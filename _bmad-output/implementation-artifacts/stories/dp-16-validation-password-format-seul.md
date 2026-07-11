# Story DP.16: Validation — politique mot de passe paramétrable + validateurs « format seul » non bloquants (parité DODLP, gaps M10+M11)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur migrant un formulaire DODLP vers zcrud,
I want que (1) le validateur de **mot de passe** (`ZValidatorSpec.password`) soit **paramétrable** avec des **défauts alignés sur la politique DODLP** (8–20 caractères, majuscule + minuscule requises, **ni chiffre ni caractère spécial** requis), la politique stricte restant **opt-in** ; et que (2) les validateurs « **format seul** » `address` et `percentage` soient **non bloquants par défaut** (rôle de simple indice de clavier/champ, comme DODLP), la contrainte de format/plage devenant **opt-in**,
so that un mot de passe et des valeurs `address`/`percentage` **valides en DODLP ne soient plus rejetés** après migration (parité restaurée), **sans** casser les usages existants, **sans** ouvrir le catalogue `ZValidatorKind` (AD-3), en restant **pur-données/défensif** (AD-3/AD-10) et **rétro-compatible** (tous les validateurs existants restent disponibles et `const`).

## Contexte & source de vérité

- **Gap M10** (`docs/dodlp-edition-parity-gap.md:160`, `:209`) — **MAJEUR** : politique mot de passe DODLP = **8–20 caractères, majuscule + minuscule requises, PAS de chiffre requis, PAS de caractère spécial requis** (`edition_screen.dart:719-742`). Côté zcrud, `ZValidatorSpec.password()` (sans paramètre) compile en `FormBuilderValidators.password()` dont les **défauts sont plus stricts** (min 8, **max 32**, **1 majuscule, 1 minuscule, 1 chiffre, 1 spécial**). ⇒ Un mot de passe **valide en DODLP** (ex. `Abcdefgh`) est **rejeté** par zcrud (manque chiffre + spécial).
- **Gap M11** (`docs/dodlp-edition-parity-gap.md:161`, `:210`) — **MAJEUR** : en DODLP, les clés `address`/`percentage`/`date` sont des validateurs **« format seul » = no-op de validation** (seul l'indice de clavier change : `address` → `TextInputType.streetAddress` `edition_screen.dart:712-713` ; `percentage` → `isPercentage=true` `:715-717`, **aucune** fonction de validation retournée). Côté zcrud, `address → FormBuilderValidators.street()` et `percentage → FormBuilderValidators.between(0,100)` **VALIDENT** (`z_validator_compiler.dart:119-125`) ⇒ des valeurs **qui passaient en DODLP** (adresse partielle, `@@@`, pourcentage non numérique ou hors 0–100) sont **rejetées** en zcrud. (`date`/`dateString` est traité à part — voir §Périmètre : hors scope M11 ici.)

### Comportement DODLP exact (lecture réelle — `dodlp-otr`, LECTURE SEULE)

Fichier : `lib/modules/data_crud/presentation/views/edition_screen.dart`.

1. **Mot de passe** (`:719-742`) — la fonction `validatePassword` DODLP :
   - vide + non requis ⇒ `null` (valide) ; vide + requis ⇒ « Mot de passe requis ».
   - `value.length < 8` ⇒ « trop court » ; `value.length > 20` ⇒ « trop long ».
   - `!contains([A-Z])` ⇒ « au moins une majuscule » ; `!contains([a-z])` ⇒ « au moins une minuscule ».
   - **Les branches chiffre (`[0-9]`) et caractère spécial sont COMMENTÉES** (`:735-740`) ⇒ **ni chiffre ni spécial requis**. `maxLength = 20` (≠ 32 de `form_builder_validators`).
2. **`address`** (`:712-713`) : `textInputType = TextInputType.streetAddress; break;` — **aucun validateur** (indice de clavier seul).
3. **`percentage`** (`:715-717`) : `isPercentage = true; break;` — **aucun validateur** (indice/format d'affichage seul, saisie numérique libre).

**Retenu pour zcrud** (voir §Décisions) : `password` **paramétrable, défaut = politique DODLP** (permissif) ; `strict` opt-in. `address`/`percentage` **no-op par défaut** (indice de clavier/champ conservé via la famille/config, hors validateur), **contrainte opt-in**.

## État actuel du code cœur (fichiers à MODIFIER — lus intégralement)

- **`packages/zcrud_core/lib/src/domain/edition/z_validator_spec.dart`** (229 l.) :
  - `enum ZValidatorKind { required, minLength, maxLength, min, max, equal, notEqual, match, email, url, ip, creditCard, phone, numeric, integer, dateString, address, percentage, password, pattern }` — **catalogue FERMÉ (AD-3)**. **Ne PAS ajouter/retirer de valeur.**
  - `class ZValidatorSpec` : type-valeur `const` **pur-données** (aucune closure, aucune exécution — c'est ce qui rend `reflectable` inutile et le schéma lisible par `ConstantReader`). Constructeur privé `._(kind, {length, bound, refKey, value, pattern, errorText})` + fabriques nommées `const` par variante. Champs `final` : `kind, length, bound, refKey, value, pattern, errorText`. `==`/`hashCode`/`toString` couvrent **tous** les champs.
  - Fabriques concernées : `ZValidatorSpec.address({String? errorText})` (L173), `.percentage({String? errorText})` (L177), `.password({String? errorText})` (L181) — **aucune ne porte de paramètre de politique aujourd'hui**.
- **`packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart`** (136 l.) : `ZValidatorCompiler.compile(List<ZValidatorSpec>) → FormFieldValidator<String>?`. **PUR/statique** (aucun `BuildContext`, aucun état). `_compileOne(spec)` mappe chaque `kind` :
  - `case ZValidatorKind.address:` → `FormBuilderValidators.street(errorText: e)` (L119-122). **← M11.**
  - `case ZValidatorKind.percentage:` → `FormBuilderValidators.between<String>(0, 100, errorText: e)` (L123-125). **← M11.**
  - `case ZValidatorKind.password:` → `FormBuilderValidators.password(errorText: e)` (L126-127) — **défauts fbv (min 8, max 32, 1 maj, 1 min, 1 chiffre, 1 spécial)**. **← M10.**
  - Contrat existant : une spec dont un paramètre requis est absent ⇒ `_compileOne` renvoie `null` (spec ignorée, aucun validateur produit). Liste sans validateur champ-local ⇒ `compile` renvoie `null` (aucune surcharge sur le `TextFormField`).
- **`packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart`** (L111) : `_validator = ZValidatorCompiler.compile(widget.field.validators);` — **mémoïsation** (`late final`, identité stable, jamais recréé en `build()` — AD-2). Seul point (avec `z_cross_field_validator.dart:71` et `z_stepper_edition.dart:511`) appelant `compile`.
- **`packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart`** : `ZcrudLocalizations` — maps `_enLabels`/`_frLabels`, clés d'UI CRUD génériques (dont `required` L33/L96, `invalidValue` L34/L97). **Ajout additif de clé** possible (deux maps). Le cœur n'exige PAS `flutter_localizations`/`FormBuilderLocalizations`.
- **Tests verrouillant le comportement actuel (à METTRE À JOUR)** :
  - `packages/zcrud_core/test/presentation/edition/z_validator_compiler_test.dart:125-141` — `address → street` (rejette `@@@`), `percentage → between(0,100)` (rejette `150`), `password` (valide `Passw0rd!`, rejette `abc`). Ces assertions encodent l'**ancien** comportement → **à réécrire** vers le nouveau (no-op par défaut + opt-in ; défaut DODLP + strict opt-in).
  - `packages/zcrud_core/test/domain/edition/edition_field_type_test.dart:124-126` — instancie `ZValidatorSpec.address()/.percentage()/.password()` : doit rester **vert** (fabriques toujours disponibles, paramètres nouveaux optionnels).

## Périmètre (STRICT)

**1 seul package : `packages/zcrud_core` (+ ses tests).** Aucun autre package modifié.

Fichiers concernés :
1. `lib/src/domain/edition/z_validator_spec.dart` — enrichir les fabriques `password`/`address`/`percentage` (paramètres de politique) + champs `final` associés + `==`/`hashCode`. **Additif / const-safe / catalogue inchangé.**
2. `lib/src/presentation/edition/z_validator_compiler.dart` — mapper les nouveaux paramètres ; rendre `address`/`percentage` **no-op par défaut** (renvoyer `null`) et **opt-in** ; mapper la politique password sur `FormBuilderValidators.password(...)`.
3. `lib/src/presentation/l10n/z_localizations.dart` — clé additive `invalidPassword` (en + fr).
4. Tests sous `packages/zcrud_core/test/` (mise à jour des 2 tests ci-dessus + nouveaux cas M10/M11).

**HORS SCOPE (ne PAS traiter dans DP-16)** :
- `date`/`dateString` : le no-op DODLP `date` est **hors M11 ici** — `dateString` reste inchangé (couvert par la famille date / DP-10/DP-11). **Ne pas toucher** `case ZValidatorKind.dateString`.
- Le **schéma structuré `address` (`ZPostalAddress`)** et l'autocomplete géo (gap B10) — story distincte.
- Le **type de clavier / la famille de champ** `address`/`percentage` (l'indice de saisie vit dans la famille/config du champ, pas dans le validateur) — non modifié ici.

**INTERDIT** : ajouter/retirer une valeur à `ZValidatorKind` (catalogue fermé AD-3) ; introduire une closure / une exécution dans `ZValidatorSpec` (doit rester `const` pur-données lisible par `ConstantReader`) ; importer un gestionnaire d'état ou un type backend dans le cœur ; modifier un autre package (dont `zcrud_generator`) ; toucher DODLP (lecture seule) ; toucher le sprint-status.

## Décisions de conception (à respecter — lèvent toute ambiguïté)

- **D1 — Politique password paramétrable, DÉFAUT aligné DODLP (permissif), STRICT opt-in.** `ZValidatorSpec.password` gagne des paramètres nommés `const` avec défauts DODLP :
  ```
  const ZValidatorSpec.password({
    int minLength = 8,
    int maxLength = 20,
    bool requireUppercase = true,
    bool requireLowercase = true,
    bool requireDigit = false,
    bool requireSpecial = false,
    String? errorText,
  })
  ```
  **Pour/contre du choix « défaut = politique DODLP » (assouplissement du défaut actuel — changement de comportement assumé)** :
  - **Pour** : (a) les `ZValidatorSpec` sont **projetés par le générateur depuis les modèles DODLP** — aligner le défaut sur DODLP restaure la parité **sans réécriture des annotations** et supprime le rejet silencieux de mots de passe DODLP valides (objectif exact de M10) ; (b) `maxLength=20` colle à DODLP (vs 32 fbv) ; (c) la sécurité forte n'est pas perdue, elle est **explicitement opt-in** (le champ le plus visible dans le code appelant), ce qui est plus honnête qu'un défaut « fort » silencieusement incompatible avec les données existantes.
  - **Contre** : un appelant qui comptait implicitement sur le défaut **fort** de `form_builder_validators` obtient désormais une validation **plus laxiste** sans le voir. **Mitigations** : (i) politique stricte restaurable en une ligne (`password(requireDigit: true, requireSpecial: true, minLength: 12, maxLength: 64)`) ; (ii) changement **documenté** au Change Log + Dev Notes + code-review ; (iii) le seul test verrouillant l'ancien défaut est **mis à jour** intentionnellement (aucun appelant applicatif ne dépend du défaut fort à ce jour — cf. grep §Dev Notes).
- **D2 — Mapping compiler password.** `requireX` (bool) → `min<X>Count = requireX ? 1 : 0` :
  ```
  FormBuilderValidators.password(
    minLength: spec.minLength, maxLength: spec.maxLength,
    minUppercaseCount: spec.requireUppercase ? 1 : 0,
    minLowercaseCount: spec.requireLowercase ? 1 : 0,
    minNumberCount:    spec.requireDigit     ? 1 : 0,
    minSpecialCharCount: spec.requireSpecial ? 1 : 0,
    errorText: e,
  )
  ```
  (`form_builder_validators-11.3.0` `PasswordValidator` accepte un compte `0` = exigence désactivée.)
- **D3 — `address`/`percentage` = NO-OP par défaut, contrainte OPT-IN.**
  - `ZValidatorSpec.address({bool enforceFormat = false, String? errorText})`. Compiler : `enforceFormat == false` ⇒ `_compileOne` **renvoie `null`** (aucun validateur produit — parité DODLP, rôle indice de clavier seul) ; `enforceFormat == true` ⇒ `FormBuilderValidators.street(errorText: e)` (opt-in, comportement historique).
  - `ZValidatorSpec.percentage({bool enforceRange = false, num min = 0, num max = 100, String? errorText})`. Compiler : `enforceRange == false` ⇒ **`null`** (no-op) ; `enforceRange == true` ⇒ `FormBuilderValidators.between<String>(spec.rangeMin, spec.rangeMax, errorText: e)` (opt-in ; défaut de plage 0–100 conservé).
  - **Pour** : restaure exactement la parité DODLP (aucune validation de format/plage imposée). **Contre** : un consommateur zcrud qui bénéficiait de l'auto-validation la perd silencieusement → **Mitigation** : opt-in explicite (`enforceFormat: true` / `enforceRange: true`), documenté ; l'indice de saisie reste porté par la famille/config du champ.
- **D4 — Catalogue FERMÉ (AD-3).** Aucune valeur ajoutée/retirée à `ZValidatorKind`. Les nouveaux paramètres sont des **champs de données** sur `ZValidatorSpec`, pas de nouvelles familles. La (dé)sérialisation reste un mapping `enum ⇄ camelCase` fermé.
- **D5 — Pur-données / const-safe (AD-3).** Les nouveaux champs sont `final` de types `const`-compatibles (`int`, `num`, `bool`, `String?`). **Aucune closure, aucun `RegExp`, aucune exécution** dans `ZValidatorSpec` (les `RegExp` de politique vivent dans `form_builder_validators`, côté compiler, jamais dans la spec). Toutes les fabriques restent `const`. `==`/`hashCode`/`toString` intègrent les nouveaux champs.
- **D6 — Défensif (AD-10).** `ZValidatorCompiler.compile` ne **lève jamais** : un paramètre incohérent (`minLength > maxLength`, compte négatif impossible car dérivé d'un `bool`, `rangeMin > rangeMax`) produit au pire un validateur qui **refuse** proprement (message), **jamais** une exception. `compile` sur une liste sans validateur champ-local (ex. uniquement `address`/`percentage` no-op) ⇒ `null` (contrat existant préservé : aucune surcharge du champ).
- **D7 — l10n additive.** Ajout d'une clé générique `invalidPassword` (en + fr) à `ZcrudLocalizations`, **additive** (aucune suppression). Le message de politique password par défaut est **résoluble via l10n** : lorsqu'aucun `errorText` n'est fourni à la fabrique, le message affiché doit pouvoir provenir de `ZcrudLocalizations` (clé `invalidPassword`), avec **repli défensif** sur `invalidValue` puis sur le message localisé de `form_builder_validators` — sans jamais dépendre obligatoirement de `FormBuilderLocalizations`. La résolution `errorText → l10n` s'effectue au **point d'appel disposant d'un `BuildContext`** (le compiler restant statique) : voir §Points de contact. Si le câblage l10n complet dépasse le seam existant, livrer **au minimum** la clé additive (en+fr) + le repli, et consigner l'écart en Dev Notes.

## Acceptance Criteria

1. **`ZValidatorSpec.password` paramétrable, défaut = politique DODLP, catalogue fermé.** La fabrique `const ZValidatorSpec.password` accepte `minLength` (défaut **8**), `maxLength` (défaut **20**), `requireUppercase` (défaut **true**), `requireLowercase` (défaut **true**), `requireDigit` (défaut **false**), `requireSpecial` (défaut **false**), `errorText`. Les valeurs sont portées par des champs `final` `const`-compatibles sur `ZValidatorSpec` ; `==`/`hashCode`/`toString` les intègrent. `ZValidatorKind` est **inchangé** (aucune valeur ajoutée/retirée). `ZValidatorSpec` reste `const` pur-données (aucune closure/`RegExp`/exécution). Test : deux `password(...)` de mêmes paramètres sont `==` et de même `hashCode` ; des paramètres différents ⇒ non égaux.

2. **Défaut password accepte les mots de passe DODLP-valides (M10).** Compilé sans paramètre (`const ZValidatorSpec.password(errorText: 'E')`), le validateur **accepte** un mot de passe DODLP-valide **sans chiffre ni caractère spécial** (ex. `Abcdefgh` — 8 car., maj+min) et rejette : `Abcdefg` (< 8), une chaîne de 21+ car., une chaîne sans majuscule (`abcdefgh`), une chaîne sans minuscule (`ABCDEFGH`). Test explicite sur ces 5 cas (le cas `Abcdefgh` échouait avec l'ancien défaut fbv → non-régression **positive** de parité).

3. **Politique stricte opt-in.** `password(minLength: 12, requireDigit: true, requireSpecial: true)` **rejette** `Abcdefgh` (trop court, sans chiffre/spécial) et **accepte** un mot de passe satisfaisant la politique stricte (ex. `Abcdefgh1!xy`). Test des deux branches.

4. **`address` non bloquant par défaut, format opt-in (M11).** `const ZValidatorSpec.address()` compile en **aucun validateur** (`_compileOne` → `null`) : une adresse partielle / `@@@` / une valeur quelconque est **acceptée** (le champ n'a aucune surcharge de validation de format). `ZValidatorSpec.address(enforceFormat: true, errorText: 'E')` → `FormBuilderValidators.street` : rejette `@@@`, accepte `123 Main Street`. Test des deux branches (dont : une liste ne contenant qu'une `address()` par défaut ⇒ `compile` renvoie `null`).

5. **`percentage` non bloquant par défaut, plage opt-in (M11).** `const ZValidatorSpec.percentage()` compile en **aucun validateur** : `150`, `-5`, `abc` sont **acceptés**. `ZValidatorSpec.percentage(enforceRange: true, errorText: 'E')` → `between(0,100)` : rejette `150`, accepte `50`/`0`/`100`. La plage est surchargeable (`percentage(enforceRange: true, min: 10, max: 90)` rejette `95`). Test de ces branches.

6. **Catalogue `ZValidatorKind` fermé (AD-3) + pur-données.** L'enum `ZValidatorKind` conserve exactement ses 20 valeurs (test d'inventaire : `ZValidatorKind.values.length` et l'ensemble des noms inchangés). `ZValidatorSpec` reste instanciable en contexte `const` (test : `const ZValidatorSpec.password(...)`, `const ZValidatorSpec.address(enforceFormat: true)`, `const ZValidatorSpec.percentage(enforceRange: true, min: 0, max: 50)` compilent).

7. **Défensif AD-10 — `compile` ne lève jamais.** `ZValidatorCompiler.compile` n'émet aucune exception pour des paramètres incohérents (`password(minLength: 30, maxLength: 10)`, `percentage(enforceRange: true, min: 100, max: 0)`) : au pire le validateur **refuse** proprement (retourne le message), jamais de throw. Une liste réduite à des specs no-op (`address()`/`percentage()` par défaut) ⇒ `compile` renvoie `null`.

8. **Rétro-compatibilité (fabriques + sérialisation).** Toutes les fabriques `ZValidatorSpec` existantes restent disponibles et `const` ; tous les appels historiques `const ZValidatorSpec.password()/.address()/.percentage()` **compilent inchangés** (nouveaux paramètres optionnels). Le test `edition_field_type_test.dart:124-126` reste **vert**. Les deux changements de comportement (défaut password assoupli ; `address`/`percentage` no-op par défaut) sont **intentionnels** et **documentés** (Change Log + Dev Notes) ; les assertions de `z_validator_compiler_test.dart:125-141` sont **réécrites** en conséquence (défaut DODLP / opt-in), sans supprimer la couverture (les branches opt-in couvrent l'ancien comportement `street`/`between`).

9. **l10n additive (D7).** Une clé `invalidPassword` est ajoutée aux maps `en` **et** `fr` de `ZcrudLocalizations` (additive, aucune suppression). Le message de politique password par défaut (sans `errorText` explicite) est **résoluble** via `ZcrudLocalizations` avec **repli défensif** (`invalidValue` puis message fbv), sans dépendance obligatoire à `FormBuilderLocalizations`. Test : la map `fr` contient `invalidPassword`, la map `en` aussi ; le repli n'échoue pas quand la clé est absente d'un registre `ZcrudLabels` surchargé.

10. **Aucune régression cœur / architecture.** Aucun import de gestionnaire d'état ou de type backend ajouté ; `ZValidatorCompiler` reste **statique/pur** (aucun `BuildContext`, résultat mémoïsable, identité stable — AD-2) ; le contrat « liste vide ⇒ `null` », « une seule spec ⇒ renvoyée telle quelle », « plusieurs ⇒ `compose` dans l'ordre » est préservé. Les suites d'édition existantes (`field_validation_test.dart`, `z_validator_compiler_test.dart` mis à jour, `cross_field_validator_test.dart`, `sm1_with_validation_test.dart`, `validation_targeted_dispatch_test.dart`, `edition_field_type_test.dart`) restent **vertes**. Le graphe reste acyclique / cœur out-degree 0.

## Testing Requirements

Emplacement : `packages/zcrud_core/test/` (`flutter_test`). Suivre les patterns existants de `z_validator_compiler_test.dart` (helpers `v(spec)` = compile d'une spec seule, `checks(name, spec, valid:, invalid:, msg:)`) et `edition_field_type_test.dart` (const/==/hashCode/inventaire d'enum).

Cas obligatoires :
- **Domaine `ZValidatorSpec`** (`test/domain/edition/`) : const-instanciation des fabriques enrichies (AC6) ; `==`/`hashCode` password (mêmes 6 params ⇔ égal ; diff ⇒ non égal) ; idem `address(enforceFormat:)` et `percentage(enforceRange:, min:, max:)` ; inventaire `ZValidatorKind.values` inchangé (AC6).
- **Password défaut DODLP (AC2)** : les 5 cas de l'AC2 (`Abcdefgh` accepté ; `Abcdefg`, 21+ car., sans-maj, sans-min rejetés).
- **Password strict opt-in (AC3)** : `Abcdefgh` rejeté ; mot de passe strict-valide accepté.
- **Address (AC4)** : défaut ⇒ `compile([address()])` renvoie `null` ; `@@@` accepté (aucune surcharge) ; `enforceFormat: true` ⇒ rejette `@@@`, accepte `123 Main Street`.
- **Percentage (AC5)** : défaut ⇒ `150`/`-5`/`abc` acceptés, `compile([percentage()])` renvoie `null` ; `enforceRange: true` ⇒ rejette `150`, accepte `50/0/100` ; plage surchargée `min:10,max:90` rejette `95`.
- **Défensif (AC7)** : `password(minLength: 30, maxLength: 10)` et `percentage(enforceRange: true, min: 100, max: 0)` ⇒ `compile` ne lève pas ; liste no-op ⇒ `null`.
- **Composition (AC10)** : `compile([required(), password()])` ⇒ compose dans l'ordre (échec au premier non satisfait) ; `compile([address(), percentage()])` (deux no-op) ⇒ `null` (aucune surcharge).
- **l10n (AC9)** : `invalidPassword` présent en `en` et `fr` ; repli défensif quand absent d'un `ZcrudLabels` surchargé.
- **Réécriture ciblée** : mettre à jour `z_validator_compiler_test.dart:125-141` (les 3 tests `address`/`percentage`/`password`) vers le nouveau comportement ; **conserver** la couverture de `street`/`between` via les branches opt-in.

## Points de contact « cœur partagé » à signaler (SÉRIALISATION / CROSS-STORY — lock core sériel)

- **`z_validator_spec.dart` (domaine) et `z_validator_compiler.dart` (présentation) sont des surfaces `zcrud_core` PARTAGÉES** (validation transverse, touchée par toute story ajoutant un validateur). DP-16 est **strictement additive** (nouveaux paramètres nommés optionnels, aucune fabrique/champ existant renommé/supprimé, `ZValidatorKind` inchangé). **Sérialiser l'écriture de ces deux fichiers** : une seule story les modifie à la fois (aucune autre story en vol ne doit écrire `z_validator_spec.dart`/`z_validator_compiler.dart`).
- **`z_localizations.dart` est une surface l10n PARTAGÉE** (deux maps `en`/`fr`). Ajout **additif** de `invalidPassword` uniquement — pas de suppression, pas de réordonnancement. Sérialiser si une autre story ajoute une clé l10n en parallèle.
- **`z_edition_field.dart:111` (point d'appel `compile` + mémoïsation)** : si la résolution l10n de l'`errorText` password nécessite un `BuildContext` (D7), c'est le seam disposant du contexte. Modification **confinée et optionnelle** ; ne PAS transformer `ZValidatorCompiler` en dépendant du contexte (il doit rester statique/pur — AD-2). Point de contact à sérialiser si une autre story touche `z_edition_field.dart`.
- **`zcrud_generator` (HORS package, à VÉRIFIER — ne PAS modifier)** : `zcrud_model_generator.dart:388-389` projette `@ZcrudField.validators` en émettant l'expression `const` via `_emitConst`. Les paramètres ajoutés étant **nommés optionnels** sur des fabriques `const` existantes, la projection reste compatible ; **à confirmer par `melos run analyze` + tests de rétro-compat de sérialisation REPO-WIDE au gate d'epic** (une suppression/renommage de symbole public dans `zcrud_core` casserait `zcrud_generator` sans être vu par une vérif ciblée au seul `zcrud_core`).

## Definition of Done

- [x] AC1–AC10 satisfaits, vérifiés par tests.
- [x] `melos run generate` — **sans objet** (aucune annotation `@ZcrudModel`/`@ZcrudField`/`@JsonSerializable` ajoutée/modifiée ; enrichissement de fabriques `const` pur-données non impactant pour le codegen).
- [x] `dart analyze packages/zcrud_core` RC=0 (No issues found!).
- [x] `flutter test` (zcrud_core) RC=0 — **788** tests ; suites de validation mises à jour + nouveaux cas M10/M11.
- [ ] `melos run analyze` **REPO-WIDE** RC=0 — **différé au gate d'epic** (orchestrateur) : garde cross-package `zcrud_generator`. Vérif ciblée `zcrud_core` verte ; graph_proof ACYCLIQUE / cœur out-degree 0 rejoué (RC=0).
- [x] `ZValidatorKind` inchangé (20 valeurs, catalogue fermé AD-3, test d'inventaire) ; `ZValidatorSpec` reste `const` pur-données (aucune closure/`RegExp`) ; `ZValidatorCompiler` reste statique/pur (AD-2) et défensif (AD-10, ne lève jamais).
- [x] Changements de défaut (password / address / percentage) documentés (Change Log + Dev Notes) ; DODLP intact (lecture seule).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, mode accéléré lot groupé DP-14 ∥ DP-16, lock core sériel).

### Debug Log References

- `dart analyze packages/zcrud_core` → `No issues found!` (RC=0).
- `flutter test` (zcrud_core, suite complète) → `All tests passed!` **788** tests (RC=0).
- Suite ciblée DP-16 : `test/presentation/edition/z_validator_compiler_test.dart` (réécrite M10/M11 + nouveaux groupes) + `test/domain/edition/z_validator_spec_policy_test.dart` (nouveau) → verts.
- `python3 scripts/dev/graph_proof.py` → `ACYCLIQUE OK`, `CORE OUT=0 OK` (RC=0).

### Completion Notes List

- **⚠️ Version `form_builder_validators` confirmée = `11.3.0`** (résolu réellement pour `zcrud_core` via `pubspec.lock` ; cache contient aussi 9.1.0/11.2.0 mais NON résolus). L'API `PasswordValidator(minUppercaseCount/minLowercaseCount/minNumberCount/minSpecialCharCount)` de D2 est **exacte** ; un compte à `0` **désactive** l'exigence via les gardes `if (count > 0)` (vérifié dans `identity/password_validator.dart:64-71`). Le mapping D2 est donc appliqué tel quel.
- **AC1** ✅ `const ZValidatorSpec.password({minLength=8, maxLength=20, requireUppercase=true, requireLowercase=true, requireDigit=false, requireSpecial=false, errorText})`. Nouveaux champs `final` (`passwordMinLength/passwordMaxLength/requireUppercase/…`) `const`-compatibles ; `==`/`hashCode` (via `Object.hashAll`) les intègrent. Catalogue `ZValidatorKind` inchangé.
- **AC2** ✅ Défaut DODLP : `Abcdefgh` **accepté** ; `Abcdefg` (<8), 21 car., sans-maj, sans-min **rejetés**.
- **AC3** ✅ Strict opt-in : `password(minLength:12, requireDigit:true, requireSpecial:true)` rejette `Abcdefgh`, accepte `Abcdefgh1!xy`.
- **AC4** ✅ `address()` défaut ⇒ `_compileOne → null` (liste ⇒ `compile null`) ; `address(enforceFormat:true)` ⇒ `street` (rejette `@@@`).
- **AC5** ✅ `percentage()` défaut ⇒ `null` (150/-5/abc acceptés) ; `percentage(enforceRange:true)` ⇒ `between(0,100)` ; plage surchargeable (`min:10,max:90` rejette `95`).
- **AC6** ✅ `ZValidatorKind.values.length == 20` + ensemble de noms figé ; `const` en contexte compile-time vérifié.
- **AC7** ✅ Défensif : `password(minLength:30,maxLength:10)` et `percentage(enforceRange:true,min:100,max:0)` ⇒ `compile` **ne lève pas** (`returnsNormally`), refuse proprement ; liste no-op ⇒ `null`.
- **AC8** ✅ Fabriques existantes toujours `const` ; `edition_field_type_test.dart:124-126` reste vert ; assertions `z_validator_compiler_test.dart:125-141` réécrites (défaut DODLP / opt-in) **sans perdre** la couverture `street`/`between` (branches opt-in).
- **AC9** ✅ Clé `invalidPassword` ajoutée en+fr (additive) ; test de présence + repli défensif (clé inconnue ⇒ clé brute, jamais de throw). **Écart consigné (D7)** : le câblage complet `errorText password → l10n` au point d'appel `z_edition_field.dart:111` **n'est pas réalisé** (fichier hors périmètre de ce lot ; seam à `BuildContext` réservé à une story ultérieure). Livré au minimum = clé additive + repli, conforme à la clause de repli de D7.
- **AC10** ✅ `ZValidatorCompiler` reste statique/pur (aucun `BuildContext`, mémoïsable) ; contrats « liste vide ⇒ null », « une seule spec ⇒ telle quelle », « plusieurs ⇒ compose ordonné » préservés ; graphe acyclique / cœur out-degree 0.
- **Non-régression L1 (DP-12/13)** : DP-16 ne touche NI `z_field_spec.dart`, NI `dynamic_edition.dart` (readMode), NI `z_theme.dart` ; l'ajout l10n `invalidPassword` est additif (aucun réordonnancement des tokens `read*`/DP-13). Suites d'édition existantes (`field_validation_test`, `sm1_with_validation_test`, `cross_field_validator_test`, `validation_targeted_dispatch_test`, `edition_field_type_test`) restent vertes.

### File List

- `packages/zcrud_core/lib/src/domain/edition/z_validator_spec.dart` (modifié — fabriques `password`/`address`/`percentage` enrichies + 10 champs `final` + `==`/`hashCode`/`Object.hashAll`).
- `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart` (modifié — mapping M10 password paramétrable, M11 address/percentage no-op par défaut + opt-in).
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` (modifié — clé additive `invalidPassword` en+fr).
- `packages/zcrud_core/test/presentation/edition/z_validator_compiler_test.dart` (modifié — réécriture M10/M11 + groupes password/address/percentage/défensif/composition).
- `packages/zcrud_core/test/domain/edition/z_validator_spec_policy_test.dart` (nouveau — const/==/hashCode/inventaire + l10n `invalidPassword`).

## Dev Notes

- **Aucun appelant applicatif ne dépend du défaut password fort actuel** : `grep -rn "ZValidatorSpec.password\|ZValidatorSpec.address\|ZValidatorSpec.percentage" packages/` ne renvoie que des **tests** (`z_validator_compiler_test.dart`, `edition_field_type_test.dart`). L'assouplissement du défaut est donc sûr côté consommateurs actuels ; il faut juste **réécrire ces tests** (intentionnel).
- `form_builder_validators-11.3.0` `PasswordValidator` : `minLength=8, maxLength=32, minUppercaseCount=1, minLowercaseCount=1, minNumberCount=1, minSpecialCharCount=1` par défaut — un compte à **0** désactive l'exigence correspondante (d'où le mapping `requireDigit=false → minNumberCount:0`). Vérifier la version résolue dans `pubspec.lock` (11.3.0 attendu) ; l'API `password(...)` est stable entre 11.2 et 11.3.
- **Ne PAS** encoder de `RegExp` de politique dans `ZValidatorSpec` (casserait la constness et la lisibilité `ConstantReader`) : la politique est un **jeu de paramètres scalaires** ; la mécanique de vérification vit dans `form_builder_validators`, appelée par le compiler.
- Le contrat « spec sans validateur produit ⇒ `_compileOne` renvoie `null` » **existe déjà** (ex. `min` avec `refKey` déféré). Réutiliser ce chemin pour `address`/`percentage` no-op : renvoyer `null` (pas un validateur qui accepte tout — un `null` évite toute surcharge et reste cohérent avec « liste no-op ⇒ compile null »).
- l10n : réutiliser le mécanisme `ZcrudLocalizations`/`ZcrudLabels` (repli `resolve(key, fallback:)`). Ne PAS ajouter `flutter_localizations`.

## Project Context Reference

- Architecture : `_bmad-output/planning-artifacts/architecture/.../architecture.md` — **AD-3** (catalogue fermé, `reflectable` banni, pur-données `ConstantReader`), **AD-10** (désérialisation/validation défensive, jamais de throw), **AD-2** (compiler statique/pur, validateur mémoïsable), **AD-1** (cœur out-degree 0).
- Parité : `docs/dodlp-edition-parity-gap.md` — M10 (`:160`, `:209`), M11 (`:161`, `:210`).
- Référence DODLP (LECTURE SEULE) : `dodlp-otr/.../edition_screen.dart:712-742` (address/percentage/password).
- Précédents : DP-10 (dates — même discipline additive/const-safe sur la config) ; famille validation E2-4/E3-2 (`z_validator_spec.dart`, `z_validator_compiler.dart`).

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-07-11 | 0.1 | Story créée (bmad-create-story) — password paramétrable (défaut DODLP, strict opt-in, M10) + address/percentage no-op par défaut (format/plage opt-in, M11), périmètre zcrud_core, catalogue AD-3 fermé | create-story |
| 2026-07-11 | 0.2 | Implémentation (bmad-dev-story). **Changement de défaut assumé** : `password` défaut assoupli (politique DODLP permissive : maj+min, ni chiffre ni spécial, 8–20 car., `maxLength` 20 vs 32 fbv) ; `address`/`percentage` **no-op par défaut** (validation format/plage désormais opt-in `enforceFormat`/`enforceRange`). Rétro-compat des fabriques `const` préservée (nouveaux params nommés optionnels). Clé l10n additive `invalidPassword` (en+fr). Version fbv résolue confirmée `11.3.0`. Vérif verte : analyze RC=0, 788 tests RC=0, graph acyclique/core out=0. | dev-story |
