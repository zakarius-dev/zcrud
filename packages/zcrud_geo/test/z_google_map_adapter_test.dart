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
}
