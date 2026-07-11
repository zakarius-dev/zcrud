# Story DP.14: ACL édition étendu (parité DODLP, gap M7)

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a **intégrateur DODLP → zcrud (module « Étude »)**,
I want **que le port d'autorisation `ZAcl`/`ZCrudAction` du cœur couvre les 6 actions étendues du `RessourceACL` DODLP (copy/archive/publish/clear/validate/history) et soit consommable côté `DynamicEdition` (gate d'actions au niveau formulaire), en plus du filtrage LISTE (E4-4) et sous-liste compacte (DP-6) déjà câblés**,
so that **les écrans d'édition portés depuis DODLP puissent masquer/désactiver les actions de formulaire (copier, archiver, publier, vider, valider, historique) selon les droits, sans perdre de capacité au portage — tout en gardant une rétro-compatibilité additive stricte et l'objectif produit n°1 (SM-1) intact.**

## Contexte & gap (source of truth)

- Gap **M7** de la matrice de parité : `ACL formulaire (RessourceACL 11 flags) + aclBuilder sub-items` — DODLP expose `read/create/update/delete/copy/restore/archive/publish/clear/validate/history` ; zcrud n'a que 5 actions et ne les consomme que côté LISTE. [Source: docs/dodlp-edition-parity-gap.md#2.6 (ligne 156), #3 MAJOR M7 (ligne 206)]
- Référence DODLP (**lecture seule**, ne rien modifier) : `dodlp-otr/lib/src/domain/security/ressource_acl.dart:3-160` — classe `RessourceACL` (Equatable) à 11 `bool` : `read, create, update, delete, copy, restore, archive, publish, clear, validate, history`.
- État zcrud actuel :
  - `ZCrudAction` = `{ view, create, update, delete, restore }` (5 valeurs, camelCase). [Source: packages/zcrud_core/lib/src/domain/ports/z_acl.dart:10-25]
  - `view` est le miroir de `read` DODLP (déjà mappé). Les **6 manquantes** = `copy, archive, publish, clear, validate, history`.
  - `restore` est déjà présent (E4-4). Donc l'extension ajoute **exactement 6** valeurs.
  - `ZAcl.can(action, {target, collectionId})` synchrone ; `ZAllowAllAcl` permissif par défaut. [z_acl.dart:35-50]

### Mapping DODLP `RessourceACL` → `ZCrudAction`

| DODLP flag | ZCrudAction | Statut |
|---|---|---|
| `read` | `view` | existant |
| `create` | `create` | existant |
| `update` | `update` | existant |
| `delete` | `delete` | existant |
| `restore` | `restore` | existant (E4-4) |
| `copy` | **`copy`** | **AJOUT** |
| `archive` | **`archive`** | **AJOUT** |
| `publish` | **`publish`** | **AJOUT** |
| `clear` | **`clear`** | **AJOUT** |
| `validate` | **`validate`** | **AJOUT** |
| `history` | **`history`** | **AJOUT** |

## Acceptance Criteria

