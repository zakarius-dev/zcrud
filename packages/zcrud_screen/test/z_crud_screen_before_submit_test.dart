// Gardes du crochet `beforeSubmit` de `ZCrudScreen` : transformation de la
// map VALIDÉE avant sa reconstruction en entité (`decode`), sur TOUS les
// chemins d'enregistrement du formulaire dérivé (création, édition,
// duplication). Sans crochet, le chemin est strictement inchangé (même
// instance de map — étalon par garde de source) ; un crochet qui lève
// emprunte le canal d'échec de la surface (message affiché, AUCUNE écriture).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Registre-espion : même enregistrement que [buildItemRegistry], mais chaque
/// map remise à `fromMap` (l'entrée réelle du décodage) est capturée dans
/// [decoded] — c'est là que s'assère « la map transformée est celle décodée ».
ZcrudRegistry buildSpyRegistry(List<Map<String, dynamic>> decoded) {
  final registry = ZcrudRegistry();
  registry.register<Item>(
    'item',
    fromMap: (map) {
      decoded.add(Map<String, dynamic>.of(map));
      return Item(
        id: map['id'] as String?,
        name: (map['name'] as String?) ?? '',
        qty: (map['qty'] as num?)?.toInt() ?? 0,
      );
    },
    toMap: (item) => <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'qty': item.qty,
    },
    fieldSpecs: itemSpecs,
  );
  return registry;
}

void main() {
  testWidgets(
    'création : le crochet reçoit original == null, sa clé AJOUTÉE atteint '
    'le décodage et sa valeur transformée survit jusqu\'à l\'entité écrite',
    (tester) async {
      final repo = FakeItemRepo(const <Item>[]);
      final decoded = <Map<String, dynamic>>[];
      final originals = <Item?>[];
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildSpyRegistry(decoded),
          beforeSubmit: (values, original) {
            originals.add(original);
            return <String, Object?>{...values, 'annex': 'granted', 'qty': 42};
          },
        ),
      );
      await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(DynamicEdition),
          matching: find.byType(TextField).at(1), // 'name' (id masqué ou 1er)
        ),
        'Nova',
      );
      await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
      await tester.pumpAndSettle();

      expect(originals, hasLength(1));
      expect(originals.single, isNull, reason: 'création : pas d\'original');
      // La map DÉCODÉE est la map transformée : clé ajoutée présente.
      expect(decoded, hasLength(1));
      expect(decoded.single['annex'], 'granted');
      // Et la valeur forcée par le crochet est celle de l'entité écrite.
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.qty, 42);
      repo.dispose();
    },
  );

  testWidgets(
    'édition : le crochet reçoit l\'entité en édition pour original et sa '
    'transformation est persistée',
    (tester) async {
      final repo = FakeItemRepo(const <Item>[
        Item(id: 'i1', name: 'Alpha', qty: 3),
      ]);
      final originals = <Item?>[];
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          beforeSubmit: (values, original) async {
            originals.add(original);
            return <String, Object?>{
              ...values,
              'name': '${values['name']} (validé)',
            };
          },
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
      await tester.pumpAndSettle();

      expect(originals, hasLength(1));
      expect(
        originals.single?.id,
        'i1',
        reason: 'édition : original = l\'entité éditée',
      );
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.id, 'i1');
      expect(repo.saved.single.name, 'Alpha (validé)');
      repo.dispose();
    },
  );

  testWidgets(
    'duplication : l\'enregistrement passe AUSSI par le crochet — original '
    'est la copie éphémère (sans identité)',
    (tester) async {
      final repo = FakeItemRepo(const <Item>[
        Item(id: 'i1', name: 'Alpha', qty: 3),
      ]);
      final originals = <Item?>[];
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          beforeSubmit: (values, original) {
            originals.add(original);
            return <String, Object?>{...values, 'qty': 99};
          },
        ),
      );
      await tester.tap(find.byIcon(Icons.copy_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
      await tester.pumpAndSettle();

      expect(originals, hasLength(1));
      final original = originals.single;
      expect(original, isNotNull);
      expect(
        original!.id,
        isNull,
        reason: 'duplication : original = la copie SANS identité',
      );
      expect(original.name, 'Alpha');
      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.id, isNot('i1'));
      expect(repo.saved.single.qty, 99);
      repo.dispose();
    },
  );

  testWidgets(
    'crochet qui lève : échec PROPRE par le canal de la surface — message '
    'affiché, surface ouverte, AUCUNE écriture',
    (tester) async {
      final repo = FakeItemRepo(const <Item>[
        Item(id: 'i1', name: 'Alpha', qty: 3),
      ]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          beforeSubmit: (values, original) =>
              throw StateError('refus annexe simulé'),
        ),
      );
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
      await tester.pumpAndSettle();

      // Aucune exception non capturée (le test échouerait), rien d'écrit,
      // la surface reste ouverte avec le message d'échec.
      expect(repo.saved, isEmpty);
      expect(find.byKey(const ValueKey('zCrudFormSave')), findsOneWidget);
      expect(find.textContaining('refus annexe simulé'), findsOneWidget);
      repo.dispose();
    },
  );

  testWidgets('sans crochet : chemin strictement inchangé — le décodage reçoit '
      'exactement la map fusionnée, sans clé parasite', (tester) async {
    final repo = FakeItemRepo(const <Item>[
      Item(id: 'i1', name: 'Alpha', qty: 3),
    ]);
    final decoded = <Map<String, dynamic>>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildSpyRegistry(decoded),
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    expect(decoded, hasLength(1));
    expect(decoded.single.keys.toSet(), <String>{'id', 'name', 'qty'});
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.name, 'Alpha');
    repo.dispose();
  });

  test('étalon de source : sans crochet la map fusionnée passe TELLE QUELLE '
      '(même instance) au décodage, et le crochet s\'applique AVANT lui', () {
    final source = File(
      'lib/src/presentation/z_crud_screen.dart',
    ).readAsStringSync();
    // Branche d'identité : absence de crochet ⇒ la map `merged` elle-même.
    final identity = RegExp(
      r'hook == null\s*\?\s*merged\s*:\s*await hook\(merged, initial\)',
    );
    expect(
      identity.hasMatch(source),
      isTrue,
      reason:
          'la branche sans crochet doit remettre `merged` inchangée '
          '(identical), et la branche avec crochet passer (merged, initial)',
    );
    // Ordre : la transformation précède le décodage sur le chemin de save.
    final hookAt = source.indexOf('widget.beforeSubmit');
    final decodeAt = source.indexOf('registry.decode(', hookAt);
    expect(hookAt, greaterThan(0));
    expect(
      decodeAt,
      greaterThan(hookAt),
      reason: 'le crochet doit être appliqué avant `registry.decode`',
    );
    expect(source.contains('transformed'), isTrue);
  });
}
