---
title: zcrud_select
description: Présentateur de sélection riche (modal, recherche) pour zcrud, adossé au fork vendorisé awesome_select.
---

# zcrud_select

## Rôle

`zcrud_select` fournit `ZSmartSelectPresenter`, un présentateur riche pour
les familles `select`/`radio`/`checkbox`/`multiselect`/`relation`, adossé au
fork vendorisé `awesome_select`. Il rend un modal avec recherche optionnelle,
dont la forme est **adaptative** par défaut (`ZSelectModalShape.adaptive`) :
boîte de dialogue au-delà de 600 dp de largeur utile, feuille par le bas en
deçà — un critère mesuré, jamais un détecteur de plateforme. Les formes fixes
`bottomSheet`, `popupDialog` et `fullPage` restent déclarables. L'apparence de
référence est entièrement personnalisable via une chaîne
paramètre/jeton/référence.

## Quand l'utiliser

- Pour un rendu de sélection riche (modal, recherche) sur les champs de type
  choix, plutôt que le rendu natif du cœur.

## Quand ne pas l'utiliser

- Si le rendu natif du cœur suffit : sans enrôlement du présentateur, ces
  familles conservent leur rendu natif sans aucune régression.

## CRUD inline de relation : geste par geste {#relation-crud}

Sur un champ `relation` dont `ZRelationConfig.crudKey` résout un
`ZRelationCrudHandler`, le présentateur monte les affordances **Créer** (dans
la barre d'actions du modal) et **Modifier** / **Copier** (par option). Il ne
redéfinit **aucune** règle : il applique celle du port du cœur, à l'identique
du rendu natif.

- **Les trois gestes se gouvernent séparément** — `canCreate`, `canEdit`,
  `canCopy`. Enregistrer un handler n'ouvre pas les trois boutons.
- **Un geste refusé est absent**, jamais inerte : aucune icône, aucune action
  sémantique, rien à atteindre.
- **La lecture est défensive et fermante** : le présentateur consulte les droits
  par `offersCreate`/`offersEdit`/`offersCopy` (extension `ZRelationCrudOffer`),
  qui capte un getter d'hôte qui lève et **ferme** le geste concerné, seul.
- **Les droits sont lus une fois pour le rendu**, jamais dans le builder de
  chaque option : l'ACL de l'hôte reste hors du chemin de défilement
  ([AD-2](../concepts/invariants.md#ad-2)).
- Un handler dont **aucun** geste n'est offert n'ajoute **aucune surface** : le
  slot secondaire des options n'est pas monté.
- Un `choiceSecondaryBuilder` fourni par l'hôte l'emporte **toujours** : c'est
  le même slot, et c'est sa décision.
- Modifier et Copier suivent `enabled` — comme Créer. Les trois écrivent la
  sélection (auto-sélection du résultat), et une écriture sur un champ en
  lecture seule n'a pas de sens. C'est un **écart assumé** avec le rendu natif,
  qui ne conditionne pas ces deux actions à `readOnly`.

Le détail du contrat — frontière ACL, doctrine « absent, pas inerte », choix du
getter — est documenté côté port : voir
[zcrud_core](zcrud_core.md#relation-crud).

## Types clés

| Type | Rôle |
|---|---|
| `ZSmartSelectPresenter` | Présentateur riche, à injecter via `ZcrudScope.selectPresenter`. |
| `ZSelectTileSpec` | Surcharge par paramètre de l'apparence. |
| `ZSelectTileReference` | Point d'audit unique des valeurs de référence : dimensions, seuil adaptatif (600 dp), pagination des options, délai de garde d'un chargeur, et formes par défaut. Aucune couleur. |
| `ZSelectChoiceStyle` / `ZSelectModalShape` | Formes des options et du conteneur de modal. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_select/README.md) — installation, démarrage rapide, API complète.
- [zcrud_core](zcrud_core.md#relation-crud) — le port `ZRelationCrudHandler` et la gouvernance geste par geste.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
