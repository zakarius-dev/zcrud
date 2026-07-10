// AC1/AC6/AC13 — ZIntlFieldConfig lue par-champ par phoneNumber/country/address
// (défaut national surchargeable) + intégration adresse (région → sélecteur
// d'état si subdivisions). Rétro-compat E11a-2 STRICTE : config == null → chemins
// et rendu identiques.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

ZCountryCatalog _countries() => ZCountryCatalog.fromList(const <ZCountryInfo>[
      ZCountryInfo(isoCode: 'NE', name: 'Niger', dialCode: '+227', flagEmoji: '🇳🇪'),
      ZCountryInfo(isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
    ]);

ZSubdivisionCatalog _subs() =>
    ZSubdivisionCatalog.fromMap(<String, List<ZSubdivision>>{
      'NE': const <ZSubdivision>[
        ZSubdivision(code: 'NE-2', countryIso: 'NE', name: 'Diffa'),
        ZSubdivision(code: 'NE-8', countryIso: 'NE', name: 'Niamey'),
      ],
    });

ZFieldSpec _field(EditionFieldType type, {ZFieldConfig? config, String? label}) =>
    ZFieldSpec(name: 'f', type: type, label: label ?? 'f', config: config);

ZFormController _ctrl({Object? value}) => ZFormController(
      initialValues: <String, Object?>{'f': value},
      visibleFields: <String>['f'],
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field,
  ZWidgetRegistry registry,
) =>
    MaterialApp(
      home: ZcrudScope(
        widgetRegistry: registry,
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[field],
          ),
        ),
      ),
    );

