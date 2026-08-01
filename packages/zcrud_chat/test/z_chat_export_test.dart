/// Comportement de l'**export agrégé** — CHAT-5.
///
/// Ce que ces gardes prouvent : les quatre formats textuels sont produits SANS
/// aucune couture (défaut zéro-dépendance d'AD-57), l'agrégat porte sur TOUTE
/// la conversation (la cible d'IFFD), le PDF et le partage passent par les
/// coutures — et AD-10 tient : aucune exception ne s'échappe, y compris quand
/// c'est l'implémentation de l'HÔTE qui lève.
@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

ZChatMessage _msg(
  ZChatRole role,
  List<ZContentBlock> blocks, {
  String id = 'm',
  List<ZChatSource>? sources,
}) => ZChatMessage(
  id: id,
  conversationId: 'c1',
  role: role,
  contentBlocks: blocks,
  sources: sources,
);

ZChatSource _src(String text) =>
    ZChatSource(sourceType: 'doc', displayText: text);

/// Une conversation de trois tours : deux notes d'assistant, une question, et
/// deux blocs `flashcards` — l'agrégat exact que le menu d'IFFD attend.
List<ZChatMessage> _conversation() => <ZChatMessage>[
  _msg(
    ZChatRole.user,
    <ZContentBlock>[const ZTextBlock(text: 'question un')],
    id: 'm1',
  ),
  _msg(
    ZChatRole.assistant,
    <ZContentBlock>[
      const ZTextBlock(text: 'note un'),
      ZCustomContentBlock('flashcards', <String, dynamic>{'q': 'Q1'}),
    ],
    id: 'm2',
    sources: <ZChatSource>[_src('Source A')],
  ),
  _msg(
    ZChatRole.assistant,
    <ZContentBlock>[
      const ZTextBlock(text: 'note deux'),
      ZCustomContentBlock('flashcards', <String, dynamic>{'q': 'Q2'}),
    ],
    id: 'm3',
    sources: <ZChatSource>[_src('Source A'), _src('Source B')],
  ),
];

/// Compositeur PDF scriptable — il peut réussir, échouer, ou LEVER.
class _ScriptedComposer extends ZChatPdfComposer {
  _ScriptedComposer({this.result, this.throws = false});

  final ZResult<Uint8List>? result;
  final bool throws;
  final List<ZChatTextExport> seen = <ZChatTextExport>[];

  @override
  Future<ZResult<Uint8List>> compose(ZChatTextExport document) async {
    seen.add(document);
    if (throws) throw StateError('composer exploded');
    return result ??
        Right<ZFailure, Uint8List>(
          Uint8List.fromList(document.text.codeUnits),
        );
  }
}

/// Destination scriptable — le stand-in du `ZPdfShareService` d'un hôte réel.
class _ScriptedSink extends ZChatExportSink {
  _ScriptedSink({this.throws = false});

  final bool throws;
  final List<ZChatExportResult> shared = <ZChatExportResult>[];
  final List<ZChatExportResult> printed = <ZChatExportResult>[];

  @override
  Future<ZResult<bool>> share(ZChatExportResult result) async {
    if (throws) throw StateError('sink exploded');
    shared.add(result);
    return const Right<ZFailure, bool>(true);
  }

  @override
  Future<ZResult<bool>> printDocument(ZChatExportResult result) async {
    if (throws) throw StateError('sink exploded');
    printed.add(result);
    return const Right<ZFailure, bool>(true);
  }
}

String _textOf(ZResult<ZChatExportResult> r) =>
    (r.getOrElse(() => throw StateError('attendu Right')) as ZChatTextExport)
        .text;

