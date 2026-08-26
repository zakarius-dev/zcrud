# Réfutation — SmartNotes / M-2 « Menu d'actions d'une note »

**Domaine** : Notes intelligentes (SmartNotes) — IFFD @ `65d1af9` vs zcrud `v3.21.0` (`cc276c154`)
**Besoin hôte** : M-2 — Menu d'actions d'une note ; « le précédent est déjà écrit ET testé dans le même dépôt (sur les dossiers) »
**Gain annoncé** : ~133 lignes d'hôte supprimées
**Verdict** : 🔴 **DÉMENTIE** — les canaux sont réels, exportés et atteignables ; l'**affirmation de migration** ne tient pas.

---

## 1. Ce qui RÉSISTE — les canaux existent, corps vérifié

Toutes les coordonnées avancées sont exactes. Vérifié ligne à ligne, corps lu (pas la dartdoc) :

| Canal | Coordonnée annoncée | Mesuré |
|---|---|---|
| `ZItemActionsMenu` | `zcrud_study/…/z_item_actions_menu.dart:283` | ✅ classe `:283`, ctor `:292`, **6 params** (`actions`, `icon`, `tooltip`, `menuBuilder`, `crossAxisCount`, `renderer`), `crossAxisCount = 3` par défaut, `assert(crossAxisCount > 0)` |
| `ZItemAction` | `:147-193` | ✅ classe `:147`, ctor `:163`, **10 params**, **3 asserts** dont l'exclusivité `onSelected`/`disabledReason` |
| `toMenuEntry()` | `:246-254` | ✅ `:246`, projette `permitted` et dérive `isDestructive` de `kind == delete` |
| `ZItemActionKind` | — | ✅ `enum` `:70` |
| `isVisible` | `zcrud_menu/…/z_menu_entry.dart:103-104` | ✅ **corps confirmé** `permitted && (onSelected != null \|\| disabledReason != null)` → `permitted:false` force bien l'**ABSENCE**, jamais le grisage |
| `ZMenuEntryTile.gridDelegate` | `z_menu_entry_tile.dart:81-96`, plancher `:92` | ✅ `math.max(mainAxisExtent, kZMenuMinTapTarget)` `:92` ; `kZMenuMinTapTarget = 48.0` `:27` ; c'est bien un `math.max`, **pas un assert** |
| `Semantics` | `:111-122` | ✅ `button` / `enabled` / `label` / `hint: entry.disabledReason` / `excludeSemantics: true` |
| `InkWell` conditionnel | `:104` / `:132-134` | ✅ `tappable = onSelected != null && entry.isEnabled` `:104`, `InkWell` posé seulement si `tappable` `:132-134` |
| `ZActionMenu` | `z_action_menu.dart:18`, site unique `:58` | ✅ classe `:18`, `zVisibleMenuEntries(entries)` **site unique** `:58` |

**Atteignabilité — vérifiée** :
- Exportés : `zcrud_study/lib/zcrud_study.dart:135`, `zcrud_menu/lib/zcrud_menu.dart:45` / `:47` / `:51`.
- Dépendances déclarées d'IFFD : `zcrud_study` (`pubspec.yaml:391`), `zcrud_menu` (`:340`).

**Le précédent existe bien** : `iffd/lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart`, **241 lignes**, imports `:36-38`, en-tête `:60-76` documentant la mesure d'équivalence, gardes `test/w8k/` (2 fichiers) et `test/w8p/` (1 fichier).

Cette moitié de l'affirmation est **tenue**. La suite ne l'est pas.

---

## 2. R1 — Le gain de ~133 lignes est arithmétiquement impossible

Structure mesurée de `buildSmartNotePopupMenu` (`popup_menu_helpers.dart`, fonction **269-489**, pas `269-491` — elle se ferme ligne 489) :

