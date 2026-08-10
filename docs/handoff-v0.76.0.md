# Handoff **v0.76.0** — l'homogénéité des champs, et un libellé annoncé trois fois

> **Tag à épingler : `v0.76.0`**
> 🔴 **Changement d'arbre visible** pour tout hôte des champs `zcrud_intl` (§ 2) — pas seulement
> vous. Le booléen, lui, reste **entièrement opt-in**.
> Aucun jeton nouveau, aucune arête, aucun paquet nouveau (38).

---

## 1. Le booléen encarté — opt-in, et le cadre n'est pas peint à la main

Votre option A est livrée : un drapeau sur la configuration enveloppe le champ dans le **conteneur
décoré du thème**. Défaut ⇒ rendu de v0.75.0 **strictement inchangé**, prouvé par quatre gardes —
dont une qui vérifie l'**absence** du décorateur, pas seulement l'absence de notre clé.

🔵 **Le chemin du cœur est réutilisé, mais un cran plus bas que prévu — et c'est mesuré** : appeler
le helper habituel aurait **rendu le libellé deux fois** (il pose toujours son propre label, alors que
la ligne le porte déjà), et son mode « nu » ne produit **aucun cadre**. L'encart descend donc à la
fabrique que ce helper appelle lui-même.
**La parité n'est pas affirmée, elle est comparée** : une garde monte un **vrai champ texte** dans le
même thème et confronte bordure, remplissage, couleur et padding réellement rendus.

**Aucun jeton nouveau** — `z_theme.dart` est **intouché**, vérifié.

### Trois décisions signalées
* la marge interne de la ligne est ramenée à zéro sous l'encart : sinon le champ serait **plus
  indenté que ses voisins** (deux paddings s'additionnaient) ;
* l'encart est **inhibé** en grande taille — la carte porte déjà le cadre ;
* l'état désactivé n'est **pas** rabattu sur la lecture seule : la décoration du cœur n'a pas de
  bordure « désactivée », donc vous **perdriez votre couleur de bordure**. Prouvé par injection.

🟡 **Le libellé en gras n'est pas livré**, et c'est un refus argumenté : aucun jeton ne décrit le poids
d'un *titre de ligne*, et en créer un aurait violé votre propre contrainte « aucun jeton nouveau ». Le
chemin propre est décrit dans le rapport — **votre décision**.

## 2. 🔴 Les champs `intl` — le doublon était un triplon

Les trois champs (`phoneNumber`, `country`, `address`) passent désormais par la décoration du cœur.
Le préfixe drapeau/indicatif reste posé : le paquet natif le pose **par-dessus** notre décoration,
qu'il conserve pour tout le reste.

**Votre constat était juste, et en dessous de la réalité.** Mesuré, le nœud d'accessibilité du
téléphone annonçait :

> **« Téléphone — Téléphone — Numéro »**

La troisième source est invisible dans votre CR : un conteneur sémantique dans lequel le texte externe
**se fond**. Et en grande taille, la carte s'y ajoute : **quatre** annonces pour un champ.
**Après : une seule occurrence, rendue et annoncée, dans les six cas** (trois champs × deux tailles).

🔵 **Une divergence que votre CR ne nomme pas** : ces champs posaient un espacement **qu'aucun champ
du cœur ne pose** — ils étaient donc **24 dp plus étroits que leurs voisins**. Retiré ; c'était l'autre
moitié de l'effet « le champ flotte » que vous décriviez.

**Pas d'opt-in, et c'est délibéré** : le rendu actuel n'était pas un choix — recherche négative à
l'appui, ces champs n'avaient **jamais** emprunté le chemin du thème. Un doublon de libellé est un
défaut ; l'offrir en option l'aurait **figé au contrat**.

⚠️ **Mode `bare` (grande taille)** : aligné nœud pour nœud sur ce que fait le cœur — la carte porte le
libellé, le champ n'en annonce pas. **C'est la convention du socle entier**, pas une régression
introduite ici ; la changer serait une correction du cœur, hors du périmètre de ce lot.

## 3. 🔴 Le constat le plus sévère de ce lot porte sur NOS gardes

> **Aucune garde n'a eu à bouger** — et la recherche négative le prouve : aucun test de ce paquet
> n'assertait sur la décoration ou le libellé.
>
> Autrement dit : **250 gardes étaient vertes pendant que le champ annonçait son libellé trois fois.**

Treize gardes ajoutées, aucune supprimée.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif du booléen** | **rien** — sans le drapeau, rendu de v0.75.0 identique |
| 🔴 **tout hôte des champs `intl`** | **changement d'arbre visible**. Sans thème custom, le repli reste **inchangé au pixel** (gardé) |
| 🔴 **hôte qui compensait** | **retirez** votre libellé externe et tout espacement de réalignement, **sur les trois widgets** — sinon vous doublez ce que le socle rend désormais |
| **DODLP** | vos jetons déjà câblés (`fieldFillColor` blanc, `fieldBorderColor` gris, rayon 12) s'appliquent **automatiquement** au téléphone, au pays et à l'adresse — et au booléen dès que vous posez le drapeau d'encart |

## 5. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1708** (+23) · `zcrud_intl` **263** (+13) · `zcrud_study` 1521 · `zcrud_markdown` 516 ·
`zcrud_get` 150 · `zcrud_select` 135 · `example` 108. **0 erreur, 0 avertissement.**
**Aucune garde existante retouchée** dans aucun des deux paquets.

**R3 — 22 injections, toutes rouges d'ASSERTION**, sha avant **et** après, restauration par copie,
résidus : greps négatifs et `diff` montrés.

🟢 **Trois gardes auraient été vertes par accident, et la mesure les a rattrapées** :
* côté booléen, la garde d'accessibilité comptait **deux** annonces **dès la ligne de base**, avant
  toute modification — l'interrupteur produit un nœud fusionné qui reporte le drapeau d'état. Elle
  aurait donc **défendu le défaut** au lieu de le détecter. Corrigée, dump de l'arbre à l'appui ;
* côté `intl`, une injection du plancher tactile ne rougissait pas parce que la garde prenait le
  **maximum** des contraintes et se satisfaisait du **48 × 48 du bouton du paquet tiers** — elle
  mesurait le plancher **d'autrui**. Corrigée par une clé nommée sur notre propre contrainte ;
* une troisième injection était **inerte** (le nœud visé n'est pas monté dans ce mode) : reformulée
  plutôt que comptée.

C'est le **troisième lot consécutif** sur le fichier booléen, et le premier à ne pas trébucher sur le
doublement d'annonce — parce qu'il a mesuré la **ligne de base** au lieu de la supposer.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 6. Signalé, non fait

* 🔴 **Deux autres champs de `zcrud_intl` ont EXACTEMENT le même défaut** — décoration nue, doublon de
  libellé, espacement en trop. Hors du périmètre de votre CR ; la garde de source est écrite fichier
  par fichier pour les y ajouter **d'une ligne**.
* Un ornement de préfixe **ne peut pas** être honoré sur le téléphone : le paquet tiers **écrase** cet
  emplacement. Documenté — et **sans garde**, délibérément : écrire une garde ici reviendrait à
  **défendre la perte**.
* Le libellé en gras du booléen (§ 1).
* La garde vacante de `zcrud_intl` signalée en v0.75.0 reste ouverte : elle n'était sur le chemin
  d'aucun des deux lots.
* Dettes antérieures : cf. v0.75.0 et les handoffs précédents.
