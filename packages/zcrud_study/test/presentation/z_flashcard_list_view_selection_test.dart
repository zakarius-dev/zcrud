// Branchement de la SÉLECTION MULTIPLE sur `ZFlashcardListView` (me-3, FR-SU19 —
// AC1..AC11, AD-44/AD-39/AD-21/AD-10/AD-13/AD-2).
//
// 🔴 LE point dur — purge SRS en cascade FALSIFIABLE (dette d'orphelins lex).
// La preuve suit les 4 étages de la « Stratégie de preuve » de la story :
//   (a) espion PROUVÉ captant AVANT toute assertion « purgé » (témoin) ;
//   (b) compte EXACT sur un lot (les BONS id, aucun survivant) ;
//   (c) R3 rougissant par le COMPORTEMENT : sans la branche purge, un
//       `ZRepetitionInfo` SURVIT (la sonde du (b) rougirait) ;
//   (d) échec partiel RAPPORTÉ (AD-39), les autres racines continuent.
//
// 🔴 Discipline « présence ≠ association » : chaque contrôle est ACTIONNÉ.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ─────────────────────────────── Fakes / espions ────────────────────────────

/// Espion du store SRS : consigne les `deleteByCard` reçus (ordre + id), sème
/// des états, et peut faire échouer la purge d'`id` ciblés (AC6).
class _SpyStore implements ZRepetitionStore {
  _SpyStore({this.failFor = const <String>{}});

  final Set<String> failFor;
  final Map<String, ZRepetitionInfo> _byCard = <String, ZRepetitionInfo>{};

  /// Espion : `id` purgés, DANS L'ORDRE (preuve falsifiable — canal prouvé).
  final List<String> deletedIds = <String>[];

  void seed(String id) =>
      _byCard[id] = const ZSm2Scheduler().initial(flashcardId: id, folderId: 'f');

  bool has(String id) => _byCard.containsKey(id);
  int get srsCount => _byCard.length;

  @override
  Future<ZResult<ZRepetitionInfo?>> getByCard(String flashcardId) async =>
      Right<ZFailure, ZRepetitionInfo?>(_byCard[flashcardId]);

  @override
  Future<ZResult<ZRepetitionInfo>> put(ZRepetitionInfo info) async {
    _byCard[info.flashcardId] = info;
    return Right<ZFailure, ZRepetitionInfo>(info);
  }

  @override
  Future<ZResult<List<ZRepetitionInfo>>> getAll() async =>
      Right<ZFailure, List<ZRepetitionInfo>>(_byCard.values.toList());

  @override
  Future<ZResult<Unit>> sync() async => Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> deleteByCard(String flashcardId) async {
    deletedIds.add(flashcardId);
    if (failFor.contains(flashcardId)) {
      return Left<ZFailure, Unit>(CacheFailure('purge SRS KO "$flashcardId"'));
    }
    _byCard.remove(flashcardId);
    return Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() {}
}

/// Espion de la suppression de carte (seam `deleteCard`) : consigne l'ordre,
/// peut échouer sur des `id` ciblés (short-circuit AD-39).
class _SpyDelete {
  _SpyDelete({this.failFor = const <String>{}});
  final Set<String> failFor;
  final List<String> deletedCards = <String>[];

  Future<ZResult<Unit>> call(String id) async {
    deletedCards.add(id);
    if (failFor.contains(id)) {
      return Left<ZFailure, Unit>(NotFoundFailure('carte KO', id: id));
    }
    return Right<ZFailure, Unit>(unit);
  }
}

// ──────────────────────────────── Harnais widget ────────────────────────────

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Champ de recherche',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',
  readOnlyBadge: 'Lecture seule',
);

const _debounce = Duration(milliseconds: 50);

ZFlashcard _card(String id, {String? question}) =>
    ZFlashcard(id: id, question: question ?? 'Question $id');

String _count(int n) => 'Mode sélection : $n sélectionnée(s)';

