# Réfutation — Étude / matières, documents, corpus (IFFD) — M1

**Besoin de l'hôte** : la coquille des 4 formulaires portés (State + initState + dispose + `_onSave`
+ Scaffold + AppBar + bouton Enregistrer).
**Affirmation attaquée** : « le socle sait déjà le faire, par `presentFormEdition(...)` ».
**Gain annoncé** : ~420 lignes d'hôte supprimées.

## VERDICT : **RÉFUTÉE**

Le canal existe, il est réel, exporté, atteignable, et il fait ce que sa dartdoc annonce. Mais il ne
couvre pas le besoin réel de ces quatre écrans : il change le **contrat de sortie** (perte de données
silencieuse sur 3 des 4), il est **inatteignable en l'état pour 2 des 4** (scope local + `steps`
mutuellement exclusifs de `bodyBuilder`), il **ne transmet pas la géométrie de conteneur** que les
quatre points d'entrée exercent, et l'assiette du gain est **surévaluée de 107 lignes** par
construction. La « preuve que ça marche dans la même app » est un chemin **jamais monté** — ni en
production, ni par un seul test widget.

---

## 1. Ce qui RÉSISTE (vérifié sur disque, à l'octet)

| Point | Vérification | Résultat |
|---|---|---|
| Le canal existe à l'endroit cité | `present_form_edition.dart:234` | ✅ `Future<Map<String, dynamic>?> presentFormEdition(` |
| Signature 22 paramètres, `:236-256` | lecture | ✅ 1 positionnel + 21 nommés |
| `steps` `:249` / `stepperConfig` `:250` | lecture | ✅ exact |
| Assert `:258-262` dictant l'échappatoire | lecture | ✅ « Montez le `ZStepperEdition` vous-même dans le `bodyBuilder` » |
| Identique au tag consommé par l'hôte | `git diff v3.21.0 HEAD -- …/present_form_edition.dart` → **vide** | ✅ pas d'écart HEAD/tag |
| Exporté par le barrel | `zcrud_screen.dart:25` `export 'src/presentation/present_form_edition.dart';` | ✅ |
| Dépendance déclarée d'IFFD | `iffd/pubspec.yaml:524-528` (`ref: v3.21.0`) + override `:695-699` | ✅ |
| Le **corps** monte vraiment la coquille | `presentEdition:238-243` → `ZEditionScaffold`, `_pageAppBar:171-189` (`SliverAppBar` + titre + `leading` d'abandon), `_actions:332-367` (action d'enregistrement) | ✅ ce n'est pas une promesse de dartdoc |
| `readOnly` ⇒ action **absente** | `ZEditionChrome.hasSubmitAction:264` = `onSubmit != null \|\| submitController != null` ; `presentFormEdition:316` passe `onSubmit: readOnly ? null : submit` | ✅ parité AD-4 de l'hôte |
| Coquilles hôtes aux bornes citées | 728-605+1=124 ; 212-122+1=91 ; 348-232+1=117 ; 685-436+1=250 | ✅ arithmétique exacte |
| `IffdZcrudScope` au `MaterialApp.builder` | `iffd/lib/main.dart:269-270` | ✅ monté |

Rien de ce qui précède n'est contesté. La réfutation porte sur la **couverture du besoin**.

---

## 2. R1 — LE CONTRAT DE SORTIE N'EST PAS LE MÊME : perte de données silencieuse sur 3 des 4

Les 4 écrans émettent aujourd'hui `ZFormController.values` — **toutes les tranches**, y compris les
clés semées mais **non déclarées** comme champs :

* `z_submission.dart:233` : `final values = controller.values;`
* `z_form_controller.dart:269-273` : `for (final e in _slices.entries) e.key: e.value.value`

`presentFormEdition` émet, lui, `zNormalizeFormValues` :

* `present_form_edition.dart:286` → `ZFormOnlyController.submit()` (`z_form_only.dart:135-141`)
  → `values` (`:121-126`) → `z_form_values.dart:253-283`
* `z_form_values.dart:258` : `for (final field in fields)` — **seuls les champs déclarés** ;
  `:259` `if (field.readOnly) continue;` ; `:260-266` champs à condition fausse écartés.

Or **3 des 4 adaptateurs ne restaurent PAS les clés manquantes depuis la graine** :

