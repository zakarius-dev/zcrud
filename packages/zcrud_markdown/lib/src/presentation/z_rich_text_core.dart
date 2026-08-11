/// Noyau **interne partagé** du rich-text Quill (DP-3) : embeds LaTeX/tableau,
/// config de toolbar STABLE et insertion/édition d'embed — FACTORISÉ depuis
/// `ZMarkdownField` (E6-1..E6-4) pour être RÉUTILISÉ **sans dupliquer le chemin
/// chaud** par les trois voies rich-text :
///   1. l'éditeur pleine-toolbar de la voie publique `ZMarkdownField({controller})`,
///   2. l'éditeur compact de la voie `ctx`/registre (mode `inline`),
///   3. l'éditeur plein-écran `ZRichTextFullscreenDialog`.
///
/// ISOLATION (AD-1/AD-7) : ce fichier vit sous `lib/src/` de `zcrud_markdown` et
/// peut donc consommer `flutter_quill`. AUCUN de ses symboles n'est re-exporté
/// par le barrel : la surface publique reste NEUTRE (aucun type Quill/math). Le
/// comportement d'insertion/édition d'embed est le MIROIR EXACT d'E6-3/E6-4 —
/// seule la localisation du code change (méthodes d'instance → fonctions
/// top-level paramétrées par le [QuillController]), pas la sémantique.
library;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../data/delta_neutral_ops.dart';
// GAP-2 : conversion de la charge tableau LEGACY (string Markdown) pour le
// pré-remplissage d'édition — parseur legacy-fidèle de la couture data.
import '../data/z_table_markdown.dart';
// SOURCE UNIQUE du type d'embed tableau (SM-S4 / ES-6.2) : re-câblage D3 sur la
// couture NEUTRE, `z_table_embed.dart` ne re-déclare plus `kTableEmbedType`.
import '../data/z_table_ops.dart';
import 'z_divider_embed.dart';
import 'z_latex_embed.dart';
import 'z_media_embed.dart';
import 'z_rich_text_style_set.dart';
import 'z_rich_text_toolbar_config.dart';
import 'z_table_embed.dart';

// Le repli d'embed inconnu (AD-10) est consommé par les TROIS voies rich-text
// qui importent déjà ce noyau. Re-exporté ici — et NULLE PART ailleurs : le
// barrel public n'exporte pas ce fichier, la surface publique reste NEUTRE.
export 'z_divider_embed.dart' show kZUnknownEmbedBuilder;

/// Cible de tap minimale (AD-13) — dimensionne les boutons de la toolbar et sa
/// hauteur minimale. PARTAGÉE par toutes les voies rich-text.
const double kZMinTapTarget = 48;

/// `EmbedBuilder`s branchés sur `QuillEditorConfig.embedBuilders` (E6-3/E6-4).
///
/// Liste `const` (donc CANONICALISÉE → instance UNIQUE partagée par tous les
/// builds ET par toutes les voies rich-text) : la référence est STABLE, aucune
/// allocation à chaque (re)build de tranche (SM-1/AD-2). MÊME liste pour LaTeX
/// (E6-3) ET tableau (E6-4), en édition ET en lecture. Définie HORS de la
/// surface publique scannée par les tests d'isolation de signature.
/// 🔴 **CR-IFFD-73 — `ZDividerEmbedBuilder` comblait un TROU, pas un manque de
/// confort.** `ZMarkdownCodec` compte `divider` parmi ses types d'embed
/// NATIFS : un `---` de Markdown produisait donc une op que **rien** ne savait
/// rendre, et le lecteur comme l'éditeur levaient un `UnimplementedError` suivi
/// de quatre `RenderErrorBox` en cascade. Mesuré, écran rouge. Le trou a
/// survécu parce que les gardes éprouvaient le CODEC (qui produisait l'op
/// correctement) et jamais le RENDU de l'op produite.
const List<EmbedBuilder> kZEmbedBuilders = <EmbedBuilder>[
  ZLatexEmbedBuilder(),
  ZLatexBlockEmbedBuilder(),
  ZTableEmbedBuilder(),
  ZMediaEmbedBuilder(ZMediaKind.image),
  ZMediaEmbedBuilder(ZMediaKind.video),
  ZDividerEmbedBuilder(),
  // GAP-1/GAP-2 (CR parité 2026-08-11) : LECTURE des embeds LEGACY DODLP —
  // `formula`/`formula_inline` (string LaTeX nu) et `x-embed-table` (string
  // Markdown). Sans eux, tout contenu DODLP existant tombait sur le repli
  // d'embed inconnu (invisible). L'ÉCRITURE reste sur nos clés
  // `latex`/`latexBlock`/`table` — migration à sens unique.
  ZLegacyFormulaEmbedBuilder(),
  ZLegacyFormulaInlineEmbedBuilder(),
  ZLegacyTableEmbedBuilder(),
];

