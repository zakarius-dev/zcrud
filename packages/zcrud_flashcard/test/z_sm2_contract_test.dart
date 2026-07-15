/// CONTRAT SM-2 GELÉ (Story ES-4.1, résolution différée OQ-S3 / AD-22).
///
/// Ce fichier est le **verrou exécutable** de la formule SuperMemo-2 canonique
/// portée par `ZSm2Scheduler` (livrée E9-2, déclarée canonique par AD-22). Il est
/// **DISTINCT** de `z_srs_scheduler_test.dart` : ce dernier teste des PROPRIÉTÉS
/// (monotonie, bornes, remplaçabilité) ; CE fichier fige une **TABLE DE VECTEURS
/// DÉTERMINISTES** (golden numérique) liant `(état initial, qualité, now) →
/// (interval, repetitions, easeFactor, nextReviewDate, learnedAt, lastQuality)`.
///
/// **Raison d'être** : rendre IMPOSSIBLE à merger tout « petit ajustement » de la
/// formule (une constante EF, un keying d'intervalle, un clamp) sans casser un
/// vecteur rouge — ce serait une **régression de planification** pour les
/// utilisateurs existants (le pire résultat possible ; cf. Story ES-4.1 §D1/D5).
/// Par défaut cette story ne change RIEN au comportement du scheduler.
///
/// ── Formule canonique GELÉE (ZSm2Scheduler.apply — MESURÉE l.44-98) ──────────
///   q          = quality.clamp(0, 5)                         (jamais de throw)
///   rawEase    = EF + (0.1 - (5-q)*(0.08 + (5-q)*0.02))      (recalcul À CHAQUE
///                                                             appel, lapse compris)
///   EF'        = rawEase.clamp(minEaseFactor, maxEaseFactor) (les DEUX bornes,
///                                                             lues de la config)
///   passed     = q >= passThreshold (défaut 3)
///   si passed :  rep' = rep+1 ; interval' = { rep==0 → 1 ; rep==1 → 6 ;
///                sinon round(interval * EF' * defaultIntervalModifier) }
///   sinon (lapse) : rep' = 0 ; interval' = 1
///   learnedAt' = learnedAt ?? (passed ? now : null)          (JAMAIS re-null)
///   next'      = now + interval' jours
///
/// ── Divergences MESURÉES vs lex `Sm2`, documentées (AD-22, story §D3/D4) ─────
///   • bonus overdue de lex : NON porté (SM-2 pur) — `overdueBonusFactor` inerte.
///   • portée `intervalModifier` : zcrud l'applique SEULEMENT à la branche
///     multiplicative (rep≥2), lex à tous les régimes. Identiques au défaut 1.0.
///
/// Horloge fixée `DateTime.utc(...)` — AUCUN `DateTime.now()` (déterminisme).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Horloge de référence GELÉE (UTC) — toutes les échéances en sont relatives.
final DateTime kNow = DateTime.utc(2026, 1, 1);

/// Tolérance de comparaison des `easeFactor` : absorbe la représentation binaire
/// des littéraux décimaux (ex. `2.36`) SANS éroder le pouvoir discriminant — la
/// moindre dérive RÉELLE de la formule décale l'EF d'au moins `0.01` (100 000×
/// l'epsilon). Un vecteur qui « passe » à cet epsilon a donc bien la valeur
/// canonique figée, pas une valeur voisine.
Matcher ef(double v) => moreOrLessEquals(v, epsilon: 1e-9);

