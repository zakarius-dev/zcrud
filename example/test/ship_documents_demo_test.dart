import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/demos/ship_documents_demo_screen.dart';

import 'support/pump_helpers.dart';

/// Gardes du **gabarit de référence** « stepper racine tout-affiché contenant un
/// sous-stepper paginé DYNAMIQUE » (CR DODLP `cr-ship-handling-nested-docs`).
///
/// Les trois propriétés qui font la valeur du gabarit — et qui doivent MORDRE :
///
/// * **G1** — choisir une valeur amont change RÉELLEMENT l'ensemble des
///   sous-étapes montées (pas leur seul libellé) : la garde parcourt tout le
///   sous-stepper et compare l'ensemble des champs de statut effectivement
///   montés à [demoRequiredDocuments] ;
/// * **G2** — pendant le chargement asynchrone, l'écran reste utilisable et
///   honnête : l'étape d'attente est seule montée, AUCUN document n'est
///   affiché, et les étapes racine restent saisissables ;
/// * **G3** — une saisie faite dans une sous-étape qui DISPARAÎT ensuite est
///   **conservée**, jamais purgée en silence (doctrine v0.65.0).
///
/// Plus les deux confirmations demandées par la CR : sous-titre **par choix**
/// d'un `rowChips` (G4) et **seams fichier** sur une valeur de tranche faite
/// d'ids opaques (G5).
void main() {
  // Latence assez large pour que la fenêtre de chargement soit OBSERVABLE
  // (l'animation de fermeture du menu du select dure ~300 ms).
  const repo = DemoShipRepository(latency: Duration(milliseconds: 900));

  /// Sélectionne un navire SANS laisser le chargement se terminer.
  Future<void> pickShip(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<Object?>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    // Fermeture du menu seulement — on reste DANS la fenêtre de chargement.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Laisse le dépôt répondre puis stabilise.
  Future<void> settleLoad(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  }

  /// Parcourt TOUT le sous-stepper paginé et retourne l'ensemble des documents
  /// dont le champ de statut a été réellement **monté**. C'est la mesure qui
  /// distingue « la liste a changé » de « le libellé a changé ».
  Future<Set<DemoShipDocument>> mountedDocuments(WidgetTester tester) async {
    final found = <DemoShipDocument>{};
    // Borne dure : le sous-stepper ne peut pas avoir plus d'étapes que de
    // documents déclarés (+ l'étape d'attente).
    for (var i = 0; i <= DemoShipDocument.values.length + 1; i++) {
      for (final d in DemoShipDocument.values) {
        if (find
            .text('Statut — ${kShipDocumentLabels[d]}')
            .evaluate()
            .isNotEmpty) {
          found.add(d);
        }
      }
      final next = find.widgetWithText(FilledButton, 'Suivant');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next.first);
      await tester.pumpAndSettle();
    }
    return found;
  }

  Future<void> pumpDemo(WidgetTester tester) async {
    useTallSurface(tester, height: 12000);
    await tester
        .pumpWidget(wrapForTest(const ShipDocumentsDemoScreen(repository: repo)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'G0 — la page est MESURÉE : la dernière étape racine est bien montée',
      (tester) async {
    await pumpDemo(tester);
    // 🔴 Sans cette garde, une surface trop courte ferait cesser d'observer les
    // dernières étapes du `ListView.builder` — vert en n'observant plus rien.
    expect(find.text('Remarques du contrôle'), findsOneWidget,
        reason: 'Le dernier champ de la dernière étape racine doit être monté '
            '— sinon la surface de test tronque le stepper déplié.');
    expect(find.text('Identification du navire'), findsOneWidget);
    expect(find.text('Contrôle des documents'), findsOneWidget);
    expect(find.text('Photos et remarques'), findsOneWidget);

    // …et elle doit le rester dans l'état le PLUS CHARGÉ (sous-stepper monté
    // avec statut + pièces), qui est celui où la troncature guette.
    await pickShip(tester, 'MT Kara (pétrolier)');
    await settleLoad(tester);
    expect(find.text('Statut — ${kShipDocumentLabels[DemoShipDocument.crewList]}'),
        findsOneWidget);
    expect(find.text('Remarques du contrôle'), findsOneWidget,
        reason: 'Mesure encore valable une fois le sous-stepper monté.');
  });

  testWidgets(
      'G2 — pendant le chargement : étape d\'attente SEULE, écran utilisable',
      (tester) async {
    await pumpDemo(tester);
    await pickShip(tester, 'MT Kara (pétrolier)');

    // Honnête : l'attente est nommée…
    expect(find.text('En attente du type de navire'), findsWidgets);
    expect(find.text('Chargement du type de navire…'), findsOneWidget);
    // …et AUCUN document n'est monté (ni faux, ni ceux du navire précédent).
    for (final d in DemoShipDocument.values) {
      expect(find.text('Statut — ${kShipDocumentLabels[d]}'), findsNothing,
          reason: 'Aucun document ne doit être monté avant que le type soit '
              'connu (${d.name}).');
    }
    // Utilisable : une étape racine reste saisissable pendant l'attente.
    await tester.enterText(
        find.widgetWithText(TextField, 'Remarques du contrôle'), 'RAS');
    await tester.pump();
    expect(find.text('RAS'), findsOneWidget);

    await settleLoad(tester);
    expect(find.text('Chargement du type de navire…'), findsNothing);
  });

  testWidgets(
      'G1 — le type chargé change RÉELLEMENT l\'ensemble des sous-étapes',
      (tester) async {
    await pumpDemo(tester);

    await pickShip(tester, 'MT Kara (pétrolier)');
    await settleLoad(tester);
    expect(await mountedDocuments(tester),
        demoRequiredDocuments(DemoShipType.tanker).toSet(),
        reason: 'Pétrolier ⇒ équipage + manifeste + registre hydrocarbures.');

    await pickShip(tester, 'MSC Lomé (porte-conteneurs)');
    await settleLoad(tester);
    expect(await mountedDocuments(tester),
        demoRequiredDocuments(DemoShipType.container).toSet(),
        reason: 'Changer de navire doit MONTER un autre ensemble de '
            'sous-étapes, pas renommer les mêmes.');

    await pickShip(tester, 'MV Aného (vraquier)');
    await settleLoad(tester);
    expect(await mountedDocuments(tester),
        demoRequiredDocuments(DemoShipType.bulk).toSet());
  });

  testWidgets(
      'G3 — une saisie dont la sous-étape disparaît est CONSERVÉE',
      (tester) async {
    await pumpDemo(tester);
    await pickShip(tester, 'MT Kara (pétrolier)');
    await settleLoad(tester);

    // Naviguer jusqu'au document PROPRE au pétrolier, et y saisir un statut.
    final target = 'Statut — '
        '${kShipDocumentLabels[DemoShipDocument.oilRecordBook]}';
    for (var i = 0; i < 6 && find.text(target).evaluate().isEmpty; i++) {
      await tester.tap(find.widgetWithText(FilledButton, 'Suivant').first);
      await tester.pumpAndSettle();
    }
    expect(find.text(target), findsOneWidget,
        reason: 'La sous-étape du registre des hydrocarbures doit être '
            'atteignable pour un pétrolier.');
    // 🔴 `ensureVisible` AVANT le tap : le sous-stepper vit dans un viewport
    // imbriqué, et un tap sur une puce hors écran est signalé mais NON délivré
    // — la garde cesserait alors d'observer ce qu'elle prétend mesurer.
    final chip = find.widgetWithText(ChoiceChip, 'Conforme');
    await tester.ensureVisible(chip.first);
    await tester.pumpAndSettle();
    await tester.tap(chip.first);
    await tester.pumpAndSettle();
    // La saisie a bien été enregistrée AVANT que la sous-étape disparaisse.
    expect(tester.widget<ChoiceChip>(chip.first).selected, isTrue,
        reason: 'Le tap doit avoir réellement sélectionné le statut.');
    // Aucune valeur orpheline tant que le document est au périmètre.
    expect(find.byKey(const ValueKey<String>('ship-orphan-banner')),
        findsNothing);

    // Le navire change : la sous-étape disparaît.
    await pickShip(tester, 'MSC Lomé (porte-conteneurs)');
    await settleLoad(tester);
    expect(find.text(target), findsNothing,
        reason: 'Le registre des hydrocarbures n\'est plus exigé.');

    // 🔴 La valeur, elle, est TOUJOURS là — jamais purgée en silence.
    expect(find.byKey(const ValueKey<String>('ship-orphan-banner')),
        findsOneWidget,
        reason: 'Le statut saisi sur une sous-étape disparue doit être '
            'CONSERVÉ (doctrine des choix orphelins, v0.65.0).');
    expect(
        find.textContaining('1 statut(s) saisi(s) pour un document hors '
            'périmètre'),
        findsOneWidget);
  });

  testWidgets('G4 — rowChips : libellé ET sous-titre par choix', (tester) async {
    await pumpDemo(tester);
    await pickShip(tester, 'MV Aného (vraquier)');
    await settleLoad(tester);

    expect(find.text('Conforme'), findsOneWidget);
    expect(find.text('Présent, lisible et en cours de validité.'),
        findsOneWidget,
        reason: '`ZFieldChoice.subtitle` doit être rendu — c\'est la '
            'confirmation demandée pour `DocumentStatus.description`.');
    expect(find.text('Non exigé pour ce navire.'), findsOneWidget);
  });

  testWidgets(
      'G5 — seams fichier : une tranche faite d\'IDS opaques est résolue',
      (tester) async {
    await pumpDemo(tester);
    await pickShip(tester, 'MV Aného (vraquier)');
    await settleLoad(tester);

    // La première sous-étape (liste d'équipage) porte la référence persistée.
    expect(
        find.text(
            'Statut — ${kShipDocumentLabels[DemoShipDocument.crewList]}'),
        findsOneWidget);
    expect(find.text('ref-crew-2024-001.pdf'), findsOneWidget,
        reason: 'Sans `ZcrudScope.appFileResolver`, un id persisté serait '
            'SILENCIEUSEMENT ignoré et le champ paraîtrait vide.');
  });
}
