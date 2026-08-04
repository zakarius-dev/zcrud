/// **CR-IFFD-49** — le rendu par défaut tient dans les DEUX axes (①), et le
/// motif « rail des N premiers → grille complète » est une capacité du socle
/// (②).
///
/// 🔴 **Ce que ces gardes mesurent, et les angles morts qu'elles visent** :
///
/// 1. **La géométrie, pas la présence.** Une garde « le rail peint N cartes »
///    resterait verte avec des cartes de 2 dp : chaque garde de rail mesure la
///    **largeur résolue** de l'item (280 par défaut, token, paramètre).
/// 2. **Les exceptions, pas seulement l'arbre.** Le symptôme mesuré du défaut ①
///    était « RenderFlex … unbounded » en rafale (debug) / rien peint
///    (release) : un collecteur `FlutterError.onError` capte TOUTE erreur de
///    layout pendant les pumps — `pumpAndSettle` seul peut en masquer.
/// 3. **À TRAVERS `ZSectionedStudyLayout`** — la limite déclarée des lots
///    CR-47/CR-48 (cartes testées isolément), et exactement là où le défaut ①
///    vivait (le rail du layout est le défileur horizontal non borné).
/// 4. **Le badge = TOTAL, jamais le nombre rendu** — LE défaut invisible décrit
///    par la CR (`headerCount` oublié ⇒ « 10 » affiché pour 60, sans erreur).
/// 5. **Les trois voies typées, les deux axes** — le correctif ne vaut pas que
///    pour la flashcard.
library;

import 'package:flutter/foundation.dart' show FlutterExceptionHandler;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ---------------------------------------------------------------------------
// Fixtures — les trois voies typées, paramétrées à l'identique
// ---------------------------------------------------------------------------

ZFlashcard _card(int i) => ZFlashcard(
      id: 'c$i',
      question: 'Question numéro $i',
      type: ZFlashcardType.openQuestion,
    );

ZMindmap _map(int i) => ZMindmap(
      id: 'm$i',
      folderId: 'f1',
      title: 'Plan de révision $i',
    );

ZExam _exam(int i) => ZExam(
      id: 'e$i',
      folderId: 'f1',
      title: 'Examen numéro $i',
    );

/// Une voie typée sous garde : son nom, son constructeur paramétré et le type
/// de sa carte par défaut (pour la mesure de géométrie).
class _TypedPath {
  const _TypedPath({
    required this.name,
    required this.build,
    required this.cardType,
  });

  final String name;
  final ZStudyToolsSectionSpec Function({
    required int count,
    Axis axis,
    double? railItemWidth,
    int? railPreviewCount,
    int? headerCount,
    VoidCallback? secondaryAction,
  }) build;
  final Type cardType;
}

final List<_TypedPath> _paths = <_TypedPath>[
  _TypedPath(
    name: 'flashcards',
    cardType: ZDefaultFlashcardCard,
    build: ({
      required int count,
      Axis axis = Axis.horizontal,
      double? railItemWidth,
      int? railPreviewCount,
      int? headerCount,
      VoidCallback? secondaryAction,
    }) =>
        ZStudyToolsSectionSpec.flashcards(
      id: 's',
      title: 'Section',
      cards: List<ZFlashcard>.generate(count, _card),
      emptyState: const SizedBox.shrink(),
      axis: axis,
      railItemWidth: railItemWidth,
      railPreviewCount: railPreviewCount,
      headerCount: headerCount,
      secondaryAction: secondaryAction,
      secondaryActionSemanticLabel: 'Afficher tout',
    ),
  ),
  _TypedPath(
    name: 'mindmaps',
    cardType: ZDefaultMindmapCard,
    build: ({
      required int count,
      Axis axis = Axis.horizontal,
      double? railItemWidth,
      int? railPreviewCount,
      int? headerCount,
      VoidCallback? secondaryAction,
    }) =>
        ZStudyToolsSectionSpec.mindmaps(
      id: 's',
      title: 'Section',
      maps: List<ZMindmap>.generate(count, _map),
      emptyState: const SizedBox.shrink(),
      axis: axis,
      railItemWidth: railItemWidth,
      railPreviewCount: railPreviewCount,
      headerCount: headerCount,
      secondaryAction: secondaryAction,
      secondaryActionSemanticLabel: 'Afficher tout',
    ),
  ),
  _TypedPath(
    name: 'exams',
    cardType: ZDefaultExamCard,
    build: ({
      required int count,
      Axis axis = Axis.horizontal,
      double? railItemWidth,
      int? railPreviewCount,
      int? headerCount,
      VoidCallback? secondaryAction,
    }) =>
        ZStudyToolsSectionSpec.exams(
      id: 's',
      title: 'Section',
      exams: List<ZExam>.generate(count, _exam),
      emptyState: const SizedBox.shrink(),
      axis: axis,
      railItemWidth: railItemWidth,
      railPreviewCount: railPreviewCount,
      headerCount: headerCount,
      secondaryAction: secondaryAction,
      secondaryActionSemanticLabel: 'Afficher tout',
    ),
  ),
];

