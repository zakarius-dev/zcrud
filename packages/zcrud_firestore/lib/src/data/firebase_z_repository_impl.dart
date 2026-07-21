/// Adaptateur **Firestore** concret du port neutre `ZRepository<T>` (E5-1).
///
/// origine: lex_core (module « Étude ») — repositories Firestore
/// (`StudyFoldersRepository`/`FlashcardsRepository`/…) généralisés. Réunit les
/// **corrections** des 3 bugs historiques des apps (DODLP/IFFD/DLCFTI) :
/// réassignation de clause perdue, `catch(_){}` silencieux, `null` traité comme
/// erreur, écritures partielles non committées.
///
/// **Isolation AD-5 (CRUCIAL)** : `cloud_firestore` est importé **uniquement**
/// ici. Aucun type Firestore (`Query`/`Timestamp`/`DocumentSnapshot`/
/// `CollectionReference`/`FirebaseException`/`Filter`) ne fuit dans une
/// **signature publique** — toutes restent `ZResult<…>` / `Stream<List<T>>`
/// **nues**. Les dates transitent en **ISO-8601 String** (jamais `Timestamp`).
///
/// **Frontières de story (ne PAS déborder)** : E5-1 = repo Firestore + traduction
/// `ZDataRequest→Query` + curseur + soft-delete/restore + count + décodage
/// défensif. Le `ZLocalStore` (Hive), l'offline-first LWW et l'orchestrateur
/// sont E5-2/E5-3/E5-4.
library;

// `prefer_initializing_formals` est un FAUX POSITIF ici : les champs de config
// sont **privés** et exposés en paramètres **nommés**. Or Dart interdit un
// formal d'initialisation nommé privé (`this._x` n'est pas appelable comme
// paramètre nommé `_x`) — l'assignation en liste d'initialisation est donc la
// SEULE forme possible. La suggestion du lint est inapplicable ; on la désactive
// au niveau fichier pour garder `analyze` à zéro info (gate melos fatal-infos).
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Journal minimal **neutre** de l'adaptateur (type public sans dépendance
/// Firestore). Un document non décodable ou une erreur de flux est **loggé** ici
/// puis écarté (AD-10) — jamais avalé silencieusement (bug #3).
///
/// Un port `ZLogger` de `zcrud_core` pourra s'y substituer additivement plus
/// tard ; en attendant, l'adaptateur reste zéro-config (défaut : no-op).
typedef ZFirestoreLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Adaptateur Firestore de [ZRepository] pour l'agrégat [T].
///
/// **Injection** (pas de singleton statique — testabilité) : une instance
/// [FirebaseFirestore], le [collectionPath], le [kind] + le couple
/// (dé)sérialisation typé (`fromMap`/`toMap`, ou la fabrique [fromRegistry]),
/// un [ZFirestoreLog] optionnel, et une voie de décodage **défensive**
/// optionnelle (`fromMapSafe`).
///
/// **Décodage DÉFENSIF (AD-10)** : la lecture route chaque document par une voie
/// tolérante — `fromMapSafe` s'il est fourni (ex. `ZModelAdapter.fromMapSafe`),
/// sinon une enveloppe locale de `fromMap`. Un document corrompu est **écarté +
/// loggé**, jamais propagé en `throw` : une page de N documents dont 1 est
/// corrompu retourne N-1 entités.
///
/// **Métadonnées de sync hors-entité** (AD-9/AD-16) : les clés `is_deleted` et
/// `updated_at` (`ZSyncMeta`, snake_case, ISO-8601) sont **fusionnées** dans le
/// document mais restent séparées côté modèle (aucun champ métier touché par
/// [softDelete]/[restore]).
///
/// **Recherche accent-insensible — limite documentée (AC15)** : Firestore n'a ni
/// `LIKE`, ni full-text, ni pliage diacritique natif. `ZDataRequest.search`
/// n'est donc **pas** servi ici (préfixe/égalité ou champ normalisé pré-calculé
/// requis côté app — voir E4/E7). Aucune normalisation NFD n'est appliquée.
///
/// **PRÉCONDITION — collection « zcrud-native » (MAJEUR-1 / MAJEUR-2)** : cet
/// adaptateur suppose une collection gérée **exclusivement** par zcrud, où
/// **tout** document écrit par [save] porte SYSTÉMATIQUEMENT (invariant
/// **exécutoire**, garanti par [_encode] + [save]) :
/// - un champ de **corps** `id` (= identité du document) — **clé de départage**
///   du tri/curseur (AC12). En **prod**, `orderBy('id')` **exclut**
///   silencieusement tout document DÉPOURVU de ce champ (sémantique Firestore) :
///   un document hérité/non-zcrud sans corps `id` disparaît des lectures
///   **triées/paginées**. Choix de la clé de corps `id` (option (b)) plutôt que
///   `FieldPath.documentId` (option (a)) : voir la justification PROUVÉE dans
///   [_buildQuery] (le backend de test rejette `startAfter` sur `documentId`).
/// - un champ `is_deleted:false` (`ZSyncMeta`, hors-entité) — le filtre serveur
///   `where('is_deleted', isEqualTo:false)` **exige la présence** du champ : un
///   document sans `is_deleted` est **exclu de TOUS** les chemins de lecture
///   (getById / getAll / watch) de façon **COHÉRENTE** (aucune divergence, cf.
///   [_isVisible]).
///
/// Brancher l'adaptateur sur une collection **préexistante** (intégration E7)
/// impose donc un **backfill d'onboarding** (`id` de corps + `is_deleted:false`
/// sur chaque document) — sans quoi les documents non conformes sont exclus des
/// lectures triées/paginées et filtrées, silencieusement, EN PROD.
class FirebaseZRepositoryImpl<T extends ZEntity> extends ZRepository<T> {
  /// Construit l'adaptateur à partir du couple (dé)sérialisation typé.
  FirebaseZRepositoryImpl({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required String kind,
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    T? Function(Map<String, dynamic> map)? fromMapSafe,
    ZFirestoreLog? logger,
    Set<String> timestampFields = const <String>{},
  })  : assert(
          timestampFields.intersection(ZSyncMeta.reservedKeys).isEmpty,
          'AD-19 : aucune clé RÉSERVÉE (ZSyncMeta.reservedKeys = '
          'updated_at/is_deleted) ne peut être annotée `persistAs: timestamp`. '
          'Convertir `updated_at` en Timestamp natif NEUTRALISERAIT la clé LWW '
          'au décodage (ZSyncMeta.updatedAt → null) et le merge dégénérerait en '
          '« le local gagne toujours ».',
        ),
        _firestore = firestore,
        _collectionPath = collectionPath,
        _kind = kind,
        _fromMap = fromMap,
        _toMap = toMap,
        _fromMapSafe = fromMapSafe,
        _log = logger ?? _noopLog,
        // Garde EXÉCUTOIRE (pas seulement en debug) : les clés réservées sont
        // retirées de l'ensemble hinté quoi qu'il arrive (l'`assert` ci-dessus
        // ne vit qu'en debug/test — la soustraction, elle, tient en release).
        _timestampFields = timestampFields.difference(ZSyncMeta.reservedKeys);

