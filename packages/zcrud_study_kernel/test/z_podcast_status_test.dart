/// AC9 — `ZPodcastStatus` : décodage DÉFENSIF, **ordre normatif** (D3, `ready`
/// en tête). ES-2.8, FR-S11.
///
/// Aucun `dart:io` (JS-safe).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  ZPodcastStatus decode(Object? raw) =>
      ZStudyPodcast.fromMap(<String, dynamic>{'status': raw}).status;

  group('ZPodcastStatus — D3 : l\'ORDRE DE DÉCLARATION est NORMATIF', () {
    test('la 1ʳᵉ constante EST `ready` (= le repli défensif du codegen)', () {
      // 🔴 Le générateur décode un enum par NOM et, pour un champ non-nullable
      // sans `defaultValue`, son repli est `T.values.first`. Réordonner cet enum
      // (ex. `pending` en tête) changerait SILENCIEUSEMENT le comportement AD-10
      // de `ZStudyPodcast.status`. Ce test est le VERROU de cet ordre.
      expect(ZPodcastStatus.values.first, ZPodcastStatus.ready);
      expect(
        ZPodcastStatus.values.map((s) => s.name).toList(),
        <String>['ready', 'pending', 'processing', 'failed', 'stale'],
        reason: 'l\'ordre est NORMATIF (D3) — `ready` en tête préserve la '
            'sémantique de repli lex (`fromJson → ready`).',
      );
    });
  });

  group('AC9 — décodage DÉFENSIF du status (AD-10 : jamais de throw)', () {
    test('valeur connue conservée (anti-golden : pas « toujours le défaut »)',
        () {
      expect(decode('ready'), ZPodcastStatus.ready);
      expect(decode('pending'), ZPodcastStatus.pending);
      expect(decode('processing'), ZPodcastStatus.processing);
      expect(decode('failed'), ZPodcastStatus.failed);
      expect(decode('stale'), ZPodcastStatus.stale);
    });

    test('absent / null / non-String / inconnu ⇒ ready (1ʳᵉ constante)', () {
      expect(
        ZStudyPodcast.fromMap(const <String, dynamic>{}).status,
        ZPodcastStatus.ready,
        reason: 'clé absente',
      );
      expect(decode(null), ZPodcastStatus.ready);
      expect(decode(42), ZPodcastStatus.ready);
      expect(decode(<String, dynamic>{'x': 1}), ZPodcastStatus.ready);
      expect(decode('READY'), ZPodcastStatus.ready, reason: 'casse ≠');
      expect(decode('zz_inconnu'), ZPodcastStatus.ready);
    });

    test('aucune entrée ne fait THROW (AD-10)', () {
      for (final raw in <Object?>[
        null,
        42,
        -1,
        3.14,
        true,
        'zz',
        <String>['ready'],
        <String, dynamic>{},
      ]) {
        expect(() => decode(raw), returnsNormally, reason: 'raw = $raw');
      }
    });
  });
}
