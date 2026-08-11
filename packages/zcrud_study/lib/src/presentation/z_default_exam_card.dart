/// `ZDefaultExamCard` — **carte d'examen PAR DÉFAUT** du socle (CR-IFFD-48).
///
/// La voie typée est POSSIBLE ici : le modèle [ZExam] vit dans `zcrud_exam`,
/// dépendance **déjà déclarée** de `zcrud_study` (arête ES-9.2) — aucune arête
/// nouvelle (AD-1). Le pendant qui porte les données est
/// `ZStudyToolsSectionSpec.exams(exams:)`.
///
/// Structure : barre d'accent de tête, intitulé, date (déjà **formatée et
/// localisée par l'hôte** — le socle ne formate jamais une date en dur,
/// FR-26/AD-13), puce de rappel quand les rappels sont ACTIVÉS **et** que
/// l'hôte a injecté son libellé. Couleurs et graisses : **rôles** de l'hôte
/// uniquement (`zResolveColorKeyOrSlot`, `TextTheme`) — aucun jeton nouveau
/// nécessaire.
///
/// - **AD-4** : tout créneau non fourni est **absent** de l'arbre.
/// - **AD-13** : l'état « rappels activés » est dit **EN TEXTE** (puce), pas
///   seulement par une couleur ; directionnel partout ; `Semantics` par la
///   primitive de base.
/// - **AD-2/SM-1** : `StatelessWidget` pur.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_exam/zcrud_exam.dart' show ZExam;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, remapColorKey;

import 'z_study_tools_item_card.dart';

/// Épaisseur de la barre d'accent de tête (dimension de LAYOUT).
const double kZDefaultExamAccentHeight = 4;

/// Carte d'examen **par défaut** du socle (CR-IFFD-48).
///
/// ```dart
/// ZDefaultExamCard(
///   exam: exam,
///   dateLabel: l10n.examDate(exam.date),   // formatée PAR L'HÔTE (l10n)
///   reminderLabel: l10n.remindersOn,       // libellé VISIBLE ⇒ injecté
///   onTap: () => open(exam),
/// )
/// ```
class ZDefaultExamCard extends StatelessWidget {
  /// Construit la carte ; seul [exam] est requis.
  const ZDefaultExamCard({
    required this.exam,
    this.untitledLabel,
    this.dateLabel,
    this.reminderLabel,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.titleMaxLines = 2,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  }) : assert(
          titleMaxLines > 0,
          'titleMaxLines doit être ≥ 1 (l\'intitulé est le contenu principal).',
        );

  /// Examen rendu — **seule** entrée requise. Le dessin lit `title`,
  /// `reminderEnabled` et `id` ; la date arrive déjà formatée ([dateLabel]).
  final ZExam exam;

  /// Libellé LOCALISÉ **INJECTÉ** pour un examen à l'intitulé vide. `null` ⇒
  /// l'intitulé vide est rendu tel quel (le socle ne traduit **jamais**).
  final String? untitledLabel;

  /// Date **déjà formatée et localisée par l'hôte**. Le socle n'appelle aucun
  /// formateur de date (le format est de la l10n — FR-26/AD-13). `null` ⇒
  /// **absente** (AD-4).
  final String? dateLabel;

  /// Libellé LOCALISÉ **INJECTÉ** de l'état « rappels activés ». La puce n'est
  /// rendue que si `exam.reminderEnabled` **et** ce libellé sont présents :
  /// l'état est alors dit **EN TEXTE** (AD-13), jamais par une seule couleur.
  /// `null` ⇒ puce **absente** (AD-4).
  final String? reminderLabel;

  /// Palette **INJECTÉE** bornant la clé d'accent.
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` **opaque**). `null` ⇒ dérivée de la
  /// clé stable `'exam'` — tous les examens portent le même accent, sur tous
  /// les lancements (remap déterministe du kernel), comme l'accent par type
  /// des flashcards.
  final String? colorKey;

  /// Nombre maximal de lignes de l'intitulé. Défaut `2`.
  final int titleMaxLines;

  /// Créneau d'actions de fin de carte. `null` ⇒ absent (AD-4).
  final Widget? trailing;

  /// Activation de la carte. `null` **et** [onLongPress] `null` ⇒ non
  /// interactive (AD-45).
  final VoidCallback? onTap;

  /// Appui long. `null` ⇒ capacité **ABSENTE** (AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : intitulé effectif,
  /// complété de [dateLabel] et — si rendue — de la puce de rappel (AD-13).
  final String? semanticLabel;

  String get _effectiveTitle {
    if (exam.title.isNotEmpty) return exam.title;
    return untitledLabel ?? exam.title;
  }

  bool get _showsReminderChip => exam.reminderEnabled && reminderLabel != null;

  ZColorPair _accent(BuildContext context) {
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey,
      // Clé de GENRE stable (comme `card.type.name` côté flashcard) — une clé
      // opaque, pas un libellé visible.
      seedTitle: 'exam',
    );
    return zResolveColorKeyOrSlot(context, key, slotIndex: palette.indexOf(key));
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZColorPair pair = _accent(context);

    return ZStudyToolsItemCard(
      accent: SizedBox(
        key: accentKey,
        height: kZDefaultExamAccentHeight,
        child: ColoredBox(color: pair.color),
      ),
      title: _effectiveTitle,
      titleMaxLines: titleMaxLines,
      subtitle: dateLabel,
      belowSubtitle:
          _showsReminderChip ? _buildReminderChip(context, theme, pair) : null,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel,
    );
  }

  String get _defaultSemanticLabel {
    final StringBuffer buffer = StringBuffer(_effectiveTitle);
    final String? date = dateLabel;
    if (date != null) buffer.write(', $date');
    if (_showsReminderChip) buffer.write(', ${reminderLabel!}');
    return buffer.toString();
  }

  Widget _buildReminderChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        // `heightFactor: 1` — leçon MESURÉE de CR-47 : un `Align` sans
        // facteur REMPLIT la hauteur disponible (carte gonflée à 854 dp).
        heightFactor: 1,
        child: DecoratedBox(
          key: reminderChipKey,
          decoration: BoxDecoration(
            color: pair.color,
            borderRadius: BorderRadius.all(theme.radiusM),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.gapM,
              vertical: theme.gapS,
            ),
            child: Text(
              reminderLabel!,
              key: reminderLabelKey,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (Theme.of(context).textTheme.labelSmall ??
                      const TextStyle())
                  .copyWith(color: pair.onColor),
            ),
          ),
        ),
      );

  /// Clé de la barre d'accent (testabilité).
  static const ValueKey<String> accentKey =
      ValueKey<String>('zDefaultExamCard_accent');

  /// Clé de la puce de rappel (testabilité).
  static const ValueKey<String> reminderChipKey =
      ValueKey<String>('zDefaultExamCard_reminderChip');

  /// Clé du **texte** de rappel (testabilité — AD-13).
  static const ValueKey<String> reminderLabelKey =
      ValueKey<String>('zDefaultExamCard_reminderLabel');
}