Widget _harness(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: Scaffold(
            body: SizedBox(width: 1200, height: 800, child: child),
          ),
        ),
      ),
    );

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // LE POINT DUR — cascade de purge SRS FALSIFIABLE (seam + batchDelete me-1).
  // ═══════════════════════════════════════════════════════════════════════
  group('🔴 AC5 — étage (a) : espion PROUVÉ captant AVANT (témoin)', () {
    test('cascade sur A ⇒ carte supprimée ET SRS de A purgé, id consigné',
        () async {
      final store = _SpyStore()..seed('A');
      final del = _SpyDelete();
      // Sonde AVANT : l'état SRS de A existe (sinon la purge ne prouve rien).
      expect(store.has('A'), isTrue, reason: 'sonde : SRS de A présent AVANT');

      final root = zFlashcardCascadeDeleteRoot(
        deleteCard: del.call,
        repetitionStore: store,
      );
      final res = await root('A');

      expect(res.isRight(), isTrue);
      expect(del.deletedCards, <String>['A'], reason: 'la carte A est supprimée');
      expect(store.deletedIds, <String>['A'],
          reason: '🔴 l\'espion capte le BON canal (deleteByCard(A))');
      expect(store.has('A'), isFalse,
          reason: '🔴 l\'état SRS de A est réellement PURGÉ');
    });
  });

  group('🔴 AC5 — étage (b) : compte EXACT sur un lot (bons id, 0 survivant)', () {
    test('batchDelete de N cartes ⇒ N purges SRS des BONS id, aucun survivant',
        () async {
      final store = _SpyStore()
        ..seed('A')
        ..seed('B')
        ..seed('C');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['A', 'B', 'C']);
      addTearDown(ctl.dispose);

      final report = await ctl.batchDelete(
        deleteRoot: zFlashcardCascadeDeleteRoot(
          deleteCard: del.call,
          repetitionStore: store,
        ),
      );

      expect(store.deletedIds.toSet(), <String>{'A', 'B', 'C'},
          reason: '🔴 EXACTEMENT les N bons id purgés (ni voisins, ni manquants)');
      expect(store.deletedIds, hasLength(3), reason: 'ni doublon, ni oubli');
      expect(del.deletedCards.toSet(), <String>{'A', 'B', 'C'});
      expect(report.succeededCount, 3);
      expect(report.failedCount, 0);
      expect(store.srsCount, 0,
          reason: '🔴 AUCUN ZRepetitionInfo ne survit (dette lex corrigée)');
      expect(ctl.selectedCount, 0,
          reason: 'les racines réussies sont retirées de la sélection');
    });
  });

  group('🔴 AC5 — étage (c) : R3 rougissant PAR LE COMPORTEMENT', () {
    test('SANS la branche purge, un ZRepetitionInfo SURVIT (la sonde (b) rougirait)',
        () async {
      final store = _SpyStore()
        ..seed('A')
        ..seed('B');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['A', 'B']);
      addTearDown(ctl.dispose);

      // 🔴 Seam VOLONTAIREMENT AMPUTÉ de la purge (= le bug lex) : supprime la
      // carte SANS `deleteByCard`. Si le test de l'étage (b) était infalsifiable,
      // il resterait vert ici aussi.
      final report = await ctl.batchDelete(deleteRoot: (id) => del.call(id));

      expect(report.succeededCount, 2, reason: 'les cartes sont supprimées');
      expect(store.deletedIds, isEmpty,
          reason: '🔴 deleteByCard n\'est JAMAIS appelé sans la branche purge');
      expect(store.srsCount, 2,
          reason: '🔴 les 2 ZRepetitionInfo SURVIVENT ⇒ l\'assertion « 0 '
              'survivant » de l\'étage (b) RUGIT bien quand la purge est retirée '
              '(preuve de falsifiabilité — jamais un test tautologique)');
    });
  });

  group('🔴 AC6 — étage (d) : échec partiel RAPPORTÉ, les autres continuent', () {
    test('purge SRS échoue pour K ⇒ K rapporté, A/B purgés (succeeded == N-1)',
        () async {
      final store = _SpyStore(failFor: <String>{'K'})
        ..seed('A')
        ..seed('B')
        ..seed('K');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['A', 'B', 'K']);
      addTearDown(ctl.dispose);

      final report = await ctl.batchDelete(
        deleteRoot: zFlashcardCascadeDeleteRoot(
          deleteCard: del.call,
          repetitionStore: store,
        ),
      );

      expect(report.failedRootIds, <String>{'K'},
          reason: '🔴 K figure dans le rapport avec sa cause (jamais avalé)');
      expect(report.failures['K'], isA<CacheFailure>());
      expect(report.succeededCount, 2, reason: 'A et B réussissent (N-1)');
      expect(store.has('A'), isFalse);
      expect(store.has('B'), isFalse);
      expect(store.has('K'), isTrue,
          reason: '🔴 l\'échec de purge ne prétend pas un succès : K subsiste');
      expect(store.deletedIds.toSet(), <String>{'A', 'B', 'K'},
          reason: 'les autres racines continuent — K n\'arrête pas le lot');
      expect(ctl.isSelected('K'), isTrue,
          reason: 'la racine échouée RESTE sélectionnée (jamais silencieuse)');
    });

    test('suppression carte échoue pour K ⇒ purge SRS de K NON tentée (short-circuit)',
        () async {
      final store = _SpyStore()
        ..seed('A')
        ..seed('K');
      final del = _SpyDelete(failFor: <String>{'K'});
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['A', 'K']);
      addTearDown(ctl.dispose);

      final report = await ctl.batchDelete(
        deleteRoot: zFlashcardCascadeDeleteRoot(
          deleteCard: del.call,
          repetitionStore: store,
        ),
      );

      expect(report.failedRootIds, <String>{'K'});
      expect(report.failures['K'], isA<NotFoundFailure>());
      expect(store.deletedIds, isNot(contains('K')),
          reason: '🔴 short-circuit : la carte K n\'ayant pas été supprimée, on '
              'ne détruit PAS son historique SRS (jamais purger une carte vivante)');
      expect(store.has('K'), isTrue, reason: 'le SRS de K est préservé');
      expect(store.deletedIds, contains('A'));
      expect(store.has('A'), isFalse, reason: 'A supprimé ET purgé');
    });
  });

  group('🔴 AC7 — borne AD-21 par délégation : await par racine, jamais monolithe',
      () {
    test('M racines ⇒ M cascades discrètes awaited (aucun plan monolithique)',
        () async {
      final store = _SpyStore()
        ..seed('A')
        ..seed('B')
        ..seed('C')
        ..seed('D');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['A', 'B', 'C', 'D']);
      addTearDown(ctl.dispose);

      await ctl.batchDelete(
        deleteRoot: zFlashcardCascadeDeleteRoot(
          deleteCard: del.call,
          repetitionStore: store,
        ),
      );

      // M suppressions de carte + M purges = 2·M écritures ≪ 450, chacune
      // dans une cascade DISCRÈTE (le cœur await racine par racine) — me-3
      // n'émet aucun plan > 450.
      expect(del.deletedCards, hasLength(4));
      expect(store.deletedIds, hasLength(4),
          reason: '🔴 chaque racine est une cascade atomique successive');
      // LOW-C — renfort d'ORDRE (au-delà du seul `hasLength`) : `batchDelete`
      // await racine PAR racine dans l'ordre de la sélection (jamais un plan
      // monolithique parallèle réordonné). La preuve stricte de non-parallélisme
      // (un seul await en vol) est couverte côté me-1 (`batchApply`).
      expect(del.deletedCards, <String>['A', 'B', 'C', 'D'],
          reason: '🔴 cartes supprimées DANS L\'ORDRE (await séquentiel)');
      expect(store.deletedIds, <String>['A', 'B', 'C', 'D'],
          reason: '🔴 purges SRS DANS L\'ORDRE (cascade successive, jamais un lot)');
    });
  });

  group('🔴 AC10 — robustesse cascade : sélection VIDE ⇒ no-op, rapport vide', () {
    test('batchDelete sans sélection ⇒ report vide, store intact, aucun throw',
        () async {
      final store = _SpyStore()..seed('A');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple);
      addTearDown(ctl.dispose);

      final report = await ctl.batchDelete(
        deleteRoot: zFlashcardCascadeDeleteRoot(
          deleteCard: del.call,
          repetitionStore: store,
        ),
      );

      expect(report.succeededCount, 0);
      expect(report.failedCount, 0);
      expect(store.deletedIds, isEmpty, reason: 'aucune purge sur sélection vide');
      expect(store.has('A'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // BRANCHEMENT WIDGET (additif) — AC1/AC2/AC3/AC4/AC8/AC9/AC10/AC11.
  // ═══════════════════════════════════════════════════════════════════════

  ZFlashcardListSelection _selection({
    ZListSelectionController? controller,
    Future<ZResult<Unit>> Function(String)? deleteRoot,
    ZFlashcardListBatchMove? move,
    List<ZBatchAction> customActions = const <ZBatchAction>[],
    String? selectAllLabel = 'Tout sélectionner',
    void Function(ZBatchDeletionReport)? onBatchResult,
  }) =>
      ZFlashcardListSelection(
        controller: controller,
        checkboxSemanticLabel: (card, selected) =>
            'Sélectionner ${card.question}',
        countLabelBuilder: _count,
        deleteRoot: deleteRoot,
        deleteActionLabel: 'Supprimer sélection',
        move: move,
        customActions: customActions,
        selectAllLabel: selectAllLabel,
        onBatchResult: onBatchResult,
      );

  group('🔴 AC2 — non-régression su-8 : SANS sélection, zéro case / zéro barre', () {
    testWidgets('selection == null ⇒ aucune Checkbox, aucune barre de lot',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2')],
        labels: _labels,
      )));
      await tester.pump();

      expect(find.byType(Checkbox), findsNothing,
          reason: '🔴 su-8 pur : aucune case à cocher sans câblage');
      expect(find.byKey(ZFlashcardListView.batchBarKey), findsNothing,
          reason: '🔴 su-8 pur : aucune ZBatchActionBar sans câblage');
    });
  });

  group('🔴 AC1 — la liste CONSOMME un contrôleur UNIQUE (cases ET barre)', () {
    testWidgets('« tout sélectionner » coche TOUTES les cases via LE contrôleur',
        (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple);
      addTearDown(ctl.dispose);
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2'), _card('c3')],
        labels: _labels,
        selection: _selection(controller: ctl),
      )));
      await tester.pump();

      expect(find.byType(Checkbox), findsNWidgets(3));

      await tester.tap(find.byTooltip('Tout sélectionner'));
      await tester.pump();

      // Le MÊME contrôleur alimente la barre (selectAll) ET les cases : preuve
      // comportementale d'identité (aucun 2e état de sélection).
      expect(ctl.selectedCount, 3);
      expect(
        tester.widgetList<Checkbox>(find.byType(Checkbox)).every((c) => c.value!),
        isTrue,
        reason: '🔴 toutes les cases reflètent le contrôleur (source unique)',
      );
      expect(find.text(_count(3)), findsOneWidget,
          reason: '🔴 la barre annonce le compteur du MÊME contrôleur');
      // LOW-D — renfort a11y : le compteur n'est pas qu'un pixel de texte, il est
      // ANNONCÉ au lecteur d'écran (le libellé sémantique porte le nombre). Source
      // unique me-1 (`ZBatchActionBar` — un seul canal de compte).
      expect(tester.getSemantics(find.text(_count(3))).label, contains('3'),
          reason: '🔴 le compteur sélectionné est exposé en SÉMANTIQUE (AD-13)');
    });
  });

  group('🔴 AC3 — actions DÉCLARÉES : absente si le seam est null (AD-44)', () {
    testWidgets('deleteRoot null ⇒ « supprimer » ABSENTE ; fourni ⇒ PRÉSENTE',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(),
      )));
      await tester.pump();
      expect(find.byTooltip('Supprimer sélection'), findsNothing,
          reason: '🔴 action absente (jamais grisée) sans seam');

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(deleteRoot: (_) async => Right(unit)),
      )));
      await tester.pump();
      expect(find.byTooltip('Supprimer sélection'), findsOneWidget);
    });

    testWidgets('« déplacer » ABSENTE sans config move, PRÉSENTE avec', (tester) async {
      final move = ZFlashcardListBatchMove(
        attachmentField: 'folder_id',
        label: 'Déplacer',
        resolveDestination: (_) async =>
            const ZFlashcardBatchMoveDestination('dest'),
        moveRoot: (_, __, ___) async => Right(unit),
      );
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(),
      )));
      await tester.pump();
      expect(find.byTooltip('Déplacer'), findsNothing);

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(move: move),
      )));
      await tester.pump();
      expect(find.byTooltip('Déplacer'), findsOneWidget);
    });
  });

  group('🔴 AC3 — « déplacer » : champ PARAMÉTRIQUE + destination INJECTÉE', () {
    testWidgets('destination résolue ⇒ batchMove(attachmentField:) sur le bon champ',
        (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      addTearDown(ctl.dispose);
      final moves = <String>[];
      final move = ZFlashcardListBatchMove(
        attachmentField: 'folder_id',
        label: 'Déplacer',
        resolveDestination: (_) async =>
            const ZFlashcardBatchMoveDestination('dossier-cible'),
        moveRoot: (id, field, dest) async {
          moves.add('$id:$field:$dest');
          return Right(unit);
        },
      );
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(controller: ctl, move: move),
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('Déplacer'));
      await tester.pumpAndSettle();

      expect(moves, <String>['c1:folder_id:dossier-cible'],
          reason: '🔴 champ de rattachement DÉCLARÉ (jamais folder_id en dur) + '
              'destination du sélecteur injecté');
    });

    testWidgets('sélecteur annulé (null) ⇒ AUCUNE écriture (no-op)', (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      addTearDown(ctl.dispose);
      var moveCalls = 0;
      final move = ZFlashcardListBatchMove(
        attachmentField: 'folder_id',
        label: 'Déplacer',
        resolveDestination: (_) async => null, // annulé
        moveRoot: (_, __, ___) async {
          moveCalls++;
          return Right(unit);
        },
      );
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(controller: ctl, move: move),
      )));
      await tester.pump();
      await tester.tap(find.byTooltip('Déplacer'));
      await tester.pumpAndSettle();

      expect(moveCalls, 0, reason: '🔴 annulation ⇒ aucune écriture');
      expect(ctl.selectedCount, 1, reason: 'la sélection est conservée');
    });

    testWidgets('slot custom : action personnalisée PRÉSENTE', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(customActions: <ZBatchAction>[
          ZBatchAction(
            kind: ZBatchActionKind.custom,
            label: 'Exporter',
            icon: Icons.download,
            onSelected: () => tapped = true,
          ),
        ]),
      )));
      await tester.pump();
      expect(find.byTooltip('Exporter'), findsOneWidget);
      await tester.tap(find.byTooltip('Exporter'));
      expect(tapped, isTrue);
    });
  });

  group('🔴 AC4/AC5 — suppression widget : batchDelete + purge + rapport AD-39', () {
    testWidgets('tap « supprimer » ⇒ cartes+SRS purgés, rapport reçu, sélection nettoyée',
        (tester) async {
      final store = _SpyStore()
        ..seed('c1')
        ..seed('c2');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1', 'c2']);
      addTearDown(ctl.dispose);
      ZBatchDeletionReport? received;

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2')],
        labels: _labels,
        selection: _selection(
          controller: ctl,
          deleteRoot: zFlashcardCascadeDeleteRoot(
            deleteCard: del.call,
            repetitionStore: store,
          ),
          onBatchResult: (r) => received = r,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('Supprimer sélection'));
      await tester.pumpAndSettle();

      expect(received, isNotNull, reason: '🔴 l\'appelant reçoit TOUJOURS le rapport');
      expect(received!.succeededRootIds, <String>{'c1', 'c2'});
      expect(received!.failedCount, 0);
      expect(store.srsCount, 0, reason: '🔴 SRS purgé pour les 2 cartes');
      expect(ctl.selectedCount, 0, reason: 'racines réussies retirées');
    });
  });

  group('🔴 AC10 — suppression sous FILTRE actif : aucun id non visible perdu', () {
    testWidgets('sélection d\'ids masqués par la recherche ⇒ tous supprimés',
        (tester) async {
      final store = _SpyStore()
        ..seed('a')
        ..seed('b')
        ..seed('c');
      final del = _SpyDelete();
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['a', 'b', 'c']);
      addTearDown(ctl.dispose);
      ZBatchDeletionReport? received;

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[
          _card('a', question: 'Alpha'),
          _card('b', question: 'Beta'),
          _card('c', question: 'Gamma'),
        ],
        labels: _labels,
        searchDebounce: _debounce,
        selection: _selection(
          controller: ctl,
          deleteRoot: zFlashcardCascadeDeleteRoot(
            deleteCard: del.call,
            repetitionStore: store,
          ),
          onBatchResult: (r) => received = r,
        ),
      )));
      await tester.pump();

      // Filtre : seule « Alpha » reste visible (b, c masqués mais sélectionnés).
      await tester.enterText(find.byKey(ZFlashcardListView.searchFieldKey), 'alph');
      await tester.pump(_debounce);
      await tester.pump();
      expect(find.text('Beta'), findsNothing, reason: 'sonde : b masqué');

      await tester.tap(find.byTooltip('Supprimer sélection'));
      await tester.pumpAndSettle();

      expect(received!.succeededRootIds, <String>{'a', 'b', 'c'},
          reason: '🔴 la sélection keyée par id STABLE ne perd AUCUN id non '
              'visible (jamais un index/position — leçon su-8)');
      expect(store.deletedIds.toSet(), <String>{'a', 'b', 'c'});
    });
  });

  group('🔴 AC8/SM-1 — cocher une carte ne reconstruit QUE sa case (pas les tuiles)',
      () {
    testWidgets('toggle d\'une case ⇒ ZÉRO rebuild de tuile (contentBuilder)',
        (tester) async {
      var tileBuilds = 0;
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple);
      addTearDown(ctl.dispose);
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2'), _card('c3')],
        labels: _labels,
        selection: _selection(controller: ctl),
        contentBuilder: (context, text) {
          tileBuilds++;
          return Text(text);
        },
      )));
      await tester.pump();
      expect(tileBuilds, greaterThan(0), reason: 'sonde : les tuiles ont été construites');
      final before = tileBuilds;

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(ctl.selectedCount, 1, reason: 'exactement une carte cochée');
      expect(tileBuilds - before, 0,
          reason: '🔴 SM-1 : cocher une case ne reconstruit AUCUNE tuile — un '
              'setState à l\'échelle liste rebâtirait les N tuiles (jank n°1)');
    });
  });

  group('🔴 AC9 — a11y : case ≥ 48 dp, Semantics annoncé (AD-13)', () {
    testWidgets('la case a une cible ≥ 48 dp et un libellé sémantique INJECTÉ',
        (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', question: 'Physique')],
        labels: _labels,
        selection: _selection(),
      )));
      await tester.pump();

      final box = tester.getSize(find
          .ancestor(
              of: find.byType(Checkbox).first,
              matching: find.byType(ConstrainedBox))
          .first);
      expect(box.width, greaterThanOrEqualTo(48.0));
      expect(box.height, greaterThanOrEqualTo(48.0));

      final node = tester.getSemantics(find.byType(Checkbox).first);
      expect(node.label, contains('Sélectionner Physique'),
          reason: '🔴 libellé a11y INJECTÉ (jamais codé en dur)');
    });

    testWidgets('RTL : la liste avec sélection rend sans débordement', (tester) async {
      await tester.pumpWidget(_harness(
        ZFlashcardListView(
          cards: <ZFlashcard>[_card('c1'), _card('c2')],
          labels: _labels,
          selection: _selection(deleteRoot: (_) async => Right(unit)),
        ),
        dir: TextDirection.rtl,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });
  });

  group('🔴 AC10 — liste VIDE + mode sélection ⇒ défini, aucun throw', () {
    testWidgets('aucune carte + selection ⇒ message vide, aucun throw', (tester) async {
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: const <ZFlashcard>[],
        labels: _labels,
        selection: _selection(deleteRoot: (_) async => Right(unit)),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(ZFlashcardListView.emptyStateKey), findsOneWidget);
    });
  });

  group('🔴 AC1 — cycle de vie : contrôleur POSSÉDÉ disposé, INJECTÉ préservé', () {
    testWidgets('contrôleur injecté : NON disposé au démontage de la liste',
        (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(controller: ctl),
      )));
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();

      // Un contrôleur injecté NON disposé reste utilisable (aucun throw
      // « used after dispose ») — la liste ne dispose que ce qu'elle possède.
      expect(ctl.selectedCount, 1);
      ctl.toggle('c2');
      expect(ctl.selectedCount, 2);
      ctl.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MED-1 (AD-39) — le rapport de lot est TOUJOURS remonté à l'appelant, même
  // si la liste est DÉMONTÉE pendant l'await : `onBatchResult` est un canal APP
  // (pas un setState) — jamais avalé par une garde `!mounted`.
  // ═══════════════════════════════════════════════════════════════════════
  group('🔴 MED-1 — rapport AD-39 remonté malgré démontage pendant l\'await', () {
    testWidgets('SUPPRIMER : liste démontée pendant deleteRoot lent ⇒ rapport reçu',
        (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      addTearDown(ctl.dispose);
      ZBatchDeletionReport? received;

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(
          controller: ctl,
          // Seam LENT : l'app met du temps à répondre (réseau) — la liste peut
          // se démonter (navigation) AVANT la résolution.
          deleteRoot: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 40));
            return Right<ZFailure, Unit>(unit);
          },
          onBatchResult: (r) => received = r,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('Supprimer sélection'));
      await tester.pump(); // démarre le lot ; on est en await du deleteRoot lent
      // Démonte la liste AVANT que le lot ne se résolve.
      await tester.pumpWidget(_harness(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 80)); // résout le seam lent
      await tester.pumpAndSettle();

      expect(received, isNotNull,
          reason: '🔴 AD-39 : l\'appelant reçoit le rapport MÊME si la liste est '
              'démontée pendant l\'await (onBatchResult = canal app, pas un setState)');
    });

    testWidgets('DÉPLACER : liste démontée pendant moveRoot lent ⇒ rapport reçu',
        (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      addTearDown(ctl.dispose);
      ZBatchDeletionReport? received;
      final move = ZFlashcardListBatchMove(
        attachmentField: 'folder_id',
        label: 'Déplacer',
        resolveDestination: (_) async =>
            const ZFlashcardBatchMoveDestination('dest'),
        moveRoot: (_, __, ___) async {
          await Future<void>.delayed(const Duration(milliseconds: 40));
          return Right<ZFailure, Unit>(unit);
        },
      );

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(
          controller: ctl,
          move: move,
          onBatchResult: (r) => received = r,
        ),
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('Déplacer'));
      await tester.pump(); // resolveDestination résolu ; en await du moveRoot lent
      await tester.pumpWidget(_harness(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(received, isNotNull,
          reason: '🔴 AD-39 : rapport de DÉPLACEMENT remonté malgré démontage');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MED-2 (AD-44) — `_SelectionCheckbox` se RÉCONCILIE au swap de contrôleur :
  // désabonne l'ancien, réabonne le nouveau, resync l'affichage (jamais un
  // listener orphelin ni une case qui affiche A pendant qu'on écrit B).
  // ═══════════════════════════════════════════════════════════════════════
  group('🔴 MED-2 — la case se resync au swap de contrôleur (affichage↔écriture)', () {
    testWidgets('swap A(coché)→B(vide) ⇒ case décochée (reflète B) ET toggle mute B',
        (tester) async {
      final a = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      final b = ZListSelectionController(mode: ZListSelectionMode.multiple);
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(controller: a),
      )));
      await tester.pump();
      // Sonde : la case reflète A (cochée).
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).value,
        isTrue,
        reason: 'sonde : la case reflète A (c1 coché)',
      );

      // Swap du contrôleur : A → B (vide). Le widget de liste est le même type ;
      // la case (State préservé par la clé de tuile stable) reçoit un NOUVEAU
      // contrôleur via didUpdateWidget.
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(controller: b),
      )));
      await tester.pump();

      // (a) l'affichage reflète désormais B (vide) — jamais l'ancien A.
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).value,
        isFalse,
        reason: '🔴 la case DÉSYNC affichait A (cochée) sans didUpdateWidget ; '
            'après resync elle reflète B (décochée)',
      );

      // (b) toggler la case mute B (contrôleur courant), pas A.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(b.isSelected('c1'), isTrue, reason: '🔴 le toggle mute B (courant)');
      expect(a.isSelected('c1'), isTrue,
          reason: 'A est INCHANGÉ (aucune écriture croisée) ; son état d\'origine reste');

      // (c) aucun listener orphelin : muter A ne reconstruit plus la case (sinon
      // elle réafficherait A). On coche c1 sur A puis on vérifie que la case
      // (branchée sur B) reste décochée.
      a.toggle('c1'); // A: c1 repasse à non-sélectionné puis on re-toggle
      a.toggle('c1'); // A: c1 re-sélectionné — si la case écoutait encore A elle bougerait
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox)).value,
        isTrue,
        reason: 'la case suit B (c1 coché en (b)) — muter A ne l\'affecte plus '
            '(listener de A bien désabonné)',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MED-3 (AD-10) — `resolveDestination` qui `throw` ne TRAVERSE PAS la surface :
  // chemin défini (no-op journalisé), jamais un Future non-awaité qui explose.
  // ═══════════════════════════════════════════════════════════════════════
  group('🔴 MED-3 — resolveDestination throw ⇒ enveloppé (aucune traversée AD-10)', () {
    testWidgets('picker KO (throw) ⇒ aucune exception non captée, aucune écriture',
        (tester) async {
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple)
        ..setSelection(<String>['c1']);
      addTearDown(ctl.dispose);
      var moveCalls = 0;
      final move = ZFlashcardListBatchMove(
        attachmentField: 'folder_id',
        label: 'Déplacer',
        resolveDestination: (_) async => throw StateError('picker KO'),
        moveRoot: (_, __, ___) async {
          moveCalls++;
          return Right<ZFailure, Unit>(unit);
        },
      );
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        selection: _selection(controller: ctl, move: move),
      )));
      await tester.pump();

      await tester.tap(find.byTooltip('Déplacer'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: '🔴 AD-10 : un throw du picker est ENVELOPPÉ (jamais une '
              'exception non-awaitée qui traverse la Zone)');
      expect(moveCalls, 0, reason: 'picker KO ⇒ aucune écriture tentée');
      expect(ctl.selectedCount, 1, reason: 'la sélection est conservée (no-op)');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MED-4 (SM-1) — garde de granularité PAR CASE : cocher A ne reconstruit QUE
  // la case de A (delta==1), jamais les N cases. `checkboxSemanticLabel` est
  // invoqué à chaque build de case ⇒ compteur PAR CASE falsifiable.
  // ═══════════════════════════════════════════════════════════════════════
  group('🔴 MED-4/SM-1 — cocher A ne reconstruit QUE la case de A (delta==1)', () {
    testWidgets('toggle d\'UNE case ⇒ un seul rebuild de case (pas les N)',
        (tester) async {
      final builds = <String, int>{};
      final ctl = ZListSelectionController(mode: ZListSelectionMode.multiple);
      addTearDown(ctl.dispose);
      final selection = ZFlashcardListSelection(
        controller: ctl,
        // Le libellé sémantique est (re)construit à CHAQUE build de la case :
        // compteur PAR CASE, sonde de granularité falsifiable (retirer le garde
        // `if (now != _selected)` ferait rebuild TOUTES les cases ⇒ ROUGE).
        checkboxSemanticLabel: (card, selected) {
          final id = card.id ?? '?';
          builds[id] = (builds[id] ?? 0) + 1;
          return 'Sélectionner ${card.question}';
        },
        countLabelBuilder: _count,
      );
      await tester.pumpWidget(_harness(ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2'), _card('c3')],
        labels: _labels,
        selection: selection,
      )));
      await tester.pump();
      expect(builds.keys.toSet(), <String>{'c1', 'c2', 'c3'},
          reason: 'sonde : les 3 cases ont été construites');
      final before = Map<String, int>.from(builds);

      // Coche la case de c1 (la première).
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      expect(ctl.selectedCount, 1, reason: 'exactement une carte cochée');
      expect((builds['c1'] ?? 0) - (before['c1'] ?? 0), 1,
          reason: '🔴 la case de c1 se reconstruit EXACTEMENT une fois');
      expect((builds['c2'] ?? 0) - (before['c2'] ?? 0), 0,
          reason: '🔴 SM-1 : la case de c2 NE se reconstruit PAS (garde par case)');
      expect((builds['c3'] ?? 0) - (before['c3'] ?? 0), 0,
          reason: '🔴 SM-1 : la case de c3 NE se reconstruit PAS (garde par case)');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // MED-5 (a11y) — le libellé de « supprimer » est REQUIS dès que le seam
  // `deleteRoot` l'est (assert constructeur, miroir me-1) : jamais un bouton de
  // suppression de lot MUET pour un lecteur d'écran (récidive su-9).
  // ═══════════════════════════════════════════════════════════════════════
  group('🔴 MED-5 — deleteActionLabel REQUIS dès que deleteRoot est fourni', () {
    test('deleteRoot fourni + deleteActionLabel null ⇒ AssertionError', () {
      expect(
        () => ZFlashcardListSelection(
          checkboxSemanticLabel: (card, selected) => 'x',
          countLabelBuilder: _count,
          deleteRoot: (_) async => Right<ZFailure, Unit>(unit),
          deleteActionLabel: null,
        ),
        throwsAssertionError,
        reason: '🔴 un seam de suppression SANS libellé d\'action rendrait le '
            'bouton MUET (récidive su-9) — l\'assert le proscrit à la construction',
      );
    });

    test('deleteRoot null + deleteActionLabel null ⇒ OK (action absente, pas de bouton)',
        () {
      expect(
        () => ZFlashcardListSelection(
          checkboxSemanticLabel: (card, selected) => 'x',
          countLabelBuilder: _count,
        ),
        returnsNormally,
        reason: 'sans seam, aucune action « supprimer » ⇒ le label est inutile',
      );
    });
  });
}
