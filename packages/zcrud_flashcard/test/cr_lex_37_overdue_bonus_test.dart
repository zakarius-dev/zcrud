// CR-LEX-37 — `ZSm2Scheduler` n'appliquait AUCUN bonus de retard, alors que
// `ZSrsConfig.overdueBonusFactor` était déclaré : le réglage était INERTE, donc
// la parité avec un moteur SM-2 qui crédite le retard était impossible PAR
// RÉGLAGE — un hôte pouvait le régler à 5 sans le moindre effet.
//
// Une carte révisée en retard a été mémorisée PLUS longtemps que son intervalle
// ne le prévoyait : le retard est une information de rétention.
import 'package:test/test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// État de référence de la mesure lex : `interval:10, repetitions:5,
/// easeFactor:2.5`, échéance dépassée de 20 jours, `quality:4`.
ZRepetitionInfo _carte({required DateTime due}) => ZRepetitionInfo(
      flashcardId: 'c1',
      folderId: 'f1',
      interval: 10,
      repetitions: 5,
      easeFactor: 2.5,
      nextReviewDate: due,
    );

final DateTime _now = DateTime.utc(2026, 6, 1, 12);

void main() {
  group('🔴 CR-LEX-37 — le bonus de retard est APPLIQUÉ', () {
    test('l\'exemple mesuré par lex : 25 (base) + 10 (bonus) = 35', () async {
      // base = round(10 * 2.5 * 1.0) = 25
      // bonus = min(round(20 * 0.5), 25) = min(10, 25) = 10
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: 0.5),
      );
      final out = scheduler.apply(
        _carte(due: _now.subtract(const Duration(days: 20))),
        4,
        now: _now,
      );
      expect(out.interval, 35);
    });

    test('🔴 le réglage n\'est PLUS inerte — il change le résultat', () {
      // La preuve d'inertie de lex : `overdueBonusFactor: 5` rendait TOUJOURS 25.
      final carte = _carte(due: _now.subtract(const Duration(days: 20)));
      const sans = ZSm2Scheduler(config: ZSrsConfig());
      const fort = ZSm2Scheduler(config: ZSrsConfig(overdueBonusFactor: 5));
      expect(sans.apply(carte, 4, now: _now).interval, 25);
      expect(fort.apply(carte, 4, now: _now).interval, greaterThan(25),
          reason: 'un facteur élevé doit produire un intervalle plus long');
    });

    test('bornage ANTI-EXPLOSION : au pire, le retard DOUBLE l\'intervalle', () {
      // Carte oubliée un an, facteur énorme : le bonus est borné par la base.
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: 10),
      );
      final out = scheduler.apply(
        _carte(due: _now.subtract(const Duration(days: 365))),
        4,
        now: _now,
      );
      expect(out.interval, 50, reason: 'base 25 + bonus borné à 25 = 50');
    });
  });

  group('Le DÉFAUT ne change RIEN pour les consommateurs existants', () {
    test('🔴 défaut = 0.0 ⇒ aucun bonus (comportement historique)', () {
      // Le champ valait 0.5 mais était INERTE : le comportement réel était 0.0.
      // Le câbler en gardant 0.5 aurait modifié SILENCIEUSEMENT les intervalles
      // de tous les consommateurs, sur des données de production.
      expect(const ZSrsConfig().overdueBonusFactor, 0.0);
      const scheduler = ZSm2Scheduler(config: ZSrsConfig());
      final out = scheduler.apply(
        _carte(due: _now.subtract(const Duration(days: 20))),
        4,
        now: _now,
      );
      expect(out.interval, 25, reason: 'base seule, exactement comme avant');
    });

    test('carte à l\'heure ou en AVANCE : aucun bonus, quel que soit le facteur',
        () {
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: 0.5),
      );
      for (final due in <DateTime>[
        _now, // pile à l'heure
        _now.add(const Duration(days: 5)), // en avance
      ]) {
        expect(scheduler.apply(_carte(due: due), 4, now: _now).interval, 25,
            reason: 'échéance $due');
      }
    });

    test('jamais planifiée (`nextReviewDate` null) ⇒ aucun bonus', () {
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: 0.5),
      );
      final vierge = ZRepetitionInfo(
        flashcardId: 'c1',
        folderId: 'f1',
        interval: 10,
        repetitions: 5,
        easeFactor: 2.5,
      );
      expect(scheduler.apply(vierge, 4, now: _now).interval, 25);
    });
  });

  group('Le bonus ne déborde pas des régimes où il a un sens', () {
    test('régime d\'AMORÇAGE (repetitions 0 et 1) : intervalles fixes', () {
      // SM-2 impose 1 puis 6 : le retard n'y a aucune influence.
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: 0.5),
      );
      for (final MapEntry<int, int> cas in <int, int>{0: 1, 1: 6}.entries) {
        final carte = ZRepetitionInfo(
          flashcardId: 'c1',
          folderId: 'f1',
          interval: 10,
          repetitions: cas.key,
          easeFactor: 2.5,
          nextReviewDate: _now.subtract(const Duration(days: 100)),
        );
        expect(scheduler.apply(carte, 4, now: _now).interval, cas.value,
            reason: 'repetitions=${cas.key}');
      }
    });

    test('LAPSE (échec) : intervalle 1, le retard ne crédite rien', () {
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: 0.5),
      );
      final out = scheduler.apply(
        _carte(due: _now.subtract(const Duration(days: 100))),
        1, // sous le seuil de réussite
        now: _now,
      );
      expect(out.interval, 1,
          reason: 'un échec repart de zéro — le retard ne le rachète pas');
    });

    test('un facteur NÉGATIF ne raccourcit pas l\'intervalle (défensif)', () {
      const scheduler = ZSm2Scheduler(
        config: ZSrsConfig(overdueBonusFactor: -3),
      );
      expect(
        scheduler
            .apply(_carte(due: _now.subtract(const Duration(days: 20))), 4,
                now: _now)
            .interval,
        25,
      );
    });
  });
}
