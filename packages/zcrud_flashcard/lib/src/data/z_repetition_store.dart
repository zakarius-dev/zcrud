/// Port flashcard-local `ZRepetitionStore` — persistance offline-first de
/// l'état SRS `ZRepetitionInfo`, adressé par `flashcardId`.
///
/// L'état de répétition espacée est persisté dans un canal séparé du
/// sous-arbre partageable de la carte. Ce canal garantit l'invariant AD-9 :
/// dupliquer ou partager une carte n'emporte jamais l'historique SRS avec le
/// corps de la carte.
///
/// ## Ce que ce canal ne garantit pas à lui seul
///
/// Ce canal sépare le SRS du corps de la carte — il ne sépare pas, par
/// construction, le SRS entre utilisateurs : la clé logique documentée
/// (identifiant de carte) est la même pour tous.
///
/// Or plusieurs utilisateurs révisant la même carte partagée est un mode
/// nominal (dossiers publics ou partagés), pas un cas limite. Sans périmètre
/// d'appartenance, leurs progressions collisionnent sur un unique
/// enregistrement : le dernier écrit gagne, les autres sont détruites — sans
/// erreur ni trace.
///
/// ## Contrat : une instance = un propriétaire
///
/// Ce port est abstrait et toujours injecté — ce paquet n'en fournit aucune
/// implémentation concrète (l'adaptateur est la responsabilité de la
/// composition racine de l'application). C'est précisément là que le
/// périmètre se pose :
///
/// > Une instance de [ZRepetitionStore] est liée à exactement un
/// > propriétaire. L'adaptateur doit porter l'identité du propriétaire
/// > (typiquement l'identifiant utilisateur) dans son chemin de
/// > persistance — par exemple `users/{uid}/study_repetitions/{cardId}` —
/// > et non dans la clé passée aux méthodes.
///
/// N'encodez jamais le propriétaire dans le `flashcardId`
/// (`'{uid}_{cardId}'`) : cela corromprait la jointure carte-répétition dont
/// dépendent [deleteByCard] et la purge des orphelins.
///
/// ### Limite résiduelle assumée — purge inter-propriétaires
///
/// Une instance liée à un propriétaire ne peut atteindre que ses
/// enregistrements. Supprimer une carte partagée purge donc le SRS du seul
/// propriétaire courant ; ceux des autres deviennent orphelins. C'est
/// délibéré — un client n'a ni le droit ni les moyens de supprimer l'état
/// d'autrui. Le balayage inter-propriétaires relève du backend (tâche
/// planifiée ou fonction cloud), jamais de ce port.
///
/// ## Pourquoi un port flashcard-local
///
/// `ZRepetitionInfo` n'est pas un `ZEntity` (clé de jointure `flashcardId`,
/// sans `id` ni `updatedAt`). Il ne peut donc pas transiter par les ports
/// génériques du cœur destinés aux entités. Ce port mime la sémantique
/// offline-first du cœur (local autoritaire, distant best-effort, merge
/// Last-Write-Wins) mais reste neutre, et vit dans `zcrud_flashcard` —
/// aucune édition de `zcrud_core`, aucune arête vers un paquet adaptateur
/// backend (invariant AD-1).
///
/// L'état `ZRepetitionInfo` ne portant aucun champ `updatedAt`, la clé de
/// merge Last-Write-Wins est estampillée hors entité par le store à chaque
/// [put] (miroir du standard `ZSyncMeta`). L'algorithme SRS n'intervient
/// jamais à la (dé)sérialisation ni au merge : l'état est persisté et
/// fusionné tel quel (invariants AD-9 et AD-10).
///
/// Contrat de résultat (invariant AD-11) : toutes les signatures retournent
/// `ZResult<…>` nus ; aucun type backend ne fuit. L'adaptateur concret
/// offline-first (Hive/Firestore) est fourni par la composition racine de
/// l'application.
library;

import 'package:zcrud_core/domain.dart';

import '../domain/z_repetition_info.dart';

/// Contrat abstrait (port) de persistance offline-first de l'état SRS,
/// adressé par `flashcardId` (canal séparé, top-level).
///
/// Neutre (invariants AD-1/AD-5) : aucune signature n'expose de type
/// backend. Injecté dans `ZFlashcardRepository` (aucun singleton —
/// testabilité).
abstract class ZRepetitionStore {
  /// Lit l'état SRS de la carte [flashcardId].
  ///
  /// Vide n'est pas une erreur (invariant AD-10) : un état absent retourne
  /// `Right(null)` (jamais un `Left`) — le coordinateur retombe alors sur
  /// `initial()`. Un état persisté corrompu est reconstruit défensivement
  /// via `ZRepetitionInfo.fromMap` (jamais d'exception). Un `Left` n'est
  /// réservé qu'à une panne réelle du store local.
  Future<ZResult<ZRepetitionInfo?>> getByCard(String flashcardId);

  /// Persiste l'état [info] (clé `flashcardId`), en estampillant la méta
  /// Last-Write-Wins hors entité — l'état n'ayant pas de champ `updatedAt`.
  /// Écrit l'état tel quel (aucun recalcul SRS). Retourne l'état persisté.
  Future<ZResult<ZRepetitionInfo>> put(ZRepetitionInfo info);

  /// Lit un instantané de tous les états SRS connus (sélection de session
  /// filtrée en mémoire côté coordinateur). Vide n'est pas une erreur
  /// (`Right(<[]>)`).
  Future<ZResult<List<ZRepetitionInfo>>> getAll();

  /// Purge l'état SRS de la carte [flashcardId].
  ///
  /// Sans primitive de purge, supprimer une carte laissait son
  /// `ZRepetitionInfo` survivre top-level, orphelin. [deleteByCard] est le
  /// point d'écriture unique qui corrige cette cause : appelé en cascade de
  /// la suppression de la carte, il garantit qu'aucun état SRS ne subsiste
  /// après suppression.
  ///
  /// Idempotence (invariant AD-10) : purger un `flashcardId` absent est un
  /// succès (`Right(unit)`), jamais un `Left` — un double appel ou une carte
  /// jamais inscrite ne fait jamais échouer la cascade. Un `Left` n'est
  /// réservé qu'à une panne réelle du store local ; il est alors rapporté,
  /// jamais avalé.
  Future<ZResult<Unit>> deleteByCard(String flashcardId);

  /// Synchronise une fois le store avec son backend distant (best-effort,
  /// invariant AD-9) : `Right(unit)` si déconnecté (jamais une erreur
  /// « hors ligne »), l'échec étant loggé. Miroir de
  /// `ZSyncableRepository.sync`.
  Future<ZResult<Unit>> sync();

  /// Libère les ressources (abonnements, contrôleurs de flux).
  void dispose();
}
