/// **CR-IFFD-57 + CR-IFFD-58** — la carte de flashcard rejoint le rendu de
/// référence, et la liste rend la MÊME carte.
///
/// Ce que ces gardes MESURENT (jamais une intention déclarée) :
/// - la bande est **réellement peinte en dégradé** (`BoxDecoration.gradient`
///   lu sur le décor, valeurs de référence EXACTES par type) ;
/// - le **contraste** de chaque `onGradient` est **recalculé** (luminance
///   WCAG) contre les DEUX extrémités — le premier plan est CHOISI, jamais
///   deviné ; les specs étant constantes, la mesure vaut dans les deux
///   luminosités (vérifié en pompant les deux thèmes) ;
/// - la **préséance** est mesurée les DEUX axes posés ensemble
///   (paramètre > jeton > seam > référence ; `typeColors` vs `colorKey`) ;
/// - la **virtualisation** est prouvée par le CULLING du viewport (widgets
///   construits ≪ total), pas par comptage naïf ;
/// - les **gestes réels** : tap de sélection, tap d'ouverture, drag d'appui
///   long (leçon CR-54 : l'InkWell gagne l'arène — la carte en liste ne
///   déclare AUCUN appui long).
library;

import 'package:flutter/gestures.dart' show kLongPressTimeout, kPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZFolderContentsOrder;

const ZFlashcardListLabels _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Recherche de cartes',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',
  readOnlyBadge: 'Lecture seule',
);

ZFlashcard _card(
  String id, {
  ZFlashcardType type = ZFlashcardType.openQuestion,
  String question = 'Question ?',
}) =>
    ZFlashcard(id: id, question: question, type: type);

Widget _host(
  Widget child, {
  Brightness brightness = Brightness.light,
  ZcrudTheme? tokens,
  ZGradientResolver? gradientResolver,
}) {
  final ThemeData theme = ThemeData(brightness: brightness);
  final Widget app = MaterialApp(
    theme: tokens == null
        ? theme
        : theme.copyWith(extensions: <ThemeExtension<dynamic>>[tokens]),
    home: Scaffold(
      body: Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(width: 360, child: child),
      ),
    ),
  );
  if (gradientResolver == null) return app;
  return ZcrudScope(gradientResolver: gradientResolver, child: app);
}

BoxDecoration _accentDecoration(WidgetTester tester) => tester
    .widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(ZDefaultFlashcardCard.accentKey),
        matching: find.byType(DecoratedBox),
      ),
    )
    .decoration as BoxDecoration;

/// Contraste WCAG 2.x entre deux couleurs (relative luminance recalculée par
/// le SDK — jamais une table écrite à la main).
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Pire contraste d'un premier plan sur les DEUX extrémités d'un dégradé.
double _minContrastOn(ZGradientSpec spec, Color fg) {
  final LinearGradient g = spec.gradient as LinearGradient;
  double worst = double.infinity;
  for (final Color stop in g.colors) {
    final double c = _contrast(stop, fg);
    if (c < worst) worst = c;
  }
  return worst;
}

const ZGradientSpec _injected = ZGradientSpec(
  gradient: LinearGradient(
    begin: AlignmentDirectional.centerStart,
    end: AlignmentDirectional.centerEnd,
    colors: <Color>[Color(0xFF101010), Color(0xFF202020)],
  ),
  onGradient: Color(0xFFFFFFFF),
);

