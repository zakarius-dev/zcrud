// Lot K1 — capacités booléennes VÉRIFIABLES sur le porteur de réglages.
//
// 🔴 TROIS PROPRIÉTÉS, PAS UNE PRÉSENCE
//
// (1) RÉTRO-COMPAT TOTALE : un réglage ancien (sans `webSearch` ni
//     `capabilities`) se décode/compare/copie À L'IDENTIQUE — aucun champ
//     nouveau n'apparaît dans sa persistance.
// (2) UNE SEULE LECTURE : la recherche web s'écrit soit par le champ typé,
//     soit par la clé canonique du canal ouvert — les deux écritures sont la
//     MÊME demande (`==`, `toJson`, `capability`, audit identiques). Jamais
//     « deux lectures conformes mais incompatibles ».
// (3) 🔴 JAMAIS DE REPLI MUET (règle v0.52.0) : une capacité que l'exécuteur
//     n'a pas honorée est NOMMÉE par `auditCapabilities` — pas « le champ
//     existe », mais « le silence est détecté ». Pendant exact de
//     `ZChatCorpusScope.audit`.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  group('Rétro-compat TOTALE — un réglage ancien est intact au bit près', () {
    test('l\'écriture d\'AVANT le lot compare, copie et sérialise à '
        'l\'identique', () {
      const ZChatGenerationSettings ancien = ZChatGenerationSettings(
        lengthBias: ZChatLengthBias.shorter,
      );
      // `==` et `hashCode` : la vieille écriture reste égale à elle-même et
      // distincte d'une autre — aucun champ nouveau n'entre dans la balance.
      expect(
        ancien,
        const ZChatGenerationSettings(lengthBias: ZChatLengthBias.shorter),
      );
      expect(ancien.webSearch, isNull);
      expect(ancien.capabilities, isEmpty);
      expect(ancien.expressedCapabilityKeys, isEmpty);

      // copyWith sans les nouveaux paramètres : rien n'apparaît.
      final ZChatGenerationSettings copie =
          ancien.copyWith(revealThinkingSteps: true);
      expect(copie.webSearch, isNull);
      expect(copie.capabilities, isEmpty);
      expect(copie.lengthBias, ZChatLengthBias.shorter);

      // 🔴 Persistance : AUCUNE clé nouvelle dans le document d'un ancien.
      final Map<String, dynamic> json = ancien.toJson();
      expect(json.containsKey('web_search'), isFalse,
          reason: '🔴 un réglage qui n\'exprime pas la recherche web ne doit '
              'JAMAIS l\'écrire — « non réglé » deviendrait « réglé » chez '
              'tout consommateur du document.');
      expect(json.containsKey('capabilities'), isFalse);
      expect(json.keys, <String>['length_bias']);
    });

    test('un document ANCIEN se décode sans qu\'aucune capacité soit inventée '
        '(AD-10)', () {
      final ZChatGenerationSettings? lu =
          ZChatGenerationSettings.fromJson(<String, dynamic>{
        'response_length': 'concise',
        'compute_effort': 3,
      });
      expect(lu, isNotNull);
      expect(lu!.webSearch, isNull,
          reason: '🔴 DÉFAUT INVENTÉ : le document ancien ne dit rien de la '
              'recherche web, le porteur non plus.');
      expect(lu.capabilities, isEmpty);
      expect(lu.responseLength, ZChatResponseLength.concise);
    });

    test('`withSettings(null)` reste `identical`, et la requête ancienne '
        'projette des capacités vides', () {
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        responseLength: ZChatResponseLength.detailed,
      );
      expect(identical(requete.withSettings(null), requete), isTrue);
      expect(requete.webSearch, isNull);
      expect(requete.capabilities, isEmpty);
      expect(requete.settings.isEmpty, isFalse); // responseLength exprimée
      expect(requete.settings.expressedCapabilityKeys, isEmpty);
    });
  });

  group('Bijection ÉTENDUE — les nouveaux réglages voyagent, jamais inertes',
      () {
    test('chaque capacité compte INDIVIDUELLEMENT dans l\'aller-retour '
        'porteur ↔ requête', () {
      final ZChatGenerationRequest base = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        notes: 'n',
      );
      final List<ZChatGenerationSettings> variantes =
          <ZChatGenerationSettings>[
        const ZChatGenerationSettings(webSearch: true),
        const ZChatGenerationSettings(webSearch: false),
        const ZChatGenerationSettings(
          capabilities: <String, bool>{'summary': true},
        ),
      ];
      for (final ZChatGenerationSettings v in variantes) {
        final ZChatGenerationRequest r = base.withSettings(v);
        expect(r == base, isFalse,
            reason: '🔴 réglage INERTE : $v n\'a pas changé la requête — le '
                'repli muet à la construction.');
        expect(r.settings, v,
            reason: '🔴 $v n\'est pas relu à l\'identique : la projection '
                'PERD la capacité en route.');
        expect(r.notes, base.notes);
        expect(r.style, base.style);
      }
    });

    test('`withCorpusScope` PRÉSERVE les capacités (aucune perte par effet de '
        'bord)', () {
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        webSearch: true,
        capabilities: const <String, bool>{'summary': true},
      );
      final ZChatGenerationRequest avecPortee = requete.withCorpusScope(
        ZChatCorpusScope.ofKeys(<String>['corpus-alpha']),
      );
      expect(avecPortee.webSearch, isTrue,
          reason: '🔴 régler la portée a EFFACÉ la recherche web : perte '
              'silencieuse entre deux axes indépendants.');
      expect(avecPortee.capabilities, <String, bool>{'summary': true});
    });

    test('un porteur VIDE retire aussi les capacités (remplacement, pas '
        'fusion)', () {
      final ZChatGenerationRequest requete = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        webSearch: true,
        capabilities: const <String, bool>{'summary': true},
      );
      final ZChatGenerationRequest nettoyee =
          requete.withSettings(const ZChatGenerationSettings());
      expect(nettoyee.webSearch, isNull);
      expect(nettoyee.capabilities, isEmpty,
          reason: 'une feuille de réglages qui retire une capacité doit '
              'pouvoir la retirer.');
    });

    test('une régénération porte ses capacités et reste comparable', () {
      const ZChatRegenerateAction avec = ZChatRegenerateAction(
        messageId: 'm1',
        settings: ZChatGenerationSettings(webSearch: true),
      );
      const ZChatRegenerateAction sans = ZChatRegenerateAction(
        messageId: 'm1',
      );
      expect(avec.overridesRequest, isTrue,
          reason: '🔴 une capacité demandée doit exiger la forme riche — '
              'sinon l\'exécuteur historique la jette en silence.');
      expect(avec == sans, isFalse);
      expect(avec.settings!.capability(kZChatCapabilityWebSearch), isTrue);
    });
  });

  group('UNE SEULE LECTURE — champ typé et clé canonique sont la MÊME demande',
      () {
    const ZChatGenerationSettings typee =
        ZChatGenerationSettings(webSearch: true);
    const ZChatGenerationSettings ouverte = ZChatGenerationSettings(
      capabilities: <String, bool>{kZChatCapabilityWebSearch: true},
    );

    test('`==`, `toJson`, `capability` et l\'audit coïncident', () {
      expect(typee, ouverte,
          reason: '🔴 DEUX LECTURES : la même demande écrite par deux canaux '
              'donne deux valeurs inégales — tout cache/déduplication les '
              'traiterait comme deux demandes.');
      expect(typee.hashCode, ouverte.hashCode);
      expect(typee.toJson(), ouverte.toJson());
      expect(ouverte.capability(kZChatCapabilityWebSearch), isTrue);
      expect(typee.expressedCapabilityKeys, ouverte.expressedCapabilityKeys);
      expect(
        typee.toJson(),
        <String, dynamic>{kZChatCapabilityWebSearch: true},
        reason: 'la forme émise est canonique : clé de premier niveau, '
            'jamais dans `capabilities`.',
      );
    });

    test('le décodage HISSE la clé réservée vers le champ typé', () {
      final ZChatGenerationSettings? lu =
          ZChatGenerationSettings.fromJson(<String, dynamic>{
        'capabilities': <String, dynamic>{
          kZChatCapabilityWebSearch: true,
          'summary': false,
        },
      });
      expect(lu!.webSearch, isTrue);
      expect(lu.capabilities, <String, bool>{'summary': false},
          reason: 'la clé réservée ne doit JAMAIS rester dans le canal '
              'ouvert après décodage — une seule écriture canonique.');
      // Et le champ de premier niveau PRIME si les deux sont présents.
      final ZChatGenerationSettings? conflit =
          ZChatGenerationSettings.fromJson(<String, dynamic>{
        kZChatCapabilityWebSearch: false,
        'capabilities': <String, dynamic>{kZChatCapabilityWebSearch: true},
      });
      expect(conflit!.webSearch, isFalse,
          reason: 'priorité UNIQUE documentée : champ typé d\'abord.');
    });

    test('la requête canonicalise EAGER : la clé réservée du canal ouvert '
        'devient le champ typé', () {
      final ZChatGenerationRequest r = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        capabilities: const <String, bool>{
          kZChatCapabilityWebSearch: true,
          ' summary ': true,
        },
      );
      expect(r.webSearch, isTrue);
      expect(r.capabilities, <String, bool>{'summary': true},
          reason: 'clés rognées, clé réservée hissée : une requête n\'a '
              'qu\'UNE écriture possible.');
    });

    test('décodage DÉFENSIF du canal ouvert (AD-10) : valeur non booléenne '
        'SAUTÉE, jamais convertie', () {
      final ZChatGenerationSettings? lu =
          ZChatGenerationSettings.fromJson(<String, dynamic>{
        'capabilities': <String, dynamic>{
          'summary': 'oui',
          'draft': 1,
          'scraping': false,
          '  ': true,
        },
      });
      expect(lu!.capabilities, <String, bool>{'scraping': false},
          reason: '🔴 `\'oui\'`/`1` convertis en booléen = une demande '
              'INVENTÉE ; une valeur illisible est une capacité ABSENTE.');
      expect(ZChatGenerationSettings.fromJson(<String, dynamic>{
        'capabilities': 'pas une map',
      })!
          .capabilities,
          isEmpty);
    });

    test('aller-retour JSON sans perte sur la forme canonique', () {
      const ZChatGenerationSettings reglages = ZChatGenerationSettings(
        responseLength: ZChatResponseLength.concise,
        webSearch: false,
        capabilities: <String, bool>{'summary': true, 'long_draft': false},
      );
      expect(ZChatGenerationSettings.fromJson(reglages.toJson()), reglages);
    });
  });

  group('🔴 JAMAIS DE REPLI MUET — la capacité non honorée est DÉTECTABLE', () {
    const ZChatGenerationSettings demande = ZChatGenerationSettings(
      webSearch: true,
      capabilities: <String, bool>{'summary': true, 'long_draft': false},
    );

    test('une clé exprimée ABSENTE de l\'écho est NOMMÉE non honorée', () {
      final ZChatCapabilityAudit constat =
          demande.auditCapabilities(<String>[kZChatCapabilityWebSearch]);
      expect(constat.isSatisfied, isFalse,
          reason: '🔴 REPLI MUET : le port n\'a compris que `web_search`, '
              'l\'hôte a demandé « résumé » et « pas de brouillon long » — '
              'déclarer la demande satisfaite est EXACTEMENT le défaut IFFD '
              '(six drapeaux jetés par le repository sans signal).');
      expect(constat.unhonored, <String>['long_draft', 'summary'],
          reason: 'les muettes sont NOMMÉES — l\'hôte peut masquer l\'option '
              'ou avertir sans parser de texte.');
      expect(constat.honored, <String>[kZChatCapabilityWebSearch]);
    });

    test('fail-safe : SANS écho, TOUT ce qui est exprimé est non honoré — '
        'jamais « probablement passé »', () {
      final ZChatCapabilityAudit constat =
          demande.auditCapabilities(const <String>[]);
      expect(constat.isSatisfied, isFalse);
      expect(constat.unhonored, constat.requested,
          reason: '🔴 en l\'absence de signal on ne présume JAMAIS '
              '« honoré » — même règle que `ZChatCorpusSelector.admits` sur '
              'une source sans clé.');
    });

    test('une capacité demandée à FALSE exige d\'être honorée autant qu\'à '
        'true', () {
      expect(demande.expressedCapabilityKeys, contains('long_draft'),
          reason: '🔴 « coupe cette capacité » est une DEMANDE : un port qui '
              'ne sait pas couper ne doit pas laisser croire qu\'il a coupé.');
    });

    test('écho complet ⇒ satisfait ; clé échoée JAMAIS demandée ⇒ désaccord '
        'de schéma constaté, pas une violation', () {
      final ZChatCapabilityAudit constat = demande.auditCapabilities(<String>[
        kZChatCapabilityWebSearch,
        'summary',
        'long_draft',
        'scraping',
      ]);
      expect(constat.isSatisfied, isTrue);
      expect(constat.unhonored, isEmpty);
      expect(constat.unrequested, <String>['scraping'],
          reason: 'l\'exécuteur prétend avoir honoré une demande qui '
              'n\'existe pas : symptôme de schéma divergent, à la main de '
              'l\'hôte.');
    });

    test('un porteur sans capacité n\'a rien promis : satisfait par '
        'construction', () {
      const ZChatGenerationSettings ancien = ZChatGenerationSettings(
        responseLength: ZChatResponseLength.concise,
      );
      final ZChatCapabilityAudit constat =
          ancien.auditCapabilities(const <String>[]);
      expect(constat.isSatisfied, isTrue);
      expect(constat.requested, isEmpty);
    });

    test('l\'audit est INDIFFÉRENT au canal d\'écriture de la recherche web',
        () {
      const ZChatGenerationSettings ouverte = ZChatGenerationSettings(
        capabilities: <String, bool>{kZChatCapabilityWebSearch: true},
      );
      const ZChatGenerationSettings typee =
          ZChatGenerationSettings(webSearch: true);
      expect(
        ouverte.auditCapabilities(const <String>[]).unhonored,
        typee.auditCapabilities(const <String>[]).unhonored,
      );
      expect(ouverte.auditCapabilities(const <String>[]).unhonored,
          <String>[kZChatCapabilityWebSearch]);
    });

    test('le constat CONSTATE : listes figées, rien n\'est filtré ni levé', () {
      final ZChatCapabilityAudit constat =
          demande.auditCapabilities(const <String>[]);
      expect(() => constat.unhonored.add('x'), throwsUnsupportedError);
      expect(() => constat.requested.clear(), throwsUnsupportedError);
    });
  });
}
