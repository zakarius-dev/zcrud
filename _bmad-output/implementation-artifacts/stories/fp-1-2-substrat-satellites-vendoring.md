---
baseline_commit: be9dc4402929f463f565ea336b88cabdf9adf995
---

# Story fp-1.2: Substrat satellites — squelettes des 4 packages neufs + vendoring `awesome_select`

Status: review

<!-- Épic E-FORM-PARITY (Formulaire : parité DODLP totale). Story de FONDATION « substrat satellites ».
     Parallélisée avec fp-1-1 (qui écrit zcrud_core) : cette story NE TOUCHE PAS packages/zcrud_core/. -->

## Story

As a **mainteneur zcrud**,
I want les **squelettes** de `zcrud_select` / `zcrud_html` / `zcrud_media` / `zcrud_field_extras` et le **vendoring** d'`awesome_select` comme membre de workspace melos **privé**,
so that les adaptateurs de parité MVP/Média-rich (fp-4-1/4-2/4-3) et le fork SmartSelect disposent d'un **emplacement conforme, gardé et résolu offline** *avant* d'être écrits — sans jamais toucher le cœur ni introduire de dépendance lourde prématurée.

## Contexte & périmètre (LIRE AVANT DE CODER)

**Nature de la story : SUBSTRAT / ASSEMBLAGE, pas d'adaptateur métier.** On crée des **coquilles** (pubspec + barrel + arbre `lib/src/{domain,data,presentation}` + placeholder documenté + test de garde) et on **vendorise** la source d'`awesome_select`. Aucune logique de champ, aucun `register()`, aucun binding.

**Disjonction avec fp-1-1 (parallélisation, cœur au repos) — NON-NÉGOCIABLE :**
- fp-1-1 est la **seule** story qui écrit `packages/zcrud_core/` (séquencée, CORE-SÉRIALISÉE).
- **fp-1-2 N'ÉCRIT RIEN dans `packages/zcrud_core/`.** Elle crée de NOUVEAUX répertoires `packages/*` et édite les points d'assemblage racine (`pubspec.yaml` bloc `workspace:`, éventuellement `melos.yaml` — voir Dev Notes) et `packages/*/pubspec.yaml`.
- Si un besoin d'écrire dans le cœur apparaît (ex. une abstraction manquante), **STOP + SIGNALER** : à re-séquencer derrière fp-1-1, pas à faire en parallèle.
- Fichiers disjoints des autres stories en vol. Le seul point de contact possible serait `zcrud_core` — **exclu ici par conception**.

**Contrainte de dépôt :** SEUL `/home/zakarius/DEV/zcrud` est modifiable. Repos d'app (dodlp-otr, etc.) = LECTURE SEULE.

**Frontières (HORS fp-1-2) :** PAS les adaptateurs (`SmartSelect`/média/HTML/PIN = fp-4-1/4-2/4-3 & Finitions) · PAS le seam cœur `ZSelectPresenter` (fp-1-1) · PAS le câblage `registerZ<Pkg>Fields`/binding (fp-2-2). Ici : coquilles + vendor + membres workspace + gates.

## Acceptance Criteria

Chaque AC = fichier réel sur disque + garde falsifiable + preuve de graphe (acyclique / CORE OUT=0). Aucune vérif non rejouée ne peut être affirmée. Toute « absence » = grep négatif (commande + RC).

**AC1 — Squelette `zcrud_select`.**
**Given** le workspace melos *(AR-3 / AD-48)*
**When** on crée `packages/zcrud_select/`
**Then** il expose `pubspec.yaml` (`name: zcrud_select`, `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2`), un barrel `lib/zcrud_select.dart`, l'arbre `lib/src/{domain,data,presentation}` avec ≥ 1 placeholder documenté (référençant AD-48 : « présentateur `ZSelectPresenter` à venir en fp-4-1 »), et une garde de pureté/confinement `test/z_select_confinement_test.dart` (patron `zcrud_export_ui`). **Parmi les arêtes `zcrud_*`, `zcrud_select → zcrud_core` uniquement** ; l'arête `zcrud_select → awesome_select` (non-`zcrud_*`, invisible `graph_proof`) est **posée ici** (voir écart tranché ET-1) et gardée par la garde vendor (AC5).

