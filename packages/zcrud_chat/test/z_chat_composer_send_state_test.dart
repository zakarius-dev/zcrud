// Lot L4 (chantier « composer avancé ») — gardes des ÉTATS D'ENVOI.
//
// Ce que ce fichier MESURE, sur un composer réellement monté et piloté par les
// verbes publics du contrôleur (`seedDraft`, `send`, `startEditing`) — jamais
// par un objet interne que le code de production ne détiendrait pas :
//
// * **SND-I — INERTIE** : sans état réglé, l'affordance annonce « Envoyer » et
//   rend la face `idle`, exactement comme avant ce vocabulaire.
// * **SND-E — un état, SA face et SON annonce** : les quatre états sont
//   atteints SÉPARÉMENT, et chacun est mesuré sur la face RENDUE et sur
//   l'étiquette sémantique RENDUE.
// * **SND-P — PRIORITÉ** : `streaming > busy > editing > idle`, mesurée sur
//   des états rendus SIMULTANÉMENT vrais.
// * **SND-B — la cible reste BORNÉE** : ≥ 48 dp rendus dans chaque état, y
//   compris quand un paramètre en demande moins.
// * **SND-A2 — granularité** : un changement d'état ne recrée pas le champ de
//   saisie et ne lui fait pas perdre le focus.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const Color _cursor = Color(0xFF123456);

const Key _idleKey = Key('glyph-idle');
const Key _busyKey = Key('glyph-busy');
const Key _streamingKey = Key('glyph-streaming');
const Key _editingKey = Key('glyph-editing');

const ZChatComposerSendGlyphs _glyphs = ZChatComposerSendGlyphs(
  idle: SizedBox(key: _idleKey, width: 16, height: 16),
  busy: SizedBox(key: _busyKey, width: 16, height: 16),
  streaming: SizedBox(key: _streamingKey, width: 16, height: 16),
  editing: SizedBox(key: _editingKey, width: 16, height: 16),
);

/// Le composer réel, avec l'affordance montée dans son créneau `trailing` —
/// le câblage exact qu'un hôte écrit.
Widget _mount(
  ZChatController controller, {
  ValueListenable<bool>? busy,
  ZChatComposerChrome? chrome,
}) => harness(
  ZChatComposer(
    controller: controller,
    cursorColor: _cursor,
    trailing: (BuildContext context, ZChatComposerSlot slot) =>
        ZChatComposerSendControl(
          slot: slot,
          glyphs: _glyphs,
          busy: busy,
          chrome: chrome,
        ),
  ),
);

/// La taille RENDUE de la cible portant [label] — la boîte contrainte, celle
/// que le doigt touche, jamais le glyphe.
Size _targetSize(WidgetTester tester, String label) {
  final Finder target = find.bySemanticsLabel(label);
  expect(target, findsOneWidget,
      reason: '🔴 GARDE VACUELLE : « $label » n\'est pas monté.');
  return tester.getSize(
    find.descendant(of: target, matching: find.byType(ConstrainedBox)).first,
  );
}