  /// Construit l'adaptateur en dérivant `fromMap`/`toMap` d'un [ZcrudRegistry]
  /// (voie stricte `decode`/`encode`). Le décodage reste **défensif** : la voie
  /// stricte est enveloppée localement (option (a) de l'ambiguïté #1 — aucune
  /// modification du contrat gelé `ZcrudRegistry`). Un `fromMapSafe` explicite
  /// (ex. `ZModelAdapter.fromMapSafe`) peut être fourni pour une tolérance
  /// portée par le modèle.
  ///
  ///
  /// ---
  ///
  /// # ✅ DW-ES14-2 SOLDÉE (ES-3.0) — la voie registre TYPE `extension`/`source`
  ///
  /// `fromRegistry` est la **voie recommandée**. Depuis ES-3.0, le [ZcrudRegistry]
  /// porte un `ZDecodeContext` (câblé au bootstrap) que `registry.decode`/`.encode`
  /// **thread** aux `fromMap`/`toMap` d'entité extensible. La voie registre
  /// **résout donc désormais** :
  ///
  /// - le slot `extension` **TYPÉ** (`ZNoteAudio`…) via le résolveur du contexte
  ///   (AD-4) — un `ZSmartNote` round-trippé par le registre revient
  ///   `extension is ZNoteAudio`, plus un `ZOpaqueNoteExtension` opaque ;
  /// - la provenance `source` via le `ZSourceRegistry` du contexte (AD-4 pt.3) —
  ///   le codec de l'app est **appliqué**, plus court-circuité.
  ///
  /// Le call-site est **INCHANGÉ** (`registry.decode(kind, map)`) : le contexte est
  /// un **champ du registre**, pas un paramètre de `decode` (AD-10 additif, spike
  /// R4 / AC10). Un `ZcrudRegistry()` **sans** contexte conserve le comportement
  /// historique (slot non typé / payload porté verbatim par `ZOpaqueNoteExtension`
  /// — jamais détruit, AD-10). Pour typer, câbler le contexte au bootstrap :
  ///
  /// ```dart
  /// final registry = ZcrudRegistry(
  ///   decodeContext: ZDecodeContext(
  ///     extensionParser: (kind, json) =>
  ///         kind == 'smart_note' ? ZNoteAudio.fromJsonSafe(json) : null,
  ///     sourceRegistry: appSourceRegistry,
  ///   ),
  /// )..bootstrap();
  /// final repo = FirebaseZRepositoryImpl<ZSmartNote>.fromRegistry(
  ///   firestore: firestore, collectionPath: path, kind: 'smart_note',
  ///   registry: registry,
  /// );
  /// ```
  ///
  /// # Décodage DÉFENSIF préservé (AD-10)
  ///
  /// La voie stricte `decode`/`encode` reste enveloppée localement (un
  /// `fromMapSafe` explicite peut être fourni). Le contexte **absorbe** toute
  /// exception d'un parser d'app (`ZExtension.guard`) : un `extension` corrompu ou
  /// de version future retombe sur `ZOpaqueNoteExtension`/`null`, **jamais** un
  /// throw, **jamais** une destruction.
  ///
  /// L'échappatoire `extra` (AD-4) reste **inconditionnellement** préservée sur
  /// **TOUTES** les voies d'écriture (DW-ES22-3, assertion (i.1) du gate) avec un
  /// `==` **profond** (DW-ES22-4, assertion (i.2)).
  ///
  /// Réf. : `architecture.md` § AD-19.1.c et § Deferred (DW-ES14-2 soldée) ;
  /// `tool/reserved_keys_gate/` (assertion **(e)** + groupe « DW-ES14-2 » inversé).
  factory FirebaseZRepositoryImpl.fromRegistry({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required String kind,
    required ZcrudRegistry registry,
    T? Function(Map<String, dynamic> map)? fromMapSafe,
    ZFirestoreLog? logger,
    Set<String> timestampFields = const <String>{},
  }) {
    return FirebaseZRepositoryImpl<T>(
      firestore: firestore,
      collectionPath: collectionPath,
      kind: kind,
      fromMap: (map) => registry.decode(kind, map) as T,
      toMap: (value) => registry.encode(kind, value),
      fromMapSafe: fromMapSafe,
      logger: logger,
      timestampFields: timestampFields,
    );
  }

