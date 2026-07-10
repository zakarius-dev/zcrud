# zcrud_riverpod

The optional Riverpod state and injection binding for zcrud (targets the lex_douane / IFFD host apps). Provides `ZcrudRiverpodScope` (mounts a `ProviderScope` and an auto-dispose `zFormControllerProvider`) and `ZRiverpodResolver` for seam resolution — reusing the core reactivity rather than reimplementing it.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_riverpod: ^0.1.0
```

## Minimal example

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

Widget wrap(Widget child) => ZcrudRiverpodScope(child: child);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
