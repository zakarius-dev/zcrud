# Code-review su-8 — liste, filtres, ordre manuel, duplication

Story : `su-8-liste-filtres-ordre-manuel.md` (22 ACs) · Spine : AD-38 · AD-45 · AD-46 · AD-10 · AD-13.
Statut : `review`. Ce document consigne l'application des findings arbitrés (D1..D7 + R3 + LOW).

## Verdict

**Tous les findings bloquants (HIGH/MAJEUR) et MEDIUM arbitrés sont CORRIGÉS.** Vérif verte
rejouée réellement : `melos run analyze` **RC=0**, `melos run verify` **RC=0** (54 arêtes,
ACYCLIQUE, CORE OUT=0), tests par package verts. Chaque finding de niveau R3 a été **prouvé
falsifiable par le comportement** (injection → RED, restauration sha256 OK, sans `git checkout`).

Compteurs après correction (référence orchestrateur entre parenthèses) :
zcrud_flashcard **541** (536, +5) · zcrud_study **342** (334, +8) · zcrud_responsive **107** (107) ·
zcrud_session **521** (521) · zcrud_study_kernel **361** (361). Aucune régression cross-package.

---

## D1 — HIGH — Réordonner sous filtre détruisait l'ordre des cartes non visibles — **CORRIGÉ**

**Fichier** : `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart`
(`_canReorder`/`_buildList`/`_reorder`) + `z_flashcard_reorder.dart:99-104`.

**Scénario** : 200 cartes classées, recherche « ZEBRE » (2 visibles), un « Descendre » ⇒
`zReorderFlashcards` remplaçait la section entière par les 2 `visibleIds`, effaçant 198 positions
en base. `applyOrder` étant TOTAL, aucune exception, aucun test rouge.

**Voie retenue : (a) interdire le réordonnancement sous filtre de CONTENU** (la plus conservatrice,
alignée AD-44 : absent, jamais grisé). Justification du choix vs (b) merge préservant :
- (b) exigerait de recalculer l'univers COMPLET ordonné puis de réinsérer les visibles à leurs
  emplacements — délicat, et la sémantique « déplacer une carte sous filtre » est ambiguë ;
- au niveau élément la vue n'a pas d'accès trivial à un « ordre complet » fiable (l'ordre persisté
  peut être périmé) ; (a) est correcte, sûre par construction, et déjà le patron du fichier.

**Détection précise du danger** (`_contentFilterActive`) : recherche débouncée non vide **OU**
`filters.sources` non vide **OU** `selector.config.tagIds` non vide **OU** `selector.config.types`
non vide. Le **sous-dossier n'en est PAS** : il **scope la clé** (`flashcards/<sub>`), donc
réordonner un sous-dossier n'écrase jamais l'ordre d'un autre (spread des autres sections) — c'est
sûr, et **reste autorisé**. `reorderable = _canReorder && !_contentFilterActive(query)` est fileté
au drag, aux boutons a11y (`_moveCallback`) et au choix grille/liste.

