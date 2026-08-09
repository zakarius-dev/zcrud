/// Sérialiseur d'arbre partagé par les gardes d'IDENTITÉ (patron
/// `zChatSerializeTree` de `zcrud_chat`, CR-LEX-78).
///
/// Il imprime, pour chaque nœud : le type, les libellés, les marges, les
/// contraintes, les alignements, les styles de texte et les drapeaux
/// sémantiques. Déterministe sous `flutter_test` à surface fixée.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sérialise le sous-arbre de widgets sous [root].
String zSerializeTree(WidgetTester tester, Finder root) {
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
      final SemanticsProperties p = w.properties;
      line.write(
        ' sem[label=${p.label} btn=${p.button} en=${p.enabled}'
        ' hdr=${p.header} cont=${w.container}]',
      );
    }
    if (w is SafeArea) {
      line.write(' safe=${w.top}/${w.bottom}/${w.left}/${w.right}');
    }
    if (w is Flex) line.write(' axis=${w.direction} mas=${w.mainAxisSize}');
    // CR-IFFD-SHEET (2026-08-09) : le CADRE de la feuille est porté par la
    // `shape` du `BottomSheet` (peinte par son `Material`), pas par un nœud
    // supplémentaire. Sans cette ligne, l'étalon d'arbre serait AVEUGLE au
    // cadre — il pourrait disparaître sans qu'ID-1 ne rougisse.
    if (w is BottomSheet) line.write(' shape=${w.shape}');
    out.writeln(line);
    element.visitChildren((Element child) => visit(child, depth + 1));
  }

  visit(tester.element(root), 0);
  return out.toString();
}
