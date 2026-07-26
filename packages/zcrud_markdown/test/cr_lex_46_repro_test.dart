// CR-LEX-46 (MAJEUR) — REPRODUCTION.
//
// Affirmation de la CR : le **texte ALT** d'une image est EFFACÉ au PREMIER
// round-trip Markdown, et cette perte n'est documentée NULLE PART dans la table
// des pertes de `ZMarkdownCodec` (qui annonce au contraire les « images via
// `![](src)` » parmi ce que le round-trip PRÉSERVE).
//
// Ce fichier ne corrige rien : il MESURE. Chaque test asserte l'invariant
// RÉCLAMÉ par la CR, donc doit ROUGIR sur le code actuel si la CR est exacte.
//
// Exécution : `cd packages/zcrud_markdown && dart test test/cr_lex_46_repro_test.dart`
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

const String _src = 'https://exemple.test/circuit.png';
const String _alt = 'Schéma du circuit de dédouanement';
const String _markdown = '![$_alt]($_src)';

void main() {
  const codec = ZMarkdownCodec();

  group('CR-LEX-46 — ALT d\'image au round-trip Markdown', () {
    test('DIAGNOSTIC : forme des ops décodées depuis `![alt](src)`', () {
      final ops = codec.decode(_markdown);
      // Trace de mesure (pas d'oracle ici) exploitée par les tests suivants.
      // ignore: avoid_print
      print('CR-46 decode($_markdown) => $ops');
      expect(ops, isNotEmpty, reason: 'le décodage ne doit rien détruire');
    });

    test('INVARIANT RÉCLAMÉ 1 — le ALT survit dans la charge de l\'embed image',
        () {
      final ops = codec.decode(_markdown);
      final imageOps = ops.where((op) {
        final insert = op['insert'];
        return insert is Map && insert.containsKey('image');
      }).toList();

      expect(imageOps, hasLength(1),
          reason: 'un embed image doit être produit depuis `![alt](src)`');

      // La CR ne prescrit pas la forme (charge `{image: src, alt: …}` OU
      // attribut d'op) : elle exige la SURVIE du ALT quelque part dans l'op.
      expect(imageOps.single.toString(), contains(_alt),
          reason: 'CR-46 : le texte ALT est absent de l\'op image décodée — '
              'il n\'a aucune place dans la charge de l\'embed');
    });

    test(
        'INVARIANT RÉCLAMÉ 2 — round-trip markdown→Delta→markdown : le ALT est '
        'restitué', () {
      final ops = codec.decode(_markdown);
      final roundTripped = codec.encode(ops);

      expect(roundTripped, isA<String>());
      expect(roundTripped! as String, contains(_src),
          reason: 'l\'URL survit (déjà acquis avant cette CR)');
      expect(roundTripped as String, contains(_alt),
          reason: 'CR-46 : le texte ALT est EFFACÉ dès le premier round-trip — '
              'attendu `![alt](src)`, obtenu `![](src)`');
    });

    test('MESURE EXACTE de la sortie du round-trip (chaîne complète)', () {
      final roundTripped = codec.encode(codec.decode(_markdown))! as String;
      // ignore: avoid_print
      print('CR-46 round-trip => "${roundTripped.trim()}"');
      expect(roundTripped.trim(), _markdown,
          reason: 'CR-46 : round-trip attendu à l\'identique');
    });

    test('SECOND VOLET DE LA CR — la perte du ALT est-elle DOCUMENTÉE ?', () {
      // À défaut de correction, la CR demande l'inscription EXPLICITE de la
      // perte dans la table des pertes. On mesure la doc réelle sur disque.
      final source =
          File('lib/src/data/z_markdown_codec.dart').readAsStringSync();
      final documented = RegExp(
        r'alt[^\n]*\bperdu\b|\bperdu\b[^\n]*alt',
        caseSensitive: false,
      ).hasMatch(source);
      expect(documented, isTrue,
          reason: 'CR-46 : ni la table des pertes ni la doc de `image` '
              'ne mentionnent la perte du texte ALT');
    });
  });
}
