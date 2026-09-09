// RENDU, GESTE, A11Y et RÉDUCTION DES ANIMATIONS de `ZCollapsibleSection`.
//
// Ce que ces gardes mesurent — et pourquoi chacune peut ROUGIR :
//  * l'ombre s'ÉCHANGE entre l'en-tête et le conteneur selon l'état : une
//    élévation figée passerait une garde qui ne regarderait qu'un état ;
//  * le corps replié est ABSENT de l'arbre (invariant AD-4), pas seulement
//    invisible — `findsNothing`, jamais « opacité 0 » ;
//  * le chevron est à un DEMI-TOUR déplié, à zéro replié — mesuré sur
//    `AnimatedRotation.turns`, pas sur la présence du glyphe ;
//  * sous `MediaQuery.disableAnimations`, la durée déclarée n'est PAS lue ;
//  * une action posée en `trailing` garde son nœud sémantique — le piège des
//    deux implémentations d'origine, qui mettaient toute la ligne en
//    `ExcludeSemantics`.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _wrap(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  bool disableAnimations = false,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Directionality(
      textDirection: direction,
      child: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    ),
  );
}

Material _material(WidgetTester tester, Key key) =>
    tester.widget<Material>(find.byKey(key));

AnimatedRotation _chevron(WidgetTester tester) => tester.widget<AnimatedRotation>(
      find.byKey(ZCollapsibleSection.chevronKey),
    );

