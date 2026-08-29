/// 🎯 `ZSessionCardSwiper.onSwipeDirection` — seam de **DIRECTION**, pas de
/// notation.
///
/// L'invariant AD-33 (« le swipe navigue, il ne note JAMAIS ») est **tenu et
/// non amendé** : il est défendu par `z_swipe_never_grades_test.dart`, qui
/// bannit tout symbole de notation du fichier du swiper et reste inchangé à
/// l'octet. Ce que le socle ajoute ici est strictement en amont de la
/// décision : *un geste a eu lieu, vers `start` ou vers `end`, sur telle
/// carte*. Ce qu'on en fait — noter, marquer, passer, rien — appartient à
/// l'hôte, chez lui.
///
/// Quatre gardes, chacune rougie par une injection R3 dans `lib/` (le marqueur
/// d'injection n'est volontairement écrit nulle part dans l'arbre : un balayage
/// de résidus doit pouvoir le chercher sans faux positif) :
///  1. **INERTIE ABSOLUE** — sans le seam, l'arbre rendu ET la suite des index
///     émis sont ceux d'AVANT le lot. L'empreinte de référence a été capturée
///     sur la source pré-lot (sha256
///     `be15af2b842b91060c89edc9018dfe802d9fb4b4e9f6baa91b5c10ec74055dbc`) et
///     est comparée en **égalité stricte** — jamais un `contains`, jamais un
///     `<=` ;
///  2. **ORDRE** — `onSwipeDirection(i, …)` précède `onIndexChanged(i + 1)`,
///     vérifié par un **journal unique** (deux listes séparées ne diraient
///     rien de l'ordre), et l'index passé est celui de la carte CHASSÉE ;
///  3. **RTL** — le même geste PHYSIQUE donne la direction LOGIQUE opposée.
///     Anti-tautologie : la valeur LTR du même scénario est mesurée dans le
///     même test et exigée DIFFÉRENTE ;
///  4. **GESTE SEULEMENT** — une avance programmatique (commande
///     `ZIndexController`, bouton accessible « carte suivante ») n'émet pas.
///     Anti-tautologie : le MÊME espion est appelé par un vrai geste dans le
///     MÊME test — sans ce témoin positif, « 0 appel » ne prouverait rien.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

Widget _card(BuildContext context, ZSessionItem item) =>
    Center(child: Text(item.flashcardId));

/// Empreinte STRICTE du sous-arbre du swiper : le type de chaque widget, dans
/// l'ordre de parcours, racine comprise.
///
/// Bornée au sous-arbre de `ZSessionCardSwiper` **délibérément** : l'échafaudage
/// de `MaterialApp` change au gré des versions de Flutter, et l'y inclure
/// ferait rougir cette garde pour une raison qui n'est pas la nôtre. Ce qui est
/// mesuré ici est ce que ce widget rend, et rien d'autre.
List<String> _fingerprint(WidgetTester tester) => tester
    .widgetList(
      find.descendant(
        of: find.byType(ZSessionCardSwiper),
        matching: find.byWidgetPredicate((Widget _) => true),
        matchRoot: true,
      ),
    )
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// 🔒 Empreinte de référence — **capturée sur la source d'AVANT ce lot**, par
/// un probe jouant exactement le scénario de la garde d'inertie, puis figée
/// ici. Ce n'est donc pas « ce que le code rend aujourd'hui » constaté après
/// coup : c'est l'état antérieur, gelé.
const String _kFrozenTree =
    'ZSessionCardSwiper,Column,Expanded,CardSwiper,LayoutBuilder,Padding,'
    'LayoutBuilder,Stack,Positioned,Transform,ConstrainedBox,Stack,Center,'
    'Text,RichText,ZSwipeEmotionIndicator,SizedBox,Positioned,GestureDetector,'
    'RawGestureDetector,_GestureSemantics,Listener,Transform,ConstrainedBox,'
    'Stack,Center,Text,RichText,ZSwipeEmotionIndicator,SizedBox,SizedBox,Row,'
    'Expanded,ValueListenableBuilder<int>,ZSessionProgressIndicator,Semantics,'
    'Wrap,_Dot,Container,ConstrainedBox,DecoratedBox,Padding,_Dot,Container,'
    'ConstrainedBox,DecoratedBox,Padding,_Dot,Container,ConstrainedBox,'
    'DecoratedBox,Padding,_Dot,Container,ConstrainedBox,DecoratedBox,Padding,'
    '_NavButton,Semantics,ConstrainedBox,Material,'
    'ClipPath,_ShapeBorderPaint,CustomPaint,'
    'NotificationListener<LayoutChangedNotification>,_InkFeatures,'
    'AnimatedDefaultTextStyle,DefaultTextStyle,InkWell,_InkResponseStateWidget,'
    '_ParentInkResponseProvider,Actions,_ActionsScope,Focus,'
    '_FocusInheritedScope,Semantics,MouseRegion,Builder,DefaultSelectionStyle,'
    'Semantics,GestureDetector,RawGestureDetector,Listener,Icon,Semantics,'
    'ExcludeSemantics,SizedBox,Center,RichText';

