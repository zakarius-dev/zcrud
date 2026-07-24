/// Port **neutre** de la couche données : store **local** offline-first.
///
/// origine: canonique §7 — « à abstraire derrière `ZLocalStore`/`ZRemoteStore` ».
/// Introduit **avec** son adaptateur en E5 (différé explicitement par E2-2).
/// AD-5 (backend-agnostique) ; AD-9 (offline-first) ; AD-10 (défensif) ;
/// AD-11 (`Either`/flux nus) ; AD-14 (matérialisation de l'éphémère) ;
/// AD-16 (soft-delete hors-entité).
library;

import 'package:dartz/dartz.dart' show Unit;

import '../contracts/z_entity.dart';
import '../failures/z_failure.dart';
import '../sync/z_sync_entry.dart';

/// Contrat **abstrait** (port) du store **local** d'un agrégat [T] — la moitié
/// « qui fait autorité » du patron offline-first (AD-9).
///
/// **Source de vérité offline-first** (AD-9) : c'est le store local qui **fait
/// autorité**. Le distant ([ZRemoteStore]) est best-effort et ne dicte jamais
/// l'état ; la composition « local autoritaire ↔ distant fire-and-forget », le
/// **merge Last-Write-Wins** sur `updatedAt` et la cascade bornée sont
/// l'affaire d'**E5-3/E5-4** — **hors** de ce port (aucune méthode `sync()`/
/// `merge()` ici, frontière **volontaire**).
///
/// **Backend-agnostique** (AD-5) : aucune signature n'expose de type `hive`
/// (`Box`, `HiveObject`, `HiveInterface`…). L'implémentation par défaut est
/// Hive-JSON (`zcrud_firestore`), mais l'abstraction autorise un backend
/// **Isar/Drift/SQLite** ultérieur (déféré) **sans** changer ce contrat.
///
/// **Contrat de résultat** (AD-11) : les opérations retournent `ZResult<...>`
/// (`Either<ZFailure, T>`) / `ZResult<Unit>` ; le local étant un **cache**, une
/// erreur d'accès est un [ZCacheFailure] (jamais `ZServerFailure`). Les **flux**
/// sont des `Stream<List<T>>` **NUS** — jamais enveloppés dans un `Either`.
///
/// **Invariants portés par l'impl** (AD-14/AD-16, documentés ici, non
/// implémentés) :
/// - [put] **matérialise l'éphémère** : une entité sans `id` (`isEphemeral`) se
///   voit attribuer une identité opaque à l'écriture ; le corps persisté porte
///   **toujours** son `id` (invariant clé↔corps).
/// - [softDelete]/[restore] basculent `is_deleted` **hors-entité** (`ZSyncMeta`,
///   AD-16) **sans** toucher aux champs métier ; la suppression locale est un
///   **soft-delete** (drapeau), **jamais** une purge physique. Les lectures
///   excluent les soft-deleted de façon **cohérente** (get / getAll / watch).
abstract class ZLocalStore<T extends ZEntity> {
  /// Flux temps réel **nu** des éléments **visibles** (non soft-deleted).
  ///
  /// Seed immédiat (état courant) puis ré-émission à chaque mutation
  /// ([put]/[softDelete]/[restore]). Jamais enveloppé dans un `Either` (AD-11).
  Stream<List<T>> watchAll();

  /// Lit tous les éléments **visibles** (exclut les soft-deleted). Un store vide
  /// renvoie `Right(<T>[])` (`vide ≠ erreur`).
  Future<ZResult<List<T>>> getAll();

  /// Lit l'élément d'identité [id]. `Left(ZNotFoundFailure)` s'il est absent ou
  /// soft-deleted (`null ≠ erreur`, AD-11).
  Future<ZResult<T>> getById(String id);

