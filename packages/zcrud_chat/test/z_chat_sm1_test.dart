/// 🔴 **SM-1 — l'objectif produit n°1 du dépôt**, MESURÉ.
///
/// zcrud existe pour corriger par conception le rafraîchissement global à
/// chaque frappe (jank, perte de focus). Une garde qui vérifierait « la tranche
/// existe » ne prouverait **rien** : le précédent CR-IFFD-37 est exactement
/// cela — une garde correcte sur la présence et la sémantique d'un slot, qui
/// n'a jamais mesuré son coût, et un slot inutilisable en production.
///
/// Ce fichier **COMPTE des reconstructions RÉELLES** : chaque tranche porte un
/// compteur incrémenté **dans le `builder`** d'un `ValueListenableBuilder`
/// réellement monté. Les sondes sont **dans** les sous-arbres visés (leçon
/// su-2/D5 : une sonde posée sur un *sibling* est structurellement aveugle).
///
/// Deux mesures symétriques :
///  1. **taper 100 caractères** ⇒ les tranches `messages`, `streamText`,
///     `progress` et `liveAnnouncement` ne bougent **pas** ;
///  2. **recevoir 100 jetons** ⇒ les tranches du **composer** ne bougent
///     **pas**, ni `messages`, ni `progress`, ni `liveAnnouncement`.
///
/// Plus deux invariants AD-2 que le bug historique violait : le
/// `TextEditingController` n'est **jamais recréé**, et le focus **survit**.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';

/// Compteurs de reconstruction, par TRANCHE.
class _Probes {
  int composer = 0;
  int attachments = 0;
  int messages = 0;
  int streamText = 0;
  int progress = 0;
  int live = 0;
  int global = 0;

  /// Somme des tranches de SAISIE (le « composer » vu comme un groupe).
  int get composerGroup => composer + attachments;

  @override
  String toString() =>
      'composer:$composer attachments:$attachments messages:$messages '
      'streamText:$streamText progress:$progress live:$live global:$global';
}

/// Hôte de test : **une frontière de widget par tranche**, chacune avec sa
/// sonde DANS son propre `builder`.
Widget _host(ZChatController c, _Probes p, String requestId) => MaterialApp(
  home: Scaffold(
    body: Column(
      children: <Widget>[
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: c.composer,
          builder: (BuildContext context, TextEditingValue v, Widget? child) {
            p.composer++;
            return Text('draft:${v.text.length}');
          },
        ),
        ValueListenableBuilder<List<String>>(
          valueListenable: c.attachmentIds,
          builder: (BuildContext context, List<String> v, Widget? child) {
            p.attachments++;
            return Text('att:${v.length}');
          },
        ),
        ValueListenableBuilder<List<ZChatMessage>>(
          valueListenable: c.messages,
          builder: (BuildContext context, List<ZChatMessage> v, Widget? child) {
            p.messages++;
            // 🔴 `ListView.builder` : le chat d'IFFD n'en contient AUCUN
            // (0 occurrence sur 5153 lignes). Rien dans la tranche `messages`
            // n'empêche la virtualisation — elle est une LISTE, pas un widget.
            return SizedBox(
              height: 40,
              child: ListView.builder(
                itemCount: v.length,
                itemBuilder: (BuildContext context, int i) => Text('m$i'),
              ),
            );
          },
        ),
        ValueListenableBuilder<String>(
          valueListenable: c.streamText(requestId),
          builder: (BuildContext context, String t, Widget? child) {
            p.streamText++;
            return Text('live:${t.length}');
          },
        ),
        ValueListenableBuilder<ZChatStreamProgress>(
          valueListenable: c.progress(requestId),
          builder: (BuildContext context, ZChatStreamProgress g, Widget? child) {
            p.progress++;
            return Text('phase:${g.phase.name}');
          },
        ),
        ValueListenableBuilder<String>(
          valueListenable: c.liveAnnouncement,
          builder: (BuildContext context, String a, Widget? child) {
            p.live++;
            return Semantics(liveRegion: true, label: a, child: const SizedBox.shrink());
          },
        ),
        TextField(controller: c.composer),
      ],
    ),
  ),
);

