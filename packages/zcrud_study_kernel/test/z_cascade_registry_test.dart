/// Tests à **pouvoir discriminant** du registre déclaratif de cascade (ES-3.3,
/// AC1-AC5). **Pur-Dart / web-safe** : aucun `dart:io`, PAS de `@TestOn('vm')` —
/// rejoué sous `dart test` **ET** `dart test -p node` (gate `test:js`), parité
/// `z_study_repository_test.dart` (ES-3.1).
///
/// Chaque garde naît avec sa **fixture d'échec isolée** (R2) : le commentaire R3
/// indique quel retrait de garde fait ROUGIR le test.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Registre canonique **miroir de lex** (fixture, DW-ES33-1 : le placement
/// physique des const dans les packages propriétaires est déféré à ES-5).
ZCascadeRegistry _lexMirrorRegistry() => ZCascadeRegistry(<ZCascadeEdge>[
      // Self-edge : sous-dossiers (lex `_subFolderIds`, via `parent_id`).
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'study_folder',
        childParentRef: 'parent_id',
        owner: 'zcrud_study_kernel',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'flashcard',
        childParentRef: 'folder_id',
        owner: 'zcrud_flashcard',
      ),
      // Transitive : flashcard → repetition_info (lex `flashcard_id`).
      const ZCascadeEdge(
        parentKind: 'flashcard',
        childKind: 'repetition_info',
        childParentRef: 'flashcard_id',
        owner: 'zcrud_flashcard',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'smart_note',
        childParentRef: 'folder_id',
        owner: 'zcrud_note',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'mindmap',
        childParentRef: 'folder_id',
        owner: 'zcrud_mindmap',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'study_document',
        childParentRef: 'folder_id',
        owner: 'zcrud_document',
      ),
      // Transitive profonde : study_document → document_annotation.
      const ZCascadeEdge(
        parentKind: 'study_document',
        childKind: 'document_annotation',
        childParentRef: 'document_id',
        owner: 'zcrud_document',
      ),
      const ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'exam',
        childParentRef: 'folder_id',
        owner: 'zcrud_exam',
      ),
    ]);

String _pair(ZCascadeEdge e) => '${e.parentKind}→${e.childKind}';

