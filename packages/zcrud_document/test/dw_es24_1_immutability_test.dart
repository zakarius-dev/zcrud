// DW-ES24-1 (ES-3.0, Phase B) — immuabilité INCONDITIONNELLE des canaux Map/List
// de `zcrud_document` : `ZDocumentLearningInfo.qualityByPage` (canal #1) et
// `ZDocumentReadingState.learning` (canal #2, compose #1).
//
// POUVOIR DISCRIMINANT (AC12) : muter la collection obtenue via l'ACCESSEUR sur
// une instance née du **constructeur NOMINAL invoqué non-`const`** avec une réf
// mutable ⇒ `UnsupportedError`. Retirer l'accesseur immuabilisant fait ROUGIR
// (R3, prouvé par l'orchestrateur).
library;

import 'package:test/test.dart';
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('DW-ES24-1 #1 — ZDocumentLearningInfo.qualityByPage', () {
    test('ctor NOMINAL non-const + mutation via accesseur ⇒ UnsupportedError',
        () {
      final mut = <int, int>{1: 2};
      final i = ZDocumentLearningInfo(qualityByPage: mut); // ctor const, non-const
      expect(() => i.qualityByPage[3] = 9, throwsUnsupportedError);
      expect(() => i.qualityByPage.remove(1), throwsUnsupportedError);
      expect(() => i.qualityByPage.clear(), throwsUnsupportedError);
    });

    test('AC13 — `const` PRÉSERVÉ + fromJson toujours non-modifiable', () {
      const i = ZDocumentLearningInfo(); // ctor const préservé
      expect(i.qualityByPage, isEmpty);
      final j = ZDocumentLearningInfo.fromJson(
        const <String, dynamic>{'quality_by_page': <String, dynamic>{'1': 2}},
      );
      expect(() => j.qualityByPage[2] = 1, throwsUnsupportedError);
    });

    test('AC14 — zéro-copie sur le chemin chaud (accesseur idempotent)', () {
      final j = ZDocumentLearningInfo.fromJson(
        const <String, dynamic>{'quality_by_page': <String, dynamic>{'1': 2}},
      );
      // La vue rendue est la MÊME instance à chaque lecture (slot déjà gardé).
      expect(identical(j.qualityByPage, j.qualityByPage), isTrue);
    });
  });

  group('DW-ES24-1 #2 — ZDocumentReadingState.learning (compose #1)', () {
    test('learning construit via ctor nominal ⇒ qualityByPage non-modifiable',
        () {
      final mut = <int, int>{1: 2};
      final state = ZDocumentReadingState(
        docId: 'd',
        learning: ZDocumentLearningInfo(qualityByPage: mut),
      );
      expect(
        () => state.learning.qualityByPage[3] = 9,
        throwsUnsupportedError,
      );
    });
  });
}
