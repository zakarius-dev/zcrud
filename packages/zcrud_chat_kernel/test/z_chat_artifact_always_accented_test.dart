/// Le drapeau de TEINTE PERMANENTE sur la voie DÉCLARATIVE des artefacts.
///
/// Le défaut fermé : le drapeau existait sur la forme de rendu, pas sur la
/// déclaration. Un hôte qui déclare ses artefacts par le registre — la voie
/// que ce socle recommande — n'y avait aucun accès, et devait redescendre
/// d'un cran pour une seule propriété.
///
/// * **ACC-1** — le drapeau est déclarable, et son défaut est `false` :
///   une déclaration existante ne change pas de sens.
/// * **ACC-2** — ALLER-RETOUR : posé, il survit à `toJson`/`fromJson`.
/// * **ACC-3** — OMISSION : à `false` il n'entre PAS dans la charge utile
///   (les champs par défaut sont omis — l'inertie de la sérialisation).
/// * **ACC-4** — DÉFENSIF (AD-10) : une charge sans la clé, ou portant une
///   valeur d'un autre type, rend `false` sans lever.
/// * **ACC-5** — AD-19.1 : `always_accented` est une clé RÉSERVÉE — un hôte
///   ne peut pas la faire entrer par `extra` et écraser la clé propre.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  group('🔴 ACC — la teinte permanente sur la déclaration', () {
    test('ACC-1 déclarable, et `false` par défaut', () {
      expect(
        ZChatArtifactDeclaration(key: 'mindmap').alwaysAccented,
        isFalse,
        reason: '🔴 une déclaration existante a changé de sens',
      );
      expect(
        ZChatArtifactDeclaration(key: 'mindmap', alwaysAccented: true)
            .alwaysAccented,
        isTrue,
      );
    });

    test('ACC-2 aller-retour : posé, il survit à la sérialisation', () {
      final Map<String, dynamic> json =
          ZChatArtifactDeclaration(key: 'mindmap', alwaysAccented: true)
              .toJson();
      expect(json['always_accented'], isTrue);
      expect(
        ZChatArtifactDeclaration.fromJson(json)!.alwaysAccented,
        isTrue,
        reason: '🔴 le drapeau est PERDU au décodage',
      );
    });

    test('ACC-3 à `false`, la clé n\'entre pas dans la charge utile', () {
      final Map<String, dynamic> json =
          ZChatArtifactDeclaration(key: 'mindmap').toJson();
      expect(
        json.containsKey('always_accented'),
        isFalse,
        reason: '🔴 une déclaration inchangée produit désormais une charge '
            'utile plus grosse',
      );
      // Contre-preuve : la clé propre EST émise quand elle vaut `true` —
      // sans elle, l'assertion d'omission serait vraie pour rien.
      expect(
        ZChatArtifactDeclaration(key: 'm', alwaysAccented: true)
            .toJson()
            .containsKey('always_accented'),
        isTrue,
      );
    });

    test('ACC-4 défensif : clé absente ou d\'un autre type ⇒ `false`', () {
      expect(
        ZChatArtifactDeclaration.fromJson(<String, dynamic>{
          'key': 'mindmap',
        })!.alwaysAccented,
        isFalse,
      );
      // Les formes que la convention partagée n'interprète PAS — mesuré,
      // pas supposé : `1` et « true » y sont vrais, cf. ACC-4b.
      for (final Object? junk in <Object?>[
        <String>['true'],
        <String, dynamic>{},
        'oui',
        null,
      ]) {
        expect(
          ZChatArtifactDeclaration.fromJson(<String, dynamic>{
            'key': 'mindmap',
            'always_accented': junk,
          })!.alwaysAccented,
          isFalse,
          reason: '🔴 une valeur ${junk.runtimeType} a été interprétée, ou a '
              'levé (AD-10)',
        );
      }
    });

    test('ACC-4b la lecture suit la MÊME convention que les drapeaux voisins',
        () {
      // Mesuré, pas supposé : `zJsonBool` accepte la chaîne « true ». Le
      // drapeau neuf ne se dote pas d'une convention à lui — ce serait deux
      // règles de décodage dans une même charge utile.
      for (final Object? raw in <Object?>['true', true, 'false', false, 'x']) {
        final ZChatArtifactDeclaration a = ZChatArtifactDeclaration.fromJson(
          <String, dynamic>{'key': 'm', 'always_accented': raw},
        )!;
        final ZChatArtifactDeclaration b = ZChatArtifactDeclaration.fromJson(
          <String, dynamic>{'key': 'm', 'has_count': raw},
        )!;
        expect(
          a.alwaysAccented,
          b.hasCount,
          reason: '🔴 « $raw » n\'est pas lu comme le drapeau voisin le lit',
        );
      }
    });

    test('ACC-5 AD-19.1 : `always_accented` est une clé RÉSERVÉE d\'`extra`',
        () {
      final ZChatArtifactDeclaration d = ZChatArtifactDeclaration(
        key: 'mindmap',
        extra: const <String, dynamic>{
          'always_accented': true,
          'libre': 'gardé',
        },
      );
      expect(
        d.extra.containsKey('always_accented'),
        isFalse,
        reason: '🔴 la clé propre peut être écrasée par `extra` (AD-19.1)',
      );
      expect(d.extra['libre'], 'gardé', reason: 'contre-preuve : `extra` vit');
      expect(
        d.toJson()['extra'],
        isNot(contains('always_accented')),
        reason: '🔴 la clé réservée est RÉÉMISE par `toJson`',
      );
    });
  });
}
