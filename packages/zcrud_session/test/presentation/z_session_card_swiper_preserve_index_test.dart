/// 🎯 `ZSessionCardSwiper.preserveIndexOnMutation` — la carte courante survit
/// (ou non) à une mutation de la file.
///
/// Deux régimes, deux gardes :
///  1. **INERTIE ABSOLUE** — le paramètre OMIS laisse le comportement
///     historique intact : toute mutation de file ramène la pile à sa
///     première carte, sans émettre d'avancée. Mesurée en **égalité stricte**
///     de l'arbre rendu avec celui d'une pile FRAÎCHEMENT montée sur la même
///     file (widget par widget, dans l'ordre) — pas un `contains`, pas un
///     `<=` ;
///  2. **CONSERVATION** — `preserveIndexOnMutation: true` garde la position,
///     ramenée dans les bornes quand la file rétrécit, et n'émet pas
///     davantage d'avancée (une mutation de file n'est pas une navigation).
///
/// 🔴 Anti-tautologie : chaque assertion du régime `true` est doublée de la
/// valeur obtenue par le régime par défaut sur le MÊME scénario, et les deux
/// sont exigées DIFFÉRENTES. Sans ce témoin, une garde qui n'assertait que
/// « l'index vaut 2 » resterait verte si le paramètre n'était jamais lu et
/// que le scénario tombait par hasard sur 2.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(String prefix, int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: '$prefix$i', folderId: 'd1'),
    ];

Widget _card(BuildContext context, ZSessionItem item) =>
    Center(child: Text(item.flashcardId));

/// Index affiché — lu à la SOURCE que le widget rend, jamais dans une copie
/// du test.
int _shownIndex(WidgetTester tester) => tester
    .widget<ZSessionProgressIndicator>(find.byType(ZSessionProgressIndicator))
    .currentIndex;

