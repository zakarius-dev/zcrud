/// Capacité **optionnelle** de suppression définitive d'un dépôt.
///
/// La corbeille du socle a trois gestes : **mettre** (`softDelete`),
/// **restaurer** (`restore`) et **purger**. Les deux premiers appartiennent au
/// port [ZRepository] : tout dépôt sait les servir. Le troisième non — un
/// journal immuable, un référentiel réglementaire ou un dépôt soumis à
/// rétention n'ont **aucun** moyen légitime de détruire une donnée.
///
/// D'où la forme retenue : la purge n'est **pas** ajoutée au port (ce qui
/// obligerait chaque implémentation existante à écrire une méthode qu'elle ne
/// veut pas), mais **déclarée** par un mixin que le dépôt applique s'il sait la
/// servir. Un dépôt qui ne l'applique pas reste un `ZRepository` complet et
/// valide : les assemblages n'offrent simplement aucun geste de purge.
library;

import 'package:dartz/dartz.dart' show Unit;

import '../contracts/z_entity.dart';
import '../failures/z_failure.dart';
import 'z_repository.dart';

/// Déclare qu'un dépôt sait **supprimer définitivement** une entité.
///
/// ## Comment le déclarer
///
/// Le mixin ne pose **aucune contrainte de superclasse** : il s'applique à un
/// dépôt quelle que soit la façon dont celui-ci satisfait [ZRepository]
/// (extension ou implémentation d'interface).
///
/// ```dart
/// class MonDepot with ZPurgeable<Dossier> implements ZRepository<Dossier> {
///   @override
///   Future<ZResult<Unit>> purge(String id) async {
///     // suppression définitive, irréversible
///     return const Right(unit);
///   }
///   // … reste du port
/// }
/// ```
///
/// ## Comment le consommer
///
/// La capacité se teste par un `is`, jamais par une convention de nommage :
///
/// ```dart
/// final depot = mesDepots.dossiers;
/// if (depot is ZPurgeable<Dossier>) {
///   await (depot as ZPurgeable<Dossier>).purge(id);
/// }
/// ```
///
/// Le cast explicite n'est pas une maladresse : n'ayant **aucune contrainte de
/// superclasse** (c'est ce qui lui permet de s'appliquer à n'importe quel
/// dépôt), le mixin n'est pas un sous-type de [ZRepository], et le test `is` ne
/// promeut donc pas une variable déclarée `ZRepository<T>`.
///
/// C'est exactement ce que fait `ZCrudScreen` : sans le mixin, l'action
/// « supprimer définitivement » n'est **pas construite** — aucun bouton, aucune
/// erreur, aucun crash.
///
/// ## Ce que la purge doit garantir
///
/// * **Irréversible et assumée** : contrairement à `softDelete`, rien ne
///   permettra de revenir en arrière. Les assemblages du socle la font
///   précéder d'une confirmation au ton irréversible.
/// * **Contrat de résultat inchangé** (AD-11) : `ZResult<Unit>`, jamais
///   d'exception à travers la frontière du dépôt.
/// * **Idempotence** : purger une identité déjà absente est un **succès**
///   (`Right(unit)`), pas une erreur — le geste a atteint son but.
/// * **Synchronisation** : sur un dépôt offline-first, une purge purement
///   locale ne propage aucun tombstone ; l'implémentation doit propager la
///   suppression **avant** de retirer l'entrée locale, faute de quoi le merge
///   Last-Write-Wins ressusciterait l'entité (AD-9).
mixin ZPurgeable<T extends ZEntity> {
  /// Supprime **définitivement** l'entité d'identité [id].
  ///
  /// Irréversible : contrairement à `ZRepository.softDelete`, l'entité ne
  /// figurera plus dans aucune portée de lecture, corbeille comprise. Purger
  /// une identité absente rend `Right(unit)` (idempotent).
  Future<ZResult<Unit>> purge(String id);
}