| Fichier | Adaptateur | Fusion sur la graine ? |
|---|---|---|
| `folder_document_zcrud_edition.dart:102-114` | `adaptFolderDocumentZcrudOutput` | ❌ **aucun paramètre `seed`** |
| `subject_zcrud_edition.dart:471-514` | `adaptSubjectZcrudOutput` | ❌ `seed` sert uniquement à **conserver** une clé nulle (`:505-511`), jamais à en rajouter |
| `valuation_tool_model_zcrud_edition.dart:202-221` | `adaptValuationToolZcrudOutput` | ❌ `seed` sert uniquement à **ne pas retirer** une clé nulle (`:212-214`) |
| `ai_router_zcrud_edition.dart:589-593` | `adaptAiRouterZcrudOutput` | ✅ `{...rawSeed, ...values}` — le seul |

**Le cas le plus net, mesuré de bout en bout** :
`folderDocumentZcrudFields()` (`:73-89`) déclare **exactement UN champ** (`name`). Le site d'appel
fait ensuite :

* `documents_dialogs.dart:103-107` : `result.remove("subjectId")` / `result.remove("folderId")` /
  `result.remove("subFolderId")` — **ces clés sont donc dans le résultat aujourd'hui** ;
* `documents_dialogs.dart:110` : `fromMap<FolderDocument>(result)` ;
* `:113-117` : `folderDocumentRepository.create(document)` / `.update(document)`.

Après migration, `result` vaudrait `{name, createdAt, updatedAt}` : `update()` réécrirait le document
**amputé de son `id`, de son `folderId`, de son `subFolderId`** et de tout le reste. Perte
silencieuse, irréversible, à chaque enregistrement.

L'hôte a lui-même écrit ce diagnostic, mot pour mot, pour le précédent qu'on nous cite comme preuve
(`tasks_screen.dart:794-800`) :

> « Sans `{...depart, ...saisie}`, `TaskList.fromMap` reconstruirait une liste sans `id`, sans
> `creatorId`, sans `members` ni `description` : renommer une liste en créerait une seconde et
> effacerait ses membres. »

Et l'un des quatre écrans le dit encore dans son propre code — en se trompant sur le socle :
`folder_document_zcrud_edition.dart:157-158` affirme « les clés non rendues (id/subjectId/…) restent
des tranches présentes dans `values`, donc dans la sortie ». C'est vrai de `controller.values`
(chemin actuel), **faux** de `zNormalizeFormValues` (chemin `presentFormEdition`).

⇒ **La migration n'est pas un retrait de coquille : c'est un changement de contrat de sortie qui
exige d'ajouter une fusion sur les 4 sites d'appel.** Les tests de parité qui figent ce contrat
(`test/w7d`, `test/w7o`, `test/w7p`) rougiraient.

---

## 3. R2 — La preuve avancée est la preuve du CONTRAIRE

`task_list_zcrud_edition.dart:105-117` (13 lignes) est bien un appel nu à `presentFormEdition`. Mais
la fonction ne peut pas être appelée telle quelle : le site d'appel a dû se doter d'une **fonction de
fusion dédiée de 26 lignes** —

`tasks_screen.dart:790-815`, `_presenterListeDeTachesParLeSocle`, dont la dartdoc commence par :

> « 🔴 **LA FUSION EST LA RAISON D'ÊTRE DE CETTE FONCTION.** `presentFormEdition` rend les valeurs des
> CHAMPS DÉCLARÉS — ici `title` et `readOnly`, rien d'autre. »

Le coût réel du précédent est donc **13 + 26 = 39 lignes**, pas 13. Et la comparaison avancée
(« 117 l. au total contre 212 l. pour UN champ ») oppose deux **fichiers entiers** dont l'essentiel
n'est pas de la coquille : `task_list_zcrud_edition.dart` porte 43 lignes d'en-tête de commentaire
(`:1-42`) et zéro adaptateur ; `folder_document_zcrud_edition.dart` porte son en-tête, la fabrique de
champs (`:73-89`) et l'adaptateur (`:102-114`). Ce n'est pas une comparaison coquille-à-coquille.

---

## 4. R3 — « ÇA MARCHE DANS LA MÊME APP » n'est pas établi à l'exécution

* `task_list_zcrud_edition.dart:60` : `const bool kTaskListEditionUseZcrudDefault = false;`
* **Grep négatif montré** : `grep -rn "taskListEditionUseZcrudProvider.overrideWith" lib test` → **RC=1,
  aucune occurrence**. Le flag n'est basculé nulle part, ni en prod ni en test.
