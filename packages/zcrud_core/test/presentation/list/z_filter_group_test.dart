// Gardes de la DISJONCTION (`ZFilterGroup`) dans le moteur de liste du socle.
//
// Le cas qui la motive est le plus courant d'un workflow : « cet état OU ce
// champ jamais renseigné », parce que l'état initial d'un dossier est
// l'absence d'état. Exprimé par la seule égalité, l'onglet d'entrée se vide
// des dossiers fraîchement déposés — silencieusement.
//
// Ce que ces gardes tiennent :
//   * une ligne dont le champ est ABSENT est bien retenue par « valeur ou
//     absence » ;
//   * un groupe est ANDé au reste : il élargit DANS le groupe, jamais au-delà
//     (il ne peut pas faire ressortir ce qu'un filtre a exclu) ;
//   * un groupe SANS clause est inerte (il ne vide pas le listing) ;
//   * la requête reste comparable par valeur avec sa nouvelle dimension.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'libelle', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'etat', type: EditionFieldType.text),
];

/// Trois rapports : un « en attente » déclaré, un « clos », et un rapport
/// **fraîchement déposé** dont la cellule `etat` n'existe pas du tout.
final _rows = <ZListRow>[
  const ZListRow(
    id: 'r1',
    cells: <String, Object?>{'libelle': 'Alpha', 'etat': 'enAttente'},
  ),
  const ZListRow(
    id: 'r2',
    cells: <String, Object?>{'libelle': 'Bravo', 'etat': 'clos'},
  ),
  const ZListRow(
    id: 'r3',
    cells: <String, Object?>{'libelle': 'Charlie'},
  ),
];

List<String> _ids(ZDataRequest request) => <String>[
      for (final row in zApplyListRequest(_rows, request, schema: _schema).rows)
        row.id,
    ];

/// La disjonction du cas réel : l'état déclaré **ou** le champ absent.
const _enAttenteOuAbsent = ZFilterGroup.any(<ZFilter>[
  ZFilter('etat', ZFilterOp.eq, 'enAttente'),
  ZFilter('etat', ZFilterOp.isNull),
]);

void main() {
  group('« valeur X ou champ absent »', () {
    test(
        '🔴 le rapport dont le champ est ABSENT est listé — l\'onglet d\'entrée '
        'du workflow ne se vide plus', () {
      expect(
        _ids(const ZDataRequest(filterGroups: <ZFilterGroup>[
          _enAttenteOuAbsent,
        ])),
        <String>['r1', 'r3'],
      );
    });

    test(
        'CONTRE-TÉMOIN : la même règle en conjonction perd le rapport au champ '
        'absent', () {
      expect(
        _ids(const ZDataRequest(filters: <ZFilter>[
          ZFilter('etat', ZFilterOp.eq, 'enAttente'),
        ])),
        <String>['r1'],
        reason: 'c\'est exactement la perte que la disjonction corrige',
      );
    });
  });

  group('Composition', () {
    test('un groupe est ANDé aux filtres : il n\'élargit jamais au-delà', () {
      expect(
        _ids(
          const ZDataRequest(
            filters: <ZFilter>[ZFilter('libelle', ZFilterOp.eq, 'Charlie')],
            filterGroups: <ZFilterGroup>[_enAttenteOuAbsent],
          ),
        ),
        <String>['r3'],
        reason: 'la disjonction ne peut pas faire ressortir Alpha, exclu par '
            'le filtre',
      );
      expect(
        _ids(
          const ZDataRequest(
            filters: <ZFilter>[ZFilter('libelle', ZFilterOp.eq, 'Bravo')],
            filterGroups: <ZFilterGroup>[_enAttenteOuAbsent],
          ),
        ),
        isEmpty,
        reason: 'Bravo passe le filtre mais pas le groupe : les deux comptent',
      );
    });

    test('deux groupes sont ANDés entre eux (chacun résolu en OR)', () {
      expect(
        _ids(
          const ZDataRequest(
            filterGroups: <ZFilterGroup>[
              _enAttenteOuAbsent,
              ZFilterGroup.any(<ZFilter>[
                ZFilter('libelle', ZFilterOp.eq, 'Charlie'),
                ZFilter('libelle', ZFilterOp.eq, 'Bravo'),
              ]),
            ],
          ),
        ),
        <String>['r3'],
      );
    });

    test('un groupe SANS clause est inerte — il ne vide pas le listing', () {
      expect(
        _ids(const ZDataRequest(filterGroups: <ZFilterGroup>[
          ZFilterGroup.any(<ZFilter>[]),
        ])),
        <String>['r1', 'r2', 'r3'],
      );
      expect(const ZFilterGroup.any(<ZFilter>[]).isEmpty, isTrue);
      expect(_enAttenteOuAbsent.isNotEmpty, isTrue);
    });

    test('une clause non comparable ne lève pas et laisse les autres décider',
        () {
      expect(
        _ids(
          const ZDataRequest(
            filterGroups: <ZFilterGroup>[
              ZFilterGroup.any(<ZFilter>[
                // Comparaison impossible (texte vs nombre) : retombe sur
                // « ne matche pas », sans exception (AD-10).
                ZFilter('libelle', ZFilterOp.gt, 42),
                ZFilter('etat', ZFilterOp.isNull),
              ]),
            ],
          ),
        ),
        <String>['r3'],
      );
    });
  });

  group('Contrat de requête', () {
    test('aucun groupe déclaré ⇒ requête et résultat strictement inchangés',
        () {
      expect(const ZDataRequest().filterGroups, isEmpty);
      expect(const ZDataRequest().hasFilterGroups, isFalse);
      expect(_ids(const ZDataRequest()), <String>['r1', 'r2', 'r3']);
    });

    test('hasFilterGroups ignore les groupes inertes', () {
      expect(
        const ZDataRequest(filterGroups: <ZFilterGroup>[
          ZFilterGroup.any(<ZFilter>[]),
        ]).hasFilterGroups,
        isFalse,
      );
      expect(
        const ZDataRequest(filterGroups: <ZFilterGroup>[
          _enAttenteOuAbsent,
        ]).hasFilterGroups,
        isTrue,
      );
    });

    test('égalité de valeur et copyWith portent la nouvelle dimension', () {
      const a = ZDataRequest(filterGroups: <ZFilterGroup>[_enAttenteOuAbsent]);
      const b = ZDataRequest(filterGroups: <ZFilterGroup>[_enAttenteOuAbsent]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const ZDataRequest()));
      expect(
        const ZDataRequest()
            .copyWith(filterGroups: const <ZFilterGroup>[_enAttenteOuAbsent]),
        a,
      );
      expect(
        a.copyWith(limit: 10).filterGroups,
        <ZFilterGroup>[_enAttenteOuAbsent],
        reason: 'une copie sans mention conserve les groupes',
      );
      expect(
        const ZFilterGroup.any(<ZFilter>[ZFilter('etat', ZFilterOp.isNull)]),
        const ZFilterGroup.any(<ZFilter>[ZFilter('etat', ZFilterOp.isNull)]),
      );
      expect(
        const ZFilterGroup.any(<ZFilter>[]).toString(),
        contains('ZFilterGroup.any'),
      );
    });
  });
}
