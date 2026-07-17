/// 🔴 AC11 (SU-4) — **les asserts de `CardSwiper` sont des CRASH RÉELS**, pas des
/// cas théoriques (AD-10 : « jamais d'exception, repli défini »).
///
/// Lus sur disque (`card_swiper.dart`, ctor) :
/// ```dart
/// assert(numberOfCardsDisplayed >= 1 && numberOfCardsDisplayed <= cardsCount)  // défaut = 2
/// assert(initialIndex >= 0 && initialIndex < cardsCount)
/// ```
/// - **file vide** (`cardsCount = 0`) ⇒ **les DEUX** lèvent ⇒ `ZSessionCardSwiper`
///   ne doit PAS construire `CardSwiper` : repli d'état vide.
/// - **file d'UNE carte** ⇒ `numberOfCardsDisplayed` (défaut **2**) `> 1` ⇒
///   **assert ⇒ crash sur une session parfaitement normale**. D'où
///   `numberOfCardsDisplayed: math.min(2, queue.length)`.
/// - **`isLoop`** (défaut `true`) ⇒ la session **ne se termine jamais**.
///
/// 🔴 **Anti-défaut (leçon su-3 : « branche de repli JAMAIS atteinte »)** : ces
/// tests **ATTEIGNENT** le repli et l'**OBSERVENT** — constater l'absence
/// d'exception ne prouverait pas que le repli existe (un `SizedBox.shrink()`
/// muet passerait tout aussi bien).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

Widget _card(BuildContext context, ZSessionItem item) => Center(
      key: ValueKey<String>('card_${item.flashcardId}'),
      child: Text(item.flashcardId),
    );