/// Construit des [DefaultStyles] Quill dérivés du **thème** ambiant (MIN-1,
/// FR-26) : titres H1..H6 alignés sur les rôles typographiques du [TextTheme]
/// (couleurs/tailles/graisses du thème), SANS couleur codée en dur.
///
/// Part de `DefaultStyles.getInstance(context)` (déjà thémé par Quill) et
/// SURCHARGE les seuls styles de titre en fusionnant le rôle `TextTheme`
/// correspondant (H1→headlineLarge … H6→titleSmall). Les rôles absents laissent
/// le style Quill intact (dégradation sûre). Résultat NEUTRE côté API : ce type
/// Quill (`DefaultStyles`) ne fuit JAMAIS dans le barrel — il n'est consommé que
/// par les `QuillEditorConfig` internes (éditeur / lecteur / plein-écran).
///
/// AD-13 (documenté) : la parité DODLP (`QuillDefaultStylesHelper` + google_fonts
/// + palette de couleurs figée) n'est PAS reproduite — pas de dépendance
/// `google_fonts`, pas de couleur en dur. Seule la dérivation thème est portée.
/// [baseStyle] (optionnel, DP-RT) : style **attendu par l'appelant** pour le
/// CORPS de texte (contrat `ZRichTextRenderer.build`). Quand il est fourni, il
/// devient la base des blocs de corps — paragraphe, listes, citation — par
/// FUSION sur le style Quill ambiant. 🔴 Il ne peut PAS être obtenu en
/// enveloppant l'éditeur d'un `DefaultTextStyle` : mesuré,
/// `DefaultStyles.getInstance` repart bien de `DefaultTextStyle.of(context)`
/// mais **écrase `fontSize` à 16** — un `bodySmall` passé par l'ambiant perdrait
/// donc sa taille en silence. Les **rôles matérialisés** (titres H1..H6, code
/// inline) en dévient délibérément et restent dérivés du thème (FR-26).
/// `null` ⇒ comportement historique strictement inchangé.
///
/// [styleSet] (optionnel, GAP-5 — CR parité 2026-08-11) : jeu de styles NEUTRE
/// injecté PAR CHAMP par l'hôte ([ZRichTextStyleSet]) — la voie « signature
/// DODLP » SANS faire entrer les valeurs legacy dans le paquet (polices Google
/// et palette restent chez l'hôte, cf. `z_rich_text_style_set.dart`). Appliqué
/// EN DERNIER (par-dessus thème + [baseStyle]) : chaque slot fusionne sur le
/// style courant, les slots absents ne changent RIEN. `null` ⇒ inchangé
/// (AD-57) — le choix AD-13 (défauts dérivés du seul thème) reste le défaut.
DefaultStyles zQuillThemedStyles(
  BuildContext context, {
  TextStyle? baseStyle,
  ZRichTextStyleSet? styleSet,
}) {
  final DefaultStyles themed =
      _zQuillThemedBase(context, baseStyle: baseStyle);
  if (styleSet == null) return themed;
  return _applyZStyleSet(themed, styleSet);
}

