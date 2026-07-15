// Tests DISCRIMINANTS ES-5.3 — sections réordonnables + persistance de l'ordre.
//
// AC1 [CENTRAL] : un réordonnancement se reflète dans `ZFolderContentsOrder`
//   (persisté en mémoire via `copyWith`) ET l'ordre lu est APPLIQUÉ au rendu
//   (`applyTo`, tri stable). Pouvoir discriminant R3-I1 : onReorder no-op ⇒ ROUGE.
// AC2 [CENTRAL / SM-1 / objectif n°1] : réordonner NE réintroduit AUCUN rebuild
//   global — (a) taper 100 caractères reste SM-1-conforme (buildsFieldB=1,
//   buildsPage=1) ; (b) réordonner la section A NE reconstruit NI la section B
//   NI l'observateur de page. Pouvoir discriminant R3-I2 : ListenableBuilder
//   global ⇒ ROUGE.
// AC5 : l'ordre visuel SUIT l'ordre appliqué (byte-diff sous permutation).
// zReorderIds : opération pure removeAt/insert, totale (clamp, jamais de throw).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Label de poignée INJECTÉ distinctif (jamais un titre, jamais codé en dur).
const String kHandleLabel = 'REORDONNER-XYZ';

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(child: Scaffold(body: child)),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // zReorderIds — opération PURE (removeAt/insert) + totale (AD-10).
  // ---------------------------------------------------------------------------
  group('zReorderIds (helper pur)', () {
    test('déplace vers le bas : [a,b,c] (0→2) ⇒ [b,c,a]', () {
      expect(zReorderIds(['a', 'b', 'c'], 0, 2), ['b', 'c', 'a']);
    });
    test('déplace vers le haut : [a,b,c] (1→0) ⇒ [b,a,c]', () {
      expect(zReorderIds(['a', 'b', 'c'], 1, 0), ['b', 'a', 'c']);
    });
    test('ne mute pas la liste source', () {
      final src = ['a', 'b', 'c'];
      zReorderIds(src, 0, 2);
      expect(src, ['a', 'b', 'c']);
    });
    test('indices hors bornes ⇒ clampés, jamais de throw (AD-10)', () {
      expect(zReorderIds(['a', 'b'], 9, 9), ['a', 'b']);
      expect(zReorderIds(<String>[], 0, 5), <String>[]);
    });
  });

  // ---------------------------------------------------------------------------
  // AC1 [CENTRAL] — réordonner reflète l'ordre dans ZFolderContentsOrder + rendu.
  // ---------------------------------------------------------------------------
  testWidgets(
      'AC1 : réordonner met à jour ZFolderContentsOrder ET l\'ordre est appliqué au rendu',
      (tester) async {
    final key = GlobalKey<_OrderHarnessState>();
    await tester.pumpWidget(_wrap(_OrderHarness(
      key: key,
      sectionKey: 'docs',
      items: const ['a', 'b', 'c'],
      rebuildOnReorder: true,
    )));

    // Ordre initial vide ⇒ applyTo préserve l'ordre d'entrée [a,b,c].
    expect(_contentDy(tester, 'a') < _contentDy(tester, 'b'), isTrue);
    expect(_contentDy(tester, 'b') < _contentDy(tester, 'c'), isTrue);

    // Déplacement b (index 1) avant a (index 0) via le callback SDK réel.
    final rlv = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    rlv.onReorderItem!(1, 0);
    await tester.pumpAndSettle();

    // (a) Ordre PERSISTÉ dans ZFolderContentsOrder (copyWith en mémoire).
    expect(key.currentState!.order.orderFor('docs'), ['b', 'a', 'c']);
    // (b) Ordre APPLIQUÉ au rendu : b est désormais AU-DESSUS de a.
    expect(_contentDy(tester, 'b') < _contentDy(tester, 'a'), isTrue,
        reason: 'l\'ordre persisté est appliqué au rendu (applyTo)');
    expect(_contentDy(tester, 'a') < _contentDy(tester, 'c'), isTrue);
  });

  testWidgets(
      'AC2/MEDIUM-1 : le retour visuel de drag vient de l\'état optimiste LOCAL '
      '(rebuildOnReorder:false — aucun setState page ne réordonne le rendu)',
      (tester) async {
    // rebuildOnReorder:false ⇒ le callback `onReorder` de l'appelant N'appelle
    // PAS setState (persistance silencieuse). Le SEUL moteur possible du
    // réordonnancement VISUEL est alors l'état optimiste LOCAL `_ids`
    // (ValueNotifier du sous-arbre de section, ligne 248) — SM-1/AD-2. Ce test
    // verrouille précisément ce chemin : neutraliser la ligne 248 (sans toucher
    // le callback onReorder) fige le rendu ⇒ ROUGE (pouvoir discriminant).
    await tester.pumpWidget(_wrap(_OrderHarness(
      sectionKey: 'docs',
      items: const ['a', 'b', 'c'],
      rebuildOnReorder: false,
    )));

    // Ordre visuel initial [a,b,c].
    expect(_contentDy(tester, 'a') < _contentDy(tester, 'b'), isTrue);

    // Réordonnancement réel via le callback SDK : b (index 1) déplacé avant a (0).
    final rlv = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    rlv.onReorderItem!(1, 0);
    await tester.pump();

    // Le retour visuel VIENT de l'état LOCAL : b est désormais AU-DESSUS de a,
    // ALORS que la page n'a subi AUCUN rebuild d'appelant (setState absent).
    expect(_contentDy(tester, 'b') < _contentDy(tester, 'a'), isTrue,
        reason: 'retour visuel de drag porté par l\'état optimiste LOCAL _ids '
            '(z_sectioned_study_layout.dart:248), PAS par un setState de page');
  });

  testWidgets('AC1 : l\'ordre PERSISTÉ initial est APPLIQUÉ au rendu (applyTo)',
      (tester) async {
    // Ordre personnel initial [c,a,b] sur items d'entrée [a,b,c].
    final initial = const ZFolderContentsOrder(folderId: 'f').copyWith(
      sectionOrders: {
        'docs': ['c', 'a', 'b'],
      },
    );
    await tester.pumpWidget(_wrap(_OrderHarness(
      sectionKey: 'docs',
      items: const ['a', 'b', 'c'],
      initialOrder: initial,
    )));

    // Le rendu SUIT l'ordre lu (c, puis a, puis b), pas l'ordre brut d'entrée.
    expect(_contentDy(tester, 'c') < _contentDy(tester, 'a'), isTrue);
    expect(_contentDy(tester, 'a') < _contentDy(tester, 'b'), isTrue);
  });

  testWidgets(
      'AC5 : permuter l\'ordre appliqué d\'une section réordonnable change le rendu (byte-diff)',
      (tester) async {
    final ordered = await _captureReorderable(tester, const ['a', 'b', 'c']);
    final permuted = await _captureReorderable(tester, const ['c', 'b', 'a']);
    expect(permuted, isNot(equals(ordered)));
  });

  // ---------------------------------------------------------------------------
  // AC2 [CENTRAL / SM-1] — (a) frappe SM-1-conforme ; (b) réordonnancement confiné.
  // ---------------------------------------------------------------------------
  testWidgets(
      'AC2 : 100 frappes SM-1-conformes PUIS réordonner A ne reconstruit ni B ni la page',
      (tester) async {
    final controller = ZFormController(initialValues: {'a': '', 'b': ''});
    final teA = TextEditingController();
    final fnA = FocusNode();
    var buildsFieldA = 0; // champ scopé de la section A réordonnable
    var buildsAObs = 0; // observateur STRUCTUREL de la section A
    var buildsFieldB = 0; // champ voisin (section B)
    var buildsPage = 0; // observateur de PAGE (section C, hors section A)

    // Section A RÉORDONNABLE : [champ 'a' scopé] + [observateur structurel].
    final sectionA = ZStudyToolsSectionSpec(
      id: 'A',
      title: 'Section A',
      itemCount: 2,
      itemIds: const ['fa', 'oa'],
      reorderHandleSemanticLabel: kHandleLabel,
      onReorder: (_, __) {}, // persistance app (no-op ici : pas de setState page)
      emptyState: const SizedBox.shrink(),
      itemBuilder: (context, index) {
        if (index == 0) {
          final c = ZStudyToolsPage.of(context);
          return ZFieldListenableBuilder(
            controller: c,
            name: 'a',
            builder: (context, value, child) {
              buildsFieldA++;
              return EditableText(
                controller: teA,
                focusNode: fnA,
                style: const TextStyle(),
                cursorColor: const Color(0xFF000000),
                backgroundCursorColor: const Color(0xFF000000),
                onChanged: (v) => c.setValue('a', v),
              );
            },
          );
        }
        buildsAObs++;
        return const SizedBox(key: ValueKey('a-observer'));
      },
    );

    // Section B : champ voisin scopé (autre section — jamais reconstruit).
    final sectionB = ZStudyToolsSectionSpec(
      id: 'B',
      title: 'Section B',
      itemCount: 1,
      emptyState: const SizedBox.shrink(),
      itemBuilder: (context, index) => ZFieldListenableBuilder(
        controller: ZStudyToolsPage.of(context),
        name: 'b',
        builder: (context, value, child) {
          buildsFieldB++;
          return const SizedBox(key: ValueKey('field-b'));
        },
      ),
    );

    // Section C : observateur de PAGE (hors de la section A réordonnable).
    final sectionC = ZStudyToolsSectionSpec(
      id: 'C',
      title: 'Section C',
      itemCount: 1,
      emptyState: const SizedBox.shrink(),
      itemBuilder: (context, index) {
        buildsPage++;
        return const SizedBox(key: ValueKey('page-observer'));
      },
    );

    await tester.pumpWidget(_wrap(ZStudyToolsPage(
      formController: controller,
      sections: [sectionA, sectionB, sectionC],
    )));

    expect(buildsFieldA, 1);
    expect(buildsAObs, 1);
    expect(buildsFieldB, 1);
    expect(buildsPage, 1);

    // (a) SM-1 : taper 100 caractères ne reconstruit QUE le champ courant.
    fnA.requestFocus();
    await tester.pump();
    final buffer = StringBuffer();
    for (var i = 1; i <= 100; i++) {
      buffer.write('x');
      await tester.enterText(find.byType(EditableText), buffer.toString());
      await tester.pump();
      expect(fnA.hasFocus, isTrue);
    }
    expect(buildsFieldA, 101, reason: 'le champ courant reconstruit par frappe');
    expect(buildsAObs, 1, reason: 'la structure de la section A NON reconstruite');
    expect(buildsFieldB, 1, reason: 'section B (voisine) JAMAIS reconstruite');
    expect(buildsPage, 1, reason: 'aucun rebuild global de la page (SM-1)');

    // (b) Réordonner la section A (callback SDK réel) : confiné au sous-arbre A.
    final rlv = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    rlv.onReorderItem!(1, 0);
    await tester.pumpAndSettle();

    expect(buildsFieldB, 1,
        reason: 'réordonner A ne reconstruit PAS la section B');
    expect(buildsPage, 1,
        reason: 'réordonner A ne reconstruit PAS l\'observateur de page');

    controller.dispose();
    teA.dispose();
    fnA.dispose();
  });

  // ---------------------------------------------------------------------------
  // AC6 — poignée a11y : label INJECTÉ présent + cible ≥ 48 dp.
  // ---------------------------------------------------------------------------
  testWidgets('AC6 : la poignée de drag porte le label INJECTÉ et fait ≥ 48 dp',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(_OrderHarness(
      sectionKey: 'docs',
      items: const ['a', 'b', 'c'],
    )));

    // Label a11y INJECTÉ présent (tree de widgets ET arbre sémantique).
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == kHandleLabel,
      ),
      findsNWidgets(3),
    );
    expect(find.bySemanticsLabel(kHandleLabel), findsWidgets);

    // Chaque déclencheur de drag couvre une cible ≥ 48 dp.
    final listeners = find.byType(ReorderableDragStartListener);
    expect(listeners, findsWidgets);
    final size = tester.getSize(listeners.first);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
    handle.dispose();
  });

  // ---------------------------------------------------------------------------
  // Non-régression ES-5.2 : onReorder null ⇒ AUCUN ReorderableListView (AD-4).
  // ---------------------------------------------------------------------------
  testWidgets('onReorder null ⇒ section NON réordonnable (rendu ES-5.2 intact)',
      (tester) async {
    await tester.pumpWidget(_wrap(ZStudyToolsPage(
      sections: [
        ZStudyToolsSectionSpec(
          id: 'plain',
          title: 'Plain',
          itemCount: 2,
          emptyState: const SizedBox.shrink(),
          itemBuilder: (context, i) =>
              SizedBox(height: 10, key: ValueKey('plain-$i')),
        ),
      ],
    )));
    expect(find.byType(ReorderableListView), findsNothing);
  });
}

