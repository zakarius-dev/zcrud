/// Implémentation **web** de `ZFileSaver` — arêtes `package:web` + `dart:js_interop`
/// CONFINÉES à ce fichier conditionnel (comble le trou DODLP : `save_file_web`
/// était un stub VIDE).
///
/// origine: E11b-3 (Axe B, AC6). Déclenche un **téléchargement navigateur** de
/// [bytes] sous [fileName] : Blob (annoté par [mimeType]) → URL objet → ancre
/// `<a download>` cliquée → révocation de l'URL objet (anti-fuite mémoire). Voie
/// web MODERNE : `dart:html` (déprécié) est BANNI → `package:web` + `dart:js_interop`.
/// Purement LOCAL : aucune requête réseau, aucun secret, aucun `badCert` (AD-12).
/// Ces symboles web ne fuient jamais dans la façade neutre `ZFileSaver`.
///
/// NOTE : non exerçable sous `flutter test` (VM Dart) — l'import conditionnel y
/// charge la version io/stub, jamais ce fichier. Couvert par le gate statique
/// (compile analyzer-clean, n'importe que web/js_interop, aucun secret) — AC12.
library;

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'z_file_save_result.dart';

/// Déclenche le téléchargement navigateur de [bytes] sous [fileName]. Défensif :
/// bytes vides → fichier vide valide téléchargé, jamais de crash.
Future<ZFileSaveResult> saveBytes(
  Uint8List bytes, {
  required String fileName,
  String? mimeType,
  String? directoryPath,
}) async {
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
  return ZFileSaveResult(fileName: fileName, path: null, success: true);
}