/// Dérivation thème + [baseStyle] HISTORIQUE (MIN-1/DP-RT) — inchangée.
DefaultStyles _zQuillThemedBase(BuildContext context, {TextStyle? baseStyle}) {
  final DefaultStyles base = DefaultStyles.getInstance(context);
  final TextTheme tt = Theme.of(context).textTheme;
  DefaultTextBlockStyle? merge(DefaultTextBlockStyle? proto, TextStyle? role) {
    if (proto == null || role == null) return proto;
    return proto.copyWith(style: proto.style.merge(role));
  }

  final DefaultStyles themed = base.merge(
    DefaultStyles(
      h1: merge(base.h1, tt.headlineLarge),
      h2: merge(base.h2, tt.headlineMedium),
      h3: merge(base.h3, tt.headlineSmall),
      h4: merge(base.h4, tt.titleLarge),
      h5: merge(base.h5, tt.titleMedium),
      h6: merge(base.h6, tt.titleSmall),
    ),
  );
  if (baseStyle == null) return themed;
  final DefaultListBlockStyle? protoLists = themed.lists;
  DefaultListBlockStyle? mergedLists;
  if (protoLists != null) {
    mergedLists = protoLists.copyWith(style: protoLists.style.merge(baseStyle));
  }
  return themed.merge(
    DefaultStyles(
      paragraph: merge(themed.paragraph, baseStyle),
      lists: mergedLists,
      quote: merge(themed.quote, baseStyle),
      // 🔴 `leading` porte la PUCE et le NUMÉRO de liste. Mesuré : sans lui,
      // un `bodySmall` rendait le texte à 11 et la puce restait au plancher
      // Quill (16) — une liste dont les marqueurs sont plus gros que ses
      // items. Le marqueur appartient au corps, pas aux rôles matérialisés.
      leading: merge(themed.leading, baseStyle),
    ),
  );
}

/// Traduction INTERNE (AD-7 : le type Quill [DefaultStyles] ne fuit jamais) du
/// jeu de styles NEUTRE [ZRichTextStyleSet] par-dessus les styles courants.
///
/// Sémantique par slot : hauteur de ligne appliquée d'abord (`copyWith(height:)`),
/// puis FUSION du [TextStyle] du slot (un slot portant `height` l'emporte) ;
/// espacement/décoration remplacés seulement si fournis ([ZRichTextSpacing] →
/// `VerticalSpacing` Quill). Les protos absents chez Quill restent absents
/// (dégradation sûre, AD-10 : on n'invente pas un bloc).
DefaultStyles _applyZStyleSet(DefaultStyles base, ZRichTextStyleSet s) {
  TextStyle? inline(TextStyle? proto, TextStyle? slot) =>
      slot == null ? null : (proto?.merge(slot) ?? slot);

  DefaultTextBlockStyle? block(
    DefaultTextBlockStyle? proto, {
    TextStyle? slot,
    double? height,
    ZRichTextSpacing? spacing,
    BoxDecoration? decoration,
  }) {
    if (proto == null) return null;
    if (slot == null && height == null && spacing == null && decoration == null) {
      // Rien à changer sur ce slot : `null` ⇒ `merge` conserve le proto.
      return null;
    }
    TextStyle style = proto.style;
    if (height != null) style = style.copyWith(height: height);
    if (slot != null) style = style.merge(slot);
    return proto.copyWith(
      style: style,
      verticalSpacing:
          spacing != null ? VerticalSpacing(spacing.top, spacing.bottom) : null,
      decoration: decoration,
    );
  }

  // Code inline : style + fond + rayon (structure `InlineCodeStyle` dédiée).
  InlineCodeStyle? inlineCode;
  if (s.inlineCode != null ||
      s.inlineCodeBackgroundColor != null ||
      s.inlineCodeRadius != null) {
    final InlineCodeStyle? proto = base.inlineCode;
    inlineCode = InlineCodeStyle(
      style: (proto?.style ?? const TextStyle()).merge(s.inlineCode),
      header1: proto?.header1,
      header2: proto?.header2,
      header3: proto?.header3,
      header4: proto?.header4,
      header5: proto?.header5,
      header6: proto?.header6,
      backgroundColor: s.inlineCodeBackgroundColor ?? proto?.backgroundColor,
      radius: s.inlineCodeRadius ?? proto?.radius,
    );
  }

  // Listes : sous-type `DefaultListBlockStyle` (copyWith dédié conserve la
  // mécanique checkbox/indent de Quill).
  DefaultListBlockStyle? lists;
  final DefaultListBlockStyle? listsProto = base.lists;
  if (listsProto != null &&
      (s.lists != null || s.lineHeight != null || s.listSpacing != null)) {
    TextStyle listStyle = listsProto.style;
    final double? lh = s.lineHeight;
    if (lh != null) listStyle = listStyle.copyWith(height: lh);
    final TextStyle? listSlot = s.lists;
    if (listSlot != null) listStyle = listStyle.merge(listSlot);
    final ZRichTextSpacing? lsp = s.listSpacing;
    lists = listsProto.copyWith(
      style: listStyle,
      verticalSpacing: lsp != null ? VerticalSpacing(lsp.top, lsp.bottom) : null,
    );
  }

  return base.merge(
    DefaultStyles(
      paragraph: block(
        base.paragraph,
        slot: s.paragraph,
        height: s.lineHeight,
        spacing: s.paragraphSpacing,
      ),
      h1: block(base.h1,
          slot: s.h1, height: s.headingLineHeight, spacing: s.headingSpacing),
      h2: block(base.h2,
          slot: s.h2, height: s.headingLineHeight, spacing: s.headingSpacing),
      h3: block(base.h3,
          slot: s.h3, height: s.headingLineHeight, spacing: s.headingSpacing),
      h4: block(base.h4,
          slot: s.h4, height: s.headingLineHeight, spacing: s.headingSpacing),
      h5: block(base.h5,
          slot: s.h5, height: s.headingLineHeight, spacing: s.headingSpacing),
      h6: block(base.h6,
          slot: s.h6, height: s.headingLineHeight, spacing: s.headingSpacing),
      bold: inline(base.bold, s.bold),
      italic: inline(base.italic, s.italic),
      underline: inline(base.underline, s.underline),
      strikeThrough: inline(base.strikeThrough, s.strikeThrough),
      subscript: inline(base.subscript, s.subscript),
      superscript: inline(base.superscript, s.superscript),
      inlineCode: inlineCode,
      code: block(
        base.code,
        slot: s.codeBlock,
        height: s.lineHeight,
        spacing: s.codeBlockSpacing,
        decoration: s.codeBlockDecoration,
      ),
      quote: block(
        base.quote,
        slot: s.quote,
        height: s.lineHeight,
        spacing: s.quoteSpacing,
        decoration: s.quoteDecoration,
      ),
      lists: lists,
      link: inline(base.link, s.link),
      sizeSmall: inline(base.sizeSmall, s.sizeSmall),
      sizeLarge: inline(base.sizeLarge, s.sizeLarge),
      sizeHuge: inline(base.sizeHuge, s.sizeHuge),
      placeHolder: block(base.placeHolder, slot: s.placeholder),
    ),
  );
}

