# lib/ layout guide

Attendance-first codebase: IoT beacon scanning (ESP32 `FindMoSer_<Room>`) + Firestore receipts for students, faculty and admin.

## core/
App-wide primitives that every feature may import.
- `app_constants.dart` — collection names, BLE prefix, thresholds (`attendanceDwellSeconds: 15`, RSSI `-70`), route durations.
- `app_routes.dart` — the only named routes: splash, login, register, account-access.
- `app_theme.dart` — soft neumorphic theme.
- `campus_time.dart` — Cebu (UTC+8) wall-clock/campus date. All session days/exports use this.
- `firebase_options.dart` — generated Firebase config.
- `user_model.dart` — `AppUser` (role, facultyApproved, deviceId).
- `room_model.dart` — room→beacon mapping.

## features/
- **auth/** — identity and devices: splash/login/register/account-access screens, `auth_service`, the fail-closed `account_access` gate, `device_id_service`, `device_change_service`, profile panel + gradient button.
- **attendance/** — the pilot itself. `models/` (receipt, session, schedule/JoinCode), `services/` (scan submission w/ outbox, dwell tracker, session open/close/correct, BLE scanner, beacon stability), `providers/` (live attendance streams, campus clock), `screens/student/` (dashboard, scan screen, home/attendance/profile tabs), `widgets/` (cards, class picker, join dialog, enrollment sheet, dwell ring, export button).
- **faculty/** — faculty role UI only: dashboard, attendance/schedule/profile tabs, live roster screen with corrections.
- **schedule/** — faculty schedule tab + dialogs (add/delete class, join code).
- **assistant/** — student chat that answers "where is this teacher" from `faculty_presence` (Firestore, server-sourced; deterministic, no LLM).
- **presence/** — faculty-side sharing: presence service/provider, `ble_provider` (scanner + `FacultyLocationUpdater`), `location_policy`, forecasts (AVL predictor), sharing settings widget.

## shared/
- `services/firestore_service.dart` — profile/schedule/location facade bridging features.
- `providers/auth_provider.dart` — auth state, current user/profile streams.
- `widgets/` — `app_navigation` (labeled nav/rail) and `ble_readiness_banner` (permission stepper).

## Cross-feature rules
- Import across features explicitly (`../attendance/services/...`); never reach into another feature's private subfolder.
- Server is authoritative: reads before acting come from `Source.server` (see `auth_service.verifyCurrentSession`, `firestore_faculty_repository`).
- Detailed processes: `docs/attendance-pilot.md`.
