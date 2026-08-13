// Tuile TYPÉE des layouts à tuiles : la carte reçoit l'ENTITÉ résolue
// (`ZEntityTileBuilder`), pas la seule `ZListRow`. Le seam `entityFor`, déjà
// déclaré pour les actions de ligne, sert aussi au rendu.
//
// Gardes :
// 1. `ZListGridLayout` + tuile typée ⇒ le builder reçoit l'ENTITÉ (non nulle) ;
// 2. `ZListBuilderLayout` + tuile typée ⇒ même chose (tout layout à tuiles) ;
// 3. égalité de valeur : deux rendus aux `entityFor` DIFFÉRENTS produisent des
//    `ZListRenderRequest` ÉGAUX (la mémoïsation du rendu ne casse pas) ;
// 4. contre-témoin : sans tuile typée, le rendu par ligne est inchangé ;
// 5. entité ÉPHÉMÈRE (`id == null`) résolue par la clé publique
//    `ZListRow.keyOf` ;
// 6. précédence : un layout portant déjà sa propre tuile la GARDE
//    (`withEntityTiles` retourne `this`) ;
// 7. repli : tuile typée déclarée mais entité introuvable ⇒ retour à la tuile
//    de ligne, jamais d'exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Entité métier de test : ce que la carte veut afficher (`label`) n'est PAS
/// dans les cellules de la ligne — une tuile qui n'a que la `ZListRow` ne peut
/// donc pas le rendre.
class _Person extends ZEntity {
  const _Person({this.id, required this.name, required this.badge});

  @override
  final String? id;
  final String name;
  final String badge;

  String get label => '$name#$badge';
}

/// Renderer factice capturant la dernière requête reçue (voie `dataGrid`).
class _CapturingRenderer extends ZListRenderer {
  _CapturingRenderer();

  final List<ZListRenderRequest> captured = <ZListRenderRequest>[];

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    captured.add(request);
    return const SizedBox.shrink();
  }
}

const List<ZFieldSpec> _fields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text),
];

Map<String, Object?> _cellsOf(_Person p) => <String, Object?>{'name': p.name};

Future<void> _pump(WidgetTester tester, Widget list) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(width: 700, height: 600, child: list),
        ),
      ),
    );