/// Position verticale (dy) du haut du contenu keyé `content:$id`.
double _contentDy(WidgetTester tester, String id) =>
    tester.getTopLeft(find.byKey(ValueKey('content:$id'))).dy;

/// Harnais de test tenant l'état `ZFolderContentsOrder` EN MÉMOIRE et rendant une
/// section réordonnable dont `itemIds` = `order.applyTo(...)` (contrat ES-5.3).
class _OrderHarness extends StatefulWidget {
  const _OrderHarness({
    required this.sectionKey,
    required this.items,
    this.initialOrder,
    this.rebuildOnReorder = false,
    super.key,
  });

  final String sectionKey;
  final List<String> items;
  final ZFolderContentsOrder? initialOrder;

  /// Si `true`, l'appelant force un rebuild de page à la persistance (exerce le
  /// re-render via `applyTo` + `didUpdateWidget`). Si `false`, la persistance est
  /// silencieuse (le retour visuel vient de l'état LOCAL de la section — SM-1).
  final bool rebuildOnReorder;

  @override
  State<_OrderHarness> createState() => _OrderHarnessState();
}

class _OrderHarnessState extends State<_OrderHarness> {
  late ZFolderContentsOrder order;

  @override
  void initState() {
    super.initState();
    order = widget.initialOrder ?? const ZFolderContentsOrder(folderId: 'f');
  }

