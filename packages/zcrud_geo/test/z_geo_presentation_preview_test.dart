// CR `geo-inline-preview` (2026-08-11), point A — `ZGeoPresentation` :
// aperçu inerte en flux (`previewWithFullscreen`) / éditeur complet en plein
// écran ; défaut `inlineEditor` = comportement v0.82.0 STRICT.
//
// Parité legacy mesurée : `gff:1525` (undo/clear rendus seulement
// `if (isFullscreen)`) ; `gff:1668,1683` (`onMapTap: isFullscreen &&
// !_isStylingMode ? _onMapTapped : (_) {}` — tap désarmé hors plein écran,
// `isInteractive` conservé : le pan/zoom n'est PAS gelé).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'support/fake_map_adapter.dart';

const ZGeoFieldConfig _previewCfg = ZGeoFieldConfig(
  presentation: ZGeoPresentation.previewWithFullscreen,
);

ZFieldSpec _field(
  String name, {
  EditionFieldType type = EditionFieldType.location,
  ZGeoFieldConfig? config,
  bool readOnly = false,
}) =>
    ZFieldSpec(
      name: name,
      type: type,
      label: 'Zone géo',
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
  ZMapAdapter? adapter,
}) =>
    MaterialApp(
      home: ZcrudScope(
        widgetRegistry: ZWidgetRegistry()
          ..register(
            field.type.name,
            ZGeoFieldWidget.builder(
              adapterFactory: adapter == null ? null : () => adapter,
            ),
          ),
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[field],
          ),
        ),
      ),
    );

ZGeoShape get _triangle => ZGeoShape(vertices: <ZGeoPoint>[
      ZGeoPoint(lat: 1, lng: 1),
      ZGeoPoint(lat: 2, lng: 2),
      ZGeoPoint(lat: 3, lng: 1),
    ]);

