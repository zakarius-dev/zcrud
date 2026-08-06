// CR-DODLP F1 — L'ordre d'affichage doit venir du SCHÉMA (`DynamicEdition.fields`),
// jamais de l'ordre de la Map de persistance passée en `initialValues`.
//
// Ce fichier est d'abord un jeu de tests de CARACTÉRISATION (comportement mesuré
// AVANT correction), puis la GARDE anti-régression : chaque cas mesure l'ORDRE
// RENDU À L'ÉCRAN (positions verticales réelles), pas la seule présence d'un
// champ — et sur un cas où l'ordre de la Map DIFFÈRE de celui du schéma (sinon la
// garde serait vacante : valeur attendue == valeur ambiante).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Schéma canonique : ordre `alpha, beta, gamma, delta`.
const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'alpha', type: EditionFieldType.text, label: 'Alpha'),
  ZFieldSpec(name: 'beta', type: EditionFieldType.text, label: 'Beta'),
  ZFieldSpec(name: 'gamma', type: EditionFieldType.text, label: 'Gamma'),
  ZFieldSpec(name: 'delta', type: EditionFieldType.text, label: 'Delta'),
];

/// Map de persistance dont l'ordre d'insertion est DÉLIBÉRÉMENT l'inverse du
/// schéma (c'est le `toMap()` d'un modèle : l'ordre y est arbitraire).
Map<String, Object?> _persistedMap() => <String, Object?>{
      'delta': 'D',
      'gamma': 'G',
      'beta': 'B',
      'alpha': 'A',
    };

Widget _app(
  ZFormController controller, {
  List<ZFieldSpec> fields = _fields,
  List<ZEditionSection> sections = const <ZEditionSection>[],
}) =>
    MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          sections: sections,
        ),
      ),
    );

/// Ordre RENDU : noms des champs montés, triés par position verticale réelle.
/// Mesure l'écran, pas une liste interne.
List<String> _renderedOrder(WidgetTester tester, List<String> candidates) {
  final found = <String, double>{};
  for (final name in candidates) {
    final f = find.byKey(ValueKey<String>(name));
    if (f.evaluate().isEmpty) continue;
    found[name] = tester.getTopLeft(f.first).dy;
  }
  final names = found.keys.toList()
    ..sort((a, b) => found[a]!.compareTo(found[b]!));
  return names;
}

const _all = <String>['alpha', 'beta', 'gamma', 'delta'];

