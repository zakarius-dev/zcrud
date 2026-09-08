// Garde de SOURCE : les deux règles que seul le socle peut énoncer restent
// écrites là où l'appelant les lit.
//
// Pourquoi une garde de SOURCE, et pas un test de comportement.
//
//  · Règle « port d'indice optionnel » : le comportement gardé (sans port,
//    l'indice STOCKÉ est tout de même servi) est réalisé par la surface de
//    saisie, qui vit dans un AUTRE paquet — celui-ci ne peut pas en dépendre
//    sans inverser le sens des dépendances (invariant AD-1). Le contrat, lui,
//    vit ici : ce fichier fige donc que la règle reste ÉNONCÉE sur le port.
//    Portée déclarée honnêtement : cette garde prouve que la phrase est là,
//    jamais que le comportement l'est.
//
//  · Règle « la borne basse est une note écrite » : le comportement est gardé
//    par `z_min_quality_written_note_test.dart` (mesures réelles). Ce qu'aucun
//    test de comportement n'attrape, c'est la disparition de l'AVERTISSEMENT
//    au consommateur — or c'est précisément ce que le socle avait à livrer :
//    un hôte dont l'échelle persistée n'a pas de `0` n'a AUCUN signal
//    d'exécution, il n'a que cette documentation.
//
// Les motifs sont volontairement lâches (des fragments porteurs, pas des
// phrases entières) : une reformulation reste possible, la SUPPRESSION du
// sens ne l'est pas.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du dépôt (dossier portant `melos.yaml`), quel que soit le CWD.
///
/// Remontée, jamais un `../` relatif : un chemin relatif dépend de l'endroit
/// d'où le harnais est lancé et rendrait la garde verte par accident.
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  for (var i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError(
    'Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}',
  );
}

/// Dartdoc du BLOC qui précède immédiatement [anchor] dans [relative].
///
/// Bloc, jamais le fichier entier : `z_srs_config.dart` parle de « facteur de
/// facilité » dans quatre autres dartdocs — une recherche à l'échelle du
/// fichier resterait donc verte après suppression du paragraphe gardé. Une
/// garde qui ne peut pas rougir ne garde rien.
///
/// Seules les lignes `///` comptent : la règle doit vivre dans la
/// documentation PUBLIÉE au consommateur, pas dans un commentaire
/// d'implémentation que dartdoc ne rend pas.
String _dartdocBlockBefore(String relative, Pattern anchor) {
  final file =
      File('${_repoRoot().path}/packages/zcrud_flashcard/$relative');
  if (!file.existsSync()) {
    // `fail`/`expect` sont interdits hors d'un corps de test (le chargement du
    // fichier lèverait `OutsideTestException` et masquerait TOUTES les gardes).
    throw StateError('fichier gardé introuvable : $relative');
  }
  final List<String> lines = file.readAsLinesSync();
  final int at = lines.indexWhere((String l) => l.trimLeft().startsWith(anchor));
  if (at < 0) {
    throw StateError('ancre introuvable dans $relative : $anchor');
  }
  final List<String> block = <String>[];
  for (var i = at - 1; i >= 0; i--) {
    final String t = lines[i].trimLeft();
    if (!t.startsWith('///')) break;
    block.insert(0, t.substring(3).trim());
  }
  if (block.isEmpty) {
    throw StateError('aucune dartdoc au-dessus de $anchor dans $relative');
  }
  return block.join(' ');
}

/// Un fragment attendu + ce que sa disparition coûterait.
class _Required {
  const _Required(this.what, this.why, this.regex);

  /// Forme lisible dans le message d'échec.
  final String what;

  /// Ce que l'appelant perd si la règle disparaît.
  final String why;

  /// Motif ancré (jamais un `contains` nu).
  final RegExp regex;
}

void main() {
  group('ZFlashcardHintPort — le port est OPTIONNEL, la règle est écrite', () {
    const String source = 'lib/src/domain/z_flashcard_hint_port.dart';
    // La règle est portée par la dartdoc de BIBLIOTHÈQUE (le contrat d'ordre),
    // là où un intégrateur qui ouvre le port la lit en premier.
    const String anchor = 'library;';

    final List<_Required> required = <_Required>[
      _Required(
        'sans port ⇒ indice STOCKÉ conservé',
        'un appelant conclurait qu\'aucun indice n\'est offert sans port, et '
            'implémenterait un port dont il n\'a pas besoin',
        RegExp(r'sans (lui|port|impl[ée]mentation)[^.]{0,160}stock',
            dotAll: true, caseSensitive: false),
      ),
      _Required(
        'sans port ⇒ seule la GÉNÉRATION est perdue',
        'la perte réelle (les indices suivants) ne serait plus bornée, et '
            'toute panne d\'indice serait imputée au socle',
        RegExp(r'g[ée]n[ée]rat\w*[^.]{0,80}perdue?',
            dotAll: true, caseSensitive: false),
      ),
    ];

    for (final _Required r in required) {
      test('la dartdoc porte : ${r.what}', () {
        // Lecture DANS le corps du test : hors corps, un échec de lecture
        // ferait tomber le chargement du fichier, pas la garde.
        expect(
          r.regex.hasMatch(_dartdocBlockBefore(source, anchor)),
          isTrue,
          reason: 'Règle DISPARUE de la dartdoc du port : ${r.what}.\n'
              'Conséquence : ${r.why}.',
        );
      });
    }
  });

  group('ZSrsConfig.minQuality — la borne basse est une note ÉCRITE', () {
    const String source = 'lib/src/domain/z_srs_config.dart';
    const String anchor = 'final int minQuality;';

    final List<_Required> required = <_Required>[
      _Required(
        'le remède explicite `minQuality: 1`',
        'un hôte dont l\'échelle persistée n\'a pas de 0 ne saurait pas quoi '
            'déclarer, et découvrirait la perte en base',
        RegExp(r'minQuality:\s*1'),
      ),
      _Required(
        'le coût de la bascule (facteur de facilité)',
        'la bascule passerait pour gratuite alors qu\'elle déplace toutes '
            'les échéances ultérieures',
        RegExp(r'facteur de\s+facilit[ée]', dotAll: true),
      ),
    ];

    for (final _Required r in required) {
      test('la dartdoc porte : ${r.what}', () {
        // Lecture DANS le corps du test : hors corps, un échec de lecture
        // ferait tomber le chargement du fichier, pas la garde.
        expect(
          r.regex.hasMatch(_dartdocBlockBefore(source, anchor)),
          isTrue,
          reason: 'Règle DISPARUE de la dartdoc de minQuality : ${r.what}.\n'
              'Conséquence : ${r.why}.',
        );
      });
    }
  });
}
