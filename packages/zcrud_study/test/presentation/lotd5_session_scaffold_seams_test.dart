/// **Seams de session relayés par l'enveloppe de page** — pour chaque
/// paramètre de [ZStudySessionHost], une valeur distinctive posée sur
/// [ZStudySessionScaffold] est **observable dans le rendu ou le comportement**.
///
/// ## Le défaut visé
///
/// L'enveloppe se documente comme un pass-through intégral. Elle ne l'était
/// pas : dix des paramètres du porteur de session n'arrivaient jamais jusqu'à
/// lui. Un hôte qui monte la page plutôt que le porteur perdait donc, **en
/// silence**, la carte de créneau, la notation manuelle et ses quatre seams de
/// présentation, les trois politiques d'écran et la gouttière basse — sans
/// aucune erreur, aucun avertissement, et un rendu qui a l'air normal.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZStudySessionHost>(…).bottomInset` resterait vert le
/// jour où le porteur cesserait d'en tenir compte : ce serait mesurer la
/// **présence** du paramètre sur un widget, pas son **effet**. Chaque garde
/// ci-dessous cherche le nœud réellement monté, le texte réellement rendu, la
/// **géométrie réellement mise en page** ou la couleur réellement peinte — et
/// chacune porte sa contre-preuve de non-vacuité (sans le paramètre, la
/// mesure est autre).
///
/// La garde d'exhaustivité de fin de fichier compare les paramètres nommés du
/// porteur à ceux que l'enveloppe relaie, **par lecture des deux sources** :
/// un paramètre ajouté demain au porteur et oublié ici fait rougir, au lieu de
/// rejoindre en silence la liste des capacités perdues.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderDecoratedBox, RenderPhysicalShape;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZGradientSpec, ZcrudLabels, ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcardReviewCard, ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardAnswerInput, ZSrsQualityButtons;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

const String kTypeKey = 'flashcard.type.openQuestion';
const String kExplicitKey = 'hote.page.cle';
const Color kDemandedSurface = Color(0xFF2A4B6C);

ZGradientSpec _spec(Color a, Color b) => ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[a, b]),
      onGradient: const Color(0xFF000000),
    );

final ZGradientSpec kByType =
    _spec(const Color(0xFF102030), const Color(0xFF405060));
final ZGradientSpec kByExplicitKey =
    _spec(const Color(0xFF708090), const Color(0xFFA0B0C0));

ZGradientSpec? _resolver(ColorScheme scheme, String key) => switch (key) {
      kTypeKey => kByType,
      kExplicitKey => kByExplicitKey,
      _ => null,
    };

Finder _button(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

Material _buttonMaterial(WidgetTester tester, int q) => tester.widget<Material>(
      find.descendant(of: _button(q), matching: find.byType(Material)).first,
    );

List<Color> _colorsOf(ZGradientSpec spec) =>
    (spec.gradient as LinearGradient).colors;

/// Couleurs RÉELLEMENT remises au moteur de rendu pour le liseré de la carte.
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

double _borderWidth(WidgetTester tester, int q) =>
    (_buttonMaterial(tester, q).shape! as RoundedRectangleBorder).side.width;

/// Mène la session jusqu'à la correction — seul état où la rangée existe.
Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('zAnswerField')),
    'ma réponse',
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey<String>('zSubmit')));
  await tester.pumpAndSettle();
}