| Bloc | Lignes | Compte | Devient quoi ? |
|---|---|---|---|
| Signature (13 params) | 269-283 | 15 | **inchangée** |
| `_container` + `PopupMenu(` + `config:` + `onClickMenu:` + `switch` | 284-289 | 6 | supprimée |
| `case 'flashcards'` | 290-343 | 54 | **DÉPLACÉE** |
| `case 'mindmap'` | 344-397 | 54 | **DÉPLACÉE** |
| `case 'edit'` | 398-408 | 11 | **DÉPLACÉE** |
| `case 'move'` | 409-443 | 35 | **DÉPLACÉE** |
| `case 'delete'` | 444-452 | 9 | **DÉPLACÉE** |
| fermetures `}` / `},` | 453-454 | 2 | supprimée |
| **`items: [ … ]`** | **455-487** | **33** | → `List<ZItemAction>` |
| `);` `}` | 488-489 | 2 | — |

**Les 163 lignes de corps de handlers (290-452) sont de la logique métier** : génération IA de flashcards, génération de mindmap, dialogue d'édition, deux dialogues de déplacement, confirmation de suppression, appels `flashcardRepositoryProvider` / `folderNoteRepositoryProvider` / `aiRepositoryProvider`. **Elles ne disparaissent pas** : elles migrent dans des closures `onSelected:` ou dans une fonction extraite. Un déplacement n'est pas une suppression.

**Seul le bloc `items:` (33 lignes) se traduit réellement.** Or 5 `ZItemAction` portant `kind`/`label`/`icon`/`onSelected` coûtent ~8-10 lignes chacune, soit **~45 lignes** — **plus** que les 33 qu'elles remplacent.

⇒ Le « ~90 l. de `List<ZItemAction>` » n'est atteignable qu'en comptant les 163 lignes de handlers comme supprimées. **Gain net réel sur la déclaration du menu : nul à négatif**, pas 133 lignes.

---

## 3. R2 — Le prérequis omis est exactement celui qu'IFFD a enregistré comme BLOCAGE du précédent invoqué

Grep négatif **montré** :

```
$ grep -rn "handleSmartNote\|iffdSmartNote\|iffdNoteActions\|SmartNoteActionsMenu\|smartNoteActions" lib/ test/
RC=1   (aucune occurrence)
```

Les handlers de note sont **enfermés dans la closure `onClickMenu`** (290-452) et capturent `_container`, `note`, `subject`, `folder`, `parentFolder`, `userId`, `subjectToolPage`, `aiRouter`, `loadingCallback`, `mindmapCallback`.

Or IFFD **a lui-même classé** le jumeau « dossiers » dans sa garde vivante `test/routing/zcrud_flag_wiring_test.dart:112-113` :

> `'kFolderActionsMenuUseZcrudDefault': '(b) forme incompatible — le switch des 5 handlers est enfermé dans la closure de buildFolderPopupMenu, à extraire'`

et, `:71-74`, la définition de la cause (b) : *« le legacy rend un `PopupMenu` qu'on `.show()`, là où le portage est un WIDGET. Il manque en plus un constructeur de `List<ZItemAction>` »*.

Pour les **dossiers**, cette extraction **a été faite** : `handleFolderMenuAction` (`popup_menu_helpers.dart:109`), appelée depuis `buildFolderPopupMenu` (`:207`) et depuis le portage. Pour les **notes**, elle **n'existe pas** (grep ci-dessus).

⇒ M-2 n'est pas « le précédent rejoué ». C'est **le prérequis du précédent, encore à construire** — sur un `switch` de **163 lignes** au lieu des 65 du dossier (`:111-175`), et avec 4 callbacks de progression (`loadingCallback`, `summaryCallback`, `mindmapCallback`) à faire traverser l'extraction.

---

## 4. R3 — Le précédent n'a JAMAIS été monté ; l'affirmation propose d'aller plus loin qu'il n'est allé

```
$ grep -rn "folder_actions_menu_zcrud" lib/
lib/src/presentation/core/widgets/popup_menu_helpers.dart:97:/// inatteignables depuis le portage zcrud (`folder_actions_menu_zcrud.dart`), qui est
```

→ **un seul hit dans `lib/`, et c'est un COMMENTAIRE.** Aucun `import`.

