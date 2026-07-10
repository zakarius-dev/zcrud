/// `AppFile` — **value object de référence de fichier** (E3-3c, parité DODLP
/// SM-2) + enum d'état d'upload [ZAppFileUploadState].
///
/// origine: `AppFile` DODLP (`models/app_file.dart`, couplé au singleton +
/// Firestore + `cloudPath` métier). E3-3c le **découple** : pur-Dart (couche
/// `domain`, aucune dépendance Flutter/Firebase — garde `domain_purity_test`),
/// **sans bytes** (aucun `Uint8List`) et sans chemin cloud métier (le transport
/// binaire + le `cloudPath` sont la responsabilité de l'impl picker/storage —
/// E5/E7).
///
/// **INVARIANT AD-2 (tranche légère)** : `AppFile` porte une **référence**
/// (id/nom/mime/taille/URL distante/chemin local/état d'upload), **jamais** les
/// octets du fichier — la tranche de formulaire reste légère.
///
/// **INVARIANT AD-10 (désérialisation défensive)** : [AppFile.fromMap] ne
/// **casse jamais** sur un champ absent/corrompu (défaut sûr, `upload_state`
/// inconnu → repli [ZAppFileUploadState.pending], jamais un `throw`).
library;

/// État d'upload d'un [AppFile] (E3-3c, canonique §5 — valeurs **camelCase**).
///
/// L'état vit **dans** [AppFile] (une seule voie de vérité de l'état du
/// fichier). Discipline défensive (AD-10) : une valeur inconnue à la
/// désérialisation retombe sur [pending] via [ZAppFileUploadState.fromName],
/// jamais un `throw`.
enum ZAppFileUploadState {
  /// Fichier **local**, pas encore uploadé (défaut sûr / repli défensif).
  pending,

  /// Upload **en cours** (transport binaire délégué à l'impl storage — E5).
  uploading,

  /// Upload **terminé** : une URL distante ([AppFile.remoteUrl]) est disponible.
  uploaded,

  /// Upload **échoué** (réessayable — reflété accessible par le widget).
  failed;

  /// Résout un état depuis sa représentation persistée (nom camelCase), avec
  /// **repli défensif** sur [pending] si absent/inconnu (AD-10 : jamais un
  /// `throw`).
  static ZAppFileUploadState fromName(Object? raw) {
    if (raw is String) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
    }
    return pending;
  }
}

/// Référence **sérialisable** vers un fichier (image/document) — value object
/// pur-Dart **sans octets** (AD-2). Ce n'est **PAS** un `ZEntity` : pas de
/// soft-delete / `ZSyncMeta` / matérialisation d'`id` (value object simple).
class AppFile {
  /// Construit une référence de fichier.
  ///
  /// [uploadState] par défaut [ZAppFileUploadState.pending] (fichier local
  /// fraîchement acquis). Tous les autres champs sont optionnels.
  const AppFile({
    this.id,
    this.name = '',
    this.mimeType,
    this.sizeBytes,
    this.remoteUrl,
    this.localPath,
    this.uploadState = ZAppFileUploadState.pending,
    this.progress,
    this.documentType,
    this.extra,
  });

  /// Identité opaque (`null` pour un fichier local non encore persisté).
  final String? id;

  /// Nom de fichier lisible (jamais `null` ; `''` si inconnu).
  final String name;

  /// Type MIME / content-type (`image/png`, `application/pdf`…), si connu.
  final String? mimeType;

  /// Taille en octets, si connue.
  final int? sizeBytes;

  /// URL distante — renseignée **après** upload ([ZAppFileUploadState.uploaded]).
  final String? remoteUrl;

  /// Chemin/URI local **pré-upload** (fourni par le picker ; jamais des octets).
  final String? localPath;

  /// État d'upload courant (une seule voie de vérité — AD-2).
  final ZAppFileUploadState uploadState;

  /// Progression d'upload optionnelle `0..1` (`null` si non suivie).
  final double? progress;

