/// Actions de **ligne** de liste, neutres, du cœur `zcrud_core` (E4-4).
///
/// origine: IFFD `CrudActionsButons` + `RessourceACL`
/// (`dynamic_list_screen.dart:73-342`, `:1272`) — les 3 apps (DODLP/IFFD/DLCFTI)
/// dupliquaient des boutons d'action de ligne (éditer/supprimer/restaurer/custom)
/// filtrés par une ACL applicative. E4-4 généralise ce patron en un **modèle
/// d'action NEUTRE** `ZRowAction<T>` (porte l'entité `T` + la permission requise
/// + le handler), **résolu par ligne** en `ZResolvedRowAction` (sans `T`, avec
/// `enabled` déjà tranché par l'ACL et `onInvoke` déjà lié à l'entité) — le
/// renderer (grille) ne voit donc **jamais** `T` ni `ZAcl` (SM-5, AD-16).
///
/// **Corbeille (AD-9/AD-16)** : les fabriques [ZRowAction.softDelete] /
/// [ZRowAction.restore] appellent les ports `ZRepository.softDelete`/`restore`
/// (bascule `is_deleted` **hors-entité** `ZSyncMeta`, jamais de suppression
/// dure) ; le `ZResult<Unit>` est **déplié** (AD-11) : `Right` → succès (hook
/// `onSuccess`), `Left(ZFailure)` → `onFailure` **non fatal** (aucun throw).
///
/// **Neutre** : imports limités à `dart:async` (`FutureOr`) +
/// `package:flutter/widgets.dart` (`IconData`/`BuildContext`/`VoidCallback`) +
/// types `zcrud_core`. AUCUN `package:syncfusion`, AUCUN backend, AUCUN
/// gestionnaire d'état (gardes de pureté SM-5).
///
/// **Frontière** : E4-4 livre les **actions** soft-delete/restore ; le **listing**
/// de la corbeille (voir les supprimés) exigerait une extension additive de
/// `ZDataRequest` honorée par l'adaptateur E5 — **déféré** (le contrat E2-2 est
/// gelé). Les sous-listes/onglets sont E4-5.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/failures/z_failure.dart';
import '../../domain/ports/z_acl.dart';
import '../../domain/ports/z_repository.dart';

/// Mode de filtrage ACL des actions de ligne (AC2).
///
/// - [hide] (défaut) : une action non autorisée n'est **pas rendue** — l'usager
///   ne voit pas ce qu'il ne peut pas faire (comportement le plus courant IFFD).
/// - [disable] : l'action est **rendue grisée** (`enabled == false`), non
///   cliquable — préférable pour la découvrabilité.
enum ZActionAclMode {
  /// Masque l'action non autorisée (défaut).
  hide,

  /// Rend l'action non autorisée mais désactivée (grisée).
  disable,
}

/// Vue **résolue et neutre** d'une action de ligne, prête à être rendue.
///
/// Débarrassée de la générécité `T` : l'entité et l'ACL ont déjà été liées lors
/// de la résolution ([ZRowAction.resolve]). Le renderer (grille Syncfusion ou
/// vue `builder` du cœur) consomme UNIQUEMENT ce type — il ne connaît ni `T` ni
/// `ZAcl` (SM-5).
@immutable
class ZResolvedRowAction {
  /// Construit une action résolue neutre.
  const ZResolvedRowAction({
    required this.id,
    required this.labelKey,
    required this.enabled,
    required this.onInvoke,
    this.icon,
    this.destructive = false,
  });

  /// Identifiant stable de l'action (déterministe, pour les clés/tests).
  final String id;

  /// Clé l10n du libellé (résolue au rendu via `label(context, labelKey)`).
  final String labelKey;

  /// Icône optionnelle du bouton d'action.
  final IconData? icon;

  /// `true` si l'action est **destructive** (suppression) — indice de style.
  final bool destructive;

  /// `true` si l'action est autorisée (ACL) et donc cliquable ; `false` = grisée
  /// (mode [ZActionAclMode.disable]).
  final bool enabled;

  /// Callback **déjà liée** à l'entité de la ligne (invoque le handler original
  /// avec le `BuildContext` et l'entité capturés à la résolution).
  final VoidCallback onInvoke;
}

/// Modèle d'action de ligne **neutre et générique** `<T>` (AC1).
///
/// Porte le handler typé `onInvoke(context, entity)` + la permission requise
/// (`requiredPermission`, filtrée par `ZAcl`, AD-16) + les métadonnées d'UI. Se
/// résout par ligne en un [ZResolvedRowAction] via [resolve].
@immutable
class ZRowAction<T extends ZEntity> {
  /// Construit une action de ligne générique.
  const ZRowAction({
    required this.id,
    required this.labelKey,
    required this.onInvoke,
    this.icon,
    this.requiredPermission,
    this.destructive = false,
  });

