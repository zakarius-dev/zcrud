# Rétrospective globale — Itération « Formulaire — parité DODLP totale » (FP-1 → FP-5)

> **Nature** : rétrospective d'itération (5 epics · 13 stories), pas d'un seul epic.
> **Date** : 2026-07-18 · **Skill** : `bmad-retrospective` (chargé, PAS de fallback disque).
> **Facilitation** : exécution non-interactive (subagent) — passes d'analyse jouées, dialogue party-mode
> remplacé par une synthèse documentaire. **Aucune écriture `sprint-status.yaml`, aucun commit** (hors périmètre).
> **Sources** : les 13 stories `fp-*`, les 13 `code-review-fp-*.md`, `docs/dodlp-form-integration-study-2026-07-17/`
> (STUDY + NEXT-ITERATION-SCOPE + 13 lentilles), CLAUDE.md.

---

## 1. Résumé de l'itération

| Métrique | Valeur |
|---|---|
| Epics | 5 (FP-1 Fondations · FP-2 Natifs & câblage · FP-3 Preuve · FP-4 Média-rich · FP-5 Finitions) |
| Stories | **13 / 13 done** (toutes committées) |
| Commits | `ae3a6ad` (vague 1, 6 stories) · `0527cb3` (vague 2, 5 stories) · `ad765ae` (vague 3, 2 stories) |
| Séquençage | Interleaved MVP → Média-rich → Finitions ; parallélisation massive **sans plafond** sur satellites disjoints |
| Nouveaux packages | 4 satellites (`zcrud_select`, `zcrud_html`, `zcrud_media`, `zcrud_field_extras`) + 1 vendor privé (`packages/awesome_select`, `publish_to:none`) |
| Cœur touché (sérialisé) | `dateRange`/`ZDateRange`, tokens d'aération, seam `ZSelectPresenter`, `ZColorConfig.multiple`, enums `pin`/`autocomplete`/`editableTable`, `mediaImage/mediaFile/mediaVideo` |
| Findings code-review | 0 HIGH · **3 MAJEUR** (fp-3-1 prose, fp-4-1 réfuté-R3, fp-4-2 dispatch) · ~13 MEDIUM · nombreux LOW — **tous corrigés ou justifiés/consignés** |
| Vérif verte finale | `flutter test` par package RC=0 (cœur ~1013-1018, media 31, html 26, select 29, field_extras 26, geo 174, example 97) ; `graph_proof` ACYCLIQUE + CORE OUT=0 ; `melos analyze`/`verify` repo-wide verts avant chaque gate de commit |

**Verdict d'itération : SUCCÈS.** La parité DODLP totale est atteinte, invariants AD tenus (CORE OUT=0
préservé malgré 4 satellites neufs + 6 touches cœur), et le code-review multi-lentilles + R3 a attrapé de
**vrais** défauts (perte de données, code mort de dispatch, contraste dark-theme) sous des suites pourtant vertes.

---

## 2. Ce qui a marché (à répéter)

1. **L'étude préalable a dé-risqué toute l'itération.** Les 13 lentilles de `dodlp-form-integration-study`
   ont renversé la prémisse fausse (« DODLP largement basé sur `flutter_form_builder` à porter ») : l'essentiel
   était **déjà natif, theme-driven, conforme AD-2** dans `zcrud_core`/`zcrud_intl`/`zcrud_responsive`. Le vrai
   bug historique (jank + perte de focus) venait d'un `setState()` à l'échelle de l'écran — précisément ce que
   `ZFormController` corrige par conception. Résultat : périmètre réel bien plus léger, une seule dépendance
   tierce réellement à adapter (`awesome_select`). **Investir dans l'étude AVANT le brief a payé.**

2. **Le seam `ZWidgetRegistry` a tenu sa promesse.** Un seul point d'extension (`register(kind, builder)`,
   injecté par `ZcrudScope`, jamais singleton) a permis de brancher 4 satellites média-rich **hors cœur** sans
   jamais faire remonter une dépendance lourde : `graph_proof` reste ACYCLIQUE + CORE OUT=0 à chaque story.

