// CR-DODLP-BOOL (2026-08-10) — Famille `boolean` : texte d'état optionnel
// (« Oui / Non ») accolé au switch, activé DÉCLARATIVEMENT par `ZBooleanConfig`.
//
// Ce que ces gardes défendent, et comment elles rougissent :
//
//  * `showsStateLabel` (domaine) — le prédicat unique d'activation. Le rendre
//    constant (`=> false` / `=> true`) casse la moitié des cas.
//  * IMMOBILITÉ de l'hôte passif — le `title` d'un `boolean` SANS config doit
//    rester un `Text` NU (pas un `Row`) et l'arbre sémantique doit être
//    identique. Rendre le `Row` inconditionnel rougit ces deux gardes.
//  * DOUBLE ANNONCE — le texte d'état est DÉCORATIF. Retirer `ExcludeSemantics`
//    fait apparaître « ACTIVÉ » dans les `label` sémantiques (1 occurrence au
//    lieu de 0) alors qu'il est déjà porté par le drapeau `toggled` du switch.
//    On compte les OCCURRENCES de sous-chaîne (les conteneurs fusionnent leurs
//    descendants : compter les NŒUDS ne mordrait pas).
//  * LES DEUX SENS — chaque garde d'affichage est jouée à `true` ET à `false` :
//    un repli qui rendrait par hasard la bonne chaîne dans un seul sens serait
//    invisible autrement.
//  * LECTURE SEULE — `readOnly` désactive le switch mais CONSERVE le texte.
//  * CIBLE TACTILE — mesurée par `androidTapTargetGuideline` (le mesureur du
//    framework, jamais un `getSize()`), sous une contrainte de largeur LIANTE
//    (360 dp : le titre + l'état + le switch doivent y tenir sans écraser la
//    hauteur de ligne).
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Libellé de champ volontairement SANS sous-chaîne commune avec les libellés
/// d'état testés (« ACTIVÉ »/« COUPÉ ») : un comptage d'occurrences ne doit pas
/// être pollué par le titre.
const String _fieldLabel = 'Magasin du bord visité ?';

ZFieldSpec _spec({ZFieldConfig? config, bool readOnly = false}) => ZFieldSpec(
      name: 'visited',
      type: EditionFieldType.boolean,
      label: _fieldLabel,
      readOnly: readOnly,
      config: config,
    );

/// Applique la locale zcrud demandée SANS déclarer la locale au `MaterialApp` :
/// `flutter_localizations` n'est pas (et ne doit pas être) une dépendance du
/// cœur, donc `MaterialLocalizations` ne connaît que `en`. `Localizations.override`
/// hérite des delegates du parent et n'échange que la locale + le delegate zcrud.
Widget _withLocale(Locale? locale, Widget child) => locale == null
    ? child
    : Builder(
        builder: (context) => Localizations.override(
          context: context,
          locale: locale,
          delegates: const <LocalizationsDelegate<Object?>>[
            ZcrudLocalizationsDelegate(),
          ],
          child: child,
        ),
      );

