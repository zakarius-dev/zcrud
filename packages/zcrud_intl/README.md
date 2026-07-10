# zcrud_intl

International fields for zcrud: phone, country and address. Slice values are neutral (`ZPhoneNumber` in E.164, ISO alpha-2 country codes, `ZPostalAddress`) and the country catalogue is a lazily-loaded bundled asset. No third-party intl type leaks into the public API.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_intl: ^0.1.0
```

## Minimal example

```dart
import 'package:zcrud_intl/zcrud_intl.dart';

// Neutral, E.164-based phone value (parsing/formatting lives in the field widget).
const phone = ZPhoneNumber(e164: '+22790000000', isoCode: 'NE');
// Persist the neutral map; rehydrate defensively (never throws):
final map = phone.toMap();
final restored = ZPhoneNumber.fromMap(map);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
