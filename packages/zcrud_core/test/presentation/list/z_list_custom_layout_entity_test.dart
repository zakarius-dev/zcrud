// Le résolveur `entityFor` (`ZListRow → T?`), déjà déclaré une fois sur
// `DynamicList` pour les actions de ligne et les tuiles typées, est REMONTÉ au
// dernier layout qui ne le voyait pas : la vue personnalisée. Avant, un
// `ZListCustomLayout` ne recevait que la `ZListRenderRequest` et l'application
// devait reconstruire elle-même l'index `ligne → entité` que l'assembleur tient
// en privé — en recopiant sa convention de clé.
//
// Gardes :
// 1. `ZListCustomLayout.forEntity<T>` reçoit un résolveur qui rend l'ENTITÉ
//    typée de chaque ligne (la vue affiche une donnée absente des cellules) ;
// 2. AD-10 : une entité d'un autre type que `T` est résolue `null`, jamais une
//    exception de cast ;
// 3. sans `entityFor` déclaré sur la liste, le résolveur rend `null` pour
//    toute ligne (aucune exception) ;
// 4. contre-témoin : `customView` seul est rendu à l'identique (aucun résolveur
//    n'est passé, rien ne change pour l'hôte passif) ;
// 5. égalité de valeur : deux `entityFor` DIFFÉRENTS donnent à la vue
//    personnalisée des requêtes ÉGALES (la mémoïsation du rendu ne casse pas) ;
// 6. `withEntityTiles` sur une vue personnalisée retourne `this` (une vue
//    entière n'a pas de tuile à recevoir) ;
// 7. constructeur : ni `customView` ni `entityView` ⇒ assertion (la variante
//    ne peut pas être muette).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _Person extends ZEntity {
  const _Person({this.id, required this.name, required this.badge});

  @override
  final String? id;
  final String name;
  final String badge;

  String get label => '$name#$badge';
}

class _Other extends ZEntity {
  const _Other({this.id});

  @override
  final String? id;
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
  const alpha = _Person(id: 'p1', name: 'Alpha', badge: 'A1');
  const beta = _Person(id: 'p2', name: 'Beta', badge: 'B2');
  const people = <_Person>[alpha, beta];
  final rows = <ZListRow>[
    for (final p in people) ZListRow.ofEntity(p, _cellsOf(p)),
  ];
  final index = <String, _Person>{
    for (final p in people) ZListRow.keyOf(p): p,
  };

  testWidgets(
      'garde 1 — vue personnalisée typée : le résolveur rend l\'ENTITÉ de '
      'chaque ligne (badge absent des cellules)', (tester) async {
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: (row) => index[row.id],
        layout: ZListCustomLayout.forEntity<_Person>(
          (context, request, entityFor) => Column(
            children: <Widget>[
              for (final row in request.rows)
                Text('vue-${entityFor(row)?.label ?? 'introuvable'}'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('vue-Alpha#A1'), findsOneWidget);
    expect(find.text('vue-Beta#B2'), findsOneWidget);
    expect(find.textContaining('introuvable'), findsNothing);
  });

  testWidgets(
      'garde 2 — AD-10 : une entité d\'un autre type que T est résolue null, '
      'sans exception de cast', (tester) async {
    const stranger = _Other(id: 'p1');
    await _pump(
      tester,
      DynamicList<ZEntity>.rows(
        _fields,
        rows,
        entityFor: (row) => row.id == 'p1' ? stranger : index[row.id],
        layout: ZListCustomLayout.forEntity<_Person>(
          (context, request, entityFor) => Column(
            children: <Widget>[
              for (final row in request.rows)
                Text('vue-${entityFor(row)?.label ?? 'nul-${row.id}'}'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('vue-nul-p1'), findsOneWidget);
    expect(find.text('vue-Beta#B2'), findsOneWidget);
  });

  testWidgets(
      'garde 3 — sans entityFor déclaré, le résolveur rend null pour toute '
      'ligne, sans exception', (tester) async {
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        layout: ZListCustomLayout.forEntity<_Person>(
          (context, request, entityFor) => Text(
            'nuls:${request.rows.where((r) => entityFor(r) == null).length}',
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('nuls:2'), findsOneWidget);
  });

  testWidgets(
      'garde 4 — contre-témoin : customView seul est rendu à l\'identique',
      (tester) async {
    await _pump(
      tester,
      DynamicList<_Person>.rows(
        _fields,
        rows,
        entityFor: (row) => index[row.id],
        layout: ZListCustomLayout(
          customView: (context, request) =>
              Text('brut:${request.rows.length}:${request.columns.length}'),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('brut:2:1'), findsOneWidget);
  });

  testWidgets(
      'garde 5 — égalité de valeur : deux entityFor différents donnent à la '
      'vue des requêtes ÉGALES', (tester) async {
    final captured = <ZListRenderRequest>[];
    _Person? first(ZListRow row) => index[row.id];
    _Person? second(ZListRow row) => index[row.id];
    expect(identical(first, second), isFalse);
    final layout = ZListCustomLayout.forEntity<_Person>(
      (context, request, entityFor) {
        captured.add(request);
        return const SizedBox.shrink();
      },
    );
    await _pump(
      tester,
      DynamicList<_Person>.rows(_fields, rows,
          entityFor: first, layout: layout),
    );
    await _pump(
      tester,
      DynamicList<_Person>.rows(_fields, rows,
          entityFor: second, layout: layout),
    );
    expect(captured.length, greaterThanOrEqualTo(2));
    final a = captured.first;
    final b = captured.last;
    expect(identical(a, b), isFalse);
    expect(a, equals(b));
    expect(a.hashCode, equals(b.hashCode));
  });

  test('garde 6 — withEntityTiles sur une vue personnalisée retourne this',
      () {
    final custom = ZListCustomLayout(
      customView: (context, request) => const SizedBox.shrink(),
    );
    expect(
      identical(
        custom.withEntityTiles<_Person>((c, p, cols) => const SizedBox.shrink()),
        custom,
      ),
      isTrue,
    );
  });

  test('garde 7 — ni customView ni entityView ⇒ assertion', () {
    expect(() => ZListCustomLayout(), throwsAssertionError);
  });
}