/// Hôte conforme au patron `ZDisplayState` : le contrôleur est possédé par un
/// `State` (champ), jamais créé dans `build` — c'est ce que le mixin impose.
class _ControllerHost extends StatefulWidget {
  const _ControllerHost({
    required this.onIndexChanged,
    required this.onSwipeDirection,
  });

  final ValueChanged<int> onIndexChanged;
  final void Function(int, ZSwipeDirection) onSwipeDirection;

  @override
  State<_ControllerHost> createState() => _ControllerHostState();
}

class _ControllerHostState extends State<_ControllerHost>
    with ZDisplayStateOwnerMixin<_ControllerHost> {
  late final ZIndexController ctrl =
      ZIndexController(owner: this, debugLabel: 'test.currentCard');

  @override
  Widget build(BuildContext context) => ZSessionCardSwiper(
        queue: _queue(4),
        cardBuilder: _card,
        passThreshold: 3,
        indexController: ctrl,
        onIndexChanged: widget.onIndexChanged,
        onSwipeDirection: widget.onSwipeDirection,
      );
}

void main() {
  group('🎯 G1 — INERTIE ABSOLUE : sans le seam, rien n\'a bougé', () {
    testWidgets(
        '🔴 le paramètre OMIS laisse l\'arbre rendu ET la suite des index '
        'émis STRICTEMENT identiques à l\'état d\'avant le seam', (tester) async {
      final emitted = <int>[];
      var ends = 0;

      await tester.pumpWidget(
        wrapApp(
          // 🔒 Le régime historique est obtenu en N'ÉCRIVANT PAS le paramètre —
          // jamais en passant `null` explicitement : c'est bien l'ABSENCE
          // d'argument que l'inertie doit mesurer.
          ZSessionCardSwiper(
            // 🔒 QUATRE cartes, pas trois : avec trois, le bouton accessible
            // tombait sur la DERNIÈRE carte, qui n'émet aucun index — la
            // garde était alors aveugle à une avance programmatique perdue
            // (mesuré : l'injection prescrite restait VERTE). L'ancrage exige
            // qu'il reste une carte APRÈS celle que le bouton chasse.
            queue: _queue(4),
            cardBuilder: _card,
            passThreshold: 3,
            onIndexChanged: emitted.add,
            onStackEnd: () => ends++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_fingerprint(tester), hasLength(89),
          reason: 'contre-preuve : le scan doit réellement voir l\'arbre');
      expect(
        _fingerprint(tester).join(','),
        _kFrozenTree,
        reason: '🔴 l\'arbre au montage diffère de celui d\'AVANT le seam : le '
            'paramètre additif a changé le rendu de l\'hôte PASSIF',
      );

      await tester.drag(find.text('f0'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(
        _fingerprint(tester).join(','),
        _kFrozenTree,
        reason: '🔴 l\'arbre après un swipe diffère de celui d\'AVANT le seam',
      );

      await tester.drag(find.text('f1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      // Bouton accessible sur f2 — il RESTE une carte derrière, donc cette
      // avance-là émet réellement un index (c'est ce que la garde mesure).
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      // Bouton accessible sur la dernière carte : n'émet pas d'index, ferme
      // la pile.
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(emitted, <int>[1, 2, 3],
          reason: '🔴 la suite des index émis a changé alors que le seam est '
              'ABSENT (geste droite, geste gauche, bouton accessible)');
      expect(ends, 1, reason: '🔴 la fin de pile n\'est plus émise une fois');
    });
  });

  group('🎯 G2 — ORDRE : la direction précède l\'avance', () {
    testWidgets(
        '🔴 un geste vers `end` donne `(indexChassé, end)` UNE fois, PUIS '
        '`onIndexChanged(index + 1)` — l\'ordre est vérifié par un journal '
        'unique', (tester) async {
      // 🔒 UN SEUL journal, partagé : deux listes séparées prouveraient les
      // deux appels sans rien dire de leur ORDRE — or l'ordre est le contrat.
      final log = <String>[];

      await tester.pumpWidget(
        wrapApp(
          ZSessionCardSwiper(
            queue: _queue(4),
            cardBuilder: _card,
            passThreshold: 3,
            onIndexChanged: (int i) => log.add('idx:$i'),
            onSwipeDirection: (int i, ZSwipeDirection d) =>
                log.add('dir:$i:${d.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Geste vers la DROITE physique, sous `ltr` (l'enveloppe `MaterialApp`
      // du harnais) : direction logique `end`.
      await tester.drag(find.text('f0'), const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(
        log,
        <String>['dir:0:end', 'idx:1'],
        reason: '🔴 attendu : la direction sur la carte CHASSÉE (0), PUIS '
            'l\'avance (1). Un `dir:1:…` signalerait l\'index de la carte '
            'SUIVANTE ; un ordre inversé priverait l\'hôte de la possibilité '
            'd\'agir sur la carte sortante avant que la pile ne bouge',
      );

      // Geste vers la GAUCHE physique : direction logique `start` — et
      // l'avance a lieu tout de même (les deux directions avancent, AD-33).
      await tester.drag(find.text('f1'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(log, <String>['dir:0:end', 'idx:1', 'dir:1:start', 'idx:2']);

      // Une seule émission par geste : un doublon ferait noter deux fois chez
      // un hôte qui dérive une décision de la direction.
      expect(log.where((String e) => e.startsWith('dir:')), hasLength(2));
    });

    testWidgets(
        '🔴 la DERNIÈRE carte émet sa direction aussi — sinon un hôte qui '
        'dérive une décision du geste perdrait silencieusement la dernière '
        'carte de chaque session', (tester) async {
      final log = <String>[];
      var ends = 0;

      await tester.pumpWidget(
        wrapApp(
          ZSessionCardSwiper(
            queue: _queue(1),
            cardBuilder: _card,
            passThreshold: 3,
            onIndexChanged: (int i) => log.add('idx:$i'),
            onStackEnd: () => ends++,
            onSwipeDirection: (int i, ZSwipeDirection d) =>
                log.add('dir:$i:${d.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('f0'), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Aucun `idx:` : il n'y a pas de carte suivante — mais le GESTE, lui, a
      // bien eu lieu.
      expect(log, <String>['dir:0:end']);
      expect(ends, 1, reason: 'la fin de pile reste émise');
    });
  });

  group('🎯 G3 — RTL : la direction est LOGIQUE, pas physique (AD-13)', () {
    /// Joue le MÊME geste physique (doigt vers la droite) sous une
    /// [TextDirection] donnée et rend la direction logique observée.
    Future<String> directionUnder(
      WidgetTester tester,
      TextDirection textDirection,
    ) async {
      final seen = <String>[];
      await tester.pumpWidget(
        wrapApp(
          Directionality(
            textDirection: textDirection,
            child: ZSessionCardSwiper(
              // 🔒 Clé distincte par régime : sans elle, le second `pumpWidget`
              // RÉUTILISE le `State` du premier (même type, même position) et
              // la pile reprend là où le geste précédent l'avait laissée — le
              // second scénario ne partirait pas de la carte 0.
              key: ValueKey<String>('swiper_${textDirection.name}'),
              queue: _queue(3),
              cardBuilder: _card,
              passThreshold: 3,
              onSwipeDirection: (int i, ZSwipeDirection d) => seen.add(d.name),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.text('f0'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(seen, hasLength(1), reason: 'un geste, une émission');
      return seen.single;
    }

    testWidgets(
        '🔴 le MÊME geste physique donne la direction logique INVERSE sous '
        '`rtl` — et les deux régimes sont mesurés dans le MÊME test, exigés '
        'DIFFÉRENTS (anti-tautologie)', (tester) async {
      final String ltr = await directionUnder(tester, TextDirection.ltr);
      final String rtl = await directionUnder(tester, TextDirection.rtl);

      expect(ltr, 'end',
          reason: '🔴 sous `ltr`, le doigt vers la droite va vers la FIN de '
              'la ligne');
      expect(rtl, 'start',
          reason: '🔴 sous `rtl`, le MÊME geste physique va vers le DÉBUT de '
              'la ligne — une direction physique relayée telle quelle '
              'donnerait `end` dans les deux cas');
      // 🔒 Sans cette assertion, une implémentation qui renverrait une
      // constante resterait verte sur l\'un des deux régimes.
      expect(ltr, isNot(rtl),
          reason: '🔴 la direction ne dépend pas du sens de lecture : le seam '
              'est physique, pas logique');
    });
  });

  group('🎯 G4 — GESTE SEULEMENT : une avance programmatique n\'émet pas', () {
    testWidgets(
        '🔴 `ZIndexController` (commande de l\'hôte) et bouton accessible '
        '« carte suivante » ⇒ 0 appel — ET le MÊME espion répond à un vrai '
        'geste dans le MÊME test (témoin positif)', (tester) async {
      final seen = <String>[];
      final emitted = <int>[];

      await tester.pumpWidget(
        wrapApp(
          _ControllerHost(
            onIndexChanged: emitted.add,
            onSwipeDirection: (int i, ZSwipeDirection d) =>
                seen.add('$i:${d.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ZIndexController controller =
          tester.state<_ControllerHostState>(find.byType(_ControllerHost)).ctrl;

      // (1) Saut direct commandé par l'hôte (l'équivalent d'un `jumpTo` : le
      // contrôleur EST la source de vérité, on lui écrit sa valeur).
      controller.value = 2;
      await tester.pumpAndSettle();
      expect(emitted, <int>[2],
          reason: 'la commande DÉPLACE bien la pile — sans quoi « 0 appel » '
              'ne mesurerait qu\'un paramètre inerte');
      expect(seen, isEmpty,
          reason: '🔴 une commande d\'index n\'est pas un geste : elle '
              'n\'exprime aucune direction');

      // (2) Bouton accessible : avance réelle, toujours aucune direction.
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(emitted, <int>[2, 3],
          reason: 'le bouton accessible avance réellement');
      expect(
        seen,
        isEmpty,
        reason: '🔴 le bouton accessible passe par `CardSwiperController.swipe`'
            ' avec une direction ARBITRAIRE : la relayer attribuerait à '
            'l\'utilisateur de lecteur d\'écran une intention qu\'il n\'a pas '
            'formulée — et lui seul la subirait',
      );

      // (3) 🔴 TÉMOIN POSITIF — sans lui, (1) et (2) ne prouvent RIEN : un
      // seam jamais branché resterait vert.
      await tester.drag(find.text('f3'), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(
        seen,
        <String>['3:end'],
        reason: '🔴 l\'espion ne sait PAS être appelé ⇒ les « 0 appel » '
            'ci-dessus sont des preuves VIDES',
      );
    });

    testWidgets(
        '🔴 le drapeau programmatique est CONSOMMÉ : le geste qui suit une '
        'avance par bouton émet bien, lui', (tester) async {
      final seen = <String>[];

      await tester.pumpWidget(
        wrapApp(
          ZSessionCardSwiper(
            queue: _queue(4),
            cardBuilder: _card,
            passThreshold: 3,
            onSwipeDirection: (int i, ZSwipeDirection d) =>
                seen.add('$i:${d.name}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(seen, isEmpty);

      // Un drapeau laissé armé ferait taire CE geste-ci — le défaut serait
      // invisible sur un scénario qui ne mêle pas les deux origines.
      await tester.drag(find.text('f1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(seen, <String>['1:start'],
          reason: '🔴 le geste suivant une avance programmatique a été avalé');
    });
  });
}
