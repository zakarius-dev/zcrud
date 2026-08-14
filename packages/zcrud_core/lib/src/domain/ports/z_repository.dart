/// Contrat de la couche **données** du domaine `zcrud_core`.
///
/// `ZRepository<T extends ZEntity>` généralise le patron repository à toute
/// entité `zcrud`. Invariants portés : AD-5 (backend-agnostique), AD-11
/// (`Either`/flux nus), AD-14 (invariants métier au repository), AD-16
/// (soft-delete hors-entité).
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
/// l'adaptateur (`zcrud_firestore`), jamais ici.
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
///   (`ZSyncMeta`, AD-16). La **portée de suppression** des lectures est
///   choisie par l'appelant via [ZDataRequest.deletedScope] (voir
///   [ZDeletedScope]) : par défaut `aliveOnly` — les soft-deleted sont exclus,
///   comportement historique — mais la corbeille reste lisible en
///   `deletedOnly` sur les chemins porteurs d'un `ZDataRequest`.
/// Surface **LECTURE SEULE** d'un dépôt.
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
  /// Flux temps réel **nu** de tous les éléments **vivants**.
  ///
  /// Chemin **sans** `ZDataRequest` : la portée est **figée** à
  /// [ZDeletedScope.aliveOnly] (les soft-deleted n'apparaissent jamais ici).
  /// Pour lire la corbeille ou tout le parc, passer par [watch] avec un
  /// [ZDataRequest.deletedScope] explicite.
  Stream<List<T>> watchAll();

  /// Flux temps réel **nu** filtré/trié/paginé selon [request].
  ///
  /// La portée de suppression est choisie par [ZDataRequest.deletedScope]
  /// (défaut [ZDeletedScope.aliveOnly] — comportement historique). Flux
  /// corbeille en une ligne :
  /// `watch(request.copyWith(deletedScope: ZDeletedScope.deletedOnly))`.
  Stream<List<T>> watch(ZDataRequest request);

  /// Lit tous les éléments correspondant à [request].
  ///
  /// La portée de suppression est choisie par [ZDataRequest.deletedScope]
  /// (défaut [ZDeletedScope.aliveOnly] — les soft-deleted sont exclus, y
  /// compris quand [request] est omis). Listing corbeille :
  /// `getAll(request: const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly))`.
  Future<ZResult<List<T>>> getAll({ZDataRequest? request});

  /// Lit l'élément d'identité [id]. `Left(ZNotFoundFailure)` s'il est absent ou
  /// soft-deleted.
  ///
  /// Chemin **sans** `ZDataRequest` : la portée est **figée** à
  /// [ZDeletedScope.aliveOnly] — un élément en corbeille rend un
  /// `Left(ZNotFoundFailure)` explicite. Son `id` se retrouve via
  /// [getAll] en portée `deletedOnly`, et [ZRepository.restore] opère sur
  /// cet `id`.
  Future<ZResult<T>> getById(String id);

  /// Compte les éléments correspondant à [request].
  ///
  /// La portée de suppression est choisie par [ZDataRequest.deletedScope]
  /// (défaut [ZDeletedScope.aliveOnly] — les soft-deleted sont exclus, y
  /// compris quand [request] est omis). Badge corbeille :
  /// `count(request: const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly))`.
  Future<ZResult<int>> count({ZDataRequest? request});
}

/// Contrat repository en lecture-écriture pour l'entité [T].
///
/// Étend [ZReadOnlyRepository] avec les écritures (création, mise à jour,
/// suppression). Toute méthode d'écriture retourne `Either<ZFailure, T>` (ou
/// `Unit` pour les opérations sans valeur de retour) — invariant AD-11 : jamais
/// d'exception non capturée à travers la frontière du repository.
///
/// **Corbeille** : le soft-delete ([softDelete]/[restore]) n'est pas une
/// impasse de lecture — les chemins porteurs d'un `ZDataRequest` ([watch],
/// [getAll], [count]) honorent [ZDataRequest.deletedScope] (voir
/// [ZDeletedScope]) pour lister les éléments supprimés (`deletedOnly`) ou
/// tout le parc (`includeDeleted`).
abstract class ZRepository<T extends ZEntity> implements ZReadOnlyRepository<T> {
  /// Flux temps réel **nu** de tous les éléments **vivants**.
  ///
  /// Équivalent du `dataChanges` canonique : seed immédiat puis diffusion des
  /// mutations (sémantique broadcast portée par l'implémentation). Jamais enveloppé
  /// dans un `Either` (invariant AD-11).
  ///
  /// Chemin **sans** `ZDataRequest` : portée **figée** à
  /// [ZDeletedScope.aliveOnly] — pour la corbeille, passer par [watch] avec un
  /// [ZDataRequest.deletedScope] explicite.
  @override
  Stream<List<T>> watchAll();

