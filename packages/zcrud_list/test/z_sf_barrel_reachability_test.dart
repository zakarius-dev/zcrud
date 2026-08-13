// ATTEIGNABILITÉ de l'API publique depuis le SEUL barrel du paquet.
//
// Ce fichier n'importe **que** `package:zcrud_list/zcrud_list.dart` (plus
// Flutter, qui n'est pas un backend) : aucun `import` de
// `package:syncfusion_flutter_datagrid/...`. C'est volontaire — il mesure
// qu'un hôte peut écrire tous les paramètres publics du renderer, y compris
// l'échappatoire documentée du mode de largeur
// (`columnWidthMode: ColumnWidthMode.fill`), SANS déclarer lui-même une
// dépendance Syncfusion (invariant AD-8 : ce paquet est la seule arête
// Syncfusion du graphe).
//
// Si le barrel cessait de ré-exporter `ColumnWidthMode`, ce fichier ne
// COMPILERAIT plus : la morsure est une erreur de compilation, pas un échec
// d'assertion.
import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_list/zcrud_list.dart';

void main() {
  group('surface publique écrivable depuis le seul barrel', () {
    test('échappatoire du mode de largeur : columnWidthMode: fill', () {
      // Exactement l'extrait publié dans le CHANGELOG et le README.
      const renderer = ZSfDataGridRenderer(
        columnWidthMode: ColumnWidthMode.fill,
      );
      expect(renderer.columnWidthMode, equals(ColumnWidthMode.fill));
    });

    test('dimensionnement par colonne : widthMode', () {
      const sizing = ZSfColumnSizing(widthMode: ColumnWidthMode.auto);
      expect(sizing.widthMode, equals(ColumnWidthMode.auto));
    });

    test('la règle responsive est comparable à un mode nommé', () {
      expect(
        ZSfDataGridRenderer.responsiveColumnWidthMode(
          visibleColumnCount: 1,
          platform: TargetPlatform.android,
        ),
        equals(ColumnWidthMode.fill),
      );
      expect(
        ZSfDataGridRenderer.responsiveColumnWidthMode(
          visibleColumnCount: 4,
          platform: TargetPlatform.linux,
        ),
        equals(ColumnWidthMode.auto),
      );
    });
  });
}
