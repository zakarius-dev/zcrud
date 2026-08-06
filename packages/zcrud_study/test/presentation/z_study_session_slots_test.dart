/// **Lot 1 « étude »** — AD-4 : un slot nul est **ABSENT DE L'ARBRE**.
///
/// ## Pourquoi « absent » et pas « rend du vide »
///
/// Un `SizedBox.shrink()` inerte à la place d'un slot nul occupe une place dans
/// le `Column`, participe au calcul de flex, et rend l'assertion « le slot est
/// absent » **indistinguable** de « le slot rend du vide ». Chaque test
/// ci-dessous vérifie donc les DEUX faces :
///
/// * le widget du slot est introuvable (`findsNothing`) ;
/// * **et** le nombre de nœuds de la colonne n'a pas été gonflé par un
///   placeholder (comparaison de l'arbre avec / sans le slot).
///
/// ## La distinction que ce fichier documente
///
/// | Slot | `null` ⇒ | Pourquoi |
/// |---|---|---|
/// | `headerBuilder`, `counterBuilder`, `gradingBuilder`, `summaryBuilder`, `celebrationBuilder` | **absent** | slots ADDITIFS |
/// | `emptyBuilder` | **repli du socle**, observable | AD-10 : une session sans carte doit offrir une ISSUE, pas un écran muet |
/// | `cardBuilder` | *(requis)* | sans carte, il n'y a pas de pile |
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart' show ZSessionItem;
import 'package:zcrud_study/zcrud_study.dart';

import '../support/z_study_session_harness.dart';

