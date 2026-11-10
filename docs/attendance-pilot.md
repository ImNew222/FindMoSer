# Attendance pilot guide

Operational checklist for the FindMoSer BLE attendance pilot at Cebu Eastern College.

## Deploy steps

1. `cd test_rules && npm ci && npm test` — all rule tests must pass against the `demo-findmoser` emulator (requires Java 17 + Node).
2. Deploy Firestore rules + indexes from the app repo root:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes
   ```

   Confirm the deployed rules include `attendance_marks` and the device-change adjudication branches. The web admin console (`../findmoser-admin`) uses the same project.
3. Build and install the release APK (keep the same signing key — device bindings depend on it):

   ```sh
   flutter build apk --release
   ```

## Beacon setup

- Six static ESP32 C3 Mini beacons. Advertised name format: `FindMoSer_Room###` — the suffix must match the schedule's Room ID exactly (for example `FindMoSer_Room305`).
- Faculty schedules store the exact room string; attendance verifies room name, a −70 dBm threshold, and 15 seconds of continuous fresh readings.

## Accounts

- Bootstrap one admin row in `users` with `role: 'admin'` (service account or console).
- Faculty sign up in-app then an admin approves them via the console (Users → Faculty Approvals).
- Students register in-app; registration atomically binds their phone (16-hex device ID). One phone = one student account.
- Re-runs of classroom data can be reset with `npm run reset` from `../` (monitor folder). `node reset-data.js --devices` also clears bindings so the same phones can re-register. `node reset-data.js --all` additionally deletes every student and teacher account (admins are kept).

## Attendance flow (thesis evidence)

1. Faculty schedule a class with exact room ID. The card shows the Cebu-time window and the 6-character class code.
2. Students join with the code or are bulk-pasted into enrollment (max 200).
3. Faculty open attendance; the default window follows the class period length (10–240 min).
4. Students open the session card, keep the app foregrounded, and submit a receipt; Firestore rules enforce enrollment, deadline, dwell, RSSI, device binding, and create-only IDs (`sessionId_studentId`).
5. Faculty close attendance from the attendance tab. Students without receipts show "Absent (no receipt)" and can be given an auditable faculty mark (absent, late, or excused) — marks never edit scan evidence.
6. Export server-confirmed CSV per session (includes absent rows + marks, with a Source column) or by class over a date range.

## Test cases to record on video

- Duplicate scan attempt is refused (evidence is create-only).
- Wrong room / weak signal / short dwell refused.
- Scan from another session's room fails.
- Offline submission stays pending; connecting confirms with a server timestamp.
- Leaving the app mid-dwell resets scanning and shows the background warning toast on return.
- Closed session: roster shows absent students; faculty mark with a reason; CSV includes the mark.
- Device change request: student files from Profile, admin approves in console, new phone registers, old phone stops working.
