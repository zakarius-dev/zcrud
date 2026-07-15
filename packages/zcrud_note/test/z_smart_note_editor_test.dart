// Tests widget de `ZSmartNoteEditor` (ES-6.1, D6) — AC2 (édition réutilisée,
// controller isolé), AC3 (SM-1 : 100 frappes, controller stable, témoin frère),
// AC4 (sens unique, contenu neutre, autres champs préservés), AC5 (🔴 DW-ES22-1 :
// round-trip d'un corps markdown LEGACY sans perte), AC6 (défensif), AC8
// (isolation de type — aucune fuite Quill).
//
// STRATÉGIE (parité `zcrud_markdown`) : les frappes sont simulées via le
// `QuillController` RÉEL rendu par `ZMarkdownField` (`QuillEditor.controller` est
// PUBLIC dans `flutter_quill`, arête de TEST uniquement). Aucun type Quill
// n'apparaît dans la surface publique de `zcrud_note` (AC8) — le test l'atteint
// par le widget Quill que le champ REND.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_note/zcrud_note.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillController _quillOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

FocusNode _focusOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).focusNode;

/// Concatène le texte des ops `insert` (texte) d'un contenu neutre.
String _joinedInserts(List<Map<String, dynamic>> ops) =>
    ops.map((o) => o['insert']).whereType<String>().join();

