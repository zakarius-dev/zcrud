/// `ZRichTextToolbarConfig` (M20) — configuration **granulaire par bouton**
/// de la barre d'outils rich-text, NEUTRE (aucun type Quill).
///
/// Remplace/enrichit l'unique drapeau `showToolbar: bool` par une
/// granularité au bouton (parité legacy `RichTextToolbarConfig` — présets
/// `full`/`minimal`/`markdown`). Consommée par `ZMarkdownField` (voie `controller`
/// ET voie `ctx`) et traduite EN INTERNE (sous `lib/src/`) vers la config Quill —
/// AUCUN type Quill ne fuit dans cette classe ni dans la surface publique
/// (AD-1/AD-7).
///
/// `toolbarConfig` est OPTIONNEL : un `ZMarkdownField` qui n'en fournit pas
/// applique le préset de son MODE (`inline` pour le champ compact, `full` pour
/// la voie `controller` et le plein-écran). Fournie, elle REMPLACE ce préset —
/// elle ne s'y ajoute pas.
///
/// ISOLATION : classe de DONNÉES pure (booléens `const`) — sûre à exporter par le
/// barrel. Sa traduction en `QuillSimpleToolbarConfig` vit dans
/// `z_rich_text_core.dart` (interne), jamais ici.
library;

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';

/// Configuration granulaire (par bouton) de la toolbar rich-text.
///
/// Chaque drapeau active/désactive UN groupe de boutons de la barre, ou fixe un
/// trait de son habillage (icônes, fond, géométrie). Les présets
/// [inline]/[minimal]/[markdown]/[full] couvrent les cas courants — [inline]
/// est celui qu'un champ compact applique sans configuration ; [copyWith]
/// personnalise finement par champ.
@immutable
class ZRichTextToolbarConfig {
  /// Construit une config granulaire. Tous les groupes sont activés par DÉFAUT
  /// (équivaut au préset [full]) — SAUF [showStrikethrough] (cf. son
  /// doc) et les options d'HABILLAGE de barre ([roundedIcons],
  /// [themedBarBackground]) qui sont opt-in; passez `false` pour
  /// masquer un groupe. [multiRow] est TRI-ÉTAT : `null` (défaut) = AUTO par
  /// surface (cf. son doc).
  const ZRichTextToolbarConfig({
    this.showUndoRedo = true,
    this.showFontFamily = true,
    this.showFontSize = true,
    this.showBold = true,
    this.showItalic = true,
    this.showUnderline = true,
    this.showStrikethrough = false,
    this.showInlineCode = true,
    this.showColor = true,
    this.showBackgroundColor = true,
    this.showClearFormat = true,
    this.showHeaderStyle = true,
    this.showAlignment = true,
    this.showList = true,
    this.showIndent = true,
    this.showBlockQuote = true,
    this.showCodeBlock = true,
    this.showLink = true,
    this.showSearch = true,
    this.showSubscript = true,
    this.showSuperscript = true,
    this.showClipboardCopy = true,
    this.showClipboardPaste = true,
    this.showLatexButton = true,
    this.showTableButton = true,
    this.showImageButton = true,
    this.showVideoButton = true,
    this.roundedIcons = false,
    this.multiRow,
    this.themedBarBackground = false,
    this.showSectionDividers = true,
    this.iconSize,
    this.iconButtonFactor,
    this.iconColor,
    this.selectedIconColor,
    this.barHeight,
  });

  /// Boutons Annuler/Rétablir.
  final bool showUndoRedo;

  /// Sélecteur de police.
  final bool showFontFamily;

  /// Sélecteur de taille de police.
  final bool showFontSize;

  /// Bouton **gras**.
  final bool showBold;

  /// Bouton *italique*.
  final bool showItalic;

  /// Bouton souligné.
  final bool showUnderline;

  /// Bouton barré.
  ///
  /// Défaut `false` — ALIGNÉ sur l'éditeur historique, qui désactive le barré
  /// sur TOUS ses éditeurs. Un hôte qui VEUT le bouton opte :
  /// `copyWith(showStrikethrough: true)`.
  final bool showStrikethrough;

  /// Bouton code inline.
  final bool showInlineCode;

  /// Bouton couleur de texte.
  final bool showColor;

  /// Bouton couleur de fond (surlignage).
  final bool showBackgroundColor;

  /// Bouton effacer le format.
  final bool showClearFormat;

  /// Sélecteur de style de titre (H1..H6 / normal).
  final bool showHeaderStyle;

