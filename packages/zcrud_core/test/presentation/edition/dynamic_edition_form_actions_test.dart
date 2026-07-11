// DP-14 (gap M7) — Gate d'actions de NIVEAU FORMULAIRE dans `DynamicEdition` :
// une `ZFormAction` non autorisée par l'`ZAcl` est MASQUÉE (mode hide, cohérent
// DP-6) ; le gate vit EXCLUSIVEMENT dans la voie de build structurel (SM-1 : une
// frappe ne recalcule ni le gate ni la barre d'actions) ; défensif (AD-10).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// ACL app-supplied refusant UNIQUEMENT `publish` (DP-14).
class _DenyPublishAcl implements ZAcl {
  const _DenyPublishAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action != ZCrudAction.publish;
}

/// ACL qui LÈVE toujours (preuve de dégradation défensive — AD-10).
class _ThrowingAcl implements ZAcl {
  const _ThrowingAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      throw StateError('acl boom');
}

void main() {
  final fields = <ZFieldSpec>[
    const ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
    const ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
  ];

  ZFormController newController() => ZFormController(
        initialValues: const <String, Object?>{'a': '', 'b': ''},
        visibleFields: const <String>['a', 'b'],
      );

  List<ZFormAction> actions() => <ZFormAction>[
        ZFormAction(
          id: 'publish',
          label: 'Publish',
          requiredPermission: ZCrudAction.publish,
          onInvoke: () {},
        ),
        ZFormAction(
          id: 'archive',
          label: 'Archive',
          requiredPermission: ZCrudAction.archive,
          onInvoke: () {},
        ),
      ];

  testWidgets('(a) sans formActions ⇒ aucune zone d\'actions (rétro-compat pixel)',
      (tester) async {
    final controller = newController();
    addTearDown(controller.dispose);
    var structural = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          onStructuralBuild: () => structural++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Aucune barre : aucun `TextButton` d'action rendu.
    expect(find.byType(TextButton), findsNothing);
    // La liste des champs reste rendue normalement.
    expect(find.byType(ZFieldWidget), findsNWidgets(2));
    expect(structural, greaterThan(0));
  });

  testWidgets('(b) action publish refusée ⇒ absente ; archive présente',
      (tester) async {
    final controller = newController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          acl: const _DenyPublishAcl(),
          formActions: actions(),
          collectionId: 'folders',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // `publish` masquée (hide), `archive` autorisée présente.
    expect(find.widgetWithText(TextButton, 'Publish'), findsNothing);
    expect(find.widgetWithText(TextButton, 'Archive'), findsOneWidget);
    // Accessibilité : bouton sémantique + cible ≥ 48 dp.
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Archive')).height,
      greaterThanOrEqualTo(48.0),
    );
  });

  testWidgets('(c) SM-1 : le gate/la barre ne sont PAS recalculés à la frappe',
      (tester) async {
    final controller = newController();
    addTearDown(controller.dispose);
    var structural = 0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          acl: const _DenyPublishAcl(),
          formActions: actions(),
          onStructuralBuild: () => structural++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final afterMount = structural;
    // Frappe de 20 caractères dans un champ.
    final editable = find.descendant(
      of: find.byKey(const ValueKey<String>('a')),
      matching: find.byType(EditableText),
    );
    for (var i = 0; i < 20; i++) {
      await tester.enterText(editable, 'x' * (i + 1));
      await tester.pump();
    }

    // Aucune reconstruction structurelle (le gate ACL n'est pas ré-évalué).
    expect(structural, afterMount, reason: 'onStructuralBuild stable à la frappe');
    // La barre reste cohérente : archive présente, publish masquée.
    expect(find.widgetWithText(TextButton, 'Archive'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Publish'), findsNothing);
  });

  testWidgets('(d) défensif : formActions vide + ACL par défaut ⇒ aucune exception',
      (tester) async {
    final controller = newController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: fields),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('(d-bis) défensif : ACL qui LÈVE ⇒ action masquée, pas de crash',
      (tester) async {
    final controller = newController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          acl: const _ThrowingAcl(),
          formActions: actions(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Fail-closed : aucune action rendue, aucune exception propagée.
    expect(tester.takeException(), isNull);
    expect(find.byType(TextButton), findsNothing);
  });
}