  /// Persiste [item] dans le cache local (source de vérité). Matérialise
  /// l'éphémère (attribution d'`id` opaque, AD-14) et renvoie l'entité
  /// matérialisée. Réécrit `is_deleted:false`/`updated_at` (`ZSyncMeta`).
  ///
  /// ⚠️ **ÉCRASEMENT TOTAL** : le document persisté est **remplacé** par la
  /// sérialisation de [item]. Une clé présente en base mais **absente** de la
  /// map de [item] — typiquement écrite par un **AUTRE hôte** — est **perdue**.
  /// Pour préserver l'existant non mappé, voir [putMerged] (CR-LEX-34).
  Future<ZResult<T>> put(T item);

  /// **Écriture PRÉSERVANTE** (CR-LEX-34) : fusionne la sérialisation de [item]
  /// **PAR-DESSUS** le document existant, clé à clé. Une clé présente en base
  /// mais **absente** de [item] — écrite par un autre hôte, ou champ hors-codegen
  /// que l'appelant n'a pas relu — **SURVIT**.
  ///
  /// ## Pourquoi ce membre existe
  ///
  /// [put] écrase le document **en totalité** : un hôte dont l'entité ne mappe
  /// pas 100 % des champs `Z` **détruit silencieusement** ceux qu'il ignore, et
  /// rien ne l'en avertit (le code compile, `analyze` est vert, aucun test ne
  /// rougit). C'est l'unique voie sans « relire-avant-écrire » manuel, dont
  /// l'oubli est **structurellement invisible**. [putMerged] déplace ce
  /// relire-fusionner **dans le store**, une fois, au lieu de le laisser à la
  /// charge de chaque appelant.
  ///
  /// ## Sémantique EXACTE, et sa limite ASSUMÉE
  ///
  /// - Les clés présentes dans [item] **écrasent** l'existant (dernière écriture
  ///   gagne pour ces clés).
  /// - Les clés présentes **uniquement** en base sont **conservées**.
  /// - ⚠️ **Ce merge est ADDITIF** : il ne peut pas EFFACER une clé. Un champ
  ///   que [item] omet — y compris un champ nullable remis à `null` (que
  ///   `toMap` **omet**) — est **préservé stale**, jamais supprimé. Pour un
  ///   effacement, utiliser [put] (remplacement total). Ce choix est ce que la
  ///   préservation exige : on ne peut pas distinguer « champ non mappé » de
  ///   « champ volontairement vidé » depuis la seule map de [item].
  ///
  /// Comme [put] : matérialise l'éphémère, réestampille `updated_at=now` et
  /// **ressuscite** (`is_deleted:false`) — un `putMerged` **est** une mutation
  /// utilisateur, pas l'application d'un merge de sync (pour cela, [applyMerged]).
  ///
  /// **Défaut** : les implémentations qui ne savent pas fusionner au niveau du
  /// document brut **doivent** rendre un `Left(ZCacheFailure)` explicite —
  /// **jamais** un repli silencieux sur [put], qui rouvrirait exactement la
  /// destruction invisible que ce membre élimine.
  Future<ZResult<T>> putMerged(T item);

  /// Soft-delete l'élément [id] (`is_deleted = true`, hors-entité `ZSyncMeta`).
  /// **Jamais** de purge physique. `id` absent → `Left(ZNotFoundFailure)`.
  Future<ZResult<Unit>> softDelete(String id);

  /// Restaure l'élément [id] soft-deleted (`is_deleted = false`). `id` absent →
  /// `Left(ZNotFoundFailure)`.
  Future<ZResult<Unit>> restore(String id);

  /// **Voie de lecture de SYNCHRONISATION** (E5-3) : lit **toutes** les entrées
  /// **y compris soft-deletées** (tombstones), chacune appariée à son
  /// [ZSyncMeta] (`updatedAt`/`isDeleted`). Un store vide → `Right(<ZSyncEntry>[])`.
  ///
  /// **Contraste voulu avec [getAll]** : [getAll] exclut les tombstones (lecture
  /// « visible »), alors que [syncEntries] les **inclut** — indispensable au merge
  /// Last-Write-Wins (E5-3), qui doit voir de **chaque côté** l'`updated_at` ET
  /// l'`is_deleted` de toute entrée pour propager une suppression. Décodage
  /// **défensif** (AD-10) : une entrée non décodable est **écartée + loggée**,
  /// jamais un `throw`. Erreur d'accès (cache) → `Left(ZCacheFailure)`.
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries();

