# Handoff **v0.99.0** — le dernier mot sur le périmètre, et l'amplitude d'une plage

> **Tag à épingler : `v0.99.0`** — release **groupée** : deux CR traités ensemble.
> Paquets porteurs : **`zcrud_core`**, **`zcrud_screen`**. Additive : sans déclaration, rien
> ne change — **à une exception près, §3, qui corrige un seam jusqu'ici inerte**.

---

## 1. Le périmètre peut enfin être dit en Dart, pas seulement en clauses

Sur la voie `items`, vous remettiez une liste **déjà constituée**. Sur la voie `repository`, le
périmètre était **entièrement** dérivé de la requête : aucun point d'accroche entre la lecture
du dépôt et le rendu. La voie nominale n'était donc ouverte qu'aux écrans dont le périmètre est
exprimable en clauses Firestore — une minorité sur un parc métier, et **7 de vos 18 écrans
examinés** étaient refusés pour cette seule raison.

**Deux seams, tous deux opt-in :**

- **Un post-filtre écrit sur l'entité typée** — `ZItemFilter.of<T>((T e) => …)`, déclaré sur
  `ZListQueryPolicy` (ou un onglet), appliqué **après la lecture et avant la projection**. Le
  typage est celui que vous demandiez : votre prédicat reste écrit sur `T`, donc **un
  renommage de champ reste une erreur de compilation**, jamais une ligne qui disparaît en
  silence. Si le type déclaré ne correspond pas à celui du listing, l'entité est **écartée**
  (jamais élargie) et un `assert` nomme la faute.
- **Une disjonction** — `ZFilterGroup.any([...])` sur `ZDataRequest.filterGroups`. Elle
  débloque le cas le plus courant d'un workflow, celui que vous citiez : *« cette valeur **ou**
  ce champ absent »* — l'état initial est l'absence d'état. Votre onglet « En attente » ne se
  videra plus des dossiers fraîchement déposés.

**Une déclaration de périmètre n'est jamais ignorée en silence.** C'était le risque principal :
un seam actif en mémoire mais muet en pagination serveur aurait produit un écran qui *paraît*
fonctionner en montrant plus que prévu. Déclarer un post-filtre — ou une disjonction non
traduisible — **bascule** donc sur le chemin mémoire, comme `ZDelegatesSearch` en v0.97.0. La
garde porte sur ce qui est **réellement demandé au dépôt** (`limit == null`), pas sur
l'affichage.

Deux finesses utiles : un groupe **sans clause est inerte** (il ne vide rien et ne fait pas
basculer), et le groupe **voyage tout de même** dans la requête — un adaptateur capable de le
traduire y gagnera, un adaptateur qui l'ignore ne perd rien puisque le socle le ré-applique.

⚠️ **Le coût, dit franchement** : la bascule mémoire lit le jeu **non paginé**, à chaque
requête, pour toute la vie de l'écran. Le README porte le « quand ne PAS en déclarer ».
**Étiez-vous touché ? Non — rien de déclaré, rien de changé.**

**P3 (conditionner la vue corbeille) est différé** : `ZTrashMode` reste un tout-ou-rien, et
votre cas `cotation_role_settings` reste donc refusé. Il mérite son propre lot plutôt qu'un
ajout précipité à celui-ci.

## 2. Une plage de dates peut déclarer son amplitude

`ZDateConfig` gagne **`maxDays`** et **`minDays`**. Le refus se fait **à la sélection**, comme
dans le moteur que vous remplacez : la valeur n'est pas écrite, le champ **conserve et affiche**
la précédente, et le refus est annoncé au lecteur d'écran. Rien n'est reporté à la validation —
votre argument était juste, l'usager doit savoir quel champ corriger au moment où il choisit.

🔴 **Sémantique de comptage — à convertir chez vous.** Nous retenons les **jours couverts,
bornes incluses** : `maxDays: 7` accepte « 1er → 7 janvier » et refuse « 1er → 8 ». C'est le
nombre que l'usager **lit**, donc valeur déclarée = valeur affichée — là où le legacy comparait
des intervalles puis annonçait `maxDays + 1`. L'unité l10n **porte** le comptage (« jours
(bornes incluses) ») : le message et la documentation ne peuvent pas diverger.

**Conversion** : `maxDays_zcrud = maxDays_legacy + 1`. Votre fenêtre de dépotage devient
`maxDays: 45`.

Les déclarations absurdes (`maxDays < 1`, `minDays > maxDays`) sont ignorées défensivement
plutôt que de faire échouer un formulaire.

## 3. ⚠️ Corrigé — les bornes d'une plage étaient déclarées mais jamais appliquées

Constat trouvé en chemin, **que votre CR ne signalait pas** : le dispatcher ne transmettait pas
les bornes à la famille `dateRange`. Autrement dit, `minDateIso`, `maxDateIso`, `firstDateKey`
et `lastDateKey` étaient **inertes** pour les plages de dates — déclarés, documentés, sans
aucun effet. Aucun test ne les couvrait.

Votre critère de recette « les bornes continuent de jouer » était donc **faux avant** ce lot.
C'est corrigé et gardé.

**Hôte ayant compensé** : si vous borniez ces plages vous-même (sélecteur pré-contraint,
validateur maison), votre compensation **s'additionne** désormais au socle — retirez-la.
Surfaces concernées : `ZDateRangeFieldWidget` via `ZFieldWidget`, donc `DynamicEdition`,
`ZFormOnly` et `ZCrudScreen`.

## 4. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **2008** (baseline 1959, +49), `zcrud_screen` **244** (baseline 230, +14).

Quinze injections R3 sur les deux lots, **toutes rouges par assertion** — dont celles qui
prouvent les points les plus glissants : bascule retirée (`limit` repasse à `2`, une entité
exclue réapparaît), filtrage appliqué **après** la troncature (une page à 1 ligne au lieu de 2),
disjonction ramenée à une conjonction (listing vidé), et borne incluse cassée. Restaurations par
copie vérifiées par sha256, résidus prouvés absents par grep négatif.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