  /// Flux temps réel **nu** filtré/trié/paginé selon [request].
  ///
  /// La portée de suppression est choisie par [ZDataRequest.deletedScope]
  /// (défaut [ZDeletedScope.aliveOnly] — comportement historique). Flux
  /// corbeille en une ligne :
  /// `watch(request.copyWith(deletedScope: ZDeletedScope.deletedOnly))`.
  @override
  Stream<List<T>> watch(ZDataRequest request);

  /// Lit tous les éléments correspondant à [request].
  ///
  /// La portée de suppression est choisie par [ZDataRequest.deletedScope]
  /// (défaut [ZDeletedScope.aliveOnly] — les soft-deleted sont exclus, y
  /// compris quand [request] est omis).
  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request});

  /// Lit l'élément d'identité [id]. `Left(ZNotFoundFailure)` s'il est absent ou
  /// soft-deleted.
  ///
  /// Chemin **sans** `ZDataRequest` : portée **figée** à
  /// [ZDeletedScope.aliveOnly]. L'`id` d'un élément en corbeille se retrouve
  /// via [getAll] en portée `deletedOnly` ; [restore] opère sur cet `id`.
  @override
  Future<ZResult<T>> getById(String id);

  /// Persiste [item]. Matérialise l'éphémère (attribution d'`id`) et rejette
  /// une cible manquante via `Left(ZDomainFailure)` (AD-14).
  ///
  /// ## [collectionId] — une **redirection d'écriture**, pas une clé de droits
  ///
  /// Quand un adaptateur l'honore, [collectionId] **localise le conteneur** :
  /// il désigne l'emplacement où le document est écrit, **à la place** de celui
  /// que le dépôt porte. C'est le cas de l'adaptateur Firestore, où la valeur
  /// est prise comme chemin de collection.
  ///
  /// **Ne jamais y passer un identifiant d'autorisation.** L'homonymie avec
  /// le `collectionId` de `ZAcl.can` est trompeuse : les deux mots désignent des
  /// choses différentes. Passer ici la clé de gouvernance d'un écran envoie les
  /// données **ailleurs** — l'écriture réussit (`Right`), aucune erreur n'est
  /// levée, et les lectures continuent d'interroger l'emplacement du dépôt :
  /// les documents écrits deviennent invisibles sans qu'aucun signal ne le
  /// laisse voir. Un backend qui crée toute collection nommée à la volée
  /// (Firestore) ne protège pas de cette confusion.
  ///
  /// Le laisser à `null` — cas normal — écrit là où le dépôt écrit. Ne le
  /// renseigner que pour une redirection **voulue et explicite**, vers un
  /// conteneur dont l'appelant connaît le nom réel.
  ///
  /// Un adaptateur n'est pas tenu de l'honorer : certaines implémentations
  /// (offline-first sur store local) l'ignorent, l'emplacement étant déterminé
  /// par leur propre topologie.
  Future<ZResult<T>> save(T item, {String? collectionId});

  /// Soft-delete l'élément [id] (`is_deleted = true`, hors-entité `ZSyncMeta`).
  ///
  /// L'élément reste lisible en portée [ZDeletedScope.deletedOnly] (corbeille)
  /// via [watch]/[getAll]/[count].
  Future<ZResult<Unit>> softDelete(String id);

  /// Restaure l'élément [id] soft-deleted (corbeille). Son `id` se retrouve
  /// via [getAll] en portée [ZDeletedScope.deletedOnly].
  Future<ZResult<Unit>> restore(String id);

  /// Compte les éléments correspondant à [request].
  ///
  /// La portée de suppression est choisie par [ZDataRequest.deletedScope]
  /// (défaut [ZDeletedScope.aliveOnly] — les soft-deleted sont exclus, y
  /// compris quand [request] est omis).
  @override
  Future<ZResult<int>> count({ZDataRequest? request});

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
