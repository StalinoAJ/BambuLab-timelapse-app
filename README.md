# BambuLab Timelapse App

A Flutter camera app that listens for `0` and `1` trigger values from an **ESP32** and captures a photo whenever `1` is received, saving shots into a **timestamp-named folder** (e.g. `2026-11-25_11-45-00/`).

## Features
- **3 Trigger Modes**:
  - **BLE (Bluetooth Low Energy)**: Connects directly to the ESP32 (`BambuTimelapse-ESP32`) and subscribes to GATT notifications (`"0"` / `"1"`).
  - **Wi-Fi WebSocket**: Connects to an ESP32 WebSocket server (e.g. `ws://192.168.4.1:81`).
  - **Simulator**: Built-in `0` / `1` buttons in the app so you can test camera capture and timestamped folder saving without hardware.
- **Smart Trigger Processing**:
  - **Rising-edge detection (`0 -> 1`)** by default so holding `1` does not spam duplicate shots (can be toggled off in Settings).
  - **Configurable cooldown** (default `500 ms`) to debounce mechanical switches.
- **Timestamped Folder Saving**:
  - **Folder per session** (default): Creates a folder named with the session start timestamp (e.g., `timelapses/2026-11-25_11-45-00/shot_0001_11-45-03.jpg`).
  - **Folder per shot** (optional in Settings): Creates a separate timestamp-named folder for each captured photo.

## Building for iOS & Android from Windows (GitHub Actions)

1. Push this repository to GitHub (`main` or `master` branch) or trigger **Build & Release (Android APK + iOS IPA)** ([.github/workflows/build.yml](.github/workflows/build.yml)) manually from the **Actions** tab.
2. Once finished, download the installers directly from the **Releases** page on GitHub (or from the workflow run's **Artifacts**):
   - **iOS**: `bambulab_timelapse_unsigned.ipa` — sideload onto your iPhone using **Sideloadly** or **AltStore**.
   - **Android**: `app-release.apk` — install directly on your Android phone.

## Getting Started (Local Mac / Android)

1. **Generate platform runner files** (if `android/` or `ios/` Gradle/Xcode files are not yet generated):
   ```bash
   flutter create . --project-name bambulab_timelapse
   ```
   *(Note: keep `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist` permissions intact.)*

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run tests**:
   ```bash
   flutter test
   ```

4. **Run on a physical device** (required for camera & BLE):
   ```bash
   flutter run
   ```

## ESP32 Setup
Flash [esp32_firmware/bambulab_trigger.ino](esp32_firmware/bambulab_trigger.ino) to your ESP32.
- Default mode is **BLE** (`BambuTimelapse-ESP32`).
- Connect your printer trigger switch/optocoupler to `GPIO 4` and `GND` (active LOW).
- When triggered, the ESP32 sends `"1"`, and when released it sends `"0"`.
