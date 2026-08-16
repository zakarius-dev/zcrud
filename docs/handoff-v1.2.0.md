# Handoff **v1.2.0** — appartenance à une sélection, et requis conditionnel

> **Tag à épingler : `v1.2.0`** — les deux manques du CR « condition d'appartenance et requis
> croisé ». Paquet porteur : **`zcrud_core`**. Release **strictement additive** : un formulaire
> qui n'emploie ni l'un ni l'autre est inchangé (contre-témoin dédié).

---

## 1. `ZCondition.contains` — un champ qui suit une case cochée

Les seize conditions existantes savaient comparer, tester une vacuité, mesurer une longueur —
mais pas répondre à « cette sélection multiple contient-elle telle valeur ? ». Vous aviez raison
de souligner que ce n'est pas un cas exotique : c'est la forme même d'un formulaire qui s'adapte
à une sélection multiple.

Vous pouvez désormais pré-déclarer un champ par option et n'afficher que les cochées, au lieu de
fabriquer des champs au rendu.

🔴 **Une décision explicite sur les chaînes** : **une `String` n'est pas une collection**.
`contains` y rend `false`, comme sur une `Map`, un scalaire, `null`, ou un champ absent — seul
un `Iterable` compte.

Le motif est celui que vous auriez rencontré autrement : `'lome-port'.contains('lome')` est vrai
en Dart. Une condition pointée par erreur sur un champ mono-valeur aurait donc *semblé marcher*,
puis surpris. Nous préférons un **faux négatif franc à un vrai positif fortuit** — et « est-ce
cette valeur ? » a déjà `equals`. La contrepartie est assumée et documentée.

Robustesse conforme à votre critère : jamais d'exception, quel que soit le contenu du champ.

## 2. `ZValidatorSpec.requiredIf` — requis seulement quand une condition tient

Votre règle « au moins un des trois » n'avait aucune traduction : trois `required()`
interdisaient la recherche par un seul critère, aucun laissait soumettre un formulaire vide.

Elle s'écrit maintenant avec trois `requiredIf`, chacun conditionné à la vacuité des deux autres
— et les deux nouveautés de cette version se composent.

**Une correction à votre constat** : vous écriviez qu'il n'existe « aucun seam de validation au
niveau du formulaire ». C'est exact de l'extérieur, mais **pas en interne** : la validation à la
soumission et celle sous le doigt de l'usager passent toutes deux par le même compilateur
inter-champs, qui tient déjà le contrôleur complet. `requiredIf` s'y insère comme quatrième
famille inter-champs, et la condition est **réévaluée à chaque appel** — le même validateur sert
donc la frappe et la soumission.

**Articulation avec la règle de la v1.1.0** (« seul `required` porte la présence ») : quand la
condition tient, le champ se comporte **exactement** comme `required` — même vacuité, même
message localisé. Quand elle ne tient pas, le vide est accepté, comme un champ sans `required`.
Les dix-huit familles de forme corrigées en v1.1.0 sont intactes.

`ZValidatorSpec` reste un type-valeur **`const`** : la spécification ne porte que la donnée.

**Limite dite franchement** : la source de contexte d'une condition n'est **pas honorée** ici
(mesuré : elle n'atteint aucun des six points de construction du champ). L'honorer côté
soumission seulement aurait produit un refus **sans message affichable** — pire que la limite.

## 3. Impact sur votre code

- **Hôte passif** : rien à faire, strictement additif.
- **Hôte ayant compensé** — deux gestes à retirer, sinon champs et messages **doublonnent** :
  la fabrication de champs au rendu dans votre dialogue de filtre, et la recompilation manuelle
  de la règle « au moins un des trois » dans votre écran de recherche.

## 4. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **2100** (+35), `zcrud_screen` **267** (non touché).

Six injections R3, toutes rouges **par assertion** — dont celle qui rend le cas de votre écran :
`requiredIf` neutralisé ⇒ un formulaire aux **trois champs vides** est accepté. Deux gardes
internes qui **fermaient** le catalogue des validateurs ont été mises à jour délibérément, et
celle qui vérifie la constructibilité `const` de chaque variante couvre désormais `requiredIf` —
elle prouve la propriété que vous teniez à préserver.

Un incident de campagne est consigné plutôt que tu : une première restauration a utilisé une
sauvegarde **antérieure au lot** et effacé des éditions — détecté par le sha, ré-appliqué,
injection rejouée.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
