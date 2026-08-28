// Vocabulaire d'actions OUVERT (ZActionKey / ZKeyedAcl / canAction).
//
// Garde la plus importante du lot : le FAIL-CLOSED. Une clé libre présentée à
// une ACL qui ne la connaît pas (une ACL écrite avant l'ouverture du
// vocabulaire, qui n'implémente que ZAcl) doit être REFUSÉE — jamais accordée
// au motif qu'elle n'était pas dans l'enum. Décision d'owner : le socle est
// fail-closed sur les ACL.
//
// Les clés libres utilisées ici sont des clés de TEST inventées : le socle ne
// connaît AUCUNE clé applicative (aucune clé d'hôte en dur — FR-26).
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Entité fictive pour vérifier le transport de `target`.
class _FakeEntity implements ZEntity {
  const _FakeEntity(this.id);
  @override
  final String? id;
  @override
  bool get isEphemeral => id == null;
}

/// ACL « d'avant l'ouverture » : n'implémente QUE ZAcl, et accorde TOUT ce
/// qu'on lui présente via `can`. Si le fail-closed était violé (repli
/// permissif dans `canAction`), c'est exactement elle qui accorderait une clé
/// libre — le test rougirait par la voie la plus courte.
class _LegacyAllowAllAcl implements ZAcl {
  const _LegacyAllowAllAcl();
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      true;
}

/// ACL fermée espionne : enregistre chaque ZCrudAction reçu par `can`, pour
/// prouver qu'une clé LIBRE n'atteint JAMAIS `can` (aucune coercition vers un
/// verbe canonique) et qu'une clé CANONIQUE y arrive à l'identique.
class _SpyAcl implements ZAcl {
  final List<ZCrudAction> received = [];
  final List<ZEntity?> targets = [];
  final List<String?> collectionIds = [];
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
    received.add(action);
    targets.add(target);
    collectionIds.add(collectionId);
    return action != ZCrudAction.delete;
  }
}

/// ACL OUVERTE espionne : enregistre la clé libre reçue TELLE QUELLE (garde
/// de transport : aucune altération, aucune interprétation entre la
/// déclaration et le point de décision).
class _SpyKeyedAcl implements ZKeyedAcl {
  _SpyKeyedAcl({required this.grants});
  final Set<String> grants;
  final List<String> receivedKeys = [];
  final List<ZEntity?> targets = [];
  final List<String?> collectionIds = [];
  final List<ZCrudAction> receivedCanonical = [];
  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
    receivedCanonical.add(action);
    return true;
  }

  @override
  bool canKey(String actionKey, {ZEntity? target, String? collectionId}) {
    receivedKeys.add(actionKey);
    targets.add(target);
    collectionIds.add(collectionId);
    return grants.contains(actionKey);
  }
}

