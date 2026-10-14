# KeepSIMs (`keep_sims`) — Active Cross-Machine Handoff State

- **Last Updated**: 2026-10-13 (Asia/Muscat)
- **Last Active Machine**: Windows Laptop
- **Branch**: `main`
- **Supabase Project**: `zwxswagokhgbuzrrbnhr`

---

## 🔄 How to Switch Between Windows & Mac

1. **Before leaving the current machine**:
   - Tell the AI agent: **"Save handoff state"** (or run `/learn`).
   - The agent will update this file (`.agents/memory/ACTIVE_HANDOFF.md`) with the current task status, modified files, and next steps.
   - Commit and push via Git (`git add . && git commit -m "wip: handoff" && git push`).
2. **When starting on the other machine**:
   - Run `git pull`.
   - Start a fresh chat and say: **"Resume from `@.agents/memory/ACTIVE_HANDOFF.md`"**.

---

## 📌 Current In-Progress & Uncommitted Work (`keep_sims`)

### 1. Password Recovery & Auth Flow Enhancements
- **New / Untracked Files**:
  - `lib/features/auth/contract/password_recovery_contract.dart`
  - `lib/features/auth/controller/password_recovery_controller.dart` (`.g.dart`)
  - `lib/features/auth/repository/password_recovery_repository.dart`
  - `lib/features/auth/ui/forgot_password_screen.dart`
  - `docs/password_recovery.md`
  - `supabase/templates/`
  - `test/features/auth/`
- **Modified Files**:
  - `lib/features/auth/controller/auth_controller.dart`
  - `lib/features/auth/repository/auth_repository.dart`
  - `lib/features/auth/ui/email_auth_screen.dart`
  - `lib/core/router/app_router.dart` (`.g.dart`)
  - `lib/core/supabase_client.dart`
  - `supabase/config.toml`

### 2. Onboarding, Notification Permissions & Alert Preferences
- **New / Untracked Files**:
  - `lib/features/notifications/data/services/`
  - `lib/features/notifications/presentation/controllers/notification_permission_controller.dart`
  - `lib/features/notifications/presentation/widgets/notification_permission_control.dart`
  - `lib/features/profile/presentation/widgets/account_setup_welcome.dart`
  - `lib/features/profile/presentation/widgets/setup_device_permissions.dart`
  - `assets/images/onboarding/`
  - `test/features/notifications/notification_permission_controller_test.dart`
  - `test/features/profile/onboarding_notification_contacts_test.dart`
- **Modified Files**:
  - `lib/features/profile/presentation/ui/onboarding_screen.dart`
  - `lib/features/notifications/presentation/screens/notification_settings_screen.dart`
  - `lib/features/sim_lines/presentation/widgets/alarm_clock_preferences_sheet.dart`
  - `test/features/notifications/alert_preferences_dashboard_test.dart`
  - `test/features/profile/onboarding_currency_transition_test.dart`
  - `docs/qa/08_profile_onboarding.md`
  - `docs/qa/13_auth_notifications.md`

### 3. App Icon, Splash Branding & Smart Calling Polish
- **New / Modified Files**:
  - Android & iOS launcher icons (`android/app/src/main/res/mipmap-*`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/*`)
  - Android 12+ splash branding (`android/app/src/main/res/drawable/splash_branding.xml`, `splash_icon.xml`, `values-v31/styles.xml`)
  - `assets/images/launcher-icon.png`, `assets/images/launcher-foreground.png`, `tool/export_launcher_icon.dart`
  - `lib/features/calling/presentation/screens/smart_call_dashboard_screen.dart`

---

## 📚 Recent Distilled Memories (in `.agents/memory/`)

- [Phase 0 — Baseline, Schema Drift Audit & Event Contract](2026-09-26_phase0_baseline_and_contract_map.md)
- [Virtual Numbers Purchase & Real-Carrier MMI Call Diversion Walkthrough](2026-09-24_virtual_numbers_and_mmi_divert_walkthrough.md)
- [Virtual Numbers Purchase & Smart Call Setup Implementation Plan](2026-09-24_virtual_numbers_and_mmi_divert_plan.md)
- [Production-Grade App-to-App Voice Calling Walkthrough](2026-09-24_app_to_app_voice_calling_walkthrough.md)
- [Smart Calling — Full Restructure Walkthrough](2026-09-23_smart_calling_restructure_walkthrough.md)

---

## 🎯 Next Steps on Resume

1. Verify `flutter pub get` and `flutter test` on the target machine (on Mac Mini M4, also run `cd ios && pod install`).
2. Complete verification and commit of the pending onboarding, notification permission, and password recovery changes.
3. For any backend worker changes, see `../backend-sync-wt/` and deploy via `.agents/AGENTS.md`.
