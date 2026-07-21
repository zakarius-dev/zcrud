/// Port **flashcard-local** `ZRepetitionStore` — persistance offline-first de
/// l'état SRS `ZRepetitionInfo`, adressé par `flashcardId` (Story E9-4, AC1/AC2).
///
/// origine: canonique §7 (l.305-306) — l'état de répétition espacée est persisté
/// dans un canal **séparé** du sous-arbre partageable de la carte. Ce canal
/// garantit l'invariant SRS (AD-9) : dupliquer/partager une carte n'emporte
/// **jamais** l'historique SRS avec le corps de la carte.
///
/// ## ⚠️ CE QUE CE CANAL NE GARANTIT PAS À LUI SEUL (CR-IFFD-4, 2026-07-20)
///
/// La documentation affirmait auparavant que ce canal empêchait de partager
/// « l'historique SRS **d'autrui** ». **C'était faux**, et l'écart est corrigé
/// ici. Le canal sépare le SRS **du corps de la carte** — il ne sépare pas, par
/// construction, le SRS **entre utilisateurs** : la clé logique documentée
/// (`{cardId}`) est la même pour tous.
///
/// Or plusieurs utilisateurs révisant la **même carte partagée** est un mode
/// nominal (dossiers publics/partagés), pas un cas limite. Sans scope
/// d'appartenance, leurs progressions **collisionnent sur un unique
/// enregistrement** : le dernier écrit gagne, les autres sont détruites — sans
/// erreur ni trace.
///
/// ## CONTRAT : une instance = UN propriétaire (NON-NÉGOCIABLE)
///
/// Ce port est **abstrait et toujours injecté** — zcrud n'en fournit
/// **aucune** implémentation concrète (l'adaptateur est la responsabilité de la
/// composition root de l'app). C'est précisément là que le scope se pose :
///
/// > **Une instance de [ZRepetitionStore] est liée à EXACTEMENT UN propriétaire.**
/// > L'adaptateur DOIT porter l'identité du propriétaire (typiquement l'`uid`)
/// > **dans son chemin de persistance** — p. ex.
/// > `users/{uid}/study_repetitions/{cardId}` — et non dans la clé passée aux
/// > méthodes.
///
/// 🚫 **N'encodez JAMAIS le propriétaire dans le `flashcardId`**
/// (`'{uid}_{cardId}'`) : cela corromprait la jointure carte↔répétition dont
/// dépendent [deleteByCard] et la purge des orphelins.
///
/// ### Limite résiduelle assumée — purge inter-propriétaires
///
/// Une instance liée à un propriétaire ne peut atteindre que SES
/// enregistrements. Supprimer une carte partagée via
/// `zFlashcardCascadeDeleteRoot` purge donc le SRS du **seul** propriétaire
/// courant ; ceux des autres deviennent orphelins. C'est **délibéré** — un
/// client n'a ni le droit ni les moyens de supprimer l'état d'autrui. Le balayage
/// inter-propriétaires relève du **backend** (tâche planifiée / Cloud Function),
/// jamais de ce port.
///
/// **Pourquoi un port flashcard-local (et non `ZSyncableRepository`) ?** —
/// `ZRepetitionInfo` **n'est pas** un `ZEntity` (clé de jointure `flashcardId`,
/// **sans** `id` ni `updatedAt`). Il ne peut donc **pas** transiter par
/// `ZSyncableRepository<T extends ZEntity>` / `ZLocalStore<T>` / `ZRemoteStore<T>`
/// directement. Ce port **mime** la sémantique offline-first d'E5 (local
/// autoritaire + distant best-effort + merge Last-Write-Wins) mais reste
/// **neutre**, et vit **dans `zcrud_flashcard`** — **aucune** édition de
/// `zcrud_core`, **aucune** arête vers le paquet adaptateur Firestore/Firebase
/// (AD-1).
///
/// **LWW via `ZSyncMeta` hors-entité** — l'état `ZRepetitionInfo` ne portant
/// **aucun** champ `updatedAt`, la clé de merge Last-Write-Wins est estampillée
/// **hors-entité** par le store à chaque [put] (miroir du standard `ZSyncMeta`
/// d'E5). L'algorithme SRS n'intervient **jamais** à la (dé)sérialisation ni au
/// merge : l'état est persisté/mergé **tel quel** (AD-9/AD-10, AC9).
///
/// **Contrat de résultat (AD-11)** : toutes les signatures retournent
/// `ZResult<…>` / `ZResult<Unit>` **nus** ; aucun type backend (Firestore/Hive)
/// ne fuite. L'**adaptateur concret** offline-first (Hive/Firestore) est
/// **déféré** (composition root / E9-5) — E9-4 ne livre que le port + des fakes
/// en mémoire, entièrement testables sans Firebase.
library;