void main() {
  final alpha = const _Person(id: 'p1', name: 'Alpha', badge: 'A1');
  final beta = const _Person(id: 'p2', name: 'Beta', badge: 'B2');
  final people = <_Person>[alpha, beta];
  final rows = <ZListRow>[
    for (final p in people) ZListRow.ofEntity(p, _cellsOf(p)),
  ];
  final index = <String, _Person>{
    for (final p in people) ZListRow.keyOf(p): p,
  };

  testWidgets(
      'garde 1 — grille de cartes : la tuile typée reçoit l\'ENTITÉ, pas null',
      (tester) async {
    final received = <_Person>[];
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: (row) => index[row.id],
        layout: ZListGridLayout.forEntity<_Person>(
          (context, person, columns) {
            received.add(person);
            // `badge` n'existe que sur l'entité : le rendre PROUVE que la
            // carte a bien reçu l'objet métier.
            return Text('carte-${person.label}');
          },
          mainAxisExtent: 100,
        ),
      ),
    );
    expect(received.map((p) => p.id), containsAll(<String>['p1', 'p2']));
    expect(find.text('carte-Alpha#A1'), findsOneWidget);
    expect(find.text('carte-Beta#B2'), findsOneWidget);
  });

  testWidgets('garde 2 — liste verticale : la tuile typée reçoit l\'ENTITÉ',
      (tester) async {
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: (row) => index[row.id],
        layout: ZListBuilderLayout.forEntity<_Person>(
          (context, person, columns) => Text('ligne-${person.label}'),
        ),
      ),
    );
    expect(find.text('ligne-Alpha#A1'), findsOneWidget);
    expect(find.text('ligne-Beta#B2'), findsOneWidget);
  });

  testWidgets(
      'garde 3 — égalité de valeur : deux `entityFor` différents produisent '
      'des requêtes de rendu ÉGALES (mémoïsation préservée)', (tester) async {
    final renderer = _CapturingRenderer();
    // Deux fermetures DISTINCTES (jamais égales entre elles), même contenu.
    _Person? first(ZListRow row) => index[row.id];
    _Person? second(ZListRow row) => index[row.id];
    expect(identical(first, second), isFalse);

    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: first,
        renderer: renderer,
      ),
    );
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: second,
        renderer: renderer,
      ),
    );
    expect(renderer.captured.length, greaterThanOrEqualTo(2));
    final a = renderer.captured.first;
    final b = renderer.captured.last;
    expect(identical(a, b), isFalse);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  testWidgets(
      'garde 4 — contre-témoin : sans tuile typée, le rendu par ligne est '
      'inchangé', (tester) async {
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: (row) => index[row.id],
        layout: ZListGridLayout(
          mainAxisExtent: 100,
          itemBuilder: (context, row, columns) =>
              Text('brut-${row.cells['name']}'),
        ),
      ),
    );
    expect(find.text('brut-Alpha'), findsOneWidget);
    expect(find.text('brut-Beta'), findsOneWidget);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets(
      'garde 5 — entité ÉPHÉMÈRE (id null) : résolue par la clé publique '
      'ZListRow.keyOf', (tester) async {
    final draft = const _Person(name: 'Draft', badge: 'X9');
    expect(draft.id, isNull);
    final key = ZListRow.keyOf(draft);
    expect(ZListRow.isEphemeralKey(key), isTrue);
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        <ZListRow>[ZListRow.ofEntity(draft, _cellsOf(draft))],
        entityFor: (row) => row.id == key ? draft : null,
        layout: ZListGridLayout.forEntity<_Person>(
          (context, person, columns) => Text('carte-${person.label}'),
          mainAxisExtent: 100,
        ),
      ),
    );
    expect(find.text('carte-Draft#X9'), findsOneWidget);
  });

  test(
      'garde 6 — précédence : un layout portant déjà sa tuile la GARDE '
      '(withEntityTiles retourne this)', () {
    final grid = ZListGridLayout(
      itemBuilder: (context, row, columns) => const SizedBox.shrink(),
    );
    expect(
      identical(
        grid.withEntityTiles<_Person>((c, p, cols) => const SizedBox.shrink()),
        grid,
      ),
      isTrue,
    );
    final typed = ZListGridLayout.forEntity<_Person>(
      (c, p, cols) => const SizedBox.shrink(),
    );
    expect(
      identical(
        typed.withEntityTiles<_Person>((c, p, cols) => const SizedBox.shrink()),
        typed,
      ),
      isTrue,
    );
    // Les variantes SANS tuile (dataGrid, custom) ne portent rien.
    const dataGrid = ZListDataGridLayout();
    expect(
      identical(
        dataGrid
            .withEntityTiles<_Person>((c, p, cols) => const SizedBox.shrink()),
        dataGrid,
      ),
      isTrue,
    );
    // Une grille NUE (destinée à recevoir la tuile d'un assembleur) la reçoit,
    // géométrie conservée.
    const bare = ZListGridLayout(maxColumns: 3, mainAxisExtent: 180);
    final filled = bare.withEntityTiles<_Person>(
      (c, p, cols) => const SizedBox.shrink(),
    );
    expect(filled, isNot(same(bare)));
    expect((filled as ZListGridLayout).entityBuilder, isNotNull);
    expect(filled.maxColumns, 3);
    expect(filled.mainAxisExtent, 180);
  });

  testWidgets(
      'garde 7 — repli : tuile typée déclarée mais entité introuvable ⇒ tuile '
      'de ligne, aucune exception', (tester) async {
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: (row) => null,
        layout: ZListGridLayout(
          mainAxisExtent: 100,
          entityBuilder: (context, entity, columns) =>
              const Text('jamais-rendu'),
          itemBuilder: (context, row, columns) =>
              Text('repli-${row.cells['name']}'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('jamais-rendu'), findsNothing);
    expect(find.text('repli-Alpha'), findsOneWidget);
  });
}
