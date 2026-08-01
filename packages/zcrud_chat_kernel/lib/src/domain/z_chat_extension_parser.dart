/// Contrat d'injection du parseur du slot `extension` du modèle de chat (AD-4).
library;

import 'package:zcrud_core/domain.dart';

/// Parseur **injecté par l'hôte** du slot `extension` d'une entité de chat.
///
/// origine: patron `ZFlashcardExtensionParser` / `ZSmartNoteExtensionParser`
/// (`packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart:60-62`) — le
/// registre ne peut pas passer un parseur typé au `fromMap` d'une entité, la
/// voie d'injection est donc un **paramètre nommé optionnel**.
///
/// ⚠️ Un parseur qui **lève** ou qui rend `null` ne coûte **jamais** la donnée :
/// `zDecodeExtension` retombe sur un `ZOpaqueExtension` portant le payload
/// verbatim (CR-LEX-33), et le parent survit (AD-10).
typedef ZChatExtensionParser = ZExtension? Function(Map<String, dynamic> json);
