/// Les **déclencheurs de contexte** : reconnaître, demander, rendre, transmettre.
///
/// Ce que ces gardes prouvent : sans déclencheur l'arbre et les gestes sont
/// **inchangés** (mesuré en absolu) ; le socle **ne filtre pas, ne trie pas et
/// ne tronque pas** — le plafond déclaré est TRANSPORTÉ, jamais appliqué ;
/// il n'exécute aucune commande ; l'ouverture du panneau ne touche ni le
/// focus, ni le texte, ni le curseur ; et la superposition est une affordance
/// conforme (cible ≥ 48 dp, navigation au clavier, annonce, fermeture sans
/// choix).
@TestOn('vm')
library;

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

ZChatMentionCandidate _cand(String k, {String? insert, String? disabled}) =>
    ZChatMentionCandidate(
      key: k,
      label: 'libellé $k',
      insertText: insert,
      disabledReasonToken: disabled,
    );

/// Source scriptable — elle rend EXACTEMENT ce qu'on lui dit, dans l'ordre
/// qu'on lui dit, y compris une liste plus longue que le plafond déclaré.
class _Source implements ZChatMentionSource {
  _Source(this.liste, {this.throws = false});
  final List<ZChatMentionCandidate> liste;
  final bool throws;
  final List<String> requetes = <String>[];

  @override
  Future<ZResult<List<ZChatMentionCandidate>>> candidates(
    ZChatMentionMatch match,
  ) async {
    requetes.add(match.query);
    if (throws) throw StateError('source en panne');
    return Right<ZFailure, List<ZChatMentionCandidate>>(liste);
  }
}

ZChatComposerAffordanceController _ctrl(
  TextEditingController composer, {
  List<ZChatMentionCandidate> candidats = const <ZChatMentionCandidate>[],
  int? maxCandidates,
  ZChatMentionSource? source,
  ZChatSlashCatalog? catalog,
  void Function(ZChatMentionCandidate, ZChatMentionMatch)? onCandidate,
  void Function(ZChatSlashCommand, ZChatMentionMatch)? onCommand,
}) {
  final ZChatMentionTrigger t = ZChatMentionTrigger(
    character: '@',
    sourceKey: 'fichiers',
    maxCandidates: maxCandidates,
  );
  return ZChatComposerAffordanceController(
    composer: composer,
    triggers: <ZChatMentionTrigger>[t],
    sources: ZChatMentionSources(<String, ZChatMentionSource>{
      'fichiers': source ?? _Source(candidats),
    }),
    catalog: catalog,
    onCandidate: onCandidate,
    onCommand: onCommand,
  );
}

