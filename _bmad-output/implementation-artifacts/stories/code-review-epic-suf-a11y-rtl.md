# Code-review epic SUF — lentille « A11y / RTL »

**Date** : 2026-07-26
**Périmètre** : SUF-1 (`zcrud_ui_kit`), SUF-2 + SUF-3 (`zcrud_study`), SUF-4 (`zcrud_session`)
**Hors périmètre (non revu, non touché)** : `packages/zcrud_markdown/`
**Mode** : lecture seule. Aucun fichier de `lib/` ni de `test/` modifié.

**Verdict global : RÉSERVES** — 1 MAJEUR + 2 MEDIUM + 1 LOW. Aucun BLOQUANT :
le RTL est propre (zéro API non-directionnelle en code), les cibles ≥ 48 dp sont
vérifiées runtime, et la crainte explicite de l'orchestrateur sur
l'`ExcludeSemantics` de SUF-4 est **levée par preuve** (§ 5).

---

## 0. Méthode et limite d'environnement

Les tests de `zcrud_study` et `zcrud_session` **ne peuvent pas être joués** : leur
chaîne de compilation traverse `packages/zcrud_markdown/`, laissé dans un état
transitoire non compilable par un workstream parallèle (hors périmètre).

```
$ cd packages/zcrud_session && flutter test test/presentation/suf4_parity_closures_test.dart
../zcrud_markdown/lib/src/data/z_markdown_codec.dart:169:9: Error: 'ZMarkdownEmbedBridge' isn't a type.
00:00 +0 -1: Some tests failed.
```

Ce n'est **pas** un finding de cette revue. Contournement employé : toutes les
assertions de comportement sémantique ont été **prouvées runtime** par des sondes
exécutées depuis `packages/zcrud_ui_kit` (qui, lui, compile — `flutter test` →
`+109: All tests passed!`), les sondes vivant dans le scratchpad
(`/tmp/claude-1000/.../scratchpad/probe*_test.dart`), **jamais** dans `test/`.
Les sondes reproduisent la structure de widget EXACTE lue sur disque.

---

## 1. RTL — API directionnelles : CONFORME (grep négatif)

```
$ grep -rnE "EdgeInsets\.only\(|Alignment\.(center|top|bottom)(Left|Right)|Positioned\(|TextAlign\.(left|right)|EdgeInsets\.fromLTRB|BorderRadius\.only\(|BorderRadius\.horizontal\(" \
    --include='*.dart' packages/zcrud_ui_kit/lib \
    packages/zcrud_study/lib/src/presentation/z_folder_card.dart \
    packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart \
    packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart \
    packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart \
    packages/zcrud_study/lib/src/presentation/z_subfolder_nav_spec.dart \
    packages/zcrud_study/lib/src/presentation/z_subfolder_ref.dart \
    packages/zcrud_session/lib/src/presentation/
packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:284:  // Directionnel (AD-13) — jamais `EdgeInsets.only(left:)`.
packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:464:  // Directionnel (AD-13) — jamais `Alignment.centerLeft/Right`.
packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart:128:  // Directionnel (RTL) — jamais `Alignment.centerRight`.
packages/zcrud_session/lib/src/presentation/z_session_mode_selector.dart:302:  // Directionnel — jamais `TextAlign.left`.
RC=0
```

**4 hits, 4 commentaires, 0 ligne de code.** (`z_session_mode_selector.dart` est
hors périmètre SUF-4 de surcroît.) `EdgeInsetsDirectional` /
`AlignmentDirectional` / `TextAlign.start|center|end` partout ailleurs.

Le RTL du **drag de resize** est correctement inversé (`z_subfolder_sidebar.dart:277-280`)
— le signe du delta bascule sous `TextDirection.rtl`, ce qui est le vrai piège
d'une sidebar redimensionnable ; c'est traité. Idem pour la garde
`matchTextDirection` des glyphes `arrow_back`/`arrow_forward`
(`z_session_progress_indicator.dart:494-503`).

---

## 2. Cibles ≥ 48 dp — CONFORME (mesures runtime)

