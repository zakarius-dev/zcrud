// AC2/AC3/AC4/AC5/AC6/AC7/AC8 — champs intl servis via `ZWidgetRegistry` :
// édition → tranche NEUTRE (E.164 / code ISO / adresse), catalogue paresseux
// injecté, défensif, SM-1 (rebuild ciblé + focus), anti-fuite, thème/RTL/a11y.
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

ZCountryCatalog _fakeCatalog() => ZCountryCatalog.fromList(const <ZCountryInfo>[
      ZCountryInfo(isoCode: 'NE', name: 'Niger', dialCode: '+227', flagEmoji: '🇳🇪'),
      ZCountryInfo(isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
    ]);

ZFieldSpec _field(String name, EditionFieldType type, {String? label}) =>
    ZFieldSpec(name: name, type: type, label: label ?? name);

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

ZWidgetRegistry _registry(ZCountryCatalog cat) => ZWidgetRegistry()
  ..register('phoneNumber', ZPhoneFieldWidget.builder(catalog: cat))
  ..register('country', ZCountryFieldWidget.builder(catalog: cat))
  ..register('address', ZAddressFieldWidget.builder(catalog: cat));

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZWidgetRegistry? registry,
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: ZcrudScope(
          widgetRegistry: registry,
          child: Scaffold(
            body: DynamicEdition(
              controller: controller,
              fields: <ZFieldSpec>[field],
            ),
          ),
        ),
      ),
    );

Future<void> _openPicker(WidgetTester tester, {int at = 0}) async {
  await tester.tap(find.byKey(const Key('z-country-picker-trigger')).at(at));
  await tester.pump();
}

/// DP-8 — seam mocké (aucun réseau) : renvoie des prédictions figées puis un
/// [ZPostalAddress] figé. Compte les appels pour prouver la voie unique.
class _FakePlaceSearch implements ZPlaceSearchProvider {
  _FakePlaceSearch(this.predictions, this.detailsResult);

  final List<ZPlacePrediction> predictions;
  final ZPostalAddress? detailsResult;
  int searchCount = 0;
  int detailsCount = 0;
  String? lastCountryIso;

  @override
  Future<List<ZPlacePrediction>> search(
    String query, {
    String? countryIso,
    String? sessionToken,
  }) async {
    searchCount++;
    lastCountryIso = countryIso;
    return predictions;
  }

  @override
  Future<ZPostalAddress?> details(String placeId, {String? sessionToken}) async {
    detailsCount++;
    return detailsResult;
  }
}

