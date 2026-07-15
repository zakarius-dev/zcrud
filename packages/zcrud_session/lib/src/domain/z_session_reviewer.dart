/// Seam d'écriture SRS injecté (`ZSessionReviewer`) — ES-4.2, D4 (AD-9/AD-23).
///
/// Le moteur de session (`ZStudySessionEngine`) **NE possède AUCUN** champ
/// `ZSrsScheduler`/`ZRepetitionStore` et **n'appelle JAMAIS** `apply`/`initial`/
/// `put`. La **seule** mutation de l'état SRS transite par ce **port/callback**,
/// dont la signature est **exactement** celle de
/// `ZFlashcardRepository.reviewCard` (la voie d'écriture UNIQUE verrouillée en
/// ES-4.1, AD-9). ⇒ *par construction*, il est **impossible** qu'un chemin de la
/// session fasse progresser l'état SRS hors de cette voie unique.
///
/// En prod, le binding fournit :
/// `(f, q, now) => repo.reviewCard(flashcardId: f.flashcardId,
///  folderId: f.folderId, quality: q, now: now)` — le moteur reste **ignorant**
/// de Firestore/Hive (ports neutres, AD-1).
library;

import 'package:zcrud_core/domain.dart' show ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZRepetitionInfo;

/// Callback d'écriture SRS : applique une révision de [quality] à la carte
/// [flashcardId]/[folderId] et renvoie le nouvel état `ZRepetitionInfo`
/// enveloppé `ZResult` (`Either<ZFailure, …>`, AD-5/AD-11). L'horloge éventuelle
/// [now] est **relayée** (déterminisme : le moteur ne lit jamais `DateTime.now`,
/// D6).
typedef ZSessionReviewer = Future<ZResult<ZRepetitionInfo>> Function({
  required String flashcardId,
  required String folderId,
  required int quality,
  DateTime? now,
});
