# Device registration and replacement

How FindMoSer binds one student account to one Android phone, and how a lost or replaced phone is re-bound safely.

## Registration binding

- On registration the app computes a 16-hex [device identifier](https://pub.dev/packages/flutter_udid-style) (install-stable, survives app updates).
- Registering creates the auth user, the `users/{uid}` profile with that `deviceId`, and `device_bindings/{deviceId}` (`uid` = student) **in a single atomic transaction**. Firestore rules require all three: a profile with an unknown/foreign binding is refused.
- `device_bindings` create-only: no client may update or delete a binding. Scans re-verify that `users/{uid}.deviceId == deviceId` and `device_bindings/{deviceId}.uid == uid`. Editing `role`, `facultyApproved`, or the device outside a sanctioned change is impossible for students.
- Faculty accounts are never device-bound; they sign in from any device and are approved by an admin.

## Lost or replaced phone (device change flow)

1. The student files a request inside the app (Profile → Account Access) with the new device ID and a 10–500 character reason, while still signed in on the lost/replacement phone. The request is visible in `device_change_requests/{uid}` with `status: 'pending'`.
2. An admin opens the console (`../findmoser-admin`) → **Device Requests**:
   - The row shows current device → new device, the reason, and when it was filed.
   - Approve runs one atomic batch: `users/{uid}.deviceId = newDeviceId`, `device_bindings/{newDeviceId}` created, and the request closed `approved` with `decidedBy`, `decidedAt`, and `previousDeviceId` recorded. Firestore rules reject any partial version.
   - Reject closes the request `rejected` with the same audit fields; the student keeps the old binding and can refile.
   - If the new device is already bound to someone else, the console refuses with a clear message; verify with on-site staff before proceeding.
3. The student then registers/logs on the new phone; the old phone's access is dead.

## Notes

- Standalone admin edits to `users/{uid}.deviceId` are only allowed when a matching `approved` request exists — no ad-hoc rebinding.
- The old `device_bindings/{previousDeviceId}` document lingers (bindings are immutable). It is harmless: no profile references it. `node reset-data.js --devices` clears bindings when doing a clean re-registration session.
- Changing the APK signing key invalidates device identities for all installs; never switch keys mid-pilot without a formal migration.
