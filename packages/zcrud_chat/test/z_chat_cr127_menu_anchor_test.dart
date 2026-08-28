/// CR-IFFD-127 ❶ — l'ancrage du menu d'artefact est déclarable, et
/// ADAPTATIF par défaut.
///
/// Tout est mesuré aux **rectangles** (`tester.getRect`), dans le repère de
/// la fenêtre de test (800 × 600) : le menu (la grille du socle) contre le
/// glyphe déclencheur (la cible 48 dp), jamais contre une icône de 20 dp.
///
/// * **A1** — place suffisante en dessous ⇒ le menu s'ouvre vers le bas :
///   son bord haut est le bord bas du glyphe, et il tient dans la fenêtre.
/// * **A2** — glyphe au bas d'une liste qui remplit la fenêtre ⇒ vers le
///   haut : son bord bas est le bord haut du glyphe, il ne sort pas de la
///   fenêtre et ne recouvre pas l'ancre.
/// * **A3** — la place est mesurée dans le VIEWPORT DÉFILABLE, pas dans la
///   fenêtre : une liste suivie d'un composer de 300 dp — le menu tiendrait
///   dans la fenêtre, pas dans la liste ⇒ vers le haut, au-dessus de la
///   bordure basse de la liste.
/// * **A4** — les valeurs explicites sont honorées : `below` dans le
///   scénario A2 rend l'ancrage historique (vers le bas, quitte à sortir) ;
///   `above` dans le scénario A1 monte.
/// * **A5** — RTL : le bord de DÉPART du menu reste sur le bord de départ du
///   glyphe (le bord droit), dans les deux sens d'ouverture.
/// * **A6** — échappatoire à l'octet : `below` pose exactement les ancres
///   historiques sur le suiveur (`bottomStart → topStart`, résolues).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

const IconData _iconMap = IconData(0xE911);
const double _tap = kZChatMinTapTarget;

int _invoked = 0;

ZChatArtifactSpec _spec() => ZChatArtifactSpec(
  key: 'mindmap',
  label: 'Carte mentale',
  icon: _iconMap,
  presence: (ZChatMessage _) => true,
  actions: <ZChatArtifactAction>[
    ZChatArtifactAction.edit(onSelected: (ZChatMessage _) => _invoked++),
    ZChatArtifactAction.delete(onSelected: (ZChatMessage _) {}),
  ],
);

Widget _bar({ZChatArtifactMenuAnchor? anchor}) => ZChatArtifactBar(
  message: assistant(const <ZContentBlock>[]),
  artifacts: <ZChatArtifactSpec>[_spec()],
  menuAnchor: anchor ?? ZChatArtifactMenuAnchor.adaptive,
);

/// La rangée en HAUT de la fenêtre : toute la place en dessous.
Widget _topHarness({
  ZChatArtifactMenuAnchor? anchor,
  TextDirection direction = TextDirection.ltr,
}) => harness(
  Align(
    alignment: AlignmentDirectional.topStart,
    child: _bar(anchor: anchor),
  ),
  direction: direction,
);

/// La rangée au BAS d'une liste qui occupe [listHeight] dp, suivie d'un
/// « composer » de [composerHeight] dp.
Widget _listHarness({
  required double listHeight,
  double composerHeight = 0,
  ZChatArtifactMenuAnchor? anchor,
  TextDirection direction = TextDirection.ltr,
}) => harness(
  Column(
    children: <Widget>[
      SizedBox(
        height: listHeight,
        child: ListView(
          children: <Widget>[
            SizedBox(height: listHeight - _tap),
            _bar(anchor: anchor),
          ],
        ),
      ),
      if (composerHeight > 0)
        SizedBox(height: composerHeight, key: const Key('composer')),
    ],
  ),
  direction: direction,
);

Finder get _glyph => find.ancestor(
  of: find.byIcon(_iconMap),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is ConstrainedBox && w.constraints.minHeight == kZChatMinTapTarget,
  ),
);

Finder get _menu => find.byType(GridView);

/// [reachable] : `false` pour les scénarios qui font DÉLIBÉRÉMENT sortir le
/// menu de la fenêtre (ancrage fixe) — un tap hors fenêtre ne prouve rien.
Future<(Rect glyph, Rect menu)> _open(
  WidgetTester tester, {
  bool reachable = true,
}) async {
  expect(_glyph, findsOneWidget);
  final Rect glyph = tester.getRect(_glyph);
  // Le glyphe est bien la CIBLE de 48 dp, pas l'icône de 20 dp.
  expect(glyph.height, _tap);
  await tester.tap(find.byIcon(_iconMap));
  await tester.pump();
  expect(_menu, findsOneWidget, reason: '🔴 le menu ne s\'est pas ouvert');
  final Rect menu = tester.getRect(_menu);
  expect(menu.height, greaterThan(0));
  // Le menu est ATTEIGNABLE, pas seulement peint : un verbe tapé s'exécute.
  // Une boîte de suiveur trop courte peint le menu sans lui livrer le tap.
  if (reachable) {
    _invoked = 0;
    await tester.tap(find.text(kZChatLabelFallbacks[kZChatLabelArtifactEdit]!));
    await tester.pump();
    expect(
      _invoked,
      1,
      reason: '🔴 le menu est peint mais ne reçoit pas le tap',
    );
  }
  return (glyph, menu);
}

