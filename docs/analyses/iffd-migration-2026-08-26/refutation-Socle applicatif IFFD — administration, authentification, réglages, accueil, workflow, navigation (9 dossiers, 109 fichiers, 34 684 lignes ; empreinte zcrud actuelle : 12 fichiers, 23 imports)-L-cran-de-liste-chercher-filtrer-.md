# Réfutation — « le socle sait déjà le faire » : `ZCrudScreen(listFields:, cellsOf:, editionBuilder:)`, registre facultatif

Domaine : **Socle applicatif IFFD** (administration, authentification, réglages, accueil, workflow,
navigation — 9 dossiers, 109 fichiers, 34 684 l ; empreinte zcrud : 12 fichiers, 23 imports)
Date : 2026-08-26 — dépôts hôtes lus en **lecture seule**, aucun test lancé.

## Verdict : **NON TENUE** (réfutée sur la couverture et sur le gain)

Le **mécanisme** avancé existe et fait exactement ce qu'on lui prête — je l'ai vérifié corps par
corps, et **toutes les lignes citées sont exactes à la ligne près**. Ce qui ne tient pas, c'est
l'affirmation de **couverture** (« le socle sait déjà le faire » pour *ce besoin-là*) et le
**gain de ~1150 lignes**. Trois manques du socle sont prouvés par grep négatif, et la moitié
« accounting » du périmètre n'est pas déblocable par le correctif chiffré.

---

## 1. Ce qui RÉSISTE — le canal existe et tient sa promesse

Lu dans les **corps**, pas dans la dartdoc.

