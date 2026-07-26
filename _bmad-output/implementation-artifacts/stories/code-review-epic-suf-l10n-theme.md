# Code-review epic SUF — lentille « L10n / thème »

**Date** : 2026-07-26
**Périmètre** : SUF-1 (`zcrud_ui_kit`), SUF-2 / SUF-3 (`zcrud_study`), SUF-4 (`zcrud_session`).
**Hors périmètre (non lu, non commenté)** : `packages/zcrud_markdown/`.
**Mode** : LECTURE SEULE — aucun fichier de `lib/` ni de `test/` modifié.

**Verdict global : RÉSERVES.** Aucun libellé utilisateur ni aucune couleur codés en
dur dans les fichiers **neufs** de l'epic ; les 5 nouveaux paramètres audités
(`archivedLabel`, `hintLabel`, `linearThickness`, `ZSrsQualityEmphasis`,
`ZQualityBreakdownCoverage`) sont bien des **seams injectables** dont les défauts
préservent le rendu historique — preuves ci-dessous. Restent **2 points
d'injection manquants** (thème d'app-bar non atteignable, épaisseur `linear` non
propagée par le swiper), **1 chaîne française en dur** (pré-existante, dans un
fichier du diff) et **1 famille de replis de libellé sémantiquement faux**.

---

## 1. Ce qui est PROUVÉ conforme

### 1.1 Zéro couleur codée en dur

```
$ grep -rnE "Colors\.[a-zA-Z]|Color\(0x|Color\.fromARGB|Color\.fromRGBO" \
    packages/zcrud_ui_kit/lib packages/zcrud_study/lib packages/zcrud_session/lib
packages/zcrud_session/lib/src/presentation/z_session_progress_indicator.dart:447:    // Rôle Material 3 résolu par le cœur — jamais un `Colors.*`/`Color(0x…)`.
packages/zcrud_session/lib/src/presentation/z_streak_badge.dart:129:                // `Colors.*` (NFR-SU5). Mon premier jet portait `Colors.red` —
packages/zcrud_session/lib/src/presentation/z_session_summary_view.dart:694:/// | `colors: null` ⇒ couleurs **aléatoires** ; `strokeColor = Colors.black` en dur | …
packages/zcrud_study/lib/src/presentation/z_folder_card.dart:27:///   Material 3 garanti). AUCUNE `Color(0x…)`, aucun `Colors.*`, aucune table de
packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart:15:/// jamais de `Colors.*`/`Color(0x…)`/string utilisateur en dur. Directionnel
RC=0
```

**Les 5 occurrences sont des COMMENTAIRES** (`///` ou `//`). Aucune occurrence
en code. Toutes les couleurs des trois packages passent par
`zResolveColorKeyOrSlot` (seam du cœur), `Theme.of(context).colorScheme` ou
`ZcrudTheme.of(context)`.

### 1.2 Zéro libellé utilisateur en dur dans les fichiers NEUFS

```
$ grep -rnE "Text\(\s*'|Text\(\s*\"|semanticLabel:\s*'|label:\s*'|tooltip:\s*'|hintText:\s*'|fallback:\s*'" \
    <les 17 fichiers du périmètre>
```
Résultat sur les fichiers **neufs** (SUF-1 ui_kit ×7, SUF-2 ×1, SUF-3 ×5) :
**aucune** occurrence en code — la seule ligne remontée est
`z_folder_card.dart:73`, un **exemple de dartdoc** (`counts: const Text('42 cartes')`).
Toutes les autres occurrences sont dans `zcrud_session` et **pré-existent au diff
SUF-4** (voir §2.3 et §3).

### 1.3 Défauts des 5 nouveaux paramètres — rendu historique préservé

