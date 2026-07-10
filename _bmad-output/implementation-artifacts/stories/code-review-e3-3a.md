# Code Review — Story E3-3a : Dispatcher de champs + familles de base

- **Story** : `_bmad-output/implementation-artifacts/stories/e3-3a-dispatcher-familles-base.md` (11 ACs, statut `review`)
- **Reviewer** : BMAD code-review adversarial (skill `bmad-code-review`, effort high)
- **Baseline** : `acc6a2138a437fd3d1c53886246fa3340c0b540f` (== HEAD ; travail E3-1/E3-2/E3-3a en arbre non commité — répertoire `edition/` non suivi)
- **Date** : 2026-07-09
- **Verdict** : ✅ **APPROVED** — 0 HIGH, 0 MAJEUR, 0 MEDIUM. Findings LOW/nits + recommandations d'architecture uniquement.

---

## 1. Vérification verte rejouée RÉELLEMENT sur disque

| Contrôle | Commande | Résultat |
|---|---|---|
| Analyse | `dart analyze` (zcrud_core) | **RC=0** — « No issues found! » |
| Tests cœur | `flutter test` (zcrud_core) | **RC=0** — **255** passed |
| Tests workspace | `melos run test` | **RC=0** — **376** passed (annotations 8 + generator 80 + provider 8 + riverpod 8 + get 17 + core 255) |
| Gates de merge | `melos run verify` | **RC=0** — melos/reflectable/secrets/codegen/compat OK ; `verify:serialization` vert (packages sans tag `serialization-compat` → skip toléré) |
| Graphe | `graph_proof.py` | **CORE OUT=0 OK**, **ACYCLIQUE OK**, **14 nœuds**, 17 arêtes |
| `.g.dart` committés | `git status` | **0** (répertoire `edition/` = source pure, aucun généré) |

Non-régression E2-7/E2-9 + E3-1/E3-2 : suite complète cœur (255) verte, dont `sm1_full_form_test`, `sm1_with_validation_test`, `uj2_external_rebuild_test`, `controller_stability_test`, `mid_cursor_test`, `external_value_sync_test` — tous rejoués **à travers** le nouveau chemin de dispatch (le harnais `_reference_form.dart` route désormais via `ZFieldWidget`).

---

## 2. Vérification adversariale des points de vigilance

### 2.1 — 0 `default` (AC2) — VÉRIFIÉ ✅
- `familyOf` (`edition_field_family.dart`) est un `switch` **exhaustif SANS clause `default:`** couvrant les 39 valeurs. Les deux occurrences « default: » du dispatcher sont dans `_dispatch` (cases `hidden`/`unsupported` en fin de switch) ET commentaires — **aucune clause `default:` balayante**. Confirmé par lecture ligne à ligne (`edition_field_family.dart:60-120`, `z_field_widget.dart:150-197`).
- **Compilation-safe** : un futur `EditionFieldType` non classé casse la compilation de `familyOf` (switch exhaustif Dart 3). Prouvé côté runtime par `z_field_dispatch_test.dart` qui itère `EditionFieldType.values` (39) : 13 types de base → famille dédiée (jamais `unsupported`), 1 `hidden`, 25 « ailleurs » → repli. **Aucune famille de base ne tombe dans le repli** (assert `isNot(EditionFamily.unsupported)` sur les 13).

### 2.2 — SM-1 / UJ-2 À TRAVERS le dispatcher — VÉRIFIÉ ✅ (aucun rebuild global réintroduit)
- `ZFieldWidget` **réutilise** `ZFieldListenableBuilder` (E2-7) comme unique frontière de rebuild ; le dispatch (`_dispatch`) n'échange que le **sous-arbre interne** sous le slice. `DynamicEdition` n'observe QUE `controller.visibleFields` (canal structurel).
- `sm1_full_form_test` (rejoué, vert) : 100 frappes → `fieldBuilds[cible] == baseline+100`, **tous les voisins strictement inchangés**, `formBuilds` inchangé (=1), focus conservé à chaque frappe, curseur en fin (`selection.baseOffset==100`), valeur propagée. Non-vacuité confirmée (≥36 champs / 3 sections, assertions strictes).
- `uj2_dispatch_nontext_test` (AC9) : rebuild d'ancêtre → texte (saisie « PARTIEL » + focus) **et** non-texte (booléen/select) préservés via `KeyedSubtree`/`ValueKey`.
- **`TextEditingController` stable** : alloué 1× en `initState` **uniquement** pour les familles clavier (`familyUsesTextController` → texte/nombre) ; jamais recréé, `dispose` propre ; sync guardée hors focus (`_syncText` : write-back uniquement si `!hasFocus`). Les familles date/booléen/select/relation n'allouent aucun contrôleur.
- **L4 focus-change borné** (`l4_focus_change_test`) : A→B → transfert propre, `fieldBuilds[A]` borné (≤ +1 au blur), valeur+curseur de A intacts.