* **Grep négatif montré** : `grep -n "testWidgets" test/m0/task_list_zcrud_test.dart` → **RC=1, aucune
  occurrence**. Les 14 `test()` de ce fichier (186 l.) sont des **gardes de source** :
  `_code(chemin) => File(chemin).readAsStringSync()` (`:31-32`), puis
  `expect(code, contains('presentTaskListEdition'))` (`:112`).

⇒ Le chemin `presentFormEdition` de `task_list` n'a **jamais été monté** : aucun widget test ne le
pompe, aucun override ne l'active. C'est une preuve **textuelle**, pas une preuve d'exécution. Elle ne
peut pas porter le poids qu'on lui donne pour quatre formulaires nettement plus lourds.

---

## 5. R4 — Le blocage n'est PAS levé pour 2 des 4 (scope local + `steps` ⊥ `bodyBuilder`)

Le scope global de `main.dart:269-270` est monté **nu** :

```dart
builder: (BuildContext context, Widget? child) =>
    IffdZcrudScope(child: child ?? const SizedBox.shrink()),
```

**Grep montré** : `grep -n "relationSources\|subListSeams" lib/main.dart` → une seule ligne, **`267`,
qui est un commentaire** (« un écran qui déclare ses `relationSources` … continue de monter le sien »).
Aucun de ces deux paramètres n'est passé au scope global.

Or deux des quatre écrans montent un scope **local et instancié** :

* `subject_zcrud_edition.dart:697-698` : `IffdZcrudScope(relationSources: _relations, …)`, où
  `_relations = subjectRelationSourceRegistry(widget.aiExpertsRepository)` (`:665`) — dépend d'un
  dépôt passé par l'appelant ;
* `ai_router_zcrud_edition.dart:513-532` : `IffdZcrudScope(subListSeams:
  buildIffdAiRouterSeamRegistry(…, countOf: (champ) => _controller.valueOf(champ)…))` — **capture le
  contrôleur vivant**.

Et c'est `main.dart:248-253` qui énonce lui-même pourquoi ces scopes ne peuvent pas rester chez
l'appelant :

> « le présentateur POUSSE UNE ROUTE, et le contenu d'une route est bâti par l'`Overlay` du
> `Navigator` — un FRÈRE de l'écran, pas un descendant. Un scope monté dans l'écran n'est donc PAS
> hérité par le formulaire qu'il ouvre. »

⇒ Ces deux scopes doivent descendre **dans le corps de la route**, donc dans `bodyBuilder`. Or les
deux mêmes écrans montent un `ZStepperEdition` (`subject:718-724`, `ai_router:554-576`), et
`present_form_edition.dart:258-262` **interdit `bodyBuilder` avec `steps`**. Le paramètre `steps` du
socle est donc **inutilisable ici** : il faut remonter le stepper à la main dans `bodyBuilder`. Ce que
l'affirmation concède — mais qui vide le gain (cf. R5).

---

## 6. R5 — L'assiette du gain est fausse de 107 lignes, et le chrome ne pèse que 76 lignes

**La plage `ai_router:436→685` (250 l.) n'est pas de la coquille.** La coquille s'arrête à la
fermeture du `build` :

* `:577` `);` — `:578` `}` — `:579` vide — `:580` `/// Recompose la map de sortie attendue par
  fromMap<IffdAiRouterModel>.`
* `:580-685` = **106 lignes** d'adaptateurs (`adaptAiRouterZcrudOutput` `:589`,
  `adaptAiRouterZcrudInput` `:672`) qui restent nécessaires quoi qu'il arrive.

Assiette réelle : **124 + 91 + 117 + 143 = 475 lignes**, pas 582.

Et le **Scaffold + AppBar + bouton Enregistrer** proprement dits — le seul morceau que le chrome du
socle remplace vraiment — pèsent **76 lignes au total** :

| Écran | Chrome | Lignes |
|---|---|---|
| `subject` | `:699` `Scaffold(` → `:717` | 19 |
| `folder_document` | `:191` `Scaffold(` → `:207` | 17 |
| `valuation_tool` | `:321` `Scaffold(` → `:339` | 19 |
| `ai_router` | `:533` `Scaffold(` → `:553` | 21 |

Ce qui reste (classe publique + `State` + `initState` + `dispose` + `_onSave`) **ne disparaît pas** :
il se déplace en fonction présentatrice + fusion au site d'appel — le précédent `task_list` chiffre ce
déplacement à 39 lignes pour **deux** champs. Et pour `subject` / `ai_router`, le `IffdZcrudScope` et
le `ZStepperEdition` survivent **à l'intérieur du `bodyBuilder`** : ~10 lignes pour `subject`
(`:697-698` + `:718-725`), ~43 lignes pour `ai_router` (`:513-532` + `:554-576`).