  /// **Écriture PRÉSERVANT la méta** (E5-3) : écrit l'entité **et** son
  /// [ZSyncMeta] **verbatim** — `updated_at`/`is_deleted` **conservés tels quels**,
  /// **jamais** réestampillés `now()`.
  ///
  /// **RÉSERVÉ à l'application d'un résultat de merge** : [put] réestampille
  /// `updated_at = now()` (vraie mutation utilisateur) ; l'appliquer à un gagnant
  /// de merge casserait le LWW (le côté qui « adopte » paraîtrait toujours le plus
  /// récent → ping-pong). [applyMerged] est donc la voie **sans `now()`**, hors
  /// chemin d'écriture utilisateur. Écrire une [entry] `isDeleted:true` **propage
  /// un tombstone** (soft-delete). Le corps persiste **toujours** son `id`
  /// (invariant clé↔corps). Erreur d'accès → `Left(ZCacheFailure)`.
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry);

  /// **Purge physique par identité** (CR-LEX-35) : supprime DÉFINITIVEMENT
  /// l'entrée [id] du cache local, **SANS** tombstone.
  ///
  /// ## Pourquoi, et en quoi c'est DISTINCT de [softDelete]
  ///
  /// [softDelete] pose un tombstone (`is_deleted = true`) — nécessaire pour
  /// **propager** une suppression **utilisateur** au merge LWW. Mais une
  /// **annulation d'écriture** (une création qui a échoué, une carte refusée
  /// pour quota/type) n'a **pas** à être propagée : elle annule une écriture
  /// qui, précisément, ne doit **pas** avoir eu lieu. La forcer en tombstone
  /// laisse une entrée dans la box **indéfiniment** et **propage** au cloud une
  /// suppression de rattrapage — la box croît sans borne chez un utilisateur qui
  /// essuie beaucoup de refus.
  ///
  /// ## 🔴 PIÈGE — cette opération ne PROPAGE RIEN
  ///
  /// [purge] agit **uniquement sur le cache local**. Elle ne pousse **aucun**
  /// tombstone au distant. Conséquence, mesurée chez un hôte qui l'a adoptée à
  /// tort : si la suppression doit se **synchroniser**, purger retire le
  /// tombstone qui la portait ⇒ un autre appareil **RESSUSCITE** le document au
  /// prochain `sync()`. **C'est une perte de donnée**, silencieuse.
  ///
  /// Et un `softDelete`-puis-`purge` **ne sauve pas** la propagation : le push
  /// du `softDelete` est fire-and-forget et **relit** l'entrée locale ; une
  /// purge awaitée la retire avant cette relecture, le tombstone n'est jamais
  /// émis.
  ///
  /// ⚠️ **N'utiliser QUE si l'annulation est STRICTEMENT locale** — une écriture
  /// qui n'a jamais atteint le distant. Sinon :
  /// - suppression **utilisateur** à propager → [softDelete] ;
  /// - annulation à propager **sans** garder de tombstone local →
  ///   `ZStudyRepository.purgeLocalPropagatingTombstone` (CR-LEX-35), qui
  ///   propage **puis** purge, dans cet ordre.
  ///
  /// `id` absent → `Right(unit)` (idempotent : purger ce qui n'existe pas est un
  /// succès, pas une erreur — contrairement à [softDelete] qui exige la cible).
  Future<ZResult<Unit>> purge(String id);

  /// **Purge physique** de tout le cache local (maintenance/tests) — distincte
  /// du [softDelete] métier. À NE PAS utiliser comme voie de suppression d'une
  /// entité (celle-ci reste un soft-delete propagé au distant en E5-3).
  Future<ZResult<Unit>> clear();

  /// Libère les ressources (abonnements, contrôleurs de flux, box possédée).
  void dispose();
}
