/// Mode de présentation **FORCÉ** (demande owner 2026-08-09) —
/// `presentEdition(forcedMode:)`.
///
/// Quatre volets :
/// * **FM-1** : le mode forcé descend **tel quel** jusqu'au présentateur, dans
///   une classe de fenêtre qui en aurait choisi un **autre** — aucune assertion,
///   aucun repli silencieux (c'est tout l'intérêt du paramètre) ;
/// * **FM-2** : la politique n'est **pas consultée** (politique instrumentée qui
///   compte ses appels) ;
/// * **FM-3** : **aucune dépendance `MediaQuery`** n'est enregistrée sur le
///   call-site — mesuré par comptage de reconstructions à taille de fenêtre
///   changeante, avec le **volet de contraste** (sans `forcedMode`, le
///   call-site DOIT se reconstruire : sans lui, FM-3 serait vacante) ;
/// * **FM-4** : le `chrome` est monté sur le mode **effectif** (donc forcé).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZWindowSizeClass;

/// Présentateur enregistreur (capte le mode sans rien ouvrir).
class _Recording implements ZFormPresenter {
  ZEditionPresentation? lastMode;
  int calls = 0;

  @override
  Future<T?> present<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
  }) {
    lastMode = mode;
    calls++;
    return Future<T?>.value(null);
  }
}

/// Politique instrumentée : compte ses consultations.
class _CountingPolicy implements ZPresentationPolicy {
  int resolves = 0;

  @override
  ZEditionPresentation resolve(
    ZWindowSizeClass sizeClass, {
    ZFormWeight formWeight = ZFormWeight.light,
  }) {
    resolves++;
    return ZEditionPresentation.dialog;
  }
}

/// Hôte qui appelle `presentEdition` **dans son `build`** et compte ses
/// reconstructions — c'est la seule façon d'observer une dépendance
/// `MediaQuery` réellement enregistrée.
class _CountingHost extends StatefulWidget {
  const _CountingHost({
    required this.presenter,
    required this.onBuild,
    this.forcedMode,
  });

  final _Recording presenter;
  final VoidCallback onBuild;
  final ZEditionPresentation? forcedMode;

  @override
  State<_CountingHost> createState() => _CountingHostState();
}

class _CountingHostState extends State<_CountingHost> {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    presentEdition<void>(
      context,
      builder: (_) => const Text('CORPS'),
      presenter: widget.presenter,
      forcedMode: widget.forcedMode,
    );
    return const SizedBox.shrink();
  }
}

