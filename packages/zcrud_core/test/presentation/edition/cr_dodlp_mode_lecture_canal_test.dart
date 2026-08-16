// CR DODLP (2026-08-16) — « le mode lecture se perd dès qu'un builder
// reconstruit le champ ».
//
// En consultation, un formulaire doit rendre des FICHES (`ZReadOnlyFieldCard` :
// label au-dessus de la valeur, ni bordure ni libellé flottant ni ornement) —
// quelle que soit sa présentation (à plat, à étapes) et à quelque profondeur
// que soit le champ (sous-liste, item dynamique).
//
// Sonde du CR : le nombre d'`InputDecorator` montés. C'est le widget que
// Material monte pour la bordure et le libellé flottant — donc la signature
// exacte d'un « formulaire désactivé » là où une fiche est attendue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _texte = ZFieldSpec(
  name: 'nom',
  type: EditionFieldType.text,
  label: 'Nom',
);

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
  ZFieldSpec(name: 'f2', type: EditionFieldType.number, label: 'F2'),
  ZFieldSpec(name: 'f3', type: EditionFieldType.dateTime, label: 'F3'),
];

const _itemValues = <String, dynamic>{
  'f1': 'Alpha',
  'f2': 42,
  'f3': '2026-08-16',
};

/// Enveloppe d'hôte. La [cle] distingue deux montages successifs dans un même
/// test : le mode de rendu d'un champ est arrêté à son MONTAGE (une fiche
/// n'alloue ni contrôleur de texte ni clavier), exactement comme le fait
/// l'écran assemblé, qui keye la place sur le mode. Sans clé distincte, le
/// second `pumpWidget` réutiliserait l'`Element` du premier et la garde
/// mesurerait le mode précédent.
Widget _app(Widget child, {String cle = 'unique'}) => MaterialApp(
      home: ZcrudScope(
        key: ValueKey<String>(cle),
        acl: const ZAllowAllAcl(),
        child: Scaffold(body: child),
      ),
    );

/// Hôte possédant le contrôleur (aucune fuite en test).
class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.builder});

  final ZFormController controller;
  final Widget Function(ZFormController controller) builder;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controller);
}

