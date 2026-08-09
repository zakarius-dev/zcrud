# Handoff **v0.68.0** — la vitrine a trouvé un défaut de v0.66.0, et il est refermé

> **Tag à épingler : `v0.68.0`** · strictement **additif** — aucune signature cassée, aucune arête,
> aucun paquet nouveau (38). Un hôte qui ne change jamais la configuration d'un stepper monté ne voit
> **rien** changer.

---

## 1. 🔴 Le défaut, et comment il a été trouvé

Nous avons écrit une page de démonstration pour montrer que trois de vos demandes étaient **déjà
couvertes**. En l'écrivant, elle a découvert que **`ZStepperEdition` ignorait tout changement de
`config`** : `didUpdateWidget` observait le contrôleur, les champs, les étapes et le déclencheur —
**jamais la configuration**.

Conséquence : basculer `showAllSteps` sur un stepper **déjà monté** laissait la fenêtre de visibilité
calculée pour le mode paginé. Les étapes suivantes s'affichaient avec leur **en-tête** et un contenu
**VIDE**.

🔴 **Rien ne levait, rien ne rougissait.** Ni la campagne R3 du stepper, ni les 1 546 gardes du cœur
ne l'ont vu — parce qu'aucune ne changeait la configuration d'un stepper **après** son montage. C'est
la famille de défaut que nous traquons depuis une semaine : *un code correct sous le seul scénario
qu'on lui fait jouer*.

Nous l'avons livré nous-mêmes en v0.66.0, la veille.

## 2. Le correctif, et pourquoi il n'invalide pas tout

La réponse facile — « recalculer dès que la configuration change » — aurait refermé un défaut
silencieux en ouvrant une régression de performance sur **l'objectif produit n°1** du dépôt.

À la place, la table a été établie sur les **seuls sites où la configuration est lue hors rendu**
(33 occurrences recensées, 6 pertinentes) :

| Canal | Nature | Ce qui doit être invalidé |
|---|---|---|
| **`showAllSteps`** | **STRUCTUREL** — il pilote qui gère la visibilité, quelles gardes sont abonnées, et la fenêtre publiée | fenêtre republiée, gardes réabonnées, contributions des sous-steppers purgées |
| `validateOnNext` | lu **à l'appel** | rien |
| `allowStepTap` | lu **au build** | rien |
| **13 canaux visuels** (orientation, style, position, libellés, sous-titres, tailles, 6 couleurs) | **VISUEL** | rien |

⇒ **un changement de couleur ne reconstruit pas vos champs.** C'est mesuré : sous bascule d'un canal
visuel, le compteur de construction du champ **ne bouge pas**, alors qu'il passe de 1 à 2 dès qu'on
neutralise le mémo.

**L'invariant tient** : les zones d'étape montées sont toutes passives, **zéro doublon** d'écrivain —
la garde l'affirme ainsi, et non par un « la fenêtre est correcte » qui pourrait être juste par
hasard.

**Votre saisie survit à la bascule** : une valeur saisie en paginé et une autre saisie en déplié sont
toutes deux intactes au retour — valeur **et** contenu du contrôleur de texte.

## 3. Le contournement de la vitrine a été retiré

La page compensait par un remontage forcé, documenté sur place. **Retiré** — et la garde qui le
couvrait est **restée verte**, ce qui était la prédiction : elle jouait le rôle de tripwire.

⚠️ **Une différence assumée depuis le retrait** : sans remontage, l'étape courante est **conservée**
au retour en mode paginé, au lieu d'être remise à la première. C'est écrit dans la page.

## 4. La vitrine elle-même

`example/lib/demos/stepper_sub_list_demo_screen.dart` — elle **démontre**, elle ne se contente pas de
compiler :
* le **mode déplié** de v0.66.0 : rail, badges numérotés, titre et sous-titre par étape ;
* l'**ACL de sous-liste en direct** : on voit les actions de ligne disparaître puis revenir, seule la
  consultation restant ;
* le **champ à valeur structurée** : une map vide **refuse « Suivant » ET affiche pourquoi** — c'est
  le refus muet corrigé en v0.67.0, montré en fonctionnement ;
* **`rowChips`** en mono statique, en mono **dynamique** (choix filtrés par un autre champ) et en
  **multi**. C'est la réponse à votre Gap 2, et elle se voit.

🔵 **Bonus non prévu** : la valeur devenue **orpheline** y reste visible sous son libellé
d'indisponibilité — le correctif de v0.65.0, visible sans qu'on l'ait cherché.

**Tout y est déclaratif** : aucun `fieldBuilder`, aucun contournement du dispatcher, aucun accès
privé. Les seuls apports impératifs sont ceux que l'architecture réserve à l'hôte.

## 5. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans changement de configuration sur un stepper monté, comportement strictement identique |
| **hôte qui basculait le mode** | vous pouvez **retirer votre remontage forcé** si vous en aviez un : le socle s'en charge, et votre saisie survit |
| **DODLP** | la vitrine répond en une page à vos Gaps 2, 3 et 4 — elle montre que `rowChips` **est** le select en chips, que l'imbrication marche, et qu'un champ custom écrit déjà une valeur structurée |

## 6. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1556** (+10) · `zcrud_study` 1521 · `zcrud_markdown` 516 · `zcrud_firestore` 770 ·
`zcrud_flashcard` 586 · `zcrud_select` 135 · `example` **102** (+5). **0 erreur, 0 avertissement.**
**Aucune garde préexistante retouchée** — ni les 1 546 du cœur, ni les 97 de la vitrine.

**Défaut reproduit avant d'être corrigé** : fichier restauré au pristine **par copie**, la garde rend
alors **6 rouges sur 10**, dont un « contenu absent » et une fenêtre de visibilité fausse. C'est la
preuve que le correctif corrige quelque chose.

**R3 — 14 injections** sur les deux lots, sha avant **et** après chacune, restauration par copie,
résidus : greps négatifs montrés.

🟢 **Une injection est restée VERTE, et elle est déclarée non prouvée mordante** — pas forcée, pas
reclassée. Mesurée inerte à la frame mais nécessaire **sous-frame** ; la ligne est gardée, son statut
est écrit. C'est la deuxième fois en deux jours qu'un lot préfère consigner une injection verte
plutôt que de la maquiller.
🟢 Un premier essai d'injection rougissait par **compilation** : **rejeté et remplacé**, pas compté.
🟢 Et les deux sens de bascule sont gardés avec des **observables différentes** — le montage des
champs dans un sens, la fenêtre dans l'autre, là où une garde de montage aurait été vacante.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 7. Fragilité latente signalée, non corrigée

`DynamicEdition.didUpdateWidget` n'observe pas son propre drapeau de gestion de visibilité
(recherche négative montrée). Sans effet sur la bascule de mode — les racines changent de type, donc
il y a remontage — mais un hôte qui **ajoute ou retire des sous-étapes** sans changer de mode pourrait
laisser une zone d'édition écrivain de la fenêtre. Mesuré, écrit, pas corrigé : c'est un lot à part.

## 8. Non couvert

* Le focus après bascule n'est pas asserté (virtualisation) — **préféré à une garde vacante**.
* `itemTitleBuilder` reste non déclaratif : c'est une fermeture, interdite dans une spécification
  sérialisable.
* Le littéral « Étape k sur N » (cf. v0.66.0) reste en dur.
* Dettes antérieures : cf. v0.67.0 et les handoffs précédents.
