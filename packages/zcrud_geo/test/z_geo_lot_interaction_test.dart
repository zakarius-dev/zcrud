// Lot « interaction » de la CR geo (cr-geo-field-parity-legacy-2026-08-11) —
// G5 (plein écran), G7 (caméra au port), G10 (« ma position » recentre),
// G11 (cercle 2-taps + poignée de rayon), G13 (drag sommet / déplacement de
// forme). Parité mesurée sur le legacy DODLP (`gff` = geofence_field.dart) :
// validation d'enregistrement `gff:1037-1059`, zoom 16 `gff:255`, haversine
// `gff:113-127` (R = 6371000), aperçu 10 m `gff:589-600`, move handle
// `gff:647-664` + `gff:1603-1642`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';

ZFieldSpec _field(
  String name, {
  ZGeoGeometry? geometry,
  List<ZGeoGeometry>? allowedGeometries,
  bool readOnly = false,
  bool? allowFullscreen,
  ZGeoEditorToolbarConfig? bar,
  EditionFieldType type = EditionFieldType.location,
}) =>
    ZFieldSpec(
      name: name,
      type: type,
      label: 'Zone géo',
      readOnly: readOnly,
      config: ZGeoFieldConfig(
        geometry: geometry,
        allowedGeometries: allowedGeometries,
        toolbarConfig: bar,
        allowFullscreen: allowFullscreen ?? true,
      ),
    );

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