| Paramètre | Défaut | Preuve que le rendu historique est intact |
|---|---|---|
| `ZAppBarSearchConfig.hintLabel` | `null` | `z_page_shell.dart:142` — `search.hintLabel ?? _resolveSearchLabel(context)` ; le repli est la chaîne `ZcrudScope.labels['search'] → ZcrudLocalizations['search'] → MaterialLocalizations.searchFieldLabel` (`z_page_shell.dart:98-101`). Clés `'search'`/`'close'` **présentes** dans les tables `en`/`fr` du cœur : `z_localizations.dart:35,54` (en) et `:126,145` (fr). Widget neuf ⇒ aucune régression possible. |
| `ZFolderCard.archivedLabel` | `null` | `z_folder_card.dart:162` — `showArchived = isArchived && archivedLabel != null` ; le badge n'est construit qu'en `:172-178`. Absence **structurelle**, pas de badge muet, pas de littéral « Archivé ». |
| `ZSessionProgressIndicator.linearThickness` | `null` | `z_session_progress_indicator.dart:170-176` — `resolvedLinearThickness()` retombe sur `theme.gapS` (= `4`, `z_theme.dart:32`) et **jamais** sur le `6` de lex. Style `linear` = **valeur d'enum neuve** (`:52`) ⇒ aucun appelant historique. `dots`/`segmentedBar` intouchés (`git diff` : le corps de `_dots`/`_bar` n'est pas modifié). |
| `ZSrsQualityButtons.emphasis` | `ZSrsQualityEmphasis.none` | `opacityFor()` renvoie `null` (`:156-158`) ⇒ `color: pair.color` **tel quel** (`:386-388`, aucun `withValues`). `borderWidthFor()` renvoie `0` ⇒ `side: BorderSide.none` (`:394-396`). Le passage `borderRadius:` → `shape:` est **byte-équivalent** : `flutter/packages/flutter/lib/src/material/material.dart:498-499` construit exactement `RoundedRectangleBorder(borderRadius: widget.borderRadius!)`, dont `side` vaut `BorderSide.none` par défaut. |
| `ZSessionQualityBreakdown.coverage` | `presentKeysOnly` | `z_session_quality_breakdown.dart:114` — `if (wholeScale \|\| byQuality.containsKey('$quality'))` : sous le défaut, la garde est identique à l'historique. Le `count: byQuality['$quality'] ?? 0` (`:121`) ne peut pas dériver : `byQuality` est un `Map<String, int>` (`:70`), valeurs **non-nullables**, donc sous `presentKeysOnly` le `?? 0` n'est jamais atteint. Pass-through `ZSessionSummaryView.breakdownCoverage` avec le **même** défaut (`z_session_summary_view.dart:160`). |

`ZSrsQualityEmphasis` et `ZQualityBreakdownCoverage` ne portent **aucune couleur** —
uniquement des dimensions (opacité, épaisseur) et un choix nommé. Les deux sont
publiquement atteignables (exports pleins-fichiers `zcrud_session.dart:100,101,113`).

### 1.4 Directionnalité (contrôle collatéral)

```
$ grep -rnE "EdgeInsets\.only\((left|right)|Alignment\.(centerLeft|centerRight|topLeft|topRight|bottomLeft|bottomRight)|TextAlign\.(left|right)|Positioned\((left|right)" \
    packages/zcrud_ui_kit/lib packages/zcrud_study/lib packages/zcrud_session/lib
```
→ 4 hits, **tous des commentaires** (`z_session_progress_indicator.dart:284,464`,
`z_session_mode_selector.dart:128,302`). Aucun usage non directionnel.

---

## 2. Findings

### F1 — MEDIUM — `centerTitle: false` en dur : l'app-bar du shell ignore `AppBarTheme` et la plateforme

**Fichiers** : `packages/zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart:99`
et `packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:164`.

```
$ grep -rn "centerTitle" packages/zcrud_ui_kit/lib/
packages/zcrud_ui_kit/lib/src/presentation/z_page_scaffold.dart:164:        centerTitle: false,
packages/zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart:99:          centerTitle: false,
```