void main() {
  const ZChatExportService bare = ZChatExportService();
  final DateTime when = DateTime.utc(2026, 8, 1, 10, 30);

  group('🔴 C5-E1 — les quatre formats TEXTUELS marchent SANS aucune couture',
      () {
    for (final ZChatExportFormat format in <ZChatExportFormat>[
      ZChatExportFormat.markdown,
      ZChatExportFormat.plainText,
      ZChatExportFormat.html,
      ZChatExportFormat.references,
    ]) {
      test('$format est produit par un service NU', () async {
        final ZResult<ZChatExportResult> r = await bare.exportConversation(
          title: 'Ma conversation',
          messages: _conversation(),
          format: format,
          exportDate: when,
        );
        expect(r.isRight(), isTrue,
            reason: '🔴 AD-57 exige un DÉFAUT FONCTIONNEL à zéro dépendance : '
                'un hôte qui ne câble rien doit pouvoir exporter du texte');
        final ZChatExportResult doc =
            r.getOrElse(() => throw StateError('x'));
        expect(doc, isA<ZChatTextExport>());
        expect(doc.mimeType, format.mimeType);
        expect(doc.suggestedFileName, endsWith('.${format.fileExtension}'));
      });
    }

    test('Markdown : titre, notes, sources et références dédupliquées',
        () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 'Ma conversation',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      expect(md, startsWith('# Ma conversation'));
      expect(md, contains('note un'));
      expect(md, contains('note deux'));
      expect(md, contains('question un'),
          reason: '🔴 l\'agrégat par DÉFAUT est TOUTE la conversation, y '
              'compris les tours de l\'utilisateur');
      // 🔴 « Source A » est citée par DEUX messages : elle ne doit apparaître
      // qu'une fois dans la section des références.
      final int refA = 'references'.allMatches(md).length;
      expect(refA, 1);
      final String tail = md.split('## references').last;
      expect('- Source A'.allMatches(tail).length, 1,
          reason: '🔴 la dédup de `_collectUniqueApaReferences` est perdue');
      expect(tail, contains('- Source B'));
    });

    test('l\'ordre de PREMIÈRE apparition des références est préservé',
        () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.references,
          exportDate: when,
        ),
      );
      expect(md.split('\n'), <String>['Source A', 'Source B']);
    });

    test('texte brut : `**gras**` devient `*gras*`, les en-têtes disparaissent',
        () async {
      final String txt = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: <ZChatMessage>[
            _msg(ZChatRole.assistant, <ZContentBlock>[
              const ZTextBlock(text: '# Titre\n**gras** et `code` et [l](u)'),
            ]),
          ],
          format: ZChatExportFormat.plainText,
          exportDate: when,
        ),
      );
      expect(txt, contains('*gras*'));
      expect(txt, isNot(contains('**gras**')));
      expect(txt, isNot(contains('# Titre')));
      expect(txt, contains('Titre'));
      expect(txt, isNot(contains('`code`')),
          reason: '🔴 le code inline doit être DÉNUDÉ');
      expect(txt, contains('l (u)'), reason: '🔴 le lien doit être APLATI');
    });

    test('HTML : `&` est échappé EN PREMIER (sinon double échappement)',
        () async {
      final String html = _textOf(
        await bare.exportConversation(
          title: 'A & B',
          messages: <ZChatMessage>[
            _msg(ZChatRole.assistant, <ZContentBlock>[
              const ZTextBlock(text: '<script>alert("x")</script>'),
            ]),
          ],
          format: ZChatExportFormat.html,
          exportDate: when,
        ),
      );
      expect(html, contains('A &amp; B'));
      expect(html, isNot(contains('&amp;lt;')),
          reason: '🔴 double échappement : `&` doit passer AVANT `<`');
      expect(html, isNot(contains('<script>')),
          reason: '🔴 injection HTML — le contenu du modèle n\'est pas du '
              'balisage de confiance');
      expect(html, contains('&lt;script&gt;'));
    });

    test('les DIX variantes de bloc du kernel sont rendues, aucune ignorée',
        () async {
      // 🔴 Le `switch` est exhaustif à la compilation, mais rien ne prouverait
      // qu'une branche ne rend pas la chaîne vide.
      final List<ZContentBlock> all = <ZContentBlock>[
        const ZTextBlock(text: 'texte'),
        const ZTableBlock(
          title: 'tab',
          headers: <String>['h1', 'h2'],
          rows: <List<String>>[
            <String>['a', 'b'],
          ],
        ),
        const ZKeyDefinitionBlock(term: 'terme', definition: 'def'),
        const ZComparisonTableBlock(
          title: 'cmp',
          columns: <ZComparisonColumn>[
            ZComparisonColumn(header: 'c1', values: <String>['v1', 'v2']),
            ZComparisonColumn(header: 'c2', values: <String>['w1']),
          ],
        ),
        const ZTimelineBlock(
          title: 'tl',
          events: <ZTimelineEvent>[
            ZTimelineEvent(date: '2026', title: 'evt', description: 'desc'),
          ],
        ),
        const ZAlertBlock(level: 'warning', title: 'att', message: 'msg'),
        const ZMermaidDiagramBlock(title: 'dia', code: 'graph TD;'),
        ZSourcesBlock(sources: <ZChatSource>[_src('SrcBlock')]),
        const ZSuggestionsBlock(
          suggestions: <ZChatSuggestion>[
            ZChatSuggestion(id: 's', type: 't', content: 'relance'),
          ],
        ),
        ZCustomContentBlock('flashcards', <String, dynamic>{'q': 'inconnu'}),
      ];
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: <ZChatMessage>[_msg(ZChatRole.assistant, all)],
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      for (final String expected in <String>[
        'texte',
        'h1',
        'terme',
        'c1',
        'evt',
        'msg',
        'graph TD;',
        'SrcBlock',
        'relance',
        // AD-4/AD-10 : un `kind` inconnu du socle n'est NI perdu NI fatal.
        'flashcards',
        'inconnu',
      ]) {
        expect(md, contains(expected),
            reason: '🔴 un bloc rendu VIDE : sa donnée est PERDUE à l\'export');
      }
    });

    test('colonnes de longueurs inégales : aucune ligne perdue, aucun crash',
        () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: <ZChatMessage>[
            _msg(ZChatRole.assistant, <ZContentBlock>[
              const ZComparisonTableBlock(
                columns: <ZComparisonColumn>[
                  ZComparisonColumn(header: 'a', values: <String>['1', '2']),
                  ZComparisonColumn(header: 'b', values: <String>['x']),
                ],
              ),
            ]),
          ],
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      expect(md, contains('| 1 | x |'));
      expect(md, contains('| 2 |  |'),
          reason: '🔴 la colonne courte doit être COMBLÉE, pas tronquer la '
              'ligne (le `reduce(max)` de lex)');
    });
  });

  group('🔴 C5-E2 — l\'AGRÉGAT est celui d\'IFFD : toute la conversation', () {
    test('le défaut ne filtre RIEN', () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      for (final String expected in <String>[
        'question un',
        'note un',
        'note deux',
        'flashcards',
      ]) {
        expect(md, contains(expected));
      }
    });

    test('`notes` = les seules notes de l\'assistant (`allExplanations`)',
        () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          selection: ZChatExportSelection.notes,
          exportDate: when,
        ),
      );
      expect(md, contains('note un'));
      expect(md, contains('note deux'));
      expect(md, isNot(contains('question un')),
          reason: '🔴 le rôle `user` doit être écarté');
      expect(md, isNot(contains('flashcards')),
          reason: '🔴 seuls les blocs de TEXTE sont des notes');
    });

    test('`ofCustomKind` = les flashcards de TOUS les messages '
        '(`allFlashcards`)', () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          selection: ZChatExportSelection.ofCustomKind('flashcards'),
          exportDate: when,
        ),
      );
      expect(md, contains('Q1'));
      expect(md, contains('Q2'),
          reason: '🔴 l\'agrégat porte sur TOUTE la conversation : IFFD boucle '
              'sur `messagesData` entier (`:2434-2442`)');
      expect(md, isNot(contains('note un')));
    });

    test('un message dont AUCUN bloc n\'est retenu disparaît (pas d\'en-tête '
        'orphelin)', () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          selection: ZChatExportSelection.ofCustomKind('flashcards'),
          exportDate: when,
        ),
      );
      // Le message `m1` (user, texte seul) ne porte aucune flashcard.
      expect('**user :**'.allMatches(md).length, 0,
          reason: '🔴 un message vidé de ses blocs laisserait un en-tête de '
              'rôle suivi de RIEN');
    });

    test('une sélection vide produit un document valide, jamais une erreur',
        () async {
      final ZResult<ZChatExportResult> r = await bare.exportConversation(
        title: 't',
        messages: _conversation(),
        format: ZChatExportFormat.markdown,
        selection: ZChatExportSelection.ofCustomKind('inexistant'),
        exportDate: when,
      );
      expect(r.isRight(), isTrue);
      expect(_textOf(r), contains('# t'));
    });
  });

  group('🔴 C5-E3 — les MOTS sont injectés, jamais figés (FR-26)', () {
    test('le défaut est un JETON neutre, pas un libellé français', () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      expect(md, contains('**assistant :**'));
      expect(md, isNot(contains('Lexia')),
          reason: '🔴 « Lexia » est le nom d\'un PRODUIT : il n\'a rien à '
              'faire dans un socle multi-consommateurs');
      expect(md, isNot(contains('Utilisateur')));
    });

    test('un hôte localisé remplace TOUS les mots', () async {
      const ZChatExportService fr = ZChatExportService(
        vocabulary: ZChatExportVocabulary(
          user: 'Utilisateur',
          assistant: 'Assistant',
          references: 'Références',
          sources: 'Sources',
          exportedOn: 'Exporté le',
        ),
      );
      final String md = _textOf(
        await fr.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      for (final String expected in <String>[
        '**Utilisateur :**',
        '**Assistant :**',
        '## Références',
        '*Sources :*',
        'Exporté le',
      ]) {
        expect(md, contains(expected),
            reason: '🔴 un mot resté en dur : $expected introuvable');
      }
    });

    test('la date est ISO-8601 — aucune locale décidée par le socle', () async {
      final String md = _textOf(
        await bare.exportConversation(
          title: 't',
          messages: _conversation(),
          format: ZChatExportFormat.markdown,
          exportDate: when,
        ),
      );
      expect(md, contains(when.toIso8601String()));
      expect(md, isNot(contains('01/08/2026')),
          reason: '🔴 jj/mm/aaaa est un choix de LOCALE, et `intl` une '
              'dépendance tierce (AD-57)');
    });
  });

  group('🔴 C5-E4 — PDF et PARTAGE passent par les COUTURES', () {
    test('aucun compositeur ⇒ `Left` explicite, jamais un PDF vide', () async {
      final ZResult<ZChatExportResult> r = await bare.exportConversation(
        title: 't',
        messages: _conversation(),
        format: ZChatExportFormat.pdf,
      );
      expect(r.isLeft(), isTrue);
      expect(
        r.swap().getOrElse(() => throw StateError('x')),
        isA<ZUnsupportedOperationFailure>(),
        reason: '🔴 « je ne sais pas faire » n\'est pas « ça a planté »',
      );
    });

    test('le compositeur reçoit le document NEUTRE et rend les octets',
        () async {
      final _ScriptedComposer composer = _ScriptedComposer();
      final ZChatExportService svc = ZChatExportService(pdfComposer: composer);
      final ZResult<ZChatExportResult> r = await svc.exportConversation(
        title: 'Ma conversation',
        messages: _conversation(),
        format: ZChatExportFormat.pdf,
        exportDate: when,
      );
      final ZChatExportResult doc = r.getOrElse(() => throw StateError('x'));
      expect(doc, isA<ZChatBinaryExport>());
      expect(doc.suggestedFileName, 'ma_conversation.pdf');
      expect(doc.mimeType, 'application/pdf');
      expect(composer.seen, hasLength(1));
      expect(composer.seen.single.format, ZChatExportFormat.markdown,
          reason: '🔴 le socle passe du MARKDOWN à la couture : il ne met rien '
              'en page, donc n\'a besoin d\'aucun moteur PDF');
      expect(composer.seen.single.text, contains('note un'));
    });

    test('un compositeur d\'HÔTE qui LÈVE produit un `Left` (AD-10)', () async {
      final ZChatExportService svc = ZChatExportService(
        pdfComposer: _ScriptedComposer(throws: true),
      );
      final ZResult<ZChatExportResult> r = await svc.exportConversation(
        title: 't',
        messages: _conversation(),
        format: ZChatExportFormat.pdf,
      );
      expect(r.isLeft(), isTrue);
      expect(r.swap().getOrElse(() => throw StateError('x')).message,
          contains('composer exploded'));
    });

    test('l\'échec du compositeur est RELAYÉ tel quel', () async {
      final ZChatExportService svc = ZChatExportService(
        pdfComposer: _ScriptedComposer(
          result: const Left<ZFailure, Uint8List>(ZServerFailure('boom')),
        ),
      );
      final ZResult<ZChatExportResult> r = await svc.exportConversation(
        title: 't',
        messages: _conversation(),
        format: ZChatExportFormat.pdf,
      );
      expect(r.swap().getOrElse(() => throw StateError('x')),
          const ZServerFailure('boom'));
    });

    test('le partage délègue à la DESTINATION, il n\'en réimplémente aucune',
        () async {
      final _ScriptedSink sink = _ScriptedSink();
      final ZChatExportService svc = ZChatExportService(
        sink: sink,
        pdfComposer: _ScriptedComposer(),
      );
      final ZResult<bool> shared = await svc.shareConversation(
        title: 'Ma conversation',
        messages: _conversation(),
        format: ZChatExportFormat.pdf,
        exportDate: when,
      );
      expect(shared, const Right<ZFailure, bool>(true));
      expect(sink.shared, hasLength(1));
      expect(sink.shared.single.suggestedFileName, 'ma_conversation.pdf');
      expect(sink.printed, isEmpty);

      await svc.shareConversation(
        title: 'Ma conversation',
        messages: _conversation(),
        format: ZChatExportFormat.pdf,
        exportDate: when,
        print: true,
      );
      expect(sink.printed, hasLength(1),
          reason: '🔴 impression et partage sont DEUX gestes distincts — '
              '`ZPdfShareService` en porte deux, et les confondre en '
              'perdrait un');
    });

    test('aucune destination ⇒ `Left`, et RIEN n\'est exporté pour rien',
        () async {
      final ZResult<bool> r = await bare.shareConversation(
        title: 't',
        messages: _conversation(),
        format: ZChatExportFormat.markdown,
      );
      expect(r.isLeft(), isTrue);
      expect(r.swap().getOrElse(() => throw StateError('x')),
          isA<ZUnsupportedOperationFailure>());
    });

    test('une destination d\'HÔTE qui LÈVE produit un `Left` (AD-10)',
        () async {
      final ZChatExportService svc = ZChatExportService(
        sink: _ScriptedSink(throws: true),
      );
      final ZResult<bool> r = await svc.shareConversation(
        title: 't',
        messages: _conversation(),
        format: ZChatExportFormat.markdown,
      );
      expect(r.isLeft(), isTrue);
      expect(r.swap().getOrElse(() => throw StateError('x')).message,
          contains('sink exploded'));
    });

    test('un export raté n\'est JAMAIS partagé', () async {
      final _ScriptedSink sink = _ScriptedSink();
      final ZChatExportService svc = ZChatExportService(sink: sink);
      final ZResult<bool> r = await svc.shareConversation(
        title: 't',
        messages: _conversation(),
        // Aucun compositeur câblé ⇒ l'export échoue.
        format: ZChatExportFormat.pdf,
      );
      expect(r.isLeft(), isTrue);
      expect(sink.shared, isEmpty,
          reason: '🔴 partager un document qui n\'existe pas ouvrirait une '
              'feuille système vide');
    });
  });

  group('🔴 C5-E5 — nom de fichier : la normalisation de lex', () {
    test('minuscules, non-alphanumériques en `_`, pas de `_` aux extrémités',
        () {
      expect(
        bare.suggestedFileName('Ma  Conversation !', ZChatExportFormat.markdown),
        'ma_conversation.md',
      );
      // ⚠️ COMPORTEMENT DE LEX, conservé et assumé : le slug est ASCII-only,
      // donc « Étude » perd son « É ». C'est lossy, et c'est le prix d'un nom
      // de fichier sûr sur toutes les plateformes et dans une URL. La garde le
      // FIGE pour qu'un changement soit un choix, pas une dérive.
      expect(
        bare.suggestedFileName('Étude № 4', ZChatExportFormat.html),
        'tude_4.html',
      );
      expect(
        bare.suggestedFileName('!!!', ZChatExportFormat.markdown),
        'conversation.md',
        reason: '🔴 un titre entièrement non-alphanumérique ne doit pas '
            'produire un `_` isolé en guise de nom',
      );
      expect(
        bare.suggestedFileName('', ZChatExportFormat.pdf),
        'conversation.pdf',
        reason: '🔴 REPLI : un titre vide donnerait `.pdf`, un fichier caché '
            'sans nom sur les systèmes POSIX',
      );
    });
  });
}
