/// `ZDefaultNoteCard` — carte de note par défaut du socle, au rendu de
/// référence.
///
/// ## Le défaut est le rendu de référence
///
/// Sans aucun réglage : tuile d'icône neutre (`surface`, jetons
/// `studyCardIconTile*`), glyphe [zDefaultNoteReferenceIcon] neutre
/// (`onSurfaceVariant`), et le chrome commun de [ZStudyCardReference] (rayon
/// 16, padding 12, marge 4, liseré `outlineVariant` à 50 %, titre
/// `titleMedium/w600/15` une ligne, sous-titre `bodySmall`/`onSurfaceVariant`).
/// L'extrait et les balises restent des options ([excerpt]/[tags] — `null`
/// / vides ⇒ absents de l'arbre, invariant AD-4) : ils se rendent dans les
/// deux hiérarchies quand ils sont fournis.
///
/// Un rendu antérieur (barre d'accent de tête, pas de tuile) reste
/// atteignable par réglage : [hierarchy] =
/// [ZStudyCardHierarchy.tintedTile] (ou le jeton
/// `ZcrudTheme.studyCardHierarchy`) — restitution exacte gardée par test.
///
/// Priorité, partout : paramètre > jeton `studyCard*` > défaut-référence
/// (résolution centralisée dans [zStudyCardChromeOf]).
///
/// ## Pourquoi cette carte ne prend aucun type de domaine
///
/// Le modèle de note (`ZSmartNote`) vit dans `zcrud_note`, qui n'est pas
/// une dépendance de `zcrud_study`. Une voie typée
/// `ZStudyToolsSectionSpec.notes(notes: List<ZSmartNote>)` exigerait une
/// nouvelle arête — interdite ici (invariant AD-1). La carte est donc
/// autonome sur des primitives (`title`, `subtitle`, `excerpt`), l'hôte
/// projette.
///
/// ## Invariants
///
/// - Invariant FR-26 : aucun libellé ni couleur en dur ; tout texte visible
///   est injecté ; `null` ⇒ absent de l'arbre (invariant AD-4).
/// - Invariant AD-13 : directionnel partout ; la tuile (référence) comme la
///   barre d'accent (`tintedTile`) sont décoratives — aucune information
///   n'est portée par la seule couleur.
/// - Invariant AD-2 : `StatelessWidget` pur.
/// - Composition : [ZStudyNoteCard] (façade) + [ZTagChips] — rien de réécrit.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZStudyCardHierarchy, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

import '../domain/z_note_summary_port.dart';
import 'z_note_summary_sheet.dart';
import 'z_study_card_reference.dart';
import 'z_study_note_card.dart';
import 'z_tag_chips.dart';

/// Épaisseur de la barre d'accent de tête en hiérarchie `tintedTile`
/// (dimension de layout).
const double kZDefaultNoteAccentHeight = 4;

/// Glyphe du rendu de référence — neutre, surchargable par
/// [ZDefaultNoteCard.icon].
const IconData zDefaultNoteReferenceIcon = Icons.note_outlined;

/// Glyphe de repli de l'action « résumer », surchargeable par
/// [ZDefaultNoteCard.summarizeIcon].
const IconData zDefaultNoteSummarizeFallbackIcon = Icons.summarize_outlined;

/// Cible de taille interactive minimale de l'action « résumer »
/// (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Carte de note par défaut du socle — autonome, sur primitives, au rendu
/// de référence.
///
/// ```dart
/// ZDefaultNoteCard(
///   title: note.title,
///   subtitle: l10n.editedAt(note.updatedAt),  // libellé localisé ⇒ injecté
///   excerpt: note.plainTextPreview,           // option (invariant AD-4)
///   tags: tagsOf(note),                       // option (invariant AD-4)
///   onTap: () => open(note),
/// )
/// ```
class ZDefaultNoteCard extends StatelessWidget {
  /// Construit la carte ; seul [title] est requis.
  const ZDefaultNoteCard({
    required this.title,
    this.subtitle,
    this.excerpt,
    this.excerptMaxLines = 2,
    this.tags = const <ZFlashcardTag>[],
    this.icon,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.hierarchy,
    this.titleMaxLines,
    this.titleStyle,
    this.subtitleStyle,
    this.contentPadding,
    this.margin,
    this.borderSide,
    this.borderRadius,
    this.trailing,
    this.progress,
    this.progressMaxWidth = 120,
    this.hidesTrailingWhileBusy = true,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.summaryPort,
    this.onSummarize,
    this.summarizeSemanticLabel,
    this.summarizeIcon,
    super.key,
  })  : assert(
          titleMaxLines == null || titleMaxLines > 0,
          'titleMaxLines doit être ≥ 1 (le titre est le contenu principal).',
        ),
        assert(
          excerptMaxLines > 0,
          'excerptMaxLines doit être ≥ 1 (un extrait à zéro ligne serait '
          'une zone morte, pas un extrait).',
        );

