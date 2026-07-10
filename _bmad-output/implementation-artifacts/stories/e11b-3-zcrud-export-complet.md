---
baseline_commit: 04aaaf0
---

# Story E11b.3 : zcrud_export complet — PdfCreationService dédupliqué (images → PDF), FileSaveHelper web, mise en page PDF anti-rognage

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrant zcrud (DODLP puis lex_douane) au-delà du sous-ensemble d'export livré en parité MVP (E11a-3)**,
je veux **compléter `zcrud_export` avec (1) un service `ZPdfCreationService` NEUTRE et UNIQUE qui assemble des images/scans (bytes) en un document PDF multi-pages — dédupliquant le `PdfCreationService` copié à l'identique dans DODLP et IFFD ; (2) un `ZFileSaver` cross-platform (facade neutre + imports conditionnels) dont la version WEB — restée VIDE dans DODLP — est réellement implémentée (téléchargement navigateur), sans secret ni contournement TLS ; (3) des options de mise en page PDF (`ZPdfExportOptions` : orientation, titre, en-tête répété) qui corrigent le rognage horizontal des tables larges (finding LOW-1 déféré d'E11a-3)**,
afin que **FR-8-export soit couvert au-delà du tableau simple, avec les backends Syncfusion TOUJOURS confinés (AD-1/AD-8/SM-5), une API publique STABLE et additive (jamais de régression du marqueur `ZExportApi` consommé par `zcrud_flashcard`), de façon défensive (AD-10), sans aucun secret ni `badCertificateCallback` (AD-12) — et EN NE MODIFIANT PAS `zcrud_core`.**

## Contexte & cadrage

**Épopée E11b — Reste géo / intl / export (v1.x/v2).** Objectif (`epics.md` l. 150-151) : « compléter **au-delà** du lot parité MVP ; couvre FR-20, FR-21, **FR-8-export (reste)** ; AD-12 ; dépend de E11a ». Story E11b-3 (`epics.md` l. 155) : « **`zcrud_export` complet : PDF documents + `FileSaveHelper` web.** AC : `PdfCreationService` unique dédupliqué ; version web `FileSaveHelper` implémentée (AD-12). »

