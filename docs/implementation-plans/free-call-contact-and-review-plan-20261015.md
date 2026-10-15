# Free Call: selected contact, recipient resolution and compact review

Date: 2026-10-15 (Asia/Muscat)
Status: Implemented on 2026-10-15. Android debug build installed on the emulator; iOS simulator compilation passed. The approved recipient lookup and its verification-field guard are deployed and checked. Real two-device audio and invitation sending remain release checks.
Recommended design: **Quick sheet**, consistent with the implemented paid call review.

## Intended experience

Selecting or typing a number on Smart Call and tapping **Call free** opens one compact Free Call review. It carries the selected number, asks for its country only when necessary, checks the number against the KeepSIMs account lookup, and shows the actual recipient before enabling Call.

Directly under the number, always show **Both of you need the KeepSIMs app for free calls.** If no eligible account is found, explain **No KeepSIMs account found for this number. Invite them to install the app and sign in.** Show **Invite via WhatsApp** and **Invite via SMS** in that same area instead of the Call action. A matched account does not prove that the app is currently installed or reachable; keep availability separate from account membership.

Flow: selected number → Call free → resolve country if needed → look up KeepSIMs account → review recipient and calling profile → Call free → existing app-to-app active call screen.

If the user has not selected a number, open a simplified Free Call page with search, native Contacts, and small Recent / People tabs. A history row, family member, or native contact goes through the same review. Known family/history recipients should use their stable account ID; only raw phone selections need number lookup.

## Findings before implementation

CONFIRMED:

- Dashboard `_openFreeWebCall()` navigates to `/calling/internet` without passing its selected number or call draft. `InternetCallingScreen` accepts no initial selection. This explains why the second screenshot opens a blank search/history page after a number was selected in the first screenshot.
- Search is held in widget fields and uses a 400ms debounce. `_onSearchChanged()` does not immediately invalidate a previous matched account for a new long query; `_executeSearch()` accepts any eventual result while mounted. A previous result can appear against a newer query or after clearing it.
- Paste both schedules and directly runs search, so the same input can trigger duplicate lookups.
- The placeholder says “Search name or number” but the implementation calls only `lookup_voip_contact_by_phone`. There is no implemented global-name directory search in this path.
- Repository `lookupContactByPhone()` returns only the first row from the lookup response.
- The latest local definition of `lookup_voip_contact_by_phone` considers SIM lines, verified caller IDs, active virtual numbers, and profile phone values. It includes suffix matching and `LIMIT 1`, prioritized by source and with other accounts ahead of the caller. Canonical client input alone cannot make an arbitrary or ambiguous suffix result safe.
- The local lookup's `is_online` field means an active push-token row exists. It does not prove the recipient is online, available now, or will answer.
- UI lookup errors and no-match results use the same unregistered-result view. A service failure can therefore be described as an unregistered number and shown Invite / Smart Call actions. Keep these states separate.
- “Share Free Call Link” shares the generic app-download link (`https://keepsims.com/app`). It does not create a recipient-bound or session-bound callable link.
- Free calls start from a stable `calleeId` through `VoipCallingController` and `initiate-voip-call`; the backend rejects the current user's own ID. The existing controller guards against a second active outgoing call and already owns signaling, media, native registration and cleanup.
- Existing paid fallback URLs use `/calling?number=...`, but the current dashboard route does not consume that query parameter. The selected number can be lost when switching to paid calling.

INFERRED: the missing route/draft handoff explains the pictured selected-number-to-empty-page behavior. This was not reproduced by placing a real call in this planning turn.
Live inspection confirmed the legacy suffix/first-match lookup. The new client now uses `resolve_free_call_recipient`, with exact verified ownership and distinct outcomes. Actual registration/reachability of the photographed contact and two-device audio remain UNKNOWN; historical repairs are not fresh runtime evidence.

## Compact Free Call review

