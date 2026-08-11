# zcrud_geo_location

Ready-made "my position" resolver for [zcrud_geo](../zcrud_geo): a `ZGeoLocationResolver` backed by [geolocator](https://pub.dev/packages/geolocator), with distinct failure causes. The host injects `zcrudGeolocatorResolver()` and never imports `geolocator` itself — no geolocator type appears in the public API.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_geo_location: ^0.81.0
```

## Minimal example

```dart
import 'package:zcrud_geo_location/zcrud_geo_location.dart';

// Inject into the geo field seam (the field hides the button when absent,
// and recenters at zoom 16 on the resolved position):
final resolver = zcrudGeolocatorResolver(
  onFailure: (cause) {
    // The USER-FACING MESSAGE is yours (l10n lives in the host app).
    // The legacy parity behaviour: show a message on serviceDisabled,
    // stay silent on permission refusals.
  },
);
// e.g. ZGeoFieldWidget.builder(locationResolver: resolver)
```

## Failure-cause contract

The resolver **never throws** (AD-10). Any failure completes with `null` — the nominal contract of the `ZGeoLocationResolver` port — after notifying `onFailure` with exactly one distinct cause:

| Cause | Meaning | Legacy parity (`gff:219-265`) |
|---|---|---|
| `serviceDisabled` | Device location service is off | Legacy shows a SnackBar — inform the user |
| `permissionDenied` | `denied` at check, still `denied` after the single re-request | Legacy returns silently |
| `permissionDeniedForever` | Denied forever (at check — no re-request — or after it); only system settings can reopen it | Legacy returns silently |
| `error` | Plugin exception, read timeout (10 s), or out-of-bounds/non-finite position | Legacy `catch` → silent abandon |

On success `onFailure` is never called. Reading uses `LocationAccuracy.high`, `distanceFilter: 10`, `timeLimit: 10 s` (legacy parity). Each resolver call replays the full cycle (service and permission are re-checked every time).

## Platform permissions — declared by the HOST app

This package embeds **no manifest and declares no permission**. Your app must declare them:

**Android** — `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<!-- Optional coarse fallback: -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** — `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Explain here why your app needs the user's position.</string>
```

Without these declarations the permission request fails at the OS level and the resolver reports `permissionDenied`/`error` — it still never throws.

## Testing in the host

The plugin layer is injectable: implement the neutral `ZGeoLocationGateway` port (service flag, permission states, position) and pass it via `zcrudGeolocatorResolver(gateway: fake)` to drive every branch without touching the platform channel.

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT — see [LICENSE](LICENSE).