/// Enveloppe PARTAGÉE du contenu rich-text (GAP-7, CR parité 2026-08-11) —
/// consommée par l'éditeur, le lecteur ET le dialog plein-écran :
///
/// * [textScaleFactor] ⇒ `MediaQuery` LOCAL portant un [TextScaler.linear] —
///   MESURÉ : Quill peint via `MediaQuery.textScalerOf(context)`
///   (`text_line.dart:182`), l'échelle s'applique donc à TOUT le contenu sans
///   toucher les styles (et sans dériver du chemin chaud) ;
/// * [formulaSpec] ⇒ [ZFormulaSpecScope] lu par les builders de formule
///   (`const` partagés — la personnalisation PAR CHAMP passe par le contexte).
///
/// Les deux `null` ⇒ [child] retourné TEL QUEL (aucun wrapper, rendu
/// historique inchangé — AD-57).
Widget zWrapRichTextContent(
  BuildContext context,
  Widget child, {
  double? textScaleFactor,
  ZRichTextFormulaSpec? formulaSpec,
}) {
  Widget wrapped = child;
  if (formulaSpec != null) {
    wrapped = ZFormulaSpecScope(spec: formulaSpec, child: wrapped);
  }
  if (textScaleFactor != null) {
    // Facteur ABSOLU par champ (parité legacy, qui multipliait les tailles en
    // ignorant l'échelle ambiante) : un hôte qui veut composer avec l'échelle
    // d'accessibilité ambiante multiplie lui-même avant d'appeler.
    wrapped = MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScaleFactor)),
      child: wrapped,
    );
  }
  return wrapped;
}

