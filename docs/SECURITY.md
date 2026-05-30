# Security Policy

## Threat model

The app is a read-only client that streams public Quran metadata + audio.
There are no user accounts, no PII, and no writes to remote services.
The relevant risks are therefore:

| Risk                                      | Mitigation                                                 |
| ----------------------------------------- | ---------------------------------------------------------- |
| MITM on API/audio traffic                 | HTTPS-only + Android NSC + iOS ATS (see below)             |
| Tampered debug build distributed as real  | Debug builds carry `.debug` app id + `-debug` version name |
| Local cache exfiltration via adb backup   | `allowBackup=false`, `data_extraction_rules.xml`           |
| Reverse-engineering of release binary     | R8 minify + resource shrink + ProGuard rules               |
| Secret/keystore leakage in git            | `key.properties`, `*.jks`, `*.env` are gitignored          |
| DoS via oversized response                | `NetworkClient` caps responses at 5 MB                     |
| Error text leaking internals to UI        | All exceptions mapped to sanitized `AppException`          |

## Network layer

1. **Transport.** All endpoints are `https://`. The shared
   [`NetworkClient`](../lib/core/network/network_client.dart):
   - rejects any URI with `scheme != 'https'`,
   - sets a 15 s timeout (overridable via `--dart-define`),
   - caps response bodies at 5 MB,
   - converts every IO exception into a sanitized `AppException`.
2. **Android NSC.**
   [`network_security_config.xml`](../android/app/src/main/res/xml/network_security_config.xml)
   - `cleartextTrafficPermitted="false"` (app-wide and per-domain),
   - only `api.alquran.cloud` and `cdn.islamic.network` are listed,
   - release builds trust system CAs only; user-installed CAs are allowed only in
     `debug-overrides` so dev tools (Charles, mitmproxy) still work.
3. **iOS ATS.** `Info.plist` sets `NSAllowsArbitraryLoads=false` and
   `NSAllowsLocalNetworking=false`.

## Storage

- sqflite cache lives in the app sandbox (`getApplicationSupportDirectory()`).
- Audio cache uses `just_audio`'s `LockCachingAudioSource`, also sandboxed.
- Neither is included in cloud backup or device transfer (see
  [`data_extraction_rules.xml`](../android/app/src/main/res/xml/data_extraction_rules.xml)).
- No data is currently considered sensitive enough to require sqlcipher-style
  encryption; revisit if user accounts are introduced.

## Build & signing

- Debug builds use the auto-generated debug keystore and a `.debug` app id, so
  they cannot be confused with a production install.
- Release builds use the upload keystore configured in `android/key.properties`
  (template: `android/key.properties.example`). When that file is absent the
  build falls back to the debug key and emits a warning — never ship a release
  built this way.
- R8 minify, resource shrink, and the project's
  [`proguard-rules.pro`](../android/app/proguard-rules.pro) are enabled in
  release. `Log.v` / `Log.d` calls are stripped at link time.

## Secrets handling

- No API keys are required by the AlQuran Cloud / Islamic Network endpoints.
- Any future secret **must** be injected at build time via `--dart-define` and
  never committed. CI should pull them from its secret store.

## Reporting

Found a vulnerability? Open a private security advisory on the repo
(do not file a public issue).