  /// Titre de la note (déjà localisé/résolu par l'hôte) — seule entrée
  /// requise.
  final String title;

  /// Méta-information (date d'édition…), déjà localisée. `null` ⇒ absente
  /// (invariant AD-4).
  final String? subtitle;

  /// Extrait du contenu, en texte brut fourni par l'hôte (le socle ne parse
  /// aucun rich-text ici) — option, jamais une mise en page imposée.
  /// `null` ⇒ absent (invariant AD-4).
  final String? excerpt;

  /// Nombre maximal de lignes de l'extrait. Défaut `2`.
  final int excerptMaxLines;

  /// Balises résolues par l'hôte — option. Vides ⇒ zone absente
  /// (invariant AD-4).
  final List<ZFlashcardTag> tags;

  /// Glyphe de la tuile (référence). `null` ⇒ [zDefaultNoteReferenceIcon].
  /// Ignoré en `tintedTile` (le rendu antérieur n'a pas de tuile —
  /// restitution littérale).
  final IconData? icon;

  /// Palette injectée bornant la clé d'accent (patron [ZTagChips]).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` opaque). `null` ⇒ dérivée du
  /// titre — stable pour une même note, remap déterministe du kernel.
  final String? colorKey;

  /// Hiérarchie. `null` ⇒ jeton `ZcrudTheme.studyCardHierarchy`,
  /// puis [ZStudyCardHierarchy.tintedGlyph] (référence).
  /// [ZStudyCardHierarchy.tintedTile] restitue exactement le rendu
  /// antérieur (barre d'accent).
  final ZStudyCardHierarchy? hierarchy;

  /// Nombre maximal de lignes du titre. `null` ⇒ défaut de la hiérarchie :
  /// `1` en référence, `2` en `tintedTile`.
  final int? titleMaxLines;

  /// Style du titre. `null` ⇒ jeton `studyCardTitleStyle`, puis référence —
  /// en `tintedTile`, repli `titleSmall`.
  final TextStyle? titleStyle;

  /// Style du sous-titre. `null` ⇒ jeton `studyCardSubtitleStyle`, puis
  /// référence — en `tintedTile`, repli `bodySmall`.
  final TextStyle? subtitleStyle;

  /// Padding interne. `null` ⇒ jeton, puis référence (12) — en `tintedTile`,
  /// repli `gapM`.
  final EdgeInsetsGeometry? contentPadding;

  /// Marge externe. `null` ⇒ jeton, puis `CardTheme.margin`, puis référence
  /// (4) — en `tintedTile`, repli du rendu antérieur.
  final EdgeInsetsGeometry? margin;

  /// Liseré. `null` ⇒ jeton, puis référence (`outlineVariant` à 50 %) — en
  /// `tintedTile`, repli aucun.
  final BorderSide? borderSide;

  /// Rayon de carte. `null` ⇒ jeton, puis référence (16) — en `tintedTile`,
  /// repli `radiusM`.
  final Radius? borderRadius;

  /// Créneau d'actions de fin de carte. `null` ⇒ absent (invariant AD-4).
  final Widget? trailing;

  /// Indicateur de traitement — relayé à la carte de base.
  final Widget? progress;

  /// Largeur maximale du slot [progress].
  final double progressMaxWidth;

  /// Politique d'éviction de [trailing] pendant un traitement.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` et [onLongPress] `null` ⇒ non
  /// interactive.
  final VoidCallback? onTap;

  /// Appui long. `null` ⇒ capacité absente (invariant AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title], complété de
  /// [subtitle].
  final String? semanticLabel;

  /// Port de résumé de la note par IA, **prioritaire** sur celui d'un
  /// [ZNoteSummaryScope] ancêtre. `null` ⇒ le scope est consulté.
  ///
  /// Sans port résolu, l'action « résumer » est **ABSENTE de l'arbre** —
  /// jamais grisée, jamais un no-op : la carte rend alors exactement les mêmes
  /// actions qu'avant (invariant AD-4).
  final ZNoteSummaryPort? summaryPort;