- Title: **Free Call**, Close/Back.
- Recipient: trusted account name and avatar when lookup succeeds, full international number with **Edit**, and small **On KeepSIMs** text. A device contact name alone does not establish the recipient's app identity. Do not invent a name when unavailable.
- App requirement: **Both of you need the KeepSIMs app for free calls**, directly below the number in every state. When account resolution confirms no eligible account, place the explanatory invitation message and two clearly labeled channel buttons immediately below it. Hide calling-profile and cost rows in this state to keep the invitation simple.
- Calling profile: signed-in KeepSIMs name/avatar or **Your KeepSIMs profile**. This is app account identity, not an external telephone caller ID. Do not copy the paid gateway/personal-number selector into Free Call.
- Cost: **Free**, with one quiet **Uses Wi‑Fi or mobile data** line. No wallet balance, minute/second tariff, savings calculator or telephone route card. The free session must never enter paid calling implicitly.
- Main action: **Call free**, enabled only after a current, unique, eligible non-self account result or validated known account ID is available. Lookup checking must not ring the recipient or create a call session.
- Edit reveals the current phone input; it preserves the selected number and invalidates old recipient results immediately. Reuse the native selected-number picker; no bulk contact import, phonebook upload, or wider permission request.
- Reuse the existing `CallDestination` normalization and `destination_country_picker.dart`. Confirm national-number country before lookup. Existing valid `+` numbers keep their prefix. Preserve country-specific leading zeros and Arabic/Eastern Arabic digits.
- Close/cancel returns to the same Smart Call selection. Opening review and changing country do not call anyone.

## State-specific behavior

| State | Display and actions |
| --- | --- |
| Missing country | Original number, country picker, full normalized preview, **Use [country]**. Lookup and Call disabled until confirmed. |
| Checking account | **Checking KeepSIMs account…**; previous account and Call cleared immediately. |
| Unique eligible account | Name/avatar, confirmed international number, signed-in calling profile, Free and **Call free**. |
| No eligible account found | Under the number and app requirement: **No KeepSIMs account found for this number. Invite them to install the app and sign in.** Show **Invite via WhatsApp** and **Invite via SMS**, with no Free Call action. Secondary **See paid call rate** opens the existing paid review with the same canonical number. No automatic message, call or charge. |
| Lookup service/network failure | **Couldn't check this number** and **Retry**. Do not claim the person is unregistered or offer actions based on a fabricated no-match. |
| Ambiguous/unverified ownership | **Couldn't identify one KeepSIMs account for this number**; Edit or choose a known People contact. Never silently pick a suffix match. |
| Self account, including one of the caller's SIMs/DIDs | **This number belongs to your account**; disable Free Call and allow Edit / choose another contact. App-to-app calling needs a different account. |
| Recipient known but presence uncertain | Registered recipient remains identifiable; omit guaranteed Online labels. Permit an explicit call attempt if backend eligibility allows it, and let normal ringing/no-answer delivery resolve reachability. |
| Offline caller | A clear connection message and Retry; do not create a session while offline. Recheck identity before resuming after reconnect. |
| Active call already exists | Show/open the existing call; do not create a competing session or replace it with a stale recipient. |

If the resolved recipient changes before the user submits (number/country/account switch), clear eligibility. If a final refresh produces a different account, show that account and require a new explicit Call tap. Backend ownership/eligibility checks remain authoritative.

## WhatsApp and SMS invitations

The two buttons are caller actions for a confirmed no-match result, not an automatic notification. They open the chosen application's compose flow addressed to the currently confirmed international number, with a short editable message: **Join me on KeepSIMs for free app-to-app calls. Install the app and sign in.** Append a verified app-download link when one is supplied. The caller reviews and sends the message in WhatsApp or Messages. Do not request SMS-send permission or send messages from the backend.

Verify the existing app-download destination before shipping; the current source's `https://keepsims.com/app` is not proof of a working universal/store link. Use platform-supported launch behavior and check current official channel/platform documentation during implementation. If WhatsApp or SMS composition is unavailable, show a truthful channel-unavailable message and offer the native share sheet or the other channel, without switching or sending silently. Returning from the composer does not prove an invitation was sent or the recipient installed the app. Provide **Check again** after return to repeat account lookup explicitly; a later valid match shows the normal Free Call review.

