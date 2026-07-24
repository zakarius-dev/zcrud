/// Options de **mise en page PDF** — neutres, immuables, `const`-constructibles.
///
/// origine: E11b-3 (Axe C, clôt LOW-1 d'E11a-3 : tables larges rognées). Ce type
/// vit ENTIÈREMENT dans `zcrud_export` (aucun ajout dans `zcrud_core`) : il ne
/// porte AUCUN type Syncfusion ni `zcrud_core`. Il paramètre le **rendu** des
/// backends confinés (`z_pdf_exporter.dart`, `z_pdf_document_builder.dart`) sans
/// jamais toucher la **projection** tabulaire (`ZExportTable.fromRequest`, source
/// unique de formatage, SM-5).
///
/// Champs (tous à défaut sûr = comportement E11a-3 quand `ZPdfExportOptions()`
/// non fourni) :
/// - [orientation] : portrait (défaut) ou paysage. Le paysage élargit la page →
///   plus de colonnes rendues avant pagination (anti-rognage complémentaire).
/// - [title] : titre optionnel dessiné en haut du document (null = aucun).
/// - [repeatHeader] : répète la ligne d'en-tête sur chaque page auto-paginée
///   (défaut `true`).
library;

/// Orientation de page PDF **neutre** (mappe vers `PdfPageOrientation` dans le
/// backend confiné — jamais exposée sous forme de type Syncfusion).
enum ZPdfOrientation {
  /// Page verticale (défaut).
  portrait,

  /// Page horizontale (plus large : réduit le rognage des tables à colonnes
  /// nombreuses).
  landscape,
}

/// Options de mise en page immuables pour l'export PDF (tabulaire + images).
class ZPdfExportOptions {
  /// Construit des options immuables. Défauts = comportement E11a-3
  /// (portrait, sans titre, en-tête répété).
  const ZPdfExportOptions({
    this.orientation = ZPdfOrientation.portrait,
    this.title,
    this.repeatHeader = true,
    this.latexEnabled = true,
  });

  /// Orientation de la/des page(s). Défaut : [ZPdfOrientation.portrait].
  final ZPdfOrientation orientation;

  /// Titre optionnel dessiné en haut du document (null → aucun titre).
  final String? title;

  /// Répète la ligne d'en-tête sur chaque page auto-paginée (défaut `true`).
  final bool repeatHeader;

  /// Interprète `$...$` comme du **LaTeX inline** dans les gabarits qui composent
  /// texte + formules (défaut `true` = comportement historique).
  ///
  /// CR-LEX-41 §B : la tokenisation était **inconditionnelle**, donc un corpus
  /// où `$` est un symbole monétaire (« 100 $ US ») n'avait aucun recours. Passer
  /// `false` traite le texte comme littéral — `$` compris.
  ///
  /// ⚠️ Ce drapeau ne « répare » pas le repli : depuis CR-LEX-41, le repli texte
  /// **réémet les délimiteurs** dans les deux cas, donc `true` n'est plus lossy.
  /// `latexEnabled: false` sert à empêcher la *rasterisation* d'un segment qui
  /// n'est pas une formule, pas à éviter une perte.
  final bool latexEnabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPdfExportOptions &&
          runtimeType == other.runtimeType &&
          orientation == other.orientation &&
          title == other.title &&
          repeatHeader == other.repeatHeader &&
          latexEnabled == other.latexEnabled;

  @override
  int get hashCode =>
      Object.hash(orientation, title, repeatHeader, latexEnabled);
}
