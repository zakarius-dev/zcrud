# zcrud_core

The pure domain and Flutter-native reactive edition engine of zcrud. A single `ZFieldSpec` schema drives both edition forms and list tables; form state lives in a `ChangeNotifier`-based `ZFormController` so each field rebuilds only its own slice (no global form refresh). This is the dependency sink of the monorepo — it pulls in no other `zcrud_*` package and no heavy backend.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_core: ^0.1.0
```

## Minimal example

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

// Describe a field once; the same spec drives forms and lists.
const nameField = ZFieldSpec(
  name: 'name',
  type: EditionFieldType.text,
  label: 'Name',
);

// Form state is a pure Flutter Listenable — each field owns its own slice.
final controller = ZFormController(initialValues: {nameField.name: ''});

// A widget that rebuilds ONLY when the 'name' slice changes, never the whole form.
Widget buildNameField() => ValueListenableBuilder<Object?>(
      valueListenable: controller.fieldListenable(nameField.name),
      builder: (context, value, child) => Text('$value'),
    );

// Writing a value notifies only that field's slice (no global form refresh).
// controller.setValue(nameField.name, 'Ada');
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
