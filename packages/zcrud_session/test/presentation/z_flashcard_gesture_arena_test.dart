/// 🎯 AC9 — **L'ARÈNE DES GESTES** : saisie ET révélation coexistent sans se
/// voler le tap.
///
/// **Contexte : un HIGH RÉEL** (code-review su-2, D1). Sur le chemin d'usage que
/// su-2 documente verbatim (`contentBuilder: ZFlashcardMarkdownContent.builder()`),
/// le `QuillEditor` **gagnait l'arène** contre l'`InkWell` de la carte ⇒
/// `onRevealChanged` ne recevait rien, **la réponse n'apparaissait jamais** —
/// sous **328/328 tests verts**. Ces tests empruntent **le chemin markdown
/// EXACT** : c'est le seul qui pouvait démasquer D1, et le seul qui peut
/// démasquer sa réapparition.
///
/// 🚫 **INTERDIT** : « régler » l'arène en retirant l'`IgnorePointer` de su-2 —
/// c'est le **correctif d'un HIGH réel**, et la non-régression est gardée ici.
///
/// ---
///
/// # 🎯 ACTE III (SU-4) — le **drag horizontal** entre dans l'arène
///
/// su-4 pose un `CardSwiper` **par-dessus** la carte d'affichage. Le paquet y
/// installe (lu sur disque, `card_swiper_state.dart:113-171`) :
///  - un `onPanStart/Update/End` ⇒ un **`PanGestureRecognizer`, qui revendique
///    LES DEUX AXES** (et non un `HorizontalDragGestureRecognizer`) ;
///  - un `onTap` **TOUJOURS** enregistré (même hors `isDisabled`) ⇒ un
///    `TapGestureRecognizer` en permanence dans l'arène — **exactement** la
///    configuration du HIGH D1, avec un compétiteur de plus.
///
/// **La conception retenue dissout le conflit par la GÉOMÉTRIE** (continuité
/// exacte de su-3) : le pan ne couvre **QUE** la carte d'affichage ;
/// `ZFlashcardAnswerInput` et `ZSrsQualityButtons` restent **FRÈRES, HORS du
/// swiper** ⇒ le champ de texte n'est **jamais** sous le pan.
///
/// Restent **DEUX conflits réels**, que la story pose en **PRÉDICTIONS à
/// MESURER** — jamais à raisonner. **Verdict mesuré ici** (cf. Dev Agent Record) :
///  1. *drag ∥ tap-to-reveal* — prédit : l'`InkWell` (descendant) gagne le tap.
///     ✅ **PRÉDICTION CONFIRMÉE** (test « (4) »).
///  2. *drag ∥ scroll vertical* — prédit : le `Scrollable` de la face (descendant)
///     gagne le geste vertical, le pan est rejeté. ✅ **PRÉDICTION CONFIRMÉE**
///     (test « (6) »).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// QCM à **2** corrects (multi-sélection : cocher n'en décoche pas un autre —
/// on isole ainsi le geste, sans effet de bord d'exclusivité).
ZFlashcard _qcm() => const ZFlashcard(
      question: 'Quels régimes sont suspensifs ?',
      type: ZFlashcardType.multipleChoice,
      choices: <ZChoice>[
        ZChoice(content: 'Transit', isCorrect: true),
        ZChoice(content: 'Mise à la consommation'),
        ZChoice(content: 'Entrepôt', isCorrect: true),
      ],
      answer: 'Transit et entrepôt',
      explanation: 'Les deux suspendent les droits.',
    );

/// Carte **RÉDIGÉE** — le seul chemin qui rend un vrai `TextField` (SU-4/AC6 :
/// sans lui, le conflit *drag ∥ saisie* ne serait pas exercé).
ZFlashcard _written() => const ZFlashcard(
      question: 'Définissez le régime du transit.',
      type: ZFlashcardType.openQuestion,
      answer: 'Suspension des droits pendant le déplacement sous douane.',
      explanation: 'Le transit suspend les droits.',
    );

