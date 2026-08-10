// CR-DODLP-INTL-DECORATION-2 (2026-08-10) — les DEUX champs `zcrud_intl` restés
// hors du lot v0.76.0 (`ZCurrencyField`, `ZStateField`) passent à leur tour par
// la décoration THÉMÉE du cœur (`zFieldDecoration` → `ZcrudTheme.inputDecoration`).
//
// 🔴 Ligne de base MESURÉE avant écriture (sonde supprimée, cf. rapport) — c'est
// elle qui fixe les comptes assertés ici, jamais une présomption :
//
//   | cas (libellé du champ = « Téléphone ») | nœud AVANT | occ. AVANT |
//   |---|---|---|
//   | devise (sans montant) / normal | conteneur `"Téléphone|Téléphone"` → trigger `"Devise"` | 1 |
//   | devise (sans montant) / large  | Card `"Téléphone"` + conteneur `"Téléphone|Téléphone"` → trigger `"Devise"` | 2 |
//   | devise + montant / normal      | `"Téléphone|Téléphone|Montant"` → trigger `"Devise"` | 1 |
//   | devise + montant / large       | Card + `"Téléphone|Téléphone|Montant"` → trigger `"Devise"` | 2 |
//   | état (sélecteur) / normal      | conteneur `"Téléphone|Téléphone"` → trigger `"État/Province"` | 1 |
//   | état (sélecteur) / large       | Card + conteneur `"Téléphone|Téléphone"` → trigger | 2 |
//   | état (repli texte) / normal    | `"Téléphone|Téléphone|État/Province"` | 1 |
//   | état (repli texte) / large     | Card + `"Téléphone|Téléphone|État/Province"` | 2 |
//
// Le doublon annoncé par le lot précédent était donc, ici encore, **plus** qu'un
// doublon : le `Semantics(container:)` du champ ET le `Text` externe se fondent
// en UN nœud (2 occurrences du libellé), auxquelles s'ajoutent le libellé
// interne du sous-champ (montant / repli texte) et, en `large`, la Card.
//
// Géométrie mesurée AVANT (trois champs du MÊME formulaire) :
//   TEXT (cœur) 12→788 = 776 dp · devise 24→776 = 752 dp · état 24→776 = 752 dp
// ⇒ le `Padding(ZcrudTheme.fieldPadding)` rendait ces champs 24 dp plus étroits
//   que leurs voisins ; APRÈS : 12→788 pour les trois.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

const Color _fill = Color(0xFF102030);
const Color _border = Color(0xFF405060);
const Color _focus = Color(0xFF708090);
const Radius _radius = Radius.circular(21);

/// Thème de test : uniquement des jetons **déjà existants** (aucun jeton neuf).
const ZcrudTheme _tokens = ZcrudTheme(
  fieldFillColor: _fill,
  fieldBorderColor: _border,
  fieldFocusedBorderColor: _focus,
  inputRadius: _radius,
);

ZCurrencyCatalog _currencies() =>
    ZCurrencyCatalog.fromList(const <ZCurrencyInfo>[
      ZCurrencyInfo(code: 'XOF', name: 'Franc CFA', symbol: 'CFA'),
      ZCurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€'),
    ]);

ZSubdivisionCatalog _subdivisions() =>
    ZSubdivisionCatalog.fromMap(const <String, List<ZSubdivision>>{
      'FR': <ZSubdivision>[
        ZSubdivision(countryIso: 'FR', code: 'FR-75', name: 'Paris'),
      ],
    });

