/// Adaptateur **Firestore** du port neutre `ZAppFileResolver` (zcrud_core).
///
/// origine (MESURÉ, pas supposé) : DODLP ne persiste PAS d'objets fichier dans
/// ses documents métier, il persiste des **identifiants**. Mesures relevées en
/// lecture seule sur `/home/zakarius/DEV/dodlp-otr` :
///
/// * `ShipHandling.shipDocumentsIds` — `Map<ShipDocumentType, List<String>>`
///   (`lib/modules/bmd/domain/models/ship/ship_handling.dart:92`) et
///   `ShipHandling.bondStorePhotosIds` — `List<String>` (`:59`) : **deux**
///   champs du même patron, tous deux peuplés dans
///   `ship_handlings_screen.dart` avec l'`id` d'un document `AppFile`.
/// * La collection cible est **RACINE** et son nom vient du **repli**
///   `FIREBASE_COLLECTION_NAMES[T] ?? T.toString()`
///   (`lib/modules/data_crud/functions.dart:524`) — `AppFile` n'est PAS dans la
///   table de mapping, donc le nom effectif est la chaîne `'AppFile'`, qui
///   **n'apparaît nulle part en littéral** dans l'app. ⇒ [collectionPath] est
///   **REQUIS** : ce paquet n'invente aucun nom de collection par défaut.
/// * Champs du document (camelCase, `models/app_file.dart:170`) : `id`,
///   `name`, `type` (`AppDocumentType` : pdf/word/excel/powerpoint/image/text),
///   `content`, `contentLength`, `pageCount`, `status` (`AppDocumentStatus` :
///   draft/uploading/uploaded/converting/converted/embedding/embedded),
///   `cloudPath`, `cloudUrl`, `deleted`, `canBeDeleted`, `lastCrudOperation`.
///   **Aucun** champ de taille en octets, **aucun** MIME, **aucun** `createdAt`.
/// * L'app lit ces fichiers par **champ** (`where('id', whereIn: ids)`,
///   `app_file_repository.dart:9`) — et parfois par `cloudUrl` (mêmes ids ou
///   URLs mélangés : `streamFromIdsOrPaths`) — mais supprime par
///   `FieldPath.documentId` (`ship_handlings_screen.dart:210`). Les deux
///   marchent parce que le champ `id` **est** l'id du document.
///   ⇒ [locations] est **paramétrable** et accepte **plusieurs** emplacements
///   essayés dans l'ordre (voir [ZAppFileRefLocation]).
///
/// **Ce que l'adaptateur ferme** : sans résolveur, un champ fichier migré
/// s'affichait **VIDE** sur une donnée existante, sans erreur.
///
/// **Isolation AD-5/AD-16** : aucun type `cloud_firestore` n'apparaît dans une
/// signature publique de ce fichier. La **seule** couture backend (voulue, comme
/// `FirebaseZRepositoryImpl`) est le paramètre `firestore` du constructeur.
/// `Timestamp` / `Filter` / `FirebaseException` / `DocumentSnapshot` ne sortent
/// jamais d'ici : la sortie est une `List<AppFile>` / `ZResult<List<AppFile>>`.
///
/// **AD-10 (défensif partout)** : aucune méthode ne laisse remonter une
/// exception non qualifiée — ni `Error`, ni `Exception` (l'échec **normal**
/// d'une E/S est une `Exception` : un `on Error` seul serait un piège). Un
/// document au champ absent / au type corrompu / à l'enum inconnue produit un
/// **repli**, jamais un `throw`, jamais une résolution qui échoue en entier.
///
/// **AD-15 / FR-26** : aucun gestionnaire d'état, aucune couleur, aucun libellé
/// d'interface. Les seules chaînes produites sont des **messages de diagnostic**
/// de [ZFailure] (même convention que le reste du paquet).
library;

// `prefer_initializing_formals` : FAUX POSITIF (champs privés exposés en
// paramètres nommés — `this._x` interdit par Dart), même convention que
// `firebase_z_repository_impl.dart` / `z_study_codec.dart`.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:zcrud_core/zcrud_core.dart';

