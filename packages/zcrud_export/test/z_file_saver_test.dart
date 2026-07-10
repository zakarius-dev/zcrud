// E11b-3 — Tests fonctionnels de `ZFileSaver` (Axe B, AC5-8) — voie IO (VM).
//
// Sous `flutter test` (VM Dart), l'import conditionnel charge `z_file_saver_io.dart`
// (`dart.library.io`). On vérifie l'écriture RÉELLE sur disque : fichier créé,
// relecture == bytes, `directoryPath` créé récursivement, bytes vides → fichier
// vide valide. La voie WEB n'est PAS exerçable ici (VM) → couverte par le gate
// statique `isolation_gates_test.dart` (compile analyzer-clean, n'importe que
// web/js_interop, aucun secret) — cf. AC12 / Dev Notes « Web non testable sur VM ».
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export/zcrud_export.dart';

void main() {
  const saver = ZFileSaver();
  final createdDirs = <Directory>[];

  tearDownAll(() {
    for (final d in createdDirs) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  group('AC7 — écriture disque (io)', () {
    test('save vers systemTemp → fichier existe, relecture == bytes', () async {
      final bytes = Uint8List.fromList(<int>[1, 2, 3, 4, 5, 250, 0, 128]);
      final result = await saver.save(
        bytes,
        fileName: 'zcrud_export_io_test.bin',
      );
      expect(result.success, isTrue);
      expect(result.fileName, 'zcrud_export_io_test.bin');
      expect(result.path, isNotNull);

      final file = File(result.path!);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), bytes);
    });

    test('directoryPath fourni + créé récursivement', () async {
      final base = Directory.systemTemp.createTempSync('zcrud_export_test_');
      createdDirs.add(base);
      final nested = '${base.path}${Platform.pathSeparator}a'
          '${Platform.pathSeparator}b${Platform.pathSeparator}c';

      final bytes = Uint8List.fromList(<int>[9, 8, 7]);
      final result = await saver.save(
        bytes,
        fileName: 'nested.dat',
        directoryPath: nested,
        mimeType: 'application/octet-stream',
      );

      expect(result.success, isTrue);
      expect(Directory(nested).existsSync(), isTrue,
          reason: 'le répertoire cible doit être créé récursivement');
      final file = File(result.path!);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsBytes(), bytes);
      expect(
        result.path,
        '$nested${Platform.pathSeparator}nested.dat',
      );
    });
  });

  group('AC8 — défensif : bytes vides → fichier vide valide, jamais de crash', () {
    test('bytes vides → fichier de taille 0', () async {
      final result = await saver.save(
        Uint8List(0),
        fileName: 'empty.bin',
      );
      expect(result.success, isTrue);
      final file = File(result.path!);
      addTearDown(() {
        if (file.existsSync()) file.deleteSync();
      });
      expect(file.existsSync(), isTrue);
      expect(await file.length(), 0);
    });
  });
}
