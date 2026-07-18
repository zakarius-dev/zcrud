# Story 2.1: Champs natifs de base & spécialisés (confirmés & polis)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

<!-- Story key: fp-2-1-champs-natifs-base-specialises · Source: epics-zcrud-form-parity-2026-07-18/epics.md → Epic 2, Story 2.1 · CORE-SÉRIALISÉE (présentation, PAS d'ajout d'enum) -->

## Story

As a développeur consommateur,
I want que toutes les familles de champs **déjà natives** de `zcrud_core` — saisie (text/multiline/password/number/integer/float/boolean/dateTime/time), collections (rowChips/tags/subItems/dynamicItem), spécialisés (rating/slider/signature), color simple, seams hidden/widget/custom — soient **confirmées à parité DODLP et débarrassées de leur dette d'accessibilité résiduelle**,
so that mes formulaires MVP rendent à parité DODLP (aération, a11y, RTL, l10n, états read-only/désactivé/erreur/conditionnel) **sans jank ni perte de focus** et sans régression.

## Contexte & cadrage (lire avant de coder)

**Marquage epic :** `[MVP]` · **CORE-SÉRIALISÉE** — cette story écrit **uniquement** la **présentation** de `packages/zcrud_core/lib/src/presentation/edition/families/` (polish a11y). Elle est le **seul écrivain** de `zcrud_core` pendant sa fenêtre. Elle **ne touche AUCUN satellite, ni l'exemple/showcase (fp-3), ni un binding**, et **n'ajoute AUCUN `EditionFieldType` ni aucune valeur d'enum** (distinction nette avec fp-1-1 `dateRange` et fp-5-1 pin/autocomplete/editableTable). Binds FR-1, FR-2, FR-3, FR-4, FR-10, FR-11, FR-12, FR-14, FR-19, FR-29, FR-30, FR-31, FR-33 ; NFR-1/2/3/4 ; **AD-2, AD-4, AD-13, FR-26**.

**Nature réelle de la story — À LIRE (verdict d'exploration disque, 2026-07-18) :** la surface de travail est **volontairement mince**. La matrice d'intégration (`docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md`) marque **✅ NATIF (parité, souvent supérieur DODLP en a11y/RTL/thème)** pour la quasi-totalité des familles visées ici. L'exploration disque le **confirme** (greps ci-dessous). Le **seul écart de parité RÉEL et prouvé** relevant du cœur MVP est une **dette d'accessibilité de "double annonce"** (`Semantics(container:true, label:X)` **+** `Text(X)` visible → l'attribut est annoncé deux fois par le lecteur d'écran) qui subsiste dans **5 familles natives**. Ce même défaut a **déjà été corrigé** ailleurs par fp-5-1 (`z_sub_list_field_widget.dart`) et fp-4-4 (`z_color_multi_field_widget.dart`) ; le patron de correction est donc **établi et à répliquer à l'identique** (pas d'invention). **Tout le reste est déjà à parité — ne pas fabriquer du polish cosmétique gratuit.**

