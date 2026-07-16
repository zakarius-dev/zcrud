// Story ES-9.4 — AC3 : l'état PERSONNEL n'est JAMAIS emporté par le partage.
//
// 🔴 LOAD-BEARING : intersection VIDE entre les clés sérialisées de TOUTE la
// surface de partage et l'ensemble des clés d'état personnel (SRS/ordre/lecture).
// R3-PERSONAL : ajouter un champ `repetition_info`/`ease_factor` (ou étaler un état
// personnel) dans une entité de partage rend l'intersection NON vide ⇒ RED.
// Runner R14.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  // Clés d'état PERSONNEL connues (SRS `zcrud_flashcard`, ordre kernel, lecture
  // `zcrud_document`). Le partage ne doit en sérialiser AUCUNE.
  const personalStateKeys = <String>{
    'repetition',
    'repetition_info',
    'folder_contents_order',
    'reading_state',
    'learning_info',
    'ease_factor',
    'interval',
    'repetitions',
    'due_date',
    'next_review',
  };

  // Chaque porteur de partage, tous champs typés renseignés (les `extra` restent
  // vides : on teste la STRUCTURE de prod, pas un payload arbitraire).
  final sharingKeys = <String>{
    ...const ZStudyMembership(
      id: 'm',
      folderId: 'f',
      actorUid: 'u',
      role: ZMembershipRole.owner,
    ).toJson().keys,
    ...ZShareLink(
      id: 'l',
      token: 't',
      folderId: 'f',
      ownerUid: 'o',
      revoked: true,
      revokedAt: DateTime.utc(2026),
    ).toJson().keys,
    ...ZPublicStudyFolder(
      id: 'p',
      folderId: 'f',
      ownerUid: 'o',
      title: 'T',
      listedAt: DateTime.utc(2026),
    ).toJson().keys,
    ...ZStudyFolderReport(
      id: 'r',
      folderId: 'f',
      reporterUid: 'u',
      reason: 'x',
      status: ZReportStatus.open,
      createdAt: DateTime.utc(2026),
    ).toJson().keys,
    ...const ZStudySharingExtension(
      isPublic: true,
      joinableWithLink: true,
      coOwnersCanInvite: true,
      shareLinkId: 'l',
    ).toJson().keys,
  };

  test('AC3 — intersection VIDE partage ∩ état personnel', () {
    final intersection = sharingKeys.intersection(personalStateKeys);
    expect(intersection, isEmpty,
        reason: 'aucune clé d\'état personnel ne doit vivre dans le sous-arbre '
            'partageable — fuite: $intersection');
  });

  test('garde méta : les deux ensembles sont non vides (scan non vacue)', () {
    expect(sharingKeys, isNotEmpty);
    expect(personalStateKeys, isNotEmpty);
  });
}
