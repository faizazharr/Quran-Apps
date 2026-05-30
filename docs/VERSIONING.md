# Versioning & Release Policy

The app version lives in [`pubspec.yaml`](../pubspec.yaml):

```yaml
version: <MAJOR>.<MINOR>.<PATCH>+<BUILD_NUMBER>
```

Flutter forwards these to:

| Platform | `versionName` / `CFBundleShortVersionString` | `versionCode` / `CFBundleVersion` |
| -------- | -------------------------------------------- | --------------------------------- |
| Android  | `MAJOR.MINOR.PATCH`                          | `BUILD_NUMBER`                    |
| iOS      | `MAJOR.MINOR.PATCH`                          | `BUILD_NUMBER`                    |

## Rules

1. **Semantic versioning** for the `MAJOR.MINOR.PATCH` segment:
   - `MAJOR` — breaking API/UX change (data model migration, removed feature).
   - `MINOR` — new feature, backwards-compatible.
   - `PATCH` — bug-fix only, no new feature.
2. **`BUILD_NUMBER` is monotonic.** Increment on **every** uploaded build,
   even if the marketing version is unchanged. Stores reject duplicates.
3. Tag every release in git: `vMAJOR.MINOR.PATCH+BUILD` (e.g. `v1.2.0+45`).

## Build matrix

| Build type | Command                                                         | App id                       | Version name suffix | Notes                              |
| ---------- | --------------------------------------------------------------- | ---------------------------- | ------------------- | ---------------------------------- |
| Debug      | `flutter run`                                                   | `com.example.quran_apps.debug` | `-debug`            | Installable beside release.        |
| Profile    | `flutter run --profile`                                         | `com.example.quran_apps.debug` | `-debug`            | For perf profiling.                |
| Staging    | `flutter build apk --release --dart-define=APP_FLAVOR=staging`  | `com.example.quran_apps`     | none                | Hits staging API URL.              |
| Release    | `flutter build appbundle --release --dart-define=APP_FLAVOR=prod` | `com.example.quran_apps`   | none                | Signed with upload keystore.       |

## Compile-time flags (`--dart-define`)

| Key                       | Default                                            | Purpose                       |
| ------------------------- | -------------------------------------------------- | ----------------------------- |
| `APP_FLAVOR`              | `dev`                                              | `dev` / `staging` / `prod`.   |
| `API_BASE_URL`            | `https://api.alquran.cloud/v1`                     | REST base URL.                |
| `AUDIO_CDN_BASE_URL`      | `https://cdn.islamic.network/quran/audio-surah`    | Audio CDN base URL.           |
| `NETWORK_TIMEOUT_SECONDS` | `15`                                               | Per-request timeout.          |

All URL flags are validated at startup; non-HTTPS values throw in release.

## Cutting a release

```sh
# 1. Bump version in pubspec.yaml (e.g. 1.2.0 → 1.2.1, build 12 → 13)
# 2. Build
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=prod \
  --build-name=1.2.1 \
  --build-number=13

# 3. Tag
git tag -a v1.2.1+13 -m "Release 1.2.1+13"
git push --tags
```
