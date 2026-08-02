# Handoff **v0.33.0** — le patron de commande externe atteint le carrousel et les sections

> **Tag à épingler : `v0.33.0`** · livraison **additive**, aucune rupture d'API.
> Suite directe de `v0.32.0` (CR-IFFD-38) : le patron `ZDisplayState` était livré mais **deux
> composants du socle ne l'acceptaient pas encore**.

---

## 1. Ce qui devient commandable

| Composant | Nouveau paramètre | Ce que vous pouviez faire avant |
|---|---|---|
| `ZSessionCardSwiper` | `indexController` (`ZIndexController?`) | **rien** — l'index était interne. Des flèches externes vous donnaient des **boutons morts** |
| section repliable (`ZStudyToolsSectionSpec`) | `expandController` (`ZToggleController?`) | **rien** — le repli n'obéissait qu'à son propre chevron |

**Sans contrôleur, comportement strictement inchangé.** Les deux paramètres sont optionnels.

Deux propriétés qui comptent, et qui sont gardées :
* **le contrôleur est la source de vérité, pas un miroir** — une commande **interne** (swipe, chevron)
  s'écrit **à la source**, donc reste lisible chez vous. Il n'y a jamais deux états à synchroniser ;
* **AD-10** : une commande **hors bornes** est ramenée dans les bornes **et réécrite dans le
  contrôleur**. L'ignorer vous laisserait affirmer un index que rien n'affiche.

## 2. 🟢 Une bonne nouvelle vérifiée pour vous

Vous nous signaliez l'**onglet actif** parmi les états non commandables. **Il l'est déjà** :
`ZPageScaffold` et `ZPageShell` acceptent un `TabController` que vous possédez, et nous l'avons
prouvé **à l'exécution** — pas par lecture — dans les **quatre** modes d'app-bar : `animateTo(1)`
change réellement l'arbre rendu, 4/4.

⚠️ Réserve honnête : cette propriété n'est **couverte par aucun test du paquet** (`grep` sur ses
tests : 0 résultat). Elle est vraie aujourd'hui, elle n'est pas **gardée** contre une régression
future. Nous poserons la sonde dans un lot séparé.

## 3. 🔴 Qui possède le contrôleur quand il y a N sections — l'arbitrage, et pourquoi

**C'est vous, jamais le paquet.** Le layout lit les specs **dans `build`** ; s'il créait les
contrôleurs, il les créerait **dans `build`** — instances remplacées à chaque rebuild, commande
silencieusement inerte. C'est-à-dire **exactement le bug que nous avons trouvé chez vous** en trois
endroits, et que nous refusons d'industrialiser.

Le `State` qui construit vos specs possède donc N contrôleurs (un champ, ou une table indexée par
identifiant), et `ZDisplayStateOwnerMixin` les libère pour vous — **et refuse une création tardive**.
Deux gardes structurelles verrouillent que le paquet ne s'en fasse jamais propriétaire.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| hôte **passif** | **rien** — aucun de ces paramètres n'est requis, aucun rendu ne change |
| vous voulez piloter le carrousel | posséder un `ZIndexController` dans un champ de `State` (via le mixin) et le passer. Vos flèches deviennent vivantes |
| vous voulez piloter le repli | idem avec un `ZToggleController` **par section** |

⚠️ **Rappel de `v0.32.0`, toujours valable** : vos **trois** contrôleurs créés dans `build`
(`menu_item_widget.dart:114,248`, `ai_assistant/widgets/folder_conversations_widget.dart:201`)
seront **refusés** par le mixin, avec une erreur nommant le fautif. Ce n'est pas une rupture de notre
part — c'est votre bug rendu visible.

## 5. Une doctrine conservée, à connaître

Le carrousel de session **n'a toujours aucun bouton « précédent »**, et nous n'en avons pas ajouté :
c'est **vous** qui commandez, et **vous** qui portez la synchronisation avec le curseur de votre
moteur de session. Si vous faites reculer l'index, rien dans le socle ne réaligne le moteur —
c'est documenté comme votre charge.

## 6. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_session` **565** (+10) · `zcrud_study` **804** (+7).

Dix injections R3, **toutes en rouge d'assertion**, dont la plus utile : un **miroir local**
réintroduit ⇒ divergence détectée **dans les deux sens**.

🟢 Et une garde de nous **trouvée non mordante puis retendue** : elle cherchait un nom de mixin par
simple présence de texte — elle rougissait sur sa propre documentation, et serait restée verte sur
un usage déguisé. C'est le même défaut que celui de votre garde de `v0.32.0` : **compter du texte,
déclarations et commentaires compris, ne mesure pas un usage.**

⚠️ Notre CI reste à l'arrêt (facturation) : ces chiffres sont des vérifications **locales**.

## 7. Ce qui n'est pas couvert

* **Aucune notification sortante** ajoutée sur le repli de section : il n'en existait aucune, et nous
  avons refusé d'en inventer une. Qui veut savoir écoute son contrôleur. À arbitrer si vous en voulez
  une pour le cas **sans** contrôleur.
* Le reset d'index consécutif à un changement de file notifie **pendant le build du parent** : un
  hôte qui reconstruirait sur cette notification peut voir un « setState during build ». Non
  atteignable depuis nos harnais, donc **non gardé**.
* Les autres instances relevées chez vous — page courante d'un visionneur, onglet piloté par tiroir
  ou barre parallèle, second bouton de révélation posé par le parent — **ne sont pas traitées ici**.
  Le patron les couvre ; les composants correspondants ne l'acceptent pas encore.
