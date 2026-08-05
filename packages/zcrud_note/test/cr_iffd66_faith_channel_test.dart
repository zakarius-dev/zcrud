// CR-IFFD-66 — le canal de FOI du corps de note.
//
// 🔴 CE QUE CES TESTS PROUVENT (et pourquoi ils ne sont pas tautologiques)
//
// Un hôte migré par strangler fig double son corps de note : le champ TYPÉ
// `ZSmartNote.content` (ops) ET une clé d'`extra` qui FAIT FOI à la relecture.
// `ZSmartNoteEditor` ne remontait que `copyWith(content: ops)` ⇒ `extra` restait
// figé ⇒ la note se rouvrait dans son état d'AVANT l'édition, SANS ERREUR.
//
// La perte a été MESURÉE avant correction (le groupe « CR-IFFD-66 · perte »
// rougissait sur `expect(relu, contains('MODIF'))`, assertion, pas compilation).
// Le mapper hôte est répliqué ci-dessous VERBATIM d'après le contrat publié par
// l'hôte (`toCanonical`/`fromCanonical`, `extra['<foi>']` fait foi) : c'est ce
// qui rend la garde MORDANTE — elle mesure la relecture de l'HÔTE, pas une
// propriété interne du socle.
//
// ⚠️ AD-10 — le groupe « producteur zcrud PUR » verrouille le cas SANS canal de
// foi : c'est lui qui rendait le défaut invisible, et il doit rester
// STRICTEMENT inchangé.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_note/zcrud_note.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Réplique du contrat HÔTE (lecture seule chez lui) — volet `content` seul.
// ═══════════════════════════════════════════════════════════════════════════

/// Clé de foi de l'hôte (nommée ici comme chez lui : préfixée, non réservée).
const String kHostFaithKey = 'iffd_content';

/// `SmartNoteModel(content: String?)` → map canonique zcrud (aller).
Map<String, dynamic> hostToCanonical(String? hostContent) => ZSmartNote(
      id: 'n1',
      folderId: 'f1',
      title: 'Titre',
      content: normalizeNoteContentOps(hostContent),
      extra: <String, dynamic>{
        // Forme conservée VERBATIM d'après le mapper de l'hôte : la garde perd
        // sa valeur de preuve si on la « modernise » (elle doit refléter le
        // contrat réellement publié, pas notre style).
        // ignore: use_null_aware_elements
        if (hostContent != null) kHostFaithKey: hostContent,
      },
    ).toMap();

/// Reconstruction best-effort de l'hôte quand il n'a PAS de canal de foi.
String? hostOpsToStringOrNull(List<Map<String, dynamic>> ops) {
  final b = StringBuffer();
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is String) b.write(insert);
  }
  final t = b.toString();
  return t.isEmpty ? null : t;
}

/// Map canonique zcrud → `content` de l'hôte (retour). **`extra` fait FOI.**
String? hostFromCanonical(Map<String, dynamic> map) {
  final note = ZSmartNote.fromMap(map);
  final extra = note.extra;
  return extra.containsKey(kHostFaithKey)
      ? extra[kHostFaithKey] as String?
      : hostOpsToStringOrNull(note.content);
}

/// Le canal de foi tel qu'un hôte le déclarerait (encodeur du socle, réutilisé).
ZNoteContentFaithChannel hostChannel() => ZNoteContentFaithChannel(
      extraKey: kHostFaithKey,
      encode: (ops) => const ZMarkdownCodec().encode(ops),
    );

// ═══════════════════════════════════════════════════════════════════════════
// Harnais widget
// ═══════════════════════════════════════════════════════════════════════════

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

QuillController _quillOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

FocusNode _focusOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).focusNode;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