void main() {
  group('🔴 AC11 — file VIDE : repli rendu, ZÉRO exception', () {
    testWidgets('le repli par DÉFAUT est atteint et OBSERVÉ', (tester) async {
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: const <ZSessionItem>[],
              cardBuilder: _card,
              passThreshold: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // (1) aucune exception — `cardsCount: 0` ferait lever DEUX asserts.
      expect(tester.takeException(), isNull);
      // (2) 🔴 le repli est RÉELLEMENT rendu (on l'observe, on ne le suppose pas).
      expect(
        find.byKey(ZSessionCardSwiper.emptyKey),
        findsOneWidget,
        reason: 'la branche de repli n\'est pas atteinte : « aucune exception » '
            'ne prouve rien si rien n\'est rendu (leçon su-3)',
      );
    });

    testWidgets('le repli INJECTÉ (`emptyBuilder`) a la priorité',
        (tester) async {
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: const <ZSessionItem>[],
              cardBuilder: _card,
              passThreshold: 3,
              emptyBuilder: (context) =>
                  const Center(key: ValueKey<String>('customEmpty')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey<String>('customEmpty')), findsOneWidget);
      expect(find.byKey(ZSessionCardSwiper.emptyKey), findsNothing);
    });
  });

  group('🔴 AC11 — file d\'UNE carte : le défaut du paquet CRASHERAIT', () {
    testWidgets(
        'montée sans exception (défaut `numberOfCardsDisplayed: 2` > 1 ⇒ assert)',
        (tester) async {
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: const <ZSessionItem>[
                ZSessionItem(flashcardId: 'f0', folderId: 'd1'),
              ],
              cardBuilder: _card,
              passThreshold: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '🔴 `numberOfCardsDisplayed: math.min(2, queue.length)` est '
            'OBLIGATOIRE : au défaut `2`, une session d\'UNE carte — cas '
            'parfaitement normal — lève un AssertionError au ctor',
      );
      expect(find.byKey(const ValueKey<String>('card_f0')), findsOneWidget);
    });

    testWidgets('un swipe sur la carte unique termine la pile', (tester) async {
      var ends = 0;
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: const <ZSessionItem>[
                ZSessionItem(flashcardId: 'f0', folderId: 'd1'),
              ],
              cardBuilder: _card,
              passThreshold: 3,
              onStackEnd: () => ends++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('card_f0')), findsOneWidget);

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(ends, 1, reason: 'la fin de pile doit être notifiée');
      expect(tester.takeException(), isNull);

      // 🔴 **`onEnd` NE PROUVE PAS `isLoop: false`** — trou de test mesuré. Le
      // paquet appelle `onEnd` dès que `_currentIndex == cardsCount - 1`
      // (`_handleCompleteSwipe`), **indépendamment d'`isLoop`** : l'injection
      // R3-I16c (`isLoop: true`) laissait donc `ends == 1` et le test **VERT**,
      // alors que la session BOUCLAIT pour de bon.
      //
      // Ce qui distingue réellement les deux réglages, c'est ce qu'il RESTE à
      // l'écran : à `false`, `_nextIndex` devient `null` ⇒ plus aucune carte ; à
      // `true`, l'index repasse à 0 ⇒ **la carte réapparaît et la session ne se
      // termine JAMAIS**. C'est cela qu'on observe.
      expect(
        find.byKey(const ValueKey<String>('card_f0')),
        findsNothing,
        reason: '🔴 `isLoop: false` : la carte est REVENUE après le dernier '
            'swipe — la pile boucle sur elle-même et l\'apprenant ne peut '
            'jamais finir sa session',
      );
    });
  });

  group('🔴 AC11 — `isLoop: false` : la pile ne BOUCLE jamais', () {
    testWidgets(
        '🔴 après la dernière carte, la PREMIÈRE ne réapparaît pas (session '
        'terminable)', (tester) async {
      var ends = 0;
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: const <ZSessionItem>[
                ZSessionItem(flashcardId: 'f0', folderId: 'd1'),
                ZSessionItem(flashcardId: 'f1', folderId: 'd1'),
              ],
              cardBuilder: _card,
              passThreshold: 3,
              onStackEnd: () => ends++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // On parcourt la file ENTIÈREMENT.
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('card_f1')), findsOneWidget);

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(ends, 1);
      // 🎯 Le discriminant RÉEL d'`isLoop` (cf. note ci-dessus).
      expect(
        find.byKey(const ValueKey<String>('card_f0')),
        findsNothing,
        reason: '🔴 la file a rebouclé sur sa première carte : au défaut '
            '`isLoop: true`, une session d\'étude est INFINIE',
      );
      expect(find.byKey(const ValueKey<String>('card_f1')), findsNothing);
    });
  });

  group(
      '🔴 AC11/AD-10 (D1) — la file MUTE sous la pile : l\'index du paquet ne '
      'doit JAMAIS lui survivre', () {
    // 🔴 **CRASH RÉEL sur le chemin NOMINAL, mesuré.** `CardSwiper` porte sa
    // propre source de vérité d'index (`_undoableIndex`), posée uniquement en
    // `initState` et que son `didUpdateWidget` ne réinitialise jamais. Construit
    // **sans `key`**, son `Element` était réutilisé au changement de file : son
    // index **survivait** à la file qu'il indexait, pendant que le
    // `didUpdateWidget` de zcrud remettait `_index = 0` de son côté.
    //
    // ⚠️ **Ce n'est pas un cas limite** : `ZStudySessionEngine.reduceGrade` fait
    // `queue.removeAt(cursor)` et **ne réinsère PAS sur une réussite**
    // (`z_study_session_engine.dart:79`) ⇒ **toute réussite RÉTRÉCIT la file**.
    // Une session SRS qui se passe BIEN est exactement ce scénario.
    //
    // Mesure d'origine : `numberOfCardsOnScreen()` = `min(2, cardsCount - index)`
    // devenait **négatif** ⇒ `List.generate(-1, …)` ⇒ **`RangeError` en plein
    // `build`** (écran rouge), là même où la file vide est correctement traitée.

    testWidgets(
        '🔴 file 5 → 2 EN COURS de session (toute réussite rétrécit la file) : '
        'AUCUN crash', (tester) async {
      final key = GlobalKey<_QueueHostState>();
      await tester.pumpWidget(wrapApp(_QueueHost(key: key, queue: _queue(5))));
      await tester.pumpAndSettle();

      // On avance jusqu'à un index que la NOUVELLE file n'aura plus.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey<String>('card_f3')), findsOneWidget,
          reason: 'témoin : la pile est bien à l\'index 3 avant la mutation');

      // 💥 La file rétrécit sous la pile — le chemin NOMINAL du moteur SRS.
      key.currentState!.setQueue(_queue(2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: '🔴 AD-10 : `RangeError` en plein build (écran rouge) — '
              'l\'index du paquet a survécu à une file qui a rétréci. C\'est le '
              'chemin NOMINAL : toute réussite retire une carte de la file.');
      // …et la pile est REPARTIE proprement sur la nouvelle file.
      expect(find.byKey(const ValueKey<String>('card_f0')), findsOneWidget,
          reason: 'la nouvelle file doit être lue depuis sa PREMIÈRE carte');
    });

    testWidgets(
        '🔴 file REMPLACÉE à chaud (même longueur) : l\'indicateur dit VRAI et '
        'aucune carte n\'est sautée', (tester) async {
      // 🔴 Variante SILENCIEUSE du même défaut : à longueur égale il n'y a pas
      // de `RangeError` — juste un indicateur qui MENT (« 1/3 » sur la 3ᵉ carte)
      // et deux cartes que l'apprenant ne voit JAMAIS.
      final key = GlobalKey<_QueueHostState>();
      final indices = <int>[];
      await tester.pumpWidget(
        wrapApp(_QueueHost(key: key, queue: _queue(3), onIndexChanged: indices.add)),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      expect(indices, <int>[1, 2]);

      // 🔄 Nouveau lot, MÊME longueur (su-6 : « lot suivant », changement de
      // filtre…).
      key.currentState!.setQueue(<ZSessionItem>[
        for (var i = 0; i < 3; i++)
          ZSessionItem(flashcardId: 'g$i', folderId: 'd1'),
      ]);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // (1) la 1ʳᵉ carte du NOUVEAU lot est affichée — pas la 3ᵉ.
      expect(find.byKey(const ValueKey<String>('card_g0')), findsOneWidget,
          reason: '🔴 l\'apprenant reçoit `g2` : `g0` et `g1` ne lui seront '
              'JAMAIS montrées, le lot est lu à partir de sa 3ᵉ carte');
      // (2) l'indicateur ne ment pas : il annonce bien la carte affichée.
      expect(tester.getSemantics(find.byKey(ZSessionProgressIndicator.progressKey)).value,
          '1/3',
          reason: '🔴 l\'indicateur annonçait « 1/3 » pendant que la pile '
              'affichait la 3ᵉ carte — au lecteur d\'écran aussi');

      // (3) l'avancée suivante émet `1`, pas `3` : un hôte qui indexe
      // `queue[i]` pour noter travaillerait sinon sur la MAUVAISE carte.
      indices.clear();
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(indices, <int>[1],
          reason: '🔴 `onIndexChanged` saute des index après un remplacement de '
              'file ⇒ note SRS attribuée à la mauvaise carte, par la voie '
              'légitime');
      expect(find.byKey(const ValueKey<String>('card_g1')), findsOneWidget);
    });

    testWidgets(
        '🔴 (D8) `index == cardsCount` : ni écran vide, ni cul-de-sac — la '
        'session reste finissable', (tester) async {
      // 🔴 `numberOfCardsOnScreen()` = `min(2, 3 - 3)` = **0** ⇒ `Stack` vide :
      // pas de crash, mais un ÉCRAN VIDE sans repli (`emptyBuilder` hors
      // d'atteinte : la file n'est PAS vide) et **`onStackEnd` jamais émis** ⇒
      // l'apprenant est bloqué devant un vide, sans fin de session ni recours.
      // AD-10 demande de DÉGRADER, pas d'aboutir à un état sans issue.
      final key = GlobalKey<_QueueHostState>();
      var ends = 0;
      await tester.pumpWidget(
        wrapApp(_QueueHost(key: key, queue: _queue(5), onStackEnd: () => ends++)),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      // La file se réduit EXACTEMENT à l'index courant.
      key.currentState!.setQueue(_queue(3));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // (1) une carte est visible — jamais un écran vide sans recours.
      expect(find.byKey(const ValueKey<String>('card_f0')), findsOneWidget,
          reason: '🔴 écran VIDE : `min(2, cardsCount - index)` = 0 ⇒ `Stack` '
              'vide, et `emptyBuilder` est hors d\'atteinte (la file n\'est pas '
              'vide). Cul-de-sac sans repli.');
      // (2) …et la session peut ENCORE se terminer (`onStackEnd` atteignable).
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
      }
      expect(ends, 1,
          reason: '🔴 `onStackEnd` n\'est JAMAIS émis ⇒ su-5 ne poussera aucun '
              'écran de fin : la session ne se termine plus');
    });
  });
}

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

/// Hôte **mutable** — reproduit ce que fait un vrai hôte (su-5/su-6) quand le
/// moteur rend une nouvelle file : il **reconstruit** `ZSessionCardSwiper` avec
/// une `queue` différente, sans le remonter.
class _QueueHost extends StatefulWidget {
  const _QueueHost({
    required this.queue,
    this.onIndexChanged,
    this.onStackEnd,
    super.key,
  });

  final List<ZSessionItem> queue;
  final ValueChanged<int>? onIndexChanged;
  final VoidCallback? onStackEnd;

  @override
  State<_QueueHost> createState() => _QueueHostState();
}

class _QueueHostState extends State<_QueueHost> {
  late List<ZSessionItem> _queue = widget.queue;

  void setQueue(List<ZSessionItem> next) => setState(() => _queue = next);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 600,
        child: ZSessionCardSwiper(
          queue: _queue,
          cardBuilder: _card,
          passThreshold: 3,
          onIndexChanged: widget.onIndexChanged,
          onStackEnd: widget.onStackEnd,
        ),
      );
}
