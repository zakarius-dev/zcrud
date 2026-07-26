// CR-LEX-49 (MAJEUR) — REPRODUCTION.
//
// « Aucune ligne vide n'est émise après un blockquote : le paragraphe suivant
//   est AVALÉ DANS la citation (lazy continuation CommonMark). »
//
// Oracle porteur = la 4e projection réclamée par la CR : l'ARBRE Delta.
// Un oracle de chaîne qui normalise les lignes vides efface exactement la
// différence porteuse — d'où la comparaison ligne-à-ligne des ATTRIBUTS DE BLOC
// (portés par les `\n` en Delta) entre le Delta d'entrée et celui de sortie.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Une ligne logique du Delta : son texte et ses attributs de BLOC (portés par
/// le `\n` terminal, convention Quill).
@immutable
class _Line {
  const _Line(this.text, this.blockAttrs);

  final String text;
  final Map<String, dynamic> blockAttrs;

  @override
  String toString() => '${blockAttrs.isEmpty ? '[]' : blockAttrs}|$text';
}

/// Projette des ops Delta neutres en lignes logiques (texte + attributs de bloc).
List<_Line> _lines(List<Map<String, dynamic>> ops) {
  final out = <_Line>[];
  final buffer = StringBuffer();
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is! String) {
      buffer.write('\u{FFFC}'); // embed : objet de remplacement
      continue;
    }
    final Map<String, dynamic> attrs = op['attributes'] is Map
        ? Map<String, dynamic>.from(op['attributes'] as Map)
        : <String, dynamic>{};
    final parts = insert.split('\n');
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        // Un `\n` vient d'être franchi : la ligne se termine, ses attributs de
        // bloc sont ceux de l'op qui porte ce `\n`.
        out.add(_Line(buffer.toString(), attrs));
        buffer.clear();
      }
      buffer.write(parts[i]);
    }
  }
  if (buffer.isNotEmpty) out.add(_Line(buffer.toString(), const {}));
  return out;
}

/// Attributs de bloc de la première ligne dont le texte contient [needle].
Map<String, dynamic> _blockAttrsOfLineContaining(
  List<_Line> lines,
  String needle,
) {
  for (final line in lines) {
    if (line.text.contains(needle)) return line.blockAttrs;
  }
  fail('Aucune ligne ne contient « $needle » dans $lines');
}

void main() {
  const codec = ZMarkdownCodec();

  const String source = '> La valeur en douane est la valeur transactionnelle.\n'
      '\n'
      "Ce commentaire est de l'auteur, pas du texte cité.\n";

  group('CR-LEX-49 — frontière de bloc après un blockquote', () {
    test('ARBRE Delta : le paragraphe suivant ne DOIT PAS acquérir blockquote',
        () {
      final ops0 = codec.decode(source);
      final lines0 = _lines(ops0);

      // Contrôle de l'entrée : la citation est bien une citation, le
      // commentaire n'en est pas une. Si cela échoue, le décodeur est en cause,
      // pas l'encodeur.
      expect(
        _blockAttrsOfLineContaining(lines0, 'valeur transactionnelle'),
        contains('blockquote'),
        reason: 'entrée : la citation doit porter blockquote',
      );
      expect(
        _blockAttrsOfLineContaining(lines0, 'Ce commentaire'),
        isNot(contains('blockquote')),
        reason: "entrée : le commentaire de l'auteur n'est PAS une citation",
      );

      final cycle1 = codec.encode(ops0)! as String;
      final ops1 = codec.decode(cycle1);
      final lines1 = _lines(ops1);

      expect(
        _blockAttrsOfLineContaining(lines1, 'valeur transactionnelle'),
        contains('blockquote'),
        reason: 'sortie : la citation reste une citation',
      );
      // LE POINT DE LA CR : le commentaire ne doit pas être happé.
      expect(
        _blockAttrsOfLineContaining(lines1, 'Ce commentaire'),
        isNot(contains('blockquote')),
        reason: "CR-LEX-49 : le commentaire de l'auteur a été AVALÉ dans la "
            'citation (lazy continuation) — markdown émis :\n$cycle1',
      );
    });

    test('le Markdown émis sépare la citation du paragraphe par une ligne vide',
        () {
      final cycle1 = codec.encode(codec.decode(source))! as String;
      expect(
        cycle1,
        matches(RegExp(r'>[^\n]*\n[ \t]*\n[ \t]*Ce commentaire')),
        reason: 'aucune ligne vide entre le blockquote et le paragraphe : '
            'markdown émis :\n$cycle1',
      );
    });

    test('idempotence : cycle2 == cycle1', () {
      final cycle1 = codec.encode(codec.decode(source))! as String;
      final cycle2 = codec.encode(codec.decode(cycle1))! as String;
      expect(cycle2, cycle1, reason: 'conversion non idempotente');
    });

    // Périmètre EXACT annoncé par la CR : seul le PARAGRAPHE est avalé.
    // Contrôles NÉGATIFS — s'ils rougissent, la CR sous-estime le périmètre.
    group('périmètre — les autres blocs ouvrent bien un nouveau bloc', () {
      const cases = <String, String>{
        'titre': '## Un titre',
        'liste': '- un item',
        'bloc de code': '```\nvar x = 1;\n```',
        'tableau': '| a | b |\n| --- | --- |\n| 1 | 2 |',
      };
      for (final entry in cases.entries) {
        test('${entry.key} après une citation', () {
          final String src = '> Une citation.\n\n${entry.value}\n';
          final cycle1 = codec.encode(codec.decode(src))! as String;
          final lines1 = _lines(codec.decode(cycle1));
          for (final line in lines1) {
            if (line.text.contains('Une citation')) continue;
            if (line.text.trim().isEmpty) continue;
            expect(
              line.blockAttrs,
              isNot(contains('blockquote')),
              reason: '${entry.key} avalé dans la citation — '
                  'markdown émis :\n$cycle1',
            );
          }
        });
      }
    });
  });
}
