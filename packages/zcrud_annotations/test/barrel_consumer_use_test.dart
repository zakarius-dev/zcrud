// Position exacte d'un modèle de paquet CONSOMMATEUR : le barrel des
// annotations est le SEUL import. La compilation de ce fichier fait partie de la
// garde — si `ZFieldRename` cesse d'être nommable ici, il ne l'est plus non plus
// dans les modèles des hôtes, et leur `fieldRename:` redevient une constante
// nulle au générateur.
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';

void main() {
  test('`fieldRename` est renseignable sans importer `zcrud_core`', () {
    const m = ZcrudModel(kind: 'article', fieldRename: ZFieldRename.kebab);
    expect(m.fieldRename, ZFieldRename.kebab);
    expect(
      ZFieldRename.values.map((v) => v.name),
      containsAll(<String>['none', 'snake', 'kebab', 'pascal']),
    );
  });
}
