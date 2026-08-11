# zcrud_export

Export tabulaire neutre pour zcrud : transforme une requête de rendu de
liste (`zcrud_core`) en bytes Excel (`.xlsx`) via Syncfusion — invariant
[AD-1](../../docs/site/concepts/invariants.md#ad-1) (aucun type Syncfusion ne
fuit dans le cœur ni dans la signature publique).

## Aperçu {#apercu}

`zcrud_export` fournit [ZExporter], la façade neutre de l'export : elle
consomme le contrat de liste du cœur (colonnes dérivées + lignes brutes) et
rend des **bytes** (`Uint8List`), jamais un type Syncfusion. Le backend
`syncfusion_flutter_xlsio` est **confiné** à l'implémentation ; un
consommateur qui n'importe pas ce paquet ne tire aucune dépendance Excel.

Ce paquet réexporte intégralement `zcrud_export_pdf` (assemblage PDF,
sauvegarde cross-platform, gabarit flashcards) et n'ajoute que l'Excel : un
hôte qui n'a besoin que du PDF peut dépendre directement de
`zcrud_export_pdf` et éviter `syncfusion_flutter_xlsio`.

**Utilisez ce paquet** pour exporter un rendu de liste en `.xlsx` ou en PDF
depuis une seule dépendance. **N'utilisez pas ce paquet** si vous n'avez
besoin que du PDF (préférez `zcrud_export_pdf` seul) ni pour choisir la
destination finale du fichier (sélecteur système, partage) : c'est le rôle
de `zcrud_export_ui`.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'dart:typed_data';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

Uint8List exportXlsx() {
  final request = ZListRenderRequest.fromSchema(
    const [ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name')],
    const [ZListRow(id: '1', cells: {'name': 'Ada'})],
  );
  return const ZExporter().toExcelBytes(request); // toPdfBytes pour le PDF
}
```

## Concepts clés {#concepts-cles}

- **Neutralité de signature (invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1))** —
  `ZExporter` prend une `ZListRenderRequest` du cœur et rend un `Uint8List` ;
  aucun `Workbook`/`PdfDocument` n'apparaît jamais dans une signature
  publique. La fuite de type Syncfusion est donc structurellement impossible.
- **Parité écran/fichier** — la valeur d'une cellule exportée est
  `col.format(row.cells[col.name])`, exactement le même formateur pur que le
  rendu `SfDataGrid` de `zcrud_list`. Une seule source de vérité de
  formatage, zéro duplication entre écran et fichier.
- **Licence Syncfusion hors package (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  l'enregistrement de licence (`SyncfusionLicense.registerLicense`) est une
  responsabilité du bootstrap de l'application hôte, jamais de ce package.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZExporter` | Façade d'export neutre et immuable : `toExcelBytes` / `toPdfBytes`. |
| `ZExportApi` | Marqueur de version de l'API publique du paquet. |

Ce barrel réexporte aussi l'intégralité de la surface publique de
`zcrud_export_pdf` (assemblage PDF, sauvegarde de fichier, options de mise en
page, gabarit flashcards) — voir sa propre fiche pour le détail.

## Cas limites et invariants {#cas-limites}

- `columns`/`rows` vides, clé de cellule absente, valeur `null` → cellule ou
  fichier vide mais valide, jamais de crash (invariant AD-10).
- Le classeur Excel est toujours libéré (`dispose()` en `finally`), y compris
  sur un chemin d'export vide ou en cas d'exception : aucune ressource
  native non libérée.
- `resolveHeader` (optionnel) résout la clé l10n de l'en-tête sans
  `BuildContext`, pour un export exécutable hors arbre de widgets.

## Voir aussi {#voir-aussi}

- [zcrud_export_pdf](../zcrud_export_pdf/README.md) — assemblage PDF neutre,
  réexporté intégralement par ce paquet.
- [zcrud_export_ui](../zcrud_export_ui/README.md) — destinations de
  sauvegarde par plateforme.
- [zcrud_list](../zcrud_list/README.md) — rendu écran partageant le même
  formateur de colonne.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
