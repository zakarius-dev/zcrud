# Code Review — Story E3-2 : Controllers & keys stables, validation ciblée

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (chemin pris : **Skill tool**, step-file architecture `.claude/skills/bmad-code-review/steps/step-01..04`). Résolution customization via `resolve_customization.py` OK.
- **Cible** : story `e3-2-controllers-keys-stables.md` (8 ACs, statut `review`), `baseline_commit: acc6a213`.
- **Diff réel** : HEAD == baseline ; le code E3-1+E3-2 est **non commité** (répertoire `presentation/edition/` untracked). Revue menée sur l'état **réel sur disque** (fichiers lus, non supposés) + diff des fichiers suivis modifiés (`zcrud_core.dart`, `pubspec.yaml`, `presentation_purity_test.dart`).
- **Mode** : full (spec chargée).
- **Date** : 2026-07-09.

---

## Verdict : **APPROVED** (avec 1 MEDIUM de couverture recommandé, non bloquant)

Aucun finding HIGH/MAJEUR. Les invariants critiques FR-1 / AD-2 / SM-1 sont **implémentés correctement et prouvés par tests réels rejoués**. Le seul point sérieux est un **trou de couverture** sur l'ampleur du compilateur de validateurs (public), pas un défaut de comportement.

### Décompte par sévérité
| Sévérité | Nb |
|---|---|
| HIGH / MAJEUR | 0 |
| MEDIUM | 1 |
| LOW / nit | 3 |

---

## Résultats de vérification RÉELLEMENT rejoués sur disque

| Contrôle | Résultat |
|---|---|
| `dart analyze` (zcrud_core) | **RC=0** — « No issues found! » |
| Gardes de pureté (`test/purity/`) | **+9 verts** (presentation whitelist `form_builder_validators` OK ; rejette toujours flutter_form_builder/cupertino/services/dart:ui/managers ; domain + style verts) |
| Tests `presentation/edition/` | **+16 verts** (controller_stability, external_value_sync, field_validation, mid_cursor, sm1_full_form, sm1_with_validation, dynamic_edition, uj2_external_rebuild) |
| Suite complète `zcrud_core` | **+214 verts**, All tests passed |
| `graph_proof.py` | **RC=0** — out-degree(zcrud_core)=0, **CORE OUT=0 OK**, ACYCLIQUE OK, **14 nœuds** |
| `gate:compat` (E1-4) | **OK** — résolution manifeste verte (analyzer 8.4.1) ; voie lex_douane SKIP propre |
| `gate:reflectable` | OK — 0 usage hors allowlist |
| `gate:secrets` | OK — aucun secret |
| `melos list` | **14** packages |
| `flutter_form_builder` importé | **0 import réel** (2 mentions = commentaires uniquement, dans pubspec/purity/compiler docs) |
| `Form(` ancêtre sous `presentation/` | **0** (validation par champ autonome confirmée) |

### Points de vigilance adversariaux — statut vérifié
- **Sync guardée (FR-1) — CRITIQUE : CONFORME.** Write-back `_text.value =` **uniquement** sous `!_focus.hasFocus && _text.text != s` (z_edition_field.dart:141). Pendant la frappe locale `hasFocus==true` ⇒ garde bloque ⇒ **aucune** ré-injection (idempotent ; la condition texte est en plus fausse car `value==_text.text`). Test `external_value_sync (b)` prouve : focus actif + `setValue` externe ⇒ texte **et** sélection préservés, voisin intact, `valueOf` détient bien la valeur externe (réflexion différée). Aucun chemin de clobber pendant focus trouvé.
- **Controller/FocusNode stables (AD-2) : CONFORME.** `_text`/`_focus`/`_validator` en `late final`, créés **1×** en `initState`, `dispose` des deux (aucune fuite). Jamais recréés dans `build()`. `initState==1` prouvé après **8 `setVisibleFields`** structurels ET identité `TextEditingController` `identical` stable (controller_stability_test). La permutation des deux derniers champs garde la cible montée — **pas un faux négatif** : c'est un rebuild structurel réel (liste différente) isolant l'invariant du recyclage viewport (voir LOW-3).
- **Validateur mémoïsé (AC4) : CONFORME.** `_validator` compilé 1× en `initState` ; `identical(v1,v2)` et `identical(v1,v3)` prouvés après rebuild de tranche **et** structurel (field_validation_test). Champ sans validateur ⇒ `validator == null` prouvé.
- **Validation ciblée (AD-2) : CONFORME.** `TextFormField` autonome, `AutovalidateMode.onUserInteraction` **par champ** ; `find.byType(Form) → findsNothing` ; erreur sous CE champ (descendant de `ValueKey`), voisin sans erreur et **compteur de build voisin inchangé** (isolation), correction ⇒ disparition.
- **Curseur médian (L2 E3-1) : CONFORME.** `mid_cursor_test` pose le caret via `updateEditingValue(selection: collapsed(3))` (pas `enterText`), prouve insertion **médiane** (`'ABCXDEF'`, caret 4 ≠ 7) + préservation sous rebuild structurel (`initState==1`, `hasFocus` gardé).
- **Frontières : CONFORME.** Aucun dispatcher par type (E3-3a), aucun `onSubmit`/dirty/validation agrégée (E3-6), inter-champs (`match`, `min/max` par `refKey`) **explicitement déférés** E3-5/E3-6.