  /// Fabrique **corbeille** : soft-delete via `ZRepository.softDelete` (bascule
  /// `is_deleted` hors-entité, AD-9). Permission requise : `ZCrudAction.delete`.
  ///
  /// Le `ZResult<Unit>` est **déplié** (AD-11) : `Right` → [onSuccess] (l'app y
  /// branche typiquement un `ZListController.refresh`) ; `Left(ZFailure)` →
  /// [onFailure] (non fatal, **aucun throw**). Une entité éphémère (`id == null`)
  /// est ignorée silencieusement (rien à supprimer).
  factory ZRowAction.softDelete(
    ZRepository<T> repository, {
    void Function(ZFailure failure)? onFailure,
    void Function()? onSuccess,
    String labelKey = 'delete',
    IconData? icon,
    String id = 'delete',
  }) {
    return ZRowAction<T>(
      id: id,
      labelKey: labelKey,
      icon: icon,
      requiredPermission: ZCrudAction.delete,
      destructive: true,
      onInvoke: (context, entity) async {
        final entityId = entity.id;
        if (entityId == null) return;
        final result = await repository.softDelete(entityId);
        result.fold(
          (failure) => onFailure?.call(failure),
          (_) => onSuccess?.call(),
        );
      },
    );
  }

  /// Fabrique **corbeille** : restore via `ZRepository.restore` (ré-inclut
  /// l'item soft-deleted, AD-9). Permission requise : `ZCrudAction.restore`.
  ///
  /// Même dépliage `ZResult<Unit>` que [ZRowAction.softDelete] (AD-11).
  factory ZRowAction.restore(
    ZRepository<T> repository, {
    void Function(ZFailure failure)? onFailure,
    void Function()? onSuccess,
    String labelKey = 'restore',
    IconData? icon,
    String id = 'restore',
  }) {
    return ZRowAction<T>(
      id: id,
      labelKey: labelKey,
      icon: icon,
      requiredPermission: ZCrudAction.restore,
      onInvoke: (context, entity) async {
        final entityId = entity.id;
        if (entityId == null) return;
        final result = await repository.restore(entityId);
        result.fold(
          (failure) => onFailure?.call(failure),
          (_) => onSuccess?.call(),
        );
      },
    );
  }

  /// Fabrique **édition** : délègue au [onInvoke] fourni par l'app (navigation
  /// vers l'édition). Permission requise : `ZCrudAction.update`.
  factory ZRowAction.edit({
    required FutureOr<void> Function(BuildContext context, T entity) onInvoke,
    String labelKey = 'edit',
    IconData? icon,
    String id = 'edit',
  }) {
    return ZRowAction<T>(
      id: id,
      labelKey: labelKey,
      icon: icon,
      requiredPermission: ZCrudAction.update,
      onInvoke: onInvoke,
    );
  }

  /// Identifiant stable de l'action.
  final String id;

  /// Clé l10n du libellé.
  final String labelKey;

  /// Icône optionnelle.
  final IconData? icon;

  /// Permission requise (filtrée par `ZAcl`, AD-16) ; `null` = action **custom**
  /// toujours autorisée (jamais filtrée).
  final ZCrudAction? requiredPermission;

  /// `true` si l'action est destructive (suppression) — indice de style.
  final bool destructive;

  /// Handler typé invoqué avec le `BuildContext` et l'entité `T` de la ligne.
  final FutureOr<void> Function(BuildContext context, T entity) onInvoke;

  /// Résout cette action **pour une ligne** donnée : lie l'[entity] et fige
  /// l'état [enabled] (déjà tranché par l'ACL en amont), produisant une vue
  /// neutre [ZResolvedRowAction] (sans `T`).
  ///
  /// Le [context] et l'[entity] sont **capturés** dans la closure `onInvoke` de
  /// l'action résolue — la résolution a lieu par-ligne au `build` de
  /// `DynamicList`, où `T`, l'ACL et le `BuildContext` coexistent.
  ZResolvedRowAction resolve(
    BuildContext context,
    T entity, {
    required bool enabled,
  }) {
    return ZResolvedRowAction(
      id: id,
      labelKey: labelKey,
      icon: icon,
      destructive: destructive,
      enabled: enabled,
      onInvoke: () => onInvoke(context, entity),
    );
  }
}
