// Appartenance à une sélection multiple — `ZCondition.contains`.
//
// Ces gardes fixent le contrat de l'opérateur d'appartenance :
//   * il répond `true` quand la collection du champ contient la valeur ;
//   * il rend `false` — SANS jamais lever — sur un champ absent, nul, ou dont
//     la valeur n'est pas une collection ;
//   * une CHAÎNE ne compte pas comme collection (décision figée ici : une
//     recherche de sous-chaîne n'est pas une appartenance) ;
//   * il se compose avec `and`/`or`/`not` comme toute autre feuille, et il
//     alimente la garde ciblée par frappe (`zGuardFieldsOf`).
//
// Elles mordent : faire retomber `zContainsValue` sur `'$container'.contains`,
// ou lui laisser accepter une `String`/`Map`, fait rougir l'assertion
// correspondante — et elle seule.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  // Évalue une condition contre une table de valeurs de champs.
  bool evalue(ZCondition condition, Map<String, Object?> valeurs) =>
      evaluateZCondition(condition, (nom) => valeurs[nom]);

  group('`contains` répond à « cette option est-elle cochée ? »', () {
    test('vrai quand la collection du champ porte la valeur', () {
      expect(
        evalue(
          const ZCondition.contains('bureaux', 'lome'),
          <String, Object?>{
            'bureaux': <String>['kara', 'lome'],
          },
        ),
        isTrue,
      );
    });

    test('faux quand la collection ne porte pas la valeur, ou est vide', () {
      expect(
        evalue(
          const ZCondition.contains('bureaux', 'lome'),
          <String, Object?>{
            'bureaux': <String>['kara'],
          },
        ),
        isFalse,
      );
      expect(
        evalue(
          const ZCondition.contains('bureaux', 'lome'),
          <String, Object?>{'bureaux': <String>[]},
        ),
        isFalse,
      );
    });

    test('un `Set` est une collection comme une autre', () {
      expect(
        evalue(
          const ZCondition.contains('bureaux', 'lome'),
          <String, Object?>{
            'bureaux': <String>{'lome'},
          },
        ),
        isTrue,
      );
    });

    test('l\'appartenance se juge par `==`, y compris sur des nombres', () {
      expect(
        evalue(
          const ZCondition.contains('rangs', 3),
          <String, Object?>{
            'rangs': <int>[1, 2, 3],
          },
        ),
        isTrue,
      );
      expect(
        evalue(
          const ZCondition.contains('rangs', '3'),
          <String, Object?>{
            'rangs': <int>[1, 2, 3],
          },
        ),
        isFalse,
        reason: 'le texte « 3 » n\'est pas le nombre 3',
      );
    });
  });

  group('Robustesse : jamais d\'exception, toujours `false`', () {
    // Chaque entrée : la valeur portée par le champ observé.
    final nonCollections = <String, Object?>{
      'champ nul': null,
      'nombre': 12,
      'booléen': true,
      'map': <String, int>{'lome': 1},
      'objet quelconque': Object(),
    };

    nonCollections.forEach((libelle, valeur) {
      test('$libelle : `false`, sans lever', () {
        expect(
          () => evalue(
            const ZCondition.contains('bureaux', 'lome'),
            <String, Object?>{'bureaux': valeur},
          ),
          returnsNormally,
        );
        expect(
          evalue(
            const ZCondition.contains('bureaux', 'lome'),
            <String, Object?>{'bureaux': valeur},
          ),
          isFalse,
        );
      });
    });

    test('champ absent de l\'état : `false`, sans lever', () {
      expect(
        () => evalue(
          const ZCondition.contains('bureaux', 'lome'),
          const <String, Object?>{},
        ),
        returnsNormally,
      );
      expect(
        evalue(
          const ZCondition.contains('bureaux', 'lome'),
          const <String, Object?>{},
        ),
        isFalse,
      );
    });

    test('collection paresseuse qui échoue au parcours : `false`, sans lever',
        () {
      final piegee = <int>[1, 2, 3].map<Object>((i) {
        throw StateError('parcours impossible');
      });
      expect(() => zContainsValue(piegee, 'lome'), returnsNormally);
      expect(zContainsValue(piegee, 'lome'), isFalse);
    });
  });

  group('Une CHAÎNE n\'est PAS une collection (décision figée)', () {
    test('`contains` sur une chaîne rend `false`, jamais une sous-chaîne', () {
      expect(
        evalue(
          const ZCondition.contains('bureau', 'lome'),
          <String, Object?>{'bureau': 'lome-port'},
        ),
        isFalse,
        reason: 'une appartenance n\'est pas une recherche de sous-chaîne',
      );
      expect(
        evalue(
          const ZCondition.contains('bureau', 'lome'),
          <String, Object?>{'bureau': 'lome'},
        ),
        isFalse,
        reason: 'même égale, une chaîne ne « contient » pas au sens de cet '
            'opérateur — c\'est `equals` qui répond à cette question',
      );
      expect(
        evalue(
          const ZCondition.equals('bureau', 'lome'),
          <String, Object?>{'bureau': 'lome'},
        ),
        isTrue,
        reason: 'la question « est-ce cette valeur ? » a son opérateur',
      );
    });

    test('la chaîne vide ne fait pas exception', () {
      expect(zContainsValue('', ''), isFalse);
      expect(zContainsValue('abc', 'b'), isFalse);
    });
  });

  group('Composition et garde ciblée', () {
    const coche = ZCondition.contains('bureaux', 'lome');

    test('`not` donne l\'inverse', () {
      expect(
        evalue(const ZCondition.not(coche), <String, Object?>{
          'bureaux': <String>['kara'],
        }),
        isTrue,
      );
      expect(
        evalue(const ZCondition.not(coche), <String, Object?>{
          'bureaux': <String>['lome'],
        }),
        isFalse,
      );
    });

    test('`and` / `or` composent avec les autres feuilles', () {
      const et = ZCondition.and(<ZCondition>[
        coche,
        ZCondition.truthy('actif'),
      ]);
      const ou = ZCondition.or(<ZCondition>[
        coche,
        ZCondition.truthy('actif'),
      ]);
      final cocheSeul = <String, Object?>{
        'bureaux': <String>['lome'],
        'actif': false,
      };
      expect(evalue(et, cocheSeul), isFalse);
      expect(evalue(ou, cocheSeul), isTrue);
      expect(
        evalue(et, <String, Object?>{
          'bureaux': <String>['lome'],
          'actif': true,
        }),
        isTrue,
      );
    });

    test('le champ observé alimente l\'abonnement ciblé par frappe', () {
      expect(
        zGuardFieldsOf(const <ZCondition?>[coche]),
        <String>{'bureaux'},
      );
      expect(
        zGuardFieldsOf(const <ZCondition?>[
          ZCondition.and(<ZCondition>[coche, ZCondition.truthy('actif')]),
        ]),
        <String>{'bureaux', 'actif'},
      );
    });

    test('la source de lecture est honorée comme pour les autres feuilles', () {
      const surBaseline = ZCondition.contains(
        'bureaux',
        'lome',
        source: ZValueSource.persisted,
      );
      expect(
        evaluateZCondition(
          surBaseline,
          (_) => <String>['kara'],
          persistedValueOf: (_) => <String>['lome'],
        ),
        isTrue,
      );
      expect(
        zGuardFieldsOf(const <ZCondition?>[surBaseline]),
        isEmpty,
        reason: 'une feuille `persisted` ne change pas sous une frappe',
      );
    });

    test('identité de valeur : deux conditions identiques sont égales', () {
      expect(
        const ZCondition.contains('bureaux', 'lome'),
        const ZCondition.contains('bureaux', 'lome'),
      );
      expect(
        const ZCondition.contains('bureaux', 'lome').hashCode,
        const ZCondition.contains('bureaux', 'lome').hashCode,
      );
      expect(
        const ZCondition.contains('bureaux', 'lome'),
        isNot(const ZCondition.contains('bureaux', 'kara')),
      );
    });
  });
}