/// Carte **LONGUE** — face RÉELLEMENT défilable (`maxScrollExtent > 0`).
///
/// 🔴 **Sans elle, le duel *pan ∥ Scrollable* n'a JAMAIS LIEU** (trou réel,
/// mesuré) : sur une carte courte, `maxScrollExtent == 0` ⇒
/// `ScrollPhysics.shouldAcceptUserOffset` est **faux** ⇒
/// `Scrollable.setCanDrag(false)` ⇒ **son recognizer n'entre même pas dans
/// l'arène**. Le test « mesurait » un duel dont l'un des deux combattants était
/// absent (mesuré : `pixels 0.0 → 0.0`, `maxScrollExtent = 0.0`).
ZFlashcard _long() => ZFlashcard(
      question: List<String>.generate(
        60,
        (i) => 'Ligne $i — le régime suspensif n°$i suspend les droits et '
            'taxes pendant le déplacement de la marchandise sous douane.',
      ).join('\n\n'),
      type: ZFlashcardType.openQuestion,
      answer: 'Réponse longue.',
      explanation: 'Explication longue.',
    );

void main() {
  group('🎯 AC9 — les deux surfaces composées en FRÈRES (chemin MARKDOWN)', () {
    /// Hôte composant les DEUX surfaces en **frères** (sous-arbres disjoints)
    /// sur le **chemin markdown** — la configuration exacte du HIGH D1.
    Future<({List<bool> reveals, List<ZFlashcardSubmission> submissions})>
        pumpHost(
      WidgetTester tester,
    ) async {
      final reveals = <bool>[];
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  // FRÈRE 1 — surface d'AFFICHAGE (su-2), révélation par tap.
                  SizedBox(
                    height: 300,
                    child: ZFlashcardReviewCard(
                      card: _qcm(),
                      contentBuilder: ZFlashcardMarkdownContent.builder(),
                      onRevealChanged: reveals.add,
                    ),
                  ),
                  // FRÈRE 2 — surface de SAISIE (su-3), AUCUN tap-to-reveal.
                  ZFlashcardAnswerInput(
                    card: _qcm(),
                    mode: ZReviewMode.learn,
                    contentBuilder: ZFlashcardMarkdownContent.builder(),
                    // `onQualitySelected` NON nul ⇒ la rangée SRS apparaît DÈS
                    // qu'une correction existe : elle devient ainsi un TÉMOIN
                    // observable de « une correction a eu lieu », y compris si
                    // le `feedback` est absent. Sans ce témoin, un tap-to-reveal
                    // injecté passerait inaperçu (mesuré : R3-I9 restait vert).
                    onQualitySelected: (_) {},
                    onSubmitted: submissions.add,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (reveals: reveals, submissions: submissions);
    }

    testWidgets(
        '🔴 (1) tap AU CENTRE d\'une case QCM ⇒ la case bascule ET `revealed` '
        'reste FALSE (le contenu riche ne vole pas le geste)', (tester) async {
      final host = await pumpHost(tester);

      final choice = find.byKey(const ValueKey<String>('zAnswerChoice_0'));
      expect(choice, findsOneWidget);
      // `tap` (centre) et non `tapAt` d'un coin : on veut précisément le point
      // qu'un contenu interactif pourrait capter.
      await tester.tap(choice, warnIfMissed: false);
      await tester.pump();

      // La case a bien basculé : le contrôle de saisie a REÇU le geste.
      final semantics = tester.getSemantics(choice);
      expect(
        semantics.hasFlag(SemanticsFlag.isChecked),
        isTrue,
        reason: 'la case n\'a pas basculé : le geste a été volé au contrôle de '
            'saisie (rejeu du HIGH D1)',
      );
      // …et la carte SŒUR n'a rien révélé : les surfaces sont ÉTANCHES.
      expect(
        host.reveals,
        isEmpty,
        reason: 'taper la SAISIE a révélé la carte d\'AFFICHAGE : les deux '
            'surfaces partagent une arène (R3-I9)',
      );
    });

    testWidgets(
        '🔴 (2) tap sur la carte d\'AFFICHAGE ⇒ `revealed == true` ET la '
        'sélection QCM reste INCHANGÉE', (tester) async {
      final host = await pumpHost(tester);

      final choice = find.byKey(const ValueKey<String>('zAnswerChoice_0'));
      expect(
        tester.getSemantics(choice).hasFlag(SemanticsFlag.isChecked),
        isFalse,
      );

      await tester.tap(find.byType(ZFlashcardReviewCard), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        host.reveals,
        isNotEmpty,
        reason: 'la révélation par tap de su-2 est CASSÉE sur le chemin '
            'markdown — c\'est exactement le HIGH D1',
      );
      expect(host.reveals.last, isTrue);
      // La saisie n'a pas bougé.
      expect(
        tester.getSemantics(choice).hasFlag(SemanticsFlag.isChecked),
        isFalse,
        reason: 'taper la carte d\'affichage a modifié la SAISIE',
      );
    });

    testWidgets(
        '🔴 (3) tap AU CENTRE du contenu riche de la SAISIE ⇒ contenu INERTE '
        '(aucune soumission, aucune révélation)', (tester) async {
      final host = await pumpHost(tester);

      // 🔒 Sonde SCOPÉE au sous-arbre VISÉ (leçon su-2 D5 : mesurer un sibling
      // est structurellement aveugle). La carte d'affichage rend PLUSIEURS
      // contenus riches (question/réponse/choix/explication) — cibler « le
      // dernier markdown de l'arbre » viserait au petit bonheur.
      final richInInput = find.descendant(
        of: find.byType(ZFlashcardAnswerInput),
        matching: find.byType(ZFlashcardMarkdownContent),
      );
      expect(richInInput, findsOneWidget,
          reason: 'la surface de saisie rend exactement un contenu de slot');
      await tester.tap(richInInput, warnIfMissed: false);
      await tester.pump();

      // 🔴 TÉMOIN de correction : la rangée SRS n'apparaît QUE si une
      // correction existe. C'est le canal qui rougit sur R3-I9 (un
      // `InkWell(onTap: reveal)` posé autour de la saisie) — `zFeedback` seul ne
      // suffisait PAS : une correction sans `feedback` ne rend aucun texte, et
      // l'injection restait invisible (mesuré).
      expect(
        find.byType(ZSrsQualityButtons),
        findsNothing,
        reason: 'une correction est apparue SANS soumission ⇒ un tap-to-reveal '
            'a été posé sur la surface de saisie (R3-I9)',
      );
      expect(find.byKey(const ValueKey<String>('zFeedback')), findsNothing);
      expect(host.submissions, isEmpty,
          reason: 'taper le contenu inerte a déclenché une soumission');
      expect(host.reveals, isEmpty, reason: 'le contenu de saisie a révélé');
      // Le contenu est inerte : il n'a pas non plus coché de case.
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey<String>('zAnswerChoice_0')))
            .hasFlag(SemanticsFlag.isChecked),
        isFalse,
      );
    });
  });

  group('🎯 ACTE III (SU-4/AC6) — drag ∥ tap ∥ saisie ∥ scroll (MARKDOWN)', () {
    /// Hôte reproduisant la composition de PROD **exacte** : la pile
    /// (contenant la carte d'affichage) est **FRÈRE** de la surface de saisie et
    /// de la rangée de notation — celles-ci ne descendent JAMAIS dans le
    /// `cardBuilder` (c'est la dissolution par la géométrie).
    ///
    /// Sur le **chemin markdown EXACT** — le seul qui pouvait démasquer D1, et
    /// le seul qui peut démasquer sa réapparition.
    /// 🔑 **Cible la carte de DEVANT, par IDENTITÉ** (jamais par ordre de
    /// peinture).
    ///
    /// 🔴 **Trou réel, mesuré** : les tests visaient
    /// `find.byType(ZFlashcardReviewCard).first`. Or `_CardSwiperState.build`
    /// fait `List.generate(…).reversed.toList()` ⇒ children =
    /// `[carte de FOND, carte de DEVANT]` ⇒ **`.first` est la carte de FOND** —
    /// celle que le pointeur n'atteint **jamais** et qui n'a **aucun**
    /// `GestureDetector` (`_backItem` n'en pose pas). Décisif : même carte
    /// longue, même drag, seul le `of:` change ⇒ `of: .first` donne
    /// `pixels 0.0 → 0.0`, `of: .last` donne `0.0 → 100.0`.
    ///
    /// La pile rend `cardBuilder(_currentIndex)` en devant et `_nextIndex` au
    /// fond : viser `f0` par sa clé désigne donc la carte de devant **sans
    /// dépendre de la géométrie** — contrairement à `.last`, qui redeviendrait
    /// faux si le paquet changeait son ordre de peinture.
    Finder frontCard() => find.byKey(const ValueKey<String>('reviewcard_f0'));

    Future<
        ({
          List<(String, bool)> reveals,
          List<int> indices,
          List<ZFlashcardSubmission> submissions,
        })> pumpStack(WidgetTester tester, {ZFlashcard Function()? card}) async {
      // 🔴 Les révélations sont tracées **PAR CARTE** (trou réel) : le harnais
      // câblait `onRevealChanged` sur TOUTES les cartes sans les distinguer ⇒
      // `host.reveals` ne disait pas LAQUELLE avait été révélée. Un tap qui
      // atteignait l'`InkWell` de la carte de FOND (elle en a un, bien réel)
      // laissait donc le test VERT alors que la révélation de la carte de devant
      // était morte — le HIGH D1 de su-2 rejoué sous un test incapable de le voir.
      final reveals = <(String, bool)>[];
      final indices = <int>[];
      final submissions = <ZFlashcardSubmission>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                // FRÈRE 1 — LA PILE : elle SEULE porte le pan.
                Expanded(
                  child: ZSessionCardSwiper(
                    queue: const <ZSessionItem>[
                      ZSessionItem(flashcardId: 'f0', folderId: 'd1'),
                      ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
                    ],
                    passThreshold: 3,
                    onIndexChanged: indices.add,
                    cardBuilder: (context, item) => ZFlashcardReviewCard(
                      key: ValueKey<String>('reviewcard_${item.flashcardId}'),
                      card: (card ?? _qcm)(),
                      contentBuilder: ZFlashcardMarkdownContent.builder(),
                      onRevealChanged: (v) =>
                          reveals.add((item.flashcardId, v)),
                    ),
                  ),
                ),
                // FRÈRE 2 — la SAISIE, HORS de la pile : jamais sous le pan.
                //
                // ⚠️ Carte **RÉDIGÉE** (`openQuestion`) et non le QCM : c'est le
                // seul type qui rend un VRAI `TextField` (`zIsLocallyEvaluatedType`
                // → false ⇒ chemin rédigé). Avec un QCM, la surface ne rend que
                // des cases, et le conflit *drag ∥ SAISIE* — celui qu'AC6 exige
                // de mesurer — ne serait tout simplement PAS exercé.
                ZFlashcardAnswerInput(
                  card: _written(),
                  mode: ZReviewMode.learn,
                  contentBuilder: ZFlashcardMarkdownContent.builder(),
                  onQualitySelected: (_) {},
                  onSubmitted: submissions.add,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (reveals: reveals, indices: indices, submissions: submissions);
    }

    testWidgets(
        '🔴 (4) PRÉDICTION 1 MESURÉE — tap sur la carte ⇒ `onRevealChanged` '
        'émis ET l\'index N\'AVANCE PAS (l\'InkWell gagne le `onTap` du swiper)',
        (tester) async {
      final host = await pumpStack(tester);

      // 🔑 La carte de DEVANT, visée par identité — et SANS `warnIfMissed:
      // false` : ce drapeau éteignait précisément l'avertissement de Flutter
      // disant que le geste n'atteint pas le widget nommé par le `Finder`. Le
      // test ne passait que parce que le centre du DOS tombait, par la géométrie
      // du moment, à l'intérieur de la carte de devant qui le recouvre.
      // Coïncidence, pas conception.
      await tester.tap(frontCard());
      await tester.pumpAndSettle();

      // 🎯 La révélation survit au `TapGestureRecognizer` du CardSwiper — et
      // c'est bien la carte de DEVANT qui a été révélée.
      expect(
        host.reveals,
        isNotEmpty,
        reason: '🔴 le `onTap` TOUJOURS enregistré par `CardSwiper` a volé le '
            'tap de révélation : c\'est le HIGH D1 qui renaît, un acte plus '
            'tard. (Prédiction de la story INFIRMÉE — corriger la COMPOSITION, '
            'jamais l\'IgnorePointer de su-2.)',
      );
      expect(host.reveals.last, ('f0', true),
          reason: '🔴 la carte révélée n\'est PAS celle de devant : le tap a '
              'atteint l\'`InkWell` de la carte de FOND');
      // …et un tap n'est PAS une navigation.
      expect(host.indices, isEmpty,
          reason: 'un simple tap a fait avancer la pile');
    });

    testWidgets(
        '🔴 (5) drag horizontal sur la carte ⇒ l\'index AVANCE, et RIEN n\'est '
        'révélé', (tester) async {
      final host = await pumpStack(tester);

      // 🔑 Carte de DEVANT, visée par identité, sans `warnIfMissed: false`
      // (cf. note du test (4)).
      await tester.drag(frontCard(), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(host.indices, <int>[1],
          reason: 'le drag horizontal doit naviguer (FR-SU6)');
      expect(
        host.reveals,
        isEmpty,
        reason: '🔴 un drag a RÉVÉLÉ la carte : l\'InkWell traite le geste comme '
            'un tap ⇒ l\'apprenant dévoile la réponse en naviguant',
      );
    });

    testWidgets(
        '🔴 (6) PRÉDICTION 2 MESURÉE — drag VERTICAL sur la face défilable ⇒ la '
        'face défile ET l\'index N\'AVANCE PAS (le Scrollable gagne)',
        (tester) async {
      // 🔴 **CE TEST NE MESURAIT RIEN — vacueux sur TROIS axes indépendants,
      // chacun suffisant** (mesuré, puis fermé) :
      //
      //  (a) la face montée était `_qcm()` — une carte COURTE, donc
      //      `maxScrollExtent == 0.0` ⇒ le `Scrollable` **décline** le geste
      //      (`setCanDrag(false)`) ⇒ le duel n'avait **jamais lieu**. Le
      //      `expect(scrollable, findsWidgets)` prouvait la **présence** du
      //      viewport, jamais sa **capacité à défiler** — « présence au lieu
      //      d'association », appliqué à un `Scrollable`.
      //  (b) le finder visait `.first` = la carte de **FOND** (cf. `frontCard()`),
      //      que le pointeur n'atteint jamais.
      //  (c) l'assertion `indices isEmpty` est **structurellement vraie quoi
      //      qu'il arrive** : `symmetric(horizontal: true)` fait rejeter
      //      `top`/`bottom` par `_isValidDirection` ⇒ `onSwipe` n'est **jamais**
      //      appelé sur un geste vertical, **même si le pan gagne l'arène de
      //      bout en bout** (mesuré : drag de -400 px, 8× le seuil ⇒
      //      `indices=[]`).
      //
      // Et **AC6 exige « la face DÉFILE »** — ce que le test n'assérait JAMAIS
      // (`grep "position.pixels|maxScrollExtent" test/` → 0 hit).
      // La vraie mesure (carte longue + carte de devant) donne `pixels = 100.0`
      // **et** `indices = []` : la prédiction est VRAIE — elle est désormais
      // **prouvée**, et non plus seulement affirmée.
      final host = await pumpStack(tester, card: _long);

      // 🔒 Sonde SCOPÉE au sous-arbre visé (leçon su-2/D5) : le `Scrollable` DE
      // LA CARTE DE DEVANT, jamais « un scrollable de l'arbre ».
      final scrollable = find.descendant(
        of: frontCard(),
        matching: find.byType(Scrollable),
      );
      expect(scrollable, findsWidgets,
          reason: 'la face de su-2 doit être défilable');

      final position = tester.state<ScrollableState>(scrollable.first).position;
      // 🎯 **LE TÉMOIN qui empêche la vacuité (a)** : sans matière à défiler, le
      // Scrollable n'entre pas dans l'arène et ce test est creux.
      expect(position.maxScrollExtent, greaterThan(0),
          reason: '🔴 la face n\'a RIEN à défiler ⇒ le `Scrollable` décline le '
              'geste ⇒ le duel *pan ∥ Scrollable* n\'a PAS LIEU : ce test ne '
              'mesure alors ABSOLUMENT rien');
      expect(position.pixels, 0.0, reason: 'témoin : on part du haut');

      await tester.drag(scrollable.first, const Offset(0, -100));
      await tester.pumpAndSettle();

      // 🎯 **CE QU'AC6 EXIGE, et que le test n'assérait jamais : LA FACE DÉFILE.**
      // C'est la SEULE assertion qui rougit si le pan vole le défilement —
      // `indices isEmpty` ne le fera jamais (c).
      expect(position.pixels, greaterThan(0),
          reason: '🔴 la face n\'a PAS défilé : le pan du CardSwiper (qui '
              'revendique les DEUX axes) a volé le geste vertical ⇒ l\'apprenant '
              'ne peut plus LIRE une carte longue. (Prédiction de la story '
              'INFIRMÉE — corriger la COMPOSITION, jamais l\'IgnorePointer.)');

      // 🎯 …et le `PanGestureRecognizer` (ancêtre) n'a PAS navigué.
      expect(
        host.indices,
        isEmpty,
        reason: '🔴 un geste VERTICAL a fait avancer la pile',
      );
      expect(host.reveals, isEmpty,
          reason: 'un défilement a révélé la carte');
    });

    testWidgets(
        '🔴 (7) saisie dans le champ (tap + frappe) ⇒ le texte est saisi ET '
        'l\'index N\'AVANCE PAS (le champ est HORS du pan, par construction)',
        (tester) async {
      final host = await pumpStack(tester);

      final field = find.byType(TextField);
      expect(field, findsOneWidget,
          reason: 'la surface de saisie rend un champ en mode rédigé/learn');

      await tester.tap(field);
      await tester.pumpAndSettle();
      await tester.enterText(field, 'transit');
      await tester.pumpAndSettle();

      expect(find.text('transit'), findsOneWidget,
          reason: '🔴 la frappe n\'a pas atteint le champ');
      expect(
        host.indices,
        isEmpty,
        reason: '🔴 saisir du texte a fait AVANCER la pile — le champ est passé '
            'sous le `PanGestureRecognizer` (R3-I10c). C\'est le conflit que la '
            'géométrie doit DISSOUDRE : le champ ne descend jamais dans le '
            '`cardBuilder`.',
      );
      expect(host.reveals, isEmpty);
    });

    test(
        '🔴 (8) GARDE DE COMPOSITION — le swiper ne compose NI la saisie NI la '
        'notation (la dissolution est structurelle, pas circonstancielle)', () {
      // ⚠️ Les tests (4)..(7) prouvent le comportement de l'hôte de TEST. Cette
      // garde-ci prouve que le CODE DE PROD du swiper ne peut pas, lui-même,
      // faire descendre une surface concurrente sous le pan.
      const swiperPath = 'lib/src/presentation/z_session_card_swiper.dart';
      final src = File(swiperPath);
      expect(src.existsSync(), isTrue,
          reason: 'introuvable: $swiperPath (cwd=${Directory.current.path})');
      final decls = <String>[
        for (final raw in src.readAsLinesSync())
          if (!raw.trimLeft().startsWith('///') &&
              !raw.trimLeft().startsWith('//') &&
              !raw.trimLeft().startsWith('*'))
            raw,
      ].join('\n');

      for (final banned in <String>[
        'ZFlashcardAnswerInput',
        'ZSrsQualityButtons',
      ]) {
        expect(
          decls.contains(banned),
          isFalse,
          reason: '🔴 `$banned` est composé PAR le swiper : il descend donc sous '
              'le `PanGestureRecognizer`. Un TextField sous un pan ancêtre, '
              'c\'est le curseur et la sélection qui se battent contre la '
              'navigation — aucun seuil ne rend cela fiable.',
        );
      }
    });
  });

  group('AC9 — gardes de SOURCE (scan par déclaration + contre-preuve R12)', () {
    /// Chemin RÉEL du fichier de su-2 (résolu depuis le CWD du package
    /// `zcrud_session`, cf. convention des gardes existantes).
    const reviewCardPath =
        '../zcrud_flashcard/lib/src/presentation/z_flashcard_review_card.dart';
    const answerInputPath = 'lib/src/presentation/z_flashcard_answer_input.dart';

    /// Recolle les déclarations (mêmes raisons que `z_widgets_purity_test.dart` :
    /// un scan ligne-à-ligne est aveugle aux coupures de `dart format`).
    List<String> declarations(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue,
          reason: 'introuvable: $path (cwd=${Directory.current.path})');
      final out = <String>[];
      final buffer = StringBuffer();
      for (final raw in file.readAsLinesSync()) {
        var trimmed = raw.trim();
        if (trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.startsWith('/*')) {
          continue;
        }
        final slash = trimmed.indexOf('//');
        if (slash >= 0) trimmed = trimmed.substring(0, slash).trim();
        if (trimmed.isEmpty) continue;
        buffer.write(trimmed);
        if (trimmed.endsWith(';') ||
            trimmed.endsWith('{') ||
            trimmed.endsWith('}')) {
          out.add(buffer.toString());
          buffer.clear();
        }
      }
      if (buffer.isNotEmpty) out.add(buffer.toString());
      return out;
    }

    test(
        '🔴 NON-RÉGRESSION su-2 : l\'`IgnorePointer` du slot est TOUJOURS là '
        '(correctif d\'un HIGH — interdit de le retirer)', () {
      final decls = declarations(reviewCardPath);
      expect(
        decls.any((d) => d.contains('IgnorePointer(')),
        isTrue,
        reason: 'l\'IgnorePointer de `z_flashcard_review_card.dart` a DISPARU : '
            'c\'est le correctif du HIGH D1 de su-2 — le retirer rouvre le bug '
            '« la réponse n\'apparaît jamais » sur le chemin markdown',
      );
    });

    test('le contenu de la SAISIE est lui aussi sous `IgnorePointer` (AC9)', () {
      final decls = declarations(answerInputPath);
      expect(
        decls.any((d) => d.contains('IgnorePointer(child: _contentBuilder(')),
        isTrue,
        reason: 'le slot AD-40 de la surface de saisie doit rester INERTE : '
            'sinon un QuillEditor injecté vole le tap des contrôles (R3-I9b)',
      );
    });

    test(
        '🔴 AUCUN `Dismissible`/`onHorizontalDrag` dans le code de prod de su-3 '
        '(le swipe appartient à su-4)', () {
      final decls = declarations(answerInputPath);
      for (final banned in <String>['Dismissible', 'onHorizontalDrag']) {
        expect(
          decls.any((d) => d.contains(banned)),
          isFalse,
          reason: '`$banned` trouvé : su-3 empiète sur su-4 (périmètre volé)',
        );
      }
    });

    test('🔴 AUCUN tap-to-reveal dans le code de prod de su-3 (AC9)', () {
      // La révélation est causée par la SOUMISSION : la surface de saisie ne
      // doit contenir aucune notion de « revealed ».
      final decls = declarations(answerInputPath);
      for (final banned in <String>['onRevealChanged', '_revealed', 'revealed']) {
        expect(
          decls.any((d) => d.contains(banned)),
          isFalse,
          reason: '`$banned` trouvé dans la surface de SAISIE : « répondre » et '
              '« dévoiler » doivent rester mutuellement exclusifs',
        );
      }
    });

    group('🔬 contre-preuve R12 — le scanner de source SAIT rougir (D6)', () {
      // ⚠️ D6 : on exerce le VRAI `declarations` (celui des tests ci-dessus)
      // sur un VRAI fichier — on ne ré-implémente pas le scanner.
      late Directory tmp;
      setUp(() => tmp = Directory.systemTemp.createTempSync('z_arena_probe'));
      tearDown(() => tmp.deleteSync(recursive: true));

      test('un fichier SANS IgnorePointer est bien détecté comme tel', () {
        final f = File('${tmp.path}/probe.dart')
          ..writeAsStringSync('Widget build() => Text("x");');
        expect(
          declarations(f.path).any((d) => d.contains('IgnorePointer(')),
          isFalse,
          reason: 'sans cette contre-preuve, le test de non-régression ci-dessus '
              'pourrait être vert pour de mauvaises raisons',
        );
      });

      test('un `Dismissible` COUPÉ par dart format serait bien capté', () {
        final f = File('${tmp.path}/probe.dart')
          ..writeAsStringSync('final w = Dismissible(\n  key: k,\n);');
        expect(
          declarations(f.path).any((d) => d.contains('Dismissible(key:')),
          isTrue,
          reason: 'le recollage par déclaration doit voir `Dismissible(key:` '
              'même coupé sur deux lignes',
        );
      });
    });
  });
}
