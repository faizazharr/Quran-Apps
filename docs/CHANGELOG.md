# Changelog

All notable changes to **Quran Player** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/) — see [VERSIONING.md](VERSIONING.md).

---

## [Unreleased]

> Changes staged on `main` that have not yet been tagged as a release.

---

## [1.0.0+1] — 2026-05-30

Initial production-ready release. Covers all test-brief requirements plus
extensive bonus hardening.

### Added

#### UX & features
- **Surah-first list** — browse all 114 Surahs in a single paginated list (was 912 rows = 114 × 8 reciters).
- **Per-surah reciter picker** — tapping a Surah opens a bottom sheet to choose the reciter. The last-used reciter is pre-selected for one-tap confirm. Sheet shows the Surah name as a subtitle for context.
- **Fuzzy search normalisation** (`SearchNormalizer`) — strips diacritics, collapses doubled vowels, drops trailing *h*. "al fatihah", "al fatiha", "al fateha" all match "Al-Faatiha".
- **Paginated list** — `SearchBloc` exposes 20 Surahs at a time (`pageSize = 20`). Further pages load on scroll via a debounced `ScrollController` listener (200 ms debounce, 400 px threshold).
- **Playback speed control** — speed chip in the player controls row.
  - Tap to cycle: 0.75 → 1.0 → 1.25 → 1.5 → 2.0×.
  - Long-press for direct-select popup menu.
  - Chip highlighted (brighter background, bold text) when speed ≠ 1.0×.
- **ReciterChip** component and `showReciterPicker` bottom sheet (reusable across contexts).
- **Reciter name on active tile** — the playing tile shows a microphone icon + reciter name when playback is active.

#### Architecture
- `IAudioPlayerService.setSpeed(double speed)` method added to the interface and `JustAudioPlayerService` implementation.
- `PlayerSpeedChanged` event + `speed` field on `PlayerState`.
- `SearchBloc` events: `SearchReciterChanged`, `SearchLoadMoreRequested`.
- `SearchState` fields: `reciters`, `selectedReciter`, `visibleCount`.
- `QuranRepository` interface extended with `getSurahs()`, `getReciters()`, `searchSurahs()`.
- `QuranRepositoryImpl` memory caches: `_surahsMemoryCache`, `_recitersMemoryCache`.
- `SearchNormalizer` utility (`lib/core/utils/search_normalizer.dart`).

#### Performance
- `BouncingScrollPhysics` — elastic scroll momentum on both platforms.
- Scroll-triggered pagination replaces `initState`-triggered pagination (eliminates infinite cascade when `PlayerBloc` emits position ticks).
- `TweenAnimationBuilder<double>` + `Color.lerp` for `SurahTile` active highlight — only the decoration colour is interpolated; layout is never touched.
- Player panel entrance animation uses `Curves.easeInOutCubic` / `Curves.easeOutCubic` (was `Curves.easeOut`).
- `cacheExtent` increased to 800 px (was 600).
- `buildWhen` guards on all `BlocBuilder` / `BlocSelector` subscribers so position ticks (~4 Hz) only rebuild `_SeekBar`.

#### Testing
- `test/core/search_normalizer_test.dart` — 9 tests covering diacritics, vowel collapse, trailing-*h* drop, `fuzzyContains` positive/negative, "al fatihah" integration case.
- `test/features/player_bloc_test.dart` extended — `speed` field defaults and `copyWith`.
- **35 total tests, 0 lint issues**.

#### API & CDN
- `GET /edition?format=audio` without `type` filter — `ar.abdulbasitmurattal` has `type=translation` in the API but works on CDN; filtering by `type=versebyverse` would incorrectly exclude it.
- Featured reciters narrowed to 3 verified HTTP 200 at 128 kbps: `ar.alafasy`, `ar.abdulbasitmurattal`, `ar.abdullahbasfar`.

#### Docs
- `docs/ARCHITECTURE.md` — full layer diagrams, data flows, BLoC event/state tables, caching strategy, search normalisation, error handling.
- `docs/CHANGELOG.md` — this file.
- `README.md` — major rewrite: accurate project structure, updated test count (35), API & CDN details section, per-feature documentation, correct widget names.

### Fixed
- `_ListFooter` (StatefulWidget) called `onLoadMore()` in `initState`, which fired on every `PlayerBloc` position update (~4 Hz) → all 114 items loaded instantly. Replaced with a `ScrollController`-based `_PaginationFooter` (StatelessWidget, no side effects).
- Reciter change not reflected in list — `buildWhen` on the list `BlocBuilder` was missing `selectedReciter` comparison. Fixed and later refactored away by moving reciter selection to per-surah bottom sheet.
- `PlayerBloc` playback errors showed a generic "Playback failed" message. `_describeAudioError` now produces specific messages for HTTP 403, 404, and network errors.
- `GET /edition?format=audio&type=versebyverse` excluded `ar.abdulbasitmurattal` (its API `type` is `translation` but CDN files exist). Removed `type` parameter.
- Raw exception messages (including stack traces) were reachable in debug UI. All paths now use `AppException.userMessage`.

### Security
- Android Network Security Config: cleartext traffic prohibited; only `api.alquran.cloud` and `cdn.islamic.network` trusted; user-installed CAs restricted to debug builds.
- iOS ATS: `NSAllowsArbitraryLoads=false`.
- `allowBackup="false"` + `data_extraction_rules.xml`.
- R8 minify + resource shrink + ProGuard rules in release.
- `NetworkClient` rejects non-HTTPS URLs at runtime.
- `NetworkClient` caps responses at 5 MB.

---

## Version History Summary

| Version | Date | Description |
| ------- | ---- | ----------- |
| 1.0.0+1 | 2026-05-30 | Initial production release |

---

[Unreleased]: https://github.com/faizazharr/Quran-Apps/compare/v1.0.0+1...HEAD
[1.0.0+1]: https://github.com/faizazharr/Quran-Apps/releases/tag/v1.0.0+1
