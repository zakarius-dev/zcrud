// CR geo — lot « surface » : G8 (picker de style câblé, style persisté —
// gff:299-307), G12 (chip de métriques — gff:1363-1391), G16 (optimize RÉEL
// gff:922-959 + dropdown d'options réel), G19 (chrome : encart/en-tête/pied
// localisé/hauteur 300 — gff:1404-1597), G20 (compaction < 600 — gff:776,880),
// G21/G22 (options plombées), G23 (zoom min/max plombés ; step = donnée sans
// consommateur, documenté).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/adapters/google.dart';
import 'package:zcrud_geo/adapters/osm.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';

ZFieldSpec _field(
  String name, {
  ZGeoFieldConfig? config,
  bool readOnly = false,
  EditionFieldType type = EditionFieldType.location,
}) =>
    ZFieldSpec(
      name: name,
      type: type,
      label: 'Zone',
      readOnly: readOnly,
      config: config,
    );

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  ZWidgetRegistry? registry,
}) =>
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

ZWidgetRegistry _registry({FakeMapAdapter? adapter, String kind = 'location'}) =>
    ZWidgetRegistry()
      ..register(
        kind,
        ZGeoFieldWidget.builder(
          adapterFactory: adapter == null ? null : () => adapter,
        ),
      );

final ZGeoShape _triangle = ZGeoShape(vertices: const <ZGeoPoint>[
  ZGeoPoint(lat: 0, lng: 0),
  ZGeoPoint(lat: 0, lng: 0.001),
  ZGeoPoint(lat: 0.001, lng: 0.001),
]);