  /// Boutons d'alignement (gauche/centre/droite/justifié).
  final bool showAlignment;

  /// Boutons de liste (numérotée / à puces / cases à cocher).
  final bool showList;

  /// Boutons d'indentation (+/−).
  final bool showIndent;

  /// Bouton citation (blockquote).
  final bool showBlockQuote;

  /// Bouton bloc de code.
  final bool showCodeBlock;

  /// Bouton lien.
  final bool showLink;

  /// Bouton recherche.
  final bool showSearch;

  /// Bouton indice (subscript).
  final bool showSubscript;

  /// Bouton exposant (superscript).
  final bool showSuperscript;

  /// Bouton **Copier** (presse-papier).
  ///
  /// Défaut `true` : cohérent avec le contrat du préset [full] (« tous les
  /// groupes activés par défaut ») ET avec l'éditeur historique.
  final bool showClipboardCopy;

  /// Bouton **Coller** (presse-papier). Défaut `true` (cf.
  /// [showClipboardCopy] ; legacy `showClipboardPaste: true`).
  final bool showClipboardPaste;

  /// Bouton custom « Insérer une formule » (embed LaTeX).
  final bool showLatexButton;

  /// Bouton custom « Insérer un tableau » (embed table).
  final bool showTableButton;

  /// Bouton custom « Insérer une image » (embed image).
  final bool showImageButton;

  /// Bouton custom « Insérer une vidéo » (embed vidéo).
  final bool showVideoButton;

  /// (opt-in) : icônes **`*_rounded`** sur les boutons de la barre
  /// (jeu MESURÉ du legacy + boutons custom). Seule
  /// l'icône (`iconData`) est remplacée — les **tooltips restent ceux de
  /// Quill, déjà localisés** (aucun libellé posé ici,l10n). Défaut
  /// `false` ⇒ icônes Quill historiques inchangées (AD-4).
  final bool roundedIcons;

  /// Barre **multi-rangées** (`multiRowsDisplay` Quill) — TRI-ÉTAT.
  ///
  /// La MÊME config sert le champ en flux ET le dialog plein-écran : un booléen
  /// unique ne peut pas être juste pour les deux surfaces. Mesuré sur appareil :
  /// `true` en flux ⇒ la barre s'empile sur ~10 rangées et noie le formulaire ;
  /// `false` en plein écran ⇒ boutons rejetés hors écran alors que la place
  /// abonde.
  ///
  /// - `null` (DÉFAUT) ⇒ **AUTO** : la bonne valeur dérive de la SURFACE —
  ///   **une rangée défilante** pour toute barre rendue DANS LE FLUX d'un
  ///   formulaire (mode `inline` ET voie `controller`), **multi-rangées** dans
  ///   `ZRichTextFullscreenDialog`. Aucune configuration hôte requise.
  /// - `true`/`false` ⇒ **forçage hôte**, respecté SUR LES DEUX surfaces
  ///   (AD-4). Un hôte qui posait `false` pour contourner l'ancien défaut garde
  ///   exactement son comportement — mais il doit RETIRER ce forçage pour
  ///   profiter de l'AUTO.
  ///
  /// Mode `block` (tranché, MESURÉ) : son rendu en flux ne monte AUCUNE
  /// toolbar (aperçu lecteur + bouton) — sa seule barre vit dans le dialog
  /// plein-écran, donc multi-rangées via l'AUTO. Mesure de la géométrie en
  /// flux (test widget, 400 dp de large, préset [markdown] + undo/redo) :
  /// barre forcée multi-rangées = **262 dp (~5,5 rangées)**, AUTO = **67 dp
  /// (1 rangée)**. La règle : un champ inséré dans un formulaire ne consomme
  /// jamais la hauteur de l'écran — donc rangée unique pour TOUTE barre en
  /// flux, quel que soit inline/block.
  final bool? multiRow;

  /// **Fond de barre thémé** — surface + liseré bas dérivés des RÔLES du thème
  /// (`surfaceContainerLow` / `outlineVariant`) : zéro couleur en dur, c'est le
  /// thème de l'hôte qui parle.
  ///
  /// `false` ⇒ aucune décoration (barre transparente sur le fond ambiant).
  /// Le préset [inline] le pose à `true` — c'est ce que rend un champ
  /// `inlineMarkdown` sans configuration.
  final bool themedBarBackground;

