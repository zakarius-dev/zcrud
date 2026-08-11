/// Seam de suppression en cascade d'une flashcard : carte puis purge de son
/// état de répétition espacée.
///
/// La suppression par lot de flashcards (`ZListSelectionController.batchDelete`)
/// prend un seam injecté `deleteRoot` (une racine produit un `ZResult`),
/// attendu racine par racine. [zFlashcardCascadeDeleteRoot] matérialise ce
/// seam pour les flashcards : il compose la suppression de la carte
/// (`deleteCard`) puis la purge de son état de répétition espacée
/// (`ZRepetitionStore.deleteByCard`). C'est le point de composition unique de
/// cette purge : sans lui, supprimer une carte laisserait son
/// `ZRepetitionInfo` survivre au niveau racine du store, orphelin.
///
/// **Portée bornée à la suppression par lot.** Cette composition vaut pour
/// le chemin de suppression par lot (barre de sélection). La suppression
/// unitaire — menu contextuel d'une carte — ne passe pas nécessairement par
/// ce seam : elle emprunte le callback fourni par l'application tel quel.
/// Pour que la purge de répétition espacée soit garantie sur toutes les
/// voies de suppression, l'**application doit router sa suppression unitaire
/// par le même seam** (`zFlashcardCascadeDeleteRoot(...)('id')`) — sans quoi
/// une suppression au menu laisserait à nouveau un `ZRepetitionInfo`
/// orphelin. Ce fichier fournit et prouve le seam ; le câblage exhaustif des
/// voies de suppression au-dessus reste la responsabilité du consommateur.
///
/// Ce fichier vit délibérément dans `lib/src/data/` et non
/// `lib/src/presentation/` : il importe `ZRepetitionStore`, un symbole que
/// la garde de pureté des widgets bannit de la couche présentation (aucun
/// store dans un widget). Le widget de liste (`ZFlashcardListView`) reste
/// pur : il ne connaît que le seam `deleteRoot` injecté, jamais ce store
/// directement.
///
/// La cascade par racine ({carte + `ZRepetitionInfo`}, soit environ deux
/// écritures) reste très en dessous de toute limite de lot : ce seam n'émet
/// jamais un plan monolithique. Chaque échec (suppression ou purge) est
/// rapporté au grain de la racine par l'appelant — jamais avalé
/// silencieusement.
library;

import 'package:zcrud_core/zcrud_core.dart' show ZResult, Unit;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionStore;

/// Fabrique le seam `deleteRoot` de suppression cascadée d'une flashcard
/// (carte puis purge de répétition espacée), attendu par
/// `ZListSelectionController.batchDelete`.
///
/// Pour chaque `rootId` (identifiant stable de la carte — jamais un index) :
/// 1. supprime la carte via [deleteCard] (`ZResult<Unit>`, injecté par
///    l'application — typiquement `repository.softDelete`) ;
/// 2. si et seulement si (1) réussit, purge l'état de répétition espacée via
///    `repetitionStore.deleteByCard(rootId)` (idempotent).
///
/// **Court-circuit** : si la suppression de la carte échoue (`Left`), la
/// purge n'est pas tentée et le `Left` de la carte est renvoyé tel quel (la
/// racine est rapportée échouée par l'appelant). Si la carte est supprimée
/// mais la purge échoue, le `Left` de la purge est renvoyé : la racine est
/// rapportée échouée — jamais un succès masquant un état de répétition
/// orphelin.
///
/// N'émet aucun `throw` ; tout `Left` remonte à l'appelant, qui l'agrège au
/// grain de la racine (les autres racines continuent).
Future<ZResult<Unit>> Function(String rootId) zFlashcardCascadeDeleteRoot({
  required Future<ZResult<Unit>> Function(String flashcardId) deleteCard,
  required ZRepetitionStore repetitionStore,
}) {
  return (String rootId) async {
    final deleted = await deleteCard(rootId);
    // Court-circuit : la carte n'a pas été supprimée, on ne purge donc pas
    // l'état de répétition espacée (on ne détruit pas l'historique d'une
    // carte encore vivante) et on rapporte l'échec de la carte tel quel.
    if (deleted.isLeft()) return deleted;
    // Carte supprimée : purge en cascade, attendue (jamais fire-and-forget).
    // Un échec de purge est renvoyé (Left) : la racine est rapportée
    // échouée par l'appelant (l'orphelin potentiel n'est jamais silencieux).
    return repetitionStore.deleteByCard(rootId);
  };
}
