/// SU-7 / AC9 — 🔴 **Correspondance carte ↔ réponse** : la Nᵉ qualité atterrit
/// sur la Nᵉ carte.
///
/// # Pourquoi c'est LE test de cette story
///
/// `ZSessionItem` (la file du moteur) ne porte **que des identifiants** — aucun
/// `ZFlashcard`. La file du moteur n'est donc **pas rendable** : l'hôte tient
/// **deux listes parallèles**. Si elles se désynchronisent, la qualité de la
/// carte **A** est attribuée à la carte **B** : un examen **faux**, par la voie
/// **légitime**, **sans aucune exception**. Rien ne plante, rien ne rougit — sauf
/// une assertion qui regarde **QUI a eu QUOI**.
///
/// # 🔴 Honnêteté de portée : ce que CHAQUE assertion peut, et NE PEUT PAS
///
/// Les deux axes ci-dessous ne sont **pas** redondants — ils attrapent des
/// défauts **différents**, et le premier est **strictement plus faible** que le
/// second. Le dire est le prix à payer pour ne pas répéter le mensonge d'intitulé
/// que `z_no_srs_write_in_non_srs_modes_test.dart:187` a dû corriger :
///
/// 1. **`captured == [0, 5, 0]`** (scorer sentinelle) — prouve que les qualités
///    arrivent au moteur **dans l'ordre des cartes**. ⚠️ **Portée réelle** :
///    `scoreWhiteExam` est un **COMPTAGE**, donc **commutatif** — l'agrégat
///    `{total, correct, byQuality}` est **insensible à l'ordre**. Cet axe ne peut
///    donc **PAS** démasquer une attribution croisée à lui seul ; il démasque un
///    **ré-ordonnancement** (une file rendue dans un ordre, consommée dans un
///    autre). C'est déjà plus que « 3 réponses enregistrées », qui ne prouve
///    **RIEN** (présence ≠ association, leçon su-4) : une longueur reste verte
///    sur un examen **entièrement faux**.
/// 2. **L'axe DÉCISIF — le RENDU par carte** : après soumission, la correction
///    peinte **à côté de la question Q2** dit « correct », et celles de **Q1**/
///    **Q3** disent « incorrect ». C'est **exactement** « la qualité de la carte
///    A écrite sur la carte B », observée là où elle blesse : sous les yeux de
///    l'apprenant. Un décalage d'un cran de `onAnswered(index, …)` rougit **ici**,
///    et **seulement** ici.
///
/// Les cartes sont donc localisées **PAR LEUR CONTENU** (`find.text('Q2')`),
/// jamais par leur position : un test qui indexe par position ne peut pas voir un
/// décalage de position.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_exam_harness.dart';

