// DP-2 (B3) — câblage `DynamicEdition` : contexte d'édition (`conditionContext`,
// source context), valeur persistée (baseline, source persisted), prédicat de
// forme (source state réactive à la frappe). Vérifie AC12/AC13/AC14 : recalcul de
// visibilité UNIQUE sur bascule de contexte (jamais par frappe), condition
// `persisted` insensible à la saisie sur le champ homonyme, condition de forme
// `isNotEmpty` réactive, et non-régression SM-1 (frappe hors garde state = 0
// build structurel).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Finder _key(String name) => find.byKey(ValueKey<String>(name));

/// Hôte permettant de piloter `conditionContext` via `setState` (simule une
/// bascule de `crud`/`mode` par l'app parente).
class _ContextHost extends StatefulWidget {
  const _ContextHost({
    required this.controller,
    required this.fields,
    required this.initialContext,
    super.key,
  });

  final ZFormController controller;
  final List<ZFieldSpec> fields;
  final Map<String, Object?> initialContext;

  @override
  State<_ContextHost> createState() => _ContextHostState();
}

class _ContextHostState extends State<_ContextHost> {
  late Map<String, Object?> _ctx = widget.initialContext;

  void setContext(Map<String, Object?> ctx) => setState(() => _ctx = ctx);

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: widget.controller,
            fields: widget.fields,
            conditionContext: _ctx,
          ),
        ),
      );
}