---

## Findings

### MEDIUM-1 — Compilateur de validateurs public : mapping ~17 familles NON testé (AC4/AC8, test-coverage)
`ZValidatorCompiler` est **exporté par le barrel** (API publique, réutilisée par E3-5) et AC4 énumère explicitement ~20 familles `ZValidatorKind` comme « couvertes par la compilation ». Or **aucun test dédié au compilateur** n'existe (`grep` : 0 fichier `*validator*test*`). Les seules familles exercées à travers `ZEditionField` sont `required` (field_validation, sm1) et `minLength` (sm1 — **compilée mais son comportement de validation n'est pas asservi**). Les ~17 autres (`maxLength`, `min`, `max`, `equal`, `notEqual`, `email`, `url`, `ip`, `creditCard`, `phone→phoneNumber`, `numeric`, `integer`, `dateString→date`, `address→street`, `percentage→between(0,100)`, `password`, `pattern→match(RegExp)`) n'ont **aucune** couverture.
- **Scénario d'échec** : une projection sémantiquement fausse (p. ex. `address→street` inadéquat, `percentage→between` acceptant une chaîne vide, un `errorText` non propagé, ou une branche `null`-guardée renvoyant `null` à tort) passerait `analyze` (les symboles existent) **et** toute la suite verte — le défaut n'émerge qu'en intégration E3-3a/E3-5.
- **Recommandation (dans le périmètre, coût faible)** : ajouter `test/presentation/edition/z_validator_compiler_test.dart` — pour chaque `ZValidatorKind` champ-local : assert `compile([spec]) != null`, propagation d'`errorText`, et 1 cas valide/invalide représentatif ; asserts `compile([]) == null` et `compile([match/minKey]) == null` (déférés). Prouve aussi la branche `compose` (déjà exercée) vs validateur unique.
- Non bloquant : le must-have E3-2 (validateurs **champ-locaux** `required`/`minLength`) est livré et exercé ; le comportement expédié est correct. À corriger de préférence ici (MEDIUM CLAUDE.md), sinon justifier le report.

### LOW-1 — Validateurs inter-champs silencieusement absorbés (foot-gun)
`ZValidatorSpec.minKey('x')` ⇒ kind `min` + `bound == null` ⇒ `_compileOne` renvoie `null` ; `match` ⇒ `null`. Le validateur **disparaît sans avertissement** : un développeur attachant `minKey`/`maxKey`/`match` obtient **aucune** validation et **aucun** signal. Décision documentée (déféré E3-5/E3-6, « ambiguïté tranchée »), donc acceptable en LOW — mais envisager un `assert(false, 'refKey deferred')` en debug ou un TODO traçable pour éviter un oubli silencieux en E3-5.

### LOW-2 — Réflexion différée non déclenchée à la perte de focus
AC2 admet une « réflexion différée **à la perte de focus** ». En pratique la sync guardée ne s'exécute qu'au **prochain rebuild de tranche** en état non-focalisé ; le `FocusNode` n'est pas écouté, donc un simple blur après un `setValue` externe survenu pendant le focus **ne rafraîchit pas** le champ tant qu'aucune autre notification de tranche n'arrive (le `TextField` garde le texte local, `valueOf` détient la valeur externe). Conforme à l'esprit d'AC2 (différé accepté) mais légèrement plus faible que la lettre « à la perte de focus ». Sans impact FR-1. À documenter/relever pour E3-3a si un rafraîchissement au blur est souhaité.

### LOW-3 — Invariant AC1/AC6 prouvé uniquement pour réordonnancements « in-viewport »
Les tests structurels permutent délibérément les **deux derniers** champs pour garder la cible montée, car un grand déplacement fait **recycler** l'`Element` par `ListView.builder` (`initState==2`, sélection perdue) — reconnu dans les Dev Notes (« incident de test résolu »). Ce n'est **pas** un faux négatif (le test est honnête et isole l'invariant AD-2 « rebuild ⇒ pas de recréation » du recyclage viewport). Mais la lecture naïve d'AC1 (« réordonnant **l'ensemble** ») n'est pas couverte : un vrai réordonnancement déplaçant loin un champ focalisé perdrait son état/curseur. Limitation de conception connue (ValueKey + position viewport), hors périmètre E3-2 ; à garder en tête pour E3-4 (champs conditionnels/réordonnancement réel).

---

## Non-régression confirmée
- E3-1 : `sm1_full_form`, `uj2_external_rebuild`, `dynamic_edition` **verts**.
- E2-7/E2-9 : suite `zcrud_core` complète **+214 verts** ; graphe CORE OUT=0 ; gates melos/reflectable/secrets/codegen/compat/serialization intacts.
- SM-1 (objectif produit n°1) **renforcé** avec validation active (sm1_with_validation : 100 frappes, voisins + formulaire strictement inchangés, focus + curseur préservés, valeur finale correcte).

## Conclusion
Story **conforme** aux ACs comportementaux et aux invariants FR-1/AD-2/SM-1, verte de bout en bout. **APPROVED**. Correction recommandée du MEDIUM-1 (test unitaire du compilateur) avant `done` — sinon justification écrite du report. LOW-1..3 optionnels/consignés.
