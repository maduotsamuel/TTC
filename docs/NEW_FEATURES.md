# New in JAMB SMART POS 3.0

- Inventory search, stock state filter and CSV export.
- Sales history receipt search, date filtering and CSV export.
- Click a receipt ID to view sale lines and print a customer receipt.
- Dashboard 30-day bestsellers by quantity and estimated gross profit.
- Actionable out-of-stock, low-stock and below-cost indicators.
- CSV reorder report.
- Refined interaction states and responsive tables.

## Important limits

Sales history still loads only the latest 1,000 sales; sale items are limited to 10,000. Exports and insight calculations reflect this loaded subset only. For a large shop, move reporting to paginated database functions. The optional PWA/offline mode and automatic payments are not implemented. Database integration cannot be verified without access to the live Supabase project. Do not run old initial migrations against an existing deployed database.
