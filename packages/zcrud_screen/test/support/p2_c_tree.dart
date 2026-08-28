/// Sérialiseur d'arbre + étalons figés des gardes d'INERTIE de `zcrud_screen`.
///
/// Patron repris de `zcrud_navigation/test/support/z_edition_tree_serializer.dart`
/// (garde d'identité d'arbre de `presentEdition`) : chaque nœud imprime son
/// type, ses libellés, ses marges, ses contraintes, ses alignements et ses
/// drapeaux sémantiques. Déterministe sous `flutter_test` à surface fixée.
///
/// L'exigence des gardes qui s'en servent n'est pas « équivalent » : elle est
/// **identique, nœud pour nœud**. Les étalons ont été relevés sur le code
/// AVANT l'ajout des passe-plats de présentation et de l'état vide injectable,
/// puis versionnés à côté de ce fichier.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sérialise le sous-arbre de widgets sous [root].
String p2cSerializeTree(WidgetTester tester, Finder root) {
  final StringBuffer out = StringBuffer();
  void visit(Element element, int depth) {
    final Widget w = element.widget;
    final StringBuffer line = StringBuffer('${'  ' * depth}${w.runtimeType}');
    if (w is Text) line.write(' text=${w.data} align=${w.textAlign}');
    if (w is RichText) {
      final TextStyle? s = w.text.style;
      line.write(
        ' rich=${w.text.toPlainText()} w=${s?.fontWeight} d=${s?.decoration}',
      );
    }
    if (w is Padding) line.write(' p=${w.padding}');
    if (w is SizedBox) line.write(' sz=${w.width}x${w.height}');
    if (w is ConstrainedBox) line.write(' c=${w.constraints}');
    if (w is Align) {
      line.write(' a=${w.alignment} wf=${w.widthFactor} hf=${w.heightFactor}');
    }
    if (w is Semantics) {
      final p = w.properties;
      line.write(
        ' sem[label=${p.label} btn=${p.button} en=${p.enabled}'
        ' hdr=${p.header} cont=${w.container}]',
      );
    }
    if (w is SafeArea) {
      line.write(' safe=${w.top}/${w.bottom}/${w.left}/${w.right}');
    }
    if (w is Flex) line.write(' axis=${w.direction} mas=${w.mainAxisSize}');
    if (w is BottomSheet) line.write(' shape=${w.shape}');
    if (w is Scaffold) line.write(' fab=${w.floatingActionButton != null}');
    out.writeln(line);
    element.visitChildren((Element child) => visit(child, depth + 1));
  }

  visit(tester.element(root), 0);
  return out.toString();
}

/// Compare [actual] à l'étalon versionné [path] (relatif au dossier du
/// package — convention `melos exec` : `flutter test` se lance depuis
/// `packages/zcrud_screen`).
///
/// Étalon **absent** ⇒ il est écrit puis la garde ÉCHOUE : un étalon effacé ne
/// peut pas se régénérer en silence sous un rendu qui aurait changé.
void p2cExpectFrozenTree(String path, String actual, {required String what}) {
  final File file = File(path);
  if (!file.existsSync()) {
    file.writeAsStringSync(actual);
    fail('Étalon absent : $path vient d\'être écrit. Relancez la garde.');
  }
  expect(
    actual,
    file.readAsStringSync(),
    reason: 'INERTIE ROMPUE — l\'arbre de $what diffère de l\'étalon $path.',
  );
}
