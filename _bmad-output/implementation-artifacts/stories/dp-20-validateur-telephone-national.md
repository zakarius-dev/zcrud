---
baseline_commit: a64e3b37c3f85c15bbe2163f667a70183fd81b75
---

# Story DP-20 : Validateur téléphone national paramétrable (parité DODLP, gap M9)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **développeur intégrant zcrud dans une app à règle téléphonique nationale (ex. DODLP/Togo)**,
I want **un validateur de numéro national paramétrable (préfixes autorisés + longueur) exposé par `zcrud_intl`, en plus du `ZPhoneCodec` E.164 existant**,
so that **je puisse recréer une politique nationale stricte (ex. Togo : préfixes 90/77/… longueur fixe) sans « Togo » codé en dur et sans casser la normalisation E.164 générique**.

## Contexte & gap comblé

- **Gap M9 (MAJEUR)** — `docs/dodlp-edition-parity-gap.md:159,208` : DODLP porte un validateur téléphone Togo (`edition_screen.dart:675-700`, clé `tgPhoneNumber`) : **longueur == 11** et **préfixe** ∈ `{90,77,78,79,91,92,93,96,97,98,99,70,71}`. zcrud n'expose que `ZPhoneCodec` (E.164 générique) → **la règle nationale est perdue**.
- **Décision** (M9, périmètre imposé) : plutôt qu'étendre le catalogue **fermé** `ZValidatorKind` de `zcrud_core` (interdit — AD-1, périmètre `zcrud_intl` UNIQUEMENT), on livre un **validateur autonome pur-Dart dans `zcrud_intl`**, paramétrable (`prefixes` + `length`), défensif (AD-10), avec messages l10n côté présentation. **Additif** : aucune signature existante modifiée.
- **Neutralité (AD-12)** : **aucun** « Togo », préfixe ou longueur codé en dur non surchargeable. Le paramétrage Togo est fourni **en recette documentée**, pas en défaut du package.

### Nuance de portage FIDÈLE (à respecter à l'implémentation)

DODLP valide la **chaîne nationale FORMATÉE** (`intl_phone_number_input`), d'où `length == 11` : `"90 12 34 56"` = **11 caractères espaces compris** (`2+1+2+1+2+1+2`). En zcrud, `ZPhoneCodec.parse` renseigne `ZPhoneNumber.nationalNumber` en **chiffres nus** (Togo = **8 chiffres**). Le validateur est donc **générique** : il **normalise l'entrée** (option `digitsOnly`) et l'app choisit la longueur cible (`8` sur chiffres nus, ou `11` sur formaté). La recette Togo documente **les deux** politiques. Ne PAS coder 8 ni 11 dans le package.

## Acceptance Criteria