void main() {
  group('ZCollapsibleSection — rendu déplié / replié', () {
    testWidgets(
        'déplié : élévation 8 sur l\'en-tête, 0 sur le conteneur, corps monté, '
        'chevron à un demi-tour', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          title: 'Semaine du 1 au 7',
          child: Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(_material(tester, ZCollapsibleSection.headerKey).elevation, 8);
      expect(_material(tester, ZCollapsibleSection.containerKey).elevation, 0);
      expect(find.byKey(ZCollapsibleSection.bodyKey), findsOneWidget);
      expect(find.text('corps'), findsOneWidget);
      expect(_chevron(tester).turns, 0.5);
    });

    testWidgets(
        'replié : élévation 0 sur l\'en-tête, 8 sur le conteneur, corps ABSENT '
        'de l\'arbre, chevron à zéro tour', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          title: 'Semaine du 1 au 7',
          initiallyExpanded: false,
          child: Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(_material(tester, ZCollapsibleSection.headerKey).elevation, 0);
      expect(_material(tester, ZCollapsibleSection.containerKey).elevation, 8);
      // 🔴 `skipOffstage: false` est ce qui rend l'assertion MORDANTE : par
      // défaut, `find` ignore déjà les widgets hors-scène, donc un corps
      // simplement mis en `Offstage`/`Visibility(maintainState:)` passerait
      // pour absent. La propriété visée est le DÉMONTAGE, pas l'invisibilité.
      expect(find.byKey(ZCollapsibleSection.bodyKey, skipOffstage: false),
          findsNothing);
      expect(find.text('corps', skipOffstage: false), findsNothing,
          reason: 'le corps replié doit être DÉMONTÉ, pas masqué (AD-4)');
      expect(_chevron(tester).turns, 0);
    });

    testWidgets('la forme n\'est portée que par la surface qui a l\'ombre',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(title: 'T', child: Text('corps')),
      ));
      await tester.pumpAndSettle();
      // Déplié : c'est l'en-tête qui est encadré.
      expect(_material(tester, ZCollapsibleSection.headerKey).shape,
          isA<RoundedRectangleBorder>());
      expect(_material(tester, ZCollapsibleSection.containerKey).shape, isNull);
      expect(_material(tester, ZCollapsibleSection.containerKey).clipBehavior,
          Clip.none);

      await tester.tap(find.text('T'));
      await tester.pumpAndSettle();
      // Replié : c'est le conteneur, et lui seul, qui rogne son contenu.
      expect(_material(tester, ZCollapsibleSection.headerKey).shape, isNull);
      expect(_material(tester, ZCollapsibleSection.containerKey).shape,
          isA<RoundedRectangleBorder>());
      expect(_material(tester, ZCollapsibleSection.containerKey).clipBehavior,
          Clip.antiAlias);
    });
  });

  group('ZCollapsibleSection — geste', () {
    testWidgets('un tap sur l\'en-tête bascule, et notifie le NOUVEL état',
        (WidgetTester tester) async {
      final List<bool> seen = <bool>[];
      await tester.pumpWidget(_wrap(
        ZCollapsibleSection(
          title: 'Semaine',
          onExpansionChanged: seen.add,
          child: const Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZCollapsibleSection.bodyKey), findsOneWidget);

      await tester.tap(find.text('Semaine'));
      await tester.pumpAndSettle();
      expect(find.byKey(ZCollapsibleSection.bodyKey, skipOffstage: false),
          findsNothing);
      expect(seen, <bool>[false]);

      await tester.tap(find.text('Semaine'));
      await tester.pumpAndSettle();
      expect(find.byKey(ZCollapsibleSection.bodyKey), findsOneWidget);
      expect(seen, <bool>[false, true]);
    });

    testWidgets('la zone de geste de l\'en-tête fait au moins 48 dp',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(title: 'T', child: SizedBox.shrink()),
      ));
      await tester.pumpAndSettle();
      final Size size = tester.getSize(find.descendant(
        of: find.byKey(ZCollapsibleSection.headerKey),
        matching: find.byType(InkWell),
      ));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('un ZToggleController de l\'hôte PILOTE l\'état, sans copie',
        (WidgetTester tester) async {
      late ZToggleController controller;
      await tester.pumpWidget(_wrap(
        _ControllerHost(
          onController: (ZToggleController c) => controller = c,
          builder: (ZToggleController c) => ZCollapsibleSection(
            title: 'T',
            expandController: c,
            child: const Text('corps'),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZCollapsibleSection.bodyKey), findsOneWidget);

      // Commande venue de l'hôte.
      controller.clear();
      await tester.pumpAndSettle();
      expect(find.byKey(ZCollapsibleSection.bodyKey, skipOffstage: false),
          findsNothing);

      // Geste dans la section : il traverse le contrôleur (aucun miroir).
      await tester.tap(find.text('T'));
      await tester.pumpAndSettle();
      expect(controller.value, isTrue);
      expect(find.byKey(ZCollapsibleSection.bodyKey), findsOneWidget);
    });
  });

  group('ZCollapsibleSection — accessibilité', () {
    testWidgets('l\'en-tête est un BOUTON qui annonce son état',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          title: 'Semaine 12',
          count: 3,
          countSemanticsLabel: '3 dossiers',
          child: Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();

      final SemanticsNode node =
          tester.getSemantics(find.bySemanticsLabel('Semaine 12, 3 dossiers'));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isExpanded, Tristate.isTrue);

      await tester.tap(find.text('Semaine 12'));
      await tester.pumpAndSettle();
      final SemanticsNode collapsed =
          tester.getSemantics(find.bySemanticsLabel('Semaine 12, 3 dossiers'));
      expect(collapsed.flagsCollection.isExpanded, Tristate.isFalse);
      handle.dispose();
    });

    testWidgets(
        'une action posée en `trailing` GARDE son nœud sémantique — le piège '
        'des lignes mises en bloc dans `ExcludeSemantics`',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZCollapsibleSection(
          title: 'Semaine 12',
          trailing: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter',
          ),
          child: const Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();

      // L'annonce d'un `IconButton` à tooltip passe par `tooltip`, pas par
      // `label` : le nœud doit exister ET rester un bouton actionnable.
      final SemanticsNode action =
          tester.getSemantics(find.byTooltip('Ajouter'));
      expect(action.tooltip, 'Ajouter');
      expect(action.flagsCollection.isButton, isTrue);
      expect(action.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });

    testWidgets(
        'le geste de `trailing` PRIME sur celui de l\'en-tête (il n\'est pas '
        'avalé par la bascule)', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(_wrap(
        ZCollapsibleSection(
          title: 'Semaine 12',
          trailing: IconButton(
            onPressed: () => taps++,
            icon: const Icon(Icons.add),
          ),
          child: const Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.byKey(ZCollapsibleSection.bodyKey), findsOneWidget,
          reason: 'le tap sur l\'action ne doit PAS replier la section');
    });

    testWidgets(
        'sans libellé texte, le nœud du titre reste ANNONÇABLE (jamais un '
        'bouton muet)', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          titleWidget: Text('Titre libre'),
          child: Text('corps'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Titre libre'), findsOneWidget);
      handle.dispose();
    });
  });

  group('ZCollapsibleSection — réduction des animations', () {
    testWidgets('durée NULLE quand `disableAnimations` est demandé',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(title: 'T', child: SizedBox.shrink()),
        disableAnimations: true,
      ));
      await tester.pumpAndSettle();
      expect(_chevron(tester).duration, Duration.zero);
    });

    testWidgets('durée de référence (200 ms) sans réduction demandée',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(title: 'T', child: SizedBox.shrink()),
      ));
      await tester.pumpAndSettle();
      expect(_chevron(tester).duration, const Duration(milliseconds: 200));
    });
  });

  group('ZCollapsibleSection — compte et tête', () {
    testWidgets('aucune pastille à zéro, ni pour un compte absent',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const Column(children: <Widget>[
          ZCollapsibleSection(title: 'A', count: 0, child: SizedBox.shrink()),
          ZCollapsibleSection(title: 'B', child: SizedBox.shrink()),
        ]),
      ));
      await tester.pumpAndSettle();
      expect(find.text('0'), findsNothing);
    });

    testWidgets('le compte fourni est peint sur `secondaryContainer`',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(title: 'A', count: 7, child: SizedBox.shrink()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
      final BuildContext context = tester.element(find.text('7'));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final Container pill = tester.widget<Container>(find.ancestor(
        of: find.text('7'),
        matching: find.byType(Container),
      ).first);
      expect((pill.decoration! as BoxDecoration).color,
          scheme.secondaryContainer);
      expect(tester.widget<Text>(find.text('7')).style?.color,
          scheme.onSecondaryContainer);
    });

    testWidgets('une pastille FOURNIE remplace celle du compte',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          title: 'A',
          count: 7,
          countBadge: Text('sept'),
          child: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('sept'), findsOneWidget);
      expect(find.text('7'), findsNothing);
    });

    testWidgets('aucun disque de tête sans glyphe ni `leading` déclaré',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(title: 'A', child: SizedBox.shrink()),
      ));
      await tester.pumpAndSettle();
      // Seul le chevron reste : aucune icône de tête n'a été inventée.
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    });

    testWidgets('le glyphe de tête est teint par `primary` sans clé de couleur',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          title: 'A',
          leadingIcon: Icons.calendar_month_rounded,
          child: SizedBox.shrink(),
        ),
      ));
      await tester.pumpAndSettle();
      final BuildContext context =
          tester.element(find.byIcon(Icons.calendar_month_rounded));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      final Icon icon =
          tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded));
      expect(icon.color, scheme.primary);
      expect(icon.size, 20);
    });

    testWidgets('une clé de couleur d\'hôte TEINT le disque de tête',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          colorKeyResolver: (ColorScheme scheme, String key) => key == 'droit'
              ? ZColorPair(
                  color: scheme.tertiary,
                  onColor: scheme.onTertiary,
                )
              : null,
          child: const Scaffold(
            body: ZCollapsibleSection(
              title: 'A',
              leadingIcon: Icons.calendar_month_rounded,
              leadingColorKey: 'droit',
              child: SizedBox.shrink(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final BuildContext context =
          tester.element(find.byIcon(Icons.calendar_month_rounded));
      final ColorScheme scheme = Theme.of(context).colorScheme;
      expect(
        tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded)).color,
        scheme.tertiary,
      );
      expect(scheme.tertiary, isNot(scheme.primary),
          reason: 'sans quoi la garde ne distinguerait pas la clé du défaut');
    });
  });

  group('ZCollapsibleSection — RTL', () {
    testWidgets('en RTL, la tête passe à droite et la pastille suit le titre',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const ZCollapsibleSection(
          title: 'A',
          leadingIcon: Icons.calendar_month_rounded,
          count: 5,
          child: SizedBox.shrink(),
        ),
        direction: TextDirection.rtl,
      ));
      await tester.pumpAndSettle();

      final double leading =
          tester.getCenter(find.byIcon(Icons.calendar_month_rounded)).dx;
      final double title = tester.getCenter(find.text('A')).dx;
      final double chevron = tester
          .getCenter(find.byIcon(Icons.keyboard_arrow_down_rounded))
          .dx;
      expect(leading, greaterThan(title),
          reason: 'la tête est du côté DÉBUT, donc à droite en RTL');
      expect(chevron, lessThan(title),
          reason: 'le chevron est du côté FIN, donc à gauche en RTL');
    });
  });
}

/// Hôte de test qui **possède** un `ZToggleController` hors `build`
/// (`ZDisplayStateOwnerMixin` l'impose : un contrôleur créé dans `build`
/// lèverait au premier rebuild).
class _ControllerHost extends StatefulWidget {
  const _ControllerHost({required this.onController, required this.builder});

  final void Function(ZToggleController controller) onController;
  final Widget Function(ZToggleController controller) builder;

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost>
    with ZDisplayStateOwnerMixin<_ControllerHost> {
  late final ZToggleController controller;

  @override
  void initState() {
    super.initState();
    controller = ZToggleController(owner: this, initialValue: true);
    widget.onController(controller);
  }

  @override
  Widget build(BuildContext context) => widget.builder(controller);
}
