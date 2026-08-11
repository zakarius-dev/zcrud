/// Implémentations **par défaut** des seams média, adossées aux plugins réels.
///
/// **Confinement (invariant AD-1)** : c'est le SEUL endroit qui importe
/// `image_picker`/`file_picker`/`image_cropper`/`video_thumbnail`/`open_file` ;
/// aucun type de ces plugins ne franchit une signature publique (les seams
/// exposent [AppFile]/`String`/`Uint8List`). Ces impls ne sont **pas** exercées
/// en test (fakes injectés) ; elles sont le comportement de production quand
/// aucun seam n'est injecté.
///
/// **Invariant AD-10** : chaque méthode enveloppe le plugin et retombe sur un
/// résultat défini (`[]` / `null` / `false`) — jamais un throw traversant.
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_media_crop_options.dart';
import '../domain/z_media_seams.dart';

/// Seam images par défaut (`image_picker`). Caméra = délégation au système
/// d'exploitation.
class ZPluginImagePickSeam implements ZImagePickSeam {
  /// Construit le seam ; [picker] injectable pour un remplacement fin (défaut =
  /// vrai `ImagePicker`).
  ZPluginImagePickSeam({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<List<AppFile>> pickImages({
    required bool fromCamera,
    required bool multiple,
    int? limit,
  }) async {
    try {
      if (fromCamera) {
        // Capture via l'appareil photo du système d'exploitation (jamais le
        // paquet `camera` en chemin par défaut).
        final x = await _picker.pickImage(source: ImageSource.camera);
        return x == null ? const <AppFile>[] : <AppFile>[_toAppFile(x)];
      }
      if (multiple) {
        final xs = await _picker.pickMultiImage(limit: limit);
        return xs.map(_toAppFile).toList(growable: false);
      }
      final x = await _picker.pickImage(source: ImageSource.gallery);
      return x == null ? const <AppFile>[] : <AppFile>[_toAppFile(x)];
    } catch (_) {
      // invariant AD-10 : annulation / permission refusée / plugin défaillant
      // → défini.
      return const <AppFile>[];
    }
  }

  static AppFile _toAppFile(XFile x) => AppFile(
        name: x.name,
        localPath: x.path,
        mimeType: x.mimeType,
      );
}

/// Seam fichiers par défaut (`file_picker`).
class ZPluginFilePickSeam implements ZFilePickSeam {
  @override
  Future<List<AppFile>> pickFiles({
    required List<String> extensions,
    required bool multiple,
  }) async {
    try {
      final hasExt = extensions.isNotEmpty;
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: multiple,
        type: hasExt ? FileType.custom : FileType.any,
        allowedExtensions: hasExt ? extensions : null,
      );
      final files = result?.files ?? const <PlatformFile>[];
      return <AppFile>[
        for (final f in files)
          if (f.path != null)
            AppFile(name: f.name, localPath: f.path),
      ];
    } catch (_) {
      return const <AppFile>[];
    }
  }
}

/// Seam recadrage par défaut (`image_cropper`). Traduit [ZMediaCropOptions]
/// (neutre) vers l'API `image_cropper` ; `null` si annulé.
class ZPluginImageCropSeam implements ZImageCropSeam {
  /// Construit le seam ; [cropper] injectable (défaut = vrai `ImageCropper`).
  ZPluginImageCropSeam({ImageCropper? cropper})
      : _cropper = cropper ?? ImageCropper();

  final ImageCropper _cropper;

  @override
  Future<AppFile?> crop(AppFile source, ZMediaCropOptions options) async {
    final path = source.localPath;
    if (path == null) return null;
    try {
      final cropped = await _cropper.cropImage(
        sourcePath: path,
        maxWidth: options.maxWidth,
        maxHeight: options.maxHeight,
        aspectRatio: options.hasAspectRatio
            ? CropAspectRatio(
                ratioX: options.aspectRatioX!.toDouble(),
                ratioY: options.aspectRatioY!.toDouble(),
              )
            : null,
        compressQuality: options.compressQuality,
      );
      if (cropped == null) return null; // annulé → original conservé (façade).
      return source.copyWith(localPath: cropped.path);
    } catch (_) {
      // invariant AD-10 : échec du recadrage → `null` (façade conserve
      // l'original).
      return null;
    }
  }
}

/// Seam vignette vidéo par défaut (`video_thumbnail`). Type neutre `Uint8List`.
class ZPluginVideoThumbnailSeam implements ZVideoThumbnailSeam {
  @override
  Future<Uint8List?> generate(String videoPath) async {
    if (videoPath.isEmpty) return null;
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.PNG,
        quality: 75,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Seam ouverture par défaut (`open_file`). `true` si l'app système a ouvert le
/// fichier ([ResultType.done]).
class ZPluginFileOpenSeam implements ZFileOpenSeam {
  @override
  Future<bool> open(String localPath) async {
    if (localPath.isEmpty) return false;
    try {
      final result = await OpenFile.open(localPath);
      return result.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
