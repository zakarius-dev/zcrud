/// Jeu de styles rich-text **NEUTRE** injectable PAR CHAMP (GAP-5, CR parité
/// 2026-08-11) + spec de rendu des **formules** (GAP-7).
///
/// ## Pourquoi l'« injection par l'hôte » et PAS des valeurs DODLP chez nous
///
/// Le legacy DODLP (`quill_default_styles_helper.dart`, `qdsh`) construit un
/// `DefaultStyles` Quill « signature » : polices Google (**Inter** corps,
/// **Poppins** titres, **FiraCode** code), palette figée (gras rose, italique
/// bleu, H2 teal, souligné teal, barré rouge/gris, code inline orange/fond
/// gris, bloc code vert/bordure, citation bordure teal 4 px), hauteurs de
/// ligne (corps 2.0 édition / 1.7 lecture ; titres 1.8/1.3) et espacements
/// par niveau. AUCUNE de ces valeurs n'entre dans `zcrud_markdown` :
///
/// * **Refus des polices Google** : embarquer Inter/Poppins/FiraCode
///   ajouterait une arête `google_fonts` (téléchargement réseau ou assets
///   lourds) au satellite — contraire à AD-1 (dépendances minimales) et
///   inutile : chaque slot de [ZRichTextStyleSet] est un [TextStyle] complet,
///   l'hôte y pose `GoogleFonts.inter(...)` LUI-MÊME.
/// * **Refus de la palette en dur** (FR-26) : les couleurs signature restent
///   chez l'hôte, qui les injecte par ce jeu de styles. La voie « injection »
///   SUFFIT : le pilote DODLP porte ses propres styles, le socle n'a pas
///   besoin d'un fichier de référence de couleurs pour ce gap.
/// * **Le défaut NE CHANGE PAS** (choix AD-13 assumé, `z_rich_text_core.dart`) :
///   `null` ⇒ styles dérivés du seul thème (titres via `TextTheme`), défauts
///   Quill pour le reste — comportement historique STRICTEMENT inchangé
///   (AD-57 : opt-in, null ⇒ inchangé).
///
/// ISOLATION (AD-1/AD-7) : ces types sont PUR Flutter ([TextStyle],
/// [BoxDecoration], [Radius], [Color]) — aucun type Quill. La traduction vers
/// `DefaultStyles` Quill vit dans `z_rich_text_core.dart` (interne).
library;

import 'package:flutter/widgets.dart';

/// Espacement vertical NEUTRE (haut/bas, dp logiques) d'un bloc rich-text.
///
/// Équivalent neutre du `VerticalSpacing` Quill (qui ne peut pas fuir dans la
/// surface publique — AD-7). Le legacy `qdsh` pose de tels couples par niveau
/// (H1 16/8, H2 12/6, … code 8/8, citation 8/8).
@immutable
class ZRichTextSpacing {
  /// Construit un espacement vertical (haut, bas).
  const ZRichTextSpacing(this.top, this.bottom);

  /// Espace AVANT le bloc (dp).
  final double top;

  /// Espace APRÈS le bloc (dp).
  final double bottom;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRichTextSpacing && top == other.top && bottom == other.bottom;

  @override
  int get hashCode => Object.hash(top, bottom);
}

/// Jeu de styles rich-text PAR CHAMP (GAP-5) — chaque slot `null` laisse le
/// style courant (thème + défauts Quill) STRICTEMENT inchangé (AD-57).
///
/// Les slots couvrent la liste `qdsh` mesurée : corps/titres, gras / italique /
/// souligné / barré / indice / exposant, code inline (+ fond + rayon) & bloc
/// (+ décoration), citation (+ décoration — la bordure latérale legacy y
/// passe), listes, lien, tailles small/large/huge, placeholder, hauteurs de
/// ligne (corps / titres) et espacements par famille de bloc.
///
/// Chaque [TextStyle] fourni est **fusionné** (`merge`) sur le style courant du
/// slot : un `TextStyle(color: …)` ne change QUE la couleur, la taille/graisse
/// du thème restent. Les hauteurs de ligne s'appliquent AVANT les slots (un
/// slot portant `height` l'emporte).
@immutable
class ZRichTextStyleSet {
  /// Construit un jeu de styles — tout est optionnel, `null` ⇒ inchangé.
  const ZRichTextStyleSet({
    this.paragraph,
    this.h1,
    this.h2,
    this.h3,
    this.h4,
    this.h5,
    this.h6,
    this.bold,
    this.italic,
    this.underline,
    this.strikeThrough,
    this.subscript,
    this.superscript,
    this.inlineCode,
    this.inlineCodeBackgroundColor,
    this.inlineCodeRadius,
    this.codeBlock,
    this.codeBlockDecoration,
    this.quote,
    this.quoteDecoration,
    this.lists,
    this.link,
    this.sizeSmall,
    this.sizeLarge,
    this.sizeHuge,
    this.placeholder,
    this.lineHeight,
    this.headingLineHeight,
    this.paragraphSpacing,
    this.headingSpacing,
    this.quoteSpacing,
    this.codeBlockSpacing,
    this.listSpacing,
  });