void main() {
  group('🔴 SND-I — INERTIE : sans état réglé, rien ne change', () {
    testWidgets('le créneau d\'envoi annonce « Envoyer » et rend la face '
        '`idle`', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: c.controller,
            cursorColor: _cursor,
            trailing: (BuildContext context, ZChatComposerSlot slot) =>
                // Le câblage d'HIER : une seule face, aucun état.
                ZChatComposerSendTarget(
                  slot: slot,
                  child: const SizedBox(key: _idleKey, width: 16, height: 16),
                ),
          ),
        ),
      );
      expect(find.bySemanticsLabel('Envoyer'), findsOneWidget,
          reason: '🔴 l\'annonce par défaut a changé : le vocabulaire d\'état '
              'n\'est plus additif.');
      expect(find.byKey(_idleKey), findsOneWidget);
    });

    testWidgets('un jeu de faces RÉDUIT à `idle` rend `idle` dans les quatre '
        'états', (WidgetTester tester) async {
      const ZChatComposerSendGlyphs only = ZChatComposerSendGlyphs(
        idle: SizedBox(key: _idleKey, width: 16, height: 16),
      );
      for (final ZChatComposerSendState state
          in ZChatComposerSendState.values) {
        expect(only.resolve(state), isA<SizedBox>(),
            reason: '🔴 un créneau VIDE : l\'hôte qui ne fournit qu\'une face '
                'perdrait son bouton dans trois états sur quatre.');
        expect((only.resolve(state) as SizedBox).key, _idleKey);
      }
    });
  });

  group('🔴 SND-E — un état, SA face et SON annonce', () {
    testWidgets('idle — face `idle`, annonce « Envoyer »', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      await tester.pumpWidget(_mount(c.controller));
      expect(find.byKey(_idleKey), findsOneWidget);
      expect(find.bySemanticsLabel('Envoyer'), findsOneWidget);
    });

    testWidgets('busy — face `busy`, annonce « Envoi en préparation »', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<bool> busy = ValueNotifier<bool>(false);
      addTearDown(busy.dispose);
      await tester.pumpWidget(_mount(c.controller, busy: busy));
      expect(find.byKey(_idleKey), findsOneWidget,
          reason: '🔴 GARDE VACUELLE : l\'état de départ n\'est pas `idle`.');
      busy.value = true;
      await tester.pump();
      expect(find.byKey(_busyKey), findsOneWidget,
          reason: '🔴 la face de préparation n\'est jamais rendue : la tranche '
              'de l\'hôte est ignorée.');
      expect(find.byKey(_idleKey), findsNothing);
      expect(find.bySemanticsLabel('Envoi en préparation'), findsOneWidget,
          reason: '🔴 un lecteur d\'écran annoncerait encore « Envoyer » alors '
              'que l\'envoi n\'est pas prêt.');
    });

    testWidgets('editing — face `editing`, annonce « Valider la '
        'modification »', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      await tester.pumpWidget(_mount(c.controller));
      c.controller.startEditing(messageId: 'm1', originalText: 'texte');
      await tester.pump();
      expect(find.byKey(_editingKey), findsOneWidget);
      expect(find.bySemanticsLabel('Valider la modification'), findsOneWidget,
          reason: '🔴 en mode modification, « Envoyer » laisse croire qu\'un '
              'NOUVEAU message part.');
    });

    testWidgets('streaming — le STOP EXISTANT est monté, avec sa face et son '
        'annonce', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      await tester.pumpWidget(_mount(c.controller));
      c.controller.seedDraft('question');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Envoyer'));
      await tester.pump();
      expect(find.bySemanticsLabel('Arrêter la génération'), findsOneWidget,
          reason: '🔴 pendant le flux, l\'affordance doit offrir l\'ARRÊT.');
      expect(find.byKey(_streamingKey), findsOneWidget);
      expect(find.byType(ZChatComposerStopTarget), findsOneWidget,
          reason: '🔴 l\'arrêt doit passer par la pièce EXISTANTE — un second '
              'chemin d\'annulation serait un second site d\'appel.');
      // Le verbe existant, mesuré sur l'exécuteur : le tap n'invente rien.
      await tester.tap(find.bySemanticsLabel('Arrêter la génération'));
      await tester.pump();
      expect(c.executor.calls['cancelRequest'], 1);
      await tester.pump();
    });
  });

  group('🔴 SND-P — PRIORITÉ, sur des états SIMULTANÉMENT vrais', () {
    test('la résolution PURE ordonne streaming > busy > editing > idle', () {
      expect(
        ZChatComposerSendState.resolve(
          streaming: true,
          busy: true,
          editing: true,
        ),
        ZChatComposerSendState.streaming,
        reason: '🔴 une génération lancée depuis le mode édition deviendrait '
            'ININTERROMPABLE.',
      );
      expect(
        ZChatComposerSendState.resolve(
          streaming: false,
          busy: true,
          editing: true,
        ),
        ZChatComposerSendState.busy,
        reason: '🔴 valider une modification dont la pièce jointe n\'est pas '
            'prête l\'enverrait sans elle.',
      );
      expect(
        ZChatComposerSendState.resolve(
          streaming: false,
          busy: false,
          editing: true,
        ),
        ZChatComposerSendState.editing,
      );
      expect(
        ZChatComposerSendState.resolve(
          streaming: false,
          busy: false,
          editing: false,
        ),
        ZChatComposerSendState.idle,
      );
    });

    testWidgets('RENDU — édition ET préparation : la préparation gagne', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<bool> busy = ValueNotifier<bool>(true);
      addTearDown(busy.dispose);
      await tester.pumpWidget(_mount(c.controller, busy: busy));
      c.controller.startEditing(messageId: 'm1', originalText: 'texte');
      await tester.pump();
      expect(find.byKey(_busyKey), findsOneWidget);
      expect(find.byKey(_editingKey), findsNothing,
          reason: '🔴 l\'ordre de priorité n\'est pas celui que la résolution '
              'pure promet — deux vérités, deux réponses différentes.');
    });

    testWidgets('RENDU — flux ET préparation : le flux gagne', (
      WidgetTester tester,
    ) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<bool> busy = ValueNotifier<bool>(true);
      addTearDown(busy.dispose);
      await tester.pumpWidget(_mount(c.controller, busy: busy));
      c.controller.seedDraft('question');
      await tester.pump();
      // La saisie est prête ; l'envoi est déclenché par le VERBE du
      // contrôleur — la face `busy` a remplacé le libellé « Envoyer », donc le
      // tap n'est pas le chemin ici.
      //
      // ⚠️ Le futur de `send()` ne se résout qu'à la fermeture du flux : on ne
      // l'attend PAS (un `await` ferait pendre la garde indéfiniment).
      unawaited(c.controller.send());
      await tester.pump();
      expect(find.byKey(_streamingKey), findsOneWidget,
          reason: '🔴 une requête en vol doit primer sur toute préparation : '
              'sinon l\'utilisateur ne peut plus l\'arrêter.');
      // Le flux est refermé par le VERBE d'arrêt — jamais par `closeAll()`,
      // dont le futur ne se résoudrait plus (souscription annulée).
      await tester.tap(find.bySemanticsLabel('Arrêter la génération'));
      await tester.pump();
    });
  });

  group('🔴 SND-B — la cible reste BORNÉE au plancher, dans CHAQUE état', () {
    testWidgets('≥ 48 dp rendus au repos, en préparation, en modification et '
        'pendant le flux', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<bool> busy = ValueNotifier<bool>(false);
      addTearDown(busy.dispose);
      await tester.pumpWidget(
        _mount(
          c.controller,
          busy: busy,
          // 🔴 Le plancher est INEXPRIMABLE : un hôte qui demande 20 dp obtient
          // quand même 48 (invariant AD-13).
          chrome: const ZChatComposerChrome(sendTargetSize: 20),
        ),
      );
      Size size = _targetSize(tester, 'Envoyer');
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      busy.value = true;
      await tester.pump();
      size = _targetSize(tester, 'Envoi en préparation');
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      busy.value = false;
      c.controller.startEditing(messageId: 'm1', originalText: 'texte');
      await tester.pump();
      size = _targetSize(tester, 'Valider la modification');
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      c.controller.cancelEditing();
      c.controller.seedDraft('question');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Envoyer'));
      await tester.pump();
      size = _targetSize(tester, 'Arrêter la génération');
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      await tester.tap(find.bySemanticsLabel('Arrêter la génération'));
      await tester.pump();
    });
  });

  group('🔴 SND-A2 — un changement d\'état ne reconstruit QUE l\'affordance',
      () {
    testWidgets('les créneaux du composer ne sont PAS rejoués, et le champ '
        'garde son état et son focus', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ValueNotifier<bool> busy = ValueNotifier<bool>(false);
      addTearDown(busy.dispose);

      // 🔴 La sonde est DANS le sous-arbre visé : elle compte les passages du
      // `builder` d'un créneau du composer. Si l'état d'envoi était résolu au
      // build du composer (un champ sur `ZChatComposerSlot`, par exemple),
      // chaque changement d'état rejouerait TOUS les créneaux — donc le champ.
      int composerBuilds = 0;
      await tester.pumpWidget(
        harness(
          ZChatComposer(
            controller: c.controller,
            cursorColor: _cursor,
            leading: (BuildContext context, ZChatComposerSlot slot) {
              composerBuilds++;
              return const SizedBox(width: 16, height: 16);
            },
            trailing: (BuildContext context, ZChatComposerSlot slot) =>
                ZChatComposerSendControl(
                  slot: slot,
                  glyphs: _glyphs,
                  busy: busy,
                ),
          ),
        ),
      );
      await tester.tap(find.byType(EditableText));
      await tester.pump();
      c.controller.composer.text = 'une phrase en cours';
      await tester.pump();
      final EditableTextState before = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(before.widget.focusNode.hasFocus, isTrue,
          reason: '🔴 GARDE VACUELLE : le champ n\'a jamais eu le focus.');
      final int baseline = composerBuilds;
      expect(baseline, greaterThan(0),
          reason: '🔴 GARDE VACUELLE : la sonde n\'a jamais été appelée.');

      // Trois changements d'état d'affilée — la face change à chaque fois.
      busy.value = true;
      await tester.pump();
      expect(find.byKey(_busyKey), findsOneWidget,
          reason: '🔴 GARDE VACUELLE : l\'état n\'a pas changé, il n\'y a '
              'rien à mesurer.');
      expect(c.controller.composer.text, 'une phrase en cours',
          reason: '🔴 une bascule d\'état a écrasé la saisie en cours.');
      // Le mode ÉDITION réécrit légitimement la saisie (c'est son verbe) : ce
      // qui est mesuré ici est que le CHAMP n'est pas rejoué ni recréé.
      c.controller.startEditing(messageId: 'm1', originalText: 'texte');
      await tester.pump();
      busy.value = false;
      await tester.pump();
      expect(find.byKey(_editingKey), findsOneWidget);

      expect(composerBuilds, baseline,
          reason: '🔴 un changement d\'état d\'envoi a rejoué les créneaux du '
              'composer : l\'état est résolu TROP HAUT, et c\'est le '
              'rafraîchissement global que ce paquet existe pour supprimer '
              '(invariant AD-2).');
      final EditableTextState after = tester.state<EditableTextState>(
        find.byType(EditableText),
      );
      expect(identical(before, after), isTrue,
          reason: '🔴 l\'état du champ a été RECRÉÉ par un changement d\'état '
              'd\'envoi.');
      expect(after.widget.focusNode.hasFocus, isTrue,
          reason: '🔴 le focus a été perdu.');
    });
  });
}