Trois soupçons ont été mesurés plutôt que supposés ; **tous les trois tombent** :

| Contrôle | Soupçon | Mesure runtime | Verdict |
|---|---|---|---|
| `Tab` de `ZPageScaffold` (`z_page_scaffold.dart:90-102`) | `_kTabHeight = 46.0` en Flutter ⇒ < 48 dp | `PROBETAB 0 size=Size(112.8, 46.0)` **mais** `PROBETABINK 0 size=Size(144.8, 48.0)` | OK — la cible tapable (`InkWell`) fait 48 dp |
| `ChoiceChip` du sélecteur compact (`z_subfolder_compact_selector.dart:88-93`) | hauteur M3 d'un chip = 32 dp | `PROBE2 chip size=Size(48.1, 48.0)` | OK — `MaterialTapTargetSize.padded` par défaut |
| `_DragHandle` (`z_subfolder_sidebar.dart:446-459`) : `ConstrainedBox(min 48)` autour d'un `Icon` de 24 | le `ConstrainedBox` pourrait ne pas mordre | `PROBE3 size=Size(48.0, 48.0)` | OK |

La poignée de resize fait bien 48 dp de large (`_kResizeHitWidth = 48.0`,
`z_subfolder_sidebar.dart:36`) et s'étire en hauteur dans le `Row` — la
**dimension** n'est pas le problème (cf. § 3, F1 : c'est l'atteignabilité).

---

## 3. Findings

### F1 — MAJEUR — Poignée de redimensionnement de la sidebar : ni clavier, ni sémantique, ni alternative au drag

**Fichier** : `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:266-295`

`_resizeHandle` est un `MouseRegion > GestureDetector(onHorizontalDragUpdate/End)`
nu. Aucun `Semantics`, aucun `Focus`, aucun raccourci clavier, aucune action
sémantique personnalisée, aucun bouton « élargir / rétrécir » de repli.

**Preuve — grep négatif sur le corps exact de la méthode** :

```
$ sed -n '266,296p' packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart \
  | grep -nE "Semantics|Focus|Shortcut|onKey|tooltip|label"
RC=1        # aucune occurrence
```

Et sur le fichier entier, les seuls nœuds `Semantics` sont aux lignes 119
(`_buildCollapsed`), 361 (`_SubfolderRow`) et 448 (`_DragHandle`) — **aucun**
dans l'intervalle 266-295 :

```
$ grep -n "Semantics\|Focus\|Shortcuts\|KeyboardListener\|CallbackShortcuts\|onKeyEvent" \
    packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart
24:import 'package:flutter/semantics.dart' show CustomSemanticsAction;
119:    return Semantics(
348:        final moveActions = <CustomSemanticsAction, VoidCallback>{};
351/356: CustomSemanticsAction(...)
361:        return Semantics(
365:          customSemanticsActions: ...
370:            excludeFromSemantics: true,
448:      child: Semantics(
```

**Conséquences**

1. **Non-conformité à l'AC15 de la story SUF-3** (`suf-3-…md:113`) : « Toutes les
   cibles interactives (items, repli, drag-handle, boutons) ≥ 48 dp ; `Semantics`
   explicites ». La poignée de resize est une cible interactive **sans aucun
   `Semantics`** — elle n'existe pas pour un lecteur d'écran, et son en-tête de
   fichier annonce pourtant « `Semantics` explicites » (`:16`).
2. **WCAG 2.1.1 (Keyboard)** : la fonction « redimensionner » n'est atteignable
   par **aucun** moyen clavier. Le bouton de repli (`collapseToggleKey`) n'en est
   pas une alternative : il masque la liste, il ne règle pas la largeur.
3. **WCAG 2.5.7 (Dragging Movements)** : aucune alternative à pointeur unique.
   Le contraste est frappant avec le **réordonnancement** de la même sidebar, qui
   a *déjà* son alternative accessible (`customSemanticsActions` « déplacer
   avant / après », `:348-359`) — le motif était connu et n'a pas été appliqué au
   resize.