1. **AC1 — Validateur national paramétrable exposé par le barrel.** `zcrud_intl` expose un type public `ZNationalPhoneValidator` **`const`, pur-Dart** (couche `domain`, AD-14) construit avec au moins `prefixes: List<String>` et `length: int` (+ `required: bool = false`, `digitsOnly: bool = true`), exporté par `lib/zcrud_intl.dart`. Un numéro dont la partie nationale a la **bonne longueur** ET commence par **l'un des `prefixes`** est **valide** ; sinon **invalide** (avec un discriminant d'erreur distinguant longueur vs préfixe vs requis).
2. **AC2 — `ZPhoneCodec` E.164 inchangé (rétro-compat STRICTE).** Aucune modification de `src/presentation/z_phone_codec.dart` ni de `ZPhoneNumber` ni de la valeur de tranche : le champ `phoneNumber` E11a-2 continue de produire l'E.164 canonique **exactement** comme avant. Le nouveau validateur est **orthogonal** (opt-in) et **n'altère jamais** la valeur émise. Les tests existants (`z_phone_codec_test.dart`) restent **verts sans modification**.
3. **AC3 — Défensif AD-10 (jamais de throw).** `ZNationalPhoneValidator.validate(value)` accepte `null`, un `ZPhoneNumber`, une `Map` sérialisée OU une `String` brute, et **ne throw jamais**. Entrée `null`/vide → `required` (message) si `required==true`, sinon **valide** (`null`). Entrée non reconnue/malformée (type inattendu, caractères non numériques) → **normalisée défensivement** (extraction chiffres si `digitsOnly`) puis évaluée ; jamais d'exception, jamais de `null` non contrôlé propagé.
4. **AC4 — Messages l10n + a11y (présentation).** Un helper de **présentation** (Flutter, hors couche domaine) mappe le discriminant d'erreur vers un message **résolu via `label(context, key, fallback:)`** (clés `intl.phone.national.required` / `.invalidLength` / `.invalidPrefix`, repli **français** fourni, surchargeables via `ZcrudLabels` du scope — pas de table ajoutée à `zcrud_core`). Le message d'erreur est exposé au champ de sorte qu'il soit **annoncé par le lecteur d'écran** (via `InputDecoration.errorText`/sémantique native du `TextField`, cible ≥ 48 dp inchangée — AD-13).
5. **AC5 — Câblage opt-in dans le champ téléphone, additif & rétro-compat.** `ZIntlFieldConfig` reçoit un champ **`nationalPhone: ZNationalPhoneValidator?` (défaut `null`)**. `null` ⇒ comportement E11a-2/E11b-2 **identique** (aucune validation nationale, aucun message). Non-`null` ⇒ `ZPhoneFieldWidget` affiche le message d'erreur du validateur sous le champ numéro (voie de lecture seule, sans casser AD-2 : contrôleur stable, pas de recréation, pas de perte de focus). L'`==`/`hashCode` de `ZIntlFieldConfig` intègre le nouveau champ.
6. **AC6 — Neutralité / aucun secret (AD-12).** Aucun « Togo », aucun préfixe, aucune longueur, aucune clé/secret/endpoint codé en dur dans `zcrud_intl`. Le gate scan-secrets reste vert. La politique Togo n'existe **que** dans la doc de recette et les tests.
7. **AC7 — Recette Togo documentée & testée.** La doc de classe (dartdoc de `ZNationalPhoneValidator`) contient une **recette reproductible** de la politique Togo, couvrant les **deux** longueurs (`8` sur chiffres nus, `11` sur national formaté) avec la liste de préfixes DODLP, et un test unitaire **prouve** que la recette accepte les numéros DODLP valides et rejette longueur/préfixe hors-règle.
8. **AC8 — Isolation AD-1 préservée.** `ZNationalPhoneValidator` (domaine) **n'importe pas** `flutter`, ni `phone_numbers_parser`, ni `zcrud_core` autrement que pour `ZPhoneNumber`/`ZFieldConfig` déjà utilisés. Le gate d'isolation (`isolation_gates_test.dart`) reste vert ; aucun type de lib tierce ne fuit dans le barrel.

## Tasks / Subtasks

- [x] **T1 — Domaine : `ZNationalPhoneValidator`** (AC1, AC3, AC7, AC8) — `packages/zcrud_intl/lib/src/domain/z_national_phone_validator.dart`
  - [x] Enum `ZNationalPhoneError { required, invalidLength, invalidPrefix }` (discriminant neutre, sans message).
  - [x] Classe `const` `ZNationalPhoneValidator({ required List<String> prefixes, required int length, bool required = false, bool digitsOnly = true })`.
  - [x] `ZNationalPhoneError? validate(Object? value)` : extrait la partie nationale (`ZPhoneNumber.nationalNumber` | `String` | `Map` via `ZPhoneNumber.fromMapSafe`), normalise (chiffres seuls si `digitsOnly`), applique **longueur** puis **préfixe**. `null` ⇒ valide.
  - [x] Défensif AD-10 : `null`/vide → `required` si requis sinon `null` ; type inattendu → normalisation défensive, jamais de throw.
  - [x] `==`/`hashCode`/`toString` + `_listEq` (cf. `ZIntlFieldConfig`).
  - [x] Dartdoc **recette Togo** (préfixes DODLP + longueurs 8 chiffres nus / 11 formaté) — AC7.