/// Empreinte STRICTE de l'arbre rendu : le type de chaque widget, dans
/// l'ordre de parcours. Deux arbres égaux au widget près donnent la même
/// liste ; un nœud ajouté, retiré ou déplacé la change.
List<String> _fingerprint(WidgetTester tester) => tester.allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Monte une pile et rend le `setState` de l'hôte pour muter ses paramètres.
Future<void Function(List<ZSessionItem> queue)> _pumpHost(
  WidgetTester tester, {
  required List<ZSessionItem> initial,
  required List<int> emitted,
  bool? preserveIndexOnMutation,
}) async {
  late StateSetter setOuter;
  var queue = initial;

  await tester.pumpWidget(
    wrapApp(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          setOuter = setState;
          // 🔒 Le régime par défaut est obtenu en N'ÉCRIVANT PAS le
          // paramètre — jamais en passant `false` explicitement : c'est bien
          // l'ABSENCE d'argument que la garde d'inertie doit mesurer.
          return preserveIndexOnMutation == null
              ? ZSessionCardSwiper(
                  queue: queue,
                  cardBuilder: _card,
                  passThreshold: 3,
                  onIndexChanged: emitted.add,
                )
              : ZSessionCardSwiper(
                  queue: queue,
                  cardBuilder: _card,
                  passThreshold: 3,
                  onIndexChanged: emitted.add,
                  preserveIndexOnMutation: preserveIndexOnMutation,
                );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (List<ZSessionItem> next) {
    setOuter(() => queue = next);
  };
}

/// Avance de [times] crans par le bouton d'accessibilité — la même voie
/// d'émission que le geste.
Future<void> _advance(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('🔒 INERTIE — paramètre OMIS : la mutation ramène à la carte 0', () {
    testWidgets('index 2 ⇒ mutation ⇒ index 0, et AUCUNE avancée émise',
        (tester) async {
      final emitted = <int>[];
      final mutate = await _pumpHost(
        tester,
        initial: _queue('f', 6),
        emitted: emitted,
      );

      await _advance(tester, 2);
      expect(_shownIndex(tester), 2);
      expect(emitted, <int>[1, 2]);

      mutate(_queue('g', 6));
      await tester.pumpAndSettle();

      expect(_shownIndex(tester), 0,
          reason: '🔴 comportement historique perdu : sans le nouveau '
              'paramètre, une mutation de file DOIT ramener à la carte 0');
      expect(emitted, <int>[1, 2],
          reason: '🔴 la remise à zéro s\'est mise à émettre `onIndexChanged` '
              '— elle ne l\'a jamais fait');
    });

    testWidgets(
        '🔬 égalité STRICTE — l\'arbre après mutation est celui d\'une pile '
        'FRAÎCHEMENT montée sur la même file (widget par widget)',
        (tester) async {
      // (1) Pile vieillie : avancée de 2 crans, puis file remplacée.
      final aged = <int>[];
      final mutate = await _pumpHost(
        tester,
        initial: _queue('f', 6),
        emitted: aged,
      );
      await _advance(tester, 2);
      mutate(_queue('g', 6));
      await tester.pumpAndSettle();
      final agedTree = _fingerprint(tester);
      // 🔴 Le CONTENU, pas seulement la forme : l'empreinte de types est
      // aveugle à la carte réellement affichée (deux `Text` sont deux `Text`).
      // Sans ces deux assertions, une pile restée sur la carte 2 passerait la
      // comparaison d'arbres — mesuré.
      expect(find.text('g0'), findsOneWidget,
          reason: '🔴 après mutation, la pile vieillie n\'affiche PAS la '
              'première carte de la nouvelle file');
      expect(find.text('g2'), findsNothing,
          reason: '🔴 la pile est restée sur la position d\'avant la mutation');

      // (2) Pile neuve sur la MÊME file, jamais avancée.
      await _pumpHost(tester, initial: _queue('g', 6), emitted: <int>[]);
      final freshTree = _fingerprint(tester);

      // Contre-preuve : l'empreinte doit réellement voir un arbre.
      expect(freshTree, isNotEmpty);
      expect(agedTree, orderedEquals(freshTree),
          reason: '🔴 après mutation, la pile vieillie ne rend PAS le même '
              'arbre qu\'une pile neuve : la remise à zéro historique est '
              'incomplète');
      expect(find.text('g0'), findsOneWidget);
      expect(find.text('g2'), findsNothing);
    });
  });

  group('🎯 CONSERVATION — preserveIndexOnMutation: true', () {
    testWidgets('🔴 l\'index survit à la mutation — et le régime par défaut, '
        'lui, ne le conserve PAS (témoin discriminant)', (tester) async {
      final preserved = <int>[];
      final mutatePreserving = await _pumpHost(
        tester,
        initial: _queue('f', 6),
        emitted: preserved,
        preserveIndexOnMutation: true,
      );
      await _advance(tester, 2);
      mutatePreserving(_queue('g', 6));
      await tester.pumpAndSettle();
      final withParam = _shownIndex(tester);

      // MÊME scénario, paramètre omis.
      final defaults = <int>[];
      final mutateDefault = await _pumpHost(
        tester,
        initial: _queue('f', 6),
        emitted: defaults,
      );
      await _advance(tester, 2);
      mutateDefault(_queue('g', 6));
      await tester.pumpAndSettle();
      final withoutParam = _shownIndex(tester);

      expect(withParam, 2,
          reason: '🔴 `preserveIndexOnMutation: true` n\'a pas conservé la '
              'position : le paramètre est un passe-plat inerte');
      expect(withoutParam, 0);
      expect(withParam == withoutParam, isFalse,
          reason: '🔴 les deux régimes rendent le MÊME index ⇒ le paramètre '
              'n\'est pas lu du tout');
      expect(preserved, <int>[1, 2],
          reason: '🔴 conserver la position n\'est pas avancer : aucune '
              'émission supplémentaire ne doit apparaître');
    });

    testWidgets('🔴 file qui RÉTRÉCIT sous l\'index : la position est CLAMPÉE '
        'à la dernière carte, jamais hors bornes', (tester) async {
      final emitted = <int>[];
      final mutate = await _pumpHost(
        tester,
        initial: _queue('f', 6),
        emitted: emitted,
        preserveIndexOnMutation: true,
      );
      await _advance(tester, 4);
      expect(_shownIndex(tester), 4);

      // Nouvelle file de 2 cartes : l'index 4 n'y existe pas.
      mutate(_queue('g', 2));
      await tester.pumpAndSettle();

      expect(_shownIndex(tester), 1,
          reason: '🔴 l\'index n\'a pas été ramené dans les bornes de la '
              'nouvelle file (dernier index valide = 1)');
      // La carte de devant est bien une carte de la NOUVELLE file — l\'index
      // conservé ne peut pas désigner une carte disparue.
      expect(find.text('g1'), findsOneWidget);
      expect(find.text('f4'), findsNothing);
    });

    testWidgets('file vidée puis re-remplie : aucun crash, repli puis index 0',
        (tester) async {
      final emitted = <int>[];
      final mutate = await _pumpHost(
        tester,
        initial: _queue('f', 4),
        emitted: emitted,
        preserveIndexOnMutation: true,
      );
      await _advance(tester, 3);

      mutate(<ZSessionItem>[]);
      await tester.pumpAndSettle();
      // Repli file vide (invariant AD-10) : jamais une exception.
      expect(find.byKey(ZSessionCardSwiper.emptyKey), findsOneWidget);
      expect(tester.takeException(), isNull);

      mutate(_queue('g', 3));
      await tester.pumpAndSettle();
      // La file vide a ramené la position à 0 (`_clampIndex` d'une file vide
      // vaut 0) : la pile repart de sa première carte, sans hors-bornes.
      expect(_shownIndex(tester), 0);
      expect(tester.takeException(), isNull);
    });
  });
}
