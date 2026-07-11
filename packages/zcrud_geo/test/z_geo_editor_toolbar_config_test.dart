// DP-7 (AC1/AC2) — `ZGeoEditorToolbarConfig` : parité DODLP (18 toggles +
// disabled + mapOptionsLabel), défauts, presets flag-par-flag, copyWith, ==/hash.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('AC1 — défauts identiques à DODLP GeoEditorToolbarConfig', () {
    test('valeurs par défaut', () {
      const c = ZGeoEditorToolbarConfig();
      // Disable
      expect(c.disabled, isFalse);
      // Drawing Tools — true × 5
      expect(c.showModeSelector, isTrue);
      expect(c.showMyLocationButton, isTrue);
      expect(c.showUndoButton, isTrue);
      expect(c.showClearButton, isTrue);
      expect(c.showOptimizeButton, isTrue);
      // Map Type — true, false
      expect(c.showMapTypeToggle, isTrue);
      expect(c.showExtendedMapTypes, isFalse);
      // Map Features — false × 3
      expect(c.showTrafficToggle, isFalse);
      expect(c.showBuildingsToggle, isFalse);
      expect(c.showIndoorViewToggle, isFalse);
      // Gesture Controls — false × 2
      expect(c.showRotationToggle, isFalse);
      expect(c.showTiltToggle, isFalse);
      // Advanced — false × 3
      expect(c.showZoomControlsToggle, isFalse);
      expect(c.showCompassToggle, isFalse);
      expect(c.showMapToolbarToggle, isFalse);
      // Layout — false, 'Options', true, false
      expect(c.useMapOptionsDropdown, isFalse);
      expect(c.mapOptionsLabel, 'Options');
      expect(c.showButtonLabels, isTrue);
      expect(c.compactMode, isFalse);
    });
  });

  group('AC2 — 5 presets, flags exacts (parité DODLP 1:1)', () {
    test('none : disabled, tout masqué, compactMode', () {
      const c = ZGeoEditorToolbarConfig.none;
      expect(c.disabled, isTrue);
      expect(c.compactMode, isTrue);
      for (final flag in <bool>[
        c.showModeSelector,
        c.showMyLocationButton,
        c.showUndoButton,
        c.showClearButton,
        c.showOptimizeButton,
        c.showMapTypeToggle,
        c.showExtendedMapTypes,
        c.showTrafficToggle,
        c.showBuildingsToggle,
        c.showIndoorViewToggle,
        c.showRotationToggle,
        c.showTiltToggle,
        c.showZoomControlsToggle,
        c.showCompassToggle,
        c.showMapToolbarToggle,
        c.useMapOptionsDropdown,
        c.showButtonLabels,
      ]) {
        expect(flag, isFalse);
      }
    });

    test('minimal : picking simple', () {
      const c = ZGeoEditorToolbarConfig.minimal;
      expect(c.disabled, isFalse);
      expect(c.showModeSelector, isFalse);
      expect(c.showMyLocationButton, isTrue);
      expect(c.showUndoButton, isTrue);
      expect(c.showClearButton, isTrue);
      expect(c.showOptimizeButton, isFalse);
      expect(c.showMapTypeToggle, isTrue);
      expect(c.showExtendedMapTypes, isFalse);
      expect(c.showButtonLabels, isFalse);
      expect(c.compactMode, isTrue);
    });

    test('standard : défaut équilibré', () {
      const c = ZGeoEditorToolbarConfig.standard;
      expect(c.showModeSelector, isTrue);
      expect(c.showMyLocationButton, isTrue);
      expect(c.showUndoButton, isTrue);
      expect(c.showClearButton, isTrue);
      expect(c.showOptimizeButton, isTrue);
      expect(c.showMapTypeToggle, isTrue);
      expect(c.showExtendedMapTypes, isFalse);
      expect(c.showTrafficToggle, isFalse);
      expect(c.showBuildingsToggle, isFalse);
      expect(c.showIndoorViewToggle, isFalse);
      expect(c.showRotationToggle, isFalse);
      expect(c.showTiltToggle, isFalse);
      expect(c.showZoomControlsToggle, isFalse);
      expect(c.showCompassToggle, isFalse);
      expect(c.showMapToolbarToggle, isFalse);
      expect(c.useMapOptionsDropdown, isFalse);
      expect(c.showButtonLabels, isTrue);
      expect(c.compactMode, isFalse);
    });

    test('full : tous les toggles à true SAUF compactMode (parité DODLP)', () {
      const c = ZGeoEditorToolbarConfig.full;
      expect(c.showModeSelector, isTrue);
      expect(c.showMyLocationButton, isTrue);
      expect(c.showUndoButton, isTrue);
      expect(c.showClearButton, isTrue);
      expect(c.showOptimizeButton, isTrue);
      expect(c.showMapTypeToggle, isTrue);
      expect(c.showExtendedMapTypes, isTrue);
      expect(c.showTrafficToggle, isTrue);
      expect(c.showBuildingsToggle, isTrue);
      expect(c.showIndoorViewToggle, isTrue);
      expect(c.showRotationToggle, isTrue);
      expect(c.showTiltToggle, isTrue);
      expect(c.showZoomControlsToggle, isTrue);
      expect(c.showCompassToggle, isTrue);
      expect(c.showMapToolbarToggle, isTrue);
      expect(c.useMapOptionsDropdown, isTrue);
      expect(c.showButtonLabels, isTrue);
      // Parité DODLP : full garde compactMode == false.
      expect(c.compactMode, isFalse);
      expect(c.disabled, isFalse);
    });

    test('professional : full sauf indoor/zoom/compass/mapToolbar', () {
      const c = ZGeoEditorToolbarConfig.professional;
      const full = ZGeoEditorToolbarConfig.full;
      // Identique à full pour tout SAUF les 4 désactivés.
      expect(c.showIndoorViewToggle, isFalse);
      expect(c.showZoomControlsToggle, isFalse);
      expect(c.showCompassToggle, isFalse);
      expect(c.showMapToolbarToggle, isFalse);
      // Le reste = full.
      expect(
        c.copyWith(
          showIndoorViewToggle: true,
          showZoomControlsToggle: true,
          showCompassToggle: true,
          showMapToolbarToggle: true,
        ),
        equals(full),
      );
    });
  });

  group('AC1 — copyWith / == / hashCode', () {
    test('copyWith couvre tous les champs', () {
      const base = ZGeoEditorToolbarConfig();
      final modified = base.copyWith(
        disabled: true,
        showModeSelector: false,
        showMyLocationButton: false,
        showUndoButton: false,
        showClearButton: false,
        showOptimizeButton: false,
        showMapTypeToggle: false,
        showExtendedMapTypes: true,
        showTrafficToggle: true,
        showBuildingsToggle: true,
        showIndoorViewToggle: true,
        showRotationToggle: true,
        showTiltToggle: true,
        showZoomControlsToggle: true,
        showCompassToggle: true,
        showMapToolbarToggle: true,
        useMapOptionsDropdown: true,
        mapOptionsLabel: 'Custom',
        showButtonLabels: false,
        compactMode: true,
      );
      expect(modified.disabled, isTrue);
      expect(modified.showExtendedMapTypes, isTrue);
      expect(modified.mapOptionsLabel, 'Custom');
      expect(modified.showButtonLabels, isFalse);
      expect(modified.compactMode, isTrue);
      // Sans argument → identique.
      expect(base.copyWith(), equals(base));
    });

    test('== et hashCode sur tous les champs', () {
      const a = ZGeoEditorToolbarConfig();
      const b = ZGeoEditorToolbarConfig();
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      final c = a.copyWith(mapOptionsLabel: 'X');
      expect(a, isNot(equals(c)));
      final d = a.copyWith(showTrafficToggle: true);
      expect(a, isNot(equals(d)));
      expect(a.hashCode, isNot(equals(d.hashCode)));
    });
  });
}
