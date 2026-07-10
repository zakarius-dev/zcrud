# zcrud_get

The optional GetX + get_it state and injection binding for zcrud (targets the DODLP host app). Provides `ZcrudGetScope` (creates/scopes/disposes the `ZFormController` along the GetX/get_it lifecycle) and `ZGetResolver` for seam resolution — reusing the core reactivity.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_get: ^0.1.0
```

## Minimal example

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_get/zcrud_get.dart';

Widget wrap(Widget child) => ZcrudGetScope(child: child);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