  final FirebaseFirestore _firestore;
  final String _collectionPath;
  final String _kind;
  final T Function(Map<String, dynamic> map) _fromMap;
  final Map<String, dynamic> Function(T value) _toMap;
  final T? Function(Map<String, dynamic> map)? _fromMapSafe;
  final ZFirestoreLog _log;

  /// Clés persistées (corps d'entité) à encoder en `Timestamp` Firestore natif
  /// plutôt qu'en String ISO-8601 (gap B14, parité DODLP). Fourni par l'artefact
  /// généré neutre `$XxxTimestampFields` (`Set<String>`), câblé app-side. Vide par
  /// défaut ⇒ comportement historique **inchangé** (tout en ISO-8601).
  ///
  /// **Confinement AD-5** : le type `Timestamp` n'apparaît QUE dans la conversion
  /// interne (`_encode`/[_inject]) ; la surface publique reste un `Set<String>`
  /// nu.
  ///
  /// **Exclusion des clés réservées — GARDÉE PAR MACHINE (AD-19, M2)** :
  /// `updated_at`/`is_deleted` (`ZSyncMeta.reservedKeys`) sont **soustraits** de
  /// cet ensemble au constructeur (`difference`, effectif en release) et un
  /// `assert` échoue en debug/test si l'appelant les y met. Ce n'est **plus** une
  /// simple convention en commentaire : hinter `updated_at` en `Timestamp`
  /// écrirait la clé LWW en type natif, `ZSyncMeta.fromJson` la relirait `null`
  /// (le parse ISO n'accepte qu'une `String`), **toutes** les métas
  /// deviendraient `null` et `ZLwwResolver` dégénérerait silencieusement en « le
  /// local gagne toujours » (perte d'écritures distantes, sans aucun test rouge).
  /// La clé LWW reste donc **toujours** comparée en ISO-8601 (AD-9).
  final Set<String> _timestampFields;

  /// Clé snake_case du drapeau de soft-delete (`ZSyncMeta`, hors-entité).
  /// **AD-19** : alias de la définition machine unique (dette DW-ES13-1 soldée).
  static const String _kIsDeleted = ZSyncMeta.kIsDeleted;

  /// Clé snake_case de l'horodatage LWW (`ZSyncMeta`, ISO-8601).
  /// **AD-19** : alias de la définition machine unique (dette DW-ES13-1 soldée).
  static const String _kUpdatedAt = ZSyncMeta.kUpdatedAt;

  /// Clé logique d'identité injectée dans la map avant décodage.
  static const String _kId = 'id';

  /// Borne SÛRE d'écritures par `WriteBatch` (E5-3, AD-9) : la limite Firestore
  /// est **500** ; la borne canonique retenue est **450** (marge de sécurité).
  /// Cette constante est **backend-spécifique** et vit donc **exclusivement** ici
  /// (`zcrud_firestore`), **jamais** dans `zcrud_core` (AD-5).
  static const int kMaxBatchWrites = 450;

  /// Contrôleurs/abonnements ouverts par [watch]/[watchAll], fermés par [dispose].
  final List<StreamController<List<T>>> _controllers =
      <StreamController<List<T>>>[];
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

  bool _disposed = false;

  // ───────────────────────── Références (types Firestore PRIVÉS) ─────────────

  /// Collection **brute** (`Map`) — voie de lecture défensive par document.
  CollectionReference<Map<String, dynamic>> _rawCollection([String? path]) =>
      _firestore.collection(path ?? _collectionPath);

  /// Collection **typée** via `withConverter<T>` (AC1). `fromFirestore` re-décode
  /// le document (injection de l'`id` du snapshot). Utilisée **UNIQUEMENT** pour
  /// la **relecture round-trip** de [save] (preuve `save`→lecture restitue
  /// l'entité égale).
  ///
  /// **LOW-3 (acté)** : `toFirestore` n'est **jamais** invoqué — [save] écrit en
  /// `Map` **brute** (`batch.set` + [_encode]) et [getById]/les listes/flux
  /// lisent en `Map` brute + [_decode] **DÉFENSIF**. C'est **délibéré** : un
  /// `withConverter` ne peut pas renvoyer `null` pour écarter un document corrompu
  /// (AD-10). Le converter est donc volontairement limité au round-trip de [save]
  /// (chemin où un corps illisible EST une vraie erreur), pas aux lectures de
  /// masse (où 1 corrompu ne doit jamais faire échouer les N-1 sains).
  CollectionReference<T> _typedCollection([String? path]) =>
      _rawCollection(path).withConverter<T>(
        fromFirestore: (snap, _) => _fromMap(_inject(snap.id, snap.data())),
        toFirestore: (value, _) => _encode(value),
      );

  // ───────────────────────── (Dé)codage ─────────────────────────────────────