1. **Enum étendu, additif strict.** `ZCrudAction` déclare **6 nouvelles valeurs en camelCase** — `copy`, `archive`, `publish`, `clear`, `validate`, `history` — **APRÈS** les 5 existantes, dans cet ordre, sans réordonner ni renommer `view/create/update/delete/restore`. `ZCrudAction.values.length == 11`. Chaque nouvelle valeur porte un doc-comment `///` (rôle + référence DODLP). [z_acl.dart:10-25]
2. **Rétro-compat des consommateurs LISTE/sub-liste (E4-4 / DP-6) : zéro régression.** Les call-sites existants restent valides et au comportement inchangé : `z_row_action.dart` (`requiredPermission: ZCrudAction.delete/restore/update`), `z_sub_list_field_widget.dart:505-510` (create/view/update/delete en mode compact hide). Aucun `switch`/`case` exhaustif sur `ZCrudAction` n'existe dans le repo (vérifié) — l'ajout ne casse aucune exhaustivité ; **si** un tel `switch` était introduit par le dev, il DOIT comporter une branche `default` défensive (AD-10).
3. **`ZAllowAllAcl` couvre les 6 nouvelles.** L'implémentation permissive par défaut retourne `true` pour toutes les valeurs, y compris `copy/archive/publish/clear/validate/history` — vérifié par itération sur `ZCrudAction.values` (le test qui affirmait `hasLength(5)` est mis à jour à `11` et couvre nominativement les 6 nouvelles). [z_acl_test.dart:26-60]
4. **Consommation optionnelle côté `DynamicEdition` (gate d'actions au niveau formulaire, additif).** `DynamicEdition` gagne un moyen **optionnel** de gater des **actions de niveau formulaire** (barre d'actions en-tête/pied) par `ZAcl` :
   - un paramètre optionnel `acl` (type `ZAcl`, **défaut `const ZAllowAllAcl()`**) — quand non fourni, comportement **strictement identique** à E3-1..E3-4/DP-2/DP-9 (aucune action rendue, aucun gate) ;
   - un paramètre optionnel `formActions` (liste de descripteurs d'action portant chacun un `ZCrudAction requiredPermission`), rendus dans une zone d'actions ; chaque action est **masquée** (mode `hide`, cohérent avec DP-6) si `acl.can(requiredPermission, collectionId: ...)` est `false`. `formActions` vide (défaut) ⇒ aucune zone d'actions rendue (rétro-compat pixel).
   - Le `collectionId` éventuel est passé tel quel à `acl.can(...)` (seam neutre, pas de règle métier dans le cœur — AD-16).
5. **SM-1 NON régressé (objectif produit n°1).** La zone d'actions et le gate ACL sont évalués **uniquement** dans la voie de (re)build **structurel** de `DynamicEdition` (jamais abonnés à une tranche de valeur). Taper 100 caractères dans un champ ne ré-exécute PAS le gate ACL ni ne reconstruit la barre d'actions : `onStructuralBuild` reste stable pendant la frappe (test widget de non-régression). [dynamic_edition.dart:413-424]
6. **a11y / RTL (AD-13).** Toute action de formulaire rendue est un contrôle accessible : `Semantics`/tooltip explicite, cible tactile **≥ 48 dp**, insets **directionnels** (`EdgeInsetsDirectional`), aucune couleur codée en dur (dérivée du `ZcrudTheme`/`Theme.of` — FR-26). Aucune API directionnelle interdite (`EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`).
7. **Défensif (AD-10).** Un `formActions` `null`/vide, un `acl` absent, un `collectionId` `null`, ou une action dont le `requiredPermission` est une valeur inconnue au runtime ne font **jamais** planter le formulaire : dégradation silencieuse (action non rendue / permissif par défaut), pas d'exception.
8. **Sérialisation — additif défensif documenté.** `ZCrudAction` **n'est sérialisé nulle part** aujourd'hui (aucun `@JsonKey`, aucun `toJson/fromJson` sur cet enum — vérifié). Aucune migration de données n'est requise. Le doc-comment de l'enum consigne la posture : **s'il** devenait sérialisé, la (dé)sérialisation DOIT être défensive (`@JsonKey(unknownEnumValue: ...)` ou `fromJsonSafe → null`), les valeurs restant en **camelCase** (canonique §5) et l'évolution **additive seulement** (AD-3/AD-10).
9. **Barrel & pureté du cœur.** Les 6 nouvelles valeurs sont exportées via le barrel existant (`ZCrudAction` déjà public). `zcrud_core` reste **pur** : aucun import de gestionnaire d'état, de Firebase/Syncfusion, ni de `RessourceACL` DODLP (le mapping est documentaire, pas une dépendance de code). [CLAUDE.md AD-1/AD-2]
10. **Vérif verte.** `melos run generate` OK → `analyze` RC=0 → `flutter test` RC=0 (package `zcrud_core` au minimum), y compris les tests neufs des ACs 1/3/4/5/7.

## Tasks / Subtasks

- [x] **Task 1 — Étendre l'enum `ZCrudAction` (AC1, AC2, AC8, AC9)**
  - [x] Ajouter, **après `restore`**, les valeurs `copy`, `archive`, `publish`, `clear`, `validate`, `history` (camelCase), chacune avec un doc-comment `///` (rôle + réf DODLP `ressource_acl.dart`). [z_acl.dart:26-56]
  - [x] Compléter le doc-comment d'en-tête de l'enum avec la **posture sérialisation additive/défensive** (AC8) et le rappel « ordre additif, jamais réordonner » (AC2).
  - [x] Vérifier qu'aucun `switch` exhaustif sur `ZCrudAction` n'existe (grep → NONE) ; consigné en Dev Notes. Aucun `switch` introduit par le dev.
- [x] **Task 2 — Vérifier/couvrir `ZAllowAllAcl` (AC3)**
  - [x] Aucune modif de code (le `=> true` couvre toute valeur) ; confirmé par test (itération sur `ZCrudAction.values` + couverture nominative des 6 nouvelles).
- [x] **Task 3 — Gate d'actions au niveau `DynamicEdition` (AC4, AC5, AC6, AC7)**
  - [x] `ZFormAction { id, label, tooltip?, icon?, requiredPermission: ZCrudAction, onInvoke }` — descripteur **présentation** public (dans `dynamic_edition.dart`), pas de règle métier.
  - [x] Params optionnels `acl` (défaut `const ZAllowAllAcl()`), `formActions` (défaut `const []`), `collectionId` propagé à `acl.can(...)`.
  - [x] Barre d'actions rendue **dans la voie structurelle** (`build`/`ListenableBuilder`), chaque action filtrée `hide` par `acl.can(requiredPermission, collectionId:)`. Aucune zone si aucune action autorisée (rétro-compat pixel — AC4).
  - [x] a11y : `Semantics(button)` + `Tooltip`, cible ≥ 48 dp (`ConstrainedBox`), `EdgeInsetsDirectional`, style dérivé du thème (AC6).
  - [x] Défensif : `formActions` vide/`null`-safe, ACL qui lève ⇒ action masquée, aucune exception (AC7).
- [x] **Task 4 — Tests (AC1, AC3, AC4, AC5, AC7, AC10)**
  - [x] `z_acl_test.dart` : `ZCrudAction.values` `hasLength(11)` + ordre additif ; `ZAllowAllAcl` autorise les 6 nouvelles ; `_DenyPublishAcl` refuse uniquement `publish` ; camelCase des noms.
  - [x] Test widget `DynamicEdition` (`dynamic_edition_form_actions_test.dart`) : (a) sans `formActions` ⇒ rendu inchangé + aucune zone ; (b) `publish` refusée ⇒ absente, `archive` présente + cible ≥ 48 dp ; (c) **SM-1** : `onStructuralBuild` stable après 20 frappes ; (d/d-bis) défensif : vide + ACL par défaut / ACL qui lève ⇒ pas d'exception.
- [x] **Task 5 — Vérif verte (AC10)** : `dart analyze` RC=0 + `flutter test` (`zcrud_core`, 788) RC=0 + graph_proof ACYCLIQUE/CORE OUT=0 + purity OK. `melos run generate` sans objet (aucune annotation `@ZcrudModel`/`@ZcrudField` ajoutée).

## Dev Notes

### Recensement des `switch`/consommateurs de `ZCrudAction` (obligatoire — extension d'enum public)

Recensement réel sur `packages/**` (hors `*.g.dart`), au moment de la story :

- **Aucun `switch (…)` / `case ZCrudAction.…`** dans tout le repo → l'ajout de valeurs **ne casse aucune exhaustivité de switch**. C'est le risque principal d'une extension d'enum public ; il est **écarté ici** mais reste une consigne : si le dev introduit un `switch`, imposer une branche `default` défensive (AD-10).
- Consommateurs = **call-sites `.can(...)`** et **champ `ZCrudAction? requiredPermission`**, tous non-exhaustifs, insensibles à l'ajout :
  - `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart:505-510` — `create/view/update/delete` (mode compact hide, DP-6). **NE PAS casser** ; l'ajout est orthogonal.
  - `packages/zcrud_core/lib/src/presentation/list/z_row_action.dart:109-198` — `requiredPermission = delete/restore/update` (actions de ligne LISTE, E4-4).
  - `packages/zcrud_core/lib/src/domain/ports/z_acl.dart:38,49` — signature du port + `ZAllowAllAcl`.
- **Tests impactés** (à mettre à jour, AC3) :
  - `test/domain/z_acl_test.dart:58-59` — assertion `hasLength(5)` + libellé « couvre view/create/update/delete/restore » → **11** + libellé étendu.
  - `test/domain/z_acl_test.dart:26-48` — itération `for (action in ZCrudAction.values)` (couvrira automatiquement les 6 nouvelles ; ajouter des `expect` nominatifs).
  - `test/presentation/zcrud_scope_test.dart`, `test/presentation/list/*acl*_test.dart`, `test/presentation/edition/z_sub_list_compact_test.dart` — `_DenyAcl(Set<ZCrudAction>)` : **inchangés** (fonctionnent sur n'importe quel sous-ensemble). Vérifier qu'aucun n'affirme une longueur figée.

### Points de contact `zcrud_core` PARTAGÉS (⚠️ LOCK CORE SÉRIEL)

Cette story écrit dans des fichiers **partagés du cœur** — signalé au dev et à l'orchestrateur pour éviter toute écriture concurrente (règle « une seule story touche `zcrud_core` à la fois ») :

1. `packages/zcrud_core/lib/src/domain/ports/z_acl.dart` — **enum `ZCrudAction`** (co-touché par E4-4/DP-6 logiquement, ici seul point d'extension).
2. `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` — **nouveaux params optionnels + zone d'actions** (co-touché par DP-2/DP-9 récemment : conserver INTACTS `manageVisibility`, `conditionContext`, la voie structurelle et SM-1).
3. `packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart` — **lecture seule attendue** ici (DP-6 y a déjà câblé `ZAcl` par action en mode hide). Cette story n'a PAS besoin d'y écrire ; toute modif éventuelle doit **additionner** sans casser DP-6.

Aucune autre story ne doit écrire ces 3 fichiers en parallèle pendant DP-14.

### Contraintes d'architecture (AD)

- **AD-1/AD-2** : `zcrud_core` reste pur (aucun gestionnaire d'état, aucun Firebase/Syncfusion, aucune dépendance à `RessourceACL` DODLP). Le mapping DODLP est **documentaire**.
- **AD-16** : `ZAcl` est **app-supplied**, aucune règle métier dans le cœur — le gate se contente d'appeler `can(...)`.
- **AD-10** (défensif) : dégradation silencieuse, `default` défensif sur tout futur `switch`, sérialisation défensive documentée.
- **AD-13** (a11y/RTL) : `Semantics`, ≥ 48 dp, directionnel, thème.
- **AD-2 / SM-1 / objectif n°1** : le gate ACL vit **exclusivement** dans la voie de build **structurel** (`ListenableBuilder` sur `_structural`), jamais dans une souscription de tranche de valeur. Une frappe ne doit ni recalculer le gate ni reconstruire la barre d'actions (`onStructuralBuild` stable). [dynamic_edition.dart:413-424]

### État actuel des fichiers UPDATE (lecture réelle)

- `z_acl.dart` : enum plat 5 valeurs + `ZAcl` (abstrait, 1 méthode `can`) + `ZAllowAllAcl` (`=> true`). L'ajout est purement additif ; `ZAllowAllAcl` couvre gratuitement les nouvelles valeurs.
- `dynamic_edition.dart` : `StatefulWidget` dont le `build` observe **uniquement** `_structural` (= `visibleFields` + `_collapsed`), jamais une tranche. **Ne consomme actuellement AUCUN `ZAcl`.** Le nouveau gate doit s'insérer dans ce `build` structurel (ou un sous-widget rendu par lui), sans élargir la frontière de rebuild ni s'abonner aux gardes/tranches. Préserver `onStructuralBuild`, `manageVisibility`, `conditionContext`, le rendu plat/groupé et les clés stables.

### Testing standards

- Framework : `flutter_test` ; fichiers `*_test.dart` sous `packages/zcrud_core/test/`.
- SM-1 : instrumenter via `onStructuralBuild` (compteur) + `WidgetTester.enterText` répété ; asserter compteur constant après la frappe.
- Gate ACL : `_DenyAcl` de test (déjà présent dans plusieurs suites) refusant un sous-ensemble ; asserter présence/absence des actions par `find.byTooltip`/`find.bySemanticsLabel`.
- Défensif : cas `formActions` vide et `acl` par défaut ⇒ `expect(tester.takeException(), isNull)`.

### Project Structure Notes

- Périmètre **strict `zcrud_core`** (domaine `ports` + présentation `edition`). Aucun autre package touché.
- Le descripteur `ZFormAction` (nouveau) vit en couche **présentation** (`presentation/edition/`), jamais dans `domain` (il porte `label`/`icon`/`onInvoke` de présentation). Le `requiredPermission: ZCrudAction` référence le port domaine — sens de dépendance correct (présentation → domaine).
- Convention de nommage : préfixe `Z`, snake_case fichiers, valeurs d'enum camelCase.

### References

- [Source: docs/dodlp-edition-parity-gap.md#2.6 (ligne 156) — gap M7 ACL formulaire]
- [Source: docs/dodlp-edition-parity-gap.md#3 MAJOR (ligne 206) — action M7 : étendre `ZAcl`/`ZCrudAction` + consommer côté `DynamicEdition`/`z_sub_list_field_widget`]
- [Source: dodlp-otr/lib/src/domain/security/ressource_acl.dart:3-160 — `RessourceACL` 11 flags (lecture seule)]
- [Source: packages/zcrud_core/lib/src/domain/ports/z_acl.dart:10-50 — `ZCrudAction`/`ZAcl`/`ZAllowAllAcl`]
- [Source: packages/zcrud_core/lib/src/presentation/edition/families/z_sub_list_field_widget.dart:505-510 — consommation ACL sub-liste compacte (DP-6, mode hide)]
- [Source: packages/zcrud_core/lib/src/presentation/list/z_row_action.dart:109-198 — patron `requiredPermission: ZCrudAction`]
- [Source: packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart:96-179, 413-424 — surface publique + voie de build structurel (SM-1)]
- [Source: CLAUDE.md — AD-1/AD-2/AD-10/AD-13/AD-16, SM-1, Key Don'ts]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (bmad-dev-story, mode accéléré lot groupé DP-14 ∥ DP-16, lock core sériel).

### Debug Log References

- `dart analyze packages/zcrud_core` → `No issues found!` (RC=0).
- `flutter test` (zcrud_core, suite complète) → `All tests passed!` **788** tests (RC=0).
- Suite ciblée DP-14 : `test/domain/z_acl_test.dart` + `test/presentation/edition/dynamic_edition_form_actions_test.dart` → verts.
- `python3 scripts/dev/graph_proof.py` → `ACYCLIQUE OK`, `CORE OUT=0 OK` (RC=0).
- `dart test test/purity/domain_entrypoint_dart_test.dart` → `All tests passed!` (RC=0).

### Completion Notes List

- **AC1** ✅ 6 nouvelles valeurs `copy/archive/publish/clear/validate/history` en camelCase, **après** `restore`, chacune doc-commentée (réf `RessourceACL` DODLP). `ZCrudAction.values.length == 11`.
- **AC2** ✅ Recensement confirmé : **aucun `switch`/`case ZCrudAction` dans tout le repo** (grep) ⇒ zéro exhaustivité cassée. Call-sites LISTE/sub-liste (`z_row_action.dart`, `z_sub_list_field_widget.dart`) inchangés. Aucun `switch` introduit.
- **AC3** ✅ `ZAllowAllAcl` (`=> true`) couvre gratuitement les 6 nouvelles ; test itère `ZCrudAction.values` + assertions nominatives.
- **AC4** ✅ `ZFormAction` + params `acl`/`formActions`/`collectionId` sur `DynamicEdition`. Filtrage `hide` par `acl.can(requiredPermission, collectionId:)`. `formActions` vide **ou** toutes refusées ⇒ aucune zone (rétro-compat pixel).
- **AC5 / SM-1** ✅ Gate ACL + barre rendus **dans le `ListenableBuilder` structurel** ; test : `onStructuralBuild` **stable** (inchangé) après 20 frappes. Frontière de rebuild NON déplacée.
- **AC6** ✅ `Semantics(button)` + `Tooltip`, `ConstrainedBox(minHeight:48,minWidth:48)`, `EdgeInsetsDirectional`, couleurs dérivées du thème (`TextButton`).
- **AC7** ✅ Défensif : ACL qui lève ⇒ `try/catch` → action masquée (fail-closed) ; `formActions` vide / `collectionId` null ⇒ pas d'exception (`takeException() == null`).
- **AC8** ✅ Posture sérialisation additive/défensive consignée dans le doc-comment d'en-tête de l'enum (non sérialisé aujourd'hui).
- **AC9** ✅ `ZCrudAction` déjà exporté (`domain.dart`) ; `ZFormAction` exporté via `dynamic_edition.dart` (barrel `zcrud_core.dart`). Cœur pur : aucun import gestionnaire d'état / Firebase / Syncfusion / `RessourceACL` (mapping documentaire).
- **AC10** ✅ Vérif verte rejouée (voir Debug Log).
- **Non-régression L1 (DP-12/13)** : `readMode` (propagé par `_fieldChild` → `ZFieldWidget`), `showIfNull`, slots de décoration et tokens `read*` **intacts** — DP-14 n'ajoute que la barre d'actions en amont du `ListView`, sans toucher la voie de rendu des champs.

### File List

- `packages/zcrud_core/lib/src/domain/ports/z_acl.dart` (modifié — enum étendu + doc-comment posture).
- `packages/zcrud_core/lib/src/presentation/edition/dynamic_edition.dart` (modifié — `ZFormAction`, params `acl`/`formActions`/`collectionId`, gate structurel, `_FormActionBar`/`_FormActionButton`).
- `packages/zcrud_core/test/domain/z_acl_test.dart` (modifié — 11 valeurs, `_DenyPublishAcl`, camelCase).
- `packages/zcrud_core/test/presentation/edition/dynamic_edition_form_actions_test.dart` (nouveau — gate/SM-1/défensif).
