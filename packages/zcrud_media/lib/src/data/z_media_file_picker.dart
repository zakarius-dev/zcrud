/// `ZMediaFilePicker` — impl **concrète** du contrat cœur EXISTANT [ZFilePicker]
/// (fp-4-2, AC1/AC2/AC3). Câble `image_picker`/`file_picker`/`image_cropper`
/// derrière une **API neutre** : [pick] retourne des [AppFile] en
/// [ZAppFileUploadState.pending] (`localPath`/`name`/`mimeType`, **jamais**
/// d'octets — contrat cœur, AD-2).
///
/// 🔴 **AD-40** : aucun type plateforme (`XFile`/`PlatformFile`/`CroppedFile`)
/// n'apparaît en signature ni en valeur de tranche. 🔴 **AD-1/CORE OUT=0** :
/// dépend du seul `zcrud_core` (+ deps média confinées). 🔴 **AD-10** : toute
/// annulation / permission refusée / plugin défaillant produit un **résultat
/// défini** (`[]` ou original pour le crop) — jamais un throw traversant.
///
/// **Seams injectables (testabilité R3)** : chaque chemin (galerie/caméra/
/// filePicker/scan/crop) est délégué à un seam (défaut = plugin réel). Les tests
/// injectent des **fakes** déterministes.
library;

import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_media_crop_options.dart';
import '../domain/z_media_seams.dart';
import 'z_media_plugin_seams.dart';

/// `ZFilePicker` média concret à injecter dans `ZcrudScope.filePicker`.
class ZMediaFilePicker implements ZFilePicker {
  /// Construit la façade média.
  ///
  /// Tous les seams sont **optionnels** : par défaut, ils sont adossés aux
  /// plugins réels ([ZPluginImagePickSeam]/[ZPluginFilePickSeam]/
  /// [ZPluginImageCropSeam]). [scanSeam] est **`null` par défaut** (ET-1 :
  /// `cunning_document_scanner` hors allowlist ⇒ `pick(source: scan)` retourne
  /// `[]` défini). [cropOptions] pilote le recadrage post-pick des images
  /// (désactivé par défaut ⇒ flux d'AC1 inchangé, AC2).
  ZMediaFilePicker({
    ZImagePickSeam? imageSeam,
    ZFilePickSeam? fileSeam,
    ZImageCropSeam? cropSeam,
    ZDocumentScanSeam? scanSeam,
    ZMediaCropOptions cropOptions = const ZMediaCropOptions.disabled(),
  })  : _imageSeam = imageSeam ?? ZPluginImagePickSeam(),
        _fileSeam = fileSeam ?? ZPluginFilePickSeam(),
        _cropSeam = cropSeam ?? ZPluginImageCropSeam(),
        // Champs privés nommés : un formel initialisant `this._scanSeam` /
        // `this._cropOptions` serait un paramètre nommé PRIVÉ (invalide en Dart).
        // Assignations explicites conservées (lint info non applicable).
        // ignore: prefer_initializing_formals
        _scanSeam = scanSeam,
        // ignore: prefer_initializing_formals
        _cropOptions = cropOptions;

  final ZImagePickSeam _imageSeam;
  final ZFilePickSeam _fileSeam;
  final ZImageCropSeam _cropSeam;
  final ZDocumentScanSeam? _scanSeam;
  final ZMediaCropOptions _cropOptions;

  @override
  Future<List<AppFile>> pick({
    required ZFileSource source,
    required FileFieldConfig config,
  }) async {
    try {
      switch (source) {
        case ZFileSource.gallery:
          final picked = await _imageSeam.pickImages(
            fromCamera: false,
            multiple: _multiple(config),
            limit: config.maxFiles,
          );
          return _maybeCrop(picked);
        case ZFileSource.camera:
          // AC3/ET-5 : capture unique déléguée à l'appareil photo OS.
          final picked = await _imageSeam.pickImages(
            fromCamera: true,
            multiple: false,
            limit: 1,
          );
          return _maybeCrop(picked);
        case ZFileSource.filePicker:
          return await _fileSeam.pickFiles(
            extensions: config.effectiveExtensions,
            multiple: _multiple(config),
          );
        case ZFileSource.scan:
          // ET-1 : sans seam scan injecté, résultat défini vide (AD-10).
          final scanner = _scanSeam;
          if (scanner == null) return const <AppFile>[];
          return await scanner.scan();
      }
    } catch (_) {
      // AD-10 : rempart ultime — un seam qui throw ne traverse jamais la façade.
      return const <AppFile>[];
    }
  }

  /// Multiplicité dérivée de la config (source unique = `ZFieldSpec.multiple`,
  /// borne = `maxFiles`) : `maxFiles == 1` ⇒ mono ; sinon multi autorisé. Le
  /// champ (`ZAppFileField`) applique la troncature finale par `maxFiles`.
  bool _multiple(FileFieldConfig config) =>
      config.maxFiles == null || config.maxFiles! > 1;

  /// Applique le recadrage post-pick aux images acquises **si** activé
  /// ([ZMediaCropOptions.enabled]). Recadrage annulé (`null`) ⇒ **original
  /// conservé** (AC2/AD-10) ; désactivé ⇒ liste inchangée (rétro-compat AC1).
  Future<List<AppFile>> _maybeCrop(List<AppFile> picked) async {
    if (!_cropOptions.enabled || picked.isEmpty) return picked;
    final out = <AppFile>[];
    for (final file in picked) {
      final cropped = await _cropSeam.crop(file, _cropOptions);
      out.add(cropped ?? file); // annulé → original.
    }
    return out;
  }
}