void main() {
  group('🔴 FAIL-CLOSED — clé libre refusée par une ACL qui ne la connaît pas',
      () {
    const libre = ZActionKey('gesteInconnuDuSocle');

    test('une ACL fermée PERMISSIVE (legacy, implements ZAcl seul) REFUSE '
        'une clé libre — le refus vient du routage, pas de l\'ACL', () {
      const acl = _LegacyAllowAllAcl();
      // Témoin vert : la même ACL accorde tout verbe canonique…
      expect(acl.canAction(ZActionKey.delete), isTrue);
      // …et pourtant la clé libre est REFUSÉE : fail-closed du socle.
      expect(acl.canAction(libre), isFalse,
          reason: 'une action inconnue ne doit JAMAIS être accordée parce '
              'qu\'elle n\'était pas dans l\'enum');
    });

    test('une clé libre n\'atteint JAMAIS can() d\'une ACL fermée '
        '(pas de coercition silencieuse vers un verbe canonique)', () {
      final spy = _SpyAcl();
      expect(spy.canAction(libre), isFalse);
      expect(spy.received, isEmpty,
          reason: 'refus AVANT l\'ACL : aucune valeur canonique fabriquée');
    });

    test('ZDenyAllAcl refuse aussi les clés libres', () {
      expect(const ZDenyAllAcl().canAction(libre), isFalse);
      expect(const ZDenyAllAcl().canKey(libre.key), isFalse);
    });

    test('ZRestrictedAcl : un côté FERMÉ au vocabulaire ouvert suffit à '
        'refuser la clé libre (intersection inélargissable)', () {
      final ouverte = _SpyKeyedAcl(grants: {libre.key});
      // Témoin vert : ouverte seule accorde la clé.
      expect(ouverte.canAction(libre), isTrue);
      // Restreinte par une ACL fermée (même permissive) → refus.
      final restreinte = zRestrictAcl(ouverte, const _LegacyAllowAllAcl());
      expect(restreinte.canAction(libre), isFalse);
      // Et dans l'autre sens (base fermée, restriction ouverte) → refus aussi.
      final inverse = zRestrictAcl(const _LegacyAllowAllAcl(), ouverte);
      expect(inverse.canAction(libre), isFalse);
    });

    test('une ACL OUVERTE reste maîtresse de son refus : clé libre hors de '
        'sa matrice → false', () {
      final acl = _SpyKeyedAcl(grants: {'gesteAccorde'});
      expect(acl.canAction(const ZActionKey('gesteAccorde')), isTrue);
      expect(acl.canAction(const ZActionKey('gesteNonDeclare')), isFalse);
    });
  });

  group('Compatibilité — clé canonique décidée par can(enum), à l\'identique',
      () {
    test('chaque valeur de ZCrudAction a sa clé canonique, et canAction '
        'délègue à can() avec la MÊME valeur, target et collectionId compris',
        () {
      const target = _FakeEntity('e1');
      for (final action in ZCrudAction.values) {
        final spy = _SpyAcl();
        final ZActionKey key = ZActionKey.of(action);
        expect(key.asCrudAction, action,
            reason: 'aller-retour enum → clé → enum sans perte');
        final bool decided =
            spy.canAction(key, target: target, collectionId: 'c1');
        expect(spy.received, [action],
            reason: 'la décision doit passer par can($action), une fois');
        expect(spy.targets, [target]);
        expect(spy.collectionIds, ['c1']);
        // Même verdict que l'appel direct (ici : refus de delete seul).
        expect(decided, spy.can(action));
      }
    });

    test('une ACL OUVERTE reçoit aussi ses verbes canoniques par can(), '
        'jamais par canKey() — un seul point de décision par action', () {
      final acl = _SpyKeyedAcl(grants: const {});
      expect(acl.canAction(ZActionKey.update), isTrue);
      expect(acl.receivedCanonical, [ZCrudAction.update]);
      expect(acl.receivedKeys, isEmpty);
    });
  });

  group('Transport — clé libre véhiculée sans altération ni interprétation',
      () {
    test('la clé arrive à canKey OCTET POUR OCTET, avec target et '
        'collectionId intacts', () {
      const target = _FakeEntity('e2');
      // Clé volontairement « étrange » : casse mixte, point, tiret — le socle
      // n'a pas à la normaliser, la juger ni la réécrire.
      const cle = 'Domaine.geste-Special_09';
      final acl = _SpyKeyedAcl(grants: const {cle});
      final ok = acl.canAction(const ZActionKey(cle),
          target: target, collectionId: 'c9');
      expect(ok, isTrue,
          reason: 'la clé accordée par la matrice doit revenir accordée : '
              'toute altération en chemin ferait échouer la correspondance');
      expect(acl.receivedKeys, [cle]);
      expect(acl.targets, [target]);
      expect(acl.collectionIds, ['c9']);
    });

    test('ZRestrictedAcl transporte la même clé aux DEUX côtés', () {
      const cle = 'gesteCompose';
      final base = _SpyKeyedAcl(grants: const {cle});
      final restriction = _SpyKeyedAcl(grants: const {cle});
      final acl = ZRestrictedAcl(base, restriction);
      expect(acl.canAction(const ZActionKey(cle)), isTrue);
      expect(base.receivedKeys, [cle]);
      expect(restriction.receivedKeys, [cle]);
    });

    test('égalité de valeur : deux ZActionKey de même chaîne se valent '
        '(utilisables en Set/Map de matrice)', () {
      expect(const ZActionKey('a'), const ZActionKey('a'));
      expect(const ZActionKey('a').hashCode, const ZActionKey('a').hashCode);
      expect(const ZActionKey('a'), isNot(const ZActionKey('b')));
      expect({ZActionKey.view, ZActionKey.of(ZCrudAction.view)}, hasLength(1));
    });

    test('asCrudAction est défensif : clé libre → null, jamais d\'exception '
        '(AD-10)', () {
      expect(const ZActionKey('inconnue').asCrudAction, isNull);
      expect(const ZActionKey('').asCrudAction, isNull);
      expect(const ZActionKey('View').asCrudAction, isNull,
          reason: 'la correspondance canonique est stricte (camelCase exact), '
              'pas une normalisation');
    });
  });
}
