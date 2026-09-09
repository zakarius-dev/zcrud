/// **Preset de session d'étude** — les FORMES que l'assemblage compose enfin
/// lui-même, au lieu de les redemander à chaque hôte.
///
/// ## Le défaut visé
///
/// Tout ce dont une session complète a besoin traversait déjà l'assemblage —
/// mais **en VALEURS** : un jeton par-ci, une clé par-là, un seam par ailleurs.
/// Les **formes** — la rangée d'en-tête, le chrome de carte, le style de
/// progression — restaient à composer par l'appelant, à chaque écran. Composer
/// une forme à la main coûte exactement ce que ces gardes mesurent : un
/// `cardSlotBuilder` posé sans l'état de révélation branché (la carte reste sur
/// sa question), puis un retrait qui emporte six seams sans qu'aucune assertion
/// ne bouge.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZFlashcardReviewCard>(…).accentHeight` resterait vert
/// si la carte cessait de peindre le liseré : ce serait mesurer le **passage**
/// d'une valeur, jamais son **effet rendu**. Chaque garde cherche donc le nœud
/// réellement monté (clé publique), le texte réellement rendu, la hauteur
/// réellement mise en page, et les couleurs réellement remises au moteur de
/// rendu (`RenderDecoratedBox`, `RenderPhysicalShape`). Aucune rastérisation :
/// `toImage()` pend sous ce harnais.
///
/// ## Inertie ABSOLUE
///
/// Les montages « historiques » n'énoncent **pas** `preset:`, pas même à `null`
/// : l'énoncer court-circuiterait le défaut du constructeur. L'arbre rendu ET
/// les couleurs peintes sont comparés en **égalité stricte** à des dumps
/// capturés sur disque **avant** l'écriture du preset.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderDecoratedBox, RenderPhysicalShape;
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZGradientSpec, ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardReviewCard, ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZSessionItem,
        ZSessionProgressIndicator,
        ZSessionProgressStyle,
        ZStreakBadge;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudyStreak;

import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

// ── Seams de test ──────────────────────────────────────────────────────────

/// Clé de dégradé que la carte compose à partir du type des cartes du harnais.
const String kTypeKey = 'flashcard.type.openQuestion';

/// Clé explicite, volontairement hors de tout format dérivé du type.
const String kExplicitKey = 'preset.session.cle';

/// Clé de couleur de fond demandée par le preset.
const String kBackgroundKey = 'preset.session.fond';

/// Fond réellement rendu pour [kBackgroundKey] — hors de toute couleur de rôle
/// du thème de test, pour qu'une égalité ne puisse pas être fortuite.
const Color kPresetSurface = Color(0xFF2A4B6C);

/// Fond demandé par le paramètre EXPLICITE du porteur — distinct du précédent.
const Color kExplicitSurface = Color(0xFF6C4B2A);

ZGradientSpec _spec(Color a, Color b) => ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[a, b]),
      onGradient: const Color(0xFF000000),
    );

/// Dégradé rendu pour la clé DÉRIVÉE du type.
final ZGradientSpec kByType = _spec(
  const Color(0xFF102030),
  const Color(0xFF405060),
);

/// Dégradé rendu pour la clé EXPLICITE — distinct, donc jamais égal par hasard.
final ZGradientSpec kByExplicitKey = _spec(
  const Color(0xFF708090),
  const Color(0xFFA0B0C0),
);

List<Color> _colorsOf(ZGradientSpec spec) =>
    (spec.gradient as LinearGradient).colors;

ZGradientSpec? _gradientResolver(ColorScheme scheme, String key) =>
    switch (key) {
      kTypeKey => kByType,
      kExplicitKey => kByExplicitKey,
      _ => null,
    };

ZColorPair? _colorResolver(ColorScheme scheme, String key) => key ==
        kBackgroundKey
    ? const ZColorPair(color: kPresetSurface, onColor: Color(0xFFFFFFFF))
    : null;

Widget _wrap(Widget child, {bool withResolvers = false}) => MaterialApp(
      home: Scaffold(
        body: withResolvers
            ? ZcrudScope(
                gradientResolver: _gradientResolver,
                colorKeyResolver: _colorResolver,
                child: child,
              )
            : child,
      ),
    );

