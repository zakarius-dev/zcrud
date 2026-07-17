# Story 1.11: Gabarit PDF flashcards et satellite d'export UI

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->
<!-- Story key: su-11-gabarit-pdf-export-ui | Epic E-STUDY-UI | Couvre FR-SU16 | Taille XL | Workstream B (∥ A, packages DISJOINTS ; après su-1) -->

## Story

As an utilisateur,
I want exporter mes flashcards en PDF imprimable (avec ou sans réponses, formules LaTeX rendues, puis prévisualiser / imprimer / partager),
so that je révise sur papier comme aujourd'hui, sans imposer une dépendance de plateforme à qui ne veut que des octets.

## Acceptance Criteria

Repris **mot pour mot** de la Story 1.11 des epics (`epics-zcrud-study-ui-2026-07-16/epics.md:531-566`), éclatés en ACs numérotés et rendus vérifiables.

1. **AC1 — Gabarit typé (dossier entier ou sélection).**
   **Given** un dossier entier **ou** une sélection de cartes
   **When** `ZFlashcardPdfTemplate` produit le document
   **Then** la mise en page **typée** comprend : **titre**, **numérotation** des cartes, un **badge d'instruction par type** (`ZFlashcardType` : multipleChoice / trueOrFalse / openQuestion / exercise / fillBlank / shortAnswer), les **choix ✓/✗ colorés** pour QCM (`isCorrect`) et V/F (`isTrue`), la **réponse distinguée** (`answer`) et l'**explication** (`explanation`).
   **And** la sortie est le triplet **`{bytes, fileName, mimeType}`** (`mimeType == "application/pdf"`, bytes préfixés `%PDF-`).

2. **AC2 — Option avec/sans réponses (par enum, jamais booléen).**
   **Given** le même corpus
   **When** le gabarit est invoqué avec un mode d'affichage des réponses **déclaré par enum** (`ZAnswerVisibility.withAnswers` / `ZAnswerVisibility.withoutAnswers`)
   **Then** en `withoutAnswers` **aucun** des éléments réponse/✓·✗/explication/`isTrue` n'apparaît dans le flux (ni texte, ni bitmap), seuls énoncé + badge + libellés de choix **non marqués** subsistent ; en `withAnswers` tout est rendu. La différence est **observable sur les bytes** (les deux modes produisent des documents distincts) **et** sur une extraction de texte du PDF (le mot de la réponse est présent/absent).

3. **AC3 — `zcrud_export` reste PUR (AD-42, aucune dépendance de plateforme).**
   **Given** l'implémentation du gabarit dans `zcrud_export`
   **When** on inspecte ses `dependencies:` et ses imports `lib/`
   **Then** `zcrud_export` ne gagne **aucune** dépendance nouvelle : **pas** de `printing`, **pas** de `flutter_math_fork`, **pas** de `dart:ui` de rendu écran (`RepaintBoundary`/`toImage`/`PictureRecorder`), aucun type de plateforme dans une signature publique. Le gabarit est une **fonction pure** (bytes in → bytes out) exécutable sous `flutter test` **sans** plateforme ni pixel réel.

4. **AC4 — Port de rasterisation LaTeX (deux maillons manquants).**
   **Given** une carte contenant une formule LaTeX (dans `question`, `answer` ou `explanation`)
   **When** le PDF est généré
   **Then** la formule est **rendue** via un **port de rasterisation** `ZLatexRasterizer` (abstraction PURE déclarée dans `zcrud_export` : LaTeX `String` → `Uint8List?` PNG), dont l'**impl concrète** (`flutter_math_fork` → capture hors écran → PNG) vit **hors** de `zcrud_export`, dans le satellite plateforme `zcrud_export_ui`, **polices KaTeX chargées**.
   **And** un **test porteur golden** couvre **au moins deux** formules de référence rendues par l'impl concrète (le seul moyen de prouver un rendu visuel).

5. **AC5 — Composition inline texte + bitmap (au-delà de `buildFromImages`).**
   **Given** le gabarit
   **When** il compose une page
   **Then** il compose **texte + bitmap en ligne dans le flux** (`drawString` + `drawImage` positionnés à la volée) — **au-delà** de `buildImagesPdf`/`buildFromImages` (qui ne fait qu'**une image par page**). Une formule LaTeX s'insère **dans** le paragraphe (énoncé/réponse), pas sur une page image séparée. Prouvé par : un document **multi-cartes contenant des formules** tient sur **moins de pages** qu'un rendu une-image-par-formule, et le texte non-LaTeX reste **extractible** (donc dessiné en texte, pas rasterisé).

6. **AC6 — Satellite NEUF `zcrud_export_ui` : preview / impression / partage.**
   **Given** le nouveau satellite `zcrud_export_ui`
   **When** il est livré
   **Then** il offre **prévisualisation, impression et partage** de bytes PDF via **`printing: ^5.15.0`**
   **And** `printing` **et** sa dépendance transitive `pdf` **ne franchissent jamais** ce package : l'API publique reste en **`Uint8List`** (le type `PdfPageFormat` est **absorbé** à l'intérieur, jamais dans une signature publique).

