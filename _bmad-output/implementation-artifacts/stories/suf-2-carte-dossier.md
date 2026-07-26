---
baseline_commit: 1cb21070d907b864a9605d2d280b9e1750a44cd0
---

# Story SUF-2 : `ZFolderCard` — carte de dossier d'étude thémable

Status: review

<!-- Source : plan approuvé /home/zakarius/.claude/plans/tingly-brewing-cake.md § Stories › SUF-2 -->
<!-- Epic : epic-suf (Study UI — Folders & Page-shell) — sprint-status.yaml:508-513 -->
<!-- Parité de référence (LECTURE SEULE) : packages/lex_ui/lib/presentation/widgets/study/folder_card.dart -->

## Story

As a **développeur d'une appli hôte de zcrud (lex_douane en cible, IFFD en sur-ensemble)**,
I want **une carte de dossier d'étude neutre et thémable, pilotée par des props primitives (jamais l'entité), avec accent dérivé d'une `colorKey`, slot compteur/badges, slot menu, état archivé et grille adaptative**,
so that **je cesse de réécrire la même carte dossier écran par écran et j'obtiens un rendu quasi identique au natif lex une fois bridgé, RTL-safe, a11y et sans gestionnaire d'état dans le widget**.

**Couvre :** le trou « Carte de dossier d'étude » diagnostiqué sur disque (grep négatif ; seul `ZStudyToolsItemCard` générique existait) — plan § Diagnostic. · **Taille :** M · **Package :** `zcrud_study` (présentation). · **Dépend de :** rien de bloquant (peut aller ∥ à SUF-1) ; **jamais en vol simultané avec SUF-3** (même package). · **Débloque :** SUF-3 (`ZStudyFolderDetail` réutilise `ZFolderCard` dans sa grille) + démo SUF-4.

---

## 🔴 Décisions tranchées AVANT dev (vérifiées sur disque, pas sur la prose)

Chaque verdict porte sa preuve disque.

### D1 — `ZFolderCard` vit dans `zcrud_study` (présentation), props PRIMITIVES, JAMAIS l'entité `ZStudyFolder`

Cohérent avec le patron déjà en place dans le package : `z_study_mindmap_section.dart` prend un **`folderId` opaque** (`String`), jamais `ZStudyFolder` (cf. son doc-comment `AD-4 : folderId = String opaque … jamais l'entité ZStudyFolder`). `ZStudyToolsItemCard` (`z_study_tools_item_card.dart:51`) est déjà la primitive à slots du package et **ne connaît aucun type métier** — même frontière ici.

⇒ **Verdict** : nouveau fichier `packages/zcrud_study/lib/src/presentation/z_folder_card.dart`, exporté par le barrel `packages/zcrud_study/lib/zcrud_study.dart`. `StatelessWidget`. **Aucune** nouvelle dépendance (`zcrud_responsive` et `zcrud_core` sont déjà déclarés — cf. `packages/zcrud_study/pubspec.yaml`). CORE OUT=0 intact.

### D2 — L'accent dérive de la `colorKey` via `ZColorKeyResolver`, PAS d'une table de couleurs locale

`packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart` fournit la chaîne **totale** `zResolveColorKeyOrSlot(context, colorKey, slotIndex:)` → `ZColorPair {color, onColor}` (jamais `null`, jamais de throw, AD-10 ; contraste garanti Material 3). C'est **exactement** le seam à consommer : le widget ne code **aucune** couleur, ne connaît **aucune** clé study (`success`/`warning`/… restent côté resolver injecté). La parité lex (`folder_card.dart`) fait `accent.withValues(alpha: 0.12)` pour la teinte de fond — on reproduit à l'identique **à partir de `pair.color`**.

⇒ **API** : `colorKey` (`String`, opaque) + `colorSlotIndex` (`int`, défaut `0`) passés tels quels à `zResolveColorKeyOrSlot`. La dérivation d'index déterministe (`ZColorPalette.indexOf`) reste **côté app/bridge** (le kernel est la source unique — cf. doc-comment du resolver) : le widget ne l'importe pas.

### D3 — Le compteur/badges est un SLOT `Widget?`, pas un `int` — superset lex+IFFD

