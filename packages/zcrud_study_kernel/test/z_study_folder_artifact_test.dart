// Garde des CANAUX DE RATTACHEMENT du dossier.
//
// Complément indissociable de `z_study_folder_structure_inertia_test.dart` :
// celle-là prouve qu'un dossier SANS rattachement écrit exactement la map de
// v3.28.0 ; celle-ci prouve qu'un dossier AVEC rattachement écrit vraiment
// quelque chose, et le relit sans perte.
//
// Les deux se tiennent : sans la seconde, on pourrait satisfaire la première
// en n'émettant jamais rien — une inertie parfaite et parfaitement inutile.

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const ZStudyRef _proprietaire = ZStudyRef(
  type: kZStudyRefTypePrincipal,
  id: 'moi',
  label: 'Mandant',
);
const ZStudyRef _portee = ZStudyRef(
  type: kZStudyRefTypeCourse,
  id: 'c1',
  label: 'Cours',
);
const ZStudyRef _groupe = ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1');

ZStudyBinding _lien(
  ZStudyRef cible, {
  String propagation = kZStudyPropagationExact,
  DateTime? validTo,
}) => ZStudyBinding(
  sourceRef: const ZStudyRef(type: kZStudyRefTypeFolder, id: 'f1'),
  targetRef: cible,
  propagation: propagation,
  validTo: validTo,
);

