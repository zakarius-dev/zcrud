// CR-DODLP-BOOL-BOXED (2026-08-10) — Famille `boolean` : **encart de champ**
// optionnel (option A de la CR : opt-in, défaut strictement inchangé).
//
// Ce que ces gardes défendent, et comment elles rougissent :
//
//  * ACTIVATION — `ZBooleanConfig.boxed` défaut `false`. Rendre l'encart
//    inconditionnel rougit les gardes d'IMMOBILITÉ (aucun `InputDecorator` ne
//    doit exister dans l'arbre de l'hôte passif), et l'inhiber toujours rougit
//    les gardes d'encart. Les DEUX sens sont couverts.
//  * MÊME CHEMIN QUE LES VOISINS — la décoration de l'encart est comparée, champ
//    par champ, à celle d'un **vrai voisin monté** (`ZTextFieldWidget`) dans le
//    MÊME thème : bordure, remplissage, marge interne, rayon. Un cadre peint à
//    la main (le motif de divergence que ce dépôt combat) rougirait ici, même
//    s'il « ressemblait ».
//  * AUCUN JETON NOUVEAU — les quatre jetons lus sont ceux que la CR nomme
//    (`fieldFillColor`, `fieldBorderColor`, `inputRadius`, `inputContentPadding`)
//    et le repli sans jeton retombe sur les RÔLES du `ColorScheme` (FR-26).
//  * SÉMANTIQUE — comparaison AVANT/APRÈS : le libellé doit apparaître
//    exactement 1 fois et le porteur d'état exactement 1 fois, encart ou pas.
//    On compte les OCCURRENCES de sous-chaîne et les PORTEURS d'état, pas les
//    nœuds (un conteneur fusionne ses descendants : compter les nœuds ne
//    mordrait pas). v0.74 avait doublé l'ÉTAT, v0.75 le TITRE.
//  * CIBLE TACTILE — deux mesures de nature différente, assumées :
//     - forme `pill` : la contrainte LIANTE POSÉE (`ConstrainedBox.constraints`
//       de `zBooleanPillTargetKey`), jamais `getSize()` ;
//     - forme `switchTile` : le plancher appartient au `ListTile` de Material,
//       il n'existe aucune `ConstrainedBox` à lire. Ce que l'encart pourrait
//       casser, c'est un RÉTRÉCISSEMENT — mesuré en DIFFÉRENTIEL (hauteur avec
//       encart ≥ hauteur sans encart ≥ 48) + `androidTapTargetGuideline`.
//  * GESTE — le tap sur toute la ligne reste actif, avec et sans encart, dans
//    les deux formes.
//  * PAS DE DOUBLE CADRE — en `ZFieldSize.large` la `ZLargeFieldCard` porte
//    déjà le cadre : l'encart est inhibé. Les deux sens sont gardés.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const String _fieldLabel = 'Magasin du bord visité ?';

ZFieldSpec _spec({
  ZFieldConfig? config,
  bool readOnly = false,
  ZFieldSize fieldSize = ZFieldSize.normal,
}) =>
    ZFieldSpec(
      name: 'visited',
      type: EditionFieldType.boolean,
      label: _fieldLabel,
      readOnly: readOnly,
      fieldSize: fieldSize,
      config: config,
    );

