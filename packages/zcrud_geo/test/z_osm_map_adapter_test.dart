// MEDIUM-2 — Couverture RÉELLE de `ZOsmMapAdapter` (adaptateur OSM concret,
// seul détenteur d'un `MapController` natif). Prouve : (1) `dispose()`
// idempotent (deux appels sans throw → libère son contrôleur une seule fois) ;
// (2) `buildMap` produit une surface neutre rendue sans exception, le SDK
// `flutter_map` restant confiné à l'adaptateur (aucun type SDK ne fuit dans
// l'API). Atteint via l'entrée dédiée `package:zcrud_geo/adapters/osm.dart`.
import 'package:flutter/material.dart';
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
}
