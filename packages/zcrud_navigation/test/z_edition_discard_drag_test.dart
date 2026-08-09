/// 🔴 **Fermeture par GLISSEMENT d'une feuille** — le trou mesuré, et sa
/// fermeture par `presentEdition(chrome:)`.
///
/// ## Le fait, mesuré (Flutter 3.44.4, 2026-08-09)
///
/// `ZDiscardGuard` est un `PopScope`. `PopScope` n'est consulté que par
/// `Navigator.maybePop`. Or `showModalBottomSheet` ferme la feuille au
/// glissement via `BottomSheet.onClosing → Navigator.pop(context)`
/// (`packages/flutter/lib/src/material/bottom_sheet.dart`, `_handleDragEnd`).
///
/// | Voie                | Seam de confirmation | Feuille |
/// |---------------------|----------------------|---------|
/// | tap sur la barrière | **appelé**           | reste   |
/// | **glissement**      | **JAMAIS appelé**    | **fermée** |
///
/// ⇒ **saisie perdue sans confirmation**.
///
/// ## Ce que gardent les volets
///
/// * **DD-1 (tripwire amont)** : affirme **la perte**, telle qu'elle existe
///   aujourd'hui dans le SDK, sur un montage BRUT. Le jour où Flutter fera
///   passer le glissement par `maybePop`, ce volet **rougit** et désigne notre
///   contournement comme devenu inutile — c'est le pendant exact de la
///   discipline « tripwire » recommandée aux hôtes.
/// * **DD-2** : avec `chrome` armé d'un `formController`, le glissement **ne
///   ferme plus** — la saisie est **préservée**. La garde affirme la **perte
///   évitée** (corps toujours monté + valeur du contrôleur intacte), pas la
///   présence d'un widget.
/// * **DD-3** : la voie qui, elle, honore `PopScope` (barrière) **reste**
///   ouverte — on ne remplace pas un défaut par une impasse.
/// * **DD-4** : SANS chrome (ou sans garde d'abandon), le glissement reste
///   actif — la voie par défaut n'est pas touchée.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

ZFormController _dirtyController() {
  final ZFormController c =
      ZFormController(initialValues: const <String, Object?>{'a': 'initial'});
  c.setValue('a', 'saisie-utilisateur');
  return c;
}

Widget _app(VoidCallback onPressed) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
      ],
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: onPressed,
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );

void main() {
  testWidgets(
      'DD-1 — TRIPWIRE amont : sur un montage BRUT, le glissement ferme la '
      'feuille SANS appeler la confirmation (saisie perdue)',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final ZFormController form = _dirtyController();
    addTearDown(form.dispose);
    int confirmations = 0;

    late BuildContext hostContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) {
            hostContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    unawaited(showModalBottomSheet<void>(
      context: hostContext,
      isScrollControlled: true,
      builder: (_) => ZDiscardGuard(
        controller: form,
        onConfirmDiscard: () async {
          confirmations++;
          return false; // l'utilisateur REFUSE d'abandonner
        },
        child: const SizedBox(height: 300, child: Text('FORMULAIRE')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('FORMULAIRE'), findsOneWidget);

    await tester.fling(find.text('FORMULAIRE'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();

    expect(find.text('FORMULAIRE'), findsNothing,
        reason: '🟢 si ce volet rougit, Flutter a CORRIGÉ le glissement '
            '(il passerait désormais par `maybePop`) : le contournement de '
            '`ZAdaptivePresenter` (`enableDrag: false`) est devenu inutile et '
            'doit être retiré.');
    expect(confirmations, 0,
        reason: '🟢 même remarque : la confirmation serait devenue '
            'atteignable par glissement.');
  });

  testWidgets(
      'DD-2 — avec chrome gardé, le glissement NE FERME PLUS et la saisie est '
      'PRÉSERVÉE', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final ZFormController form = _dirtyController();
    addTearDown(form.dispose);
    int confirmations = 0;

    late BuildContext hostContext;
    await tester.pumpWidget(_app(() {}));
    hostContext = tester.element(find.text('ouvrir'));
    unawaited(presentEdition<void>(
      hostContext,
      builder: (_) => const SizedBox(height: 300, child: Text('FORMULAIRE')),
      chrome: ZEditionChrome(
        title: 'Édition',
        formController: form,
        onConfirmDiscard: () async {
          confirmations++;
          return false;
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('FORMULAIRE'), findsOneWidget);

    await tester.fling(find.text('FORMULAIRE'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();

    expect(find.text('FORMULAIRE'), findsOneWidget,
        reason: '🔴 la feuille s\'est fermée par GLISSEMENT alors qu\'un garde '
            'd\'abandon est armé : la saisie est perdue sans confirmation.');
    expect(form.values['a'], 'saisie-utilisateur',
        reason: '🔴 la saisie a été perdue.');
    expect(confirmations, 0,
        reason: 'le glissement est désactivé : il ne doit même pas déclencher '
            'la question.');
  });

  testWidgets(
      'DD-3 — la voie qui HONORE `PopScope` (barrière) reste ouverte',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);
    final ZFormController form = _dirtyController();
    addTearDown(form.dispose);
    int confirmations = 0;

    await tester.pumpWidget(_app(() {}));
    unawaited(presentEdition<void>(
      tester.element(find.text('ouvrir')),
      builder: (_) => const SizedBox(height: 300, child: Text('FORMULAIRE')),
      chrome: ZEditionChrome(
        formController: form,
        onConfirmDiscard: () async {
          confirmations++;
          return false;
        },
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(200, 20)); // barrière, au-dessus
    await tester.pumpAndSettle();
    expect(confirmations, 1,
        reason: '🔴 le tap sur la barrière ne demande plus confirmation : on a '
            'transformé le défaut en impasse.');
    expect(find.text('FORMULAIRE'), findsOneWidget);
  });

  testWidgets(
      'DD-4 — SANS garde d\'abandon, le glissement reste ACTIF (voie par '
      'défaut intacte)', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(() {}));
    unawaited(presentEdition<void>(
      tester.element(find.text('ouvrir')),
      builder: (_) => const SizedBox(height: 300, child: Text('FORMULAIRE')),
      chrome: const ZEditionChrome(title: 'Édition'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('FORMULAIRE'), findsOneWidget);

    await tester.fling(find.text('FORMULAIRE'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    expect(find.text('FORMULAIRE'), findsNothing,
        reason: '🔴 le glissement a été désactivé alors qu\'AUCUN garde '
            'd\'abandon n\'est armé : régression d\'ergonomie sur la voie par '
            'défaut.');
  });
}
