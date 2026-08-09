# Handoff **v0.62.0** — CR-IFFD-78 : un paramètre est honoré, ou son inertie est écrite

> **Tag à épingler : `v0.62.0`** · **hôte passif : rien ne bouge** (étalons d'arbre verts sans
> retouche, aucun défaut changé).
> ⚠️ Une **rupture pour implémenteur tiers** du port optionnel (§ 5). Aucun paquet nouveau (38).

---

## 0. Sur la CR elle-même

C'est la meilleure CR que ce dépôt ait reçue, et deux choses la rendent telle.

**Elle se corrige avant d'argumenter.** Vous aviez commencé par lire un « paramètre passé, non lu »
franc ; vous avez découvert que la restriction était **déclarée** pour `barrierDismissible`, et vous
avez réécrit la demande en conséquence — en le disant en tête, pas en note de bas de page.

**Et le défaut a été trouvé par une injection restée VERTE.** Votre garde affirmait qu'une feuille se
ferme par la barrière ; vous avez injecté `barrierDismissible: false` en attendant du rouge ; la
garde est restée verte, et l'empreinte prouvait que l'injection avait bien été écrite. Votre phrase
est exacte et mérite d'être reprise telle quelle :

> *Un paramètre qui ne peut produire aucun effet ne se détecte pas en lisant du code qui compile ;
> il se détecte quand on essaie de s'en servir.*

C'est le pendant exact des sept gardes vacantes que nos propres lots ont démasquées cette semaine.

---

## 1. ③ La règle, livrée en matrice dérivée — c'est le vrai contenu du lot

Deux matrices publiées : `packages/zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md` et
`packages/zcrud_get/doc/parameter-matrix-z-get-form-presenter.md`.

Vous demandiez la forme du catalogue de types de v0.60.1, « dont vous écrivez qu'il rend inexprimable
d'annoncer supporté un type routé en repli ». **La même propriété est atteinte ici, et par une voie
plus forte que la lecture de code** :

