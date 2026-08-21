/// Couture **NEUTRE, pur-Dart** de construction d'une op embed **tableau**
/// (COMBLEMENT).
///
/// ## Pourquoi ce fichier existe (l'« écart révélé par la migration »)
///
/// L'embed tableau vit dans `presentation/z_table_embed.dart`, un fichier
/// **Flutter/Quill** : la SEULE façon d'y CONSTRUIRE l'op passe par le dialogue
/// utilisateur `showZTableDialog`. Le migrateur (`zcrud_note`) a besoin de
/// fabriquer la même op **programmatiquement, sans Flutter** — à partir de données
/// structurées. Plutôt que de **dupliquer** le contrat `{table:{rows,columns,cells}}`
/// dans `zcrud_note` (violation), on le comble **ICI**, dans le package
/// d'origine, et [kTableEmbedType] devient la **source UNIQUE** partagée par le
/// builder de rendu (`z_table_embed.dart`) **et** le migrateur.
///
/// ## Contrat & isolation (AD-1/AD-4/AD-7)
///
/// - **PUR-DART** : ce fichier n'importe **AUCUN** `package:flutter*` ni
///   `package:flutter_quill*`. Il ne dépend que de `zcrud_core` (surface pure
///   `domain.dart`, pour le gel PROFOND). C'est ce qui le rend réutilisable par un
///   domaine/adaptateur pur-Dart.
/// - La valeur produite est une **`Map` opaque JSON-safe** (jamais un type Quill) —
///   exactement l'op Delta `{"insert": {"table": <structure>}}` que
///   `ZTableEmbedBuilder` rend défensivement (AD-10).
/// - Le barrel n'exporte que [zTableEmbedOp] + [kTableEmbedType] — **jamais**
///   `ZTableEmbed`/`ZTableEmbedBuilder` (isolation épinglée par
///   `quill_signature_isolation_test.dart`).
library;

import 'package:zcrud_core/domain.dart';

/// Type Delta de l'embed tableau — op `{"insert": {"table": <structure>}}`.
///
/// **SOURCE UNIQUE** du contrat : `z_table_embed.dart` (rendu) et le
/// migrateur (`zcrud_note`) l'importent **d'ici**, jamais en dur.
const String kTableEmbedType = 'table';

/// Type Delta de l'embed tableau **LEGACY** — op
/// `{"insert": {"x-embed-table": "<markdown>"}}`.
///
/// Forme legacy MESURÉE : la clé est `x-embed-table` et la charge un
/// **string Markdown** (tableau GFM). zcrud le RECONNAÎT EN LECTURE (rendu +
/// pré-remplissage d'édition) ; toute ÉCRITURE reste sur [kTableEmbedType]
/// (`{rows,columns,cells}`) — migration à SENS UNIQUE (le legacy ne relit pas
/// le contenu réécrit par zcrud).
const String kLegacyTableEmbedType = 'x-embed-table';

/// Clé du nombre de lignes dans la structure JSON-safe de l'embed tableau.
const String kTableRowsKey = 'rows';

/// Clé du nombre de colonnes dans la structure JSON-safe de l'embed tableau.
const String kTableColumnsKey = 'columns';

/// Clé de la matrice `cells` (source de vérité) de l'embed tableau.
const String kTableCellsKey = 'cells';

/// Fabrique **NEUTRE** l'op embed tableau à partir de la matrice [cells].
///
/// Produit exactement :
/// `{'insert': {kTableEmbedType: {rows: R, columns: C, cells: <copie>}}}`
///
/// - **JSON-safe & non modifiable** : la valeur est gelée en PROFONDEUR
///   ([zUnmodifiableJsonMapList]) — aucun caller ne peut muter la structure.
/// - **JAMAIS jagged** : les lignes plus courtes que la largeur max sont
///   **paddées** de cellules `''` AVANT production, de sorte que l'op est
///   TOUJOURS rectangulaire (rendable par `ZTableEmbedBuilder._parseTable`, qui
///   rejette les matrices irrégulières). `columns` = largeur max ; `rows` =
///   nombre de lignes.
///
/// > La décision de **structurer ou non** un bloc legacy (table valide vs texte à
/// > préserver) appartient à l'appelant (le migrateur) : cette fabrique
/// > ne fait que garantir qu'une op PRODUITE est toujours saine.
Map<String, dynamic> zTableEmbedOp({required List<List<String>> cells}) {
  var width = 0;
  for (final List<String> row in cells) {
    if (row.length > width) width = row.length;
  }
  final List<List<String>> normalized = <List<String>>[
    for (final List<String> row in cells)
      <String>[
        for (var i = 0; i < width; i++) i < row.length ? row[i] : '',
      ],
  ];
  final Map<String, dynamic> op = <String, dynamic>{
    'insert': <String, dynamic>{
      kTableEmbedType: <String, dynamic>{
        kTableRowsKey: normalized.length,
        kTableColumnsKey: width,
        kTableCellsKey: normalized,
      },
    },
  };
  // Gel PROFOND (liste → op → valeurs imbriquées) : valeur neutre non modifiable.
  return zUnmodifiableJsonMapList(<Map<String, dynamic>>[op]).single;
}
