/// Base **offline-first bi-topologie** `ZOfflineFirstBoxRepository<T>` (ES-3.2,
/// FR-S13) : implémentation du **point d'extension `persist`** du Template Method
/// `ZStudyRepository<T>` (ES-3.1) — store local **autoritaire**, Firestore
/// **fire-and-forget**, merge **Last-Write-Wins sur `updated_at` HORS-ENTITÉ**,
/// filtrage `hasPendingWrites` des échos locaux, upload de rattrapage local-only,
/// chemins résolus par [ZFirestorePathResolver] (flat / nested / global).
///
/// origine: canonique §7 / AD-9 + les ~15 repositories offline-first quasi
/// identiques de lex_core/lex_data (`study_folders_repository_impl.dart`,
/// `mindmaps_repository_impl.dart`, `study_sharing_repository_impl.dart`) et le
/// CRUD bi-topologie d'IFFD (`firebase_crud_repository_impl.dart`) — **factorisés
/// une fois** et débarrassés du CRUD quasi-réflexif `T.toString()` (banni, AC11).
///
/// ## D1 — étend le Template Method d'ES-3.1 (pas `ZSyncableRepository`)
///
/// `extends ZStudyRepository<T>` (kernel) : `save` (concret, `@nonVirtual`) est
/// **hérité** — il appelle `validate(item)` PUIS, **seulement si `Right`**, le
/// [persist] `@protected` implémenté ici. **On ne re-déclare JAMAIS `save`** (un
/// override casserait la garde métier). Un `validate → Left` **bloque** l'écriture
/// bout-en-bout (aucun `put` local, aucun push Firestore) — AC2.
///
/// ## D2 — COMPOSE la couche E5 (AD-4), n'en duplique rien
///
/// Le store local ([ZLocalStore], défaut `HiveZLocalStore`) est **injecté** : tout
/// le décodage défensif Hive / `_readEntry` / `_softDeleteInBox` vit **là**, pas
/// ici (aucun `Box` brut re-détenu). Ce dépôt **ajoute** par-dessus E5-3 : (1) un
/// **listener temps réel** cross-device (`snapshots(includeMetadataChanges:true)`),
/// (2) le **filtrage `hasPendingWrites`** des échos locaux, (3) le **résolveur
/// bi-topologie**, (4) une **merge-key hors-entité** paramétrable pour les entités
/// **sans `T.updatedAt`** (cas `ZMindmap`).
///
/// ## AD-5/AD-11 — isolation backend
///
/// `cloud_firestore` est importé ici mais **aucun** type Firestore
/// (`CollectionReference`/`Query`/`Timestamp`/`DocumentSnapshot`/`WriteBatch`/
/// `FirebaseException`) ne fuit dans une **signature publique** : toutes restent
/// `ZResult<…>` / `Stream<List<T>>` **nues** / `String`. L'injection d'une
/// instance `FirebaseFirestore` et d'un [ZLocalStore] est la SEULE couture.
///
/// ## AD-9/AD-16/AD-19 — offline-first
///
/// Le **local fait autorité** : lectures et écritures passent d'abord par lui ; le
/// résultat local est renvoyé **dès son succès** (`unawaited` sur la propagation
/// distante — une panne réseau ne casse **jamais** le succès local). Le merge LWW
/// lit `updated_at` **de la méta hors-entité** ([ZSyncMeta]), **jamais** un champ
/// `T.updatedAt` interne (AC6). `is_deleted`/`updated_at` vivent **uniquement**
/// dans l'enveloppe stockée, **jamais** dans le corps métier `toMap` (AC9).
///
/// ## AD-10 + ES-3.0 — décodage cloud CONTEXTUALISÉ
///
/// Le décodage des documents cloud (merge, listener, `sync`) passe par la fonction
/// [decode] **threadée au [ZDecodeContext]** (voie `ZcrudRegistry.decode`) : le
/// slot `extension` **typé** (ex. `ZNoteAudio`) et la provenance `source`
/// **survivent** au round-trip cloud→merge→local (AC8, anti DW-ES14-2). Un
/// document corrompu est **écarté + loggé**, jamais un `throw` (AD-10).
library;