  /// Séparateurs verticaux entre les GROUPES de boutons. Défaut `true`.
  final bool showSectionDividers;

  /// Taille de base du glyphe d'un bouton, en dp.
  ///
  /// Le glyphe rendu mesure `iconSize × iconButtonFactor` : les deux valeurs se
  /// composent, changer l'une sans l'autre change la taille finale. `null`
  /// (défaut) ⇒ valeur de la barre sous-jacente.
  final double? iconSize;

  /// Facteur multiplicateur du glyphe (cf. [iconSize]). `null` ⇒ valeur de la
  /// barre sous-jacente.
  final double? iconButtonFactor;

  /// Couleur des glyphes NON sélectionnés. `null` (défaut) ⇒ couleur héritée du
  /// thème ambiant. Une couleur posée ici vient de l'HÔTE : le paquet n'en code
  /// aucune.
  final Color? iconColor;

  /// Couleur des glyphes SÉLECTIONNÉS (bouton actif). `null` ⇒ couleur héritée
  /// du thème ambiant.
  final Color? selectedIconColor;

  /// Hauteur RENDUE de la rangée de boutons, en dp — la barre en une rangée
  /// occupe exactement cette hauteur.
  ///
  /// `null` (défaut) ⇒ hauteur dérivée de la cible de tap minimale. ⚠️ Chaque
  /// bouton porte la contrainte interactive minimale de la plateforme : une
  /// hauteur inférieure à cette contrainte ROGNE les boutons. Sans effet en
  /// mode multi-rangées, où la hauteur est celle du contenu.
  final double? barHeight;

  /// Préset **complet** : tous les boutons (défaut de la voie `controller`),
  /// SAUF le barré (cf. [showStrikethrough]) ; l'habillage reste opt-in.
  static const ZRichTextToolbarConfig full = ZRichTextToolbarConfig();

  /// Préset **minimal** (parité legacy `minimal`) : style inline de base + listes,
  /// SANS police/couleur/alignement/embeds — pour un champ compact. C'est le
  /// préset appliqué par défaut au mode `inline`.
  static const ZRichTextToolbarConfig minimal = ZRichTextToolbarConfig(
    showUndoRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showUnderline: true,
    showStrikethrough: false,
    showInlineCode: false,
    showColor: false,
    showBackgroundColor: false,
    showClearFormat: false,
    showHeaderStyle: false,
    showAlignment: false,
    showList: true,
    showIndent: false,
    showBlockQuote: false,
    showCodeBlock: false,
    showLink: false,
    showSearch: false,
    showSubscript: false,
    showSuperscript: false,
    showClipboardCopy: false,
    showClipboardPaste: false,
    showLatexButton: false,
    showTableButton: false,
    showImageButton: false,
    showVideoButton: false,
  );

  /// Préset **inline** — celui qu'applique un champ rich-text compact rendu
  /// DANS LE FLUX d'un formulaire quand aucune configuration n'est fournie.
  ///
  /// C'est une **donnée**, jamais un comportement : il n'active et ne masque
  /// que des boutons, et fixe l'habillage (icônes arrondies, fond de barre
  /// thémé, géométrie). L'ordre de rendu et le groupement ne s'écrivent pas
  /// ici — ils appartiennent à la barre, qui range les boutons par groupe
  /// (style de caractère · paragraphe · listes · retraits · presse-papier ·
  /// insertions) et les sépare de traits verticaux.
  ///
  /// Boutons RENDUS, dans l'ordre : annuler · rétablir · gras · italique ·
  /// souligné · code inline ┃ style de titre ┃ liste numérotée · liste à puces ·
  /// cases à cocher ┃ retrait + · retrait − ┃ copier · coller ┃ formule ·
  /// tableau.
  ///
  /// Boutons volontairement ABSENTS : barré, couleur de texte, couleur de
  /// fond, effacer le format, alignements, citation, bloc de code, lien,
  /// recherche, indice, exposant, police, taille de police, image, vidéo. Un
  /// hôte qui en veut un l'ajoute par [copyWith].
  static const ZRichTextToolbarConfig inline = ZRichTextToolbarConfig(
    showUndoRedo: true,
    showFontFamily: false,
    showFontSize: false,
    showUnderline: true,
    showStrikethrough: false,
    showInlineCode: true,
    showColor: false,
    showBackgroundColor: false,
    showClearFormat: false,
    showHeaderStyle: true,
    showAlignment: false,
    showList: true,
    showIndent: true,
    showBlockQuote: false,
    showCodeBlock: false,
    showLink: false,
    showSearch: false,
    showSubscript: false,
    showSuperscript: false,
    showClipboardCopy: true,
    showClipboardPaste: true,
    showLatexButton: true,
    showTableButton: true,
    showImageButton: false,
    showVideoButton: false,
    roundedIcons: true,
    themedBarBackground: true,
    // Composent le MÊME glyphe que les valeurs par défaut de la barre
    // sous-jacente (20 × 1,2 = 15 × 1,6 = 24 dp, mesuré) : le préset rend la
    // géométrie EXPLICITE sans rien déplacer à l'écran.
    iconSize: 20,
    iconButtonFactor: 1.2,
  );

