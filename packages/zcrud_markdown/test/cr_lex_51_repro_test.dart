// CR-LEX-51 — REPRODUCTION (discipline R3).
//
// §A — un `code` inline contenant du HTML (`` `<u>` ``) est détruit au décodage
//      et la balise déborde en soulignement RÉEL sur la fin de la phrase.
// §B — une liste ordonnée ne démarrant pas à 1 est renumérotée.
//
// Ce fichier MESURE le comportement décrit par la CR sur le code actuel. Il ne
// corrige rien : il doit ROUGIR tant que le défaut est présent, et devient la
// garde mordante une fois la correction appliquée.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

String _plainText(List<Map<String, dynamic>> ops) =>
    ops.map((op) => op['insert']).whereType<String>().join();

bool _hasAttr(List<Map<String, dynamic>> ops, String attr, [Object? value]) =>
    ops.any((op) {
      final Object? a = op['attributes'];
      if (a is! Map || !a.containsKey(attr)) return false;
      return value == null || a[attr] == value;
    });

/// Texte porté par les ops qui ont l'attribut [attr].
String _textWithAttr(List<Map<String, dynamic>> ops, String attr) => ops
    .where((op) {
      final Object? a = op['attributes'];
      return a is Map && a.containsKey(attr);
    })
    .map((op) => op['insert'])
    .whereType<String>()
    .join();

void main() {
  const codec = ZMarkdownCodec();

  group('CR-LEX-51 §A — code inline contenant du HTML', () {
    // L'exemple EXACT de la CR, côté Delta (ce que produit l'éditeur).
    const ops = <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'La balise '},
      <String, dynamic>{
        'insert': '<u>',
        'attributes': <String, dynamic>{'code': true},
      },
      <String, dynamic>{'insert': ' est interdite dans une déclaration.\n'},
    ];

    test('encode écrit bien le code inline `<u>`', () {
      final String md = codec.encode(ops)! as String;
      expect(md, contains('`<u>`'));
    });

    test('round-trip : le texte n\'est ni amputé ni augmenté', () {
      final String md = codec.encode(ops)! as String;
      final List<Map<String, dynamic>> back = codec.decode(md);
      expect(
        _plainText(back),
        'La balise <u> est interdite dans une déclaration.\n',
        reason: 'CR-51 §A : le `<u>` du code inline est consommé comme balise '
            'et une balise fermante est réécrite en fin de ligne.',
      );
    });

    test('round-trip : le code inline SURVIT', () {
      final String md = codec.encode(ops)! as String;
      final List<Map<String, dynamic>> back = codec.decode(md);
      expect(
        _hasAttr(back, 'code'),
        isTrue,
        reason: 'CR-51 §A : `code-inline` disparaît des marqueurs.',
      );
      expect(_textWithAttr(back, 'code'), '<u>');
    });

    test('round-trip : AUCUN soulignement réel n\'est introduit', () {
      final String md = codec.encode(ops)! as String;
      final List<Map<String, dynamic>> back = codec.decode(md);
      expect(
        _hasAttr(back, 'underline'),
        isFalse,
        reason: 'CR-51 §A : le `<u>` est ré-interprété en soulignement qui '
            'avale la fin de la phrase.',
      );
    });

    test('la corruption ne déborde pas au second round-trip', () {
      final String md1 = codec.encode(ops)! as String;
      final String md2 = codec.encode(codec.decode(md1))! as String;
      expect(md2, isNot(contains('</u>')));
      expect(md2, contains('`<u>`'));
    });

    test(
        'un `<u>` RÉEL et un `<u>` EN CODE dans la MÊME phrase : chacun garde '
        'son rôle', () {
      // Ajouté à la correction (discipline R3) : sans ce cas, la garde
      // « contenu de `code` opaque » n'est jamais mordante — le court-circuit
      // « aucun marqueur dans le document » suffisait à faire passer l'exemple
      // de la CR, et retirer la garde ne rougissait RIEN. Ici le document porte
      // un VRAI marqueur `<u>` (hors code), donc la machine à états s'exécute
      // pour de bon et doit distinguer les deux occurrences.
      const mixed = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'Le mot '},
        <String, dynamic>{
          'insert': 'souligné',
          'attributes': <String, dynamic>{'underline': true},
        },
        <String, dynamic>{'insert': ' s\'écrit avec '},
        <String, dynamic>{
          'insert': '<u>',
          'attributes': <String, dynamic>{'code': true},
        },
        <String, dynamic>{'insert': ' en HTML.\n'},
      ];
      final String md = codec.encode(mixed)! as String;
      final List<Map<String, dynamic>> back = codec.decode(md);

      expect(
        _plainText(back),
        'Le mot souligné s\'écrit avec <u> en HTML.\n',
        reason: 'le texte doit être RIGOUREUSEMENT conservé',
      );
      expect(_textWithAttr(back, 'code'), '<u>',
          reason: 'le `<u>` en CODE reste du code');
      expect(_textWithAttr(back, 'underline'), 'souligné',
          reason: 'le soulignement RÉEL ne doit ni disparaître ni s\'étendre '
              'sur le `<u>` du code ni sur la fin de la phrase');
    });

    test('CONTRÔLE NÉGATIF — un code inline SANS HTML survit intact', () {
      const plainCode = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'Position '},
        <String, dynamic>{
          'insert': '8471.30.00',
          'attributes': <String, dynamic>{'code': true},
        },
        <String, dynamic>{'insert': ' du tarif.\n'},
      ];
      final List<Map<String, dynamic>> back =
          codec.decode(codec.encode(plainCode)! as String);
      expect(_plainText(back), 'Position 8471.30.00 du tarif.\n');
      expect(_textWithAttr(back, 'code'), '8471.30.00');
    });

    test('depuis le Markdown source (sens lecture)', () {
      const source = 'La balise `<u>` est interdite dans une déclaration.\n';
      final List<Map<String, dynamic>> ops2 = codec.decode(source);
      expect(
        _plainText(ops2),
        'La balise <u> est interdite dans une déclaration.\n',
      );
      expect(_hasAttr(ops2, 'underline'), isFalse);
      expect(_hasAttr(ops2, 'code'), isTrue);
    });
  });

  group('CR-LEX-51 §B — liste ordonnée ne démarrant pas à 1', () {
    const source = '3. Contrôle documentaire\n4. Mainlevée\n';

    test('round-trip Markdown : le numéro de départ est conservé', () {
      final List<Map<String, dynamic>> ops = codec.decode(source);
      final String md = codec.encode(ops)! as String;
      expect(
        md,
        contains('3. Contrôle documentaire'),
        reason: 'CR-51 §B : la liste est renumérotée à partir de 1, ce qui '
            'change la référence citée.',
      );
      expect(md, contains('4. Mainlevée'));
    });

    test('le Delta décodé porte le numéro de départ', () {
      final List<Map<String, dynamic>> ops = codec.decode(source);
      final Iterable<Object?> attrs = ops
          .map((op) => op['attributes'])
          .whereType<Map<dynamic, dynamic>>()
          .where((a) => a['list'] == 'ordered');
      expect(attrs, isNotEmpty, reason: 'liste ordonnée attendue');
      expect(
        attrs.first,
        contains('start'),
        reason: 'CR-51 §B : le Delta ne porte pas le numéro de départ.',
      );
    });
  });
}