- [x] **T2 — Présentation : helper de message l10n** (AC4) — `packages/zcrud_intl/lib/src/presentation/z_national_phone_message.dart`
  - [x] `String? nationalPhoneErrorText(BuildContext context, ZNationalPhoneError? error)` mappant vers `label(context, 'intl.phone.national.*', fallback: <fr>)`.
  - [x] Repli français : `required` → « Numéro de téléphone requis » ; `invalidLength` → « Numéro de téléphone incomplet » ; `invalidPrefix` → « Numéro de téléphone invalide » (fidèles à DODLP `edition_screen.dart:679/682/696`).
- [x] **T3 — Config additive** (AC5) — `z_intl_field_config.dart`
  - [x] Ajouter `final ZNationalPhoneValidator? nationalPhone;` (défaut `null`) au constructeur `const` + dartdoc (rétro-compat : `null` = pas de validation).
  - [x] Intégrer dans `==`/`hashCode`.
- [x] **T4 — Câblage champ téléphone opt-in** (AC5, AC4) — `z_phone_field_widget.dart`
  - [x] Lire `_config?.nationalPhone` ; si non-`null`, calculer l'erreur sur la valeur courante (texte du champ numéro) et passer `errorText: nationalPhoneErrorText(context, err)` à l'`InputDecoration` du champ numéro.
  - [x] **Ne PAS** recréer le contrôleur ni ré-injecter la valeur (AD-2) ; recalcul de l'erreur dans `build` uniquement (dérivé, pas d'état).
- [x] **T5 — Barrel** (AC1) — `lib/zcrud_intl.dart` : exporter `z_national_phone_validator.dart` et `z_national_phone_message.dart`.
- [x] **T6 — Tests** (AC1-AC8) — `packages/zcrud_intl/test/z_national_phone_validator_test.dart`
  - [x] Recette Togo (8 chiffres nus) : accepte `90123456`/`77123456`/… ; rejette longueur (`9012345`) et préfixe (`10123456`).
  - [x] Recette Togo (11 formaté, `digitsOnly:false`) : accepte `"90 12 34 56"` ; rejette `"90 12 34 5"`.
  - [x] Défensif AD-10 : `null`, `42`, `Map` sérialisée, `ZPhoneNumber` neutre → jamais de throw ; `required` respecté.
  - [x] `ZPhoneNumber` d'entrée (lecture `nationalNumber`).
  - [x] `==`/`hashCode` du validateur et de `ZIntlFieldConfig` (avec/sans `nationalPhone`).
  - [x] Widget : `nationalPhone` non-`null` invalide → `errorText` présent & annoncé ; `null` → aucun message (rétro-compat) ; SM-1 : frappe ne perd pas le focus.
  - [x] Isolation : le nouveau fichier domaine ajouté à la denylist pur-Dart d'`isolation_gates_test.dart` (n'importe pas `flutter`/`phone_numbers_parser`).

## Dev Notes

### État actuel des fichiers touchés (lecture faite)

- **`src/presentation/z_phone_codec.dart`** (READ) — pont **unique** vers `phone_numbers_parser`, `parse()` défensif renseigne `nationalNumber` (chiffres nus). **NE PAS MODIFIER** (AC2). Le validateur national lit `nationalNumber`, il ne re-parse pas.
- **`src/domain/z_phone_number.dart`** (READ) — modèle neutre pur-Dart ; `nationalNumber: String?` = source pour le validateur ; `fromMapSafe` défensif réutilisable pour AC3. **NE PAS MODIFIER**.
- **`src/domain/z_intl_field_config.dart`** (READ) — `ZFieldConfig` const, pattern `==`/`hashCode`/`_listEq` à suivre. **UPDATE** minimal additif (T3) : nouveau champ nullable défaut `null` (rétro-compat stricte, cf. dartdoc existant).
- **`src/presentation/z_phone_field_widget.dart`** (READ) — patron AD-2 : `_numberController`/`_numberFocus` créés 1× en `initState`, sync guardée hors focus, voie sens unique `_emit()`. **UPDATE** T4 : ajouter un `errorText` **dérivé** dans `build` (aucun état, aucun contrôleur recréé). `_config` déjà résolu via `ctx.field.config is ZIntlFieldConfig`.
- **l10n** : pas de table dans `zcrud_intl`. Utiliser `label(context, key, fallback:)` de `zcrud_core` (déjà importé, cf. `intl.phone.number`/`intl.phone.country`). Les clés `intl.phone.national.*` se résolvent par **repli `fallback`** (français) et restent **surchargeables** via `ZcrudScope(labels:)` — **ne pas** éditer `z_localizations.dart` (AD-1, périmètre zcrud_intl).

