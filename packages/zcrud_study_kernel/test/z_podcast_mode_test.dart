/// AC9 — `ZPodcastMode` : décodage DÉFENSIF, **ordre normatif** (D3, `simple` en
/// tête). ES-2.8, FR-S11. Aucun `dart:io` (JS-safe).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  ZPodcastMode decode(Object? raw) =>
      ZStudyPodcast.fromMap(<String, dynamic>{'mode': raw}).mode;

  group('ZPodcastMode — D3 : l\'ORDRE DE DÉCLARATION est NORMATIF', () {
    test('la 1ʳᵉ constante EST `simple` (= repli défensif + parité lex)', () {
      expect(ZPodcastMode.values.first, ZPodcastMode.simple);
      expect(
        ZPodcastMode.values.map((m) => m.name).toList(),
        <String>['simple', 'dialogue'],
      );
    });
  });

  group('AC9 — décodage DÉFENSIF du mode (AD-10)', () {
    test('valeur connue conservée', () {
      expect(decode('simple'), ZPodcastMode.simple);
      expect(decode('dialogue'), ZPodcastMode.dialogue);
    });

    test('absent / null / non-String / inconnu ⇒ simple (1ʳᵉ constante)', () {
      expect(ZStudyPodcast.fromMap(const <String, dynamic>{}).mode,
          ZPodcastMode.simple);
      expect(decode(null), ZPodcastMode.simple);
      expect(decode(42), ZPodcastMode.simple);
      expect(decode('DIALOGUE'), ZPodcastMode.simple, reason: 'casse ≠');
      expect(decode('zz'), ZPodcastMode.simple);
    });
  });
}
