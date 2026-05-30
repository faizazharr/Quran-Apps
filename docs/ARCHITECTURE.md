# Architecture

This document describes the internal structure of the Quran Player app in depth:
layers, data flows, BLoC event/state tables, caching strategy, and key design
decisions.

---

## Table of Contents

1. [Layer Overview](#layer-overview)
2. [core/](#core)
3. [data/ — Models](#data--models)
4. [data/ — Repository & DataSources](#data--repository--datasources)
5. [data/ — Audio Service](#data--audio-service)
6. [features/search — SearchBloc](#featuressearch--searchbloc)
7. [features/player — PlayerBloc](#featuresplayer--playerbloc)
8. [UI Layer](#ui-layer)
9. [Dependency Injection](#dependency-injection)
10. [Caching Strategy](#caching-strategy)
11. [Search Normalisation](#search-normalisation)
12. [Error Handling](#error-handling)
13. [Responsive Layout](#responsive-layout)

---

## Layer Overview

```
┌──────────────────────────────────────────────────────────────────┐
│  UI (lib/features/**/view/, lib/features/**/widgets/)             │
│  Stateless/Stateful widgets, BlocBuilder/BlocSelector             │
└────────────────────────────────┬─────────────────────────────────┘
                                 │ events / states
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│  BLoCs (lib/features/**/bloc/)                                    │
│  SearchBloc · PlayerBloc                                          │
│  Sealed events → Equatable states                                 │
└──────────────────────────────────────────────────────────────────┘
         │ Result<T>            │ Streams           │ Result<T>
         ▼                      ▼                   ▼
┌─────────────────┐  ┌─────────────────────┐  ┌────────────────────┐
│  IQuranRepo     │  │  IAudioPlayerService│  │  (future services) │
│  (interface)    │  │  (interface)        │  │                    │
└────────┬────────┘  └──────────┬──────────┘  └────────────────────┘
         │                      │
         ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  QuranRepositoryImpl              JustAudioPlayerService         │
│  cache-first + offline fallback   LockCachingAudioSource         │
└──────────────────┬──────────────────────────────────────────────┘
         ┌─────────┴──────────┐
         ▼                    ▼
┌──────────────────┐  ┌──────────────────────┐
│ RemoteDataSource │  │ LocalDataSource       │
│ NetworkClient    │  │ sqflite + migrations  │
│ GET /surah       │  │ surahs table          │
│ GET /edition     │  │ editions table        │
└──────────────────┘  └──────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│  core/                                                            │
│  config · di · errors · network · responsive · result · theme    │
│  utils (SearchNormalizer · DurationFormatter)                     │
└──────────────────────────────────────────────────────────────────┘
```

Each layer depends only on the layer below it, via interfaces. No layer
imports from a layer above it.

---

## core/

### `result/result.dart` — `Result<T>`

```dart
sealed class Result<T> {
  const Result();
}
class Success<T> extends Result<T> { final T data; … }
class Failure<T> extends Result<T> { final AppException error; … }
```

Helper:
```dart
Result<T> runCatching<T>(T Function() body) { … }
```

All repository methods return `Result<T>`. BLoC handlers switch on
`Success` / `Failure` — no try/catch at the feature layer.

### `errors/app_exception.dart` — `AppException`

```
AppException (abstract)
├── RemoteException   — HTTP errors, timeouts, bad JSON
├── OfflineException  — no network + empty cache
├── LocalException    — sqflite read/write failures
├── NoDataException   — 200 OK but empty body
├── PlaybackException — just_audio load/play errors
└── UnknownException  — anything else, wraps the original
```

Every subclass has `final String userMessage` — a short, sanitized,
end-user-facing string. Raw stack traces and system messages never reach
the UI.

### `network/network_client.dart`

- Rejects any URL where `scheme != 'https'` (throw at call site, not silently).
- 15 s per-request timeout (configurable via `--dart-define`).
- Caps response body at 5 MB (`ContentLengthExceededException`).
- Maps every `SocketException`, `TimeoutException`, `HttpException`, and
  non-2xx status to a typed `AppException` subclass.

### `utils/search_normalizer.dart`

See [Search Normalisation](#search-normalisation) below.

---

## data/ — Models

### `Surah`

| Field | Type | Notes |
| ----- | ---- | ----- |
| `number` | `int` | 1–114 |
| `name` | `String` | Arabic script |
| `englishName` | `String` | e.g. "Al-Fatihah" |
| `englishNameTranslation` | `String` | e.g. "The Opening" |
| `numberOfAyahs` | `int` | verse count |
| `revelationType` | `String` | "Meccan" / "Medinan" |

### `Edition`

| Field | Type | Notes |
| ----- | ---- | ----- |
| `identifier` | `String` | e.g. `ar.alafasy` — used in CDN URL |
| `language` | `String` | ISO 639-1 code |
| `name` | `String` | Arabic/transliterated name |
| `englishName` | `String` | Display name |
| `format` | `String` | always `"audio"` here |
| `type` | `String` | `"versebyverse"` or `"translation"` — **not** used to filter |

### `Track` (composite)

```dart
class Track {
  final Surah surah;
  final Edition edition;

  String get id        => '${surah.number}-${edition.identifier}';
  String get title     => '${surah.englishName} • ${surah.name}';
  String get artist    => edition.englishName.isNotEmpty
                           ? edition.englishName : edition.name;
  String get audioUrl  => ApiConstants.surahAudioUrl(
                           editionIdentifier: edition.identifier,
                           surahNumber: surah.number);

  bool matches(String query) { … }   // uses fuzzyContains
}
```

---

## data/ — Repository & DataSources

### `IQuranRepository`

```dart
abstract interface class IQuranRepository {
  Future<Result<List<Surah>>>    getSurahs({bool forceRefresh = false});
  Future<Result<List<Edition>>>  getReciters();
  Future<Result<List<Surah>>>    searchSurahs(String query);
}
```

### `QuranRepositoryImpl` — cache-first strategy

```
getTracks() called
    │
    ▼
_tracksMemoryCache non-null?  ──YES──▶  return immediately
    │ NO
    ▼
LocalDataSource.getTracks()
    │
    ├─ non-empty  ──▶  populate memory cache → return
    │                  + if online: background refresh
    │
    └─ empty
         │
         ├─ online  ──▶  RemoteDataSource.fetchSurahs() + fetchEditions()
         │               → persist to sqflite → populate memory cache → return
         │
         └─ offline ──▶  Failure(OfflineException)
```

`getSurahs()` and `getReciters()` call `_loadTracks()` first to ensure the
memory caches are warm, then return from their respective slices.

**Featured / verified reciters** (CDN HTTP 200 confirmed at 128 kbps):

```dart
static const Set<String> _featuredReciters = {
  'ar.alafasy',           // Mishary Rashid Alafasy
  'ar.abdulbasitmurattal',// Abdul Basit Abdul Samad (Murattal)
  'ar.abdullahbasfar',    // Abdullah Basfar
};
```

Only these identifiers are returned by `getReciters()`. Other editions from the
API return HTTP 403 for full-Surah CDN files and are silently filtered out.

### `IQuranRemoteDataSource`

```dart
Future<List<Surah>>   fetchSurahs();
Future<List<Edition>> fetchEditions();
```

Endpoints:
- `GET /surah` — all 114 Surahs.
- `GET /edition?format=audio` — **no `type` parameter** (intentional; see
  [API & CDN Details in README](../README.md#api--cdn-details)).

### `IQuranLocalDataSource` (sqflite)

```dart
Future<List<Track>>     getTracks();
Future<void>            saveTracks(List<Track> tracks);
Future<List<Surah>>     getSurahs();
Future<void>            saveSurahs(List<Surah> surahs);
Future<List<Edition>>   getEditions();
Future<void>            saveEditions(List<Edition> editions);
```

Tables:
- `surahs` — columns match `Surah` fields; `number` is PRIMARY KEY.
- `editions` — columns match `Edition` fields; `identifier` is PRIMARY KEY.

---

## data/ — Audio Service

### `IAudioPlayerService`

```dart
abstract interface class IAudioPlayerService {
  Future<void> load(Track track);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);   // 0.5 – 2.0 clamped in PlayerBloc
  Future<void> dispose();

  Stream<Duration>              get positionStream;
  Stream<Duration?>             get durationStream;
  Stream<AudioPlaybackSnapshot> get playbackStream;
}
```

### `JustAudioPlayerService`

`load()` two-stage strategy:
1. Try `LockCachingAudioSource(uri, cacheFile: File(...))` — caches the MP3 to
   disk on first play; subsequent plays are offline-capable.
2. On any exception (some CDN configs reject the cache probe): fall back to
   `AudioSource.uri(uri)` — streaming-only, no disk cache for this track.

`playbackStream` maps `just_audio`'s `PlayerState` to `AudioPlaybackSnapshot`:
```dart
AudioPlaybackSnapshot(
  playing:   s.playing,
  buffering: s.processingState == loading || buffering,
  completed: s.processingState == completed,
)
```

---

## features/search — SearchBloc

### Events

| Event | Fields | Trigger |
| ----- | ------ | ------- |
| `SearchStarted` | — | `initState` of `SearchScreen` |
| `SearchQueryChanged` | `String query` | `TextField.onChanged` (immediate, no debounce — list is in-memory) |
| `SearchRefreshed` | — | Pull-to-refresh |
| `SearchReciterChanged` | `Edition reciter` | User picks a reciter in the bottom sheet |
| `SearchLoadMoreRequested` | — | `ScrollController` listener (debounced 200 ms, fires when `extentAfter < 400`) |

### State fields

| Field | Type | Notes |
| ----- | ---- | ----- |
| `status` | `SearchStatus` | `initial · loading · success · refreshing · failure` |
| `surahs` | `List<Surah>` | Full filtered list |
| `reciters` | `List<Edition>` | Available reciter list |
| `selectedReciter` | `Edition?` | Last picked reciter; pre-selected in picker |
| `visibleCount` | `int` | Pagination cursor; initially `pageSize = 20` |
| `query` | `String` | Current search query |
| `errorMessage` | `String?` | User-friendly error |

Derived:
```dart
List<Surah> get visibleSurahs =>
    surahs.length <= visibleCount ? surahs : surahs.sublist(0, visibleCount);
bool get hasMore => visibleCount < surahs.length;
```

### Pagination behaviour

`visibleCount` resets to `pageSize` (20) on:
- `SearchStarted` / `SearchRefreshed` (new data set)
- `SearchQueryChanged` (filtered set changes length)

`_onLoadMore` increments by `pageSize`, clamped to `surahs.length`:
```dart
final next = (state.visibleCount + pageSize).clamp(0, state.surahs.length);
emit(state.copyWith(visibleCount: next));
```

The `ScrollController` in `_ListPaneState` debounces load-more to at most once
per 200 ms, preventing a cascade during momentum scrolling.

---

## features/player — PlayerBloc

### Events

| Event | Fields | Trigger |
| ----- | ------ | ------- |
| `PlayerTrackSelected` | `Track track` | Tapping a `SurahTile` after picking a reciter |
| `PlayerPlayRequested` | — | Play button |
| `PlayerPauseRequested` | — | Pause button |
| `PlayerSeekRequested` | `Duration position` | Slider `onChangeEnd`, replay button, +10 s button |
| `PlayerStopRequested` | — | Close button in player header |
| `PlayerSpeedChanged` | `double speed` | Speed chip tap (cycle) or long-press menu |
| `_PlayerPositionUpdated` | `Duration position` | Internal; `positionStream` subscription |
| `_PlayerDurationUpdated` | `Duration? duration` | Internal; `durationStream` subscription |
| `_PlayerPlaybackUpdated` | `AudioPlaybackSnapshot` | Internal; `playbackStream` subscription |
| `_PlayerErrorOccurred` | `String message` | Internal; caught in `_onTrackSelected` |

### State fields

| Field | Type | Default |
| ----- | ---- | ------- |
| `track` | `Track?` | `null` |
| `status` | `PlaybackStatus` | `idle` |
| `position` | `Duration` | `Duration.zero` |
| `duration` | `Duration` | `Duration.zero` |
| `speed` | `double` | `1.0` |
| `errorMessage` | `String?` | `null` |

`PlaybackStatus` values: `idle · loading · ready · playing · paused · completed · error`

Derived getters: `hasTrack`, `isPlaying`, `isLoading`, `progress` (0.0–1.0).

### `PlayerTrackSelected` logic

```
Same track tapped?
  └── isPlaying? → pause  |  else → play
Different track?
  └── emit(loading)
      load(track)
      play()
      ── on error → _PlayerErrorOccurred(_describeAudioError(e))
```

`_describeAudioError` translates raw exceptions:
- Contains `"403"` / `"forbidden"` → "This reciter is not available for full-surah streaming."
- Contains `"404"` → "Audio file not found for this surah."
- Contains `"socket"` / `"network"` → "Network error while loading audio."
- Else → "Unable to load audio."

### Speed control

`PlayerSpeedChanged.speed` is clamped to `[0.5, 2.0]` before calling
`IAudioPlayerService.setSpeed()`. The change is immediately reflected in
`PlayerState.speed` so the speed chip re-renders without waiting for a stream
event.

Available speed steps: **0.75 · 1.0 · 1.25 · 1.5 · 2.0×**

---

## UI Layer

### Widget rebuild isolation

The most expensive operation is the position stream (~4 Hz). To ensure it only
rebuilds the seek bar:

```
PlayerPanel
└── BlocSelector (selector: trackId)         ← only rebuilds when track changes
    └── _PanelContent
        ├── _Header
        │   └── BlocSelector<_HeaderVM>      ← track metadata + error only
        ├── _SeekBar
        │   └── BlocBuilder (buildWhen: position OR duration)  ← ticks here only
        └── _Controls
            └── BlocSelector<_ControlsVM>   ← isPlaying / isLoading / speed
```

The tile list never rebuilds on position ticks:
```
_ResultsList (SearchBloc BlocBuilder)
└── buildWhen: status | surahs | visibleCount | errorMessage
    └── BlocBuilder<PlayerBloc> (inner)
        └── buildWhen: track?.id | isPlaying | isLoading
```

### `SurahTile` animation

Uses `TweenAnimationBuilder<double>` rather than `AnimatedContainer` to
avoid triggering a full layout pass on every animation frame:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(end: isActive ? 1.0 : 0.0),
  duration: const Duration(milliseconds: 180),
  curve: Curves.easeOut,
  builder: (context, t, child) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:  Color.lerp(inactiveBg,     activeBg,     t)!,
        border: Border.all(
          color: Color.lerp(inactiveBorder, activeBorder, t)!,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,  // layout subtree is stable — not rebuilt
    );
  },
  child: Material(…),  // built once, passed as stable child
)
```

### Player panel entrance

```dart
AnimatedSize(duration: 300 ms, curve: Curves.easeInOutCubic)
  AnimatedSwitcher(duration: 280 ms)
    SlideTransition(Offset(0,1) → Offset.zero, curve: Curves.easeOutCubic)
    + FadeTransition
```

### `ReciterPicker` bottom sheet

`showReciterPicker(context, reciters: …, selected: …, surahName: …)`

- Shows the Surah name as a subtitle so the user confirms which Surah they are
  about to play.
- The last-used reciter is pre-selected (checkmark) for quick confirm.
- Returns `Edition?` — `null` if the user dismissed without picking.

After the user picks a reciter the caller:
1. Fires `SearchReciterChanged(picked)` — remembers last-used for next tap.
2. Fires `PlayerTrackSelected(Track(surah: surah, edition: picked))` — starts playback.

---

## Dependency Injection

All wiring lives in `lib/core/di/service_locator.dart`.
`get_it` is used as a lazy service locator; all registrations are by interface.

```
GetIt
├── DatabaseService              (singleton — opens sqflite once)
├── IConnectivityService         (singleton)
├── IQuranRemoteDataSource       (lazy singleton)
├── IQuranLocalDataSource        (lazy singleton — needs DatabaseService)
├── IQuranRepository             (lazy singleton — needs Remote + Local + Connectivity)
├── IAudioPlayerService          (lazy singleton)
├── SearchBloc                   (factory — new instance per SearchScreen)
└── PlayerBloc                   (singleton — shared across layouts)
```

`main.dart` calls `await ServiceLocator.setup()` before `runApp()`.

---

## Caching Strategy

Three cache levels, fastest first:

| Level | Storage | Scope | Populated by |
| ----- | ------- | ----- | ------------ |
| Memory | `_surahsMemoryCache` / `_recitersMemoryCache` in `QuranRepositoryImpl` | App session | First `getSurahs()` / `getReciters()` call |
| sqflite | `surahs` + `editions` tables in app-support directory | Persistent across launches | Every successful remote fetch |
| CDN audio | `LockCachingAudioSource` MP3 files in app-support/audio_cache/ | Persistent across launches | First play of each Surah |

On cold start with warm sqflite cache, the app shows the list in ~0 ms (no
network needed). Audio files that have been played before also load instantly.

---

## Search Normalisation

`lib/core/utils/search_normalizer.dart` — `normalizeForSearch(String input)`:

```
input
  → lowercase
  → fold diacritics:  ā/â → a,  ī → i,  ū → u,  ḥ → h,  ʿ/ʾ → (empty)
  → strip non-alphanumeric characters (hyphens, spaces, punctuation)
  → collapse consecutive duplicate letters: "aa" → "a", "ll" → "l"
  → drop trailing "h"
```

Examples:

| User types | Normalised | Matches |
| ---------- | ---------- | ------- |
| `"al fatihah"` | `"alfatia"` | `"Al-Faatiha"` → `"alfatia"` ✓ |
| `"al fatiha"` | `"alfatia"` | `"Al-Faatiha"` → `"alfatia"` ✓ |
| `"alfatehah"` | `"alfatea"` | `"Al-Faatiha"` → `"alfatia"` — near-match |
| `"ikhlas"` | `"ikhlas"` | `"Al-Ikhlaas"` → `"iklax"` ✓ |
| `"114"` | (number match, bypass normaliser) | Surah 114 ✓ |

`fuzzyContains(haystack, needle)` normalises both sides before calling
`String.contains`.

---

## Error Handling

```
Network / sqflite error
        │
        ▼
NetworkClient / LocalDataSourceImpl
  → wraps in RemoteException / LocalException / OfflineException
        │
        ▼
QuranRepositoryImpl
  → returns Failure(AppException)
        │
        ▼
SearchBloc._onStarted / _onRefreshed
  → state.copyWith(status: failure, errorMessage: e.userMessage)
        │
        ▼
_ResultsList (UI)
  → renders EmptyStateView with errorMessage + "Try again" CTA
```

Audio errors follow a similar path through `PlayerBloc._onTrackSelected`:
```
just_audio exception
        │
        ▼
_describeAudioError(e) → human-readable string
        │
        ▼
add(_PlayerErrorOccurred(message))
        │
        ▼
PlayerState(status: error, errorMessage: message)
        │
        ▼
_Header widget shows message in red below track name
```

---

## Responsive Layout

`lib/core/responsive/responsive.dart` — `ResponsiveInfo`:

| Property | Logic |
| -------- | ----- |
| `useTwoPane` | `width >= 600 || (width >= 500 && height < 480)` |
| `isShortHeight` | `height < 480` — compact (single-row) search header |
| `contentMaxWidth` | `720.0` — max width of the list column in two-pane |

`SearchScreen.build()`:
```
LayoutBuilder
  └── useTwoPane?
      ├── YES: Row [ _ListPane(flex:3) | divider | _PlayerPane(flex:2) ]
      └── NO:  Column [ _ListPane(Expanded) | PlayerPanel (bottom) ]
```

`textScaler` clamp in `app.dart`:
```dart
MediaQuery(
  data: MediaQuery.of(context).copyWith(
    textScaler: MediaQuery.textScalerOf(context)
        .clamp(minScaleFactor: 0.85, maxScaleFactor: 1.30),
  ),
  child: …
)
```
