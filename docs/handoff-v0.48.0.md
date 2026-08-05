# Handoff **v0.48.0** — CR-IFFD-61 + CR-IFFD-62 : les écarts d'espacement fermés, le rail en contraintes descendantes

> **Tag à épingler : `v0.48.0`** · additif, aucune rupture d'API, tous les défauts de rendu
> conservés hors ceux explicitement demandés.
> 🔴 **Deux de vos constats ont été redressés par la mesure** — § 1 et § 2. Lisez-les : l'un
> désigne un réglage **de votre côté** comme cause, l'autre corrige une cause que vous aviez
> mal attribuée.

---

# Partie A — CR-IFFD-61

## 1. 🔴 Votre point ② est INFIRMÉ — et la vraie cause est trouvée

Vous demandiez de rendre optionnel « l'accent de 4 dp que `ZDefaultNoteCard` pose toujours ».
**Il n'existe pas au défaut** : l'accent ne vit que dans la hiérarchie `tintedTile` (l'ancien
rendu v0.43.0). Vérifié aussi chez vous : `study_tools_zcrud_adapter.dart:728` et `:762`
appellent `ZDefaultNoteCard` **sans `hierarchy`**, donc au défaut `tintedGlyph`, donc **sans
accent**. Deux gardes le verrouillent désormais dans les deux sens.

**Mais votre mesure au pixel était juste** — et l'enquête a trouvé ce qu'elle voyait :

> Les deux rendus sont **byte-identiques sur toute la face de la carte**. La seule divergence
> est la bande de **1 dp juste HORS de la face** : noire chez nous, transparente au legacy.
> C'est **l'ombre du `Card`** — `elevation` était laissé à `null`, donc au défaut Material —
> qui assombrissait les pixels autour de la tête de carte. Pas un accent.

Corrigé : `cardElevation = 0` dans la référence (le legacy n'a pas d'ombre) + jeton
`studyCardElevation` et slot `elevation` sur la carte de base pour qui en veut une.

## 2. ① Le gap tuile→titre, et pourquoi vous ne pouviez pas le corriger

Confirmé : la primitive posait `SizedBox(width: theme.gapM)` ; la référence pose **16**.
Comme vous réglez `gapM: 12` (pour votre padding de carte), le gap tombait à 12.

Livré : `leadingGap = 16` dans `ZStudyCardReference`, jeton `studyCardLeadingGap`, slot
`leadingGap` sur la carte de base. 🔴 **Sans fuite** : la carte de base **hors** cartes par
défaut garde `gapM` — un hôte qui l'utilise directement ne bouge pas d'un pixel (gardé par
une injection dédiée).

## 3. ③ Votre « preuve systémique » était partiellement dépassée

Vous écriviez que `gapM` porte **trois** valeurs. Le **padding de carte avait déjà son slot**
(`contentPadding`, et la référence y passe 12) : il en restait **deux**. Les deux sont
traitées — le gap (§ 2) et la gouttière de la feuille de fratrie
(`subfolderSheetContentPadding`, référence 8).

🔵 **Non demandé, à vérifier chez vous** : votre `radiusM: 16` scopé (que vous notiez « non
arbitré ») visait le rayon de carte — or celui-ci a son propre jeton `studyCardRadius` depuis
`v0.45.0`. Il est donc probablement **devenu inutile**, et il ride encore le déclencheur de
fratrie (référence ≈ 12). À retirer si c'est bien votre cas.

## 4. ④ Le compteur, adjacent au titre

`ZStudySectionCountPlacement { lineEnd (défaut, inchangé), adjacentToTitle }` — jeton de
thème + `studySectionCountGap`. En `adjacentToTitle`, le compteur reste **inflexible** et
c'est le titre qui est `Flexible` + ellipsé : le compteur n'est jamais écrasé par un titre
long. Mesuré à 320 dp, LTR et RTL, avec `secondaryActionLabel` et le chevron `inHeaderRow`.

# Partie B — CR-IFFD-62

## 5. 🔴 Votre diagnostic ⑤ était le bon — mais sa forme littérale est FAUSSE, mesurée

