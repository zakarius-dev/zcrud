/// Ports de la structure d'étude — accès, import, résolution de mandant.
///
/// **Aucun contrat de dépôt n'est redéfini ici.** `ZReadOnlyRepository<T>` et
/// `ZRepository<T>` existent déjà dans le socle, avec leurs flux nus, leur
/// `Either<ZFailure, T>`, leur pagination à curseur et leur corbeille. Un port
/// de structure n'est donc **qu'une composition** : il dit quels dépôts un hôte
/// expose, pas comment on lit ou on écrit.
///
/// **Chaque accesseur peut rendre `null`, et c'est la valeur par défaut.**
/// `null` signifie « cet hôte ne sert pas cette entité » — un cas parfaitement
/// normal : une application personnelle n'a ni programmes ni audiences, une
/// application d'administration n'a peut-être pas de dossiers. L'absence est une
/// réponse valide ; un hôte n'implémente que ce qu'il porte, et n'écrit pas une
/// ligne pour le reste.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_classification.dart';
import 'z_study_competency.dart';
import 'z_study_competency_framework.dart';
import 'z_study_course.dart';
import 'z_study_curriculum.dart';
import 'z_study_group.dart';
import 'z_study_offering.dart';
import 'z_study_offering_audience.dart';
import 'z_study_org_unit.dart';
import 'z_study_organization.dart';
import 'z_study_participation.dart';
import 'z_study_period.dart';
import 'z_study_program.dart';
import 'z_study_program_course.dart';
import 'z_study_ref.dart';
import 'z_study_role_binding.dart';
import 'z_study_share_grant.dart';
import 'z_study_structure_snapshot.dart';
import 'z_study_subject.dart';
import 'z_study_topic.dart';

/// Composition des dépôts de structure exposés par un hôte.
///
/// Étendre cette classe et redéclarer **uniquement** les entités servies ;
/// tout le reste vaut `null` sans une ligne de code.
abstract class ZStudyStructurePort {
  /// Construit un port. Sans état : une instance `const` convient.
  const ZStudyStructurePort();

  /// Dépôt des organisations, `null` si non servi.
  ZRepository<ZStudyOrganization>? get organizations => null;

  /// Dépôt des unités d'organisation, `null` si non servi.
  ZRepository<ZStudyOrgUnit>? get orgUnits => null;

  /// Dépôt des groupes, `null` si non servi.
  ZRepository<ZStudyGroup>? get groups => null;

  /// Dépôt des programmes, `null` si non servi.
  ZRepository<ZStudyProgram>? get programs => null;

  /// Dépôt des liaisons programme ↔ cours, `null` si non servi.
  ZRepository<ZStudyProgramCourse>? get programCourses => null;

  /// Dépôt des matières, `null` si non servi.
  ZRepository<ZStudySubject>? get subjects => null;

  /// Dépôt des cours, `null` si non servi.
  ZRepository<ZStudyCourse>? get courses => null;

  /// Dépôt des périodes, `null` si non servi.
  ZRepository<ZStudyPeriod>? get periods => null;

  /// Dépôt des offres, `null` si non servi.
  ZRepository<ZStudyOffering>? get offerings => null;

  /// Dépôt des audiences d'offres, `null` si non servi.
  ZRepository<ZStudyOfferingAudience>? get offeringAudiences => null;

  /// Dépôt des participations, `null` si non servi.
  ZRepository<ZStudyParticipation>? get participations => null;

  /// Dépôt des curriculums, `null` si non servi.
  ZRepository<ZStudyCurriculum>? get curricula => null;

  /// Dépôt des thèmes, `null` si non servi.
  ZRepository<ZStudyTopic>? get topics => null;

  /// Dépôt des cadres de compétences, `null` si non servi.
  ZRepository<ZStudyCompetencyFramework>? get competencyFrameworks => null;

  /// Dépôt des compétences, `null` si non servi.
  ZRepository<ZStudyCompetency>? get competencies => null;

  /// Dépôt des classifications, `null` si non servi.
  ZRepository<ZStudyClassification>? get classifications => null;

  /// Dépôt des attributions de rôles, `null` si non servi.
  ///
  /// Rappel : ces enregistrements décrivent des **faits**. Les lire ne dit rien
  /// de ce qui est permis — l'autorisation est calculée par l'hôte.
  ZRepository<ZStudyRoleBinding>? get roleBindings => null;

  /// Dépôt des faits de partage, `null` si non servi.
  ZRepository<ZStudyShareGrant>? get shareGrants => null;
}

/// Port de structure ne servant **aucune** entité.
///
/// Utile comme valeur par défaut d'un hôte qui n'a pas encore de structure, et
/// comme témoin dans les tests : tous les accesseurs rendent `null`, et rien ne
/// se produit.
class ZInertStudyStructurePort extends ZStudyStructurePort {
  /// Construit le port inerte.
  const ZInertStudyStructurePort();
}

