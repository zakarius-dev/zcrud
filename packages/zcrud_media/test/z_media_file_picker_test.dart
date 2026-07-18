/// 🎯 fp-4-2 (AC1/AC2/AC3) — `ZMediaFilePicker` : contrat cœur [ZFilePicker]
/// concret, API neutre, seams injectables prouvés par **fakes** déterministes
/// (discipline R3 : jamais le vrai plugin). Routage galerie/caméra/filePicker/
/// scan, recadrage post-pick (activé/annulé/désactivé), repli défini AD-10.
@TestOn('vm')
library;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_media/zcrud_media.dart';

/// Fake image seam : enregistre les paramètres reçus + renvoie une réponse
/// programmée (ou throw pour simuler une permission refusée).
class _FakeImageSeam implements ZImagePickSeam {
  _FakeImageSeam(this._response);

  final List<AppFile> Function() _response;
  bool? lastFromCamera;
  bool? lastMultiple;
  int? lastLimit;

  @override
  Future<List<AppFile>> pickImages({
    required bool fromCamera,
    required bool multiple,
    int? limit,
  }) async {
    lastFromCamera = fromCamera;
    lastMultiple = multiple;
    lastLimit = limit;
    return _response();
  }
}

/// Fake file seam : enregistre extensions/multiple, renvoie une réponse.
class _FakeFileSeam implements ZFilePickSeam {
  _FakeFileSeam(this._response);

  final List<AppFile> Function() _response;
  List<String>? lastExtensions;
  bool? lastMultiple;

  @override
  Future<List<AppFile>> pickFiles({
    required List<String> extensions,
    required bool multiple,
  }) async {
    lastExtensions = extensions;
    lastMultiple = multiple;
    return _response();
  }
}

/// Fake crop seam : conduite paramétrable (recadre / annule / throw).
class _FakeCropSeam implements ZImageCropSeam {
  _FakeCropSeam(this._behavior);

  final AppFile? Function(AppFile source) _behavior;
  int calls = 0;

  @override
  Future<AppFile?> crop(AppFile source, ZMediaCropOptions options) async {
    calls++;
    return _behavior(source);
  }
}

/// Fake scan seam (ET-1) : renvoie un PDF fictif.
class _FakeScanSeam implements ZDocumentScanSeam {
  @override
  Future<List<AppFile>> scan() async =>
      const <AppFile>[AppFile(name: 'scan.pdf', localPath: '/tmp/scan.pdf')];
}

const AppFile _img = AppFile(
  name: 'photo.jpg',
  localPath: '/tmp/photo.jpg',
  mimeType: 'image/jpeg',
);

