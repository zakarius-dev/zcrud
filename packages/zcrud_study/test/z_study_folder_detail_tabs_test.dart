/// SUF-3 AC1–AC4 — en-tête composé (`ZPageScaffold`), 3 onglets, actions &
/// recherche déléguées à SUF-1. Chaque garde est prouvée mordante (cf. Dev
/// Agent Record pour les injections de régression rejouées).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/suf3_harness.dart';

void main() {
  group('AC1 — en-tête via ZPageScaffold, accent dérivé du colorKey', () {
    testWidgets('ZPageScaffold présent, titre visible', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester, title: 'Mon dossier');
      expect(find.byType(ZPageScaffold), findsOneWidget);
      expect(find.text('Mon dossier'), findsOneWidget);
    });

    testWidgets('deux colorKey distincts ⇒ deux couleurs d\'accent distinctes',
        (tester) async {
      await setScreen(tester, 500, 800);

      await pumpDetail(tester, colorKey: 'primary');
      final c1 = (tester
              .widget<Container>(find.byKey(ZStudyFolderDetail.accentKey))
              .decoration! as BoxDecoration)
          .color;

      await pumpDetail(tester, colorKey: 'secondary');
      final c2 = (tester
              .widget<Container>(find.byKey(ZStudyFolderDetail.accentKey))
              .decoration! as BoxDecoration)
          .color;

      expect(c1, isNotNull);
      expect(c2, isNotNull);
      // GARDE MORDANTE : coder l'accent en `Colors.blue` ferait converger c1==c2.
      expect(c1, isNot(equals(c2)));
    });
  });

  group('AC2 — 3 onglets, le contenu suit l\'onglet actif', () {
    testWidgets('Matériel à l\'index 0 ; tap Progression ⇒ anneau visible',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        progressData:
            const ZProgressRingsData(total: 10, correct: 7, ratio: .7),
      );

      // Onglet Matériel actif par défaut.
      expect(find.byType(ZSectionedStudyLayout), findsOneWidget);
      expect(find.byType(ZStudyProgressRings), findsNothing);

      await tester.tap(find.text(kProgTab));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : câbler les 3 contentBuilder sur l'onglet 0 ⇒ l'anneau
      // n'apparaîtrait jamais ici (rouge).
      expect(find.byType(ZStudyProgressRings), findsOneWidget);
    });

    testWidgets('tap Notebook ⇒ corps notebook injecté visible', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      await tester.tap(find.text(kNoteTab));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('notebook-marker')),
          findsOneWidget);
    });
  });

  group('AC3 — slots d\'action (tri/ajout/menu) : absents si null, bon callback',
      () {
    // Glyphe RÉELLEMENT injecté par le cas positif ci-dessous : la garde
    // d'absence porte donc sur une icône que `lib/` PEUT produire (une icône
    // jamais injectée nulle part rendrait l'assertion vraie par construction).
    const IconData addIcon = Icons.add_circle;

    testWidgets('add fourni ⇒ icône rendue + tap invoque SON callback',
        (tester) async {
      await setScreen(tester, 500, 800);
      var sortHits = 0;
      var addHits = 0;
      var menuHits = 0;
      await pumpDetail(
        tester,
        sortAction: ZAppBarAction(
          icon: Icons.sort,
          semanticLabel: 'sort',
          onPressed: () => sortHits++,
        ),
        addAction: ZAppBarAction(
          icon: addIcon,
          semanticLabel: 'add',
          onPressed: () => addHits++,
        ),
        menuActions: <ZAppBarAction>[
          ZAppBarAction(
            icon: Icons.info_outline,
            semanticLabel: 'menu',
            onPressed: () => menuHits++,
          ),
        ],
      );

      // GARDE MORDANTE : supprimer `if (widget.addAction != null) …`
      // (z_study_folder_detail.dart:206) perd le slot d'ajout ⇒ icône absente.
      expect(find.byIcon(addIcon), findsOneWidget);

      await tester.tap(find.byIcon(addIcon));
      await tester.pump();
      // GARDE MORDANTE : câbler l'ajout sur le callback du tri (ou l'insérer au
      // mauvais rang) ferait monter sortHits/menuHits au lieu d'addHits.
      expect(addHits, 1);
      expect(sortHits, 0);
      expect(menuHits, 0);
    });

    testWidgets('sort présent + add ABSENT ; tap tri invoque SON callback',
        (tester) async {
      await setScreen(tester, 500, 800);
      var sortHits = 0;
      var menuHits = 0;
      await pumpDetail(
        tester,
        sortAction: ZAppBarAction(
          icon: Icons.sort,
          semanticLabel: 'sort',
          onPressed: () => sortHits++,
        ),
        // addAction non fourni ⇒ structurellement absent.
        menuActions: <ZAppBarAction>[
          ZAppBarAction(
            icon: Icons.info_outline,
            semanticLabel: 'menu',
            onPressed: () => menuHits++,
          ),
        ],
      );

      expect(find.byIcon(Icons.sort), findsOneWidget);
      // ABSENCE STRUCTURELLE : le MÊME glyphe est rendu par le test précédent
      // quand `addAction` est fourni — il ne peut donc pas manquer « par
      // construction ». Rendre un bouton d'ajout inconditionnel le ferait
      // apparaître ici alors qu'`addAction == null`.
      expect(find.byIcon(addIcon), findsNothing);

      await tester.tap(find.byIcon(Icons.sort));
      await tester.pump();
      // GARDE MORDANTE : câbler toutes les actions sur la 1re ⇒ menuHits monterait.
      expect(sortHits, 1);
      expect(menuHits, 0);

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pump();
      expect(menuHits, 1);
      expect(sortHits, 1);
    });
  });

  group('AC4 — recherche déléguée à SUF-1, absente si non configurée', () {
    testWidgets('search null ⇒ pas de loupe', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      expect(find.byIcon(Icons.search), findsNothing);
    });

    testWidgets('search fourni ⇒ loupe présente', (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
      );
      // GARDE MORDANTE : rendre la loupe indépendamment de `search` ferait
      // apparaître l'icône même quand search==null (cf. test précédent).
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
