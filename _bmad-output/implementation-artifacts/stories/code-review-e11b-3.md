# Code Review — E11b-3 : zcrud_export complet

- **Story** : `_bmad-output/implementation-artifacts/stories/e11b-3-zcrud-export-complet.md`
- **Baseline** : `04aaaf0` (frontmatter story) → working tree
- **Périmètre** : `packages/zcrud_export/` UNIQUEMENT (8 fichiers créés + 6 modifiés + 4 tests créés)
- **Mode skill** : `bmad-code-review` invoqué via le tool `Skill` (step-file architecture). Revue adversariale conduite en interne par l'orchestrateur de revue sur les 3 axes (Blind Hunter / Edge Case Hunter / Acceptance Auditor) — subagents parallèles non requis (diff 378 l. + 8 nouveaux fichiers, sous le seuil de chunking).
- **Date** : 2026-07-10

## Verdict : PRÊT POUR `done`

Aucun finding HIGH / MAJEUR / MEDIUM. 3 LOW (nits, aucun bloquant). Les 12 ACs sont satisfaits, l'isolation Syncfusion et les invariants AD-1/AD-8/AD-10/AD-12 sont respectés, l'API est strictement additive.

## Vérif verte rejouée sur disque (export uniquement)

| Gate | Commande | Résultat réel |
|------|----------|---------------|
| pub get | `dart pub get` | RC 0 (Got dependencies) |
| analyze | `dart analyze packages/zcrud_export` | **No issues found!** RC 0 |
| test | `flutter test packages/zcrud_export` | **All tests passed — 42 tests** RC 0 |
| graphe AD-1 | `python3 scripts/dev/graph_proof.py` | ACYCLIQUE OK, **CORE OUT=0 OK**, 19 arêtes / 14 nœuds |
| compat E1-4 | `dart pub get --dry-run` | Would get dependencies, RC 0 |

## Confirmations transversales (axes du mandat)

- **API export STABLE/ADDITIVE** ✅ — `ZExportApi`, `ZExporter`, `ZExportTable` toujours exportés par le barrel (aucun retrait/renommage). Ajouts additifs : `ZPdfCreationService`, `ZFileSaver`, `ZFileSaveResult`, `ZPdfExportOptions`, `ZPdfOrientation`. `ZExportApi.version` bumpé `0.0.1 → 0.1.0`, **nom `version` inchangé** (consommé par `zcrud_flashcard`). Verrouillé par `api_surface_test.dart` (compile-time). La régression historique (suppression de `ZExportApi` en E11a-3) n'est PAS reproduite.
- **Syncfusion confiné (AD-8)** ✅ — `grep` confirme : seuls `lib/src/data/z_pdf_exporter.dart`, `z_pdf_document_builder.dart`, `z_excel_exporter.dart` importent `package:syncfusion`. Aucune réexportation par le barrel. Toutes les sorties = `Uint8List` neutre → fuite de type structurellement impossible. Gate d'isolation durci : allowlist Syncfusion + fichiers publics DÉRIVÉS dynamiquement (clôt LOW-2 d'E11a-3).
- **Web sans `dart:html`** ✅ — `z_file_saver_web.dart` utilise `package:web` + `dart:js_interop` (Blob → `createObjectURL` → ancre `download` → `revokeObjectURL`). `dart:html` n'apparaît que dans des doc-comments (contre-exemples), aucun import réel. Imports conditionnels stub/io/web corrects (`dart.library.io` → io, `dart.library.js_interop` → web). io via `dart:io` sans `path_provider`.
- **Zéro secret (AD-12)** ✅ — aucun `registerLicense(...)` ni `badCertificateCallback` en CODE (seule occurrence : doc-comment `z_exporter.dart:21` documentant que la licence appartient à l'app hôte). Aucun `HttpClient`/`package:http`/appel réseau. Gate no-secret/no-badcert/no-réseau étendu à tout `lib/`.
- **ZPdfCreationService défensif** ✅ — décodage `PdfBitmap` en try/catch AVANT `pages.add()` (bytes non décodables → page sautée, aucune page orpheline) ; liste vide → garantie d'au moins 1 page (`pages.count == 0 → add()`) ; `dispose()` en `finally` sur tous les chemins ; fit-to-page `min(w/imgW, h/imgH)` centré, gardé par `imgW>0 && imgH>0`. Vérifié par 8 tests (contenu réel via ré-ouverture `PdfDocument`).
- **Anti-rognage** ✅ — `grid.style.allowHorizontalOverflow = true` + police compacte : la dernière colonne (en-tête `Colonne15` ET valeur `v15`) est extraite par `PdfTextExtractor` sur une table à 16 colonnes → clôt LOW-1 d'E11a-3.

## Findings

### HIGH / MAJEUR / MEDIUM
Aucun.

### LOW

**LOW-1 — Téléchargement web : ancre non attachée au DOM + `revokeObjectURL` synchrone**
`packages/zcrud_export/lib/src/data/z_file_saver_web.dart:37-41`
L'ancre `<a download>` est cliquée sans être insérée dans `document.body`, et `URL.revokeObjectURL(url)` est appelé synchroniquement juste après `anchor.click()`. Le pattern fonctionne sur les navigateurs modernes (Chrome/Edge/Safari traitent le download pendant le dispatch synchrone du click, l'URL Blob est lue avant le retour de `click()`), mais reste plus robuste, historiquement, avec append/remove de l'ancre et une révocation différée (microtask/`setTimeout`) — angle mort pour d'anciennes versions Firefox.
*Impact* : robustesse/portabilité navigateur uniquement ; NON exerçable sous `flutter test` (VM charge io/stub) — couvert seulement par le gate statique. Aucun crash prouvé.
*Recommandation (optionnel, v1.x)* : `document.body.appendChild(anchor)` avant `click()`, `anchor.remove()` après, et différer `revokeObjectURL` (p. ex. `Future.microtask`). À laisser en dette consignée : pattern actuel = standard, sans régression testable.

