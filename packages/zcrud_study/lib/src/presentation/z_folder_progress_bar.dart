/// `ZFolderProgressBar` — barre de progression segmentée d'un dossier
/// d'étude : « apprises », « à réviser », « à apprendre ».
///
/// La barre consomme une **valeur** déjà agrégée
/// ([ZFolderProgressSummary]) : elle ne voit ni les cartes, ni les états SRS,
/// ni un flux. C'est l'appelant qui appelle [zSummarizeFolderProgress] quand
/// ses données changent ; le widget ne recalcule rien, même reconstruit cent
/// fois (invariant AD-2).
///
/// Trois seaux et non un seul arc : l'anneau `correct/total` d'une session
/// répond à une autre question (ce qui vient d'être répondu), pas à la
/// partition SRS d'un dossier.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZColorPair,
        ZGradientSpec,
        ZcrudTheme,
        zResolveColorKeyOrSlot,
        zResolveGradient,
        zSignatureKey;

import '../domain/z_folder_progress_summary.dart';
import 'z_gradient_geometry.dart';

/// Hauteur de référence de la barre (dimension de LAYOUT, jamais une couleur).
const double kZFolderProgressBarHeight = 8;

/// Barre segmentée de progression d'un dossier (présentation **pure**).
///
/// ```dart
/// // Une fois, quand les données changent :
/// final summary = zSummarizeFolderProgress(cards, infos, now: DateTime.now());
/// // Au rendu — la valeur, jamais les flux :
/// ZFolderProgressBar(
///   summary: summary,
///   learnedLabel: l10n.learned(summary.learned),
///   toReviewLabel: l10n.toReview(summary.toReview),
///   toLearnLabel: l10n.toLearn(summary.toLearn),
/// )
/// ```
///
/// - **AD-2** : `StatelessWidget` pur, aucun état détenu, aucun calcul de
///   partition — [summary] est déjà agrégé.
/// - **AD-4** : un libellé `null` est **absent** de l'arbre (jamais un
///   `SizedBox.shrink()` inerte) ; aucune légende n'est fabriquée par le
///   socle.
/// - **AD-13** : la couleur n'est jamais le seul canal — la légende porte les
///   comptes en texte, et l'annonce sémantique les répète ; insets et
///   alignements directionnels.
/// - **FR-26** : aucune couleur en dur ; tout passe par les clés de couleur
///   résolues (rôles de l'hôte) et par les jetons `ZcrudTheme`.
class ZFolderProgressBar extends StatelessWidget {
  /// Construit la barre depuis un agrégat déjà calculé.
  const ZFolderProgressBar({
    required this.summary,
    this.learnedLabel,
    this.toReviewLabel,
    this.toLearnLabel,
    this.learnedColorKey = 'primary',
    this.toReviewColorKey = 'secondary',
    this.toLearnColorKey = 'neutral',
    this.gradientIdentity,
    this.height,
    this.borderRadius,
    this.semanticLabel,
    super.key,
  }) : assert(
         height == null || height > 0,
         'height doit être > 0 (une barre de hauteur nulle serait invisible).',
       );

  /// Agrégat **pré-calculé** affiché. Le widget ne le recalcule jamais.
  final ZFolderProgressSummary summary;

  /// Libellé LOCALISÉ **INJECTÉ** du seau « apprises ». `null` ⇒ entrée de
  /// légende absente (AD-4).
  final String? learnedLabel;

  /// Libellé LOCALISÉ **INJECTÉ** du seau « à réviser ». `null` ⇒ absent.
  final String? toReviewLabel;

  /// Libellé LOCALISÉ **INJECTÉ** du seau « à apprendre ». `null` ⇒ absent.
  final String? toLearnLabel;

  /// Clé de couleur du segment « apprises ».
  final String learnedColorKey;

  /// Clé de couleur du segment « à réviser ».
  final String toReviewColorKey;

  /// Clé de couleur du segment « à apprendre » (piste restante).
  final String toLearnColorKey;

  /// Identité de dégradé signature du segment « apprises » (nom du dossier,
  /// matière…). `null` ⇒ segment uni.
  ///
  /// L'arbitrage référence/neutre n'est pas refait ici : la clé passe par le
  /// résolveur de dégradé du cœur, qui décide seul si le profil courant
  /// autorise la palette de référence. Sans résolveur ni palette injectés, la
  /// résolution rend `null` et le segment reste uni — rendu inchangé.
  final String? gradientIdentity;

  /// Hauteur de la barre. `null` ⇒ [kZFolderProgressBarHeight].
  final double? height;

  /// Rayon des extrémités. `null` ⇒ jeton `ZcrudTheme.radiusS`.
  final Radius? borderRadius;

  /// Annonce sémantique de la barre entière. `null` ⇒ annonce composée des
  /// libellés fournis, à défaut du seul rapport `apprises/total`.
  final String? semanticLabel;

  /// Clé de la piste (testabilité).
  static const ValueKey<String> trackKey = ValueKey<String>(
    'zFolderProgressBar_track',
  );

