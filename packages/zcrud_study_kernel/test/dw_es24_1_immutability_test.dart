// DW-ES24-1 (ES-3.0, Phase B) — immuabilité INCONDITIONNELLE des canaux Map/List
// de `zcrud_study_kernel` : `ZFolderContentsOrder.sectionOrders` (canal #4,
// `Map<String,List<String>>` — 2 niveaux) et `ZStudySessionResult.byQuality`
// (canal #5, `Map<String,int>` — scalaire).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('DW-ES24-1 #4 — ZFolderContentsOrder.sectionOrders (profond)', () {
    test('ctor NOMINAL non-const + mutation MAP via accesseur ⇒ Unsupported',
        () {
      final mut = <String, List<String>>{
        'flashcards': <String>['c1', 'c2'],
      };
      final o = ZFolderContentsOrder(sectionOrders: mut); // ctor const non-const
      expect(() => o.sectionOrders['notes'] = <String>['n1'],
          throwsUnsupportedError);
      expect(() => o.sectionOrders.remove('flashcards'), throwsUnsupportedError);
    });

    test('mutation de la LISTE INTERNE (2ᵉ niveau) via accesseur ⇒ Unsupported',
        () {
      final o = ZFolderContentsOrder(sectionOrders: <String, List<String>>{
        'flashcards': <String>['c1'],
      });
      expect(() => o.sectionOrders['flashcards']!.add('c2'),
          throwsUnsupportedError);
      expect(() => o.sectionOrders['flashcards']!.clear(),
          throwsUnsupportedError);
    });

    test('AC13 — `const` PRÉSERVÉ + fromMap profondément immuable', () {
      const o = ZFolderContentsOrder();
      expect(o.sectionOrders, isEmpty);
      final relu = ZFolderContentsOrder.fromMap(const <String, dynamic>{
        'section_orders': <String, dynamic>{
          'flashcards': <String>['c1'],
        },
      });
      expect(() => relu.sectionOrders['flashcards']!.add('c2'),
          throwsUnsupportedError);
    });

    test('AC14 — zéro-copie sur le chemin chaud (accesseur idempotent)', () {
      final relu = ZFolderContentsOrder.fromMap(const <String, dynamic>{
        'section_orders': <String, dynamic>{
          'flashcards': <String>['c1'],
        },
      });
      expect(identical(relu.sectionOrders, relu.sectionOrders), isTrue);
    });
  });

  group('DW-ES24-1 #5 — ZStudySessionResult.byQuality (scalaire)', () {
    test('ctor NOMINAL non-const + mutation via accesseur ⇒ UnsupportedError',
        () {
      final mut = <String, int>{'0': 1};
      final r = ZStudySessionResult(byQuality: mut); // ctor const non-const
      expect(() => r.byQuality['1'] = 2, throwsUnsupportedError);
      expect(() => r.byQuality.remove('0'), throwsUnsupportedError);
    });

    test('AC13 — `const` PRÉSERVÉ + fromMap toujours non-modifiable', () {
      const r = ZStudySessionResult();
      expect(r.byQuality, isEmpty);
      final relu = ZStudySessionResult.fromMap(
        const <String, dynamic>{'by_quality': <String, dynamic>{'0': 3}},
      );
      expect(() => relu.byQuality['1'] = 9, throwsUnsupportedError);
    });
  });
}