void main() {
  group('ZGeoPresentation — config (AD-4 : défaut inchangé)', () {
    test('défaut = inlineEditor (aucun hôte existant ne bouge)', () {
      expect(
        const ZGeoFieldConfig().presentation,
        ZGeoPresentation.inlineEditor,
      );
    });

    test('copyWith propage presentation ET la conserve sans argument', () {
      final ZGeoFieldConfig preview =
          const ZGeoFieldConfig().copyWith(
        presentation: ZGeoPresentation.previewWithFullscreen,
      );
      expect(preview.presentation, ZGeoPresentation.previewWithFullscreen);
      expect(
        preview.copyWith(mapHeight: 250).presentation,
        ZGeoPresentation.previewWithFullscreen,
      );
    });

    test('== et hashCode discriminent sur presentation', () {
      const ZGeoFieldConfig a = ZGeoFieldConfig();
      const ZGeoFieldConfig b = _previewCfg;
      expect(a, isNot(equals(b)));
      expect(a.hashCode, isNot(equals(b.hashCode)));
      expect(b, equals(_previewCfg.copyWith()));
    });
  });

  group('previewWithFullscreen — aperçu inerte en flux', () {
    testWidgets(
        'AUCUN bloc d\'édition en flux : ni lat/lng, ni sommets, ni toolbar, '
        'ni picker, ni métriques (même demandés par la config)', (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('g', value: _triangle);
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field(
          'g',
          type: EditionFieldType.geoArea,
          config: const ZGeoFieldConfig(
            presentation: ZGeoPresentation.previewWithFullscreen,
            showStylePicker: true,
            showMetrics: true,
          ),
        ),
        adapter: adapter,
      ));
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('z-geo-add-vertex')), findsNothing);
      expect(find.byKey(const Key('z-geo-toolbar')), findsNothing);
      expect(find.byKey(const Key('z-geo-style-picker')), findsNothing);
      expect(find.byKey(const Key('z-geo-metrics')), findsNothing);
      // La carte, elle, est rendue.
      expect(find.byKey(FakeMapAdapter.mapKey), findsOneWidget);
    });

    testWidgets(
        'la carte reste MANIPULABLE (interactive: true — pan/zoom) mais le '
        'TAP d\'ajout est désarmé (parité gff:1668,1683)', (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('g', value: _triangle);
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field('g', type: EditionFieldType.geoArea, config: _previewCfg),
        adapter: adapter,
      ));
      expect(adapter.lastInteractive, isTrue,
          reason: 'un aperçu gelé (interactive:false) serait un contresens');
      expect(adapter.sawOnTap, isFalse,
          reason: 'le tap d\'ajout doit être désarmé (onTap: null)');
      // Un tap réel ne change RIEN à la tranche.
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect(c.valueOf('g'), _triangle);
    });

    testWidgets('les DRAGS d\'édition sont désarmés (handlers null)',
        (tester) async {
      final adapter = FakeCameraGestureMapAdapter();
      final c = _controller('g', value: _triangle);
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field('g', type: EditionFieldType.geoArea, config: _previewCfg),
        adapter: adapter,
      ));
      expect(adapter.onVertexDragEnd, isNull);
      expect(adapter.onShapeDragEnd, isNull);
      expect(adapter.onCircleRadiusDragEnd, isNull);
    });

    testWidgets('pied « N points » LOCALISÉ rendu (sans chrome, éditable)',
        (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('g', value: _triangle);
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field('g', type: EditionFieldType.geoArea, config: _previewCfg),
        adapter: adapter,
      ));
      expect(find.byKey(const Key('z-geo-footer')), findsOneWidget);
      expect(find.textContaining('3 '), findsOneWidget);
    });

    testWidgets('chrome G19 conservé en aperçu quand showChrome: true',
        (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('g', value: _triangle);
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field(
          'g',
          type: EditionFieldType.geoArea,
          config: const ZGeoFieldConfig(
            presentation: ZGeoPresentation.previewWithFullscreen,
            showChrome: true,
          ),
        ),
        adapter: adapter,
      ));
      expect(find.byKey(const Key('z-geo-chrome')), findsOneWidget);
      expect(find.byKey(const Key('z-geo-chrome-header')), findsOneWidget);
      expect(find.byKey(const Key('z-geo-footer')), findsOneWidget);
      expect(find.byKey(const Key('z-geo-toolbar')), findsNothing);
    });

    testWidgets(
        'icône plein écran RENDUE si éditable, MASQUÉE en readOnly '
        '(aperçu conservé, sans porte d\'entrée)', (tester) async {
      final c1 = _controller('g', value: _triangle);
      addTearDown(c1.dispose);
      await tester.pumpWidget(_app(
        c1,
        _field('g', type: EditionFieldType.geoArea, config: _previewCfg),
        adapter: FakeMapAdapter(),
      ));
      expect(find.byKey(const Key('z-geo-fullscreen')), findsOneWidget);

      final c2 = _controller('g', value: _triangle);
      addTearDown(c2.dispose);
      await tester.pumpWidget(_app(
        c2,
        _field(
          'g',
          type: EditionFieldType.geoArea,
          config: _previewCfg,
          readOnly: true,
        ),
        adapter: FakeMapAdapter(),
      ));
      await tester.pump();
      expect(find.byKey(const Key('z-geo-fullscreen')), findsNothing);
      // L'aperçu RESTE : carte + pied toujours rendus.
      expect(find.byKey(FakeMapAdapter.mapKey), findsOneWidget);
      expect(find.byKey(const Key('z-geo-footer')), findsOneWidget);
    });

    testWidgets(
        'NON-RÉGRESSION : en inlineEditor (défaut), l\'icône plein écran '
        'reste visible en readOnly (consultation immersive, v0.82.0)',
        (tester) async {
      final c = _controller('g', value: _triangle);
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field('g', type: EditionFieldType.geoArea, readOnly: true),
        adapter: FakeMapAdapter(),
      ));
      expect(find.byKey(const Key('z-geo-fullscreen')), findsOneWidget);
    });
  });

  group('previewWithFullscreen — la route immersive N\'HÉRITE PAS de '
      'la restriction d\'aperçu (cœur de la CR)', () {
    testWidgets(
        'en plein écran : toolbar + saisie + tap ARMÉS malgré la config '
        'preview ; « Enregistrer » écrit la tranche', (tester) async {
      final adapter = FakeMapAdapter(
        tapPoint: const ZGeoPoint(lat: 10, lng: 20),
      );
      final c = _controller('g');
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field('g', config: _previewCfg), // location → point
        adapter: adapter,
      ));
      // En flux : rien d'éditable, tap désarmé.
      expect(find.byType(TextField), findsNothing);
      expect(adapter.sawOnTap, isFalse);

      await tester.tap(find.byKey(const Key('z-geo-fullscreen')));
      await tester.pumpAndSettle();

      // Plein écran : TOUTES les capacités (même spec, même config).
      expect(find.byKey(const Key('z-geo-toolbar')), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // lat + lng
      expect(adapter.sawOnTap, isTrue,
          reason: 'le tap d\'ajout doit être ARMÉ en plein écran');
      expect(adapter.lastInteractive, isTrue);

      // Tap → point posé sur le BROUILLON (tranche intacte), puis Enregistrer.
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect(c.valueOf('g'), isNull,
          reason: 'brouillon G5 : la tranche n\'est écrite qu\'au retour');
      await tester.tap(find.byKey(const Key('z-geo-fullscreen-save')));
      await tester.pumpAndSettle();
      expect(c.valueOf('g'), const ZGeoPoint(lat: 10, lng: 20));
    });

    testWidgets(
        'G5 gardé : fermeture avec brouillon modifié → confirmation '
        'd\'abandon (inchangée en mode preview)', (tester) async {
      final adapter = FakeMapAdapter();
      final c = _controller('g');
      addTearDown(c.dispose);
      await tester.pumpWidget(_app(
        c,
        _field('g', config: _previewCfg),
        adapter: adapter,
      ));
      await tester.tap(find.byKey(const Key('z-geo-fullscreen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FakeMapAdapter.mapKey)); // brouillon modifié
      await tester.pump();
      await tester.tap(find.byType(CloseButton).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('z-geo-fullscreen-discard')), findsOneWidget);
      await tester.tap(find.byKey(const Key('z-geo-fullscreen-keep')));
      await tester.pumpAndSettle();
      // Toujours en plein écran, saisie intacte.
      expect(find.byKey(const Key('z-geo-fullscreen-save')), findsOneWidget);
      expect(c.valueOf('g'), isNull);
    });
  });
}
