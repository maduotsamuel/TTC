# Manual acceptance tests (not executed)

1. Create product P (cost=3000, price=4500), receive 10 -> stock=10.
2. Sell 5 -> stock=5; revenue=22500; COGS=15000; gross profit=7500.
3. Receive 10 more at cost=5000 -> weighted average cost rounds to 4333.33 per unit.
4. Attempt sell 100 -> transaction rejected without changing stock or sales.
5. Retry same checkout request UUID -> receive original sale UUID with no duplicate.
6. Login as a user not in membership -> cannot query shop records or call RPC successfully.
7. Login as cashier -> cannot record stock receiving, add products or expenses.
8. Attempt browser-side update of products.stock -> database permission denied.
9. Record expense 2000 -> today's operating result decreases by 2000.
10. Try zero or negative purchase quantity -> RPC rejects.
11. Check branch/shop access for separate shops before enabling multishop use.

12. Log in, confirm dashboard opens, refresh KPI loads.
13. Check advert slider autoplay, indicators and previous/next controls.
14. Sidebar buttons open the correct view with hover/focus animations.
15. Test mobile viewport layout and horizontal navigation.
16. Confirm form validation, adding a product, receiving stock, checking out and saving expense.
17. Verify role-specific views with a cashier account and ensure no unauthorized database writes.
18. Verify that network errors display visible messages and do not silently create duplicate sales.
