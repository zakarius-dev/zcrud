/// Implémentation `ZSm2Scheduler` — SuperMemo-2 par défaut.
///
/// Pur, sans état, horloge injectée. Les constantes réglables (bornes de
/// facteur de facilité, seuil de réussite, modificateur d'intervalle, bornes
/// d'échelle) sont lues depuis un [ZSrsConfig] injecté — aucune n'est
/// recopiée ici.
///
/// Seule exception assumée : le sommet `5` de la formule de facteur de
/// facilité (`(5 - q)`) est intrinsèque à SM-2, pas un réglage — il est gelé
/// par un test de contrat dédié. Il n'est pas pour autant une seconde source
/// de vérité : `ZSrsConfig` épingle `maxQuality == 5` par assertion, si bien
/// que la configuration ne peut pas diverger de la formule.
library;

import 'z_repetition_info.dart';
import 'z_srs_config.dart';
import 'z_srs_scheduler.dart';

/// Planificateur SuperMemo-2 (implémentation par défaut de [ZSrsScheduler]).
///
/// Sans état : une même instance est réutilisable sur toutes les cartes.
/// Toute la logique est fonction pure de `(current, quality, now, config)`.
class ZSm2Scheduler implements ZSrsScheduler {
  /// Construit un scheduler SM-2 paramétré par [config] (défaut
  /// `const ZSrsConfig()`, constantes canoniques).
  const ZSm2Scheduler({this.config = const ZSrsConfig()});

  /// Constantes injectées (bornes `easeFactor`, seuil de réussite,
  /// modificateur d'intervalle…). Aucune constante SM-2 n'est codée en dur
  /// ailleurs.
  final ZSrsConfig config;

  @override
  ZRepetitionInfo initial({
    required String flashcardId,
    required String folderId,
  }) =>
      ZRepetitionInfo(
        flashcardId: flashcardId,
        folderId: folderId,
        interval: 0,
        repetitions: 0,
        easeFactor: config.defaultEaseFactor,
      );

  /// Bonus de retard — `0` si la carte est à l'heure ou en avance, si elle
  /// n'a jamais été planifiée, ou si le facteur de bonus est nul (le
  /// défaut).
  ///
  /// Formule : `min(round(joursDeRetard * overdueBonusFactor), base)`. Le
  /// bornage par [base] est anti-explosion : une carte oubliée six mois ne
  /// doit pas se voir attribuer un intervalle délirant — au pire, le retard
  /// double l'intervalle calculé.
  int _overdueBonus(ZRepetitionInfo current, DateTime now, int base) {
    if (config.overdueBonusFactor <= 0) return 0;
    final due = current.nextReviewDate;
    if (due == null) return 0;
    final overdueDays = now.difference(due).inDays;
    if (overdueDays <= 0) return 0;
    final bonus = (overdueDays * config.overdueBonusFactor).round();
    return bonus < base ? bonus : base;
  }

  @override
  ZRepetitionInfo apply(ZRepetitionInfo current, int quality, {DateTime? now}) {
    // Horloge injectée, jamais capturée à la construction.
    final effectiveNow = now ?? DateTime.now();
    // Clamp défensif de la qualité — jamais d'exception. Les bornes sont
    // lues depuis la config (source unique de l'échelle et du clamp) : une
    // valeur hors échelle venue d'un port d'évaluation est ramenée sur
    // l'échelle que le domaine déclare, jamais sur des bornes recopiées ici
    // — une seconde source divergerait en silence.
    final q = config.clampQuality(quality);

    // Mise à jour du facteur de facilité (formule SM-2), appliquée quelle
    // que soit l'issue, puis bornée aux deux bornes de la config.
    final rawEase =
        current.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
    final easeFactor =
        rawEase.clamp(config.minEaseFactor, config.maxEaseFactor).toDouble();

    final passed = q >= config.passThreshold;

    final int repetitions;
    final int interval;
    if (passed) {
      repetitions = current.repetitions + 1;
      if (current.repetitions == 0) {
        interval = 1;
      } else if (current.repetitions == 1) {
        interval = 6;
      } else {
        // Croissance : `interval * easeFactor * modificateur`, arrondi.
        final base =
            (current.interval * easeFactor * config.defaultIntervalModifier)
                .round();
        // Bonus de retard : une carte révisée en retard a été mémorisée
        // plus longtemps que son intervalle ne le prévoyait — le retard est
        // donc une information de rétention, créditée au prochain
        // intervalle si `overdueBonusFactor` est réglé.
        interval = base + _overdueBonus(current, effectiveNow, base);
      }
    } else {
      // Lapse : on repart de zéro (compteur), intervalle minimal.
      repetitions = 0;
      interval = 1;
    }

    // `learnedAt` fixé à la première réussite, jamais remis à `null`.
    final learnedAt = current.learnedAt ?? (passed ? effectiveNow : null);
    final nextReviewDate = effectiveNow.add(Duration(days: interval));

    // Reconstruction via le primitif de bas niveau (aucune formule ici :
    // l'état est déjà calculé). Les canaux hors SRS (extension/extra) sont
    // préservés.
    return ZRepetitionInfo(
      flashcardId: current.flashcardId,
      folderId: current.folderId,
      interval: interval,
      repetitions: repetitions,
      easeFactor: easeFactor,
      nextReviewDate: nextReviewDate,
      learnedAt: learnedAt,
      lastQuality: q,
      extension: current.extension,
      extra: current.extra,
    );
  }

  @override
  ZRepetitionInfo simulate(ZRepetitionInfo current, int quality,
          {DateTime? now}) =>
      // Projection sans effet de bord : identique à `apply` (fonction pure,
      // aucun état persisté ici).
      apply(current, quality, now: now);
}
