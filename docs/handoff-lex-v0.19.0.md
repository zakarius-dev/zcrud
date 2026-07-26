# Handoff → session `lex_douane` · zcrud **v0.19.0**

> **Tag à épingler : `v0.19.0`**
> Vos **7 CR ouvertes sont livrées** (dont la bloquante), et l'UI d'étude qui vous
> manquait — carte de dossier, page-détail, page-shell — existe désormais.

| Lot | État |
|---|---|
| **CR-45 → CR-51** (codec Markdown) | ✅ **7/7 LIVRÉES**, dont CR-50 🔴 BLOQUANT |
| **Parité UI d'étude** (cartes de dossier, page-détail, app-bars) | ✅ **NOUVEAU** — `ZPageScaffold`, `ZFolderCard`, `ZStudyFolderDetail` |
| **Parité session** | ✅ 3 écarts fermés par slots, 1 réfuté par preuve |

---

## 1. CR-50 — vous aviez raison, et la cause était en amont de votre diagnostic

Votre CR décrivait l'incohérence. La **cause racine mesurée** est plus simple et
plus grave que l'énoncé : `_kInlineDangerous` échappait `]`. L'encodeur écrivait
donc `[1]` → `\[1\]`, forme que `ZMarkdownBridges.latex` reconnaît comme **bloc
LaTeX**. Le codec **fabriquait la nourriture de son propre décodeur**.

Vérifié : la dégradation **se compose** (cycle 2 → `$$1$$`), contrairement à la
stabilité qu'annonçait la table des pertes. Le placeholder était sa propre
victime : `\[embed:chart\]` → `$$embed:chart$$`.

**Correctif** : `]` n'est plus échappé — `]` seul n'ouvre rien en Markdown (lien,
image et référence exigent tous un `[` ouvrant, lui toujours échappé). Plus gardes
`(?<!\\)` sur les délimiteurs, pour le `\]` résiduel d'un backslash littéral.

### 🔴 Votre option 1 est REFUSÉE, avec la mesure

Ajouter `[`/`]` à `escapedCharacters` **ne change rien** : ils y sont déjà
échappés. Et contrairement à `$` dont la forme échappée `\$` est inerte, la forme
échappée `\[` **EST** le délimiteur. **La symétrie que vous invoquez n'existe
pas** — c'est précisément ce qui rend ce défaut différent de tous les autres.

---

## 2. Les six autres, en une ligne chacune

| CR | Ce qui était cassé | Correctif |
|---|---|---|
| **45** | Un embed de bloc **partageait sa ligne Delta** avec le bloc suivant et en héritait l'attribut ⇒ titre détruit | `_ensureOwnLineEmbeds()` — répare la **structure**, pas le rendu |
| **46** | ALT effacé **aux deux bouts** | Syntaxe inline prioritaire au décodage + handler `image` à l'encodage |
| **47** | Retour souple en blockquote : mots recollés, emphase détruite | Normalisation au niveau **inline**, donc identique dans/hors citation |
| **48** | Aucune garde au décodage | `accepts` + `acceptsMatch()` défensif (AD-10) |
| **49** | Paragraphe **avalé** dans la citation | `zSeparateBlocksAfterQuote()`, idempotent |
| **51** | §A code inline détruit · §B liste renumérotée | Code opaque · numéro de départ **porté**, pas seulement documenté |

### Deux précisions qui vous concernent directement

**CR-46 — un commentaire de notre codec vous induisait en erreur.** Il déconseillait
de surcharger la clé `image` à l'encodage. **C'est faux** : la fusion y est
`addAll`, la clé **est** surchargeable. (Au décodage en revanche, `img` ne l'est
pas — fusion `{...custom, ...builtin}` : il a fallu une syntaxe inline prioritaire.)
Le commentaire est corrigé.

**CR-48 — rendre `false` ne suffisait pas.** Mesuré : `tryMatch` ne consomme rien
mais rend `true`, et `parse()` reboucle à la même position ⇒ **boucle infinie**.
Le refus réémet donc le premier caractère du délimiteur et consomme 1.
Votre **option 2** (variante « stricte » de `ZMarkdownBridges.latex`) est
**refusée** : elle dupliquerait la famille de motifs en deux jeux à synchroniser —
une seconde source de vérité, c'est-à-dire le défaut que vos CR combattent.

### ⚠️ Une interaction que nous n'avons pas masquée

**CR-50 × CR-46** : écrire `\]` pour un ALT contenant `]` **rouvrirait CR-50** (un
`\[` échappé plus haut dans la ligne y trouverait son délimiteur fermant).
Arbitrage explicite : dans ce seul cas, l'**ALT est omis** (`![](src)`, URL
intacte). Perte **bornée et inscrite dans la table des pertes**, jamais une
corruption du texte voisin.

---

## 3. NOUVEAU — l'UI d'étude que vous n'aviez pas

Vous consommez déjà `ZFlashcardReviewCard` en production. Il vous manquait tout
le reste de la coquille. C'est livré, **neutre et thémable** : vos couleurs, vos
libellés, votre look — via bridge, comme `ZFlashcardReviewBridge`.

