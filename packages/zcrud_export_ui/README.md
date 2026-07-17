# zcrud_export_ui

Platform export destinations for zcrud. `zcrud_export` stays pure (bytes in, bytes out); everything that needs a real platform lives here:

- **PDF preview / print / share** of already-rendered PDF bytes, via [`printing`](https://pub.dev/packages/printing). The public API is `Uint8List` only — `printing` and its transitive `pdf` (including `PdfPageFormat`) never cross this package boundary.
- **The concrete LaTeX rasterizer** (`ZFlutterMathLatexRasterizer`), implementing the pure `ZLatexRasterizer` port declared in `zcrud_export`, via [`flutter_math_fork`](https://pub.dev/packages/flutter_math_fork) (offscreen render → PNG).

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — reusable rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

`zcrud_export_ui` is a **leaf**: no zcrud package depends on it. Its only zcrud edges are `zcrud_export` and `zcrud_core` (AD-1, acyclic).

## Install

```yaml
dependencies:
  zcrud_export_ui: ^0.2.1
```

## Minimal example

```dart
import 'package:zcrud_export/zcrud_export.dart';
import 'package:zcrud_export_ui/zcrud_export_ui.dart';

// 1. Render the PDF bytes with the PURE template + the concrete rasterizer.
final rasterizer = ZFlutterMathLatexRasterizer();
final template = ZFlashcardPdfTemplate(rasterizer: rasterizer);
final file = await template.build(input, answerVisibility: ZAnswerVisibility.withAnswers);

// 2. Preview / print / share the bytes (platform).
await ZPdfShareService().share(file.bytes, fileName: file.fileName);
// or embed: ZPdfPreview(bytes: file.bytes)
```
