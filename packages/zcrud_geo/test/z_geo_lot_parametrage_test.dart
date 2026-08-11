// CR geo — lot « paramétrage » (G2 multi-géométries, G4 fournisseur par champ,
// G15 défaut de barre d'outils). Références legacy mesurées : `gff:46-50`
// (allowedModes), `gff:205-216` (_setDrawingMode efface les sommets),
// `gff:272` (la valeur initiale dicte le mode), `gff:1204-1213` (sélecteur en
// barre), `gfc:25` (mapsProvider par champ), `es:2337` (défaut standard).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
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
      label: 'Geo',
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

ZWidgetRegistry _registry({
  FakeMapAdapter? adapter,
  Map<String, ZMapAdapterFactory>? adapterFactories,
  String kind = 'location',
}) =>
    ZWidgetRegistry()
      ..register(
        kind,
        ZGeoFieldWidget.builder(
          adapterFactory: adapter == null ? null : () => adapter,
          adapterFactories: adapterFactories,
        ),
      );

const Key _modePoint = Key('z-geo-mode-point');
const Key _modeCircle = Key('z-geo-mode-circle');
const Key _modePolygon = Key('z-geo-mode-polygon');
const Key _radius = Key('z-geo-radius');
const Key _addVertex = Key('z-geo-add-vertex');

const ZGeoFieldConfig _multiConfig = ZGeoFieldConfig(
  allowedGeometries: <ZGeoGeometry>[
    ZGeoGeometry.point,
    ZGeoGeometry.polygon,
    ZGeoGeometry.circle,
  ],
);

