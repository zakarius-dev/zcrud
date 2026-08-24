// CR-IFFD-92 ③ — icône, décoration d'en-tête et filet vertical côté début
// d'une ZEditionSection.
//
// Couvre :
//  - étalon hôte passif : sans style ni icône, l'en-tête reste la ligne nue
//    (aucune décoration, chevron conventionnel) ;
//  - icône de préfixe + décoration déclarée (fond, filet supérieur, rayon,
//    typographie) appliquées ;
//  - filet vertical CÔTÉ DÉBUT (BorderDirectional(start:)) couvrant les
//    champs, couleur/épaisseur déclarées, testé en LTR ET RTL ;
//  - chevron REMPLAÇABLE d'une section repliable stylée, repli fonctionnel.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
  ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
];

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('③ étalon hôte passif : en-tête nu, aucune décoration',
      (tester) async {
    final controller =
        ZFormController(initialValues: const <String, Object?>{'a': 'x'});
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(title: 'Sec', fields: <String>['a', 'b']),
      ],
    )));
    await tester.pump();
    expect(find.text('Sec'), findsOneWidget);
    // Aucune décoration d'en-tête n'est montée sans déclaration.
    expect(
      find.ancestor(of: find.text('Sec'), matching: find.byType(DecoratedBox)),
      findsNothing,
    );
    // L'en-tête natif est un `Padding → Text` nu : le chrome déclaré (qui
    // monte une `Row`) ne doit JAMAIS être emprunté sans déclaration.
    expect(
      find.ancestor(of: find.text('Sec'), matching: find.byType(Row)),
      findsNothing,
    );
    expect(find.byType(ClipRRect), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '③ étalon hôte passif (repliable) : chevron conventionnel, aucune '
      'décoration', (tester) async {
    final controller =
        ZFormController(initialValues: const <String, Object?>{'a': 'x'});
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: 'Sec',
          fields: <String>['a', 'b'],
          collapsible: true,
        ),
      ],
    )));
    await tester.pump();
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(
      find.ancestor(of: find.text('Sec'), matching: find.byType(DecoratedBox)),
      findsNothing,
    );
  });

  testWidgets('③ icône + décoration déclarées : fond, filet supérieur, rayon, '
      'typographie', (tester) async {
    final controller =
        ZFormController(initialValues: const <String, Object?>{'a': 'x'});
    addTearDown(controller.dispose);
    const style = ZEditionSectionStyle(
      background: Colors.amber,
      topAccent: BorderSide(color: Colors.red, width: 3),
      radius: BorderRadiusDirectional.only(
        topStart: Radius.circular(12),
        topEnd: Radius.circular(12),
      ),
      titleStyle: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
      iconColor: Colors.purple,
    );
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: 'Sec',
          fields: <String>['a', 'b'],
          icon: Icons.folder,
          style: style,
        ),
      ],
    )));
    await tester.pump();

    // Icône de préfixe, colorée par la déclaration.
    final icone = tester.widget<Icon>(find.byIcon(Icons.folder));
    expect(icone.color, Colors.purple);

    // Typographie du titre.
    final titre = tester.widget<Text>(find.text('Sec'));
    expect(titre.style?.fontSize, 30);
    expect(titre.style?.fontWeight, FontWeight.w900);

    // Fond + rayon : la DecoratedBox déclarée enveloppe l'en-tête.
    final deco = tester.widgetList<DecoratedBox>(
      find.ancestor(of: find.text('Sec'), matching: find.byType(DecoratedBox)),
    );
    final boites = <BoxDecoration>[
      for (final d in deco)
        if (d.decoration is BoxDecoration) d.decoration as BoxDecoration,
    ];
    expect(
      boites.any((b) => b.color == Colors.amber && b.borderRadius != null),
      isTrue,
      reason: 'fond et rayon déclarés doivent habiller l\'en-tête',
    );

    // Filet supérieur : bande rouge de 3 dp au-dessus de l'en-tête.
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == Colors.red,
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  group('③ filet vertical côté début', () {
    const style = ZEditionSectionStyle(
      startRailColor: Colors.blue,
      startRailWidth: 4,
    );

    Finder railFinder() => find.byWidgetPredicate((w) {
          if (w is! DecoratedBox) return false;
          final deco = w.decoration;
          if (deco is! BoxDecoration) return false;
          final border = deco.border;
          return border is BorderDirectional &&
              border.start.color == Colors.blue &&
              border.start.width == 4;
        });

    testWidgets('couvre les champs de la section (LTR)', (tester) async {
      final controller =
          ZFormController(initialValues: const <String, Object?>{'a': 'x'});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(DynamicEdition(
        controller: controller,
        fields: _fields,
        sections: const <ZEditionSection>[
          ZEditionSection(
            title: 'Sec',
            fields: <String>['a', 'b'],
            style: style,
          ),
        ],
      )));
      await tester.pump();
      expect(railFinder(), findsOneWidget);
      // Le filet enveloppe bien les CHAMPS (pas l'en-tête).
      expect(
        find.descendant(
          of: railFinder(),
          matching: find.byKey(const ValueKey<String>('a')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('directionnel : rendu RTL sans variante left/right',
        (tester) async {
      final controller =
          ZFormController(initialValues: const <String, Object?>{'a': 'x'});
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        DynamicEdition(
          controller: controller,
          fields: _fields,
          sections: const <ZEditionSection>[
            ZEditionSection(
              title: 'Sec',
              fields: <String>['a', 'b'],
              style: style,
            ),
          ],
        ),
        dir: TextDirection.rtl,
      ));
      await tester.pump();
      // Le filet est déclaré `BorderDirectional(start:)` : il bascule de côté
      // avec la direction — un `Border(left:)` échouerait ce prédicat.
      expect(railFinder(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('③ chevron remplaçable + repli fonctionnel d\'une section stylée',
      (tester) async {
    final controller =
        ZFormController(initialValues: const <String, Object?>{'a': 'x'});
    addTearDown(controller.dispose);
    const style = ZEditionSectionStyle(
      collapsedIcon: Icons.chevron_right,
      expandedIcon: Icons.keyboard_arrow_down,
    );
    await tester.pumpWidget(_host(DynamicEdition(
      controller: controller,
      fields: _fields,
      sections: const <ZEditionSection>[
        ZEditionSection(
          title: 'Sec',
          fields: <String>['a', 'b'],
          collapsible: true,
          initiallyExpanded: false,
          style: style,
        ),
      ],
    )));
    await tester.pump();
    // Repliée : chevron déclaré, champs masqués.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byKey(const ValueKey<String>('a')), findsNothing);

    await tester.tap(find.text('Sec'));
    await tester.pump();
    expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('a')), findsOneWidget);
  });
}
