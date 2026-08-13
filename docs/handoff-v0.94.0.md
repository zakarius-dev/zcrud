# Handoff **v0.94.0** — la fiche de détail devient un geste de ligne

> **Tag à épingler : `v0.94.0`** — lève le **dernier bloquant d'adoption** signalé par la
> deuxième mesure du pilote sur écran réel, plus deux aspérités. Paquet porteur :
> **`zcrud_screen`** uniquement (`zcrud_core` et `zcrud_list` ont un diff vide — vérifié).
> Release **strictement additive** : aucun défaut ne change.

---

## 1. La fiche de détail n'est plus un mode d'écran

`ZScreenMode.details` désactivait la création **et** la corbeille pour tout l'écran. C'était une
erreur de granularité de notre part : la parité attendue est un écran **complet** — on crée, on
met à la corbeille, on restaure — **dont le tap sur une ligne ouvre la fiche**. Les deux ne sont
pas exclusifs, et c'est le cas le plus courant.

Vos deux propositions n'étaient pas concurrentes, elles sont les deux faces du même geste : les
voici toutes les deux.

```dart
// (a) la déclaration : écran complet, le tap ouvre la fiche
ZCrudScreen<Consignee>(
  title: 'Consignataires',
  source: ZCrudSource.repository(repo),
  registry: registry,
  detailsEnabled: true,          // création et corbeille restent offertes
)

// (b) le rappel qu'elle rend disponible, depuis n'importe quelle carte
final voir = zCrudDetailsOpener(context, consignee);   // null si `view` refusé
```

Plus `canOpenDetails` / `openDetails` / `detailsOpener` sur `ZCrudScreenActions`, symétriques de
ce qui existait pour l'édition.

**`ZScreenMode.details` est strictement intact** — vos 23 fichiers qui le déclarent ne bougent
pas. Il reste le mode « écran de consultation ». Les trois conditions que vous aviez pointées
(corbeille l. 876, création l. 2414) sont inchangées : elles testent toujours le mode, et
`full + detailsEnabled` **est** le mode `full`.

## 2. Retour vers l'édition depuis la fiche — une bascule, pas une réouverture

`ZCrudEditionScope` porte désormais un **`onEdit` nullable**, gouverné par `ZCrudAction.update` :
`null` quand l'édition n'est pas permise, pour que vous **ne dessiniez pas** un bouton mort —
même contrat que `zCrudEditionOpener`.

L'invoquer **bascule la surface courante** : aucune route n'est fermée, le `State` de votre
formulaire survit (mesuré : un seul montage après bascule), ses valeurs aussi, seul le titre
passe de « lecture » à « modification ». C'est le geste que vos utilisateurs attendent : on
consulte, puis on décide d'éditer sans refermer.

**Réserve, dite franchement** : dans le formulaire **dérivé** (celui que zcrud construit depuis
le registre), les champs sont remontés à la bascule. Le socle décide en `late final` qu'une fiche
en lecture n'alloue ni `TextEditingController` ni `FocusNode` — une optimisation qui, sans
remontage, laisserait « Enregistrer » agir sur des champs inertes. Coût : la position de
défilement. Votre formulaire à vous, passé par `editionBuilder`, n'est pas concerné : il survit
entièrement.

## 3. Coloration de ligne — sur l'entité, jamais sur la cellule

`ZCrudScreen.rowColor` reçoit **l'entité typée** et rend un `ZRowTint`. Votre argument est repris
tel quel : décider sur `T` plutôt que sur des cellules formatées fait d'un renommage de colonne
une **erreur de compilation**, au lieu d'une couleur qui disparaît en silence.

⚠️ **Une information portée par la seule couleur est inaccessible** — invisible pour un daltonien,
muette pour un lecteur d'écran. `ZRowTint` porte donc la couleur **et** son libellé dans le même
objet : un seul seam à déclarer, donc pas de doublage oublié par distraction. Le libellé est
annoncé en `Semantics` ; le README montre le doublage visible (icône ou pastille) attendu à côté.

Aucun contrat de layout n'a bougé : la teinte s'insère en amont, l'écran étant déjà propriétaire
des tuiles qu'il fait descendre. `zcrud_core` et `zcrud_list` sont inchangés.

## 4. Impact sur votre code

- **Hôte passif** : rien à faire — sans `detailsEnabled`, sans `rowColor`, l'écran est identique
  à la v0.93.0 (contre-témoins dédiés).
- **Hôte ayant compensé** — trois cas, à retirer :
  - vous **dupliquiez l'écran** ou basculiez `mode` selon le rôle pour obtenir la consultation
    sans perdre la corbeille : `detailsEnabled` remplace ce montage ;
  - vous portiez **votre propre bouton « Modifier »** dans la fiche : vous en dessineriez deux ;
  - vous **coloriez vos lignes** vous-même : les deux teintes se superposeraient.
- **Hôte qui _implémente_ `ZCrudScreenActions`** (rare — l'interface est faite pour être
  consommée) : trois membres à compléter.

## 5. État des vérifications

`melos run generate` RC=0 (zéro `.g.dart` modifié) · `melos run analyze` RC=0 ·
`melos run verify` RC=0 (14 gates, 40 paquets, graphe acyclique, `CORE OUT=0`).
`zcrud_screen` : **194 tests** (baseline 173, +21), analyze strict à zéro issue.
`zcrud_core` / `zcrud_list` : diff vide, donc non re-testés — leurs baselines de la v0.93.0
tiennent (1949 et 69).

Dix injections R3, toutes rouges **par assertion** (dont la requête de rendu comparée à
elle-même pour prouver que le builder de couleur n'entre pas dans l'égalité — le piège qui aurait
cassé la mémoïsation). Restaurations par copie vérifiées par sha256, résidus prouvés absents par
grep négatif.

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
ci-dessus constitue la ligne de défense de cette release.

## 6. Ce que cela débloque

Vous annonciez l'adoption dès cette CR levée. Pour mémoire, votre propre mesure : le pilote passe
de 137 à 76 lignes, vos **1411 lignes de coquilles** deviennent supprimables (≈ −900 lignes
nettes sur 29 écrans), et vos quatre derniers écrans legacy peuvent être migrés directement sur
`ZCrudScreen` plutôt que sur des coquilles à jeter ensuite.

Votre garde qui **fige l'écart n°1** va rougir : c'est le signal de bascule que vous attendiez.