void main() {
  const Rect window = Rect.fromLTWH(0, 0, 800, 600);

  group('CR127-A1 — place suffisante en dessous ⇒ vers le bas', () {
    testWidgets('bord haut du menu = bord bas du glyphe, dans la fenêtre', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_topHarness());
      final (Rect glyph, Rect menu) = await _open(tester);
      expect(menu.top, moreOrLessEquals(glyph.bottom, epsilon: 0.01));
      expect(menu.left, moreOrLessEquals(glyph.left, epsilon: 0.01));
      expect(window.contains(menu.bottomRight), isTrue);
      expect(menu.overlaps(glyph), isFalse);
    });
  });

  group('CR127-A2 — place insuffisante en dessous ⇒ vers le haut', () {
    testWidgets('bord bas du menu = bord haut du glyphe, dans la fenêtre, '
        'sans recouvrir l\'ancre', (WidgetTester tester) async {
      await tester.pumpWidget(_listHarness(listHeight: 600));
      final (Rect glyph, Rect menu) = await _open(tester);
      // Témoin du scénario : sous le glyphe, il n'y a rien.
      expect(glyph.bottom, moreOrLessEquals(600, epsilon: 0.01));
      expect(
        menu.bottom,
        moreOrLessEquals(glyph.top, epsilon: 0.01),
        reason: '🔴 le menu ne s\'est pas ouvert vers le haut',
      );
      expect(menu.top, greaterThanOrEqualTo(0));
      expect(menu.left, moreOrLessEquals(glyph.left, epsilon: 0.01));
      expect(menu.overlaps(glyph), isFalse);
    });
  });

  group('CR127-A3 — la place se mesure dans le viewport défilable', () {
    testWidgets('menu qui tiendrait dans la fenêtre mais pas dans la liste ⇒ '
        'vers le haut, au-dessus du composer', (WidgetTester tester) async {
      await tester.pumpWidget(
        _listHarness(listHeight: 300, composerHeight: 300),
      );
      final (Rect glyph, Rect menu) = await _open(tester);
      final Rect composer = tester.getRect(find.byKey(const Key('composer')));
      expect(composer.top, moreOrLessEquals(300, epsilon: 0.01));
      // Témoin : le menu TIENDRAIT sous le glyphe dans la fenêtre — c'est
      // bien la borne du viewport qui décide, pas celle de la fenêtre.
      expect(glyph.bottom + menu.height, lessThanOrEqualTo(600));
      expect(
        menu.bottom,
        moreOrLessEquals(glyph.top, epsilon: 0.01),
        reason:
            '🔴 le menu s\'est cru à l\'aise dans la fenêtre et recouvre '
            'le composer',
      );
      expect(menu.overlaps(composer), isFalse);
    });
  });

  group('CR127-A4 — les ancrages explicites sont honorés', () {
    testWidgets('`below` au bas de la liste ⇒ vers le bas, quitte à sortir', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _listHarness(listHeight: 600, anchor: ZChatArtifactMenuAnchor.below),
      );
      final (Rect glyph, Rect menu) = await _open(tester, reachable: false);
      expect(menu.top, moreOrLessEquals(glyph.bottom, epsilon: 0.01));
      expect(menu.bottom, greaterThan(600), reason: 'témoin : il déborde');
    });

    testWidgets('`above` en haut de fenêtre ⇒ vers le haut', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _topHarness(anchor: ZChatArtifactMenuAnchor.above),
      );
      final (Rect glyph, Rect menu) = await _open(tester, reachable: false);
      expect(menu.bottom, moreOrLessEquals(glyph.top, epsilon: 0.01));
    });
  });

  group('CR127-A5 — RTL : le bord de départ reste celui du glyphe', () {
    for (final (String name, Widget tree) in <(String, Widget)>[
      ('vers le bas', _topHarness(direction: TextDirection.rtl)),
      (
        'vers le haut',
        _listHarness(listHeight: 600, direction: TextDirection.rtl),
      ),
    ]) {
      testWidgets(name, (WidgetTester tester) async {
        await tester.pumpWidget(tree);
        final (Rect glyph, Rect menu) = await _open(tester);
        expect(menu.right, moreOrLessEquals(glyph.right, epsilon: 0.01));
        expect(menu.overlaps(glyph), isFalse);
        expect(window.contains(menu.topLeft), isTrue);
      });
    }
  });

  group('CR127-A6 — `below` = les ancres historiques, à l\'octet', () {
    testWidgets('suiveur bottomStart → topStart résolus', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _topHarness(anchor: ZChatArtifactMenuAnchor.below),
      );
      // Le tap fermerait le portail : les ancres se lisent AVANT.
      await _open(tester, reachable: false);
      final CompositedTransformFollower follower = tester.widget(
        find.byType(CompositedTransformFollower),
      );
      expect(follower.targetAnchor, Alignment.bottomLeft);
      expect(follower.followerAnchor, Alignment.topLeft);
      expect(follower.offset, Offset.zero);
      expect(find.byType(CustomSingleChildLayout), findsNothing);
      // Et le menu ancré en mode fixe reste atteignable.
      _invoked = 0;
      await tester.tap(
        find.text(kZChatLabelFallbacks[kZChatLabelArtifactEdit]!),
      );
      await tester.pump();
      expect(_invoked, 1);
    });
  });
}
