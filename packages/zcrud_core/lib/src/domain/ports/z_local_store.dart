/// Port **neutre** de la couche données : store **local** offline-first.
///
/// origine: canonique §7 — « à abstraire derrière `ZLocalStore`/`ZRemoteStore` ».
/// Introduit **avec** son adaptateur en E5 (différé explicitement par E2-2).
/// AD-5 (backend-agnostique) ; AD-9 (offline-first) ; AD-10 (défensif) ;
/// AD-11 (`Either`/flux nus) ; AD-14 (matérialisation de l'éphémère) ;
/// AD-16 (soft-delete hors-entité).
library;

import 'package:dartz/dartz.dart' show Unit;

import '../contracts/z_entity.dart';
import '../failures/z_failure.dart';
import '../sync/z_sync_entry.dart';

/// Contrat **abstrait** (port) du store **local** d'un agrégat [T] — la moitié
/// « qui fait autorité » du patron offline-first (AD-9).
///
/// **Source de vérité offline-first** (AD-9) : c'est le store local qui **fait
/// autorité**. Le distant ([ZRemoteStore]) est best-effort et ne dicte jamais
/// l'état ; la composition « local autoritaire ↔ distant fire-and-forget », le
/// **merge Last-Write-Wins** sur `updatedAt` et la cascade bornée sont
/// l'affaire d'**E5-3/E5-4** — **hors** de ce port (aucune méthode `sync()`/
/// `merge()` ici, frontière **volontaire**).
///
/// **Backend-agnostique** (AD-5) : aucune signature n'expose de type `hive`
/// (`Box`, `HiveObject`, `HiveInterface`…). L'implémentation par défaut est
/// Hive-JSON (`zcrud_firestore`), mais l'abstraction autorise un backend
/// **Isar/Drift/SQLite** ultérieur (déféré) **sans** changer ce contrat.
///
/// **Contrat de résultat** (AD-11) : les opérations retournent `ZResult<...>`
/// (`Either<ZFailure, T>`) / `ZResult<Unit>` ; le local étant un **cache**, une
/// erreur d'accès est un [CacheFailure] (jamais `ServerFailure`). Les **flux**
/// sont des `Stream<List<T>>` **NUS** — jamais enveloppés dans un `Either`.
///
/// **Invariants portés par l'impl** (AD-14/AD-16, documentés ici, non
/// implémentés) :
/// - [put] **matérialise l'éphémère** : une entité sans `id` (`isEphemeral`) se
///   voit attribuer une identité opaque à l'écriture ; le corps persisté porte
///   **toujours** son `id` (invariant clé↔corps).
/// - [softDelete]/[restore] basculent `is_deleted` **hors-entité** (`ZSyncMeta`,
///   AD-16) **sans** toucher aux champs métier ; la suppression locale est un
///   **soft-delete** (drapeau), **jamais** une purge physique. Les lectures
///   excluent les soft-deleted de façon **cohérente** (get / getAll / watch).
abstract class ZLocalStore<T extends ZEntity> {
  /// Flux temps réel **nu** des éléments **visibles** (non soft-deleted).
  ///
  /// Seed immédiat (état courant) puis ré-émission à chaque mutation
  /// ([put]/[softDelete]/[restore]). Jamais enveloppé dans un `Either` (AD-11).
  Stream<List<T>> watchAll();

  /// Lit tous les éléments **visibles** (exclut les soft-deleted). Un store vide
  /// renvoie `Right(<T>[])` (`vide ≠ erreur`).
  Future<ZResult<List<T>>> getAll();

  /// Lit l'élément d'identité [id]. `Left(NotFoundFailure)` s'il est absent ou
  /// soft-deleted (`null ≠ erreur`, AD-11).
  Future<ZResult<T>> getById(String id);

  /// Persiste [item] dans le cache local (source de vérité). Matérialise
  /// l'éphémère (attribution d'`id` opaque, AD-14) et renvoie l'entité
  /// matérialisée. Réécrit `is_deleted:false`/`updated_at` (`ZSyncMeta`).
  Future<ZResult<T>> put(T item);

  /// Soft-delete l'élément [id] (`is_deleted = true`, hors-entité `ZSyncMeta`).
  /// **Jamais** de purge physique. `id` absent → `Left(NotFoundFailure)`.
  Future<ZResult<Unit>> softDelete(String id);

  /// Restaure l'élément [id] soft-deleted (`is_deleted = false`). `id` absent →
  /// `Left(NotFoundFailure)`.
  Future<ZResult<Unit>> restore(String id);

  /// **Voie de lecture de SYNCHRONISATION** (E5-3) : lit **toutes** les entrées
  /// **y compris soft-deletées** (tombstones), chacune appariée à son
  /// [ZSyncMeta] (`updatedAt`/`isDeleted`). Un store vide → `Right(<ZSyncEntry>[])`.
  ///
  /// **Contraste voulu avec [getAll]** : [getAll] exclut les tombstones (lecture
  /// « visible »), alors que [syncEntries] les **inclut** — indispensable au merge
  /// Last-Write-Wins (E5-3), qui doit voir de **chaque côté** l'`updated_at` ET
  /// l'`is_deleted` de toute entrée pour propager une suppression. Décodage
  /// **défensif** (AD-10) : une entrée non décodable est **écartée + loggée**,
  /// jamais un `throw`. Erreur d'accès (cache) → `Left(CacheFailure)`.
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries();

  /// **Écriture PRÉSERVANT la méta** (E5-3) : écrit l'entité **et** son
  /// [ZSyncMeta] **verbatim** — `updated_at`/`is_deleted` **conservés tels quels**,
  /// **jamais** réestampillés `now()`.
  ///
  /// **RÉSERVÉ à l'application d'un résultat de merge** : [put] réestampille
  /// `updated_at = now()` (vraie mutation utilisateur) ; l'appliquer à un gagnant
  /// de merge casserait le LWW (le côté qui « adopte » paraîtrait toujours le plus
  /// récent → ping-pong). [applyMerged] est donc la voie **sans `now()`**, hors
  /// chemin d'écriture utilisateur. Écrire une [entry] `isDeleted:true` **propage
  /// un tombstone** (soft-delete). Le corps persiste **toujours** son `id`
  /// (invariant clé↔corps). Erreur d'accès → `Left(CacheFailure)`.
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry);

  /// **Purge physique** de tout le cache local (maintenance/tests) — distincte
  /// du [softDelete] métier. À NE PAS utiliser comme voie de suppression d'une
  /// entité (celle-ci reste un soft-delete propagé au distant en E5-3).
  Future<ZResult<Unit>> clear();

  /// Libère les ressources (abonnements, contrôleurs de flux, box possédée).
  void dispose();
}