**Tests porteurs ajoutés** (`z_flashcard_list_view_test.dart`, groupe « D1 (HIGH) ») :
recherche active ⇒ drag ET boutons ABSENTS, `onOrderChanged` jamais appelé ; **filtre de tags**
actif ⇒ idem (sans que l'utilisateur tape) ; **sous-dossier** ⇒ réordonnancement AUTORISÉ **et**
l'ordre de la section racine (cartes non visibles) est PRÉSERVÉ. Le test pure-function
`z_flashcard_reorder_test.dart` « l'ordre se répare » a été **reframé** : la purge des orphelins
n'est correcte que parce que `visibleIds` est COMPLET, garantie EN AMONT par la vue.

**Preuve de falsifiabilité** : neutraliser le garde (`reorderable = _canReorder`) ⇒ les tests
« recherche active » **et** « tags actif » passent **RED** ; le test « sous-dossier » reste vert
(comportement attendu). Restauration sha256 OK.

## D2 — MAJEUR — `type.name` / `source.kind` rendus verbatim — **CORRIGÉ**

`z_flashcard_list_view.dart` `_TypeBadge` (`type.name`) et le `Text(card.source!.kind)` servaient
`'openQuestion'`/`'pdf'` bruts (1er mot annoncé sur chaque carte). Ajout de deux slots d'injection
`typeLabels`/`sourceLabels` (`Map<String,String>?`), patron `tagLabels` : `typeLabels?[type.name]
?? type.name`, `sourceLabels?[kind] ?? kind`. **Test porteur** (groupe « D2/AC20 ») : injection ⇒
libellés localisés rendus, clés brutes `openQuestion`/`pdf` **absentes** ; sans injection ⇒ repli
sur la clé (identique au repli tags).

## D3 — MAJEUR — `_SearchField` : `Semantics(label:)` fantôme — **CORRIGÉ**

Le `Semantics(textField:, label:)` parent créait un nœud `isTextField` fantôme (non focusable,
sans action) ; le vrai champ n'annonçait que le hint. Remplacé par
`InputDecoration(labelText: labels.searchFieldLabel)` : le SDK attache le libellé **au nœud du
champ** (`EditableText`). Prouvé par sonde : nœud du champ = `label:"Champ de recherche"`, flags
`isTextField, isFocusable`. **Gardes corrigées** (a11y + list_view) : elles s'ancrent désormais sur
`getSemantics(find.byType(EditableText))` avec `containsSemantics(label:…, isTextField:true,
isFocusable:true)` — plus jamais vertes sur un fantôme (l'ancien `bySemanticsLabel` matchait le
fantôme).

## D4 — MEDIUM — Contre-preuve de virtualisation infalsifiable — **CORRIGÉ**

`z_adaptive_grid_test.dart` : l'ancien `expect(builtEagerly, 1000)` comptait `List.generate` (le
SDK), vrai avant même `pumpWidget`. **Fait mesuré (sonde jetable)** : les DEUX ctors s'appuient sur
`GridView.builder` et **cullent le viewport** ⇒ ils montent le MÊME petit nombre de tuiles
(**≈12/1000**), il n'y a **PAS** de différentiel « 1000 vs 10 » monté (la suggestion de la lentille
était imprécise sur ce point). Réécriture qui mesure le WIDGET : `.builder` **appelle** son
`itemBuilder` `< 200` fois (propriété du widget, non de `List.generate`), et chaque ctor **rend**
son viewport (`find.byKey('cell-0')` findsOneWidget). **Preuve** : mutiler le ctor `children:`
(→ `SizedBox.shrink()`) fait désormais **RED** la contre-preuve (elle dépend du ctor), là où
l'ancien `builtEagerly` restait vert. Restauration sha256 OK.

## D5 — MEDIUM — `filters.query` gelée au montage — **CORRIGÉ**

**Voie retenue : rendre la prop VIVANTE via `didUpdateWidget`** (plutôt que renommer `query` en
`initialQuery`). Justification : `query` est un champ de `ZFlashcardBrowseFilters` **réellement
vivant** pour `zApplyBrowseFilters` (le needle de recherche) — le renommer sur le value object
serait faux ; l'asymétrie était strictement dans la VUE (`searchFields`/`sources` vivants, `query`
lu seulement en `initState`). `didUpdateWidget` resynchronise `_searchController.text` **et**
`_query.value` **uniquement** sur changement RÉEL de la prop (`widget.filters.query !=
oldWidget.filters.query && != _searchController.text`), ce qui empêche d'écraser la saisie en cours
(AD-2). **Tests** : parent pousse `query` ⇒ appliquée + champ mis à jour ; rebuild avec la même
prop ⇒ la saisie utilisateur en cours n'est PAS écrasée. (Le débounce armé par la resync est drainé
en test — aucun Timer pendant.)

## D6 — MEDIUM — `extra` copié en surface — **CORRIGÉ**

`z_flashcard_duplicate.dart:83` : `Map.of(card.extra)` (surface) ⇒ sous-structure imbriquée
`identical` entre original et copie ⇒ éditer la copie mutait la carte partagée (AD-45). Remplacé
par une copie **profonde** (`_deepCopyJson` récursif sur `Map`/`List`, scalaires immuables
partagés), symétrique du clonage de `choices`. **Test porteur** (fixture NON scalaire :
`extra: {'nested': [...], 'meta': {...}}`) : `identical` false sur liste ET map imbriquées, et
muter la copie ne touche pas l'original.

## D7 — MEDIUM — Strip U+0300–U+036F inconditionnel sur table latine — **CORRIGÉ**

