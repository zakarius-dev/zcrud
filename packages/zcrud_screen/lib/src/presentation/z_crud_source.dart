/// `ZCrudSource<T>` — descripteur de **source de données** d'un `ZCrudScreen`.
///
/// Deux voies, deux fabriques :
/// * [ZCrudSource.repository] : la voie **nominale** — un `ZRepository<T>`
///   fournit lecture (recherche/tri via `ZDataRequest`), sauvegarde et
///   corbeille (`deletedScope`, `softDelete`/`restore`) ;
/// * [ZCrudSource.items] : la voie de **cohabitation** — les données arrivent
///   déjà chargées (flux de l'application hôte) et chaque écriture est un
///   callback optionnel. Sans callback, l'écran est en lecture seule
///   **effective** : aucune action d'écriture n'est offerte.
library;

import 'dart:async';

import 'package:zcrud_core/zcrud_core.dart';

/// Persistance (upsert) d'une entité, fournie par l'application.
typedef ZCrudSave<T> = Future<void> Function(T entity);

/// Écriture de corbeille (soft-delete ou restore) déléguée à l'application.
typedef ZCrudTrashWrite<T> = FutureOr<void> Function(T entity);

/// Source de données déclarative d'un `ZCrudScreen<T>`.
///
/// Immuable ; construite par l'une des deux fabriques ([repository] /
/// [items]). L'écran interroge ses capacités ([canWrite], [supportsTrash])
/// pour dériver les gestes offerts — un journal immuable ou un référentiel
/// distant en lecture seule s'exprime donc **par déclaration**
/// (`ZCrudSource.items(rows)` sans callback), jamais par contournement.
class ZCrudSource<T extends ZEntity> {
  /// Voie **repository** : lecture, sauvegarde et corbeille passent par les
  /// ports neutres de [repository] (`getAll`/`save`/`softDelete`/`restore`,
  /// listing corbeille via `ZDataRequest.deletedScope`).
  const ZCrudSource.repository(ZRepository<T> this.repository)
      : items = null,
        onSave = null,
        onSoftDelete = null,
        onRestore = null,
        isDeleted = null;

  /// Voie **cohabitation** : [items] arrive déjà chargé (flux de l'hôte).
  ///
  /// Les écritures sont des callbacks **optionnels** : [onSave] (création +
  /// édition), [onSoftDelete] / [onRestore] (corbeille). [isDeleted] est le
  /// prédicat de **partition** vivants/corbeille (la source livrant tout,
  /// c'est l'écran qui partitionne — `null` = aucune corbeille).
  const ZCrudSource.items(
    List<T> this.items, {
    this.onSave,
    this.onSoftDelete,
    this.onRestore,
    this.isDeleted,
  }) : repository = null;

  /// Dépôt neutre de la voie repository, ou `null` (voie `items`).
  final ZRepository<T>? repository;

  /// Données déjà chargées de la voie cohabitation, ou `null` (voie
  /// repository).
  final List<T>? items;

  /// Sauvegarde déléguée à l'hôte (voie `items`), ou `null`.
  final ZCrudSave<T>? onSave;

  /// Soft-delete délégué à l'hôte (voie `items`), ou `null` (action absente).
  final ZCrudTrashWrite<T>? onSoftDelete;

  /// Restauration déléguée à l'hôte (voie `items`), ou `null` (action
  /// absente).
  final ZCrudTrashWrite<T>? onRestore;

  /// Prédicat de partition corbeille de la voie `items` (`true` = l'item est
  /// à la corbeille), ou `null` (aucune partition, la corbeille n'existe pas).
  final bool Function(T item)? isDeleted;

  /// `true` si la source sait **écrire** (création/édition) : repository, ou
  /// callback [onSave] fourni.
  bool get canWrite => repository != null || onSave != null;

  /// `true` si la source sait servir une **corbeille** : repository
  /// (`deletedScope` + `softDelete`/`restore`), ou partition [isDeleted] +
  /// au moins une écriture de corbeille.
  bool get supportsTrash =>
      repository != null ||
      (isDeleted != null && (onSoftDelete != null || onRestore != null));
}
