@TestOn('vm')
// ⚠️ `@TestOn('vm')` : garde STRUCTURELLE qui inspecte le DISQUE (`dart:io`) —
// elle ne compile pas vers le web, où `gate:web` exécute ce paquet.
library;

// Le barrel doit rendre nommable TOUT type qui apparaît dans la signature d'une
// annotation qu'il exporte. À défaut, le paramètre existe mais reste
// inutilisable depuis une bibliothèque qui n'importe que ce barrel : l'argument
// écrit ne se résout pas, et le générateur ne voit pas une erreur de
// compilation — il voit une constante NULLE, donc un échec de build.
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('barrel : les types des signatures d\'annotation sont nommables', () {
    test(
      '`ZFieldRename` (type de `@ZcrudModel.fieldRename`) est ré-exporté',
      () {
        final barrel = File('lib/zcrud_annotations.dart').readAsStringSync();
        expect(
          barrel,
          contains(
            "export 'package:zcrud_core/edition.dart' show ZFieldRename;",
          ),
          reason:
              'sans cette ré-exportation, `fieldRename:` n\'est renseignable '
              'qu\'en important AUSSI un barrel de `zcrud_core`',
        );
      },
    );
  });
}
