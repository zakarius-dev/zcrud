/// `ZCrudSource<T>` — descripteur de **source de données** d'un `ZCrudScreen`.
///
/// Trois fabriques, deux voies :
/// * [ZCrudSource.repository] : la voie **nominale** — un `ZRepository<T>`
///   fournit lecture (recherche/tri via `ZDataRequest`), sauvegarde et
///   corbeille (`deletedScope`, `softDelete`/`restore`, plus la **purge** si le
///   dépôt applique le mixin `ZPurgeable`) ;
/// * [ZCrudSource.readOnlyRepository] : la même voie, **amputée de
///   l'écriture** — le dépôt sert la lecture (pagination, tri, recherche
///   serveur) et la source déclare que cette ressource ne s'écrit pas ;
/// * [ZCrudSource.items] : la voie de **cohabitation** — les données arrivent
///   déjà chargées (flux de l'application hôte) et chaque écriture est un
///   callback optionnel. Sans callback, l'écran est en lecture seule
///   **effective** : aucune action d'écriture n'est offerte.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Persistance (upsert) d'une entité, fournie par l'application.
typedef ZCrudSave<T> = Future<void> Function(T entity);

/// Écriture de corbeille (mise à la corbeille, restauration, purge) déléguée à
/// l'application.
///
/// Le `BuildContext` est celui de la **ligne** au moment du geste : il permet à
/// l'application de demander sa propre confirmation, d'afficher une notification
/// ou de naviguer, sans avoir à capturer un contexte extérieur.
typedef ZCrudTrashWrite<T> = FutureOr<void> Function(
  BuildContext context,
  T entity,
);

/// Source de données déclarative d'un `ZCrudScreen<T>`.
///
/// Immuable ; construite par l'une des trois fabriques ([repository] /
/// [readOnlyRepository] / [items]). L'écran interroge ses capacités
/// ([canWrite], [supportsTrash], [supportsPurge]) pour dériver les gestes
/// offerts — un journal immuable ou un référentiel distant en lecture seule
/// s'exprime donc **par déclaration** ([ZCrudSource.readOnlyRepository] sur la
/// voie dépôt, `ZCrudSource.items(rows)` sans callback sur l'autre), jamais par
/// contournement.
class ZCrudSource<T extends ZEntity> {
  /// Voie **repository** : lecture, sauvegarde et corbeille passent par les
  /// ports neutres de [repository] (`getAll`/`save`/`softDelete`/`restore`,
  /// listing corbeille via `ZDataRequest.deletedScope`).
  ///
  /// La **suppression définitive** n'appartient pas au port : elle est offerte
  /// si et seulement si le dépôt applique le mixin `ZPurgeable` (voir
  /// [supportsPurge]).
  const ZCrudSource.repository(ZRepository<T> this.repository)
      : items = null,
        onSave = null,
        onSoftDelete = null,
        onRestore = null,
        onPurge = null,
        isDeleted = null,
        _writable = true;

  /// Voie **repository en lecture seule** : le dépôt sert toute la lecture
  /// (pagination, tri, recherche serveur, périmètre de requête) et la source
  /// déclare que la ressource **ne s'écrit pas**. [canWrite], [supportsTrash]
  /// et [supportsPurge] valent tous `false`, dépôt présent ou non — l'écran
  /// n'offre alors ni création, ni édition, ni bascule corbeille, et ses gestes
  /// programmatiques (`ZCrudScreenActions.openCreation`/`openEdition`…) restent
  /// inertes.
  ///
  /// ```dart
  /// ZCrudScreen<Operation>(
  ///   title: 'Journal des opérations',
  ///   // Le journal se lit, se pagine et se cherche ; il ne se modifie pas.
  ///   source: ZCrudSource.readOnlyRepository(journalRepository),
  ///   registry: registry,
  ///   detailsEnabled: true,
  /// )
  /// ```
  ///
  /// **Ce n'est pas une ACL, et cela ne doit pas en devenir une.** Une ACL
  /// gouverne **qui** a le droit d'agir : elle se paramètre par usager, et un
  /// administrateur finit toujours par obtenir le geste qu'elle refusait aux
  /// autres. Cette fabrique parle de **ce que la ressource permet** : un
  /// journal d'opérations horodatées, ou un référentiel servi par un tiers,
  /// n'est pas « un CRUD interdit à tout le monde » — c'est une ressource dont
  /// l'écriture **n'existe pas**. Le geste n'est donc offert à personne, pas
  /// même à un profil tout-accordé, et sa disparition ne dépend d'aucune
  /// configuration qu'un oubli pourrait défaire.
  ///
  /// La consultation, elle, reste entière : la fiche de détail
  /// (`detailsEnabled`) s'ouvre normalement et se présente **sans** retour vers
  /// l'édition.
  const ZCrudSource.readOnlyRepository(ZRepository<T> this.repository)
      : items = null,
        onSave = null,
        onSoftDelete = null,
        onRestore = null,
        onPurge = null,
        isDeleted = null,
        _writable = false;

