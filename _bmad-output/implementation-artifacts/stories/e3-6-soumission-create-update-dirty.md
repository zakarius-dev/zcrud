---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---

# Story 3.6 : Soumission create/update + détection dirty + états UI

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

En tant que **développeur intégrateur d'un formulaire `DynamicEdition`/`ZStepperEdition`**,
je veux **une soumission qui valide TOUT le formulaire puis délègue à un hook `onSubmit` de mon app (create/update), avec détection *dirty*, confirmation d'abandon, et des états UI accessibles (`submit-in-progress`, échec)**,
afin de **fermer le cycle d'édition E3 par une voie de soumission robuste et accessible — sans jamais casser la granularité de rebuild (SM-1) ni sérialiser un callback/Widget**.

**C'est la DERNIÈRE story d'E3.** Elle absorbe trois reports explicitement rattachés (voir §Reports absorbés) : (a) la révélation d'erreur pour les familles NON-texte (MEDIUM-1 de la revue E3-5), (b) les validateurs **inter-champs** (`min/max` par `refKey`, `match`) déférés E3-2/E3-5, (c) le **write-back de valeur externe** (contrat `reseedRevision` hors focus) déféré E3-4.

## Acceptance Criteria

1. **AC1 — Validation agrégée bloque la soumission si invalide.** `submit()` valide **tous les champs visibles** (formulaire plat via `DynamicEdition` **ET** toutes les étapes visibles d'un `ZStepperEdition`, conditionnels honorés : un champ masqué par `displayCondition`/`showIfNull` ne bloque pas). Si **au moins un** champ visible est invalide, `onSubmit` **n'est PAS appelé**, la soumission retourne un résultat d'échec-de-validation, et l'état passe à un statut d'échec de validation (distinct de l'échec applicatif). Given un formulaire avec un `required` vide → When `submit()` → Then `onSubmit` non invoqué (compteur 0) ET état = échec validation.

2. **AC2 — Révélation d'erreur pour TOUTES les familles (report a / MEDIUM-1 E3-5).** À l'échec de validation, **chaque** champ visible invalide affiche son message d'erreur — y compris les familles **NON-texte** (`select`/`date`/`booléen`/`slider`/`tags`/…), pas seulement `texte`/`nombre`. La révélation se fait via un canal de révélation structurel (épreuve : `reveal`), sans introduire de `Form`/`FormBuilder` global (AD-2). Le message est **accessible** (`Semantics` : rôle/`liveRegion` ou `InputDecoration.errorText` selon la famille). Given un `select` `required` vide → When `submit()` → Then un message d'erreur visible et sémantiquement exposé apparaît sous le `select`. `find.byType(Form) findsNothing` reste vrai.

3. **AC3 — `onSubmit` appelé avec les valeurs (snapshot), jamais un callback/Widget sérialisé.** Formulaire valide ⇒ `onSubmit(Map<String,Object?> values)` est appelé **une fois** avec un **snapshot immuable** des valeurs de tranches (`controller.values`) — des **données pures**, jamais un `Widget`, `VoidCallback`, `Function` ou `BuildContext`. Le hook `onSubmit` (et `onConfirmDiscard`) sont détenus **hors** du `ZFormController` (paramètres du widget/contrôleur de soumission), **jamais** stockés dans une tranche ni traversés par le codegen. Given un formulaire valide → When `submit()` → Then `onSubmit` reçoit exactement les paires `name→valeur` attendues et aucune entrée de type non sérialisable.

4. **AC4 — Contrat `onSubmit` = `Either<ZFailure,T>` (AD-11).** La signature du hook retourne `Future<Either<ZFailure, T>>` (`dartz`). `Right` ⇒ succès ; `Left(ZFailure)` ⇒ échec applicatif porté dans l'état (voir AC6). Aucun `try/catch` nu : une exception jetée par le hook est **enveloppée** en `ZFailure` (`ServerFailure`/`DomainFailure`) et ne remonte pas non typée. Given un `onSubmit` renvoyant `Left(ServerFailure('x'))` → When `submit()` → Then état = échec applicatif portant ce `ZFailure`.

5. **AC5 — État `submit-in-progress` accessible.** Pendant l'attente de `onSubmit`, l'état de soumission est `inProgress` : le bouton de soumission est **désactivé** (`onPressed: null`), affiche un indicateur de progression, et est sémantiquement `enabled: false` avec un `hint`/`label` explicite. Une seconde invocation concurrente de `submit()` pendant `inProgress` est **ignorée** (pas de double soumission). Given `onSubmit` pendante → When on lit l'état + le bouton → Then `inProgress`, bouton désactivé, `Semantics(enabled:false)`.