/// Tape [text] à la fin du document et laisse le curseur derrière.
Future<void> _typeAtEnd(WidgetTester tester, String text) async {
  final quill = _quillOf(tester);
  _focusOf(tester).requestFocus();
  await tester.pump();
  final at = quill.document.length - 1;
  quill.replaceText(
    at,
    0,
    text,
    TextSelection.collapsed(offset: at + text.length),
  );
  await tester.pump();
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // 🔴 LA GARDE PORTEUSE — elle rougissait AVANT la correction (assertion).
  // ═════════════════════════════════════════════════════════════════════════
  group('CR-IFFD-66 · perte — l\'édition SURVIT au rechargement chez un hôte '
      'dont `extra` fait FOI', () {
    testWidgets(
        'avec un canal de foi déclaré, la relecture HÔTE porte la modification',
        (tester) async {
      const original = '# Titre markdown legacy';
      final note = ZSmartNote.fromMap(hostToCanonical(original));

      // Au repos, l'hôte relit son original à l'identique.
      expect(hostFromCanonical(note.toMap()), original);

      ZSmartNote? captured;
      await tester.pumpWidget(_host(ZSmartNoteEditor(
        note: note,
        onChanged: (n) => captured = n,
        faithChannel: hostChannel(),
      )));

      await _typeAtEnd(tester, ' MODIF');

      expect(captured, isNotNull);

      // 🔴 LOAD-BEARING : c'est la RELECTURE DE L'HÔTE (canal de foi) qui est
      // mesurée, pas le champ typé. Sans la re-synchronisation du canal, elle
      // rend l'état d'AVANT l'édition ⇒ ROUGE.
      final relu = hostFromCanonical(captured!.toMap());
      expect(
        relu,
        contains('MODIF'),
        reason: 'CR-IFFD-66 : la modification a été écrite dans le champ TYPÉ '
            'mais pas dans le canal de FOI ⇒ la note se rouvre dans son état '
            'd\'avant l\'édition, silencieusement.',
      );
      expect(relu, contains('Titre markdown legacy'));

      await _settle(tester);
    });

    testWidgets('les DEUX canaux restent cohérents (aucun instant de divergence)',
        (tester) async {
      final note = ZSmartNote.fromMap(hostToCanonical('corps'));
      final vus = <ZSmartNote>[];

      await tester.pumpWidget(_host(ZSmartNoteEditor(
        note: note,
        onChanged: vus.add,
        faithChannel: hostChannel(),
      )));

      final quill = _quillOf(tester);
      _focusOf(tester).requestFocus();
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        final at = quill.document.length - 1;
        quill.replaceText(at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await tester.pump();
      }

      expect(vus, hasLength(5));
      // CHAQUE remontée porte les deux canaux d'accord entre eux.
      for (final n in vus) {
        expect(
          n.extra[kHostFaithKey],
          const ZMarkdownCodec().encode(n.content),
          reason: 'une remontée où le canal de foi ne dérive PAS des ops de la '
              'MÊME note est un instant de divergence.',
        );
      }

      await _settle(tester);
    });

    testWidgets('un corps VIDÉ retire la clé de foi (au lieu de laisser '
        'l\'ancienne valeur, qui ressusciterait le corps)', (tester) async {
      final note = ZSmartNote.fromMap(hostToCanonical('a supprimer'));
      ZSmartNote? captured;

      await tester.pumpWidget(_host(ZSmartNoteEditor(
        note: note,
        onChanged: (n) => captured = n,
        faithChannel: ZNoteContentFaithChannel(
          extraKey: kHostFaithKey,
          // Encodeur qui rend `null` sur un corps vide (contrat documenté).
          encode: (ops) {
            final s = const ZMarkdownCodec().encode(ops) as String?;
            return (s == null || s.trim().isEmpty) ? null : s;
          },
        ),
      )));

      final quill = _quillOf(tester);
      _focusOf(tester).requestFocus();
      await tester.pump();
      quill.replaceText(
        0,
        quill.document.length - 1,
        '',
        const TextSelection.collapsed(offset: 0),
      );
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.extra.containsKey(kHostFaithKey), isFalse);
      // ⇒ l'hôte retombe sur sa reconstruction depuis les ops. Elle rend le
      // `'\n'` terminal que Quill garde toujours — donc un corps BLANC, jamais
      // le corps supprimé. C'est le point : l'ancienne valeur ne RESSUSCITE pas.
      expect((hostFromCanonical(captured!.toMap()) ?? '').trim(), isEmpty);
      expect(hostFromCanonical(captured!.toMap()), isNot(contains('supprimer')));

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // AD-10 — le cas qui rendait le défaut INVISIBLE doit rester INCHANGÉ.
  // ═════════════════════════════════════════════════════════════════════════
  group('AD-10 — producteur zcrud PUR (aucun canal de foi) : comportement '
      'STRICTEMENT inchangé', () {
    testWidgets('sans `faithChannel`, `extra` est préservé VERBATIM et AUCUNE '
        'clé n\'est ajoutée', (tester) async {
      final note = ZSmartNote(
        id: 'n1',
        title: 'Titre',
        folderId: 'f1',
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'A\n'},
        ],
        extra: const <String, dynamic>{
          'legacy_meta': 'v',
          kHostFaithKey: 'NE DOIT PAS BOUGER',
        },
      );
      ZSmartNote? captured;

      await tester.pumpWidget(
        _host(ZSmartNoteEditor(note: note, onChanged: (n) => captured = n)),
      );
      await _typeAtEnd(tester, 'B');

      expect(captured, isNotNull);
      // 🔴 LOAD-BEARING : aucun canal déclaré ⇒ le socle ne touche à RIEN dans
      // `extra`, même à une clé qui RESSEMBLE à un canal de foi. Deviner serait
      // écrire chez l'hôte sans mandat.
      expect(captured!.extra, equals(note.extra));
      expect(captured!.extra.keys.toSet(), <String>{'legacy_meta', kHostFaithKey});

      await _settle(tester);
    });

    testWidgets('note SANS `extra` du tout : aucune clé n\'apparaît, aucun throw',
        (tester) async {
      const note = ZSmartNote(
        content: <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'A\n'},
        ],
      );
      ZSmartNote? captured;

      await tester.pumpWidget(
        _host(ZSmartNoteEditor(note: note, onChanged: (n) => captured = n)),
      );
      await _typeAtEnd(tester, 'B');

      expect(captured, isNotNull);
      expect(captured!.extra, isEmpty);
      expect(tester.takeException(), isNull);

      await _settle(tester);
    });

    testWidgets('note SANS `extra` AVEC un canal déclaré : la clé est CRÉÉE, '
        'rien d\'autre ne bouge', (tester) async {
      const note = ZSmartNote(
        id: 'n1',
        title: 'T',
        folderId: 'f',
        content: <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'A\n'},
        ],
      );
      ZSmartNote? captured;

      await tester.pumpWidget(_host(ZSmartNoteEditor(
        note: note,
        onChanged: (n) => captured = n,
        faithChannel: hostChannel(),
      )));
      await _typeAtEnd(tester, 'B');

      expect(captured, isNotNull);
      expect(captured!.extra.keys.toSet(), <String>{kHostFaithKey});
      expect(captured!.id, 'n1');
      expect(captured!.title, 'T');
      expect(captured!.folderId, 'f');

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // AD-2 / SM-1 — la correction remonte DAVANTAGE à chaque frappe : mesurer
  // que le curseur ne saute pas et que rien n'est recréé.
  // ═════════════════════════════════════════════════════════════════════════
  group('AD-2 / SM-1 — 100 frappes AVEC canal de foi actif', () {
    testWidgets(
        'controller Quill et ZFormController JAMAIS recréés, focus conservé, '
        'curseur exact, 100 remontées, canal final cohérent', (tester) async {
      final note = ZSmartNote.fromMap(hostToCanonical('AC'));
      var count = 0;
      ZSmartNote? last;

      await tester.pumpWidget(_host(_RebuildOnChange(
        initial: note,
        channel: hostChannel(),
        onEach: (n) {
          count++;
          last = n;
        },
      )));

      final quill = _quillOf(tester);
      final focus = _focusOf(tester);
      final formBefore =
          tester.widget<ZMarkdownField>(find.byType(ZMarkdownField)).controller;
      final editorState0 =
          tester.state<State<ZSmartNoteEditor>>(find.byType(ZSmartNoteEditor));

      focus.requestFocus();
      await tester.pump();
      // Curseur AU MILIEU ('AC' → offset 1).
      quill.updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.pump();

      for (var i = 0; i < 100; i++) {
        final at = quill.selection.baseOffset;
        quill.replaceText(at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await tester.pump();
      }

      expect(identical(_quillOf(tester), quill), isTrue,
          reason: 'QuillController recréé ⇒ AD-2 violé.');
      expect(
        identical(
          tester.state<State<ZSmartNoteEditor>>(find.byType(ZSmartNoteEditor)),
          editorState0,
        ),
        isTrue,
      );
      expect(
        identical(
          tester.widget<ZMarkdownField>(find.byType(ZMarkdownField)).controller,
          formBefore,
        ),
        isTrue,
        reason: 'ZFormController recréé sous rebuild ⇒ AD-2 violé.',
      );
      expect(focus.hasFocus, isTrue);
      // 🔴 Curseur JAMAIS remis à 0 : l'écriture du canal de foi n'a provoqué
      // aucune ré-injection dans la tranche.
      expect(quill.selection.baseOffset, 101);
      expect(count, 100);
      expect(last!.extra[kHostFaithKey],
          const ZMarkdownCodec().encode(last!.content));

      await _settle(tester);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Unités du domaine — `applyTo` seul (pur Dart, sans widget).
  // ═════════════════════════════════════════════════════════════════════════
  group('ZNoteContentFaithChannel.applyTo — unités', () {
    test('écrase la clé existante et n\'en touche AUCUNE autre', () {
      final note = ZSmartNote(
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'neuf\n'},
        ],
        extra: const <String, dynamic>{
          kHostFaithKey: 'vieux',
          'autre': 42,
        },
      );
      final out = ZNoteContentFaithChannel(
        extraKey: kHostFaithKey,
        encode: (ops) => 'neuf',
      ).applyTo(note);

      expect(out.extra[kHostFaithKey], 'neuf');
      expect(out.extra['autre'], 42);
      expect(out.content, note.content);
    });

    test('`encode` rendant `null` RETIRE la clé (jamais de valeur périmée)', () {
      final note = ZSmartNote(
        extra: const <String, dynamic>{kHostFaithKey: 'vieux'},
      );
      final out = ZNoteContentFaithChannel(
        extraKey: kHostFaithKey,
        encode: (_) => null,
      ).applyTo(note);

      expect(out.extra.containsKey(kHostFaithKey), isFalse);
    });

    test('une clé RÉSERVÉE rend le canal INERTE — signalé par `assert` en debug',
        () {
      final note = ZSmartNote(
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ],
      );
      // `content` est une clé réservée : `ZSmartNote` la dépouille de `extra`.
      // 🔴 En debug l'assert doit MORDRE (sinon un hôte croirait son canal tenu).
      expect(
        () => ZNoteContentFaithChannel(
          extraKey: 'content',
          encode: (_) => 'x',
        ).applyTo(note),
        throwsA(isA<AssertionError>()),
      );
    });

    test('AD-10 — n\'échoue JAMAIS sur une note vide / sans extra', () {
      const note = ZSmartNote();
      final out = ZNoteContentFaithChannel(
        extraKey: kHostFaithKey,
        encode: (ops) => ops.isEmpty ? null : 'x',
      ).applyTo(note);
      expect(out.extra, isEmpty);
      expect(out, isA<ZSmartNote>());
    });
  });
}

/// Hôte qui RECONSTRUIT l'éditeur à chaque frappe (stress AD-2).
class _RebuildOnChange extends StatefulWidget {
  const _RebuildOnChange({
    required this.initial,
    required this.onEach,
    this.channel,
  });

  final ZSmartNote initial;
  final ValueChanged<ZSmartNote> onEach;
  final ZNoteContentFaithChannel? channel;

  @override
  State<_RebuildOnChange> createState() => _RebuildOnChangeState();
}

class _RebuildOnChangeState extends State<_RebuildOnChange> {
  late ZSmartNote _note = widget.initial;

  @override
  Widget build(BuildContext context) => ZSmartNoteEditor(
        note: _note,
        faithChannel: widget.channel,
        onChanged: (n) {
          widget.onEach(n);
          setState(() => _note = n);
        },
      );
}
