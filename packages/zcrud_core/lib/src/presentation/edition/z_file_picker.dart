/// `ZFilePicker` — **seam d'acquisition de fichier** injecté (E3-3c).
///
/// Interface **pure** (aucune dépendance lourde) : le cœur définit le contrat
/// d'acquisition, l'impl concrète (image_picker/file_picker/scan/caméra) vit
/// dans l'app/le binding (**E7**), **jamais** dans `zcrud_core` (AD-1 : cœur
/// OUT=0, aucune dépendance lourde). Injecté via `ZcrudScope.filePicker` (défaut
/// `null` ⇒ actions désactivées proprement, aucun crash).
///
/// **Contrat** : [pick] retourne des [AppFile] en [ZAppFileUploadState.pending]
/// avec métadonnées + `localPath` — **jamais des octets** (AD-2 : la tranche
/// reste légère ; le transport binaire est la responsabilité de l'impl
/// picker/storage). En test, un **fake** renvoie un [AppFile] déterministe.
library;

import '../../domain/edition/app_file.dart';
import '../../domain/edition/z_field_config.dart';

/// Seam d'acquisition de fichiers/images/documents (injecté, jamais un
/// singleton statique — AD-6).
abstract class ZFilePicker {
  /// Acquiert un ou plusieurs fichiers depuis la [source] demandée, contraint
  /// par [config] (extensions/mime/tailles). Retourne des [AppFile]
  /// [ZAppFileUploadState.pending] avec `localPath` (**pas d'octets**). Liste
  /// vide si l'utilisateur annule.
  Future<List<AppFile>> pick({
    required ZFileSource source,
    required FileFieldConfig config,
  });
}