### Référence DODLP (LECTURE SEULE — ne rien modifier dans `/home/zakarius/DEV/dodlp-otr`)

`edition_screen.dart:675-700`, clé `tgPhoneNumber` :
- `value == null || isEmpty` → requis ? « Numero de téléphone requis » : ok.
- `value.length != 11` → « Numéro de téléphone incomplet ».
- `!startsWith` ∈ `{90,77,78,79,91,92,93,96,97,98,99,70,71}` → « Numéro de téléphone invalide ».
- Ordre d'évaluation **requis → longueur → préfixe** (à reproduire pour parité des messages).
- `length==11` = chaîne **formatée** (espaces) ; sur chiffres nus zcrud, longueur = **8** (cf. nuance ci-dessus).

### Recette Togo documentée (à placer en dartdoc de `ZNationalPhoneValidator` — AC7)

```dart
// Politique nationale Togo (parité DODLP tgPhoneNumber), NEUTRE et surchargeable.
// Variante A — sur la partie nationale en CHIFFRES NUS (ZPhoneNumber.nationalNumber) :
const togoNationalPhone = ZNationalPhoneValidator(
  prefixes: ['70', '71', '77', '78', '79', '90', '91', '92', '93', '96', '97', '98', '99'],
  length: 8,            // 8 chiffres nus
  required: true,
  // digitsOnly: true (défaut) : "90 12 34 56" est normalisé en "90123456".
);
// Variante B — FIDÈLE à DODLP sur la chaîne nationale FORMATÉE ("90 12 34 56") :
const togoNationalPhoneFormatted = ZNationalPhoneValidator(
  prefixes: ['70', '71', '77', '78', '79', '90', '91', '92', '93', '96', '97', '98', '99'],
  length: 11,           // 11 caractères, espaces compris
  required: true,
  digitsOnly: false,
);
// Câblage : ZIntlFieldConfig(nationalPhone: togoNationalPhone) posé sur ZFieldSpec.config.
```

### Invariants AD à respecter

- **AD-1** : `zcrud_intl → zcrud_core` uniquement ; domaine sans `flutter`/`phone_numbers_parser` (AC8).
- **AD-2** : câblage widget sans recréation de contrôleur, sans perte de focus (SM-1).
- **AD-4** : extension par `ZIntlFieldConfig` (slot config additif), pas d'héritage sérialisé, pas de modif du cœur.
- **AD-10** : `validate` défensif total (AC3).
- **AD-12** : zéro défaut national codé en dur, zéro secret (AC6).
- **AD-13** : message annoncé, cibles ≥ 48 dp, directionnel (`TextAlign.start` déjà en place).
- **AD-14** : couche `domain` pur-Dart.

### Project Structure Notes

- Nouveaux fichiers : `lib/src/domain/z_national_phone_validator.dart`, `lib/src/presentation/z_national_phone_message.dart`, `test/z_national_phone_validator_test.dart`.
- Modifs additives : `lib/src/domain/z_intl_field_config.dart`, `lib/src/presentation/z_phone_field_widget.dart`, `lib/zcrud_intl.dart`.
- **Périmètre `zcrud_intl` UNIQUEMENT** — package satellite disjoint, parallélisable avec les stories core (aucune écriture dans `zcrud_core`, aucune arête nouvelle du graphe).

### Testing standards

- `flutter test` par package ; widgets via `WidgetTester` ; a11y via `test/support/a11y_asserts.dart` (pattern existant). Vérif verte : `melos run generate` → `analyze` RC=0 → `flutter test` RC=0.

### References

