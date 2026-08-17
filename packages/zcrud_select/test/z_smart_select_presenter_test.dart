/// 🎯 fp-4-1 — tests PORTEURS de `ZSmartSelectPresenter` (AC2–AC8).
///
/// Discipline R3 (leçon fp-1-2) : chaque preuve de rendu ROUGIT si `present()`
/// renvoie le natif / un placebo (mutant témoin décrit dans l'en-tête T4). Les
/// captures `onChanged` prouvent la **valeur métier exacte** (jamais « le widget
/// existe »). L'ABSENCE du natif est prouvée par `findsNothing`.
///
/// `SmartSelect` (type du fork) est importé ICI (test) — la garde de confinement
/// ne scanne que `lib/**`, jamais `test/**` : légitime.
@TestOn('vm')
library;

import 'dart:io';

import 'package:awesome_select/awesome_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const ZFieldChoice _a = ZFieldChoice(value: 'a', label: 'Alpha');
const ZFieldChoice _b = ZFieldChoice(value: 'b', label: 'Bravo');
const List<ZFieldChoice> _abc = <ZFieldChoice>[
  _a,
  _b,
  ZFieldChoice(value: 'c', label: 'Charlie'),
];

ZFieldSpec _spec(
  EditionFieldType type, {
  String label = 'Mon champ',
  List<ZFieldChoice> choices = _abc,
  bool readOnly = false,
}) =>
    ZFieldSpec(
      name: 'f',
      type: type,
      label: label,
      choices: choices,
      readOnly: readOnly,
    );

/// Enveloppe : `MaterialApp` (Theme + Localizations) → `Directionality` →
/// `ZcrudScope(selectPresenter: …)` → `Scaffold(body: child)`.
Widget _host({
  required ZSelectPresenter? presenter,
  required Widget child,
  TextDirection direction = TextDirection.ltr,
  ZcrudLabels? labels,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: Directionality(
      textDirection: direction,
      child: ZcrudScope(
        selectPresenter: presenter,
        labels: labels,
        child: Scaffold(body: child),
      ),
    ),
  );
}

Widget _selectField(
  EditionFieldType type, {
  Object? value,
  required ValueChanged<Object?> onChanged,
  List<ZFieldChoice>? choices,
  bool multiple = false,
  bool searchable = false,
  bool readOnly = false,
}) =>
    ZSelectFieldWidget(
      field: _spec(type, choices: choices ?? _abc, readOnly: readOnly),
      value: value,
      onChanged: onChanged,
      choices: choices,
      multiple: multiple,
      searchable: searchable,
    );

Widget _relationPresentation({
  required ZRelationCrudHandler handler,
}) =>
    Builder(
      builder: (context) => const ZSmartSelectPresenter().present(
        context,
        ZSelectPresentation(
          field: ZFieldSpec(
            name: 'relation',
            type: EditionFieldType.relation,
            label: 'Relation',
            choices: _abc,
          ),
          options: _abc,
          selected: null,
          onChanged: _ignoreRelationChange,
          multiple: false,
          searchable: false,
          readOnly: false,
          crudHandler: handler,
        ),
      ),
    );

void _ignoreRelationChange(Object? _) {}

class _DefaultCrudHandler extends ZRelationCrudHandler {
  const _DefaultCrudHandler();

  @override
  Future<ZFieldChoice?> create(Map<String, Object?> context) async => _a;

  @override
  Future<ZFieldChoice?> edit(Object? value) async => _a;

  @override
  Future<ZFieldChoice?> copy(Object? value) async => _a;
}

class _CreateDeniedCrudHandler extends _DefaultCrudHandler {
  const _CreateDeniedCrudHandler();

  @override
  bool get canCreate => false;
}

class _EditDeniedCrudHandler extends _DefaultCrudHandler {
  const _EditDeniedCrudHandler();

  @override
  bool get canEdit => false;
}

class _CopyDeniedCrudHandler extends _DefaultCrudHandler {
  const _CopyDeniedCrudHandler();

  @override
  bool get canCopy => false;
}

class _ThrowingCreateCrudHandler extends _DefaultCrudHandler {
  const _ThrowingCreateCrudHandler();

