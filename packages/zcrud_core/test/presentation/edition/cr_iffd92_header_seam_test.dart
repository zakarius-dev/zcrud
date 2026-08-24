// CR-IFFD-92 ⑤/⑥ — seam d'en-tête INFORMÉ (`ZSubListSeams.headerBuilder`) :
// le builder reçoit le champ, le compte d'items et le rappel d'ajout.
//
// Couvre :
//  - le nouveau seam reçoit `field`, `itemCount` et `onAdd` (compact et tags) ;
//  - `onAdd` ouvre la machinerie de création native ;
//  - l'ACL n'est jamais contournée : création refusée ⇒ `onAdd` nul et
//    contrôle d'ajout `SizedBox.shrink()` ;
//  - l'ANCIEN seam (`captionBuilder`) marche toujours, seul ;
//  - précédence : `headerBuilder` PRIME quand les deux sont déclarés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// ACL qui refuse UNIQUEMENT `create`.
class _NoCreateAcl implements ZAcl {
  const _NoCreateAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action != ZCrudAction.create;
}

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

const _field = ZFieldSpec(
  name: 'items',
  type: EditionFieldType.subItems,
  label: 'Items',
  config: ZSubListConfig(
    itemFields: _itemFields,
    summaryFields: <String>['f1'],
  ),
);

const _seed = <Map<String, dynamic>>[
  <String, dynamic>{'f1': 'A'},
  <String, dynamic>{'f1': 'B'},
];

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('⑥ headerBuilder reçoit champ + compte + rappel d\'ajout ; '
      'onAdd ouvre la création native', (tester) async {
    ZSubListHeaderView? recu;
    final seams = ZSubListSeamRegistry()
      ..register(
        'items',
        ZSubListSeams(
          headerBuilder: (context, header) {
            recu = header;
            return Text('EN-TETE ${header.field.name} ${header.itemCount}');
          },
        ),
      );
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      subListSeamRegistry: seams,
      child: ZSubListFieldWidget(
        field: _field,
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();

    expect(recu, isNotNull);
    expect(recu!.field.name, 'items');
    expect(recu!.itemCount, 2);
    expect(recu!.onAdd, isNotNull);
    expect(find.text('EN-TETE items 2'), findsOneWidget);
    // L'en-tête natif est remplacé.
    expect(find.text('Items'), findsNothing);

    // Le rappel d'ajout ouvre la machinerie native (formulaire d'item).
    recu!.onAdd!();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('⑥ ACL jamais contournée : création refusée ⇒ onAdd nul et '
      'contrôle inerte', (tester) async {
    ZSubListHeaderView? recu;
    final seams = ZSubListSeamRegistry()
      ..register(
        'items',
        ZSubListSeams(
          headerBuilder: (context, header) {
            recu = header;
            return const Text('EN-TETE');
          },
        ),
      );
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const _NoCreateAcl(),
      subListSeamRegistry: seams,
      child: ZSubListFieldWidget(
        field: _field,
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(recu, isNotNull);
    expect(recu!.onAdd, isNull);
    expect(recu!.addControl, isA<SizedBox>());
  });

  testWidgets('⑥ l\'ancien seam (captionBuilder) marche toujours, seul',
      (tester) async {
    final seams = ZSubListSeamRegistry()
      ..register(
        'items',
        ZSubListSeams(
          captionBuilder: (context, addControl) =>
              Row(children: <Widget>[const Text('CAPTION'), addControl]),
        ),
      );
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      subListSeamRegistry: seams,
      child: ZSubListFieldWidget(
        field: _field,
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(find.text('CAPTION'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('⑥ précédence : headerBuilder PRIME sur captionBuilder',
      (tester) async {
    var captionAppele = false;
    final seams = ZSubListSeamRegistry()
      ..register(
        'items',
        ZSubListSeams(
          headerBuilder: (context, header) => const Text('NOUVEAU'),
          captionBuilder: (context, addControl) {
            captionAppele = true;
            return const Text('ANCIEN');
          },
        ),
      );
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      subListSeamRegistry: seams,
      child: ZSubListFieldWidget(
        field: _field,
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(find.text('NOUVEAU'), findsOneWidget);
    expect(find.text('ANCIEN'), findsNothing);
    expect(captionAppele, isFalse);
  });

  testWidgets('⑥ mode tags : headerBuilder servi avec le compte', (tester) async {
    const champTags = ZFieldSpec(
      name: 'items',
      type: EditionFieldType.subItems,
      label: 'Items',
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: ZSubListDisplayMode.tags,
        summaryFields: <String>['f1'],
      ),
    );
    ZSubListHeaderView? recu;
    final seams = ZSubListSeamRegistry()
      ..register(
        'items',
        ZSubListSeams(
          headerBuilder: (context, header) {
            recu = header;
            return Text('TAGS ${header.itemCount}');
          },
        ),
      );
    await tester.pumpWidget(_host(ZcrudScope(
      acl: const ZAllowAllAcl(),
      subListSeamRegistry: seams,
      child: ZSubListFieldWidget(
        field: champTags,
        initialValue: _seed,
        onChanged: (_) {},
      ),
    )));
    await tester.pump();
    expect(recu, isNotNull);
    expect(recu!.itemCount, 2);
    expect(recu!.onAdd, isNotNull);
    expect(find.text('TAGS 2'), findsOneWidget);
  });
}
