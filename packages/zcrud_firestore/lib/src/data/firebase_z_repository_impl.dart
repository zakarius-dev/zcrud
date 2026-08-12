/// Adaptateur **Firestore** concret du port neutre `ZRepository<T>`.
///
/// Réunit des corrections consolidées à partir de plusieurs implémentations
/// applicatives historiques : réassignation de clause perdue, `catch(_){}`
/// silencieux, `null` traité comme erreur, écritures partielles non
/// committées.
///
/// **Isolation (invariant AD-5, CRUCIAL)** : `cloud_firestore` est importé
/// **uniquement** ici. Aucun type Firestore (`Query`/`Timestamp`/
/// `DocumentSnapshot`/`CollectionReference`/`FirebaseException`/`Filter`) ne
/// fuit dans une **signature publique** — toutes restent `ZResult<…>` /
/// `Stream<List<T>>` **nues**. Les dates transitent en **ISO-8601 String**
/// (jamais `Timestamp`), sauf pour les champs explicitement hintés en
/// `Timestamp` natif via `timestampFields`.
///
/// **Périmètre** : ce fichier porte le repo Firestore, la traduction
/// `ZDataRequest → Query`, le curseur, le soft-delete/restore, le comptage et
/// le décodage défensif. Le `ZLocalStore` (Hive), l'offline-first LWW et
/// l'orchestrateur de synchronisation vivent dans les autres fichiers de ce
/// paquet.
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
/// puis écarté (AD-10) — jamais avalé silencieusement.
///
/// Un port `ZLogger` de `zcrud_core` pourra s'y substituer additivement plus
/// tard ; en attendant, l'adaptateur reste zéro-config (défaut : no-op).
typedef ZFirestoreLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Sémantique de **lecture** du drapeau de soft-delete `is_deleted`, pour
/// intégrer un parc documentaire existant sans backfill. Opt-in au
/// constructeur de [FirebaseZRepositoryImpl] — le défaut [strict] est le
/// comportement historique, **inchangé**.
///
/// Type **neutre** (aucun symbole `cloud_firestore` — AD-5) : il décrit un
/// contrat de visibilité, pas une mécanique backend.
enum ZDeletionSemantics {
  /// Comportement historique (défaut) : le filtre serveur
  /// `where('is_deleted', isEqualTo: false)` **exige la présence** du champ.
  /// Un document SANS `is_deleted` est exclu de tous les chemins de lecture
  /// (parc **né zcrud** — précondition « collection zcrud-native », backfill
  /// d'onboarding requis sinon).
  strict,

