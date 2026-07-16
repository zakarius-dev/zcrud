// Story ES-9.4 — AC1/AC4 : construction, désérialisation défensive (AD-10),
// round-trip EXACT (R26) et égalité par valeur COMPLÈTE (leçon ES-9.3 MEDIUM-1 :
// varier CHAQUE champ individuellement) des entités de partage. Runner R14.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  group('ZStudyMembership', () {
    const seed = ZStudyMembership(
      id: 'm1',
      folderId: 'f1',
      actorUid: 'u1',
      role: ZMembershipRole.contributor,
      extra: <String, dynamic>{'note': 'x'},
    );

    test('round-trip toJson/fromJson EXACT (R26, non dégénéré)', () {
      final relu = ZStudyMembership.fromJson(seed.toJson());
      expect(relu, seed);
      expect(relu.role, ZMembershipRole.contributor);
      expect(relu.extra['note'], 'x');
    });

    test('fromJson défensif : non-map / corrompu / rôle inconnu ⇒ défauts', () {
      expect(ZStudyMembership.fromJson(null), const ZStudyMembership());
      expect(ZStudyMembership.fromJson(42), const ZStudyMembership());
      final r = ZStudyMembership.fromJson(<String, dynamic>{
        'folder_id': 123, // mauvais type ⇒ défaut ''
        'role': 'moderator', // inconnu ⇒ unknown
      });
      expect(r.folderId, '');
      expect(r.role, ZMembershipRole.unknown);
    });

    test('== varie chaque champ UN à la fois (MEDIUM-1)', () {
      expect(seed.copyWith(id: 'm2') == seed, isFalse);
      expect(seed.copyWith(folderId: 'f2') == seed, isFalse);
      expect(seed.copyWith(actorUid: 'u2') == seed, isFalse);
      expect(seed.copyWith(role: ZMembershipRole.owner) == seed, isFalse);
      expect(
        seed.copyWith(extra: <String, dynamic>{'note': 'y'}) == seed,
        isFalse,
      );
      // Identiques ⇒ égaux + même hashCode.
      expect(seed.copyWith(), seed);
      expect(seed.copyWith().hashCode, seed.hashCode);
    });
  });

  group('ZShareLink', () {
    final seed = ZShareLink(
      id: 'l1',
      token: 't1',
      folderId: 'f1',
      ownerUid: 'o1',
      revoked: true,
      revokedAt: DateTime.utc(2026, 1, 2),
      extra: const <String, dynamic>{'k': 1},
    );

    test('révocation SURVIT au round-trip (AC4)', () {
      final relu = ZShareLink.fromJson(seed.toJson());
      expect(relu.revoked, isTrue);
      expect(relu.revokedAt, DateTime.utc(2026, 1, 2));
      expect(relu, seed);
    });

    test('revoke() est monotone (helper)', () {
      const active = ZShareLink(id: 'l', ownerUid: 'o');
      final revoked = active.revoke(at: DateTime.utc(2026));
      expect(revoked.revoked, isTrue);
      expect(revoked.revokedAt, DateTime.utc(2026));
    });

    test('fromJson défensif : revoked non-bool ⇒ false', () {
      final r = ZShareLink.fromJson(<String, dynamic>{'revoked': 'yes'});
      expect(r.revoked, isFalse);
    });

    test('== varie chaque champ UN à la fois (MEDIUM-1)', () {
      expect(seed.copyWith(id: 'l2') == seed, isFalse);
      expect(seed.copyWith(token: 't2') == seed, isFalse);
      expect(seed.copyWith(folderId: 'f2') == seed, isFalse);
      expect(seed.copyWith(ownerUid: 'o2') == seed, isFalse);
      expect(seed.copyWith(revoked: false) == seed, isFalse);
      expect(
        seed.copyWith(revokedAt: DateTime.utc(2027)) == seed,
        isFalse,
      );
      expect(
        seed.copyWith(extra: const <String, dynamic>{'k': 2}) == seed,
        isFalse,
      );
      expect(seed.copyWith(), seed);
      expect(seed.copyWith().hashCode, seed.hashCode);
    });
  });

  group('ZPublicStudyFolder', () {
    final seed = ZPublicStudyFolder(
      id: 'p1',
      folderId: 'f1',
      ownerUid: 'o1',
      title: 'T',
      listedAt: DateTime.utc(2026, 3, 4),
      extra: const <String, dynamic>{'k': 1},
    );

    test('round-trip EXACT (R26)', () {
      expect(ZPublicStudyFolder.fromJson(seed.toJson()), seed);
    });

    test('fromJson défensif : non-map ⇒ défaut', () {
      expect(ZPublicStudyFolder.fromJson('x'), const ZPublicStudyFolder());
    });

    test('== varie chaque champ UN à la fois (MEDIUM-1)', () {
      expect(seed.copyWith(id: 'p2') == seed, isFalse);
      expect(seed.copyWith(folderId: 'f2') == seed, isFalse);
      expect(seed.copyWith(ownerUid: 'o2') == seed, isFalse);
      expect(seed.copyWith(title: 'U') == seed, isFalse);
      expect(seed.copyWith(listedAt: DateTime.utc(2027)) == seed, isFalse);
      expect(
        seed.copyWith(extra: const <String, dynamic>{'k': 2}) == seed,
        isFalse,
      );
      expect(seed.copyWith(), seed);
      expect(seed.copyWith().hashCode, seed.hashCode);
    });
  });

  group('ZStudyFolderReport', () {
    final seed = ZStudyFolderReport(
      id: 'r1',
      folderId: 'f1',
      reporterUid: 'u1',
      reason: 'spam',
      status: ZReportStatus.reviewing,
      createdAt: DateTime.utc(2026, 5, 6),
      extra: const <String, dynamic>{'k': 1},
    );

    test('round-trip EXACT (R26)', () {
      final relu = ZStudyFolderReport.fromJson(seed.toJson());
      expect(relu, seed);
      expect(relu.status, ZReportStatus.reviewing);
    });

    test('fromJson défensif : statut inconnu ⇒ unknown', () {
      final r = ZStudyFolderReport.fromJson(<String, dynamic>{'status': 'weird'});
      expect(r.status, ZReportStatus.unknown);
    });

    test('== varie chaque champ UN à la fois (MEDIUM-1)', () {
      expect(seed.copyWith(id: 'r2') == seed, isFalse);
      expect(seed.copyWith(folderId: 'f2') == seed, isFalse);
      expect(seed.copyWith(reporterUid: 'u2') == seed, isFalse);
      expect(seed.copyWith(reason: 'abuse') == seed, isFalse);
      expect(seed.copyWith(status: ZReportStatus.resolved) == seed, isFalse);
      expect(seed.copyWith(createdAt: DateTime.utc(2027)) == seed, isFalse);
      expect(
        seed.copyWith(extra: const <String, dynamic>{'k': 2}) == seed,
        isFalse,
      );
      expect(seed.copyWith(), seed);
      expect(seed.copyWith().hashCode, seed.hashCode);
    });
  });

  group('ZStudySharingExtension', () {
    const seed = ZStudySharingExtension(
      isPublic: true,
      joinableWithLink: true,
      coOwnersCanInvite: true,
      shareLinkId: 'l1',
    );

    test('round-trip toJson/fromJsonSafe EXACT (R26)', () {
      final relu = ZStudySharingExtension.fromJsonSafe(seed.toJson());
      expect(relu, seed);
      expect(relu!.formatVersion, kZStudySharingFormatVersion);
    });

    test('fromJsonSafe défensif : null / corrompu / version non gérée ⇒ null', () {
      expect(ZStudySharingExtension.fromJsonSafe(null), isNull);
      expect(ZStudySharingExtension.fromJsonSafe(42), isNull);
      expect(
        ZStudySharingExtension.fromJsonSafe(
          <String, dynamic>{'format_version': 99},
        ),
        isNull,
      );
      // Version absente ⇒ null (jamais de throw).
      expect(
        ZStudySharingExtension.fromJsonSafe(<String, dynamic>{'is_public': true}),
        isNull,
      );
    });

    test('== varie chaque champ UN à la fois (MEDIUM-1)', () {
      expect(seed.copyWith(isPublic: false) == seed, isFalse);
      expect(seed.copyWith(joinableWithLink: false) == seed, isFalse);
      expect(seed.copyWith(coOwnersCanInvite: false) == seed, isFalse);
      expect(seed.copyWith(shareLinkId: 'l2') == seed, isFalse);
      expect(seed.copyWith(), seed);
      expect(seed.copyWith().hashCode, seed.hashCode);
    });
  });
}