/// Monte le champ booléen seul via `ZBooleanFieldWidget` (la famille sous test).
Widget _app(
  ZFieldSpec field,
  Object? value, {
  TextDirection textDirection = TextDirection.ltr,
  Locale? locale,
  double width = 360,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: _withLocale(
                locale,
                ZBooleanFieldWidget(
                  field: field,
                  value: value,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// Nombre total d'OCCURRENCES de [needle] dans les `label` de TOUS les nœuds
/// sémantiques rendus — le canal réellement lu par un lecteur d'écran.
int _labelOccurrences(WidgetTester tester, String needle) {
  // `rootPipelineOwner` (le remplaçant annoncé) n'expose PAS de
  // `semanticsOwner` en test — mesuré : les gardes deviennent un
  // `_TypeError` au lieu d'une assertion. On lit l'owner effectif.
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var count = 0;
  void walk(SemanticsNode n) {
    count += needle.allMatches(n.getSemanticsData().label).length;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return count;
}

/// `true` si un nœud sémantique porte le drapeau `isToggled` demandé — c'est
/// l'annonce d'état NATIVE du `Switch`, celle que le texte ne doit pas doubler.
bool _hasToggled(WidgetTester tester, {required bool expected}) {
  // `rootPipelineOwner` (le remplaçant annoncé) n'expose PAS de
  // `semanticsOwner` en test — mesuré : les gardes deviennent un
  // `_TypeError` au lieu d'une assertion. On lit l'owner effectif.
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var found = false;
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    // `SemanticsFlags.isToggled` (le remplaçant) est un `Tristate` non
    // comparable à un `bool` : `hasFlag` reste la lecture exacte de l'état —
    // même choix que `fp_2_1_double_annonce_test`/`z_batch_action_test`.
    // ignore: deprecated_member_use
    final hasToggle = d.hasFlag(SemanticsFlag.hasToggledState);
    // ignore: deprecated_member_use
    final isToggled = d.hasFlag(SemanticsFlag.isToggled);
    if (hasToggle && isToggled == expected) {
      found = true;
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return found;
}

/// Le widget occupant le slot `title` du `SwitchListTile` rendu.
Widget _titleOf(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).title!;

void main() {
  group('ZBooleanConfig — surface domaine (const, pur-données)', () {
    test('défauts : aucun texte d\'état (rétro-compat stricte)', () {
      const cfg = ZBooleanConfig();
      expect(cfg.showStateLabel, isFalse);
      expect(cfg.trueLabel, isNull);
      expect(cfg.falseLabel, isNull);
      expect(cfg.showsStateLabel, isFalse);
    });

    test('showStateLabel: true active seul (libellés localisés par défaut)', () {
      const cfg = ZBooleanConfig(showStateLabel: true);
      expect(cfg.showsStateLabel, isTrue);
      expect(cfg.trueLabel, isNull);
      expect(cfg.falseLabel, isNull);
    });

    test('trueLabel SEUL active (jamais silencieusement ignoré)', () {
      const cfg = ZBooleanConfig(trueLabel: 'ACTIVÉ');
      expect(cfg.showStateLabel, isFalse);
      expect(cfg.showsStateLabel, isTrue);
    });

    test('falseLabel SEUL active aussi (les deux sens couverts)', () {
      const cfg = ZBooleanConfig(falseLabel: 'COUPÉ');
      expect(cfg.showStateLabel, isFalse);
      expect(cfg.showsStateLabel, isTrue);
    });

    test('R3 : égalité/hash discriminent CHAQUE champ', () {
      const base = ZBooleanConfig();
      expect(base, equals(const ZBooleanConfig()));
      expect(base.hashCode, equals(const ZBooleanConfig().hashCode));
      // Rougit si `showStateLabel` sort de `operator ==`/`hashCode`.
      expect(base, isNot(equals(const ZBooleanConfig(showStateLabel: true))));
      expect(base.hashCode,
          isNot(equals(const ZBooleanConfig(showStateLabel: true).hashCode)));
      // Rougit si `trueLabel` en sort.
      expect(base, isNot(equals(const ZBooleanConfig(trueLabel: 'ACTIVÉ'))));
      expect(base.hashCode,
          isNot(equals(const ZBooleanConfig(trueLabel: 'ACTIVÉ').hashCode)));
      // Rougit si `falseLabel` en sort.
      expect(base, isNot(equals(const ZBooleanConfig(falseLabel: 'COUPÉ'))));
      expect(base.hashCode,
          isNot(equals(const ZBooleanConfig(falseLabel: 'COUPÉ').hashCode)));
    });

    test('c\'est bien un ZFieldConfig (point d\'extension AD-4)', () {
      const ZFieldConfig cfg = ZBooleanConfig();
      expect(cfg, isA<ZFieldConfig>());
    });
  });

  group('Hôte PASSIF — immobilité stricte', () {
    testWidgets('sans config : le `title` reste un Text NU (pas un Row)',
        (tester) async {
      await tester.pumpWidget(_app(_spec(), false));
      // Rougit si le `Row` d'état devient inconditionnel.
      expect(_titleOf(tester), isA<Text>());
      expect(find.descendant(
              of: find.byType(SwitchListTile), matching: find.byType(Row)),
          findsNothing);
    });

    testWidgets('sans config : AUCUN texte d\'état rendu (les 2 sens)',
        (tester) async {
      for (final v in <bool>[true, false]) {
        await tester.pumpWidget(_app(_spec(), v));
        expect(find.text('Yes'), findsNothing, reason: 'valeur=$v');
        expect(find.text('No'), findsNothing, reason: 'valeur=$v');
        expect(find.text(_fieldLabel), findsOneWidget, reason: 'valeur=$v');
      }
    });

    testWidgets('sans config : ZBooleanConfig() vide ⇒ même rendu que null',
        (tester) async {
      await tester.pumpWidget(_app(_spec(config: const ZBooleanConfig()), true));
      expect(_titleOf(tester), isA<Text>());
      expect(find.text('Yes'), findsNothing);
    });

    testWidgets('sans config : le libellé n\'apparaît qu\'UNE fois en sémantique',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(_spec(), true));
      expect(_labelOccurrences(tester, _fieldLabel), 1);
      expect(_hasToggled(tester, expected: true), isTrue);
      handle.dispose();
    });
  });

  group('Activation — texte d\'état rendu, LES DEUX SENS', () {
    testWidgets('showStateLabel + locale fr ⇒ « Oui » / « Non »',
        (tester) async {
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(showStateLabel: true)),
        true,
        locale: const Locale('fr'),
      ));
      expect(find.text('Oui'), findsOneWidget);
      expect(find.text('Non'), findsNothing);

      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(showStateLabel: true)),
        false,
        locale: const Locale('fr'),
      ));
      expect(find.text('Non'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);
    });

    testWidgets('showStateLabel + locale en ⇒ « Yes » / « No » (l10n, FR-26)',
        (tester) async {
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(showStateLabel: true)),
        true,
        locale: const Locale('en'),
      ));
      expect(find.text('Yes'), findsOneWidget);
      // Rougit si un littéral français est codé en dur dans le widget.
      expect(find.text('Oui'), findsNothing);

      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(showStateLabel: true)),
        false,
        locale: const Locale('en'),
      ));
      expect(find.text('No'), findsOneWidget);
      expect(find.text('Non'), findsNothing);
    });

    testWidgets('libellés de l\'hôte : priorité sur les clés l10n (2 sens)',
        (tester) async {
      const cfg = ZBooleanConfig(trueLabel: 'ACTIVÉ', falseLabel: 'COUPÉ');
      await tester.pumpWidget(
          _app(_spec(config: cfg), true, locale: const Locale('fr')));
      expect(find.text('ACTIVÉ'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);

      await tester.pumpWidget(
          _app(_spec(config: cfg), false, locale: const Locale('fr')));
      expect(find.text('COUPÉ'), findsOneWidget);
      expect(find.text('Non'), findsNothing);
    });

    testWidgets('trueLabel SEUL : l\'autre sens retombe sur la clé l10n',
        (tester) async {
      const cfg = ZBooleanConfig(trueLabel: 'ACTIVÉ');
      await tester.pumpWidget(
          _app(_spec(config: cfg), true, locale: const Locale('fr')));
      expect(find.text('ACTIVÉ'), findsOneWidget);

      await tester.pumpWidget(
          _app(_spec(config: cfg), false, locale: const Locale('fr')));
      expect(find.text('Non'), findsOneWidget);
    });

    testWidgets('libellé VIDE ⇒ repli l10n, jamais une chaîne vide (AD-10)',
        (tester) async {
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(trueLabel: '')),
        true,
        locale: const Locale('fr'),
      ));
      expect(find.text('Oui'), findsOneWidget);
    });

    testWidgets('le texte d\'état est DANS le title, donc accolé au Switch',
        (tester) async {
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(trueLabel: 'ACTIVÉ')),
        true,
      ));
      // Rougit si le texte migre vers `subtitle` / `secondary` / hors du tile.
      expect(_titleOf(tester), isA<Row>());
      final tile = find.byType(SwitchListTile);
      final state = find.text('ACTIVÉ');
      expect(find.descendant(of: tile, matching: state), findsOneWidget);
      // Ordre visuel LTR : libellé, puis état, puis le switch tout à la fin.
      final labelEnd = tester.getBottomRight(find.text(_fieldLabel)).dx;
      final stateStart = tester.getTopLeft(state).dx;
      final switchStart = tester.getTopLeft(find.byType(Switch)).dx;
      expect(stateStart, greaterThanOrEqualTo(labelEnd));
      expect(switchStart, greaterThan(tester.getBottomRight(state).dx));
    });

    testWidgets('RTL : l\'état reste du côté du switch (AD-13)', (tester) async {
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(trueLabel: 'ACTIVÉ')),
        true,
        textDirection: TextDirection.rtl,
      ));
      // En RTL le switch passe à gauche : l'état doit le suivre (donc être à
      // GAUCHE du libellé). Rougit avec un `EdgeInsets.only(left:)` ou un `Row`
      // non directionnel.
      final stateStart = tester.getTopLeft(find.text('ACTIVÉ')).dx;
      final labelStart = tester.getTopLeft(find.text(_fieldLabel)).dx;
      final switchStart = tester.getTopLeft(find.byType(Switch)).dx;
      expect(stateStart, lessThan(labelStart));
      expect(switchStart, lessThan(stateStart));
    });
  });

  group('A11y — le texte d\'état ne DOUBLE PAS l\'annonce', () {
    testWidgets('état ACTIVÉ : 0 occurrence en sémantique, drapeau toggled=true',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(trueLabel: 'ACTIVÉ')),
        true,
      ));
      // Visible à l'écran…
      expect(find.text('ACTIVÉ'), findsOneWidget);
      // …mais ABSENT du canal sémantique : retirer `ExcludeSemantics` le fait
      // passer à 1 → rouge d'assertion.
      expect(_labelOccurrences(tester, 'ACTIVÉ'), 0);
      // L'état reste annoncé NATIVEMENT par le switch (pas de perte d'info).
      expect(_hasToggled(tester, expected: true), isTrue);
      // Le libellé du champ, lui, reste annoncé exactement une fois.
      expect(_labelOccurrences(tester, _fieldLabel), 1);
      handle.dispose();
    });

    testWidgets('état COUPÉ : 0 occurrence en sémantique, toggled=false',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(falseLabel: 'COUPÉ')),
        false,
      ));
      expect(find.text('COUPÉ'), findsOneWidget);
      expect(_labelOccurrences(tester, 'COUPÉ'), 0);
      expect(_hasToggled(tester, expected: false), isTrue);
      expect(_labelOccurrences(tester, _fieldLabel), 1);
      handle.dispose();
    });

    testWidgets('cible tactile ≥ 48 dp conservée avec le texte d\'état',
        (tester) async {
      final handle = tester.ensureSemantics();
      // Largeur LIANTE (360 dp) : le titre, l'état et le switch se disputent la
      // ligne. Mesuré par le guideline du framework, pas par `getSize()`.
      await tester.pumpWidget(_app(
        _spec(config: const ZBooleanConfig(trueLabel: 'ACTIVÉ')),
        true,
      ));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('Lecture seule', () {
    testWidgets('readOnly : switch désactivé mais texte d\'état CONSERVÉ',
        (tester) async {
      const cfg = ZBooleanConfig(trueLabel: 'ACTIVÉ', falseLabel: 'COUPÉ');
      await tester.pumpWidget(_app(_spec(config: cfg, readOnly: true), false));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      // Rougit si le texte est masqué en lecture seule.
      expect(find.text('COUPÉ'), findsOneWidget);

      await tester.pumpWidget(_app(_spec(config: cfg, readOnly: true), true));
      expect(find.text('ACTIVÉ'), findsOneWidget);
    });

    testWidgets('readOnly sans config : toujours aucun texte d\'état',
        (tester) async {
      await tester.pumpWidget(_app(_spec(readOnly: true), true));
      expect(_titleOf(tester), isA<Text>());
      expect(find.text('Yes'), findsNothing);
    });
  });

  group('Mode lecture (DP-13) — cohérence édition ↔ fiche', () {
    Widget host(ZFieldSpec field, Object? value) {
      final controller = ZFormController(
        initialValues: <String, Object?>{field.name: value},
        visibleFields: <String>[field.name],
      );
      return MaterialApp(
        home: Scaffold(
          body: _withLocale(
            const Locale('fr'),
            _CtrlHost(controller: controller, field: field),
          ),
        ),
      );
    }

    testWidgets('sans config : la fiche rend « Oui »/« Non » (inchangé)',
        (tester) async {
      await tester.pumpWidget(host(_spec(), true));
      expect(find.text('Oui'), findsOneWidget);
      await tester.pumpWidget(host(_spec(), false));
      expect(find.text('Non'), findsOneWidget);
    });

    testWidgets('avec libellés de l\'hôte : la fiche les reprend (2 sens)',
        (tester) async {
      const cfg = ZBooleanConfig(trueLabel: 'ACTIVÉ', falseLabel: 'COUPÉ');
      await tester.pumpWidget(host(_spec(config: cfg), true));
      // Rougit si la fiche ignore la config : elle afficherait « Oui ».
      expect(find.text('ACTIVÉ'), findsOneWidget);
      expect(find.text('Oui'), findsNothing);

      await tester.pumpWidget(host(_spec(config: cfg), false));
      expect(find.text('COUPÉ'), findsOneWidget);
      expect(find.text('Non'), findsNothing);
    });

    testWidgets('showStateLabel seul : la fiche garde « Oui » (l10n)',
        (tester) async {
      await tester.pumpWidget(
          host(_spec(config: const ZBooleanConfig(showStateLabel: true)), true));
      expect(find.text('Oui'), findsOneWidget);
    });
  });
}

/// Hôte possédant le controller (évite les fuites) et rendant en `readMode`.
class _CtrlHost extends StatefulWidget {
  const _CtrlHost({required this.controller, required this.field});
  final ZFormController controller;
  final ZFieldSpec field;
  @override
  State<_CtrlHost> createState() => _CtrlHostState();
}

class _CtrlHostState extends State<_CtrlHost> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZFieldWidget(
        controller: widget.controller,
        field: widget.field,
        readMode: true,
      );
}
