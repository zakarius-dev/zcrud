# Handoff **v1.4.1** — une sous-liste redevient lisible sur un téléphone

> **Tag à épingler : `v1.4.1`** — traite le dernier point du CR « mode lecture », celui que la
> v1.4.0 avait explicitement laissé de côté. Paquet porteur : **`zcrud_core`**.
> Release **additive** : là où la place suffit, rien ne change.

---

## 1. Le défaut

Sur votre TECNO KN4, fiche d'un poste en consultation, étape « Changements subis » : quatre
en-têtes tronqués au-dessus d'une ligne elle-même tronquée. Votre verdict était juste — *« la
sous-liste ne délivre aucune information lisible »*.

**La cause était un compromis assumé, devenu faux hors de son contexte.** Le mode en-têtes rendait
des colonnes de largeur **égale**, avec ellipse et sans défilement, pour que les cellules restent
alignées sous leur en-tête. Le commentaire du code ajoutait : *« le texte tronqué reste
atteignable par consulter/modifier »*. C'est recevable en saisie ; en consultation, cela ne l'est
pas — vous consultez et vous **imprimez**, vous n'ouvrez rien.

## 2. Ce qui change

**La table alignée reste** partout où la place suffit — vous ne la contestiez pas, et elle n'est
pas touchée. En deçà du seuil, chaque ligne **s'empile en couples libellé/valeur**, la valeur
n'étant plus tronquée mais renvoyée à la ligne.

**Les en-têtes ne peuvent plus rester orphelins** : cellules et en-têtes obéissent au même
calcul, dans une seule mesure de mise en page. Quand la ligne s'empile, le libellé **descend dans
la ligne** au lieu de coiffer une colonne qui n'existe plus.

**Le seuil est calculé, pas décrété** :

```
disponible = largeur − marges − (nombre d'actions × 48)
empilé  ⇔  disponible < colonnes × largeurMinColonne
```

où `largeurMinColonne` vient du jeton `ZcrudTheme.subListColumnMinWidth`, à défaut de la largeur
de colonne de libellés déjà réservée par la forme `inlineRow`, à défaut 160. Le raisonnement est
explicite : une colonne est coiffée par le libellé de son champ, elle doit donc valoir au moins
la colonne de libellés que le socle se réserve ailleurs — en deçà, c'est l'**en-tête** qui se
tronque, exactement ce que vous avez vu.

**Le repli vaut en consultation *et* en édition.** Il ne se déclenche que là où la table ne
délivrait plus rien, et « on ouvre l'item » justifie de *tolérer* une troncature, pas de la
*préférer*. Conséquence mesurée et gardée : les boutons d'action entrant dans le calcul, une
sous-liste en édition se replie plus tôt — à 800 dp sur quatre colonnes, la consultation garde la
table quand l'édition s'empile.

## 3. Le vocabulaire du socle est réutilisé — sauf le widget

Le couple empilé **est** la forme `definition` livrée en v1.4.0, et le repli sous seuil **est**
le mécanisme d'`inlineRow`. En revanche, le widget de fiche n'a **pas** été réutilisé, et la
raison mérite d'être dite : il applique les jetons de la fiche encadrée. Un hôte ayant déclaré
un encadré aurait donc obtenu **un cadre par couple à l'intérieur d'une ligne déjà bordée** — les
« cadres dans des cadres » que votre propre CR dénonce. Par contrat, c'est en outre un rendu de
*champ consulté*, alors que ce repli doit valoir aussi en saisie.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire. Là où la place suffit, la table est **inchangée** (contre-témoin
  dédié, géométrie assertée).
- Si vous compensiez en réduisant le nombre de colonnes de résumé sur mobile, vous pouvez le
  retirer — ou le garder, le repli ne s'en trouvera pas contrarié.
- Nouveau jeton `ZcrudTheme.subListColumnMinWidth` si vous voulez déplacer le seuil.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets).
Tests : `zcrud_core` **2166** (+14), `zcrud_screen` **288** (inchangé).

Le rouge initial est cité tel quel — les gardes ont été écrites **avant** le correctif, contre la
v1.4.0 : `valeur TRONQUÉE sur un téléphone : vendredi 12 avril 2024`, plus quatre en-têtes
trouvés là où il n'aurait pas dû y en avoir. Six injections R3, toutes rouges par assertion,
dont celles qui figent les points de conception : seuil codé en dur, en-tête survivant à
l'empilement, actions sorties du calcul.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
