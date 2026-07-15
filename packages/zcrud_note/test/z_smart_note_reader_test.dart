// Tests widget de `ZSmartNoteReader` (ES-6.1, D5) — AC1 (lecture réutilisée),
// AC6 (défensif vide), AC7 (a11y basique).
//
// STRATÉGIE : `ZSmartNoteReader` est un MINCE ADAPTATEUR (D1). On vérifie qu'il
// COMPOSE `ZMarkdownReader` de zcrud_markdown TEL QUEL, avec la valeur NEUTRE
// `note.content` et le codec IDENTITÉ `ZDeltaCodec` — sans transformer le
// contenu, sans réimplémenter un lecteur, sans exposer un type Quill (AC8).
import 'package:flutter/material.dart';
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

/// Draine les timers Quill et démonte l'arbre avant la vérification d'invariants
/// de fin de test (parité avec les tests de `zcrud_markdown`).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  group('AC1 — lecture via ZMarkdownReader RÉUTILISÉ (identité, lecture seule)',
      () {
    testWidgets(
        'un ZMarkdownReader unique reçoit value == note.content, codec '
        'ZDeltaCodec, label == titre ; AUCUN éditeur (voie d\'écriture)',
        (tester) async {
      final note = ZSmartNote(
        title: 'Ma note',
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Bonjour '},
          <String, dynamic>{
            'insert': 'gras',
            'attributes': <String, dynamic>{'bold': true},
          },
          <String, dynamic>{'insert': '\n'},
        ],
      );

      await tester.pumpWidget(_host(ZSmartNoteReader(note: note)));

      // Exactement UN lecteur réutilisé…
      final readers = find.byType(ZMarkdownReader);
      expect(readers, findsOneWidget);
      final reader = tester.widget<ZMarkdownReader>(readers);

      // …recevant la valeur NEUTRE `note.content` SANS transformation…
      expect(reader.value, equals(note.content));
      // …le codec IDENTITÉ (jamais un codec maison)…
      expect(reader.codec, isA<ZDeltaCodec>());
      // …le titre pour la sémantique…
      expect(reader.label, 'Ma note');
      // …et AUCUN éditeur (aucune voie d'écriture en lecture).
      expect(find.byType(ZMarkdownField), findsNothing);

      await _settle(tester);
    });
  });

  group('AC6 — décodage défensif (AD-10) : vide ⇒ placeholder, jamais de throw',
      () {
    testWidgets('content == [] ⇒ placeholder par défaut, aucun throw',
        (tester) async {
      const note = ZSmartNote(); // content == kEmptyNoteContent (== [])
      await tester.pumpWidget(_host(const ZSmartNoteReader(note: note)));

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.text('Aucun contenu'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _settle(tester);
    });

    testWidgets('note construite d\'une map VIDE ⇒ placeholder, aucun throw',
        (tester) async {
      final note = ZSmartNote.fromMap(const <String, dynamic>{});
      await tester.pumpWidget(_host(ZSmartNoteReader(note: note)));

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.text('Aucun contenu'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _settle(tester);
    });

    testWidgets('placeholder PERSONNALISÉ propagé au lecteur réutilisé',
        (tester) async {
      const note = ZSmartNote();
      await tester.pumpWidget(
        _host(const ZSmartNoteReader(note: note, placeholder: 'Note vide')),
      );

      final reader = tester.widget<ZMarkdownReader>(find.byType(ZMarkdownReader));
      expect(reader.placeholder, 'Note vide');
      expect(find.text('Note vide'), findsOneWidget);

      await _settle(tester);
    });
  });

  group('AC7 — a11y : le contenu vide ne casse pas, rendu directionnel (RTL)',
      () {
    testWidgets('rendu RTL sans exception (l\'adaptateur ne régresse pas AD-13)',
        (tester) async {
      final note = ZSmartNote(
        title: 'RTL',
        content: const <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'محتوى\n'},
        ],
      );
      await tester.pumpWidget(
        _host(ZSmartNoteReader(note: note), dir: TextDirection.rtl),
      );

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _settle(tester);
    });
  });
}
