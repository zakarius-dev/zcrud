// CR-IFFD-135 — ouverture IMPÉRATIVE ancrée : l'hôte garde SON déclencheur.
//
// Ce que ces gardes verrouillent :
//   1. la GÉOMÉTRIE d'ancrage — la surface se pose là où la poserait un
//      déclencheur porté, en LTR **et** en RTL (le choix du coin de DÉPART est
//      mesuré par `getRect`, jamais affirmé) ;
//   2. le repli AD-10 — ancre non montée / non mesurée, contexte démonté, rien
//      à montrer : AUCUNE surface, AUCUNE levée ;
//   3. la parité de surface — `menuBuilder`, `renderer`, `crossAxisCount`, la
//      règle d'absence (AD-4) et la voie unique de sélection sont les mêmes que
//      celles du widget porté ;
//   4. l'a11y (AD-13) — cibles ≥ 48 dp sur la surface ainsi ouverte.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart'
    show ZMenuEntry, ZMenuEntryTile, ZMenuPanelEntry, ZMenuRequest, ZMenuScope;
import 'package:zcrud_study/zcrud_study.dart';

const String kOuvrir = 'OUVRIR-135';
const String kRenommer = 'RENOMMER-135';
const String kAbsente = 'ABSENTE-135';

List<ZItemAction> _actions(List<String> journal) => <ZItemAction>[
      ZItemAction(
        kind: ZItemActionKind.open,
        label: kOuvrir,
        icon: Icons.folder_open,
        onSelected: () => journal.add(kOuvrir),
      ),
      ZItemAction(
        kind: ZItemActionKind.rename,
        label: kRenommer,
        icon: Icons.edit,
        onSelected: () => journal.add(kRenommer),
      ),
      // Ni actionnable ni motivée ⇒ ABSENTE (AD-4).
      const ZItemAction(
        kind: ZItemActionKind.delete,
        label: kAbsente,
        icon: Icons.delete,
      ),
    ];

/// Bouton de l'HÔTE, monté dans SON arbre, ancré par sa propre `GlobalKey`.
class _HostButton extends StatelessWidget {
  const _HostButton({
    required this.anchorKey,
    required this.actions,
    this.menuBuilder,
    this.renderer,
    this.crossAxisCount = 3,
  });

  final GlobalKey anchorKey;
  final List<ZItemAction> actions;
  final ZItemActionsMenuBuilder? menuBuilder;
  final ZMenuRenderer? renderer;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) => IconButton(
        key: anchorKey,
        icon: const Icon(Icons.more_horiz),
        tooltip: 'HÔTE',
        onPressed: () => showZItemActionsMenu(
          context,
          actions: actions,
          anchorKey: anchorKey,
          menuBuilder: menuBuilder,
          renderer: renderer,
          crossAxisCount: crossAxisCount,
        ),
      );
}

/// Enveloppe d'essai.
///
/// La directionnalité est posée par `builder`, donc AU-DESSUS du `Navigator` :
/// c'est la seule façon d'en faire hériter l'`Overlay`, et donc la surface
/// flottante. Une `Directionality` posée dans `home` laisserait la surface en
/// LTR et rendrait toute garde RTL de placement TAUTOLOGIQUE (mesuré).
Widget _app(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  AlignmentGeometry align = Alignment.center,
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? navigator) =>
          Directionality(textDirection: direction, child: navigator!),
      home: Scaffold(body: Align(alignment: align, child: child)),
    );

/// Rectangle GLOBAL de la surface ouverte (le panneau du socle).
Rect _surfaceRect(WidgetTester tester) =>
    tester.getRect(find.byType(ZMenuPanelEntry));

