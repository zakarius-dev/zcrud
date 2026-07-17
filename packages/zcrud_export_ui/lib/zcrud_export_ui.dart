/// Barrel d'API publique de `zcrud_export_ui` — satellite PLATEFORME d'export
/// (su-11, AD-42).
///
/// `zcrud_export` reste PUR (bytes in/out) ; ce package porte les maillons de
/// PLATEFORME :
/// - [ZFlutterMathLatexRasterizer] : impl concrète du port pur `ZLatexRasterizer`
///   (rendu `flutter_math_fork` hors écran → PNG) ;
/// - [ZPdfShareService] / [ZPdfPreview] : preview / impression / partage de bytes
///   PDF via `printing`.
///
/// 🔴 **Isolation (AD-42/AD-8)** : ce barrel n'exporte **AUCUN** symbole
/// `printing` / `pdf` / `flutter_math_fork`. L'API publique est **100%
/// `Uint8List`** (les types `PdfPageFormat` / `Math` / … sont absorbés dans
/// `lib/src/`). Gardé par `test/z_export_ui_confinement_test.dart`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_export_ui_api.dart' show ZExportUiApi;
export 'src/data/z_flutter_math_latex_rasterizer.dart'
    show ZFlutterMathLatexRasterizer;
export 'src/data/z_pdf_share_service.dart' show ZPdfShareService;
export 'src/presentation/z_pdf_preview.dart' show ZPdfPreview;
