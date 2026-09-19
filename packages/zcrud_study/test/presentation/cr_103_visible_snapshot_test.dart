import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Recherche',
  emptyState: 'Vide',
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
);

final _cards = [
  ZFlashcard(id: 'b', question: 'Beta', answer: 'Réponse banane'),
  ZFlashcard(id: 'a', question: 'Alpha', answer: 'Réponse pomme'),
];

Widget _app({
  required ValueChanged<ZFlashcardVisibleSnapshot>? onVisible,
  List<ZFlashcard>? cards,
  ZFlashcardSortMode sort = ZFlashcardSortMode.title,
  String query = '',
  ZFolderContentsOrder? order,
}) => MaterialApp(
  home: Scaffold(
    body: ZFlashcardListView(
      cards: cards ?? _cards,
      labels: _labels,
      itemStyle: ZFlashcardListItemStyle.tile,
      sortMode: sort,
      filters: ZFlashcardBrowseFilters(query: query),
      order: order,
      onVisibleChanged: onVisible,
    ),
  ),
);

void main() {
  testWidgets('ordre personnel identique dans snapshot et rendu', (
    tester,
  ) async {
    final seen = <ZFlashcardVisibleSnapshot>[];
    await tester.pumpWidget(
      _app(
        onVisible: seen.add,
        sort: ZFlashcardSortMode.manual,
        order: ZFolderContentsOrder(
          folderId: 'f',
          sectionOrders: const {
            'flashcards': ['a', 'b'],
          },
        ),
      ),
    );
    expect(seen.single.ids, ['a', 'b']);
    final alpha = tester.getTopLeft(find.text('Alpha'));
    final beta = tester.getTopLeft(find.text('Beta'));
    expect(
      alpha.dy < beta.dy || (alpha.dy == beta.dy && alpha.dx < beta.dx),
      isTrue,
    );
  });

  testWidgets('résultat initial trié, puis recherche débouncée et vide', (
    tester,
  ) async {
    final seen = <ZFlashcardVisibleSnapshot>[];
    await tester.pumpWidget(_app(onVisible: seen.add));
    expect(seen.single.ids, ['a', 'b']);
    expect(seen.single.sortMode, ZFlashcardSortMode.title);
    expect(() => seen.single.cards.clear(), throwsUnsupportedError);
    expect(() => seen.single.ids.clear(), throwsUnsupportedError);
    final search = find.byKey(ZFlashcardListView.searchFieldKey);
    await tester.enterText(search, 'banane');
    await tester.pump(const Duration(milliseconds: 299));
    expect(seen, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1));
    expect(seen.last.query, 'banane');
    expect(seen.last.ids, ['b']);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
    await tester.enterText(search, 'introuvable');
    await tester.pump(const Duration(milliseconds: 300));
    expect(seen.last.cards, isEmpty);
    expect(find.text('Aucun résultat'), findsOneWidget);
  });

  testWidgets('props vivantes : requête restaurée, tri et contenu mêmes ids', (
    tester,
  ) async {
    final seen = <ZFlashcardVisibleSnapshot>[];
    await tester.pumpWidget(_app(onVisible: seen.add));
    await tester.pumpWidget(
      _app(onVisible: seen.add, sort: ZFlashcardSortMode.manual),
    );
    expect(seen.last.ids, ['b', 'a']);
    expect(seen.last.sortMode, ZFlashcardSortMode.manual);
    await tester.pumpWidget(_app(onVisible: seen.add, query: 'pomme'));
    expect(seen.last.ids, ['a']);
    expect(seen.last.query, 'pomme');
    await tester.pumpWidget(
      _app(
        onVisible: seen.add,
        query: 'pomme',
        cards: [
          ZFlashcard(id: 'a', question: 'Alpha modifié', answer: 'pomme'),
        ],
      ),
    );
    expect(seen.last.cards.single.question, 'Alpha modifié');
    expect(seen, hasLength(4));
  });

  testWidgets('callback parent setState et closure recréée ne bouclent pas', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setParentState) => Column(
              children: [
                Text('Compteur $calls'),
                Expanded(
                  child: ZFlashcardListView(
                    cards: [for (final c in _cards) c.copyWith()],
                    labels: _labels,
                    onVisibleChanged: (snapshot) =>
                        setParentState(() => calls++),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(calls, 1);
    expect(find.text('Compteur 1'), findsOneWidget);
  });

  testWidgets(
    'callback réactivé reçoit le résultat courant et retrait est inerte',
    (tester) async {
      final seen = <ZFlashcardVisibleSnapshot>[];
      await tester.pumpWidget(_app(onVisible: null, query: 'Alpha'));
      await tester.pumpWidget(_app(onVisible: seen.add, query: 'Alpha'));
      expect(seen.single.ids, ['a']);
      await tester.pumpWidget(_app(onVisible: null, query: 'Beta'));
      await tester.pumpAndSettle();
      expect(seen, hasLength(1));
      await tester.pumpWidget(_app(onVisible: seen.add, query: 'Beta'));
      expect(seen.last.ids, ['b']);
      expect(seen, hasLength(2));
    },
  );

  testWidgets('démontage annule la recherche en attente', (tester) async {
    final seen = <ZFlashcardVisibleSnapshot>[];
    await tester.pumpWidget(_app(onVisible: seen.add));
    await tester.enterText(
      find.byKey(ZFlashcardListView.searchFieldKey),
      'Beta',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
    expect(seen, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  test('snapshot détache la liste et conserve les cartes sans identifiant', () {
    final cards = [ZFlashcard(question: 'Éphémère'), ..._cards];
    final snapshot = ZFlashcardVisibleSnapshot(
      query: '',
      sortMode: ZFlashcardSortMode.manual,
      cards: cards,
    );
    cards.clear();
    expect(snapshot.cards, hasLength(3));
    expect(snapshot.ids, ['b', 'a']);
  });
}
