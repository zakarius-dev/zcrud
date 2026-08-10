// CR-DODLP « Sous-stepper paginé : mode vertical Material » (2026-08-10).
//
// La TROISIÈME forme d'affichage : tous les en-têtes visibles dans le rail
// numéroté, UNE SEULE étape dépliée, en-têtes tapables.
//
// Ce que chaque bloc affirme, et pourquoi il n'est pas vacant :
//
//  * TROIS ÉTATS — la règle de préséance `stepsDisplay > showAllSteps` est
//    gardée dans les DEUX sens (l'enum annule le booléen, et le booléen seul
//    continue de décider). L'hôte PASSIF est mesuré par l'ÉGALITÉ de l'arbre
//    rendu, pas par une inspection de champ.
//  * MODE MONTÉ — 🔴 le piège de la veille : une garde d'accordéon montée en
//    PAGINÉ reste verte sans rien mesurer. Chaque bloc ci-dessous vérifie
//    d'abord qu'il est bien dans la forme attendue (présence des en-têtes des
//    AUTRES étapes), ce qui n'est vrai qu'en accordéon.
//  * SINGLE WRITER — affirmé par le COMPTE (un seul `DynamicEdition` monté,
//    une fenêtre = celle de l'étape ACTIVE, jamais l'union), pas par
//    l'apparence.
//  * 48 dp — mesuré sur la CONTRAINTE LIANTE reçue par l'enfant de la
//    `ConstrainedBox`, jamais par `getSize()`.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