🔴 **Chaque cellule est MESURÉE, pas déclarée.** La surface est montée **deux fois** — une fois aux
défauts du port, une fois avec **un seul** paramètre changé — et les deux rendus sont réduits à une
empreinte uniforme (contrainte *liante* via `LayoutBuilder`, encart restant, rect, `enableDrag`,
`shape`, effet d'un tap hors surface). La règle est alors :

> **honoré ⇔ les deux empreintes diffèrent.**

**Il n'existe aucun champ où écrire un statut.** Annoncer « honoré » un paramètre que la branche
ignore est donc *inexprimable* — c'est précisément votre méthode d'injection, systématisée et rejouée
à chaque `flutter test`.

**Limites nommées, pas maquillées** : l'exhaustivité des **modes** est garantie à la compilation
(`switch` sans `default`) ; le lien **enum ↔ signature du port** est tenu par une garde qui lit le
port sur disque — ce maillon-là **n'est pas structurel**, et c'est écrit. La synchronisation des
documents est une comparaison octet à octet.

## 2. 🔴 Un défaut que votre CR n'a pas vu — et qu'aucune lecture ne pouvait voir

`useSafeArea` était **inerte en mode `dialog` sous `ZGetFormPresenter`**. Et le code avait l'air
juste : `_constrained` **lit** bien le paramètre et **pose** bien sa `SafeArea`. Seulement,
`Get.dialog` porte **son propre `useSafeArea: true`** et enveloppe déjà la page — l'encart était donc
consommé en amont, et `false` rendait exactement le même arbre que `true`.

C'est votre défaut n°① sous une autre forme, dans le paquet que votre CR ne couvrait pas. Corrigé en
transmettant le paramètre à `Get.dialog` : **défaut inchangé, seul l'opt-out devient effectif.**
Les deux matrices sont désormais **identiques** — la divergence entre implémentations que vous
pointiez est refermée, pas déplacée.

Pour le reste, votre table est **confirmée cellule par cellule**. Une seule correction : le
`barrierDismissible` en `page` que vous notiez « s.o. » est mesuré **inerte**.

## 3. ① `useSafeArea` en `page` — votre hypothèse et la mienne étaient fausses toutes les deux

Nous avions parié que `MaterialPageRoute` fournissait déjà l'encart, auquel cas seul `false` aurait
été inerte et le correctif aurait été gratuit. **Mesuré (écran 800×600, encart 12/44/8/34) : faux.**
La route n'insère **aucune** `SafeArea`, et l'encart arrive **intact** au contenu — avec `true` comme
avec `false`, rect identique. Il n'existe donc **pas** de correctif « opt-out seulement » :
`false` ne peut devenir effectif qu'en faisant d'abord cesser `true` de l'être.

**Appliqué : l'inertie est DÉCLARÉE** — l'option que vous jugez vous-même « probablement meilleure ».
L'arbre par défaut ne bouge pas, et les deux échappatoires sont nommées au dartdoc : votre propre
`SafeArea`, ou `ZEditionChrome` dont le `Scaffold`+`SliverAppBar` consomme déjà l'encart haut.

🔴 **Ce qui reste ouvert, et c'est votre appel autant que le nôtre** : *honorer* le paramètre
déplacerait l'arbre par défaut de **tout** hôte passif en mode page. Nous ne l'avons pas fait
unilatéralement. **Le tripwire est posé** : la garde rougit si quelqu'un le fait un jour sans le
décider. Dites-nous si vous en avez l'usage réel — vous écriviez ne pas le savoir.

## 4. ② `isDismissible` — ajouté aux DEUX présentateurs

Défaut `true` = comportement d'aujourd'hui. Et la question que vous souleviez — la cohérence avec
`ZImplicitDismissControl` de v0.60.0 — est **mesurée**, pas raisonnée :

| | ce que ça fait |
|---|---|
| `allowImplicitDismiss: false` | **garde** le renoncement : la barrière reste vivante, passe par `maybePop`, donc par votre garde d'abandon |
| `isDismissible: false` | **retire** le renoncement : mesuré, **zéro appel** du seam de confirmation |
| les deux à `false` | aucune sortie implicite |

Les deux voies sont **orthogonales** (dans le SDK, `isDismissible` n'alimente que
`barrierDismissible`). Règle écrite au dartdoc et gardée **dans les deux paquets** — pas seulement
dans celui où le besoin s'est exprimé.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — aucun défaut changé, étalons d'arbre verts sans retouche |
| **IFFD** | ① l'inertie en `page` est désormais **écrite** ; si vous voulez peindre sous l'encoche en page, c'est votre `SafeArea` ou le chrome — dites-nous si vous préférez qu'on honore le paramètre (ça déplacerait tout le monde) · ② `isDismissible: false` vous donne la voie qui manquait pour **interdire** le renoncement |
| **hôte GetX (DODLP, IFFD)** | 🔵 `useSafeArea: false` en `dialog` **fonctionne enfin** — il ne faisait rien avant. Si vous aviez compensé par une `SafeArea` négative ou un `MediaQuery.removePadding`, **retirez la compensation** |
| 🔴 **implémenteur TIERS du port optionnel** | `ZImplicitDismissControl.presentWithDismissControl` gagne `bool isDismissible = true` : une implémentation **hors dépôt** cesse de conformer (erreur de compilation, pas un silence). `ZFormPresenter.present` est **intact**. Recensement montré : **deux** implémentations dans tout le dépôt, aucune dans `zcrud_riverpod` ni `zcrud_provider` |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump des 38 versions et des contraintes.

`zcrud_navigation` **176** (+32) · `zcrud_get` **150** (+31) · `zcrud_core` 1394 · `zcrud_select` 83 ·
`example` 97. **0 erreur, 0 avertissement.** **Aucun fichier de test existant retouché.**

**R3 — 8 injections**, toutes avec des empreintes qui ont **bougé**, restauration par copie, résidu :
grep négatif montré. Les rouges portent sur ce qui compte : `isDismissible` décâblé dans **chacun**
des deux paquets, `useSafeArea` retiré de `Get.dialog`, `useSafeArea` rendu **effectif** en page (le
tripwire), un paramètre ajouté au port et à ses deux implémentations, **un caractère** changé dans un
document publié, et une sonde rendue non discriminante.

🟢 **Qualification honnête à signaler** : la première passe d'une injection donnait un rouge de
**compilation**, pas d'assertion. Elle a été **refaite** en patchant les trois fichiers pour isoler
la garde, au lieu d'être comptée comme mordante.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Non couvert

* `useSafeArea` en `page` reste **inerte et déclaré tel** — le changer est une décision, pas un
  correctif (§ 3).
* `enableDrag` en `dialog` : inertie **structurelle**, un dialogue ne se glisse pas. Inventoriée
  comme vous le suggériez.
* La matrice couvre les **deux** implémentations du dépôt ; une implémentation tierce n'y figure pas
  et n'a aucun moyen d'y entrer — limite assumée.
* Dettes antérieures : cf. v0.61.0, v0.60.1 et v0.60.0 (dont ses **quatre axes visibles**).
