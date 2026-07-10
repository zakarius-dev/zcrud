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

  /// **Purge physique** de tout le cache local (maintenance/tests) — distincte
  /// du [softDelete] métier. À NE PAS utiliser comme voie de suppression d'une
  /// entité (celle-ci reste un soft-delete propagé au distant en E5-3).
  Future<ZResult<Unit>> clear();

  /// Libère les ressources (abonnements, contrôleurs de flux, box possédée).
  void dispose();
}
