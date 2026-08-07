// CR-IFFD-73 — LE TROU DE RENDU D'EMBED, et pourquoi les gardes ne le voyaient
// pas.
//
// 🔴 Le fait, mesuré en montant `ZMarkdownReader` sur le Markdown `***` :
//
//   UnimplementedError: Embeddable type "divider" is not supported by supplied
//   embed builders. […]
//   puis, en cascade :
//   _TypeError: type 'RenderErrorBox' is not a subtype of type
//   'RenderContentProxyBox?' in type cast   (x4)
//
// `ZMarkdownCodec` compte `divider` parmi ses types d'embed NATIFS : un `---`,
// `***` ou `___` produisait bien l'op `{"insert": {"divider": "hr"}}` — et
// AUCUN `EmbedBuilder` ne savait la rendre. Cinq exceptions, écran rouge, sur
// TOUTES les voies rich-text du paquet (lecteur, éditeur, plein-écran).
//
// 🔴 POURQUOI C'EST RESTÉ INVISIBLE. Les gardes existantes éprouvaient le
// CODEC — qui produisait l'op correctement, et restait donc vert — jamais le
// RENDU de l'op produite. C'est la famille « une garde hérite de l'angle mort
// de son auteur » : verte, mordante, et braquée sur la mauvaise propriété. Les
// tests ci-dessous changent de lentille : ils MONTENT.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Le texte réellement PEINT — Quill peint par `RichText`, pas par `Text` :
/// `find.textContaining` ne le voit pas, et une garde bâtie dessus serait un
/// faux rouge (ou, pire, un faux vert sur une négation).
String _painted(WidgetTester tester) {
  final StringBuffer b = StringBuffer();
  for (final RichText r in tester.widgetList<RichText>(
    find.byType(RichText),
  )) {
    b.write(r.text.toPlainText());
  }
  return b.toString();
}

Future<void> _pumpReader(WidgetTester tester, Object? value) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ZMarkdownReader(
            value: value,
            codec: const ZMarkdownCodec(),
            chrome: ZMarkdownReaderChrome.none,
            placeholder: '',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('🔴 CR-IFFD-73 — le filet horizontal se RENDait par un écran rouge', () {
    for (final String md in <String>['---', '***', '___', 'a\n\n---\n\nb']) {
      testWidgets('« ${md.replaceAll('\n', r'\n')} » se rend sans lever', (
        WidgetTester tester,
      ) async {
        await _pumpReader(tester, md);
        expect(
          tester.takeException(),
          isNull,
          reason: '🔴 un filet horizontal ne doit pas peindre un écran rouge — '
              'c\'est la construction Markdown la plus banale qui soit, et les '
              'modèles de langage en produisent en permanence.',
        );
      });
    }

    testWidgets('le filet est RÉELLEMENT PEINT (pas juste « ça ne lève pas »)',
        (WidgetTester tester) async {
      await _pumpReader(tester, 'avant\n\n---\n\napres');
      expect(
        find.byType(Divider),
        findsAtLeastNWidgets(1),
        reason: '🔴 Ne pas lever ne suffit pas : un embed silencieusement '
            'escamoté serait une PERTE, pas une réparation.',
      );
      expect(_painted(tester), contains('avant'));
    });

    test('🔬 CONTRÔLE — le codec produit BIEN un embed `divider`', () {
      // Ancre le fait qui rendait le trou atteignable. Si le codec cessait de
      // produire l'embed, les tests de rendu ci-dessus deviendraient verts pour
      // la mauvaise raison.
      final List<Map<String, dynamic>> ops = const ZMarkdownCodec().decode(
        '---',
      );
      expect(
        ops.any(
          (Map<String, dynamic> op) =>
              op['insert'] is Map &&
              (op['insert'] as Map<Object?, Object?>).containsKey('divider'),
        ),
        isTrue,
        reason: 'ops = $ops',
      );
    });
  });

  group('🔴 AD-10 — le repli TOTAL ferme la CLASSE de défauts', () {
    testWidgets('un type d\'embed INCONNU ne fait pas lever le rendu', (
      WidgetTester tester,
    ) async {
      // Corriger `divider` seul aurait traité un symptôme. Un embed d'un hôte,
      // d'une version future, ou né d'une op corrompue doit dégrader lui aussi.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZMarkdownReader(
              value: const <Map<String, dynamic>>[
                <String, dynamic>{'insert': 'avant '},
                <String, dynamic>{
                  'insert': <String, dynamic>{'zTypeQuiNExistePas': 'x'},
                },
                <String, dynamic>{'insert': ' apres\n'},
              ],
              chrome: ZMarkdownReaderChrome.none,
              placeholder: '',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 Sans `unknownEmbedBuilder`, Quill lève un '
            '`UnimplementedError` EN PLEIN BUILD : irrattrapable par '
            'l\'appelant, écran rouge déjà peint.',
      );
      expect(_painted(tester), contains('avant'));
      expect(_painted(tester), contains('apres'));
    });
  });

  group('CR-IFFD-73 — le chrome et la sémantique sont ADDITIFS', () {
    testWidgets('DÉFAUT inchangé : cadre présent, `Semantics` posé', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZMarkdownReader(value: 'x', label: 'Champ'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(ZMarkdownReader),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(
        boxes.any(
          (DecoratedBox b) =>
              b.decoration is BoxDecoration &&
              (b.decoration as BoxDecoration).border != null,
        ),
        isTrue,
        reason: 'le défaut `bordered` ne doit pas bouger d\'un pixel',
      );
      // Le nœud FUSIONNE le libellé et le contenu : on cherche donc le libellé
      // PAR MOTIF, jamais par égalité. Une garde en égalité serait verte
      // dans les DEUX sens — donc vacante.
      expect(find.bySemanticsLabel(RegExp('Champ')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('`chrome: none` retire RÉELLEMENT le cadre', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZMarkdownReader(
              value: 'x',
              chrome: ZMarkdownReaderChrome.none,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(ZMarkdownReader),
          matching: find.byType(DecoratedBox),
        ),
      );
      final bool hasBorder = boxes.any((DecoratedBox b) {
        final Decoration d = b.decoration;
        return d is BoxDecoration && d.border != null;
      });
      expect(
        hasBorder,
        isFalse,
        reason: '🔴 `chrome: none` doit avoir un effet OBSERVABLE, sinon le '
            'drapeau ment.',
      );
    });

    testWidgets('`semanticsEnabled: false` retire le nœud du lecteur', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZMarkdownReader(
              value: 'x',
              label: 'Champ',
              semanticsEnabled: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('Champ')), findsNothing);
      handle.dispose();
    });
  });
}
