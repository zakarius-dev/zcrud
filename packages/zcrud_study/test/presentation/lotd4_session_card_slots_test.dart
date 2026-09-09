/// **Relais des slots de la carte de révision** — de [ZStudySessionHost]
/// jusqu'à la carte que l'assemblage monte lui-même.
///
/// ## Le défaut visé
///
/// `ZFlashcardReviewCard` porte une pastille de type, un bandeau de consigne,
/// une clé de dégradé explicite, une hauteur de liseré et une couleur de fond.
/// L'assemblage montait cette carte **sans jamais leur donner de valeur** : le
/// seul moyen d'y accéder était de remplacer la carte entière par
/// `cardBuilder` — ce qui fait perdre au passage le câblage
/// `revealController: slot.isFront ? … : null`, donc la révélation elle-même.
///
/// ## Ce que ces gardes mesurent — et ce qu'elles refusent de mesurer
///
/// 🔴 Lire `tester.widget<ZFlashcardReviewCard>(…).instructionBanner` resterait
/// **vert** si la carte cessait de rendre le bandeau : ce serait mesurer le
/// **passage** du paramètre, pas son **effet**. Chaque garde ci-dessous
/// cherche donc le nœud réellement monté (clé publique de la carte), le texte
/// réellement rendu, la **hauteur réellement mise en page** et les couleurs
/// réellement remises au moteur de rendu (`RenderDecoratedBox`,
/// `RenderPhysicalModel`). Aucune rastérisation : `toImage()` pend sous ce
/// harnais.
///
/// ## Les DEUX sites, jamais un seul
///
/// L'assemblage construit sa carte à deux endroits symétriques : sans
/// affordance de révélation (`cardBuilder` de la vue) et avec
/// (`cardSlotBuilder` de la vue, qui seul câble `revealController`). En
/// oublier un est le défaut classique de cette forme — chaque garde est donc
/// jouée sur les deux, pilotées par [ZStudySessionRevealPolicy].
///
/// ## Inertie ABSOLUE
///
/// Les montages « historiques » n'énoncent **aucun** des cinq paramètres, pas
/// même à sa valeur neutre : les énoncer court-circuiterait le défaut du
/// constructeur, et une injection qui change ce défaut passerait sous une
/// garde restée verte. L'arbre rendu est comparé en **égalité stricte** à un
/// dump capturé sur disque avant le relais.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show RenderDecoratedBox, RenderPhysicalShape;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZGradientSpec, ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcardReviewCard, ZFlashcardType;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_sources.dart' as zsrc;
import '../support/z_study_session_harness.dart';

/// Clé de dégradé que la carte compose à partir du type des cartes du harnais.
const String kTypeKey = 'flashcard.type.openQuestion';

/// Clé explicite, volontairement hors de tout format dérivé du type.
const String kExplicitKey = 'hote.session.cle';

/// Fond de carte demandé par les gardes — choisi hors de toute couleur de
/// rôle du thème de test, pour qu'une égalité ne puisse pas être fortuite.
const Color kDemandedSurface = Color(0xFF2A4B6C);

ZGradientSpec _spec(Color a, Color b) => ZGradientSpec(
      gradient: LinearGradient(colors: <Color>[a, b]),
      onGradient: const Color(0xFF000000),
    );

/// Dégradé rendu pour la clé DÉRIVÉE du type.
final ZGradientSpec kByType = _spec(
  const Color(0xFF102030),
  const Color(0xFF405060),
);

/// Dégradé rendu pour la clé EXPLICITE — distinct, donc jamais égal par
/// coïncidence.
final ZGradientSpec kByExplicitKey = _spec(
  const Color(0xFF708090),
  const Color(0xFFA0B0C0),
);

List<Color> _colorsOf(ZGradientSpec spec) =>
    (spec.gradient as LinearGradient).colors;

/// Résolveur d'hôte : répond aux deux clés, et à rien d'autre.
ZGradientSpec? _resolver(ColorScheme scheme, String key) => switch (key) {
      kTypeKey => kByType,
      kExplicitKey => kByExplicitKey,
      _ => null,
    };

Widget _wrap(Widget child, {bool withResolver = false}) => MaterialApp(
      home: Scaffold(
        body: withResolver
            ? ZcrudScope(gradientResolver: _resolver, child: child)
            : child,
      ),
    );

