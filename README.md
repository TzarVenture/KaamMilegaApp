# KaamMilega — Flutter mobile app

KaamMilega is an Indian jobs and gig-work platform. This repository is the **Flutter mobile app** for **candidates, guests and gig workers** (not recruiters or admins): jobs, applications, interviews, profile, networking, real-time chat (attachments, read ticks, typing), in-app notifications, experts / mentorship (incl. Expert Dashboard and Pro Expert plans), events and tickets, Instant Milega spot gigs, skills, a Razorpay-backed wallet and a community Posts section (UI on local demo data until the backend has a posts API).

- App id: `com.kaammilega.app` · package `kaam_milega`
- Backend: separate Go service **km-backend** at `https://api.kaammilega.com/api` (repository `TzarVenture/KaamMilega`, developed by another developer — **never edited from here**)
- Stack: Flutter, Riverpod 3, GoRouter, Dio, web_socket_channel, SharedPreferences, connectivity_plus, razorpay_flutter, image_picker, file_picker, speech_to_text, geolocator

## Where to find what (for people and AI tools)

| Question | Read |
|---|---|
| What is done and what is pending? | [AI_QUICK_START.md](AI_QUICK_START.md) → "Status at a glance", then [FEATURE_STATUS.md](FEATURE_STATUS.md) |
| Feature tracker in Google-Sheet format | [flutter_app_feature_tracker.md](flutter_app_feature_tracker.md) / `.csv` |
| Bugs, backend problems, what changed recently | [KNOWN_ISSUES.md](KNOWN_ISSUES.md) (incl. "Work 7–13 Oct 2026", "Work 1–6 Oct 2026" and the verification log) |
| Which backend endpoints the app uses | [API_INTEGRATION_STATUS.md](API_INTEGRATION_STATUS.md) (overview) · [API_CONTRACT.md](API_CONTRACT.md) (fields) |
| How the code is organised | [architecture.md](architecture.md) |
| Rules for AI coding agents | [CLAUDE.md](CLAUDE.md) |

Docs last updated **13 October 2026** (app `main` @ `9578c5c` (9 Oct) **plus uncommitted work of 10–13 Oct** (the owner commits) · backend monorepo `main` @ `b86e973` (read-only)). Source code wins over the docs.

## Run and check

```
flutter pub get
flutter run
dart format .
flutter analyze
flutter test
```

If a build stops with Java "insufficient memory" (`hs_err_pid*.log` / `replay_pid*.log` files appear in the project folder), Gradle ran out of RAM — see KNOWN_ISSUES "Build/Environment Issues". The log files can be deleted.

Release builds still use the debug signing key (Android) and have no iOS signing team yet — see KNOWN_ISSUES "Build/Environment Issues".