```dart
// Le page-shell : ce que vous dupliquez aujourd'hui sur 11 écrans
ZPageScaffold(
  title: 'Étudier',
  actions: [ZAppBarAction(icon: Icons.sort_rounded, semanticLabel: …, onPressed: …)],
  search: ZAppBarSearchConfig(hintLabel: …, onQueryChanged: …),
  tabs: [ZPageTab(label: 'Matériel', contentBuilder: …), …],
  mode: ZPageAppBarMode.pinned,   // ou fixed
);
```

- **`ZFolderCard`** — props **primitives** (jamais l'entité), accent dérivé du
  `colorKey`, compteur en **slot** (votre compteur simple et les badges par type
  d'IFFD sont tous deux couverts), `archivedLabel` **injecté**.
- **`ZStudyFolderDetail`** — en-tête + onglets Matériel/Notebook/Progression ;
  l'onglet Matériel **compose** `ZSectionedStudyLayout`, Progression **compose**
  `ZStudyProgressRings` — rien n'est réimplémenté.
- **Navigation de sous-dossiers adaptative** : sidebar redimensionnable et
  repliable au-delà de 600 dp, sélecteur compact en deçà. Le seuil est délégué à
  `ZResponsiveLayout` — aucune constante en dur.

⚠️ **`ZPageScaffold` n'est PAS un portage du `DynamicSearcheableAppBar` d'IFFD.**
Celui-ci délègue son état à un controller externe, ce qu'AD-2 interdit. Le shell
**détient** son état de recherche. Conséquence pour vous : vous ne lui passez pas
un controller, vous lui passez une **config immuable** que vous pouvez remplacer
à chaque build.

---

## 4. Parité session — 3 fermetures, et un écart que nous avons refusé d'inventer

| Écart | Fermeture |
|---|---|
| Surbrillance du niveau suggéré (votre `alpha 0.12→0.24` + `width 1→2`) | `ZSrsQualityEmphasis` — **dimensions seules, aucune couleur** |
| Crans à 0 omis du bilan | `ZQualityBreakdownCoverage` |
| Pas de barre continue face à votre `LinearProgressIndicator` h=6 | `ZSessionProgressStyle.linear` + `linearThickness` |

**Tous les défauts préservent le rendu historique** : l'adoption est opt-in, rien
ne bouge chez vous tant que vous ne le demandez pas.

🔵 **Le sélecteur de mode : aucun écart, et nous n'avons rien codé.** `FilterChip`
RC=1, radio RC=1, stepper **déjà présent** dans `ZTestFiltersDialog`. Vos tuiles
sont des **lanceurs**, pas une sélection — la sémantique radio y serait fausse.
Preuve négative consignée dans `docs/parity-session-widgets-2026-07-26.md`, avec
les greps et leurs codes de retour.

---

## 5. Ce que la revue a trouvé, et que nous vous signalons

Une revue adversariale à 7 lentilles a tourné sur ce lot. Deux défauts **HIGH**
vous auraient touchés :

1. **Changer `mode` à chaud crashait** (`Null check operator`) — le contrôleur
   n'était créé que si le mode *initial* était sliver. Un shell adaptatif
   (fixed en compact, sliver en large) était donc un crash garanti. Corrigé.
2. **La frappe partait vers un callback mort** — la config de recherche était
   figée à l'`initState` : le hint suivait la config fraîche, l'émission la
   précédente. Le contrôleur relit désormais la config **au moment d'émettre**.

Et une garde de **notre** écriture était **tautologique** : elle affirmait couvrir
« la sélection ne rebâtit pas Progression » alors que l'onglet n'est pas monté
hors écran — vraie par construction. Supprimée, remplacée par une tranche
réellement montée, la limite écrite dans l'en-tête du test. Nous vous le signalons
parce que c'est le genre d'affirmation que vous auriez pu croire sur parole.

---

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (10 gates) · `graph_proof`
**ACYCLIQUE + CORE OUT=0** (69 arêtes) · `zcrud_ui_kit` **120** ·
`zcrud_study` **620** · `zcrud_session` **543** · `zcrud_markdown` **459** ·
`example` **97**.

Les 7 CR ont été **reproduites par un test rouge avant correction** (28 rouges de
baseline) et chaque garde a été prouvée mordante par ré-injection de la régression.

⚠️ **Le repro de CR-48 a dû être réécrit** : il assertait, *dans le même test*, la
**mesure du défaut** (`expect(charge, ' à 9 ')`) **et** l'**invariant réclamé**
(`expect(charge, isNull)`) — mutuellement exclusifs, il ne pouvait pas devenir
vert. Les invariants de votre CR sont conservés mot pour mot ; seules les
assertions qui épinglaient le comportement fautif ont été remplacées.

---

## 7. Ce qui reste chez vous

Le **câblage** (bridges) est app-side, comme toujours : zcrud livre des widgets
neutres, vous leur donnez votre thème et vos libellés. `ZFlashcardReviewBridge` et
`z_mindmap_bridge.dart` sont le patron à répliquer pour `ZFolderCard` et
`ZStudyFolderDetail`.