  /// Déclenché au tap sur l'action « résumer », avec le port résolu (non
  /// `null`) : l'application ouvre la surface de son choix — typiquement
  /// [ZNoteSummarySheet].
  ///
  /// [summaryPort]/[ZNoteSummaryScope], [onSummarize] et
  /// [summarizeSemanticLabel] sont **indissociables** : l'action n'est montée
  /// que si les trois sont fournis. Une action sans rappel serait un no-op
  /// (AD-4) ; sans libellé, elle serait muette pour un lecteur d'écran
  /// (AD-13). Le glyphe, lui, a un repli documenté
  /// ([zDefaultNoteSummarizeFallbackIcon]).
  final void Function(ZNoteSummaryPort port)? onSummarize;

  /// Libellé sémantique INJECTÉ de l'action « résumer » (sert aussi de
  /// `tooltip`). Aucun défaut : un libellé par défaut serait figé dans une
  /// langue (FR-26).
  final String? summarizeSemanticLabel;

  /// Glyphe INJECTÉ de l'action « résumer ». `null` ⇒
  /// [zDefaultNoteSummarizeFallbackIcon].
  final IconData? summarizeIcon;

  /// Port de résumé EFFECTIF : paramètre prioritaire, sinon le scope ancêtre.
  /// Exposé pour falsifier la règle « sans port, action ABSENTE ».
  @visibleForTesting
  ZNoteSummaryPort? resolvedSummaryPort(BuildContext context) =>
      summaryPort ?? ZNoteSummaryScope.maybePortOf(context);

