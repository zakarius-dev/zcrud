// CR-IFFD-124 (correctif) — le mode d'activation d'un artefact est une
// donnée DÉCLARATIVE : il se persiste, se relit, et retombe sur le menu.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  group('ZChatArtifactActivation — persistance défensive', () {
    test('aller-retour JSON : `direct` et `confirm` se conservent, le prompt '
        'aussi', () {
      final ZChatArtifactDeclaration d = ZChatArtifactDeclaration(
        key: 'mindmap',
        activation: ZChatArtifactActivation.confirm,
        activationPromptToken: 'prompt.mindmap',
      );
      final Map<String, dynamic> json = d.toJson();
      expect(json['activation'], 'confirm');
      expect(json['activation_prompt_token'], 'prompt.mindmap');
      final ZChatArtifactDeclaration? back = ZChatArtifactDeclaration.fromJson(
        json,
      );
      expect(back, isNotNull);
      expect(back!.activation, ZChatArtifactActivation.confirm);
      expect(back.activationPromptToken, 'prompt.mindmap');
      expect(
        ZChatArtifactDeclaration.fromJson(
          ZChatArtifactDeclaration(
            key: 'k',
            activation: ZChatArtifactActivation.direct,
          ).toJson(),
        )!.activation,
        ZChatArtifactActivation.direct,
      );
    });

    test('le DÉFAUT est `menu`, il est omis du JSON, et une valeur inconnue '
        'y retombe', () {
      final ZChatArtifactDeclaration d = ZChatArtifactDeclaration(key: 'k');
      expect(d.activation, ZChatArtifactActivation.menu);
      expect(
        d.toJson().containsKey('activation'),
        isFalse,
        reason: 'un champ par défaut est omis, comme les voisins',
      );
      // Parse TOTAL : une valeur inconnue ne lève pas et retombe sur le mode
      // le plus prudent — celui qui n'exécute rien au toucher.
      expect(
        ZChatArtifactActivation.fromJson('explode'),
        ZChatArtifactActivation.menu,
      );
      expect(
        ZChatArtifactActivation.fromJson(null),
        ZChatArtifactActivation.menu,
      );
      // Et la clé est RÉSERVÉE : elle ne resurgit pas dans `extra`.
      final ZChatArtifactDeclaration polluted = ZChatArtifactDeclaration(
        key: 'k',
        extra: <String, dynamic>{
          'activation': 'direct',
          'activation_prompt_token': 'x',
          'libre': 1,
        },
      );
      expect(polluted.extra, <String, dynamic>{'libre': 1});
      expect(polluted.activation, ZChatArtifactActivation.menu);
    });
  });
}
