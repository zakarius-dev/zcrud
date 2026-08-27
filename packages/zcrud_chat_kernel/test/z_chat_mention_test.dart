// Vocabulaire des MENTIONS : candidat, déclencheur, reconnaissance, port de
// source. Ces gardes couvrent quatre propriétés, et rien d'autre :
//   (1) aller-retour de sérialisation FIDÈLE (AD-4/AD-10) ;
//   (2) décodage DÉFENSIF — corrompu / absent / mauvais type ⇒ repli SANS
//       lever, et un repli DOCUMENTÉ (jamais une exception avalée) ;
//   (3) `extra` FILTRÉ (AD-19.1) : clé de sync ou clé propre n'entre pas, et
//       n'est pas réémise par `toJson` ;
//   (4) le port est INERTE par défaut : une source absente rend une liste
//       vide, pas une exception.
//
// R3 (rouge par ASSERTION, jamais par compilation) :
//  • retirer `...ZSyncMeta.reservedKeys` de `_reservedKeys` ⇒ (3) rougit ;
//  • remplacer `zSanitizeExtra` par `Map.unmodifiable` ⇒ (3) rougit ;
//  • rendre `character` par défaut `'@'` au lieu de refuser le vide ⇒ (2)
//    rougit sur `fromJson` d'une amorce blanche ;
//  • supprimer le contrôle `requiresLeadingBoundary` ⇒ (5) rougit ;
//  • faire rendre à `ZChatEmptyMentionSource` un `Left` ⇒ (4) rougit.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

const Map<String, dynamic> _polluted = <String, dynamic>{
  'host': 'kept',
  ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00Z',
  ZSyncMeta.kIsDeleted: true,
  'key': 'smuggled',
  'character': 'smuggled',
};

