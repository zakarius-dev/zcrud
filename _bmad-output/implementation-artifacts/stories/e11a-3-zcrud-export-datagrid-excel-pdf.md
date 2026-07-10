---
baseline_commit: fe203b90bb95a659063452af4cf584f66e7bab0f
---

# Story E11a.3 : zcrud_export (sous-ensemble) — export DataGrid → Excel/PDF (Syncfusion, isolé)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant zcrud dans DODLP (banc d'essai parité SM-2)**,
je veux **un service d'export tabulaire qui prend les colonnes dérivées du schéma (`ZListColumn`) + les lignes neutres (`ZListRow`) de la liste et produit un classeur Excel et un document PDF**,
afin que **la fonction d'export de la liste DODLP soit préservée AVANT E7 (E7-4 : « export préservé (E11a-3) ») sans faire fuiter Syncfusion (PDF/Excel) dans `zcrud_core` (AD-1/AD-8/SM-5), sans clé de licence committée ni `badCertificateCallback` (AD-12)**.

## Contexte & cadrage

**Épopée E11a — Lot parité DODLP** (sous-ensemble MVP de geo/intl/export). E11a **précède E7** (le graphe de dépendances prime sur la numérotation) : `E7 dépend de E11a`. Cette story est la **troisième et dernière** d'E11a.

