/// 🔴 Garde de la **réservation de la place du clavier sous GetX** — pendant
/// de CR-IFFD-122 (2026-08-26), côté binding.
///
/// ## Ce que la mesure a établi, et qui n'était pas l'hypothèse de départ
///
/// Le présentateur GetX ouvre lui aussi `Get.bottomSheet(…,
/// isScrollControlled: true)` et n'a **aucune** lecture de `viewInsets` (grep
/// NÉGATIF : `grep -rn "viewInsets" packages/zcrud_get/lib` ⇒ rc=1, aucune
/// ligne). Le défaut de la CR semblait donc s'y reproduire à l'identique.
///
/// **Il ne s'y reproduit pas.** Mesuré, écran 400×800, clavier 300 dp, corps
/// de quatre champs (288 dp) :
///
/// ```text
/// GetX, code inchangé : sheet=Rect.fromLTRB(0, 212, 400, 500)
///                       f3   =Rect.fromLTRB(28, 436, 372, 492)   ⇒ VISIBLE
/// ```
///
/// `GetModalBottomSheetRoute` borne sa mise en page à la hauteur d'écran
/// **moins** `viewInsets.bottom` — la feuille s'arrête exactement au bord haut
/// du clavier —, là où `showModalBottomSheet` du SDK pose la feuille au bas de
/// l'écran **entier**. Le défaut est donc propre au SDK, pas au mode
/// scroll-controlled en soi.
///
/// ## Ce que cette garde protège
///
/// Elle protège la NON-reprise du correctif ici. Enveloppée d'une seconde
/// réservation, la feuille GetX compterait l'encart deux fois : mesuré, la
/// zone utile tombe de 288 à 200 dp et le corps est écrasé. La garde rougit
/// donc dans les DEUX sens — si GetX cessait de réserver, comme si le socle
/// réservait une seconde fois.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Hauteur intrinsèque du corps de quatre champs (dp) — 4 × (40 + 2 × 8).
const double kBodyHeight = 288;

/// Largeur d'écran du montage (dp).
const double kWidth = 400;

/// Hauteur d'écran du montage (dp).
const double kHeight = 800;

/// Hauteur du clavier simulée (dp).
const double kKeyboard = 300;

/// Corps à quatre champs — `f3`, le dernier, est celui que la QA touche.
Widget fourFields() => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              key: ValueKey<String>('f$i'),
              decoration: InputDecoration(labelText: 'champ $i'),
            ),
          ),
      ],
    );

/// Ouvre la feuille via `presentEdition` **avec le présentateur GetX**,
/// encarts à ZÉRO.
Future<void> openSheet(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewInsets = FakeViewPadding.zero;
  tester.view.physicalSize = const Size(kWidth, kHeight);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => unawaited(
                presentEdition<void>(
                  context,
                  builder: (_) => fourFields(),
                  presenter: const ZGetFormPresenter(),
                  forcedMode: ZEditionPresentation.sheet,
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Rectangle du dernier champ.
Rect lastField(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey<String>('f3')));

void main() {
  testWidgets(
      'KBG-1 — sous GetX, la route réserve DÉJÀ la place du clavier : le '
      'champ focalisé reste visible, et le corps n\'est PAS écrasé',
      (WidgetTester tester) async {
    await openSheet(tester);
    final Rect before = lastField(tester);
    expect(before.bottom, greaterThan(kHeight - kKeyboard),
        reason: 'montage non probant : sans clavier, `f3` doit déjà se '
            'trouver dans la zone que le clavier va recouvrir.');

    await tester.tap(find.byKey(const ValueKey<String>('f3')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: kKeyboard);
    await tester.pumpAndSettle();

    final Rect sheet = tester.getRect(find.byType(BottomSheet));
    final Rect after = lastField(tester);

    // ① La feuille s'arrête au bord haut du clavier — c'est la route GetX qui
    //    le fait, sans que le socle ait rien à ajouter.
    expect(sheet.bottom, equals(kHeight - kKeyboard),
        reason: '🔴 la feuille GetX ne s\'arrête plus au bord haut du '
            'clavier : la réservation que la route faisait d\'elle-même a '
            'disparu, et le socle doit alors la prendre en charge. '
            'Mesuré : $sheet.');

    // ② Le champ focalisé est visible.
    expect(after.bottom, lessThanOrEqualTo(kHeight - kKeyboard),
        reason: '🔴 sous GetX, le champ focalisé est SOUS le clavier. '
            'Mesuré : $after.');

    // ③ ANTI-DOUBLE-COMPTE : le corps garde sa hauteur INTRINSÈQUE. Une
    //    seconde réservation posée par le socle par-dessus celle de la route
    //    la ferait tomber à 200 dp (mesuré) — la feuille resterait « bien
    //    placée », mais le formulaire serait écrasé.
    expect(sheet.height, equals(kBodyHeight),
        reason: '🔴 la place du clavier est réservée DEUX fois : la route '
            'GetX la retranche déjà, et le socle vient d\'en retrancher une '
            'seconde. Hauteur utile mesurée : ${sheet.height} dp au lieu de '
            '$kBodyHeight.');
    expect(tester.takeException(), isNull,
        reason: 'un double comptage ferait déborder le corps.');

    // ④ Le clavier redescend : retour EXACT à l\'état d\'avant.
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(lastField(tester), equals(before),
        reason: '🔴 clavier refermé, la géométrie ne revient pas à son état '
            'initial.');
  });
}