void main() {
  const scheduler = ZSm2Scheduler();

  ZRepetitionInfo fresh() =>
      scheduler.initial(flashcardId: 'c', folderId: 'f');

  // ───────────────────────────────────────────────────────────────────────────
  // AC2 — CONTRAT « première révision » gelé.
  // Depuis `initial()` (EF=2.5, rep=0, interval=0), un unique `apply(q)` à kNow.
  // EF recalculé depuis 2.5 : 2.5 + (0.1 - (5-q)*(0.08 + (5-q)*0.02)) puis clamp.
  //   q=5 → 2.6  → clamp 2.5   q=4 → 2.5           q=3 → 2.36
  //   q=2 → 2.18                q=1 → 1.96          q=0 → 1.70
  // Passed ⇔ q≥3 : palier « rep==0 → interval 1 ». Lapse (q<3) : interval 1, rep 0.
  // ───────────────────────────────────────────────────────────────────────────
  group('AC2 — contrat première révision (golden figé)', () {
    test('q=5 → interval 1, rep 1, EF 2.5, learnedAt=kNow, lastQuality 5', () {
      final r = scheduler.apply(fresh(), 5, now: kNow);
      expect(r.interval, 1);
      expect(r.repetitions, 1);
      expect(r.easeFactor, ef(2.5)); // 2.6 clampé au plafond.
      expect(r.nextReviewDate, kNow.add(const Duration(days: 1)));
      expect(r.learnedAt, kNow);
      expect(r.lastQuality, 5);
    });

    test('q=4 → interval 1, rep 1, EF 2.5 (raw 2.5, non abaissé)', () {
      final r = scheduler.apply(fresh(), 4, now: kNow);
      expect(r.interval, 1);
      expect(r.repetitions, 1);
      expect(r.easeFactor, ef(2.5));
      expect(r.learnedAt, kNow);
      expect(r.lastQuality, 4);
    });

    test('q=3 → interval 1, rep 1, EF 2.36 (décroissance depuis 2.5)', () {
      final r = scheduler.apply(fresh(), 3, now: kNow);
      expect(r.interval, 1);
      expect(r.repetitions, 1);
      expect(r.easeFactor, ef(2.36)); // 2.5 - 0.14.
      expect(r.easeFactor, lessThan(2.5));
      expect(r.learnedAt, kNow); // 1re réussite.
      expect(r.lastQuality, 3);
    });

    test('q=2 → LAPSE : rep 0, interval 1, learnedAt null, EF 2.18', () {
      final r = scheduler.apply(fresh(), 2, now: kNow);
      expect(r.repetitions, 0);
      expect(r.interval, 1);
      expect(r.learnedAt, isNull);
      expect(r.easeFactor, ef(2.18)); // 2.5 - 0.32 (recalcul même sur lapse).
      expect(r.nextReviewDate, kNow.add(const Duration(days: 1)));
      expect(r.lastQuality, 2);
    });

    test('q=1 → LAPSE : rep 0, interval 1, learnedAt null, EF 1.96', () {
      final r = scheduler.apply(fresh(), 1, now: kNow);
      expect(r.repetitions, 0);
      expect(r.interval, 1);
      expect(r.learnedAt, isNull);
      expect(r.easeFactor, ef(1.96)); // 2.5 - 0.54.
      expect(r.lastQuality, 1);
    });

    test('q=0 → LAPSE : rep 0, interval 1, learnedAt null, EF 1.70', () {
      final r = scheduler.apply(fresh(), 0, now: kNow);
      expect(r.repetitions, 0);
      expect(r.interval, 1);
      expect(r.learnedAt, isNull);
      expect(r.easeFactor, ef(1.70)); // 2.5 - 0.80.
      expect(r.lastQuality, 0);
    });

    test('q∈{0,1,2} équivalents sur l\'issue de lapse (rep/interval/learnedAt)',
        () {
      final r0 = scheduler.apply(fresh(), 0, now: kNow);
      final r1 = scheduler.apply(fresh(), 1, now: kNow);
      final r2 = scheduler.apply(fresh(), 2, now: kNow);
      for (final r in <ZRepetitionInfo>[r0, r1, r2]) {
        expect(r.repetitions, 0);
        expect(r.interval, 1);
        expect(r.learnedAt, isNull);
        expect(r.nextReviewDate, kNow.add(const Duration(days: 1)));
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AC3 — CONTRAT « révisions successives » gelé (courbe q=5, EF plafonné 2.5).
  // interval : 1, 6, round(6×2.5)=15, round(15×2.5)=38, round(38×2.5)=95.
  // ───────────────────────────────────────────────────────────────────────────
  group('AC3 — contrat révisions successives q=5 (golden figé)', () {
    test('interval suit EXACTEMENT 1, 6, 15, 38, 95 ; rep 1..5 ; EF=2.5', () {
      const expectedIntervals = <int>[1, 6, 15, 38, 95];
      var info = fresh();
      for (var step = 0; step < expectedIntervals.length; step++) {
        info = scheduler.apply(info, 5, now: kNow);
        expect(info.interval, expectedIntervals[step],
            reason: 'pas ${step + 1} : interval attendu '
                '${expectedIntervals[step]}');
        expect(info.repetitions, step + 1);
        expect(info.easeFactor, ef(2.5)); // déjà au plafond, y reste.
        expect(info.nextReviewDate,
            kNow.add(Duration(days: expectedIntervals[step])));
        expect(info.learnedAt, kNow);
      }
    });

    test('EF CROÎT de +0.1/pas depuis un état abaissé puis PLAFONNE à 2.5', () {
      // Un q=3 abaisse EF à 2.36, puis suite de q=5 : 2.46, puis clamp 2.5.
      var info = scheduler.apply(fresh(), 3, now: kNow);
      expect(info.easeFactor, ef(2.36));

      info = scheduler.apply(info, 5, now: kNow);
      expect(info.easeFactor, ef(2.46)); // 2.36 + 0.1.

      info = scheduler.apply(info, 5, now: kNow);
      expect(info.easeFactor, ef(2.5)); // 2.56 clampé au plafond.

      info = scheduler.apply(info, 5, now: kNow);
      expect(info.easeFactor, ef(2.5)); // y demeure.
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AC4 — CONTRAT « reset sur échec (q<3) » gelé.
  // Depuis un état avancé (2× q=5 : rep=2, interval=6, EF=2.5, learnedAt=kNow),
  // apply(q=2) : rep 0, interval 1, learnedAt PRÉSERVÉ (kNow), EF 2.18, next kNow+1j.
  // ───────────────────────────────────────────────────────────────────────────
  group('AC4 — contrat reset sur échec q<3 (golden figé)', () {
    ZRepetitionInfo advanced() {
      var info = scheduler.apply(fresh(), 5, now: kNow); // rep1, interval1
      info = scheduler.apply(info, 5, now: kNow); // rep2, interval6
      return info;
    }

    test('état avancé de départ : rep 2, interval 6, EF 2.5, learnedAt=kNow', () {
      final a = advanced();
      expect(a.repetitions, 2);
      expect(a.interval, 6);
      expect(a.easeFactor, ef(2.5));
      expect(a.learnedAt, kNow);
    });

    test('apply(q=2) : rep 0, interval 1, learnedAt PRÉSERVÉ, EF 2.18', () {
      final r = scheduler.apply(advanced(), 2, now: kNow);
      expect(r.repetitions, 0);
      expect(r.interval, 1);
      expect(r.learnedAt, kNow); // JAMAIS remis à null (invariant AD-9/AC4).
      expect(r.easeFactor, ef(2.18)); // 2.5 - 0.32.
      expect(r.nextReviewDate, kNow.add(const Duration(days: 1)));
      expect(r.lastQuality, 2);
    });

    test('apply(q∈{0,1}) : même issue de reset, learnedAt préservé', () {
      for (final q in <int>[0, 1]) {
        final r = scheduler.apply(advanced(), q, now: kNow);
        expect(r.repetitions, 0, reason: 'q=$q');
        expect(r.interval, 1, reason: 'q=$q');
        expect(r.learnedAt, kNow, reason: 'q=$q learnedAt préservé');
        expect(r.lastQuality, q);
      }
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AC5 — CONTRAT « bornes EF » gelé (plancher 1.3 ET plafond 2.5), + preuve que
  // la borne est LUE DE LA CONFIG (variante custom 1.5).
  // ───────────────────────────────────────────────────────────────────────────
  group('AC5 — contrat bornes easeFactor (golden figé)', () {
    test('plancher : suite de q=3 s\'ancre EXACTEMENT à minEaseFactor=1.3', () {
      var info = fresh();
      // Décroissance -0.14/pas : 2.5→2.36→…→1.38→(1.24 clampé 1.3). ~12 pas suffisent.
      for (var i = 0; i < 12; i++) {
        info = scheduler.apply(info, 3, now: kNow);
        expect(info.easeFactor, greaterThanOrEqualTo(1.3));
      }
      expect(info.easeFactor, 1.3); // ancré EXACTEMENT au plancher (clamp).
    });

    test('plafond : defaultEaseFactor=2.5=maxEaseFactor ⇒ q=5 ne dépasse pas 2.5',
        () {
      var info = fresh();
      for (var i = 0; i < 8; i++) {
        info = scheduler.apply(info, 5, now: kNow);
        expect(info.easeFactor, lessThanOrEqualTo(2.5));
      }
      expect(info.easeFactor, 2.5);
    });

    test('config custom minEaseFactor=1.5 ⇒ le plancher devient 1.5 (lu config)',
        () {
      const custom = ZSm2Scheduler(config: ZSrsConfig(minEaseFactor: 1.5));
      var info = custom.initial(flashcardId: 'c', folderId: 'f');
      for (var i = 0; i < 12; i++) {
        info = custom.apply(info, 3, now: kNow);
        expect(info.easeFactor, greaterThanOrEqualTo(1.5));
      }
      // Prouve que le clamp lit `config.minEaseFactor` (1.5), PAS un littéral 1.3.
      expect(info.easeFactor, 1.5);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AC6 — Qualité clampée 0..5, AUCUN throw, gelée.
  // ───────────────────────────────────────────────────────────────────────────
  group('AC6 — contrat qualité 0..5 défensive (golden figé)', () {
    test('apply(-100) ≡ apply(0) (états EXACTEMENT égaux, lastQuality 0)', () {
      final neg = scheduler.apply(fresh(), -100, now: kNow);
      final zero = scheduler.apply(fresh(), 0, now: kNow);
      expect(neg, zero);
      expect(neg.lastQuality, 0);
    });

    test('apply(1000) ≡ apply(5) (états EXACTEMENT égaux, lastQuality 5)', () {
      final big = scheduler.apply(fresh(), 1000, now: kNow);
      final five = scheduler.apply(fresh(), 5, now: kNow);
      expect(big, five);
      expect(big.lastQuality, 5);
    });

    test('aucune exception pour toute qualité hors bornes (apply ET simulate)',
        () {
      final info = fresh();
      expect(() => scheduler.apply(info, -100, now: kNow), returnsNormally);
      expect(() => scheduler.apply(info, 1000, now: kNow), returnsNormally);
      expect(() => scheduler.simulate(info, -100, now: kNow), returnsNormally);
      expect(() => scheduler.simulate(info, 1000, now: kNow), returnsNormally);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AC7 — Voie d'écriture SRS UNIQUE réaffirmée (AD-9).
  //   (b) simulate == apply, source non mutée ;
  //   (c) withFolder PRÉSERVE à l'identique tous les champs d'ordonnancement ;
  //   (d) ZRepetitionInfo n'expose aucun copyWith/setter SRS public (hide barrel).
  // ───────────────────────────────────────────────────────────────────────────
  group('AC7 — contrat voie d\'écriture unique (golden figé)', () {
    test('simulate == apply et la source N\'EST PAS mutée', () {
      final info = fresh();
      final sim = scheduler.simulate(info, 4, now: kNow);
      final app = scheduler.apply(info, 4, now: kNow);
      expect(sim, app);
      // Source intacte : preuve d'immuabilité (projection pure).
      expect(info.repetitions, 0);
      expect(info.interval, 0);
      expect(info.lastQuality, isNull);
    });

    test('withFolder PRÉSERVE l\'ordonnancement (relocalisation, PAS avancement)',
        () {
      // État avancé non trivial.
      var info = scheduler.apply(fresh(), 5, now: kNow);
      info = scheduler.apply(info, 5, now: kNow);
      info = scheduler.apply(info, 5, now: kNow); // rep3, interval15, EF2.5
      final moved = info.withFolder('autre-dossier');

      // Seul folderId change ; TOUS les champs d'ordonnancement sont identiques.
      expect(moved.folderId, 'autre-dossier');
      expect(moved.flashcardId, info.flashcardId);
      expect(moved.interval, info.interval);
      expect(moved.repetitions, info.repetitions);
      expect(moved.easeFactor, info.easeFactor);
      expect(moved.nextReviewDate, info.nextReviewDate);
      expect(moved.learnedAt, info.learnedAt);
      expect(moved.lastQuality, info.lastQuality);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AC9 — (dé)sérialisation défensive SANS scheduler (AD-10), non-régression.
  // Ne DUPLIQUE PAS les groupes défensifs de z_repetition_info_test.dart : un
  // seul vecteur de contrat prouve (a) le round-trip d'un état AVANCÉ ne recalcule
  // rien (toMap→fromMap = identité sur les champs SRS) et (b) un état persisté
  // corrompu ne fait pas throw.
  // ───────────────────────────────────────────────────────────────────────────
  group('AC9 — (dé)sérialisation défensive sans scheduler (golden figé)', () {
    test('round-trip toMap→fromMap d\'un état avancé = identité (aucun recalcul)',
        () {
      var info = scheduler.apply(fresh(), 5, now: kNow);
      info = scheduler.apply(info, 5, now: kNow);
      info = scheduler.apply(info, 5, now: kNow); // rep3, interval15, EF2.5

      final round = ZRepetitionInfo.fromMap(info.toMap());
      // Aucun scheduler invoqué à la (dé)sérialisation : l'état est reconstruit
      // TEL QUEL (mêmes interval/rep/EF/dates) — pas de dérive.
      expect(round.interval, 15);
      expect(round.repetitions, 3);
      expect(round.easeFactor, ef(2.5));
      expect(round.nextReviewDate, info.nextReviewDate);
      expect(round.learnedAt, info.learnedAt);
      expect(round.lastQuality, 5);
      expect(round, info);
    });

    test('état persisté CORROMPU (ease non-numérique, compteurs négatifs) : '
        'pas de throw, défauts sûrs', () {
      final corrupt = <String, dynamic>{
        'flashcard_id': 'c',
        'folder_id': 'f',
        'interval': -7,
        'repetitions': -3,
        'ease_factor': 'not-a-number',
      };
      late ZRepetitionInfo r;
      expect(() => r = ZRepetitionInfo.fromMap(corrupt), returnsNormally);
      expect(r.interval, 0); // compteur négatif sanitisé.
      expect(r.repetitions, 0);
      expect(r.easeFactor, ZSrsConfig.kDefaultEaseFactor); // repli 2.5.
    });
  });
}
