# Réfutation — « les 5 menus contextuels d'item » ⇒ `ZItemActionsMenu`

**Domaine** : Étude — dossiers d'étude (IFFD) : `lib/src/presentation/features/folders/**` (36 f. / 18 333 l),
`features/documents/**` (12 f. / 6 420 l), 6 modèles de dossier (1 310 l), sécurité/ACL (8 f. / 1 582 l),
6 adaptateurs `z_backed_*` (4 648 l).
**Besoin** : les 5 menus contextuels d'item de `lib/src/presentation/core/widgets/popup_menu_helpers.dart`
(`:186` folder, `:269` note, `:492` mindmap, `:612` flashcard, `:667` document — 831 l).
**Affirmation attaquée** : « le socle sait déjà le faire, par `ZItemActionsMenu` + `ZItemAction` +
`ZItemActionKind` + `ZItemActionState` + `zMenuEntryIdForKind` ». **Gain annoncé : ~545 lignes d'hôte supprimées.**

**Ancrages vérifiés** : hôte `65d1af9` / `feat/migration-zcrud` ✅ ; socle `cc276c154` (v3.21.0) ✅.

## VERDICT : **DÉMENTIE** — le canal existe et fonctionne, mais le **gain annoncé est faux d'un facteur ~9**, et la couverture est **partielle sur trois axes**.

---

## 1. Ce qui RÉSISTE (attaques menées, sans succès)

### 1.1 Le canal existe, à l'endroit cité, avec cette signature
`/home/zakarius/DEV/zcrud/packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart` (613 l).

| Symbole | Ligne annoncée | Ligne **mesurée** |
|---|---|---|
| `enum ZItemActionKind` | :95 | **:70** ❌ (écart 25 l) |
| `enum ZItemActionState` | :104 | :104 ✅ |
| `zMenuEntryIdForKind` | :119 | :119 ✅ |
| `class ZItemAction` | :147 | :147 ✅ |
| `const ZItemAction({` | :166 | **:163** ❌ |
| assert `onSelected`/`disabledReason` | :176 | **:174** ❌ |
| `class ZItemActionsMenu` | :283 | :283 ✅ |
| `const ZItemActionsMenu({` | :292 | :292 ✅ |
| `this.crossAxisCount = 3` | :297 | :297 ✅ |
| assert `crossAxisCount > 0` | :302 | **:300** ❌ |

⚠️ 4 citations sur 10 sont fausses (dont une de 25 lignes). Les symboles existent : ce n'est pas la
réfutation, mais la preuve avancée n'a pas été relue sur disque.

### 1.2 Le CORPS tient les trois états promis (pas seulement la dartdoc)
`packages/zcrud_menu/lib/src/domain/z_menu_entry.dart:102-106` :
```dart
bool get isVisible => permitted && (onSelected != null || disabledReason != null);
bool get isEnabled => permitted && onSelected != null;
```
`zVisibleMenuEntries` (`:194-195`) filtre par `isVisible`, appliqué **une seule fois** dans
`ZActionMenu.build` (`z_action_menu.dart:58`). Donc : `permitted:false` ⇒ ABSENTE ;
`onSelected`+`disabledReason` nuls ⇒ ABSENTE ; `disabledReason` non-nul ⇒ présente inerte. **Conforme.**

### 1.3 Il est ATTEIGNABLE depuis l'hôte
- Exporté : `packages/zcrud_study/lib/zcrud_study.dart:135` → `export 'src/presentation/z_item_actions_menu.dart';`
- Déclaré chez l'hôte **dans `dependencies:`** (bloc lignes `10`→`533`) : `zcrud_study` (`pubspec.yaml:391-395`)
  et `zcrud_menu` (`:340-344`), tous deux `ref: v3.21.0` — **exactement le commit du socle attaqué**.

### 1.4 Attaque « collision d'`id` sur `custom` » — **échouée**
10 des 23 items de l'hôte n'ont pas de `ZItemActionKind` propre ⇒ `kind: custom` ⇒
`zMenuEntryIdForKind(custom) == 'custom'` (`:126`), donc `id` partagé. J'ai cherché un mauvais aiguillage :
`zMenuSelectFor` (`z_menu_request.dart:52-70`) résout d'abord par `identical`, puis par **`id` ET `label`**,
motif explicitement documenté : « un hôte peut réutiliser `'custom'` sur plusieurs entrées ».
Les libellés sont distincts dans chacun des 5 menus. **Pas de mis-dispatch. Le socle avait anticipé.**

