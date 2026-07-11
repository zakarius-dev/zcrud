// AC2/AC3/AC4/AC5/AC6/AC7/AC8 — `ZGeoFieldWidget` : servi via `ZWidgetRegistry`,
// édition → tranche neutre, carte via adaptateur injecté + repli propre,
// défensif, SM-1 (rebuild ciblé + focus), anti-fuite dispose, thème/RTL/a11y.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';

ZFieldSpec _locationField(String name) => ZFieldSpec(
      name: name,
      type: EditionFieldType.location,
      label: 'Lieu',
    );

ZFieldSpec _areaField(String name) => ZFieldSpec(
      name: name,
      type: EditionFieldType.geoArea,
      label: 'Zone',
    );

// Champ cercle (E11b-1) : type `location` + config géométrie `circle` (la
// géométrie passe par ZGeoFieldConfig, PAS par une nouvelle valeur d'enum).
ZFieldSpec _circleField(String name) => ZFieldSpec(
      name: name,
      type: EditionFieldType.location,
      label: 'Cercle',
      config: const ZGeoFieldConfig(geometry: ZGeoGeometry.circle),
    );

// Champ avec surcharges par-champ (E11b-1 MEDIUM-1) : tuiles/style/zoom.
ZFieldSpec _configuredField(String name) => ZFieldSpec(
      name: name,
      type: EditionFieldType.location,
      label: 'Lieu configuré',
      config: const ZGeoFieldConfig(
        tileUrlTemplate: 'https://example.test/{z}/{x}/{y}.png',
        mapStyleJson: '[{"stylers":[]}]',
        defaultZoom: 9,
      ),
    );

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

