# Code Review — E3-6 : Soumission create/update + détection *dirty* + états UI

- **Story** : `_bmad-output/implementation-artifacts/stories/e3-6-soumission-create-update-dirty.md` (14 ACs, statut `review`, DERNIÈRE story d'E3, absorbe reports a/b/c).
- **Baseline** : `acc6a213` (= HEAD ; tout E3 est **non commité** dans l'arbre de travail — le répertoire `presentation/edition/` est entièrement `untracked`).
- **Reviewer** : `bmad-code-review` (skill réel invoqué ; étape adversariale exécutée par lecture directe des artefacts E3-6 + rejeu de la vérif verte).
- **Date** : 2026-07-10.
- **Verdict** : **APPROVED** (0 HIGH / 0 MAJEUR ; 1 MEDIUM déjà justifié-déféré par la story ; 3 LOW).

---

## 1. Vérifications réellement rejouées sur disque

| Contrôle | Commande | Résultat |
|---|---|---|
| Analyse cœur | `dart analyze` (zcrud_core) | **RC=0** — `No issues found!` |
| Tests cœur | `flutter test` (zcrud_core) | **RC=0** — **387** tests OK (362 baseline + 25 E3-6) |
| Gate de merge | `melos run verify` | **RC=0** |
| Graphe AD-1 | `graph_proof.py` | **CORE OUT=0 OK**, **ACYCLIQUE OK**, 14 nœuds, 17 arêtes |
| Packages | `melos list` | **14** |
| Anti-`reflectable` | gate | OK (0 usage hors allowlist) |
| Scan secrets | gate | OK |
| Codegen | gate | OK (1 modèle `@ZcrudModel`, 0 `.g.dart` manquant) |
| Compat manifeste | gate | OK |
| Corpus sérialisation AD-10 | gate | OK (25 cas défensifs) |
| `.g.dart` committés | `git ls-files '*.g.dart'` | 0 |

Le message `ERROR: No tests match ... "serialization-compat"` est le **slot no-op documenté E2-10** (verify:serialization) et **ne fait pas échouer** la chaîne (`VERIFY_RC=0`).

---

## 2. Confirmation des points de vigilance adversariaux

### Cœur agnostique manager (AD-15 / AD-11) — **CONFIRMÉ vert**
- `grep -rnE "package:(flutter_riverpod|riverpod|get/|provider/)"` sur `packages/zcrud_core/lib/` → **0**.
- `AsyncValue` dans `lib/` → **uniquement en dartdoc** (`z_submission.dart` l.13-14/170-173, barrel l.113) documentant le pont réalisé au binding ; **aucun symbole importé**.
- `ZOnSubmit<T> = Future<ZResult<T>> Function(Map<String,Object?>)` avec `ZResult<T> = Either<ZFailure,T>` (`z_failure.dart:93`). `ZSubmissionState` porte un `ZFailure?` — **aucun type manager**. `CORE OUT=0` prouvé.
- Test de pureté (`presentation_purity_test.dart`) bannit `flutter_riverpod/riverpod/get/provider` + tokens `WidgetRef/Get.find/Get.put/Provider.of` sur tout `lib/` (2 tests + garde bidirectionnelle `services.dart`).

### `onSubmit` NON-sérialisé — **CONFIRMÉ**
- Le snapshot passé à `onSubmit` est `controller.values` : `Map<String,Object?>.unmodifiable` **de données pures** (`z_form_controller.dart:142-146`).
- `onSubmit` (`ZEditionSubmitController.onSubmit`, champ du contrôleur dédié) et `onConfirmDiscard` (`ZDiscardGuard.onConfirmDiscard`, param widget) vivent **HORS** `ZFormController` → jamais dans une tranche, jamais traversés par le codegen (AD-3).
- Test `AC3` : le snapshot capturé == `{nom:Ada, age:42}`, assertions `v is Function == false`, `v is Widget == false`, mutation → `throwsUnsupportedError`. **Aucune fuite** (grep : aucun `Widget`/`Function`/`VoidCallback` stocké via `setValue`).

### Soumission agrégée — **CONFIRMÉ**
- `_aggregateValidate` (`z_submission.dart:257-272`) itère **tout le catalogue `fields`** en honorant `field.condition` via `evaluateZCondition` (un champ masqué par condition `continue` → ne bloque pas). `showIfNull` n'affecte que le **mode lecture** (`dynamic_edition.dart:288-292`, `if (!readOnly) return true`) → sans effet à la soumission (correct).
- Stepper : l'agrégation **toutes-étapes** repose sur le **catalogue complet** passé au contrôleur (pas `visibleFields`, qui ne reflète que l'étape courante) + honneur des conditions. Sain **par conception** (voir LOW-1 : non couvert par test).
- `onSubmit` NON appelé si invalide : test `AC1` (`calls==0`) + `reveal_all_families` (`calls==0`).
- Révélation **toutes familles** (report a) : `select`/`dateTime`/`tags` requis vides → `find.text('err-*') findsOneWidget` chacun, `≥3` nœuds `liveRegion`, `find.byType(Form) findsNothing`. Familles clavier → `errorText` natif (autovalidate `always`) ; non-texte → surface additive `Semantics(liveRegion)+Text` (`z_field_widget.dart:274-299`). **Source unique** : `ZCrossFieldValidator.compileField` utilisée par le widget ET l'agrégat (messages cohérents).

### Dirty — **CONFIRMÉ**
- Baseline vs courant (`_updateDirty`, `z_form_controller.dart:125-135`), toggle au **flip** uniquement (test `AC8` : 3 écarts → `toggles==1`). `ValueNotifier<bool>` **dédié** ; `setValue`/dirty n'émettent **jamais** `notifyListeners()` global (test : `global==0`). `reset`/`markPristine`/`reseed` cohérents (tests dédiés). SM-1 non cassé (voir plus bas).

### Inter-champs (report b) — **CONFIRMÉ (avec MEDIUM-1 sur les dates)**
- `match`/`minKey`/`maxKey` produits par closures capturant le controller, lues à l'invocation via `valueOf(refKey)` (`z_cross_field_validator.dart`). `ZValidatorCompiler` **skippe proprement** les variantes `refKey` (bound null → `null`, l.78-88) → **partition sans double-validation ni NPE**.
- Réévaluation **live** par abonnement **CIBLÉ** à `fieldListenable(refKey)` (`z_field_widget.dart:141-147`, `_revealAndRefs = Listenable.merge`) + fallback garanti à `submit()`. Test `AC12` : taper dans un champ **tiers** (`email`) ne reconstruit **pas** `confirm` ; modifier le **référencé** (`password`) le réévalue.
- Référence indéterminée/non numérique → **non bloquant** (test dédié : ref `abc`/absente → `null`).

### Write-back externe (report c) — **CONFIRMÉ**
- `reset()`/`reseed()` incrémentent `reseedRevision` ; texte/nombre re-lus **hors focus** via `_syncText` (guard `!hasFocus`) + **report différé** à la perte de focus (`_onFocusChange`, `z_field_widget.dart:170-179`). subList/dynamicItem re-clés via `_reseedable` (ValueListenableBuilder sur `reseedRevision`).
- Test `AC13` **focalisé** : `reseed({a:'EXTERNE'})` pendant saisie `'partiel'` → buffer **inchangé** (`'partiel'`), `valueOf=='EXTERNE'` ; à l'`unfocus` → buffer reflète `'EXTERNE'`. **Une saisie focalisée n'est JAMAIS écrasée** (FR-1 respecté).

### États AD-11 — **CONFIRMÉ**
- `inProgress` désactive le bouton (`onPressed:null`) + spinner + `Semantics(enabled:false)` (`z_submit_button.dart`). Garde de ré-entrance en tête de `submit()` (avant tout `await`, donc pas de fenêtre de course) → test `AC5` : 2ᵉ appel `ignored`, `calls==1`. **Double submit impossible**.
- Échec `Left(ZFailure)` → `failure(f)` en `liveRegion`, bouton **réactivé** (test `AC5/AC6`). Exception → **enveloppée** `ServerFailure` (`catch (e)`, jamais `catch(_){}` nu) — test dédié.

### SM-1 — **CONFIRMÉ**
- Test `sm1_submission` : 100 frappes → voisin **0** rebuild, chrome structurel inchangé, `stateNotifs==0` (état soumission intact), bannière dirty **≤1** flip, focus conservé, curseur en fin, `find.byType(Form) findsNothing`. Le `ZDiscardGuard` réutilise `widget.child` (référence stable) → pas de rebuild de sous-arbre au flip dirty.

---

## 3. Findings (triage sévérité)

### HIGH / MAJEUR
Aucun.

### MEDIUM

**MEDIUM-1 — `minKey`/`maxKey` ne comparent que numériquement (`num.tryParse`) : l'exemple normatif AC11 sur les DATES n'est pas honoré (accepte silencieusement une plage de dates invalide).**
- Fichier : `z_cross_field_validator.dart:102-118`.
- `_compileOne` (min/max) fait `num.tryParse(value)` / `num.tryParse(valueOf(refKey))` ; **toute valeur non numérique (chaîne ISO de date) ⇒ `null` ⇒ non bloquant**. Or l'AC11 énonce littéralement : « Given `dateFin` avec `minKey('dateDebut')` et une valeur < `dateDebut` → Then invalide et révélé ». Ce cas **retourne `null` (valide)** → une plage de dates inversée passerait la soumission.
- **Scénario d'échec** : formulaire E7/E8 avec `dateFin.minKey('dateDebut')`, `dateDebut='2026-05-10'`, `dateFin='2026-01-01'` → `submit()` réussit alors que la contrainte est violée (faux négatif de validation, donnée incohérente persistée).
- **Statut** : **JUSTIFIÉ-DÉFÉRÉ**. La story résout explicitement ce point en **ambiguïté #5** (« `min/max` refKey via `num.tryParse` ; pour les dates ISO, comparaison `DateTime.tryParse`/lexicographique **documentée** ; à affiner E7/E8 ») et le test `cross_field_validator` ne couvre volontairement que le numérique. Le contrat « référence indéterminée ⇒ non bloquant » est tenu.
- **Action recommandée (avant E7/E8, pas bloquante pour `done`)** : soit (a) réconcilier le **texte normatif d'AC11** pour scoper explicitement les dates hors E3-6, soit (b) ajouter une branche `DateTime.tryParse` dans `_compileOne` (min/max) — la seconde est peu coûteuse et lèverait la contradiction AC11 ↔ ambiguïté #5. Le report écrit existant (ambiguïté #5 + déférence E7/E8) satisfait la politique MEDIUM de CLAUDE.md.

### LOW / nits

**LOW-1 — Agrégation stepper « toutes étapes » (AC1) non couverte par un test.**
- `grep` confirme : **aucun** test ne câble `ZStepperEdition → ZEditionSubmitController`. La correction est **saine par conception** (le contrôleur itère le catalogue complet `fields` + conditions, indépendamment de `visibleFields`/étape courante ; T8 note « aucune modif du stepper nécessaire »), mais la clause AC1 « valide toutes les étapes visibles d'un `ZStepperEdition` » repose sur la seule inspection de code. Suggestion : un test câblant un stepper multi-étapes sur `submit()` prouvant qu'un champ invalide d'une étape **non courante** bloque + est révélé.

**LOW-2 — Re-seed de la famille `signature` dépend d'un changement de valeur de tranche (asymétrie avec subList/dynamicItem).**
- `z_field_widget.dart:381-392` : la clé signature `sig:name:reseedRevision.value` est lue **sous le builder de tranche** (pas sous `_reseedable`). subList/dynamicItem, eux, sont enveloppés dans `_reseedable` (ValueListenableBuilder sur `reseedRevision`) et re-clés **quel que soit** le changement de valeur. Pour la signature, un `reset`/`reseed` qui réécrit la **même** valeur de tranche ne provoquerait pas de remontage → pas de re-seed. Cas-limite bénin (re-seed à valeur identique = no-op fonctionnel), mais l'asymétrie mérite un commentaire ou un alignement sur `_reseedable` par cohérence.

**LOW-3 (informational) — `controller.values` sérialise TOUTES les tranches, y compris les champs masqués par condition.**
- `z_form_controller.dart:142-146` : le snapshot itère `_slices` (toutes les tranches créées), pas les seuls champs visibles/pertinents. `onSubmit` peut donc recevoir la valeur **périmée** d'un champ conditionnellement masqué. C'est un choix E3-6 acceptable (la couche data E5/E7 décide de la projection), mais à **garder en tête pour E7** (create/update réel) afin d'éviter de persister des valeurs de champs devenus invisibles.

---

## 4. Trous de couverture examinés

| Cas adversarial | Verdict |
|---|---|
| Double submit (bouton désactivé + garde ré-entrance) | Couvert (test `AC5`, `calls==1`) — **OK** |
| Reseed pendant focus multi-champs / saisie focalisée écrasée | Couvert (test `AC13` focalisé) — **OK** |
| Inter-champ sur type non numérique (ref `abc`/absente) | Couvert (non bloquant) — **OK** ; **dates → MEDIUM-1** (non couvert, déféré) |
| Abandon **non-dirty** (pop direct, seam jamais appelé) | Couvert (test `AC9` non-dirty) — **OK** |
| Exception `onSubmit` enveloppée | Couvert (test dédié) — **OK** |
| Agrégation stepper toutes étapes | **Non couvert par test** → LOW-1 |
| Re-seed signature à valeur identique | Cas-limite → LOW-2 |

---

## 5. Conclusion

La story E3-6 **clôt E3** avec une voie de soumission robuste et accessible qui respecte les invariants non-négociables : **cœur agnostique manager** (0 `AsyncValue`/manager importé, `Either<ZFailure,T>`, `CORE OUT=0`), **`onSubmit` non-sérialisé** (snapshot de données pures, seams hors modèle), **soumission agrégée** bloquante révélant **toutes les familles** sans `Form` global, **dirty** au flip unique, **inter-champs** ciblés SM-1-safe, **write-back hors focus** ne détruisant jamais une saisie, **états AD-11** (inProgress/échec/exception enveloppée), et **SM-1 re-prouvé**. Vérif verte intégrale rejouée (`analyze` RC=0, **387** tests core, `verify` RC=0, graphe OK).

Le seul MEDIUM (dates via `refKey`) est **pré-justifié et déféré** par la propre résolution d'ambiguïté #5 de la story (E7/E8) ; recommandation de réconcilier le texte d'AC11 ou d'ajouter la branche `DateTime.tryParse`. Les 3 LOW sont optionnels.

**Verdict : APPROVED** — éligible à `done` (MEDIUM justifié par écrit conformément à la politique MEDIUM de CLAUDE.md ; LOW consignés).
