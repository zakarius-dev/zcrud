// Gardes des CORRECTIONS DE FIN D'EPIC — chacune défend un défaut MESURÉ par
// la code-review à quatre lentilles, et rougit si le défaut revient.
//
// | Garde | Défaut d'origine |
// |---|---|
// | HIGH-1 | 12 clés sur 12 sans repli : `zchat.removeAttachment` s'affichait, `zchat.liveRegion` était ANNONCÉ |
// | HIGH-2 | le résumé exhaustif du kernel partait dans `AssistMessage.data`, champ INERTE |
// | MAJEUR-live | une réponse faite UNIQUEMENT de blocs donnait `ANNONCES=[]` |
// | MAJEUR-doublon | `Semantics(label:)` sans `excludeSemantics` ⇒ `<rapport.pdf\nrapport.pdf>` |
// | MAJEUR-AD10 | le kernel ABSORBAIT, les résolveurs PROPAGEAIENT : écran rouge d'un côté |
// | MEDIUM-fuite | `_release` ne libérait jamais les tranches : 400 `ValueNotifier` sur 200 tours |
//
// ⚠️ `@TestOn('vm')` : le volet SOURCE lit le disque via `dart:io`.
@TestOn('vm')
library;

import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

/// Renderer de blocs qui **lève** — la doublure du défaut d'hôte.
class _ExplodingRenderer extends ZChatRenderer {
  const _ExplodingRenderer();

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) =>
      throw StateError('renderer d\'hôte fautif');
}

/// Coquille qui **lève** — le jumeau exact, un étage plus haut.
class _ExplodingShell extends ZChatShellRenderer {
  const _ExplodingShell();

  @override
  Widget? buildShell(BuildContext context, ZChatShellRenderRequest request) =>
      throw StateError('coquille d\'hôte fautive');
}

/// Capte les erreurs relayées à `FlutterError` le temps d'un bloc.
Future<List<FlutterErrorDetails>> captureErrors(
  Future<void> Function() body,
) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

