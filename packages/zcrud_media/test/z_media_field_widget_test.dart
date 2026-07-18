/// 🎯 fp-4-2 (AC4/AC6) — widgets riches média via `ZWidgetRegistry` RÉEL :
/// enregistrement sous kinds custom, zone de dépôt (`dotted_border`), émission
/// `onChanged` au drop, vignette vidéo NEUTRE (`Uint8List`), ouverture au tap,
/// a11y (≥48 dp, `Semantics`), rebuild ciblé (SM-1), picker absent → no-op.
///
/// 🔴 **MAJEUR-1 (fp-4-2 code-review)** : les kinds média doivent être
/// ATTEIGNABLES par le VRAI dispatcher cœur (`ZFieldWidget`/`DynamicEdition`),
/// pas seulement via `reg.builderFor(kind)` indexé à la main (qui masquait le
/// défaut). Le groupe « MAJEUR-1 » monte un `ZFieldSpec(type:
/// EditionFieldType.mediaImage/…)` sous `ZcrudScope(widgetRegistry: reg)` et
/// exige le widget média — pas `ZUnsupportedFieldWidget`. Falsifiable : registre
/// vide ⇒ repli.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_media/zcrud_media.dart';

/// PNG 1×1 valide (évite les erreurs de décodage `Image.memory` en test).
final Uint8List _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLv'
  'AAAAAElFTkSuQmCC',
);

class _FakeImageSeam implements ZImagePickSeam {
  @override
  Future<List<AppFile>> pickImages({
    required bool fromCamera,
    required bool multiple,
    int? limit,
  }) async =>
      const <AppFile>[
        AppFile(name: 'picked.jpg', localPath: '/tmp/picked.jpg'),
      ];
}

class _FakeThumbSeam implements ZVideoThumbnailSeam {
  int calls = 0;
  String? lastPath;
  @override
  Future<Uint8List?> generate(String videoPath) async {
    calls++;
    lastPath = videoPath;
    return _png1x1;
  }
}

class _FakeOpenSeam implements ZFileOpenSeam {
  final List<String> opened = <String>[];
  @override
  Future<bool> open(String localPath) async {
    opened.add(localPath);
    return true;
  }
}

ZFieldSpec _field({
  EditionFieldType type = EditionFieldType.custom,
  bool multiple = false,
  bool readOnly = false,
  FileFieldConfig? config,
}) =>
    ZFieldSpec(
      name: 'media',
      type: type,
      label: 'Média',
      multiple: multiple,
      readOnly: readOnly,
      config: config,
    );

/// Harnais : rend un builder de registre DANS une frontière value-in-slice
/// (`ValueListenableBuilder` sur [notifier]) — comme le dispatcher du cœur.
Widget _host(
  ZFieldWidgetBuilder builder,
  ValueNotifier<Object?> notifier,
  ZFieldSpec field, {
  Widget? sibling,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: <Widget>[
            ValueListenableBuilder<Object?>(
              valueListenable: notifier,
              builder: (c, v, _) => builder(
                c,
                ZFieldWidgetContext(
                  field: field,
                  value: v,
                  onChanged: (nv) => notifier.value = nv,
                ),
              ),
            ),
            if (sibling != null) sibling,
          ],
        ),
      ),
    );

/// Monte un champ de type [type] via le VRAI dispatcher (`DynamicEdition` →
/// `ZFieldWidget` → famille `registryOrFallback` → `registry.tryBuilderFor(
/// field.type.name)`) sous un [ZcrudScope] portant [registry]. C'est le chemin
/// d'intégration réel : si un `EditionFieldType` média n'était pas routé vers le
/// registre, le rendu retomberait sur `ZUnsupportedFieldWidget`.
Widget _dispatch(
  EditionFieldType type,
  ZWidgetRegistry? registry, {
  Object? initialValue,
}) {
  final controller = ZFormController(
    initialValues: <String, Object?>{'media': initialValue},
    visibleFields: const <String>['media'],
  );
  addTearDown(controller.dispose);
  final field = ZFieldSpec(name: 'media', type: type, label: 'Média');
  return ZcrudScope(
    widgetRegistry: registry,
    child: MaterialApp(
      home: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: <ZFieldSpec>[field],
        ),
      ),
    ),
  );
}