void main() {
  group('ZChatMentionCandidate — aller-retour et repli', () {
    test('aller-retour FIDÈLE : chaque champ déclaré revient', () {
      final ZChatMentionCandidate c = ZChatMentionCandidate(
        key: 'doc-42',
        label: 'Rapport annuel',
        sublabel: 'dossiers/2026',
        iconKey: 'file',
        kindKey: 'document',
        insertText: '[Rapport annuel](doc-42)',
        disabledReasonToken: 'quota',
        order: 3,
        extra: <String, dynamic>{'host': 1},
      );
      final ZChatMentionCandidate back =
          ZChatMentionCandidate.fromJson(c.toJson())!;
      expect(back.key, 'doc-42');
      expect(back.label, 'Rapport annuel');
      expect(back.sublabel, 'dossiers/2026');
      expect(back.iconKey, 'file');
      expect(back.kindKey, 'document');
      expect(back.insertText, '[Rapport annuel](doc-42)');
      expect(back.disabledReasonToken, 'quota');
      expect(back.isEnabled, isFalse);
      expect(back.order, 3);
      expect(back.extra, <String, dynamic>{'host': 1});
    });

    test('les défauts sont OMIS de `toJson` (forme minimale)', () {
      final Map<String, dynamic> out = ZChatMentionCandidate(
        key: 'k',
      ).toJson();
      expect(out, <String, dynamic>{'key': 'k'});
      expect(out.containsKey('order'), isFalse);
      expect(out.containsKey('label'), isFalse);
    });

    test('AD-10 — corrompu / absent / mauvais type : repli SANS lever', () {
      // Racine illisible ⇒ null, pas d'exception.
      expect(ZChatMentionCandidate.fromJson(null), isNull);
      expect(ZChatMentionCandidate.fromJson('pas une map'), isNull);
      expect(ZChatMentionCandidate.fromJson(<Object?>[1, 2]), isNull);
      // Clé absente ou du mauvais type ⇒ candidat ÉCARTÉ (pas d'identité).
      expect(ZChatMentionCandidate.fromJson(<String, dynamic>{}), isNull);
      expect(
        ZChatMentionCandidate.fromJson(<String, dynamic>{'key': 42}),
        isNull,
      );
      // Champs annexes du mauvais type ⇒ repli documenté, candidat CONSERVÉ.
      final ZChatMentionCandidate c = ZChatMentionCandidate.fromJson(
        <String, dynamic>{
          'key': 'k',
          'label': <String>['pas une chaine'],
          'order': 'pas un entier',
          'extra': 'pas une map',
          'extension': 'pas une extension',
        },
      )!;
      expect(c.key, 'k');
      expect(c.label, isNull, reason: 'repli documenté : absent');
      expect(c.order, 0, reason: 'repli documenté : 0');
      expect(c.extra, isEmpty);
      expect(c.extension, isNull);
    });

    test('AD-19.1 — `extra` filtré : ni clé de sync, ni clé propre', () {
      final ZChatMentionCandidate c = ZChatMentionCandidate.fromJson(
        <String, dynamic>{'key': 'k', 'extra': _polluted},
      )!;
      expect(c.extra, <String, dynamic>{'host': 'kept', 'character': 'smuggled'},
          reason: '`character` n\'est PAS une clé propre du candidat');
      expect(c.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(c.extra.containsKey(ZSyncMeta.kIsDeleted), isFalse);
      expect(c.extra.containsKey('key'), isFalse);
      final Map<String, dynamic> out = c.toJson();
      expect(out['key'], 'k');
      expect(
        (out['extra']! as Map<String, dynamic>)
            .containsKey(ZSyncMeta.kUpdatedAt),
        isFalse,
        reason: 'le merge Last-Write-Wins (AD-9) ne doit pas être faussé',
      );
      // Voie constructeur : MÊME garde (la pollution n'entre pas non plus).
      expect(
        ZChatMentionCandidate(key: 'x', extra: _polluted)
            .extra
            .containsKey(ZSyncMeta.kIsDeleted),
        isFalse,
      );
      // 🔴 Le filtrage est EAGER (`zSanitizeExtra` au constructeur) : le slot
      // stocké est DÉJÀ propre, donc l'accesseur le rend SANS COPIE. Retirer
      // `zSanitizeExtra` en ne gardant que la normalisation de lecture ferait
      // recopier à chaque lecture — et rougir ICI (et là seulement).
      expect(identical(c.extra, c.extra), isTrue,
          reason: 'slot déjà assaini ⇒ lecture sans copie');
    });
  });

  group('ZChatMentionTrigger — déclaration et reconnaissance', () {
    test('aller-retour FIDÈLE et défauts omis', () {
      final ZChatMentionTrigger t = ZChatMentionTrigger(
        character: '@',
        sourceKey: 'files',
        minQueryLength: 2,
        maxCandidates: 8,
        allowsWhitespace: true,
        requiresLeadingBoundary: false,
        extra: <String, dynamic>{'host': true},
      );
      final ZChatMentionTrigger back =
          ZChatMentionTrigger.fromJson(t.toJson())!;
      expect(back.character, '@');
      expect(back.sourceKey, 'files');
      expect(back.minQueryLength, 2);
      expect(back.maxCandidates, 8);
      expect(back.allowsWhitespace, isTrue);
      expect(back.requiresLeadingBoundary, isFalse);
      expect(back.extra, <String, dynamic>{'host': true});
      expect(
        ZChatMentionTrigger(character: '/').toJson(),
        <String, dynamic>{'character': '/'},
      );
    });

    test('AD-10 — amorce absente / blanche / du mauvais type ⇒ écartée', () {
      expect(ZChatMentionTrigger.fromJson(null), isNull);
      expect(ZChatMentionTrigger.fromJson(<String, dynamic>{}), isNull);
      expect(
        ZChatMentionTrigger.fromJson(<String, dynamic>{'character': '   '}),
        isNull,
      );
      expect(
        ZChatMentionTrigger.fromJson(<String, dynamic>{'character': 42}),
        isNull,
        reason: 'le socle ne retombe sur AUCUNE amorce inventée (FR-26)',
      );
      final ZChatMentionTrigger t = ZChatMentionTrigger.fromJson(
        <String, dynamic>{
          'character': '@',
          'min_query_length': 'pas un entier',
          'max_candidates': 'pas un entier',
          'allows_whitespace': 'pas un booleen',
          'requires_leading_boundary': 'pas un booleen',
        },
      )!;
      expect(t.minQueryLength, 0);
      expect(t.maxCandidates, isNull);
      expect(t.allowsWhitespace, isFalse);
      expect(t.requiresLeadingBoundary, isTrue, reason: 'repli le plus strict');
    });

    test('une longueur minimale NÉGATIVE est ramenée à 0, sans lever', () {
      expect(ZChatMentionTrigger(character: '@', minQueryLength: -5)
          .minQueryLength, 0);
    });

    test('un déclencheur non déclaré ne reconnaît RIEN et ne lève pas', () {
      final ZChatMentionTrigger vide = ZChatMentionTrigger(character: '  ');
      expect(vide.isDeclared, isFalse);
      expect(vide.matchIn('@bob', 4), isNull);
    });

    test('reconnaissance : amorce en début de mot, requête jusqu\'au curseur',
        () {
      final ZChatMentionTrigger t =
          ZChatMentionTrigger(character: '@', sourceKey: 'people');
      final ZChatMentionMatch m = t.matchIn('bonjour @bo', 11)!;
      expect(m.query, 'bo');
      expect(m.start, 8);
      expect(m.end, 11);
      expect(identical(m.trigger, t), isTrue);
      // Une amorce en tout début de texte est reconnue.
      expect(t.matchIn('@a', 2)!.query, 'a');
      // Une amorce nue, requête vide : reconnue, mais pas encore « prête ».
      final ZChatMentionMatch nu = t.matchIn('@', 1)!;
      expect(nu.query, isEmpty);
      expect(nu.isReady, isTrue, reason: 'minQueryLength vaut 0 par défaut');
    });

    test('la FRONTIÈRE DE MOT est exigée : un courriel n\'ouvre pas de panneau',
        () {
      final ZChatMentionTrigger t = ZChatMentionTrigger(character: '@');
      expect(t.matchIn('zak@exemple', 11), isNull);
      // Désactivée explicitement par l'hôte ⇒ reconnue.
      final ZChatMentionTrigger libre =
          ZChatMentionTrigger(character: '@', requiresLeadingBoundary: false);
      expect(libre.matchIn('zak@exemple', 11)!.query, 'exemple');
    });

    test('un blanc ferme la requête, sauf si l\'hôte l\'autorise', () {
      final ZChatMentionTrigger t = ZChatMentionTrigger(character: '@');
      expect(t.matchIn('@bob ', 5), isNull);
      expect(t.matchIn('@bob dit', 8), isNull);
      final ZChatMentionTrigger cmd =
          ZChatMentionTrigger(character: '/', allowsWhitespace: true);
      expect(cmd.matchIn('/resume ce texte', 16)!.query, 'resume ce texte');
    });

    test('un curseur HORS BORNES ⇒ null, jamais de RangeError', () {
      final ZChatMentionTrigger t = ZChatMentionTrigger(character: '@');
      expect(t.matchIn('@ab', -1), isNull);
      expect(t.matchIn('@ab', 99), isNull);
      expect(t.matchIn('', 0), isNull);
    });

    test('`isReady` compare la LONGUEUR, il n\'ordonne aucun affichage', () {
      final ZChatMentionTrigger t =
          ZChatMentionTrigger(character: '@', minQueryLength: 2);
      expect(t.matchIn('@a', 2)!.isReady, isFalse);
      expect(t.matchIn('@ab', 3)!.isReady, isTrue);
    });

    test('AD-19.1 — `extra` filtré sur le déclencheur aussi', () {
      final ZChatMentionTrigger t = ZChatMentionTrigger(
        character: '@',
        extra: _polluted,
      );
      expect(t.extra, <String, dynamic>{'host': 'kept', 'key': 'smuggled'},
          reason: '`key` n\'est PAS une clé propre du déclencheur');
      expect(t.extra.containsKey('character'), isFalse);
      expect(t.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect((t.toJson()['extra']! as Map<String, dynamic>)
          .containsKey(ZSyncMeta.kIsDeleted), isFalse);
      // Filtrage EAGER au constructeur ⇒ lecture sans copie (cf. candidat).
      expect(identical(t.extra, t.extra), isTrue,
          reason: 'slot déjà assaini ⇒ lecture sans copie');
    });
  });

  group('ZChatMentionSource — le socle ne résout rien, et reste inerte', () {
    test('la source inerte rend une liste VIDE, sans lever', () async {
      final ZChatMentionTrigger t = ZChatMentionTrigger(character: '@');
      final ZChatMentionMatch m = t.matchIn('@a', 2)!;
      final ZResult<List<ZChatMentionCandidate>> r =
          await const ZChatEmptyMentionSource().candidates(m);
      expect(r.isRight(), isTrue, reason: 'vide n\'est PAS une panne');
      expect(
        r.getOrElse(() => <ZChatMentionCandidate>[ZChatMentionCandidate(key: 'panne')]),
        isEmpty,
        reason: 'le repli marqueur prouverait un Left',
      );
    });

    test('une clé de source INCONNUE rend l\'inerte, jamais une exception',
        () async {
      final ZChatMentionSources sources = ZChatMentionSources();
      expect(sources.keys, isEmpty);
      expect(sources.sourceFor('absente'), isA<ZChatEmptyMentionSource>());
      expect(sources.sourceFor(null), isA<ZChatEmptyMentionSource>());
      expect(
        sources.sourceForTrigger(ZChatMentionTrigger(character: '@')),
        isA<ZChatEmptyMentionSource>(),
      );
    });

    test('une source déclarée est RENDUE TELLE QUELLE — aucun filtrage, '
        'aucun tri, aucune troncature par le socle', () async {
      final ZChatMentionSources sources = ZChatMentionSources(
        <String, ZChatMentionSource>{'people': _FixedSource()},
      );
      final ZChatMentionTrigger t = ZChatMentionTrigger(
        character: '@',
        sourceKey: 'people',
        maxCandidates: 1,
      );
      final ZChatMentionSource s = sources.sourceForTrigger(t);
      final List<ZChatMentionCandidate> got =
          (await s.candidates(t.matchIn('@z', 2)!))
              .getOrElse(() => <ZChatMentionCandidate>[]);
      expect(got.map((ZChatMentionCandidate c) => c.key), <String>['b', 'a'],
          reason: 'ordre de la source PRÉSERVÉ malgré `order` et '
              '`maxCandidates` : le socle ne classe ni ne tronque');
    });
  });
}

class _FixedSource implements ZChatMentionSource {
  @override
  Future<ZResult<List<ZChatMentionCandidate>>> candidates(
    ZChatMentionMatch match,
  ) async =>
      Right<ZFailure, List<ZChatMentionCandidate>>(<ZChatMentionCandidate>[
        ZChatMentionCandidate(key: 'b', order: 9),
        ZChatMentionCandidate(key: 'a', order: 1),
      ]);
}
