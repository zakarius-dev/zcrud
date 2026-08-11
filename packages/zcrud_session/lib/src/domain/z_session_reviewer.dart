/// Seam d'écriture SRS injecté par l'hôte au moteur de session.
///
/// Le moteur de session (`ZStudySessionEngine`) ne possède aucun champ
/// `ZSrsScheduler`/`ZRepetitionStore` et n'appelle jamais `apply`/`initial`/
/// `put` directement. La seule mutation de l'état SRS transite par ce
/// port/callback, dont la signature est exactement celle de
/// `ZFlashcardRepository.reviewCard` — la voie d'écriture unique de
/// l'invariant AD-9 (offline-first, écriture SRS unique). Par construction,
/// il est impossible qu'un chemin de la session fasse progresser l'état SRS
/// hors de cette voie.
///
/// En production, le binding fournit typiquement :
/// `(f, q, now) => repo.reviewCard(flashcardId: f.flashcardId,
///  folderId: f.folderId, quality: q, now: now)` — le moteur reste ignorant
/// de Firestore/Hive (ports neutres, invariant AD-1).
library;

import 'package:zcrud_core/domain.dart' show ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionInfo;

/// Callback d'écriture SRS : applique une révision de [quality] à la carte
/// [flashcardId]/[folderId] et renvoie le nouvel état `ZRepetitionInfo`
/// enveloppé dans un `ZResult` (`Either<ZFailure, …>`, invariants AD-5/AD-11).
/// L'horloge éventuelle [now] est relayée telle quelle : le moteur ne lit
/// jamais `DateTime.now` lui-même, pour rester déterministe et testable.
typedef ZSessionReviewer = Future<ZResult<ZRepetitionInfo>> Function({
  required String flashcardId,
  required String folderId,
  required int quality,
  DateTime? now,
});