/// Construit une [QuillSimpleToolbarConfig] STABLE (SM-1/AD-2) branchée sur les
/// callbacks d'insertion d'embed, PILOTÉE par une [ZRichTextToolbarConfig]
/// granulaire (DP-22, M20) — chaque bouton (natif Quill ET custom
/// LaTeX/table/image/vidéo) est activé/masqué au drapeau.
///
/// [config] traduit la granularité NEUTRE (aucun type Quill ne fuit à l'appelant)
/// vers les `showXxx` de Quill + la liste `customButtons`. La config DOIT être
/// construite UNE FOIS par l'appelant (en `initState`) et HISSÉE en champ —
/// jamais ré-allouée dans le chemin chaud de frappe.
QuillSimpleToolbarConfig buildZToolbarConfig({
  required VoidCallback onInsertLatex,
  required VoidCallback onInsertTable,
  VoidCallback? onInsertImage,
  VoidCallback? onInsertVideo,
  ZRichTextToolbarConfig config = ZRichTextToolbarConfig.full,
}) =>
    QuillSimpleToolbarConfig(
      toolbarSize: kZMinTapTarget,
      // GAP-9 : multi-rangées OPT-IN (parité legacy `qmew:229`) ; défaut
      // `false` = mono-rangée historique.
      multiRowsDisplay: config.multiRow,
      // GAP-9 : icônes rounded OPT-IN — SEUL `iconData` est posé, jamais de
      // `tooltip` : les tooltips restent ceux de Quill, DÉJÀ localisés.
      buttonOptions: config.roundedIcons
          ? _kZRoundedButtonOptions
          : const QuillSimpleToolbarButtonOptions(),
      showUndo: config.showUndoRedo,
      showRedo: config.showUndoRedo,
      showFontFamily: config.showFontFamily,
      showFontSize: config.showFontSize,
      showBoldButton: config.showBold,
      showItalicButton: config.showItalic,
      showUnderLineButton: config.showUnderline,
      showStrikeThrough: config.showStrikethrough,
      showInlineCode: config.showInlineCode,
      showColorButton: config.showColor,
      showBackgroundColorButton: config.showBackgroundColor,
      showClearFormat: config.showClearFormat,
      showHeaderStyle: config.showHeaderStyle,
      showAlignmentButtons: config.showAlignment,
      showListNumbers: config.showList,
      showListBullets: config.showList,
      showListCheck: config.showList,
      showIndent: config.showIndent,
      showQuote: config.showBlockQuote,
      showCodeBlock: config.showCodeBlock,
      showLink: config.showLink,
      showSearchButton: config.showSearch,
      showSubscript: config.showSubscript,
      showSuperscript: config.showSuperscript,
      // GAP-4 (CR parité 2026-08-11) : boutons presse-papier NATIFS de Quill
      // (désactivés par défaut côté Quill — le drapeau zcrud les pilote).
      // `@experimental` chez Quill 11.x, MESURÉ fonctionnels ; le legacy DODLP
      // s'appuie sur ces mêmes drapeaux (`qmew:227-228`). L'ignore est LOCAL :
      // si Quill retire l'API, la compile rougit ici et nulle part ailleurs.
      // ignore: experimental_member_use
      showClipboardCopy: config.showClipboardCopy,
      // ignore: experimental_member_use
      showClipboardPaste: config.showClipboardPaste,
      customButtons: <QuillToolbarCustomButtonOptions>[
        if (config.showLatexButton)
          QuillToolbarCustomButtonOptions(
            // GAP-9 : variante rounded opt-in (parité legacy `qmew:244`).
            icon: Icon(
                config.roundedIcons ? Icons.functions_rounded : Icons.functions),
            tooltip: 'Insérer une formule',
            onPressed: onInsertLatex,
          ),
        if (config.showTableButton)
          QuillToolbarCustomButtonOptions(
            // GAP-10 (CR parité 2026-08-11) : icône alignée sur le legacy
            // (`table_chart_rounded`, `qmew:249`) — remplace `grid_on`.
            icon: const Icon(Icons.table_chart_rounded),
            tooltip: 'Insérer un tableau',
            onPressed: onInsertTable,
          ),
        if (config.showImageButton && onInsertImage != null)
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.image_outlined),
            tooltip: 'Insérer une image',
            onPressed: onInsertImage,
          ),
        if (config.showVideoButton && onInsertVideo != null)
          QuillToolbarCustomButtonOptions(
            icon: const Icon(Icons.videocam_outlined),
            tooltip: 'Insérer une vidéo',
            onPressed: onInsertVideo,
          ),
      ],
    );

