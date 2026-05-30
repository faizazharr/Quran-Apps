# Quran Player

A Flutter mobile app that streams all 114 Surah recitations from the public
[AlQuran Cloud](https://alquran.cloud) API. Built as the deliverable for the
**Mobile App Technical Test** and progressively hardened into a production-ready
template with offline support, DI, SOLID layering, lint rules, security
hardening, semantic versioning, a responsive UI, fuzzy search, pagination,
playback speed control, and smooth 60 fps scrolling.

> **Terminology:** in this app a "song" is a full-Surah recitation:
> - **Title** = Surah name (e.g. *Al-Fatihah*)
> - **Artist** = Reciter (e.g. *Mishary Rashid Alafasy*)

---

## Table of Contents

1. [Features](#features)
2. [Tech Stack](#tech-stack)
3. [Architecture](#architecture)
4. [Project Structure](#project-structure)
5. [Getting Started](#getting-started)
6. [Build & Run Commands](#build--run-commands)
7. [Configuration (`--dart-define`)](#configuration---dart-define)
8. [API & CDN Details](#api--cdn-details)
9. [Versioning Policy](#versioning-policy)
10. [Security](#security)
11. [Lint & Code Style](#lint--code-style)
12. [Performance](#performance)
13. [Responsive UI](#responsive-ui)
14. [Offline Support](#offline-support)
15. [Testing](#testing)
16. [Test-Brief Requirements Mapping](#test-brief-requirements-mapping)
17. [Known Limitations](#known-limitations)

---

## Features

### Core requirements

| Requirement                            | Implementation                                                              |
| -------------------------------------- | --------------------------------------------------------------------------- |
| **Search** by Surah name or number     | Fuzzy-normalised search via `SearchNormalizer`; "al fatihah" matches "Al-Faatiha" |
| **Play / Pause / Resume**              | `PlayerBloc` + `just_audio` — tap a Surah, pick a reciter, play             |
| **Progress display** (current / total) | Live position + duration streams; slider updates as audio buffers           |
| **Seek** via slider                    | Drag-to-seek `Slider` bound to `PlayerSeekRequested` event                  |

### Bonus features

| Feature | Details |
| ------- | ------- |
| **Surah-first browsing** | 114-row list, not 912. Reciter is chosen *per-tap* via a bottom sheet, not forced upfront. |
| **Per-surah reciter picker** | Tap a Surah → bottom sheet lists all available reciters with the last-used one pre-selected. |
| **Fuzzy search normalisation** | `normalizeForSearch` strips diacritics, collapses doubled vowels, drops trailing *h* — "al fatihah" / "al fatiha" / "alfatehah" all match "Al-Faatiha". |
| **Paginated list** | `SearchBloc` loads 20 Surahs at a time. Subsequent pages load on scroll (debounced, 200 ms) instead of all at once. |
| **Playback speed control** | Speed chip in the player controls: **tap** cycles 0.75 → 1.0 → 1.25 → 1.5 → 2.0x; **long-press** opens a direct-select menu. Highlighted when not at 1×. |
| **Offline-first** | sqflite metadata cache + on-disk audio cache via `LockCachingAudioSource`. Replaying a cached track works with no network. |
| **Clean Architecture** | `core / data / features / shared` layering with SOLID interfaces at every boundary. |
| **SOLID + DI** | [`get_it`](https://pub.dev/packages/get_it) service locator; all collaborators registered as interfaces. |
| **`Result<T>` sealed type** | `Success<T>` / `Failure<T>`; no nullable returns for failure paths. |
| **Centralized network client** | HTTPS guard, 15 s timeout, 5 MB cap, sanitized error mapping. |
| **Polished Material 3 UI** | Gradient hero header, shimmer loaders, animated player panel, friendly empty/error states. |
| **Responsive layout** | Compact (phone portrait) ↔ two-pane (landscape / tablet / desktop). |
| **Strict lint rules** | `analysis_options.yaml` with strict types + OOP-discipline lints. |
| **Security hardening** | Android NSC, iOS ATS, backup disabled, R8 minify, ProGuard, secret hygiene. |

---

## Tech Stack

| Concern              | Choice                                                                    |
| -------------------- | ------------------------------------------------------------------------- |
| State management     | [`flutter_bloc ^9.1.1`](https://pub.dev/packages/flutter_bloc) + `equatable ^2.0.8` |
| Networking           | [`http ^1.6.0`](https://pub.dev/packages/http) wrapped by `NetworkClient` |
| Audio                | [`just_audio ^0.10.5`](https://pub.dev/packages/just_audio) — `LockCachingAudioSource` with fallback to `AudioSource.uri` |
| Local persistence    | [`sqflite ^2.4.2`](https://pub.dev/packages/sqflite) + `path_provider ^2.1.5` |
| Connectivity         | [`connectivity_plus ^7.1.1`](https://pub.dev/packages/connectivity_plus)  |
| Dependency injection | [`get_it ^9.2.1`](https://pub.dev/packages/get_it)                        |
| Lints                | [`flutter_lints ^6.0.0`](https://pub.dev/packages/flutter_lints) + project rules |
| Path utilities       | [`path ^1.9.1`](https://pub.dev/packages/path)                            |

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         UI (Widgets)                          │
│   SearchScreen · SurahTile · ReciterPicker · PlayerPanel · …  │
└──────────────────────────────────────────────────────────────┘
                             ▲
                             │  events / states
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                       BLoCs (features)                        │
│    SearchBloc (surah list + search + pagination)              │
│    PlayerBloc (playback + seek + speed)                       │
└──────────────────────────────────────────────────────────────┘
                             ▲
                             │  Result<T> / Streams
                             ▼
┌──────────────────────────────────────────────────────────────┐
│                     Repositories (data)                       │
│   QuranRepositoryImpl — cache-first, offline fallback         │
│     getSurahs() · getReciters() · searchSurahs()              │
└──────────────────────────────────────────────────────────────┘
          ▲                      ▲                      ▲
          │                      │                      │
┌──────────────────┐  ┌──────────────────────┐  ┌──────────────────┐
│ RemoteDataSource │  │  LocalDataSource     │  │ AudioPlayerSvc   │
│ (NetworkClient)  │  │  (sqflite)           │  │ (just_audio)     │
│ GET /surah       │  │  surahs + editions   │  │ load/play/pause  │
│ GET /edition     │  │  tables              │  │ seek/setSpeed    │
└──────────────────┘  └──────────────────────┘  └──────────────────┘
          ▲
          │
┌──────────────────────────────────────────────────────────────┐
│   core/ — config · DI · errors · theme · network · Result<T> │
│           responsive · utils (SearchNormalizer, Formatter)    │
└──────────────────────────────────────────────────────────────┘
```

For an in-depth walkthrough of every layer, data flows, and BLoC event/state
tables, see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

### Key design choices

| Choice | Rationale |
| ------ | --------- |
| **Interfaces everywhere** | `IQuranRepository`, `IQuranRemoteDataSource`, `IQuranLocalDataSource`, `IAudioPlayerService`, `IConnectivityService` — swappable without touching call sites. |
| **`Result<T>` sealed type** | `Success<T>` / `Failure<T>` — no nullable returns for failure, no surprise exceptions reaching the BLoC layer. |
| **`AppException` hierarchy** | `RemoteException` / `OfflineException` / `LocalException` / `NoDataException` / `PlaybackException` / `UnknownException`, each with a sanitized `userMessage`. |
| **Cache-first repository** | Return local cache immediately; refresh in background when online. Offline + empty cache → `OfflineException`, not a crash. |
| **Surah-first list** | 114 rows (not 912 = 114 × 8). Choosing a reciter is deferred to the moment the user actually wants to play, reducing cognitive load. |
| **`SearchNormalizer`** | Centralised normalisation (`diacritics → ASCII → de-duplicate vowels → drop trailing h`) so the search field is forgiving of varied transliteration styles. |
| **Paginated BLoC** | `SearchBloc` manages `visibleCount`; `SearchLoadMoreRequested` is fired by a debounced `ScrollController` listener (not `initState`) to prevent cascade reloads. |

---

## Project Structure

```
lib/
├── main.dart                             # Entry: ensureInitialized → DI → runApp
├── app.dart                              # Root MaterialApp + BlocProviders
│
├── core/
│   ├── config/app_config.dart            # --dart-define driven config + HTTPS guard
│   ├── constants/api_constants.dart      # CDN URL builder
│   ├── di/service_locator.dart           # GetIt registrations (all as interfaces)
│   ├── errors/app_exception.dart         # Sealed AppException hierarchy
│   ├── network/
│   │   ├── network_client.dart           # HTTPS, 15 s timeout, 5 MB cap, error map
│   │   ├── connectivity_service.dart     # (interface)
│   │   └── connectivity_service_impl.dart
│   ├── responsive/responsive.dart        # Breakpoints + ResponsiveInfo
│   ├── result/result.dart                # sealed Result<T> + runCatching
│   ├── theme/app_theme.dart              # Material 3 tokens + brand gradient
│   └── utils/
│       ├── duration_formatter.dart       # HH:MM:SS / MM:SS formatter
│       └── search_normalizer.dart        # Fuzzy search normalization
│
├── data/
│   ├── datasources/
│   │   ├── quran_remote_data_source.dart         (interface)
│   │   ├── quran_remote_data_source_impl.dart    # GET /surah, GET /edition?format=audio
│   │   ├── quran_local_data_source.dart          (interface)
│   │   └── quran_local_data_source_impl.dart     # sqflite CRUD
│   ├── models/
│   │   ├── surah.dart                    # id, name, englishName, translation, ayahCount
│   │   ├── edition.dart                  # identifier, name, englishName, format, language
│   │   └── track.dart                    # Surah × Edition composite; fuzzyContains search
│   ├── repositories/
│   │   ├── quran_repository.dart         (interface — Result<T>)
│   │   └── quran_repository_impl.dart    # Cache-first; in-memory + sqflite caches
│   └── services/
│       ├── database_service.dart         # sqflite open / migrate
│       ├── audio_player_service.dart     (interface — load/play/pause/seek/setSpeed)
│       └── just_audio_player_service.dart # LockCachingAudioSource → AudioSource.uri fallback
│
├── features/
│   ├── player/
│   │   ├── bloc/player_bloc.dart         # Events: TrackSelected, Play, Pause, Seek,
│   │   │                                 #         Stop, SpeedChanged, _Position/Duration/
│   │   │                                 #         Playback/Error (internal)
│   │   └── view/player_panel.dart        # Gradient panel: header · seek bar · controls
│   │                                     # Speed chip: tap-to-cycle, long-press menu
│   └── search/
│       ├── bloc/search_bloc.dart         # Events: Started, QueryChanged, Refreshed,
│       │                                 #         ReciterChanged, LoadMoreRequested
│       │                                 # State: surahs · reciters · selectedReciter
│       │                                 #        visibleCount · query · status
│       ├── view/search_screen.dart       # LayoutBuilder → compact / two-pane
│       │                                 # ScrollController debounce → LoadMoreRequested
│       └── widgets/
│           ├── search_header.dart        # Gradient header; compact / stacked variants
│           ├── surah_tile.dart           # Animated card (TweenAnimationBuilder color lerp)
│           ├── reciter_picker.dart       # ReciterChip + showReciterPicker bottom sheet
│           └── track_tile_shimmer.dart   # Loading skeleton
│
└── shared/
    └── widgets/empty_state_view.dart

test/
├── core/
│   ├── duration_formatter_test.dart      # Edge cases: zero, negative, hour-spanning
│   ├── result_test.dart                  # Success/Failure, when, map, runCatching
│   └── search_normalizer_test.dart       # Diacritics, fuzzy matching, "al fatihah" cases
├── data/
│   ├── track_test.dart                   # id, audioUrl, matches() — title/artist/number
│   └── quran_repository_test.dart        # Cache-first, remote refresh, offline, search
└── features/
    └── player_bloc_test.dart             # PlayerState defaults, copyWith, speed field

docs/
├── ARCHITECTURE.md                       # Detailed layer diagrams + BLoC event tables
├── CHANGELOG.md                          # Version history
├── SECURITY.md                           # Threat model + mitigations
└── VERSIONING.md                         # Semver + build-number policy
```

---

## Getting Started

### Prerequisites

| Tool | Minimum version |
| ---- | --------------- |
| Flutter SDK | **3.41+** |
| Dart | **3.11+** |
| Android Studio | Hedgehog (2023.1.1)+ — for Android builds |
| Xcode | 15+ — for iOS builds |
| Device / emulator | Android API 21+ · iOS 14+ |

### First-time setup

```bash
# Clone
git clone https://github.com/faizazharr/Quran-Apps.git
cd "Quran-Apps"

# Install dependencies
flutter pub get

# Run on connected device (or emulator)
flutter run
```

No extra API keys are needed — the AlQuran Cloud and Islamic Network CDN
endpoints are public and require no authentication.

---

## Build & Run Commands

| Goal | Command |
| ---- | ------- |
| Dev run (auto-detect device) | `flutter run` |
| Android only | `flutter run -d android` |
| iOS only | `flutter run -d ios` |
| Profile build (perf tracing) | `flutter run --profile` |
| Debug APK | `flutter build apk --debug` |
| Release APK (R8 + ProGuard) | `flutter build apk --release --dart-define=APP_FLAVOR=prod` |
| Release App Bundle (upload) | `flutter build appbundle --release --dart-define=APP_FLAVOR=prod` |
| iOS release (Xcode archive) | `flutter build ipa --release --dart-define=APP_FLAVOR=prod` |
| Static analysis | `flutter analyze` |
| All unit tests | `flutter test` |
| Tests with coverage | `flutter test --coverage` |
| Format all code | `dart format lib test` |

---

## Configuration (`--dart-define`)

All environment-dependent values are injected at compile time via `--dart-define`
and read by [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart).

| Key | Default | Purpose |
| --- | ------- | ------- |
| `APP_FLAVOR` | `dev` | `dev` / `staging` / `prod` |
| `API_BASE_URL` | `https://api.alquran.cloud/v1` | REST base URL |
| `AUDIO_CDN_BASE_URL` | `https://cdn.islamic.network/quran/audio-surah` | Audio CDN root |
| `NETWORK_TIMEOUT_SECONDS` | `15` | Per-request hard timeout |

Non-HTTPS values throw at startup in all flavors. Example staging build:

```bash
flutter build apk --release \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=API_BASE_URL=https://staging.api.alquran.cloud/v1
```

---

## API & CDN Details

### AlQuran Cloud REST API (`https://api.alquran.cloud/v1`)

| Endpoint | Usage | Notes |
| -------- | ----- | ----- |
| `GET /surah` | Fetch all 114 Surahs | Returns `{ data: [ { number, name, englishName, englishNameTranslation, numberOfAyahs, … } ] }` |
| `GET /edition?format=audio` | Fetch all audio editions | **`type` param is intentionally omitted** — `ar.abdulbasitmurattal` has `type=translation` in the API but its CDN files are fully functional. Filtering by `type=versebyverse` would incorrectly exclude it. |

### CDN audio URL structure

```
https://cdn.islamic.network/quran/audio-surah/{bitrate}/{identifier}/{surahNumber}.mp3
```

Example: Al-Fatihah by Alafasy at 128 kbps →
`https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3`

### Verified reciters (128 kbps, HTTP 200 confirmed)

| Identifier | English Name |
| ---------- | ------------ |
| `ar.alafasy` | Mishary Rashid Alafasy |
| `ar.abdulbasitmurattal` | Abdul Basit Abdul Samad (Murattal) |
| `ar.abdullahbasfar` | Abdullah Basfar |

> Other editions listed by the API return HTTP 403 for full-Surah CDN files at
> 128 kbps. The app surfaces a user-friendly "This reciter is not available for
> full-surah streaming" message instead of a raw exception.

---

## Versioning Policy

Version lives in [`pubspec.yaml`](pubspec.yaml) as
`MAJOR.MINOR.PATCH+BUILD_NUMBER`. Full policy: [`docs/VERSIONING.md`](docs/VERSIONING.md).

| Build type | App ID | Minify | Signed with |
| ---------- | ------ | ------ | ----------- |
| Debug | `com.example.quran_apps.debug` | off | debug keystore |
| Release | `com.example.quran_apps` | R8 + shrink | upload keystore (debug fallback) |

**Rules**

1. **Semver** for `MAJOR.MINOR.PATCH`.
2. **`BUILD_NUMBER` is monotonic** — increment on every uploaded build. Stores reject duplicates.
3. Tag every release in git: `git tag -a v1.2.0+13 -m "Release 1.2.0+13"`.

```bash
# Cutting a release
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=prod \
  --build-name=1.2.0 \
  --build-number=13
```

---

## Security

Full audit and threat model: [`docs/SECURITY.md`](docs/SECURITY.md).

| Risk | Mitigation |
| ---- | ---------- |
| MITM on API/audio traffic | HTTPS-only in `NetworkClient` + Android NSC + iOS ATS |
| Cleartext traffic | `usesCleartextTraffic="false"` + `cleartextTrafficPermitted="false"` |
| User-installed CA MITM in release | System CAs only in release; user CAs allowed only in `debug-overrides` |
| Cache exfiltration via adb backup | `allowBackup="false"` + `data_extraction_rules.xml` |
| Reverse engineering | R8 `isMinifyEnabled=true` + `isShrinkResources=true` + ProGuard rules |
| DoS via giant payload | 5 MB response cap in `NetworkClient` |
| Secret leakage in git | `key.properties`, `*.jks`, `*.env`, `google-services.json` gitignored |
| Raw exception text in UI | All errors mapped to sanitized `AppException.userMessage` |

Configure release signing by copying
[`android/key.properties.example`](android/key.properties.example) to
`android/key.properties` and pointing it at your upload keystore.

---

## Lint & Code Style

[`analysis_options.yaml`](analysis_options.yaml) extends `flutter_lints` and adds:

- **Strict type system** — `strict-casts`, `strict-inference`, `strict-raw-types`.
- **Promoted errors** — `missing_required_param`, `unused_import`, `dead_code`.
- **Style** — single quotes, trailing commas, sorted child properties, sorted pub deps.
- **Project structure** — `prefer_relative_imports` inside `lib/`, no relative imports in tests.
- **Async hygiene** — `unawaited_futures`, `discarded_futures`, `cancel_subscriptions`.
- **OOP discipline** — `prefer_const_*`, `prefer_final_*`, `avoid_setters_without_getters`,
  `avoid_equals_and_hash_code_on_mutable_classes`, `use_super_parameters`.
- **Flutter-specific** — `use_build_context_synchronously`, `use_key_in_widget_constructors`,
  `use_decorated_box` / `use_colored_box`, `sized_box_for_whitespace`.

Run `dart format lib test && flutter analyze` before every commit. Zero issues is the required baseline.

---

## Performance

### Rebuild isolation

| Widget | Subscriber | Rebuilds on |
| ------ | ---------- | ----------- |
| `_SeekBar` | `BlocBuilder` with `buildWhen: position OR duration changed` | ~4 Hz position ticks only |
| `_Controls` | `BlocSelector<_ControlsVM>` | isPlaying / isLoading / speed changes |
| `_Header` | `BlocSelector<_HeaderVM>` | Track identity + error state |
| `SurahTile` | Outer `BlocBuilder` | Track identity + isPlaying + isLoading |
| Surah list | `BlocBuilder` with `buildWhen` | surahs / visibleCount / status / errorMessage |

`_SeekBar` is the **only** widget that rebuilds on position ticks — it never
triggers a repaint of the tile list or player header/controls.

### Scroll smoothness

- `BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())` — elastic
  momentum on both iOS and Android.
- `ScrollController` listener debounced 200 ms before firing `SearchLoadMoreRequested`.
  This prevents rapid event flood during momentum scrolling.
- `cacheExtent: 800` — tiles are pre-built 800 px before they enter the viewport.
- `RepaintBoundary` around each `SurahTile` isolates paint invalidation.

### Tile animation

- `TweenAnimationBuilder<double>` with `Color.lerp` for the active tile highlight.
  Only the **decoration colour** is interpolated — layout is never touched.
  Duration: 180 ms `Curves.easeOut`.

### Memory

- In-memory `_surahsMemoryCache` + `_recitersMemoryCache` + `_tracksMemoryCache`
  in `QuranRepositoryImpl` — search filtering never hits the database.
- `cacheExtent` keeps near-viewport tiles warm without building the whole list.

---

## Responsive UI

See [`lib/core/responsive/responsive.dart`](lib/core/responsive/responsive.dart).

| Form factor | Width | Layout |
| ----------- | ----- | ------ |
| Phone portrait | < 600 dp | Header + scrollable list + bottom player panel |
| Phone landscape | < 480 dp tall | Two-pane + **compact** (single-row) header |
| Small tablet / foldable | ~700–840 dp | Two-pane |
| Tablet landscape | ≥ 840 dp | Two-pane; list column capped at 720 dp |
| Desktop | ≥ 1200 dp | Two-pane; list column capped at 720 dp |

The root `MediaQuery` clamps `textScaler` to `0.85–1.30`, respecting OS
accessibility settings without breaking single-line layouts (badges, player
controls). All sizes are logical pixels (dp) so multi-density
(`mdpi → xxxhdpi`) is handled automatically by Flutter.

---

## Offline Support

1. **Metadata** (`Surah` + `Edition`) is persisted in sqflite on every successful
   API refresh. On the next cold start the repository returns from cache
   immediately without a network round-trip.
2. **Audio** is cached on first stream by `LockCachingAudioSource` into the
   app-support directory (`getApplicationSupportDirectory()`). Re-playing the
   same Surah works fully offline. If `LockCachingAudioSource` fails (e.g.
   certain CDN configurations), the service transparently falls back to
   `AudioSource.uri` (streaming-only, no disk cache for that track).
3. **Connectivity guard** — `ConnectivityServiceImpl` is checked before every
   remote request. If offline + no cache → `OfflineException` → UI shows
   "No connection" with a retry CTA.

---

## Testing

```bash
flutter test
```

**35 tests · 0 lint issues** (as of v1.0.0+1).

| File | What is tested |
| ---- | -------------- |
| `test/core/duration_formatter_test.dart` | `00:00`, minutes+seconds, hours+minutes+seconds, negative clamping |
| `test/core/result_test.dart` | `Success` / `Failure` construction, `when()`, `map()`, `runCatching` with `AppException` and unknown error |
| `test/core/search_normalizer_test.dart` | Lowercase + punctuation strip, diacritic folding, vowel collapse, trailing-*h* drop, `fuzzyContains` positive/negative cases, `"al fatihah"` → matches `"Al-Faatiha"` |
| `test/data/track_test.dart` | Stable `id`, correct CDN `audioUrl`, `matches()` by English name, translation, reciter, number, empty query, non-matching query |
| `test/data/quran_repository_test.dart` | Cache-first serve, remote fetch + cache write, `OfflineException` when offline + empty cache, search filtering |
| `test/features/player_bloc_test.dart` | `PlayerState` default values, `isPlaying` / `isLoading` derived getters, `copyWith` (all fields + `clearError`), `speed` field |

---

## Test-Brief Requirements Mapping

| Test brief item | Where implemented |
| --------------- | ----------------- |
| Search by title / artist | `SearchBloc` + `Track.matches()` + `SearchNormalizer` |
| Play / Pause / Resume | `PlayerBloc` — `PlayerPlayRequested`, `PlayerPauseRequested`, `PlayerTrackSelected` |
| Progress display | `_SeekBar` in `player_panel.dart` (position + duration streams, 4 Hz) |
| Seek via slider | `PlayerSeekRequested` event → `IAudioPlayerService.seek()` |
| State management | `flutter_bloc` — sealed events + `Equatable` states |
| Clean code & structure | Layered `core / data / features / shared` + SOLID interfaces + `Result<T>` |
| Library usage minimization | Custom repository, custom search normalizer, custom `Result<T>` / `AppException` types — no redundant packages |
| Unit tests | 35 tests across `core/`, `data/`, `features/` |
| Comprehensive README | This file — plus [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |

---

## Known Limitations

- **Duration metadata** — full-Surah MP3s do not always expose their duration
  upfront; the seek slider updates as soon as `just_audio` resolves it during
  buffering.
- **Network required on first launch** — local cache is empty until the first
  successful API response. Subsequent launches are offline-capable.
- **Background audio / lockscreen controls** — `just_audio` supports this via
  the `audio_service` package, but it is not wired up here (out of scope for
  the test).
- **CDN availability** — only 3 of the ~37 audio editions have been confirmed
  to return HTTP 200 for full-Surah files at 128 kbps. Other reciters surface a
  friendly error message instead of a raw exception.
- **Pull-to-refresh** always refetches both API endpoints; an ETag-based
  conditional refresh could be added to reduce bandwidth.
- **No verse-by-verse mode** — the app plays full-Surah audio only. Per-verse
  streams require a different CDN path and are not implemented.

---

## Build & Run Commands

| Goal                              | Command                                                                                    |
| --------------------------------- | ------------------------------------------------------------------------------------------ |
| Dev run (auto device)             | `flutter run`                                                                              |
| Android only                      | `flutter run -d android`                                                                   |
| iOS only                          | `flutter run -d ios`                                                                       |
| Profile (perf)                    | `flutter run --profile`                                                                    |
| Release APK (debug-signed)        | `flutter build apk --release`                                                              |
| Release App Bundle (upload key)   | `flutter build appbundle --release --dart-define=APP_FLAVOR=prod`                          |
| iOS release (Xcode-signed)        | `flutter build ipa --release --dart-define=APP_FLAVOR=prod`                                |
| Static analysis                   | `flutter analyze`                                                                          |
| Tests                             | `flutter test`                                                                             |

---

## Configuration (`--dart-define`)

All environment-dependent values are injected at compile time. See
[`lib/core/config/app_config.dart`](lib/core/config/app_config.dart).

| Key                       | Default                                            | Purpose                       |
| ------------------------- | -------------------------------------------------- | ----------------------------- |
| `APP_FLAVOR`              | `dev`                                              | `dev` / `staging` / `prod`    |
| `API_BASE_URL`            | `https://api.alquran.cloud/v1`                     | REST base URL                 |
| `AUDIO_CDN_BASE_URL`      | `https://cdn.islamic.network/quran/audio-surah`    | Audio CDN base                |
| `NETWORK_TIMEOUT_SECONDS` | `15`                                               | Per-request timeout           |

Non-HTTPS values throw at startup. Example staging build:

```bash
flutter build apk --release \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=API_BASE_URL=https://staging.api.alquran.cloud/v1
```

---

## Versioning Policy

Version lives in [`pubspec.yaml`](pubspec.yaml) as
`MAJOR.MINOR.PATCH+BUILD_NUMBER`. Full policy: [`docs/VERSIONING.md`](docs/VERSIONING.md).

| Build type | App id                          | Version suffix | Minify | Signed with                              |
| ---------- | ------------------------------- | -------------- | ------ | ---------------------------------------- |
| Debug      | `com.example.quran_apps.debug`  | `-debug`       | off    | debug keystore                           |
| Release    | `com.example.quran_apps`        | none           | R8 + shrink | upload keystore (debug fallback)    |

**Rules**

1. **Semver** for `MAJOR.MINOR.PATCH`.
2. **`BUILD_NUMBER` is monotonic** — increment on every uploaded build, even
   when the marketing version is unchanged. Stores reject duplicates.
3. Tag every release in git: `git tag -a v1.2.0+13 -m "Release 1.2.0+13"`.

Cutting a release:

```bash
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=prod \
  --build-name=1.2.0 \
  --build-number=13
```

---

## Security

Full audit and threat model: [`docs/SECURITY.md`](docs/SECURITY.md).

| Risk                                       | Mitigation                                                                 |
| ------------------------------------------ | -------------------------------------------------------------------------- |
| MITM on API/audio traffic                  | HTTPS-only enforced in `NetworkClient` + Android NSC + iOS ATS             |
| Cleartext traffic                          | `usesCleartextTraffic="false"` + `cleartextTrafficPermitted="false"`       |
| User-installed CAs MITM in release         | Trust system CAs only in release; user CAs allowed only in `debug-overrides` |
| Cache exfiltration via adb backup          | `allowBackup="false"` + `data_extraction_rules.xml`                        |
| Reverse engineering                        | R8 `isMinifyEnabled=true` + `isShrinkResources=true` + ProGuard rules      |
| DoS via giant payload                      | 5 MB response cap in `NetworkClient`                                       |
| Secret leakage in git                      | `key.properties`, `*.jks`, `*.env`, `google-services.json` gitignored      |
| Raw exception text in UI                   | All errors mapped to sanitized `AppException.userMessage`                  |

Configure release signing by copying
[`android/key.properties.example`](android/key.properties.example) to
`android/key.properties` and pointing it at your upload keystore.

---

## Lint & Code Style

Project [`analysis_options.yaml`](analysis_options.yaml) extends
`flutter_lints` and adds:

- **Strict type system**: `strict-casts`, `strict-inference`, `strict-raw-types`.
- **Promoted errors**: `missing_required_param`, `unused_import`, `dead_code`.
- **Style**: single quotes, trailing commas, sorted child properties, sorted pub deps.
- **Project structure**: `prefer_relative_imports` inside `lib/`, no relative imports in tests.
- **Async hygiene**: `unawaited_futures`, `discarded_futures`, `cancel_subscriptions`.
- **OOP discipline**: `prefer_const_*`, `prefer_final_*`, `avoid_setters_without_getters`,
  `avoid_equals_and_hash_code_on_mutable_classes`, `use_super_parameters`.
- **Flutter-specific**: `use_build_context_synchronously`, `use_key_in_widget_constructors`,
  `use_decorated_box`/`use_colored_box`, `sized_box_for_whitespace`.

Run `dart format lib test` and `flutter analyze` before every commit.

---

## Performance

- **`buildWhen` / `BlocSelector`** on every player subscriber so position
  ticks (~10 Hz) only rebuild the seek bar — not the track list or panel
  header/controls.
- **`RepaintBoundary`** around each `TrackTile` to isolate paint invalidation.
- **`cacheExtent: 600`** keeps near-viewport tiles warm during fast scrolls.
- **Const widgets** wherever possible to skip element rebuilds.
- **In-memory cache** of computed `Track` list inside `QuranRepositoryImpl` so
  search filtering doesn't refetch.

---

## Responsive UI

See [`lib/core/responsive/responsive.dart`](lib/core/responsive/responsive.dart).

| Form factor                              | Layout                            |
| ---------------------------------------- | --------------------------------- |
| Phone portrait (< 600 dp wide)           | Header + list + bottom player     |
| Phone landscape (< 480 dp tall)          | Two-pane + **compact** header     |
| Foldable / small tablet (~700–840 dp)    | Two-pane                          |
| Tablet landscape (≥ 840 dp)              | Two-pane, list capped at 720 dp   |
| Desktop (≥ 1200 dp)                      | Two-pane, list capped at 720 dp   |

The root `MediaQuery` clamps `textScaler` to `0.85–1.30`, honouring OS
accessibility settings without breaking single-line layouts (badges, controls).
All sizes are in logical pixels (dp), so multi-density (`mdpi → xxxhdpi`)
is handled automatically.

---

## Offline Support

1. **Metadata** (`Surah` + `Edition`) is persisted in sqflite
   ([`database_service.dart`](lib/data/services/database_service.dart)) on
   every successful refresh.
2. **Audio** is cached on first stream by
   [`LockCachingAudioSource`](https://pub.dev/documentation/just_audio/latest/just_audio/LockCachingAudioSource-class.html)
   into the app-support directory. Re-playing the same track works offline.
3. **Connectivity** is checked via
   [`ConnectivityServiceImpl`](lib/core/network/connectivity_service_impl.dart);
   when offline with no cache, the repository returns `OfflineException` which
   the UI surfaces with a retry CTA.

---

## Testing

```bash
flutter test
```

| File                                          | Coverage                                                          |
| --------------------------------------------- | ----------------------------------------------------------------- |
| `test/core/duration_formatter_test.dart`      | Edge cases: zero, negative, hour-spanning                         |
| `test/core/result_test.dart`                  | `Success` / `Failure`, `when`, `map`, `runCatching`               |
| `test/data/track_test.dart`                   | Track matching by title / artist / translation / number           |
| `test/data/quran_repository_test.dart`        | Cache-first, remote refresh, offline fallback, search filter      |
| `test/features/player_bloc_test.dart`         | `PlayerState` derived getters                                     |

Current totals: **26 tests · 0 lint issues**.

---

## Test-Brief Requirements Mapping

| Test brief item               | Where implemented                                                     |
| ----------------------------- | --------------------------------------------------------------------- |
| Search by title / artist      | `SearchBloc` + `Track.matches`                                        |
| Play / Pause / Resume         | `PlayerBloc` (`PlayerPlayRequested`, `PlayerPauseRequested`)          |
| Progress display              | `_SeekBar` in `player_panel.dart` (position + duration streams)       |
| Seek via slider               | `PlayerSeekRequested` event                                           |
| State management              | `flutter_bloc` with sealed events + Equatable states                  |
| Clean code & structure        | Layered `core / data / features / shared` + SOLID interfaces          |
| Library usage minimization    | Custom repository, custom search, custom result/exception types       |
| Unit tests                    | `test/` directory (formatter, model, repository, bloc, Result)        |
| Comprehensive README          | This file                                                             |

---

## Known Limitations

- Full-Surah MP3s do not always expose their duration upfront; the slider
  updates as soon as `just_audio` resolves it.
- Network is required on first launch to populate the local cache.
- Background-audio playback (lockscreen controls, audio focus) is not enabled —
  out of scope for the test.
- Pull-to-refresh is wired but currently always refetches both endpoints; a
  smarter ETag-based refresh could be added.
