/// Tests de `orphanTagIds` (ES-2.3, FR-S6, AC5/AC11 — décision D5).
///
/// Primitive PURE de **détection** des références orphelines. La **purge** (retrait
/// des refs) est HORS PÉRIMÈTRE : elle appartient au **repository**
/// (`StudyTagsRepository.deleteTag` chez lex — ES-8.1 / ES-3). Ce test ne couvre
/// QUE la détection.
///
/// ⚠️ **Aucun `dart:io`** (AC14) · clés `String` neutres, aucune dép satellite.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('orphanTagIds — détection (AC5)', () {
    test('sous-ensemble des référencés absents des existants', () {
      final orphans = orphanTagIds(
        referencedTagIds: <String>['a', 'b', 'c'],
        existingTagIds: <String>['a', 'c'],
      );
      expect(orphans, <String>{'b'});
    });

    test('ordre d\'entrée préservé', () {
      final orphans = orphanTagIds(
        referencedTagIds: <String>['z', 'y', 'x'],
        existingTagIds: <String>[],
      );
      expect(orphans.toList(), <String>['z', 'y', 'x']);
    });

    test('dédoublonné', () {
      final orphans = orphanTagIds(
        referencedTagIds: <String>['b', 'b', 'b', 'a'],
        existingTagIds: <String>['a'],
      );
      expect(orphans, <String>{'b'});
      expect(orphans.length, 1);
    });
  });

  group('orphanTagIds — PURE/TOTALE (AC5/AC11, AD-10)', () {
    test('referencedTagIds vide -> {}', () {
      expect(
        orphanTagIds(referencedTagIds: <String>[], existingTagIds: <String>['a']),
        isEmpty,
      );
    });

    test('existingTagIds vide -> tous orphelins', () {
      expect(
        orphanTagIds(
            referencedTagIds: <String>['a', 'b'], existingTagIds: <String>[]),
        <String>{'a', 'b'},
      );
    });

    test('chaîne vide gérée comme clé opaque', () {
      expect(
        orphanTagIds(
            referencedTagIds: <String>['', 'a'], existingTagIds: <String>['a']),
        <String>{''},
      );
      expect(
        orphanTagIds(
            referencedTagIds: <String>[''], existingTagIds: <String>['']),
        isEmpty,
      );
    });

    test('aucun throw même sur itérables vides', () {
      expect(
        () => orphanTagIds(
            referencedTagIds: <String>[], existingTagIds: <String>[]),
        returnsNormally,
      );
    });

    test('aucun orphelin quand tout est existant', () {
      expect(
        orphanTagIds(
          referencedTagIds: <String>['a', 'b'],
          existingTagIds: <String>['a', 'b', 'c'],
        ),
        isEmpty,
      );
    });
  });

  // 🔴 AC5 — la PURGE est HORS PÉRIMÈTRE (repository, ES-8.1/ES-3). Cette
  // primitive DÉTECTE seulement ; elle ne modifie aucune carte, ne retire aucune
  // référence. `orphanTagIds` est pure et sans effet de bord — l'entrée n'est
  // jamais mutée.
  test('DOC — détection SANS purge (entrées non mutées)', () {
    final referenced = <String>['a', 'b', 'c'];
    final existing = <String>['a'];
    orphanTagIds(referencedTagIds: referenced, existingTagIds: existing);
    expect(referenced, <String>['a', 'b', 'c']); // inchangé
    expect(existing, <String>['a']); // inchangé
  });
}