`AppBar.centerTitle` est **nullable par conception** précisément pour laisser le
thème et la plateforme décider :

```
$ grep -n "_getEffectiveCenterTitle" -A 12 /home/zakarius/flutter/packages/flutter/lib/src/material/app_bar.dart
805:  bool _getEffectiveCenterTitle(ThemeData theme, AppBarThemeData appbarTheme) {
806-    bool platformCenter() {
807-      return switch (theme.platform) {
808-        TargetPlatform.iOS || TargetPlatform.macOS => actions == null || actions!.length < 2,
…
816-    return centerTitle ?? appbarTheme.centerTitle ?? platformCenter();
```

En passant `false` **en dur**, `ZSearchableAppBar`/`ZPageScaffold` court-circuitent
`AppBarThemeData.centerTitle` **et** le défaut iOS/macOS. Une app qui injecte
`ThemeData(appBarTheme: AppBarThemeData(centerTitle: true))` — soit la voie
d'injection de thème normale, FR-26 — n'a **aucun moyen** d'obtenir un titre
centré : le paramètre n'est pas exposé par le shell (grep négatif ci-dessous).

```
$ grep -rn "this.centerTitle\|centerTitle:" packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart
RC=1   (aucune sortie — le shell n'expose aucun paramètre centerTitle)
```