ZFormController _controllerOf(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _hosted(
  Map<String, Object?> values,
  Widget Function(ZFormController controller) builder,
) =>
    _Host(controller: _controllerOf(values), builder: builder);

ZEditionStep _step(List<String> names) =>
    ZEditionStep(title: 'Étape', fields: names);

void main() {
  group('(a) La fenêtre à étapes rend des fiches en consultation', () {
    testWidgets('ZStepperEdition(readOnly: true) — 0 InputDecorator, 1 fiche',
        (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => ZStepperEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          steps: <ZEditionStep>[_step(const <String>['nom'])],
          readOnly: true,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(InputDecorator), findsNothing);
      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
      // (h) la valeur reste rendue — une fiche vide n'est pas une fiche.
      expect(find.text('Ada'), findsOneWidget);
      expect(find.text('Nom'), findsWidgets);
    });

    testWidgets('même sonde sur DynamicEdition(readOnly: true) — référence',
        (tester) async {
      await tester.pumpWidget(_app(
        _hosted(
          const <String, Object?>{'nom': 'Ada'},
          (c) => DynamicEdition(
            controller: c,
            fields: const <ZFieldSpec>[_texte],
            shrinkWrap: true,
          ),
        ),
        cle: 'edition',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ZReadOnlyFieldCard), findsNothing);
      expect(find.byType(InputDecorator), findsOneWidget);

      await tester.pumpWidget(_app(
        _hosted(
          const <String, Object?>{'nom': 'Ada'},
          (c) => DynamicEdition(
            controller: c,
            fields: const <ZFieldSpec>[_texte],
            shrinkWrap: true,
            readOnly: true,
          ),
        ),
        cle: 'lecture',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(InputDecorator), findsNothing);
      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
    });

    testWidgets('le mode est lisible PARTOUT dans l\'assistant, chrome compris',
        (tester) async {
      bool? luDansLeChrome;
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => ZStepperEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          config: const ZStepperConfig(showSubtitles: true),
          steps: <ZEditionStep>[
            ZEditionStep(
              title: 'Étape',
              fields: const <String>['nom'],
              // Le sous-titre est rendu par le CHROME, hors de la zone
              // d'étape : ce que lit ce widget est donc bien le mode posé par
              // l'assistant lui-même, pas celui d'une étape.
              subtitleWidget: Builder(
                builder: (context) {
                  luDansLeChrome = ZReadModeScope.of(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
          readOnly: true,
        ),
      )));
      await tester.pumpAndSettle();

      expect(luDansLeChrome, isTrue);
    });

    testWidgets('un builder de champ FOURNI ne perd pas le mode',
        (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          shrinkWrap: true,
          readOnly: true,
          // Builder de remplacement qui ne connaît PAS le drapeau : c'est le
          // cas exact que le CR relève (quatre sites sur six).
          fieldBuilder: (context, controller, field) =>
              ZFieldWidget(controller: controller, field: field),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(InputDecorator), findsNothing);
      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
    });
  });

  group('(b) Les champs INTERNES d\'une sous-liste en lecture', () {
    ZFieldSpec sousListe(ZSubListDisplayMode mode) => ZFieldSpec(
          name: 'items',
          type: EditionFieldType.subItems,
          label: 'Items',
          config: ZSubListConfig(
            itemFields: _itemFields,
            displayMode: mode,
            summaryFields: const <String>['f1'],
          ),
        );

    Widget formulaire(ZSubListDisplayMode mode) => _app(_hosted(
          <String, Object?>{
            'items': const <Map<String, dynamic>>[_itemValues],
          },
          (c) => DynamicEdition(
            controller: c,
            fields: <ZFieldSpec>[sousListe(mode)],
            shrinkWrap: true,
            readOnly: true,
          ),
        ));

    testWidgets('inline — les trois champs sont des fiches', (tester) async {
      await tester.pumpWidget(formulaire(ZSubListDisplayMode.inline));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(3));
      expect(find.byType(InputDecorator), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('compact — la consultation d\'un item rend des fiches',
        (tester) async {
      await tester.pumpWidget(formulaire(ZSubListDisplayMode.compact));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(3));
      expect(find.byType(InputDecorator), findsNothing);
      expect(find.text('Alpha'), findsWidgets);
    });

    testWidgets('tags — la consultation d\'une puce rend des fiches',
        (tester) async {
      await tester.pumpWidget(formulaire(ZSubListDisplayMode.tags));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InputChip));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(3));
      expect(find.byType(InputDecorator), findsNothing);
    });
  });

  group('(c) Les champs internes d\'un item dynamique en lecture', () {
    testWidgets('les trois champs de l\'item sont des fiches', (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'item': _itemValues},
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[
            ZFieldSpec(
              name: 'item',
              type: EditionFieldType.dynamicItem,
              label: 'Item',
              config: ZSubListConfig(itemFields: _itemFields),
            ),
          ],
          shrinkWrap: true,
          readOnly: true,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNWidgets(3));
      expect(find.byType(InputDecorator), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
    });
  });

  group('(d) Contre-témoin — une fenêtre à étapes en ÉDITION est inchangée',
      () {
    testWidgets('rendu, géométrie et sonde identiques', (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => ZStepperEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          steps: <ZEditionStep>[_step(const <String>['nom'])],
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNothing);
      expect(find.byType(InputDecorator), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      // Géométrie EXACTE : mesurée avant le correctif, réaffirmée après.
      expect(
        tester.getRect(find.byType(InputDecorator)),
        rectMoreOrLessEquals(const Rect.fromLTRB(12, 60, 788, 116)),
      );
    });
  });

  group('(e) Contre-témoin — un formulaire à plat en lecture est inchangé', () {
    testWidgets('rendu et géométrie identiques', (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          shrinkWrap: true,
          readOnly: true,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
      // Géométrie EXACTE de la forme par défaut. Elle a changé avec le passage
      // aux valeurs legacy (rang de 72 posé à plat, au lieu de la carte
      // encadrée de 92) : c'est la rupture visuelle assumée, et cette garde en
      // porte la mesure.
      expect(
        tester.getRect(find.byType(ZReadOnlyFieldCard)),
        rectMoreOrLessEquals(const Rect.fromLTRB(12, 12, 788, 84)),
      );
      expect(find.text('Ada'), findsOneWidget);
      expect(
        tester.getRect(find.text('Ada')),
        rectMoreOrLessEquals(const Rect.fromLTRB(28, 50, 70.8, 70), epsilon: 0.1),
      );
    });
  });

  group('(f) Le paramètre explicite PRIME sur le contexte', () {
    testWidgets('une surface en lecture peut forcer un champ en édition',
        (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          shrinkWrap: true,
          readOnly: true,
          fieldBuilder: (context, controller, field) => ZFieldWidget(
            controller: controller,
            field: field,
            readMode: false,
          ),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsNothing);
      expect(find.byType(InputDecorator), findsOneWidget);
    });

    testWidgets('une surface en édition peut forcer un champ en fiche',
        (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => DynamicEdition(
          controller: c,
          fields: const <ZFieldSpec>[_texte],
          shrinkWrap: true,
          fieldBuilder: (context, controller, field) => ZFieldWidget(
            controller: controller,
            field: field,
            readMode: true,
          ),
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
      expect(find.byType(InputDecorator), findsNothing);
      expect(find.text('Ada'), findsOneWidget);
    });
  });

  group('(g) Aucun ornement n\'est rendu en mode fiche', () {
    const orne = ZFieldSpec(
      name: 'nom',
      type: EditionFieldType.text,
      label: 'Nom',
      suffix: ZFieldAdornment.text('€'),
    );

    testWidgets('le suffixe déclaré disparaît en consultation, à étapes aussi',
        (tester) async {
      await tester.pumpWidget(_app(
        _hosted(
          const <String, Object?>{'nom': 'Ada'},
          (c) => ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[orne],
            steps: <ZEditionStep>[_step(const <String>['nom'])],
          ),
        ),
        cle: 'edition',
      ));
      await tester.pumpAndSettle();
      // En édition, l'ornement est bien là (sinon la garde ne prouverait rien).
      expect(find.text('€'), findsOneWidget);

      await tester.pumpWidget(_app(
        _hosted(
          const <String, Object?>{'nom': 'Ada'},
          (c) => ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[orne],
            steps: <ZEditionStep>[_step(const <String>['nom'])],
            readOnly: true,
          ),
        ),
        cle: 'lecture',
      ));
      await tester.pumpAndSettle();
      expect(find.text('€'), findsNothing);
      expect(find.byType(ZReadOnlyFieldCard), findsOneWidget);
      expect(find.text('Ada'), findsOneWidget);
    });
  });

  group('Fiche encadrée / fiche à plat — jetons de fond et de filet', () {
    ShapeBorder? formeDeLaFiche(WidgetTester tester) => tester
        .widget<Card>(find.descendant(
          of: find.byType(ZReadOnlyFieldCard),
          matching: find.byType(Card),
        ))
        .shape;

    Color? fondDeLaFiche(WidgetTester tester) => tester
        .widget<Card>(find.descendant(
          of: find.byType(ZReadOnlyFieldCard),
          matching: find.byType(Card),
        ))
        .color;

    Widget fiche({ZcrudTheme? theme}) {
      const carte = ZReadOnlyFieldCard(label: 'Nom', value: Text('Ada'));
      return MaterialApp(
        home: Scaffold(
          body: theme == null
              ? carte
              : ZcrudScope(theme: theme, child: carte),
        ),
      );
    }

    testWidgets('défaut LEGACY : ni fond ni filet', (tester) async {
      await tester.pumpWidget(fiche());
      await tester.pumpAndSettle();

      // Fond dérivé du `ColorScheme` mais totalement translucide, et filet
      // ABSENT — le rendu du moteur legacy, sans aucune déclaration d'hôte.
      expect(fondDeLaFiche(tester)!.a, 0);
      expect(
        (formeDeLaFiche(tester)! as RoundedRectangleBorder).side.style,
        BorderStyle.none,
      );
    });

    testWidgets('fiche ENCADRÉE : deux jetons la ramènent', (tester) async {
      final scheme = ThemeData().colorScheme;
      await tester.pumpWidget(fiche(
        theme: ZcrudTheme(
          readFillColor: scheme.surfaceContainerLow,
          readBorderWidth: 1,
        ),
      ));
      await tester.pumpAndSettle();

      expect(fondDeLaFiche(tester), scheme.surfaceContainerLow);
      final side = (formeDeLaFiche(tester)! as RoundedRectangleBorder).side;
      expect(side.style, BorderStyle.solid);
      expect(side.width, 1);
      expect(side.color, scheme.outline);
    });

    testWidgets('fiche à plat : aucun filet, fond transparent', (tester) async {
      await tester.pumpWidget(fiche(
        theme: const ZcrudTheme(
          readFillColor: Color(0x00000000),
          readBorderWidth: 0,
        ),
      ));
      await tester.pumpAndSettle();

      expect(fondDeLaFiche(tester), const Color(0x00000000));
      final side = (formeDeLaFiche(tester)! as RoundedRectangleBorder).side;
      // Largeur nulle ⇒ AUCUN trait (et non un filet d'un pixel physique).
      expect(side.style, BorderStyle.none);
    });

    testWidgets('le filet de la fiche est indépendant des champs de saisie',
        (tester) async {
      await tester.pumpWidget(_app(_hosted(
        const <String, Object?>{'nom': 'Ada'},
        (c) => ZcrudScope(
          theme: const ZcrudTheme(readBorderWidth: 0),
          child: DynamicEdition(
            controller: c,
            fields: const <ZFieldSpec>[_texte],
            shrinkWrap: true,
          ),
        ),
      )));
      await tester.pumpAndSettle();

      // Le champ de SAISIE garde son encadrement : le jeton de la fiche ne
      // gouverne que la fiche.
      expect(find.byType(InputDecorator), findsOneWidget);
      final deco = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(deco.decoration.enabledBorder, isNotNull);
    });
  });
}
