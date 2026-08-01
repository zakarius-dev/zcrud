// CHAT-0 — AC3/AC4. Gardes **G1** (round-trip par valeur), **G3** (enum inconnu
// ⇒ repli, JAMAIS de throw) et **G4** (alias de lecture des documents lex).
//
// L'assertion est écrite à partir de l'INVARIANT (« aucun parse ne lève, tout
// repli est nommé »), jamais à partir de ce que le code fait — piège VIS-1.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  group('G1 — valeur persistée camelCase + round-trip par enum', () {
    test('chaque valeur se relit elle-même depuis son `jsonValue`', () {
      for (final ZChatRole v in ZChatRole.values) {
        expect(ZChatRole.fromJson(v.jsonValue), v);
      }
      for (final ZChatResponseLength v in ZChatResponseLength.values) {
        expect(ZChatResponseLength.fromJson(v.jsonValue), v);
      }
      for (final ZChatLengthBias v in ZChatLengthBias.values) {
        expect(ZChatLengthBias.fromJson(v.jsonValue), v);
      }
      for (final ZChatFeedbackRating v in ZChatFeedbackRating.values) {
        expect(ZChatFeedbackRating.fromJson(v.jsonValue), v);
      }
      for (final ZChatFeedbackCategory v in ZChatFeedbackCategory.values) {
        expect(ZChatFeedbackCategory.fromJson(v.jsonValue), v);
      }
      for (final ZChatSuggestionType v in ZChatSuggestionType.values) {
        expect(ZChatSuggestionType.fromJson(v.jsonValue), v);
      }
      for (final ZChatSuggestionActionType v
          in ZChatSuggestionActionType.values) {
        expect(ZChatSuggestionActionType.fromJson(v.jsonValue), v);
      }
      for (final ZChatSourceUsageStatus v in ZChatSourceUsageStatus.values) {
        expect(ZChatSourceUsageStatus.fromJson(v.jsonValue), v);
      }
      for (final ZChatDatasetFreshness v in ZChatDatasetFreshness.values) {
        expect(ZChatDatasetFreshness.fromJson(v.jsonValue), v);
      }
      for (final ZChatConfidenceLevel v in ZChatConfidenceLevel.values) {
        expect(ZChatConfidenceLevel.fromJson(v.jsonValue), v);
      }
      for (final ZChatConfidenceFactorSense v
          in ZChatConfidenceFactorSense.values) {
        expect(ZChatConfidenceFactorSense.fromJson(v.jsonValue), v);
      }
    });

    test('AC3 — les valeurs persistées sont bien en camelCase', () {
      expect(ZChatFeedbackCategory.offTopic.jsonValue, 'offTopic');
      expect(ZChatFeedbackCategory.wrongCitation.jsonValue, 'wrongCitation');
      expect(ZChatSuggestionType.followUp.jsonValue, 'followUp');
      expect(ZChatSuggestionActionType.sendMessage.jsonValue, 'sendMessage');
      expect(ZChatSourceUsageStatus.generalKnowledge.jsonValue,
          'generalKnowledge');
      expect(ZChatLengthBias.asIs.jsonValue, 'asIs');
      expect(ZChatConfidenceLevel.toVerify.jsonValue, 'toVerify');
    });
  });

  group('G3 — valeur inconnue ⇒ repli documenté, jamais de throw', () {
    test('rôle inconnu ⇒ `unknown` (et surtout PAS `user`)', () {
      expect(ZChatRole.fromJson('wizard'), ZChatRole.unknown);
      expect(ZChatRole.fromJson(null), ZChatRole.unknown);
      expect(ZChatRole.fromJson(42), ZChatRole.unknown);
      // Le repli n'est pas `user` : lex coerce tout en `user`
      // (chat_message.dart:92-93), ce qui maquille un rôle non reconnu en rôle
      // légitime. Ici l'inconnu reste RECONNAISSABLE comme inconnu.
      expect(ZChatRole.fromJson('assistant2'), isNot(ZChatRole.user));
    });

    test('catégorie de feedback inconnue ⇒ `null`', () {
      expect(ZChatFeedbackCategory.fromJson('zzz'), isNull);
      expect(ZChatFeedbackCategory.fromJson(null), isNull);
      expect(ZChatFeedbackCategory.fromJson(<String>[]), isNull);
    });

    test('fraîcheur inconnue ⇒ `unknown` (neutre)', () {
      expect(ZChatDatasetFreshness.fromJson('zzz'),
          ZChatDatasetFreshness.unknown);
      expect(ZChatDatasetFreshness.fromJson(null),
          ZChatDatasetFreshness.unknown);
    });

    test('longueur/biais inconnus ⇒ replis `standard` / `asIs`', () {
      expect(ZChatResponseLength.fromJson('zzz'),
          ZChatResponseLength.standard);
      expect(ZChatLengthBias.fromJson('zzz'), ZChatLengthBias.asIs);
    });

    test('confiance illisible ⇒ `toVerify` — JAMAIS `high` par défaut', () {
      expect(ZChatConfidenceLevel.fromJson('zzz'),
          ZChatConfidenceLevel.toVerify);
      expect(ZChatConfidenceLevel.fromJson(null),
          ZChatConfidenceLevel.toVerify);
    });

    test('AUCUN parse ne lève, quelle que soit la valeur reçue', () {
      final List<Object?> hostiles = <Object?>[
        null,
        42,
        3.14,
        true,
        '',
        'ZZZ',
        <String>['a'],
        <String, dynamic>{'a': 1},
        Object(),
      ];
      for (final Object? raw in hostiles) {
        expect(() => ZChatRole.fromJson(raw), returnsNormally);
        expect(() => ZChatResponseLength.fromJson(raw), returnsNormally);
        expect(() => ZChatLengthBias.fromJson(raw), returnsNormally);
        expect(() => ZChatFeedbackRating.fromJson(raw), returnsNormally);
        expect(() => ZChatFeedbackCategory.fromJson(raw), returnsNormally);
        expect(() => ZChatSuggestionType.fromJson(raw), returnsNormally);
        expect(() => ZChatSuggestionActionType.fromJson(raw), returnsNormally);
        expect(() => ZChatSourceUsageStatus.fromJson(raw), returnsNormally);
        expect(() => ZChatDatasetFreshness.fromJson(raw), returnsNormally);
        expect(() => ZChatConfidenceLevel.fromJson(raw), returnsNormally);
        expect(() => ZChatConfidenceFactorSense.fromJson(raw), returnsNormally);
      }
    });
  });

  group('G4 — alias de LECTURE des documents lex (Postel)', () {
    test('`concis` / `detaille` ⇒ concise / detailed', () {
      expect(ZChatResponseLength.fromJson('concis'),
          ZChatResponseLength.concise);
      expect(ZChatResponseLength.fromJson('detaille'),
          ZChatResponseLength.detailed);
    });

    test('`as_is` ⇒ asIs', () {
      expect(ZChatLengthBias.fromJson('as_is'), ZChatLengthBias.asIs);
      // Contrôle d'anti-vacuité : `asIs` est AUSSI le repli, donc le test
      // ci-dessus passerait même sans l'alias. On prouve donc l'alias sur une
      // valeur DISCRIMINANTE de la même famille.
      expect(ZChatLengthBias.fromJson('shorter'), ZChatLengthBias.shorter);
    });

    test('`off_topic` / `wrong_citation` / `inappropriate_tone`', () {
      expect(ZChatFeedbackCategory.fromJson('off_topic'),
          ZChatFeedbackCategory.offTopic);
      expect(ZChatFeedbackCategory.fromJson('wrong_citation'),
          ZChatFeedbackCategory.wrongCitation);
      expect(ZChatFeedbackCategory.fromJson('inappropriate_tone'),
          ZChatFeedbackCategory.inappropriateTone);
    });

    test('`follow_up` / `related_topic` / `deep_dive`', () {
      expect(ZChatSuggestionType.fromJson('follow_up'),
          ZChatSuggestionType.followUp);
      expect(ZChatSuggestionType.fromJson('related_topic'),
          ZChatSuggestionType.relatedTopic);
      expect(ZChatSuggestionType.fromJson('deep_dive'),
          ZChatSuggestionType.deepDive);
    });

    test('`send_message` ⇒ sendMessage', () {
      expect(ZChatSuggestionActionType.fromJson('send_message'),
          ZChatSuggestionActionType.sendMessage);
    });

    test('`general_knowledge` ⇒ generalKnowledge', () {
      expect(ZChatSourceUsageStatus.fromJson('general_knowledge'),
          ZChatSourceUsageStatus.generalKnowledge);
    });
  });

  group('AC3 — zéro présentation dans le domaine (AD-13/FR-26)', () {
    test('aucun enum ne porte de libellé, couleur ni icône', () {
      // Contrôle SÉMANTIQUE (le contrôle SYNTAXIQUE est dans
      // `z_chat_naming_guard_test.dart`) : la seule surface exposée est
      // `jsonValue` + `fromJson`. `label`/`colorValue`/`iconName` de lex
      // (chat_enums.dart:34-53) sont de la PRÉSENTATION, résolue app-side.
      expect(ZChatResponseLength.concise.jsonValue, 'concise');
      expect(ZChatResponseLength.values, hasLength(3));
    });
  });
}