```
$ grep -rn "kFolderActionsMenuUseZcrudDefault\|FolderActionsMenuZcrudView\|iffdFolderActions" lib/ test/
   (hors le fichier lui-même : 5 hits, TOUS sous test/)
$ grep -rn "ZItemActionsMenu(" lib/
lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart:170
```

- Le flag `kFolderActionsMenuUseZcrudDefault = false` (`:60`) — **legacy par défaut** (strangler fig).
- IFFD range ce flag dans `kPortagesInertes`.
- `ZItemActionsMenu(` n'apparaît **qu'une fois dans tout `lib/`**, dans un fichier **que rien n'importe**.
- Les seuls usages zcrud vivants côté notebook (`notebook_zcrud.dart`, `notebook_artifact_specs_iffd.dart`, `notebook_artifact_counts_iffd.dart`) n'importent que l'**enum** `ZItemActionState` — jamais `ZItemAction` ni `ZItemActionsMenu`.

⇒ **`ZItemActionsMenu` a zéro point de montage en production chez IFFD.** Le précédent a **ajouté 241 lignes à côté** du legacy ; il n'a **rien supprimé** : `buildFolderPopupMenu` est toujours là (`:186`). L'affirmation « Supprime `buildSmartNotePopupMenu` » n'a donc **aucun précédent** — elle propose le geste que le précédent n'a précisément pas osé.

---

## 5. R4 — Les couleurs d'icône par action sont PERDUES, et ce n'est pas signalé

Le legacy des notes porte **5 couleurs d'icône littérales** :

| Ligne | Action | Couleur |
|---|---|---|
| `:460` | Flashcards | `Colors.blue` |
| `:466` | Mindmap | `Colors.orange` |
| `:472` | Modifier | `Color(0xffc5c5c5)` |
| `:478` | Déplacer | `Color(0xffc5c5c5)` |
| `:485` | Supprimer | `Colors.red` |

Or `ZItemAction.icon` est un **`IconData`** (`z_item_actions_menu.dart:200`), pas un `Widget`. Et `ZMenuEntryTile._content` rend `Icon(icon)` **sans couleur** (`z_menu_entry_tile.dart:162` et `:171`) — FR-26, par conception.

Le **seul** crochet de couleur est `ZItemActionState` (`z_item_actions_menu.dart:505-516`) : une teinte d'**état sémantique**, bornée à `colorScheme.secondary` / `colorScheme.primary`, et **conditionnée à un `stateSemanticLabel` non vide** (assert `:186-193`) qui annoncerait un état que ces 5 actions n'ont pas.

⇒ Par le chemin par défaut, les 5 icônes deviennent **monochromes**. L'hôte ne peut conserver ses couleurs qu'en passant par `menuBuilder` **avec sa propre tuile** — donc en abandonnant `ZMenuEntryTile`, c'est-à-dire le gain a11y qui est l'argument même du précédent, et en aggravant encore le compte de lignes.

Note : le `_grid` du précédent dossier (`folder_actions_menu_zcrud.dart:206-225`) utilise `ZMenuEntryTile` et **perd donc aussi** les couleurs du legacy dossier (`:223`, `:229`, `:235`, `:256`, `:262`) — mais comme il n'a jamais été monté (R3), **ce compromis n'a jamais été vu par un utilisateur**. Il n'est validé par rien.

---

## 6. R5 — L'« ATTENTION QA » est FAUSSE pour les notes

Grep négatif **montré**, deux fois :

```
$ sed -n '269,491p' lib/src/presentation/core/widgets/popup_menu_helpers.dart | grep -n "0\.7\|opacity\|Opacity\|enable"
RC=1   (aucune occurrence)

$ grep -n "0\.7\|withOpacity\|Opacity(" lib/src/presentation/core/widgets/popup_menu_helpers.dart
RC=1   (aucune occurrence dans les 1016 lignes du fichier)
```

