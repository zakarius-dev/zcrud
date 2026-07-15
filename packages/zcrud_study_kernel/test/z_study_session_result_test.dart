/// Tests `ZStudySessionResult` (ES-2.7, AC1–AC4) — VO pur, round-trip défensif,
/// égalité `byQuality` COMMUTATIVE.
///
/// Littéraux JS-safe, **aucun `dart:io`** ⇒ tourne sous `dart test` ET
/// `dart test -p node` (`gate:web` default-ON, AC15).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('AC1 — value-object PUR (défauts)', () {
    test('constructeur `const` : défauts spaced/0/0/{}', () {
      const r = ZStudySessionResult();
      expect(r.mode, ZReviewMode.spaced);
      expect(r.total, 0);
      expect(r.correct, 0);
      expect(r.byQuality, <String, int>{});
    });
  });

  group('AC2 — `fromMap` défensif et TOTAL (AD-10, D6)', () {
    test('R2 — fromMap(const {}) ne throw JAMAIS et rend les défauts', () {
      final r = ZStudySessionResult.fromMap(const <String, dynamic>{});
      expect(r.mode, ZReviewMode.spaced);
      expect(r.total, 0);
      expect(r.correct, 0);
      expect(r.byQuality, <String, int>{});
    });

    test('R2 — champs corrompus retombent sur défauts sûrs', () {
      final r = ZStudySessionResult.fromMap(const <String, dynamic>{
        'total': -3, // négatif → 0 (clamp)
        'correct': 'x', // non-numérique → 0
        'mode': 'inconnu', // inconnu → spaced
        'by_quality': 42, // non-Map → {}
      });
      expect(r.total, 0);
      expect(r.correct, 0);
      expect(r.mode, ZReviewMode.spaced);
      expect(r.byQuality, <String, int>{});
    });

    test('R2 — by_quality : niveau 2, valeur non-int IGNORÉE (pas de nettoyage)',
        () {
      final r = ZStudySessionResult.fromMap(const <String, dynamic>{
        'by_quality': <String, dynamic>{'0': 2, '5': 'nan', '3': 4},
      });
      // La paire '5' (valeur non-int) est ignorée ; les autres survivent.
      expect(r.byQuality, <String, int>{'0': 2, '3': 4});
    });

    test('mode/total/correct bien-formés décodés verbatim', () {
      final r = ZStudySessionResult.fromMap(const <String, dynamic>{
        'mode': 'whiteExam',
        'total': 20,
        'correct': 13,
        'by_quality': <String, dynamic>{'0': 1, '2': 3, '5': 9},
      });
      expect(r.mode, ZReviewMode.whiteExam);
      expect(r.total, 20);
      expect(r.correct, 13);
      expect(r.byQuality, <String, int>{'0': 1, '2': 3, '5': 9});
    });

    test('byQuality issu de fromMap est NON MODIFIABLE (immuabilité)', () {
      final r = ZStudySessionResult.fromMap(const <String, dynamic>{
        'by_quality': <String, dynamic>{'0': 1},
      });
      expect(() => r.byQuality['1'] = 2, throwsUnsupportedError);
    });
  });

  group('AC3 — round-trip Map idempotent + pouvoir discriminant (anti-golden)',
      () {
    test('fromMap(r.toMap()) == r (instance bien formée)', () {
      const r = ZStudySessionResult(
        mode: ZReviewMode.whiteExam,
        total: 20,
        correct: 13,
        byQuality: <String, int>{'0': 1, '2': 3, '5': 9},
      );
      expect(ZStudySessionResult.fromMap(r.toMap()), r);
    });

    test('toMap émet snake_case + enum camelCase', () {
      const r = ZStudySessionResult(
        mode: ZReviewMode.whiteExam,
        total: 20,
        correct: 13,
        byQuality: <String, int>{'0': 1},
      );
      expect(r.toMap(), <String, dynamic>{
        'mode': 'whiteExam',
        'total': 20,
        'correct': 13,
        'by_quality': <String, int>{'0': 1},
      });
    });

    test('POUVOIR DISCRIMINANT — faire varier `correct` rend INÉGAL', () {
      const base = ZStudySessionResult(
        mode: ZReviewMode.whiteExam,
        total: 20,
        correct: 13,
        byQuality: <String, int>{'0': 1, '2': 3, '5': 9},
      );
      const varie = ZStudySessionResult(
        mode: ZReviewMode.whiteExam,
        total: 20,
        correct: 12, // ← un seul champ change
        byQuality: <String, int>{'0': 1, '2': 3, '5': 9},
      );
      // Prouve que `==` dépend RÉELLEMENT de `correct` (pas un `true` fortuit).
      expect(base == varie, isFalse);
    });
  });

  group('AC4 — égalité `byQuality` COMMUTATIVE sur les clés (D7)', () {
    test('mêmes paires, ordre de clés différent ⇒ ÉGAUX + même hashCode', () {
      const a = ZStudySessionResult(
        mode: ZReviewMode.spaced,
        total: 5,
        correct: 3,
        byQuality: <String, int>{'0': 1, '5': 2},
      );
      const b = ZStudySessionResult(
        mode: ZReviewMode.spaced,
        total: 5,
        correct: 3,
        byQuality: <String, int>{'5': 2, '0': 1}, // ordre d'insertion inversé
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('les VALEURS comptent : {0:1} != {0:2}', () {
      const a = ZStudySessionResult(byQuality: <String, int>{'0': 1});
      const b = ZStudySessionResult(byQuality: <String, int>{'0': 2});
      expect(a == b, isFalse);
    });

    test('les CLÉS comptent : {0:1} != {1:1}', () {
      const a = ZStudySessionResult(byQuality: <String, int>{'0': 1});
      const b = ZStudySessionResult(byQuality: <String, int>{'1': 1});
      expect(a == b, isFalse);
    });
  });
}