3. **La parallélisation massive sur fichiers disjoints a tenu.** Jusqu'à 3+ satellites en vol (`zcrud_select` ∥
   `zcrud_media` ∥ `zcrud_html`, puis `zcrud_field_extras` ∥ `zcrud_geo`) sans collision, grâce à la règle
   « seul point de contact = `zcrud_core`, sérialisé, une story à la fois » et aux vérifs vertes par package ciblé.

4. **Le vendoring du fork `awesome_select` a été propre.** Package privé `publish_to:none`, déclarant unique
   (`zcrud_select`), zéro fuite import/export au barrel (garde AD-40/AD-49), LICENSE MIT + attribution amont,
   `lib/**` byte-identique. La dette de compat Flutter 3.0 a été explicitement transmise fp-1-2 → fp-4-1 et soldée.

5. **Code-review multi-lentilles + discipline R3 = vrais défauts attrapés sous suites vertes.** Perte de données
   (`dispose()` sans flush — fp-4-3), code mort de dispatch (kinds média inatteignables — fp-4-2), contraste
   dark-theme (glyphe suivant le thème, pas la donnée — fp-4-4), re-hydratation manquante (table/autocomplete —
   fp-5-2). Chaque correctif a été verrouillé par un test **falsifiable** (rouge-avant prouvé par injection réelle).

6. **Résilience opérationnelle.** Un plantage réseau de dev (fp-3-1) a été absorbé par la vérif disque +
   reprise (les Completion Notes fausses ont été rattrapées par la lentille « réalité du code »). 2 tests example
   pré-cassés soldés au passage. Aucun `done` sur la seule foi d'un rapport d'agent.

---

## 3. Motifs de défauts → garde-fous réutilisables (checklist)

> À intégrer aux prompts de `dev-story` et aux lentilles de `code-review`. Les items **[NOUVEAU]** sont
> apparus pour la première fois dans cette itération.

- [ ] **[NOUVEAU] Présence ≠ association AU NIVEAU DISPATCH.** Un `kind` enregistré n'est atteignable QUE si le
      dispatcher route vers lui. Le dispatcher route par `field.type.name` → tout `kind` sans `EditionFieldType`
      correspondant est **code mort** (`mediaImage`/`mediaFile`/`mediaVideo` tombaient sur `ZUnsupportedFieldWidget`
      — fp-4-2 MAJEUR). **Garde-fou** : tout test d'association DOIT traverser le VRAI dispatcher
      (`DynamicEdition`→`ZFieldWidget` sous `ZcrudScope(widgetRegistry:)`), JAMAIS indexer `reg.builderFor(kind)`
      directement. Ajouter un test dérivé de l'enum/matrice : pour chaque type `liveSatellite`, exiger ≥1 champ
      monté sans `ZUnsupportedFieldWidget`.

- [ ] **[NOUVEAU] Le cœur en parallèle est une CIBLE DE COMPILATION MOUVANTE.** Une story éditant `zcrud_core`
      casse transitoirement TOUS les dépendants pendant l'édition. **Garde-fou** : une seule story touche
      `zcrud_core` à la fois (sérialisation stricte) ; les vérifs des satellites ne sont validées qu'une fois le
      cœur **stable** ; ne jamais lancer `melos test` global au milieu d'un dev cœur actif.

- [ ] **[NOUVEAU] `dispose()` doit flusher tout commit débouncé en attente.** Un debouncer qui jette son
      `_pending` au `dispose()` = **perte de données** (fp-4-3). **Garde-fou** : tout contrôleur à commit différé
      appelle `flush()` avant nettoyage ; test porteur « dispose flushe le pending » + test d'idempotence.

- [ ] **[NOUVEAU] Le contraste d'un glyphe sur une pastille de DONNÉE se dérive de la DONNÉE, pas du thème.**
      Peindre une coche/croix via `onPrimary/onSurface` (axe thème) rend le glyphe invisible en dark sur pastille
      sombre (fp-4-4). **Garde-fou** : contraste piloté par `estimateBrightnessForColor(donnée)`, blanc/noir dérivés
      HSV (pas de `Colors.`/`Color(0x…)` — garde FR-26) ; test sous `ThemeData.dark()` avec pastille sombre ET claire.