/// Nombre **maximal** de valeurs acceptées par un filtre `whereIn` / `in`,
/// **MESURÉ dans la version épinglée** (pas supposé) :
///
/// * `cloud_firestore` **6.7.1** — `lib/src/query.dart:726` :
///   `assert((operator != 'in' && operator != 'array-contains-any') || (value
///   as Iterable).length <= 30, "'in' filters support a maximum of 30 elements
///   in the value [Iterable].")` ;
/// * `fake_cloud_firestore` **4.2.0** — lève une `ArgumentError`
///   « whereIn cannot contain more than 30 comparison values » au-delà (mesuré
///   par sonde exécutée).
///
/// C'est pourquoi une liste de 200 références **doit** être découpée : elle
/// franchit la limite près de 7 fois.
const int kZFirestoreWhereInLimit = 30;

/// Exception portant l'échec **typé** d'une résolution (AD-5 ↔ port).
///
/// Le paquet raisonne en `Either<ZFailure, T>` (AD-5) ; le port
/// [ZAppFileResolver] raisonne, lui, en `Future<List<AppFile>>` **nu** et
/// définit qu'un échec s'exprime par un **`Future` en erreur**. La conciliation
/// est **unique et explicite**, sans troisième convention inventée :
///
/// * [ZFirestoreAppFileResolver.resolveResult] est la voie **canonique** du
///   paquet et rend un [ZResult] ;
/// * [ZFirestoreAppFileResolver.resolve] (l'override du port) **replie** ce
///   `Either` : `Right` → la liste, `Left` → `throw ZAppFileResolveException`.
///
/// L'exception implémente `Exception` (et non `Error`) parce que c'est l'échec
/// **normal** d'une E/S ; le consommateur du cœur rattrape `on Object` et bascule
/// sur son état `échec` réessayable.
class ZAppFileResolveException implements Exception {
  /// Construit l'exception à partir de la [failure] typée du paquet.
  const ZAppFileResolveException(this.failure);

  /// Échec typé sous-jacent (`ZServerFailure` en pratique).
  final ZFailure failure;

  /// Message de diagnostic de la [failure].
  String get message => failure.message;

  @override
  String toString() => 'ZAppFileResolveException(${failure.message})';
}

/// **Où** vit la référence dans le document Firestore.
///
/// Type **neutre** : il ne mentionne aucun type `cloud_firestore` dans sa
/// surface (la traduction vers `FieldPath.documentId` est privée).
///
/// * [ZAppFileRefLocation.documentId] — la référence **est** l'id du document
///   (chemin de suppression mesuré chez DODLP) ;
/// * [ZAppFileRefLocation.field] — la référence est la valeur d'un **champ**
///   (chemin de lecture mesuré chez DODLP : `where('id', whereIn: …)`, et
///   `where('cloudUrl', whereIn: …)` pour des références en forme d'URL).
class ZAppFileRefLocation {
  const ZAppFileRefLocation._(this.fieldName);

  /// La référence est l'**identifiant du document**.
  static const ZAppFileRefLocation documentId = ZAppFileRefLocation._(null);

  /// La référence est la valeur du champ nommé.
  const ZAppFileRefLocation.field(String this.fieldName);

  /// Nom du champ porteur de la référence, ou `null` pour l'id de document.
  final String? fieldName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAppFileRefLocation && fieldName == other.fieldName;

  @override
  int get hashCode => Object.hash(runtimeType, fieldName);

  @override
  String toString() => fieldName == null
      ? 'ZAppFileRefLocation.documentId'
      : 'ZAppFileRefLocation.field($fieldName)';
}

