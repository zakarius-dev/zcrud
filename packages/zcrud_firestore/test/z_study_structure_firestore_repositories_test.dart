// Garde e2e de la fabrique des dépôts Firestore de la structure d'étude.
//
// Ce que cette garde établit, et qui n'est établi nulle part ailleurs :
// - le round-trip complet passe par le dépôt GÉNÉRIQUE + le registrar de
//   codegen du noyau (aucun adaptateur spécifique n'existe pour ces entités) ;
// - un document abîmé n'emporte ni la lecture ni ses voisins (AD-10) ;
// - `absentMeansAlive` rend lisible une collection préexistante sans
//   `is_deleted` — en `strict`, la même collection est vide (c'est la moitié
//   qui rend l'assertion mordante) ;
// - la requête de portée sur la chaîne d'ancêtres retient les descendants à
//   toute profondeur et EXCLUT l'ancêtre lui-même ;
// - le soft-delete retire des vivants, `deletedOnly` retrouve, `restore` rend.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Topologie plate : une collection par `kind`, nommée par son `kind`.
String _flat(String kind) => kind;

ZStudyStructureRepositories _build(
  FirebaseFirestore firestore, {
  ZDeletionSemantics deletionSemantics = ZDeletionSemantics.strict,
  String? legacyDeletedKey,
}) =>
    buildStudyStructureRepositories(
      firestore: firestore,
      collectionPathOf: _flat,
      deletionSemantics: deletionSemantics,
      legacyDeletedKey: legacyDeletedKey,
    );