- [ ] **[NOUVEAU] Re-hydratation sur ré-injection externe.** Un champ à contrôleur (table, autocomplete) DOIT
      re-synchroniser sur `setValue`/reset externe via `didUpdateWidget` (positionnel, borné, n'écrit que si
      `text != slice`, préserve la sélection) — sinon la ré-injection est silencieusement ignorée (fp-5-2).
      **Garde-fou** : contrôleurs gérés (`putIfAbsent`, jamais recréés au rebuild — SM-1) + re-sync `didUpdateWidget` ;
      test porteur « ré-injection d'une valeur existante s'affiche ».

- [ ] **La prose ment (RÉCIDIVE).** Completion Notes / README / dartdoc affirmant un état non vérifié sur disque —
      aggravé quand l'orchestrateur remédie SÉPARÉMENT après le dev (Completion Notes périmées — fp-3-1), ou README
      décrivant encore un squelette (fp-4-1/fp-4-2/fp-4-3). **Garde-fou** : lentille « réalité du code » obligatoire —
      toute affirmation d'« absence » prouvée par grep négatif ; toute prose d'état réconciliée avec le disque avant `done`.

- [ ] **Tests tautologiques / porteurs (RÉCIDIVE, discipline R3).** Test qui n'exerce jamais le chemin (picker jamais
      tapé — fp-1-1), qui assied la valeur par défaut (token vs littéral indistinguables — fp-1-1), qui n'assère pas le
      repli AD-10 (« champ vide » jamais asséré — fp-5-2), volet de scan sans anti-vacuité (glob à 0 fichier reste vert —
      fp-1-2). **Garde-fou** : chaque test doit ROUGIR sous une injection inverse réelle (rejouée), assertions sur valeur
      NON-défaut, anti-vacuité (`expect(scanned, isNotEmpty)`) sur tout scan.

- [ ] **Double annonce a11y (RÉCIDIVE à CHAQUE story).** `Semantics(container:true, label:X)` englobant un
      `Text(X)` visible ⇒ libellé annoncé 2×. Apparu en fp-2-1 (5 familles), fp-4-4, fp-5-1 (3 modes), fp-5-2
      (autocomplete). **Garde-fou** : ne jamais poser `label:` sur un `Semantics(container:)` qui contient déjà un
      `Text` visible (ou `excludeSemantics:true`) ; test `bySemanticsLabel(X) findsOneWidget`. → **candidat lint custom**.

- [ ] **WebView non testable headless (ET-5).** `ZHtmlEditorField` (WebView) n'est pas montable en `flutter test` —
      ne jamais prétendre qu'une édition WYSIWYG est « exercée au runtime » par les tests (fp-3-2 LOW). **Garde-fou** :
      démontrer la LECTURE (`ZHtmlView`) en test ; documenter l'édition runtime comme hors-démo-test.

- [ ] **Placeholder / littéral tiers non localisé.** Un fork peut afficher un texte anglais codé en dur à l'état vide
      (`'Select one'` — fp-4-1). **Garde-fou** : passer un `placeholder` l10n depuis le présentateur ; test
      `find.text('<littéral fork>') findsNothing`.

- [ ] **`materialTapTargetSize` du chip.** Sous un thème `shrinkWrap`, un `InputChip` (et son `onDeleted`) tombe
      < 48 dp (fp-5-1). **Garde-fou** : épingler `MaterialTapTargetSize.padded` ; test `getSize(...).height >= 48`
      sous thème `shrinkWrap`.

- [ ] **Cadre neutre vs donnée.** Une vignette d'aperçu dont la bordure = la donnée (`stroke`) disparaît quand
      donnée ≈ fond (fp-5-3). **Garde-fou** : cadre extérieur NEUTRE du thème (`fieldBorderColor ?? outline`) distinct
      du liseré intérieur (donnée) ; test avec `fill == stroke == fond`.

---

## 4. Décisions de périmètre tranchées — À VALIDER PAR L'OWNER

1. **Retrait tags-riches / icon.** Écartés du périmètre : 0 call-site DODLP, non-parité. → Confirmer l'exclusion
   définitive ou re-planifier si un consommateur futur les exige.