### 1.5 Attaque « CR-IFFD-83, la pastille vole le tap » — **échouée** (déjà corrigée)
Le registre hôte (`docs/zcrud-change-requests.md:6388`) signale un défaut d'interaction du `Badge.count`.
Corrigé sur disque à v3.21.0 : `z_item_actions_menu.dart:554-580` — `Stack(fit: StackFit.passthrough)` +
`Positioned.fill` + `IgnorePointer` autour du `Badge.count`. **Ne tient plus.**

---

## 2. RÉFUTATION n°1 — le « gain » de ~545 lignes est **le corps métier**, qui ne disparaît pas

### Décomposition MESURÉE des 831 lignes (`sed`/`wc` sur `popup_menu_helpers.dart`)

| Menu | Plage | Total | `onClickMenu` (**métier**) | `items:` (déclaratif) | Signature/enveloppe |
|---|---|---|---|---|---|
| folder | :186-266 | 81 | **8** (déjà délégué à `handleFolderMenuAction`) | 51 | 22 |
| smartNote | :269-489 | 221 | **167** | 34 | 20 |
| mindmap | :492-609 | 118 | **71** | 31 | 16 |
| flashcard | :612-664 | 53 | **26** | 15 | 12 |
| document | :667-1016 | 350 | **276** | 48 | 26 |
| **TOTAL** | :186-1016 | **831** | **548** | **179** | **96** |

🔴 **548 ≈ 545.** Le « gain annoncé » est, à trois lignes près, **la somme des corps de `onClickMenu`**.

Or ces corps ne sont pas du squelette de menu. Un seul `case` du menu document (`:692-760`) contient :
`showFolderDocumentPagesSelectionDialog`, destructuration de record,
`aiRepositoryProvider.generateFlashcardsFromDocumentPagesContents(...)`, callback `onComplete`,
`json.decode`, `fromMapList<FlashcardModel>`, `.map(...)` sur 12 champs,
`flashcardRepositoryProvider.saveFolderFlashcards`, `try/catch` + `_logger.severe`, `loadingCallback`.
Idem menu note (`:288-454` : génération flashcards **et** mindmap, `MindmapNode.fromMap`,
`showFolderMindmapViewer`, `folderMindmapRepositoryProvider.update`).

**Migrer vers `ZItemActionsMenu` DÉPLACE ce code dans les closures `onSelected`. Il n'en supprime pas une ligne.**

### Ce qui est réellement supprimable

| Élément | Mesure | Lignes |
|---|---|---|
| `return PopupMenu(` + `context:` + `config: MenuConfig(...)` + `onClickMenu: (item) async {` + `switch (item.menuUserInfo) {` + 2 fermetures + `items: [` + `],` + `);` | 5 menus × ~10 | ~50 |
| `case '…':` / `break;` | `grep -c` : **18** + **18** | 36 → net ~18 (remplacés par `onSelected: () async {` / `},`) |
| `MenuItem(title:, userInfo:, image: Icon(...))` → `ZItemAction(kind:, label:, icon:, onSelected:)` | 23 items | **neutre à +1/item** |
| **À AJOUTER** : `menuBuilder` + grille 2 colonnes (cf. §4.3) | mesuré sur le jumeau : `_grid` `:200-224` | **−25** |
| **NET RÉALISTE** | | **≈ 45 à 60 lignes** |

⇒ **~545 annoncées vs ~50 réelles : facteur ~9.**

---

## 3. RÉFUTATION n°2 — la PREUVE par le jumeau mort : **+241 lignes / −0**

Les 4 greps avancés se rejouent **exactement** (hôte `65d1af9`) :

```
grep -n folderActionsMenu lib/src/presentation/shared/zcrud/z_qa_flags.dart        → RC=1 (absent)
grep -rn -w iffdFolderActions lib          → 1 ligne : folder_actions_menu_zcrud.dart:98 (sa déclaration)
grep -rn -w FolderActionsMenuZcrudView lib → 3 lignes, toutes dans folder_actions_menu_zcrud.dart (:155,:157,:232)
grep -rn kFolderActionsMenuUseZcrudDefault lib → 1 ligne : :56, `const bool … = false;` sans provider
```

✅ Le jumeau est bien MORT. Mais c'est une preuve **à charge**, pas à décharge :

- L'hôte a **déjà porté** le plus PETIT des cinq menus (folder, 81 l).
- Coût : `wc -l lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart` = **241 lignes**.
- Gain : **0** — le legacy `buildFolderPopupMenu` est intact (`:186-266`) et reste appelé depuis 3 sites
  (`folder_details_page.dart:239`, `:1803`, `folder_subfolder_selection_dialog_widget.dart:96`).

