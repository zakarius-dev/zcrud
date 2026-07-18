# Étude d'intégration — `awesome_select` (fork `akbarpulatov/flutter_awesome_select`, alias SmartSelect / S2)

> Lentille : usages DODLP de `SmartSelect`/`awesome_select`, mapping vers `EditionFieldType` zcrud, proposition d'intégration hors-cœur.
> Repo source (lecture seule) : `/home/zakarius/DEV/dodlp-otr`. Repo cible : `/home/zakarius/DEV/zcrud` (ce rapport est la seule écriture).

## 0. Résumé exécutif

- `SmartSelect` (package `awesome_select`, **fork git non officiel**, pas pub.dev) porte **3 des 4 types "à choix"** de DODLP dans un **seul `case` du `switch`** d'`edition_screen.dart` : `select`, `crudDataSelect` (relation dynamique) et **`radio`** — les trois partagent EXACTEMENT le même builder `_buildSmartSelect`. Le `radio` DODLP n'est **jamais** un `RadioListTile` inline : c'est un déclencheur `ListTile` qui ouvre un **modal S2** (bottom sheet mobile / popup dialog desktop) avec `S2ChoiceType.radios` à l'intérieur.
- `checkbox` (valeur d'enum `EditionFieldTypes.checkbox`) n'a **aucun** `case` dans le `switch` → tombe dans `default:` → rend `EmptyContainer()`. C'est un type **mort/non implémenté** côté DODLP, pas une référence de parité.
- `rowChips` en mode `multiple: true` retourne `SmartSelect<String?>.multiple()` **sans aucun paramètre** (pas de `choiceItems`, pas de `onChange`) → widget non fonctionnel, quasi certainement un défaut/reliquat DODLP. Seul `rowChips` **single** (le `Wrap`/`RawChip` juste après) est réellement utilisé.
- **`zcrud_core` a DÉJÀ anticipé cette parité** dans ses docstrings de conception (`ZSelectConfig.radioAsModal`, commentaire *"MIN-2 — parité DODLP « radio = en réalité modal S2 »"* ; `ZRelationConfig` commenté *"ex-`crudDataSelect` DODLP"* avec un `crudKey` qui documente explicitement `showCrudButton`). Le seam d'intégration (`ZWidgetRegistry`) et les configs const-safe (`ZSelectConfig`, `ZRelationConfig`) sont taillés pour cet adaptateur — il reste à l'écrire.
- Risque fork : dépendance `git` sur `ref: master` (flottant, non semver) chez un mainteneur personnel tiers, non publié sur pub.dev. Le `pubspec.lock` DODLP pin un commit précis (`088e8b7e…`) mais toute régénération du lock (`pub upgrade`) peut faire dériver l'API sans avertissement.

---

## 1. Sites d'usage DODLP (`file:line`)

Fichier principal : `lib/modules/data_crud/presentation/views/edition_screen.dart` (import `package:awesome_select/awesome_select.dart` via `edition_forms.dart:19`).

| Ligne(s) | Contexte |
|---|---|
| `models.dart:22` | `import 'package:awesome_select/awesome_select.dart';` — **le modèle de champ DODLP lui-même** (`DynamicFormField`) type ses propriétés `s2choiceType`/`s2modalType` avec les enums S2 (`models.dart:593-594`, `1149`, `1181`). Le couplage n'est **pas** confiné à la vue. |
| `edition_screen.dart:2488-2490` | `case EditionFieldTypes.select: case EditionFieldTypes.crudDataSelect: case EditionFieldTypes.radio:` — un seul point d'entrée pour les 3 types, `StreamBuilder` autour (source statique `Stream.value` vs source dynamique `field.loadRessourcesStream`). |
| `edition_screen.dart:2500-2504` | Choix de la source : `field.type == crudDataSelect ? field.loadRessourcesStream(editionState) : Stream.value(fieldChoiceItems)`. |
| `edition_screen.dart:2539-2569` | `listToS2Choice()` — projection `{id,name,…} → S2Choice{value,title,subtitle}` (via `choiceValueKey`/`choiceLabelKey`/`choiceSubTitleBuilder` fournis par le champ). |
| `edition_screen.dart:2833-3062` | `_buildSmartSelect()` branche **multiple** → `SmartSelect<String?>.multiple(...)`. |
| `edition_screen.dart:2899-3062` | Config `multiple` : `tileBuilder` en `Card`+`ListTile`+`Wrap` de `Chip`, `modalConfig` (bottomSheet mobile / popupDialog desktop), `choiceConfig` (style actif bleu, sous-titre italique gris), `choiceType: S2ChoiceType.switches` par défaut. |
| `edition_screen.dart:3064-3220` | Branche **single** → `SmartSelect<String?>.single(...)`. `tileBuilder` en `Card`+`ListTile`, `choiceConfig.type` = `radios` en desktop sinon `_choiceType` (calculé ligne 2869-2878, `chips` pour une liste blanche de noms de champs sinon `radios`). |
| `edition_screen.dart:2869-2878` | `_choiceType` : force `S2ChoiceType.chips` pour les champs nommés `state`/`label`/`attributeType`/`stockUnit`/`barecodeType` — **règle spéciale par nom de champ**, pas par type. |
| `edition_screen.dart:2709-2798` | `_modalBuilder()` — dimensionnement custom du modal desktop (`Scaffold` full-page vs `SizedBox` popup, largeur `400.0` cappée, hauteur calculée sur `fieldChoiceItems.length * (kToolbarHeight+2)`). |
| `edition_screen.dart:2633-2704` | `_modalActionsBuilder()` — bouton "reset" (icône ban rouge), bouton confirm multiple, bouton create CRUD-inline (`field.showCrudButton`) si `allowErpRessourceCrud`. |
| `edition_screen.dart:3223-3311` | `_onCrud()` + `choiceSecondaryBuilder` — **CRUD inline** update/copy sur chaque choix quand `field.type == crudDataSelect && widget.allowErpRessourceCrud` (icônes secondaires par item du modal). |
| `edition_screen.dart:3314-3371` | `case EditionFieldTypes.rowChips:` — **multiple → `SmartSelect<String?>.multiple()` vide (non fonctionnel)** ; **single → PAS de SmartSelect**, un `Wrap`/`RawChip` maison. |
| `edition_screen.dart:3737-3767` | `case EditionFieldTypes.widget:` — lecture défensive d'un `SmartSelect` retourné par un champ `widget` custom, pour le rendu `readOnly` (extraction du libellé sélectionné). Cas générique, pas un site de configuration propre. |
| `edition_forms.dart:71-78` | Bloc **commenté** `DynamicSmartSelect(...)` pour un sélecteur pays — mort, ignoré. |
| `models.dart:1040-1066` | `loadRessourcesStream()` — source dynamique réelle de `crudDataSelect` : `dodlp.streamAll<T>()` (repository Firestore) filtré par `ressourceFilter`, mappé en `List<Map<String,dynamic>>`. |

Vérification d'absence (checkbox non implémenté) :
```
$ grep -n "EditionFieldTypes.checkbox" lib/modules/data_crud/presentation/views/edition_screen.dart lib/modules/data_crud/*.dart
(aucune sortie, RC=1)
```
Le `switch` se termine par un `default:` générique (`edition_screen.dart:4061-4063`) qui rend `EmptyContainer()` — c'est donc le sort de tout `EditionFieldTypes.checkbox` déclaré.

## 2. API réellement configurée

### 2.1 Mode `single` (`select`, `radio`, `crudDataSelect` non-multiple)
- `tileBuilder` : `Card` (`elevation: 0`, bord `Colors.grey.shade300`, radius 12) contenant un `ListTile` (`title` = label du champ, `subtitle` = titre du choix sélectionné ou placeholder "Sélectionner...", `trailing` = chevron sauf `readOnly`).
- **Couplage `flutter_form_builder` résiduel et mort** : si `noChoice`, un `FormBuilderChoiceChips` est empilé en `Stack` **avec `options: []`** — il ne rend jamais rien de sélectionnable, ne sert qu'à porter le `validator` (`FormBuilderValidators.compose`). Artefact d'une ancienne implémentation FormBuilder, pas une dépendance fonctionnelle réelle sur l'état FormBuilder global (le SmartSelect gère sa propre sélection).
- `modalConfig.type` : `S2ModalType.popupDialog` desktop / `S2ModalType.bottomSheet` mobile (`AppPlatform.isWebOrDesktop`). Largeur popup cappée à 400 (`edition_screen.dart:2715`), `minWidth: 700` codé en dur sur le sous-titre en desktop (`edition_screen.dart:3110-3113`).
- `choiceConfig.type` : `S2ChoiceType.radios` en desktop, sinon `_choiceType` — `chips` pour 5 noms de champ hardcodés, `radios` sinon.
- Couleurs codées en dur : `Colors.grey.shade300/400`, `Colors.blueAccent` (style actif), `Colors.white70`/`Colors.black87` (texte selon `isDark` calculé à la main, pas via `Theme.of(context)`), `kErrorColor`/`kNavyColor` (constantes app DODLP).
- `onChange` : écrit `item[fieldName]`, `fieldController.text`, `_textFieldCtrl.text`, appelle `field.onChange` custom, puis `Future.delayed(300ms, () => setState({}))` — **rebuild de tout l'écran d'édition** après un délai. C'est exactement le pattern que zcrud AD-2 interdit (rebuild formulaire entier au lieu de la tranche).

### 2.2 Mode `multiple` (`select`/`crudDataSelect` avec `field.multiple == true`)
- `tileBuilder` similaire, mais `subtitle` = `Wrap` de `Chip` (un par choix sélectionné), `backgroundColor` bascule `kNavyColor`/`Colors.grey.shade200` selon `isDark`.
- `FormBuilderCheckboxGroup` mort en `Stack` (mêmes remarques que 2.1), `options: []`.
- `modalConfig.useFilter: false` mais `filterAuto: true`, `useConfirm: true` (bouton check explicite pour valider la sélection multiple — UX différente du single qui se ferme au tap).
- `choiceType` par défaut : `S2ChoiceType.switches` (≠ single qui préfère `radios`/`chips`).
- `onChange` : reçoit `List<String?>`, sérialise en `value.join("S2Choice")` dans deux `TextEditingController` (séparateur littéral `"S2Choice"` — fragile si une valeur métier contient cette sous-chaîne).

### 2.3 CRUD inline (`crudDataSelect` uniquement)
- `field.showCrudButton(state, Crud.create/update/copy, onCrud: _onCrud)` injecte des boutons dans `modalActionsBuilder` (header du modal) et `choiceSecondaryBuilder` (par ligne de choix) — permet de créer/éditer/dupliquer la ressource liée **sans quitter le modal de sélection**, avec re-résolution des choix (`state.resolveChoices()`) après l'opération.
- Actif seulement si `widget.allowErpRessourceCrud == true` — flag au niveau de l'écran d'édition, pas du champ.

## 3. Rendu visuel — ce qui casserait la parité DODLP si remplacé

1. **`radio` DODLP n'est visuellement PAS un groupe de radios inline** : c'est une carte déclenchant un modal (bottom sheet/dialog) contenant les radios. Un remplaçant zcrud qui rendrait `radio` en `RadioListTile` inline (ce que suggère le nom) romprait la parité visuelle — **sauf activation explicite** du flag prévu à cet effet côté zcrud (`ZSelectConfig.radioAsModal`, cf. §5).
2. **Bascule responsive du modal** (bottom sheet mobile / popup dialog desktop, largeur cappée 400px, dimensionnement dynamique sur le nombre de choix) — un simple `DropdownButtonFormField` ne reproduit ni la recherche filtrable ni cette bascule.
3. **Chips de sélection multiple** avec libellés tronqués et couleurs distinctes clair/sombre calculées à la main.
4. **CRUD inline** (créer/éditer une ressource liée sans quitter le sélecteur) — fonctionnalité riche propre à `crudDataSelect`, absente de tout `<select>`/`Dropdown` standard.
5. **Recherche/filtre dans le modal** (`filterAuto: true`, `modalFilterHint`).
6. Règle spéciale par nom de champ (`_choiceType` chips pour 5 champs) — comportement ad hoc non généralisable tel quel (à traiter comme config explicite côté zcrud, pas une règle de nommage magique).
7. **Ce qui NE serait PAS une régression à ne pas reproduire** : le `FormBuilderChoiceChips`/`FormBuilderCheckboxGroup` fantômes (`options: []`, invisibles), le `rowChips.multiple` vide/cassé, le rebuild `setState(() {})` différé de 300ms.

## 4. Corroboration côté zcrud_core (déjà anticipé)

Grep de confirmation :
```
$ grep -n "MIN-2\|radioAsModal\|crudDataSelect" packages/zcrud_core/lib/src/domain/edition/z_field_config.dart
400: /// MIN-2 (parité DODLP « radio = en réalité modal S2 ») — quand `true`, un champ
430: /// Config du champ **relation** (`relation`, ex-`crudDataSelect` DODLP — gap
```
- `ZSelectConfig` (`z_field_config.dart:363-428`) porte déjà `searchable`, `modalThreshold`, `choicesFromKey` (parité `stateChoiceItems`), `choicesSourceKey` (résolu via `ZChoicesSourceRegistry` runtime), `filterKeys`, et **`radioAsModal`** — exactement la bascule identifiée en §3.1. Défaut `radioAsModal: false` = `RadioListTile` inline (rétro-compat E3-3a) ; **un binding DODLP doit passer `radioAsModal: true`** pour retrouver le rendu exact du fork actuel.
- `ZRelationConfig` (`z_field_config.dart:445-490`) porte `sourceKey` (résolu dans `ZRelationSourceRegistry`, remplace `loadRessourcesStream`), `filterKeys` (remplace `ressourceFilter`), `searchable`, et **`crudKey`** (résolu dans `ZRelationCrudRegistry`, parité explicite `showCrudButton` documentée dans le commentaire source) — couvre le CRUD inline du §2.3.
- `ZFieldChoice` (`z_field_choice.dart`) porte déjà `subtitle`/`disabled`, parité `choiceSubTitleBuilder`/`s2ChoiceDisabled` DODLP.
- Ces trois types sont **const-safe** (aucune closure/Stream) — cohérent avec AD-3 (codegen) : la résolution dynamique (repository, filtre, CRUD handler) est déportée dans des registres runtime (`ZRelationSourceRegistry`, `ZChoicesSourceRegistry`, `ZRelationCrudRegistry`), pas dans l'annotation.

**Conclusion** : le travail de modélisation const-safe est déjà fait. Ce qui manque est le **widget adaptateur** (le rendu S2 réel branché sur ces configs) et les **registres runtime** eux-mêmes (existent-ils déjà en E3/E4 ? à vérifier par la story qui les implémentera — hors du périmètre de cette étude).

## 5. Mapping `EditionFieldType` / DODLP / config S2

| `EditionFieldType` zcrud | Équivalent DODLP | Widget S2 | Config zcrud pertinente |
|---|---|---|---|
| `select` | `EditionFieldTypes.select` | `SmartSelect.single` (ou `.multiple` si `multiple: true`) | `ZSelectConfig` (`searchable`, `modalThreshold`, `choicesFromKey`, `choicesSourceKey`, `filterKeys`) + `ZFieldSpec.choices` (`ZFieldChoice`) |
| `radio` | `EditionFieldTypes.radio` | `SmartSelect.single` avec `choiceType: radios`, **modal** — PAS `RadioListTile` inline par défaut DODLP | `ZSelectConfig.radioAsModal: true` pour parité exacte DODLP ; `false` = rendu inline natif E3-3a (divergence assumée, à documenter côté binding) |
| `checkbox` | **aucun** (type mort, `default:` → vide côté DODLP) | — | Pas de référence de parité à porter ; zcrud peut définir son propre rendu (ex. `SmartSelect.multiple` avec `choiceType: checkboxes`) sans contrainte historique |
| `relation` | `EditionFieldTypes.crudDataSelect` | `SmartSelect.single`/`.multiple` + CRUD inline (`choiceSecondaryBuilder`, `modalActionsBuilder`) | `ZRelationConfig` (`sourceKey`, `filterKeys`, `searchable`, `crudKey`) |
| `rowChips` | `EditionFieldTypes.rowChips` | **PAS de SmartSelect** en mode single (le seul mode réellement fonctionnel côté DODLP) — `Wrap`/`RawChip` maison ; mode `multiple` cassé côté DODLP (à ne pas reproduire) | Hors périmètre S2 — lentille séparée (widget `Wrap`/`Chip` custom), ou réutiliser `SmartSelect.multiple(choiceType: chips)` en corrigeant le défaut DODLP |
| `tags` | `EditionFieldTypes.tags` | **Non concerné** — DODLP implémente `tags` comme saisie libre de chips (`edition_screen.dart:2100+`), aucun `SmartSelect` | Hors périmètre de cette lentille |

## 6. Proposition d'intégration (placement, AD-1, AD-2, a11y/RTL/thème)

### 6.1 Placement (AD-1)
- **Jamais dans `zcrud_core`** : `awesome_select` est un package Flutter lourd (dépend de `flutter`, transitivement de widgets Material) et un **fork git non pub.dev** — deux raisons suffisantes pour l'isoler dans un satellite dédié (proposition : `zcrud_select` ou un module `select` dans un satellite d'adaptateurs DODLP, ex. `zcrud_dodlp_compat` si une telle collection existe déjà — à trancher par la story d'implémentation, pas par cette étude).
- Le satellite expose une fonction `registerDodlpSelectWidgets(ZWidgetRegistry registry, {required ZRelationSourceRegistry relationSources, ZRelationCrudRegistry? relationCrud, ZChoicesSourceRegistry? choicesSources})` qui appelle `registry.register('select', ...)`, `register('radio', ...)`, `register('checkbox', ...)`, `register('relation', ...)` — jamais un singleton statique (AD-4), l'app hôte l'appelle explicitement au bootstrap et injecte le registre rempli via `ZcrudScope`.
- `zcrud_core` continue à n'exposer QUE `ZFieldSpec`/`ZSelectConfig`/`ZRelationConfig`/`ZFieldChoice` (déjà fait) + le `kind` `String` (nom de l'`EditionFieldType`) — zéro import `awesome_select` dans le cœur. Un consommateur sans ce satellite obtient le repli `ZUnsupportedFieldWidget` (E3-3a), pas un crash.

