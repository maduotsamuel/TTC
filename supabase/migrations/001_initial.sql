-- JAMB SMART POS MVP: execute on a new Supabase database.
create extension if not exists pgcrypto;
create table public.shops(id uuid primary key default gen_random_uuid(),name text not null,created_at timestamptz not null default now());
create table public.memberships(shop_id uuid not null references public.shops(id),user_id uuid not null references auth.users(id),role text not null check(role in ('owner','manager','cashier')),primary key(shop_id,user_id));
create table public.products(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id),name text not null check(length(trim(name))>0),sku text,price numeric(16,2) not null check(price>=0),cost numeric(16,2) not null check(cost>=0),stock numeric(14,3) not null default 0 check(stock>=0),reorder_level numeric(14,3) not null default 5 check(reorder_level>=0),active boolean not null default true,created_at timestamptz not null default now(),unique(shop_id,sku),unique(id,shop_id));
create table public.purchases(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id),product_id uuid not null,quantity numeric(14,3) not null check(quantity>0),unit_cost numeric(16,2) not null check(unit_cost>=0),total numeric(18,2) not null check(total>=0),created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),foreign key(product_id,shop_id) references public.products(id,shop_id));
create table public.sales(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id),request_id uuid not null,subtotal numeric(18,2) not null check(subtotal>=0),cogs numeric(18,2) not null check(cogs>=0),payment_method text not null check(payment_method in ('cash','mobile_money','bank')),created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),unique(shop_id,request_id),unique(id,shop_id));
create table public.sale_items(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id),sale_id uuid not null,product_id uuid not null,quantity numeric(14,3) not null check(quantity>0),unit_price numeric(16,2) not null check(unit_price>=0),unit_cost numeric(16,2) not null check(unit_cost>=0),line_total numeric(18,2) not null check(line_total>=0),foreign key(sale_id,shop_id) references public.sales(id,shop_id),foreign key(product_id,shop_id) references public.products(id,shop_id));
create table public.expenses(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id),category text not null check(length(trim(category))>0),description text not null default '',amount numeric(18,2) not null check(amount>0),spent_at timestamptz not null default now(),created_by uuid not null references auth.users(id));
create table public.stock_movements(id uuid primary key default gen_random_uuid(),shop_id uuid not null references public.shops(id),product_id uuid not null,delta numeric(14,3) not null check(delta<>0),reference_type text not null check(reference_type in ('purchase','sale')),reference_id uuid not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),foreign key(product_id,shop_id) references public.products(id,shop_id));
create index on public.products(shop_id,name);
create index on public.sales(shop_id,created_at);
create index on public.expenses(shop_id,spent_at);
create index on public.purchases(shop_id,created_at);
create index on public.stock_movements(shop_id,product_id,created_at);

-- Membership test is called by RLS policies and transactional functions.
create schema if not exists private;
create function private.has_role(p_shop uuid,p_roles text[]) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.memberships m where m.shop_id=p_shop and m.user_id=(select auth.uid()) and m.role=any(p_roles));
$$;
revoke all on function private.has_role(uuid,text[]) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.has_role(uuid,text[]) to authenticated;

alter table public.shops enable row level security;
alter table public.memberships enable row level security;
alter table public.products enable row level security;
alter table public.purchases enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.expenses enable row level security;
alter table public.stock_movements enable row level security;

create policy shops_read on public.shops for select to authenticated using (private.has_role(id,array['owner','manager','cashier']));
create policy membership_read on public.memberships for select to authenticated using (user_id=(select auth.uid()));
create policy products_read on public.products for select to authenticated using (private.has_role(shop_id,array['owner','manager','cashier']));
create policy products_insert on public.products for insert to authenticated with check (private.has_role(shop_id,array['owner','manager']) and stock=0);
create policy products_update on public.products for update to authenticated using (private.has_role(shop_id,array['owner','manager'])) with check (private.has_role(shop_id,array['owner','manager']));
create policy purchases_read on public.purchases for select to authenticated using (private.has_role(shop_id,array['owner','manager']));
create policy sales_read on public.sales for select to authenticated using (private.has_role(shop_id,array['owner','manager','cashier']));
create policy sale_items_read on public.sale_items for select to authenticated using (private.has_role(shop_id,array['owner','manager','cashier']));
create policy expenses_read on public.expenses for select to authenticated using (private.has_role(shop_id,array['owner','manager']));
create policy expenses_insert on public.expenses for insert to authenticated with check (private.has_role(shop_id,array['owner','manager']) and created_by=(select auth.uid()));
create policy movement_read on public.stock_movements for select to authenticated using (private.has_role(shop_id,array['owner','manager']));

