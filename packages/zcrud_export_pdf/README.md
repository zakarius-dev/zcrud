# zcrud_export_pdf

Export PDF neutre pour zcrud (gabarits flashcards, documents tabulaires,
assemblage d'images) — sans aucune dépendance tableur.

## Aperçu {#apercu}

`zcrud_export_pdf` isole tout ce qui produit un PDF depuis
`zcrud_export`, pour qu'un hôte n'exportant que du PDF n'ait pas à tirer
`syncfusion_flutter_xlsio` (et ses transitifs `syncfusion_officecore`,
`jiffy`). `zcrud_export` réexporte intégralement ce paquet en y ajoutant
l'Excel : aucun consommateur existant n'est affecté par cette séparation.

Le paquet fournit trois familles de capacités, toutes derrière une API
100 % neutre (bytes en entrée/sortie, jamais un type Syncfusion) :

- **Export tabulaire** — `buildPdfBytes` transforme une `ZExportTable`
  neutre en document PDF, avec anti-rognage horizontal et en-tête riche
  optionnel (logo, hiérarchie organisationnelle, sous-titre).
- **Gabarit flashcards** — `ZFlashcardPdfTemplate` compose texte et LaTeX
  **inline** dans le flux du document, avec repli robuste sur le texte
  brut pour toute formule non rasterisée, et une chaîne de polices pour
  couvrir plusieurs écritures dans un même document.
- **Assemblage d'images** — `ZPdfCreationService`/`buildImagesPdf`
  transforment une liste de bytes d'images en un document PDF multi-pages,
  et `ZFileSaver` sauvegarde n'importe quel export sur disque ou déclenche
  un téléchargement navigateur, selon la plateforme.

**Utilisez ce paquet** pour tout export PDF — tabulaire, flashcards, ou
assemblage d'images — sans dépendance tableur. **N'utilisez pas ce paquet**
si vous avez aussi besoin d'Excel : dépendez alors de `zcrud_export`, qui
réexporte celui-ci intégralement.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'dart:typed_data';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

Uint8List exportTablePdf() {
  final request = ZListRenderRequest.fromSchema(
    const [ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Name')],
    const [ZListRow(id: '1', cells: {'name': 'Ada'})],
  );
  final table = ZExportTable.fromRequest(request);
  return buildPdfBytes(
    table,
    options: const ZPdfExportOptions(
      header: ZPdfHeaderSpec(organizationLines: ['Ma structure']),
    ),
  );
}
```

## Concepts clés {#concepts-cles}

- **Isolation Syncfusion (invariants [AD-1](../../docs/site/concepts/invariants.md#ad-1)/[AD-8](../../docs/site/concepts/invariants.md#ad-8))** —
  `syncfusion_flutter_pdf` est confiné aux implémentations concrètes ; aucune
  signature publique ne porte un type `PdfDocument`/`PdfGrid`/`PdfBitmap`.
- **En-tête riche rétrocompatible** — `ZPdfExportOptions.header` (voir
  `ZPdfHeaderSpec`) est un ajout purement additif : `options == null` ou
  `options.header == null` reproduit bit pour bit le rendu historique
  (titre seul, sans logo).
- **Chaîne de polices pour l'Unicode** — sans `fontProvider`, seule la
  police WinAnsi standard est utilisée (latin-1 seulement, tout autre
  caractère devient `?`, visible plutôt qu'un `.notdef` silencieux). Une
  chaîne de `ZPdfFontProvider` (`fontProvider` + `fallbackFontProviders`)
  couvre plusieurs écritures dans un même document, chaque suite de
  caractères étant peinte avec la première police qui la porte.
- **Aucune perte silencieuse de contenu** — la composition inline
  texte/LaTeX réémet toujours les délimiteurs `$` en repli, et un saut de
  ligne dans un mot produit un véritable retour à la ligne plutôt que de
  faire disparaître le texte hors du rectangle de dessin.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `buildPdfBytes` / `ZExportTable` | Export tabulaire neutre : table de chaînes → bytes PDF. |
| `ZPdfExportOptions` / `ZPdfHeaderSpec` / `ZPdfOrientation` | Options de mise en page (orientation, titre, en-tête riche). |
| `ZFlashcardPdfTemplate` | Gabarit PDF flashcards, composition inline texte + LaTeX. |
| `ZFlashcardPdfInput` / `ZFlashcardPdfCard` / `ZFlashcardPdfChoice` / `ZFlashcardPdfLabels` | Entrée neutre et libellés injectés du gabarit flashcards. |
| `ZAnswerVisibility` | Mode d'affichage des réponses (`withAnswers` / `withoutAnswers`). |
| `ZLatexRasterizer` | Port pur de rastérisation LaTeX, implémenté dans `zcrud_export_ui`. |
| `ZPdfFontProvider` | Port de fourniture d'une police TrueType, pour dépasser le latin-1. |
| `ZFontCoverage` | Lecture de la couverture réelle d'une police via sa table `cmap`. |
| `ZPdfCreationService` / `buildImagesPdf` | Assemblage d'une liste d'images en document PDF multi-pages. |
| `ZExportedFile` | Triplet neutre `{bytes, fileName, mimeType}` produit par un export. |
| `ZFileSaver` / `ZFileSaveResult` | Sauvegarde cross-plateforme (disque ou téléchargement navigateur). |

## Cas limites et invariants {#cas-limites}

- Une table ou un dossier vide produit toujours un document PDF **valide**
  d'au moins une page — jamais un fichier vide ni une exception.
- Une carte flashcard malformée, un LaTeX invalide, ou un logo d'en-tête non
  décodable dégradent proprement (repli texte brut ou omission) sans faire
  échouer l'export entier (invariant AD-10).
- `PdfDocument.dispose()` est toujours appelé en `finally`, sur tous les
  chemins, y compris les chemins vides ou en exception — aucune fuite de
  ressource native.
- `ZFileSaver` ne fait fuir aucun symbole `dart:io`/`package:web` dans sa
  signature ; la sélection d'implémentation se fait par import conditionnel
  à la compilation.

## Voir aussi {#voir-aussi}

- [zcrud_export](../zcrud_export/README.md) — façade combinée Excel + PDF
  qui réexporte intégralement ce paquet.
- [zcrud_export_ui](../zcrud_export_ui/README.md) — implémentation concrète
  du port `ZLatexRasterizer`, et l'aperçu/impression/partage des bytes PDF.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
