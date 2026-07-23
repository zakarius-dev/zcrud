/// Adaptateur **Hive** concret du port neutre `ZLocalStore<T>` (E5-2).
///
/// origine: canonique §7 — store LOCAL **source de vérité** offline-first (AD-9).
/// Réplique côté cache les corrections d'E5-1 : invariant **corps `id`** toujours
/// écrit (MAJEUR-1), visibilité `is_deleted` **cohérente** get/getAll/watch
/// (MAJEUR-2), décodage **défensif** (AD-10, un corrompu parmi N → N-1),
/// soft-delete **hors-entité** (`ZSyncMeta`), erreurs enveloppées en
/// `Left(ZCacheFailure)` (AD-11, jamais de `catch(_){}`).
///
/// **Isolation AD-5 (CRUCIAL)** : `package:hive` est importé **uniquement** ici.
/// Aucun type Hive (`Box`, `HiveObject`, `HiveInterface`, `BoxEvent`,
/// `HiveError`) ne fuit dans une **signature publique de méthode** — toutes
/// restent `ZResult<…>` / `Stream<List<T>>` **nues**. L'injection d'une
/// [Box] au constructeur (ou l'ouverture via [openBox]) est la SEULE couture
/// (voulue) vers le backend — exactement comme E5-1 injecte `FirebaseFirestore`.
///
/// **Stockage JSON sans `TypeAdapter`** : chaque entité est persistée comme
/// **JSON** (`jsonEncode` de la map codée) keyée par son `id` — pas de codegen
/// Hive. Le décodage relit la chaîne, la reparse et route par la voie défensive.
///
/// **Frontière de story (ne PAS déborder)** : E5-2 = le store local + son port.
/// Le **merge Last-Write-Wins** sur `updatedAt` (E5-3), la cascade bornée ≤ 450
/// (E5-3) et le `ZSyncOrchestrator`/débounce (E5-4) sont **hors périmètre** —
/// aucune méthode `sync()`/`merge()` ici. La suppression locale est un
/// **soft-delete** (drapeau), jamais une purge physique ([clear] est une
/// maintenance distincte du chemin de suppression métier).
library;

// `prefer_initializing_formals` est un FAUX POSITIF ici : les champs de config
// sont **privés** et exposés en paramètres **nommés**. Dart interdit un formal
// d'initialisation nommé privé (`this._x`) — l'assignation en liste
// d'initialisation est la SEULE forme possible. Désactivé au niveau fichier pour
// garder `analyze` à zéro info (gate melos fatal-infos), comme en E5-1.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Journal minimal **neutre** de l'adaptateur (type public sans dépendance
/// Hive). Une entrée non décodable ou une erreur de flux est **loggée** ici puis
/// écartée (AD-10) — jamais avalée silencieusement. Miroir de `ZFirestoreLog`
/// d'E5-1 (aucun port `ZLogger` n'existe dans `zcrud_core` — hors périmètre).
typedef ZLocalStoreLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Adaptateur Hive de [ZLocalStore] pour l'agrégat [T].
///
/// **Injection** (pas de singleton statique — testabilité) : la [Box] Hive (ou
/// [openBox] en prod), le [kind], le couple (dé)sérialisation typé
/// (`fromMap`/`toMap`), une voie de décodage **défensive** optionnelle
/// (`fromMapSafe`, ex. `ZModelAdapter.fromMapSafe`), un [ZLocalStoreLog]
/// optionnel, une fabrique d'`id` opaque optionnelle (matérialisation de
/// l'éphémère, AD-14).
class HiveZLocalStore<T extends ZEntity> extends ZLocalStore<T> {
  /// Construit l'adaptateur à partir d'une [Box] déjà ouverte (couture DI —
  /// injectée en test ; fournie par [openBox] en prod).
  HiveZLocalStore({
    required Box<dynamic> box,
    required String kind,
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    T? Function(Map<String, dynamic> map)? fromMapSafe,
    String Function()? idFactory,
    ZLocalStoreLog? logger,
    ZClock? clock,
    bool ownsBox = false,
  })  : _box = box,
        _kind = kind,
        _fromMap = fromMap,
        _toMap = toMap,
        _fromMapSafe = fromMapSafe,
        _idFactory = idFactory ?? _defaultIdFactory,
        _log = logger ?? _noopLog,
        // CR-LEX-36 : source de temps de la clé LWW. Défaut = horloge système
        // (comportement historique). Un hôte peut injecter une horloge corrigée.
        _clock = clock ?? ZSystemClock.utc,
        _ownsBox = ownsBox;