void main() {
  group('Le dossier porte le protocole ZStudyArtifact', () {
    test('un dossier EST un artefact (le protocole est réellement mixé)', () {
      const dossier = ZStudyFolder(title: 'D');
      expect(dossier, isA<ZStudyArtifact>());
    });

    test('les trois canaux round-trippent sans perte', () {
      final dossier = ZStudyFolder(
        id: 'f1',
        title: 'D',
        ownerRef: _proprietaire,
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[
          _lien(_groupe, propagation: kZStudyPropagationDescendants),
          _lien(_portee),
        ],
      );
      expect(ZStudyFolder.fromMap(dossier.toMap()), equals(dossier));
    });

    test('les trois clés SONT émises quand les canaux portent quelque chose',
        () {
      final map = ZStudyFolder(
        title: 'D',
        ownerRef: _proprietaire,
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[_lien(_groupe)],
      ).toMap();
      expect(map.keys, contains('owner_ref'));
      expect(map.keys, contains('primary_scope_ref'));
      expect(map.keys, contains('bindings'));
      // Contre-épreuve : la clé n'est pas seulement présente, elle porte la
      // donnée. Une émission à vide satisferait `contains` sans rien livrer.
      expect((map['owner_ref']! as Map<String, dynamic>)['id'], equals('moi'));
      expect((map['bindings']! as List<Object?>).length, equals(1));
    });

    test('chaque canal est émis INDÉPENDAMMENT des deux autres', () {
      final seulProprietaire = ZStudyFolder(
        title: 'D',
        ownerRef: _proprietaire,
      ).toMap();
      expect(seulProprietaire.keys, contains('owner_ref'));
      expect(seulProprietaire.keys, isNot(contains('primary_scope_ref')));
      expect(seulProprietaire.keys, isNot(contains('bindings')));

      final seulePortee = ZStudyFolder(
        title: 'D',
        primaryScopeRef: _portee,
      ).toMap();
      expect(seulePortee.keys, contains('primary_scope_ref'));
      expect(seulePortee.keys, isNot(contains('owner_ref')));

      final seulsLiens = ZStudyFolder(
        title: 'D',
        bindings: <ZStudyBinding>[_lien(_groupe)],
      ).toMap();
      expect(seulsLiens.keys, contains('bindings'));
      expect(seulsLiens.keys, isNot(contains('owner_ref')));
    });

    test('une liste de rattachements VIDE n\'écrit pas de clé', () {
      final map = ZStudyFolder(
        title: 'D',
        bindings: const <ZStudyBinding>[],
      ).toMap();
      expect(map.keys, isNot(contains('bindings')));
    });

    test('copyWith couvre les trois canaux, remise à null comprise', () {
      final dossier = ZStudyFolder(
        title: 'D',
        ownerRef: _proprietaire,
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[_lien(_groupe)],
      );
      // Un argument omis préserve.
      expect(dossier.copyWith(title: 'E').ownerRef, equals(_proprietaire));
      expect(dossier.copyWith(title: 'E').bindings.length, equals(1));
      // `null` explicite remet à null.
      expect(dossier.copyWith(ownerRef: null).ownerRef, isNull);
      expect(
        dossier.copyWith(primaryScopeRef: null).primaryScopeRef,
        isNull,
      );
      expect(
        dossier.copyWith(bindings: const <ZStudyBinding>[]).toMap().keys,
        isNot(contains('bindings')),
      );
    });
  });

  group('scopeRefs et isBoundTo — le protocole rendu sur un vrai porteur', () {
    test('scopeRefs met la portée principale d\'abord, puis les cibles', () {
      final dossier = ZStudyFolder(
        title: 'D',
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[_lien(_groupe)],
      );
      expect(
        dossier.scopeRefs.map((ZStudyRef r) => r.id),
        <String>['c1', 'g1'],
      );
    });

    test('scopeRefs dédoublonne la portée principale redite en rattachement',
        () {
      final dossier = ZStudyFolder(
        title: 'D',
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[_lien(_portee), _lien(_groupe)],
      );
      expect(
        dossier.scopeRefs.map((ZStudyRef r) => r.id),
        <String>['c1', 'g1'],
      );
    });

    test('isBoundTo ignore un rattachement `none`', () {
      final dossier = ZStudyFolder(
        title: 'D',
        bindings: <ZStudyBinding>[
          _lien(_groupe, propagation: kZStudyPropagationNone),
        ],
      );
      expect(dossier.isBoundTo(_groupe), isFalse);
      // Mais la cible reste listée : elle est désignée, pas étendue.
      expect(dossier.scopeRefs.map((ZStudyRef r) => r.id), <String>['g1']);
    });

    test('isBoundTo honore la fenêtre de validité quand un instant est donné',
        () {
      final dossier = ZStudyFolder(
        title: 'D',
        bindings: <ZStudyBinding>[_lien(_groupe, validTo: DateTime.utc(2026))],
      );
      expect(dossier.isBoundTo(_groupe, at: DateTime.utc(2025)), isTrue);
      expect(dossier.isBoundTo(_groupe, at: DateTime.utc(2027)), isFalse);
      expect(dossier.isBoundTo(_groupe), isTrue);
    });

    test('la portée principale n\'est pas datée : elle compte toujours', () {
      final dossier = ZStudyFolder(title: 'D', primaryScopeRef: _portee);
      expect(dossier.isBoundTo(_portee, at: DateTime.utc(2999)), isTrue);
    });
  });

  group('Décodage défensif et clés réservées', () {
    test('des canaux corrompus ne lèvent pas et retombent sur l\'absence', () {
      final relu = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 'D',
        'owner_ref': 'pas une map',
        'primary_scope_ref': 42,
        'bindings': 'pas une liste',
      });
      expect(relu.ownerRef, isNull);
      expect(relu.primaryScopeRef, isNull);
      expect(relu.bindings, isEmpty);
      expect(relu.toMap, returnsNormally);
    });

    test('un rattachement illisible dans une liste lisible est ignoré, '
        'les autres survivent', () {
      final relu = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 'D',
        'bindings': <Object?>[
          'pas une map',
          <String, dynamic>{
            'source_ref': <String, dynamic>{'type': 'folder', 'id': 'f1'},
            'target_ref': <String, dynamic>{'type': 'group', 'id': 'g1'},
            'propagation': 'exact',
          },
        ],
      });
      expect(relu.bindings.length, equals(1));
      expect(relu.bindings.single.targetRef.id, equals('g1'));
    });

    test('les trois clés de rattachement ne tombent JAMAIS dans extra', () {
      final relu = ZStudyFolder.fromMap(<String, dynamic>{
        'title': 'D',
        'owner_ref': <String, dynamic>{'type': 'principal', 'id': 'moi'},
        'primary_scope_ref': <String, dynamic>{'type': 'course', 'id': 'c1'},
        'bindings': <Object?>[],
        'zz_libre': 'préservée',
      });
      for (final reservee in <String>[
        'owner_ref',
        'primary_scope_ref',
        'bindings',
      ]) {
        expect(relu.extra.keys, isNot(contains(reservee)));
      }
      expect(relu.extra['zz_libre'], equals('préservée'));
    });

    test('les canaux n\'écrasent pas extra, et extra ne les fabrique pas', () {
      final dossier = ZStudyFolder(
        title: 'D',
        ownerRef: _proprietaire,
        extra: const <String, dynamic>{'owner_ref': 'tentative', 'zz': 1},
      );
      // La clé réservée passée par `extra` est filtrée à l'accesseur…
      expect(dossier.extra.keys, isNot(contains('owner_ref')));
      // …et la map porte bien le canal typé, pas la tentative.
      expect(
        (dossier.toMap()['owner_ref']! as Map<String, dynamic>)['id'],
        equals('moi'),
      );
      expect(dossier.toMap()['zz'], equals(1));
    });

    test('le round-trip préserve extra ET les canaux ensemble', () {
      final dossier = ZStudyFolder(
        id: 'f1',
        title: 'D',
        ownerRef: _proprietaire,
        bindings: <ZStudyBinding>[_lien(_groupe)],
        extra: const <String, dynamic>{'zz': 1},
      );
      expect(ZStudyFolder.fromMap(dossier.toMap()), equals(dossier));
    });
  });

  group('Égalité — les canaux entrent dans l\'identité de valeur', () {
    test('deux dossiers ne différant que par le propriétaire ne sont pas '
        'égaux', () {
      const base = ZStudyFolder(title: 'D');
      expect(base.copyWith(ownerRef: _proprietaire) == base, isFalse);
    });

    test('deux dossiers ne différant que par les rattachements ne sont pas '
        'égaux', () {
      final base = const ZStudyFolder(title: 'D');
      expect(
        base.copyWith(bindings: <ZStudyBinding>[_lien(_groupe)]) == base,
        isFalse,
      );
    });

    test('deux dossiers identiques restent égaux, hachage compris', () {
      final a = ZStudyFolder(
        title: 'D',
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[_lien(_groupe)],
      );
      final b = ZStudyFolder(
        title: 'D',
        primaryScopeRef: _portee,
        bindings: <ZStudyBinding>[_lien(_groupe)],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
