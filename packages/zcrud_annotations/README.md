# zcrud_annotations

Declarative annotations consumed by the zcrud code generator. Annotate a model once with `@ZcrudModel`, `@ZcrudField` and `@ZcrudId`; `zcrud_generator` reads them statically (never via `reflectable`) to emit serialization, the `ZFieldSpec[]` and registry wiring.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_annotations: ^0.1.0
```

## Minimal example

```dart
import 'package:zcrud_annotations/zcrud_annotations.dart';

@ZcrudModel()
class Note {
  @ZcrudId()
  final String id;

  @ZcrudField(label: 'Title')
  final String title;

  const Note({required this.id, required this.title});
}
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