void main() {
  group('buildStudyStructureRepositories — câblage', () {
    test('les 23 dépôts sont construits, sur 23 collections DISTINCTES', () {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final List<String> asked = <String>[];
      final ZStudyStructureRepositories repositories =
          buildStudyStructureRepositories(
        firestore: firestore,
        collectionPathOf: (String kind) {
          asked.add(kind);
          return kind;
        },
      );

      expect(repositories.all, hasLength(23));
      expect(asked, hasLength(23));
      expect(asked.toSet(), hasLength(23));
      // Les kinds viennent du registre du noyau, jamais d'un littéral local.
      expect(
        asked.every((String kind) => kind.startsWith('study_')),
        isTrue,
        reason: 'kinds observés : $asked',
      );
      repositories.dispose();
    });

    test('chaque kind demandé est celui que le registre associe au type', () {
      final ZcrudRegistry registry = buildStudyStructureRegistry();
      expect(registry.kindOf<ZStudyOrganization>(), 'study_organization');
      expect(registry.kindOf<ZStudyGroup>(), 'study_group');
      expect(registry.kindOf<ZStudyOffering>(), 'study_offering');
      expect(registry.kindOf<ZStudyShareGrant>(), 'study_share_grant');
    });
  });

  group('round-trip par le dépôt générique', () {
    test('organisation : save → getById restitue TOUS les champs', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final ZStudyStructureRepositories repositories = _build(firestore);

      final ZResult<ZStudyOrganization> saved =
          await repositories.organizations.save(
        const ZStudyOrganization(
          id: 'org-1',
          workspaceId: 'ws-1',
          kind: 'school',
          label: 'Lycée Central',
          code: 'LC',
          ancestorIds: <String>['root'],
          extra: <String, dynamic>{'couleur': 'bleu'},
        ),
      );
      expect(saved.isRight(), isTrue);

      final ZResult<ZStudyOrganization> read =
          await repositories.organizations.getById('org-1');
      final ZStudyOrganization value = read.getOrElse(
        () => const ZStudyOrganization(),
      );
      expect(value.id, 'org-1');
      expect(value.workspaceId, 'ws-1');
      expect(value.kind, 'school');
      expect(value.label, 'Lycée Central');
      expect(value.code, 'LC');
      expect(value.ancestorIds, <String>['root']);
      expect(value.extra['couleur'], 'bleu');
      repositories.dispose();
    });

    test('groupe et offre : save → getAll les restitue', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final ZStudyStructureRepositories repositories = _build(firestore);

      await repositories.groups.save(
        const ZStudyGroup(
          id: 'grp-1',
          organizationId: 'org-1',
          kind: 'classe',
          label: '3e B',
        ),
      );
      await repositories.offerings.save(
        const ZStudyOffering(
          id: 'off-1',
          organizationId: 'org-1',
          courseId: 'crs-1',
          periodId: 'per-1',
          label: 'Maths 3e B',
        ),
      );

      final ZResult<List<ZStudyGroup>> groups =
          await repositories.groups.getAll();
      expect(
        groups.getOrElse(() => <ZStudyGroup>[]).map((ZStudyGroup g) => g.label),
        <String>['3e B'],
      );
      final ZResult<List<ZStudyOffering>> offerings =
          await repositories.offerings.getAll();
      final List<ZStudyOffering> list =
          offerings.getOrElse(() => <ZStudyOffering>[]);
      expect(list, hasLength(1));
      expect(list.single.courseId, 'crs-1');
      expect(list.single.periodId, 'per-1');
      repositories.dispose();
    });
  });

  group('AD-10 — document corrompu', () {
    test('lecture jamais en échec, voisin sain intact, champ illisible neutralisé',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      // Document sain, écrit par le dépôt (forme canonique + méta de sync).
      final ZStudyStructureRepositories repositories = _build(firestore);
      await repositories.groups.save(
        const ZStudyGroup(id: 'grp-ok', label: 'sain'),
      );
      // Document corrompu, écrit HORS du dépôt : trois champs portent un type
      // que le schéma n'admet pas.
      //
      // MESURE : le décodeur du noyau est lui-même défensif — il ne LÈVE pas
      // sur ces valeurs, il fait retomber chaque champ illisible sur son
      // défaut. La voie « document écarté » du dépôt (enveloppe de `fromMap`)
      // reste donc inatteignable par ce chemin, et ce n'est PAS ce que cette
      // garde affirme. Ce qu'elle affirme, et qui est le vrai contrat AD-10 :
      // la lecture ne devient jamais un `Left`, le document sain n'est pas
      // perdu, et le champ illisible ne franchit jamais la frontière tel quel.
      await firestore.collection('study_group').doc('grp-ko').set(
        <String, dynamic>{
          'label': <String, dynamic>{'pas': 'un texte'},
          'kind': 42,
          'ancestor_ids': 42,
          'is_deleted': false,
          'updated_at': DateTime.utc(2026).toIso8601String(),
        },
      );

      final ZResult<List<ZStudyGroup>> all = await repositories.groups.getAll();
      final List<ZStudyGroup> list = all.getOrElse(() => <ZStudyGroup>[]);
      expect(all.isRight(), isTrue, reason: 'un doc corrompu n\'échoue jamais');

      final ZStudyGroup sain =
          list.firstWhere((ZStudyGroup g) => g.id == 'grp-ok');
      expect(sain.label, 'sain', reason: 'le voisin sain est intact');

      final ZStudyGroup corrompu =
          list.firstWhere((ZStudyGroup g) => g.id == 'grp-ko');
      expect(corrompu.label, '', reason: 'champ illisible → défaut du schéma');
      expect(corrompu.kind, '');
      expect(corrompu.ancestorIds, <String>[]);
      repositories.dispose();
    });
  });

  group('absentMeansAlive — collection préexistante', () {
    Future<void> seedLegacy(FakeFirebaseFirestore firestore) =>
        firestore.collection('study_subject').doc('sub-legacy').set(
          <String, dynamic>{'label': 'Histoire', 'kind': 'matiere'},
        );

    test('strict : un document SANS is_deleted n\'est PAS lu', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await seedLegacy(firestore);
      final ZStudyStructureRepositories repositories = _build(firestore);

      final ZResult<List<ZStudySubject>> all =
          await repositories.subjects.getAll();
      expect(all.getOrElse(() => <ZStudySubject>[]), isEmpty);
      repositories.dispose();
    });

    test('absentMeansAlive : le MÊME document est lu', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      await seedLegacy(firestore);
      final ZStudyStructureRepositories repositories = _build(
        firestore,
        deletionSemantics: ZDeletionSemantics.absentMeansAlive,
      );

      final ZResult<List<ZStudySubject>> all =
          await repositories.subjects.getAll();
      final List<ZStudySubject> list = all.getOrElse(() => <ZStudySubject>[]);
      expect(list, hasLength(1));
      expect(list.single.id, 'sub-legacy');
      expect(list.single.label, 'Histoire');
      repositories.dispose();
    });
  });

  group('portée par chaîne d\'ancêtres', () {
    test('descendants à toute profondeur, ancêtre EXCLU', () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final ZStudyStructureRepositories repositories = _build(firestore);

      await repositories.orgUnits.save(
        const ZStudyOrgUnit(id: 'u-root', label: 'racine'),
      );
      await repositories.orgUnits.save(
        const ZStudyOrgUnit(
          id: 'u-child',
          parentId: 'u-root',
          label: 'enfant',
          ancestorIds: <String>['u-root'],
        ),
      );
      await repositories.orgUnits.save(
        const ZStudyOrgUnit(
          id: 'u-grand',
          parentId: 'u-child',
          label: 'petit-enfant',
          ancestorIds: <String>['u-root', 'u-child'],
        ),
      );
      await repositories.orgUnits.save(
        const ZStudyOrgUnit(id: 'u-other', label: 'hors portée'),
      );

      final ZResult<List<ZStudyOrgUnit>> scoped = await repositories.orgUnits
          .getAll(request: zStudyAncestorRequest('u-root'));
      final List<String?> ids = scoped
          .getOrElse(() => <ZStudyOrgUnit>[])
          .map((ZStudyOrgUnit u) => u.id)
          .toList()
        ..sort();
      expect(ids, <String>['u-child', 'u-grand']);
      repositories.dispose();
    });

    test('la clé visée est CELLE que la sérialisation du noyau émet', () {
      // Sans cette assertion, la requête pourrait viser une clé inexistante et
      // ne jamais rien rendre — un défaut silencieux.
      final Map<String, dynamic> map = const ZStudyOrgUnit(
        id: 'u',
        ancestorIds: <String>['a'],
      ).toMap();
      expect(map.containsKey(kZStudyAncestorIdsKey), isTrue);
      expect(map[kZStudyAncestorIdsKey], <String>['a']);
      expect(zStudyAncestorFilter('a').field, kZStudyAncestorIdsKey);
      expect(zStudyAncestorFilter('a').op, ZFilterOp.contains);
      expect(zStudyAncestorFilter('a').value, 'a');
    });
  });

  group('soft-delete', () {
    test('softDelete retire des vivants, deletedOnly retrouve, restore rend',
        () async {
      final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
      final ZStudyStructureRepositories repositories = _build(firestore);
      await repositories.courses.save(
        const ZStudyCourse(id: 'crs-1', label: 'Algèbre'),
      );

      expect(
        (await repositories.courses.softDelete('crs-1')).isRight(),
        isTrue,
      );
      expect(
        (await repositories.courses.getAll())
            .getOrElse(() => <ZStudyCourse>[]),
        isEmpty,
      );
      final ZResult<List<ZStudyCourse>> trash = await repositories.courses
          .getAll(request: const ZDataRequest(
            deletedScope: ZDeletedScope.deletedOnly,
          ));
      expect(
        trash.getOrElse(() => <ZStudyCourse>[]).map((ZStudyCourse c) => c.id),
        <String>['crs-1'],
      );

      expect((await repositories.courses.restore('crs-1')).isRight(), isTrue);
      expect(
        (await repositories.courses.getAll())
            .getOrElse(() => <ZStudyCourse>[])
            .map((ZStudyCourse c) => c.id),
        <String>['crs-1'],
      );
      repositories.dispose();
    });
  });
}