  @override
  bool get canCreate => throw StateError('ACL indisponible');
}

class _AllDeniedCrudHandler extends _DefaultCrudHandler {
  const _AllDeniedCrudHandler();

  @override
  bool get canCreate => false;

  @override
  bool get canEdit => false;

  @override
  bool get canCopy => false;
}

Future<void> _openRelationModal(WidgetTester tester) async {
  await tester.tap(_trigger);
  await tester.pumpAndSettle();
}

/// Le **déclencheur** rendu par le présentateur — le `ListTile` que porte le
/// `Card` de l'apparence DODLP.
///
/// 🔴 Anti-vacuité (piège de ce lot) : ce finder est **spécifique au
/// présentateur**. Le rendu NATIF de `zcrud_core` n'enveloppe aucun `ListTile`
/// dans un `Card` (c'est un `DropdownButtonFormField`, des `RadioListTile` ou
/// des `CheckboxListTile` nus) — une garde qui l'emploie ROUGIT donc si le
/// présentateur n'est pas monté, au lieu de passer par accident.
final Finder _trigger = find
    .descendant(of: find.byType(Card), matching: find.byType(ListTile))
    .first;

/// Le `Card` du déclencheur (racine de l'habillage DODLP).
final Finder _triggerCard = find.byType(Card).first;

/// Lit la `BorderSide` peinte par le `Card` du déclencheur.
BorderSide _cardSide(WidgetTester tester) {
  final card = tester.widget<Card>(_triggerCard);
  final shape = card.shape! as RoundedRectangleBorder;
  return shape.side;
}