⇒ **~420 lignes nettes supprimées n'est pas soutenable.**

---

## 7. R6 — La géométrie de conteneur n'est pas transmissible

Les 4 formulaires passent aujourd'hui par `showPushedDialog` (`forms_utils.dart:727-785`), qui
délègue **déjà** à `presentEdition` (`:775`) mais lui transmet :

* `maxHeight` calculé depuis `bottomSheetHeightRation` (`:766-772`) — « 28 des 93 [appelants] passent
  un ratio » (`:764`) ;
* `maxWidth` (`:779`) ;
* `sheetFrame: ZSheetFrameSpec(widthRatio: kIffdSheetWidthRatio, mode: unlessChrome)` (`:780-783`).

**Grep négatif montré**, dans `present_form_edition.dart` :
`grep -n "maxWidth\|maxHeight\|sheetFrame\|barrierDismissible\|isDismissible\|useSafeArea\|presenter"`
→ **RC=1, aucune occurrence**.

`presentFormEdition` n'expose que `policy` / `formWeight` / `forcedMode`. Or les trois points d'entrée
déclarent tous `double bottomSheetHeightRation = 1` (`documents_dialogs.dart:42`,
`valuation_tool_model_dialogs.dart:27`, `ai_routers_dialogs.dart:30`). Migrer perd ce réglage, et
perd le cadre de feuille IFFD.

---

## 8. R7 — Les sites d'appel n'ont pas de `BuildContext`

`presentFormEdition(context, …)` exige un contexte. Or :

* `documents_dialogs.dart:37-49` — `showFolderDocumentEditonDialog({FolderDocument? document, …})` :
  **aucun paramètre `BuildContext`** ;
* `valuation_tool_model_dialogs.dart:22-33` — `showValationToolEditonDialog<T>({T? tool, …})` : idem ;
* `ai_routers_dialogs.dart:25-33` — `showAiRouterEditionDialog({…})` : idem.

C'est délibéré : `showPushedDialog` retombe sur `Get.context` (`forms_utils.dart:745-746`), et sa
propre dartdoc note que « nos 93 appelants n'en passent aucun » (`:740-741`). Migrer ces trois entrées
oblige à propager un contexte jusqu'à elles — travail d'hôte que le socle ne fournit pas.

---

## 9. R8 — Le strangler fig est un ternaire entre deux **Widgets**

* `documents_dialogs.dart:60-88` : `final Widget editionScreen = zUseZcrud ?
  FolderDocumentZcrudEditionScreen(…) : DynamicEditionScreen<…>(…);` puis `showPushedDialog(builder:
  editionScreen)` (`:92-97`).
* `valuation_tool_model_dialogs.dart:50-...` : `builder: zUseZcrud ? ValuationToolZcrudEditionScreen(…)
  : DynamicEditionScreen(…)`.
* `ai_routers_dialogs.dart:48-...` : `builder: … ? Builder(builder: (popContext) =>
  AiRouterZcrudEditionScreen(…)) : …`.
* `subject_model_dialogs.dart:119-146` : `Widget build(…)` retourne l'un **ou** l'autre widget.

Une fonction `Future<Map<String,dynamic>?>` **ne peut pas occuper une branche de ces ternaires**. Le
site d'appel doit être restructuré en deux `await` distincts — ce qui touche la branche LEGACY, que
chacun de ces fichiers déclare « conservé À L'IDENTIQUE (aucune ligne retirée) »
(`documents_dialogs.dart:69`). Le seul écran déjà migré, `task_list`, l'a fait
(`tasks_screen.dart:454-469`) — et c'est précisément pour ça qu'il a fallu y ajouter la fusion.

---

## 10. R9 — 75 tests widget montent les 4 types supprimés

| Fichier de test | `testWidgets` | Lignes |
|---|---|---|
| `test/w7o/subject_zcrud_test.dart` | 27 | 863 |
| `test/w7p/valuation_tool_zcrud_test.dart` | 18 | 417 |
| `test/w7d/folder_document_zcrud_test.dart` | 6 | 266 |
| `test/w7p/valuation_tool_edition_flag_routing_test.dart` | 6 | 200 |
| `test/w7o/subject_edition_flag_routing_test.dart` | 5 | 250 |
| `test/w9o/lecture_seule_sous_champs_test.dart` | 3 | 140 |
| `test/w9o/valeur_orpheline_test.dart` | 3 | 160 |
| `test/m0/sous_liste_defauts_v2_test.dart` | 2 | 243 |
| `test/w9o/libelles_socle_francais_test.dart` | 2 | 194 |
| `test/w9q/sous_liste_actions_acl_test.dart` | 2 | 166 |
| `test/w9o/readonly_apres_montage_test.dart` | 1 | 141 |
| **Total** | **75** | **3 040** |

