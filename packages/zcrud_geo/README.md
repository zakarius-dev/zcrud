# zcrud_geo

Geo fields for zcrud: a neutral `ZGeoPoint`/`ZGeoShape` value model and a `ZGeoFieldWidget` served through `ZWidgetRegistry`. The optional OpenStreetMap adapter (no API key) lives behind a separate import so the map SDK stays off the default import path.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_geo: ^0.1.0
```

## Minimal example

```dart
import 'package:zcrud_geo/zcrud_geo.dart';
// Optional OSM map adapter (kept off the default import path):
// import 'package:zcrud_geo/adapters/osm.dart';

const point = ZGeoPoint(lat: 13.5, lng: 2.1);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
