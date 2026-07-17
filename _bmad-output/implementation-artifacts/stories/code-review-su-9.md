# Code-review su-9 — Flux UI de génération IA (`zcrud_study`)

Story : `su-9-flux-generation-ia.md` (13 ACs). Spine : AD-37 · AD-43 · AD-35 · AD-4 · AD-10 · AD-13.
Package : `zcrud_study` SEUL. Working tree non committé (su-1..su-9). Remédiation des findings du
code-review multi-lentilles (6 rapports) selon les dispositions ARBITRÉES D1..D5 + LOW.

## Verdict

**CHANGES APPLIED — vert.** Les 2 MAJEURS (D1 témoin infalsifiable, D2 fuite L10n) et les 3 MEDIUM
(D3, D4, D5) sont **corrigés et prouvés par mutation**. Les invariants durs confirmés au crédit par les
lentilles (AD-43 runtime, port faillible, module de défauts) sont **intacts — non touchés**.

Vérif verte rejouée RÉELLEMENT :
- `flutter test` DEPUIS `packages/zcrud_study` ⇒ **408/408** (403 base + 4 a11y su-9 + 1 contre-preuve garde).
- `dart run melos run analyze` (repo-wide) ⇒ **RC=0** (SUCCESS ; seuls des `info` de dépréciation
  pré-existants, catégorie déjà présente dans la base verte : `containsSemantics`/`hasFlag`/`pipelineOwner`,
  `dartz` en `depend_on_referenced_packages` déjà porté par les tests su-9 voisins).
- `dart run melos run verify` ⇒ **RC=0** ; **54 arêtes, ACYCLIQUE OK, CORE OUT=0 OK** ; melos / reflectable /
  secrets / codegen / codegen-distribution / compat / web / reserved-keys **OK**.

---

## Findings & dispositions

### D1 — MAJEUR — témoin comportemental d'AC5 INFALSIFIABLE → **CORRIGÉ (témoin SUPPRIMÉ + remplacé)**
`test/presentation/z_flashcard_generation_controller_test.dart` (ancien `:148-170`).

**Défaut** : le `_SpyStore` était instancié mais **jamais joignable par le SUT** (le contrôleur n'a ni
param store ni `ZcrudScope` — `grep -qF _SpyStore controller.dart` ⇒ RC=1) : `expect(spy.writes,1)` était
un `1==1` vrai quel que soit le code (récidive su-4/su-7).

**Voie retenue = (b) SUPPRESSION + remplacement falsifiable.** Justification : le contrôleur **ne persiste
RIEN par conception** — il n'existe AUCUN seam de store à injecter (AD-43 est tenu **purement
structurellement** par la garde purity `z_widgets_purity_test`, mutation-vérifiée). Brancher un espion via
`ZcrudScope` (voie a) aurait exigé d'**ajouter une dépendance de store au contrôleur** — contraire à
AD-43 et à la garde purity elle-même. Le témoin comportemental est donc **structurellement impossible** ;
un test qui ne peut pas rougir est pire que pas de test. `_SpyStore` supprimé (sinon `unused_element`).

