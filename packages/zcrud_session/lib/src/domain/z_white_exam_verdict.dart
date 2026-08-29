/// Verdict de réussite d'un examen blanc — valeur pure, jamais une règle
/// du socle.
///
/// Le seuil de réussite est une **donnée de l'application** : aucun taux n'est
/// écrit dans ce paquet. Tant que l'hôte ne déclare pas de `successRatio`,
/// aucun verdict n'existe (`null`) et rien ne change à l'écran de fin — c'est
/// le défaut.
///
/// Pur-Dart côté calcul (aucun widget, aucune horloge, aucun gestionnaire
/// d'état) : [zWhiteExamVerdictFor] est une fonction totale, déterministe et
/// sans exception (invariant AD-10).
library;

import 'package:flutter/foundation.dart' show immutable;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

/// Verdict d'un examen blanc : le parcours atteint-il le seuil déclaré ?
///
/// Value-object immuable, sans identité ni date. Il ne porte **pas** le seuil
/// lui-même : il porte le fait mesuré ([ratio], [correct], [total]) et la
/// conclusion ([passed]).
@immutable
class ZWhiteExamVerdict {
  /// Construit un verdict.
  ///
  /// Aucun `assert` (invariant AD-10) : la normalisation des entrées est
  /// portée par [zWhiteExamVerdictFor], la seule frontière qui reçoit des
  /// valeurs brutes (résultat persisté, seuil venu de la configuration hôte).
  const ZWhiteExamVerdict({
    required this.passed,
    required this.ratio,
    required this.correct,
    required this.total,
  });

  /// `true` si et seulement si [ratio] atteint le seuil déclaré par l'hôte.
  final bool passed;

  /// Taux de réussite **atteint** (`correct / total`), borné à `[0, 1]`.
  ///
  /// Ce n'est pas le seuil : c'est la performance mesurée. Un examen sans
  /// question ([total] à `0`) vaut `0` — jamais une division par zéro.
  final double ratio;

  /// Nombre de réponses comptées correctes par le scoring, tel quel.
  final int correct;

  /// Nombre de réponses présentées, tel quel.
  final int total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZWhiteExamVerdict &&
          runtimeType == other.runtimeType &&
          passed == other.passed &&
          ratio == other.ratio &&
          correct == other.correct &&
          total == other.total;

  @override
  int get hashCode => Object.hash(passed, ratio, correct, total);

  @override
  String toString() =>
      'ZWhiteExamVerdict(passed: $passed, ratio: $ratio, correct: $correct, '
      'total: $total)';
}

/// Calcule le verdict d'un [result] d'examen blanc face au seuil
/// [successRatio] déclaré par l'application.
///
/// Rend `null` — « aucun verdict » — dans trois cas, et c'est le défaut :
///
/// - [successRatio] est `null` : l'application n'a déclaré aucun seuil, le
///   socle n'en invente pas ;
/// - [successRatio] n'est pas un nombre (`NaN`) : une valeur inexploitable ne
///   produit pas un échec silencieux ;
/// - [result] est `null` : l'examen n'est pas soumis, il n'y a rien à juger.
///
/// Normalisation défensive (invariant AD-10) — la fonction ne lève jamais :
///
/// - [successRatio] est borné à `[0, 1]` (`1.4` vaut `1`, `-0.2` vaut `0`,
///   l'infini vaut la borne correspondante) ;
/// - `ratio` vaut `correct / total`, borné à `[0, 1]` : `total <= 0` donne
///   `0` (aucune division par zéro), un `correct` supérieur au `total` — une
///   incohérence de données — donne `1`, jamais un taux au-dessus de 1 ;
/// - la comparaison est **large** : atteindre exactement le seuil réussit.
///
/// Fonction pure et déterministe : mêmes entrées, même verdict.
ZWhiteExamVerdict? zWhiteExamVerdictFor(
  ZStudySessionResult? result, {
  double? successRatio,
}) {
  if (result == null) return null;
  if (successRatio == null || successRatio.isNaN) return null;
  final threshold = zClampSuccessRatio(successRatio)!;
  final total = result.total;
  final correct = result.correct;
  final ratio = total <= 0 ? 0.0 : (correct / total).clamp(0.0, 1.0);
  return ZWhiteExamVerdict(
    passed: ratio >= threshold,
    ratio: ratio,
    correct: correct,
    total: total,
  );
}

/// Borne un seuil de réussite déclaré par l'hôte à `[0, 1]`.
///
/// Rend `null` si [successRatio] est `null` ou n'est pas un nombre (`NaN`) —
/// dans les deux cas, aucun seuil n'est exploitable et aucun verdict ne sera
/// rendu. Ne lève jamais (invariant AD-10).
double? zClampSuccessRatio(double? successRatio) {
  if (successRatio == null || successRatio.isNaN) return null;
  return successRatio.clamp(0.0, 1.0).toDouble();
}
