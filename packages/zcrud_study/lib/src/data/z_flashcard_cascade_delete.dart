/// Seam de **cascade de suppression** carte + purge SRS (me-3, FR-SU19 —
/// AD-21/AD-39/AD-10/AD-1).
///
/// ## Pourquoi ce seam existe (dette d'orphelins lex corrigée par conception)
///
/// La suppression par lot de flashcards (`ZListSelectionController.batchDelete`,
/// me-1) prend un **seam INJECTÉ** `deleteRoot` (une racine ⇒ un `ZResult`)
/// `await`é **par racine**. [zFlashcardCascadeDeleteRoot] **matérialise**
/// ce seam pour les flashcards : il **compose** la suppression de la carte
/// (`deleteCard`) **PUIS** la **purge** de son état SRS
/// (`ZRepetitionStore.deleteByCard`). C'est le **point de composition unique** de
/// la purge : sans lui, on supprimait la carte et son `ZRepetitionInfo`
/// **survivait** top-level (`study_repetitions/{cardId}`), orphelin — le bug lex.
///
/// ## 🔴 LOW-A — bornage : ce seam ne corrige que la suppression **PAR LOT**
///
/// La « dette d'orphelins corrigée par conception » vaut **exactement** pour le
/// chemin de **lot** (`batchDelete` de la barre de sélection me-3). La
/// suppression **UNITAIRE** — menu contextuel d'une carte
/// (`ZFlashcardListView.onDelete`), prop `su-8` app-side — **ne passe PAS** par
/// ce seam : elle emprunte le callback de l'app tel quel. Pour que la purge SRS
/// soit garantie **partout**, **l'app DOIT router sa suppression unitaire par le
/// MÊME seam** (`zFlashcardCascadeDeleteRoot(...)('id')`), sans quoi une
/// suppression au menu laisserait à nouveau un `ZRepetitionInfo` orphelin. me-3
/// fournit et prouve le seam ; le **câblage exhaustif** des voies de suppression
/// dessus reste la responsabilité du consommateur (hors périmètre widget).
///
/// ## Pourquoi ce fichier vit dans `lib/src/data/` (et PAS `presentation/`)
///
/// Il importe `ZRepetitionStore` — symbole **banni** de
/// `lib/src/presentation/**` par la garde de pureté (`z_widgets_purity_test.dart`,
/// AD-23/AD-33 : aucun store dans un widget). Le **widget** de liste
/// (`ZFlashcardListView`) reste **PUR** : il ne connaît que le seam `deleteRoot`
/// injecté, jamais ce store. L'arête `zcrud_study → zcrud_flashcard` est
/// **existante** (AD-1) ; CORE OUT=0 inchangé.
///
/// ## Bornes (AD-21) & rapport (AD-39)
///
/// La cascade **par racine** est {carte + `ZRepetitionInfo`} ≈ **2** écritures
/// ≪ 450 : ce seam n'émet **jamais** un plan monolithique. Un lot volumineux
/// reste borné par le fait que `batchDelete` `await`e racine **par** racine (M
/// cascades successives) ; la borne physique ≤ 450/lot d'une cascade éventuelle
/// plus profonde est la propriété du **batcher app-side** (`ZFirestoreCascadeBatcher`),
/// jamais de me-3. Chaque `Left` (suppression **ou** purge) est **rapporté** au
/// grain de la racine par `batchDelete` (`ZBatchDeletionReport`) — jamais avalé.
library;

import 'package:zcrud_core/zcrud_core.dart' show ZResult, Unit;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionStore;

/// Fabrique le seam `deleteRoot` de suppression **cascadée** d'une flashcard
/// (carte + purge SRS), attendu par `ZListSelectionController.batchDelete`.
///
/// Pour chaque `rootId` (`id` STABLE de la carte — jamais un index) :
/// 1. supprime la carte via [deleteCard] (`ZResult<Unit>`, injecté par l'app —
///    typiquement `repository.softDelete`) ;
/// 2. **si et seulement si** (1) réussit, purge l'état SRS via
///    [repetitionStore]`.deleteByCard(rootId)` (idempotent, AD-10).
///
/// **Short-circuit (AD-39)** : si la suppression de la carte échoue (`Left`), la
/// purge SRS **n'est PAS tentée** et le `Left` de la carte est renvoyé tel quel
/// (la racine est rapportée échouée par `batchDelete`). Si la carte est
/// supprimée mais la purge échoue, le `Left` de la **purge** est renvoyé : la
/// racine est rapportée échouée (jamais un succès masquant un SRS orphelin).
///
/// Aucun `throw` n'est émis ici ; tout `Left` remonte à `batchDelete` qui l'agrège
/// au grain de la racine (les **autres** racines continuent — AC6).
Future<ZResult<Unit>> Function(String rootId) zFlashcardCascadeDeleteRoot({
  required Future<ZResult<Unit>> Function(String flashcardId) deleteCard,
  required ZRepetitionStore repetitionStore,
}) {
  return (String rootId) async {
    final deleted = await deleteCard(rootId);
    // Short-circuit AD-39 : la carte n'a pas été supprimée ⇒ on NE purge PAS le
    // SRS (on ne détruit pas l'historique d'une carte encore vivante) et on
    // rapporte l'échec de la carte tel quel.
    if (deleted.isLeft()) return deleted;
    // Carte supprimée ⇒ purge SRS EN CASCADE, `await`ée (jamais fire-and-forget).
    // Un échec de purge est renvoyé (Left) ⇒ racine rapportée échouée par
    // `batchDelete` (l'orphelin potentiel n'est jamais silencieux).
    return repetitionStore.deleteByCard(rootId);
  };
}
