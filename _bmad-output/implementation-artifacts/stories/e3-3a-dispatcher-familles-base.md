---
baseline_commit: acc6a2138a437fd3d1c53886246fa3340c0b540f
---
# Story 3.3a : Dispatcher de champs + familles de base

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a développeur intégrant zcrud,
I want un **dispatcher de champ par type** qui rend, pour chaque `EditionFieldType` des **familles de base** (texte, nombre, date, booléen, select, relation), le widget d'édition approprié — accessible, RTL-correct — en **réutilisant intégralement** la machinerie de tranche (slice) et de validation d'E3-1/E3-2,
so that un formulaire dérivé du schéma affiche le bon contrôle par type sans jamais retomber dans un rendu par défaut inadapté, tout en préservant l'objectif produit n°1 (rebuilds granulaires, focus/curseur intacts — SM-1/UJ-2).

## Contexte

E3-1 (`e3-1-rendu-champ-tranche.md`, **done**) a livré `DynamicEdition` + `ZEditionField` : un champ = un widget top-level scellé sur **sa seule tranche** via `ZFieldListenableBuilder` (helper E2-7), `ValueKey(field.name)`, `ListView.builder`, **zéro `setState` global**. Le rendu est **volontairement type-agnostique** : un `TextFormField` uniforme, `EditionFieldType` **non dispatché**. Un **seam** est prêt : `DynamicEdition.fieldBuilder` (`typedef ZEditionFieldBuilder`) et le commentaire de `ZEditionField` désigne explicitement E3-3a comme responsable d'« échanger le rendu **interne** sans toucher ni la machinerie de tranche, ni le contrat de stabilité, ni la compilation de validateurs ».

E3-2 (`e3-2-controllers-keys-stables.md`, **done**) a durci la stabilité : `TextEditingController`/`FocusNode`/validateur en `late final` (créés 1×, `dispose`), **sync guardée** hors focus (aucune ré-injection pendant l'édition — FR-1), `AutovalidateMode.onUserInteraction` **par champ**, `ZValidatorCompiler` (barrel public) qui mémoïse le `FormFieldValidator<String>?`.

**E3-3a REMPLACE le rendu uniforme d'E3-1/E3-2 par un DISPATCHER par type pour les familles de base**, en **réutilisant** (jamais réécrivant) : `ZFieldListenableBuilder`, la stabilité controller/key, `ZValidatorCompiler`. Le dispatcher échange le **rendu du contrôle interne** (le sous-arbre sous le slice), pas la frontière de rebuild.

`EditionFieldType` (E2-4/E2-5, **39 valeurs**, `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart`) couvre bien au-delà des familles de base : sous-listes, fichiers, géo, téléphone, markdown, etc. **E3-3a ne traite QUE les familles de base** ; tout le reste est soit renvoyé à E3-3b/E3-3c, soit servi « ailleurs » via `ZTypeRegistry` (E6/E11a), et **doit dégrader proprement (fallback contrôlé), jamais planter**.

### Frontière E3-3a / E3-3b / E3-3c (DÉCIDÉE)

Classification **exhaustive** des 39 `EditionFieldType` (source de vérité pour le test d'exhaustivité) :

| Famille / destination | `EditionFieldType` | Traité par |
|---|---|---|
| **texte** (base) | `text`, `multiline`, `password` (masqué : `obscureText`) | **E3-3a** — widget dédié |
| **nombre** (base) | `number`, `integer`, `float` | **E3-3a** — widget dédié |
| **date** (base) | `dateTime`, `time` | **E3-3a** — widget dédié |
| **booléen** (base) | `boolean` | **E3-3a** — widget dédié |
| **select** (base) | `select`, `radio`, `checkbox` | **E3-3a** — widget dédié |
| **relation** (base) | `relation` | **E3-3a** — widget dédié (abstraction ; source runtime déférée E4) |
| **non rendu** | `hidden` | **E3-3a** — rend `SizedBox.shrink()` (zéro-taille, jamais un crash) |
| avancées & sous-listes | `subItems`, `dynamicItem`, `tags`, `rowChips`, `rating`, `slider`, `signature`, `color`, `widget`, `stepper` | **E3-3b** (`stepper`→E3-5) — fallback contrôlé ici |
| fichier / image / document | `file`, `image`, `document` | **E3-3c** — fallback contrôlé ici |
| widget « ailleurs » (registre) | `markdown`, `inlineMarkdown`, `html`, `inlineHtml`, `richText` (→E6) ; `location`, `geoArea`, `phoneNumber`, `country`, `address` (→E11a) ; `icon` (hors parité MVP) ; `custom` (AD-4, `ZTypeRegistry`) | servi **ailleurs** via `ZTypeRegistry` (E3-3b/registry) — **fallback contrôlé** ici, jamais un crash |

> **Note relation.** E3-3a livre l'**abstraction** du sélecteur d'entité liée (contrat + rendu d'un champ de sélection lisant/écrivant la tranche) ; le câblage de la **source** (repository/stream) est un port E2-2 résolu au runtime en **E4** (jamais dans l'annotation `const`, cf. doc de `EditionFieldType.relation`). Le widget E3-3a rend un contrôle de sélection accessible avec une source **injectable** (défaut : liste vide / placeholder l10n), sans dépendre de E4.

## Acceptance Criteria

1. **Un widget dédié par famille de base.** Pour chacune des 6 familles — **texte** (`text`/`multiline`/`password`), **nombre** (`number`/`integer`/`float`), **date** (`dateTime`/`time`), **booléen** (`boolean`), **select** (`select`/`radio`/`checkbox`), **relation** (`relation`) — le dispatcher rend un widget d'édition **spécifique et adapté** (p. ex. `TextFormField` clavier texte, champ numérique à `keyboardType`/formatters + validateur numérique, contrôle de date via picker directionnel, `Switch`/`Checkbox`, `DropdownButtonFormField`/radios/cases depuis `ZFieldChoice`, sélecteur d'entité liée). Test : chaque type de base → le type de widget attendu (jamais le fallback).

2. **Zéro `default` pour les familles de base.** Le dispatch est un **`switch` exhaustif** sur `EditionFieldType` **sans clause `default:` balayant les familles de base** : aucun type de base ne tombe dans un fallback. L'exhaustivité est prouvée par un test qui **itère `EditionFieldType.values`** (39) et vérifie que chacun des types de base produit son widget dédié (0 fallback). *(Recommandé : switch exhaustif Dart 3 sans `default`, pour qu'un futur `EditionFieldType` **casse la compilation** tant qu'il n'est pas classé.)*

