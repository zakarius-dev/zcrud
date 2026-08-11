/// Port PUR de rasterisation LaTeX.
///
/// `ZFlashcardPdfTemplate` (fonction PURE, dans `zcrud_export_pdf`) doit
/// insérer des formules LaTeX **dans le flux du PDF**, mais rasteriser une
/// formule exige un **rendu Flutter hors écran** (widget → pixels) =
/// **plateforme**, incompatible avec la pureté de ce paquet (bytes in/out,
/// sans `dart:ui` de rendu écran ni `printing`).
///
/// La résolution est un **port** : ce paquet déclare l'**abstraction** pure
/// ci-dessous (LaTeX `String` → PNG `Uint8List?`), et l'**impl concrète**
/// (`flutter_math_fork` → capture hors écran → PNG) vit dans le satellite
/// plateforme `zcrud_export_ui`. Le gabarit ne dépend QUE de ce port : aucun
/// type de plateforme ne franchit ce paquet.
///
/// **Défensif (invariant AD-10)** : l'impl renvoie `null` (jamais un throw) si
/// la formule est invalide/vide/non rendue — le gabarit retombe alors sur le
/// **texte brut** de la formule (jamais de trou ni d'exception vers
/// l'appelant).
library;

import 'dart:typed_data';

/// Rasterise une formule LaTeX en **PNG** (bytes neutres) pour insertion inline
/// dans un document généré par ce paquet.
///
/// Contrat :
/// - Entrée : la **source LaTeX brute** (sans délimiteurs `$`), ex. `x^2 + 1`.
/// - Sortie : les **bytes PNG** du rendu (préfixe magic-number PNG), ou `null`
///   si le rendu échoue / la source est vide / invalide.
/// - **Ne lève JAMAIS** (invariant AD-10) : toute erreur de parsing/rendu →
///   `Future.value(null)`.
///
/// [logicalWidth] : largeur logique max souhaitée pour le rendu (px logiques) —
/// indicatif ; l'impl peut l'ignorer (la formule est généralement rendue à sa
/// taille naturelle puis mise à l'échelle par le gabarit sur la hauteur de ligne).
///
/// L'impl concrète (`flutter_math_fork`) vit dans `zcrud_export_ui` : ce
/// paquet ne connaît QUE cette interface (aucune arête `flutter_math_fork`).
abstract interface class ZLatexRasterizer {
  /// Rasterise [latex] en bytes PNG, ou `null` si le rendu échoue (jamais throw).
  Future<Uint8List?> rasterize(String latex, {double? logicalWidth});
}