### 6.2 Conformité AD-2 (réactivité Flutter-native)
- Le `ZFieldWidgetBuilder` adaptateur **lit `ctx.value`** (la tranche courante du champ, pas un état global) et **écrit exclusivement via `ctx.onChanged`** — jamais `item[fieldName] = ...` ni `setState()` à l'échelle du formulaire. Le pattern DODLP `Future.delayed(300ms, () => setState({}))` (rebuild différé de tout l'écran, §2.1) est **strictement interdit** dans l'adaptateur : `onChange: (selected) => ctx.onChanged(selected.value)` suffit, le `ZFormController` propage la tranche seule.
- Les deux `FormBuilderChoiceChips`/`FormBuilderCheckboxGroup` fantômes (`options: []`) ne doivent **pas** être portés : ils n'apportent rien (pas de `FormBuilderState` réellement branché ailleurs dans `zcrud_core`) et introduiraient une dépendance `flutter_form_builder` non désirée dans le satellite sans bénéfice fonctionnel. La validation passe par le pipeline `ZValidatorSpec` existant de zcrud, pas par `FormBuilderValidators`.
- Le `TextEditingController` de synchronisation (`fieldController?.text = value.join("S2Choice")`) est un artefact DODLP pour interop avec le reste du formulaire FormBuilder — sans objet dans zcrud où la tranche `ValueListenable` porte déjà la valeur typée (`List<String>` ou `String`), pas de sérialisation `"S2Choice"`-joined à reproduire.
- Le `StreamBuilder` autour du choix dynamique (`crudDataSelect`, §1) est acceptable **localement dans l'adaptateur** (il ne concerne que ce champ, pas le formulaire) — équivalent à ce qu'imposerait `ZRelationSourceRegistry` côté zcrud (résolution d'un flux d'options par `sourceKey`).