import 'package:zcrud_core/domain.dart';

import '../domain/z_repetition_info.dart';

/// Contrat **abstrait** (port) de persistance offline-first de l'état SRS,
/// adressé par `flashcardId` (canal séparé top-level `study_repetitions/{cardId}`).
///
/// **Neutre** (AD-1/AD-5) : aucune signature n'expose de type backend. Injecté
/// dans `ZFlashcardRepository` (aucun singleton — testabilité).
abstract class ZRepetitionStore {
  /// Lit l'état SRS de la carte [flashcardId].
  ///
  /// **`vide ≠ erreur` (AD-10)** : un état absent retourne `Right(null)`
  /// (jamais un `Left`) — le coordinateur retombe alors sur `initial()`. Un
  /// état persisté **corrompu** est reconstruit **défensivement** via
  /// `ZRepetitionInfo.fromMap` (jamais de throw). Un `Left` n'est réservé
  /// qu'à une **panne réelle** du store local (`ZCacheFailure`).
  Future<ZResult<ZRepetitionInfo?>> getByCard(String flashcardId);

  /// Persiste l'état [info] (clé `flashcardId`), en **estampillant** la méta
  /// Last-Write-Wins (`ZSyncMeta.updatedAt`) **hors-entité** — l'état n'ayant
  /// pas de champ `updatedAt`. Écrit l'état **tel quel** (aucun recalcul SRS,
  /// AC9). Retourne l'état persisté.
  Future<ZResult<ZRepetitionInfo>> put(ZRepetitionInfo info);

  /// Lit un **snapshot** de tous les états SRS connus (sélection de session
  /// filtrée en mémoire — dette A2 assumée côté coordinateur). `vide ≠ erreur`
  /// (`Right(<[]>)`).
  Future<ZResult<List<ZRepetitionInfo>>> getAll();

  /// **Purge** l'état SRS de la carte [flashcardId] (me-3, AC5/AC6 —
  /// AD-10/AD-39).
  ///
  /// **Racine de la dette d'orphelins lex** : sans primitive de purge, supprimer
  /// une carte laissait son `ZRepetitionInfo` **survivre** top-level
  /// (`study_repetitions/{cardId}`), orphelin. [deleteByCard] est le point
  /// d'écriture unique qui **corrige la cause** : appelé en **cascade** de la
  /// suppression de la carte (seam `zFlashcardCascadeDeleteRoot`, study-side),
  /// il garantit qu'aucun état SRS ne subsiste après suppression.
  ///
  /// **Idempotence (AD-10)** : purger un `flashcardId` **absent** est un
  /// **succès** (`Right(unit)`), jamais un `Left` — un double-appel ou une carte
  /// jamais inscrite ne fait **jamais** échouer la cascade. Un `Left`
  /// (`ZCacheFailure`) n'est réservé qu'à une **panne réelle** du store local ;
  /// il est alors **rapporté** au grain de la racine (AD-39), jamais avalé.
  Future<ZResult<Unit>> deleteByCard(String flashcardId);

  /// Synchronise **une fois** le store avec son backend distant (best-effort,
  /// AD-9) : `Right(unit)` si déconnecté (jamais une erreur « offline »),
  /// l'échec étant **loggé**. Miroir de `ZSyncableRepository.sync`.
  Future<ZResult<Unit>> sync();

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