### 2.3 — Garde `KeyedSubtree` (L3/AC7) — VÉRIFIÉ ✅
`DynamicEdition._buildField` enveloppe **inconditionnellement** la sortie (dispatcher OU `fieldBuilder` custom) dans `KeyedSubtree(key: ValueKey(spec.name))` (`dynamic_edition.dart:146-155`). `keyed_subtree_guard_test` : builder custom SANS clé reste keyé, `initState==1` après 5 rebuilds d'ancêtre. **Non contournable.**

### 2.4 — a11y (AD-13/FR-23) — VÉRIFIÉ ✅
`field_a11y_test` monte les 6 familles et asserte `meetsGuideline(androidTapTargetGuideline)` (≥48 dp) **et** `textContrastGuideline` sur l'arbre réel (date-trigger forcé à 48 dp, `SwitchListTile`/`RadioListTile`/`CheckboxListTile` ≥48 dp, dropdowns). État sémantique booléen exposé (`Semantics.toggled==true`), libellés présents. Assertion non-vacuée (couvre chaque famille interactive).

### 2.5 — RTL (AD-13) — VÉRIFIÉ ✅
`field_rtl_test` : formulaire 6 familles sous `Directionality.rtl` sans overflow/exception + bascule LTR→RTL. `style_purity_test` (durci L-2/L-3, scan multi-lignes) **vert** sur tous les nouveaux fichiers `presentation/**` : **0** `EdgeInsets.only(left/right)`, `fromLTRB`, `Alignment.*Left/Right`, `TextAlign.left/right`, `Positioned(left/right)`, `BorderRadius.only/horizontal`, **0** couleur codée en dur. Usage exclusif `EdgeInsetsDirectional`/`AlignmentDirectional.centerStart`/thème hérité.

