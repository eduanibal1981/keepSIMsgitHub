# KeepSIMs static Android splash

Navy background (`#0A295A`), the existing complete logo, and a white/green KeepSIMs wordmark. The native screen uses the same colors in light and dark system mode.

The Android 12+ icon uses a transparent 288dp canvas with a centered 128x138dp logo. Its 188.2dp diagonal fits within the system's 192dp circular safe area. Android 13+ also prefers showing the icon when the app is opened by an installer. Older Android versions use a matching launch background.

`preview.png` and `preview@3x.png` are illustrative renders, not device screenshots. Android controls the exact icon and branding placement on newer versions.

Run `render-splash.ps1` from this directory to copy the original logo into Android resources, recreate the outlined wordmark, and render the previews. The animation and Flutter pre-video image are unchanged.

Validation: all Android resources compiled and linked against Android API 36; the linked resource table contains the default, Android 12, and Android 13 launch theme variants. Device appearance has not been verified.
