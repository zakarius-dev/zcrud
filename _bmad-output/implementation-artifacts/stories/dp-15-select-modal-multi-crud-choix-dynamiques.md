---
baseline_commit: a64e3b37c3f85c15bbe2163f667a70183fd81b75
---

# Story DP.15: `select` modal/multi + choix dynamiques cross-champ + CRUD inline relation (parité DODLP — M8 + M22)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que le champ **`select`** propose (comme le `SmartSelect`/S2 DODLP) un **mode modal de recherche**, un **sous-titre** et un état **désactivé par option**, une **variante multi (chips)**, que ses **choix soient recalculables dynamiquement depuis un autre champ** (`stateChoiceItems`, recalcul déclaratif cross-champ), et que le champ **`relation`** expose un **bouton CRUD inline** (créer/modifier/copier l'entité liée) **via un seam neutre injecté**,
so that les formulaires DODLP qui reposaient sur `SmartSelect` (S2), `stateChoiceItems` et `showCrudButton` migrent fidèlement sous zcrud — **sans jamais faire dépendre `zcrud_core` d'un backend/gestionnaire d'état** (AD-1/AD-5), **sans régresser la réactivité granulaire SM-1** (AD-2), et **strictement en additif** (aucune régression du dropdown/radio/checkbox E3-3a ni de la relation dynamique DP-5).

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gaps couverts : **M8** (`select` modal recherche / sous-titre / disabled par choix + variante multi chips + CRUD inline sur relation) et **M22** (choix dynamiques `stateChoiceItems` recalculés cross-champ ; seam `choicesBuilder`). Réf : `docs/dodlp-edition-parity-gap.md` §2.2 (`select — choix dynamiques`, ligne 67), §2.4 (`select` dropdown → SmartSelect S2 modal/recherche/sous-titre ; `select` multiple chips ; `crudDataSelect` CRUD inline, lignes 110-115), §3 MAJOR M8 (ligne 207) + M22 (ligne 221) ; épic `E-DP` story DP-15. DODLP **lecture seule** `/home/zakarius/DEV/dodlp-otr`.

> ⚠️ **Additif & rétro-compatible (sérialisation cœur).** `ZFieldChoice`, `ZFieldConfig`/`ZRelationConfig`, le dispatcher `z_field_widget.dart`, `ZcrudScope` et les barrels `domain.dart`/`zcrud_core.dart` sont des **points de contact cœur PARTAGÉS** (source unique de (dé)sérialisation + dispatch). Tout ajout est **strictement additif** (nouveaux champs optionnels à défaut rétro-compat sur `ZFieldChoice`, nouvelle `ZSelectConfig`, nouveaux ports/registres neutres, nouveaux seams de scope à défaut `null`). Aucun renommage, aucune signature cassante, aucune dépendance ajoutée (graphe `zcrud_core` out-degree 0 inchangé). **Lock cœur sériel** : cette story écrit dans des fichiers cœur partagés — aucun autre workstream ne doit écrire ces fichiers en parallèle (cf. règle de parallélisation CLAUDE.md).

## Contexte — mécanisme DODLP réel (lecture seule)

### SmartSelect (S2 / awesome_select) — `select`/`radio`/`crudDataSelect` (`edition_screen.dart:2489-2668`)

DODLP rend `select`, `radio` **et** `crudDataSelect` via un **`SmartSelect` (S2)** modal :

- **Choix dynamiques `stateChoiceItems`** (`edition_screen.dart:2491-2497`, `models.dart:597`) :
  ```dart
  final fieldChoiceItems =
      (field.stateChoiceItems != null &&
              editionState[field.stateChoiceItems] is List<Map<String, dynamic>>)
          ? editionState[field.stateChoiceItems] as List<Map<String, dynamic>>
          : field.choiceItems;
  ```
  → les options d'un `select` peuvent être **lues depuis un AUTRE champ** du formulaire (`editionState[field.stateChoiceItems]`), recalculées à chaque rebuild. Repli sur `field.choiceItems` (choix statiques) si absent/mal typé. **C'est le gap M22** : côté zcrud `ZFieldSpec.choices` est **const figée**, aucun recalcul cross-champ.

- **Mapping option** (`listToS2Choice`, `edition_screen.dart:2540-2565`) : chaque item → `{value: choiceValueKey ?? id, title: choiceLabelKey ?? name, subtitle: choiceSubTitleBuilder}`. → **sous-titre par option** (gap M8, absent de `ZFieldChoice`).

- **Multi** (`field.multiple → SmartSelect.multiple`) : chips + bouton de confirmation.

- **Modal de recherche/filtre** (`S2ModalType`, `state.filter`) : liste filtrable par saisie.

- **`s2ChoiceDisabled(item, editionState, choice) → bool`** (`models.dart:632-637`) : prédicat de **désactivation par option** (gap M8 — `disabled` par choix).

- **CRUD inline** (`showCrudButton(state, Crud.create/update/copy, onCrud:)` + `field.find(...)`, `edition_screen.dart:3223-3311`) : depuis le sélecteur, **créer / modifier / copier** l'entité liée ; à la résolution, l'option créée/éditée est **auto-sélectionnée** (`state.selected.choice = choice` en mono ; `addIfNotIn` en multi). Défensif (`try/catch (_) {}`). → gap M8 « CRUD inline sur relation ».

### État zcrud actuel

- **`z_select_field_widget.dart`** (`ZSelectFieldWidget`, `StatelessWidget`) : `select` → `DropdownButtonFormField` natif ; `radio` → `RadioGroup` ; `checkbox` → `CheckboxListTile` multi. Options = `field.choices` **const figée** (`ZFieldChoice{value,label}`). **Aucun** modal/recherche, **aucun** sous-titre, **aucun** `disabled` par option, **aucune** variante multi-chips pour `select`, **aucun** recalcul cross-champ.
- **`z_relation_field_widget.dart`** (`ZRelationFieldWidget`, `StatefulWidget`, **DP-5**) : source dynamique injectée (`ZRelationSource`), filtre cross-champ (`filterContext`), **multi chips** + **modal de recherche** déjà livrés (`_RelationSelectSheet`, `_buildMulti`, `_buildSearchableMono`). **Manque le CRUD inline** (explicitement déféré par DP-5 : « *CRUD inline (`showCrudButton`/`crudRepository`) → binding + story de suivi DP-12+* »). **DP-15 livre ce seam.**
- **`z_field_choice.dart`** (`ZFieldChoice`) : `{value, label}` seulement.
- **`z_field_widget.dart`** (dispatcher) : branche `select` (l.384-390) sans config/cross-champ ; branche `relation` (l.391-420, DP-5) résout source+`filterContext`+`multiple`+`searchable`, s'abonne **ciblément** aux `filterKeys` via `_refListenables` (SM-1).

## Approche retenue

