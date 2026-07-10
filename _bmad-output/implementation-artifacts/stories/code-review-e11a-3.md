# Code Review — E11a-3 : zcrud_export (DataGrid → Excel/PDF, Syncfusion isolé)

- **Story** : `stories/e11a-3-zcrud-export-datagrid-excel-pdf.md` (11 ACs, statut `review`)
- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chemin skill, PAS le fallback disque).
- **Reviewer** : agent adversarial (Blind Hunter + Edge Case Hunter + Acceptance Auditor, exécution mono-session).
- **Baseline** : `fe203b90bb95a659063452af4cf584f66e7bab0f`.
- **Périmètre relu** : `lib/src/data/{z_exporter,z_export_table,z_excel_exporter,z_pdf_exporter}.dart`, barrel `lib/zcrud_export.dart`, `pubspec.yaml`, `test/{z_exporter_test,isolation_gates_test}.dart` + contrat cœur (`z_list_column.dart`, `z_list_render_request.dart`) et renderer écran `zcrud_list/…/z_sf_data_grid_renderer.dart` (parité).

## Verdict global : GO (aucun finding HIGH / MAJEUR / MEDIUM)

Story propre et bien exécutée. Isolation Syncfusion réelle et structurellement prouvée, zéro secret / zéro badcert, parité écran/fichier vérifiée sur la MÊME expression que le renderer écran, tests vérifiant le CONTENU réel des fichiers, défensif complet, dispose en `try/finally`. Seuls quelques LOW/nits, non bloquants.

---

## Vérifications adversariales (résultats)