**Le seul essai réel de cette migration, mené par l'hôte lui-même, a un bilan de +241/−0.**

Négatif montré : un seul fichier de l'hôte référence `ZItemAction` —
`grep -rln "ZItemActionsMenu\|ZItemAction\b" lib` → **1 ligne**. Les 4 autres menus (les 750 lignes
restantes) n'ont **aucun** port, et ce sont précisément ceux qui portent le métier lourd.

---

## 4. RÉFUTATION n°3 — la couverture est PARTIELLE sur trois axes

### 4.1 Les 23 couleurs d'item ne sont PAS exprimables — et `isDestructive` est INERTE
Les 5 menus portent **23 icônes colorées**
(`sed -n '186,1016p' … | grep -o "color: …" | sort | uniq -c`) :
`Colors.red` ×5, `Color(0xffc5c5c5)` ×10, `Colors.orange` ×3, `Colors.blue` ×3, `Colors.blueGrey` ×1.

- `ZItemAction` n'a **aucun** champ couleur (`kind, label, icon, onSelected, id, permitted, disabledReason, state, stateSemanticLabel, count`).
- `ZMenuEntry` non plus (`z_menu_entry.dart:81-99` : `id, label, icon, onSelected, disabledReason, isDestructive, permitted`).
- `ZMenuEntryTile` rend un **`Icon(icon)` nu** (`z_menu_entry_tile.dart:166` et `:173`) — couleur ambiante uniquement.

🔴 Et le seul canal résiduel, `isDestructive`, **ne peint rien** :
```
grep -rn "isDestructive" packages/zcrud_menu/lib/src/presentation/   → RC=1   (les 9 fichiers de rendu)
grep -rn "colorScheme.error\|error," packages/zcrud_menu/lib          → aucune ligne
```
Ses seules occurrences dans `zcrud_menu` sont `z_menu_entry.dart:57,70,96,118,128` — dartdoc, ctor,
champ, `==`, `hashCode`. **Écrit par `ZItemAction.toMenuEntry()` (`:253`), jamais lu par un renderer.**
Les seules lectures hors de sa classe sont dans `zcrud_chat_kernel` (un `isDestructive` HOMONYME sur
`ZChatAction`) et dans des tests qui asseoient le drapeau sur lui-même
(`zcrud_study/test/chat4b_item_actions_menu_delegation_test.dart:325,328` :
`expect(….toMenuEntry().isDestructive, …)` — garde tautologique : elle ne rougirait pas si le rendu changeait).

⇒ Migrer les 5 menus **aplatit 23 accents chromatiques en une seule teinte**, y compris les 5 « Supprimer »
rouges. C'est peut-être souhaitable au titre de FR-26 — ce n'est pas « le socle sait déjà le faire ».

### 4.2 Le rendu legacy est le paquet `popup_menu`, que le socle NE SAIT PAS piloter
Contrainte du propriétaire, consignée dans le registre hôte
(`/home/zakarius/DEV/iffd/docs/zcrud-change-requests.md:6822`, datée du 2026-08-19) :
> « pour les menus, on doit pouvoir utiliser les zcrud_menu combiné avec le package popup_menu déjà
> présent dans l'app pour le rendu de menu »

et la ligne suivante nomme la cible : « IFFD emploie ce paquet pour **cinq** autres menus
(`popup_menu_helpers.dart:204, :287, …`) » — **précisément les 5 menus de cette affirmation**.
L'hôte déclare `popup_menu: ^2.1.0` (`pubspec.yaml:186`).

Négatifs montrés :
```
grep -rn "popup_menu" packages --include=pubspec.yaml     → RC=1
grep -rn "package:popup_menu" packages --include='*.dart' → RC=1
grep -rn "ZMenuRenderer\|ZMenuScope" /home/zakarius/DEV/iffd/lib → RC=1
```
⇒ Le socle n'embarque **aucun** renderer `popup_menu`, et l'hôte n'en a écrit **aucun**. À v3.21.0,
migrer aujourd'hui fait tomber les 5 menus sur `ZDefaultMenuRenderer`, c'est-à-dire un
**`PopupMenuButton<ZMenuEntry>` Material** (`z_default_menu_renderer.dart:38-39, :55`) — surface
différente de la bulle `popup_menu` employée partout ailleurs dans l'application, **et contraire à la
contrainte du propriétaire**. Un `ZMenuRenderer` adaptateur est *concevable* (le contrat `ZMenuRequest`
est neutre, sans type Material), mais c'est du code à écrire, non compté dans le gain.

