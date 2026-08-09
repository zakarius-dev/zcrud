// Vitrine « Stepper & sous-listes » — ce fichier EXERCE les quatre propriétés
// que la page prétend démontrer. Une page de démonstration qui compile mais ne
// montre rien est un décor : chaque assertion ci-dessous porte la propriété
// elle-même, pas sa mise en scène.
//
//   S1  mode DÉPLIÉ (v0.66.0) — rail numéroté, badges, titre + sous-titre par
//       étape, et surtout : le champ de la DERNIÈRE étape est réellement monté
//       (sans quoi le test aurait cessé d'observer sous le viewport) ;
//   S2  ACL de sous-liste basculable EN DIRECT — les actions de ligne
//       disparaissent puis reviennent (les DEUX sens) ;
//   S3  champ custom à valeur STRUCTURÉE — une map vide bloque « Suivant » ET
//       affiche son message (le refus muet corrigé en v0.67.0), une map garnie
//       laisse passer ;
//   S4  `rowChips` en mono, en multi, et à choix DYNAMIQUES.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/app.dart';
import 'package:zcrud_example/demos/stepper_sub_list_demo_screen.dart';

import 'support/pump_helpers.dart';

Widget _host() => const MaterialApp(
      localizationsDelegates: <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZcrudLocalizationsDelegate.supportedLocales,
      home: StepperSubListDemoScreen(),
    );

Finder get _next => find.widgetWithText(FilledButton, 'Suivant');
Finder get _expandToggle => find.byTooltip('Mode paginé');
Finder get _aclToggle => find.byTooltip('ACL : tout permis');

/// Franchit l'étape « Autorisations » en cochant un module (la map cesse d'être
/// vide) puis en validant le gate. Laisse le stepper sur « Historique ».
Future<void> _goToHistorique(WidgetTester tester) async {
  await tester.tap(_next); // Identité → Autorisations
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey<String>('perm-agents')));
  await tester.pumpAndSettle();
  await tester.tap(_next); // Autorisations → Historique
  await tester.pumpAndSettle();
  expect(find.byType(ZSubListFieldWidget), findsOneWidget,
      reason: 'le scénario doit réellement atteindre l\'étape Historique');
}