void main() {
  group('AC1 — défaut national surchargeable lu par-champ', () {
    testWidgets('country : config.defaultCountryIso amorce la sélection',
        (t) async {
      final reg = ZWidgetRegistry()
        ..register('country', ZCountryFieldWidget.builder(catalog: _countries()));
      await t.pumpWidget(_app(
        _ctrl(),
        _field(EditionFieldType.country,
            config: const ZIntlFieldConfig(defaultCountryIso: 'NE')),
        reg,
      ));
      await t.pump();
      expect(find.text('Niger'), findsWidgets);
    });

    testWidgets('phone : config.defaultCountryIso amorce l\'indicatif',
        (t) async {
      final reg = ZWidgetRegistry()
        ..register('phoneNumber',
            ZPhoneFieldWidget.builder(catalog: _countries()));
      await t.pumpWidget(_app(
        _ctrl(),
        _field(EditionFieldType.phoneNumber,
            config: const ZIntlFieldConfig(defaultCountryIso: 'FR')),
        reg,
      ));
      await t.pump();
      expect(find.text('+33'), findsWidgets);
    });

    testWidgets('address : config.defaultCountryIso amorce le pays', (t) async {
      final reg = ZWidgetRegistry()
        ..register('address', ZAddressFieldWidget.builder(catalog: _countries()));
      await t.pumpWidget(_app(
        _ctrl(),
        _field(EditionFieldType.address,
            config: const ZIntlFieldConfig(defaultCountryIso: 'NE')),
        reg,
      ));
      await t.pump();
      expect(find.text('Niger'), findsWidgets);
    });
  });

  group('AC1/AC13 — rétro-compat E11a-2 STRICTE (config == null)', () {
    testWidgets('country sans config → placeholder (aucun défaut)', (t) async {
      final reg = ZWidgetRegistry()
        ..register('country', ZCountryFieldWidget.builder(catalog: _countries()));
      await t.pumpWidget(
          _app(_ctrl(), _field(EditionFieldType.country), reg));
      await t.pump();
      expect(find.text('Niger'), findsNothing);
      expect(find.text('France'), findsNothing);
    });

    testWidgets('phone sans config → aucun indicatif présélectionné', (t) async {
      final reg = ZWidgetRegistry()
        ..register('phoneNumber',
            ZPhoneFieldWidget.builder(catalog: _countries()));
      await t.pumpWidget(
          _app(_ctrl(), _field(EditionFieldType.phoneNumber), reg));
      await t.pump();
      expect(find.text('+33'), findsNothing);
      expect(find.text('+227'), findsNothing);
    });

    testWidgets('config d\'un AUTRE type (non-intl) ignorée → chemin E11a-2',
        (t) async {
      final reg = ZWidgetRegistry()
        ..register('country', ZCountryFieldWidget.builder(catalog: _countries()));
      // Une config non-ZIntlFieldConfig ne doit pas influencer le champ.
      await t.pumpWidget(_app(
        _ctrl(),
        _field(EditionFieldType.country, config: const ZNumberConfig()),
        reg,
      ));
      await t.pump();
      expect(find.text('Niger'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

  group('AC6 — intégration adresse : région → sélecteur d\'état', () {
    testWidgets('pays avec subdivisions → sélecteur d\'état ; sélection → région',
        (t) async {
      final reg = ZWidgetRegistry()
        ..register(
            'address',
            ZAddressFieldWidget.builder(
                catalog: _countries(), subdivisionCatalog: _subs()));
      final c = _ctrl(value: const ZPostalAddress(countryCode: 'NE'));
      await t.pumpWidget(_app(c, _field(EditionFieldType.address), reg));
      await t.pump();
      expect(find.byKey(const Key('z-address-state-trigger')), findsOneWidget);
      expect(find.byKey(const Key('z-address-region')), findsNothing);
      await t.tap(find.byKey(const Key('z-address-state-trigger')));
      await t.pump();
      await t.tap(find.byKey(const Key('z-address-state-item-NE-2')));
      await t.pump();
      final v = c.valueOf('f')! as ZPostalAddress;
      expect(v.region, 'NE-2');
      expect(v.countryCode, 'NE');
    });

    testWidgets('pays sans subdivision → région texte libre (emet adresse)',
        (t) async {
      final reg = ZWidgetRegistry()
        ..register(
            'address',
            ZAddressFieldWidget.builder(
                catalog: _countries(), subdivisionCatalog: _subs()));
      final c = _ctrl(value: const ZPostalAddress(countryCode: 'FR'));
      await t.pumpWidget(_app(c, _field(EditionFieldType.address), reg));
      await t.pump();
      expect(find.byKey(const Key('z-address-region')), findsOneWidget);
      expect(find.byKey(const Key('z-address-state-trigger')), findsNothing);
      await t.enterText(find.byKey(const Key('z-address-region')), 'Bretagne');
      await t.pump();
      expect((c.valueOf('f')! as ZPostalAddress).region, 'Bretagne');
    });

    testWidgets('changer le pays met à jour l\'option d\'état', (t) async {
      final reg = ZWidgetRegistry()
        ..register(
            'address',
            ZAddressFieldWidget.builder(
                catalog: _countries(), subdivisionCatalog: _subs()));
      final c = _ctrl(value: const ZPostalAddress(countryCode: 'FR'));
      await t.pumpWidget(_app(c, _field(EditionFieldType.address), reg));
      await t.pump();
      // FR : pas de subdivision → texte libre.
      expect(find.byKey(const Key('z-address-region')), findsOneWidget);
      // Change vers NE (a des subdivisions).
      await t.tap(find.byKey(const Key('z-country-picker-trigger')));
      await t.pump();
      await t.tap(find.byKey(const Key('z-country-item-NE')));
      await t.pump();
      expect(find.byKey(const Key('z-address-state-trigger')), findsOneWidget);
    });

    testWidgets('SANS subdivisionCatalog → région texte libre (E11a-2 inchangé)',
        (t) async {
      final reg = ZWidgetRegistry()
        ..register('address', ZAddressFieldWidget.builder(catalog: _countries()));
      final c = _ctrl(value: const ZPostalAddress(countryCode: 'NE'));
      await t.pumpWidget(_app(c, _field(EditionFieldType.address), reg));
      await t.pump();
      expect(find.byKey(const Key('z-address-region')), findsOneWidget);
      expect(find.byKey(const Key('z-address-state-trigger')), findsNothing);
    });
  });
}
