# Changelog

All notable changes to `zcrud_geo_location` are documented in this file.

## 0.81.0

Initial release (G10 — CR geo parité legacy 2026-08-11).

- `zcrudGeolocatorResolver({onFailure, gateway})`: turnkey `ZGeoLocationResolver` backed by `geolocator` (legacy parity `gff:219-265`: service check, single permission re-request, `LocationAccuracy.high` / `distanceFilter: 10` / 10 s time limit).
- Distinct failure causes `ZGeoLocationFailureCause` (`serviceDisabled`, `permissionDenied`, `permissionDeniedForever`, `error`) delivered via `onFailure`; the resolver itself never throws (AD-10) and completes `null` on failure, per the port contract.
- Neutral, injectable plugin port `ZGeoLocationGateway` (+ `ZGeoLocationPermission`) so hosts and tests can fake the platform layer; no geolocator type in the public API (AD-1).
- No platform permission embedded: AndroidManifest/Info.plist declarations are the host's (documented in the README).
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. Published under the MIT license.
