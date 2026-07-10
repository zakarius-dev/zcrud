# Code Review — E3-5 · Stepper multi-étapes (même `ZFormController`)

- **Story** : `_bmad-output/implementation-artifacts/stories/e3-5-stepper-multi-etapes.md` (14 ACs, statut `review`)
- **Baseline** : `acc6a213` (frontmatter story) · **Reviewé** : arbre de travail (fichiers E3-5 non suivis)
- **Skill** : `bmad-code-review` (chemin pris : **skill Skill()** puis exécution disque `.claude/skills/bmad-code-review/steps/*` — architecture step-file). Revue autonome (sous-agent) : les 3 couches adversariales — **Blind Hunter**, **Edge Case Hunter**, **Acceptance Auditor** — exécutées inline (pas de HALT humain).
- **Date** : 2026-07-10
- **Verdict** : ✅ **APPROVED** (0 HIGH, 0 MEDIUM bloquant, 1 MEDIUM documenté/justifié, 3 LOW). Vert intégral rejoué sur disque.

---

## Périmètre reviewé (fichiers E3-5)

| Fichier | Nature |
|---|---|
| `packages/zcrud_core/lib/src/presentation/edition/z_stepper_edition.dart` | **créé** — `ZEditionStep` + `ZStepperEdition` + chrome (`_StepIndicator`, `_StepNavigationBar`) |
| `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` | **modifié** — seam additif `autovalidateMode?` |
| `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart` | **modifié** — param `autovalidateMode` (défaut `onUserInteraction`) |
| `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` | **modifié** — idem |
| `packages/zcrud_core/lib/zcrud_core.dart` | **modifié** — export du stepper |
| `test/.../stepper_edition_test.dart` · `sm1_stepper_test.dart` · `stepper_a11y_rtl_test.dart` | **créés** — 13 tests |

---

## Résultats de vérification RÉELLEMENT rejoués sur disque

| Gate | Commande | Résultat |
|---|---|---|
| Analyze | `dart analyze lib/ test/` (zcrud_core) | **No issues found** (RC=0) |
| Tests E3-5 | `flutter test` (3 fichiers stepper) | **+13 All tests passed** |
| Suite core (non-régression E3-1..E3-4) | `flutter test` (zcrud_core) | **+362 All tests passed** (RC=0) |
| Graph AD-1 | `graph_proof.py` | `ACYCLIQUE OK` · **`CORE OUT=0 OK`** · noeuds=14 |
| Verify (chaîne complète) | graph + melos-div + reflectable + secrets + codegen + compat + serialization | **tous RC=0** |
| melos list | `melos list` | **14** packages |
| `.g.dart` committés | `git ls-files '*.g.dart'` | **0** |

---

## Points de vigilance adversarial — vérifiés

### AD-2 — Un seul controller / pas de `Form` global ✅
- **Un `ZFormController` unique** : `ZStepperEdition` reçoit `controller` (jamais recréé, jamais un par étape). Chaque étape monte un `DynamicEdition` keyé `ValueKey('zstep:$index')` sur **le même** controller ; les valeurs vivent dans les tranches partagées. Test AC1 : `setValue('s2_final', …)` avant montage → réaffiché à l'étape 2 ; `identical(controller, ctrl)` vrai. **Confirmé.**
- **Aucun `Form`/`FormBuilder`** : la révélation d'erreurs passe par un **seam additif** `autovalidateMode` (bascule `always`) sur les `TextFormField` **autonomes** des familles clavier — jamais un `Form` ancêtre. Test AC2 : `find.byType(Form) findsNothing` à l'étape 0, après « suivant », au retour. **Confirmé.**
- **Aucune recréation de controller au changement d'étape** : `_currentStep`/`_reveal` sont des `ValueNotifier` locaux STRUCTURELS ; `didUpdateWidget` ne recrée le merge que si `controller` change. **Confirmé.**

