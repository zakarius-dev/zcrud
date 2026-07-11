# Code-review adversarial — Périmètre A (DP-12, DP-13, DP-14, DP-16)

Mode : **VRAI skill `bmad-code-review` invoqué** (Skill tool, workflow step-file chargé). Exécution autonome (subagent, aucun humain — checkpoints HALT non applicables, adaptés en revue continue).
Date : 2026-07-11 · Modèle : claude-opus-4-8 · Cible : 4 stories majeures E-DP en `review` (zcrud_core + annotations/generator).

## Vérifications REJOUÉES réellement sur disque (RC réels)

| Vérif | Commande | RC | Résultat |
|---|---|---|---|
| Analyze | `dart analyze packages/zcrud_core packages/zcrud_annotations packages/zcrud_generator` | **0** | `No issues found!` |
| Tests core | `flutter test packages/zcrud_core` | **0** | `All tests passed!` — **857** tests |
| Tests generator | `dart test packages/zcrud_generator/test` | **0** | `All tests passed!` — **87** tests (dont `dp12_dp13_projection_test`) |
| Tests annotations | `dart test packages/zcrud_annotations` | **0** | `All tests passed!` — **9** tests |
| Graphe | `python3 scripts/dev/graph_proof.py` | **0** | `ACYCLIQUE OK` · `CORE OUT=0 OK` |