**Réutiliser au maximum les patterns DP-5** (déjà éprouvés dans le cœur) : modal `showModalBottomSheet` + recherche client + chips (le `_RelationSelectSheet`/`_buildMulti` de DP-5 sont un **modèle direct** pour le select), abonnement cross-champ **ciblé** via le canal `_refListenables` (SM-1), seams **neutres injectés** via `ZcrudScope` + registre instanciable (AD-4), tout `const`/pur-Dart dans le domaine.

| Besoin DODLP | Mécanisme zcrud (déclaratif + seam neutre) |
|---|---|
| `subtitle` + `s2ChoiceDisabled` par option | **Enrichir `ZFieldChoice`** additivement : `subtitle` (`String?`) + `disabled` (`bool = false`). `const`, rétro-compat (défauts). Rendu : sous-titre en `RadioListTile.subtitle`/`CheckboxListTile.subtitle`/tuile modal ; `disabled` désactive l'option (mono dropdown → `DropdownMenuItem.enabled: false` ; radio/checkbox/modal → tuile désactivée). |
| `SmartSelect` modal recherche (mono/multi) | Ajouter au **select** un mode modal (`showModalBottomSheet` + recherche client sur `label`, `ListView.builder`, a11y AD-13), **activé** par `ZSelectConfig.searchable` **OU** par un **seuil** `modalThreshold` (rétro-compat : sous le seuil et `searchable == false` ⇒ dropdown natif inchangé). Réutilise le gabarit de feuille de DP-5. |
| `SmartSelect.multiple` (chips) | Variante **multi chips** du `select` s'appuyant sur **`ZFieldSpec.multiple`** (source unique — comme relation/fichier). Rendu chips supprimables + déclencheur d'ajout (modal multi), `onChanged` écrit `List<Object?>`. |
| `stateChoiceItems` (choix depuis un autre champ) | **Recalcul déclaratif cross-champ pur-cœur** : `ZSelectConfig.choicesFromKey` (`String?`) — le dispatcher lit la **tranche** de ce champ ; si elle porte une `List<ZFieldChoice>` (ou vide), elle **remplace** `field.choices`. Abonnement **ciblé** à cette clé (canal `_refListenables`, SM-1). Zéro binding requis (parité `stateChoiceItems`). |
| `choicesBuilder` (choix calculés arbitraires) | **Seam neutre** `ZChoicesSource` (port **synchrone** pur-Dart : `List<ZFieldChoice> options(Map<String,Object?> filterContext)`) + registre `ZChoicesSourceRegistry` injecté au scope, résolu par `ZSelectConfig.choicesSourceKey` ; `filterKeys` forment le `filterContext` (abonnement ciblé). Impl concrète **déférée au binding/app**. Défensif : registre/clé absents ⇒ repli sur `choicesFromKey`/`field.choices`. |
| CRUD inline relation (`showCrudButton`) | **Seam neutre** `ZRelationCrudHandler` (port **async** pur-Dart : `create/edit/copy` → `Future<ZFieldChoice?>` = option résultante à auto-sélectionner, ou `null` si annulé) + registre `ZRelationCrudRegistry` injecté au scope, résolu par `ZRelationConfig.crudKey`. Le cœur **n'affiche que les boutons** (Créer dans le modal ; Modifier/Copier par option) et **appelle le handler** ; le formulaire/dialog + repository vivent **entièrement** dans le binding/app (E7 DODLP). Défensif : pas de handler ⇒ aucun bouton (rétro-compat). |

**Frontière neutralité (AD-1/AD-5, NON-NÉGOCIABLE)** : le cœur ne connaît NI repository, NI Firestore/Hive, NI SmartSelect, NI form d'édition. Il connaît : des **clés** (`String`), un **snapshot de contexte** (`Map`), des **ports** (`List<ZFieldChoice>` synchrone / `Future<ZFieldChoice?>`), des **registres instanciables injectés**. Toute impl concrète (calcul métier des choix, form + repository CRUD) vit hors cœur.

## Acceptance Criteria

### Bloc A — Enrichissement additif `ZFieldChoice` (sous-titre + disabled)

1. **`ZFieldChoice` gagne `subtitle` + `disabled` (additif, `const`).** `z_field_choice.dart` : deux champs **optionnels** `final String? subtitle` (défaut `null`) et `final bool disabled` (défaut `false`), intégrés au constructeur `const`, à `==`/`hashCode`/`toString`. **Rétro-compat stricte** : toute construction existante `const ZFieldChoice(value:, label:)` compile et se comporte à l'identique (défauts). Reste **pur-données `const`** (lisible `ConstantReader`, projeté par le générateur E2-5 — aucune closure). Le générateur reste compatible sans changement (champs optionnels).

### Bloc B — `select` : modal recherche + sous-titre/disabled + multi chips (`z_select_field_widget.dart`)

2. **Sous-titre + `disabled` par option (dropdown/radio/checkbox).** `ZSelectFieldWidget` consomme `ZFieldChoice.subtitle`/`disabled` : (a) `select` dropdown → `DropdownMenuItem.enabled: !choice.disabled` (option non sélectionnable, reste visible/accessible) ; (b) `radio` → `RadioListTile.subtitle` (si `subtitle != null`) + `enabled: !field.readOnly && !choice.disabled` ; (c) `checkbox` → `CheckboxListTile.subtitle` + `onChanged: null` si `choice.disabled`. a11y : l'état désactivé est porté sémantiquement (pas un simple grisage). **Rétro-compat** : `subtitle == null` + `disabled == false` ⇒ rendu E3-3a identique.

3. **Mode modal de recherche du `select` (rétro-compat par défaut).** Une nouvelle `ZSelectConfig` (Bloc C) porte `searchable` (`bool = false`) et `modalThreshold` (`int?`). Le `select` bascule en **modal** (`showModalBottomSheet` : recherche client insensible à la casse sur `label`, `ListView.builder`, tuiles avec sous-titre + état désactivé, boutons Confirmer/Fermer l10n) **si** `searchable == true` **OU** si `modalThreshold != null && choices.length >= modalThreshold`. **Sinon** (défaut : pas de `ZSelectConfig`, ou `searchable == false` et sous le seuil) ⇒ `DropdownButtonFormField` natif **inchangé** (E3-3a). Le déclencheur du modal est un `InputDecorator` tap-able accessible (cible ≥ 48 dp) affichant la sélection courante. a11y/RTL AD-13 (directionnel, `Semantics`, recherche `liveRegion`).

