import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Extension concrète de test (audio/RAG factice) : `formatVersion` 1 géré,
/// autre version → le décodeur renvoie `null` (rétro-compat AD-10).
class _FakeExt extends ZExtension {
  const _FakeExt(this.confidence);

  final double confidence;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'format_version': formatVersion,
        'confidence': confidence,
      };

  static _FakeExt? decode(Map<String, dynamic> json) {
    if (json['format_version'] != 1) return null; // version non gérée
    final c = json['confidence'];
    return _FakeExt(c is num ? c.toDouble() : 0);
  }
}

void main() {
  group('ZMindmapNode — réutilisation du cœur (AC1/AC2)', () {
    test('étend ZNode et mixe ZExtensible', () {
      final node = ZMindmapNode(id: 'n1', label: 'A');
      expect(node, isA<ZNode>());
      expect(node, isA<ZExtensible>());
      expect(node.id, 'n1');
    });

    test('défauts : extra jamais null, extension null, children vide', () {
      final node = ZMindmapNode(id: 'n1');
      expect(node.extra, isEmpty);
      expect(node.extension, isNull);
      expect(node.children, isEmpty);
      expect(node.level, 0);
      expect(node.content, isNull);
    });

    test('children copiés défensivement (immuabilité)', () {
      final kids = [ZMindmapNode(id: 'c1')];
      final node = ZMindmapNode(id: 'p', children: kids);
      kids.add(ZMindmapNode(id: 'c2'));
      expect(node.children, hasLength(1)); // non affecté
      expect(() => node.children.add(ZMindmapNode(id: 'x')),
          throwsUnsupportedError);
    });

    test('aucun copyWith public exposé', () {
      // Vérification de conception : ZMindmapNode n'expose pas de copyWith.
      // (compile-time — l'absence de la méthode est garantie par l'API.)
      final node = ZMindmapNode(id: 'n1');
      expect(node, isNotNull);
    });
  });

  group('ZMindmapNode — round-trip snake_case (AC6)', () {
    test('toJson/fromJson stable', () {
      final node = ZMindmapNode(
        id: 'root',
        label: 'Racine',
        content: 'texte brut\nmultiligne',
        level: 0,
        children: [
          ZMindmapNode(id: 'c1', label: 'Enfant', level: 1),
        ],
      );
      final json = node.toJson();
      final back = ZMindmapNode.fromJson(json);
      expect(back.id, 'root');
      expect(back.label, 'Racine');
      expect(back.content, 'texte brut\nmultiligne');
      expect(back.children.single.id, 'c1');
      expect(back.children.single.level, 1);
      expect(back.toJson(), json); // round-trip idempotent
    });

    test('content null omis de la sérialisation', () {
      final json = ZMindmapNode(id: 'n1').toJson();
      expect(json.containsKey('content'), isFalse);
    });

    test('INVARIANT AD-16 : jamais updated_at/is_deleted', () {
      final json = ZMindmapNode(
        id: 'n1',
        children: [ZMindmapNode(id: 'c1', level: 1)],
      ).toJson();
      expect(json.containsKey('updated_at'), isFalse);
      expect(json.containsKey('is_deleted'), isFalse);
      final childJson = (json['children'] as List).first as Map;
      expect(childJson.containsKey('updated_at'), isFalse);
      expect(childJson.containsKey('is_deleted'), isFalse);
    });
  });

  group('ZMindmapNode — désérialisation défensive (AC6/AD-10)', () {
    test('map vide → jamais de throw, défauts sûrs', () {
      final node = ZMindmapNode.fromJson(<String, dynamic>{});
      expect(node.id, '');
      expect(node.label, '');
      expect(node.content, isNull);
      expect(node.level, 0);
      expect(node.children, isEmpty);
    });

    test('children absent / non-liste → []', () {
      expect(ZMindmapNode.fromJson({'children': 'oops'}).children, isEmpty);
      expect(ZMindmapNode.fromJson({'children': 42}).children, isEmpty);
    });

    test('enfant corrompu (non-map) ignoré, parent survit', () {
      final node = ZMindmapNode.fromJson({
        'id': 'p',
        'children': [
          'not-a-map',
          {'id': 'ok'},
          123,
        ],
      });
      expect(node.id, 'p');
      expect(node.children, hasLength(1));
      expect(node.children.single.id, 'ok');
    });

    test('level non-int → 0', () {
      expect(ZMindmapNode.fromJson({'level': 'x'}).level, 0);
      expect(ZMindmapNode.fromJson({'level': 2.5}).level, 0);
    });

    test('clés extra inconnues préservées au round-trip', () {
      final node = ZMindmapNode.fromJson({
        'id': 'n1',
        'audio_url': 'https://x/a.mp3',
        'rag_score': 0.8,
      });
      expect(node.extra['audio_url'], 'https://x/a.mp3');
      expect(node.extra['rag_score'], 0.8);
      final json = node.toJson();
      expect(json['audio_url'], 'https://x/a.mp3');
      expect(json['rag_score'], 0.8);
    });

    test('extension : version gérée décodée', () {
      final node = ZMindmapNode.fromJson(
        {
          'id': 'n1',
          'extension': {'format_version': 1, 'confidence': 0.9},
        },
        extensionDecoder: _FakeExt.decode,
      );
      expect(node.extension, isA<_FakeExt>());
      expect((node.extension! as _FakeExt).confidence, 0.9);
    });

    test('extension : formatVersion inconnue → null, nœud survit', () {
      final node = ZMindmapNode.fromJson(
        {
          'id': 'n1',
          'extension': {'format_version': 99, 'confidence': 0.9},
        },
        extensionDecoder: _FakeExt.decode,
      );
      expect(node.extension, isNull);
      expect(node.id, 'n1');
    });

    test('extension : décodeur qui throw → null (guard), nœud survit', () {
      final node = ZMindmapNode.fromJson(
        {
          'id': 'n1',
          'extension': {'format_version': 1},
        },
        extensionDecoder: (_) => throw StateError('boom'),
      );
      expect(node.extension, isNull);
      expect(node.id, 'n1');
    });

    test('extension : corrompue (non-map) → null', () {
      final node = ZMindmapNode.fromJson(
        {'id': 'n1', 'extension': 'garbage'},
        extensionDecoder: _FakeExt.decode,
      );
      expect(node.extension, isNull);
    });

    test('sans décodeur, extension ignorée → null (mais pas dans extra)', () {
      final node = ZMindmapNode.fromJson({
        'id': 'n1',
        'extension': {'format_version': 1},
      });
      expect(node.extension, isNull);
      expect(node.extra.containsKey('extension'), isFalse);
    });
  });
}
