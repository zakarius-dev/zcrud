# Handoff **v0.63.0** — l'astérisque requis revient, le champ date devient un champ

> **Tag à épingler : `v0.63.0`**
> 🔴 **Changement visible pour TOUS** : les champs `date` / `time` / `dateTime` / `dateRange` ne sont
> plus des boutons, ce sont des champs décorés (§ 2). Échappatoire en un paramètre.
> Aucun paquet nouveau (38).

---

## 1. ① L'astérisque requis — une régression que NOUS avions causée

Votre constat est exact, et sa cause l'est aussi : le rendu **natif** portait l'astérisque, le
présentateur ne le rendait pas. Donc **enrôler `zcrud_select` — ce que nous recommandons depuis
v0.61.0 — faisait disparaître l'indicateur**.

🔴 **C'est la deuxième régression de cette classe sur ce seam en 24 h.** La première était le
`crudHandler` (Créer / Modifier / Copier), que le DTO ne transportait pas. Le motif est toujours le
même, et il mérite d'être nommé : **le DTO porte la donnée, le présentateur ne la lit pas.**

Livré : l'astérisque sur la tuile **et** sur le titre du modal (aux **trois** sites — mono, multi
avec recherche, multi sans), plus le canal d'accessibilité `Semantics.isRequired`.

### 🔵 Nous n'avons pas pu réutiliser `ZFieldLabel`, et ce n'est pas un renoncement
Vous le demandiez, et c'était la bonne intuition. **Mesuré, deux blocages indépendants** : il
**impose** un style de base — le libellé passerait de w400 à **w500** sur la tuile, et de **22 à 16
points** sur le titre du modal, qui cesserait d'être un en-tête ; et il **re-dérive** le libellé de
`field.label ?? field.name`, ignorant le libellé **résolu** que le seam transporte.
La recette est donc reprise à la lettre (glyphe, `ExcludeSemantics`, couleur par rôle) et **gardée
contre la dérive** par un test qui compare notre astérisque à celui de `ZFieldLabel` dans le même
thème. Suite identifiée côté cœur : un mode « style ambiant » sur `ZFieldLabel`, après quoi le
helper local disparaît.

### 🔴 Le vrai résultat du lot : quatre autres écarts natif ↔ présentateur, mesurés
Non corrigés, et signalés parce que vous les rencontrerez : `field.hintText`, `field.helperText`,
`field.prefix`, `field.suffix` ne sont **jamais lus** par le présentateur (grep négatif montré) ;
`isLoading` est reçu et **non affiché** alors que le natif montre un chargement. **Toutes ces données
sont déjà atteignables** — même motif que ci-dessus.

### 🔵 Et un constat qui retourne le problème
En **natif**, l'astérisque n'est porté que par la voie `DropdownButtonFormField` : **6 des 8 voies de
rendu** de `select`/`relation` le perdaient **déjà** (radios, cases, chips multi, les deux
déclencheurs de sélection). Après ce lot, `zcrud_select` couvre l'indicateur sur **plus** de chemins
que le rendu natif qu'il remplace. La correction du cœur est identifiée, pas encore faite.

## 2. 🔴 ② Le champ date devient un champ — changement visible pour tout hôte

Vous aviez raison sur l'incohérence : un `OutlinedButton` là où toutes les autres familles sont des
champs décorés. Corrigé — et **étendu à `dateRange`**, que votre CR ne nommait pas mais qui portait
le **même** `OutlinedButton` : le corriger d'un seul côté aurait recréé l'incohérence qu'il ferme.

Nouveau déclencheur interne : `Semantics → ConstrainedBox(48) → InkWell → InputDecorator`. Donc
libellé flottant, astérisque, et les jetons `fieldFillColor` / `fieldBorderColor` /
`fieldFocusedBorderColor` de v0.60.0 s'y appliquent **sans une ligne de code nouvelle**. La croix
d'effacement et toute la logique de sélection (bornes, clamp, annulation) sont **inchangées**.

**Échappatoire** : `decorated` (par champ) > `ZcrudTheme.dateFieldDecorated` (jeton, absent du repli)
> référence (`true`). `decorated: false` restitue exactement le rendu legacy — le code n'a pas été
réécrit, il est conservé. L'ordre de priorité est prouvé mordant.

