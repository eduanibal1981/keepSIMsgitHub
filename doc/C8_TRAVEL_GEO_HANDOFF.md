# C8 — Travel & Geolocation: Hand-off Brief

**Written 2026-07-22, repo @ `9d42d67` (main), live DB `zwxswagokhgbuzrrbnhr` verified same day.**
Plan section: `doc/PRODUCTION_PLAN.md` § C8. Order: C1–C7 (incl. C5) are DONE; C8 is next, then C9.

## Owner decision (encoded in plan)

Foreground-only tracking is enough; the trigger that matters is **"user entered a new
country."** On detection: update stored country, fire roaming-advice notification with
an eSIM-offer deep link (C9's browse screen), and offer the B5 freeze/resume flow.
No background location — detection happens on next app open, and the UI must say so.

## Verified current state (live DB + repo, 2026-07-22)

- **🔴 The plan's premise is WRONG: there is no geolocation flow to "audit."** The
  entire `lib/features/geo/` feature is a **Border Simulator** — the current country is
  `_simulatedIso`, set by tapping fake destination buttons on `geo_screen.dart`
  (routed at `/settings/geo`, **reachable in release builds**). `pubspec.yaml` has
  **no geolocator / location / permission_handler / geocoding package at all**.
  Country detection must be built from scratch; the "existing geolocation permission
  flow" the plan references does not exist.
- **🔴 The freeze is COSMETIC — money keeps flowing on "frozen" lines.**
  `freezeAllInternationalLines()` (`geo_controller.dart:116`) sets only
  `sim_lines.status='paused'`. Verified live: **no DB function or worker reads
  `sim_lines.status`** for refill gating — `claim_due_executions` gates solely on
  `scheduled_topups.is_active`. The real pause mechanism is B5's
  `_applyProtectionPause` (`sim_lines_controller.dart:418`) → `toggleActive(schedule,
  false)`. So a traveler who taps "Freeze" sees lines paused while the workers keep
  debiting the wallet on schedule. **This is the most valuable thing C8 fixes.**
- **`profiles` has NO `last_country` column** (verified: columns end at
  `is_suspended`; only `home_country_code` exists). Migration needed, ISO-2 only.
- **Notification plumbing is ready**: `geo_fence_triggered` and `welcome_home_ready`
  are both canonical C2 categories; `alert_settings` seeded (16 rows = 8 users × 2);
  the C1 dispatcher fans out on INSERT into `notifications` with zero new wiring.
- **`notifications` is client-insertable** (policy "Users can insert own
  notifications", INSERT granted to `authenticated`) — that's how the simulator
  "notifies" (`simulateNotification`, `notifications_repository_impl.dart:246`,
  hardcoded English). Pre-existing hole (any user can trigger dispatcher fan-out with
  arbitrary category/title/body). C8 must NOT build on this path — and shouldn't
  widen it.
- **B5 interplay already half-done**: `freezeAllInternationalLines` correctly skips
  `requiresProtectionAtHome` lines (`geo_controller.dart:133`); resume path exists.
  Only the underlying pause mechanism is wrong (above).
- `authProfile.homeCountryCode` exists (fallback `'US'`); the controller has a
  hardcoded 6-entry `countryNames` map — `supportedCountriesProvider` already has real
  names + ISO codes, use it. `userPreferences.travelModeEnabled` toggle exists and
  persists but gates nothing real yet.
- **eSIM deep-link target exists**: `/esim` route → `esim_screen.dart` facade
  ("coming soon" CTAs). Fine to point the offer link there now; C9 fills it in.
  `notifications.action_url` column exists — **verify in-session that notification tap
  actually routes** before relying on it.
- `geo_screen.dart` strings are hardcoded English (no ARB), with a false claim
  ("Geolocation Shield active and running in background") that contradicts the
  owner's foreground-only decision.

## Design conflicts & judgment calls (recommendations)

1. **Country detection: IP-based via Edge Function, NOT GPS** (deviation from the
   plan's implied geolocation flow — record it). Rationale: nothing exists yet either
   way; `ACCESS_FINE_LOCATION` buys permission UX, Play Store location declarations,
   and D3 privacy-questionnaire burden — all to obtain one ISO-2 code that IP lookup
   gives for free on both platforms with **zero permissions**. It also makes the
   plan's privacy promise absolute: coordinates are never *collected*, not just never
   stored. Trade-off: VPN users mis-detect — acceptable for an advice-only feature
   where every action is prompt-confirmed. Alternatives considered: GPS+geocoding
   (accurate, heavy); SIM/network country via telephony (no permission, but iOS
   CTCarrier is deprecated/dead since iOS 16). **Confirm with owner at session
   start.**
2. **Detection and write in ONE server round trip**: new Edge Function
   `detect-country` (verify_jwt ON — it acts as the caller) that resolves the
   caller's IP → ISO country server-side and then applies the change itself:
   compare to `profiles.last_country`, no-op if unchanged, else update + insert the
   `geo_fence_triggered` (abroad) / `welcome_home_ready` (home) notification
   **server-side** with the eSIM `action_url`. The client only calls it on app
   open/resume (and when `travelModeEnabled`); it cannot spoof a country or forge
   notification content. First probe whether Supabase Edge Functions receive a
   CDN geo header (e.g. `cf-ipcountry` / `x-forwarded-for` + lookup) — **verify with
   a live probe before designing around it**; fall back to a geo-IP lookup inside the
   function if not. Add a flap guard (ignore changes within ~1h,
   `system_configs`-tunable) so border/VPN flapping can't spam the dispatcher.
3. **Fix the cosmetic freeze — route it through the real pause path**: freeze/resume
   must toggle `scheduled_topups.is_active` for the line's schedules (the same thing
   `_applyProtectionPause` does), in addition to the `status` field the UI displays.
   Extract the shared logic rather than duplicating the loop in geo_controller. Keep
   the `requiresProtectionAtHome` skip exactly as is. Add a Dart test proving a
   frozen line's schedules are inactive.
4. **Keep it prompt-driven, not auto-freeze**: the plan's item 2 wording implies
   entering a country "triggers" the freeze; the current UX prompts and the user
   confirms. With fallible IP detection, prompting is right — never bulk-pause money
   flows off a heuristic. Confirm with owner.
5. **Rebuild `geo_screen`, kill the fake shield**: kDebugMode-gate the Border
   Simulator (useful test rig — same treatment as other simulators, D4 direction),
   replace the release screen with an honest status card (current country, last
   change, travel-mode master toggle, "checked when you open the app" copy per plan
   item 4), ARB ×9 for every string.
6. **Privacy (plan item 3)**: only the ISO code lands in `profiles.last_country`;
   note for D3's privacy policy + Play Data Safety. Notification opt-out already
   works via the C2 `geo_fence_triggered` toggle — nothing to build. Detection
   failure (offline, lookup error) = silent no-op, never an error surface.

## Confirm with owner at session start (blocking)

1. IP-based detection with zero location permissions (VPN caveat) vs GPS — recommend IP.
2. Country change **prompts** freeze/resume (current UX) vs auto-executes — recommend prompt.
3. Border Simulator: kDebugMode-gate and keep as test rig — confirm (vs delete).
4. Flap-guard window (suggest 1h, `system_configs` key so it's DB-tunable).

## Session conventions (house rules — do not deviate)

- Migration `supabase/migrations/20260725000000_c8_travel_geo.sql` — round manual
  timestamp, `timestamp_phase_description` naming; apply via MCP `apply_migration`
  AND save the local file **the same session** (eb832ec lesson).
- Live SQL tests `supabase/tests/c8_travel_geo_tests.sql`, BEGIN..ROLLBACK via MCP
  `execute_sql`. Smoke over PostgREST as the a1 fixture
  (`a1-wallet-test@example.com` / `A1TestPass!2026`) — **wallet must end unchanged at
  37.81** (updated baseline 2026-07-22; the old 42.96 note is stale — a $5.15 refill
  test on 07-21 moved it, ledger reconciles exactly).
- Edge Fn deploy via MCP: pass `import_map_path: "deno.json"` + include `deno.json`
  (`{}`) in files, or redeploy fails. Check the function into
  `supabase/functions/detect-country/`.
- `get_advisors` after migration: target 0 net-new (authenticated SECURITY DEFINER
  self-scoped is the accepted known pattern).
- `flutter analyze` — record the baseline BEFORE changes (last known **143** infos);
  no regressions. All Flutter tests pass (52 at C5). Debug APK builds.
- ARB keys in all 9 locales (en, ar, es, hi, tr, bn, ne, si, ur). Use the Edit tool
  for files with non-Latin text — PowerShell 5.1 Get/Set-Content mojibakes UTF-8.
- Don't blanket `dart format` touched files (repo isn't format-clean; it buries diffs).
- Commit `feat(geo): …`, push to `main`.
- Update `doc/PRODUCTION_PLAN.md` § C8 with an implementation record in the style of
  the C5/C6/C3c records, including recorded deviations (IP-based detection, cosmetic-
  freeze fix).

## Execution prompt for the implementing agent

See the fenced prompt handed alongside this brief (chat), or reconstruct from the
sections above — the brief is the source of truth.