- [Source: docs/dodlp-edition-parity-gap.md#2.5 (ligne 140), #3 MAJOR M9 (lignes 159, 208)]
- [Source: /home/zakarius/DEV/dodlp-otr/.../edition_screen.dart:675-700 (tgPhoneNumber, LECTURE SEULE)]
- [Source: packages/zcrud_intl/lib/src/presentation/z_phone_codec.dart (E.164, inchangé — AC2)]
- [Source: packages/zcrud_intl/lib/src/domain/z_phone_number.dart (nationalNumber, fromMapSafe défensif)]
- [Source: packages/zcrud_intl/lib/src/domain/z_intl_field_config.dart (slot config additif AD-4)]
- [Source: packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart (patron AD-2)]
- [Source: packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart (helper `label(context, key, fallback:)`)]
- [Source: _bmad-output/planning-artifacts/architecture/.../architecture.md (AD-1/2/4/10/12/13/14)]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, effort high).

### Debug Log References

- `dart analyze packages/zcrud_intl` → **RC=0** (No issues found).
- `flutter test packages/zcrud_intl` → **RC=0** (169 tests OK, dont 38 nouveaux DP-20).
- `python3 scripts/dev/graph_proof.py` → **RC=0** (ACYCLIQUE OK, CORE OUT=0).
- Pas de codegen requis (aucune annotation `@ZcrudModel`/`@JsonSerializable` ajoutée).

### Completion Notes List

- **AC1** ✅ `ZNationalPhoneValidator` `const` pur-Dart (`prefixes` + `length` requis, `required=false`, `digitsOnly=true`), exporté par le barrel ; discriminant `ZNationalPhoneError { required, invalidLength, invalidPrefix }`.
- **AC2** ✅ `z_phone_codec.dart`/`ZPhoneNumber` **inchangés** ; `z_phone_codec_test.dart` vert sans modification ; le validateur est orthogonal (n'altère jamais la valeur émise).
- **AC3** ✅ `validate(Object?)` défensif total : `null`/vide → `required` si requis sinon `null` ; `int`/type inattendu, `Map`, `String` non numérique → normalisation défensive, **jamais de throw** (test `returnsNormally`).
- **AC4** ✅ `nationalPhoneErrorText` (présentation) → `label(context, 'intl.phone.national.*', fallback:<fr>)`, surchargeable via le scope, annoncé par la sémantique native du `TextField` (`errorText`), aucune table ajoutée au cœur.
- **AC5** ✅ `ZIntlFieldConfig.nationalPhone` (défaut `null`, intégré à `==`/`hashCode`) ; `ZPhoneFieldWidget` calcule un `errorText` **dérivé** en `build` (aucun contrôleur recréé, focus préservé — SM-1) ; `null` ⇒ comportement E11a-2/E11b-2 identique.
- **AC6** ✅ Aucun « Togo »/préfixe/longueur/secret dans `lib/` (politique Togo dans doc + tests uniquement) ; gate secrets vert.
- **AC7** ✅ Recette Togo (variantes A chiffres nus length 8 / B formaté length 11) en dartdoc + tests prouvant acceptation des numéros DODLP et rejet longueur/préfixe.
- **AC8** ✅ Domaine sans `flutter`/`phone_numbers_parser`/`zcrud_core` (importe seulement `z_phone_number.dart`) ; fichier ajouté à la denylist pur-Dart d'`isolation_gates_test.dart` ; gate confinement `phone_numbers_parser` (1 seul importeur) vert.
- Périmètre strict `packages/zcrud_intl` ; **aucune** écriture dans `zcrud_core`/DODLP ; graphe inchangé (`zcrud_intl → zcrud_core`, AD-1).

### File List

- `packages/zcrud_intl/lib/src/domain/z_national_phone_validator.dart` (nouveau)
- `packages/zcrud_intl/lib/src/presentation/z_national_phone_message.dart` (nouveau)
- `packages/zcrud_intl/test/z_national_phone_validator_test.dart` (nouveau)
- `packages/zcrud_intl/lib/src/domain/z_intl_field_config.dart` (modifié — champ `nationalPhone` additif)
- `packages/zcrud_intl/lib/src/presentation/z_phone_field_widget.dart` (modifié — `errorText` opt-in dérivé)
- `packages/zcrud_intl/lib/zcrud_intl.dart` (modifié — exports)
- `packages/zcrud_intl/test/isolation_gates_test.dart` (modifié — denylist pur-Dart AC8)