void main() {
  const config = ZSrsConfig();

  /// Surface large : les 3 cartes doivent être **réellement construites** par le
  /// `ListView.builder`. 🚫 On n'ajuste JAMAIS une assertion pour contourner un
  /// débordement — on donne au test la surface que le scénario exige.
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// La carte dont la question est [question] — **par CONTENU**, jamais par index.
  Finder cardOf(String question) => find.ancestor(
    of: find.text(question),
    matching: find.byType(ZFlashcardAnswerInput),
  );

  /// Répond à la carte [question] : `true` ⇒ juste (`maxQuality`), `false` ⇒
  /// faux (`minQuality`) — les cartes du harnais sont `isTrue: true`.
  Future<void> answer(
    WidgetTester tester,
    String question, {
    required bool correctly,
  }) async {
    await tester.tap(
      find.descendant(
        of: cardOf(question),
        matching: find.byKey(correctly ? EK.answerTrue : EK.answerFalse),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '🔴 AC9 — le scorer reçoit les qualités DANS L\'ORDRE DES CARTES '
    '([0, 5, 0], jamais [5, 0, 0])',
    (tester) async {
      useLargeSurface(tester);
      List<int>? captured;
      final cards = <ZFlashcard>[
        examCard('Q1'),
        examCard('Q2'),
        examCard('Q3'),
      ];

      await tester.pumpWidget(
        ExamHost(
          cards: cards,
          // 🔒 Scorer **SENTINELLE** : il CAPTURE la liste réellement reçue.
          // C'est le seul moyen de voir ce que le moteur a enregistré — un
          // `expect` sur `result.total` ne verrait qu'un **comptage**.
          scorer: (qualities, {required int passThreshold}) {
            captured = List<int>.of(qualities);
            return scoreWhiteExam(qualities, passThreshold: passThreshold);
          },
        ),
      );

      // Une seule carte est répondue JUSTE — et ce n'est **pas** la première :
      // `[0, 5, 0]` et `[5, 0, 0]` ont la même longueur ET le même agrégat.
      await answer(tester, 'Q1', correctly: false);
      await answer(tester, 'Q2', correctly: true);
      await answer(tester, 'Q3', correctly: false);

      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZListSessionView.confirmKey));
      await tester.pumpAndSettle();

      // 🔒 Les qualités attendues sont **DÉRIVÉES de la config** (AD-46) —
      // jamais les littéraux d'une seconde échelle.
      expect(
        captured,
        <int>[config.minQuality, config.maxQuality, config.minQuality],
        reason: '🔴 AC9 : les qualités n\'arrivent pas dans l\'ordre des '
            'cartes. Un décalage d\'un cran, ou deux tris indépendants entre '
            '`items` (moteur) et `cards` (vue), et l\'examen est FAUX sans '
            'qu\'aucune exception ne soit levée.',
      );
    },
  );

  testWidgets(
    '🔴 AC9 (axe DÉCISIF) — la correction de CHAQUE carte est peinte SUR SA '
    'carte (Q2 correct ; Q1/Q3 incorrect)',
    (tester) async {
      useLargeSurface(tester);
      final cards = <ZFlashcard>[
        examCard('Q1'),
        examCard('Q2'),
        examCard('Q3'),
      ];
      await tester.pumpWidget(ExamHost(cards: cards));

      await answer(tester, 'Q1', correctly: false);
      await answer(tester, 'Q2', correctly: true);
      await answer(tester, 'Q3', correctly: false);
      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZListSessionView.confirmKey));
      await tester.pumpAndSettle();

      /// Le verdict peint **dans le bloc de LA question** [question].
      ///
      /// On remonte au `Padding` porteur de la clé de question — la maille qui
      /// contient **une** question ET **sa** révélation — puis on y cherche le
      /// verdict. Chercher `find.text('correct')` globalement ne dirait **PAS**
      /// à quelle carte il appartient : ce serait « présence ≠ association ».
      Finder verdictIn(String question, String verdict) => find.descendant(
        of: find.ancestor(
          of: find.text(question),
          matching: find.byWidgetPredicate(
            (w) => w is Padding && w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  ZListSessionView.questionKeyPrefix,
                ),
          ),
        ),
        matching: find.text(verdict),
      );

      expect(
        verdictIn('Q2', 'correct'),
        findsOneWidget,
        reason: '🔴 AC9 : Q2 est la SEULE réponse juste — son verdict doit être '
            'peint sur SA carte.',
      );
      expect(verdictIn('Q1', 'incorrect'), findsOneWidget);
      expect(verdictIn('Q3', 'incorrect'), findsOneWidget);
      // 🔴 Le complément est ce qui rend l'assertion DÉCISIVE : un décalage d'un
      // cran mettrait « correct » sur Q1 ou Q3 — et les trois `findsOneWidget`
      // ci-dessus, à eux seuls, ne le verraient pas tous.
      expect(verdictIn('Q1', 'correct'), findsNothing);
      expect(verdictIn('Q3', 'correct'), findsNothing);
      expect(verdictIn('Q2', 'incorrect'), findsNothing);
    },
  );

  testWidgets(
    '🔴 AC9 — `onAnswered` émet l\'INDEX DE SA carte (le seam qui rend la '
    'désynchronisation DÉTECTABLE)',
    (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')],
        ),
      );
      // On répond DANS LE DÉSORDRE : l'index émis doit suivre la CARTE, jamais
      // le rang d'arrivée. Une signature sans index rendrait ceci indétectable.
      await answer(tester, 'Q3', correctly: true);
      await answer(tester, 'Q1', correctly: false);

      final state = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(
        state.answeredIndexes,
        <int>[2, 0],
        reason: '🔴 AC9 : l\'index émis doit être celui de la CARTE répondue '
            '(2 puis 0), jamais son rang d\'arrivée (0 puis 1).',
      );
      expect(state.submissions[2]!.quality, config.maxQuality);
      expect(state.submissions[0]!.quality, config.minQuality);
      expect(
        state.submissions.containsKey(1),
        isFalse,
        reason: 'Q2 n\'a pas été répondue : rien ne doit être rangé sous elle.',
      );
    },
  );

  testWidgets(
    '🔴 D10 — une carte répondue est VERROUILLÉE : re-taper ne ré-émet RIEN '
    '(le moteur ne sait pas réviser)',
    (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
      );
      await answer(tester, 'Q1', correctly: true);

      final state = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(state.answeredIndexes, <int>[0]);

      // 🔴 On **TAPE RÉELLEMENT** (présence ≠ association, leçon su-4 : le
      // bouton « précédent » qui avançait était vert parce que jamais tapé).
      await tester.tap(
        find.descendant(of: cardOf('Q1'), matching: find.byKey(EK.answerFalse)),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(
        state.answeredIndexes,
        <int>[0],
        reason: '🔴 D10 : re-taper une carte répondue a ré-émis une réponse. Le '
            'moteur AJOUTE (il ne révise pas) ⇒ `total` serait FAUX. Le verrou '
            'de su-3 doit survivre au report de correction (D2/G4).',
      );
    },
  );
}
