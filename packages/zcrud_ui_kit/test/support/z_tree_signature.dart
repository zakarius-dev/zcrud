/// Signature d'arbre **stricte** partagée par les gardes d'inertie.
///
/// Une garde d'inertie qui affirme `contains` ou `<=` ne mord pas : elle reste
/// verte quand un widget s'ajoute. [zTreeSignature] rend donc une empreinte
/// **totale** du sous-arbre — type de chaque widget, dans l'ordre, avec les
/// propriétés qui décident du pixel (taille et couleur d'icône, style et
/// alignement de texte, hauteur d'espaceur, retrait, axe de colonne, libellé
/// sémantique). L'égalité stricte contre une empreinte figée AVANT
/// modification est la seule forme qui rougisse au premier écart.
///
/// La descente s'arrête aux feuilles de rendu ([Icon], [Text]) et aux boutons
/// Material : leur expansion interne appartient au framework, pas à nous, et
/// la figer transformerait la garde en test du SDK.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Types dont on n'explore pas l'expansion interne.
bool _isLeaf(Widget w) =>
    w is Icon ||
    w is Text ||
    w is TextButton ||
    w is FilledButton ||
    w is ElevatedButton ||
    w is OutlinedButton ||
    w is CircularProgressIndicator;

String _describe(Widget w) {
  if (w is Icon) {
    return 'icon=${w.icon?.codePoint} size=${w.size} color=${w.color}';
  }
  if (w is Text) {
    return 'data=${w.data} align=${w.textAlign} style=${w.style}';
  }
  if (w is SizedBox) return 'w=${w.width} h=${w.height}';
  if (w is Padding) return 'pad=${w.padding}';
  if (w is Column) {
    return 'main=${w.mainAxisSize} cross=${w.crossAxisAlignment}';
  }
  if (w is Semantics) {
    return 'label=${w.properties.label} container=${w.container}';
  }
  if (w is AlertDialog) {
    return 'shape=${w.shape} titleTextStyle=${w.titleTextStyle} '
        'contentTextStyle=${w.contentTextStyle} '
        'actionsPadding=${w.actionsPadding} icon=${w.icon?.runtimeType}';
  }
  return '';
}

/// Empreinte totale du sous-arbre enraciné en [root].
String zTreeSignature(WidgetTester tester, Finder root) {
  final StringBuffer out = StringBuffer();
  void visit(Element el, int depth) {
    final Widget w = el.widget;
    final String extra = _describe(w);
    out.writeln(
      '${'  ' * depth}${w.runtimeType}${extra.isEmpty ? '' : ' [$extra]'}',
    );
    if (_isLeaf(w)) return;
    el.visitChildren((Element child) => visit(child, depth + 1));
  }

  visit(tester.element(root), 0);
  return out.toString();
}