void main() {
  group('AC1 — ZCascadeEdge : quadruplet de String, égalité de valeur', () {
    test('les 4 champs sont des String littéraux ; == / hashCode sur le tuple',
        () {
      const a = ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'flashcard',
        childParentRef: 'folder_id',
        owner: 'zcrud_flashcard',
      );
      const b = ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'flashcard',
        childParentRef: 'folder_id',
        owner: 'zcrud_flashcard',
      );
      const c = ZCascadeEdge(
        parentKind: 'study_folder',
        childKind: 'flashcard',
        childParentRef: 'folder_id',
        owner: 'zcrud_autre',
      );
      // AC4 (anti-réflexion) : ces valeurs sont des String — aucun `Type`, aucun
      // générique n'entre dans l'identité de l'arête.
      expect(a.parentKind, isA<String>());
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('AC2 — descendantEdges : fermeture transitive déterministe complète', () {
    test('toutes les arêtes déclarées apparaissent (dont les transitives)', () {
      final registry = _lexMirrorRegistry();
      final edges = registry.descendantEdges('study_folder').map(_pair).toSet();

      // R3-b (partie kernel) : retirer une arête de la fermeture (ex. filtrer
      // `study_document→document_annotation`) fait DISPARAÎTRE l'annotation du
      // plan ⇒ ce test ROUGIT.
      expect(
        edges,
        containsAll(<String>[
          'study_folder→study_folder',
          'study_folder→flashcard',
          'flashcard→repetition_info', // transitive
          'study_folder→smart_note',
          'study_folder→mindmap',
          'study_folder→study_document',
          'study_document→document_annotation', // transitive profonde
          'study_folder→exam',
        ]),
      );
    });

    test('ordre déterministe et stable (2 appels ⇒ liste identique)', () {
      final registry = _lexMirrorRegistry();
      final first = registry.descendantEdges('study_folder').map(_pair).toList();
      final second =
          registry.descendantEdges('study_folder').map(_pair).toList();
      expect(second, orderedEquals(first));
      // BFS : arêtes directes du root avant les transitives profondes.
      expect(first.first, equals('study_folder→study_folder'));
      expect(first.contains('flashcard→repetition_info'), isTrue);
      expect(
        first.indexOf('study_folder→flashcard'),
        lessThan(first.indexOf('flashcard→repetition_info')),
      );
    });

    test('chaque arête déclarée apparaît EXACTEMENT une fois (pas de doublon)',
        () {
      final registry = _lexMirrorRegistry();
      final edges = registry.descendantEdges('study_folder').map(_pair).toList();
      expect(edges.toSet().length, equals(edges.length));
      expect(edges.length, equals(8));
    });

    test('childrenOf : arêtes directes uniquement, liste vide si aucune', () {
      final registry = _lexMirrorRegistry();
      expect(registry.childrenOf('repetition_info'), isEmpty);
      expect(
        registry.childrenOf('flashcard').map(_pair),
        equals(<String>['flashcard→repetition_info']),
      );
    });
  });

  group('AC3 — anti two-owners : rejet à la construction', () {
    test('deux arêtes (folder→exam) à owners DIFFÉRENTS ⇒ ArgumentError', () {
      // R3-f : retirer la garde anti two-owners fait RÉUSSIR cette construction
      // (arête à deux propriétaires acceptée) ⇒ ce test ROUGIT.
      expect(
        () => ZCascadeRegistry(<ZCascadeEdge>[
          const ZCascadeEdge(
            parentKind: 'study_folder',
            childKind: 'exam',
            childParentRef: 'folder_id',
            owner: 'zcrud_exam',
          ),
          const ZCascadeEdge(
            parentKind: 'study_folder',
            childKind: 'exam',
            childParentRef: 'folder_id',
            owner: 'zcrud_intrus',
          ),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            allOf(
              contains('study_folder→exam'),
              contains('zcrud_exam'),
              contains('zcrud_intrus'),
            ),
          ),
        ),
      );
    });

    test('doublon STRICTEMENT identique (même owner) ⇒ toléré + dédupliqué', () {
      final registry = ZCascadeRegistry(<ZCascadeEdge>[
        const ZCascadeEdge(
          parentKind: 'study_folder',
          childKind: 'exam',
          childParentRef: 'folder_id',
          owner: 'zcrud_exam',
        ),
        const ZCascadeEdge(
          parentKind: 'study_folder',
          childKind: 'exam',
          childParentRef: 'folder_id',
          owner: 'zcrud_exam',
        ),
      ]);
      // Idempotence de composition : une seule arête après dédup.
      expect(registry.childrenOf('study_folder').length, equals(1));
    });

    test('une arête à owner unique passe', () {
      expect(
        () => ZCascadeRegistry(<ZCascadeEdge>[
          const ZCascadeEdge(
            parentKind: 'study_folder',
            childKind: 'exam',
            childParentRef: 'folder_id',
            owner: 'zcrud_exam',
          ),
        ]),
        returnsNormally,
      );
    });
  });

  group('AC5 — garde de cycle : la traversée de kinds TERMINE', () {
    test('self-edge study_folder→study_folder ne boucle pas', () {
      final registry = _lexMirrorRegistry();
      // R3-g : retirer le `Set<String> visited` de descendantEdges ⇒ le self-edge
      // re-queue `study_folder` à l'infini (StackOverflow / timeout) ⇒ ROUGIT.
      final edges = registry.descendantEdges('study_folder');
      expect(edges, isNotEmpty); // termine, résultat fini
    });

    test('cycle a→b→a termine et reste fini/déterministe', () {
      final registry = ZCascadeRegistry(<ZCascadeEdge>[
        const ZCascadeEdge(
          parentKind: 'a',
          childKind: 'b',
          childParentRef: 'a_id',
          owner: 'pkg',
        ),
        const ZCascadeEdge(
          parentKind: 'b',
          childKind: 'a',
          childParentRef: 'b_id',
          owner: 'pkg',
        ),
      ]);
      final edges = registry.descendantEdges('a').map(_pair).toList();
      expect(edges, equals(<String>['a→b', 'b→a']));
    });

    test('kind sans arête sortante ⇒ fermeture vide', () {
      final registry = _lexMirrorRegistry();
      expect(registry.descendantEdges('inconnu'), isEmpty);
    });
  });
}
