/// Widget de **prévisualisation** PDF (su-11, AC6). Arête `printing` **confinée**
/// (avec `z_pdf_share_service.dart`).
///
/// origine: su-11 (E-STUDY-UI, FR-SU16, AD-42). Prévisualise des bytes PDF déjà
/// rendus (`ZFlashcardPdfTemplate`, PUR) et offre les actions natives de
/// `printing` (imprimer / partager / choisir l'imprimante).
///
/// 🔴 **API publique 100% `Uint8List`** : `ZPdfPreview` prend des `bytes` ; le
/// callback interne de `printing` reçoit un `PdfPageFormat` qui est **ABSORBÉ**
/// (ignoré — les bytes sont déjà mis en page). Aucun type `printing`/`pdf`
/// n'apparaît en signature publique ni au barrel. Gardé par
/// `test/z_export_ui_confinement_test.dart`.
///
/// **A11y (AD-13)** : la surface porte un [Semantics] (« aperçu du document PDF »)
/// et délègue les actions à la barre de `PdfPreview` (cibles natives). Aucun
/// libellé ni couleur codé en dur au-delà du label a11y (fourni via [semanticsLabel]).
library;

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:printing/printing.dart';

/// Prévisualise un PDF (bytes) avec les actions imprimer/partager de `printing`.
class ZPdfPreview extends StatelessWidget {
  /// Construit l'aperçu pour [bytes] (un document PDF déjà rendu).
  const ZPdfPreview({
    super.key,
    required this.bytes,
    this.semanticsLabel = 'Aperçu du document PDF',
    this.canPrint = true,
    this.canShare = true,
  });

  /// Les bytes du PDF à prévisualiser (déjà mis en page).
  final Uint8List bytes;

  /// Libellé a11y de la surface d'aperçu (injecté, jamais figé au fond du rendu).
  final String semanticsLabel;

  /// Autorise l'action « imprimer ».
  final bool canPrint;

  /// Autorise l'action « partager ».
  final bool canShare;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      container: true,
      child: PdfPreview(
        // `PdfPageFormat` (paramètre) ABSORBÉ : les bytes sont déjà mis en page.
        build: (_) => bytes,
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: canPrint,
        allowSharing: canShare,
      ),
    );
  }
}