/// Alias de noms de champs consultés par le mapper **par défaut**, dans
/// l'ordre : le **premier** alias présent avec une valeur exploitable gagne.
///
/// Les défauts couvrent la forme canonique zcrud (`snake_case`, cf.
/// `AppFile.toMap`) **et** la forme DODLP **mesurée** (camelCase :
/// `name`/`type`/`status`/`cloudUrl`/`cloudPath`). Rien d'autre n'est deviné :
/// tout hôte au schéma différent passe ses propres alias (ou un
/// [ZAppFileDocumentMapper] complet).
class ZAppFileFieldAliases {
  /// Construit un jeu d'alias (tous les champs ont un défaut).
  const ZAppFileFieldAliases({
    this.name = const <String>['name', 'file_name', 'fileName', 'filename'],
    this.mimeType = const <String>[
      'mime_type',
      'mimeType',
      'content_type',
      'contentType',
    ],
    this.sizeBytes = const <String>['size_bytes', 'sizeBytes', 'sizeInBytes'],
    this.remoteUrl = const <String>[
      'remote_url',
      'remoteUrl',
      // DODLP (mesuré) : URL de téléchargement Storage.
      'cloudUrl',
      'download_url',
      'downloadUrl',
    ],
    this.localPath = const <String>['local_path', 'localPath'],
    this.uploadState = const <String>[
      'upload_state',
      'uploadState',
      // DODLP (mesuré) : `AppDocumentStatus`.
      'status',
    ],
    this.documentType = const <String>[
      'document_type',
      'documentType',
      // DODLP (mesuré) : `AppDocumentType` (pdf/word/excel/…), qui est un type
      // de DOCUMENT, pas un MIME — d'où le mapping vers `documentType` et
      // NON vers `mimeType`.
      'type',
    ],
    this.deleted = const <String>['is_deleted', 'isDeleted', 'deleted'],
  });

  /// Alias de `AppFile.name`.
  final List<String> name;

  /// Alias de `AppFile.mimeType`.
  final List<String> mimeType;

  /// Alias de `AppFile.sizeBytes`.
  ///
  /// ⚠️ Volontairement **sans** équivalent DODLP : le champ `contentLength`
  /// mesuré là-bas est la longueur du **texte extrait**, pas une taille en
  /// octets. L'assimiler serait inventer une convention.
  final List<String> sizeBytes;

  /// Alias de `AppFile.remoteUrl`.
  final List<String> remoteUrl;

  /// Alias de `AppFile.localPath`.
  ///
  /// ⚠️ `cloudPath` (DODLP) n'y figure **pas** : c'est un chemin **Storage
  /// distant**, pas un chemin local. Il est préservé dans `AppFile.extra`.
  final List<String> localPath;

  /// Alias de l'état d'upload.
  final List<String> uploadState;

  /// Alias de `AppFile.documentType`.
  final List<String> documentType;

  /// Alias du drapeau de **soft-delete** (cf.
  /// [ZFirestoreAppFileResolver.skipDeleted]).
  final List<String> deleted;

  /// Ensemble de **toutes** les clés consommées (pour le calcul de `extra`).
  Set<String> get allKeys => <String>{
        ...name,
        ...mimeType,
        ...sizeBytes,
        ...remoteUrl,
        ...localPath,
        ...uploadState,
        ...documentType,
        ...deleted,
      };
}

/// Traduit un document brut en [AppFile], ou `null` pour déclarer la référence
/// **introuvable**.
///
/// [ref] est la référence demandée ; l'implémentation **doit** poser
/// `AppFile.id == ref` (le résolveur le refait de toute façon, contrat du port).
/// [data] est le corps brut du document (déjà purgé des types backend :
/// voir `ZFirestoreAppFileResolver` — les `Timestamp` éventuels y sont
/// normalisés en ISO-8601 `String`).
typedef ZAppFileDocumentMapper = AppFile? Function(
  String ref,
  Map<String, dynamic> data,
);