3. **Fallback contrôlé pour l'« ailleurs », jamais un crash.** Tout type non-base (E3-3b/E3-3c, markdown/géo/tél/`icon`/`custom`, `widget`) rend un **widget de repli explicite** (p. ex. `ZUnsupportedFieldWidget`) — placeholder accessible (libellé du champ + indication l10n « type non pris en charge ici »), **sans lever d'exception** et sans casser le formulaire. Test : monter un champ de chaque type non-base ne jette **aucune** exception et produit le widget de repli (pas un `ErrorWidget`, pas un throw). Point d'extension documenté : E3-3b branchera un **registre de widgets** (aligné sur `ZTypeRegistry`) pour remplacer ce repli par le vrai widget hôte.

4. **`hidden` ne rend rien.** Un champ `hidden` rend `SizedBox.shrink()` (widget zéro-taille), **jamais** un crash ni un repli visible. Test dédié.

5. **A11y par widget (AD-13/FR-23).** Chaque widget de famille de base porte des **`Semantics` explicites** (libellé lié à `field.label`/`field.name`, rôle/état pour booléen et select) et des **cibles tactiles ≥ 48 dp** (contrôles interactifs : switch, cases, boutons de picker, dropdown). Test a11y de référence : pour un formulaire couvrant les 6 familles, `SemanticsNode`/`meetsGuideline(androidTapTargetGuideline)` et présence de labels sémantiques vérifiés.

