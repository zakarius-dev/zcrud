/// `ZDefaultNoteCard` — **carte de note PAR DÉFAUT** du socle (CR-IFFD-48,
/// rendu de référence CR-IFFD-56).
///
/// ## Le DÉFAUT est le rendu de RÉFÉRENCE (CR-IFFD-56)
///
/// Sans aucun réglage : tuile d'icône **NEUTRE** (`surface`, jetons
/// `studyCardIconTile*`), glyphe [zDefaultNoteReferenceIcon] **neutre**
/// (`onSurfaceVariant`), et le chrome commun de [ZStudyCardReference] (rayon
/// 16, padding 12, marge 4, liseré `outlineVariant` à 50 %, titre
/// `titleMedium/w600/15` une ligne, sous-titre `bodySmall`/`onSurfaceVariant`).
/// L'extrait et les balises restent des **OPTIONS** ([excerpt]/[tags] — `null`
/// / vides ⇒ absents de l'arbre, AD-4) : ils se rendent dans les deux
/// hiérarchies quand ils sont fournis.
///
/// L'ancien rendu v0.43.0 (barre d'accent de tête, pas de tuile) reste
/// **atteignable par réglage** : [hierarchy] `=`
/// [ZStudyCardHierarchy.tintedTile] (ou le jeton
/// `ZcrudTheme.studyCardHierarchy`) — restitution EXACTE gardée par test.
///
/// Priorité, partout : **paramètre > jeton `studyCard*` > défaut-référence**
/// (résolution centralisée dans [zStudyCardChromeOf]).
///
/// ## 🔴 Pourquoi cette carte ne prend AUCUN type de domaine
///
/// Le modèle de note (`ZSmartNote`) vit dans `zcrud_note`, qui n'est **pas**
/// une dépendance de `zcrud_study` (pubspec : « AUCUN autre satellite lourd
/// (`zcrud_note`/`zcrud_document`) »). Une voie typée
/// `ZStudyToolsSectionSpec.notes(notes: List<ZSmartNote>)` exigerait une
/// **nouvelle arête** — interdite ici (AD-1). La carte est donc **autonome sur
/// des primitives** (`title`, `subtitle`, `excerpt`), l'hôte projette.
///
/// ## Invariants
///
/// - **FR-26/NFR-S7** : aucun libellé ni couleur en dur ; tout texte visible
///   est injecté ; `null` ⇒ **absent** de l'arbre (AD-4).
/// - **AD-13** : directionnel partout ; la tuile (référence) comme la barre
///   d'accent (`tintedTile`) sont décoratives — aucune information n'est
///   portée par la SEULE couleur.
/// - **AD-2/SM-1** : `StatelessWidget` pur.
/// - Composition : [ZStudyNoteCard] (façade) + [ZTagChips] — rien de réécrit.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZStudyCardHierarchy, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

import 'z_study_card_reference.dart';
import 'z_study_note_card.dart';
import 'z_tag_chips.dart';

/// Épaisseur de la barre d'accent de tête en hiérarchie `tintedTile` (rendu
/// v0.43.0 — dimension de LAYOUT).
const double kZDefaultNoteAccentHeight = 4;

/// Glyphe du rendu de référence (CR-IFFD-56) — neutre, surchargable par
/// [ZDefaultNoteCard.icon].
const IconData zDefaultNoteReferenceIcon = Icons.note_outlined;

