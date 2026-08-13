// Gardes du mode de l'écran (`ZScreenMode`) et du TRANSPORT du drapeau de
// lecture jusqu'au FORMULAIRE.
//
// Ce que ces gardes mesurent, et pourquoi elles ne sont pas interchangeables :
//
// (a) `details` retire la création et la corbeille, mais garde le retour vers
//     l'édition — présent si et seulement si `ZCrudAction.update` est accordé ;
// (b) ouvrir une fiche rend le FORMULAIRE, pas les colonnes : la garde compte
//     les champs rendus et prouve qu'ils DÉPASSENT le nombre de colonnes de la
//     liste (c'est tout l'enjeu — une fiche dérivée des colonnes ne montrerait
//     que ce que le tableau montre déjà) ;
// (c) aucun champ n'est saisissable dans cette fiche ;
// (d) un champ WIDGET LIBRE reçoit bien l'information : son builder hôte
//     dessine ses propres contrôles, et sans le drapeau la fiche « lecture
//     seule » resterait cliquable ;
// (e) `locked` est l'exact équivalent de l'ancien `readOnly: true` ;
// (f) le titre affiché en `details` est celui de la consultation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Colonne UNIQUE de la liste : le cas réel du CR — la liste montre 4 à 6
/// colonnes là où le formulaire porte tous les champs. Ici 1 colonne contre
/// 3 champs de formulaire, pour que l'écart soit CHIFFRABLE.
const List<ZFieldSpec> _listOneColumn = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
];

/// Champ **widget libre** : le socle ne rend rien pour lui, c'est le builder
/// hôte (registre) qui dessine ses propres contrôles.
///
/// `showIfNull: true` est **nécessaire** et mesuré : en mode lecture,
/// `DynamicEdition` masque les champs vides qui ne le déclarent pas (règle
/// préexistante du socle, invariante ici). Sans ce drapeau, la fiche de détail
/// n'afficherait pas un champ resté vide.
const ZFieldSpec _permSpec = ZFieldSpec(
  name: 'perm',
  type: EditionFieldType.widget,
  widgetKind: 'permMatrix',
  showIfNull: true,
);

/// Formulaire à 3 champs — deux de plus que la liste n'a de colonnes.
const List<ZFieldSpec> _formThreeFields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text),
  ZFieldSpec(name: 'qty', type: EditionFieldType.integer),
  _permSpec,
];

/// Espion du builder hôte de widget libre : enregistre le `readOnly` de la
/// spec REÇUE à chaque rendu. C'est la mesure du transport, pas une
/// reformulation de la déclaration.
class _PermSpy {
  final List<bool> received = <bool>[];

  ZWidgetRegistry buildRegistry() {
    final registry = ZWidgetRegistry();
    registry.register('permMatrix', (context, ctx) {
      received.add(ctx.field.readOnly);
      return Switch(
        key: const ValueKey('permSwitch'),
        value: ctx.value == true,
        // Le widget hôte HONORE le drapeau reçu : c'est précisément ce qu'il
        // ne peut pas faire si le socle ne le lui transmet pas.
        onChanged: ctx.field.readOnly
            ? null
            : (bool v) => ctx.onChanged(v),
      );
    });
    return registry;
  }
}

/// Monte un écran dans un scope portant l'ACL ET le registre de widgets.
///
/// Le scope est posé **au-dessus du `Navigator`** (`MaterialApp.builder`), et
/// non sous `home:` : la surface d'édition est une route, elle n'hérite donc
/// que de ce qui enveloppe le `Navigator`. C'est l'emplacement qu'une
/// application doit choisir pour que son registre de widgets serve aussi les
/// formulaires présentés en dialogue ou en feuille.
Future<void> _pumpWithRegistry(
  WidgetTester tester,
  Widget child, {
  required ZWidgetRegistry widgetRegistry,
  ZAcl acl = const ZAllowAllAcl(),
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, navigator) => ZcrudScope(
        acl: acl,
        widgetRegistry: widgetRegistry,
        child: navigator!,
      ),
      home: child,
    ),
  );
  await tester.pumpAndSettle();
}