void main() {
  /// Monte la PAGE. Aucun paramètre optionnel n'est énoncé par défaut : les
  /// énoncer à leur valeur neutre court-circuiterait le défaut du
  /// constructeur, et une injection qui change ce défaut passerait sous une
  /// garde restée verte.
  Future<void> pump(
    WidgetTester tester,
    ZStudySessionScaffold page, {
    ZcrudLabels? labels,
    bool withResolver = false,
  }) async {
    useTallSurface(tester);
    Widget body = page;
    if (withResolver) {
      body = ZcrudScope(gradientResolver: _resolver, child: body);
    }
    await tester.pumpWidget(
      MaterialApp(home: ZcrudScope(labels: labels, child: body)),
    );
    await tester.pumpAndSettle();
  }

  group('🃏 `cardSlotBuilder` — le créneau de l\'hôte est RENDU, et vivant',
      () {
    testWidgets('sans lui : la carte du SOCLE est montée', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
        ),
      );
      expect(find.byType(ZFlashcardReviewCard), findsWidgets);
      expect(find.text('créneau hôte c0'), findsNothing);
    });

    testWidgets('avec lui : la carte de l\'HÔTE est rendue, et sa commande de '
        'révélation bascule', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(2),
          // La voie SRS est requise pour que le mode `learn` monte un runtime
          // (AD-34 : aucun no-op n'est fabriqué à sa place).
          reviewer: FakeSessionReviewer().call,
          cardSlotBuilder: (BuildContext context, ZStudySessionCardSlot slot) =>
              GestureDetector(
            onTap: slot.toggleReveal,
            child: Text(
              slot.revealed
                  ? 'révélé ${slot.card.id}'
                  : 'créneau hôte ${slot.card.id}',
            ),
          ),
        ),
      );
      expect(find.byType(ZFlashcardReviewCard), findsNothing,
          reason: '🔴 le créneau de l\'hôte prime la carte du socle');
      expect(find.text('créneau hôte c0'), findsWidgets);

      await tester.tap(find.text('créneau hôte c0').first);
      await tester.pumpAndSettle();
      expect(find.text('révélé c0'), findsWidgets,
          reason: '🔴 la commande de bascule reçue par le créneau est morte : '
              'le contrôleur de révélation n\'a pas suivi le relais');
    });
  });

  group('🎚️ notation manuelle et ses quatre seams de présentation', () {
    testWidgets('sans `onQualitySelected` : la rangée est ABSENTE (AD-4)',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
        ),
      );
      await _submit(tester);
      expect(find.byType(ZSrsQualityButtons), findsNothing);
    });

    testWidgets('`onQualitySelected` : la rangée est montée ET la commande '
        'porte le cran EXACT', (tester) async {
      final List<int> taps = <int>[];
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: reviewer.call,
          onQualitySelected: taps.add,
        ),
      );
      await _submit(tester);
      expect(find.byType(ZSrsQualityButtons), findsOneWidget);
      final int writesBefore = reviewer.writes;
      await tester.tap(_button(5));
      await tester.pumpAndSettle();
      expect(taps, <int>[5],
          reason: '🔴 commande morte : le cran tapé n\'atteint pas l\'hôte');
      expect(reviewer.writes, writesBefore,
          reason: '🔒 AD-33 — la rangée NOTIFIE, elle n\'écrit pas de SRS');
    });

    testWidgets('`qualityLabelKeyFor` : le LIBELLÉ rendu vient de la clé '
        'résolue', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (_) {},
          qualityLabelKeyFor: (int q) => 'cle.cran.$q',
        ),
        labels: ZcrudLabels(const <String, String>{
          'cle.cran.5': 'CRAN CINQ',
          'cle.cran.0': 'CRAN ZERO',
        }),
      );
      await _submit(tester);
      expect(find.text('CRAN CINQ'), findsOneWidget,
          reason: '🔴 le seam de clé de libellé n\'atteint pas la rangée');
      expect(find.text('CRAN ZERO'), findsOneWidget);
    });

    testWidgets('sans `qualityColorKeyFor` : réussite et lapse sont peints '
        'DIFFÉREMMENT (non-vacuité)', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (_) {},
        ),
      );
      await _submit(tester);
      expect(
        _buttonMaterial(tester, 5).color,
        isNot(_buttonMaterial(tester, 0).color),
        reason: 'le défaut dérive la couleur du seuil de réussite : si les '
            'deux crans étaient déjà identiques, la garde suivante ne '
            'prouverait rien',
      );
    });

    testWidgets('`qualityColorKeyFor` : la COULEUR peinte suit la clé rendue '
        'par le seam', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (_) {},
          // Une clé CONSTANTE : tous les crans doivent alors être peints de
          // la même couleur — ce que le défaut ne fait jamais.
          qualityColorKeyFor: (int q) => 'error',
        ),
      );
      await _submit(tester);
      expect(_buttonMaterial(tester, 5).color,
          _buttonMaterial(tester, 0).color,
          reason: '🔴 le seam de clé de couleur n\'atteint pas la rangée');
    });

    testWidgets('`qualityPreviewLabelFor` : l\'APERÇU est rendu sous le cran',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (_) {},
          qualityPreviewLabelFor: (int q) => 'J+$q',
        ),
      );
      await _submit(tester);
      expect(find.text('J+5'), findsOneWidget,
          reason: '🔴 le seam d\'aperçu n\'atteint pas la rangée');
    });

    testWidgets('sans `qualityEmphasis` : AUCUN bord (non-vacuité)',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (_) {},
        ),
      );
      await _submit(tester);
      expect(_borderWidth(tester, 5), 0);
    });

    testWidgets('`qualityEmphasis` : le BORD réellement posé est celui demandé',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.learn,
          queue: writtenCards(1),
          reviewer: FakeSessionReviewer().call,
          onQualitySelected: (_) {},
          qualityEmphasis: const ZSrsQualityEmphasis(
            borderWidth: 3,
            selectedBorderWidth: 3,
          ),
        ),
      );
      await _submit(tester);
      expect(_borderWidth(tester, 5), 3,
          reason: '🔴 le seam d\'emphase n\'atteint pas la rangée');
    });
  });

  group('👁️ `revealPolicy` — l\'affordance de révélation', () {
    testWidgets('défaut sur un mode `list` : ABSENTE', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
        ),
      );
      expect(find.byKey(ZStudySessionHost.revealActionKey), findsNothing);
    });

    testWidgets('`always` sur un mode `list` : PRÉSENTE et opérante',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          revealPolicy: ZStudySessionRevealPolicy.always,
        ),
      );
      final Finder reveal = find.byKey(ZStudySessionHost.revealActionKey);
      expect(reveal, findsOneWidget,
          reason: '🔴 la politique de révélation n\'atteint pas le porteur');
      expect(find.text('r0'), findsNothing);
      await tester.tap(reveal);
      await tester.pumpAndSettle();
      expect(find.text('r0'), findsWidgets);
    });
  });

  group('⏸️ `postSubmitPolicy` — la retenue après notation', () {
    testWidgets('défaut sur un mode `spaced` : la carte part immédiatement',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.spaced,
          queue: writtenCards(2),
          reviewer: FakeSessionReviewer().call,
        ),
      );
      await _submit(tester);
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsNothing);
    });

    testWidgets('`hold` sur un mode `spaced` : la carte est RETENUE',
        (tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.spaced,
          queue: writtenCards(2),
          reviewer: reviewer.call,
          postSubmitPolicy: ZStudySessionPostSubmitPolicy.hold,
        ),
      );
      await _submit(tester);
      expect(find.byKey(ZStudySessionHost.continueActionKey), findsOneWidget,
          reason: '🔴 la politique de retenue n\'atteint pas le porteur');
      // 🔒 AD-33 — la retenue déplace le PASSAGE, jamais l'écriture SRS.
      expect(reviewer.writes, 1);
    });
  });

  group('📖 `questionRecall` — le rappel de question sous la saisie', () {
    testWidgets('défaut sur une fenêtre large : rappel ENTIER (aucun abrégé)',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(1),
        ),
      );
      expect(find.byType(ZFadedOverflow), findsNothing);
    });

    testWidgets('`compact` : le rappel ABRÉGÉ est monté', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(1),
          questionRecall: ZStudySessionQuestionRecall.compact,
        ),
      );
      expect(find.byType(ZFadedOverflow), findsOneWidget,
          reason: '🔴 le régime de rappel n\'atteint pas le porteur');
    });
  });

  group('📐 `bottomInset` — la gouttière basse de la saisie', () {
    testWidgets('défaut, sans inset système : AUCUNE gouttière',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(1),
        ),
      );
      expect(find.byKey(ZFlashcardAnswerInput.bottomInsetKey), findsNothing);
    });

    testWidgets('posé : la gouttière RÉELLEMENT mise en page vaut la valeur '
        'demandée', (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(1),
          bottomInset: 37,
        ),
      );
      final Finder gutter = find.byKey(ZFlashcardAnswerInput.bottomInsetKey);
      expect(gutter, findsOneWidget,
          reason: '🔴 la gouttière n\'atteint pas le porteur');
      // Géométrie MISE EN PAGE : le bas du `Padding` moins le bas de son
      // enfant. Lire `Padding.padding` mesurerait une propriété déclarée.
      final Rect outer = tester.getRect(gutter);
      final Rect inner = tester.getRect(
        find.descendant(of: gutter, matching: find.byType(MediaQuery)).first,
      );
      expect(outer.bottom - inner.bottom, 37);
    });
  });

  group('🃏 slots de la carte du socle — relayés par la PAGE aussi', () {
    testWidgets('pastille, bandeau, liseré, clé et fond arrivent à la carte',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          questionTypeBadgeBuilder: (BuildContext c, ZFlashcardType t) =>
              Text('pastille:${t.name}'),
          instructionBanner: const Text('consigne de page'),
          cardAccentHeight: 9,
          cardTypeGradientKey: kExplicitKey,
          cardBackgroundColor: kDemandedSurface,
        ),
        withResolver: true,
      );

      expect(find.text('pastille:openQuestion'), findsWidgets);
      expect(find.text('consigne de page'), findsWidgets);

      final Finder accent =
          find.byKey(ZFlashcardReviewCard.gradientAccentKey).first;
      expect(accent, findsOneWidget);
      expect(tester.getSize(accent).height, 9);
      // La clé EXPLICITE court-circuite la chaîne par type : c'est son
      // dégradé qui est peint, jamais celui de `flashcard.type.openQuestion`.
      expect(_accentColors(tester), _colorsOf(kByExplicitKey));
      expect(_colorsOf(kByExplicitKey), isNot(_colorsOf(kByType)),
          reason: 'les deux dégradés doivent différer, sinon l\'égalité '
              'ci-dessus serait vraie par coïncidence');

      final RenderPhysicalShape shape = tester.renderObject<RenderPhysicalShape>(
        find
            .descendant(
              of: find.byType(ZFlashcardReviewCard).first,
              matching: find.byType(PhysicalShape),
            )
            .first,
      );
      expect(shape.color, kDemandedSurface);
    });

    testWidgets('rien de tout cela sans les paramètres (non-vacuité)',
        (tester) async {
      await pump(
        tester,
        ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
        ),
        withResolver: true,
      );
      expect(find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey), findsNothing);
      expect(find.byKey(ZFlashcardReviewCard.instructionBannerKey), findsNothing);
      expect(find.byKey(ZFlashcardReviewCard.gradientAccentKey), findsNothing);
      final RenderPhysicalShape shape = tester.renderObject<RenderPhysicalShape>(
        find
            .descendant(
              of: find.byType(ZFlashcardReviewCard).first,
              matching: find.byType(PhysicalShape),
            )
            .first,
      );
      expect(shape.color, isNot(kDemandedSurface));
    });
  });

  group('🧮 exhaustivité du pass-through — mesurée sur les DEUX sources', () {
    String read(String relative) {
      final File file = File('${zsrc.packageRoot().path}/$relative');
      if (!file.existsSync()) {
        throw StateError(
          'Source introuvable : ${file.path}. La garde ne mesure plus rien.',
        );
      }
      return file.readAsStringSync();
    }

    /// Les paramètres nommés du constructeur du porteur.
    ///
    /// La borne est `\n  })` et non `\n  });` : un constructeur qui enchaîne
    /// sur une liste d'initialisation écrit `})  : x = …`, et l'exiger avec le
    /// point-virgule ferait courir la capture NON GOURMANDE jusqu'au `});`
    /// d'un widget privé situé plus bas — la garde réclamerait alors le relais
    /// de paramètres qui ne sont pas ceux du porteur. Même borne que le
    /// scanner du montage énuméré.
    List<String> hostParams(String source) {
      final RegExpMatch? block = RegExp(
        r'const ZStudySessionHost\(\{(.*?)\n  \}\)',
        dotAll: true,
      ).firstMatch(source);
      if (block == null) {
        throw StateError(
          'Constructeur `ZStudySessionHost` introuvable : la garde ne mesure '
          'plus rien.',
        );
      }
      return RegExp(r'this\.(\w+)')
          .allMatches(block.group(1)!)
          .map((RegExpMatch m) => m.group(1)!)
          .toList(growable: false);
    }

    /// Les arguments nommés que l'enveloppe passe au porteur.
    Set<String> relayed(String source) {
      final RegExpMatch? block = RegExp(
        r'return ZStudySessionHost\((.*?)\n    \);',
        dotAll: true,
      ).firstMatch(source);
      if (block == null) {
        throw StateError(
          'Site de composition `return ZStudySessionHost(` introuvable : la '
          'garde ne mesure plus rien.',
        );
      }
      return RegExp(r'^\s*(\w+):', multiLine: true)
          .allMatches(block.group(1)!)
          .map((RegExpMatch m) => m.group(1)!)
          .toSet();
    }

    String hostSource() =>
        read('lib/src/presentation/z_study_session_host.dart');
    String scaffoldSource() =>
        read('lib/src/presentation/z_study_session_scaffold.dart');

    test('l\'extraction aboutit des deux côtés et n\'est pas vide', () {
      expect(hostParams(hostSource()).length, greaterThan(20));
      expect(relayed(scaffoldSource()).length, greaterThan(20));
    });

    test('CHAQUE paramètre du porteur est relayé par l\'enveloppe', () {
      final List<String> params = hostParams(hostSource());
      final Set<String> passed = relayed(scaffoldSource());
      final List<String> missing =
          params.where((String p) => !passed.contains(p)).toList();
      expect(missing, isEmpty,
          reason: '🔴 capacités perdues EN SILENCE pour un hôte qui monte la '
              'page : $missing');
    });

    test('la garde MORD : un paramètre retiré du relais est signalé', () {
      final String muted = scaffoldSource().replaceFirst(
        RegExp(r'^\s*contentBuilder: contentBuilder,\n', multiLine: true),
        '',
      );
      expect(muted, isNot(scaffoldSource()), reason: 'mutation non appliquée');
      final Set<String> passed = relayed(muted);
      expect(passed.contains('contentBuilder'), isFalse);
    });

    test('🔴 la capture s\'arrête AU constructeur du porteur', () {
      // Contre-preuve de la borne : `revealLabel` est un paramètre d'un widget
      // PRIVÉ déclaré plus bas dans le même fichier. Le voir ici signifierait
      // que la capture a débordé, et que l'exhaustivité mesurée porte sur un
      // ensemble qui n'est pas celui du porteur.
      final List<String> params = hostParams(hostSource());
      expect(params, contains('counterStyle'),
          reason: 'la capture doit couvrir TOUT le constructeur');
      expect(params, isNot(contains('revealLabel')),
          reason: '🔴 la capture a débordé sur un constructeur suivant');
      expect(params.toSet(), hasLength(params.length),
          reason: '🔴 un paramètre capturé deux fois : la borne a sauté un '
              'constructeur entier');
    });

    test('la garde MORD : un constructeur renommé LÈVE', () {
      final String muted =
          hostSource().replaceAll('const ZStudySessionHost({', 'const Autre({');
      expect(() => hostParams(muted), throwsStateError);
    });
  });
}