4. **Variante multi chips du `select` (via `ZFieldSpec.multiple`).** Si `field.type == select` **et** `field.multiple == true` : le champ rend la sélection en **chips supprimables** (`InputChip`, cibles ≥ 48 dp, `Semantics`, directionnel) + un déclencheur d'ajout ouvrant un **modal multi** (confirmation) ; la tranche porte une `List<Object?>`, `onChanged` écrit la liste mise à jour. Une valeur sélectionnée absente des `choices` courants est affichée par sa valeur brute (pas de crash), cohérent avec la garde `values.contains(value)`. **Ne PAS** confondre avec `checkbox` (qui reste la multi-liste inline E3-3a). `select` mono (`multiple == false`) : dropdown ou modal mono selon AC3.

5. **Réutilisation stricte des primitives.** Le modal/chips du `select` **réutilisent le même gabarit** que DP-5 (`showModalBottomSheet` + recherche client + `CheckboxListTile`/`InputChip` + boutons l10n). Facteur commun autorisé : extraire un widget de feuille partagé (`_ZChoiceSelectSheet`) OU dupliquer le gabarit **dans `z_select_field_widget.dart`** — au choix du dev, **sans** modifier le comportement de `z_relation_field_widget.dart` (le `_RelationSelectSheet` de DP-5 reste privé/intact si non factorisé). Si factorisation : le widget partagé vit dans un fichier neutre de présentation, exporté seulement si nécessaire, **sans** casser les tests DP-5.

### Bloc C — Choix dynamiques cross-champ (`ZSelectConfig` + `choicesFromKey` + seam `ZChoicesSource`) — M22

