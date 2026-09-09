/// Composition de face de la carte de révision : choix du QCM sur la face
/// question, et carte muette réduite à son chrome.
///
/// Ce que ces gardes mesurent : l'arbre **réellement monté** (suite ordonnée
/// `(type, clé)` comparée à un dump figé), les widgets de choix **réellement
/// trouvés**, la décoration **réellement montée** et l'arbre de **sémantique**
/// réellement produit — jamais le seul passage d'un paramètre.
///
/// Chaque `findsNothing` de ce fichier est apparié à une preuve que le sujet
/// est bel et bien **monté** (l'énoncé présent, ou le liseré présent) : sans
/// cet appariement, l'absence serait verte pour la mauvaise raison.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

// ── Sujets ────────────────────────────────────────────────────────────────

const String _question = 'Capitale ?';
const String _rightChoice = 'Lomé';
const String _wrongChoice = 'Paris';
const String _explanation = 'Togo.';
const String _openQuestion = 'Énoncé ?';
const String _openAnswer = 'Réponse.';

const ZFlashcard _mcq = ZFlashcard(
  question: _question,
  type: ZFlashcardType.multipleChoice,
  choices: <ZChoice>[
    ZChoice(content: _rightChoice, isCorrect: true),
    ZChoice(content: _wrongChoice),
  ],
  explanation: _explanation,
);

const ZFlashcard _open = ZFlashcard(
  question: _openQuestion,
  answer: _openAnswer,
  type: ZFlashcardType.openQuestion,
);

const ZGradientSpec _spec = ZGradientSpec(
  gradient: LinearGradient(
    colors: <Color>[Color(0xFF112233), Color(0xFF445566)],
  ),
  onGradient: Color(0xFFFFFFFF),
);

// ── Hôte ──────────────────────────────────────────────────────────────────

/// Hôte minimal — aucun jeton posé sauf ceux que le cas exige.
Widget _host(
  ZFlashcard card, {
  ZFlashcardQuestionFaceChoices questionFaceChoices =
      ZFlashcardQuestionFaceChoices.shown,
  ZFlashcardFaceContent faceContent = ZFlashcardFaceContent.full,
  double? accentBarHeight,
  Color? shadowColor,
  Widget? instructionBanner,
  ZFlashcardQuestionTypeBadgeBuilder? questionTypeBadgeBuilder,
  VoidCallback? onEdit,
  ValueChanged<bool>? onRevealChanged,
}) => MaterialApp(
  home: ZcrudScope(
    theme: ZcrudTheme(accentBarHeight: accentBarHeight),
    gradientResolver: accentBarHeight == null
        ? null
        : (ColorScheme _, String key) => _spec,
    child: Scaffold(
      body: SizedBox(
        width: 300,
        child: ZFlashcardReviewCard(
          card: card,
          questionFaceChoices: questionFaceChoices,
          faceContent: faceContent,
          shadowColor: shadowColor,
          instructionBanner: instructionBanner,
          questionTypeBadgeBuilder: questionTypeBadgeBuilder,
          onEdit: onEdit,
          onRevealChanged: onRevealChanged,
        ),
      ),
    ),
  ),
);

// ── Mesures ───────────────────────────────────────────────────────────────

/// Signature d'arbre : suite ORDONNÉE de `(type, clé)`, hachages d'instance
/// neutralisés. Même patron que `z_review_card_gradient_chain_test.dart`.
List<String> _treeSignature(WidgetTester tester) => tester.allWidgets
    .map(
      (w) =>
          '${w.runtimeType}|${w.key}'.replaceAll(RegExp(r'#[0-9a-f]{5}'), '#…'),
    )
    .toList();

List<String> _frozen(String name) {
  final List<String> lines = File('test/support/$name')
      .readAsLinesSync()
      .where((String l) => l.isNotEmpty)
      .toList();
  expect(lines, isNotEmpty, reason: 'dump figé absent : $name');
  return lines;
}

