/// Implémentation **stub** par défaut de `ZFileSaver` (plateforme sans `dart:io`
/// ni `dart:js_interop`).
///
/// origine: E11b-3 (Axe B). Chargée uniquement quand NI `dart.library.io` NI
/// `dart.library.js_interop` ne sont disponibles (cas théorique). N'importe
/// AUCUN symbole plateforme, aucun secret. Signale l'absence de support plutôt
/// que d'écrire silencieusement dans le vide.
library;

import 'dart:typed_data';

import 'z_file_save_result.dart';

/// Contrat commun des implémentations conditionnelles : écrit [bytes] et renvoie
/// un [ZFileSaveResult]. Le stub lève `UnsupportedError` (aucune plateforme de
/// stockage disponible).
Future<ZFileSaveResult> saveBytes(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  String? directoryPath,
}) {
  throw UnsupportedError(
    'ZFileSaver : aucune plateforme de stockage disponible '
    '(ni dart:io ni dart:js_interop). Aucun secret, aucune écriture effectuée.',
  );
}
