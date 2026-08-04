/// **CR-IFFD-59** — ACHEVER la réplication de la carte de flashcard :
/// structure d'en-tête, enveloppe ombrée, énoncé RICHE borné, aperçu de
/// réponse en MODE, tampon Vrai/Faux.
///
/// Ce que ces gardes MESURENT (jamais une intention déclarée) :
/// - la ligne d'en-tête par GÉOMÉTRIE (tuile et balises au même niveau,
///   énoncé EN DESSOUS pleine largeur) ;
/// - « l'énoncé est riche » par un rendu markdown RÉEL (le segment `gras`
///   porte `FontWeight.bold` et la source `**` n'apparaît nulle part) — une
///   garde de présence de widget resterait verte sur un rendu inerte ;
/// - la NEUTRALITÉ plain-text : un énoncé nu rend à la hauteur du `Text`
///   13/w600 de référence (l'échelle 16→13 est réellement appliquée), sans
///   liseré de champ PEINT ;
/// - « l'ombre existe » par la `BoxShadow` réellement construite avec les
///   alphas de référence, dans les DEUX luminosités ;
/// - « l'aperçu en mode » par PRÉSENCE ET ABSENCE selon la surface (rail
///   sans, grille avec, liste-carte avec — chacune mesurée) ;
/// - le tampon par texte RENDU (libellé INJECTÉ, repli clé opaque) + couleur.
///
/// ⚠️ **LaTeX — mesuré, pas promis** : `ZFlashcardMarkdownContent` compose
/// `const ZMarkdownCodec()` SANS pont (`bridges` vide — vérifié sur pièces,
/// `z_flashcard_markdown_content.dart:88-95` + `z_markdown_codec.dart:386`).
/// Une source `$x^2$` reste donc du TEXTE LITTÉRAL intégral (aucune perte —
/// c'était le grief le plus grave de la CR — mais pas de formule DESSINÉE).
/// L'hôte à formules injecte `questionBuilder` avec son lecteur à ponts —
/// exactement la voie que la CR prévoit. La garde fige ce contrat.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

ZFlashcard _card({
  String id = 'c1',
  String question = 'Question ?',
  ZFlashcardType type = ZFlashcardType.openQuestion,
  String? answer,
  bool? isTrue,
  List<ZChoice>? choices,
}) =>
    ZFlashcard(
      id: id,
      question: question,
      type: type,
      answer: answer,
      isTrue: isTrue,
      choices: choices,
    );

Widget _host(
  Widget child, {
  double width = 400,
  Brightness brightness = Brightness.light,
}) =>
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );

/// Le `RichText` du lecteur riche dont le texte à plat contient [needle].
RichText _richTextContaining(WidgetTester tester, String needle) =>
    tester.widgetList<RichText>(find.byType(RichText)).firstWhere(
          (RichText rt) => rt.text.toPlainText().contains(needle),
          orElse: () => fail('🔴 aucun RichText ne contient « $needle »'),
        );

/// Style EFFECTIF (héritage inclus : racine → feuille) du premier segment
/// EXACT [text] — une lecture de la seule feuille mentirait, la teinte et la
/// graisse de base vivent sur le span RACINE du paragraphe.
TextStyle? _effectiveSpanStyle(WidgetTester tester, String text) {
  TextStyle? result;
  void visit(InlineSpan span, TextStyle? inherited) {
    final TextStyle? style = span.style == null
        ? inherited
        : (inherited == null ? span.style : inherited.merge(span.style));
    if (span is TextSpan) {
      if (span.text == text) result ??= style;
      for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
        visit(child, style);
      }
    }
  }

  for (final RichText rt
      in tester.widgetList<RichText>(find.byType(RichText))) {
    visit(rt.text, null);
    if (result != null) return result;
  }
  return null;
}

/// `true` si un segment EXACT [text] porte EFFECTIVEMENT [weight].
bool _spanHasWeight(WidgetTester tester, String text, FontWeight weight) =>
    _effectiveSpanStyle(tester, text)?.fontWeight == weight;