void main() {
  group('AC1 — routage & AppFile neutres (seams fakes)', () {
    test('gallery mono (maxFiles:1) → pickImages(fromCamera:false, multiple:false)',
        () async {
      final seam = _FakeImageSeam(() => <AppFile>[_img]);
      final picker = ZMediaFilePicker(imageSeam: seam);
      final out = await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(maxFiles: 1),
      );
      expect(seam.lastFromCamera, isFalse);
      expect(seam.lastMultiple, isFalse);
      expect(out, hasLength(1));
      final f = out.single;
      expect(f.localPath, '/tmp/photo.jpg');
      expect(f.name, 'photo.jpg');
      expect(f.mimeType, 'image/jpeg');
      // Contrat cœur : pending + aucune notion d'octets exposée.
      expect(f.uploadState, ZAppFileUploadState.pending);
    });

    test('gallery multi (maxFiles null) → pickMultiImage(multiple:true, limit:null)',
        () async {
      final seam = _FakeImageSeam(() => const <AppFile>[
            AppFile(name: 'a.jpg', localPath: '/a.jpg'),
            AppFile(name: 'b.jpg', localPath: '/b.jpg'),
          ]);
      final picker = ZMediaFilePicker(imageSeam: seam);
      final out = await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(),
      );
      expect(seam.lastMultiple, isTrue);
      expect(seam.lastLimit, isNull);
      expect(out, hasLength(2));
    });

    test('gallery multi borné → limit == maxFiles', () async {
      final seam = _FakeImageSeam(() => const <AppFile>[]);
      final picker = ZMediaFilePicker(imageSeam: seam);
      await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(maxFiles: 3),
      );
      expect(seam.lastMultiple, isTrue);
      expect(seam.lastLimit, 3);
    });

    test('camera → pickImage(source: camera), toujours mono (ET-5)', () async {
      final seam = _FakeImageSeam(() => <AppFile>[_img]);
      final picker = ZMediaFilePicker(imageSeam: seam);
      final out = await picker.pick(
        source: ZFileSource.camera,
        config: const FileFieldConfig(),
      );
      expect(seam.lastFromCamera, isTrue);
      expect(seam.lastMultiple, isFalse);
      expect(out, hasLength(1));
    });

    test('filePicker → extensions == effectiveExtensions', () async {
      final seam = _FakeFileSeam(() => const <AppFile>[
            AppFile(name: 'doc.pdf', localPath: '/doc.pdf'),
          ]);
      final picker = ZMediaFilePicker(fileSeam: seam);
      final out = await picker.pick(
        source: ZFileSource.filePicker,
        config: const FileFieldConfig(
          acceptedExtensions: <String>['pdf'],
          allowedDocumentTypes: <String, List<String>>{
            'images': <String>['png'],
          },
        ),
      );
      expect(seam.lastExtensions, <String>['pdf', 'png']);
      expect(out.single.name, 'doc.pdf');
    });
  });

  group('AC2 — recadrage post-pick optionnel (résultat neutre)', () {
    test('activé → localPath remplacé par le fichier recadré', () async {
      final imageSeam = _FakeImageSeam(() => <AppFile>[_img]);
      final crop = _FakeCropSeam(
          (src) => src.copyWith(localPath: '/tmp/cropped.jpg'));
      final picker = ZMediaFilePicker(
        imageSeam: imageSeam,
        cropSeam: crop,
        cropOptions: const ZMediaCropOptions.on(),
      );
      final out = await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(maxFiles: 1),
      );
      expect(crop.calls, 1);
      expect(out.single.localPath, '/tmp/cropped.jpg');
    });

    test('annulé (crop → null) → original conservé, aucune exception (AD-10)',
        () async {
      final imageSeam = _FakeImageSeam(() => <AppFile>[_img]);
      final crop = _FakeCropSeam((_) => null);
      final picker = ZMediaFilePicker(
        imageSeam: imageSeam,
        cropSeam: crop,
        cropOptions: const ZMediaCropOptions.on(),
      );
      final out = await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(maxFiles: 1),
      );
      expect(crop.calls, 1);
      expect(out.single.localPath, '/tmp/photo.jpg'); // inchangé.
    });

    test('désactivé (défaut) → seam crop JAMAIS appelé, flux inchangé', () async {
      final imageSeam = _FakeImageSeam(() => <AppFile>[_img]);
      final crop = _FakeCropSeam((_) => fail('crop ne doit pas être appelé'));
      final picker = ZMediaFilePicker(imageSeam: imageSeam, cropSeam: crop);
      final out = await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(maxFiles: 1),
      );
      expect(crop.calls, 0);
      expect(out.single.localPath, '/tmp/photo.jpg');
    });
  });

  group('AC3 — permission/annulation & scan (AD-10)', () {
    test('seam qui throw PlatformException(denied) → [] défini, pas de propagation',
        () async {
      final seam = _FakeImageSeam(
          () => throw PlatformException(code: 'photo_access_denied'));
      final picker = ZMediaFilePicker(imageSeam: seam);
      final out = await picker.pick(
        source: ZFileSource.gallery,
        config: const FileFieldConfig(),
      );
      expect(out, isEmpty);
    });

    test('annulation (seam → []) → [] défini', () async {
      final seam = _FakeImageSeam(() => const <AppFile>[]);
      final picker = ZMediaFilePicker(imageSeam: seam);
      final out = await picker.pick(
        source: ZFileSource.camera,
        config: const FileFieldConfig(),
      );
      expect(out, isEmpty);
    });

    test('scan sans seam injecté (ET-1) → [] défini, jamais un throw', () async {
      final picker = ZMediaFilePicker();
      final out = await picker.pick(
        source: ZFileSource.scan,
        config: const FileFieldConfig(),
      );
      expect(out, isEmpty);
    });

    test('scan AVEC seam injecté → produit le(s) fichier(s)', () async {
      final picker = ZMediaFilePicker(scanSeam: _FakeScanSeam());
      final out = await picker.pick(
        source: ZFileSource.scan,
        config: const FileFieldConfig(),
      );
      expect(out.single.name, 'scan.pdf');
    });
  });

  group('AC1 — surface neutre', () {
    test('ZMediaFilePicker EST un ZFilePicker (contrat cœur)', () {
      expect(ZMediaFilePicker(), isA<ZFilePicker>());
    });
  });
}