6. **`ZSelectConfig extends ZFieldConfig` (additive, `const`).** `z_field_config.dart` : nouvelle config `const` pur-données : `searchable` (`bool = false`), `modalThreshold` (`int?`), `choicesFromKey` (`String?`, clé d'un autre champ portant les choix — parité `stateChoiceItems`), `choicesSourceKey` (`String?`, clé de résolution dans `ZChoicesSourceRegistry`), `filterKeys` (`List<String> = const <String>[]`, forment le `filterContext` du seam calculé). Champs `final`, `==`/`hashCode` (`_listEquals(filterKeys)`), **aucun** `Function`, tout `const` (émissible `ConstantReader`). La **multiplicité** réutilise `ZFieldSpec.multiple` (jamais dupliquée). Rétro-compat : un `select` **sans** `ZSelectConfig` conserve exactement le dropdown/radio/checkbox E3-3a.

7. **Recalcul déclaratif `choicesFromKey` (parité `stateChoiceItems`, pur-cœur, SM-1).** Dans le dispatcher, si `field.config is ZSelectConfig` avec `choicesFromKey != null` : lire la **tranche** `controller.valueOf(choicesFromKey)` ; si elle est une `List<ZFieldChoice>` non vide, elle **remplace** `field.choices` comme options rendues ; sinon (absente/vide/mal typée) ⇒ repli sur `field.choices` (jamais un crash, AD-10). L'abonnement à cette clé est **ciblé** (canal `_refListenables`, comme les `filterKeys` DP-5) : une frappe/un changement du champ source recompute **uniquement** ce champ select, jamais le formulaire (SM-1). `choicesFromKey == null` ⇒ aucun abonnement ajouté.

8. **Seam neutre `ZChoicesSource` (choix calculés) + registre (AD-4).** Nouveau port **synchrone** pur-Dart `abstract class ZChoicesSource { const ZChoicesSource(); List<ZFieldChoice> options(Map<String, Object?> filterContext); }` (`lib/src/domain/ports/z_choices_source.dart`), **aucun** import Flutter/backend (AD-1). Registre instanciable `ZChoicesSourceRegistry` aligné sur `ZRelationSourceRegistry`/`ZWidgetRegistry` : `register`(collision → `ZDuplicateRegistrationError`)/`isRegistered`/`keys`/`sourceFor`(strict `ZUnregisteredTypeError`)/`trySourceFor`(défensif `null`). Le dispatcher résout via `ZcrudScope.choicesSourceRegistry?.trySourceFor(choicesSourceKey)` et bâtit le `filterContext` depuis `filterKeys` (snapshot `valueOf`), abonnement **ciblé** à ces tranches (SM-1). **Priorité de résolution des choix** (défensif, ordre stable) : `choicesSourceKey` (si registre+clé résolus) → `choicesFromKey` (si tranche typée non vide) → `field.choices` (statique). Impl concrète du port **déférée au binding/app** (jamais dans le cœur).

### Bloc D — CRUD inline relation via seam neutre (`ZRelationCrudHandler`) — M8

9. **Seam neutre `ZRelationCrudHandler` (port async) + registre (AD-4).** Nouveau port pur-Dart `abstract class ZRelationCrudHandler` (`lib/src/domain/ports/z_relation_crud.dart`, `dart:async` autorisé, **aucun** Flutter/backend) : `Future<ZFieldChoice?> create(Map<String, Object?> context)`, `Future<ZFieldChoice?> edit(Object? value)`, `Future<ZFieldChoice?> copy(Object? value)` — chacun retourne l'**option résultante** à sélectionner (ou `null` si annulé/échec). Registre instanciable `ZRelationCrudRegistry` (même API register/try/strict que les autres registres). Le doc-comment précise : **aucune impl concrète dans le cœur** (form + repository CRUD → binding/app E7).

10. **`ZRelationConfig.crudKey` (additif) + résolution scope.** `ZRelationConfig` gagne `crudKey` (`String?`, défaut `null`) résolu via `ZcrudScope.relationCrudRegistry?.trySourceFor(crudKey)`. `crudKey == null` OU registre/handler absent ⇒ **aucun** bouton CRUD (rétro-compat DP-5 stricte). Additif : constructeur `const`, `==`/`hashCode` étendus, tout `const`.

11. **`ZRelationFieldWidget` surface les boutons CRUD (défensif).** Param **additif optionnel** `crudHandler` (`ZRelationCrudHandler?`, défaut `null`). Si `crudHandler != null` : (a) le **modal** de sélection expose une action **Créer** (`create(filterContext)`) ; (b) chaque option listée expose **Modifier**/**Copier** (`edit(value)`/`copy(value)`) via une affordance accessible (icônes, cibles ≥ 48 dp, `Tooltip`/`Semantics`, l10n `create`/`edit`/`copy`). À la résolution non-`null` du `Future` : l'option retournée est **auto-sélectionnée** (mono → remplace la valeur ; multi → `addIfNotIn`) via `onChanged`. Toujours **défensif** (AD-10) : `Future` en erreur/`null` ⇒ aucune écriture, aucun crash (équivalent du `try/catch (_) {}` DODLP). `crudHandler == null` ⇒ modal identique à DP-5 (aucun bouton). Le cœur **n'ouvre aucun form** lui-même : il délègue au handler.

### Bloc E — Câblage dispatcher `z_field_widget.dart` + scope (SM-1 préservé)

12. **Dispatcher `select` : résout choix dynamiques + config + multi.** Branche `EditionFamily.select` : (a) résout la config `field.config is ZSelectConfig ? … : null` ; (b) résout les **choix effectifs** selon la priorité AC8 (`choicesSourceKey`→`choicesFromKey`→`field.choices`) ; (c) passe `searchable`/`modalThreshold`/`multiple: field.multiple` au widget. Abonnement **ciblé** (via `_refListenables`, comme DP-5) : `choicesFromKey` (si présent) **et** `filterKeys` du `choicesSourceKey` (si présent). Aucun `ZSelectConfig` ⇒ comportement E3-3a strict + `field.choices`.

13. **Dispatcher `relation` : résout le handler CRUD.** Branche `EditionFamily.relation` (DP-5) : en plus de la source/`filterContext`/`multiple`/`searchable`, résout `crudHandler` via `ZcrudScope.maybeOf(context)?.relationCrudRegistry?.trySourceFor(crudKey)` (`crudKey` depuis `ZRelationConfig`) et le passe au widget. Aucun `crudKey`/registre/handler ⇒ `crudHandler: null` (comportement DP-5 strict).

14. **Seams scope additifs.** `ZcrudScope` gagne deux seams **additifs** à défaut `null` : `final ZChoicesSourceRegistry? choicesSourceRegistry` et `final ZRelationCrudRegistry? relationCrudRegistry` — intégrés au constructeur `const`, aux doc-comments (alignés sur `relationSourceRegistry`), et à `updateShouldNotify` (`!identical(...)`). Défaut `null` = rétro-compat totale (tout scope existant compile et se comporte à l'identique).

### Transverse — invariants & non-régression

15. **AD-1 / graphe inchangé.** `zcrud_core` out-degree 0 : aucune dépendance ajoutée ; `ZChoicesSource`/`ZChoicesSourceRegistry`/`ZRelationCrudHandler`/`ZRelationCrudRegistry` pur-Dart (`dart:async` seulement). Aucun `cloud_firestore`/Hive/gestionnaire d'état importé. `graph_proof` vert (CORE OUT=0), `domain.dart` reste Flutter-free (`domain_entrypoint_dart_test` vert).

16. **AD-2 / SM-1 non régressés.** Aucun `setState` à l'échelle du formulaire ; abonnements cross-champ (`choicesFromKey`, `filterKeys`) **ciblés** via `_refListenables` (jamais un canal global). Taper 100 caractères dans un champ **non référencé** ne reconstruit ni le `select` (choix dynamiques) ni le `relation`, et ne perd pas le focus (test compteur `onBuild`). Un changement d'un champ **référencé** recompute **uniquement** le champ dépendant. Aucun contrôleur recréé dans la voie de build ; modals ouverts hors de la frontière de rebuild.

17. **AD-4 / AD-5 / AD-10.** Registres **instanciables** injectés (jamais statiques) ; ports = valeur/`Future` nus (jamais `Either` sur un port UI live) ; **défensif de bout en bout** : registre/clé/config absents → repli statique ; source de choix calculée absente → `choicesFromKey`/`field.choices` ; handler CRUD absent → aucun bouton ; `Future` CRUD en erreur/`null` → aucune écriture ; option courante absente des choix → affichée brute / non sélectionnée ; jamais de `throw` dans le build.

18. **AD-13 (a11y/RTL) + FR-26 (thème).** Chips, modal, dropdown, boutons CRUD, tuiles sous-titre/disabled : `EdgeInsetsDirectional`/`AlignmentDirectional`, `TextAlign.start/end`, `ListView.builder`, cibles ≥ 48 dp, `Semantics` explicites (libellé, action ajouter/supprimer/créer/modifier/copier, état désactivé, résultat de recherche `liveRegion`). Thème via `Theme.of`/`ZcrudTheme` — **aucune** couleur/inset non directionnel en dur.

19. **Rétro-compatibilité stricte, barrels & l10n.** Aucune API publique renommée/retirée. `ZFieldChoice` : nouveaux champs optionnels à défaut. `ZRelationFieldWidget`/`ZSelectFieldWidget` : nouveaux params **optionnels à défaut rétro-compat**. Exports additifs : `domain.dart` (`z_choices_source.dart`, `z_relation_crud.dart` ; `ZSelectConfig`/`ZRelationConfig.crudKey` transitifs via `z_field_config.dart`) ; `zcrud_core.dart` (scope déjà exporté). **l10n** : réutiliser `select`/`search`/`confirm`/`close`/`loading`/`add`/`remove`/`empty`/`edit`/`reset` (déjà présents EN+FR) ; **ajouter** les clés manquantes `create` + `copy` (EN+FR) consommées par les boutons CRUD. Les tests existants (catalogue/dispatch E3-3a, relation DP-5) restent verts.

## Tasks / Subtasks

- [x] **T1 — `ZFieldChoice` : `subtitle` + `disabled` (AC1)**
  - [x] `z_field_choice.dart` : `final String? subtitle` (défaut `null`), `final bool disabled` (défaut `false`) intégrés au constructeur `const`, `==`/`hashCode`/`toString`. Constructions existantes `ZFieldChoice(value:, label:)` inchangées (défauts).
- [x] **T2 — Ports/registres neutres (AC8, AC9)**
  - [x] `lib/src/domain/ports/z_choices_source.dart` : `ZChoicesSource` (SYNCHRONE) + `ZChoicesSourceRegistry` (register/isRegistered/keys/sourceFor strict/trySourceFor défensif ; réutilise `ZDuplicateRegistrationError`/`ZUnregisteredTypeError`). Pur-Dart.
  - [x] `lib/src/domain/ports/z_relation_crud.dart` : `ZRelationCrudHandler` (`create`/`edit`/`copy` → `Future<ZFieldChoice?>`) + `ZRelationCrudRegistry`. Pur-Dart (`dart:async`).
  - [x] Exports `domain.dart` (les deux ports, ordre alphabétique respecté).
- [x] **T3 — Config `ZSelectConfig` + `ZRelationConfig.crudKey` (AC6, AC10)**
  - [x] `z_field_config.dart` : `ZSelectConfig extends ZFieldConfig` (`searchable`/`modalThreshold`/`choicesFromKey`/`choicesSourceKey`/`filterKeys`), `==`/`hashCode` (`_listEquals`), `const`.
  - [x] `ZRelationConfig.crudKey` (`String?`, défaut `null`) ; constructeur/`==`/`hashCode` étendus. DP-5 intact.
- [x] **T4 — `ZSelectFieldWidget` : modal/multi/sous-titre/disabled (AC2, AC3, AC4, AC5)**
  - [x] Sous-titre + `disabled` (dropdown `enabled:false` / radio `enabled` / checkbox `onChanged:null`) (AC2).
  - [x] Mode modal (searchable OU seuil) : `showModalBottomSheet` + recherche client + tuiles sous-titre/disabled + boutons l10n ; déclencheur `InputDecorator` accessible ; repli dropdown natif (AC3).
  - [x] Variante multi chips (via `ZFieldSpec.multiple`) : chips supprimables + modal multi (AC4).
  - [x] Gabarit de feuille `_ZChoiceSelectSheet` **dupliqué** dans `z_select_field_widget.dart` (AC5 autorise) — `z_relation_field_widget.dart` non touché par ce point.
  - [x] a11y/RTL AD-13 + thème FR-26.
- [x] **T5 — `ZRelationFieldWidget` : CRUD inline (AC11)**
  - [x] Param additif `crudHandler` ; bouton Créer (modal) + Modifier/Copier (par option via `secondary`) ; auto-sélection (mono remplace+ferme / multi `addIfNotIn`) ; défensif (`Future` erreur/`null` → no-op). `crudHandler == null` ⇒ modal DP-5 identique.
- [x] **T6 — Dispatcher + scope (AC7, AC12, AC13, AC14, AC16)**
  - [x] `zcrud_scope.dart` : seams `choicesSourceRegistry` + `relationCrudRegistry` (constructeur `const`, doc, `updateShouldNotify`).
  - [x] `z_field_widget.dart` branche `select` : `_resolveSelectChoices` (priorité `choicesSourceKey`→`choicesFromKey`→`field.choices`), passe `searchable`/`modalThreshold`/`multiple` ; abonnement ciblé `choicesFromKey` + `filterKeys` (fusion `_refListenables`).
  - [x] `z_field_widget.dart` branche `relation` : résout `crudHandler` via scope+`crudKey`.
- [x] **T7 — l10n (AC19)**
  - [x] Ajouté `create` (EN+FR) ; `copy`/`edit` déjà présents (réutilisés).
- [x] **T8 — Tests (AC1..AC19)**
  - [x] Domaine (`package:test`) : `ZChoicesSourceRegistry`/`ZRelationCrudRegistry` (register/collision/strict/défensif/non-singleton) ; `ZSelectConfig`/`ZRelationConfig` égalité/`const` ; `ZFieldChoice` (subtitle/disabled, `==`, rétro-compat). Pureté verte.
  - [x] Widget (`flutter_test`) : sous-titre/disabled (dropdown/radio/checkbox) ; modal select (searchable + seuil ; recherche client ; sélection mono ; repli dropdown sous seuil) ; multi chips (add modal / remove chip → liste) ; `choicesFromKey` (change source → maj ; frappe hors clé = 0 recompute) ; `ZChoicesSource` (registre → calculé + priorité + repli) ; CRUD inline (create/edit/copy → auto-sélection ; null/erreur → no-op ; pas de handler → aucun bouton).
  - [x] Rejoué réellement : `dart analyze` RC=0 → `flutter test` RC=0 (829 tests) → `graph_proof` CORE OUT=0 → entrypoint pur-Dart. `melos run generate` sans objet (aucune annotation touchée).

## Dev Notes

### Fichiers touchés (tous `zcrud_core`)

**NEW**
- `lib/src/domain/ports/z_choices_source.dart` — port synchrone `ZChoicesSource` + `ZChoicesSourceRegistry`. Modèle direct : `lib/src/domain/ports/z_relation_source.dart` (DP-5) — copier l'API du registre (register/try/strict, réutiliser `ZDuplicateRegistrationError`/`ZUnregisteredTypeError` de `z_registry_error.dart`). **Différence clé** : `options(...)` est **synchrone** (`List<ZFieldChoice>`), pas un `Stream` — un `select` recalcule ses choix à la lecture, il n'a pas de flux repository live (contrairement à `relation`).
- `lib/src/domain/ports/z_relation_crud.dart` — port async `ZRelationCrudHandler` + `ZRelationCrudRegistry`. `dart:async` autorisé.
- `test/domain/ports/z_choices_source_test.dart`, `test/domain/ports/z_relation_crud_test.dart`
- Tests widget : `test/presentation/edition/z_select_field_widget_test.dart` (compléter l'existant s'il existe) + compléments dans `z_relation_field_widget_test.dart` (CRUD inline) — **ne PAS** casser les tests DP-5 existants.

**UPDATE (points de contact cœur PARTAGÉS — additif strict, lock sériel)**
- `lib/src/domain/edition/z_field_choice.dart` — **⚠️ SÉRIALISATION PARTAGÉE** : `subtitle`/`disabled` additifs. **État actuel** : `{value, label}` (`==`/`hashCode`/`toString`). **À préserver** : `const`, pur-données, projetabilité `ConstantReader` (générateur E2-5), toutes les constructions existantes valides.
- `lib/src/domain/edition/z_field_config.dart` — **⚠️ PARTAGÉ** : `ZSelectConfig` (nouveau) + `ZRelationConfig.crudKey` (additif). **État actuel** : `ZTextConfig`/`ZNumberConfig`/`ZSliderConfig`/`ZRatingConfig`/`FileFieldConfig`/`ZRelationConfig`/`ZDateConfig` + helper `_listEquals`. **À préserver** : tout `const`, `_listEquals` réutilisé, aucune dépendance ajoutée, DP-5/DP-10 intacts.
- `lib/src/presentation/edition/families/z_select_field_widget.dart` — **CIBLE PRINCIPALE** : modal/multi/sous-titre/disabled. **État actuel** : `StatelessWidget` ; `select`→`DropdownButtonFormField` (garde `values.contains(value)`, `key: ValueKey(current)` L-3, `ZcrudTheme.inputDecoration`, `bare` pour mode large B1) ; `radio`→`RadioGroup` ; `checkbox`→`CheckboxListTile` multi + `_toggle`. **À préserver** : mode `bare` (large), garde L-3, repli dropdown natif sous le seuil / sans `ZSelectConfig`, familles radio/checkbox inchangées hors sous-titre/disabled.
- `lib/src/presentation/edition/families/z_relation_field_widget.dart` — **CIBLE (additif DP-5)** : param `crudHandler` + boutons CRUD dans le modal/par option + auto-sélection. **État actuel (DP-5)** : `StatefulWidget` ; `_RelationSelectSheet` (recherche client), `_buildMulti` (chips), `_buildSearchableMono`, `_openModal`, abonnement flux unique possédé par le `State`. **À préserver** : abonnement unique (create `initState`/`cancel` `dispose`/ré-abonnement contrôlé `didUpdateWidget`), repli statique strict (`source==null`), garde L-3, a11y. **Le CRUD est purement additif** au modal existant.
- `lib/src/presentation/edition/z_field_widget.dart` — **⚠️ DISPATCHER PARTAGÉ** : branches `select` (résolution choix dynamiques + config + multi + abonnement ciblé) et `relation` (résolution `crudHandler`). **État actuel** : dispatch value-in-slice sous `ZFieldListenableBuilder` ; pattern `_refListenables`/`refKeys`+`filterKeys` (l.129-159) déjà présent pour l'abonnement ciblé — **le RÉUTILISER** pour `choicesFromKey`/`filterKeys` du select. Branche `select` l.384-390, `relation` l.391-420. **À préserver** : frontière de rebuild = tranche (AD-2), `switch` exhaustif sans `default`, contrôleur texte alloué seulement pour familles clavier, place stable posée par `DynamicEdition`, cas `date`/B1 `large`/DP-5 relation intacts.
- `lib/src/presentation/zcrud_scope.dart` — **⚠️ PARTAGÉ** : seams `choicesSourceRegistry` + `relationCrudRegistry` (constructeur `const` + `updateShouldNotify`). **État actuel** : seams `resolver`/`acl`/`labels`/`theme`/`widgetRegistry`/`relationSourceRegistry`/`filePicker`/`cloudStorage`/`listRenderer`. **À préserver** : zéro-config par défaut (`null`), tous les seams existants inchangés, `updateShouldNotify` chaîné.
- `lib/domain.dart` — exports additifs des deux nouveaux ports.
- `lib/src/presentation/l10n/z_localizations.dart` — clés `create`/`copy` (EN+FR).

### Réutiliser le pattern d'abonnement ciblé `refKeys`/`filterKeys` (SM-1)

`z_field_widget.dart` sait déjà s'abonner **ciblément** à d'autres tranches sans rebuild global (validateurs inter-champs `refKeys` l.146-148 ; `filterKeys` relation DP-5 l.153-159). `choicesFromKey` et les `filterKeys` d'un `ZSelectConfig` suivent **exactement** ce mécanisme : fusionner `controller.fieldListenable(k)` dans `_refListenables` **de ce seul champ select**. Un changement du champ source → recompute des choix de CE champ, jamais un rebuild du formulaire. **Ne PAS** ajouter ces clés à un canal global.

### Frontière neutralité (rappel AD-1/AD-5)

Le cœur ne connaît **jamais** le calcul métier des choix, ni le form d'édition CRUD, ni un repository. `ZChoicesSource` retourne une `List<ZFieldChoice>` **synchrone** (le calcul vit côté binding) ; `ZRelationCrudHandler` retourne un `Future<ZFieldChoice?>` (le form/dialog + repository create/edit/copy vivent côté binding, exactement comme `ZRelationSource` en DP-5). Enregistrés dans `ZcrudScope(choicesSourceRegistry:/relationCrudRegistry:)` par l'app (E7 DODLP).

### Hors périmètre DP-15 (défére / besoins binding détectés)

- **Impl concrète `ZChoicesSource`** (calcul métier des choix depuis l'état) → binding/app. Le cœur ne fournit aucune impl.
- **Impl concrète `ZRelationCrudHandler`** (form d'édition + repository create/update/copy + soft-delete/restore) → binding/app **E7 DODLP** / `zcrud_firestore`. Le cœur n'ouvre aucun form, il appelle le handler.
- **`s2ChoiceDisabled` comme prédicat runtime arbitraire** (closure) → **remplacé** par `ZFieldChoice.disabled` (statique) OU par la source qui n'émet pas / marque `disabled` les options non sélectionnables. Le cœur ne porte pas de closure (AD-3).
- **CRUD inline `select` statique** (hors relation) : DODLP ne l'expose que sur `crudDataSelect` (relation). DP-15 limite le CRUD inline à la famille `relation`.
- **Confirmation/soft-delete/restore d'items** (subItems) : couvert par DP-6, hors périmètre ici.

### Pièges à éviter

- ❌ Ne PAS casser le repli E3-3a du `select` : sans `ZSelectConfig` (ou searchable=false + sous le seuil), le dropdown natif DOIT être identique.
- ❌ Ne PAS mettre un `multiple` dans `ZSelectConfig` (double source ; utiliser `ZFieldSpec.multiple`).
- ❌ Ne PAS confondre `select` multi (chips, nouveau) et `checkbox` (multi inline E3-3a) — deux rendus distincts, tous deux valides.
- ❌ Ne PAS importer un backend/gestionnaire d'état dans le cœur (AD-1) ; ports pur-Dart.
- ❌ Ne PAS ouvrir un form CRUD dans le cœur : déléguer au `ZRelationCrudHandler` (le cœur ne montre que boutons + auto-sélectionne le résultat).
- ❌ Ne PAS ajouter `choicesFromKey`/`filterKeys` à un canal réactif global (régression SM-1).
- ❌ Ne PAS lever sur `Future` CRUD en erreur / registre absent / clé non enregistrée (AD-10 — défensif).
- ❌ Ne PAS régresser DP-5 : `z_relation_field_widget.dart` reste fonctionnel sans `crudHandler` ; les tests DP-5 restent verts.
- ❌ Ne PAS toucher `ZFieldSpec` (réutiliser `multiple`/`choices`/`config` existants) — évite d'élargir la surface de sérialisation partagée.

## Testing Requirements

Framework : `flutter_test` (widget/présentation) + `package:test` (domaine pur). Rejouer `melos run generate` → `dart analyze` (RC=0) → `flutter test` (RC=0) sur `zcrud_core` avant `review`.

**Tests widget (`test/presentation/edition/…`) :**
- **Sous-titre/disabled** : `ZFieldChoice(subtitle:'…', disabled:true)` → dropdown item `enabled:false` ; radio/checkbox tuile désactivée + sous-titre rendu.
- **Modal select** : `ZSelectConfig(searchable:true)` OU `modalThreshold` atteint → modal ouvert, recherche client filtre sur `label`, sélection mono écrite ; sous le seuil + `searchable:false` → dropdown natif (pas de modal).
- **Multi chips select** : `field.multiple:true` + type select → sélectionner 2 options via modal → chips ; supprimer un chip → `onChanged` reçoit la `List` réduite.
- **`choicesFromKey`** : tranche source portant une `List<ZFieldChoice>` → options rendues = cette liste ; changer la tranche source → options mises à jour (recompute ciblé) ; frappe sur un champ hors clé → 0 recompute (SM-1).
- **`ZChoicesSource` (registre)** : source mockée → choix calculés depuis `filterContext` ; priorité `choicesSourceKey` > `choicesFromKey` > `field.choices` ; registre `null`/clé absente → repli défensif (pas de crash).
- **CRUD inline relation** : `ZRelationCrudHandler` mocké — `create` retourne une option → auto-ajoutée/sélectionnée ; `edit`/`copy` idem ; `Future` `null`/`throw` → aucune écriture, aucun crash ; `crudHandler:null` → aucun bouton (modal DP-5 identique).
- **SM-1 / AD-2** : formulaire de référence, 100 frappes dans un champ non lié → 0 rebuild du select/relation (compteur `onBuild`), focus conservé.
- **a11y** : `Semantics`/cibles ≥ 48 dp/directionnel sur chips, boutons CRUD, tuiles, recherche `liveRegion`.

**Tests domaine (`test/domain/…`, pur) :**
- `ZChoicesSourceRegistry`/`ZRelationCrudRegistry` : register + isRegistered/keys ; collision → `ZDuplicateRegistrationError` ; `sourceFor` absent → `ZUnregisteredTypeError` ; `trySourceFor` absent → `null`.
- `ZSelectConfig`/`ZRelationConfig` : égalité/`hashCode` (dont `filterKeys` profond + `crudKey`), `const`.
- `ZFieldChoice` : égalité avec/sans `subtitle`/`disabled`, défauts rétro-compat.
- Pureté : `domain_purity_test.dart` + `domain_entrypoint_dart_test.dart` verts (aucun Flutter dans ports/config/choice).

## Architecture Compliance

- **AD-1** : `zcrud_core` out-degree 0 — ports/registres/config pur-Dart ; impl concrète (calcul choix, form+repo CRUD) hors cœur (binding).
- **AD-2 / SM-1** : abonnements cross-champ **ciblés** (`_refListenables`, pattern `refKeys`/`filterKeys`) ; frontière value-in-slice inchangée ; modals hors voie de rebuild ; aucun `setState` global.
- **AD-3** : configs/choix `const` pur-données (émissibles `ConstantReader`) ; aucune closure (le prédicat `s2ChoiceDisabled` runtime est remplacé par `disabled` statique / source).
- **AD-4** : registres **instanciables** injectés via `ZcrudScope` (jamais statiques) ; extension par enregistrement (`register(key, …)`).
- **AD-5** : ports = valeur/`Future` nus (pas de `Either` sur un port UI live) ; erreurs gérées **défensivement** au widget (AD-10) ; aucun type backend dans le domaine.
- **AD-10** : totalité défensive — registre/clé/config absents → repli ; source calculée absente → `choicesFromKey`/`field.choices` ; handler absent → aucun bouton ; `Future` CRUD erreur/`null` → no-op ; option manquante → brute/non sélectionnée ; évolution **additive**.
- **AD-13 / FR-26** : chips/modal/dropdown/boutons CRUD/tuiles a11y + RTL (directionnel, ≥ 48 dp, `Semantics`, `ListView.builder`, `liveRegion`) ; thème injecté.

## Definition of Done

- [ ] AC1..AC19 satisfaits.
- [ ] `select` : sous-titre/disabled + modal recherche (searchable/seuil) + multi chips fonctionnels ; repli dropdown natif E3-3a strict sans `ZSelectConfig`.
- [ ] Choix dynamiques cross-champ : `choicesFromKey` (parité `stateChoiceItems`, pur-cœur) + seam `ZChoicesSource` (calcul déféré binding) ; priorité de résolution défensive ; SM-1 (abonnement ciblé).
- [ ] CRUD inline relation via seam neutre `ZRelationCrudHandler` : boutons create/edit/copy + auto-sélection ; défensif ; `crudHandler:null` → modal DP-5 identique.
- [ ] Rétro-compat vérifiée : `ZFieldChoice`/`ZRelationConfig` additifs ; scope sans nouveaux seams inchangé ; tests E3-3a + DP-5 verts.
- [ ] SM-1 / AD-2 non régressés (frappe hors clés = 0 rebuild select/relation, focus conservé).
- [ ] Neutralité AD-1/AD-5 : aucun backend/gestionnaire d'état dans le cœur ; `graph_proof` CORE OUT=0 ; `domain.dart` Flutter-free.
- [ ] `dart analyze` RC=0, `flutter test` RC=0 (zcrud_core) ; `melos run generate` sans objet (aucune annotation touchée).
- [ ] Aucune modification hors `zcrud_core` (+ tests) ; **aucun fichier DODLP touché**.

## Project Context Reference

- Gap source : `docs/dodlp-edition-parity-gap.md` §2.2 (ligne 67 `select — choix dynamiques`), §2.4 (lignes 110-115 `select` dropdown/multi/CRUD inline), §3 M8 (ligne 207) + M22 (ligne 221).
- Épics : `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md` (E-DP · DP-15).
- Architecture (AD-1/2/3/4/5/10/13, FR-26) : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`.
- DODLP (lecture seule) : `/home/zakarius/DEV/dodlp-otr/lib/modules/data_crud/presentation/views/edition_screen.dart:2489-2668` (SmartSelect S2 : `stateChoiceItems`, `listToS2Choice` subtitle, multi, modal), `:3223-3311` (`showCrudButton`/`_onCrud` create/update/copy + auto-sélection) ; `models.dart:597` (`stateChoiceItems`), `:601` (`choiceSubTitleBuilder`), `:632-637` (`s2ChoiceDisabled`).
- Patterns cœur réutilisés : `z_relation_source.dart` (port+registre neutre AD-4, DP-5) ; `z_field_widget.dart:129-159` (abonnement ciblé `refKeys`/`filterKeys`) ; `z_relation_field_widget.dart` (modal/chips/recherche DP-5, gabarit direct) ; `z_field_config.dart` (`ZRelationConfig`/`ZDateConfig` const).
- Story précédente de l'épic : `dp-5-relation-dynamique-cruddataselect.md` (même épic ; même discipline additive/rétro-compat sur le cœur partagé ; CRUD inline explicitement déféré à cette story).

## Dev Agent Record

### Implementation Plan

Ordre suivi : domaine pur d'abord (ZFieldChoice → ports → config → barrel domain.dart → scope → l10n), puis présentation (widget select réécrit, widget relation additif CRUD, dispatcher), puis tests domaine + widget, puis vérif verte réelle.

### Completion Notes

- **AC1** ✅ `ZFieldChoice` : `subtitle` (`String?=null`) + `disabled` (`bool=false`) additifs, `const`, `==`/`hashCode`/`toString`. Rétro-compat prouvée (test « legacy == explicit defaults »). Pur-données (aucune closure), projetable `ConstantReader`.
- **AC2** ✅ Sous-titre + disabled : dropdown `DropdownMenuItem.enabled:!disabled` + sous-titre en `Column` ; radio `RadioListTile.enabled:!readOnly&&!disabled` + `subtitle` ; checkbox `onChanged:null` si disabled + `subtitle`. `subtitle==null&&!disabled` ⇒ rendu E3-3a identique.
- **AC3** ✅ Modal du `select` (searchable OU `modalThreshold` atteint) via `showModalBottomSheet` + recherche client insensible casse + `ListView.builder` + tuiles sous-titre/disabled + boutons l10n ; déclencheur `_ChoiceSelectionTrigger` (`InputDecorator`/`InkWell`, ≥48dp). Sous seuil & non searchable ⇒ `DropdownButtonFormField` natif inchangé.
- **AC4** ✅ Multi chips `select` (via `ZFieldSpec.multiple`) : `InputChip` supprimables + bouton Add ouvrant modal multi ; `onChanged` écrit `List<Object?>`. Valeur absente des choices → affichée brute (`'$v'`).
- **AC5** ✅ Gabarit `_ZChoiceSelectSheet` **dupliqué** dans le fichier select (option autorisée) ; `z_relation_field_widget.dart._RelationSelectSheet` non modifié par ce point (les tests DP-5 restent verts).
- **AC6** ✅ `ZSelectConfig extends ZFieldConfig` const, `_listEquals(filterKeys)`, aucun `Function`, multiplicité via `ZFieldSpec.multiple`.
- **AC7** ✅ `choicesFromKey` : dispatcher lit la tranche → si `List<ZFieldChoice>` non vide, remplace `field.choices` ; abonnement CIBLÉ via `_refListenables` (test SM-1 : 100 frappes hors clé = 0 recompute du select ; changement de la tranche source = recompute du seul champ dépendant).
- **AC8** ✅ Port SYNCHRONE `ZChoicesSource` + `ZChoicesSourceRegistry` (API alignée sur `ZRelationSourceRegistry`). Priorité `choicesSourceKey`(résolu, même vide) → `choicesFromKey`(typé non vide) → `field.choices`. Source en erreur → repli (try/catch).
- **AC9** ✅ Port async `ZRelationCrudHandler` (create/edit/copy → `Future<ZFieldChoice?>`) + `ZRelationCrudRegistry`. Doc-comment : impl concrète hors cœur.
- **AC10** ✅ `ZRelationConfig.crudKey` additif (`String?=null`), `==`/`hashCode` étendus.
- **AC11** ✅ `ZRelationFieldWidget.crudHandler` additif : bouton Créer (titre du modal) + Modifier/Copier par option (`secondary` du `CheckboxListTile`, `IconButton` ≥48dp + tooltip l10n). Auto-sélection : mono remplace+ferme, multi `addIfNotIn` (Set) + insertion dans la liste locale mutable de la feuille. `_runCrud` défensif (try/catch + null → no-op). `crudHandler==null` ⇒ aucun bouton.
- **AC12** ✅ Dispatcher `select` : `_resolveSelectChoices` + passe `searchable`/`modalThreshold`/`multiple:field.multiple` ; abonnement ciblé `choicesFromKey`+`filterKeys` en `initState`.
- **AC13** ✅ Dispatcher `relation` : `crudHandler` résolu via `ZcrudScope.maybeOf(context)?.relationCrudRegistry?.trySourceFor(crudKey)`.
- **AC14** ✅ `ZcrudScope` : `choicesSourceRegistry` + `relationCrudRegistry` (défaut `null`), constructeur `const`, doc alignée, `updateShouldNotify` chaîné.
- **AC15** ✅ Graphe inchangé : `graph_proof` CORE OUT=0 ; `domain_entrypoint_dart_test` vert ; ports pur-Dart (`dart:async` seulement pour le CRUD).
- **AC16** ✅ Abonnements cross-champ CIBLÉS (`_refListenables`) ; aucun `setState` global ; modals hors voie de rebuild. Test compteur `onBuild`.
- **AC17** ✅ Défensif de bout en bout (registre/clé/config absents → repli ; source erreur → repli ; handler absent → aucun bouton ; Future null/erreur → no-op).
- **AC18** ✅ Directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), `ListView.builder`, ≥48dp, `Semantics`, recherche `liveRegion`, thème `Theme.of`.
- **AC19** ✅ Aucune API renommée/retirée ; params additifs à défaut ; exports additifs `domain.dart` ; l10n `create` ajouté (`copy`/`edit` réutilisés). Tests E3-3a + DP-5 verts.

**Besoins binding déférés (documentés, NON implémentés)** : impl concrète `ZChoicesSource` (calcul métier des options) + `ZRelationCrudHandler` (form d'édition + repository create/update/copy) → app/binding E7 DODLP / `zcrud_firestore` ; enregistrement dans `ZcrudScope(choicesSourceRegistry:/relationCrudRegistry:)` → app.

**Note de conception** : le CRUD inline relation est surfacé dans le **modal** ; le dispatcher force donc le chemin modal (searchable) dès qu'un `crudHandler` est résolu, même sans `searchable` explicite (parité SmartSelect DODLP, toujours modal). Sans `crudHandler` ni `searchable`, le dropdown DP-5 reste strictement inchangé.

### File List

**NEW (zcrud_core)**
- `packages/zcrud_core/lib/src/domain/ports/z_choices_source.dart`
- `packages/zcrud_core/lib/src/domain/ports/z_relation_crud.dart`
- `packages/zcrud_core/test/domain/ports/z_choices_source_test.dart`
- `packages/zcrud_core/test/domain/ports/z_relation_crud_test.dart`
- `packages/zcrud_core/test/domain/edition/z_select_config_choice_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_select_field_widget_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_relation_field_crud_test.dart`

**UPDATE (zcrud_core)**
- `packages/zcrud_core/lib/src/domain/edition/z_field_choice.dart` — `subtitle`/`disabled` additifs.
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` — `ZSelectConfig` (nouveau) + `ZRelationConfig.crudKey`.
- `packages/zcrud_core/lib/domain.dart` — exports des deux ports.
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` — seams `choicesSourceRegistry`/`relationCrudRegistry`.
- `packages/zcrud_core/lib/src/presentation/l10n/z_localizations.dart` — clé `create` (EN+FR).
- `packages/zcrud_core/lib/src/presentation/edition/families/z_select_field_widget.dart` — modal/multi/sous-titre/disabled + `_ZChoiceSelectSheet`.
- `packages/zcrud_core/lib/src/presentation/edition/families/z_relation_field_widget.dart` — `crudHandler` + boutons CRUD + `_CrudRowActions`.
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` — dispatcher select (choix effectifs + abonnement ciblé) + relation (crudHandler).

## Change Log

| Date | Version | Description | Auteur |
|---|---|---|---|
| 2026-07-11 | 0.1 | Création story (context engine) — DP-15 select modal/multi + choix dynamiques cross-champ + CRUD inline relation (M8+M22) | bmad-create-story |
| 2026-07-11 | 0.2 | Implémentation complète AC1..AC19 : ZFieldChoice subtitle/disabled, ZSelectConfig, ZChoicesSource+ZRelationCrudHandler (ports+registres neutres), ZRelationConfig.crudKey, select modal/multi/sous-titre/disabled, CRUD inline relation, 2 seams scope, dispatcher (choix dynamiques SM-1). Vert : analyze RC=0, flutter test RC=0 (829), graph_proof CORE OUT=0, entrypoint pur-Dart. Status → review | bmad-dev-story |
