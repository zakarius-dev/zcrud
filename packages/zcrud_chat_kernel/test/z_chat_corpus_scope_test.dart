// Lot β — la **portée de corpus VÉRIFIABLE**.
//
// 🔴 CE QUE CE FICHIER DOIT PROUVER, ET QU'UNE GARDE DE PRÉSENCE NE PROUVE PAS
//
// Vérifier qu'un champ de portée **existe** sur la requête ne vaut rien : le
// socle porterait alors une restriction que personne ne peut confronter aux
// faits, exactement comme les six drapeaux de corpus d'IFFD — transmis par le
// contrôleur, **jetés** par le repository, et jamais démentis (étude
// CR-IFFD-72, § 1.1). La propriété à établir est donc :
//
//   > **une source HORS de la portée demandée est DÉTECTABLE.**
//
// Chaque test de la première section injecte une violation réelle et exige
// qu'elle soit nommée. Le second axe est tout aussi central : la confrontation
// porte sur une **CLÉ STABLE** (`ZChatSource.corpusKey`), jamais sur le
// **libellé** (`ZChatSource.corpus`) — sans quoi la vérification passerait
// quand les deux se ressemblent et tomberait dès qu'un hôte traduit son
// interface.
//
// ⚠️ `@TestOn('vm')` : la dernière section lit les SOURCES du dépôt.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_repo_sources.dart';

/// Clés de corpus **fictives** — le socle ne connaît aucune valeur métier ;
/// ces jetons sont ceux d'un hôte imaginaire, et n'ont aucun sens douanier.
const String kAlpha = 'corpus-alpha';
const String kBeta = 'corpus-beta';
const String kZeta = 'corpus-zeta';

ZChatSource _source({
  String sourceType = 'doc',
  String? corpusKey,
  String? corpus,
  String displayText = 'extrait',
}) =>
    ZChatSource(
      sourceType: sourceType,
      displayText: displayText,
      corpus: corpus,
      corpusKey: corpusKey,
    );

/// Port de streaming d'un hôte qui **prétend** honorer la portée.
///
/// [honnete] à `false` reproduit le cas qui compte : un fournisseur qui rend
/// une source d'un corpus qu'on ne lui a pas demandé.
class _FakeCorpusPort implements ZChatStreamPort {
  _FakeCorpusPort({required this.honnete});

  final bool honnete;

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async* {
    final List<String> demandees = request.corpusScope?.corpusKeys ??
        const <String>[];
    final List<ZChatSource> rendues = <ZChatSource>[
      for (final String k in demandees) _source(corpusKey: k),
      if (!honnete) _source(corpusKey: kZeta, displayText: 'hors portée'),
    ];
    yield Right<ZFailure, ZChatStreamEvent>(
      ZChatSourcesPreviewEvent(sources: rendues, sequenceId: 'e0'),
    );
    yield Right<ZFailure, ZChatStreamEvent>(
      const ZChatDoneEvent(sequenceId: 'e1'),
    );
  }
}

/// Collecte les sources d'un tour de streaming.
Future<List<ZChatSource>> _sourcesDe(
  ZChatStreamPort port,
  ZChatGenerationRequest request,
) async {
  final List<ZChatSource> out = <ZChatSource>[];
  await for (final ZResult<ZChatStreamEvent> e in port.stream(
    request,
    token: ZChatRequestToken('req-1'),
  )) {
    e.fold(
      (ZFailure _) {},
      (ZChatStreamEvent ev) {
        if (ev is ZChatSourcesPreviewEvent) out.addAll(ev.sources);
      },
    );
  }
  return out;
}

