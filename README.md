# Psiphon Flutter

Custom Flutter Android client featuring the dark OLED + radial glowing Orb aesthetic inspired by Psiphon 4, built on top of the open-source Psiphon 3 tunnel core (`ca.psiphon.aar`), `badvpn` `tun2socks` JNI, and all **49 Psiphon egress countries unlocked** for individual selection.

## Key Features
- **Unrestricted Region Selection**: Choose **Best performance** or manually select any of the 49+ supported countries without `autoSelectOnly` restrictions, with live server availability indicators.
- **Psiphon 4 Dark Aesthetic**: Pure OLED black (`#000000`), radial-gradient interactive **Orb**, tactile **Slide-to-Connect** bar, vector SVG flags (`flutter_svg`), live throughput waveform telemetry, and streaming core logs.
- **Zero Non-Free Binaries**: Uses the open-source `ca.psiphon.aar` tunnel library, `badvpn` `tun2socks` NDK sources (`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`), and community bootstrap server entries (`server_list.hex`).

## Building via GitHub Actions (No Local Flutter SDK Needed)
This repository ships with [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml), which installs Java 17, Android SDK 35 + NDK `27.2.12479018`, and the latest `stable` Flutter SDK on Ubuntu runners to:
1. Run `flutter analyze --fatal-infos` and `flutter test`
2. Compile native `libtun2socks.so` for all 4 ABIs (`armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`)
3. Produce debug, split-per-ABI release, and universal release APKs under workflow artifact **`psiphon-flutter-apks`**

You can trigger builds on push or manually from the **Actions** tab (or via `gh workflow run build-apk.yml`).

## Building Locally (If Flutter SDK is Installed)
```bash
flutter pub get
flutter analyze --fatal-infos
flutter test
flutter build apk --release
```

## License
Licensed under the **GNU General Public License v3.0 (GPL-3.0)** — see [LICENSE](LICENSE).