void main() {
  group('G2 — sélecteur de mode multi-géométries', () {
    testWidgets(
        'allowedGeometries (≥2) + barre standard (défaut G15) → un bouton '
        'de mode par géométrie autorisée (parité gff:1204-1213)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', config: _multiConfig), registry: _registry()),
      );
      expect(find.byKey(_modePoint), findsOneWidget);
      expect(find.byKey(_modePolygon), findsOneWidget);
      expect(find.byKey(_modeCircle), findsOneWidget);
      // Aucun bouton pour une géométrie NON autorisée.
      expect(find.byKey(const Key('z-geo-mode-polyline')), findsNothing);
    });

    testWidgets('sans allowedGeometries → AUCUN sélecteur (mono-géométrie '
        'strictement inchangée)', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(_app(c, _field('geo'), registry: _registry()));
      expect(find.byKey(_modePoint), findsNothing);
      expect(find.byKey(_modeCircle), findsNothing);
      expect(find.byKey(_modePolygon), findsNothing);
    });

    testWidgets('showModeSelector: false → sélecteur masqué même en '
        'multi-géométries', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field(
            'geo',
            config: _multiConfig.copyWith(
              toolbarConfig: const ZGeoEditorToolbarConfig(
                showModeSelector: false,
              ),
            ),
          ),
          registry: _registry(),
        ),
      );
      expect(find.byKey(_modePoint), findsNothing);
    });

    testWidgets(
        'mode initial = allowedGeometries.first quand la tranche est vide '
        '(parité gff:196-198) : point → 2 champs, pas de rayon',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', config: _multiConfig), registry: _registry()),
      );
      expect(find.byKey(_radius), findsNothing);
      expect(find.byKey(_addVertex), findsNothing);
    });

    testWidgets(
        'G2 — la géométrie PORTÉE PAR LA VALEUR INITIALE PRIME (parité '
        'gff:272) : Map legacy typée circle sur un champ dont le 1er mode est '
        'point → UI cercle (champ rayon présent, rayon amorcé)',
        (tester) async {
      final c = _controller(
        'geo',
        value: <String, Object?>{
          'type': 'circle',
          'points': <Object?>[
            <String, Object?>{'lat': 6.13, 'lng': 1.28},
          ],
          'radius': 250.0,
        },
      );
      await tester.pumpWidget(
        _app(c, _field('geo', config: _multiConfig), registry: _registry()),
      );
      expect(find.byKey(_radius), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byKey(_radius)).controller!.text,
        '250.0',
      );
    });

    testWidgets(
        'POLITIQUE D\'EFFACEMENT (parité gff:205-216, rendue explicite) : '
        'changer de mode vide l\'état de travail et émet null dans la tranche',
        (tester) async {
      final fake = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', config: _multiConfig),
          registry: _registry(adapter: fake),
        ),
      );
      // Mode point : fixer un point par tap carte.
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect(c.valueOf('geo'), isNotNull);
      // Bascule vers polygone → la tranche est remise à null (jamais une
      // valeur d'une géométrie incompatible avec le mode affiché).
      await tester.tap(find.byKey(_modePolygon));
      await tester.pump();
      expect(c.valueOf('geo'), isNull);
      expect(find.byKey(_addVertex), findsOneWidget);
      // L'édition reprend proprement dans le nouveau mode.
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      expect(c.valueOf('geo'), isA<ZGeoShape>());
    });

    testWidgets('re-taper le mode COURANT est un no-op strict (rien effacé, '
        'rien émis)', (tester) async {
      final fake = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', config: _multiConfig),
          registry: _registry(adapter: fake),
        ),
      );
      await tester.tap(find.byKey(FakeMapAdapter.mapKey));
      await tester.pump();
      final Object? before = c.valueOf('geo');
      expect(before, isNotNull);
      await tester.tap(find.byKey(_modePoint)); // mode déjà courant
      await tester.pump();
      expect(c.valueOf('geo'), equals(before));
    });

    testWidgets('readOnly → boutons de mode désactivés (pas de bascule)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo', config: _multiConfig, readOnly: true),
          registry: _registry(),
        ),
      );
      await tester.tap(find.byKey(_modeCircle));
      await tester.pump();
      // Toujours en mode point : aucun champ rayon apparu.
      expect(find.byKey(_radius), findsNothing);
    });

    testWidgets('AD-13 — boutons de mode ≥ 48dp (contrainte posée)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo', config: _multiConfig), registry: _registry()),
      );
      final ConstrainedBox box = tester.widget<ConstrainedBox>(
        find.byKey(_modePoint),
      );
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48));
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48));
    });
  });

  group('G4 — fournisseur de carte par champ (adapterKey)', () {
    testWidgets('adapterKey présent → la fabrique NOMMÉE est utilisée',
        (tester) async {
      final osmLike = FakeMapAdapter();
      final googleLike = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field(
            'geo',
            config: const ZGeoFieldConfig(adapterKey: 'google'),
          ),
          registry: _registry(
            adapter: osmLike,
            adapterFactories: <String, ZMapAdapterFactory>{
              'google': () => googleLike,
            },
          ),
        ),
      );
      expect(googleLike.buildCount, greaterThan(0));
      expect(osmLike.buildCount, 0);
    });

    testWidgets('adapterKey INCONNU du registre → repli sur la fabrique '
        'unique, jamais de crash (AD-10)', (tester) async {
      final mono = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field(
            'geo',
            config: const ZGeoFieldConfig(adapterKey: 'inexistante'),
          ),
          registry: _registry(
            adapter: mono,
            adapterFactories: <String, ZMapAdapterFactory>{
              'google': FakeMapAdapter.new,
            },
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(mono.buildCount, greaterThan(0));
    });

    testWidgets('HÔTE MONO-FACTORY STRICTEMENT INCHANGÉ : sans adapterKey ni '
        'adapterFactories, la fabrique unique sert la carte', (tester) async {
      final mono = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(c, _field('geo'), registry: _registry(adapter: mono)),
      );
      expect(mono.buildCount, greaterThan(0));
      expect(find.byKey(FakeMapAdapter.mapKey), findsOneWidget);
    });

    testWidgets('registre nommé fourni mais config SANS adapterKey → fabrique '
        'unique (le registre ne vole jamais le champ)', (tester) async {
      final mono = FakeMapAdapter();
      final named = FakeMapAdapter();
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field('geo'),
          registry: _registry(
            adapter: mono,
            adapterFactories: <String, ZMapAdapterFactory>{
              'google': () => named,
            },
          ),
        ),
      );
      expect(mono.buildCount, greaterThan(0));
      expect(named.buildCount, 0);
    });
  });

  group('G15 — défaut de barre (complément des tests AC3/AC6 mis à jour)', () {
    testWidgets('opt-out explicite : ZGeoEditorToolbarConfig.none → aucune '
        'barre', (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(
        _app(
          c,
          _field(
            'geo',
            config: const ZGeoFieldConfig(
              toolbarConfig: ZGeoEditorToolbarConfig.none,
            ),
          ),
          registry: _registry(),
        ),
      );
      expect(find.byKey(const Key('z-geo-toolbar')), findsNothing);
    });

    testWidgets('champ SANS ZGeoFieldConfig du tout → barre standard aussi '
        '(le défaut ne dépend pas de la présence d\'une config)',
        (tester) async {
      final c = _controller('geo');
      await tester.pumpWidget(_app(c, _field('geo'), registry: _registry()));
      expect(find.byKey(const Key('z-geo-toolbar')), findsOneWidget);
    });
  });
}