6. **AC6 — Échec de soumission accessible (AD-11).** À `Left(ZFailure)` (ou exception enveloppée), l'état passe à `failure(ZFailure)` ; le message (`failure.message`) est rendu dans une surface d'erreur **accessible** (`Semantics` `liveRegion`), le bouton redevient actif (nouvel essai possible). Le cœur reste **agnostique du gestionnaire d'état** : il expose `ZSubmissionState.failure` (pas d'`AsyncValue`) ; le **pont `AsyncValue.error`** est réalisé au **binding** (`zcrud_riverpod`, qui déplie l'`Either`/l'état et **re-throw** l'exception typée — AD-11) et **documenté**, jamais importé dans `zcrud_core`. Given un échec → When on lit l'état → Then `failure` avec message exposé en `liveRegion` et bouton réactivé.

7. **AC7 — Détection *dirty* (propre → dirty → propre).** Le `ZFormController` expose `ValueListenable<bool> isDirty` dérivé d'une **empreinte de l'état initial** (baseline capturée à la construction / `markPristine()`). Un `setValue` qui **écarte** un champ de sa baseline ⇒ `isDirty` devient `true` ; revenir à la baseline (ou `reset()`) ⇒ `isDirty` redevient `false`. `markPristine()` (après succès) re-capture la baseline ⇒ `isDirty=false`. Given baseline `{a:1}` → When `setValue('a',2)` (dirty) puis `setValue('a',1)` → Then `isDirty` : false → true → false.

8. **AC8 — `isDirty` ne casse PAS SM-1.** La mise à jour de `isDirty` passe par un `ValueNotifier<bool>` **dédié** : elle **ne notifie jamais** les tranches de champ ni le `notifyListeners()` global, et ne bascule que lorsque le booléen **change** effectivement. Un widget « bannière dirty »/« bouton enregistrer » n'écoute que `isDirty`. Given un champ focalisé → When on tape 100 caractères → Then le champ voisin ne se reconstruit pas, le focus/curseur sont conservés (SM-1), et `isDirty` ne bascule qu'**une** fois (au 1er écart).

9. **AC9 — Confirmation d'abandon si dirty.** Un widget `ZDiscardGuard` (enveloppe **de type `PopScope`**, sans dépendance au routing de l'app) empêche la fermeture tant que `isDirty` est vrai : il délègue à un **seam** app `Future<bool> Function()? onConfirmDiscard` (dialogue fourni par l'app). Non-dirty ⇒ pop autorisé sans question. Dirty + seam ⇒ pop conditionné à `true`. Given `isDirty=true` → When tentative de pop → Then `onConfirmDiscard` appelé ; `false` ⇒ pas de pop, `true` ⇒ pop. Given `isDirty=false` → When pop → Then pop immédiat sans appel du seam.

10. **AC10 — Validateurs inter-champs `match` (report b).** Un `ZValidatorSpec.match(refKey)` est **honoré** : la valeur du champ doit être égale à `controller.valueOf(refKey)`. Implémenté par une **closure mémoïsée capturant le `ZFormController`** (lue à l'invocation), composée avec le validateur champ-local — jamais recompilée dans `build()`. Given `password='x'` et `confirm` avec `match('password')` valant `'y'` → When validation/`submit()` → Then `confirm` invalide (message révélé, AC2) ; égalité ⇒ valide.

11. **AC11 — Validateurs inter-champs `min/max` par `refKey` (report b).** `ZValidatorSpec.minKey(refKey)`/`maxKey(refKey)` sont honorés : la valeur numérique courante est comparée à `num.tryParse(controller.valueOf(refKey))`. Référence absente/non numérique ⇒ contrat documenté (non bloquant : le validateur ne rejette pas sur référence indéterminée). Given `dateFin` avec `minKey('dateDebut')` et une valeur < `dateDebut` → When `submit()` → Then invalide et révélé.

12. **AC12 — Rafraîchissement inter-champs sans casser SM-1.** Un champ portant un validateur inter-champs se **réévalue** (i) systématiquement à la validation agrégée (`submit()`), et (ii) en direct lorsque le champ **référencé** change — via un abonnement **ciblé** à `fieldListenable(refKey)` (une tranche précise), **jamais** au `notifyListeners()` global. Taper dans un champ **tiers** (non référencé) ne reconstruit pas le champ dépendant. Given `confirm match('password')` → When on tape dans un 3ᵉ champ `email` → Then `confirm` ne se reconstruit pas ; When on modifie `password` → Then `confirm` se réévalue.

13. **AC13 — Write-back de valeur externe re-amorce hors focus (report c).** Le `ZFormController` expose `ValueListenable<int> reseedRevision`, incrémenté par `reset()` et par `reseed(Map values)` (rechargement externe). Les widgets à **buffer d'édition interne** (`texte`, `signature`, mini-CRUD sous-liste, `select`/`relation` bufferisés) **re-lisent `valueOf`** dans leur buffer sur incrément de `reseedRevision`, **uniquement hors focus** (jamais pendant un geste/frappe — FR-1). Le contrat de clé documenté en E3-4 (`ValueKey(field.name + reseedRevision)` OU re-seed observé hors focus) est honoré. Given un champ texte affichant `'a'`, **non focalisé** → When `controller.reset()` restaure baseline `'init'` → Then le champ affiche `'init'`. Given le **même** champ **focalisé** en train de saisir → When un `reseed` survient → Then la saisie en cours **n'est pas écrasée** (report différé à la perte de focus).

14. **AC14 — SM-1 global re-prouvé sur la voie de soumission/dirty/reseed.** L'ajout de la soumission, du *dirty* et du reseed **ne réintroduit aucun rebuild global** sur la voie de frappe : le bouton de soumission et la bannière dirty n'écoutent que leurs `ValueListenable` dédiés (état de soumission, `isDirty`) ; taper 100 caractères ne reconstruit que le champ courant (0 build voisin, 0 build chrome de soumission), focus + curseur (fin ET milieu) conservés. `find.byType(Form) findsNothing` sur toute la surface. [SM-1, AD-2]

## Tasks / Subtasks

- [x] **T1 — État & contrôleur de soumission** (AC1, AC3, AC4, AC5, AC6)
  - [x] `presentation/edition/z_submission.dart` : `enum ZSubmissionStatus { idle, inProgress, success, failure }` + type-valeur `ZSubmissionState` (`status`, `failure: ZFailure?`) avec `==`/`hashCode`, fabriques `idle()/inProgress()/success()/failure(ZFailure)`.
  - [x] `ZEditionSubmitController` (`ChangeNotifier` léger OU détenteur d'un `ValueNotifier<ZSubmissionState>`) : `ValueListenable<ZSubmissionState> state` ; `Future<ZSubmissionOutcome> submit()`.
  - [x] `submit()` : (1) validation agrégée (T2) ; si invalide ⇒ `reveal=true` + état `failure`(validation) + return **sans** `onSubmit` ; (2) sinon `inProgress`, snapshot `controller.values`, appel du seam `onSubmit(values)` ; (3) `fold` : `Right` ⇒ `success` (+ `markPristine()`), `Left` ⇒ `failure(ZFailure)`. Exception ⇒ **enveloppée** en `ZFailure` (AD-11, jamais de `catch(_){}` nu).
  - [x] Garde de ré-entrance : `submit()` ignoré si déjà `inProgress`.
  - [x] Seam `onSubmit` typé `Future<Either<ZFailure, T>> Function(Map<String,Object?> values)` porté **hors** `ZFormController` (paramètre) — jamais sérialisé.
- [x] **T2 — Validation agrégée + révélation toutes familles** (AC1, AC2)
  - [x] Fonction d'agrégation : itère les champs **visibles** (plat + toutes les étapes, conditionnels honorés), évalue chaque validateur (champ-local compilé E3-2 **+** inter-champs T4) contre `_stringOf(valueOf)`, renvoie `Map<String,String> errors` (name→message) ⇒ `isValid = errors.isEmpty`.
  - [x] Canal de révélation structurel (`ValueNotifier<bool> reveal` ou epoch) propagé aux champs SANS `Form` global ; familles clavier ⇒ `autovalidateMode: always` (seam existant E3-5) ; **familles non-texte** ⇒ surface d'erreur additive (`InputDecoration.errorText` pour inputs Material ; `Semantics(liveRegion) + Text` pour widgets custom) alimentée par l'erreur agrégée.
  - [x] Étendre `z_field_widget.dart`/familles concernées (`select`/`date`/`booléen`/`slider`/`tags`/`rating`/…) pour rendre le message d'erreur quand `reveal` et invalide.
- [x] **T3 — Détection dirty** (AC7, AC8)
  - [x] `z_form_controller.dart` : baseline (`Map<String,Object?> _baseline`) capturée à la construction depuis `initialValues` ; `ValueNotifier<bool> _isDirty` ; `ValueListenable<bool> get isDirty`.
  - [x] `setValue` met à jour un compte d'écarts vs baseline et ne **toggle** `_isDirty` que sur changement de booléen (jamais `notifyListeners()` global, jamais notification de tranche tierce).
  - [x] `markPristine()` (re-capture baseline ⇒ dirty=false) ; `Map<String,Object?> get values` (snapshot immuable des tranches).
- [x] **T4 — Validateurs inter-champs** (AC10, AC11, AC12)
  - [x] `presentation/edition/z_cross_field_validator.dart` : `compile(List<ZValidatorSpec> specs, ZFormController c) → FormFieldValidator<String>?` produisant des **closures mémoïsées** pour `match`(refKey), `min`(refKey), `max`(refKey) — lues à l'invocation via `c.valueOf(refKey)`.
  - [x] Composer avec `ZValidatorCompiler.compile` (champ-local) dans le widget de champ ; identité stable (mémoïsé `late final`).
  - [x] Abonnement **ciblé** du champ dépendant à `fieldListenable(refKey)` pour re-validation en direct (jamais le global) ; se désabonner au dispose.
  - [x] Retirer le `null` silencieux du chemin déféré (au minimum : les inter-champs sont désormais réellement produits par `z_cross_field_validator`).
- [x] **T5 — Confirmation d'abandon** (AC9)
  - [x] `presentation/edition/z_discard_guard.dart` : widget enveloppe type `PopScope` (`canPop` dérivé de `!isDirty`, `onPopInvoked`/équivalent délègue au seam `onConfirmDiscard`), sans dépendance `go_router`/routing app (AD-13).
  - [x] Seam `Future<bool> Function()? onConfirmDiscard` (paramètre / résolu via `ZcrudScope` si absent) ; `maybeConfirmDiscard()` retourne `true` si non-dirty.
- [x] **T6 — Chrome de soumission accessible** (AC5, AC6, AC14)
  - [x] `presentation/edition/z_submit_button.dart` : bouton écoutant **uniquement** `submitController.state` ; `inProgress` ⇒ désactivé + `CircularProgressIndicator` + `Semantics(enabled:false, hint)`, cible ≥ 48 dp, `EdgeInsetsDirectional` ; surface d'erreur `Semantics(liveRegion)` pour `failure.message`.
  - [x] (Optionnel) slot de soumission intégrable dans `DynamicEdition`/`ZStepperEdition` (bouton « Terminer » de la dernière étape câblé sur `submit()` via `onComplete`).
- [x] **T7 — Write-back valeur externe (reseed hors focus)** (AC13)
  - [x] `z_form_controller.dart` : `ValueNotifier<int> _reseedRevision` ; `ValueListenable<int> get reseedRevision` ; `reset()` (restaure baseline dans les tranches + `reset` dirty + `++reseedRevision`) ; `reseed(Map values)` (écrit + `++reseedRevision`, sans devenir dirty selon contrat).
  - [x] Widgets à buffer interne (`z_text_field_widget`, `z_signature_field_widget`, `z_sub_list_field_widget`, `select`/`relation` bufferisés) : observer `reseedRevision` et re-lire `valueOf` dans le buffer **hors focus** (guard `FocusNode.hasFocus`) ; report du re-seed à la perte de focus si focalisé.
- [x] **T8 — Câblage stepper** (AC1, AC2)
  - [x] `z_stepper_edition.dart` : `onComplete` de la dernière étape route vers `submit()` (validation agrégée **de toutes les étapes**, pas seulement la courante) ; révélation non-texte active sur chaque étape.
- [x] **T9 — Barrels & exports**
  - [x] Exporter `ZSubmissionState`/`ZSubmissionStatus`/`ZEditionSubmitController`/`ZSubmitButton`/`ZDiscardGuard` dans `zcrud_core.dart` (et types-valeur pertinents dans `edition.dart` si pur-données).
- [x] **T10 — Tests** (voir §Testing) : submission, dirty, discard-guard, cross-field, reveal-all-families, reseed-writeback, sm1-submission.

## Dev Notes

### Contexte architectural (NON-NÉGOCIABLE)

- **AD-11 (Erreurs)** : tout contrat renvoie `Either<ZFailure,T>` (`dartz`), `Unit` pour void ; hiérarchie `ZFailure` maison (`DomainFailure`/`ServerFailure`/…). Le seam `onSubmit` **doit** retourner `Either<ZFailure,T>`. Le cœur expose un état `failure(ZFailure)` ; **les providers déplient l'`Either` et re-throw une exception typée pour alimenter `AsyncValue.error`** → ce pont vit dans **`zcrud_riverpod`**, jamais dans `zcrud_core` (AD-15). [Source: architecture.md#AD-11 ; z_failure.dart]
- **AD-2 / SM-1 (objectif produit n°1)** : aucun rebuild global à la frappe. La soumission, le *dirty* et le reseed s'appuient sur des `ValueListenable` **dédiés** (état soumission, `isDirty`, `reseedRevision`) — jamais `notifyListeners()` global sur la voie de frappe, jamais de `Form`/`FormBuilder` global (interdit). Le seul canal global reste `visibleFields` (structurel). [Source: architecture.md#AD-2 ; z_form_controller.dart:60-108]
- **AD-15 (multi-gestionnaire)** : `zcrud_core` n'importe aucun manager. Le pont `AsyncValue.error` et le dialogue d'abandon sont des **seams** (paramètres / `ZcrudScope`), branchés par un binding. [Source: architecture.md#AD-15]
- **AD-3 (codegen)** : les callbacks/Widgets ne sont **jamais** des données de modèle — ils vivent hors du `ZFormController` (paramètres du contrôleur de soumission), donc jamais traversés par `toMap/fromMap`. C'est l'exigence « callbacks/Widgets non sérialisés ».

### État réel du dépôt (E3-1..E3-5 done)

- `ZFormController` (`z_form_controller.dart`) : tranches mémoïsées `_slices`, `setValue` **local** (jamais global), canal structurel `visibleFields` (seul déclencheur `notifyListeners()`), `valueOf`. **À étendre** (non-régressif) : `values` snapshot, `isDirty`+baseline+`markPristine`, `reseedRevision`+`reset`+`reseed`. **À préserver** : `setValue` local, tranche stable, `dispose` complet.
- `ZValidatorCompiler` (`z_validator_compiler.dart`) : compile les validateurs **champ-locaux** ; `min/max` par `refKey` et `match` renvoient **`null`** (déférés — commentaires l.20-26, 78-102). E3-6 les **complète** via `z_cross_field_validator.dart` (closures capturant le controller), composé au champ-local. Ne PAS changer la sémantique champ-local existante (prouvée E3-2).
- `ZValidatorSpec` (`z_validator_spec.dart`) : fabriques `minKey`/`maxKey`/`match(refKey)` déjà présentes (pur-données, `refKey`). Rien à changer côté domaine.
- `ZFieldWidget` (`z_field_widget.dart`) : `TextEditingController` interne alloué 1× en `initState` pour les familles clavier (`familyUsesTextController`), valeur initiale lue via `valueOf` ; hook `onFieldInit`. **À étendre** : observation `reseedRevision` (re-seed hors focus), surface d'erreur révélée pour familles non-texte, composition validateur inter-champs + abonnement ciblé `fieldListenable(refKey)`.
- `DynamicEdition` (`dynamic_edition.dart`) : observe `visibleFields` (`ValueListenableBuilder<List<String>>`), `ListView.builder`, place stable `KeyedSubtree(ValueKey(name))` **non contournable**, `findChildIndexCallback` (préservation focus au décalage d'index), sections repliables, grille, `readOnly`, `onStructuralBuild`. **À préserver intégralement.** Fournit la liste des champs visibles pour l'agrégation.
- `ZStepperEdition` (`z_stepper_edition.dart`) : **un seul** `ZFormController` (jamais un par étape), `find.byType(Form) findsNothing` prouvé, validation **par étape** via `ZValidatorCompiler`, seam `autovalidateMode` (révélation `always` **sans** `Form`), `onComplete` (slot de soumission laissé à E3-6, l.32/149-150). **À étendre** : `onComplete → submit()` agrégé toutes étapes.

### Reports absorbés (rattachement explicite)

- **(a) MEDIUM-1 revue E3-5** — révélation d'erreur absente pour familles NON-clavier. Le gate bloque correctement (sécurité des données OK) mais `select`/`date`/`booléen` **n'affichent aucun message** (impasse UX). E3-6 (AC2/T2) **étend la révélation à toutes les familles** via une surface d'erreur additive alimentée par la validation agrégée — sans `Form` global. [Source: code-review-e3-5.md#MEDIUM-1 l.69-74]
- **(b) Inter-champs déférés E3-2/E3-5** — `minKey`/`maxKey`/`match` produisent aujourd'hui `null` (foot-gun LOW-1 E3-2). E3-6 (AC10-AC12/T4) les **implémente** en closures mémoïsées capturant le controller, réévaluées à la validation/soumission et en direct via abonnement **ciblé** à la tranche référencée (SM-1 préservé). [Source: code-review-e3-2.md#LOW-1 l.58-60 ; z_validator_compiler.dart l.20-26]
- **(c) Write-back externe déféré E3-4** — contrat `ValueKey(name+reseedRevision)` / re-seed **hors focus** documenté mais NON câblé (l'état dérivé E3-4 relit la tranche sans buffer). E3-6 est le **déclencheur réel** (reset/reload) : AC13/T7 câblent le re-amorçage des widgets à buffer interne (texte/signature/mini-CRUD/select) sur incrément de `reseedRevision`, **jamais** pendant un geste (FR-1/SM-1). [Source: e3-4….md §« mécanisme UNIFORME de reflet de valeur EXTERNE » l.115-124, 148, 217 ; code-review-e3-4.md l.78]

### Conception — soumission agrégée + `onSubmit` non-sérialisé + dirty + abandon + états

```
submit():
  errors = aggregateValidate(visibleFields ∪ toutes étapes)   // champ-local (E3-2) + inter-champs (T4)
  if errors.isNotEmpty:
      reveal = true                    // révèle TOUTES familles (AC2), sans Form global
      state = failure(validation)      // onSubmit NON appelé (AC1)
      return validationFailure
  if state == inProgress: return       // garde ré-entrance (AC5)
  state = inProgress                   // bouton désactivé + spinner + Semantics (AC5)
  values = controller.values           // snapshot Map<String,Object?> PUR (jamais Widget/callback) (AC3)
  either = await onSubmit(values)      // seam app, Future<Either<ZFailure,T>> (AD-11)
  either.fold(
    (f) => state = failure(f),         // message liveRegion, bouton réactivé (AC6)
    (_) => { markPristine(); state = success } // dirty=false
  )
  // exception jetée par onSubmit ⇒ enveloppée en ZFailure (AD-11), jamais catch(_){} nu
```

- **`onSubmit` / `onConfirmDiscard` = seams hors modèle.** Portés par le contrôleur de soumission / le widget, **jamais** dans une tranche du `ZFormController` ⇒ jamais atteints par le codegen (AC3, AD-3). Les valeurs transmises sont un **snapshot de données** (`Map<String,Object?>`).
- **Pont `AsyncValue.error` (AD-11)** : `zcrud_core` s'arrête à `ZSubmissionState.failure(ZFailure)`. Un provider de `zcrud_riverpod` déplie et **re-throw** l'exception typée pour alimenter `AsyncValue.error`. À **documenter** dans le dartdoc de `ZEditionSubmitController` ; **ne pas** importer Riverpod dans le cœur.
- **Dirty** : empreinte baseline vs courant, `ValueNotifier<bool>` dédié, toggle uniquement au flip ⇒ SM-1 intact (AC8). `markPristine()` après succès, `reset()` restaure baseline + `reseedRevision++`.
- **Abandon** : `ZDiscardGuard` = enveloppe `PopScope`-like (aucune dép routing), `canPop = !isDirty`, sinon délègue au seam.
- **États UI** : `idle`/`inProgress`/`success`/`failure(ZFailure)` — un `ValueListenable` que le bouton/la surface d'erreur écoutent seuls (AC14).

### Frontière E3-6 / E5 / E7 (à respecter STRICTEMENT)

- **E3-6 = le hook + les états.** On livre : validation agrégée, seam `onSubmit`, détection *dirty*, confirmation d'abandon, états `submit-in-progress`/`failure`, inter-champs, reseed hors focus. On teste avec un `onSubmit` **factice** (echo/`Right`/`Left`) — **aucun** repository réel.
- **E5** : la **soumission réelle** create/update contre un backend (`FirebaseZRepositoryImpl<T>`, `ZLocalStore`) — l'app branchera son `onSubmit` dessus. Hors périmètre ici.
- **E7** : **intégration DODLP** (chargement async d'un enregistrement → `reseed`, câblage `onSubmit` sur le repo, dialogue d'abandon réel). C'est le consommateur du contrat posé ici. Hors périmètre.

### Project Structure Notes

- **NEW** : `z_submission.dart`, `z_cross_field_validator.dart`, `z_discard_guard.dart`, `z_submit_button.dart` (sous `packages/zcrud_core/lib/src/presentation/edition/`).
- **UPDATE** : `z_form_controller.dart` (dirty/baseline/values/reseed), `z_field_widget.dart` + familles à buffer/non-texte, `dynamic_edition.dart` (agrégation + reveal), `z_stepper_edition.dart` (onComplete→submit), `zcrud_core.dart`/`edition.dart` (exports).
- Conventions : préfixe `Z`, snake_case fichiers, barrel `lib/zcrud_core.dart`, `EdgeInsetsDirectional`/`TextAlign.start`, cibles ≥ 48 dp, `Semantics` explicites (AD-13). Aucun style codé en dur (thème via `ZcrudScope`/`Theme.of`, FR-26).

### Testing

- **Framework** : `flutter_test` (widget + unit), au sein de `packages/zcrud_core/test/presentation/edition/`. Rejouer la **vérif verte** : `melos run generate` → `dart analyze` RC=0 → `flutter test` RC=0 (+ non-régression suite core E3-1..E3-5).
- **Fichiers de test attendus** :
  - `submission_test.dart` — AC1 (bloque+non-appel), AC3 (snapshot valeurs, aucun callback), AC4 (`Left`/`Right`/exception enveloppée), AC5 (`inProgress`+garde ré-entrance), AC6 (`failure` message).
  - `reveal_all_families_test.dart` — AC2 : `required` sur `select`/`date`/`booléen` ⇒ message visible + `Semantics`, `find.byType(Form) findsNothing`.
  - `dirty_test.dart` — AC7 (false→true→false, `markPristine`, `reset`), AC8 (toggle unique + SM-1 voisin).
  - `discard_guard_test.dart` — AC9 (dirty ⇒ seam ; `false` pas de pop, `true` pop ; non-dirty ⇒ pop direct).
  - `cross_field_validator_test.dart` — AC10 (`match`), AC11 (`minKey`/`maxKey`), AC12 (réévaluation sur champ référencé, pas de rebuild sur champ tiers).
  - `reseed_writeback_test.dart` — AC13 : `reset`/`reseed` re-amorce hors focus ; saisie focalisée non écrasée.
  - `sm1_submission_test.dart` — AC14 : 100 frappes ⇒ 0 build voisin / 0 build chrome soumission / 0 build bouton, focus+curseur (fin & milieu) conservés, `find.byType(Form) findsNothing`.
- **Gates** : lint anti-`reflectable`, scan secrets, graph AD-1 (`CORE OUT=0`), rétro-compat sérialisation — verts avant tout `done`.

### References

- [Source: epics.md#E3 — Story E3-6] validation → hook `onSubmit` ; callbacks/Widgets non sérialisés ; empreinte dirty + confirmation d'abandon ; états `submit-in-progress`/échec via `AsyncValue.error` (AD-11).
- [Source: architecture.md#AD-11] `Either<ZFailure,T>`, hiérarchie `ZFailure`, providers re-throw pour `AsyncValue.error`.
- [Source: architecture.md#AD-2] rebuilds granulaires, interdits (`setState` global, `FormBuilder` global), obligatoires (`ValueKey`, validateurs mémoïsés).
- [Source: architecture.md#AD-15 / AD-6] seams + bindings ; aucun manager dans le cœur.
- [Source: code-review-e3-5.md#MEDIUM-1] report (a).
- [Source: code-review-e3-2.md#LOW-1 ; z_validator_compiler.dart#FRONTIÈRE] report (b).
- [Source: e3-4-sections-conditionnels-lecture-grille.md#« mécanisme UNIFORME de reflet de valeur EXTERNE »] report (c).
- [Source: z_form_controller.dart] tranches/`setValue` local/`visibleFields` (base à étendre).
- [Source: CLAUDE.md] Critical Patterns (AD-2), Key Don'ts.

### Ambiguïtés détectées (à trancher en dev-story, décisions consignées)

1. **Emplacement du contrôleur de soumission** : `ZEditionSubmitController` séparé (recommandé — sépare responsabilités, testable isolément) vs méthodes sur `ZFormController`. Le *dirty*/`reseed`/`values` vivent sur `ZFormController` (état) ; la soumission (validation agrégée + seam + états) sur un contrôleur dédié. Décision par défaut : **contrôleur dédié** consommant le `ZFormController`.
2. **Réévaluation inter-champs en direct (AC12)** : abonnement ciblé à `fieldListenable(refKey)` recommandé (SM-1-safe car tranche précise) ; alternative minimale = réévaluation **uniquement** à `submit()`. Défaut : abonnement ciblé + fallback garanti à la soumission.
3. **`reseed` et dirty (AC13)** : un rechargement externe (`reseed`) redéfinit-il la baseline (⇒ non-dirty) ou marque-t-il dirty ? Défaut : `reseed(values)` = nouvelle donnée autoritaire ⇒ **re-baseline** (non-dirty) ; `reset()` = retour baseline courante (non-dirty). À confirmer avec E7.
4. **Reveal non-texte : `InputDecoration.errorText` vs surface `Semantics(liveRegion)`** selon la famille (inputs Material vs widgets custom `slider`/`signature`). Défaut : `errorText` quand un `InputDecoration` existe, sinon `Text`+`Semantics(liveRegion)`. Uniformité du message via l'erreur agrégée.
5. **`min/max` par `refKey` sur type non numérique/date** (AC11) : comparaison via `num.tryParse` ; pour les dates ISO, comparaison lexicographique/`DateTime.tryParse` documentée. Référence indéterminée ⇒ non-bloquant (ne rejette pas). À affiner selon les besoins réels (E7/E8).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story BMAD, effort high).

### Debug Log References

- `dart analyze` (zcrud_core) : RC=0, `No issues found!`
- `flutter test` (zcrud_core) : RC=0, **387** tests (362 baseline + 25 nouveaux).
- `melos run analyze` : RC=0 (14 packages).
- `melos run test` : RC=0 — annotations 8, generator 80, provider 8, get 17, riverpod 8, core 387 (508 au total).
- `melos run verify` : RC=0 (graph AD-1, gate melos, reflectable, secrets, codegen, compat, serialization).
- `graph_proof.py` : `CORE OUT=0 OK`, `ACYCLIQUE OK`, 14 nœuds.
- `git ls-files '*.g.dart'` : 0 (aucun code généré committé).

#### Remédiation revue E3-6 (MEDIUM-1 + LOW-1) — statut reste `review`

- **MEDIUM-1 (comparaison inter-champs limitée à `num`)** — CORRIGÉ dans
  `z_cross_field_validator.dart`. `_compileOne` (min/max) délègue désormais à un
  comparateur **typé et robuste** `_compare(selfRaw, refRaw)` :
  (1) deux valeurs numériques (`num`/`num.tryParse`) ⇒ comparaison numérique ;
  (2) sinon deux `DateTime` (déjà typés ou chaîne ISO-8601 via `DateTime.tryParse`)
  ⇒ comparaison de dates ; (3) sinon (types non comparables / référence
  indéterminée) ⇒ `null` **non bloquant**, SANS `throw`. L'exemple normatif AC11
  `dateFin.minKey('dateDebut')` détecte maintenant une plage inversée. `match`
  (égalité textuelle) inchangé. Dartdoc de tête + `_compare` documentent la règle
  et la priorité numérique. Helpers `_asNum`/`_asDate` pur-Dart (AD-2/AD-15 :
  aucun import manager).
- **LOW-1 (agrégation stepper toutes-étapes non testée)** — COMBLÉ par
  `test/presentation/edition/stepper_submit_aggregation_test.dart` (2 tests) :
  un `ZStepperEdition` réel monté à l'étape 0 (seul `visibleFields=[s0_name]`),
  un `required` invalide dans l'étape 2 (non courante) ⇒ `submit()` bloque,
  `onSubmit` NON appelé, `s2_final` figure dans l'agrégat `ZValidationFailure`
  (et `s0_name` rempli n'y figure pas) ; second test : toutes étapes valides ⇒
  `onSubmit` appelé une fois. Prouve que l'agrégation itère le catalogue complet,
  pas la seule étape courante.
- **LOW-2 / LOW-3** — NON traités (hors périmètre remédiation, consignés) :
  LOW-2 (asymétrie re-seed `signature` vs `_reseedable`) = cas-limite bénin
  (re-seed à valeur identique = no-op) ; LOW-3 (`values` sérialise les champs
  masqués) = choix E3-6 assumé, à trancher côté projection data en **E7**.
- Tests inter-champs ajoutés : `cross_field_validator_test.dart` +5
  (minKey dates plage inversée→erreur / correcte→null ; maxKey dates ;
  `DateTime` déjà typé ; num priorité numérique ; types non comparables non
  bloquant).
- **Vérif verte re-rejouée** : `dart analyze` (cœur) RC=0 ; `flutter test`
  (cœur) RC=0 = **394** tests (387 + 7 : 5 dates + 2 stepper) ; `melos run
  analyze` RC=0 ; `melos run verify` RC=0 (`CORE OUT=0 OK`, `ACYCLIQUE OK`,
  17 arêtes ; gate reflectable/secrets OK ; slot `serialization-compat` no-op
  documenté E2-10) ; `melos list` = 14 ; `git ls-files '*.g.dart'` = 0 ;
  cœur = **0** `AsyncValue`/import manager (dartdoc seulement).

### Completion Notes List

- **T1 — Soumission (`z_submission.dart`)** : `ZSubmissionStatus`/`ZSubmissionState` (type-valeur, `==`/`hashCode`, fabriques), `ZValidationFailure extends ZFailure` (distingue l'échec de validation de l'applicatif — AC1), `ZSubmissionOutcome<T>`, seam `ZOnSubmit<T> = Future<Either<ZFailure,T>> Function(Map)`, `ZEditionSubmitController<T>` détenant `ValueListenable<ZSubmissionState> state`. `submit()` : validation agrégée → si invalide `revealErrors()`+`failure(validation)` (onSubmit NON appelé) ; sinon `inProgress`, snapshot `controller.values` (données pures), `await onSubmit`, `fold(Left→failure, Right→markPristine+success)` ; exception **enveloppée** en `ServerFailure` (jamais `catch(_){}` nu) ; garde de ré-entrance si `inProgress`.
- **AsyncValue.error (AD-11/AD-15)** : le cœur s'arrête à `ZSubmissionState.failure(ZFailure)` — **aucun** `AsyncValue`, aucun import Riverpod. Le pont (déplier + re-throw typé) est **documenté** dans le dartdoc de `ZEditionSubmitController` et vit dans `zcrud_riverpod`. Prouvé : `graph_proof CORE OUT=0`.
- **T2 — Révélation toutes familles (report a)** : canal `ValueListenable<int> reveal` sur `ZFormController` (`revealErrors()` incrémente ; `reset()` remet à 0). `ZFieldWidget` observe `reveal` : familles clavier ⇒ `autovalidateMode: always` ; familles **non-texte** ⇒ surface d'erreur additive `Semantics(liveRegion)+Text` alimentée par le validateur combiné mémoïsé — **sans** `Form` global (`find.byType(Form) findsNothing`).
- **T3 — Dirty** : baseline capturée à la construction/`markPristine`/`reseed` ; `Set<String> _dirtyFields` ; `ValueNotifier<bool> _isDirty` **dédié** (toggle au flip uniquement, jamais de `notifyListeners()` global) ; `values` snapshot immuable ; `markPristine()`.
- **T4 — Inter-champs (report b, `z_cross_field_validator.dart`)** : closures mémoïsées capturant le controller pour `match`/`minKey`/`maxKey` (lues via `valueOf(refKey)` à l'invocation) ; `compileField` compose champ-local (E3-2) + inter-champs ; `refKeysOf` alimente l'abonnement **ciblé** de `ZFieldWidget` à `fieldListenable(refKey)` (re-validation en direct sans rebuild d'un champ tiers — AC12) ; référence indéterminée/non numérique ⇒ non bloquant (AC11).
- **T5 — Abandon (`z_discard_guard.dart`)** : enveloppe `PopScope`-like (aucune dép routing), `canPop = !isDirty`, seam `ZConfirmDiscard` ; n'observe que `controller.isDirty`.
- **T6 — Chrome (`z_submit_button.dart`)** : bouton scellé sur `controller.state` uniquement ; `inProgress` ⇒ désactivé + `CircularProgressIndicator` + `Semantics(enabled:false)` ; `failure.message` en `Semantics(liveRegion)` ; cible ≥ 48 dp, `EdgeInsetsDirectional`, thème (aucun style codé en dur).
- **T7 — Reseed (report c)** : `reset()` (restaure baseline) / `reseed(values)` (re-baseline autoritaire, ambiguïté #3 → non-dirty) incrémentent `reseedRevision`. Texte/nombre : re-seed hors focus via la sync de tranche existante **+ report différé à la perte de focus** (`FocusNode` listener) — saisie en cours JAMAIS écrasée (FR-1). Mini-CRUD (`subItems`/`dynamicItem`) et `signature` : re-clé sur `reseedRevision` (re-lecture `valueOf`). `select` bufferisé : re-clé natif sur la valeur courante de tranche (déjà E3-3a).
- **T8 — Stepper** : aucune modification de `z_stepper_edition.dart` nécessaire. L'agrégation toutes-étapes est portée par `ZEditionSubmitController` (itère les champs **par condition**, pas seulement `visibleFields` — qui, pour un stepper, ne reflète que l'étape courante), câblé par l'app via le slot `onComplete` existant. La révélation non-texte par étape passe par le seam `autovalidateMode: always` déjà propagé par le stepper à `ZFieldWidget` (report a couvert aussi côté stepper). Non-régression : suite stepper E3-5 verte.
- **T9 — Barrels** : `z_submission`, `z_submit_button`, `z_discard_guard`, `z_cross_field_validator` exportés dans `zcrud_core.dart`.
- **T10 — Tests** : 7 fichiers, 25 tests (voir File List).
- **Décisions d'ambiguïtés** : #1 contrôleur de soumission **dédié** (état sur `ZFormController`, soumission sur `ZEditionSubmitController`) ; #2 abonnement **ciblé** `fieldListenable(refKey)` + fallback garanti à `submit()` ; #3 `reseed` **re-baseline** (non-dirty), `reset` retour baseline ; #4 `Semantics(liveRegion)+Text` pour non-texte custom (surface uniforme via validateur agrégé) ; #5 `min/max` refKey via `num.tryParse`, référence indéterminée non bloquante.
- **Frontière E5/E7 respectée** : `onSubmit` **factice** dans les tests (echo/`Right`/`Left`/exception), aucun repository réel.

### File List

**NEW (lib)**
- `packages/zcrud_core/lib/src/presentation/edition/z_submission.dart`
- `packages/zcrud_core/lib/src/presentation/edition/z_cross_field_validator.dart`
- `packages/zcrud_core/lib/src/presentation/edition/z_discard_guard.dart`
- `packages/zcrud_core/lib/src/presentation/edition/z_submit_button.dart`

**UPDATE (lib)**
- `packages/zcrud_core/lib/src/presentation/z_form_controller.dart` (baseline/dirty/values/markPristine/reset/reseed/reseedRevision/reveal)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (validateur combiné toutes familles, abonnement ciblé refKey, révélation non-texte, re-seed hors focus/différé)
- `packages/zcrud_core/lib/zcrud_core.dart` (exports)

**NEW (test)**
- `packages/zcrud_core/test/presentation/edition/submission_test.dart` (AC1, AC3, AC4, AC5, AC6 — 6)
- `packages/zcrud_core/test/presentation/edition/reveal_all_families_test.dart` (AC2 — 1)
- `packages/zcrud_core/test/presentation/edition/dirty_test.dart` (AC7, AC8 — 7)
- `packages/zcrud_core/test/presentation/edition/discard_guard_test.dart` (AC9 — 2)
- `packages/zcrud_core/test/presentation/edition/cross_field_validator_test.dart` (AC10, AC11, AC12 — 5)
- `packages/zcrud_core/test/presentation/edition/reseed_writeback_test.dart` (AC13 — 3)
- `packages/zcrud_core/test/presentation/edition/sm1_submission_test.dart` (AC14 — 1)