  /// Action « résumer », ou `null` quand elle ne doit pas exister.
  ///
  /// Retourne `null` — et non un widget vide — dès qu'un des trois maillons
  /// manque.
  Widget? _buildSummarizeAction(BuildContext context) {
    final port = resolvedSummaryPort(context);
    final onSummarizeAction = onSummarize;
    final label = summarizeSemanticLabel;
    if (port == null || onSummarizeAction == null || label == null) return null;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: IconButton(
        key: summarizeActionKey,
        onPressed: () => onSummarizeAction(port),
        tooltip: label,
        icon: Icon(
          summarizeIcon ?? zDefaultNoteSummarizeFallbackIcon,
          semanticLabel: label,
        ),
      ),
    );
  }

  /// Créneau d'actions EFFECTIF de la carte.
  ///
  /// Sans action « résumer », c'est [trailing] **tel quel** : l'identité du
  /// widget est préservée, aucune rangée n'est interposée — le rendu d'un hôte
  /// qui ne câble pas le résumé est inchangé au widget près.
  Widget? _trailingWith(BuildContext context) {
    final summarize = _buildSummarizeAction(context);
    if (summarize == null) return trailing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[?trailing, summarize],
    );
  }

  ZColorPair _accent(BuildContext context) {
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      seedTitle: title,
    );
    return zResolveColorKeyOrSlot(context, key, slotIndex: palette.indexOf(key));
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZStudyCardHierarchy effective = hierarchy ??
        theme.studyCardHierarchy ??
        ZStudyCardHierarchy.tintedGlyph;
    if (effective == ZStudyCardHierarchy.tintedTile) {
      return _buildTintedTile(context);
    }
    return _buildReference(context);
  }

  // ── Hiérarchie de référence (défaut) ───────────────────────────

  Widget _buildReference(BuildContext context) {
    final ZStudyCardChrome chrome = zStudyCardChromeOf(
      context,
      borderSide: borderSide,
      borderRadius: borderRadius,
      contentPadding: contentPadding,
      margin: margin,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );

    return ZStudyNoteCard(
      // Tuile neutre, glyphe neutre — décorative (aucune information n'est
      // portée par la seule couleur, invariant AD-13).
      leading: ExcludeSemantics(
        child: SizedBox(
          key: iconTileKey,
          width: chrome.iconTileSize,
          height: chrome.iconTileSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.tileColor,
              borderRadius: BorderRadius.all(chrome.iconTileRadius),
            ),
            child: Center(
              child: Icon(
                icon ?? zDefaultNoteReferenceIcon,
                color: chrome.neutralGlyphColor,
              ),
            ),
          ),
        ),
      ),
      title: title,
      titleMaxLines: titleMaxLines ?? ZStudyCardReference.titleMaxLines,
      titleStyle: chrome.titleStyle,
      subtitle: subtitle,
      subtitleStyle: chrome.subtitleStyle,
      contentPadding: chrome.contentPadding,
      margin: chrome.margin,
      borderSide: chrome.borderSide,
      borderRadius: chrome.borderRadius,
      // L'écart tuile→titre (16) et l'élévation (0) de
      // la référence sont résolus par le chrome. Ils ne sont pas écrits en
      // dur dans la primitive de base : celle-ci garde `gapM` et
      // l'élévation du `CardTheme` pour ses hôtes directs.
      leadingGap: chrome.leadingGap,
      elevation: chrome.elevation,
      belowSubtitle: _buildBody(context),
      actions: _trailingWith(context),
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
    );
  }

  // ── Hiérarchie `tintedTile` — restitution exacte du rendu antérieur ──────
  //
  // Ne pas « moderniser » ce chemin : gardé par un test de restitution aux
  // valeurs mesurées du rendu antérieur. Les paramètres de chrome restent
  // non inertes (invariant AD-4) : fournis, ils s'appliquent ; nuls, rendu
  // littéral.

  Widget _buildTintedTile(BuildContext context) {
    final ZColorPair pair = _accent(context);
    return ZStudyNoteCard(
      // Barre d'accent de tête — décor pur (gestes et sémantique isolés par la
      // primitive de base).
      accent: SizedBox(
        key: accentKey,
        height: kZDefaultNoteAccentHeight,
        child: ColoredBox(color: pair.color),
      ),
      title: title,
      titleMaxLines: titleMaxLines ?? 2,
      titleStyle: titleStyle,
      subtitle: subtitle,
      subtitleStyle: subtitleStyle,
      contentPadding: contentPadding,
      margin: margin,
      borderSide: borderSide,
      borderRadius: borderRadius,
      belowSubtitle: _buildBody(context),
      actions: _trailingWith(context),
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
    );
  }

  /// Extrait + balises, sous le sous-titre. `null` ⇒ slot absent
  /// (invariant AD-4) — jamais un `SizedBox.shrink()` inerte. Rendu dans les
  /// deux hiérarchies quand fourni : c'est une option, pas un défaut.
  Widget? _buildBody(BuildContext context) {
    final String? preview = excerpt;
    final bool hasTags = tags.isNotEmpty;
    if (preview == null && !hasTags) return null;

    final ZcrudTheme theme = ZcrudTheme.of(context);
    final List<Widget> children = <Widget>[
      if (preview != null)
        Text(
          preview,
          key: excerptKey,
          textAlign: TextAlign.start,
          maxLines: excerptMaxLines,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      if (hasTags)
        // Aucune rangée de puces réécrite : `ZTagChips` porte la palette
        // filée, le titre textuel systématique (invariant AD-13) et les
        // cibles ≥ 48 dp.
        ZTagChips(key: tagsKey, tags: tags, palette: palette),
    ];
    if (children.length == 1) return children.single;
    // Mesuré : avec des enfants inflexibles, cette colonne débordait dans
    // une cellule de rail étroite — le slot `belowSubtitle` est prêté en
    // fit loose par la carte de base, et un contenu rigide s'ajoute à la
    // hauteur au lieu d'y participer. Chaque bloc est donc `Flexible`
    // (l'espacement compris, d'où le `Padding`).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: children.first),
        Flexible(
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: theme.gapS),
            child: children.last,
          ),
        ),
      ],
    );
  }

  /// Clé de la tuile d'icône (référence — testabilité).
  static const ValueKey<String> iconTileKey =
      ValueKey<String>('zDefaultNoteCard_iconTile');

  /// Clé de la barre d'accent `tintedTile` (testabilité).
  static const ValueKey<String> accentKey =
      ValueKey<String>('zDefaultNoteCard_accent');

  /// Clé de l'extrait (testabilité).
  static const ValueKey<String> excerptKey =
      ValueKey<String>('zDefaultNoteCard_excerpt');

  /// Clé de la zone de balises (testabilité).
  static const ValueKey<String> tagsKey =
      ValueKey<String>('zDefaultNoteCard_tags');

  /// Clé de l'action « résumer » (testabilité).
  static const ValueKey<String> summarizeActionKey =
      ValueKey<String>('zDefaultNoteCard_summarize');
}
