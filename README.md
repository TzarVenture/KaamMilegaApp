# KaamMilega — Flutter mobile app

KaamMilega is an Indian jobs and gig-work platform. This repository is the **Flutter mobile app** for **candidates, guests and gig workers** (not recruiters or admins): jobs, applications, interviews, profile, networking, real-time chat, experts / mentorship, events and tickets, Instant Milega spot gigs, skills and a Razorpay-backed wallet.

- App id: `com.kaammilega.app` · package `kaam_milega`
- Backend: separate Go service **km-backend** at `https://api.kaammilega.com/api` (repository `TzarVenture/KaamMilega`, developed by another developer — **never edited from here**)
- Stack: Flutter, Riverpod 3, GoRouter, Dio, SharedPreferences, connectivity_plus, razorpay_flutter, speech_to_text, geolocator

## Where to find what (for people and AI tools)

| Question | Read |
|---|---|
| What is done and what is pending? | [AI_QUICK_START.md](AI_QUICK_START.md) → "Status at a glance", then [FEATURE_STATUS.md](FEATURE_STATUS.md) |
| Feature tracker in Google-Sheet format | [flutter_app_feature_tracker.md](flutter_app_feature_tracker.md) / `.csv` |
| Bugs, backend problems, what changed recently | [KNOWN_ISSUES.md](KNOWN_ISSUES.md) (incl. "Work 26–30 Sep 2026" and the verification log) |
| Which backend endpoints the app uses | [API_INTEGRATION_STATUS.md](API_INTEGRATION_STATUS.md) (overview) · [API_CONTRACT.md](API_CONTRACT.md) (fields) |
| How the code is organised | [architecture.md](architecture.md) |
| Rules for AI coding agents | [CLAUDE.md](CLAUDE.md) |

Docs last updated **30 September 2026**. Source code wins over the docs.

## Run and check

```
flutter pub get
flutter run
dart format .
flutter analyze
flutter test
```

Release builds still use the debug signing key (Android) and have no iOS signing team yet — see KNOWN_ISSUES "Build/Environment Issues".