7. **AC7 — Confinement des deps tierces du satellite (SEULE protection).**
   **Given** que `graph_proof.py` ne connaît **que** les arêtes inter-`zcrud_*` (ne voit **aucune** fuite tierce — prouvé su-4/su-5)
   **When** on garde `zcrud_export_ui`
   **Then** une **garde de confinement propre au package** (owner = `zcrud_export_ui`, patron `z_third_party_confinement_test.dart`) rougit si `printing` **ou** `flutter_math_fork` est déclaré par un **autre** package que son owner, est importé par **plus d'un** fichier `lib/`, est **réexporté** par le barrel, ou voit **un de ses types** (`PdfPageFormat`, `Printing`, `Math`, `TeXParser`…) fuiter dans une signature publique. La garde porte une **contre-preuve R12 mutante** (un vrai leak témoin la fait rougir ; notre propre type voisin ne la déclenche pas).

8. **AC8 — Membre du workspace melos, mêmes gates CI (NFR-SU10), `zcrud_export` inchangé.**
   **Given** `zcrud_export_ui`
   **When** on lance les gates repo-wide
   **Then** il est membre du **workspace melos**, versionné (`0.2.1`) et contraint comme ses pairs, et passe **graphe acyclique (AD-1)** + **CORE OUT=0** + **secrets** + **codegen-distribution** + **rétro-compat sérialisation**. Ses **seules** arêtes `zcrud_*` sont `zcrud_export` + `zcrud_core` (leaf : personne ne dépend de lui). `melos run analyze` / `melos run verify` restent **RC=0 repo-wide**.
   **And** `zcrud_export` ne gagne **aucune** dépendance (revérifié après ajout du satellite).