Nuance de traçabilité : la story SUF-1 sanctionne cette valeur
(`suf-1-page-shell-searchable-appbar.md:162`, « Garder l'idée : … `centerTitle:false` »),
mais elle la décrit comme un **défaut** de parité lex, pas comme une valeur
inatteignable. C'est bien un choix de **thème figé dans le package**.

**Correction suggérée (hors périmètre de cette revue)** : exposer
`final bool? centerTitle` (défaut `false` pour conserver la parité lex à
l'identique) et le passer tel quel à `AppBar`/`SliverAppBar` — ou passer `null`
et laisser le thème arbitrer.

---

### F2 — MEDIUM — `ZSessionCardSwiper` ne propage PAS `linearThickness` : le nouveau style `linear` reste figé à `gapS` pour ses appelants

**Fichier** : `packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart:460-466`.

```
$ grep -n "ZSessionProgressIndicator" -A 7 packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart
460:            child: ZSessionProgressIndicator(
461-              total: widget.queue.length,
462-              currentIndex: _index,
463-              passThreshold: widget.passThreshold,
464-              style: widget.progressStyle,
465-              qualityOf: widget.qualityOf,
466-            ),
```

Le swiper **expose** `progressStyle` (`:153,178`) — donc un appelant peut
sélectionner `ZSessionProgressStyle.linear` — mais il ne transmet **ni**
`linearThickness`, **ni** `labelKeyFor`, **ni** `colorKeyFor`. Grep négatif :

```
$ grep -rn "linearThickness" packages/zcrud_session/lib/src/presentation/z_session_card_swiper.dart
RC=1   (aucune sortie)
```

Conséquence exacte : une app qui monte `ZSessionCardSwiper` (le chemin naturel
d'une session de cartes) et choisit `linear` obtient une barre de
`ZcrudTheme.gapS` = **4 dp** (`z_theme.dart:32`) et **ne peut pas** atteindre les
6 dp de son design — ce qui est précisément l'écart de parité que SUF-4 déclare
fermer, et précisément le raisonnement que SUF-4 applique correctement à
`ZSessionSummaryView.breakdownCoverage` :

> « Sans ce pass-through, une app montant CE widget ne pourrait pas atteindre la
> répartition à longueur stable du natif lex : le breakdown est construit ici,
> pas par l'appelant. » (`z_session_summary_view.dart:198-201`)

Le même argument s'applique mot pour mot à l'épaisseur `linear` construite par le
swiper. Asymétrie de traitement entre les deux paires, pas défaut de conception
du seam lui-même.

**Correction suggérée** : ajouter `final double? linearThickness` à
`ZSessionCardSwiper` (défaut `null` ⇒ rendu inchangé) et le passer en `:460-466`.

---

### F3 — MEDIUM — chaîne FRANÇAISE en dur dans un `Semantics.label` (pré-existante, fichier du diff SUF-4)

**Fichier** : `packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart:209`.

```dart
label: unknown ? 'hors échelle: $labelText' : labelText,
```

```
$ grep -rn "hors échelle" packages/*/lib/ | grep -v "^.*:[0-9]*:///\|^.*:[0-9]*://"
packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart:209:      label: unknown ? 'hors échelle: $labelText' : labelText,
```
(les autres hits du grep brut sont tous des lignes `///` ou `//`.)

Contrairement à tous les autres libellés du fichier — qui passent par
`label(context, <clé>, fallback: …)` (`:119,138`) et sont donc **surchargeables**
par `ZcrudScope.labels` ou le delegate — celui-ci est un **littéral direct** :
aucune clé, aucun point d'injection. Un lecteur d'écran en locale `en` annonce
« hors échelle: 9 ». C'est exactement la dette soldée ailleurs dans le même package
(`z_srs_quality_buttons.dart:330-340`, « les libellés `'ok'`/`'lapse'` étaient
codés en dur dans `Semantics.value` … AD-13 exige l'inverse : c'est précisément le
canal non-visuel qui doit être lisible »).

**Antériorité prouvée** (ce n'est PAS une régression SUF-4) :
```
$ git show HEAD:packages/zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart | grep -n "hors échelle"
172:      label: unknown ? 'hors échelle: $labelText' : labelText,
RC=0
```

Je le remonte parce que (a) le fichier fait partie du diff de l'epic, (b) la
lentille demande explicitement de vérifier « qu'aucune chaîne visible n'est écrite
en français/anglais en dur dans `lib/` », (c) le coût de correction est d'une
ligne (`label(context, 'zcrud.srs.quality.outOfScale', fallback: …)`).

Note connexe, **non retenue comme finding** : les `fallback: 'ok'` / `'lapse'` /
`'sélectionné'` (`z_srs_quality_buttons.dart:361,362,367`), `'Session terminée'`,
`'Bravo'`, `'Cartes'`, `'Maîtrisées'`, `'Durée'`, `'Encore {n} dues'`, `'Terminer'`
(`z_session_summary_view.dart:397-552`) et `'carte suivante'`
(`z_session_card_swiper.dart:471`) sont eux aussi des chaînes littérales en
français/anglais, **mais** elles transitent par `label(context, key, fallback:)` :
`z_localizations.dart:294-302` les place en **dernier recours après** le scope, la
locale et la table `en` — l'app dispose donc d'un point d'injection par clé. Toutes
pré-existent au diff SUF-4 (vérifié via `git show HEAD:…`).

---

### F4 — MEDIUM — replis de libellé a11y sémantiquement FAUX dans la nav de sous-dossiers (SUF-3)

**Fichiers** : `packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:160-162, 248, 414`
et `packages/zcrud_study/lib/src/presentation/z_subfolder_compact_selector.dart:99`.

```dart
// z_subfolder_sidebar.dart:160-162  (bouton replier/déployer)
final label = collapsed
    ? (spec.expandLabel   ?? spec.allSubfoldersLabel)
    : (spec.collapseLabel ?? spec.allSubfoldersLabel);

// z_subfolder_sidebar.dart:248  et  z_subfolder_compact_selector.dart:99  (bouton Ajouter)
final label = spec.addLabel ?? spec.allSubfoldersLabel;

// z_subfolder_sidebar.dart:414  (poignée de réordonnancement)
label: spec.reorderHandleLabel ?? spec.allSubfoldersLabel,
```

Ces labels alimentent à la fois `IconButton.tooltip` et `Icon.semanticLabel`
(`:170-177`, `:256-261`, `compact:107-112`) et `Semantics(label:)` (`:448-450`).

La règle « jamais de libellé en dur » est bien respectée — mais le repli choisi
**ment sur la fonction du contrôle** : `allSubfoldersLabel` est le libellé de
l'item racine (« Tous les sous-dossiers »). Un utilisateur de lecteur d'écran, sur
une app qui n'a pas renseigné `addLabel`, entend « bouton, Tous les sous-dossiers »
sur le **bouton Ajouter**, sur la **poignée de drag** et sur le **bouton de
repli** — trois contrôles de fonctions différentes annoncés à l'identique, et
à l'identique de l'item de navigation racine. Un label faux est plus nuisible
qu'un label générique : il oriente vers la mauvaise action.

La dartdoc du spec assume ce choix (`z_subfolder_nav_spec.dart:75-76,89-91,100-101`,
« dernier recours pour ne jamais rendre un contrôle sans annonce »), donc c'est un
**arbitrage explicite** — mais l'alternative correcte existe déjà dans le cœur et
n'a pas été utilisée : les clés génériques `'add'` (`z_localizations.dart:31`),
`'close'` (`:54`), `'moveItemUp'`/`'moveItemDown'` (`:81-82`) sont livrées en `en`
**et** `fr`, et `label(context, key)` ne throw jamais.

**Correction suggérée** : remplacer le repli `?? spec.allSubfoldersLabel` par
`?? label(context, 'add')` / `'close'` / `'moveItemDown'` selon le contrôle.

---

### F5 — LOW — dimensions littérales là où un token de thème existe (contredit la dartdoc du fichier)

```
$ grep -rnE "SizedBox\((width|height): [0-9]|EdgeInsets(Directional)?\.(all|symmetric|only)\([^)]*[0-9]" \
    <fichiers SUF-1/2/3>
packages/zcrud_study/lib/src/presentation/z_folder_card.dart:308:      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 2),
packages/zcrud_ui_kit/lib/src/presentation/z_page_shell.dart:200:                  const SizedBox(width: 12),
packages/zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:420:      margin: EdgeInsetsDirectional.symmetric(vertical: theme.gapS / 2),   ← OK (dérivé du token)
```

* `z_folder_card.dart:308` (`_ArchivedBadge`) : padding `8`/`2` en dur, alors que
  la dartdoc du **même fichier** promet, `:42-44` :
  « rayon et gaps depuis `ZcrudTheme.of(context)`, typo depuis `Theme.of(context)`
  — **aucun littéral** ». Le widget lit pourtant déjà `ZcrudTheme.of(context)`
  ligne `305` (pour `radiusM`) : `theme.gapM` (= 8) et `theme.gapS / 2` (= 2)
  reproduiraient **exactement** les valeurs actuelles sous le thème par défaut
  (`z_theme.dart:32-34`), donc la correction est neutre au pixel près sous
  `ZcrudTheme()` par défaut — mais elle rendrait le badge sensible au thème injecté,
  ce qu'il n'est pas aujourd'hui (idem golden `z_folder_card_neutral.png` : inchangé
  sous thème par défaut).
* `z_page_shell.dart:200` : `const SizedBox(width: 12)` entre l'icône et le texte
  d'une entrée de menu de débordement — valeur entre `gapM` (8) et `gapL` (16),
  ne correspondant à aucun token ; `ZcrudTheme` n'est lu **nulle part** dans
  `z_page_shell.dart` (`grep -n "ZcrudTheme" z_page_shell.dart` → RC=1).
* `z_subfolder_sidebar.dart:507` : `style: TextStyle(color: scheme.onSecondaryContainer)`
  — `TextStyle` **nu** (couleur seule) là où le reste du fichier dérive de
  `Theme.of(context).textTheme` (`:399`). La taille/graisse retombent sur le
  `DefaultTextStyle` ambiant, hors échelle typographique explicite.

Les constantes nommées `_kPastilleSize` (`z_folder_card.dart:65`, `z_subfolder_sidebar.dart:43`),
`_kHeaderAccentSize` (`z_study_folder_detail.dart:56`), `_kMinTapTarget`,
`_kResizeHitWidth`, `_kResizeLineWidth` sont, elles, **acceptables** : ce sont des
dimensions de layout documentées et nommées (pas des couleurs, pas des libellés),
et `kZFolderCardTintAlpha` est même exposée publiquement pour rester ajustable.

---

## 3. Points contrôlés SANS finding

| Contrôle | Résultat |
|---|---|
| Couleur codée en dur dans un package | Aucun (§1.1) |
| Libellé utilisateur en dur dans les fichiers neufs SUF-1/2/3 | Aucun (§1.2) |
| Défauts des 5 nouveaux params ⇒ rendu historique | Préservé, prouvé (§1.3) |
| `borderRadius:` → `shape:` (SUF-4) équivalent au rendu antérieur | Oui — `material.dart:498-499` |
| `linear` ajouté à `ZSessionProgressStyle` casse un `switch` exhaustif ailleurs | Non — seul autre usage : `z_session_card_swiper.dart:153,178` (champ, pas `switch`) |
| Nouveaux types publics atteignables (sinon « non injectable ») | Oui — `zcrud_session.dart:100,101,113` (exports pleins fichiers) ; `zcrud_ui_kit.dart` exporte les 4 domaines + `z_page_shell.dart` ; `zcrud_study.dart` exporte `z_folder_card`, `z_study_folder_detail` (show), `z_subfolder_*` |
| Clés l10n `'search'`/`'close'` réellement livrées en/fr | Oui — `z_localizations.dart:35,54,126,145` |
| Chaîne de résolution des labels SUF-1 | `ZcrudScope.labels → ZcrudLocalizations → MaterialLocalizations` (`z_page_shell.dart:98-107`), jamais de throw sur clé absente |
| Variantes directionnelles (RTL) | Aucun `left`/`right` en code (§1.4) |
| `PopupMenuButton` de débordement sans tooltip injecté | Non-finding : le défaut Flutter est `MaterialLocalizations.showMenuTooltip`, donc localisé |

---

## 4. Récapitulatif

| # | Sévérité | Fichier:ligne | Résumé |
|---|---|---|---|
| F1 | MEDIUM | `zcrud_ui_kit/lib/src/presentation/z_searchable_app_bar.dart:99` + `z_page_scaffold.dart:164` | `centerTitle: false` en dur ⇒ `AppBarThemeData.centerTitle` injecté et défaut iOS/macOS inatteignables |
| F2 | MEDIUM | `zcrud_session/lib/src/presentation/z_session_card_swiper.dart:460` | `linearThickness` non propagé : le style `linear` de SUF-4 reste figé à `gapS` pour les appelants du swiper |
| F3 | MEDIUM | `zcrud_session/lib/src/presentation/z_session_quality_breakdown.dart:209` | `'hors échelle: '` — chaîne française en dur dans un `Semantics.label`, sans clé ni point d'injection (pré-existante) |
| F4 | MEDIUM | `zcrud_study/lib/src/presentation/z_subfolder_sidebar.dart:161,248,414` + `z_subfolder_compact_selector.dart:99` | Repli a11y `?? allSubfoldersLabel` : Ajouter / poignée / repli annoncés « Tous les sous-dossiers » |
| F5 | LOW | `zcrud_study/…/z_folder_card.dart:308`, `zcrud_ui_kit/…/z_page_shell.dart:200`, `z_subfolder_sidebar.dart:507` | Dimensions littérales / `TextStyle` nu là où un token existe — contredit la dartdoc de `z_folder_card.dart:42-44` |

Aucun finding HIGH. Aucun finding bloquant pour la lentille l10n/thème :
les seams sont en place et les défauts sont neutres ; ce qui manque, ce sont
**deux points d'injection** (F1, F2) et **deux libellés** (F3, F4).