Votre cascade (`Expanded` sur l'énoncé, en-tête et pied fixes) a été implémentée **telle
quelle**, puis mesurée :

* pour que l'`Expanded` absorbe *tout*, l'en-tête et le pied doivent devenir **inflexibles**
  — sinon `RenderFlex` perd le reliquat des enfants *loose* (**81 dp de vide** mesurés) ;
* inflexibles, ils **débordent** : les gardes **CR-IFFD-47 §9** sont passées au rouge
  (`RenderFlex overflowed by 82 pixels` sur une cellule 300×120) — c'est-à-dire la régression
  exacte que **CR-IFFD-37** avait fermée.

⇒ Forme livrée, **même comportement affirmé par votre CR**, deux groupes qui restent
flexibles : `Column(max, spaceBetween)` = `Flexible[en-tête + énoncé]` / `Flexible[pied]`.
Vous aviez raison d'affirmer le comportement et pas l'implémentation : votre comportement est
tenu, votre implémentation ne l'aurait pas été.

**La bascule est MESURÉE, jamais déduite** : `constraints.hasTightHeight` — pas le fait qu'un
paramètre de hauteur soit passé.

## 6. Neutralité et cadre — les deux mesurés

| Sans cadre | hauteur intrinsèque **93,0 dp → 93,0 dp**, pastille au même rect (3 gardes) |
|---|---|
| **Sous cadre** | pied à **8 dp du bas**, **constant** quels que soient l'énoncé, le cadre et l'échelle (avant : 111,5 dp dans un cadre de 300) |

`ZRailItem.height` + `railItemHeight` suivent le patron **exact** de `railItemWidth` (CR-49).

## 7. 🔴 L'ellipse : NON atteignable sur le rendu riche — dit franchement

`TextOverflow` est une propriété de **paragraphe** ; le rendu riche par défaut est une
**colonne de blocs** Quill. Nous ne le prétendons donc pas.

Livré à la place : **`ZFadedOverflow`** (render object dédié), fondu de 12 dp peint
**uniquement** si le contenu déborde — mesuré **en pixels** (`RepaintBoundary.toImage`) :
encre de la dernière bande **< 75 %** du rendu sans fondu quand ça déborde, **octets
strictement identiques** quand ça tient. Layout inchangé dans les deux cas.
La **vraie ellipse** existe sur le chemin **texte nu** (`didExceedMaxLines` vrai,
`isTruncated` faux — jamais les deux).

## 8. Vos 45 px : un CUMUL, dont 4 dp viennent de VOUS

**12 dp** (padding de section = `gapM`, que vous réglez à 12) **+ 4 dp**
(`CardThemeData.margin`, que **vous** posez — votre propre commentaire le dit) = **16 dp**,
mesuré par garde. × 2,75 de densité ≈ **44 px**. Le legacy : 8 dp ≈ 22 px.

Livré : `railPadding` (défaut `null`). Quand il est fourni, le padding de section cesse de
s'appliquer au rail — sans quoi le retrait demandé resterait inatteignable.
⚠️ **Défaut délibérément non aligné sur 8** : ce serait désaligner le titre de section et les
cartes, l'en-tête restant à `gapM`. À vous de poser la valeur avec votre thème.

## 9. Les trois réglages du point ④

| Réglage | Défaut |
|---|---|
| `contentAlignment` | `spread` (la référence) |
| `railItemGap` | **voie typée : 12** (référence) · **constructeur principal : `gapS`** (historique — lex_douane ne bouge pas) |
| `railPadding` | `null` (§ 8) |

## 10. Votre « non mesuré » : l'échelle de texte

`textScaler` **1.5 et 2.0** : aucune exception, carte à 200 dp exact, énoncé borné, pied en
bas, **aucun rognage**. **Seuil mesuré : 130,4 dp** de contenu à l'échelle 2 — votre cadre de
référence garde ~70 dp de marge.

## 11. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **vous, IFFD** | posez `railItemHeight: 200`, `railItemGap: 12`, `railPadding` à votre valeur ; **retirez votre `SizedBox(height: 200)`** d'hôte (il ne servait à rien — mesuré par vous — et ferait doublon) ; vérifiez si votre `radiusM: 16` est encore utile (§ 3) |
| **hôte passif** | rien — sans cadre imposé, hauteur intrinsèque **identique au dp près**, gardé |
| **hôte utilisant `ZStudyToolsItemCard` directement** | rien — le gap de référence ne fuit pas sur la carte de base, gardé |
| 🔴 **hôte ayant compensé l'ombre** (fond posé pour masquer le liseré sombre) | **retirez la compensation** : l'élévation par défaut est désormais 0 |

🟢 **Tripwire recommandé** : un test qui affirme votre `SizedBox(height: 200)` d'hôte — il
rougira quand la hauteur native prendra le relais, et vous désignera le doublon.

## 12. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`melos generate` RC=0 (0 `.g.dart` modifié) · `zcrud_study` **1270** (+65 depuis v0.47.0) ·
`zcrud_core` **1213** (+22) · **0 error, 0 warning** · voisins verts : flashcard 586,
session 565, ui_kit 193.

**R3 — 16 injections mordantes** : 7 (CR-61, **rejouées intégralement par l'orchestrateur**,
l'agent rédacteur ayant été perdu — intégrité prouvée bit à bit contre sauvegardes) +
9 (CR-62, dont une première version disqualifiée pour rouge de **compilation** et rejouée
valide) + 1 injection indépendante de l'orchestrateur sur la neutralité sans cadre.

🟢 **Deux gardes du dépôt ont mordu d'elles-mêmes pendant les lots** : la garde de passe-plat
**CR-LEX-78** (les façades document/note relaient désormais le nouveau slot) et les gardes de
débordement **CR-IFFD-47 §9** (§ 5). Les verrous posés aux lots précédents travaillent.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 13. Ce que nous savons ne pas avoir couvert

* 🔴 **En grille avec aperçu de réponse, l'espace libre va entre l'énoncé et le divider** ;
  le legacy le donne à l'aperçu. Écart **déclaré, non traité** — candidat CR si vous le voyez.
* L'ellipse **vraie** reste hors de portée du rendu riche (§ 7) — fondu à la place.
* `railPadding` par défaut `null` et non 8 (§ 8), par choix argumenté.
* Aucun golden : géométrie, couleurs peintes et octets d'image, jamais un pixel de référence
  stocké.
