/// 🔴 **Fermeture par GLISSEMENT sous GetX** — le trou mesuré chez les hôtes
/// GetX (DODLP, IFFD), et sa fermeture par `ZGetFormPresenter`.
///
/// ## Le fait, mesuré (get 4.7.2 + Flutter 3.44.4, 2026-08-09)
///
/// `ZDiscardGuard` est un `PopScope`, et `PopScope` n'est consulté que par
/// `Navigator.maybePop`. Or la feuille GetX se ferme au glissement par
/// `BottomSheet.onClosing → Navigator.pop(context)` — écrit **noir sur blanc**
/// dans `get/lib/get_navigation/src/bottomsheet/bottomsheet.dart` :
///
/// ```dart
/// BottomSheet(
///   onClosing: () { if (widget.route!.isCurrent) { Navigator.pop(context); } },
///   …
/// )
/// ```
///
/// | Voie                | Seam de confirmation | Feuille    |
/// |---------------------|----------------------|------------|
/// | tap sur la barrière | **appelé**           | reste      |
/// | **glissement**      | **JAMAIS appelé**    | **fermée** |
///
/// ⇒ **saisie perdue sans confirmation**, sous GetX comme sous Flutter nu.
///
/// ## Ce que gardent les volets
///
/// * **GD-1 (tripwire amont)** : affirme **la perte** telle qu'elle existe
///   aujourd'hui, sur un montage `Get.bottomSheet` BRUT. Le jour où GetX (ou
///   Flutter) fera passer le glissement par `maybePop`, ce volet **rougit** et
///   désigne notre contournement comme devenu inutile.
/// * **GD-2** : avec `chrome` armé d'un `formController`, le glissement **ne
///   ferme plus** — la garde affirme la **perte évitée** (corps toujours monté
///   **et** valeur du contrôleur intacte), jamais la seule présence d'un widget.
/// * **GD-3** : la voie qui, elle, honore `PopScope` (barrière) **reste**
///   ouverte — on ne remplace pas un défaut par une impasse.
/// * **GD-4** : SANS garde d'abandon, le glissement reste actif.
/// * **GD-5 (TRIPWIRE de contrat)** : `ZGetFormPresenter` **implémente**
///   `ZImplicitDismissControl`. Sans ce volet, retirer l'interface ferait
///   retomber `presentEdition` sur `present` **en silence** (AD-10 : repli sans
///   exception) — c'est exactement ainsi que le trou avait survécu.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

ZFormController _dirtyController() {
  final ZFormController c =
      ZFormController(initialValues: const <String, Object?>{'a': 'initial'});
  c.setValue('a', 'saisie-utilisateur');
  return c;
}

/// Hôte GetX minimal : un bouton qui capture un vrai `BuildContext`.
Widget _app(void Function(BuildContext context) onPressed) => GetMaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
      ],
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onPressed(context),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );

