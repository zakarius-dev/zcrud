/// Formats d'export d'une conversation.
///
/// [ZChatExportFormat.plainText] désigne délibérément un format générique :
/// du texte brut avec des `*gras*` et sans en-têtes Markdown, sans référence
/// à une application tierce particulière — un socle multi-consommateurs ne
/// fige pas le nom d'un produit dans son API publique.
library;

/// Le format demandé pour un export.
enum ZChatExportFormat {
  /// Markdown structuré (titres, tableaux, citations).
  markdown,

  /// Texte brut allégé — `*gras*`, aucun en-tête, aucun lien Markdown.
  plainText,

  /// Document HTML autonome.
  html,

  /// La seule liste des **références** citées, dédupliquée.
  references,

  /// PDF — **binaire**, produit par la couture `ZChatPdfComposer` (ce package
  /// ne met rien en page : cf. `z_chat_export_ports.dart`).
  pdf;

  /// Type MIME du document produit.
  String get mimeType => switch (this) {
    ZChatExportFormat.markdown => 'text/markdown',
    ZChatExportFormat.plainText => 'text/plain',
    ZChatExportFormat.html => 'text/html',
    ZChatExportFormat.references => 'text/plain',
    ZChatExportFormat.pdf => 'application/pdf',
  };

  /// Extension de fichier suggérée (sans le point).
  String get fileExtension => switch (this) {
    ZChatExportFormat.markdown => 'md',
    ZChatExportFormat.plainText => 'txt',
    ZChatExportFormat.html => 'html',
    ZChatExportFormat.references => 'txt',
    ZChatExportFormat.pdf => 'pdf',
  };

  /// `true` si le format produit des **octets** plutôt que du texte.
  bool get isBinary => this == ZChatExportFormat.pdf;
}
