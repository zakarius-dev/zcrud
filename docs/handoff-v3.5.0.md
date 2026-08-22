# Handoff **v3.5.0** — CR-IFFD-86, les trois volets

> **Tag à épingler : `v3.5.0`** — paquets porteurs : **`zcrud_core`**, **`zcrud_chat`**.
> ⚠️ **Deux changements de rendu**, tous deux dans le sens de la lisibilité — §1 et §2.

---

## 1. ⚠️ Le libellé de pastille n'est plus la couleur de surface

Votre diagnostic était exact, et votre formule l'a emporté : *« correct au sens de la mesure, et
faux au sens de l'usage — personne n'écrit du noir sur une pastille d'alerte »*.

Le libellé dérive désormais du rôle **premier plan d'erreur**, comme vous le demandiez. Le plancher
de contraste reste appliqué en **garde-fou** : il corrige un couple illisible, il ne choisit plus
la couleur.

**Le rendu par défaut change**, mesuré sur le schéma du SDK : en clair `#D6D6D6` → `#FFFFFF`, en
sombre `#535353` → `#601410`.

⚠️ **Ce que vous devez savoir** : un thème qui surcharge la couleur d'erreur **sans** surcharger son
premier plan fournit un couple désaccordé. Le plancher le rattrape — mesuré, un rouge personnalisé
donne un libellé clair à 4,5:1 — mais le blanc pur de votre legacy suppose que **les deux rôles**
soient surchargés ensemble.

**Le rôle que vous nommiez n'était pas atteignable** depuis le paquet concerné : la bibliothèque qui
le porte y est bannie par une garde de pureté, et notre thème portait la couleur d'erreur **sans**
son premier plan. Le jeton manquant a donc été ajouté au cœur, apparié au sien.

## 2. La présentation d'un menu d'artefact devient injectable

Votre argument a porté sans réserve : *« la barre décide quels verbes sont visibles — ce qu'elle
fait bien — mais elle ne devrait pas décider comment ils sont peints »*. Et le motif existait bien
chez nous : la couture livrée est **de forme identique** à celle de l'autre menu du dépôt, pas une
troisième variante.

🔴 **Un maillon que ni votre CR ni notre analyse ne voyaient** : posée sur la seule barre, la
couture serait restée **inatteignable** — c'est la vue notebook que vous montez. Le relais a été
ajouté et gardé.

**Ce que la couture ne peut pas faire** : le sélecteur passe par le **même chemin** que le rendu par
défaut. Une présentation alternative ne peut ni contourner la confirmation d'un verbe destructeur,
ni faire réapparaître un verbe que la barre a écarté. C'est ce qui rend l'injection sûre.

**Le menu par défaut devient une grille de trois colonnes**, réglable — **1** retrouve la colonne.
Même défaut que l'autre menu : deux défauts différents pour deux menus du même écran seraient un
piège.

## 3. L'accent d'état actif du composer — avec une correction à votre constat

Le jeton et le paramètre existent, chaîne `paramètre > jeton > rien`, portée au plancher de
contraste.

⚠️ **Mais votre constat était inexact sur un point, et c'est à votre avantage** : vous écriviez
qu'un outil actif se voit comme un outil au repos. **Ce n'est pas vrai des bascules du socle** —
elles gardent déjà le libellé emphasé quand l'état est actif, même en mode compact. Le passage de
notre documentation que vous citiez décrit le **raisonnement**, pas le comportement livré.

Le manque réel était donc bien le canal **chromatique** — et il reste réel si vous montez **vos
propres** bascules, ou le déclencheur d'outils qui est sans état par construction.

🔴 **La teinte s'ajoute, elle ne remplace pas.** L'état reste **écrit et annoncé** : en mode
compact, sans libellé visible, une information portée par la seule couleur serait invisible à qui ne
les distingue pas. C'est gardé.

## 4. Ce que vous ne demandiez pas, et que nous n'avons pas touché

La **sélection** des verbes et la **confirmation**. Votre justification est la meilleure preuve
qu'un mécanisme est au bon endroit : deux des cinq défauts que vous aviez mesurés en les tenant
vous-mêmes — un tap qui régénérait sans demander, une pastille qui volait le geste — sont devenus
**inexprimables**.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` **repo-wide** RC=0 ·
`melos run verify` RC=0.
**Balayage complet des 40 paquets** : `zcrud_chat` **673** (+25 sur la vague) · `zcrud_core` 2371 ·
`zcrud_study` 1555 · … tous verts.
⚠️ `zcrud_generator` échoue de façon **environnementale** — rouge qualifié, code sain.

Seize injections R3 sur les deux lots, rouges **par assertion**. Deux faits méritent d'être dits :

- une garde du premier lot **assertait une prémisse devenue fausse** — l'égalité exacte du libellé
  avec la couleur ambiante, qui mesurait l'ancienne chaîne. Elle a été **corrigée, pas défaite** :
  ses assertions d'intention sont conservées, et l'égalité exacte déplacée dans une garde à schéma
  cohérent, qui est votre cas réel ;
- deux cas d'une garde de contraste sont **restés verts** sous injection et ont été **déclarés comme
  contre-témoins** plutôt que comptés : sur ces teintes, l'ambiant tenait déjà le plancher.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale constitue la
ligne de défense de cette release.