-- Restrict all exposed table operations first; grant individual capabilities.
revoke all on all tables in schema public from anon,authenticated;
grant select on public.shops,public.memberships,public.products,public.purchases,public.sales,public.sale_items,public.expenses,public.stock_movements to authenticated;
grant insert(shop_id,name,sku,price,cost,reorder_level,active) on public.products to authenticated;
grant update(name,sku,price,cost,reorder_level,active) on public.products to authenticated;
grant insert(shop_id,category,description,amount,spent_at,created_by) on public.expenses to authenticated;
-- uuid defaults require no sequence grants.

-- No untrusted direct write access to stock, purchases, sales or movement ledger.
create function public.receive_stock(p_shop uuid,p_product uuid,p_qty numeric,p_unit_cost numeric)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_old_stock numeric; v_old_cost numeric; v_new_cost numeric;
begin
 if not private.has_role(p_shop,array['owner','manager']) then raise exception 'Not authorized'; end if;
 if p_qty is null or p_qty<=0 or p_unit_cost is null or p_unit_cost<0 or p_qty>1000000 then raise exception 'Invalid purchase input'; end if;
 select stock,cost into v_old_stock,v_old_cost from public.products where id=p_product and shop_id=p_shop and active for update;
 if not found then raise exception 'Product not found'; end if;
 v_new_cost:=round((v_old_stock*v_old_cost + p_qty*p_unit_cost)/(v_old_stock+p_qty),2);
 insert into public.purchases(shop_id,product_id,quantity,unit_cost,total,created_by) values(p_shop,p_product,p_qty,p_unit_cost,round(p_qty*p_unit_cost,2),auth.uid()) returning id into v_id;
 update public.products set stock=stock+p_qty,cost=v_new_cost where id=p_product;
 insert into public.stock_movements(shop_id,product_id,delta,reference_type,reference_id,created_by) values(p_shop,p_product,p_qty,'purchase',v_id,auth.uid());
 return v_id;
end $$;

create function public.checkout(p_shop uuid,p_request uuid,p_items jsonb,p_payment_method text)
returns uuid language plpgsql security definer set search_path='' as $$
declare v_id uuid; v_existing uuid; v_item record; v_product record; v_subtotal numeric(18,2):=0; v_cogs numeric(18,2):=0; v_lines int:=0;
begin
 if not private.has_role(p_shop,array['owner','manager','cashier']) then raise exception 'Not authorized'; end if;
 if p_request is null or p_payment_method not in ('cash','mobile_money','bank') then raise exception 'Invalid checkout'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>100 then raise exception 'Invalid cart'; end if;
 -- Serialize same-shop duplicate request IDs by transaction-scoped lock.
 perform pg_advisory_xact_lock(hashtextextended(p_shop::text||':'||p_request::text,0));
 select id into v_existing from public.sales where shop_id=p_shop and request_id=p_request;
 if found then return v_existing; end if;
 -- Prevalidate items before writing; aggregate repeated product IDs, lock by ID order.
 for v_item in select (elem->>'product_id')::uuid as product_id,sum((elem->>'quantity')::numeric) as qty from jsonb_array_elements(p_items) elem group by 1 order by 1 loop
   v_lines:=v_lines+1;
   if v_item.qty is null or v_item.qty<=0 or v_item.qty>1000000 then raise exception 'Invalid quantity'; end if;
   select id,stock,price,cost into v_product from public.products where id=v_item.product_id and shop_id=p_shop and active for update;
   if not found then raise exception 'Unknown product'; end if;
   if v_product.stock<v_item.qty then raise exception 'Insufficient stock for product %',v_item.product_id; end if;
   v_subtotal:=v_subtotal+round(v_item.qty*v_product.price,2);
   v_cogs:=v_cogs+round(v_item.qty*v_product.cost,2);
 end loop;
 insert into public.sales(shop_id,request_id,subtotal,cogs,payment_method,created_by) values(p_shop,p_request,v_subtotal,v_cogs,p_payment_method,auth.uid()) returning id into v_id;
 for v_item in select (elem->>'product_id')::uuid as product_id,sum((elem->>'quantity')::numeric) as qty from jsonb_array_elements(p_items) elem group by 1 order by 1 loop
   select id,price,cost into v_product from public.products where id=v_item.product_id and shop_id=p_shop;
   insert into public.sale_items(shop_id,sale_id,product_id,quantity,unit_price,unit_cost,line_total) values(p_shop,v_id,v_item.product_id,v_item.qty,v_product.price,v_product.cost,round(v_item.qty*v_product.price,2));
   update public.products set stock=stock-v_item.qty where id=v_item.product_id;
   insert into public.stock_movements(shop_id,product_id,delta,reference_type,reference_id,created_by) values(p_shop,v_item.product_id,-v_item.qty,'sale',v_id,auth.uid());
 end loop;
 return v_id;
end $$;
revoke all on function public.receive_stock(uuid,uuid,numeric,numeric) from public,anon;
revoke all on function public.checkout(uuid,uuid,jsonb,text) from public,anon;
grant execute on function public.receive_stock(uuid,uuid,numeric,numeric),public.checkout(uuid,uuid,jsonb,text) to authenticated;
