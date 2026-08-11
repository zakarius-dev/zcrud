/// Options de **mise en page PDF** — neutres, immuables, `const`-constructibles.
///
/// Ce type vit ENTIÈREMENT dans `zcrud_export_pdf` (aucun ajout dans
/// `zcrud_core`) : il ne porte AUCUN type Syncfusion ni `zcrud_core`. Il
/// paramètre le **rendu** des backends confinés (`z_pdf_exporter.dart`,
/// `z_pdf_document_builder.dart`) sans jamais toucher la **projection**
/// tabulaire (`ZExportTable.fromRequest`, source unique de formatage).
///
/// Champs (tous à défaut sûr = comportement historique quand
/// `ZPdfExportOptions()` non fourni) :
/// - [orientation] : portrait (défaut) ou paysage. Le paysage élargit la page →
///   plus de colonnes rendues avant pagination (anti-rognage complémentaire).
/// - [title] : titre optionnel dessiné en haut du document (null = aucun).
/// - [repeatHeader] : répète la ligne d'en-tête sur chaque page auto-paginée
///   (défaut `true`).
/// - [header] : en-tête riche optionnel (logo + hiérarchie organisationnelle +
///   sous-titre), voir [ZPdfHeaderSpec]. `null` (défaut) = repli STRICT sur
///   le rendu historique du [title] seul.
library;

import 'dart:typed_data';

/// Orientation de page PDF **neutre** (mappe vers `PdfPageOrientation` dans le
/// backend confiné — jamais exposée sous forme de type Syncfusion).
enum ZPdfOrientation {
  /// Page verticale (défaut).
  portrait,

  /// Page horizontale (plus large : réduit le rognage des tables à colonnes
  /// nombreuses).
  landscape,
}

/// En-tête PDF **riche**, neutre et immuable : logo + hiérarchie
/// organisationnelle + sous-titre.
///
/// Purement déclaratif : ni police, ni couleur, ni type Syncfusion — seulement
/// des DONNÉES (bytes d'image + chaînes fournies par l'hôte). Le rendu (police,
/// alignement, gabarit) reste interne au backend confiné
/// (`z_pdf_exporter.dart`). Aucun libellé n'est codé en dur ici : les
/// [organizationLines]/[subtitle] sont systématiquement fournis par l'appelant,
/// jamais une valeur littérale zcrud.
///
/// Défensif (invariant AD-10) : des [logoBytes] non décodables comme image ne
/// font PAS échouer le rendu — le logo est simplement omis, le reste de
/// l'en-tête (lignes organisationnelles, titre, sous-titre) est rendu
/// normalement.
class ZPdfHeaderSpec {
  /// Construit un en-tête riche immuable.
  const ZPdfHeaderSpec({
    this.logoBytes,
    this.logoWidth = 60,
    this.logoHeight = 60,
    this.organizationLines = const <String>[],
    this.subtitle,
  });

  /// Bytes d'image du logo (PNG/JPEG…), dessiné en haut du document. `null` =
  /// aucun logo. Bytes non décodables → logo omis, sans exception (invariant
  /// AD-10).
  final Uint8List? logoBytes;

  /// Largeur de rendu du logo (points PDF). Défaut `60`.
  final double logoWidth;

  /// Hauteur de rendu du logo (points PDF). Défaut `60`.
  final double logoHeight;

  /// Lignes organisationnelles (ex. agence / division / section), fournies par
  /// l'hôte, dessinées centrées sous le logo. Vide (défaut) → bloc omis.
  final List<String> organizationLines;

  /// Sous-titre optionnel dessiné sous le [ZPdfExportOptions.title]. `null`
  /// (défaut) → aucun sous-titre.
  final String? subtitle;

  bool _sameLines(List<String> other) {
    if (identical(organizationLines, other)) return true;
    if (organizationLines.length != other.length) return false;
    for (var i = 0; i < organizationLines.length; i++) {
      if (organizationLines[i] != other[i]) return false;
    }
    return true;
  }

  bool _sameBytes(Uint8List? other) {
    final mine = logoBytes;
    if (identical(mine, other)) return true;
    if (mine == null || other == null) return mine == other;
    if (mine.length != other.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != other[i]) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPdfHeaderSpec &&
          runtimeType == other.runtimeType &&
          _sameBytes(other.logoBytes) &&
          logoWidth == other.logoWidth &&
          logoHeight == other.logoHeight &&
          _sameLines(other.organizationLines) &&
          subtitle == other.subtitle;

  @override
  int get hashCode => Object.hash(
        logoBytes == null ? 0 : Object.hashAll(logoBytes!),
        logoWidth,
        logoHeight,
        Object.hashAll(organizationLines),
        subtitle,
      );
}

/// Options de mise en page immuables pour l'export PDF (tabulaire + images).
class ZPdfExportOptions {
  /// Construit des options immuables. Défauts = comportement historique
  /// (portrait, sans titre, en-tête répété, sans en-tête riche).
  const ZPdfExportOptions({
    this.orientation = ZPdfOrientation.portrait,
    this.title,
    this.repeatHeader = true,
    this.latexEnabled = true,
    this.header,
  });

  /// Orientation de la/des page(s). Défaut : [ZPdfOrientation.portrait].
  final ZPdfOrientation orientation;

  /// Titre optionnel dessiné en haut du document (null → aucun titre).
  final String? title;

  /// En-tête riche optionnel (logo, lignes organisationnelles, sous-titre) —
  /// voir [ZPdfHeaderSpec]. `null` (défaut) : repli STRICT sur le rendu
  /// historique du [title] seul, sans rupture pour un appelant existant.
  final ZPdfHeaderSpec? header;

  /// Répète la ligne d'en-tête sur chaque page auto-paginée (défaut `true`).
  final bool repeatHeader;

  /// Interprète `$...$` comme du **LaTeX inline** dans les gabarits qui composent
  /// texte + formules (défaut `true` = comportement historique).
  ///
  /// Une tokenisation inconditionnelle laisserait un corpus où `$` est un
  /// symbole monétaire (« 100 $ US ») sans recours. Passer `false` traite le
  /// texte comme littéral — `$` compris.
  ///
  /// Ce drapeau ne « répare » pas le repli : le repli texte **réémet les
  /// délimiteurs** dans les deux cas, `true` n'est donc jamais lossy.
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
          latexEnabled == other.latexEnabled &&
          header == other.header;

  @override
  int get hashCode =>
      Object.hash(orientation, title, repeatHeader, latexEnabled, header);
}
