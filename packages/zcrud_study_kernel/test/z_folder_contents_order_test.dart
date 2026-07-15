/// Tests de `ZFolderContentsOrder` (`ZExtensible`, patron ES-2.2b + canal
/// hors-codegen `section_orders`) — ES-2.4, FR-S7,
/// AC1..AC9/AC11/AC12.
///
/// ⚠️ **Aucun `dart:io`** (AC12) : le kernel est pur-Dart, ses tests tournent
/// sous `dart test`. Le garde de pureté SM-S5 lit les sources via `dart:io` mais
/// vit dans `z_kernel_purity_test.dart` (`@TestOn('vm')`).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Extension type de test (AD-4 pt.1) — round-trip d'un slot `extension` typé.
class _TestExt extends ZExtension {
  const _TestExt(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'note': note};

  static ZExtension? fromJsonSafe(Map<String, dynamic> json) {
    if (json['format_version'] != 1) return null;
    return ZExtension.guard<ZExtension?>(() => _TestExt(json['note'] as String));
  }

  @override
  bool operator ==(Object other) =>
      other is _TestExt && note == other.note && formatVersion == 1;

  @override
  int get hashCode => Object.hash(note, formatVersion);
}

void main() {
  group('ZFolderContentsOrder — modèle & round-trip (AC1)', () {
    test('valeurs par défaut : folderId vide, sectionOrders/extra vides', () {
      const o = ZFolderContentsOrder();
      expect(o.folderId, '');
      expect(o.sectionOrders, isEmpty);
      expect(o.extension, isNull);
      expect(o.extra, isEmpty);
    });

    test('PAS un ZEntity : aucun id propre (identité = folderId)', () {
      const o = ZFolderContentsOrder(folderId: 'f1');
      expect(o, isNot(isA<ZEntity>()));
      expect(o.folderId, 'f1');
    });

    test('round-trip PLEIN : fromMap(toMap(x)) == x', () {
      final o = ZFolderContentsOrder(
        folderId: 'f1',
        sectionOrders: ZFolderContentsOrder.fromMap(const <String, dynamic>{
          'section_orders': <String, dynamic>{
            'flashcards': <String>['c3', 'c1'],
            'notes': <String>['n2'],
          },
        }).sectionOrders,
      );
      final rt = ZFolderContentsOrder.fromMap(o.toMap());
      expect(rt, equals(o));
      expect(rt.hashCode, equals(o.hashCode));
    });

    test('clé folder_id snake_case', () {
      const o = ZFolderContentsOrder(folderId: 'f1');
      expect(o.toMap()['folder_id'], 'f1');
    });

    test('slot extension typé round-trippé', () {
      const o = ZFolderContentsOrder(folderId: 'f', extension: _TestExt('hi'));
      final map = o.toMap();
      expect((map['extension'] as Map)['note'], 'hi');
      final rt = ZFolderContentsOrder.fromMap(
        map,
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(rt.extension, const _TestExt('hi'));
    });
  });

  group('ZFolderContentsOrder — canal section_orders idempotent (AC2, D3)', () {
    test('section_orders TOUJOURS émise, même {} (idempotence)', () {
      const o = ZFolderContentsOrder(folderId: 'f');
      final map = o.toMap();
      expect(map.containsKey('section_orders'), isTrue);
      expect(map['section_orders'], <String, dynamic>{});
      expect(ZFolderContentsOrder.fromMap(map), equals(o));
    });

    test('section_orders décodée depuis la map, jamais dans extra', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          'flashcards': <String>['c1', 'c2'],
        },
      });
      expect(o.orderFor('flashcards'), <String>['c1', 'c2']);
      // La clé du canal n'apparaît JAMAIS dans extra (réservée) ni en double.
      expect(o.extra.containsKey('section_orders'), isFalse);
    });

    test('round-trip byte-stable : verbatim, aucun dédoublonnage au stockage', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          // doublon volontaire : PAS de nettoyage au décodage (D3-bis / R6).
          'flashcards': <String>['c1', 'c1', 'c2'],
        },
      });
      expect(o.orderFor('flashcards'), <String>['c1', 'c1', 'c2']);
      expect(
        o.toMap()['section_orders'],
        <String, dynamic>{
          'flashcards': <String>['c1', 'c1', 'c2'],
        },
      );
    });

    test('idempotence : fromMap(toMap(fromMap(m))) stable', () {
      final m = <String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          'notes': <String>['n2', 'n1'],
        },
        'zz_libre': 'gardé',
      };
      final a = ZFolderContentsOrder.fromMap(m);
      final b = ZFolderContentsOrder.fromMap(a.toMap());
      expect(b, equals(a));
    });
  });

  group('ZFolderContentsOrder — décodage défensif 2 niveaux + M3 (AC3, AD-10)',
      () {
    test('fromMap(const {}) ne throw pas', () {
      expect(() => ZFolderContentsOrder.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(
          ZFolderContentsOrder.fromMap(const <String, dynamic>{}).sectionOrders,
          isEmpty);
    });

    test('section_orders non-Map (42/"x"/liste/absente) ⇒ {}', () {
      for (final bad in <Object?>[42, 'x', <int>[1, 2], null]) {
        final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
          'folder_id': 'f',
          if (bad != null) 'section_orders': bad,
        });
        expect(o.sectionOrders, isEmpty, reason: 'raw=$bad');
      }
    });

    test('section à valeur non-liste ({"a": 7}) ⇒ section ignorée', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          'a': 7,
          'b': <String>['x'],
        },
      });
      expect(o.sectionOrders.containsKey('a'), isFalse);
      expect(o.orderFor('b'), <String>['x']);
    });

    test('éléments non-String filtrés, ordre relatif préservé', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          'a': <Object?>['x', 3, null, 'y'],
        },
      });
      expect(o.orderFor('a'), <String>['x', 'y']);
    });

    test('clé de section vide "" tolérée (opaque)', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          '': <String>['z'],
        },
      });
      expect(o.orderFor(''), <String>['z']);
    });

    test('immuabilité PROFONDE (M3) — map ET listes non modifiables', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          'a': <String>['x', 'y'],
        },
      });
      expect(() => o.sectionOrders['b'] = <String>[], throwsUnsupportedError);
      expect(() => o.sectionOrders['a']!.add('z'), throwsUnsupportedError);
    });

    test('immuabilité (M3) aussi via copyWith (invariant non rouvert)', () {
      const o = ZFolderContentsOrder(folderId: 'f');
      final c = o.copyWith(sectionOrders: <String, List<String>>{
        'a': <String>['x'],
      });
      expect(() => c.sectionOrders['a']!.add('z'), throwsUnsupportedError);
      expect(() => c.sectionOrders['b'] = <String>[], throwsUnsupportedError);
    });
  });

  group('ZFolderContentsOrder — applyTo délègue à applyOrder (AC4, D4)', () {
    // Vecteurs à POUVOIR DISCRIMINANT OBSERVÉ (leçon ES-2.3).
    final items = <String>['a', 'b', 'c', 'd'];
    String idOf(String s) => s;

    test('ordre partiel/permuté, unordered:end ⇒ [c,a,b,d]', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          's': <String>['c', 'a'],
        },
      });
      // Un impl qui rend l'entrée inchangée → [a,b,c,d] : ROUGE.
      // Un impl qui trie lexicographiquement → [a,b,c,d] : ROUGE.
      expect(o.applyTo('s', items, idOf: idOf), <String>['c', 'a', 'b', 'd']);
    });

    test('unordered:start ⇒ [b,d,c,a]', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          's': <String>['c', 'a'],
        },
      });
      expect(
        o.applyTo('s', items,
            idOf: idOf, unordered: ZUnorderedPlacement.start),
        <String>['b', 'd', 'c', 'a'],
      );
    });

    test('intégrité GRATUITE : id fantôme ignoré, item hors-ordre déterministe',
        () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          's': <String>['z', 'c', 'a'], // z = id fantôme (aucun item)
        },
      });
      expect(o.applyTo('s', items, idOf: idOf), <String>['c', 'a', 'b', 'd']);
    });

    test('doublon dans l\'ordre → 1re occurrence fait foi', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'section_orders': <String, dynamic>{
          's': <String>['a', 'a', 'b'],
        },
      });
      expect(o.applyTo('s', items, idOf: idOf), <String>['a', 'b', 'c', 'd']);
    });

    test('section absente ⇒ ordre d\'entrée préservé', () {
      const o = ZFolderContentsOrder(folderId: 'f');
      expect(o.applyTo('inconnue', items, idOf: idOf), items);
    });
  });

  group('ZFolderContentsOrder — égalité D5 (AC5, OBSERVÉ)', () {
    ZFolderContentsOrder withSection(String key, List<String> ids) =>
        ZFolderContentsOrder.fromMap(<String, dynamic>{
          'folder_id': 'f',
          'section_orders': <String, dynamic>{key: ids},
        });

    test('ordre-SENSIBLE dans une liste : [a,b] != [b,a] (INÉGALES + hash≠)', () {
      final x = withSection('s', <String>['a', 'b']);
      final y = withSection('s', <String>['b', 'a']);
      // 🔴 Un `==`/hash naïvement ENSEMBLISTE sur la liste rendrait CE test VERT
      // à tort — c'est LE test qui prouve que l'ordre est observé (payload).
      expect(x, isNot(equals(y)));
      expect(x.hashCode, isNot(equals(y.hashCode)));
    });

    test('ordre-INSENSIBLE entre sections : clés permutées ⇒ ÉGALES + même hash',
        () {
      final a = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          's1': <String>['a'],
          's2': <String>['b', 'c'],
        },
      });
      final b = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          's2': <String>['b', 'c'],
          's1': <String>['a'],
        },
      });
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('folderId discriminant', () {
      expect(withSection('s', <String>['a']),
          isNot(equals(ZFolderContentsOrder.fromMap(<String, dynamic>{
            'folder_id': 'AUTRE',
            'section_orders': <String, dynamic>{
              's': <String>['a'],
            },
          }))));
    });

    test('extra profond (DW-ES22-4)', () {
      const a = ZFolderContentsOrder(
        folderId: 'f',
        extra: <String, dynamic>{
          'meta': <String, dynamic>{'a': 1, 'b': <int>[1, 2]},
        },
      );
      const b = ZFolderContentsOrder(
        folderId: 'f',
        extra: <String, dynamic>{
          'meta': <String, dynamic>{'a': 1, 'b': <int>[1, 2]},
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ZFolderContentsOrder — AD-19 & extra (AC6/AC7/AC8)', () {
    test('\$FieldSpecs ∩ ZSyncMeta.reservedKeys == {} (R-C)', () {
      final specNames =
          $ZFolderContentsOrderFieldSpecs.map((s) => s.name).toSet();
      expect(specNames.intersection(ZSyncMeta.reservedKeys), isEmpty);
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
    });

    test('aucun champ persistAs:timestamp réservé', () {
      expect(
        $ZFolderContentsOrderTimestampFields.intersection(
            ZSyncMeta.reservedKeys),
        isEmpty,
      );
    });

    test('clé métier inconnue survit (anti-vacuité, AC7)', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'zz_cle_inconnue': 'gardee',
      });
      expect(o.extra['zz_cle_inconnue'], 'gardee');
      expect(o.toMap()['zz_cle_inconnue'], 'gardee');
    });

    test('sonde de STORE : updated_at/is_deleted hors extra + non réémis (AC7)',
        () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          's': <String>['a'],
        },
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      });
      expect(
        o.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
      expect(o.extra['zz_cle_inconnue'], 'gardee');
      final map = o.toMap();
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map['zz_cle_inconnue'], 'gardee');
      // section_orders jamais en double dans extra.
      expect(o.extra.containsKey('section_orders'), isFalse);
    });

    test('pollution ctor const NEUTRALISÉE (accesseur, HIGH-2) — AC8', () {
      const o = ZFolderContentsOrder(
        folderId: 'f',
        extra: <String, dynamic>{
          'is_deleted': true,
          'section_orders': <String, dynamic>{},
          'ok': 1,
        },
      );
      expect(o.extra.containsKey('is_deleted'), isFalse);
      expect(o.extra.containsKey('section_orders'), isFalse);
      expect(o.extra['ok'], 1);
      // Convergence : entité polluée en mémoire == la même relue du store.
      expect(ZFolderContentsOrder.fromMap(o.toMap()), equals(o));
    });

    test('copyWith(extra:) ne rouvre PAS le filtre (garde partagée)', () {
      const o = ZFolderContentsOrder(folderId: 'f');
      final c = o.copyWith(
          extra: <String, dynamic>{'is_deleted': true, 'k': 'v'});
      expect(c.extra.containsKey('is_deleted'), isFalse);
      expect(c.extra['k'], 'v');
    });

    test('_reservedKeys couvre kSectionOrdersKey (via export public)', () {
      // kSectionOrdersKey est la clé persistée du canal (D3).
      expect(kSectionOrdersKey, 'section_orders');
    });
  });

  group('ZFolderContentsOrder — copyWith à sentinelle (tous champs)', () {
    test('champs préservés quand omis', () {
      final o = ZFolderContentsOrder.fromMap(<String, dynamic>{
        'folder_id': 'f',
        'section_orders': <String, dynamic>{
          's': <String>['a'],
        },
        'zz': 'gardé',
      });
      final c = o.copyWith();
      expect(c, equals(o));
    });

    test('folderId / sectionOrders remplacés', () {
      const o = ZFolderContentsOrder(folderId: 'f');
      final c = o.copyWith(
        folderId: 'g',
        sectionOrders: <String, List<String>>{
          's': <String>['x'],
        },
      );
      expect(c.folderId, 'g');
      expect(c.orderFor('s'), <String>['x']);
    });

    test('extension remise à null explicitement', () {
      const o = ZFolderContentsOrder(folderId: 'f', extension: _TestExt('n'));
      expect(o.copyWith(extension: null).extension, isNull);
    });
  });
}
