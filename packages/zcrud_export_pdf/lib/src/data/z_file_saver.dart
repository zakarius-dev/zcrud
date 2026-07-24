/// Façade **neutre** cross-platform `ZFileSaver` : écrit des bytes en fichier.
///
/// origine: E11b-3 (Axe B, AC5-8). API 100 % neutre (`Uint8List` + `String`) qui
/// délègue par **imports conditionnels** à l'implémentation adaptée à la
/// plateforme : `dart:io` (mobile/desktop → disque) ou `package:web` +
/// `dart:js_interop` (web → téléchargement navigateur), avec un stub par défaut.
/// AUCUN symbole `dart:io`/`package:web` ne fuit dans cette signature. Purement
/// LOCAL : aucune requête réseau, aucun secret, aucun `badCertificateCallback`
/// (AD-12). `dart:html` (déprécié) est BANNI — la voie web utilise `package:web`.
library;

import 'dart:typed_data';

import 'z_file_save_result.dart';
// Sélection d'implémentation à la compilation : stub par défaut, io si
// `dart.library.io` (VM/mobile/desktop), web si `dart.library.js_interop`.
import 'z_file_saver_stub.dart'
    if (dart.library.io) 'z_file_saver_io.dart'
    if (dart.library.js_interop) 'z_file_saver_web.dart' as impl;

export 'z_file_save_result.dart' show ZFileSaveResult;

/// Sauvegarde de bytes en fichier, **neutre et immuable** (`const`).
///
/// - **io** : écrit sous `<directoryPath>/<fileName>` si [directoryPath] (absolu)
///   est fourni, sinon dans `Directory.systemTemp` ; renvoie le chemin écrit.
/// - **web** : déclenche un téléchargement navigateur des bytes sous [fileName]
///   (Blob + `mimeType` + ancre `download`), sans chemin filesystem.
class ZFileSaver {
  /// Construit le service (sans état ; immuable).
  const ZFileSaver();

  /// Sauvegarde [bytes] sous [fileName]. [mimeType] annote le Blob (web) ;
  /// [directoryPath] (absolu, io uniquement) choisit le dossier cible, créé
  /// récursivement si absent. Défensif (AD-12/AD-10) : bytes vides → fichier vide
  /// valide, jamais de crash.
  Future<ZFileSaveResult> save(
    Uint8List bytes, {
    required String fileName,
    String? mimeType,
    String? directoryPath,
  }) =>
      impl.saveBytes(
        bytes,
        fileName: fileName,
        mimeType: mimeType,
        directoryPath: directoryPath,
      );
}
