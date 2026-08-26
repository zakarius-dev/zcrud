# Réfutation — Cartes mentales (mindmap) / IFFD

**Affirmation attaquée** : « le menu d'actions d'une carte, écrit deux fois (feuille 216 l. + popup
118 l.), le socle sait déjà le faire par `ZItemActionsMenu(actions:, crossAxisCount: 2,
menuBuilder:)` + `ZItemAction` + `ZItemActionKind` ». Gain annoncé : **~334 lignes d'hôte
supprimées**.

**VERDICT : DÉMENTIE.** Le canal existe et fait ce qu'on lui prête, mais l'affirmation, telle
qu'elle est formulée, ne tient pas : elle couvre **118 lignes sur 334** (35 %), sa moitié
principale (216 l.) est du **code mort**, son **gain de comportement annoncé est nul sur ce
menu précis**, sa **signature est auto-contradictoire**, et **quatre de ses coordonnées de preuve
sont fausses**.

Date de mesure : 2026-08-26. Aucun test lancé. Aucun fichier hôte modifié.

---

## 1. Ce qui RÉSISTE (vérifié ligne à ligne)

Le canal existe, à l'endroit cité, avec cette signature, et son corps fait ce qu'on lui prête.

| Affirmation de preuve | Mesure | Verdict |
|---|---|---|
| `z_item_actions_menu.dart:283` (widget) | `283:class ZItemActionsMenu extends StatelessWidget {` | ✅ |
| `:147` (`ZItemAction`) | `147:class ZItemAction {` | ✅ |
| `:70` (`ZItemActionKind`) | `70:enum ZItemActionKind {` | ✅ |
| `:342` (`menuBuilder`) | `342:  final ZItemActionsMenuBuilder? menuBuilder;` | ✅ |
| `:297` (`crossAxisCount`, défaut 3) | `297:    this.crossAxisCount = 3,` | ✅ |
| Corps `:355-425` — traduction 1:1 en `ZMenuEntry` puis délégation | corps lu : boucle `for (final action in actions) { entries.add(action.toMenuEntry()); … }` puis `return ZActionMenu(entries: entries, …)` | ✅ |
| `ZActionMenu` à `z_action_menu.dart:18` | `18:class ZActionMenu extends StatelessWidget {` | ✅ |
| `zVisibleMenuEntries` à `z_menu_entry.dart:194`, site UNIQUE | `194:List<ZMenuEntry> zVisibleMenuEntries(List<ZMenuEntry> entries) =>` ; appelé une fois dans `ZActionMenu.build` | ✅ |
| `contentBuilder` nul quand aucune action visible | `contentBuilder: hote == null && !hasVisibleAction ? null : (…)` | ✅ |
| Atteignabilité : exporté par le barrel | `packages/zcrud_study/lib/zcrud_study.dart:135:export 'src/presentation/z_item_actions_menu.dart';` | ✅ |
| Atteignabilité : `zcrud_study` déclaré par IFFD | `iffd/pubspec.yaml:391` (`zcrud_study`, source git, `path: packages/zcrud_study`) | ✅ |

Le canal n'est donc **ni fantôme, ni inerte, ni hors de portée**. C'est le reste qui casse.

---

## 2. RÉFUTATION 1 — la moitié la plus grosse (216 l. sur 334) est du CODE MORT

La « feuille 216 l. » est `MindmapActionsDialogWidget`
(`iffd/lib/src/presentation/features/mindmap/dialogs/mindmap_dialog_widgets.dart:20-235`, soit
**216 lignes** exactement — l'arithmétique de l'affirmation est juste).

Son **unique** point d'entrée est `showMindmapActionsDialog`
(`mindmap_dialogs.dart:145-179`), qui l'instancie à `:164`.

**GREP NÉGATIF MONTRÉ — `showMindmapActionsDialog` n'a AUCUN appelant :**