Tous montent le type (`home: XZcrudEditionScreen(…)`) ou l'assertent (`find.byType(XZcrudEditionScreen)`,
`test/w7o/subject_edition_flag_routing_test.dart:174-192`). Supprimer les quatre widgets casse les 75 :
ils devraient être réécrits autour d'un hôte qui appelle le présentateur puis tape. Ce coût est absent
du gain annoncé.

---

## 11. R10 — `valuation_tool` a besoin du contrôleur AU MOMENT de la soumission

`valuation_tool_model_zcrud_edition.dart:295` : `persisted[name] =
iffdPersistedRichTextValue(_controller, name);` — appelé **dans** `onSubmit`. La fonction exige un
`ZFormController` vivant (`z_iffd_rich_text_codec.dart:186-193`).

`presentFormEdition` crée son contrôleur (`:274-279`) et le libère avant de rendre la main
(`:359` `.whenComplete(controller.dispose)` — l'action de `whenComplete` s'exécute avant que le futur
rendu ne complète). Pour garder ce post-traitement, l'hôte doit soit fournir `formController:` — et
donc **le créer et le libérer lui-même**, c'est-à-dire réintroduire le `State` + `initState` +
`dispose` que M1 prétend supprimer — soit passer par `bodyBuilder`.

Et il n'y a **pas** de crochet de transformation à la soumission :
**grep négatif montré** : `grep -n "beforeSubmit" packages/zcrud_screen/lib/src/presentation/present_form_edition.dart`
→ **RC=1, aucune occurrence**. (`beforeSubmit` n'existe que sur `ZCrudScreen` : `z_crud_screen.dart:218,
671, 1710`.) Le commentaire de `iffd/pubspec.yaml:517-519` qui l'annonce « livré sur
`ZCrudScreen`/`presentFormEdition` » est donc inexact pour `presentFormEdition`.

---

## 12. Ce qui est VRAI à la place

`presentFormEdition` **couvre réellement** le chrome de deux des quatre formulaires
(`folder_document`, `valuation_tool` : scope nu, corps à plat, pas de `steps`), à trois conditions
que le socle ne remplit pas et que l'hôte doit payer :

1. **ajouter une fusion sur la graine** au site d'appel (patron `tasks_screen.dart:790-815`, 26 l.) —
   sans quoi `update()` écrase le document ;
2. **propager un `BuildContext`** jusqu'à `showFolderDocumentEditonDialog` /
   `showValationToolEditonDialog`, qui n'en ont aucun ;
3. **accepter la perte** de `bottomSheetHeightRation` / `maxWidth` / `sheetFrame` — ou obtenir du
   socle qu'il les expose sur `presentFormEdition`.

Pour les deux autres (`subject`, `ai_router`), `presentFormEdition` n'est utilisable qu'en
`bodyBuilder` (scope local instancié + `steps` interdits ensemble), ce qui laisse en place le scope,
ses seams et le `ZStepperEdition` : le gain de chrome y tombe à 19 et 21 lignes respectivement.

**Chiffrage honnête du gain** : 76 lignes de chrome retirées, ~250 lignes de `State`/`initState`/
`dispose`/classe publique **déplacées** (présentateur + fusion), 106 lignes comptées à tort dans
l'assiette, et 75 tests widget à réécrire. Le solde net n'est pas « ~420 lignes supprimées ».

**Le vrai manque du socle**, révélé par cet exercice, n'est pas la coquille : c'est (a) l'absence d'un
mode de sortie « **fusionner sur `initialValues`** » sur `presentFormEdition` — chaque hôte réécrit la
même fusion, et l'oublier perd des données en silence ; (b) l'exclusion mutuelle `steps` ⊥
`bodyBuilder`, qui interdit d'envelopper un assistant dans un scope applicatif ; (c) l'absence de
`maxWidth` / `maxHeight` / `sheetFrame` sur `presentFormEdition`, pourtant présents sur
`presentEdition` qu'il appelle.

---

### Méthode

Lectures seules dans `/home/zakarius/DEV/iffd` (aucune écriture, aucun test lancé). Aucun secret cité.
Toutes les affirmations d'absence portent leur grep négatif et son RC.