// ---------------------------------------------------------------------------
// Harnais
// ---------------------------------------------------------------------------

/// Collecteur d'erreurs de layout : capte TOUT ce qui passe par
/// `FlutterError.onError` pendant les pumps (le symptôme debug du défaut ① est
/// une RAFALE de « RenderFlex … unbounded » — un `pumpAndSettle` peut en
/// digérer certaines sans les remonter).
List<FlutterErrorDetails> _collectLayoutErrors() {
  final List<FlutterErrorDetails> errors = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}

Future<void> _pump(
  WidgetTester tester,
  ZStudyToolsSectionSpec spec, {
  ZcrudTheme? theme,
  bool sliver = false,
}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: theme == null
            ? null
            : ThemeData(extensions: <ThemeExtension<dynamic>>[theme]),
        home: Scaffold(
          body: sliver
              ? CustomScrollView(
                  slivers: <Widget>[
                    ZSectionedStudySliver(
                      sections: <ZStudyToolsSectionSpec>[spec],
                    ),
                  ],
                )
              : ZSectionedStudyLayout(
                  sections: <ZStudyToolsSectionSpec>[spec],
                ),
        ),
      ),
    );

double _cardWidth(WidgetTester tester, Type cardType) =>
    tester.getSize(find.byType(cardType).first).width;

