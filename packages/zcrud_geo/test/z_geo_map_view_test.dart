// G6 — `ZGeoMapView` : vue de lecture multi-formes (parité `GeofenceView`
// legacy gfv:16-188, mesures : labels via style.infoWindowTitle gfv:111-114,
// sélection par TAP MARQUEUR gfv:132-139, centre = moyenne arithmétique
// gfv:52-76, zoom initial 14 gfv:31, toggle normal↔hybrid gfv:141-147).
// Rendu via le port existant (paramètre additif `overlays`) — aucun moteur
// nouveau ; preuve par FakeMapAdapter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';

const ZGeoPoint _p1 = ZGeoPoint(lat: 6.0, lng: 1.0);
const ZGeoCircle _c1 =
    ZGeoCircle(center: ZGeoPoint(lat: 8.0, lng: 3.0), radiusMeters: 100);
final ZGeoShape _s1 = ZGeoShape(vertices: const <ZGeoPoint>[
  ZGeoPoint(lat: 10, lng: 5),
  ZGeoPoint(lat: 10, lng: 7),
  ZGeoPoint(lat: 12, lng: 7),
]);

Future<void> _pump(
  WidgetTester tester,
  FakeMapAdapter adapter, {
  required List<ZGeoMapViewEntry> entries,
  ZGeoMapViewLabelBuilder? labelBuilder,
  ValueChanged<ZGeoMapViewEntry>? onShapeSelected,
  bool showMapTypeToggle = true,
  bool autoFitBounds = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: ZGeoMapView(
            entries: entries,
            adapterFactory: () => adapter,
            labelBuilder: labelBuilder,
            onShapeSelected: onShapeSelected,
            showMapTypeToggle: showMapTypeToggle,
            autoFitBounds: autoFitBounds,
          ),
        ),
      ),
    ),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  group('G6 — rendu multi-formes via le port (AUCUN moteur nouveau)', () {
    testWidgets('N entrées → N overlays neutres transmis à buildMap',
        (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter, entries: <ZGeoMapViewEntry>[
        const ZGeoMapViewEntry(value: _p1),
        const ZGeoMapViewEntry(value: _c1, id: 'circle-A'),
        ZGeoMapViewEntry(value: _s1, renderAsPolyline: true),
      ]);
      final List<ZGeoMapOverlay> overlays = adapter.lastOverlays!;
      expect(overlays, hasLength(3));
      expect(overlays[0].id, 'entry-0'); // id par défaut = index
      expect(overlays[1].id, 'circle-A'); // id explicite respecté
      expect(overlays[2].renderAsPolyline, isTrue);
      expect(overlays[0].value, isA<ZGeoPoint>());
      expect(overlays[1].value, isA<ZGeoCircle>());
      expect(overlays[2].value, isA<ZGeoShape>());
    });

    testWidgets(
        'centre initial = MOYENNE ARITHMÉTIQUE de tous les points (parité '
        'stricte gfv:52-76) + zoom initial 14 (gfv:31)', (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter, entries: const <ZGeoMapViewEntry>[
        ZGeoMapViewEntry(value: ZGeoPoint(lat: 0, lng: 0)),
        ZGeoMapViewEntry(value: ZGeoPoint(lat: 4, lng: 2)),
      ]);
      expect(adapter.lastCenter, const ZGeoPoint(lat: 2, lng: 1));
      expect(adapter.lastDefaultZoom, 14);
    });

    testWidgets('aucune fabrique → espace vide, jamais de crash (AD-10)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ZGeoMapView(entries: <ZGeoMapViewEntry>[]),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(FakeMapAdapter.mapKey), findsNothing);
    });

    testWidgets('la vue POSSÈDE son adaptateur : dispose au démontage '
        '(MAJEUR-1)', (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter, entries: const <ZGeoMapViewEntry>[]);
      expect(adapter.disposed, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(adapter.disposed, isTrue);
    });
  });

  group('G6 — labels (canal legacy style.infoWindowTitle, gfv:111-114)', () {
    testWidgets('labelBuilder → repris en infoWindowTitle de l\'overlay',
        (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(
        tester,
        adapter,
        entries: const <ZGeoMapViewEntry>[ZGeoMapViewEntry(value: _p1)],
        labelBuilder: (ZGeoMapViewEntry e) => 'Poste 4',
      );
      final Object value = adapter.lastOverlays!.single.value;
      expect((value as ZGeoPoint).style?.infoWindowTitle, 'Poste 4');
    });

    testWidgets(
        'un infoWindowTitle DÉJÀ porté par la valeur PRIME (on ne fabrique '
        'pas une donnée par-dessus la source)', (tester) async {
      final adapter = FakeMapAdapter();
      const ZGeoPoint titled = ZGeoPoint(
        lat: 6,
        lng: 1,
        style: ZGeoShapeStyle(infoWindowTitle: 'Origine'),
      );
      await _pump(
        tester,
        adapter,
        entries: const <ZGeoMapViewEntry>[ZGeoMapViewEntry(value: titled)],
        labelBuilder: (ZGeoMapViewEntry e) => 'Écraseur',
      );
      final Object value = adapter.lastOverlays!.single.value;
      expect((value as ZGeoPoint).style?.infoWindowTitle, 'Origine');
    });
  });

  group('G6 — sélection par tap marqueur (parité mesurée gfv:132-139)', () {
    testWidgets('tap d\'ancrage → onShapeSelected(entrée d\'origine)',
        (tester) async {
      final adapter = FakeMapAdapter();
      ZGeoMapViewEntry? selected;
      const ZGeoMapViewEntry entry =
          ZGeoMapViewEntry(value: _c1, id: 'circle-A');
      await _pump(
        tester,
        adapter,
        entries: const <ZGeoMapViewEntry>[entry],
        onShapeSelected: (ZGeoMapViewEntry e) => selected = e,
      );
      expect(adapter.lastOnOverlayMarkerTap, isNotNull);
      adapter.lastOnOverlayMarkerTap!('circle-A');
      expect(selected, same(entry));
      // Id inconnu → no-op silencieux (AD-10).
      adapter.lastOnOverlayMarkerTap!('fantôme');
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans onShapeSelected → aucun callback posé (rendu inchangé)',
        (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter,
          entries: const <ZGeoMapViewEntry>[ZGeoMapViewEntry(value: _p1)]);
      expect(adapter.lastOnOverlayMarkerTap, isNull);
    });
  });

  group('G6 — toggle de type de carte (parité gfv:141-147) + fit bounds', () {
    testWidgets('bouton ≥48dp, bascule normal → hybrid transmise au port',
        (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter,
          entries: const <ZGeoMapViewEntry>[ZGeoMapViewEntry(value: _p1)]);
      expect(adapter.lastMapOptions?.mapType, ZGeoMapType.normal);
      final Finder toggle = find.byKey(const Key('z-geo-map-view-type-toggle'));
      expect(toggle, findsOneWidget);
      // AD-13 : cible ≥ 48dp — contrainte POSÉE (jamais tester.getSize).
      final ConstrainedBox box = tester.widget<ConstrainedBox>(toggle);
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48));
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48));
      await tester.tap(toggle);
      await tester.pump();
      expect(adapter.lastMapOptions?.mapType, ZGeoMapType.hybrid);
    });

    testWidgets('showMapTypeToggle: false → aucun bouton', (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter,
          entries: const <ZGeoMapViewEntry>[ZGeoMapViewEntry(value: _p1)],
          showMapTypeToggle: false);
      expect(
          find.byKey(const Key('z-geo-map-view-type-toggle')), findsNothing);
    });

    testWidgets(
        'adaptateur CAMÉRA-capable → fitBounds sur la boîte globale (le '
        'cercle étend la sienne de son rayon)', (tester) async {
      final adapter = FakeCameraGestureMapAdapter();
      await _pump(tester, adapter, entries: const <ZGeoMapViewEntry>[
        ZGeoMapViewEntry(value: ZGeoPoint(lat: 0, lng: 0)),
        ZGeoMapViewEntry(value: ZGeoPoint(lat: 4, lng: 2)),
      ]);
      await tester.pump(); // post-frame
      final (ZGeoPoint sw, ZGeoPoint ne) = adapter.lastFitBounds!;
      expect(sw, const ZGeoPoint(lat: 0, lng: 0));
      expect(ne, const ZGeoPoint(lat: 4, lng: 2));
    });

    testWidgets('adaptateur SANS capacité caméra → aucun crash (AD-10)',
        (tester) async {
      final adapter = FakeMapAdapter();
      await _pump(tester, adapter,
          entries: const <ZGeoMapViewEntry>[ZGeoMapViewEntry(value: _p1)]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