void main() {
  group('§1 — géométrie d\'ancrage MESURÉE', () {
    // Trois placements d'ancre × deux directionnalités : la parité de placement
    // est mesurée là où Material CHANGE de côté (ancre centrée, collée au bord
    // de départ, collée au bord de fin), pas seulement au centre de l'écran.
    const Map<String, AlignmentGeometry> placements = <String, AlignmentGeometry>{
      'centre': Alignment.center,
      'bord de départ': AlignmentDirectional.centerStart,
      'bord de fin': AlignmentDirectional.centerEnd,
    };

    for (final TextDirection direction in TextDirection.values) {
      for (final MapEntry<String, AlignmentGeometry> placement
          in placements.entries) {
        testWidgets(
            'surface AU MÊME rectangle que le déclencheur porté — '
            '${direction.name}, ancre au ${placement.key}', (tester) async {
          final journal = <String>[];

          // (a) le déclencheur PORTÉ par le socle.
          await tester.pumpWidget(_app(
            ZItemActionsMenu(actions: _actions(journal)),
            direction: direction,
            align: placement.value,
          ));
          final Rect ancreSocle = tester.getRect(find.byType(ZItemActionsMenu));
          await tester.tap(find.byType(ZItemActionsMenu));
          await tester.pumpAndSettle();
          final Rect surfacePortee = _surfaceRect(tester);
          await tester.tapAt(const Offset(5, 590)); // referme
          await tester.pumpAndSettle();

          // (b) le déclencheur de l'HÔTE, au MÊME rectangle.
          final anchorKey = GlobalKey();
          await tester.pumpWidget(_app(
            _HostButton(anchorKey: anchorKey, actions: _actions(journal)),
            direction: direction,
            align: placement.value,
          ));
          final Rect ancreHote = tester.getRect(find.byKey(anchorKey));
          expect(ancreHote, equals(ancreSocle),
              reason: 'précondition : les deux ancres doivent coïncider');
          await tester.tap(find.byKey(anchorKey));
          await tester.pumpAndSettle();

          expect(_surfaceRect(tester), equals(surfacePortee));
        });
      }
    }

    testWidgets('LTR : la surface s\'aligne sur le bord de DÉPART (gauche)',
        (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(
        _app(_HostButton(anchorKey: anchorKey, actions: _actions(<String>[]))),
      );
      final Rect ancre = tester.getRect(find.byKey(anchorKey));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      final Rect surface = _surfaceRect(tester);
      expect(surface.left, equals(ancre.left));
      // Contre-preuve : elle n'est PAS alignée sur le bord de fin.
      expect(surface.right, isNot(equals(ancre.right)));
    });

    testWidgets('RTL : la surface s\'aligne sur le bord de DÉPART (droit)',
        (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(
        _app(_HostButton(anchorKey: anchorKey, actions: _actions(<String>[])),
            direction: TextDirection.rtl),
      );
      final Rect ancre = tester.getRect(find.byKey(anchorKey));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      final Rect surface = _surfaceRect(tester);
      expect(surface.right, equals(ancre.right));
      // Contre-preuve : le coin haut-gauche N'EST PAS le point d'ancrage.
      expect(surface.left, isNot(equals(ancre.left)));
    });
  });

  group('§2 — repli AD-10 : aucune surface, AUCUNE levée', () {
    testWidgets('ancre JAMAIS montée ⇒ rien ne s\'ouvre, rien ne lève',
        (tester) async {
      final anchorKey = GlobalKey(); // n'est attachée à aucun widget
      late BuildContext captured;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        captured = context;
        return const SizedBox(width: 48, height: 48);
      })));
      // Le repli est mesuré par une VALEUR, jamais par une attente : un
      // `expectLater(…, completes)` sur une surface réellement ouverte
      // PENDRAIT au lieu de rougir.
      bool termine = false;
      // `unawaited` : la garde mesure que la main est rendue AUSSITÔT — un
      // `await` ici pendrait au lieu de rougir si la surface s'ouvrait.
      unawaited(showZItemActionsMenu(
        captured,
        actions: _actions(<String>[]),
        anchorKey: anchorKey,
      ).then((_) => termine = true));
      await tester.pumpAndSettle();
      expect(termine, isTrue, reason: 'le repli doit rendre la main aussitôt');
      expect(find.byType(ZMenuPanelEntry), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('contexte DÉMONTÉ ⇒ rien ne s\'ouvre, rien ne lève',
        (tester) async {
      final anchorKey = GlobalKey();
      late BuildContext captured;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        captured = context;
        return SizedBox(key: anchorKey, width: 48, height: 48);
      })));
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      bool termine = false;
      // `unawaited` : la garde mesure que la main est rendue AUSSITÔT — un
      // `await` ici pendrait au lieu de rougir si la surface s'ouvrait.
      unawaited(showZItemActionsMenu(
        captured,
        actions: _actions(<String>[]),
        anchorKey: anchorKey,
      ).then((_) => termine = true));
      await tester.pumpAndSettle();
      expect(termine, isTrue, reason: 'le repli doit rendre la main aussitôt');
      expect(find.byType(ZMenuPanelEntry), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AUCUNE action visible et aucun menuBuilder ⇒ AUCUNE surface',
        (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(_app(_HostButton(
        anchorKey: anchorKey,
        actions: const <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.delete,
            label: kAbsente,
            icon: Icons.delete,
          ),
        ],
      )));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      expect(find.byType(ZMenuPanelEntry), findsNothing);
      expect(find.text(kAbsente), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'rien à montrer ⇒ le RENDERER n\'est même pas sollicité (aucune '
        'surface déléguée non plus)', (tester) async {
      // Mesuré au niveau du renderer, et non de la surface rendue : le repli
      // Material refuse DÉJÀ d'ouvrir une surface vide, si bien qu'une garde
      // qui ne regarderait que l'arbre resterait verte même si cette voie
      // sollicitait le renderer à tort. Un renderer INJECTÉ, lui, ferait ce
      // qu'on lui demande — c'est le cas de l'hôte qui branche le sien.
      final anchorKey = GlobalKey();
      final renderer = _RecordingRenderer();
      await tester.pumpWidget(_app(_HostButton(
        anchorKey: anchorKey,
        renderer: renderer,
        actions: const <ZItemAction>[
          ZItemAction(
            kind: ZItemActionKind.delete,
            label: kAbsente,
            icon: Icons.delete,
          ),
        ],
      )));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      expect(renderer.openings, isEmpty);
    });
  });

  group('§3 — parité de surface avec le widget porté', () {
    testWidgets('AD-4 : l\'action ni actionnable ni motivée est ABSENTE',
        (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(
        _app(_HostButton(anchorKey: anchorKey, actions: _actions(<String>[]))),
      );
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      expect(find.text(kOuvrir), findsOneWidget);
      expect(find.text(kRenommer), findsOneWidget);
      expect(find.text(kAbsente), findsNothing);
    });

    testWidgets(
        'le menuBuilder de l\'hôte reçoit la liste DÉJÀ filtrée et `select` '
        'invoque UNE fois en fermant', (tester) async {
      final journal = <String>[];
      final recues = <List<String>>[];
      final anchorKey = GlobalKey();
      await tester.pumpWidget(_app(_HostButton(
        anchorKey: anchorKey,
        actions: _actions(journal),
        menuBuilder: (context, actions, select) {
          recues.add(actions.map((ZItemAction a) => a.label).toList());
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final ZItemAction action in actions)
                SizedBox(
                  height: 48,
                  child: InkWell(
                    onTap: () => select(action),
                    child: Text('HOTE-${action.label}'),
                  ),
                ),
            ],
          );
        },
      )));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      expect(recues, isNotEmpty);
      expect(recues.last, equals(<String>[kOuvrir, kRenommer]));
      await tester.tap(find.text('HOTE-$kOuvrir'));
      await tester.pumpAndSettle();
      expect(journal, equals(<String>[kOuvrir]));
      expect(find.byType(ZMenuPanelEntry), findsNothing);
    });

    testWidgets('le renderer INJECTÉ sert la voie impérative (paramètre)',
        (tester) async {
      final anchorKey = GlobalKey();
      final renderer = _RecordingRenderer();
      await tester.pumpWidget(_app(_HostButton(
        anchorKey: anchorKey,
        actions: _actions(<String>[]),
        renderer: renderer,
      )));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      expect(renderer.openings, hasLength(1));
      expect(
        renderer.openings.single.entries.map((ZMenuEntry e) => e.label),
        equals(<String>[kOuvrir, kRenommer]),
      );
      // Rien du socle n'a été ouvert : le renderer a la main complète.
      expect(find.byType(ZMenuPanelEntry), findsNothing);
    });

    testWidgets('le renderer du ZMenuScope AMBIANT sert aussi cette voie',
        (tester) async {
      final anchorKey = GlobalKey();
      final renderer = _RecordingRenderer();
      await tester.pumpWidget(_app(ZMenuScope(
        renderer: renderer,
        child: _HostButton(anchorKey: anchorKey, actions: _actions(<String>[])),
      )));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      expect(renderer.openings, hasLength(1));
    });

    testWidgets('crossAxisCount gouverne la grille par défaut', (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(_app(_HostButton(
        anchorKey: anchorKey,
        actions: _actions(<String>[]),
        crossAxisCount: 1,
      )));
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      final Rect a = tester.getRect(find.ancestor(
        of: find.text(kOuvrir),
        matching: find.byType(ZMenuEntryTile),
      ));
      final Rect b = tester.getRect(find.ancestor(
        of: find.text(kRenommer),
        matching: find.byType(ZMenuEntryTile),
      ));
      // Une seule colonne : les deux cellules sont EMPILÉES, jamais côte à côte.
      expect(a.left, equals(b.left));
      expect(a.top, lessThan(b.top));
    });

    testWidgets('AD-13 : chaque cellule ouverte tient ≥ 48 dp', (tester) async {
      final anchorKey = GlobalKey();
      await tester.pumpWidget(
        _app(_HostButton(anchorKey: anchorKey, actions: _actions(<String>[]))),
      );
      await tester.tap(find.byKey(anchorKey));
      await tester.pumpAndSettle();
      final Iterable<Element> cellules =
          find.byType(ZMenuEntryTile).evaluate();
      expect(cellules, hasLength(2));
      for (final Element cellule in cellules) {
        final Size taille = tester.getSize(find.byWidget(cellule.widget));
        expect(taille.width, greaterThanOrEqualTo(48.0));
        expect(taille.height, greaterThanOrEqualTo(48.0));
      }
    });
  });
}

/// Renderer d'observation : il ENREGISTRE l'ouverture au lieu d'ouvrir.
class _RecordingRenderer extends ZMenuRenderer {
  final List<ZMenuRequest> openings = <ZMenuRequest>[];

  @override
  Widget build(BuildContext context, ZMenuRequest request) =>
      const SizedBox.shrink();

  @override
  Future<void> openAt(
    BuildContext context,
    ZMenuRequest request,
    Offset globalPosition,
  ) async {
    openings.add(request);
  }
}
