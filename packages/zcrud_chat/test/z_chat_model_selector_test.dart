/// Lot « mode Tile + sélecteur de modèle » (arbitrage 2) — **comportement** du
/// sélecteur de modèle d'IA du composer.
///
/// Ce que ce fichier MESURE :
/// * **MS-A** — SANS option, le sélecteur est **absent de l'arbre** du
///   composer (AD-4 : le créneau rend `null`, jamais un bouton inerte) ;
/// * **MS-R1** — le déclencheur ouvre le menu ; toutes les options d'hôte y
///   figurent ;
/// * **MS-R2** — la **coche suit l'actif** : `Semantics(selected:)` + emphase
///   CR-74 peinte + glyphe d'hôte, sur la SEULE option active — et elle BOUGE
///   quand `activeId` change ; un id actif inconnu du catalogue ⇒ aucune
///   coche, libellé générique (AD-10) ;
/// * **MS-G** — la sélection REMONTE par callback (id opaque), puis le menu se
///   ferme ; le socle ne stocke rien ;
/// * **MS-SM1** — le sélecteur n'est abonné à AUCUNE tranche du contrôleur
///   (un tour de flux complet ne le reconstruit pas), et ouvrir le menu ne
///   REMONTE pas les tuiles de la liste (AD-2/SM-1 — portée mesurée, cf. le
///   commentaire du groupe : la forme « frère non reconstruit » est
///   inatteignable sous ce montage, deux injections restées vertes) ;
/// * **MS-13** — cibles ≥ 48 dp en géométrie rendue (déclencheur ET items),
///   y compris en RTL ;
/// * **MS-T** — règle des trois cas du déclencheur ;
/// * **MS-NN** — grep NÉGATIF : aucun nom de modèle d'IA dans `lib/` (le
///   contrat est OPAQUE — « Mini », « Polaris »… n'existent pas au socle).
library;

import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const Color _cursor = Color(0xFF223344);

/// Un fil de [count] messages d'assistant (patron `z_chat_composer_test`).
List<ZChatMessage> thread(int count) => <ZChatMessage>[
  for (int i = 0; i < count; i++)
    assistant(<ZContentBlock>[ZTextBlock(text: 'msg $i')], id: 'm$i'),
];

/// Options FICTIVES — des identifiants de test, jamais des noms de modèles
/// réels : le socle n'en connaît aucun.
const List<ZChatModelOption> _options = <ZChatModelOption>[
  ZChatModelOption(id: 'routeur-a', label: 'Routeur Alpha'),
  ZChatModelOption(id: 'routeur-b', label: 'Routeur Bravo'),
  ZChatModelOption(id: 'routeur-c', label: 'Routeur Charlie'),
];

String _fb(String key) => kZChatLabelFallbacks[key]!;

TextStyle _painted(WidgetTester tester, Finder finder) {
  final RenderParagraph p = tester.renderObject<RenderParagraph>(finder);
  expect(p.text.style, isNotNull);
  return p.text.style!;
}

