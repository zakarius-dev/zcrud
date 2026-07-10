# zcrud_markdown

Rich Markdown editing and reading for zcrud, built on Quill. The editor exposes a neutral value (Delta JSON) through a `ZFormController` slice — no Quill type leaks into the public API — with a pluggable `ZCodec` and LaTeX/table embeds.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_markdown: ^0.1.0
```

## Minimal example

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

// The field is described once by a ZFieldSpec; its value lives in a controller slice.
const bodyField = ZFieldSpec(
  name: 'body',
  type: EditionFieldType.markdown,
  label: 'Body',
);

// A rich-text field bound to the `body` slice of the form controller.
// The stored value is a neutral Delta JSON, never a Quill type.
Widget buildBody(ZFormController controller) => ZMarkdownField(
      key: const ValueKey(bodyField.name),
      controller: controller,
      field: bodyField,
    );
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
