# Handoff **v0.47.0** — CR-IFFD-59 + CR-IFFD-60 : la carte achevée, le déclencheur composable

> **Tag à épingler : `v0.47.0`** · aucune rupture d'API · défauts du déclencheur inchangés.
> 🔴 La carte de flashcard **change encore de rendu par défaut** (structure de référence,
> énoncé riche) — suite directe de CR-57, même gouvernance. Un point à lire absolument : le
> **LaTeX** (§ 3).

---

# Partie A — CR-IFFD-59 : la carte de flashcard, achevée

## 1. Le tableau de votre CR, ligne à ligne

| Élément | Livré |
|---|---|
| ligne d'en-tête | tuile ⚡ 32×32 (fond type 15 %, rayon 8, glyphe 18) + balises + `trailing` **sur la même ligne** ; énoncé **en dessous pleine largeur** |
| enveloppe | rayon 12, bordure, **ombre** — via les jetons `cardShadow*` existants (epic VIS), aucun jeton créé |
| énoncé | 13/w600, borné `kToolbarHeight×0.65`, **riche par défaut** (§ 3) |
| réponse | `Divider` h12 + **aperçu teinté par type**, tampon Vrai/Faux — et la **liste ✓/✕ des QCM**, que votre code rendait mais que votre CR ne demandait pas : le code a fait foi |
| pastille de pied | « proche ✅ » — non touchée |

L'aperçu de réponse est un **mode** (votre `isInGrid`) : voie typée `null` ⇒ suit la surface
(grille ON, rail OFF) ; liste en style `card` ⇒ ON. Les libellés « Vrai »/« Faux » sont
**injectés** (`answerLabels`, FR-26) — sans eux, repli opaque, jamais un mot français en dur.

Ajout demandé en cours de lot par le propriétaire : le **liseré est teinté par type** (très fin,
alpha 0,35 dérivé du dégradé, surchargeable) — la bande épaisse reste.

## 2. Un slot structurel nouveau sur la carte de base

`ZStudyToolsItemCard.titleWidget` — l'en-tête composé n'était pas exprimable avec `title` seul.
Le `title` String **reste la source sémantique** (l'annonce ne change pas) ; les façades
document/note relaient (la garde CR-LEX-78 l'a exigé d'elle-même).

## 3. 🔴 Le rendu riche — câblé sans arête nouvelle, avec UNE limite à connaître

Défaut = `ZFlashcardMarkdownContent` (`zcrud_flashcard`, qui porte déjà `zcrud_markdown`).
Adapté par mesure : liseré/padding de champ neutralisés, échelle 16→13 **composée** avec
l'échelle d'accessibilité, graisse/teinte héritées — et un `IgnorePointer`, parce que **Quill
volait l'appui long** à la carte (la garde CR-47 a rougi avant le correctif, pas après).
Texte nu : rendu visuellement équivalent au `Text` (taille réellement 13, zéro liseré peint).

⚠️ **La limite, dite franchement** : `ZFlashcardMarkdownContent` compose son codec **sans pont
LaTeX** — `$x^2$` s'affiche en **source littérale intégrale** (zéro troncature — le grief de
votre CR est levé — mais pas de formule *dessinée*). Pour le rendu dessiné aujourd'hui :
`questionBuilder` (il surcharge l'énoncé ET l'aperçu). Le remède amont — un paramètre `bridges`
sur `ZFlashcardMarkdownContent` — relève de `zcrud_flashcard`, hors de ce lot : **candidat CR**
si vous le voulez nativement.

**Coût mesuré** (votre « non mesuré ») : rail de 50 cartes markdown — culling intact
(**4/50 construites**, <15 après drag réel) ; pump 86-117 ms contre 34-71 en texte nu, payé sur
les ~4 cartes visibles seulement. L'ombre ne casse ni culling ni geste (pas d'A/B sans-ombre
possible — limite dite).

## 4. 🔴 Une garde jumelle a mordu APRÈS le lot — et c'est le système qui a gagné

Le lot avait posé un `DefaultTextStyle.merge` **coloré** pour teinter l'énoncé — la classe de
défaut exacte que la garde de source v0.39.0 interdit (seul `ZForegroundOverride` ferme les
trois chemins de premier plan). Cette garde vit dans `zcrud_core` : les vérifications du lot
(package `zcrud_study` seul) ne la jouaient pas — c'est le lot **suivant** qui l'a vue rouge.
Corrigé par la primitive (la couleur passe par `ZForegroundOverride`, le `merge` ne garde que
la graisse), re-prouvé vert. Leçon inscrite pour l'orchestrateur : **rejouer les gardes
jumelles des packages voisins avant publication**, pas seulement les suites du package écrit.

