// Story ES-9.4 — AC2 : le partage est OPTIONNEL (AD-26). Une app qui n'injecte
// PAS le parser de partage décode un dossier NORMALEMENT — `extension == null` —
// même si la map porte un bloc `extension` de partage (aucune activation
// implicite, AD-10). Complété par graph_proof (delta = 0, orchestrateur).
// Runner R14.
import 'package:zcrud_core/domain.dart';
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

  test('AC2 — fromMap SANS parser ⇒ partage NON activé, payload PRÉSERVÉ', () {
    // ⚠️ CHANGEMENT DE CONTRAT (CR-LEX-33, v0.11.0) : ce test assertait
    // `extension == null`. Ne pas savoir TYPER un payload n'autorise pas à
    // l'EFFACER — `extension` étant une clé connue (exclue d'`extra`), le
    // `null` valait DESTRUCTION silencieuse du slot d'un autre hôte.
    //
    // L'invariant AD-26 que ce test protège est INTACT : le partage n'est pas
    // activé sans parser (le slot n'est pas typé). Seule la préservation du
    // payload brut change.
    final folder = ZStudyFolder.fromMap(folderMap);
    expect(folder.extension, isA<ZOpaqueExtension>(),
        reason: 'le payload est préservé verbatim, faute de savoir le typer');
    expect(folder.extension, isNot(isA<ZStudySharingExtension>()),
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
