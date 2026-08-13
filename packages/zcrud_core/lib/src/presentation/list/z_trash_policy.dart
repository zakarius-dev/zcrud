/// `ZTrashPolicy` — **quels gestes** de corbeille une liste offre.
///
/// La corbeille est un cycle à trois gestes : **mettre à la corbeille**,
/// **restaurer**, **supprimer définitivement**. Trois questions distinctes en
/// décident, et les confondre est la source d'erreur habituelle :
///
/// * *La corbeille existe-t-elle ?* — décidé par l'assemblage (une source qui
///   ne sait pas soft-supprimer n'en a pas) ;
/// * *L'usager a-t-il le droit ?* — décidé par `ZAcl` (`delete`, `restore`,
///   `clear`) ;
/// * *Le produit veut-il offrir ce geste ?* — c'est **ce type**, et lui seul.
///
/// Les trois se composent en **conjonction** : un geste est offert s'il est
/// possible, autorisé **et** voulu. Déclarer un geste ici n'accorde jamais un
/// droit refusé en amont.
library;

import 'package:flutter/foundation.dart' show immutable;

/// Gestes de corbeille **voulus** par la déclaration.
///
/// Par défaut, les trois gestes sont offerts ([full]) : la corbeille complète
/// est le comportement attendu, et retirer un geste est le cas particulier.
///
/// ```dart
/// // Corbeille consultable et restaurable, mais rien ne s'y détruit :
/// const ZTrashPolicy(purge: false)
/// ```
@immutable
class ZTrashPolicy {
  /// Déclare les gestes offerts (tous par défaut), l'affichage du **compteur**
  /// ([showCount]) et la visibilité de l'accès **à vide** ([visibleWhenEmpty]).
  const ZTrashPolicy({
    this.softDelete = true,
    this.restore = true,
    this.purge = true,
    this.showCount = true,
    this.visibleWhenEmpty = true,
  });

  /// Les trois gestes : mettre, restaurer, purger. C'est le défaut.
  static const ZTrashPolicy full = ZTrashPolicy();

  /// Corbeille **sans destruction définitive** : on y met et on en sort, rien
  /// n'en disparaît. Politique des domaines à rétention (journal, dossier
  /// réglementaire) dont le dépôt sait pourtant purger.
  static const ZTrashPolicy withoutPurge = ZTrashPolicy(purge: false);

  /// Corbeille en **consultation seule** : ce qui y est déjà se voit, mais
  /// aucun geste ne s'y applique.
  static const ZTrashPolicy readOnly = ZTrashPolicy(
    softDelete: false,
    restore: false,
    purge: false,
  );

  /// Offrir la mise à la corbeille (`softDelete`) sur les éléments vivants.
  final bool softDelete;

  /// Offrir la restauration sur les éléments en corbeille.
  final bool restore;

  /// Offrir la **suppression définitive** sur les éléments en corbeille.
  ///
  /// Voulu ne signifie pas possible : le geste n'apparaît que si la source sait
  /// aussi le servir (mixin `ZPurgeable` sur le dépôt, ou rappel de purge
  /// déclaré) et si `ZCrudAction.clear` est accordé.
  final bool purge;

  /// Afficher le **nombre d'éléments** en corbeille sur l'accès à celle-ci
  /// (défaut `true`).
  ///
  /// Le nombre n'apparaît que s'il est **connu** : l'assemblage ne compte
  /// jamais de lui-même (compter, c'est interroger la source — voir
  /// `ZCrudScreen.trashCount`). Déclarer `false` retire la pastille même
  /// quand le compte est disponible : un écran dont la corbeille se remplit
  /// en permanence n'a pas forcément à afficher son volume.
  final bool showCount;

  /// Offrir l'accès à la corbeille **même vide** (défaut `true` — comportement
  /// historique).
  ///
  /// `false` fait disparaître l'accès tant que la corbeille ne contient rien :
  /// pas de bouton qui ouvre une page vide. La condition ne s'applique que si
  /// le compte est **connu** ; compte inconnu, l'accès reste offert (une
  /// corbeille non comptée n'est pas une corbeille vide).
  final bool visibleWhenEmpty;

  /// `true` si aucun geste n'est offert (corbeille en consultation seule).
  bool get isEmpty => !softDelete && !restore && !purge;

  /// Copie de cette politique dont seuls les traits cités changent.
  ZTrashPolicy copyWith({
    bool? softDelete,
    bool? restore,
    bool? purge,
    bool? showCount,
    bool? visibleWhenEmpty,
  }) =>
      ZTrashPolicy(
        softDelete: softDelete ?? this.softDelete,
        restore: restore ?? this.restore,
        purge: purge ?? this.purge,
        showCount: showCount ?? this.showCount,
        visibleWhenEmpty: visibleWhenEmpty ?? this.visibleWhenEmpty,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTrashPolicy &&
          other.softDelete == softDelete &&
          other.restore == restore &&
          other.purge == purge &&
          other.showCount == showCount &&
          other.visibleWhenEmpty == visibleWhenEmpty;

  @override
  int get hashCode =>
      Object.hash(softDelete, restore, purge, showCount, visibleWhenEmpty);

  @override
  String toString() => 'ZTrashPolicy(softDelete: $softDelete, '
      'restore: $restore, purge: $purge, showCount: $showCount, '
      'visibleWhenEmpty: $visibleWhenEmpty)';
}
