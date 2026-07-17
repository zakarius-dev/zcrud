# Changelog

All notable changes to `zcrud_export_ui` are documented in this file.

## 0.2.1

Initial release (su-11, epic E-STUDY-UI).

- Platform export satellite for zcrud (AD-42): keeps `zcrud_export` pure (bytes in/out) while hosting the platform-bound pieces.
- `ZFlutterMathLatexRasterizer`: concrete implementation of the pure `ZLatexRasterizer` port (offscreen `flutter_math_fork` render → PNG).
- `ZPdfShareService` + `ZPdfPreview`: PDF preview / print / share of `Uint8List` bytes via `printing` — neutral `Uint8List` API, `PdfPageFormat` absorbed internally.
- Leaf of the AD-1 graph; only zcrud edges are `zcrud_export` and `zcrud_core`.
- Published under the MIT license.