void main() {
  group('🔴 MS-A — sans option, PAS de sélecteur (AD-4)', () {
    testWidgets('le créneau `slot(options: [])` rend `null` : le composer ne '
        'monte AUCUN sélecteur — et le même montage avec options le monte '
        '(non-vacuité)', (WidgetTester tester) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      Widget mount(List<ZChatModelOption> options) => harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          tools: ZChatComposerModelSelector.slot(
            options: options,
            onSelect: (String _) {},
          ),
        ),
      );
      await tester.pumpWidget(mount(const <ZChatModelOption>[]));
      expect(find.byType(ZChatComposerModelSelector), findsNothing,
          reason: '🔴 un hôte sans option ne doit voir AUCUNE affordance — '
              'pas même un SizedBox inerte');
      // Non-vacuité : le même montage AVEC options monte bien le sélecteur.
      await tester.pumpWidget(mount(_options));
      expect(find.byType(ZChatComposerModelSelector), findsOneWidget);
    });
  });

  group('🔴 MS-R — menu par défaut : ouverture et COCHE sur l\'actif', () {
    Widget mount({
      String? activeId,
      ValueChanged<String>? onSelect,
      Widget? mark,
    }) => harness(
      // Le sélecteur vit EN BAS (rangée d'accessoires du composer) — c'est
      // aussi ce qui laisse la place au menu, qui s'ouvre AU-DESSUS.
      Align(
        alignment: AlignmentDirectional.bottomEnd,
        child: ZChatComposerModelSelector(
          options: _options,
          activeId: activeId,
          onSelect: onSelect ?? (String _) {},
          selectionMark: mark,
        ),
      ),
    );

    testWidgets('MS-R1 — le déclencheur ouvre le menu, TOUTES les options y '
        'figurent', (WidgetTester tester) async {
      await tester.pumpWidget(mount(activeId: 'routeur-b'));
      // Fermé : aucune option visible ; le déclencheur porte l'ACTIF.
      expect(find.text('Routeur Alpha'), findsNothing);
      expect(find.text('Routeur Bravo'), findsOneWidget);
      await tester.tap(find.text('Routeur Bravo'));
      await tester.pump();
      expect(find.text('Routeur Alpha'), findsOneWidget);
      expect(find.text('Routeur Charlie'), findsOneWidget);
    });

    testWidgets('MS-R2 — la coche SUIT l\'actif : sémantique + emphase peinte '
        '+ glyphe d\'hôte, sur la SEULE option active — et elle bouge avec '
        'l\'id', (WidgetTester tester) async {
      Widget withActive(String id) => harness(
        Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: ZChatComposerModelSelector(
            key: const ValueKey<String>('ms'),
            options: _options,
            activeId: id,
            onSelect: (String _) {},
            selectionMark: const Text('✓', key: ValueKey<String>('coche')),
          ),
        ),
      );
      await tester.pumpWidget(withActive('routeur-b'));
      await tester.tap(find.byType(ZChatComposerModelSelector));
      await tester.pump();
      // 1. Sémantique : UNE seule option `selected`, la bonne.
      List<SemanticsNode> selected() => collectSemantics(
        tester,
        (SemanticsNode n) =>
            n.flagsCollection.isSelected == Tristate.isTrue &&
            n.label.contains('Routeur'),
      );
      expect(selected(), hasLength(1));
      expect(selected().single.label, contains('Bravo'));
      // 2. Emphase PEINTE (CR-74) sur l'actif — style ambiant sur les autres.
      // Le déclencheur montre aussi « Routeur Bravo » : on mesure l'item du
      // MENU (le dernier rendu).
      final TextStyle active =
          _painted(tester, find.text('Routeur Bravo').last);
      final TextStyle idle =
          _painted(tester, find.text('Routeur Alpha').first);
      expect(active.fontWeight, kZChatSettingsReferenceSelectedWeight);
      expect(idle.fontWeight, isNot(kZChatSettingsReferenceSelectedWeight));
      // 3. Le glyphe d'hôte est là, UNE fois.
      expect(find.byKey(const ValueKey<String>('coche')), findsOneWidget);
      // 4. Elle SUIT : un autre actif déplace les trois canaux.
      await tester.pumpWidget(withActive('routeur-c'));
      await tester.pump();
      expect(selected().single.label, contains('Charlie'));
      final TextStyle nowActive =
          _painted(tester, find.text('Routeur Charlie').last);
      expect(nowActive.fontWeight, kZChatSettingsReferenceSelectedWeight);
    });

    testWidgets('MS-R3 — id actif INCONNU du catalogue : libellé générique, '
        'aucune coche (AD-10, aucune présomption)',
        (WidgetTester tester) async {
      await tester.pumpWidget(mount(activeId: 'routeur-disparu'));
      expect(tester.takeException(), isNull);
      expect(find.text(_fb(kZChatLabelModelSelector)), findsOneWidget);
      await tester.tap(find.text(_fb(kZChatLabelModelSelector)));
      await tester.pump();
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) =>
              n.flagsCollection.isSelected == Tristate.isTrue &&
              n.label.contains('Routeur'),
        ),
        isEmpty,
      );
    });

    testWidgets('MS-G — la sélection REMONTE (id opaque) puis le menu se '
        'ferme', (WidgetTester tester) async {
      final List<String> received = <String>[];
      await tester.pumpWidget(
        mount(activeId: 'routeur-a', onSelect: received.add),
      );
      await tester.tap(find.text('Routeur Alpha'));
      await tester.pump();
      await tester.tap(find.text('Routeur Charlie'));
      await tester.pump();
      expect(received, <String>['routeur-c'],
          reason: '🔴 c\'est l\'ID qui remonte — l\'hôte le range chez lui '
              '(`aiRouterId`), le socle ne stocke rien');
      expect(find.text('Routeur Bravo'), findsNothing,
          reason: '🔴 le menu doit se refermer après la sélection');
    });
  });

  group('🔴 MS-SM1 — le sélecteur et la liste s\'IGNORENT (AD-2)', () {
    // ⚠️ Portée de la garde, mesurée avant de l'écrire : un « frère ne se
    // reconstruit pas quand le menu s'ouvre » est INATTEIGNABLE sous ce
    // montage — l'arbre de test est fait d'instances de widgets identiques,
    // toute propagation de rebuild s'y arrête (deux injections d'ancêtre
    // `reassemble`/`markNeedsBuild` sont restées VERTES, mesuré). On n'écrit
    // pas une garde que rien ne peut faire rougir (leçon des 19 vacantes) ;
    // on garde les deux propriétés ATTEIGNABLES :
    // 1. le sélecteur n'est ABONNÉ à aucune tranche du contrôleur — un
    //    message qui arrive ne le reconstruit pas (compteur sur
    //    `triggerBuilder`, re-invoqué à chaque build du sélecteur) ;
    // 2. ouvrir/fermer le menu ne REMONTE pas les tuiles de la liste
    //    (identité d'`Element` — c'est le remontage qui perd l'état).
    testWidgets('un jeton de flux qui arrive ne reconstruit PAS le '
        'sélecteur ; ouvrir le menu ne REMONTE pas la liste',
        (WidgetTester tester) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      int triggerBuilds = 0;
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              Expanded(
                child: ZChatConversationView(controller: rig.controller),
              ),
              ZChatComposer(
                controller: rig.controller,
                cursorColor: _cursor,
                tools: ZChatComposerModelSelector.slot(
                  options: _options,
                  activeId: 'routeur-a',
                  onSelect: (String _) {},
                  triggerBuilder: (BuildContext context,
                      ZChatModelOption? active, bool open, VoidCallback t) {
                    triggerBuilds++;
                    return GestureDetector(
                      onTap: t,
                      child: const Text('déclencheur-sonde'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(tester.widgetList(find.byType(ZChatMessageTile)).length,
          greaterThan(0),
          reason: '🔴 SUJET NON MONTÉ : sans tuile, la mesure serait vide');
      expect(triggerBuilds, 1);
      final Set<Element> tileElements =
          tester.elementList(find.byType(ZChatMessageTile)).toSet();
      // 1. Un tour de conversation COMPLET arrive — le sélecteur ne bouge pas.
      rig.controller.composer.text = 'question';
      await tester.pump();
      // ⚠️ `send()` ne se résout qu'à la FIN du flux : on ne l'attend pas
      // avant d'avoir alimenté le canal (deadlock mesuré).
      final Future<void> turn = rig.controller.send();
      await tester.pump();
      rig.port.last.add(tok('réponse'));
      await rig.port.closeAll();
      await turn;
      await tester.pump();
      await tester.pump();
      expect(tester.widgetList(find.byType(ZChatMessageTile)).length,
          greaterThan(2),
          reason: '🔴 le tour n\'a pas produit de nouvelle tuile : la mesure '
              'ne prouverait rien');
      expect(triggerBuilds, 1,
          reason: '🔴 le sélecteur s\'est reconstruit à l\'arrivée d\'un '
              'message : il est ABONNÉ à une tranche du contrôleur (AD-2)');
      // 2. Ouvrir puis fermer le menu ne REMONTE pas les tuiles initiales.
      await tester.tap(find.text('déclencheur-sonde'));
      await tester.pump();
      expect(find.text('Routeur Charlie'), findsOneWidget,
          reason: '🔴 le menu ne s\'est pas ouvert : mesure vide');
      await tester.tap(find.text('Routeur Charlie').last);
      await tester.pump();
      expect(
        tester
            .elementList(find.byType(ZChatMessageTile))
            .toSet()
            .containsAll(tileElements),
        isTrue,
        reason: '🔴 ouvrir le menu a REMONTÉ des tuiles de la liste — perte '
            'd\'état de dépli/sélection (SM-1)',
      );
    });
  });

  group('🔴 MS-13 — cibles ≥ 48 dp, géométrie RENDUE, LTR et RTL', () {
    testWidgets('déclencheur et items du menu', (WidgetTester tester) async {
      for (final TextDirection dir in TextDirection.values) {
        await tester.pumpWidget(
          harness(
            Align(
              alignment: AlignmentDirectional.bottomEnd,
              child: ZChatComposerModelSelector(
                options: _options,
                activeId: 'routeur-a',
                onSelect: (String _) {},
              ),
            ),
            direction: dir,
          ),
        );
        final Size trigger =
            tester.getSize(find.byType(ZChatComposerModelSelector));
        expect(trigger.height, greaterThanOrEqualTo(48), reason: '$dir');
        expect(trigger.width, greaterThanOrEqualTo(48), reason: '$dir');
        await tester.tap(find.text('Routeur Alpha'));
        await tester.pump();
        final Size item = tester.getSize(
          find
              .ancestor(
                of: find.text('Routeur Charlie'),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(item.height, greaterThanOrEqualTo(48), reason: '$dir');
        // Refermer avant l'itération suivante.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
      }
    });
  });

  group('🔴 MS-T — règle des trois cas du DÉCLENCHEUR', () {
    testWidgets('builder fourni ⇒ remplace ; rendant `null` ⇒ affordance '
        'absente', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          ZChatComposerModelSelector(
            options: _options,
            onSelect: (String _) {},
            triggerBuilder:
                (BuildContext _, ZChatModelOption? _, bool _, VoidCallback _) =>
                    const Text('déclencheur-hôte'),
          ),
        ),
      );
      expect(find.text('déclencheur-hôte'), findsOneWidget);
      expect(find.text(_fb(kZChatLabelModelSelector)), findsNothing);

      await tester.pumpWidget(
        harness(
          ZChatComposerModelSelector(
            options: _options,
            onSelect: (String _) {},
            triggerBuilder:
                (BuildContext _, ZChatModelOption? _, bool _, VoidCallback _) =>
                    null,
          ),
        ),
      );
      expect(find.text(_fb(kZChatLabelModelSelector)), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 MS-NN — grep NÉGATIF : aucun nom de modèle au socle', () {
    test('aucun littéral de nom de modèle d\'IA dans `lib/` (commentaires '
        'exclus — le contrat est OPAQUE)', () {
      final List<String> offenders = <String>[];
      int scanned = 0;
      // Les noms vus dans les VIDÉOS et les hôtes — s'ils entraient au socle,
      // c'est exactement ici qu'ils rougiraient.
      final RegExp names = RegExp(
        "['\"](Mini|Plus|Pro|Polaris|Polaris Lite|Lexia|GPT[^'\"]*|Claude|"
        "Gemini)['\"]",
      );
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          scanned++;
          if (names.hasMatch(e.value[i])) {
            offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(scanned, greaterThan(1000),
          reason: '🔴 GARDE VACUELLE : balayage trop court');
      expect(offenders, isEmpty,
          reason: '🔴 un nom de modèle d\'IA est entré au socle — le contrat '
              '`ZChatModelOption` est OPAQUE (arbitrage 2).\n'
              '${offenders.join('\n')}');
      // Contre-preuve : le motif VOIT un nom s'il entrait.
      expect(names.hasMatch("const x = 'Polaris';"), isTrue);
      expect(names.hasMatch("label: 'Mini',"), isTrue);
    });
  });
}
