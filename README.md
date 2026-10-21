# JAMB SMART POS • Yellow & Blue Edition

This is an updated version of the uploaded `TTC-main.zip`. It includes a dashboard advertising carousel, branded layout, icons, animation, and the existing Supabase-backed product, stock, POS, expense and dashboard workflows.

## Deploy on GitHub Pages

1. Back up the original repository.
2. Replace the site files with this ZIP's contents (the contents of the folder, not an additional nested folder).
3. Keep `src/config.js` configured with your own Supabase project URL and **publishable/anon** key. Never put the `service_role`/secret key in a public repository.
4. Commit and wait for GitHub Pages to deploy. Hard-refresh the site.
5. Use a new test product to run the acceptance checklist.

## Database setup

- Existing working database: **do not rerun** `supabase/migrations/001_initial.sql`. It is provided for new databases and reference.
- New database: execute the SQL in Supabase SQL Editor, create an Authentication user, create a shop and link that user through `memberships` with role `owner`.
- Functions `receive_stock` and `checkout` must exist for stock receiving and POS checkout.

## Customize the adverts

Open `index.html`, find `id="advertCarousel"`. Each `.carousel-item` is a separate slide. Edit the headline, description and icon. To insert your own banner image, use an image inside `.advert-slide` and add styling in `src/styles.css`. Keep the first slide `active`. The slider uses Bootstrap 5 carousel controls, indicators and autoplay (5.5 seconds).

## Existing MVP limitations

- No completed refunds, editing, expense reversals, receipt printing, formal double-entry accounting, verified payment gateway or offline POS.
- Today's 'operating result' is a **partial estimate** (gross profit minus recorded expenses). It is not a full accounting net profit or confirmed cash balance.
- Reporting loads the most recent 1,000 sales and expenses. Full historical reporting requires pagination / server-side aggregation.
- Cashier access has basic UI restrictions, but the database grants read access to product cost. Enforce column-level protection or safe security-definer views before granting real cashier accounts.
- No live Supabase execution was possible in this environment, so run acceptance tests against your Supabase project before entering actual records.

## Developer checks

`node --check src/app.js` is a syntax check (ES modules). `tests/ACCEPTANCE.md` contains additional manual test cases.