# Partie B — CR-IFFD-60 : fond, bordure, élévation — composables

Votre constat était exact mot pour mot (variantes exclusives, zéro élévation). Livré :

* `subfolderTriggerFill` (`none`/`surface`/`surfaceContainerLowest→Highest` — rôles, zéro hex) ;
* `subfolderTriggerBorder` (`none`/`outlineVariant`/`outline`) ;
* `subfolderTriggerElevation` (`double?`, relief **tonal**).

**Précédence** : `subfolderTriggerVariant` (v0.36.0) reste fonctionnelle et décide par défaut ;
chaque jeton fourni la **raffine attribut par attribut** (`none` = retrait explicite ≠ `null` =
« la variante décide »). Plus rien à peindre ⇒ chrome **absent de l'arbre** — la neutralité
littérale de `flat` est conservée et re-prouvée.

**Votre « non mesuré », mesuré** : une `BoxShadow(blur 8, offset (0,4))` sous `aboveTabBar`
**repeint réellement le `TabBar`** (796 pixels modifiés, delta max 254/255 — le déclencheur est
bord à bord, rien ne clippe). ⇒ **élévation tonale sans ombre portée** : voile
`ElevationOverlay.applySurfaceTint`, `Material.elevation` à 0 **par construction** — aucune
ombre possible, quel que soit M2/M3. Votre intuition était la bonne ; elle est maintenant un fait.

🟢 **Un défaut latent corrigé au passage — votre B-53, côté socle** : la variante `filled`
historique posait son fond en `DecoratedBox` **au-dessus** du Material — l'encre du tap était
avalée (la classe exacte de votre incident du tiroir). Le chrome est désormais un `Material` :
l'encre se peint au-dessus du fond, splash **réellement mesuré** (`paints..circle()`).

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | carte : rien à faire de plus qu'en v0.46.0 — la structure suit ; si vos énoncés portent du LaTeX, branchez `questionBuilder` (ou émettez la CR `bridges`) ; déclencheur : `subfolderTriggerFill: surface` + `subfolderTriggerBorder: outlineVariant` + l'élévation voulue = votre `Card.outlined` |
| **hôte à `subfolderTriggerVariant` posé** | rien — la variante décide tant qu'aucun jeton fin n'est fourni, gardé |
| 🔴 **hôte ayant compensé l'encre avalée** de `filled` (splash custom, `InkWell` externe) | **retirez la compensation** : l'encre est native désormais |
| **hôte au `contentBuilder`/`questionBuilder`** | rien — surcharges inchangées, gardées |

🟢 **Tripwire recommandé** : si vous compensiez l'encre, un test qui affirme votre `InkWell`
externe ; il rougira à l'adoption.

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **1205** (+30) · `zcrud_core` **1191** (+4) · **0 error, 0 warning, infos =
baseline (57/10)** · voisins verts : flashcard 586, session 565.

**R3 — 15 injections mordantes** (9 CR-59 + 6 CR-60), toutes rouges d'assertion ciblée,
restaurations par copie, aucun résidu. S'y ajoutent les gardes du dépôt qui ont mordu **en
réel** pendant les lots : parité CR-48 (table complétée), passe-plat CR-LEX-78 (relais des
façades), appui long volé par Quill (garde CR-47), et le `merge` coloré (garde v0.39.0, § 4).

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 7. Ce que nous savons ne pas avoir couvert

* **LaTeX non dessiné par défaut** (§ 3) — candidat CR amont (`bridges` sur `zcrud_flashcard`).
* Pas d'A/B de coût avec/sans ombre (limite d'instrumentation, dite).
* Le splash n'est mesuré que sous `InkSplash` (InkSparkle = shader non observable) ; la bordure
  est vérifiée par rôle, pas au pixel ; l'encre n'est pas clippée aux coins arrondis (inchangé).
* `questionMaxLines` a été **retiré au profit de `questionMaxHeight`** (inerte en rendu riche —
  AD-4) : vérifié non utilisé chez vous ; si un autre hôte le passait, c'est le seul point
  potentiellement sensible du lot — signalez-vous.