/// Journal optionnel du résolveur (diagnostic ; jamais de libellé d'interface).
typedef ZAppFileResolverLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Découpe [refs] en paquets d'au plus [size] éléments.
///
/// Extrait et `@visibleForTesting` **exprès** : le découpage est la propriété
/// que la limite `whereIn` rend obligatoire, il doit être mesurable
/// directement — pas seulement de biais par un bout-en-bout.
@visibleForTesting
List<List<String>> zChunkAppFileRefs(List<String> refs, int size) {
  if (size < 1) {
    throw ArgumentError.value(size, 'size', 'doit être >= 1');
  }
  final out = <List<String>>[];
  for (var i = 0; i < refs.length; i += size) {
    out.add(refs.sublist(i, i + size > refs.length ? refs.length : i + size));
  }
  return out;
}

/// Résolveur Firestore de références opaques de fichiers.
///
/// ## Règles de sortie (contrat, gardées)
///
/// | Situation | Résultat |
/// |---|---|
/// | référence résolue | un [AppFile] avec `id == ref` |
/// | référence **sans document** | **absente** du retour (⇒ « introuvable » visible côté rendu) — jamais une exception, jamais un objet fabriqué |
/// | référence **vide** (`''`) | absente du retour, **sans** requête émise (`whereIn` refuse le vide) |
/// | référence **en double** | **une seule** requête, **un seul** [AppFile] dans le retour (dédoublonnage sur la première occurrence) |
/// | **ordre** | le retour suit l'ordre de **première apparition** dans `refs`. Le port déclare l'ordre indifférent ; on rend malgré tout un ordre **déterministe** — un hôte qui affiche la liste telle quelle retrouve son ordre |
/// | `refs` vide | `[]` immédiat, **aucune** requête |
/// | **échec réseau** (une seule requête qui échoue) | échec **global** : `Left(ZServerFailure)` / `ZAppFileResolveException`. **Jamais** une liste partielle : un paquet perdu ferait passer ses références pour « introuvables », c'est-à-dire un **mensonge** silencieux là où l'utilisateur doit voir un état réessayable |
/// | `Future` qui ne se termine **jamais** | tranché par [timeout] ⇒ même échec global |
/// | document au corps **corrompu** | l'[AppFile] est produit quand même (le document **existe**) avec des replis sûrs ; jamais un `throw`, jamais un échec du lot |
/// | document **soft-deleted** | traité comme **introuvable** si [skipDeleted] (défaut) |
///
/// ## Isolation
///
/// Aucun type `cloud_firestore` ne franchit la frontière : `Timestamp` est
/// normalisé en `String` ISO-8601 **avant** d'atteindre le mapper, et
/// `FirebaseException` est convertie en [ZServerFailure].
class ZFirestoreAppFileResolver extends ZAppFileResolver {
  /// Construit le résolveur.
  ///
  /// - [firestore] : **seule** couture backend (même convention que
  ///   `FirebaseZRepositoryImpl`).
  /// - [collectionPath] : chemin de la collection des documents fichier.
  ///   **Requis, sans défaut** — le nom effectif chez DODLP (`'AppFile'`) est
  ///   produit par un repli `T.toString()` et n'existe en littéral nulle part :
  ///   le coder ici serait inventer une convention.
  /// - [locations] : emplacements de la référence, essayés **dans l'ordre** ;
  ///   chaque emplacement ne requête que les références **encore** non
  ///   résolues. Défaut : `[ZAppFileRefLocation.documentId]`.
  /// - [aliases] : noms de champs consultés par le mapper par défaut.
  /// - [mapper] : mapper **complet** de remplacement. S'il lève, on **replie**
  ///   sur le mapper par défaut (AD-10) ; s'il rend `null`, la référence est
  ///   déclarée introuvable.
  /// - [uploadStateMapper] : mapping de **valeur** de l'état d'upload
  ///   (confinement AD-27 : la connaissance des valeurs legacy vit dans
  ///   l'adaptateur, jamais dans le domaine). Défaut :
  ///   [mapDodlpDocumentStatus].
  /// - [batchSize] : taille de paquet, bornée à [kZFirestoreWhereInLimit].
  /// - [skipDeleted] : un document dont un alias [ZAppFileFieldAliases.deleted]
  ///   vaut **exactement** `true` est traité comme introuvable. Noter la
  ///   différence **délibérée** avec `FirebaseZRepositoryImpl._isVisible`
  ///   (`is_deleted == false`) : ici un drapeau **absent** garde le document,
  ///   parce que la collection fichier d'un hôte n'est pas forcément
  ///   zcrud-native (DODLP écrit `deleted`, pas `is_deleted`).
  /// - [resolveTimeout] : surcharge du [timeout] du port (défaut : celui du
  ///   port, 15 s). Appliqué **ici aussi** — le port dit que le consommateur le
  ///   pose, l'adaptateur ne s'en remet pas à lui pour ne jamais pendre.
  /// - [onBatch] : observateur de test des paquets réellement émis.
  ZFirestoreAppFileResolver({
    required FirebaseFirestore firestore,
    required String collectionPath,
    List<ZAppFileRefLocation> locations = const <ZAppFileRefLocation>[
      ZAppFileRefLocation.documentId,
    ],
    ZAppFileFieldAliases aliases = const ZAppFileFieldAliases(),
    ZAppFileDocumentMapper? mapper,
    String Function(Object? raw)? uploadStateMapper,
    int batchSize = kZFirestoreWhereInLimit,
    bool skipDeleted = true,
    Duration? resolveTimeout,
    ZAppFileResolverLog? logger,
    void Function(List<String> batch)? onBatch,
  })  : assert(collectionPath.isNotEmpty, 'collectionPath ne peut être vide'),
        assert(locations.isNotEmpty, 'au moins un emplacement de référence'),
        assert(
          batchSize >= 1 && batchSize <= kZFirestoreWhereInLimit,
          'batchSize doit tenir dans [1, $kZFirestoreWhereInLimit]',
        ),
        _firestore = firestore,
        _collectionPath = collectionPath,
        _locations = List<ZAppFileRefLocation>.unmodifiable(locations),
        _aliases = aliases,
        _mapper = mapper,
        _uploadStateMapper = uploadStateMapper ?? mapDodlpDocumentStatus,
        _batchSize = batchSize,
        _skipDeleted = skipDeleted,
        _timeout = resolveTimeout,
        _log = logger ?? _noopLog,
        _onBatch = onBatch;