void main() {
  testWidgets(
    '🔴 SM-1 (1/2) — 100 caractères tapés : AUCUNE reconstruction de la liste '
    'des messages, du texte en cours, de la progression ni de la région live',
    (WidgetTester tester) async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      final _Probes p = _Probes();
      c.addListener(() => p.global++);

      await tester.pumpWidget(_host(c, p, 'r0'));

      // Contre-preuve de NON-VACUITÉ : les six sondes ont réellement construit.
      expect(
        <int>[p.composer, p.attachments, p.messages, p.streamText, p.progress, p.live]
            .every((int n) => n > 0),
        isTrue,
        reason: 'une sonde jamais construite rendrait sa mesure VIDE : $p',
      );

      final Finder field = find.byType(TextField);
      await tester.tap(field);
      await tester.pump();

      final TextEditingController before = tester
          .widget<TextField>(field)
          .controller!;
      final int messages0 = p.messages;
      final int stream0 = p.streamText;
      final int progress0 = p.progress;
      final int live0 = p.live;
      final int attachments0 = p.attachments;
      final int composer0 = p.composer;

      // Frappe caractère par caractère — le chemin RÉEL d'un utilisateur (un
      // seul `enterText` de 100 caractères est UNE mutation, pas cent).
      final StringBuffer buffer = StringBuffer();
      for (int i = 0; i < 100; i++) {
        buffer.write('a');
        await tester.enterText(field, buffer.toString());
        await tester.pump();
      }

      expect(
        p.composer - composer0,
        greaterThanOrEqualTo(100),
        reason: '🔴 la sonde du composer n\'a pas vu les 100 frappes : la '
            'mesure ci-dessous serait vraie par VACUITÉ',
      );
      expect(
        p.messages,
        messages0,
        reason: '🔴 SM-1 : taper a reconstruit la LISTE DES MESSAGES. C\'est '
            'EXACTEMENT le bug historique (jank, perte de focus) que zcrud '
            'existe pour corriger. $p',
      );
      expect(p.streamText, stream0,
          reason: '🔴 SM-1 : taper a reconstruit la bulle en cours de rédaction');
      expect(p.progress, progress0,
          reason: '🔴 SM-1 : taper a reconstruit l\'indicateur de progression');
      expect(p.live, live0,
          reason: '🔴 SM-1 : taper a fait parler la région live (a11y : le '
              'lecteur d\'écran annoncerait chaque touche)');
      expect(p.attachments, attachments0,
          reason: '🔴 taper n\'ajoute aucune pièce jointe');
      expect(
        p.global,
        0,
        reason: '🔴 `notifyListeners()` GLOBAL déclenché par une frappe : tout '
            'écoutant du contrôleur se reconstruirait — le canal global est '
            'RÉSERVÉ aux changements structurels (`attach`). $p',
      );

      // AD-2 — les deux symptômes visibles du bug historique.
      expect(
        identical(tester.widget<TextField>(field).controller, before),
        isTrue,
        reason: '🔴 le `TextEditingController` a été RECRÉÉ pendant la frappe',
      );
      final EditableText editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.focusNode.hasFocus, isTrue,
          reason: '🔴 SM-1 : la frappe a fait perdre le focus');
      expect(c.composer.text, 'a' * 100);
    },
  );

  testWidgets(
    '🔴 SM-1 (2/2) — 100 jetons reçus : AUCUNE reconstruction du composer, de '
    'la liste des messages, de la progression ni de la région live',
    (WidgetTester tester) async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      final FakeStreamPort port = harness.port;
      addTearDown(c.dispose);
      final _Probes p = _Probes();
      c.addListener(() => p.global++);

      await tester.pumpWidget(_host(c, p, 'r0'));

      await tester.enterText(find.byType(TextField), 'question');
      await tester.pump();
      final Future<void> sending = c.send();
      await tester.pump();
      expect(port.calls, hasLength(1), reason: 'le flux n\'a pas démarré');

      // Base de référence APRÈS l'envoi (qui vide légitimement le composer et
      // ajoute le message utilisateur).
      final int composerGroup0 = p.composerGroup;
      final int messages0 = p.messages;
      final int progress0 = p.progress;
      final int live0 = p.live;
      final int stream0 = p.streamText;

      for (int i = 0; i < 100; i++) {
        port.last.add(tok('x', seq: 's$i'));
        await tester.pump();
      }

      expect(
        p.streamText - stream0,
        greaterThanOrEqualTo(100),
        reason: '🔴 la sonde du texte en cours n\'a pas vu les 100 jetons : '
            'les mesures ci-dessous seraient vraies par VACUITÉ. $p',
      );
      expect(
        p.composerGroup,
        composerGroup0,
        reason: '🔴 SM-1 : un jeton reçu a reconstruit le COMPOSER — le champ '
            'de saisie se reconstruit sous les doigts de l\'utilisateur '
            'pendant que la réponse arrive. $p',
      );
      expect(p.messages, messages0,
          reason: '🔴 SM-1 : chaque jeton reconstruit TOUTE la liste des '
              'messages (la virtualisation ne sauve rien si le builder de la '
              'liste est réinvoqué 300 fois par tour)');
      expect(p.progress, progress0,
          reason: '🔴 SM-1 : chaque jeton reconstruit l\'indicateur de '
              'réflexion, les sources et le quota — c\'est pourquoi '
              '`lastSequenceId` et le compteur d\'événements ne sont PAS dans '
              '`ZChatStreamProgress`');
      expect(p.live, live0,
          reason: '🔴 a11y : une région live qui parle à chaque jeton est '
              'inutilisable — elle ne doit s\'exprimer qu\'aux JALONS');
      expect(p.global, 0,
          reason: '🔴 `notifyListeners()` GLOBAL déclenché par un jeton. $p');

      // Le composer est resté VIDE et intact pendant tout le flux.
      expect(c.composer.text, isEmpty);

      port.last.add(done());
      await tester.pump();
      await sending;
      await tester.pump();

      // Aux JALONS, en revanche, les tranches grossières bougent — sans quoi
      // « elles ne bougent pas » serait vrai parce qu'elles sont mortes.
      expect(p.messages, greaterThan(messages0),
          reason: '🔴 GARDE VACUELLE : la tranche `messages` ne bouge JAMAIS');
      expect(p.live, greaterThan(live0),
          reason: '🔴 GARDE VACUELLE : la région live ne s\'exprime JAMAIS — '
              'c\'est la dette d\'IFFD (0 `Semantics` sur tout son chat)');
      expect(p.progress, greaterThan(progress0),
          reason: '🔴 GARDE VACUELLE : la progression ne bouge JAMAIS');
      expect(c.liveAnnouncement.value, 'x' * 100);
    },
  );
}
