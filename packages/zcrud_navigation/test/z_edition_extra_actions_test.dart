/// `ZEditionScaffold` — **unicité de rendu** des actions supplémentaires.
///
/// Ce volet verrouille un contrat de rendu qui n'était vérifié dans aucun mode :
/// une action passée dans `ZEditionChrome.extraActions` apparaît **exactement
/// une fois** à l'écran, quel que soit le mode (`page`, `sheet`, `dialog`), et
/// toujours **au même endroit sémantique** — dans la rangée des actions
/// positives, juste **avant** l'enregistrement.
///
/// Contre-témoins joints : l'action d'enregistrement et l'action d'abandon
/// restent elles aussi rendues une seule fois et à leur place ; une liste
/// d'actions supplémentaires **vide** n'ajoute **rien** dans l'arbre.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Clé de l'action supplémentaire — identifiable sans ambiguïté dans l'arbre.
const Key _extraKey = ValueKey<String>('EXTRA_ACTION');

/// Libellés distinctifs : aucun ne peut être produit par le repli l10n.
const String _titleText = 'TITRE_CHROME';
const String _bodyText = 'CORPS_CHROME';
const String _submitText = 'ENREGISTRER_CHROME';
const String _discardText = 'ABANDON_CHROME';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
      ],
      home: Scaffold(body: child),
    );

/// Le chrome de référence : un titre, une action supplémentaire identifiable,
/// une action d'enregistrement, une action d'abandon.
ZEditionChrome _chrome({bool withExtra = true, bool withSubmit = true}) =>
    ZEditionChrome(
      title: _titleText,
      submitLabel: _submitText,
      discardLabel: _discardText,
      onSubmit: withSubmit ? () {} : null,
      extraActions: withExtra
          ? const <Widget>[SizedBox(key: _extraKey, width: 24, height: 24)]
          : const <Widget>[],
    );

Future<void> _pump(
  WidgetTester tester,
  ZEditionPresentation mode, {
  bool withExtra = true,
  bool withSubmit = true,
}) async {
  await tester.pumpWidget(_host(
    ZEditionScaffold(
      body: const Text(_bodyText),
      chrome: _chrome(withExtra: withExtra, withSubmit: withSubmit),
      mode: mode,
    ),
  ));
}

Finder _inScaffold(Finder matching) => find.descendant(
      of: find.byType(ZEditionScaffold),
      matching: matching,
    );

void main() {
  group('extraActions — rendu EXACTEMENT une fois, dans les trois modes', () {
    for (final ZEditionPresentation mode in ZEditionPresentation.values) {
      testWidgets('mode ${mode.name} : une action supplémentaire, une seule '
          'occurrence à l\'écran', (WidgetTester tester) async {
        await _pump(tester, mode);

        expect(
          _inScaffold(find.byKey(_extraKey)),
          findsOneWidget,
          reason: '🔴 mode ${mode.name} : l\'action supplémentaire n\'est pas '
              'rendue exactement une fois (doublon = deux chemins de rendu '
              'actifs simultanément).',
        );
      });

      testWidgets('mode ${mode.name} : l\'action supplémentaire précède '
          'l\'enregistrement', (WidgetTester tester) async {
        await _pump(tester, mode);

        final Offset extra = tester.getCenter(_inScaffold(find.byKey(
          _extraKey,
        )));
        final Offset submit =
            tester.getCenter(_inScaffold(find.text(_submitText)));
        expect(
          extra.dx,
          lessThan(submit.dx),
          reason: '🔴 mode ${mode.name} : l\'action supplémentaire n\'est plus '
              'placée AVANT l\'enregistrement dans la rangée des actions '
              'positives.',
        );
      });

      testWidgets(
          'mode ${mode.name} : enregistrement et abandon rendus une seule fois, '
          'à leur place', (WidgetTester tester) async {
        await _pump(tester, mode);

        expect(
          _inScaffold(find.text(_submitText)),
          findsOneWidget,
          reason: '🔴 mode ${mode.name} : l\'enregistrement est dupliqué ou '
              'absent.',
        );
        expect(
          _inScaffold(find.text(_discardText)),
          findsOneWidget,
          reason: '🔴 mode ${mode.name} : l\'abandon est dupliqué ou absent.',
        );

        final Offset discard =
            tester.getCenter(_inScaffold(find.text(_discardText)));
        final Offset submit =
            tester.getCenter(_inScaffold(find.text(_submitText)));
        expect(
          discard.dx,
          lessThan(submit.dx),
          reason: '🔴 mode ${mode.name} : l\'abandon n\'est plus du côté début '
              'de l\'enregistrement.',
        );

        if (mode == ZEditionPresentation.page) {
          expect(
            find.descendant(
              of: find.byType(AppBar),
              matching: find.byKey(_extraKey),
            ),
            findsOneWidget,
            reason: '🔴 mode page : l\'action supplémentaire a quitté '
                'l\'en-tête.',
          );
        } else {
          final Offset title =
              tester.getCenter(_inScaffold(find.text(_titleText)));
          expect(
            tester.getCenter(_inScaffold(find.byKey(_extraKey))).dy,
            greaterThan(title.dy),
            reason: '🔴 mode ${mode.name} : l\'action supplémentaire n\'est '
                'plus dans la barre d\'actions en pied (elle est remontée au '
                'niveau du titre).',
          );
        }
      });

      testWidgets('mode ${mode.name} : liste vide ⇒ RIEN dans l\'arbre',
          (WidgetTester tester) async {
        await _pump(tester, mode, withExtra: false, withSubmit: false);

        expect(
          find.byKey(_extraKey),
          findsNothing,
          reason: '🔴 mode ${mode.name} : une action supplémentaire est rendue '
              'alors que la liste est vide.',
        );
        expect(
          _inScaffold(find.byType(Text)),
          findsExactly(3),
          reason: '🔴 mode ${mode.name} : le chrome sans action supplémentaire '
              'ni enregistrement doit porter EXACTEMENT trois textes (titre, '
              'corps, abandon) — un nœud de remplissage a été ajouté.',
        );
      });
    }
  });
}
