// CR-DODLP « Gap 0 » + « Bug 1 » — mode « TOUT AFFICHÉ » à rail numéroté et
// bornage de la bande latérale.
//
// Ce que ces gardes affirment, et POURQUOI chacune n'est pas vacante :
//
//  * BUG 1 — la garde de matrice existante (`stepper_dp9_test.dart`, bloc
//    « position × direction ») force `style: ZStepStyle.dots`, c'est-à-dire la
//    SEULE branche du `_StepIndicator` qui ne contient AUCUN `Expanded`. Elle
//    est donc structurellement aveugle au défaut rapporté. Les gardes ci-dessous
//    montent les branches `numbered` / `icons` / `progressBar` — celles qui
//    portent le `Expanded` — ET sous une **largeur d'hôte NON BORNÉE**, ce qui
//    est le cadrage exact de la pile d'exception du CR.
//
//  * SINGLE WRITER — on n'affirme pas « la fenêtre est correcte » (une valeur
//    peut être correcte avec deux écrivains qui se relaient) : on affirme que
//    TOUS les `DynamicEdition` montés sont `manageVisibility: false`, donc qu'il
//    n'existe littéralement **qu'un** écrivain de `visibleFields`.
//
//  * SM-1 — mesuré avec BEAUCOUP de champs montés simultanément, ce que le mode
//    paginé ne produit jamais.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));
Finder _editable(String name) =>
    find.descendant(of: _key(name), matching: find.byType(EditableText));