Widget _appWithRegistry(
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

ZWidgetRegistry _registry({ZMapAdapter? adapter, String kind = 'location'}) =>
    ZWidgetRegistry()
      ..register(
        kind,
        ZGeoFieldWidget.builder(
          // Fabrique renvoyant l'instance fournie (le champ l'appelle 1× par
          // montage) — préserve les assertions sur une instance de test unique.
          adapterFactory: adapter == null ? null : () => adapter,
        ),
      );

ZWidgetRegistry _registryFactory(
  ZMapAdapterFactory factory, {
  String kind = 'location',
}) =>
    ZWidgetRegistry()
      ..register(kind, ZGeoFieldWidget.builder(adapterFactory: factory));

void main() {
  group('MEDIUM-1 (E11b-1) — surcharges par-champ RÉELLEMENT plombées', () {
    testWidgets(
        'tileUrlTemplate/mapStyleJson/defaultZoom de la config atteignent '
        'buildMap (champs non morts)', (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _appWithRegistry(c, _configuredField('geo'),
            registry: _registry(adapter: fake)),
      );
      await tester.pump();

      expect(fake.lastTileUrlTemplate, 'https://example.test/{z}/{x}/{y}.png');
      expect(fake.lastMapStyleJson, '[{"stylers":[]}]');
      expect(fake.lastDefaultZoom, 9);
    });
  });

  group('AC2 — champ servi via le registre', () {
    testWidgets('registre peuplé → widget géo rendu', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      expect(find.byType(ZGeoFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
    });

    testWidgets('registre vide (null) → repli ZUnsupportedFieldWidget',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(_appWithRegistry(c, _locationField('geo')));
      expect(find.byType(ZGeoFieldWidget), findsNothing);
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AC3 — édition met à jour la tranche (valeur neutre)', () {
    testWidgets('saisie lat+lng → ZGeoPoint dans la tranche', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '13.5');
      await tester.enterText(fields.at(1), '2.1');
      await tester.pump();
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 13.5, lng: 2.1)));
    });

    testWidgets('saisie incomplète → tranche neutre (null)', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      await tester.enterText(find.byType(TextField).at(0), '13.5');
      await tester.pump();
      expect(c.valueOf('geo'), isNull);
    });
  });

  group('AC4 — carte via adaptateur injecté + repli propre', () {
    testWidgets('adaptateur fake → surface rendue + tap → point neutre',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter(tapPoint: const ZGeoPoint(lat: 5, lng: 6));
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'),
            registry: _registry(adapter: fake)),
      );
      expect(find.byKey(FakeMapAdapter.mapKey), findsOneWidget);
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 5, lng: 6)));
    });

    testWidgets('sans adaptateur (null) → repli coordonnées, pas de crash',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      expect(find.byKey(FakeMapAdapter.mapKey), findsNothing);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('adaptateur reçoit uniquement des types NEUTRES',
        (tester) async {
      final c = _controller('geo',
          value: const ZGeoPoint(lat: 1, lng: 2));
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'),
            registry: _registry(adapter: fake)),
      );
      expect(fake.lastCenter, equals(const ZGeoPoint(lat: 1, lng: 2)));
      expect(fake.sawOnTap, isTrue);
    });
  });

  group('AC5 — défensif : valeur de tranche corrompue → neutre, pas de throw',
      () {
    testWidgets('map hors-bornes en valeur initiale → champs vides, pas throw',
        (tester) async {
      final c = _controller('geo',
          value: <String, Object?>{'lat': 200.0, 'lng': 999.0});
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '');
    });

    testWidgets('valeur String absurde → pas de crash', (tester) async {
      final c = _controller('geo', value: 'garbage');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZGeoFieldWidget), findsOneWidget);
    });
  });

  group('AC6 — SM-1 : rebuild ciblé + focus préservé + contrôleur non recréé',
      () {
    testWidgets('frappe → seule la tranche du champ se reconstruit ; focus OK',
        (tester) async {
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
              builder: (context, value, _) => ZGeoFieldWidget(
                ctx: ZFieldWidgetContext(
                  field: _locationField(name),
                  value: value,
                  onChanged: (v) => c.setValue(name, v),
                ),
                onInit: onInit,
                onBuild: onBuild,
              ),
            ),
          );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: <Widget>[
            sliced('a', const Key('hostA'), onInit: () => initA++),
            sliced('b', const Key('hostB'), onBuild: () => buildB++),
          ]),
        ),
      ));

      final latA = find
          .descendant(of: find.byKey(const Key('hostA')), matching: find.byType(TextField))
          .first;
      final buildBBefore = buildB;

      await tester.tap(latA);
      await tester.pump();
      await tester.enterText(latA, '4');
      await tester.pump();
      await tester.enterText(latA, '45');
      await tester.pump();

      // Contrôleur/State non recréés (compteur initState == 1).
      expect(initA, 1);
      // Voisin NON reconstruit par la frappe (rebuild ciblé à la tranche).
      expect(buildB, buildBBefore);
      // Focus préservé pendant la frappe.
      expect(
        tester.widget<TextField>(latA).focusNode!.hasFocus,
        isTrue,
      );
    });

    testWidgets(
        'LOW-6 — SM-1 bout-en-bout via le vrai dispatch DynamicEdition : '
        'focus préservé après frappe', (tester) async {
      // Rejoue le chemin RÉEL (ZFieldWidget/registry/ZFieldListenableBuilder)
      // via DynamicEdition — pas un slice fait-main — et prouve le non-saut de
      // curseur (aucun write-back pendant le focus, AD-2).
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      final lat = find.byType(TextField).first;
      await tester.tap(lat);
      await tester.pump();
      await tester.enterText(lat, '4');
      await tester.pump();
      await tester.enterText(lat, '45');
      await tester.pump();
      // Focus intact après deux frappes traversant le dispatch réel.
      expect(tester.widget<TextField>(lat).focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('AC7 — anti-fuite : dispose libère le contrôleur natif de l\'adaptateur',
      () {
    testWidgets('unmount → fake adapter disposed == true', (tester) async {
      final fake = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'),
            registry: _registry(adapter: fake)),
      );
      expect(fake.disposed, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(fake.disposed, isTrue);
    });
  });

  group('AC8 — thème injecté + RTL + a11y ≥48dp', () {
    testWidgets('rendu sous Directionality.rtl sans exception', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'),
            registry: _registry(), dir: TextDirection.rtl),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ZGeoFieldWidget), findsOneWidget);
    });

    testWidgets('cibles tactiles ≥ 48dp + Semantics bouton (a11y)',
        (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _areaField('geo'),
            registry: _registry(kind: 'geoArea')),
      );
      final addBtn = find.byKey(const Key('z-geo-add-vertex'));
      expect(addBtn, findsOneWidget);
      final size = tester.getSize(addBtn);
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      // Semantics explicite du bouton (AD-13).
      expect(find.bySemanticsLabel('ajouter-sommet'), findsOneWidget);
      handle.dispose();
    });
  });

  group('geoArea — édition d\'aire (valeur ZGeoShape neutre)', () {
    testWidgets('ajout de sommet via bouton → ZGeoShape dans la tranche',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _areaField('geo'),
            registry: _registry(kind: 'geoArea')),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '13.5');
      await tester.enterText(fields.at(1), '2.1');
      await tester.pump();
      await tester.tap(find.byKey(const Key('z-geo-add-vertex')));
      await tester.pump();
      final value = c.valueOf('geo');
      expect(value, isA<ZGeoShape>());
      expect((value! as ZGeoShape).vertices, hasLength(1));
      expect((value as ZGeoShape).vertices.first,
          equals(const ZGeoPoint(lat: 13.5, lng: 2.1)));
    });
  });

  group('DP-21/M13 — géométrie POLYLIGNE (tracé ouvert)', () {
    ZFieldSpec polylineField(String name) => ZFieldSpec(
          name: name,
          type: EditionFieldType.geoArea,
          label: 'Tracé',
          config: const ZGeoFieldConfig(geometry: ZGeoGeometry.polyline),
        );

    testWidgets('collecte de sommets (même UI que le polygone) → ZGeoShape',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, polylineField('geo'),
            registry: _registry(kind: 'geoArea')),
      );
      // Le bouton d'ajout de sommet est présent (géométrie collectrice).
      expect(find.byKey(const Key('z-geo-add-vertex')), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '13.5');
      await tester.enterText(fields.at(1), '2.1');
      await tester.pump();
      await tester.tap(find.byKey(const Key('z-geo-add-vertex')));
      await tester.pump();
      final value = c.valueOf('geo');
      expect(value, isA<ZGeoShape>());
      expect((value! as ZGeoShape).vertices, hasLength(1));
    });

    testWidgets('renderShapeAsPolyline: true plombé à l\'adaptateur',
        (tester) async {
      final fake = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, polylineField('geo'),
            registry: _registry(adapter: fake, kind: 'geoArea')),
      );
      await tester.pump();
      // Le signal neutre « tracé ouvert » a bien été transmis (honoré-si-supporté).
      expect(fake.lastRenderShapeAsPolyline, isTrue);
    });

    testWidgets('géométrie polygone → renderShapeAsPolyline reste false',
        (tester) async {
      final fake = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _areaField('geo'),
            registry: _registry(adapter: fake, kind: 'geoArea')),
      );
      await tester.pump();
      expect(fake.lastRenderShapeAsPolyline, isFalse);
    });
  });

  group('MAJEUR-1 — fabrique : une instance d\'adaptateur possédée par montage',
      () {
    testWidgets('2 champs géo montés simultanément → 2 instances DISTINCTES',
        (tester) async {
      final created = <FakeMapAdapter>[];
      ZMapAdapter make() {
        final f = FakeMapAdapter();
        created.add(f);
        return f;
      }

      final c = ZFormController(
        initialValues: <String, Object?>{'a': null, 'b': null},
        visibleFields: <String>['a', 'b'],
      );
      final registry = ZWidgetRegistry()
        ..register('location', ZGeoFieldWidget.builder(adapterFactory: make));

      await tester.pumpWidget(MaterialApp(
        home: ZcrudScope(
          widgetRegistry: registry,
          child: Scaffold(
            body: DynamicEdition(
              controller: c,
              fields: <ZFieldSpec>[_locationField('a'), _locationField('b')],
            ),
          ),
        ),
      ));

      // Chaque montage a appelé la fabrique 1× → 2 instances, jamais aliasées
      // (le `MapController` natif n'est pas partagé entre les deux champs).
      expect(created, hasLength(2));
      expect(identical(created[0], created[1]), isFalse);
      expect(find.byKey(FakeMapAdapter.mapKey), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'remontage → NOUVELLE instance ; ancienne disposée sans affecter la '
        'nouvelle', (tester) async {
      final created = <FakeMapAdapter>[];
      ZMapAdapter make() {
        final f = FakeMapAdapter();
        created.add(f);
        return f;
      }

      final c = _controller('geo');
      final reg = _registryFactory(make);

      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: reg),
      );
      expect(created, hasLength(1));
      expect(created[0].disposed, isFalse);

      // Démontage → l'instance POSSÉDÉE par ce montage est disposée.
      await tester.pumpWidget(const SizedBox());
      expect(created[0].disposed, isTrue);

      // Remontage → la fabrique est rappelée → instance NEUVE, non disposée,
      // indépendante de l'ancienne (pas de contrôleur réutilisé après dispose).
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: reg),
      );
      expect(created, hasLength(2));
      expect(identical(created[0], created[1]), isFalse);
      expect(created[1].disposed, isFalse);
      expect(find.byKey(FakeMapAdapter.mapKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MEDIUM-3 — geoArea : deux mutations dans la même frame ne perdent '
      'aucun sommet', () {
    testWidgets('2 taps carte (même frame, sans rebuild entre eux) → 2 sommets',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter(tapPoint: const ZGeoPoint(lat: 5, lng: 6));
      await tester.pumpWidget(
        _appWithRegistry(c, _areaField('geo'),
            registry: _registry(adapter: fake, kind: 'geoArea')),
      );
      // Deux taps SANS pump intermédiaire : aucun rebuild → `ctx.value` resterait
      // obsolète pour le second (lost update sans le correctif atomique).
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      final value = c.valueOf('geo');
      expect(value, isA<ZGeoShape>());
      expect((value! as ZGeoShape).vertices, hasLength(2));
    });

    testWidgets('ajouts successifs via bouton candidat → sommets cumulés',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _areaField('geo'),
            registry: _registry(kind: 'geoArea')),
      );
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '1');
      await tester.enterText(fields.at(1), '2');
      await tester.pump();
      await tester.tap(find.byKey(const Key('z-geo-add-vertex')));
      await tester.pump();
      await tester.enterText(fields.at(0), '3');
      await tester.enterText(fields.at(1), '4');
      await tester.pump();
      await tester.tap(find.byKey(const Key('z-geo-add-vertex')));
      await tester.pump();
      final value = c.valueOf('geo')! as ZGeoShape;
      expect(value.vertices, hasLength(2));
      expect(value.vertices[0], equals(const ZGeoPoint(lat: 1, lng: 2)));
      expect(value.vertices[1], equals(const ZGeoPoint(lat: 3, lng: 4)));
    });
  });

  group('LOW-4 — libellé "Ajouter" routé via l10n injectée', () {
    testWidgets('ZcrudScope.labels surcharge le libellé du bouton',
        (tester) async {
      final c = _controller('geo');
      final registry = _registry(kind: 'geoArea');
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            widgetRegistry: registry,
            labels: ZcrudLabels(<String, String>{'geo.addVertex': 'Add point'}),
            child: Scaffold(
              body: DynamicEdition(
                controller: c,
                fields: <ZFieldSpec>[_areaField('geo')],
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Add point'), findsOneWidget);
      expect(find.text('Ajouter'), findsNothing);
    });
  });

  group('LOW-5 — _pointOf ignore un ZGeoPoint hors-bornes en tranche', () {
    testWidgets('ZGeoPoint hors-bornes en valeur initiale → champs vides',
        (tester) async {
      // Point construit programmatiquement hors-bornes (constructeur sans assert).
      final c = _controller('geo', value: const ZGeoPoint(lat: 200, lng: 999));
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '',
      );
    });
  });

  group('E11b-1 — édition CERCLE (ZGeoFieldConfig geometry: circle)', () {
    testWidgets('config circle → champ rayon présent (3 TextField)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'), registry: _registry()),
      );
      expect(find.byType(ZGeoFieldWidget), findsOneWidget);
      expect(find.byKey(const Key('z-geo-radius')), findsOneWidget);
      // centre (lat/lng) + rayon.
      expect(find.byType(TextField), findsNWidgets(3));
    });

    testWidgets('saisie centre + rayon → ZGeoCircle neutre dans la tranche',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'), registry: _registry()),
      );
      await tester.enterText(find.byType(TextField).at(0), '13.5');
      await tester.enterText(find.byType(TextField).at(1), '2.1');
      await tester.enterText(find.byKey(const Key('z-geo-radius')), '500');
      await tester.pump();
      expect(
        c.valueOf('geo'),
        equals(const ZGeoCircle(
          center: ZGeoPoint(lat: 13.5, lng: 2.1),
          radiusMeters: 500,
        )),
      );
    });

    testWidgets('rayon 0 → cercle non valide → tranche neutre (null)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'), registry: _registry()),
      );
      await tester.enterText(find.byType(TextField).at(0), '13.5');
      await tester.enterText(find.byType(TextField).at(1), '2.1');
      await tester.enterText(find.byKey(const Key('z-geo-radius')), '0');
      await tester.pump();
      expect(c.valueOf('geo'), isNull);
    });

    testWidgets('rayon négatif (-5) → tranche neutre (null)', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'), registry: _registry()),
      );
      await tester.enterText(find.byType(TextField).at(0), '13.5');
      await tester.enterText(find.byType(TextField).at(1), '2.1');
      await tester.enterText(find.byKey(const Key('z-geo-radius')), '-5');
      await tester.pump();
      expect(c.valueOf('geo'), isNull);
    });

    testWidgets('tap carte → fixe le centre, cercle recomposé (rayon conservé)',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter(tapPoint: const ZGeoPoint(lat: 5, lng: 6));
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'),
            registry: _registry(adapter: fake)),
      );
      // Rayon d'abord saisi, puis tap carte fixe le centre.
      await tester.enterText(find.byKey(const Key('z-geo-radius')), '250');
      await tester.pump();
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect(
        c.valueOf('geo'),
        equals(const ZGeoCircle(
          center: ZGeoPoint(lat: 5, lng: 6),
          radiusMeters: 250,
        )),
      );
    });

    testWidgets('valeur initiale ZGeoCircle → champs amorcés + reçu par la carte',
        (tester) async {
      const initial = ZGeoCircle(
        center: ZGeoPoint(lat: 1, lng: 2),
        radiusMeters: 100,
      );
      final c = _controller('geo', value: initial);
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'),
            registry: _registry(adapter: fake)),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '1.0',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('z-geo-radius')))
            .controller!
            .text,
        '100.0',
      );
      // La carte reçoit le cercle neutre (aucun type SDK).
      expect(fake.lastCircle, equals(initial));
    });

    testWidgets('valeur cercle corrompue (rayon NaN via Map) → pas de throw',
        (tester) async {
      final c = _controller('geo', value: <String, Object?>{
        'center': <String, Object?>{'lat': 1.0, 'lng': 2.0},
        'radius_m': double.nan,
      });
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'), registry: _registry()),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('z-geo-radius')))
            .controller!
            .text,
        '',
      );
    });

    testWidgets('SM-1 : frappe du rayon → State non recréé + focus préservé',
        (tester) async {
      final c = _controller('geo');
      var initCount = 0;
      final registry = ZWidgetRegistry()
        ..register(
          'location',
          ZGeoFieldWidget.builder(
            geometry: ZGeoGeometry.circle,
            onInit: () => initCount++,
          ),
        );
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: registry),
      );
      final radius = find.byKey(const Key('z-geo-radius'));
      await tester.tap(radius);
      await tester.pump();
      await tester.enterText(radius, '5');
      await tester.pump();
      await tester.enterText(radius, '50');
      await tester.pump();
      expect(initCount, 1);
      expect(tester.widget<TextField>(radius).focusNode!.hasFocus, isTrue);
    });

    testWidgets('rendu sous Directionality.rtl sans exception', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'),
            registry: _registry(), dir: TextDirection.rtl),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('z-geo-radius')), findsOneWidget);
    });

    testWidgets('dispose (unmount) → fake adapter disposed == true',
        (tester) async {
      final fake = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _circleField('geo'),
            registry: _registry(adapter: fake)),
      );
      expect(fake.disposed, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(fake.disposed, isTrue);
    });
  });

  group('E11b-1 — géométrie via builder override (sans config par-champ)', () {
    testWidgets('builder(geometry: circle) sur type location → mode cercle',
        (tester) async {
      final c = _controller('geo');
      final registry = ZWidgetRegistry()
        ..register(
          'location',
          ZGeoFieldWidget.builder(geometry: ZGeoGeometry.circle),
        );
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: registry),
      );
      expect(find.byKey(const Key('z-geo-radius')), findsOneWidget);
    });
  });

  group('E11b-1 — RÉTRO-COMPAT E11a-1 stricte (sans config → inchangé)', () {
    testWidgets('location sans config → point (2 champs, pas de rayon)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _locationField('geo'), registry: _registry()),
      );
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byKey(const Key('z-geo-radius')), findsNothing);
      await tester.enterText(find.byType(TextField).at(0), '13.5');
      await tester.enterText(find.byType(TextField).at(1), '2.1');
      await tester.pump();
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 13.5, lng: 2.1)));
    });

    testWidgets('geoArea sans config → polygone (bouton ajouter présent)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _appWithRegistry(c, _areaField('geo'),
            registry: _registry(kind: 'geoArea')),
      );
      expect(find.byKey(const Key('z-geo-add-vertex')), findsOneWidget);
      expect(find.byKey(const Key('z-geo-radius')), findsNothing);
    });
  });

  group('E11b-1 — mapHeight surchargé par ZGeoFieldConfig', () {
    testWidgets('config.mapHeight prime sur le défaut du widget',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      const field = ZFieldSpec(
        name: 'geo',
        type: EditionFieldType.location,
        label: 'Cercle',
        config: ZGeoFieldConfig(
          geometry: ZGeoGeometry.circle,
          mapHeight: 321,
        ),
      );
      await tester.pumpWidget(
        _appWithRegistry(c, field, registry: _registry(adapter: fake)),
      );
      final box = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byKey(FakeMapAdapter.mapKey),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.height, 321);
    });
  });
}
