# KeepSIMs launcher icon

The icon keeps the blue shield, green protective rim and orbit, white SIM card with a gold chip, and green check badge. A transparent foreground and explicit 22% Android inset replace the full-size foreground that was being cropped by the launcher.

Artwork was edited with the built-in image-generation tool. The original `assets/images/Logo.png` and the previously approved static splash remain intact.

Production assets:

- `assets/images/launcher-foreground.png`: generated transparent foreground, used by Android adaptive icons.
- `assets/images/launcher-icon.png`: opaque 1024px navy square export for iOS and older Android launchers.
- `pubspec.yaml`: persistent launcher generation settings.

Regenerate by running `dart run tool/export_launcher_icon.dart` followed by `dart run flutter_launcher_icons`. The exporter measures every nontransparent pixel and rejects foreground settings that exceed the 33dp radius of Android's circular safe area. See [Android's adaptive icon requirements](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).

`preview.png` is an illustrative rendering of the actual generated Android foreground under circular, squircle, and rounded-square masks, including the adaptive icon's 108dp-to-72dp viewport scaling. It is not a device screenshot.

`validation.json` records the measured safe-area result. `prompts.md` contains the exact image-generation prompt. `before-foreground.png` preserves the previous artwork for the comparison preview.

Validation completed: every nontransparent source pixel fits within a 32.53dp radius after the configured inset, below the 33dp limit. Android resources compiled and linked against API 36, and the linked launcher drawable contains the 22% inset. All Android densities and the existing iOS icon sizes were regenerated. Device appearance and an iOS build have not been verified.
