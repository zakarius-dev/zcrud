/// `ZEditionScaffold` — chrome d'édition **adapté au mode** (CR
/// chrome-presentation-aware).
///
/// Volets : forme par mode, AD-4 (`null` ⇒ absent de l'arbre, jamais un nœud
/// neutre), AD-10 (chrome partiel ⇒ aucun throw), AD-13 (cibles ≥ 48 dp
/// **prouvées sous `shrinkWrap`**, sémantique explicite), FR-26/NFR-S7 (aucun
/// libellé ni couleur en dur), SM-1 (le bouton n'écoute que `state`).
///
/// ⚠️ Les délégués Material du SDK ne supportent que `en` (aucun
/// `flutter_localizations` dans ce paquet — et on ne l'ajoutera pas pour un
/// test). L'hôte Material tourne donc en `en` ; la preuve de **locale-awareness**
/// des libellés (volet SC-5) utilise un hôte `Localizations` **nu**, suffisant
/// pour la forme `dialog` qui n'exige aucune `MaterialLocalizations`.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Hôte Material (locale `en` — la seule que les délégués du SDK couvrent).
Widget _host(
  Widget child, {
  MaterialTapTargetSize tapTarget = MaterialTapTargetSize.padded,
}) =>
    MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        ZcrudLocalizationsDelegate(),
      ],
      theme: ThemeData(materialTapTargetSize: tapTarget),
      home: Scaffold(body: child),
    );

