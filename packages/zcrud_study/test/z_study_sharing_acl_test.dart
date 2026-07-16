// Story ES-9.4 — AC5 CŒUR : garde ACL de sécurité (dette lex CORRIGÉE).
//
// 🔴🔴 LOAD-BEARING : ce test EXERCE `ZStudySharingAcl`. Injections R3 attendues :
//   - `canMutateControl(...) => true;`  ⇒ un contributeur passerait la garde ⇒ RED
//   - `isControlField(...) => false;`   ⇒ les clés de contrôle ne seraient plus
//                                          reconnues ⇒ RED
// Si la neutralisation laisse le test VERT, la garde est un vœu (interdit).
// Runner R14.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  group('isControlField — reconnaissance des champs de contrôle (AC5)', () {
    // Un champ par facette : propriété, révocation, listing, invitation, rôle.
    const controlKeys = <String>[
      'owner_uid',
      'owner_id',
      'revoked',
      'revoked_at',
      'is_public',
      'listed_at',
      'co_owners_can_invite',
      'co_workers_can_invite_others',
      'can_be_joined_with_link',
      'joinable_with_link',
      'share_id',
      'share_link_id',
      'shared_with',
      'role',
    ];

    for (final key in controlKeys) {
      test('"$key" EST un champ de contrôle', () {
        expect(ZStudySharingAcl.isControlField(key), isTrue,
            reason: '$key doit être reconnu comme champ de contrôle owner-only');
      });
    }

    test('un champ NON-contrôle (contenu partageable) ⇒ false', () {
      expect(ZStudySharingAcl.isControlField('title'), isFalse);
      expect(ZStudySharingAcl.isControlField('reason'), isFalse);
      expect(ZStudySharingAcl.isControlField('folder_id'), isFalse);
    });
  });

  group('canMutateControl — autorisation owner-only (AC5, CŒUR)', () {
    const owner = 'owner-uid';

    test('🔴 un CONTRIBUTEUR (non-owner) NE PEUT PAS muter (dette lex fermée)',
        () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: 'contrib-uid',
          ownerUid: owner,
          role: ZMembershipRole.contributor,
        ),
        isFalse,
        reason: 'un contributeur ne doit JAMAIS muter un champ de contrôle',
      );
    });

    test('un VIEWER ne peut pas muter', () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: 'v', ownerUid: owner, role: ZMembershipRole.viewer),
        isFalse,
      );
    });

    test('un rôle INCONNU ne peut pas muter (repli sûr AD-10)', () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: 'x', ownerUid: owner, role: ZMembershipRole.unknown),
        isFalse,
      );
    });

    test('un OWNER (par rôle) peut muter', () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: 'anyone', ownerUid: owner, role: ZMembershipRole.owner),
        isTrue,
      );
    });

    test('un OWNER (par identité actorUid == ownerUid) peut muter', () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: owner, ownerUid: owner, role: ZMembershipRole.contributor),
        isTrue,
      );
    });

    test('actorUid vide ne devient pas owner par identité (ownerUid vide)', () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: '', ownerUid: '', role: ZMembershipRole.contributor),
        isFalse,
      );
    });
  });

  group('Révocation MONOTONE — R3-REVOKE (AC5 pt.3)', () {
    test('🔴 un contributeur NE PEUT PAS dé-révoquer un lien', () {
      // `revoked` est un champ de contrôle…
      expect(ZStudySharingAcl.isControlField('revoked'), isTrue);
      // …donc un contributeur ne peut pas le muter (le remettre à false).
      final canDeRevoke = ZStudySharingAcl.canMutateControl(
        actorUid: 'contrib',
        ownerUid: 'owner-uid',
        role: ZMembershipRole.contributor,
      );
      expect(canDeRevoke, isFalse,
          reason: 'la dé-révocation par un non-owner doit être rejetée '
              '(révocation monotone, dette LWW lex fermée)');
    });

    test('un owner peut, lui, changer l\'état de révocation', () {
      expect(
        ZStudySharingAcl.canMutateControl(
          actorUid: 'owner-uid',
          ownerUid: 'owner-uid',
          role: ZMembershipRole.owner,
        ),
        isTrue,
      );
    });
  });
}