Preuve du besoin superset : lex affiche un **simple compteur** (`folder_card.dart` : `Text(l10n.folderCardCountSemantics(count))`), IFFD affiche des **badges par type**. Un `int count` figerait la présentation lex et exclurait IFFD. ⇒ slot `counts` (`Widget?`) rendu ancré en bas, à côté du badge « Archivé ». Absent structurellement si `null` (patron `ZStudyToolsItemCard`).

### D4 — Le libellé « Archivé » est INJECTÉ (l10n), jamais codé en dur

`packages/zcrud_core/lib/src/presentation/l10n/z_labels.dart` (`ZcrudLabels`) **n'a aucun** libellé folder/archived (grep négatif). Le patron du package est l'**injection de labels** (cf. `z_study_mindmap_section.dart` : « la SÉMANTIQUE (label a11y) reste toujours injectée, aucun libellé jamais codé en dur »). ⇒ `archivedLabel` (`String?`) : **le badge n'apparaît QUE si `isArchived == true` ET `archivedLabel != null`** — pas de texte en dur, pas de badge muet. Le `semanticLabel` de la carte est lui aussi injectable (repli `title`).

### D5 — La grille RÉUTILISE `ZAdaptiveGrid`, aucun nouveau layout

`packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart` : `ZAdaptiveGrid(children:, minItemWidth:, itemHeight:, …)` (EAGER) et `.builder(itemCount:, itemBuilder:, …)` (virtualisé, NFR-SU9). ⇒ `ZFolderCard` est **une cellule** ; la grille est fournie par `ZAdaptiveGrid` **côté appelant** (la démo SUF-4 et SUF-3 la posent). La story livre la carte + un **test d'intégration** prouvant qu'elle se compose dans `ZAdaptiveGrid.builder` sans overflow. **Ne PAS** réimplémenter de layout de grille dans `z_folder_card.dart`.

### D6 — Titre 2 lignes ellipsé ANCRÉ BAS (parité lex) + hauteur de cellule pilotée par la grille

Parité `folder_card.dart` : `Expanded(child: Align(alignment: AlignmentDirectional.bottomStart, child: Text(title, maxLines: 2, overflow: ellipsis)))`. Le commentaire lex documente **pourquoi** : `Expanded` absorbe la hauteur résiduelle de la cellule (pilotée par `itemHeight` de la grille) ⇒ **jamais d'overflow** sur cellule courte, contrairement à `Spacer` + hauteurs fixes. On reproduit ce patron exact (directionnel).

---

## Acceptance Criteria

1. **AC1 — Accent dérivé de la `colorKey`.** `ZFolderCard(colorKey: k, colorSlotIndex: i, …)` obtient sa pastille pleine et sa teinte de fond en résolvant `zResolveColorKeyOrSlot(context, k, slotIndex: i)` : la pastille utilise `pair.color`, le fond de carte utilise `pair.color.withValues(alpha: 0.12)`. Aucune `Color(0x…)`, aucun `Colors.*`, aucune table de couleurs dans `z_folder_card.dart`. Un `colorKey` reconnu par le resolver injecté (`ZcrudScope.colorKeyResolver`) ET un `colorKey` inconnu (repli `zColorSlotPair` via `colorSlotIndex`) rendent **tous deux** une couleur non nulle contrastée.

2. **AC2 — Badge « Archivé » conditionnel.** Le badge « Archivé » est rendu **si et seulement si** `isArchived == true` **et** `archivedLabel != null`. Il porte le texte `archivedLabel` (jamais un littéral). À `isArchived == false` (ou `archivedLabel == null`), le badge est **structurellement absent** de l'arbre (pas masqué, pas `Opacity(0)`).

3. **AC3 — Slot compteur/badges rendu.** Le `Widget?` `counts` fourni est rendu dans la carte (ancré bas, à côté du slot badge archivé). `counts == null` ⇒ aucun espace réservé, slot absent de l'arbre. Le slot est rendu **verbatim** (le widget n'en interprète jamais le contenu — superset lex compteur / IFFD badges).

