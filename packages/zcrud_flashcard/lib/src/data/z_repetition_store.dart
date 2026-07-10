/// Port **flashcard-local** `ZRepetitionStore` — persistance offline-first de
/// l'état SRS `ZRepetitionInfo`, adressé par `flashcardId` (Story E9-4, AC1/AC2).
///
/// origine: canonique §7 (l.305-306) — l'état de répétition espacée est persisté
/// **top-level** `study_repetitions/{cardId}`, **jamais** dans le sous-arbre
/// partageable de la carte. Ce canal séparé garantit l'invariant SRS top-level
/// (AD-9) : dupliquer/partager une carte n'emporte **jamais** l'historique SRS
/// d'autrui.
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

import 'package:zcrud_core/zcrud_core.dart';

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
  /// qu'à une **panne réelle** du store local (`CacheFailure`).
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

  /// Synchronise **une fois** le store avec son backend distant (best-effort,
  /// AD-9) : `Right(unit)` si déconnecté (jamais une erreur « offline »),
  /// l'échec étant **loggé**. Miroir de `ZSyncableRepository.sync`.
  Future<ZResult<Unit>> sync();

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