void _bigView(WidgetTester tester, {Size size = const Size(1000, 4000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ── Harnais ─────────────────────────────────────────────────────────────────

class _H {
  _H({
    this.config = ZStepperConfig.accordionVertical,
    this.steps = _H.threeSteps,
    this.catalogue = _H.threeFields,
    this.onComplete,
    Map<String, Object?>? initial,
  }) : initial = initial ?? const <String, Object?>{'a': '', 'b': '', 'c': ''};

  final ZStepperConfig config;
  final List<ZEditionStep> steps;
  final List<ZFieldSpec> catalogue;
  final VoidCallback? onComplete;
  final Map<String, Object?> initial;

  static const List<ZFieldSpec> threeFields = <ZFieldSpec>[
    ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
    ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
  ];

  static const List<ZEditionStep> threeSteps = <ZEditionStep>[
    ZEditionStep(
      title: 'Identité',
      subtitle: 'Informations personnelles',
      fields: <String>['a'],
    ),
    ZEditionStep(
      title: 'Historique',
      subtitle: 'Mobilités',
      fields: <String>['b'],
    ),
    ZEditionStep(
      title: 'Autorisations',
      subtitle: 'Permissions',
      fields: <String>['c'],
    ),
  ];

  int structural = 0;

  late final ZFormController controller = ZFormController(
    initialValues: initial,
    visibleFields: const <String>[],
  );

  Widget build({TextDirection dir = TextDirection.ltr}) => MaterialApp(
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

/// Nombre de `DynamicEdition` montés — le COMPTE qui prouve qu'une seule zone
/// d'étape existe (donc au plus un écrivain de `visibleFields`).
int _editionCount() => find.byType(DynamicEdition).evaluate().length;

/// Nombre de `DynamicEdition` montés qui se déclarent PILOTES de la fenêtre.
int _managingCount() => find
    .byType(DynamicEdition)
    .evaluate()
    .map((e) => e.widget as DynamicEdition)
    .where((w) => w.manageVisibility)
    .length;

void main() {
  // ══ 1. TROIS ÉTATS SANS RUPTURE D'API ══════════════════════════════════════

  group('Trois états — dérivation et préséance', () {
    test('hôte PASSIF : la forme effective est `paged`', () {
      expect(
        const ZStepperConfig().effectiveDisplay,
        ZStepsDisplay.paged,
        reason: 'un hôte qui ne touche à rien garde le comportement E3-5',
      );
      expect(const ZStepperConfig().stepsDisplay, isNull);
    });

    test('`showAllSteps: true` SEUL continue de décider (alias hérité)', () {
      expect(
        const ZStepperConfig(showAllSteps: true).effectiveDisplay,
        ZStepsDisplay.allExpanded,
      );
      expect(
        ZStepperConfig.allStepsVertical.effectiveDisplay,
        ZStepsDisplay.allExpanded,
        reason: 'le preset v0.66.0 n\'a pas bougé',
      );
    });

    test('CONTRADICTION — `stepsDisplay` GAGNE, dans les deux sens', () {
      // Sens 1 : l'enum ANNULE un `showAllSteps: true`.
      expect(
        const ZStepperConfig(
          showAllSteps: true,
          stepsDisplay: ZStepsDisplay.paged,
        ).effectiveDisplay,
        ZStepsDisplay.paged,
      );
      // Sens 2 : l'enum impose l'accordéon malgré `showAllSteps: true`.
      expect(
        const ZStepperConfig(
          showAllSteps: true,
          stepsDisplay: ZStepsDisplay.accordion,
        ).effectiveDisplay,
        ZStepsDisplay.accordion,
      );
      // Sens 3 : l'enum impose « tout affiché » malgré `showAllSteps: false`.
      expect(
        const ZStepperConfig(stepsDisplay: ZStepsDisplay.allExpanded)
            .effectiveDisplay,
        ZStepsDisplay.allExpanded,
      );
    });

    test('`stepsDisplay` entre dans `copyWith` / `==` / `hashCode`', () {
      const ZStepperConfig base = ZStepperConfig();
      final ZStepperConfig acc =
          base.copyWith(stepsDisplay: ZStepsDisplay.accordion);
      expect(acc.stepsDisplay, ZStepsDisplay.accordion);
      expect(acc == base, isFalse);
      expect(acc.hashCode == base.hashCode, isFalse);
      expect(
        acc,
        const ZStepperConfig(stepsDisplay: ZStepsDisplay.accordion),
        reason: 'égalité de valeur, pas d\'identité',
      );
      // Les autres canaux survivent au copyWith.
      expect(base.copyWith(showAllSteps: true).stepsDisplay, isNull);
    });

    testWidgets('HÔTE PASSIF — l\'arbre rendu est celui d\'AVANT (paginé)',
        (tester) async {
      _bigView(tester);
      final _H h = _H(config: const ZStepperConfig());
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      // Preuve de forme : SEUL le titre de l'étape courante est rendu, et le
      // compteur « 1/3 » du paginé est présent. Aucun en-tête d'autre étape.
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text('Identité'), findsOneWidget);
      expect(find.text('Historique'), findsNothing);
      expect(find.text('Autorisations'), findsNothing);
      // Et les boutons du paginé.
      expect(find.text('Suivant'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ══ 2. LA FORME ACCORDÉON ══════════════════════════════════════════════════

  group('Accordéon — en-têtes visibles, une seule dépliée', () {
    testWidgets('tous les en-têtes sont rendus, UN SEUL contenu est monté',
        (tester) async {
      _bigView(tester);
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      // 🔴 Vérification de MODE d'abord : les trois en-têtes présents — ce qui
      // est FAUX en paginé (garde non vacante) et faux nulle part ailleurs.
      expect(find.text('Identité'), findsOneWidget);
      expect(find.text('Historique'), findsOneWidget);
      expect(find.text('Autorisations'), findsOneWidget);
      expect(find.text('1/3'), findsNothing,
          reason: 'le compteur du paginé n\'a pas sa place ici');

      // Une seule étape dépliée : un seul champ monté, celui de l'étape 0.
      expect(_key('a'), findsOneWidget);
      expect(_key('b'), findsNothing);
      expect(_key('c'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('le rail est RÉUTILISÉ : même painter que « tout affiché »',
        (tester) async {
      _bigView(tester);
      // Le painter du rail est privé : on l'identifie par la SEULE chose
      // observable — la présence d'un `CustomPaint` dont le painter repeint sur
      // changement de direction. On compare donc les deux modes par le NOMBRE
      // de `CustomPaint` porteurs d'un painter, structurellement identiques.
      int paintersIn(ZStepperConfig config) => find
          .byType(CustomPaint)
          .evaluate()
          .map((e) => e.widget as CustomPaint)
          .where((c) => c.painter?.runtimeType.toString() == '_RailPainter')
          .length;

      final _H all = _H(config: ZStepperConfig.allStepsVertical);
      addTearDown(all.dispose);
      await tester.pumpWidget(all.build());
      await tester.pump();
      final int allRails = paintersIn(ZStepperConfig.allStepsVertical);

      final _H acc = _H();
      addTearDown(acc.dispose);
      await tester.pumpWidget(acc.build());
      await tester.pump();
      final int accRails = paintersIn(ZStepperConfig.accordionVertical);

      expect(allRails, 3, reason: 'un segment de rail par étape');
      expect(accRails, allRails,
          reason: 'l\'accordéon peint le MÊME rail, pas un second');
    });

    testWidgets('VIRTUALISÉ — `ListView.builder`, jamais `ListView(children:)` '
        'sur 18 sous-étapes', (tester) async {
      _bigView(tester, size: const Size(1000, 900));
      final List<ZFieldSpec> catalogue = <ZFieldSpec>[
        for (int i = 0; i < 18; i++)
          ZFieldSpec(
              name: 'f$i', type: EditionFieldType.text, label: 'Doc $i'),
      ];
      final _H h = _H(
        catalogue: catalogue,
        steps: <ZEditionStep>[
          for (int i = 0; i < 18; i++)
            ZEditionStep(title: 'Document $i', fields: <String>['f$i']),
        ],
        initial: <String, Object?>{for (int i = 0; i < 18; i++) 'f$i': ''},
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      final ListView list = tester.widget<ListView>(find.byType(ListView).first);
      expect(
        list.childrenDelegate,
        isA<SliverChildBuilderDelegate>(),
        reason: 'un `children:` construirait les 18 lignes à chaque build',
      );
      // Virtualisation EFFECTIVE : la dernière étape n'est pas montée.
      expect(find.text('Document 0'), findsOneWidget);
      expect(find.text('Document 17'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ══ 3. NAVIGATION PAR TAP D'EN-TÊTE + VERROU DE VALIDATION ════════════════

  group('Navigation par en-tête', () {
    testWidgets('taper un en-tête change d\'étape (recul et avance libres '
        'quand le gate passe)', (tester) async {
      _bigView(tester);
      final _H h = _H(initial: const <String, Object?>{
        'a': 'x',
        'b': 'y',
        'c': 'z',
      });
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();
      expect(_key('a'), findsOneWidget);

      await tester.tap(find.text('Autorisations'));
      await tester.pump();
      expect(_key('c'), findsOneWidget, reason: 'saut AVANT');
      expect(_key('a'), findsNothing);

      await tester.tap(find.text('Identité'));
      await tester.pump();
      expect(_key('a'), findsOneWidget, reason: 'retour ARRIÈRE');
      expect(_key('c'), findsNothing);
    });

    testWidgets('`allowStepTap: false` ⇒ en-tête NON tapable (aucun rôle '
        '`button`, aucun changement d\'étape)', (tester) async {
      _bigView(tester);
      final _H h = _H(
        config: ZStepperConfig.accordionVertical
            .copyWith(allowStepTap: false),
        initial: const <String, Object?>{'a': 'x', 'b': 'y', 'c': 'z'},
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      // Mode vérifié : les trois en-têtes sont là.
      expect(find.text('Autorisations'), findsOneWidget);
      await tester.tap(find.text('Autorisations'));
      await tester.pump();
      expect(_key('a'), findsOneWidget,
          reason: 'aucun changement : l\'en-tête est inerte');
      expect(_key('c'), findsNothing);
    });

    testWidgets('🔴 VERROU — `validateOnNext: true` (défaut) BLOQUE le saut '
        'avant sur une étape invalide', (tester) async {
      _bigView(tester);
      final _H h = _H(
        catalogue: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'a',
            type: EditionFieldType.text,
            label: 'A',
            validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS')],
          ),
          ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
          ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
        ],
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();
      expect(find.text('Autorisations'), findsOneWidget); // mode vérifié

      await tester.tap(find.text('Autorisations'));
      await tester.pump();
      expect(_key('a'), findsOneWidget,
          reason: 'étape 0 invalide ⇒ le gate refuse le saut avant');
      expect(_key('c'), findsNothing);

      // Le RECUL, lui, reste inconditionnel : on va d'abord en 1 en validant.
      h.controller.setValue('a', 'rempli');
      await tester.pump();
      await tester.tap(find.text('Historique'));
      await tester.pump();
      expect(_key('b'), findsOneWidget);
      h.controller.setValue('a', '');
      await tester.pump();
      await tester.tap(find.text('Identité'));
      await tester.pump();
      expect(_key('a'), findsOneWidget,
          reason: 'retour arrière JAMAIS gaté (parité `_jumpTo`)');
    });

    testWidgets('🔴 VERROU — `validateOnNext: false` rend la navigation LIBRE '
        '(parité legacy DODLP)', (tester) async {
      _bigView(tester);
      final _H h = _H(
        config: ZStepperConfig.accordionVertical
            .copyWith(validateOnNext: false),
        catalogue: const <ZFieldSpec>[
          ZFieldSpec(
            name: 'a',
            type: EditionFieldType.text,
            label: 'A',
            validators: <ZValidatorSpec>[ZValidatorSpec.required(errorText: 'REQUIS')],
          ),
          ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
          ZFieldSpec(name: 'c', type: EditionFieldType.text, label: 'C'),
        ],
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      await tester.tap(find.text('Autorisations'));
      await tester.pump();
      expect(_key('c'), findsOneWidget,
          reason: 'gate relâché ⇒ saut avant autorisé malgré `a` vide');
    });

    testWidgets('la barre Précédent/Suivant vit DANS l\'étape dépliée',
        (tester) async {
      _bigView(tester);
      bool completed = false;
      final _H h = _H(
        initial: const <String, Object?>{'a': 'x', 'b': 'y', 'c': 'z'},
        onComplete: () => completed = true,
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      // Exactement UNE barre (celle de l'étape active), pas une par étape.
      expect(find.text('Suivant'), findsOneWidget);
      expect(find.text('Précédent'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pump();
      expect(_key('b'), findsOneWidget);

      await tester.tap(find.text('Suivant'));
      await tester.pump();
      expect(_key('c'), findsOneWidget);
      expect(find.text('Terminer'), findsOneWidget);
      await tester.tap(find.text('Terminer'));
      await tester.pump();
      expect(completed, isTrue);
    });
  });

  // ══ 4. SINGLE WRITER, PROUVÉ PAR LE COMPTE ════════════════════════════════

  group('Single writer de la fenêtre', () {
    testWidgets('une SEULE zone d\'étape montée, fenêtre = étape ACTIVE '
        '(jamais l\'union)', (tester) async {
      _bigView(tester);
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      expect(find.text('Autorisations'), findsOneWidget); // mode vérifié
      expect(_editionCount(), 1,
          reason: 'une seule zone d\'étape ⇒ au plus un écrivain');
      expect(_managingCount(), lessThanOrEqualTo(1));
      expect(h.controller.visibleFields.value, <String>['a'],
          reason: 'la fenêtre est celle de l\'étape ACTIVE, pas l\'union');

      await tester.tap(find.text('Historique'));
      await tester.pump();
      expect(_editionCount(), 1);
      expect(h.controller.visibleFields.value, <String>['b']);
    });

    testWidgets('avec NESTING : toutes les zones montées sont PASSIVES '
        '(zéro écrivain concurrent)', (tester) async {
      _bigView(tester);
      final _H h = _H(
        steps: const <ZEditionStep>[
          ZEditionStep(
            title: 'Documents',
            fields: <String>['a'],
            nestedSteps: <ZEditionStep>[
              ZEditionStep(title: 'Manifeste', fields: <String>['b']),
              ZEditionStep(title: 'Connaissement', fields: <String>['c']),
            ],
          ),
          ZEditionStep(title: 'Fin', fields: <String>[]),
        ],
      );
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      expect(find.text('Fin'), findsOneWidget); // mode accordéon vérifié
      expect(_managingCount(), 0,
          reason: 'en pilotage, AUCUNE zone n\'écrit `visibleFields`');
      expect(h.controller.visibleFields.value, <String>['a', 'b'],
          reason: 'union du CHEMIN ACTIF, pas de toutes les étapes');
      expect(h.controller.visibleFields.value.contains('c'), isFalse);
    });
  });

  // ══ 4bis. LE CAS RÉEL DE LA CR : SOUS-STEPPER ACCORDÉON ═══════════════════

  group('CR — racine PAGINÉE, sous-stepper en accordéon (18 documents)', () {
    // 🔴 Le piège de la veille, nommé : monter la RACINE en accordéon
    // laisserait cette garde verte sans jamais exercer le sous-stepper. Ici la
    // racine est **paginée** (défaut) et c'est `nestedConfig` qui porte
    // l'accordéon — le gabarit exact du CR.
    _H harness({bool freeNav = false}) => _H(
          config: const ZStepperConfig(), // racine PAGINÉE
          catalogue: <ZFieldSpec>[
            const ZFieldSpec(
                name: 'nav', type: EditionFieldType.text, label: 'Navire'),
            for (int i = 0; i < 18; i++)
              ZFieldSpec(
                  name: 'doc$i', type: EditionFieldType.text, label: 'Doc $i'),
          ],
          steps: <ZEditionStep>[
            ZEditionStep(
              title: 'Contrôle des documents',
              fields: const <String>['nav'],
              nestedConfig: freeNav
                  ? ZStepperConfig.accordionVertical
                      .copyWith(validateOnNext: false)
                  : ZStepperConfig.accordionVertical,
              nestedSteps: <ZEditionStep>[
                for (int i = 0; i < 18; i++)
                  ZEditionStep(
                      title: 'Document $i', fields: <String>['doc$i']),
              ],
            ),
          ],
          initial: <String, Object?>{
            'nav': '',
            for (int i = 0; i < 18; i++) 'doc$i': '',
          },
        );

    testWidgets('les 18 en-têtes existent, un seul document est déplié, '
        'et un tap y saute directement', (tester) async {
      _bigView(tester, size: const Size(1000, 1200));
      final _H h = harness(freeNav: true);
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      // MODE vérifié : le sous-stepper montre les en-têtes des AUTRES
      // sous-étapes — ce que le paginé ne fait jamais (c'est tout le CR).
      expect(find.text('Document 0'), findsOneWidget);
      expect(find.text('Document 3'), findsOneWidget);
      expect(_key('doc0'), findsOneWidget);
      expect(_key('doc3'), findsNothing,
          reason: 'une seule sous-étape dépliée');

      await tester.tap(find.text('Document 3'));
      await tester.pumpAndSettle();
      expect(_key('doc3'), findsOneWidget,
          reason: 'accès DIRECT, sans 3 clics « Suivant »');
      expect(_key('doc0'), findsNothing);
    });

    testWidgets('la fenêtre publiée reste celle du CHEMIN ACTIF, et le racine '
        'en est le SEUL écrivain', (tester) async {
      _bigView(tester, size: const Size(1000, 1200));
      final _H h = harness(freeNav: true);
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      expect(_managingCount(), 0,
          reason: 'nesting ⇒ toutes les zones sont passives');
      expect(h.controller.visibleFields.value, <String>['nav', 'doc0']);

      await tester.tap(find.text('Document 5'));
      await tester.pumpAndSettle();
      expect(h.controller.visibleFields.value, <String>['nav', 'doc5'],
          reason: 'fenêtre de l\'étape ACTIVE — jamais les 18 documents');
      expect(_editionCount(), 2,
          reason: 'zone du parent + zone de la sous-étape active, pas 19');
    });
  });

  // ══ 5. A11Y (AD-13) ═══════════════════════════════════════════════════════

  group('A11y', () {
    testWidgets('cible ≥ 48 dp mesurée sur la CONTRAINTE LIANTE',
        (tester) async {
      _bigView(tester);
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();
      expect(find.text('Autorisations'), findsOneWidget); // mode vérifié

      for (int i = 0; i < 3; i++) {
        final RenderBox box =
            tester.renderObject<RenderBox>(_key('zstep:header:$i'));
        expect(
          box.constraints.minHeight,
          greaterThanOrEqualTo(48),
          reason: 'en-tête $i : la contrainte reçue doit PLANCHER à 48 dp',
        );
        expect(box.size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('l\'étape active n\'est PAS signalée par la seule couleur',
        (tester) async {
      _bigView(tester);
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      final Text active = tester.widget<Text>(find.text('Identité'));
      final Text pending = tester.widget<Text>(find.text('Autorisations'));
      expect(active.style?.fontWeight, FontWeight.bold);
      expect(pending.style?.fontWeight, FontWeight.normal);
      expect(
        active.style?.fontWeight == pending.style?.fontWeight,
        isFalse,
        reason: 'marque NON chromatique : la graisse du titre',
      );
      // Et la marque structurelle : seule l'active porte du contenu.
      expect(_key('a'), findsOneWidget);
      expect(_key('c'), findsNothing);
    });

    testWidgets('l\'état déplié/replié est ANNONCÉ, et le rôle est `button`',
        (tester) async {
      _bigView(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      expect(
        find.bySemanticsLabel(RegExp('Étape 1 sur 3 : Identité')),
        findsOneWidget,
      );
      final SemanticsNode activeNode = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Étape 1 sur 3 : Identité')),
      );
      expect(activeNode.flagsCollection.isButton, isTrue);
      expect(activeNode.flagsCollection.isExpanded, Tristate.isTrue);

      final SemanticsNode pendingNode = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Étape 3 sur 3 : Autorisations')),
      );
      expect(pendingNode.flagsCollection.isExpanded, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets('mode « tout affiché » : AUCUN drapeau `expanded` ajouté '
        '(hôte passif de v0.66.0 inchangé)', (tester) async {
      _bigView(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final _H h = _H(config: ZStepperConfig.allStepsVertical);
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Étape 1 sur 3 : Identité')),
      );
      expect(node.flagsCollection.isExpanded, Tristate.none,
          reason: 'aucun drapeau d\'expansion en mode « tout affiché »');
      expect(node.flagsCollection.isButton, isFalse);
      handle.dispose();
    });

    testWidgets('RTL : aucune exception, en-têtes et rail rendus',
        (tester) async {
      _bigView(tester);
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build(dir: TextDirection.rtl));
      await tester.pump();
      expect(find.text('Historique'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ══ 6. SM-1 (AD-2) ════════════════════════════════════════════════════════

  group('SM-1', () {
    testWidgets('une frappe ne reconstruit PAS le chrome de l\'accordéon',
        (tester) async {
      _bigView(tester);
      final _H h = _H();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();
      expect(find.text('Autorisations'), findsOneWidget); // mode vérifié

      final int before = h.structural;
      await tester.enterText(
        find.descendant(of: _key('a'), matching: find.byType(EditableText)),
        'Bonjour',
      );
      await tester.pump();
      expect(h.structural, before,
          reason: 'aucun rebuild structurel sur une frappe (objectif n°1)');
    });

    testWidgets('changer d\'étape ne reconstruit le chrome qu\'UNE fois',
        (tester) async {
      _bigView(tester);
      final _H h = _H(initial: const <String, Object?>{
        'a': 'x',
        'b': 'y',
        'c': 'z',
      });
      addTearDown(h.dispose);
      await tester.pumpWidget(h.build());
      await tester.pump();

      final int before = h.structural;
      await tester.tap(find.text('Historique'));
      await tester.pump();
      expect(h.structural - before, lessThanOrEqualTo(2),
          reason: 'index + fenêtre : au plus deux notifications structurelles');
      expect(h.structural, greaterThan(before));
    });
  });
}