/// GAP-9 — jeu d'icônes **`*_rounded`** (opt-in [ZRichTextToolbarConfig.roundedIcons]).
///
/// Jeu MESURÉ sur le legacy DODLP (`qmew:118-208`) : seuls les boutons que le
/// legacy re-skinnait sont couverts — on n'INVENTE pas d'icône pour les autres
/// (search, couleur, police… gardent l'icône Quill). 🔴 AUCUN `tooltip` posé :
/// Quill fournit les siens, déjà localisés (FR-26/l10n) — poser un libellé ici
/// serait un libellé en dur.
const QuillSimpleToolbarButtonOptions _kZRoundedButtonOptions =
    QuillSimpleToolbarButtonOptions(
  bold: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_bold_rounded),
  italic: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_italic_rounded),
  underLine: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_underlined_rounded),
  strikeThrough: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_strikethrough_rounded),
  inlineCode:
      QuillToolbarToggleStyleButtonOptions(iconData: Icons.code_rounded),
  codeBlock: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.integration_instructions_rounded),
  quote: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_quote_rounded),
  listNumbers: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_list_numbered_rounded),
  listBullets: QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.format_list_bulleted_rounded),
  toggleCheckList: QuillToolbarToggleCheckListButtonOptions(
      iconData: Icons.checklist_rounded),
  indentIncrease: QuillToolbarIndentButtonOptions(
      iconData: Icons.format_indent_increase_rounded),
  indentDecrease: QuillToolbarIndentButtonOptions(
      iconData: Icons.format_indent_decrease_rounded),
  linkStyle:
      QuillToolbarLinkStyleButtonOptions(iconData: Icons.link_rounded),
  undoHistory:
      QuillToolbarHistoryButtonOptions(iconData: Icons.undo_rounded),
  redoHistory:
      QuillToolbarHistoryButtonOptions(iconData: Icons.redo_rounded),
  clearFormat: QuillToolbarClearFormatButtonOptions(
      iconData: Icons.format_clear_rounded),
  // ignore: experimental_member_use
  clipboardCopy: QuillToolbarClipboardButtonOptions(iconData: Icons.copy_rounded),
  // ignore: experimental_member_use
  clipboardPaste: QuillToolbarClipboardButtonOptions(iconData: Icons.paste_rounded),
);

/// GAP-9 — habillage OPT-IN de la barre d'outils
/// ([ZRichTextToolbarConfig.themedBarBackground]) : surface + liseré bas
/// dérivés des RÔLES du thème (FR-26 : zéro couleur en dur — les gris figés du
/// legacy `qmew:70-74` ne sont PAS repris, c'est le thème de l'hôte qui parle).
/// Drapeau `false` ⇒ [child] retourné TEL QUEL (rendu historique, AD-4).
Widget zDecorateToolbar(
  BuildContext context,
  ZRichTextToolbarConfig config,
  Widget child,
) {
  if (!config.themedBarBackground) return child;
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return DecoratedBox(
    decoration: BoxDecoration(
      color: scheme.surfaceContainerLow,
      border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
    ),
    child: child,
  );
}

// ─────────────────────────────── Embed LaTeX (E6-3) ──────────────────────────

