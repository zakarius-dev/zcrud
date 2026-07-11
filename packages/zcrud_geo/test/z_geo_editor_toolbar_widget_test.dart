// DP-7 (AC3/AC4/AC5/AC6/AC7/AC8/AC9) — barre d'outils d'éditeur géo rendue par
// `ZGeoFieldWidget` : rendu conditionnel gated par toggles, actions câblées
// (undo/clear/ma-position/type-carte), options carte neutres plombées à
// l'adaptateur, rétro-compat (pas de barre si null), SM-1, readOnly, RTL/thème.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';

ZFieldSpec _field(
  String name, {
  ZGeoEditorToolbarConfig? bar,
  ZGeoGeometry? geometry,
  bool readOnly = false,
  EditionFieldType type = EditionFieldType.location,
}) =>
    ZFieldSpec(
      name: name,
      type: type,
      label: 'Geo',
      readOnly: readOnly,
      config: ZGeoFieldConfig(geometry: geometry, toolbarConfig: bar),
    );

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

ZWidgetRegistry _registry({
  FakeMapAdapter? adapter,
  ZGeoLocationResolver? resolver,
  VoidCallback? onInit,
  String kind = 'location',
}) =>
    ZWidgetRegistry()
      ..register(
        kind,
        ZGeoFieldWidget.builder(
          adapterFactory: adapter == null ? null : () => adapter,
          locationResolver: resolver,
          onInit: onInit,
        ),
      );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZWidgetRegistry? registry,
  TextDirection dir = TextDirection.ltr,
  ThemeData? theme,
}) =>
    MaterialApp(
      theme: theme,
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

const Key _toolbar = Key('z-geo-toolbar');
const Key _undo = Key('z-geo-undo');
const Key _clear = Key('z-geo-clear');
const Key _myLoc = Key('z-geo-my-location');
const Key _mapType = Key('z-geo-map-type');

void main() {
  group('AC3/AC4 — rendu conditionnel de la barre', () {
    testWidgets('toolbarConfig null → aucune barre (rétro-compat stricte)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry()),
      );
      expect(find.byKey(_toolbar), findsNothing);
    });

    testWidgets('preset none (disabled) → aucune barre', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.none),
            registry: _registry()),
      );
      expect(find.byKey(_toolbar), findsNothing);
    });

    testWidgets('toolbarConfig standard → barre présente', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.standard),
            registry: _registry()),
      );
      expect(find.byKey(_toolbar), findsOneWidget);
    });
  });

  group('AC4 — boutons gated par leurs toggles', () {
    testWidgets('undo/clear/map-type présents selon toggles', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(
                showUndoButton: true,
                showClearButton: false,
                showMapTypeToggle: true,
                showMyLocationButton: false,
              )),
          registry: _registry(),
        ),
      );
      expect(find.byKey(_undo), findsOneWidget);
      expect(find.byKey(_clear), findsNothing);
      expect(find.byKey(_mapType), findsOneWidget);
    });

    testWidgets('ma-position masqué si seam absent même si toggle true',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showMyLocationButton: true)),
          registry: _registry(), // pas de resolver
        ),
      );
      expect(find.byKey(_myLoc), findsNothing);
    });

    testWidgets('ma-position présent si seam injecté', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showMyLocationButton: true)),
          registry: _registry(resolver: () async => null),
        ),
      );
      expect(find.byKey(_myLoc), findsOneWidget);
    });

    testWidgets('feature toggles (traffic) rendus selon config', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showTrafficToggle: true)),
          registry: _registry(),
        ),
      );
      expect(find.byKey(const Key('z-geo-traffic')), findsOneWidget);
    });
  });

  group('AC5 — actions câblées (voie ctx.onChanged)', () {
    testWidgets('clear → tranche null + champs vidés', (tester) async {
      final c = _controller('geo', value: const ZGeoPoint(lat: 1, lng: 2));
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.standard),
            registry: _registry()),
      );
      expect(c.valueOf('geo'), isNotNull);
      await tester.tap(find.byKey(_clear));
      await tester.pump();
      expect(c.valueOf('geo'), isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text,
        '',
      );
    });

    testWidgets('undo polygone → retire le dernier sommet', (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter(tapPoint: const ZGeoPoint(lat: 5, lng: 6));
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: ZGeoEditorToolbarConfig.standard,
              type: EditionFieldType.geoArea),
          registry: _registry(adapter: fake, kind: 'geoArea'),
        ),
      );
      // Deux taps carte → 2 sommets.
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect((c.valueOf('geo')! as ZGeoShape).vertices, hasLength(2));
      // undo → 1 sommet.
      await tester.tap(find.byKey(_undo));
      await tester.pump();
      expect((c.valueOf('geo')! as ZGeoShape).vertices, hasLength(1));
    });

    testWidgets('undo sans rien à annuler → no-op (pas de crash)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: ZGeoEditorToolbarConfig.standard,
              type: EditionFieldType.geoArea),
          registry: _registry(kind: 'geoArea'),
        ),
      );
      await tester.tap(find.byKey(_undo));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ma-position → applique le point du resolver (point)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showMyLocationButton: true)),
          registry: _registry(
            resolver: () async => const ZGeoPoint(lat: 7, lng: 8),
          ),
        ),
      );
      await tester.tap(find.byKey(_myLoc));
      await tester.pumpAndSettle();
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 7, lng: 8)));
    });

    testWidgets('ma-position → resolver null/erreur = no-op silencieux',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showMyLocationButton: true)),
          registry: _registry(
            resolver: () async => throw Exception('denied'),
          ),
        ),
      );
      await tester.tap(find.byKey(_myLoc));
      await tester.pumpAndSettle();
      expect(c.valueOf('geo'), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('type-de-carte → met à jour ZGeoMapOptions.mapType',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showMapTypeToggle: true)),
          registry: _registry(adapter: fake),
        ),
      );
      // Défaut DODLP = hybrid ; cycle non-étendu [normal, hybrid].
      expect(fake.lastMapOptions?.mapType, ZGeoMapType.hybrid);
      await tester.tap(find.byKey(_mapType));
      await tester.pump();
      expect(fake.lastMapOptions?.mapType, ZGeoMapType.normal);
    });

    testWidgets('type-de-carte étendu → atteint satellite/terrain',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(
                showMapTypeToggle: true,
                showExtendedMapTypes: true,
              )),
          registry: _registry(adapter: fake),
        ),
      );
      // Départ hybrid (défaut DODLP) ; cycle étendu [normal,hybrid,satellite,terrain] :
      // hybrid → satellite → terrain → normal.
      await tester.tap(find.byKey(_mapType));
      await tester.pump();
      await tester.tap(find.byKey(_mapType));
      await tester.pump();
      expect(fake.lastMapOptions?.mapType, ZGeoMapType.terrain);
      await tester.tap(find.byKey(_mapType));
      await tester.pump();
      expect(fake.lastMapOptions?.mapType, ZGeoMapType.normal);
    });
  });

  group('AC6 — mapOptions plombé à l\'adaptateur', () {
    testWidgets('sans toolbarConfig → mapOptions null', (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: fake)),
      );
      expect(fake.lastMapOptions, isNull);
    });

    testWidgets('avec toolbarConfig → mapOptions non-null (neutre)',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.standard),
            registry: _registry(adapter: fake)),
      );
      expect(fake.lastMapOptions, isNotNull);
      expect(fake.lastMapOptions!.mapType, ZGeoMapType.hybrid); // défaut DODLP
    });

    testWidgets('toggle feature → reflété dans mapOptions', (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: const ZGeoEditorToolbarConfig(showTrafficToggle: true)),
          registry: _registry(adapter: fake),
        ),
      );
      expect(fake.lastMapOptions!.trafficEnabled, isFalse);
      await tester.tap(find.byKey(const Key('z-geo-traffic')));
      await tester.pump();
      expect(fake.lastMapOptions!.trafficEnabled, isTrue);
    });
  });

  group('AC8 — AD-2/SM-1 & readOnly', () {
    testWidgets('SM-1 : frappe + action barre → State non recréé (onInit==1)',
        (tester) async {
      final c = _controller('geo');
      var initCount = 0;
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', bar: ZGeoEditorToolbarConfig.standard),
          registry: _registry(onInit: () => initCount++),
        ),
      );
      final lat = find.byType(TextField).first;
      await tester.tap(lat);
      await tester.pump();
      await tester.enterText(lat, '12');
      await tester.pump();
      // Action discrète de barre (type de carte) → setState, PAS de recréation.
      await tester.tap(find.byKey(_mapType));
      await tester.pump();
      expect(initCount, 1);
    });

    testWidgets('readOnly → actions désactivées (clear ne vide pas)',
        (tester) async {
      final c = _controller('geo', value: const ZGeoPoint(lat: 1, lng: 2));
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              bar: ZGeoEditorToolbarConfig.standard, readOnly: true),
          registry: _registry(),
        ),
      );
      await tester.tap(find.byKey(_clear));
      await tester.pump();
      // Bouton désactivé → la valeur reste inchangée.
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 1, lng: 2)));
    });
  });

  group('AC9 — a11y ≥48dp / RTL / thème', () {
    testWidgets('boutons barre ≥ 48dp', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.standard),
            registry: _registry()),
      );
      final size = tester.getSize(find.byKey(_undo));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('rendu RTL sans exception', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.full),
            registry: _registry(resolver: () async => null),
            dir: TextDirection.rtl),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(_toolbar), findsOneWidget);
    });

    testWidgets('thème custom (dark) sans exception + Semantics boutons',
        (tester) async {
      final handle = tester.ensureSemantics();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', bar: ZGeoEditorToolbarConfig.standard),
            registry: _registry(), theme: ThemeData.dark()),
      );
      expect(tester.takeException(), isNull);
      // Libellé sémantique routé via l10n (fallback inline).
      expect(find.bySemanticsLabel('Annuler'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('libellé l10n surchargeable via ZcrudScope.labels',
        (tester) async {
      final c = _controller('geo');
      final registry = _registry();
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            widgetRegistry: registry,
            labels: ZcrudLabels(<String, String>{'geo.clear': 'Wipe'}),
            child: Scaffold(
              body: DynamicEdition(
                controller: c,
                fields: <ZFieldSpec>[
                  _field('geo', bar: ZGeoEditorToolbarConfig.standard),
                ],
              ),
            ),
          ),
        ),
      ));
      expect(find.text('Wipe'), findsOneWidget);
    });
  });
}