**Périmètre STRICT E11a-3 = export Excel + PDF de la liste UNIQUEMENT.** Frontières explicites :
- **E11a-1** (`done`) : `zcrud_geo` — champ géo/carte. Hors périmètre.
- **E11a-2** (en cours, parallèle) : `zcrud_intl` — téléphone/pays/adresse. Hors périmètre.
- **E11b** (v1.x) : export COMPLET au-delà de la parité MVP (mise en page riche, styles avancés, export flashcard PDF E9, en-têtes/pieds/pagination élaborés, export d'entités non tabulaires, autres formats). **E11a-3 = strict minimum de parité : un tableau Excel + un tableau PDF.**

> Cette story se développe **EN PARALLÈLE d'E6 (`zcrud_markdown`) et d'E11a-2 (`zcrud_intl`)**. Elle reste **strictement** dans `packages/zcrud_export/`. **Aucune modification de `zcrud_core`** n'est nécessaire (voir *Impact zcrud_core* ci-dessous) — l'orchestrateur n'a donc **pas** à sérialiser de fichier core avec E6/E11a-2. Fichiers **disjoints** garantis.

### État réel du terrain (vérifié sur disque)

- **E1..E5 `done`, E4 `done`** : le moteur liste fournit **tous les types neutres** dont l'export a besoin. E6/E11a-2 en cours (packages disjoints).
- **Le cœur porte déjà le contrat neutre de liste** (E4-1/E4-2), consommé aujourd'hui par `zcrud_list` (`SfDataGrid`) et réutilisable **tel quel** pour l'export :
  - `ZListColumn` (`packages/zcrud_core/lib/src/presentation/list/z_list_column.dart`) : `name`, `header` (= `field.label ?? field.name`, **clé l10n non résolue**), `type` (`EditionFieldType`), `order`, `width?`, **`String Function(Object? raw) format`** — formateur **PUR, locale-neutre, qui ne lève jamais** (AD-10), dérivé du type/`choices`.
  - `deriveColumns(List<ZFieldSpec>, {ZColumnPolicy?})` : projette le schéma en colonnes visibles/ordonnées (whitelist `_tabularTypes` ; `ZColumnPolicy.forceInclude/forceExclude` additif AD-4).
  - `ZListRow` (`z_list_render_request.dart`) : `id` opaque + `cells: Map<String, Object?>` (valeurs **brutes**, indexées par `field.name`).
  - `ZListRenderRequest` + fabrique `ZListRenderRequest.fromSchema(fields, rows, {policy})` : agrège `columns` (dérivées) + `rows`. **C'est l'objet d'entrée idéal de l'export** (même contrat que le rendu écran → zéro re-dérivation, SM-5).
- **Règle de valeur de cellule (à répliquer telle quelle)** : le backend écran calcule `col.format(row.cells[col.name])`. **L'export DOIT faire exactement pareil** → format identique écran/fichier, une seule source de vérité de formatage (dans le cœur), pas de logique dupliquée.
- **`zcrud_export` est un squelette** : `pubspec.yaml` (dépend uniquement de `zcrud_core: ^0.0.1`), barrel `lib/zcrud_export.dart`, marqueur `lib/src/data/z_export_api.dart` (`ZExportApi`, référence `ZCoreApi.version` pour matérialiser l'arête AD-1). C'est ici que vit le service d'export.
- **Pas de `badCertificateCallback` réel dans `packages/`** aujourd'hui (les seules occurrences sont les **gardes/contre-exemples** du scanner et le test d'isolation géo). Le `badCertificateCallback => true` mentionné par l'épopée est un **reliquat du code DODLP hérité** (app hôte), **hors dépôt zcrud** → E11a-3 acte son **NON-portage** (voir AC10/Dev Notes).
- **Syncfusion est déjà présent au workspace mais confiné** : `zcrud_list/pubspec.yaml` déclare `syncfusion_flutter_datagrid: ^32.1.19`. `zcrud_core` n'en tire **rien** (gate `graph_proof.py` : `CORE OUT=0`). E11a-3 réplique ce **patron de confinement** avec `syncfusion_flutter_xlsio` + `syncfusion_flutter_pdf`.

### ADs applicables (NON-NÉGOCIABLES)

- **AD-1** — `zcrud_export → zcrud_core` seulement ; **Syncfusion (PDF/Excel) ne fuit JAMAIS dans `zcrud_core`** ni dans aucune signature publique neutre ; graphe acyclique + `out-degree(zcrud_core)==0` préservés (gate `graph_proof.py`).
- **AD-8 / SM-5** — Syncfusion **confiné** au seul `zcrud_export` (comme `SfDataGrid` l'est à `zcrud_list`) : **un consommateur qui n'importe pas `zcrud_export` ne tire PAS** `syncfusion_flutter_pdf`/`_xlsio`. Le cœur n'expose que des abstractions/types neutres (`ZListColumn`/`ZListRow`/`ZListRenderRequest`).
- **AD-10** — export **défensif** : données vides / colonnes absentes / cellule `null` / `cells` sans la clé attendue → cellule **vide**, classeur/document **vide mais valide**, **jamais** de crash. Le formatage passe par `col.format(...)` (déjà « ne lève jamais »).
- **AD-12** — **AUCUN secret** : aucune **clé/licence Syncfusion** committée (`SyncfusionLicense.registerLicense(...)` avec clé en dur INTERDIT — la licence est **fournie par l'app hôte** à son bootstrap, hors package) ; **AUCUN `badCertificateCallback => true`** ; aucun endpoint en dur. Gate `gate:secrets` vert.
- **AD-13** — l'export est **headless** (pas de widget) ; néanmoins toute surface UI éventuelle (aucune prévue ici) respecterait RTL/a11y. Le **texte des cellules** provient du format neutre ; l'export n'introduit **aucune** chaîne visible codée en dur non surchargeable (en-têtes = `header` résolus via resolver injecté optionnel).
- **AD-14/AD-15** — le service d'export est **pur-Dart headless** (n'importe **aucun** gestionnaire d'état, **aucun** `package:flutter/widgets`). Il peut importer `dart:typed_data` (`Uint8List`) et Syncfusion (confiné). La signature publique reste **neutre** (entrées `zcrud_core`, sortie **bytes**).

## Conception (résumé pour le dev)

**Principe directeur : réutiliser le contrat neutre de liste du cœur, ne rien réinventer, ne rien faire fuiter.**

1. **Port/service d'export neutre** (`ZExporter`, `abstract` ou façade + impls) — dans `zcrud_export`, signature **100 % neutre** :
   - Entrée = **`ZListRenderRequest`** (colonnes dérivées + lignes) — ou, en surcharge de commodité, `(List<ZListColumn> columns, List<ZListRow> rows)`. **Aucun type Syncfusion en paramètre.**
   - Option **`String Function(String headerKey)? resolveHeader`** (défaut = identité) : l'app peut résoudre les en-têtes l10n (`ZListColumn.header` est une **clé non résolue**) **sans** `BuildContext` (export headless). Par défaut, l'en-tête = `header` brut.
   - Sortie = **bytes neutres** `Uint8List` (ou `List<int>`), **jamais** un `Workbook`/`PdfDocument` Syncfusion en retour public → aucune fuite de type (AD-1 signature).
   - Méthodes : `Uint8List toExcelBytes(...)` et `Uint8List toPdfBytes(...)` (nommage explicite du format ; **pas** de dépendance `dart:io` obligatoire → testable en mémoire).
2. **En-têtes** : pour chaque `ZListColumn` (dans l'ordre `order`), cellule d'en-tête = `resolveHeader(col.header)`. **Une ligne d'en-tête.**
3. **Lignes** : pour chaque `ZListRow`, pour chaque colonne, valeur = **`col.format(row.cells[col.name])`** (clé absente → `format(null)` → `''`). **Réutilise le formatage pur du cœur** (SM-5 : source unique).
4. **Excel (`syncfusion_flutter_xlsio`)** : créer un `Workbook`, écrire l'en-tête en ligne 1 puis les lignes ; `workbook.saveAsStream()` → `Uint8List` ; `workbook.dispose()` (anti-fuite, learning E5). Le `Workbook` reste **local** à la méthode, jamais exposé.
5. **PDF (`syncfusion_flutter_pdf`)** : créer un `PdfDocument`, dessiner un `PdfGrid` (en-tête + lignes) sur une page ; `document.saveAsBytes()`/`document.save()` → `Uint8List` ; `document.dispose()`. Le `PdfDocument`/`PdfGrid` restent **locaux**, jamais exposés.
6. **Défensif (AD-10)** : `columns` vide → fichier valide **sans colonne** (Excel : classeur avec feuille vide ; PDF : document/page sans grille ou grille vide), **pas de crash**. `rows` vide → en-têtes seuls, aucune ligne de données. `cells` sans la clé → cellule vide. Aucune exception ne remonte.
7. **Isolation (AD-1/SM-5)** : `syncfusion_flutter_xlsio` + `syncfusion_flutter_pdf` déclarés **uniquement** au `pubspec.yaml` de `zcrud_export` ; imports Syncfusion **confinés** aux fichiers d'implémentation `lib/src/data/`; **jamais** ré-exportés par le barrel ; **aucun** symbole Syncfusion dans `lib/zcrud_export.dart`. Gate `graph_proof.py` (`CORE OUT=0`, acyclique) + gate signature (barrel/API sans type Syncfusion).
8. **No-secret / no-badcert (AD-12)** : aucune clé de licence Syncfusion dans le package (l'enregistrement de licence est **responsabilité de l'app hôte** ; documenter ce contrat) ; **aucun** `badCertificateCallback` ; gate `gate:secrets` vert. Acter le **NON-portage** du `badCertificateCallback` hérité DODLP.

### Impact zcrud_core

**NON — aucune modification de `zcrud_core`.** Justification vérifiée sur disque :
- Les types d'entrée neutres **existent déjà** et suffisent : `ZListColumn`, `ZListRow`, `ZListRenderRequest`/`fromSchema`, `deriveColumns`, `ZColumnPolicy` (E4-1/E4-2, `done`). L'export **consomme** ce contrat, sans l'étendre.
- Le **formatage** de cellule est déjà porté par `ZListColumn.format` (pur, ne lève jamais) → rien à ajouter au cœur.
- La sortie est en **bytes neutres** → aucun nouveau type/port côté cœur.

→ **Aucune sérialisation de fichier core à prévoir avec E6 / E11a-2.** Si, en cours de dev, un besoin de toucher `zcrud_core` apparaissait (p. ex. un port `ZExportRenderer` symétrique à `ZListRenderer`, ou un resolver de header dans `ZcrudScope`), **STOP + signalement à l'orchestrateur** avant d'éditer le cœur (risque de conflit avec E6/E11a-2). La conception ci-dessus (service autonome consommant le contrat neutre existant, resolver passé en paramètre) est précisément faite pour l'éviter.

## Acceptance Criteria

1. **Export Excel : classeur avec en-têtes + lignes (parité).** `ZExporter.toExcelBytes(request)` produit des `Uint8List` **non vides** d'un classeur `.xlsx` valide dont la **ligne 1** porte les en-têtes des colonnes (ordre `order`) et les lignes suivantes portent, pour chaque `ZListRow`, `col.format(row.cells[col.name])`. *Test : reconstruire/ré-ouvrir le classeur généré (via l'API xlsio de lecture **ou** assertions sur la présence des libellés/valeurs attendus dans les bytes/feuille) → en-tête + N lignes × M colonnes conformes.*
2. **Export PDF : document tabulaire valide.** `ZExporter.toPdfBytes(request)` produit des `Uint8List` **non vides** d'un PDF valide (signature `%PDF-`), contenant une grille en-tête + lignes dérivées du même contrat. *Test : bytes non vides + préfixe `%PDF` ; grille construite sans exception ; nb de lignes = 1 en-tête + `rows.length`.*
3. **Colonnes dérivées du schéma respectées (SM-5, réutilisation cœur).** Les colonnes exportées = celles de `ZListRenderRequest.columns` (donc `deriveColumns` : visibilité `_tabularTypes` + `ZColumnPolicy`, ordre `order`) ; la valeur d'une cellule = **exactement** `col.format(row.cells[col.name])` (même sortie qu'à l'écran). *Test : un champ `isId`/non-tabulaire exclu n'apparaît PAS ; un `forceInclude` apparaît ; un `select` rend le **libellé de choix** (pas la valeur brute) ; une valeur `Iterable`/`tags` rend le join `', '`.*
4. **Défensif : données vides / colonnes absentes / cellule nulle (AD-10).** `request` à `rows` vide → fichiers valides avec en-têtes seuls, **pas de crash** ; `columns` vide → fichiers valides sans colonne ; `row.cells` sans la clé d'une colonne, ou valeur `null` → cellule **vide** ; `ZListRenderRequest(columns: [], rows: [])` → Excel et PDF valides non-null. *Test : table de cas (rows vide, columns vide, clé manquante, valeur null, tout vide) → chaque appel `returnsNormally`, bytes non-null.*
5. **Isolation graphe — `zcrud_core` ne tire AUCUNE lib d'export Syncfusion (AD-1/SM-5).** `graph_proof.py` reste **`CORE OUT=0`** + acyclique + 14 nœuds ; `zcrud_core/pubspec.yaml` ne liste ni `syncfusion_flutter_pdf` ni `syncfusion_flutter_xlsio` ; ces libs n'apparaissent **qu'au** `pubspec.yaml` de `zcrud_export`. *Gate/test : `graph_proof.py` RC=0 ; assertion (grep/deps) sur les pubspecs.*
6. **Aucune fuite de type Syncfusion (AD-1, signature).** Ni le barrel `lib/zcrud_export.dart`, ni l'API publique de `ZExporter` (paramètres **et** valeurs de retour) n'exposent un type `syncfusion_flutter_*` (`Workbook`, `Worksheet`, `PdfDocument`, `PdfGrid`, `Range`, …) ; les imports Syncfusion restent **internes** à `lib/src/data/` ; la sortie publique est **neutre** (`Uint8List`). *Test : inspection des exports du barrel (aucune directive `export` d'un fichier important Syncfusion) + `dart analyze` ; grep : aucun symbole Syncfusion dans une signature publique.*
7. **No-secret — aucune clé/licence Syncfusion committée (AD-12).** Aucun `SyncfusionLicense.registerLicense('<clé>')` avec clé en dur, aucun token/clé/endpoint en dur dans `zcrud_export` ; l'enregistrement de licence est **délégué à l'app hôte** (documenté). *Gate : `gate:secrets` vert sur `zcrud_export` ; grep négatif clé/licence.*
8. **No-badcert — aucun contournement TLS (AD-12).** Aucun `badCertificateCallback => true` (ni forme `= (c,h,p) => true` / `{ return true; }`) dans `zcrud_export` ; le reliquat DODLP hérité est **explicitement NON porté** (documenté en Dev Notes / Completion). *Gate : `gate:secrets` (motif `badCertificateCallback`) vert ; grep négatif.*
9. **API neutre & barrel propre.** Le barrel exporte `ZExporter` (+ éventuel type de résultat neutre) ; entrée = types `zcrud_core` (`ZListRenderRequest`/`ZListColumn`/`ZListRow`) ; sortie = `Uint8List`. Le marqueur squelette `ZExportApi` est conservé ou remplacé proprement (l'arête AD-1 `zcrud_export → zcrud_core` reste matérialisée). *Test : import du barrel + usage de `ZExporter` compile ; `dart analyze` RC=0.*
10. **Anti-fuite de cycle de vie (learning E5).** Chaque `Workbook`/`PdfDocument` créé est **`dispose()`** après sérialisation des bytes (y compris en cas d'export vide) ; aucune ressource native non libérée. *Test : chemin nominal + chemin vide → pas de fuite ; (si outillable) vérifier qu'une exception éventuelle libère quand même via `try/finally`.*
11. **Vérif verte rejouée.** `melos run generate` OK → `dart analyze` RC=0 → `flutter test` (ou `dart test`) RC=0 sur `zcrud_export` (workspace inchangé) ; `melos run verify` RC=0 (graphe + secrets + reflectable + serialization). *Gate `done`.*

## Tasks / Subtasks

- [x] **T1 — Service d'export neutre `ZExporter`** (AC: 1, 2, 3, 4, 9)
  - [x] `lib/src/data/z_exporter.dart` : API publique **neutre** — `Uint8List toExcelBytes(ZListRenderRequest request, {String Function(String)? resolveHeader})` et `Uint8List toPdfBytes(...)`. Aucun type Syncfusion en signature. (Projection commune extraite dans `z_export_table.dart` → `ZExportTable.fromRequest`.)
  - [x] Boucle de projection commune : en-tête = `resolveHeader(col.header)` (défaut identité) ; cellule = `col.format(row.cells[col.name])` ; ordre = `columns` tels quels (déjà ordonnés par `deriveColumns`).
  - [x] Défensif AD-10 : `columns`/`rows` vides, clé absente, valeur null → cellule/fichier vide, jamais de throw.
- [x] **T2 — Backend Excel (xlsio, confiné)** (AC: 1, 6, 10)
  - [x] `lib/src/data/z_excel_exporter.dart` (impl interne) : `import 'package:syncfusion_flutter_xlsio/xlsio.dart'` **confiné ici** ; `Workbook` local ; écriture en-tête + lignes ; `saveAsStream()` → `Uint8List` ; `workbook.dispose()` en `finally`. Aucun type Syncfusion réexporté.
- [x] **T3 — Backend PDF (pdf, confiné)** (AC: 2, 6, 10)
  - [x] `lib/src/data/z_pdf_exporter.dart` (impl interne) : `import 'package:syncfusion_flutter_pdf/pdf.dart'` **confiné ici** ; `PdfDocument` + `PdfGrid` locaux ; `saveSync()` → `Uint8List` ; `document.dispose()` en `finally`. Aucun type Syncfusion réexporté.
- [x] **T4 — pubspec & barrel** (AC: 5, 6, 7, 8, 9)
  - [x] `pubspec.yaml` de `zcrud_export` : ajout `syncfusion_flutter_xlsio: ^32.1.19` + `syncfusion_flutter_pdf: ^32.1.19` (résolu 32.2.9, aligné workspace) ; devient package Flutter (SDK exigé par xlsio/pdf) ; **rien** dans `zcrud_core`. Aucune clé/licence. (`archive: ^4.0.0` en dev_dependency test-only pour ré-ouvrir le .xlsx.)
  - [x] `lib/zcrud_export.dart` : exporte `ZExporter` + `ZExportTable` (neutre) ; **ne réexporte pas** `z_excel_exporter.dart`/`z_pdf_exporter.dart` (impl interne Syncfusion) ; **aucun** symbole Syncfusion. Marqueur `ZExportApi` supprimé (arête AD-1 désormais matérialisée par l'import réel de `zcrud_core` dans `ZExporter`).
- [x] **T5 — Tests** (AC: 1-10) — voir *Stratégie de tests*. 19 tests (contenu Excel ré-ouvert via ZIP `archive`, contenu PDF via `PdfTextExtractor`, colonnes dérivées, défensif, isolation/signature/secrets).
- [x] **T6 — Gates** (AC: 5, 6, 7, 8, 11)
  - [x] `graph_proof.py` (`CORE OUT=0`, acyclique, 14 nœuds) RC=0 ; assertions pubspec (`zcrud_core` sans lib export ; xlsio/pdf uniquement dans `zcrud_export`) ; inspection barrel sans symbole Syncfusion ; `flutter analyze` 0 issue + `flutter test` RC=0 + `dart pub get --dry-run` RC=0.

## Stratégie de tests

- **Excel** : construire un `ZListRenderRequest.fromSchema(schema, rows)` avec des types variés (`text`, `number`, `boolean`, `select` avec `choices`, `tags`/multiple, `dateTime`) → `toExcelBytes` ; ré-ouvrir/reconstruire le classeur (API xlsio de lecture si dispo, sinon vérifier la présence des libellés d'en-tête et des valeurs formatées attendues) : en-tête ligne 1 conforme, valeurs = `col.format(...)` (choix résolu, join `', '`, ISO date), bytes non vides.
- **PDF** : `toPdfBytes` → bytes non vides + préfixe `%PDF` ; grille construite (en-tête + `rows.length` lignes) sans exception.
- **Colonnes dérivées (AC3)** : schéma avec champ `isId` + un `richText`/`file` (non tabulaire) → **absents** ; `ZColumnPolicy(forceInclude: {...})` → **présent** ; `select` → **libellé** de choix ; `forceExclude` prioritaire.
- **Défensif (AC4)** : table de cas — `rows: []` (en-têtes seuls) ; `columns: []` (fichier valide sans colonne) ; `row.cells` sans la clé d'une colonne → cellule vide ; valeur `null` → vide ; `ZListRenderRequest(columns: [], rows: [])` → Excel + PDF non-null. Chaque appel `returnsNormally`.
- **Isolation / signature (AC5, AC6)** : `graph_proof.py` RC=0 (`CORE OUT=0`) ; test/assertion : `zcrud_core/pubspec.yaml` sans `syncfusion_flutter_pdf`/`_xlsio` ; inspection des directives `export` du barrel → aucune n'expose un fichier important Syncfusion ; grep : aucun `Workbook`/`PdfDocument`/`PdfGrid`/`Worksheet` dans une signature publique.
- **Secrets / badcert (AC7, AC8)** : `gate:secrets` vert ; grep négatif `registerLicense('...')` avec littéral + `badCertificateCallback`.
- **Cycle de vie (AC10)** : chemin nominal + vide → dispose appelé (via impl `try/finally` ; couverture par lecture/instrumentation si le SDK ne l'expose pas directement).

## Dev Notes

### Fichiers du cœur à NE PAS modifier (lecture de référence — contrat d'entrée)

- `packages/zcrud_core/lib/src/presentation/list/z_list_column.dart` — `ZListColumn` (`name`/`header`/`type`/`order`/`width`/**`format`**), `deriveColumns`, `ZColumnPolicy`, `_tabularTypes`. **Source du formatage** : l'export appelle `col.format(raw)`, ne re-dérive rien.
- `packages/zcrud_core/lib/src/presentation/list/z_list_render_request.dart` — `ZListRow` (`id`/`cells`), `ZListRenderRequest` + `ZListRenderRequest.fromSchema`. **Objet d'entrée de l'export.**
- `packages/zcrud_core/lib/src/presentation/list/z_list_renderer.dart` — `ZListRenderer` (patron d'isolation à imiter : le cœur n'expose que l'abstraction, le backend lourd vit dans le satellite). L'export **ne** définit **pas** de port core symétrique (headless, pas de widget) — s'il en fallait un, STOP + signalement orchestrateur.
- `packages/zcrud_list/lib/src/presentation/z_sf_data_grid_renderer.dart` + `packages/zcrud_list/pubspec.yaml` — **modèle de confinement Syncfusion** (import confiné, version `^32.1.19`, `CORE OUT=0`). À répliquer pour xlsio/pdf.

### Patron de confinement Syncfusion (AD-8/SM-5) — à répliquer

`zcrud_list` prouve le patron : la lib lourde (`syncfusion_flutter_datagrid`) est déclarée **seulement** dans son pubspec, importée **seulement** dans l'impl, jamais réexportée ; le cœur reste `CORE OUT=0`. E11a-3 fait pareil avec `syncfusion_flutter_xlsio` + `syncfusion_flutter_pdf` dans `zcrud_export`. **Un import `zcrud_markdown` (ou tout package sans `zcrud_export`) ne doit tirer NI PDF NI Excel** (SM-5, validé par la structure du graphe).

### badCertificateCallback hérité DODLP — NON porté (AD-12)

L'épopée mentionne « retrait de tout `badCertificateCallback => true` (AD-12) ». Ce reliquat vit dans le **code DODLP hérité** (app hôte), **pas** dans `zcrud_export`. E11a-3 **n'introduit** aucun contournement TLS et **acte** son non-portage : lors de l'intégration DODLP (**E7**), le code d'export dupliqué de l'app est supprimé au profit de `ZExporter` (qui n'a **jamais** de `badCertificateCallback`). Le gate `gate:secrets` verrouille l'absence côté package. **Rien à « retirer » dans zcrud** — la responsabilité est d'empêcher la réintroduction.

### Licence Syncfusion — responsabilité de l'app hôte (AD-12)

`syncfusion_flutter_*` peut exiger l'enregistrement d'une licence via `SyncfusionLicense.registerLicense(...)`. **Cet appel — et la clé — appartiennent au bootstrap de l'app hôte, JAMAIS au package** (zéro secret committé, AD-12). Documenter ce contrat dans le doc-comment de `ZExporter`. Ne **pas** appeler `registerLicense` dans `zcrud_export`.

### Sortie en bytes neutres (AD-1 signature)

Retourner `Uint8List` (`dart:typed_data`) — **jamais** un `Workbook`/`PdfDocument`. L'écriture disque (`dart:io`) est laissée à l'app (mobile/desktop/web ont des chemins différents) : garder l'export **headless et testable en mémoire**. Une surcharge helper d'écriture fichier reste **hors périmètre** (E11b) si elle force `dart:io`.

### Learnings absorbés

- **E11a-1** : isolation prouvée par **gate graphe** (fermeture transitive, `CORE OUT=0`) + **gate signature** (barrel sans symbole SDK) + **gate secrets**. Même triple preuve ici pour Syncfusion.
- **E5** : **disposer** toute ressource native (`Workbook.dispose()`, `PdfDocument.dispose()`) via `try/finally`, même sur le chemin d'export vide/erreur — anti-fuite de cycle de vie.
- **E4-2** : le **formatage vit une seule fois** dans le cœur (`ZListColumn.format`, pur, ne lève jamais). L'export **consomme**, ne duplique pas → parité écran/fichier garantie, AD-10 hérité gratuitement.

### Project Structure Notes

- Tout sous `packages/zcrud_export/lib/` : `src/data/` (service + backends xlsio/pdf, headless, pur-Dart + Syncfusion confiné). Barrel `lib/zcrud_export.dart` (neutre). `*_test.dart` sous `test/`. Aucun `*.g.dart` committé (pas de modèle annoté attendu).
- Nommage : types publics préfixés `Z` (`ZExporter`) ; fichiers snake_case ; impls internes non réexportées si elles portent Syncfusion en API.
- `zcrud_export` devient un **package Flutter** si les libs Syncfusion l'exigent (comme `zcrud_list`) : ajouter `flutter`/`flutter_test` au pubspec au besoin ; sinon rester pur-Dart. Confirmer au dev via `dart pub get`.

### Latest tech (à confirmer via `pub` au dev — versions indicatives 2026)

- **Excel :** `syncfusion_flutter_xlsio: ^32.1.19` (aligné `^32.1.x` de l'architecture et sur `syncfusion_flutter_datagrid ^32.1.19` déjà résolu dans `zcrud_list`). API : `Workbook()`, `workbook.worksheets[0]`, `sheet.getRangeByIndex(r,c).setText/.setValue`, `workbook.saveAsStream()` → `List<int>`, `workbook.dispose()`.
- **PDF :** `syncfusion_flutter_pdf: ^32.1.19`. API : `PdfDocument()`, `PdfGrid()` (`grid.columns.add`, `grid.headers.add`, `grid.rows.add`), `grid.draw(page:, bounds:)`, `document.saveAsBytes()`/`save()` → `List<int>`, `document.dispose()`.
- **Aligner les 3 versions Syncfusion** du workspace (datagrid/xlsio/pdf) pour éviter un conflit de résolution ; confirmer via `dart pub get --dry-run` (gate compat E1-4). SDK Dart `^3.12.2`.
- **Un seul niveau de mise en page** (tableau simple) suffit à la parité E11a-3 ; styles/pagination/en-têtes riches = **E11b**.

### References

- [Source: epics.md#E11a — Story E11a-3] (`_bmad-output/planning-artifacts/epics/.../epics.md` l. 111-117) — export DataGrid Excel/PDF Syncfusion ; retrait de tout `badCertificateCallback=>true` (AD-12).
- [Source: epics.md#E7 — Story E7-4] l. 125 — « export préservé (E11a-3) » : E11a-3 est la dépendance de parité d'E7.
- [Source: architecture.md#AD-1] l. 57-60 — direction acyclique ; Syncfusion jamais dans le cœur.
- [Source: architecture.md#AD-8] l. 92-95 — Syncfusion isolé derrière l'abstraction ; un consommateur sans le satellite ne tire pas Syncfusion.
- [Source: architecture.md#AD-10] l. 102-105 — désérialisation/export défensif, ne casse jamais le parent.
- [Source: architecture.md#AD-12] l. 112-115 — zéro secret ; pas de `badCertificateCallback` ; endpoints surchargeables.
- [Source: architecture.md#AD-14] l. 122-125 — pureté de couche ; headless pur-Dart.
- [Source: architecture.md#Stack] l. 163 — `syncfusion_flutter_datagrid / _pdf / _xlsio (zcrud_list, zcrud_export)` `^32.1.x`.
- [Source: prd.md#SM-5] l. 384 — isolation des dépendances : importer un package seul n'ajoute ni Firebase, ni Syncfusion, ni Maps (valide FR-24).
- [Source: prd.md#SM-2] l. 379 — parité d'intégration DODLP (export inclus).
- [Source: zcrud_core] `z_list_column.dart` (`ZListColumn`/`deriveColumns`/`ZColumnPolicy`), `z_list_render_request.dart` (`ZListRow`/`ZListRenderRequest`/`fromSchema`), `z_list_renderer.dart` (patron d'isolation).
- [Source: zcrud_list] `z_sf_data_grid_renderer.dart` + `pubspec.yaml` (`syncfusion_flutter_datagrid ^32.1.19`) — patron de confinement à répliquer.
- [Source: melos.yaml] l. 48/58-83 — gates `graph:proof` (`CORE OUT=0`), `gate:secrets`, `verify` (agrégat) à rejouer verts.
- [Source: story E11a-1] `stories/e11a-1-...md` — triple preuve d'isolation (graphe + signature + secrets), dispose anti-fuite, non-modification du cœur.
- [Source: CLAUDE.md] Key Don'ts — jamais Syncfusion dans `zcrud_core` (isolé dans `zcrud_export`/`zcrud_list`) ; jamais `badCertificateCallback => true` ; jamais de secret dans un package ; disposer les ressources ; `Either`/types neutres.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, skill chargé via le tool `Skill` — chemin skill pris, pas le fallback disque).

### Debug Log References

- `flutter analyze` (zcrud_export) : **No issues found!** (RC=0, 0 issue).
- `flutter test` (zcrud_export) : **All tests passed!** — **19 tests**, RC=0.
- `python3 scripts/dev/graph_proof.py` : `ACYCLIQUE OK` / `CORE OUT=0 OK` / 14 nœuds, **RC=0**.
- `dart pub get --dry-run` (racine workspace) : `No dependencies would change` — **RC=0** ; Syncfusion (xlsio/pdf/core/officecore/datagrid) co-résolus à **32.2.9** (aucun conflit, gate E1-4 vert).

### Completion Notes List

- **API neutre** : `ZExporter.toExcelBytes(request, {resolveHeader})` / `toPdfBytes(...)` → `Uint8List`. Entrée = `ZListRenderRequest` (colonnes dérivées + `ZListRow`) du cœur ; **aucun** type Syncfusion en signature.
- **Parité écran/fichier (SM-5)** : cellule = `col.format(row.cells[col.name])` (formateur PUR du cœur, une seule source) ; projection centralisée dans `ZExportTable.fromRequest`. Tests prouvent la parité : `select` → libellé de choix (`Ouvert`), `tags` → join `', '` (`a, b`), `dateTime` → ISO (`2026-01-02T03:04:05.000Z`).
- **Contenu réel vérifié** : Excel ré-ouvert par décodage ZIP (`package:archive`, xlsio étant write-only) → en-têtes + valeurs présents dans le XML de feuille/sharedStrings ; PDF ré-ouvert par `PdfTextExtractor` → en-têtes + valeurs présents ; préfixes `PK`/`%PDF-` vérifiés.
- **Isolation (AD-1/AD-8/SM-5)** : `syncfusion_flutter_xlsio`+`_pdf` déclarés UNIQUEMENT dans `zcrud_export/pubspec.yaml` (0 dans `zcrud_core`, 0 ailleurs) ; imports Syncfusion confinés à `z_excel_exporter.dart`/`z_pdf_exporter.dart` ; barrel sans symbole Syncfusion ; sortie bytes → 0 type `Workbook`/`PdfDocument` public. `graph_proof.py` : `CORE OUT=0`, 14 nœuds.
- **Défensif (AD-10)** : rows vides → en-têtes seuls ; columns vides → xlsx (feuille vide) + PDF (page vide) valides ; clé absente/null → cellule `''`. Tous `returnsNormally`, bytes non-null.
- **Cycle de vie (AC10/E5)** : `Workbook.dispose()` et `PdfDocument.dispose()` en `try/finally` (chemin nominal + vide + exception).
- **No-secret / no-badcert (AD-12)** : aucun `SyncfusionLicense.registerLicense(...)` (licence = bootstrap app hôte, documenté dans le doc-comment de `ZExporter`) ; aucun `badCertificateCallback` ; reliquat DODLP hérité **non porté** (acté). Gate de secrets rejoué en test (scan de code hors prose).
- **zcrud_core NON touché** (confirmé) : les types neutres existants suffisent ; aucune modification du cœur, aucune sérialisation de fichier core avec E6/E11a-2.
- **Frontière** : export tabulaire Excel/PDF de la liste UNIQUEMENT (styles/pagination/en-têtes riches = E11b ; géo = E11a-1 ; intl = E11a-2). Périmètre strict `packages/zcrud_export/`.

### File List

- `packages/zcrud_export/pubspec.yaml` (modifié — devient package Flutter ; deps xlsio/pdf ; dev-dep archive)
- `packages/zcrud_export/lib/zcrud_export.dart` (modifié — barrel neutre, exporte `ZExporter`/`ZExportTable`)
- `packages/zcrud_export/lib/src/data/z_exporter.dart` (créé — façade neutre `ZExporter`)
- `packages/zcrud_export/lib/src/data/z_export_table.dart` (créé — projection neutre `ZExportTable`)
- `packages/zcrud_export/lib/src/data/z_excel_exporter.dart` (créé — backend Excel xlsio confiné)
- `packages/zcrud_export/lib/src/data/z_pdf_exporter.dart` (créé — backend PDF confiné)
- `packages/zcrud_export/lib/src/data/z_export_api.dart` (supprimé — marqueur squelette obsolète)
- `packages/zcrud_export/test/z_exporter_test.dart` (créé — tests fonctionnels AC1..AC4/AC10)
- `packages/zcrud_export/test/isolation_gates_test.dart` (créé — gates AC5..AC8)
