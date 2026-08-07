/// Lot γ0/δ (CR-IFFD-72) — **comportement** du raccord des réglages et de la
/// feuille par défaut.
///
/// Ce que ce fichier MESURE, sur un sujet réellement monté :
/// * **SET-A** — le RACCORD : `send()` sans réglages produit une requête
///   **identique** (au sens de `identical`) à celle du builder de l'hôte ; avec
///   réglages, ils atteignent la requête **même si le builder en avait posé
///   d'autres** ; et un hôte non opté à `ZChatSettingsAwareActionExecutor`
///   reçoit une **failure explicite**, jamais un repli muet ;
/// * **SET-S** — la FEUILLE : rendu par défaut, tuile remplaçable, tuile
///   **retirée** quand son builder rend `null` (AD-4), et le retour à « l'hôte
///   décide » — le geste que `copyWith` ne sait pas exprimer ;
/// * **SET-G** — AD-13 : une option mesure ≥ 48 dp **en géométrie rendue** et
///   reste bornée par le haut ;
/// * **SET-T** — priorité **paramètre > jeton > référence**, les TROIS niveaux
///   atteints séparément ;
/// * **SET-M** — SM-1 : ouvrir, régler puis fermer la feuille ne reconstruit
///   **aucune** tuile de conversation ;
/// * **SET-R** — sémantique (l'état choisi est dans l'arbre, pas seulement à
///   l'écran) et RTL ;
/// * **SET-C** — la composition RÉELLE feuille ↔ composer : un réglage choisi
///   dans la feuille se retrouve sur la requête ouverte par la touche
///   « valider » du clavier.
library;

import 'dart:async';

import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Couleur de curseur du TEST — le socle n'en invente aucune (FR-26).
const Color _cursor = Color(0xFF123456);

/// Clés de corpus **fictives** : le socle ne connaît aucun corpus réel, et ce
/// test ne doit pas en introduire un (aucune valeur métier, ni ici ni dans
/// `lib/`).
const String _kAlpha = 'corpus-alpha';
const String _kBeta = 'corpus-beta';

/// Catalogue d'HÔTE — libellés déjà résolus par lui.
const List<ZChatCorpusOption> _catalogue = <ZChatCorpusOption>[
  ZChatCorpusOption(key: _kAlpha, label: 'Alpha'),
  ZChatCorpusOption(key: _kBeta, label: 'Beta'),
];

/// Exécuteur **OPTÉ** : il implémente l'interface sœur du lot β.
class _AwareExecutor extends SpyExecutor
    implements ZChatSettingsAwareActionExecutor {
  /// Les actions reçues ENTIÈRES (donc avec leurs réglages).
  final List<ZChatRegenerateAction> rich = <ZChatRegenerateAction>[];

  @override
  Future<ZResult<List<String>>> regenerateWithSettings(
    ZChatRegenerateAction action,
  ) async {
    rich.add(action);
    return Right<ZFailure, List<String>>(const <String>['m1']);
  }
}

/// Monte [child] avec un `ZcrudScope` porteur d'un **jeton de thème** — le
/// niveau 2 de la priorité (le harnais commun n'en installe aucun).
Widget themed(Widget child, {required ZcrudTheme theme}) => harnessThemed(
  child,
  theme: theme,
);

/// Variante locale du harnais : `harness()` n'expose pas `theme`.
Widget harnessThemed(
  Widget child, {
  required ZcrudTheme? theme,
  TextDirection direction = TextDirection.ltr,
  Map<String, String>? labels,
}) {
  Widget tree = child;
  if (theme != null || labels != null) {
    tree = ZcrudScope(
      theme: theme,
      labels: labels == null ? null : ZcrudLabels(labels),
      child: tree,
    );
  }
  return harness(tree, direction: direction);
}

/// Un contrôleur dont le builder d'hôte est PILOTÉ par le test.
({
  ZChatController controller,
  FakeStreamPort port,
  SpyExecutor executor,
  List<ZChatGenerationRequest> built,
})
rigWith({
  ZChatResponseLength? responseLength,
  ZChatCorpusScope? corpusScope,
  SpyExecutor? executor,
}) {
  final FakeStreamPort port = FakeStreamPort();
  final SpyExecutor spy = executor ?? SpyExecutor();
  final List<ZChatGenerationRequest> built = <ZChatGenerationRequest>[];
  int n = 0;
  final ZChatController controller = ZChatController(
    streamPort: port,
    actionExecutor: spy,
    confirm: (ZChatActionPlan plan) async => true,
    newRequestId: () => 'r${n++}',
    buildRequest: (ZChatDraft draft) {
      final ZChatGenerationRequest r = ZChatGenerationRequest(
        style: ZChatGenerationStyle('test'),
        subject: draft.text,
        responseLength: responseLength,
        corpusScope: corpusScope,
      );
      built.add(r);
      return r;
    },
  );
  return (controller: controller, port: port, executor: spy, built: built);
}