### L'accessibilité, mesurée avant/après plutôt que supposée
Le risque réel était de **doubler** l'annonce (l'ancien `Semantics(label:)` plus le libellé que porte
un `InputDecorator`). Sonde posée, mesurée, retirée : **même nombre de nœuds, mêmes `label` /
`value` / `button` / `enabled`** — ni perte, ni doublon. Unique différence voulue : `isRequired`
passe à vrai sur un champ requis, et reste **nul** sinon, pour que le nœud d'un champ non requis
soit bit pour bit celui d'avant.

🔵 **Convergence non concertée** : les deux lots, écrits en parallèle dans deux paquets, ont retenu
**le même canal** `Semantics.isRequired`. Personne ne le leur avait dit.

## 3. Votre ligne

| Vous êtes… | Geste |
|---|---|
| 🔴 **tous** | **vos champs date changent d'apparence** : bouton → champ décoré, avec libellé flottant et astérisque. Échappatoire : `decorated: false` par champ, ou le jeton pour toute l'app |
| **DODLP** | ① l'astérisque revient sur vos `select` enrôlés — **retirez le hack** si vous aviez accolé ` *` au libellé ② vos champs date deviennent cohérents avec le reste du formulaire, et consomment enfin vos jetons de champ |
| **hôte enrôlant `ZSmartSelectPresenter`** | vous couvrez désormais l'astérisque sur **plus** de chemins que le rendu natif |
| **hôte qui compensait** | si vous aviez enveloppé votre champ date pour lui donner l'air d'un champ, **retirez la compensation** — sinon double décoration |

🟢 **Tripwire recommandé** : un test qui affirme votre compensation actuelle (hack d'astérisque ou
enveloppe de date) — il rougira à l'adoption et vous désignera les lignes à supprimer.

## 4. Vérification

`melos generate` **RC=0**, aucun `.g.dart` modifié · `melos analyze` **RC=0** · `melos verify`
**RC=0** — rejoués **après** le bump.

`zcrud_core` **1412** (+18) · `zcrud_select` **102** (+19) · jumelles rejouées vertes : `zcrud_study`
1521, `zcrud_markdown` 504, `zcrud_intl` 183, `zcrud_geo` 174, `zcrud_media` 31,
`zcrud_field_extras` 26 · `example` 97. **0 erreur, 0 avertissement.**
Les **83 gardes préexistantes** de `zcrud_select` sont restées vertes **sans une seule retouche**.

**R3 — 23 injections, toutes qualifiées**, sha avant **et** après chacune, restauration par copie,
résidus : greps négatifs montrés.

🟢 **Deux corrections d'honnêteté que les agents ont faites sur leur propre travail** :
* une garde était **fausse** — elle mesurait l'astérisque de la tuile restée montée *derrière* le
  modal, au lieu de l'en-tête du modal. Reportée sur le bon nœud ;
* trois gardes rougissaient par `StateError` au lieu d'une assertion : **durcies**, et l'injection
  rejouée. Un rouge d'infrastructure n'est pas une preuve de morsure.

🔴 **Le piège des 48 dp, mesuré une fois de plus** : sous injection du plancher à zéro, la hauteur
**rendue** reste 56. Une garde écrite sur `getSize()` serait passée **verte**. La garde porte donc
sur la **contrainte**, pas sur la taille — c'est la troisième fois cette semaine que ce piège se
présente.

🟡 **Un aveu de l'agent, repris tel quel** : sa garde « astérisque décoratif » ne rougit que si **les
deux** barrières d'exclusion sémantique tombent — elle mesure une conjonction, et n'est pas
présentée comme une garde de `ZFieldLabel`.

⚠️ **Notre CI reste à l'arrêt (facturation).** Vérifications locales uniquement.

## 5. Non couvert

* Les quatre écarts natif ↔ présentateur du § 1 (hint, helper, prefix, suffix, chargement) —
  mesurés, listés, non corrigés.
* Les **6 voies de rendu sur 8** qui perdent l'astérisque **en natif**, dans `zcrud_core` — le
  déclencheur décoré livré ici leur est directement réutilisable. Identifié, non fait.
* `dateRange` n'a toujours **aucune classe de configuration** (pas de bornes) — hors sujet apparence.
* Risque non testé : champ non requis **avec** valeur ⇒ icône de décoration **plus** croix
  d'effacement — débordement possible en largeur très contrainte.
* Dettes antérieures : cf. v0.62.0, v0.61.0, v0.60.0 (dont ses quatre axes visibles).