  /// Corps de texte (paragraphe).
  final TextStyle? paragraph;

  /// Titre niveau 1.
  final TextStyle? h1;

  /// Titre niveau 2.
  final TextStyle? h2;

  /// Titre niveau 3.
  final TextStyle? h3;

  /// Titre niveau 4.
  final TextStyle? h4;

  /// Titre niveau 5.
  final TextStyle? h5;

  /// Titre niveau 6.
  final TextStyle? h6;

  /// Gras.
  final TextStyle? bold;

  /// Italique.
  final TextStyle? italic;

  /// Souligné.
  final TextStyle? underline;

  /// Barré.
  final TextStyle? strikeThrough;

  /// Indice.
  final TextStyle? subscript;

  /// Exposant.
  final TextStyle? superscript;

  /// Code inline (style de texte).
  final TextStyle? inlineCode;

  /// Fond du code inline (legacy : gris 200/800).
  final Color? inlineCodeBackgroundColor;

  /// Rayon du fond du code inline (legacy : 4).
  final Radius? inlineCodeRadius;

  /// Bloc de code (style de texte).
  final TextStyle? codeBlock;

  /// Décoration du bloc de code (fond/bordure/rayon — legacy : fond gris,
  /// bordure, rayon 8).
  final BoxDecoration? codeBlockDecoration;

  /// Citation (style de texte).
  final TextStyle? quote;

  /// Décoration de la citation — la **bordure latérale teal 4 px** legacy passe
  /// ici (`Border(left: …)` chez l'hôte ; préférer une bordure directionnelle
  /// si l'hôte vise le RTL).
  final BoxDecoration? quoteDecoration;

  /// Listes (puces/numéros + items).
  final TextStyle? lists;

  /// Lien.
  final TextStyle? link;

  /// Taille « small ».
  final TextStyle? sizeSmall;

  /// Taille « large ».
  final TextStyle? sizeLarge;

  /// Taille « huge ».
  final TextStyle? sizeHuge;

  /// Placeholder (texte indicatif de l'éditeur vide).
  final TextStyle? placeholder;

  /// Hauteur de ligne du CORPS (paragraphe, listes, citation, code bloc) —
  /// legacy : 2.0 édition / 1.7 lecture. Appliquée AVANT les slots.
  final double? lineHeight;

  /// Hauteur de ligne des TITRES (H1..H6) — legacy : 1.8 édition / 1.3 lecture.
  final double? headingLineHeight;

  /// Espacement vertical du paragraphe.
  final ZRichTextSpacing? paragraphSpacing;

  /// Espacement vertical des titres (appliqué H1..H6).
  final ZRichTextSpacing? headingSpacing;

  /// Espacement vertical de la citation.
  final ZRichTextSpacing? quoteSpacing;

  /// Espacement vertical du bloc de code.
  final ZRichTextSpacing? codeBlockSpacing;

  /// Espacement vertical des listes.
  final ZRichTextSpacing? listSpacing;
}

/// Rendu des **formules LaTeX** PAR CHAMP (GAP-7) — NEUTRE (aucun type Quill /
/// math dans la signature).
///
/// MESURE legacy (`rtes:85-101` + `qmew`) : `formulasTextStyle` est le SEUL
/// paramètre réellement câblé sur les builders de formule de l'éditeur Quill
/// legacy ; `formulasBlock/InlineTextScaleFactor` y sont déclarés mais MORTS
/// (jamais lus par `qmew` — ils ne servent qu'au lecteur Markdown minimal,
/// défaut 1.2). zcrud câble les TROIS (style + 2 facteurs) sur ses builders,
/// en édition ET en lecture.
@immutable
class ZRichTextFormulaSpec {
  /// Construit une spec de rendu de formules — tout optionnel, `null` ⇒ inchangé.
  const ZRichTextFormulaSpec({
    this.textStyle,
    this.blockScaleFactor,
    this.inlineScaleFactor,
  });

  /// Style de texte de base des formules (remplace le style ambiant du point
  /// d'insertion quand fourni).
  final TextStyle? textStyle;

  /// Facteur d'échelle des formules **bloc/display** (`latexBlock`/`formula`).
  final double? blockScaleFactor;

  /// Facteur d'échelle des formules **inline** (`latex`/`formula_inline`).
  final double? inlineScaleFactor;
}