| Affirmation | Vérification sur disque | Verdict |
|---|---|---|
| `listFields` param `:187` | `z_crud_screen.dart:187` `this.listFields,` | ✅ exact |
| `cellsOf` param `:189` | `:189` `this.cellsOf,` | ✅ exact |
| `editionBuilder` param `:219` | `:219` `this.editionBuilder,` | ✅ exact |
| Registre **nullable** | `:255` `final ZcrudRegistry? registry;` | ✅ |
| `_listFields:1334` | `:1335` `final fields = widget.listFields ?? _derivedSpecs;` puis `throw ZScopeError` si `null` | ✅ paramètre prioritaire |
| `_cellsOf:1361` | `:1362-1363` `final explicit = widget.cellsOf; if (explicit != null) return explicit;` — **avant** toute lecture du registre | ✅ paramètre prioritaire |
| `_formPathAvailable:1401` | `:1402` `if (widget.editionBuilder != null) return true;` — court-circuit avant `widget.registry != null` | ✅ paramètre prioritaire |
| `ZEntity` en `z_entity.dart:17` | `abstract class ZEntity` — `String? get id;` (`:23`), `bool get isEphemeral => id == null;` (`:26`) | ✅ exact |
| Atteignable | `zcrud_screen/lib/zcrud_screen.dart` exporte `src/presentation/z_crud_screen.dart` | ✅ exporté |
| Paquet déclaré | `iffd/pubspec.yaml:524` (`dependencies`) **et** `:695` (`dependency_overrides`), ref `v3.21.0` | ✅ exact |
| 8 importeurs du périmètre | `grep -rln "package:zcrud_screen" lib/ \| grep -E "administration\|/auth/\|settings\|/home/\|workflow\|navigation"` = **8** | ✅ exact |
| 16 classes `extends DynamicModel` | 24 lignes brutes − **8 bornes génériques** (`<T extends DynamicModel>` : `data_controller`, `smart_learn_controller` ×2, `dialog_widgets`, `firebase_crud_repository_impl`, `supabase_crud_repository_impl`, l'`extension`, `DataResponse`) = **16 classes** | ✅ exact |
| 9 classes `implements DynamicModel` | 9 (`Event`, `TaskList`, `Task`, `ChatbotMessage`, `AiExpertResponsesExample`, `ChatbotConversation`, `TimeSlice`, `AiExpertKnowledge`, `AiExpert`) | ✅ exact |
| 4 268 l d'administration | 1330 + 1281 + 692 + 632 + 333 = **4 268** | ✅ exact |
| `DynamicModel` porte déjà `final String? id` | `dynamic_model.dart:4` | ✅ — satisfait le getter `ZEntity.id` |

Le rendu **grille de cartes métier** est bien exprimable : `ZListGridLayout`
(`zcrud_core/lib/src/presentation/list/z_list_layout.dart:175`, exporté ligne 211 du barrel) +
`itemBuilder` (`:310`). Les onglets à ACL propre le sont aussi : `ZListTab.acl` composée en
conjonction restrictive (`zcrud_core/.../z_list_tab.dart:63+`) — ce qui couvre le besoin réel
d'`ai_experts_page:1250-1260` (`permissions.getACL("AiExpert${cycle.name}")` par onglet).

**Sur ce point précis, la preuve avancée est irréprochable.** La réfutation porte ailleurs.

---

## 2. Ce qui la DÉMENT

### R1 — Il y a une **QUATRIÈME** dérivation du registre, et elle n'a PAS de paramètre de remplacement

L'affirmation dit : « chacune de ses **trois** dérivations a son paramètre de remplacement ».
Il y en a quatre.

`z_crud_screen.dart:1911-1913` :
```dart
bool get _duplicateAvailable =>
    widget.canDuplicate && _mode == ZScreenMode.full && _editionAvailable &&
    widget.registry != null && _registryKind != null;
```
`_duplicate()` (`:1920-1939`) passe **exclusivement** par `registry.encode` → retrait des `isId`
→ `registry.decode`. Or `canDuplicate` vaut **`true` par défaut** (`:203`).

**Grep négatif montré** :
```
$ grep -n "onDuplicate\|duplicateOf\|this.duplicate" lib/src/presentation/z_crud_screen.dart
RC=1   (aucune occurrence)
```
⇒ Sans registre, le geste « dupliquer » **disparaît sans échappatoire**. C'est documenté en
dartdoc (`:469-471`), mais l'affirmation le passe sous silence en comptant trois dérivations.
Perte silencieuse, pas bloquante — mais l'énoncé « registre facultatif, tout est remplaçable »
est **inexact**.

### R2 — Aucun seam d'**état vide** : le plus gros bloc supprimable des pages n'est pas récupérable

`DynamicList.build` (`zcrud_core/lib/src/presentation/list/dynamic_list.dart:184-192`) code en dur :
```dart
ZListEmpty()     => const _ZListMessageView(messageKey: 'list.empty', …),
ZListNoResults() => const _ZListMessageView(messageKey: 'list.noResults', …),
```
et `z_crud_screen.dart:3305` pose `state = const ZListEmpty();`.

**Grep négatif montré** :
```
$ grep -rn "emptyBuilder\|onEmpty\|emptyWidget\|buildEmpty" zcrud_screen/lib zcrud_core/lib/src/presentation/list/
RC=1   (AUCUN seam, ni dans l'écran ni dans la liste)
```

Or **4 des 5 pages d'administration portent un état vide illustré, bespoke** :
`user_role_page.dart:103` → `:250` (**~148 l** : cercle dégradé 180×180, titre « Aucun Groupe
d'Utilisateurs » `:172`, CTA), `ai_experts_page.dart:130` (« Aucun Agent IA Expert » `:204`),
`auditeurs_pages.dart:290` (« Aucun Auditeur Enregistré » `:359`), `accademic_years_page.dart:222`
(« Aucune Promotion »).

⇒ Ou bien ces blocs **survivent** (le gain fond), ou bien ils sont **perdus** au profit d'un texte
générique l10n — **régression visuelle non annoncée** par l'affirmation.

### R3 — Aucun slot **FAB** : `ZCrudScreen` n'expose pas une fente que son propre scaffold offre

`ZPageScaffold` **a** `floatingActionButton` et `floatingActionButtonLocation`
(`zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:67-68`, champs `:162-166`, câblés au
`Scaffold` `:282-283`). Mais `ZCrudScreen._buildScopeAndScaffold`
(`z_crud_screen.dart:3818-3846`) ne transmet que `title`, `leading`, `drawer`, `endDrawer`,
`actions`, `search`, `body` — **jamais le FAB**.

**Grep négatif montré** :
```
$ grep -n "this.floatingActionButton\|final Widget? floatingActionButton" lib/src/presentation/z_crud_screen.dart
RC=1   (aucun paramètre FAB sur ZCrudScreen)
$ grep -n "floatingActionButton\|FloatingActionButton" lib/src/presentation/z_crud_screen.dart
(aucune ligne)
```

Or **4 des 5 pages** créent par un FAB dégradé maison : `user_role_page:297`,
`accademic_years_page:633`+`:654`, `auditeurs_pages:1109`+`:1217`+`:1268`,
`ai_experts_page:1119`+`:1266`+`:1317`. `ZCrudScreen` **possède** le scaffold : l'hôte ne peut ni
le lui passer, ni l'envelopper. La création migre de force vers un bouton de barre — changement
d'UX non signalé — ou les lignes restent.

### R4 — La moitié **accounting** (647 l, 4 écrans) n'est PAS déblocable par le correctif chiffré

L'affirmation chiffre la conformité `ZEntity` à « **1 fichier + 10 lignes** » via
`abstract class DynamicModel extends ZEntity`. Ce chiffre est juste **pour les 25 descendants de
`DynamicModel`** — il ne couvre **rien** du dossier `accounting/`.

**Grep négatif montré** :
```
$ grep -rn "DynamicModel" lib/accounting/
RC=1   (ZÉRO occurrence dans tout lib/accounting/)
```
Les 10 classes de `lib/accounting/model/` (`JournalType`, `AccountingJournal`, `JournalEntry`,
`JournalEntryItem`, `AccountingAccount`, `AccountSelection`, `AccountingPlanController`,
`AccountingPlan`, `Taxe`, `AccountingConfig`) sont **autonomes**. `AccountingAccount`
(`lib/accounting/model/account.dart:3-8`) porte `String? uid` — **pas `id`** — plus `int? number`,
`int? minNumber`, `String? wording`. Conformer ces modèles est un **second chantier, non chiffré**.

Pire : **2 des 4 écrans ne sont pas des listes CRUD.**
* `accounting_system_screen.dart` (**182 l**) est un **menu** de `ListTile` → `Navigator.push`
  (`:107`, `:128`, `:143`) vers d'autres écrans. Rien à remplacer.
* `select_accounting_account_screen.dart` (**220 l**) est un **sélecteur** : il rend la valeur
  choisie par `Navigator.pop(context, acc)` (`:160`), travaille sur `Map<String, dynamic>
  selectedAccount` (`:4`) et fait un **forage hiérarchique par préfixe de numéro de compte**
  (`initState:44-56` : `elNumber.indexOf(pattern) == 0`, `parentNumber` par `substring`), avec
  modes `isSelectable` / `popUpDialog` / `readOnly`.

  `ZCrudScreen` **n'a pas de mode sélecteur**. `ZScreenMode` ne compte que `full` (`:34`),
  `details` (`:47`), `locked` (`:54`).
  **Grep négatif montré** :
  ```
  $ grep -n "onRowTap\|picker\|onSelected\|Navigator.pop" lib/src/presentation/z_crud_screen.dart
  110:  (dartdoc de editionBuilder — « responsable de se fermer »)
  2382: onSelected: granted        (PopupMenuButton d'actions de ligne)
  ```
  Aucun canal ne rend une valeur à l'appelant.

⇒ Sur les 647 l « accounting », **402 l (182 + 220) ne relèvent pas de `ZCrudScreen`**. Restent
`accounts_by_classe_screen` (123 l) et `accounts_by_group_screen` (122 l), qui sont bien des listes
à onglets recherchables — mais sur des modèles non conformes `ZEntity`.

### R5 — `listFields` est **obligatoire même pour une grille de cartes**, et c'est du code hôte NEUF

`_listFields` (`:1334`) **lève** `ZScopeError` si `widget.listFields == null` et le registre est
absent (`:1336-1341`). Il est consommé en cinq points, y compris hors colonnes : `:2587` (titre de
ligne), `:2754`, `:2916` (`schema:` du `ZListController`), `:3213` (`DynamicList.fields`), `:3301`
(`zApplyListRequest(schema:)` — la voie `items`). La **recherche** n'interroge que les champs
`searchable` (dartdoc `:430`), le **tri** et l'**export** en dépendent aussi.

⇒ Migrer les 5 pages impose d'**écrire à la main** un `List<ZFieldSpec>` pour `AppUserRole`,
`AiExpert`, `AnneeAccademique`, `AuditeurIffd`, `ExamModel` — du code hôte **ajouté**, jamais
déduit du gain. (L'hôte sait le faire : 34 fichiers contiennent déjà des `ZFieldSpec`, dont 51
occurrences dans `ai_expert_zcrud_edition.dart` — mais ce sont des specs de **formulaire**, pas de
liste, et rien ne prouve qu'elles soient réutilisables telles quelles.)

### R6 — La charge portée contre le document hôte est à moitié infondée

L'affirmation écrit : « les deux moitiés sont fausses » (`docs/migration-data-crud/04-navigation-et-pages.md:139-141`).

* **« Paquet non déclaré »** — **stale, pas faux quand il a été écrit**.
  `git log -1 --date=short` : doc = **2026-08-24** (`24ec31f`) ; ajout de `zcrud_screen` au
  `pubspec.yaml` = **2026-08-25** (`b943a35`). Le document a été **rattrapé le lendemain**.
* **« BLOQUANT `T extends ZEntity` »** — **factuellement VRAI**, et toujours vrai aujourd'hui :
  ```
  $ grep -rn "extends ZEntity\|implements ZEntity" lib/   → RC=1  (ZÉRO)
  $ grep -rn "@ZcrudModel" lib/                            → RC=1  (ZÉRO)
  $ grep -rn "ZcrudRegistry" lib/ | wc -l                  → 0
  $ grep -rn "ZCrudSource"   lib/ | wc -l                  → 0
  $ grep -rn "ZCrudScreen"   lib/                          → RC=1  (ZÉRO)
  ```
  Le préalable **existe**. L'affirmation ne le réfute pas : elle argue qu'il est **bon marché**.
  C'est une autre proposition — et R4 montre qu'elle n'est bon marché que pour la moitié
  `DynamicModel` du périmètre.

### R7 — Le gain de ~1150 lignes n'est pas soutenu

Aucune des 4 915 l invoquées n'utilise aujourd'hui le socle : **0 `ZCrudScreen` dans tout `lib/`**
(grep négatif ci-dessus). Le chiffre est donc une projection, et trois postes la contredisent :
* **−402 l** d'entrée : `accounting_system_screen` + `select_accounting_account_screen` ne sont pas
  des listes CRUD (R4) ;
* les **états vides bespoke** (≈ 148 l pour la seule `user_role_page`, présents dans 4 pages sur 5)
  survivent ou régressent (R2) ;
* les **cartes métier** restent chez l'hôte via `itemBuilder` — sur `user_role_page`, le widget de
  carte occupe `:343-632` (**290 l**, soit 46 % du fichier) et n'est pas touché ;
* les **FAB** (4 pages sur 5) survivent hors du scaffold ou disparaissent (R3) ;
* **+ N lignes** de `ZFieldSpec` à écrire pour 5 modèles (R5).

Le gain net n'est ni mesuré ni mesurable en l'état.

---

## 3. Ce qui serait vrai à la place

> **Le socle sait faire l'ossature, pas la page.**
> `ZCrudScreen` **fonctionne bel et bien sans `ZcrudRegistry`** — c'est établi, corps lus :
> `listFields` (`:187`), `cellsOf` (`:189`) et `editionBuilder` (`:219`) court-circuitent les trois
> dérivations (`:1335`, `:1362`, `:1402`). Une **quatrième** dérivation, la **duplication**
> (`:1911-1913`), reste au registre sans paramètre de secours.
>
> Le périmètre réellement adressable est l'**administration seule : 5 pages, 4 268 l**, et
> **après** un préalable `ZEntity` — réel, non réfuté — chiffré à **1 fichier + 10 lignes** pour
> les 16 `extends` + 9 `implements DynamicModel`. La moitié **accounting (647 l)** est hors
> d'atteinte : **0 occurrence de `DynamicModel`** dans `lib/accounting/`, `AccountingAccount` porte
> `uid` et non `id`, et 402 de ces 647 l sont un **menu de navigation** (182 l) et un **sélecteur à
> retour de valeur** (220 l) — forme que `ZCrudScreen` ne sait pas rendre
> (`ZScreenMode` = `full`/`details`/`locked`, aucun canal `Navigator.pop(valeur)`).
>
> Trois manques du socle sont à combler avant que la promesse tienne, tous prouvés par grep
> négatif : **(a)** aucun seam d'**état vide** (`emptyBuilder|onEmpty|emptyWidget|buildEmpty` →
> RC=1) alors que 4 pages sur 5 en portent un illustré (~148 l mesurées sur `user_role_page`) ;
> **(b)** aucun slot **FAB** sur `ZCrudScreen` alors que `ZPageScaffold` l'offre
> (`z_page_scaffold.dart:67-68`, `:282-283`) et que 4 pages sur 5 créent par FAB ; **(c)** aucun
> mode **sélecteur**. S'y ajoute le coût **ajouté** des `ZFieldSpec` de liste, obligatoires même
> pour une grille de cartes (`_listFields` lève, `:1336-1341`).
>
> **Gain défendable : nettement inférieur à 1 150 l, non chiffrable avant que (a) et (b) soient
> livrés.** Reformulation honnête : *« le socle assemble la barre, la recherche, les onglets à ACL
> propre, la corbeille et l'édition ; l'hôte garde ses cartes, ses états vides et ses FAB — trois
> seams manquent pour que la migration soit sans perte. »*

---

## 4. Périmètre de la vérification

* Dépôts hôtes (`iffd`) : **lecture seule stricte** — `cat`, `sed -n`, `grep`, `git log`. Aucune écriture.
* **Aucun test lancé**, dans aucun dépôt.
* Écriture limitée à ce seul fichier, sous `docs/analyses/iffd-migration-2026-08-26/`.
* Aucune clé ni secret cité.
* Toute absence affirmée porte son grep négatif, RC montré (R1, R2, R3, R4, R6).
