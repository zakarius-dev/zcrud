# zcrud_provider

The optional `provider` state and injection binding for zcrud, completing the multi-state-manager matrix. Provides `ZcrudProviderScope` (a `ChangeNotifierProvider<ZFormController>` with provider-managed disposal) and `ZProviderResolver` for seam resolution.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_provider: ^0.1.0
```

## Minimal example

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_provider/zcrud_provider.dart';

Widget wrap(Widget child) => ZcrudProviderScope(child: child);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
