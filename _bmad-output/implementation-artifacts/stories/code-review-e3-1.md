# Code Review — E3-1 : Rendu d'un champ = widget écoutant sa tranche

- **Story** : `_bmad-output/implementation-artifacts/stories/e3-1-rendu-champ-tranche.md` (8 ACs, statut `review`)
- **Skill** : `bmad-code-review` (VRAI skill invoqué ; step-file architecture suivie — step-01 gather-context, step-02 review, triage). Chemin pris : **skill réel** (`.claude/skills/bmad-code-review/SKILL.md` + `steps/`), workflow résolu via `resolve_customization.py` (RC=0).
- **Baseline** : `acc6a213` (frontmatter story). **Diff** : barrel `zcrud_core.dart` (modifié, +2 exports) + 6 fichiers non suivis (`presentation/edition/{z_edition_field,dynamic_edition}.dart` ; `test/presentation/edition/{_reference_form,sm1_full_form,uj2_external_rebuild,dynamic_edition}`).
- **Couches de revue** : Blind Hunter (adversarial général) + Edge Case Hunter + Acceptance Auditor (mode `full`, spec présente) — exécutées inline.
- **Date** : 2026-07-09

## Verdict : **APPROVED**

**SM-1 est RÉEL, non trompeur.** Les instruments de preuve sont correctement placés et détecteraient un rebuild global ou un rebuild de voisin s'il survenait. **Aucun anti-pattern AD-2.** Frontières E3-2/E3-3a/E3-4 respectées. Pureté par couche préservée. Fondation E2-7 (`z_form_controller`/`z_field_listenable_builder`) **non modifiée**. Les findings retenus sont tous **LOW** (qualité de test / trous de couverture volontairement bornés par la découpe d'épic), aucun ne masque un défaut réel.

## Vérifications RÉELLEMENT rejouées sur disque

| Contrôle | Résultat |
|---|---|
| `melos run analyze` | **RC=0** — `No issues found!` (14 packages) |
| Tests E3-1 ciblés (`flutter test test/presentation/edition/`) | **RC=0 — 6/6** |
| `melos run test` (suite complète) | **RC=0 — SUCCESS** ; `zcrud_core` **204** (incl. purity ×3, E2-7 `sm1_granular` 2/2) ; total ~325 |
| E2-9 parité (`z_get`/`z_riverpod`/`zcrud_provider_scope`) | **verts** (dans la suite complète) |
| `melos run verify` | **RC=0** |
| `graph_proof` | `noeuds=14, triés=14` / **CORE OUT=0 OK** / **ACYCLIQUE OK** |
| gates | `melos` OK (13 scripts) · `reflectable` OK · `secrets` OK · `codegen` OK (0 .g.dart manquant) · `compat` OK · `verify:serialization` OK |
| `melos list` | **14** packages |
| `.g.dart`/`.freezed.dart` committés | **0** (gitignorés ✓) |

## Analyse par point de vigilance adversarial

### SM-1 réel (objectif produit n°1) — **VÉRIFIÉ NON TROMPEUR**

Compteurs correctement placés et **capables de détecter** un rebuild indésirable :

