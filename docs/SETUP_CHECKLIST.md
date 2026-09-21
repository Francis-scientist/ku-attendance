# Setup Checklist — Attendance Platform

Everything that must be configured before development can run end-to-end.
Work top to bottom. Items marked **[you]** only you can do (they need your accounts
and your card). Items marked **[claude]** I will do once you approve Phase 1.

---

## A. Decisions I need from you

I can't start Phase 1 without these, because they get baked into identifiers that
are painful to change later.

| # | Decision | My recommendation |
|---|---|---|
| 1 | University name + domain | e.g. `university.ac.ke` |
| 2 | Android `applicationId` | `ke.ac.university.attendance` (reverse domain, no `com.example`) |
| 3 | Admission number format | Confirm `CS001/2024` is exact and universal |
| 4 | Student login email domain | `students.<yourdomain>` — must be a domain the university controls |
| 5 | Term identifier format | `2026-SEM1` |
| 6 | OTP lifetime | 120 s, rotating every 30 s |
| 7 | Default geofence radius | 50 m |
| 8 | Delete `.github/modernize/`? | Yes — it's unrelated leftover tooling |

---

## B. Firebase Console — **[you]**

### B1. Create the project
- Go to https://console.firebase.google.com → **Add project**
- Name: `attendance-platform`
- Google Analytics: **not needed** — skip it

### B2. Upgrade to Blaze (pay-as-you-go) — **required**
- Project settings → **Usage and billing** → **Modify plan** → Blaze
- Attach a payment method

> **Why this is non-negotiable:** all attendance validation runs in Cloud
> Functions, and Functions do not exist on the free Spark plan. Without Blaze,
> the security model of this app cannot be built.

- **Immediately after upgrading**, set a budget alert:
  Google Cloud Console → **Billing → Budgets & alerts** → create budget → **$10/month**
- Realistic cost for one university is a few dollars a month. The budget alert is
  insurance against a runaway loop during development, not an expected expense.

### B3. Enable Authentication
- Build → **Authentication** → Get started
- Enable **Email/Password**
- Leave "Email link (passwordless)" **off**

### B4. Create Firestore
- Build → **Firestore Database** → Create database
- Choose **Production mode** — *not* test mode

> Test mode installs `allow read, write: if true` with a 30-day expiry. That is
> exactly the rule you told me never to ship, and it's easy to forget it's there.

- **Location:** pick the region closest to your users. For East Africa, compare
  `europe-west1` (Belgium) and `asia-south1` (Mumbai).

> ⚠️ **The Firestore location is permanent.** It cannot be changed after
> creation — changing it means creating a new project and migrating all data.
> Decide this one carefully.

### B5. Note your Functions region
- Use the **same region** as Firestore so Functions and database are co-located
  (lower latency, no cross-region egress). Tell me which you chose.

### B6. Later phases — not yet
- **Storage** — only if we add profile photos (Phase 4+)
- **App Check** — Phase 9, needs a release signing certificate first

---

## C. Your machine — **[you]**

Already installed and verified: Flutter 3.47.5, Dart 3.13.4, Firebase CLI 15.30.2,
Node v24.15.0, Android SDK. ✅

Three things to add:

```bash
# 1. FlutterFire CLI — generates firebase_options.dart
dart pub global activate flutterfire_cli

# 2. Log the CLI into the Google account that owns the Firebase project
firebase login

# 3. Confirm the CLI can see your new project
firebase projects:list
```

If `flutterfire` isn't found afterwards, add this to your PATH and restart VS Code:
```
%LOCALAPPDATA%\Pub\Cache\bin
```

### Possible Java issue
You have **JDK 23**; the Gradle build targets **Java 17**. This may be fine. If
Gradle errors on an unsupported class file or JVM version, install **JDK 17** and
point Flutter at it:
```bash
flutter config --jdk-dir "C:\Program Files\Java\jdk-17"
```
Don't pre-emptively install it — wait and see whether the build actually complains.

---

## D. GitHub — **[you]**

- Create an **empty private** repository named `attendance-platform`
  (no README, no .gitignore — I'll generate those)
- Send me the remote URL; I'll `git init`, commit, and push

### What must never be committed
| File | Commit? | Reason |
|---|---|---|
| `google-services.json` | OK | Client config. Contains public identifiers only — security comes from rules and App Check, not from hiding this. |
| `lib/firebase_options.dart` | OK | Same — it's compiled into the APK anyway. |
| **Service account `.json` keys** | 🚫 **Never** | Full admin access to your entire project. Bypasses every security rule. |
| `android/local.properties` | 🚫 No | Machine-specific paths |
| `.env`, `functions/.env` | 🚫 No | Secrets |

I'll configure `.gitignore` to enforce this.

---

## E. For testing — **[you]**

- **A sample CSV of ~10 students** in your real format, with columns:
  admission number, full name, email, programme, year, class group, units.
  Real column headers and real messiness — I'd rather build the importer against
  your actual file than a guess.
- **Two physical Android devices** (yours + one other), or one device plus one
  emulator.

> ⚠️ **Android emulators always report location as mocked.** Our spoofing defence
> rejects mocked locations, so geofencing cannot be properly tested on an
> emulator. I'll add a debug-only bypass flag for development, but **Phase 8
> needs at least one real device** for meaningful testing.

---

## F. What I do once you approve — **[claude]**

| Phase | Work |
|---|---|
| 1 | `git init`, `.gitignore`, dependencies, folder skeleton, theme, Riverpod + go_router shell, change `applicationId` |
| 2 | `flutterfire configure`, `functions/` project, `firestore.rules`, indexes, emulator config, Android permissions |
| 3 | Auth + custom claims + role routing + first admin bootstrap script |

---

## Minimum to unblock Phase 1

You only need these four before I can start:

1. ✅ Answers to **section A** (the 8 decisions)
2. ✅ Firebase project created and **on Blaze** (B1, B2)
3. ✅ `flutterfire_cli` installed and `firebase login` done (C)
4. ✅ Empty GitHub repo created (D)

Sections E and F can follow behind.