```
$ cd /home/zakarius/DEV/iffd && grep -rn "showMindmapActionsDialog" . --include='*.dart'
lib/src/presentation/features/mindmap/dialogs/mindmap_dialogs.dart:145:Future<void> showMindmapActionsDialog({
RC=0                    # 1 seule ligne : la DÉFINITION elle-même

$ grep -rn "showMindmapActionsDialog" . 2>/dev/null | grep -v '\.dart:'
RC2=1                   # aucune référence hors Dart (routes, générés, docs)
```

**GREP NÉGATIF MONTRÉ — le widget n'est référencé que depuis cette fonction morte :**

```
$ grep -rn "MindmapActionsDialogWidget" lib --include='*.dart'
lib/.../mindmap_dialogs.dart:164:    builder: MindmapActionsDialogWidget(
lib/.../mindmap_dialog_widgets.dart:20:class MindmapActionsDialogWidget
lib/.../mindmap_dialog_widgets.dart:24:  const MindmapActionsDialogWidget({
lib/.../mindmap_dialog_widgets.dart:42:  Logger get logger => Logger("MindmapActionsDialogWidget");
```

⇒ **La chaîne entière est orpheline.** Le menu d'actions d'une carte n'est donc **pas « écrit deux
fois »** : il est écrit **une fois vivante** (le popup) et **une fois morte** (la feuille). Ces
216 lignes se suppriment **sans le socle, sans migration, sans risque de rendu** — les attribuer au
gain d'un portage `ZItemActionsMenu` fait passer une **suppression de code mort** pour une
**migration**.

Preuve accessoire que les deux copies avaient déjà DIVERGÉ (donc que la « duplication » n'en était
plus une) : à `mindmap_dialog_widgets.dart:163`, la branche `subjectToolPage` du « Déplacer » écrit
via **`folderDocumentRepositoryProvider`** avec la clé **`"subjectid"`** (minuscule), là où le popup
vivant écrit via `folderMindmapRepositoryProvider` avec `'subjectId'`
(`popup_menu_helpers.dart:541-544`). Un défaut latent, resté invisible **parce que** le code est mort.

**Gain réel corrigé : ~118 lignes migrables + ~216 lignes supprimables séparément**, pas 334 lignes
de migration.

---

## 3. RÉFUTATION 2 — `ZItemActionsMenu` ne PEUT PAS remplacer la feuille (même si elle était vivante)

L'affirmation présente un seul canal comme couvrant les deux écritures. Ce sont **deux formes
structurellement différentes** :

| | Feuille (`MindmapActionsDialogWidget`) | Popup (`buildMindmapPopupMenu`) |
|---|---|---|
| Nature | **corps de dialogue** (`StatelessItemDialogWidget`), rendu par `showPushedDialog` | **menu ancré** à un `GlobalKey`, `.show(widgetKey:)` |
| Déclencheur | **aucun** — l'appelant a déjà ouvert la surface | l'hôte pose son `IconButton` |
| Disposition | `Column` de `ListTile`, `BoxConstraints(maxWidth: 500)` (`:66-72`) — **une colonne** | `MenuConfig(type: MenuType.grid, maxColumn: 2)` (`:505`) — **deux colonnes** |
| Paquet de rendu | Material pur | `popup_menu: ^2.1.0` (`pubspec.yaml:186`) — bulle sombre à flèche |

`ZItemActionsMenu` **rend toujours son propre déclencheur** : son `build` retourne
`ZActionMenu(trigger: ZMenuTrigger(icon: …), …)` (`z_item_actions_menu.dart:378-397`), et
`ZActionMenu` exige `required this.trigger` (`z_action_menu.dart:34`), lui-même rendu en
`PopupMenuButton` par `ZDefaultMenuRenderer` (`z_default_menu_renderer.dart:55`).

⇒ **Il n'existe aucune façon d'utiliser `ZItemActionsMenu` comme corps de dialogue.** Pour la
feuille, le socle offrirait au mieux la **cellule** (`ZMenuEntryTile`) que l'hôte disposerait
lui-même — ce qui n'est **pas** l'affirmation soumise. Couverture partielle présentée comme totale.