- **`onBuild` (par champ)** est appelé **dans le `builder` du slice** (`z_edition_field.dart:104`), c.-à-d. **sous** le `ValueListenableBuilder` de `ZFieldListenableBuilder` — le bon niveau. Il mesure exactement le nombre de rebuilds du sous-arbre réactif du champ. Un voisin qui reconstruirait (parce que son slice notifie, ou parce que le widget est rebâti par le parent) **incrémenterait** son `onBuild` → le test le capterait. Compteur cible mesuré = baseline(1)+100 = **101** ; voisins = **1** (strictement inchangés, sur les 36 champs montés via surface haute 6000px, donc couverture exhaustive des 35 voisins).
- **`onStructuralBuild` (formulaire)** est appelé **dans le `builder` du `ValueListenableBuilder<List<String>>`** de `visibleFields` (`dynamic_edition.dart:117`). Comme `DynamicEdition.build()` retourne ce `ValueListenableBuilder`, **tout** rebuild du formulaire (parent-driven OU structurel) ré-exécute ce builder → `onStructuralBuild` fire. C'est un **détecteur valide de rebuild global**. Mesuré = **1** (inchangé sur 100 frappes).
- **`DynamicEdition` n'écoute QUE `visibleFields`**, jamais une tranche de valeur (vérifié ligne 114). Une frappe (`setValue`) ne touche pas `visibleFields` et `ZFormController.setValue` ne déclenche **aucun** `notifyListeners()` global (vérifié `z_form_controller.dart:88-90`) → le formulaire ne se reconstruit pas. **Pas de faille : le cœur ne peut pas reconstruire tout.**
- Focus (`focusNode.hasFocus == true` à chaque frappe et en fin) et curseur (`selection.base==extent==100`) asservis.

**Conclusion : SM-1 prouve VRAIMENT que 100 frappes ne reconstruisent que le champ courant.** L'objectif n°1 est réalisé par conception (pas seulement par un test complaisant).

### Anti-patterns AD-2 — **AUCUN**

- `setState` global : **absent** — `DynamicEdition` est `StatelessWidget` ; l'`State` de `ZEditionField` n'appelle **jamais** `setState`.
- `TextEditingController` recréé au rebuild : **non** — `late final _text` créé une seule fois en `initState` (`z_edition_field.dart:83-88`).
- Ré-injection `.text=` : **absente** — voie de frappe sens unique `onChanged → setValue` ; aucune écriture dans `_text` par notre code.
- `ListView(children:)` : **non** — `ListView.builder` (`dynamic_edition.dart:132`).
- `ValueKey(field.name)` : **présent** sur les deux voies (défaut `_buildField:147` + harnais).
- `dispose()` libère le `TextEditingController` : **oui** (`z_edition_field.dart:91-94`) — pas de fuite.

### UJ-2 réel — **VÉRIFIÉ (avec une réserve LOW)**

`uj2_external_rebuild_test.dart` déclenche un **vrai** rebuild d'ancêtre (bascule `ValueNotifier<bool>` de connectivité → `ValueListenableBuilder` reconstruit la `Column` + `form.buildForm()`, produisant une **nouvelle** instance `DynamicEdition`). Prouvé correctement : `initState == 1` (State/`TextEditingController` **non recréés** grâce à `ValueKey`), texte partiel préservé (`valueOf`+`controller.text == '0123456789'`), voisin intact, focus conservé, reprise de saisie sans reset. **Un `ValueKey` manquant casserait `initState==1` — le test l'attraperait.** L'edge est genuine. (Réserve : assertion `identical(controller)` tautologique — voir Finding L1.)

### Frontières E3-1/E3-2/E3-3a/E3-4 — **RESPECTÉES**

Aucun `AutovalidateMode`, aucun validateur (E3-2). Rendu **type-agnostique** (un seul `TextField`, `EditionFieldType` non dispatché) — dispatcher + a11y/RTL par-widget laissés à E3-3a (seam `fieldBuilder` en place). Pas de section repliable / champ conditionnel / grille (E3-4) — en-têtes purement visuels. Aucun empiètement.

### Pureté & invariants

`presentation/edition/` importe uniquement `package:flutter/material.dart` (autorisé sous `presentation/` depuis E2-8 ; `presentation_purity_test` **vert**). **0** gestionnaire d'état / `WidgetRef` / `Get` / `Provider`. `z_form_controller.dart` et `z_field_listenable_builder.dart` **inchangés** (git : seul le barrel modifié). En-tête de section : `EdgeInsetsDirectional` + `Theme.of` (AD-13/FR-26 respectés, `style_purity_test` vert).

## Findings (triage par sévérité)

**HIGH / MAJEUR : 0 — MEDIUM : 0 — LOW : 4**

