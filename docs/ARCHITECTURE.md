# Architecture and scope

Browser (HTML/Bootstrap/ES modules) -> Supabase Auth -> PostgREST + RPC -> PostgreSQL.

- Publicly exposed direct table writes are limited to permitted product metadata and expenses.
- `checkout()` and `receive_stock()` are PostgreSQL transactional functions, with authorization, row locks, pricing validation, idempotency for checkout, and stock movements.
- `products.stock` is server-owned. Client can insert new products with default stock 0, but cannot edit stock directly.
- RLS scopes reads by shop membership; cashier cannot view expenses or purchase costs by role policy? Current MVP cashiers can view `products.cost` through product read permission, so hide cost in the UI and restrict with a future protected read projection before production use.
- Sales store cost snapshots to protect historical gross profit after later price changes.
- Dashboard queries latest 1000 rows only. Production reporting needs server-side aggregate RPCs, pagination, date boundaries, and a financial ledger.
- Mobile money and bank are only manually recorded collection methods and must not be treated as independently verified.

## Logical schema

`shops 1--* memberships *--1 auth.users`
`shops 1--* products`
`shops 1--* purchases *--1 products`
`shops 1--* sales 1--* sale_items *--1 products`
`shops 1--* expenses`
`products 1--* stock_movements`

## MVP versus future

Working MVP: password login, a single shop membership, product creation, stock receiving with weighted-average cost, sale checkout and cost snapshots, expense capture, sales history, today's gross profit and simple operating result.

Not implemented: payment integrations/verification, taxes, refunds, discounts, multi-location checkout UI, purchase liabilities, customer credit, cash reconciliation, offline sales, double-entry books, full net-profit statements, owner onboarding, comprehensive automated database tests and server-side historical reports.

*The operating result shown on the dashboard is sales minus COGS minus entered expenses for today, not accounting net profit. It excludes liabilities, taxes, depreciation and unrecorded costs.*