**Correctif suggéré (périmètre story)** : envelopper la poignée d'un
`Semantics(label: <label injecté>, value: '<largeur>' , increasedValue/decreasedValue,
onIncrease: → clamp(width + step), onDecrease: → clamp(width - step))` — les deux
callbacks réutilisent tels quels `onWidthChanged` + `onWidthChangeEnd`, aucun état
nouveau, aucune I/O — et rendre la poignée focusable (`Focus` +
`CallbackShortcuts` flèches gauche/droite, avec inversion RTL identique à
`:277-280`). Les libellés doivent être **injectés** via `ZSubfolderNavSpec`
(nouveaux champs `resizeLabel` / `widenLabel` / `narrowLabel`), jamais littéraux.

---

### F2 — MAJEUR — `ZFolderCard` NON interactive : titre et badge « Archivé » totalement inaudibles

**Fichier** : `packages/zcrud_study/lib/src/presentation/z_folder_card.dart:177`, `:184`, `:280`

Trois lignes se combinent en un trou :

```dart
:177   ExcludeSemantics(child: _ArchivedBadge(label: archivedLabel!)),   // INCONDITIONNEL
:184   final Widget titleText = ExcludeSemantics(                        // INCONDITIONNEL
:185     child: Text(title, maxLines: 2, …),
:186   );
…
:253   final bool interactive = onTap != null || onLongPress != null;
…
:280   if (!interactive) return card;                                    // sort AVANT le Semantics
:282   return Semantics(container: true, button: true, …,
:287     label: semanticLabel ?? (showArchived ? '$title, ${archivedLabel!}' : title),
```

Les deux `ExcludeSemantics` sont justifiés en commentaire par « le texte est DÉJÀ
porté par le `label` du nœud de la carte » — ce qui est vrai **uniquement** dans
la branche interactive. Quand `onTap == null && onLongPress == null` (cas
explicitement supporté par l'AD-45 et testé par la garde G9,
`z_folder_card_test.dart:205`), le `return` de la ligne 280 saute le nœud porteur
du `label`… mais **les `ExcludeSemantics`, eux, restent**. Le `semanticLabel`
injecté est également ignoré dans cette branche.

**Preuve runtime** — sonde reproduisant la structure exacte de la branche
non-interactive (`probe5_test.dart`, jouée depuis `packages/zcrud_ui_kit`) :

```
--- arbre semantique (carte NON interactive) ---
                                    ← AUCUN nœud avec label ou action
PROBECARD titre trouvable par label = 0
PROBECARD badge trouvable par label = 0
00:00 +1: All tests passed!
```

L'arbre sémantique de la carte est **vide**. Une carte de dossier en lecture seule
(mode consultation, dossier verrouillé par ACL, grille non cliquable) affiche à
l'écran un titre et un badge « Archivé » **sans aucun équivalent accessible** :
échec WCAG 1.1.1 / 1.3.1, et violation directe de l'AD-13 (« `Semantics`
explicites »).

À noter : **les ACs de SUF-2 sont formellement satisfaits** — l'AC8 ne parle que
de « la carte **activable** », l'AC5/AD-45 n'exige que l'absence du rôle `button`.
C'est précisément le cas « conforme à la lettre, cassé à l'usage » que cette
lentille doit remonter : AD-45 demande de ne pas annoncer un **bouton** éteint,
pas de rendre le **contenu** muet.

**Correctif suggéré** : dans la branche `!interactive`, envelopper `card` d'un
`Semantics(container: true, label: semanticLabel ?? (showArchived ? '$title, ${archivedLabel!}' : title))`
— même expression de label qu'en `:287`, sans `button:` ni `onTap:` (l'absence de
capacité reste structurelle). Alternative équivalente : ne poser les
`ExcludeSemantics` de `:177` et `:184` que `if (interactive)`. Garde R3 à ajouter :
carte sans `onTap`/`onLongPress` ⇒ `find.bySemanticsLabel(title)` trouve 1 nœud,
et retirer le correctif la fait rougir.

---

### F3 — MEDIUM — Libellés a11y de repli : trois contrôles distincts annoncés avec le libellé de l'item racine

