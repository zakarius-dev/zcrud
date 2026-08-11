// AC8/AC12 — `ZGoogleMapAdapter` : 2e adaptateur carte, port neutre, SDK
// `google_maps_flutter` confiné, ZÉRO clé (AD-1/AD-12), dispose idempotent
// (learning E5). NOTE testabilité : `google_maps_flutter` s'affiche via une
// PlatformView native NON peinte sous `flutter test` (headless). La preuve
// automatisée se limite donc à : conformité de signature neutre, `dispose`
// idempotent, `buildMap(...)` qui CONSTRUIT le graphe de widgets sans exception
// (sans monter la PlatformView). Le rendu interactif réel est validé hors CI.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zcrud_geo/adapters/google.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('AC8 — conformité port neutre', () {
    test('ZGoogleMapAdapter implements ZMapAdapter (signatures neutres)', () {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      expect(adapter, isA<ZMapAdapter>());
    });
  });

  group('AC12 — dispose idempotent (learning E5)', () {
    test('dispose() sans montage ne throw pas (fabrique appelée puis démontée)',
        () {
      final adapter = ZGoogleMapAdapter();
      expect(adapter.dispose, returnsNormally);
    });

    test('dispose() est idempotent (deux appels ne throw pas)', () {
      final adapter = ZGoogleMapAdapter();
      expect(adapter.dispose, returnsNormally);
      expect(adapter.dispose, returnsNormally);
    });
  });

  group('AC8 — buildMap construit le graphe neutre sans exception', () {
    // On invoque buildMap pour CONSTRUIRE le graphe (GoogleMap + markers/
    // polygons/circles) mais on NE monte PAS la PlatformView native (retour d'un
    // SizedBox à l'arbre) : preuve du non-throw au build sans dépendre d'un rendu
    // natif indisponible en headless.
    testWidgets('point : buildMap → Widget sans throw', (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      late Widget map;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              map = adapter.buildMap(
                context,
                center: const ZGeoPoint(lat: 13.5, lng: 2.1),
                onTap: (_) {},
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(map, isA<Widget>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('cercle + polygone : buildMap → Widget sans throw',
        (tester) async {
      final adapter = ZGoogleMapAdapter(mapStyleJson: '[]');
      addTearDown(adapter.dispose);
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 2, lng: 0),
        ],
      );
      late Widget map;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              map = adapter.buildMap(
                context,
                shape: shape,
                circle: const ZGeoCircle(
                  center: ZGeoPoint(lat: 1, lng: 1),
                  radiusMeters: 500,
                ),
                interactive: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(map, isA<Widget>());
      expect(tester.takeException(), isNull);
    });

    testWidgets('cercle invalide (rayon ≤0) ignoré sans throw', (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      late Widget map;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              map = adapter.buildMap(
                context,
                circle: const ZGeoCircle(
                  center: ZGeoPoint(lat: 1, lng: 1),
                  radiusMeters: 0,
                ),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(map, isA<Widget>());
      expect(tester.takeException(), isNull);
    });
  });

  group('DP-21/M13 — Google : polyligne + style + holes honorés', () {
    Future<GoogleMap> buildGoogleMap(
      WidgetTester tester,
      Widget Function(BuildContext) build,
    ) async {
      late Widget map;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              map = build(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return map as GoogleMap;
    }

    testWidgets('renderShapeAsPolyline: true → une Polyline, aucun Polygon',
        (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 2, lng: 0),
        ],
      );
      final map = await buildGoogleMap(
        tester,
        (context) => adapter.buildMap(
          context,
          shape: shape,
          renderShapeAsPolyline: true,
        ),
      );
      expect(map.polylines, hasLength(1)); // tracé ouvert rendu
      expect(map.polygons, isEmpty); // aucun polygone fermé
    });

    testWidgets('polygone (défaut) → un Polygon, aucune Polyline',
        (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 2, lng: 0),
        ],
      );
      final map = await buildGoogleMap(
        tester,
        (context) => adapter.buildMap(context, shape: shape),
      );
      expect(map.polygons, hasLength(1));
      expect(map.polylines, isEmpty);
    });

    testWidgets('style ARGB honoré : couleurs traduites en Color SDK confiné',
        (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 2, lng: 0),
        ],
        style: const ZGeoShapeStyle(
          fillColorArgb: 0x33FF0000,
          strokeColorArgb: 0xFF0000FF,
          strokeWidth: 6,
        ),
        holes: const <List<ZGeoPoint>>[
          <ZGeoPoint>[
            ZGeoPoint(lat: 0.2, lng: 0.2),
            ZGeoPoint(lat: 0.4, lng: 0.4),
            ZGeoPoint(lat: 0.3, lng: 0.1),
          ],
        ],
      );
      final map = await buildGoogleMap(
        tester,
        (context) => adapter.buildMap(context, shape: shape),
      );
      final Polygon poly = map.polygons.single;
      expect(poly.fillColor, const Color(0x33FF0000));
      expect(poly.strokeColor, const Color(0xFF0000FF));
      expect(poly.strokeWidth, 6);
      expect(poly.holes, hasLength(1)); // trou honoré
    });

    testWidgets('sans style → défauts SDK d\'origine (rétro-compat E11b-1)',
        (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 2, lng: 0),
        ],
      );
      final map = await buildGoogleMap(
        tester,
        (context) => adapter.buildMap(context, shape: shape),
      );
      final Polygon poly = map.polygons.single;
      // Défauts SDK d'origine préservés (avant DP-21 : Colors.black / width 10).
      expect(poly.strokeWidth, 10);
      expect(poly.holes, isEmpty);
    });
  });

  group('G7 — caméra ZGoogleMapAdapter (ZMapCameraCapable)', () {
    test('l\'adaptateur opte pour caméra + gestes', () {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      expect(adapter, isA<ZMapCameraCapable>());
      expect(adapter, isA<ZMapGesturesCapable>());
    });

    test(
        'moveCamera/fitBounds AVANT création du contrôleur natif → no-op '
        'IMMÉDIAT (ne suspend jamais sur un Completer incomplet — AD-10)',
        () async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      // Si l\'implémentation attendait le Completer jamais complété, ces
      // futures ne complèteraient JAMAIS → timeout du test.
      await adapter
          .moveCamera(const ZGeoPoint(lat: 6, lng: 1), zoom: 16)
          .timeout(const Duration(seconds: 1));
      await adapter
          .fitBounds(
            const ZGeoPoint(lat: 5, lng: 0),
            const ZGeoPoint(lat: 7, lng: 2),
          )
          .timeout(const Duration(seconds: 1));
    });

    test('moveCamera APRÈS dispose → no-op sans throw', () async {
      final adapter = ZGoogleMapAdapter();
      adapter.dispose();
      await adapter.moveCamera(const ZGeoPoint(lat: 6, lng: 1));
    });
  });

  group('G11/G13 — marqueurs draggables natifs Google (si handler posé)', () {
    final ZGeoShape triShape = ZGeoShape(
      vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 1, lng: 1),
        ZGeoPoint(lat: 2, lng: 0),
      ],
    );

    /// Construit le graphe via buildMap et CAPTURE le widget `GoogleMap` pour
    /// inspecter ses marqueurs (aucune PlatformView montée).
    Future<GoogleMap> capture(
      WidgetTester tester,
      ZGoogleMapAdapter adapter, {
      ZGeoShape? shape,
      ZGeoCircle? circle,
    }) async {
      late final Widget built;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              built = adapter.buildMap(context, shape: shape, circle: circle);
              return const SizedBox();
            },
          ),
        ),
      );
      return built as GoogleMap;
    }

    testWidgets('sans handler → AUCUN marqueur de sommet (rendu antérieur, AD-4)',
        (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final GoogleMap map = await capture(tester, adapter, shape: triShape);
      expect(
        map.markers.where(
          (Marker m) => m.markerId.value.startsWith('z-geo-vertex-'),
        ),
        isEmpty,
      );
      expect(
        map.markers.where((Marker m) => m.markerId.value == 'z-geo-move-handle'),
        isEmpty,
      );
    });

    testWidgets(
        'onVertexDragEnd posé → un marqueur draggable PAR SOMMET ; onDragEnd '
        'remonte (index, point neutre)', (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final List<(int, ZGeoPoint)> dragged = <(int, ZGeoPoint)>[];
      adapter.onVertexDragEnd = (int i, ZGeoPoint p) => dragged.add((i, p));
      final GoogleMap map = await capture(tester, adapter, shape: triShape);
      final List<Marker> vertexMarkers = map.markers
          .where((Marker m) => m.markerId.value.startsWith('z-geo-vertex-'))
          .toList();
      expect(vertexMarkers, hasLength(3));
      expect(vertexMarkers.every((Marker m) => m.draggable), isTrue);
      // Simule la fin de drag native du sommet 1.
      final Marker m1 = vertexMarkers
          .singleWhere((Marker m) => m.markerId.value == 'z-geo-vertex-1');
      m1.onDragEnd!(const LatLng(1.5, 1.5));
      expect(dragged.single, equals((1, const ZGeoPoint(lat: 1.5, lng: 1.5))));
    });

    testWidgets('onShapeDragEnd posé → marqueur draggable au centroïde ; '
        'onDragEnd remonte le DELTA', (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final List<(double, double)> deltas = <(double, double)>[];
      adapter.onShapeDragEnd =
          (double dLat, double dLng) => deltas.add((dLat, dLng));
      final GoogleMap map = await capture(tester, adapter, shape: triShape);
      final Marker handle = map.markers
          .singleWhere((Marker m) => m.markerId.value == 'z-geo-move-handle');
      expect(handle.draggable, isTrue);
      // Centroïde du triangle = (1, 1/3) ; fin de drag à (1.5, 0.5).
      handle.onDragEnd!(const LatLng(1.5, 0.5));
      expect(deltas.single.$1, closeTo(0.5, 1e-9));
      expect(deltas.single.$2, closeTo(0.5 - 1 / 3, 1e-9));
    });

    testWidgets('onCircleRadiusDragEnd posé → poignée draggable au périmètre '
        'EST ; onDragEnd remonte le rayon haversine', (tester) async {
      final adapter = ZGoogleMapAdapter();
      addTearDown(adapter.dispose);
      final List<double> radii = <double>[];
      adapter.onCircleRadiusDragEnd = radii.add;
      const circle = ZGeoCircle(
        center: ZGeoPoint(lat: 0, lng: 0),
        radiusMeters: 500,
      );
      final GoogleMap map =
          await capture(tester, adapter, circle: circle);
      final Marker handle = map.markers
          .singleWhere((Marker m) => m.markerId.value == 'z-geo-radius-handle');
      expect(handle.draggable, isTrue);
      // La poignée est posée ~500 m à l\'EST du centre.
      expect(
        const ZGeoPoint(lat: 0, lng: 0).distanceMetersTo(
          ZGeoPoint(
            lat: handle.position.latitude,
            lng: handle.position.longitude,
          ),
        ),
        closeTo(500, 1),
      );
      // Fin de drag à ~0.01° est (≈ 1112 m).
      handle.onDragEnd!(const LatLng(0, 0.01));
      expect(radii.single, closeTo(1111.95, 1));
    });
  });
}
