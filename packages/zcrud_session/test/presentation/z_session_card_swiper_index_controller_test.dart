/// CR-IFFD-38 — raccordement du patron `ZDisplayState` à la pile de session :
/// la **carte courante** devient commandable par l'hôte (`ZIndexController`),
/// sans rien changer pour l'hôte qui n'en fournit pas.
///
/// 🔴 Ce que ces gardes mesurent — et pourquoi ce n'est pas « bien mesurer à
/// côté » :
/// - une commande de l'hôte est vérifiée **sur l'ARBRE RENDU** (quelle carte est
///   montée), jamais sur un champ interne : un `moveTo` oublié laisserait le
///   champ juste et l'écran faux ;
/// - la **source de vérité** est vérifiée dans les DEUX sens (l'hôte lit ce que
///   le geste a produit, ET le geste part de ce que l'hôte a écrit) : un miroir
///   local passerait le premier sens et échouerait au second ;
/// - la **consommation** du contrôleur est vérifiée (`wasEverConsumed`) : c'est
///   la seule garde qui distingue « paramètre branché » de « paramètre déclaré
///   et jamais utilisé » — le passe-plat inerte mesuré chez l'hôte.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';

import '../support/z_sources.dart';
import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

/// Carte d'affichage minimale — le contenu porte l'id, pour prouver **QUELLE**
/// carte est rendue (jamais « une carte est rendue »).
Widget _card(BuildContext context, ZSessionItem item) => Center(
      key: ValueKey<String>('card_${item.flashcardId}'),
      child: Text(item.flashcardId),
    );

/// Hôte de test **conforme au patron** : le contrôleur est possédé par un
/// `State` (champ), jamais créé dans `build` — c'est exactement ce que le mixin
/// impose.
class _Host extends StatefulWidget {
  const _Host({
    required this.queue,
    this.onIndexChanged,
    this.initialIndex = 0,
    this.withController = true,
    super.key,
  });

  final List<ZSessionItem> queue;
  final ValueChanged<int>? onIndexChanged;
  final int initialIndex;
  final bool withController;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with ZDisplayStateOwnerMixin<_Host> {
  late final ZIndexController controller = ZIndexController(
    owner: this,
    initialValue: widget.initialIndex,
    debugLabel: 'test.currentCard',
  );

  late List<ZSessionItem> queue = widget.queue;

  void replaceQueue(List<ZSessionItem> next) => setState(() => queue = next);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 600,
        child: ZSessionCardSwiper(
          queue: queue,
          cardBuilder: _card,
          passThreshold: 3,
          onIndexChanged: widget.onIndexChanged,
          indexController: widget.withController ? controller : null,
        ),
      );
}

Finder _cardAt(int i) => find.byKey(ValueKey<String>('card_f$i'));

/// Ce que l'indicateur ANNONCE (`position/total`) — mesuré sur le nœud de
/// progression, jamais sur un champ du `State`.
String? _announcedProgress(WidgetTester tester) => tester
    .getSemantics(find.byKey(ZSessionProgressIndicator.progressKey))
    .value;

/// Racine du dépôt (dossier portant `melos.yaml`) — ancrage ROBUSTE : un
/// chemin relatif dépendrait du répertoire de lancement de `flutter test`.
Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/melos.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
    }
    dir = parent;
  }
  return dir;
}

