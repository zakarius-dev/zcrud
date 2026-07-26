/// SUF-4 / T8 — test de fumée **MORDANT** du parcours assemblé (AC9/AC10).
///
/// Monte la démo de bout en bout — **grille de dossiers → page-détail → flux de
/// session** — et vérifie l'ENCHAÎNEMENT, pas la simple présence :
///
/// 1. la grille rend une carte de dossier (`ZFolderCard`) ;
/// 2. **un tap** ouvre le détail (`ZStudyFolderDetail`) **du bon dossier** ;
/// 3. le **point d'entrée de session** y est atteignable, et **un tap** ouvre le
///    flux `zcrud_session`, jusqu'au bilan.
///
/// 🔴 **Discipline anti-tautologie** : chaque étape est franchie par une
/// **interaction réelle** (`tester.tap` sur une `ValueKey`, jamais un
/// `find.text` dépendant de la langue) et l'assertion porte sur ce qui n'existe
/// **qu'après** l'étape (le détail n'est pas monté avant le tap ; le bilan
/// n'existe pas avant la dernière notation). Un câblage « toutes les cartes vers
/// le même dossier », un point d'entrée inerte ou un flux qui saute une étape
/// ROUGIT — les injections ont été rejouées, cf. Completion Notes.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf4_assembly_demo.dart';

