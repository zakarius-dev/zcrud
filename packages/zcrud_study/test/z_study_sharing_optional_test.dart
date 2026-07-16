// Story ES-9.4 — AC2 : le partage est OPTIONNEL (AD-26). Une app qui n'injecte
// PAS le parser de partage décode un dossier NORMALEMENT — `extension == null` —
// même si la map porte un bloc `extension` de partage (aucune activation
// implicite, AD-10). Complété par graph_proof (delta = 0, orchestrateur).
// Runner R14.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  // Map d'un dossier portant un bloc `extension` de partage typé.
  final folderMap = <String, dynamic>{
    'id': 'f1',
    'title': 'Mon dossier',
    'color_key': 'blue',
    'owner_id': 'o1',
    'extension': const ZStudySharingExtension(isPublic: true).toJson(),
  };

  test('AC2 — fromMap SANS parser ⇒ extension == null, dossier survit', () {
    // Aucune app-activation : pas d'extensionParser.
    final folder = ZStudyFolder.fromMap(folderMap);
    expect(folder.extension, isNull,
        reason: 'sans parser injecté, le partage n\'est PAS activé (AD-26)');
    // Le reste du dossier est décodé normalement.
    expect(folder.id, 'f1');
    expect(folder.title, 'Mon dossier');
    expect(folder.colorKey, 'blue');
    expect(folder.ownerId, 'o1');
  });

  test('AC2 — AVEC parser injecté ⇒ extension typée (opt-in)', () {
    final folder = ZStudyFolder.fromMap(
      folderMap,
      extensionParser: ZStudySharingExtension.fromJsonSafe,
    );
    expect(folder.extension, isA<ZStudySharingExtension>());
    expect((folder.extension! as ZStudySharingExtension).isPublic, isTrue);
    // Le dossier reste par ailleurs intact.
    expect(folder.title, 'Mon dossier');
  });

  test('AC2 — pas de nouvelle dépendance backend (documentaire)', () {
    // La surface de partage n'importe QUE zcrud_core + zcrud_study_kernel (déjà
    // déclarés) : aucun SDK/backend tiré. Le graphe (delta = 0, 44 arêtes) le
    // prouve côté orchestrateur ; ce test épingle l'intention côté package.
    expect(const ZStudySharingExtension().formatVersion,
        kZStudySharingFormatVersion);
  });
}
