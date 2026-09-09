/// **Composition de face de la carte, décidée par l'ASSEMBLAGE.**
///
/// Deux propriétés que seul l'assemblage peut tenir, parce que lui seul sait
/// ce qu'il monte à côté de la carte :
///
/// 1. **Les choix d'un QCM ne sont rendus qu'une fois.** L'assemblage monte
///    une surface de saisie qui rend les choix, interactifs. La carte les
///    rendait aussi, en radios inertes, sur sa face question : le même QCM
///    s'affichait deux fois, l'un tapable et l'autre non.
/// 2. **Les cartes de rang > 0 sont muettes.** La pile laisse dépasser une
///    bande de la carte suivante ; le texte qui s'y lisait était celui de la
///    question d'après.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZFlashcardReviewCard>(…).questionFaceChoices`
/// resterait vert le jour où la carte cesserait d'en tenir compte : ce serait
/// mesurer la **présence** d'un paramètre, pas son **effet**. Chaque garde
/// ci-dessous compte des nœuds RÉELLEMENT montés — le glyphe de choix de la
/// carte (`radio_button_unchecked`, jamais celui de la saisie, qui est
/// `radio_button_off`), les clés `zAnswerChoice_i` de la saisie, le texte
/// réellement rendu sous la carte arrière — et chacune porte sa contre-preuve
/// de non-vacuité (le sujet est monté, prouvé par l'énoncé).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZChoice,
        ZFlashcard,
        ZFlashcardFaceContent,
        ZFlashcardQuestionFaceChoices,
        ZFlashcardReviewCard,
        ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardAnswerInput, ZFlashcardSubmission, ZSessionItem;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

// ── Cartes ──────────────────────────────────────────────────────────────────

/// Libellés de choix volontairement DISTINCTS de l'énoncé et de la réponse :
/// un décompte de texte ne peut donc pas être satisfait par le mauvais nœud.
const String kAlpha = 'Choix alpha';
const String kBeta = 'Choix beta';

ZFlashcard _mcq(String id) => ZFlashcard(
      id: id,
      folderId: kHarnessFolderId,
      type: ZFlashcardType.multipleChoice,
      question: 'Question $id.',
      answer: kAlpha,
      choices: const <ZChoice>[
        ZChoice(content: kAlpha, isCorrect: true),
        ZChoice(content: kBeta),
      ],
    );

List<ZFlashcard> _mcqCards(int n) =>
    <ZFlashcard>[for (int i = 0; i < n; i++) _mcq('c$i')];

// ── Sondes de RENDU ─────────────────────────────────────────────────────────

/// La carte de session d'identité [id], telle qu'elle est réellement montée.
Finder _card(String id) =>
    find.byKey(ValueKey<String>('zStudySessionCard_$id'));

/// Les glyphes de choix RÉELLEMENT rendus par les cartes.
///
/// `radio_button_unchecked` est le marqueur de la carte, et de rien d'autre :
/// la surface de saisie peint `radio_button_off` / `radio_button_checked`
/// (choix unique) ou `check_box*` (choix multiple). Les deux familles ne se
/// confondent donc jamais.
int _cardChoiceMarkers(WidgetTester tester) => tester
    .widgetList<Icon>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
    )
    .length;

/// Les tuiles de choix RÉELLEMENT montées par la surface de saisie, comptées
/// par leur clé (le préfixe est celui de `ZFlashcardAnswerInput`).
int _inputChoiceTiles(WidgetTester tester) {
  int n = 0;
  for (int i = 0; i < 8; i++) {
    if (find.byKey(ValueKey<String>('zAnswerChoice_$i')).evaluate().isNotEmpty) {
      n += 1;
    }
  }
  return n;
}