Et `crossAxisCount: 2`, annoncé comme le réglage commun, est de toute façon **faux pour la
feuille**, qui est à **une** colonne.

---

## 4. RÉFUTATION 3 — la signature proposée est AUTO-CONTRADICTOIRE

L'affirmation propose `ZItemActionsMenu(actions:, crossAxisCount: 2, menuBuilder:)` — les **trois**
ensemble. Or `crossAxisCount` est **ignoré dès que `menuBuilder` est fourni**. Ce n'est pas une
lecture de dartdoc, c'est le chemin de code :

```dart
// z_item_actions_menu.dart, build()
contentBuilder: hote == null && !hasVisibleAction
    ? null
    : (surfaceContext, visibles, select) {
        if (hote != null) {
          return hote(surfaceContext, [...], (action) {...});   // crossAxisCount JAMAIS lu
        }
        return _ZDefaultItemActionGrid(..., crossAxisCount: crossAxisCount, ...);
      },
```

`crossAxisCount` n'est consommé que par `_ZDefaultItemActionGrid`, branche atteinte **uniquement**
si `hote == null`. La dartdoc le dit d'ailleurs mot pour mot (`:349` : « Ignoré quand [menuBuilder]
est fourni »), et **le patron de référence de l'hôte ne le passe pas** :
`folder_actions_menu_zcrud.dart:170-182` passe `actions:`, `tooltip:`, `menuBuilder:` — **pas**
`crossAxisCount`. La grille à 2 colonnes y vient de `ZMenuEntryTile.gridDelegate(crossAxisCount:
kFolderMenuColumns, …)` **dans le `_grid` de l'hôte** (`:209-211`), pas du paramètre du socle.

