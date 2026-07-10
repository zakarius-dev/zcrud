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
}