### 2.6 — Frontières E3-3a/b/c — RESPECTÉES ✅
Familles de base + `hidden` uniquement. Avancées/sous-listes/`stepper`/`widget`/fichier/image/document/markdown/géo/tél/`icon`/`custom` → repli `ZUnsupportedFieldWidget` (25 types, `find` = repli, `takeException()==null`, pas d'`ErrorWidget`). Aucun empiètement E3-3b/E3-3c/E3-5. Graphe inchangé (OUT=0).

---

## 3. Question d'architecture tranchée — `services.dart` / `inputFormatters`

**Ruling : NE PAS relâcher la garde maintenant. Classé LOW. Contournement robuste — validation NON dégradée.**

Vérification empirique du SDK (Flutter 3.44.4) :
- `TextInputType` (utilisé par `keyboardType`) est **re-exporté** par `widgets.dart`→`editable_text.dart` (`show … TextInputType …`) → visible sans import `services.dart` (c'est pourquoi le code compile).
- **`TextInputFormatter`/`FilteringTextInputFormatter` ne sont PAS dans cette `show`-list** ni re-exportés par `material.dart`/`widgets.dart`. Ils requièrent réellement `import 'package:flutter/services.dart'` — **banni** par `presentation_purity_test`. **La justification du dev est donc factuellement exacte** : l'omission n'est pas un oubli contournable.

Comportement réel du champ nombre sur entrée non-numérique (analyse du code `z_number_field_widget._parse`) :
- Saisie « abc » / « 42x » → `int.tryParse`/`num.tryParse` → **`null`** → `setValue(name, null)`. La tranche reçoit **`null`, jamais de valeur corrompue**. Le validateur `numeric`/`integer` mémoïsé signale l'invalidité (`AutovalidateMode.onUserInteraction`). Aucune exception.
- Seule dégradation : sur clavier physique (desktop/web) les caractères non-numériques restent **visuellement** saisis (le clavier numérique n'est qu'un indice) jusqu'au prochain rebuild hors-focus (où `_syncText` les efface, la tranche valant `null`). **Cosmétique**, pas de perte de donnée, validation intacte. Sur mobile le clavier numérique restreint déjà la saisie.

**Recommandation (LOW, suivi)** : relâcher la garde de pureté pour autoriser `TextInputFormatter`/`FilteringTextInputFormatter` (transformateurs **purs**, sans état — analogues à `form_builder_validators` déjà whitelisté en E3-2 ; **jamais** tout `services.dart` en bloc — whitelister par symbole ou par sous-chemin). À traiter en E3-3b ou dans une petite story « guard-relax ». Non bloquant pour E3-3a.

---

## 4. Findings (triage sévérité)

### HIGH / MAJEUR / MEDIUM
**Aucun.** Aucun rebuild global réintroduit, aucun `default` silencieux, aucune famille interactive sans a11y/RTL.

### LOW / nits (optionnels — consignés)

- **L-1 (a11y, `z_date_field_widget.dart:52-68`)** — Double `Semantics` : `Semantics(button: true, label: '$resolvedLabel: $display')` enveloppe un `OutlinedButton` dont le child `Text('$resolvedLabel : $display')` expose déjà rôle bouton + libellé → possible **double annonce** au lecteur d'écran. Incohérence cosmétique du séparateur (`: ` vs ` : `). Reco : `excludeSemantics: true` sur le wrapper OU supprimer le `Semantics` externe (le bouton suffit).
- **L-2 (UX, `z_number_field_widget.dart`)** — Absence d'`inputFormatters` (cf. §3) : entrée non-numérique visible transitoirement. Robuste (parse défensif + validateur), cosmétique. Reco : relâchement ciblé de la garde (voir §3).
- **L-3 (correctness latente, `z_select_field_widget.dart:64` / `z_relation_field_widget.dart:58`)** — `DropdownButtonFormField(initialValue:)` : un `FormField` ne relit `initialValue` qu'à l'`initState`. Un changement **programmatique** (externe) de la valeur de tranche après montage n'est PAS reflété visuellement par le dropdown (la sélection **par l'utilisateur** fonctionne, via `onChanged`). Hors périmètre strict d'AC9 (couvert par le booléen, qui relit `value` à chaque build). À surveiller en E4 (relation à valeur pilotée par la source).
- **L-4 (cohérence, `z_select_field_widget.dart:84`)** — `radio` en `readOnly` passe `onChanged: (_) {}` (no-op) au lieu de `null` → le groupe reste **visuellement interactif mais inerte**, incohérent avec `dropdown`/`checkbox` (qui passent `null` et se désactivent proprement). Reco : désactiver le `RadioGroup` en readOnly.

### Trous de couverture (aucun ne bloque ; à combler quand la famille sera exercée)

- **Relation avec source injectée** : le dispatcher construit `ZRelationFieldWidget` **sans** passer `options` → toujours vide/désactivé. Le chemin `options` non-vide (sélection + écriture de tranche + `enabled`) n'est **pas testé**. Acceptable (câblage source déféré E4), mais **aucun seam** n'existe encore pour injecter `options` via le dispatcher/`DynamicEdition` — à ajouter en E4.
- **Picker date/heure (interaction)** : `_pick`/`_parseTime`/format ISO (`toIso8601String`/`HH:mm`) non exercés au runtime (le RTL/a11y ne teste que le déclencheur, jamais le dialog). Gap le plus utile à combler (le `onChanged→ISO` est non couvert).
- **Nombre non-numérique** : le chemin `_parse→null` + erreur validateur non couvert au niveau widget (pertinent pour §3).
- **Checkbox multi** : `_toggle` (add/remove de la `List`) non exercé au runtime.
- **Select/radio à `choices` vide** : arête non testée (`values.contains(value)` sur liste vide).

---

## 5. Conformité AD (échantillon)

- **AD-2** : frontière de rebuild = tranche unique ; dispatch = sous-arbre interne seulement ; aucun `setState` formulaire ; contrôleur clavier stable. ✅
- **AD-13/FR-23** : directionnel exclusif, `Semantics`, ≥48 dp, l10n injectée (`label()` composition scope→delegate→`en`→fallback). ✅
- **AD-15** : aucun gestionnaire d'état ; `presentation_purity_test` vert (whitelist `material` + `form_builder_validators` ; `flutter/services.dart` toujours banni). ✅
- **AD-4** : repli contrôlé documenté comme point d'extension du futur registre de widgets (E3-3b) ; `ZTypeRegistry` non détourné. ✅
- **AD-1** : `zcrud_core` OUT=0, graphe acyclique, 14 packages. ✅

---

## 6. Décision

**APPROVED.** Les 11 ACs sont satisfaits et **re-prouvés réellement** à travers le chemin de dispatch (SM-1/UJ-2/L3/L4/a11y/RTL/exhaustivité 0-default/validation ciblée). Vérif verte intégrale rejouée sur disque (analyze RC=0, test 376 RC=0, verify RC=0, graphe CORE OUT=0, 0 `.g.dart`). Aucun finding HIGH/MAJEUR/MEDIUM. Les 4 nits LOW et les trous de couverture sont **optionnels** ; recommandé de tracer la relaxation ciblée de la garde `inputFormatters` (§3) et le seam d'injection `options` de la relation pour E3-3b/E4.
