/// Port **neutre** de la couche données : store **distant** best-effort.
///
/// origine: canonique §7 — « à abstraire derrière `ZLocalStore`/`ZRemoteStore` ».
/// Introduit **avec** son adaptateur en E5 (différé explicitement par E2-2).
/// AD-5 (backend-agnostique) ; AD-9 (offline-first, distant fire-and-forget) ;
/// AD-11 (`Either`/flux nus).
library;

import 'package:dartz/dartz.dart' show Unit;

import '../contracts/z_entity.dart';
import '../data/z_data_request.dart';
import '../failures/z_failure.dart';
import '../sync/z_sync_entry.dart';

/// Contrat **abstrait** (port) du store **distant** d'un agrégat [T] — la moitié
/// « best-effort » du patron offline-first (AD-9).
///
/// **Fire-and-forget / best-effort** (AD-9) : le distant **n'est jamais la
/// source de vérité**. Un échec distant ne doit pas invalider l'état local
/// autoritaire ([ZLocalStore]). Ce port se borne à exposer les primitives
/// **pousser / tirer** un agrégat ; la **composition** local↔distant, le **merge
/// Last-Write-Wins** sur `updatedAt`, la cascade bornée (≤ 450) et le
/// **débounce** (`ZSyncOrchestrator`) appartiennent à **E5-3/E5-4** et ne vivent
/// **pas** ici (frontière **volontaire** — aucune orchestration dans ce port).
///
/// **Backend-agnostique** (AD-5) : aucune signature n'expose de type
/// `cloud_firestore`. L'adaptateur concret (`FirestoreZRemoteStore`,
/// `zcrud_firestore`) délègue au repository Firestore d'E5-1 ; les dates
/// transitent en **ISO-8601** (jamais `Timestamp`).
///
/// **Contrat de résultat** (AD-11) : `ZResult<...>` / `ZResult<Unit>` ; une
/// erreur d'accès distant est un [ServerFailure]. Les **flux** sont des
/// `Stream<List<T>>` **NUS**.
abstract class ZRemoteStore<T extends ZEntity> {
  /// Pousse [item] vers le distant (best-effort). Matérialise l'éphémère et
  /// renvoie l'entité poussée. Même sémantique de clé (corps `id`) et de
  /// soft-delete (`is_deleted`/`updated_at` hors-entité) que le local.
  Future<ZResult<T>> push(T item);

  /// Propage un **soft-delete** distant de l'élément [id] (`is_deleted = true`,
  /// hors-entité). **Jamais** de purge physique. `id` absent →
  /// `Left(NotFoundFailure)`.
  Future<ZResult<Unit>> remoteDelete(String id);

  /// Tire l'état distant (lecture best-effort) filtré/trié/paginé selon
  /// [request]. Exclut les soft-deleted.
  Future<ZResult<List<T>>> pull({ZDataRequest? request});

  /// Flux temps réel **nu** distant des éléments visibles (non soft-deleted).
  Stream<List<T>> watchAll();

  /// **Voie de lecture de SYNCHRONISATION** (E5-3) : lit **toutes** les entrées
  /// distantes **y compris soft-deletées** (tombstones), chacune appariée à son
  /// [ZSyncMeta]. **Contraste voulu avec [pull]** (qui exclut les tombstones) :
  /// indispensable au merge Last-Write-Wins. Décodage **défensif** (AD-10) : une
  /// entrée non décodable est écartée + loggée. Erreur d'accès distant →
  /// `Left(ServerFailure)` (best-effort, assimilé à « offline » par le dépôt).
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries();

  /// **Écriture PRÉSERVANT la méta** (E5-3) d'une **seule** entrée : écrit
  /// l'entité **et** son [ZSyncMeta] **verbatim** — `updated_at`/`is_deleted`
  /// conservés tels quels, **jamais** `now()`. Réservé au merge (défaire
  /// l'estampille de `push` casserait le LWW). Un tombstone (`isDeleted:true`) est
  /// propagé tel quel. Erreur distante → `Left(ServerFailure)`.
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry);

  /// **Propagation PAR LOT BORNÉE** (E5-3, AD-9) d'un changeset d'[entries]
  /// (gagnants locaux d'un merge), chacune écrite **verbatim** (méta préservée,
  /// jamais `now()`).
  ///
  /// La **borne** de découpage (≤ 450 écritures/lot, sûre sous la limite Firestore
  /// de 500) est **backend-spécifique** et vit **exclusivement** dans l'adaptateur
  /// (`zcrud_firestore`) — **jamais** dans ce port neutre (AD-5). Chaque lot est
  /// **committé atomiquement** (aucune écriture partielle non-commit). Une liste
  /// vide → `Right(unit)` (no-op). Erreur distante → `Left(ServerFailure)`.
  Future<ZResult<Unit>> applyMergedAll(List<ZSyncEntry<T>> entries);

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
