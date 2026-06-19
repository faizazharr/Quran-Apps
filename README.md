# Quran Player

A production-ready Flutter app for streaming all 114 Surah recitations from the public
[AlQuran Cloud](https://alquran.cloud) API. Built with Clean Architecture, BLoC state
management, offline-first caching, and a fully automated CI/CD pipeline to Google Play.

---

## Table of Contents

1. [Features](#features)
2. [Screenshots](#screenshots)
3. [Tech Stack](#tech-stack)
4. [Architecture](#architecture)
5. [Project Structure](#project-structure)
6. [Getting Started](#getting-started)
7. [Makefile Commands](#makefile-commands)
8. [Build & Release](#build--release)
9. [CI/CD Pipeline](#cicd-pipeline)
10. [Git Hooks](#git-hooks)
11. [Configuration](#configuration)
12. [API & CDN Details](#api--cdn-details)
13. [Versioning Policy](#versioning-policy)
14. [Security](#security)
15. [Localization](#localization)
16. [Testing](#testing)

---

## Features

### Playback
| Feature | Details |
|---------|---------|
| **Stream 114 Surahs** | Full-Surah MP3 streamed via Islamic Network CDN |
| **8+ Reciters** | Per-Surah reciter picker via bottom sheet |
| **Play / Pause / Seek** | Live seek bar with buffered position |
| **Playback speed** | Tap-to-cycle (0.75× → 1.0× → 1.25× → 1.5× → 2.0×); long-press for direct select |
| **Auto-play next Surah** | `PlayerRepeatMode.all` auto-advances when a Surah ends |
| **Background audio** | Lockscreen controls + notification via `just_audio_background` |
| **Sleep timer** | Count-down timer or end-of-Surah auto-stop |

### Browse & Search
| Feature | Details |
|---------|---------|
| **Fuzzy search** | `SearchNormalizer` strips diacritics, collapses vowels — "al fatihah" matches "Al-Faatiha" |
| **Surah-first list** | 114 rows (not 912). Reciter chosen at play time |
| **Paginated scroll** | 20 Surahs per page; load-more fires on scroll (debounced 200 ms) |
| **Pull-to-refresh** | Re-fetches remote data and refreshes cache |

### Ayah & Content
| Feature | Details |
|---------|---------|
| **Ayah reader** | Per-Surah verse-by-verse view with Arabic text |
| **Copy ayah** | Long-press any ayah to copy Arabic text to clipboard |
| **Translation** | English and Indonesian translations per ayah |
| **Quote of the Day** | Random inspirational Quranic verse on the home screen |

### Offline & Downloads
| Feature | Details |
|---------|---------|
| **Offline-first cache** | sqflite metadata + LockCachingAudioSource for audio |
| **Download Surahs** | Download audio for offline playback with progress indicator |

### Bookmarks & Activity
| Feature | Details |
|---------|---------|
| **Bookmarks** | Save Surahs; dedicated Bookmarks screen |
| **Continue listening** | "Continue listening" chip resumes last played position |
| **Activity tracking** | Last-played Surah, reciter, and position persisted locally |

### UI & Settings
| Feature | Details |
|---------|---------|
| **Responsive layout** | Single-pane (phone) ↔ two-pane with Now Playing pane (tablet / landscape) |
| **Material 3** | Gradient hero headers, shimmer loaders, animated player panel |
| **Dark / Light theme** | System-adaptive theme via Material 3 tokens |
| **Settings screen** | Theme, language, and playback preferences |
| **Localization** | English (`en`) and Indonesian (`id`) |

---

## Tech Stack

| Concern | Package |
|---------|---------|
| State management | `flutter_bloc ^9.1.1` + `equatable ^2.0.8` |
| Audio | `just_audio ^0.10.5` + `just_audio_background 0.0.1-beta.17` |
| Local DB | `sqflite ^2.4.2` + `path_provider ^2.1.5` |
| Networking | `http ^1.6.0` wrapped by `NetworkClient` |
| Connectivity | `connectivity_plus ^7.1.1` |
| Dependency injection | `get_it ^9.2.1` |
| Notifications | `flutter_local_notifications ^18.0.0` + `timezone ^0.9.0` |
| Permissions | `permission_handler ^11.3.0` |
| Localization | `flutter_localizations` + `intl ^0.20.2` |
| Linting | `flutter_lints ^6.0.0` + project rules |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI (Widgets)                             │
│  SearchScreen · SurahDetailPage · AyahView · BookmarksScreen    │
│  PlayerPanel · NowPlayingPane · SettingsScreen · QuoteCard      │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │  events / states
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       BLoCs (features/)                         │
│  SearchBloc   PlayerBloc   BookmarkBloc   DownloadBloc          │
│  AyahBloc     QuoteBloc    ActivityBloc   SettingsBloc          │
│  SleepTimerBloc                                                 │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │  Result<T> / Streams
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Repositories (data/)                         │
│  QuranRepositoryImpl — cache-first, offline fallback            │
│  BookmarkRepositoryImpl · AyahRepositoryImpl                    │
│  SettingsRepositoryImpl · ActivityRepositoryImpl                │
└─────────────────────────────────────────────────────────────────┘
        ▲                    ▲                     ▲
        │                    │                     │
┌────────────────┐  ┌────────────────┐  ┌──────────────────────┐
│ RemoteData     │  │ LocalData      │  │ Services             │
│ Source         │  │ Source         │  │ AudioPlayerService   │
│ (NetworkClient)│  │ (sqflite)      │  │ DownloadService      │
│ GET /surah     │  │ surahs +       │  │ QuoteService         │
│ GET /edition   │  │ editions +     │  │ DatabaseService      │
│ GET /ayah      │  │ bookmarks +    │  └──────────────────────┘
└────────────────┘  │ downloads      │
                    └────────────────┘
```

### Key design choices

| Choice | Rationale |
|--------|-----------|
| **Interfaces everywhere** | `IQuranRepository`, `IAudioPlayerService`, `IConnectivityService`, etc. — swappable without touching call sites |
| **`Result<T>` sealed type** | `Success<T>` / `Failure<T>` — no nullable returns for failure paths, no surprise exceptions reaching BLoC |
| **`AppException` hierarchy** | `RemoteException` / `OfflineException` / `LocalException` / `PlaybackException` / `UnknownException`, each with a `userMessage` |
| **Cache-first repository** | Return local cache immediately; refresh in background when online. Offline + empty cache → `OfflineException` |
| **Surah-first list** | 114 rows (not 912 = 114 × 8). Reciter deferred to play time, reducing cognitive load |
| **Paginated BLoC** | `SearchBloc` manages `visibleCount`; `SearchLoadMoreRequested` fired by debounced `ScrollController` |

---

## Project Structure

```
lib/
├── main.dart                         # Entry: ensureInitialized → DI → runApp
├── app.dart                          # Root MaterialApp + global BlocProviders
│
├── core/
│   ├── config/app_config.dart        # --dart-define config + HTTPS guard
│   ├── constants/api_constants.dart  # CDN URL builder
│   ├── di/service_locator.dart       # GetIt registrations (all as interfaces)
│   ├── errors/app_exception.dart     # Sealed AppException hierarchy
│   ├── network/                      # NetworkClient (HTTPS, timeout, error map)
│   ├── responsive/responsive.dart    # Breakpoints + ResponsiveInfo
│   ├── result/result.dart            # sealed Result<T> + runCatching
│   ├── theme/app_theme.dart          # Material 3 tokens + brand gradient
│   └── utils/                        # DurationFormatter · SearchNormalizer · RandomService
│
├── data/
│   ├── datasources/                  # Remote + local interfaces + implementations
│   ├── models/                       # Surah · Edition · Track · Ayah · Bookmark
│   │                                 # DownloadRecord · AppSettings · Quote · Translation
│   ├── repositories/                 # QuranRepo · BookmarkRepo · AyahRepo
│   │                                 # SettingsRepo · ActivityRepo (cache-first)
│   └── services/                     # AudioPlayerService · DownloadService
│                                     # DatabaseService · QuoteService · CloudSyncService
│
├── features/
│   ├── activity/                     # ActivityBloc + LastActivityCard widget
│   ├── ayah/                         # AyahBloc + AyahView (verse reader + copy)
│   ├── bookmark/                     # BookmarkBloc + BookmarksScreen
│   ├── download/                     # DownloadBloc (enqueue / progress / delete)
│   ├── player/                       # PlayerBloc + PlayerPanel
│   ├── quote/                        # QuoteBloc + QuoteCard
│   ├── search/                       # SearchBloc + SearchScreen + widgets
│   ├── settings/                     # SettingsBloc + SettingsScreen + SleepTimerDialog
│   ├── sleep_timer/                  # SleepTimerBloc
│   └── surah/                        # SurahDetailPage (ayahs + download button)
│
├── l10n/                             # ARB files + generated AppLocalizations
└── shared/widgets/                   # EmptyStateView · NowPlayingPane · PlayerSeekBar

test/
├── core/                             # result_test · duration_formatter_test · search_normalizer_test
├── data/                             # track_test · quran_repository_test
└── features/                         # player_bloc_test · search_bloc_test
                                      # download_bloc_test · sleep_timer_bloc_test

.github/workflows/
├── ci.yml                            # Lint + Test + Build (push to main + PRs)
├── cd-android.yml                    # Validate → Build → Sign → Deploy to Play Store
├── cd-ios.yml                        # iOS build pipeline
└── promote-android.yml               # Promote between tracks

.githooks/
├── pre-commit                        # Auto-format + re-stage changed files
└── pre-push                          # Format check + analyze + test (mirrors CI)

docs/
├── ARCHITECTURE.md
├── CHANGELOG.md
├── SECURITY.md
└── VERSIONING.md
```

---

## Getting Started

### Prerequisites

| Tool | Version |
|------|---------|
| Flutter SDK | **3.x stable** (latest) |
| Dart | **3.11+** |
| Android Studio | Hedgehog (2023.1.1)+ |
| Xcode | 15+ (iOS builds) |
| Java | 17 (Android builds) |
| Device / emulator | Android API 21+ · iOS 14+ |

### First-time setup

```bash
# 1. Clone
git clone https://github.com/faizazharr/Quran-Apps.git
cd Quran-Apps

# 2. Install dependencies
flutter pub get

# 3. Install git hooks (run once — enables pre-commit format + pre-push CI gate)
make setup

# 4. Run
flutter run
```

No API keys required — AlQuran Cloud and Islamic Network CDN are public endpoints.

---

## Makefile Commands

```bash
make setup          # Install git hooks (run once after cloning)
make check          # Full CI gate: format + analyze + test
make fmt            # Auto-format lib/ and test/
make fmt-check      # Format check without modifying files
make analyze        # flutter analyze --fatal-infos
make test           # flutter test
make test-coverage  # flutter test --coverage + lcov summary
make build-apk      # Debug APK
make build-aab      # Signed release AAB (reads version from pubspec.yaml)
make release        # Tag + push release (runs CI gate first)
make clean          # flutter clean
make help           # Show all targets with descriptions
```

### Version bumping

Bump the version name in `pubspec.yaml` and auto-commit — no manual editing needed:

```bash
make bump-patch     # 1.0.2 → 1.0.3  (bug fix)
make bump-minor     # 1.0.2 → 1.1.0  (new feature)
make bump-major     # 1.0.2 → 2.0.0  (breaking change)
```

Then push to the appropriate release branch to trigger CD.

### AAB local build

```bash
make build-aab                          # version from pubspec, code = YYYYMMDDHHmm
make build-aab VERSION=1.2.0            # custom version name
make build-aab VERSION=1.2.0 CODE=42   # fully custom
```

---

## Build & Release

### Local signing setup

The upload keystore is `android/upload-keystore.jks` (gitignored). Convert it to
legacy PKCS12 format for compatibility with bundletool:

```bash
keytool -importkeystore \
  -srckeystore android/upload-keystore.jks \
  -srcstorepass <password> -srckeypass <password> -srcalias upload \
  -destkeystore upload-keystore-ci.p12 \
  -deststoretype PKCS12 -deststorepass <password> -destalias upload \
  -J-Dkeystore.pkcs12.legacy -noprompt
```

Then create `android/key.properties` (gitignored):

```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=upload
storeFile=../../upload-keystore-ci.p12
```

> **Important:** The PKCS12 keystore used in CI must match the SHA1 fingerprint
> registered in Play Console as the upload key. Verify with:
> ```bash
> keytool -list -keystore upload-keystore-ci.p12 -storetype PKCS12 -storepass <password> -v
> ```

### Manual AAB build

```bash
make build-aab
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## CI/CD Pipeline

### Branch strategy

```
feature/* ──PR──▶ dev ──PR──▶ dev-release ──PR──▶ staging ──PR──▶ main
                               │                   │                │
                            Internal            Closed          Production
                            Testing              Testing         (10% rollout)
```

### Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **CI** (`ci.yml`) | Push to `main` + PRs to any release branch | Lint → Test → Build smoke (debug APK + unsigned AAB) |
| **CD Android** (`cd-android.yml`) | Push to `dev-release` / `staging` / `main` | Validate → Build signed AAB → Upload to Play Store track |
| **CD iOS** (`cd-ios.yml`) | Push to `dev-release` / `staging` / `main` | Build IPA → TestFlight / App Store |
| **Promote** (`promote-android.yml`) | Manual dispatch | Promote existing build between tracks |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `KEYSTORE_BASE64` | Base64 of upload keystore: `base64 -i upload-keystore-ci.p12 \| gh secret set KEYSTORE_BASE64` |
| `STORE_PASSWORD` | Keystore store password |
| `KEY_PASSWORD` | Keystore key password |
| `KEY_ALIAS` | Keystore alias (e.g. `upload`) |
| `GOOGLE_PLAY_JSON` | Google Play service account JSON: `gh secret set GOOGLE_PLAY_JSON < service-account.json` |

### Setting up secrets via CLI

```bash
# Keystore (must be PKCS12 legacy format)
gh secret set KEYSTORE_BASE64 < <(base64 -i upload-keystore-ci.p12)
gh secret set STORE_PASSWORD --body "your-password"
gh secret set KEY_PASSWORD --body "your-password"
gh secret set KEY_ALIAS --body "upload"

# Google Play service account
gh secret set GOOGLE_PLAY_JSON < service-account.json
```

### Play Store track mapping

| Branch | Track | Status | Notes |
|--------|-------|--------|-------|
| `dev-release` | Internal Testing | `completed` | Available to all internal testers immediately |
| `staging` | Closed Testing (alpha) | `completed` | Available to invited testers |
| `main` | Production | `inProgress` | 10% staged rollout — increase manually in Play Console |

### Version numbering in CI

- **Version name** — read from `pubspec.yaml` (e.g. `1.0.2`). Use `make bump-patch/minor/major` to change it.
- **Version code** — `github.run_number` (always increasing, unique per repo, never needs manual editing)
- Each push to a release branch produces a unique build (e.g. `1.0.2+42`)

---

## Git Hooks

Installed via `make setup` (points `core.hooksPath` to `.githooks/`).

| Hook | Runs | What it does |
|------|------|--------------|
| `pre-commit` | Before every commit | `dart format lib test` → re-stages any reformatted files automatically |
| `pre-push` | Before every push | Format check + `flutter analyze --fatal-infos` + `flutter test` — mirrors CI exactly |

The pre-push hook ensures no broken code reaches remote. If any check fails, the push is aborted.

---

## Configuration

All environment-dependent values are injected at compile time via `--dart-define`
and read by [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart).

| Key | Default | Purpose |
|-----|---------|---------|
| `APP_FLAVOR` | `dev` | `dev` / `staging` / `prod` |
| `API_BASE_URL` | `https://api.alquran.cloud/v1` | REST base URL |
| `AUDIO_CDN_BASE_URL` | `https://cdn.islamic.network/quran/audio-surah` | Audio CDN root |
| `NETWORK_TIMEOUT_SECONDS` | `15` | Per-request hard timeout |

Non-HTTPS values throw at startup in all flavors.

---

## API & CDN Details

### AlQuran Cloud REST API

Base URL: `https://api.alquran.cloud/v1`

| Endpoint | Usage |
|----------|-------|
| `GET /surah` | All 114 Surahs with metadata |
| `GET /edition?format=audio` | All available audio editions (reciters) |
| `GET /surah/{number}/{edition}` | Ayah-by-ayah content for a specific Surah + reciter |

> **Note:** The `type` filter is intentionally omitted from `GET /edition` — some editions like `ar.abdulbasitmurattal` have `type=translation` in the API but fully functional CDN audio files. Filtering by `type=versebyverse` would incorrectly exclude them.

### CDN audio URL structure

```
https://cdn.islamic.network/quran/audio-surah/{bitrate}/{identifier}/{surahNumber}.mp3
```

Example — Al-Fatihah by Alafasy at 128 kbps:
```
https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3
```

---

## Versioning Policy

```
MAJOR.MINOR.PATCH+BUILD_NUMBER
```

| Segment | Rule |
|---------|------|
| `MAJOR` | Breaking API or UX change |
| `MINOR` | New feature (backward-compatible) |
| `PATCH` | Bug fix or internal improvement |
| `BUILD_NUMBER` | `github.run_number` in CI; timestamp (`YYYYMMDDHHmm`) locally |

- Bump version in `pubspec.yaml` and commit before tagging
- `make release` runs the CI gate then tags and pushes, triggering CD automatically

---

## Security

| Layer | Measure |
|-------|---------|
| **Network** | HTTPS enforced in `NetworkClient` + Android NSC `network_security_config.xml` + iOS ATS |
| **Storage** | `android:allowBackup="false"` — local DB excluded from cloud backups |
| **Build** | R8 minification + ProGuard rules in release builds |
| **Secrets** | Keystore + service account JSON stored only in GitHub Secrets, never committed |
| **Dependencies** | `dependency-review` action blocks HIGH/CRITICAL CVE packages on PRs |

### Digital Asset Links

`docs/.well-known/assetlinks.json` is served via GitHub Pages at
`https://faizazharr.github.io/Quran-Apps/.well-known/assetlinks.json`
using the **App signing key** SHA-256 (Google-managed, not the upload key).

---

## Localization

The app supports **English** (`en`) and **Indonesian** (`id`).

ARB source files live in `lib/l10n/`. Generated code is in `lib/l10n/generated/`.

To add a new locale:
1. Add `lib/l10n/app_XX.arb`
2. Add the locale to `supportedLocales` in `app.dart`
3. Run `flutter gen-l10n`

---

## Testing

```bash
flutter test                  # Run all unit tests
flutter test --coverage       # With coverage report
make test-coverage            # Tests + lcov summary in terminal
```

**53 unit tests** across:

| Suite | Coverage |
|-------|----------|
| `result_test` | `Result<T>` — Success, Failure, map, runCatching |
| `duration_formatter_test` | Edge cases: zero, negative, hour-spanning |
| `search_normalizer_test` | Diacritics, fuzzy matching, transliteration variants |
| `track_test` | `id`, `audioUrl`, `matches()` — title / artist / number |
| `quran_repository_test` | Cache-first, remote refresh, offline fallback, search |
| `player_bloc_test` | State defaults, `copyWith`, speed/status fields |
| `search_bloc_test` | Load, query change, load-more, reciter change, failure |
| `download_bloc_test` | Enqueue, progress stream, delete, cancel |
| `sleep_timer_bloc_test` | Start (timed + end-of-Surah), tick, cancel, expiry |