### 6.3 a11y / RTL / thème (AD-13, FR-26)
- Couleurs codées en dur à bannir (§2.1) : `Colors.grey.shade300/400`, `Colors.blueAccent`, `Colors.white70`/`black87`, `kErrorColor`/`kNavyColor` → remplacer par `Theme.of(context).colorScheme.*` (ou `ZcrudScope`/`ThemeExtension` si zcrud expose un thème dédié aux champs).
- `EdgeInsets.symmetric(horizontal:, vertical:)` (§2.1, `contentPadding`) est déjà directionnellement neutre — rien à corriger là. Vérifier en revanche tout futur `EdgeInsets.only(left:/right:)` introduit par l'adaptateur (AD-13).
- Cible tactile : `ListTile` standard (≥48dp de hauteur par défaut Material) — à vérifier explicitement en test widget plutôt qu'assumé.
- `Semantics` : le `ListTile` déclencheur du modal doit porter un label explicite (ex. `Semantics(button: true, label: '$fieldLabel, sélectionner')`) — DODLP s'appuie sur le `title`/`subtitle` visuels seuls, insuffisant pour un lecteur d'écran distinguant "ouvre un sélecteur" d'un simple texte.
- RTL : le paquet `awesome_select` gère `Directionality` en héritant du `MaterialApp` ambiant (`Scaffold`/`AppBar` standards) — pas de `Alignment.centerLeft/Right` ni `Positioned(left:/right:)` détecté dans les sites DODLP étudiés ; à re-vérifier sur le code interne du fork si un rendu RTL cassé est constaté en test (hors périmètre de cette étude, le fork lui-même n'a pas été audité ligne à ligne).

## 7. Risques

1. **Fork git non pub.dev, `ref: master` flottant** (`pubspec.yaml:95-98`) — aucune garantie semver ni changelog ; le `pubspec.lock` pin `resolved-ref: 088e8b7e…` (version affichée `6.0.0`) mais ce pin casse au premier `pub upgrade` sans intervention humaine. Porter cette dépendance dans un satellite zcrud reproduit ce risque de maintenance pour **tous** les consommateurs zcrud, pas seulement DODLP.
2. **Mainteneur personnel unique** (`akbarpulatov`) — pas d'organisation, pas de CI visible depuis ce dépôt ; abandon = fork à internaliser (vendoring) ou remplacement complet du widget.
3. **Couplage modèle DODLP → types S2** (`models.dart:22,593-594`) — si zcrud absorbe ce fork, il hérite de la même tentation de fuir les types S2 dans une couche "config" au lieu de les confiner au satellite ; `ZSelectConfig`/`ZRelationConfig` (const-safe, sans closure S2) montrent que zcrud a déjà évité ce piège au niveau du cœur — à maintenir strictement lors de l'écriture de l'adaptateur (aucun type `S2*` ne doit apparaître dans une signature publique `zcrud_core`).
4. **Bugs latents à ne pas hériter** : `rowChips.multiple` vide (§1, §5), séparateur littéral `"S2Choice"` fragile pour le multi-select, règle magique par nom de champ (`_choiceType`, §2.1 point 6).
5. **`checkbox` sans référence de parité** — toute décision de rendu pour `EditionFieldType.checkbox` est une décision **neuve** côté zcrud, pas un portage (§5).

## 8. Questions ouvertes

- Où vivra concrètement l'adaptateur (nouveau package `zcrud_select`/`zcrud_dodlp_widgets`, ou dans le binding `zcrud_get` puisque DODLP cible GetX) ? Cette étude ne tranche pas le nom/emplacement exact du satellite — décision d'architecture (E3/E7).
- `ZRelationSourceRegistry`/`ZChoicesSourceRegistry`/`ZRelationCrudRegistry` référencés par les commentaires `z_field_config.dart` existent-ils déjà en code (E3/E4) ou restent-ils à créer ? Non vérifié dans cette étude (hors périmètre "awesome_select").
- Faut-il vendoriser (fork interne zcrud) le paquet `awesome_select` plutôt que dépendre du fork `akbarpulatov` en direct, pour couper le risque de maintenance tiers (§7.1-7.2) ? Décision produit, pas technique pure.
- Le rendu RTL interne du fork (au-delà de l'héritage `Directionality` ambiant) n'a pas été audité ligne à ligne dans `awesome_select` lui-même — à couvrir par un test widget RTL dédié avant `done` sur la story d'intégration.
