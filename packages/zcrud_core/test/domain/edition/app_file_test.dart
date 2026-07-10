// AC2/AC3 (E3-3c) — `AppFile` : value object pur-Dart SANS bytes, round-trip
// `toMap`/`fromMap`, `copyWith`, `==`/`hashCode`, désérialisation DÉFENSIVE
// (AD-10 : champ absent/corrompu / uploadState inconnu → défaut sûr, 0 throw),
// enum `ZAppFileUploadState` camelCase.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZAppFileUploadState (AC3)', () {
    test('valeurs camelCase attendues', () {
      expect(
        ZAppFileUploadState.values.map((e) => e.name).toList(),
        <String>['pending', 'uploading', 'uploaded', 'failed'],
      );
    });

    test('fromName : nom connu → valeur ; inconnu/null → pending (défensif)', () {
      expect(ZAppFileUploadState.fromName('uploaded'), ZAppFileUploadState.uploaded);
      expect(ZAppFileUploadState.fromName('failed'), ZAppFileUploadState.failed);
      // Repli défensif (AD-10) — jamais un throw.
      expect(ZAppFileUploadState.fromName('__inconnu__'), ZAppFileUploadState.pending);
      expect(ZAppFileUploadState.fromName(null), ZAppFileUploadState.pending);
      expect(ZAppFileUploadState.fromName(42), ZAppFileUploadState.pending);
    });
  });

  group('AppFile (AC2)', () {
    const full = AppFile(
      id: 'f1',
      name: 'photo.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
      remoteUrl: 'https://cdn/f1.png',
      localPath: '/tmp/photo.png',
      uploadState: ZAppFileUploadState.uploaded,
      progress: 1,
      documentType: 'passport',
      extra: <String, dynamic>{'k': 'v'},
    );

    test('round-trip toMap/fromMap préserve tous les champs', () {
      final round = AppFile.fromMap(full.toMap());
      expect(round, full);
      expect(round.hashCode, full.hashCode);
    });

    test('toMap : clés snake_case + uploadState camelCase, aucun champ bytes', () {
      final map = full.toMap();
      expect(map.keys, containsAll(<String>[
        'id', 'name', 'mime_type', 'size_bytes', 'remote_url', 'local_path',
        'upload_state', 'progress', 'document_type', 'extra',
      ]));
      expect(map['upload_state'], 'uploaded');
      // AUCUN champ d'octets (AD-2 : tranche légère).
      expect(map.keys.any((k) => k.contains('byte') && k != 'size_bytes'), isFalse);
      expect(map.containsKey('bytes'), isFalse);
      expect(map.containsKey('data'), isFalse);
    });

    test('isImage dérivé du mimeType', () {
      expect(full.isImage, isTrue);
      expect(const AppFile(mimeType: 'application/pdf').isImage, isFalse);
      expect(const AppFile().isImage, isFalse);
    });

    test('copyWith surcharge ciblée (null conserve — convention documentée)', () {
      final up = full.copyWith(uploadState: ZAppFileUploadState.failed);
      expect(up.uploadState, ZAppFileUploadState.failed);
      expect(up.name, full.name);
      expect(up.remoteUrl, full.remoteUrl);
      // null conserve la valeur courante.
      expect(full.copyWith().name, full.name);
    });

    test('== / hashCode : égalité de valeur (extra profond)', () {
      const a = AppFile(name: 'a', extra: <String, dynamic>{'x': 1});
      const b = AppFile(name: 'a', extra: <String, dynamic>{'x': 1});
      const c = AppFile(name: 'a', extra: <String, dynamic>{'x': 2});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('AppFile.fromMap défensif (AC2/AD-10)', () {
    test('map vide → défauts sûrs, jamais un throw', () {
      final f = AppFile.fromMap(<String, dynamic>{});
      expect(f.name, '');
      expect(f.id, isNull);
      expect(f.uploadState, ZAppFileUploadState.pending);
      expect(f.sizeBytes, isNull);
    });

    test('champs corrompus (types inattendus) → défaut sûr, 0 throw', () {
      final f = AppFile.fromMap(<String, dynamic>{
        'id': 123, // pas une String
        'name': <int>[1, 2], // pas une String
        'size_bytes': 'abc', // pas parsable
        'upload_state': <String>['x'], // pas une String connue
        'progress': true,
        'extra': 'pas une map',
      });
      expect(f.id, isNull);
      expect(f.name, '');
      expect(f.sizeBytes, isNull);
      expect(f.uploadState, ZAppFileUploadState.pending);
      expect(f.progress, isNull);
      expect(f.extra, isNull);
    });

    test('size_bytes/progress tolèrent num et String parsable', () {
      final f = AppFile.fromMap(<String, dynamic>{
        'size_bytes': '2048',
        'progress': '0.5',
      });
      expect(f.sizeBytes, 2048);
      expect(f.progress, 0.5);
    });
  });
}
