# zcrud_export

Tabular export for zcrud: turn a neutral render request (columns and rows from `zcrud_core`) into Excel (`.xlsx`) or PDF bytes via Syncfusion. The Syncfusion backends are confined to the implementation — the public `ZExporter` API returns neutral `Uint8List`.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_export: ^0.1.0
```

## Minimal example

```dart
import 'dart:typed_data';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

Uint8List exportXlsx() {
  // Neutral render request from zcrud_core: columns derived from the schema + rows.
  final request = ZListRenderRequest.fromSchema(
    const [ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name')],
    const [ZListRow(id: '1', cells: {'name': 'Ada'})],
  );
  // Synchronous; returns neutral bytes. Syncfusion stays confined to the impl.
  return const ZExporter().toExcelBytes(request); // toPdfBytes for PDF
}
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