/// Ouvre une feuille d'édition GetX via `presentEdition`.
///
/// Le passage par `presentEdition` est délibéré : c'est lui qui teste
/// `is ZImplicitDismissControl`. Un test qui appellerait
/// `presentWithDismissControl` en direct **contournerait** le repli qu'on garde.
Future<void> _open(
  WidgetTester tester, {
  required ZEditionChrome? chrome,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app((BuildContext context) {
    unawaited(presentEdition<void>(
      context,
      builder: (_) => const SizedBox(height: 300, child: Text('FORMULAIRE')),
      presenter: const ZGetFormPresenter(),
      chrome: chrome,
      forcedMode: ZEditionPresentation.sheet,
    ));
  }));
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => Get.testMode = true);

  testWidgets(
      'GD-1 — TRIPWIRE amont : sur un `Get.bottomSheet` BRUT, le glissement '
      'ferme la feuille SANS appeler la confirmation (saisie perdue)',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final ZFormController form = _dirtyController();
    addTearDown(form.dispose);
    int confirmations = 0;

    await tester.pumpWidget(_app((BuildContext context) {
      unawaited(Get.bottomSheet<void>(
        ZDiscardGuard(
          controller: form,
          onConfirmDiscard: () async {
            confirmations++;
            return false; // l'utilisateur REFUSE d'abandonner
          },
          child: const SizedBox(height: 300, child: Text('FORMULAIRE')),
        ),
        isScrollControlled: true,
      ));
    }));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('FORMULAIRE'), findsOneWidget);

    await tester.fling(find.text('FORMULAIRE'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();

    expect(find.text('FORMULAIRE'), findsNothing,
        reason: '🟢 si ce volet rougit, le glissement passe DÉSORMAIS par '
            '`maybePop` : le contournement `enableDrag: false` de '
            '`ZGetFormPresenter` est devenu inutile et doit être retiré.');
    expect(confirmations, 0,
        reason: '🟢 même remarque : la confirmation serait devenue '
            'atteignable par glissement.');
  });

  testWidgets(
      'GD-2 — avec chrome gardé, le glissement NE FERME PLUS et la saisie est '
      'PRÉSERVÉE', (WidgetTester tester) async {
    final ZFormController form = _dirtyController();
    addTearDown(form.dispose);
    int confirmations = 0;

    await _open(
      tester,
      chrome: ZEditionChrome(
        title: 'Édition',
        formController: form,
        onConfirmDiscard: () async {
          confirmations++;
          return false;
        },
      ),
    );
    expect(find.text('FORMULAIRE'), findsOneWidget);

    await tester.fling(find.text('FORMULAIRE'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();

    expect(find.text('FORMULAIRE'), findsOneWidget,
        reason: '🔴 la feuille GetX s\'est fermée par GLISSEMENT alors qu\'un '
            'garde d\'abandon est armé : la saisie est perdue sans '
            'confirmation, chez DODLP et IFFD.');
    expect(form.values['a'], 'saisie-utilisateur',
        reason: '🔴 la saisie a été perdue.');
    expect(confirmations, 0,
        reason: 'le glissement est désactivé : il ne doit même pas déclencher '
            'la question.');
  });

  testWidgets(
      'GD-3 — la voie qui HONORE `PopScope` (barrière) reste ouverte',
      (WidgetTester tester) async {
    final ZFormController form = _dirtyController();
    addTearDown(form.dispose);
    int confirmations = 0;

    await _open(
      tester,
      chrome: ZEditionChrome(
        formController: form,
        onConfirmDiscard: () async {
          confirmations++;
          return false;
        },
      ),
    );

    await tester.tapAt(const Offset(200, 20)); // barrière, au-dessus
    await tester.pumpAndSettle();
    expect(confirmations, 1,
        reason: '🔴 le tap sur la barrière ne demande plus confirmation : on a '
            'transformé le défaut en impasse.');
    expect(find.text('FORMULAIRE'), findsOneWidget);
    expect(form.values['a'], 'saisie-utilisateur');
  });

  testWidgets(
      'GD-4 — SANS garde d\'abandon, le glissement reste ACTIF (voie par '
      'défaut intacte)', (WidgetTester tester) async {
    await _open(tester, chrome: const ZEditionChrome(title: 'Édition'));
    expect(find.text('FORMULAIRE'), findsOneWidget);

    await tester.fling(find.text('FORMULAIRE'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    expect(find.text('FORMULAIRE'), findsNothing,
        reason: '🔴 le glissement a été désactivé alors qu\'AUCUN garde '
            'd\'abandon n\'est armé : régression d\'ergonomie sur la voie par '
            'défaut.');
  });

  test(
      'GD-5 — TRIPWIRE de CONTRAT : `ZGetFormPresenter` implémente '
      '`ZImplicitDismissControl` (sinon `presentEdition` retombe EN SILENCE)',
      () {
    const ZFormPresenter presenter = ZGetFormPresenter();
    expect(presenter, isA<ZImplicitDismissControl>(),
        reason: '🔴 le présentateur GetX a cessé d\'implémenter le port de '
            'contrôle des fermetures implicites : `presentEdition` le teste '
            'par `is` et retombe sur `present` SANS erreur (AD-10). Les hôtes '
            'GetX reperdraient le garde de glissement ET la feuille '
            'contrainte/encadrée, en silence.');
  });
}