void main() {
  // ── S1 — mode déplié réellement rendu, et réellement MESURÉ ───────────────

  testWidgets(
      'S1 — mode déplié : rail numéroté, titre + sous-titre par étape, et le '
      'champ de la DERNIÈRE étape est monté', (tester) async {
    useTallSurface(tester);
    // L'arbre sémantique RÉEL (et non le seul widget `Semantics`) : c'est lui
    // qu'un lecteur d'écran voit.
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // Départ : mode paginé — une seule étape à l'écran (garde non vacante).
    expect(find.byType(ZSubListFieldWidget), findsNothing);

    await tester.tap(_expandToggle);
    await tester.pumpAndSettle();

    // Les TROIS en-têtes d'étape sont annoncés (AD-13) …
    for (var i = 0; i < 3; i++) {
      final titre = <String>['Identité', 'Autorisations', 'Historique'][i];
      // Le nœud sémantique FUSIONNE l'annonce, le titre, le sous-titre et le
      // numéro de badge : on cherche donc un motif dans le libellé réel.
      expect(
          find.bySemanticsLabel(RegExp('Étape ${i + 1} sur 3 : $titre')),
          findsOneWidget,
          reason: 'en-tête de l\'étape ${i + 1} attendu');
    }
    // … avec leur badge numéroté …
    for (final n in <String>['1', '2', '3']) {
      expect(find.text(n), findsOneWidget, reason: 'badge $n attendu');
    }
    // … et leur sous-titre (showSubtitles: true).
    expect(find.text('Sous-liste compacte + ACL de ligne basculable'),
        findsOneWidget);

    // 🔴 Le piège du viewport : le champ de la DERNIÈRE étape doit être
    // réellement construit — sinon le test serait vert en ayant cessé
    // d'observer la moitié de la page.
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
    expect(find.byType(ZRowChipsFieldWidget), findsNWidgets(3));
    expect(find.byKey(const ValueKey<String>('perm-agents')), findsOneWidget);
    semantics.dispose();
  });

  // ── S2 — ACL de sous-liste : les DEUX sens ────────────────────────────────

  testWidgets(
      'S2 — la bascule d\'ACL retire puis rend les actions de ligne de la '
      'sous-liste', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await _goToHistorique(tester);

    // Une ligne réelle : sans elle, l'absence d'actions serait vacante.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Poste').hitTestable(), 'Lomé');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Lomé'), findsWidgets);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    // ACL → consultation seule : les affordances d'écriture s'en vont.
    await tester.tap(_aclToggle);
    await tester.pumpAndSettle();
    expect(find.byType(ZSubListFieldWidget), findsOneWidget,
        reason: 'la sous-liste reste montée : c\'est l\'ACL qui filtre');
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
    // La consultation, elle, reste offerte.
    expect(find.byIcon(Icons.visibility), findsOneWidget);

    // Retour : elles reviennent (anti-tautologie « toujours non »).
    await tester.tap(find.byTooltip('ACL : consultation seule'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  // ── S3 — valeur structurée : le requis MORD, et il le DIT ─────────────────

  testWidgets(
      'S3 — une map vide bloque « Suivant » AVEC son message ; une map garnie '
      'laisse passer', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    await tester.tap(_next); // Identité → Autorisations
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('perm-agents')), findsOneWidget);
    expect(find.text('0 module(s) autorisé(s)'), findsOneWidget);

    // Branche BLOQUANTE : le gate refuse …
    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(find.byType(ZSubListFieldWidget), findsNothing,
        reason: 'une map requise VIDE ne doit pas franchir le gate');
    // … et il ne refuse pas EN SILENCE.
    expect(find.text('Autorisez au moins un module pour continuer.'),
        findsWidgets);

    // Branche PASSANTE : la map écrite par le champ custom est une vraie map.
    await tester.tap(find.byKey(const ValueKey<String>('perm-agents')));
    await tester.pumpAndSettle();
    expect(find.text('1 module(s) autorisé(s)'), findsOneWidget);
    expect(find.text('Autorisez au moins un module pour continuer.'),
        findsNothing);

    await tester.tap(_next);
    await tester.pumpAndSettle();
    expect(find.byType(ZSubListFieldWidget), findsOneWidget);
  });

  // ── S4 — `rowChips` : mono, multi, et choix dynamiques ────────────────────

  testWidgets('S4 — rowChips : mono statique, choix dynamiques, multi',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // Mono = ChoiceChip (corps : 2 + grade : 3) ; multi = FilterChip (3).
    expect(find.byType(ChoiceChip), findsNWidgets(5));
    expect(find.byType(FilterChip), findsNWidgets(3));

    // Choix DYNAMIQUES : les grades suivent le corps, en direct.
    expect(find.text('Sergent'), findsOneWidget);
    expect(find.text('Brigadier'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Gendarmerie'));
    await tester.pumpAndSettle();
    expect(find.text('Brigadier'), findsOneWidget);
    expect(find.text('Sergent'), findsNothing,
        reason: 'la source dynamique REMPLACE les grades de l\'autre corps');
    // La valeur devenue ORPHELINE n'est pas jetée en silence : le socle la
    // garde visible et sélectionnée sous un libellé d'indisponibilité.
    expect(find.widgetWithText(ChoiceChip, 'Option unavailable'),
        findsOneWidget);

    // MULTI : chaque puce bascule indépendamment, et deux restent cochées.
    FilterChip chip(String label) =>
        tester.widget<FilterChip>(find.widgetWithText(FilterChip, label));
    expect(chip('Transmissions').selected, isFalse);
    await tester.tap(find.widgetWithText(FilterChip, 'Transmissions'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Logistique'));
    await tester.pumpAndSettle();
    expect(chip('Transmissions').selected, isTrue);
    expect(chip('Logistique').selected, isTrue);
    expect(chip('Secourisme').selected, isFalse,
        reason: 'le multi coche, il ne remplace pas');

    // …et la décoche est bien une décoche (pas un mono déguisé à l'envers).
    await tester.tap(find.widgetWithText(FilterChip, 'Transmissions'));
    await tester.pumpAndSettle();
    expect(chip('Transmissions').selected, isFalse);
    expect(chip('Logistique').selected, isTrue);
  });

  // ── S5 — la page est ATTEIGNABLE depuis l'accueil ─────────────────────────
  //
  // Aucune garde préexistante n'exige qu'une page déclarée soit joignable
  // (`grep -rn "_entries" example/test` → RC=1, aucune occurrence ;
  // `home_nav_test.dart` n'énumère que les 5 démos de son propre lot). Une
  // vitrine orpheline étant une vitrine morte, elle est posée ici.

  testWidgets('S5 — l\'entrée d\'accueil ouvre réellement la vitrine',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Stepper & sous-listes'), findsOneWidget);
    await tester.tap(find.text('Stepper & sous-listes'));
    await tester.pumpAndSettle();
    expect(find.byType(StepperSubListDemoScreen), findsOneWidget);
  });
}