**Ce qui existe déjà (E11a-3, `done`) — NE PAS refaire, RÉUTILISER :**
- `ZExporter` (façade neutre) : `toExcelBytes(request)` / `toPdfBytes(request)` → `Uint8List`. Parité écran/fichier via `ZExportTable.fromRequest` (cellule = `col.format(row.cells[col.name])`, source unique de formatage du cœur).
- `ZExportTable` : projection neutre `ZListRenderRequest` → table de `String` (headers + rows). C'est le POINT UNIQUE de projection ; les backends ne voient QUE des `String`.
- Backends Syncfusion **confinés** : `src/data/z_excel_exporter.dart` (`buildExcelBytes`, `syncfusion_flutter_xlsio`) et `src/data/z_pdf_exporter.dart` (`buildPdfBytes`, `syncfusion_flutter_pdf`). Dispose en `finally`. Défensif AD-10.
- `ZExportApi` (marqueur d'API stable) : `version = '0.0.1'`, `coreApiVersion`. **Réexporté par le barrel et CONSOMMÉ par `zcrud_flashcard`** (`z_flashcard_api.dart:24 → exportApiVersion = ZExportApi.version`).
- Gates : `test/isolation_gates_test.dart` (core-sans-Syncfusion, confinement des imports aux 2 backends, aucun type Syncfusion en signature publique, no-secret/no-badcert) + `test/z_exporter_test.dart` (contenu réel via `package:archive` / `PdfTextExtractor`).

**Ce qui manque pour « complet » (périmètre de CETTE story) :** voir les 3 axes ci-dessous. Origine des besoins (inventaire technique, `docs/technical-inventory.md` l. 156-160, 313, 322, 360) :
- `PdfCreationService` (images/scan → PDF) **dupliqué à l'identique DODLP/IFFD** → dédupliquer en une source unique.
- `FileSaveHelper` (imports conditionnels web/mobile) dont **la version web est VIDE** dans DODLP → l'implémenter.
- Export DataGrid PDF : L1 d'E11a-3 (tables larges **rognées** en largeur) explicitement **déféré à E11b**.

## Contrainte DURE (NON-NÉGOCIABLE)

- 🚫 **NE PAS modifier `zcrud_core`.** Aucun type nouveau dans le cœur : `ZPdfCreationService` prend des **bytes bruts** (`List<Uint8List>` d'images), `ZFileSaver` prend des **bytes** (`Uint8List`), `ZPdfExportOptions` est **local à `zcrud_export`**. Si un besoin cœur réel émergeait → **STOP + signaler à l'orchestrateur** (ne pas éditer `zcrud_core` en solo).
- 🚫 **Syncfusion reste confiné.** UNIQUEMENT dans `src/data/z_*.dart` (backends). Aucun type `PdfDocument`/`Workbook`/… dans une signature publique ni dans le barrel. Sortie = bytes neutres.
- 🚫 **Aucun second stack PDF.** On génère les PDF via le backend Syncfusion pdf **déjà présent** (`syncfusion_flutter_pdf`, `PdfBitmap`/`page.graphics.drawImage`). **Ne PAS** ajouter `pdf`/`printing` (packages legacy DODLP/IFFD) — HORS story.
- 🚫 **Aucun secret / aucun `badCertificateCallback` / aucun `registerLicense('<clé>')`** dans le package (AD-12). La licence Syncfusion reste config de l'app hôte.
- 🚫 **API publique additive uniquement.** Interdiction de supprimer/renommer `ZExportApi`, `ZExporter`, `ZExportTable` (leçon rétro : la suppression de `ZExportApi` en E11a-3 avait cassé `zcrud_flashcard`, `melos analyze` resté RED plusieurs commits). Les nouveaux symboles s'AJOUTENT au barrel.

## Acceptance Criteria

**Axe A — `ZPdfCreationService` : images/scans → document PDF unique (dédup DODLP/IFFD)**

1. **AC1.** `zcrud_export` expose une façade publique **neutre** `ZPdfCreationService` (barrel) dont la méthode prend une **liste ordonnée de bytes d'image** (`List<Uint8List> images`) et renvoie les **bytes d'un unique document PDF multi-pages** (`Uint8List`, préfixe `%PDF-`) — **une image par page**, dans l'ordre fourni. Aucune signature ne référence de type Syncfusion.
2. **AC2.** Chaque image est **ajustée à la page** en préservant son ratio (fit-to-page, centrée) — une image plus large/haute que la page n'est **pas** rognée ni déformée. L'orientation par défaut est portrait (option de mise en page réutilisée depuis l'axe C si fournie).
3. **AC3 (défensif AD-10).** `images` vide → PDF **valide** (document minimal d'une page vide OU document 0-page valide selon la lib), **jamais** d'exception. Un élément de `images` dont les bytes ne sont **pas** une image décodable est **ignoré** (page sautée), le reste du document est produit **sans crash**. Le `PdfDocument` est `dispose()` en `finally` (anti-fuite, learning E5), y compris chemin vide/exception.
4. **AC4 (dédup).** L'implémentation vit dans le backend Syncfusion **confiné** (`src/data/z_pdf_document_builder.dart`, réutilisant `syncfusion_flutter_pdf` DÉJÀ déclaré) : **aucune** duplication de la logique de rendu tabulaire existante ni ajout d'un second moteur PDF. Le service est la **source unique** remplaçant le `PdfCreationService` DODLP/IFFD.

**Axe B — `ZFileSaver` cross-platform (version web implémentée, AD-12)**

5. **AC5.** `zcrud_export` expose une façade publique **neutre** `ZFileSaver` (barrel) : `Future<ZFileSaveResult> save(Uint8List bytes, {required String fileName, String? mimeType, String? directoryPath})`. Elle délègue à une implémentation **choisie par imports conditionnels** (`z_file_saver_stub.dart` ↔ `z_file_saver_io.dart` (`dart:io`) ↔ `z_file_saver_web.dart` (`package:web` + `dart:js_interop`)). Aucun symbole `dart:io`/`package:web` ne fuit dans la signature publique.
6. **AC6 (web — le trou DODLP).** L'implémentation **web** déclenche un **téléchargement navigateur** des `bytes` sous `fileName` (Blob + `mimeType` + ancre `download`, révocation de l'URL objet). Elle est **réellement écrite** (plus de stub vide comme DODLP `save_file_web`) et **analyzer-clean**. `dart:html` **banni** (déprécié) → `package:web`/`dart:js_interop`.
7. **AC7 (io).** L'implémentation **io** écrit `bytes` sur disque : si `directoryPath` (absolu) est fourni → `<directoryPath>/<fileName>` ; sinon un répertoire **temporaire système** (`Directory.systemTemp`). Elle renvoie le chemin écrit dans `ZFileSaveResult`. **Aucune** dépendance `path_provider` (la sélection de dossier applicatif reste hors package). Répertoire créé si absent (`recursive`).
8. **AC8 (AD-12).** Ni `ZFileSaver` ni ses implémentations ne contiennent de secret, de `badCertificateCallback`, ni d'appel réseau : c'est une écriture/téléchargement **local** de bytes. `ZFileSaveResult` porte au minimum le nom/chemin et un indicateur de succès ; défensif (bytes vides → fichier vide valide, jamais de crash).

**Axe C — Mise en page PDF anti-rognage (clôt LOW-1 d'E11a-3)**

9. **AC9.** `zcrud_export` expose `ZPdfExportOptions` (neutre, immuable, `const`) portant **au minimum** : `orientation` (portrait|paysage, défaut portrait), `title` (String? optionnel, dessiné en haut du document si présent), `repeatHeader` (bool, défaut true : la ligne d'en-tête se répète sur chaque page auto-paginée). `ZExporter.toPdfBytes(request, {resolveHeader, ZPdfExportOptions? options})` accepte ces options ; **rétro-compatible** : appel sans `options` = comportement E11a-3 inchangé (paramètre optionnel, valeur par défaut).
10. **AC10.** Avec beaucoup de colonnes, la grille **n'est plus rognée** horizontalement : la largeur est répartie/ajustée à la page (`PdfLayoutFormat` / largeur de colonnes, ou orientation paysage) de sorte que la **dernière colonne** apparaisse dans le texte extrait du PDF (assertion `PdfTextExtractor`). Le contenu (valeurs `col.format`) et la parité écran/fichier (SM-5) restent inchangés.

**Axe D — Isolation, API stable, non-régression (transversal, NON-NÉGOCIABLE)**

11. **AC11 (API additive stable).** Le barrel `lib/zcrud_export.dart` **continue** d'exporter `ZExportApi`, `ZExporter`, `ZExportTable` (aucune suppression/renommage) et **ajoute** `ZPdfCreationService`, `ZFileSaver`, `ZFileSaveResult`, `ZPdfExportOptions`. Un **test de surface** verrouille la présence de ces symboles (import du barrel + référence compilée). `zcrud_flashcard` (qui lit `ZExportApi.version`) **compile toujours** — vérifié par `melos run analyze` **REPO-WIDE**.
12. **AC12 (isolation étendue + gate durci).** Les gates `isolation_gates_test.dart` sont **étendus** au nouveau backend `z_pdf_document_builder.dart` : (a) l'allowlist des fichiers autorisés à importer Syncfusion est **dérivée dynamiquement** (tous les `.dart` de `src/data/` important Syncfusion) OU mise à jour **exhaustivement** (learning E10 AI-E10-2 : un garde ne prouve QUE ce qu'il scanne, allowlist codée en dur = dette) ; (b) le contrôle « aucun type Syncfusion en signature publique » **dérive** la liste des fichiers publics (tous les `.dart` de `lib/` sauf backends `src/data/z_*.dart`) plutôt qu'une liste de 3 fichiers codée en dur (clôt LOW-2 d'E11a-3) ; (c) no-secret/no-badcert re-scanné sur TOUS les nouveaux fichiers (y compris `z_file_saver_*.dart`), strip-comment, cwd-robuste ; (d) `package:web`/`dart:js_interop`/`dart:io` autorisés (ne sont ni Syncfusion ni secret) mais **confinés** à leurs fichiers conditionnels respectifs.

## Tasks / Subtasks

- [x] **T1 — ZPdfCreationService (Axe A, AC1-4).**
  - [x] Backend confiné `src/data/z_pdf_document_builder.dart` : `Uint8List buildImagesPdf(List<Uint8List> images, {ZPdfExportOptions? options})`, une image/page via `PdfBitmap` + `page.graphics.drawImage`, fit-to-page ratio-preserving centré ; try/catch par image (bytes non décodables → page sautée) ; `PdfDocument.dispose()` en `finally`.
  - [x] Façade neutre `src/data/z_pdf_creation_service.dart` (`ZPdfCreationService`, `const`-constructible) déléguant au backend ; signature 100 % neutre (`List<Uint8List>` → `Uint8List`).
  - [x] Export additif au barrel.
- [x] **T2 — ZFileSaver cross-platform (Axe B, AC5-8).**
  - [x] Façade + contrat : `src/data/z_file_saver.dart` (`ZFileSaver`, `ZFileSaveResult`) avec **imports conditionnels** (`if (dart.library.io)` / `if (dart.library.js_interop)` → stub par défaut). `ZFileSaveResult` extrait dans `z_file_save_result.dart` (évite le cycle facade↔impl).
  - [x] `z_file_saver_stub.dart` (`throw UnsupportedError` documenté), `z_file_saver_io.dart` (`dart:io`, écriture disque, `directoryPath`/`systemTemp`, `recursive`), `z_file_saver_web.dart` (`package:web` + `dart:js_interop` : Blob → URL objet → ancre `download` → révocation).
  - [x] Ajouter la dépendance **`web`** au SEUL `zcrud_export/pubspec.yaml` (usage web-conditionnel ; ne fuit pas dans `zcrud_core`). Gate compat E1-4 (`dart pub get --dry-run`) RC=0.
  - [x] Export additif au barrel.
- [x] **T3 — Options de mise en page PDF (Axe C, AC9-10).**
  - [x] `src/data/z_pdf_export_options.dart` (`ZPdfExportOptions` + enum neutre `ZPdfOrientation`, immuable, `const`, `==`/`hashCode`).
  - [x] Étendre `z_pdf_exporter.dart::buildPdfBytes(table, {options})` : orientation (paysage → `PdfPageSettings.orientation`/`PdfPageOrientation`), titre optionnel dessiné en haut (`drawString`), en-tête répété (`grid.repeatHeader`) + anti-rognage via `grid.style.allowHorizontalOverflow = true` (colonnes en surnombre rejouées en bande sous la précédente, à largeur naturelle — aucune colonne rognée).
  - [x] Étendre `ZExporter.toPdfBytes(request, {resolveHeader, options})` — paramètre optionnel, défaut = comportement E11a-3.
- [x] **T4 — Isolation, gates durcis, non-régression (Axe D, AC11-12).**
  - [x] Étendre `isolation_gates_test.dart` : allowlist Syncfusion **dérivée** dynamiquement (tout `.dart` de `lib/` important Syncfusion doit être un backend `src/data/z_*.dart`), fichiers publics **dérivés** (lib/ hors importeurs Syncfusion), no-secret/no-badcert + no-réseau sur TOUS les fichiers, `dart:io`/`package:web`/`dart:js_interop` confinés à `z_file_saver_{io,web}.dart`, `dart:html` banni.
  - [x] Test de **surface d'API** (`api_surface_test.dart`) : le barrel exporte `ZExportApi`, `ZExporter`, `ZExportTable`, `ZPdfCreationService`, `ZFileSaver`, `ZFileSaveResult`, `ZPdfExportOptions`, `ZPdfOrientation`.
  - [x] Bump additif `ZExportApi.version` `'0.0.1' → '0.1.0'` — **sans** renommer le champ (consommé par `zcrud_flashcard`).
- [x] **T5 — Tests fonctionnels (contenu réel).**
  - [x] `ZPdfCreationService` (`z_pdf_creation_service_test.dart`) : 1 image PNG minimale → PDF `%PDF-` non vide, page-count = 1 ; N images → N pages ; liste vide → `returnsNormally` + PDF valide 1 page ; bytes non-image → page sautée (2 valides/1 garbage → 2 pages) ; que du garbage → 1 page vide ; boucle x20 → `returnsNormally` (dispose).
  - [x] `ZFileSaver` io (`z_file_saver_test.dart`) : `save` vers `systemTemp` → fichier existe, `readAsBytes` == bytes ; `directoryPath` imbriqué créé récursivement ; bytes vides → fichier de taille 0. (Web : non exerçable sous VM → gate statique AC12.)
  - [x] Mise en page PDF (`z_pdf_layout_test.dart`) : table 16 colonnes → texte extrait contient la **dernière** colonne (en-tête `Colonne15` + valeur `v15`) ; paysage → PDF valide ; titre présent ; `repeatHeader:false` → valide ; `==`/`hashCode`/défauts ; **sans `options` = rétro-compat**.
  - [x] Tests E11a-3 (`z_exporter_test.dart`) restés verts (aucune régression parité/défensif).

## Dev Notes

### Réutilisation impérative (anti-réinvention)
- **NE PAS** ré-implémenter la projection tabulaire : `ZExportTable.fromRequest` est la source unique (`col.format`). Les options C n'agissent que sur le **rendu** PDF (backend), jamais sur la projection.
- **NE PAS** ajouter `pdf`/`printing` : générer les documents image→PDF via `syncfusion_flutter_pdf` **déjà présent** (`PdfBitmap`, `PdfDocument.pages.add()`, `page.graphics.drawImage`). Un seul stack PDF (AD-8).
- **NE PAS** ajouter `path_provider` : `dart:io` + `directoryPath` fourni / `Directory.systemTemp` suffisent (la sélection de dossier UI = app hôte).
- Patterns de confinement/dispose à **copier** depuis `z_pdf_exporter.dart` / `z_excel_exporter.dart` (try/finally dispose, garde `isNotEmpty`, bytes neutres).

### Isolation & signature (AD-1/AD-8/SM-5)
- Nouveau backend `z_pdf_document_builder.dart` = **seul** nouveau fichier autorisé à importer Syncfusion, en plus des 2 backends existants. Le barrel ne réexporte AUCUN backend.
- La sortie de tout nouveau chemin = **`Uint8List`** → fuite de type Syncfusion structurellement impossible.
- `z_file_saver_web.dart` importe `package:web`/`dart:js_interop` ; `z_file_saver_io.dart` importe `dart:io`. Ces imports sont **confinés** à leurs fichiers conditionnels et ne remontent jamais dans la façade neutre `ZFileSaver`.

### Défensif (AD-10) — obligatoire sur chaque entrée
- `images` vide / élément non décodable → PDF valide, page sautée, **jamais** de crash ni de propagation d'exception au-delà du service.
- `bytes` vides pour `ZFileSaver` → fichier vide valide.
- `toPdfBytes` sans `options` → strictement le comportement E11a-3 (rétro-compat verrouillée par test).

### AD-12 — zéro secret, zéro TLS permissif
- Rappel inventaire (`technical-inventory.md` l. 360) : DODLP portait `badCertificateCallback => true` (`helpers.dart:160`) — **ne JAMAIS** le réintroduire. `ZFileSaver` est purement local (aucune requête réseau). Gate no-badcert/no-secret étendu à tous les nouveaux fichiers.

### API stable — leçon de régression (rappel orchestrateur)
- E11a-3 avait **supprimé `ZExportApi`** → `zcrud_flashcard` (`exportApiVersion = ZExportApi.version`) cassé, `melos analyze` **RED** non vu plusieurs commits. **Interdiction absolue** de retirer/renommer `ZExportApi`/`ZExporter`/`ZExportTable`. Ajouts **additifs** seulement. **Gate de sortie : `melos run analyze` REPO-WIDE** (pas seulement `flutter analyze` ciblé zcrud_export) — un symbole public cassé ne se voit que repo-wide.

### Leçons rétro à appliquer (E5, E10)
- **Dispose en `finally`** sur tout objet natif Syncfusion (learning E5 : cycle de vie non borné = fuite). Vaut pour le `PdfDocument` du builder d'images.
- **Garde grep/gate = ce qu'il scanne, rien de plus** (E10 AI-E10-2) : allowlist Syncfusion et liste de fichiers publics **dérivées dynamiquement**, strip-comment, cwd-robuste, denylist AD-12 exhaustive. Clôt LOW-2 d'E11a-3.
- **a11y** : N/A pour cette story (aucun widget ; prévisualisation PDF = HORS story). Si un widget émergeait → STOP (hors périmètre).

### Web non testable sur VM
- `flutter test` s'exécute sur la VM Dart → les imports conditionnels chargent la version **io/stub**, jamais `z_file_saver_web.dart`. La logique web ne peut donc PAS être exercée en unit-test VM. Couverture attendue : (1) io testé réellement (écriture/relecture) ; (2) façade/contrat ; (3) **gate statique** sur le fichier web (compile analyzer-clean, n'importe que `web`/`js_interop`, aucun secret/Syncfusion). Documenter cette limite dans les Completion Notes.

### Dépendance nouvelle
- **`web`** (léger, usage web-conditionnel) ajouté au SEUL `zcrud_export/pubspec.yaml`. N'affecte PAS `graph_proof.py` (ne piste que les arêtes `zcrud_*` + CORE OUT=0 ; `web` n'est pas un package zcrud). **Rejouer `dart pub get --dry-run` (gate compat E1-4)** et consigner le résultat.

### Périmètre RETENU vs HORS-story (v2) — NE PAS gold-plater
**RETENU (justifié FR-8 / epic E11b-3 / LOW-1 déféré) :** ZPdfCreationService images→PDF (dédup) ; ZFileSaver web+io (comble le trou DODLP) ; ZPdfExportOptions minimal (orientation/titre/en-tête répété) anti-rognage.
**HORS-story (v2, à ne PAS implémenter) :** styling PDF riche (polices embarquées, couleurs, bordures/thèmes de cellule, logos) ; widget de **prévisualisation PDF** (concern UI) ; stack PDF alternatif `pdf`/`printing` ; `path_provider`/sélecteur de dossier/partage natif (share sheet) ; `RemotePdfRenderer` (endpoint IA IFFD distant) ; cellules Excel typées natif (numérique/date) et styling/multi-feuilles/sous-listes Excel ; **export CSV** (FR-8 = Excel/PDF uniquement — explicitement exclu).

### Project Structure Notes
- Tout sous `packages/zcrud_export/` : `lib/src/data/{z_pdf_document_builder,z_pdf_creation_service,z_file_saver,z_file_saver_stub,z_file_saver_io,z_file_saver_web,z_pdf_export_options}.dart` + éditions de `z_pdf_exporter.dart`, `z_exporter.dart`, barrel `lib/zcrud_export.dart` ; tests sous `test/`.
- `pubspec.yaml` : ajout `web` (dependencies). Syncfusion pdf/xlsio déjà présents.
- **Aucune** édition hors `packages/zcrud_export/`. **`zcrud_core` NON modifié** (confirmé nécessaire : aucun type cœur requis — bytes/images/options tous locaux).

### References
- [Source: epics.md#E11b l.150-155] — objectif E11b + AC E11b-3 (`PdfCreationService` dédup, `FileSaveHelper` web).
- [Source: prd.md#FR-8] — export Excel/PDF via `zcrud_export` (optionnel ; son absence ne casse pas la liste).
- [Source: architecture.md#AD-8] — Syncfusion isolé ; [AD-1] graphe acyclique, CORE OUT=0 ; [AD-12] zéro secret ; [AD-10] désérialisation/entrées défensives.
- [Source: docs/technical-inventory.md l.156-160,313,322,360] — `PdfCreationService` dupliqué DODLP/IFFD, `FileSaveHelper` web vide, `badCertificateCallback` à retirer, licence Syncfusion.
- [Source: stories/code-review-e11a-3.md] — LOW-1 (tables larges rognées → E11b), LOW-2 (allowlist codée en dur → dériver), notes de conformité (setText, resolveHeader, dispose).
- [Source: stories/epic-5-retrospective.md] — dispose/cycle de vie en `finally`.
- [Source: stories/epic-10-retrospective.md AI-E10-2] — gate/grep exhaustif, dérivé, strip-comment, cwd-robuste.
- [Source: packages/zcrud_export/lib/ (E11a-3)] — `ZExporter`, `ZExportTable`, `ZExportApi`, backends confinés, gates existants à étendre.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- Anti-rognage : une 1re approche (largeurs égales `pageWidth/n` + `allowHorizontalOverflow=false`) rendait les colonnes trop étroites → en-têtes longs rognés (`Colonne15` → `Colonne`). Correctif retenu : `grid.style.allowHorizontalOverflow = true` (mécanisme Syncfusion documenté) qui rejoue les colonnes en surnombre dans une bande sous la précédente, à largeur naturelle — la dernière colonne (en-tête + valeur) est intégralement rendue et extraite par `PdfTextExtractor` (vérifié : `Colonne0..Colonne15` + `v0..v15` présents, PDF à 2 pages en portrait).
- PNG de test : générés déterministement (2x2 rouge, 1000x10 vert « très large ») et embarqués en base64 pour valider le décodage `PdfBitmap` et le fit-to-page ratio-preserving.

### Completion Notes List

- **Périmètre strict `zcrud_export`** : AUCUN autre package modifié (`zcrud_core` intact — tous les types nouveaux sont locaux : bytes/images/options). Vérifié `git status`.
- **API additive** : `ZExportApi`/`ZExporter`/`ZExportTable` conservés (aucun retrait/renommage). Ajouts au barrel : `ZPdfCreationService`, `ZFileSaver`, `ZFileSaveResult`, `ZPdfExportOptions`, `ZPdfOrientation`. `ZExportApi.version` bumpé `0.0.1 → 0.1.0` (nom `version` inchangé — `zcrud_flashcard` compile toujours, analyze RC=0, 135 tests verts).
- **Syncfusion confiné** : seuls les 3 backends `src/data/{z_excel_exporter,z_pdf_exporter,z_pdf_document_builder}.dart` importent Syncfusion ; gate d'isolation durci (allowlist + fichiers publics DÉRIVÉS dynamiquement, clôt LOW-2 d'E11a-3). Sortie de tout chemin = `Uint8List` neutre.
- **Web sans `dart:html`** : `z_file_saver_web.dart` utilise `package:web` + `dart:js_interop` (Blob → `URL.createObjectURL` → ancre `download` → `revokeObjectURL`). Non exerçable sous `flutter test` VM (import conditionnel charge io/stub) → couvert par le gate statique (analyze-clean + imports confinés + no-secret). `dart:html` interdit par gate.
- **AD-12 zéro secret** : aucun `registerLicense`/`badCertificateCallback`/appel réseau ; `ZFileSaver` purement local. Gate no-secret/no-badcert/no-réseau étendu à tous les fichiers `lib/`.
- **Défensif AD-10** : images vide → PDF 1 page valide ; bytes non décodables → page sautée ; bytes vides `ZFileSaver` → fichier vide valide ; `dispose()` en `finally` sur `PdfDocument`.
- **Dépendance nouvelle** : `web: ^1.1.0` au SEUL `zcrud_export/pubspec.yaml`. N'affecte pas `graph_proof.py` (pas un package zcrud_*).

**Vérif verte rejouée sur disque :**
| Gate | Commande | Résultat |
|------|----------|----------|
| pub get | `dart pub get` | Got dependencies (RC 0) |
| analyze export | `dart analyze packages/zcrud_export` | No issues, RC 0 |
| test export | `flutter test packages/zcrud_export` | **42 tests, All passed**, RC 0 |
| non-régression flashcard | `dart analyze packages/zcrud_flashcard` | No issues, RC 0 (135 tests verts) |
| graphe AD-1 | `python3 scripts/dev/graph_proof.py` | ACYCLIQUE OK, **CORE OUT=0 OK**, RC 0 |
| compat E1-4 | `dart pub get --dry-run` | Would get dependencies, RC 0 |

### File List

**Créés (zcrud_export uniquement) :**
- `packages/zcrud_export/lib/src/data/z_pdf_export_options.dart`
- `packages/zcrud_export/lib/src/data/z_pdf_document_builder.dart`
- `packages/zcrud_export/lib/src/data/z_pdf_creation_service.dart`
- `packages/zcrud_export/lib/src/data/z_file_save_result.dart`
- `packages/zcrud_export/lib/src/data/z_file_saver.dart`
- `packages/zcrud_export/lib/src/data/z_file_saver_stub.dart`
- `packages/zcrud_export/lib/src/data/z_file_saver_io.dart`
- `packages/zcrud_export/lib/src/data/z_file_saver_web.dart`
- `packages/zcrud_export/test/z_pdf_creation_service_test.dart`
- `packages/zcrud_export/test/z_file_saver_test.dart`
- `packages/zcrud_export/test/z_pdf_layout_test.dart`
- `packages/zcrud_export/test/api_surface_test.dart`

**Modifiés (zcrud_export uniquement) :**
- `packages/zcrud_export/lib/zcrud_export.dart` (exports additifs)
- `packages/zcrud_export/lib/src/data/z_exporter.dart` (`toPdfBytes(..., options)`)
- `packages/zcrud_export/lib/src/data/z_pdf_exporter.dart` (`buildPdfBytes(table, {options})` : orientation/titre/repeatHeader/anti-rognage)
- `packages/zcrud_export/lib/src/data/z_export_api.dart` (`version` `0.0.1 → 0.1.0`)
- `packages/zcrud_export/pubspec.yaml` (dépendance `web: ^1.1.0`)
- `packages/zcrud_export/test/isolation_gates_test.dart` (gates durcis dérivés)

### Change Log

- E11b-3 (2026-07-10) : `zcrud_export` complet — `ZPdfCreationService` (images→PDF dédupliqué DODLP/IFFD), `ZFileSaver` cross-platform (web `package:web` implémenté, io disque), `ZPdfExportOptions` (orientation/titre/en-tête répété) anti-rognage clôturant LOW-1. Gates d'isolation durcis (dérivation dynamique, clôt LOW-2). API additive, Syncfusion confiné, AD-12 respecté, `zcrud_core` intact.
