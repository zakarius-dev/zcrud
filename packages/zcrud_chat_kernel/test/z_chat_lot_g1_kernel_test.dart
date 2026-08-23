// Gardes des besoins signalés au noyau par le contrôleur de fil de travail :
// désabonnement immédiat de `zChatTranscriptOrEmpty`, `copyWith` de la
// requête d'artefact, `subjectRequired`/`style` déclaratifs.
import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

Future<void> _settle() async {
  for (int i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ZChatMessage _msg(String id) => ZChatMessage(
      id: id,
      conversationId: 'c',
      role: ZChatRole.user,
      contentBlocks: <ZContentBlock>[ZTextBlock(text: id)],
    );

void main() {
  group('G1-b — `zChatTranscriptOrEmpty` : désabonnement IMMÉDIAT', () {
    test('🔴 après `cancel`, la source est désabonnée SANS attendre un '
        'instantané suivant', () async {
      int cancelled = 0;
      final StreamController<List<ZChatMessage>> source =
          StreamController<List<ZChatMessage>>(onCancel: () => cancelled++);
      final List<List<ZChatMessage>> got = <List<ZChatMessage>>[];
      final StreamSubscription<List<ZChatMessage>> sub =
          zChatTranscriptOrEmpty(source.stream).listen(got.add);
      source.add(<ZChatMessage>[_msg('a')]);
      await _settle();
      expect(got.length, 1);
      expect(cancelled, 0);

      unawaited(sub.cancel());
      await _settle(); // AUCUN instantané poussé entre le cancel et la mesure.

      expect(cancelled, 1,
          reason: '🔴 l\'écouteur distant survivrait au dispose jusqu\'à la '
              'prochaine écriture');
      // Ce qui arrive ensuite n\'est plus lu.
      source.add(<ZChatMessage>[_msg('b')]);
      await _settle();
      expect(got.length, 1);
      await source.close();
    });

    test('la source n\'est écoutée qu\'à l\'abonnement', () async {
      bool listened = false;
      final StreamController<List<ZChatMessage>> source =
          StreamController<List<ZChatMessage>>(onListen: () => listened = true);
      final Stream<List<ZChatMessage>> s = zChatTranscriptOrEmpty(source.stream);
      await _settle();
      expect(listened, isFalse);
      final StreamSubscription<List<ZChatMessage>> sub = s.listen((_) {});
      await _settle();
      expect(listened, isTrue);
      await sub.cancel();
      await source.close();
    });

    test('sémantique inchangée : erreur avant ⇒ fil vierge ; erreur après ⇒ '
        'dernier instantané, flux fermé, jamais d\'erreur', () async {
      expect(
        await zChatTranscriptOrEmpty(
          Stream<List<ZChatMessage>>.error(StateError('x')),
        ).toList(),
        <List<ZChatMessage>>[<ZChatMessage>[]],
      );
      final StreamController<List<ZChatMessage>> c =
          StreamController<List<ZChatMessage>>();
      final Future<List<List<ZChatMessage>>> collected =
          zChatTranscriptOrEmpty(c.stream).toList();
      c.add(<ZChatMessage>[_msg('a')]);
      c.addError(StateError('coupure'));
      c.add(<ZChatMessage>[_msg('fantome')]);
      await c.close();
      final List<List<ZChatMessage>> got = await collected;
      expect(got.length, 1);
      expect(got.single.single.id, 'a');
    });
  });

  group('G1-c — `ZChatArtifactGenerationRequest.copyWith`', () {
    final ZChatArtifactGenerationRequest base = ZChatArtifactGenerationRequest(
      messageId: 'm',
      artifactKey: 'mindmap',
      notes: 'notes',
      subject: 'sujet',
      style: ZChatGenerationStyle.summarize,
      languageTag: 'fr',
      extra: <String, dynamic>{'k': 1},
    );

    test('sans argument ⇒ égal ; un champ posé ⇒ lui seul change', () {
      expect(base.copyWith(), base);
      final ZChatArtifactGenerationRequest r =
          base.copyWith(subjectRequired: true);
      expect(r.subjectRequired, isTrue);
      expect(r.copyWith(subjectRequired: false), base);
      expect(r.notes, 'notes');
      expect(r.style, ZChatGenerationStyle.summarize);
      expect(r.extra, <String, dynamic>{'k': 1});
    });

    test('un champ nullable se RETIRE par `null` explicite, se conserve par '
        'omission', () {
      expect(base.copyWith(style: null).style, isNull);
      expect(base.copyWith(languageTag: null).languageTag, isNull);
      expect(base.copyWith(notes: 'x').style, ZChatGenerationStyle.summarize);
      expect(
        base.copyWith(style: ZChatGenerationStyle.elaborate).style,
        ZChatGenerationStyle.elaborate,
      );
    });

    test('`subjectRequired` posé par copyWith change le refus sur sujet vide',
        () {
      final ZChatArtifactGenerationRequest sansSujet =
          base.copyWith(subject: '');
      expect(sansSujet.isEmptyInput, isFalse);
      expect(sansSujet.copyWith(subjectRequired: true).isEmptyInput, isTrue);
    });
  });

  group('G1-c — `ZChatArtifactDeclaration.subjectRequired` / `style`', () {
    test('défauts : faux / null, omis du JSON ; posés : sérialisés et relus',
        () {
      final ZChatArtifactDeclaration d = ZChatArtifactDeclaration(key: 'a');
      expect(d.subjectRequired, isFalse);
      expect(d.style, isNull);
      expect(d.toJson().containsKey('subject_required'), isFalse);
      expect(d.toJson().containsKey('style'), isFalse);

      final ZChatArtifactDeclaration posee = ZChatArtifactDeclaration(
        key: 'flashcards',
        subjectRequired: true,
        style: ZChatGenerationStyle('flashcards', <String, dynamic>{'n': 10}),
      );
      final Map<String, dynamic> json = posee.toJson();
      expect(json['subject_required'], isTrue);
      expect(json['style'], 'flashcards');
      expect(json['style_params'], <String, dynamic>{'n': 10});
      final ZChatArtifactDeclaration relue =
          ZChatArtifactDeclaration.fromJson(json)!;
      expect(relue.subjectRequired, isTrue);
      expect(relue.style, posee.style);
    });

    test('lecture défensive : `subject_required` mal typé ⇒ faux ; `style` '
        'illisible ⇒ null', () {
      final ZChatArtifactDeclaration d = ZChatArtifactDeclaration.fromJson(
        <String, dynamic>{
          'key': 'a',
          'subject_required': 'oui',
          'style': 42,
        },
      )!;
      expect(d.subjectRequired, isFalse);
      expect(d.style, isNull);
    });

    test('le registre transporte les deux champs', () {
      final ZChatArtifactRegistry reg = ZChatArtifactRegistry.fromJson(
        <Map<String, dynamic>>[
          <String, dynamic>{
            'key': 'm',
            'subject_required': true,
            'style': 'mindmap',
          },
        ],
      );
      expect(reg.declarationOf('m')!.subjectRequired, isTrue);
      expect(reg.declarationOf('m')!.style!.kind, 'mindmap');
    });
  });
}