void main() {
  group('AC2 — édition via ZMarkdownField RÉUTILISÉ, ZFormController isolé', () {
    testWidgets(
        'un ZMarkdownField unique (voie controller), key ValueKey(content), '
        'codec ZDeltaCodec, tranche seedée avec note.content', (tester) async {
      final note = ZSmartNote(
        title: 'T',
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Corps\n'},
        ],
      );

      await tester.pumpWidget(
        _host(ZSmartNoteEditor(note: note, onChanged: (_) {})),
      );

      final fields = find.byType(ZMarkdownField);
      expect(fields, findsOneWidget);
      final md = tester.widget<ZMarkdownField>(fields);

      // Place STABLE obligatoire (AD-2).
      expect(md.key, const ValueKey<String>('content'));
      // Voie `controller` (E6-1), pas la voie `ctx`.
      expect(md.controller, isNotNull);
      // Codec IDENTITÉ.
      expect(md.codec, isA<ZDeltaCodec>());
      // Tranche seedée avec note.content (valeur neutre, sans transformation).
      expect(md.controller!.valueOf('content'), equals(note.content));

      // Le ZFormController est créé UNE FOIS (State stable ⇒ initState unique).
      final state0 =
          tester.state<State<ZSmartNoteEditor>>(find.byType(ZSmartNoteEditor));
      await tester.pump();
      final state1 =
          tester.state<State<ZSmartNoteEditor>>(find.byType(ZSmartNoteEditor));
      expect(identical(state0, state1), isTrue);
      // …et le controller de la tranche n'est pas remplacé.
      final md2 = tester.widget<ZMarkdownField>(find.byType(ZMarkdownField));
      expect(identical(md2.controller, md.controller), isTrue);

      await _settle(tester);
    });
  });

  group('AC3 / SM-1 — 100 frappes : controller JAMAIS recréé, focus/curseur '
      'préservés, témoin frère figé (AD-2)', () {
    testWidgets(
        'sous rebuild parent à CHAQUE frappe, le QuillController et le State '
        'restent identiques ; onChanged remonte 100 fois ; le témoin ne '
        'reconstruit pas', (tester) async {
      final note = ZSmartNote(
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'AC\n'},
        ],
      );
      var onChangedCount = 0;

      await tester.pumpWidget(_host(_RebuildOnChange(
        initial: note,
        onEach: (_) => onChangedCount++,
      )));

      final host = tester.state<_RebuildOnChangeState>(
        find.byType(_RebuildOnChange),
      );

      final quill = _quillOf(tester);
      final focus = _focusOf(tester);
      final editorState0 =
          tester.state<State<ZSmartNoteEditor>>(find.byType(ZSmartNoteEditor));
      // Identité du ZFormController ISOLÉ capturée AVANT la tempête (MEDIUM-1).
      final formBefore =
          tester.widget<ZMarkdownField>(find.byType(ZMarkdownField)).controller;

      focus.requestFocus();
      await tester.pump();
      // Curseur AU MILIEU ('AC' → offset 1).
      quill.updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.pump();

      final witnessBefore = host.witnessBuilds;

      for (var i = 0; i < 100; i++) {
        final at = quill.selection.baseOffset;
        quill.replaceText(
          at,
          0,
          'x',
          TextSelection.collapsed(offset: at + 1),
        );
        await tester.pump();
      }

      // 🔴 LOAD-BEARING : controller Quill JAMAIS recréé (identité stable).
      expect(identical(_quillOf(tester), quill), isTrue,
          reason: 'QuillController recréé ⇒ AD-2 violé (injection #1 : _form '
              'créé dans build au lieu d\'initState).');
      // State de l'éditeur JAMAIS recréé (⇒ _form créé une seule fois).
      expect(
        identical(
          tester.state<State<ZSmartNoteEditor>>(find.byType(ZSmartNoteEditor)),
          editorState0,
        ),
        isTrue,
      );
      // 🔴 LOAD-BEARING (MEDIUM-1) : identité DIRECTE du ZFormController isolé,
      // indépendante des protections propres de ZMarkdownField sur son
      // QuillController. Si `_form` était créé dans build() au lieu d'initState
      // (injection #1), cette identité changerait à chaque frame ⇒ ROUGE — là où
      // l'assertion sur le seul QuillController restait faussement verte.
      expect(
        identical(
          tester.widget<ZMarkdownField>(find.byType(ZMarkdownField)).controller,
          formBefore,
        ),
        isTrue,
        reason: 'ZFormController recréé sous rebuild ⇒ AD-2 violé (injection #1 : '
            '_form créé dans build au lieu d\'initState).',
      );
      // Focus conservé pendant toute la frappe.
      expect(focus.hasFocus, isTrue);
      // Curseur cohérent (jamais remis à 0 par une ré-injection).
      expect(quill.selection.baseOffset, 101);
      // Sens unique : onChanged a remonté à chaque frappe.
      expect(onChangedCount, 100);
      // Témoin FRÈRE (hors tranche content) figé : le rebuild parent ne force
      // pas sa reconstruction (place stable).
      expect(host.witnessBuilds, witnessBefore);

      await _settle(tester);
    });
  });

  group('AC4 — saisie à SENS UNIQUE : onChanged remonte une note neutre, autres '
      'champs préservés, aucune ré-injection', () {
    testWidgets(
        'onChanged reçoit note.copyWith(content: ops neutres) ; id/titre/'
        'dossier/extra intacts ; le curseur n\'est pas écrasé', (tester) async {
      final note = ZSmartNote(
        id: 'n1',
        title: 'Titre',
        folderId: 'f1',
        subFolderId: 's1',
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'A\n'},
        ],
        extra: const <String, dynamic>{'legacy_meta': 'v'},
      );
      ZSmartNote? captured;

      await tester.pumpWidget(
        _host(ZSmartNoteEditor(note: note, onChanged: (n) => captured = n)),
      );

      final quill = _quillOf(tester);
      _focusOf(tester).requestFocus();
      await tester.pump();
      final at = quill.document.length - 1; // avant le \n terminal
      quill.replaceText(at, 0, 'B', TextSelection.collapsed(offset: at + 1));
      await tester.pump();

      expect(captured, isNotNull);
      // Contenu NEUTRE (jamais un type Quill) — `content` est List<Map>.
      expect(captured!.content, isA<List<Map<String, dynamic>>>());
      expect(_joinedInserts(captured!.content), contains('B'));
      // Autres champs préservés (copyWith à sentinelle).
      expect(captured!.id, 'n1');
      expect(captured!.title, 'Titre');
      expect(captured!.folderId, 'f1');
      expect(captured!.subFolderId, 's1');
      expect(captured!.extra['legacy_meta'], 'v');
      // Aucune ré-injection : le curseur reste après l'insertion.
      expect(quill.selection.baseOffset, at + 1);

      await _settle(tester);
    });
  });

  group('AC5 — 🔴 DW-ES22-1 : round-trip d\'un corps markdown LEGACY sans perte',
      () {
    testWidgets(
        'note née de fromMap({content: "# Titre markdown legacy"}) : le corps '
        'entre VERBATIM dans l\'éditeur (jamais [] via asDeltaOps(String)) et '
        'SURVIT à un aller-retour', (tester) async {
      final note = ZSmartNote.fromMap(
        const <String, dynamic>{'content': '# Titre markdown legacy'},
      );
      // Le domaine a préservé le corps en ops canoniques.
      expect(_joinedInserts(note.content), contains('# Titre markdown legacy'));

      ZSmartNote? captured;
      await tester.pumpWidget(
        _host(ZSmartNoteEditor(note: note, onChanged: (n) => captured = n)),
      );

      // 🔴 PREUVE EXÉCUTABLE : le document seedé porte le corps legacy VERBATIM.
      // Si l'adaptateur passait une `String` brute à ZMarkdownField,
      // asDeltaOps(String)→null→[] rendrait un document VIDE ⇒ cette assertion
      // ROUGIRAIT (le corps aurait été DÉTRUIT).
      final quill = _quillOf(tester);
      expect(quill.document.toPlainText(), contains('# Titre markdown legacy'));

      // Aller-retour domaine → éditeur → domaine (on tape puis on relit).
      _focusOf(tester).requestFocus();
      await tester.pump();
      final at = quill.document.length - 1;
      quill.replaceText(at, 0, '!', TextSelection.collapsed(offset: at + 1));
      await tester.pump();

      expect(captured, isNotNull);
      // Jamais vidé, corps legacy toujours présent (réconciliation prouvée).
      expect(captured!.content, isNot(equals(const <Map<String, dynamic>>[])));
      expect(
        _joinedInserts(captured!.content),
        contains('# Titre markdown legacy'),
      );

      await _settle(tester);
    });
  });

  group('AC6 — décodage défensif (AD-10) : contenu vide ⇒ éditeur vide éditable, '
      'jamais de throw', () {
    testWidgets('content == [] ⇒ document vide, aucun throw, éditeur présent',
        (tester) async {
      const note = ZSmartNote();
      await tester.pumpWidget(
        _host(const ZSmartNoteEditor(note: note, onChanged: _noop)),
      );

      expect(find.byType(ZMarkdownField), findsOneWidget);
      final quill = _quillOf(tester);
      expect(quill.document.toPlainText().trim(), isEmpty);
      expect(tester.takeException(), isNull);

      await _settle(tester);
    });
  });
}

