/// AC9 — `ZPodcastSourceKind` : décodage DÉFENSIF, **ordre normatif** (D3, `note`
/// en tête). ES-2.8, FR-S11. Aucun `dart:io` (JS-safe).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  ZPodcastSourceKind decode(Object? raw) =>
      ZStudyPodcast.fromMap(<String, dynamic>{'source_kind': raw}).sourceKind;

  group('ZPodcastSourceKind — D3 : l\'ORDRE DE DÉCLARATION est NORMATIF', () {
    test('la 1ʳᵉ constante EST `note` (= repli défensif + parité lex)', () {
      expect(ZPodcastSourceKind.values.first, ZPodcastSourceKind.note);
      expect(
        ZPodcastSourceKind.values.map((k) => k.name).toList(),
        <String>['note', 'folder', 'document'],
      );
    });
  });

  group('AC9 — décodage DÉFENSIF du source_kind (AD-10)', () {
    test('valeur connue conservée', () {
      expect(decode('note'), ZPodcastSourceKind.note);
      expect(decode('folder'), ZPodcastSourceKind.folder);
      expect(decode('document'), ZPodcastSourceKind.document);
    });

    test('absent / null / non-String / inconnu ⇒ note (1ʳᵉ constante)', () {
      expect(ZStudyPodcast.fromMap(const <String, dynamic>{}).sourceKind,
          ZPodcastSourceKind.note);
      expect(decode(null), ZPodcastSourceKind.note);
      expect(decode(42), ZPodcastSourceKind.note);
      expect(decode('FOLDER'), ZPodcastSourceKind.note, reason: 'casse ≠');
      expect(decode('zz'), ZPodcastSourceKind.note);
    });
  });
}
