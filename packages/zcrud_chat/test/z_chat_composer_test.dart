/// Lot α (CR-IFFD-72) — **comportement** du composer socle partagé.
///
/// Ce que ce fichier MESURE, sur un sujet réellement monté :
/// * **CMP-P** — l'hôte PASSIF ne bouge pas : sans `composer`, l'arbre des deux
///   surfaces est celui d'avant le lot (mesuré sur l'enfant direct de la vue,
///   pas sur une impression) ;
/// * **CMP-N** — anti-divergence : les DEUX surfaces montent la saisie par la
///   fabrique unique `_zChatComposeSurface`, et une régression dans cette
///   fabrique les fait rougir ENSEMBLE (démontré par injection R3) ;
/// * **CMP-S** — AD-4 : créneau nul **ou** builder rendant `null` ⇒ ABSENT de
///   l'arbre (compté sur les enfants réels de la `Column`, pas deviné) ;
/// * **CMP-A** — l'envoi passe par `ZChatController.send()`, et par un SEUL
///   site : le créneau d'envoi et la touche « valider » du clavier ouvrent
///   exactement UN flux ;
/// * **CMP-G** — AD-13 : la cible d'un créneau mesure ≥ 48 dp **en géométrie
///   rendue** et reste BORNÉE PAR LE HAUT (leçon `widthFactor` de
///   `z_chat_diffusion_bar.dart`) ; le socle ne comprime pas non plus une cible
///   d'hôte déjà conforme ;
/// * **CMP-M** — SM-1 : 100 frappes ne reconstruisent AUCUNE tuile, le
///   `TextEditingController` n'est jamais recréé, le focus survit et le curseur
///   garde sa **position exacte** au travers d'un rebuild ;
/// * **CMP-R** — RTL et sémantique.
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Couleur de curseur du TEST — le socle, lui, n'en invente aucune (FR-26) :
/// c'est un paramètre REQUIS du composer, comme pour la relecture de capture.
const Color _cursor = Color(0xFF123456);

/// Le fil témoin, IDENTIQUE pour les deux surfaces (patron CR71-N1).
List<ZChatMessage> thread(int count) => <ZChatMessage>[
  for (int i = 0; i < count; i++)
    assistant(<ZContentBlock>[ZTextBlock(text: 'msg $i')], id: 'm$i'),
];

/// Le widget de l'**enfant direct** de [of] — la mesure structurelle qui
/// distingue « arbre inchangé » de « arbre qui rend les mêmes textes ».
Widget firstChildOf(WidgetTester tester, Finder of) {
  final Element root = tester.element(of);
  Element? first;
  root.visitChildren((Element e) => first ??= e);
  expect(first, isNotNull, reason: '🔴 la vue n\'a aucun enfant : mesure vide');
  return first!.widget;
}

/// La `Column` du composer (jamais la `Row`, ni celle d'une tuile).
Column composerColumn(WidgetTester tester) => tester.widget<Column>(
  find
      .descendant(
        of: find.byType(ZChatComposer),
        matching: find.byType(Column),
      )
      .first,
);

/// Un composer minimal, sans aucun créneau.
ZChatComposer bare(ZChatController c) =>
    ZChatComposer(controller: c, cursorColor: _cursor);