Le menu legacy des notes construit ses entrées **sous condition** (`:455-486`) :
`if (permissions.canGenerateFlashcards)`, `if (permissions.canGenerateMindmap)`, `if (permissions.canUpdate)`, `if (permissions.canMove)`, `if (permissions.canDelete && (permissions.isResourceCreator || permissions.isFolderOwner))`.

⇒ Une action interdite est **DÉJÀ ABSENTE**. Il n'y a **ni opacité 0,7, ni entrée inerte, ni clic ignoré**.

La description « affiché à 0,7 d'opacité et ignoré au clic » est une **transposition du cas DOSSIER** — et même là elle est inexacte : l'en-tête du précédent (`folder_actions_menu_zcrud.dart:22-31`) écrit *« une action interdite est donc VISIBLE et ne fait rien quand on la touche »*, jamais « 0,7 d'opacité ». Cette valeur n'existe nulle part dans le fichier.

⇒ Le seul avertissement QA fourni décrit un changement de comportement **qui n'aura pas lieu**. Accessoirement, `permitted:` n'est même pas nécessaire ici : les `if` de l'hôte se traduisent en `onSelected: permis ? handler : null`, à sémantique identique. Cela prouve surtout que l'affirmation **n'a pas été mesurée sur le code des notes**.

---

## 7. Ce qui est vrai à la place

1. Les 6 canaux nommés **existent**, sont **exportés** et sont **atteignables** depuis IFFD (`zcrud_study` et `zcrud_menu` déclarés). Sur ce point l'affirmation est exacte, coordonnées comprises.
2. Le précédent dossier est **écrit (241 l.) et testé (3 fichiers)** — mais **jamais monté** : zéro `import` depuis `lib/`, flag à `false`, rangé par IFFD dans `kPortagesInertes`.
3. M-2 exige d'abord une **extraction de 163 lignes de handlers** hors de la closure `onClickMenu` (aucune n'existe : grep RC=1) — le blocage `(b)` que la garde d'IFFD documente déjà pour le jumeau dossier.
4. Le gain réel sur la déclaration du menu est **nul à négatif** (33 lignes d'`items:` → ~45 lignes de `ZItemAction`), pas ~133. Les 163 lignes comptées comme « supprimées » sont **déplacées**.
5. Le vrai gain du portage n'est **pas le volume** : c'est le plancher tactile 48 dp (`math.max`, `z_menu_entry_tile.dart:92`), les `Semantics` non dupliquées (`excludeSemantics: true`, `:120`) et le site unique de filtrage (`z_action_menu.dart:58`). C'est ce que l'affirmation aurait dû défendre.
6. **Régression non signalée** : perte des 5 couleurs d'icône par action (`ZItemAction.icon` est un `IconData` ; `Icon(icon)` sans couleur). Elle est inévitable par le chemin par défaut.
7. **L'avertissement QA fourni est faux** pour ce domaine (grep RC=1 sur `0.7`/`opacity` dans tout le fichier).

---

## 8. Reformulation tenable

> `ZItemActionsMenu` + `ZItemAction` + `ZMenuEntryTile` + `ZActionMenu` existent, sont exportés et sont atteignables depuis IFFD. Ils apporteraient au menu de note le plancher 48 dp, les `Semantics` non dupliquées et un site unique de filtrage. Mais M-2 **n'est pas** le rejeu d'un précédent livré : le précédent dossier n'a jamais été monté (flag `false`, aucun `import` depuis `lib/`), et il exige d'abord d'extraire les **163 lignes** de handlers scellées dans `onClickMenu` (`popup_menu_helpers.dart:290-452`) — le blocage `(b)` qu'IFFD documente lui-même. Le gain de lignes est **nul à négatif**, pas ~133. Coût non signalé : les **5 couleurs d'icône** par action sont perdues. L'avertissement QA sur l'opacité 0,7 est **inexistant dans le code** (grep RC=1) : le legacy des notes rend déjà ses actions interdites absentes.

---

*Mesures faites en lecture seule sur `iffd @ 65d1af9` et `zcrud @ cc276c154` (v3.21.0). Aucun test lancé, aucun fichier hôte modifié.*