void main() {
  // -------------------------------------------------------------------------
  // ① Le rail par défaut peint dans les DEUX axes — trois voies typées
  // -------------------------------------------------------------------------
  for (final _TypedPath path in _paths) {
    group('CR-IFFD-49 ① — voie typée `.${path.name}` via ZSectionedStudyLayout',
        () {
      testWidgets('rail horizontal : peint SANS exception, items à 280 dp',
          (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = _collectLayoutErrors();
        await _pump(tester, path.build(count: 3, axis: Axis.horizontal));
        await tester.pump();
        expect(
          errors,
          isEmpty,
          reason: '🔴 le rail par défaut lève encore des erreurs de layout '
              '(symptôme CR-49 ①) : '
              '${errors.map((FlutterErrorDetails e) => e.exception).join(" | ")}',
        );
        // Présence : les 3 cartes sont construites (le rail défile, il ne
        // tronque pas).
        expect(find.byType(path.cardType, skipOffstage: false), findsNWidgets(3));
        // 🔴 GÉOMÉTRIE, pas seulement présence : une carte de 2 dp (ou de
        // largeur folle) serait « présente ». Largeur RÉSOLUE = repli 280.
        expect(_cardWidth(tester, path.cardType), 280);
      });

      testWidgets('le token `ZcrudTheme.railItemWidth` gouverne la largeur',
          (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = _collectLayoutErrors();
        await _pump(
          tester,
          path.build(count: 2, axis: Axis.horizontal),
          theme: const ZcrudTheme(railItemWidth: 240),
        );
        expect(errors, isEmpty);
        expect(_cardWidth(tester, path.cardType), 240);
      });

      testWidgets('le paramètre `railItemWidth` PRIME sur le token',
          (WidgetTester tester) async {
        await _pump(
          tester,
          path.build(count: 2, axis: Axis.horizontal, railItemWidth: 320),
          theme: const ZcrudTheme(railItemWidth: 240),
        );
        expect(_cardWidth(tester, path.cardType), 320);
      });

      testWidgets('axe VERTICAL : aucun bornage de rail imposé (inchangé)',
          (WidgetTester tester) async {
        final List<FlutterErrorDetails> errors = _collectLayoutErrors();
        await _pump(tester, path.build(count: 2, axis: Axis.vertical));
        expect(errors, isEmpty);
        // La colonne verticale laisse la carte prendre la largeur disponible
        // (surface 800 dp − gouttières) : si l'enveloppe de rail s'appliquait
        // aussi ici, on mesurerait 280.
        expect(_cardWidth(tester, path.cardType), greaterThan(600));
      });
    });
  }

  testWidgets(
      'CR-IFFD-49 ① — la variante SLIVER partage le correctif (source unique)',
      (WidgetTester tester) async {
    final List<FlutterErrorDetails> errors = _collectLayoutErrors();
    await _pump(
      tester,
      _paths.first.build(count: 3, axis: Axis.horizontal),
      sliver: true,
    );
    expect(errors, isEmpty);
    expect(_cardWidth(tester, _paths.first.cardType), 280);
  });

  // -------------------------------------------------------------------------
  // ① — NEUTRALITÉ : un itemBuilder d'HÔTE n'est JAMAIS emballé
  // -------------------------------------------------------------------------
  testWidgets(
      'CR-IFFD-49 ① — constructeur principal : la largeur de l\'HÔTE est '
      'restituée telle quelle (aucun 280 imposé)', (WidgetTester tester) async {
    final ZStudyToolsSectionSpec spec = ZStudyToolsSectionSpec(
      id: 'host',
      title: 'Section hôte',
      itemCount: 2,
      axis: Axis.horizontal,
      itemBuilder: (BuildContext context, int index) => SizedBox(
        key: ValueKey<String>('host-$index'),
        width: 123,
        height: 40,
      ),
      emptyState: const SizedBox.shrink(),
    );
    await _pump(tester, spec);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('host-0'))).width,
      123,
      reason: '🔴 neutralité rompue : le chemin itemBuilder explicite doit '
          'rester STRICTEMENT celui d\'avant CR-49 (l\'hôte borne lui-même).',
    );
  });

  // -------------------------------------------------------------------------
  // ② Le couplage « rail des N premiers → grille complète »
  // -------------------------------------------------------------------------
  for (final _TypedPath path in _paths) {
    group('CR-IFFD-49 ② — couplage rail→grille sur `.${path.name}`', () {
      testWidgets(
          'railPreviewCount: 10 sur 25 : 10 rendus, badge = TOTAL (25), '
          'jamais le nombre rendu', (WidgetTester tester) async {
        await _pump(
          tester,
          path.build(
            count: 25,
            axis: Axis.horizontal,
            railPreviewCount: 10,
            secondaryAction: () {},
          ),
        );
        expect(
          find.byType(path.cardType, skipOffstage: false),
          findsNWidgets(10),
          reason: 'le rail doit rendre min(N, total) items',
        );
        // 🔴 LE défaut invisible décrit par la CR : le badge qui montre le
        // nombre RENDU. Il doit montrer le TOTAL.
        expect(find.text('25'), findsOneWidget,
            reason: '🔴 le badge doit porter le TOTAL réel (25)');
        expect(find.text('10'), findsNothing,
            reason: '🔴 le badge porte le nombre RENDU au lieu du total');
        // L'action « afficher tout » (créneau EXISTANT secondaryAction) est
        // présente : total > N.
        expect(
          find.byKey(const ValueKey<String>('section:s:secondaryAction')),
          findsOneWidget,
        );
      });

      testWidgets('l\'annonce a11y du compteur dit le TOTAL, pas le rendu',
          (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await _pump(
          tester,
          path.build(count: 25, axis: Axis.horizontal, railPreviewCount: 10),
        );
        // Le nœud fusionne l'en-tête (« Section ») et le compteur : l'annonce
        // doit porter le TOTAL (25), jamais le nombre rendu (10).
        final String label = tester.getSemantics(find.text('25')).label;
        expect(label, contains('25'));
        expect(label, isNot(contains('10')));
        handle.dispose();
      });

      testWidgets('un `headerCount` EXPLICITE prime (données paginées)',
          (WidgetTester tester) async {
        await _pump(
          tester,
          path.build(
            count: 25,
            axis: Axis.horizontal,
            railPreviewCount: 10,
            headerCount: 60,
          ),
        );
        expect(find.text('60'), findsOneWidget,
            reason: 'la liste locale peut être PARTIELLE : l\'hôte qui connaît '
                'le vrai total (60) doit pouvoir le dire');
        expect(find.text('25'), findsNothing);
      });

      testWidgets(
          'total ≤ N : tout est rendu, « afficher tout » ABSENTE de l\'arbre '
          '(AD-4), badge = total', (WidgetTester tester) async {
        bool called = false;
        await _pump(
          tester,
          path.build(
            count: 3,
            axis: Axis.horizontal,
            railPreviewCount: 10,
            secondaryAction: () => called = true,
          ),
        );
        expect(
            find.byType(path.cardType, skipOffstage: false), findsNWidgets(3));
        expect(find.text('3'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('section:s:secondaryAction')),
          findsNothing,
          reason: '🔴 le rail montre déjà tout : « afficher tout » doit être '
              'ABSENTE de l\'arbre (AD-4 — jamais présente et inutile)',
        );
        expect(called, isFalse);
      });

      testWidgets('total > N : « afficher tout » est BRANCHÉE (callback hôte)',
          (WidgetTester tester) async {
        int taps = 0;
        await _pump(
          tester,
          path.build(
            count: 25,
            axis: Axis.horizontal,
            railPreviewCount: 10,
            secondaryAction: () => taps++,
          ),
        );
        await tester.tap(
          find.byKey(const ValueKey<String>('section:s:secondaryAction')),
        );
        expect(taps, 1);
      });
    });
  }

  // -------------------------------------------------------------------------
  // ① — `ZRailItem` PUBLIC : la même résolution de largeur, réutilisable par
  // un hôte dans SES propres surfaces (demande owner : la carte par défaut vit
  // à plusieurs endroits — study tools, liste de flashcards en grille…).
  // -------------------------------------------------------------------------
  group('CR-IFFD-49 ① — `ZRailItem` public (réutilisation hôte)', () {
    Future<void> pumpRail(
      WidgetTester tester,
      ZRailItem item, {
      ZcrudTheme? theme,
    }) =>
        tester.pumpWidget(
          MaterialApp(
            theme: theme == null
                ? null
                : ThemeData(extensions: <ThemeExtension<dynamic>>[theme]),
            home: Scaffold(
              body: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[item],
              ),
            ),
          ),
        );

    testWidgets('repli du socle : 280 dp (constante PUBLIQUE documentée)',
        (WidgetTester tester) async {
      expect(zRailItemFallbackWidth, 280);
      await pumpRail(
        tester,
        const ZRailItem(child: Text('x')),
      );
      expect(tester.getSize(find.byType(ZRailItem)).width, 280);
    });

    testWidgets('token de thème puis paramètre explicite (même priorité que '
        'les voies typées)', (WidgetTester tester) async {
      await pumpRail(
        tester,
        const ZRailItem(child: Text('x')),
        theme: const ZcrudTheme(railItemWidth: 300),
      );
      expect(tester.getSize(find.byType(ZRailItem)).width, 300,
          reason: 'l\'app consommatrice doit pouvoir OVERRIDER le défaut par '
              'son thème (ex. les 300 dp d\'IFFD)');
      await pumpRail(
        tester,
        const ZRailItem(width: 320, child: Text('x')),
        theme: const ZcrudTheme(railItemWidth: 300),
      );
      expect(tester.getSize(find.byType(ZRailItem)).width, 320);
    });
  });

  group('CR-IFFD-49 ② — garde-fous de construction', () {
    test('railPreviewCount ≤ 0 : assert', () {
      expect(
        () => _paths.first
            .build(count: 3, axis: Axis.horizontal, railPreviewCount: 0),
        throwsAssertionError,
      );
    });

    test('railPreviewCount avec axe VERTICAL : assert (la grille verticale '
        'EST la destination, pas un rail)', () {
      expect(
        () => _paths.first
            .build(count: 30, axis: Axis.vertical, railPreviewCount: 10),
        throwsAssertionError,
      );
    });
  });
}