void main() {
  group('🔴 CMP-P — l\'HÔTE PASSIF ne bouge pas', () {
    testWidgets('CMP-P1 — la CONVERSATION sans composer garde son arbre : '
        'aucune Column de composition, aucun champ', (
      WidgetTester tester,
    ) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(ZChatConversationView(controller: rig.controller)),
      );
      expect(renderedTexts(tester), <String>['msg 0', 'msg 1']);
      expect(
        find.byType(EditableText),
        findsNothing,
        reason: '🔴 une saisie est apparue sans que l\'hôte la demande',
      );
      expect(
        firstChildOf(tester, find.byType(ZChatConversationView)),
        isA<ValueListenableBuilder<List<ZChatMessage>>>(),
        reason:
            '🔴 l\'enfant direct de la vue n\'est plus la tranche `messages` : '
            'la fabrique a enveloppé l\'arbre de l\'hôte PASSIF. C\'est '
            'l\'incident du 2026-08-01 sur ce volet, rejoué — un lot additif '
            'qui déplace le défaut.',
      );
    });

    testWidgets('CMP-P2 — le NOTEBOOK sans composer garde le sien', (
      WidgetTester tester,
    ) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(ZChatNotebookView(controller: rig.controller)),
      );
      expect(renderedTexts(tester), <String>['msg 0', 'msg 1']);
      expect(find.byType(EditableText), findsNothing);
      expect(
        firstChildOf(tester, find.byType(ZChatConversationView)),
        isA<ValueListenableBuilder<List<ZChatMessage>>>(),
      );
    });

    testWidgets('CMP-P3 — et avec un composer, l\'arbre CHANGE (la mesure '
        'ci-dessus n\'est donc pas vraie par vacuité)', (
      WidgetTester tester,
    ) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            composer: bare(rig.controller),
          ),
        ),
      );
      expect(
        firstChildOf(tester, find.byType(ZChatConversationView)),
        isA<Column>(),
        reason: '🔴 GARDE VACUELLE : l\'arbre est le MÊME avec et sans '
            'composer — la mesure de CMP-P1 ne prouverait rien',
      );
    });
  });

  group('🔴 CMP-N — ANTI-DIVERGENCE : une fabrique, deux surfaces', () {
    testWidgets('CMP-N1a — la CONVERSATION monte la saisie et l\'écrit dans '
        '`controller.composer`', (WidgetTester tester) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            composer: bare(rig.controller),
          ),
        ),
      );
      expect(find.byType(ZChatComposer), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'depuis la conversation');
      expect(
        rig.controller.composer.text,
        'depuis la conversation',
        reason: '🔴 la saisie rendue n\'est pas la tranche du contrôleur',
      );
      // Le fil est toujours là : la saisie ne l'a pas remplacé.
      expect(find.byType(ZChatMessageTile), findsNWidgets(2));
    });

    testWidgets('CMP-N1b — le NOTEBOOK monte la MÊME saisie, par la MÊME '
        'fabrique', (WidgetTester tester) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            composer: bare(rig.controller),
          ),
        ),
      );
      // 🔴 La composition est STRUCTURELLE (motif CR-LEX-78) : le notebook
      // délègue, il ne monte pas une saisie à lui.
      expect(
        find.byType(ZChatConversationView),
        findsOneWidget,
        reason: '🔴 le notebook a cessé de déléguer : début d\'une surface B',
      );
      expect(find.byType(ZChatComposer), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'depuis le notebook');
      expect(rig.controller.composer.text, 'depuis le notebook');
      expect(find.byType(ZChatMessageTile), findsNWidgets(2));
    });
  });

  group('🔴 CMP-N2 — une COQUILLE tierce ne fait pas perdre la saisie', () {
    testWidgets('sous un `ZChatShellRenderer` d\'hôte, le composer est TOUJOURS '
        'monté — y compris sous une coquille AVEUGLE', (
      WidgetTester tester,
    ) async {
      // 🔴 La saisie est composée AU-DESSUS du seam de coquille (patron G-S2 :
      // la région live l'est déjà). Un backend tiers — Syncfusion, lot γ —
      // rend le CADRE du fil ; il ne doit pas pouvoir escamoter la zone de
      // saisie, ni la construire lui-même.
      for (final ZChatShellRenderer shell in <ZChatShellRenderer>[
        FakeShellRenderer(),
        const BlindShellRenderer(),
      ]) {
        final rig = buildController(initialMessages: thread(2));
        addTearDown(rig.controller.dispose);
        await tester.pumpWidget(
          harness(
            ZChatConversationView(
              controller: rig.controller,
              composer: bare(rig.controller),
            ),
            shell: shell,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZChatComposer), findsOneWidget,
            reason: '🔴 la coquille ${shell.runtimeType} a emporté la zone de '
                'saisie : le seam est posé TROP HAUT');
        await tester.enterText(find.byType(EditableText), 'sous coquille');
        expect(rig.controller.composer.text, 'sous coquille');
      }
    });
  });

  group('🔴 CMP-S — AD-4 : un créneau nul est ABSENT de l\'arbre', () {
    testWidgets('CMP-S1 — sans aucun créneau, la Column n\'a QU\'UN enfant', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(harness(bare(rig.controller)));
      expect(
        composerColumn(tester).children,
        hasLength(1),
        reason: '🔴 un créneau nul a laissé un widget INERTE dans l\'arbre '
            '(AD-4 : absent, jamais un `SizedBox.shrink()`)',
      );
    });

    testWidgets('CMP-S2 — un builder qui rend `null` est absent, lui aussi', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: rig.controller,
            cursorColor: _cursor,
            capture: (BuildContext context, ZChatComposerSlot slot) => null,
            tools: (BuildContext context, ZChatComposerSlot slot) => null,
            leading: (BuildContext context, ZChatComposerSlot slot) => null,
            trailing: (BuildContext context, ZChatComposerSlot slot) => null,
          ),
        ),
      );
      expect(
        composerColumn(tester).children,
        hasLength(1),
        reason: '🔴 un builder rendant `null` doit être ABSENT, pas vide',
      );
    });

    testWidgets('CMP-S3 — les quatre créneaux montés, et dans l\'ORDRE : '
        'capture au-dessus, outils en dessous', (WidgetTester tester) async {
      const Key kCapture = ValueKey<String>('cmp-capture');
      const Key kLeading = ValueKey<String>('cmp-leading');
      const Key kTrailing = ValueKey<String>('cmp-trailing');
      const Key kTools = ValueKey<String>('cmp-tools');
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: rig.controller,
            cursorColor: _cursor,
            capture: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kCapture, width: 48, height: 48),
            leading: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kLeading, width: 48, height: 48),
            trailing: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kTrailing, width: 48, height: 48),
            tools: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kTools, width: 48, height: 48),
          ),
        ),
      );
      expect(composerColumn(tester).children, hasLength(3));
      final double captureBottom = tester.getBottomLeft(find.byKey(kCapture)).dy;
      final double fieldTop = tester.getTopLeft(find.byType(EditableText)).dy;
      final double fieldBottom =
          tester.getBottomLeft(find.byType(EditableText)).dy;
      final double toolsTop = tester.getTopLeft(find.byKey(kTools)).dy;
      expect(captureBottom, lessThanOrEqualTo(fieldTop),
          reason: '🔴 la capture doit PRÉCÉDER le champ');
      expect(toolsTop, greaterThanOrEqualTo(fieldBottom),
          reason: '🔴 les réglages doivent SUIVRE le champ');
      // …et les deux créneaux latéraux encadrent le champ (LTR).
      expect(tester.getTopLeft(find.byKey(kLeading)).dx,
          lessThan(tester.getTopLeft(find.byType(EditableText)).dx));
      expect(tester.getTopLeft(find.byKey(kTrailing)).dx,
          greaterThan(tester.getTopLeft(find.byType(EditableText)).dx));
    });
  });

  group('🔴 CMP-A — l\'envoi passe par `send()`, et par UN SEUL site', () {
    testWidgets('CMP-A1 — le créneau d\'envoi ouvre EXACTEMENT un flux, vide la '
        'saisie et ajoute le message', (WidgetTester tester) async {
      const Key kSend = ValueKey<String>('cmp-send');
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      await tester.pumpWidget(
        harness(
          bareWithSend(rig.controller, kSend),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'question');
      await tester.pump();

      await tester.tap(find.byKey(kSend));
      await tester.pump();

      expect(rig.port.calls, hasLength(1),
          reason: '🔴 le créneau d\'envoi n\'a pas emprunté `send()` — ou il '
              'l\'a emprunté DEUX fois (second site d\'appel)');
      expect(rig.port.calls.single.request.subject, 'question');
      expect(rig.controller.composer.text, isEmpty);
      expect(rig.controller.messages.value, hasLength(1));
    });

    testWidgets('CMP-A2 — la touche « valider » du clavier emprunte le MÊME '
        'site : un seul flux', (WidgetTester tester) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      await tester.pumpWidget(harness(bare(rig.controller)));
      await tester.enterText(find.byType(EditableText), 'au clavier');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(rig.port.calls, hasLength(1),
          reason: '🔴 la validation clavier n\'atteint pas `send()`');
      expect(rig.port.calls.single.request.subject, 'au clavier');
    });

    testWidgets('CMP-A3 — une saisie VIDE ne déclenche rien, et ne salit pas '
        '`lastFailure`', (WidgetTester tester) async {
      const Key kSend = ValueKey<String>('cmp-send');
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      await tester.pumpWidget(harness(bareWithSend(rig.controller, kSend)));
      await tester.tap(find.byKey(kSend));
      await tester.pump();
      expect(rig.port.calls, isEmpty);
      expect(rig.controller.lastFailure.value, isNull,
          reason: '🔴 un geste sans texte a produit un ÉCHEC TYPÉ visible par '
              'l\'hôte : le composer doit lire la même condition que `send()`, '
              'pas en inventer une seconde');
      expect(rig.controller.messages.value, isEmpty);
    });

    testWidgets('CMP-A4 — le créneau voit le contrôleur : il peut réagir à '
        '`canSend` SANS second canal', (WidgetTester tester) async {
      final List<bool> seen = <bool>[];
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: rig.controller,
            cursorColor: _cursor,
            trailing: (BuildContext context, ZChatComposerSlot slot) =>
                ValueListenableBuilder<bool>(
                  valueListenable: slot.controller.canSend,
                  builder: (BuildContext context, bool can, Widget? child) {
                    seen.add(can);
                    return const SizedBox(width: 48, height: 48);
                  },
                ),
          ),
        ),
      );
      expect(seen, <bool>[false]);
      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(seen, <bool>[false, true],
          reason: '🔴 le créneau n\'atteint pas la tranche `canSend` du '
              'contrôleur : l\'hôte devrait rouvrir un canal parallèle');
    });
  });

  group('🔴 CMP-G — AD-13 : géométrie RENDUE des cibles (≥ 48 dp, bornée)', () {
    testWidgets('CMP-G1 — un créneau plus PETIT que 48 dp est porté à 48 dp… '
        'et pas à la largeur de l\'écran', (WidgetTester tester) async {
      const Key kSmall = ValueKey<String>('cmp-small');
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: rig.controller,
            cursorColor: _cursor,
            // 🔴 La taille exacte du FAB d'envoi d'IFFD.
            trailing: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kSmall, width: 40, height: 40),
          ),
        ),
      );
      final Finder box = find
          .ancestor(of: find.byKey(kSmall), matching: find.byType(Align))
          .first;
      final Size size = tester.getSize(box);
      expect(size.height, greaterThanOrEqualTo(kZChatMinTapTarget),
          reason: '🔴 la cible d\'envoi mesure ${size.height} dp — le défaut '
              'de 40 dp du legacy IFFD, reproduit dans le socle');
      expect(size.width, greaterThanOrEqualTo(kZChatMinTapTarget));
      // 🔴 …et BORNÉE PAR LE HAUT. Sans cette borne, « ≥ 48 dp » serait vrai
      // pour la mauvaise raison — le précédent mesuré de
      // `z_chat_diffusion_bar.dart` : une cible de 600 dp, verte à la garde,
      // absurde à l'usage. Ce qui la borne ici est la DISPOSITION (le champ est
      // le seul enfant flexible de la `Row`) : rendre ce créneau flexible fait
      // rougir cette ligne, et l'injection R3 jumelle le démontre.
      expect(size.width, lessThan(200),
          reason: '🔴 la cible occupe ${size.width} dp : elle s\'est approprié '
              'la rangée, et la garde de plancher est devenue VACANTE');
      expect(size.height, lessThan(200));
    });

    testWidgets('CMP-G2 — et le socle ne COMPRIME pas une cible d\'hôte déjà '
        'conforme', (WidgetTester tester) async {
      const Key kOk = ValueKey<String>('cmp-ok');
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: rig.controller,
            cursorColor: _cursor,
            leading: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kOk, width: 56, height: 56),
          ),
        ),
      );
      final Size size = tester.getSize(find.byKey(kOk));
      expect(size.width, greaterThanOrEqualTo(48.0),
          reason: '🔴 le composer a COMPRIMÉ la cible de l\'hôte (leçon '
              'CR71-S6 : on mesure la géométrie, jamais les contraintes)');
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('🔴 CMP-M — SM-1, l\'objectif produit n°1, MESURÉ', () {
    testWidgets('CMP-M1 — 100 frappes : AUCUNE tuile reconstruite, contrôleur '
        'stable, focus conservé', (WidgetTester tester) async {
      int tileBuilds = 0;
      final rig = buildController(initialMessages: thread(3));
      addTearDown(rig.controller.dispose);
      addTearDown(rig.port.closeAll);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            // Sonde DANS le sous-arbre visé (leçon su-2/D5) : le builder n'est
            // invoqué que par une tuile RÉELLEMENT construite.
            actionsBuilder: (BuildContext context, ZChatMessage m) {
              tileBuilds++;
              return null;
            },
            composer: bare(rig.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tileBuilds, greaterThan(0),
          reason: '🔴 la sonde n\'a jamais construit : la mesure serait VIDE');

      final Finder field = find.byType(EditableText);
      await tester.tap(field);
      await tester.pump();
      final TextEditingController before =
          tester.widget<EditableText>(field).controller;
      expect(identical(before, rig.controller.composer), isTrue,
          reason: '🔴 le champ ne rend PAS la tranche du contrôleur');

      final int tiles0 = tileBuilds;
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < 100; i++) {
        buffer.write('a');
        await tester.enterText(field, buffer.toString());
        await tester.pump();
      }

      expect(rig.controller.composer.text, 'a' * 100);
      expect(
        tileBuilds,
        tiles0,
        reason: '🔴 SM-1 : taper a reconstruit ${tileBuilds - tiles0} tuile(s) '
            'de la conversation. C\'est EXACTEMENT le bug historique (jank, '
            'perte de focus) que zcrud existe pour corriger, et que le dartdoc '
            'du contrôleur documente en tête.',
      );
      expect(
        identical(tester.widget<EditableText>(field).controller, before),
        isTrue,
        reason: '🔴 le `TextEditingController` a été RECRÉÉ pendant la frappe',
      );
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue,
          reason: '🔴 SM-1 : la frappe a fait perdre le focus');
      expect(rig.controller.composer.selection.baseOffset, 100,
          reason: '🔴 le curseur n\'est plus en fin de saisie');

      // 🔴 NON-VACUITÉ : un vrai tour, lui, RECONSTRUIT les tuiles — sans quoi
      // « aucune reconstruction » serait vrai parce que la sonde est morte.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tileBuilds, greaterThan(tiles0),
          reason: '🔴 GARDE VACUELLE : les tuiles ne se reconstruisent JAMAIS');
    });

    testWidgets('CMP-M2 — un rebuild du composer préserve la POSITION EXACTE '
        'du curseur', (WidgetTester tester) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      Widget tree(double pad) => harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          padding: EdgeInsetsDirectional.all(pad),
        ),
      );
      await tester.pumpWidget(tree(4));
      final Finder field = find.byType(EditableText);
      await tester.tap(field);
      await tester.enterText(field, 'abcdefghij');
      await tester.pump();

      // Curseur AU MILIEU — la position que le bug historique perdait.
      rig.controller.composer.selection =
          const TextSelection.collapsed(offset: 4);
      await tester.pump();
      final TextEditingController before =
          tester.widget<EditableText>(field).controller;

      // Rebuild RÉEL du composer (nouvelle configuration du même widget).
      await tester.pumpWidget(tree(12));
      await tester.pump();

      expect(rig.controller.composer.selection.baseOffset, 4,
          reason: '🔴 le curseur a sauté au rebuild : c\'est le symptôme n°1 '
              'du contrôleur recréé (AD-2)');
      expect(rig.controller.composer.text, 'abcdefghij');
      expect(identical(tester.widget<EditableText>(field).controller, before),
          isTrue);
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue,
          reason: '🔴 le focus n\'a pas survécu au rebuild');
    });
  });

  group('🔴 CMP-R — a11y et RTL (AD-13)', () {
    testWidgets('CMP-R1 — la zone de saisie est annoncée, l\'invite sert de '
        'libellé de champ, et rien n\'est énoncé DEUX fois', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(harness(bare(rig.controller)));
      await tester.pumpAndSettle();

      expect(
        findSemantics(
          tester,
          (SemanticsNode n) =>
              n.label == kZChatLabelFallbacks[kZChatLabelComposer],
        ),
        isNotNull,
        reason: '🔴 la zone de saisie n\'a aucun nœud sémantique',
      );
      final List<SemanticsNode> hints = collectSemantics(
        tester,
        (SemanticsNode n) =>
            n.label.contains(kZChatLabelFallbacks[kZChatLabelComposerHint]!),
      );
      expect(hints, hasLength(1),
          reason: '🔴 DOUBLE ANNONCE de l\'invite (le placeholder visuel doit '
              'rester HORS de l\'arbre sémantique) : '
              '${hints.map((SemanticsNode n) => n.label).toList()}');
      // 🔴 ÉGALITÉ, pas « contient » — DÉFAUT DE GARDE TROUVÉ PAR R3 : retirer
      // l'`ExcludeSemantics` du placeholder ne crée PAS un second nœud, il
      // CONCATÈNE le libellé dans le nœud existant
      // (`Écrivez votre message\nÉcrivez votre message`). C'est exactement la
      // forme du défaut MAJEUR-doublon mesuré sur la bande de pièces jointes
      // (`<rapport.pdf\nrapport.pdf>`), et un `contains` y était aveugle.
      expect(hints.single.label,
          kZChatLabelFallbacks[kZChatLabelComposerHint],
          reason: '🔴 le libellé du champ est CONCATÉNÉ avec lui-même : '
              '"${hints.single.label.replaceAll('\n', ' / ')}"');
      expect(hints.single.getSemanticsData().flagsCollection.isTextField, isTrue,
          reason: '🔴 l\'invite n\'est pas portée par un CHAMP : un lecteur '
              'd\'écran ne saurait pas qu\'on peut y écrire');
      // 🔴 NON-VACUITÉ de l'arbre sémantique : ce que l'utilisateur tape y
      // ARRIVE — sans quoi « pas de doublon » serait vrai d'un champ muet.
      await tester.enterText(find.byType(EditableText), 'saisie annoncee');
      await tester.pumpAndSettle();
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) => n.value.contains('saisie annoncee'),
        ),
        hasLength(1),
        reason: '🔴 le contenu tapé n\'est annoncé NULLE PART, ou DEUX fois',
      );
      // …et AUCUNE clé brute n'atteint l'écran (défaut HIGH-1).
      for (final String t in renderedTexts(tester)) {
        expect(t, isNot(startsWith(kZChatLabelPrefix)));
      }
      handle.dispose();
    });

    testWidgets('CMP-R2 — en RTL, le créneau de tête passe à DROITE du champ', (
      WidgetTester tester,
    ) async {
      const Key kLeading = ValueKey<String>('cmp-rtl-leading');
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: rig.controller,
            cursorColor: _cursor,
            leading: (BuildContext context, ZChatComposerSlot slot) =>
                const SizedBox(key: kLeading, width: 48, height: 48),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(kLeading)).dx,
        greaterThan(tester.getTopLeft(find.byType(EditableText)).dx),
        reason: '🔴 la disposition n\'est pas DIRECTIONNELLE : en RTL le '
            'créneau de tête doit être à droite',
      );
    });

    testWidgets('CMP-R3 — l\'invite disparaît dès la première frappe', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(harness(bare(rig.controller)));
      expect(
        find.text(kZChatLabelFallbacks[kZChatLabelComposerHint]!),
        findsOneWidget,
      );
      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(
        find.text(kZChatLabelFallbacks[kZChatLabelComposerHint]!),
        findsNothing,
        reason: '🔴 l\'invite reste par-dessus le texte de l\'utilisateur',
      );
    });

    testWidgets('CMP-R4 — un registre d\'hôte REMPLACE les libellés (FR-26)', (
      WidgetTester tester,
    ) async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          bare(rig.controller),
          labels: <String, String>{kZChatLabelComposerHint: 'Ask anything'},
        ),
      );
      expect(find.text('Ask anything'), findsOneWidget,
          reason: '🔴 le libellé du socle n\'est pas INJECTABLE : le repli '
              'écrase la traduction de l\'hôte');
      expect(
        find.text(kZChatLabelFallbacks[kZChatLabelComposerHint]!),
        findsNothing,
      );
    });
  });
}

/// Un composer dont le créneau d'envoi est câblé sur [ZChatComposerSlot.submit]
/// — c'est-à-dire sur le site UNIQUE du socle, jamais sur un `send()` recopié.
ZChatComposer bareWithSend(ZChatController c, Key key) => ZChatComposer(
  controller: c,
  cursorColor: _cursor,
  trailing: (BuildContext context, ZChatComposerSlot slot) => GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: slot.submit,
    child: const SizedBox(width: 48, height: 48),
  ),
);
