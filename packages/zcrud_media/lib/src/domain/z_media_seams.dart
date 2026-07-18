/// Seams d'acquisition média **injectables** (fp-4-2, AC1/AC2/AC3/AC4).
///
/// 🔴 **API NEUTRE (AD-40)** : chaque seam expose des méthodes dont les
/// signatures ne portent **AUCUN** type plateforme (`XFile`/`PlatformFile`/
/// `CroppedFile`/`File`) — uniquement des [AppFile]/chemins `String`/
/// `Uint8List`. Les implémentations par défaut (plugins réels) vivent dans
/// `lib/src/data/` (confinées) ; les tests injectent des **fakes** déterministes
/// (discipline R3 : jamais le vrai plugin, non testable sans device).
///
/// 🔴 **AD-10** : chaque contrat garantit un **résultat défini** (liste vide /
/// `null` / `false`) sur annulation, permission refusée ou plugin défaillant —
/// **jamais** un throw traversant. La façade [ZMediaFilePicker] renforce cette
/// garantie en enveloppant tout appel de seam.
library;

import 'dart:typed_data';

import 'package:zcrud_core/zcrud_core.dart';

import 'z_media_crop_options.dart';

/// Seam de sélection d'**images** (galerie/caméra), neutre.
///
/// [fromCamera] `true` ⇒ capture caméra (parité DODLP : délégation à l'appareil
/// photo OS, ET-5) ; sinon galerie. [multiple] autorise la multi-sélection
/// (galerie) ; [limit] borne le nombre de fichiers (`maxFiles`). Retourne des
/// [AppFile] neutres en [ZAppFileUploadState.pending] (`localPath`/`name`/
/// `mimeType`, jamais d'octets). Annulation / permission refusée ⇒ `[]`.
abstract class ZImagePickSeam {
  /// Acquiert 0..n images depuis la caméra ou la galerie.
  Future<List<AppFile>> pickImages({
    required bool fromCamera,
    required bool multiple,
    int? limit,
  });
}

/// Seam de sélection de **fichiers/documents** génériques, neutre.
///
/// [extensions] restreint les extensions acceptées (issu de
/// `FileFieldConfig.effectiveExtensions` ; vide = aucune contrainte).
/// [multiple] autorise la multi-sélection. Retourne des [AppFile] neutres en
/// [ZAppFileUploadState.pending]. Annulation ⇒ `[]`.
abstract class ZFilePickSeam {
  /// Acquiert 0..n fichiers depuis le sélecteur de documents.
  Future<List<AppFile>> pickFiles({
    required List<String> extensions,
    required bool multiple,
  });
}

/// Seam de **recadrage** d'image post-pick, neutre.
///
/// [source] est l'[AppFile] fraîchement acquis ; [options] les réglages neutres
/// ([ZMediaCropOptions]). Retourne un **nouvel** [AppFile] (chemin recadré) si
/// l'utilisateur valide, ou `null` s'il **annule** — auquel cas la façade
/// conserve l'original (AD-10). Jamais de throw traversant.
abstract class ZImageCropSeam {
  /// Recadre [source] selon [options] ; `null` si annulé.
  Future<AppFile?> crop(AppFile source, ZMediaCropOptions options);
}

/// Seam OPTIONNEL de **numérisation** de document (`ZFileSource.scan`).
///
/// 🔴 **ET-1** : `cunning_document_scanner` est **hors allowlist** (mono-mainteneur,
/// natif, risque élevé). Ce seam reste donc **injectable** et **`null` par
/// défaut** dans [ZMediaFilePicker] ⇒ `pick(source: scan)` retourne un `[]`
/// **défini** (AD-10), jamais un throw. Une story binding/média ultérieure
/// pourra fournir une impl concrète en l'ajoutant à SON allowlist. Retourne des
/// [AppFile] neutres (idéalement un PDF assemblé). Annulation ⇒ `[]`.
abstract class ZDocumentScanSeam {
  /// Numérise 0..n pages ; retourne le(s) fichier(s) neutre(s) produit(s).
  Future<List<AppFile>> scan();
}

/// Seam de génération de **vignette vidéo**, neutre (AC4c).
///
/// [videoPath] est un chemin local ; retourne les octets PNG/JPEG en
/// [Uint8List] (type neutre — **aucun** type plateforme), ou `null` si la
/// génération échoue / le chemin est vide (AD-10). Jamais de throw traversant.
abstract class ZVideoThumbnailSeam {
  /// Génère une vignette pour [videoPath] ; `null` si indisponible.
  Future<Uint8List?> generate(String videoPath);
}

/// Seam d'**ouverture** d'un fichier au tap, neutre (AC4b).
///
/// [localPath] est le chemin du fichier acquis ; retourne `true` si l'ouverture
/// a réussi, `false` sinon (aucune app, chemin absent, permission refusée) —
/// **résultat défini**, jamais un throw traversant (AD-10).
abstract class ZFileOpenSeam {
  /// Ouvre [localPath] via l'app système ; `true` si réussi.
  Future<bool> open(String localPath);
}
