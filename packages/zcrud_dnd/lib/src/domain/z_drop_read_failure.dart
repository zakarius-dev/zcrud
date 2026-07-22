/// Échec **neutre** de lecture d'un contenu déposé (AD-57 : aucun type de
/// `super_drag_and_drop` / `super_clipboard` ne franchit cette frontière).
library;

import 'package:flutter/foundation.dart';

/// Levée **uniquement** par la future retournée par `ZDroppedItem.readBytes`,
/// jamais pendant le traitement du dépôt lui-même.
///
/// AD-10 — la réception d'un dépôt ne lève JAMAIS : un élément illisible est
/// ignoré ou remonté en `ZDropKind.unknown`. Mais lorsque l'hôte demande
/// **explicitement** les octets et que la plateforme ne peut pas les fournir
/// (fichier virtuel annulé, session déjà libérée, permission refusée), rendre
/// un `Uint8List` vide serait un mensonge : l'hôte croirait tenir un fichier
/// vide. L'échec est donc porté par la future — l'hôte le capture s'il le veut.
@immutable
class ZDropReadFailure implements Exception {
  /// Construit un échec de lecture.
  const ZDropReadFailure(this.message);

  /// Description technique, non destinée à l'affichage direct (non localisée).
  final String message;

  @override
  String toString() => 'ZDropReadFailure: $message';
}