⇒ La signature avancée mélange deux réglages **mutuellement exclusifs**. Il faut choisir :
`crossAxisCount: 2` **sans** `menuBuilder` (grille du socle, cellules du socle), ou `menuBuilder`
**seul** (grille de l'hôte). L'affirmation ne dit pas laquelle, et les deux n'ont pas le même rendu.

---

## 5. RÉFUTATION 4 — le « gain de comportement » annoncé est NUL sur ce menu

L'affirmation conclut : *« une action non permise DISPARAÎT au lieu d'être visible et inerte
(AD-4) »*. C'est vrai du menu **dossier** (11 actions, droits testés dans le `switch`) — c'est
**faux du menu carte mentale**.

`buildMindmapPopupMenu` construit ses items **sous condition de droit**
(`popup_menu_helpers.dart:575-608`) :

```dart
items: [
  if (permissions.canUpdate)  MenuItem(title: 'Détails',   userInfo: 'edit_details', …),
  if (permissions.canUpdate)  MenuItem(title: 'Éditer',    userInfo: 'edit',         …),
  if (permissions.canMove)    MenuItem(title: 'Déplacer',  userInfo: 'move',         …),
  if (permissions.canDelete && (permissions.isResourceCreator || permissions.isFolderOwner))
                              MenuItem(title: 'Supprimer', userInfo: 'delete',       …),
],
```

Et son `onClickMenu` (`:506-573`) ne re-teste **aucun** droit : il n'y a donc **aucune entrée
visible et inerte** à corriger. Idem pour la feuille morte (`if (canUpdate)` `:85`, `:111` ;
`if (canMove)` `:140` ; `if (userId != null && canDelete && …)` `:204-207`).

Le déclencheur lui-même est déjà conditionné en amont : `hasMindmapActions`
(`popup_menu_helpers.dart:56-62`) et, sur le chemin vivant, `canShowActions`
(`folder_study_tools_page.dart:816-819`, `return null` si faux).

⇒ **Le portage serait ici purement cosmétique/structurel.** Le seul argument non-cosmétique
avancé (« changement de comportement visible », repris mot pour mot du commentaire W8k de
`folder_actions_menu_zcrud.dart:19-31`) a été transposé du menu **dossier** au menu **carte mentale**
sans être revérifié. Il ne s'y applique pas.

---

## 6. RÉFUTATION 5 — les coordonnées de la « preuve chez l'hôte » sont fausses, et le patron est SOUS FLAG

| Coordonnée avancée | Mesure réelle | Écart |
|---|---|---|
| `folder_actions_menu_zcrud.dart:34-38` « conserve la grille 2 colonnes via `menuBuilder` » | `:34-38` = le **bloc d'imports** (`import 'package:flutter/foundation.dart' …` → `show ZItemAction, ZItemActionKind, ZItemActionsMenu;`). Le vrai site est `:170-182` (`ZItemActionsMenu(… menuBuilder: …)`) et `:198-215` (`_grid`) | ❌ faux |
| `kFolderMenuColumns=2, :44` | `45:const int kFolderMenuColumns = 2;` (`:44` = la dartdoc) | ❌ décalé |
| « **13 occurrences** `ZItemActionsMenu` » | `grep -rn … lib` → **3 lignes**, dans **1 seul fichier** ; `grep -rno … .` (test inclus) → **16 occurrences**, **3 fichiers** | ❌ ni 13 ni cohérent |
| « **122** `ZItemAction` » | `grep -rno "\bZItemAction\b" . --include='*.dart'` → **57** ; dans `lib` seul → **21** | ❌ ×2,1 de trop |

Répartition mesurée de `ZItemActionsMenu` (3 fichiers, **un seul** de production) :

```
lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart
test/w8k/folder_actions_menu_zcrud_test.dart
test/w8p/folder_actions_menu_a11y_test.dart
```

Surtout : ce **seul** usage de production est **derrière un drapeau qui vaut LEGACY par défaut** —
`folder_actions_menu_zcrud.dart:56` :

```dart
const bool kFolderActionsMenuUseZcrudDefault = false;
```

et le test d'IFFD l.asserte tel quel (`test/w8k/folder_actions_menu_zcrud_test.dart:149:
expect(kFolderActionsMenuUseZcrudDefault, isFalse);`).

⇒ Le « **PATRON DÉJÀ PROUVÉ CHEZ CET HÔTE** » est prouvé **en test**, pas **en production**. Il n'a
jamais été rendu à un utilisateur d'IFFD par défaut. Ce n'est pas rien — c'est du code compilé et
testé — mais ce n'est pas la démonstration de rendu que l'affirmation en fait.

---

## 7. CONDITION CACHÉE — la surface change, et l'affirmation n'en parle pas

L'affirmation réduit l'équivalence à une colonne : *« `MenuConfig(type: grid, maxColumn: 2)` à `:505`
— exactement `crossAxisCount: 2` »*. Le nombre de colonnes est en effet le même. **Le reste ne l'est
pas.**

**GREP NÉGATIF MONTRÉ — IFFD n'injecte AUCUN `ZMenuRenderer` :**

```
$ cd /home/zakarius/DEV/iffd && grep -rn "ZMenuScope\|ZMenuRenderer\|ZGridMenuRenderer\|zResolveMenuRenderer" lib --include='*.dart'
RC=1                    # aucune sortie

$ grep -rn "ZMenuScope\|ZMenuRenderer\|ZGridMenuRenderer" . --include='*.dart'
RC2=1                   # aucune sortie, test inclus
```

⇒ Un portage retomberait sur `ZDefaultMenuRenderer` (`z_default_menu_renderer.dart:39`), donc sur
un **`PopupMenuButton` Material**. On échangerait la **bulle sombre à flèche de `popup_menu ^2.1.0`**
(icônes `Color(0xffc5c5c5)`, `Colors.red` pour Supprimer — `popup_menu_helpers.dart:580-607`) contre
une **surface Material standard**. C'est un changement de rendu visible, non mentionné.

Second point non mentionné : la **couleur du déclencheur**. L'hôte pose
`Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant)`
(`folder_study_tools_page.dart:832-833` et `:2148-2151`). `ZItemActionsMenu` n'expose que
`icon: IconData?`, et `ZDefaultMenuRenderer` rend `Icon(trigger.icon)` **sans couleur** (`:59`) —
la teinte retomberait sur l'`IconTheme` ambiant. Récupérable par l'hôte (un `IconTheme` enveloppant),
mais c'est une ligne de plus, pas une ligne de moins.

---

## 8. Ce qui est VRAI à la place

1. **Le canal existe, est exporté, et fait ce qu'on lui prête** — `ZItemActionsMenu` (`:283`) traduit
   1:1 en `ZMenuEntry` et délègue à `ZActionMenu` (`z_action_menu.dart:18`), qui applique
   `zVisibleMenuEntries` (`z_menu_entry.dart:194`) comme site unique de la règle d'absence.
   `zcrud_study` est une dépendance déclarée d'IFFD (`pubspec.yaml:391`).
2. **Le popup vivant (118 l., `popup_menu_helpers.dart:492-609`) est migrable**, avec ses
   **2 appelants** (`folder_study_tools_page.dart:822` via `_mindmapTrailing`, et `:2122` dans le
   corps legacy) — au prix d'un `menuBuilder` calqué sur `folder_actions_menu_zcrud.dart:198-215`,
   **pas** d'un `crossAxisCount: 2`, et d'un changement de surface assumé.
3. **La feuille (216 l., `mindmap_dialog_widgets.dart:20-235`) n'est pas migrable : elle est morte.**
   Elle se supprime, avec `showMindmapActionsDialog` (`mindmap_dialogs.dart:145-179`), **sans le
   socle**.
4. **Aucun gain AD-4 sur ce menu** : les quatre entrées sont déjà construites sous condition de
   droit, des deux côtés. Le gain réel du portage est ailleurs — cellule `ZMenuEntryTile` (cible
   ≥ 48 dp, `Semantics` non dupliquées), vocabulaire `ZItemActionKind`, et suppression d'une
   dépendance à `popup_menu`.
5. **Gain de lignes honnête : ~118 lignes migrées + ~216 lignes de code mort supprimées**, et non
   « ~334 lignes supprimées par le socle ».

---

## Annexe — commandes de mesure (toutes en lecture seule)

```bash
# Bornes des deux écritures
wc -l iffd/lib/src/presentation/features/mindmap/dialogs/mindmap_dialog_widgets.dart   # 235 (classe :20-235 = 216 l.)
grep -n "^PopupMenu build" iffd/lib/src/presentation/core/widgets/popup_menu_helpers.dart
#   492:PopupMenu buildMindmapPopupMenu({   …   611:/// Builds a PopupMenu for Flashcard actions  => 492-609 = 118 l.