### État préservé en va-et-vient ✅
- Les tranches `_slices` ne sont détruites qu'au `dispose` du controller (possédé par l'hôte). Le démontage des champs d'une étape (remontage d'un `DynamicEdition` keyé neuf) n'y touche pas. Test AC7/AC8/AC9 : `valueOf('s0_note')` inchangé après aller-retour ; buffer texte + `s0_name` réaffichés (via `ZFieldWidget.initState` → `valueOf`). **Aucune perte d'état trouvée.**

### Validation par étape ✅
- `_validateStep(i)` valide **exclusivement** les champs **visibles** de l'étape `i` (`_windowFor(i)` ∩ `_stepSpecs(i)`, conditionnels honorés), via `ZValidatorCompiler` **mémoïsé** évalué contre `_stringOf(valueOf)`. Un `required` d'une étape **ultérieure** ne bloque pas (test AC3). Un conditionnel **masqué** ne bloque pas ; rendu visible + invalide, il bloque (test AC13). **Confirmé.**
- « Suivant » invalide ⇒ index inchangé + `_reveal=true` (révélation `always` **sans** `Form`), test AC4 (`REQUIS0` révélé sans interaction préalable). « Précédent » **inconditionnel** (test AC6). Dernière étape ⇒ `onComplete` seulement si l'étape valide (test AC5 : `completeCount` reste 0 tant que `s2_final` vide). **Confirmé — frontière E3-6 respectée.**

