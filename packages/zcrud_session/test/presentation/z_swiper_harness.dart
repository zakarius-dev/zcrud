/// Harnais PARTAGÉ des tests de la pile su-4 — factorise l'hôte, l'espion de
/// reviewer et la file (miroir de `z_answer_input_harness.dart`, su-3).
///
/// 🔒 **L'hôte de test reproduit la composition de PROD** (AC6) : la pile est
/// **frère** de la surface de saisie et de la rangée de notation — celles-ci ne
/// descendent JAMAIS dans le `cardBuilder`.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show Left, Right, ZFailure, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZRepetitionInfo, ZSrsConfig;

/// Espion d'écriture SRS — il **ENREGISTRE** (jamais un no-op de prod : AD-34).
///
/// 🔴 Sa capacité d'être appelé est prouvée **dans le même test** par la voie
/// légitime (`ZSrsQualityButtons`) : sans ce témoin positif, un « 0 appel »
/// resterait vert même si tout le câblage avait disparu.
class SpyReviewer {
  SpyReviewer({this.failure});

  /// Si non nul, le seam échoue (`Left`) — pour prouver que la file **n'avance
  /// pas** et que l'échec est **exposé** (AD-5/AD-10).
  final ZFailure? failure;

  /// Appels reçus, dans l'ordre.
  final List<({String flashcardId, String folderId, int quality})> calls =
      <({String flashcardId, String folderId, int quality})>[];

  /// Nombre d'appels — raccourci de lisibilité.
  int get count => calls.length;

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    calls.add((flashcardId: flashcardId, folderId: folderId, quality: quality));
    final f = failure;
    if (f != null) return Left<ZFailure, ZRepetitionInfo>(f);
    return Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

/// Enveloppe `MaterialApp`/`Scaffold` minimale.
Widget wrapApp(Widget child, {ZSrsConfig? config}) => MaterialApp(
      home: Scaffold(body: child),
    );