/// Le dump ordonné des types de widgets montés — égalité STRICTE.
List<String> _treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Le dump figé sur disque AVANT le lot.
List<String> _baseline(String name) {
  final File file = File('${zsrc.packageRoot().path}/test/support/$name');
  if (!file.existsSync()) {
    throw StateError(
      'Dump de référence introuvable : ${file.path}. La garde d\'inertie ne '
      'mesure plus rien.',
    );
  }
  return file.readAsLinesSync();
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  useTallSurface(tester);
  await tester.pumpWidget(wrapForTest(child));
  await tester.pumpAndSettle();
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // 1. QCM assemblé — les choix ne sont rendus QU'UNE FOIS
  // ═════════════════════════════════════════════════════════════════════════
  group('🃏 QCM assemblé — les choix ne sont rendus qu\'UNE fois', () {
    testWidgets('la saisie les rend, la carte ne les rend plus',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(mode: ZReviewMode.list, queue: _mcqCards(1)),
      );

      // Contre-preuve de non-vacuité : le sujet EST monté — l'énoncé de la
      // carte est à l'écran, et la saisie a bien construit ses deux tuiles.
      expect(
        find.descendant(of: _card('c0'), matching: find.text('Question c0.')),
        findsOneWidget,
        reason: '🔴 la carte ne rend pas son énoncé : elle n\'est pas le sujet '
            'monté, et l\'absence de choix ne prouverait rien',
      );
      expect(_inputChoiceTiles(tester), 2,
          reason: '🔴 la saisie ne rend plus les choix : leur absence sur la '
              'carte ne prouverait alors rien');

      expect(_cardChoiceMarkers(tester), 0,
          reason: '🔴 la carte rend les choix que la saisie rend déjà : le '
              'même QCM est affiché deux fois');
      expect(find.text(kAlpha), findsOneWidget,
          reason: '🔴 le libellé d\'un choix apparaît plus d\'une fois dans '
              'l\'arbre monté');
      expect(find.text(kBeta), findsOneWidget);
    });

    testWidgets('la face RÉPONSE garde ses choix marqués',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: _mcqCards(1),
          revealPolicy: ZStudySessionRevealPolicy.always,
        ),
      );
      expect(_cardChoiceMarkers(tester), 0,
          reason: 'face question : aucun choix sur la carte');

      await tester.tap(find.byKey(ZStudySessionHost.revealActionKey));
      await tester.pumpAndSettle();

      // Face réponse : le choix correct porte `check_circle`, l'autre garde
      // `radio_button_unchecked` — la correction est intacte.
      expect(
        find.descendant(
          of: find.byType(ZFlashcardReviewCard),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
        reason: '🔴 la face réponse a perdu le marquage de la bonne réponse',
      );
      expect(_cardChoiceMarkers(tester), 1,
          reason: '🔴 la face réponse ne rend plus le choix non retenu');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 2. Question ouverte à UNE carte — inertie stricte
  // ═════════════════════════════════════════════════════════════════════════
  group('🧊 inertie — une question ouverte, une seule carte', () {
    const String kDump = 'z_face_tree_before_lott2_open_single.txt';

    test('le dump de référence est non vide et porte bien la carte', () {
      final List<String> dump = _baseline(kDump);
      expect(dump, isNotEmpty);
      expect(dump, contains('ZFlashcardReviewCard'),
          reason: '🔴 un dump sans carte ne prouverait rien');
    });

    testWidgets('égalité stricte avec le dump figé', (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(mode: ZReviewMode.list, queue: writtenCards(1)),
      );
      expect(_treeDump(tester), _baseline(kDump),
          reason: '🔴 la décision de composition a changé l\'arbre d\'une '
              'session qui ne monte ni QCM ni pile');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 3. Pile de deux cartes — la carte arrière est MUETTE
  // ═════════════════════════════════════════════════════════════════════════
  group('🎴 pile de deux cartes — le rang > 0 est muet', () {
    testWidgets('la carte arrière ne rend ni texte ni nœud de question',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(mode: ZReviewMode.list, queue: writtenCards(2)),
      );

      // Contre-preuve : les deux cartes sont montées, et celle de devant, elle,
      // rend bien son énoncé.
      expect(_card('c0'), findsOneWidget);
      expect(_card('c1'), findsOneWidget,
          reason: '🔴 la carte arrière n\'est pas montée : l\'absence de texte '
              'ne prouverait rien');
      expect(
        find.descendant(of: _card('c0'), matching: find.text('Question c0.')),
        findsOneWidget,
        reason: 'la carte de devant rend son énoncé',
      );

      expect(
        find.descendant(of: _card('c1'), matching: find.byType(Text)),
        findsNothing,
        reason: '🔴 la bande de débord laisse lire le texte de la carte '
            'suivante',
      );
      expect(
        find.descendant(of: _card('c1'), matching: find.byType(Semantics)),
        findsNothing,
        reason: '🔴 la carte arrière est encore annoncée comme une question '
            'par un lecteur d\'écran',
      );
    });

    testWidgets('après avance, la nouvelle carte de devant est PLEINE',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(mode: ZReviewMode.list, queue: writtenCards(2)),
      );
      expect(
        find.descendant(of: _card('c1'), matching: find.byType(Text)),
        findsNothing,
        reason: 'état de départ : la carte arrière est muette',
      );

      // Le geste RÉEL d'avance de la pile — jamais une soumission : en mode
      // `list`, répondre ne fait pas passer la carte suivante devant.
      await tester.drag(_card('c0'), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Contre-preuve : la pile a bel et bien avancé.
      expect(
        find.descendant(of: _card('c1'), matching: find.byType(Text)),
        isNot(findsNothing),
        reason: '🔴 la pile n\'a pas avancé : la mesure qui suit ne prouverait '
            'rien',
      );

      expect(
        find.descendant(of: _card('c1'), matching: find.text('Question c1.')),
        findsOneWidget,
        reason: '🔴 la carte passée devant est restée muette : le cache du '
            'swiper a rendu la carte figée sur son rang précédent',
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 4. La saisie du socle n'est pas montée ⇒ la carte GARDE ses choix
  // ═════════════════════════════════════════════════════════════════════════
  group('🧩 saisie de l\'HÔTE — la carte garde ses choix', () {
    testWidgets('`gradingBuilder` posé : la décision automatique se retire',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: _mcqCards(1),
          gradingBuilder: (
            BuildContext context,
            ZSessionItem item,
            ValueChanged<ZFlashcardSubmission> submit,
          ) =>
              const Text('saisie de l\'hôte'),
        ),
      );

      // Contre-preuve : la surface du socle n'est PLUS montée — c'est bien la
      // condition mesurée, et non un hasard de rendu.
      expect(find.byType(ZFlashcardAnswerInput), findsNothing,
          reason: 'la surface du socle a été remplacée');
      expect(_inputChoiceTiles(tester), 0,
          reason: '🔴 des tuiles de choix du socle subsistent : la condition '
              'mesurée ne serait pas celle qu\'on croit');
      expect(find.text('saisie de l\'hôte'), findsOneWidget);

      expect(_cardChoiceMarkers(tester), 2,
          reason: '🔴 la carte a perdu ses choix alors que rien ne les rend '
              'plus : le QCM est devenu illisible');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // 5. Échappatoires — le paramètre posé BAT la décision de l'assemblage
  // ═════════════════════════════════════════════════════════════════════════
  group('🎚️ échappatoires — le paramètre de l\'hôte prime', () {
    testWidgets('`questionFaceChoices: shown` ramène les choix sur la carte',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: _mcqCards(1),
          questionFaceChoices: ZFlashcardQuestionFaceChoices.shown,
        ),
      );
      // La saisie du socle est bien là : la décision automatique aurait donc
      // retiré les choix — c'est le paramètre, et lui seul, qui les ramène.
      expect(_inputChoiceTiles(tester), 2);
      expect(_cardChoiceMarkers(tester), 2,
          reason: '🔴 le paramètre explicite ne bat pas la décision de '
              'l\'assemblage');
    });

    testWidgets('`questionFaceChoices: hidden` vaut même sans saisie du socle',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: _mcqCards(1),
          questionFaceChoices: ZFlashcardQuestionFaceChoices.hidden,
          gradingBuilder: (
            BuildContext context,
            ZSessionItem item,
            ValueChanged<ZFlashcardSubmission> submit,
          ) =>
              const Text('saisie de l\'hôte'),
        ),
      );
      expect(_cardChoiceMarkers(tester), 0,
          reason: '🔴 le paramètre ne bat la décision que dans un sens');
    });

    testWidgets('`backCardsContent: full` restitue la carte arrière',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          backCardsContent: ZFlashcardFaceContent.full,
        ),
      );
      expect(
        find.descendant(of: _card('c1'), matching: find.text('Question c1.')),
        findsOneWidget,
        reason: '🔴 le paramètre explicite ne restitue pas le contenu des '
            'cartes empilées',
      );
    });

    testWidgets('la PAGE relaie les deux réglages jusqu\'au rendu',
        (WidgetTester tester) async {
      await _pump(
        tester,
        ZStudySessionScaffold(
          title: 'lotT2',
          mode: ZReviewMode.list,
          queue: _mcqCards(2),
          questionFaceChoices: ZFlashcardQuestionFaceChoices.shown,
          backCardsContent: ZFlashcardFaceContent.full,
        ),
      );
      // Deux choix sur la carte de devant, deux sur la carte arrière — les
      // deux réglages ont traversé l'enveloppe de page.
      expect(_cardChoiceMarkers(tester), 4,
          reason: '🔴 l\'enveloppe de page perd un des deux réglages EN '
              'SILENCE');
    });
  });
}