/// Carte de note **par défaut** du socle — autonome, sur primitives
/// (CR-IFFD-48), au rendu de référence (CR-IFFD-56).
///
/// ```dart
/// ZDefaultNoteCard(
///   title: note.title,
///   subtitle: l10n.editedAt(note.updatedAt),  // libellé LOCALISÉ ⇒ injecté
///   excerpt: note.plainTextPreview,           // OPTION (AD-4)
///   tags: tagsOf(note),                       // OPTION (AD-4)
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

  /// Titre de la note (déjà localisé/résolu par l'hôte) — **seule** entrée
  /// requise.
  final String title;

  /// Méta-information (date d'édition…), déjà localisée. `null` ⇒ **absente**
  /// (AD-4).
  final String? subtitle;

  /// Extrait du contenu, en texte brut fourni par l'hôte (le socle ne parse
  /// aucun rich-text ici) — **OPTION** (CR-IFFD-56 : plus jamais une mise en
  /// page imposée). `null` ⇒ **absent** (AD-4).
  final String? excerpt;

  /// Nombre maximal de lignes de l'extrait. Défaut `2`.
  final int excerptMaxLines;

  /// Balises **résolues par l'hôte** — **OPTION**. Vides ⇒ zone **absente**
  /// (AD-4).
  final List<ZFlashcardTag> tags;

  /// Glyphe de la tuile (référence). `null` ⇒ [zDefaultNoteReferenceIcon].
  /// Ignoré en `tintedTile` (le rendu v0.43.0 n'a pas de tuile — restitution
  /// littérale).
  final IconData? icon;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron [ZTagChips]).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ dérivée du
  /// **titre** — stable pour une même note, remap déterministe du kernel.
  final String? colorKey;

  /// Hiérarchie (CR-IFFD-56). `null` ⇒ jeton `ZcrudTheme.studyCardHierarchy`,
  /// puis [ZStudyCardHierarchy.tintedGlyph] (RÉFÉRENCE).
  /// [ZStudyCardHierarchy.tintedTile] restitue exactement v0.43.0 (barre
  /// d'accent).
  final ZStudyCardHierarchy? hierarchy;

  /// Nombre maximal de lignes du titre. `null` ⇒ défaut de la hiérarchie :
  /// `1` en référence, `2` en `tintedTile` (v0.43.0).
  final int? titleMaxLines;

  /// Style du titre. `null` ⇒ jeton `studyCardTitleStyle`, puis référence —
  /// en `tintedTile`, repli v0.43.0 (`titleSmall`).
  final TextStyle? titleStyle;

  /// Style du sous-titre. `null` ⇒ jeton `studyCardSubtitleStyle`, puis
  /// référence — en `tintedTile`, repli v0.43.0 (`bodySmall`).
  final TextStyle? subtitleStyle;

  /// Padding interne. `null` ⇒ jeton, puis référence (12) — en `tintedTile`,
  /// repli v0.43.0 (`gapM`).
  final EdgeInsetsGeometry? contentPadding;

  /// Marge externe. `null` ⇒ jeton, puis `CardTheme.margin`, puis référence
  /// (4) — en `tintedTile`, repli v0.43.0.
  final EdgeInsetsGeometry? margin;

  /// Liseré. `null` ⇒ jeton, puis référence (`outlineVariant` à 50 %) — en
  /// `tintedTile`, repli v0.43.0 (aucun).
  final BorderSide? borderSide;

  /// Rayon de carte. `null` ⇒ jeton, puis référence (16) — en `tintedTile`,
  /// repli v0.43.0 (`radiusM`).
  final Radius? borderRadius;

  /// Créneau d'actions de fin de carte. `null` ⇒ absent (AD-4).
  final Widget? trailing;

  /// Indicateur de traitement — **relayé** à la carte de base (CR-IFFD-56).
  final Widget? progress;

  /// Largeur maximale du slot [progress].
  final double progressMaxWidth;

  /// Politique d'éviction de [trailing] pendant un traitement.
  final bool hidesTrailingWhileBusy;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ non
  /// interactive (AD-45).
  final VoidCallback? onTap;

  /// Appui long. `null` ⇒ capacité **ABSENTE** (AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : [title], complété de
  /// [subtitle].
  final String? semanticLabel;

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

  // ── Hiérarchie de RÉFÉRENCE (défaut CR-IFFD-56) ───────────────────────────

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
      // Tuile NEUTRE, glyphe NEUTRE — décorative (aucune information n'est
      // portée par la seule couleur, AD-13).
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
      belowSubtitle: _buildBody(context),
      actions: trailing,
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
    );
  }

  // ── Hiérarchie `tintedTile` — restitution EXACTE du rendu v0.43.0 ─────────
  //
  // 🔴 NE PAS « moderniser » ce chemin : gardé par un test de restitution aux
  // valeurs POMPÉES depuis v0.43.0. Les paramètres de chrome restent
  // NON-inertes (AD-4) : fournis, ils s'appliquent ; nuls, rendu littéral.

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
      actions: trailing,
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      hidesTrailingWhileBusy: hidesTrailingWhileBusy,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
    );
  }

  /// Extrait + balises, sous le sous-titre. `null` ⇒ slot **absent** (AD-4) —
  /// jamais un `SizedBox.shrink()` inerte. Rendu dans les DEUX hiérarchies
  /// quand fourni (CR-IFFD-56 : c'est une OPTION, pas un défaut).
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
        // filée, le titre textuel systématique (AD-13) et les cibles ≥ 48 dp.
        ZTagChips(key: tagsKey, tags: tags, palette: palette),
    ];
    if (children.length == 1) return children.single;
    // 🔴 MESURÉ (leçon CR-IFFD-37, rejouée ici) : avec des enfants INFLEXIBLES,
    // cette colonne débordait de 156 px dans une cellule de rail 300 × 80 dp —
    // le slot `belowSubtitle` est prêté en fit LOOSE par la carte de base, et
    // un contenu rigide s'AJOUTE à la hauteur au lieu d'y PARTICIPER. Chaque
    // bloc est donc `Flexible` (l'espacement COMPRIS, d'où le `Padding`).
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
}
