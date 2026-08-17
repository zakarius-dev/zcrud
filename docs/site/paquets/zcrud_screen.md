---
title: zcrud_screen
description: Écran CRUD assemblé et déclaratif — liste, recherche, onglets, édition, fiche de détail, corbeille, gouvernance par ligne, sélection et export.
---

# zcrud_screen

## Rôle

`zcrud_screen` fournit `ZCrudScreen<T>` : la pièce qui **assemble** les briques
zcrud existantes (`DynamicList`/`ZTabbedList`, `ZRowAction`, `presentEdition` +
`ZPresentationPolicy`, `DynamicEdition`/`ZFormController`, `ZRepository` +
`ZDataRequest.deletedScope`) en un écran CRUD complet, à partir d'une
déclaration (`title` + `ZCrudSource`). `ZCrudScreen` est à `DynamicList` ce que
`DynamicEdition` est aux champs : il prend une déclaration et rend un écran
fonctionnel, sans que l'assemblage ne monte jamais dans le cœur
([invariant AD-1](../concepts/invariants.md#ad-1)).

L'écran est **bâti sur `zcrud_ui_kit`** : la coquille de page
(`ZPageScaffold`/`ZSearchableAppBar`, actions `ZAppBarAction` avec menu de
débordement, recherche `ZAppBarSearchConfig`), la **confirmation** des gestes
destructifs (`showZConfirmDialog`, `ZConfirmTone.destructive`) et la
**notification** d'échec des actions de ligne (`ZToaster`/`ZToasterScope`)
viennent du socle — aucune n'est réinventée ici. Les états vide / chargement /
erreur du listing restent ceux de `DynamicList` (aucun état doublé).

## Quand l'utiliser

- Pour un écran « liste dont on crée, édite et met à la corbeille les
  éléments » — le cas nominal d'un paquet qui s'appelle zcrud — sans réécrire
  le câblage écran par écran.
- Pour les variantes en consultation, **par déclaration** :
  `mode: ZScreenMode.details`, `canCreate: false`,
  `trash: ZTrashMode.none`, ou une source `ZCrudSource.items(rows)` sans
  rappels d'écriture.
- En cohabitation avec un chemin de données hôte (`ZCrudSource.items` +
  rappels `onSave`/`onSoftDelete`/`onRestore`).

## Quand ne pas l'utiliser

- Pour une vue qui n'est pas une liste (carte géographique, organigramme) :
  composez directement `DynamicList`/`ZListController`/`presentEdition` —
  l'assemblage est mince, descendre d'un cran ne fait rien perdre.

## Une déclaration minimale, et ses conditions

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

Widget buildConsigneesScreen(
  ZRepository<Consignee> repo,
  ZcrudRegistry registry,
) {
  return ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.repository(repo),
    registry: registry,
  );
}
```

Cette déclaration tient en cinq lignes parce que **trois conditions** sont
réunies. Ôtez-en une et elle s'allonge : ce n'est pas un défaut de
l'assemblage, c'est le prix de ce qu'il ne peut plus dériver.

| Condition | Ce qui est dérivé | Si elle n'est pas remplie |
|---|---|---|
| Le modèle est **enregistré au registre** (`@ZcrudModel` + registrar appelé au bootstrap) | champs de liste et de formulaire, projection en cellules, reconstruction d'entité | déclarer `listFields`/`formFields`, `cellsOf` à la main |
| La source est un **`ZRepository`** | lecture paginée, recherche, corbeille, observation des mutations | `ZCrudSource.items` + les rappels d'écriture correspondants |
| Les lignes sont rendues par la **tuile générique** | l'affichage d'une ligne | un `itemBuilder` — c'est-à-dire tout le code de votre carte métier |

Deux conséquences à connaître avant de compter les lignes gagnées :

- une **carte métier** reste du code de l'application ; sur un écran à carte,
  l'assemblage n'apporte pas la brièveté mais le **cycle** (édition, corbeille,
  recherche, gouvernance, notifications) qu'il n'y a plus à recoudre ;
- le layout par défaut délègue à un **backend de rendu** que le cœur
  n'embarque pas : sans renderer injecté
  (`ZcrudScope(listRenderer: const ZSfDataGridRenderer())`, paquet
  [zcrud_list](zcrud_list.md)), l'écran lève une `ZScopeError` explicite au
  premier rendu de la liste.

## Autorisation : refus par défaut

Sans ACL déclarée — ni `ZCrudScreen(acl:)`, ni `ZcrudScope(acl:)` — l'écran
n'offre **aucun** geste, et `ZCrudAction.view` refusé bloque l'écran entier :
il rend un état « accès refusé », sans bouton ni recherche, et **n'interroge
pas le dépôt**. L'ouverture totale reste possible, mais **déclarée** :
`ZCrudScreen(acl: const ZAllowAllAcl())`. Le paramètre de l'écran l'emporte sur
le scope ([invariant AD-16](../concepts/invariants.md#ad-16)).

## Modes d'écran et fiche de détail

`mode` (`ZScreenMode`) décide de ce que l'écran **entier** est ; `detailsEnabled`
ajoute la fiche à un écran complet.

| Déclaration | L'écran offre |
|---|---|
| `mode: ZScreenMode.full` (défaut) | création, édition, corbeille, selon l'ACL et la source |
| `mode: ZScreenMode.full` + `detailsEnabled: true` | tout ce qui précède **et** la fiche de chaque ligne |
| `mode: ZScreenMode.details` | consultation seule : ni création, ni corbeille ; chaque ligne ouvre sa fiche |
| `mode: ZScreenMode.locked` | consultation verrouillée : rien ne s'ouvre (`detailsEnabled` y est ignoré) |

La fiche n'est pas dérivée des colonnes : elle rend **tous** les champs du
formulaire, en lecture seule. Le retour vers l'édition reste offert si l'ACL
accorde `ZCrudAction.update` — `ZCrudEditionScope.onEditOf(context)` rend ce
geste (ou `null`), et **bascule la surface courante sans la refermer** :
aucune route n'est fermée ni rouverte, l'état du formulaire de l'application
survit, seul le titre change. Un formulaire applicatif lit
`ZCrudEditionScope.readOnlyOf(context)` pour se rendre lui-même en lecture.

## Corbeille à trois gestes

`trash` (`ZTrashMode`) décide si la corbeille **existe** ; `trashPolicy`
(`ZTrashPolicy`) décide des gestes qu'elle **offre** : mise à la corbeille,
restauration, suppression définitive. La purge n'apparaît que si la source la
déclare — dépôt appliquant le mixin `ZPurgeable` du cœur, ou
`ZCrudSource.items(onPurge:)`. Sans l'un ni l'autre : aucun bouton, aucune
erreur, la corbeille garde ses deux autres gestes.

Les gestes destructifs passent par la confirmation du socle
(`confirmDestructive`, `true` par défaut) ; annuler n'écrit rien. La
restauration, non destructive, n'est jamais confirmée. `trashRowActions`
déclare les actions de ligne propres à la vue corbeille — `rowActions` ne
s'applique qu'à la vue vivante. `trashCount` (`ValueListenable<int>?`) affiche
une pastille de comptage sur le bouton d'accès, et
`ZTrashPolicy(visibleWhenEmpty: false)` évite un bouton qui mène à une
corbeille vide.

## Gouvernance par ligne

`rowAcl` (`ZRowAclResolver<T>`) reçoit l'entité d'une ligne et rend ses droits
effectifs — une seule déclaration gouvernant la vue vivante **et** la
corbeille, les actions rendues en boutons **comme** en menu :

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource<Dossier>.repository(repo),
  registry: registry,
  rowAcl: (dossier) => dossier.cloture
      ? const ZRowPermissions.locked(reasonKey: 'dossierCloture')
      : const ZRowPermissions.unrestricted(),
);
```

Le résolveur **restreint, il n'élargit jamais** : sa composition avec l'ACL de
l'écran (ou du scope) est une intersection. La présentation d'une action fermée
suit la nature du refus — un **droit** refusé obéit à `actionAclMode`
(`hide` masque, `disable` montre inerte avec son motif), tandis qu'une action
simplement **inapplicable** à la ligne (`ZRowAction.enabledFor`) reste toujours
rendue, inerte et motivée.

## Requête, onglets et recherche

`query` (`ZListQueryPolicy`) porte le **tri par défaut**, les **filtres
permanents**, la **taille de page**, et la sémantique de la recherche —
`searchScope` (les colonnes interrogées) et `searchFolding` (ce qui est ignoré
en comparant). Sans déclaration, les requêtes émises sont exactement celles
d'un écran non gouverné : aucun filtre, aucun tri, aucune limite, recherche sur
les seuls champs `searchable`.

En mode **onglets** (`tabs`, `ZListTab`), un onglet porte son filtre de
catégorie, ses **droits** (`acl`), ses **intitulés de formulaire** (`titles`) et
son **compteur** (`countOf`), appliqués à l'onglet actif. La cascade
**onglet > écran > scope** est une intersection : un onglet ne peut pas rouvrir
un geste refusé plus haut. La politique de requête reste lisible par les pages
via `ZListQueryPolicy.of(context)`, et se compose avec le filtre de catégorie
— jamais à sa place.

Depuis n'importe quelle vue posée sous l'écran,
`ZCrudScreenScope.maybeOf(context)` donne accès à `sortBy` et `filterBy` : un
tri demandé remplace le tri par défaut, des filtres demandés s'**ajoutent** aux
filtres permanents, qu'aucun appel ne peut lever.

`tabsStore` (`ZListTabsStore`) fait **survivre l'onglet actif et le défilement
de chaque onglet** à la fermeture de l'écran — deux choses, pas une : un onglet
retrouvé en haut de sa liste n'a restitué que la moitié du geste. Le paquet ne
connaît pas le stockage, seulement le port (quatre méthodes synchrones qui ne
lèvent jamais, même patron que `ZSectionCollapseStore`). L'écriture est **par
emplacement**, jamais par portée entière : mémoriser l'offset d'un onglet
n'efface ni l'index, ni l'offset du voisin. La **clé de portée est dérivée** —
type d'entité, identité de l'écran (`collectionId`, à défaut le titre) et jeu
d'onglets —, si bien que deux écrans ne se marchent jamais dessus et qu'un
changement de jeu d'onglets invalide naturellement l'ancienne préférence
(`tabsScopeKey` reste la voie d'échappement). Lecture tolérante
([AD-10](../concepts/invariants.md#ad-10)) : index absent ou **hors bornes** ⇒
premier onglet, offsets absents ⇒ zéros, store qui lève ⇒ traité comme absent.
Sans `tabsStore`, ni lecture, ni écriture, ni widget supplémentaire.

## Actions d'app-bar dépendantes de l'état

`actions` (`List<ZAppBarAction>`) est le bon défaut : une action déclarée en
**données** porte son `semanticLabel`, sa cible tactile et son débordement, là
où le chemin déprécié `appBarActions` transmet des widgets muets pour un
lecteur d'écran. Mais une liste figée ne sait exprimer qu'une action
**constante**.

`actionsBuilder` la complète — **exclusif** avec elle (assertion au montage) —
et rend lui aussi des `ZAppBarAction`, jamais des widgets : la conditionnalité
sans rien perdre de l'accessibilité. Il reçoit un `ZAppBarActionsContext`
portant l'**ACL résolue** (restriction de l'onglet actif déjà composée), le
**tabIndex**, l'**itemCount** de la vue courante, `isEmpty` et `isTrashView` —
et rien de l'état interne de l'écran.

Le builder est réévalué quand l'onglet, le comptage ou la portée changent, et
**seule la coquille est rebâtie** ([AD-2](../concepts/invariants.md#ad-2)) : le
corps est construit une fois, au-dessus des abonnements, et transmis tel quel.
Le comptage vient de `entitiesInViewListenable`, dont le notifieur n'est créé
qu'au premier accès — **un écran sans `actionsBuilder` ne paie rien**.

## Sélection multiple et actions de masse

`selection` (`ZSelectionPolicy`) câble la case à cocher par ligne et la barre
d'actions de masse, qui apparaît au premier élément coché. `null` — le défaut —
laisse l'écran strictement inchangé. Les actions assemblées suivent la vue
(corbeille sur les vivants ; restauration et suppression définitive en
corbeille) et sont gouvernées par la **même** voie que les actions de ligne :
une entité que `rowAcl` ou `enabledFor` n'admet pas est **exclue du lot avant
toute écriture**. Un lot partiellement en échec le dit — succès, échecs,
éléments écartés, et le nom des éléments en échec ; le `ZBatchReport` complet
est remis à l'application par `ZSelectionPolicy.onReport`. `batchActions`
ajoute les actions de masse de l'application après les actions assemblées.

## Export du listing

`export` (`ZExportPolicy`) offre l'export de la liste : un format déclaré = une
entrée dans le menu de débordement de l'app-bar. **Aucun format par défaut** —
sans politique, ni entrée, ni menu, ni dépendance : l'écran ne connaît que le
port `ZListExporter` du cœur et ne dépend d'**aucun** paquet d'export.

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource<Dossier>.repository(repo),
  registry: registry,
  export: ZExportPolicy(
    exporters: const <ZListExporter>[ZCsvListExporter()],
    onExported: (context, file) => maPlateforme.enregistrer(file),
  ),
);
```

Ce qui est exporté est **ce qui est affiché** : les lignes réellement listées
(tri, filtres, recherche et vue déjà appliqués), avec les colonnes dérivées du
schéma et leurs valeurs **formatées**. Les ornements d'écran — numéro d'ordre,
cases à cocher, boutons — n'entrent jamais dans le fichier. Une sélection en
cours restreint l'export aux seuls éléments cochés. Le fichier va où
l'application décide (`onExported` reçoit octets, nom suggéré et type MIME).
Les exporteurs concrets vivent dans [zcrud_export](zcrud_export.md) (CSV,
Excel) et [zcrud_export_pdf](zcrud_export_pdf.md) (PDF).

## Menus, appui long et coloration

Les actions de ligne se rendent en boutons ou en menu
(`rowActionsPresentation`, `inlineActionLimit`). L'appui long étant réclamé par
plusieurs fonctions, son propriétaire se **déclare** une fois pour l'écran —
`longPressOwner` (`ZRowLongPressOwner`) : menu contextuel (défaut), ouverture
de la **sélection multiple**, ou copie de cellule du backend de rendu. Un choix
unique et déclaré, plutôt que trois réglages qui permettraient d'en désigner
deux à la fois.

`rowColor` teinte les lignes selon un état métier, la décision se prenant sur
l'**entité typée** — jamais sur une cellule formatée :

```dart
ZCrudScreen<Convocation>(
  title: 'Convocations',
  source: ZCrudSource<Convocation>.repository(repo),
  registry: registry,
  rowColor: (context, c) => c.enRetard
      ? ZRowTint(
          Theme.of(context).colorScheme.errorContainer,
          semanticLabel: 'convocation.enRetard',
        )
      : null,
);
```

**Aucune couleur n'est codée dans zcrud** : la teinte vient entièrement du
thème de l'application, d'où le `BuildContext` passé au seam. Sans `rowColor`
— ou pour une ligne rendant `null` — le rendu est strictement inchangé, pas un
widget de plus dans l'arbre. Une information portée par la **seule** couleur
étant perdue pour un usager daltonien, à l'impression et pour un lecteur
d'écran, `ZRowTint.semanticLabel` la rend audible ; la rendre visible autrement
(icône, pastille, mot d'état) reste l'affaire de la tuile
([invariant AD-13](../concepts/invariants.md#ad-13)).

## Navigation de l'application {#navigation}

L'écran **construit** le `Scaffold` : il relaie donc `drawer` et `endDrawer` au
socle, tels quels, pour qu'une application à modules puisse attacher son menu à
un écran assemblé sans imbriquer un second `Scaffold`.

```dart
ZCrudScreen<Navire>(
  title: 'ships',
  source: ZCrudSource<Navire>.repository(repo),
  drawer: MonMenuLateral(), // votre menu, votre ACL, votre responsive
);
```

**Le menu appartient à l'application** : le paquet n'en fournit aucun, n'impose
aucun comportement responsive et n'y applique aucune règle de droits.

**Le bouton d'ouverture est inséré par Material**, pas par zcrud : il n'apparaît
que si la place du `leading` est libre (`automaticallyImplyLeading`, non
réimplémenté ici).

| Situation | Bouton de menu | Tiroir atteignable ? |
|---|---|---|
| Vue normale, pas de `leading` | inséré par Material | oui (bouton + glissement) |
| `leading:` déclaré par l'hôte | absent — le `leading` prime | oui, par glissement depuis le bord |
| Vue **corbeille** | absent — le bouton de retour occupe la place | oui, par glissement depuis le bord |
| **Recherche ouverte** | absent — le bouton de fermeture occupe la place | oui, par glissement |

La règle de la corbeille est **figée et gardée** : sortir de la corbeille prime
sur changer de module. L'état **« accès refusé » porte lui aussi le tiroir** —
c'est l'écran où la navigation manque le plus, l'usager n'y ayant ni contenu ni
sortie. Sans `drawer`/`endDrawer` déclarés, le rendu est strictement celui
d'avant leur introduction : aucun tiroir, aucun bouton.

## Types clés

| Type | Rôle |
|---|---|
| `ZCrudScreen<T>` | Écran CRUD assemblé et déclaratif. |
| `ZCrudSource<T>` | Source déclarative : `.repository(…)` ou `.items(…)` (avec `onSave`/`onSoftDelete`/`onRestore`/`onPurge`). |
| `ZScreenMode` | Portée de l'écran : `full` / `details` / `locked`. |
| `ZTrashMode` / `ZTrashPolicy` | Existence de la corbeille / gestes qu'elle offre. |
| `ZListQueryPolicy` | Tri, filtres permanents, pagination et sémantique de recherche du listing. |
| `ZListTabsStore` | Persistance de l'onglet actif **et** du défilement par onglet — port neutre, écriture par emplacement, clé de portée dérivée. `ZInMemoryListTabsStore` sert les tests. |
| `ZAppBarActionsBuilder` / `ZAppBarActionsContext` | Actions d'app-bar dépendantes de l'état, rendues en données (`ZAppBarAction`). Exclusif avec `actions`. |
| `ZRowAclResolver<T>` / `ZRowPermissions` | Droits effectifs d'une ligne, en intersection avec l'ACL de l'écran. |
| `ZSelectionPolicy` | Sélection multiple et barre d'actions de masse. |
| `ZExportPolicy` | Formats d'export offerts et remise du fichier à l'application. |
| `ZRowTint` | Teinte d'une ligne, doublée d'un libellé annoncé. |
| `ZCrudTitles` | Porte-titres de la surface d'édition (`create`/`copy`/`update`/`read`). |
| `ZCrudScreenScope` / `ZCrudScreenActions` | Accès, depuis une tuile, au cycle d'édition et de consultation **de l'écran**. |
| `ZCrudEditionScope` | Transport de la lecture seule et du retour vers l'édition jusqu'au formulaire applicatif. |
| `ZCrudEditionBuilder<T>` | Formulaire applicatif, voie d'échappement de l'édition dérivée. |
| `ZCrudItemBuilder<T>` | Tuile de liste (reçoit l'entité `T`), voie d'échappement du rendu par défaut. |

## Cas limites

- **Une tuile ouvre le cycle de l'écran, pas le sien.** Depuis une carte
  descendante de l'écran, `zCrudEditionOpener(context, entity)` et
  `zCrudDetailsOpener(context, entity)` rendent le rappel d'ouverture — ou
  `null` quand le geste n'est pas possible, pour qu'on ne dessine pas un bouton
  mort. La surface ouverte est celle de l'écran à l'identique (même politique,
  même poids de formulaire, même `onSave`, mêmes titres). Un rappel d'édition
  passé à vos cartes par fermeture court-circuiterait tout cela.
- **Refus fail-closed, jamais d'exception**
  ([AD-10](../concepts/invariants.md#ad-10)) : hors d'un `ZCrudScreen`,
  `maybeOf` rend `null` ; une capacité refusée rend `false` ; une ouverture
  demandée malgré tout ne présente rien.
- **Le champ « widget libre » n'est pas dispensé.** Un widget hôte servi par le
  `ZWidgetRegistry` dessine ses propres contrôles : le socle lui transmet bien
  `ctx.field.readOnly`, mais c'est au widget de l'honorer, sinon la fiche
  « lecture seule » reste cliquable. Le registre doit par ailleurs être posé
  **au-dessus du `Navigator`** pour servir une surface présentée en route, et
  un champ vide n'apparaît en lecture que s'il déclare `showIfNull: true`.

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_screen/README.md) — installation, démarrage rapide, API complète.
- [zcrud_core](zcrud_core.md) — les briques assemblées (liste, édition, registre, ACL).
- [zcrud_navigation](zcrud_navigation.md) — `presentEdition` et la politique de présentation.
- [zcrud_ui_kit](zcrud_ui_kit.md) — coquille de page, app-bar recherchable, confirmation et toaster consommés par l'écran.
- [zcrud_list](zcrud_list.md) — backend de **rendu** Syncfusion (`ZListRenderer`), à injecter pour le layout `dataGrid`.
- [zcrud_export](zcrud_export.md) et [zcrud_export_pdf](zcrud_export_pdf.md) — les exporteurs de liste déclarés sur `export`.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
