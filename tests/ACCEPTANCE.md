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
