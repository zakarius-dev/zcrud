/// Contrat de la couche **données** du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — `StudyFoldersRepository` /
/// `FlashcardsRepository` / `MindmapsRepository` / `RepetitionRepository`,
/// généralisés en `ZRepository<T extends ZEntity>`. Canonique §7 ;
/// AD-5 (backend-agnostique) ; AD-11 (`Either`/flux nus) ; AD-14 (invariants
/// métier au repository) ; AD-16 (soft-delete hors-entité).
library;

import 'package:dartz/dartz.dart' show Unit;

import '../contracts/z_entity.dart';
import '../data/z_data_request.dart';
import '../failures/z_failure.dart';

/// Contrat **abstrait** (port) de persistance d'un agrégat [T].
///
/// **Backend-agnostique** (AD-5) : aucune signature n'expose de type
/// `cloud_firestore` (`Timestamp`/`Filter`/`DocumentSnapshot`…). La traduction
/// `ZDataRequest → Filter` et le curseur `startAfter` concret vivent dans
/// l'adaptateur (E5 `zcrud_firestore`), jamais ici.
///
/// **Contrat de résultat** (AD-11) : les opérations retournent `ZResult<...>`
/// (`Either<ZFailure, T>`) et `ZResult<Unit>` pour les « void ». Les **flux**
/// sont des `Stream<List<T>>` **NUS** — jamais enveloppés dans un `Either`.
///
/// **Invariants métier portés par l'impl** (AD-14, documentés ici, non
/// implémentés) :
/// - [save] **matérialise l'éphémère** : une entité sans `id` (`isEphemeral`)
///   se voit attribuer une identité opaque à l'écriture ; l'absence de cible
///   requise est rejetée par un `Left(ZDomainFailure)`.
/// - [softDelete]/[restore] basculent le drapeau `is_deleted` **hors-entité**
///   (`ZSyncMeta`, AD-16) ; les lectures excluent les soft-deleted.
/// Surface **LECTURE SEULE** d'un dépôt (CR-LEX-32).
///
/// ## Pourquoi elle existe
///
/// Une migration par vagues, un écran de consultation, un rapport : tous
/// lisent sans jamais écrire. Sans surface dédiée, ils reçoivent un
/// [ZRepository] complet — donc la capacité d'écrire — et la seule protection
/// possible était un **décorateur écrit à la main par chaque hôte**, qu'il
/// fallait en plus tester.
///
/// Typer la dépendance en [ZReadOnlyRepository] rend l'écriture **inexprimable
/// à la compilation** : ce n'est plus une convention à surveiller en revue,
/// c'est le compilateur qui la refuse.
///
/// ```dart
/// // La vague de migration ne PEUT PAS écrire, par construction :
/// Future<void> migrerVague(ZReadOnlyRepository<ZStudyFolder> source) async { … }
/// ```
///
/// [ZRepository] l'**implémente** : aucun adaptateur existant n'a à changer, et
/// tout dépôt se passe déjà là où une lecture seule est attendue.
abstract class ZReadOnlyRepository<T extends ZEntity> {
  /// Flux temps réel **nu** de tous les éléments non soft-deleted.
  Stream<List<T>> watchAll();

  /// Flux temps réel **nu** filtré/trié/paginé selon [request].
  Stream<List<T>> watch(ZDataRequest request);

  /// Lit tous les éléments correspondant à [request] (exclut les soft-deleted).
  Future<ZResult<List<T>>> getAll({ZDataRequest? request});

  /// Lit l'élément d'identité [id]. `Left(ZNotFoundFailure)` s'il est absent ou
  /// soft-deleted.
  Future<ZResult<T>> getById(String id);

  /// Compte les éléments correspondant à [request] (exclut les soft-deleted).
  Future<ZResult<int>> count({ZDataRequest? request});
}

abstract class ZRepository<T extends ZEntity> implements ZReadOnlyRepository<T> {
  /// Flux temps réel **nu** de tous les éléments non soft-deleted.
  ///
  /// Équivalent du `dataChanges` canonique : seed immédiat puis diffusion des
  /// mutations (sémantique broadcast portée par l'impl E5). Jamais enveloppé
  /// dans un `Either` (AD-11).
  @override
  Stream<List<T>> watchAll();

  /// Flux temps réel **nu** filtré/trié/paginé selon [request].
  @override
  Stream<List<T>> watch(ZDataRequest request);

  /// Lit tous les éléments correspondant à [request] (exclut les soft-deleted).
  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request});

  /// Lit l'élément d'identité [id]. `Left(ZNotFoundFailure)` s'il est absent ou
  /// soft-deleted.
  @override
  Future<ZResult<T>> getById(String id);

  /// Persiste [item]. Matérialise l'éphémère (attribution d'`id`) et rejette
  /// une cible manquante via `Left(ZDomainFailure)` (AD-14). [collectionId]
  /// localise le conteneur si nécessaire.
  Future<ZResult<T>> save(T item, {String? collectionId});

  /// Soft-delete l'élément [id] (`is_deleted = true`, hors-entité `ZSyncMeta`).
  Future<ZResult<Unit>> softDelete(String id);

  /// Restaure l'élément [id] soft-deleted (corbeille, E4-4).
  Future<ZResult<Unit>> restore(String id);

  /// Compte les éléments correspondant à [request] (exclut les soft-deleted).
  @override
  Future<ZResult<int>> count({ZDataRequest? request});

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
