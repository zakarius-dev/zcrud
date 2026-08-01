/// Garde de la **COUTURE** (CHAT-4) : le déclencheur ET le contenu sont
/// réellement substituables, et la voie de sélection reste UNIQUE.
///
/// C'est la capacité que ni `ZItemActionsMenu.menuBuilder`, ni `ZBatchActionBar`,
/// ni `ZPageShell` ne portaient : leur `PopupMenuButton` est construit EN DUR.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

const IconData _glyphe = Icons.circle;

/// Renderer d'hôte : AUCUN `PopupMenuButton`, aucun Material — un simple bouton
/// qui exécute la première entrée. Représente « l'app fournit son package ».
class _RendererHote extends ZMenuRenderer {
  const _RendererHote();

  @override
  Widget build(BuildContext context, ZMenuRequest request) => GestureDetector(
        key: const ValueKey('RENDERER-HOTE'),
        onTap: () {
          for (final e in request.entries) {
            request.select(e);
          }
        },
        child: Text(request.trigger.semanticLabel),
      );
}

/// Renderer HOSTILE : tente de contourner la couture — exécuter une entrée
/// désactivée, et une entrée qu'il a fabriquée lui-même.
class _RendererHostile extends ZMenuRenderer {
  const _RendererHostile();

  @override
  Widget build(BuildContext context, ZMenuRequest request) => GestureDetector(
        key: const ValueKey('RENDERER-HOSTILE'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          for (final e in request.entries) {
            request.select(e);
          }
          request.select(
            ZMenuEntry(
              id: 'forge',
              label: 'FORGEE',
              onSelected: () => throw StateError('entrée forgée exécutée'),
            ),
          );
        },
        child: const SizedBox(width: 48, height: 48),
      );
}

Widget _hote(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('ZMenuScope : le repli est TOTALEMENT contourné', (tester) async {
    var appels = 0;
    await tester.pumpWidget(
      _hote(
        ZMenuScope(
          renderer: const _RendererHote(),
          child: ZActionMenu(
            trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
            entries: [
              ZMenuEntry(
                id: ZMenuEntryIds.open,
                label: 'LBL-A',
                onSelected: () => appels++,
              ),
            ],
          ),
        ),
      ),
    );
    // 🔴 Le repli n'a pas été rendu DU TOUT : ni son déclencheur, ni son glyphe.
    expect(find.byType(PopupMenuButton<ZMenuEntry>), findsNothing);
    expect(find.byIcon(_glyphe), findsNothing);
    expect(find.byKey(const ValueKey('RENDERER-HOTE')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('RENDERER-HOTE')));
    await tester.pumpAndSettle();
    expect(appels, 1);
  });

  testWidgets('le paramètre `renderer` prime sur le scope', (tester) async {
    await tester.pumpWidget(
      _hote(
        ZMenuScope(
          renderer: const _RendererHostile(),
          child: const ZActionMenu(
            renderer: _RendererHote(),
            trigger: ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
            entries: [],
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('RENDERER-HOTE')), findsOneWidget);
    expect(find.byKey(const ValueKey('RENDERER-HOSTILE')), findsNothing);
  });

  testWidgets('la chaîne est TOTALE : sans scope ni paramètre, le repli',
      (tester) async {
    expect(zFallbackMenuRenderer, isA<ZDefaultMenuRenderer>());
    await tester.pumpWidget(
      _hote(
        const ZActionMenu(
          trigger: ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
          entries: [],
        ),
      ),
    );
    expect(find.byType(PopupMenuButton<ZMenuEntry>), findsOneWidget);
  });

  testWidgets('`select` est la SEULE voie : un renderer ne peut ni exécuter une '
      'entrée désactivée, ni une entrée forgée', (tester) async {
    var actionnable = 0;
    await tester.pumpWidget(
      _hote(
        ZMenuScope(
          renderer: const _RendererHostile(),
          child: ZActionMenu(
            trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
            entries: [
              ZMenuEntry(
                id: ZMenuEntryIds.open,
                label: 'LBL-A',
                onSelected: () => actionnable++,
              ),
              const ZMenuEntry(
                id: ZMenuEntryIds.edit,
                label: 'LBL-DESACTIVEE',
                disabledReason: 'MOTIF',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('RENDERER-HOSTILE')));
    await tester.pumpAndSettle();
    // L'entrée forgée lèverait si elle était exécutée : la garde le prouve.
    expect(tester.takeException(), isNull);
    expect(actionnable, 1);
  });

  testWidgets('`ZMenuTrigger.widget` : déclencheur porté par un widget hôte',
      (tester) async {
    var appels = 0;
    await tester.pumpWidget(
      _hote(
        ZActionMenu(
          trigger: const ZMenuTrigger.widget(
            child: Text('DECLENCHEUR-HOTE'),
            semanticLabel: 'SL-TRIG',
          ),
          entries: [
            ZMenuEntry(
              id: ZMenuEntryIds.open,
              label: 'LBL-A',
              onSelected: () => appels++,
            ),
          ],
        ),
      ),
    );
    expect(find.text('DECLENCHEUR-HOTE'), findsOneWidget);
    await tester.tap(find.text('DECLENCHEUR-HOTE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LBL-A'));
    await tester.pumpAndSettle();
    expect(appels, 1);
  });

  test('ZMenuScope.updateShouldNotify compare par IDENTITÉ', () {
    const a = _RendererHote();
    const b = _RendererHostile();
    const enfant = SizedBox.shrink();
    expect(
      const ZMenuScope(renderer: a, child: enfant)
          .updateShouldNotify(const ZMenuScope(renderer: a, child: enfant)),
      isFalse,
    );
    expect(
      const ZMenuScope(renderer: b, child: enfant)
          .updateShouldNotify(const ZMenuScope(renderer: a, child: enfant)),
      isTrue,
    );
  });

  test('une entrée à la fois actionnable et désactivée ne se construit pas', () {
    expect(
      () => ZMenuEntry(
        id: 'x',
        label: 'L',
        onSelected: () {},
        disabledReason: 'MOTIF',
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('un déclencheur MUET ne se construit pas (AD-13, récidive su-9)', () {
    // ⚠️ En littéral `const`, l'assert est encore plus fort : il échoue à la
    // COMPILATION (mesuré — « Constant evaluation error »). On passe donc par
    // une valeur runtime pour prouver aussi la garde à l'exécution.
    final vide = String.fromCharCodes(const <int>[]);
    expect(
      () => ZMenuTrigger(icon: _glyphe, semanticLabel: vide),
      throwsA(isA<AssertionError>()),
    );
    expect(
      () => ZMenuTrigger.widget(child: const SizedBox(), semanticLabel: vide),
      throwsA(isA<AssertionError>()),
    );
  });
}
