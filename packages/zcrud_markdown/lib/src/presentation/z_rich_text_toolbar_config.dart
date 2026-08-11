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
/// RÉTRO-COMPAT (NON-NÉGOCIABLE) : `toolbarConfig` est OPTIONNEL. Un
/// `ZMarkdownField` sans `toolbarConfig` conserve EXACTEMENT le comportement
/// (drapeau `showToolbar` honoré, toolbar pleine en voie `controller`,
/// toolbar compacte en mode `inline`).
///
/// ISOLATION : classe de DONNÉES pure (booléens `const`) — sûre à exporter par le
/// barrel. Sa traduction en `QuillSimpleToolbarConfig` vit dans
/// `z_rich_text_core.dart` (interne), jamais ici.
library;

import 'package:flutter/foundation.dart';

/// Configuration granulaire (par bouton) de la toolbar rich-text.
///
/// Chaque drapeau active/désactive UN groupe de boutons de la barre. Les présets
/// [full]/[minimal]/[markdown] couvrent les cas parité legacy ; [copyWith] permet
/// une personnalisation fine par field.
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
  /// (CR parité 2026-08-11) : défaut `false` — ALIGNÉ sur le legacy
  /// l'éditeur historique, qui désactive le barré sur TOUS ses éditeurs
  /// (`showStrikeThrough: false`, `qmew:85`, hors de portée des presets
  /// legacy). MESURÉ avant le changement : AUCUN hôte (l'éditeur historique / lex_douane /
  /// un consommateur legacy / un autre consommateur legacy) ne référence `ZRichTextToolbarConfig` ni ne passe
  /// `toolbarConfig` — le seul consommateur du défaut est le pilote historique via
  /// le registre, qui demande précisément ce retrait. Un hôte qui VEUT le
  /// bouton opte : `copyWith(showStrikethrough: true)`.
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

  /// Bouton **Copier** (presse-papier), CR parité 2026-08-11.
  ///
  /// Défaut `true` : cohérent avec le contrat du préset [full] (« tous les
  /// groupes activés par défaut ») ET avec le legacy
  /// (`showClipboardCopy: true`, `qmew:227`).
  final bool showClipboardCopy;

  /// Bouton **Coller** (presse-papier). Défaut `true` (cf.
  /// [showClipboardCopy] ; legacy `showClipboardPaste: true`, `qmew:228`).
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
  /// (jeu MESURÉ du legacy, `qmew:118-208` + boutons custom). Seule
  /// l'icône (`iconData`) est remplacée — les **tooltips restent ceux de
  /// Quill, déjà localisés** (aucun libellé posé ici,l10n). Défaut
  /// `false` ⇒ icônes Quill historiques inchangées (AD-4).
  final bool roundedIcons;

  /// Barre **multi-rangées** (`multiRowsDisplay` Quill, parité `qmew:229`) —
  /// TRI-ÉTAT (CR toolbar multi-rangées par surface, 2026-08-11).
  ///
  /// La MÊME config sert le champ en flux ET le dialog plein-écran : un booléen
  /// unique ne peut pas être juste pour les deux surfaces. Constat device
  /// (pilote historique) : `true` en flux ⇒ la barre s'empile sur ~10 rangées et
  /// noie le formulaire ; `false` en plein écran ⇒ boutons rejetés hors écran
  /// alors que la place abonde.
  ///
  /// - `null` (DÉFAUT) ⇒ **AUTO** : la bonne valeur dérive de la SURFACE —
  ///   **une rangée défilante** pour toute barre rendue DANS LE FLUX d'un
  ///   formulaire (mode `inline` ET voie `controller`), **multi-rangées** dans
  ///   `ZRichTextFullscreenDialog`. Aucune configuration hôte requise.
  /// - `true`/`false` ⇒ **forçage hôte**, respecté SUR LES DEUX surfaces
  ///   (AD-4). Un hôte qui posait `false` (contournement v0.82/v0.83) garde
  ///   exactement son comportement — mais il doit RETIRER ce forçage pour
  ///   profiter de l'AUTO.
  ///
  /// Mode `block` (tranché, MESURÉ) : son rendu en flux ne monte AUCUNE
  /// toolbar (aperçu lecteur + bouton) — sa seule barre vit dans le dialog
  /// plein-écran, donc multi-rangées via l'AUTO. Mesure de la géométrie en
  /// flux (test widget, 400 dp de large, préset [markdown] + undo/redo) :
  /// barre forcée multi-rangées = **262 dp (~5,5 rangées)**, AUTO = **67 dp
  /// (1 rangée)** — le critère CR « un champ inséré dans un formulaire ne doit
  /// jamais consommer la hauteur de l'écran » impose la rangée unique pour
  /// TOUTE barre en flux, quel que soit inline/block.
  final bool? multiRow;

  /// Opt-in : **fond de barre thémé** — surface + liseré bas dérivés
  /// des RÔLES du thème (`surfaceContainerLow`/`outlineVariant`) :
  /// zéro couleur en dur ; le legacy posait des gris figés, non repris.
  /// Défaut `false` ⇒ aucune décoration (rendu historique).
  final bool themedBarBackground;

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
          themedBarBackground == other.themedBarBackground;

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