/// Hôte `Localizations` **nu** : permet d'exercer une locale que les délégués
/// Material du SDK ne couvrent pas.
Widget _l10nHost(Widget child, Locale locale) => Directionality(
      textDirection: TextDirection.ltr,
      child: Localizations(
        locale: locale,
        delegates: const <LocalizationsDelegate<Object?>>[
          ZcrudLocalizationsDelegate(),
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Theme(data: ThemeData(), child: Material(child: child)),
      ),
    );

Finder _inScaffold(Finder matching) => find.descendant(
      of: find.byType(ZEditionScaffold),
      matching: matching,
    );

void main() {
  group('SC-1 — forme du chrome PAR MODE', () {
    testWidgets('page → Scaffold + SliverAppBar repliable au scroll',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(title: 'Titre'),
          mode: ZEditionPresentation.page,
        ),
      ));
      expect(_inScaffold(find.byType(SliverAppBar)), findsOneWidget);
      final SliverAppBar bar = tester.widget(find.byType(SliverAppBar));
      expect(bar.floating, isTrue,
          reason: '🔴 l\'en-tête de page ne se replie pas au scroll.');
      expect(bar.pinned, isFalse);
      expect(find.text('CORPS'), findsOneWidget);
    });

    testWidgets(
        'dialog → en-tête + corps + barre d\'actions en pied, PAS de '
        'SliverAppBar, PAS de safe-area, PAS de poignée',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(title: 'Titre', submitLabel: 'OK', onSubmit: _noop),
          mode: ZEditionPresentation.dialog,
        ),
      ));
      expect(_inScaffold(find.byType(SliverAppBar)), findsNothing);
      expect(_inScaffold(find.byType(SafeArea)), findsNothing,
          reason: '🔴 le mode dialog ne doit pas ancrer ses actions en '
              'safe-area (c\'est propre à la feuille).');
      expect(find.text('Titre'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets(
        'sheet → poignée + en-tête + corps scrollable + actions en SAFE-AREA',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(title: 'Titre', submitLabel: 'OK', onSubmit: _noop),
          mode: ZEditionPresentation.sheet,
        ),
      ));
      expect(_inScaffold(find.byType(SliverAppBar)), findsNothing);
      expect(_inScaffold(find.byType(SingleChildScrollView)), findsOneWidget,
          reason: '🔴 le corps de la feuille n\'est pas scrollable.');
      final Finder safe = _inScaffold(find.byType(SafeArea));
      expect(safe, findsOneWidget);
      final SafeArea area = tester.widget(safe);
      expect(area.bottom, isTrue,
          reason: '🔴 les actions ancrées en bas n\'honorent pas la '
              'safe-area.');
      expect(area.top, isFalse);
      expect(
        _inScaffold(find.byWidgetPredicate((Widget w) =>
            w is SizedBox &&
            w.width == ZEditionChromeReference.dragHandleWidth &&
            w.height == ZEditionChromeReference.dragHandleHeight)),
        findsOneWidget,
        reason: '🔴 la poignée de feuille est absente.',
      );
    });
  });

  group('SC-2 — AD-4 : `null` ⇒ ABSENT de l\'arbre (jamais un nœud neutre)',
      () {
    testWidgets(
        'titre null ⇒ aucun nœud de titre ; poignée off ⇒ aucune poignée',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(showDragHandle: false),
          mode: ZEditionPresentation.sheet,
        ),
      ));
      expect(
        _inScaffold(find.byWidgetPredicate(
            (Widget w) => w is Semantics && w.properties.header == true)),
        findsNothing,
        reason: '🔴 un nœud de titre a été construit alors que `title` est '
            'null.',
      );
      expect(
        _inScaffold(find.byWidgetPredicate((Widget w) =>
            w is SizedBox &&
            w.width == ZEditionChromeReference.dragHandleWidth)),
        findsNothing,
      );
    });

    testWidgets('aucune action de soumission ⇒ AUCUN bouton d\'enregistrement',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(),
          mode: ZEditionPresentation.dialog,
        ),
      ));
      expect(find.text('Save'), findsNothing);
      // La voie d'abandon, elle, existe toujours.
      expect(find.text('Cancel'), findsOneWidget);
    });
  });

  group('SC-3 — AD-10 : un chrome PARTIEL ne lève jamais', () {
    for (final ZEditionPresentation mode in ZEditionPresentation.values) {
      testWidgets('chrome entièrement vide en mode ${mode.name}',
          (WidgetTester tester) async {
        await tester.pumpWidget(_host(
          ZEditionScaffold(
            body: const Text('CORPS'),
            chrome: const ZEditionChrome(),
            mode: mode,
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('CORPS'), findsOneWidget);
      });
    }
  });

  group('SC-4 — AD-13 : cible tactile ≥ 48 dp PROUVÉE sous shrinkWrap', () {
    testWidgets(
        'les actions mesurent ≥ 48 dp même quand le thème ambiant rétracte '
        'les cibles', (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(title: 'Titre', submitLabel: 'OK', onSubmit: _noop),
          mode: ZEditionPresentation.dialog,
        ),
        // 🔴 Le plancher AMBIANT du SDK est retiré : ce qui reste est le nôtre.
        tapTarget: MaterialTapTargetSize.shrinkWrap,
      ));
      for (final String action in <String>['OK', 'Cancel']) {
        final Finder box = find
            .ancestor(
              of: find.text(action),
              matching: find.byType(ConstrainedBox),
            )
            .first;
        final Size size = tester.getSize(box);
        expect(size.height,
            greaterThanOrEqualTo(ZEditionChromeReference.minTouchTarget),
            reason: '🔴 « $action » : hauteur ${size.height} < 48 dp sous '
                'shrinkWrap.');
        expect(size.width,
            greaterThanOrEqualTo(ZEditionChromeReference.minTouchTarget),
            reason: '🔴 « $action » : largeur ${size.width} < 48 dp sous '
                'shrinkWrap.');
      }
    });

    testWidgets(
        'chaque action porte une sémantique EXPLICITE (bouton + libellé + état)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_host(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(title: 'Titre', submitLabel: 'OK', onSubmit: _noop),
          mode: ZEditionPresentation.dialog,
        ),
      ));
      final Iterable<Semantics> nodes = tester
          .widgetList<Semantics>(_inScaffold(find.byType(Semantics)))
          .where((Semantics s) => s.properties.button == true);
      final Set<String?> labels =
          nodes.map((Semantics s) => s.properties.label).toSet();
      expect(labels.contains('OK'), isTrue);
      expect(labels.contains('Cancel'), isTrue);
      expect(
        nodes.every((Semantics s) => s.properties.enabled != null),
        isTrue,
        reason: '🔴 l\'état activé/désactivé n\'est porté que par la couleur.',
      );
    });
  });

  group('SC-5 — FR-26/NFR-S7 : aucun libellé codé en dur', () {
    testWidgets('les libellés par défaut suivent la LOCALE (fr ≠ en)',
        (WidgetTester tester) async {
      await tester.pumpWidget(_l10nHost(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(onSubmit: _noop),
          mode: ZEditionPresentation.dialog,
        ),
        const Locale('fr'),
      ));
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);

      await tester.pumpWidget(_l10nHost(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(onSubmit: _noop),
          mode: ZEditionPresentation.dialog,
        ),
        const Locale('en'),
      ));
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
    });

    testWidgets('un libellé fourni par PARAMÈTRE l\'emporte sur la locale',
        (WidgetTester tester) async {
      await tester.pumpWidget(_l10nHost(
        const ZEditionScaffold(
          body: Text('CORPS'),
          chrome: ZEditionChrome(submitLabel: 'Valider', discardLabel: 'Fuir', onSubmit: _noop),
          mode: ZEditionPresentation.dialog,
        ),
        const Locale('fr'),
      ));
      expect(find.text('Valider'), findsOneWidget);
      expect(find.text('Fuir'), findsOneWidget);
      expect(find.text('Enregistrer'), findsNothing);
    });
  });

  group('SC-6 — SM-1 : l\'action d\'enregistrement n\'écoute QUE `state`', () {
    testWidgets(
        'pendant `inProgress`, l\'action est DÉSACTIVÉE (sémantique incluse)',
        (WidgetTester tester) async {
      final ZFormController form = ZFormController(
        initialValues: const <String, Object?>{'a': 'x'},
      );
      addTearDown(form.dispose);
      final Completer<ZResult<Object?>> pending =
          Completer<ZResult<Object?>>();
      final ZEditionSubmitController<Object?> submit =
          ZEditionSubmitController<Object?>(
        controller: form,
        fields: const <ZFieldSpec>[],
        onSubmit: (Map<String, Object?> _) => pending.future,
      );
      addTearDown(submit.dispose);

      await tester.pumpWidget(_host(
        ZEditionScaffold(
          body: const Text('CORPS'),
          chrome: ZEditionChrome(submitController: submit),
          mode: ZEditionPresentation.dialog,
        ),
      ));
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.text('Save'));
      await tester.pump();
      final Semantics node = tester
          .widgetList<Semantics>(_inScaffold(find.byType(Semantics)))
          .firstWhere((Semantics s) => s.properties.label == 'Save');
      expect(node.properties.enabled, isFalse,
          reason: '🔴 l\'action reste activée pendant la soumission : double '
              'soumission possible, et l\'état n\'est pas porté par la '
              'sémantique.');
    });
  });
}

void _noop() {}