void main() {
  // ==========================================================================
  group('CR-IFFD-57 — la bande est RÉELLEMENT peinte en dégradé, par type', () {
    for (final MapEntry<ZFlashcardType, List<int>> expected
        in <ZFlashcardType, List<int>>{
      ZFlashcardType.multipleChoice: <int>[0xFF667EEA, 0xFF764BA2],
      ZFlashcardType.trueOrFalse: <int>[0xFF11998E, 0xFF38EF7D],
      ZFlashcardType.openQuestion: <int>[0xFF4FACFE, 0xFF00F2FE],
      ZFlashcardType.exercise: <int>[0xFFF093FB, 0xFFF5576C],
    }.entries) {
      testWidgets('${expected.key.name} : dégradé de référence EXACT (mesuré '
          'sur le décor peint)', (tester) async {
        await tester.pumpWidget(
            _host(ZDefaultFlashcardCard(card: _card('a', type: expected.key))));
        await tester.pumpAndSettle();

        final Gradient? painted = _accentDecoration(tester).gradient;
        expect(painted, isA<LinearGradient>(),
            reason: '🔴 « la bande est dégradée » se mesure en GRADIENT '
                'réellement peint (decoration), pas en présence de widget.');
        expect(
          (painted! as LinearGradient).colors,
          <Color>[Color(expected.value[0]), Color(expected.value[1])],
          reason: '🔴 les valeurs de référence (legacy '
              'flashcard_widgets.dart:143-156) sont EXACTES, par type.',
        );
      });
    }

    testWidgets('le point de pied porte le même dégradé ; la tuile d\'icône '
        'et la pastille sont teintées par la PREMIÈRE couleur', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card('a'))));
      await tester.pumpAndSettle();

      final BoxDecoration dot = tester
          .widget<DecoratedBox>(find.descendant(
              of: find.byKey(ZDefaultFlashcardCard.typeDotKey),
              matching: find.byType(DecoratedBox)))
          .decoration as BoxDecoration;
      expect(dot.gradient, _accentDecoration(tester).gradient);

      final BoxDecoration tile = tester
          .widget<DecoratedBox>(find.descendant(
              of: find.byKey(ZDefaultFlashcardCard.iconTileKey),
              matching: find.byType(DecoratedBox)))
          .decoration as BoxDecoration;
      expect(
        tile.color,
        const Color(0xFF4FACFE).withValues(
            alpha: ZFlashcardCardReference.iconTileTintAlpha),
        reason: 'tuile teintée à 15 % de la couleur primaire du type '
            '(openQuestion → #4facfe).',
      );
    });
  });

  // ==========================================================================
  group('CR-IFFD-57 — « non mesuré » n°1 : contraste sur dégradé, MESURÉ', () {
    test('🔴 chaque onGradient de référence est le MEILLEUR des deux candidats '
        'et satisfait le seuil 3,0 (recalculé, jamais recopié)', () {
      const Color white = Color(0xFFFFFFFF);
      const Color black = Color(0xFF000000);
      ZFlashcardCardReference.typeGradients
          .forEach((String type, ZGradientSpec spec) {
        final double chosen = _minContrastOn(spec, spec.onGradient);
        final Color rejectedFg = spec.onGradient == white ? black : white;
        final double rejected = _minContrastOn(spec, rejectedFg);
        expect(chosen, greaterThanOrEqualTo(rejected),
            reason: '🔴 $type : le premier plan est CHOISI par mesure — le '
                'candidat retenu ($chosen) doit battre l\'autre ($rejected).');
        expect(chosen, greaterThanOrEqualTo(3.0),
            reason: '🔴 $type : plancher WCAG 3,0 (texte large/composants) '
                'sur les DEUX extrémités du dégradé — mesuré $chosen.');
      });
    });

    for (final Brightness b in Brightness.values) {
      testWidgets(
          'les dégradés peints sont IDENTIQUES en $b (la mesure vaut dans '
          'les deux luminosités)', (tester) async {
        await tester.pumpWidget(
            _host(ZDefaultFlashcardCard(card: _card('a')), brightness: b));
        await tester.pumpAndSettle();
        expect(_accentDecoration(tester).gradient,
            ZFlashcardCardReference.openQuestionGradient.gradient,
            reason: 'le dégradé de référence ne dépend pas du thème : le '
                'contraste mesuré ci-dessus vaut donc en clair ET en sombre.');
      });
    }
  });

  // ==========================================================================
  group('CR-IFFD-57 — préséance MESURÉE, les deux axes posés ensemble', () {
    testWidgets('paramètre typeColors > jeton de thème > seam > référence',
        (tester) async {
      const ZGradientSpec themed = ZGradientSpec(
        gradient: LinearGradient(
            colors: <Color>[Color(0xFF303030), Color(0xFF404040)]),
        onGradient: Color(0xFFFFFFFF),
      );
      ZGradientSpec? seam(ColorScheme scheme, String key) =>
          key == 'flashcard.type.openQuestion' ? _injected : null;

      // ① Seam SEUL (aucun paramètre, aucun jeton) ⇒ le seam prime la référence.
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card('a')),
        gradientResolver: seam,
      ));
      await tester.pumpAndSettle();
      expect(_accentDecoration(tester).gradient, _injected.gradient,
          reason: '🔴 la couture EXISTANTE (ZcrudScope.gradientResolver) est '
              'RÉUTILISÉE — clé `flashcard.type.<name>`.');

      // ② Jeton de thème ⇒ prime le seam.
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card('a')),
        gradientResolver: seam,
        tokens: const ZcrudTheme(flashcardTypeGradients: <String, ZGradientSpec>{
          'openQuestion': themed,
        }),
      ));
      await tester.pumpAndSettle();
      expect(_accentDecoration(tester).gradient, themed.gradient);

      // ③ Paramètre ⇒ prime le jeton ET le seam.
      const ZGradientSpec param = ZGradientSpec(
        gradient: LinearGradient(
            colors: <Color>[Color(0xFF505050), Color(0xFF606060)]),
        onGradient: Color(0xFFFFFFFF),
      );
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card('a'),
          typeColors: const <String, ZGradientSpec>{'openQuestion': param},
        ),
        gradientResolver: seam,
        tokens: const ZcrudTheme(flashcardTypeGradients: <String, ZGradientSpec>{
          'openQuestion': themed,
        }),
      ));
      await tester.pumpAndSettle();
      expect(_accentDecoration(tester).gradient, param.gradient);
    });

    testWidgets('colorKey EXPLICITE prime les DÉFAUTS de l\'axe type (bande '
        'UNIE — rendu v0.42-v0.45 préservé)', (tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(card: _card('a'), colorKey: 'tertiary'),
        tokens: const ZcrudTheme(flashcardTypeGradients: <String, ZGradientSpec>{
          'openQuestion': _injected,
        }),
      ));
      await tester.pumpAndSettle();
      final BoxDecoration deco = _accentDecoration(tester);
      expect(deco.gradient, isNull,
          reason: '🔴 un choix d\'IDENTITÉ posé par l\'hôte n\'est jamais '
              'écrasé par un défaut (jeton compris).');
      expect(deco.color, isNotNull);
    });

    testWidgets('…mais une entrée typeColors EXPLICITE pour le type bat même '
        'un colorKey explicite (paramètre SPÉCIFIQUE à la surface)',
        (tester) async {
      await tester.pumpWidget(_host(
        ZDefaultFlashcardCard(
          card: _card('a'),
          colorKey: 'tertiary',
          typeColors: const <String, ZGradientSpec>{'openQuestion': _injected},
        ),
      ));
      await tester.pumpAndSettle();
      expect(_accentDecoration(tester).gradient, _injected.gradient);
    });

    testWidgets('AD-10 — type SANS dégradé de référence (`fillBlank`, hors du '
        'legacy à 4 types) ⇒ repli TOTAL sur l\'accent uni dérivé, jamais une '
        'carte sans accent', (tester) async {
      // MESURÉ à l'écriture de la garde : le modèle porte SIX types
      // (`fillBlank`/`shortAnswer` en plus des 4 du legacy) — la référence
      // auditée ne peut couvrir QUE les 4 paires mesurées chez IFFD (inventer
      // des hex hors legacy violerait l'audit de l'exception FR-26). Les deux
      // types restants suivent le chemin AD-10 : accent UNI dérivé de la clé
      // stable (`type.name`), réellement peint.
      const List<String> legacy = <String>[
        'multipleChoice', 'trueOrFalse', 'openQuestion', 'exercise',
      ];
      expect(ZFlashcardCardReference.typeGradients.keys.toSet(),
          legacy.toSet(),
          reason: '🔴 la référence porte EXACTEMENT les 4 paires du legacy — '
              'ni plus (hex inventé), ni moins (type legacy oublié).');

      await tester.pumpWidget(_host(ZDefaultFlashcardCard(
          card: _card('a', type: ZFlashcardType.fillBlank))));
      await tester.pumpAndSettle();
      final BoxDecoration deco = _accentDecoration(tester);
      expect(deco.gradient, isNull);
      expect(deco.color, isNotNull,
          reason: '🔴 repli TOTAL : la bande reste PEINTE (accent uni dérivé '
              'de la clé stable), jamais une carte sans accent.');
    });
  });

  // ==========================================================================
  group('CR-IFFD-57 — chrome de référence (complément owner : hauteur fixe)',
      () {
    testWidgets('hauteur FIXE 200 par défaut ; `height: null` ⇒ intrinsèque',
        (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card('a'))));
      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byType(ZDefaultFlashcardCard)).height,
          ZFlashcardCardReference.cardHeight,
          reason: '🔴 legacy `SizedBox(height: 200)` : la hauteur fixe est le '
              'défaut — c\'est elle qui rend grille et rail réguliers.');

      await tester.pumpWidget(_host(
          ZDefaultFlashcardCard(card: _card('a'), height: null)));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ZDefaultFlashcardCard)).height,
          lessThan(ZFlashcardCardReference.cardHeight),
          reason: 'hauteur intrinsèque atteignable par `height: null` '
              'explicite (carte courte ⇒ moins de 200 dp).');
    });

    testWidgets('rayon 12, fond scaffold, liseré `outline` (rôles, pas de hex '
        'hors référence)', (tester) async {
      await tester.pumpWidget(_host(ZDefaultFlashcardCard(card: _card('a'))));
      await tester.pumpAndSettle();
      final Card card = tester.widget<Card>(find.byType(Card));
      final ThemeData theme =
          Theme.of(tester.element(find.byType(ZDefaultFlashcardCard)));
      expect(card.color, theme.scaffoldBackgroundColor);
      final RoundedRectangleBorder shape =
          card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius,
          BorderRadius.all(ZFlashcardCardReference.cardRadius));
      expect(shape.side.color, theme.colorScheme.outline,
          reason: 'la « bordure grise » legacy est rendue par le RÔLE '
              '`outline` (dérivable ⇒ jamais un hex, CR-48).');
    });
  });

  // ==========================================================================
  group('CR-IFFD-58 — la liste rend la MÊME carte', () {
    testWidgets('🔴 par défaut : ZDefaultFlashcardCard (« une carte, toutes '
        'les surfaces »)', (tester) async {
      await tester.pumpWidget(_host(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a'), _card('b')],
        labels: _labels,
      )));
      await tester.pump();
      expect(find.byType(ZDefaultFlashcardCard), findsNWidgets(2));
    });

    testWidgets('itemStyle: tile ⇒ la tuile compacte est CONSERVÉE (mode '
        'explicite, jamais un remplacement sec)', (tester) async {
      await tester.pumpWidget(_host(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a')],
        labels: _labels,
        itemStyle: ZFlashcardListItemStyle.tile,
      )));
      await tester.pump();
      expect(find.byType(ZDefaultFlashcardCard), findsNothing);
      expect(find.text('Question ?'), findsOneWidget);
    });

    testWidgets('🔴 NEUTRALITÉ : un hôte qui passait contentBuilder obtient '
        'EXACTEMENT ce qu\'il obtenait (la tuile + son slot)', (tester) async {
      const Key slotKey = ValueKey<String>('hostSlot');
      await tester.pumpWidget(_host(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a')],
        labels: _labels,
        contentBuilder: (BuildContext context, String text) =>
            Text(text, key: slotKey, maxLines: 1),
      )));
      await tester.pump();
      expect(find.byType(ZDefaultFlashcardCard), findsNothing,
          reason: '🔴 le slot AD-40 est un contrat de la TUILE : le fournir '
              'replie sur elle — rendu STRICTEMENT inchangé pour cet hôte.');
      expect(find.byKey(slotKey), findsOneWidget,
          reason: 'le slot de l\'hôte est bien CONSOMMÉ.');
    });

    testWidgets('itemStyle: card + contentBuilder ⇒ REFUSÉ (jamais un slot '
        'silencieusement inerte — AD-4)', (tester) async {
      expect(
        () => ZFlashcardListView(
          cards: const <ZFlashcard>[],
          labels: _labels,
          itemStyle: ZFlashcardListItemStyle.card,
          contentBuilder: (BuildContext c, String t) => Text(t),
        ),
        throwsAssertionError,
      );
    });

    testWidgets('les options de la carte sont RELAYÉES (typeLabels, '
        'typeColors)', (tester) async {
      await tester.pumpWidget(_host(ZFlashcardListView(
        cards: <ZFlashcard>[_card('a')],
        labels: _labels,
        typeLabels: const <String, String>{'openQuestion': 'Question ouverte'},
        typeColors: const <String, ZGradientSpec>{'openQuestion': _injected},
      )));
      await tester.pump();
      expect(find.text('Question ouverte'), findsOneWidget);
      expect(_accentDecoration(tester).gradient, _injected.gradient);
    });
  });

  // ==========================================================================
  group('CR-IFFD-58 — « non mesuré » n°1 : coût en liste LONGUE (culling)',
      () {
    Future<int> builtCount(
      WidgetTester tester, {
      required ZFlashcardListItemStyle style,
    }) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZFlashcardListView(
            cards: List<ZFlashcard>.generate(
                300, (int i) => _card('c$i', question: 'Q$i')),
            labels: _labels,
            itemStyle: style,
          ),
        ),
      ));
      await tester.pump();
      // Sonde de MÉCANISME (culling du viewport) : les items CONSTRUITS,
      // jamais un comptage d'itemCount (piège déjà payé).
      return find.byType(ZItemActionsMenu).evaluate().length;
    }

    testWidgets('🔴 300 cartes en mode CARTE : seul le viewport est construit',
        (tester) async {
      final int cards =
          await builtCount(tester, style: ZFlashcardListItemStyle.card);
      expect(cards, greaterThan(0), reason: 'sonde cassée : rien de construit');
      expect(cards, lessThan(60),
          reason: '🔴 $cards/300 items construits — sans culling, la carte '
              'complète (plus lourde que la tuile) serait matérialisée 300 '
              'fois à chaque frappe.');
    });

    testWidgets('comparaison tuile vs carte : MÊME mécanisme, coût borné du '
        'même ordre', (tester) async {
      final int tiles =
          await builtCount(tester, style: ZFlashcardListItemStyle.tile);
      final int cards =
          await builtCount(tester, style: ZFlashcardListItemStyle.card);
      expect(tiles, greaterThan(0));
      expect(cards, greaterThan(0));
      // La carte (200 dp) est plus HAUTE que la tuile (180 dp) : à viewport
      // égal elle ne peut pas construire PLUS d'items. Le culling borne les
      // deux — c'est la propriété, pas un chiffre magique.
      expect(cards, lessThanOrEqualTo(tiles),
          reason: 'mesuré : $cards cartes vs $tiles tuiles construites pour '
              '300 items — le viewport gouverne, pas le total.');
    });
  });

  // ==========================================================================
  group('CR-IFFD-58 — « non mesuré » n°2 : gestes RÉELS (sélection, drag)',
      () {
    testWidgets('🔴 tap de sélection (case) + tap d\'ouverture (carte) '
        'coexistent en mode carte', (tester) async {
      final List<String> opened = <String>[];
      final ZListSelectionController controller =
          ZListSelectionController(mode: ZListSelectionMode.multiple);
      addTearDown(controller.dispose);
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZFlashcardListView(
            cards: <ZFlashcard>[_card('a', question: 'Alpha')],
            labels: _labels,
            onOpen: (ZFlashcard c) => opened.add(c.id!),
            selection: ZFlashcardListSelection(
              controller: controller,
              checkboxSemanticLabel: (ZFlashcard c, bool s) =>
                  'Sélection ${c.id}',
              countLabelBuilder: (int n) => '$n sélectionnées',
            ),
          ),
        ),
      ));
      await tester.pump();

      // Geste RÉEL n°1 : tap sur la case ⇒ sélection, PAS d'ouverture.
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(controller.isSelected('a'), isTrue,
          reason: '🔴 le tap de sélection doit atteindre la case posée À CÔTÉ '
              'de la carte (jamais avalé par l\'InkWell de la carte).');
      expect(opened, isEmpty);

      // Geste RÉEL n°2 : tap sur la carte ⇒ ouverture.
      await tester.tap(find.byType(ZDefaultFlashcardCard));
      await tester.pump();
      expect(opened, <String>['a']);
    });

    testWidgets('🔴 drag d\'appui long RÉEL en mode carte : l\'ordre bouge, '
        'l\'ouverture ne part PAS (leçon CR-54)', (tester) async {
      ZFolderContentsOrder? persisted;
      final List<String> opened = <String>[];
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZFlashcardListView(
            cards: <ZFlashcard>[
              _card('a', question: 'Alpha'),
              _card('b', question: 'Beta'),
              _card('c', question: 'Gamma'),
            ],
            labels: _labels,
            sortMode: ZFlashcardSortMode.manual,
            order: const ZFolderContentsOrder(folderId: 'f'),
            onOrderChanged: (ZFolderContentsOrder o) => persisted = o,
            onOpen: (ZFlashcard c) => opened.add(c.id!),
          ),
        ),
      ));
      await tester.pump();

      // GESTE réel : appui long (déclencheur du ReorderableDelayedDrag du
      // SDK sur mobile) puis glissement vers le bas. La carte ne déclare
      // AUCUN onLongPress (mesure CR-54 : l'InkWell gagnerait l'arène et le
      // drag ne partirait jamais) — le listener de réordonnancement est donc
      // SEUL dans l'arène d'appui long.
      final Offset from = tester.getCenter(find.text('Alpha'));
      final TestGesture gesture = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + kPressTimeout);
      // Déplacement INCRÉMENTAL (le recognizer de drag consomme le mouvement
      // par étapes ; un saut unique peut être avalé par le slop initial).
      for (int i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 50));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(persisted, isNotNull,
          reason: '🔴 le drag RÉEL doit démarrer et persister — pas seulement '
              'le callback SDK invoqué à la main.');
      expect(persisted!.orderFor(zFlashcardsSectionKey()).first, isNot('a'),
          reason: '« Alpha » a été glissée vers le bas : elle n\'est plus '
              'première.');
      expect(opened, isEmpty,
          reason: '🔴 un appui long qui OUVRIRAIT la carte prouverait que '
              'l\'InkWell a volé l\'arène (leçon CR-54).');
    });
  });
}