2. **`editableTable` — limite de persistance `List<Map>`.** L'enum est **nommé + routé (`registryOrFallback`) +
   repli-testé**, mais le générateur ne round-trippe PAS `List<Map<String,dynamic>>` (`_classify` récurse sur `Map`,
   aucune branche → `InvalidGenerationSourceError`). → Dette : **type de valeur dédié + codec** dans une story
   ultérieure. Confirmer que la table éditable reste UI-only pour l'instant.
3. **ET-2 — parité riche sur types NATIFS image/file.** Décision cœur : les types natifs `file`/`image`/`document`
   sont rendus par `ZAppFileField` (dispatch natif), la richesse média (crop/caméra/vignette) passe par les kinds
   `mediaImage/mediaFile/mediaVideo` du satellite `zcrud_media`. → Valider cette dualité natif/satellite.
4. **Acquisition vidéo directe (fp-4-2 LOW).** La drop-zone `mediaVideo` gère la vignette d'un `AppFile` vidéo
   préexistant mais n'a pas de `pickVideo` (mode vidéo → `pickImages`). → Suivi : ajouter une source vidéo à
   `ZFileSource` côté cœur.
5. **Variantes `SmartSelect` non exposées.** `page`/`dialog`/`chips` NON implémentées (bottom-sheet + radios/checkboxes
   seulement). → Confirmer suffisance pour la parité DODLP.

---

## 5. Action items & dette transmise

| # | Action | Catégorie | Owner suggéré | Statut |
|---|---|---|---|---|
| 1 | Ajouter les 5 nouveaux garde-fous [NOUVEAU] du §3 aux prompts `dev-story` + lentilles `code-review` | Process | Orchestrateur | open |
| 2 | **Lint custom double-annonce a11y** (`Semantics(container,label:) + Text(même)`) — récidive à chaque story | Technique | zcrud_core / CI | open |
| 3 | Story dédiée : champ couleur **simple** `z_color_field_widget.dart` porte encore le motif double-annonce (fp-4-4 LOW-dette signalée, hors périmètre) | Technique | zcrud_core | open |
| 4 | Story dédiée : **type de valeur + codec `editableTable`** (`List<Map>` non round-trippé par le générateur) | Technique | zcrud_core + zcrud_generator | open |
| 5 | Suivi : **source vidéo** dans `ZFileSource` + seam (acquisition vidéo directe drop-zone) | Technique | zcrud_core + zcrud_media | open |
| 6 | Resserrer si besoin les `// ignore:` ligne-à-ligne du vendor `awesome_select` (déjà fait fp-4-1, vérifier durabilité au prochain bump Flutter) | Dette | zcrud_select | done (fp-4-1) |
| 7 | Test SM-1 curseur mid-stream : porté au niveau cœur (champ texte), le banc example ne prouve que la granularité — s'assurer que la couverture cœur reste (fp-3-1 LOW consigné) | Test | zcrud_core | open (justifié) |

**Dette déjà soldée dans l'itération** : compat Flutter du fork `awesome_select` (fp-1-2→fp-4-1) · dep `camera`
morte retirée (fp-4-2 MED-3) · 2 tests example pré-cassés · placeholder l10n `SmartSelect` · READMEs squelette réécrits.

---

## 6. Readiness — état réel

- **Toutes stories `done` + committées** (`ae3a6ad`/`0527cb3`/`ad765ae`) ; `git status packages/` propre.
- **Invariants tenus** : AD-1 (CORE OUT=0 malgré 4 satellites + 6 touches cœur) · AD-2/SM-1 (contrôleurs stables,
  vignette mémoïsée, rebuild granulaire) · AD-10 (replis défensifs prouvés par test) · AD-13/FR-26 (a11y ≥48dp,
  directionnel, thème injecté, contraste HSV) · AD-49 (vendor confiné).
- **Aucune découverte structurante ne remet en cause l'architecture** — les limites (`editableTable`, vidéo directe)
  sont des dettes bornées et documentées, pas des remises en question d'AD.
- **Pas de prochain epic FP planifié** : l'itération clôt la parité DODLP totale. Les 4 action items techniques
  ouverts (§5 : #2 lint, #3 color simple, #4 editableTable codec, #5 vidéo) sont des stories de v1.x, non bloquantes.

---

*Rétrospective produite par `bmad-retrospective` — synthèse documentaire non-interactive. Sprint-status et commits
laissés à l'orchestrateur.*