void main() {
  testWidgets(
      'AC13/AC14 — bascule de conditionContext (crud) recalcule la visibilité '
      'UNE fois, sans frappe', (tester) async {
    // `secret` visible seulement si crud == read (source context).
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name'),
      ZFieldSpec(
        name: 'secret',
        type: EditionFieldType.text,
        label: 'Secret',
        condition:
            ZCondition.equals('crud', 'read', source: ZValueSource.context),
      ),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{'name': '', 'secret': ''},
    );
    addTearDown(controller.dispose);

    // Compte les changements STRUCTURELS réels : le controller ne notifie QUE sur
    // une transition effective de `setVisibleFields` (canal unique AD-2). C'est le
    // proxy propre de « recalcul de visibilité effectif » (indépendant des rebuilds
    // de parent).
    var structuralChanges = 0;
    controller.addListener(() => structuralChanges++);

    final hostKey = GlobalKey<_ContextHostState>();
    await tester.pumpWidget(_ContextHost(
      key: hostKey,
      controller: controller,
      fields: fields,
      initialContext: const <String, Object?>{'crud': 'read'},
    ));
    await tester.pumpAndSettle();

    // crud=read ⇒ secret visible.
    expect(controller.visibleFields.value, <String>['name', 'secret']);
    expect(_key('secret'), findsOneWidget);

    final changesBefore = structuralChanges;

    // Bascule crud → update : secret disparaît (recalcul via didUpdateWidget).
    hostKey.currentState!.setContext(const <String, Object?>{'crud': 'update'});
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['name']);
    expect(_key('secret'), findsNothing);
    // Exactement UNE transition structurelle (la bascule de contexte).
    expect(structuralChanges, changesBefore + 1);

    // Re-basculer un contexte AVEC une clé non surveillée ne recalcule pas la
    // visibilité (secret dépend de `crud` inchangé ⇒ setVisibleFields no-op).
    final changesAfter = structuralChanges;
    hostKey.currentState!.setContext(
        const <String, Object?>{'crud': 'update', 'foo': 'bar'});
    await tester.pumpAndSettle();
    expect(structuralChanges, changesAfter,
        reason: 'clé de contexte non surveillée ⇒ aucune transition');
  });

  testWidgets(
      'AC12/AC14 — condition persisted insensible à la frappe sur le champ '
      'homonyme', (tester) async {
    // `panel` visible si l'item d'origine reajusting != true (source persisted).
    const fields = <ZFieldSpec>[
      ZFieldSpec(
          name: 'reajusting', type: EditionFieldType.text, label: 'Reajusting'),
      ZFieldSpec(
        name: 'panel',
        type: EditionFieldType.text,
        label: 'Panel',
        condition: ZCondition.notEquals('reajusting', true,
            source: ZValueSource.persisted),
      ),
    ];
    // Baseline reajusting = true ⇒ panel masqué dès l'amorçage.
    final controller = ZFormController(
      initialValues: const <String, Object?>{'reajusting': true, 'panel': ''},
    );
    addTearDown(controller.dispose);

    var structuralBuilds = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: fields,
          onStructuralBuild: () => structuralBuilds++,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(controller.visibleFields.value, <String>['reajusting'],
        reason: 'baseline reajusting=true ⇒ panel masqué');

    final buildsBefore = structuralBuilds;

    // Frappe sur le champ homonyme `reajusting` (état courant) : la BASELINE ne
    // change pas ⇒ aucune bascule de visibilité, aucun recalcul structurel
    // (source persisted n'est PAS dans le set de garde state — SM-1).
    for (var i = 0; i < 10; i++) {
      controller.setValue('reajusting', 'saisie$i');
      await tester.pump();
    }
    expect(structuralBuilds, buildsBefore,
        reason: 'frappe sur champ persisted homonyme ⇒ 0 recalcul (SM-1)');
    expect(_key('panel'), findsNothing);
  });

  testWidgets('AC14 — prédicat de forme isNotEmpty (source state) réactif à la '
      'frappe', (tester) async {
    // `detail` visible si `entries` (state) est non vide.
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'entries', type: EditionFieldType.text, label: 'Entries'),
      ZFieldSpec(
        name: 'detail',
        type: EditionFieldType.text,
        label: 'Detail',
        condition: ZCondition.isNotEmpty('entries'),
      ),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{'entries': '', 'detail': ''},
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: fields),
      ),
    ));
    await tester.pumpAndSettle();

    // Vide ⇒ detail masqué.
    expect(controller.visibleFields.value, <String>['entries']);
    expect(_key('detail'), findsNothing);

    // Non-vide ⇒ detail apparaît (source state ⇒ garde ⇒ recalcul par frappe).
    controller.setValue('entries', 'x');
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['entries', 'detail']);
    expect(_key('detail'), findsOneWidget);

    // Redevient vide ⇒ disparaît.
    controller.setValue('entries', '');
    await tester.pumpAndSettle();
    expect(_key('detail'), findsNothing);
  });

  testWidgets(
      'AC16 — sans conditionContext, conditions existantes se comportent à '
      "l'identique (rétro-compat)", (tester) async {
    const fields = <ZFieldSpec>[
      ZFieldSpec(name: 'trig', type: EditionFieldType.text, label: 'Trig'),
      ZFieldSpec(
        name: 'dep',
        type: EditionFieldType.text,
        label: 'Dep',
        condition: ZCondition.truthy('trig'),
      ),
    ];
    final controller = ZFormController(
      initialValues: const <String, Object?>{'trig': '', 'dep': ''},
    );
    addTearDown(controller.dispose);

    // Aucun conditionContext fourni (défaut vide).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: fields),
      ),
    ));
    await tester.pumpAndSettle();

    expect(controller.visibleFields.value, <String>['trig']);
    controller.setValue('trig', 'x');
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['trig', 'dep']);
  });

  testWidgets(
      'DP-2 MEDIUM-1 — condition persisted recalculée sur reseed (la baseline '
      'change ⇒ visibilité rafraîchie)', (tester) async {
    // `panel` visible si l'item d'origine reajusting != true (source persisted).
    const fields = <ZFieldSpec>[
      ZFieldSpec(
          name: 'reajusting', type: EditionFieldType.text, label: 'Reajusting'),
      ZFieldSpec(
        name: 'panel',
        type: EditionFieldType.text,
        label: 'Panel',
        condition: ZCondition.notEquals('reajusting', true,
            source: ZValueSource.persisted),
      ),
    ];
    // Baseline initiale reajusting = true ⇒ panel masqué à l'amorçage.
    final controller = ZFormController(
      initialValues: const <String, Object?>{'reajusting': true, 'panel': ''},
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: fields),
      ),
    ));
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['reajusting'],
        reason: 'baseline reajusting=true ⇒ panel masqué');
    expect(_key('panel'), findsNothing);

    // Chargement async d'un item dont l'original reajusting=false (simule un
    // reseed après fetch — E7). La BASELINE change et `reseed` incrémente
    // `reseedRevision` ⇒ panel doit apparaître (canal structurel, hors SM-1).
    controller.reseed(const <String, Object?>{'reajusting': false, 'panel': ''});
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['reajusting', 'panel'],
        reason: 'reseed(baseline reajusting=false) ⇒ panel visible (MEDIUM-1)');
    expect(_key('panel'), findsOneWidget);

    // `reset` restaure la baseline courante (reajusting=false) : panel reste
    // visible et le recalcul repasse sans erreur (idempotent).
    controller.reset();
    await tester.pumpAndSettle();
    expect(controller.visibleFields.value, <String>['reajusting', 'panel'],
        reason: 'reset(baseline reajusting=false) ⇒ panel toujours visible');
    expect(_key('panel'), findsOneWidget);
  });
}