/// Monte le champ composable [builder] sous le `kind` `custom`, DANS
/// `DynamicEdition` — seul montage où `ZLargeFieldCard` (mode `bare`) existe.
Future<void> _pump(
  WidgetTester tester,
  ZFieldWidgetBuilder builder, {
  ZFieldSize size = ZFieldSize.normal,
  Object? value,
  ZcrudTheme? theme = _tokens,
  bool required = false,
}) async {
  final controller = ZFormController(
    initialValues: <String, Object?>{'f': value},
    visibleFields: const <String>['f'],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: ZcrudScope(
      theme: theme,
      widgetRegistry: ZWidgetRegistry()..register('custom', builder),
      child: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: <ZFieldSpec>[
            ZFieldSpec(
              name: 'f',
              type: EditionFieldType.custom,
              label: 'Téléphone',
              fieldSize: size,
              validators: required
                  ? const <ZValidatorSpec>[ZValidatorSpec.required()]
                  : const <ZValidatorSpec>[],
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

ZFieldWidgetBuilder _currency({bool showAmount = false}) =>
    ZCurrencyField.builder(catalog: _currencies(), showAmount: showAmount);

ZFieldWidgetBuilder _statePicker() =>
    ZStateField.builder(catalog: _subdivisions(), countryIso: 'FR');

ZFieldWidgetBuilder _stateFree() =>
    ZStateField.builder(catalog: _subdivisions());

InputDecoration _triggerDecoration(WidgetTester tester, Key key) => tester
    .widget<InputDecorator>(find.descendant(
      of: find.byKey(key),
      matching: find.byType(InputDecorator),
    ))
    .decoration;

InputDecoration _fieldDecoration(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).decoration!;

Color _restBorderColor(InputDecoration d) =>
    (d.enabledBorder! as OutlineInputBorder).borderSide.color;

BorderRadius _borderRadius(InputDecoration d) =>
    (d.enabledBorder! as OutlineInputBorder).borderRadius;

/// 🔴 AD-13 : cible tactile lue sur la contrainte **LIANTE NOMMÉE** posée par
/// NOTRE widget — jamais `getSize()`, jamais le maximum des `ConstrainedBox`
/// descendants (motif daté 2026-08-10 : une garde du paquet mesurait ainsi le
/// plancher d'un widget TIERS et restait verte sous injection).
double _bindingMinHeight(WidgetTester tester, Key key) =>
    tester.widget<ConstrainedBox>(find.byKey(key)).constraints.minHeight;

/// Annonce **effective** d'un nœud : `SemanticsData.label`, c'est-à-dire ce que
/// le lecteur d'écran prononce réellement (fusion des descendants comprise).
///
/// 🔴 Motif daté (2026-08-10, ce lot) : `SemanticsNode.label` — le label *propre*
/// du nœud — vaut `'Téléphone\n'` sur le conteneur du groupe devise **dès la
/// ligne de base**, artefact de fusion d'un descendant sans libellé. Une garde
/// écrite sur `node.label` aurait donc été rouge sans défaut, ou (pire, en
/// l'assouplissant) verte par accident. On mesure l'annonce, jamais le nœud.
String _announced(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData().label;

/// Nombre d'**occurrences** de [needle] dans [haystack] (jamais un nombre de
/// nœuds : le doublon mesuré vivait DANS un seul nœud).
int _occurrences(String haystack, String needle) =>
    needle.allMatches(haystack).length;

void main() {
  group('CR-INTL-DECO2-1 · jetons EXISTANTS honorés (aucun jeton nouveau)', () {
    testWidgets('devise : le déclencheur est un InputDecorator thémé',
        (tester) async {
      await _pump(tester, _currency(), value: 'EUR');
      final d = _triggerDecoration(tester, const Key('z-currency-trigger'));
      expect(d.fillColor, _fill, reason: 'fieldFillColor doit atteindre la devise');
      expect(_restBorderColor(d), _border, reason: 'fieldBorderColor au repos');
      expect(_borderRadius(d), const BorderRadius.all(_radius),
          reason: 'inputRadius doit piloter le rayon');
      expect(d.suffixIcon, isA<Icon>(),
          reason: 'le chevron d\'affordance reste posé, mais DANS le cadre');
    });

    testWidgets('devise + montant : le sous-champ montant est décoré lui aussi',
        (tester) async {
      await _pump(tester, _currency(showAmount: true));
      final d = _fieldDecoration(tester, const Key('z-currency-amount'));
      expect(d.fillColor, _fill);
      expect(_restBorderColor(d), _border);
      expect(_borderRadius(d), const BorderRadius.all(_radius));
      expect(
        (d.focusedBorder! as OutlineInputBorder).borderSide.color,
        _focus,
        reason: 'fieldFocusedBorderColor sur le focus',
      );
    });

    testWidgets('état (sélecteur) : déclencheur thémé', (tester) async {
      await _pump(tester, _statePicker(), value: 'FR-75');
      final d = _triggerDecoration(tester, const Key('z-state-trigger'));
      expect(d.fillColor, _fill);
      expect(_restBorderColor(d), _border);
      expect(_borderRadius(d), const BorderRadius.all(_radius));
    });

    testWidgets('état (repli texte) : TextField thémé', (tester) async {
      await _pump(tester, _stateFree());
      final d = _fieldDecoration(tester, const Key('z-state-free'));
      expect(d.fillColor, _fill);
      expect(_restBorderColor(d), _border);
      expect(_borderRadius(d), const BorderRadius.all(_radius));
    });
  });

  group('CR-INTL-DECO2-2 · UN SEUL libellé (comptes MESURÉS, pas présumés)', () {
    testWidgets('devise : le nœud annonce le libellé UNE fois (avant : deux)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _currency(), value: 'EUR');
      // 🔴 Égalité STRICTE sur l'annonce EFFECTIVE : le doublon mesuré valait
      // « Téléphone\nTéléphone » — un `contains` l'aurait laissé passer.
      expect(_announced(tester, find.byKey(const Key('z-currency-trigger'))),
          'Téléphone');
      expect(
          tester
              .getSemantics(find.byKey(const Key('z-currency-trigger')))
              .getSemanticsData()
              .value,
          'Euro');
      // « Devise » ne re-nomme plus la catégorie par-dessus le libellé du champ.
      expect(find.text('Devise'), findsNothing);
      // …et le libellé n'est RENDU qu'une fois (libellé flottant).
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('devise : le libellé flottant est le ZFieldLabel du cœur '
        '(astérisque requis inclus)', (tester) async {
      await _pump(tester, _currency(), required: true);
      final d = _triggerDecoration(tester, const Key('z-currency-trigger'));
      expect(d.label, isA<ZFieldLabel>());
      expect(d.labelText, isNull,
          reason: 'label (Widget) et labelText sont mutuellement exclusifs');
      expect(find.text(' *'), findsOneWidget,
          reason: 'astérisque « requis » du cœur, décoratif');
    });

    testWidgets('devise + montant (GROUPE) : libellé du groupe rendu UNE fois, '
        'sous-champs nommés UNE fois chacun', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _currency(showAmount: true));
      // 🔴 Occurrences RENDUES (pas des nœuds) : le libellé du groupe était
      // rendu 1× et annoncé 2× ; il est désormais rendu ET annoncé 1×.
      expect(find.text('Téléphone'), findsOneWidget);
      expect(find.text('Devise'), findsOneWidget);
      expect(find.text('Montant'), findsOneWidget);
      // Annonce EFFECTIVE du conteneur, mesurée : « Téléphone » (le groupe) +
      // « Montant » (le sous-champ montant, qui n'est pas une frontière
      // sémantique et fusionne dans le conteneur). Le libellé du groupe y
      // apparaît UNE fois — avant ce lot : DEUX (`Téléphone\nTéléphone\nMontant`).
      final group = _announced(tester, find.byType(ZCurrencyField));
      expect(_occurrences(group, 'Téléphone'), 1,
          reason: 'en-tête décoratif (ExcludeSemantics) : le conteneur seul '
              'annonce le libellé du groupe — annonce mesurée « $group »');
      expect(group, 'Téléphone\nMontant');
      expect(_announced(tester, find.byKey(const Key('z-currency-trigger'))),
          'Devise',
          reason: 'sous-champ du groupe : son libellé PROPRE, jamais celui '
              'du groupe');
      handle.dispose();
    });

    testWidgets('état (sélecteur) : le nœud annonce le libellé UNE fois',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _statePicker(), value: 'FR-75');
      expect(_announced(tester, find.byKey(const Key('z-state-trigger'))),
          'Téléphone');
      expect(
          tester
              .getSemantics(find.byKey(const Key('z-state-trigger')))
              .getSemanticsData()
              .value,
          'Paris');
      expect(find.text('État/Province'), findsNothing);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('état (repli texte) : le nœud annonce le libellé UNE fois '
        '(avant : « Téléphone|Téléphone|État/Province »)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _stateFree());
      expect(_announced(tester, find.byKey(const Key('z-state-free'))),
          'Téléphone');
      expect(find.text('État/Province'), findsNothing);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CR-INTL-DECO2-3 · mode `bare` (fieldSize.large) — parité cœur mesurée',
      () {
    testWidgets('devise : bordures none, aucun libellé propre, libellé rendu '
        'une seule fois (par la Card)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _currency(), size: ZFieldSize.large, value: 'EUR');
      final d = _triggerDecoration(tester, const Key('z-currency-trigger'));
      expect(d.border, InputBorder.none);
      expect(d.enabledBorder, InputBorder.none);
      expect(d.focusedBorder, InputBorder.none);
      expect(d.filled, isFalse);
      expect(d.label, isNull);
      expect(d.labelText, isNull);
      // Parité mesurée avec `text`/`select` du cœur en `large` : le nœud du
      // champ ne porte AUCUN libellé, la Card ancêtre le porte.
      expect(_announced(tester, find.byKey(const Key('z-currency-trigger'))),
          isEmpty,
          reason: 'sinon la Card ET le déclencheur annoncent le libellé');
      // 🔴 En `bare` la Card n'affiche rien d'autre : la VALEUR doit rester
      // visible dans le corps (règle reprise de ZDecoratedFieldTrigger).
      expect(find.text('Euro'), findsOneWidget);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('devise + montant : en-tête retiré, sous-champs TOUJOURS '
        'décorés et nommés', (tester) async {
      await _pump(tester, _currency(showAmount: true), size: ZFieldSize.large);
      // Le libellé du groupe n'est rendu QUE par la Card.
      expect(find.text('Téléphone'), findsOneWidget);
      // 🔴 Les sous-champs ne sont JAMAIS `bare` : leur libellé n'est porté par
      // personne d'autre.
      final d = _fieldDecoration(tester, const Key('z-currency-amount'));
      expect(d.enabledBorder, isA<OutlineInputBorder>());
      expect(d.fillColor, _fill);
      expect(find.text('Montant'), findsOneWidget);
      expect(find.text('Devise'), findsOneWidget);
    });

    testWidgets('état (sélecteur) : bordures none et libellé porté par la Card',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _statePicker(),
          size: ZFieldSize.large, value: 'FR-75');
      final d = _triggerDecoration(tester, const Key('z-state-trigger'));
      expect(d.border, InputBorder.none);
      expect(d.filled, isFalse);
      expect(d.label, isNull);
      expect(_announced(tester, find.byKey(const Key('z-state-trigger'))),
          isEmpty);
      expect(find.text('Paris'), findsOneWidget);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('état (repli texte) : bordures none et aucun libellé propre',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _stateFree(), size: ZFieldSize.large);
      final d = _fieldDecoration(tester, const Key('z-state-free'));
      expect(d.border, InputBorder.none);
      expect(d.filled, isFalse);
      expect(d.label, isNull);
      expect(d.labelText, isNull);
      expect(_announced(tester, find.byKey(const Key('z-state-free'))), isEmpty);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });
  });

  group('CR-INTL-DECO2-4 · AD-10 — sans thème, repli ColorScheme, aucun throw',
      () {
    testWidgets('les 2 champs se montent sans ZcrudTheme et retombent sur '
        'ColorScheme', (tester) async {
      for (final builder in <ZFieldWidgetBuilder>[
        _currency(showAmount: true),
        _statePicker(),
        _stateFree(),
      ]) {
        await _pump(tester, builder, theme: null);
        expect(tester.takeException(), isNull, reason: 'AD-10');
      }
      // Dernier montage : état en repli texte. Bordure = rôle `outline`.
      final scheme =
          Theme.of(tester.element(find.byType(ZStateField))).colorScheme;
      final d = _fieldDecoration(tester, const Key('z-state-free'));
      expect(_restBorderColor(d), scheme.outline);
      expect(d.fillColor, scheme.surfaceContainerHighest);
    });
  });

  group('CR-INTL-DECO2-5 · AD-13 — cible tactile LIANTE conservée', () {
    testWidgets('devise (déclencheur + montant) et état gardent minHeight ≥ 48',
        (tester) async {
      await _pump(tester, _currency(showAmount: true));
      expect(_bindingMinHeight(tester, const Key('z-currency-tap-target')),
          greaterThanOrEqualTo(48));
      expect(
          _bindingMinHeight(tester, const Key('z-currency-amount-tap-target')),
          greaterThanOrEqualTo(48));
      await _pump(tester, _statePicker(), value: 'FR-75');
      expect(_bindingMinHeight(tester, const Key('z-state-tap-target')),
          greaterThanOrEqualTo(48));
      await _pump(tester, _stateFree());
      expect(_bindingMinHeight(tester, const Key('z-state-tap-target')),
          greaterThanOrEqualTo(48));
    });
  });

  group('CR-INTL-DECO2-6 · géométrie — alignement sur les champs du cœur', () {
    testWidgets('devise et état ne sont plus 24 dp plus étroits que le `text` '
        'voisin', (tester) async {
      final controller = ZFormController(
        initialValues: const <String, Object?>{},
        visibleFields: const <String>['t', 'c', 's'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          theme: _tokens,
          widgetRegistry: ZWidgetRegistry()
            ..register('custom', _currency())
            ..register('icon', _stateFree()),
          child: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: const <ZFieldSpec>[
                ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
                ZFieldSpec(name: 'c', type: EditionFieldType.custom, label: 'C'),
                ZFieldSpec(name: 's', type: EditionFieldType.icon, label: 'S'),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final core = tester.getRect(find.byType(TextField).first).width;
      expect(tester.getRect(find.byKey(const Key('z-currency-trigger'))).width,
          core,
          reason: 'mesuré AVANT : 752 dp contre 776 dp (Padding(fieldPadding))');
      expect(tester.getRect(find.byKey(const Key('z-state-free'))).width, core,
          reason: 'mesuré AVANT : 752 dp contre 776 dp (Padding(fieldPadding))');
    });
  });
}
