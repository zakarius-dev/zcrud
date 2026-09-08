@TestOn('vm')
library;

// Ce paquet est un porteur de VALEURS. Un widget ici créerait un second rendu,
// concurrent de celui des paquets d'écrans — le doublon exact qu'une boîte à
// outils partagée existe pour supprimer. La garde lit les SOURCES plutôt que
// d'inspecter les symboles à l'exécution : un widget déclaré mais non instancié
// serait invisible à toute inspection dynamique, et c'est précisément ce qu'on
// veut interdire.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'z_package_root.dart';

/// Motifs qui trahissent la déclaration d'un widget ou d'un rendu.
const List<String> _forbidden = <String>[
  'extends StatelessWidget',
  'extends StatefulWidget',
  'extends InheritedWidget',
  'extends RenderObjectWidget',
  'extends Widget',
  'extends State<',
  'Widget build(',
];

void main() {
  test('aucun fichier de lib/ ne déclare de widget ni de méthode build', () {
    final List<File> sources = zThemesLibSources();
    expect(sources, isNotEmpty,
        reason: 'lib/ vide : la garde ne mesurerait rien.');

    final List<String> offences = <String>[];
    for (final File file in sources) {
      final List<String> lines = file.readAsLinesSync();
      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        // Les dartdoc et les commentaires citent ces motifs pour les
        // INTERDIRE : les compter serait une garde qui défend le défaut.
        final String stripped = line.trimLeft();
        if (stripped.startsWith('//') || stripped.startsWith('///')) continue;
        for (final String pattern in _forbidden) {
          if (line.contains(pattern)) {
            offences.add('${file.path}:${i + 1}: $pattern');
          }
        }
      }
    }
    expect(
      offences,
      isEmpty,
      reason: 'Ce paquet ne rend AUCUN widget. Trouvé :\n${offences.join('\n')}',
    );
  });

  test('le barrel n\'importe aucun paquet de rendu de widgets', () {
    final File barrel =
        File('${zThemesPackageRoot().path}/lib/zcrud_themes.dart');
    expect(barrel.existsSync(), isTrue);
    final String text = barrel.readAsStringSync();
    // Le barrel n'exporte que des fichiers de ce paquet : aucun ré-export
    // d'un paquet d'écrans, qui ferait entrer des widgets par la bande.
    final Iterable<RegExpMatch> exports =
        RegExp(r"export\s+'([^']+)'").allMatches(text);
    expect(exports, isNotEmpty);
    for (final RegExpMatch m in exports) {
      expect(
        m.group(1)!.startsWith('src/'),
        isTrue,
        reason: 'Ré-export hors du paquet : ${m.group(1)}',
      );
    }
  });
}
