# FindMoSer

Proximity-based student attendance pilot for Cebu Eastern College, built with Flutter, Riverpod, Firebase Auth and Firestore. Six static ESP32 C3 Mini classroom beacons advertise names such as `FindMoSer_Room305`. The Android app performs the scan; the ESP32 does not run Flutter.

## Current workflow

- Faculty accounts require trusted operator approval. Faculty create schedules, enroll students and open/close attendance windows.
- Students register one Android phone and select an enrolled open session. The scanner checks the exact room, a pilot -70 dBm threshold and 15 seconds of continuous fresh readings. Leaving the app or losing the beacon resets unfinished dwell.
- Test beacon is diagnostic only. It never creates an official record.
- Deterministic session/student IDs prevent duplicate student records. Firestore rules verify enrollment, session deadline, owner fields and registered device consistency.
- Receipts show pending, confirmed or rejected. A server timestamp is required for confirmation; a local outbox preserves pending/rejected state after restart. Cached copies are labeled.
- Faculty see live session receipts, search enrollment, correct existing statuses with an immutable reason audit, and share server-confirmed CSV exports.
- The active app uses soft neumorphic surfaces with labeled actions, readable text and reduced-motion support. Old locator/AI screens are absent from active navigation; historical source and data have not been bulk-deleted.

Device registration and BLE proximity reduce some casual misuse. They do **not** prove who is carrying a phone, authenticate static beacon broadcasts, or attest unmodified clients. Do not claim proxy-proof attendance.

## Develop and validate

Use Flutter stable with Dart >=3.12.2 and the Android SDK. The existing Firebase platform files point to a configured project; verify that project before deployment.

```sh
flutter pub get
flutter analyze
flutter test
npm ci --prefix test_rules
npm test --prefix test_rules
flutter build apk --release
```

Rules tests run solely against the `demo-findmoser` local emulator. Java 17 and a compatible Node runtime are required by the pinned Firebase test tools. Firebase rules are **not deployed** by tests or APK builds.

APK output: `build/app/outputs/flutter-apk/app-release.apk`. This repository currently signs release-mode APKs with the existing debug key for internal testing. Keep that same key for test updates because Android ID depends on signing identity. Before external production distribution, configure a private release key and a device-binding migration plan; do not silently change the signing key halfway through the pilot.

To capture sample-data UI previews:

```sh
PREVIEW_OUTPUT=/tmp/findmoser-ui-preview flutter test test/attendance_ui_test.dart
```

## Setup before school testing

Read [the attendance pilot guide](docs/attendance-pilot.md) for rule/index deployment, initial account approval, exact beacon names, test cases and thesis evidence. Read [device registration and replacement](docs/device-binding.md) for existing-account migration. Existing faculty accounts require `facultyApproved: true`; existing student hash IDs require review with the new APK. This intentionally fails closed until accounts and deployed rules match the new schema.

[Earlier locator notes](docs/legacy-locator-notes.md) are retained as historical context, not a description of the current attendance app. The existing Chapter 1/2 documents must be reframed and physical results collected before presenting attendance claims in Chapter 3.
