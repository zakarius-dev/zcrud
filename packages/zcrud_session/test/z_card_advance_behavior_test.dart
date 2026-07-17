/// AC8 — `zDefaultAdvanceBehavior` : TABLE UNIQUE des défauts par mode (FR-SU5).
///
/// Test **PUR** (aucun widget) : la table est une fonction pure.
///
/// ⚠️ Aucun `expect` ne passe par une table locale de test (défaut D5 de su-1) :
/// tout traverse la VRAIE `zDefaultAdvanceBehavior` du barrel public. Un test
/// qui ré-écrirait la table qu'il vérifie resterait vert quoi qu'il arrive.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('AC8 — 6 cas, un par ZReviewMode (table UNIQUE)', () {
    test('test ⇒ auto (mode chronométré)', () {
      expect(
        zDefaultAdvanceBehavior(ZReviewMode.test),
        ZCardAdvanceBehavior.auto,
      );
    });

    test('whiteExam ⇒ auto (mode chronométré)', () {
      expect(
        zDefaultAdvanceBehavior(ZReviewMode.whiteExam),
        ZCardAdvanceBehavior.auto,
      );
    });

    test('spaced ⇒ manual (on lit la correction)', () {
      expect(
        zDefaultAdvanceBehavior(ZReviewMode.spaced),
        ZCardAdvanceBehavior.manual,
      );
    });

    test('learn ⇒ manual (on lit la correction)', () {
      expect(
        zDefaultAdvanceBehavior(ZReviewMode.learn),
        ZCardAdvanceBehavior.manual,
      );
    });

    test('list ⇒ manual (consultation)', () {
      expect(
        zDefaultAdvanceBehavior(ZReviewMode.list),
        ZCardAdvanceBehavior.manual,
      );
    });

    test('cramming ⇒ manual (bachotage : on relit)', () {
      expect(
        zDefaultAdvanceBehavior(ZReviewMode.cramming),
        ZCardAdvanceBehavior.manual,
      );
    });
  });

  group('AC8 — la table est TOTALE et DÉTERMINISTE', () {
    test('les 6 valeurs RÉELLES de l\'enum sont couvertes, sans exception', () {
      // Itère sur `ZReviewMode.values` (la source de vérité) plutôt que sur une
      // liste recopiée : si un 7ᵉ mode apparaît, ce test l'exerce
      // automatiquement — et la fonction, `switch` exhaustif SANS `default`,
      // aura de toute façon cassé la COMPILATION avant d'arriver ici.
      expect(ZReviewMode.values, hasLength(6));
      for (final mode in ZReviewMode.values) {
        expect(
          () => zDefaultAdvanceBehavior(mode),
          returnsNormally,
          reason: 'aucun mode ne doit lever (AD-10)',
        );
      }
    });

    test('exactement 2 modes sont `auto` — les modes CHRONOMÉTRÉS', () {
      // Garde de PARTITION : elle rougit aussi bien si un mode `auto` devient
      // `manual` que l'inverse — y compris pour un futur 7ᵉ mode mal classé.
      final auto = ZReviewMode.values
          .where((m) => zDefaultAdvanceBehavior(m) == ZCardAdvanceBehavior.auto)
          .toSet();
      expect(auto, <ZReviewMode>{ZReviewMode.test, ZReviewMode.whiteExam});
    });

    test('la table est PURE : deux appels rendent le même résultat', () {
      for (final mode in ZReviewMode.values) {
        expect(zDefaultAdvanceBehavior(mode), zDefaultAdvanceBehavior(mode));
      }
    });
  });

  group('ZCardAdvanceBehavior / ZTimerDisplay — enums, jamais des booléens', () {
    test('ZCardAdvanceBehavior porte exactement {auto, manual}', () {
      expect(
        ZCardAdvanceBehavior.values,
        <ZCardAdvanceBehavior>[
          ZCardAdvanceBehavior.auto,
          ZCardAdvanceBehavior.manual,
        ],
      );
    });

    test('ZTimerDisplay porte exactement {hidden, elapsed, countdown}', () {
      // 3 valeurs : un booléen ne pourrait pas les représenter — d'où l'enum.
      expect(
        ZTimerDisplay.values,
        <ZTimerDisplay>[
          ZTimerDisplay.hidden,
          ZTimerDisplay.elapsed,
          ZTimerDisplay.countdown,
        ],
      );
    });
  });
}
