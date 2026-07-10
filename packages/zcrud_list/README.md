# zcrud_list

The `DynamicList` data-grid backend for zcrud, powered by Syncfusion `SfDataGrid`. It provides the concrete `ZSfDataGridRenderer` behind the neutral `ZListRenderer` port declared in `zcrud_core`, so consumers that do not import `zcrud_list` never pull Syncfusion.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_list: ^0.1.0
```

## Minimal example

```dart
import 'package:zcrud_list/zcrud_list.dart';

// Plug the Syncfusion-backed renderer into the neutral ZListRenderer port.
const ZListRenderer renderer = ZSfDataGridRenderer();
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