/// Ouvre le dialogue de saisie/édition d'une formule LaTeX puis insère (ou
/// remplace) l'op embed `{insert:{latex:...}}` au point d'insertion courant du
/// [quill]. MIROIR EXACT d'E6-3 (`_promptAndInsertLatex`), paramétré par le
/// controller pour être partagé par toutes les voies. [isMounted] garde contre
/// une écriture après démontage de l'hôte.
Future<void> insertZLatex(
  BuildContext context,
  QuillController quill, {
  required bool Function() isMounted,
}) async {
  final _LatexEmbedHit? existing = _latexEmbedAtSelection(quill);
  final ZLatexInput? input = await showZLatexDialog(
    context,
    initial: existing?.source ?? '',
    initialBlock: existing?.block ?? false,
  );
  if (input == null || !isMounted()) return;
  // MIN-1 : bascule inline/bloc → embed `latex` (text) vs `latexBlock` (display).
  final Embeddable embed = input.block
      ? ZLatexBlockEmbed(input.source)
      : ZLatexEmbed(input.source);
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      embed,
      TextSelection.collapsed(offset: existing.index + 1),
    );
    return;
  }
  final TextSelection sel = quill.selection;
  final int index =
      sel.isValid ? sel.start : (quill.document.length - 1).clamp(0, 1 << 30);
  final int length = sel.isValid ? sel.end - sel.start : 0;
  quill.replaceText(
    index,
    length,
    embed,
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed LaTeX (inline `latex` OU bloc `latexBlock`) sous/juste-avant
/// le caret (pour l'édition, E6-3 + MIN-1). Retient le mode `block`.
_LatexEmbedHit? _latexEmbedAtSelection(QuillController quill) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map) {
      // GAP-1 : les clés LEGACY DODLP (`formula` display / `formula_inline`)
      // sont détectées pour l'ÉDITION — le REMPLACEMENT ré-écrit sur NOS clés
      // (`latex`/`latexBlock`), migration à sens unique par embed édité.
      final bool isBlock = insert[kLatexBlockEmbedType] is String ||
          insert[kLegacyFormulaEmbedType] is String;
      final bool isInline = insert[kLatexEmbedType] is String ||
          insert[kLegacyFormulaInlineEmbedType] is String;
      if ((isInline || isBlock) && (caret == index || caret == index + 1)) {
        final String source = (isBlock
            ? (insert[kLatexBlockEmbedType] ?? insert[kLegacyFormulaEmbedType])
            : (insert[kLatexEmbedType] ??
                insert[kLegacyFormulaInlineEmbedType])) as String;
        return _LatexEmbedHit(index, source, block: isBlock);
      }
      // Un embed (latex ou autre) occupe une position Delta.
      index += 1;
    } else {
      index += insert is String ? insert.length : 1;
    }
  }
  return null;
}

// ─────────────────────────────── Embed tableau (E6-4) ────────────────────────

/// Ouvre le dialogue de saisie/édition d'un tableau puis insère (ou remplace)
/// l'op embed `{insert:{table:...}}` au point d'insertion courant du [quill].
/// MIROIR EXACT d'E6-4 (`_promptAndInsertTable`), paramétré par le controller.
Future<void> insertZTable(
  BuildContext context,
  QuillController quill, {
  required bool Function() isMounted,
}) async {
  final _TableEmbedHit? existing = _tableEmbedAtSelection(quill);
  final Map<String, dynamic>? structure =
      await showZTableDialog(context, initial: existing?.structure);
  if (structure == null || !isMounted()) return;
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      ZTableEmbed(structure),
      TextSelection.collapsed(offset: existing.index + 1),
    );
    return;
  }
  final TextSelection sel = quill.selection;
  final int index =
      sel.isValid ? sel.start : (quill.document.length - 1).clamp(0, 1 << 30);
  final int length = sel.isValid ? sel.end - sel.start : 0;
  quill.replaceText(
    index,
    length,
    ZTableEmbed(structure),
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed tableau sous/juste-avant le caret (pour l'édition, E6-4).
_TableEmbedHit? _tableEmbedAtSelection(QuillController quill) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map &&
        (insert[kTableEmbedType] is Map ||
            insert[kLegacyTableEmbedType] is String)) {
      if (caret == index || caret == index + 1) {
        final Map<String, dynamic>? structure =
            _tableStructureOfInsert(insert);
        if (structure != null) return _TableEmbedHit(index, structure);
      }
      index += 1;
    } else {
      index += insert is String ? insert.length : 1;
    }
  }
  return null;
}