  /// Injecte l'`id` du document dans la [data] (le corps Firestore ne stocke pas
  /// nécessairement `id`) **et normalise** en String ISO-8601 les dates lues au
  /// format `Timestamp` natif, **avant** tout décodage (`fromMap` généré — qui ne
  /// connaît que `DateTime`/String via `_$asDateTime` — et `ZSyncMeta.fromJson` —
  /// dont le parse ISO n'accepte qu'une `String`). Une valeur déjà String (ancien
  /// document ISO) est laissée telle quelle : **tolérance bi-format**
  /// (`Timestamp` OU String, comme DODLP ; AD-10, gap B14).
  ///
  /// Deux ensembles de clés sont normalisés :
  /// 1. **[_timestampFields]** — les clés de **corps** hintées `persistAs:
  ///    timestamp` (B14) ;
  /// 2. **`ZSyncMeta.reservedKeys`** — les clés de **sync** (`updated_at`),
  ///    normalisées **INCONDITIONNELLEMENT** (M3, ES-1.3). C'est le correctif du
  ///    cas legacy **le plus probable du consommateur n°1** : un document
  ///    réellement écrit par **DODLP** persiste ses dates en `Timestamp`
  ///    Firestore natif, `updated_at` compris. Sans cette normalisation,
  ///    `ZSyncMeta.fromJson` renvoyait `updatedAt: null` sur **toute** la donnée
  ///    legacy ⇒ la **clé d'autorité du merge était perdue** et `ZLwwResolver`
  ///    dégénérait en « le local gagne toujours » (écritures distantes écrasées),
  ///    silencieusement. La méta **SURVIT** désormais au décodage d'un document
  ///    legacy — et le miroir de compat `T.updatedAt` (AD-19.2) est peuplé du
  ///    même coup.
  Map<String, dynamic> _inject(String id, Map<String, dynamic>? data) {
    final map = <String, dynamic>{...?data, _kId: id};
    // (2) Clés de SYNC : toujours (indépendant de `_timestampFields`, AD-19/M3).
    for (final key in ZSyncMeta.reservedKeys) {
      _normalizeIsoInPlace(map, key);
    }
    // (1) Clés de CORPS hintées (B14).
    for (final key in _timestampFields) {
      _normalizeIsoInPlace(map, key);
    }
    return map;
  }