/// Montage **historique** : aucun des cinq paramètres n'est énoncé.
Widget _historic(ZStudySessionRevealPolicy policy) => _wrap(
      ZStudySessionHost(
        mode: ZReviewMode.list,
        queue: writtenCards(2),
        revealPolicy: policy,
      ),
    );

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

/// Couleur RÉELLEMENT peinte sous la carte (`Material` ⇒ `PhysicalShape`).
Color _cardSurface(WidgetTester tester) => tester
    .renderObject<RenderPhysicalShape>(_inCard(find.byType(PhysicalShape)).first)
    .color;

/// Le dump ordonné des types de widgets montés — égalité STRICTE, jamais
/// `contains` ni un décompte : un nœud intercalé se voit à la position.
List<String> _treeDump(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Le dump de référence, capturé sur disque AVANT le relais.
List<String> _baseline(String name) {
  final File file =
      File('${zsrc.packageRoot().path}/test/support/$name');
  if (!file.existsSync()) {
    throw StateError(
      'Dump de référence introuvable : ${file.path}. La garde d\'inertie ne '
      'mesure plus rien.',
    );
  }
  return file.readAsLinesSync();
}

void main() {
  /// Les deux sites de construction de carte de l'assemblage.
  const Map<String, ZStudySessionRevealPolicy> sites =
      <String, ZStudySessionRevealPolicy>{
    'sans affordance de révélation (`cardBuilder` de la vue)':
        ZStudySessionRevealPolicy.never,
    'avec affordance de révélation (`cardSlotBuilder` de la vue)':
        ZStudySessionRevealPolicy.always,
  };

  group('🎫 pastille de type — relayée jusqu\'au RENDU', () {
    sites.forEach((String site, ZStudySessionRevealPolicy policy) {
      testWidgets('$site : la pastille est rendue, avec le type de la carte',
          (WidgetTester tester) async {
        useTallSurface(tester);
        final List<ZFlashcardType> seen = <ZFlashcardType>[];
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
            questionTypeBadgeBuilder: (BuildContext context, ZFlashcardType t) {
              seen.add(t);
              return Text('pastille:${t.name}');
            },
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey),
          findsWidgets,
          reason: '🔴 le chrome de pastille de la carte n\'est pas monté : le '
              'builder n\'a pas été relayé jusqu\'à la carte',
        );
        expect(find.text('pastille:openQuestion'), findsWidgets);
        expect(seen, isNotEmpty);
        expect(seen.every((ZFlashcardType t) => t == ZFlashcardType.openQuestion),
            isTrue);
      });
    });
  });

  group('📋 bandeau de consigne — relayé jusqu\'au RENDU', () {
    sites.forEach((String site, ZStudySessionRevealPolicy policy) {
      testWidgets('$site : le bandeau est rendu', (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
            instructionBanner: const Text('consigne de session'),
          ),
        ));
        await tester.pumpAndSettle();

        expect(
          find.byKey(ZFlashcardReviewCard.instructionBannerKey),
          findsWidgets,
          reason: '🔴 le slot de bandeau de la carte n\'est pas monté',
        );
        expect(find.text('consigne de session'), findsWidgets);
      });
    });
  });

  group('📏 hauteur de liseré — le SEUL interrupteur du liseré', () {
    sites.forEach((String site, ZStudySessionRevealPolicy policy) {
      testWidgets('$site : sans elle, le seam répond mais AUCUN liseré n\'est '
          'peint', (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
          ),
          withResolver: true,
        ));
        await tester.pumpAndSettle();
        expect(find.byKey(ZFlashcardReviewCard.gradientAccentKey), findsNothing,
            reason: '🔴 le liseré ne doit exister que sur demande explicite');
      });

      testWidgets('$site : avec elle, la hauteur MISE EN PAGE est la hauteur '
          'demandée', (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
            cardAccentHeight: 7,
          ),
          withResolver: true,
        ));
        await tester.pumpAndSettle();

        final Finder accent =
            find.byKey(ZFlashcardReviewCard.gradientAccentKey).first;
        expect(accent, findsOneWidget);
        expect(tester.getSize(accent).height, 7,
            reason: '🔴 la hauteur relayée doit être celle MISE EN PAGE');
        expect(_accentColors(tester), _colorsOf(kByType));
      });
    });
  });

  group('🔑 clé de dégradé explicite — court-circuite la chaîne par type', () {
    sites.forEach((String site, ZStudySessionRevealPolicy policy) {
      testWidgets('$site : c\'est la clé EXPLICITE qui peint',
          (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
            cardAccentHeight: 5,
            cardTypeGradientKey: kExplicitKey,
          ),
          withResolver: true,
        ));
        await tester.pumpAndSettle();

        expect(_accentColors(tester), _colorsOf(kByExplicitKey),
            reason: '🔴 la clé explicite n\'atteint pas la carte : le dégradé '
                'peint est celui dérivé du type');
        // Contre-preuve de non-vacuité : les deux dégradés diffèrent.
        expect(_colorsOf(kByExplicitKey), isNot(_colorsOf(kByType)));
      });
    });
  });

  group('🎨 couleur de fond de carte — relayée jusqu\'à la PEINTURE', () {
    sites.forEach((String site, ZStudySessionRevealPolicy policy) {
      testWidgets('$site : le DÉFAUT peint est le rôle de surface du thème',
          (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
          ),
        ));
        await tester.pumpAndSettle();
        // Non-vacuité de la garde suivante : sans le paramètre, la couleur
        // demandée n'est PAS celle qui est peinte.
        expect(_cardSurface(tester), isNot(kDemandedSurface));
      });

      testWidgets('$site : la surface peinte est celle demandée',
          (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_wrap(
          ZStudySessionHost(
            mode: ZReviewMode.list,
            queue: writtenCards(2),
            revealPolicy: policy,
            cardBackgroundColor: kDemandedSurface,
          ),
        ));
        await tester.pumpAndSettle();
        expect(_cardSurface(tester), kDemandedSurface,
            reason: '🔴 la couleur de fond ne traverse pas jusqu\'au '
                '`RenderPhysicalShape` réellement peint');
      });
    });
  });

  group('🔗 le relais ne passe PAS par `cardBuilder` — la révélation survit',
      () {
    testWidgets(
        'slots fournis ⇒ l\'affordance de révélation est TOUJOURS là, et elle '
        'bascule la face', (WidgetTester tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(
        ZStudySessionHost(
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          revealPolicy: ZStudySessionRevealPolicy.always,
          questionTypeBadgeBuilder: (BuildContext context, ZFlashcardType t) =>
              Text('pastille:\${t.name}'),
          instructionBanner: const Text('consigne de session'),
        ),
      ));
      await tester.pumpAndSettle();

      // La face question est à l'écran, la réponse ne l'est pas.
      expect(find.text('Question c0.'), findsWidgets);
      expect(find.text('r0'), findsNothing);

      // 🔴 Un relais passé par `cardBuilder` retirerait cette action : la vue
      // n'aurait plus de `cardSlotBuilder`, donc plus de `revealController`.
      final Finder reveal = find.byKey(ZStudySessionHost.revealActionKey);
      expect(reveal, findsOneWidget,
          reason: '🔴 l\'affordance de révélation a disparu avec le relais');
      await tester.tap(reveal);
      await tester.pumpAndSettle();

      expect(find.text('r0'), findsWidgets,
          reason: '🔴 la bascule ne parvient plus à la carte de devant');
      // …et les deux slots relayés sont toujours rendus après la bascule.
      expect(find.text('consigne de session'), findsWidgets);
      expect(find.byKey(ZFlashcardReviewCard.questionTypeBadgeKey),
          findsWidgets);
    });
  });

  group('🧊 inertie — aucun paramètre énoncé ⇒ arbre STRICTEMENT identique',
      () {
    const Map<ZStudySessionRevealPolicy, String> baselines =
        <ZStudySessionRevealPolicy, String>{
      ZStudySessionRevealPolicy.auto:
          'z_session_card_tree_before_lotd4_auto.txt',
      ZStudySessionRevealPolicy.always:
          'z_session_card_tree_before_lotd4_always.txt',
    };

    test('les dumps de référence sont non vides et portent bien la carte', () {
      baselines.forEach((_, String name) {
        final List<String> dump = _baseline(name);
        expect(dump, isNotEmpty);
        expect(dump, contains('ZFlashcardReviewCard'),
            reason: '🔴 un dump sans carte ne prouverait rien');
      });
    });

    baselines.forEach((ZStudySessionRevealPolicy policy, String name) {
      testWidgets('${policy.name} : égalité stricte avec $name',
          (WidgetTester tester) async {
        useTallSurface(tester);
        await tester.pumpWidget(_historic(policy));
        await tester.pumpAndSettle();
        expect(_treeDump(tester), _baseline(name),
            reason: '🔴 le relais a ajouté ou retiré un nœud alors qu\'aucun '
                'slot n\'est fourni (AD-4)');
      });
    });
  });
}