/// Ouvre la fiche de détail de la première ligne.
Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.visibility_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'garde (a) — details : aucune création, aucune corbeille, MAIS retour '
      'vers l\'édition quand update est accordé', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    // Ni création, ni duplication, ni corbeille.
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    // La fiche s'ouvre, et l'édition reste joignable.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (a) — details : update REFUSÉ ⇒ l\'action éditer disparaît, la '
      'fiche reste consultable', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.update}),
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (b) — la fiche rend le FORMULAIRE (3 champs), pas les colonnes '
      'de la liste (1 colonne)', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 7)],
    );
    final spy = _PermSpy();
    await _pumpWithRegistry(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        listFields: _listOneColumn,
        formFields: _formThreeFields,
        mode: ZScreenMode.details,
      ),
      widgetRegistry: spy.buildRegistry(),
    );
    // La LISTE ne connaît qu'une colonne : `qty` n'y est pas.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('7'), findsNothing);

    await _openDetails(tester);

    // La FICHE porte les trois champs du formulaire (place stable posée par
    // `DynamicEdition` : `ValueKey(field.name)`).
    final rendered = <String>[
      for (final spec in _formThreeFields)
        if (find
            .byKey(ValueKey<String>(spec.name))
            .evaluate()
            .isNotEmpty)
          spec.name,
    ];
    expect(rendered, <String>['name', 'qty', 'perm']);
    // Le point du CR, chiffré : plus de champs rendus que de colonnes.
    expect(rendered.length, greaterThan(_listOneColumn.length));
    expect(rendered.length, 3);
    expect(_listOneColumn.length, 1);
    repo.dispose();
  });

  testWidgets(
      'garde (c) — aucune saisie possible dans la fiche : aucun champ de '
      'texte éditable, aucun bouton d\'enregistrement', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 7)],
    );
    final spy = _PermSpy();
    final screen = ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      listFields: _listOneColumn,
      formFields: _formThreeFields,
      mode: ZScreenMode.details,
    );
    await _pumpWithRegistry(
      tester,
      screen,
      widgetRegistry: spy.buildRegistry(),
    );
    await _openDetails(tester);
    // Aucun `EditableText` : il n'y a littéralement rien où taper.
    expect(find.byType(EditableText), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormClose')), findsOneWidget);
    // Le widget libre reçu est INERTE (le drapeau lui est parvenu).
    final Switch sw = tester.widget(find.byKey(const ValueKey('permSwitch')));
    expect(sw.onChanged, isNull);

    // CONTRASTE — la même surface ouverte en ÉDITION est bien saisissable :
    // sans ce couple, la garde ci-dessus serait verte même si le formulaire
    // n'affichait jamais rien.
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsWidgets);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (d) — le champ WIDGET LIBRE reçoit le drapeau : readOnly vrai en '
      'fiche, faux en édition', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 7)],
    );
    final spy = _PermSpy();
    await _pumpWithRegistry(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        listFields: _listOneColumn,
        formFields: _formThreeFields,
        mode: ZScreenMode.details,
      ),
      widgetRegistry: spy.buildRegistry(),
    );
    expect(spy.received, isEmpty, reason: 'le champ n\'est pas dans la liste');

    await _openDetails(tester);
    expect(spy.received, isNotEmpty);
    expect(
      spy.received.every((bool ro) => ro),
      isTrue,
      reason: 'le builder hôte doit voir `ctx.field.readOnly == true`',
    );

    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();
    spy.received.clear();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(spy.received, isNotEmpty);
    expect(
      spy.received.any((bool ro) => ro),
      isFalse,
      reason: 'en édition, le drapeau ne doit PAS être posé',
    );
    repo.dispose();
  });

  testWidgets(
      'garde (e) — `ZScreenMode.locked` est l\'exact équivalent de l\'ancien '
      '`readOnly: true` (non-régression)', (tester) async {
    /// Relevé des affordances visibles d'un écran monté.
    Future<Map<String, bool>> affordances(Widget screen) async {
      await pumpScreen(tester, screen);
      final snapshot = <String, bool>{
        'liste': find.text('Alpha').evaluate().isNotEmpty,
        'creer': find
            .byKey(const ValueKey('zCrudCreate'))
            .evaluate()
            .isNotEmpty,
        'editer': find.byIcon(Icons.edit_outlined).evaluate().isNotEmpty,
        'dupliquer': find.byIcon(Icons.copy_outlined).evaluate().isNotEmpty,
        'details':
            find.byIcon(Icons.visibility_outlined).evaluate().isNotEmpty,
        'corbeille': find
            .byKey(const ValueKey('zCrudTrashToggle'))
            .evaluate()
            .isNotEmpty,
        'supprimer': find.byIcon(Icons.delete_outline).evaluate().isNotEmpty,
      };
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      return snapshot;
    }

    final legacyRepo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final legacy = await affordances(
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(legacyRepo),
        registry: buildItemRegistry(),
        // ignore: deprecated_member_use
        readOnly: true,
      ),
    );
    legacyRepo.dispose();

    final lockedRepo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final locked = await affordances(
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(lockedRepo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.locked,
      ),
    );
    lockedRepo.dispose();

    expect(locked, legacy);
    // …et ce relevé n'est pas vide de sens : la liste est bien rendue, tous
    // les gestes sont bien retirés.
    expect(locked['liste'], isTrue);
    expect(
      <bool>[
        locked['creer']!,
        locked['editer']!,
        locked['dupliquer']!,
        locked['details']!,
        locked['corbeille']!,
        locked['supprimer']!,
      ],
      everyElement(isFalse),
    );
  });

  testWidgets(
      'garde (f) — le titre de la fiche est celui de la CONSULTATION : repli '
      'l10n `details`, puis titre déclaré', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
      ),
    );
    await _openDetails(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('zCrudFormTitle'))).data,
      'Details',
    );
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();

    // Titre déclaré : il l'emporte, et il est DISTINCT de celui de l'édition.
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        titles: const ZCrudTitles(read: 'Fiche du consignataire',
            update: 'Modifier le consignataire'),
      ),
    );
    await _openDetails(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('zCrudFormTitle'))).data,
      'Fiche du consignataire',
    );
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('zCrudFormTitle'))).data,
      'Modifier le consignataire',
    );
    repo.dispose();
  });

  testWidgets(
      'transport jusqu\'au formulaire de l\'APPLICATION : `editionBuilder` '
      'lit le drapeau depuis son propre contexte', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    final seen = <bool>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
        editionBuilder: (context, initial, save) {
          seen.add(ZCrudEditionScope.readOnlyOf(context));
          return const SizedBox(key: ValueKey('hostForm'));
        },
      ),
    );
    await _openDetails(tester);
    expect(find.byKey(const ValueKey('hostForm')), findsOneWidget);
    expect(seen, isNotEmpty);
    expect(seen.every((bool ro) => ro), isTrue);

    Navigator.of(tester.element(find.byKey(const ValueKey('hostForm')))).pop();
    await tester.pumpAndSettle();
    seen.clear();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(seen, isNotEmpty);
    expect(seen.any((bool ro) => ro), isFalse);
    repo.dispose();
  });
}
