// CR geo — lot « rendu » (G3 tuiles OSM typées, G9 style sur les 3 types,
// G14 marqueurs labellisés, G17 iconSize/iconAnchor/iconRotation, G18 presets).
// Références legacy mesurées : `oma:53-110` (ESRI World Imagery satellite ET
// hybride — même URL, OpenTopoMap terrain), `zosm:176-180` (primary en dur du
// cercle, supprimé), `gma:185-233` (pastille de texte), `gs:109-116` (champs
// d'icône), `gs:154-177` (presets bleu 0xFF4285F4).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/adapters/google.dart';
import 'package:zcrud_geo/adapters/osm.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';
import 'support/z_sources.dart' show stripComments;

/// Monte `adapter.buildMap` seul (hors champ) et rend la surface.
Future<void> _pumpOsm(
  WidgetTester tester,
  ZOsmMapAdapter adapter, {
  ZGeoPoint? center,
  ZGeoCircle? circle,
  String? tileUrlTemplate,
  Map<ZGeoMapType, String>? tileUrlTemplates,
  ZGeoMapOptions? mapOptions,
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 300,
          child: Builder(
            builder: (context) => adapter.buildMap(
              context,
              center: center,
              circle: circle,
              tileUrlTemplate: tileUrlTemplate,
              tileUrlTemplates: tileUrlTemplates,
              mapOptions: mapOptions,
            ),
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

String _osmTiles(WidgetTester tester) =>
    tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate!;

/// Construit (sans rendre) le `GoogleMap` produit par l'adaptateur Google.
Future<gmap.GoogleMap> _buildGoogle(
  WidgetTester tester, {
  ZGeoPoint? center,
  ZGeoCircle? circle,
}) async {
  final adapter = ZGoogleMapAdapter();
  addTearDown(adapter.dispose);
  Widget? map;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          map = adapter.buildMap(context, center: center, circle: circle);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  expect(tester.takeException(), isNull);
  return map! as gmap.GoogleMap;
}

const ZGeoCircle _circle = ZGeoCircle(
  center: ZGeoPoint(lat: 6.13, lng: 1.28),
  radiusMeters: 300,
);

void main() {
  group('G3 — tuiles OSM typées (parité oma:53-110)', () {
    testWidgets('mapType satellite → ESRI World Imagery (référence auditée)',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        mapOptions: const ZGeoMapOptions(mapType: ZGeoMapType.satellite),
      );
      expect(_osmTiles(tester), ZGeoTileReference.esriWorldImagery);
      expect(_osmTiles(tester), contains('server.arcgisonline.com'));
      expect(_osmTiles(tester), contains('World_Imagery'));
    });

    testWidgets(
        'mapType hybrid → la MÊME imagerie ESRI que satellite (mesuré : le '
        'legacy n\'ajoute AUCUNE couche de labels malgré son commentaire)',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        mapOptions: const ZGeoMapOptions(mapType: ZGeoMapType.hybrid),
      );
      expect(_osmTiles(tester), ZGeoTileReference.esriWorldImagery);
    });

    testWidgets('mapType terrain → OpenTopoMap (référence auditée)',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        mapOptions: const ZGeoMapOptions(mapType: ZGeoMapType.terrain),
      );
      expect(_osmTiles(tester), ZGeoTileReference.openTopoMap);
      expect(_osmTiles(tester), contains('tile.opentopomap.org'));
    });

    testWidgets('mapType normal / sans mapOptions → tuiles OSM standard '
        '(rétro-compat stricte)', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(tester, adapter);
      expect(_osmTiles(tester), ZGeoTileReference.osmStandard);
    });

    testWidgets('SURCHARGE par paramètre buildMap : tileUrlTemplates[type] '
        'PRIME sur la référence auditée', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        mapOptions: const ZGeoMapOptions(mapType: ZGeoMapType.satellite),
        tileUrlTemplates: const <ZGeoMapType, String>{
          ZGeoMapType.satellite: 'https://tiles.example.test/{z}/{x}/{y}.png',
        },
      );
      expect(_osmTiles(tester), 'https://tiles.example.test/{z}/{x}/{y}.png');
    });

    testWidgets('SURCHARGE au constructeur : ZOsmMapAdapter(tileUrlTemplates:) '
        'prime sur la référence, cède au paramètre par-champ', (tester) async {
      final adapter = ZOsmMapAdapter(
        tileUrlTemplates: const <ZGeoMapType, String>{
          ZGeoMapType.terrain: 'https://ctor.example.test/{z}/{x}/{y}.png',
        },
      );
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        mapOptions: const ZGeoMapOptions(mapType: ZGeoMapType.terrain),
      );
      expect(_osmTiles(tester), 'https://ctor.example.test/{z}/{x}/{y}.png');
    });

    testWidgets('un type ABSENT de la surcharge partielle retombe sur la '
        'référence auditée de CE type', (tester) async {
      final adapter = ZOsmMapAdapter(
        tileUrlTemplates: const <ZGeoMapType, String>{
          ZGeoMapType.terrain: 'https://ctor.example.test/{z}/{x}/{y}.png',
        },
      );
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        mapOptions: const ZGeoMapOptions(mapType: ZGeoMapType.satellite),
      );
      expect(_osmTiles(tester), ZGeoTileReference.esriWorldImagery);
    });

    testWidgets('plomberie champ→carte : ZGeoFieldConfig.tileUrlTemplates '
        'atteint buildMap', (tester) async {
      final fake = FakeMapAdapter();
      const templates = <ZGeoMapType, String>{
        ZGeoMapType.satellite: 'https://cfg.example.test/{z}/{x}/{y}.png',
      };
      final c = ZFormController(
        initialValues: const <String, Object?>{'geo': null},
        visibleFields: const <String>['geo'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            widgetRegistry: ZWidgetRegistry()
              ..register(
                'location',
                ZGeoFieldWidget.builder(adapterFactory: () => fake),
              ),
            child: Scaffold(
              body: DynamicEdition(
                controller: c,
                fields: const <ZFieldSpec>[
                  ZFieldSpec(
                    name: 'geo',
                    type: EditionFieldType.location,
                    config: ZGeoFieldConfig(tileUrlTemplates: templates),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(fake.lastTileUrlTemplates, templates);
    });

    test('AD-12/audit — les endpoints ESRI/OpenTopoMap ne vivent QUE dans le '
        'fichier de référence (grep négatif montré)', () {
      final libDir = Directory('packages/zcrud_geo/lib').existsSync()
          ? Directory('packages/zcrud_geo/lib')
          : Directory('lib');
      final offenders = <String>[];
      for (final e in libDir.listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        if (e.path.endsWith('z_geo_tile_reference.dart')) continue;
        // P0D2 : source dé-commentée — l'endpoint public reste légitimement
        // cité en dartdoc par les fichiers qui EXPLIQUENT l'exemption (pas un
        // secret : URL de tuiles publique, cf. scission RTL/confinement).
        final src = stripComments(e.readAsStringSync());
        if (src.contains('arcgisonline.com') ||
            src.contains('opentopomap.org')) {
          offenders.add(e.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'endpoints de tuiles hors du fichier de référence audité : '
              '$offenders');
    });
  });

  group('G9 — style porté par le CERCLE, honoré par OSM (zosm:176-180)', () {
    testWidgets('cercle SANS style → repli thème (colorScheme.primary), '
        'rendu antérieur préservé', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final theme = ThemeData(
        colorScheme: const ColorScheme.light(primary: Color(0xFF123456)),
      );
      await _pumpOsm(tester, adapter, circle: _circle, theme: theme);
      final layer = tester.widget<CircleLayer>(find.byType(CircleLayer));
      final marker = layer.circles.single;
      expect(marker.borderColor, const Color(0xFF123456));
      expect(marker.color, const Color(0xFF123456).withValues(alpha: 0.2));
      expect(marker.borderStrokeWidth, 2);
    });

    testWidgets('cercle AVEC style → le style PRIME sur le thème (le primary '
        'en dur de zosm:176-180 est supprimé)', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      final styled = _circle.copyWith(
        style: const ZGeoShapeStyle(
          fillColorArgb: 0x33112233,
          strokeColorArgb: 0xFFAABBCC,
          strokeWidth: 5,
        ),
      );
      await _pumpOsm(tester, adapter, circle: styled, theme: ThemeData());
      final layer = tester.widget<CircleLayer>(find.byType(CircleLayer));
      final marker = layer.circles.single;
      expect(marker.color, const Color(0x33112233));
      expect(marker.borderColor, const Color(0xFFAABBCC));
      expect(marker.borderStrokeWidth, 5);
    });

    testWidgets('style.visible == false → le cercle n\'est PAS rendu',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        circle: _circle.copyWith(
          style: const ZGeoShapeStyle(visible: false),
        ),
      );
      expect(find.byType(CircleLayer), findsNothing);
    });
  });

  group('G9 — style porté par le cercle, honoré par Google', () {
    testWidgets('cercle SANS style → défauts SDK antérieurs EXACTS '
        '(rétro-compat AD-4)', (tester) async {
      final map = await _buildGoogle(tester, circle: _circle);
      final c = map.circles.single;
      expect(c.fillColor, const Color(0x00000000));
      expect(c.strokeColor, const Color(0xFF000000));
      expect(c.strokeWidth, 10);
      expect(c.visible, isTrue);
    });

    testWidgets('cercle AVEC style → fill/stroke/épaisseur honorés',
        (tester) async {
      final map = await _buildGoogle(
        tester,
        circle: _circle.copyWith(
          style: const ZGeoShapeStyle(
            fillColorArgb: 0x33445566,
            strokeColorArgb: 0xFF445566,
            strokeWidth: 3,
          ),
        ),
      );
      final c = map.circles.single;
      expect(c.fillColor, const Color(0x33445566));
      expect(c.strokeColor, const Color(0xFF445566));
      expect(c.strokeWidth, 3);
    });
  });

  group('G14 — marqueurs labellisés (parité gma:185-233, écarts documentés)',
      () {
    testWidgets('OSM : infoWindowTitle → pastille de texte visible en continu '
        '(couleurs par rôles de thème, jamais de littéral)', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        center: const ZGeoPoint(
          lat: 6.13,
          lng: 1.28,
          style: ZGeoShapeStyle(infoWindowTitle: 'Poste 4'),
        ),
      );
      expect(find.text('Poste 4'), findsOneWidget);
      // La pastille remplace l'icône par défaut (parité : le bitmap legacy EST
      // le marqueur).
      expect(find.byIcon(Icons.place), findsNothing);
    });

    testWidgets('OSM : iconColorArgb → icône teintée ; iconSize → taille ; '
        'sans style → Icons.place d\'origine', (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        center: const ZGeoPoint(
          lat: 6.13,
          lng: 1.28,
          style: ZGeoShapeStyle(iconColorArgb: 0xFF4285F4, iconSize: 56),
        ),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.place));
      expect(icon.color, const Color(0xFF4285F4));
      expect(icon.size, 56);
    });

    testWidgets('OSM : G17 iconRotation ≠ 0 → Transform.rotate appliqué',
        (tester) async {
      final adapter = ZOsmMapAdapter();
      addTearDown(adapter.dispose);
      await _pumpOsm(
        tester,
        adapter,
        center: const ZGeoPoint(
          lat: 6.13,
          lng: 1.28,
          style: ZGeoShapeStyle(iconRotation: 90),
        ),
      );
      expect(
        find.ancestor(
          of: find.byIcon(Icons.place),
          matching: find.byType(Transform),
        ),
        findsWidgets,
      );
    });

    testWidgets('Google : infoWindowTitle/snippet → InfoWindow natif ; '
        'iconRotation/iconAnchor honorés (G17) — écart documenté : libellé au '
        'tap, pas de bitmap peint', (tester) async {
      final map = await _buildGoogle(
        tester,
        center: const ZGeoPoint(
          lat: 6.13,
          lng: 1.28,
          style: ZGeoShapeStyle(
            infoWindowTitle: 'Poste 4',
            infoWindowSnippet: 'BMD',
            iconRotation: 45,
            iconAnchor: ZGeoPoint(lat: 1.0, lng: 0.5),
          ),
        ),
      );
      final m = map.markers.single;
      expect(m.infoWindow.title, 'Poste 4');
      expect(m.infoWindow.snippet, 'BMD');
      expect(m.rotation, 45);
      expect(m.anchor, const Offset(0.5, 1.0)); // (lng→dx, lat→dy)
    });

    testWidgets('Google : SANS style → Marker d\'origine strict (pas '
        'd\'InfoWindow, pas de rotation)', (tester) async {
      final map = await _buildGoogle(
        tester,
        center: const ZGeoPoint(lat: 6.13, lng: 1.28),
      );
      final m = map.markers.single;
      expect(m.infoWindow, gmap.InfoWindow.noText);
      expect(m.rotation, 0.0);
    });
  });

  group('G17 — iconSize/iconAnchor/iconRotation sur ZGeoShapeStyle', () {
    test('fromMapSafe LIT les clés (les données legacy G1 ne sont plus '
        'jetées)', () {
      final style = ZGeoShapeStyle.fromMapSafe(<String, Object?>{
        'iconSize': 48.0,
        'iconAnchor': <String, Object?>{'lat': 1.0, 'lng': 0.5},
        'iconRotation': 33.0,
      })!;
      expect(style.iconSize, 48.0);
      expect(style.iconAnchor, const ZGeoPoint(lat: 1.0, lng: 0.5));
      expect(style.iconRotation, 33.0);
    });

    test('chaîne legacy COMPLÈTE (enveloppe String jusqu\'au style) : la '
        'lecture G1 capte désormais les 3 clés', () {
      final raw = jsonEncode(<String, Object?>{
        'type': 'point',
        'points': <Object?>[
          <String, Object?>{'lat': 6.13, 'lng': 1.28},
        ],
        'style': <String, Object?>{
          'iconColor': 0xFF4285F4,
          'iconSize': 40.0,
          'iconAnchor': <String, Object?>{'lat': 0.5, 'lng': 0.5},
          'iconRotation': 12.0,
        },
      });
      final point = ZGeoValue.fromMapSafe(raw)! as ZGeoPoint;
      expect(point.style, isNotNull);
      expect(point.style!.iconColorArgb, 0xFF4285F4);
      expect(point.style!.iconSize, 40.0);
      expect(point.style!.iconRotation, 12.0);
      expect(point.style!.iconAnchor, const ZGeoPoint(lat: 0.5, lng: 0.5));
    });

    test('défensif (AD-10) : anchor corrompu → null, rotation non numérique → '
        '0.0, jamais de throw', () {
      final style = ZGeoShapeStyle.fromMapSafe(<String, Object?>{
        'iconAnchor': 'pas-une-map',
        'iconRotation': 'nan',
        'iconSize': double.nan,
      })!;
      expect(style.iconAnchor, isNull);
      expect(style.iconRotation, 0.0);
      expect(style.iconSize, isNull);
    });

    test('toMap additif : clés omises quand neutres, roundtrip fidèle sinon',
        () {
      expect(const ZGeoShapeStyle().toMap().containsKey('iconSize'), isFalse);
      expect(
          const ZGeoShapeStyle().toMap().containsKey('iconAnchor'), isFalse);
      const style = ZGeoShapeStyle(
        iconSize: 24,
        iconAnchor: ZGeoPoint(lat: 0.5, lng: 1.0),
        iconRotation: 7,
      );
      expect(ZGeoShapeStyle.fromMapSafe(style.toMap()), style);
    });
  });

  group('G9 — style porté par les 3 types (modèle)', () {
    test('ZGeoPoint/ZGeoCircle : style lu (zcrud et legacy), toMap additif '
        '(aucune clé style quand null), ==/copyWith le portent', () {
      const style = ZGeoShapeStyle(strokeColorArgb: 0xFFAABBCC);
      const point = ZGeoPoint(lat: 1, lng: 2, style: style);
      expect(ZGeoPoint.fromMapSafe(point.toMap()), point);
      expect(const ZGeoPoint(lat: 1, lng: 2).toMap().containsKey('style'),
          isFalse);
      expect(point, isNot(const ZGeoPoint(lat: 1, lng: 2)));

      const circle = ZGeoCircle(
        center: ZGeoPoint(lat: 1, lng: 2),
        radiusMeters: 10,
        style: style,
      );
      expect(ZGeoCircle.fromMapSafe(circle.toMap()), circle);
      expect(
        const ZGeoCircle(center: ZGeoPoint(lat: 1, lng: 2), radiusMeters: 10)
            .toMap()
            .containsKey('style'),
        isFalse,
      );
    });

    test('cercle legacy typé (points[0]+radius+style) → ZGeoCircle AVEC style',
        () {
      final circle = ZGeoCircle.fromMapSafe(<String, Object?>{
        'type': 'circle',
        'points': <Object?>[
          <String, Object?>{'lat': 6.13, 'lng': 1.28},
        ],
        'radius': 120.0,
        'style': <String, Object?>{'fillColor': 0x334285F4},
      })!;
      expect(circle.style, isNotNull);
      expect(circle.style!.fillColorArgb, 0x334285F4);
    });
  });

  group('G18 — presets de style legacy (référence auditée, opt-in)', () {
    test('valeurs EXACTES mesurées gs:154-177', () {
      expect(ZGeoShapeStyle.defaultPoint.iconColorArgb, 0xFF4285F4);
      expect(ZGeoShapeStyle.defaultPoint.strokeWidth, 0);
      expect(ZGeoShapeStyle.defaultCircle.fillColorArgb, 0x334285F4);
      expect(ZGeoShapeStyle.defaultCircle.strokeColorArgb, 0xFF4285F4);
      expect(ZGeoShapeStyle.defaultCircle.strokeWidth, 2);
      expect(ZGeoShapeStyle.defaultPolygon.fillColorArgb, 0x334285F4);
      expect(ZGeoShapeStyle.defaultPolygon.strokeColorArgb, 0xFF4285F4);
      expect(ZGeoShapeStyle.defaultPolygon.strokeWidth, 3);
      expect(ZGeoShapeStyle.defaultPolyline.strokeColorArgb, 0xFF4285F4);
      expect(ZGeoShapeStyle.defaultPolyline.fillColorArgb, isNull);
      expect(ZGeoShapeStyle.defaultPolyline.strokeWidth, 3);
    });

    test('FR-26/audit — les ARGB legacy (4285F4) ne vivent QUE dans le '
        'fichier de référence (grep négatif montré)', () {
      final libDir = Directory('packages/zcrud_geo/lib').existsSync()
          ? Directory('packages/zcrud_geo/lib')
          : Directory('lib');
      final offenders = <String>[];
      for (final e in libDir.listSync(recursive: true).whereType<File>()) {
        if (!e.path.endsWith('.dart')) continue;
        if (e.path.endsWith('z_geo_style_reference.dart')) continue;
        // P0D2 : idem — la valeur ARGB legacy est citée en dartdoc par les
        // fichiers qui expliquent l'exemption FR-26 (pas un secret).
        if (stripComments(e.readAsStringSync()).contains('4285F4')) {
          offenders.add(e.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'couleur legacy hors du fichier de référence audité : '
              '$offenders');
    });

    test('opt-in prouvé : une valeur SANS style ne reçoit AUCUN preset '
        'd\'office', () {
      expect(const ZGeoPoint(lat: 1, lng: 2).style, isNull);
      expect(
        const ZGeoCircle(center: ZGeoPoint(lat: 1, lng: 2), radiusMeters: 5)
            .style,
        isNull,
      );
      expect(ZGeoShape().style, isNull);
    });
  });
}