ZWidgetRegistry _registry({
  ZMapAdapterFactory? adapterFactory,
  ZGeoLocationResolver? resolver,
  String kind = 'location',
}) =>
    ZWidgetRegistry()
      ..register(
        kind,
        ZGeoFieldWidget.builder(
          adapterFactory: adapterFactory,
          locationResolver: resolver,
        ),
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

const Key _mapKey = FakeMapAdapter.mapKey;
const Key _fullscreenBtn = Key('z-geo-fullscreen');
const Key _saveBtn = Key('z-geo-fullscreen-save');
const Key _keepBtn = Key('z-geo-fullscreen-keep');
const Key _discardBtn = Key('z-geo-fullscreen-discard');
const Key _moveBtn = Key('z-geo-move');
const Key _myLoc = Key('z-geo-my-location');

void main() {
  // ==========================================================================
  group('G7 — capacités caméra/gestes au port (opt-in, AD-4)', () {
    test('un implémenteur MINIMAL du port pur compile et reste sans capacités',
        () {
      // FakeMapAdapter n'implémente QUE buildMap/dispose : s'il compile, un
      // adaptateur externe existant compile (contrainte n°1 — rien n'a été
      // ajouté au port pur). Et il n'est PAS capacitaire.
      final Object adapter = FakeMapAdapter();
      expect(adapter, isA<ZMapAdapter>());
      expect(adapter, isNot(isA<ZMapCameraCapable>()));
      expect(adapter, isNot(isA<ZMapGesturesCapable>()));
    });

    test('le fake capacitaire expose caméra + gestes', () {
      final Object adapter = FakeCameraGestureMapAdapter();
      expect(adapter, isA<ZMapCameraCapable>());
      expect(adapter, isA<ZMapGesturesCapable>());
    });

    testWidgets(
        'adaptateur NON capacitaire : « ma position » (polygone) = no-op sans '
        'crash (honoré-si-supporté)', (tester) async {
      final c = _controller('geo');
      final fake = FakeMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(
            adapterFactory: () => fake,
            resolver: () async => const ZGeoPoint(lat: 6.1, lng: 1.3),
          ),
        ),
      );
      await tester.tap(find.byKey(_myLoc));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // G10 : aucun sommet ajouté, même sans caméra.
      expect(c.valueOf('geo'), isNull);
    });
  });

  // ==========================================================================
  group('G10 — « ma position » RECENTRE (zoom 16) au lieu d\'ajouter un sommet',
      () {
    testWidgets(
        'polygone : la tranche reste INTACTE et la caméra bouge (zoom 16 — '
        'parité gff:255) — l\'ancien comportement (_appendVertex) est mort',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeCameraGestureMapAdapter();
      const resolved = ZGeoPoint(lat: 6.1319, lng: 1.2228);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(
            adapterFactory: () => fake,
            resolver: () async => resolved,
          ),
        ),
      );
      await tester.tap(find.byKey(_myLoc));
      await tester.pumpAndSettle();
      // AVANT G10 (mesuré zgfw : `_appendVertex(point)`) la tranche aurait
      // porté une forme à 1 sommet. Elle doit rester nulle.
      expect(c.valueOf('geo'), isNull,
          reason: 'ma-position ne doit JAMAIS ajouter un sommet (G10)');
      expect(fake.movedCameras, hasLength(1));
      expect(fake.movedCameras.single.$1, equals(resolved));
      expect(fake.movedCameras.single.$2, equals(16.0));
    });

    testWidgets('point : la valeur est fixée ET la caméra recentre (zoom 16)',
        (tester) async {
      final c = _controller('geo');
      final fake = FakeCameraGestureMapAdapter();
      const resolved = ZGeoPoint(lat: 7, lng: 8);
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point),
          registry: _registry(
            adapterFactory: () => fake,
            resolver: () async => resolved,
          ),
        ),
      );
      await tester.tap(find.byKey(_myLoc));
      await tester.pumpAndSettle();
      expect(c.valueOf('geo'), equals(resolved));
      expect(fake.movedCameras.single.$2, equals(16.0));
    });

    testWidgets('cercle : centre fixé + caméra recentrée', (tester) async {
      final c = _controller('geo');
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle),
          registry: _registry(
            adapterFactory: () => fake,
            resolver: () async => const ZGeoPoint(lat: 3, lng: 4),
          ),
        ),
      );
      await tester.tap(find.byKey(_myLoc));
      await tester.pumpAndSettle();
      // Centre posé dans les champs texte (rayon encore vide → tranche nulle).
      expect(find.text('3.0'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
      expect(fake.movedCameras.single.$2, equals(16.0));
    });
  });

  // ==========================================================================
  group('G11 — distance haversine (parité gff:113-127, R=6371000)', () {
    test('1° de latitude ≈ 111 194,93 m', () {
      const a = ZGeoPoint(lat: 0, lng: 0);
      const b = ZGeoPoint(lat: 1, lng: 0);
      expect(a.distanceMetersTo(b), closeTo(111194.9266, 0.01));
      // Symétrie.
      expect(b.distanceMetersTo(a), closeTo(111194.9266, 0.01));
    });

    test('distance nulle vers soi-même', () {
      const a = ZGeoPoint(lat: 6.1319, lng: 1.2228);
      expect(a.distanceMetersTo(a), equals(0));
    });

    test('longitude à l\'équateur : même échelle que la latitude', () {
      const a = ZGeoPoint(lat: 0, lng: 10);
      const b = ZGeoPoint(lat: 0, lng: 11);
      expect(a.distanceMetersTo(b), closeTo(111194.9266, 0.01));
    });
  });

  group('G11 — cercle « 2 taps » (centre puis rayon) + aperçu 10 m', () {
    testWidgets(
        '1er tap = centre (aperçu 10 m plombé à l\'adaptateur, tranche nulle) ; '
        '2e tap = rayon haversine (tranche = cercle valide)', (tester) async {
      final c = _controller('geo');
      final fake =
          FakeCameraGestureMapAdapter(tapPoint: const ZGeoPoint(lat: 10, lng: 20));
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      // --- 1er tap : centre.
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      expect(c.valueOf('geo'), isNull, reason: 'pas encore de rayon');
      // Aperçu 10 m (parité gff:589-600 `geofence_circle_preview`).
      expect(fake.lastCircle, isNotNull);
      expect(fake.lastCircle!.radiusMeters, equals(10));
      expect(fake.lastCircle!.center, equals(const ZGeoPoint(lat: 10, lng: 20)));
      // --- 2e tap (0.1° plus au nord) : rayon = distance haversine.
      fake.tapOverride = const ZGeoPoint(lat: 10.1, lng: 20);
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      final Object? v = c.valueOf('geo');
      expect(v, isA<ZGeoCircle>());
      final circle = v! as ZGeoCircle;
      expect(circle.center, equals(const ZGeoPoint(lat: 10, lng: 20)));
      final double expected = const ZGeoPoint(lat: 10, lng: 20)
          .distanceMetersTo(const ZGeoPoint(lat: 10.1, lng: 20));
      // Arrondi au décimètre (champ texte lisible).
      expect(circle.radiusMeters, closeTo(expected, 0.06));
      // L'aperçu 10 m a disparu : la carte reçoit le cercle réel.
      expect(fake.lastCircle!.radiusMeters, closeTo(expected, 0.06));
    });

    testWidgets('3e tap : nouveau centre (parité du reset legacy)',
        (tester) async {
      final c = _controller('geo');
      final fake =
          FakeCameraGestureMapAdapter(tapPoint: const ZGeoPoint(lat: 10, lng: 20));
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      await tester.tap(find.byKey(_mapKey)); // centre
      await tester.pump();
      fake.tapOverride = const ZGeoPoint(lat: 10.1, lng: 20);
      await tester.tap(find.byKey(_mapKey)); // rayon
      await tester.pump();
      fake.tapOverride = const ZGeoPoint(lat: 30, lng: 40);
      await tester.tap(find.byKey(_mapKey)); // reset → nouveau centre
      await tester.pump();
      // Le centre a changé ; le rayon précédent est CONSERVÉ dans le champ
      // texte (acquis zcrud : champ rayon éditable) → cercle recomposé.
      final circle = c.valueOf('geo')! as ZGeoCircle;
      expect(circle.center, equals(const ZGeoPoint(lat: 30, lng: 40)));
    });

    testWidgets('le champ texte rayon RESTE rendu en mode cercle (acquis zcrud)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      expect(find.byKey(const Key('z-geo-radius')), findsOneWidget);
    });
  });

  group('G11 — poignée de rayon (honorée-si-supportée)', () {
    testWidgets(
        'cercle valide + adaptateur capacitaire → handler posé ; fin de drag '
        '→ rayon mis à jour (champ texte + tranche)', (tester) async {
      final c = _controller(
        'geo',
        value: const ZGeoCircle(
          center: ZGeoPoint(lat: 5, lng: 5),
          radiusMeters: 100,
        ),
      );
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      expect(fake.onCircleRadiusDragEnd, isNotNull);
      fake.onCircleRadiusDragEnd!(250);
      await tester.pump();
      final circle = c.valueOf('geo')! as ZGeoCircle;
      expect(circle.radiusMeters, equals(250.0));
      expect(find.text('250.0'), findsOneWidget);
    });

    testWidgets('readOnly → aucun handler de gestes posé', (tester) async {
      final c = _controller(
        'geo',
        value: const ZGeoCircle(
          center: ZGeoPoint(lat: 5, lng: 5),
          radiusMeters: 100,
        ),
      );
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle, readOnly: true),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      expect(fake.onCircleRadiusDragEnd, isNull);
      expect(fake.onVertexDragEnd, isNull);
      expect(fake.onShapeDragEnd, isNull);
    });
  });

  // ==========================================================================
  group('G13 — drag de sommet (onVertexDragEnd)', () {
    ZGeoShape shape3() => ZGeoShape(
          vertices: const <ZGeoPoint>[
            ZGeoPoint(lat: 0, lng: 0),
            ZGeoPoint(lat: 1, lng: 1),
            ZGeoPoint(lat: 2, lng: 0),
          ],
        );

    testWidgets('fin de drag → le sommet [index] est remplacé dans la tranche',
        (tester) async {
      final c = _controller('geo', value: shape3());
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      expect(fake.onVertexDragEnd, isNotNull);
      fake.onVertexDragEnd!(1, const ZGeoPoint(lat: 1.5, lng: 1.5));
      await tester.pump();
      final shape = c.valueOf('geo')! as ZGeoShape;
      expect(shape.vertices[1], equals(const ZGeoPoint(lat: 1.5, lng: 1.5)));
      expect(shape.vertices[0], equals(const ZGeoPoint(lat: 0, lng: 0)));
      expect(shape.vertices, hasLength(3));
    });

    testWidgets('index hors-bornes / point invalide → no-op (AD-10)',
        (tester) async {
      final initial = shape3();
      final c = _controller('geo', value: initial);
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      fake.onVertexDragEnd!(99, const ZGeoPoint(lat: 1, lng: 1));
      fake.onVertexDragEnd!(-1, const ZGeoPoint(lat: 1, lng: 1));
      fake.onVertexDragEnd!(0, const ZGeoPoint(lat: 999, lng: 0));
      await tester.pump();
      expect(c.valueOf('geo'), equals(initial));
      expect(tester.takeException(), isNull);
    });
  });

  group('G13 — mode « Déplacer » (marqueur au centroïde)', () {
    ZGeoShape shape3() => ZGeoShape(
          vertices: const <ZGeoPoint>[
            ZGeoPoint(lat: 0, lng: 0),
            ZGeoPoint(lat: 1, lng: 1),
            ZGeoPoint(lat: 2, lng: 0),
          ],
        );

    testWidgets(
        'le toggle n\'apparaît QUE si l\'adaptateur est capacitaire et que la '
        'géométrie collecte des sommets', (tester) async {
      final c = _controller('geo');
      // Adaptateur capacitaire + polygone → présent.
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      expect(find.byKey(_moveBtn), findsOneWidget);
      // Adaptateur NON capacitaire → absent (honoré-si-supporté, parité
      // gff:1439 `if (!isOsm)` : le legacy masquait pareillement).
      final c2 = _controller('geo2');
      await tester.pumpWidget(
        _app(
          c2,
          _field('geo2', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: FakeMapAdapter.new),
        ),
      );
      expect(find.byKey(_moveBtn), findsNothing);
      // Mode point → absent même capacitaire.
      final c3 = _controller('geo3');
      await tester.pumpWidget(
        _app(
          c3,
          _field('geo3', geometry: ZGeoGeometry.point),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      expect(find.byKey(_moveBtn), findsNothing);
    });

    testWidgets(
        'mode Déplacer actif → carte non interactive + tap désarmé + handler '
        'posé ; fin de drag → TOUS les sommets translatés (parité _moveShape)',
        (tester) async {
      final c = _controller('geo', value: shape3());
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      // Avant : interactif, tap armé, pas de handler de déplacement.
      expect(fake.lastInteractive, isTrue);
      expect(fake.sawOnTap, isTrue);
      expect(fake.onShapeDragEnd, isNull);
      await tester.tap(find.byKey(_moveBtn));
      await tester.pump();
      // Parité gff:1673 : la carte devient inerte, seul le handle se manipule.
      expect(fake.lastInteractive, isFalse);
      expect(fake.sawOnTap, isFalse);
      expect(fake.onShapeDragEnd, isNotNull);
      fake.onShapeDragEnd!(0.5, -0.25);
      await tester.pump();
      final shape = c.valueOf('geo')! as ZGeoShape;
      expect(
        shape.vertices,
        equals(const <ZGeoPoint>[
          ZGeoPoint(lat: 0.5, lng: -0.25),
          ZGeoPoint(lat: 1.5, lng: 0.75),
          ZGeoPoint(lat: 2.5, lng: -0.25),
        ]),
      );
      // Sortie du mode → carte interactive à nouveau, handler retiré.
      await tester.tap(find.byKey(_moveBtn));
      await tester.pump();
      expect(fake.lastInteractive, isTrue);
      expect(fake.onShapeDragEnd, isNull);
    });

    testWidgets(
        'translation qui sortirait un sommet des bornes → abandon EN BLOC '
        '(AD-10, jamais de forme partiellement déplacée)', (tester) async {
      final initial = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 89.9, lng: 0),
          ZGeoPoint(lat: 89.8, lng: 1),
          ZGeoPoint(lat: 89.7, lng: 0),
        ],
      );
      final c = _controller('geo', value: initial);
      final fake = FakeCameraGestureMapAdapter();
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: () => fake),
        ),
      );
      await tester.tap(find.byKey(_moveBtn));
      await tester.pump();
      fake.onShapeDragEnd!(0.5, 0); // 89.9 + 0.5 = 90.4 → hors-bornes
      await tester.pump();
      expect(c.valueOf('geo'), equals(initial));
    });
  });

  // ==========================================================================
  group('G5 — bouton plein écran (en-tête)', () {
    testWidgets('rendu par défaut quand une carte existe (parité legacy)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      expect(find.byKey(_fullscreenBtn), findsOneWidget);
      // A11y (AD-13) : cible ≥ 48 dp portée par la contrainte du bouton.
      final ConstrainedBox box = tester.widget<ConstrainedBox>(
        find.byKey(_fullscreenBtn),
      );
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48));
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48));
    });

    testWidgets('allowFullscreen: false → aucun bouton', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point, allowFullscreen: false),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      expect(find.byKey(_fullscreenBtn), findsNothing);
    });

    testWidgets('sans adaptateur carte → aucun bouton (repli coordonnées-seules)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', geometry: ZGeoGeometry.point),
            registry: _registry()),
      );
      expect(find.byKey(_fullscreenBtn), findsNothing);
    });
  });

  group('G5 — route immersive : brouillon, validation, enregistrement', () {
    testWidgets(
        'éditer en plein écran n\'écrit PAS la tranche ; « Enregistrer » '
        '(point valide) la commet en une fois', (tester) async {
      final c = _controller('geo');
      final fakes = <FakeCameraGestureMapAdapter>[];
      FakeCameraGestureMapAdapter makeFake() {
        final f = FakeCameraGestureMapAdapter(
          tapPoint: const ZGeoPoint(lat: 12.5, lng: 34.5),
        );
        fakes.add(f);
        return f;
      }

      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point),
          registry: _registry(adapterFactory: makeFake),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      // La route immersive est ouverte : AppBar + « Enregistrer ».
      expect(find.byKey(_saveBtn), findsOneWidget);
      // MAJEUR-1 : l'éditeur immersif possède SA PROPRE instance d'adaptateur.
      expect(fakes, hasLength(2));
      // Tap carte DANS le plein écran → brouillon seulement.
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      expect(c.valueOf('geo'), isNull,
          reason: 'le plein écran n\'écrit la tranche qu\'à Enregistrer');
      // Enregistrer → pop + écriture unique de la tranche.
      await tester.tap(find.byKey(_saveBtn));
      await tester.pumpAndSettle();
      expect(find.byKey(_saveBtn), findsNothing);
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 12.5, lng: 34.5)));
    });

    testWidgets(
        'polygone < 3 sommets → SnackBar (parité gff:1049-1052), route '
        'OUVERTE, tranche intacte', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      // 2 sommets seulement (2 taps au même point fake = 2 sommets).
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      await tester.tap(find.byKey(_saveBtn));
      await tester.pump();
      expect(
        find.text('Le polygone doit avoir au moins 3 points.'),
        findsOneWidget,
      );
      expect(find.byKey(_saveBtn), findsOneWidget, reason: 'la route reste');
      expect(c.valueOf('geo'), isNull);
    });

    testWidgets('brouillon vide (polygone) → message « aucune donnée »',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.polygon),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_saveBtn));
      await tester.pump();
      expect(
        find.text('Aucune donnée géographique à enregistrer.'),
        findsOneWidget,
      );
    });

    testWidgets('cercle sans rayon (centre posé) → message rayon (parité)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.circle),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_mapKey)); // 1er tap : centre seul
      await tester.pump();
      await tester.tap(find.byKey(_saveBtn));
      await tester.pump();
      expect(
        find.text('Veuillez définir un rayon pour le cercle.'),
        findsOneWidget,
      );
    });

    testWidgets('readOnly → plein écran consultable SANS « Enregistrer »',
        (tester) async {
      final c = _controller('geo',
          value: const ZGeoPoint(lat: 1, lng: 2));
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point, readOnly: true),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      expect(find.byKey(_fullscreenBtn), findsOneWidget);
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      expect(find.byKey(_saveBtn), findsNothing);
      // Et pas de second bouton plein écran DANS la route (mode immersif).
      expect(find.byKey(_fullscreenBtn), findsNothing);
    });
  });

  group('G5 — fermeture sans enregistrer', () {
    testWidgets('brouillon intact → fermeture directe, tranche inchangée',
        (tester) async {
      final c = _controller('geo', value: const ZGeoPoint(lat: 1, lng: 2));
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_saveBtn), findsNothing);
      expect(c.valueOf('geo'), equals(const ZGeoPoint(lat: 1, lng: 2)));
    });

    testWidgets(
        'brouillon MODIFIÉ → confirmation (jamais de perte silencieuse) ; '
        '« Continuer » garde la route, « Abandonner » jette le brouillon',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', geometry: ZGeoGeometry.point),
          registry: _registry(adapterFactory: FakeCameraGestureMapAdapter.new),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_mapKey)); // modifie le brouillon
      await tester.pump();
      // Fermer → dialogue de confirmation.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byKey(_discardBtn), findsOneWidget);
      // « Continuer l'édition » → la route reste.
      await tester.tap(find.byKey(_keepBtn));
      await tester.pumpAndSettle();
      expect(find.byKey(_saveBtn), findsOneWidget);
      // Re-fermer puis « Abandonner » → route fermée, tranche INTACTE.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_discardBtn));
      await tester.pumpAndSettle();
      expect(find.byKey(_saveBtn), findsNothing);
      expect(c.valueOf('geo'), isNull,
          reason: 'fermer sans enregistrer ne commet jamais le brouillon');
    });
  });

  group('G5 — adoption de la géométrie du plein écran (G2 croisé)', () {
    testWidgets(
        'changer de mode EN plein écran puis enregistrer → le champ encarté '
        'adopte la géométrie et la valeur', (tester) async {
      final c = _controller('geo');
      final fakes = <FakeCameraGestureMapAdapter>[];
      FakeCameraGestureMapAdapter makeFake() {
        final f = FakeCameraGestureMapAdapter();
        fakes.add(f);
        return f;
      }

      await tester.pumpWidget(
        _app(
          c,
          _field(
            'geo',
            allowedGeometries: const <ZGeoGeometry>[
              ZGeoGeometry.point,
              ZGeoGeometry.polygon,
            ],
          ),
          registry: _registry(adapterFactory: makeFake),
        ),
      );
      await tester.tap(find.byKey(_fullscreenBtn));
      await tester.pumpAndSettle();
      // Bascule en polygone DANS la route immersive (sélecteur G2).
      await tester.tap(find.byKey(const Key('z-geo-mode-polygon')).last);
      await tester.pump();
      // 3 sommets distincts.
      final inner = fakes.last;
      inner.tapOverride = const ZGeoPoint(lat: 0, lng: 0);
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      inner.tapOverride = const ZGeoPoint(lat: 1, lng: 1);
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      inner.tapOverride = const ZGeoPoint(lat: 2, lng: 0);
      await tester.tap(find.byKey(_mapKey));
      await tester.pump();
      await tester.tap(find.byKey(_saveBtn));
      await tester.pumpAndSettle();
      final Object? v = c.valueOf('geo');
      expect(v, isA<ZGeoShape>());
      expect((v! as ZGeoShape).vertices, hasLength(3));
      // Le champ encarté rend désormais l'UI polygone (bouton ajouter-sommet).
      expect(find.byKey(const Key('z-geo-add-vertex')), findsOneWidget);
    });
  });
}
