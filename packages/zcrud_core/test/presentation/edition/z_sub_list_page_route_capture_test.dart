// Garde : le formulaire d'item d'une sous-liste ouvert en forme **page** est
// poussé À LA MAIN (`Navigator.push(MaterialPageRoute(…))`) — le seul
// présentateur de `zcrud_core` que le framework ne peut pas aider.
//
// 🔴 MOTIF — `showDialog` / `showModalBottomSheet` capturent d'eux-mêmes les
// `InheritedTheme` du point d'appel et les re-posent dans la route. Un
// `Navigator.push` nu ne capture RIEN : la route ne voit que ce qui vit
// au-dessus du `Navigator`. Le champ compensait en relevant le seul
// `ZcrudScope` et en le re-posant à la main — ce qui laissait tomber TOUT le
// reste de la pile de thèmes hérités (un `Theme` local, un `IconTheme`, un
// `DefaultSelectionStyle` posés entre le `Navigator` et le champ). La capture
// explicite remplace la compensation par le mécanisme du framework, et couvre
// les deux : le scope ET le reste de la pile.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Couleur du `Theme` LOCAL posé entre le `Navigator` et le champ.
const Color _kThemeLocal = Color(0xFF6200EA);

/// Jeton posé UNIQUEMENT par `ZcrudScope(theme: …)` — aucune
/// `ThemeData.extension`.
const Color _kJetonScope = Color(0xFF00C853);

const List<ZFieldSpec> _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
];

const ZFieldSpec _sousListePage = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    displayMode: ZSubListDisplayMode.compact,
    summaryFields: <String>['a'],
    itemFormPresentation: ZSubItemFormPresentation.page,
  ),
);

/// Surface haute : `DynamicEdition` monte ses champs par `ListView.builder`.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      '🔴 forme PAGE : la pile de thèmes hérités du point d\'appel suit la '
      'route poussée à la main', (tester) async {
    _useTallSurface(tester);
    const ZAcl acl = ZAllowAllAcl();
    final ZFormController controller = ZFormController(
      initialValues: const <String, Object?>{'items': <Object?>[]},
      visibleFields: const <String>['items'],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        // Thème de l'application : ce n'est PAS celui qu'on attend dans la
        // route — sans capture, c'est pourtant lui que la route verrait.
        theme: ThemeData(primaryColor: const Color(0xFFB00020)),
        home: ZcrudScope(
          acl: acl,
          theme: const ZcrudTheme(fieldBorderColor: _kJetonScope),
          // `Theme` LOCAL, posé SOUS le `Navigator` et AU-DESSUS du champ.
          child: Theme(
            data: ThemeData(primaryColor: _kThemeLocal),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: DynamicEdition(
                  controller: controller,
                  fields: const <ZFieldSpec>[_sousListePage],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Le formulaire d'item est bien monté DANS la route poussée.
    final Finder champ = find.widgetWithText(TextFormField, 'A');
    expect(champ, findsOneWidget,
        reason: 'la forme page doit avoir monté le formulaire d\'item');
    final BuildContext dansLaRoute = tester.element(champ);

    // 🔴 Le cœur du défaut : le `Theme` local ne traversait pas.
    expect(Theme.of(dansLaRoute).primaryColor, _kThemeLocal,
        reason: 'la pile de thèmes du point d\'appel doit suivre la route');

    // Et le scope reste vu, à identité égale (ce que la compensation assurait
    // déjà : la capture ne doit RIEN perdre en la remplaçant).
    expect(identical(ZcrudScope.maybeOf(dansLaRoute)?.acl, acl), isTrue,
        reason: 'la MÊME ACL doit rester visible dans la route');
    expect(ZcrudTheme.of(dansLaRoute).fieldBorderColor, _kJetonScope,
        reason: 'le jeton posé par le scope doit rester visible dans la route');
  });
}