### L1 — Assertion `identical(controllerBefore, form.controller)` tautologique (qualité de test)
`uj2_external_rebuild_test.dart:83`. `form.controller` est un `late final` du harnais : l'égalité d'identité est **toujours vraie**, quel que soit le comportement du widget. Elle ne prouve pas que le *widget* ne recrée pas de controller (garantie réelle : `DynamicEdition` prend le controller en paramètre requis et n'en construit jamais — invariant de conception). **Non bloquant** : les vraies preuves UJ-2 (`initState==1`, texte préservé) sont présentes et correctes. Suggestion : documenter que l'invariant « pas de recréation dans un `build` » est structurel, ou instrumenter un compteur de construction de controller.

### L2 — Trou de couverture : curseur au milieu du texte (déféré E3-2)
SM-1 ne saisit qu'en **append** (chaîne cumulative) et s'appuie sur le fait qu'`enterText` recolle la sélection en fin. Aucun test ne place le caret **au milieu** puis prouve qu'une modification préserve la position médiane. La préservation est architecturalement garantie (aucune ré-injection `.text=`), mais **non testée**. La Dev Note frontière assigne explicitement « préservation curseur sous rebuild comme contrat de premier ordre » à **E3-2** → acceptable ici, à couvrir en E3-2.

### L3 — Seam `fieldBuilder` sans garde de `ValueKey` (risque latent E3-3a)
`dynamic_edition.dart:143-145` : quand un `fieldBuilder` est fourni, `DynamicEdition` délègue entièrement et **ne garantit pas** le `ValueKey(field.name)` (place stable = invariant UJ-2). La discipline repose sur le seul contrat documenté du `typedef`. **Sans risque pour E3-1** (voie par défaut `_buildField` keyée ; harnais keyé). Pourrait devenir **MEDIUM** en E3-3a si un dispatcher oublie la clé. Suggestion : envelopper la sortie du builder dans un `KeyedSubtree(key: ValueKey(spec.name), …)` côté `DynamicEdition` pour rendre l'invariant non contournable.

### L4 — Trou de couverture : changement de focus entre champs
Aucun test ne tape un champ A, saisit, puis tape un champ B pour prouver (a) transfert de focus propre, (b) aucun rebuild-storm sur A, (c) pas de reset de curseur/valeur de A. Gap mineur (le mécanisme le garantit) ; candidat naturel au lot de tests E3-2/E3-3a.

### Nit (non compté) — Hypothèse d'ordre contigu des sections
`dynamic_edition.dart:121-129` : les en-têtes sont émis sur transition `section != currentSection`. Si `visibleFields` **entrelaçait** les sections, des en-têtes seraient dupliqués. Non pertinent pour E3-1 (ordre groupé garanti par le harnais), mais hypothèse latente à documenter pour E3-4.

## Trous de couverture identifiés (récapitulatif)
- Curseur en **milieu** de texte (L2, → E3-2).
- **Focus changeant** de champ (L4).
- Champ **vide → rempli** : **couvert** (la cible SM-1 démarre vide).
- Voie de rendu **par défaut** (sans `fieldBuilder`) : **couverte** (`dynamic_edition_test.dart` « liste plate »).

## Décision
Story **E3-1** conforme aux 8 ACs, vérif verte réelle rejouée (analyze RC=0, test RC=0 ~325, verify RC=0, graph CORE OUT=0, 14 packages, 0 .g.dart committé). SM-1 **réel**, 0 anti-pattern AD-2, frontières respectées. **Aucun finding HIGH/MAJEUR/MEDIUM.** Les 4 LOW sont des améliorations de test/couverture, dont L2 est explicitement déféré à E3-2 par la découpe d'épic.

**→ APPROVED.** Correction des LOW optionnelle ; L1 et L3 recommandés (triviaux, sans régression) ; L2/L4 à porter au backlog de tests E3-2/E3-3a.