/// Monte le champ booléen seul, avec thème optionnel.
Widget _app(
  ZFieldSpec field,
  Object? value, {
  TextDirection textDirection = TextDirection.ltr,
  double width = 360,
  ZcrudTheme? tokens,
  ColorScheme? scheme,
  ValueChanged<bool>? onChanged,
}) {
  final ColorScheme effective =
      scheme ?? ColorScheme.fromSeed(seedColor: const Color(0xFF00477D));
  return MaterialApp(
    theme: ThemeData(
      colorScheme: effective,
      extensions: <ThemeExtension<Object?>>[?tokens],
    ),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: ZBooleanFieldWidget(
              field: field,
              value: value,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

/// Monte **côte à côte** le booléen encadré et un vrai voisin `text`, dans le
/// même thème : c'est la comparaison de PARITÉ (même chaîne de décoration).
Widget _appWithNeighbour(ZFieldSpec field, {ZcrudTheme? tokens}) {
  final controller = TextEditingController();
  final focusNode = FocusNode();
  addTearDown(controller.dispose);
  addTearDown(focusNode.dispose);
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00477D)),
      extensions: <ThemeExtension<Object?>>[?tokens],
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ZBooleanFieldWidget(
                field: field,
                value: true,
                onChanged: (_) {},
              ),
              ZTextFieldWidget(
                field: const ZFieldSpec(
                  name: 'nom',
                  type: EditionFieldType.text,
                  label: 'Nom',
                ),
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Décoration RÉELLEMENT posée sur l'encart (présence assertée d'abord : sans
/// cet `expect`, une injection qui supprime l'encart rendrait un `StateError`
/// de `find` au lieu d'une ASSERTION).
InputDecoration _boxDecoration(WidgetTester tester) {
  expect(find.byKey(zBooleanBoxKey), findsOneWidget, reason: 'encart attendu');
  return tester.widget<InputDecorator>(find.byKey(zBooleanBoxKey)).decoration;
}

/// Décoration du VOISIN `text` réellement monté.
InputDecoration _neighbourDecoration(WidgetTester tester) {
  expect(find.byType(TextField), findsOneWidget, reason: 'voisin text attendu');
  return tester.widget<TextField>(find.byType(TextField)).decoration!;
}

/// Marge interne réellement posée sur le `ListTile` du champ.
EdgeInsetsGeometry? _tilePadding(WidgetTester tester) {
  expect(find.byType(ListTile), findsOneWidget, reason: 'ListTile attendu');
  return tester.widget<ListTile>(find.byType(ListTile)).contentPadding;
}

/// Nombre total d'OCCURRENCES de [needle] dans les `label` des nœuds
/// **ANNONÇABLES** — le canal réellement lu par un lecteur d'écran.
///
/// 🔴 Les nœuds `isMergedIntoParent` sont **exclus** : ce ne sont pas des
/// annonces, leur contenu est déjà porté (fusionné) par l'ancêtre. Mesuré : un
/// `SwitchListTile` produit un nœud annonçable (`label`, `toggled`) **et** un
/// nœud fusionné pour le `Switch`, dont `getSemanticsData()` reporte lui aussi
/// le drapeau — les compter tous ferait valoir 2 le comptage de base, donc une
/// garde qui ne mesure pas ce qu'elle prétend. Un doublon *à l'intérieur* de la
/// fusion reste détecté : il apparaît deux fois dans le `label` fusionné du
/// parent, que l'on compte en OCCURRENCES de sous-chaîne.
int _labelOccurrences(WidgetTester tester, String needle) {
  // `rootPipelineOwner` (le remplaçant annoncé par la dépréciation) n'expose
  // PAS de `semanticsOwner` en test : les gardes deviendraient un `_TypeError`
  // au lieu d'une assertion (mesuré en v0.74). On lit l'owner effectif.
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var count = 0;
  void walk(SemanticsNode n) {
    if (!n.isMergedIntoParent) {
      count += needle.allMatches(n.getSemanticsData().label).length;
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return count;
}

/// Nombre de nœuds ANNONÇABLES porteurs d'un état bascule (`hasToggledState`).
/// Doit valoir 1 : deux porteurs feraient annoncer l'état deux fois (le défaut
/// mesuré en v0.74). Même exclusion des nœuds fusionnés que [_labelOccurrences].
int _toggleCarriers(WidgetTester tester) {
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var count = 0;
  void walk(SemanticsNode n) {
    // `SemanticsFlags.isToggled` (le remplaçant) est un `Tristate` non
    // comparable à un `bool` : `hasFlag` reste la lecture exacte de l'état.
    // ignore: deprecated_member_use
    if (!n.isMergedIntoParent &&
        // ignore: deprecated_member_use
        n.getSemanticsData().hasFlag(SemanticsFlag.hasToggledState)) {
      count++;
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(owner.rootSemanticsNode!);
  return count;
}

/// `true` si un nœud sémantique porte le drapeau `isToggled` demandé.
bool _hasToggled(WidgetTester tester, {required bool expected}) {
  // ignore: deprecated_member_use
  final owner = tester.binding.pipelineOwner.semanticsOwner!;
  var found = false;
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    // ignore: deprecated_member_use
    final hasToggle = d.hasFlag(SemanticsFlag.hasToggledState);
    // ignore: deprecated_member_use
    final isToggled = d.hasFlag(SemanticsFlag.isToggled);
    if (!n.isMergedIntoParent && hasToggle && isToggled == expected) {
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

/// Hauteur RENDUE de la ligne (présence assertée d'abord).
double _tileHeight(WidgetTester tester) {
  expect(find.byType(ListTile), findsOneWidget, reason: 'ListTile attendu');
  return tester.getSize(find.byType(ListTile)).height;
}

void main() {
  // ══ 1. DOMAINE — surface additive ═══════════════════════════════════════

  group('ZBooleanConfig.boxed (domaine)', () {
    test('défaut : false (rétro-compat stricte)', () {
      expect(const ZBooleanConfig().boxed, isFalse);
      expect(const ZBooleanConfig(style: ZBooleanStyle.pill).boxed, isFalse);
    });

    test('R3 : égalité/hash discriminent boxed', () {
      const base = ZBooleanConfig();
      expect(base, isNot(const ZBooleanConfig(boxed: true)));
      expect(
        base.hashCode,
        isNot(const ZBooleanConfig(boxed: true).hashCode),
      );
      expect(
        const ZBooleanConfig(boxed: true),
        equals(const ZBooleanConfig(boxed: true)),
      );
    });
  });

  // ══ 2. IMMOBILITÉ DE L'HÔTE PASSIF ══════════════════════════════════════

  group('Hôte passif — rendu v0.75 strictement inchangé', () {
    testWidgets('sans config : AUCUN encart dans l\'arbre', (t) async {
      await t.pumpWidget(_app(_spec(), true));
      expect(find.byKey(zBooleanBoxKey), findsNothing);
      // Structurel : pas seulement « pas notre clé » — AUCUN décorateur.
      expect(find.byType(InputDecorator), findsNothing);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    testWidgets('config posée mais boxed absent : aucun encart (3 cas)',
        (t) async {
      for (final cfg in const <ZBooleanConfig>[
        ZBooleanConfig(),
        ZBooleanConfig(showStateLabel: true),
        ZBooleanConfig(style: ZBooleanStyle.pill),
      ]) {
        await t.pumpWidget(_app(_spec(config: cfg), true));
        expect(find.byType(InputDecorator), findsNothing,
            reason: 'aucun encart attendu pour $cfg');
      }
    });

    testWidgets('sans encart : marge du ListTile = 16 dp directionnels',
        (t) async {
      await t.pumpWidget(_app(_spec(), true));
      expect(
        _tilePadding(t),
        const EdgeInsetsDirectional.symmetric(horizontal: 16),
      );
      // Même valeur en forme pilule (le chemin v0.75 est le même).
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)), true),
      );
      expect(
        _tilePadding(t),
        const EdgeInsetsDirectional.symmetric(horizontal: 16),
      );
    });
  });

  // ══ 3. L'ENCART — MÊME CHEMIN QUE LES VOISINS ═══════════════════════════

  group('Encart — décoration issue de la fabrique du thème', () {
    testWidgets('boxed:true monte UN encart, les deux formes', (t) async {
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true),
      );
      expect(find.byKey(zBooleanBoxKey), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);

      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(
              boxed: true,
              style: ZBooleanStyle.pill,
            ),
          ),
          true,
        ),
      );
      expect(find.byKey(zBooleanBoxKey), findsOneWidget);
      // La PILULE ne bouge pas : elle reste montée à l'intérieur de l'encart.
      expect(find.byKey(zBooleanPillKey), findsOneWidget);
    });

    testWidgets(
        'PARITÉ VOISIN : bordure / remplissage / marge / rayon IDENTIQUES à ceux '
        'du champ text monté dans le même thème', (t) async {
      const tokens = ZcrudTheme(
        fieldFillColor: Color(0xFFFFFFFF),
        fieldBorderColor: Color(0xFF9E9E9E),
        inputRadius: Radius.circular(12),
        inputContentPadding:
            EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 16),
      );
      await t.pumpWidget(
        _appWithNeighbour(
          _spec(config: const ZBooleanConfig(boxed: true)),
          tokens: tokens,
        ),
      );
      final box = _boxDecoration(t);
      final neighbour = _neighbourDecoration(t);

      expect(box.enabledBorder, neighbour.enabledBorder);
      expect(box.border, neighbour.border);
      expect(box.filled, neighbour.filled);
      expect(box.fillColor, neighbour.fillColor);
      // CR-BOOL-BOXED-HEIGHT (2026-08-10) : la marge HORIZONTALE reste celle du
      // voisin — c'est elle qui aligne les contenus. La VERTICALE, elle, est
      // délibérément nulle côté encart : le `ListTile` porte déjà sa hauteur de
      // ligne, et les cumuler rendait la carte 32 dp plus haute que le voisin.
      // La PARITÉ DE HAUTEUR qui en résulte est mesurée, sur les deux rendus
      // réels, dans `cr_boolean_label_weight_and_height_test.dart`.
      final boxPad = box.contentPadding! as EdgeInsetsDirectional;
      final neighbourPad = neighbour.contentPadding! as EdgeInsetsDirectional;
      expect(boxPad.start, neighbourPad.start);
      expect(boxPad.end, neighbourPad.end);
      expect(boxPad.top, 0);
      expect(boxPad.bottom, 0);
      // La garde n'est pas vacante : le voisin, lui, a bien une marge verticale.
      expect(neighbourPad.top, greaterThan(0));
    });

    testWidgets('les QUATRE jetons de la CR pilotent l\'encart', (t) async {
      const tokens = ZcrudTheme(
        fieldFillColor: Color(0xFF0A0B0C),
        fieldBorderColor: Color(0xFF010203),
        inputRadius: Radius.circular(21),
        inputContentPadding:
            EdgeInsetsDirectional.fromSTEB(7, 9, 11, 13),
      );
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true,
            tokens: tokens),
      );
      final d = _boxDecoration(t);
      final border = d.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.color, const Color(0xFF010203));
      expect(border.borderRadius, const BorderRadius.all(Radius.circular(21)));
      expect(d.fillColor, const Color(0xFF0A0B0C));
      // CR-BOOL-BOXED-HEIGHT : start/end DÉRIVÉS du jeton (7 et 11 traversent),
      // top/bottom nuls (la ligne porte déjà sa hauteur).
      expect(
        d.contentPadding,
        const EdgeInsetsDirectional.fromSTEB(7, 0, 11, 0),
      );
      // AD-13 : marge DIRECTIONNELLE (jamais `EdgeInsets.only(left:)`).
      expect(d.contentPadding, isA<EdgeInsetsDirectional>());
    });

    testWidgets('sans jeton : repli sur les RÔLES du ColorScheme (FR-26)',
        (t) async {
      final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00477D));
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true,
            scheme: scheme),
      );
      final d = _boxDecoration(t);
      expect((d.enabledBorder! as OutlineInputBorder).borderSide.color,
          scheme.outline);
      expect(d.fillColor, scheme.surfaceContainerHighest);
    });

    testWidgets('AUCUN libellé dans la décoration (pas de doublon visuel)',
        (t) async {
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true),
      );
      final d = _boxDecoration(t);
      expect(d.label, isNull);
      expect(d.labelText, isNull);
      // Le libellé du champ est rendu UNE fois, par le `ListTile`.
      expect(find.text(_fieldLabel), findsOneWidget);
    });

    testWidgets('avec encart : marge du ListTile = zéro (16 dp au total)',
        (t) async {
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true),
      );
      expect(_tilePadding(t), EdgeInsetsDirectional.zero);
    });

    testWidgets('lecture seule : l\'encart garde la bordure de l\'hôte',
        (t) async {
      const tokens = ZcrudTheme(fieldBorderColor: Color(0xFF010203));
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(boxed: true), readOnly: true),
          true,
          tokens: tokens,
        ),
      );
      final d = _boxDecoration(t);
      expect(d.enabled, isTrue,
          reason: '`enabled:false` ferait tomber la bordure sur `disabledBorder`, '
              'hors de la chaîne de jetons');
      expect((d.enabledBorder! as OutlineInputBorder).borderSide.color,
          const Color(0xFF010203));
    });
  });

  // ══ 4. PAS DE DOUBLE CADRE (ZFieldSize.large) ═══════════════════════════

  group('ZFieldSize.large — encart inhibé (la Card porte déjà le cadre)', () {
    testWidgets('large + boxed : AUCUN encart', (t) async {
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(boxed: true),
            fieldSize: ZFieldSize.large,
          ),
          true,
        ),
      );
      expect(find.byType(InputDecorator), findsNothing);
      // Et la marge du ListTile reste celle d'origine.
      expect(
        _tilePadding(t),
        const EdgeInsetsDirectional.symmetric(horizontal: 16),
      );
    });

    testWidgets('normal + boxed : encart présent (2ᵉ sens)', (t) async {
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(boxed: true),
            fieldSize: ZFieldSize.normal,
          ),
          true,
        ),
      );
      expect(find.byKey(zBooleanBoxKey), findsOneWidget);
    });
  });

  // ══ 5. SÉMANTIQUE — COMPARAISON AVANT / APRÈS ═══════════════════════════

  group('A11y — l\'encart n\'ajoute NI doublon NI porteur d\'état', () {
    testWidgets('switchTile : 1 libellé, 1 porteur d\'état, AVANT et APRÈS',
        (t) async {
      final handle = t.ensureSemantics();
      for (final checked in <bool>[true, false]) {
        await t.pumpWidget(_app(_spec(), checked));
        expect(_labelOccurrences(t, _fieldLabel), 1,
            reason: 'AVANT (sans encart), checked=$checked');
        expect(_toggleCarriers(t), 1, reason: 'AVANT, checked=$checked');
        expect(_hasToggled(t, expected: checked), isTrue);
        // La garde n'est pas vacante : le drapeau DISCRIMINE.
        expect(_hasToggled(t, expected: !checked), isFalse);

        await t.pumpWidget(
          _app(_spec(config: const ZBooleanConfig(boxed: true)), checked),
        );
        expect(_labelOccurrences(t, _fieldLabel), 1,
            reason: 'APRÈS (avec encart), checked=$checked');
        expect(_toggleCarriers(t), 1, reason: 'APRÈS, checked=$checked');
        expect(_hasToggled(t, expected: checked), isTrue);
        expect(_hasToggled(t, expected: !checked), isFalse);
      }
      handle.dispose();
    });

    testWidgets('pill : 1 libellé, 1 porteur d\'état, AVANT et APRÈS',
        (t) async {
      final handle = t.ensureSemantics();
      for (final checked in <bool>[true, false]) {
        await t.pumpWidget(
          _app(
            _spec(config: const ZBooleanConfig(style: ZBooleanStyle.pill)),
            checked,
          ),
        );
        expect(_labelOccurrences(t, _fieldLabel), 1, reason: 'AVANT pill');
        expect(_toggleCarriers(t), 1, reason: 'AVANT pill');

        await t.pumpWidget(
          _app(
            _spec(
              config: const ZBooleanConfig(
                boxed: true,
                style: ZBooleanStyle.pill,
              ),
            ),
            checked,
          ),
        );
        expect(_labelOccurrences(t, _fieldLabel), 1, reason: 'APRÈS pill');
        expect(_toggleCarriers(t), 1, reason: 'APRÈS pill');
        expect(_hasToggled(t, expected: checked), isTrue);
        expect(_hasToggled(t, expected: !checked), isFalse);
      }
      handle.dispose();
    });

    testWidgets('encart : le texte d\'état reste DÉCORATIF (0 occurrence)',
        (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(
              boxed: true,
              trueLabel: 'ACTIVÉ',
              falseLabel: 'COUPÉ',
            ),
          ),
          true,
        ),
      );
      expect(find.text('ACTIVÉ'), findsOneWidget); // visible
      expect(_labelOccurrences(t, 'ACTIVÉ'), 0); // mais pas annoncé
      handle.dispose();
    });
  });

  // ══ 6. CIBLE TACTILE ════════════════════════════════════════════════════

  group('AD-13 — plancher tactile préservé par l\'encart', () {
    testWidgets(
        'pill + encart : la contrainte LIANTE POSÉE reste 48 dp '
        '(lue sur ConstrainedBox.constraints, jamais getSize)', (t) async {
      await t.pumpWidget(
        _app(
          _spec(
            config: const ZBooleanConfig(
              boxed: true,
              style: ZBooleanStyle.pill,
            ),
          ),
          true,
        ),
      );
      expect(find.byKey(zBooleanPillTargetKey), findsOneWidget);
      final constraints = t
          .widget<ConstrainedBox>(find.byKey(zBooleanPillTargetKey))
          .constraints;
      expect(constraints.minHeight, greaterThanOrEqualTo(48.0));
      expect(constraints.minWidth, greaterThanOrEqualTo(48.0));
    });

    testWidgets(
        'switchTile : l\'encart ne RÉTRÉCIT pas la ligne (différentiel) et '
        'la cible reste ≥ 48 dp', (t) async {
      await t.pumpWidget(_app(_spec(), true));
      final plain = _tileHeight(t);
      expect(plain, greaterThanOrEqualTo(48.0));

      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true),
      );
      final boxed = _tileHeight(t);
      expect(boxed, greaterThanOrEqualTo(plain),
          reason: 'l\'encart ne doit jamais comprimer la ligne');
      expect(boxed, greaterThanOrEqualTo(48.0));
    });

    testWidgets('switchTile + encart : androidTapTargetGuideline', (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(
        _app(_spec(config: const ZBooleanConfig(boxed: true)), true),
      );
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  // ══ 7. GESTE — le tap sur toute la ligne survit ═════════════════════════

  group('Le tap sur la LIGNE reste actif sous l\'encart', () {
    testWidgets('switchTile : tap sur le LIBELLÉ bascule, avec et sans encart',
        (t) async {
      for (final boxed in <bool>[false, true]) {
        final writes = <bool>[];
        await t.pumpWidget(
          _app(
            _spec(config: ZBooleanConfig(boxed: boxed)),
            false,
            onChanged: writes.add,
          ),
        );
        await t.tap(find.text(_fieldLabel));
        await t.pump();
        expect(writes, <bool>[true], reason: 'boxed=$boxed');
      }
    });

    testWidgets('pill : tap sur le LIBELLÉ bascule, avec et sans encart',
        (t) async {
      for (final boxed in <bool>[false, true]) {
        final writes = <bool>[];
        await t.pumpWidget(
          _app(
            _spec(
              config: ZBooleanConfig(boxed: boxed, style: ZBooleanStyle.pill),
            ),
            true,
            onChanged: writes.add,
          ),
        );
        await t.tap(find.text(_fieldLabel));
        await t.pump();
        expect(writes, <bool>[false], reason: 'boxed=$boxed');
      }
    });

    testWidgets('lecture seule + encart : aucune écriture', (t) async {
      final writes = <bool>[];
      await t.pumpWidget(
        _app(
          _spec(config: const ZBooleanConfig(boxed: true), readOnly: true),
          false,
          onChanged: writes.add,
        ),
      );
      await t.tap(find.text(_fieldLabel), warnIfMissed: false);
      await t.pump();
      expect(writes, isEmpty);
    });
  });
}