  /// Mode **compat parc existant** : un document SANS `is_deleted` est
  /// considéré **NON supprimé** (le sens métier legacy : absent = vivant).
  ///
  /// **Coût — filtrage client** : Firestore ne sait pas exprimer
  /// `!= true OU absent` en une clause (`isNotEqualTo` exclut les documents
  /// sans le champ). La lecture se fait donc **SANS** clause `is_deleted` et
  /// le drapeau est filtré **au décodage** ([FirebaseZRepositoryImpl] écarte
  /// `is_deleted == true`, et `legacyDeletedKey == true` si fournie) : chaque
  /// page lit aussi les documents supprimés avant de les écarter — les
  /// index/perf restent corrects tant que la corbeille est marginale.
  /// `count()` perd l'agrégat serveur (décompte client, même raison).
  ///
  /// L'auto-réparation à l'écriture demeure : chaque `save` pose
  /// `is_deleted:false`, le parc **converge** vers [strict] au fil des
  /// écritures (bascule ultérieure possible sans backfill).
  absentMeansAlive,
}

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
/// **Recherche accent-insensible — limite documentée** : Firestore n'a ni
/// `LIKE`, ni full-text, ni pliage diacritique natif. `ZDataRequest.search`
/// n'est donc **pas** servi ici (préfixe/égalité ou champ normalisé pré-calculé
/// requis côté application). Aucune normalisation NFD n'est appliquée.
///
/// **PRÉCONDITION — collection « zcrud-native »** : cet adaptateur suppose
/// une collection gérée **exclusivement** par zcrud, où **tout** document
/// écrit par [save] porte SYSTÉMATIQUEMENT (invariant **exécutoire**, garanti
/// par [_encode] + [save]) :
/// - un champ de **corps** `id` (= identité du document) — **clé de
///   départage** du tri/curseur. En **prod**, `orderBy('id')` **exclut**
///   silencieusement tout document DÉPOURVU de ce champ (sémantique Firestore) :
///   un document hérité/non-zcrud sans corps `id` disparaît des lectures
///   **triées/paginées**. Choix de la clé de corps `id` (option (b)) plutôt que
///   `FieldPath.documentId` (option (a)) : voir la justification PROUVÉE dans
///   [_buildQuery] (le backend de test rejette `startAfter` sur `documentId`).
/// - un champ `is_deleted:false` (`ZSyncMeta`, hors-entité) — le filtre serveur
///   `where('is_deleted', isEqualTo:false)` **exige la présence** du champ : un
///   document sans `is_deleted` est **exclu de TOUS** les chemins de lecture
///   (getById / getAll / watch) de façon **COHÉRENTE** (aucune divergence, cf.
///   [_matchesScope]).
///
/// Brancher l'adaptateur sur une collection **préexistante** impose donc un
/// **backfill d'onboarding** (`id` de corps + `is_deleted:false` sur chaque
/// document) — sans quoi les documents non conformes sont exclus des lectures
/// triées/paginées et filtrées, silencieusement, EN PROD. **OU** — le mode
/// opt-in [ZDeletionSemantics.absentMeansAlive] (« absent = vivant », zéro
/// migration de données), qui lève cette précondition pour le drapeau
/// `is_deleted` (celle du corps `id` demeure pour les lectures
/// **triées/paginées**).
///
/// **Corbeille** : `ZDataRequest.deletedScope`
/// (`aliveOnly`/`includeDeleted`/`deletedOnly`) est honoré sur
/// [getAll]/[watch]/[count] dans les DEUX sémantiques — clauses `where` en
/// [ZDeletionSemantics.strict], filtrage client en
/// [ZDeletionSemantics.absentMeansAlive] (`deletedOnly` y inclut
/// `legacyDeletedKey == true`).
///
/// **Contrat `fromMap`** : votre `fromMap` doit accepter les dates
/// **ISO-8601** — le décodage normalise tout horodatage (`Timestamp` natif,
/// `DateTime`, `{_seconds,_nanoseconds}`) en `String` ISO **avant** d'appeler
/// le `fromMap` injecté (cf. [_normalizeTemporalDeep]) : un cast dur
/// `as Timestamp?` y jette systématiquement.
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
    ZDeletionSemantics deletionSemantics = ZDeletionSemantics.strict,
    String? legacyDeletedKey,
  })  : assert(
          timestampFields.intersection(ZSyncMeta.reservedKeys).isEmpty,
          'AD-19 : aucune clé RÉSERVÉE (ZSyncMeta.reservedKeys = '
          'updated_at/is_deleted) ne peut être annotée `persistAs: timestamp`. '
          'Convertir `updated_at` en Timestamp natif NEUTRALISERAIT la clé LWW '
          'au décodage (ZSyncMeta.updatedAt → null) et le merge dégénérerait en '
          '« le local gagne toujours ».',
        ),
        assert(
          legacyDeletedKey == null ||
              deletionSemantics == ZDeletionSemantics.absentMeansAlive,
          'legacyDeletedKey n\'est honorée qu\'en '
          'ZDeletionSemantics.absentMeansAlive (le mode strict lit '
          'EXCLUSIVEMENT le drapeau canonique is_deleted, par clauses '
          'serveur) — la fournir en strict serait ignorée SILENCIEUSEMENT.',
        ),
        assert(
          legacyDeletedKey == null ||
              !ZSyncMeta.reservedKeys.contains(legacyDeletedKey),
          'legacyDeletedKey ne peut pas être une clé réservée ZSyncMeta '
          '(is_deleted est déjà lue nativement).',
        ),
        _firestore = firestore,
        _collectionPath = collectionPath,
        _kind = kind,
        _fromMap = fromMap,
        _toMap = toMap,
        _fromMapSafe = fromMapSafe,
        _log = logger ?? _noopLog,
        _deletionSemantics = deletionSemantics,
        _legacyDeletedKey = legacyDeletedKey,
        // Garde EXÉCUTOIRE (pas seulement en debug) : les clés réservées sont
        // retirées de l'ensemble hinté quoi qu'il arrive (l'`assert` ci-dessus
        // ne vit qu'en debug/test — la soustraction, elle, tient en release).
        _timestampFields = timestampFields.difference(ZSyncMeta.reservedKeys);

  /// Construit l'adaptateur en dérivant `fromMap`/`toMap` d'un [ZcrudRegistry]
  /// (voie stricte `decode`/`encode`). Le décodage reste **défensif** : la voie
  /// stricte est enveloppée localement (sans aucune
  /// modification du contrat gelé `ZcrudRegistry`). Un `fromMapSafe` explicite
  /// (ex. `ZModelAdapter.fromMapSafe`) peut être fourni pour une tolérance
  /// portée par le modèle.
  ///
  ///
  /// ---
  ///
  /// # La voie registre type `extension`/`source`
  ///
  /// `fromRegistry` est la **voie recommandée**. Le [ZcrudRegistry]
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
  /// un **champ du registre**, pas un paramètre de `decode` (extension additive,
  /// AD-10). Un `ZcrudRegistry()` **sans** contexte conserve le comportement
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
  /// **TOUTES** les voies d'écriture, vérifiée par égalité **profonde**.
  factory FirebaseZRepositoryImpl.fromRegistry({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required String kind,
    required ZcrudRegistry registry,
    T? Function(Map<String, dynamic> map)? fromMapSafe,
    ZFirestoreLog? logger,
    Set<String> timestampFields = const <String>{},
    ZDeletionSemantics deletionSemantics = ZDeletionSemantics.strict,
    String? legacyDeletedKey,
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
      deletionSemantics: deletionSemantics,
      legacyDeletedKey: legacyDeletedKey,
    );
  }

  final FirebaseFirestore _firestore;
  final String _collectionPath;
  final String _kind;
  final T Function(Map<String, dynamic> map) _fromMap;
  final Map<String, dynamic> Function(T value) _toMap;
  final T? Function(Map<String, dynamic> map)? _fromMapSafe;
  final ZFirestoreLog _log;

  /// Sémantique de lecture du drapeau `is_deleted`.
  /// Défaut [ZDeletionSemantics.strict] = comportement historique inchangé.
  final ZDeletionSemantics _deletionSemantics;

  /// Clé **legacy** de soft-delete du parc préexistant (ex. `'deleted'`,
  /// camelCase), ou `null`. Honorée **uniquement** en
  /// [ZDeletionSemantics.absentMeansAlive] (filtrage client) : un document dont
  /// cette clé vaut `true` est traité comme supprimé (écarté d'`aliveOnly`,
  /// inclus dans `deletedOnly`).
  final String? _legacyDeletedKey;

  /// Clés persistées (corps d'entité) à encoder en `Timestamp` Firestore natif
  /// plutôt qu'en String ISO-8601. Fourni par l'artefact
  /// généré neutre `$XxxTimestampFields` (`Set<String>`), câblé app-side. Vide par
  /// défaut ⇒ comportement historique **inchangé** (tout en ISO-8601).
  ///
  /// **Confinement AD-5** : le type `Timestamp` n'apparaît QUE dans la conversion
  /// interne (`_encode`/[_inject]) ; la surface publique reste un `Set<String>`
  /// nu.
  ///
  /// **Exclusion des clés réservées — GARDÉE PAR MACHINE** :
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
  /// Alias de la définition machine unique.
  static const String _kIsDeleted = ZSyncMeta.kIsDeleted;

  /// Clé snake_case de l'horodatage LWW (`ZSyncMeta`, ISO-8601).
  /// Alias de la définition machine unique.
  static const String _kUpdatedAt = ZSyncMeta.kUpdatedAt;

  /// Clé logique d'identité injectée dans la map avant décodage.
  static const String _kId = 'id';

  /// Borne SÛRE d'écritures par `WriteBatch` (AD-9) : la limite Firestore
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

  /// Collection **typée** via `withConverter<T>`. `fromFirestore` re-décode
  /// le document (injection de l'`id` du snapshot). Utilisée **UNIQUEMENT** pour
  /// la **relecture round-trip** de [save] (preuve `save`→lecture restitue
  /// l'entité égale).
  ///
  /// Note : `toFirestore` n'est **jamais** invoqué — [save] écrit en
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
  /// (`Timestamp` OU String ; AD-10).
  ///
  /// Deux ensembles de clés sont normalisés :
  /// 1. **[_timestampFields]** — les clés de **corps** hintées `persistAs:
  ///    timestamp` ;
  /// 2. **`ZSyncMeta.reservedKeys`** — les clés de **sync** (`updated_at`),
  ///    normalisées **INCONDITIONNELLEMENT**. C'est le correctif du
  ///    cas legacy **le plus probable côté consommateur** : un document
  ///    réellement écrit par une application legacy persiste ses dates en
  ///    `Timestamp` Firestore natif, `updated_at` compris. Sans cette
  ///    normalisation, `ZSyncMeta.fromJson` renverrait `updatedAt: null` sur
  ///    **toute** la donnée legacy ⇒ la **clé d'autorité du merge serait perdue**
  ///    et `ZLwwResolver` dégénérerait en « le local gagne toujours » (écritures
  ///    distantes écrasées), silencieusement. La méta **SURVIT** au décodage
  ///    d'un document legacy — et le miroir de compat `T.updatedAt` est peuplé
  ///    du même coup.
  Map<String, dynamic> _inject(String id, Map<String, dynamic>? data) {
    final map = <String, dynamic>{...?data, _kId: id};
    // Normalisation UNIVERSELLE et RÉCURSIVE — alignée sur celle de
    // `ZOfflineFirstBoxRepository._normalizeMetaIso`.
    //
    // La restreindre aux seules clés de SYNC et aux clés de corps
    // explicitement HINTÉES (`persistAs: timestamp`) laisserait une clé
    // temporelle non hintée — `created_at` en est le cas type — traverser le
    // décodage en `Timestamp` brut, produisant une forme de donnée
    // dépendante du chemin d'écriture, sans qu'aucun contrat ne l'annonce.
    //
    // L'argument de la dartdoc de `_normalizeMetaIso` vaut mot pour mot ici :
    // on ne convertit QUE les formes backend (`Timestamp`, `DateTime`,
    // `{_seconds,_nanoseconds}`), jamais du texte que l'hôte aurait voulu — une
    // String déjà ISO n'est pas retouchée (idempotence).
    for (final key in map.keys.toList()) {
      map[key] = _normalizeTemporalDeep(map[key]);
    }
    return map;
  }

  /// Réécrit `map[key]` en String ISO-8601 **si** la valeur lue est une date au
  /// format natif Firestore. Défensif (AD-10) : toute autre valeur (String déjà
  /// ISO, `null`, `bool`, type inattendu) est **laissée intacte** — jamais de
  /// `throw`.
  ///
  /// Formes reconnues :
  /// - `Timestamp` **natif** (SDK `cloud_firestore`) — cas prod/legacy ;
  /// - `DateTime` (certains backends/fakes désérialisent directement) ;
  /// - map `{_seconds, _nanoseconds}` — forme **sérialisée** d'un `Timestamp`
  ///   (export/REST, caches JSON), qui autrement traverserait le décodage en
  ///   silence.
  /// Convertit RÉCURSIVEMENT tout horodatage backend en String ISO-8601.
  /// Valeur non temporelle ⇒ rendue **inchangée** (AD-10).
  Object? _normalizeTemporalDeep(Object? value) {
    if (value is Timestamp) {
      return value.toDate().toUtc().toIso8601String();
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is Map) {
      // Forme sérialisée `{_seconds,_nanoseconds}` (export/REST, cache JSON).
      final seconds = value['_seconds'];
      if (seconds is int) {
        final nanos = value['_nanoseconds'];
        final micros = seconds * Duration.microsecondsPerSecond +
            (nanos is int ? nanos ~/ 1000 : 0);
        return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true)
            .toIso8601String();
      }
      return <String, dynamic>{
        for (final e in value.entries) '${e.key}': _normalizeTemporalDeep(e.value),
      };
    }
    if (value is List) {
      return value.map<Object?>(_normalizeTemporalDeep).toList();
    }
    return value;
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

  /// `true` si [data] porte le drapeau **legacy** de suppression
  /// ([_legacyDeletedKey]` == true`). Toujours `false` si aucune clé legacy
  /// n'est configurée.
  bool _isLegacyDeleted(Map<String, dynamic> data) {
    final key = _legacyDeletedKey;
    return key != null && data[key] == true;
  }

  /// Prédicat de visibilité **applicatif** d'un document pour un [scope] donné,
  /// selon [_deletionSemantics] :
  ///
  /// - **[ZDeletionSemantics.strict]** : sémantique historique **ALIGNÉE** sur
  ///   les clauses serveur. `aliveOnly` ⇔ `is_deleted == false` — un
  ///   champ **ABSENT** (document non-zcrud-native) OU `== true` est non
  ///   visible, de façon **COHÉRENTE** sur TOUS les chemins de lecture (getById
  ///   / getAll / watch) — voir la précondition « collection zcrud-native » du
  ///   dartdoc de classe. `deletedOnly` ⇔ `== true` ; `includeDeleted` ⇔ champ
  ///   **présent** (booléen) — l'absent reste hors de tout scope strict.
  /// - **[ZDeletionSemantics.absentMeansAlive]** : un document est « supprimé »
  ///   ssi `is_deleted == true` **OU** [_isLegacyDeleted]. `aliveOnly` = non
  ///   supprimé (l'**absence** du champ = vivant) ; `deletedOnly` = supprimé ;
  ///   `includeDeleted` = tout.
  bool _matchesScope(Map<String, dynamic> data, ZDeletedScope scope) {
    switch (_deletionSemantics) {
      case ZDeletionSemantics.strict:
        switch (scope) {
          case ZDeletedScope.aliveOnly:
            return data[_kIsDeleted] == false;
          case ZDeletedScope.deletedOnly:
            return data[_kIsDeleted] == true;
          case ZDeletedScope.includeDeleted:
            return data[_kIsDeleted] is bool;
        }
      case ZDeletionSemantics.absentMeansAlive:
        final deleted = data[_kIsDeleted] == true || _isLegacyDeleted(data);
        switch (scope) {
          case ZDeletedScope.aliveOnly:
            return !deleted;
          case ZDeletedScope.deletedOnly:
            return deleted;
          case ZDeletedScope.includeDeleted:
            return true;
        }
    }
  }

  /// Décode une liste de documents en **écartant** les corrompus (défensif) et
  /// les hors-[scope]. En mode strict c'est du belt-and-suspenders (les clauses
  /// serveur excluent déjà — [_matchesScope] réaligne la couche applicative sur
  /// la MÊME sémantique) ; en mode `absentMeansAlive` c'est **LE**
  /// filtre (lecture sans clause `is_deleted`, coût documenté sur
  /// [ZDeletionSemantics.absentMeansAlive]).
  List<T> _decodeDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    ZDeletedScope scope,
  ) {
    final out = <T>[];
    for (final d in docs) {
      final data = d.data();
      if (!_matchesScope(data, scope)) continue;
      final entity = _decode(d.id, data);
      if (entity != null) out.add(entity);
    }
    return out;
  }

  // ───────────────────────── Traduction ZDataRequest → Query ──────

  /// Requête de base pour un [scope] donné, selon [_deletionSemantics] :
  ///
  /// - **[ZDeletionSemantics.strict]** — clauses **serveur** :
  ///   - `aliveOnly` : égalité `is_deleted == false` (choix délibéré :
  ///     l'égalité — contrairement à `isNotEqualTo` — n'impose PAS de premier
  ///     `orderBy`, n'entre pas en conflit avec le tie-break `id`, et laisse
  ///     `count()` fonctionner). L'égalité Firestore **exige la
  ///     présence** du champ — un document SANS `is_deleted` est exclu ICI
  ///     (serveur) ; la couche applicative [_matchesScope] applique la MÊME
  ///     sémantique (get/getAll/watch cohérents). Précondition « collection
  ///     zcrud-native » : tout document écrit par [save] porte
  ///     `is_deleted=false` (invariant exécutoire, cf. [_encode]).
  ///   - `deletedOnly` : égalité `is_deleted == true` (corbeille).
  ///   - `includeDeleted` : `whereIn: [false, true]` — exige la présence du
  ///     champ (l'absent reste exclu, cohérent avec strict). Firestore borne
  ///     le nombre de clauses `in` par requête : combiner `includeDeleted` avec
  ///     un `ZFilterOp.isIn` peut exiger un découpage côté appelant.
  /// - **[ZDeletionSemantics.absentMeansAlive]** — **AUCUNE** clause
  ///   `is_deleted` (Firestore ne sait pas exprimer `!= true OU absent`) : le
  ///   scope est appliqué **client** au décodage ([_decodeDocs] /
  ///   [_matchesScope]), coût documenté sur l'enum.
  Query<Map<String, dynamic>> _scopedQuery(
    ZDeletedScope scope, [
    String? path,
  ]) {
    final raw = _rawCollection(path);
    switch (_deletionSemantics) {
      case ZDeletionSemantics.strict:
        switch (scope) {
          case ZDeletedScope.aliveOnly:
            return raw.where(_kIsDeleted, isEqualTo: false);
          case ZDeletedScope.deletedOnly:
            return raw.where(_kIsDeleted, isEqualTo: true);
          case ZDeletedScope.includeDeleted:
            return raw.where(_kIsDeleted, whereIn: const <bool>[false, true]);
        }
      case ZDeletionSemantics.absentMeansAlive:
        return raw;
    }
  }

  /// Requête de base historique : scope [ZDeletedScope.aliveOnly] (exclusion
  /// des soft-deleted) — voie des chemins SANS `ZDataRequest` ([watchAll]).
  Query<Map<String, dynamic>> _baseQuery([String? path]) =>
      _scopedQuery(ZDeletedScope.aliveOnly, path);

  /// Applique les [filters] par **chaînage IMMUABLE** (réaffectation
  /// systématique — une `Query` est immuable, `where(...)`
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
          // `arrayContains` (appartenance à un champ collection).
          // La « sous-chaîne texte » n'est PAS supportée nativement.
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
  /// limit) par **chaînage immuable**. Le tie-break final `orderBy(id)` sur
  /// le **champ `id` logique** (stocké dans le corps de chaque document par
  /// [_encode]/[save]) garantit un ordre **total et stable** aux clés de tri
  /// égales, cohérent avec `ZCursor` (départage par `id`).
  ///
  /// **Choix du champ `id` de corps comme tie-break, plutôt que
  /// `FieldPath.documentId`, PROUVÉ.** L'alternative (tie-break
  /// `orderBy(FieldPath.documentId)`, toujours présent en prod, donc SANS
  /// exclusion silencieuse) a été **testée et écartée** : le backend de test
  /// `fake_cloud_firestore` **REJETTE** `startAfter([...values, id])` quand un
  /// `orderBy` porte sur `documentId` — son évaluation interne appelle
  /// `doc.get(FieldPath.documentId)` et lève `Invalid argument(s): key must be
  /// String or FieldPath but found FieldPathType`. La pagination devient donc
  /// infaisable en test sous cette alternative. On retient le champ `id` de
  /// corps — sous la **précondition « collection zcrud-native »** (dartdoc de
  /// classe) : tout document écrit par [save] porte son `id` de corps (invariant
  /// exécutoire). En **prod**, `orderBy('id')` **exclut** tout document
  /// dépourvu de corps `id` (documents non-zcrud → backfill d'onboarding requis).
  /// Le fake N'imite PAS cette exclusion (il classe le champ absent comme
  /// `null`), donc un test ne peut prouver l'exclusion prod — il prouve
  /// l'invariant [save]-écrit-`id` qui la neutralise.
  ///
  /// **Index composites requis EN PROD.** Une requête combinant un
  /// `where` d'inégalité (`>`, `>=`, `<`, `<=`) OU un `where(is_deleted==false)`
  /// AVEC un `orderBy(champ)` + le tie-break `orderBy('id')` exige un **index
  /// composite** Firestore (`firestore.indexes.json`), sinon la prod lève
  /// `FAILED_PRECONDITION` → `ZServerFailure`. `fake_cloud_firestore` n'exige aucun
  /// index (faux vert). Les index sont à provisionner à l'intégration/déploiement
  /// — non fournis par cet adaptateur (backend-agnostique, AD-5).
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
    // par curseur) — un `ZDataRequest()` vide reste SANS clause d'ordre.
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

  // ───────────────────────── Enveloppe d'erreurs unique ──────────

  /// Enveloppe **unique** de toute opération : `FirebaseException → ZServerFailure`
  /// ; un `ZFailure` levé volontairement est repropagé ; toute autre erreur →
  /// `ZServerFailure` typé. **JAMAIS** de `catch(_){}`. Le corps décide
  /// lui-même des `Left`/`Right` métier (`null ≠ erreur`).
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

  // ───────────────────────── Lectures ───────────────────────

  @override
  Stream<List<T>> watchAll() =>
      _watchQuery(_baseQuery, ZDeletedScope.aliveOnly);

  @override
  Stream<List<T>> watch(ZDataRequest request) => _watchQuery(
        () => _buildQuery(_scopedQuery(request.deletedScope), request),
        request.deletedScope,
      );

  /// Flux **NU** (AD-11) : seed immédiat (état courant) puis mutations. Les
  /// non-visibles/corrompus sont exclus. Une collection vide émet `[]`.
  /// L'abonnement upstream est tracé pour [dispose].
  ///
  /// La `Query` est construite par [build] **DANS**
  /// `onListen`, sous garde `try/catch`. Un throw **SYNCHRONE** à la construction
  /// (ex. `_firestore.collection(...)` lève une `FirebaseException`) ou à
  /// l'abonnement est **poussé dans le canal du stream** ([StreamController.
  /// addError]) — **jamais** relancé synchroniquement vers l'appelant. Les
  /// erreurs **runtime** de `snapshots()` transitent par le même canal
  /// (`onError`). Aucune exception ne remonte hors du flux.
  Stream<List<T>> _watchQuery(
    Query<Map<String, dynamic>> Function() build,
    ZDeletedScope scope,
  ) {
    late final StreamController<List<T>> controller;
    // L'abonnement source `snapshots()` est capturé
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
              // Une exception DANS le callback (`_decodeDocs`)
              // est routée vers le canal d'erreur — miroir du `onError` — au lieu
              // de devenir une erreur asynchrone non gérée.
              try {
                controller.add(_decodeDocs(snap.docs, scope));
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
          // en erreur de FLUX (jamais d'exception qui remonte à l'appelant).
          _log('construction du flux firestore en erreur (kind=$_kind)',
              error: e, stackTrace: s);
          controller.addError(_toFailure(e));
        }
      },
      onCancel: () async {
        // Libère la souscription source + le contrôleur dès
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
        final scope = request?.deletedScope ?? ZDeletedScope.aliveOnly;
        final query = request == null
            ? _scopedQuery(scope)
            : _buildQuery(_scopedQuery(scope), request);
        final snap = await query.get();
        return Right<ZFailure, List<T>>(_decodeDocs(snap.docs, scope));
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
        // Visibilité ALIGNÉE sur getAll/watch (même prédicat
        // `_matchesScope(…, aliveOnly)` selon la sémantique configurée) :
        // - strict : un `is_deleted` ABSENT (doc non-zcrud-native) est exclu
        //   ICI AUSSI, comme le filtre serveur l'exclut de getAll/watch ;
        // - absentMeansAlive : un doc SANS `is_deleted` est VISIBLE ici aussi
        //   (absent = vivant), le supprimé (canonique OU legacy) reste exclu.
        // → aucune divergence get vs getAll/watch, quelle que soit la sémantique.
        if (!_matchesScope(data, ZDeletedScope.aliveOnly)) {
          return Left<ZFailure, T>(
            ZNotFoundFailure(
              data[_kIsDeleted] == true || _isLegacyDeleted(data)
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
        // (+ le scope de suppression) comptent.
        final scope = request?.deletedScope ?? ZDeletedScope.aliveOnly;
        final query = _applyFilters(
          _scopedQuery(scope),
          request?.filters ?? const <ZFilter>[],
        );
        if (_deletionSemantics == ZDeletionSemantics.absentMeansAlive) {
          // Coût du mode compat (cf. ZDeletionSemantics.absentMeansAlive) :
          // l'agrégat serveur `count()` ne sait pas exprimer « != true OU
          // absent » — décompte CLIENT sur les documents lus, aligné sur le
          // MÊME prédicat que les listes (`_matchesScope`).
          final snap = await query.get();
          var n = 0;
          for (final d in snap.docs) {
            if (_matchesScope(d.data(), scope)) n++;
          }
          return Right<ZFailure, int>(n);
        }
        final agg = await query.count().get();
        return Right<ZFailure, int>(agg.count ?? 0);
      });

  // ───────────────────────── Écritures ─────────────────────────

  /// Persiste [item] en **écrasement TOTAL** (`batch.set`, JAMAIS un merge) puis
  /// relit l'entité persistée (round-trip).
  ///
  /// **Comportement full-write, INTENTIONNEL :**
  /// - [_encode] réécrit **inconditionnellement** `is_deleted:false` +
  ///   `updated_at=now` → re-sauver une entité **soft-deletée la RESSUSCITE**
  ///   (redevient visible). Assumé (invariant « save ⇒ vivant »).
  /// - tout champ hors [_toMap]/[_encode] présent sur le document existant est
  ///   **écrasé** (`set` remplace le document entier) — aucune préservation de
  ///   méta concurrente.
  ///
  /// Le **merge Last-Write-Wins** sur `updated_at` (offline-first, préservation
  /// des écritures concurrentes) est la responsabilité de la couche de
  /// synchronisation offline-first — hors du périmètre de cet adaptateur.
  @override
  Future<ZResult<T>> save(T item, {String? collectionId}) => _guard(() async {
        final collection = _rawCollection(collectionId);
        // Matérialisation de l'éphémère (AD-14, invariant porté par le repo).
        // `isEphemeral` fait foi, pas `id == null`.
        final id = item.isEphemeral ? collection.doc().id : item.id!;
        // Le corps porte TOUJOURS son `id` logique (clé du tie-break) en
        // plus des métadonnées `ZSyncMeta` fusionnées par [_encode].
        final map = _encode(item)..[_kId] = id;

        // Écriture ATOMIQUE via WriteBatch committé (jamais partielle).
        final batch = _firestore.batch();
        batch.set(collection.doc(id), map);
        await batch.commit();

        // Round-trip fidèle : relecture via la collection **typée**
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
  /// `WriteBatch` committé. `id` inconnu → `Left(ZNotFoundFailure)`.
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

  // ───────────────────────── Sync offline-first ───────────────────────

  /// **Voie de lecture de SYNCHRONISATION** : lit **TOUS** les documents
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

  /// **Écriture PRÉSERVANT la méta** d'une **seule** [entry] : `batch.set`
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

  /// **Propagation PAR LOT BORNÉE** (AD-9) d'un changeset d'[entries],
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
  /// Applique AUSSI le hint de type (`_applyTimestampHints`) sur
  /// cette voie d'écriture (sync/merge offline-first), pas seulement `_encode`
  /// (save). Sinon `created_at` finirait en types MIXTES sur disque (Timestamp pour
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
