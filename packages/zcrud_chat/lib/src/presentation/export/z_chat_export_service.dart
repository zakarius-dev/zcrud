/// Export agrégé d'une conversation.
///
/// Conforme à l'invariant AD-5 : `Future<ZResult<ZChatExportResult>>`,
/// `try`/`catch` unique au sommet de chaque opération, aucun `throw` qui
/// s'échappe.
///
/// Trois choix structurants :
/// 1. PDF par couture — la mise en page passe par `ZChatPdfComposer` plutôt
///    que par un moteur de rendu de document intégré directement au
///    service : cf. `z_chat_export_ports.dart`.
/// 2. Libellés injectés — aucun mot n'est écrit en dur dans une langue
///    donnée. [ZChatExportVocabulary] les porte, et son défaut est un jeton
///    neutre (`user`, `assistant`) — une donnée, pas une traduction.
/// 3. Agrégation explicite — un export de conversation complète (tous les
///    messages, toutes les notes, tout le matériau transformé) est une
///    demande fréquente. [ZChatExportSelection] rend cet agrégat explicite
///    et testable, et son défaut est « toute la conversation ».
///
/// ## Invariant AD-10 — aucune exception ne s'échappe
///
/// Chaque opération publique est enveloppée : un bloc malformé, un `ZExtension`
/// corrompu ou une couture d'hôte qui lève produisent un
/// `Left(ZDomainFailure)`, jamais une exception qui remonterait dans le
/// gestionnaire de tap de l'hôte.
library;

import 'dart:typed_data';

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_export_format.dart';
import 'z_chat_export_ports.dart';
import 'z_chat_export_result.dart';

/// Ce qu'on agrège avant d'exporter.
///
/// L'export cible typiquement toute une conversation plutôt qu'un seul
/// message : c'est le défaut de [ZChatExportSelection.all].
class ZChatExportSelection {
  /// Construit une sélection.
  const ZChatExportSelection({this.blockFilter, this.roleFilter});

  /// Ne retient que les blocs pour lesquels ce prédicat rend `true`.
  /// `null` signifie tous les blocs (le défaut : l'agrégat complet).
  final bool Function(ZContentBlock block)? blockFilter;

  /// Ne retient que les messages de ces rôles. `null` signifie tous.
  final Set<ZChatRole>? roleFilter;

  /// L'agrégat complet — le défaut.
  static const ZChatExportSelection all = ZChatExportSelection();

  /// Les seules notes de l'assistant.
  static final ZChatExportSelection notes = ZChatExportSelection(
    roleFilter: const <ZChatRole>{ZChatRole.assistant},
    blockFilter: (ZContentBlock block) => block is ZTextBlock,
  );

  /// Les blocs personnalisés d'un [kind] donné, sans que le socle n'ait à
  /// connaître ce qu'ils représentent : `ZCustomContentBlock` est la famille
  /// ouverte prévue pour exactement cela (invariant AD-4).
  static ZChatExportSelection ofCustomKind(String kind) => ZChatExportSelection(
    blockFilter: (ZContentBlock block) =>
        block is ZCustomContentBlock && block.kind == kind,
  );

  /// `true` si [message] est retenu.
  bool keepsMessage(ZChatMessage message) =>
      roleFilter == null || roleFilter!.contains(message.role);

  /// `true` si [block] est retenu.
  bool keepsBlock(ZContentBlock block) =>
      blockFilter == null || blockFilter!(block);
}

/// Les mots que l'export écrit et que le socle ne doit pas décider.
///
/// Les défauts sont des jetons neutres (`user`, `assistant`, `sources`,
/// `references`, `exported`), pas des libellés dans une langue particulière.
/// Un hôte localisé les remplace ; un hôte qui ne le fait pas produit un
/// document en jetons — bruyant, donc corrigé. Un faux libellé dans la
/// mauvaise langue serait, lui, silencieux : c'est le même arbitrage que
/// `z_chat_labels.dart`.
class ZChatExportVocabulary {
  /// Construit un vocabulaire d'export.
  const ZChatExportVocabulary({
    this.user = 'user',
    this.assistant = 'assistant',
    this.system = 'system',
    this.sources = 'sources',
    this.references = 'references',
    this.exportedOn = 'exported',
  });

