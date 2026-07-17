/// 🎯 AC9 (SU-4) — **le swipe n'est PAS accessible ⇒ alternative OBLIGATOIRE**
/// (AD-13).
///
/// 🔴 **Justification FACTUELLE, mesurée (pas une précaution)** :
/// `grep -rn "Semantics" ~/.pub-cache/hosted/pub.dev/flutter_card_swiper-7.2.0/lib/`
/// → **RC=1**. Le paquet n'expose **AUCUNE** sémantique : sans alternative, la
/// pile est **inutilisable** au lecteur d'écran. C'est un **trou mesuré**.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

Future<List<int>> _pump(WidgetTester tester, {TextDirection? direction}) async {
  final indices = <int>[];
  final swiper = SizedBox(
    height: 600,
    child: ZSessionCardSwiper(
      queue: _queue(3),
      cardBuilder: (context, item) => Center(child: Text(item.flashcardId)),
      passThreshold: 3,
      onIndexChanged: indices.add,
    ),
  );
  await tester.pumpWidget(
    direction == null
        ? wrapApp(swiper)
        : wrapApp(Directionality(textDirection: direction, child: swiper)),
  );
  await tester.pumpAndSettle();
  return indices;
}

void main() {
  group('🎯 AC9 — l\'alternative accessible EXISTE et PILOTE la pile', () {
    testWidgets('🔴 la navigation par BOUTON fait avancer l\'index',
        (tester) async {
      final indices = await _pump(tester);

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(
        indices,
        <int>[1],
        reason: '🔴 sans cette alternative, un lecteur d\'écran ne peut PAS '
            'avancer dans la pile (le paquet n\'expose aucune sémantique de '
            'swipe — RC=1 mesuré)',
      );
      expect(find.text('f1'), findsOneWidget);
    });

    testWidgets('le contrôle de navigation a une cible ≥ 48 dp', (tester) async {
      await _pump(tester);

      // 🔴 **TAUTOLOGIE RÉELLE, mesurée et fermée.** Le premier jet comparait à
      // `ZSessionCardSwiper.minTarget` — c'est-à-dire à la constante que le CODE
      // déclare. L'injection R3-I14 (ramener la cible à 40 dp) baissait donc
      // **l'assertion en même temps que le code**, et le test restait **VERT**
      // (mesuré : « All tests passed » avec des cibles à 40 dp).
      //
      // Le `48` d'AD-13 est une exigence **EXTERNE** (Material / WCAG cible
      // tactile) : elle ne peut pas être définie par le widget qu'elle contraint.
      // On l'écrit donc en dur ICI — c'est le seul endroit où un littéral est
      // légitime, parce qu'il EST la spécification.
      const requiredTarget = 48.0;
      // …et l'on vérifie au passage que le code n'a pas relâché SA constante en
      // douce (sans quoi la prod dessinerait 40 dp là où le test exige 48).
      expect(ZSessionCardSwiper.minTarget, greaterThanOrEqualTo(requiredTarget),
          reason: '🔴 AD-13 : la cible minimale déclarée par le widget est '
              'descendue sous 48 dp');

      for (final key in <ValueKey<String>>[
        ZSessionCardSwiper.nextButtonKey,
      ]) {
        final size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(requiredTarget),
            reason: '$key : largeur ${size.width} < $requiredTarget dp (AD-13)');
        expect(size.height, greaterThanOrEqualTo(requiredTarget),
            reason: '$key : hauteur ${size.height} < $requiredTarget dp (AD-13)');
      }
    });

    testWidgets(
        '🔴 le libellé annoncé DÉCRIT L\'ACTION RÉELLEMENT EXÉCUTÉE '
        '(association, pas présence)', (tester) async {
      // 🔴 **LE TROU RÉEL, mesuré et fermé — récidive exacte du HIGH de su-2.**
      // Le premier jet n'assérait que `expect(node.label, isNotEmpty)` : il
      // prouvait qu'**une** chaîne existe, jamais **laquelle**, ni qu'elle
      // décrit ce que le bouton FAIT. Sous cette assertion, un bouton étiqueté
      // « carte précédente » **qui avançait** est resté VERT (mesuré :
      // tap next puis prev ⇒ indices=[1,2], carte `f2` affichée) — et c'est
      // l'utilisateur de LECTEUR D'ÉCRAN, le seul public que cette rangée
      // existe pour servir, qui sautait une carte en croyant reculer.
      //
      // La seule garde qui mord est celle qui lie le LIBELLÉ à l'EFFET MESURÉ.
      final indices = await _pump(tester);
      final finder = find.byKey(ZSessionCardSwiper.nextButtonKey);

      // (1) ce que le nœud ANNONCE — visé par sa CLÉ, jamais par le libellé
      // qu'on vérifie (anti-défaut su-2/su-3 D6b).
      final node = tester.getSemantics(finder);
      expect(node.label, 'carte suivante',
          reason: '🔴 le bouton n\'annonce pas l\'action qu\'il exécute');

      // (2) ce que le nœud FAIT, réellement.
      await tester.tap(finder);
      await tester.pumpAndSettle();

      // (3) 🔒 L'ASSOCIATION : l'annonce (« suivante ») et l'effet (index +1)
      // concordent. Étiqueter ce bouton « précédent » rougirait en (1) ; le
      // câbler sur un retour arrière rougirait en (3).
      expect(indices, <int>[1],
          reason: '🔴 le contrôle annoncé « carte suivante » n\'a PAS avancé : '
              'il annonce l\'inverse de ce qu\'il fait');
      expect(find.text('f1'), findsOneWidget);
    });

    testWidgets(
        '🔴 AUCUN contrôle n\'annonce un RETOUR ARRIÈRE — il n\'en existe aucun',
        (tester) async {
      // 🔴 **Garde anti-récidive (D2).** La pile n'a AUCUN retour arrière : les
      // deux directions de swipe avancent (A2 — `_nextIndex` vaut `+1` quelle
      // que soit la direction), et AUCUN des 3 runtimes ne recule (`cursor` ne
      // fait que croître). Un contrôle qui en annoncerait un mentirait
      // forcément — c'est ce qui est arrivé.
      await _pump(tester);

      final announced = <String>[];
      void visit(SemanticsNode node) {
        if (node.label.isNotEmpty) announced.add(node.label.toLowerCase());
        node.visitChildren((child) {
          visit(child);
          return true;
        });
      }

      final root = tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!;
      visit(root);
      // Contre-preuve : le scan doit réellement voir des libellés (sans quoi il
      // serait vert pour de mauvaises raisons).
      expect(announced, isNotEmpty, reason: 'aucun libellé scanné');
      expect(announced, contains('carte suivante'),
          reason: 'le scan ne voit pas la rangée de navigation');

      const backwards = <String>['précédent', 'precedent', 'previous', 'retour'];
      for (final label in announced) {
        for (final b in backwards) {
          expect(label.contains(b), isFalse,
              reason: '🔴 D2 : le contrôle « $label » annonce un retour arrière '
                  'que la pile ne sait PAS faire. `controller.swipe(left)` '
                  'AVANCE (mesuré 0→1→2) ; `undo()` n\'est câblé nulle part et '
                  'aucun runtime ne recule. Un contrôle absent vaut mieux '
                  'qu\'un contrôle qui ment à un lecteur d\'écran.');
        }
      }
    });
  });

  group('🎯 AC9/D2 — garde de SOURCE : aucune navigation « à gauche »', () {
    test(
        '🔴 le swiper n\'appelle JAMAIS `swipe(CardSwiperDirection.left)` '
        'ni `undo()`', () {
      // 🔴 **Pourquoi une garde de SOURCE en plus de la garde de rendu** :
      // `controller.swipe(left)` **n'est pas** « aller à la carte précédente »
      // (fait vérifié sur disque : `_swipe(dir)` ⇒ `_undoableIndex.state =
      // _nextIndex` = **+1 quelle que soit la direction**,
      // `card_swiper_state.dart:295-300`). Tout appel à `.left` ici est donc,
      // par construction, soit mort, soit MENSONGER. La seule voie de retour du
      // paquet est `undo()` — qu'aucun runtime ne sait suivre (`cursor` ne fait
      // que croître) : la câbler désynchroniserait le widget et le moteur.
      final file = File(
        'lib/src/presentation/z_session_card_swiper.dart',
      );
      expect(file.existsSync(), isTrue,
          reason: 'cette garde ne scanne plus rien et serait verte pour de '
              'mauvaises raisons');

      // On dépouille les commentaires : la dartdoc EXPLIQUE la règle (elle cite
      // `swipe(left)` et `undo()`) et se dénoncerait elle-même.
      final code = <String>[];
      var inBlock = false;
      for (final raw in file.readAsLinesSync()) {
        var t = raw.trim();
        if (inBlock) {
          if (t.contains('*/')) {
            inBlock = false;
            t = t.substring(t.indexOf('*/') + 2).trim();
          } else {
            continue;
          }
        }
        if (t.startsWith('/*')) {
          if (!t.contains('*/')) {
            inBlock = true;
            continue;
          }
          t = t.substring(t.indexOf('*/') + 2).trim();
        }
        if (t.startsWith('///') || t.startsWith('//') || t.startsWith('*')) {
          continue;
        }
        final slash = t.indexOf('//');
        if (slash >= 0) t = t.substring(0, slash).trim();
        if (t.isEmpty) continue;
        code.add(t);
      }
      expect(code, isNotEmpty, reason: 'aucun code scanné');
      // Contre-preuve : le scan voit bien le code exécutable du swiper.
      expect(code.any((l) => l.contains('CardSwiper(')), isTrue,
          reason: 'le scan ne voit pas la construction du CardSwiper');

      final joined = code.join('\n');
      expect(joined.contains('CardSwiperDirection.left'), isFalse,
          reason: '🔴 D2 : `swipe(left)` AVANCE (mesuré 0→1→2). Un bouton '
              'câblé dessus et étiqueté « précédent » ment au lecteur d\'écran.');
      expect(joined.contains('.undo()'), isFalse,
          reason: '🔴 D2 : `undo()` reculerait l\'index DU WIDGET pendant que le '
              '`cursor` DU MOTEUR resterait sur place — la désynchronisation à '
              'deux sources de vérité que `_queueGeneration` ferme.');
    });
  });

  group('🎯 AC9 — RTL : l\'alternative fonctionne dans les deux directions', () {
    for (final direction in TextDirection.values) {
      testWidgets('en $direction, le bouton « suivant » avance', (tester) async {
        final indices = await _pump(tester, direction: direction);
        await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
        await tester.pumpAndSettle();
        // ⚠️ A2 : les DEUX directions physiques font AVANCER — il n'y a donc
        // aucune sémantique gauche/droite à inverser en RTL. C'est ce qui rend
        // ce test vert dans les deux sens SANS code directionnel dans le swipe.
        expect(indices, <int>[1],
            reason: 'la navigation doit avancer quelle que soit la direction '
                'du texte');
      });
    }
  });
}