void main() {
  const presenter = ZSmartSelectPresenter();

  group('🎯 AC2 — `select` supplanté par SmartSelect (natif ABSENT)', () {
    testWidgets('sous présentateur injecté → SmartSelect, PAS de dropdown natif',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      // Rendu riche présent…
      expect(find.byType(SmartSelect), findsOneWidget);
      // …ET le natif est bien SUPPLANTÉ (presence≠association : prouvé par ABSENCE).
      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    });

    testWidgets('SANS présentateur → dropdown natif (non-régression AD-48)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: null,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
      expect(find.byType(SmartSelect), findsNothing);
    });

    testWidgets('espion `onChanged` capte le `value` MÉTIER (modal + tap option)',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            onChanged: (v) => captured = v),
      ));
      // Ouvre le modal S2 (tap sur le déclencheur riche).
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      // Le modal affiche les options : tap « Bravo » (choix unique → auto-commit).
      expect(find.text('Bravo'), findsOneWidget);
      await tester.tap(find.text('Bravo'));
      await tester.pumpAndSettle();
      // La tranche reçoit la VALEUR MÉTIER 'b' (jamais un type S2).
      expect(captured, 'b');
    });
  });

  group('🔴 CR-RELATION-ACL — gestes CRUD inline gouvernés séparément', () {
    Future<void> expectActions(
      WidgetTester tester,
      ZRelationCrudHandler handler, {
      required int create,
      required int edit,
      required int copy,
    }) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _relationPresentation(handler: handler),
      ));
      await _openRelationModal(tester);
      // Comptes absolus : aucun geste refusé ne subsiste dans le modal, son
      // slot secondaire, ni son arbre sémantique (les tooltips nomment les
      // seuls boutons CRUD construits).
      expect(find.byTooltip('Create'), findsNWidgets(create));
      expect(find.byTooltip('Edit'), findsNWidgets(edit));
      expect(find.byTooltip('Copy'), findsNWidgets(copy));
      expect(find.byIcon(Icons.add), findsNWidgets(create));
      expect(find.byIcon(Icons.edit), findsNWidgets(edit));
      expect(find.byIcon(Icons.copy), findsNWidgets(copy));
    }

    testWidgets('canCreate=false : Créer est absent, Modifier/Copier restent',
        (tester) async {
      await expectActions(tester, const _CreateDeniedCrudHandler(),
          create: 0, edit: 3, copy: 3);
    });

    testWidgets('canEdit=false : Modifier est absent, Créer/Copier restent',
        (tester) async {
      await expectActions(tester, const _EditDeniedCrudHandler(),
          create: 1, edit: 0, copy: 3);
    });

    testWidgets('canCopy=false : Copier est absent, Créer/Modifier restent',
        (tester) async {
      await expectActions(tester, const _CopyDeniedCrudHandler(),
          create: 1, edit: 3, copy: 0);
    });

    testWidgets('rétrocompat : handler sans override affiche les trois gestes',
        (tester) async {
      await expectActions(tester, const _DefaultCrudHandler(),
          create: 1, edit: 3, copy: 3);
    });

    testWidgets('AD-10 : getter canCreate qui lève ferme Créer seulement',
        (tester) async {
      await expectActions(tester, const _ThrowingCreateCrudHandler(),
          create: 0, edit: 3, copy: 3);
    });

    testWidgets('adversarial : aucun geste refusé ne survit dans la sémantique',
        (tester) async {
      final handle = tester.ensureSemantics();
      await expectActions(tester, const _AllDeniedCrudHandler(),
          create: 0, edit: 0, copy: 0);
      expect(find.bySemanticsLabel('Create'), findsNothing);
      expect(find.bySemanticsLabel('Edit'), findsNothing);
      expect(find.bySemanticsLabel('Copy'), findsNothing);
      handle.dispose();
    });

    testWidgets('actions CRUD restantes : contraintes explicites >= 48 dp',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _relationPresentation(handler: const _DefaultCrudHandler()),
      ));
      await _openRelationModal(tester);
      final create = tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip('Create'), matching: find.byType(IconButton),
      ));
      final edit = tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip('Edit').first, matching: find.byType(IconButton),
      ));
      final copy = tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip('Copy').first, matching: find.byType(IconButton),
      ));
      expect(create.constraints?.minWidth, greaterThanOrEqualTo(48));
      expect(create.constraints?.minHeight, greaterThanOrEqualTo(48));
      expect(edit.constraints?.minWidth, greaterThanOrEqualTo(48));
      expect(edit.constraints?.minHeight, greaterThanOrEqualTo(48));
      expect(copy.constraints?.minWidth, greaterThanOrEqualTo(48));
      expect(copy.constraints?.minHeight, greaterThanOrEqualTo(48));
    });
  });

  group('🎯 AC3 — radio (modal) / multiselect (List) / statiques+dynamiques', () {
    testWidgets('radio sous présentateur → SmartSelect mono (choix unique)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.radio, onChanged: (_) {}),
      ));
      final smart = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
      expect(smart.isMultiChoice, isFalse);
      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    });

    testWidgets('mono → scalaire (espion) ; select mono commit direct',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (v) => captured = v),
      ));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Charlie'));
      await tester.pumpAndSettle();
      expect(captured, 'c'); // scalaire, pas une List.
    });

    testWidgets('multi (checkbox) → SmartSelect.multiple + écrit une `List`',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], onChanged: (v) => captured = v),
      ));
      final smart = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
      expect(smart.isMultiChoice, isTrue);
      // Ouvre le modal multi, coche « Alpha »…
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      // 🔴 Parité DODLP (`useConfirm: readOnly ? false : true`) : en multi, la
      // sélection ne s'écrit QU'À la confirmation. Abandonner par la barrière ne
      // doit RIEN commettre — c'est la propriété, pas un détail de test.
      await tester.tapAt(const Offset(5, 5)); // dismiss sans confirmer.
      await tester.pumpAndSettle();
      expect(captured, #none,
          reason: '🔴 une fermeture NON confirmée ne doit pas écrire la tranche');

      // …puis re-ouvre, coche et CONFIRME.
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
      expect(captured, isA<List<Object?>>());
      expect(captured, <Object?>['a']); // une VRAIE List (jamais "S2Choice").
    });

    testWidgets('options DYNAMIQUES (résolues cross-champ) rendues telles quelles',
        (tester) async {
      // `choices` passé explicitement = options déjà résolues par le dispatcher.
      const dynamicChoices = <ZFieldChoice>[
        ZFieldChoice(value: 'x', label: 'Xray'),
        ZFieldChoice(value: 'y', label: 'Yankee'),
      ];
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            choices: dynamicChoices, onChanged: (_) {}),
      ));
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      expect(find.text('Xray'), findsOneWidget);
      expect(find.text('Yankee'), findsOneWidget);
    });
  });

  group('🎯 AC4 — `relation` sous présentateur : rendu S2 + capture', () {
    testWidgets('relation mono → SmartSelect rendu + capte la sélection',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: ZRelationFieldWidget(
          field: _spec(EditionFieldType.relation),
          value: null,
          onChanged: (v) => captured = v,
          options: _abc,
        ),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      await tester.tap(_trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(captured, 'a');
    });
  });

  group('🎯 AC6 — a11y / RTL / thème', () {
    testWidgets('déclencheur ≥ 48 dp', (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      final size = tester.getSize(find.byType(InkWell).first);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('UNE seule annonce accessible : button + label + action tap',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      // Un unique nœud porte le label du champ (pas de double annonce) ET
      // rassemble rôle `button` + action `tap` (activable au lecteur d'écran).
      expect(find.bySemanticsLabel('Mon champ'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mon champ')),
        containsSemantics(label: 'Mon champ', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('rendu en RTL sans exception', (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        direction: TextDirection.rtl,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'champ readOnly AVEC valeur → déclencheur rendu mais inerte '
        '(n\'ouvre pas de modal)', (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', readOnly: true, onChanged: (_) {}),
      ));
      // 🔴 Le fork résout la sélection de façon ASYNCHRONE (`resolveSelection`
      // au premier frame) : sans `pumpAndSettle`, `state.selected.isResolved`
      // est encore `false` et le tile s'efface (règle `EmptyContainer`).
      await tester.pumpAndSettle();
      // Le tile EST rendu (il y a une valeur à lire)…
      expect(_trigger, findsOneWidget);
      await tester.tap(_trigger, warnIfMissed: false);
      await tester.pumpAndSettle();
      // …mais aucun modal ne s'ouvre : « Bravo » (option NON sélectionnée)
      // n'apparaît nulle part. 🔴 On ne teste PAS sur « Alpha », qui est la
      // valeur COURANTE et s'affiche donc légitimement dans le déclencheur —
      // la garde serait fausse.
      expect(find.text('Bravo'), findsNothing);
    });
  });

  group('🎯 AC7 — défensif AD-10 : dégradé DÉFINI, jamais un crash', () {
    testWidgets('options vides → sélecteur rendu, aucune exception',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            choices: const <ZFieldChoice>[], onChanged: (_) {}),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('`selected` hors options → rendu neutre, aucune exception',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'zzz-inconnu', onChanged: (_) {}),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('option `disabled` → non sélectionnable, aucune exception',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(
          EditionFieldType.select,
          choices: const <ZFieldChoice>[
            ZFieldChoice(value: 'a', label: 'Alpha', disabled: true),
            _b,
          ],
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('🎯 MED-1 (FR-26) — placeholder état vide LOCALISÉ, jamais l\'anglais du fork', () {
    testWidgets(
        'mono SANS valeur → déclencheur affiche le placeholder l10n, PAS `Select one`',
        (tester) async {
      // l10n injectée : la clé `select` est surchargée en français. Le fork
      // retomberait sinon sur son littéral ANGLAIS `Select one`.
      await tester.pumpWidget(_host(
        presenter: presenter,
        labels: ZcrudLabels(<String, String>{'select': 'Choisir…'}),
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      // Le libellé ANGLAIS du fork (`selected.dart:200`) NE surface PAS.
      expect(find.text('Select one'), findsNothing);
      // …remplacé par le placeholder LOCALISÉ injecté.
      expect(find.text('Choisir…'), findsOneWidget);
    });

    testWidgets(
        'multi SANS valeur → placeholder l10n, PAS `Select one or more`',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        labels: ZcrudLabels(<String, String>{'select': 'Choisir…'}),
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], multiple: true, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Select one or more'), findsNothing);
      expect(find.text('Choisir…'), findsOneWidget);
    });

    testWidgets(
        'défaut en (aucune surcharge) → placeholder `Select`, jamais `Select one`',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Select one'), findsNothing);
      // Clé l10n `select` résolue par la table `en` de repli.
      expect(find.text('Select'), findsOneWidget);
    });
  });

  group('🎯 FIX-3 (AD-2) — reflet d\'un changement EXTERNE de la tranche', () {
    testWidgets(
        're-`pumpWidget` avec value:c → le déclencheur reflète `Charlie` (plus `Alpha`)',
        (tester) async {
      // Tranche initiale = 'a' → le déclencheur affiche « Alpha ».
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Charlie'), findsNothing);

      // Reflet EXTERNE : le MÊME champ re-monté avec value:'c' (sans interaction).
      // Le fork re-résout la sélection via didUpdateWidget ⇒ parité réactive AD-2.
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'c', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });
  });

  group('🎯 AC8 — composabilité `const`, zéro side-effect d\'import', () {
    test('présentateur `const`-constructible et immuable', () {
      const a = ZSmartSelectPresenter();
      const b = ZSmartSelectPresenter();
      expect(identical(a, b), isTrue); // const canonicalisé.
      expect(a, isA<ZSelectPresenter>());
    });

    test('avec une `spec`, le présentateur reste `const`-constructible', () {
      const c = ZSmartSelectPresenter(spec: ZSelectTileSpec(cardRadius: 4));
      expect(c.spec?.cardRadius, 4);
      expect(c, isA<ZSelectPresenter>());
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // CR-SELECT-FID — FIDÉLITÉ à l'apparence du `DynamicEdition` de DODLP legacy.
  // Relevé de référence : `z_select_tile_reference.dart` (dartdoc de tête).
  // ══════════════════════════════════════════════════════════════════════════

  group('🎯 FID-1 — STRUCTURE DODLP du déclencheur (Card + ListTile)', () {
    testWidgets('mono → `Card(elevation 0, radius 12, side 1)` + `ListTile`',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(_triggerCard, findsOneWidget);
      expect(_trigger, findsOneWidget);

      // 🔴 R3 : les valeurs attendues sont les LITTÉRAUX relevés chez DODLP,
      // JAMAIS `ZSelectTileReference.*`. Comparer le rendu à la constante qui
      // le produit est TAUTOLOGIQUE : changer la référence changerait les deux
      // côtés et la garde resterait verte (mesuré — injections I1/I2 inertes
      // dans la première version de ce fichier).
      final card = tester.widget<Card>(_triggerCard);
      expect(card.elevation, 0.0,
          reason: '🔴 DODLP : `elevation: 0` (le relief vient de la bordure)');

      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12),
          reason: '🔴 DODLP : `BorderRadius.circular(12)`');
      expect(shape.side.width, 1.0,
          reason: '🔴 DODLP : `BorderSide(color:)` sans width ⇒ 1,0');

      // …et la référence auditée porte bien ces mêmes valeurs (si elle dérive,
      // c'est ICI que ça se voit, pas dans un rendu devenu incohérent).
      expect(ZSelectTileReference.cardRadius, 12);
      expect(ZSelectTileReference.cardElevation, 0);
      expect(ZSelectTileReference.borderWidth, 1);
    });

    testWidgets('le libellé du champ est le TITRE du tile (jamais le sous-titre)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle(); // résolution ASYNCHRONE de la sélection.
      final tile = tester.widget<ListTile>(_trigger);
      expect((tile.title! as Text).data, 'Mon champ');
      // …et la VALEUR est le sous-titre (parité DODLP), pas l'inverse.
      expect((tile.subtitle! as Text).data, 'Alpha');
    });

    testWidgets('mono : `contentPadding` DIRECTIONNEL 16/8 (AD-13)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      final tile = tester.widget<ListTile>(_trigger);
      expect(tile.contentPadding, isA<EdgeInsetsDirectional>(),
          reason: '🔴 AD-13 : insets DIRECTIONNELS, jamais left/right');
      // 🔴 littéraux relevés chez DODLP (l. ~3067), pas la constante.
      expect(
        tile.contentPadding,
        const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 8),
      );
    });
  });

  group('🎯 FID-2 — PUCES du multi (Wrap 6/4, texte 12) — parité DODLP', () {
    testWidgets('multi AVEC valeurs → une `Chip` par titre, dans un `Wrap` 6/4',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>['a', 'c'], onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();

      final wrapFinder =
          find.descendant(of: _trigger, matching: find.byType(Wrap));
      expect(wrapFinder, findsOneWidget,
          reason: '🔴 DODLP affiche les sélections en PUCES, pas en texte joint');
      // 🔴 littéraux DODLP (`Wrap(spacing: 6, runSpacing: 4)`), pas la
      // constante qui les produit (injections I5/I6 : inertes autrement).
      final wrap = tester.widget<Wrap>(wrapFinder);
      expect(wrap.spacing, 6.0);
      expect(wrap.runSpacing, 4.0);
      expect(ZSelectTileReference.chipSpacing, 6);
      expect(ZSelectTileReference.chipRunSpacing, 4);

      final chips = find.descendant(of: _trigger, matching: find.byType(Chip));
      expect(chips, findsNWidgets(2));
      expect(find.descendant(of: _trigger, matching: find.text('Alpha')),
          findsOneWidget);
      expect(find.descendant(of: _trigger, matching: find.text('Charlie')),
          findsOneWidget);

      // 🔴 Le `state.selected.toString()` de la version précédente rendait
      // « [Alpha, Charlie] » : cette forme NE DOIT PAS surfacer.
      expect(find.text('[Alpha, Charlie]'), findsNothing);

      final chipText = tester.widget<Text>(
        find.descendant(of: chips.first, matching: find.byType(Text)),
      );
      expect(chipText.style?.fontSize, 12.0,
          reason: '🔴 DODLP : `TextStyle(fontSize: 12)` sur le texte de puce');
      expect(ZSelectTileReference.chipFontSize, 12);
    });

    testWidgets('multi SANS valeur → placeholder, AUCUNE puce', (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _trigger, matching: find.byType(Chip)),
          findsNothing);
      expect(find.descendant(of: _trigger, matching: find.text('Select')),
          findsOneWidget);
    });
  });

  group('🎯 FID-3 — COULEURS par RÔLES `ColorScheme` (FR-26), jamais littérales',
      () {
    /// 🔴 Anti-vacuité de garde de couleur : on ne compare pas la teinte peinte
    /// à une constante (elle pourrait coïncider avec l'ambiante). On monte le
    /// MÊME arbre sous DEUX schémas différents et l'on exige que la teinte
    /// SUIVE — ce qu'un littéral `Colors.grey.shade300` ne ferait jamais.
    testWidgets('la bordure SUIT `ColorScheme.outlineVariant` (2 thèmes)',
        (tester) async {
      final blue = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000FF)),
      );
      final red = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF0000)),
      );
      // Prérequis de la garde : les deux rôles DIFFÈRENT (sinon elle est vaine).
      expect(blue.colorScheme.outlineVariant,
          isNot(red.colorScheme.outlineVariant));

      await tester.pumpWidget(_host(
        presenter: presenter,
        theme: blue,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(_cardSide(tester).color, blue.colorScheme.outlineVariant);

      await tester.pumpWidget(_host(
        presenter: presenter,
        theme: red,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      // 🔴 `MaterialApp` INTERPOLE le thème (`AnimatedTheme`, 200 ms) : sans
      // ce `pumpAndSettle`, on lirait une teinte à mi-chemin et la garde
      // rougirait pour une raison qui n'est pas celle qu'elle mesure.
      await tester.pumpAndSettle();
      expect(_cardSide(tester).color, red.colorScheme.outlineVariant,
          reason: '🔴 une couleur EN DUR ne suivrait pas le changement de thème');
    });

    testWidgets('le fond de puce SUIT `ColorScheme.surfaceContainerHighest`',
        (tester) async {
      final blue = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000FF)),
      );
      final red = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF0000)),
      );
      expect(blue.colorScheme.surfaceContainerHighest,
          isNot(red.colorScheme.surfaceContainerHighest));

      Future<Color?> chipBg(ThemeData t) async {
        await tester.pumpWidget(_host(
          presenter: presenter,
          theme: t,
          child: _selectField(EditionFieldType.checkbox,
              value: const <Object?>['a'], onChanged: (_) {}),
        ));
        await tester.pumpAndSettle();
        return tester
            .widget<Chip>(
                find.descendant(of: _trigger, matching: find.byType(Chip)))
            .backgroundColor;
      }

      expect(await chipBg(blue), blue.colorScheme.surfaceContainerHighest);
      expect(await chipBg(red), red.colorScheme.surfaceContainerHighest);
    });

    test('🔴 ZÉRO couleur littérale dans `lib/**` (grep de source)', () {
      final dir = Directory('lib');
      expect(dir.existsSync(), isTrue,
          reason: '🔴 lancer `flutter test` DEPUIS le dossier du paquet');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files.length, greaterThan(2),
          reason: '🔴 anti-vacuité : le scan ne voit que ${files.length} fichier(s)');

      // Motifs interdits par FR-26. `Colors.` couvre `Colors.grey.shade300`.
      final banned = <RegExp>[
        RegExp(r'\bColors\.'),
        RegExp(r'\bColor\(0x'),
        RegExp(r'\.shade\d'),
      ];
      final hits = <String>[];
      for (final f in files) {
        // Dé-commentateur DART : le relevé de DODLP est CITÉ en dartdoc (il
        // contient donc `Colors.grey.shade300`) — accuser un commentaire serait
        // un diagnostic FAUX.
        final code = f
            .readAsStringSync()
            .split('\n')
            .where((l) {
              final t = l.trimLeft();
              return !t.startsWith('///') &&
                  !t.startsWith('//') &&
                  !t.startsWith('*') &&
                  !t.startsWith('/*');
            })
            .join('\n');
        for (final re in banned) {
          if (re.hasMatch(code)) hits.add('${f.path} ~ ${re.pattern}');
        }
      }
      expect(hits, isEmpty, reason: '🔴 couleur(s) littérale(s) :\n${hits.join('\n')}');
    });

    test('🔬 R12 — le scan de source SAIT voir une couleur littérale', () {
      final banned = <RegExp>[
        RegExp(r'\bColors\.'),
        RegExp(r'\bColor\(0x'),
        RegExp(r'\.shade\d'),
      ];
      const mutant = 'final c = Colors.grey.shade300;';
      expect(banned.any((re) => re.hasMatch(mutant)), isTrue,
          reason: '🔴 témoin : un littéral DOIT être vu');
      const legit = 'final c = scheme.outlineVariant;';
      expect(banned.any((re) => re.hasMatch(legit)), isFalse,
          reason: '🔴 un RÔLE ne doit PAS être accusé');
    });
  });

  group('🎯 FID-4 — défauts du legacy NON reproduits', () {
    testWidgets(
        'readOnly SANS valeur → RIEN n\'est rendu (parité `EmptyContainer`)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            readOnly: true, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      // Le SmartSelect est bien monté (le seam a délégué)…
      expect(find.byType(SmartSelect), findsOneWidget);
      // …mais son déclencheur s'efface entièrement.
      expect(find.byType(Card), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('🔴 AD-13 : le plancher de 48 dp n\'est pas ABAISSABLE par spec',
        (tester) async {
      const shrunk = ZSmartSelectPresenter(
        spec: ZSelectTileSpec(minTileHeight: 8),
      );
      await tester.pumpWidget(_host(
        presenter: shrunk,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      // 🔴 R3 : mesurer `getSize(_trigger)` ne prouvait RIEN — un `ListTile`
      // à titre + sous-titre dépasse 48 dp par sa hauteur INTRINSÈQUE, donc la
      // garde restait verte même avec le plancher supprimé (injection I8
      // inerte). On mesure la CONTRAINTE que le présentateur pose lui-même.
      final box = tester.widget<ConstrainedBox>(find
          .descendant(of: _triggerCard, matching: find.byType(ConstrainedBox))
          .first);
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48.0),
          reason: '🔴 une spec à 8 dp ne doit PAS descendre le plancher sous 48');
      // …et la cible rendue le respecte aussi.
      expect(tester.getSize(_trigger).height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('la spec PEUT rehausser le plancher (chaîne paramètre > réf.)',
        (tester) async {
      const tall = ZSmartSelectPresenter(
        spec: ZSelectTileSpec(minTileHeight: 96),
      );
      await tester.pumpWidget(_host(
        presenter: tall,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(tester.getSize(_trigger).height, greaterThanOrEqualTo(96.0));
    });

    testWidgets('AD-13 : le chevron est DIRECTIONNEL (RTL ⇒ chevron_left)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect((tester.widget<ListTile>(_trigger).trailing! as Icon).icon,
          Icons.chevron_right);

      await tester.pumpWidget(_host(
        presenter: presenter,
        direction: TextDirection.rtl,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect((tester.widget<ListTile>(_trigger).trailing! as Icon).icon,
          Icons.chevron_left,
          reason: '🔴 `Icons.chevron_right` ne se retourne PAS seul en RTL');
    });

    testWidgets(
        'readOnly AVEC valeur → PAS de chevron (parité DODLP `trailing: null`)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', readOnly: true, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle(); // résolution ASYNCHRONE de la sélection.
      expect(tester.widget<ListTile>(_trigger).trailing, isNull);
    });

    testWidgets(
        '🔴 l\'état ne repose pas sur la SEULE couleur : `Semantics.value` '
        'n\'existe QUE s\'il y a une valeur', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mon champ')),
        containsSemantics(label: 'Mon champ', value: ''),
        reason: '🔴 état vide : aucune valeur annoncée (le gris ne suffit pas)',
      );

      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mon champ')),
        containsSemantics(label: 'Mon champ', value: 'Alpha'),
      );
      handle.dispose();
    });

    testWidgets('multi : la `Semantics.value` JOINT les titres (pas les puces)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>['a', 'c'], onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mon champ')),
        containsSemantics(label: 'Mon champ', value: 'Alpha, Charlie'),
        reason: '🔴 dix puces = dix nœuds sémantiques sans cette jonction',
      );
      handle.dispose();
    });
  });

  group('🎯 FID-5 — parité de CONFIGURATION du modal', () {
    testWidgets('multi : `choiceType` = `switches` (défaut MESURÉ de DODLP)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], onChanged: (_) {}),
      ));
      final smart = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
      expect(smart.choiceConfig.type, S2ChoiceType.switches,
          reason: '🔴 DODLP : `field.s2choiceType ?? S2ChoiceType.switches`');
    });

    testWidgets('mono : `choiceType` = `radios` ; surchargeable par spec',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(
        tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect))
            .choiceConfig.type,
        S2ChoiceType.radios,
      );

      const chipped = ZSmartSelectPresenter(
        spec: ZSelectTileSpec(monoChoiceStyle: ZSelectChoiceStyle.chips),
      );
      await tester.pumpWidget(_host(
        presenter: chipped,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(
        tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect))
            .choiceConfig.type,
        S2ChoiceType.chips,
        reason: '🔴 chaîne paramètre > référence : la spec DOIT gagner',
      );
    });

    testWidgets(
        '`adaptive` : feuille sur écran étroit, dialogue sur écran large '
        '(substitut mesurable à `AppPlatform.isWebOrDesktop`)', (tester) async {
      Future<S2ModalType> typeAt(double width) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(
          presenter: presenter,
          child: _selectField(EditionFieldType.select, onChanged: (_) {}),
        ));
        return tester
            .widget<SmartSelect<dynamic>>(find.byType(SmartSelect))
            .modalConfig
            .type;
      }

      expect(await typeAt(400), S2ModalType.bottomSheet);
      expect(await typeAt(1200), S2ModalType.popupDialog);
    });

    testWidgets('FR-26 : l\'indice de recherche du modal est LOCALISÉ',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        labels: ZcrudLabels(<String, String>{'search': 'Chercher…'}),
        child: _selectField(EditionFieldType.select,
            searchable: true, onChanged: (_) {}),
      ));
      final smart = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
      expect(smart.modalConfig.filterHint, 'Chercher…',
          reason: '🔴 sinon le fork pose son `Search on <titre>` ANGLAIS');
      expect(smart.modalConfig.useFilter, isTrue);
    });

    testWidgets('multi : `useConfirm` actif en édition, INACTIF en lecture seule',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], onChanged: (_) {}),
      ));
      expect(
        tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect))
            .modalConfig.useConfirm,
        isTrue,
        reason: '🔴 DODLP : `useConfirm: readOnly ? false : true`',
      );

      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>['a'], readOnly: true, onChanged: (_) {}),
      ));
      expect(
        tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect))
            .modalConfig.useConfirm,
        isFalse,
      );
    });
  });
}