/// Écran large : la page-détail monte alors sa sidebar, et la grille place
/// plusieurs cartes de front (parcours réaliste).
Future<void> _setScreen(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(900, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDemo(WidgetTester tester, {ZcrudTheme? theme}) async {
  await _setScreen(tester);
  // 🔴 Démontage EXPLICITE avant re-montage — mesuré : re-pomper directement
  // une seconde `Suf4AssemblyDemoApp` RÉUTILISE l'élément `MaterialApp`, donc
  // la PILE DE NAVIGATION de la passe précédente : le test « repartait » du
  // flux de session et ne trouvait plus la grille. Un test qui compare deux
  // montages doit repartir d'un arbre vide, sinon il compare deux états
  // différents pour la mauvaise raison.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(Suf4AssemblyDemoApp(theme: theme));
  await tester.pumpAndSettle();
}

void main() {
  group('AC7/AC9 — le parcours s\'assemble et s\'ENCHAÎNE', () {
    testWidgets('étape 1 — la grille rend une carte par dossier', (tester) async {
      await _pumpDemo(tester);

      expect(find.byType(ZFolderCard), findsNWidgets(kDemoFolders.length));
      // 🔴 MORDANT : le détail ne doit PAS être monté avant le tap — sinon
      // l'assertion de l'étape 2 serait vraie sans que rien ne se passe.
      expect(find.byType(ZStudyFolderDetail), findsNothing);
    });

    testWidgets(
      '🔴 étape 2 — UN TAP ouvre le détail DU BON dossier (pas d\'un dossier '
      'câblé en dur)',
      (tester) async {
        await _pumpDemo(tester);

        // On ouvre le DEUXIÈME dossier : un câblage « toutes les cartes vers
        // l'index 0 » (le défaut classique d'une grille) rougirait ici.
        await tester.tap(find.byKey(demoFolderCardKey(1)));
        await tester.pumpAndSettle();

        expect(find.byType(ZStudyFolderDetail), findsOneWidget);
        expect(find.text(kDemoFolders[1].title), findsWidgets);
        expect(find.text(kDemoFolders[0].title), findsNothing);
      },
    );

    testWidgets(
      '🔴 étape 3 — le point d\'entrée de session est ATTEIGNABLE et ACTIONNÉ '
      '(un contrôle inerte rougirait)',
      (tester) async {
        await _pumpDemo(tester);
        await tester.tap(find.byKey(demoFolderCardKey(0)));
        await tester.pumpAndSettle();

        expect(find.byKey(demoSessionEntryKey), findsOneWidget);
        // Rien du flux session n'existe encore.
        expect(find.byKey(demoSessionScreenKey), findsNothing);
        expect(find.byType(ZSessionModeSelector), findsNothing);

        await tester.tap(find.byKey(demoSessionEntryKey));
        await tester.pumpAndSettle();

        // 🔴 MORDANT : un `onTap: null` (ou un `ListTile` décoratif) laisserait
        // ces deux attentes fausses — « le point d'entrée existe » ne prouve
        // rien, « il ouvre la session » si.
        expect(find.byKey(demoSessionScreenKey), findsOneWidget);
        expect(find.byType(ZSessionModeSelector), findsOneWidget);
      },
    );

    testWidgets(
      '🔴 parcours COMPLET — grille → détail → sélecteur → notation → bilan',
      (tester) async {
        await _pumpDemo(tester);

        // Dossier 1 : 7 cartes (corpus non trivial, et ≠ du dossier 0).
        await tester.tap(find.byKey(demoFolderCardKey(1)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(demoSessionEntryKey));
        await tester.pumpAndSettle();

        // Sélecteur → file produite → notation.
        await tester.tap(find.byKey(ZSessionModeSelector.learnKey));
        await tester.pumpAndSettle();
        expect(find.byType(ZSrsQualityButtons), findsOneWidget);
        expect(
          find.byKey(ZSessionProgressIndicator.linearKey),
          findsOneWidget,
          reason: 'la barre CONTINUE de SUF-4 est bien celle que la démo monte',
        );
        // 🔴 Le bilan n'existe PAS encore : sans cette contre-attente,
        // l'assertion finale serait vraie même si le bilan était monté d'emblée.
        expect(find.byType(ZSessionSummaryView), findsNothing);

        // On note les 7 cartes ; la barre doit AVANCER, pas rester figée.
        final before = tester
            .widget<LinearProgressIndicator>(
              find.byKey(ZSessionProgressIndicator.linearKey),
            )
            .value;
        await tester.tap(
          find.byKey(
            const ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}4'),
          ),
        );
        await tester.pumpAndSettle();
        final after = tester
            .widget<LinearProgressIndicator>(
              find.byKey(ZSessionProgressIndicator.linearKey),
            )
            .value;
        // 🔴 MORDANT : une barre câblée sur une constante (ou sur un index qui
        // n'avance pas) ferait `before == after`.
        expect(after, greaterThan(before!));

        for (var i = 1; i < kDemoFolders[1].cardCount; i++) {
          await tester.tap(
            find.byKey(
              const ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}4'),
            ),
          );
          await tester.pumpAndSettle();
        }

        // Bilan atteint — la boucle a réellement consommé la file.
        expect(find.byType(ZSessionSummaryView), findsOneWidget);
        // La répartition à longueur STABLE (fermeture paire 2) : le cran 1,
        // jamais utilisé, a tout de même sa pilule.
        expect(
          find.byKey(
            const ValueKey<String>(
              '${ZSessionQualityBreakdown.segmentKeyPrefix}1',
            ),
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('AC8 — apparence NEUTRE et thémable (aucun look imposé par la démo)',
      () {
    /// Traverse le parcours jusqu'à la rangée de notation.
    Future<void> reachReviewing(WidgetTester tester, ZcrudTheme? theme) async {
      await _pumpDemo(tester, theme: theme);
      await tester.tap(find.byKey(demoFolderCardKey(0)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(demoSessionEntryKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZSessionModeSelector.learnKey));
      await tester.pumpAndSettle();
    }

    /// Espacement RÉELLEMENT peint par la rangée SRS (`Wrap(spacing:)`), qui
    /// vient du token `ZcrudTheme.gapM` — la démo n'y touche pas.
    double srsSpacing(WidgetTester tester) => tester
        .widget<Wrap>(
          find.descendant(
            of: find.byType(ZSrsQualityButtons),
            matching: find.byType(Wrap),
          ),
        )
        .spacing;

    testWidgets(
      '🔴 le thème du `ZcrudScope` racine TRAVERSE la démo (deux `gapM` ⇒ deux '
      'espacements) — un token codé en dur ferait converger',
      (tester) async {
        await reachReviewing(tester, const ZcrudTheme(gapM: 8));
        final tight = srsSpacing(tester);

        await reachReviewing(tester, const ZcrudTheme(gapM: 24));
        final loose = srsSpacing(tester);

        expect(tight, 8);
        expect(loose, 24);
        // 🔴 MORDANT : une démo qui monterait ses écrans hors du `ZcrudScope`
        // racine (ou qui imposerait son propre thème) rendrait ces deux
        // mesures ÉGALES — le look ne serait plus celui de l'app hôte.
        expect(tight, isNot(equals(loose)));
      },
    );

    testWidgets(
      '🔒 l\'épaisseur de barre reste une décision de l\'APP, pas du thème',
      (tester) async {
        // La démo injecte `linearThickness: 6` (le design de lex). Changer le
        // token de thème ne doit donc RIEN changer ici : c'est la démonstration
        // que la fermeture SUF-4 laisse la main à l'app sans coder `6` dans le
        // widget.
        await reachReviewing(tester, const ZcrudTheme(gapS: 4));
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byKey(ZSessionProgressIndicator.linearKey),
              )
              .minHeight,
          6,
        );

        await reachReviewing(tester, const ZcrudTheme(gapS: 12));
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byKey(ZSessionProgressIndicator.linearKey),
              )
              .minHeight,
          6,
        );
      },
    );

    testWidgets(
      'la démo n\'impose AUCUN thème : elle fonctionne sans `ZcrudTheme` injecté',
      (tester) async {
        // Repli `Theme.of` (AD-10) : aucun token n'est présupposé.
        await _pumpDemo(tester);
        await tester.tap(find.byKey(demoFolderCardKey(0)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(ZStudyFolderDetail), findsOneWidget);
      },
    );
  });
}
