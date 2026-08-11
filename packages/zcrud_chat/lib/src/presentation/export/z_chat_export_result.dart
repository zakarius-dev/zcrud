/// Résultat d'un export de conversation.
///
/// La distinction texte/binaire est réelle — on ne partage pas des octets
/// comme on partage une chaîne — et la porter dans le type plutôt que dans
/// deux champs nullables (`String? text; Uint8List? bytes;`) élimine l'état
/// où les deux seraient `null` ou renseignés à la fois.
///
/// `sealed` est ici approprié et ne contredit pas l'invariant AD-4 : ce type
/// ne franchit aucune frontière de sérialisation et n'est pas un point
/// d'extension inter-paquet — un satellite n'a aucune raison d'inventer une
/// troisième nature de fichier. C'est l'inverse de `ZContentBlock` (kernel),
/// qui reste une famille ouverte parce qu'il est, lui, sérialisé et
/// extensible.
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
