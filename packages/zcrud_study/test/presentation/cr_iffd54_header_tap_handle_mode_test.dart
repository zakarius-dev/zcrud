/// **CR-IFFD-54** — le repli et le réordonnancement : deux gestes que l'hôte
/// peut désormais régler.
///
/// ① `collapseOnHeaderTap` (spec) — TOUTE la ligne d'en-tête devient zone de
///   bascule (défaut inchangé : chevron seul). Gardes : la PRIORITÉ tactile
///   mesurée combinaison par combinaison (titre ⇒ bascule ; action/ajout ⇒
///   JAMAIS de bascule ; chevron ⇒ UNE bascule, pas deux), y compris sous
///   `studySectionCollapsePlacement.inHeaderRow` et en RTL ; UNE seule annonce
///   sémantique (l'arbre sémantique interactif est INCHANGÉ par le mode) ;
///   SM-1 par comptage de builds ; AD-4 (zone absente par défaut).
///
/// ② `reorderHandleMode` (spec) — poignée `{visible (défaut), masquée avec
///   appui long}`, sémantique conservée dans les DEUX modes. Gardes : le mode
///   masqué RÉORDONNE par drag réel (géométrie avant/après) ; les actions
///   sémantiques RÉPONDENT encore poignée masquée (prouvé, pas affirmé) ; le
///   conflit MESURÉ carte-qui-consomme-l'appui-long × mode masqué est REFUSÉ à
///   la construction ; l'arbitrage actuel du mode visible (carte ⇒ callback
///   carte, poignée ⇒ drag) est encodé en garde de régression.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZcrudScope, ZcrudTheme, ZStudySectionCollapsePlacement;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'cr_iffd48_parity_guard_test.dart' show zNamedCtorParams;

ZFlashcard _card(int i) => ZFlashcard(
      id: 'c$i',
      question: 'Question numéro $i',
      type: ZFlashcardType.openQuestion,
    );

Future<void> _pump(
  WidgetTester tester,
  List<ZStudyToolsSectionSpec> sections, {
  ZcrudTheme? theme,
  TextDirection direction = TextDirection.ltr,
}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: theme == null
                ? ZSectionedStudyLayout(sections: sections)
                : ZcrudScope(
                    theme: theme,
                    child: ZSectionedStudyLayout(sections: sections),
                  ),
          ),
        ),
      ),
    );

/// Section repliable à ligne-bascule, corps sentinelle `BODY-<id>`.
ZStudyToolsSectionSpec _toggleSection({
  String id = 's1',
  bool collapseOnHeaderTap = true,
  VoidCallback? secondaryAction,
  String? secondaryActionLabel,
  VoidCallback? addAction,
  void Function(int calls)? onItemBuild,
}) {
  var builds = 0;
  return ZStudyToolsSectionSpec(
    id: id,
    title: 'Titre $id',
    itemCount: 1,
    itemBuilder: (context, index) {
      builds++;
      onItemBuild?.call(builds);
      return Text('BODY-$id');
    },
    emptyState: const SizedBox.shrink(),
    collapsible: true,
    collapseOnHeaderTap: collapseOnHeaderTap,
    collapseSemanticLabel: 'Replier-X',
    expandSemanticLabel: 'Déplier-X',
    secondaryAction: secondaryAction,
    secondaryActionIcon: Icons.arrow_forward,
    secondaryActionLabel: secondaryActionLabel,
    secondaryActionSemanticLabel: 'Afficher tout $id',
    addAction: addAction,
    addActionIcon: Icons.add_circle_outline,
    addActionSemanticLabel: 'Ajouter $id',
  );
}

bool _bodyVisible(WidgetTester tester, String id) =>
    find.text('BODY-$id').evaluate().isNotEmpty;

