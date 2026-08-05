/// **CR-IFFD-61 ③** — les paddings STRUCTURELS de la feuille de fratrie
/// cessent de rider `gapM`.
///
/// 🔴 **Ce que la garde mesure, et l'angle mort visé** : la POSITION RÉELLE du
/// contenu de la feuille (`getRect` du titre et du pied comparés à la boîte de
/// la feuille), jamais la propriété d'un `Padding`. Et elle la mesure **sous un
/// thème qui règle `gapM` à 12** — le montage réel d'IFFD : c'est le seul qui
/// distingue « le token est lu » de « la valeur coïncide avec `gapM` ».
///
/// 🔵 **Correction factuelle portée au handoff** : la CR affirmait que `gapM`
/// portait TROIS valeurs de référence (padding de carte 12, écart 16,
/// feuille 8). Le padding de carte a DÉJÀ son slot depuis CR-LEX-70
/// (`contentPadding`) — il n'en restait donc que DEUX.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

const String _kSheetTitle = 'SHEET_TITLE';

/// Le montage réel d'IFFD : `gapM` scopé à 12 pour le padding de ses cartes.
const ZcrudTheme _kIffdLike = ZcrudTheme(gapM: 12);

ZSubfolderNavSpec _spec() => ZSubfolderNavSpec(
      subfolders: refs(),
      allSubfoldersLabel: kAllLabel,
      sheetTitle: _kSheetTitle,
      addLabel: kAddLabel,
      // Le pied de feuille n'est monté que si l'ACTION existe (CR-IFFD-44).
      addAction: () {},
    );

Widget Function(Widget) _scoped(ZcrudTheme theme) =>
    (Widget child) => ZcrudScope(theme: theme, child: child);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(ZSubfolderSelectorBar.triggerKey));
  await tester.pumpAndSettle();
}

/// Retrait RÉEL, dans le sens de lecture, entre la `Column` de la feuille
/// (`sheetKey`, posée SOUS la gouttière) et le bord du contenu.
double _inset(WidgetTester tester, Finder content) {
  final Rect sheet = tester.getRect(find.byKey(ZSubfolderSelectorBar.sheetKey));
  return tester.getRect(content).left - sheet.left;
}

/// La GOUTTIÈRE elle-même : retrait entre la surface modale et la `Column`.
///
/// 🔴 Mesure DISTINCTE de [_inset] : `sheetKey` est posée SOUS le `Padding` de
/// gouttière. Une garde qui ne mesurerait que [_inset] laisserait la gouttière
/// rider `gapM` sans rougir — c'est exactement l'angle mort de la CR.
double _gutter(WidgetTester tester) {
  final Rect outer = tester.getRect(find.byType(BottomSheet));
  final Rect sheet = tester.getRect(find.byKey(ZSubfolderSelectorBar.sheetKey));
  return sheet.left - outer.left;
}

void main() {
  group('CR-IFFD-61 ③ — gouttière interne de la feuille', () {
    testWidgets('DÉFAUT (jeton nul) sous `gapM: 12` ⇒ le retrait suit `gapM` — '
        'rendu STRICTEMENT inchangé', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(tester, nav: _spec(), wrap: _scoped(_kIffdLike));
      await _open(tester);
      // Gouttière ET padding du titre suivent `gapM` (12) — les deux mesures.
      expect(_gutter(tester), 12);
      expect(_inset(tester, find.byKey(ZSubfolderSelectorBar.sheetTitleKey)), 12);
    });

    testWidgets(
        '🔴 jeton fourni ⇒ le retrait suit le JETON, et `gapM` (12) n\'y est '
        'plus pour rien', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(),
        wrap: _scoped(const ZcrudTheme(
          gapM: 12,
          subfolderSheetContentPadding: EdgeInsetsDirectional.all(8),
        )),
      );
      await _open(tester);
      expect(
        _gutter(tester),
        8,
        reason: '🔴 la GOUTTIÈRE ride encore `gapM` (12 au lieu de 8)',
      );
      expect(
        _inset(tester, find.byKey(ZSubfolderSelectorBar.sheetTitleKey)),
        8,
        reason: '🔴 le padding du TITRE ride encore `gapM`',
      );
      // Le PIED « ajouter » suit le même jeton (c'est la STRUCTURE de la
      // feuille, pas seulement son titre).
      expect(
        _inset(tester, find.byKey(ZSubfolderSelectorBar.footerAddKey)),
        8,
        reason: '🔴 le padding du PIED ride encore `gapM`',
      );
    });

    testWidgets(
        '🔴 le jeton NE touche PAS la marge EXTÉRIEURE `subfolderSheetPadding` '
        '(deux rôles distincts, CR-IFFD-46)', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(),
        wrap: _scoped(const ZcrudTheme(
          subfolderSheetContentPadding: EdgeInsetsDirectional.all(8),
        )),
      );
      await _open(tester);
      expect(
        find.byKey(ZSubfolderSelectorBar.sheetPaddingKey),
        findsNothing,
        reason: '🔴 le jeton interne a matérialisé l\'enveloppe EXTERNE : la '
            'neutralité littérale de CR-IFFD-46 est perdue',
      );
    });

    testWidgets('🔴 RTL — le retrait est mesuré du côté DÉBUT, qui est la '
        'droite (AD-13)', (tester) async {
      await setScreen(tester, 320, 800);
      await pumpDetail(
        tester,
        nav: _spec(),
        textDirection: TextDirection.rtl,
        wrap: _scoped(const ZcrudTheme(
          gapM: 12,
          subfolderSheetContentPadding:
              EdgeInsetsDirectional.only(start: 8, end: 20),
        )),
      );
      await _open(tester);
      final Rect sheet =
          tester.getRect(find.byKey(ZSubfolderSelectorBar.sheetKey));
      final Rect title =
          tester.getRect(find.byKey(ZSubfolderSelectorBar.sheetTitleKey));
      // `start` = DROITE en RTL : le 8 se lit à DROITE, le 20 à gauche. Une
      // garde qui lirait `left` verrait 20 et croirait à un bug.
      expect(sheet.right - title.right, 8);
      expect(title.left - sheet.left, 20);
      // …et la gouttière elle-même bascule aussi.
      final Rect outer = tester.getRect(find.byType(BottomSheet));
      expect(outer.right - sheet.right, 8);
      expect(sheet.left - outer.left, 20);
    });
  });
}