  final FirebaseFirestore _firestore;
  final String _collectionPath;
  final List<ZAppFileRefLocation> _locations;
  final ZAppFileFieldAliases _aliases;
  final ZAppFileDocumentMapper? _mapper;
  final String Function(Object? raw) _uploadStateMapper;
  final int _batchSize;
  final bool _skipDeleted;
  final Duration? _timeout;
  final ZAppFileResolverLog _log;
  final void Function(List<String> batch)? _onBatch;

  @override
  Duration get timeout => _timeout ?? super.timeout;

  /// Voie du **port** : `Future<List<AppFile>>` nu. Replie [resolveResult].
  ///
  /// `Left` ⇒ `throw ZAppFileResolveException` (le canal d'échec **défini** par
  /// le port : un `Future` en erreur).
  @override
  Future<List<AppFile>> resolve(List<String> refs) async {
    final result = await resolveResult(refs);
    return result.fold(
      (f) => throw ZAppFileResolveException(f),
      (files) => files,
    );
  }

  /// Voie **canonique du paquet** (AD-5) : `Either<ZFailure, List<AppFile>>`.
  ///
  /// N'échoue **jamais** par exception : toute erreur (y compris un `Error`,
  /// y compris un `throw` synchrone) devient un `Left`.
  Future<ZResult<List<AppFile>>> resolveResult(List<String> refs) async {
    try {
      return await _resolve(refs).timeout(
        timeout,
        onTimeout: () => Left<ZFailure, List<AppFile>>(
          ZServerFailure(
            'app file resolution timed out after ${timeout.inMilliseconds}ms',
          ),
        ),
      );
    } on FirebaseException catch (e, s) {
      _log('FirebaseException (code=${e.code})', error: e, stackTrace: s);
      return Left<ZFailure, List<AppFile>>(ZServerFailure(e.message ?? e.code));
    } on ZFailure catch (f) {
      return Left<ZFailure, List<AppFile>>(f);
    } on Object catch (e, s) {
      // `on Object` DÉLIBÉRÉ : un `on Error` seul laisserait remonter les
      // `Exception`, c'est-à-dire l'échec NORMAL d'une E/S.
      _log('erreur inattendue de résolution', error: e, stackTrace: s);
      return Left<ZFailure, List<AppFile>>(ZServerFailure(e.toString()));
    }
  }