6. **RTL par widget (AD-13).** (a) Rendu sous `Directionality(textDirection: TextDirection.rtl)` correct pour chaque famille (test widget rtl : pas d'overflow, alignements cohérents). (b) **0 usage non-directionnel** : la garde `style_purity_test.dart` (motifs `EdgeInsets.only(left/right`, `EdgeInsets.fromLTRB`, `Alignment.*Left/Right`, `TextAlign.left/right`, `Positioned(left/right`, `BorderRadius.only/horizontal`) reste **verte** sur **tous** les nouveaux fichiers `lib/src/presentation/**` ; usage exclusif d'`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start-end`/`PositionedDirectional`. Aucun style/couleur codé en dur (thème via `Theme.of`/`ZcrudTheme` — FR-26).

7. **Garde `KeyedSubtree` (finding L3, code-review E3-1).** `DynamicEdition._buildField` **enveloppe la sortie du `fieldBuilder`** (dispatcher intégré **ou** builder custom fourni par l'hôte) dans `KeyedSubtree(key: ValueKey(spec.name), …)`, rendant la place stable **non contournable**. Test : un `fieldBuilder` custom **sans** clé explicite reste tout de même keyé sur `field.name` (rebuild externe ⇒ `Element`/`State` réutilisés).

8. **SM-1 préservé à travers le dispatcher (objectif produit n°1, AD-2).** Sur le formulaire de référence passé par le **nouveau chemin de dispatch**, taper **100 caractères** dans un champ **texte** ne reconstruit **que** ce champ (compteur de build du champ = baseline+100 ; compteurs des voisins **inchangés** ; compteur structurel du formulaire **inchangé** = 1) ; **focus** et **curseur** conservés. Le `TextEditingController` **n'est pas recréé** (créé 1× ; `initState==1`) et n'est **jamais** ré-injecté pendant l'édition.

9. **UJ-2 préservé à travers le dispatcher.** Un rebuild d'ancêtre (nouvelle instance `DynamicEdition`) **ne recrée pas** l'état des champs (via `KeyedSubtree`/`ValueKey`) : saisie partielle préservée, focus conservé, pour **au moins** un champ texte **et** un champ non-texte (p. ex. booléen ou select) montés via le dispatcher.

10. **L4 — changement de focus entre champs (finding L4, code-review E3-1).** Taper un champ A (saisir), puis taper un champ B : (a) transfert de focus propre (A perd le focus, B l'obtient), (b) **aucun rebuild-storm** sur A (compteur de build de A borné), (c) **aucun reset** de la valeur/curseur de A. Couvre au moins A texte → B texte ; bonus A texte → B select/booléen.

11. **Validation ciblée réutilisée (E3-2, AD-2).** Les familles portant un `TextFormField` (texte, nombre) réutilisent le **validateur mémoïsé** (`ZValidatorCompiler`, identité stable entre builds) et `AutovalidateMode.onUserInteraction` **par champ** ; **aucun `Form`/`FormBuilder` global** n'apparaît sous `presentation/edition/` (`find.byType(Form) → findsNothing` sur le formulaire de référence). L'erreur d'un champ n'affecte pas ses voisins.

## Tasks / Subtasks

- [x] **Task 1 — Résolution de famille + squelette du dispatcher** (AC: 1, 2)
  - [x] Ajouter une fonction pure `EditionFamily familyOf(EditionFieldType)` (ou équivalent) classant les 39 types selon la table de frontière ci-dessus (base × 6 + `hidden` + « ailleurs »/E3-3b/E3-3c).
  - [x] Créer `ZFieldWidget` (dispatcher) qui, depuis `(ZFormController controller, ZFieldSpec field)`, s'abonne à la tranche via `ZFieldListenableBuilder` (**réutilisé**, jamais réimplémenté) et dispatche par famille — `switch` **exhaustif** sur `EditionFieldType` **sans `default:`** balayant les familles de base.
  - [x] Le corps du slice-builder reste la **frontière de rebuild** (AD-2) : le dispatch choisit uniquement le sous-arbre interne rendu, ne touche ni `visibleFields`, ni `setValue`, ni la mémoïsation du slice.
- [x] **Task 2 — Famille texte (réutilise E3-2)** (AC: 1, 8, 11)
  - [x] Widget texte (`text`/`multiline`/`password`) : conserve `TextEditingController`/`FocusNode` stables (`late final`, 1×, `dispose`), sync guardée hors focus, `AutovalidateMode.onUserInteraction`, validateur mémoïsé `ZValidatorCompiler`. `multiline` : `minLines`/`maxLines`. `password` : `obscureText: true`.
  - [x] Ne pas dupliquer la logique de stabilité déjà portée par le host de champ ; l'extraire proprement si nécessaire pour la partager, sans réécrire E3-2.
- [x] **Task 3 — Famille nombre** (AC: 1, 5, 11)
  - [x] Widget numérique (`number`/`integer`/`float`) : `keyboardType` numérique adapté, `inputFormatters` (int vs décimal), validateur numérique (via `ZValidatorCompiler` si spec, + garde de parsing), écriture typée cohérente dans la tranche (`setValue`).
- [x] **Task 4 — Famille date** (AC: 1, 5, 6)
  - [x] Widget date (`dateTime`/`time`) : déclenche `showDatePicker`/`showTimePicker` (ou champ + bouton picker), rendu **directionnel**, cible du déclencheur ≥ 48 dp, valeur ISO-8601 en tranche (cohérent conventions dates).
- [x] **Task 5 — Famille booléen** (AC: 1, 5, 6)
  - [x] Widget booléen (`boolean`) : `Switch`/`Checkbox` + libellé, `Semantics` d'état (coché/décoché), zone tactile ≥ 48 dp, lecture/écriture de la tranche.
- [x] **Task 6 — Famille select** (AC: 1, 5, 6)
  - [x] Widget select (`select`/`radio`/`checkbox`) alimenté par `ZFieldSpec.choices` (`ZFieldChoice{value,label}`) : `select`→dropdown, `radio`→boutons radio, `checkbox`(+`multiple`)→cases. `Semantics` + cibles ≥ 48 dp ; `label` résolu côté UI ; écriture de(s) valeur(s) dans la tranche.
- [x] **Task 7 — Famille relation (abstraction)** (AC: 1, 5)
  - [x] Widget relation (`relation`) : contrôle de sélection d'entité liée avec **source injectable** (défaut vide/placeholder l10n) ; documenter le point de câblage E4 (port repository/stream). Ne pas tirer de dépendance E4.
- [x] **Task 8 — `hidden` + fallback contrôlé** (AC: 3, 4)
  - [x] `hidden` → `SizedBox.shrink()`.
  - [x] `ZUnsupportedFieldWidget` : repli accessible (libellé + indication l10n), **aucune** exception. Router tous les types non-base vers ce repli via une branche **explicite** (pas un `default` fourre-tout masquant les familles de base). Documenter le futur registre de widgets (E3-3b).
- [x] **Task 9 — Câblage seam + garde `KeyedSubtree` (L3)** (AC: 7, 8, 9)
  - [x] Brancher `ZFieldWidget` comme rendu par défaut (soit `ZEditionField` délègue son rendu interne au dispatcher, soit `DynamicEdition` utilise `ZFieldWidget` comme `fieldBuilder` par défaut — cf. Dev Notes « Décision d'intégration »).
  - [x] Dans `DynamicEdition._buildField`, envelopper la sortie du `fieldBuilder` (dispatcher **et** custom) dans `KeyedSubtree(key: ValueKey(spec.name), …)`.
- [x] **Task 10 — A11y & RTL par widget** (AC: 5, 6)
  - [x] `Semantics` explicites + cibles ≥ 48 dp sur chaque widget interactif ; insets/alignements **directionnels** exclusivement ; thème injecté (`Theme.of`/`ZcrudTheme`), aucun style/couleur en dur.
  - [x] Étendre/mettre à jour l'l10n (`ZcrudLabels`/registre E2-8) pour les libellés de repli/pickers si nécessaire (pas de littéral métier codé en dur).
- [x] **Task 11 — Tests** (AC: 1–11) — voir « Testing » ci-dessous.
- [x] **Task 12 — Vérif verte** : `melos run generate` → `analyze` RC=0 → `flutter test` RC=0 (dont `presentation_purity_test`, `style_purity_test`, `domain_purity_test`, graphe CORE OUT=0, 14 packages). Pas de `.g.dart` committé.

## Dev Notes

### Architecture — invariants applicables (NON-NÉGOCIABLES)

- **AD-2 (objectif produit n°1)** : le dispatcher **échange le rendu interne** sous le slice ; il ne doit **jamais** introduire de rebuild global. Frontière de rebuild = `ZFieldListenableBuilder` (E2-7, RÉUTILISÉ). Interdits : `setState` de niveau formulaire ; construction des champs dans une closure locale de `build()` recréée à chaque rebuild ; recréation de `TextEditingController` ; ré-injection de valeur écrasant la sélection. [Source: architecture.md#AD-2]
- **AD-13 (RTL/a11y/l10n)** : `EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start-end`/`PositionedDirectional` **uniquement** ; `Semantics` explicites ; cibles **≥ 48 dp** ; l10n via delegate/registre injecté, zéro dépendance à `lex_localizations`/`go_router`. [Source: architecture.md#AD-13]
- **FR-23** : i18n/RTL sur toute surface UI. [Source: architecture.md#AD-13 binds FR-23]
- **AD-15 / AD-2** : `zcrud_core` **n'importe aucun gestionnaire d'état** ; jamais `WidgetRef`/`Get.find`/`Provider.of` — passer par `ZcrudScope`/seams. [Source: architecture.md#AD-15]
- **FR-26** : aucun style/couleur codé en dur ; thème injecté (`ZcrudTheme`/`ThemeExtension`), repli `Theme.of(context)`. [Source: architecture.md#AD-13 / CLAUDE.md]
- **AD-4 / `ZTypeRegistry`** : types ouverts (`custom`) et widgets « ailleurs » servis via registre injecté (pas de singleton statique mutable). E3-3a rend un **fallback contrôlé** ; le branchement réel du registre de widgets est **E3-3b**. [Source: z_type_registry.dart, architecture.md#AD-4]

### CLAUDE.md — Key Don'ts directement pertinents

- **Jamais** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `Positioned(left:/right:)`, `TextAlign.left/right` → variantes **directionnelles**.
- **Jamais** `ListView(children: [...])` → `ListView.builder`.
- **Toujours** `Semantics` explicites + cibles ≥ 48 dp ; `const` pour les widgets immuables.
- **Jamais** de style/couleur codé en dur dans un package.
- **Jamais** importer un gestionnaire d'état dans `zcrud_core`.

### Findings de code-review à couvrir (portés dans les ACs)

- **L3** (code-review E3-1, `dynamic_edition.dart:143-145`) : le seam `fieldBuilder` **ne garantit pas** `ValueKey(field.name)` ; « pourrait devenir MEDIUM en E3-3a si un dispatcher oublie la clé ». → **AC7** : `KeyedSubtree(key: ValueKey(spec.name))` autour de la sortie du builder (dispatcher **et** custom), rendant l'invariant de place stable **non contournable** (préserve SM-1/UJ-2).
- **L4** (code-review E3-1) : aucun test de **changement de focus entre champs**. → **AC10**.
- *(Info)* **LOW-2** (code-review E3-2) : réflexion différée non déclenchée au blur. Non exigé ici ; si un widget de famille implémente un rafraîchissement au blur, rester cohérent avec la sync guardée (aucune ré-injection pendant focus).

### Fichiers existants à réutiliser (LIRE avant d'implémenter — ne pas réécrire)

- `packages/zcrud_core/lib/src/presentation/edition/z_edition_field.dart` — **host de champ** : `ZFieldListenableBuilder` + stabilité controller/focus/validateur + sync guardée. E3-3a **échange le rendu interne** de ce host (ou en extrait un dispatcher partagé), **sans** casser ses invariants. *(État actuel : rend un `TextFormField` uniforme dans le `builder` du slice.)*
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` — assembleur : `fieldBuilder` seam + `_buildField` (**cible de la garde `KeyedSubtree`**). *(Actuellement `_buildField` délègue au `fieldBuilder` sans garantir la clé — L3.)*
- `packages/zcrud_core/lib/src/presentation/edition/z_validator_compiler.dart` — validateur mémoïsé (réutiliser tel quel).
- `packages/zcrud_core/lib/src/presentation/z_field_listenable_builder.dart` (E2-7) — helper de tranche (**réutiliser**, jamais réimplémenter).
- `packages/zcrud_core/lib/src/domain/edition/edition_field_type.dart` — **39 valeurs**, source du test d'exhaustivité.
- `packages/zcrud_core/lib/src/domain/edition/z_field_spec.dart` (`type`, `label`, `choices`, `validators`, `config`, `multiple`, `readOnly`…) et `z_field_choice.dart` (`{value,label}`) — données des familles select.
- `packages/zcrud_core/lib/src/domain/registry/z_type_registry.dart` — cible du futur registre de widgets (E3-3b).
- l10n/thème injectables (E2-8) : `ZcrudTheme`, registre de libellés — pour pickers/repli.
- Garde : `packages/zcrud_core/test/purity/style_purity_test.dart` (couleur + directionnel) — doit rester verte ; `presentation_purity_test.dart` (whitelist `flutter/material` + `form_builder_validators`).

### Décision d'intégration (à trancher par le dev dans le respect d'AD-2)

Deux options, toutes deux conformes ; **privilégier B** (alignée sur les commentaires d'E3-1/E3-2) :

- **B (recommandée)** — Le **host de champ** conserve `ZFieldListenableBuilder` + `ValueKey` + stabilité, et **délègue le rendu du contrôle interne** (given `value`, `onChanged`, `validator`, `field`) à un dispatcher par famille (`ZFieldWidget`/`familyOf`). La stabilité du `TextEditingController` reste dans le host mais **n'est allouée que pour les familles texte** (les familles non-texte n'en ont pas besoin). Avantage : la frontière de rebuild et le contrat de stabilité restent **au même endroit** (intacts), le dispatch ne concerne que le sous-arbre.
- **A** — `ZFieldWidget` est passé comme `fieldBuilder` par défaut de `DynamicEdition` ; il ré-encapsule `ZFieldListenableBuilder` + stabilité par famille. Plus modulaire mais **duplique** la logique de stabilité → risque de divergence avec E3-2. À éviter sauf extraction commune propre.

Dans les deux cas : `DynamicEdition._buildField` applique la garde `KeyedSubtree` (AC7), et le contrat de stabilité (`initState==1`, pas de ré-injection) doit être **re-prouvé** à travers le nouveau chemin (AC8/AC9).

### Familles non-texte — écriture dans la tranche

Les familles booléen/date/select/relation **ne s'éditent pas au clavier** : elles lisent `value` depuis le slice et écrivent via `controller.setValue(name, typedValue)` sur interaction (toggle/sélection/pick). Pas de `TextEditingController` requis. Le rebuild reste ciblé (le slice notifie ⇒ seul ce widget se reconstruit). Attention à la stabilité : ne pas recréer de contrôleurs/nœuds dans `build()`.

### Ambiguïtés détectées (à trancher en dev, sans bloquer)

1. **`ZTypeRegistry` = codec, pas widget.** Le `ZTypeRegistry` actuel enregistre des **codecs** (`fromJson`/`toJson`), pas des **widgets**. Le epics dit « widget servi via `ZTypeRegistry` » (E3-3b). E3-3a **n'introduit pas** le registre de widgets : il livre le **fallback contrôlé** et documente le point d'extension. Le vrai registre de widgets (nouveau seam ou extension typée) est **E3-3b**. → tranché : fallback ici, registre widgets en E3-3b.
2. **`stepper`** est un **regroupement** multi-étapes (E3-5), pas un champ-feuille : classé « ailleurs » → fallback contrôlé en E3-3a (E3-5 le traite).
3. **`checkbox` + `multiple`** : `checkbox` peut être choix multiple (cases) ou booléen unique. Convention retenue : `boolean`→toggle unique ; `checkbox`(+`choices`)→multi-sélection depuis `choices` ; respecter `ZFieldSpec.multiple`.
4. **`relation`** : source runtime **non disponible** avant E4. E3-3a rend l'abstraction avec source **injectable** (défaut vide) ; ne pas simuler une dépendance E4.
5. **Écriture typée vs texte** pour `number`/`date` : décider si la tranche stocke la valeur **typée** (`num`/ISO-8601) ou la chaîne. Recommandé : valeur **typée** en tranche (cohérent conventions dates ISO-8601 / persistance), rendu formaté côté widget.

### Project Structure Notes

- Nouveaux fichiers sous `packages/zcrud_core/lib/src/presentation/edition/` (p. ex. `z_field_widget.dart`, `families/` : `z_text_field_widget.dart`, `z_number_field_widget.dart`, `z_date_field_widget.dart`, `z_boolean_field_widget.dart`, `z_select_field_widget.dart`, `z_relation_field_widget.dart`, `z_unsupported_field_widget.dart`, et `edition_field_family.dart` pour `familyOf`). Barrel : exporter l'API publique nécessaire (dispatcher + repli) dans `lib/zcrud_core.dart`.
- **Pureté** : `presentation/` autorise `package:flutter/material.dart` + `form_builder_validators` (whitelist E2-8/E3-2) — **aucun** gestionnaire d'état, `WidgetRef`, `Get`, `Provider`, `cloud_firestore`, Syncfusion, Quill. `domain/` (`edition_field_family.dart` si placé côté domaine) reste **pur-Dart** — mais `familyOf` peut vivre en `presentation/` puisqu'il pilote le rendu. Respecter `domain_purity_test`.
- Le graphe reste **acyclique**, `zcrud_core` out-degree **0** (aucune nouvelle dépendance de package).

### Testing

Framework : `flutter_test` (widgets) + `package:test` (gardes fichiers). Répertoire : `packages/zcrud_core/test/presentation/edition/`. Réutiliser `_reference_form.dart` (harnais E3-1/E3-2), l'étendre pour couvrir les 6 familles.

Tests exigés :

- **Exhaustivité dispatch (AC1/AC2)** : `z_field_dispatch_test.dart` — itère `EditionFieldType.values` (39) ; assert chaque type **de base** → widget dédié attendu (`find.byType(...)`), **0 fallback** ; assert la classification `familyOf` couvre les 39 (aucun `throw`, aucun non classé).
- **Fallback contrôlé (AC3)** : monter un champ de chaque type non-base (E3-3b/E3-3c/registry/`icon`/`custom`/`widget`) ⇒ `ZUnsupportedFieldWidget`, **aucune** exception (`tester.takeException()` == null, pas d'`ErrorWidget`).
- **`hidden` (AC4)** : rend `SizedBox` zéro-taille, pas de crash.
- **A11y de référence (AC5)** : `field_a11y_test.dart` — formulaire des 6 familles ; `meetsGuideline(androidTapTargetGuideline)` (≥ 48 dp) et présence de `Semantics`/labels ; `SemanticsHandle` disposé.
- **RTL (AC6a)** : `field_rtl_test.dart` — pump sous `Directionality(rtl)` pour chaque famille, pas d'overflow, alignements cohérents. **(AC6b)** : `style_purity_test` reste vert (directionnel + couleur) sur les nouveaux fichiers.
- **KeyedSubtree / L3 (AC7)** : `fieldBuilder` custom sans clé ⇒ toujours keyé (rebuild externe ⇒ `initState==1`).
- **SM-1 à travers le dispatcher (AC8)** : réutiliser/étendre `sm1_full_form_test` via le nouveau chemin ; 100 frappes ⇒ champ courant seul reconstruit, voisins + structurel inchangés, focus/curseur préservés, `TextEditingController` non recréé.
- **UJ-2 (AC9)** : rebuild d'ancêtre ⇒ état préservé pour un champ texte **et** un champ non-texte.
- **L4 focus-change (AC10)** : taper A, saisir, taper B ⇒ transfert focus propre, pas de rebuild-storm sur A, pas de reset valeur/curseur de A.
- **Validation ciblée (AC11)** : `find.byType(Form) → findsNothing` ; validateur mémoïsé identité stable ; erreur d'un champ n'affecte pas les voisins.

Non-régression : suite `zcrud_core` complète verte (E2-7/E2-9, E3-1/E3-2), gates melos/reflectable/secrets/codegen/compat/serialization, `graph_proof` CORE OUT=0, 14 packages, 0 `.g.dart` committé.

### References

- [Source: epics.md#E3 — Story E3-3a] (familles texte/nombre/date/booléen/select/relation ; 0 default ; a11y/RTL par-widget — AD-13/FR-23) ; frontières E3-3b (avancées/sous-listes, `ZTypeRegistry`) et E3-3c (fichier/image/document).
- [Source: architecture.md#AD-2] (rebuilds granulaires, réactivité Flutter-native) ; [architecture.md#AD-13] (RTL/a11y/l10n) ; [architecture.md#AD-4] (`ZTypeRegistry`) ; [architecture.md#AD-15] (multi-gestionnaire).
- [Source: CLAUDE.md] Key Don'ts (directionnel, `ListView.builder`, Semantics ≥ 48 dp, no hardcoded style, no state-manager in core).
- [Source: code-review-e3-1.md] findings **L3** (garde `KeyedSubtree` sur le seam `fieldBuilder`) et **L4** (test changement de focus).
- [Source: code-review-e3-2.md] contrat de stabilité controller/validateur mémoïsé/sync guardée à préserver.
- Fichiers : `z_edition_field.dart`, `dynamic_edition.dart`, `z_validator_compiler.dart`, `z_field_listenable_builder.dart`, `edition_field_type.dart`, `z_field_spec.dart`, `z_field_choice.dart`, `z_type_registry.dart`, `style_purity_test.dart`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (BMAD dev-story, effort high).

### Debug Log References

- `dart analyze` (zcrud_core lib) → RC=0 ; `melos run analyze` (14 pkgs) → RC=0.
- `flutter test` (zcrud_core) → **255** tests OK ; `melos run test` (agrégat) → **376** OK (8+80+8+8+17+255), RC=0.
- `melos run verify` → RC=0 : CORE OUT=0 OK, ACYCLIQUE OK, gate:melos/reflectable/secrets/codegen/compat OK ; `melos list`=14 ; 0 `.g.dart` committé.
- Purity : `style_purity_test` (couleur + directionnel) + `presentation_purity_test` + `domain_purity_test` verts sur les nouveaux fichiers.

### Completion Notes List

**Décision d'intégration (Option B host-préservant).** `ZFieldWidget` est le
dispatcher-hôte canonique : il RÉUTILISE `ZFieldListenableBuilder` (frontière de
rebuild), `ZValidatorCompiler` (validateur mémoïsé) et le contrat de stabilité
E3-2 (contrôleur/focus `late final`, sync guardée hors focus) — le contrôleur de
texte n'est alloué QUE pour les familles clavier (texte & nombre) via
`familyUsesTextController`. `DynamicEdition` rend `ZFieldWidget` par défaut et
enveloppe la sortie (dispatcher ET builder custom) dans
`KeyedSubtree(ValueKey(field.name))` (garde L3/AC7). Le harnais de référence
route désormais via `ZFieldWidget`, si bien que les preuves E3-1/E3-2
(SM-1 plein-formulaire, UJ-2, stabilité du contrôleur, curseur médian,
validation) sont **rejouées à travers le dispatcher**. `ZEditionField` reste
inchangé et exporté (compat ; ses tests de source-garde restent verts).

**0 default (AC2).** `familyOf(EditionFieldType)` est un `switch` EXHAUSTIF SANS
`default:` couvrant les 39 valeurs → un futur type non classé **casse la
compilation**. Test runtime itérant `EditionFieldType.values` (39) : 13 types de
base → leur `EditionFamily` dédiée (jamais `unsupported`), 1 `hidden`, 25
« ailleurs » → repli.

**Fallback contrôlé (AC3) / hidden (AC4).** Types « ailleurs » →
`ZUnsupportedFieldWidget` (placeholder accessible, aucune exception, pas
d'`ErrorWidget`). `hidden` → `SizedBox.shrink()` (offstage, hauteur 0).

**a11y/RTL par widget (AC5/AC6).** Cibles ≥ 48 dp prouvées via
`meetsGuideline(androidTapTargetGuideline)` sur le formulaire des 6 familles
(+ `textContrastGuideline`) ; état sémantique `switch` (booléen) exposé
(`Semantics.toggled`) ; rendu RTL sans overflow par famille. Insets/alignements
**directionnels exclusivement** ; aucune couleur en dur (thème hérité).

**Ambiguïtés tranchées.**
1. `ZTypeRegistry` = codec, PAS widget → E3-3a livre le repli + documente le
   point d'extension ; le registre de widgets reste E3-3b.
2. `stepper` → « ailleurs » (regroupement E3-5), repli ici.
3. `checkbox`(+`choices`) → multi-sélection (`List`) ; `boolean` → toggle unique.
4. `relation` → abstraction à source **injectable** (`options`, défaut vide) ;
   câblage repository/stream déféré E4 (jamais simulé).
5. Valeurs **typées** en tranche : `number`/`integer`/`float` → `num`/`int`
   (`null` si non parsable) ; `dateTime`/`time` → ISO-8601 (`toIso8601String`
   / `HH:mm`).
6. **`inputFormatters` omis** (`FilteringTextInputFormatter` vit dans
   `package:flutter/services.dart`, **banni** sous `presentation/` par la garde
   de pureté AD-15/AD-2). La restriction numérique est portée par `keyboardType`
   + parsing typé défensif (`tryParse → null`) + validateur `numeric`/`integer`.

**Findings de code-review couverts.** L3 → `KeyedSubtree` non contournable
(test builder custom sans clé). L4 → test de changement de focus A→B (transfert
propre, A borné, A non réinitialisé).

**Remédiation des findings LOW du code-review (passe post-review, statut reste `review`).**
Trois nits LOW (a11y/correction, AD-13/AD-2) corrigés localement aux widgets de
famille, avec tests dédiés (`test/presentation/edition/low_findings_fix_test.dart`,
+5 tests → cœur 255→260, workspace 376→381). La machinerie de slice E3-1/E3-2 et
le dispatcher `familyOf` (0 default) sont **inchangés**.

- **L-1 (a11y, `families/z_date_field_widget.dart:52-74`)** — double `Semantics`
  supprimé : le wrapper porte désormais `button:true` + `label` (libellé) +
  `value` (valeur/placeholder) + `onTap` + `enabled:!readOnly` et
  `excludeSemantics:true` (exclut la sémantique descendante du bouton Material +
  `Text`). **UN SEUL** nœud sémantique bouton. _Preuve_ : `low_findings_fix_test`
  « déclencheur date = un seul nœud sémantique » — traversée de l'arbre sémantique
  (`flagsCollection.isButton` + label) → exactement 1 nœud, label=`Date`,
  valeur non vide.
- **L-4 (correction/a11y, `families/z_select_field_widget.dart:93-101`)** — le
  radio en `readOnly` ne passe plus `onChanged:(_){}` (no-op, contrôle actif mais
  inerte) : chaque `RadioListTile` porte `enabled:!field.readOnly`
  (`RadioGroup.onChanged` reste non-null, requis par l'API). En `readOnly` le
  groupe est réellement **disabled** (sémantique + UX). _Preuve_ :
  `low_findings_fix_test` — readOnly : tap sans effet (valeur `null`) +
  `flagsCollection.isEnabled == Tristate.isFalse` sur chaque radio ; contre-preuve
  hors readOnly : tap → `'a'` + radios `isEnabled == Tristate.isTrue`.
- **L-3 (correction, `families/z_select_field_widget.dart:71` /
  `families/z_relation_field_widget.dart:58-65`)** — le
  `DropdownButtonFormField` reçoit `key: ValueKey<Object?>(current)` : un
  changement de valeur EXTERNE/programmatique de la tranche recrée l'état du
  `FormField` (qui sinon ne relit `initialValue` qu'à l'`initState`) et **reflète
  la valeur courante**. La sélection d'un dropdown étant atomique (aucune saisie
  en cours), aucun clobber ; le rebuild reste **borné par
  `ZFieldListenableBuilder`** (AD-2, aucun rebuild global). _Preuve_ :
  `low_findings_fix_test` — `setValue('sel','b')` → affiche `Option B`, puis
  `'c'` → `Option C` ; non-régression : sélection utilisateur via menu → `'c'`.

**Vérif verte rejouée (passe LOW).** `dart analyze` (lib + nouveau test) → RC=0,
« No issues found! » (APIs non dépréciées : `getSemantics`/`flagsCollection`) ;
`melos run analyze` RC=0 ; `flutter test` (cœur) → **260** OK ; `melos run test`
→ **381** OK ; `melos run verify` RC=0 (CORE OUT=0, ACYCLIQUE, gates
melos/reflectable/secrets/codegen/compat OK ; skip `serialization-compat`
toléré) ; `melos list`=14 ; 0 `.g.dart`. Non-régression rejouée : `sm1_full_form`,
`uj2_external_rebuild`, `uj2_dispatch_nontext`, `l4_focus_change`,
`external_value_sync`, `field_a11y`, `field_rtl`, purity (`style`/`presentation`/
`domain`) — tous verts. `sprint-status.yaml` et le rapport de code-review NON
modifiés ; aucun commit.

**LOW-2 (non traité, tracké E3-3b).** L'absence d'`inputFormatters`
(`FilteringTextInputFormatter` ∈ `package:flutter/services.dart`, banni sous
`presentation/` par la garde de pureté) reste **différée** : elle exige un
relâchement ciblé de la garde (whitelist par symbole/sous-chemin, jamais
`services.dart` en bloc), à traiter en **E3-3b**. Robuste en l'état (parse
défensif `tryParse→null` + validateur `numeric`/`integer`), dégradation
uniquement cosmétique sur clavier physique — cf. §3 du rapport de code-review.

**Frontière respectée.** E3-3a = familles de base + `hidden` uniquement ;
avancées/sous-listes/registre-widgets = E3-3b ; fichier/image/document = E3-3c.
Le graphe reste acyclique (`zcrud_core` OUT=0 ; aucune nouvelle dépendance de
package). `melos list` = 14. Aucune modification de `sprint-status.yaml` ni des
artefacts de planification ; aucun commit.

### File List

**Créés — `lib/src/presentation/edition/`**
- `edition_field_family.dart` — `EditionFamily` + `familyOf` (0 default) + `familyUsesTextController`.
- `z_field_widget.dart` — dispatcher-hôte (slice + stabilité E3-2 réutilisée).
- `families/z_text_field_widget.dart` — texte / multiline / password.
- `families/z_number_field_widget.dart` — number / integer / float (valeur typée).
- `families/z_date_field_widget.dart` — dateTime / time (picker directionnel, ISO-8601).
- `families/z_boolean_field_widget.dart` — boolean (`SwitchListTile`, état sémantique).
- `families/z_select_field_widget.dart` — select / radio (`RadioGroup`) / checkbox (multi).
- `families/z_relation_field_widget.dart` — relation (source injectable, câblage E4).
- `families/z_unsupported_field_widget.dart` — repli contrôlé accessible.

**Modifiés — `lib/`**
- `src/presentation/edition/dynamic_edition.dart` — défaut → `ZFieldWidget` + garde `KeyedSubtree` (L3/AC7).
- `src/presentation/l10n/z_localizations.dart` — clés `selectTime`, `unsupportedField` (en/fr).
- `zcrud_core.dart` — exports (`familyOf`/`EditionFamily`, `ZFieldWidget`, widgets par famille, repli).

**Tests — `test/presentation/edition/`**
- Créés : `z_field_dispatch_test.dart`, `field_a11y_test.dart`, `field_rtl_test.dart`, `keyed_subtree_guard_test.dart`, `l4_focus_change_test.dart`, `uj2_dispatch_nontext_test.dart`, `validation_targeted_dispatch_test.dart`, `_family_form.dart`.
- Modifiés : `_reference_form.dart` (route via `ZFieldWidget`), `dynamic_edition_test.dart` (`ZEditionField` → `ZFieldWidget`).

**Remédiation LOW — fichiers touchés (passe post-review)**
- Modifiés : `lib/src/presentation/edition/families/z_date_field_widget.dart` (L-1), `lib/src/presentation/edition/families/z_select_field_widget.dart` (L-3 + L-4), `lib/src/presentation/edition/families/z_relation_field_widget.dart` (L-3).
- Créé : `test/presentation/edition/low_findings_fix_test.dart` (+5 tests : L-1/L-3/L-4 + contre-preuves).
</content>
</invoke>
