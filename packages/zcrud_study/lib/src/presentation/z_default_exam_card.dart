/// `ZDefaultExamCard` — **carte d'examen PAR DÉFAUT** du socle.
///
/// La voie typée est POSSIBLE ici : le modèle [ZExam] vit dans `zcrud_exam`,
/// dépendance **déjà déclarée** de `zcrud_study` — aucune arête nouvelle
/// (invariant AD-1). Le pendant qui porte les données est
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
/// - **AD-2** : `StatelessWidget` pur.
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

/// Opacité de la variante « passé » (grandeur de RENDU, jamais une couleur :
/// aucun rôle sémantique n'est inventé pour dire « échu »).
const double kZDefaultExamPastOpacity = 0.6;

/// Carte d'examen **par défaut** du socle.
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
    this.now,
    this.pastLabel,
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

  /// Instant de référence qui décide de la variante « passé ».
  ///
  /// `null` ⇒ la variante est **hors service** : la carte rend exactement
  /// l'arbre d'avant l'introduction de cette capacité (invariant AD-4), quel
  /// que soit `exam.date`. La règle de date n'est pas réécrite ici : elle est
  /// celle de `ZExam.isPast` — un examen daté dont le jour calendaire est
  /// antérieur à celui de [now].
  ///
  /// Le socle n'appelle jamais `DateTime.now()` : l'horloge est un paramètre
  /// (rendu déterministe, testable).
  final DateTime? now;

  /// Libellé LOCALISÉ **INJECTÉ** de l'état « passé ». Rendu en puce quand la
  /// carte est passée : l'état est alors dit **EN TEXTE** (AD-13), jamais par
  /// la seule atténuation. `null` ⇒ puce absente — l'atténuation, elle,
  /// s'applique quand même.
  final String? pastLabel;

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
  /// interactive.
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

  /// Variante « passé » : uniquement si l'hôte a fourni son horloge, et selon
  /// la règle de date du modèle (`ZExam.isPast`) — aucune seconde règle.
  bool get _isPast {
    final DateTime? at = now;
    return at != null && exam.isPast(at);
  }

  bool get _showsPastChip => _isPast && pastLabel != null;

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

    final Widget card = ZStudyToolsItemCard(
      accent: SizedBox(
        key: accentKey,
        height: kZDefaultExamAccentHeight,
        child: ColoredBox(color: pair.color),
      ),
      title: _effectiveTitle,
      titleMaxLines: titleMaxLines,
      subtitle: dateLabel,
      belowSubtitle: _buildBelowSubtitle(context, theme, pair),
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel: semanticLabel ?? _defaultSemanticLabel,
    );

    // Atténuation d'un examen passé : opacité seule — aucune couleur
    // sémantique inventée, aucun rôle détourné. L'information reste portée par
    // le texte (puce « passé » quand l'hôte l'a injectée) et par l'annonce.
    if (!_isPast) return card;
    return Opacity(
      key: pastOverlayKey,
      opacity: kZDefaultExamPastOpacity,
      child: card,
    );
  }

  /// Contenu sous le sous-titre : puce de rappel, puce « passé », ou les deux.
  ///
  /// Hors variante « passé », rend **exactement** ce que rendait la carte
  /// avant : la puce de rappel, ou `null` (invariant AD-4).
  Widget? _buildBelowSubtitle(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) {
    final Widget? reminder =
        _showsReminderChip ? _buildReminderChip(context, theme, pair) : null;
    if (!_showsPastChip) return reminder;

    final Widget past = _buildPastChip(context, theme, pair);
    if (reminder == null) return past;
    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapS,
      children: <Widget>[past, reminder],
    );
  }

  String get _defaultSemanticLabel {
    final StringBuffer buffer = StringBuffer(_effectiveTitle);
    final String? date = dateLabel;
    if (date != null) buffer.write(', $date');
    if (_showsPastChip) buffer.write(', ${pastLabel!}');
    if (_showsReminderChip) buffer.write(', ${reminderLabel!}');
    return buffer.toString();
  }

  /// Puce « passé » : libellé injecté sur un rôle **neutre** — la carte
  /// n'invente aucune couleur d'état (FR-26), et le texte porte l'état.
  Widget _buildPastChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair accent,
  ) {
    final ZColorPair neutral = zResolveColorKeyOrSlot(
      context,
      'neutral',
      slotIndex: palette.indexOf('neutral'),
    );
    return Align(
      alignment: AlignmentDirectional.centerStart,
      heightFactor: 1,
      child: DecoratedBox(
        key: pastChipKey,
        decoration: BoxDecoration(
          color: neutral.color,
          borderRadius: BorderRadius.all(theme.radiusM),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapM,
            vertical: theme.gapS,
          ),
          child: Text(
            pastLabel!,
            key: pastLabelKey,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                    .copyWith(color: neutral.onColor),
          ),
        ),
      ),
    );
  }

  Widget _buildReminderChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
  ) =>
      Align(
        alignment: AlignmentDirectional.centerStart,
        // `heightFactor: 1` : un `Align` sans facteur REMPLIT la hauteur
        // disponible (carte gonflée), donc ce facteur est requis.
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

  /// Clé de l'enveloppe d'atténuation de la variante « passé » (testabilité).
  static const ValueKey<String> pastOverlayKey =
      ValueKey<String>('zDefaultExamCard_pastOverlay');

  /// Clé de la puce « passé » (testabilité).
  static const ValueKey<String> pastChipKey =
      ValueKey<String>('zDefaultExamCard_pastChip');

  /// Clé du **texte** « passé » (testabilité — AD-13).
  static const ValueKey<String> pastLabelKey =
      ValueKey<String>('zDefaultExamCard_pastLabel');
}
