// Garde d'INERTIE ABSOLUE du dossier face à l'arrivée du kernel pédagogique.
//
// Le lot P0b-A1 ajoute une famille entière de types de structure. Aucun d'eux
// ne doit modifier ce que `ZStudyFolder` écrit : un dossier sérialisé après le
// lot doit produire une map STRICTEMENT ÉGALE, clé pour clé et valeur pour
// valeur, à celle produite au tag v3.28.0.
//
// La map de référence est FIGÉE EN LITTÉRAL (relevée sur le paquet au tag,
// avant toute écriture du lot) : la garde ne se compare pas à elle-même. Une
// assertion relative (`containsPair`, `length >=`) laisserait passer
// exactement le défaut qu'on surveille — l'ajout silencieux d'une clé.
//
// Le rattachement d'un dossier à la structure (propriétaire, portée
// principale, rattachements) est déliberément HORS de ce lot : il arrivera par
// des canaux additifs, et cette garde est ce qui obligera à prouver qu'ils
// n'émettent rien tant qu'ils sont vides.

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Map produite par `ZStudyFolder(title: 'T').toMap()` au tag v3.28.0.
const Map<String, dynamic> _minimalAtV3280 = <String, dynamic>{
  'id': null,
  'title': 'T',
  'color_key': '',
  'parent_id': null,
  'owner_id': '',
  'archived_at': null,
  'created_at': null,
  'is_public': false,
  'shared_with': <String>[],
  'can_be_joined_with_link': false,
  'co_workers_can_invite_others': false,
  'share_id': null,
};

/// Map produite au tag v3.28.0 par un dossier dont tous les champs sont
/// renseignés (aucune clé nulle ne subsiste).
const Map<String, dynamic> _fullAtV3280 = <String, dynamic>{
  'id': 'f1',
  'title': 'T',
  'color_key': 'blue',
  'parent_id': 'p1',
  'subject_id': 'subj1',
  'owner_id': 'o1',
  'archived_at': '2026-01-02T03:04:05.000Z',
  'created_at': '2025-01-02T03:04:05.000Z',
  'is_public': true,
  'shared_with': <String>['a'],
  'can_be_joined_with_link': true,
  'co_workers_can_invite_others': true,
  'share_id': 's1',
};

void main() {
  group('ZStudyFolder — inertie absolue face au kernel pédagogique', () {
    test('la map d\'un dossier minimal est IDENTIQUE à celle de v3.28.0', () {
      final map = const ZStudyFolder(title: 'T').toMap();

      // Égalité STRICTE des deux côtés : ni clé en trop, ni clé en moins.
      expect(map.keys.toSet(), equals(_minimalAtV3280.keys.toSet()));
      expect(map, equals(_minimalAtV3280));
    });

    test('la map d\'un dossier complet est IDENTIQUE à celle de v3.28.0', () {
      final map = ZStudyFolder(
        id: 'f1',
        title: 'T',
        colorKey: 'blue',
        parentId: 'p1',
        subjectId: 'subj1',
        ownerId: 'o1',
        archivedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        createdAt: DateTime.utc(2025, 1, 2, 3, 4, 5),
        isPublic: true,
        sharedWith: const <String>['a'],
        canBeJoinedWithLink: true,
        coWorkersCanInviteOthers: true,
        shareId: 's1',
      ).toMap();

      expect(map.keys.toSet(), equals(_fullAtV3280.keys.toSet()));
      expect(map, equals(_fullAtV3280));
    });

    test('aucun champ de rattachement n\'est déclaré sur le dossier', () {
      // Ce lot n'ouvre AUCUN canal de rattachement sur le dossier : les noms
      // ci-dessous ne doivent apparaître ni dans le schéma généré, ni dans la
      // map. Si un lot ultérieur les ajoute, il devra prouver ici que la map
      // d'un dossier SANS rattachement reste celle de v3.28.0.
      final names = <String>{
        for (final spec in $ZStudyFolderFieldSpecs) spec.name,
      };
      for (final forbidden in <String>[
        'owner_ref',
        'primary_scope_ref',
        'bindings',
        'attachments',
        'topic_ids',
        'external_refs',
      ]) {
        expect(
          names,
          isNot(contains(forbidden)),
          reason: '$forbidden ne doit pas être un champ du dossier',
        );
        expect(
          const ZStudyFolder(title: 'T').toMap().keys,
          isNot(contains(forbidden)),
          reason: '$forbidden ne doit pas être émis par un dossier vide',
        );
      }
    });
  });
}
