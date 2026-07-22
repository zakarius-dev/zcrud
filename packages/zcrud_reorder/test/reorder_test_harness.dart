// Échafaudage PARTAGÉ des tests de `zcrud_reorder`.
//
// Le harnais est délibérément **agnostique du renderer** : il prend un
// `ZReorderRenderer` quelconque. C'est ce qui permet de rejouer EXACTEMENT la
// même séquence sur le repli zéro-dépendance et sur l'implémentation adossée au
// paquet tiers (`interchangeability_test.dart`).

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Libellé sémantique « déplacer avant » injecté par les tests — volontairement
/// non-français et unique, pour prouver qu'aucun littéral interne ne s'y
/// substitue.
const String kMoveBefore = 'MOVE-BEFORE-XYZ';

/// Libellé sémantique « déplacer après » injecté par les tests.
const String kMoveAfter = 'MOVE-AFTER-XYZ';

/// Construit une requête de rendu de test (600 dp de large ⇒ 3 colonnes de
/// 200 x 100 avec les défauts).
ZReorderRenderRequest request({
  required List<String> ids,
  required void Function(int oldIndex, int newIndex) onReorder,
  double minItemWidth = 200,
  double spacing = 0,
  double? itemHeight = 100,
  int minColumns = 1,
  int? maxColumns,
  EdgeInsetsGeometry? padding,
  bool semanticLabels = true,
}) {
  return ZReorderRenderRequest(
    itemIds: ids,
    itemBuilder: (context, index) => Center(
      child: Text(ids[index], textDirection: TextDirection.ltr),
    ),
    onReorder: onReorder,
    minItemWidth: minItemWidth,
    spacing: spacing,
    itemHeight: itemHeight,
    minColumns: minColumns,
    maxColumns: maxColumns,
    padding: padding,
    moveBeforeSemanticLabel: semanticLabels ? kMoveBefore : null,
    moveAfterSemanticLabel: semanticLabels ? kMoveAfter : null,
  );
}

/// Enveloppe minimale : aucun `MaterialApp`, la surface reste widgets-only.
/// L'`Overlay` est requis par les aperçus de glissement (des deux renderers).
///
/// ⚠️ `Overlay.initialEntries` n'est lu qu'à l'`initState` : un second
/// `pumpWidget` ne remplacerait PAS l'entrée, et la closure figerait la requête
/// initiale (piège qui rendrait le test de resync trompeusement vert). D'où le
/// [_RequestScope] : l'entrée relit la requête COURANTE via un `InheritedWidget`,
/// donc un nouveau `pumpWidget` la propage réellement.
Widget wrapRenderer(
  ZReorderRenderer renderer,
  ZReorderRenderRequest req, {
  TextDirection dir = TextDirection.ltr,
}) {
  return Directionality(
    textDirection: dir,
    child: MediaQuery(
      data: const MediaQueryData(size: Size(800, 600)),
      child: _RequestScope(
        renderer: renderer,
        request: req,
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (context) {
                final scope = _RequestScope.of(context);
                return Align(
                  alignment: AlignmentDirectional.topStart,
                  child: SizedBox(
                    width: 600,
                    height: 600,
                    child: scope.renderer.build(context, scope.request),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Porte la requête COURANTE jusqu'à l'entrée d'`Overlay` (cf. [wrapRenderer]).
class _RequestScope extends InheritedWidget {
  const _RequestScope({
    required this.renderer,
    required this.request,
    required super.child,
  });

  final ZReorderRenderer renderer;
  final ZReorderRenderRequest request;

  static _RequestScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RequestScope>()!;

  @override
  bool updateShouldNotify(_RequestScope oldWidget) =>
      !identical(oldWidget.request, request) ||
      !identical(oldWidget.renderer, renderer);
}

/// Ordre VISUEL courant, lu sur les positions réelles (ligne d'abord, puis
/// colonne selon la direction du texte) — jamais sur l'ordre d'entrée.
List<String> visualOrder(
  WidgetTester tester,
  List<String> ids, {
  bool rtl = false,
}) {
  final entries = <MapEntry<String, Offset>>[];
  for (final id in ids) {
    final finder = find.text(id);
    if (finder.evaluate().isEmpty) continue;
    entries.add(MapEntry(id, tester.getTopLeft(finder.first)));
  }
  entries.sort((a, b) {
    final dy = a.value.dy.compareTo(b.value.dy);
    if (dy != 0) return dy;
    return rtl
        ? b.value.dx.compareTo(a.value.dx)
        : a.value.dx.compareTo(b.value.dx);
  });
  return entries.map((e) => e.key).toList();
}

/// Déclenche l'action sémantique personnalisée de libellé [label] sur la
/// cellule affichant [text] — **la voie non-gestuelle**, celle qu'emprunte un
/// lecteur d'écran (AD-13).
///
/// Passe par `SemanticsNode.owner` (et non `tester.binding.pipelineOwner`, qui
/// est déprécié) : le test doit rester vert sans `deprecated_member_use`.
void performCustomAction(WidgetTester tester, String text, String label) {
  final SemanticsNode node = tester.getSemantics(find.text(text));
  node.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label)),
  );
}

/// Identifiants d'actions personnalisées effectivement exposés par la cellule
/// affichant [text].
List<int>? customActionIds(WidgetTester tester, String text) =>
    tester.getSemantics(find.text(text)).getSemanticsData()
        .customSemanticsActionIds;

/// Identifiant stable d'une action personnalisée de libellé [label].
int actionId(String label) =>
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: label));

/// Vrai geste : appui long sur [from], glissement jusqu'au centre de [to],
/// relâchement. Les deux renderers démarrent sur un délai d'appui long.
Future<void> dragCell(WidgetTester tester, String from, String to) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.text(from).first));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(find.text(to).first));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}