Use the same confirmed number in review and invitation; editing it clears the old match and invitation target immediately. Do not expose invitations during a lookup failure, missing country, ambiguous ownership or self match. For a known registered recipient who is offline or unreachable, retain their account identity and appropriate call status; never label them as not having the app based on push-token absence or a failed call.

## Simplify the browsing page and dashboard copy

1. Rename **Free Web Call** to **Free Call**, subtitle **KeepSIMs to KeepSIMs**, CTA **Call free**. Repoint **Browse directory** to **Choose a KeepSIMs contact** so it does not imply a public searchable global directory.
2. With a selected number, use the review sheet. With no number, use the Free Call browsing page. Preserve the existing history and household routes.
3. Browsing page: **Free Call** header, one search/input row and Contacts action, then **Recent** / **People**. Remove the large always-visible share banner and “WhatsApp-Style…” marketing subtitle. Place **Invite a friend** in a small overflow action or empty-state action.
4. Phone lookup requires canonical international input. Name search, if retained, filters only the existing loaded/authorized People and Recent entries; do not call a phone RPC with a name or introduce unrestricted profile queries. Otherwise label the field **Enter a number** and keep name filtering out of initial scope.
5. Group repeat history attempts by stable peer ID within a day into one compact row such as **3 missed calls · Today**, with one review/redial action. Preserve underlying call records and every status; opening row details shows individual attempts. Do not merge peers just because names or number suffixes match. Never count a call as completed without actual media connection.
6. People list uses existing registered household/history account IDs and explicit individual phone lookup. A saved/protected SIM line is not automatically an app-to-app recipient. Self-owned lines show self/unavailable, and unregistered lines show Invite / paid-rate options.

## Implementation order and ownership

### Phase 1 — shared selection handoff and recipient state

Reuse `CallDestination` and country UI from paid review. Introduce a small typed free-call selection/draft under `voip_calling` that can contain raw number plus confirmed country, or a trusted known recipient ID with display data. Paid quote/identity state and free recipient/account state remain distinct; they share number normalization, not pricing or submission controllers.

Pass the selection explicitly from `SmartCallDashboardScreen` to the new `FreeCallReviewSheet`, or seed an account-scoped free-call draft before navigation. Add an optional initial number to the browsing route only where direct/deep-link use requires it. A route/query string containing a number or user ID is not proof of permission or account eligibility.

Add a free recipient controller with typed states (idle, needsCountry, resolving, found, notFound, ambiguous, self, offline, error) and a bounded lookup timeout. Invalidate on every number/country/selection/account mutation, clear, and disposal. Tag requests immediately before debounce and capture the canonical number and signed-in account; stale callbacks cannot restore eligibility. Remove duplicate paste-triggered requests. UI performs no raw Supabase/profile queries.

### Phase 2 — verify and secure recipient resolution

Before relying on the phone result, inspect the **live** `lookup_voip_contact_by_phone` definition/grants with Supabase MCP read-only tools and compare its source to local migrations. Verify the live policy for which phone records are allowed to identify an account.

Required resolution contract: exact canonical E.164 match to an eligible owner, deduplicated by stable user ID, with explicit no-match/self/ambiguous outcomes. A raw SIM-line claim or user-editable profile phone must not automatically count as verified ownership. Retain legitimately authorized verified caller IDs and active owned virtual numbers where the existing business contract permits them. Do not casually remove an existing supported lookup source; map ownership and migration behavior first. Exclude unauthorized, suspended/ineligible or non-discoverable identities according to the current backend contract. Return only the minimal data needed for calling; preserve authenticated-only access and an appropriate lookup rate limit/privacy boundary.

If live behavior already satisfies this contract, reuse it. If it still does suffix matching/first-match selection or lacks an ownership rule, prepare a forward-only migration and typed result adapter plus negative SQL tests. Do not treat client normalization as a replacement for this backend fix. Review dependent clients/callers before changing the RPC shape. Live migration/deployment requires separate explicit authorization under repository rules.

There must be no “pick any result” workaround in the Flutter UI. Name-based searches of already authorized People entries operate separately from phone account resolution.

### Phase 3 — review and browse UI