  /// Ouvre (ou réutilise) la box du [kind] via Hive puis construit l'adaptateur
  /// **sans** exposer de type Hive. Prod : `Hive.initFlutter()` (app) doit avoir
  /// été appelé au préalable. La box ainsi ouverte est **possédée** ([dispose]
  /// la ferme).
  static Future<HiveZLocalStore<T>> openBox<T extends ZEntity>({
    required String kind,
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    T? Function(Map<String, dynamic> map)? fromMapSafe,
    String Function()? idFactory,
    ZLocalStoreLog? logger,
    ZClock? clock,
  }) async {
    final box = await Hive.openBox<dynamic>(boxNameFor(kind));
    return HiveZLocalStore<T>(
      box: box,
      kind: kind,
      fromMap: fromMap,
      toMap: toMap,
      fromMapSafe: fromMapSafe,
      idFactory: idFactory,
      logger: logger,
      clock: clock,
      ownsBox: true,
    );
  }

  /// Nom de box **dérivé du [kind]** (une box par entité/kind).
  static String boxNameFor(String kind) => 'zcrud_$kind';

  final Box<dynamic> _box;
  final String _kind;
  final T Function(Map<String, dynamic> map) _fromMap;
  final Map<String, dynamic> Function(T value) _toMap;
  final T? Function(Map<String, dynamic> map)? _fromMapSafe;
  final String Function() _idFactory;
  final ZLocalStoreLog _log;
  /// CR-LEX-36 : source de temps de la clé LWW `updated_at`.
  final ZClock _clock;
  final bool _ownsBox;

  /// Clé snake_case du drapeau de soft-delete (`ZSyncMeta`, hors-entité).
  /// **AD-19** : alias de la définition machine unique (dette DW-ES13-1 soldée).
  static const String _kIsDeleted = ZSyncMeta.kIsDeleted;

  /// Clé snake_case de l'horodatage LWW (`ZSyncMeta`, ISO-8601).
  /// **AD-19** : alias de la définition machine unique (dette DW-ES13-1 soldée).
  ///
  /// **Immunité structurelle au vecteur M3 (Timestamp legacy)** : ce store
  /// persiste du **JSON** (`jsonEncode`/`jsonDecode`) — un `Timestamp` Firestore
  /// n'y est pas représentable (`jsonEncode` lèverait). Toute valeur relue de la
  /// box est donc un scalaire JSON, et `updated_at` y est **toujours** une String
  /// ISO-8601 écrite par [_encode]/[applyMerged]/[_setDeletedFlag]. La
  /// normalisation `Timestamp → ISO` d'AD-19/M3 est **inutile ici** ; elle vit
  /// dans l'adapter Firestore (`firebase_z_repository_impl.dart` `_inject`), seul
  /// chemin exposé aux documents legacy DODLP.
  static const String _kUpdatedAt = ZSyncMeta.kUpdatedAt;

  /// Clé logique d'identité écrite dans le corps (invariant clé↔corps).
  static const String _kId = 'id';

  static final Random _random = Random();