void main() {
  group('AC2 — champs servis via le registre', () {
    testWidgets('phoneNumber/country/address → widget intl rendu', (t) async {
      final cat = _fakeCatalog();
      for (final entry in <MapEntry<EditionFieldType, Type>>[
        MapEntry(EditionFieldType.phoneNumber, ZPhoneFieldWidget),
        MapEntry(EditionFieldType.country, ZCountryFieldWidget),
        MapEntry(EditionFieldType.address, ZAddressFieldWidget),
      ]) {
        final c = _controller('f');
        await t.pumpWidget(
          _app(c, _field('f', entry.key), registry: _registry(cat)),
        );
        expect(find.byType(entry.value), findsOneWidget);
        expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      }
    });

    testWidgets('registre vide (null) → repli ZUnsupportedFieldWidget', (t) async {
      final c = _controller('f');
      await t.pumpWidget(_app(c, _field('f', EditionFieldType.phoneNumber)));
      expect(find.byType(ZPhoneFieldWidget), findsNothing);
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('AC3 — édition met à jour la tranche (valeur neutre)', () {
    testWidgets('pays → tranche = code ISO string', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.country), registry: _registry(_fakeCatalog())),
      );
      await _openPicker(t);
      await t.tap(find.byKey(const Key('z-country-item-NE')));
      await t.pump();
      expect(c.valueOf('f'), 'NE');
    });

    testWidgets('téléphone → tranche = ZPhoneNumber E.164', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber), registry: _registry(_fakeCatalog())),
      );
      await _openPicker(t);
      await t.tap(find.byKey(const Key('z-country-item-FR')));
      await t.pump();
      await t.enterText(find.byKey(const Key('z-phone-number')), '612345678');
      await t.pump();
      final v = c.valueOf('f');
      expect(v, isA<ZPhoneNumber>());
      expect((v! as ZPhoneNumber).e164, '+33612345678');
      expect((v as ZPhoneNumber).isoCode, 'FR');
    });

    testWidgets('adresse → tranche = ZPostalAddress structurée', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.address), registry: _registry(_fakeCatalog())),
      );
      await t.enterText(find.byKey(const Key('z-address-line1')), '12 rue X');
      await t.pump();
      await t.enterText(find.byKey(const Key('z-address-city')), 'Niamey');
      await t.pump();
      final v = c.valueOf('f');
      expect(v, isA<ZPostalAddress>());
      expect((v! as ZPostalAddress).line1, '12 rue X');
      expect((v as ZPostalAddress).city, 'Niamey');
    });
  });

  group('AC4 — sélecteur pays (catalogue paresseux injecté) + liaison tél', () {
    testWidgets('liste rendue depuis le catalogue + sélection', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.country), registry: _registry(_fakeCatalog())),
      );
      await _openPicker(t);
      expect(find.byKey(const Key('z-country-item-NE')), findsOneWidget);
      expect(find.byKey(const Key('z-country-item-FR')), findsOneWidget);
    });

    testWidgets('changer le pays du téléphone → dialCode mis à jour', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber), registry: _registry(_fakeCatalog())),
      );
      // Sélection FR + numéro → E.164 FR.
      await _openPicker(t);
      await t.tap(find.byKey(const Key('z-country-item-FR')));
      await t.pump();
      await t.enterText(find.byKey(const Key('z-phone-number')), '612345678');
      await t.pump();
      expect((c.valueOf('f')! as ZPhoneNumber).dialCode, '+33');
      // Change le pays → NE : l'indicatif est re-calculé (AC4).
      await _openPicker(t);
      await t.tap(find.byKey(const Key('z-country-item-NE')));
      await t.pump();
      final v = c.valueOf('f')! as ZPhoneNumber;
      expect(v.dialCode, '+227');
      expect(v.isoCode, 'NE');
    });
  });

  group('AC5 — défensif : valeur de tranche corrompue → neutre, pas de throw', () {
    testWidgets('téléphone : valeur String absurde → pas de crash', (t) async {
      final c = _controller('f', value: 'garbage');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber), registry: _registry(_fakeCatalog())),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
    });

    testWidgets('pays : code inconnu ("ZZ") → aucune sélection, pas de crash',
        (t) async {
      final c = _controller('f', value: 'ZZ');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.country), registry: _registry(_fakeCatalog())),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(ZCountryFieldWidget), findsOneWidget);
    });

    testWidgets('adresse : map corrompue → pas de crash', (t) async {
      final c = _controller('f',
          value: <String, Object?>{'line1': 99, 'city': <int>[1]});
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.address), registry: _registry(_fakeCatalog())),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(ZAddressFieldWidget), findsOneWidget);
    });

    testWidgets('téléphone : numéro non parsable → neutre, pas de throw', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber), registry: _registry(_fakeCatalog())),
      );
      await t.enterText(find.byKey(const Key('z-phone-number')), 'abc');
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  group('AC6 — SM-1 : rebuild ciblé + focus préservé + contrôleur non recréé', () {
    testWidgets('frappe numéro → voisin non reconstruit ; focus OK ; initState==1',
        (t) async {
      final cat = _fakeCatalog();
      final c = ZFormController(
        initialValues: <String, Object?>{'a': null, 'b': null},
        visibleFields: <String>['a', 'b'],
      );
      var initA = 0;
      var buildB = 0;
      Widget sliced(String name, Key key,
              {VoidCallback? onInit, VoidCallback? onBuild}) =>
          KeyedSubtree(
            key: key,
            child: ValueListenableBuilder<Object?>(
              valueListenable: c.fieldListenable(name),
              builder: (context, value, _) => ZPhoneFieldWidget(
                ctx: ZFieldWidgetContext(
                  field: _field(name, EditionFieldType.phoneNumber),
                  value: value,
                  onChanged: (v) => c.setValue(name, v),
                ),
                catalog: cat,
                defaultIsoCode: 'FR',
                onInit: onInit,
                onBuild: onBuild,
              ),
            ),
          );

      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: <Widget>[
            sliced('a', const Key('hostA'), onInit: () => initA++),
            sliced('b', const Key('hostB'), onBuild: () => buildB++),
          ]),
        ),
      ));

      final numA = find
          .descendant(
              of: find.byKey(const Key('hostA')),
              matching: find.byKey(const Key('z-phone-number')))
          .first;
      final buildBBefore = buildB;
      await t.tap(numA);
      await t.pump();
      await t.enterText(numA, '6');
      await t.pump();
      await t.enterText(numA, '61');
      await t.pump();

      expect(initA, 1);
      expect(buildB, buildBBefore);
      expect(t.widget<TextField>(numA).focusNode!.hasFocus, isTrue);
    });

    testWidgets('SM-1 bout-en-bout via DynamicEdition : focus préservé', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber), registry: _registry(_fakeCatalog())),
      );
      final num = find.byKey(const Key('z-phone-number'));
      await t.tap(num);
      await t.pump();
      await t.enterText(num, '6');
      await t.pump();
      await t.enterText(num, '61');
      await t.pump();
      expect(t.widget<TextField>(num).focusNode!.hasFocus, isTrue);
      expect(t.takeException(), isNull);
    });
  });

  group('AC7 — anti-fuite : contrôleurs par-montage, dispose propre', () {
    testWidgets('2 champs téléphone montés → contrôleurs DISTINCTS', (t) async {
      final cat = _fakeCatalog();
      final c = ZFormController(
        initialValues: <String, Object?>{'a': null, 'b': null},
        visibleFields: <String>['a', 'b'],
      );
      final reg = ZWidgetRegistry()
        ..register('phoneNumber', ZPhoneFieldWidget.builder(catalog: cat));
      await t.pumpWidget(MaterialApp(
        home: ZcrudScope(
          widgetRegistry: reg,
          child: Scaffold(
            body: DynamicEdition(
              controller: c,
              fields: <ZFieldSpec>[
                _field('a', EditionFieldType.phoneNumber),
                _field('b', EditionFieldType.phoneNumber),
              ],
            ),
          ),
        ),
      ));
      final nums = find.byKey(const Key('z-phone-number'));
      expect(nums, findsNWidgets(2));
      final c0 = t.widget<TextField>(nums.at(0)).controller;
      final c1 = t.widget<TextField>(nums.at(1)).controller;
      expect(identical(c0, c1), isFalse);
    });

    testWidgets('démontage après frappe (tél + adresse) → aucune exception',
        (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.address), registry: _registry(_fakeCatalog())),
      );
      await t.enterText(find.byKey(const Key('z-address-line1')), 'X');
      await t.pump();
      await t.pumpWidget(const SizedBox());
      expect(t.takeException(), isNull);
    });
  });

  group('AC8 — thème injecté + RTL + a11y ≥48dp', () {
    testWidgets('rendu des 3 champs sous Directionality.rtl sans exception',
        (t) async {
      for (final type in <EditionFieldType>[
        EditionFieldType.phoneNumber,
        EditionFieldType.country,
        EditionFieldType.address,
      ]) {
        final c = _controller('f');
        await t.pumpWidget(
          _app(c, _field('f', type),
              registry: _registry(_fakeCatalog()), dir: TextDirection.rtl),
        );
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('cible tactile pays ≥ 48dp + Semantics', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.country, label: 'Pays'),
            registry: _registry(_fakeCatalog())),
      );
      final trigger = find.byKey(const Key('z-country-picker-trigger'));
      expect(trigger, findsOneWidget);
      expect(t.getSize(trigger).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel('Pays'), findsWidgets);
      handle.dispose();
    });

    testWidgets('champ numéro téléphone ≥ 48dp', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber), registry: _registry(_fakeCatalog())),
      );
      expect(t.getSize(find.byKey(const Key('z-phone-number'))).height,
          greaterThanOrEqualTo(48));
    });
  });

  group('MEDIUM-2 — a11y OPÉRABLE : action sémantique tap déclenchable (AD-13)', () {
    testWidgets('trigger pays : SemanticsAction.tap présente ET ouvre le picker',
        (t) async {
      final handle = t.ensureSemantics();
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.country),
            registry: _registry(_fakeCatalog())),
      );
      final node = t.getSemantics(find.byKey(const Key('z-country-picker-trigger')));
      // Opérabilité : l'action de tap EXISTE sur le nœud (pas seulement label/taille).
      expect(node, isSemantics(hasTapAction: true));
      // Fonctionnelle : la déclencher via le lecteur d'écran OUVRE le panneau.
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await t.pump();
      expect(find.byKey(const Key('z-country-picker-search')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('item pays : action tap sélectionne → tranche = code ISO', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.country),
            registry: _registry(_fakeCatalog())),
      );
      await _openPicker(t);
      final node = t.getSemantics(find.byKey(const Key('z-country-item-NE')));
      expect(node, isSemantics(hasTapAction: true));
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await t.pump();
      expect(c.valueOf('f'), 'NE');
      handle.dispose();
    });

    testWidgets('champ numéro tél : sémantique de champ ÉDITABLE exposée', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.phoneNumber),
            registry: _registry(_fakeCatalog())),
      );
      final node = t.getSemantics(find.byKey(const Key('z-phone-number')));
      // Plus masqué par ExcludeSemantics : le champ éditable est opérable.
      expect(node, isSemantics(isTextField: true));
      handle.dispose();
    });
  });

  group('DP-8 — double kind address / addressSearchField (mapping n:1)', () {
    testWidgets('les DEUX kinds résolvent vers ZAddressFieldWidget', (t) async {
      final reg = ZWidgetRegistry();
      registerZAddressFieldWidgets(reg, catalog: _fakeCatalog());
      expect(reg.isRegistered('address'), isTrue);
      expect(reg.isRegistered('addressSearchField'), isTrue);

      for (final kind in <String>['address', 'addressSearchField']) {
        final builder = reg.tryBuilderFor(kind)!;
        final c = _controller('f');
        await t.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => builder(
                context,
                ZFieldWidgetContext(
                  field: _field('f', EditionFieldType.address),
                  value: null,
                  onChanged: (v) => c.setValue('f', v),
                ),
              ),
            ),
          ),
        ));
        expect(find.byType(ZAddressFieldWidget), findsOneWidget,
            reason: 'kind "$kind" doit rendre ZAddressFieldWidget');
      }
    });
  });

  group('DP-8 — affordance de recherche géo (seam injecté)', () {
    testWidgets('rétro-compat : SANS provider ⇒ aucun bouton de recherche', (t) async {
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.address),
            registry: _registry(_fakeCatalog())),
      );
      expect(find.byType(ZAddressFieldWidget), findsOneWidget);
      expect(find.byKey(const Key('z-address-search-button')), findsNothing);
    });

    testWidgets('AVEC provider ⇒ bouton recherche ≥48dp', (t) async {
      final reg = ZWidgetRegistry();
      registerZAddressFieldWidgets(
        reg,
        catalog: _fakeCatalog(),
        placeSearch: _FakePlaceSearch(const <ZPlacePrediction>[], null),
      );
      final c = _controller('f');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.address), registry: reg),
      );
      final btn = find.byKey(const Key('z-address-search-button'));
      expect(btn, findsOneWidget);
      expect(t.getSize(btn).height, greaterThanOrEqualTo(48));
      expect(t.getSize(btn).width, greaterThanOrEqualTo(48));
    });

    testWidgets('sélection Places → UN SEUL ctx.onChanged (voie unique AD-2)',
        (t) async {
      final provider = _FakePlaceSearch(
        const <ZPlacePrediction>[
          ZPlacePrediction(placeId: 'p1', description: '12 rue X, Niamey'),
        ],
        const ZPostalAddress(
          line1: '12 rue X',
          city: 'Niamey',
          countryCode: 'NE',
          formatted: '12 rue X, Niamey, Niger',
        ),
      );
      var emitCount = 0;
      Object? lastValue;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZAddressFieldWidget(
            ctx: ZFieldWidgetContext(
              field: _field('f', EditionFieldType.address),
              value: null,
              onChanged: (v) {
                emitCount++;
                lastValue = v;
              },
            ),
            catalog: _fakeCatalog(),
            placeSearch: provider,
          ),
        ),
      ));

      await t.tap(find.byKey(const Key('z-address-search-button')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('z-address-search-input')), 'rue X');
      await t.pumpAndSettle();
      expect(find.byKey(const Key('z-address-prediction-p1')), findsOneWidget);
      expect(provider.searchCount, greaterThanOrEqualTo(1));

      final emitBefore = emitCount;
      await t.tap(find.byKey(const Key('z-address-prediction-p1')));
      await t.pumpAndSettle();

      // Voie unique (AD-2) : le remplissage n'émet QU'UNE fois.
      expect(emitCount - emitBefore, 1);
      expect(provider.detailsCount, 1);
      expect(lastValue, isA<ZPostalAddress>());
      final v = lastValue! as ZPostalAddress;
      expect(v.line1, '12 rue X');
      expect(v.city, 'Niamey');
      expect(v.countryCode, 'NE');
      expect(v.formatted, '12 rue X, Niamey, Niger');
      expect(t.takeException(), isNull);
    });
  });

  group('DP-8 — compat schéma String legacy (ingestion sans réécriture)', () {
    testWidgets('valeur de tranche = String legacy → affichage formatted, pas de crash',
        (t) async {
      final c = _controller('f', value: 'Rond-point 6e, Niamey');
      await t.pumpWidget(
        _app(c, _field('f', EditionFieldType.address),
            registry: _registry(_fakeCatalog())),
      );
      expect(t.takeException(), isNull);
      expect(find.byType(ZAddressFieldWidget), findsOneWidget);
      // La String legacy s'affiche dans un sous-champ (via `formatted`).
      expect(find.byKey(const Key('z-address-formatted')), findsOneWidget);
      expect(find.text('Rond-point 6e, Niamey'), findsOneWidget);
    });
  });
}