Create `free_call_review_sheet.dart` with found, missing-country, unavailable and failed states. Reuse theme/layout conventions from `CallReviewSheet`; keep app identity/Free display specific to app calls. Apply light/dark themes, English/Arabic labels, RTL, LTR phone text, safe areas, keyboard avoidance, large text, and minimum touch targets.

Make history/family/native-contact entry points open the same review. Validate known account IDs against the current authorization/session boundary; do not convert them back into unreliable phone searches. Fix paid fallback to seed the same canonical number in the existing paid draft and open `CallReviewSheet`, where the rate is shown and explicit Call is still required.

Implement explicit **Invite via WhatsApp** and **Invite via SMS** compose actions in the no-match review, with the current canonical recipient and editable generic app-download message. Keep a generic native-share fallback and small **Invite a friend** entry in browsing. Add **Check again** when returning to the no-match review. Actual signed call links, automatic messages, or a public contact directory are separate product features and are not included.

### Phase 4 — outgoing call dispatch and recovery

Final **Call free** checks the current draft, distinct caller/recipient account IDs, no conflicting active session, authenticated session, and eligible recipient. Request microphone access only at this action. Denial retains the review and selection, with a suitable Settings option if permanently denied. Lock repeated taps and cancel safely if account or draft changes during permission/refresh work.

Submit the resolved `calleeId` through the existing `VoipCallingController.startCall()` and `VoipCallingRepository.initiateCall()`. Preserve signaling, ICE/TURN, native call handling, call-ID/generation guards, end/mute/speaker, and recovery. Do not reuse paid-call audio or `make-call`/wallet paths.

If permission/recipient validation fails before submission, remain in review; if the backend returns busy/unavailable or setup fails, show its appropriate existing call-state UI and release local resources. Ringing/Connecting must be bounded. Connected and the timer start only on actual media connection. No live Online, Connected or successful-call claim should be inferred from a push token, accepted invitation or saved SDP.

This UX task does not authorize rewriting or redeploying the historical connection-repair work. Investigate any reproduced transport issue in its existing component with focused tests; keep the new review independent of the media stack.

## Verification and acceptance

Automated checks:

- Dashboard selection arrives unchanged in Free Call review; no-number entry opens browse.
- Local numbers cannot look up/call without confirmed country; `+` and Arabic-digit cases reuse the existing resolver tests.
- A phone RPC never receives a name. Local name filtering respects existing People access.
- Old lookup responses during debounce, clear, account change, permission dialog or disposal cannot populate a new draft or enable Call.
- The app requirement stays directly under the number in matched and unmatched states. A confirmed no-match shows WhatsApp and SMS invite buttons in the same area and hides Free Call; matched recipients use the normal review.
- Invitations open only the caller-selected compose channel after a tap, with the exact confirmed international number and editable download message. They never auto-send or request SMS-send permission. Missing channel support offers an explicit fallback. Returning does not imply sent/installed; **Check again** performs a fresh lookup.
- An error is distinct from no-match. Lookup failure, ambiguous ownership and self matches do not show no-app invitations. Ambiguous phone owners never become an arbitrary `calleeId`.
- Exact same suffix across different countries and duplicate matches across lookup sources/users have explicit safe outcomes. Exact canonical match must not be outranked by a suffix or unverified claim. Anonymous callers and unauthorized record sources are denied in SQL tests when backend changes apply.
- Self-call rejected by stable account ID for profile, SIM, caller-ID and owned-DID numbers. A matched account name is used only after successful trusted resolution.
- An active push token does not yield an “Online now” promise. Known registered recipients with uncertain presence can still have an explicit, authorized call attempt.
- Selected caller is the signed-in app profile; there is no gateway/personal-line switch or wallet tariff in Free Call.
- Paid fallback retains the canonical number and goes through the paid rate review; no paid start is triggered by free-call failure.
- History grouping is deterministic by peer ID/day; individual rows/statuses remain accessible and incoming/outgoing/missed distinctions are preserved.
- No wallet debit or paid-provider call on free lookup, invite, free setup, decline or completion.
- Duplicate Call taps, busy response, microphone denial, lookup timeout, reconnect and back/cancel behave without stale draft/session creation.
- Small screens, large text, Arabic/RTL, light/dark, Android contact selection/cancel and iOS contact selection/cancel.