**Fichiers** :
- `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:160-162` (bascule repli/déploi)
- `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:248` (bouton « Ajouter »)
- `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:414` (poignée de reorder)
- `packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart:99` (bouton « Ajouter » compact)

```dart
:160  final label = collapsed
:161      ? (spec.expandLabel   ?? spec.allSubfoldersLabel)
:162      : (spec.collapseLabel ?? spec.allSubfoldersLabel);
:248  final label = spec.addLabel ?? spec.allSubfoldersLabel;
:414  label: spec.reorderHandleLabel ?? spec.allSubfoldersLabel,
```

Les quatre champs de repli sont `String?` non requis
(`z_subfolder_nav_spec.dart:42-45, 77`) : un appelant qui n'injecte que
`allSubfoldersLabel` (le seul requis avec `subfolders`) obtient une sidebar où le
bouton de repli, le bouton d'ajout, **chaque** poignée de reorder **et** l'item
racine annoncent tous la même chaîne — typiquement « Tous les sous-dossiers ».

Un libellé **faux** est pire qu'un libellé absent : l'utilisateur de lecteur
d'écran entend « Tous les sous-dossiers, bouton » et active… le repli de la
sidebar. La dartdoc assume le compromis (`z_subfolder_nav_spec.dart:75-76` :
« pour ne jamais rendre un contrôle sans annonce ») mais l'arbitrage est mal
posé : le repli choisi ne « nomme » pas le contrôle, il le **désigne comme un
autre contrôle**.

**Correctif suggéré** : soit rendre ces libellés **requis** dès que la capacité
correspondante est fournie (assert : `addAction != null ⇒ addLabel != null`,
`onReorder != null ⇒ reorderHandleLabel != null`, symétrique de la règle
« capacité absente si le callback est nul » déjà appliquée à `onReorder`), soit
retomber sur `MaterialLocalizations` (comme SUF-1 le fait pour `search`/`close`,
`z_page_shell.dart:98-107`) plutôt que sur un libellé métier sans rapport.

---

