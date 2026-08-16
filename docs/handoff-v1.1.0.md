# Handoff **v1.1.0** — fichiers retirés, motif facultatif, fenêtre à étapes

> **Tag à épingler : `v1.1.0`** — les trois manques du CR « formulaire », traités ensemble.
> Paquets porteurs : **`zcrud_core`**, **`zcrud_screen`**.
> ⚠️ **Une rupture douce** au §2 : un motif ne rend plus un champ obligatoire.

---

## 1. Un champ fichier retient ce que l'usager a retiré *(perte de données corrigée)*

Le champ n'écrivait que les fichiers **restants**. Migrer un site compilait parfaitement, la
liste des retirés devenait vide, et **plus rien n'était effacé** : documents et photos supprimés
par l'usager restaient en base indéfiniment, sans le moindre signal.

Votre remarque sur la résolution était juste, et la mesure l'a précisée : **zcrud résolvait déjà
les fichiers** — exactement comme votre moteur — mais **gardait la résolution pour lui**.
L'information existait, elle n'était simplement pas exposée.

Les fichiers retirés sont désormais émis à la soumission sous une **clé compagne**
`zRemovedFilesKey(nom)` (soit `'<nom>_removed'`), sous leur forme **résolue**. Contrat figé :

- la clé est **toujours présente** pour un champ fichier soumis, avec une liste **vide** si rien
  n'a été retiré — pas d'ambiguïté entre « rien retiré » et « information absente » ;
- jamais émise pour un champ en lecture seule ou masqué ;
- n'écrase jamais un champ homonyme que vous auriez déclaré.

**Deux cas trouvés au-delà de votre CR** : le **remplacement** d'un fichier sur un champ mono
était la même perte silencieuse (désormais couvert), et une transition d'upload n'est **pas**
un retrait (elle ne pollue pas la liste).

## 2. ⚠️ Un motif ne rend plus le champ obligatoire

`pattern` refusait une valeur vide : poser un motif rendait le champ obligatoire, ne pas le poser
perdait le verrou. Vous n'aviez pas d'issue.

L'incohérence était **interne**, et plus large que vous ne le pensiez : dans le même fichier,
`password` posait déjà explicitement l'inverse, avec ce raisonnement écrit — *« la contrainte de
présence est portée séparément par `required`, jamais implicitement ici »*. Nous l'avons
généralisé.

**Votre soupçon sur `email` est confirmé**, et il concernait en réalité **18 sites** :
`pattern`, `email`, `url`, `ip`, `creditCard`, `phone`, `numeric`, `integer`, `dateString`,
`minLength`, `maxLength`, `min`, `max`, `equal`, `notEqual`, et les formes contraintes
d'`address`/`percentage`. Tous acceptent désormais le vide.

**Non touchés, et pourquoi** : `required` (c'est sa raison d'être) ; `password` (déjà juste) ;
et surtout `match(refKey)`, la comparaison inter-champs — une confirmation vide face à un mot de
passe saisi doit continuer de refuser.

Un exemple de l'incohérence levée : `minLength(8)` refusait le vide alors que
`password(minLength: 8)` l'acceptait.

🔴 **Rupture douce** : si vous vous appuyiez sur l'effet de bord « motif ⇒ obligatoire »,
**ajoutez `ZValidatorSpec.required()`** sur ces champs. Si vous déclariez déjà `required`, rien
ne change.

## 3. Une fenêtre de formulaire peut être un assistant à étapes

`presentFormEdition` accepte `steps` (+ `stepperConfig`), et plus généralement un `bodyBuilder`
si vous voulez composer le corps vous-même.

**Correction à notre propre analyse** : nous pensions que `fields` et `steps` devaient s'exclure.
La mesure dit l'inverse — `ZEditionStep.fields` ne porte que des **noms**, donc `fields` reste le
**catalogue** et les deux ensemble sont le cas **nominal**. Les vraies exclusivités sont
`bodyBuilder` avec `steps`, et `steps` avec `sections` : assertion en développement, préséance
définie en production.

Le nombre d'étapes peut **dépendre des données** (votre cas « une étape par type de document
présent »), et le contrat de sortie ne change pas : valeurs validées et normalisées, `null` si
annulé.

**Le piège classique est couvert** : un champ **invalide dans une étape jamais visitée** empêche
la soumission — la validation itère sur le catalogue entier, jamais sur les seuls champs
affichés. Deux garde-fous s'y ajoutent : une étape nommant un champ inconnu, et un champ validé
**hors de toute étape** (qui produirait une fenêtre insoumissible sans message).

## 4. Impact sur votre code

- **Hôte passif** : rien à faire pour §1 et §3 (contre-témoins dédiés). Pour §2, vérifiez vos
  champs à motif sans `required` — c'est le seul changement de comportement.
- **Hôte ayant contourné** : si vous montiez `ZStepperEdition` à la main **avec une
  re-validation maison**, retirez le doublon — les erreurs seraient révélées deux fois.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run verify` RC=0 (14 gates,
40 paquets) · `melos run analyze` repo-wide RC=0.
Tests : `zcrud_core` **2065** (+37), `zcrud_screen` **267** (+8), `example` 108.

Treize injections R3 sur les deux lots, toutes rouges **par assertion** — dont celle qui rend le
point exact de votre CR : `Expected: [AppFile(connaissement.pdf)] / Actual: ['doc-42']`, la
différence entre un objet résolu et un simple identifiant.

Deux points d'honnêteté consignés plutôt que lissés : une garde s'est révélée **inerte** (un
transport non monté) et a été renforcée avant remesure ; et trois assertions d'absence étaient
**tautologiques** — le libellé d'un champ requis est un texte enrichi contenant un marqueur
invisible, si bien qu'une recherche exacte ne mord jamais. Corrigées et commentées.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
constitue la ligne de défense de cette release.