void main() {
  // Tranches figées : ce fichier teste la VUE seule (aucun runtime), donc la
  // composition des slots — pas le comportement de session.
  ZStudySessionSlices slicesFor(
    ZStudySessionPhase phase, {
    List<ZSessionItem> queue = const <ZSessionItem>[
      ZSessionItem(flashcardId: 'c0', folderId: kHarnessFolderId),
    ],
  }) =>
      ZStudySessionSlices(
        phase: ValueNotifier<ZStudySessionPhase>(phase),
        queue: ValueNotifier<List<ZSessionItem>>(queue),
        current: ValueNotifier<ZSessionItem?>(
          queue.isEmpty ? null : queue.first,
        ),
        progress: ValueNotifier<ZStudySessionProgress>(
          ZStudySessionProgress(total: queue.length),
        ),
      );

  Widget view(
    ZStudySessionPhase phase, {
    ZStudySessionHeaderBuilder? header,
    ZStudySessionCounterBuilder? counter,
    ZStudySessionGradingBuilder? grading,
    ZStudySessionSummaryBuilder? summary,
    ZStudySessionCelebrationBuilder? celebration,
    WidgetBuilder? empty,
    VoidCallback? onExit,
  }) =>
      wrapForTest(
        ZStudySessionView(
          slices: slicesFor(phase),
          passThreshold: 3,
          cardBuilder: (BuildContext context, ZSessionItem item) =>
              Text('carte ${item.flashcardId}'),
          headerBuilder: header,
          counterBuilder: counter,
          gradingBuilder: grading,
          summaryBuilder: summary,
          celebrationBuilder: celebration,
          emptyBuilder: empty,
          onExit: onExit,
        ),
      );

  /// Compte les nœuds de la colonne de phase « étude » — la mesure qui
  /// distingue « absent » de « rend du vide ».
  int columnChildren(WidgetTester tester) =>
      tester.widget<Column>(find.byType(Column).first).children.length;

  group('🔴 AD-4 — slots ADDITIFS : `null` ⇒ absent de l\'arbre', () {
    testWidgets('headerBuilder / counterBuilder', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(view(ZStudySessionPhase.studying));
      await tester.pumpAndSettle();
      final int withoutSlots = columnChildren(tester);
      expect(find.text('EN-TÊTE'), findsNothing);
      expect(find.text('COMPTEUR'), findsNothing);

      await tester.pumpWidget(
        view(
          ZStudySessionPhase.studying,
          header: (BuildContext c, ZStudySessionProgress p) =>
              const Text('EN-TÊTE'),
          counter: (BuildContext c, ZStudySessionProgress p) =>
              const Text('COMPTEUR'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('EN-TÊTE'), findsOneWidget);
      expect(find.text('COMPTEUR'), findsOneWidget);

      // 🔴 La colonne a gagné EXACTEMENT deux nœuds : les slots nuls n'y
      // occupaient donc AUCUNE place (pas de placeholder inerte).
      expect(columnChildren(tester), withoutSlots + 2,
          reason: '🔴 un slot nul rendu par un `SizedBox.shrink()` laisserait '
              'ce compte inchangé — l\'absence serait indistinguable du vide');
    });

    testWidgets(
        '🔴 gradingBuilder nul ⇒ la zone de saisie ET son séparateur '
        'disparaissent (jamais un trait orphelin)', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(view(ZStudySessionPhase.studying));
      await tester.pumpAndSettle();
      final int withoutGrading = columnChildren(tester);
      expect(find.byType(Divider), findsNothing,
          reason: '🔴 un séparateur sans zone à séparer est un trait orphelin');
      expect(find.text('SAISIE'), findsNothing);

      await tester.pumpWidget(
        view(
          ZStudySessionPhase.studying,
          grading: (BuildContext c, ZSessionItem i) => const Text('SAISIE'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('SAISIE'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      // Séparateur + Expanded = 2 nœuds ajoutés, jamais moins.
      expect(columnChildren(tester), withoutGrading + 2);
    });

    testWidgets('celebrationBuilder nul ⇒ absent (et aucune `Stack` créée)',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        view(
          ZStudySessionPhase.celebrating,
          summary: (BuildContext c) => const Text('RÉSUMÉ'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RÉSUMÉ'), findsOneWidget);
      expect(find.text('CÉLÉBRATION'), findsNothing);
      // 🔴 Une seule couche ⇒ AUCUNE `Stack` de composition n'est créée : le
      // slot nul ne coûte pas même un nœud d'empilement.
      expect(
        find.ancestor(
          of: find.text('RÉSUMÉ'),
          matching: find.byType(Stack),
        ),
        findsNothing,
        reason: '🔴 sans célébration, la vue ne doit pas empiler pour rien',
      );

      await tester.pumpWidget(
        view(
          ZStudySessionPhase.celebrating,
          summary: (BuildContext c) => const Text('RÉSUMÉ'),
          celebration: (BuildContext c) => const Text('CÉLÉBRATION'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CÉLÉBRATION'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('RÉSUMÉ'),
          matching: find.byType(Stack),
        ),
        findsWidgets,
        reason: 'deux couches ⇒ empilement RÉEL (la sonde n\'est pas morte)',
      );
    });

    testWidgets('summaryBuilder nul ⇒ absent — mais AD-10 garde une ISSUE',
        (tester) async {
      useTallSurface(tester);
      var exited = 0;
      await tester.pumpWidget(
        view(ZStudySessionPhase.celebrating, onExit: () => exited++),
      );
      await tester.pumpAndSettle();
      expect(find.text('RÉSUMÉ'), findsNothing);
      // 🔴 Le contrat n'est PAS « rien » : c'est « pas de résumé, mais jamais
      // un écran dont on ne sort pas ».
      final Finder exit = find.byKey(ZStudySessionView.exitButtonKey);
      expect(exit, findsOneWidget,
          reason: '🔴 AD-10 : une phase de fin sans résumé DOIT garder une '
              'issue de sortie — sinon l\'apprenant est piégé');
      await tester.tap(exit);
      expect(exited, 1, reason: 'l\'issue est RÉELLEMENT câblée');
    });
  });

  group('🔒 emptyBuilder — repli REMPLAÇABLE, jamais un vide', () {
    testWidgets('nul ⇒ repli du socle observable (message + issue)',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        view(ZStudySessionPhase.empty, onExit: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZStudySessionView.emptyKey), findsOneWidget);
      expect(find.byKey(ZStudySessionView.exitButtonKey), findsOneWidget);
    });

    testWidgets('fourni ⇒ REMPLACE le repli du socle (jamais les deux)',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        view(
          ZStudySessionPhase.empty,
          empty: (BuildContext c) => const Text('MON VIDE'),
          onExit: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MON VIDE'), findsOneWidget);
      expect(find.byKey(ZStudySessionView.emptyKey), findsNothing,
          reason: '🔴 le repli du socle et celui de l\'hôte ne coexistent pas');
      expect(find.byKey(ZStudySessionView.exitButtonKey), findsNothing);
    });

    testWidgets(
        '🔴 AD-45 — sans `onExit`, le bouton est ABSENT (jamais grisé, jamais '
        'un bouton mort)', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(view(ZStudySessionPhase.empty));
      await tester.pumpAndSettle();
      expect(find.byKey(ZStudySessionView.emptyKey), findsOneWidget,
          reason: 'le message reste rendu');
      expect(find.byKey(ZStudySessionView.exitButtonKey), findsNothing,
          reason: '🔴 la vue ne FABRIQUE pas une action qu\'elle ne sait pas '
              'exécuter — l\'hôte porte alors son issue lui-même');
    });
  });

  group('🔴 phase `unavailable` (AD-34/AD-10)', () {
    testWidgets(
        'un mode SRS sans reviewer rend un repli DISTINCT du repli « vide »',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        view(ZStudySessionPhase.unavailable, onExit: () {}),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZStudySessionView.unavailableKey), findsOneWidget);
      expect(find.byKey(ZStudySessionView.emptyKey), findsNothing,
          reason: '🔴 « pas de carte » et « mode non servable » sont deux '
              'diagnostics différents : les confondre mentirait à l\'apprenant');
      expect(find.byKey(ZStudySessionView.exitButtonKey), findsOneWidget);
    });
  });
}
