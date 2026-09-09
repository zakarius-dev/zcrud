/// Bandeau de résultat d'un examen blanc : `ZWhiteExamScoreBanner`.
///
/// Widget pur : il ne connaît aucun moteur, ne recalcule aucun score et
/// n'écrit rien. Il **lit** l'agrégat produit à la soumission et le verdict
/// qui en est dérivé par la fonction pure du domaine — il n'existe donc
/// qu'un seul endroit où la réussite est décidée.
///
/// Le seuil est une **donnée de l'application** : ce paquet n'en écrit aucun,
/// pas même en repli. Sans seuil déclaré, le bandeau ne prononce **aucun
/// verdict** — il rend les statistiques sur une teinte neutre. Les trois
/// teintes (atteint / non atteint / sans verdict) sont des **clés** résolues
/// contre le thème, jamais des couleurs posées ici.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

import '../domain/z_white_exam_verdict.dart';
import 'z_white_exam_format.dart';

/// Bandeau de fin d'examen : taux atteint, verdict, et trois statistiques.
///
/// Les trois statistiques sont **réponses correctes**, **temps total** et
/// **temps moyen par réponse**. Elles se lisent toutes sur les mêmes nombres
/// que le verdict : « répondues » est le nombre de réponses **notées**, qui
/// inclut les questions restées blanches lorsque la soumission les a comptées
/// fausses.
class ZWhiteExamScoreBanner extends StatelessWidget {
  /// Construit le bandeau à partir de l'agrégat de soumission.
  const ZWhiteExamScoreBanner({
    required this.result,
    this.elapsed = Duration.zero,
    this.successRatio,
    super.key,
  });

  /// Agrégat produit à la soumission — lu tel quel, jamais recompté.
  final ZStudySessionResult result;

  /// Temps écoulé sur l'épreuve, mesuré par l'hôte (le domaine n'a pas
  /// d'horloge). `Duration.zero` par défaut : aucune durée n'est inventée.
  final Duration elapsed;

  /// Taux de réussite exigé par l'application, dans `[0, 1]`.
  ///
  /// `null` — ou une valeur inexploitable — signifie « aucun verdict » : le
  /// bandeau n'annonce alors ni réussite ni échec, et n'affiche aucun
  /// pourcentage. C'est le défaut, et c'est délibéré : un seuil est une règle
  /// pédagogique, que le socle ne décide pas à la place de l'application.
  final double? successRatio;

  /// Clé du bandeau.
  static const ValueKey<String> bannerKey = ValueKey<String>('zWhiteExamScore');

  /// Clé de la statistique « réponses correctes ».
  static const ValueKey<String> correctStatKey = ValueKey<String>(
    'zWhiteExamStatCorrect',
  );

  /// Clé de la statistique « temps total ».
  static const ValueKey<String> elapsedStatKey = ValueKey<String>(
    'zWhiteExamStatElapsed',
  );

  /// Clé de la statistique « temps moyen par réponse ».
  static const ValueKey<String> averageStatKey = ValueKey<String>(
    'zWhiteExamStatAverage',
  );

  /// Clé de couleur du bandeau lorsque le seuil est **atteint** — résolue par
  /// le seam de clés du cœur, jamais par une valeur.
  static const String successColorKey = 'zcrud.study.exam.success';

  /// Clé de couleur du bandeau lorsque le seuil n'est **pas** atteint.
  static const String shortfallColorKey = 'zcrud.study.exam.shortfall';

  /// Clé de couleur du bandeau lorsque **aucun seuil** n'est déclaré : il n'y
  /// a alors rien à juger, et rien à teinter d'un verdict.
  static const String neutralColorKey = 'zcrud.study.exam.score';

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Voie UNIQUE du jugement : la fonction pure du domaine. Le bandeau ne
    // compare aucun ratio lui-même — sans quoi la règle existerait à deux
    // endroits, et pourrait diverger.
    final verdict = zWhiteExamVerdictFor(result, successRatio: successRatio);
    final pair = zResolveColorKeyOrSlot(
      context,
      switch (verdict) {
        null => neutralColorKey,
        final v when v.passed => successColorKey,
        _ => shortfallColorKey,
      },
      slotIndex: switch (verdict) {
        null => ZColorSlot.neutral.index,
        final v when v.passed => ZColorSlot.primary.index,
        _ => ZColorSlot.tertiary.index,
      },
    );
    final answered = result.total;
    final average = answered > 0
        ? Duration(seconds: elapsed.inSeconds ~/ answered)
        : Duration.zero;

    return Semantics(
      key: bannerKey,
      liveRegion: true,
      label: switch (verdict) {
        null => label(context, 'zcrud.study.exam.score', fallback: 'Résultat'),
        final v when v.passed => label(
          context,
          'zcrud.study.exam.passed',
          fallback: 'Seuil atteint',
        ),
        _ => label(
          context,
          'zcrud.study.exam.failed',
          fallback: 'Seuil non atteint',
        ),
      },
      value: '${result.correct}/$answered',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pair.color,
          borderRadius: BorderRadius.all(theme.radiusM),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.gapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // Sans seuil déclaré, aucun pourcentage : le taux atteint
              // n'a de sens que face à un taux exigé, et le socle n'en
              // invente pas.
              if (verdict case final v?)
                ExcludeSemantics(
                  child: Text(
                    '${(v.ratio * 100).round()}%',
                    textAlign: TextAlign.start,
                    style: TextStyle(color: pair.onColor),
                  ),
                ),
              SizedBox(height: theme.gapM),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _Stat(
                    statKey: correctStatKey,
                    caption: label(
                      context,
                      'zcrud.study.exam.stat.correct',
                      fallback: 'Correctes',
                    ),
                    value: '${result.correct}/$answered',
                    foreground: pair.onColor,
                  ),
                  _Stat(
                    statKey: elapsedStatKey,
                    caption: label(
                      context,
                      'zcrud.study.exam.stat.elapsed',
                      fallback: 'Temps total',
                    ),
                    value: zWhiteExamDigits(elapsed),
                    foreground: pair.onColor,
                  ),
                  _Stat(
                    statKey: averageStatKey,
                    caption: label(
                      context,
                      'zcrud.study.exam.stat.average',
                      fallback: 'Moyenne par question',
                    ),
                    value: zWhiteExamDigits(average),
                    foreground: pair.onColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une statistique du bandeau : un nombre visible, une annonce complète.
class _Stat extends StatelessWidget {
  const _Stat({
    required this.statKey,
    required this.caption,
    required this.value,
    required this.foreground,
  });

  final ValueKey<String> statKey;

  /// Libellé déjà résolu par l'appelant — aucun littéral ne transite.
  final String caption;
  final String value;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Semantics(
    key: statKey,
    label: caption,
    value: value,
    // Sans exclusion, le libellé visible et le nœud parent annonceraient
    // deux fois la même chose.
    child: ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            textAlign: TextAlign.start,
            style: TextStyle(color: foreground),
          ),
          Text(
            caption,
            textAlign: TextAlign.start,
            style: TextStyle(color: foreground),
          ),
        ],
      ),
    ),
  );
}