  /// Fabrique d'`id` opaque par défaut (matérialisation de l'éphémère, AD-14) —
  /// aucun couplage à un paquet `uuid` (out-degree du graphe inchangé).
  static String _defaultIdFactory() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final rand = _random.nextInt(0x7fffffff).toRadixString(36);
    return '$now-$rand';
  }

  final List<StreamController<List<T>>> _controllers =
      <StreamController<List<T>>>[];
  final List<StreamSubscription<BoxEvent>> _subs =
      <StreamSubscription<BoxEvent>>[];

  bool _disposed = false;

  /// Future de fermeture de la box **possédée**, capturé par [dispose] pour être
  /// **observable EN TEST** uniquement (le contrat de port [dispose] reste
  /// `void` — fermeture fire-and-forget). `null` tant que [dispose] n'a pas
  /// fermé une box possédée. Permet aux tests de synchroniser leur `tearDown`
  /// sur la fin RÉELLE de la fermeture (au lieu d'un délai fixe fragile).
  Future<void>? _closing;

  /// (Test-only) Future de fin de fermeture de la box possédée — voir [_closing].
  @visibleForTesting
  Future<void>? get closedForTest => _closing;

  /// (Test-only) Nombre d'abonnements `box.watch()` encore VIVANTS — prouve
  /// qu'un `onCancel` libère bien la souscription source (anti-fuite MEDIUM-1).
  @visibleForTesting
  int get activeSourceSubscriptions => _subs.length;

  /// (Test-only) Nombre de `StreamController` de flux encore alloués (anti-fuite).
  @visibleForTesting
  int get activeStreamControllers => _controllers.length;

  // ───────────────────────── (Dé)codage ─────────────────────────────────────

  /// Encode [value] + fusionne les métadonnées `ZSyncMeta` (updated_at ISO-8601,
  /// is_deleted=false) + écrit **toujours** le corps `id` (invariant clé↔corps,
  /// MAJEUR-1). Jamais de `DateTime`/`Timestamp` brut (AD-5) : ISO-8601.
  ///
  /// **LOW-3 — `put` RESSUSCITE un soft-deleté (cohérent E5-1) :** `is_deleted`
  /// est réécrit **inconditionnellement** à `false`. Re-`put` d'une entité
  /// précédemment soft-deletée la **rend de nouveau visible** (invariant « save
  /// ⇒ vivant »). Le merge Last-Write-Wins sur `updated_at` (préservation des
  /// écritures concurrentes) reste la responsabilité d'**E5-3**.
  Map<String, dynamic> _encode(T value, String id) {
    final map = Map<String, dynamic>.of(_toMap(value));
    map[_kId] = id;
    final meta =
        ZSyncMeta(updatedAt: _clock(), isDeleted: false).toJson();
    map[_kUpdatedAt] = meta[_kUpdatedAt];
    map[_kIsDeleted] = false;
    return map;
  }

  /// Reparse **défensif** de l'entrée brute Hive en map. Une valeur non-`String`
  /// (type inattendu), un JSON illisible (tronqué) ou un JSON non-objet →
  /// `null` (écarté + loggé, AD-10), jamais de `throw` propagé. L'`id` de clé est
  /// (ré)injecté dans le corps.
  Map<String, dynamic>? _rawMap(String id, Object? stored) {
    if (stored is! String) {
      _log('entrée Hive non-String (kind=$_kind, id=$id) — écartée');
      return null;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException catch (e, s) {
      _log('entrée Hive JSON illisible (kind=$_kind, id=$id) — écartée',
          error: e, stackTrace: s);
      return null;
    }
    if (decoded is! Map<String, dynamic>) {
      _log('entrée Hive JSON non-objet (kind=$_kind, id=$id) — écartée');
      return null;
    }
    decoded[_kId] = id;
    return decoded;
  }

  /// Décodage **DÉFENSIF** (AD-10) : `fromMapSafe` s'il existe, sinon enveloppe
  /// locale de `fromMap`. Une map non décodable (champ manquant, enum inconnu,
  /// type inattendu) → `null` (écarté + loggé), jamais de `throw`.
  T? _decodeEntity(String id, Map<String, dynamic> map) {
    final safe = _fromMapSafe;
    if (safe != null) {
      final decoded = safe(map);
      if (decoded == null) {
        _log('entrée non décodable (kind=$_kind, id=$id) — écartée');
      }
      return decoded;
    }
    try {
      return _fromMap(map);
    } on Object catch (e, s) {
      _log('entrée non décodable (kind=$_kind, id=$id) — écartée',
          error: e, stackTrace: s);
      return null;
    }
  }

  /// Une entrée est **VISIBLE** ssi `is_deleted == false` — sémantique appliquée
  /// de façon **COHÉRENTE** sur getById / getAll / watchAll (MAJEUR-2). Un
  /// `is_deleted` **ABSENT** (entrée non-zcrud-native) OU `== true` (soft-deleted)
  /// est traité comme **non visible** sur TOUS les chemins (aucune divergence).
  bool _isVisible(Map<String, dynamic> map) => map[_kIsDeleted] == false;

  /// Lit une entrée : corrompue OU non visible → `null` ; sinon l'entité décodée.
  T? _readVisible(String id, Object? stored) {
    final map = _rawMap(id, stored);
    if (map == null) return null;
    if (!_isVisible(map)) return null;
    return _decodeEntity(id, map);
  }

  /// Instantané des visibles décodés, **tri stable par `id`** (ordre total).
  List<T> _snapshot() {
    final out = <T>[];
    for (final key in _box.keys) {
      final id = key.toString();
      final entity = _readVisible(id, _box.get(key));
      if (entity != null) out.add(entity);
    }
    out.sort((a, b) => (a.id ?? '').compareTo(b.id ?? ''));
    return out;
  }

  // ───────────────────────── Enveloppe d'erreurs (AD-11) ─────────────────────

  /// Enveloppe **unique** : un `ZFailure` levé volontairement est repropagé ;
  /// une `HiveError` (box fermée/corrompue, I/O) ou toute autre erreur d'accès →
  /// `Left(ZCacheFailure)` (le local est un **cache**). **JAMAIS** de `catch(_){}`.
  Future<ZResult<R>> _guard<R>(Future<ZResult<R>> Function() body) async {
    try {
      return await body();
    } on ZFailure catch (f) {
      return Left<ZFailure, R>(f);
    } on HiveError catch (e, s) {
      _log('HiveError (kind=$_kind)', error: e, stackTrace: s);
      return Left<ZFailure, R>(ZCacheFailure(e.message));
    } on Object catch (e, s) {
      _log('erreur cache inattendue (kind=$_kind)', error: e, stackTrace: s);
      return Left<ZFailure, R>(ZCacheFailure(e.toString()));
    }
  }

  /// Mappe une erreur brute en [ZFailure] pour la voie **FLUX** (miroir [_guard]).
  ZFailure _toFailure(Object e) {
    if (e is ZFailure) return e;
    if (e is HiveError) return ZCacheFailure(e.message);
    return ZCacheFailure(e.toString());
  }

  // ───────────────────────── Lectures (AC4/5/6/8/9) ──────────────────────────

  @override
  Stream<List<T>> watchAll() {
    late final StreamController<List<T>> controller;
    // MEDIUM-1 : l'abonnement source `box.watch()` est capturé pour être ANNULÉ
    // à l'annulation du flux (`onCancel`) — pas seulement au `dispose()`. Sans
    // cela, chaque `watchAll()` empilerait un contrôleur + un abonnement vivants
    // (fuite non bornée sur un store à longue durée de vie).
    StreamSubscription<BoxEvent>? sub;
    controller = StreamController<List<T>>(
      onListen: () {
        try {
          controller.add(_snapshot()); // seed immédiat
          sub = _box.watch().listen(
            (_) {
              // LOW-1 : une exception DANS le callback (ex. `_snapshot()` sur box
              // fermée en cours de flux) est routée vers le canal d'erreur —
              // miroir du `onError` — au lieu de devenir une erreur asynchrone
              // non gérée qui contournerait le stream.
              try {
                controller.add(_snapshot());
              } on Object catch (e, s) {
                _log('événement hive en erreur (kind=$_kind)',
                    error: e, stackTrace: s);
                controller.addError(_toFailure(e));
              }
            },
            onError: (Object e, StackTrace s) {
              _log('flux hive en erreur (kind=$_kind)', error: e, stackTrace: s);
              controller.addError(_toFailure(e));
            },
          );
          _subs.add(sub!);
        } on Object catch (e, s) {
          _log('construction du flux hive en erreur (kind=$_kind)',
              error: e, stackTrace: s);
          controller.addError(_toFailure(e));
        }
      },
      onCancel: () async {
        // MEDIUM-1 : libère la souscription source + le contrôleur dès que le
        // consommateur annule (ex. `.first`, changement d'écran) — sans attendre
        // `dispose()`. Idempotent avec `dispose()` (retraits sur listes).
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

  @override
  Future<ZResult<List<T>>> getAll() =>
      _guard(() async => Right<ZFailure, List<T>>(_snapshot()));

  @override
  Future<ZResult<T>> getById(String id) => _guard(() async {
        if (!_box.containsKey(id)) {
          return Left<ZFailure, T>(
            ZNotFoundFailure('Entité introuvable', id: id, entity: _kind),
          );
        }
        final map = _rawMap(id, _box.get(id));
        if (map == null) {
          return Left<ZFailure, T>(
            ZNotFoundFailure('Entrée corrompue', id: id, entity: _kind),
          );
        }
        if (!_isVisible(map)) {
          return Left<ZFailure, T>(
            ZNotFoundFailure(
              map[_kIsDeleted] == true
                  ? 'Entité soft-deleted'
                  : 'Entité non visible (is_deleted absent — hors invariant '
                      'zcrud-native)',
              id: id,
              entity: _kind,
            ),
          );
        }
        final entity = _decodeEntity(id, map);
        if (entity == null) {
          return Left<ZFailure, T>(
            ZNotFoundFailure('Entrée corrompue', id: id, entity: _kind),
          );
        }
        return Right<ZFailure, T>(entity);
      });

  // ───────────────────────── Sync offline-first (E5-3) ───────────────────────

  /// **Voie de lecture de SYNCHRONISATION** (E5-3) : renvoie **toutes** les
  /// entrées **y compris soft-deletées** (tombstones), chacune appariée à son
  /// [ZSyncMeta]. **NE PASSE PAS** par [_isVisible] (contraste voulu avec
  /// [getAll], qui exclut les tombstones — indispensable au merge LWW pour
  /// propager une suppression). Décodage **défensif** (AD-10) : une entrée
  /// corrompue/non décodable est **écartée + loggée**, jamais un `throw`. Tri
  /// stable par `id` (ordre total). Erreur d'accès → `Left(ZCacheFailure)`.
  @override
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries() => _guard(() async {
        final out = <ZSyncEntry<T>>[];
        for (final key in _box.keys) {
          final id = key.toString();
          final map = _rawMap(id, _box.get(key));
          if (map == null) continue; // corrompu → écarté + loggé par _rawMap
          final entity = _decodeEntity(id, map);
          if (entity == null) continue; // non décodable → écarté (AD-10)
          out.add(
            ZSyncEntry<T>(entity: entity, meta: ZSyncMeta.fromJson(map)),
          );
        }
        out.sort((a, b) => (a.id ?? '').compareTo(b.id ?? ''));
        return Right<ZFailure, List<ZSyncEntry<T>>>(out);
      });

  /// **Écriture PRÉSERVANT la méta** (E5-3) : écrit l'entité **et** son
  /// [ZSyncMeta] **verbatim** — `updated_at`/`is_deleted` **conservés tels quels**
  /// (jamais `now()`, contrairement à [put]). RÉSERVÉ à l'application d'un
  /// résultat de merge (défaire l'estampille `now()` casserait le LWW). Le corps
  /// porte **toujours** son `id` (invariant clé↔corps). Écrire une [entry]
  /// `isDeleted:true` **propage un tombstone**. `box.watch()` réémet le flux.
  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry) => _guard(() async {
        final id = entry.entity.id;
        if (id == null) {
          return Left<ZFailure, Unit>(
            ZDomainFailure(
              'applyMerged requiert une entité matérialisée (id non-null) '
              '(kind=$_kind)',
            ),
          );
        }
        final map = Map<String, dynamic>.of(_toMap(entry.entity));
        map[_kId] = id; // invariant clé↔corps
        final meta = entry.meta.toJson();
        map[_kUpdatedAt] = meta[_kUpdatedAt]; // verbatim (peut être null)
        map[_kIsDeleted] = entry.meta.isDeleted; // verbatim (tombstone possible)
        await _box.put(id, jsonEncode(map));
        return Right<ZFailure, Unit>(unit);
      });

  // ───────────────────────── Écritures (AC6/7/9) ─────────────────────────────

  /// Persiste [item] (écrasement JSON total keyé par son `id`) puis relit
  /// l'entrée pour un round-trip fidèle. **LOW-3** : re-`put` d'une entité
  /// soft-deletée la **RESSUSCITE** (`is_deleted` forcé à `false` par [_encode],
  /// cohérent E5-1 ; merge LWW = E5-3).
  @override
  Future<ZResult<T>> put(T item) => _guard(() async {
        // Matérialisation de l'éphémère (AD-14, invariant porté par le store).
        final id = item.id ?? _idFactory();
        final map = _encode(item, id);
        await _box.put(id, jsonEncode(map));

        // Round-trip fidèle : relecture + re-décodage de l'entrée persistée.
        final reread = _rawMap(id, _box.get(id));
        final decoded = reread == null ? null : _decodeEntity(id, reread);
        if (decoded == null) {
          return Left<ZFailure, T>(
            ZDomainFailure('Entité écrite mais non re-décodable (kind=$_kind)'),
          );
        }
        return Right<ZFailure, T>(decoded);
      });

  /// Écriture PRÉSERVANTE (CR-LEX-34) : fusionne la map de [item] PAR-DESSUS le
  /// document brut existant. Une clé présente en base mais absente de [item]
  /// (autre hôte, champ hors-codegen non relu) **survit**.
  ///
  /// Le merge est fait sur la **map brute** stockée — seule couche qui voit les
  /// clés non mappées : décoder en `T` puis ré-encoder les perdrait, sauf
  /// celles que `extra` a capturées. On lit donc le JSON brut et on superpose
  /// `{...existant, ...encodé}` : l'encodé (donc [item] + méta fraîche) gagne
  /// par clé, l'existant-seul survit. Absent en base ⇒ création (= [put]).
  @override
  Future<ZResult<T>> putMerged(T item) => _guard(() async {
        final id = item.id ?? _idFactory();
        final encoded = _encode(item, id);
        final existing = _rawMap(id, _box.get(id));
        final merged = existing == null
            ? encoded
            : <String, dynamic>{...existing, ...encoded};
        await _box.put(id, jsonEncode(merged));

        final reread = _rawMap(id, _box.get(id));
        final decoded = reread == null ? null : _decodeEntity(id, reread);
        if (decoded == null) {
          return Left<ZFailure, T>(
            ZDomainFailure('Entité fusionnée mais non re-décodable (kind=$_kind)'),
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

  /// Purge physique par identité (CR-LEX-35) : `box.delete(id)`, **sans**
  /// tombstone. Idempotent — purger un `id` absent est un succès.
  @override
  Future<ZResult<Unit>> purge(String id) => _guard(() async {
        await _box.delete(id);
        return Right<ZFailure, Unit>(unit);
      });

  /// Bascule `is_deleted` **hors-entité** (aucun champ métier touché), réécrit
  /// `updated_at` (ISO-8601). `id` absent → `Left(ZNotFoundFailure)`. **Jamais**
  /// de `box.delete` (soft-delete par drapeau — la propagation distante = E5-3).
  Future<ZResult<Unit>> _setDeletedFlag(String id, {required bool deleted}) =>
      _guard(() async {
        if (!_box.containsKey(id)) {
          return Left<ZFailure, Unit>(
            ZNotFoundFailure('Entité introuvable', id: id, entity: _kind),
          );
        }
        final map = _rawMap(id, _box.get(id));
        if (map == null) {
          return Left<ZFailure, Unit>(
            ZNotFoundFailure('Entrée corrompue', id: id, entity: _kind),
          );
        }
        map[_kIsDeleted] = deleted;
        map[_kUpdatedAt] = _clock().toIso8601String();
        await _box.put(id, jsonEncode(map));
        return Right<ZFailure, Unit>(unit);
      });

  @override
  Future<ZResult<Unit>> clear() => _guard(() async {
        await _box.clear();
        return Right<ZFailure, Unit>(unit);
      });

  /// Libère TOUTES les ressources restantes : annule les abonnements `box.watch()`
  /// et ferme les `StreamController` encore vivants (ceux dont le flux a déjà été
  /// annulé se sont auto-libérés via `onCancel`, MEDIUM-1), puis ferme la box si
  /// elle est **possédée** ([_ownsBox], ouverte par [openBox]).
  ///
  /// **LOW-2 — fermeture NON attendable (fire-and-forget) :** le contrat de port
  /// [dispose] est `void` ; la fermeture de la box possédée (`_box.close()`,
  /// asynchrone) est donc lancée sans être attendue. Le Future correspondant est
  /// néanmoins capturé dans [closedForTest] pour permettre à un test de
  /// synchroniser son `tearDown`/`Hive.close()` sur la fin RÉELLE de la
  /// fermeture (au lieu d'un délai fixe fragile). En prod, l'app dispose au
  /// shutdown : l'absence d'attente est sans conséquence.
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
    if (_ownsBox) {
      _closing = _box.close();
      unawaited(_closing!);
    }
  }
}