  /// Nom du rôle « utilisateur ».
  final String user;

  /// Nom du rôle « assistant ».
  final String assistant;

  /// Nom du rôle « système ».
  final String system;

  /// En-tête de la liste des sources d'un message.
  final String sources;

  /// En-tête de la section des références du document.
  final String references;

  /// Mention de la date d'export.
  final String exportedOn;

  /// Le nom du [role].
  String nameOf(ZChatRole role) => switch (role) {
    ZChatRole.user => user,
    ZChatRole.assistant => assistant,
    ZChatRole.system => system,
    ZChatRole.unknown => system,
  };
}

/// Produit un document exportable à partir d'une conversation.
///
/// Sans couture, les quatre formats textuels sont pleinement fonctionnels :
/// c'est le défaut zéro-dépendance de ce paquet. Le PDF exige
/// [ZChatPdfComposer], le partage exige [ZChatExportSink] — et leur absence
/// est un `Left` explicite.
class ZChatExportService {
  /// Construit le service.
  const ZChatExportService({
    this.pdfComposer,
    this.sink,
    this.vocabulary = const ZChatExportVocabulary(),
  });

  /// Couture de mise en page PDF, ou `null`.
  final ZChatPdfComposer? pdfComposer;

  /// Couture de destination système, ou `null`.
  final ZChatExportSink? sink;

  /// Les mots du document.
  final ZChatExportVocabulary vocabulary;

  /// Exporte l'**agrégat** de [messages] dans [format].
  ///
  /// [selection] par défaut : **toute** la conversation.
  Future<ZResult<ZChatExportResult>> exportConversation({
    required String title,
    required List<ZChatMessage> messages,
    required ZChatExportFormat format,
    ZChatExportSelection selection = ZChatExportSelection.all,
    DateTime? exportDate,
  }) async {
    try {
      final List<ZChatMessage> kept = _aggregate(messages, selection);
      final String fileName = suggestedFileName(title, format);
      final DateTime date = exportDate ?? DateTime.now();

      if (format == ZChatExportFormat.pdf) {
        final ZChatPdfComposer? composer = pdfComposer;
        if (composer == null) {
          return const Left<ZFailure, ZChatExportResult>(
            ZUnsupportedOperationFailure(
              'no ZChatPdfComposer wired',
              operation: 'exportConversation(pdf)',
            ),
          );
        }
        // Le socle produit le document NEUTRE (Markdown) ; la mise en page est
        // à la couture. Aucun moteur PDF n'entre ici.
        final ZChatTextExport source = ZChatTextExport(
          text: _renderMarkdown(title, kept, date),
          format: ZChatExportFormat.markdown,
          suggestedFileName: suggestedFileName(
            title,
            ZChatExportFormat.markdown,
          ),
        );
        final ZResult<Uint8List> bytes = await composer.compose(source);
        return bytes.fold(
          Left<ZFailure, ZChatExportResult>.new,
          (Uint8List b) => Right<ZFailure, ZChatExportResult>(
            ZChatBinaryExport(
              bytes: b,
              format: format,
              suggestedFileName: fileName,
            ),
          ),
        );
      }

      final String text = switch (format) {
        ZChatExportFormat.markdown => _renderMarkdown(title, kept, date),
        ZChatExportFormat.plainText => _renderPlainText(title, kept, date),
        ZChatExportFormat.html => _renderHtml(title, kept, date),
        ZChatExportFormat.references => _uniqueReferences(kept).join('\n'),
        // Traité plus haut ; la branche existe pour l'exhaustivité du `switch`.
        ZChatExportFormat.pdf => '',
      };
      return Right<ZFailure, ZChatExportResult>(
        ZChatTextExport(
          text: text,
          format: format,
          suggestedFileName: fileName,
        ),
      );
    } catch (error) {
      // Invariant AD-10 : un bloc malformé n'emporte jamais la conversation.
      return Left<ZFailure, ZChatExportResult>(ZDomainFailure('$error'));
    }
  }