  /// Clé du segment « apprises » (testabilité).
  static const ValueKey<String> learnedSegmentKey = ValueKey<String>(
    'zFolderProgressBar_learnedSegment',
  );

  /// Clé du segment « à réviser » (testabilité).
  static const ValueKey<String> toReviewSegmentKey = ValueKey<String>(
    'zFolderProgressBar_toReviewSegment',
  );

  /// Clé du segment « à apprendre » (testabilité).
  static const ValueKey<String> toLearnSegmentKey = ValueKey<String>(
    'zFolderProgressBar_toLearnSegment',
  );

  /// Clé de la légende textuelle (testabilité — AD-13).
  static const ValueKey<String> legendKey = ValueKey<String>(
    'zFolderProgressBar_legend',
  );

  bool get _hasLegend =>
      learnedLabel != null || toReviewLabel != null || toLearnLabel != null;

  String get _effectiveSemanticLabel {
    final String? injected = semanticLabel;
    if (injected != null) return injected;
    final List<String> parts = <String>[
      ?learnedLabel,
      ?toReviewLabel,
      ?toLearnLabel,
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    return '${summary.learned}/${summary.total}';
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final Radius radius = borderRadius ?? theme.radiusS;
    final double barHeight = height ?? kZFolderProgressBarHeight;

    final ZColorPair learnedPair = zResolveColorKeyOrSlot(
      context,
      learnedColorKey,
      slotIndex: 0,
    );
    final ZColorPair toReviewPair = zResolveColorKeyOrSlot(
      context,
      toReviewColorKey,
      slotIndex: 1,
    );
    final ZColorPair toLearnPair = zResolveColorKeyOrSlot(
      context,
      toLearnColorKey,
      slotIndex: 4,
    );
    final String? identity = gradientIdentity;
    final ZGradientSpec? learnedGradient = identity == null || identity.isEmpty
        ? null
        : zResolveGradient(context, zSignatureKey(identity));

    final Widget bar = ClipRRect(
      borderRadius: BorderRadius.all(radius),
      child: SizedBox(
        key: trackKey,
        height: barHeight,
        // `total == 0` : aucun flex ne peut être nul partout — la piste seule
        // est peinte (jamais une division par zéro, jamais une `Row` vide).
        child: summary.total == 0
            ? ColoredBox(color: toLearnPair.color)
            : Row(
                children: <Widget>[
                  if (summary.learned > 0)
                    Expanded(
                      flex: summary.learned,
                      child: DecoratedBox(
                        key: learnedSegmentKey,
                        decoration: BoxDecoration(
                          color: learnedGradient == null
                              ? learnedPair.color
                              : null,
                          gradient: learnedGradient == null
                              ? null
                              : zApplyThemedGradientGeometry(
                                  learnedGradient.gradient,
                                  theme,
                                ),
                        ),
                      ),
                    ),
                  if (summary.toReview > 0)
                    Expanded(
                      flex: summary.toReview,
                      child: ColoredBox(
                        key: toReviewSegmentKey,
                        color: toReviewPair.color,
                      ),
                    ),
                  if (summary.toLearn > 0)
                    Expanded(
                      flex: summary.toLearn,
                      child: ColoredBox(
                        key: toLearnSegmentKey,
                        color: toLearnPair.color,
                      ),
                    ),
                ],
              ),
      ),
    );

    return Semantics(
      container: true,
      value: _effectiveSemanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          bar,
          if (_hasLegend) ...<Widget>[
            SizedBox(height: theme.gapS),
            _buildLegend(context, theme, learnedPair, toReviewPair, toLearnPair),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair learnedPair,
    ZColorPair toReviewPair,
    ZColorPair toLearnPair,
  ) {
    final TextStyle style =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle();
    return ExcludeSemantics(
      child: Wrap(
        key: legendKey,
        spacing: theme.gapM,
        runSpacing: theme.gapS,
        children: <Widget>[
          if (learnedLabel != null)
            _LegendEntry(
              label: learnedLabel!,
              color: learnedPair.color,
              size: theme.gapM,
              gap: theme.gapS,
              style: style,
            ),
          if (toReviewLabel != null)
            _LegendEntry(
              label: toReviewLabel!,
              color: toReviewPair.color,
              size: theme.gapM,
              gap: theme.gapS,
              style: style,
            ),
          if (toLearnLabel != null)
            _LegendEntry(
              label: toLearnLabel!,
              color: toLearnPair.color,
              size: theme.gapM,
              gap: theme.gapS,
              style: style,
            ),
        ],
      ),
    );
  }
}

/// Une entrée de légende : pastille de couleur **et** libellé textuel — la
/// couleur ne porte jamais l'information seule (AD-13).
class _LegendEntry extends StatelessWidget {
  const _LegendEntry({
    required this.label,
    required this.color,
    required this.size,
    required this.gap,
    required this.style,
  });

  final String label;
  final Color color;
  final double size;
  final double gap;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
      SizedBox(width: gap),
      Text(label, textAlign: TextAlign.start, style: style),
    ],
  );
}