**Voie retenue : borner le strip au latin** (plutôt que seulement corriger la dartdoc).
`z_flashcard_search_text.dart` : une marque combinante n'est retirée que si sa **base est latine**
(`< U+0250`, fin de Latin Extended-B) ou **orpheline** ; une base non-latine la CONSERVE. Justif :
cette variante corrige réellement la confusion `й`(NFD)→`и` (deux lettres russes distinctes)
**sans** régression — İ turc (strip en amont de la casse, base latine), latin NFD, et le contrat
« combinant orphelin ⇒ '' » sont tous préservés (13/13 tests search-text verts, dont le nouveau
groupe D7). **Preuve** : neutraliser le strip (`_kCombiningStart=0xFFFE`) ⇒ les tests NFD réels
RED. Le fond « parité NFC/NFD hors-latin » reste une limite documentée (epic ME possède la table) —
non une régression de su-8.

## R3 — Lentille tests-porteurs (2 MAJEUR) — **CORRIGÉS**

**F1 — corpus NFD infalsifiable (motif ②).** `z_flashcard_browse_filters_test.dart:413` et
`z_flashcard_list_view_sm1_test.dart:254` étiquetaient « nfd » une carte dont les octets étaient
**précomposés NFC** (`c3 89`/`c3 a8`, vérifié hexdump) ⇒ vertes même le strip supprimé. Corrigé :
littéraux remplacés par du **vrai NFD explicite** (`'Élève…'`) + **sonde d'auto-défense**
(`runes.any((r)=>r>=0x300&&r<=0x36F)`) qui rougit si un `dart format`/éditeur re-précompose le
fichier. **Preuve** : strip neutralisé ⇒ les DEUX tests passent RED (avant : verts).

**F2 — le drag n'était actionné par aucun test.** Aucun test ne pilotait le callback SDK du
`ReorderableListView` ⇒ des indices inversés restaient 334/334 verts. Ajout d'un test widget
(groupe « F2/AC11 ») qui **actionne** `rlv.onReorderItem!(0, 2)` et assère l'ordre notifié contre un
**littéral** `['b','c','a']` (jamais comparé à `zReorderFlashcards` ⇒ pas de tautologie). **Preuve** :
injecter le swap d'indices (`_reorder(visible, newIndex, oldIndex)`) ⇒ test RED. Restauration
sha256 OK.

## LOW — dispositions

- **Ligature `ﬁ`/`ﬂ` et sigma final grec `ς/σ`** : bloqués par l'interdit d'écriture dans
  `zcrud_core` (table dans `z_search_text.dart`, réservée epic ME) ⇒ **CONSIGNÉS au ledger**, non
  corrigés (évolution additive naturelle `'ﬁ':'fi'`, `'ς':'σ'`).
- **`isFiltered` — logique morte** (`_buildList`) : le 3ᵉ terme `widget.cards.isNotEmpty` absorbait
  les deux autres. Corrigé au passage (trivial) : réduit à `widget.cards.isNotEmpty ? noResults :
  emptyState`.
- **Foin renormalisé sans mémoïsation** (`z_flashcard_filters.dart`) : la lentille a **réfuté** le
  micro-correctif (hisser la `RegExp` ne gagne rien, mesuré) ; le débounce absorbe le coût.
  **CONSIGNÉ** (index normalisé par carte à porter par la story des gros volumes, v1.x).
- **Test reorder « l'ordre se répare » (:385-403)** : reframé (traité en D1).

## MEDIUM/MAJEUR NON arbitrés dans D1..D7+R3 (signalés par des lentilles, hors périmètre appliqué)

Non corrigés car **hors** de la liste arbitrée par l'orchestrateur (consignés pour décision) :
`sortLabel` champ mort `required` (3 lentilles) ; drag + `id==null` (référentiels d'index
divergents) ; dartdoc `container:true` « fusionne » (fausse, mais comportement final correct) ; tri
`title` normalisant dans le comparateur ; `fontSize:11` ×3 en dur ; garde hardcode ligne-à-ligne
plus faible que sa jumelle. **À trancher par l'orchestrateur** (plusieurs sont des MEDIUM légitimes).

## Findings résiduels (post-arbitrage) — R1..R4

Passe de reprise sur les findings laissés hors de la liste D1..D7+R3 et signalés à
l'orchestrateur. Fichiers touchés : `z_flashcard_list_view.dart`,
`z_widgets_hardcode_scan_test.dart`, `z_flashcard_list_view_test.dart`, +
4 fixtures de test (retrait `sortLabel`). Aucune écriture dans `zcrud_core`.