Future<ZEditionPresentation?> _modeAt(
  WidgetTester tester, {
  required double width,
  required ZFormWeight weight,
  ZEditionPresentation? forcedMode,
  ZPresentationPolicy? policy,
}) async {
  final _Recording recording = _Recording();
  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Builder(
          builder: (BuildContext context) {
            presentEdition<void>(
              context,
              builder: (_) => const Text('CORPS'),
              formWeight: weight,
              presenter: recording,
              forcedMode: forcedMode,
              policy: policy ?? const ZPresentationPolicy(),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return recording.lastMode;
}

void main() {
  group('FM-1 — le mode forcé descend tel quel, SANS cohérence exigée', () {
    testWidgets('compact (400) choisirait `sheet` — forcer `page` donne `page`',
        (WidgetTester tester) async {
      expect(
        await _modeAt(tester,
            width: 400,
            weight: ZFormWeight.light,
            forcedMode: ZEditionPresentation.page),
        ZEditionPresentation.page,
      );
    });

    testWidgets('compact (400) — forcer `dialog` donne `dialog`',
        (WidgetTester tester) async {
      expect(
        await _modeAt(tester,
            width: 400,
            weight: ZFormWeight.light,
            forcedMode: ZEditionPresentation.dialog),
        ZEditionPresentation.dialog,
      );
    });

    testWidgets('expanded heavy (1000) choisirait `page` — forcer `sheet` '
        'donne `sheet`', (WidgetTester tester) async {
      expect(
        await _modeAt(tester,
            width: 1000,
            weight: ZFormWeight.heavy,
            forcedMode: ZEditionPresentation.sheet),
        ZEditionPresentation.sheet,
      );
    });

    testWidgets('sans forcedMode, la dérivation par breakpoint est INTACTE',
        (WidgetTester tester) async {
      expect(await _modeAt(tester, width: 400, weight: ZFormWeight.light),
          ZEditionPresentation.sheet);
      expect(await _modeAt(tester, width: 700, weight: ZFormWeight.light),
          ZEditionPresentation.dialog);
      expect(await _modeAt(tester, width: 1000, weight: ZFormWeight.heavy),
          ZEditionPresentation.page);
    });
  });

  group('FM-2 — la politique n\'est PAS consultée quand le mode est forcé', () {
    testWidgets('resolve() n\'est jamais appelé', (WidgetTester tester) async {
      final _CountingPolicy policy = _CountingPolicy();
      final ZEditionPresentation? mode = await _modeAt(
        tester,
        width: 400,
        weight: ZFormWeight.light,
        forcedMode: ZEditionPresentation.page,
        policy: policy,
      );
      expect(mode, ZEditionPresentation.page);
      expect(policy.resolves, 0,
          reason: '🔴 la politique a été consultée alors que le mode est '
              'forcé.');
    });

    testWidgets('CONTRASTE — sans forcedMode, resolve() EST appelé',
        (WidgetTester tester) async {
      final _CountingPolicy policy = _CountingPolicy();
      await _modeAt(
        tester,
        width: 400,
        weight: ZFormWeight.light,
        policy: policy,
      );
      expect(policy.resolves, greaterThan(0),
          reason: '🔴 sans mode forcé la politique DOIT être consultée : le '
              'volet FM-2 serait vacant.');
    });
  });

  group('FM-3 — aucune dépendance MediaQuery quand le mode est forcé', () {
    testWidgets(
        'le call-site NE se reconstruit PAS quand la fenêtre change de taille',
        (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      int builds = 0;
      final _Recording recording = _Recording();
      await tester.pumpWidget(
        MaterialApp(
          home: _CountingHost(
            presenter: recording,
            onBuild: () => builds++,
            forcedMode: ZEditionPresentation.page,
          ),
        ),
      );
      final int afterMount = builds;
      expect(afterMount, greaterThan(0));

      tester.view.physicalSize = const Size(1100, 800);
      await tester.pump();
      expect(builds, afterMount,
          reason: '🔴 le call-site s\'est reconstruit au changement de taille : '
              '`ZWindowSizeClass.of(context)` est donc encore lu alors que son '
              'résultat est ignoré.');
      expect(recording.lastMode, ZEditionPresentation.page);
    });

    testWidgets(
        'CONTRASTE — sans forcedMode, le call-site SE reconstruit (sinon FM-3 '
        'serait vacante)', (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      int builds = 0;
      final _Recording recording = _Recording();
      await tester.pumpWidget(
        MaterialApp(
          home: _CountingHost(
            presenter: recording,
            onBuild: () => builds++,
          ),
        ),
      );
      final int afterMount = builds;

      tester.view.physicalSize = const Size(1100, 800);
      await tester.pump();
      expect(builds, greaterThan(afterMount),
          reason: '🔴 le call-site NON forcé ne se reconstruit pas au '
              'changement de taille : la mesure de FM-3 ne prouve rien.');
    });
  });

  group('FM-4 — le chrome est monté sur le mode EFFECTIF (forcé)', () {
    testWidgets('compact (400) + forcedMode page ⇒ chrome de PAGE (SliverAppBar)',
        (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(400, 800);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => presentEdition<void>(
                    context,
                    builder: (_) => const Text('CORPS'),
                    forcedMode: ZEditionPresentation.page,
                    chrome: const ZEditionChrome(title: 'Titre'),
                  ),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('ouvrir'));
      await tester.pumpAndSettle();
      expect(find.byType(SliverAppBar), findsOneWidget,
          reason: '🔴 le chrome n\'a pas été monté sur le mode FORCÉ : à 400 dp '
              'il a rendu la forme `sheet` au lieu de la forme `page`.');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('CORPS'), findsOneWidget);
    });
  });
}