/// Extrait la structure `{rows,columns,cells}` d'un insert tableau — natif
/// (`table`, Map) OU LEGACY (`x-embed-table`, string Markdown converti via
/// [zParseLegacyMarkdownTable]). GAP-2 : l'édition d'un embed legacy pré-remplit
/// le dialogue puis le REMPLACEMENT ré-écrit un embed `table` structuré
/// (migration à sens unique par embed édité). `null` si la charge legacy est
/// illisible (AD-10 : on n'invente pas une grille — l'insertion reste possible,
/// le remplacement non).
Map<String, dynamic>? _tableStructureOfInsert(Map<dynamic, dynamic> insert) {
  final Object? native = insert[kTableEmbedType];
  if (native is Map) return Map<String, dynamic>.from(native);
  final Object? legacy = insert[kLegacyTableEmbedType];
  if (legacy is String) {
    final List<List<String>>? cells = zParseLegacyMarkdownTable(legacy);
    if (cells != null) {
      return <String, dynamic>{
        kTableRowsKey: cells.length,
        kTableColumnsKey: cells.first.length,
        kTableCellsKey: cells,
      };
    }
  }
  return null;
}

// ─────────────────────────────── Embed média (DP-22) ────────────────────────

/// Ouvre le dialogue de saisie/édition d'une **source média** ([kind] image ou
/// vidéo) puis insère (ou remplace) l'op embed `{insert:{image|video:<source>}}`
/// au point d'insertion courant du [quill]. MIROIR EXACT du flux LaTeX/table,
/// paramétré par la nature du média. SEAM NEUTRE : seule une source OPAQUE est
/// portée — aucun upload/accès réseau n'est câblé (cf. `z_media_embed.dart`).
Future<void> insertZMedia(
  BuildContext context,
  QuillController quill, {
  required ZMediaKind kind,
  required bool Function() isMounted,
}) async {
  final String embedType =
      kind == ZMediaKind.image ? kImageEmbedType : kVideoEmbedType;
  final _MediaEmbedHit? existing = _mediaEmbedAtSelection(quill, embedType);
  final String? source = await showZMediaSourceDialog(
    context,
    kind: kind,
    initial: existing?.source ?? '',
  );
  if (source == null || !isMounted()) return;
  final Embeddable embed =
      kind == ZMediaKind.image ? ZImageEmbed(source) : ZVideoEmbed(source);
  if (existing != null) {
    quill.replaceText(
      existing.index,
      1,
      embed,
      TextSelection.collapsed(offset: existing.index + 1),
    );
    return;
  }
  final TextSelection sel = quill.selection;
  final int index =
      sel.isValid ? sel.start : (quill.document.length - 1).clamp(0, 1 << 30);
  final int length = sel.isValid ? sel.end - sel.start : 0;
  quill.replaceText(
    index,
    length,
    embed,
    TextSelection.collapsed(offset: index + 1),
  );
}

/// Détecte un embed média (`embedType`) sous/juste-avant le caret (édition).
_MediaEmbedHit? _mediaEmbedAtSelection(QuillController quill, String embedType) {
  final TextSelection sel = quill.selection;
  if (!sel.isValid) return null;
  final int caret = sel.baseOffset;
  final List<Map<String, dynamic>> ops =
      DeltaNeutralOps.encodeNeutral(quill.document);
  var index = 0;
  for (final Map<String, dynamic> op in ops) {
    final Object? insert = op['insert'];
    if (insert is Map && insert[embedType] is String) {
      if (caret == index || caret == index + 1) {
        return _MediaEmbedHit(index, insert[embedType] as String);
      }
      index += 1;
    } else {
      index += insert is String ? insert.length : 1;
    }
  }
  return null;
}

/// Localisation d'un embed média dans le document (index Delta + source).
class _MediaEmbedHit {
  const _MediaEmbedHit(this.index, this.source);

  final int index;
  final String source;
}

/// Localisation d'un embed LaTeX dans le document (index Delta + source + mode).
class _LatexEmbedHit {
  const _LatexEmbedHit(this.index, this.source, {required this.block});

  final int index;
  final String source;

  /// `true` si l'embed détecté est un `latexBlock` (display) — MIN-1.
  final bool block;
}

/// Localisation d'un embed tableau dans le document (index Delta + structure).
class _TableEmbedHit {
  const _TableEmbedHit(this.index, this.structure);

  final int index;
  final Map<String, dynamic> structure;
}