**État confirmé sur disque (greps rejoués — "rien à faire", NE PAS retoucher) :**
- **Aération / tokens fp-1-1** : `ZcrudTheme.formPadding` existe et est **déjà consommé** par `DynamicEdition` (`dynamic_edition.dart:576` : `widget.padding ?? ZcrudTheme.of(context).formPadding`) ; `interFieldGap` + `zFieldGapAfter()` en place (`dynamic_edition.dart:193,298,775`). **Rien à ajouter côté aération dans cette story** (les tokens sont livrés par fp-1-1).
- **RTL / directionnel (AD-13)** : `grep -rn "EdgeInsets.only(left:|EdgeInsets.only(right:|Alignment.centerLeft|Alignment.centerRight|TextAlign.left|TextAlign.right|Positioned(left:|Positioned(right:" families/` → **0 violation** (seul match = une ligne de commentaire dans `z_color_multi_field_widget.dart:28`). **Rien à corriger.**
- **Thème / FR-26 (pas de couleur codée en dur)** : `grep -rn "Colors\.[a-zA-Z]" families/*.dart` → **0** usage illégitime (seul match = `z_color_field_widget.dart:447`, un `if (widget.recentColors.isNotEmpty)` — pas une couleur littérale). **Rien à corriger.**
- **l10n (number)** : le suffixe `%` (pourcentage) et le symbole monétaire dérivent de la config/locale et **jamais** d'un littéral de style — `z_number_field_widget.dart:86-92` (`_suffixText` : `label(context,'percentSuffix',fallback:'%')` / `cfg.currencySymbol ?? label(context,'currencySuffix',...)`), suffixe **NEUTRE lecture**, valeur persistée intacte. **Conforme, rien à faire.**
- **boolean (≥48dp + Semantics on/off)** : `z_boolean_field_widget.dart:43` = `SwitchListTile` natif (cible ≥48dp + rôle `switch` + état coché/décoché fusionnés nativement). **Conforme, rien à faire** (delta cosmétique DODLP absorbé par `SwitchThemeData`, hors cœur).
- **dateTime / time (ISO-8601, pickers Material natifs, 0 dep)** : `z_date_field_widget.dart` (natif, aucune dep `date_time_picker`/`table_calendar`). **Conforme.**
- **subItems (réordo monter/descendre `_move()`, supérieur DODLP)** : `z_sub_list_field_widget.dart` — a11y **déjà corrigée** par fp-5-1. **Ne pas retoucher.**
- **rowChips (mono-choix `ChoiceChip`) / tags (bouton `+` ≥48dp, aucune dep `flutter_tags`) / slider (min/max/divisions) / signature (strokes vectoriels, 0 dep)** : natifs et fonctionnellement à parité — **seule** la dette double-annonce (rowChips, tags — cf. §Décisions) est à traiter ; slider/signature/subItems n'ont **pas** cette dette (grep négatif ci-dessous).
- **Seams `hidden`/`widget`/`custom`** : comportements/seams natifs (`ZWidgetRegistry`/`ZTypeRegistry`) ne recevant que `ctx.value`/`ctx.onChanged`, jamais le `ZFormController` (AD-2). **Confirmés natifs, pas un widget à polir** — la story n'y touche pas (aucune régression du contrat de seam).

