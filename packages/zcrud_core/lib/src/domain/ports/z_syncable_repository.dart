/// Sur-port **synchronisable** du domaine `zcrud_core` : un [ZRepository] qui sait
/// **converger** avec un backend distant via un merge one-shot (E5-3).
///
/// origine: canonique §7 — `sync()` au contrat de dépôt. Ajout **additif** :
/// [ZRepository] (et son adaptateur pur-distant `FirebaseZRepositoryImpl`) reste
/// **inchangé** ; seul un dépôt offline-first (`ZOfflineFirstRepository`,
/// `zcrud_firestore`) implémente ce sur-port.
/// AD-9 (offline-first LWW) ; AD-11 (`Either`/flux nus).
library;

import 'package:dartz/dartz.dart' show Unit;

import '../contracts/z_entity.dart';
import '../failures/z_failure.dart';
import 'z_repository.dart';

/// Contrat **abstrait** d'un dépôt **synchronisable** : un [ZRepository] enrichi
/// d'une unique méthode [sync].
///
/// **Frontière E5-3 (le *comment*) vs E5-4 (le *quand*)** : [sync] est un appel
/// **one-shot** (pull + merge Last-Write-Wins + propagation bornée). Le *quand*
/// (login/reconnexion **débouncée**) et le pilotage d'un **ensemble** de dépôts
/// enregistrés appartiennent au `ZSyncOrchestrator` (E5-4) — **hors** de ce port.
abstract class ZSyncableRepository<T extends ZEntity> extends ZRepository<T> {
  /// Synchronise **une fois** le dépôt avec son backend distant : pull des méta
  /// (tombstones inclus) des deux côtés, merge **Last-Write-Wins** sur
  /// `updatedAt`, application locale des gagnants distants et propagation
  /// **bornée** des gagnants locaux.
  ///
  /// **`Right(unit)` si déconnecté** (best-effort, AD-9) : un distant injoignable
  /// (couture de connectivité `false`, ou `Left(ZServerFailure)` distant) est
  /// traité comme « offline » → `Right(unit)` (jamais une erreur « offline »),
  /// l'échec étant **loggé**. En revanche une **panne locale**
  /// (`Left(ZCacheFailure)`) est une vraie erreur → `Left` (jamais avalée).
  Future<ZResult<Unit>> sync();
}