  // ───────────────────────────── Résolution ────────────────────────────────

  Future<ZResult<List<AppFile>>> _resolve(List<String> refs) async {
    // Dédoublonnage + rejet des références vides, ordre de PREMIÈRE apparition.
    final ordered = <String>[];
    final wanted = <String>{};
    for (final ref in refs) {
      if (ref.isEmpty) continue;
      if (wanted.add(ref)) ordered.add(ref);
    }
    if (ordered.isEmpty) {
      return const Right<ZFailure, List<AppFile>>(<AppFile>[]);
    }

    final byRef = <String, AppFile>{};
    var pending = ordered;

    for (final location in _locations) {
      if (pending.isEmpty) break;
      for (final chunk in zChunkAppFileRefs(pending, _batchSize)) {
        _onBatch?.call(chunk);
        final snapshot = await _query(location, chunk).get();
        for (final doc in snapshot.docs) {
          final data = _sanitize(doc.data());
          final ref = _refOfDocument(location, doc.id, data);
          if (ref == null || !wanted.contains(ref)) continue;
          if (byRef.containsKey(ref)) continue;
          if (_skipDeleted && _isDeleted(data)) continue;
          final file = _decode(ref, data);
          if (file != null) byRef[ref] = file;
        }
      }
      pending = <String>[
        for (final ref in pending)
          if (!byRef.containsKey(ref)) ref,
      ];
    }

    return Right<ZFailure, List<AppFile>>(<AppFile>[
      for (final ref in ordered)
        if (byRef[ref] case final AppFile file) file,
    ]);
  }

  Query<Map<String, dynamic>> _query(
    ZAppFileRefLocation location,
    List<String> chunk,
  ) {
    final collection = _firestore.collection(_collectionPath);
    final field = location.fieldName;
    if (field == null) {
      return collection.where(FieldPath.documentId, whereIn: chunk);
    }
    return collection.where(field, whereIn: chunk);
  }