### SM-1 dans le stepper ✅
- Chrome scellé sous `ListenableBuilder(Listenable.merge([_currentStep, _reveal, controller.visibleFields]))` — **aucune** `fieldListenable`. Test SM-1 : 100 frappes ⇒ `chromeBuilds` **inchangé**, `fieldBuilds[voisin]` **inchangé**, seul le champ cible +100, focus conservé, curseur **fin** (offset=100) ET **milieu** (insertion à l'offset 3→4 non écrasée). **Confirmé.**
- Le seam `autovalidateMode` NE réintroduit PAS de validation globale : `always` n'agit qu'à l'intérieur du sous-arbre `TextFormField` du champ (sous sa propre tranche) ; une frappe ne touche aucun canal structurel → 0 build chrome. **Confirmé.**

### a11y / RTL (AD-13) ✅
- Boutons Material (rôle `button`, `label` fusionné, `enabled` dérivé de `onPressed`) ; cible ≥ 48 dp via `ConstrainedBox(minHeight/minWidth:48)` (test : `nextSize.height`/`prevSize.height` ≥ 48) ; indicateur `Semantics(header, label:'Étape k sur N …')`. Insets `EdgeInsetsDirectional`, `TextAlign.start`. Bascule LTR↔RTL : ordre visuel Précédent↔Suivant suit la `Directionality` (test : `prevLtr < nextLtr`, `prevRtl > nextRtl`), `takeException()` null. **Confirmé.**

### Orthogonalité E3-4 ✅
- L'étape réutilise `DynamicEdition` : sélecteur de visibilité conditionnelle + sections repliables restent actifs dans l'étape montée. Fenêtre pilotée par `setVisibleFields(_windowFor(i))` (canal structurel, no-op `listEquals`) — cohérente avec le `_recomputeVisibility` interne de `DynamicEdition` (même sous-ensemble). **Aucune destruction de tranche. Confirmé.**

### Frontière E3-6 ✅
- Dernière étape ⇒ bouton « Terminer » → slot `onComplete` (désactivé si `null`). **Aucun** `onSubmit`, dirty, confirmation d'abandon, ni validateur **inter-champs** (`refKey`/`match`, restés déférés). **Confirmé.**

---

## Findings

### 🟠 MEDIUM-1 — Révélation d'erreur absente pour les familles NON-clavier (gate bloque « en silence »)
**Fichier** : `z_stepper_edition.dart` (`_stepContent` / seam `autovalidateMode`) ; `z_field_widget.dart`.
Le seam `autovalidateMode` n'est propagé qu'aux familles **texte/nombre** (`ZTextFieldWidget`/`ZNumberFieldWidget`). Le gate `_validateStep` est, lui, **agnostique de famille** (`_stringOf(valueOf(name))`) : un `required` sur un champ **non-texte** (select/date/booléen) **bloque** correctement « suivant » (aucune donnée invalide ne passe — bon), **mais** ces familles ne rendent pas de `FormField`/validateur → **aucun message d'erreur n'est révélé**. L'utilisateur voit la navigation refusée sans savoir pourquoi (impasse UX).
- **AC concerné** : AC4 (« **chaque** champ invalide de l'étape **affiche son message d'erreur** »). Littéralement non tenu pour les familles non-texte.
- **Statut** : **documenté & justifié** par la story (Ambiguïté #2 : « le must-have couvre `required`/longueur/format sur champs **texte** » ; Dev Notes révélation forcée). La sécurité des données est préservée (blocage effectif) ; seule la restitution visuelle manque, hors must-have.
- **Recommandation (E3-6)** : étendre le seam de révélation aux familles à validateur non-texte (ou afficher un résumé d'erreurs au niveau étape). **Non bloquant** pour `done` — reporté E3-6 avec justification écrite (conforme règle MEDIUM CLAUDE.md).

### 🟡 LOW-1 — `_stepSpecs(index)` alloue une liste neuve à chaque build structurel
`_stepContent` passe `fields: _stepSpecs(index)` (nouvelle `List` à chaque appel) à `DynamicEdition` ; son `didUpdateWidget` teste `!identical(oldWidget.fields, widget.fields)` → **toujours vrai** → `_rebuildIndexes` + `_bindGuards` + `_recomputeVisibility` re-exécutés à **chaque rebuild structurel** du chrome (changement d'étape, toggle `_reveal`, changement `visibleFields`). **Hors voie de frappe** (SM-1 intact, prouvé) → impact nul sur l'objectif produit ; simple travail redondant. Envisager de mémoïser les specs par étape.

### 🟡 LOW-2 — `didUpdateWidget` ne reclampe pas `_currentStep` ni ne re-fenêtre si seul `steps` change
Si `widget.steps` rétrécit à chaud (controller inchangé), `_currentStep.value` peut rester hors bornes (le `build` le clampe pour l'affichage, mais `_next` lit `_currentStep.value` non clampé → `current >= _lastStep` peut traiter à tort la dernière étape) et la fenêtre `visibleFields` n'est pas resynchronisée. Cas limite hors AC (`steps` typiquement `const`). Ajouter un clamp + `_syncWindow` sur changement de `steps`.

### 🟡 LOW-3 — Trous de couverture
- **Étape entièrement masquée / vide à l'exécution** (tous champs conditionnels off) : comportement documenté (Ambiguïté #4 : `_validateStep` passe trivialement, `setVisibleFields([])`) mais **aucun test dédié**.
- **SM-1 sous `reveal=true` (`AutovalidateMode.always`)** : les 2 tests SM-1 s'exécutent en `onUserInteraction` (reveal=false). La saisie en mode `always` (validateur ré-évalué par frappe) reste logiquement scellée dans le sous-arbre du champ (chrome non observant la tranche) — **non re-prouvé par test**.
- **Champ non-`TextFormField` avec `required`** (le cas de MEDIUM-1) : aucun test n'exerce le blocage sur famille non-texte.
- **Aller-retour rapide multi-étapes** : round-trip simple couvert (AC7) ; pas de stress 0↔N répété.

---

## Décision

**APPROVED.** Les invariants cardinaux sont tenus et **prouvés par test rejoué** : un seul `ZFormController` partagé, `find.byType(Form) findsNothing` sur toutes les étapes/transitions, état intégralement préservé en va-et-vient, validation strictement par étape (bloque/autorise/révèle sans `Form`), SM-1 re-prouvé dans le stepper (0 build chrome / 0 voisin / focus + curseur fin & milieu), a11y/RTL conformes AD-13. Vert intégral (analyze RC=0, 362 tests, verify RC=0, `CORE OUT=0`, 14 packages, 0 `.g.dart`).

Le seul MEDIUM (révélation non-texte) est **documenté et justifié** par la frontière de la story (must-have texte), la sécurité des données restant assurée → **reportable à E3-6** sans bloquer `done`. Les LOW sont des améliorations/couvertures optionnelles.
