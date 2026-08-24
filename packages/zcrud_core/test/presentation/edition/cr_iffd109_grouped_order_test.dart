// Voie GROUPÉE de `DynamicEdition` :
// ① l'ordre de rendu est l'ORDRE DÉCLARÉ de `fields` — un champ libre déclaré
//   entre deux sections est rendu ENTRE elles (les champs libres contigus
//   forment des blocs intercalés, chaque section reste un bloc) ;
// ② un en-tête n'est rendu que s'il a quelque chose à montrer : une section à
//   titre vide (et sans icône) ne monte NI chrome, NI padding, NI nœud
//   sémantique — ses champs seulement ; `collapsible` y est sans effet (pas
//   de déclencheur : la section reste dépliée).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'head', type: EditionFieldType.text, label: 'Head'),
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
  ZFieldSpec(name: 'mid', type: EditionFieldType.text, label: 'Mid'),
  ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
  ZFieldSpec(name: 'tail', type: EditionFieldType.text, label: 'Tail'),
];

const _values = <String, Object?>{
  'head': 'h',
  'a': 'va',
  'mid': 'm',
  'b': 'vb',
  'tail': 't',
};

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

double _dy(WidgetTester tester, String name) =>
    tester.getTopLeft(find.byKey(ValueKey<String>('field:$name'))).dy;

void main() {
  testWidgets(
      '① l\'ordre déclaré de `fields` est respecté : '
      'libre → section → libre → section → libre', (tester) async {
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      // Une section stylée force la voie groupée — la seule qui décore.
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: 'S1',
          fields: <String>['a'],
          style: ZEditionSectionStyle(),
        ),
        ZEditionSection(title: 'S2', fields: <String>['b']),
      ],
    )));
    await tester.pump();

    // head < S1(a) < mid < S2(b) < tail — un champ libre entre deux sections
    // RESTE entre elles (l'ancien rendu remontait head/mid/tail en tête).
    expect(_dy(tester, 'head'), lessThan(_dy(tester, 'a')));
    expect(_dy(tester, 'a'), lessThan(_dy(tester, 'mid')));
    expect(_dy(tester, 'mid'), lessThan(_dy(tester, 'b')));
    expect(_dy(tester, 'b'), lessThan(_dy(tester, 'tail')));
    // Les en-têtes coiffent leur section, au bon endroit.
    expect(tester.getTopLeft(find.text('S1')).dy, lessThan(_dy(tester, 'a')));
    expect(tester.getTopLeft(find.text('S2')).dy, lessThan(_dy(tester, 'b')));
    expect(tester.getTopLeft(find.text('S2')).dy,
        greaterThan(_dy(tester, 'mid')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('① étalon : sans champ libre intercalé, le rendu reste celui '
      'd\'avant (tête libre, puis sections déclarées)', (tester) async {
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: const <ZFieldSpec>[
        // Champs libres déclarés EN TÊTE : l'ordre déclaré et l'ancien
        // regroupement coïncident — rien ne bouge pour cet hôte.
        ZFieldSpec(name: 'head', type: EditionFieldType.text, label: 'Head'),
        ZFieldSpec(name: 'mid', type: EditionFieldType.text, label: 'Mid'),
        ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
        ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
      ],
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: 'S1',
          fields: <String>['a'],
          style: ZEditionSectionStyle(),
        ),
        ZEditionSection(title: 'S2', fields: <String>['b']),
      ],
    )));
    await tester.pump();
    expect(_dy(tester, 'head'), lessThan(_dy(tester, 'mid')));
    expect(_dy(tester, 'mid'), lessThan(_dy(tester, 'a')));
    expect(_dy(tester, 'a'), lessThan(_dy(tester, 'b')));
  });

  testWidgets(
      '② section à titre VIDE : aucun en-tête — ni chrome, ni nœud '
      'sémantique — les champs rendus', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        // La section stylée force la voie groupée ; la section à titre vide
        // est le sujet mesuré.
        ZEditionSection(
          title: 'S1',
          fields: <String>['a'],
          style: ZEditionSectionStyle(),
        ),
        ZEditionSection(title: '', fields: <String>['b']),
      ],
    )));
    await tester.pump();

    // Les membres de la section sans titre sont rendus…
    expect(find.byKey(const ValueKey<String>('field:b')), findsOneWidget);
    // …mais AUCUN widget d'en-tête n'est monté pour elle (les en-têtes de
    // section sont keyés `section:<titre>`).
    expect(find.byKey(const ValueKey<String>('section:')), findsNothing);
    // Aucune ligne de texte vide (le coût d'~une ligne + padding a disparu).
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == ''),
      findsNothing,
    );
    // L'en-tête titré, lui, est bien là (étalon dans le même arbre).
    expect(find.text('S1'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
      '② repliable sans titre : pas de déclencheur — la section reste '
      'DÉPLIÉE, ses champs rendus', (tester) async {
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: '',
          fields: <String>['b'],
          collapsible: true,
        ),
      ],
    )));
    await tester.pump();
    // Aucun chevron (pas d'en-tête, donc pas de déclencheur de repli)…
    expect(find.byIcon(Icons.expand_less), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    // …et les membres sont montés (dépliée par construction).
    expect(find.byKey(const ValueKey<String>('field:b')), findsOneWidget);
  });

  testWidgets(
      '② icône SANS titre : l\'en-tête existe (l\'icône a quelque chose à '
      'montrer) mais ne monte AUCUN `Text` vide', (tester) async {
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(title: '', fields: <String>['b'], icon: Icons.star),
      ],
    )));
    await tester.pump();
    // L'icône déclarée est bien rendue : l'en-tête n'a pas été supprimé.
    expect(find.byIcon(Icons.star), findsOneWidget);
    // Mais aucun `Text` vide ne l'accompagne — pas de ligne sémantique vide.
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == ''),
      findsNothing,
    );
    expect(find.byKey(const ValueKey<String>('field:b')), findsOneWidget);
  });

  testWidgets('② étalon : une section TITRÉE garde son en-tête, inchangé',
      (tester) async {
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: 'Sec',
          fields: <String>['b'],
          collapsible: true,
        ),
      ],
    )));
    await tester.pump();
    expect(find.text('Sec'), findsOneWidget);
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    // Le repli fonctionne toujours.
    await tester.tap(find.text('Sec'));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('field:b')), findsNothing);
  });

  testWidgets(
      '② voie PLATE : même règle — un titre vide ne monte aucun en-tête',
      (tester) async {
    final controller = ZFormController(initialValues: _values);
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      // Aucun style/icône/repliable ⇒ voie plate.
      sections: const <ZEditionSection>[
        ZEditionSection(title: '', fields: <String>['b']),
      ],
    )));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('field:b')), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => w is Text && w.data == ''),
      findsNothing,
    );
  });
}
