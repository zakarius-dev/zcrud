// DP-18 (M15) — ZSignatureCodec strokes ↔ PNG (rasterisation déférée + pur-Dart).
//
// Couvre :
//  - round-trip strokes ↔ valeur-de-tranche (Map versionnée) ;
//  - défensif (AD-10) : valeur corrompue → [] / null, jamais de throw ;
//  - inspection PNG pur-Dart : isPng / pngSize (IHDR) ;
//  - toPng : aucun rasterizer → null ; rasterizer défaillant → null ;
//  - PREUVE de seam : un rasterizer RÉEL `dart:ui` (implémentable dans un
//    binding/`zcrud_export`) produit un PNG que le codec sait ré-inspecter.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Rasterizer RÉEL (dart:ui) — vit hors du cœur (ici : côté test, preuve qu'un
/// binding peut l'implémenter). Défensif (AD-10).
Future<Uint8List?> _realRasterizer(
  List<List<Offset>> strokes,
  ZSignatureRasterSpec spec,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()
    ..color = ui.Color(spec.strokeColorArgb)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = spec.strokeWidth;
  for (final stroke in strokes) {
    for (var i = 1; i < stroke.length; i++) {
      canvas.drawLine(
        Offset(stroke[i - 1].dx * spec.width, stroke[i - 1].dy * spec.height),
        Offset(stroke[i].dx * spec.width, stroke[i].dy * spec.height),
        paint,
      );
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(spec.width, spec.height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

void main() {
  const codec = ZSignatureCodec();

  final strokes = <List<Offset>>[
    <Offset>[const Offset(0.1, 0.2), const Offset(0.5, 0.6)],
    <Offset>[const Offset(0.7, 0.7)],
  ];

  group('DP-18 — round-trip pur-Dart', () {
    test('valueFromStrokes → strokesFromValue restitue les strokes', () {
      final value = codec.valueFromStrokes(strokes);
      expect(value, isNotNull);
      expect(value!['formatVersion'], ZSignatureCodec.formatVersion);
      final back = codec.strokesFromValue(value);
      expect(back.length, 2);
      expect(back[0][0].dx, closeTo(0.1, 1e-9));
      expect(back[0][1].dy, closeTo(0.6, 1e-9));
      expect(back[1][0].dx, closeTo(0.7, 1e-9));
    });

    test('strokes vides → null', () {
      expect(codec.valueFromStrokes(const <List<Offset>>[]), isNull);
      expect(codec.valueFromStrokes(<List<Offset>>[<Offset>[]]), isNull);
    });

    test('défensif : valeur corrompue → [] (jamais de throw)', () {
      expect(codec.strokesFromValue(null), isEmpty);
      expect(codec.strokesFromValue(42), isEmpty);
      expect(codec.strokesFromValue(<String, dynamic>{'strokes': 'nope'}),
          isEmpty);
      expect(
        codec.strokesFromValue(<String, dynamic>{
          'strokes': <dynamic>[
            <dynamic>['x', 'y'],
            42,
          ],
        }),
        isEmpty,
      );
    });
  });

  group('DP-18 — inspection PNG pur-Dart', () {
    test('isPng : magic-number', () {
      final png = Uint8List.fromList(
          <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0]);
      expect(codec.isPng(png), isTrue);
      expect(codec.isPng(Uint8List.fromList(<int>[1, 2, 3])), isFalse);
      expect(codec.isPng(Uint8List(0)), isFalse);
    });

    test('pngSize : lit IHDR ; non-PNG → null', () {
      // En-tête PNG minimal : magic (8) + longueur+type IHDR (8) + W/H (8).
      final bytes = Uint8List(24)
        ..setRange(0, 8, <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..setRange(16, 20, <int>[0, 0, 1, 0x2C]) // W = 300
        ..setRange(20, 24, <int>[0, 0, 0, 0x64]); // H = 100
      final size = codec.pngSize(bytes);
      expect(size, const Size(300, 100));
      expect(codec.pngSize(Uint8List.fromList(<int>[1, 2, 3])), isNull);
    });
  });

  group('DP-18 — toPng (seam déféré)', () {
    test('aucun rasterizer → null', () async {
      expect(await codec.toPng(codec.valueFromStrokes(strokes)), isNull);
    });

    test('rasterizer défaillant → null (défensif AD-10)', () async {
      final failing = ZSignatureCodec(
          rasterizer: (_, __) async => throw StateError('boom'));
      expect(await failing.toPng(codec.valueFromStrokes(strokes)), isNull);
    });

    test('strokes vides → null (même avec rasterizer)', () async {
      final c = ZSignatureCodec(
          rasterizer: (_, __) async => Uint8List.fromList(<int>[1]));
      expect(await c.toPng(null), isNull);
    });

    test('PREUVE seam : rasterizer dart:ui RÉEL → PNG valide ré-inspectable',
        () async {
      const c = ZSignatureCodec(rasterizer: _realRasterizer);
      final png = await c.toPng(
        codec.valueFromStrokes(strokes),
        spec: const ZSignatureRasterSpec(width: 120, height: 40),
      );
      expect(png, isNotNull);
      expect(c.isPng(png!), isTrue);
      expect(c.pngSize(png), const Size(120, 40));
    });
  });
}
