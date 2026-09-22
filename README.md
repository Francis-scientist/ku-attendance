# KU Attendance

A geofenced, OTP-verified class attendance platform for **Kenyatta University**, built
with Flutter and Firebase. Lecturers open time-boxed attendance sessions; enrolled
students mark themselves present only when they are physically inside the session's
geofence and enter the correct one-time code. Administrators provision users, courses
and enrolments and monitor activity live.

- **Package:** `am_in` · **Android applicationId:** `ke.ac.ku.attendance`
- **Firebase project:** `ku-attendance` (Firestore region `africa-south1`)
- Android-first; the codebase also builds for the other Flutter desktop/web targets.

---

## Features

### Student
- See active sessions for enrolled courses in real time.
- Mark attendance: on-device geofence check + OTP, written once per session.
- Attendance history across all courses; per-course attended counts.
- Edit own profile (name, department, faculty, phone).

### Lecturer
- View assigned courses and start an attendance session for any of them
  (configurable radius and duration; a fresh OTP is generated per session).
- Live roster of who has marked in, updating as students arrive.
- Session history.

### Administrator
- Platform overview (student/lecturer/course counts, live sessions).
- Manage students, lecturers, courses and enrolments; enable/disable accounts.
- Reports across the platform.

Every role shares a single **Sign out** action (confirm-then-`signOut()`); the router's
auth redirect returns the user to the login screen and tears down data streams.

---

## Tech stack

| Concern            | Choice |
|--------------------|--------|
| Framework          | Flutter 3.47.5 / Dart ^3.13.4 |
| Auth               | `firebase_auth` (Email/Password) |
| Database           | `cloud_firestore` |
| State management   | `flutter_riverpod` |
| Routing            | `go_router` (redirect-driven auth + role guard) |
| Location           | `geolocator` |
| Connectivity       | `connectivity_plus` |

> `cloud_functions` is a declared dependency and a `functions/` codebase exists, but
> **Cloud Functions are not deployed** — see [Project status](#project-status--limitations).

---

## Project structure

```
lib/
├── core/            # constants, error mapping, theme, utils (geo, formatters)
├── models/          # AppUser, Course, Enrollment, AttendanceSession, AttendanceRecord
├── providers/       # Riverpod providers (auth, data streams, repositories)
├── repositories/    # Firestore access (auth, user, course, enrollment, attendance)
├── routes/          # go_router config + role-based redirect
├── screens/         # admin/ · lecturer/ · student/ · auth/ · common/
├── services/        # location, connectivity
└── widgets/         # shared UI (buttons, fields, state views, sign-out, chips…)
```

Data flows one way: **screens → providers → repositories → Firebase**. Screens never
touch Firebase directly; repositories never know about the UI.

---

## Data model (Firestore)

| Collection | Doc id | Notes |
|------------|--------|-------|
| `users` | `uid` | role, profile; role is authoritative and non-self-escalatable |
| `courses` | auto | catalogue; a course references its assigned `lecturerId` |
| `enrollments` | `courseId__studentId` | deterministic id → a student enrols once per course |
| `attendanceSessions` | auto | one open session per class meeting |
| `attendanceSessions/{id}/records` | `studentId` | one record per student → structural dedupe |
| `attendanceSessions/{id}/private/otp` | `otp` | locked; only owning lecturer/admin can read |

---

## Security model

Enforced by [`firestore.rules`](firestore.rules) — there is no `allow … if true` anywhere.

- **Roles are authoritative** in `users/{uid}` and cannot be self-escalated. A client may
  self-register only as `student` or `lecturer` and can never change their own role,
  active flag or email afterwards. Admins are provisioned server-side.
- **OTP is never exposed to students.** It lives in a locked `private/` subcollection.
  Rules validate a student's submitted code with `get()` (which bypasses read rules), so
  the device that submits the code never receives it.
- **Attendance records are write-once and server-verified.** A student may create only
  their **own** record, once, and only while: they are an active student, enrolled in the
  session's course, the session is active and before its `expiresAt` (server clock), and
  the submitted OTP matches. Records can never be edited or deleted from a client.
- **`presentCount`** can be incremented by exactly one, only in the same commit that
  creates the caller's own record (tied together with `getAfter`), so the counter can't
  be inflated without a real record.
- A student's cross-session history uses a `collectionGroup('records')` query authorized
  on the `studentId` **field** (matching the query's filter, as collection-group rules
  require).

> **Geofence caveat:** Firestore rules have no trigonometry, so the distance check is
> enforced **on-device only** in the current build. Move it server-side when the
> `markAttendance` Cloud Function is deployed (see below).

---

## Attendance flow

1. **Lecturer** starts a session for a course → app writes the session + a fresh OTP to
   the locked subcollection and shows the code + a countdown.
2. **Student** opens the active session, the app takes a GPS fix and checks the geofence
   locally, then writes their record (`studentId`, `courseId`, `submittedOtp`, server
   timestamp) and bumps `presentCount` in one transaction.
3. Rules re-verify identity, enrolment, session state, expiry and OTP server-side; a
   duplicate is impossible because the record's id **is** the student's uid.
4. **Lecturer** sees the live roster update; **student** sees "Attendance recorded".

---

## Getting started

### Prerequisites
- Flutter 3.47.x (Dart ^3.13.4) — `flutter doctor` should be clean for Android.
- A physical Android device or emulator with **location services enabled** (the geofence
  needs a real GPS fix; grant the app "while in use" location permission).
- Firebase CLI (`npm i -g firebase-tools`) for deploying rules/indexes.

### Setup
```bash
git clone <repo-url>
cd am_in
flutter pub get
```

Firebase config is already generated for the `ku-attendance` project
(`lib/firebase_options.dart`, `android/app/google-services.json`). To point the app at a
**different** Firebase project, re-run FlutterFire:
```bash
dart pub global activate flutterfire_cli
flutterfire configure
```
Then enable **Email/Password** sign-in in the Firebase console.

### Run
```bash
flutter run            # on the selected device
```

### First accounts
Students and lecturers self-register from the app. **Admins are provisioned manually** —
create the Auth user in the Firebase console, then add a `users/{uid}` document with
`role: "admin"` and `isActive: true`.

---

## Deploying Firestore rules & indexes

Rules and composite indexes must be deployed for queries (student/lecturer history,
collection-group reads) to work:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

This runs on the free **Spark** plan. Do **not** run a full `firebase deploy` unless you
intend to deploy Cloud Functions, which requires the paid Blaze plan.

---

## Testing

```bash
flutter analyze        # static analysis (expected: no issues)
flutter test           # widget + unit tests
```

---

## Project status & limitations

- **Cloud Functions are not deployed.** Attendance marking currently runs **client-side**
  (the "Option B" path): the student writes their own record directly, with all integrity
  checks except the geofence enforced by Security Rules. This keeps the app fully runnable
  on the free Spark plan.
- **Geofence is client-enforced only** for the same reason. When `functions/markAttendance`
  is deployed on Blaze, route marking through it, enforce the geofence server-side, and
  tighten the `records` rule back to `allow write: if false`.
- Passwords are never stored in Firestore — Firebase Authentication owns credentials. No
  service-account keys live in the app.

