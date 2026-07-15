/// Tests ES-7.2 du verrou modèle OQ-S5 (AC7) : `ZMindmapNode.content` reste
/// **texte brut** (`String?`), ZÉRO champ rich-text, ensemble de clés émises
/// **figé**, et round-trip **byte-préservé** d'un payload rich stocké dans le
/// slot AD-4 (`extra`). AD-28 / AD-4 / AD-10 / AD-16.
///
/// Injection **INJ-4** : ajouter un champ rich-text au modèle (émis par `toJson`)
/// ou l'insérer dans les clés connues casse (a) le verrou « clés émises == set
/// figé » et/ou (b) le round-trip du payload dans `extra` (il serait capturé
/// comme champ typé au lieu de transiter par le slot).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Payload rich (ops Delta neutres) stocké dans le slot AD-4 — PAS dans `content`.
List<Map<String, dynamic>> _richPayload() => <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Bonjour '},
      <String, dynamic>{
        'insert': 'gras',
        'attributes': <String, dynamic>{'bold': true},
      },
      <String, dynamic>{'insert': '\n'},
    ];

void main() {
  group('AC7 — content texte brut, ZÉRO champ rich-text', () {
    test('content est un String? texte brut (jamais un objet rich)', () {
      final node = ZMindmapNode(id: 'n', content: 'ligne 1\nligne 2');
      expect(node.content, isA<String>());
      expect(node.content, 'ligne 1\nligne 2');

      final nul = ZMindmapNode(id: 'n2');
      expect(nul.content, isNull);
    });

    test(
        'INJ-4 : ensemble de clés ÉMISES par toJson est FIGÉ '
        '(id,label,level,children [+content/extension si présents])', () {
      // Nœud minimal : aucun champ rich-text ne doit apparaître.
      final minimal = ZMindmapNode(id: 'a', label: 'b').toJson();
      // 🔴 GARDE (INJ-4) : ajouter un champ rich-text émis par toJson (ex.
      // `delta`/`rich_content`/`format`) fait grossir cet ensemble ⇒ ROUGE.
      expect(
        minimal.keys.toSet(),
        <String>{'id', 'label', 'level', 'children'},
      );
      // Aucune clé de format rich parasite.
      for (final forbidden in const <String>[
        'delta',
        'rich_content',
        'richContent',
        'format',
        'ops',
      ]) {
        expect(minimal.containsKey(forbidden), isFalse,
            reason: 'clé rich-text interdite émise : $forbidden');
      }

      // Avec content présent : `content` s'ajoute (texte brut), rien d'autre.
      final withContent =
          ZMindmapNode(id: 'a', label: 'b', content: 'x').toJson();
      expect(
        withContent.keys.toSet(),
        <String>{'id', 'label', 'content', 'level', 'children'},
      );
      expect(withContent['content'], 'x');
    });
  });

  group('AC7 — round-trip byte-préservé du payload rich dans le slot AD-4', () {
    test(
        'un payload rich sous une clé applicative de `extra` survit '
        'fromJson→toJson INCHANGÉ ; content reste texte brut', () {
      final payload = _richPayload();
      final json = <String, dynamic>{
        'id': 'n',
        'label': 'Titre',
        'content': 'texte brut', // reste texte brut (OQ-S5)
        'level': 0,
        'children': <dynamic>[],
        'rich_delta': payload, // slot AD-4 (clé applicative)
      };

      final node = ZMindmapNode.fromJson(json);
      // Le payload transite par le slot `extra` (jamais un champ typé du modèle).
      expect(node.extra['rich_delta'], equals(payload));
      // `content` reste texte brut, distinct du payload rich.
      expect(node.content, 'texte brut');

      final out = node.toJson();
      // 🔴 Round-trip byte-préservé : payload inchangé, content préservé.
      expect(out['rich_delta'], equals(payload));
      expect(out['content'], 'texte brut');
    });

    test('AD-16 : le round-trip ne ré-émet JAMAIS les clés de sync', () {
      final json = <String, dynamic>{
        'id': 'n',
        'label': 'L',
        'rich_delta': _richPayload(),
        'updated_at': '2026-07-15T00:00:00Z',
        'is_deleted': true,
      };
      final out = ZMindmapNode.fromJson(json).toJson();
      expect(out.containsKey('updated_at'), isFalse);
      expect(out.containsKey('is_deleted'), isFalse);
      // Le payload rich, lui, est préservé.
      expect(out['rich_delta'], equals(_richPayload()));
    });
  });
}