4. **AC4 — Slot menu/trailing rendu.** Le `Widget?` `menu` (ex. `IconButton` ⋮) est rendu en tête de carte (aligné en fin, RTL-safe) ; `menu == null` ⇒ slot absent. Le slot conserve sa propre sémantique (jamais exclu de la sémantique — un menu doit rester atteignable au lecteur d'écran, patron `ZStudyToolsItemCard`).

5. **AC5 — Interactions.** `onTap` fourni ⇒ la carte est activable (`InkWell` + `Semantics(button: true, onTap:)`) et l'appui déclenche exactement `onTap`. `onLongPress` fourni ⇒ appui long déclenche exactement `onLongPress`. `onTap == null` **et** `onLongPress == null` ⇒ **aucun** `InkWell` inerte et **pas** de rôle `button` annoncé (AD-45 : absence de capacité structurelle, pas un bouton éteint).

6. **AC6 — Cible d'activation ≥ 48 dp (AD-13).** La carte activable a une hauteur minimale ≥ 48 dp indépendamment du contenu (`ConstrainedBox(minHeight: 48)` ou constante partagée). Un `menu` `IconButton` conserve sa cible ≥ 48 dp (pas de `VisualDensity.compact`).

7. **AC7 — Neutre thémable + RTL (AD-13/FR-26).** Rayon, gaps et typo viennent de `ZcrudTheme.of(context)` / `Theme.of(context)` (repli), jamais de littéral. Tous les insets/alignements sont **directionnels** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`) — aucun `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `TextAlign.left/right`. `const` partout où c'est immuable.

8. **AC8 — Sémantique de carte unique.** La carte activable expose **un seul** nœud sémantique de type bouton portant `semanticLabel` (repli : `title`, complété du texte d'archivage si présent), en excluant de la sémantique les fragments de libellé internes (patron `ExcludeSemantics` ciblé de `ZStudyToolsItemCard`) — MAIS **sans** exclure le slot `menu` (il reste atteignable).

9. **AC9 — Composable dans `ZAdaptiveGrid` sans overflow.** `ZFolderCard` se rend en cellule de `ZAdaptiveGrid.builder(itemCount:, itemBuilder:, minItemWidth:, itemHeight:)` sur une largeur produisant ≥ 2 colonnes, titre long (2 lignes ellipsées ancrées bas), sans exception de layout ni overflow, sur cellule courte **et** haute.

10. **AC10 — Golden neutre.** Un test golden fige le rendu par défaut de `ZFolderCard` (thème fixe déterministe, police Ahem, animations off) : carte plate, radius thème, fond teinté `alpha 0.12`, pastille pleine, titre 2 lignes ancré bas, badge « Archivé » présent. Golden versionné sous `packages/zcrud_study/test/golden/goldens/`.

11. **AC11 — Export public.** `ZFolderCard` est exporté par le barrel `packages/zcrud_study/lib/zcrud_study.dart` (avec un commentaire de traçabilité SUF-2). `flutter analyze` RC=0 sur le package.

---

## Tasks / Subtasks

- [x] **T1 — Créer `z_folder_card.dart`** (AC1, AC7, AC8) — (packages/zcrud_study/lib/src/presentation/z_folder_card.dart)
  - [x] Doc-comment de tête : rôle, frontière (props primitives, jamais l'entité), invariants AD-2/AD-13/FR-26, parité lex référencée.
  - [x] Signature : `title` (String, requis), `colorKey` (String, requis), `colorSlotIndex` (int = 0), `counts` (Widget?), `menu` (Widget?), `archivedLabel` (String?), `isArchived` (bool = false), `onTap` (VoidCallback?), `onLongPress` (VoidCallback?), `semanticLabel` (String?), `tintAlpha` (double = 0.12), `key`.
  - [x] Résolution accent : `final pair = zResolveColorKeyOrSlot(context, colorKey, slotIndex: colorSlotIndex);` — pastille = `pair.color`, fond = `pair.color.withValues(alpha: tintAlpha)`.
  - [x] Layout : `Column` directionnel → Row(pastille pleine + `Spacer` + slot `menu`), `Expanded(Align(bottomStart, Text(title, maxLines: 2, ellipsis, TextAlign.start)))`, Row(slot `counts` en `Expanded` + badge archivé conditionnel). **Nuance dev** : le titre est ancré bas par `Expanded(Align)` UNIQUEMENT sous hauteur bornée (cellule de grille) via un `LayoutBuilder` ; sous hauteur NON bornée (min-content) la colonne est `MainAxisSize.min` + titre plain (un `Expanded` y lèverait « unbounded height »). Cette bascule réconcilie D6/AC9 (ancre bas + anti-overflow) et AC6/G10 (plancher 48 dp réellement mordant).
  - [x] Radius/gaps depuis `ZcrudTheme.of(context)` (`radiusM`, `gapM`, `gapS`) ; typo depuis `Theme.of(context).textTheme`.
- [x] **T2 — Cible ≥ 48 dp + activation AD-45** (AC5, AC6) — `ConstrainedBox(minHeight: kZFolderCardMinHeight = 48)` ; `onTap == null && onLongPress == null` ⇒ pas d'`InkWell`, pas de `button:` ; sinon `InkWell(onTap:, onLongPress:, excludeFromSemantics: true)` + `Semantics(button: true, onTap:, onLongPress:, label:)`.
- [x] **T3 — Badge « Archivé » conditionnel** (AC2) — sous-widget privé `_ArchivedBadge` (fond `surfaceContainerHighest`, texte `onSurfaceVariant`, radius thème), rendu `if (isArchived && archivedLabel != null)`.
- [x] **T4 — Slots menu/counts + sémantique** (AC3, AC4, AC8) — slots rendus verbatim ; `ExcludeSemantics` ciblé sur les seuls libellés internes (titre + badge archivé déjà porté par le `label`) ; `menu`/`counts` NON exclus ; `semanticLabel` = injecté ?? `title` (+ `', $archivedLabel'` si archivé).
- [x] **T5 — Export barrel** (AC11) — ajouter `export 'src/presentation/z_folder_card.dart';` avec commentaire SUF-2.
- [x] **T6 — Tests R3** (AC1..AC9) — `packages/zcrud_study/test/presentation/z_folder_card_test.dart` (13 gardes G1..G13 + G11b source-grep + G12b, cf. § Testing).
- [x] **T7 — Golden neutre** (AC10) — `packages/zcrud_study/test/golden/z_folder_card_golden_test.dart` + `goldens/z_folder_card_neutral.png` (harnais `_fixtures.buildFixedTheme`, surface/dpr/textScale figés) ; généré via `--update-goldens`, mordancy prouvée (`tintAlpha 0.12→0.45` ⇒ mismatch pixel).
- [x] **T8 — Vérif verte** — `dart analyze packages/zcrud_study` RC=0 (0 error/warning sur la story) ; `flutter test` (zcrud_study) RC=0 — 557 tests verts.

---

## Dev Notes

### Patron de référence à RÉUTILISER (ne rien réinventer)

- **`ZStudyToolsItemCard`** — `packages/zcrud_study/lib/src/presentation/z_study_tools_item_card.dart:51`. Modèle de discipline pour : `ConstrainedBox(minHeight: 48)`, `Semantics(container: true, button: tap != null, onTap: tap, label:)`, `InkWell(excludeFromSemantics: true)` sur activation, `ExcludeSemantics` **ciblé** sur les libellés seulement (le menu `trailing` reste atteignable), `EdgeInsetsDirectional`, radius via `ZcrudTheme.of(context)`. **Reproduire ces choix**, ne pas en inventer d'autres.
- **`zResolveColorKeyOrSlot`** — `packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:218`. Point d'entrée **total** (jamais `null`, jamais de throw). Retourne `ZColorPair {color, onColor}` contrasté. Signature exacte : `zResolveColorKeyOrSlot(BuildContext context, String colorKey, {required int slotIndex})`.
- **`ZcrudTheme.of(context)`** — `packages/zcrud_core/lib/src/presentation/theme/z_theme.dart` : `gapS = 4`, `gapM = 8`, `gapL = 16`, `radiusM = Radius.circular(8)`. Source unique des gaps/radius.
- **`ZAdaptiveGrid` / `ZAdaptiveGrid.builder`** — `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:57` et `:88`. Grille adaptative par largeur-min (garde vide → `SizedBox.shrink`). La carte est la **cellule** ; la grille est posée par l'appelant.

### Parité visuelle cible (LECTURE SEULE — packages/lex_ui/lib/presentation/widgets/study/folder_card.dart)

Le natif lex `FolderCard` est la cible « quasiment aucune différence visuelle » (plan § Objectif). Structure lex à reproduire **en neutre** :
- `Card(color: accent.withValues(alpha: 0.12), clipBehavior: antiAlias)` + `InkWell(onTap:, onLongPress:)`.
- Header Row : pastille pleine `Container(14×14, BoxShape.circle, color: accent)` + `Spacer()` + `IconButton(more_vert)` (cible ≥ 48 dp, **pas** de `VisualDensity.compact`).
- `Expanded(Align(bottomStart, Text(title, maxLines: 2, ellipsis, titleMedium w600)))`.
- Footer Row : compteur (`Expanded`) + badge archivé conditionnel.
- `_ArchivedBadge` : `Container(padding H8/V2, color: surfaceContainerHighest, radius 8, Text(label, labelSmall, onSurfaceVariant))`.
- `Semantics(button: true, label: isArchived ? '$title, $archivedLabel, …' : '$title, …')`.

**Écarts imposés par l'architecture zcrud (NON-NÉGOCIABLES) :**
- lex fait `ref.watch(folderCardCountProvider(folder.id))` → **INTERDIT ici** (AD-2 : aucun gestionnaire d'état, `ConsumerWidget` banni). Le compteur devient un **slot `counts` injecté** par l'hôte (D3).
- lex prend `StudyFolder folder` → **INTERDIT ici** (D1) : props primitives (`title`, `colorKey`).
- lex fait `FolderColorPalette.colorFor(folder.colorKey)` (table locale) → **INTERDIT ici** (D2) : `zResolveColorKeyOrSlot`.
- lex fait `l10n.folderArchivedBadge` → **INTERDIT ici** (D4) : `archivedLabel` injecté.

### Invariants d'architecture applicables (architecture.md — 16 AD)

- **AD-2 / AD-15** : `StatelessWidget` pur-Flutter. AUCUN `WidgetRef`/`Get.`/`Provider.of`, aucun `ConsumerWidget`, aucun `setState`. Le widget **ne détient aucun état** (pas de compteur, pas de sélection — tout est props/slots). Rien à disposer.
- **AD-4** : props opaques ; `colorKey` = `String` neutre ; jamais l'entité `ZStudyFolder`. Slot `null` ⇒ absent (jamais un no-op).
- **AD-13 / FR-26** : `Semantics` explicites, cible ≥ 48 dp, insets/alignements **directionnels**, aucune couleur/typo/radius codé en dur (thème injecté, repli `Theme.of`). `const` où immuable.
- **AD-45** : absence d'activation = structurelle (pas d'`InkWell` inerte, pas de `button:` annoncé).
- **AD-10** : `zResolveColorKeyOrSlot` est total (aucun throw même sur `colorKey` inconnu / index hors-bornes — déjà garanti par le resolver).

### Project Structure Notes

- Nouveau fichier : `packages/zcrud_study/lib/src/presentation/z_folder_card.dart`.
- Barrel modifié : `packages/zcrud_study/lib/zcrud_study.dart` (ajout `export`).
- Tests : `packages/zcrud_study/test/presentation/z_folder_card_test.dart` + `packages/zcrud_study/test/golden/z_folder_card_golden_test.dart` + golden sous `test/golden/goldens/`.
- Aucune écriture `zcrud_core`, aucun autre package. Aucune nouvelle dépendance (`zcrud_responsive`/`zcrud_core` déjà déclarés — `packages/zcrud_study/pubspec.yaml`).
- **Aucun codegen** (pas de `@ZcrudModel`) : pas de `melos run generate` requis pour cette story, mais `analyze`/`test` verts obligatoires.

### Previous Story Intelligence (SUF-1)

SUF-1 (`suf-1-page-shell-searchable-appbar.md`, `ready-for-dev`) crée le page-shell dans `zcrud_ui_kit` — **package disjoint**, aucun couplage de code avec cette story (SUF-2 ↔ SUF-1 parallélisables selon le plan). Leçon transverse retenue de SUF-1 : re-vérifier chaque affirmation de la consigne sur disque avant dev (SUF-1 a corrigé « ~6 écrans » → 11) — appliqué ici (la parité lex a été lue à la source, pas supposée).

### References

- [Source: /home/zakarius/.claude/plans/tingly-brewing-cake.md#Stories › SUF-2]
- [Source: packages/zcrud_study/lib/src/presentation/z_study_tools_item_card.dart:51 — patron slots + a11y]
- [Source: packages/zcrud_study/lib/src/presentation/z_study_mindmap_section.dart — patron folderId opaque + labels injectés]
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_color_key_resolver.dart:218 — zResolveColorKeyOrSlot]
- [Source: packages/zcrud_core/lib/src/presentation/theme/z_theme.dart:32 — jetons gap/radius]
- [Source: packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:57 — ZAdaptiveGrid(.builder)]
- [Source: packages/lex_ui/lib/presentation/widgets/study/folder_card.dart — parité visuelle cible (LECTURE SEULE)]
- [Source: architecture.md — AD-2, AD-4, AD-10, AD-13, AD-15, AD-45, FR-26]

---

## Testing — discipline R3 (chaque garde PROUVÉE mordante)

**Principe R3 :** chaque test doit **rougir** si l'on ré-injecte la régression qu'il prétend interdire. Pour chaque garde ci-dessous, le dev doit vérifier localement que le retrait de la ligne de production correspondante fait **échouer** le test (documenté dans les Completion Notes ; ne jamais laisser un test tautologique).

Fichier `test/presentation/z_folder_card_test.dart` :

1. **G1 (AC1 — accent dérive du colorKey, resolver injecté).** Monter la carte sous un `ZcrudScope` avec un `colorKeyResolver` renvoyant une `ZColorPair` **distinctive** (ex. `color: Color(0xFFAABBCC)`) pour `colorKey = 'x'`. Asserter que la pastille (`Container` `BoxDecoration.color`) == `0xFFAABBCC` et que le fond de carte == `0xFFAABBCC`.withValues(alpha: 0.12). **Mord** : si la prod code une couleur en dur au lieu de `zResolveColorKeyOrSlot`, la couleur distinctive n'apparaît pas → rouge.
2. **G2 (AC1 — repli slot sur colorKey inconnu).** Sans resolver injecté (ou resolver renvoyant `null`), `colorKey = 'inconnu'`, `colorSlotIndex: 1` vs `colorSlotIndex: 3` produisent des pastilles de couleurs **différentes** (slots distincts du `ColorScheme`). **Mord** : si la prod ignore `colorSlotIndex` (couleur fixe), les deux montages sont identiques → rouge.
3. **G3 (AC2 — badge archivé apparaît).** `isArchived: true, archivedLabel: 'ARCH'` ⇒ `find.text('ARCH')` trouve **un** nœud. **Mord** : si la prod n'affiche jamais le badge → rouge.
4. **G4 (AC2 — badge archivé disparaît).** `isArchived: false, archivedLabel: 'ARCH'` **et** `isArchived: true, archivedLabel: null` ⇒ `find.text('ARCH')` = `findsNothing` dans les deux cas (absence structurelle). **Mord** : si la prod rend le badge inconditionnellement, ou le rend à `label == null` → rouge.
5. **G5 (AC3 — slot compteur rendu / absent).** `counts: Text('42 cartes')` ⇒ `find.text('42 cartes')` trouvé ; `counts: null` ⇒ `findsNothing`. **Mord** : slot ignoré → rouge.
6. **G6 (AC4 — slot menu rendu / absent + atteignable).** `menu: IconButton(key: ValueKey('m'), …)` ⇒ trouvé ; `menu: null` ⇒ `findsNothing`. Vérifier que le menu **n'est pas** exclu de la sémantique (le `Semantics` du menu reste dans l'arbre). **Mord** : slot ignoré, ou `ExcludeSemantics` trop large englobant le menu → rouge.
7. **G7 (AC5 — onTap déclenché).** `onTap` incrémente un compteur ; `tester.tap(find.byType(ZFolderCard))` ⇒ compteur == 1. **Mord** : `onTap` non câblé → rouge.
8. **G8 (AC5 — onLongPress déclenché).** `tester.longPress(...)` ⇒ callback long invoqué. **Mord** : non câblé → rouge.
9. **G9 (AC5/AD-45 — pas d'InkWell inerte).** `onTap: null, onLongPress: null` ⇒ `find.byType(InkWell)` = `findsNothing` **et** la carte n'expose pas `SemanticsFlag.isButton`. **Mord** : `InkWell` toujours présent, ou `button: true` inconditionnel → rouge.
10. **G10 (AC6 — cible ≥ 48 dp).** Carte activable à contenu minimal (`title` court, aucun slot) ⇒ `tester.getSize(find.byType(ZFolderCard)).height >= 48`. **Mord** : retrait du `ConstrainedBox(minHeight: 48)` → hauteur < 48 → rouge.
11. **G11 (AC7 — RTL directionnel).** Monter sous `Directionality(textDirection: TextDirection.rtl)` ; le rendu ne lève pas et l'alignement du titre suit le sens (vérifier via `AlignmentDirectional` — pas d'assert de pixel, mais absence d'exception + présence du titre). Garde structurelle : un grep de test **interdit** `Alignment.centerLeft`/`EdgeInsets.only(left`/`TextAlign.left` dans `z_folder_card.dart` (test source-level optionnel). **Mord** : alignement non directionnel → grep positif → rouge.
12. **G12 (AC8 — sémantique unique).** La carte activable expose **un** nœud `isButton` avec le `label` attendu (`title`, + archivé si présent) ; les fragments de titre internes sont exclus (pas de double annonce). **Mord** : `semanticLabel` non appliqué, ou libellés internes non exclus → rouge.
13. **G13 (AC9 — composable dans ZAdaptiveGrid.builder sans overflow).** Monter `ZAdaptiveGrid.builder(itemCount: 6, minItemWidth: 160, itemHeight: 120, itemBuilder: (_, i) => ZFolderCard(title: 'Dossier très long …', colorKey: 'k$i', menu: …, counts: …))` sur `Size(500, …)` ⇒ ≥ 2 colonnes, aucune exception de layout, aucun `RenderFlex overflow` (asserter `tester.takeException()` == null sur cellule courte **et** haute). **Mord** : titre sans `Expanded`/`Align` ancré bas → overflow sur cellule courte → rouge.

Fichier `test/golden/z_folder_card_golden_test.dart` (AC10) :

14. **G14 (golden neutre).** Rendu figé (thème fixe déterministe du harnais `_fixtures.dart`, police Ahem, `textScaleFactor` figé, animations off) d'une `ZFolderCard(title: …, colorKey: 'secondary', counts: Text(…), menu: Icon(…), isArchived: true, archivedLabel: 'Archivé')`. Golden `test/golden/goldens/z_folder_card_neutral.png`. **Mord** : le golden est une empreinte pixel — toute dérive de layout/teinte le fait rougir (prouver en modifiant `tintAlpha` → diff).

> Note d'exécution : `flutter test` (package Flutter, tests widget/golden — R14). Générer le golden avec `--update-goldens`, puis **prouver qu'il mord** en le comparant après une micro-régression volontaire (documenté dans Completion Notes, régression retirée avant `done`).

---

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (agent BMAD `bmad-dev-story`).

### Debug Log References

- `dart analyze packages/zcrud_study` → RC=0 (0 error/warning ; 51 `info` PRÉ-EXISTANTS dans d'autres fichiers, aucun sur `z_folder_card.dart` après correction du lint `use_null_aware_elements` → `?menu`).
- `flutter test packages/zcrud_study` → RC=0, **557 tests verts** (dont 14 nouveaux du fichier `z_folder_card_test.dart` + 1 golden).

### Completion Notes List

**Décision de conception clé (réconciliation D6 ↔ AC6).** `Expanded` (ancre bas + anti-overflow, D6/AC9) remplit toute hauteur bornée, ce qui rendrait un plancher `minHeight:48` (AC6/G10) soit inopérant (hauteur ≥ 48 déjà imposée par la cellule) soit non mordant. Résolu par un `LayoutBuilder` : branche `Expanded(Align(bottomStart))` sous hauteur **bornée** (cellule de `ZAdaptiveGrid.builder`), branche `MainAxisSize.min` + titre plain sous hauteur **non bornée** (min-content, où le `ConstrainedBox(minHeight:48)` devient le seul plancher — donc réellement mordant). Aucun layout de grille réimplémenté (D5 respecté : la grille reste posée par l'appelant).

**Écarts NON-NÉGOCIABLES vs natif lex tenus** : `StatelessWidget` (jamais `ConsumerWidget`/`ref.watch`, AD-2) ; props primitives (jamais `ZStudyFolder`, D1) ; accent via `zResolveColorKeyOrSlot` (aucune table locale, D2) ; libellé « Archivé » injecté `archivedLabel` (D4) ; compteur = slot `counts` (D3).

**Discipline R3 — mordancy PROUVÉE pour chaque garde** (régression ré-injectée → ROUGE observé → retirée → VERT ; fichier de prod restauré bit-à-bit identique au pristine) :
- **G1** (accent dérivé) : pastille codée en dur `Color(0xFFFF0000)` → G1 ROUGE.
- **G2** (slot distinct sur clé inconnue) : même mutation (couleur fixe) → slot1==slot3 → G2 ROUGE.
- **G3** (badge présent) : badge jamais rendu → ROUGE.
- **G4** (badge absent) : badge rendu inconditionnellement → ROUGE.
- **G5** (slot counts) : `if (counts != null)` → `if (false)` → ROUGE.
- **G6** (menu atteignable) : menu enveloppé d'`ExcludeSemantics` → `bySemanticsLabel('MENU')` ROUGE.
- **G7** (onTap câblé) : `InkWell(onTap: null)` → compteur=0 → ROUGE.
- **G8** (onLongPress câblé) : `InkWell(onLongPress: null)` → ROUGE.
- **G9** (AD-45 absence structurelle) : `interactive = true` forcé → InkWell + `button` présents → ROUGE.
- **G10** (plancher 48 dp) : `minHeight: 0` (contenu à titre `fontSize:2` < 48, hauteur non bornée) → hauteur < 48 → ROUGE.
- **G11b** (source directionnelle) : injection `// TextAlign.left` dans la source → grep positif → ROUGE.
- **G12 / G12b** (sémantique unique / label injecté) : `label: 'WRONG'` → ROUGE.
- **G13** (anti-overflow en grille) : `bounded = false` (pas d'`Expanded`) → RenderFlex overflow **56 px** à `itemHeight=120` → `takeException()` non nul → ROUGE (seuil mesuré : overflow à 80/100/120, sain à 140/240).
- **G14** (golden neutre) : `tintAlpha 0.12 → 0.45` → mismatch pixel du golden committé → ROUGE.

**MEDIUM/nits corrigés dans le périmètre** : lint `use_null_aware_elements` (`if (menu != null) menu!` → `?menu`).

**AC non satisfaits** : aucun. AC1–AC11 couverts.

### File List

- **Créé** : `packages/zcrud_study/lib/src/presentation/z_folder_card.dart` (widget `ZFolderCard` + `_ArchivedBadge` privé + constantes `kZFolderCardMinHeight`/`kZFolderCardTintAlpha`).
- **Créé** : `packages/zcrud_study/test/presentation/z_folder_card_test.dart` (14 gardes R3 : G1..G13 + G11b + G12b).
- **Créé** : `packages/zcrud_study/test/golden/z_folder_card_golden_test.dart` (golden neutre AC10/G14).
- **Créé** : `packages/zcrud_study/test/golden/goldens/z_folder_card_neutral.png` (empreinte golden committée).
- **Modifié** : `packages/zcrud_study/lib/zcrud_study.dart` (export barrel `z_folder_card.dart` + commentaire de traçabilité SUF-2).

### Change Log

- SUF-2 : ajout `ZFolderCard` (carte de dossier d'étude thémable à props primitives) dans `zcrud_study` — accent dérivé de `colorKey`, slots counts/menu, badge « Archivé » injecté, cible ≥ 48 dp, composable dans `ZAdaptiveGrid.builder`. 14 gardes R3 (mordancy prouvée) + golden neutre. Vérif verte : analyze RC=0, `flutter test` RC=0 (557 tests).