# Code mort
grep -rn "showMindmapActionsDialog" iffd --include='*.dart'      # 1 ligne = la définition

# Canal socle
grep -n "class ZItemActionsMenu\|this.crossAxisCount = 3\|final ZItemActionsMenuBuilder? menuBuilder\|^class ZItemAction \|^enum ZItemActionKind" \
  zcrud/packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart
#   70 / 147 / 283 / 297 / 342
grep -n "zVisibleMenuEntries" zcrud/packages/zcrud_menu/lib/src/domain/z_menu_entry.dart   # 194
grep -rn "z_item_actions_menu" zcrud/packages/zcrud_study/lib/zcrud_study.dart             # 135 (export)
grep -n "zcrud_study" iffd/pubspec.yaml                                                    # 391

# Patron hôte + flag
grep -n "kFolderMenuColumns\|menuBuilder\|crossAxisCount\|ZItemActionsMenu\|kFolderActionsMenuUseZcrudDefault" \
  iffd/lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart
#   38 (import) / 45 (=2) / 56 (flag=false) / 170 (widget) / 176 (menuBuilder) / 210 (crossAxisCount DANS _grid)

# Absences
grep -rn "ZMenuScope\|ZMenuRenderer\|ZGridMenuRenderer" iffd --include='*.dart'   # RC=1, aucune sortie
```