// `prefer_initializing_formals` : FAUX POSITIF (champ privé exposé en paramètre
// nommé — `this._x` interdit par Dart). Désactivé au niveau fichier comme E5-1/2/3.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_firestore_path_resolver.dart';

/// Journal minimal **neutre** (aucune dépendance backend). Un échec distant
/// best-effort, un document corrompu ou une erreur de listener est **loggé** ici
/// avant d'être avalé/écarté — jamais silencieux (AD-10/AD-11). Miroir des logs
/// E5-1/E5-2/E5-3.
typedef ZOfflineFirstBoxLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Base offline-first bi-topologie pour l'agrégat [T].
///
/// **Injection** (aucun singleton — testabilité) :
/// - [local] : le store local **autoritaire** ([ZLocalStore], défaut
///   `HiveZLocalStore`) — source de `_readEntry`/décodage défensif (E5-2) ;
/// - [firestore] : l'instance `FirebaseFirestore` (SEULE couture backend) ;
/// - [resolver] : la table de topologie ([ZFirestorePathResolver]) ;
/// - [kind] : le discriminant de collection (clé de la table de topologie) ;
/// - [decode] : décodage cloud **context-porté** (D7 — `registry.decode`) ;
/// - [encode] : sérialisation du corps métier (sans clés réservées — AD-19) ;
/// - [userId]/[parentId] : contexte de topologie (nested/user-scopé) ;
/// - [isConnected] : couture de connectivité optionnelle (court-circuit `sync`) ;
/// - [logger] : journal neutre optionnel ;
/// - [autoListen] : démarre le listener temps réel à la construction (défaut
///   `true` ; `false` pour piloter la synchro à la main / en test).
class ZOfflineFirstBoxRepository<T extends ZEntity>
    extends ZStudyRepository<T> {
  /// Construit la base offline-first par **composition** du store local et d'un
  /// accès Firestore résolu par [resolver].
  ZOfflineFirstBoxRepository({
    required ZLocalStore<T> local,
    required FirebaseFirestore firestore,
    required ZFirestorePathResolver resolver,
    required String kind,
    required T Function(Map<String, dynamic> map) decode,
    required Map<String, dynamic> Function(T value) encode,
    String? userId,
    String? parentId,
    Future<bool> Function()? isConnected,
    ZOfflineFirstBoxLog? logger,
    bool autoListen = true,
  })  : _local = local,
        _firestore = firestore,
        _resolver = resolver,
        _kind = kind,
        _decode = decode,
        _encode = encode,
        _userId = userId,
        _parentId = parentId,
        _isConnected = isConnected,
        _log = logger ?? _noopLog {
    if (autoListen) _startListener();
  }

  final ZLocalStore<T> _local;
  final FirebaseFirestore _firestore;
  final ZFirestorePathResolver _resolver;
  final String _kind;
  final T Function(Map<String, dynamic> map) _decode;
  final Map<String, dynamic> Function(T value) _encode;
  final String? _userId;
  final String? _parentId;
  final Future<bool> Function()? _isConnected;
  final ZOfflineFirstBoxLog _log;

  /// Clé snake_case de l'identité logique écrite dans le corps (invariant
  /// clé↔corps). Aligné E5-1/E5-2.
  static const String _kId = 'id';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _listenerSub;
  bool _disposed = false;

  // ───────────────────────── Chemins (résolveur bi-topologie) ────────────────

  /// Résout le chemin de collection du [_kind] pour le contexte courant
  /// ([_userId]/[_parentId]). [collectionIdOverride] (le `collectionId?` du port
  /// `persist`, Dev Notes #3) **remplace** le `parentId` (topologie nested) ; il
  /// est **ignoré** par les topologies flat/global (le résolveur ne le lit pas).
  ZResult<String> _collectionPath({String? collectionIdOverride}) =>
      _resolver.resolveCollection(
        kind: _kind,
        userId: _userId,
        parentId: collectionIdOverride ?? _parentId,
      );

  CollectionReference<Map<String, dynamic>> _collection(String path) =>
      _firestore.collection(path);

  /// Énumère les **identifiants des parents** existants au cloud pour ce `kind`
  /// *nested* (ex. les `folderId` de `users/{uid}/study_folders`) — **CR-LEX-10**.
  ///
  /// ## Le problème que cela résout
  ///
  /// Un repository folder-scopé est figé sur **un** `parentId` : son [sync] ne
  /// couvre que ce dossier. Un hôte multi-dossiers devait donc connaître la liste
  /// des dossiers **avant** de construire ses repos — or sa seule source était le
  /// **store local**. La découverte devenait circulaire : sur un appareil **neuf**
  /// (réinstallation, nouveau téléphone, logout/login) le local est vide ⇒ aucun
  /// dossier découvert ⇒ `sync()` ne parcourt rien ⇒ les données cloud ne
  /// redescendent **jamais**. Et comme `sync()` rend `Right(unit)`, le mode
  /// dégradé est **indiscernable** de « l'utilisateur n'a rien » : succès
  /// silencieux, liste vide, données pourtant intactes au cloud.
  ///
  /// Faute de cette API, un hôte devait interroger `FirebaseFirestore`
  /// **lui-même** — perçant l'isolation backend (AD-5/AD-11) pour une opération
  /// qui relève du repository.
  ///
  /// ## Contrat
  ///
  /// Signature **nue** (AD-5) : aucun type `cloud_firestore` n'apparaît.
  /// `Left(ZDomainFailure)` si le `kind` n'est pas *nested* ou si le `userId`
  /// manque ; `Left(ZServerFailure)` sur panne réseau — **jamais** une liste vide
  /// silencieuse, précisément le mode que cette API existe pour éliminer.
  @override
  Future<ZResult<List<String>>> listParentIds() async {
    final resolved =
        _resolver.resolveParentCollection(kind: _kind, userId: _userId);
    final path = resolved.fold<String?>((_) => null, (p) => p);
    if (path == null) {
      return Left<ZFailure, List<String>>(
        resolved.swap().getOrElse(
              () => const ZDomainFailure('chemin parent non résolu'),
            ),
      );
    }
    try {
      final snap = await _collection(path).get();
      return Right<ZFailure, List<String>>(
        <String>[for (final d in snap.docs) d.id],
      );
    } on Object catch (e, s) {
      _log('listParentIds a échoué (kind=$_kind, path=$path)',
          error: e, stackTrace: s);
      return Left<ZFailure, List<String>>(
        ZServerFailure('Énumération des parents impossible : $e'),
      );
    }
  }

  // ───────────────────────── (Dé)codage cloud (D7/D8, AD-10) ─────────────────

  /// Décodage **DÉFENSIF + CONTEXTUALISÉ** (D7/AD-10) d'un document cloud : injecte
  /// l'`id` du document, normalise `updated_at` (Timestamp→ISO) puis décode par la
  /// voie [_decode] **threadée au [ZDecodeContext]** (l'`extension`/`source` typée
  /// survit — AC8). Un document non décodable → `null` (écarté + loggé), jamais un
  /// `throw`.
  T? _decodeCloud(String id, Map<String, dynamic> data) {
    final map = <String, dynamic>{...data, _kId: id};
    _normalizeMetaIso(map);
    try {
      return _decode(map);
    } on Object catch (e, s) {
      _log('document cloud non décodable (kind=$_kind, id=$id) — écarté',
          error: e, stackTrace: s);
      return null;
    }
  }

  /// Normalise en String ISO-8601 **TOUT** horodatage lu au format Firestore
  /// natif (`Timestamp`, `DateTime`, forme sérialisée `{_seconds,_nanoseconds}`)
  /// — **pas seulement** la clé LWW (CR-LEX-8/CR-LEX-9).
  ///
  /// ## Pourquoi systématique, et non une liste de clés déclarée
  ///
  /// Cette normalisation ne traitait auparavant que [ZSyncMeta.kUpdatedAt]. Tout
  /// AUTRE champ porteur d'un `Timestamp` était transmis **brut** à [_decode] :
  /// or les entités `Z*` sont **backend-agnostiques par conception** (AD-16 —
  /// `Timestamp` est confiné à ce package), leur `fromMap` généré ne sait décoder
  /// ni `Timestamp` ni `{_seconds,_nanoseconds}`, et le champ retombait
  /// silencieusement à **`null`**. Un hôte dont la production écrit ses dates en
  /// `Timestamp` natif perdait la date de TOUS ses enregistrements au cutover,
  /// sans erreur ni avertissement.
  ///
  /// Une liste `dateKeys` déclarée par l'hôte aurait été un second inventaire à
  /// tenir juste — et en oublier une clé reproduit exactement la perte. Ici
  /// aucune configuration n'est requise : un `Timestamp` est **sans ambiguïté**
  /// temporel, et le convertir est précisément ce qu'AD-16 exige. Un hôte n'a
  /// aucun usage légitime d'un `Timestamp` brut dans son domaine.
  ///
  /// **Récursif** : un horodatage imbriqué (sous-map / liste) pose le même
  /// problème et est traité de même. **DÉFENSIF (AD-10)** : toute valeur
  /// non-temporelle traverse **intacte**, jamais de `throw`.
  void _normalizeMetaIso(Map<String, dynamic> map) {
    for (final key in map.keys.toList()) {
      map[key] = _normalizeTemporalDeep(map[key]);
    }
  }

  /// Convertit récursivement tout horodatage backend en String ISO-8601.
  /// Retourne la valeur **inchangée** si elle n'est pas temporelle (AD-10).
  Object? _normalizeTemporalDeep(Object? value) {
    // Une String déjà ISO n'est PAS retouchée (idempotence) ; on ne convertit
    // que les formes backend, jamais du texte que l'hôte pourrait avoir voulu.
    if (value is Timestamp || value is DateTime) {
      return _timeFromRaw(value)?.toIso8601String() ?? value;
    }
    if (value is Map) {
      // Forme sérialisée `{_seconds,_nanoseconds}` → horodatage complet.
      if (value['_seconds'] is int) {
        final t = _timeFromRaw(value);
        if (t != null) return t.toIso8601String();
      }
      return <String, dynamic>{
        for (final e in value.entries)
          '${e.key}': _normalizeTemporalDeep(e.value),
      };
    }
    if (value is List) {
      return value.map<Object?>(_normalizeTemporalDeep).toList();
    }
    return value;
  }

  /// Lit un horodatage **tolérant** (AD-10) : `Timestamp` natif, `DateTime`, forme
  /// sérialisée `{_seconds,_nanoseconds}` ou String ISO-8601 → `DateTime` UTC ;
  /// toute autre valeur → `null`. C'est **la** brique de comparaison LWW cloud
  /// brute (D4). Jamais de `throw`.
  DateTime? _timeFromRaw(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    if (value is Map) {
      final seconds = value['_seconds'];
      final nanos = value['_nanoseconds'];
      if (seconds is int) {
        final micros = seconds * Duration.microsecondsPerSecond +
            (nanos is int ? nanos ~/ 1000 : 0);
        return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
      }
    }
    return null;
  }

  /// Construit la map d'écriture cloud : `id` + méta ([isoUpdatedAt]/[isDeleted])
  /// PUIS le corps métier — **stripé de ses clés réservées** ([ZSyncMeta.
  /// stripReserved], AD-19/D8). Le strip est **LOAD-BEARING** : le corps est
  /// épandu **en dernier**, donc sans strip une clé `updated_at`/`is_deleted`
  /// **fuitée** par [_encode] écraserait la méta autoritaire (merge corrompu —
  /// AC9/R3-g). Aucun `Timestamp` brut : `updated_at` reste ISO-8601 (AD-9).
  Map<String, dynamic> _cloudMap({
    required T entity,
    required String id,
    required String? isoUpdatedAt,
    required bool isDeleted,
  }) =>
      <String, dynamic>{
        _kId: id,
        ZSyncMeta.kUpdatedAt: isoUpdatedAt,
        ZSyncMeta.kIsDeleted: isDeleted,
        // Corps métier épandu EN DERNIER, débarrassé des clés réservées : il ne
        // peut donc PAS clobberer la méta ci-dessus (garde AD-19, D8/R3-g).
        ...ZSyncMeta.stripReserved(_encode(entity)),
      };

  // ───────────────────────── D5 — persist offline-first ──────────────────────

  /// Écriture protégée (point d'extension ES-3.1) **offline-first** : (1)
  /// `local.put(item)` — **matérialise l'éphémère** (attribution d'`id` opaque,
  /// AD-14) et réécrit `is_deleted:false`/`updated_at=now` ([ZSyncMeta]) ; (2)
  /// renvoie le **résultat local DÈS son succès** ; (3) pousse au Firestore résolu
  /// en **fire-and-forget** (`unawaited`) — un échec distant est **loggé** puis
  /// **avalé** (AD-9), **jamais** propagé.
  ///
  /// **JAMAIS appelé si `validate → Left`** (garanti par le Template Method `save`
  /// hérité d'ES-3.1) : un rejet métier bloque `put` local ET push (AC2).
  ///
  /// [collectionId] (compat port) **remplace** le `parentId` de topologie nested
  /// (Dev Notes #3) ; ignoré par les topologies flat/global.
  @override
  Future<ZResult<T>> persist(T item, {String? collectionId}) async {
    final localRes = await _local.put(item);
    return localRes.fold(
      (failure) => Left<ZFailure, T>(failure), // échec local : renvoyé tel quel
      (saved) {
        // AD-9 fire-and-forget STRICT : on rend la main DÈS le succès local, sans
        // attendre la propagation distante (`unawaited`). Attendre le push
        // bloquerait `persist` le temps d'un timeout réseau hors-ligne.
        unawaited(_bestEffortPushFresh(saved, collectionId: collectionId));
        return Right<ZFailure, T>(saved);
      },
    );
  }

  /// Pousse [saved] (matérialisé) au Firestore résolu avec une méta **fraîche**
  /// (`updated_at=now`, `is_deleted:false`) — best-effort (échec loggé + avalé).
  Future<void> _bestEffortPushFresh(T saved, {String? collectionId}) async {
    final id = saved.id;
    if (id == null) return; // défensif : put a matérialisé l'id
    final iso = DateTime.now().toUtc().toIso8601String();
    await _bestEffortSet(
      docId: id,
      map: _cloudMap(
          entity: saved, id: id, isoUpdatedAt: iso, isDeleted: false),
      collectionIdOverride: collectionId,
      label: 'persist→push (id=$id)',
    );
  }

  /// Pousse une [entry] (méta **verbatim** — jamais `now()`) au Firestore résolu —
  /// voie d'**upload de rattrapage** (local-only) et de propagation de tombstone.
  Future<void> _bestEffortPushEntry(ZSyncEntry<T> entry) async {
    final id = entry.entity.id;
    if (id == null) return;
    await _bestEffortSet(
      docId: id,
      map: _cloudMap(
        entity: entry.entity,
        id: id,
        isoUpdatedAt: entry.meta.updatedAt?.toIso8601String(),
        isDeleted: entry.meta.isDeleted,
      ),
      collectionIdOverride: null,
      label: 'catch-up→push (id=$id)',
    );
  }

  /// Écriture distante **best-effort** unique : résout le chemin, `set` le doc ;
  /// tout échec (chemin `Left`, `FirebaseException`, exception) est **loggé** puis
  /// **avalé** (AD-9/AD-11) — le local reste autoritaire.
  Future<void> _bestEffortSet({
    required String docId,
    required Map<String, dynamic> map,
    required String? collectionIdOverride,
    required String label,
  }) async {
    final pathRes = _collectionPath(collectionIdOverride: collectionIdOverride);
    await pathRes.fold(
      (failure) async => _log(
          'propagation distante best-effort abandonnée ($label) : chemin non '
          'résolu — ${failure.message}'),
      (path) async {
        try {
          await _collection(path).doc(docId).set(map);
        } on Object catch (e, s) {
          _log('propagation distante best-effort échouée ($label)',
              error: e, stackTrace: s);
        }
      },
    );
  }

  // ───────────────────────── Lectures = LOCAL autoritaire (AD-9) ──────────────

  @override
  Stream<List<T>> watchAll() => _local.watchAll();

  /// Le port [ZLocalStore] n'expose pas de requête filtrée : le [request] n'est
  /// PAS traduit vers le cache (parité E5-3, dette E9). Le flux nu complet est
  /// renvoyé — jamais un `Either` (AD-11).
  @override
  Stream<List<T>> watch(ZDataRequest request) {
    _log('ZOfflineFirstBoxRepository: request non traduit vers le cache '
        '(snapshot local complet) [watch] — dette E9');
    return _local.watchAll();
  }

  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request}) {
    if (request != null) {
      _log('ZOfflineFirstBoxRepository: request non traduit vers le cache '
          '(snapshot local complet) [getAll] — dette E9');
    }
    return _local.getAll();
  }

  @override
  Future<ZResult<T>> getById(String id) => _local.getById(id);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async {
    if (request != null) {
      _log('ZOfflineFirstBoxRepository: request non traduit vers le cache '
          '(snapshot local complet) [count] — dette E9');
    }
    final res = await _local.getAll();
    return res.map((list) => list.length);
  }

  // ───────────────────────── Écritures locales + propagation ──────────────────

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    final localRes = await _local.softDelete(id);
    localRes.fold(
      (_) {},
      (_) => unawaited(_bestEffortPropagateFromLocal(id, 'softDelete→push')),
    );
    return localRes;
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    final localRes = await _local.restore(id);
    localRes.fold(
      (_) {},
      (_) => unawaited(_bestEffortPropagateFromLocal(id, 'restore→push')),
    );
    return localRes;
  }

  /// Relit l'entrée locale [id] (méta incluse) puis la pousse **verbatim** au
  /// distant (best-effort) — propage un soft-delete (tombstone) ou un restore sans
  /// dériver la méta vers `now()`.
  Future<void> _bestEffortPropagateFromLocal(String id, String label) async {
    final entries = await _local.syncEntries();
    await entries.fold(
      (_) async {},
      (list) async {
        for (final e in list) {
          if (e.id == id) {
            await _bestEffortPushEntry(e);
            return;
          }
        }
      },
    );
  }

  // ───────────────────────── D4/D6/D7 — merge LWW + listener ──────────────────

  /// Merge **Last-Write-Wins** cloud→local des [cloudDocs] (`id → corps cloud`).
  ///
  /// Pour chaque doc : décodage **contextualisé + défensif** ([_decodeCloud]) ;
  /// comparaison de `updated_at` **hors-entité** — cloud (`_timeFromRaw`) vs local
  /// (`ZSyncEntry.updatedAt`, méta) ; **adoption** (`local.applyMerged`, verbatim
  /// sans `now()`) **ssi** le cloud est **STRICTEMENT plus récent** OU le local est
  /// absent. Un cloud **sans** horodatage n'écrase **jamais** un local présent.
  /// PUIS **upload de rattrapage** des locaux **non supprimés** absents du cloud.
  ///
  /// Une panne LOCALE (`syncEntries`/`applyMerged` → `Left`) est une **vraie
  /// erreur** propagée (`Left`) ; le cloud reste best-effort (docs corrompus
  /// écartés).
  Future<ZResult<Unit>> _mergeSnapshotWithLocal(
    List<MapEntry<String, Map<String, dynamic>>> cloudDocs,
  ) async {
    final localRes = await _local.syncEntries();
    final localEntries = localRes.fold<List<ZSyncEntry<T>>?>(
      (_) => null,
      (r) => r,
    );
    if (localEntries == null) {
      return localRes.fold(
        (f) => Left<ZFailure, Unit>(f),
        (_) => Right<ZFailure, Unit>(unit), // inatteignable
      );
    }
    final localById = <String, ZSyncEntry<T>>{
      for (final e in localEntries)
        if (e.id != null) e.id!: e,
    };
    final cloudIds = <String>{};

    for (final doc in cloudDocs) {
      final id = doc.key;
      cloudIds.add(id);
      final map = doc.value;
      final entity = _decodeCloud(id, map);
      if (entity == null) continue; // corrompu → écarté + loggé (AD-10)
      // CR-LEX-9 — `ZSyncMeta.fromJson` doit lire le map NORMALISÉ. Construit
      // sur le map brut, `updatedAt` valait `null` quand le cloud portait un
      // `Timestamp` — et c'est ce `null` qui était PERSISTÉ. La clé d'arbitrage
      // LWW retombait donc à vide, exposant les cycles suivants à écraser la
      // version la plus récente par la plus ancienne, silencieusement.
      // `_decodeCloud` normalise une COPIE : la normalisation est refaite ici.
      final normalized = <String, dynamic>{...map};
      _normalizeMetaIso(normalized);
      final cloudMeta = ZSyncMeta.fromJson(normalized);
      final cloudTime = _timeFromRaw(normalized[ZSyncMeta.kUpdatedAt]);
      final localEntry = localById[id];
      final localTime = localEntry?.updatedAt;

      // D4 : adopter SSI local absent OU cloud STRICTEMENT plus récent. La clé
      // est TOUJOURS hors-entité (méta) — jamais un `T.updatedAt` (AC6). ★ R3-c :
      // inverser `isAfter` fait adopter un cloud plus ANCIEN (régression LWW).
      final adopt = localEntry == null ||
          (cloudTime != null &&
              (localTime == null || cloudTime.isAfter(localTime)));
      if (adopt) {
        final applied = await _local
            .applyMerged(ZSyncEntry<T>(entity: entity, meta: cloudMeta));
        final failed = applied.fold<ZFailure?>((f) => f, (_) => null);
        if (failed != null) return Left<ZFailure, Unit>(failed);
      }
    }

    // Upload de rattrapage : entrées local-only, NON supprimées, absentes du cloud
    // (parité lex `_mergeSnapshotWithLocal:541-552`). Best-effort (fire-and-forget).
    for (final e in localEntries) {
      final id = e.id;
      if (id != null && !e.isDeleted && !cloudIds.contains(id)) {
        unawaited(_bestEffortPushEntry(e));
      }
    }
    return Right<ZFailure, Unit>(unit);
  }

  /// Traite un lot de documents cloud issus du **listener temps réel** : **skip**
  /// tout écho local non confirmé serveur ([hasPendingWrites] `== true`, D6/AC7) —
  /// sinon un merge ré-adopterait la donnée que le local vient de produire. Un
  /// snapshot **confirmé** déclenche le merge LWW. Erreur locale de merge → loggée
  /// (le flux ne throw jamais).
  ///
  /// Résolveur de chemin composé — exposé pour la vérification de CÂBLAGE des
  /// fabriques d'assemblage (ex. `buildFolderScopedStudyRepository`) : un test
  /// peut asserter que la fabrique PUBLIQUE a bien câblé `collection`/
  /// `parentCollection` (le swap au site d'appel de la fabrique rougit alors).
  @visibleForTesting
  ZFirestorePathResolver get resolver => _resolver;

  /// Signature **NEUTRE** (`id → corps`) : aucun type Firestore n'y transite
  /// (AD-5) — le listener extrait les `snap.docs` avant l'appel.
  @visibleForTesting
  Future<void> handleCloudSnapshot(
    List<MapEntry<String, Map<String, dynamic>>> cloudDocs, {
    required bool hasPendingWrites,
  }) async {
    if (hasPendingWrites) return; // ★ R3-e : sans ce skip, l'écho local re-merge.
    final res = await _mergeSnapshotWithLocal(cloudDocs);
    res.leftMap((f) => _log('merge listener : panne locale — ${f.message}'));
  }

  /// Démarre le listener temps réel `snapshots(includeMetadataChanges:true)` au
  /// chemin résolu (D6). Le chemin non résolu / une erreur de flux est **loggée**
  /// (jamais un `throw` non géré, parité E5-1). Idempotent (un seul abonnement).
  void _startListener() {
    if (_listenerSub != null) return;
    final pathRes = _collectionPath();
    pathRes.fold(
      (failure) => _log('listener temps réel non démarré (kind=$_kind) : chemin '
          'non résolu — ${failure.message}'),
      (path) {
        try {
          _listenerSub = _collection(path)
              .snapshots(includeMetadataChanges: true)
              .listen(
            (snap) {
              unawaited(handleCloudSnapshot(
                <MapEntry<String, Map<String, dynamic>>>[
                  for (final d in snap.docs) MapEntry(d.id, d.data()),
                ],
                hasPendingWrites: snap.metadata.hasPendingWrites,
              ));
            },
            onError: (Object e, StackTrace s) => _log(
                'listener temps réel en erreur (kind=$_kind)',
                error: e,
                stackTrace: s),
          );
        } on Object catch (e, s) {
          _log('démarrage du listener temps réel en erreur (kind=$_kind)',
              error: e, stackTrace: s);
        }
      },
    );
  }

  // ───────────────────────── AC12 — sync() best-effort one-shot ───────────────

  /// Synchronise **une fois** : pull du snapshot serveur au chemin résolu → merge
  /// LWW cloud→local + upload de rattrapage local-only → `Right(unit)`.
  ///
  /// **`Right(unit)` si déconnecté / panne distante** (AD-9) : `isConnected==false`
  /// court-circuite ; une `FirebaseException` (ou un chemin non résolu) est
  /// assimilée à « offline » → `Right(unit)` (loggé), le local **intact**. Une
  /// **panne LOCALE** de merge reste une vraie erreur → `Left` (jamais avalée).
  /// Le *quand*/débounce multi-dépôts reste ES-3.4.
  @override
  Future<ZResult<Unit>> sync() async {
    final isConnected = _isConnected;
    if (isConnected != null && !await isConnected()) {
      _log('sync: hors-ligne (isConnected=false) — Right(unit) best-effort');
      return Right<ZFailure, Unit>(unit);
    }
    final pathRes = _collectionPath();
    return pathRes.fold(
      (failure) async {
        _log('sync: chemin non résolu — Right(unit) best-effort : '
            '${failure.message}');
        return Right<ZFailure, Unit>(unit);
      },
      (path) async {
        final List<MapEntry<String, Map<String, dynamic>>> docs;
        try {
          final snap = await _collection(path).get();
          docs = <MapEntry<String, Map<String, dynamic>>>[
            for (final d in snap.docs) MapEntry(d.id, d.data()),
          ];
        } on FirebaseException catch (e, s) {
          _log('sync: pull distant en échec, assimilé offline → Right(unit) '
              '(kind=$_kind, code=${e.code})', error: e, stackTrace: s);
          return Right<ZFailure, Unit>(unit);
        } on Object catch (e, s) {
          _log('sync: pull distant en exception, assimilé offline → Right(unit) '
              '(kind=$_kind)', error: e, stackTrace: s);
          return Right<ZFailure, Unit>(unit);
        }
        // Panne LOCALE de merge → Left (vraie erreur) ; sinon Right(unit).
        return _mergeSnapshotWithLocal(docs);
      },
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final sub = _listenerSub;
    _listenerSub = null;
    if (sub != null) unawaited(sub.cancel());
    _local.dispose();
  }
}
