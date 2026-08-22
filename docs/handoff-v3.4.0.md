# Handoff **v3.4.0** — CR-IFFD-85, les trois volets

> **Tag à épingler : `v3.4.0`** — paquets porteurs : **`zcrud_chat`**, **`zcrud_chat_markdown`**.
> ⚠️ **Un changement de rendu**, borné aux hôtes qui déclarent une coquille de tuile — §1.

---

## 1. ⚠️ Le filet borne le contenu, plus les commandes

Votre constat était exact, et vérifié sur disque : le filet englobait la tuile entière, barre
d'actions comprise. Votre formule a emporté la décision — *« le cadre cesse de délimiter la réponse
pour délimiter la réponse et ses commandes »*.

Le filet borne désormais le **contenu** ; la barre d'actions est rendue **sous** la carte.
Mesuré, et c'est votre centaine de pixels : sur un message court avec une barre de 96 dp, la
hauteur du filet passe de **132 dp à moins de 44 dp**.

**Le sort de chaque créneau a été tranché, pas subi** :

| créneau | | pourquoi |
|---|---|---|
| identité | **dedans** | elle dit *de qui* est le message — une propriété de la réponse |
| coiffe | **dedans** | c'est le titre de la carte ; dehors, le cadre serait sans titre |
| contenu | **dedans** | c'est ce que le cadre délimite |
| bouton de dépli | **dedans** | il gouverne la hauteur que le filet borne |
| **barre d'actions** | **dehors** | ce sont les commandes, pas la réponse |

**Aucun réglage n'a été ajouté** : la coquille a été livrée la veille et son seul consommateur connu
demandait le changement. Un bouton de réglage pour une API d'un jour avec un utilisateur aurait été
prématuré.

**Ce que vous avez à faire** : rien à retirer. Vous écriviez n'avoir rien contourné sur ce point,
et c'est cohérent avec notre code — encadrer vous-même le contenu aurait demandé de reconstruire la
tuile. L'impact est visuel.

## 2. `topicTrailing` — la place des commandes de la carte

La proposition du owner était la bonne, et votre legacy lui donne raison : ces verbes ne sont pas
des actions parmi d'autres, ce sont **les commandes de la carte**.

Le créneau est rendu **en fin de coiffe**. Le sujet occupe la place restante et **tronque** ; le
créneau garde sa largeur entière et une densité de glyphe réduite — 20 dp contre 24 pour une action
de message.

En y déplaçant vos trois verbes, ils quittent la rangée d'artefacts **et** rejoignent la coiffe : cela
résout aussi l'écart d'ordre que vous signaliez, sans que nous ayons eu à inverser quoi que ce soit.

⚠️ **Un écart délibéré avec votre legacy** : il compacte ses boutons en leur retirant leur
remplissage. Nous ne pouvons pas suivre — un **plancher tactile de 48 dp** n'est pas négociable.
Une coiffe portant un créneau chargé fera donc au moins cette hauteur. C'est le seul point où nous
divergeons sciemment, et il est gardé.

## 3. Le style de lecture devient déclarable

Votre constat était exact : le lecteur portait le canal, le renderer de chat ne lui passait jamais
rien. `styleSet` et `textScaleFactor` sont désormais relayés.

**Chaque axe est fusionné par-dessus le style courant**, donc un jeu **partiel** est légitime : les
axes que vous ne couvrez pas ne bougent pas.

**Règle d'articulation, et ce n'est pas un arbitrage** : sur un axe couvert par le jeu de styles,
c'est lui qui l'emporte ; ailleurs, le style global reste seul. C'est la mécanique de composition —
le style global sert de base sous le lecteur, le jeu est fusionné par-dessus.

⚠️ **Le facteur d'échelle est ABSOLU** — il **remplace** l'échelle ambiante au lieu de s'y
multiplier. Si vous voulez composer avec l'échelle d'accessibilité du système, multipliez vous-même
avant de la passer. L'ignorer **écraserait le réglage d'un utilisateur malvoyant** sans que rien ne
le signale. C'est le point le plus facile à manquer de cette livraison.

## 4. Votre rétractation, et ce qu'elle a changé

Vous aviez écrit que le rendu markdown coloré était « acquis, mesuré », avant de constater que les
couleurs observées étaient celles des **captures du legacy**. Cette correction n'est pas un détail
de forme : elle a transformé un écart d'échelle supposé en un écart **entier**, et c'est elle qui a
donné à ce volet sa priorité.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0.
**Balayage complet des 40 paquets** : `zcrud_chat` **648** (+15) · `zcrud_chat_markdown` **67** (+10)
· `zcrud_core` 2371 · `zcrud_study` 1555 · … tous verts.
⚠️ `zcrud_generator` échoue de façon **environnementale** — rouge qualifié, code sain.

Dix-huit injections R3, rouges **par assertion**. Deux méritent d'être citées :

- la garde du style ne mesure pas qu'un paramètre a été transmis, mais **le style effectif résolu
  par héritage** sur chaque fragment peint. C'était nécessaire : un style de bloc vit sur le nœud
  racine, un style inline sur l'enfant — une sonde à un seul niveau aurait manqué exactement l'axe
  dont vous vous plaigniez ;
- une injection est **restée verte** et a été **déclarée comme telle** plutôt que comptée : deux
  formes de flexibilité tronquaient identiquement, ce n'était pas un défaut. Refaite autrement, elle
  mord.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
