// Story ES-9.1 — `ZEducationQuotaInfo` : fail-open (AC3), désérialisation
// défensive + round-trip DISCRIMINANT (AC4, R26). Runner R14 : `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  group('AC3 — fail-open (indisponible ⇒ autorisé, seul remaining<=0 bloque)', () {
    test('quota indisponible (unavailable) ⇒ allowsRequest == true', () {
      // R3-I3 : si allowsRequest retournait false quand tout est null, RC=1.
      expect(const ZEducationQuotaInfo.unavailable().allowsRequest, isTrue);
    });

    test('tous champs null (constructeur) ⇒ allowsRequest == true', () {
      expect(const ZEducationQuotaInfo().allowsRequest, isTrue);
    });

    test('remaining == 0 ⇒ bloqué (allowsRequest == false)', () {
      expect(
        const ZEducationQuotaInfo(limit: 100, remaining: 0, resetSeconds: 60)
            .allowsRequest,
        isFalse,
      );
    });

    test('remaining < 0 ⇒ bloqué', () {
      expect(const ZEducationQuotaInfo(remaining: -3).allowsRequest, isFalse);
    });

    test('remaining > 0 ⇒ autorisé', () {
      expect(const ZEducationQuotaInfo(remaining: 5).allowsRequest, isTrue);
    });

    test('remaining null avec limit/reset présents ⇒ autorisé (fail-open)', () {
      expect(
        const ZEducationQuotaInfo(limit: 100, resetSeconds: 30).allowsRequest,
        isTrue,
      );
    });
  });

  group('AC4 — désérialisation défensive (jamais de throw, AD-10)', () {
    test('fromJson(null) ⇒ unavailable, pas de throw', () {
      expect(ZEducationQuotaInfo.fromJson(null),
          const ZEducationQuotaInfo.unavailable());
    });

    test('fromJson(non-map) ⇒ unavailable', () {
      expect(ZEducationQuotaInfo.fromJson('abc'),
          const ZEducationQuotaInfo.unavailable());
      expect(ZEducationQuotaInfo.fromJson(42),
          const ZEducationQuotaInfo.unavailable());
      expect(ZEducationQuotaInfo.fromJson(<int>[1, 2]),
          const ZEducationQuotaInfo.unavailable());
    });

    test('valeurs non-numériques ⇒ champ null (repli sûr, pas de throw)', () {
      final q = ZEducationQuotaInfo.fromJson(<String, dynamic>{
        'limit': 'abc',
        'remaining': true,
        'reset_seconds': <int>[1],
      });
      expect(q.limit, isNull);
      expect(q.remaining, isNull);
      expect(q.resetSeconds, isNull);
      // Aucune info lisible ⇒ fail-open.
      expect(q.allowsRequest, isTrue);
    });

    test('coercion défensive: String numérique et num ⇒ int', () {
      final q = ZEducationQuotaInfo.fromJson(<String, dynamic>{
        'limit': '100',
        'remaining': 7.0,
        'reset_seconds': ' 30 ',
      });
      expect(q.limit, 100);
      expect(q.remaining, 7);
      expect(q.resetSeconds, 30);
    });

    test('fromHeaders: noms de header INJECTÉS, défensif', () {
      final q = ZEducationQuotaInfo.fromHeaders(
        <String, String>{'lim': '50', 'rem': '0', 'rst': '120'},
        limitKey: 'lim',
        remainingKey: 'rem',
        resetKey: 'rst',
      );
      expect(q.limit, 50);
      expect(q.remaining, 0);
      expect(q.resetSeconds, 120);
      expect(q.allowsRequest, isFalse); // remaining==0 connu ⇒ bloqué.
    });

    test('fromHeaders(null) ⇒ unavailable (fail-open)', () {
      final q = ZEducationQuotaInfo.fromHeaders(
        null,
        limitKey: 'lim',
        remainingKey: 'rem',
        resetKey: 'rst',
      );
      expect(q, const ZEducationQuotaInfo.unavailable());
      expect(q.allowsRequest, isTrue);
    });
  });

  group('AC4 — round-trip EXACT DISCRIMINANT (R26 : les 3 champs survivent)', () {
    // R3-I4 : un toJson qui OMET resetSeconds fait ROUGIR ces cas (le champ
    // non-null n'est pas restitué ⇒ != q). Chaque cas inclut au moins un champ
    // NON dégénéré (non-null) à préserver.
    final cases = <ZEducationQuotaInfo>[
      const ZEducationQuotaInfo(limit: 100, remaining: 42, resetSeconds: 3600),
      // Un SEUL champ non-null : discrimine la perte de resetSeconds (R3-I4).
      const ZEducationQuotaInfo(resetSeconds: 3600),
      const ZEducationQuotaInfo(limit: 100),
      const ZEducationQuotaInfo(remaining: 0),
      // Deux null, un non-null au milieu.
      const ZEducationQuotaInfo(remaining: 7),
      const ZEducationQuotaInfo.unavailable(),
    ];

    for (final q in cases) {
      test('fromJson(toJson()) == $q (préservation byte-à-byte, null inclus)',
          () {
        final restored = ZEducationQuotaInfo.fromJson(q.toJson());
        expect(restored, equals(q));
        // Assertion champ-par-champ (garde la perte silencieuse impossible).
        expect(restored.limit, q.limit);
        expect(restored.remaining, q.remaining);
        expect(restored.resetSeconds, q.resetSeconds);
      });
    }
  });
}