// ── Sondes de rendu ────────────────────────────────────────────────────────

/// La carte de devant, telle qu'elle est réellement montée.
Finder _card() => find.byType(ZFlashcardReviewCard).first;

Finder _inCard(Finder matching) =>
    find.descendant(of: _card(), matching: matching);

/// Couleurs RÉELLEMENT remises au moteur de rendu pour le liseré.
List<Color> _accentColors(WidgetTester tester) {
  final RenderDecoratedBox box = tester.renderObject<RenderDecoratedBox>(
    find
        .descendant(
          of: find.byKey(ZFlashcardReviewCard.gradientAccentKey).first,
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).gradient! as LinearGradient).colors;
}

/// Couleurs RÉELLEMENT remises au moteur de rendu pour la PASTILLE de type.
List<Color> _badgeColors(WidgetTester tester) {
  final RenderDecoratedBox box = tester.renderObject<RenderDecoratedBox>(
    find
        .descendant(
          of: find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey).first,
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return ((box.decoration as BoxDecoration).gradient! as LinearGradient).colors;
}

/// Couleur RÉELLEMENT peinte sous la carte (`Material` ⇒ `PhysicalShape`).
Color _cardSurface(WidgetTester tester) => tester
    .renderObject<RenderPhysicalShape>(_inCard(find.byType(PhysicalShape)).first)
    .color;

/// Le dump ordonné des types de widgets montés — égalité STRICTE, jamais
/// `contains` ni un décompte : un nœud intercalé se voit à la position.
List<String> _treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Les couleurs RÉELLEMENT peintes, sous la même forme que le dump figé.
String _paintedDump(WidgetTester tester) {
  final Finder accent = find.byKey(ZFlashcardReviewCard.gradientAccentKey);
  final String accentLine = accent.evaluate().isEmpty
      ? 'accent=absent'
      : 'accent=${_accentColors(tester)}';
  return 'cardSurface=${_cardSurface(tester)}\n$accentLine';
}

/// Le dump de référence, capturé sur disque AVANT le preset.
List<String> _baseline(String name) {
  final File file = File('${zsrc.packageRoot().path}/test/support/$name');
  if (!file.existsSync()) {
    throw StateError(
      'Dump de référence introuvable : ${file.path}. La garde d\'inertie ne '
      'mesure plus rien.',
    );
  }
  return file.readAsStringSync().split('\n');
}

/// Le dump vivant, mis à la forme exacte du fichier figé (dump, séparateur,
/// couleurs peintes, saut de ligne final).
List<String> _live(WidgetTester tester) =>
    '${_treeDump(tester).join('\n')}\n--- painted ---\n'
            '${_paintedDump(tester)}\n'
        .split('\n');

// ── Presets de test ────────────────────────────────────────────────────────

ZSessionHeaderSpec _headerSpec(ZStudySessionProgress progress) =>
    ZSessionHeaderSpec(
      title: 'titre de preset',
      counter: 'compteur ${progress.reviewed}',
    );

void main() {
  group('🧊 inertie ABSOLUE — `preset` non énoncé ⇒ rien ne bouge', () {
    const Map<String, String> baselines = <String, String>{
      'auto': 'z_preset_tree_before_lotp3_auto.txt',
      'always': 'z_preset_tree_before_lotp3_always.txt',
      'header': 'z_preset_tree_before_lotp3_header.txt',
    };

    test('les dumps de référence sont non vides et portent bien la carte', () {
      baselines.forEach((_, String name) {
        final List<String> dump = _baseline(name);
        expect(dump, isNotEmpty);
        expect(dump, contains('ZFlashcardReviewCard'),
            reason: '🔴 un dump sans carte ne prouverait rien');
        expect(dump, contains('--- painted ---'),
            reason: '🔴 un dump sans couleurs peintes ne prouverait que '
                'la structure');
      });
    });

    testWidgets('auto : arbre ET couleurs strictement identiques',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(mode: ZReviewMode.list, queue: writtenCards(2)),
      ));
      await tester.pumpAndSettle();
      expect(_live(tester), _baseline(baselines['auto']!),
          reason: '🔴 le preset a changé l\'arbre ou les couleurs alors qu\'il '
              'n\'est pas énoncé (AD-4)');
    });

    testWidgets('always : arbre ET couleurs strictement identiques',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          revealPolicy: ZStudySessionRevealPolicy.always,
        ),
      ));
      await tester.pumpAndSettle();
      expect(_live(tester), _baseline(baselines['always']!),
          reason: '🔴 le preset a changé l\'arbre ou les couleurs sur le site '
              'du créneau de carte');
    });

    testWidgets('en-tête explicite : arbre ET couleurs strictement identiques',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          headerBuilder: (BuildContext context, ZStudySessionProgress p) =>
              Text('hdr:${p.reviewed}'),
          counterBuilder: (BuildContext context, ZStudySessionProgress p) =>
              Text('cnt:${p.remaining}'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_live(tester), _baseline(baselines['header']!),
          reason: '🔴 la résolution du preset a modifié le chemin de l\'en-tête '
              'alors qu\'aucun preset n\'est posé');
    });
  });

  group('🥇 priorité — un slot EXPLICITE gagne toujours sur le preset', () {
    testWidgets('`headerBuilder` explicite bat `preset.header`',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          headerBuilder: (BuildContext context, ZStudySessionProgress p) =>
              const Text('en-tête de l\'hôte'),
          preset: ZStudySessionPreset(header: _headerSpec),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('en-tête de l\'hôte'), findsOneWidget);
      expect(find.byKey(ZSessionHeaderSpec.rowKey), findsNothing,
          reason: '🔴 la rangée du preset s\'est ajoutée au slot explicite au '
              'lieu de lui céder la place');
      expect(find.text('titre de preset'), findsNothing);
    });

    testWidgets('`progressStyle` explicite bat `preset.progressStyle`',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          progressStyle: ZSessionProgressStyle.dots,
          preset: const ZStudySessionPreset(
            progressStyle: ZSessionProgressStyle.pill,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ZSessionProgressIndicator.pillKey), findsNothing,
          reason: '🔴 le preset a écrasé le style explicitement demandé');
      expect(find.byKey(ZSessionProgressIndicator.progressKey), findsWidgets,
          reason: '🔴 sujet non monté : l\'absence de pilule ne prouve rien');
    });

    testWidgets('`cardAccentHeight` explicite bat `cardChrome.accentHeight`',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          cardAccentHeight: 9,
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) =>
                const ZCardChromeSpec(accentHeight: 3),
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(ZFlashcardReviewCard.gradientAccentKey).first).height,
        9,
        reason: '🔴 c\'est la hauteur du preset qui a été mise en page',
      );
    });

    testWidgets('`cardTypeGradientKey` explicite bat le chrome',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          cardTypeGradientKey: kExplicitKey,
          cardAccentHeight: 4,
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) =>
                const ZCardChromeSpec(typeGradientKey: kTypeKey),
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      expect(_accentColors(tester), _colorsOf(kByExplicitKey),
          reason: '🔴 la clé du preset a gagné sur la clé explicite');
    });

    testWidgets('`instructionBanner` explicite bat le chrome',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          instructionBanner: const Text('consigne de l\'hôte'),
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) => const ZCardChromeSpec(
              instructionBanner: Text('consigne du preset'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('consigne de l\'hôte'), findsWidgets);
      expect(find.text('consigne du preset'), findsNothing);
    });

    testWidgets('`questionTypeBadgeBuilder` explicite bat le chrome',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          questionTypeBadgeBuilder:
              (BuildContext context, ZFlashcardType t) =>
                  const Text('pastille hôte'),
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) => ZCardChromeSpec(
              questionTypeBadgeBuilder:
                  (BuildContext context, ZFlashcardType t) =>
                      const Text('pastille preset'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('pastille hôte'), findsWidgets);
      expect(find.text('pastille preset'), findsNothing);
    });

    testWidgets('`cardBackgroundColor` explicite bat `cardBackgroundColorKey`',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          cardBackgroundColor: kExplicitSurface,
          preset: const ZStudySessionPreset(
            cardBackgroundColorKey: kBackgroundKey,
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      expect(_cardSurface(tester), kExplicitSurface,
          reason: '🔴 la clé du preset a repeint le fond explicitement demandé');
    });
  });

  group('🧍 forme 3 — la rangée d\'en-tête', () {
    testWidgets('`streak: null` ⇒ badge ABSENT, sujet bien monté',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(header: _headerSpec),
        ),
      ));
      await tester.pumpAndSettle();

      // 🔴 La preuve que le sujet EST monté : sans elle, `findsNothing`
      // serait vert pour la seule raison que rien n'a été construit.
      expect(find.text('titre de preset'), findsOneWidget);
      expect(find.byKey(ZSessionHeaderSpec.rowKey), findsOneWidget);
      expect(find.byType(ZStreakBadge), findsNothing,
          reason: '🔴 un badge fabriqué pour un streak absent (AD-4)');
    });

    testWidgets('`streak` posé ⇒ badge présent et `Semantics.value` exact',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(
            header: (ZStudySessionProgress p) => const ZSessionHeaderSpec(
              title: 'titre de preset',
              streak: ZStudyStreak(current: 7),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ZStreakBadge), findsOneWidget);
      final SemanticsNode node =
          tester.getSemantics(find.byKey(ZStreakBadge.badgeKey));
      expect(node.value, '7',
          reason: '🔴 la série annoncée n\'est pas celle du streak injecté');
    });

    testWidgets('la rangée fait au moins 48 dp (AD-13)',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(header: _headerSpec),
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byKey(ZSessionHeaderSpec.rowKey)).height,
        greaterThanOrEqualTo(48),
        reason: '🔴 cible tactile sous le plancher AD-13',
      );
    });

    testWidgets('une spécification VIDE ne monte aucune rangée (AD-4)',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(
            header: (ZStudySessionProgress p) => const ZSessionHeaderSpec(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ZSessionHeaderSpec.rowKey), findsNothing,
          reason: '🔴 une bande vide de 48 dp fabriquée pour un objet vide');
    });

    testWidgets(
        'AD-2 : une variation de progression ne reconstruit QUE l\'en-tête',
        (WidgetTester tester) async {
      useTallSurface(tester);
      final ValueNotifier<ZStudySessionProgress> progress =
          ValueNotifier<ZStudySessionProgress>(
        const ZStudySessionProgress(total: 2, remaining: 2),
      );
      addTearDown(progress.dispose);
      final ValueNotifier<ZStudySessionPhase> phase =
          ValueNotifier<ZStudySessionPhase>(ZStudySessionPhase.studying);
      addTearDown(phase.dispose);
      const ZSessionItem item =
          ZSessionItem(flashcardId: 'c0', folderId: kHarnessFolderId);
      final ValueNotifier<List<ZSessionItem>> queue =
          ValueNotifier<List<ZSessionItem>>(const <ZSessionItem>[item]);
      addTearDown(queue.dispose);
      final ValueNotifier<ZSessionItem?> current =
          ValueNotifier<ZSessionItem?>(item);
      addTearDown(current.dispose);

      // 🔴 Le compteur porte sur la SURFACE DE NOTATION, pas sur la carte.
      // La pile mémoïse ses instances de carte par index et rend des widgets
      // `identical` : son constructeur reste donc muet même sous une
      // reconstruction totale du sous-arbre — un compteur posé là serait vert
      // quoi qu'on lui injecte. La surface de notation, elle, n'écoute que la
      // tranche `current` et se reconstruit dès que son parent le fait : c'est
      // le seul témoin qui distingue une reconstruction granulaire d'une
      // reconstruction d'écran.
      var gradingBuilds = 0;
      var cardBuilds = 0;
      await tester.pumpWidget(_wrap(
        ZStudySessionView(
          slices: ZStudySessionSlices(
            phase: phase,
            queue: queue,
            current: current,
            progress: progress,
          ),
          cardBuilder: (BuildContext context, ZSessionItem i) {
            cardBuilds += 1;
            return const Text('carte');
          },
          gradingBuilder: (BuildContext context, ZSessionItem i) {
            gradingBuilds += 1;
            return const Text('notation');
          },
          passThreshold: 3,
          preset: ZStudySessionPreset(header: _headerSpec),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('compteur 0'), findsOneWidget);
      expect(find.text('notation'), findsOneWidget);
      expect(cardBuilds, greaterThan(0),
          reason: '🔴 pile jamais construite : le sujet n\'est pas monté');
      final int gradingFloor = gradingBuilds;
      expect(gradingFloor, greaterThan(0),
          reason: '🔴 surface de notation jamais construite : le plancher ne '
              'mesure rien');

      progress.value = const ZStudySessionProgress(
        total: 2,
        reviewed: 1,
        remaining: 1,
      );
      await tester.pumpAndSettle();

      expect(find.text('compteur 1'), findsOneWidget,
          reason: '🔴 l\'en-tête n\'a pas suivi la tranche de progression');
      expect(gradingBuilds, gradingFloor,
          reason: '🔴 un changement de progression a reconstruit une surface '
              'qui ne l\'écoute pas (SM-1/AD-2)');
    });
  });

  group('🎫 forme 5 — pastille de type et consigne posées par le preset', () {
    const Map<String, ZStudySessionRevealPolicy> sites =
        <String, ZStudySessionRevealPolicy>{
      'sans affordance de révélation': ZStudySessionRevealPolicy.never,
      'avec affordance de révélation': ZStudySessionRevealPolicy.always,
    };

    sites.forEach((String site, ZStudySessionRevealPolicy policy) {
      testWidgets('$site : la pastille est RENDUE, sous un `IgnorePointer`',
          (WidgetTester tester) async {
        useTallSurface(tester);
        final List<ZFlashcardType> seen = <ZFlashcardType>[];
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
            preset: ZStudySessionPreset(
              cardChrome: (ZFlashcard card) => ZCardChromeSpec(
                questionTypeBadgeBuilder:
                    (BuildContext context, ZFlashcardType t) {
                  seen.add(t);
                  return Text('pastille:${t.name}');
                },
                instructionBanner: const Text('consigne du preset'),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey),
            findsWidgets,
            reason: '🔴 la pastille est passée mais jamais rendue');
        expect(find.text('pastille:openQuestion'), findsWidgets);
        expect(seen, contains(ZFlashcardType.openQuestion),
            reason: '🔴 le chrome ne reçoit pas le type de la carte rendue');
        expect(find.byKey(ZFlashcardReviewCard.instructionBannerKey),
            findsWidgets);
        expect(find.text('consigne du preset'), findsWidgets);

        // La pastille ne doit pas voler le tap de révélation.
        expect(
          find.ancestor(
            of: find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey).first,
            matching: find.byType(IgnorePointer),
          ),
          findsWidgets,
          reason: '🔴 la pastille intercepte les gestes de la carte',
        );
      });
    });

    testWidgets('le chrome reçoit la carte RÉELLE, pas un gabarit',
        (WidgetTester tester) async {
      useTallSurface(tester);
      final List<String> ids = <String>[];
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) {
              ids.add(card.id ?? '');
              return const ZCardChromeSpec();
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(ids, contains('c0'),
          reason: '🔴 le chrome est résolu sur une autre carte que la rendue');
    });

    testWidgets(
        'la pastille et le liseré partagent la MÊME résolution de dégradé',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) => ZCardChromeSpec(
              accentHeight: 6,
              typeGradientKey: kExplicitKey,
              questionTypeBadgeBuilder:
                  (BuildContext context, ZFlashcardType t) =>
                      const Text('pastille'),
            ),
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      expect(_accentColors(tester), _colorsOf(kByExplicitKey));
      expect(_badgeColors(tester), _accentColors(tester),
          reason: '🔴 deux résolutions de dégradé au lieu d\'une seule');
    });
  });

  group('🎨 formes 1 et 2 — liseré et fond détaché posés par le preset', () {
    testWidgets('`cardChrome.accentHeight` ⇒ liseré RENDU à cette hauteur',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(
            cardChrome: (ZFlashcard card) =>
                const ZCardChromeSpec(accentHeight: 7),
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      final Finder accent =
          find.byKey(ZFlashcardReviewCard.gradientAccentKey).first;
      expect(accent, findsOneWidget);
      expect(tester.getSize(accent).height, 7);
      expect(_accentColors(tester), _colorsOf(kByType),
          reason: '🔴 le liseré ne suit pas la chaîne de dégradé du type');
    });

    testWidgets('`cardBackgroundColorKey` ⇒ fond résolu PAR CLÉ (FR-26)',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: const ZStudySessionPreset(
            cardBackgroundColorKey: kBackgroundKey,
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      expect(_cardSurface(tester), kPresetSurface,
          reason: '🔴 la clé n\'a pas traversé le résolveur de couleur');
    });

    testWidgets('une clé INCONNUE retombe sur un slot, sans jamais lever',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: const ZStudySessionPreset(
            cardBackgroundColorKey: 'clef.absolument.inconnue',
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      // AD-10 : aucun throw, la carte reste rendue.
      expect(_card(), findsOneWidget);
    });
  });

  group('📏 forme 4 — la pilule de progression posée par le preset', () {
    testWidgets('`preset.progressStyle` gouverne quand rien n\'est énoncé',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: const ZStudySessionPreset(
            progressStyle: ZSessionProgressStyle.pill,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ZSessionProgressIndicator.pillKey), findsOneWidget,
          reason: '🔴 le style du preset n\'atteint pas l\'indicateur');
    });
  });

  group('🏗 l\'enveloppe de PAGE relaie le preset', () {
    testWidgets('`ZStudySessionScaffold(preset:)` rend la rangée du preset',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(MaterialApp(
        home: ZStudySessionScaffold(
          title: 'session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset(header: _headerSpec),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ZSessionHeaderSpec.rowKey), findsOneWidget,
          reason: '🔴 capacité perdue EN SILENCE pour un hôte qui monte la '
              'page complète');
    });
  });

  group('🎁 `classic` — l\'assemblage complet en une déclaration', () {
    testWidgets('les quatre formes arrivent ensemble',
        (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          preset: ZStudySessionPreset.classic(
            title: 'Ma session',
            counter: (ZStudySessionProgress p) =>
                '${p.reviewed} sur ${p.total}',
            streak: const ZStudyStreak(current: 5),
            accentHeight: 5,
            cardBackgroundColorKey: kBackgroundKey,
          ),
        ),
        withResolvers: true,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Ma session'), findsOneWidget);
      expect(find.text('0 sur 2'), findsOneWidget);
      expect(find.byType(ZStreakBadge), findsOneWidget);
      expect(tester.getSize(
              find.byKey(ZFlashcardReviewCard.gradientAccentKey).first)
          .height, 5);
      expect(_cardSurface(tester), kPresetSurface);
      expect(find.byKey(ZSessionProgressIndicator.pillKey), findsOneWidget,
          reason: '🔴 `classic` doit poser la pilule, sa direction de design');
    });

    test('sans aucune valeur, `classic` ne fabrique AUCUN objet vide (AD-4)',
        () {
      final ZStudySessionPreset preset = ZStudySessionPreset.classic();
      expect(preset.header, isNull,
          reason: '🔴 un constructeur d\'en-tête fabriqué pour rien');

      // Le chrome, lui, est TOUJOURS décrit — parce que `classic` y pose sa
      // direction d'ombre par type, qu'aucun jeton de thème ne peut porter.
      // Ce n'est donc pas un descripteur vide, et l'assertion mesure qu'il ne
      // porte QUE cette direction : un champ d'habillage qui s'y glisserait
      // sans valeur demandée serait un objet fabriqué pour rien.
      final ZCardChromeSpecBuilder? chrome = preset.cardChrome;
      expect(chrome, isNotNull,
          reason: '🔴 la direction d\'ombre par type de `classic` a disparu');
      final ZCardChromeSpec spec = chrome!(
        ZFlashcard(
          id: 'ad4',
          folderId: kHarnessFolderId,
          type: ZFlashcardType.openQuestion,
          question: 'q',
          answer: 'r',
        ),
      );
      expect(spec.shadowColorResolver, isNotNull);
      expect(spec.shadowColor, isNull,
          reason: '🔴 une teinte d\'ombre fabriquée pour rien');
      expect(spec.typeGradientKey, isNull);
      expect(spec.instructionBanner, isNull);
      expect(spec.questionTypeBadgeBuilder, isNull);
      expect(spec.accentHeight, isNull);
    });
  });
}