void main() {
  group('🔴 HIGH-1 — AUCUNE clé du chat sans repli lisible', () {
    test('volet CARTE — la carte des replis et la liste des clés sont ÉGALES '
        'en ensemble, et aucun repli n\'est la clé elle-même', () {
      expect(kZChatLabelFallbacks.keys.toSet(), kZChatLabelKeys.toSet(),
          reason: '🔴 une clé sans repli affiche son DISCRIMINANT MACHINE. '
              'Mesuré avant correction : `zchat.removeAttachment` rendu tel '
              'quel sur le bouton de retrait.');
      for (final MapEntry<String, String> e in kZChatLabelFallbacks.entries) {
        expect(e.value.trim(), isNotEmpty, reason: '🔴 repli VIDE : ${e.key}');
        expect(e.value, isNot(e.key),
            reason: '🔴 repli = clé : le défaut, déguisé en correctif.');
        expect(e.value, isNot(startsWith(kZChatLabelPrefix)),
            reason: '🔴 repli préfixé `zchat.` : c\'est encore une clé.');
      }
      // Non-vacuité : 10 clés, pas zéro.
      expect(kZChatLabelFallbacks, hasLength(greaterThanOrEqualTo(10)));
    });

    test('volet SOURCE — `label(` n\'est appelé QUE depuis `z_chat_labels.dart`',
        () {
      // 🔴 C'est ce qui rend « aucune clé sans repli » STRUCTUREL. Un nouvel
      // appel direct à `label(context, clé)` — même écrit par quelqu'un qui
      // « avait pensé » au repli — rougit ici, parce qu'il rouvre la porte par
      // laquelle les 12 clés étaient passées.
      final List<String> offenders = <String>[];
      for (final File f in libDartFiles()) {
        final String path = f.path.replaceAll(r'\', '/');
        if (path.endsWith('z_chat_labels.dart')) continue;
        final List<String> lines = stripped(f);
        for (int i = 0; i < lines.length; i++) {
          if (RegExp(r'(?<![\w.])label\s*\(\s*context').hasMatch(lines[i])) {
            offenders.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 appel DIRECT à `label(context, …)` hors du fichier de '
              'clés : passez par `zChatLabel`, qui porte le repli.\n'
              '${offenders.join('\n')}');

      // Volet NON-VACUITÉ : le fichier de clés, lui, DOIT en porter un —
      // sinon la garde ci-dessus passerait sur un package qui ne résout plus
      // aucun libellé.
      final String labels = stripped(
        libFile('view/z_chat_labels.dart'),
      ).join('\n');
      expect(labels, contains('fallback: kZChatLabelFallbacks[key]'),
          reason: '🔴 GARDE VACUELLE : le résolveur unique ne passe plus de '
              'repli — les 12 clés seraient de nouveau nues.');

      // 🔬 CONTRE-PREUVE : le motif VOIT un appel direct.
      expect(
        RegExp(r'(?<![\w.])label\s*\(\s*context')
            .hasMatch('      child: Text(label(context, kZChatLabelSources)),'),
        isTrue,
        reason: '🔴 le motif est aveugle : la garde serait décorative.',
      );
      // …et n'accuse PAS le résolveur unique ni un appel qualifié.
      expect(
        RegExp(r'(?<![\w.])label\s*\(\s*context')
            .hasMatch('    zChatLabel(context, kZChatLabelSources)'),
        isFalse,
        reason: '🔴 FAUX POSITIF sur `zChatLabel` — une garde qui crie au loup '
            'finit désactivée.',
      );
    });

    testWidgets('volet RENDU — sans registre, AUCUNE clé brute n\'atteint '
        'l\'écran ni l\'arbre sémantique', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZSourcesBlock(),
              const ZSuggestionsBlock(),
              const ZMermaidDiagramBlock(code: 'graph TD'),
              ZCustomContentBlock('legalReference', const <String, dynamic>{}),
            ]),
            collapsedMaxHeight: 40,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final String texte in renderedTexts(tester)) {
        expect(texte, isNot(startsWith(kZChatLabelPrefix)),
            reason: '🔴 CLÉ BRUTE AFFICHÉE : "$texte" — le défaut HIGH-1.');
      }
      // …et la sémantique non plus : c'est là que `zchat.liveRegion` était
      // ANNONCÉ à un lecteur d'écran.
      final SemanticsNode? fautif = findSemantics(
        tester,
        (SemanticsNode n) => n.label.contains(kZChatLabelPrefix),
      );
      expect(fautif, isNull,
          reason: '🔴 CLÉ BRUTE ANNONCÉE : "${fautif?.label}".');
      // Non-vacuité : le rendu a bien produit des mots.
      expect(renderedTexts(tester).where((String t) => t.isNotEmpty), isNotEmpty);
      handle.dispose();
    });

    testWidgets('volet RENDU — la région live annonce le REPLI, jamais '
        '`zchat.liveRegion`', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController();
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      await tester.pumpWidget(
        harness(ZChatConversationView(controller: rig.controller)),
      );
      await tester.pumpAndSettle();
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == kZChatLabelFallbacks[kZChatLabelLiveRegion],
        ),
        isNotNull,
        reason: '🔴 la région live n\'annonce pas son repli lisible — c\'est '
            'exactement là que `zchat.liveRegion` était énoncé.',
      );
      handle.dispose();
    });
  });

  group('🔴 HIGH-2 — le résumé du kernel est ANNONCÉ, pas seulement calculé',
      () {
    testWidgets('un message fait UNIQUEMENT d\'un tableau porte un nœud '
        'sémantique qui en contient les cellules', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(const <ZContentBlock>[
              ZTableBlock(
                headers: <String>['code', 'droit'],
                rows: <List<String>>[
                  <String>['0101', 'cinq'],
                ],
              ),
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final SemanticsNode? node = findSemantics(
        tester,
        (SemanticsNode n) => n.label.contains('0101') && n.label.contains('code'),
      );
      expect(node, isNotNull,
          reason: '🔴 le résumé exhaustif du kernel n\'est annoncé NULLE PART. '
              'C\'est le défaut HIGH-2 : il partait dans `AssistMessage.data`, '
              'que `syncfusion_flutter_chat` ne lit que dans la branche `else` '
              'de son constructeur de contenu — celle qu\'un '
              '`messageContentBuilder` court-circuite toujours.');
      handle.dispose();
    });

    testWidgets('le résolveur de l\'hôte atteint l\'ANNONCE, pas seulement un '
        'champ de données', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          ZChatAccessibleTextScope(
            resolver: (ZContentBlock b) =>
                b.kind == 'legalReference' ? 'référence juridique' : null,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[
                ZCustomContentBlock('legalReference', const <String, dynamic>{}),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) => n.label.contains('référence juridique'),
        ),
        isNotNull,
        reason: '🔴 le seam d\'annonce de l\'hôte n\'est pas énoncé : un bloc '
            'OUVERT reste annoncé par son discriminant machine.',
      );
      handle.dispose();
    });

    testWidgets('le nœud d\'annonce N\'AVALE PAS la sémantique du bouton de '
        'dépli', (WidgetTester tester) async {
      // 🔴 `excludeSemantics: true` est nécessaire (sans lui, résumé ET texte
      // des blocs sont énoncés), mais il ne doit couvrir QUE le corps : le
      // bouton est un frère, pas un descendant. Une régression ici échangerait
      // un doublon contre une action inatteignable au lecteur d'écran.
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 60,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Le nœud de BOUTON et son libellé sont deux nœuds voisins (Flutter ne
      // les fusionne pas ici) : on exige les DEUX. Si l'exclusion avait
      // débordé, ni l'un ni l'autre ne subsisterait.
      expect(
        collectSemantics(tester, (SemanticsNode n) => n.flagsCollection.isButton),
        isNotEmpty,
        reason: '🔴 le bouton de dépli n\'est plus un BOUTON pour le lecteur '
            'd\'écran : l\'exclusion sémantique du corps a débordé sur lui.',
      );
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == kZChatLabelFallbacks[kZChatLabelShowMore],
        ),
        isNotNull,
        reason: '🔴 le libellé du bouton de dépli est MUET.',
      );
      handle.dispose();
    });

    testWidgets('`announce: false` rend la main à l\'hôte (blocs INTERACTIFS)',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          const ZChatAccessibleTextScope(
            resolver: null,
            announce: false,
            child: ZChatMessageTile(
              message: ZChatMessage(
                id: 'm1',
                conversationId: 'c1',
                role: ZChatRole.assistant,
                contentBlocks: <ZContentBlock>[ZTextBlock(text: 'corps')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Le texte reste annoncé par SON PROPRE nœud — donc rien n'est perdu ;
      // seul le nœud de résumé du socle disparaît.
      expect(
        findSemantics(tester, (SemanticsNode n) => n.label == 'corps'),
        isNotNull,
      );
      handle.dispose();
    });
  });

  group('🔴 MAJEUR — la région live annonce AUSSI les réponses sans texte', () {
    testWidgets('un tour fait UNIQUEMENT de blocs produit une annonce NON VIDE',
        (WidgetTester tester) async {
      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController();
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      final List<String> annonces = <String>[];
      rig.controller.liveAnnouncement.addListener(
        () => annonces.add(rig.controller.liveAnnouncement.value),
      );

      rig.controller.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> envoi = rig.controller.send();
      await tester.pump();
      // AUCUN `ZChatTokenEvent` : la réponse est un TABLEAU, la forme même que
      // produit la chaîne de lex (taxation, sources).
      rig.port.last.add(
        Right<ZFailure, ZChatStreamEvent>(
          const ZChatContentBlockEvent(
            block: ZTableBlock(
              headers: <String>['code'],
              rows: <List<String>>[
                <String>['0101'],
              ],
            ),
          ),
        ),
      );
      rig.port.last.add(
        Right<ZFailure, ZChatStreamEvent>(
          const ZChatDoneEvent(messageId: 'a1', conversationId: 'c1'),
        ),
      );
      await tester.pumpAndSettle();
      await envoi;

      expect(annonces.where((String a) => a.isNotEmpty), isNotEmpty,
          reason: '🔴 `ANNONCES=[]` — la dette d\'IFFD (0 `Semantics` sur son '
              'chat) reproduite sur notre rendu neutre : une réponse faite de '
              'blocs était MUETTE alors que `zChatAccessibleTextOf` existait.');
      expect(rig.controller.liveAnnouncement.value, contains('0101'),
          reason: '🔴 l\'annonce ne porte pas le CONTENU du bloc.');
    });
  });

  group('🔴 MAJEUR — aucune DOUBLE annonce sur la bande de pièces jointes', () {
    testWidgets('le nom du fichier est énoncé UNE fois, et le retrait reste '
        'un bouton', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ZChatAttachmentController strip = ZChatAttachmentController();
      addTearDown(strip.dispose);
      strip.add(
        ZPendingAttachment(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          fileName: 'rapport.pdf',
          mimeType: 'application/pdf',
        ),
      );
      await tester.pumpWidget(
        harness(ZChatAttachmentStrip(controller: strip)),
      );
      await tester.pumpAndSettle();

      final List<SemanticsNode> nommants = collectSemantics(
        tester,
        (SemanticsNode n) => n.label.contains('rapport.pdf'),
      );
      expect(nommants, hasLength(1),
          reason: '🔴 DOUBLE ANNONCE mesurée : `<rapport.pdf\\nrapport.pdf>`. '
              'Le nœud portait `label:` SANS `excludeSemantics`, et son enfant '
              '`Text` répétait le même nom. Nœuds fautifs : '
              '${nommants.map((SemanticsNode n) => n.label).toList()}');
      expect(nommants.single.label, 'rapport.pdf',
          reason: '🔴 le libellé est CONCATÉNÉ avec lui-même.');
      // Contre-partie NON NÉGOCIABLE : l'exclusion n'a pas mangé le bouton.
      expect(
        collectSemantics(tester, (SemanticsNode n) => n.flagsCollection.isButton),
        isNotEmpty,
        reason: '🔴 le bouton de retrait n\'est plus un BOUTON : on aurait '
            'échangé un doublon contre une action inatteignable. C\'est '
            'précisément pourquoi il est passé HORS du nœud excluant.',
      );
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == kZChatLabelFallbacks[kZChatLabelRemoveAttachment],
        ),
        isNotNull,
        reason: '🔴 le libellé du retrait est MUET.',
      );
      handle.dispose();
    });
  });

  group('🔴 MAJEUR — AD-10 : les DEUX seams de rendu ABSORBENT, comme le kernel',
      () {
    testWidgets('un renderer de BLOCS qui lève ⇒ rendu neutre, pas d\'écran '
        'rouge', (WidgetTester tester) async {
      final List<FlutterErrorDetails> relayes = await captureErrors(() async {
        await tester.pumpWidget(
          harness(
            ZChatMessageTile(
              message: assistant(const <ZContentBlock>[
                ZTextBlock(text: 'contenu neutre'),
              ]),
            ),
            renderer: const _ExplodingRenderer(),
          ),
        );
        await tester.pumpAndSettle();
      });
      expect(tester.takeException(), isNull,
          reason: '🔴 l\'exception de l\'hôte a EMPORTÉ le rendu — alors que '
              'le seam JUMEAU du kernel (`accessibleText`) l\'absorbe. Deux '
              'lectures d\'AD-10 dans le même lot.');
      expect(find.text('contenu neutre'), findsOneWidget,
          reason: '🔴 le rendu neutre n\'a pas pris le relais.');
      expect(relayes, isNotEmpty,
          reason: '🔴 ABSORPTION SILENCIEUSE : l\'hôte ne peut plus déboguer '
              'son renderer. L\'exception DOIT être relayée à `FlutterError`.');
      expect(relayes.first.toString(), contains(kZChatSeamBlock),
          reason: '🔴 le rapport ne NOMME pas le seam fautif.');
    });

    testWidgets('une COQUILLE qui lève ⇒ liste neutre (le défaut AD-57 reste '
        'fonctionnel)', (WidgetTester tester) async {
      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(const <ZContentBlock>[ZTextBlock(text: 'contenu neutre')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      final List<FlutterErrorDetails> relayes = await captureErrors(() async {
        await tester.pumpWidget(
          harness(
            ZChatConversationView(controller: rig.controller),
            shell: const _ExplodingShell(),
          ),
        );
        await tester.pumpAndSettle();
      });
      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsOneWidget,
          reason: '🔴 une coquille tierce qui lève ne retombait JAMAIS sur la '
              'liste neutre — la promesse AD-57 était fausse.');
      expect(find.text('contenu neutre'), findsOneWidget);
      expect(relayes, isNotEmpty);
      expect(relayes.first.toString(), contains(kZChatSeamShell));
    });

    test('volet SOURCE — les deux résolveurs portent un `catch`, comme le '
        'kernel', () {
      for (final String f in <String>[
        'render/z_chat_renderer_scope.dart',
        'render/z_chat_shell_renderer_scope.dart',
      ]) {
        final String src = stripped(libFile(f)).join('\n');
        expect(src, contains('catch'),
            reason: '🔴 $f a REPERDU son absorption : le seam propage de '
                'nouveau, et diverge du kernel.');
        expect(src, contains('zChatReportSeamFailure'),
            reason: '🔴 $f absorbe SANS relayer : indébogable pour l\'hôte.');
      }
    });
  });

  group('🔴 MEDIUM — la rétention des tranches par requête est BORNÉE', () {
    testWidgets('après de nombreux tours, les tranches anciennes sont '
        'DISPOSÉES et les récentes conservées', (WidgetTester tester) async {
      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController();
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);

      final List<String> ids = <String>[];
      final List<ValueListenable<String>> tranches = <ValueListenable<String>>[];
      for (int i = 0; i < 40; i++) {
        rig.controller.composer.text = 'q$i';
        final Future<ZResult<ZChatRequestToken>> envoi = rig.controller.send();
        final String id = rig.controller.activeRequests.value.last;
        ids.add(id);
        tranches.add(rig.controller.streamText(id));
        rig.port.last.add(tok('réponse $i'));
        rig.port.last.add(
          Right<ZFailure, ZChatStreamEvent>(
            ZChatDoneEvent(messageId: 'a$i', conversationId: 'c1'),
          ),
        );
        await tester.pumpAndSettle();
        await envoi;
      }

      // La tranche du PREMIER tour est sortie de la fenêtre : elle a été
      // disposée (un `addListener` sur un `ValueNotifier` disposé LÈVE), et
      // `streamText` en rend désormais une NOUVELLE instance.
      expect(() => (tranches.first as ValueNotifier<String>).addListener(() {}),
          throwsA(isA<FlutterError>()),
          reason: '🔴 FUITE : `_release` ne libérait jamais les tranches. '
              '200 tours ⇒ 400 `ValueNotifier` retenus, chacun gardant le '
              'texte INTÉGRAL d\'une réponse déjà stockée dans `messages`.');
      expect(identical(rig.controller.streamText(ids.first), tranches.first),
          isFalse);

      // …et la fenêtre de transition existe TOUJOURS : la tranche du DERNIER
      // tour reste vivante et stable par identité (sans quoi on aurait corrigé
      // la fuite en cassant SM-1).
      expect(identical(rig.controller.streamText(ids.last), tranches.last),
          isTrue,
          reason: '🔴 la tranche du tour qui vient de finir a été libérée trop '
              'tôt : un widget en cours de démontage l\'écoute encore.');
      expect(
        () => (tranches.last as ValueNotifier<String>).addListener(() {}),
        returnsNormally,
      );
    });
  });
}