  /// Réécrit `map[key]` en String ISO-8601 **si** la valeur lue est une date au
  /// format natif Firestore. Défensif (AD-10) : toute autre valeur (String déjà
  /// ISO, `null`, `bool`, type inattendu) est **laissée intacte** — jamais de
  /// `throw`.
  ///
  /// Formes reconnues :
  /// - `Timestamp` **natif** (SDK `cloud_firestore`) — cas prod/legacy DODLP ;
  /// - `DateTime` (certains backends/fakes désérialisent directement) ;
  /// - map `{_seconds, _nanoseconds}` — forme **sérialisée** d'un `Timestamp`
  ///   (export/REST, caches JSON), qui autrement traverserait le décodage en
  ///   silence.
  void _normalizeIsoInPlace(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is Timestamp) {
      map[key] = value.toDate().toUtc().toIso8601String();
      return;
    }
    if (value is DateTime) {
      map[key] = value.toUtc().toIso8601String();
      return;
    }
    if (value is Map) {
      final seconds = value['_seconds'];
      final nanos = value['_nanoseconds'];
      if (seconds is int) {
        final micros = seconds * Duration.microsecondsPerSecond +
            (nanos is int ? nanos ~/ 1000 : 0);
        map[key] = DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
            .toIso8601String();
      }
    }
  }

  /// Encode [value] + fusionne les métadonnées `ZSyncMeta` (updated_at ISO-8601,
  /// is_deleted=false — jamais de `Timestamp`, AD-9) puis applique le hint B14 :
  /// chaque clé de [_timestampFields] portant une String ISO-8601 parsable est
  /// remplacée par un `Timestamp` natif (confiné ici, AD-5).
  Map<String, dynamic> _encode(T value) {
    final map = Map<String, dynamic>.of(_toMap(value));
    final meta = ZSyncMeta(updatedAt: DateTime.now().toUtc(), isDeleted: false)
        .toJson();
    map[_kUpdatedAt] = meta[_kUpdatedAt];
    map[_kIsDeleted] = false;
    _applyTimestampHints(map);
    return map;
  }

  /// Remplace, pour chaque clé de [_timestampFields] (jamais `ZSyncMeta`), une
  /// String ISO-8601 **non nulle parsable** par `Timestamp.fromDate(...UTC)`.
  /// Valeur `null` ⇒ reste `null` ; valeur non-String / non parsable ⇒ **laissée
  /// inchangée** (défensif AD-10, jamais de `throw`).
  void _applyTimestampHints(Map<String, dynamic> map) {
    if (_timestampFields.isEmpty) return;
    for (final key in _timestampFields) {
      final value = map[key];
      if (value is String && value.isNotEmpty) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) map[key] = Timestamp.fromDate(parsed.toUtc());
      }
    }
  }

  /// Décodage **DÉFENSIF** (AD-10) : `fromMapSafe` s'il existe, sinon enveloppe
  /// locale de `fromMap`. Un document non décodable → `null` (écarté + loggé),
  /// jamais de `throw` propagé.
  T? _decode(String id, Map<String, dynamic>? data) {
    final map = _inject(id, data);
    final safe = _fromMapSafe;
    if (safe != null) {
      final decoded = safe(map);
      if (decoded == null) {
        _log('document non décodable (kind=$_kind, id=$id) — écarté');
      }
      return decoded;
    }
    try {
      return _fromMap(map);
    } on Object catch (e, s) {
      _log(
        'document non décodable (kind=$_kind, id=$id) — écarté',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Un document est **VISIBLE** ssi `is_deleted == false` — sémantique **ALIGNÉE**
  /// sur le filtre serveur `where('is_deleted', isEqualTo:false)` (MAJEUR-2). Un
  /// champ `is_deleted` **ABSENT** (document non-zcrud-native) OU `== true`
  /// (soft-deleted) est traité comme **non visible** de façon **COHÉRENTE** sur
  /// TOUS les chemins de lecture (getById / getAll / watch) — voir la précondition
  /// « collection zcrud-native » du dartdoc de classe. **Aucune divergence** get
  /// vs getAll/watch pour un même document.
  bool _isVisible(Map<String, dynamic> data) => data[_kIsDeleted] == false;

  /// Décode une liste de documents en **écartant** les corrompus (défensif) et
  /// les non-visibles (belt-and-suspenders : le filtre serveur `is_deleted ==
  /// false` les exclut déjà — [_isVisible] réaligne la couche applicative sur la
  /// MÊME sémantique, MAJEUR-2).
  List<T> _decodeDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final out = <T>[];
    for (final d in docs) {
      final data = d.data();
      if (!_isVisible(data)) continue;
      final entity = _decode(d.id, data);
      if (entity != null) out.add(entity);
    }
    return out;
  }

  // ───────────────────────── Traduction ZDataRequest → Query (AC6/7/12) ──────

  /// Requête de base : **exclusion serveur des soft-deleted** via égalité
  /// `is_deleted == false` (ambiguïté #2 tranchée : l'égalité — contrairement à
  /// `isNotEqualTo` — n'impose PAS de premier `orderBy` et n'entre pas en
  /// conflit avec le tie-break `id`, et laisse `count()` fonctionner).
  ///
  /// **MAJEUR-2** : l'égalité Firestore **exige la présence** du champ — un
  /// document SANS `is_deleted` est exclu ICI (serveur) ; la couche applicative
  /// [_isVisible] applique la MÊME sémantique (get/getAll/watch cohérents).
  /// Précondition « collection zcrud-native » : tout document écrit par [save]
  /// porte `is_deleted=false` (invariant exécutoire, cf. [_encode]).
  Query<Map<String, dynamic>> _baseQuery([String? path]) =>
      _rawCollection(path).where(_kIsDeleted, isEqualTo: false);

  /// Applique les [filters] par **chaînage IMMUABLE** (réaffectation
  /// systématique — corrige le bug #1 : une `Query` est immuable, `where(...)`
  /// retourne une NOUVELLE `Query`).
  Query<Map<String, dynamic>> _applyFilters(
    Query<Map<String, dynamic>> base,
    List<ZFilter> filters,
  ) {
    var q = base;
    for (final f in filters) {
      switch (f.op) {
        case ZFilterOp.eq:
          q = q.where(f.field, isEqualTo: f.value);
        case ZFilterOp.neq:
          q = q.where(f.field, isNotEqualTo: f.value);
        case ZFilterOp.lt:
          q = q.where(f.field, isLessThan: f.value);
        case ZFilterOp.lte:
          q = q.where(f.field, isLessThanOrEqualTo: f.value);
        case ZFilterOp.gt:
          q = q.where(f.field, isGreaterThan: f.value);
        case ZFilterOp.gte:
          q = q.where(f.field, isGreaterThanOrEqualTo: f.value);
        case ZFilterOp.contains:
          // Ambiguïté #4 : `arrayContains` (appartenance à un champ collection).
          // La « sous-chaîne texte » n'est PAS supportée nativement (AC15).
          q = q.where(f.field, arrayContains: f.value);
        case ZFilterOp.isIn:
          q = q.where(
            f.field,
            whereIn: (f.value is List)
                ? (f.value! as List<Object?>)
                : <Object?>[f.value],
          );
        case ZFilterOp.isNull:
          q = q.where(f.field, isNull: true);
      }
    }
    return q;
  }

  /// Construit la requête complète (filtres + tri + tie-break `id` + curseur +
  /// limit) par **chaînage immuable** (AC7). Le tie-break final `orderBy(id)` sur
  /// le **champ `id` logique** (stocké dans le corps de chaque document par
  /// [_encode]/[save]) garantit un ordre **total et stable** aux clés de tri
  /// égales (AC12), cohérent avec `ZCursor` (départage par `id`).
  ///
  /// **MAJEUR-1 — choix (b) `id` de corps vs (a) `FieldPath.documentId`, PROUVÉ.**
  /// L'option (a) (tie-break `orderBy(FieldPath.documentId)`, toujours présent en
  /// prod, donc SANS exclusion silencieuse) a été **testée et écartée** : le
  /// backend de test `fake_cloud_firestore` **REJETTE** `startAfter([...values,
  /// id])` quand un `orderBy` porte sur `documentId` — son évaluation interne
  /// appelle `doc.get(FieldPath.documentId)` et lève `Invalid argument(s): key
  /// must be String or FieldPath but found FieldPathType`. La pagination AC12
  /// devient donc infaisable en test sous (a). On retient (b) — champ `id` de
  /// corps — sous la **précondition « collection zcrud-native »** (dartdoc de
  /// classe) : tout document écrit par [save] porte son `id` de corps (invariant
  /// exécutoire). ⚠️ En **prod**, `orderBy('id')` **exclut** tout document
  /// dépourvu de corps `id` (documents non-zcrud → backfill d'onboarding E7). NB:
  /// le fake N'imite PAS cette exclusion (il classe le champ absent comme `null`),
  /// donc un test ne peut prouver l'exclusion prod — il prouve l'invariant
  /// [save]-écrit-`id` qui la neutralise (voir tests MAJEUR-1).
  ///
  /// **LOW-5 — index composites requis EN PROD.** Une requête combinant un
  /// `where` d'inégalité (`>`, `>=`, `<`, `<=`) OU un `where(is_deleted==false)`
  /// AVEC un `orderBy(champ)` + le tie-break `orderBy('id')` exige un **index
  /// composite** Firestore (`firestore.indexes.json`), sinon la prod lève
  /// `FAILED_PRECONDITION` → `ZServerFailure`. `fake_cloud_firestore` n'exige aucun
  /// index (faux vert). Les index sont à provisionner à l'intégration/déploiement
  /// (E7) — non fournis par cette story (adaptateur backend-agnostique, AD-5).
  Query<Map<String, dynamic>> _buildQuery(
    Query<Map<String, dynamic>> base,
    ZDataRequest req,
  ) {
    var q = _applyFilters(base, req.filters);

    final hasSorts = req.sorts.isNotEmpty;
    if (hasSorts) {
      for (final s in req.sorts) {
        q = q.orderBy(s.field, descending: s.direction == ZSortDirection.desc);
      }
    }
    // Tie-break `id` systématique dès qu'un ordre est requis (tri OU pagination
    // par curseur) — un `ZDataRequest()` vide reste SANS clause d'ordre (AC6).
    if (hasSorts || req.startAfter != null) {
      q = q.orderBy(_kId);
    }

    final cursor = req.startAfter;
    if (cursor != null) {
      // Valeurs alignées positionnellement sur `sorts` + `id` en tie-break final
      // (curseur partiel accepté par Firestore si `id` absent).
      final values = <Object?>[...cursor.values];
      if (cursor.id != null) values.add(cursor.id);
      q = q.startAfter(values);
    }

    final limit = req.limit;
    if (limit != null) q = q.limit(limit);

    return q;
  }

  // ───────────────────────── Enveloppe d'erreurs unique (AC9/10/11) ──────────

  /// Enveloppe **unique** de toute opération : `FirebaseException → ZServerFailure`
  /// ; un `ZFailure` levé volontairement est repropagé ; toute autre erreur →
  /// `ZServerFailure` typé. **JAMAIS** de `catch(_){}` (bug #3). Le corps décide
  /// lui-même des `Left`/`Right` métier (`null ≠ erreur` — bug #4).
  Future<ZResult<R>> _guard<R>(Future<ZResult<R>> Function() body) async {
    try {
      return await body();
    } on FirebaseException catch (e, s) {
      _log('FirebaseException (kind=$_kind, code=${e.code})',
          error: e, stackTrace: s);
      return Left<ZFailure, R>(ZServerFailure(e.message ?? e.code));
    } on ZFailure catch (f) {
      return Left<ZFailure, R>(f);
    } on Object catch (e, s) {
      _log('erreur inattendue (kind=$_kind)', error: e, stackTrace: s);
      return Left<ZFailure, R>(ZServerFailure(e.toString()));
    }
  }

  // ───────────────────────── Lectures (AC2/3/4/10/11) ───────────────────────

  @override
  Stream<List<T>> watchAll() => _watchQuery(_baseQuery);

  @override
  Stream<List<T>> watch(ZDataRequest request) =>
      _watchQuery(() => _buildQuery(_baseQuery(), request));

  /// Flux **NU** (AD-11) : seed immédiat (état courant) puis mutations. Les
  /// non-visibles/corrompus sont exclus. Une collection vide émet `[]` (AC10).
  /// L'abonnement upstream est tracé pour [dispose].
  ///
  /// **MEDIUM-1 (AC9)** : la `Query` est construite par [build] **DANS**
  /// `onListen`, sous garde `try/catch`. Un throw **SYNCHRONE** à la construction
  /// (ex. `_firestore.collection(...)` lève une `FirebaseException`) ou à
  /// l'abonnement est **poussé dans le canal du stream** ([StreamController.
  /// addError]) — **jamais** relancé synchroniquement vers l'appelant. Les
  /// erreurs **runtime** de `snapshots()` transitent par le même canal
  /// (`onError`). Aucune exception ne remonte hors du flux.
  Stream<List<T>> _watchQuery(Query<Map<String, dynamic>> Function() build) {
    late final StreamController<List<T>> controller;
    // MEDIUM-1 (parité E5-1) : l'abonnement source `snapshots()` est capturé
    // pour être ANNULÉ à l'annulation du flux (`onCancel`) — pas seulement au
    // `dispose()`. Sans cela, chaque `watch`/`watchAll` empilerait un contrôleur
    // + un abonnement vivants (fuite non bornée sur un repo à longue durée de
    // vie).
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    controller = StreamController<List<T>>(
      onListen: () {
        try {
          sub = build().snapshots().listen(
            (snap) {
              // LOW-1 (parité) : une exception DANS le callback (`_decodeDocs`)
              // est routée vers le canal d'erreur — miroir du `onError` — au lieu
              // de devenir une erreur asynchrone non gérée.
              try {
                controller.add(_decodeDocs(snap.docs));
              } on Object catch (e, s) {
                _log('événement firestore en erreur (kind=$_kind)',
                    error: e, stackTrace: s);
                controller.addError(_toFailure(e));
              }
            },
            onError: (Object e, StackTrace s) {
              _log('flux firestore en erreur (kind=$_kind)',
                  error: e, stackTrace: s);
              controller.addError(_toFailure(e));
            },
          );
          _subs.add(sub!);
        } on Object catch (e, s) {
          // Throw SYNCHRONE à la construction/abonnement de la Query : converti
          // en erreur de FLUX (jamais d'exception qui remonte à l'appelant, AC9).
          _log('construction du flux firestore en erreur (kind=$_kind)',
              error: e, stackTrace: s);
          controller.addError(_toFailure(e));
        }
      },
      onCancel: () async {
        // MEDIUM-1 (parité) : libère la souscription source + le contrôleur dès
        // que le consommateur annule — sans attendre `dispose()`. Idempotent
        // avec `dispose()` (retraits sur listes).
        _controllers.remove(controller);
        final s = sub;
        sub = null;
        if (s != null) {
          _subs.remove(s);
          await s.cancel();
        }
        if (!controller.isClosed) await controller.close();
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }

  /// Mappe une erreur brute en [ZFailure] pour la voie **FLUX** — miroir de
  /// [_guard] (`FirebaseException → ZServerFailure`, `ZFailure` repropagé, reste →
  /// `ZServerFailure`).
  ZFailure _toFailure(Object e) {
    if (e is FirebaseException) return ZServerFailure(e.message ?? e.code);
    if (e is ZFailure) return e;
    return ZServerFailure(e.toString());
  }

  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request}) => _guard(() async {
        final query = request == null
            ? _baseQuery()
            : _buildQuery(_baseQuery(), request);
        final snap = await query.get();
        return Right<ZFailure, List<T>>(_decodeDocs(snap.docs));
      });

  @override
  Future<ZResult<T>> getById(String id) => _guard(() async {
        final snap = await _rawCollection().doc(id).get();
        if (!snap.exists) {
          return Left<ZFailure, T>(
            ZNotFoundFailure('Entité introuvable', id: id, entity: _kind),
          );
        }
        final data = snap.data() ?? <String, dynamic>{};
        // MAJEUR-2 : visibilité ALIGNÉE sur getAll/watch (`is_deleted == false`).
        // Un `is_deleted` ABSENT (doc non-zcrud-native) est exclu ICI AUSSI, comme
        // le filtre serveur l'exclut de getAll/watch → aucune divergence.
        if (!_isVisible(data)) {
          return Left<ZFailure, T>(
            ZNotFoundFailure(
              data[_kIsDeleted] == true
                  ? 'Entité soft-deleted'
                  : 'Entité non visible (is_deleted absent — hors invariant '
                      'zcrud-native)',
              id: id,
              entity: _kind,
            ),
          );
        }
        final entity = _decode(id, data);
        if (entity == null) {
          return Left<ZFailure, T>(
            ZNotFoundFailure('Document corrompu', id: id, entity: _kind),
          );
        }
        return Right<ZFailure, T>(entity);
      });

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) => _guard(() async {
        // Le tri/curseur/limit n'affectent pas un décompte : seuls les FILTRES
        // (+ exclusion soft-deleted) comptent.
        final query = _applyFilters(
          _baseQuery(),
          request?.filters ?? const <ZFilter>[],
        );
        final agg = await query.count().get();
        return Right<ZFailure, int>(agg.count ?? 0);
      });

  // ───────────────────────── Écritures (AC1/5/8/10) ─────────────────────────

  /// Persiste [item] en **écrasement TOTAL** (`batch.set`, JAMAIS un merge) puis
  /// relit l'entité persistée (round-trip AC1).
  ///
  /// **LOW-4 — comportement full-write E5-1, INTENTIONNEL :**
  /// - [_encode] réécrit **inconditionnellement** `is_deleted:false` +
  ///   `updated_at=now` → re-sauver une entité **soft-deletée la RESSUSCITE**
  ///   (redevient visible). Assumé (invariant « save ⇒ vivant »).
  /// - tout champ hors [_toMap]/[_encode] présent sur le document existant est
  ///   **écrasé** (`set` remplace le document entier) — aucune préservation de
  ///   méta concurrente.
  ///
  /// Le **merge Last-Write-Wins** sur `updated_at` (offline-first, préservation
  /// des écritures concurrentes) est la responsabilité d'**E5-3** — hors de cette
  /// story.
  @override
  Future<ZResult<T>> save(T item, {String? collectionId}) => _guard(() async {
        final collection = _rawCollection(collectionId);
        // Matérialisation de l'éphémère (AD-14, invariant porté par le repo).
        final id = item.id ?? collection.doc().id;
        // Le corps porte TOUJOURS son `id` logique (clé du tie-break AC12) en
        // plus des métadonnées `ZSyncMeta` fusionnées par [_encode].
        final map = _encode(item)..[_kId] = id;

        // Écriture ATOMIQUE via WriteBatch committé (AC8 — jamais partielle).
        final batch = _firestore.batch();
        batch.set(collection.doc(id), map);
        await batch.commit();

        // Round-trip fidèle (AC1) : relecture via la collection **typée**
        // `withConverter<T>` — `fromFirestore` re-décode le document persisté.
        final snap = await _typedCollection(collectionId).doc(id).get();
        final decoded = snap.data();
        if (decoded == null) {
          return Left<ZFailure, T>(
            ZDomainFailure('Entité écrite mais non re-décodable (kind=$_kind)'),
          );
        }
        return Right<ZFailure, T>(decoded);
      });

  @override
  Future<ZResult<Unit>> softDelete(String id) =>
      _setDeletedFlag(id, deleted: true);

  @override
  Future<ZResult<Unit>> restore(String id) =>
      _setDeletedFlag(id, deleted: false);

  /// Bascule `is_deleted` **hors-entité** (aucun champ métier touché) via un
  /// `WriteBatch` committé (AC8). `id` inconnu → `Left(ZNotFoundFailure)` (AC10).
  Future<ZResult<Unit>> _setDeletedFlag(String id, {required bool deleted}) =>
      _guard(() async {
        final doc = _rawCollection().doc(id);
        final snap = await doc.get();
        if (!snap.exists) {
          return Left<ZFailure, Unit>(
            ZNotFoundFailure('Entité introuvable', id: id, entity: _kind),
          );
        }
        final batch = _firestore.batch();
        batch.update(doc, <String, dynamic>{
          _kIsDeleted: deleted,
          _kUpdatedAt: DateTime.now().toUtc().toIso8601String(),
        });
        await batch.commit();
        return Right<ZFailure, Unit>(unit);
      });

  // ───────────────────────── Sync offline-first (E5-3) ───────────────────────

  /// **Voie de lecture de SYNCHRONISATION** (E5-3) : lit **TOUS** les documents
  /// **SANS** le filtre serveur `is_deleted == false` (tombstones **inclus**),
  /// chacun apparié à son [ZSyncMeta] (lu depuis le corps). Contraste voulu avec
  /// [getAll] (qui exclut les tombstones) — indispensable au merge LWW. Décodage
  /// **défensif** (AD-10) : un document corrompu est **écarté + loggé**, jamais un
  /// `throw`. `FirebaseException` → `Left(ZServerFailure)` (best-effort).
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntriesAll() => _guard(() async {
        final snap = await _rawCollection().get();
        final out = <ZSyncEntry<T>>[];
        for (final d in snap.docs) {
          final data = d.data();
          final entity = _decode(d.id, data);
          if (entity == null) continue; // corrompu → écarté + loggé (AD-10)
          out.add(
            ZSyncEntry<T>(
              entity: entity,
              meta: ZSyncMeta.fromJson(_inject(d.id, data)),
            ),
          );
        }
        return Right<ZFailure, List<ZSyncEntry<T>>>(out);
      });

  /// **Écriture PRÉSERVANT la méta** (E5-3) d'une **seule** [entry] : `batch.set`
  /// committé (jamais partiel) écrivant le corps + `updated_at`/`is_deleted`
  /// **verbatim** (jamais `now()`, contrairement à [save]). Réservé au merge.
  Future<ZResult<Unit>> writeMerged(ZSyncEntry<T> entry) => _guard(() async {
        final id = entry.entity.id;
        if (id == null) {
          return Left<ZFailure, Unit>(
            ZDomainFailure(
              'writeMerged requiert une entité matérialisée (kind=$_kind)',
            ),
          );
        }
        final batch = _firestore.batch();
        batch.set(_rawCollection().doc(id), _mergedMap(entry, id));
        await batch.commit();
        return Right<ZFailure, Unit>(unit);
      });

  /// **Propagation PAR LOT BORNÉE** (E5-3, AD-9) d'un changeset d'[entries],
  /// chacune écrite **verbatim** (méta préservée, jamais `now()`). Le changeset
  /// est **découpé** en lots de ≤ [kMaxBatchWrites] (**450**), chaque lot étant un
  /// `WriteBatch` **committé atomiquement** (aucune écriture partielle non-commit).
  /// Liste vide → `Right(unit)`. `FirebaseException` → `Left(ZServerFailure)`.
  Future<ZResult<Unit>> applyMergedAll(List<ZSyncEntry<T>> entries) =>
      _guard(() async {
        for (var start = 0;
            start < entries.length;
            start += kMaxBatchWrites) {
          final end = (start + kMaxBatchWrites < entries.length)
              ? start + kMaxBatchWrites
              : entries.length;
          final batch = _firestore.batch();
          for (var i = start; i < end; i++) {
            final entry = entries[i];
            final id = entry.entity.id;
            if (id == null) {
              return Left<ZFailure, Unit>(
                ZDomainFailure(
                  'applyMergedAll: entité éphémère (id null) interdite '
                  '(kind=$_kind)',
                ),
              );
            }
            batch.set(_rawCollection().doc(id), _mergedMap(entry, id));
          }
          await batch.commit();
        }
        return Right<ZFailure, Unit>(unit);
      });

  /// Construit la map d'écriture d'un merge : corps [_toMap] + corps `id` +
  /// `updated_at`/`is_deleted` de la [entry] **verbatim** (jamais `now()`).
  ///
  /// MAJEUR-1 (DP-11) : applique AUSSI le hint B14 (`_applyTimestampHints`) sur
  /// cette voie d'écriture (sync/merge offline-first), pas seulement `_encode`
  /// (save). Sinon `created_at` finit en types MIXTES sur disque (Timestamp pour
  /// les save en ligne, String ISO pour les save resync) → `orderBy`/plage
  /// Firestore silencieusement incorrects. `_applyTimestampHints` est idempotent
  /// et n'affecte JAMAIS `ZSyncMeta` (`updated_at`/`is_deleted` ∉ `_timestampFields`).
  Map<String, dynamic> _mergedMap(ZSyncEntry<T> entry, String id) {
    final map = Map<String, dynamic>.of(_toMap(entry.entity));
    map[_kId] = id;
    final meta = entry.meta.toJson();
    map[_kUpdatedAt] = meta[_kUpdatedAt]; // verbatim (peut être null)
    map[_kIsDeleted] = entry.meta.isDeleted; // verbatim (tombstone possible)
    _applyTimestampHints(map);
    return map;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    for (final controller in _controllers) {
      unawaited(controller.close());
    }
    _controllers.clear();
  }
}
