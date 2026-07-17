/// 🎯 AC7 (SU-4) — **NFR-SU2 : la pile ne se reconstruit pas pendant le drag.**
///
/// **Le fait, vérifié sur disque** : `onPanUpdate` appelle `setState`
/// (`card_swiper_state.dart:139-165`) ⇒ le `cardBuilder` **EST** ré-invoqué à
/// **chaque frame** de drag. C'est non contournable depuis l'extérieur du
/// paquet. La granularité s'obtient donc en rendant l'invocation **inoffensive** :
/// `ZSessionCardSwiper` **mémoïse l'instance de carte par index** ⇒
/// `Element.updateChild` court-circuite le sous-arbre.
///
/// 🔴 **Anti-défaut (leçon su-3 : « sonde mesurant un sibling »)** : la sonde
/// compte les builds **DU CONTENU DE LA CARTE** (elle vit DANS le sous-arbre
/// mémoïsé). Une sonde posée à côté mesurerait autre chose et resterait verte à
/// tort.
///
/// 🔴 **Et la preuve n'est pas « rien ne bouge »** : le même test prouve que
/// l'overlay émotionnel, lui, **se met bien à jour** pendant le drag. Sans ce
/// contre-témoin, un widget entièrement figé (ou un drag qui n'a pas eu lieu)
/// passerait le test.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

/// Sonde de comptage — vit **À L'INTÉRIEUR** du contenu de la carte.
class _BuildProbe extends StatelessWidget {
  const _BuildProbe({required this.onBuild, required this.text});

  final VoidCallback onBuild;
  final String text;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return Text(text);
  }
}

void main() {
  group('🎯 AC7 — SM-1 : le contenu de carte ne se reconstruit PAS au drag', () {
    testWidgets(
        '🔴 un drag complet (multiples `moveBy`) ne reconstruit PAS le contenu, '
        'MAIS met bien à jour l\'overlay émotionnel', (tester) async {
      var contentBuilds = 0;

      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: _queue(3),
              cardBuilder: (context, item) => Center(
                child: _BuildProbe(
                  // 🔒 La sonde est DANS le sous-arbre de la carte — pas à côté.
                  onBuild: () => contentBuilds++,
                  text: item.flashcardId,
                ),
              ),
              passThreshold: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buildsAfterMount = contentBuilds;
      expect(buildsAfterMount, greaterThan(0),
          reason: 'la sonde ne s\'est jamais construite : elle ne mesure RIEN');

      // Drag RÉEL, frame par frame, sur la carte de devant (son contenu — donc
      // à coup sûr dans la zone du pan, jamais sur la rangée de navigation).
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('f0')),
      );
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(8, 0));
        await tester.pump();
      }

      // (1) 🎯 le contenu n'a PAS été reconstruit malgré ~10 frames de drag.
      expect(
        contentBuilds,
        buildsAfterMount,
        reason: '🔴 NFR-SU2 : le contenu de carte s\'est reconstruit '
            '${contentBuilds - buildsAfterMount} fois pendant le drag — la '
            'mémoïsation par index a disparu (le `cardBuilder` EST ré-invoqué '
            'par frame : c\'est l\'instance IDENTIQUE qui court-circuite)',
      );

      // (2) 🔴 …et pourtant quelque chose a bien bougé : l'overlay émotionnel
      // suit le doigt. Sans ce contre-témoin, « rien ne bouge » passerait.
      //
      // ⚠️ Il y a UN indicateur par carte rendue (devant + fond) : le paquet
      // appelle `cardBuilder(context, cardIndex, 0, 0)` pour les cartes de fond
      // (`_backItem`, vérifié sur disque) ⇒ offset 0 ⇒ elles ne rendent RIEN.
      // Seule la carte de DEVANT suit le doigt — c'est précisément ce qu'on
      // mesure ici (et non « un overlay existe quelque part »).
      final dragging = tester
          .widgetList<ZSwipeEmotionIndicator>(
              find.byType(ZSwipeEmotionIndicator))
          .where((i) => i.offsetPercentage != 0)
          .toList();
      expect(
        dragging,
        hasLength(1),
        reason: 'aucun overlay ne reçoit d\'offset ⇒ le drag n\'a pas eu lieu, '
            'et la preuve (1) est VIDE',
      );

      // La valeur RÉSOLUE est LUE sur le widget (jamais déduite). Seule la carte
      // de devant rend un `Opacity` : les cartes de fond (offset 0) rendent un
      // `SizedBox.shrink`.
      final opacityFinder = find.byKey(ZSwipeEmotionIndicator.opacityKey);
      expect(opacityFinder, findsOneWidget);
      expect(
        tester.widget<Opacity>(opacityFinder).opacity,
        greaterThan(0),
        reason: 'l\'overlay est présent mais totalement transparent ⇒ il ne '
            'suit pas l\'offset',
      );

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