  /// Exporte puis remet le document à la feuille de partage du système.
  ///
  /// Le partage lui-même n'est pas réimplémenté : il passe par
  /// [ZChatExportSink], dont l'implémentation d'hôte délègue à un service de
  /// partage déjà disponible dans l'écosystème zcrud.
  Future<ZResult<bool>> shareConversation({
    required String title,
    required List<ZChatMessage> messages,
    required ZChatExportFormat format,
    ZChatExportSelection selection = ZChatExportSelection.all,
    DateTime? exportDate,
    bool print = false,
  }) async {
    final ZChatExportSink? destination = sink;
    if (destination == null) {
      return const Left<ZFailure, bool>(
        ZUnsupportedOperationFailure(
          'no ZChatExportSink wired',
          operation: 'shareConversation',
        ),
      );
    }
    final ZResult<ZChatExportResult> document = await exportConversation(
      title: title,
      messages: messages,
      format: format,
      selection: selection,
      exportDate: exportDate,
    );
    return document.fold(Left<ZFailure, bool>.new, (
      ZChatExportResult result,
    ) async {
      try {
        return print
            ? await destination.printDocument(result)
            : await destination.share(result);
      } catch (error) {
        // Invariant AD-10 : une destination d'hôte qui lève ne remonte pas.
        return Left<ZFailure, bool>(ZDomainFailure('$error'));
      }
    });
  }

  /// Nom de fichier suggéré, normalisé en minuscules avec les caractères
  /// non-alphanumériques remplacés par `_`.
  String suggestedFileName(String title, ZChatExportFormat format) {
    final String slug = title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${slug.isEmpty ? 'conversation' : slug}.${format.fileExtension}';
  }

  // ---------------------------------------------------------------------------
  // Agrégation
  // ---------------------------------------------------------------------------

  List<ZChatMessage> _aggregate(
    List<ZChatMessage> messages,
    ZChatExportSelection selection,
  ) => <ZChatMessage>[
    for (final ZChatMessage m in messages)
      if (selection.keepsMessage(m))
        if (m.contentBlocks.any(selection.keepsBlock))
          m.copyWith(
            contentBlocks: <ZContentBlock>[
              for (final ZContentBlock b in m.contentBlocks)
                if (selection.keepsBlock(b)) b,
            ],
          ),
  ];

  // ---------------------------------------------------------------------------
  // Markdown — porté de `_formatConversationMarkdown` / `_renderBlockMarkdown`
  // ---------------------------------------------------------------------------

