# Handoff **v0.59.0** — CR-IFFD-77 : l'état reste visible en compact, une pièce n'affiche que ce qu'elle pilote

> **Tag à épingler : `v0.59.0`**
> ⚠️ **Deux changements à connaître** : une **rupture d'API mineure** sur `badgeBuilder` (§ 2 —
> zéro consommateur mesuré) et un **changement visible** de la surface Material (§ 3 — bordure
> désormais peinte par défaut).

---

## 1. ① L'état actif en compact — CR-74 rouverte, refermée

Votre mesure était exacte, et votre lecture de la cause aussi : sous 400 dp le libellé
disparaît, **et c'est lui qui portait l'emphase**. Le glyphe, opaque et en `ExcludeSemantics`,
rendait à l'identique actif ou non.

**Règle retenue** : le compact masque le libellé des pièces qui **n'ont rien à dire** ; une
pièce dont l'état est actif **garde son libellé emphasé**. Un point de décision unique
(`_labelVisible`), appliqué aux 4 pièces à état (Réfléchir, Internet, effort, dictée).
« Outils » et « STOP » restent nus en compact : ils n'ont pas d'état — un badge et une
présence.

**Pourquoi ce canal plutôt qu'une pastille ou un fond** : le socle n'invente aucune couleur
(FR-26) et ne peut pas re-styler un glyphe d'hôte. Une pastille exigerait une couleur d'hôte,
donc un canal **conditionné au câblage** — c'est-à-dire zéro canal chez qui n'a rien câblé,
exactement le défaut à fermer. Le libellé emphasé est le seul canal peignable
**inconditionnellement**, et c'est déjà la grammaire de la feuille.

🔵 **Correctif annexe trouvé en chemin** : l'emphase de la bande était une **seconde
implémentation**, sans l'anti-annulation AD-10 de la feuille (le cas où l'ambiant porte déjà
graisse et soulignement). Implémentation désormais **unique**.

## 2. ② Le badge et son contrôle — la règle inscrite

`computeEffort` n'est plus lu par la bascule : `badgeBuilder` reçoit `bool active` — **la pièce
n'affiche que ce qu'elle pilote**.

**Pourquoi pas l'inverse** (faire piloter le budget par la bascule) : cela en ferait un
déclencheur à menu, c'est-à-dire **une autre pièce, qui existe déjà**
(`ZChatComposerEffortSelector`). On aurait deux menus voisins, et la bascule perdrait ce qui la
rend lisible. Votre modèle booléen + budget séparé est conservé ; **le kernel n'est pas
rouvert**.

**Règle inscrite au dartdoc**, à côté de celles de CR-74 et CR-75 :
> *un widget ne rend que la donnée que son propre geste écrit ; afficher un champ voisin fait
> de l'affichage un commentaire — vrai par hasard, faux dès que le modèle bouge.*

⚠️ **Seul point non additif du lot** : la signature de `badgeBuilder` change. Grep montré :
**zéro consommateur** hors sa déclaration, et le badge n'était de toute façon **jamais rendu**
(`computeEffort` nul au défaut). La rupture est une **erreur de compilation**, pas un silence.

## 3. ③ La bordure — et la mesure orpheline, délibérément laissée orpheline

`ZChatComposerSurface.borderColor` (paramètre > jeton > **rien**), épaisseur par la chaîne du
chrome, et 🔵 **un seul rayon** pour le fond, le filet et le rognage : les deux rayons que
l'hôte devait faire coïncider à la main **ne peuvent plus diverger**.

🔴 **Changement visible** : côté Material, le défaut est `Theme.dividerColor` — le rôle de lex.
**Un hôte qui compensait par un second conteneur doit retirer sa compensation.**

`clipBehavior` : **porté, `Clip.none` par défaut** — mesuré inutile aujourd'hui (aucun enfant ne
peint au bord), et un défaut `antiAlias` changerait l'arbre de **tout** hôte passif.

### 🔵 Sur `composerHelperDividerAlpha` : nous avons essayé, et une garde nous a arrêtés
Vous aviez raison de signaler la mesure inconsommée. Le consommateur a été écrit — et la garde
**REF-G7 l'a rougi** : *« le rendu de référence a été CÂBLÉ dans le socle »*. Code retiré, et
trois raisons inscrites au dartdoc : cette référence est **opt-in par `ZChatNotebookSkin`
seul** ; elle appartient à la famille **notebook**, pas **composer** ; et lex n'a pas ce filet
(il a une bordure). Son seul consommateur légitime serait un lot de la famille notebook.
**La valeur reste publiée et non consommée — c'est désormais un choix documenté, plus un
oubli.**

## 4. ④ Le déclencheur de dictée

`ZChatComposerDictationTrigger` : geste d'hôte, état **injecté** (`ValueListenable<bool>`), un
seul chemin de rendu, **trois canaux** (étiquette / `toggled` + région live / glyphe), ≥ 48 dp
dans les deux états. Material : `Icons.mic` → `Icons.stop` teinté du rôle `error`. Zéro
dépendance nouvelle. Le créneau `dictation` existant est inchangé.

🔵 **Vous aviez raison sur CR-76** : elle comptait cette pièce parmi ses six sans qu'elle y
soit. C'est exact, et c'est écrit au dartdoc.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **IFFD** | rien à faire pour ①②④ ; pour ③, si vous aviez enveloppé la surface d'un second conteneur pour votre bordure, **retirez-le** |
| **hôte du satellite Material** | 🔴 la surface peint désormais une bordure `dividerColor` par défaut — **retirez votre compensation** si vous en aviez une |
| **hôte consommant `badgeBuilder`** | signature changée (erreur de compilation, pas de silence) — mesuré à zéro consommateur |
| **hôte passif** | rien — `ZChatComposer`, l'étalon de la feuille et celui du composer rejoués verts |

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (38 paquets) · `melos generate` RC=0, aucun
`.g.dart` modifié · `zcrud_chat` **551** (+20) · `zcrud_chat_material` **47** (+4) · jumelles
inchangées : kernel 411, syncfusion 65, markdown 504 · **0 erreur, 0 avertissement**.
CR-74, CR-75, l'étalon de re-expression de la feuille et celui du composer : **rejoués verts**.

**R3 — 5 injections, toutes mordantes** (17 rouges au total) ; `sha256` à chaque pas,
restauration par copie, sha d'origine retrouvé, aucun résidu.

⚠️ Notre CI reste à l'arrêt (facturation) : vérifications locales, état commité re-mesuré après
commit.

## 7. Non couvert

* Jetons `chatComposerBorderColor` / `chatComposerBorderWidth` à poser dans `zcrud_core` — le
  niveau 2 de la chaîne est un **trou documenté** en attendant.
* `ZChatCaptureBar` non fusionnée avec le nouveau déclencheur : deux formes distinctes (bande
  vs bouton), non demandé.
* Aucune capture sur appareil réel de notre côté ; **DODLP et DLCFTI toujours non
  inventoriés** — votre « non mesuré » reste ouvert.
* Dettes antérieures : cf. v0.58.0.