/// Couleur EFFECTIVE d'un segment EXACT [text] (premier trouvé).
Color? _spanColor(WidgetTester tester, String text) =>
    _effectiveSpanStyle(tester, text)?.color;

/// Décoration ombrée réellement construite AUTOUR de la carte (le
/// `DecoratedBox` d'ombre enveloppe le `Card`).
BoxDecoration? _shadowDecoration(WidgetTester tester) {
  for (final DecoratedBox box
      in tester.widgetList<DecoratedBox>(find.ancestor(
    of: find.byType(Card),
    matching: find.byType(DecoratedBox),
  ))) {
    final Decoration deco = box.decoration;
    if (deco is BoxDecoration && (deco.boxShadow?.isNotEmpty ?? false)) {
      return deco;
    }
  }
  return null;
}

void main() {
  // ==========================================================================
  group('CR-IFFD-59 ① — ligne d\'en-tête : tuile ⚡ ET balises sur la MÊME '
      'ligne, énoncé EN DESSOUS pleine largeur', () {
    testWidgets('géométrie mesurée (tuile 32×32, balises au même niveau, '
        'énoncé sous la ligne et aligné au bord du contenu)', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: 'Énoncé de mesure'),
        tags: const <ZFlashcardTag>[ZFlashcardTag(id: 't1', title: 'Balise')],
        trailing: const Icon(Icons.more_horiz, key: ValueKey<String>('menu')),
      )));
      await tester.pumpAndSettle();

      final Rect tile =
          tester.getRect(find.byKey(ZDefaultFlashcardCard.iconTileKey));
      final Rect tags =
          tester.getRect(find.byKey(ZDefaultFlashcardCard.tagsKey));
      final Rect question =
          tester.getRect(find.byKey(ZDefaultFlashcardCard.questionKey));
      final Rect menu = tester.getRect(find.byKey(const ValueKey<String>('menu')));

      // Cotes de référence (déjà en v0.46.0, revérifiées : 32/18).
      expect(tile.size, const Size(32, 32));
      expect(
        tester
            .widget<Icon>(find.descendant(
                of: find.byKey(ZDefaultFlashcardCard.iconTileKey),
                matching: find.byType(Icon)))
            .size,
        ZFlashcardCardReference.glyphSize,
      );

      // MÊME ligne : les centres verticaux de la tuile, des balises et du
      // créneau d'actions se recouvrent (tolérance : la moitié de la tuile).
      expect((tags.center.dy - tile.center.dy).abs(), lessThan(16),
          reason: '🔴 tuile et balises doivent partager la LIGNE d\'en-tête '
              '(le legacy les met dans la même Row).');
      expect((menu.center.dy - tile.center.dy).abs(), lessThan(16),
          reason: '🔴 le créneau d\'actions vit sur la ligne d\'en-tête '
              '(la place du more_horiz legacy).');
      // Balises À CÔTÉ de la tuile, jamais empilées.
      expect(tags.left, greaterThan(tile.right),
          reason: '🔴 balises À CÔTÉ de la tuile (même ligne).');

      // Énoncé EN DESSOUS…
      expect(question.top, greaterThanOrEqualTo(tile.bottom),
          reason: '🔴 l\'énoncé vient SOUS la ligne d\'en-tête.');
      // …et PLEINE LARGEUR : il repart du bord de contenu (celui de la tuile),
      // pas de l'ancienne colonne à droite de la tuile.
      expect(question.left, moreOrLessEquals(tile.left, epsilon: 1),
          reason: '🔴 l\'énoncé est PLEINE LARGEUR (aligné au bord du '
              'contenu, pas indenté à droite de la tuile).');
      expect(question.width, greaterThan(tile.width * 4),
          reason: '🔴 l\'énoncé occupe la largeur du contenu.');
    });
  });

  // ==========================================================================
  group('CR-IFFD-59 ② — enveloppe : ombre de référence (flou 8, décalage '
      '(0,2), alpha .06/.2) et liseré teinté par type', () {
    for (final MapEntry<Brightness, double> expected
        in <Brightness, double>{
      Brightness.light: ZFlashcardCardReference.shadowAlphaLight,
      Brightness.dark: ZFlashcardCardReference.shadowAlphaDark,
    }.entries) {
      testWidgets('${expected.key.name} : BoxShadow RÉELLEMENT construite '
          'avec les scalaires de référence', (tester) async {
        await tester.pumpWidget(_host(
          ZDefaultFlashcardCard(card: _card()),
          brightness: expected.key,
        ));
        await tester.pumpAndSettle();

        final BoxDecoration? deco = _shadowDecoration(tester);
        expect(deco, isNotNull,
            reason: '🔴 « l\'ombre existe » se mesure en BoxShadow construite '
                'autour du Card — pas en intention.');
        final BoxShadow shadow = deco!.boxShadow!.single;
        expect(shadow.blurRadius, ZFlashcardCardReference.shadowBlurRadius);
        expect(shadow.offset, ZFlashcardCardReference.shadowOffset);
        expect(shadow.color.a, moreOrLessEquals(expected.value, epsilon: 0.01),
            reason: '🔴 alpha d\'ombre de référence '
                '(${expected.value} en ${expected.key.name}).');
        // Deux ombres ne se superposent pas : l'élévation native cède.
        expect(tester.widget<Card>(find.byType(Card)).elevation, 0);
      });
    }

    testWidgets('jetons cardShadow* du thème : ils PRIMENT le repli de '
        'référence (le canal d\'ombre de l\'hôte reste atteignable)',
        (tester) async {
      final ZcrudTheme tokens = ZcrudTheme.fallback(ThemeData()).copyWith(
        cardShadowBlurRadius: 20,
        cardShadowOffset: const Offset(0, 6),
        cardShadowAlpha: 0.5,
      );
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData()
            .copyWith(extensions: <ThemeExtension<dynamic>>[tokens]),
        home: Scaffold(
          body: SizedBox(width: 400, child: ZDefaultFlashcardCard(card: _card())),
        ),
      ));
      await tester.pumpAndSettle();
      final BoxShadow shadow = _shadowDecoration(tester)!.boxShadow!.single;
      expect(shadow.blurRadius, 20,
          reason: '🔴 les jetons EXISTANTS de l\'epic VIS gouvernent — le '
              'repli de référence ne les rend jamais inatteignables.');
      expect(shadow.offset, const Offset(0, 6));
    });
  });

  // ==========================================================================
  group('CR-IFFD-59 ③ — énoncé : rendu RICHE par défaut, neutre sur du '
      'texte nu, questionBuilder en surcharge', () {
    testWidgets('🔴 markdown RÉEL : `**gras**` rend un segment `gras` en '
        'bold — la source `**` n\'apparaît NULLE PART', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: 'Un mot **gras** ici'),
      )));
      await tester.pumpAndSettle();

      expect(_spanHasWeight(tester, 'gras', FontWeight.bold), isTrue,
          reason: '🔴 « l\'énoncé est riche » = attribut bold RÉEL sur le '
              'segment — pas la présence d\'un widget lecteur.');
      expect(find.textContaining('**', findRichText: true), findsNothing,
          reason: '🔴 la source markdown ne doit jamais s\'afficher brute.');
    });

    testWidgets('LaTeX — contrat MESURÉ : la source `\$…\$` reste du texte '
        'LITTÉRAL INTÉGRAL (codec sans pont), jamais tronquée', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: r'Formule $x^2 + y^2$ à retenir'),
      )));
      await tester.pumpAndSettle();
      // Pas de perte : l'information mathématique est INTÉGRALEMENT rendue
      // (en source). Le rendu DESSINÉ passe par `questionBuilder` (hôte).
      expect(
        find.textContaining(r'$x^2 + y^2$', findRichText: true),
        findsOneWidget,
        reason: '🔴 le grief de la CR était la TRONCATURE silencieuse — la '
            'source doit survivre intégralement.',
      );
    });

    testWidgets('NEUTRALITÉ plain-text : hauteur du rendu riche ≈ Text '
        '13/w600 de référence, graisse w600, AUCUN liseré de champ peint',
        (tester) async {
      const String plain = 'Texte nu sans markdown';
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: plain),
      )));
      await tester.pumpAndSettle();

      // Graisse de référence héritée (w600).
      expect(_spanHasWeight(tester, plain, FontWeight.w600), isTrue,
          reason: '🔴 l\'énoncé de référence est w600 (legacy 13/w600).');

      // Échelle 16 → 13 réellement appliquée. MESURÉ : Quill force sa base à
      // 16 et son interligne à 1.15 — la ligne rendue fait 13 × 1.15 ≈ 15 dp
      // (l'interligne 1.15 est aussi celui du lecteur legacy, qui ÉTAIT un
      // lecteur markdown — la « neutralité Text » porte sur la TAILLE et la
      // graisse, pas sur l'interligne bodyMedium de Material, 1.43).
      final RichText rich = _richTextContaining(tester, plain);
      final Size richLine = tester.getSize(find.byWidget(rich));
      expect(
        rich.textScaler
            .scale(ZFlashcardCardReference.quillBaseFontSize),
        moreOrLessEquals(ZFlashcardCardReference.questionFontSize,
            epsilon: 0.1),
        reason: '🔴 l\'échelle 16 → 13 doit être RÉELLEMENT appliquée au '
            'paragraphe (sinon l\'énoncé rend à 16).',
      );
      expect(richLine.height, lessThan(16),
          reason: '🔴 une ligne à 16 non réduite rendrait ≥ 18.4 dp '
              '(16 × 1.15) — mesuré ici : ${richLine.height} dp '
              '(attendu ≈ 13 × 1.15 ≈ 15).');
      expect(richLine.height,
          greaterThanOrEqualTo(ZFlashcardCardReference.questionFontSize));
    });

    testWidgets('AUCUN liseré de champ PEINT autour de l\'énoncé (le lecteur '
        'de formulaire en peint un — neutralisé alpha 0)', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: 'Nu'),
      )));
      await tester.pumpAndSettle();
      // Chaque DecoratedBox SOUS l'énoncé qui porte une bordure doit la
      // porter INVISIBLE (alpha 0) — mesure sur le décor construit.
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(ZDefaultFlashcardCard.questionKey),
          matching: find.byType(DecoratedBox),
        ),
      );
      for (final DecoratedBox box in boxes) {
        final Decoration deco = box.decoration;
        if (deco is BoxDecoration && deco.border is Border) {
          final Border border = deco.border! as Border;
          expect(border.top.color.a, 0,
              reason: '🔴 un liseré de CHAMP peint dans la carte trahirait '
                  'la neutralisation (l\'énoncé n\'est pas un champ).');
        }
      }
    });

    testWidgets('questionBuilder INJECTÉ : il REMPLACE le rendu par défaut '
        '(aucun lecteur riche monté) et gouverne AUSSI l\'aperçu',
        (tester) async {
      int calls = 0;
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(question: 'Q1', answer: 'R1'),
        showAnswerPreview: true,
        questionBuilder: (BuildContext context, String content) {
          calls++;
          return Text('HÔTE:$content');
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('HÔTE:Q1'), findsOneWidget);
      expect(find.text('HÔTE:R1'), findsOneWidget,
          reason: '🔴 l\'aperçu de réponse SUIT le rendu de l\'énoncé.');
      expect(calls, 2);
      expect(find.byType(ZFlashcardMarkdownContent), findsNothing,
          reason: 'le builder de l\'hôte REMPLACE le défaut (AD-40).');
    });
  });

  // ==========================================================================
  group('CR-IFFD-59 ④ — aperçu de réponse en MODE (le isInGrid legacy)', () {
    testWidgets('mode OFF (défaut carte) : NI divider NI aperçu (AD-4)',
        (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(answer: 'Réponse'),
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsNothing);
      expect(find.byKey(ZDefaultFlashcardCard.answerPreviewKey), findsNothing);
    });

    testWidgets('mode ON + réponse libre : Divider (hauteur 12, rôle '
        'outlineVariant) puis aperçu RICHE teinté par type', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(answer: 'La bonne réponse'),
        showAnswerPreview: true,
      )));
      await tester.pumpAndSettle();

      final Divider divider = tester
          .widget<Divider>(find.byKey(ZDefaultFlashcardCard.answerDividerKey));
      expect(divider.height, ZFlashcardCardReference.answerDividerHeight);
      expect(find.byKey(ZDefaultFlashcardCard.answerPreviewKey), findsOneWidget);

      // Teinte par TYPE : premier plan = teinte LISIBLE dérivée de la
      // primaire du type (openQuestion #4facfe), jamais une couleur nouvelle.
      final Color expected = zReadableTypeTint(
        (ZFlashcardCardReference.openQuestionGradient.gradient
                as LinearGradient)
            .colors
            .first,
        isDark: false,
      );
      expect(_spanColor(tester, 'La bonne réponse'), expected,
          reason: '🔴 « aperçu teinté par type » = couleur MESURÉE sur le '
              'segment rendu.');
    });

    testWidgets('mode ON sans AUCUNE donnée de réponse : ni divider ni '
        'aperçu — jamais une donnée fabriquée (AD-10)', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(),
        showAnswerPreview: true,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsNothing);
      expect(find.byKey(ZDefaultFlashcardCard.answerPreviewKey), findsNothing);
    });

    testWidgets('tampon « Vrai » : libellé INJECTÉ rendu, teinte de type '
        'LISIBLE, scalaires de référence (200×40, rotation −0.45)',
        (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(type: ZFlashcardType.trueOrFalse, isTrue: true),
        showAnswerPreview: true,
        answerLabels: const <String, String>{'true': 'Vrai', 'false': 'Faux'},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Vrai'), findsOneWidget,
          reason: '🔴 le tampon se mesure en TEXTE RENDU (AD-13).');
      final Text label = tester
          .widget<Text>(find.byKey(ZDefaultFlashcardCard.stampLabelKey));
      final Color expected = zReadableTypeTint(
        (ZFlashcardCardReference.trueOrFalseGradient.gradient
                as LinearGradient)
            .colors
            .first,
        isDark: false,
      );
      expect(label.style?.color, expected,
          reason: '🔴 « vrai » = teinte de type lisible (le teal legacy '
              'n\'est pas un rôle — FR-26).');

      final Container stamp = tester
          .widget<Container>(find.byKey(ZDefaultFlashcardCard.stampKey));
      expect(stamp.constraints?.maxWidth, ZFlashcardCardReference.stampWidth);
      expect(
          stamp.constraints?.maxHeight, ZFlashcardCardReference.stampHeight);
      expect(stamp.transform,
          isNotNull, // rotation −0.45 + translation (0,40) — legacy
          reason: '🔴 le tampon legacy est INCLINÉ (rotationZ −0.45).');
      final BoxDecoration deco = stamp.decoration! as BoxDecoration;
      expect(deco.color?.a,
          moreOrLessEquals(ZFlashcardCardReference.stampBackgroundAlpha,
              epsilon: 0.01));
    });

    testWidgets('tampon « Faux » : rôle error ; libellés absents ⇒ repli '
        'CLÉ OPAQUE (jamais une traduction en dur)', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(type: ZFlashcardType.trueOrFalse, isTrue: false),
        showAnswerPreview: true,
      )));
      await tester.pumpAndSettle();
      expect(find.text('false'), findsOneWidget,
          reason: '🔴 repli = clé opaque — le socle ne dit jamais « Faux » '
              'de lui-même (FR-26).');
      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(ZDefaultFlashcardCard)))
              .colorScheme;
      final Text label = tester
          .widget<Text>(find.byKey(ZDefaultFlashcardCard.stampLabelKey));
      expect(label.style?.color, scheme.error);
    });

    testWidgets('trueOrFalse SANS isTrue : aperçu ABSENT — jamais un « Faux » '
        'fabriqué depuis null (écart assumé avec le legacy)', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(type: ZFlashcardType.trueOrFalse),
        showAnswerPreview: true,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.stampKey), findsNothing);
      expect(find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsNothing);
    });

    testWidgets('multipleChoice : la liste des choix ✓/✕ (fidélité au CODE '
        'legacy) — corrects teintés type, incorrects rôle error',
        (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
        card: _card(
          type: ZFlashcardType.multipleChoice,
          choices: const <ZChoice>[
            ZChoice(content: 'Bonne', isCorrect: true),
            ZChoice(content: 'Mauvaise'),
          ],
        ),
        showAnswerPreview: true,
      )));
      await tester.pumpAndSettle();

      expect(find.text('✓ '), findsOneWidget);
      expect(find.text('✕ '), findsOneWidget,
          reason: '🔴 la marque est TEXTUELLE (AD-13) — la couleur n\'est '
              'jamais le seul canal.');
      final ColorScheme scheme =
          Theme.of(tester.element(find.byType(ZDefaultFlashcardCard)))
              .colorScheme;
      final Color expected = zReadableTypeTint(
        (ZFlashcardCardReference.multipleChoiceGradient.gradient
                as LinearGradient)
            .colors
            .first,
        isDark: false,
      );
      expect(_spanColor(tester, 'Bonne'), expected);
      expect(_spanColor(tester, 'Mauvaise'), scheme.error);
    });
  });

  // ==========================================================================
  group('CR-IFFD-59 ⑤ — câblage du MODE par les surfaces', () {
    ZStudyToolsSectionSpec spec({
      required Axis axis,
      bool? showAnswerPreview,
    }) =>
        ZStudyToolsSectionSpec.flashcards(
          id: 'flashcards',
          title: 'Cartes',
          cards: <ZFlashcard>[_card(answer: 'Réponse en aperçu')],
          emptyState: const SizedBox.shrink(),
          axis: axis,
          showAnswerPreview: showAnswerPreview,
        );

    Future<void> pumpSpec(WidgetTester tester, ZStudyToolsSectionSpec s) =>
        tester.pumpWidget(_host(
          SizedBox(
            height: 240,
            child: Builder(builder: (BuildContext c) => s.itemBuilder(c, 0)),
          ),
          width: 600,
        ));

    testWidgets('voie typée VERTICALE (grille) ⇒ aperçu PRÉSENT par défaut',
        (tester) async {
      await pumpSpec(tester, spec(axis: Axis.vertical));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsOneWidget,
          reason: '🔴 la grille est la surface `isInGrid` du legacy.');
    });

    testWidgets('voie typée HORIZONTALE (rail) ⇒ aperçu ABSENT par défaut',
        (tester) async {
      await pumpSpec(tester, spec(axis: Axis.horizontal));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsNothing,
          reason: '🔴 le rail de sections n\'affiche PAS l\'aperçu (CR-59).');
    });

    testWidgets('surcharge EXPLICITE : elle gouverne, dans les deux sens',
        (tester) async {
      await pumpSpec(
          tester, spec(axis: Axis.vertical, showAnswerPreview: false));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsNothing);

      await pumpSpec(
          tester, spec(axis: Axis.horizontal, showAnswerPreview: true));
      await tester.pumpAndSettle();
      expect(
          find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsOneWidget);
    });

    testWidgets('liste en mode CARTE (CR-58) ⇒ aperçu ACTIF, answerLabels '
        'relayés (tampon localisé)', (tester) async {
      await tester.pumpWidget(_host(
        SizedBox(
          height: 600,
          child: ZFlashcardListView(
            cards: <ZFlashcard>[
              _card(type: ZFlashcardType.trueOrFalse, isTrue: true),
            ],
            labels: const ZFlashcardListLabels(
              searchHint: 'Rechercher',
              searchFieldLabel: 'Recherche',
              emptyState: 'Aucune carte',
              noResults: 'Aucun résultat',
              actionsMenuTooltip: 'Actions',
              openAction: 'Ouvrir',
              editAction: 'Modifier',
              deleteAction: 'Supprimer',
              duplicateAction: 'Dupliquer',
              moveUpAction: 'Monter',
              moveDownAction: 'Descendre',
              generateWithAiAction: 'Générer',
              readOnlyBadge: 'Lecture seule',
            ),
            answerLabels: const <String, String>{
              'true': 'Vrai',
              'false': 'Faux',
            },
          ),
        ),
        width: 800,
      ));
      await tester.pump();
      expect(
          find.byKey(ZDefaultFlashcardCard.answerDividerKey), findsOneWidget,
          reason: '🔴 CR-58 : le style carte ACTIVE l\'aperçu.');
      expect(find.text('Vrai'), findsOneWidget,
          reason: '🔴 answerLabels relayés par la liste (FR-26).');
    });
  });

  // ==========================================================================
  group('CR-IFFD-59 — « non mesurés » : coût du rendu riche en rail, ombre '
      'sous densité', () {
    testWidgets('rail de 50 cartes markdown : le CULLING tient (widgets '
        'construits ≪ 50) et l\'ombre ne le casse pas', (tester) async {
      final Stopwatch richWatch = Stopwatch()..start();
      await tester.pumpWidget(_host(
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 50,
            itemBuilder: (BuildContext context, int i) => ZRailItem(
              child: ZDefaultFlashcardCard(
                card: _card(
                  id: 'c$i',
                  question: 'Énoncé **numéro $i** avec du `code` et du texte '
                      'assez long pour peupler la carte.',
                ),
              ),
            ),
          ),
        ),
        width: 800,
      ));
      await tester.pumpAndSettle();
      richWatch.stop();

      final int built =
          find.byType(ZDefaultFlashcardCard, skipOffstage: false)
              .evaluate()
              .length;
      expect(built, lessThan(15),
          reason: '🔴 CULLING : un rail virtualisé ne construit que le '
              'viewport (+cache) — $built construites sur 50. L\'ombre '
              '(DecoratedBox par carte) ne doit pas le casser.');
      // Chaque carte CONSTRUITE porte bien son ombre (densité réelle).
      expect(_shadowDecoration(tester), isNotNull);

      // Variante PLAIN (questionBuilder → Text) pour la comparaison de coût.
      final Stopwatch plainWatch = Stopwatch()..start();
      await tester.pumpWidget(_host(
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 50,
            itemBuilder: (BuildContext context, int i) => ZRailItem(
              child: ZDefaultFlashcardCard(
                card: _card(id: 'p$i', question: 'Énoncé numéro $i'),
                questionBuilder: (BuildContext c, String s) => Text(s),
              ),
            ),
          ),
        ),
        width: 800,
      ));
      await tester.pumpAndSettle();
      plainWatch.stop();

      // Mesure RAPPORTÉE (pas de seuil : le temps machine varie) — le rapport
      // de lot consigne l'ordre de grandeur riche vs plain.
      // ignore: avoid_print
      print('CR-IFFD-59 mesure rail 50 cartes — riche: '
          '${richWatch.elapsedMilliseconds} ms, plain: '
          '${plainWatch.elapsedMilliseconds} ms, cartes construites: $built');

      // Défilement RÉEL : le rail répond et recycle sans throw.
      await tester.drag(find.byType(ListView), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final int afterScroll =
          find.byType(ZDefaultFlashcardCard, skipOffstage: false)
              .evaluate()
              .length;
      expect(afterScroll, lessThan(15),
          reason: '🔴 le culling tient AUSSI en défilement (recyclage).');
    });
  });
}