void main() {
  group('CR-DODLP F1 — ordre piloté par le SCHÉMA, pas par la persistance', () {
    testWidgets(
        'sans visibleFields : l\'ordre rendu suit `fields`, PAS l\'ordre de la Map',
        (tester) async {
      final c = ZFormController(initialValues: _persistedMap());
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c));

      // Égalité stricte (jamais `contains`) sur l'ordre COMPLET.
      expect(_renderedOrder(tester, _all), <String>[
        'alpha',
        'beta',
        'gamma',
        'delta',
      ]);
      // Et le canal structurel porte le même ordre canonique.
      expect(c.visibleFields.value, <String>['alpha', 'beta', 'gamma', 'delta']);
    });

    testWidgets(
        'sans visibleFields : un champ du schéma ABSENT de initialValues est rendu',
        (tester) async {
      // `delta` n'est pas persisté (champ ajouté au schéma, modèle plus ancien).
      final c = ZFormController(
        initialValues: <String, Object?>{'gamma': 'G', 'alpha': 'A'},
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c));

      expect(_renderedOrder(tester, _all), <String>[
        'alpha',
        'beta',
        'gamma',
        'delta',
      ]);
    });

    testWidgets(
        'sans visibleFields : une clé de initialValues INCONNUE du schéma est '
        'ignorée sans throw (AD-10)', (tester) async {
      final c = ZFormController(
        initialValues: <String, Object?>{
          'zzz_legacy': 'orphelin',
          'beta': 'B',
          'alpha': 'A',
        },
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('zzz_legacy')), findsNothing);
      expect(c.visibleFields.value, isNot(contains('zzz_legacy')));
      expect(_renderedOrder(tester, _all), <String>[
        'alpha',
        'beta',
        'gamma',
        'delta',
      ]);
      // La tranche de la clé orpheline existe toujours (aucune destruction).
      expect(c.valueOf('zzz_legacy'), 'orphelin');
    });

    testWidgets('controller VIDE (ni initialValues ni visibleFields) : le '
        'schéma est rendu', (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c));

      expect(_renderedOrder(tester, _all), <String>[
        'alpha',
        'beta',
        'gamma',
        'delta',
      ]);
    });

    testWidgets(
        'RÉTRO-COMPAT — visibleFields EXPLICITE : ensemble ET ordre intacts',
        (tester) async {
      // Sous-ensemble, dans un ordre volontairement non canonique : l'hôte est
      // autoritaire, la correction ne doit RIEN y changer.
      final c = ZFormController(
        initialValues: _persistedMap(),
        visibleFields: const <String>['gamma', 'alpha'],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c));

      expect(c.visibleFields.value, <String>['gamma', 'alpha']);
      expect(_renderedOrder(tester, _all), <String>['gamma', 'alpha']);
      expect(find.byKey(const ValueKey<String>('beta')), findsNothing);
      expect(find.byKey(const ValueKey<String>('delta')), findsNothing);
    });

    testWidgets(
        'RÉTRO-COMPAT — visibleFields explicite VIDE : rien n\'est rendu',
        (tester) async {
      final c = ZFormController(
        initialValues: _persistedMap(),
        visibleFields: const <String>[],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c));

      expect(c.visibleFields.value, isEmpty);
      expect(_renderedOrder(tester, _all), isEmpty);
    });

    testWidgets(
        'fields VIDE : n\'EFFACE pas l\'ensemble visible d\'un autre écrivain '
        '(AD-10)', (tester) async {
      final c = ZFormController(initialValues: _persistedMap());
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, fields: const <ZFieldSpec>[]));

      expect(tester.takeException(), isNull);
      expect(c.visibleFields.value, <String>['delta', 'gamma', 'beta', 'alpha']);
    });

    testWidgets('manageVisibility:false (stepper imbriqué) : aucun amorçage — '
        'la fenêtre reste celle du single-writer', (tester) async {
      final c = ZFormController(initialValues: _persistedMap());
      addTearDown(c.dispose);
      // Le racine (ici simulé) est seul écrivain : il n'a rien écrit d'autre que
      // l'amorçage du controller (ordre de la Map). Une zone PASSIVE ne doit pas
      // le réécrire.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicEdition(
              controller: c,
              fields: _fields,
              manageVisibility: false,
            ),
          ),
        ),
      );

      expect(c.visibleFields.value, <String>['delta', 'gamma', 'beta', 'alpha']);
      expect(_renderedOrder(tester, _all), <String>[
        'delta',
        'gamma',
        'beta',
        'alpha',
      ]);
    });

    testWidgets(
        'sans visibleFields + condition : l\'ordre canonique est préservé et le '
        'champ masqué est absent', (tester) async {
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'alpha', type: EditionFieldType.text, label: 'Alpha'),
        ZFieldSpec(
          name: 'beta',
          type: EditionFieldType.text,
          label: 'Beta',
          condition: ZCondition.equals('alpha', 'show'),
        ),
        ZFieldSpec(name: 'gamma', type: EditionFieldType.text, label: 'Gamma'),
        ZFieldSpec(name: 'delta', type: EditionFieldType.text, label: 'Delta'),
      ];
      final c = ZFormController(initialValues: _persistedMap());
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(c, fields: fields));

      expect(_renderedOrder(tester, _all), <String>['alpha', 'gamma', 'delta']);

      c.setValue('alpha', 'show');
      await tester.pump();
      expect(_renderedOrder(tester, _all), <String>[
        'alpha',
        'beta',
        'gamma',
        'delta',
      ]);
    });

    testWidgets('AD-2/SM-1 — l\'amorçage ne coûte AUCUN rebuild structurel '
        'supplémentaire pendant la saisie', (tester) async {
      var structural = 0;
      final c = ZFormController(initialValues: _persistedMap());
      addTearDown(c.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicEdition(
              controller: c,
              fields: _fields,
              onStructuralBuild: () => structural++,
            ),
          ),
        ),
      );
      final afterMount = structural;
      expect(afterMount, greaterThan(0));

      for (var i = 0; i < 20; i++) {
        c.setValue('alpha', 'x$i');
        await tester.pump();
      }
      expect(structural, afterMount);
    });
  });
}