void main() {
  group('L8 — reconnaissance et TRANSMISSION SANS FILTRAGE', () {
    test(
      '🔴 le plafond déclaré est TRANSPORTÉ, jamais appliqué : les 5 candidats '
      'de la source sont rendus alors que le déclencheur en annonce 2',
      () async {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        final _Source src = _Source(<ZChatMentionCandidate>[
          for (int i = 0; i < 5; i++) _cand('c$i'),
        ]);
        final ZChatComposerAffordanceController c = _ctrl(
          champ,
          maxCandidates: 2,
          source: src,
        );
        addTearDown(c.dispose);

        champ.value = const TextEditingValue(
          text: '@do',
          selection: TextSelection.collapsed(offset: 3),
        );
        await Future<void>.delayed(Duration.zero);

        expect(c.state.value.entries, hasLength(5),
            reason: '🔴 tronquer ferait disparaître des candidats sans que '
                'personne ne sache lesquels');
        expect(c.state.value.maxCandidates, 2,
            reason: 'le plafond est transporté pour que l\'hôte en décide');
        expect(src.requetes, <String>['do']);
      },
    );

    test(
      '🔴 l\'ORDRE de la source est conservé : le socle ne trie pas',
      () async {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        final ZChatComposerAffordanceController c = _ctrl(
          champ,
          candidats: <ZChatMentionCandidate>[
            _cand('zzz'),
            _cand('aaa'),
            _cand('mmm'),
          ],
        );
        addTearDown(c.dispose);

        champ.value = const TextEditingValue(
          text: '@x',
          selection: TextSelection.collapsed(offset: 2),
        );
        await Future<void>.delayed(Duration.zero);

        expect(
          c.state.value.entries.map((ZChatComposerAffordanceEntry e) => e.key),
          <String>['zzz', 'aaa', 'mmm'],
        );
      },
    );

    test('une amorce NON reconnue ne demande rien à la source', () async {
      final TextEditingController champ = TextEditingController();
      addTearDown(champ.dispose);
      final _Source src = _Source(<ZChatMentionCandidate>[_cand('c0')]);
      final ZChatComposerAffordanceController c = _ctrl(champ, source: src);
      addTearDown(c.dispose);

      champ.value = const TextEditingValue(
        text: 'bonjour',
        selection: TextSelection.collapsed(offset: 7),
      );
      await Future<void>.delayed(Duration.zero);

      expect(c.state.value.isOpen, isFalse);
      expect(src.requetes, isEmpty);
    });

    test('une source qui LÈVE laisse le panneau vide et expose la panne',
        () async {
      final TextEditingController champ = TextEditingController();
      addTearDown(champ.dispose);
      final ZChatComposerAffordanceController c = _ctrl(
        champ,
        source: _Source(const <ZChatMentionCandidate>[], throws: true),
      );
      addTearDown(c.dispose);

      champ.value = const TextEditingValue(
        text: '@x',
        selection: TextSelection.collapsed(offset: 2),
      );
      await Future<void>.delayed(Duration.zero);

      expect(c.state.value.entries, isEmpty);
      expect(c.state.value.failure, isNotNull);
    });

    test(
      '🔴 une COMMANDE est TRANSMISE, jamais exécutée : la saisie n\'est pas '
      'touchée et rien n\'est lancé',
      () async {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        final List<String> transmises = <String>[];
        final ZChatSlashCatalog cat = ZChatSlashCatalog(
          trigger: ZChatMentionTrigger(character: '/'),
          commands: <ZChatSlashCommand>[
            ZChatSlashCommand(key: 'resume', label: 'Résumer'),
            ZChatSlashCommand(key: 'traduire', label: 'Traduire'),
          ],
        );
        final ZChatComposerAffordanceController c = _ctrl(
          champ,
          catalog: cat,
          onCommand: (ZChatSlashCommand cmd, ZChatMentionMatch _) =>
              transmises.add(cmd.key),
        );
        addTearDown(c.dispose);

        champ.value = const TextEditingValue(
          text: '/re',
          selection: TextSelection.collapsed(offset: 3),
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          c.state.value.entries.map((ZChatComposerAffordanceEntry e) => e.key),
          <String>['resume', 'traduire'],
          reason: 'réduire la liste à ce qui est tapé serait FILTRER',
        );

        c.commit();

        expect(transmises, <String>['resume']);
        expect(
          champ.text,
          '/re',
          reason: '🔴 le socle n\'est pas un interpréteur : il ne réécrit même '
              'pas la saisie',
        );
      },
    );

    test(
      'un candidat sans `insertText` ne fait écrire AUCUN texte au socle',
      () async {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        final List<String> retenus = <String>[];
        final ZChatComposerAffordanceController c = _ctrl(
          champ,
          candidats: <ZChatMentionCandidate>[_cand('c0')],
          onCandidate: (ZChatMentionCandidate cd, ZChatMentionMatch _) =>
              retenus.add(cd.key),
        );
        addTearDown(c.dispose);

        champ.value = const TextEditingValue(
          text: 'avant @x',
          selection: TextSelection.collapsed(offset: 8),
        );
        await Future<void>.delayed(Duration.zero);
        c.commit();

        expect(retenus, <String>['c0']);
        expect(champ.text, 'avant @x');
      },
    );

    test(
      'un candidat AVEC `insertText` remplace le seul intervalle reconnu — le '
      'reste de la saisie est préservé',
      () async {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        final ZChatComposerAffordanceController c = _ctrl(
          champ,
          candidats: <ZChatMentionCandidate>[
            _cand('c0', insert: '@rapport.pdf'),
          ],
        );
        addTearDown(c.dispose);

        champ.value = const TextEditingValue(
          text: 'vois @ra et la suite',
          selection: TextSelection.collapsed(offset: 8),
        );
        await Future<void>.delayed(Duration.zero);
        c.commit();

        expect(champ.text, 'vois @rapport.pdf et la suite');
        expect(champ.selection.baseOffset, 'vois @rapport.pdf'.length);
      },
    );

    test('un candidat DÉSACTIVÉ n\'est pas retenu', () async {
      final TextEditingController champ = TextEditingController();
      addTearDown(champ.dispose);
      final List<String> retenus = <String>[];
      final ZChatComposerAffordanceController c = _ctrl(
        champ,
        candidats: <ZChatMentionCandidate>[
          _cand('c0', insert: 'X', disabled: 'quota'),
        ],
        onCandidate: (ZChatMentionCandidate cd, ZChatMentionMatch _) =>
            retenus.add(cd.key),
      );
      addTearDown(c.dispose);

      champ.value = const TextEditingValue(
        text: '@x',
        selection: TextSelection.collapsed(offset: 2),
      );
      await Future<void>.delayed(Duration.zero);
      c.commit();

      expect(retenus, isEmpty);
      expect(champ.text, '@x');
    });
  });

  group('L8 — INERTIE du composer, mesurée en ABSOLU', () {
    testWidgets(
      '🔴 sans rappel d\'historique NI déclencheur, le champ ne porte AUCUNE '
      'couche de raccourcis L8 — pas un `Shortcuts` inerte de plus',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(controller: rig.controller, cursorColor: _cursor),
          ),
        );

        // Mesure ABSOLUE : on énumère les activateurs réellement déclarés sous
        // le composer, et on affirme qu'AUCUN des quatre gestes L8 n'y est.
        // Aucun arbre témoin — un témoin serait affecté par la même injection.
        final Set<LogicalKeyboardKey> declares = <LogicalKeyboardKey>{
          for (final Shortcuts w in tester.widgetList<Shortcuts>(
            find.descendant(
              of: find.byType(ZChatComposer),
              matching: find.byType(Shortcuts),
            ),
          ))
            for (final ShortcutActivator a in w.shortcuts.keys)
              ...a.triggers ?? const <LogicalKeyboardKey>[],
        };
        for (final LogicalKeyboardKey k in <LogicalKeyboardKey>[
          LogicalKeyboardKey.arrowUp,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.escape,
        ]) {
          expect(
            declares,
            isNot(contains(k)),
            reason: '🔴 un hôte passif ne doit voir AUCUN geste changer : '
                '${k.keyLabel} est capté alors que rien n\'est déclaré',
          );
        }
      },
    );
  });

  group('L8 — la superposition, affordance conforme', () {
    Future<ZChatComposerAffordanceController> ouvrir(
      WidgetTester tester,
      TextEditingController champ, {
      List<ZChatMentionCandidate>? candidats,
    }) async {
      final ZChatComposerAffordanceController c = _ctrl(
        champ,
        candidats:
            candidats ??
            <ZChatMentionCandidate>[_cand('c0'), _cand('c1'), _cand('c2')],
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(ZChatComposerAffordanceOverlay(controller: c)),
      );
      champ.value = const TextEditingValue(
        text: '@x',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('FERMÉE, elle ne met AUCUNE ligne dans l\'arbre', (
      WidgetTester tester,
    ) async {
      final TextEditingController champ = TextEditingController();
      addTearDown(champ.dispose);
      final ZChatComposerAffordanceController c = _ctrl(champ);
      addTearDown(c.dispose);

      await tester.pumpWidget(
        harness(ZChatComposerAffordanceOverlay(controller: c)),
      );

      expect(
        find.descendant(
          of: find.byType(ZChatComposerAffordanceOverlay),
          matching: find.byType(ListView),
        ),
        findsNothing,
      );
    });

    testWidgets(
      '🔴 chaque candidat est une cible d\'au moins 48 dp — mesurée sur la '
      'boîte QUI REÇOIT LE GESTE, pas sur son texte',
      (WidgetTester tester) async {
        final TextEditingController champ = TextEditingController();
        addTearDown(champ.dispose);
        await ouvrir(tester, champ);

        for (final String k in <String>['c0', 'c1', 'c2']) {
          final Finder cible = find.byKey(
            ZChatComposerAffordanceOverlay.targetKey(k),
          );
          expect(cible, findsOneWidget);
          expect(
            tester.getSize(cible).height,
            greaterThanOrEqualTo(48.0),
            reason: '🔴 cible sous le plancher pour « $k »',
          );
          // Contre-mesure : le texte, lui, est BIEN plus petit — c'est la
          // preuve qu'on ne mesurait pas la mauvaise boîte.
          expect(
            tester
                .getSize(
                  find.descendant(of: cible, matching: find.byType(Text)).first,
                )
                .height,
            lessThan(48.0),
          );
        }
      },
    );

    testWidgets('la liste est ANNONCÉE et chaque ligne dit si elle est en avant',
        (WidgetTester tester) async {
      final SemanticsHandle poignee = tester.ensureSemantics();
      final TextEditingController champ = TextEditingController();
      addTearDown(champ.dispose);
      await ouvrir(tester, champ);

      expect(
        find.bySemanticsLabel(
          kZChatLabelFallbacks[kZChatLabelAffordanceCandidates]!,
        ),
        findsOneWidget,
        reason: '🔴 la liste doit être annoncée comme une liste de candidats',
      );

      // Mesuré sur le NŒUD de la ligne — celui qui reçoit le geste — et non
      // sur un texte quelconque de l'arbre.
      final SemanticsNode n0 = tester.getSemantics(
        find.byKey(ZChatComposerAffordanceOverlay.targetKey('c0')),
      );
      final SemanticsNode n1 = tester.getSemantics(
        find.byKey(ZChatComposerAffordanceOverlay.targetKey('c1')),
      );
      expect(n0.label, contains('libellé c0'));
      expect(
        n0,
        isSemantics(isSelected: true, isButton: true, isEnabled: true),
        reason: '🔴 la ligne mise en avant doit se DIRE mise en avant, et être '
            'annoncée comme un bouton disponible',
      );
      expect(n1, isSemantics(isSelected: false, isButton: true));
      poignee.dispose();
    });

    testWidgets(
      '🔴 le panneau qui s\'ouvre puis se ferme ne touche NI le focus, NI le '
      'texte, NI le curseur du champ',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final ZChatComposerAffordanceController panneau = _ctrl(
          rig.controller.composer,
          candidats: <ZChatMentionCandidate>[_cand('c0'), _cand('c1')],
        );
        addTearDown(panneau.dispose);
        final FocusNode noeud = FocusNode();
        addTearDown(noeud.dispose);

        await tester.pumpWidget(
          harness(
            Column(
              children: <Widget>[
                ZChatComposerAffordanceOverlay(controller: panneau),
                ZChatComposer(
                  controller: rig.controller,
                  cursorColor: _cursor,
                  focusNode: noeud,
                  affordance: panneau,
                ),
              ],
            ),
          ),
        );
        noeud.requestFocus();
        await tester.pump();
        final EditableText avant = tester.widget<EditableText>(
          find.byType(EditableText),
        );

        rig.controller.composer.value = const TextEditingValue(
          text: 'bonjour @x',
          selection: TextSelection.collapsed(offset: 10),
        );
        await tester.pumpAndSettle();
        expect(panneau.state.value.isOpen, isTrue);

        expect(noeud.hasFocus, isTrue, reason: '🔴 focus perdu à l\'ouverture');
        expect(rig.controller.composer.text, 'bonjour @x');
        expect(rig.controller.composer.selection.baseOffset, 10,
            reason: '🔴 curseur déplacé à l\'ouverture');
        expect(
          identical(
            tester.widget<EditableText>(find.byType(EditableText)).controller,
            avant.controller,
          ),
          isTrue,
          reason: '🔴 la tranche de saisie a été recréée',
        );

        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(panneau.state.value.isOpen, isFalse);
        expect(noeud.hasFocus, isTrue, reason: '🔴 focus perdu à la fermeture');
        expect(rig.controller.composer.text, 'bonjour @x');
        expect(rig.controller.composer.selection.baseOffset, 10);
      },
    );

    testWidgets(
      '🔴 navigation au CLAVIER : bas/haut parcourent, Entrée retient, et le '
      'parcours est BORNÉ aux extrémités',
      (WidgetTester tester) async {
        final rig = buildController();
        addTearDown(rig.controller.dispose);
        final List<String> retenus = <String>[];
        final ZChatComposerAffordanceController panneau = _ctrl(
          rig.controller.composer,
          candidats: <ZChatMentionCandidate>[_cand('c0'), _cand('c1')],
          onCandidate: (ZChatMentionCandidate c, ZChatMentionMatch _) =>
              retenus.add(c.key),
        );
        addTearDown(panneau.dispose);
        final FocusNode noeud = FocusNode();
        addTearDown(noeud.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              focusNode: noeud,
              affordance: panneau,
            ),
          ),
        );
        noeud.requestFocus();
        await tester.pump();
        rig.controller.composer.value = const TextEditingValue(
          text: '@x',
          selection: TextSelection.collapsed(offset: 2),
        );
        await tester.pumpAndSettle();
        expect(panneau.state.value.selectedIndex, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(panneau.state.value.selectedIndex, 1);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(panneau.state.value.selectedIndex, 1,
            reason: '🔴 le parcours est BORNÉ : pas d\'enroulement silencieux');

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();
        expect(panneau.state.value.selectedIndex, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(retenus, <String>['c0']);
        expect(panneau.state.value.isOpen, isFalse);
      },
    );

    testWidgets(
      '🔴 panneau FERMÉ, Entrée redevient le raccourci d\'envoi et la flèche '
      'haut redevient le rappel d\'historique',
      (WidgetTester tester) async {
        final rig = buildController(
          initialMessages: <ZChatMessage>[
            ZChatMessage(
              id: 'u1',
              conversationId: 'c1',
              role: ZChatRole.user,
              contentBlocks: <ZContentBlock>[
                ZTextBlock(text: 'question précédente'),
              ],
            ),
          ],
        );
        addTearDown(rig.controller.dispose);
        final ZChatComposerAffordanceController panneau = _ctrl(
          rig.controller.composer,
          candidats: <ZChatMentionCandidate>[_cand('c0')],
        );
        addTearDown(panneau.dispose);
        final FocusNode noeud = FocusNode();
        addTearDown(noeud.dispose);

        await tester.pumpWidget(
          harness(
            ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              focusNode: noeud,
              affordance: panneau,
              history: ZChatThreadHistory(rig.controller),
            ),
          ),
        );
        noeud.requestFocus();
        await tester.pump();

        // Panneau fermé (champ vide) : la flèche haut traverse la couche du
        // panneau, désactivée, et atteint le rappel d'historique.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pump();

        expect(panneau.state.value.isOpen, isFalse);
        expect(rig.controller.composer.text, 'question précédente');
      },
    );
  });
}