  /// Préset **markdown** (parité legacy `markdown`) : style + listes + insertions
  /// (embeds), SANS police/couleur/alignement — pensé pour un rendu Markdown.
  static const ZRichTextToolbarConfig markdown = ZRichTextToolbarConfig(
    showUndoRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showUnderline: true,
    // barré retiré du préset (parité legacy `qmew:85` — le legacy le
    // désactive sur l'éditeur markdown lui-même, quel que soit le preset).
    showStrikethrough: false,
    showInlineCode: true,
    showColor: false,
    showBackgroundColor: false,
    showClearFormat: false,
    showHeaderStyle: true,
    showAlignment: false,
    showList: true,
    showIndent: false,
    showBlockQuote: true,
    showCodeBlock: true,
    showLink: true,
    showSearch: false,
    showSubscript: false,
    showSuperscript: false,
    showClipboardCopy: true,
    showClipboardPaste: true,
    showLatexButton: true,
    showTableButton: true,
    showImageButton: true,
    showVideoButton: true,
  );

  /// Retourne une copie avec les drapeaux fournis remplacés (personnalisation
  /// par field à partir d'un préset).
  ///
  /// [multiRow] est TRI-ÉTAT : **omis** ⇒ valeur conservée ; `true`/`false` ⇒
  /// forçage ; **`null` explicite** ⇒ retour à l'AUTO. La distinction
  /// « omis »/« null » passe par une sentinelle (même patron que `_$undefined`
  /// du `copyWith` généré de zcrud_generator) — un `??` naïf les confondrait.
  ZRichTextToolbarConfig copyWith({
    bool? showUndoRedo,
    bool? showFontFamily,
    bool? showFontSize,
    bool? showBold,
    bool? showItalic,
    bool? showUnderline,
    bool? showStrikethrough,
    bool? showInlineCode,
    bool? showColor,
    bool? showBackgroundColor,
    bool? showClearFormat,
    bool? showHeaderStyle,
    bool? showAlignment,
    bool? showList,
    bool? showIndent,
    bool? showBlockQuote,
    bool? showCodeBlock,
    bool? showLink,
    bool? showSearch,
    bool? showSubscript,
    bool? showSuperscript,
    bool? showClipboardCopy,
    bool? showClipboardPaste,
    bool? showLatexButton,
    bool? showTableButton,
    bool? showImageButton,
    bool? showVideoButton,
    bool? roundedIcons,
    Object? multiRow = _zMultiRowUnset,
    bool? themedBarBackground,
    bool? showSectionDividers,
    double? iconSize,
    double? iconButtonFactor,
    Color? iconColor,
    Color? selectedIconColor,
    double? barHeight,
  }) {
    return ZRichTextToolbarConfig(
      showUndoRedo: showUndoRedo ?? this.showUndoRedo,
      showFontFamily: showFontFamily ?? this.showFontFamily,
      showFontSize: showFontSize ?? this.showFontSize,
      showBold: showBold ?? this.showBold,
      showItalic: showItalic ?? this.showItalic,
      showUnderline: showUnderline ?? this.showUnderline,
      showStrikethrough: showStrikethrough ?? this.showStrikethrough,
      showInlineCode: showInlineCode ?? this.showInlineCode,
      showColor: showColor ?? this.showColor,
      showBackgroundColor: showBackgroundColor ?? this.showBackgroundColor,
      showClearFormat: showClearFormat ?? this.showClearFormat,
      showHeaderStyle: showHeaderStyle ?? this.showHeaderStyle,
      showAlignment: showAlignment ?? this.showAlignment,
      showList: showList ?? this.showList,
      showIndent: showIndent ?? this.showIndent,
      showBlockQuote: showBlockQuote ?? this.showBlockQuote,
      showCodeBlock: showCodeBlock ?? this.showCodeBlock,
      showLink: showLink ?? this.showLink,
      showSearch: showSearch ?? this.showSearch,
      showSubscript: showSubscript ?? this.showSubscript,
      showSuperscript: showSuperscript ?? this.showSuperscript,
      showClipboardCopy: showClipboardCopy ?? this.showClipboardCopy,
      showClipboardPaste: showClipboardPaste ?? this.showClipboardPaste,
      showLatexButton: showLatexButton ?? this.showLatexButton,
      showTableButton: showTableButton ?? this.showTableButton,
      showImageButton: showImageButton ?? this.showImageButton,
      showVideoButton: showVideoButton ?? this.showVideoButton,
      roundedIcons: roundedIcons ?? this.roundedIcons,
      multiRow: identical(multiRow, _zMultiRowUnset)
          ? this.multiRow
          : multiRow as bool?,
      themedBarBackground: themedBarBackground ?? this.themedBarBackground,
      showSectionDividers: showSectionDividers ?? this.showSectionDividers,
      iconSize: iconSize ?? this.iconSize,
      iconButtonFactor: iconButtonFactor ?? this.iconButtonFactor,
      iconColor: iconColor ?? this.iconColor,
      selectedIconColor: selectedIconColor ?? this.selectedIconColor,
      barHeight: barHeight ?? this.barHeight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRichTextToolbarConfig &&
          runtimeType == other.runtimeType &&
          showUndoRedo == other.showUndoRedo &&
          showFontFamily == other.showFontFamily &&
          showFontSize == other.showFontSize &&
          showBold == other.showBold &&
          showItalic == other.showItalic &&
          showUnderline == other.showUnderline &&
          showStrikethrough == other.showStrikethrough &&
          showInlineCode == other.showInlineCode &&
          showColor == other.showColor &&
          showBackgroundColor == other.showBackgroundColor &&
          showClearFormat == other.showClearFormat &&
          showHeaderStyle == other.showHeaderStyle &&
          showAlignment == other.showAlignment &&
          showList == other.showList &&
          showIndent == other.showIndent &&
          showBlockQuote == other.showBlockQuote &&
          showCodeBlock == other.showCodeBlock &&
          showLink == other.showLink &&
          showSearch == other.showSearch &&
          showSubscript == other.showSubscript &&
          showSuperscript == other.showSuperscript &&
          showClipboardCopy == other.showClipboardCopy &&
          showClipboardPaste == other.showClipboardPaste &&
          showLatexButton == other.showLatexButton &&
          showTableButton == other.showTableButton &&
          showImageButton == other.showImageButton &&
          showVideoButton == other.showVideoButton &&
          roundedIcons == other.roundedIcons &&
          multiRow == other.multiRow &&
          themedBarBackground == other.themedBarBackground &&
          showSectionDividers == other.showSectionDividers &&
          iconSize == other.iconSize &&
          iconButtonFactor == other.iconButtonFactor &&
          iconColor == other.iconColor &&
          selectedIconColor == other.selectedIconColor &&
          barHeight == other.barHeight;

  @override
  int get hashCode => Object.hashAll(<Object?>[
        showUndoRedo,
        showFontFamily,
        showFontSize,
        showBold,
        showItalic,
        showUnderline,
        showStrikethrough,
        showInlineCode,
        showColor,
        showBackgroundColor,
        showClearFormat,
        showHeaderStyle,
        showAlignment,
        showList,
        showIndent,
        showBlockQuote,
        showCodeBlock,
        showLink,
        showSearch,
        showSubscript,
        showSuperscript,
        showClipboardCopy,
        showClipboardPaste,
        showLatexButton,
        showTableButton,
        showImageButton,
        showVideoButton,
        roundedIcons,
        multiRow,
        themedBarBackground,
        showSectionDividers,
        iconSize,
        iconButtonFactor,
        iconColor,
        selectedIconColor,
        barHeight,
      ]);
}

/// Sentinelle « argument non fourni » du tri-état [ZRichTextToolbarConfig.multiRow]
/// dans [ZRichTextToolbarConfig.copyWith] (piège classique du copyWith : sans
/// elle, `copyWith(multiRow: null)` — retour AUTO demandé — serait indistinct
/// de « multiRow non fourni » — valeur à conserver).
const Object _zMultiRowUnset = _ZMultiRowUnset();

class _ZMultiRowUnset {
  const _ZMultiRowUnset();
}