  String? _refOfDocument(
    ZAppFileRefLocation location,
    String documentId,
    Map<String, dynamic> data,
  ) {
    final field = location.fieldName;
    if (field == null) return documentId;
    final raw = data[field];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  bool _isDeleted(Map<String, dynamic> data) {
    for (final key in _aliases.deleted) {
      // `== true` STRICT : un drapeau absent, `null`, ou d'un autre type ne
      // supprime rien (défensif AD-10 — cf. dartdoc de `skipDeleted`).
      if (data[key] == true) return true;
    }
    return false;
  }

  /// Décodage **défensif** : le mapper injecté peut lever ou rendre `null` ;
  /// on ne laisse jamais cela casser le lot.
  AppFile? _decode(String ref, Map<String, dynamic> data) {
    final custom = _mapper;
    if (custom != null) {
      try {
        final mapped = custom(ref, data);
        // Contrat du port : `AppFile.id` DOIT être exactement la référence.
        return mapped == null ? null : _forceId(mapped, ref);
      } on Object catch (e, s) {
        _log('mapper hôte en erreur — repli par défaut', error: e, stackTrace: s);
      }
    }
    return _defaultMap(ref, data);
  }

  AppFile _forceId(AppFile file, String ref) =>
      file.id == ref ? file : file.copyWith(id: ref);

  /// Mapper **par défaut** — total (ne rend jamais `null`, ne lève jamais).
  ///
  /// Un document qui **existe** produit un [AppFile], même si tous ses champs
  /// sont absents ou corrompus : sinon un corps illisible se déguiserait en
  /// « introuvable », c'est-à-dire exactement le silence que ce lot ferme.
  AppFile _defaultMap(String ref, Map<String, dynamic> data) {
    final remoteUrl = _pickString(data, _aliases.remoteUrl);
    final rawState = _pickRaw(data, _aliases.uploadState);
    final mappedState = rawState == null ? null : _uploadStateMapper(rawState);
    final consumed = _aliases.allKeys;
    final extra = <String, dynamic>{
      for (final entry in data.entries)
        if (!consumed.contains(entry.key) && entry.key != 'id')
          entry.key: entry.value,
    };
    return AppFile(
      id: ref,
      name: _pickString(data, _aliases.name) ?? '',
      mimeType: _pickString(data, _aliases.mimeType),
      sizeBytes: _pickInt(data, _aliases.sizeBytes),
      remoteUrl: remoteUrl,
      localPath: _pickString(data, _aliases.localPath),
      uploadState: mappedState != null
          ? ZAppFileUploadState.fromName(mappedState)
          // Repli SANS état persisté : une URL distante ⇒ le transfert a eu
          // lieu ; sinon l'état sûr du domaine (`pending`).
          : (remoteUrl != null && remoteUrl.isNotEmpty
              ? ZAppFileUploadState.uploaded
              : ZAppFileUploadState.pending),
      documentType: _pickString(data, _aliases.documentType),
      extra: extra.isEmpty ? null : extra,
    );
  }

  // ──────────────────────── Lecture défensive de champs ────────────────────

  Object? _pickRaw(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v != null) return v;
    }
    return null;
  }

  String? _pickString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  int? _pickInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final v = data[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  /// Purge **tous** les types `cloud_firestore` du corps avant qu'il n'atteigne
  /// le mapper (AD-16 : aucun type backend hors de l'adaptateur).
  ///
  /// `Timestamp` → ISO-8601 UTC ; `DocumentReference` → son `path` ;
  /// `GeoPoint` → `{latitude, longitude}` ; récursif sur `Map`/`List`.
  Map<String, dynamic> _sanitize(Map<String, dynamic>? data) {
    if (data == null) return <String, dynamic>{};
    return <String, dynamic>{
      for (final entry in data.entries) entry.key: _sanitizeValue(entry.value),
    };
  }

  Object? _sanitizeValue(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DocumentReference) return value.path;
    if (value is GeoPoint) {
      return <String, dynamic>{
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries) '${e.key}': _sanitizeValue(e.value),
      };
    }
    if (value is Iterable) {
      return <dynamic>[for (final e in value) _sanitizeValue(e)];
    }
    return value;
  }

  /// Mapping de **valeur** `AppDocumentStatus` (DODLP, 7 valeurs mesurées) →
  /// `ZAppFileUploadState` (4 valeurs).
  ///
  /// Confinement AD-27 : la connaissance des valeurs legacy vit **ici**, jamais
  /// dans le domaine. Défensif (AD-10) : une valeur inconnue rend une chaîne
  /// inconnue, que `ZAppFileUploadState.fromName` replie sur `pending`.
  ///
  /// | legacy | canonique |
  /// |---|---|
  /// | `draft` | `pending` |
  /// | `uploading` | `uploading` |
  /// | `uploaded`, `converting`, `converted`, `embedding`, `embedded` | `uploaded` |
  /// | `failed` | `failed` |
  static String mapDodlpDocumentStatus(Object? raw) {
    if (raw is! String) return '';
    switch (raw) {
      case 'draft':
      case 'pending':
        return ZAppFileUploadState.pending.name;
      case 'uploading':
        return ZAppFileUploadState.uploading.name;
      case 'uploaded':
      case 'converting':
      case 'converted':
      case 'embedding':
      case 'embedded':
        return ZAppFileUploadState.uploaded.name;
      case 'failed':
        return ZAppFileUploadState.failed.name;
      default:
        return raw;
    }
  }
}
