# 04 — eSIM Store and Roaming Tools

## eSIM catalogue filters
### TC-ESIM-001: Search countries and filter regional eSIM plans
- **Preconditions**: The catalogue contains offers for multiple countries, regions, carriers, and durations.
- **Expected**: Search and filters update the result set and empty state without showing offers outside the selected criteria.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: The existing N1 SQL test failed before assertions because its JSON-to-array cast produces a malformed PostgreSQL array.

## Plan cards and comparison
### TC-ESIM-002: Compare data, validity, and retail price
- **Preconditions**: At least two active offers differ by data amount, validity, or price.
- **Expected**: Cards show supplier-independent retail price, data size, validity, and destination; compare filters return matching offers.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Compare widget tests exist; Flutter execution stalled.

## Plan details and checkout
### TC-ESIM-003: Review plan details and confirm an eSIM purchase
- **Preconditions**: A compatible device, active offer, and sufficient test balance or sandbox payment route are available.
- **Expected**: Details match the offer; checkout creates one order; funds are debited only after successful purchase finalization.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No purchase was submitted. The legacy C9a SQL test was rejected by the approval review because its fixture can trigger notification side effects for a real profile.

## Purchased eSIM delivery
### TC-ESIM-004: Open installation instructions for a purchased eSIM
- **Preconditions**: A completed eSIM order has an activation code or QR payload.
- **Expected**: Order status and installation steps match the completed order; secrets are not exposed to unrelated accounts.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: No live supplier order or device installation was attempted.

## Price Watch
### TC-ESIM-005: Create, update, and remove a price threshold
- **Preconditions**: A signed-in user has an eligible offer and a chosen drop threshold.
- **Expected**: Watch persists for that user, refreshes current best price, and generates one alert when the threshold is crossed.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Existing G2 SQL suite could not complete because its seeded fixture expects an existing watch and found none; Flutter screen test did not run.

## Roam Calculator
### TC-ESIM-006: Estimate roaming cost from destination and usage
- **Preconditions**: A destination, trip length, and daily usage are entered.
- **Expected**: Estimate updates from the selected country and usage; changing inputs updates comparison and displayed units.
- **Status**: CATALOGED - UNTESTED
- **Notes/Found Issues**: Roam quote tests exist but Flutter execution stalled.
