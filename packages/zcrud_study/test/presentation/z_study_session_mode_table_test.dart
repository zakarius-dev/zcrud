/// **Lot 1 « étude »** — la table `ZSessionModeKind → ZReviewMode` et son
/// accord avec la table de runtime `zSessionRuntimeForMode` (AD-34).
///
/// ## Ce que ce fichier prouve — et ce qu'il refuse de prouver
///
/// 🚫 Il ne **relit pas** `zReviewModeForKind` (elle se réciterait à
/// elle-même). Il vérifie que le mode produit est celui qui **monte réellement
/// le bon runtime** : pour chaque mode, on assère le type de runtime
/// **effectivement construit** par `ZStudySessionHost`, à travers son
/// comportement observable — jamais à travers une relecture de la table.
///
/// C'est le pendant exact de `z_session_runtime_mapping_test.dart`
/// (`zcrud_session`) : *confronter la table à la réalité des types*.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZSessionCardSwiper,
        ZSessionModeKind,
        ZSessionRuntimeKind,
        zSessionRuntimeForMode;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

void main() {
  group('table `ZSessionModeKind → ZReviewMode` (montée de la démo)', () {
    test('les TROIS membres sont couverts, aux valeurs de la référence', () {
      // Égalités EXACTES, jamais un `contains` : ce sont les correspondances
      // relevées dans `study_session_demo_screen.dart:36-43`.
      expect(zReviewModeForKind(ZSessionModeKind.learnNew), ZReviewMode.learn);
      expect(zReviewModeForKind(ZSessionModeKind.review), ZReviewMode.spaced);
      expect(zReviewModeForKind(ZSessionModeKind.test), ZReviewMode.whiteExam);
    });

    test(
        '🔴 EXHAUSTIVITÉ — tout membre de `ZSessionModeKind` a une image '
        '(la garde suit l\'enum, elle n\'énumère pas une liste figée)', () {
      // Si un 4ᵉ membre (`cramming`) est ajouté à `ZSessionModeKind`, le
      // `switch` sans `default` de `zReviewModeForKind` casse la COMPILATION.
      // Ce test-ci garde le versant runtime : aucune image manquante.
      for (final ZSessionModeKind kind in ZSessionModeKind.values) {
        expect(() => zReviewModeForKind(kind), returnsNormally,
            reason: '🔴 `$kind` n\'a pas d\'image — un mode du sélecteur qui '
                'ne sait pas quel `ZReviewMode` démarrer est un bouton mort');
      }
    });

    test(
        '🔴 ACCORD avec la table de runtime : chaque image atterrit dans un '
        'régime d\'écriture LÉGITIME (AD-34)', () {
      // `learnNew`/`review` visent l'apprentissage ⇒ régime SRS.
      expect(
        zSessionRuntimeForMode(zReviewModeForKind(ZSessionModeKind.learnNew)),
        ZSessionRuntimeKind.srsEngine,
      );
      expect(
        zSessionRuntimeForMode(zReviewModeForKind(ZSessionModeKind.review)),
        ZSessionRuntimeKind.srsEngine,
      );
      // `test` vise l'évaluation ⇒ examen, JAMAIS le moteur SRS : un « Test »
      // qui écrirait de la répétition espacée fausserait la courbe de
      // l'apprenant à son insu.
      expect(
        zSessionRuntimeForMode(zReviewModeForKind(ZSessionModeKind.test)),
        ZSessionRuntimeKind.whiteExam,
      );
      expect(
        zSessionRuntimeForMode(zReviewModeForKind(ZSessionModeKind.test)),
        isNot(ZSessionRuntimeKind.srsEngine),
      );
    });
  });

  group('🔴 le runtime MONTÉ est celui que la table désigne (AD-34)', () {
    /// Monte le host dans [mode] et rend le nombre d'écritures SRS après un
    /// tour complet — la seule propriété qui distingue les régimes.
    Future<int> srsWritesAfterATurn(
      WidgetTester tester,
      ZReviewMode mode,
    ) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        wrapForTest(
          ZStudySessionHost(
            mode: mode,
            queue: writtenCards(2),
            // Le seam est fourni dans TOUS les modes : s'il est consommé par un
            // mode non-SRS, le compteur le dira. C'est la porte dérobée qu'on
            // cherche, pas celle qu'on suppose absente.
            reviewer: reviewer.call,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey<String>('zAnswerField')),
          matching: find.byType(EditableText),
        ),
        'réponse',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
      await tester.pumpAndSettle();
      return reviewer.writes;
    }

    testWidgets('`learn` (srsEngine) ÉCRIT du SRS — contrôle POSITIF',
        (tester) async {
      expect(await srsWritesAfterATurn(tester, ZReviewMode.learn), 1,
          reason: '🔴 sans cette écriture, les « 0 » ci-dessous seraient '
              'infalsifiables (un seam jamais câblé rendrait 0 partout)');
    });

    testWidgets('`spaced` (srsEngine) ÉCRIT du SRS', (tester) async {
      expect(await srsWritesAfterATurn(tester, ZReviewMode.spaced), 1);
    });

    testWidgets('`list` (linear) n\'écrit AUCUN SRS', (tester) async {
      expect(await srsWritesAfterATurn(tester, ZReviewMode.list), 0,
          reason: 'le runtime linéaire n\'a AUCUN seam SRS (AD-23)');
    });

    testWidgets('`cramming` (linear) n\'écrit AUCUN SRS', (tester) async {
      expect(await srsWritesAfterATurn(tester, ZReviewMode.cramming), 0);
    });

    testWidgets('`whiteExam` (whiteExam) n\'écrit AUCUN SRS', (tester) async {
      expect(await srsWritesAfterATurn(tester, ZReviewMode.whiteExam), 0);
    });

    testWidgets('`test` (whiteExam) n\'écrit AUCUN SRS', (tester) async {
      expect(await srsWritesAfterATurn(tester, ZReviewMode.test), 0);
    });

    testWidgets(
        '🔴 les SIX modes se montent sans exception (aucun mode orphelin)',
        (tester) async {
      for (final ZReviewMode mode in ZReviewMode.values) {
        useTallSurface(tester);
        await tester.pumpWidget(
          wrapForTest(
            ZStudySessionHost(
              mode: mode,
              queue: writtenCards(2),
              reviewer: FakeSessionReviewer().call,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'mode $mode');
        expect(find.byType(ZSessionCardSwiper), findsOneWidget,
            reason: '🔴 le mode $mode doit RÉELLEMENT démarrer une pile — un '
                'mode qui se monte sans rien afficher est un cul-de-sac');
      }
    });
  });

  group('🟢 `cramming` — le point d\'entrée EXISTE (tripwire déclenché le '
      '2026-08-06)', () {
    test('`ZSessionModeKind.cramming` atteint bien `ZReviewMode.cramming`', () {
      // 🔬 **Ce test était un TRIPWIRE, et il a fait son travail.** Il assertait
      // l'ABSENCE (« aucun `ZSessionModeKind` n'atteint `ZReviewMode.cramming` »)
      // et portait sa propre consigne : « si ce test rougit, c'est que
      // `ZSessionModeKind.cramming` a été ajouté : le point d'entrée existe
      // enfin, retire ce test. »
      //
      // C'est arrivé : `zcrud_session` a ajouté le 4ᵉ membre, le `switch` sans
      // `default` de `zReviewModeForKind` a cassé la COMPILATION (le mode
      // d'échec VOULU — pas un héritage muet du régime voisin), la
      // correspondance a été câblée, et ce test a rougi. Il est donc converti
      // en assertion de la NOUVELLE vérité plutôt que supprimé : supprimer
      // laisserait la correspondance sans garde.
      expect(zReviewModeForKind(ZSessionModeKind.cramming),
          ZReviewMode.cramming);
      final Set<ZReviewMode> reachable =
          ZSessionModeKind.values.map(zReviewModeForKind).toSet();
      expect(reachable.contains(ZReviewMode.cramming), isTrue);
      // …et le régime d'écriture reste LÉGITIME : le bachotage ne doit écrire
      // aucun SRS (AD-33/AD-34). C'est la propriété qui compte réellement — un
      // point d'entrée qui atterrirait sur `srsEngine` fausserait la courbe de
      // l'apprenant à son insu.
      expect(
        zSessionRuntimeForMode(zReviewModeForKind(ZSessionModeKind.cramming)),
        ZSessionRuntimeKind.linear,
      );
    });

    test('🔴 `list` reste SANS point d\'entrée — le tripwire survivant', () {
      // Le versant NON déclenché du constat d'origine : `list` (parcours de
      // révision libre) est exécutable mais aucune option du sélecteur n'y mène.
      final Set<ZReviewMode> reachable =
          ZSessionModeKind.values.map(zReviewModeForKind).toSet();
      expect(reachable.contains(ZReviewMode.list), isFalse,
          reason: '🟢 si CE test rougit, c\'est qu\'un point d\'entrée `list` a '
              'été ajouté : convertis-le en assertion de la nouvelle vérité, '
              'comme cela vient d\'être fait pour `cramming`.');
    });
  });
}
