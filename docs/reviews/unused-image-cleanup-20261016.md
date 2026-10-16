# Unused image cleanup — 16 October 2026

Removed 317 images (79.82 MiB) after tracing current Flutter screens, tests, launcher generation settings and native resources. Of these, 290 were already committed (71.48 MiB); 27 were staged additions that have been removed from the index. The remaining 56 images are used app or platform assets, including the two pending calling-card illustrations.

| Removed group | Images | Reason |
| --- | ---: | --- |
| Root screenshots and dashboard mockups | 62 | Development captures; no app consumer. |
| `.gemini` / `.zcode` screenshots | 2 | Development captures. |
| `output/` images | 56 | Design concepts and generated review captures, not golden-test inputs. |
| `test-results/protection-console/` images | 179 | Historical QA captures, not test fixtures. |
| `assets/images/onboarding/` | 10 | No current or committed app/test references; onboarding uses Flutter widgets and the launcher foreground. |
| `assets/images/start.png`, `start3.png`, `startinwhite.png` | 3 | Obsolete, unreferenced startup artwork. |
| Android `mipmap-*/ic_launcher.png` | 5 | Legacy icons; the manifest and widget preview use `launcher_icon`. |

Retained Flutter images: `Logo.png`, `esim.png`, `presplash.png`, `launcher-icon.png`, `launcher-foreground.png`, `sim_protection.svg`, `call_dialer.png` and `free_app_call.png`. Native launcher/adaptive-icon, splash, iOS/macOS asset-catalog, web manifest/favicon and Windows icon resources remain. Video, sound and font resources are outside this image cleanup.

Removed the obsolete onboarding directory from `pubspec.yaml`. Scoped `.gitignore` rules keep generated images in the root, `output/` and `test-results/` out of future commits while allowing app assets and text reports. Historical review links to deleted images are now plain capture identifiers. Screenshot-producing tests still run; their generated images are local ignored artifacts.

Validation:

- 26 focused calling-card and dashboard tests passed, including image loading and responsive dashboard layouts.
- `flutter build bundle --debug` passed with the cleaned asset declarations.
- All literal Flutter asset references in both current source and the committed base resolve; iOS/macOS asset-catalog filenames resolve.
- Ignore checks accept app assets and text reports, and exclude future screenshot captures.
- Unrelated staged implementation work is excluded from the cleanup commit.

The GitHub change is a normal deletion commit. Earlier commits retain their historical image content.