/// Demande d'import de structure, dans un format **neutre**.
///
/// Un import est un instantané plus des correspondances externes : rien de
/// propre à un système d'origine n'entre dans le noyau. Les identifiants d'un
/// annuaire ou d'un export voyagent dans les `externalRefs` des entités
/// elles-mêmes, et [sourceSystem] ne sert qu'à nommer d'où vient le lot.
class ZStudyStructureImport {
  /// Construit une demande d'import.
  const ZStudyStructureImport({
    this.snapshot = ZStudyStructureSnapshot.empty,
    this.sourceSystem,
    this.dryRun = false,
  });

  /// Contenu à importer.
  final ZStudyStructureSnapshot snapshot;

  /// Nom du système d'origine — chaîne opaque, `null` si non qualifié.
  final String? sourceSystem;

  /// Si `true`, l'implémentation calcule le rapport **sans rien écrire**.
  final bool dryRun;
}

/// Compte rendu d'un import de structure.
///
/// [created], [updated] et [skipped] sont indexés par `kind` de modèle
/// (`study_organization`, `study_offering`…) : la même clé que celle du
/// registre, pour qu'un rapport se relise sans table de correspondance.
class ZStudyStructureImportReport {
  /// Construit un rapport d'import.
  const ZStudyStructureImportReport({
    this.created = const <String, int>{},
    this.updated = const <String, int>{},
    this.skipped = const <String, int>{},
    this.rejections = const <String>[],
    this.dryRun = false,
  });

  /// Nombre d'enregistrements créés, par `kind` de modèle.
  final Map<String, int> created;

  /// Nombre d'enregistrements mis à jour, par `kind` de modèle.
  final Map<String, int> updated;

  /// Nombre d'enregistrements ignorés (déjà à jour), par `kind` de modèle.
  final Map<String, int> skipped;

  /// Motifs de rejet, un par enregistrement refusé.
  ///
  /// Un rejet **n'interrompt pas** l'import : un lot partiellement importable
  /// l'est partiellement, et le rapport dit exactement ce qui n'est pas passé.
  final List<String> rejections;

  /// `true` si le rapport décrit une simulation, sans aucune écriture.
  final bool dryRun;

  /// `true` si aucun enregistrement n'a été refusé.
  bool get isClean => rejections.isEmpty;

  /// Sérialise le rapport ; une section vide n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    if (created.isNotEmpty) 'created': Map<String, int>.of(created),
    if (updated.isNotEmpty) 'updated': Map<String, int>.of(updated),
    if (skipped.isNotEmpty) 'skipped': Map<String, int>.of(skipped),
    if (rejections.isNotEmpty) 'rejections': List<String>.of(rejections),
    'dry_run': dryRun,
  };
}

/// Port d'import d'une structure au format neutre.
abstract class ZStudyStructureImportPort {
  /// Construit un port d'import. Sans état : une instance `const` convient.
  const ZStudyStructureImportPort();

  /// Importe [request] et rend le compte rendu, ou `Left(ZFailure)`.
  Future<ZResult<ZStudyStructureImportReport>> import(
    ZStudyStructureImport request,
  );
}

/// Port d'import n'important rien.
///
/// Rend systématiquement `Left(ZUnsupportedOperationFailure)` : un hôte sans
/// import se branche dessus et obtient un refus **explicite**, jamais un succès
/// silencieux qui laisserait croire que des données ont été écrites.
class ZInertStudyStructureImportPort extends ZStudyStructureImportPort {
  /// Construit le port d'import inerte.
  const ZInertStudyStructureImportPort();

  @override
  Future<ZResult<ZStudyStructureImportReport>> import(
    ZStudyStructureImport request,
  ) async => Left<ZFailure, ZStudyStructureImportReport>(
    const ZUnsupportedOperationFailure(
      'Aucun import de structure n\'est branché sur cet hôte.',
      operation: 'ZStudyStructureImportPort.import',
    ),
  );
}

/// Port de résolution d'un mandant à partir de son identifiant.
///
/// Le noyau ne sait pas d'où vient une personne : annuaire, fournisseur
/// d'identité, table locale. Ce port est la seule voie par laquelle un
/// identifiant devient une référence affichable.
abstract class ZStudyPrincipalResolver {
  /// Construit un résolveur. Sans état : une instance `const` convient.
  const ZStudyPrincipalResolver();

  /// Résout [id] en référence, ou `Left(ZNotFoundFailure)` s'il est inconnu.
  Future<ZResult<ZStudyRef>> resolve(String id);
}

/// Résolveur de mandant ne résolvant rien.
///
/// Rend systématiquement `Left(ZNotFoundFailure)` — un refus explicite plutôt
/// qu'une référence fabriquée. Un noyau qui inventerait un libellé pour un
/// identifiant qu'il ne connaît pas ferait passer une supposition pour une
/// donnée.
class ZInertStudyPrincipalResolver extends ZStudyPrincipalResolver {
  /// Construit le résolveur inerte.
  const ZInertStudyPrincipalResolver();

  @override
  Future<ZResult<ZStudyRef>> resolve(String id) async =>
      Left<ZFailure, ZStudyRef>(
        ZNotFoundFailure('Mandant « $id » non résolu : aucun annuaire branché.'),
      );
}