void main() {
  group('🔴 GARDE MAÎTRESSE — une source HORS PORTÉE est DÉTECTÉE', () {
    test('la violation est NOMMÉE, pas seulement comptée', () {
      final ZChatCorpusScope scope =
          ZChatCorpusScope.ofKeys(<String>[kAlpha, kBeta]);
      final ZChatSource dedans = _source(corpusKey: kAlpha);
      final ZChatSource dehors =
          _source(corpusKey: kZeta, displayText: 'intrus');

      final ZChatCorpusAudit audit =
          scope.audit(<ZChatSource>[dedans, dehors]);

      expect(audit.isSatisfied, isFalse,
          reason: '🔴 une source d\'un corpus NON demandé a été rendue et la '
              'confrontation la déclare satisfaite : la restriction est '
              'INVÉRIFIABLE, donc sans valeur.');
      expect(audit.outOfScope, <ZChatSource>[dehors]);
      expect(audit.admitted, <ZChatSource>[dedans]);
      expect(audit.violations.single.displayText, 'intrus',
          reason: 'l\'hôte doit pouvoir DÉSIGNER la source fautive');
      expect(scope.admits(dehors), isFalse);
      expect(scope.admits(dedans), isTrue);
    });

    test('🔴 le LIBELLÉ ne peut pas se faire passer pour la clé', () {
      // Le défaut que l'étude a mis au jour : `corpus` est un texte
      // d'affichage. Une source dont le LIBELLÉ coïncide avec une clé demandée
      // mais dont la CLÉ diffère doit rester détectée — sinon la vérification
      // ne mesure qu'une ressemblance de mots.
      final ZChatCorpusScope scope = ZChatCorpusScope.ofKeys(<String>[kAlpha]);
      final ZChatSource menteuse = _source(corpus: kAlpha, corpusKey: kZeta);

      expect(scope.admits(menteuse), isFalse,
          reason: '🔴 la confrontation lit `corpus` (LIBELLÉ) au lieu de '
              '`corpusKey` : il suffirait d\'un libellé bien choisi pour '
              'traverser n\'importe quelle portée.');
      expect(scope.audit(<ZChatSource>[menteuse]).outOfScope, hasLength(1));

      // Volet symétrique — NON-VACUITÉ : une source dont la CLÉ est demandée
      // passe, quel que soit son libellé (traduit, vide, trompeur).
      final ZChatSource honnete =
          _source(corpus: 'Alpha — libellé traduit', corpusKey: kAlpha);
      expect(scope.admits(honnete), isTrue,
          reason: '🔴 la garde ci-dessus deviendrait un refus TOTAL, vert pour '
              'la mauvaise raison.');
    });

    test('🔴 fail-safe — une source SANS clé est INVÉRIFIABLE, donc en défaut',
        () {
      final ZChatCorpusScope scope = ZChatCorpusScope.ofKeys(<String>[kAlpha]);
      final ZChatSource anonyme = _source(corpus: 'un corpus quelconque');

      final ZChatCorpusAudit audit = scope.audit(<ZChatSource>[anonyme]);
      expect(audit.isSatisfied, isFalse,
          reason: '🔴 présumer conforme une source qui ne porte AUCUNE clé '
              'rend la portée contournable par simple OMISSION — le '
              'fournisseur n\'a qu\'à ne rien attribuer. C\'est la prudence de '
              '`ZChatSource.isVerified`, appliquée ici.');
      expect(audit.unattributed, <ZChatSource>[anonyme]);
      expect(audit.outOfScope, isEmpty,
          reason: 'l\'hôte doit distinguer « hors portée » (le fournisseur a '
              'désobéi) de « invérifiable » (son schéma ne dit rien)');
    });

    test('deux NIVEAUX (motif porté de lex) : famille seule, puis clés', () {
      // Niveau 1 SEUL — toute la famille est admise, y compris une source non
      // attribuée : la restriction ne porte pas sur le corpus, il n'y a donc
      // rien d'invérifiable.
      final ZChatCorpusScope famille = ZChatCorpusScope(<ZChatCorpusSelector>[
        ZChatCorpusSelector(sourceType: 'article'),
      ]);
      expect(famille.admits(_source(sourceType: 'article')), isTrue);
      expect(famille.admits(_source(sourceType: 'web')), isFalse);
      expect(famille.requiresCorpusKey, isFalse);

      // Niveau 1 + 2 — la famille ET la clé doivent concorder.
      final ZChatCorpusScope precise = ZChatCorpusScope(<ZChatCorpusSelector>[
        ZChatCorpusSelector(
          sourceType: 'article',
          corpusKeys: <String>[kAlpha],
        ),
      ]);
      expect(precise.requiresCorpusKey, isTrue);
      expect(
        precise.admits(_source(sourceType: 'article', corpusKey: kAlpha)),
        isTrue,
      );
      expect(
        precise.admits(_source(sourceType: 'article', corpusKey: kBeta)),
        isFalse,
        reason: '🔴 le niveau 2 est inerte : la famille suffit à passer',
      );
      expect(
        precise.admits(_source(sourceType: 'web', corpusKey: kAlpha)),
        isFalse,
        reason: '🔴 le niveau 1 est inerte : la clé suffit à passer',
      );
    });

    test('🔴 BOUT EN BOUT par le PORT RÉEL — la portée écrite sur la requête '
        'est confrontable aux sources rendues', () async {
      final ZChatCorpusScope scope =
          ZChatCorpusScope.ofKeys(<String>[kAlpha, kBeta]);
      final ZChatGenerationRequest request = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        notes: 'question',
        corpusScope: scope,
      );

      // (1) Le port VOIT la portée — sans cela, rien de ce qui suit n'a de
      //     sens : la demande n'aurait jamais quitté l'appelant.
      final List<ZChatSource> honnetes =
          await _sourcesDe(_FakeCorpusPort(honnete: true), request);
      expect(honnetes, hasLength(2),
          reason: '🔴 le port n\'a pas reçu les clés demandées : le champ de '
              'portée ne traverse pas le contrat.');
      expect(
        request.corpusScope!.audit(honnetes).isSatisfied,
        isTrue,
        reason: 'un fournisseur conforme ne doit produire AUCUNE violation',
      );

      // (2) Le fournisseur désobéit : la confrontation le dit.
      final List<ZChatSource> douteuses =
          await _sourcesDe(_FakeCorpusPort(honnete: false), request);
      final ZChatCorpusAudit audit = request.corpusScope!.audit(douteuses);
      expect(audit.isSatisfied, isFalse);
      expect(audit.outOfScope.single.corpusKey, kZeta);
    });
  });

  group('Rétro-compatibilité — sans portée, RIEN ne change', () {
    test('une requête sans portée est identique à celle d\'avant le lot', () {
      final ZChatGenerationRequest avant = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        notes: 'n',
        responseLength: ZChatResponseLength.concise,
      );
      final ZChatGenerationRequest apres = ZChatGenerationRequest(
        style: ZChatGenerationStyle('answer'),
        notes: 'n',
        responseLength: ZChatResponseLength.concise,
      );
      expect(apres, avant);
      expect(apres.hashCode, avant.hashCode);
      expect(avant.corpusScope, isNull,
          reason: '🔴 un DÉFAUT a bougé : la portée doit être absente tant '
              'qu\'un hôte ne l\'écrit pas.');
      expect(avant.revealThinkingSteps, isNull);
    });

    test('une portée VIDE n\'interdit rien', () {
      final ZChatCorpusScope vide = ZChatCorpusScope(
        const <ZChatCorpusSelector>[],
      );
      final ZChatCorpusAudit audit = vide.audit(<ZChatSource>[
        _source(corpusKey: kZeta),
        _source(),
      ]);
      expect(vide.isUnrestricted, isTrue);
      expect(audit.isSatisfied, isTrue);
      expect(audit.admitted, hasLength(2));

      // Un sélecteur sans aucune restriction ne restreint pas davantage.
      expect(
        ZChatCorpusScope(<ZChatCorpusSelector>[ZChatCorpusSelector()])
            .isUnrestricted,
        isTrue,
      );
    });

    test('AD-10 — une charge ANCIENNE (sans `corpus_key`) se décode sans '
        'throw, clé nulle, et ne réémet pas la clé', () {
      final Map<String, dynamic> ancienne = <String, dynamic>{
        'source_type': 'article',
        'display_text': 'Article 12',
        'relevance_score': 0.8,
        'corpus': 'Recueil des textes',
        'usage_status': 'cited',
        'code_id': 'x-1',
      };
      final ZChatSource? decodee = ZChatSource.fromJson(ancienne);
      expect(decodee, isNotNull);
      expect(decodee!.corpusKey, isNull,
          reason: '🔴 une clé INVENTÉE depuis le libellé serait pire que pas '
              'de clé : elle rendrait une portée faussement satisfaite.');
      expect(decodee.corpus, 'Recueil des textes');
      expect(decodee.payload['code_id'], 'x-1', reason: 'AD-10 : rien perdu');
      expect(decodee.toJson().containsKey('corpus_key'), isFalse);
    });

    test('une charge NOUVELLE fait l\'aller-retour sans perte', () {
      final ZChatSource source = _source(
        sourceType: 'article',
        corpus: 'Recueil des textes',
        corpusKey: kAlpha,
      );
      final Map<String, dynamic> json = source.toJson();
      expect(json['corpus_key'], kAlpha);
      expect(json['corpus'], 'Recueil des textes');
      expect(ZChatSource.fromJson(json), source);
      // La clé ne doit PAS retomber dans le payload fourre-tout.
      expect(ZChatSource.fromJson(json)!.payload.containsKey('corpus_key'),
          isFalse);
    });
  });

  group('Portée — valeur, normalisation, décodage défensif', () {
    test('l\'ordre de saisie n\'est pas une information', () {
      expect(
        ZChatCorpusScope.ofKeys(<String>[kBeta, kAlpha]),
        ZChatCorpusScope.ofKeys(<String>[kAlpha, kBeta]),
      );
      expect(
        ZChatCorpusScope.ofKeys(<String>[kBeta, kAlpha]).hashCode,
        ZChatCorpusScope.ofKeys(<String>[kAlpha, kBeta]).hashCode,
      );
      // Doublons fusionnés, blancs et vides écartés — une chaîne blanche n'est
      // pas une clé, et ne doit surtout pas devenir une clé « vide » qu'une
      // source sans attribution pourrait satisfaire.
      final ZChatCorpusSelector s = ZChatCorpusSelector(
        corpusKeys: <String>[' $kAlpha ', kAlpha, '', '   '],
      );
      expect(s.corpusKeys, <String>[kAlpha]);
      expect(s.admits(_source(corpusKey: '  ')), isFalse);
      expect(s.admits(_source(corpusKey: ' $kAlpha')), isTrue);
    });

    test('AD-10 — décodage défensif, jamais de throw', () {
      expect(ZChatCorpusScope.fromJson(42), isNull);
      expect(ZChatCorpusScope.fromJson(null), isNull);
      expect(ZChatCorpusSelector.fromJson('texte'), isNull);

      // Un sélecteur illisible est SAUTÉ ; il n'annule pas les autres.
      final ZChatCorpusScope? scope = ZChatCorpusScope.fromJson(
        <String, dynamic>{
          'selectors': <dynamic>[
            'pas une map',
            <String, dynamic>{
              'source_type': 'article',
              'corpus_keys': <dynamic>[kAlpha, 7],
            },
          ],
        },
      );
      expect(scope, isNotNull);
      expect(scope!.selectors, hasLength(1));
      expect(scope.selectors.single.corpusKeys, <String>[kAlpha]);
      expect(scope.toJson(), ZChatCorpusScope.fromJson(scope.toJson())!.toJson());
    });
  });

  group('FR-26 — le socle porte le MÉCANISME, jamais les VALEURS', () {
    test('aucune valeur métier dans le code de la portée (grep négatif)', () {
      final File f = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/ai/'
        'z_chat_corpus_scope.dart',
      );
      expect(f.existsSync(), isTrue, reason: 'garde VACUELLE');
      // Commentaires RETIRÉS : la dartdoc DOIT pouvoir citer ce qu'elle écarte
      // (les familles codées en dur de lex) pour documenter POURQUOI.
      final String code = strippedLines(f).join('\n').toLowerCase();
      for (final String metier in <String>[
        'douane',
        'cedeao',
        'gatt',
        'tarif',
        'tec_',
        'enablecodes',
      ]) {
        expect(code.contains(metier), isFalse,
            reason: '🔴 « $metier » est une valeur d\'HÔTE. Le socle ne '
                'connaît aucune famille ni aucun corpus : c\'est ce qui '
                'l\'empêche d\'imposer la douane à IFFD et à DODLP.');
      }
    });
  });
}