9. **AC9 — Robustesse (AD-10) : jamais de throw du parent.**
   **Given** des entrées dégradées
   **When** le gabarit compose
   **Then** aucun chemin ne lève vers l'appelant : **dossier vide** → PDF valide d'une page (titre seul, jamais 0-page) ; **carte malformée** (question `''`, choix `null`, type inconnu retombé sur `openQuestion`) → carte rendue sans crash ; **LaTeX invalide** (le rasteriseur échoue / renvoie `null`) → **repli** sur le **texte brut** de la formule (jamais de trou ni d'exception) ; **explication très longue** → **pagination** correcte (débordement sur page suivante, pas de rognage) ; **Unicode / RTL** dans le texte → rendu sans exception. `PdfDocument.dispose()` en `finally` sur **tous** les chemins (learning E5).

## Tasks / Subtasks

- [x] **T1 — Port + modèle d'entrée neutre dans `zcrud_export` (PUR)** (AC1, AC3, AC4)
  - [x] Déclarer `ZLatexRasterizer` (abstraction PURE) : `Future<Uint8List?> rasterize(String latex, {double? logicalWidth})` — PNG bytes ou `null` si échec. Aucun import Flutter de rendu.
  - [x] Déclarer les enums de rendu (jamais booléen) : `ZAnswerVisibility { withAnswers, withoutAnswers }` ; réutiliser `ZPdfOrientation` existant.
  - [x] Déclarer `ZFlashcardPdfInput` neutre : liste de cartes projetées en primitives (`type` : `ZFlashcardType`, `question`, `answer?`, `isTrue?`, `choices?` = liste `(content, isCorrect)`, `explanation?`) — **ne pas** faire dépendre `zcrud_export` de `zcrud_flashcard` (sens d'arête : `zcrud_export → zcrud_flashcard` est INTERDIT ; l'arête réelle est `zcrud_export → flash` **inversée** dans le mermaid AD, i.e. `exp --> flash` = flash dépend d'export). ⚠️ Vérifier le sens : `zcrud_flashcard` dépend de `zcrud_export` (barrel `ZExportApi`), donc **la projection carte→input se fait CHEZ l'appelant** (`zcrud_flashcard`/app), et `ZFlashcardPdfTemplate` reçoit un `ZFlashcardPdfInput` neutre. Ne JAMAIS importer `zcrud_flashcard` dans `zcrud_export`.
- [x] **T2 — `ZFlashcardPdfTemplate` : composition inline typée (PUR, Syncfusion confiné)** (AC1, AC2, AC5, AC9)
  - [x] Nouveau fichier confiné `lib/src/data/z_flashcard_pdf_template.dart` : import `syncfusion_flutter_pdf` **confiné à ce fichier** (comme `z_pdf_exporter.dart`/`z_pdf_document_builder.dart`), aucun type Syncfusion en signature publique.
  - [x] Composition inline : titre + numérotation ; par carte, badge d'instruction (par `ZFlashcardType`, table unique jamais redécidée) ; énoncé en `drawString` avec insertion **inline** des bitmaps LaTeX (`drawImage` positionné dans le flux) ; choix ✓/✗ colorés (vert/rouge thémés, jamais couleur codée en dur si évitable — sinon constantes documentées) ; réponse distinguée ; explication paginée.
  - [x] `ZAnswerVisibility.withoutAnswers` : masque réponse / ✓·✗ / `isTrue` / explication.
  - [x] Sortie = `ZExportResult`-like `{Uint8List bytes, String fileName, String mimeType}` (réutiliser un type neutre existant si présent, sinon créer `ZExportedFile` neutre). `mimeType = "application/pdf"`.
  - [x] `PdfDocument.dispose()` en `finally` sur **tous** les chemins (vide / exception).
  - [x] Défensif AD-10 : dossier vide, carte malformée, LaTeX null (repli texte brut), explication longue (pagination), Unicode/RTL.
  - [x] Exposer via le barrel `zcrud_export.dart` (ADDITIF, jamais de retrait — leçon `ZExportApi` E11a-3) : `ZFlashcardPdfTemplate`, `ZLatexRasterizer`, `ZAnswerVisibility`, `ZFlashcardPdfInput`, `ZExportedFile`. Bumper `ZExportApi.version` (`0.1.0 → 0.2.0`, ADDITIF).
- [x] **T3 — Paquet NEUF `zcrud_export_ui` (membre workspace melos)** (AC6, AC8)
  - [x] `packages/zcrud_export_ui/pubspec.yaml` : `resolution: workspace`, `version: 0.2.1`, `publish_to: none`, env `sdk: ^3.12.2`, deps = `flutter`, `printing: ^5.15.0`, `flutter_math_fork: ^0.7.4`, `zcrud_export: ^0.2.1`, `zcrud_core: ^0.2.1` (arêtes `zcrud_*` = export + core UNIQUEMENT — AD-1). Header pubspec documentant le confinement (patron `zcrud_export`/`zcrud_session`).
  - [x] Barrel `lib/zcrud_export_ui.dart` : n'exporte **aucun** symbole `printing`/`pdf`/`flutter_math_fork` ; API publique 100% `Uint8List`.
  - [x] `ZExportUiApi` marqueur d'API stable (patron `ZExportApi`) rattachant les arêtes `→ zcrud_export` / `→ zcrud_core`.
  - [x] Squelette : `analysis_options.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE` (copier les pairs).
- [x] **T4 — Impl concrète du rasteriseur LaTeX (`zcrud_export_ui`)** (AC4, AC9)
  - [x] `lib/src/data/z_flutter_math_latex_rasterizer.dart` : `implements ZLatexRasterizer`, **SEUL** fichier important `flutter_math_fork`. Rendu hors écran (`Math.tex` → `RepaintBoundary`/`PictureRecorder` → `Image.toByteData(png)`), **polices KaTeX chargées** (asset du package, comme `zcrud_markdown`).
  - [x] Défensif (AD-10) : LaTeX invalide / vide → `Future.value(null)` (jamais throw), pour que le template retombe sur le texte brut (AC9).
- [x] **T5 — Preview / impression / partage via `printing` (`zcrud_export_ui`)** (AC6)
  - [x] `lib/src/presentation/z_pdf_preview.dart` (widget) + `lib/src/data/z_pdf_share_service.dart` : **SEUL(S)** fichier(s) important(s) `package:printing/`. API publique en `Uint8List` (bytes du PDF déjà produit par `ZFlashcardPdfTemplate`) ; `PdfPageFormat` **absorbé** en interne.
  - [x] Semantics + cibles ≥ 48 dp sur les actions (AD-13) ; libellés via l10n / thème injecté, jamais codés en dur.
- [x] **T6 — Garde de confinement propre au paquet neuf** (AC7)
  - [x] `packages/zcrud_export_ui/test/z_export_ui_confinement_test.dart` (patron `z_third_party_confinement_test.dart`) : **TABLE** `_confined` = `printing` (^5.15.0, owner = `z_pdf_preview.dart`/share, bannedTypes `PdfPageFormat`,`Printing`,`PrintingInfo`,`PdfPreview`…) **et** `flutter_math_fork` (^0.7.4, owner = `z_flutter_math_latex_rasterizer.dart`, bannedTypes `Math`,`TeXParser`,`MathStyle`,`FlutterMathException`…). Owner package = `zcrud_export_ui`. Dé-commentateur **YAML** (`#`) + motif ANCRÉ (leçon su-5 D2). Contre-preuve R12 mutante par paquet.
  - [x] Note de portée honnête (leçon E10 : « un garde ne prouve QUE ce qu'il scanne ») : scanne les `pubspec.yaml` de `packages/*` + les sources `lib/**` de `zcrud_export_ui`.
- [x] **T7 — Golden du rendu LaTeX + preuve de composition inline** (AC4, AC5)
  - [x] `packages/zcrud_export_ui/test/golden/z_latex_rasterizer_golden_test.dart` : `matchesGoldenFile` sur **≥ 2** formules de référence rendues par l'impl concrète, + discriminant byte-diff (deux formules distinctes → octets distincts ; formule vide → repli). Committer les `.png` golden.
  - [x] Preuve de composition inline (AC5) dans `zcrud_export` : un test qui vérifie qu'un doc multi-cartes avec formules tient sur **moins** de pages qu'une-image-par-formule ET que le texte non-LaTeX reste **extractible** (décoder les bytes PDF, compter pages + extraire texte).
- [x] **T8 — Tests porteurs `zcrud_export` (fonction pure)** (AC1, AC2, AC9)
  - [x] `z_flashcard_pdf_template_test.dart` : par type (badge présent, ✓/✗ selon `isCorrect`/`isTrue`), `withAnswers` vs `withoutAnswers` (extraction texte : réponse présente/absente + bytes distincts), robustesse AD-10 (vide, malformé, LaTeX null via fake rasterizer, explication longue paginée, Unicode/RTL). **Injection R3** : chaque test doit rougir si le comportement casse (ex. masquer les réponses cesse de masquer → texte réponse ré-apparaît).
- [x] **T9 — Gates repo-wide + vérif verte** (AC8)
  - [x] `python3 scripts/dev/graph_proof.py` : acyclique, CORE OUT=0, nouveau nœud `zcrud_export_ui` présent (leaf).
  - [x] `melos run generate` (si annotation) → `melos run analyze` RC=0 repo-wide → `flutter test` **DEPUIS chaque package touché** (`zcrud_export`, `zcrud_export_ui`) RC=0. **Ne PAS** lancer `melos run test` (workstreams ∥ actifs).
  - [x] Vérifier que le pubspec `zcrud_session` (dartdoc « printing vit dans zcrud_export ») **n'affirme rien de faux** : la table de confinement de session reste à **2** paquets ; `printing` vit désormais dans `zcrud_export_ui` (écart documenté, cf. Dev Notes).

## Dev Notes

### Contrat RÉEL vérifié sur disque (ne pas resupposer)

- **`zcrud_export` existe et est DÉJÀ PUR** : `buildPdfBytes` (`z_pdf_exporter.dart`) et `buildImagesPdf` (`z_pdf_document_builder.dart`) prennent des entrées neutres et rendent `Uint8List`. **Syncfusion (`syncfusion_flutter_pdf` + `_xlsio`) est confiné** aux impls `lib/src/data/z_{excel,pdf}_exporter.dart` + `z_pdf_document_builder.dart` — **jamais** réexporté par le barrel, **jamais** dans une signature publique. **Aucun `printing`, aucun `dart:ui` de rendu écran** aujourd'hui. env `sdk: ^3.12.2`, package **Flutter**, `version: 0.2.1`. `dispose()` en `finally` déjà la norme (learning E5). → **AD-42 déjà à moitié tenu ; su-11 ajoute le gabarit typé + le port LaTeX + le satellite, sans jamais salir `zcrud_export`.**
- **`ZFlashcardPdfTemplate` n'existe PAS** — grep négatif : `grep -rl "ZFlashcardPdfTemplate" packages/` → **RC=1**. À créer.
- **`zcrud_export_ui` n'existe PAS** (`ls packages/zcrud_export_ui` → RC=2). **Paquet NEUF.**
- **`printing` : ABSENT partout** (`grep -rln "package:printing" packages/*/lib/` → RC=1 ; aucun pubspec ne le déclare — seule une **prose** de `zcrud_session/pubspec.yaml:75` l'anticipe). C'est la **3ᵉ** dépendance tierce de l'epic (su-4 `flutter_card_swiper`, su-5 `confetti`). Compat vérifiée en amont (AD-42) : `^5.15.0` accepte `Uint8List`, CVE-2024-4367 corrigé, SDK monorepo OK. **À confiner dans `zcrud_export_ui` (owner).**
- **`flutter_math_fork` : DÉJÀ présent** — `zcrud_markdown/pubspec.yaml:64` `flutter_math_fork: ^0.7.4` (import réel dans `z_latex_embed.dart`, aussi utilisé indirectement par `zcrud_flashcard`/`zcrud_note`). Rendu via `Math.tex(onErrorFallback:)`. Ce n'est donc **PAS** une 4ᵉ dépendance nouvelle du repo, mais l'impl concrète du rasteriseur lui donne un **2ᵉ site de déclaration** (`zcrud_export_ui`). **À confiner aussi dans la garde du paquet neuf.**

### Décisions conservatrices tranchées (mode non-interactif — consignées)

1. **Où vit le rasteriseur LaTeX ?** → **Impl concrète dans `zcrud_export_ui`** (satellite plateforme), PAS dans `zcrud_export`. Motif : la rasterisation exige un **rendu Flutter hors écran** (`Math.tex` widget → `RepaintBoundary`/`PictureRecorder` → `toByteData(png)`) = **plateforme**, incompatible avec la pureté d'`zcrud_export` (AD-42). Le **port `ZLatexRasterizer`** (abstraction) vit PUR dans `zcrud_export` ; `ZFlashcardPdfTemplate` ne dépend que du port. Conséquence assumée : `flutter_math_fork` gagne un 2ᵉ home → **couvert par la garde de confinement du paquet neuf** (AC7).
2. **`flutter_math_fork` en 2ᵉ site NE casse PAS le guard existant** : `math_lib_isolation_graph_test.dart` (zcrud_markdown) n'assure **que** (a) le cœur n'a pas `flutter_math_fork`, (b) contrôle positif markdown, (c) acyclicité — **aucune** assertion « un seul owner dans tout le repo ». `zcrud_export_ui` étant un **leaf** (le cœur n'en dépend jamais), (a) reste vrai. Vérifié sur disque (`math_lib_isolation_graph_test.dart:145-170`).
3. **La table de confinement de `zcrud_session` reste à 2 paquets** (`hasLength(2)`, liste exacte `['flutter_card_swiper','confetti']`). Elle est **owner-scoped** (`_ownerPackage = 'zcrud_session'`) : elle ne peut pas garder `printing`/`flutter_math_fork` dans un **autre** package. → **Le paquet neuf a sa PROPRE garde** (T6/AC7). ⚠️ Le dartdoc de `z_third_party_confinement_test.dart` et le commentaire `zcrud_session/pubspec.yaml:75` disent « printing vit dans `zcrud_export` » : c'est **faux** au regard d'AD-42 (printing va dans `zcrud_export_ui`). **Ne PAS** modifier la table de session (hors périmètre, elle reste juste sur ses 2 paquets) ; **consigner l'écart** dans le header de la nouvelle garde et — si trivial et sans régression — corriger la seule ligne de **prose** trompeuse. **Ne jamais** ajouter `printing` au pubspec de `zcrud_session`.
4. **Projection carte → input neutre chez l'appelant** : `zcrud_flashcard` **dépend de** `zcrud_export` (`exp --> flash` dans le mermaid = flash consomme export ; `ZExportApi` référencé par flashcard). L'arête inverse est **interdite** (AD-1). Donc `ZFlashcardPdfTemplate` prend un **`ZFlashcardPdfInput` neutre**, la projection depuis `ZFlashcard` se faisant côté `zcrud_flashcard`/app. **Ne jamais importer `zcrud_flashcard` dans `zcrud_export`.**
5. **`printing` fournit AUSSI un rendu PDF→bitmap** : ne PAS l'utiliser pour rasteriser le LaTeX (ce serait `printing` dans `zcrud_export` — interdit). Le rasteriseur reste `flutter_math_fork` dans `zcrud_export_ui`.

### Modèle `ZFlashcard` (champs pertinents, vérifiés `z_flashcard.dart`)

`type: ZFlashcardType` (6 valeurs, défaut `openQuestion`, désérial. défensive), `question: String` (requis, `''` si absent), `answer: String?`, `isTrue: bool?` (V/F), `choices: List<ZChoice>?` (`ZChoice{content:String, isCorrect:bool}`), `explanation: String?`, `hint`, `isReadOnly`. Persistance snake_case, enums camelCase (`type: "openQuestion"`).

### Graphe après le paquet neuf (AD-1)

Arête ajoutée : `zcrud_export_ui → zcrud_export` **et** `zcrud_export_ui → zcrud_core` (mermaid AD : `exp --> expui`). `zcrud_export_ui` est un **leaf** (personne ne dépend de lui → CORE OUT inchangé, aucun cycle possible). `graph_proof.py` auto-découvre tout `packages/*/pubspec.yaml` (pas de compte d'arêtes codé en dur) → le nœud entre sans édition du script. Acyclicité (Kahn) préservée. Le nombre d'arêtes `zcrud_*` passe de son total actuel à **+1** (l'arête `→ zcrud_core` d'un leaf ; `→ zcrud_export` compte aussi selon la lecture — au moins **+1**, cf. AD « 54 → 55+ »).

### Comment le rendu LaTeX est PROUVÉ

Un rendu visuel ne se prouve que par **golden** : `z_latex_rasterizer_golden_test.dart` dans `zcrud_export_ui` (le seul package qui a `flutter_math_fork` + peut pomper un widget) rend **≥ 2** formules de référence en PNG et les compare à des `.png` committés, + discriminant byte-diff (formules distinctes → octets distincts ; formule vide → repli `null`). Patron établi : `zcrud_study/test/golden/study_tools_page_golden_test.dart` (matchesGoldenFile + byte-diff discriminant, tolérance nulle). La **composition inline** (AC5), elle, se prouve dans `zcrud_export` par décodage des bytes PDF (nb de pages < une-image-par-formule + texte non-LaTeX extractible).

### Invariants AD applicables (spine study-ui + hérités AD-1..46)

- **AD-42** (fondateur de la story) : `zcrud_export` PUR bytes in/out ; LaTeX par port ; destination (preview/print/share) en satellite `zcrud_export_ui` avec `printing ^5.15.0` confiné, API `Uint8List`, `PdfPageFormat` absorbé.
- **AD-8** : dépendance lourde isolée derrière son satellite (`printing`, `flutter_math_fork` concret).
- **AD-1** : graphe acyclique, CORE OUT=0, arête `zcrud_*` sortante = `zcrud_core` (+ ici `zcrud_export`).
- **AD-10** : désérial/rendu défensif — jamais de throw du parent (dossier vide, carte malformée, LaTeX invalide, explication longue, Unicode/RTL).
- **AD-13** : RTL (`EdgeInsetsDirectional`, `TextAlign.start/end`), Semantics, cibles ≥ 48 dp sur la surface UI ; libellés l10n/thème, jamais codés en dur.
- **AD-12** : zéro secret/clé committé (aucune licence Syncfusion, pas de `badCertificateCallback`).
- **NFR-SU10** : le paquet neuf subit tous les gates CI comme ses pairs.
- **Enums > booléens** (Conventions spine) : `ZAnswerVisibility` (jamais `bool showAnswers`), `ZPdfOrientation` existant.

### Fichiers à créer / modifier

**`zcrud_export` (MODIFIÉ, reste pur) :**
- NEW `lib/src/domain/z_latex_rasterizer.dart` (port pur)
- NEW `lib/src/data/z_flashcard_pdf_template.dart` (Syncfusion confiné)
- NEW `lib/src/data/z_flashcard_pdf_input.dart` + `z_answer_visibility.dart` + `z_exported_file.dart` (neutres)
- UPDATE `lib/zcrud_export.dart` (exports ADDITIFS), `lib/src/data/z_export_api.dart` (`version 0.1.0 → 0.2.0`)
- NEW `test/z_flashcard_pdf_template_test.dart`, `test/z_inline_composition_test.dart`
- **NE PAS** toucher `z_pdf_exporter.dart`/`z_pdf_document_builder.dart`/`z_excel_exporter.dart` (parité SM-5)

**`zcrud_export_ui` (NOUVEAU) :**
- `pubspec.yaml`, `analysis_options.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`
- `lib/zcrud_export_ui.dart` (barrel, 0 symbole tiers), `lib/src/data/z_export_ui_api.dart`
- `lib/src/data/z_flutter_math_latex_rasterizer.dart` (SEUL import `flutter_math_fork`)
- `lib/src/data/z_pdf_share_service.dart` + `lib/src/presentation/z_pdf_preview.dart` (SEUL(S) import(s) `printing`)
- assets polices KaTeX si nécessaires (comme `zcrud_markdown`)
- `test/z_export_ui_confinement_test.dart`, `test/golden/z_latex_rasterizer_golden_test.dart` + `test/golden/goldens/*.png`

### Project Structure Notes

- Aligné sur la structure des pairs (`zcrud_export`, `zcrud_session`) : barrel `lib/<pkg>.dart`, impl `lib/src/{domain,data,presentation}`, `resolution: workspace`, version alignée `0.2.1`.
- Auto-inclusion melos : le glob `packages/*` prend le paquet neuf sans édition de `melos.yaml`/root pubspec (vérifier néanmoins la config workspace `pubspec.yaml` racine `workspace:` liste si énumérée explicitement).
- Conflit détecté et tranché : prose « printing dans zcrud_export » (session pubspec + dartdoc confinement) vs AD-42 (« printing dans zcrud_export_ui ») → AD-42 fait foi ; correction de prose optionnelle, jamais de la table à 2 paquets.

### Testing standards

- Fonction pure `zcrud_export` : `flutter test` **depuis** `packages/zcrud_export` (jamais depuis la racine pendant que les workstreams ∥ tournent).
- Golden : `flutter test --update-goldens` une fois, committer les `.png` (suivis git).
- Tests **porteurs** (discipline R3, leçons su-1..9) : chaque test rougit **par le COMPORTEMENT** (masquage réponses cassé → réponse ré-apparaît ; confinement cassé → leak témoin détecté). **Fake `ZLatexRasterizer`** en test (renvoie un PNG connu ou `null`) pour tester le template sous `flutter test` sans plateforme. Pièges bash évités : `grep -qF` (pas `-q` avec `$`), `flutter test` depuis le package.
- Baseline à confirmer avant `done` : `zcrud_export` **42** tests (RC=0), `zcrud_export_ui` neuf (ses tests verts), aucune régression repo-wide (`melos run analyze` RC=0).

### References

- [Source: epics-zcrud-study-ui-2026-07-16/epics.md#Story-1.11 (lignes 531-566)]
- [Source: ARCHITECTURE-SPINE.md#AD-42 (lignes 171-186), #AD-8 (45), #Placement-des-paquets (241-272), #Écarts-PRD (283)]
- [Source: prds/prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU16 (ligne 111), #OA-6 (232)]
- [Source: packages/zcrud_export/lib/src/data/z_pdf_exporter.dart, z_pdf_document_builder.dart, z_export_api.dart, lib/zcrud_export.dart, pubspec.yaml]
- [Source: packages/zcrud_flashcard/lib/src/domain/z_flashcard.dart, z_flashcard_type.dart, z_choice.dart]
- [Source: packages/zcrud_session/test/z_third_party_confinement_test.dart (patron garde tierce, leçons su-4/su-5 D2/R12)]
- [Source: packages/zcrud_markdown/test/math_lib_isolation_graph_test.dart (guard flutter_math_fork : core-purity + positif markdown, PAS single-owner)]
- [Source: packages/zcrud_markdown/lib/src/presentation/z_latex_embed.dart (Math.tex onErrorFallback, polices KaTeX)]
- [Source: packages/zcrud_study/test/golden/study_tools_page_golden_test.dart (patron golden discriminant)]
- [Source: scripts/dev/graph_proof.py (auto-découverte packages, Kahn, CORE OUT=0)]
- [Source: CLAUDE.md — invariants zcrud, gates codegen-distribution/secrets/graph_proof]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (workstream B, exécution parallèle disjointe su-10/su-12).

### Debug Log References

- Vérif verte SCOPÉE (jamais melos global — workstreams ∥ actifs) :
  - `packages/zcrud_export` : `flutter test` → **RC=0, 67 tests** (42 baseline + 25 su-11) ; `flutter analyze` → RC=0.
  - `packages/zcrud_export_ui` : `flutter test` → **RC=0, 24 tests** (18 confinement + 6 golden) ; `flutter analyze` → RC=0.
- `dart pub get` : résolution OK après ajout du membre workspace (printing 5.14.3, pdf 3.12.0, xml 6.6.1, flutter_math_fork 0.7.4).
- **Preuves R3 (injection → rouge par le COMPORTEMENT → restaurée + SHA-256 OK)** :
  1. Masquage réponses cassé (`withoutAnswers` force les réponses) → `ZREPONSESECRETE` réapparaît → test AC2 rouge.
  2. Confinement : import `package:printing/` injecté dans le barrel → garde `zcrud_export_ui` rouge (barrel + importers-count).
  3. Golden : `matchesGoldenFile` PROUVÉ NO-OP sous ce harnais (rendre une autre formule passait) ⇒ ajout d'une comparaison **octet-exact** vs PNG committé (rendu déterministe prouvé) ; mutation `fontSize 20→26` → golden rouge.

### Completion Notes List

- **AD-42 tenu** : `zcrud_export` reste PUR (aucun `printing`/`flutter_math_fork`, aucun `dart:ui` de rendu écran ; pubspec inchangé). `ZFlashcardPdfTemplate` = fonction pure bytes-out ; le port `ZLatexRasterizer` (PUR) déclaré dans `zcrud_export`, impl concrète (`flutter_math_fork` hors écran → PNG) dans `zcrud_export_ui`.
- **Composition inline (AC5)** prouvée : 6 formules inline tiennent sur < 6 pages (réf. une-image-par-page) + texte non-LaTeX extractible + formule rasterisée absente du texte.
- **AC2** : `ZAnswerVisibility` (enum) ; masquage prouvé par extraction de texte + bytes distincts.
- **AC9 (AD-10)** : dossier vide, carte malformée, LaTeX null/throw (repli texte), explication longue (>1 page), Unicode/RTL. **Défaut réel corrigé** : `PdfStandardFont` (WinAnsi) levait sur les glyphes non-Latin → sanitisation défensive (`_sanitize`, glyphes hors police → `?`), jamais de throw.
- **Confinement (AC7)** : garde propre `z_export_ui_confinement_test.dart` (table `printing` + `flutter_math_fork`), dé-commentateur YAML, motifs ancrés, garde-mot, contre-preuve R12 mutante. `flutter_math_fork` a DEUX déclarants légitimes (zcrud_markdown + zcrud_export_ui) → garde adaptée ; `printing` déclaré par le SEUL owner.
- **ÉCART TRANCHÉ (non-interactif, consigné)** : `printing ^5.15.0` ratifié est **non résolvable** (→ `pdf ^3.13.0` → `xml ^7.0.1`, conflit avec `xml ^6.5.0` de Syncfusion confiné à `zcrud_export`, intouchable SM-5 ; `version solving failed` prouvé). Contrainte abaissée à **`^5.14.0`** (5.14.3, `pdf ^3.10.0`/`xml 6.x`) — même API preview/print/share, même surface `Uint8List`.
- **Proses à réconcilier (NON éditées — autres packages)** : `zcrud_markdown/pubspec.yaml` (« flutter_math_fork ISOLÉE au seul pubspec zcrud_markdown » — désormais imprécis, l'invariant « aucun type flutter_math_fork ne fuit de zcrud_markdown » reste VRAI) ; `zcrud_session` pubspec:75 + dartdoc confinement:77 (« printing vit dans zcrud_export » — faux vs AD-42, printing vit dans zcrud_export_ui). Table de confinement de session laissée à 2 paquets.
- **Gate REPO-WIDE (à rejouer par l'orchestrateur au repos)** : `graph_proof.py` (nouveau nœud leaf `zcrud_export_ui`, arêtes sortantes zcrud_* = `zcrud_export` + `zcrud_core` uniquement, acyclique, CORE OUT=0) ; `melos run analyze`/`verify` repo-wide ; `melos list` +1 membre.

### File List

**`zcrud_export` (modifié, reste PUR) :**
- NEW `packages/zcrud_export/lib/src/domain/z_latex_rasterizer.dart`
- NEW `packages/zcrud_export/lib/src/data/z_flashcard_pdf_template.dart`
- NEW `packages/zcrud_export/lib/src/data/z_flashcard_pdf_input.dart`
- NEW `packages/zcrud_export/lib/src/data/z_answer_visibility.dart`
- NEW `packages/zcrud_export/lib/src/data/z_exported_file.dart`
- MOD `packages/zcrud_export/lib/zcrud_export.dart` (exports additifs, tri alphabétique)
- MOD `packages/zcrud_export/lib/src/data/z_export_api.dart` (version 0.1.0 → 0.2.0)
- NEW `packages/zcrud_export/test/z_flashcard_pdf_template_test.dart`
- NEW `packages/zcrud_export/test/z_inline_composition_test.dart`
- NEW `packages/zcrud_export/test/support/pdf_flashcard_support.dart`

**`zcrud_export_ui` (NOUVEAU) :**
- `packages/zcrud_export_ui/pubspec.yaml`, `analysis_options.yaml`, `README.md`, `CHANGELOG.md`, `LICENSE`
- `packages/zcrud_export_ui/lib/zcrud_export_ui.dart` (barrel, 0 symbole tiers)
- `packages/zcrud_export_ui/lib/src/data/z_export_ui_api.dart`
- `packages/zcrud_export_ui/lib/src/data/z_flutter_math_latex_rasterizer.dart` (SEUL import flutter_math_fork)
- `packages/zcrud_export_ui/lib/src/data/z_pdf_share_service.dart` (import printing)
- `packages/zcrud_export_ui/lib/src/presentation/z_pdf_preview.dart` (import printing)
- `packages/zcrud_export_ui/test/z_export_ui_confinement_test.dart`
- `packages/zcrud_export_ui/test/golden/z_latex_rasterizer_golden_test.dart` + `test/golden/goldens/latex_quadratic.png` + `latex_fraction.png`

**Racine :**
- MOD `pubspec.yaml` (membre workspace `packages/zcrud_export_ui`)
- MOD `pubspec.lock` (résolution ; EXCLU du commit d'epic)
