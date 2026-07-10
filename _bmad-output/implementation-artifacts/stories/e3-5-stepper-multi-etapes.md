---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---

# Story 3.5 : Stepper multi-étapes (même `ZFormController`)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

Story ID : E3-5 · Epic : E3 (Moteur DynamicEdition à rebuilds granulaires) · Phase : MVP
Couvre : **FR-2, FR-4** · AD-2, AD-13, AD-15 · SM-1 · Dépend de : E3-1, E3-2, E3-3a, E3-3b, E3-4 — précède E3-6 (soumission/dirty).

## Story

En tant que **développeur consommateur de zcrud** (DODLP puis lex_douane),
je veux **présenter un formulaire long comme un assistant (wizard) en plusieurs étapes qui partitionnent le MÊME `ZFormController`, avec validation à la transition de chaque étape et préservation intégrale des valeurs en va-et-vient entre étapes**,
afin de **reproduire les formulaires historiques à étapes SANS jamais réintroduire un `Form`/`FormBuilder` global, ni le rebuild global, ni la perte de focus (objectif produit n°1)**.

## Contexte (pourquoi cette story, et ce qu'elle N'est PAS)

- **`EditionFieldType.stepper` n'est PAS un champ-feuille.** Le dispatcher (E3-3a) classe volontairement `stepper` en `EditionFamily.unsupported` (repli contrôlé) car c'est un **REGROUPEMENT / structure de navigation**, explicitement renvoyé à E3-5 (`edition_field_family.dart` lignes 17, 99, 194-201 ; `edition_field_type.dart` ligne 145 « Regroupement multi-étapes »). E3-5 le traite donc comme une **structure d'orchestration** posée AUTOUR du dispatcher existant, jamais comme un `ZFieldWidget`. Aucun nouveau widget de famille n'est ajouté.
- **AD-2 (objectif produit n°1)** impose la contrainte cardinale : *« Stepper : les étapes regroupent des champs du MÊME `ZFormController` (sectionnement) — pas de `FormBuilder` global comme source d'état ; `form_builder_validators` sert la composition de validateurs, jamais l'état (résout OQ-4, évite tout rebuild global). »* [architecture.md#AD-2, ligne 65]
- **Distinct des sections repliables (E3-4).** Les sections d'E3-4 coexistent sur **une seule page** (accordéon) ; le stepper **séquence** des étapes (une étape montée à la fois). Les deux se **composent** : une étape peut elle-même contenir des sections E3-4 et des champs conditionnels.

## Acceptance Criteria

Les ACs sont **testables** (widget / a11y / RTL / SM-1). Chaque AC cite sa source.

### A. Sectionnement du MÊME `ZFormController` — AUCUN `Form`/`FormBuilder` global (AD-2)

1. **AC1 — Un seul controller partagé, partitionné en étapes.** Le stepper (`ZStepperEdition`) reçoit **un** `ZFormController` et une liste ordonnée d'**étapes** (`ZEditionStep`), chacune décrivant un **sous-ensemble de noms de champs** du **même** catalogue `List<ZFieldSpec>`. Toutes les étapes lisent/écrivent le **même** controller (mêmes tranches) : il n'existe **jamais** de `ZFormController` par étape, ni de re-création de controller au changement d'étape. Testable : un `setValue` sur une tranche est visible depuis n'importe quelle étape qui monte ce champ. [Source: architecture.md#AD-2 ligne 65 ; z_form_controller.dart lignes 32-54]
2. **AC2 — Zéro `Form`/`FormBuilder` ancêtre, sur toutes les étapes.** À chaque étape et à chaque transition, `find.byType(Form)` **findsNothing** (parité stricte avec la garde E3-2 `field_validation_test.dart` lignes 35-38). La validation reste **par champ** (le `TextFormField` autonome d'E3-3a/`ZEditionField`), jamais agrégée par un `Form`/`FormBuilderState` global (interdit AD-2). [Source: z_edition_field.dart lignes 26-29, 148-160 ; z_validator_compiler.dart lignes 10-14]

### B. Validation PAR ÉTAPE via `form_builder_validators` mémoïsés (E3-2)

3. **AC3 — La transition « suivant » ne valide QUE les champs de l'étape courante.** À l'action « suivant », le stepper valide **exclusivement** les champs (visibles) de l'**étape courante** — jamais ceux des autres étapes — en réutilisant les validateurs **compilés/mémoïsés** d'E3-2 (`ZValidatorCompiler.compile(field.validators)`) évalués contre la valeur courante de la tranche (`controller.valueOf(name)`). Testable : un champ `required` **d'une étape ultérieure** laissé vide **ne bloque PAS** la transition depuis l'étape courante. [Source: z_validator_compiler.dart lignes 50-59 ; z_edition_field.dart lignes 101-111 ; epics E3-5]
4. **AC4 — Étape invalide ⇒ navigation BLOQUÉE + erreurs révélées.** Si au moins un champ de l'étape courante échoue à sa validation, « suivant » est **refusé** (l'index d'étape reste inchangé) et **chaque** champ invalide de l'étape **affiche son message d'erreur** (révélation forcée, même sans interaction préalable de l'utilisateur sur ce champ). Testable : étape 1 avec un `required` vide → tap « suivant » → toujours étape 1, message `errorText` visible sous le champ. [Source: epics E3-5 « bloquer/autoriser la navigation » ; z_edition_field.dart ligne 152 `AutovalidateMode.onUserInteraction`]
5. **AC5 — Étape valide ⇒ navigation AUTORISÉE.** Si tous les champs (visibles) de l'étape courante passent, « suivant » **avance** à l'étape suivante ; à la dernière étape, « suivant » n'existe pas / est désactivé (la **soumission finale** relève d'E3-6). Testable : étape valide → tap « suivant » → l'étape suivante est montée. [Source: epics E3-5 ; frontière E3-6]
6. **AC6 — « Précédent » est inconditionnel (jamais de gate de validation en arrière).** Revenir à une étape antérieure ne déclenche **aucune** validation ni blocage : la navigation arrière est toujours permise (on ne piège pas l'utilisateur dans une étape). Testable : depuis une étape courante invalide, « précédent » ramène à l'étape antérieure sans erreur. [Source: FR-2 ergonomie ; UX assistant standard]

### C. État PRÉSERVÉ entre étapes (garanti par le controller unique)

7. **AC7 — Va-et-vient conserve les valeurs saisies.** Saisir des valeurs à l'étape 1, avancer à l'étape 2 (les champs de l'étape 1 sont **démontés**), puis revenir à l'étape 1 : **toutes** les valeurs précédemment saisies sont **restaurées**. C'est le controller **unique** qui le garantit : ses tranches (`_slices`) ne sont **jamais détruites** au changement d'étape (elles ne le sont qu'à `dispose` du controller — possédé par l'hôte, hors du cycle d'étape). Testable : round-trip étape 1 → 2 → 1, valeur inchangée. [Source: z_form_controller.dart lignes 56-118 ; architecture.md#AD-2]
8. **AC8 — Buffer texte + curseur restaurés au remontage.** Un champ **texte** démonté au changement d'étape puis remonté au retour restaure son texte depuis `controller.valueOf(name)` (via `ZEditionField.initState` lignes 106-113) — aucune valeur perdue, aucune ré-injection écrasant une saisie en cours (la sync reste guardée hors focus, FR-1). Testable : texte saisi étape 1 → aller-retour → `TextField` réaffiche la valeur. [Source: z_edition_field.dart lignes 91-146]
9. **AC9 — Validité de tranche non altérée par le démontage.** Le démontage des champs d'une étape ne modifie **pas** l'ensemble structurel `controller.visibleFields` de façon destructive pour les autres étapes (le stepper pilote la fenêtre montée sans supprimer les tranches). Un champ conditionnel masqué dans une étape conserve sa tranche (compat E3-4/AC5). [Source: z_form_controller.dart lignes 92-108 ; dynamic_edition.dart lignes 250-262]

### D. SM-1 re-vérifié DANS le stepper (objectif produit n°1)

10. **AC10 — Taper dans un champ d'étape ne reconstruit QUE ce champ.** Sur une étape de référence (≥ 10 champs), taper 100 caractères ne reconstruit **ni** le chrome du stepper (indicateur d'étape, boutons Précédent/Suivant), **ni** un champ voisin : le compteur `onStructuralBuild` du stepper **reste inchangé** pendant la saisie, et **zéro perte de focus / saut de curseur** (y compris curseur au milieu). [Source: prd.md SM-1 ligne 378 ; dynamic_edition.dart lignes 304-315 (pattern canal structurel) ; sm1_e3_4_composite_test.dart]
11. **AC11 — Le chrome du stepper n'observe QUE des canaux structurels.** Le `build` du stepper (barre d'étapes + navigation + zone d'étape montée) n'écoute **que** l'index d'étape courant (`ValueNotifier<int>`/`Listenable` local) et `controller.visibleFields` — **jamais** une tranche de valeur (`fieldListenable`). Une frappe (qui ne touche aucun canal structurel) ne ré-exécute donc **pas** le chrome. Aucun `setState` de niveau formulaire dans la voie de frappe. [Source: architecture.md#AD-2 lignes 62-65 ; z_form_controller.dart lignes 82-90]

### E. Navigation accessible & directionnelle (AD-13)

12. **AC12 — Contrôles de navigation accessibles.** Les boutons Précédent/Suivant et l'indicateur d'étape exposent des `Semantics` explicites (label ; `enabled`/état), des **cibles tactiles ≥ 48 dp**, des insets **directionnels** (`EdgeInsetsDirectional`) et `TextAlign.start`/`AlignmentDirectional`. Sous `Directionality.rtl`, l'ordre visuel Précédent/Suivant suit le sens de lecture (bascule LTR↔RTL sans overflow/exception). Les gardes `style_purity_test` / `field_rtl_test` restent **vertes sans relâchement**. [Source: architecture.md#AD-13 ; CLAUDE.md Key Don'ts directionnels ; code-review-e3-3a.md §2.3]

### F. Composition avec E3-4 (sections, conditionnels) — orthogonalité

13. **AC13 — Une étape compose avec les champs conditionnels et sections d'E3-4.** À l'intérieur d'une étape, `displayCondition` (place stable, sélecteur de visibilité abonné aux seuls champs de garde) et les sections repliables continuent de fonctionner ; le partitionnement en étapes est une couche **plus grossière et orthogonale** : la validation « par étape » (AC3) ne porte que sur les champs **visibles** de l'étape (un champ masqué par condition n'est pas validé). Testable : un champ conditionnel masqué dans l'étape courante n'empêche pas la transition ; rendu visible et invalide, il la bloque. [Source: dynamic_edition.dart lignes 16-34, 250-262 ; e3-4 AC2/AC3]

### G. Invariants transverses (repris des ACs E3)

14. **AC14 — Aucun gestionnaire d'état, cœur pur, vert.** Aucun import de `flutter_riverpod`/`get`/`provider` ni de `flutter_form_builder` (seul `form_builder_validators` — validateurs PURS — est autorisé, E3-2) ; réactivité 100 % `Listenable`/`ValueListenable` ; `domain/` reste pur-Dart ; graphe `CORE OUT=0` inchangé ; **zéro `.g.dart`** committé ; vérif verte (`melos run analyze` RC=0, `flutter test` RC=0, `melos run verify` RC=0). [Source: architecture.md#AD-15, AD-1 ; CLAUDE.md ; z_validator_compiler.dart lignes 10-14]

## Tasks / Subtasks

- [x] **T1 — Modèle d'étape `ZEditionStep` (présentation, additif)** (AC1)
  - [x] Créer `ZEditionStep { String title; List<String> fields; ... }` (immuable `const`, préfixe `Z`) — un descripteur **présentation** partitionnant le catalogue par **noms de champs** (aligné sur `ZEditionSection` d'E3-4 : titre + noms, PAS de nouvelle donnée de formulaire). Ne PAS toucher au générateur/annotations (domaine préservé, additif only).
  - [x] Décider l'emplacement : nouveau `presentation/edition/z_stepper_edition.dart` (héberge `ZEditionStep` + `ZStepperEdition`), OU factoriser dans `dynamic_edition.dart`. Recommandé : fichier dédié (le stepper est une surface d'orchestration distincte de `DynamicEdition`).
- [x] **T2 — `ZStepperEdition` : orchestrateur multi-étapes sur le controller unique** (AC1, AC2, AC7, AC9, AC11)
  - [x] `ZStepperEdition` = `StatefulWidget` recevant `controller`, `fields`, `steps`, options de rendu (padding/physics), hook `@visibleForTesting onStructuralBuild`.
  - [x] État local : `ValueNotifier<int> _currentStep` (canal STRUCTUREL local — **jamais** une tranche de valeur). Le `build` du chrome observe un `Listenable.merge([_currentStep, controller.visibleFields])` (pattern `_structural` de `dynamic_edition.dart` lignes 178-190) — **aucune** écoute de `fieldListenable` (garantit AC10/AC11).
  - [x] Zone d'étape : monter UNIQUEMENT les champs (visibles) de l'étape courante en **réutilisant le rendu existant** — soit `DynamicEdition` avec le sous-ensemble de `fields`/`sections` de l'étape, soit directement `ZFieldWidget`/`ZEditionField` par champ. Réutiliser `DynamicEdition` est préférable (hérite gratuitement conditionnels/sections/grille/lecture E3-1..E3-4 et la place stable `ValueKey(name)`).
  - [x] Fenêtrage de `visibleFields` : voir « Décision d'intégration — canal `visibleFields` & fenêtre d'étape » ci-dessous. NE JAMAIS détruire de tranche au changement d'étape (le controller les conserve — AC7/AC9).
- [x] **T3 — Validation PAR ÉTAPE (gate de navigation)** (AC3, AC4, AC5, AC6)
  - [x] `bool _validateStep(int index)` : pour chaque champ **visible** de l'étape `index`, compiler (mémoïsé) `ZValidatorCompiler.compile(spec.validators)` et l'évaluer contre `_stringOf(controller.valueOf(name))` (réutiliser la représentation textuelle d'`z_edition_field.dart` ligne 123). Retourne `true` ssi tous passent. **Pur, sans `Form`, sans pump** (déterministe, testable unitairement).
  - [x] Gate « suivant » : `if (_validateStep(current)) _goTo(current + 1); else _revealErrors(current);` — index inchangé si invalide (AC4).
  - [x] Gate « précédent » : inconditionnel (AC6).
  - [x] **Révélation des erreurs** (AC4) : voir « Décision — révélation forcée des erreurs d'étape ». Recommandé : canal `ValueNotifier<int> _validateEpoch` (ou set de champs à forcer) transmis aux champs de l'étape ; à son incrément, chaque champ concerné bascule sa validation en mode affichage (equivalent `AutovalidateMode.always` pour ce champ). Alternative : `GlobalKey<FormFieldState<String>>` par champ d'étape et `.validate()` (fonctionne SANS `Form` ancêtre) — révèle l'erreur ET renvoie la validité en un appel.
- [x] **T4 — Navigation accessible & directionnelle** (AC12)
  - [x] Barre de navigation : boutons Précédent/Suivant `Semantics(label, enabled)`, cible ≥ 48 dp (`ConstrainedBox(minHeight: 48)` ou boutons Material conformes), insets `EdgeInsetsDirectional`, alignement `AlignmentDirectional`, `TextAlign.start`. Aucune couleur codée en dur (thème via `Theme.of`/`ZcrudTheme` — FR-26).
  - [x] Indicateur d'étape (ex. « Étape k/N » + titre) : `Semantics` explicite ; RTL : ordre visuel suivant le sens de lecture.
- [x] **T5 — Composition E3-4 dans une étape** (AC13)
  - [x] Vérifier que le sélecteur de visibilité conditionnelle (E3-4, abonné aux champs de garde) reste actif dans l'étape montée ; que `_validateStep` ne valide QUE les champs **visibles** (filtrer par `controller.visibleFields` ∩ champs de l'étape).
  - [x] Vérifier qu'une section repliable peut vivre dans une étape (réutilisation `DynamicEdition.sections` restreint aux champs de l'étape).
- [x] **T6 — Preuve SM-1 dans le stepper & non-régression** (AC10, AC11, AC14)
  - [x] Fixture stepper (≥ 3 étapes, une étape ≥ 10 champs, ≥ 1 conditionnel, ≥ 1 `required`) : 100 frappes ⇒ `onStructuralBuild` non incrémenté ; focus + curseur (médian) préservés.
  - [x] Rejouer les gardes `style_purity_test` / `field_rtl_test` / `presentation_purity_test` / `domain_purity_test` / graphe `CORE OUT=0` / scan `.g.dart` = 0.
- [x] **T7 — Barrel & docs** : exporter `z_stepper_edition.dart` (types `Z`) via `lib/zcrud_core.dart` ; dartdoc FR posant les invariants AD-2/AD-13 (un seul controller, pas de `Form` global, validation par étape, canal structurel) en tête du fichier.

## Dev Notes

### Architecture — invariants applicables (NON-NÉGOCIABLES)

- **AD-2 (objectif produit n°1)** — [architecture.md lignes 62-65] : *« Stepper : les étapes regroupent des champs du MÊME `ZFormController` (sectionnement) — pas de `FormBuilder` global comme source d'état ; `form_builder_validators` sert la composition de validateurs, jamais l'état. »* Interdits repris : `setState` de formulaire, construction des champs dans une closure locale de `build()`, recréation de `TextEditingController`, ré-injection de valeur. Le chrome du stepper n'observe QUE des canaux structurels.
- **AD-13** — [architecture.md lignes 117-121] : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`/`PositionedDirectional` ; `Semantics` explicites ; cibles ≥ 48 dp. **La barre de navigation et l'indicateur d'étape sont des surfaces UI ⇒ intégralement directionnels et accessibles.**
- **AD-15 / AD-1** — cœur sans gestionnaire d'état ; **jamais `flutter_form_builder`** (son `FormBuilder`/`FormBuilderState` = état global interdit) — seul `form_builder_validators` (validateurs purs) est tiré ; `zcrud_core` out-degree contrôlé (`CORE OUT=0`) ; `domain/` pur-Dart.
- **FR-2 / FR-4** — [prd.md] : rendu déclaratif multi-familles ; formulaires riches (assistant multi-étapes) reproduits par conception sans rebuild global.
- **SM-1** — [prd.md ligne 378] : sur un formulaire de référence, 100 caractères ne reconstruisent que le champ courant, zéro perte de focus — **re-prouvé ici DANS le stepper** (chrome inclus).

### CLAUDE.md — Key Don'ts directement pertinents

- **Never** importer un gestionnaire d'état · **Never** `setState` à l'échelle du formulaire · **Never** `Form`/`FormBuilder` global comme source d'état (AD-2) · **Never** `ListView(children:[...])` → `ListView.builder` · **Never** insets/alignements non directionnels · **Never** style/couleur codé en dur (thème via `ZcrudScope`/`ThemeExtension`, repli `Theme.of`) · **Always** `const` widgets immuables, `Semantics` + cibles ≥ 48 dp · **Never** éditer/committer un `.g.dart`.

### Fichiers existants à RÉUTILISER (LIRE avant d'implémenter — ne pas réécrire)

- `presentation/edition/dynamic_edition.dart` — **brique de montage à réutiliser par étape.** Déjà : `StatefulWidget` observant UNIQUEMENT les canaux structurels (`Listenable.merge(visibleFields, _collapsed)`, lignes 178-190, 304-315) ; `ListView.builder` + `findChildIndexCallback` (place stable focus, lignes 339-352) ; sections/conditionnels/grille/lecture E3-4 ; `ZEditionSection` (lignes 65-91) comme modèle pour `ZEditionStep`. **Réutiliser DynamicEdition** pour rendre le sous-ensemble de champs d'une étape (hérite gratuitement E3-1..E3-4 et la place stable).
- `presentation/z_form_controller.dart` — **le controller unique.** `fieldListenable`/`setValue`/`valueOf` (tranches mémoïsées jamais détruites sauf `dispose`, lignes 56-90) ; `visibleFields`/`setVisibleFields` (canal structurel, no-op `listEquals`, lignes 92-108). **La préservation d'état inter-étapes en découle directement** (les tranches survivent au démontage des champs). NE PAS ajouter de logique d'étape DANS le controller (il reste agnostique ; l'orchestration vit en présentation).
- `presentation/edition/z_validator_compiler.dart` — **réutiliser tel quel** pour la validation par étape : `ZValidatorCompiler.compile(specs)` → `FormFieldValidator<String>?` (lignes 50-59). **Note frontière (lignes 20-26)** : les validateurs **inter-champs** (`min`/`max` via `refKey`, `match`) sont **déférés** (le compilateur les ignore) — voir « Frontière — validateurs inter-champs » ci-dessous.
- `presentation/edition/z_edition_field.dart` — `ZEditionField` : `TextFormField` AUTONOME (aucun `Form`, ligne 148-160), `AutovalidateMode.onUserInteraction` par champ (ligne 152), validateur mémoïsé (`_validator`, ligne 103/111), `_stringOf` (ligne 123), sync guardée hors focus (lignes 140-146), restauration du buffer en `initState` depuis `valueOf` (lignes 106-113 — **socle d'AC8**). Réutiliser ; ne pas réécrire.
- `test/presentation/edition/field_validation_test.dart` — **modèle de test** : `expect(find.byType(Form), findsNothing)` (lignes 35-38), révélation d'erreur `onUserInteraction`, isolation du rebuild voisin. Le stepper doit rejouer `findsNothing` sur toutes les étapes.
- `test/presentation/edition/_reference_form.dart` / `sm1_e3_4_composite_test.dart` — helpers de fixture + patron de preuve SM-1 (`onStructuralBuild` inchangé, focus préservé). Réutiliser pour la fixture stepper.
- `edition_field_family.dart` (lignes 194-201) / `edition_field_type.dart` (ligne 145) — confirment que `stepper` est un **regroupement** rendu unsupported en tant que feuille : E3-5 le sert au niveau **orchestration**, sans widget de famille.

### Décision d'intégration — canal `visibleFields` & fenêtre d'étape (à trancher par le dev dans le respect d'AD-2)

Le montage d'une étape doit exposer **uniquement** les champs de cette étape, tout en préservant les tranches des autres étapes. Deux options :

- **(A) Recommandée — fenêtrage par sous-ensemble de `fields` passé à `DynamicEdition`.** Le stepper monte, pour l'étape courante, un `DynamicEdition` dont `fields` = specs de l'étape (et `sections` restreintes). `DynamicEdition` amorce/pilote `visibleFields` sur CE sous-ensemble (les conditionnels de l'étape recalculent en interne). Les champs des autres étapes ne sont **pas montés** mais leurs **tranches subsistent** dans le controller (AC7/AC9). Simple, réutilise tout E3-4. Attention : si le controller est partagé, s'assurer que le pilotage de `visibleFields` par une étape ne « perd » pas l'ensemble global — préférer que chaque étape gère sa propre fenêtre au montage (le `visibleFields` reflète l'étape montée ; c'est un canal structurel, pas la source des valeurs).
- **(B) Rendu direct par champ** (le stepper itère les champs de l'étape et monte `ZFieldWidget`/`ZEditionField` keyés `ValueKey(name)`), sans `DynamicEdition`. Plus de contrôle mais **réimplémente** l'interleave sections/conditionnels/place-stable d'E3-4 — **déconseillé** (duplication, risque de régression SM-1).

**Trancher (A)** sauf contrainte forte. Documenter le choix et prouver qu'aucune tranche n'est détruite au changement d'étape (AC7/AC9).

### Décision — révélation forcée des erreurs d'étape (AC4)

Les champs utilisent `AutovalidateMode.onUserInteraction` : un champ **jamais touché** n'affiche pas son erreur. À la transition, on doit **forcer l'affichage** des erreurs des champs invalides de l'étape, **sans** introduire de `Form` global. Options :

- **(A) Canal `_validateEpoch` (ValueNotifier<int>) transmis aux champs de l'étape** : à l'incrément (déclenché par un « suivant » bloqué), chaque champ de l'étape re-valide et affiche son erreur (bascule locale vers un mode « toujours valider » pour ce champ, ou re-run du validateur mémoïsé et pose du `errorText`). Pur AD-2 (par champ). Nécessite un **seam additif** minimal sur `ZEditionField` (ex. `autovalidateSignal`/`forceValidate`), OU un wrapper de présentation.
- **(B) `GlobalKey<FormFieldState<String>>` par champ de l'étape** : le stepper détient une clé par champ monté et appelle `key.currentState?.validate()` sur « suivant ». `FormFieldState.validate()` **fonctionne sans `Form` ancêtre** : il pose l'erreur ET renvoie la validité — **révélation + gate en un seul appel**. Nécessite d'exposer la clé du `TextFormField` interne de `ZEditionField` (seam additif).

**Recommandé** : **gate déterministe pur** via `_validateStep` (option T3, testable sans pump, couvre aussi les champs non-`TextFormField`) **pour décider** la navigation ; **révélation** via l'option (A) canal `_validateEpoch` OU (B) `GlobalKey`. Choisir le mécanisme le plus simple qui garde `find.byType(Form) == findsNothing` (AC2) et n'ajoute qu'un **seam additif** (pas de changement cassant de signature). Documenter le choix.

### Frontière — validateurs inter-champs (`min`/`max` via `refKey`, `match`)

`z_validator_compiler.dart` (lignes 20-26, 78-102) **ignore** les validateurs inter-champs et les note « **déférés E3-5/E3-6** ». **Décision pour E3-5** : le must-have de cette story est le **gate de navigation par étape** sur les validateurs **champ-locaux** (déjà compilés E3-2). Les validateurs **inter-champs** (closures mémoïsées capturant le `ZFormController`, lisant `valueOf(refKey)`) sont un mécanisme du **pipeline de validateur de champ**, **orthogonal** au stepper : les câbler ici serait du scope creep. **Ils restent déférés à E3-6** (validation finale/soumission, où l'ensemble des valeurs est arbitré) — sauf si le dev estime le seam trivial et sans risque, auquel cas il peut être posé additivement et couvert par un test. **E3-5 ne doit PAS être bloquée dessus.** Consigner ce report dans les Completion Notes.

### Frontière E3-5 / E3-4 / E3-6 (DÉCIDÉE)

- **E3-4 (fait)** : sections **repliables** (accordéon, page unique), conditionnels place-stable, mode lecture, grille 12 colonnes. **Coexistent sur une page.**
- **E3-5 (cette story)** : partitionne le **même** `ZFormController` en **étapes** séquencées (wizard) ; **une étape montée à la fois** ; validation **par étape** (gate « suivant ») sur validateurs champ-locaux E3-2 ; **état préservé** en va-et-vient (controller unique) ; navigation accessible/directionnelle ; SM-1 re-prouvé dans le stepper. **Ne fait PAS** : soumission finale, détection dirty, confirmation d'abandon, validateurs inter-champs.
- **E3-6 (suivant)** : validation **globale finale** → hook `onSubmit` app ; empreinte **dirty** + confirmation d'abandon/reset ; états UI (`submit-in-progress`, erreur via `AsyncValue.error`, AD-11) ; **write-back de valeur externe** (reset/reload, contrat uniforme posé en E3-4) ; **validateurs inter-champs** (`refKey`/`match`). Le stepper d'E3-5 s'**intègre** à E3-6 (le « suivant » de la **dernière** étape délègue la soumission à E3-6). E3-5 **ne fait pas** de soumission.

### Ambiguïtés détectées (à trancher en dev, sans bloquer)

1. **Source des `ZEditionStep`** : paramètre **présentation** (`List<ZEditionStep>` passé à `ZStepperEdition`), PAS une projection depuis `@ZcrudField`/`StepperConfig`. `z_field_config.dart` (ligne 9) mentionne un `StepperConfig → E3` additif : **hors périmètre** ici (authoring déclaratif d'étapes traçable pour une story ultérieure si besoin). Retenu : partition présentation par noms de champs, comme `ZEditionSection`.
2. **Validation d'un champ non-`TextFormField`** (booléen/select/date/sous-liste…) : les validateurs compilés E3-2 sont typés `String`. Retenu : `_validateStep` évalue `_stringOf(valueOf(name))` (cohérent avec le rendu `ZEditionField`) ; pour les familles non-texte à validateur (ex. `required` sur un select), vérifier le comportement (valeur `null`/vide → invalide). Le must-have couvre `required`/longueur/format sur champs texte ; les cas non-texte suivent la sémantique du compilateur.
3. **Comportement de la dernière étape** : « suivant » absent/désactivé, place réservée à un bouton de **soumission** délégué à E3-6. Retenu : le stepper expose un hook/slot `onComplete`/dernier bouton **sans** implémenter la soumission (E3-6).
4. **Étape avec champs conditionnels tous masqués** : une étape peut-elle être « vide » à l'exécution (tous ses champs masqués par condition) ? Retenu : `_validateStep` passe trivialement (aucun champ visible à valider) → transition permise ; documenter.
5. **Indicateur d'étape** : linéaire (points/numéros) vs libellé « Étape k/N ». Retenu : implémentation minimale accessible (label sémantique + titres d'étape) ; le style riche est cosmétique et thémable.
6. **Animation de transition** : hors périmètre AC ; si présente, ne doit pas recréer les `State`/controllers (place stable) ni casser SM-1.

### Project Structure Notes

- Nouveau fichier (présentation, `packages/zcrud_core/lib/src/`) : `presentation/edition/z_stepper_edition.dart` (`ZEditionStep` + `ZStepperEdition`). Réutilise `DynamicEdition` par étape.
- Seam additif éventuel sur `presentation/edition/z_edition_field.dart` (révélation forcée : `autovalidateSignal`/`GlobalKey`) — **additif, non cassant** ; ne pas modifier la voie de frappe ni la sync guardée.
- Exports publics via barrel `lib/zcrud_core.dart` — types préfixés `Z` (`ZEditionStep`, `ZStepperEdition`).
- Tests : `packages/zcrud_core/test/presentation/edition/` (sectionnement/controller partagé, no-Form, validation par étape, gate/blocage, préservation d'état aller-retour, SM-1 stepper, a11y/RTL navigation, composition conditionnels).
- **Aucune** modification du générateur/annotations ni des familles de champ. **Aucun** `.g.dart` à committer.

### Testing

Stratégie (widget + unit + a11y/RTL) :
- **Sectionnement / controller partagé (AC1)** : un `ZStepperEdition` à N étapes ; `setValue` visible depuis toute étape montant le champ ; **un seul** `ZFormController` (jamais recréé au changement d'étape).
- **No-Form (AC2)** : `expect(find.byType(Form), findsNothing)` à l'étape 1, après « suivant », à l'étape 2, au retour.
- **Validation par étape (AC3/AC4/AC5/AC6)** : (a) `required` d'une étape **ultérieure** vide ⇒ « suivant » depuis l'étape courante **passe** (AC3) ; (b) `required` de l'étape **courante** vide ⇒ « suivant » **bloqué**, index inchangé, message `errorText` révélé sous le champ (AC4) ; (c) champ rempli valide ⇒ « suivant » **avance** (AC5) ; (d) « précédent » depuis étape invalide **recule** sans erreur (AC6). `_validateStep` testé aussi **unitairement** (pur).
- **Préservation d'état aller-retour (AC7/AC8/AC9)** : saisir étape 1 → « suivant » (champs étape 1 démontés) → « précédent » → valeurs restaurées ; buffer texte + valeur réaffichés (AC8) ; tranches non détruites (via `controller.valueOf` inchangé après aller-retour).
- **SM-1 dans le stepper (AC10/AC11)** : fixture ≥ 3 étapes / étape ≥ 10 champs ; 100 frappes ⇒ `onStructuralBuild` du stepper **non incrémenté**, focus + curseur (offset médian) préservés ; le chrome (boutons/indicateur) ne se reconstruit pas pendant la saisie.
- **Composition conditionnels (AC13)** : champ conditionnel masqué dans l'étape courante n'empêche pas la transition ; rendu visible + invalide, il la bloque.
- **A11y / RTL navigation (AC12)** : `Semantics` sur Précédent/Suivant/indicateur, cible ≥ 48 dp ; bascule LTR↔RTL sans overflow ; rejouer `style_purity_test`/`field_rtl_test`.
- **Gardes CI (AC14)** : `melos run analyze` RC=0, `flutter test` RC=0, `melos run verify` RC=0 (`ACYCLIQUE`, `CORE OUT=0`, `reflectable`/`secrets`/`codegen`/`compat`), 0 `.g.dart`, `domain_purity_test`/`presentation_purity_test` verts.

### References

- [Source: _bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md — Story E3-5 (ligne 83), E3-4 (82), E3-6 (84), E3-3b (80)]
- [Source: _bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md#AD-2 (lignes 62-65, en particulier ligne 65 « Stepper »), #AD-13 (117-121), #AD-15 (128-130)]
- [Source: _bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md#FR-2, FR-4, SM-1 (378)]
- [Source: packages/zcrud_core/lib/src/presentation/z_form_controller.dart — controller unique, tranches mémoïsées jamais détruites, canal structurel visibleFields]
- [Source: packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart — montage réutilisable par étape, canal structurel, place stable, ZEditionSection (modèle de ZEditionStep)]
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart — compile() réutilisé pour la validation par étape ; frontière inter-champs déférée E3-5/E3-6]
- [Source: packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart — TextFormField autonome (no Form), autovalidate par champ, validateur mémoïsé, restauration buffer initState]
- [Source: packages/zcrud_core/lib/src/presentation/edition/edition_field_family.dart (194-201), edition_field_type.dart (145) — stepper = regroupement, servi au niveau orchestration]
- [Source: packages/zcrud_core/test/presentation/edition/field_validation_test.dart — modèle de test no-Form + révélation d'erreur ; sm1_e3_4_composite_test.dart / _reference_form.dart — patron SM-1]
- [Source: CLAUDE.md — Key Don'ts (pas de Form global, pas de setState de formulaire, directionnels, ListView.builder, pas de .g.dart) ; frontière E3-4/E3-5/E3-6 de e3-4-sections-conditionnels-lecture-grille.md (lignes 144-148)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, skill `bmad-dev-story`).

### Debug Log References

- `dart analyze lib/` (zcrud_core) → No issues found.
- `melos run analyze` → SUCCESS (RC=0, 14 packages).
- `flutter test` (zcrud_core) → +362 All tests passed (dont 13 nouveaux : 8 comportement + 2 SM-1 + 3 a11y/RTL).
- `melos run test` → SUCCESS (RC=0, agrégat dart+flutter).
- `melos run verify` → RC=0 (graph/melos-divergence/reflectable/secrets/codegen/compat/serialization).
- `graph_proof.py` → ACYCLIQUE OK ; **CORE OUT=0 OK** ; noeuds=14.
- `git ls-files '*.g.dart'` → 0 (aucun généré committé).

### Completion Notes List

**Décision d'intégration (canal `visibleFields` & fenêtre d'étape) — Option (A) retenue.** Chaque étape monte un `DynamicEdition` sur le **sous-ensemble** de specs de l'étape (hérite gratuitement conditionnels/sections/grille/place-stable d'E3-1..E3-4). Pour éviter qu'une étape à conditions ne « perde » la fenêtre au bénéfice d'une étape sans conditions, l'orchestrateur pilote lui-même `controller.setVisibleFields(_windowFor(step))` (fenêtre = champs de l'étape filtrés par condition, ordre canonique) à l'initState et à **chaque navigation** — no-op `listEquals` si inchangé, idempotent avec le recalcul interne de `DynamicEdition`. Aucune tranche n'est jamais détruite (AC7/AC9 prouvés : `valueOf` inchangé après aller-retour).

**Décision — révélation forcée des erreurs (AC4) — seam additif Option (A)/autovalidate.** Ajout d'un paramètre **optionnel non cassant** `autovalidateMode` sur `ZFieldWidget` → `ZTextFieldWidget`/`ZNumberFieldWidget` (défaut `onUserInteraction` : comportement E3-2/E3-3a strictement inchangé). Le stepper bascule ce mode à `AutovalidateMode.always` pour l'étape courante via un canal **structurel local** `ValueNotifier<bool> _reveal` quand un « suivant » est bloqué → chaque champ invalide affiche son `errorText` **sans** aucun `Form`/`FormBuilder` global (`find.byType(Form)` reste `findsNothing` sur toutes les étapes). `_reveal` est remis à `false` à toute navigation effective. La **décision** de navigation reste un gate PUR `_validateStep(i)` (compile mémoïsé `ZValidatorCompiler` évalué contre `_stringOf(valueOf)`), déterministe, ne validant QUE les champs **visibles** de l'étape.

**SM-1 dans le stepper (AC10/AC11).** Le chrome (indicateur + navigation + zone d'étape) est scellé sous un `ListenableBuilder` observant `Listenable.merge([_currentStep, _reveal, controller.visibleFields])` — **jamais** une tranche de valeur. Preuve rejouée : 100 frappes ⇒ `onStructuralBuild` (chrome) **inchangé**, seul le champ courant reconstruit (~1/frappe), aucun voisin, focus + curseur (fin ET milieu) préservés.

**Frontière E3-6 (respectée).** La dernière étape expose un bouton « Terminer » qui délègue à un slot `onComplete` (E3-6) après validation de l'étape ; E3-5 n'implémente ni `onSubmit`, ni dirty, ni confirmation. **Validateurs inter-champs** (`refKey`/`match`) : restés **déférés** à E3-6 (aucun câblage ici — hors périmètre, conforme à la frontière de `z_validator_compiler.dart`).

**Ambiguïtés tranchées** : #1 `ZEditionStep` = descripteur présentation (titre + noms), pas une projection `@ZcrudField` (StepperConfig hors périmètre). #3 dernière étape = slot `onComplete` (bouton désactivé si `null`). #4 étape à champs tous masqués ⇒ `_validateStep` passe trivialement (transition permise). #5 indicateur minimal accessible « k/N + titre » (`Semantics(header)`), style thémable. `_validateStep` étant privé, sa pureté est prouvée **via** les transitions widget (bloque/autorise) plutôt qu'en unit isolé.

**a11y/RTL (AC12).** Boutons Material (rôle `button`, `label` fusionné, état `enabled` dérivé de `onPressed`, action tap) sans `Semantics(label:)` surajouté (évite le nœud dupliqué) ; cible ≥ 48 dp via `ConstrainedBox(minHeight/minWidth: 48)` ; insets `EdgeInsetsDirectional`, `TextAlign.start` ; ordre visuel Précédent→Suivant suivant la `Directionality` (bascule LTR↔RTL sans overflow ni exception). Gardes `style_purity`/`presentation_purity`/`field_rtl` vertes sans relâchement.

### File List

- `packages/zcrud_core/lib/src/presentation/edition/z_stepper_edition.dart` (**créé**) — `ZEditionStep` + `ZStepperEdition` + `ZStepFieldBuilder` + chrome (`_StepIndicator`, `_StepNavigationBar`).
- `packages/zcrud_core/lib/zcrud_core.dart` (**modifié**) — export du stepper (ordre alpha).
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (**modifié**) — seam additif `autovalidateMode?` (défaut `onUserInteraction`) propagé aux familles clavier.
- `packages/zcrud_core/lib/src/presentation/edition/families/z_text_field_widget.dart` (**modifié**) — param additif `autovalidateMode` (défaut `onUserInteraction`).
- `packages/zcrud_core/lib/src/presentation/edition/families/z_number_field_widget.dart` (**modifié**) — param additif `autovalidateMode` (défaut `onUserInteraction`).
- `packages/zcrud_core/test/presentation/edition/stepper_edition_test.dart` (**créé**) — AC1/AC2/AC3/AC4/AC5/AC6/AC7/AC8/AC9/AC13 (8 tests).
- `packages/zcrud_core/test/presentation/edition/sm1_stepper_test.dart` (**créé**) — AC10/AC11 (2 tests, curseur fin + milieu).
- `packages/zcrud_core/test/presentation/edition/stepper_a11y_rtl_test.dart` (**créé**) — AC12 (3 tests, Semantics/≥48dp/LTR↔RTL).
