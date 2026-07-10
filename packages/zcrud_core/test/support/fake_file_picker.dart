// Fake `ZFilePicker` (E3-3c) — renvoie des `AppFile` déterministes en
// `pending` + `localPath`, SANS aucune dépendance lourde (pas d'image_picker/
// file_picker). Trace la dernière source demandée.
import 'package:zcrud_core/zcrud_core.dart';

/// Fake déterministe du seam d'acquisition (aucune dépendance lourde).
class FakeFilePicker implements ZFilePicker {
  FakeFilePicker(this.result);

  /// Fichiers retournés à chaque [pick] (déterministe).
  List<AppFile> result;

  /// Dernière source demandée (oracle de test des boutons d'action).
  ZFileSource? lastSource;

  /// Nombre d'appels à [pick].
  int pickCount = 0;

  @override
  Future<List<AppFile>> pick({
    required ZFileSource source,
    required FileFieldConfig config,
  }) async {
    pickCount++;
    lastSource = source;
    return result;
  }
}

/// Fabrique un `AppFile` local `pending` déterministe (image par défaut).
AppFile fakePendingFile({
  String name = 'photo.png',
  String mime = 'image/png',
  String path = '/tmp/photo.png',
}) =>
    AppFile(
      name: name,
      mimeType: mime,
      localPath: path,
      uploadState: ZAppFileUploadState.pending,
    );
