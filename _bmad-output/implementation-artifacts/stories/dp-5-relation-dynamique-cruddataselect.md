---
baseline_commit: 1bcae2ad4ea1a66198f02020a6f29f77e1e2e2f6
---

# Story DP.5: Relation dynamique `crudDataSelect` (parité DODLP — B7)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As développeur consommateur de zcrud (migration DODLP → zcrud),
I want que le champ **relation** (`EditionFieldType.relation`, ex-`crudDataSelect` DODLP) s'alimente d'une **source de données dynamique** (un flux d'options live fourni par un repository/stream), applique un **filtre cross-champ** dépendant de l'état d'édition, et propose la **multi-sélection** + un **modal de recherche** — le tout via un **port neutre injecté**,
so that les formulaires DODLP qui liaient une entité via `loadRessourcesStream(editionState)` + `ressourceFilter(editionState, item)` migrent fidèlement sous zcrud, **sans jamais faire dépendre `zcrud_core` d'un backend** (AD-1/AD-5) et **sans régresser la réactivité granulaire SM-1** (AD-2).

Périmètre : **`zcrud_core` uniquement** (+ ses tests). Gap couvert : **B7** (`crudDataSelect` relation dynamique — `ZRelationFieldWidget` n'est aujourd'hui qu'un dropdown statique `options` vide par défaut, sans stream/repo/filtre). Réf : `docs/dodlp-edition-parity-gap.md` §1 (bloquant #7), §2.2 (ligne `crudDataSelect → relation`), §2.4 (source dynamique + filtre + multi + modal + CRUD inline) ; épic `E-DP` story DP-5 ; DODLP lecture seule `/home/zakarius/DEV/dodlp-otr`.

> ⚠️ **Additif & rétro-compatible (sérialisation cœur).** `ZFieldSpec`/`ZFieldConfig`/`ZFieldChoice` et le barrel `domain.dart` sont **partagés** (source unique de (dé)sérialisation) : tout ajout est **strictement additif** (nouveau `ZRelationConfig`, nouveau port, nouveau registre). Un champ `relation` **sans** source (config absente ou registre non injecté) conserve **exactement** le dropdown statique actuel (`ZRelationFieldWidget(options: …)`). Aucun renommage, aucune signature cassante, aucune dépendance ajoutée (graphe `zcrud_core` out-degree 0 inchangé).

## Contexte — mécanisme DODLP réel (lecture seule)

DODLP porte `crudDataSelect` sur un champ (`DynamicListField`, `models.dart`) qui embarque **des closures et un repository** :

- **Source de données** (`models.dart:1045-1055`) :
  ```dart
  Stream<List<Map<String, dynamic>>> loadRessourcesStream(Map<String, dynamic> editionState) =>
      dodlp.streamAll<T>()?.map((event) => toMapList(
            event.where((e) => ressourceFilter?.call(editionState, e) ?? true).toList(),
          )) ?? Stream.value([]);
  ```
  → un **flux live** d'entités liées issu d'un repository (Firestore/`dodlp.streamAll<T>()`), converties en `List<Map>`, **filtrées** par `ressourceFilter`. Repli `Stream.value([])` (jamais un crash).

- **Filtre cross-champ** (`models.dart:596`) : `bool Function(Map editionState, T item)? ressourceFilter` — reçoit **l'état d'édition complet** (les autres champs du formulaire) pour ne garder que les entités pertinentes (ex. filtrer les sous-ressources par le parent sélectionné dans un autre champ).

- **Câblage UI** (`edition_screen.dart:2489-2668`) : un `StreamBuilder(initialData: choiceItems, stream: loadRessourcesStream(editionState))` alimente un **SmartSelect (S2 / awesome_select)** :
  - `listToS2Choice` mappe chaque item → `{value: choiceValueKey ?? id, title: choiceLabelKey ?? name, subtitle: choiceSubTitleBuilder}` (`2540-2565`).
  - `field.multiple` → `SmartSelect.multiple` (chips + bouton de confirmation, `2647-2666`).
  - **Modal de recherche/filtre** (`S2ModalType`, `state.filter`, `2640-2668`).
  - `s2ChoiceDisabled(item, editionState, choice) → bool` : prédicat de désactivation par option (`models.dart:632-637`).
  - **CRUD inline** (`showCrudButton(state, Crud.create, onCrud:)` + `crudRepository` + `allowErpRessourceCrud`, `2644-2646`) : créer/modifier l'entité liée **depuis le sélecteur**.
  - `stateChoiceItems` : source alternative lue depuis **un autre champ** de l'`editionState` (`2491-2497`).

**État zcrud actuel** (`z_relation_field_widget.dart`) : `StatelessWidget` rendant un `DropdownButtonFormField` sur une liste `options: List<ZFieldChoice>` **statique** (défaut vide → contrôle **désactivé mais accessible**). Le doc-comment annonce déjà le point de câblage « E4 » : *« remplacer `options` par une résolution de source (via un port injecté au scope) fournissant `List<ZFieldChoice>` (ou un flux) — la signature `value`/`onChanged` du widget reste inchangée »*. Le dispatcher (`z_field_widget.dart:368-373`) route la famille `relation` sans passer de source. **DP-5 livre ce câblage.**

## Approche retenue — **port de données NEUTRE injecté** (zéro backend dans le cœur)

**Décision (NON-NÉGOCIABLE, AD-1/AD-5) : le cœur n'importe aucun backend.** La source dynamique est un **port pur-Dart** (`dart:async` autorisé, aucun Flutter, aucun `cloud_firestore`/Hive) que l'app/binding implémente et **enregistre** dans le scope. Le champ `const` ne peut porter ni `Stream` ni `Function` (AD-3, émissible `ConstantReader`) : il porte seulement une **clé de source** (`String`) + des **clés de champ** de filtre. La résolution clé → source se fait au runtime via un **registre injecté**, exactement comme `ZWidgetRegistry` (AD-4).

| Besoin DODLP | Mécanisme zcrud (déclaratif + seam neutre) |
|---|---|
| `loadRessourcesStream` (flux repo) | Port **`ZRelationSource`** (domaine, pur) : `Stream<List<ZFieldChoice>> options(Map<String,Object?> filterContext)`. Neutre : l'app l'implémente sur Firestore/Hive/mémoire. AD-5 (`Stream<List<T>>` nu). |
| `ressourceFilter(editionState, item)` | Le `filterContext` passé à `options(...)` = **snapshot des champs référencés** (déclarés dans `ZRelationConfig.filterKeys`). La source filtre en interne. Abonnement **ciblé** aux tranches `filterKeys` (SM-1, comme `refKeys` des validateurs inter-champs). |
| injection de la source | Registre instanciable **`ZRelationSourceRegistry`** (clé `String` → `ZRelationSource`), injecté via `ZcrudScope.relationSourceRegistry` (jamais un singleton statique — AD-4). Clé portée par `ZRelationConfig.sourceKey`. |
| `multiple` (chips + confirm) | Réutilise **`ZFieldSpec.multiple`** (source unique de multiplicité, comme `FileFieldConfig`) → valeur `List<Object?>` en tranche ; rendu chips + modal multi. |
| modal recherche/filtre | `ZRelationConfig.searchable` → modal de sélection avec champ de recherche (filtrage **client** sur les libellés ; a11y/RTL AD-13). |
| `choiceValueKey`/`choiceLabelKey`/`subtitle` | Portés par la **source** : elle émet directement des `ZFieldChoice{value,label}` déjà mappés (le mapping repo→choix vit côté binding, hors cœur). |
| CRUD inline (`showCrudButton`) | **HORS PÉRIMÈTRE DP-5** (classé *major* §2.4, pas *blocking* B7) : nécessite une voie d'écriture repository → **déféré à un binding** / story de suivi. Documenté ci-dessous. |
| `s2ChoiceDisabled` (prédicat par option) | **HORS PÉRIMÈTRE DP-5** (prédicat runtime = closure) : déféré ; contournement = la source n'émet pas les options non sélectionnables. Documenté. |

Aucun code manager-spécifique, aucun Flutter dans le domaine : `ZRelationSource` et `ZRelationSourceRegistry` (partie domaine du port) sont pur-Dart. Le widget consomme le flux **dans sa propre frontière de rebuild** (value-in-slice, AD-2).

## Acceptance Criteria

### Bloc A — Port neutre `ZRelationSource` (source dynamique + filtre cross-champ)

1. **Port de domaine `ZRelationSource` (pur, neutre).** Un port public `abstract class ZRelationSource` existe dans la couche `domain` de `zcrud_core` (`lib/src/domain/ports/z_relation_source.dart`), pur-Dart (`dart:async` autorisé, **aucun** import Flutter/`cloud_firestore`/Hive — AD-1), exporté par le barrel `domain.dart`. Il expose : `Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext)` — un **flux live** d'options `{value,label}` (AD-5 : `Stream<List<T>>` nu). Le doc-comment précise que **aucune implémentation concrète ne vit dans le cœur** : l'app/binding l'implémente sur son backend et l'enregistre au scope.

2. **Filtre cross-champ via `filterContext`.** `options(filterContext)` reçoit un `Map<String, Object?>` = **snapshot des valeurs** des champs déclarés `ZRelationConfig.filterKeys` (les « autres champs » de l'`editionState` DODLP). La source filtre en interne (équivalent `ressourceFilter(editionState, item)`). `filterKeys` vide → `filterContext` vide → aucun filtre cross-champ (source non filtrée). Le port ne présume **aucune** sémantique de filtre côté cœur (neutralité totale).

3. **Registre instanciable `ZRelationSourceRegistry` (AD-4).** Un registre public `ZRelationSourceRegistry` (couche `presentation` OU `domain` selon pureté — pur-Dart, aucun Flutter requis → **domaine**), aligné sur `ZWidgetRegistry`/`ZOpenRegistry` : `register(String key, ZRelationSource source)` (collision → `throw ZDuplicateRegistrationError`), `isRegistered(key)`, `keys`, `sourceFor(key)` strict (`throw ZUnregisteredTypeError` si absent), `trySourceFor(key)` défensif (`null` si absent — AD-10). **Instanciable et injecté**, jamais un singleton statique mutable. Exporté par le barrel approprié.

### Bloc B — Config déclarative `ZRelationConfig` (additive, `const`)

4. **`ZRelationConfig extends ZFieldConfig`.** Nouvelle config `const` pur-données dans `z_field_config.dart` (point d'extension AD-4) : `sourceKey` (`String?`, clé de résolution dans le registre — `null` ⇒ pas de source dynamique ⇒ repli statique), `filterKeys` (`List<String> = const <String>[]`, champs formant le `filterContext`), `searchable` (`bool = false`, active le modal de recherche). Champs `final`, `==`/`hashCode` (égalité profonde de `filterKeys` via le helper `_listEquals` existant), aucun `Function`, tout `const` (émissible `ConstantReader`/`_emitConst`). **La multiplicité réutilise `ZFieldSpec.multiple`** (source unique — ne PAS dupliquer un `multiple` dans la config).

5. **Rétro-compat champ sans config.** Un `ZFieldSpec(type: relation)` sans `config` (ou `config` d'un autre type) reste rendu par le dropdown statique actuel sur `choices`/`options` (comportement E3-3a **identique**). Le générateur (`@ZcrudField(config: ZRelationConfig(...))`) reste compatible ; aucun champ obligatoire ajouté à `ZFieldSpec`.

### Bloc C — `ZRelationFieldWidget` consomme la source (stream + filtre + multi + modal)

6. **Résolution de source + abonnement au flux.** `ZRelationFieldWidget` (devenu `StatefulWidget`) reçoit, **en plus** de ses params actuels (`field`, `value`, `onChanged`, `options`), des params **additifs optionnels** : `source` (`ZRelationSource?`), `filterContext` (`Map<String, Object?> = const {}`), `multiple` (`bool = false`). Si `source != null` : il **s'abonne une fois** (`initState`) à `source.options(filterContext)`, conserve la dernière `List<ZFieldChoice>` en `State`, `cancel` l'abonnement en `dispose`, et **se ré-abonne** en `didUpdateWidget` **uniquement** si `filterContext` a changé (comparaison de contenu) ou si la `source` change. Le flux **remplace** `options` comme source d'affichage. L'abonnement (un seul `StreamSubscription`) est **possédé par le `State`** (jamais recréé à chaque build — AD-2).

7. **Repli statique strict (rétro-compat).** Si `source == null` (registre non injecté, clé absente/non enregistrée, ou `config == null`) : rendu **identique** à l'actuel (`DropdownButtonFormField` sur `options`, désactivé si vide, libellé + indice l10n, jamais un crash). Aucune régression du test/usage E3-3a.

8. **Multi-sélection (chips) via `ZFieldSpec.multiple`.** Si `multiple == true` : la tranche porte une `List<Object?>` de valeurs sélectionnées ; le rendu affiche les sélections en **chips** (supprimables, cibles ≥ 48 dp, `Semantics`) + un déclencheur d'ajout ouvrant un modal multi (confirmation). `onChanged` écrit la `List<Object?>` mise à jour. Si `multiple == false` : sélection scalaire (dropdown ou modal mono selon `searchable`), `onChanged` écrit la valeur scalaire. Valeur courante non présente dans les options live → non sélectionnée (pas de crash), cohérent avec la garde `values.contains(value)` actuelle.

9. **Modal de recherche (`searchable`).** Si `searchable == true` : le déclencheur ouvre un modal (`showModalBottomSheet`/dialog) listant les options live avec un **champ de recherche** filtrant **côté client** sur `ZFieldChoice.label` (insensible à la casse), `ListView.builder`, sélection mono/multi selon `multiple`, boutons **Confirmer/Fermer** l10n (`'confirm'`/`'close'`/`'search'`). a11y/RTL : `EdgeInsetsDirectional`, `TextAlign.start`, cibles ≥ 48 dp, `Semantics` explicites (AD-13). Si `searchable == false` et mono : conserver le `DropdownButtonFormField` (léger).

10. **États de flux défensifs (AD-10).** Avant la 1ʳᵉ émission : contrôle en état **chargement** (désactivé + libellé `'loading'`, jamais un crash). Émission vide : contrôle actif mais sans option (mono désactivé comme aujourd'hui ; multi = liste vide). **Erreur du flux** (`onError`) : capturée, **aucune exception propagée** au build, conservation de la dernière liste connue (ou vide), contrôle utilisable/dégradé proprement. Le widget ne lève jamais.

### Bloc D — Câblage dispatcher `z_field_widget.dart` (SM-1 préservé)

11. **Le dispatcher résout la source + le `filterContext` + `multiple`.** Dans `z_field_widget.dart`, la branche `EditionFamily.relation` (`_buildControl`) : (a) résout `ZRelationSource?` via `ZcrudScope.maybeOf(context)?.relationSourceRegistry?.trySourceFor(sourceKey)` où `sourceKey` provient de `field.config is ZRelationConfig ? config.sourceKey : null` ; (b) construit `filterContext` en lisant `widget.controller.valueOf(k)` pour chaque `k` de `config.filterKeys` ; (c) passe `multiple: field.multiple`. Si pas de `ZRelationConfig` ou pas de registre/source → `source: null` (repli statique, AC7).

12. **Abonnement ciblé aux `filterKeys` (SM-1 / AD-2).** Le dispatcher s'abonne **uniquement** aux tranches des `config.filterKeys` (via `controller.fieldListenable(k)`, exactement comme le pattern `_refListenables`/`refKeys` inter-champs existant, `z_field_widget.dart:129-151`) : un changement d'un champ de filtre re-lit le `filterContext` et reconstruit **la seule** frontière de rebuild de CE champ relation (ré-abonnement du flux avec le nouveau contexte). **Aucun** rebuild global, **aucune** frappe dans un champ tiers hors `filterKeys` ne touche le champ relation. Si `filterKeys` vide → aucun abonnement cross-champ ajouté. La frontière value-in-slice (`ZFieldListenableBuilder`) reste la borne (AD-2).

13. **Injection scope `relationSourceRegistry`.** `ZcrudScope` gagne un seam **additif** `final ZRelationSourceRegistry? relationSourceRegistry` (défaut `null` → repli statique universel), intégré au constructeur `const`, au doc-comment (aligné sur `widgetRegistry`), et à `updateShouldNotify` (`!identical(...)`). Défaut `null` = rétro-compat totale (tout scope existant compile et se comporte à l'identique).

### Transverse — invariants & non-régression

14. **AD-1 / graphe inchangé.** `zcrud_core` out-degree 0 : aucune dépendance ajoutée ; `ZRelationSource`/`ZRelationSourceRegistry` pur-Dart (`dart:async` seulement). Aucun `cloud_firestore`/Hive/gestionnaire d'état importé. `graph_proof` vert.

15. **AD-2 / SM-1 non régressés.** Un seul `StreamSubscription` par champ relation, possédé par le `State`, jamais recréé dans la voie de build. Taper 100 caractères dans un champ **hors `filterKeys`** ne reconstruit pas le champ relation ni ne perd le focus. Une frappe dans un champ `filterKeys` recalcule **uniquement** ce champ relation (ré-abonnement ciblé), pas le formulaire. Aucun `setState` à l'échelle du formulaire.

16. **AD-4 / AD-5 / AD-10.** Registre **instanciable** injecté (jamais statique) ; port = `Stream<List<T>>` nu ; **défensif de bout en bout** : registre absent / clé non enregistrée / config absente → repli statique ; flux en erreur → aucune exception ; option courante absente → non sélectionnée ; jamais de `throw` dans le build.

17. **AD-13 (a11y/RTL).** Chips, modal, dropdown : `EdgeInsetsDirectional`/`AlignmentDirectional`, `TextAlign.start/end`, `ListView.builder`, cibles ≥ 48 dp, `Semantics` (libellé du champ, action ajouter/supprimer, résultat de recherche `liveRegion`). Thème via `Theme.of`/`ZcrudTheme` (aucune couleur/inset non directionnel en dur — FR-26).

18. **Rétro-compatibilité stricte & barrels.** Aucune API publique renommée/retirée. Ajouts au barrel : `domain.dart` (export `z_relation_source.dart` + `ZRelationSourceRegistry` s'il est en domaine) ; `z_field_config.dart` déjà exporté (ajout `ZRelationConfig` interne) ; `zcrud_core.dart` (scope déjà exporté ; export du registre s'il est en présentation). `ZRelationFieldWidget` garde ses params existants (nouveaux params **optionnels à défaut rétro-compat**). Les tests existants du catalogue/dispatch restent verts.

## Tasks / Subtasks

- [x] **T1 — Port neutre + registre (AC1, AC2, AC3)**
  - [x] Créer `lib/src/domain/ports/z_relation_source.dart` : `abstract class ZRelationSource { const ZRelationSource(); Stream<List<ZFieldChoice>> options(Map<String, Object?> filterContext); }`, doc-comment (neutralité, aucune impl cœur), `dart:async` seulement.
  - [x] Créer `ZRelationSourceRegistry` (même fichier, pur-Dart) aligné sur `ZWidgetRegistry` : `register`/`isRegistered`/`keys`/`sourceFor` (strict `throw`)/`trySourceFor` (défensif `null`), réutilise `ZDuplicateRegistrationError`/`ZUnregisteredTypeError`.
  - [x] Exporté par `domain.dart` (port + registre — domaine pur).
- [x] **T2 — Config `ZRelationConfig` (AC4, AC5)**
  - [x] `z_field_config.dart` : ajouté `class ZRelationConfig extends ZFieldConfig` (`sourceKey`, `filterKeys=const[]`, `searchable=false`), `==`/`hashCode` (`_listEquals(filterKeys)`), `const`, aucun `Function`.
  - [x] Émission `const` OK (config pur-données comme `ZDateConfig`/`FileFieldConfig`) — codegen sans objet (aucune annotation modifiée).
- [x] **T3 — Widget dynamique (AC6..AC10, AC17)**
  - [x] `z_relation_field_widget.dart` : `StatelessWidget → StatefulWidget` ; params additifs optionnels `source`/`filterContext`/`multiple`/`searchable` ; `StreamSubscription` unique (create `initState`, `cancel` `dispose`, ré-abonnement `didUpdateWidget` si `filterContext`/`source` changent).
  - [x] Rendu : `source==null` → dropdown statique (repli strict) ; `source!=null` mono non-searchable → dropdown live ; mono searchable → modal recherche ; multi → chips + modal multi (confirmation).
  - [x] États : chargement (`'loading'`, désactivé), vide, erreur (`onError` capturé, dernière liste connue), option courante absente → non sélectionnée.
  - [x] a11y/RTL (AD-13) : chips ≥ 48 dp (`materialTapTargetSize.padded`), `Semantics`, `ListView.builder`, directionnel (`EdgeInsetsDirectional`/`AlignmentDirectional`/`TextAlign.start`), l10n (`select`/`search`/`confirm`/`close`/`loading`/`add`/`remove`/`empty`).
- [x] **T4 — Dispatcher + scope (AC11, AC12, AC13, AC15)**
  - [x] `zcrud_scope.dart` : ajouté `final ZRelationSourceRegistry? relationSourceRegistry` (constructeur `const`, doc, `updateShouldNotify`).
  - [x] `z_field_widget.dart` : branche `relation` → résout source via scope+`config.sourceKey`, bâtit `filterContext` depuis `controller.valueOf` sur `config.filterKeys`, passe `multiple: field.multiple`, `searchable`, `options: field.choices`.
  - [x] Abonnement **ciblé** aux `filterKeys` (fusion `controller.fieldListenable(k)` dans `_refListenables` — même canal que `refKeys`) — SM-1 préservé.
- [x] **T5 — Barrels + l10n (AC18)**
  - [x] Exports barrel `domain.dart` additifs (port+registre) ; `z_field_config.dart` (transitif) et `zcrud_scope.dart` déjà exportés par `zcrud_core.dart`.
  - [x] Aucune clé l10n manquante — `select`/`search`/`confirm`/`close`/`loading`/`add`/`remove`/`empty` déjà présentes (EN+FR).
- [x] **T6 — Tests (AC1..AC18)**
  - [x] Tests widget (`flutter_test`, `test/presentation/edition/z_relation_field_widget_test.dart`) : source mockée → options live (1 abonnement) ; filtre cross-champ (change `filterKeys` re-query, frappe hors `filterKeys` = 0 re-query) ; multi (chips add via modal/remove via chip, `onChanged` liste) ; modal recherche (filtrage client + sélection) ; repli statique (registre `null` / clé absente = dropdown) ; états vide/erreur/chargement (défensif) ; SM-1 (100 frappes hors `filterKeys` = 0 rebuild relation).
  - [x] Tests domaine (`package:test`, `test/domain/ports/z_relation_source_test.dart`) : `ZRelationSourceRegistry` (register/collision/strict/défensif/non-singleton/`Stream` nu) ; `ZRelationConfig` égalité/`const`. Pureté (`domain_purity_test` + `domain_entrypoint_dart_test`) verte.
  - [x] Rejoué `analyze` RC=0 + `flutter test` RC=0 (683) + `graph_proof` (CORE OUT=0) + entrypoint pur-Dart. `melos run generate` sans objet (aucune annotation touchée).

## Dev Notes

### Fichiers touchés (tous `zcrud_core`)

- **NEW** `lib/src/domain/ports/z_relation_source.dart` — port `ZRelationSource` + `ZRelationSourceRegistry` (pur-Dart, `dart:async`). Modèle : `z_widget_registry.dart` (API register/try/strict) et `cloud_storage_repository.dart` (port neutre).
- **UPDATE** `lib/src/domain/edition/z_field_config.dart` — ajouter `ZRelationConfig`. **État actuel** : base `abstract ZFieldConfig` + `ZTextConfig`/`ZNumberConfig`/`ZSliderConfig`/`ZRatingConfig`/`FileFieldConfig`/`ZDateConfig`, helper `_listEquals` pur. **À préserver** : tout `const`, `_listEquals` réutilisé, aucune dépendance ajoutée.
- **UPDATE** `lib/src/presentation/edition/families/z_relation_field_widget.dart` — Stateful + consommation du flux. **État actuel** : `StatelessWidget`, `DropdownButtonFormField` sur `options` statique (défaut vide → désactivé accessible), garde `values.contains(value)`, `key: ValueKey(current)` (L-3, relit `initialValue` sur changement externe). **À préserver** : repli statique **identique** quand `source==null` ; garde L-3 ; libellé/indice l10n ; a11y.
- **UPDATE** `lib/src/presentation/edition/z_field_widget.dart` — **⚠️ FICHIER PARTAGÉ (dispatcher, `zcrud_core`)** : branche `EditionFamily.relation` (l.368-373) + abonnement ciblé `filterKeys`. **État actuel** : dispatch value-in-slice sous `ZFieldListenableBuilder`, pattern `_refListenables`/`refKeys` déjà présent (l.129-151, 145-147) pour l'abonnement ciblé inter-champs — **le réutiliser** pour `filterKeys`. `_revealAndRefs = Listenable.merge([reveal, ..._refListenables])`. **À préserver** : frontière de rebuild = tranche (AD-2), contrôleur texte alloué seulement pour familles clavier, `switch` exhaustif sans `default`, place stable posée par `DynamicEdition`.
- **UPDATE** `lib/src/presentation/zcrud_scope.dart` — seam `relationSourceRegistry` (constructeur `const` + `updateShouldNotify`). **À préserver** : zéro-config par défaut (`null`), tous les seams existants inchangés.
- **UPDATE** `lib/domain.dart` / `lib/zcrud_core.dart` — exports additifs (port/registre/config déjà transitivement exporté via `z_field_config.dart`).
- **UPDATE** `lib/src/presentation/l10n/z_localizations.dart` — clés éventuelles (EN+FR), si un libellé manque (réutiliser l'existant en priorité).

### Frontière neutralité (rappel AD-1/AD-5)

Le cœur ne connaît **jamais** Firestore, `dodlp.streamAll<T>()`, ni un `crudRepository`. Il connaît : un **port** (`Stream<List<ZFieldChoice>>`), une **clé de source** (`String`), des **clés de filtre** (`List<String>`) et un **snapshot de contexte** (`Map`). L'impl concrète (repository + mapping entité→`ZFieldChoice` + filtre métier) vit **entièrement** côté app/binding (E7 DODLP / `zcrud_firestore`), enregistrée dans `ZcrudScope(relationSourceRegistry: registry)`. C'est le « seam de source » : structure déclarative + données injectées au runtime, **zéro backend dans le cœur**.

### Abonnement ciblé = réutiliser le pattern `refKeys` existant (SM-1)

`z_field_widget.dart` sait déjà s'abonner **ciblément** à d'autres tranches sans rebuild global (validateurs inter-champs, `_refListenables`, l.129-151). Les `filterKeys` d'une relation suivent **exactement** ce mécanisme : fusionner `controller.fieldListenable(k)` (pour chaque `k` de `config.filterKeys`) dans l'enveloppe réactive **de ce seul champ**. Une frappe dans un champ de filtre → recompute du `filterContext` → ré-abonnement du flux de CE champ, jamais un rebuild du formulaire. Ne PAS ajouter les `filterKeys` à un canal global.

### Hors périmètre DP-5 (défére / besoins binding détectés)

- **Impl concrète `ZRelationSource`** (flux repo Firestore/Hive + mapping entité→`ZFieldChoice` + filtre métier) → **binding/app** (`zcrud_firestore` ou app DODLP E7). Le cœur ne fournit **aucune** impl (comme `ZFilePicker`/`CloudStorageRepository`/`ZListRenderer`).
- **CRUD inline** (`showCrudButton` DODLP : créer/modifier l'entité liée depuis le sélecteur, `allowErpRessourceCrud`, `crudRepository`) → classé *major* (§2.4), **pas** B7. Nécessite une voie d'écriture repository → **binding** + story de suivi (DP-12+). À NE PAS implémenter ici.
- **`s2ChoiceDisabled`** (prédicat de désactivation par option, closure runtime) → déféré ; contournement : la source n'émet pas les options non sélectionnables. Documenter dans le doc-comment de `ZRelationSource`.
- **`stateChoiceItems`** (source d'options lue depuis un autre champ) : couvert **conceptuellement** par `filterKeys`/le contexte, mais l'aiguillage « options depuis un champ » sans repository peut rester un cas app ; ne PAS sur-concevoir dans DP-5.

### Pièges à éviter

- ❌ Ne PAS importer un backend (`cloud_firestore`/Hive) ni un gestionnaire d'état dans le cœur (AD-1).
- ❌ Ne PAS recréer le `StreamSubscription` dans `build` (fuite + rebuild — AD-2) : create en `initState`, `cancel` en `dispose`, ré-abonnement contrôlé en `didUpdateWidget`.
- ❌ Ne PAS ajouter les `filterKeys` à un canal réactif global (régression SM-1 : le formulaire entier se reconstruirait).
- ❌ Ne PAS casser le repli statique : `source==null` DOIT rendre exactement le dropdown E3-3a.
- ❌ Ne PAS mettre un `multiple` dans `ZRelationConfig` (double source ; utiliser `ZFieldSpec.multiple`).
- ❌ Ne PAS lever sur flux en erreur / clé absente / registre absent (AD-10).
- ❌ Ne PAS introduire un `ZRelationSource` **statique/singleton** (AD-4 : registre instanciable injecté).

## Testing Requirements

Framework : `flutter_test` (widget/présentation) + `package:test` (domaine pur). Rejouer `melos run generate` → `analyze` (RC=0) → `flutter test` (RC=0) sur `zcrud_core` avant `review`.

**Tests widget (`test/presentation/edition/…relation…_test.dart`) :**
- **Source mockée** : `ZRelationSource` de test émettant une `List<ZFieldChoice>` contrôlée via un `StreamController` → options live rendues ; nouvelle émission → options mises à jour (un seul abonnement, pas de recréation).
- **Filtre cross-champ** : un champ `filterKeys: ['parent']` ; changer la tranche `parent` → `filterContext` re-passé à `options(...)` (vérifier via un mock enregistrant les contextes reçus) ; les options reflètent le filtre. Frappe sur un champ **hors** `filterKeys` → aucun ré-appel (SM-1).
- **Multi** (`ZFieldSpec.multiple: true`) : sélectionner 2 options → chips affichées, `onChanged` reçoit `List<Object?>` ; supprimer un chip → liste mise à jour.
- **Modal recherche** (`searchable: true`) : ouvrir le modal, saisir un terme → filtrage client sur `label` ; confirmer → sélection écrite.
- **Repli statique** : `relationSourceRegistry == null` OU `sourceKey` non enregistré → dropdown statique sur `options`/`choices` (comportement E3-3a), pas de crash.
- **États défensifs (AD-10)** : avant 1ʳᵉ émission → chargement/désactivé ; émission `[]` → vide ; flux `addError(...)` → aucun crash, contrôle dégradé. Option courante absente des options live → non sélectionnée.
- **SM-1 / AD-2** : sur formulaire de référence, taper 100 caractères dans un champ non lié → 0 rebuild du champ relation (compteur `onBuild`), focus conservé.

**Tests domaine (`test/domain/…`, pur) :**
- `ZRelationSourceRegistry` : `register` + `isRegistered`/`keys` ; collision → `ZDuplicateRegistrationError` ; `sourceFor` absent → `ZUnregisteredTypeError` ; `trySourceFor` absent → `null`.
- `ZRelationConfig` : égalité/`hashCode` (dont `filterKeys` profond), `const`.
- Pureté : `domain_purity_test.dart` reste vert (aucun import Flutter dans le port/registre/config).

## Architecture Compliance

- **AD-1** : `zcrud_core` out-degree 0 — port/registre/config pur-Dart (`dart:async`), aucune dépendance backend ; impl concrète hors cœur (binding).
- **AD-2 / SM-1** : abonnement flux possédé par le `State` (create/dispose, non recréé) ; abonnement cross-champ **ciblé** aux `filterKeys` (pattern `refKeys` existant) ; frontière value-in-slice inchangée ; aucun `setState` global.
- **AD-4** : registre **instanciable** injecté via `ZcrudScope.relationSourceRegistry` (jamais statique) ; extension par enregistrement (`register(key, source)`), aucune classe scellée.
- **AD-5** : port = `Stream<List<ZFieldChoice>>` **nu** (pas de `Either` sur un flux live) ; erreurs gérées **défensivement** dans le widget (AD-10), aucun type backend dans le domaine.
- **AD-10** : totalité défensive — registre/clé/config absents → repli statique ; flux en erreur → aucun crash ; option manquante → non sélectionnée ; évolution **additive** (nouveaux port/registre/config, params optionnels, défauts rétro-compat).
- **AD-13** : chips/modal/dropdown a11y + RTL (directionnel, ≥ 48 dp, `Semantics`, `ListView.builder`, `liveRegion` recherche) ; thème injecté (FR-26).

## Definition of Done

- [x] AC1..AC18 satisfaits.
- [x] Source dynamique + filtre cross-champ + multi + modal fonctionnels (tests source mockée / filtre / multi / recherche verts).
- [x] Rétro-compat vérifiée : champ `relation` sans source = dropdown statique E3-3a identique ; scope sans `relationSourceRegistry` inchangé ; `ZRelationFieldWidget` params existants inchangés.
- [x] SM-1 / AD-2 non régressés (frappe hors `filterKeys` = 0 rebuild relation, focus conservé ; abonnement flux unique).
- [x] Neutralité AD-1/AD-5 : aucun backend/gestionnaire d'état dans le cœur ; `graph_proof` vert ; `Stream<List<T>>` nu.
- [x] `analyze` RC=0, `flutter test` RC=0 (zcrud_core) ; `melos run generate` sans objet (aucune annotation touchée).
- [x] Aucune modification hors `zcrud_core` (+ tests) ; **aucun fichier DODLP touché**.

## Project Context Reference

- Gap source : `docs/dodlp-edition-parity-gap.md` §1 (bloquant #7), §2.2 (`crudDataSelect → relation`), §2.4 (source dynamique/filtre/multi/modal/CRUD inline), §3 (action B7).
- Épics : `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md` (E-DP · DP-5).
- Architecture (AD-1/2/4/5/10/13) : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`.
- DODLP (lecture seule) : `/home/zakarius/DEV/dodlp-otr/lib/modules/data_crud/models.dart:596,632-637,1045-1055` (ressourceFilter/loadRessourcesStream), `.../presentation/views/edition_screen.dart:2489-2668` (StreamBuilder + SmartSelect S2 + multi + modal + showCrudButton).
- Patterns cœur réutilisés : `z_widget_registry.dart` (registre AD-4), `z_field_widget.dart:129-151` (abonnement ciblé `refKeys`), `z_app_file_field_widget.dart`/`cloud_storage_repository.dart` (seam neutre injecté via scope).
- Story précédente de l'épic : `dp-2-displaycondition-etendu.md` (même épic ; même discipline additive/rétro-compat sur le cœur partagé).

## Dev Agent Record

### Implementation Plan

Port neutre `ZRelationSource` (pur-Dart `dart:async`) + registre instanciable
`ZRelationSourceRegistry` dans `domain/ports/`, injecté via
`ZcrudScope.relationSourceRegistry`. Clé de source + `filterKeys` + `searchable`
portés par `ZRelationConfig` (`const`, additif). Le widget passe `Stateful` :
abonnement unique au flux dans le `State` (create `initState` / `cancel`
`dispose` / ré-abonnement contrôlé `didUpdateWidget` sur changement
source/`filterContext`). Le dispatcher résout la source + bâtit le `filterContext`
et s'abonne **ciblément** aux `filterKeys` via le canal `_refListenables`
existant (même mécanique que les validateurs inter-champs `refKeys` — SM-1).

### Completion Notes

- **Statut par AC** : AC1..AC18 satisfaits. Détail : port neutre (AC1/AC2),
  registre AD-4 (AC3), config `const` additive (AC4/AC5), abonnement flux
  possédé par le State (AC6), repli statique strict (AC7), multi chips (AC8),
  modal recherche client (AC9), états défensifs chargement/vide/erreur (AC10),
  résolution source+`filterContext`+`multiple` au dispatcher (AC11), abonnement
  ciblé `filterKeys` (AC12), seam scope (AC13), graphe inchangé CORE OUT=0
  (AC14), SM-1 non régressé (AC15), défensif de bout en bout (AC16), a11y/RTL
  (AC17), rétro-compat/barrels (AC18).
- **Additivité/pureté** : aucune API publique renommée/retirée ; nouveaux params
  du widget optionnels à défaut rétro-compat ; `relationSourceRegistry` défaut
  `null` (repli statique universel) ; `domain.dart` reste Flutter-free (garde
  `domain_entrypoint_dart_test` verte). `graph_proof` : ACYCLIQUE OK, CORE OUT=0.
- **AD-1/AD-5** : aucun backend/manager dans le cœur ; port = `Stream<List<
  ZFieldChoice>>` **nu** ; impl concrète déférée au binding.
- **SM-1** : un seul `StreamSubscription` par champ relation possédé par le
  `State` (jamais recréé dans `build`) ; 100 frappes hors `filterKeys` → 0
  rebuild du champ relation (test compteur `onBuild`), structurel == 1.
- **Vérif verte réelle** : `dart analyze` RC=0 (No issues found) ;
  `flutter test` RC=0 (683 tests) ; `graph_proof.py` OK ; entrypoint pur-Dart OK.
  `melos run generate` **sans objet** (aucune annotation `@ZcrudModel`/
  `@ZcrudField`/`@JsonSerializable` touchée).
- **Besoins binding déférés (documentés, non implémentés)** : impl concrète
  `ZRelationSource` (flux repository Firestore/Hive + mapping entité→`ZFieldChoice`
  + filtre métier) → `zcrud_firestore`/app DODLP E7 ; **CRUD inline**
  (`showCrudButton`/`crudRepository`) → *major* DP-12+ ; **`s2ChoiceDisabled`**
  (prédicat runtime) → contournement = la source n'émet pas les options non
  sélectionnables ; **enregistrement des sources** dans `ZcrudScope(
  relationSourceRegistry:)` → app.
- **Points de contact cœur partagés (additif strict)** : `z_field_widget.dart`
  (branche relation + abonnement `filterKeys` — additionné SANS toucher la case
  `date` DP-10), `z_field_config.dart` (`ZRelationConfig` — additionné à côté de
  `ZDateConfig`), `zcrud_scope.dart` (seam + `updateShouldNotify`), `domain.dart`
  (export). Aucun autre writer cœur concurrent.

### File List

**NEW**
- `packages/zcrud_core/lib/src/domain/ports/z_relation_source.dart`
- `packages/zcrud_core/test/domain/ports/z_relation_source_test.dart`
- `packages/zcrud_core/test/presentation/edition/z_relation_field_widget_test.dart`

**MODIFIED**
- `packages/zcrud_core/lib/src/domain/edition/z_field_config.dart` (`ZRelationConfig`)
- `packages/zcrud_core/lib/src/presentation/edition/families/z_relation_field_widget.dart` (Stateful + flux + chips + modal)
- `packages/zcrud_core/lib/src/presentation/edition/z_field_widget.dart` (branche relation + abonnement `filterKeys`)
- `packages/zcrud_core/lib/src/presentation/zcrud_scope.dart` (seam `relationSourceRegistry`)
- `packages/zcrud_core/lib/domain.dart` (export port/registre)

## Change Log

| Date | Version | Description | Auteur |
|---|---|---|---|
| 2026-07-11 | 0.1 | Création story (context engine) — DP-5 relation dynamique crudDataSelect (B7) | bmad-create-story |
| 2026-07-11 | 1.0 | Implémentation DP-5 : port neutre `ZRelationSource` + registre AD-4 + `ZRelationConfig` + widget Stateful (flux/chips/modal) + dispatcher/scope + tests. Vert (analyze RC=0, 683 tests, graph CORE OUT=0). | bmad-dev-story |
