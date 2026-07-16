// Story ES-9.4 — AC4/AC7 : surface AD-5 des ports, PINCÉE par liaison de type
// STATIQUE. Un fake implémente les ports ; les retours sont affectés à des
// variables typées explicitement. R3-SURFACE : changer `revokeShareLink` en
// `ZResult<ZShareLink>` (non-`Unit`) casse la COMPILATION de ce fichier ⇒ RED.
// Runner R14.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Fake minimal : la seule existence de ces `@override` prouve la surface AD-5
/// (retours `ZResult<T>` / `ZResult<Unit>` / `Stream<List<T>>` nu).
class _FakeSharingPort implements ZStudySharingPort {
  @override
  Future<ZResult<ZShareLink>> createShareLink(String folderId) async =>
      Right<ZFailure, ZShareLink>(ZShareLink(folderId: folderId));

  @override
  Future<ZResult<Unit>> revokeShareLink(String linkId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<ZStudyMembership>> grantMembership(
    ZStudyMembership membership,
  ) async =>
      Right<ZFailure, ZStudyMembership>(membership);

  @override
  Stream<List<ZStudyMembership>> watchMemberships(String folderId) =>
      Stream<List<ZStudyMembership>>.value(const <ZStudyMembership>[]);

  @override
  Future<ZResult<ZPublicStudyFolder>> publishToGallery(String folderId) async =>
      Right<ZFailure, ZPublicStudyFolder>(ZPublicStudyFolder(folderId: folderId));

  @override
  Future<ZResult<Unit>> unpublish(String folderId) async =>
      const Right<ZFailure, Unit>(unit);
}

class _FakeModerationPort implements ZStudyModerationPort {
  @override
  Future<ZResult<Unit>> report(ZStudyFolderReport report) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Stream<List<ZStudyFolderReport>> watchReports(String folderId) =>
      Stream<List<ZStudyFolderReport>>.value(const <ZStudyFolderReport>[]);

  @override
  Future<ZResult<Unit>> resolveReport(String reportId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> takedown(String folderId) async =>
      const Right<ZFailure, Unit>(unit);
}

void main() {
  test('ZStudySharingPort — surface AD-5 (retours typés statiquement)', () async {
    final ZStudySharingPort port = _FakeSharingPort();

    // Mutations ⇒ Future<ZResult<T>> (jamais un T nu).
    final ZResult<ZShareLink> created = await port.createShareLink('f');
    expect(created.isRight(), isTrue);

    // Révocation ⇒ ZResult<Unit> (AC4 : jamais un ZShareLink nu ni Stream).
    final ZResult<Unit> revoked = await port.revokeShareLink('l');
    expect(revoked, const Right<ZFailure, Unit>(unit));

    final ZResult<ZStudyMembership> granted =
        await port.grantMembership(const ZStudyMembership());
    expect(granted.isRight(), isTrue);

    final ZResult<ZPublicStudyFolder> published =
        await port.publishToGallery('f');
    expect(published.isRight(), isTrue);

    final ZResult<Unit> unpublished = await port.unpublish('f');
    expect(unpublished.isRight(), isTrue);

    // Flux ⇒ Stream<List<T>> NU (jamais enveloppé dans ZResult).
    final Stream<List<ZStudyMembership>> stream = port.watchMemberships('f');
    expect(await stream.first, isEmpty);
  });

  test('ZStudyModerationPort — surface AD-5', () async {
    final ZStudyModerationPort port = _FakeModerationPort();

    final ZResult<Unit> reported =
        await port.report(const ZStudyFolderReport());
    expect(reported, const Right<ZFailure, Unit>(unit));

    final ZResult<Unit> resolved = await port.resolveReport('r');
    expect(resolved.isRight(), isTrue);

    final ZResult<Unit> taken = await port.takedown('f');
    expect(taken.isRight(), isTrue);

    final Stream<List<ZStudyFolderReport>> stream = port.watchReports('f');
    expect(await stream.first, isEmpty);
  });
}
