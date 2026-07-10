/// Implémentation `ZSm2Scheduler` — SuperMemo-2 par défaut (Story E9-2,
/// AC4/AC6 ; FR-17).
///
/// origine: lex_core (module « Étude ») — `Sm2` (canonique §2.1, l.75),
/// variante IFFD (clamp des DEUX bornes de `easeFactor`). Pur, sans état,
/// horloge injectée (AD-14) ; toutes les constantes lues depuis un
/// [ZSrsConfig] injecté (AC5 : aucune constante en dur dans l'algorithme).
///
/// **Précédent** : classe d'algorithme pure du monorepo à l'image de
/// `ZMindmapTreeOps` (E10-1) — fonctions pures retournant de **nouvelles**
/// structures, jamais de mutation en place.
library;

import 'z_repetition_info.dart';
import 'z_srs_config.dart';
import 'z_srs_scheduler.dart';

/// Planificateur SuperMemo-2 (implémentation par défaut de [ZSrsScheduler]).
///
/// Sans état : une même instance est réutilisable sur toutes les cartes. Toute
/// la logique est fonction pure de `(current, quality, now, config)`.
class ZSm2Scheduler implements ZSrsScheduler {
  /// Construit un scheduler SM-2 paramétré par [config] (défaut
  /// `const ZSrsConfig()`, constantes canoniques).
  const ZSm2Scheduler({this.config = const ZSrsConfig()});

  /// Constantes injectées (bornes `easeFactor`, seuil de réussite, modificateur
  /// d'intervalle…). Aucune constante SM-2 n'est codée en dur ailleurs.
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

  @override
  ZRepetitionInfo apply(ZRepetitionInfo current, int quality, {DateTime? now}) {
    // Horloge injectée, jamais capturée à la construction (AD-14).
    final effectiveNow = now ?? DateTime.now();
    // Clamp défensif de la qualité `0..5` — jamais de throw (AC6).
    final q = quality.clamp(0, 5);

    // Mise à jour du facteur de facilité (formule SM-2), appliquée QUELLE QUE
    // SOIT l'issue, puis bornée aux DEUX bornes de la config (variante IFFD).
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
        interval =
            (current.interval * easeFactor * config.defaultIntervalModifier)
                .round();
      }
    } else {
      // Lapse : on repart de zéro (compteur), intervalle minimal.
      repetitions = 0;
      interval = 1;
    }

    // `learnedAt` fixé à la PREMIÈRE réussite, JAMAIS remis à `null` (AC4).
    final learnedAt = current.learnedAt ?? (passed ? effectiveNow : null);
    final nextReviewDate = effectiveNow.add(Duration(days: interval));

    // Reconstruction via le primitif de bas niveau (aucune formule ici : l'état
    // est déjà calculé). Les canaux hors-SRS (extension/extra) sont préservés.
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
      // aucun état persisté ici — la persistance réelle est E9-4).
      apply(current, quality, now: now);
}