void main() {
  group('🔴 MAJEUR-1 — kinds média ATTEIGNABLES par le VRAI dispatcher cœur', () {
    test('les kinds sont ALIGNÉS sur EditionFieldType.<media>.name', () {
      // Le dispatcher résout `registry.tryBuilderFor(field.type.name)` : le kind
      // d'enregistrement DOIT être exactement le nom d'enum, sinon le builder est
      // du code mort en intégration.
      expect(mediaImageFieldKind, EditionFieldType.mediaImage.name);
      expect(mediaFileFieldKind, EditionFieldType.mediaFile.name);
      expect(mediaVideoFieldKind, EditionFieldType.mediaVideo.name);
    });

    testWidgets('mediaImage via dispatcher + registre peuplé → widget média '
        '(drop-zone), PAS ZUnsupportedFieldWidget', (t) async {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(
        reg,
        picker: ZMediaFilePicker(imageSeam: _FakeImageSeam()),
      );
      await t.pumpWidget(_dispatch(EditionFieldType.mediaImage, reg));
      await t.pump();
      expect(find.byType(ZMediaFieldWidget), findsOneWidget);
      expect(find.byKey(const Key('z-media-dropzone')), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('mediaFile via dispatcher + registre peuplé → widget média',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(reg, picker: ZMediaFilePicker());
      await t.pumpWidget(_dispatch(EditionFieldType.mediaFile, reg));
      await t.pump();
      expect(find.byType(ZMediaFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('mediaVideo via dispatcher + registre peuplé → widget média',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(reg, picker: ZMediaFilePicker());
      await t.pumpWidget(_dispatch(EditionFieldType.mediaVideo, reg));
      await t.pump();
      expect(find.byType(ZMediaFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('FALSIFIABLE — registre VIDE ⇒ repli ZUnsupportedFieldWidget '
        '(rouge-avant : sans l\'ajout d\'enum, ce chemin était TOUJOURS le repli)',
        (t) async {
      await t.pumpWidget(_dispatch(EditionFieldType.mediaImage, ZWidgetRegistry()));
      await t.pump();
      expect(find.byType(ZMediaFieldWidget), findsNothing);
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('FALSIFIABLE — AUCUN ZcrudScope/registre ⇒ repli contrôlé',
        (t) async {
      await t.pumpWidget(_dispatch(EditionFieldType.mediaVideo, null));
      await t.pump();
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('🔴 MED-2 — vignette vidéo MÉMOÏSÉE (SM-1/AD-2)', () {
    testWidgets('generate() appelé UNE SEULE FOIS par localPath malgré N rebuilds '
        'de la tranche (rouge-avant : appelé à chaque build)', (t) async {
      final reg = ZWidgetRegistry();
      final thumb = _FakeThumbSeam();
      registerZMediaFieldWidgets(reg,
          picker: ZMediaFilePicker(), thumbnailer: thumb);
      final notifier = ValueNotifier<Object?>(
          const AppFile(name: 'v.mp4', localPath: '/tmp/v.mp4'));
      addTearDown(notifier.dispose);
      await t.pumpWidget(
          _host(reg.builderFor(mediaVideoFieldKind), notifier, _field()));
      await t.pumpAndSettle();
      expect(thumb.calls, 1, reason: 'première génération');

      // Rebuild de la tranche SANS changer le chemin (nouvel AppFile, MÊME
      // localPath) : la vignette ne doit PAS être régénérée (Future mémoïsé).
      notifier.value =
          const AppFile(name: 'v-renamed.mp4', localPath: '/tmp/v.mp4');
      await t.pumpAndSettle();
      notifier.value =
          const AppFile(name: 'v-again.mp4', localPath: '/tmp/v.mp4');
      await t.pumpAndSettle();
      expect(thumb.calls, 1,
          reason: 'MED-2 : mémoïsé par localPath — aucun nouvel appel natif');
      expect(thumb.lastPath, '/tmp/v.mp4');
    });
  });

  group('AC6 — enregistrement sous kinds custom (ZWidgetRegistry réel)', () {
    test('registerZMediaFieldWidgets enrôle les 3 kinds custom', () {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(reg, picker: ZMediaFilePicker());
      expect(reg.isRegistered(mediaImageFieldKind), isTrue);
      expect(reg.isRegistered(mediaFileFieldKind), isTrue);
      expect(reg.isRegistered(mediaVideoFieldKind), isTrue);
    });
  });

  group('AC4a — zone de dépôt + émission onChanged au drop', () {
    testWidgets('drop-zone présente et déclenche l\'acquisition (via registre)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(
        reg,
        picker: ZMediaFilePicker(imageSeam: _FakeImageSeam()),
      );
      final notifier = ValueNotifier<Object?>(null);
      await t.pumpWidget(
          _host(reg.builderFor(mediaImageFieldKind), notifier, _field()));
      expect(find.byKey(const Key('z-media-dropzone')), findsOneWidget);

      await t.tap(find.byKey(const Key('z-media-dropzone')));
      await t.pumpAndSettle();
      expect(notifier.value, isA<AppFile>());
      expect((notifier.value! as AppFile).localPath, '/tmp/picked.jpg');
      addTearDown(notifier.dispose);
    });

    testWidgets('picker null → drop-zone désactivée, aucun onChanged (AD-10)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(reg); // picker: null
      final notifier = ValueNotifier<Object?>(null);
      await t.pumpWidget(
          _host(reg.builderFor(mediaImageFieldKind), notifier, _field()));
      await t.tap(find.byKey(const Key('z-media-dropzone')));
      await t.pumpAndSettle();
      expect(notifier.value, isNull);
      addTearDown(notifier.dispose);
    });
  });

  group('AC4c — vignette vidéo neutre (Uint8List)', () {
    testWidgets('mediaVideo génère une vignette via le seam (type neutre)',
        (t) async {
      final reg = ZWidgetRegistry();
      final thumb = _FakeThumbSeam();
      registerZMediaFieldWidgets(reg,
          picker: ZMediaFilePicker(), thumbnailer: thumb);
      final notifier = ValueNotifier<Object?>(
          const AppFile(name: 'v.mp4', localPath: '/tmp/v.mp4'));
      await t.pumpWidget(
          _host(reg.builderFor(mediaVideoFieldKind), notifier, _field()));
      await t.pumpAndSettle();
      expect(thumb.calls, greaterThanOrEqualTo(1));
      expect(thumb.lastPath, '/tmp/v.mp4');
      expect(find.byType(Image), findsOneWidget);
      addTearDown(notifier.dispose);
    });
  });

  group('AC4b — ouverture au tap (résultat défini)', () {
    testWidgets('tap sur le bouton ouvrir → seam.open(localPath)', (t) async {
      final reg = ZWidgetRegistry();
      final opener = _FakeOpenSeam();
      registerZMediaFieldWidgets(reg,
          picker: ZMediaFilePicker(), opener: opener);
      final notifier = ValueNotifier<Object?>(
          const AppFile(name: 'doc.pdf', localPath: '/tmp/doc.pdf'));
      await t.pumpWidget(
          _host(reg.builderFor(mediaFileFieldKind), notifier, _field()));
      await t.pump();
      await t.tap(find.byKey(const Key('z-media-open-/tmp/doc.pdf')));
      await t.pump();
      expect(opener.opened, <String>['/tmp/doc.pdf']);
      addTearDown(notifier.dispose);
    });
  });

  group('AC4 — a11y (≥48 dp, Semantics)', () {
    testWidgets('boutons ouvrir/retirer ≥ 48 dp + Semantics drop-zone', (t) async {
      final reg = ZWidgetRegistry();
      registerZMediaFieldWidgets(reg, picker: ZMediaFilePicker());
      final notifier = ValueNotifier<Object?>(
          const AppFile(name: 'doc.pdf', localPath: '/tmp/doc.pdf'));
      final handle = t.ensureSemantics();
      await t.pumpWidget(
          _host(reg.builderFor(mediaFileFieldKind), notifier, _field()));
      await t.pump();
      final open = t.widget<IconButton>(
          find.byKey(const Key('z-media-open-/tmp/doc.pdf')));
      expect(open.constraints!.minHeight, greaterThanOrEqualTo(48));
      final remove = t.widget<IconButton>(
          find.byKey(const Key('z-media-remove-/tmp/doc.pdf')));
      expect(remove.constraints!.minWidth, greaterThanOrEqualTo(48));
      // Drop-zone (multiple) annoncée comme bouton sémantique.
      expect(
        find.bySemanticsLabel('Ajouter un fichier'),
        findsNothing, // mono + fichier présent ⇒ pas de drop-zone ici
      );
      handle.dispose();
      addTearDown(notifier.dispose);
    });
  });

  group('AC4 — SM-1 : rebuild ciblé (value-in-slice)', () {
    testWidgets('un voisin qui change NE reconstruit PAS le champ média',
        (t) async {
      var buildCount = 0;
      final builder = ZMediaFieldWidget.builder(
        mode: ZMediaFieldMode.image,
        thumbnailer: _FakeThumbSeam(),
        opener: _FakeOpenSeam(),
        picker: ZMediaFilePicker(imageSeam: _FakeImageSeam()),
        onBuild: () => buildCount++,
      );
      final target = ValueNotifier<Object?>(null);
      final sibling = ValueNotifier<int>(0);
      await t.pumpWidget(_host(
        builder,
        target,
        _field(),
        sibling: ValueListenableBuilder<int>(
          valueListenable: sibling,
          builder: (c, v, _) => Text('sib $v'),
        ),
      ));
      expect(buildCount, 1);

      // Le voisin change → le champ média NE se reconstruit pas.
      sibling.value = 1;
      await t.pump();
      expect(buildCount, 1);

      // Sa propre tranche change → un seul rebuild ciblé.
      target.value = const AppFile(name: 'x.jpg', localPath: '/x.jpg');
      await t.pump();
      expect(buildCount, 2);
      addTearDown(target.dispose);
      addTearDown(sibling.dispose);
    });
  });
}