### R1 — MEDIUM — `sortLabel` `required` jamais lu — **CORRIGÉ (supprimé)**

`ZFlashcardListLabels.sortLabel` était un paramètre **`required`** avec **2 seules
occurrences, toutes deux des déclarations** (ctor + champ). **Intention de l'AC
mesurée** : la vue reçoit `sortMode` en **prop** (le parent pilote le tri) et **ne
rend AUCUN sélecteur de tri** (grep `DropdownButton|SegmentedButton|onSortChanged`
⇒ néant ; AC8 définit l'enum, jamais un contrôle dans cette vue). Le libellé a11y
d'un sélecteur inexistant était donc **mort**, tout en **forçant chaque appelant**
à fournir une valeur inutilisée. **Voie retenue : suppression** (le rendre vivant
inventerait un contrôle hors AC). Retiré du ctor + du champ + des **4 fixtures**
(`a11y`, `list_view`, `contrast`, `sm1`). **Preuve** : `grep -rn sortLabel
--include='*.dart'` repo-wide ⇒ **NONE** ; compilation des appelants **verte**
(zcrud_study 346 RC=0).

### R2 — MEDIUM — `fontSize: 11` en dur (×3) invisible à la garde — **CORRIGÉ**

`z_flashcard_list_view.dart:886/932/959` : `TextStyle(color: foreground,
fontSize: 11)` — taille **codée en dur** ⇒ ignore la mise à l'échelle du texte
(a11y) et casse le thème (FR-26/AD-13). Les **3 sites** (source, `_TypeBadge`,
`_Tags`) remplacés par `(Theme.of(context).textTheme.labelSmall ?? const
TextStyle()).copyWith(color: foreground)` — la taille vient du thème et scale, la
couleur `foreground` reste apposée (aucun token `ZcrudTheme` de caption n'existe :
`z_theme.dart` n'expose que `labelTextStyle`/spacing/couleurs, pas de variante
« small » — repli documenté sur `textTheme`). **Garde ÉTENDUE (pas parallèle)** :
`z_widgets_hardcode_scan_test.dart` (la garde ligne-à-ligne existante, jusque-là
aveugle au `fontSize:`) reçoit une règle regex `fontSize:\s*[0-9]` + un scanner
`scanForHardcodedStyle` + un test réel-fichiers + une contre-preuve (un
`fontSize: theme.x` **variable** n'est PAS un faux positif). **Preuve par
mutation** : fichier `_mutant_r2_probe.dart` (throwaway) avec `TextStyle(fontSize:
11)` déposé dans `lib/src/presentation/` ⇒ le test « R2 — ZÉRO dimension
typographique en dur » passe **RED** (`fontSize: littéral en dur`) ; mutant
supprimé, vert restauré. `grep -rn fontSize` du fichier ⇒ 3 occurrences, toutes
en **commentaire**.

### R3 — À INSTRUIRE — drag + carte `id == null` — **CORRIGÉ (garde défensif)**

**Scénario MESURÉ** (probe throwaway jeté) : liste manuelle `[a, éphémère(id=null),
b]`, `order={flashcards:[a,b]}`, `onReorderItem(2, 0)` (drag de l'éphémère vers le
haut) ⇒ ordre notifié **`[b, a]`** : c'est une **AUTRE carte (b)** qui bouge, pas
l'éphémère glissée. Cause : `_reorder` écarte les cartes sans id de `visibleIds`
(`if (card.id != null)`), donc l'**espace d'indices** de `visible` (qui contient
l'éphémère) **diverge** de celui de `visibleIds` ⇒ `zReorderIds` clampe et déplace
le mauvais élément **en silence**. Défaut **réel et user-visible SI atteignable**.
**Réachabilité tranchée** : en su-8 la duplication (`zDuplicateFlashcardForEditing`,
`id: null`) **sort par `onDuplicate`** et n'entre **jamais** dans `widget.cards`
(persistance = **me-2**, hors périmètre). Une carte éphémère dans une liste
manuelle réordonnable **n'est donc pas un état su-8**. **Disposition** : plutôt que
justifier seul, **garde défensif AD-10/AD-2** aligné D1 — `reorderable = _canReorder
&& !_contentFilterActive(query) && !visible.any((c) => c.id == null)` : dès qu'une
carte sans id est visible, drag **ET** boutons **ABSENTS** (jamais grisés, jamais
« mauvaise carte silencieuse »). Coût nul, **zéro régression** (aucun test nominal
n'a de carte éphémère). **Tests porteurs** (groupe « R3 ») : éphémère présente ⇒
`ReorderableListView` absent + « Monter »/« Descendre » absents + `onOrderChanged`
jamais appelé ; **contrôle** sans éphémère ⇒ `ReorderableListView` présent
(falsifiable : neutraliser le garde ⇒ 1ᵉʳ test RED, contrôle vert).

### R4 — LOW — instruction — **VÉRIFIÉS CORRECTS (aucun changement)**

- **dartdoc `container: true` « fusionne »** : **MESURÉ** (probe throwaux jeté).
  `Semantics(container: true)` **SANS** label propre ⇒ nœud de label
  `"QUESTION\nBADGE"` (les labels des descendants **SONT fusionnés** dans le nœud
  container) ; **AVEC** `label: 'QUESTION'` ⇒ `"QUESTION\nQUESTION\nBADGE"` (la
  question annoncée **DEUX FOIS**). La prose on-disk (`z_flashcard_list_view.dart`
  ~817-823) est donc **VRAIE** — pas une 7ᵉ occurrence « prose vs code ». **Aucune
  correction** (un « fix » l'aurait faussée).
- **Comparateur de tri `title`** : `zSortFlashcards` (mode `title`) trie sur
  `zFlashcardSearchText(question)` (normalisé accents/casse). La dartdoc de l'enum
  annonce « Par **énoncé**, ordre alphabétique normalisé » — le comparateur trie
  **bien** par l'énoncé (question) normalisé, exactement ce qu'il prétend. **Correct,
  aucun changement.**

### Vérif verte R1..R4 (rejouée réellement)

- `dart run melos run analyze` → **RC=0** (32 `info` de dépréciation `hasFlag`/
  `containsSemantics` PRÉ-EXISTANTS, non touchés).
- `dart run melos run verify` → **RC=0** — 10 gates ; graphe **54 arêtes,
  ACYCLIQUE, CORE OUT=0**.
- `flutter test` par package : zcrud_study **346** (342 réf + 4 : R2 réel + R2
  contre-preuve + 2 R3) ; zcrud_flashcard **541** (réf). Aucune régression
  cross-package. Mutation R2 (RED puis restauré) + falsifiabilité R3 prouvées.

## Points CONFIRMÉS — portés au crédit (non « corrigés »)

- **Clé AD-38 irréprochable** : rétro-compat deux sens relue par la clé LITTÉRALE (non
  tautologique), `applyOrder` réellement appliqué, garde de composition unique couvrant
  `zcrud_study/lib`. Le HIGH D1 n'était pas une faute de clé mais le merge manquant.
- **SM-1 / virtualisation TENUES et prouvées** : 100 caractères ⇒ 0 rebuild de liste, focus
  conservé, controller `identical` ; `.builder` cull réellement (≈12/1000). Le test SM-1 phare est
  falsifiable (injection débounce ⇒ RED).
- **Duplication 17/17 champs** ; Fisher-Yates porteur ; `choices` profond ; `source`/`extension`
  corrects ; SRS et ordre non joignables (prouvé). Seul `extra` manquait (D6).
- **Filtres délégués au kernel** (aucune 2ᵉ implémentation) ; table Unicode unique ; ordre à voie
  unique réel (drag ET boutons = une seule fonction).

## Vérif verte finale (rejouée réellement)

- `dart run melos run analyze` → **RC=0** (32 `info` de dépréciation `hasFlag` PRÉ-EXISTANTS dans
  des tests zcrud_session non touchés ; niveau `info`, n'échoue pas).
- `dart run melos run verify` → **RC=0** — 10 gates ; graphe **54 arêtes, ACYCLIQUE, CORE OUT=0** ;
  secrets OK ; reserved-keys OK ; web OK.
- `flutter test` par package : flashcard **541**, study **342**, responsive **107**, session
  **521**, kernel **361** — tous RC=0.
- **Falsifiabilité R3** (injection → RED, restauration sha256 OK, zéro `git checkout`) : D1 (2 RED),
  D4, F1 (browse + sm1), F2.