| Axe | Verdict | Preuve |
|---|---|---|
| Isolation Syncfusion (AD-1/AD-8/SM-5) | **OUI** | xlsio/pdf déclarés au SEUL `zcrud_export/pubspec.yaml` (l.32-33) ; imports confinés à `z_excel_exporter.dart`/`z_pdf_exporter.dart` ; barrel n'exporte que `ZExporter`/`ZExportTable` (aucun symbole Syncfusion) ; sortie `Uint8List` → fuite de type structurellement impossible ; `isolation_gates_test` vérifie core-sans-lib + aucun-autre-package + barrel + confinement + signature ; `graph_proof.py` CORE OUT=0. Transitivité garantie par construction (seul `zcrud_export` porte l'arête). |
| No-secret / no-badcert (AD-12) | **OUI** | Aucun `SyncfusionLicense.registerLicense(` ni `badCertificateCallback` dans le code (uniquement en prose de doc-comment, comme contre-exemples) ; `isolation_gates_test` strip-comment + regex négatives ; gate:secrets (`gate_secret_scan.dart`) rejoué. Licence déléguée à l'app hôte, documentée. |
| Parité format écran/fichier (SM-5) | **OUI** | `ZExportTable.fromRequest` : cellule = `col.format(row.cells[col.name])` (z_export_table.dart:49) — **exactement** l'expression du renderer écran `z_sf_data_grid_renderer.dart:266`. Source unique de formatage (cœur), zéro duplication. Testé : select→libellé (`Ouvert`), tags→join `', '` (`a, b`), dateTime→ISO. |
| Tests vérifient le CONTENU réel | **OUI** | Excel : ré-ouverture ZIP (`package:archive`) → décode `xl/worksheets/*` + `sharedStrings.xml`, assert présence en-têtes + valeurs formatées. PDF : `PdfTextExtractor` → assert présence en-têtes + valeurs. Non tautologique (pas seulement bytes non-null). |
| Défensif (AD-10) | **OUI** | rows vides→en-têtes seuls ; columns vides→xlsx feuille vide + PDF page vide (garde `headers.isNotEmpty` z_pdf_exporter.dart:37) ; clé absente/null→`format(null)`→`''` ; tout vide→valide. Chaque sous-liste de `rows` a toujours `headers.length` cellules (projection par colonnes) → jamais d'index out-of-range dans les backends. Table de cas `returnsNormally`. |
| Anti-fuite dispose | **OUI** | `Workbook.dispose()` (z_excel_exporter.dart:52) et `PdfDocument.dispose()` (z_pdf_exporter.dart:64) en `finally` — chemin nominal + vide + exception. |
| Frontière E11a-3 (pas d'anticipation E11b) | **OUI** | Strictement `packages/zcrud_export/` ; tableau simple ; aucun style/pagination riche/flashcard PDF ; `zcrud_core` non modifié (confirmé) ; zcrud_intl/zcrud_markdown/example non touchés. |

---

## Findings

### HIGH / MAJEUR
_Néant._

### MEDIUM
_Néant._

### LOW / nits (optionnels — consignés)

**L1 — PDF : débordement horizontal des tables larges (non-fit en largeur).**
`z_pdf_exporter.dart:56-59` — `grid.draw(bounds: Rect.fromLTWH(0,0,width,height))` sans mode d'ajustement de largeur. `PdfGrid.draw` auto-pagine **verticalement** (aucune perte de lignes), mais avec beaucoup de colonnes la grille dépasse la largeur de page et les cellules de droite sont **rognées**. Impact : lisibilité d'un export à nombreuses colonnes ; possible écart de parité si l'export DODLP hérité ajustait les colonnes. Relève très probablement de la **mise en page riche = E11b** (frontière explicite de la story). Remède (E11b) : `PdfLayoutFormat` / répartition de largeur, ou orientation paysage.

**L2 — Gate signature : allowlist de fichiers publics codée en dur.**
`test/isolation_gates_test.dart:144-148` — le contrôle « aucun type Syncfusion en signature publique » n'inspecte que 3 fichiers (`z_exporter`, `z_export_table`, barrel). Un futur fichier public **neutre** ajouté sous `lib/` échapperait à ce contrôle précis. Risque atténué (couvert par le test « imports Syncfusion confinés aux backends » : tout nouveau fichier important Syncfusion hors backend échoue déjà). Remède : dériver la liste dynamiquement (tous les `.dart` de `lib/` hors `z_*_exporter.dart`).

**L3 — `_code()` tronque au premier `//` de ligne.**
`test/isolation_gates_test.dart:59-68` — le strip-comment coupe à la 1re occurrence de `//`, ce qui tronquerait un futur littéral de chaîne contenant `//` (ex. un endpoint `https://…`) et affaiblirait le scan-secret **de ce test**. L'assertion actuelle repose sur l'hypothèse documentée « aucun `//` en littéral ». Non bloquant : le gate autoritatif `gate:secrets` (`gate_secret_scan.dart`) tourne indépendamment. Remède : strip conscient des chaînes, ou s'appuyer uniquement sur le gate central.

**L4 — Assertions Excel faibles sur tokens courts.**
`test/z_exporter_test.dart:107,113` — `contains('age')` / `contains('30')` peuvent matcher des sous-chaînes incidentes du XML (attributs, ids de style). Les tokens distinctifs (`Nom`, `Statut`, `Alice`, `Ouvert`, `a, b`, ISO date) portent la valeur du test ; nit de robustesse. Remède : cibler la balise `<t>…</t>` de sharedStrings.

---

## Notes de conformité (non-findings, vérifiés)

- **Excel `setText` pour toutes les cellules** : volontaire pour la parité (l'écran affiche la String formatée) ; typage numérique/date natif = E11b. Conforme, pas un défaut. Pas d'injection de formule (`setText` force le type texte).
- **`resolveHeader` défaut identité** : en-têtes = clé l10n brute si l'app utilise des clés ; hook documenté prévu exactement pour ça (parité résolue par l'app, headless sans `BuildContext`). Contrat conforme.
- **`archive` en dev_dependency** : test-only, aucune fuite runtime. Correct.
- **`zcrud_core` non modifié** : confirmé ; aucune sérialisation de fichier core en conflit avec E6/E11a-2.

## Recommandation

Findings LOW uniquement, tous optionnels/déférables (L1→E11b ; L2/L3/L4 = durcissement de tests). **Aucune correction obligatoire avant `done`.** Transition `review → done` autorisée (édition ciblée du sprint-status par l'orchestrateur).

---

## Décision orchestrateur (2026-07-10)

0 HIGH/MAJEUR/MEDIUM → **aucune remédiation requise**. Les 4 LOW sont **consignés/déférés** :
- LOW-1 (PDF tables larges rognées) → **E11b** (mise en page riche, v1.x).
- LOW-2/3 (durcissement des gates d'isolation en test) → nits, gate:secrets central reste autoritatif.
- LOW-4 (assertions sur tokens courts) → nit de robustesse de test.

**Vérif verte rejouée (orchestrateur, ciblée zcrud_export)** : `flutter analyze` **0 issue** · `flutter test` **19/19** (contenu réel vérifié via `archive`/`PdfTextExtractor`) · core sans Syncfusion · **CORE OUT=0**. Story E11a-3 → **done**.
