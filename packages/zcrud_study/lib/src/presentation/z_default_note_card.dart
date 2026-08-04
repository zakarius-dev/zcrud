/// `ZDefaultNoteCard` — **carte de note PAR DÉFAUT** du socle (CR-IFFD-48).
///
/// Le socle porte la **structure** (barre d'accent de tête, titre, méta,
/// extrait tronqué, balises) ; chaque **couleur et graisse** passe par les
/// **rôles** de l'hôte (`zResolveColorKeyOrSlot` → paires `*Container`/`on*`,
/// `TextTheme.titleSmall`/`bodySmall`). Aucun jeton nouveau nécessaire
/// (mesuré, cf. `z_default_document_card.dart`).
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
/// - **AD-13** : directionnel partout ; la barre d'accent est décorative
///   (isolée par `ZStudyToolsItemCard.accent`) — aucune information n'est
///   portée par la SEULE couleur.
/// - **AD-2/SM-1** : `StatelessWidget` pur.
/// - Composition : [ZStudyNoteCard] (façade) + [ZTagChips] — rien de réécrit.
///
/// ℹ️ Aucune enveloppe colorée sous du contenu d'hôte ⇒ `ZForegroundOverride`
/// sans objet ; aucun `merge` écrit dans ce fichier.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, remapColorKey;

import 'z_study_note_card.dart';
import 'z_tag_chips.dart';

/// Épaisseur de la barre d'accent de tête (dimension de LAYOUT).
const double kZDefaultNoteAccentHeight = 4;

/// Carte de note **par défaut** du socle — autonome, sur primitives
/// (CR-IFFD-48).
///
/// ```dart
/// ZDefaultNoteCard(
///   title: note.title,
///   subtitle: l10n.editedAt(note.updatedAt),  // libellé LOCALISÉ ⇒ injecté
///   excerpt: note.plainTextPreview,
///   tags: tagsOf(note),
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
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.titleMaxLines = 2,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  })  : assert(
          titleMaxLines > 0,
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
  /// aucun rich-text ici). `null` ⇒ **absent** (AD-4).
  final String? excerpt;

  /// Nombre maximal de lignes de l'extrait. Défaut `2`.
  final int excerptMaxLines;

  /// Balises **résolues par l'hôte**. Vides ⇒ zone **absente** (AD-4).
  final List<ZFlashcardTag> tags;

  /// Palette **INJECTÉE** bornant la clé d'accent (patron [ZTagChips]).
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ dérivée du
  /// **titre** — stable pour une même note, remap déterministe du kernel.
  final String? colorKey;

  /// Nombre maximal de lignes du titre. Défaut `2`.
  final int titleMaxLines;

  /// Créneau d'actions de fin de carte. `null` ⇒ absent (AD-4).
  final Widget? trailing;

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
      titleMaxLines: titleMaxLines,
      subtitle: subtitle,
      belowSubtitle: _buildBody(context),
      actions: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel,
    );
  }

  /// Extrait + balises, sous le sous-titre. `null` ⇒ slot **absent** (AD-4) —
  /// jamais un `SizedBox.shrink()` inerte.
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

  /// Clé de la barre d'accent (testabilité).
  static const ValueKey<String> accentKey =
      ValueKey<String>('zDefaultNoteCard_accent');

  /// Clé de l'extrait (testabilité).
  static const ValueKey<String> excerptKey =
      ValueKey<String>('zDefaultNoteCard_excerpt');

  /// Clé de la zone de balises (testabilité).
  static const ValueKey<String> tagsKey =
      ValueKey<String>('zDefaultNoteCard_tags');
}