void _noop(ZSmartNote _) {}

/// Hôte qui RECONSTRUIT l'éditeur à CHAQUE frappe (setState sur onChanged) —
/// stresse la stabilité du controller (injection #1). Le témoin frère
/// [_Witness] est une instance STABLE : un rebuild parent ne le reconstruit pas.
class _RebuildOnChange extends StatefulWidget {
  const _RebuildOnChange({required this.initial, required this.onEach});

  final ZSmartNote initial;
  final ValueChanged<ZSmartNote> onEach;

  @override
  State<_RebuildOnChange> createState() => _RebuildOnChangeState();
}

class _RebuildOnChangeState extends State<_RebuildOnChange> {
  late ZSmartNote _note = widget.initial;
  int witnessBuilds = 0;

  late final Widget _witness = _Witness(onBuild: () => witnessBuilds++);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _witness,
        ZSmartNoteEditor(
          note: _note,
          onChanged: (n) {
            widget.onEach(n);
            setState(() => _note = n);
          },
        ),
      ],
    );
  }
}

class _Witness extends StatefulWidget {
  const _Witness({required this.onBuild});
  final VoidCallback onBuild;
  @override
  State<_Witness> createState() => _WitnessState();
}

class _WitnessState extends State<_Witness> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    return const SizedBox.shrink();
  }
}