**LOW-2 — « Rétro-compat E11a-3 inchangé » (AC9) est vrai au niveau API/parité, pas au pixel**
`packages/zcrud_export/lib/src/data/z_pdf_exporter.dart:88-90`
Même sans `options`, `buildPdfBytes` applique désormais INCONDITIONNELLEMENT `grid.style.font = helvetica 8` et `allowHorizontalOverflow = true`. Le rendu PDF par défaut change donc par rapport à E11a-3, alors que l'AC9 dit « appel sans options = comportement E11a-3 inchangé ».
*Impact* : nul — ce comportement est en réalité **requis** par le test AC10 qui appelle `toPdfBytes(request)` SANS options et exige la dernière colonne. La parité de contenu SM-5 (`col.format`, valeurs `Colonne0`/`v0`) reste préservée (testée). C'est une imprécision de formulation de l'AC9, résolue correctement vers AC10 ; le fix anti-rognage s'applique par défaut, ce qui est souhaitable.
*Recommandation* : aucune modification de code. Noter que « rétro-compat » couvre la signature (paramètre optionnel) + la parité de contenu, pas le rendu pixel.

**LOW-3 (nit) — Denylist `_syncfusionTypes` du gate non exhaustive**
`packages/zcrud_export/test/isolation_gates_test.dart:27-37`
Le scan « aucun type Syncfusion en signature publique » repose sur une liste de 9 noms de types (`Workbook`, `PdfGrid`, `PdfBitmap`…) qui n'inclut pas `PdfGraphics`, `PdfPageOrientation`, `PdfLayoutFormat`, `PdfPageSettings`, etc.
*Impact* : négligeable — la neutralité est déjà garantie STRUCTURELLEMENT par le test d'import-confinement (tout fichier important Syncfusion DOIT être un backend `src/data/z_*.dart`) + le fait que toute sortie publique est `Uint8List`. Ce scan de noms n'est qu'une ceinture secondaire.
*Recommandation (optionnel)* : soit documenter cette limite, soit dériver la neutralité du seul test d'import (déjà dérivé dynamiquement). Non bloquant.

## Notes de conformité

- **Périmètre respecté** : aucune édition hors `packages/zcrud_export/`. `zcrud_core` intact (`git status` : aucun fichier core modifié). Tous les types nouveaux sont locaux (bytes/images/options).
- **Dédup DODLP/IFFD** : `ZPdfCreationService` est bien la source unique (backend confiné `z_pdf_document_builder.dart`), aucun second stack PDF (`pdf`/`printing` absents), réutilise `syncfusion_flutter_pdf` déjà déclaré.
- **Dépendance `web: ^1.1.0`** ajoutée au SEUL `zcrud_export/pubspec.yaml` ; n'affecte pas `graph_proof.py` (pas un package `zcrud_*`) ; gate compat E1-4 vert.
- **Non-régression cross-package** (`zcrud_flashcard` consommant `ZExportApi.version`) : hors périmètre de cette revue, à reconfirmer par l'orchestrateur au gate d'epic via `melos run analyze` REPO-WIDE (flashcard en dev E9-5 actuellement).
- **Qualité des tests (42)** : contenu réel vérifié (ré-ouverture `PdfDocument`, `PdfTextExtractor`, relecture disque `readAsBytes`), défensif couvert (vide/garbage/bytes vides), rétro-compat + `==`/`hashCode` verrouillés. Limite web (non exerçable VM) correctement couverte par gate statique et documentée.

---

## Résolution (orchestrateur)

Vérif verte (export) : `dart analyze packages/zcrud_export` RC=0, `flutter test packages/zcrud_export` **42 tests** RC=0, `graph_proof` CORE OUT=0 / ACYCLIQUE, `dart pub get --dry-run` RC=0.

- **0 HIGH / 0 MAJEUR / 0 MEDIUM.**
- **LOW-1/2/3 — CONSIGNÉS** (nits, non bloquants) : LOW-1 ancre web `<a download>` non attachée + révocation synchrone (pattern standard OK navigateurs modernes ; robustification append/remove + révocation différée = optionnel v1.x, non exerçable sous VM) ; LOW-2 rendu PDF par défaut (font helvetica 8 + allowHorizontalOverflow) change vs E11a-3 au niveau pixel mais REQUIS par le test AC10 (dernière colonne visible), parité de contenu SM-5 préservée ; LOW-3 denylist Syncfusion non exhaustive (neutralité déjà garantie par le gate d'import-confinement + sorties Uint8List).
- API export **additive** (ZExportApi/ZExporter/ZExportTable intacts, version 0.0.1→0.1.0, verrouillé par api_surface_test), Syncfusion confiné (3 backends src/data), pas de dart:html (web via package:web + dart:js_interop), zéro secret.

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert. Non-régression cross-package flashcard (consomme ZExportApi) à reconfirmer au gate d'epic REPO-WIDE.
