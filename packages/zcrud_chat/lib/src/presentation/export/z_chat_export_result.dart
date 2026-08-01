/// Résultat d'un export — `ZChatExportResult` (CHAT-5).
///
/// origine: lex_data — `chat_export_service.dart` (`sealed class ExportResult`
/// + `TextExportResult` / `BinaryExportResult`). Porté à l'identique dans sa
/// forme : la distinction texte/binaire est réelle (on ne partage pas des
/// octets comme on partage une chaîne), et la porter dans le TYPE évite le
/// `String? text; Uint8List? bytes;` où l'un des deux est toujours `null`.
///
/// `sealed` est ici **correct** et ne heurte pas AD-4 : ce type ne franchit
/// aucune frontière de sérialisation et n'est pas un point d'extension
/// inter-package — un satellite n'a aucune raison d'inventer une troisième
/// nature de fichier. C'est le même arbitrage que `ZContentBlock` du kernel…
/// à l'inverse : celui-là est une famille OUVERTE parce qu'il est, lui,
/// sérialisé et extensible.
library;

import 'dart:typed_data';

import 'z_chat_export_format.dart';

/// Un document exporté, prêt à être partagé, imprimé ou écrit sur disque.
sealed class ZChatExportResult {
  /// Construit un résultat d'export.
  const ZChatExportResult({
    required this.format,
    required this.suggestedFileName,
  });

  /// Le format demandé.
  final ZChatExportFormat format;

  /// Nom de fichier suggéré (extension comprise).
  final String suggestedFileName;

  /// Type MIME — dérivé du [format], jamais saisi deux fois.
  String get mimeType => format.mimeType;
}

/// Un export **textuel** (Markdown, texte brut, HTML, références).
class ZChatTextExport extends ZChatExportResult {
  /// Construit un export textuel.
  const ZChatTextExport({
    required this.text,
    required super.format,
    required super.suggestedFileName,
  });

  /// Le contenu du document.
  final String text;

  @override
  String toString() =>
      'ZChatTextExport($format, $suggestedFileName, ${text.length} chars)';
}

/// Un export **binaire** (PDF).
class ZChatBinaryExport extends ZChatExportResult {
  /// Construit un export binaire.
  const ZChatBinaryExport({
    required this.bytes,
    required super.format,
    required super.suggestedFileName,
  });

  /// Les octets du document.
  final Uint8List bytes;

  @override
  String toString() =>
      'ZChatBinaryExport($format, $suggestedFileName, ${bytes.length} bytes)';
}