/// La feuille, montée seule.
ZChatSettingsSheet sheet(
  ZChatSettingsController c, {
  List<ZChatCorpusOption> catalogue = const <ZChatCorpusOption>[],
  ZChatSettingsTileBuilder? responseLengthBuilder,
  EdgeInsetsDirectional? padding,
  double? spacing,
}) => ZChatSettingsSheet(
  controller: c,
  corpusCatalog: catalogue,
  responseLengthBuilder: responseLengthBuilder,
  padding: padding,
  spacing: spacing,
);

/// Le repli français d'une clé — l'unique carte auditée du paquet.
String fb(String key) => kZChatLabelFallbacks[key]!;

void main() {
  group('🔴 SET-A — le RACCORD : les réglages atteignent la requête, et une '
      'absence de réglages ne change RIEN', () {
    testWidgets('SET-A1 — `send()` SANS réglages envoie au port l\'objet MÊME '
        'que le builder a construit (identité, pas égalité)', (
      WidgetTester tester,
    ) async {
      final rig = rigWith(responseLength: ZChatResponseLength.detailed);
      addTearDown(rig.controller.dispose);
      rig.controller.composer.text = 'bonjour';
      // 🔴 `send()` ne se termine qu'au TERME du flux : l'attendre ici
      // BLOQUERAIT le test. Le patron du paquet est de lancer puis de pomper.
      unawaited(rig.controller.send());
      await tester.pump();

      expect(rig.built, hasLength(1));
      expect(rig.port.calls, hasLength(1));
      expect(
        identical(rig.port.calls.single.request, rig.built.single),
        isTrue,
        reason: '🔴 LE DÉFAUT A BOUGÉ. Sans argument, `send()` doit rendre au '
            'port la requête du builder TELLE QUELLE — `withSettings(null)` '
            'rend `identical(this)`. Une copie, même égale, prouverait qu\'un '
            'chemin de recomposition s\'est glissé sur le trajet.',
      );
      await rig.port.closeAll();
      await tester.pump();
    });

    testWidgets('SET-A2 — les réglages passés ARRIVENT, et ils GOUVERNENT : le '
        'builder de l\'hôte ne peut pas les jeter', (WidgetTester tester) async {
      // Le builder pose délibérément un AUTRE réglage : c'est la forme exacte
      // du défaut IFFD (des drapeaux transmis, puis remplacés/jetés en aval).
      final rig = rigWith(responseLength: ZChatResponseLength.detailed);
      addTearDown(rig.controller.dispose);
      final ZChatGenerationSettings wanted = ZChatGenerationSettings(
        responseLength: ZChatResponseLength.concise,
        computeEffort: ZChatComputeEffort(4),
        revealThinkingSteps: true,
      );
      rig.controller.composer.text = 'bonjour';
      unawaited(rig.controller.send(settings: wanted));
      await tester.pump();

      final ZChatGenerationRequest sent = rig.port.calls.single.request;
      expect(sent.settings, wanted,
          reason: '🔴 les réglages n\'ont pas atteint la requête : c\'est le '
              'défaut de l\'étude (§ 1.1), rejoué dans le socle');
      expect(sent.responseLength, ZChatResponseLength.concise,
          reason: '🔴 le réglage du BUILDER a gagné : la feuille ne '
              'gouvernerait donc rien');
      expect(sent.computeEffort?.level, 4);
      expect(sent.revealThinkingSteps, isTrue);
      await rig.port.closeAll();
      await tester.pump();
    });

    testWidgets('SET-A3 — la portée passée ARRIVE ; la portée du builder n\'est '
        'PAS effacée par une absence d\'argument', (WidgetTester tester) async {
      final ZChatCorpusScope fromBuilder = ZChatCorpusScope.ofKeys(
        const <String>[_kAlpha],
      );
      final rig = rigWith(corpusScope: fromBuilder);
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'a';
      unawaited(rig.controller.send());
      await tester.pump();
      expect(rig.port.calls[0].request.corpusScope, fromBuilder,
          reason: '🔴 `send()` sans portée a ÉLARGI la portée du builder : une '
              'absence d\'argument n\'est pas une demande d\'élargissement');

      final ZChatCorpusScope wanted = ZChatCorpusScope.ofKeys(
        const <String>[_kBeta],
      );
      rig.controller.composer.text = 'b';
      unawaited(rig.controller.send(corpusScope: wanted));
      await tester.pump();
      expect(rig.port.calls[1].request.corpusScope, wanted);
      expect(rig.port.calls[1].request.corpusScope!.corpusKeys, <String>[_kBeta]);
      await rig.port.closeAll();
      await tester.pump();
    });

    testWidgets('🔴 SET-A4 — un hôte NON OPTÉ reçoit une FAILURE EXPLICITE, '
        'jamais un repli muet', (WidgetTester tester) async {
      final rig = rigWith();
      addTearDown(rig.controller.dispose);

      final ZResult<ZChatActionOutcome> out = await rig.controller.runAction(
        ZChatRegenerateAction(
          messageId: 'm1',
          settings: const ZChatGenerationSettings(
            responseLength: ZChatResponseLength.concise,
          ),
        ),
      );

      expect(
        out.fold((ZFailure f) => f, (ZChatActionOutcome _) => null),
        isA<ZUnsupportedOperationFailure>(),
        reason: '🔴 REPLI MUET. Un exécuteur qui n\'implémente pas '
            '`ZChatSettingsAwareActionExecutor` ne doit PAS voir sa '
            'régénération dégradée en silence : l\'hôte croirait avoir réglé '
            'la longueur alors que sa demande a été jetée. C\'est exactement '
            'ce que fait `IffdAiRepositoryImpl` avec ses six drapeaux de '
            'corpus.',
      );
      expect(rig.controller.lastFailure.value,
          isA<ZUnsupportedOperationFailure>(),
          reason: '🔴 l\'échec doit être LISIBLE par l\'UI, pas seulement '
              'rendu à l\'appelant');
      expect(rig.executor.calls['regenerate'], isNull,
          reason: '🔴 GARDE VACUELLE INVERSÉE : la régénération a QUAND MÊME '
              'eu lieu, sans les réglages. C\'est le repli muet, avec une '
              'failure en prime.');
    });

    testWidgets('SET-A5 — un hôte OPTÉ reçoit l\'action ENTIÈRE', (
      WidgetTester tester,
    ) async {
      final _AwareExecutor aware = _AwareExecutor();
      final rig = rigWith(executor: aware);
      addTearDown(rig.controller.dispose);
      final ZChatCorpusScope scope = ZChatCorpusScope.ofKeys(
        const <String>[_kAlpha],
      );

      final ZResult<ZChatActionOutcome> out = await rig.controller.runAction(
        ZChatRegenerateAction(
          messageId: 'm1',
          settings: const ZChatGenerationSettings(
            lengthBias: ZChatLengthBias.longer,
          ),
          corpusScope: scope,
        ),
      );

      expect(out.isRight(), isTrue);
      expect(aware.rich, hasLength(1));
      expect(aware.rich.single.settings?.lengthBias, ZChatLengthBias.longer,
          reason: '🔴 le BIAIS de régénération — celui que l\'étude a mesuré '
              '« structurellement inatteignable sur son propre cas d\'usage » '
              '— n\'arrive toujours pas chez l\'hôte');
      expect(aware.rich.single.corpusScope, scope);
      expect(aware.calls['regenerate'], isNull);
    });

    testWidgets('SET-A6 — une régénération SANS réglages emprunte le chemin '
        'd\'AVANT, y compris chez un hôte opté', (WidgetTester tester) async {
      final _AwareExecutor aware = _AwareExecutor();
      final rig = rigWith(executor: aware);
      addTearDown(rig.controller.dispose);

      final ZResult<ZChatActionOutcome> out = await rig.controller.runAction(
        const ZChatRegenerateAction(messageId: 'm1'),
      );

      expect(out.isRight(), isTrue);
      expect(aware.calls['regenerate'], 1,
          reason: '🔴 le chemin historique a été détourné : un hôte qui ne '
              'règle rien doit voir EXACTEMENT le même appel qu\'avant le lot');
      expect(aware.rich, isEmpty);
    });
  });

  group('🔴 SET-S — la FEUILLE : composable, et le retrait exprimable', () {
    testWidgets('SET-S1 — rendu par défaut : les quatre axes du kernel, et '
        'AUCUNE tuile de corpus sans catalogue (AD-4)', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(sheet(c)));

      for (final String key in <String>[
        kZChatLabelResponseLength,
        kZChatLabelLengthBias,
        kZChatLabelComputeBudget,
        kZChatLabelRevealThinking,
      ]) {
        expect(find.text(fb(key)), findsWidgets, reason: 'axe absent : $key');
      }
      expect(
        find.text(fb(kZChatLabelCorpusScope)),
        findsNothing,
        reason: '🔴 le socle ne connaît AUCUN corpus : proposer une portée '
            'documentaire vide laisserait croire qu\'il en propose une.',
      );
      // Les cinq paliers `1..5` viennent des BORNES du kernel, pas d'une liste
      // recopiée : si le kernel élargissait, la feuille suivrait.
      for (int i = ZChatComputeEffort.min; i <= ZChatComputeEffort.max; i++) {
        expect(find.text('Niveau $i'), findsOneWidget);
      }
    });

    testWidgets('SET-S2 — avec catalogue, la portée apparaît, libellée par '
        'l\'HÔTE', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(sheet(c, catalogue: _catalogue)));

      expect(find.text(fb(kZChatLabelCorpusScope)), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text(fb(kZChatLabelCorpusAll)), findsOneWidget,
          reason: '🔴 « aucune restriction » doit être RENDUE : une portée '
              'vide qui n\'apparaît pas est indiscernable d\'une portée '
              'oubliée');
    });

    testWidgets('SET-S3 — un builder REMPLACE la tuile ; un builder qui rend '
        '`null` la RETIRE de l\'arbre (AD-4)', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);

      // (a) remplacement
      await tester.pumpWidget(
        harness(
          sheet(
            c,
            responseLengthBuilder:
                (BuildContext context, ZChatSettingsSlot slot) =>
                    const SizedBox(key: ValueKey<String>('mine'), height: 3),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('mine')), findsOneWidget);
      expect(find.text(fb(kZChatLabelResponseLength)), findsNothing,
          reason: '🔴 le défaut du socle est resté À CÔTÉ du remplacement');

      // (b) retrait — et on COMPTE les enfants réels, on ne devine pas.
      final int withTile = tester
          .widget<Column>(
            find
                .descendant(
                  of: find.byType(ZChatSettingsSheet),
                  matching: find.byType(Column),
                )
                .first,
          )
          .children
          .length;
      await tester.pumpWidget(
        harness(
          sheet(
            c,
            responseLengthBuilder:
                (BuildContext context, ZChatSettingsSlot slot) => null,
          ),
        ),
      );
      final int without = tester
          .widget<Column>(
            find
                .descendant(
                  of: find.byType(ZChatSettingsSheet),
                  matching: find.byType(Column),
                )
                .first,
          )
          .children
          .length;
      expect(find.byKey(const ValueKey<String>('mine')), findsNothing);
      expect(find.text(fb(kZChatLabelResponseLength)), findsNothing);
      expect(without, lessThan(withTile),
          reason: '🔴 AD-4 : un builder qui rend `null` doit retirer la tuile '
              'de l\'ARBRE, pas y laisser un `SizedBox.shrink()` inerte. '
              'Enfants : $withTile → $without');
    });

    testWidgets('SET-S4 — taper une option RÈGLE, et « Automatique » RETIRE le '
        'réglage — le geste que `copyWith` ne sait pas exprimer', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController(
        settings: const ZChatGenerationSettings(
          responseLength: ZChatResponseLength.standard,
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(sheet(c)));

      await tester.tap(find.text(fb(kZChatLabelLengthDetailed)));
      await tester.pump();
      expect(c.settings.value.responseLength, ZChatResponseLength.detailed);

      await tester.tap(find.text('Niveau 5'));
      await tester.pump();
      expect(c.settings.value.computeEffort?.level, 5);

      // 🔴 LE cas : revenir à « l'hôte décide ». `copyWith(responseLength: null)`
      // est indistinguable d'un paramètre omis ; seule une construction
      // explicite le permet, et c'est ce que le contrôleur fait.
      await tester.tap(find.text(fb(kZChatLabelSettingAuto)).first);
      await tester.pump();
      expect(c.settings.value.responseLength, isNull,
          reason: '🔴 le réglage n\'est pas RETIRABLE : l\'utilisateur ne peut '
              'plus jamais revenir au défaut du fournisseur');
      expect(c.settings.value.computeEffort?.level, 5,
          reason: '🔴 « Automatique » d\'un axe a effacé un AUTRE axe : les '
              'quatre réglages sont indépendants');
    });

    testWidgets('SET-S5 — cocher un corpus construit une portée en CLÉS ; tout '
        'décocher la retire (« vide ⇒ tout »)', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(sheet(c, catalogue: _catalogue)));

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(c.corpusScope.value?.corpusKeys, <String>[_kAlpha],
          reason: '🔴 la portée doit porter la CLÉ stable, jamais le libellé — '
              'sans quoi elle ne serait pas confrontable aux sources rendues');
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(c.corpusScope.value?.corpusKeys, <String>[_kAlpha, _kBeta]);

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(c.corpusScope.value, isNull,
          reason: '🔴 une sélection VIDE ne veut pas dire « aucun corpus » : '
              'elle veut dire « tous » (sémantique portée de lex). Une portée '
              'vide non nulle interdirait TOUT.');
    });
  });

  group('🔴 SET-G — AD-13 : la cible d\'une option, en géométrie RENDUE', () {
    testWidgets('SET-G1 — ≥ 48 dp, et BORNÉE PAR LE HAUT', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(sheet(c)));

      final Size box = tester.getSize(
        find
            .ancestor(
              of: find.text(fb(kZChatLabelLengthConcise)),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(box.height, greaterThanOrEqualTo(kZChatMinTapTarget),
          reason: '🔴 le FAB d\'envoi du legacy IFFD mesure 40 dp. Ce plancher '
              'est ce qui rend cette valeur inexprimable ici.');
      expect(box.width, greaterThanOrEqualTo(kZChatMinTapTarget));
      expect(box.width, lessThan(400),
          reason: '🔴 la cible occupe TOUTE la ligne : le `widthFactor` est '
              'inerte et la garde ci-dessus passe pour la mauvaise raison — '
              'le précédent exact de `z_chat_diffusion_bar.dart`.');
    });
  });

  group('🔴 SET-T — priorité **paramètre > jeton > référence**, les TROIS '
      'niveaux atteints', () {
    Future<(EdgeInsetsGeometry, double)> measure(
      WidgetTester tester,
      Widget tree,
    ) async {
      await tester.pumpWidget(tree);
      final Padding pad = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(ZChatSettingsSheet),
              matching: find.byType(Padding),
            )
            .first,
      );
      final Wrap wrap = tester.widget<Wrap>(
        find
            .descendant(
              of: find.byType(ZChatSettingsSheet),
              matching: find.byType(Wrap),
            )
            .first,
      );
      return (pad.padding, wrap.spacing);
    }

    testWidgets('SET-T1 — le PARAMÈTRE l\'emporte sur le jeton', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final ZcrudTheme token = const ZcrudTheme().copyWith(
        gapS: 33,
        formPadding: const EdgeInsetsDirectional.all(31),
      );
      final (EdgeInsetsGeometry pad, double gap) = await measure(
        tester,
        harnessThemed(
          sheet(
            c,
            padding: const EdgeInsetsDirectional.all(7),
            spacing: 5,
          ),
          theme: token,
        ),
      );
      expect(pad, const EdgeInsetsDirectional.all(7));
      expect(gap, 5);
    });

    testWidgets('SET-T2 — sans paramètre, le JETON de l\'hôte l\'emporte sur '
        'la référence', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final ZcrudTheme token = const ZcrudTheme().copyWith(
        gapS: 33,
        formPadding: const EdgeInsetsDirectional.all(31),
      );
      final (EdgeInsetsGeometry pad, double gap) = await measure(
        tester,
        // 🔴 La feuille est un `Column(min)` et ne DÉFILE PAS d'elle-même :
        // c'est ce qui la rend montable dans le créneau `tools` d'un composer
        // (lui-même une `Column`). Sous un jeton d'espacement large, elle
        // dépasse donc l'écran — et c'est l'HÔTE qui la borne, comme ici.
        harnessThemed(
          SingleChildScrollView(child: sheet(c)),
          theme: token,
        ),
      );
      expect(pad, const EdgeInsetsDirectional.all(31),
          reason: '🔴 le jeton injecté par l\'hôte est ignoré : FR-26 exige '
              'que le thème PRIME sur la valeur du socle');
      expect(gap, 33);
    });

    testWidgets('SET-T3 — sans paramètre NI jeton, la RÉFÉRENCE du socle — '
        'et elle est donc ATTEIGNABLE', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      final (EdgeInsetsGeometry pad, double gap) = await measure(
        tester,
        harnessThemed(sheet(c), theme: null),
      );
      expect(pad, kZChatSettingsReferencePadding,
          reason: '🔴 le niveau 3 est INATTEIGNABLE : une « référence » que '
              'rien ne peut atteindre est une garde vacante déguisée en '
              'gouvernance. C\'est ce qui arriverait en lisant '
              '`ZcrudTheme.of`, qui ne rend jamais `null`.');
      expect(gap, kZChatSettingsReferenceGap);
      // 🔬 non-vacuité : la référence n'est pas, par hasard, la valeur du
      // repli Material — sans quoi SET-T3 serait vrai pour la mauvaise raison.
      expect(kZChatSettingsReferenceGap, isNot(33.0));
    });
  });

  group('🔴 SET-M — SM-1 : la feuille ne touche pas la liste des messages', () {
    testWidgets('SET-M1 — ouvrir, RÉGLER, fermer : ZÉRO tuile reconstruite', (
      WidgetTester tester,
    ) async {
      final rig = rigWith();
      addTearDown(rig.controller.dispose);
      rig.controller.attach(
        conversationId: 'c1',
        messages: <ZChatMessage>[
          assistant(<ZContentBlock>[ZTextBlock(text: 'un')], id: 'm0'),
          assistant(<ZContentBlock>[ZTextBlock(text: 'deux')], id: 'm1'),
        ],
      );
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final ValueNotifier<bool> open = ValueNotifier<bool>(false);
      addTearDown(open.dispose);

      int tiles = 0;
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            // Sonde DANS le sous-arbre visé : un compteur posé ailleurs ne
            // prouverait rien.
            actionsBuilder: (BuildContext context, ZChatMessage m) {
              tiles++;
              return null;
            },
            composer: ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              settings: settings,
              tools: (BuildContext context, ZChatComposerSlot slot) =>
                  ValueListenableBuilder<bool>(
                    valueListenable: open,
                    builder: (BuildContext context, bool o, Widget? _) =>
                        o
                        ? ZChatSettingsSheet(controller: slot.settings!)
                        : const SizedBox.shrink(),
                  ),
            ),
          ),
        ),
      );
      expect(tiles, greaterThan(0), reason: '🔴 la sonde ne voit rien');
      final int base = tiles;

      open.value = true; // ouvrir
      await tester.pump();
      await tester.tap(find.text(fb(kZChatLabelLengthConcise)));
      await tester.pump(); // régler
      open.value = false; // fermer
      await tester.pump();

      expect(settings.settings.value.responseLength,
          ZChatResponseLength.concise,
          reason: '🔴 GARDE VACUELLE : rien n\'a été réglé, donc rien n\'aurait '
              'pu reconstruire quoi que ce soit');
      expect(
        tiles - base,
        0,
        reason: '🔴 SM-1, objectif produit n°1 : ouvrir une feuille de réglages '
            'a reconstruit ${tiles - base} tuile(s) de conversation. C\'est le '
            'bug historique — la fusion des tranches — sous une autre forme.',
      );

      // 🔬 NON-VACUITÉ : un VRAI tour, lui, reconstruit bien les tuiles.
      rig.controller.composer.text = 'x';
      unawaited(rig.controller.send());
      await tester.pump();
      expect(tiles, greaterThan(base),
          reason: '🔴 le compteur ne bouge JAMAIS : il ne mesure rien');
      await rig.port.closeAll();
      await tester.pump();
    });

    testWidgets('SET-M2 — régler ne reconstruit AUCUN créneau d\'hôte : le '
        'composer ne s\'abonne PAS aux réglages', (WidgetTester tester) async {
      // 🔴 Cette garde existe parce que l'injection R15 d'origine — abonner le
      // composer à la tranche `messages` — est restée VERTE sur SET-M1 : elle
      // reconstruisait le COMPOSER, pas les tuiles, donc elle ne violait pas la
      // propriété que SET-M1 énonce. Injection rejetée, propriété RÉELLEMENT
      // menacée isolée ici : « un créneau qui ne réagit à rien n'est jamais
      // reconstruit » — la promesse écrite dans le dartdoc de
      // `ZChatComposerSlot`, jusqu'ici NON gardée.
      final rig = rigWith();
      addTearDown(rig.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);

      int slots = 0;
      Widget tree() => harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          settings: settings,
          leading: (BuildContext context, ZChatComposerSlot slot) {
            slots++;
            return const SizedBox(key: ValueKey<String>('lead'), height: 8);
          },
          tools: (BuildContext context, ZChatComposerSlot slot) =>
              ZChatSettingsSheet(controller: slot.settings!),
        ),
      );
      await tester.pumpWidget(tree());
      expect(slots, greaterThan(0), reason: '🔴 la sonde ne voit rien');
      final int base = slots;

      await tester.tap(find.text(fb(kZChatLabelLengthDetailed)));
      await tester.pump();
      await tester.tap(find.text('Niveau 2'));
      await tester.pump();

      expect(settings.settings.value.responseLength,
          ZChatResponseLength.detailed,
          reason: '🔴 GARDE VACUELLE : rien n\'a été réglé');
      expect(settings.settings.value.computeEffort?.level, 2);
      expect(
        slots - base,
        0,
        reason: '🔴 AD-2 : régler la verbosité a reconstruit ${slots - base} '
            'créneau(x) d\'hôte. Le composer LIT les réglages au moment de '
            'l\'envoi ; s\'il s\'y ABONNE, tout ce qu\'il porte — créneaux '
            'de l\'hôte, champ de saisie — se reconstruit à chaque clic dans '
            'la feuille.',
      );

      // 🔬 NON-VACUITÉ : une vraie reconfiguration, elle, RECONSTRUIT bien.
      await tester.pumpWidget(tree());
      expect(slots, greaterThan(base),
          reason: '🔴 le compteur ne bouge JAMAIS : il ne mesure rien');
    });
  });

  group('🔴 SET-R — sémantique et RTL', () {
    testWidgets('SET-R1 — l\'ÉTAT choisi est dans l\'arbre sémantique, pas '
        'seulement à l\'écran ; et l\'intitulé n\'est annoncé qu\'UNE fois', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final ZChatSettingsController c = ZChatSettingsController(
        settings: const ZChatGenerationSettings(
          responseLength: ZChatResponseLength.concise,
        ),
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(sheet(c)));

      expect(
        findSemantics(
          tester,
          (SemanticsNode n) => n.label == fb(kZChatLabelSettings),
        ),
        isNotNull,
        reason: '🔴 la feuille n\'a aucune identité pour un lecteur d\'écran',
      );

      // 🔴 ÉGALITÉ, pas `contains` : l'injection jumelle du lot α a montré que
      // retirer un `ExcludeSemantics` CONCATÈNE le libellé au lieu de le
      // dupliquer — un `contains` y est aveugle.
      final List<SemanticsNode> groups = collectSemantics(
        tester,
        (SemanticsNode n) => n.label == fb(kZChatLabelResponseLength),
      );
      expect(groups, hasLength(1),
          reason: '🔴 l\'intitulé du groupe est annoncé ${groups.length} fois '
              '(0 = muet, 2 = doublon). Le `Text` visuel doit rester HORS de '
              'l\'arbre sémantique, l\'étiquette étant portée par le groupe.');

      final List<SemanticsNode> selected = collectSemantics(
        tester,
        (SemanticsNode n) =>
            // 🔴 `isSelected` est un **Tristate** : `none` (non applicable),
            // `isTrue`, `isFalse`. Le comparer à `isTrue` distingue « choisie »
            // de « choisissable mais pas choisie » — un `!= none` accepterait
            // les deux et la garde ne discriminerait rien.
            n.getSemanticsData().flagsCollection.isSelected ==
                Tristate.isTrue &&
            n.label == fb(kZChatLabelLengthConcise),
      );
      expect(selected, hasLength(1),
          reason: '🔴 l\'option choisie ne porte PAS le drapeau `selected` : '
              'l\'information est alors portée par la seule couleur — l\'un '
              'des 18 défauts structurants relevés dans le legacy.');
      final List<SemanticsNode> wrong = collectSemantics(
        tester,
        (SemanticsNode n) =>
            // 🔴 `isSelected` est un **Tristate** : `none` (non applicable),
            // `isTrue`, `isFalse`. Le comparer à `isTrue` distingue « choisie »
            // de « choisissable mais pas choisie » — un `!= none` accepterait
            // les deux et la garde ne discriminerait rien.
            n.getSemanticsData().flagsCollection.isSelected ==
                Tristate.isTrue &&
            n.label == fb(kZChatLabelLengthDetailed),
      );
      expect(wrong, isEmpty,
          reason: '🔴 TOUTES les options se disent choisies : le drapeau ne '
              'discrimine rien');
      // Le handle doit être libéré DANS le corps du test : un `addTearDown`
      // s'exécute APRÈS la vérification du framework, qui rougit alors sur
      // « A SemanticsHandle was active at the end of the test » (mesuré).
      handle.dispose();
    });

    testWidgets('SET-R2 — en RTL, la première option est à DROITE (géométrie)',
        (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harnessThemed(sheet(c), theme: null, direction: TextDirection.rtl),
      );
      final double first = tester
          .getTopLeft(find.text(fb(kZChatLabelSettingAuto)).first)
          .dx;
      final double second = tester
          .getTopLeft(find.text(fb(kZChatLabelLengthConcise)))
          .dx;
      expect(first, greaterThan(second),
          reason: '🔴 AD-13 : la feuille est disposée en LTR sous une '
              'directionnalité RTL');
    });

    testWidgets('SET-R3 — le registre de l\'HÔTE remplace les libellés : le '
        'repli n\'est qu\'un dernier ressort', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harnessThemed(
          sheet(c),
          theme: null,
          // 🔴 Une clé réellement RENDUE : `zchat.settings` n'est qu'une
          // étiquette sémantique (aucun `Text` ne la porte), et mesurer un
          // remplacement sur elle aurait été vrai par vacuité.
          labels: <String, String>{kZChatLabelResponseLength: 'Verbosity'},
        ),
      );
      expect(find.text('Verbosity'), findsOneWidget);
      expect(find.text(fb(kZChatLabelResponseLength)), findsNothing,
          reason: '🔴 le repli français a survécu à une traduction d\'hôte : '
              'il ne serait donc pas un REPLI mais une valeur imposée');
    });
  });

  group('🔴 SET-C — la composition RÉELLE feuille ↔ composer', () {
    testWidgets('SET-C1 — un réglage choisi dans la feuille se retrouve sur la '
        'requête ouverte par la touche « valider »', (
      WidgetTester tester,
    ) async {
      final rig = rigWith();
      addTearDown(rig.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);

      // Lot K4 : la feuille par défaut a gagné la famille « capacités »
      // (raccord kernel K1) — la fenêtre 800×600 débordait de 40 px. La
      // propriété mesurée ici est la COUTURE feuille↔composer, pas la
      // hauteur : on agrandit la fenêtre, sans toucher à la mesure.
      tester.view.physicalSize = const Size(2400, 2700);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            composer: ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
              settings: settings,
              // 🔴 La feuille lit le contrôleur DU CRÉNEAU : l'hôte ne peut pas
              // en fabriquer un second par mégarde.
              tools: (BuildContext context, ZChatComposerSlot slot) {
                expect(slot.settings, isNotNull,
                    reason: '🔴 le créneau ne reçoit PAS le contrôleur de '
                        'réglages : l\'hôte serait contraint d\'en fabriquer '
                        'un second, que le composer ne soumettrait pas — le '
                        'défaut IFFD, à la lettre.');
                return ZChatSettingsSheet(
                  controller: slot.settings!,
                  corpusCatalog: _catalogue,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Niveau 4'));
      await tester.pump();
      await tester.tap(find.text('Beta'));
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'question');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(rig.port.calls, hasLength(1),
          reason: '🔴 un SECOND chemin d\'envoi est apparu');
      final ZChatGenerationRequest sent = rig.port.calls.single.request;
      expect(sent.computeEffort?.level, 4,
          reason: '🔴 LE défaut de l\'étude, reproduit : un réglage montré à '
              'l\'utilisateur, puis JETÉ avant l\'appel.');
      expect(sent.corpusScope?.corpusKeys, <String>[_kBeta],
          reason: '🔴 la portée documentaire choisie n\'atteint pas la '
              'requête : la restriction serait un vœu, pas une demande');
      expect(sent.subject, 'question');
      await rig.port.closeAll();
      await tester.pump();
    });

    testWidgets('SET-C2 — SANS contrôleur de réglages, le composer envoie la '
        'requête du builder TELLE QUELLE (hôte passif inchangé)', (
      WidgetTester tester,
    ) async {
      final rig = rigWith(responseLength: ZChatResponseLength.detailed);
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            composer: ZChatComposer(
              controller: rig.controller,
              cursorColor: _cursor,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'salut');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(
        identical(rig.port.calls.single.request, rig.built.single),
        isTrue,
        reason: '🔴 LE DÉFAUT A BOUGÉ pour l\'hôte PASSIF : le composer '
            'recompose la requête alors qu\'aucun réglage ne lui a été confié.',
      );
      await rig.port.closeAll();
      await tester.pump();
    });
  });
}