**Remplacement** (assertion à vrai pouvoir, en ACTIONNANT le flux) : le handoff `onGenerated` ne transporte
que des cartes **`id == null`** (non persistables telles quelles par l'hôte) ; puis regénère + `abandon()` ⇒
retour `idle`, `cards` vide (aucun résidu). Documenté honnêtement : « zéro persistance » est **structurel**.

**R3 (prouvé par mutation, par le COMPORTEMENT)** : mutant `_ephemeral → return card` (id backend qui fuit)
⇒ le nouveau test ROUGE : `Expected: true / Actual: <false>` sur `every id==null`. Fichier restauré, `sha256sum -c` OK, `grep MUTANT` RC=1.

### D2 — MAJEUR — libellés de tags FR en dur non injectables → **CORRIGÉ (fermeture structurelle + garde)**
`z_flashcard_tag_confirm_sheet.dart:44-46` (défauts FR) · `z_flashcard_generation_sheet.dart:261-270`
(non transmis) · `ZFlashcardGenerationLabels` (n'exposait pas).

**Scénario** : app anglaise → confirmation de tags → `ZTagEditor` rendait « Nom du tag » / « Ajouter un
tag » / (lecteur d'écran) « Ajouter le tag » en français, **sans aucune voie d'override** par le flux canonique.

**Correctif (fermeture par CONSTRUCTION)** :
1. `ZFlashcardGenerationLabels` expose `tagInputLabel` / `tagInputHint` / `tagAddSemanticLabel` (**requis**,
   patron des autres libellés).
2. `ZFlashcardGenerationSheet` les **transmet** à `ZFlashcardTagConfirmSheet`.
3. `ZFlashcardTagConfirmSheet` : `inputLabel`/`inputHint`/`addSemanticLabel` rendus **REQUIS** (défauts FR
   supprimés). ⇒ les fichiers su-9 ne portent PLUS aucun libellé rendu en dur.
4. **Racine partagée** : `ZTagEditor` (ES-8.1) portait les MÊMES 3 défauts FR (`z_tag_editor.dart:89-91`) —
   son seul consommateur de prod est la feuille de confirmation ; ses 3 params rendus **REQUIS**, ses 11
   constructions de test mises à jour.

**Garde (trou fermé, EXTENSION de l'existante, pas de garde parallèle)** : `z_widgets_hardcode_scan_test`
gagne 3 règles attrapant la forme **défaut de constructeur** `\b(inputLabel|inputHint|addSemanticLabel)\s*=\s*'…'`
(invisible aux règles de site d'argument existantes) + contre-preuve partageant le scanner réel.
**R3 (mutation)** : re-introduction de `this.inputLabel = 'Nom du tag'` dans un fichier su-9 ⇒ scan ROUGE
(`z_flashcard_tag_confirm_sheet.dart:44 → inputLabel = '…' … « Nom du tag »`). Restauré, `sha256sum -c` OK.

**Portée explicitement consignée (hors su-9)** : `z_exam_editor.dart` (~16 défauts) et
`z_study_mindmap_section.dart` (4) portent le MÊME anti-patron sous des **noms de champ différents**
(`titleLabel`, `enterEditSemanticLabel`, `addThresholdSemanticLabel`…). La règle su-9 est ciblée sur le
trio de saisie de tag et ne les attrape volontairement PAS : leur remédiation générique exigerait de rendre
~20 params requis sur 3 widgets d'épics antérieurs (ES-exam, ES-7.1) + réécriture de leurs suites — un
refactor multi-story **hors périmètre su-9 et régressif**. Consigné comme **dette L10n pré-existante
séparée à traiter** (follow-up), non « légalisée » silencieusement.

### D3 — MEDIUM — double annonce du launcher → **CORRIGÉ**
`z_flashcard_generation_sheet.dart:562` : `Icon(…, semanticLabel: label)` + `Text(label)` fusionnés par
`ElevatedButton.icon` ⇒ « Générer avec IA, Générer avec IA » (récidive su-8). Correctif :
`semanticLabel` retiré de l'icône (le `Text` porte déjà le sens). **R3 (mutation)** : re-ajout de
`semanticLabel: label` ⇒ le test D3 ROUGE `Expected <1> / Actual <2>` (label fusionné « Générer avec IA /
Générer avec IA »).

### D4 — MEDIUM (instruit par SONDE, puis CONFIRMÉ) — slider `count` à nœud fantôme → **CORRIGÉ**
`z_flashcard_generation_sheet.dart:362-373`. **Sonde (dump de l'arbre sémantique)** : l'ancien
`Semantics(slider:true, label:, value:)` ENVELOPPANT créait **DEUX** nœuds `isSlider` — un **fantôme** #7
(label « Nombre de cartes », valeur `10`, **sans action**) et le vrai Slider #8 (increase/decrease, valeur
`18%`, **sans label**). Un lecteur d'écran rencontrait deux sliders et le contrôle réel était muet
(structurellement identique à su-8 D3). **Finding CONFIRMÉ.**

Le `Slider` étant une **frontière sémantique dure** (impose son propre nœud actionnable, n'hérite pas d'un
libellé de parent — `MergeSemantics` NE traverse PAS la frontière, testé), le patron accessible correct est
un **conteneur libellé UNIQUE** : `Semantics(container: true, label:)` → un seul nœud slider actionnable,
libellé porté par le conteneur (doublé par le `Text` visible). **R3 (mutation)** : re-ajout de
`slider: true` sur le conteneur ⇒ le test D4 ROUGE (`hasLength(1)` échoue : 2 nœuds isSlider, le fantôme
cohabite). Voie retenue documentée dans le code (limitation Flutter du Slider).

### D5 — MEDIUM — énumération a11y AC12 non tenue pour su-9 → **CORRIGÉ (extension, pas de garde parallèle)**
`z_flashcard_a11y_test.dart` ne couvrait que `ZFlashcardListView` (su-8). Extension avec un groupe
`su-9/AC12` **balayant les contrôles des 2 feuilles** (leçon su-6 : ne pas omettre une surface entière) :
launcher (annoncé 1×, ≥48 dp), bouton Générer (≥48 dp + BOUTON), slider (1 seul nœud, actionnable, libellé
atteignable — D4), boutons Confirmer/Annuler de la feuille de confirmation (≥48 dp), libellé d'ajout de tag
injecté atteignable (D2). 4 tests, **verts** ; c'est cette énumération qui **rougit** D3 et D4 sous mutation.

### LOW — dispositions
- **`zNormalizeTypesDistribution` jamais invoquée en prod** (`z_flashcard_generation_defaults.dart:94`) :
  **consigné/justifié, pas de correctif**. La feuille dérive toujours `zEvenTypesDistribution(count,
  typesSélectionnés)` de FilterChips (sous-ensemble des 6 types valides) ⇒ **jamais** de distribution
  incohérente à normaliser dans su-9. Câbler la normalisation dans le contrôleur exigerait qu'il connaisse
  les 6 types admis (couplage domaine injustifié). La fonction reste une **utilité de domaine app-side**
  (pure, testée, exportée) pour un consommateur qui construirait un DTO à la main — hors flux su-9.
- **Pas d'affordance d'annulation pendant `generating`** (`sheet.dart:409`) : **consigné, suffisant**.
  Fermer la feuille suffit : `dispose()` fait `_generation++` ⇒ toute réponse en vol devient périmée et est
  écartée (`_isStale`). Cohérent AD-35 (timeout = responsabilité app-side) / AC8. Pas de bouton Annuler câblé.
- **Prose vs code (RC=1 cité rendant RC=0)** : **CORRIGÉ**. `z_flashcard_generation_controller.dart:13-14`
  et `z_flashcard_tag_confirm_sheet.dart:16-17` reformulés en « sur les lignes de CODE (commentaires exclus)
  ⇒ RC=1 ; garde purity mutation-vérifiée ». L'invariant était vrai ; seule la preuve citée est corrigée.

---

## Points CONFIRMÉS au crédit (NON touchés)
- **AD-43 tient réellement sur toutes les voies runtime** : `id==null` forcé via la sentinelle `_$undefined`
  (pas le piège `id ?? this.id`), `source = request.provenance` seule, pas d'aliasing preview↔handoff
  (`copyWith` reconstruit), pas de save implicite (dispose/abandon), jeton de fraîcheur load-bearing. La
  garde structurelle purity est **non-aveugle** (injecter `.save(` la fait rougir — mutation ratifiée).
- **Port faillible : PASS** (0 finding) — Left/throw/`Right([])`/malformé ont tous un repli sans throw,
  anti-double-tap, pas de `notify` après `dispose`, jeton falsifiable. Non touché.
- **Module de défauts : GREEN** — pur, source unique `[1,50]`, déterministe, clamp prouvé par mutation.
  Non touché.

## Discipline
Toutes les mutations R3 jouées **isolément** (cp + SHA-256, restaurées, `sha256sum -c` OK, `grep MUTANT`
RC=1). Sonde jetable du slider (`_probe_slider_test.dart`) supprimée après usage (preuve : `ls` ⇒ absent).
Aucune écriture dans `zcrud_core`, aucun `git checkout/restore`, aucun `melos run test`, aucun `dart format`,
aucun commit, sprint-status NON touché.