**CE QUI EST HORS de cette story (frontières dures) :**
- **Aucun** ajout d'`EditionFieldType`/valeur d'enum (fp-1-1 / fp-5-1 s'en chargent). Aucune écriture `domain/`.
- **Aucun** satellite (`zcrud_select`, `zcrud_media`, `zcrud_html`, `zcrud_intl`, `zcrud_geo`, `zcrud_markdown`, bindings).
- **Aucune** page showcase / harnais `example/` (fp-3).
- **Aucune** roue HSV `flex_color_picker` au cœur (reste `ZcrudScope.colorPicker` côté binding, NFR-2).
- **`file`/`image`/`document`** : impl concrète `ZFilePicker` = **différée (E7/satellite)** ; ici, seule la **dette a11y double-annonce du wrapper natif `ZAppFileField`** (label de conteneur) est traitée — pas l'adaptateur de sources.

## Décisions tranchées (le seul écart de parité réel : dette a11y "double annonce")

**Défaut ciblé (prouvé sur disque, motif identique à celui corrigé par fp-4-4/fp-5-1) :** un widget porte `Semantics(container: true, label: resolvedLabel, …)` **et** rend, en enfant visible, un `Text(resolvedLabel)`. Comme le `Text` produit déjà un nœud sémantique portant le même texte, le libellé du champ est **annoncé deux fois**. Le **patron de correction établi** (cf. `z_color_multi_field_widget.dart:169-179`, corrigé par fp-4-4) : **retirer le `label:` du `Semantics(container:true)`** — le `Text` visible fournit déjà le nom accessible du conteneur — en **conservant** `value:`/`readOnly:`/`liveRegion:` éventuels (qui, eux, ne sont pas dupliqués par le Text). Ajouter le commentaire explicatif au même format que le précédent fp-4-4.

**Inventaire disque des 5 familles portant la dette (à corriger) :**

| Fichier | `Semantics(container:true,label:)` | `Text(resolvedLabel)` visible | Attributs à préserver |
|---|---|---|---|
| `z_color_field_widget.dart` | l.142-144 (`label: resolvedLabel`) | l.154 | (aucun autre sur ce conteneur) |
| `z_rating_field_widget.dart` | l.63-64 (`label: resolvedLabel`) | l.72 | `value: '$current / $max'` |
| `z_tags_field_widget.dart` | l.104-105 (`label: resolvedLabel`) | l.112 | (aucun autre) |
| `z_row_chips_field_widget.dart` | l.88-89 (`label: resolvedLabel`) | l.96 | (aucun autre) |
| `z_app_file_field_widget.dart` | l.221-222 (`label: resolvedLabel`) | l.228 | (aucun autre ; **ne PAS** toucher le 2ᵉ `Semantics` l.386, `altLabel`+`value:stateLabel`, sans `Text(resolvedLabel)` → pas de dette) |

**Familles NATIVES SANS cette dette (grep négatif — NE PAS toucher, éviter le polish gratuit) :**
- `z_dynamic_item_field_widget.dart` : `container:true` + `label` (l.218-219) **mais aucun** `Text(resolvedLabel)` visible → annonce simple, **conforme**.
- `z_signature_field_widget.dart` : `label: '$resolvedLabel: signatureArea'` + `value: stateLabel` (l.189-191), pas de `Text(resolvedLabel)` → **conforme**.
- `z_slider_field_widget.dart` : pas de `container:true` (label porté par le `Slider`/décoration) → **conforme**.
- `z_sub_list_field_widget.dart` (fp-5-1) et `z_color_multi_field_widget.dart` (fp-4-4) : **déjà corrigés**.
- `z_boolean_field_widget.dart`, `z_date_field_widget.dart`, `z_date_range_field_widget.dart`, `z_number_field_widget.dart`, `z_text_field_widget.dart` : pas de motif conteneur+Text redondant → **conformes**.

**Justification de l'inclusion des 5 (pas du seul `z_color_field`) :** la consigne nomme `z_color_field_widget.dart` comme cas connu, mais le grep prouve **4 autres familles** portant **exactement** le même défaut d'a11y (bug de correction, pas cosmétique). fp-4-4/fp-5-1 ont déjà acté que ce motif est une dette à corriger ; laisser 4 familles natives divergentes serait une **incohérence de parité a11y** au sein du cœur. Le périmètre reste donc **borné et prouvé** (5 fichiers, 1 motif), pas une chasse cosmétique ouverte.

## Acceptance Criteria

1. **(FR-19 · AD-13 — color simple)** **Given** `z_color_field_widget.dart` rendu avec un `resolvedLabel` **When** un lecteur d'écran parcourt le champ **Then** le libellé du champ est annoncé **une seule fois** : le `Semantics(container:true)` (l.142) **ne porte plus** `label: resolvedLabel`, le `Text(resolvedLabel)` visible (l.154) reste l'unique source du nom accessible ; le picker built-in (`ZColorPickerDialog`), la palette, l'aperçu et le seam `ZcrudScope.colorPicker` restent **intacts** ; un commentaire au format fp-4-4 explicite le retrait.

2. **(FR-29 — rating)** **Given** `z_rating_field_widget.dart` **When** rendu **Then** le `Semantics(container:true)` (l.63) **ne porte plus** `label: resolvedLabel` mais **conserve** `value: '$current / $max'` ; le `Text(resolvedLabel)` visible (l.72) reste le nom accessible ; max configurable + toggle-clear + a11y des étoiles **inchangés** (supérieur DODLP préservé).

3. **(FR-11 — tags)** **Given** `z_tags_field_widget.dart` **When** rendu **Then** le `Semantics(container:true)` (l.104) **ne porte plus** `label: resolvedLabel` ; le `Text(resolvedLabel)` (l.112) reste le nom ; le bouton `+` d'ajout **reste ≥48dp** et son `Semantics` propre est inchangé (annonce du bouton non affectée).

4. **(FR-10 — rowChips)** **Given** `z_row_chips_field_widget.dart` **When** rendu **Then** le `Semantics(container:true)` (l.88) **ne porte plus** `label: resolvedLabel` ; le `Text(resolvedLabel)` (l.96) reste le nom ; le comportement mono-choix `ChoiceChip` et l'annonce `selected` de chaque puce sont **inchangés**.

5. **(FR-14 — file wrapper natif)** **Given** `z_app_file_field_widget.dart` **When** le wrapper natif est rendu **Then** le **premier** `Semantics(container:true)` (l.221) **ne porte plus** `label: resolvedLabel` (le `Text(resolvedLabel)` l.228 reste le nom) ; le **second** `Semantics` (l.386, `altLabel`+`value: stateLabel`+`liveRegion`) est **laissé strictement intact** ; aucun changement de l'impl différée `ZFilePicker`/`ZFileSource`.

6. **(Non-régression a11y — familles conformes)** **Given** les familles natives **sans** dette prouvée (`dynamicItem`, `signature`, `slider`, `subItems`, `color_multi`, `boolean`, `date`, `dateRange`, `number`, `text`) **When** la story est terminée **Then** elles sont **inchangées** (aucun diff), démontré par l'absence de modification hors des 5 fichiers listés.

7. **(SM-1 / AD-2 — non-régression réactivité)** **Given** les 5 fichiers modifiés **When** un champ est édité **Then** **aucun** `TextEditingController` n'est recréé, **aucune** logique de rebuild n'est modifiée (le patch touche **exclusivement** l'arbre `Semantics`, jamais le montage `ZFieldListenableBuilder`/`onChanged`/controller) ; le banc SM-1 (frappe → rebuild du seul champ courant, zéro perte de focus) reste vert.

8. **(CORE OUT=0 · graphe acyclique)** **Given** `packages/zcrud_core/pubspec.yaml` **When** la story est terminée **Then** **aucune** dépendance lourde n'est ajoutée (CORE OUT=0 inchangé), aucun import de satellite/binding/gestionnaire d'état, graphe de dépendances toujours acyclique.

9. **(Vérif verte)** **Given** le workspace **When** on rejoue `melos run generate` → `dart analyze` → `flutter test` **Then** RC=0 partout ; le gate `codegen-distribution`/anti-`reflectable`/secrets reste vert ; aucun `*.g.dart` n'a à changer (aucune annotation/enum modifiée).

## Tasks / Subtasks

- [x] **Task 1 — Vérifier l'état réel sur disque avant tout patch (discipline R3, ABSENCE=grep négatif)** (AC: #1-#6)
  - [x] Rejouer `grep -rn "container: true" families/*.dart` et, pour chaque, confirmer présence/absence d'un `Text(resolvedLabel)` frère (prouver la table de l'inventaire).
  - [x] Rejouer le grep négatif directionnel/thème/l10n (cf. §Contexte) pour **prouver** qu'il n'y a rien d'autre à corriger (ne pas élargir le périmètre).
  - [x] Lire intégralement les 5 fichiers cibles (état courant, ce qui doit être préservé : `value:`/`readOnly:`/`liveRegion:`, montage réactif, seams).
- [x] **Task 2 — Corriger la double annonce sur `z_color_field_widget.dart`** (AC: #1)
  - [x] Retirer `label: resolvedLabel` du `Semantics(container:true)` (l.142) ; ajouter le commentaire explicatif (format fp-4-4).
  - [x] Vérifier que le `Text(resolvedLabel)` visible et tous les `Semantics` internes (boutons picker, palette, hex, récents) restent intacts. `value:` (hex courant) conservé.
- [x] **Task 3 — Corriger `z_rating_field_widget.dart`** (AC: #2) — retirer `label:` du conteneur, **conserver** `value: '$current / $max'`, commentaire.
- [x] **Task 4 — Corriger `z_tags_field_widget.dart`** (AC: #3) — retirer `label:` du conteneur, ne pas toucher le bouton `+` ni son `Semantics`.
- [x] **Task 5 — Corriger `z_row_chips_field_widget.dart`** (AC: #4) — retirer `label:` du conteneur, ne pas toucher les `ChoiceChip`.
- [x] **Task 6 — Corriger `z_app_file_field_widget.dart`** (AC: #5) — retirer `label:` du **1er** conteneur (l.221) uniquement ; **ne pas** toucher le 2ᵉ `Semantics` (l.386).
- [x] **Task 7 — Tests porteurs a11y (canal Semantics, injection R3)** (AC: #1-#7)
  - [x] Pour chacune des 5 familles : test widget qui **compte les occurrences du libellé** dans l'arbre sémantique et **assert = 1** (les conteneurs `container:true` fusionnant leurs descendants, on compte les occurrences de sous-chaîne — pas les nœuds). Falsifiabilité prouvée : mutation locale « re-ajouter `label:` » sur tags ⇒ test RED (Actual: 2), puis reverté.
  - [x] Pour rating : assert que le nœud conteneur porte toujours `value == '3 / 5'` (`_hasSemanticsValue`) — prouve que `value:` n'a pas été retiré par erreur.
  - [x] Pour app_file : assert que le 2ᵉ `Semantics` (état upload, `value: stateLabel = 'photo.png'`) est intact.
  - [x] Injection R3 : mutation locale « re-ajouter `label:` au conteneur tags » ⇒ test RED confirmé, puis revert (aucune mutation committée).
- [x] **Task 8 — Non-régression & vérif verte** (AC: #6-#9)
  - [x] `git status --porcelain` ⇒ mes seules écritures = les 5 fichiers de `families/` + 1 test ajouté ; **aucun** `domain/`, **aucun** satellite, **aucun** `*.g.dart` de mon fait (les autres diffs du working tree = workstreams parallèles fp-2-2/fp-4-4/fp-5-2/fp-5-3).
  - [x] `pubspec.yaml` de `zcrud_core` inchangé (CORE OUT=0, graphe acyclique — `graph_proof.py`).
  - [x] `dart analyze` RC=0 (4 info deprecations `pipelineOwner`, idiome repo existant) → `flutter test packages/zcrud_core` RC=0 (1018 tests) ; codegen no-op (aucune annotation/enum modifiée).

## Dev Notes

- **Patron de correction unique (ne pas improviser)** : le diff par fichier est **minimal** — suppression d'une ligne `label: resolvedLabel,` sur un `Semantics(container:true)` + un commentaire de 2-3 lignes copié du style fp-4-4. **Ne rien refactorer d'autre**, ne pas « améliorer » les couleurs/paddings/labels visibles (déjà à parité). Toute écriture hors des 5 fichiers = hors périmètre.
- **Pourquoi retirer `label:` et non ajouter `excludeSemantics`/`explicitChildNodes`** : c'est le choix déjà **acté et livré** par fp-4-4 (`z_color_multi_field_widget.dart:171-178`) et fp-5-1 (`z_sub_list_field_widget.dart`). Rester cohérent évite deux stratégies d'a11y divergentes dans le même dossier. Le `Text` visible **est** le nom accessible du conteneur ; le conteneur n'a donc pas à le redupliquer.
- **Préserver impérativement** : les attributs **non** dupliqués par le `Text` — `value:` (rating), `readOnly:`, `liveRegion:` (app_file 2ᵉ Semantics) ; le montage réactif (`ZFieldListenableBuilder`, `onChanged`, controller stable) ; les `Semantics` **internes** aux boutons/puces (annoncent une action, pas le nom du champ — jamais une double annonce).
- **AD-2 / SM-1** : le patch ne touche **aucune** logique d'état → aucun risque de régression jank/focus ; néanmoins, ne pas déplacer la construction de champ dans une closure de `build()`, ne pas recréer de controller (le patch ne doit pas s'approcher de ces zones).
- **AD-13** : la story ne **crée** aucune nouvelle directionnalité (déjà conforme, grep négatif) — ne pas introduire par mégarde d'`EdgeInsets.only(left/right)` en éditant.
- **FR-26** : ne recopier **aucune** couleur/mesure DODLP hardcodée ; la story ne touche pas au style.
- **Verdict honnête de périmètre** : cette story est **mince par conception** — c'est une story de **confirmation + une seule catégorie de correction a11y prouvée** (5 fichiers). L'essentiel de la « parité champs natifs » était déjà atteint par E3/E4/DP-*. Ne pas gonfler artificiellement le travail.

### Project Structure Notes

- Écriture **exclusive** dans `packages/zcrud_core/lib/src/presentation/edition/families/` (5 fichiers) + tests sous `packages/zcrud_core/test/presentation/edition/`.
- Aucune écriture `domain/`, aucun nouvel enum/spec, aucun `*.g.dart` (aucune annotation modifiée → codegen no-op).
- Conforme à la règle CORE-SÉRIALISÉE : seul écrivain `zcrud_core` sur sa fenêtre ; fichiers **disjoints** de fp-2-2 (binding/satellites).

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-form-parity-2026-07-18/epics.md#Story-2.1 (l.282-328)]
- [Source: docs/dodlp-form-integration-study-2026-07-17/FIELD-PACKAGE-MATRIX.md#1-Matrice-maitresse (✅ NATIF lignes 1-16,25-27,37-40) + #3 (natif suffit)]
- [Source: docs/dodlp-form-integration-study-2026-07-17/06-aeration-layout.md#3 (tokens déjà présents) + §4.3 (formPadding, livré par fp-1-1)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_color_multi_field_widget.dart:169-179 (patron de correction fp-4-4)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart:142-154 · z_rating_field_widget.dart:63-72 · z_tags_field_widget.dart:104-112 · z_row_chips_field_widget.dart:88-96 · z_app_file_field_widget.dart:221-228,386-388 (cibles + zone à préserver)]
- [Source: CLAUDE.md — invariants AD-1/AD-2/AD-13/FR-26 ; Key Don'ts (Semantics, directionnel, thème)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (1M context) — bmad-dev-story

### Debug Log References

- `grep -rn "container: true" families/*.dart` → inventaire confirmé (5 familles avec `label:` + `Text(resolvedLabel)` : color/rating/tags/rowChips/app_file[1er]).
- Grep négatif directionnel/thème (5 fichiers) → 0 violation réelle (seuls matches : une ligne de commentaire dans `z_color_multi` et un `.isNotEmpty`).
- Dump de l'arbre sémantique : les conteneurs `container:true` **fusionnent** leurs descendants → la double annonce se lit comme 2 occurrences de la sous-chaîne dans le `label` du nœud fusionné (ex. tags avant fix : `"Étiquettes|Étiquettes|x|Add tag"`). D'où le compteur d'occurrences (pas de nœuds).
- Falsifiabilité (R3) : re-ajout temporaire de `label: resolvedLabel` sur `z_tags` ⇒ test RED (`Expected: <1> Actual: <2>`), puis revert par sauvegarde disque (jamais `git checkout`).

### Completion Notes List

- Correction du seul écart de parité réel MVP : dette a11y « double annonce » sur 5 familles natives, patron fp-4-4/fp-5-1 (retrait du `label:` du `Semantics(container:true)` ; le `Text` visible fournit le nom accessible ; commentaire explicatif ajouté).
- Attributs **préservés** : `value:` du conteneur `color` (hex courant) et `rating` (`'$current / $max'`) — non dupliqués par le `Text` ; 2ᵉ `Semantics` d'`app_file` (état upload, `altLabel`+`value`+`liveRegion`) laissé strictement intact.
- Aucune logique d'état/rebuild/controller touchée (AD-2/SM-1) ; aucune dépendance ajoutée (CORE OUT=0, graphe acyclique) ; aucun `*.g.dart` (codegen no-op).
- Familles déjà conformes laissées intactes (dynamicItem, signature, slider, subItems, color_multi, boolean, date, dateRange, number, text) — pas de polish gratuit.
- Vérif verte rejouée : `dart analyze packages/zcrud_core` RC=0 (4 info deprecations `pipelineOwner`, idiome repo existant) ; `flutter test packages/zcrud_core` RC=0 — **1018 tests** ; `python3 scripts/dev/graph_proof.py` → ACYCLIQUE OK + CORE OUT=0 OK.

### File List

- `packages/zcrud_core/lib/src/presentation/edition/families/z_color_field_widget.dart` (modifié — retrait `label:`, `value:` conservé)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_rating_field_widget.dart` (modifié — retrait `label:`, `value:` conservé)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_tags_field_widget.dart` (modifié — retrait `label:`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_row_chips_field_widget.dart` (modifié — retrait `label:`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_app_file_field_widget.dart` (modifié — retrait `label:` du 1er `Semantics` uniquement)
- `packages/zcrud_core/test/presentation/edition/fp_2_1_double_annonce_test.dart` (ajouté — 5 tests porteurs canal Semantics)