  String _renderMarkdown(
    String title,
    List<ZChatMessage> messages,
    DateTime date,
  ) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('# $title')
      ..writeln()
      ..writeln('*${vocabulary.exportedOn} ${_iso(date)}*')
      ..writeln()
      ..writeln('---')
      ..writeln();
    for (final ZChatMessage m in messages) {
      buffer
        ..writeln(_messageMarkdown(m))
        ..writeln();
    }
    final List<String> refs = _uniqueReferences(messages);
    if (refs.isNotEmpty) {
      buffer
        ..writeln('---')
        ..writeln()
        ..writeln('## ${vocabulary.references}')
        ..writeln();
      for (final String r in refs) {
        buffer.writeln('- $r');
      }
    }
    return buffer.toString().trimRight();
  }

  String _messageMarkdown(ZChatMessage message) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('**${vocabulary.nameOf(message.role)} :**')
      ..writeln();
    for (final ZContentBlock b in message.contentBlocks) {
      buffer
        ..writeln(_blockMarkdown(b))
        ..writeln();
    }
    final List<ZChatSource> sources =
        message.sources ?? const <ZChatSource>[];
    if (sources.isNotEmpty) {
      buffer.writeln('*${vocabulary.sources} :*');
      for (final ZChatSource s in sources) {
        buffer.writeln('- ${s.displayText}');
      }
    }
    return buffer.toString().trimRight();
  }

  String _blockMarkdown(ZContentBlock block) => switch (block) {
    ZTextBlock(:final String text) => text,
    ZTableBlock(
      :final String? title,
      :final List<String> headers,
      :final List<List<String>> rows,
    ) =>
      '${title != null ? '**$title**\n\n' : ''}'
          '| ${headers.join(' | ')} |\n'
          '| ${headers.map((String _) => '---').join(' | ')} |\n'
          '${rows.map((List<String> r) => '| ${r.join(' | ')} |').join('\n')}',
    ZKeyDefinitionBlock(:final String term, :final String definition) =>
      '**$term** : $definition',
    ZComparisonTableBlock(
      :final String? title,
      :final List<ZComparisonColumn> columns,
    ) =>
      '${title != null ? '**$title**\n\n' : ''}'
          '| ${columns.map((ZComparisonColumn c) => c.header).join(' | ')} |\n'
          '| ${columns.map((ZComparisonColumn _) => '---').join(' | ')} |\n'
          '${_comparisonRows(columns, (String header, String value) => value, '| ', ' |')}',
    ZTimelineBlock(
      :final String? title,
      :final List<ZTimelineEvent> events,
    ) =>
      '${title != null ? '**$title**\n\n' : ''}'
          '${events.map((ZTimelineEvent e) => '- **${e.date}** — ${e.title}'
              '${e.description != null ? ': ${e.description}' : ''}').join('\n')}',
    ZAlertBlock(
      :final String level,
      :final String? title,
      :final String message,
    ) =>
      '> [$level]${title != null ? ' **$title**' : ''}\n> $message',
    ZMermaidDiagramBlock(:final String? title, :final String code) =>
      '${title != null ? '**$title**\n\n' : ''}```mermaid\n$code\n```',
    ZSourcesBlock(:final List<ZChatSource> sources) =>
      sources.map((ZChatSource s) => '- ${s.displayText}').join('\n'),
    ZSuggestionsBlock(:final List<ZChatSuggestion> suggestions) =>
      suggestions.map((ZChatSuggestion s) => '- ${s.content}').join('\n'),
    // AD-4/AD-10 : un `kind` que le socle ne connaît pas n'est ni perdu ni
    // fatal — sa charge utile est préservée telle quelle.
    ZCustomContentBlock(:final String kind, :final Map<String, dynamic> payload) =>
      '```$kind\n$payload\n```',
  };

  // ---------------------------------------------------------------------------
  // Texte brut — porté de `_formatConversationWhatsApp` / `_markdownToWhatsApp`
  // ---------------------------------------------------------------------------

  String _renderPlainText(
    String title,
    List<ZChatMessage> messages,
    DateTime date,
  ) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('*$title*')
      ..writeln('${vocabulary.exportedOn} ${_iso(date)}')
      ..writeln();
    for (final ZChatMessage m in messages) {
      buffer
        ..writeln(_messagePlainText(m))
        ..writeln();
    }
    final List<String> refs = _uniqueReferences(messages);
    if (refs.isNotEmpty) {
      buffer.writeln('*${vocabulary.references} :*');
      for (final String r in refs) {
        buffer.writeln('- $r');
      }
    }
    return buffer.toString().trimRight();
  }

  String _messagePlainText(ZChatMessage message) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('*${vocabulary.nameOf(message.role)} :*');
    for (final ZContentBlock b in message.contentBlocks) {
      buffer.writeln(_markdownToPlainText(_blockMarkdown(b)));
    }
    return buffer.toString().trimRight();
  }

  /// Aplatit le Markdown en texte brut allégé : `**gras**` devient `*gras*`,
  /// code inline dénudé, en-têtes retirés, liens aplatis.
  String _markdownToPlainText(String md) {
    String result = md;
    result = result.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (Match m) => '*${m.group(1)}*',
    );
    result = result.replaceAllMapped(
      RegExp('`(.+?)`'),
      (Match m) => m.group(1)!,
    );
    result = result.replaceAll(RegExp(r'#{1,6}\s+'), '');
    result = result.replaceAllMapped(
      RegExp(r'\[(.+?)\]\((.+?)\)'),
      (Match m) => '${m.group(1)} (${m.group(2)})',
    );
    return result;
  }

  // ---------------------------------------------------------------------------
  // HTML — porté de `_formatConversationHtml` / `_escapeHtml`
  // ---------------------------------------------------------------------------

  String _renderHtml(String title, List<ZChatMessage> messages, DateTime date) {
    final StringBuffer buffer = StringBuffer()
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html><head><meta charset="utf-8">')
      ..writeln('<title>${_escapeHtml(title)}</title>')
      ..writeln('</head><body>')
      ..writeln('<h1>${_escapeHtml(title)}</h1>')
      ..writeln(
        '<p><em>${_escapeHtml(vocabulary.exportedOn)} '
        '${_escapeHtml(_iso(date))}</em></p>',
      );
    for (final ZChatMessage m in messages) {
      buffer
        ..writeln(
          '<h2>${_escapeHtml(vocabulary.nameOf(m.role))}</h2>',
        )
        ..writeln(
          '<pre>${_escapeHtml(<String>[
            for (final ZContentBlock b in m.contentBlocks) _blockMarkdown(b),
          ].join('\n\n'))}</pre>',
        );
    }
    final List<String> refs = _uniqueReferences(messages);
    if (refs.isNotEmpty) {
      buffer.writeln('<h2>${_escapeHtml(vocabulary.references)}</h2><ul>');
      for (final String r in refs) {
        buffer.writeln('<li>${_escapeHtml(r)}</li>');
      }
      buffer.writeln('</ul>');
    }
    buffer.writeln('</body></html>');
    return buffer.toString().trimRight();
  }

  /// L'ordre compte : `&` d'abord, sans quoi les entités produites par les
  /// remplacements suivants seraient ré-échappées (`&lt;` deviendrait
  /// `&amp;lt;`).
  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  // ---------------------------------------------------------------------------
  // Références
  // ---------------------------------------------------------------------------

  /// Références dédupliquées en préservant l'ordre de première apparition.
  List<String> _uniqueReferences(List<ZChatMessage> messages) {
    final Set<String> seen = <String>{};
    final List<String> out = <String>[];
    void add(Iterable<ZChatSource> sources) {
      for (final ZChatSource s in sources) {
        final String ref = s.displayText;
        if (ref.isEmpty || !seen.add(ref)) continue;
        out.add(ref);
      }
    }

    for (final ZChatMessage m in messages) {
      add(m.sources ?? const <ZChatSource>[]);
      for (final ZContentBlock b in m.contentBlocks) {
        if (b is ZSourcesBlock) add(b.sources);
      }
    }
    return out;
  }

  /// Date en ISO-8601 (convention de nommage du dépôt).
  ///
  /// Un format localisé (jour/mois/année ou l'inverse) est un choix de
  /// locale que le socle n'a pas à faire, et formater une date exige
  /// généralement une dépendance tierce que ce paquet n'importe pas.
  String _iso(DateTime date) => date.toIso8601String();

  /// Assemble les lignes d'un tableau comparatif, colonnes de longueurs
  /// inégales comprises.
  String _comparisonRows(
    List<ZComparisonColumn> columns,
    String Function(String header, String value) cell,
    String prefix,
    String suffix,
  ) {
    if (columns.isEmpty) return '';
    final int rowCount = columns
        .map((ZComparisonColumn c) => c.values.length)
        .reduce((int a, int b) => a > b ? a : b);
    final List<String> lines = <String>[];
    for (int i = 0; i < rowCount; i++) {
      final String cells = columns
          .map(
            (ZComparisonColumn c) => cell(
              c.header,
              i < c.values.length ? c.values[i] : '',
            ),
          )
          .join(' | ');
      lines.add('$prefix$cells$suffix');
    }
    return lines.join('\n');
  }
}