  @override
  Widget build(BuildContext context) {
    final ordered =
        order.applyTo(widget.sectionKey, widget.items, idOf: (s) => s);
    return ZStudyToolsPage(
      sections: [
        ZStudyToolsSectionSpec(
          id: widget.sectionKey,
          title: 'Docs',
          itemCount: ordered.length,
          itemIds: ordered,
          reorderHandleSemanticLabel: kHandleLabel,
          onReorder: (oldIndex, newIndex) {
            final base = order.orderFor(widget.sectionKey);
            final current = base.isEmpty ? ordered : base;
            final next = order.copyWith(sectionOrders: {
              ...order.sectionOrders,
              widget.sectionKey: zReorderIds(current, oldIndex, newIndex),
            });
            if (widget.rebuildOnReorder) {
              setState(() => order = next);
            } else {
              order = next; // persistance silencieuse (pas de rebuild page)
            }
          },
          emptyState: const SizedBox.shrink(),
          itemBuilder: (context, i) => SizedBox(
            key: ValueKey('content:${ordered[i]}'),
            height: 30,
            child: Text(ordered[i], textAlign: TextAlign.start),
          ),
        ),
      ],
    );
  }
}

/// Capture les octets de rendu d'une section réordonnable dont `itemIds` == [ids].
Future<Uint8List> _captureReorderable(
  WidgetTester tester,
  List<String> ids,
) async {
  const size = Size(300, 500);
  final boundaryKey = GlobalKey();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: ZSectionedStudyLayout(sections: [
                  ZStudyToolsSectionSpec(
                    id: 'docs',
                    title: 'Docs',
                    itemCount: ids.length,
                    itemIds: ids,
                    reorderHandleSemanticLabel: kHandleLabel,
                    onReorder: (_, __) {},
                    emptyState: const SizedBox.shrink(),
                    // Hauteur DISTINCTE par id (la police Ahem rend chaque glyphe
                    // comme un carré identique ⇒ le texte seul ne discrimine pas
                    // l'ordre ; la hauteur, si — permuter l'ordre change donc les
                    // octets, R12/powerless évité).
                    itemBuilder: (context, i) => Container(
                      key: ValueKey('content:${ids[i]}'),
                      height: 20.0 + (ids[i].codeUnitAt(0) - 97) * 20.0,
                      color: const Color(0xFF334455),
                      child: Text(ids[i], textAlign: TextAlign.start),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late final Uint8List bytes;
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}