### F4 — MEDIUM — Bouton de débordement de l'app-bar : `SemanticsData.label` vide, hors des seams l10n

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:189-207`

```dart
:190  PopupMenuButton<int>(
:191    icon: const Icon(Icons.more_vert),      // ni semanticLabel, ni tooltip:
```

C'est le **seul** contrôle du fichier à ne pas recevoir de `semanticLabel`
explicite : les actions inline en reçoivent un obligatoire (`:185`,
`ZAppBarAction.semanticLabel` est `required`), la loupe et la fermeture passent par
les seams `_resolveSearchLabel`/`_resolveCloseLabel` (`:98-107`).

**Preuve runtime** (`probe4_test.dart`, `ZSearchableAppBar` réel avec une action
`isOverflow: true` + une action inline) :

```
- label=<T>       tooltip=<>          actions=0          ← titre
- label=<Editer>  tooltip=<>          actions=4194305    ← action inline : nommée
- label=<>        tooltip=<Show menu> actions=4194305    ← PopupMenuButton : NON nommé
PROBE popup tooltip prop = null
```

Deux conséquences :

1. Le nœud n'a **pas de nom accessible** ; il ne porte qu'un `tooltip`. Le tooltip
   est exposé (Android `setTooltipText`, iOS concaténation) mais reste un canal
   secondaire — et sur les plateformes/versions qui l'ignorent, l'annonce est
   « bouton », sans plus.
2. Ce libellé de repli vient de `MaterialLocalizations.showMenuTooltip` **en
   dur en anglais** ici (`Show menu`) alors que tout le reste du fichier passe
   d'abord par `ZcrudScope.labels` puis `ZcrudLocalizations` : une app hôte qui
   injecte sa table l10n peut traduire « rechercher » et « fermer », **pas** ce
   bouton-ci. Incohérence de seam, pas seulement de libellé.

**Correctif suggéré** : `tooltip:` + `Icon(..., semanticLabel:)` résolus par une
fonction `_resolveMoreLabel(context)` sur le modèle exact de `_resolveCloseLabel`
(`ZcrudScope.labels` → `ZcrudLocalizations` → `MaterialLocalizations.showMenuTooltip`).

---

### F5 — LOW — Mode recherche : deux contrôles portent le même nom accessible « Close »

**Fichier** : `packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:122-128` (leading) et `:208-220` (action de fin)

En mode recherche, l'app-bar rend simultanément un `IconButton(Icons.arrow_back)`
en leading **et** un `IconButton(Icons.close)` en action, tous deux étiquetés par
`_resolveCloseLabel(context)` et déclenchant la même fermeture.

**Preuve runtime** (`probe3_test.dart`, app-bar réelle après tap sur la loupe) :

```
- label=<Close>  actions=4194305  rect=0,0,48,48     ← leading arrow_back
- label=<Search> actions=6293505  rect=0,0,664,48    ← le TextField
- label=<Close>  actions=4194305  rect=0,0,48,48     ← action de fin
```

Deux nœuds au nom **strictement identique** dans la même barre. Ce n'est pas
trompeur (les deux ferment bien la recherche) mais c'est une double annonce et un
contrôle redondant à la navigation séquentielle. LOW : à arbitrer (supprimer l'un,
ou différencier — p.ex. « effacer la recherche » pour l'action de fin, qui vide
déjà le champ via `_ZSearchController.close`, `:77-82`).

---

## 4. Reduce Motion — non applicable sur SUF-1/2/3, correct sur SUF-4

```
$ grep -rn "reduceMotion\|zReduceMotionOf\|disableAnimations" --include='*.dart' \
    packages/zcrud_ui_kit/lib \
    packages/zcrud_study/lib/src/presentation/z_study_folder_detail.dart \
    packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart \
    packages/zcrud_study/lib/src/presentation/z_folder_card.dart \
    packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart
RC=1        # aucune occurrence
```

**Pas un finding** : la primitive unique du dépôt (`zReduceMotionOf`) n'a de sens
que devant une animation **écrite par nous**. Aucun des livrables SUF-1/2/3 n'en
porte : le repli de sidebar est un échange de sous-arbre instantané
(`z_subfolder_sidebar.dart:110-113`), la sélection un `ValueListenableBuilder`, la
carte un `Card` statique. Les seules animations en jeu (encre `InkWell`, glissement
de `TabBarView`, `SliverAppBar` floating) sont pilotées par le framework et par les
réglages système, hors de portée du widget.

SUF-4 est conforme au motif du dépôt : `ZSwipeEmotionIndicator` prend un
`reduceMotion` **injecté** et le dégrade réellement (opacité binaire au seuil,
échelle figée — `z_session_progress_indicator.dart:427-440`), sans jamais dégrader
la **fonction**.

---

## 5. Levée de la suspicion de l'orchestrateur : l'`ExcludeSemantics` de SUF-4 ne rend RIEN inaudible

Question posée : masquer la double annonce `['2/4', '50']` n'a-t-il pas supprimé
**toute** annonce ?

**Réponse : non — l'information reste annoncée, une seule fois, dans la bonne
unité.** L'`ExcludeSemantics` (`z_session_progress_indicator.dart:248`) est
**interne** au `Semantics(key: progressKey, label:…, value: '$position/$total')`
(`:212-223`) : il retire le nœud *enfant* que le `LinearProgressIndicator` du
framework fabrique (et dont le framework **calcule** un pourcentage même quand on
lui passe `semanticsValue: null`), pas le nœud parent porteur de la progression.

**Preuve runtime** (`probe3_test.dart`, structure identique : `Semantics(label,
value) > ExcludeSemantics > LinearProgressIndicator`) :

```
- label=<progression> value=<2/4> actions=0 rect=Rect.fromLTRB(0.0, 0.0, 800.0, 4.0)
```

Le `value` survit. La garde R3 de SUF-4 énumère d'ailleurs **tout** le sous-arbre
et exige `announcing == ['2/4']`
(`packages/zcrud_session/test/presentation/suf4_parity_closures_test.dart:271-281`)
— exactement la bonne forme de garde (elle rougirait aussi bien sur zéro annonce
que sur deux). Ce test ne peut pas être **joué** ici (§ 0) mais son assertion est
la bonne, et le comportement du framework qu'elle encode est vérifié
indépendamment ci-dessus.

Contrôles connexes vérifiés au passage :
- la couleur n'est jamais le seul canal — `_QualityButton` porte
  `Semantics(button, selected, label, value)` + une **coche** (forme) +
  le texte du cran (`z_srs_quality_buttons.dart:371-419`) ;
- `passed`/`lapsed`/`selected` passent par des clés l10n avec `fallback`
  (`:337-344`, `:360-367`) — la dette « `'ok'`/`'lapse'` en dur » est bien soldée ;
- l'`ZSwipeEmotionIndicator` a remplacé les visages évaluatifs par des flèches
  `matchTextDirection` (`:494-503`) : neutre **et** RTL-correct.

---

## 6. Points vérifiés sans finding (traces)

| Vérification | Résultat |
|---|---|
| `ZFolderCard` interactive : le slot `menu` reste-t-il atteignable malgré `Semantics(container: true)` sans `explicitChildNodes` ? | **Oui** — sonde `probeA` : `label=<Chapitre 3>` → enfant `label=<42 cartes>` → petit-enfant `label=<Menu>` ; `find.bySemanticsLabel("Menu")` = 1 |
| `_SubfolderRow` : `Semantics(selected, button, onTap)` **sans** `label`, autour d'un `InkWell(excludeFromSemantics: true)` — le libellé de l'item se perd-il ? | **Non** — sonde `probe1` : `label=<Sous-dossier A> actions=4194305 flags=270532620` (bouton + sélectionné, label fusionné depuis le `Text`) |
| `InkWell(excludeFromSemantics: true)` casse-t-il l'activation clavier ? | Non — `excludeFromSemantics` ne neutralise que le `Semantics` du geste ; le `Focus` + `ActionMap` de `InkResponse` subsistent (activation ENTER/ESPACE conservée) |
| `ZSearchableAppBar` : `Échap` ferme la recherche au clavier | Oui — `CallbackShortcuts(SingleActivator(escape))`, `z_page_shell.dart:143-146` |
| RTL de l'app-bar : leading ancré à droite | Oui — garde existante `z_page_shell_rtl_a11y_test.dart:28-35`, rejouée verte (`flutter test packages/zcrud_ui_kit` → `+109: All tests passed!`) |
| Champ de recherche : nom accessible | `label=<Search>` (sonde `probe3`) — hint résolu par les seams l10n, repli `MaterialLocalizations.searchFieldLabel` |

---

## 7. Synthèse

| # | Sévérité | Fichier:ligne | Résumé |
|---|---|---|---|
| F1 | **MAJEUR** | `z_subfolder_sidebar.dart:266-295` | Poignée de resize : aucun `Semantics`, aucun clavier, aucune alternative au drag (AC15 SUF-3, WCAG 2.1.1 / 2.5.7) |
| F2 | **MAJEUR** | `z_folder_card.dart:177,184,280` | Carte non interactive : titre + badge sous `ExcludeSemantics` inconditionnel, `return` avant le nœud porteur du label ⇒ arbre sémantique **vide** |
| F3 | MEDIUM | `z_subfolder_sidebar.dart:160,248,414` + `z_subfolder_compact_selector.dart:99` | Repli `?? allSubfoldersLabel` : 3-4 contrôles distincts annoncés avec le libellé de l'item racine |
| F4 | MEDIUM | `z_page_shell.dart:189-191` | `PopupMenuButton` de débordement : `SemanticsData.label` vide, libellé hors des seams `ZcrudScope`/`ZcrudLocalizations` |
| F5 | LOW | `z_page_shell.dart:122-128` + `:208-220` | Deux contrôles nommés « Close » simultanément en mode recherche |

**Verdict : RÉSERVES.** F1 et F2 sont à corriger avant `done` (les deux sont des
correctifs locaux de quelques lignes, sans nouvel état ni nouvelle dépendance).
F3 et F4 sont corrigibles dans le périmètre des stories. F5 relève d'un arbitrage
de design.