  /// Voie **cohabitation** : [items] arrive déjà chargé (flux de l'hôte).
  ///
  /// Les écritures sont des callbacks **optionnels** : [onSave] (création +
  /// édition), [onSoftDelete] / [onRestore] / [onPurge] (les trois gestes de
  /// corbeille). [isDeleted] est le prédicat de **partition** vivants/corbeille
  /// (la source livrant tout, c'est l'écran qui partitionne — `null` = aucune
  /// corbeille).
  const ZCrudSource.items(
    List<T> this.items, {
    this.onSave,
    this.onSoftDelete,
    this.onRestore,
    this.onPurge,
    this.isDeleted,
  })  : repository = null,
        _writable = true;

  /// Dépôt neutre de la voie repository, ou `null` (voie `items`).
  ///
  /// C'est le dépôt de **lecture** : il sert le listing quelle que soit la
  /// fabrique employée. La voie d'écriture, elle, est [writeRepository] — les
  /// deux ne coïncident pas sur une source déclarée en lecture seule.
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

  /// Suppression **définitive** déléguée à l'hôte (voie `items`), ou `null`
  /// (action absente).
  ///
  /// Pendant de `ZPurgeable` sur la voie repository : le geste n'existe que si
  /// l'application l'a déclaré. L'écran pose la confirmation irréversible
  /// **avant** l'appel.
  final ZCrudTrashWrite<T>? onPurge;

  /// Prédicat de partition corbeille de la voie `items` (`true` = l'item est
  /// à la corbeille), ou `null` (aucune partition, la corbeille n'existe pas).
  final bool Function(T item)? isDeleted;

  /// L'écriture par dépôt est-elle déclarée ? Vrai partout sauf sur
  /// [ZCrudSource.readOnlyRepository], seule fabrique qui la retire.
  final bool _writable;

  /// Dépôt utilisable pour **écrire** (sauvegarde, corbeille, purge), ou
  /// `null` — soit qu'il n'y ait pas de dépôt (voie `items`), soit que la
  /// source ait déclaré la ressource en lecture seule
  /// ([ZCrudSource.readOnlyRepository]).
  ///
  /// Distinct de [repository], qui reste le dépôt de **lecture**. C'est cette
  /// séparation qui rend l'immuabilité structurelle plutôt que déclarative sur
  /// parole : un écran branché en lecture seule n'a **aucune** voie d'écriture
  /// à emprunter, même si tout le reste de sa configuration est présent.
  ZRepository<T>? get writeRepository => _writable ? repository : null;

  /// `true` si la source sait **écrire** (création/édition) : dépôt d'écriture
  /// ([writeRepository]), ou callback [onSave] fourni.
  ///
  /// Faux sur une source déclarée en lecture seule, **dépôt présent compris** :
  /// c'est ce qui permet d'exprimer une ressource immuable sans renoncer à la
  /// pagination ni à la recherche serveur.
  bool get canWrite => writeRepository != null || onSave != null;

  /// `true` si la source sait servir une **corbeille** : dépôt d'écriture
  /// (`deletedScope` + `softDelete`/`restore`), ou partition [isDeleted] +
  /// au moins une écriture de corbeille.
  bool get supportsTrash =>
      writeRepository != null ||
      (isDeleted != null &&
          (onSoftDelete != null || onRestore != null || onPurge != null));

  /// `true` si la source sait **supprimer définitivement** : dépôt d'écriture
  /// appliquant le mixin `ZPurgeable`, ou rappel [onPurge] déclaré.
  ///
  /// Faux par défaut : la purge est une capacité qu'on **déclare**, jamais une
  /// capacité qu'on suppose. Une source qui ne l'a pas ne fait apparaître aucun
  /// geste de suppression définitive — sans erreur ni avertissement. Un dépôt
  /// `ZPurgeable` branché en lecture seule n'en offre donc aucun non plus : la
  /// ressource prime sur ce que le dépôt saurait faire.
  bool get supportsPurge => writeRepository is ZPurgeable<T> || onPurge != null;
}