/// Tous les nœuds sémantiques (parcours préfixe, ordre des enfants).
List<SemanticsNode> _allNodes(WidgetTester tester) {
  final List<SemanticsNode> nodes = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    nodes.add(node);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  // ignore: deprecated_member_use — même sonde que cr_iffd15 (W3).
  visit(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
  return nodes;
}

/// Nombre de nœuds sémantiques portant l'action TAP (surface interactive).
int _tapNodeCount(WidgetTester tester) => _allNodes(tester)
    .where((SemanticsNode n) =>
        n.getSemanticsData().hasAction(SemanticsAction.tap))
    .length;

void main() {
  // ════════════════════════════════ ① — la ligne d'en-tête zone de bascule ═
  group('CR-IFFD-54 ① — priorité tactile (placement historique, belowTitle)',
      () {
    testWidgets('🔴 tap sur le TITRE bascule ; tap sur l\'ACTION secondaire '
        'déclenche l\'action et ne replie JAMAIS ; tap sur AJOUT idem',
        (tester) async {
      var secondaryTaps = 0;
      var addTaps = 0;
      await _pump(tester, <ZStudyToolsSectionSpec>[
        _toggleSection(
          secondaryAction: () => secondaryTaps++,
          addAction: () => addTaps++,
        ),
      ]);
      expect(_bodyVisible(tester, 's1'), isTrue);

      // Titre ⇒ bascule (replie).
      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isFalse,
          reason: '🔴 le tap sur le TITRE doit replier la section '
              '(collapseOnHeaderTap)');

      // Titre ⇒ bascule (redéplie).
      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isTrue);

      // Action secondaire ⇒ l'ACTION, jamais la bascule (contrôle interne
      // gagne l'arène).
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(secondaryTaps, 1);
      expect(_bodyVisible(tester, 's1'), isTrue,
          reason: '🔴 un tap sur « Afficher tout » ne doit JAMAIS replier');

      // Ajout ⇒ l'action d'ajout, jamais la bascule.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pumpAndSettle();
      expect(addTaps, 1);
      expect(_bodyVisible(tester, 's1'), isTrue,
          reason: '🔴 un tap sur l\'ajout ne doit JAMAIS replier');

      // Badge compteur (non interactif) : appartient à la ligne ⇒ bascule.
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isFalse,
          reason: 'le badge fait partie de la ligne-bascule');
    });

    testWidgets('🔴 tap sur le CHEVRON bascule UNE fois exactement (jamais '
        'chevron + ligne)', (tester) async {
      await _pump(tester, <ZStudyToolsSectionSpec>[_toggleSection()]);
      expect(_bodyVisible(tester, 's1'), isTrue);
      // Si le chevron ET la ligne gagnaient tous deux, l'état basculerait deux
      // fois et le corps resterait VISIBLE.
      await tester.tap(find.byKey(const ValueKey<String>('section:s1:collapse')));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isFalse,
          reason: '🔴 double bascule détectée : le chevron et la ligne ont '
              'tous deux répondu au même tap');
    });

    testWidgets('RTL — titre ⇒ bascule, action ⇒ jamais de bascule',
        (tester) async {
      var secondaryTaps = 0;
      await _pump(
        tester,
        <ZStudyToolsSectionSpec>[
          _toggleSection(secondaryAction: () => secondaryTaps++),
        ],
        direction: TextDirection.rtl,
      );
      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isFalse);
      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await tester.pumpAndSettle();
      expect(secondaryTaps, 1);
      expect(_bodyVisible(tester, 's1'), isTrue);
    });
  });

  group('CR-IFFD-54 ① — sous `inHeaderRow` (CR-50 ④, livré v0.44.0)', () {
    final ZcrudTheme inHeaderRow = ZcrudTheme(
      studySectionCollapsePlacement: ZStudySectionCollapsePlacement.inHeaderRow,
    );

    testWidgets('🔴 titre ⇒ bascule ; action à LIBELLÉ VISIBLE ⇒ jamais de '
        'bascule ; chevron en ligne ⇒ UNE bascule', (tester) async {
      var secondaryTaps = 0;
      await _pump(
        tester,
        <ZStudyToolsSectionSpec>[
          _toggleSection(
            secondaryAction: () => secondaryTaps++,
            secondaryActionLabel: 'Afficher tout',
          ),
        ],
        theme: inHeaderRow,
      );
      // Le chevron est bien DANS la ligne (placement CR-50 ④ respecté).
      expect(find.byKey(const ValueKey<String>('section:s1:collapse')),
          findsOneWidget);

      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isFalse);
      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isTrue);

      // TextButton.icon (variante à libellé visible, CR-50 ③) : l'action
      // gagne, la ligne ne replie pas.
      await tester.tap(find.text('Afficher tout'));
      await tester.pumpAndSettle();
      expect(secondaryTaps, 1);
      expect(_bodyVisible(tester, 's1'), isTrue,
          reason: '🔴 un tap sur « Afficher tout » (libellé visible) ne doit '
              'JAMAIS replier — même sous inHeaderRow');

      // Chevron en ligne : UNE bascule exactement.
      await tester.tap(find.byKey(const ValueKey<String>('section:s1:collapse')));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isFalse);
    });
  });

  group('CR-IFFD-54 ① — sémantique et AD-4', () {
    testWidgets('🔴 UNE seule annonce : le mode n\'ajoute AUCUN nœud '
        'interactif — l\'arbre sémantique tap est IDENTIQUE avec et sans la '
        'ligne-bascule', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, <ZStudyToolsSectionSpec>[
        _toggleSection(collapseOnHeaderTap: false, secondaryAction: () {}),
      ]);
      final int tapNodesWithout = _tapNodeCount(tester);
      // L'annonce de bascule existe et est UNIQUE (portée par le chevron,
      // libellés injectés — recherche par label, en ancêtre comme en nœud).
      expect(
        _allNodes(tester)
            .where((SemanticsNode n) =>
                n.getSemanticsData().label.contains('Replier-X'))
            .length,
        1,
      );

      await _pump(tester, <ZStudyToolsSectionSpec>[
        _toggleSection(secondaryAction: () {}),
      ]);
      expect(_tapNodeCount(tester), tapNodesWithout,
          reason: '🔴 la ligne-bascule doit être EXCLUE de la sémantique '
              '(extension de cible pointeur) : l\'annonce de bascule reste '
              'portée par le SEUL chevron — jamais deux annonces (v0.36.0)');
      expect(
        _allNodes(tester)
            .where((SemanticsNode n) =>
                n.getSemanticsData().label.contains('Replier-X'))
            .length,
        1,
        reason: '🔴 une seule annonce de bascule, mode actif compris',
      );
      handle.dispose();
    });

    testWidgets('AD-4 — défaut : la zone de bascule est ABSENTE de l\'arbre '
        'et le titre ne bascule PAS', (tester) async {
      await _pump(tester, <ZStudyToolsSectionSpec>[
        _toggleSection(collapseOnHeaderTap: false),
      ]);
      expect(
        find.byKey(const ValueKey<String>('section:s1:headerToggle')),
        findsNothing,
        reason: 'AD-4 : capacité non demandée = absente structurellement',
      );
      await tester.tap(find.text('Titre s1'));
      await tester.pumpAndSettle();
      expect(_bodyVisible(tester, 's1'), isTrue,
          reason: 'défaut inchangé : seul le chevron bascule');
    });

    test('🔴 collapseOnHeaderTap sans collapsible ⇒ REFUS (réglage inerte, '
        'AD-4)', () {
      expect(
        () => ZStudyToolsSectionSpec(
          id: 's1',
          title: 'T',
          itemCount: 0,
          itemBuilder: (_, _) => const SizedBox.shrink(),
          emptyState: const SizedBox.shrink(),
          collapseOnHeaderTap: true,
        ),
        throwsA(isA<AssertionError>().having(
          (AssertionError e) => e.message.toString(),
          'message',
          contains('collapsible'),
        )),
      );
    });
  });

  group('CR-IFFD-54 ① — SM-1 (comptage de builds)', () {
    testWidgets('🔴 replier/déplier par la LIGNE ne reconstruit NI les items '
        'de la section voisine NI les siens', (tester) async {
      var buildsA = 0;
      var buildsB = 0;
      await _pump(tester, <ZStudyToolsSectionSpec>[
        _toggleSection(id: 'a', onItemBuild: (_) => buildsA++),
        _toggleSection(id: 'b', onItemBuild: (_) => buildsB++),
      ]);
      final int baselineA = buildsA;
      final int baselineB = buildsB;
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('Titre a'));
        await tester.pumpAndSettle();
      }
      expect(buildsB, baselineB,
          reason: '🔴 SM-1 : basculer la section A par sa ligne ne doit '
              'reconstruire AUCUN item de la section B');
      expect(buildsA, baselineA,
          reason: 'le corps est PRÉ-CONSTRUIT (instance restituée) : la '
              'bascule ne ré-invoque pas itemBuilder');
      // La bascule a bien eu lieu (nombre pair ⇒ état final déplié).
      expect(_bodyVisible(tester, 'a'), isTrue);
    });
  });

  // ═══════════════════════════════════════════ ② — mode de la poignée ═
  group('CR-IFFD-54 ② — liste, mode masqué : le geste', () {
    testWidgets('🔴 poignée ABSENTE (AD-4) et l\'appui long sur l\'ITEM '
        'réordonne RÉELLEMENT (géométrie avant/après + indices)',
        (tester) async {
      final List<List<int>> moves = <List<int>>[];
      await _pump(tester, <ZStudyToolsSectionSpec>[
        ZStudyToolsSectionSpec.flashcards(
          id: 'cards',
          title: 'Cartes',
          cards: <ZFlashcard>[for (var i = 0; i < 3; i++) _card(i)],
          emptyState: const Text('vide'),
          onReorder: (int o, int n) => moves.add(<int>[o, n]),
          reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
        ),
      ]);
      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byIcon(Icons.drag_handle), findsNothing,
          reason: '🔴 mode masqué : la poignée doit être ABSENTE de l\'arbre');

      double dy(String text) =>
          tester.getTopLeft(find.text(text, findRichText: true)).dy;
      expect(dy('Question numéro 0'), lessThan(dy('Question numéro 1')));

      // Drag RÉEL par APPUI LONG sur la carte 0 (patron cr_iffd52 : la carte
      // saisie est celle qui bouge).
      final TestGesture gesture = await tester
          .startGesture(
              tester.getCenter(find.text('Question numéro 0', findRichText: true)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 160));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(moves, hasLength(1));
      expect(moves.single[0], 0, reason: 'c\'est la carte 0 qui a été saisie');
      expect(dy('Question numéro 0'), greaterThan(dy('Question numéro 1')),
          reason: '🔴 l\'appui long doit déplacer la carte SAISIE');
    });

    testWidgets('défaut inchangé : mode omis ⇒ poignée visible', (tester) async {
      await _pump(tester, <ZStudyToolsSectionSpec>[
        ZStudyToolsSectionSpec.flashcards(
          id: 'cards',
          title: 'Cartes',
          cards: <ZFlashcard>[for (var i = 0; i < 3; i++) _card(i)],
          emptyState: const Text('vide'),
          onReorder: (int o, int n) {},
        ),
      ]);
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
    });
  });

  group('CR-IFFD-54 ② — liste, mode masqué : la sémantique CONSERVÉE', () {
    testWidgets('🔴 poignée masquée, les actions sémantiques du SDK RÉPONDENT '
        'encore (déplacement réel via customAction, sans aucun appui long)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final List<List<int>> moves = <List<int>>[];
      await _pump(tester, <ZStudyToolsSectionSpec>[
        ZStudyToolsSectionSpec.flashcards(
          id: 'cards',
          title: 'Cartes',
          cards: <ZFlashcard>[for (var i = 0; i < 3; i++) _card(i)],
          emptyState: const Text('vide'),
          onReorder: (int o, int n) => moves.add(<int>[o, n]),
          reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
        ),
      ]);
      // Libellé SDK (WidgetsLocalizations) — jamais codé en dur ici : lu à la
      // même source que `SliverReorderableList._wrapWithSemantics`.
      final String moveDownLabel =
          const DefaultWidgetsLocalizations().reorderItemDown;
      final int moveDownId = CustomSemanticsAction.getIdentifier(
          CustomSemanticsAction(label: moveDownLabel));
      // Recherche en ANCÊTRE/arbre entier (piège documenté : chercher en
      // descendant du texte rate le nœud porteur).
      final List<SemanticsNode> carriers = _allNodes(tester)
          .where((SemanticsNode n) =>
              (n.getSemanticsData().customSemanticsActionIds ?? const <int>[])
                  .contains(moveDownId))
          .toList();
      expect(carriers, isNotEmpty,
          reason: '🔴 mode masqué : l\'action « $moveDownLabel » doit rester '
              'atteignable au lecteur d\'écran (sémantique conservée, CR-54 ②)');

      double dy(String text) =>
          tester.getTopLeft(find.text(text, findRichText: true)).dy;
      expect(dy('Question numéro 0'), lessThan(dy('Question numéro 1')));
      // Premier porteur en ordre préfixe = item 0 — VALIDÉ par l'effet mesuré
      // ci-dessous (indices notifiés + géométrie), pas supposé.
      // ignore: deprecated_member_use — même sonde que cr_iffd15 (W3).
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        carriers.first.id,
        SemanticsAction.customAction,
        moveDownId,
      );
      await tester.pumpAndSettle();
      expect(moves, <List<int>>[
        <int>[0, 1],
      ]);
      expect(dy('Question numéro 0'), greaterThan(dy('Question numéro 1')),
          reason: '🔴 l\'action sémantique doit RÉORDONNER réellement');
      handle.dispose();
    });
  });

  group('CR-IFFD-54 ② — grille, mode masqué', () {
    testWidgets('🔴 aucune poignée ; l\'appui long sur la CELLULE réordonne ; '
        'les actions « déplacer avant/après » (libellés INJECTÉS) répondent',
        (tester) async {
      final handle = tester.ensureSemantics();
      final List<List<int>> moves = <List<int>>[];
      await _pump(tester, <ZStudyToolsSectionSpec>[
        ZStudyToolsSectionSpec.flashcards(
          id: 'cards',
          title: 'Cartes',
          cards: <ZFlashcard>[for (var i = 0; i < 4; i++) _card(i)],
          emptyState: const Text('vide'),
          onReorder: (int o, int n) => moves.add(<int>[o, n]),
          crossAxisMinItemWidth: 200,
          reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
          reorderMoveBeforeSemanticLabel: 'AVANT-XYZ',
          reorderMoveAfterSemanticLabel: 'APRES-XYZ',
        ),
      ]);
      expect(find.byIcon(Icons.drag_handle), findsNothing,
          reason: '🔴 mode masqué : aucune décoration de poignée en amont du '
              'renderer (AD-4)');

      // Geste : appui long sur la CELLULE (renderer par défaut) — réel.
      final TestGesture gesture = await tester
          .startGesture(
              tester.getCenter(find.text('Question numéro 0', findRichText: true)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, 250));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(moves, isNotEmpty,
          reason: '🔴 l\'appui long sur la cellule doit réordonner (renderer '
              'par défaut)');

      // Sémantique conservée : l'action injectée répond (recherche en arbre).
      moves.clear();
      final int beforeId = CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'AVANT-XYZ'));
      final List<SemanticsNode> carriers = _allNodes(tester)
          .where((SemanticsNode n) =>
              (n.getSemanticsData().customSemanticsActionIds ?? const <int>[])
                  .contains(beforeId))
          .toList();
      expect(carriers, isNotEmpty,
          reason: '🔴 les actions sémantiques de la grille doivent survivre au '
              'masquage de la poignée (elles n\'ont jamais vécu dedans)');
      // ignore: deprecated_member_use — même sonde que cr_iffd15 (W3).
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        carriers.first.id,
        SemanticsAction.customAction,
        beforeId,
      );
      await tester.pumpAndSettle();
      expect(moves, hasLength(1));
      handle.dispose();
    });
  });

  group('CR-IFFD-54 ② — le conflit de geste MESURÉ (le piège du lot)', () {
    testWidgets('GARDE DE RÉGRESSION de l\'arbitrage VISIBLE : la carte qui '
        'consomme l\'appui long GAGNE sur la cellule (0 move) ; la POIGNÉE '
        'reste le déclencheur qui échappe à la carte', (tester) async {
      final List<List<int>> moves = <List<int>>[];
      final List<String> longPressed = <String>[];
      await _pump(tester, <ZStudyToolsSectionSpec>[
        ZStudyToolsSectionSpec.flashcards(
          id: 'cards',
          title: 'Cartes',
          cards: <ZFlashcard>[for (var i = 0; i < 4; i++) _card(i)],
          emptyState: const Text('vide'),
          onReorder: (int o, int n) => moves.add(<int>[o, n]),
          crossAxisMinItemWidth: 200,
          onCardLongPress: (ZFlashcard c) => longPressed.add(c.id!),
        ),
      ]);
      // (a) Appui long + mouvement sur la CARTE : l'InkWell de la carte gagne
      // l'arène — le drag ne démarre JAMAIS (mesure fondatrice du refus
      // hiddenLongPress × onCardLongPress).
      final TestGesture g1 = await tester
          .startGesture(
              tester.getCenter(find.text('Question numéro 0', findRichText: true)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g1.moveBy(const Offset(0, 250));
      await tester.pump();
      await g1.up();
      await tester.pumpAndSettle();
      expect(moves, isEmpty,
          reason: 'MESURÉ : la carte consomme l\'appui long, le drag ne '
              'démarre pas depuis la cellule');
      expect(longPressed, <String>['c0']);

      // (b) Depuis la POIGNÉE (hors de l'InkWell de la carte) : le drag passe.
      longPressed.clear();
      final TestGesture g2 = await tester
          .startGesture(tester.getCenter(find.byIcon(Icons.drag_handle).first));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await g2.moveBy(const Offset(0, 250));
      await tester.pump();
      await g2.up();
      await tester.pumpAndSettle();
      expect(moves, isNotEmpty,
          reason: '🔴 en mode visible, la poignée doit RESTER un déclencheur '
              'qui échappe à l\'appui long de la carte');
      expect(longPressed, isEmpty);
    });

    test('🔴 hiddenLongPress + onCardLongPress + onReorder ⇒ REFUS à la '
        'construction (il ne resterait AUCUN déclencheur tactile)', () {
      expect(
        () => ZStudyToolsSectionSpec.flashcards(
          id: 'cards',
          title: 'Cartes',
          cards: <ZFlashcard>[_card(0)],
          emptyState: const SizedBox.shrink(),
          onReorder: (int o, int n) {},
          onCardLongPress: (ZFlashcard c) {},
          reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
        ),
        throwsA(isA<AssertionError>().having(
          (AssertionError e) => e.message.toString(),
          'message',
          allOf(contains('INCOMPATIBLE'), contains('onCardLongPress')),
        )),
      );
    });

    test('hiddenLongPress SANS onReorder ⇒ refus (réglage inerte, AD-4) — '
        'constructeur principal ET voie typée', () {
      expect(
        () => ZStudyToolsSectionSpec(
          id: 's',
          title: 'T',
          itemCount: 0,
          itemBuilder: (_, _) => const SizedBox.shrink(),
          emptyState: const SizedBox.shrink(),
          reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ZStudyToolsSectionSpec.flashcards(
          id: 's',
          title: 'T',
          cards: <ZFlashcard>[_card(0)],
          emptyState: const SizedBox.shrink(),
          reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('carte SANS appui long + mode masqué : accepté (aucun conflit)', () {
      final ZStudyToolsSectionSpec spec = ZStudyToolsSectionSpec.flashcards(
        id: 's',
        title: 'T',
        cards: <ZFlashcard>[_card(0)],
        emptyState: const SizedBox.shrink(),
        onReorder: (int o, int n) {},
        onCardTap: (ZFlashcard c) {},
        reorderHandleMode: ZStudyReorderHandleMode.hiddenLongPress,
      );
      expect(spec.reorderHandleMode, ZStudyReorderHandleMode.hiddenLongPress);
    });
  });

  // ══════════════════════════════════════ garde de SOURCE (voies typées) ═
  group('CR-IFFD-54 — garde de source', () {
    test('les trois voies typées exposent `reorderHandleMode` ET '
        '`collapseOnHeaderTap`', () {
      Directory dir = Directory.current.absolute;
      for (int i = 0; i < 8; i++) {
        if (File('${dir.path}/melos.yaml').existsSync()) break;
        dir = dir.parent;
      }
      final String src = File(
              '${dir.path}/packages/zcrud_study/lib/src/presentation/'
              'z_study_tools_section_spec.dart')
          .readAsStringSync();
      for (final String header in <String>[
        'ZStudyToolsSectionSpec.flashcards({',
        'ZStudyToolsSectionSpec.mindmaps({',
        'ZStudyToolsSectionSpec.exams({',
      ]) {
        final List<String>? params = zNamedCtorParams(src, header);
        expect(params, isNotNull, reason: 'sonde cassée : $header');
        expect(params, contains('reorderHandleMode'),
            reason: '🔴 PARITÉ ROMPUE : `reorderHandleMode` absent de '
                '`$header` (CR-IFFD-54 ②)');
        expect(params, contains('collapseOnHeaderTap'),
            reason: '🔴 PARITÉ ROMPUE : `collapseOnHeaderTap` absent de '
                '`$header` (CR-IFFD-54 ①)');
      }
    });
  });
}
