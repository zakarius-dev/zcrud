# Handoff **v0.71.0** — la date est lisible partout, et un invariant qui pouvait se briser en silence

> **Tag à épingler : `v0.71.0`** · additif — un hôte qui n'injecte rien et ne bascule rien ne voit
> **rien** changer. Aucune signature cassée, aucun paquet nouveau (38), aucune arête.

---

## 1. La date en saisie — l'incohérence est fermée

Le port de formatage livré en v0.69.0 servait la fiche de lecture, le résumé de sous-liste et la
liste — **mais pas le champ en saisie**. Un même champ affichait donc une date lisible dans une liste
et un **ISO brut** dans le formulaire.

Corrigé, sur les **quatre** familles. Le déclencheur décoré de v0.63.0 était le bon endroit : il **a**
un contexte, donc le port et la locale y sont atteignables.

🔵 **`dateRange` a été traité après mesure, et pour une autre raison que les trois autres.** Il n'est
ni tabulaire ni affiché en fiche — il ne portait donc **pas** l'incohérence entre surfaces. Il portait
l'autre moitié du problème : sous port injecté, un formulaire aurait rendu une date **lisible** pour
un champ et un **ISO** pour la plage juste à côté.

**Le repli reste la chaîne d'aujourd'hui**, pas « mieux » — même règle qu'en v0.69.0, où un repli plus
lisible pourtant faisable avait été **écarté** parce qu'il aurait déplacé tout hôte passif.

🔵 **Un piège de normalisation évité** : les bornes d'une plage entrent dans la règle **déjà
normalisées**, là où un objet date nu serait replié sur sa représentation par défaut — qui n'est
**pas** de l'ISO. Prouvé par injection.
🔵 **Et un effet de bord corrigé au passage** : le formatage d'une plage était appelé **deux fois par
construction**, détecté par un compteur d'appels.

## 2. 🔴 Un invariant qui pouvait se briser en silence

`DynamicEdition` **lisait** son drapeau de gestion de visibilité sans jamais **comparer** son ancienne
valeur. Signalé en v0.68.0 comme une fragilité *latente*.

**Le scénario est atteignable, et il a été reproduit en rouge avant d'être corrigé** — pas dans le
stepper (qui passe une liste de champs neuve à chaque fois, donc le rebind complet a toujours lieu),
mais par **tout hôte direct** qui bascule ce paramètre **public** sur un catalogue constant.

🔴 **Les deux sens étaient défaillants, et le premier est grave** :

| Bascule | Conséquence |
|---|---|
| pilote → passif | la zone **restait écrivain** de la fenêtre de visibilité ⇒ **deux écrivains**, ce que l'architecture interdit |
| passif → pilote | la zone devenait **pilote inerte** — elle avait le rôle sans le remplir |

Le correctif est **discriminant**, comme celui du stepper en v0.68.0 : seul le rôle est structurel
(il décide si la zone écrit, et quel jeu d'observables est abonné). Ce qui ne dépend que des champs,
ou ce que le moteur consulte à l'appel, n'est **pas** réinvalidé.

**L'invariant est gardé par le COMPTE**, pas par l'apparence : zéro écriture en passif, **exactement
une** publication au passage de témoin, zéro doublon — mesuré en passes de recalcul.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — sans port injecté, l'affichage des dates est **strictement** celui d'aujourd'hui ; sans bascule du drapeau, aucun changement |
| **DODLP** | vos dates deviennent lisibles **aussi en saisie** — même formateur, aucun geste supplémentaire |
| **hôte basculant `manageVisibility`** | 🔴 vous aviez potentiellement **deux écrivains** de la fenêtre de visibilité, ou un pilote inerte. C'est fermé |

## 4. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.
`zcrud_core` **1604** (+21) · `zcrud_study` 1521 · `zcrud_firestore` 770 · `zcrud_flashcard` 586 ·
`zcrud_markdown` 516 · `zcrud_intl` 202 · `zcrud_select` 135 · `example` 102.
**0 erreur, 0 avertissement.** **Zéro fichier de test existant modifié** — les 1 583 gardes héritées
sont vertes sans retouche.

**R3 — 15 injections, toutes appliquées (sha différent avant/après), toutes rouges d'ASSERTION** ;
restauration par copie, sha revenus aux valeurs propres, résidus : grep négatif montré, fichiers
restés en texte.

🟢 **Deux gardes de granularité renforcées après mesure** — et le motif mérite d'être nommé : écrites
sur le **nombre de publications**, elles restaient **vertes** sous injection, parce que republier un
ensemble **inchangé** ne fait rien. Le repli rendait donc la valeur attendue **par hasard**. Elles
mesurent désormais le **travail à la source**, pas son effet observable.
🟢 **Une garde restée verte a révélé qu'une AUTRE mordait à sa place** : le repli « valeur non
parsable » attrapait le cas avant que l'exclusion de mode ne soit exercée. Une seconde garde, sur une
valeur réellement parsable, a été ajoutée.
🟢 Et une injection qui ne rougit pas la garde attendue a été **expliquée** plutôt que forcée : son
défaut n'est observable qu'à la bascule, déjà couverte ailleurs.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 5. Une dette annoncée qui n'existait pas

Un rapport précédent listait « `rowChips` sans résolution de libellé » parmi les dettes ouvertes.
**Vérifié : faux.** La voie multi formate chaque élément **récursivement**, donc elle traverse déjà la
résolution de choix et la règle d'orphelin de v0.65.0. Seul `relation` reste non résolu, et c'est un
**choix mesuré** — sa source est un flux, s'y abonner depuis une cellule élargirait la tranche.

⚠️ **C'est le troisième rapport d'agent pris en défaut aujourd'hui**, après un port faussement déclaré
oublié et un registrar attribué à un paquet qui n'en a pas. Sans vérification, ce lot aurait rouvert
une famille déjà résolue — et probablement produit une **cinquième copie** de la résolution de
libellés pour « corriger » ce qui marchait.

## 6. Non couvert

* `relation` ne résout pas ses libellés en liste — délibéré, motif ci-dessus.
* Les **Gaps 0, 3 et 4** de votre CR stepper sont livrés (v0.66.0, v0.67.0) mais **pas encore rejoués
  chez vous** — le Gap 3bis, lui, est accusé résolu.
* Dettes antérieures : cf. v0.70.0 et les handoffs précédents.