/// Les lignes de choix réellement montées.
///
/// `MergeSemantics` est le nœud que `_choiceRow` construit, et **lui seul**
/// dans cette carte : le dump figé d'une question ouverte n'en compte aucun,
/// celui d'un QCM en compte exactement deux.
Finder get _choiceRows => find.descendant(
  of: find.byType(ZFlashcardReviewCard),
  matching: find.byType(MergeSemantics),
);

/// Les marqueurs de choix (le canal non coloré) réellement montés.
Finder get _choiceMarkers => find.descendant(
  of: find.byType(ZFlashcardReviewCard),
  matching: find.byWidgetPredicate(
    (Widget w) =>
        w is Icon &&
        (w.icon == Icons.radio_button_unchecked ||
            w.icon == Icons.check_circle),
  ),
);

/// Tout nœud de texte monté sous la carte.
Finder get _cardTexts => find.descendant(
  of: find.byType(ZFlashcardReviewCard),
  matching: find.byType(Text),
);

Finder get _cardRichTexts => find.descendant(
  of: find.byType(ZFlashcardReviewCard),
  matching: find.byType(RichText),
);

/// Toute surface qui capte un tap sous la carte.
Finder get _cardInkWells => find.descendant(
  of: find.byType(ZFlashcardReviewCard),
  matching: find.byType(InkWell),
);

/// La couleur RÉELLEMENT montée sur la surface `Material` de la carte.
int _mountedSurface(WidgetTester tester) => tester
    .widgetList<Material>(
      find.descendant(
        of: find.byType(ZFlashcardReviewCard),
        matching: find.byType(Material),
      ),
    )
    .first
    .color!
    .toARGB32();

/// La décoration RÉELLEMENT montée sous la clé du liseré.
BoxDecoration _mountedAccentDecoration(WidgetTester tester) =>
    tester.renderObject<RenderDecoratedBox>(
          find.descendant(
            of: find.byKey(ZFlashcardReviewCard.gradientAccentKey),
            matching: find.byType(DecoratedBox),
            matchRoot: true,
          ),
        ).decoration
        as BoxDecoration;