**AC2 — Squelette `zcrud_html`.**
**Given** le workspace *(AD-50)*
**When** on crée `packages/zcrud_html/`
**Then** mêmes exigences (barrel `lib/zcrud_html.dart`, arbre `lib/src/…`, placeholder référençant AD-50 : « WebView à controller isolé, `html`/`inlineHtml` exclusifs avec `zcrud_markdown` »), garde `test/z_html_confinement_test.dart`. **Arête `zcrud_*` sortante = `zcrud_core` UNIQUEMENT** ; **aucune** dep lourde (`html_editor_enhanced`/`flutter_html`) ajoutée à ce stade (elles arrivent en fp-4-3, confinées à l'impl).

**AC3 — Squelette `zcrud_media`.**
**Given** le workspace *(AD-51)*
**When** on crée `packages/zcrud_media/`
**Then** mêmes exigences (barrel `lib/zcrud_media.dart`, placeholder référençant AD-51 : « câble le contrat cœur existant `ZFilePicker`/`ZFileSource`, API neutre `Uint8List`/chemins »), garde `test/z_media_confinement_test.dart`. **Arête `zcrud_*` sortante = `zcrud_core` UNIQUEMENT** ; **aucune** dep média (`image_cropper`/`camera`/…) ajoutée ici (fp-4-2).

**AC4 — Squelette `zcrud_field_extras`.**
**Given** le workspace *(AD-53)*
**When** on crée `packages/zcrud_field_extras/`
**Then** mêmes exigences (barrel `lib/zcrud_field_extras.dart`, placeholder référençant AD-53 : « PIN/autocomplete/table éditable/icon servis par `ZWidgetRegistry`, deps légères confinées »), garde `test/z_field_extras_confinement_test.dart`. **Arête `zcrud_*` sortante = `zcrud_core` UNIQUEMENT** ; **aucune** dep (`pinput`/…) ajoutée ici (Finitions).

**AC5 — Vendoring privé `packages/awesome_select`.**
**Given** la source du fork `awesome_select` (pub.dev 6.0.0, MIT — présente au cache `~/.pub-cache/hosted/pub.dev/awesome_select-6.0.0/`) *(AR-1 / AD-49)*
**When** elle entre sous `packages/awesome_select/`
**Then** le package est **membre de workspace privé** (`publish_to: none`, `resolution: workspace`, `environment.sdk` aligné `^3.12.2`), la **licence MIT est conservée** (fichier `LICENSE` original — attribution `Copyright (c) 2021 Akbar Pulatov` **préservée** — + note d'attribution/fork dans `README.md`/en-tête pubspec), il **résout offline** (`dart pub get` OK, aucun `git:`/`hosted:` étranger), passe les **mêmes gates repo** (graph_proof, secrets, codegen-distribution, analyze), et il est **dépendu uniquement par `zcrud_select`** (garde déclarer, patron `z_export_ui_confinement_test`). **Aucun type `awesome_select` ne fuit** en signature publique d'un package zcrud (AD-40 — trivialement vrai au stade squelette : `zcrud_select` n'importe encore rien).

**AC6 — Membres du workspace visibles & résolus.**
**Given** les 5 nouveaux répertoires *(Distribution / Consistency Conventions)*
**When** ils sont enrôlés dans le bloc `workspace:` du root `pubspec.yaml` (source de vérité de résolution ; `melos.yaml` reste en glob `packages/**`)
**Then** `dart pub get` (racine) résout sans conflit, `melos list` **voit les 5 nouveaux membres** (`zcrud_select`, `zcrud_html`, `zcrud_media`, `zcrud_field_extras`, `awesome_select`), et chaque nouveau package passe **`dart analyze .`** (RC=0) — y compris le vendor (via son `analysis_options.yaml` propre, hérité du cache).

**AC7 — Gates verts repo-wide + cœur intact (preuve de disjonction).**
**Given** l'état post-création *(AD-1 / AD-12 / ES-1-D1)*
**When** on rejoue les gates repo-wide
**Then** `python3 scripts/dev/graph_proof.py` imprime **`ACYCLIC OK`** + **`CORE OUT=0 OK`** (les seules arêtes `zcrud_*` nouvelles : `zcrud_select/html/media/field_extras → zcrud_core`), `gate:secrets` OK (aucun secret dans le vendor), `gate:codegen-distribution` OK (squelettes sans codegen → no-op propre), et `git status`/`git diff --stat` prouve **zéro modification sous `packages/zcrud_core/`** (disjonction fp-1-1 respectée).

## Tasks / Subtasks

- [x] **T1 — Squelette `zcrud_select`** (AC1)
  - [x] `packages/zcrud_select/pubspec.yaml` : `name`, `description`, `version: 0.2.1`, `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2` ; `dependencies:` = `flutter (sdk)`, `zcrud_core: ^0.2.1`, `awesome_select: ^6.0.0` (arête vendor — ET-1) ; `dev_dependencies:` = `flutter_test (sdk)`.
  - [x] Barrel `lib/zcrud_select.dart` (dartdoc : rôle AD-48, `library;`) exportant le placeholder.
  - [x] Arbre `lib/src/domain/`, `lib/src/data/`, `lib/src/presentation/` + placeholder documenté (ex. `lib/src/presentation/z_select_presenter_placeholder.dart` — commentaire pointant AD-48 et fp-4-1, **aucun** import `awesome_select`).
  - [x] `analysis_options.yaml` (aligné sur le patron repo — `include:` du lint partagé s'il existe, sinon minimal).
  - [x] `test/z_select_confinement_test.dart` — garde de pureté (voir Dev Notes « Garde falsifiable »).
  - [x] `LICENSE` (MIT Zakarius, patron `zcrud_export_ui`), `README.md`, `CHANGELOG.md` minimaux.
- [x] **T2 — Squelette `zcrud_html`** (AC2) — idem T1, **sans** arête `awesome_select`, dep `zcrud_*` sortante = `zcrud_core` seule ; placeholder → AD-50 ; garde `test/z_html_confinement_test.dart`.
- [x] **T3 — Squelette `zcrud_media`** (AC3) — idem, placeholder → AD-51 (contrat `ZFilePicker`) ; garde `test/z_media_confinement_test.dart`.
- [x] **T4 — Squelette `zcrud_field_extras`** (AC4) — idem, placeholder → AD-53 ; garde `test/z_field_extras_confinement_test.dart`.
- [x] **T5 — Vendoring `packages/awesome_select`** (AC5)
  - [x] Copier la source depuis `~/.pub-cache/hosted/pub.dev/awesome_select-6.0.0/` : `lib/`, `LICENSE`, `README.md`, `CHANGELOG.md`, `analysis_options.yaml`. **NE PAS** copier `example/`, `demo/`, `test/` du paquet amont (surface inutile ; garder le vendor minimal — décision conservatrice ET-2) sauf si nécessaire à `pub get`.
  - [x] Réécrire `packages/awesome_select/pubspec.yaml` : `publish_to: none`, `resolution: workspace`, `environment.sdk: ^3.12.2` (alignement workspace), en-tête d'attribution (fork MIT, source pub.dev 6.0.0), `dependencies:` amont conservées (`flutter (sdk)`, `collection: ^1.16.0`).
  - [x] Vérifier que `LICENSE` conserve **le copyright original** (Akbar Pulatov 2021) + ajouter mention de fork.
- [x] **T6 — Garde du confinement vendor** (AC5) — dans `packages/zcrud_select/test/z_select_confinement_test.dart` (ou fichier dédié) : `awesome_select` déclaré **EXACTEMENT** par `zcrud_select` parmi tous les `packages/*/pubspec.yaml` (patron déclarer `z_export_ui_confinement_test`), + assertion « le barrel `zcrud_select` n'exporte aucun symbole `awesome_select` », + contre-preuve R12 mutante.
- [x] **T7 — Enrôlement workspace** (AC6) — ajouter les 5 membres au bloc `workspace:` du root `pubspec.yaml` (ordre/commentaires cohérents). Vérifier `melos.yaml` (glob `packages/**` couvre déjà ; pas d'`ignore` à ajouter). `dart pub get` racine.
- [x] **T8 — Vérif verte repo-wide + disjonction** (AC6/AC7)
  - [x] `python3 scripts/dev/graph_proof.py` → `ACYCLIC OK` + `CORE OUT=0 OK`.
  - [x] `dart run melos run analyze` (repo-wide) RC=0.
  - [x] `flutter test` **par nouveau package** (les 4 gardes) RC=0 — **PAS** `melos run test` global (peut se bloquer).
  - [x] `gate:secrets` + `gate:codegen-distribution` OK ; `melos list` = 5 membres neufs visibles.
  - [x] `git diff --stat -- packages/zcrud_core` → **VIDE** (preuve disjonction fp-1-1).

## Dev Notes

### Patron de référence (à IMITER sur disque, ne pas réinventer)
- **Satellite modèle : `packages/zcrud_export_ui/`** (su-11) — pubspec `publish_to: none` + `resolution: workspace` + `environment.sdk: ^3.12.2` ; barrel `lib/zcrud_export_ui.dart` (`library;` + `export 'src/...' show ...`) ; arbre `lib/src/{data,presentation}` ; `LICENSE`/`README.md`/`CHANGELOG.md`. **Nos squelettes ajoutent `lib/src/domain/`** (couche pure) même vide-avec-placeholder pour matérialiser l'hexagone.
- **Satellite pur minimal : `packages/zcrud_responsive/`** — `dependencies: { zcrud_core: ^0.2.1, flutter }`, `dev_dependencies: { flutter_test }`. C'est exactement la forme d'un squelette **sans** dep tierce (html/media/field_extras).
- **Garde de confinement : `packages/zcrud_export_ui/test/z_export_ui_confinement_test.dart`** — dé-commentateur YAML ancré (`_stripYaml`), `_yamlDeclares(pkg)`, scan des `packages/*/pubspec.yaml`, garde-mot `_wholeType`, **contre-preuves R12 mutantes**. C'est le patron pour T6 (déclarer `awesome_select` = exactement `zcrud_select`).

### Garde falsifiable pour un SQUELETTE (T1-T4) — conception
Un squelette n'a pas (encore) de dep tierce à confiner. La garde doit néanmoins **rougir si le package gagnait une dépendance interdite** ou **importait un paquet non autorisé**. Deux volets falsifiables :
1. **Volet pubspec (déclaration = arête)** : lire `packages/<pkg>/pubspec.yaml` (dé-commenté YAML), extraire les clés du bloc `dependencies:`, asserter que l'ensemble ⊆ **allowlist** `{flutter, zcrud_core}` (pour `zcrud_select`, ajouter `awesome_select`). Contre-preuve R12 : un fixture pubspec avec `image_cropper: ^12.2.1` **DOIT** faire rougir la règle (prouver que la règle sait détecter un intrus).
2. **Volet import (lib/**)** : scanner `lib/**` (dé-commenté Dart), asserter qu'aucun `import 'package:<X>/'` n'apparaît hors allowlist `{flutter, zcrud_core, <self>}`. Contre-preuve R12 : une chaîne témoin `import 'package:image_cropper/...'` est vue comme fuite ; `import 'package:zcrud_core/...'` ne l'est pas.
> ⚠️ **Falsifiabilité prouvée par CONSTRUCTION** (leçon su-5/su-11) : inclure les tests-témoins `probeLeak`/`probeOwn` (la règle voit une vraie fuite ET ignore un import légitime). Sans ces témoins, la garde est déclarative. Dé-commentateur du **bon langage** (`#` pour YAML, `//` pour Dart) — ne jamais appliquer `_stripDart` à un pubspec.

### Vendoring `awesome_select` — points durs
- **Source disponible offline** : `~/.pub-cache/hosted/pub.dev/awesome_select-6.0.0/` (vérifié). Deps amont = `flutter (sdk)` + `collection: ^1.16.0` (paquet standard Dart, **non** `zcrud_*`, invisible `graph_proof` — OK).
- **`resolution: workspace` impose l'alignement SDK** : le pubspec amont a son propre `environment`. Le réécrire en `environment.sdk: ^3.12.2` pour matcher le workspace. Risque : le code vendoré peut lever des lints/erreurs sous une toolchain récente → **conserver son `analysis_options.yaml` amont** (il ship souvent des exclusions) ; si `dart analyze .` rougit sur du code tiers, assouplir via l'`analysis_options.yaml` **du vendor uniquement** (jamais globalement), et le **documenter** en en-tête. Ne PAS éditer la logique amont (ce n'est pas notre code — le garder substituable/fork).
- **`graph_proof` est aveugle à `awesome_select`** (il ne suit que les arêtes `zcrud_*`) : l'arête `zcrud_select → awesome_select` **et** l'invariant « dépendu uniquement par `zcrud_select` » sont gardés par **T6** (garde déclarer), pas par `graph_proof`. Le déclarer honnêtement (leçon E10 : « un garde ne prouve QUE ce qu'il scanne »).
- **`gate:compat`** (`tool/compat_check`, dry-run `flutter_quill+awesome_select+analyzer`) référence déjà `awesome_select` : vérifier qu'il n'entre pas en conflit avec le membre workspace (il exige la toolchain Flutter ; ne pas le rejouer si la toolchain est absente — le noter, ne pas simuler vert).

### Écarts tranchés (mode non-interactif → option CONSERVATRICE, consignée)
- **ET-1 — Arête `zcrud_select → awesome_select` POSÉE ICI (fp-1-2), pas reportée en fp-4-1.** Rationale : AD-49 fait d'`awesome_select` une **feuille dépendue du SEUL `zcrud_select`** ; poser l'arête au moment du vendoring (a) rend le graphe final et **acyclique dès la naissance**, (b) donne un sens à la garde déclarer T6 (« exactement `zcrud_select` » plutôt qu'« exactement personne » — un orphelin est plus fragile à garder), (c) permet la **résolution offline immédiate** sous notre tag (raison d'être d'AD-49). Une dépendance déclarée mais non encore importée est licite pour un squelette (l'adaptateur SmartSelect qui l'importera est fp-4-1). Le task-brief autorise explicitement « posée ici ou en fp-4-1 (tranche) » → **tranché : ici**.
- **ET-2 — Vendor minimal : ne PAS copier `example/`/`demo/`/`test/` du paquet amont.** Rationale : réduire la surface de maintenance (NFR-9) et le risque de secrets/deps de démo ; ne garder que `lib/` + `LICENSE` + `README.md` + `CHANGELOG.md` + `analysis_options.yaml`. Si `dart pub get`/`analyze` exige un fichier amont supplémentaire, l'ajouter au minimum et le consigner.
- **ET-3 — `lib/src/domain/` matérialisé même vide (avec placeholder).** Rationale : rendre l'hexagone (domain/data/presentation) visible dès le squelette (cohérence Consistency Conventions), plutôt qu'un `lib/src/` plat.

### Invariants applicables (rappel, NON-NÉGOCIABLES)
- **AD-1** : graphe acyclique ; **CORE OUT=0** ; chaque satellite ne dépend que de `zcrud_core` (+ sa/ses dep(s) tierce(s) propre(s) — ici seul `zcrud_select` en a une : le vendor). `zcrud_core` **inchangé**.
- **AD-40** : aucun type `awesome_select` en signature publique (trivial au stade squelette ; gardé pour l'avenir).
- **AD-12** : zéro secret dans un package (scan du vendor).
- **Distribution en dép. git** : membres versionnés/contraints comme leurs pairs (`^0.2.1`), soumis aux gates repo. Un squelette n'a pas de codegen → `gate:codegen-distribution` no-op propre (aucun `part` vers un fichier gitignoré).
- **Nommage** : préfixe `Z` pour les types publics ; barrel `lib/<pkg>.dart` ; `lib/src/{domain,data,presentation}`.

### Pièges de vérification (discipline de réalité)
- `grep | head` **masque le RC** → utiliser `grep -q` (RC explicite) pour toute preuve d'absence.
- `melos run test` **peut se bloquer** (Flutter) → lancer `flutter test` **par package** ciblé.
- `git checkout`/`git restore` **interdits** (destructif).
- Toute « absence » (ex. « le barrel n'exporte pas `awesome_select` ») = **grep négatif** (commande + RC=1) ou assertion de test, jamais une affirmation nue.

### Project Structure Notes
- Point d'enrôlement de résolution = **bloc `workspace:` du root `pubspec.yaml`** (source de vérité ; `melos.yaml` = glob `packages/**`, aucun `ignore` à ajouter pour ces 5 membres). Insérer les 5 entrées avec commentaires cohérents avec le style existant (cf. blocs `zcrud_export_ui`, `zcrud_responsive`).
- Conflit potentiel : `resolution: workspace` + SDK amont du vendor → aligner `environment.sdk`. Variance assumée : le vendor porte son propre `analysis_options.yaml` (code tiers), documenté.

### References
- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story-1.2] (AC source, marquage AR-1/AR-3, Binds AD-49/50/51/53)
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-form-parity-2026-07-18/ARCHITECTURE-SPINE.md#AD-49] (vendoring workspace privé, MIT, dépendu du seul zcrud_select)
- [Source: …/ARCHITECTURE-SPINE.md#AD-48] (zcrud_select + ZSelectPresenter) · [#AD-50] (zcrud_html WebView isolée) · [#AD-51] (zcrud_media, ZFilePicker) · [#AD-53] (zcrud_field_extras)
- [Source: …/ARCHITECTURE-SPINE.md#Direction-de-dépendance] (graphe : vendor = feuille privée, satellites → core, CORE OUT=0) · [#Consistency-Conventions] (Distribution : membre workspace, gates repo)
- [Source: …/ARCHITECTURE-SPINE.md#AD-1] (acyclique, CORE OUT=0) · [#AD-40] (pas de type tiers en signature) · [#AD-12] (zéro secret)
- [Pattern: packages/zcrud_export_ui/pubspec.yaml] · [packages/zcrud_export_ui/lib/zcrud_export_ui.dart] · [packages/zcrud_export_ui/test/z_export_ui_confinement_test.dart]
- [Pattern: packages/zcrud_responsive/pubspec.yaml] (satellite pur core-only)
- [Gates: scripts/dev/graph_proof.py (ACYCLIC + CORE OUT=0) ; pubspec.yaml bloc `melos:` (gate:secrets, gate:codegen-distribution, verify) ; melos.yaml]
- [Source vendor: ~/.pub-cache/hosted/pub.dev/awesome_select-6.0.0/ (MIT, deps: flutter + collection ^1.16.0)]

## Dev Agent Record

### Agent Model Used

Opus 4.8 (1M context) — `bmad-dev-story` (skill réel invoqué).

### Debug Log References

Vérif verte rejouée réellement sur disque (RC réels) :
- `dart pub get --offline` (racine) → **RC=0** (résolution workspace offline ; `awesome_select` 6.0.0 depuis `~/.pub-cache`, `flutter_lints` remonté 5.0.0 pour compat `lints ^5`).
- `python3 scripts/dev/graph_proof.py` → **RC=0**, `ACYCLIQUE OK` + `CORE OUT=0 OK`, 61 arêtes. Seules arêtes `zcrud_*` neuves : `zcrud_select→zcrud_core`, `zcrud_html→zcrud_core`, `zcrud_media→zcrud_core`, `zcrud_field_extras→zcrud_core`. `awesome_select` invisible (non-`zcrud_*`).
- `dart analyze .` : `zcrud_select` / `zcrud_html` / `zcrud_media` / `zcrud_field_extras` → **RC=0** (No issues). `awesome_select` → initialement **RC=3** (4 erreurs d'API Flutter retirées depuis la cible amont Flutter 3.0 : `ThemeData.errorColor`, `TextTheme.headline6` ×2, `S2ChosenData` utilisée comme mixin Dart 3) ⇒ rabaissées à `ignore` dans le SEUL `analysis_options.yaml` du vendor (documenté en en-tête, logique amont non éditée) ⇒ **RC=0** (74 infos non fatals restants).
- `flutter test` par package (séquentiel, jamais `melos run test`) : `zcrud_select` **RC=0** (7 tests), `zcrud_html` **RC=0** (4), `zcrud_media` **RC=0** (4), `zcrud_field_extras` **RC=0** (4).
- `dart run melos list` → **RC=0**, 29 paquets, les 5 neufs PRÉSENTS.
- `gate:secrets` → **RC=0** ; `gate:codegen-distribution` → **RC=0** (squelettes sans `part` → no-op propre).
- **Disjonction fp-1-1** : `git status --short` — mes écritures = 5 nouveaux dossiers `packages/*` (untracked) + `pubspec.yaml` racine (M). **Zéro fichier écrit sous `packages/zcrud_core/` ni `packages/zcrud_generator/`.** Les 23 changements présents sous ces deux dossiers sont ceux de fp-1-1 (en vol parallèle), PAS les miens.

### Completion Notes List

- **7 ACs couverts.** AC1-AC4 : 4 squelettes (pubspec `publish_to:none` + `resolution:workspace` + `sdk ^3.12.2` ; barrel + arbre `lib/src/{domain,data,presentation}` avec placeholder documenté référençant l'AD ; garde de confinement falsifiable). AC5 : vendor `awesome_select` (MIT conservée, attribution Akbar Pulatov préservée + note de fork README/pubspec, résolu offline, gardé « déclaré exactement par zcrud_select »). AC6 : 5 membres enrôlés au bloc `workspace:` racine, `melos list` les voit, `analyze` RC=0 partout. AC7 : graph_proof + gates verts, cœur intact côté fp-1-2.
- **Gardes de confinement FALSIFIABLES (patron `z_export_ui_confinement_test`)** : deux volets (allowlist pubspec dé-commentée YAML ancrée + allowlist import `lib/**` dé-commentée Dart), chacun avec contre-preuve R12 mutante (un intrus témoin — `image_cropper`/`html_editor_enhanced`/`pinput` — DOIT rougir ; un import légitime `zcrud_core` NE DOIT PAS ; un import commenté est neutralisé). Pour `zcrud_select`, volet 3 « déclarer » : `awesome_select` déclaré EXACTEMENT par `zcrud_select` parmi tous les `packages/*/pubspec.yaml`, + barrel n'exporte pas `awesome_select`, + R12 (commentaire non falsifiant).
- **Écarts tranchés appliqués** : ET-1 (arête `zcrud_select→awesome_select` posée ici), ET-2 (vendor minimal — pas d'`example/`/`demo/`/`test/` amont), ET-3 (`lib/src/domain/` matérialisé avec placeholder documenté).
- **Variance vendor documentée** (risque anticipé par la story) : le fork cible Flutter 3.0 ; sous la toolchain workspace il faut assouplir 4 erreurs via son `analysis_options.yaml` propre (jamais globalement). Aucune ligne de logique amont modifiée — fork substituable. fp-4-1 devra rétablir la compat Flutter avant de compiler l'adaptateur contre le fork (rien ne l'importe au stade squelette).
- `zcrud_core` / `zcrud_generator` **NON touchés** par fp-1-2 (disjonction fp-1-1 respectée par conception).

### File List

Nouveaux paquets (créés) :
- `packages/zcrud_select/` : `pubspec.yaml`, `lib/zcrud_select.dart`, `lib/src/presentation/z_select_presenter_placeholder.dart`, `lib/src/domain/domain.dart`, `lib/src/data/data.dart`, `analysis_options.yaml`, `test/z_select_confinement_test.dart`, `LICENSE`, `README.md`, `CHANGELOG.md`
- `packages/zcrud_html/` : `pubspec.yaml`, `lib/zcrud_html.dart`, `lib/src/presentation/z_html_view_placeholder.dart`, `lib/src/domain/domain.dart`, `lib/src/data/data.dart`, `analysis_options.yaml`, `test/z_html_confinement_test.dart`, `LICENSE`, `README.md`, `CHANGELOG.md`
- `packages/zcrud_media/` : `pubspec.yaml`, `lib/zcrud_media.dart`, `lib/src/presentation/z_media_field_placeholder.dart`, `lib/src/domain/domain.dart`, `lib/src/data/data.dart`, `analysis_options.yaml`, `test/z_media_confinement_test.dart`, `LICENSE`, `README.md`, `CHANGELOG.md`
- `packages/zcrud_field_extras/` : `pubspec.yaml`, `lib/zcrud_field_extras.dart`, `lib/src/presentation/z_field_extras_placeholder.dart`, `lib/src/domain/domain.dart`, `lib/src/data/data.dart`, `analysis_options.yaml`, `test/z_field_extras_confinement_test.dart`, `LICENSE`, `README.md`, `CHANGELOG.md`
- `packages/awesome_select/` (vendor MIT) : `pubspec.yaml` (réécrit), `analysis_options.yaml` (assoupli, documenté), `LICENSE` (amont conservée), `README.md` (note de fork ajoutée), `CHANGELOG.md` (amont), `lib/**` (39 fichiers Dart amont, non modifiés)

Modifié :
- `pubspec.yaml` (racine) — bloc `workspace:` : 5 membres enrôlés (`zcrud_select`, `zcrud_html`, `zcrud_media`, `zcrud_field_extras`, `awesome_select`)

Non committé (hors périmètre epic) : `pubspec.lock`, `example/pubspec.lock` (résultat de `pub get`).
