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

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
