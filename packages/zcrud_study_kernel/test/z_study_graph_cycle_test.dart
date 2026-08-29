// Gardes du GRAPHE de compétences.
//
// La propriété défendue n'est pas « le graphe est un arbre » — c'est
// exactement l'inverse. Un graphe de compétences DOIT admettre des cycles :
// `related` et `equivalent` sont symétriques, un aller-retour y est la norme.
// Seules `prerequisite` et `contains` ne le peuvent pas, parce que rien ne
// peut se précéder ni se contenir soi-même.
//
// Une garde qui refuserait tous les cycles serait donc une garde qui DÉFEND LE
// DÉFAUT : elle rendrait le noyau incapable d'exprimer ce pour quoi il existe.
// D'où les deux moitiés, symétriques et également assertives : ce qui doit
// rougir, et ce qui doit rester vert.

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

ZStudyCompetencyRelation _r(String from, String to, String kind) =>
    ZStudyCompetencyRelation(fromId: from, toId: to, kind: kind);

/// `true` si le résultat est un `Left` (l'appel a refusé).
bool _refuse(ZResult<Unit> resultat) =>
    resultat.fold<bool>((ZFailure _) => true, (Unit _) => false);

void main() {
  group('zDetectCycle — primitive de graphe, sans vocabulaire métier', () {
    test('un graphe acyclique passe', () {
      expect(
        _refuse(
          zDetectCycle<List<String>>(
            <List<String>>[
              <String>['a', 'b'],
              <String>['b', 'c'],
              <String>['a', 'c'],
            ],
            fromIdOf: (List<String> e) => e[0],
            toIdOf: (List<String> e) => e[1],
          ),
        ),
        isFalse,
      );
    });

    test('une boucle sur soi est un cycle', () {
      expect(
        _refuse(
          zDetectCycle<List<String>>(
            <List<String>>[
              <String>['a', 'a'],
            ],
            fromIdOf: (List<String> e) => e[0],
            toIdOf: (List<String> e) => e[1],
          ),
        ),
        isTrue,
      );
    });

    test('un cycle dans une composante ISOLÉE est trouvé', () {
      // Une garde qui ne partirait que du premier sommet raterait celui-ci.
      expect(
        _refuse(
          zDetectCycle<List<String>>(
            <List<String>>[
              <String>['a', 'b'],
              <String>['x', 'y'],
              <String>['y', 'x'],
            ],
            fromIdOf: (List<String> e) => e[0],
            toIdOf: (List<String> e) => e[1],
          ),
        ),
        isTrue,
      );
    });

    test('un losange n\'est pas un cycle (deux chemins, aucun retour)', () {
      // Un parcours qui confondrait « déjà vu » et « sur la pile » rougirait
      // ici : c'est le piège classique du marquage à deux couleurs.
      expect(
        _refuse(
          zDetectCycle<List<String>>(
            <List<String>>[
              <String>['a', 'b'],
              <String>['a', 'c'],
              <String>['b', 'd'],
              <String>['c', 'd'],
            ],
            fromIdOf: (List<String> e) => e[0],
            toIdOf: (List<String> e) => e[1],
          ),
        ),
        isFalse,
      );
    });

    test('une arête à extrémité vide est ignorée, sans échec', () {
      expect(
        _refuse(
          zDetectCycle<List<String>>(
            <List<String>>[
              <String>['', 'b'],
              <String>['b', ''],
            ],
            fromIdOf: (List<String> e) => e[0],
            toIdOf: (List<String> e) => e[1],
          ),
        ),
        isFalse,
      );
    });

    test('une chaîne longue termine (borne par marquage, pas par récursion)',
        () {
      final aretes = <List<String>>[
        for (var i = 0; i < 2000; i++) <String>['n$i', 'n${i + 1}'],
      ];
      expect(
        _refuse(
          zDetectCycle<List<String>>(
            aretes,
            fromIdOf: (List<String> e) => e[0],
            toIdOf: (List<String> e) => e[1],
          ),
        ),
        isFalse,
      );
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('zValidateCompetencyGraph — seules deux natures sont contraintes', () {
    test('un cycle de `prerequisite` est REFUSÉ', () {
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', kZStudyCompetencyRelationPrerequisite),
            _r('b', 'a', kZStudyCompetencyRelationPrerequisite),
          ]),
        ),
        isTrue,
      );
    });

    test('un cycle de `contains` est REFUSÉ', () {
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', kZStudyCompetencyRelationContains),
            _r('b', 'c', kZStudyCompetencyRelationContains),
            _r('c', 'a', kZStudyCompetencyRelationContains),
          ]),
        ),
        isTrue,
      );
    });

    test('un cycle de `related` est ADMIS', () {
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', kZStudyCompetencyRelationRelated),
            _r('b', 'a', kZStudyCompetencyRelationRelated),
          ]),
        ),
        isFalse,
      );
    });

    test('un cycle d\'`equivalent` est ADMIS', () {
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', kZStudyCompetencyRelationEquivalent),
            _r('b', 'a', kZStudyCompetencyRelationEquivalent),
          ]),
        ),
        isFalse,
      );
    });

    test('un cycle d\'une nature INCONNUE est admis', () {
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', 'zzNatureInconnue'),
            _r('b', 'a', 'zzNatureInconnue'),
          ]),
        ),
        isFalse,
      );
    });

    test('chaque nature est contrôlée SÉPARÉMENT : le mélange ne boucle pas',
        () {
      // `a --contains--> b` puis `b --prerequisite--> a` : aucun des deux
      // sous-graphes ne se referme sur lui-même. Une implémentation qui
      // fusionnerait les natures en un seul graphe refuserait à tort.
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', kZStudyCompetencyRelationContains),
            _r('b', 'a', kZStudyCompetencyRelationPrerequisite),
          ]),
        ),
        isFalse,
      );
    });

    test('une seule nature fautive suffit à refuser tout le lot', () {
      expect(
        _refuse(
          zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
            _r('a', 'b', kZStudyCompetencyRelationRelated),
            _r('b', 'a', kZStudyCompetencyRelationRelated),
            _r('x', 'y', kZStudyCompetencyRelationPrerequisite),
            _r('y', 'x', kZStudyCompetencyRelationPrerequisite),
          ]),
        ),
        isTrue,
      );
    });

    test('le jeu de natures contraintes est paramétrable', () {
      // Avec `related` déclaré contraignant, le même graphe bascule : la règle
      // est bien portée par la liste, pas codée en dur dans le parcours.
      final relations = <ZStudyCompetencyRelation>[
        _r('a', 'b', kZStudyCompetencyRelationRelated),
        _r('b', 'a', kZStudyCompetencyRelationRelated),
      ];
      expect(_refuse(zValidateCompetencyGraph(relations)), isFalse);
      expect(
        _refuse(
          zValidateCompetencyGraph(
            relations,
            acyclicKinds: const <String>{kZStudyCompetencyRelationRelated},
          ),
        ),
        isTrue,
      );
    });

    test('le message de refus NOMME la nature fautive', () {
      final message = zValidateCompetencyGraph(<ZStudyCompetencyRelation>[
        _r('a', 'b', kZStudyCompetencyRelationPrerequisite),
        _r('b', 'a', kZStudyCompetencyRelationPrerequisite),
      ]).fold<String>((ZFailure f) => f.message, (Unit _) => '');
      expect(message, contains(kZStudyCompetencyRelationPrerequisite));
    });

    test('un lot vide passe, et ne parcourt rien', () {
      expect(
        _refuse(zValidateCompetencyGraph(const <ZStudyCompetencyRelation>[])),
        isFalse,
      );
    });
  });

  group('ZStudyCompetencyRelation — contrat de donnée', () {
    test('round-trip, nature inconnue et métadonnées comprises', () {
      const relation = ZStudyCompetencyRelation(
        fromId: 'a',
        toId: 'b',
        kind: 'zzNatureInconnue',
        metadata: <String, dynamic>{'zz': 1},
      );
      expect(
        ZStudyCompetencyRelation.fromMap(relation.toMap()),
        equals(relation),
      );
    });

    test('fromMap d\'une map corrompue ne lève pas et rend les défauts', () {
      final relu = ZStudyCompetencyRelation.fromMap(<String, dynamic>{
        'from_id': 42,
        'to_id': <String>[],
        'kind': <String, dynamic>{},
        'metadata': 'pas une map',
      });
      expect(relu.fromId, isEmpty);
      expect(relu.toId, isEmpty);
      expect(relu.kind, equals(kZStudyCompetencyRelationRelated));
      expect(relu.metadata, isEmpty);
    });

    test('mustBeAcyclic ne vaut que pour les deux natures contraintes', () {
      expect(
        _r('a', 'b', kZStudyCompetencyRelationPrerequisite).mustBeAcyclic,
        isTrue,
      );
      expect(
        _r('a', 'b', kZStudyCompetencyRelationContains).mustBeAcyclic,
        isTrue,
      );
      expect(
        _r('a', 'b', kZStudyCompetencyRelationRelated).mustBeAcyclic,
        isFalse,
      );
      expect(_r('a', 'b', 'zzInconnue').mustBeAcyclic, isFalse);
    });
  });

  group('ZStudyTopicCompetency — contrat de donnée', () {
    test('round-trip, poids compris', () {
      const liaison = ZStudyTopicCompetency(
        topicId: 't1',
        competencyId: 'c1',
        weight: 0.25,
      );
      expect(ZStudyTopicCompetency.fromMap(liaison.toMap()), equals(liaison));
    });

    test('un poids absent n\'écrit AUCUNE clé', () {
      const liaison = ZStudyTopicCompetency(topicId: 't1', competencyId: 'c1');
      expect(liaison.toMap().keys, isNot(contains('weight')));
      expect(ZStudyTopicCompetency.fromMap(liaison.toMap()), equals(liaison));
    });

    test('fromMap d\'une map corrompue ne lève pas et rend les défauts', () {
      final relu = ZStudyTopicCompetency.fromMap(<String, dynamic>{
        'topic_id': <int>[1],
        'competency_id': 3.5,
        'weight': 'pas un nombre',
      });
      expect(relu.topicId, isEmpty);
      expect(relu.competencyId, isEmpty);
      expect(relu.weight, isNull);
    });
  });
}
