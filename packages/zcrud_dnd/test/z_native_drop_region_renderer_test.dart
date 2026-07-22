/// Banc du renderer natif — **strictement ce qui est atteignable sans engine**.
///
/// Ce qui EST couvert ici : le contrat 1 (contenu rendu inchangé), l'absence
/// d'affordance et de couleur codée en dur, la neutralité RTL, la stabilité du
/// renderer (`const`), et le fait qu'aucun survol n'est notifié hors
/// glissement.
///
/// Ce qui N'EST PAS couvert ici : les chemins `onDropOver` / `onPerformDrop` /
/// `onDropLeave`. Ils ne sont PAS appelés par Flutter mais par le contexte de
/// dépôt natif de `super_native_extensions` (Rust) via le `RenderObject` du
/// `DropRegion`. Sous `flutter test` ce contexte n'existe pas et aucune session
/// de glissement système ne peut être fabriquée : les simuler reviendrait à
/// tester un faux. Les RÈGLES que ces chemins appliquent sont donc exercées
/// pour de vrai — sur le code de production — dans
/// `z_drop_kind_mapping_test.dart`, et le renderer se contente de les brancher.
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_dnd/zcrud_dnd.dart';

Widget _host({
  required Widget child,
  required TextDirection direction,
  void Function(List<ZDroppedItem>)? onDrop,
  void Function(bool)? onHoverChanged,
  Set<ZDropKind> accepts = const <ZDropKind>{ZDropKind.file},
}) {
  const ZDropRegionRenderer renderer = ZNativeDropRegionRenderer();
  return Directionality(
    textDirection: direction,
    child: Center(
      child: Builder(
        builder: (BuildContext context) => renderer.build(
          context,
          ZDropRegionRequest(
            child: child,
            onDrop: onDrop ?? (List<ZDroppedItem> _) {},
            accepts: accepts,
            onHoverChanged: onHoverChanged,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('le renderer est un ZDropRegionRenderer const et immuable', () {
    const ZNativeDropRegionRenderer a = ZNativeDropRegionRenderer();
    const ZNativeDropRegionRenderer b = ZNativeDropRegionRenderer();
    expect(a, isA<ZDropRegionRenderer>());
    // `const` canonicalisé : injecté dans un `ZcrudScope`, il ne provoque
    // aucune reconstruction parasite.
    expect(identical(a, b), isTrue);
  });

  testWidgets('contrat 1 — le contenu est rendu, à taille INCHANGÉE',
      (WidgetTester tester) async {
    const Key key = Key('contenu');
    await tester.pumpWidget(
      _host(
        direction: TextDirection.ltr,
        child: const SizedBox(key: key, width: 123, height: 45),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
    // Si le renderer enveloppait le contenu dans une bordure ou un padding
    // « déposez ici », la taille rendue changerait.
    expect(tester.getSize(find.byKey(key)), const Size(123, 45));
  });

  testWidgets('aucune décoration ni couleur n est introduite par le renderer',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _host(
        direction: TextDirection.ltr,
        child: const SizedBox(width: 10, height: 10),
      ),
    );

    // AD-45 / thème : l'affordance appartient à l'hôte, avec SON thème. Le
    // paquet n'a donc aucune couleur à coder en dur — et n'en peint aucune.
    expect(find.byType(DecoratedBox), findsNothing);
    expect(find.byType(ColoredBox), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('rendu identique en LTR et en RTL (aucune géométrie ajoutée)',
      (WidgetTester tester) async {
    const Key key = Key('contenu');
    const Widget child = SizedBox(key: key, width: 80, height: 20);

    await tester.pumpWidget(
      _host(direction: TextDirection.ltr, child: child),
    );
    final Rect ltr = tester.getRect(find.byKey(key));

    await tester.pumpWidget(
      _host(direction: TextDirection.rtl, child: child),
    );
    final Rect rtl = tester.getRect(find.byKey(key));

    expect(rtl, ltr);
  });

  testWidgets('onHoverChanged n est jamais notifié hors glissement',
      (WidgetTester tester) async {
    final List<bool> hovers = <bool>[];
    await tester.pumpWidget(
      _host(
        direction: TextDirection.ltr,
        child: const SizedBox(width: 50, height: 50),
        onHoverChanged: hovers.add,
      ),
    );
    await tester.pump();

    // Le simple montage — puis un survol de souris ordinaire — ne sont PAS un
    // glissement : aucune affordance ne doit s'allumer.
    final TestGesture pointer = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await pointer.addPointer(location: tester.getCenter(find.byType(SizedBox)));
    addTearDown(pointer.removePointer);
    await tester.pump();

    expect(hovers, isEmpty);
  });

  testWidgets('onDrop n est jamais appelé sans dépôt réel',
      (WidgetTester tester) async {
    int drops = 0;
    await tester.pumpWidget(
      _host(
        direction: TextDirection.ltr,
        child: const SizedBox(width: 50, height: 50),
        onDrop: (List<ZDroppedItem> _) => drops++,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(drops, 0);
  });

  testWidgets('reconstruire l hôte ne recrée pas la zone de dépôt',
      (WidgetTester tester) async {
    const Key key = Key('contenu');
    for (int i = 0; i < 3; i++) {
      await tester.pumpWidget(
        _host(
          direction: TextDirection.ltr,
          child: const SizedBox(key: key, width: 30, height: 30),
        ),
      );
    }
    // L'élément est conservé d'un pump à l'autre : le renderer n'introduit
    // aucune clé instable qui forcerait une remise à zéro de l'état de survol.
    expect(find.byKey(key), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
