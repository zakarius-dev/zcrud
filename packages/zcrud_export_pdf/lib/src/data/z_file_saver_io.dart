/// Implémentation **io** de `ZFileSaver` (mobile/desktop/VM) — arête `dart:io`
/// CONFINÉE à ce fichier conditionnel.
///
/// origine: E11b-3 (Axe B, AC7). Écrit [bytes] sur disque : sous
/// `<directoryPath>/<fileName>` si [directoryPath] (absolu) est fourni, sinon
/// dans `Directory.systemTemp` (la sélection d'un dossier applicatif reste HORS
/// package — pas de `path_provider`). Répertoire créé récursivement si absent.
/// Purement LOCAL : aucune requête réseau, aucun secret, aucun `badCert` (AD-12).
/// `dart:io` ne fuit jamais dans la façade neutre `ZFileSaver`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'z_file_save_result.dart';

/// Écrit [bytes] en fichier et renvoie le chemin absolu écrit. Défensif : bytes
/// vides → fichier vide valide ; répertoire créé (`recursive`) si absent.
Future<ZFileSaveResult> saveBytes(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  String? directoryPath,
}) async {
  final dir = directoryPath != null && directoryPath.isNotEmpty
      ? Directory(directoryPath)
      : Directory.systemTemp;
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final path = '${dir.path}${Platform.pathSeparator}$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return ZFileSaveResult(fileName: fileName, path: path, success: true);
}