Future<void> _reveal(WidgetTester tester) async {
  await tester.tap(find.byType(ZFlashcardReviewCard));
  await tester.pumpAndSettle();
}

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  group('🧊 inertie absolue — rien de posé, arbre identique au dump figé', () {
    testWidgets('QCM, face question', (tester) async {
      await tester.pumpWidget(_host(_mcq));
      expect(
        _treeSignature(tester),
        _frozen('z_review_card_tree_before_lott1_mcq_q.txt'),
        reason: 'égalité STRICTE de la suite (widget, clé)',
      );
      expect(find.text(_question), findsOneWidget);
      expect(_choiceRows, findsNWidgets(2));
    });

    testWidgets('QCM, face réponse', (tester) async {
      await tester.pumpWidget(_host(_mcq));
      await _reveal(tester);
      expect(
        _treeSignature(tester),
        _frozen('z_review_card_tree_before_lott1_mcq_a.txt'),
      );
      expect(find.text(_explanation), findsOneWidget);
    });

    testWidgets('question ouverte, face question', (tester) async {
      await tester.pumpWidget(_host(_open));
      expect(
        _treeSignature(tester),
        _frozen('z_review_card_tree_before_lott1_open_q.txt'),
      );
      expect(find.text(_openQuestion), findsOneWidget);
    });

    testWidgets('question ouverte, face réponse', (tester) async {
      await tester.pumpWidget(_host(_open));
      await _reveal(tester);
      expect(
        _treeSignature(tester),
        _frozen('z_review_card_tree_before_lott1_open_a.txt'),
      );
      expect(find.text(_openAnswer), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('choix de la face question — `hidden` sur un QCM', () {
    testWidgets(
      'la face question se réduit à l\'énoncé : AUCUN widget de choix, et '
      'l\'énoncé prouve que le sujet est monté',
      (tester) async {
        await tester.pumpWidget(
          _host(_mcq, questionFaceChoices: ZFlashcardQuestionFaceChoices.hidden),
        );

        // Sujet MONTÉ — sans quoi les `findsNothing` ci-dessous seraient
        // verts pour la mauvaise raison.
        expect(find.text(_question), findsOneWidget);

        expect(_choiceRows, findsNothing, reason: 'aucune ligne de choix');
        expect(_choiceMarkers, findsNothing, reason: 'aucun marqueur de choix');
        expect(find.text(_rightChoice), findsNothing);
        expect(find.text(_wrongChoice), findsNothing);
      },
    );

    testWidgets(
      'aucun espacement fantôme : l\'arbre de la face question vaut EXACTEMENT '
      'celui d\'une question ouverte à un seul contenu',
      (tester) async {
        await tester.pumpWidget(
          _host(_mcq, questionFaceChoices: ZFlashcardQuestionFaceChoices.hidden),
        );
        final List<String> hidden = _treeSignature(tester);

        await tester.pumpWidget(_host(_open));
        final List<String> single = _treeSignature(tester);

        expect(
          hidden,
          single,
          reason:
              'un `SizedBox` de gouttière subsistant après le retrait des '
              'choix se verrait ici',
        );
      },
    );

    testWidgets(
      'la face RÉPONSE est strictement inchangée : arbre identique au dump '
      'figé, choix marqués présents',
      (tester) async {
        await tester.pumpWidget(
          _host(_mcq, questionFaceChoices: ZFlashcardQuestionFaceChoices.hidden),
        );
        await _reveal(tester);

        expect(
          _treeSignature(tester),
          _frozen('z_review_card_tree_before_lott1_mcq_a.txt'),
          reason: '`hidden` ne touche JAMAIS la face réponse',
        );
        expect(_choiceRows, findsNWidgets(2));
        expect(find.text(_rightChoice), findsOneWidget);
        expect(find.text(_wrongChoice), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (Widget w) => w is Icon && w.icon == Icons.check_circle,
          ),
          findsOneWidget,
          reason: 'le marquage de la bonne réponse est la correction',
        );
      },
    );

    testWidgets('`shown` rend exactement ce que rendait la carte hier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_mcq, questionFaceChoices: ZFlashcardQuestionFaceChoices.shown),
      );
      expect(
        _treeSignature(tester),
        _frozen('z_review_card_tree_before_lott1_mcq_q.txt'),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('choix de la face question — inerte hors QCM', () {
    testWidgets(
      'question ouverte : `hidden` rend EXACTEMENT le même arbre que `shown`, '
      'sur les deux faces',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _open,
            questionFaceChoices: ZFlashcardQuestionFaceChoices.hidden,
          ),
        );
        expect(
          _treeSignature(tester),
          _frozen('z_review_card_tree_before_lott1_open_q.txt'),
        );
        expect(find.text(_openQuestion), findsOneWidget);

        await _reveal(tester);
        expect(
          _treeSignature(tester),
          _frozen('z_review_card_tree_before_lott1_open_a.txt'),
        );
        expect(find.text(_openAnswer), findsOneWidget);
      },
    );

    testWidgets('vrai/faux : `hidden` laisse l\'énoncé et rien d\'autre', (
      tester,
    ) async {
      const ZFlashcard trueFalse = ZFlashcard(
        question: _openQuestion,
        type: ZFlashcardType.trueOrFalse,
        isTrue: true,
      );
      await tester.pumpWidget(
        _host(trueFalse, questionFaceChoices: ZFlashcardQuestionFaceChoices.shown),
      );
      final List<String> shown = _treeSignature(tester);

      await tester.pumpWidget(
        _host(
          trueFalse,
          questionFaceChoices: ZFlashcardQuestionFaceChoices.hidden,
        ),
      );
      expect(_treeSignature(tester), shown);
      expect(find.text(_openQuestion), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('carte muette — le chrome sans le contenu', () {
    testWidgets(
      'le chrome est MONTÉ : fond peint, liseré présent et son dégradé aussi, '
      'ombre portée présente',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _mcq,
            faceContent: ZFlashcardFaceContent.blank,
            accentBarHeight: 6,
            shadowColor: const Color(0xFF000000),
          ),
        );

        final BuildContext context = tester.element(
          find.byType(ZFlashcardReviewCard),
        );
        expect(
          _mountedSurface(tester),
          Theme.of(context).colorScheme.surface.toARGB32(),
          reason: 'le fond de la carte est peint comme en mode `full`',
        );

        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
          reason: 'le liseré est du chrome, pas du contenu',
        );
        expect(
          (_mountedAccentDecoration(tester).gradient! as LinearGradient).colors
              .map((Color c) => c.toARGB32())
              .toList(),
          <int>[0xFF112233, 0xFF445566],
        );

        expect(
          find.byKey(ZFlashcardReviewCard.shadowKey),
          findsOneWidget,
          reason: 'l\'ombre portée est du chrome',
        );
      },
    );

    testWidgets(
      'AUCUN contenu textuel : ni énoncé, ni choix, ni badge, ni consigne, ni '
      'actions — le liseré prouve que la carte est montée',
      (tester) async {
        await tester.pumpWidget(
          _host(
            _mcq,
            faceContent: ZFlashcardFaceContent.blank,
            accentBarHeight: 6,
            instructionBanner: const Text('Consigne'),
            questionTypeBadgeBuilder: (BuildContext _, ZFlashcardType type) =>
                const Text('QCM'),
            onEdit: () {},
          ),
        );

        // Sujet MONTÉ.
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
        );

        expect(_cardTexts, findsNothing, reason: 'aucun `Text` sous la carte');
        expect(_cardRichTexts, findsNothing, reason: 'rien de peint en texte');
        expect(find.text(_question), findsNothing);
        expect(_choiceRows, findsNothing);
        expect(_choiceMarkers, findsNothing);
        expect(
          find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey),
          findsNothing,
        );
        expect(
          find.byKey(ZFlashcardReviewCard.instructionBannerKey),
          findsNothing,
        );
        expect(find.byKey(ZFlashcardReviewCard.actionsKey), findsNothing);
      },
    );

    testWidgets(
      'la carte muette n\'intercepte AUCUN geste et ne bascule pas : aucune '
      'surface tapable, et le tap au centre ne notifie rien',
      (tester) async {
        final List<bool> reveals = <bool>[];
        await tester.pumpWidget(
          _host(
            _mcq,
            faceContent: ZFlashcardFaceContent.blank,
            accentBarHeight: 6,
            onRevealChanged: reveals.add,
          ),
        );

        // Sujet MONTÉ.
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
        );

        expect(_cardInkWells, findsNothing, reason: 'aucune surface tapable');

        await tester.tap(find.byType(ZFlashcardReviewCard), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(reveals, isEmpty, reason: 'une carte muette ne bascule pas');
        expect(_cardTexts, findsNothing, reason: 'et rien n\'apparaît');
      },
    );

    testWidgets(
      'la carte muette n\'est PAS annoncée comme une question — alors que la '
      'même carte en mode `full` l\'est',
      (tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();

        // Appariement : le libellé EXISTE en mode `full`.
        await tester.pumpWidget(_host(_mcq, accentBarHeight: 6));
        expect(
          find.bySemanticsLabel('Afficher la réponse'),
          findsOneWidget,
          reason: 'le nœud de révélation existe bel et bien en mode `full`',
        );

        await tester.pumpWidget(
          _host(
            _mcq,
            faceContent: ZFlashcardFaceContent.blank,
            accentBarHeight: 6,
          ),
        );
        expect(
          find.byKey(ZFlashcardReviewCard.gradientAccentKey),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Afficher la réponse'),
          findsNothing,
          reason: 'une carte muette n\'est ni un contrôle ni une question',
        );
        expect(find.bySemanticsLabel('Question'), findsNothing);
        expect(find.bySemanticsLabel(_question), findsNothing);

        handle.dispose();
      },
    );

    testWidgets('`full` rend exactement ce que rendait la carte hier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_mcq, faceContent: ZFlashcardFaceContent.full),
      );
      expect(
        _treeSignature(tester),
        _frozen('z_review_card_tree_before_lott1_mcq_q.txt'),
      );
    });
  });
}