Note : `melos run analyze`/`verify` **REPO-WIDE** non rejoué ici (hors des 5 vérifs prescrites ; DP-16 DoD le diffère explicitement au gate d'epic orchestrateur). Les 4 stories sont **additives** sur core/annotations/generator et `graph_proof` est vert, mais le gate d'epic DOIT rejouer `melos analyze` repo-wide avant `done` (règle cross-package NON-NÉGOCIABLE CLAUDE.md).

---

## DP-12 — Décoration enrichie (M1+M5+M6) — **VERDICT : APPROVED**

Zones à risque vérifiées :
- **ZFieldAdornment pur-données (AD-3/AD-14)** ✅ `z_field_adornment.dart` : type-valeur `const`, un seul payload `String`, discriminé `ZAdornmentKind{text,icon,widget}`. Aucun `IconData`, aucun `Widget`, aucune closure, aucun import Flutter. `==`/`hashCode`/`toString` de valeur. Garde `domain_purity` verte.
- **Slots additifs `ZFieldSpec`** ✅ `leading/prefix/suffix` (`ZFieldAdornment?`) + `hintText/helperText` (`String?`), défaut `null`, intégrés au ctor `const`, `copyWith`, `==`, `hashCode` (les 19 champs couverts). Rétro-compat de valeur préservée.
- **Générateur (projection)** ✅ `_emitSpec` (L412-426) n'émet `leading/prefix/suffix/hintText/helperText` que si `!isNull` ; `_emitConst` re-émet les ctors nommés (`ZFieldAdornment.text(...)`) à l'identique (revive vérifié en test). Champ sans slot ⇒ spec inchangée (golden testé).
- **`ZFieldLabel` (M5)** ✅ couleur astérisque = `tokens.errorColor ?? colorScheme.error` (jamais `kErrorColorDark` en dur — FR-26) ; astérisque `ExcludeSemantics` (décoratif, AD-13) rendu ssi `isRequired && !field.readOnly` (parité `_buildLabelWidget`) ; directionnel (`TextAlign.start`). Widget statique (aucune tranche — SM-1).
- **`resolveAdornment` défensif (AD-10)** ✅ `.icon` clé inconnue ⇒ `null` (seam `ZcrudScope.iconResolver` → table Material bornée → `null`, jamais de throw) ; `.widget` `kind` non enregistré ⇒ `null`. Aucun `IconData` dans le domaine.
- **SM-1 / AD-2** ✅ décoration résolue statiquement (`zFieldDecoration`), aucune allocation de contrôleur/`Listenable` ; la Card `large` résout leading/suffix **une fois** hors frontière de rebuild (`z_field_widget.dart` L318-336).

### Findings

**[LOW] DP-12-L1 — `suffix` (Widget) + `suffixText` mutuellement exclusifs dans `InputDecoration`.**
Fichier : `packages/zcrud_core/lib/src/presentation/edition/z_field_adornment_view.dart:178-193` (`zFieldDecoration`).
Un champ portant à la fois un ornement `suffix` déclaratif de kind `.text`/`.widget` (⇒ `suffix` Widget non nul) **et** un `suffixText` DP-17 (config devise/pourcentage) alimenterait simultanément `InputDecoration(suffix:, suffixText:)`. Flutter **asserte** `suffix == null || suffixText == null` → crash d'assertion en debug. Cas étroit (nécessite un `number`+`ZNumberConfig` currency/percentage ET un ornement suffixe texte/widget sur le même champ) ; un suffixe `.icon` (`suffixIcon`) coexiste sans problème avec `suffixText`.
Remédiation : quand `suffixText != null`, préférer router un ornement `.text` vers `suffixIcon`/ignorer, ou documenter/asserter l'exclusivité côté helper (privilégier `suffixText` neutre DP-17 ou le `suffix` déclaratif, pas les deux). Optionnel (relève partiellement de DP-17, hors périmètre A).

---

## DP-13 — Fiche lecture + flip `showIfNull` (M3+M4) — **VERDICT : APPROVED**

Zone à risque n°1 (FLIP `showIfNull → false`) — vérifiée end-to-end :
- **Opt-in NON cassé** ✅ Défaut aligné aux **trois** surfaces : `ZFieldSpec.showIfNull = false` (`z_field_spec.dart:48`), `@ZcrudField.showIfNull = false` (`zcrud_field.dart:58`), et le générateur n'émet `showIfNull:` **que si `true`** (`zcrud_model_generator.dart:410` : `if (r.read('showIfNull').boolValue) parts.add('showIfNull: true')`). Donc `@ZcrudField()` ⇒ aucune émission ⇒ défaut `false` ; `@ZcrudField(showIfNull: true)` ⇒ `showIfNull: true` émis. **L'opt-in `true` n'est jamais écrasé** (test `dp12_dp13_projection_test` : « émis SEULEMENT si true »). Companion générateur correctement appliqué.
- **Flip BORNÉ au mode lecture** ✅ `dynamic_edition.dart:465-468` `_renderInReadMode` retourne `true` (affiché) dès `!widget.readOnly` — `showIfNull` est **inerte hors mode lecture**. Édition/liste/SM-1 intacts.
- **Note de migration présente** ✅ Docstring `ZFieldSpec.showIfNull` (L97-101, « BREAKING (mode lecture uniquement) ») + Completion Notes (AC13).

Autres zones :
- **Fiche : aucun contrôleur (AD-2/SM-1)** ✅ `z_field_widget.dart:162,204` : `_readModeCard = readMode && zReadModeCardable(_family)` ; garde `if (familyUsesTextController(_family) && !_readModeCard)` ⇒ ni `TextEditingController` ni `FocusNode` alloués en fiche. Fiche montée SOUS `ZFieldListenableBuilder` (frontière = tranche).
- **Copie a11y (AD-13)** ✅ appui long (parité DODLP) **+** `IconButton` explicite (cible native ≥ 48 dp, tooltip/`Semantics` l10n `copy`) ; `Clipboard.setData` + `SemanticsService.sendAnnouncement` + `ScaffoldMessenger.maybeOf(...)?.showSnackBar` (best-effort, aucun throw si absent). `Semantics(container, label, value)` + `ExcludeSemantics` sur label/valeur visibles (pas de double annonce).
- **Formatage défensif (AD-10)** ✅ `zReadOnlyValueOf` pur, ne lève jamais ; `password` ⇒ jamais en clair (`••••`/`—`, non copiable) ; Map bornée à 200 car. ; valeur-Widget (`color`) ⇒ copie désactivée. Insets directionnels ; couleurs dérivées `ColorScheme`.

### Findings
Aucun (HIGH/MAJEUR/MEDIUM/LOW). Non-régression L1 confirmée : décoration DP-12 et readMode cohabitent sans déplacer la frontière de rebuild.

---

## DP-14 — ACL édition étendu 5→11 (M7) — **VERDICT : APPROVED**

Zone à risque n°2 (extension enum) — vérifiée :
- **6 valeurs APRÈS les 5, jamais réordonnées** ✅ `z_acl.dart:29-63` : `view/create/update/delete/restore` puis `copy/archive/publish/clear/validate/history`. `ZCrudAction.values.length == 11` (testé). Doc-comment d'ordre additif + posture sérialisation défensive présents.
- **`ZAllowAllAcl` couvre les 6** ✅ `can(...) => true` couvre gratuitement toute valeur (testé par itération sur `.values` + assertions nominatives).
- **Aucun `switch` exhaustif cassé** ✅ `grep "case ZCrudAction."` sur `packages/**` (hors `.g.dart`) = **0 occurrence**. Consommateurs LISTE (`z_row_action.dart`) / sub-liste (`z_sub_list_field_widget.dart`, DP-6) = call-sites `.can(...)`/`requiredPermission`, non-exhaustifs, intacts.
- **Gate `DynamicEdition` en voie STRUCTURELLE (SM-1)** ✅ `dynamic_edition.dart:505-537` : `_permittedFormActions()`/`_can` évalués DANS le `ListenableBuilder(_structural)` (jamais une tranche de valeur) ; `formActions` vide OU toutes refusées ⇒ `return list` (rétro-compat pixel). `onStructuralBuild` stable pendant la frappe (testé).
- **Défensif (AD-10)** ✅ `_can` : `try/catch` ⇒ ACL défaillante = action masquée (fail-closed), jamais de throw. `collectionId` passé tel quel (seam neutre AD-16).
- **a11y** ✅ `_FormActionButton` : `Semantics(button)` + `Tooltip` + `ConstrainedBox` (≥ 48 dp) + `EdgeInsetsDirectional`, couleurs du thème.

### Findings
Aucun.

---

## DP-16 — Validation password/address/percentage (M10+M11) — **VERDICT : CHANGES REQUESTED**

Zone à risque n°3 (assouplissement validateurs) — vérifiée :
- **Password défaut = politique DODLP** ✅ `ZValidatorSpec.password` : `minLength=8, maxLength=20, requireUppercase=true, requireLowercase=true, requireDigit=false, requireSpecial=false` ; compiler mappe `requireX ? 1 : 0` sur `PasswordValidator` fbv-11.3.0 (compte `0` = exigence désactivée, gardes `if (count>0)` vérifiées). `Abcdefgh` (maj+min, ni chiffre ni spécial) accepté ; strict opt-in accepté (testé AC2/AC3).
- **address/percentage no-op par défaut** ✅ `_compileOne` retourne `null` sans `enforceFormat`/`enforceRange` ; opt-in ⇒ `street`/`between` (testé AC4/AC5). Liste no-op ⇒ `compile` renvoie `null` (contrat préservé).
- **Catalogue `ZValidatorKind` FERMÉ (AD-3)** ✅ 20 valeurs inchangées (test d'inventaire) ; `ZValidatorSpec` reste `const` pur-données (nouveaux champs `int?/num?/bool?`, aucune closure/`RegExp`) ; `==`/`hashCode` (via `Object.hashAll`) intègrent les 10 nouveaux champs. Compiler statique/pur (AD-2), ne lève jamais (AD-10, testé params incohérents).
- **Changements de défaut documentés** ✅ Change Log + Dev Notes + docstrings ; DODLP intact.

### Findings

**[MEDIUM] DP-16-M1 — Parité password INCOMPLÈTE : un champ password NON requis rejette la valeur vide (contredit DODLP).**
Fichier : `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart:139-147`.
`FormBuilderValidators.password(...)` a pour défaut `checkNullOrEmpty: true` (vérifié : `form_builder_validators-11.3.0/lib/src/form_builder_validators.dart:834-852` + `BaseValidator.validate` L24 : `if (checkNullOrEmpty && isNullOrEmpty) return errorText;`). Le compiler **ne surcharge pas** ce paramètre.
Conséquence : un champ `password` **sans** `ZValidatorSpec.required` produit néanmoins une erreur sur une entrée **vide** — donc **tout** champ password est implicitement requis. Or DODLP `validatePassword` traite explicitement « vide + non requis ⇒ `null` (valide) » (documenté story DP-16 §« Comportement DODLP exact » ligne 24). Le modèle de composition zcrud délègue la vacuité à un `ZValidatorSpec.required` **séparé** (comme `email`/`url`), ce que ce mapping court-circuite.
Scénario de défaut concret : un formulaire DODLP migré avec un champ `password` **optionnel** laissé vide ⇒ `« Invalid password »` affiché et **soumission bloquée**, alors qu'il était valide en DODLP → la parité M10 visée par la story n'est pas restaurée pour ce cas.
Remédiation : passer `checkNullOrEmpty: false` à `FormBuilderValidators.password(...)` dans `_compileOne` (la vacuité reste gouvernée par un `ZValidatorSpec.required` explicite). Ajouter un test : `compile([const ZValidatorSpec.password(errorText: 'E')])!('')` retourne `null`, et `compile([required(), password()])('')` échoue au `required`. Précision : régression **pré-existante** (même défaut avant DP-16), mais DP-16 est la story propriétaire de la parité password — c'est le lieu de correction. À défaut de corriger dans le périmètre, **justifier par écrit** (règle MEDIUM CLAUDE.md) que le cas vide/optionnel est hors M10.

---

## Synthèse

| Story | Verdict | HIGH | MAJEUR | MEDIUM | LOW |
|---|---|---|---|---|---|
| DP-12 | **APPROVED** | 0 | 0 | 0 | 1 (DP-12-L1) |
| DP-13 | **APPROVED** | 0 | 0 | 0 | 0 |
| DP-14 | **APPROVED** | 0 | 0 | 0 | 0 |
| DP-16 | **CHANGES REQUESTED** | 0 | 0 | 1 (DP-16-M1) | 0 |

Recommandation orchestrateur : corriger **DP-16-M1** (`checkNullOrEmpty: false`, 1 ligne + test) avant `done` de DP-16, ou consigner la justification écrite si jugé hors scope M10. DP-12-L1 (LOW) : optionnel, à traiter idéalement avec DP-17 (helper partagé `zFieldDecoration`). Rappel : rejouer **`melos run analyze` REPO-WIDE** au gate d'epic (cross-package annotations/generator).

---

## Résolution des findings (orchestrateur, post-review)

- **MEDIUM DP-16-M1 — CORRIGÉ** : `z_validator_compiler.dart` — ajout de `checkNullOrEmpty: false`
  au `FormBuilderValidators.password(...)`. Un champ password NON requis laissé vide est de
  nouveau valide (parité DODLP « vide + non requis ⇒ null ») ; la présence reste gouvernée
  séparément par `ZValidatorKind.required`. Test de non-régression ajouté
  (`z_validator_compiler_test.dart` → « DP-16-M1 : password NON requis laissé vide reste VALIDE »).
- **LOW DP-12-L1 — CORRIGÉ** : `z_field_adornment_view.dart` — garde défensive
  `suffixText: suffix != null ? null : suffixText` (InputDecoration interdit `suffix` widget +
  `suffixText` simultanément — assertion Flutter). Un ornement `suffix` déclaratif l'emporte ;
  `suffixIcon` + `suffixText` restent compatibles.
- **LOWs groupe B** (soft-delete session-only DP-19, libellés FR markdown DP-22, `_applyHex` par
  frappe DP-17, source vide DP-15) : **reportés, justifiés** — design documenté (soft-delete de
  session vs `is_deleted` persistant = couche données/app, cohérent AD-9) ou cohérents avec des
  patterns pré-existants. Non bloquants.

**Vérif verte re-jouée sur disque après corrections** : `dart analyze packages/zcrud_core` RC=0 ·
`flutter test packages/zcrud_core` **858 tests** RC=0 · `graph_proof.py` CORE OUT=0 + ACYCLIQUE ·
`melos run analyze` REPO-WIDE **SUCCESS** (14 packages) · `melos run verify` RC=0 (inchangé : les
corrections ne touchent ni sérialisation/codegen/secrets/graphe). **DP-12..DP-22 → done.**