void main() {
  group('CR-IFFD-38 — SANS contrôleur : strictement inchangé', () {
    testWidgets('la carte de devant reste l\'index 0 et le bouton avance',
        (tester) async {
      final indices = <int>[];
      await tester.pumpWidget(
        wrapApp(
          _Host(
            queue: _queue(3),
            withController: false,
            onIndexChanged: indices.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(_cardAt(0), findsOneWidget);
      expect(_cardAt(2), findsNothing);

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(indices, <int>[1]);
      expect(_cardAt(1), findsOneWidget);
      // L'indicateur suit — il lit la source, pas une copie.
      expect(_announcedProgress(tester), '2/3');
    });

    testWidgets('aucun `ZIndexController` n\'est CRÉÉ par le composant',
        (tester) async {
      // Garde STRUCTURELLE : le composant ne peut pas créer de contrôleur (il
      // faudrait un `ZDisplayStateOwner`), et ne doit pas non plus en fabriquer
      // un par un propriétaire interne — ce serait industrialiser le bug de
      // l'hôte (contrôleur créé dans `build`, écrasé au rebuild suivant).
      // Source débarrassée de ses commentaires : une garde qui compterait des
      // occurrences de TEXTE (dartdoc comprise) ne mesurerait pas le code.
      // P0b : dé-commentateur ROBUSTE — l'ancien filtre ne retirait que les
      // lignes commençant par `//`, aveugle à `/* … */` et aux commentaires de
      // fin de ligne.
      final src = strippedSource(
        File(
          '${_repoRoot().path}/packages/zcrud_session/lib/src/presentation/'
          'z_session_card_swiper.dart',
        ),
      );
      expect(
        RegExp(r'ZIndexController\s*\(').allMatches(src),
        isEmpty,
        reason: '🔴 le composant CONSOMME un contrôleur, il n\'en construit '
            'jamais — ni dans `build`, ni ailleurs',
      );
      expect(
        RegExp(r'with[^;{]*ZDisplayStateOwnerMixin').hasMatch(src),
        isFalse,
        reason: '🔴 la POSSESSION appartient à l\'hôte : le composant qui se '
            'ferait propriétaire reprendrait la main sur l\'état qu\'il '
            'prétend céder',
      );
    });
  });

  group('CR-IFFD-38 — AVEC contrôleur : la commande AGIT sur l\'arbre', () {
    testWidgets('🔴 un saut direct MONTE une autre carte', (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(wrapApp(_Host(key: key, queue: _queue(3))));
      await tester.pumpAndSettle();

      expect(_cardAt(0), findsOneWidget);
      expect(_cardAt(2), findsNothing);

      key.currentState!.controller.value = 2;
      await tester.pumpAndSettle();

      expect(
        _cardAt(2),
        findsOneWidget,
        reason: '🔴 sans `moveTo`, le paramètre serait un passe-plat inerte : '
            'la valeur changerait et l\'écran resterait sur la carte 0',
      );
      // La carte 2 est la DERNIÈRE : à cet index le paquet ne monte qu'elle
      // (`min(2, 3 - 2) = 1`) ⇒ ni f0 ni f1 ne sont dans l'arbre.
      expect(_cardAt(0), findsNothing);
      expect(_cardAt(1), findsNothing);
      expect(_announcedProgress(tester), '3/3');
    });

    testWidgets('🔴 `previous()` recule RÉELLEMENT la carte affichée',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        wrapApp(_Host(key: key, queue: _queue(3), initialIndex: 2)),
      );
      await tester.pumpAndSettle();
      expect(_cardAt(2), findsOneWidget);

      key.currentState!.controller.previous();
      await tester.pumpAndSettle();

      // Retour en arrière RÉEL : la carte 1 (re)devient la carte de devant et
      // la carte 0 reste hors de l'arbre — le paquet ne monte que `index` et
      // `index + 1`.
      expect(_cardAt(1), findsOneWidget);
      expect(_cardAt(0), findsNothing);
      expect(_announcedProgress(tester), '2/3');
    });

    testWidgets('un contrôleur DÉJÀ positionné monte SA carte, pas l\'index 0',
        (tester) async {
      await tester.pumpWidget(
        wrapApp(_Host(queue: _queue(4), initialIndex: 2)),
      );
      await tester.pumpAndSettle();

      expect(_cardAt(2), findsOneWidget);
      expect(_cardAt(0), findsNothing);
      expect(_cardAt(1), findsNothing);
      expect(_announcedProgress(tester), '3/4');
    });

    testWidgets('le contrôleur est réellement CONSOMMÉ (anti passe-plat)',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(wrapApp(_Host(key: key, queue: _queue(3))));
      await tester.pumpAndSettle();

      expect(key.currentState!.controller.wasEverConsumed, isTrue);
      expect(key.currentState!.controller.consumerCount, 1);
    });
  });

  group('CR-IFFD-38 — le contrôleur reste LA source de vérité', () {
    testWidgets('🔴 une commande INTERNE (bouton) est écrite CHEZ L\'HÔTE',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(wrapApp(_Host(key: key, queue: _queue(3))));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(
        key.currentState!.controller.value,
        1,
        reason: '🔴 un miroir interne laisserait le contrôleur de l\'hôte à 0 '
            'pendant que la carte 1 est affichée — la divergence exacte que le '
            'contrat interdit',
      );

      // …et le SENS INVERSE : l'hôte repart de l\'état réel, pas d\'un état
      // périmé. Un miroir passerait le premier sens et échouerait ici.
      key.currentState!.controller.previous();
      await tester.pumpAndSettle();
      expect(_cardAt(0), findsOneWidget);
      expect(key.currentState!.controller.value, 0);
    });

    testWidgets('AD-10 — une commande HORS BORNES est ramenée À LA SOURCE',
        (tester) async {
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(wrapApp(_Host(key: key, queue: _queue(3))));
      await tester.pumpAndSettle();

      key.currentState!.controller.value = 99;
      await tester.pumpAndSettle();

      expect(
        key.currentState!.controller.value,
        2,
        reason: '🔴 ignorer la commande laisserait le contrôleur affirmer un '
            'index (99) que rien n\'affiche',
      );
      expect(_cardAt(2), findsOneWidget);

      key.currentState!.controller.value = -5;
      await tester.pumpAndSettle();
      expect(key.currentState!.controller.value, 0);
      expect(_cardAt(0), findsOneWidget);
    });
  });

  group('CR-IFFD-38 — la notification sortante SURVIT au pilote', () {
    testWidgets('🔴 `onIndexChanged` est émis AUSSI sur commande de l\'hôte',
        (tester) async {
      final indices = <int>[];
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        wrapApp(_Host(key: key, queue: _queue(3), onIndexChanged: indices.add)),
      );
      await tester.pumpAndSettle();

      // Voie interne (témoin positif : la voie d'émission est vivante).
      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(indices, <int>[1]);

      // Voie HÔTE — muette si l'émission était accrochée à l'écriture interne.
      key.currentState!.controller.value = 2;
      await tester.pumpAndSettle();
      expect(indices, <int>[1, 2]);
    });

    testWidgets(
        'un changement de FILE ne se met PAS à émettre (comportement d\'origine)',
        (tester) async {
      final indices = <int>[];
      final key = GlobalKey<_HostState>();
      await tester.pumpWidget(
        wrapApp(_Host(key: key, queue: _queue(3), onIndexChanged: indices.add)),
      );
      await tester.pumpAndSettle();

      key.currentState!.controller.value = 2;
      await tester.pumpAndSettle();
      expect(indices, <int>[2]);

      key.currentState!.replaceQueue(_queue(2));
      await tester.pumpAndSettle();

      expect(
        indices,
        <int>[2],
        reason: 'la remise à zéro consécutive à un changement de file '
            'n\'émettait rien avant CR-IFFD-38',
      );
      // …mais l'état, lui, est bien remis à zéro À LA SOURCE.
      expect(key.currentState!.controller.value, 0);
      expect(_cardAt(0), findsOneWidget);
    });
  });
}
