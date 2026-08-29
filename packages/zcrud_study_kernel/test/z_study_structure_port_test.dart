// Gardes des PORTS de structure.
//
// Deux propriétés, et une seule vraiment importante : un port inerte doit
// REFUSER EXPLICITEMENT, jamais réussir en silence. Un import qui rendrait un
// rapport vide en `Right` ferait croire à un hôte que ses données sont
// écrites ; un résolveur qui fabriquerait une référence ferait passer une
// supposition pour une donnée. Les deux défauts sont muets — d'où ces gardes.

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('ZStudyStructurePort — l\'absence est la valeur par défaut', () {
    test('un port inerte ne sert AUCUNE entité', () {
      const port = ZInertStudyStructurePort();
      expect(port.organizations, isNull);
      expect(port.orgUnits, isNull);
      expect(port.groups, isNull);
      expect(port.programs, isNull);
      expect(port.programCourses, isNull);
      expect(port.subjects, isNull);
      expect(port.courses, isNull);
      expect(port.periods, isNull);
      expect(port.offerings, isNull);
      expect(port.offeringAudiences, isNull);
      expect(port.participations, isNull);
      expect(port.curricula, isNull);
      expect(port.topics, isNull);
      expect(port.competencyFrameworks, isNull);
      expect(port.competencies, isNull);
      expect(port.classifications, isNull);
      expect(port.roleBindings, isNull);
      expect(port.shareGrants, isNull);
    });

    test('un hôte ne redéclare QUE ce qu\'il porte', () {
      // La preuve que les défauts sont utilisables : ce port ne déclare rien,
      // et reste un port valide. Si les accesseurs étaient abstraits, cette
      // classe ne compilerait pas.
      const port = _PortPartiel();
      expect(port.groups, isNull);
      expect(port.offerings, isNull);
    });
  });

  group('ZStudyStructureImportPort — un refus explicite, jamais un succès '
      'silencieux', () {
    test('le port inerte REFUSE, et nomme l\'opération', () async {
      const port = ZInertStudyStructureImportPort();
      final resultat = await port.import(const ZStudyStructureImport());
      expect(
        resultat.fold<bool>(
          (ZFailure f) => f is ZUnsupportedOperationFailure,
          (_) => false,
        ),
        isTrue,
      );
      expect(
        resultat.fold<String>(
          (ZFailure f) =>
              f is ZUnsupportedOperationFailure ? f.operation : '',
          (_) => '',
        ),
        equals('ZStudyStructureImportPort.import'),
      );
    });

    test('une demande d\'import par défaut est vide et non destructrice', () {
      const demande = ZStudyStructureImport();
      expect(demande.snapshot.isEmpty, isTrue);
      expect(demande.sourceSystem, isNull);
      expect(demande.dryRun, isFalse);
    });

    test('un rapport vide est propre, et le dit', () {
      const rapport = ZStudyStructureImportReport();
      expect(rapport.isClean, isTrue);
      expect(rapport.toMap(), equals(<String, dynamic>{'dry_run': false}));
    });

    test('un rapport porteur de rejets n\'est PAS propre', () {
      const rapport = ZStudyStructureImportReport(
        created: <String, int>{'study_offering': 2},
        rejections: <String>['offre sans cours'],
        dryRun: true,
      );
      expect(rapport.isClean, isFalse);
      expect(rapport.toMap(), <String, dynamic>{
        'created': <String, int>{'study_offering': 2},
        'rejections': <String>['offre sans cours'],
        'dry_run': true,
      });
    });
  });

  group('ZStudyPrincipalResolver — ne fabrique jamais une référence', () {
    test('le résolveur inerte refuse et n\'invente aucun libellé', () async {
      const resolveur = ZInertStudyPrincipalResolver();
      final resultat = await resolveur.resolve('inconnu');
      expect(
        resultat.fold<bool>(
          (ZFailure f) => f is ZNotFoundFailure,
          (_) => false,
        ),
        isTrue,
      );
      // Contre-épreuve : aucune référence n'est rendue, même vide.
      expect(
        resultat.fold<ZStudyRef?>((_) => null, (ZStudyRef r) => r),
        isNull,
      );
    });
  });

  group('ZStudyStructureSnapshot — vue partielle exploitable', () {
    test('l\'instantané vide est vide, et le dit', () {
      expect(ZStudyStructureSnapshot.empty.isEmpty, isTrue);
    });

    test('ancestorIdsOf d\'une cible inconnue rend une chaîne vide, sans '
        'échec', () {
      expect(
        ZStudyStructureSnapshot.empty.ancestorIdsOf(
          const ZStudyRef(type: kZStudyRefTypeGroup, id: 'absent'),
        ),
        isEmpty,
      );
    });

    test('ancestorIdsOf d\'un type sans arbre rend une chaîne vide', () {
      expect(
        ZStudyStructureSnapshot.empty.ancestorIdsOf(
          const ZStudyRef(type: kZStudyRefTypeSubject, id: 's1'),
        ),
        isEmpty,
      );
    });

    test('refFor d\'une cible inconnue garde l\'identité sans inventer de '
        'libellé', () {
      final ref = ZStudyStructureSnapshot.empty.refFor(
        kZStudyRefTypeGroup,
        'absent',
      );
      expect(ref.type, equals(kZStudyRefTypeGroup));
      expect(ref.id, equals('absent'));
      expect(ref.label, isNull);
      expect(ref.code, isNull);
    });

    test('refFor d\'une cible connue porte son instantané d\'affichage', () {
      const snapshot = ZStudyStructureSnapshot(
        groups: <String, ZStudyGroup>{
          'g1': ZStudyGroup(id: 'g1', label: 'Cohorte', code: 'G1'),
        },
      );
      final ref = snapshot.refFor(kZStudyRefTypeGroup, 'g1');
      expect(ref.label, equals('Cohorte'));
      expect(ref.code, equals('G1'));
    });
  });
}

/// Hôte ne servant rien — vérifie que les défauts du port sont utilisables.
class _PortPartiel extends ZStudyStructurePort {
  const _PortPartiel();
}
