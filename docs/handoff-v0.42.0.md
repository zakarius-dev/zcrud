# Handoff **v0.42.0** — CR-IFFD-46 (quatre capacités de la feuille) + CR-IFFD-47 (carte par défaut)

> **Tag à épingler : `v0.42.0`** · additif, aucune rupture d'API. Tous les défauts sont conservés.
> 🔴 **Deux points concernent l'hôte qui COMPENSAIT** — § 6. Lisez-les avant d'intégrer.
> 🟢 **Un défaut préexistant que nous avions déclaré non corrigé est fermé** — § 3.

---

# Partie A — CR-IFFD-46 : les quatre capacités

Vos quatre points étaient **exacts**, vérifiés ligne à ligne. Aucun ne demandait un changement de
défaut : chacun signalait une décision d'apparence **non révisable** par l'hôte. Les quatre sont
livrés, tous à défaut inchangé.

| # | Livré | Où | Défaut |
|---|---|---|---|
| ① | `rootItemLabel` + `rootItemIcon` | spec | `null` ⇒ repli sur `allSubfoldersLabel` |
| ② | `subfolderSheetTitleAlign` | **thème** | `null` ⇒ `TextAlign.start` actuel |
| ③ | `itemMaxLines` | spec | `null` ⇒ une ligne, comme aujourd'hui |
| ④ | `subfolderSheetPadding` | **thème** | `null` ⇒ pleine largeur actuelle |

## 1. 🔵 Le point ① allait plus loin que vous ne l'écriviez

Vous demandiez un libellé distinct. Le vrai défaut est que **les deux surfaces sont indiscernables
pour l'hôte** : `zBuildSubfolderItemContent` passe `ZSubfolderRef(id: '')` au déclencheur **et** à la
ligne racine. Un `rootItemLabel` seul aurait résolu votre cas en laissant le défaut de modèle intact.

Le scope de surface **existait** (`ZSubfolderLayoutScope`) — mais mesuré : le déclencheur (`:199`) et
la feuille (`:456`) y posaient **la même valeur**. Il ne les distinguait donc pas.