### 4.3 La grille par défaut n'est PAS la grille legacy
Legacy : `MenuConfig(type: MenuType.grid, maxColumn: 2)` — 5 sites (`:204, :287, :506, :622, :691`).
Défaut du socle (`_ZDefaultItemActionGrid`, `:445-455`) :
`width: crossAxisCount * kZMenuMinTapTarget * 2` et `mainAxisExtent: kZMenuMinTapTarget * 2`, avec
`kZMenuMinTapTarget = 48.0` (`z_menu_entry_tile.dart:27`) ⇒ **192 dp × 96 dp** pour 2 colonnes.
Le port de l'hôte a dû injecter sa propre grille : `SizedBox(width: 280)`, `mainAxisExtent: 72`,
`padding: EdgeInsets.all(8)` (`folder_actions_menu_zcrud.dart:200-224`), via `menuBuilder`.
⇒ **`crossAxisCount: 2` ne suffit pas** ; les ~25 lignes de grille sont à réintroduire (déduites au §2).

---

## 5. RÉFUTATION n°4 — deux zones adjacentes non couvertes, non comptées

- **Le déclencheur.** Les 5 menus sont des `PopupMenu` **impératifs** : `.show(widgetKey: btnKey)` —
  `grep -rn "show(widgetKey" lib | wc -l` = **9 sites**. `ZItemActionsMenu` **fabrique son propre
  déclencheur** (`ZActionMenu` → `renderer.build` → `PopupMenuButton`, `z_action_menu.dart:59-71`) ;
  l'appelant ne peut pas ancrer sur un widget existant. L'hôte l'a écrit lui-même
  (`popup_menu_helpers.dart:98` : « un WIDGET là où le legacy rend un `PopupMenu` qu'on `.show()` »).
  9 sites à réécrire, non comptés dans le gain.
- **Les gardes de visibilité du bouton.** `hasSmartNoteActions` / `hasMindmapActions` /
  `hasFlashcardActions` / `hasDocumentActions` / `hasFolderActions` (`:46-88`, 43 l) rendent le bouton
  **ABSENT** (`folder_study_tools_page.dart:736-741` → `return null`). Le socle rend le déclencheur
  **présent mais inerte** quand rien n'est visible
  (`enabled: entries.isNotEmpty || contentBuilder != null`, `z_default_menu_renderer.dart:59`).
  Les 43 lignes restent nécessaires ; le comportement diffère si on les retire.

---

## 6. Ce qu'il faudrait pour que l'affirmation devienne vraie

1. Un **`ZMenuRenderer` adossé à `popup_menu`** — chez l'hôte (le socle ne peut pas dépendre du paquet, AD-1),
   ou un canal socle documentant le patron. Sans lui, la contrainte propriétaire du 2026-08-19 est violée.
2. Un canal **chromatique par action** (jeton, ou consommation effective d'`isDestructive` par
   `ZMenuEntryTile`), sinon acter par écrit l'aplatissement des 23 accents.
3. Un **défaut de grille** aux mesures legacy, ou l'acceptation des ~25 lignes de `menuBuilder`.
4. Réénoncer le gain à **~50 lignes**, et énoncer séparément que **548 lignes de logique métier sont
   RELOCALISÉES**, pas supprimées — avec le risque de régression que porte tout déplacement de 548 lignes
   d'appels IA / dépôt / dialogues.

---

## 7. Bilan chiffré

| | Annoncé | Mesuré |
|---|---|---|
| Lignes hôte supprimées | ~545 | **≈ 45-60** |
| Lignes hôte à ajouter | 0 (implicite) | ≈ 25 (grille) + 9 sites de déclencheur |
| Lignes métier concernées | — | **548, relocalisées** |
| Précédent réel (menu folder) | — | **+241 / −0**, code mort |
| Items perdant leur couleur | 0 (implicite) | **23** |
| Menus déjà portés | — | **1 sur 5**, et mort |
| Citations de lignes exactes | 10/10 | **6/10** |

**Ce qui reste vrai** : le canal existe, est exporté, est atteignable, et apporte **deux choses réelles**
que le legacy n'a pas — la règle d'absence AD-4 appliquée en un site unique (une action interdite
DISPARAÎT au lieu d'être visible et inerte : le legacy teste les droits dans son `switch`), et une voie
de sélection unique insensible aux rebuilds (`zMenuSelectFor`). **Ce sont des gains de correction, pas
des gains de lignes.** L'affirmation aurait tenu si elle les avait revendiqués ; elle est démentie parce
qu'elle a chiffré le corps métier comme du squelette de menu.
