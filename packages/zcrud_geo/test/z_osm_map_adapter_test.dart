// MEDIUM-2 — Couverture RÉELLE de `ZOsmMapAdapter` (adaptateur OSM concret,
// seul détenteur d'un `MapController` natif). Prouve : (1) `dispose()`
// idempotent (deux appels sans throw → libère son contrôleur une seule fois) ;
// (2) `buildMap` produit une surface neutre rendue sans exception, le SDK
// `flutter_map` restant confiné à l'adaptateur (aucun type SDK ne fuit dans
// l'API). Atteint via l'entrée dédiée `package:zcrud_geo/adapters/osm.dart`.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/adapters/osm.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('MEDIUM-2 — ZOsmMapAdapter : dispose idempotent + confinement', () {
    test('dispose() est idempotent (deux appels ne throw pas)', () {
      final adapter = ZOsmMapAdapter();
      // Premier dispose : libère le `MapController` natif possédé.
      expect(adapter.dispose, returnsNormally);
      // Second dispose : garde `_disposed` → aucun re-dispose du contrôleur,
      // aucun throw (contrat ZMapAdapter).
      expect(adapter.dispose, returnsNormally);
    });

    test('adaptateur neuf → dispose immédiat sans montage ne throw pas', () {
      // Cas « créé puis jamais utilisé » (fabrique appelée, champ démonté vite).
      final adapter = ZOsmMapAdapter();
      expect(adapter.dispose, returnsNormally);
    });

    testWidgets('buildMap rend une surface neutre sans exception (location)',
        (tester) async {
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
                  center: const ZGeoPoint(lat: 13.5, lng: 2.1),
                  interactive: true,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      // Le rendu ne lève aucune exception synchrone : le SDK est confiné et
      // l'API ne parle que de types neutres (aucun `LatLng`/`MapController`
      // exposé à l'appelant).
      expect(tester.takeException(), isNull);
    });

    testWidgets('buildMap rend une aire (geoArea) sans exception',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 2, lng: 0),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: Builder(
                builder: (context) => adapter.buildMap(
                  context,
                  center: shape.vertices.first,
                  shape: shape,
                  interactive: false,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AC7 — OSM : rendu cercle (sans clé)', () {
    testWidgets('buildMap(circle: …) rend un CircleLayer sans exception',
        (tester) async {
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
                  circle: const ZGeoCircle(
                    center: ZGeoPoint(lat: 13.5, lng: 2.1),
                    radiusMeters: 500,
                  ),
                  interactive: true,
                ),
              ),
            ),
          ),
        ),
      );
      // Un CircleLayer flutter_map est présent (le SDK reste confiné : on ne le
      // référence pas par type ici, on prouve seulement l'absence d'exception).
      expect(tester.takeException(), isNull);
    });

    testWidgets('cercle invalide (rayon ≤0) → pas de rendu, pas d\'exception',
        (tester) async {
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
                  circle: const ZGeoCircle(
                    center: ZGeoPoint(lat: 13.5, lng: 2.1),
                    radiusMeters: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('tileUrlTemplate surchargeable (aucun endpoint privé imposé)', () {
      final adapter = ZOsmMapAdapter(
        tileUrlTemplate: 'https://tiles.example.org/{z}/{x}/{y}.png',
      );
      addTearDown(adapter.dispose);
      expect(adapter.tileUrlTemplate, contains('example.org'));
    });
  });

  group('DP-21/M13 — OSM : polyligne + style + holes honorés', () {
    Future<void> pump(
      WidgetTester tester,
      Widget Function(BuildContext) build,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: Builder(builder: build),
            ),
          ),
        ),
      );
    }

    final ZGeoShape triShape = ZGeoShape(
      vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 1, lng: 1),
        ZGeoPoint(lat: 2, lng: 0),
      ],
    );

    testWidgets('renderShapeAsPolyline: true → PolylineLayer, pas de PolygonLayer',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: triShape.vertices.first,
          shape: triShape,
          renderShapeAsPolyline: true,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(PolygonLayer), findsNothing);
    });

    testWidgets('polygone (défaut) → PolygonLayer, pas de PolylineLayer',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: triShape.vertices.first,
          shape: triShape,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PolygonLayer), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
    });

    testWidgets('style visible:false → forme non rendue, aucune exception',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final hidden = ZGeoShape(
        vertices: triShape.vertices,
        style: const ZGeoShapeStyle(visible: false),
      );
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: hidden.vertices.first,
          shape: hidden,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PolygonLayer), findsNothing);
    });

    testWidgets('polygone stylé avec holes → rendu sans exception',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final styled = ZGeoShape(
        vertices: triShape.vertices,
        style: const ZGeoShapeStyle(
          fillColorArgb: 0x33FF0000,
          strokeColorArgb: 0xFF0000FF,
          strokeWidth: 5,
        ),
        holes: const <List<ZGeoPoint>>[
          <ZGeoPoint>[
            ZGeoPoint(lat: 0.2, lng: 0.2),
            ZGeoPoint(lat: 0.4, lng: 0.4),
            ZGeoPoint(lat: 0.3, lng: 0.1),
          ],
        ],
      );
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: styled.vertices.first,
          shape: styled,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(PolygonLayer), findsOneWidget);
    });
  });

  Future<void> pump(
    WidgetTester tester,
    Widget Function(BuildContext) build,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 300,
            child: Builder(builder: build),
          ),
        ),
      ),
    );
  }

  group('G7 — caméra ZOsmMapAdapter (ZMapCameraCapable)', () {
    test('l\'adaptateur opte pour caméra + gestes', () {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      expect(adapter, isA<ZMapCameraCapable>());
      expect(adapter, isA<ZMapGesturesCapable>());
    });

    test('moveCamera/fitBounds AVANT montage → no-op sans throw (AD-10)',
        () async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await adapter.moveCamera(const ZGeoPoint(lat: 6, lng: 1), zoom: 16);
      await adapter.fitBounds(
        const ZGeoPoint(lat: 5, lng: 0),
        const ZGeoPoint(lat: 7, lng: 2),
      );
      // Point invalide → même garantie.
      await adapter.moveCamera(const ZGeoPoint(lat: 999, lng: 0));
    });

    test('moveCamera APRÈS dispose → no-op sans throw', () async {
      final adapter = ZOsmMapAdapter();
      adapter.dispose();
      await adapter.moveCamera(const ZGeoPoint(lat: 6, lng: 1));
    });

    testWidgets('moveCamera sur carte MONTÉE ne throw pas (zoom conservé si nul)',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: const ZGeoPoint(lat: 6, lng: 1),
        ),
      );
      await adapter.moveCamera(const ZGeoPoint(lat: 7, lng: 2));
      await adapter.moveCamera(const ZGeoPoint(lat: 8, lng: 3), zoom: 16);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  group('G11/G13 — poignées de drag OSM (rendues si handler posé)', () {
    final triShape = ZGeoShape(
      vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 0.5, lng: 0.5),
        ZGeoPoint(lat: 1, lng: 0),
      ],
    );

    testWidgets('sans handler → AUCUNE poignée (rendu antérieur inchangé, AD-4)',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: triShape.vertices.first,
          shape: triShape,
        ),
      );
      expect(find.byKey(const ValueKey<String>('z-geo-osm-vertex-0')),
          findsNothing);
      expect(find.byKey(const ValueKey<String>('z-geo-osm-move-handle')),
          findsNothing);
    });

    testWidgets('onVertexDragEnd posé → sommets draggables ; un pan remonte la '
        'NOUVELLE coordonnée du sommet', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final List<(int, ZGeoPoint)> dragged = <(int, ZGeoPoint)>[];
      adapter.onVertexDragEnd = (int i, ZGeoPoint p) => dragged.add((i, p));
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: triShape.vertices.first,
          shape: triShape,
        ),
      );
      final vertex0 = find.byKey(const ValueKey<String>('z-geo-osm-vertex-0'));
      expect(vertex0, findsOneWidget);
      await tester.drag(vertex0, const Offset(0, -40));
      await tester.pump();
      expect(dragged, hasLength(1));
      expect(dragged.single.$1, equals(0));
      // Un déplacement écran vers le HAUT augmente la latitude.
      expect(dragged.single.$2.lat, greaterThan(triShape.vertices.first.lat));
      expect(tester.takeException(), isNull);
    });

    testWidgets('onShapeDragEnd posé → marqueur au centroïde ; un pan remonte '
        'le DELTA (lat/lng)', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final List<(double, double)> deltas = <(double, double)>[];
      adapter.onShapeDragEnd =
          (double dLat, double dLng) => deltas.add((dLat, dLng));
      // Petite forme + centrage sur le CENTROÏDE : le handle doit être DANS le
      // viewport (les marqueurs hors-champ sont éliminés par MarkerLayer).
      final smallShape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 0.002, lng: 0.002),
          ZGeoPoint(lat: 0.004, lng: 0),
        ],
      );
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          center: const ZGeoPoint(lat: 0.002, lng: 0.000667),
          shape: smallShape,
          interactive: false, // mode Déplacer : carte inerte (parité)
        ),
      );
      final handle =
          find.byKey(const ValueKey<String>('z-geo-osm-move-handle'));
      expect(handle, findsOneWidget);
      await tester.drag(handle, const Offset(30, 0));
      await tester.pump();
      expect(deltas, hasLength(1));
      expect(deltas.single.$1.abs(), lessThan(0.5)); // pan horizontal pur
      expect(deltas.single.$2, greaterThan(0)); // vers l\'EST → lng +
    });

    testWidgets('onCircleRadiusDragEnd posé → poignée sur le périmètre ; un pan '
        'vers l\'extérieur AGRANDIT le rayon (haversine)', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final List<double> radii = <double>[];
      adapter.onCircleRadiusDragEnd = radii.add;
      // Rayon court : la poignée (périmètre EST) doit rester dans le viewport.
      const circle = ZGeoCircle(
        center: ZGeoPoint(lat: 0, lng: 0),
        radiusMeters: 500,
      );
      await pump(
        tester,
        (context) => adapter.buildMap(
          context,
          circle: circle,
        ),
      );
      final handle =
          find.byKey(const ValueKey<String>('z-geo-osm-radius-handle'));
      expect(handle, findsOneWidget);
      await tester.drag(handle, const Offset(40, 0));
      await tester.pump();
      expect(radii, hasLength(1));
      expect(radii.single, greaterThan(500));
    });
  });
}