  /// Type de document **ouvert** (parité `AppDocumentType` DODLP — valeur
  /// ouverte, AD-4/AD-10 ; jamais un `enum` fermé inter-package).
  final String? documentType;

  /// Sac d'extension additif (AD-4) — données hôte non modélisées.
  final Map<String, dynamic>? extra;

  /// `true` si le fichier référence une **image** (préviz `Image.network`
  /// possible une fois uploadé) — dérivé du [mimeType].
  bool get isImage => mimeType != null && mimeType!.startsWith('image/');

  /// Copie en surchargeant les champs fournis.
  ///
  /// **Convention** (documentée — pas de sentinelle ici) : un argument `null`
  /// **conserve** la valeur courante (`?? this.x`). Pour effacer un champ
  /// (p. ex. repasser `remoteUrl` à `null`), construire un nouvel [AppFile].
  AppFile copyWith({
    String? id,
    String? name,
    String? mimeType,
    int? sizeBytes,
    String? remoteUrl,
    String? localPath,
    ZAppFileUploadState? uploadState,
    double? progress,
    String? documentType,
    Map<String, dynamic>? extra,
  }) =>
      AppFile(
        id: id ?? this.id,
        name: name ?? this.name,
        mimeType: mimeType ?? this.mimeType,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        remoteUrl: remoteUrl ?? this.remoteUrl,
        localPath: localPath ?? this.localPath,
        uploadState: uploadState ?? this.uploadState,
        progress: progress ?? this.progress,
        documentType: documentType ?? this.documentType,
        extra: extra ?? this.extra,
      );

  /// Projette vers une `Map` **persistable** (clés snake_case — AD-3 ;
  /// `upload_state` = nom d'enum camelCase). N'émet **jamais** d'octets.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'remote_url': remoteUrl,
        'local_path': localPath,
        'upload_state': uploadState.name,
        'progress': progress,
        'document_type': documentType,
        'extra': extra,
      };

  /// Reconstruit un [AppFile] depuis une `Map` **défensivement** (AD-10) : un
  /// champ absent/corrompu retombe sur un défaut sûr, `upload_state` inconnu →
  /// [ZAppFileUploadState.pending], **jamais un `throw`**.
  factory AppFile.fromMap(Map<String, dynamic> map) => AppFile(
        id: _asString(map['id']),
        name: _asString(map['name']) ?? '',
        mimeType: _asString(map['mime_type']),
        sizeBytes: _asInt(map['size_bytes']),
        remoteUrl: _asString(map['remote_url']),
        localPath: _asString(map['local_path']),
        uploadState: ZAppFileUploadState.fromName(map['upload_state']),
        progress: _asDouble(map['progress']),
        documentType: _asString(map['document_type']),
        extra: _asStringMap(map['extra']),
      );

  static String? _asString(Object? v) => v is String ? v : null;

  static int? _asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDouble(Object? v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static Map<String, dynamic>? _asStringMap(Object? v) {
    if (v is Map) {
      return <String, dynamic>{
        for (final e in v.entries) '${e.key}': e.value,
      };
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          mimeType == other.mimeType &&
          sizeBytes == other.sizeBytes &&
          remoteUrl == other.remoteUrl &&
          localPath == other.localPath &&
          uploadState == other.uploadState &&
          progress == other.progress &&
          documentType == other.documentType &&
          _mapEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        name,
        mimeType,
        sizeBytes,
        remoteUrl,
        localPath,
        uploadState,
        progress,
        documentType,
        extra == null ? null : Object.hashAll(extra!.entries.map((e) => '${e.key}=${e.value}')),
      );

  @override
  String toString() =>
      'AppFile(name: $name, uploadState: ${uploadState.name}, '
      'remoteUrl: $remoteUrl)';
}

/// Égalité **profonde** (clé→valeur) de deux `Map` nullables — pur-Dart (évite
/// `package:collection`, AD-1 out-degree 0).
bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}