void main() {
  group('G8 — picker de style câblé (showStylePicker)', () {
    testWidgets('défaut (sans flag) → AUCUN picker (AD-4, rendu inchangé)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(find.byKey(const Key('z-geo-style-picker')), findsNothing);
      expect(find.byType(ZGeoShapeStylePicker), findsNothing);
    });

    testWidgets(
        'showStylePicker → picker rendu, AMORCÉ du style de la valeur, et '
        'toute modification est PERSISTÉE DANS LA VALEUR (parité gff:299-307)',
        (tester) async {
      const ZGeoPoint initial = ZGeoPoint(
        lat: 6.13,
        lng: 1.28,
        style: ZGeoShapeStyle(strokeWidth: 2),
      );
      final c = _controller('geo', value: initial);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              config: const ZGeoFieldConfig(showStylePicker: true)),
          registry: _registry(adapter: FakeMapAdapter()),
        ),
      );
      expect(find.byKey(const Key('z-geo-style-picker')), findsOneWidget);
      // « + » du stepper d'épaisseur → strokeWidth 3, persisté dans la tranche.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final Object? value = c.valueOf('geo');
      expect(value, isA<ZGeoPoint>());
      expect((value! as ZGeoPoint).style?.strokeWidth, 3);
      expect((value as ZGeoPoint).lat, 6.13); // coordonnées intactes
    });

    testWidgets(
        'le style brouillon voyage avec les émissions suivantes : tap carte '
        'en mode point → le point émis PORTE le style', (tester) async {
      const ZGeoPoint initial = ZGeoPoint(
        lat: 1,
        lng: 2,
        style: ZGeoShapeStyle(strokeWidth: 5),
      );
      final adapter = FakeMapAdapter();
      final c = _controller('geo', value: initial);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              config: const ZGeoFieldConfig(showStylePicker: true)),
          registry: _registry(adapter: adapter),
        ),
      );
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      final Object? value = c.valueOf('geo');
      expect((value! as ZGeoPoint).lat, adapter.tapPoint.lat);
      expect((value as ZGeoPoint).style?.strokeWidth, 5);
    });
  });

  group('G12 — chip de métriques (showMetrics, parité gff:1363-1391)', () {
    testWidgets('défaut → aucun chip (AD-4)', (tester) async {
      final c = _controller('geo', value: _triangle);
      await tester.pumpWidget(
        _app(c, _field('geo', type: EditionFieldType.geoArea),
            registry: _registry(adapter: FakeMapAdapter(), kind: 'geoArea')),
      );
      expect(find.byKey(const Key('z-geo-metrics')), findsNothing);
    });

    testWidgets(
        'polygone : compteur en gras + chip « aire | périmètre » aux formats '
        'legacy (m² sous 1 km², séparateur « | »)', (tester) async {
      final c = _controller('geo', value: _triangle);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              type: EditionFieldType.geoArea,
              config: const ZGeoFieldConfig(showMetrics: true)),
          registry: _registry(adapter: FakeMapAdapter(), kind: 'geoArea'),
        ),
      );
      expect(find.byKey(const Key('z-geo-metrics-count')), findsOneWidget);
      expect(find.text('3 points'), findsOneWidget);
      final Text chip = tester
          .widget<Text>(find.descendant(
            of: find.byKey(const Key('z-geo-metrics')),
            matching: find.byType(Text),
          ));
      // ~6182 m² | ~380 m (triangle ~111 m de côté) — unités via l10n (repli).
      expect(chip.data, contains('m²'));
      expect(chip.data, contains(' | '));
      expect(chip.data, isNot(contains('km²'))); // sous le seuil legacy 1e6
    });

    testWidgets('cercle : aire π·r² planaire + circonférence', (tester) async {
      const ZGeoCircle circle = ZGeoCircle(
        center: ZGeoPoint(lat: 6, lng: 1),
        radiusMeters: 100,
      );
      final c = _controller('geo', value: circle);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              config: const ZGeoFieldConfig(
                geometry: ZGeoGeometry.circle,
                showMetrics: true,
              )),
          registry: _registry(adapter: FakeMapAdapter()),
        ),
      );
      final Text chip = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('z-geo-metrics')),
        matching: find.byType(Text),
      ));
      expect(chip.data, contains('31416 m²')); // π·100² arrondi legacy (0 déc.)
      expect(chip.data, contains('628 m')); // 2π·100
    });
  });

  group('G16 — showOptimizeButton RÉEL (parité gff:922-959)', () {
    testWidgets(
        'barre standard (défaut) sur geoArea → bouton rendu ; tap → sommets '
        'réordonnés par angle et RÉÉMIS dans la tranche', (tester) async {
      final ZGeoShape bowtie = ZGeoShape(vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 1, lng: 1),
        ZGeoPoint(lat: 0, lng: 1),
        ZGeoPoint(lat: 1, lng: 0),
      ]);
      final c = _controller('geo', value: bowtie);
      await tester.pumpWidget(
        _app(c, _field('geo', type: EditionFieldType.geoArea),
            registry: _registry(adapter: FakeMapAdapter(), kind: 'geoArea')),
      );
      final Finder button = find.byKey(const Key('z-geo-optimize'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      final ZGeoShape next = c.valueOf('geo')! as ZGeoShape;
      expect(next.vertices, const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 0, lng: 1),
        ZGeoPoint(lat: 1, lng: 1),
        ZGeoPoint(lat: 1, lng: 0),
      ]);
      // SnackBar localisée (parité gff:952-958).
      await tester.pump();
      expect(find.text('Tracé optimisé et réordonné'), findsOneWidget);
    });

    testWidgets('< 3 sommets → no-op strict (aucune émission, aucun snack)',
        (tester) async {
      final ZGeoShape line =
          ZGeoShape(vertices: const <ZGeoPoint>[ZGeoPoint(lat: 0, lng: 0)]);
      final c = _controller('geo', value: line);
      await tester.pumpWidget(
        _app(c, _field('geo', type: EditionFieldType.geoArea),
            registry: _registry(adapter: FakeMapAdapter(), kind: 'geoArea')),
      );
      await tester.tap(find.byKey(const Key('z-geo-optimize')));
      await tester.pump();
      expect(c.valueOf('geo'), same(line));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('flag false (preset minimal) OU géométrie point → absent',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              type: EditionFieldType.geoArea,
              config: const ZGeoFieldConfig(
                toolbarConfig: ZGeoEditorToolbarConfig.minimal,
              )),
          registry: _registry(adapter: FakeMapAdapter(), kind: 'geoArea'),
        ),
      );
      expect(find.byKey(const Key('z-geo-optimize')), findsNothing);
      final c2 = _controller('p');
      await tester.pumpWidget(
        _app(c2, _field('p'), registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(find.byKey(const Key('z-geo-optimize')), findsNothing);
    });
  });

  group('G16 — useMapOptionsDropdown RÉEL (dropdown vs Wrap)', () {
    const ZGeoFieldConfig dropdownConfig = ZGeoFieldConfig(
      toolbarConfig: ZGeoEditorToolbarConfig.full, // useMapOptionsDropdown: true
    );

    testWidgets(
        'full (dropdown actif) → un menu unique remplace les toggles plats ; '
        'cocher « Trafic » bascule bien l\'option plombée à la carte',
        (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', config: dropdownConfig),
            registry: _registry(adapter: adapter)),
      );
      expect(
          find.byKey(const Key('z-geo-map-options-dropdown')), findsOneWidget);
      // Les toggles plats ne sont PAS rendus dans la barre (menu fermé).
      expect(find.byKey(const Key('z-geo-traffic')), findsNothing);
      expect(adapter.lastMapOptions?.trafficEnabled, isFalse);
      await tester.tap(find.byKey(const Key('z-geo-map-options-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('z-geo-traffic')));
      await tester.pumpAndSettle();
      expect(adapter.lastMapOptions?.trafficEnabled, isTrue);
    });

    testWidgets(
        'full SANS dropdown (copyWith(useMapOptionsDropdown: false)) → '
        'toggles plats rendus (comportement antérieur)', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              config: ZGeoFieldConfig(
                toolbarConfig: ZGeoEditorToolbarConfig.full
                    .copyWith(useMapOptionsDropdown: false),
              )),
          registry: _registry(adapter: FakeMapAdapter()),
        ),
      );
      expect(find.byKey(const Key('z-geo-map-options-dropdown')), findsNothing);
      expect(find.byKey(const Key('z-geo-traffic')), findsOneWidget);
    });
  });

  group('G19 — chrome legacy opt-in (encart/en-tête/pied/hauteur)', () {
    testWidgets('défaut → AUCUN chrome (rendu antérieur strict, AD-4)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(find.byKey(const Key('z-geo-chrome')), findsNothing);
      expect(find.byKey(const Key('z-geo-chrome-header')), findsNothing);
      expect(find.byKey(const Key('z-geo-footer')), findsNothing);
    });

    testWidgets(
        'showChrome → encart (rayon 14 de référence) + en-tête + pied '
        'LOCALISÉ « N points… » (jamais le texte anglais legacy)',
        (tester) async {
      final c = _controller('geo', value: _triangle);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              type: EditionFieldType.geoArea,
              config: const ZGeoFieldConfig(showChrome: true)),
          registry: _registry(adapter: FakeMapAdapter(), kind: 'geoArea'),
        ),
      );
      final Container card = tester
          .widget<Container>(find.byKey(const Key('z-geo-chrome')));
      final BoxDecoration deco = card.decoration! as BoxDecoration;
      expect(
        deco.borderRadius,
        BorderRadius.circular(ZGeoChromeReference.cardRadius),
      );
      expect(find.byKey(const Key('z-geo-chrome-header')), findsOneWidget);
      final Finder footer = find.byKey(const Key('z-geo-footer'));
      expect(footer, findsOneWidget);
      final Text footerText = tester.widget<Text>(
        find.descendant(of: footer, matching: find.byType(Text)),
      );
      expect(footerText.data, startsWith('3 '));
      // GARDE : jamais la chaîne anglaise codée en dur du legacy.
      expect(
        footerText.data,
        isNot(contains('points defined - Tap on map')),
      );
    });

    testWidgets('lecture seule → pas de pied (parité gff:1583)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              readOnly: true,
              config: const ZGeoFieldConfig(showChrome: true)),
          registry: _registry(adapter: FakeMapAdapter()),
        ),
      );
      expect(find.byKey(const Key('z-geo-chrome')), findsOneWidget);
      expect(find.byKey(const Key('z-geo-footer')), findsNothing);
    });

    testWidgets(
        'HAUTEUR (décision G19 documentée) : chrome → 300 (legacy) ; '
        'config.mapHeight PRIME ; hors chrome le défaut 200 ne bouge pas',
        (tester) async {
      SizedBox mapBox(WidgetTester t) => t.widget<SizedBox>(
            find.ancestor(
              of: find.byKey(FakeMapAdapter.mapKey),
              matching: find.byType(SizedBox),
            ).first,
          );
      // Chrome sans surcharge → hauteur legacy 300.
      final c1 = _controller('geo');
      await tester.pumpWidget(
        _app(c1,
            _field('geo', config: const ZGeoFieldConfig(showChrome: true)),
            registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(mapBox(tester).height, ZGeoChromeReference.chromeMapHeight);
      // Démonter entre scénarios : la config du champ est lue en initState
      // (late final) — un remontage propre est requis pour la re-lire.
      await tester.pumpWidget(const SizedBox.shrink());
      // Chrome + mapHeight: 250 → la config PRIME.
      final c2 = _controller('geo');
      await tester.pumpWidget(
        _app(
            c2,
            _field('geo',
                config: const ZGeoFieldConfig(
                    showChrome: true, mapHeight: 250)),
            registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(mapBox(tester).height, 250);
      await tester.pumpWidget(const SizedBox.shrink());
      // Hors chrome → défaut zcrud 200 STRICTEMENT inchangé (aucun hôte ne
      // bouge — pendant du handoff G22).
      final c3 = _controller('geo');
      await tester.pumpWidget(
        _app(c3, _field('geo'),
            registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(mapBox(tester).height, 200);
    });
  });

  group('G20 — compaction responsive (< 600 dp, parité gff:776,880)', () {
    testWidgets('largeur 500 → barre compacte (icônes seules, sans libellés)',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(find.byKey(const Key('z-geo-clear')), findsOneWidget);
      expect(find.text('Effacer'), findsNothing); // libellé masqué (compact)
    });

    testWidgets('largeur 800 (≥ seuil) → libellés rendus (inchangé)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: FakeMapAdapter())),
      );
      expect(find.text('Effacer'), findsOneWidget);
    });

    testWidgets(
        'seuil surchargeable : compactBreakpointDp 0 → jamais de compaction '
        'automatique, même à 500 dp (opt-out)', (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              config: ZGeoFieldConfig(
                toolbarConfig: ZGeoEditorToolbarConfig.standard
                    .copyWith(compactBreakpointDp: 0),
              )),
          registry: _registry(adapter: FakeMapAdapter()),
        ),
      );
      expect(find.text('Effacer'), findsOneWidget);
    });

    test('seuil de référence audité = 600 (gff:776,880)', () {
      expect(ZGeoChromeReference.compactBreakpointDp, 600);
    });
  });

  group('G21/G22/G23 — options et zoom plombés aux adaptateurs', () {
    testWidgets('G22 : la barre par défaut plombe rotation/tilt INACTIFS '
        '(défauts legacy gec:293-294) à la carte', (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: adapter)),
      );
      expect(adapter.lastMapOptions?.rotateGesturesEnabled, isFalse);
      expect(adapter.lastMapOptions?.tiltGesturesEnabled, isFalse);
      expect(adapter.lastMapOptions?.myLocationEnabled, isFalse); // G21 opt-in
    });

    testWidgets('G23 : minZoom/maxZoom de la config plombés à buildMap ; '
        'défaut null (comportement adaptateur inchangé)', (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo',
              config: const ZGeoFieldConfig(minZoom: 3, maxZoom: 19)),
          registry: _registry(adapter: adapter),
        ),
      );
      expect(adapter.lastMinZoom, 3);
      expect(adapter.lastMaxZoom, 19);
      final adapter2 = FakeMapAdapter();
      final c2 = _controller('geo');
      await tester.pumpWidget(
        _app(c2, _field('geo'), registry: _registry(adapter: adapter2)),
      );
      expect(adapter2.lastMinZoom, isNull);
      expect(adapter2.lastMaxZoom, isNull);
    });

    test('G23 : défauts legacy OSM en RÉFÉRENCE auditée (oma:162-167) ; le '
        'pas de zoom est une donnée SANS consommateur SDK (documenté)', () {
      expect(ZGeoChromeReference.osmMinZoom, 3);
      expect(ZGeoChromeReference.osmMaxZoom, 19);
      expect(ZGeoChromeReference.osmZoomStep, 1.0);
      const ZGeoFieldConfig cfg = ZGeoFieldConfig(zoomStep: 0.5);
      expect(cfg.zoomStep, 0.5); // exposé, copyWith/== couverts ailleurs
    });

    testWidgets('OSM honore minZoom/maxZoom (MapOptions) et rend les overlays '
        'G6 sans exception', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: Builder(
                builder: (context) => adapter.buildMap(
                  context,
                  center: const ZGeoPoint(lat: 6, lng: 1),
                  minZoom: 3,
                  maxZoom: 19,
                  overlays: <ZGeoMapOverlay>[
                    ZGeoMapOverlay(
                      id: 'a',
                      value: ZGeoShape(vertices: const <ZGeoPoint>[
                        ZGeoPoint(lat: 6, lng: 1),
                        ZGeoPoint(lat: 6, lng: 1.01),
                        ZGeoPoint(lat: 6.01, lng: 1.01),
                      ]),
                    ),
                    const ZGeoMapOverlay(
                      id: 'b',
                      value: ZGeoCircle(
                        center: ZGeoPoint(lat: 6.001, lng: 1.001),
                        radiusMeters: 50,
                      ),
                    ),
                  ],
                  onOverlayMarkerTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final FlutterMap map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.options.minZoom, 3);
      expect(map.options.maxZoom, 19);
      // Marqueurs d'ancrage tappables présents (sélection G6).
      expect(find.byKey(const ValueKey<String>('z-geo-osm-overlay-a')),
          findsOneWidget);
      expect(find.byKey(const ValueKey<String>('z-geo-osm-overlay-b')),
          findsOneWidget);
    });

    testWidgets('Google honore myLocation (G21) et minMaxZoomPreference (G23)',
        (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      Widget? built;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              built = adapter.buildMap(
                context,
                center: const ZGeoPoint(lat: 6, lng: 1),
                mapOptions: const ZGeoMapOptions(
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                ),
                minZoom: 5,
                maxZoom: 18,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final gmap.GoogleMap map = built! as gmap.GoogleMap;
      expect(map.myLocationEnabled, isTrue);
      expect(map.myLocationButtonEnabled, isFalse);
      expect(map.minMaxZoomPreference,
          const gmap.MinMaxZoomPreference(5, 18));
      // Sans options → défauts SDK inchangés (opt-in strict).
      Widget? plain;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              plain = adapter.buildMap(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final gmap.GoogleMap plainMap = plain! as gmap.GoogleMap;
      expect(plainMap.myLocationEnabled, isFalse);
      expect(plainMap.minMaxZoomPreference,
          gmap.MinMaxZoomPreference.unbounded);
    });
  });
}