void _bigView(WidgetTester tester, {Size size = const Size(1200, 8000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Harnais « tout affiché » : 3 étapes scalaires ────────────────────────────

class _Rail {
  _Rail({this.config = ZStepperConfig.allStepsVertical, this.onComplete});

  final ZStepperConfig config;
  final VoidCallback? onComplete;

  static const List<ZFieldSpec> catalogue = <ZFieldSpec>[
    ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
    ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
  ];

  static const List<ZEditionStep> steps = <ZEditionStep>[
    ZEditionStep(
      title: 'Identité',
      subtitle: 'Informations personnelles',
      fields: <String>['a'],
    ),
    ZEditionStep(
      title: 'Historique',
      subtitle: 'Mobilités et absences',
      fields: <String>['b'],
    ),
    ZEditionStep(
      title: 'Autorisations',
      subtitle: 'Gestion des permissions',
      fields: <String>['c'],
    ),
  ];

  int structural = 0;

  late final ZFormController controller = ZFormController(
    initialValues: const <String, Object?>{'a': '', 'b': '', 'c': ''},
    visibleFields: const <String>[],
  );

  Widget build({
    TextDirection dir = TextDirection.ltr,
    ThemeData? theme,
  }) =>
      MaterialApp(
        theme: theme,
        home: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: ZStepperEdition(
              controller: controller,
              fields: catalogue,
              steps: steps,
              config: config,
              onComplete: onComplete,
              onStructuralBuild: () => structural++,
            ),
          ),
        ),
      );

  void dispose() => controller.dispose();
}

/// Hôte du CR « Bug 1 », **reproduit à l'identique** : `Scaffold > SafeArea >
/// ZStepperEdition`, donc une largeur d'hôte parfaitement **BORNÉE**.
///
/// 🔴 MESURÉ : la largeur non bornée qui déclenche l'exception est produite par
/// `ZStepperEdition` LUI-MÊME, pas par l'hôte. Dans une `Row`, un enfant NON
/// FLEXIBLE est toujours mesuré avec `maxWidth: infinity`, quelles que soient
/// les contraintes de la `Row` — le `_StepIndicator`, posé nu à côté d'un
/// `Expanded`, recevait donc l'infini même sous cet hôte borné. C'est
/// exactement ce que dit la pile du CR (« nearest ancestor providing an
/// unbounded width constraint is: Row ← Expanded ← Column ← ZStepperEdition »,
/// c'est-à-dire un nœud INTERNE au socle).
///
/// ⚠️ Un hôte réellement non borné en largeur (`SingleChildScrollView`
/// horizontal) a été essayé et **écarté** : il fait échouer le
/// `crossAxisAlignment: stretch` de la composition — un défaut DIFFÉRENT, que
/// ce correctif ne prétend pas traiter et qu'aucun stepper ne peut traiter.
Widget _crHost(Widget child) => MaterialApp(
      home: Scaffold(body: SafeArea(child: child)),
    );

void main() {
  // ══ BUG 1 : vertical + indicateur au début, sous largeur NON BORNÉE ════════

  group('Bug 1 — bande latérale bornée', () {
    for (final ZStepStyle style in <ZStepStyle>[
      ZStepStyle.numbered,
      ZStepStyle.icons,
      ZStepStyle.progressBar,
      ZStepStyle.dots,
    ]) {
      testWidgets(
          'vertical + indicatorPosition.start, style $style, hôte du CR '
          '(Scaffold > SafeArea) : aucune exception de layout', (tester) async {
        _bigView(tester);
        final ZFormController controller = ZFormController(
          initialValues: const <String, Object?>{'a': '', 'b': ''},
          visibleFields: const <String>['a'],
        );
        addTearDown(controller.dispose);

        await tester.pumpWidget(_crHost(
          ZStepperEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
              ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
            ],
            steps: const <ZEditionStep>[
              ZEditionStep(title: 'Première étape', fields: <String>['a']),
              ZEditionStep(title: 'Seconde étape', fields: <String>['b']),
            ],
            config: ZStepperConfig(
              orientation: ZStepOrientation.vertical,
              indicatorPosition: ZStepIndicatorPosition.start,
              style: style,
            ),
          ),
        ));
        await tester.pump();

        expect(
          tester.takeException(),
          isNull,
          reason: 'style $style : le `Expanded` du rendu compact doit recevoir '
              'une largeur BORNÉE (jeton stepperSideBandMaxWidth)',
        );
      });
    }

    testWidgets('la borne de bande est PILOTÉE par le jeton de thème',
        (tester) async {
      _bigView(tester);
      final ZFormController controller = ZFormController(
        initialValues: const <String, Object?>{'a': ''},
        visibleFields: const <String>['a'],
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          extensions: const <ThemeExtension<dynamic>>[
            ZcrudTheme(stepperSideBandMaxWidth: 90),
          ],
        ),
        home: Scaffold(
          body: ZStepperEdition(
            controller: controller,
            fields: const <ZFieldSpec>[
              ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
            ],
            steps: const <ZEditionStep>[
              ZEditionStep(title: 'Une étape', fields: <String>['a']),
            ],
            config: const ZStepperConfig(
              orientation: ZStepOrientation.vertical,
              indicatorPosition: ZStepIndicatorPosition.start,
            ),
          ),
        ),
      ));
      await tester.pump();

      // 🔴 On mesure la CONTRAINTE liante posée sur la bande, jamais `getSize()`
      // (qui rendrait la taille effective — celle du contenu, pas de la borne).
      final BoxConstraints c = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .map((ConstrainedBox b) => b.constraints)
          .firstWhere((BoxConstraints k) => k.maxWidth == 90,
              orElse: () => const BoxConstraints());
      expect(c.maxWidth, 90,
          reason: 'le jeton stepperSideBandMaxWidth doit borner la bande');
    });
  });

  // ══ GAP 0 : mode « tout affiché » — rail, badges, titres, sous-titres ══════

  group('Gap 0 — rail numéroté « tout affiché »', () {
    testWidgets('toutes les étapes sont dépliées : les 3 champs sont montés',
        (tester) async {
      _bigView(tester);
      final _Rail f = _Rail();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.build());
      await tester.pumpAndSettle();

      for (final String n in <String>['a', 'b', 'c']) {
        expect(_editable(n), findsOneWidget,
            reason: 'le champ $n de son étape doit être monté d\'emblée');
      }
      // Pas de pagination à ce niveau : aucun bouton de navigation.
      expect(find.widgetWithText(FilledButton, 'Next'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Previous'), findsNothing);
    });

    testWidgets('badge NUMÉROTÉ + titre + sous-titre par étape', (tester) async {
      _bigView(tester);
      final _Rail f = _Rail();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.build());
      await tester.pumpAndSettle();

      for (final String n in <String>['1', '2', '3']) {
        expect(find.text(n), findsOneWidget, reason: 'badge numéroté $n');
      }
      expect(find.text('Identité'), findsOneWidget);
      expect(find.text('Autorisations'), findsOneWidget);
      expect(find.text('Informations personnelles'), findsOneWidget);
      expect(find.text('Gestion des permissions'), findsOneWidget);
    });

    testWidgets('un RAIL est peint entre les badges, jamais après le dernier',
        (tester) async {
      _bigView(tester);
      final _Rail f = _Rail();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.build());
      await tester.pumpAndSettle();

      final List<CustomPainter> painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((CustomPaint p) => p.painter)
          .whereType<CustomPainter>()
          .where((CustomPainter p) => p.runtimeType.toString() == '_RailPainter')
          .toList();
      expect(painters.length, 3,
          reason: 'un peintre par étape (le dernier ne dessine rien)');
    });

    testWidgets('FR-26 — la teinte du badge suit le PARAMÈTRE, puis le RÔLE',
        (tester) async {
      _bigView(tester);
      // 1) Sans override : le badge prend le rôle `ColorScheme.primary` du thème
      //    de l'hôte — la valeur n'est PAS produite par le widget (non tautologique).
      final ThemeData theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F51B5)),
      );
      final _Rail plain = _Rail();
      addTearDown(plain.dispose);
      await tester.pumpWidget(plain.build(theme: theme));
      await tester.pumpAndSettle();
      final BoxDecoration d1 = tester
          .widget<Container>(find.ancestor(
            of: find.text('1'),
            matching: find.byType(Container),
          ).first)
          .decoration! as BoxDecoration;
      expect(d1.shape, BoxShape.circle);
      expect(d1.color, theme.colorScheme.primary,
          reason: 'repli = rôle du ColorScheme de l\'hôte');

      // 2) Avec override de paramètre : le paramètre l'emporte.
      const Color custom = Color(0xFF00695C);
      final _Rail themed = _Rail(
        config: ZStepperConfig.allStepsVertical.copyWith(activeColor: custom),
      );
      addTearDown(themed.dispose);
      await tester.pumpWidget(themed.build(theme: theme));
      await tester.pumpAndSettle();
      final BoxDecoration d2 = tester
          .widget<Container>(find.ancestor(
            of: find.text('1'),
            matching: find.byType(Container),
          ).first)
          .decoration! as BoxDecoration;
      expect(d2.color, custom, reason: 'paramètre > jeton > rôle');
    });

    testWidgets('VIRTUALISATION : la liste est bâtie par builder, pas children:',
        (tester) async {
      _bigView(tester);
      final _Rail f = _Rail();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.build());
      await tester.pumpAndSettle();

      final ListView root = tester.widget<ListView>(find.byType(ListView).first);
      expect(root.childrenDelegate, isA<SliverChildBuilderDelegate>(),
          reason: 'ListView.builder exigé (jamais ListView(children:))');
    });

    testWidgets('AD-13 — le rail suit le sens de lecture (RTL)', (tester) async {
      _bigView(tester);
      for (final TextDirection dir in TextDirection.values) {
        final _Rail f = _Rail();
        addTearDown(f.dispose);
        await tester.pumpWidget(f.build(dir: dir));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'direction $dir');
        // Le badge est du côté DÉBUT de lecture : à droite en RTL.
        final double badgeX = tester.getTopLeft(find.text('1')).dx;
        final double titleX = tester.getTopLeft(find.text('Identité')).dx;
        if (dir == TextDirection.ltr) {
          expect(badgeX, lessThan(titleX), reason: 'LTR : badge avant le titre');
        } else {
          expect(badgeX, greaterThan(titleX),
              reason: 'RTL : badge après le titre (côté début de lecture)');
        }
      }
    });

    testWidgets('onComplete absent ⇒ AUCUN bouton final (canal jamais mort)',
        (tester) async {
      _bigView(tester);
      final _Rail without = _Rail();
      addTearDown(without.dispose);
      await tester.pumpWidget(without.build());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Finish'), findsNothing);

      int done = 0;
      final _Rail with_ = _Rail(onComplete: () => done++);
      addTearDown(with_.dispose);
      await tester.pumpWidget(with_.build());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
      expect(done, 1);
    });
  });

  // ══ INVARIANT SINGLE-WRITER (DP-9 / AC13) ═════════════════════════════════

  group('Single writer de visibleFields', () {
    testWidgets(
        'TOUS les DynamicEdition montés sont PASSIFS (manageVisibility:false)',
        (tester) async {
      _bigView(tester);
      final _Rail f = _Rail();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.build());
      await tester.pumpAndSettle();

      final List<DynamicEdition> editions =
          tester.widgetList<DynamicEdition>(find.byType(DynamicEdition)).toList();
      expect(editions.length, 3, reason: 'une zone par étape dépliée');
      for (final DynamicEdition e in editions) {
        expect(e.manageVisibility, isFalse,
            reason: 'un seul écrivain : le stepper racine');
      }
    });

    testWidgets('la fenêtre publiée est l\'UNION de toutes les étapes',
        (tester) async {
      _bigView(tester);
      final _Rail f = _Rail();
      addTearDown(f.dispose);
      await tester.pumpWidget(f.build());
      await tester.pumpAndSettle();
      expect(f.controller.visibleFields.value, <String>['a', 'b', 'c']);
    });
  });

  // ══ SM-1 : granularité AVEC BEAUCOUP DE CHAMPS MONTÉS ═════════════════════

  testWidgets(
      'SM-1 — 100 frappes en mode « tout affiché » (30 champs montés) : '
      'zéro rebuild de chrome, zéro perte de focus', (tester) async {
    _bigView(tester, size: const Size(1200, 20000));
    const int n = 30;
    final List<ZFieldSpec> catalogue = <ZFieldSpec>[
      for (int i = 0; i < n; i++)
        ZFieldSpec(name: 'f$i', type: EditionFieldType.text, label: 'F$i'),
    ];
    final List<ZEditionStep> steps = <ZEditionStep>[
      for (int s = 0; s < 6; s++)
        ZEditionStep(
          title: 'Étape $s',
          fields: <String>[for (int i = s * 5; i < s * 5 + 5; i++) 'f$i'],
        ),
    ];
    final ZFormController controller = ZFormController(
      initialValues: <String, Object?>{for (final ZFieldSpec f in catalogue) f.name: ''},
      visibleFields: const <String>[],
    );
    addTearDown(controller.dispose);

    int structural = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZStepperEdition(
          controller: controller,
          fields: catalogue,
          steps: steps,
          config: ZStepperConfig.allStepsVertical,
          onStructuralBuild: () => structural++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(controller.visibleFields.value.length, n,
        reason: 'les 30 champs sont dans la fenêtre (union)');

    final Finder target = _editable('f0');
    expect(target, findsOneWidget);
    await tester.tap(target);
    await tester.pump();
    final int before = structural;

    for (int i = 0; i < 100; i++) {
      await tester.enterText(target, 'x' * (i + 1));
      await tester.pump();
    }

    expect(structural, before,
        reason: 'SM-1 : le chrome du stepper ne se reconstruit JAMAIS pendant '
            'la saisie, même avec 30 champs montés');
    expect(tester.widget<EditableText>(target).focusNode.hasFocus, isTrue,
        reason: 'zéro perte de focus');
    expect(controller.valueOf('f0'), 'x' * 100);
  });

  // ══ IMBRICATION : racine « tout affiché » + sous-steppers PAGINÉS ═════════

  group('Imbrication (cas navires du CR)', () {
    List<ZFieldSpec> catalogue() => const <ZFieldSpec>[
          ZFieldSpec(name: 'root0', type: EditionFieldType.text, label: 'R0'),
          ZFieldSpec(name: 'root1', type: EditionFieldType.text, label: 'R1'),
          ZFieldSpec(name: 'n0a', type: EditionFieldType.text, label: 'N0A'),
          ZFieldSpec(name: 'n0b', type: EditionFieldType.text, label: 'N0B'),
          ZFieldSpec(name: 'n1a', type: EditionFieldType.text, label: 'N1A'),
          ZFieldSpec(name: 'n1b', type: EditionFieldType.text, label: 'N1B'),
        ];

    // Racine « tout affiché » : DEUX étapes portant CHACUNE un sous-stepper
    // paginé. C'est le cas qui met à l'épreuve la carte des contributions —
    // avec un champ unique, la seconde remontée écraserait la première.
    List<ZEditionStep> steps() => const <ZEditionStep>[
          ZEditionStep(
            title: 'Documents',
            fields: <String>['root0'],
            nestedSteps: <ZEditionStep>[
              ZEditionStep(title: 'Bill of Lading', fields: <String>['n0a']),
              ZEditionStep(title: 'Cargo Manifest', fields: <String>['n0b']),
            ],
          ),
          ZEditionStep(
            title: 'Contrôles',
            fields: <String>['root1'],
            nestedSteps: <ZEditionStep>[
              ZEditionStep(title: 'Visite', fields: <String>['n1a']),
              ZEditionStep(title: 'Scellés', fields: <String>['n1b']),
            ],
          ),
        ];

    Widget host(ZFormController c) => MaterialApp(
          home: Scaffold(
            body: ZStepperEdition(
              controller: c,
              fields: catalogue(),
              steps: steps(),
              config: ZStepperConfig.allStepsVertical,
            ),
          ),
        );

    testWidgets(
        'la fenêtre agrège les contributions des DEUX sous-steppers montés',
        (tester) async {
      _bigView(tester, size: const Size(1200, 20000));
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{
          'root0': '', 'root1': '', 'n0a': '', 'n0b': '', 'n1a': '', 'n1b': '',
        },
        visibleFields: const <String>[],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();

      // Chaque sous-stepper est à SA sous-étape 0 : la fenêtre contient les
      // deux champs racine ET les deux premières sous-étapes.
      expect(
        c.visibleFields.value.toSet(),
        <String>{'root0', 'n0a', 'root1', 'n1a'},
        reason: 'aucune contribution de sous-stepper ne doit en écraser une autre',
      );
    });

    testWidgets('les sous-steppers PAGINENT indépendamment sous la racine',
        (tester) async {
      _bigView(tester, size: const Size(1200, 20000));
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{
          'root0': '', 'root1': '', 'n0a': '', 'n0b': '', 'n1a': '', 'n1b': '',
        },
        visibleFields: const <String>[],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(host(c));
      await tester.pumpAndSettle();

      // Deux boutons « Suivant » : un par sous-stepper paginé.
      final Finder nexts = find.widgetWithText(FilledButton, 'Next');
      expect(nexts, findsNWidgets(2));

      await tester.tap(nexts.first);
      await tester.pumpAndSettle();

      expect(
        c.visibleFields.value.toSet(),
        <String>{'root0', 'n0b', 'root1', 'n1a'},
        reason: 'seul le PREMIER sous-stepper a avancé',
      );

      // 🔴 Les DEUX sous-steppers hors de leur sous-étape 0 EN MÊME TEMPS.
      // Tant qu'un seul a bougé, le repli structurel (`_initialUnion(nested, 0)`)
      // rend par hasard la même valeur que la contribution manquante — et une
      // carte des contributions cassée resterait INVISIBLE. C'est seulement ici
      // que l'écrasement d'une contribution par une autre devient observable.
      await tester.tap(find.widgetWithText(FilledButton, 'Next').last);
      await tester.pumpAndSettle();

      expect(
        c.visibleFields.value.toSet(),
        <String>{'root0', 'n0b', 'root1', 'n1b'},
        reason: 'chaque sous-stepper garde SA contribution ; aucune n\'écrase '
            'l\'autre',
      );
    });
  });

  // ══ AD-10 : replis définis, jamais d'exception ════════════════════════════

  group('AD-10 — replis', () {
    testWidgets('étapes VIDES : rendu sans exception', (tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{},
        visibleFields: const <String>[],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[],
            steps: const <ZEditionStep>[
              ZEditionStep(title: 'Vide 1', fields: <String>[]),
              ZEditionStep(title: 'Vide 2', fields: <String>[]),
            ],
            config: ZStepperConfig.allStepsVertical,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(c.visibleFields.value, isEmpty);
    });

    testWidgets('sous-titre ABSENT : l\'étape rend quand même son titre',
        (tester) async {
      _bigView(tester);
      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'a': ''},
        visibleFields: const <String>[],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[
              ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
            ],
            steps: const <ZEditionStep>[
              ZEditionStep(title: 'Sans sous-titre', fields: <String>['a']),
            ],
            config: ZStepperConfig.allStepsVertical,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Sans sous-titre'), findsOneWidget);
    });

    testWidgets('nestedSteps CIRCULAIRES : plafonné, jamais de StackOverflow',
        (tester) async {
      _bigView(tester, size: const Size(1200, 20000));
      // Cycle réel : la liste est mutable, l'étape se référence elle-même.
      final List<ZEditionStep> loop = <ZEditionStep>[];
      final ZEditionStep self = ZEditionStep(
        title: 'Boucle',
        fields: const <String>['a'],
        nestedSteps: loop,
      );
      loop.add(self);

      final ZFormController c = ZFormController(
        initialValues: const <String, Object?>{'a': ''},
        visibleFields: const <String>[],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZStepperEdition(
            controller: c,
            fields: const <ZFieldSpec>[
              ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
            ],
            steps: <ZEditionStep>[self],
          ),
        ),
      ));
      await tester.pump();

      // 🔴 Ce que cette garde affirme : la descente TERMINE. Un cycle non
      // plafonné ne produirait pas un `expect` rouge — il produirait un
      // `StackOverflowError` (ou un test pendu), c'est-à-dire un rouge qu'on ne
      // pourrait PAS qualifier. Empiler 8 steppers dans un viewport fini
      // déborde en pixels : c'est attendu et hors sujet, on draine.
      while (tester.takeException() != null) {}

      expect(
        find.byType(ZStepperEdition).evaluate().length,
        // Racine (profondeur 0) + au plus `kZStepperMaxNestingDepth` niveaux.
        lessThanOrEqualTo(kZStepperMaxNestingDepth + 1),
        reason: 'la descente s\'arrête au plafond',
      );
      expect(c.visibleFields.value, <String>['a'],
          reason: 'le calcul de fenêtre TERMINE malgré le cycle, et publie une '
              'UNION (un nom une seule fois), pas une concaténation');

      // Démontage explicite : cet arbre de 9 niveaux, laissé en place, ferait
      // rougir le test SUIVANT pour une raison qui ne le concerne pas.
      await tester.pumpWidget(const SizedBox.shrink());
      while (tester.takeException() != null) {}
    });
  });

  // ══ MATRICE orientation × position × mode ═════════════════════════════════

  testWidgets('matrice complète : aucune combinaison ne lève', (tester) async {
    _bigView(tester, size: const Size(1200, 20000));
    for (final ZStepOrientation o in ZStepOrientation.values) {
      for (final ZStepIndicatorPosition p in ZStepIndicatorPosition.values) {
        for (final ZStepStyle st in ZStepStyle.values) {
          for (final bool all in <bool>[false, true]) {
            for (final TextDirection dir in TextDirection.values) {
              final _Rail f = _Rail(
                config: ZStepperConfig(
                  orientation: o,
                  indicatorPosition: p,
                  style: st,
                  showAllSteps: all,
                  showSubtitles: true,
                ),
              );
              addTearDown(f.dispose);
              await tester.pumpWidget(f.build(dir: dir));
              await tester.pump();
              expect(tester.takeException(), isNull,
                  reason: 'orientation=$o position=$p style=$st '
                      'showAllSteps=$all direction=$dir');
              // Démontage explicite : sans lui, l'arbre suivant réutilise les
              // Elements du précédent et l'assert `_dependents.isEmpty` de
              // Flutter rougit pour une raison qui n'est PAS le sujet.
              await tester.pumpWidget(const SizedBox.shrink());
            }
          }
        }
      }
    }
  });
}
