import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

void main() {
  mainCrLex14();
  group('ZMindmap — modèle container (AC3)', () {
    test('mixe ZExtensible, défauts sûrs', () {
      final map = ZMindmap(id: 'm1', folderId: 'f1');
      expect(map, isA<ZExtensible>());
      expect(map.extra, isEmpty);
      expect(map.extension, isNull);
      expect(map.nodes, isEmpty);
      expect(map.title, '');
      expect(map.description, isNull);
    });

    test('multi-racine autorisé, nodes copiés défensivement', () {
      final roots = [ZMindmapNode(id: 'r1'), ZMindmapNode(id: 'r2')];
      final map = ZMindmap(id: 'm1', folderId: 'f1', nodes: roots);
      expect(map.nodes, hasLength(2));
      expect(() => map.nodes.add(ZMindmapNode(id: 'x')),
          throwsUnsupportedError);
    });
  });

  group('ZMindmap — round-trip snake_case (AC6)', () {
    test('folder_id en snake_case, round-trip stable', () {
      final map = ZMindmap(
        id: 'm1',
        folderId: 'folder-42',
        title: 'Ma carte',
        description: 'desc',
        nodes: [
          ZMindmapNode(id: 'r', label: 'R', level: 0, children: [
            ZMindmapNode(id: 'c', label: 'C', level: 1),
          ]),
        ],
      );
      final json = map.toJson();
      expect(json['folder_id'], 'folder-42');
      expect(json.containsKey('folderId'), isFalse);
      final back = ZMindmap.fromJson(json);
      expect(back.folderId, 'folder-42');
      expect(back.title, 'Ma carte');
      expect(back.description, 'desc');
      expect(back.nodes.single.children.single.id, 'c');
      expect(back.toJson(), json);
    });

    test('description null omise', () {
      final json = ZMindmap(id: 'm1', folderId: 'f1').toJson();
      expect(json.containsKey('description'), isFalse);
    });

    test('INVARIANT AD-16 : ZMindmap sans updated_at/is_deleted', () {
      final json = ZMindmap(
        id: 'm1',
        folderId: 'f1',
        nodes: [ZMindmapNode(id: 'r')],
      ).toJson();
      expect(json.containsKey('updated_at'), isFalse);
      expect(json.containsKey('is_deleted'), isFalse);
    });

    test(
        'INVARIANT AD-16 : des clés de sync en entrée ne survivent PAS au '
        'round-trip fromJson→toJson (jamais capturées dans extra)', () {
      final map = ZMindmap.fromJson(<String, dynamic>{
        'id': 'm1',
        'folder_id': 'f1',
        'updated_at': '2026-07-10T00:00:00Z',
        'is_deleted': true,
        'nodes': <dynamic>[
          <String, dynamic>{
            'id': 'r',
            'updated_at': '2026-07-10T00:00:00Z',
            'is_deleted': false,
          },
        ],
      });
      // Ni la carte ni le nœud ne doivent avoir capturé les clés réservées.
      expect(map.extra.containsKey('updated_at'), isFalse);
      expect(map.extra.containsKey('is_deleted'), isFalse);
      expect(map.nodes.single.extra.containsKey('updated_at'), isFalse);
      expect(map.nodes.single.extra.containsKey('is_deleted'), isFalse);
      final json = map.toJson();
      expect(json.containsKey('updated_at'), isFalse);
      expect(json.containsKey('is_deleted'), isFalse);
      final nodeJson = (json['nodes'] as List).single as Map<String, dynamic>;
      expect(nodeJson.containsKey('updated_at'), isFalse);
      expect(nodeJson.containsKey('is_deleted'), isFalse);
    });
  });

  group('ZMindmap — défensif + renormalisation level (AC6)', () {
    test('map vide → jamais de throw', () {
      final map = ZMindmap.fromJson(<String, dynamic>{});
      expect(map.id, '');
      expect(map.folderId, '');
      expect(map.title, '');
      expect(map.nodes, isEmpty);
    });

    test('nodes non-liste → []', () {
      expect(ZMindmap.fromJson({'nodes': 'x'}).nodes, isEmpty);
    });

    test('level persistés incohérents renormalisés (racine→0, cascade)', () {
      final map = ZMindmap.fromJson({
        'id': 'm1',
        'folder_id': 'f1',
        'nodes': [
          {
            'id': 'r',
            'level': 99, // incohérent
            'children': [
              {
                'id': 'c',
                'level': 7, // incohérent
                'children': [
                  {'id': 'g', 'level': -3},
                ],
              },
            ],
          },
        ],
      });
      final r = map.nodes.single;
      expect(r.level, 0);
      expect(r.children.single.level, 1);
      expect(r.children.single.children.single.level, 2);
    });

    test('clés extra inconnues préservées', () {
      final map = ZMindmap.fromJson({
        'id': 'm1',
        'folder_id': 'f1',
        'owner': 'zak',
      });
      expect(map.extra['owner'], 'zak');
      expect(map.toJson()['owner'], 'zak');
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CR-LEX-14 — `ZMindmap` doit être utilisable par la chaîne de persistance.
// ─────────────────────────────────────────────────────────────────────────────
void mainCrLex14() {
  group('CR-LEX-14 — conformité ZEntity', () {
    test('🔴 ZMindmap SATISFAIT la borne `T extends ZEntity`', () {
      // Discriminant : avant, `buildFolderScopedStudyRepository<ZMindmap>` et
      // toute la chaîne (`ZStudyRepository`, `ZLocalStore`, `HiveZLocalStore`)
      // refusaient le type — « doesn't conform to the bound 'ZEntity' ».
      // Cette fonction générique reproduit la borne : si ZMindmap ne la
      // satisfaisait pas, ce fichier NE COMPILERAIT PAS.
      String? idOf<T extends ZEntity>(T e) => e.id;

      final m = ZMindmap(id: 'm1', folderId: 'f1');
      expect(idOf<ZMindmap>(m), 'm1');
      expect(m, isA<ZEntity>());
    });

    test('`id` reste NON-NULLABLE : aucune rupture pour l\'existant', () {
      final m = ZMindmap(id: 'm1', folderId: 'f1');
      // Si `id` était devenu `String?`, cette affectation ne compilerait pas.
      final String id = m.id;
      expect(id, 'm1');
    });

    test('isEphemeral suit la chaîne VIDE (marqueur réel d\'absence d\'id)', () {
      expect(ZMindmap(id: '', folderId: 'f1').isEphemeral, isTrue);
      expect(ZMindmap(id: 'm1', folderId: 'f1').isEphemeral, isFalse);
      // Le défaut hérité (`id == null`) serait TOUJOURS faux ici : sans cette
      // redéfinition, une carte sans identité se dirait matérialisée.
    });

    test('un document sans `id` se désérialise en éphémère', () {
      final m = ZMindmap.fromJson(<String, dynamic>{'folder_id': 'f1'});
      expect(m.isEphemeral, isTrue);
    });
  });
}