⇒ Il est **étendu d'un second axe** — `ZSubfolderSurface { sidebar, chips, selectorTrigger,
selectorSheet }`, champ optionnel du **même** `InheritedWidget` — plutôt que doublé d'un mécanisme
concurrent. Votre `itemBuilder` sait désormais quelle surface il rend.
*(Son dartdoc documentait déjà qu'une 3ᵉ valeur de l'axe existant casserait les `switch` exhaustifs
d'hôte : c'est pourquoi c'est un second axe et non une valeur de plus.)*

## 2. Le point ② et le piège qu'il portait

Un jeton de thème nullable doit être ajouté aux **quatre** sites (déclaration, constructeur,
`copyWith`, `lerp`) **et** court-circuiter `lerp` quand il est `null` des deux côtés — sinon
l'héritage est gelé à la première transition de thème. La garde structurelle livrée en `v0.40.0`
(qui balaie tous les champs et **refuse d'être inerte**) couvre les deux nouveaux jetons.

## 3. 🔴 Le point ③ : votre prémisse était inversée — et ce lot ferme un défaut préexistant

Vous écriviez ne pas avoir mesuré l'effet de deux lignes sur la hauteur, et vous nous laissiez
l'arbitrage. Mesuré, bande `aboveTabBar`, libellé long sélectionné :

| `itemMaxLines` | hauteur du déclencheur | exception |
|---|---|---|
| **`null` (le défaut ACTUEL)** | 48 dp | 🔴 **débordement HORIZONTAL** |
| **`2`** | **48 dp — inchangée** | **aucune** |
| `3` | 68 dp | débordement vertical de 20 px |
| `3` + `subfolderNavBandHeight: 68` | 68 dp | aucune |

**À deux lignes, la bande ne coûte rien** : 40 dp de texte + 8 de gouttière tombent exactement sur le
plancher de 48. Le cas que vous redoutiez ne se produit pas.

🟢 **Et l'inverse est vrai : c'est l'état ACTUEL qui est le pire.** Le débordement horizontal du
défaut est exactement le *« débordement de libellé »* que nous vous avions signalé comme **candidat
CR non corrigé** au handoff `v0.40.0` § 4. **`itemMaxLines: 2` le ferme, sans coût de hauteur.**
Vérifié deux fois, indépendamment : par le lot, puis re-mesuré par l'orchestrateur sur son propre
harnais (824 px de débordement dans sa configuration — le chiffre suit la longueur du libellé, le
fait ne bouge pas).

**Arbitrage tranché : la hauteur reste DÉCLARÉE, et le dépassement est DÉNONCÉ.** Recalculer est
structurellement impossible — `preferredSize` est connue **avant** la mise en page (c'est le
mécanisme même du défaut de `subtitle`, § 2 du handoff `v0.41.0`). Borner en silence ferait rendre au
socle autre chose que ce que vous demandez : le grief même de vos CR.

**Cibles tactiles** : elles **grandissent** (48 → 68), elles ne rétrécissent pas.
**Hauteur totale de la feuille** à 12 fratries longues : **identique** avec `null` et avec `2`.

## 4. Le point ④ : plafond intact, mais le vrai risque était ailleurs

Le plafond de 80 % livré en `v0.36.0` est **inchangé** — 640 dp (= 0,8 × 800) mesuré à marge 0, 24,
120 et 300. Ce qui rompt sous marge, c'est la **largeur des items** (jusqu'à 0 dp au-delà de 128 dp
par côté). La dénonciation de cible tactile est donc généralisée et posée **sur chaque item**,
uniquement sous marge — le sujet est l'item, pas la colonne : les items indentés sont plus étroits
que la racine (279 contre 304 dp), et ne garder que la racine laissait une fenêtre de 25 dp.

---

# Partie B — CR-IFFD-47 : la carte par défaut

## 5. 🔴 Votre forme ne pouvait pas fonctionner — et ce n'est pas un détail

Vous demandiez « un rendu par défaut, utilisé quand `itemBuilder` n'est pas fourni ». Vérifié :
`ZStudyToolsSectionSpec` porte **`itemCount` + `itemBuilder(context, index)` et AUCUNE donnée**.
Rendre `itemBuilder` facultatif ne permettrait au socle de rendre **rien** — il ne sait pas ce qu'est
l'item numéro *i*.

C'est le même schéma que votre CR précédente : **constat juste, forme fausse**. Livré à la place :

**① `ZDefaultFlashcardCard`** — widget public **autonome** sur `ZFlashcard`. Seule `card` est requise ;
`typeLabels`, `tags`, `emptyTagsLabel`/`onTagsTap`, `palette`/`colorKey`, `questionMaxLines`,
`trailing`/`onTap`/`onLongPress` sont **injectés**. **Aucune entrée n'exige un type IFFD** — votre
test de frontière tient, et c'est ce qui rend la carte utile aux autres applications.

**② `ZStudyToolsSectionSpec.flashcards({required List<ZFlashcard> cards, …})`** — la voie typée qui
**porte les données** et fabrique `itemCount` + `itemBuilder`. C'est elle qui supprime réellement le
travail répété.

🟢 **`itemBuilder` reste `required` dans le constructeur principal** — il n'existe aucune branche de
repli. Un hôte existant ne peut pas régresser, et une garde de source (scanner ancré sur `melos.yaml`,
**échec bruyant** si le constructeur disparaît) le verrouille.

⚠️ **Le réordonnancement n'est pas offert par la voie typée**, délibérément : une carte éphémère
ferait déplacer la **mauvaise** carte — défaut déjà fermé dans `ZFlashcardListView`.

## 6. 🔴 VOTRE LIGNE — deux points pour l'hôte qui compensait

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — tous les défauts sont conservés |
| **vous, IFFD** | posez les quatre jetons ; remplacez votre `FlashcardCard` par `ZDefaultFlashcardCard` + vos actions par créneaux |
| 🔴 **vous compensiez le débordement de `ZTagChips`** | **retirez votre compensation** : il **tronque** désormais au lieu de déborder (il partait de 21 px en rail étroit) |
| 🔴 **vous posiez un `GestureDetector` externe** autour de `ZStudyNoteCard`/`ZStudyDocumentCard` | **retirez-le** : elles gagnent `onLongPress` en propre ⇒ **double déclenchement** sinon |
| vous voulez `itemMaxLines ≥ 3` **avec** `aboveTabBar` | déclarez `subfolderNavBandHeight: 68` |

🟢 **Tripwire recommandé** : sur chacun des deux points ci-dessus, gardez un test qui **affirme votre
compensation** (que votre `GestureDetector` reçoit bien l'appui long ; que les balises débordent).
Il rougira à l'adoption et vous désignera le doublon — au lieu de vous fier à ce handoff.

## 7. Ce que vous n'aviez pas mesuré — nous l'avons fait

**Coût pour un hôte existant** : **nul**, et prouvé — garde de source sur `required this.itemBuilder`,
plus garde de rendu vérifiant que l'arbre d'un hôte fournissant son builder ne contient **aucun**
`ZDefaultFlashcardCard` ni `ZTagChips`.

**Rail contraint contre grille** (`physicalSize` pompé à 2400 × 1600, jamais supposé) : 300 dp ⇒
264 dp de contenu, 800 ⇒ 264, 1200 ⇒ 232 ; cellules 300 × {120, 150, 180, 210} ⇒ **aucun**
`RenderFlex overflowed`.

🟢 **Cette mesure a trouvé deux défauts réels** que le rendu seul ne montrait pas : des `Align` sans
`heightFactor` faisaient mesurer la carte **854 dp au lieu de ~120**, et `ZTagChips` débordait de
**21 px** en rail étroit — corrigé **à la source** (ses 19 tests restent verts).

## 8. 🔵 Votre principe général, repris à notre compte

> *« la forme migre, exprimée sur les modèles du socle ; les dépendances de domaine et les actions
> restent chez l'hôte, par créneaux. Si le composant, une fois dans le socle, exige un type que seul
> IFFD possède, la frontière est mal placée. »*

C'est exactement le critère que le socle applique, et il est meilleur formulé ainsi que ce que nous
avions écrit. Vos candidats suivants — carte de document typée, carte de note, vignette de carte
mentale — sont recevables **sous cette règle**. Notez que `ZStudyNoteCard` et `ZStudyDocumentCard`
existent déjà : la question sera de leur ajouter une **forme par défaut**, pas de les créer.

## 9. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **1005** (+54) · `zcrud_core` **1169** (+9) · **0 error, 0 warning**, `info` **inchangés
(57)** · voisins rejoués verts : `zcrud_flashcard` 586, `zcrud_session` 565, `zcrud_ui_kit` 193,
`zcrud_get` 74, `zcrud_menu` 72, `zcrud_chat_study` 67.

**R3 — 21 injections, toutes ROUGES D'ASSERTION**, aucune de compilation, aucune inerte.
Trois d'entre elles ont dû être **rejetées et reformulées**, et c'est le plus instructif :
* une injection rendait un rouge de **compilation** — qui ne prouve rien : reformulée ;
* une garde était **VERTE sous sa propre régression** : elle cherchait un `Semantics` *descendant* de
  la pastille, or une annonce se pose en **ancêtre**. Bien écrite, mauvaise propriété — exactement le
  mode d'échec que nous traquons. Reformulée en « le type est annoncé exactement une fois » ;
* une propriété **non injectable en source** (rendre `itemBuilder` facultatif casse des dizaines de
  sites) a vu sa mordance prouvée sur l'**entrée du scanner**, avec contre-preuves : elle attrape la
  perte de `required`, ne rougit pas sur un simple retour à la ligne, et échoue si le constructeur
  disparaît.

Autres angles morts combattus : les deux surfaces du point ① mesurées **dans le même test** (une
garde qui n'en voit qu'une est verte quand le socle rend la bonne chaîne au mauvais endroit) ;
alignement mesuré en **géométrie peinte** ; non-vacuité contrôlée avant chaque mesure ; le `maxLines: 1`
de `ChoiceChip` identifié comme plancher **du SDK** et non le nôtre ; `takeException()` mesuré
**incapable** de restituer une dénonciation levée pendant l'animation modale ⇒ collecteur
`FlutterError.onError` dédié.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 10. Ce que nous savons ne pas avoir couvert

* **Aucun golden**, et **aucun rendu RTL réel** pour la carte : l'ordre de lecture est asséré en LTR,
  le RTL n'est couvert que par la garde de source.
* **`.flashcards` n'est pas testé *à travers* `ZSectionedStudyLayout`** — seulement en propre.
* **Réordonnancement** non offert par la voie typée (§ 5), délibérément.
* **Pas de mesure SM-1** sur la carte (widget sans état).
* Le point ③ n'est **pas** gardé en mode sliver `floating`.
* La dénonciation de cible tactile n'existe **que sous marge posée** : un parent anormalement étroit
  sans marge reste silencieux, comme avant.
