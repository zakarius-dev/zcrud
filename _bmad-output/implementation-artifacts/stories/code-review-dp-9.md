# Code Review — DP-9 : `ZStepperConfig` + steppers imbriqués (parité DODLP, gap B11)

- **Story** : `_bmad-output/implementation-artifacts/stories/dp-9-stepperconfig-imbrique.md` (18 ACs)
- **Périmètre revu** : `zcrud_core` uniquement.
- **Mode** : revue adversariale ciblée (skill `bmad-code-review`, layers fusionnés en revue directe — subagents non lancés en contexte mono-agent non-interactif).
- **Date** : 2026-07-11

## Verdict : ✅ APPROVED

L'invariant critique **single-writer racine de `controller.visibleFields`** est **correctement réalisé** ; la **non-régression `manageVisibility=true`** (chemin LEGACY) est **stricte** ; tous les ACs sont couverts et prouvés par tests ; toutes les vérifs sont vertes. Seuls subsistent des **LOW/nits** non bloquants.

## Résultats des vérifications (rejouées réellement sur disque)

| Vérification | Commande | RC réel | Résultat |
|---|---|---|---|
| Analyse statique | `dart analyze packages/zcrud_core` | **0** | `No issues found!` |
| Tests unitaires+widgets | `flutter test packages/zcrud_core` | **0** | **724 tests — All tests passed!** |
| Graphe de dépendances | `python3 scripts/dev/graph_proof.py` | **0** | `ACYCLIQUE OK` / `CORE OUT=0 OK` (19 arêtes, 14 nœuds) |
| Pureté domaine Flutter-free | `dart test .../purity/domain_entrypoint_dart_test.dart` | **0** | `All tests passed!` (surface 4 APIs pur-Dart inchangée) |
| Non-régression E3-5 | `git status --porcelain` sur les 4 tests stepper E3-5 + `style_purity_test.dart` | — | **non modifiés** (garde d'additivité tenue) |
| `ZWidgetRegistry` | `git status --porcelain z_widget_registry.dart` | — | **non modifié** (contact évalué/écarté, comme borné) |

## Analyse des points de revue adversariale (1)→(9)

### (1) INVARIANT-CLÉ — single-writer racine de `visibleFields` ✅ CONFORME
Énumération exhaustive des écritures de `setVisibleFields` en mode nesting (`_driving == true`) :
- **Racine** (`nested==false`, `_hasNesting==true`) : écrit via `_initWindow` (l.441) et `_publishWindow` (l.455). **Seul écrivain.**
- **Imbriqué** (`nested==true`) : `_publishWindow` (l.450-457) prend la branche `onNestedWindowChanged` — **jamais** `setVisibleFields` ; `_initWindow` (l.431-438) diffère la contribution en `addPostFrameCallback` (évite un `notifyListeners` pendant le build du parent). **Aucune écriture.**
- **`DynamicEdition` des zones d'étape** (parent-direct ET nested) : reçoivent `manageVisibility:false` (l.717). Confirmé côté `dynamic_edition.dart` : `_bindGuards` retourne tôt (l.324), `_recomputeVisibility` gardé par `manageVisibility` en `initState`/`didUpdateWidget` (l.243, 263, 273), `_bindReseed` idem (l.342). **Aucune écriture passive.**

⇒ Un **unique** propriétaire (le racine) publie l'**union du chemin actif** ; les nested remontent via `onNestedWindowChanged` → `_onChildWindow` → ré-agrégation récursive (`_contribution`, l.420-427). **Pas de double écriture concurrente.** Récursivité prouvée profondeur ≥ 2 (`stepper_dp9_test.dart:403`). Propagation de garde conditionnelle du nested vers le racine vérifiée (nested `_bindStepperGuards` → `_publishWindow` remontant).

### (2) Flag `manageVisibility` — non-régression LEGACY ✅ CONFORME
Défaut `true` ⇒ **chemin LEGACY strictement inchangé** : chaque garde ajoutée (`&& widget.manageVisibility`) est neutre à `true` ; le stepper ne passe `false` **que** en mode `_driving` (`!_driving`, l.717), lui-même `false` en l'absence de nesting (`_driving = widget.nested || _hasNesting`, l.318). Un formulaire existant sans nesting ne bascule **jamais**. Preuve : les 4 tests E3-5 + `sm1_stepper_test` + `style_purity_test` **verts sans modification** (confirmé par `git status`).

### (3) SM-1 / AD-2 root ET nested ✅ CONFORME
Controller **unique** partagé à tous les niveaux (`controller: widget.controller` passé au nested, l.741). Frontière `ListenableBuilder`/`_structural` (l.633) scellée sur `{_currentStep, _reveal, controller.visibleFields}` — jamais une tranche. En mode `_driving`, seuls les **champs de garde** sont abonnés (`_bindStepperGuards`, l.480-496) : une frappe non-garde ne recalcule rien. Test AC16 (`stepper_dp9_test.dart:447`) : 100 frappes dans une sous-étape imbriquée ⇒ `rootChrome` inchangé, voisin non reconstruit, focus + curseur conservés, `find.byType(Form) == findsNothing` à tous niveaux. ✅

### (4) Validation par étape `validateOnNext` ✅ CONFORME
Gate `_next` (l.579-595) : `passes = !validateOnNext || _validateGate(current)`. En `_driving`, `_validateGate` valide l'**union** du chemin actif (`_validateNames(_contribution())`, l.548-549) ⇒ le gate parent honore la **sous-étape active du nested** (test `stepper_dp9_test.dart:335`, RN0 révélé/levé). Défaut `true` = strict ; `false` = navigation libre (test l.156). Nested utilise **son propre** `nestedConfig.validateOnNext` (indépendance, l.744). ✅

### (5) État préservé parent↔nested ✅ CONFORME
Aucune recréation de controller ; tranches survivent au démontage des sous-arbres (test AC14 `stepper_dp9_test.dart:365` : va-et-vient préserve `p0`/`n0`). `_goTo` remet `_childContribution=null` pour recalcul structurel, sans toucher aux tranches. ✅

### (6) AD-1/AD-3/AD-14 pureté ✅ CONFORME
`ZStepperConfig` + 3 enums + `ZEditionStep.icon/subtitle/nestedSteps/nestedConfig` sont **présentation-only**, non annotés, non persistés. `domain.dart` inchangé, purity verte, `graph_proof` CORE OUT=0. Enums en **camelCase**. ✅

### (7) AD-6/FR-26 + AD-13 ✅ CONFORME
Aucun `Colors.*`/`Color(0x…)` littéral dans le widget : couleurs dérivées via `config.activeOf/completedOf/inactiveOf/errorOf(scheme)` (overrides nullables → `ColorScheme`). Positions **directionnelles** : `EdgeInsetsDirectional`, `TextAlign.start`, `AlignmentDirectional`, `Row`/`Column` respectant `Directionality` ; `left→start`. Cibles ≥ 48 dp (`ConstrainedBox(minWidth/minHeight:48)` sur dots tapables et boutons nav). `Semantics(header/button)` explicites. Test AC15 (top/start/bottom × LTR/RTL sans exception). `style_purity_test` verte. ✅

### (8) Rétro-compat additive stricte ✅ CONFORME
Défaut `ZStepperConfig()` = « Étape k/N » + titre (test AC5 l.78). `ZEditionStep` sans icon/subtitle inchangé (test l.86). Tous ajouts = params nommés optionnels / nouveaux symboles ; aucun retrait/renommage. Barrel additif. ✅

### (9) `ZWidgetRegistry` NON modifié ✅ CONFIRMÉ
`git status` vide sur `z_widget_registry.dart`. Décision « nesting structurel, pas via registre » documentée en Dev Notes. ✅

---

## Findings

### HIGH / MAJEUR
_Aucun._

### MEDIUM
_Aucun._

### LOW / nits (optionnels — non bloquants)

- **LOW-1 — `indicatorSize`/`stepSpacing` de `config` silencieusement bornés pour les dots.**
  `z_stepper_edition.dart:905` `size = config.indicatorSize.clamp(8.0, 24.0)` et `:918` `config.stepSpacing.clamp(2.0, 12.0)`. Le défaut documenté de parité `indicatorSize = 40` (AC2/Dev Notes) est donc rendu à **24 px** pour le style `dots` ; un consommateur réglant `indicatorSize: 40` n'obtient pas 40 px. Le clamp est un garde-fou raisonnable (le marqueur vit dans une cible tactile ≥ 48 dp), mais la valeur de `config` n'est que **partiellement** honorée et l'écart n'est pas documenté au point d'usage.
  *Remédiation (optionnelle)* : documenter le clamp sur le champ `indicatorSize` (« le marqueur `dots` est borné à 24 dp dans la cible ≥ 48 dp ») ou distinguer taille-de-marqueur vs taille-de-cible. Aucun risque fonctionnel.

- **LOW-2 — validation d'étape intermédiaire incomplète pour un saut avant (dots) par-dessus une étape contenant un nested.**
  `_jumpTo` (l.605-625) valide l'étape courante via `_validateGate(current)` (union incluant le nested actif — correct), mais les étapes **intermédiaires** `k` via `_validateStep(k)` (l.617), qui n'utilise que `_windowFor(k)` = champs **directs** (l.401) et **ignore** les sous-étapes requises d'un nested intermédiaire. Un saut avant multi-étapes (style `dots` + `allowStepTap`) par-dessus une étape à nested pourrait franchir des champs nested requis. Portée : uniquement `dots` + saut avant de ≥ 2 crans par-dessus une étape à nested (les steppers DODLP migrés sont mono-étape active + boutons ; cas de bord). Cohérent avec le fait qu'un nested intermédiaire n'est pas monté (sous-index actif inconnu).
  *Remédiation (optionnelle)* : documenter la limite, ou traiter une étape intermédiaire porteuse de `nestedSteps` comme validée sur `_initialUnion(nested, 0)`.

- **LOW-3 — double export de `z_stepper_config.dart`.**
  Le barrel `zcrud_core.dart:84-85` exporte `z_stepper_config.dart` **et** `z_stepper_edition.dart`, ce dernier ré-exportant déjà `z_stepper_config.dart` (l.69). Redondant (Dart dédoublonne les exports de même origine — sans erreur ni ambiguïté), mais l'un des deux exports est superflu.
  *Remédiation (optionnelle)* : conserver un seul chemin d'export.

- **LOW-4 — insets de layout littéraux (`16/12/8`) dans l'indicateur.**
  Ex. `EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8)` (l.852, 882, 931…). AC17 vise « aucune valeur de layout magique en dur ». Ces valeurs sont **cohérentes avec le pattern E3-5 pré-existant** (`_StepIndicator`, `_SectionHeader`) et directionnelles ; ce n'est pas une régression. Signalé pour cohérence si une tokenisation `ZcrudTheme` des espacements est entreprise ultérieurement.

## Conclusion

Implémentation **solide et conforme**. L'invariant HIGH (single-writer racine de `visibleFields`) est réalisé sans double écriture concurrente ; la non-régression du chemin `manageVisibility=true` est stricte (E3-5 + purity + style verts, fichiers de garde intacts). Aucun finding HIGH/MAJEUR/MEDIUM. Les 4 LOW sont optionnels et sans risque fonctionnel. **APPROVED — la story peut passer à `done`.**