Verification sequence: focused unit/widget tests → calling/VoIP regression suites → scoped/full Flutter analysis as appropriate → Android build/install → iOS compile/runtime where available. Run SQL/function regression checks via MCP only if the resolution contract changes. Record existing unrelated failures separately rather than claiming a clean entire app.

Two-device release gate: A calls B, B calls A; test both normal directions with answer, no-answer, decline, busy, hangup from either side, and a background/locked recipient. Verify real two-way speech, mute/output and truthful connected duration/history. Repeat on different networks with TURN and include a physical recipient before claiming reliable background/cold delivery. Do not use the same account on two devices as the distinct-recipient acceptance test. Mark unavailable hardware/live tests NOT RUN. An actual test call to another person requires the user's explicit authorization for that recipient.

Done means selected contact → correct authorized account → one compact review → explicit app-to-app call, with safe unmatched/error/self outcomes and correct paid fallback. A visual refresh alone does not satisfy that gate.

## Change surfaces and scope

Customer UI/controller/repository: `smart_call_dashboard_screen.dart`, `app_router.dart` only where route initial selection is needed, `internet_calling_screen.dart`, new free-recipient draft/controller and review widget, and `voip_calling_repository.dart` result adapter. Shared reuse: `calling/domain/call_destination.dart`, `destination_country_picker.dart`, existing native `DeviceContactPicker`, existing paid `CallReviewSheet`. Backend: lookup RPC/migration only if live verification shows the local risks remain; retain existing VoIP call-initiation authorization.

Implementation uses `free_call_review_test.dart` plus the existing browse/navigation/VoIP/calling suites. Paid-call, auth and native-contact changes were preserved. See `docs/reviews/free-call-review-verification-20261015.md` for current results and live migration IDs.

## Proposal verification

The initial inline Quick sheet / Simple page mockup was inspected locally. Edit → national number → country choice → full-number confirmation and a resolved example recipient were checked. The revised proposal was also inspected: both variants show the app requirement directly below the number and separate WhatsApp/SMS invitation actions for a no-match result. Each invite preview retains the selected canonical number; Edit hides invitation actions, and a matched example restores Call free with no invitations. The preview reported no browser errors. Names, account-match results and numbers in the mockup are illustrative; it performs no account lookup, message, share, call, or payment. App source and live backend were not modified by this planning request.

## Implemented contract and verification

- Selected Smart Call number → Free Call quick sheet; empty entry → Recent/People browsing. Native contacts and history/family selections share this review. Name-directory searching was removed; phone search is explicit and country-confirmed. Repeated peer/day records group visually while individual status/direction remains accessible.
- A request epoch and signed-in account fence clear stale eligibility on edit, country/account changes and disposal. The final tap rechecks the recipient after microphone permission; a changed account requires another tap. Lookup errors, ambiguous/unverified ownership and self outcomes never become no-match invitations.
- Phone proof comes from verified caller IDs, active server-owned DIDs or a confirmed Auth phone. Raw SIM/carrier setup and editable profile phones are unverified claims; conflicting owners are ambiguous. Known IDs require an accepted household relationship or existing caller-owned call history.
- The live caller-ID table previously allowed clients to manufacture `is_verified`/`verified_at`. A SECURITY INVOKER trigger now rejects client verification writes and clears proof on phone changes. Existing server verification and harmless label/default edits are retained.
- WhatsApp opens the caller's installed app; Android SMS uses SENDTO, and iOS uses the native MessageUI composer. Both fill the confirmed number and an editable message, and the human must press Send. Channel unavailability has an explicit share/alternate-channel option.
- The user clarified that their own WhatsApp/Messages app must send the invitation. No real store/test URL was supplied; the current marketing page's store buttons are placeholders. Invitations currently contain installation/sign-in instructions without that broken download promise. A verified HTTPS link can be supplied with `FREE_CALL_APP_DOWNLOAD_URL` at build time.
- The existing active-call/signaling/media stack and wallet paths were retained. No live call, paid charge, or outbound invitation was performed in verification.
