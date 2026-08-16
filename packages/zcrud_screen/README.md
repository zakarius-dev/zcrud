# zcrud_screen

Écran CRUD **assemblé et déclaratif** : `ZCrudScreen<T>` est à `DynamicList` ce
que `DynamicEdition` est aux champs — la pièce qui prend une déclaration et rend
un écran fonctionnel (liste, recherche, création, édition, sauvegarde,
corbeille), sans que l'assemblage ne monte jamais dans le cœur (invariant AD-1).

## Aperçu {#apercu}

zcrud fournit d'excellentes briques — `DynamicList`/`ZTabbedList` (rendu),
`ZRowAction` (actions de ligne gouvernées `ZAcl`), `presentEdition` +
`ZPresentationPolicy` (présentation dérivée du breakpoint), `DynamicEdition`/
`ZFormController` (formulaire), `ZRepository`/`ZDataRequest.deletedScope`
(données et corbeille). Ce paquet fournit **la pièce qui les assemble**, pour
que chaque application n'ait plus à recoudre le cycle complet écran par écran.

L'écran est **bâti sur `zcrud_ui_kit`** : il ne refabrique ni sa coquille de
page, ni sa confirmation, ni sa notification. Concrètement, sans une ligne de
code hôte, il hérite :

- de l'**app-bar recherchable** du socle (`ZPageScaffold`/`ZSearchableAppBar`)
  — le titre morphe en champ de recherche, `Échap` referme, la frappe ne
  reconstruit que la tranche app-bar ; les actions sont **déclarées en
  données** (`ZAppBarAction`) avec le **menu de débordement** du socle, et la
  typographie d'en-tête reste atteignable par les jetons `ZcrudTheme` ;
- de la **confirmation** des gestes destructifs (`showZConfirmDialog`,
  `ZConfirmTone.destructive`) — dark-mode-aware, libellés l10n, cibles ≥ 48 dp ;
- de la **notification** d'échec des actions de ligne (`ZToaster` +
  `ZToasterScope`) — l'app substitue son toaster (GetX, `toastification`…)
  sans que le paquet n'importe le moindre tiers.

Dépendances internes (arêtes sortantes uniquement, graphe acyclique) :

```
zcrud_screen ──> zcrud_core
             ├─> zcrud_navigation ──> zcrud_responsive ──> zcrud_core
             └─> zcrud_ui_kit ──> zcrud_core
```

**Quand l'utiliser** : « une liste dont on crée, édite et met à la corbeille
les éléments » — le cas d'usage nominal d'un écran CRUD, y compris ses
variantes en lecture seule (déclarées, jamais contournées).

**Quand ne pas l'utiliser** : une vue qui n'est pas une liste (carte
géographique, organigramme) — descendez d'un cran et composez directement
`DynamicList`/`ZListController`/`presentEdition` : l'assemblage est mince,
rien n'est perdu.

## Installation {#installation}

Dépendance git (paquet non publié sur pub.dev) :

```yaml
dependencies:
  zcrud_screen:
    git:
      url: git@github.com:zakarius-dev/zcrud.git
      ref: <tag>
      path: packages/zcrud_screen
```

Les arêtes internes (`zcrud_core`, `zcrud_navigation`…) exigent des
`dependency_overrides` à la racine du consommateur : suivez la recette
complète de `docs/private-git-consumption.md` (dépôt zcrud).

## Démarrage rapide {#demarrage-rapide}

Déclaration **minimale** — le type est enregistré au `ZcrudRegistry`
(annotation `@ZcrudModel`, registrar généré appelé au bootstrap) : champs de
liste et de formulaire, projection en cellules et reconstruction d'entité sont
**dérivés** du schéma généré, l'ACL vient du `ZcrudScope` ambiant, le mode de
présentation du breakpoint.

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

/// Modèle d'exemple — en pratique un `@ZcrudModel` dont le registrar généré
/// enregistre schéma et codec au bootstrap.
class Consignee extends ZEntity {
  const Consignee({this.id, required this.name, this.code = ''});

  @override
  final String? id;
  final String name;
  final String code;
}

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

#### Ce que ces cinq lignes supposent

La déclaration ci-dessus tient en cinq lignes parce que **trois conditions**
sont réunies. Ôtez-en une, et la déclaration s'allonge — ce n'est pas un défaut
de l'assemblage, c'est le prix de ce qu'il ne peut plus dériver.

| Condition | Ce qui est dérivé | Si elle n'est pas remplie |
|---|---|---|
| Le modèle est **enregistré au registre** (`@ZcrudModel` + registrar appelé au bootstrap) | champs de liste et de formulaire, projection en cellules, reconstruction d'entité | déclarer `listFields`/`formFields`, `toCells`, `fromValues` à la main |
| La source est un **`ZRepository`** | lecture paginée, recherche, corbeille, observation des mutations | `ZCrudSource.items` + les rappels d'écriture correspondants |
| Les lignes sont rendues par la **tuile générique** | l'affichage d'une ligne | un `itemBuilder`/`entityBuilder` — c'est-à-dire tout le code de votre carte métier |

**Ordre de grandeur mesuré** sur un écran réel à **carte métier** et source en
mémoire : **136 lignes**, contre **95** pour le même écran écrit à la main sans
l'assemblage. L'écart tient presque entièrement à la carte : une tuile
dessinée par l'application reste du code de l'application, et l'assemblage ne
peut ni la deviner ni la raccourcir. Ce qu'il apporte alors n'est pas la
brièveté mais le **cycle** (édition, corbeille, recherche, gouvernance,
notifications) qu'il n'y a plus à recoudre.

À retenir : les cinq lignes sont le profil **modèle enregistré + dépôt + tuile
générique**. Annoncer ce chiffre pour un écran à carte métier serait faux.

#### La grille de données exige `zcrud_list`

Le layout par défaut est `ZListDataGridLayout` : il **délègue à un backend de
rendu**, et le cœur n'en embarque aucun (`zcrud_core` ne dépend ni de Syncfusion
ni d'aucune bibliothèque de grille). Sans renderer injecté, l'écran lève une
`ZScopeError` explicite au premier rendu de la liste.

Deux façons de le brancher :

```dart
// 1. Par le scope, une fois pour toute l'application (recommandé).
ZcrudScope(
  listRenderer: const ZSfDataGridRenderer(),
  child: MonApplication(),
);

// 2. Ou en choisissant un layout rendu DANS le cœur, sans backend :
ZCrudScreen<Consignee>(
  title: 'Consignataires',
  source: ZCrudSource<Consignee>.repository(repo),
  registry: registry,
  layout: ZListBuilderLayout(itemBuilder: ...), // ou ZListGridLayout
);
```

`zcrud_list` (dépendance : `syncfusion_flutter_datagrid`) fournit
`ZSfDataGridRenderer`. Les layouts `builder`, `grid` et `custom` n'exigent
**aucun** backend : ils sont rendus dans le cœur.

Exemple **complet** (celui du CR d'origine) — chaque dérivation surchargée par
un paramètre :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

// `Consignee` : voir le modèle d'exemple du bloc précédent.

Widget buildConsigneesScreenComplet({
  required ZRepository<Consignee> repo,
  required ZcrudRegistry registry,
  required ZAcl acl,
  required List<ZFieldSpec> listFields,
  required List<ZFieldSpec> formFields,
}) {
  return ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.repository(repo),
    registry: registry,
    listFields: listFields,          // ce qui s'affiche
    formFields: formFields,          // ce qui s'édite
    cellsOf: (c) => <String, Object?>{'name': c.name, 'code': c.code},
    acl: acl,
    policy: const ZPresentationPolicy(),
    layout: ZListGridLayout(
      maxCrossAxisExtent: 350,
      itemBuilder: (context, row, columns) => Card(
        child: Center(child: Text('${row.cells['name']}')),
      ),
    ),
  );
}
```

Cohabitation (les données arrivent des flux de l'hôte, écritures par
callbacks) :

```dart
Widget buildCohabitationScreen({
  required List<Consignee> consignees,
  required ZcrudRegistry registry,
  required Future<void> Function(Consignee c) upsert,
  required Future<void> Function(Consignee c) softDelete,
  required Future<void> Function(Consignee c) restore,
  required bool Function(Consignee c) isDeleted,
}) {
  return ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.items(
      consignees,
      onSave: upsert,
      onSoftDelete: softDelete,
      onRestore: restore,
      isDeleted: isDeleted,
    ),
    registry: registry,
  );
}
```

## Concepts clés {#concepts-cles}

### Dérivation depuis le registre

Tout ce qui est dérivable d'une déclaration existante ne se redemande jamais :
`registry.kindOf<T>()` résout le `kind`, `fieldSpecsFor` fournit le schéma
(colonnes de liste, champs de formulaire — champs `isId` exclus du
formulaire), `encode` projette l'entité en cellules **et** en valeurs
initiales du formulaire, `decode` reconstruit l'entité depuis les valeurs
fusionnées (l'identité et les champs non édités sont conservés). Chaque
dérivation est remplaçable : `listFields`, `formFields`, `cellsOf`,
`editionBuilder`. Un type enregistré sous **plusieurs** kinds exige le
paramètre `kind` explicite (le registre refuse le choix silencieux).

### Source déclarative

`ZCrudSource.repository(repo)` est la voie nominale (lecture, recherche,
sauvegarde et corbeille par les ports neutres) ; `ZCrudSource.items(rows, …)`
la voie de cohabitation (callbacks optionnels). Les capacités de l'écran se
**dérivent** de la source : sans voie d'écriture, ni création ni édition ; sans
support de corbeille, ni bascule ni actions.

#### Une ressource qui ne s'écrit pas

Certaines ressources se lisent, se paginent et se cherchent, mais ne se
modifient **jamais** : un journal d'opérations horodatées, un référentiel servi
par un tiers, l'historique d'un parcours métier. `ZCrudSource.repository` ne
sait pas les dire — brancher un dépôt suffit à faire déclarer à l'écran qu'il
sait écrire. La troisième fabrique le dit :

```dart
ZCrudScreen<Operation>(
  title: 'Journal des opérations',
  // Le dépôt sert toute la lecture ; l'écriture n'existe pas.
  source: ZCrudSource.readOnlyRepository(journalRepository),
  registry: registry,
  detailsEnabled: true,
)
```

`canWrite`, `supportsTrash` et `supportsPurge` valent alors **tous `false`**,
dépôt présent — et dépôt `ZPurgeable` compris. L'écran n'offre ni bouton de
création, ni action d'édition, ni duplication, ni bascule corbeille, et ses
gestes programmatiques (`ZCrudScreenActions.openCreation` / `openEdition` /
`openUpdate`) restent **inertes**. Pagination, tri, recherche serveur et
périmètre de requête, eux, sont intacts : c'est la contrepartie qu'on n'a plus
à payer pour exprimer l'immuabilité.

**Ce n'est pas une ACL — et il ne faut pas le remplacer par une.** Une ACL
gouverne **qui** a le droit d'agir : elle se paramètre par usager, et un profil
administrateur finit toujours par obtenir le geste qu'elle refusait aux autres.
Cette fabrique parle de **ce que la ressource permet**. Un journal immuable
n'est pas « un CRUD interdit à tout le monde » : c'est une ressource dont
l'écriture n'existe pas. Le geste n'est donc offert à personne — pas même sous
une ACL tout-accordée — et sa disparition ne dépend d'aucune configuration
qu'un oubli pourrait défaire.

C'est aussi la différence avec une **omission**. Un écran qui n'ouvre pas
d'édition faute de `registry` tient son invariant d'un manque : le premier
refactoring qui ajoute le registre le lui reprend, sans bruit. Ici le registre
peut être fourni, le formulaire dérivable et la fiche de détail offerte : il n'y
a toujours **aucune voie d'écriture** à emprunter.

La consultation, elle, reste entière : `detailsEnabled: true` ouvre le
formulaire complet en lecture, sans retour vers l'édition.

### Corbeille

La corbeille a **trois gestes** : y mettre, en sortir, supprimer
définitivement.

| Geste | Permission `ZAcl` | Voie repository | Voie items |
|---|---|---|---|
| Mettre à la corbeille | `ZCrudAction.delete` | `repository.softDelete` | `onSoftDelete` |
| Restaurer | `ZCrudAction.restore` | `repository.restore` | `onRestore` |
| Supprimer définitivement | `ZCrudAction.clear` | `ZPurgeable.purge` | `onPurge` |

Voie repository : le listing corbeille interroge le backend en portée
`ZDeletedScope.deletedOnly` (recherche et pagination inchangées). Voie items :
partition par le prédicat `isDeleted` déclaré — mêmes permissions, même
filtrage `ZAcl`.

Les deux premiers gestes sont servis par **tout** `ZRepository`. Le troisième
non, et c'est délibéré : un journal immuable, un référentiel réglementaire ou un
dépôt soumis à rétention n'ont aucun moyen légitime de détruire une donnée. La
purge se **déclare** donc, par un mixin optionnel :

```dart
class DepotDossiers with ZPurgeable<Dossier> implements ZRepository<Dossier> {
  @override
  Future<ZResult<Unit>> purge(String id) async {
    // suppression définitive, irréversible ; idempotente si l'id est absent
    return const Right(unit);
  }
  // … reste du port
}
```

**Sans le mixin** (ou, voie items, sans `onPurge`) : aucun bouton de
suppression définitive, aucune erreur, aucun crash — la corbeille fonctionne
normalement avec ses deux autres gestes.

Un geste n'apparaît que s'il est **voulu**, **possible** et **autorisé** :

```dart
ZCrudScreen<Dossier>(
  // voulu : quels gestes le produit offre
  trashPolicy: ZTrashPolicy.withoutPurge, // corbeille dont rien ne disparaît
  // possible : la source sait-elle le servir (mixin / rappel déclaré)
  source: ZCrudSource.repository(depot),
  // autorisé : `delete`, `restore`, `clear` de votre ZAcl
  acl: MonAcl(),
  // …
)
```

`ZTrashMode` décide si la corbeille *existe* ; `ZTrashPolicy` décide de *ce
qu'on y fait* (`full` par défaut, `withoutPurge`, `readOnly`, ou une
combinaison libre).

**Consulter avant d'agir** : la fiche de détail est offerte **en corbeille
aussi**, dès que vous l'avez déclarée (`detailsEnabled`, ou `ZScreenMode.details`)
et que votre `ZAcl` accorde `ZCrudAction.view` sur la ligne. L'asymétrie avec
les gestes d'écriture est voulue : *écrire* sur un élément supprimé n'a pas de
sens, *le lire* en a — et c'est là qu'on en a le plus besoin. Une corbeille
contient souvent des documents qui se ressemblent, dont la ligne ne montre
qu'une poignée de colonnes ; la fiche les montre **tous**, et la suppression
définitive ne se rejoue pas.

La fiche ainsi ouverte est **strictement en lecture** : aucun bouton
« Modifier » n'y apparaît, **même** pour un usager muni de `ZCrudAction.update`
(`ZCrudEditionScope.onEditOf` y rend `null`). Éditer un élément supprimé n'est
offert nulle part.

**Actions supplémentaires** : `rowActions` s'applique aux éléments **vivants**,
`trashRowActions` aux éléments **en corbeille**. Les deux canaux sont disjoints
— une action déclarée pour l'un n'apparaît jamais dans l'autre.

**Confirmation** : les deux gestes destructifs sont confirmés
(`confirmDestructive`, défaut `true`), mais ne posent pas la même question. La
mise à la corbeille se défait ; la suppression définitive annonce son
irréversibilité. Annuler — bouton, barrière ou retour arrière — n'écrit
**rien**.

#### Qui voit l'accès à la corbeille, et avec quel compte

L'accès à la corbeille est offert à qui peut **restaurer** ou **purger**.
Supprimer n'en fait pas partie : *mettre* à la corbeille n'est pas *y entrer*,
et un usager qui ne sait ni restaurer ni purger n'a rien à y faire — il verrait
une vue où aucun geste ne lui est possible.

Le bouton peut afficher le **nombre d'éléments** que la corbeille contient, et
disparaître quand elle est vide :

```dart
ZCrudScreen<Dossier>(
  trashCount: compteurDeCorbeille,                 // ValueListenable<int>
  trashPolicy: const ZTrashPolicy(visibleWhenEmpty: false),
  // …
);
```

L'écran **ne compte jamais lui-même** : compter, c'est lire la source, et le
faire au rendu coûterait une lecture asynchrone par image — l'écran
clignoterait pour afficher un nombre. Il prend donc celui que l'application
lui donne, sauf sur la voie `items` où le compte est **dérivé gratuitement**
de la liste déjà en mémoire (rien à déclarer).

Parce que le compte est **écoutable**, sa mise à jour ne redessine que la
pastille : le corps de l'écran est construit une fois et transmis tel quel
(invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2)). Compte
inconnu, l'accès reste offert — une corbeille non comptée n'est pas une
corbeille vide.

### Onglets

Un écran segmenté déclare ses onglets dans `tabs`. Un onglet prend l'une de
**deux formes**, et la présence de son `builder` suffit à trancher :

| Forme | Ce que l'onglet déclare | Ce que l'écran y accroche | Ce qu'il en coûte |
|---|---|---|---|
| **Onglet assemblé** (`builder` absent) | sa catégorie (`baseFilters`), et s'il y a lieu ses droits (`acl`) | la liste dérivée du schéma, ses actions de ligne (consulter, modifier, dupliquer, mettre à la corbeille), le filtrage par les droits, la recherche partagée, la corbeille catégorisée | l'onglet rend une **liste** — pas autre chose |
| **Onglet à builder** | la vue entière | **rien** : la vue est opaque à l'écran | ni actions de ligne, ni recherche partagée, ni onglets dans la corbeille |

**Préférez l'onglet assemblé** dès que l'onglet n'est qu'une **partition de la
même collection**. C'est le cas le plus courant — segmenter par statut, par
type, par service — et il ne demande alors aucune ligne de vue :

```dart
ZCrudScreen<Piece>(
  title: 'Pièces',
  source: ZCrudSource<Piece>.repository(repo),
  registry: registry,
  detailsEnabled: true,
  tabsScrollable: true,               // 6 onglets ne tiennent pas sur une barre fixe
  tabs: <ZListTab>[
    ZListTab(
      labelKey: 'enCours',
      baseFilters: const <ZFilter>[ZFilter('statut', ZFilterOp.eq, 'open')],
      titles: const ZCrudTitles(create: 'Nouveau dossier'),
      countOf: compteurEnCours,       // ValueListenable<int>
    ),
    ZListTab(
      labelKey: 'clotures',
      baseFilters: const <ZFilter>[ZFilter('statut', ZFilterOp.eq, 'closed')],
      acl: const MesDroitsEnLecture(), // ce segment ne s'écrit plus
    ),
  ],
);
```

Chaque onglet assemblé possède **son propre contrôleur de liste**, né sur la
politique de l'écran **élargie de sa catégorie** : sa position de défilement,
sa pagination et sa recherche lui appartiennent, et changer d'onglet ne les
perd pas.

L'onglet à builder reste la voie ouverte pour tout ce qui **n'est pas une
liste** — vue carte, carte mentale, tableau de bord. Ce que cet onglet rend,
l'écran ne le connaît pas ; il ne peut donc rien y accrocher, et il ne prétend
pas le contraire :

```dart
ZListTab(
  labelKey: 'carte',
  builder: (context) => MaCarteMentale(),  // l'écran ne sait pas ce que c'est
),
```

Les deux formes cohabitent dans une même barre. Mais **un seul onglet opaque
suffit** à retirer la barre de recherche partagée et les onglets de la
corbeille : l'écran ne propose pas ce qu'il ne pourrait honorer que sur une
partie des onglets.

#### Une barre de recherche unique, pour l'onglet actif

Des onglets **tous assemblés** rendent la loupe à l'app-bar. La barre est
unique — une seule saisie, au-dessus de toute la barre d'onglets — et elle
filtre **l'onglet actif, et lui seul** : les autres gardent leur liste
entière. Changer d'onglet fait **suivre** la recherche : l'onglet quitté
retrouve sa liste, l'onglet rejoint reçoit le terme resté visible dans la
barre.

Avec un onglet à builder, la loupe disparaît : l'écran n'a aucun moyen de
porter une recherche dans une vue qu'il ne construit pas. C'est à l'onglet de
poser la sienne, dans sa propre vue.

#### La corbeille garde la catégorisation

Quand tous les onglets sont assemblés, la vue corbeille **conserve la barre
d'onglets** : les mêmes filtres de catégorie s'appliquent à la partition
supprimée, et l'on retrouve ses éléments là où on les avait laissés. Avec un
onglet opaque, la corbeille reste le **listing unique** de l'écran — inchangé.

La **sélection multiple** (`selection`) n'est pas servie tant que la barre
d'onglets est rendue : chaque onglet possède sa vue, et un lot exécuté sur une
sélection faite dans un autre onglet serait invisible.

#### La requête d'un onglet est composée par l'écran

Un onglet déclare son socle de filtres — `ZListTab(baseFilters: …)`, ou
`ZListTab.category(filters: …)` qui le renseigne pour vous. L'écran le **compose
avec les filtres permanents de `query`** et offre le tout à la page de l'onglet :
celle-ci n'a plus rien à composer.

```dart
ZCrudScreen<Piece>(
  query: const ZListQueryPolicy(
    baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
  ),
  tabs: <ZListTab>[
    ZListTab.category(
      labelKey: 'enCours',
      filters: const <ZFilter>[ZFilter('statut', ZFilterOp.eq, 'open')],
      buildList: (context, _) => MaPage(),
    ),
  ],
);

// Dans MaPage — une seule ligne, permanents ET catégorie compris :
ZListController<Piece>(
  repository: repo,
  toRow: …,
  schema: …,
  baseFilters: ZListQueryPolicy.of(context).baseFilters,
);
```

Les deux socles sont ANDés **en tête** de chaque requête : `setFilters` et
`setSearch` ne peuvent pas les écraser — chercher dans un onglet ne peut pas en
faire sortir.

> **Si votre page composait déjà elle-même** (`ZListQueryPolicy.of(context)
> .filtersWith(categoryFilters)`), **retirez cette composition** : l'écran la
> fait désormais, et la garder ajoute une seconde fois le filtre de catégorie.
> La liste rendue reste correcte — une conjonction est idempotente — mais la
> requête émise porte un doublon.

**La cascade restreint, elle n'élargit jamais.** Les droits d'un onglet se
composent en **intersection** avec ceux de l'écran, puis du scope :

| Niveau | Ce qu'il décide |
|---|---|
| Scope de l'application | les droits de l'usager, valables partout |
| Écran | les droits de la ressource affichée |
| **Onglet** | l'affinage du segment courant — il **retire seulement** |

Un onglet ne peut donc pas rouvrir un geste refusé plus haut, quelle que soit
la générosité de ce qu'il déclare. Et sans aucun niveau supérieur monté, la
composition retombe sur le **refus** : déclarer des droits sur un onglet n'en
crée jamais à partir de rien. La brique sous-jacente est
`zRestrictAcl(base, restriction)` (type `ZRestrictedAcl`), réutilisable partout
où deux niveaux d'autorisation se rencontrent.

Les **intitulés** suivent l'onglet actif : un mode non renseigné par l'onglet
retombe sur celui de l'écran, puis sur le libellé l10n générique. Le
**compteur** est une `ValueListenable<int>` — la pastille se redessine seule,
la page de l'onglet n'est pas reconstruite.

### Tri, filtres de base et pagination

Un listing s'ouvre rarement « dans l'ordre de la source » : il s'ouvre trié par
date, sans les archives, cinquante lignes à la fois. Ces trois réglages se
**déclarent** sur l'écran, dans une seule politique :

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource.repository(repo),
  registry: registry,
  query: const ZListQueryPolicy(
    sort: <ZSort>[ZSort('updated_at', ZSortDirection.desc)],
    baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
    pageSize: 50,
  ),
);

// Cas courant, en une ligne :
query: ZListQueryPolicy.sortedBy('name'),
```

**Rien de déclaré, rien de changé** : sans `query`, l'écran émet exactement les
requêtes d'avant — aucun filtre, aucun tri, aucune limite de page.

**Un tri se remplace, un filtre de base ne se remplace pas.** C'est toute la
différence entre les deux premières lignes du tableau :

| Réglage | Effet | Ce qui l'emporte ensuite |
|---|---|---|
| `sort` | l'ordre du **premier** rendu | un tri demandé le **remplace** |
| `baseFilters` | une **règle du listing** (« jamais les archives ») | rien : un filtre demandé s'y **ajoute** |
| `pageSize` | la taille de page du listing paginé | — |

Le tri et les filtres **demandés** n'obligent plus à descendre au
`ZListController` : ils passent par les gestes de l'écran, donc par la même
déclaration.

```dart
// En-tête de tri posé par l'application, sous l'écran :
final actions = ZCrudScreenScope.maybeOf(context)!;
actions.sortBy(<ZSort>[const ZSort('qty', ZSortDirection.desc)]); // remplace le défaut
actions.filterBy(<ZFilter>[const ZFilter('statut', ZFilterOp.eq, 'ouvert')]); // s'ajoute
```

**Ce que la politique compose, et qu'elle n'écrase jamais :**

- **Corbeille** — la vue corbeille reste une vue corbeille : sa portée de
  suppression est intacte, le tri, les filtres permanents et la taille de page
  s'y appliquent **en plus**.
- **Recherche** — chercher, c'est ajouter un terme, pas remplacer une requête :
  ni les filtres permanents ni le tri ne sont perdus pendant la frappe.
- **Onglets** — un onglet **assemblé** (sans `builder`) reçoit la politique de
  l'écran **déjà composée avec sa catégorie** : il n'a rien à déclarer. Un
  onglet à `builder` possède sa vue, donc sa requête ; la politique composée
  lui est alors **offerte** :

  ```dart
  // Dans la page d'un onglet : les permanents de l'écran, puis la catégorie.
  ZListController<Dossier>(
    repository: repo,
    toRow: toRow,
    schema: specs,
    baseFilters: ZListQueryPolicy.of(context).filtersWith(categoryFilters),
  );
  ```

  `filtersWith` ne sait qu'**ajouter** : aucun appel ne peut faire disparaître
  un filtre permanent, ni le filtre de catégorie qu'on lui confie.

**Deux limites à connaître.** `pageSize` gouverne la pagination **curseur** de
la voie dépôt ; sur la voie `items` (liste déjà en mémoire, rendue d'un bloc,
sans geste « page suivante »), elle n'a pas d'objet — la tronquer masquerait
des éléments sans recours. Et le tri par défaut est posé **sur la requête**,
pas par un tri appliqué après coup : la toute première requête part déjà
triée, sans lecture supplémentaire de la source.

### Recherche : ce qu'elle interroge, ce qu'elle ignore

La barre de recherche de l'écran filtre la liste au fil de la frappe. Deux
réglages décident de ce qu'elle trouve, et ils se déclarent dans la **même**
politique que le tri et les filtres :

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource.repository(repo),
  registry: registry,
  query: const ZListQueryPolicy(
    searchScope: ZSearchScope.allColumns,                 // ce qu'elle interroge
    searchFolding: ZSearchFolding.diacriticsAndSpaces,    // ce qu'elle ignore
  ),
);

// Les deux d'un coup — la parité avec les moteurs de liste historiques :
query: const ZListQueryPolicy.legacySearch(),
```

**Le domaine par défaut.** Sans rien déclarer, la recherche interroge les seuls
champs marqués `searchable: true` dans le schéma, et compare en ignorant la
casse et les accents — les espaces, eux, comptent. C'est un domaine **choisi** :
le schéma décide de ce qui est cherchable, la recherche ne coûte que ce qu'il a
désigné, et une colonne technique ne devient pas trouvable par accident.

**Retrouver la parité d'un moteur de liste historique.** Les moteurs déclaratifs
antérieurs cherchaient dans **toutes** les colonnes déclarées et ignoraient les
espaces des deux côtés de la comparaison. Une migration qui garde le défaut
rétrécit donc la recherche **sans aucun signal** : la liste s'affiche, elle est
simplement vide. Les deux réglages ci-dessous rendent exactement ce
comportement.

| Réglage | Défaut | Valeur de parité | Ce qui change |
|---|---|---|---|
| `searchScope` | `searchableFields` | `allColumns` | une valeur d'une colonne **non** `searchable` (numéro de conteneur, référence, quantité) redevient trouvable |
| `searchFolding` | `diacritics` | `diacriticsAndSpaces` | « SOCIETE X SARL U » se laisse trouver par « sarlu », « SARL U » ou « sa rlu » |

`diacriticsAndSpaces` ignore **tous** les blancs — espace, espace insécable,
tabulation, saut de ligne — où qu'ils se trouvent. La ponctuation, elle, reste
significative dans les deux modes (`RC-2019-742` ne se cherche pas
`RC2019742`).

**Ce que coûte l'élargissement.** `allColumns` compare le terme à **chaque**
colonne de chaque ligne déjà retenue par les filtres, au lieu des seules
colonnes `searchable` : un facteur au plus égal au nombre de colonnes, sur un
jeu déjà réduit. Aucune lecture supplémentaire de la source, aucune requête de
plus, aucune reconstruction de plus du corps de l'écran — c'est ce que la
recherche **compare** qui change, pas ce que l'écran **reconstruit**.

**Ce que l'élargissement ne fait jamais.** Il ne fait pas déborder la recherche
hors de ce que la requête a déjà réduit :

- les **filtres permanents** restent opposables — une ligne exclue par
  `baseFilters` ne réapparaît pas parce qu'un terme la trouve ;
- la **vue corbeille** reste la corbeille — le domaine élargi s'y applique, sa
  portée de suppression est intacte ;
- un **onglet** garde son filtre de catégorie ; la sémantique de recherche lui
  est **offerte** comme les filtres permanents :

  ```dart
  // Dans la page d'un onglet : hériter du domaine déclaré par l'écran.
  final policy = ZListQueryPolicy.of(context);
  ZListController<Dossier>(
    repository: repo,
    toRow: toRow,
    schema: specs,
    baseFilters: policy.filtersWith(categoryFilters),
    searchScope: policy.searchScope,
    searchFolding: policy.searchFolding,
  );
  ```

**Une limite à connaître.** Ces réglages gouvernent la recherche exécutée par le
moteur de liste de `zcrud_core` — la voie `items`, la voie dépôt en mémoire, et
tout dépôt qui applique `ZDataRequest` par ce moteur. Un adaptateur qui exécute
la recherche côté serveur reçoit les deux réglages dans la requête, mais reste
libre de ne pas les servir : l'adaptateur Firestore, par exemple, ne sert pas
`search` du tout.

#### Ce qui filtre, sur quelle voie, à quel coût

Une barre de recherche qui ne filtre rien est pire qu'une barre absente :
l'usager en conclut que la liste ne contient pas ce qu'il cherche. L'écran ne
suppose donc plus que la source sait chercher — il le lui **demande**.

| Voie | Qui filtre | Ce que cela coûte |
|---|---|---|
| `ZCrudSource.items` | le moteur du socle | rien : la liste est déjà en mémoire |
| Dépôt qui **sert** `search` (SQL, index plein-texte, champ normalisé) | la source | une requête paginée par frappe |
| Dépôt qui **délègue** `search` (`ZDelegatesSearch` : Firestore, dépôts offline-first) | le moteur du socle, **le temps de la recherche** | une lecture non paginée du jeu, tant qu'un terme est saisi |

La troisième ligne est automatique et ne se déclare pas : le dépôt porte le
mixin `ZDelegatesSearch` de `zcrud_core`, l'écran le lit. **Tant qu'aucun terme
n'est saisi, rien ne change** — la pagination curseur reste le chemin nominal,
et aucune lecture supplémentaire n'a lieu. Dès qu'un terme est saisi, le
listing est servi en mémoire : recherche exacte, portée de colonnes et pliage
diacritique (« elephant » trouve « Éléphant ») compris ; un terme sans
correspondance rend la liste **vide**, jamais la totalité. Le terme effacé
ramène la voie paginée.

Ce chemin convient à un listing dont le jeu tient en mémoire (quelques milliers
de lignes). Au-delà, la voie tenable reste un **champ de recherche normalisé
pré-calculé** côté application, interrogeable par égalité ou par préfixe : le
dépôt sert alors la recherche lui-même et n'applique pas le mixin.

Un dépôt d'application qui a la même limite le déclare de la même façon :

```dart
class MonDepot<T extends ZEntity> extends ZRepository<T>
    with ZDelegatesSearch<T> {
  // … le port, inchangé : aucun membre à ajouter.
}
```

**Quand le filtrage ou le tri, eux aussi, sont inexacts.** La bascule
automatique ne concerne que la recherche. Si la source ne sert ni les filtres
ni le tri, le listing entier se déclare en mémoire :

```dart
query: const ZListQueryPolicy(
  pageSize: 50,
  paginationMode: ZListPaginationMode.inMemory,
),
```

Le jeu est alors lu en entier à **chaque** requête, puis filtré, trié et paginé
par le socle — à ne déclarer que sur un listing borné.

**Ce que devient le tri sur la voie mémoire.** Il n'est **pas** transmis à la
source : la requête part sans tri, et c'est le moteur du socle qui rend l'ordre
demandé, une fois le jeu lu. Ce n'est pas une économie, c'est une correction.
Un ordre servi par un backend documentaire **exclut** les documents dépourvus
du champ trié — trier sur une date facultative y perd, en silence, tous les
éléments non datés, et la seule alternative était de renoncer à l'ordre. Le
moteur du socle, lui, **classe** les valeurs absentes au lieu de les
retrancher : dernières en ordre croissant, premières en décroissant. Un listing
servi en mémoire — parce qu'il déclare `paginationMode: inMemory`, un
`itemFilter`, une disjonction, ou parce qu'une recherche est en cours — affiche
donc **tout** ce qu'il a lu, dans l'ordre demandé, et n'exige aucun index
composite pour un tri qui ne s'applique qu'en mémoire. Sur la voie dépôt à
périmètre requêtable, rien ne change : tri et pagination restent **serveur**.

#### Quand le périmètre n'est pas une requête

Les trois lignes ci-dessus supposent que le périmètre de l'écran s'écrit en
clauses. Sur un parc métier, c'est souvent faux : le dernier mot sur ce qui est
montré appartient au métier, et il s'exprime **en Dart**. Deux déclarations
prennent alors le relais, et elles se paient de la même façon.

| Déclaration | Ce qu'elle dit | Ce que cela coûte |
|---|---|---|
| `baseFilters` | « ce listing ne montre jamais les archives » | rien : servi par la source, pagination curseur intacte |
| `ZFilter.servedBySource` | « cette clause-là, c'est la base qui la tranche » | rien — mais elle ne vaut que ce que la source en fait |
| `baseFilterGroups` | « cet état **ou** ce champ jamais renseigné » | une lecture non paginée du jeu, à chaque requête |
| `itemFilter` | « ce que ce prédicat retient, et rien d'autre » | une lecture non paginée du jeu, à chaque requête |

**La clause que seule la base sait trancher**, d'abord, parce qu'elle est la
moins visible. Dès qu'un listing est servi en mémoire, le socle **ré-applique**
les filtres de la requête sur les lignes projetées : c'est ce qui les rend
exacts devant une source qui ne les traduit pas. Mais une clause qui vise un
champ **absent de la ligne** — une valeur calculée, jamais persistée, ou une
colonne que l'écran n'affiche pas — n'y trouve rien, et **vide le listing dès
le premier rendu**. Le contournement était d'ajouter une colonne « pont » au
seul bénéfice du filtre. `ZFilter.servedBySource` le remplace :

```dart
// `etat_depotage` est calculé côté source : aucune colonne ne le porte.
query: const ZListQueryPolicy(
  baseFilters: <ZFilter>[
    ZFilter.servedBySource('etat_depotage', ZFilterOp.isIn, <String>['termine']),
  ],
),
```

La clause part dans la requête comme n'importe quelle autre — l'adaptateur la
traduit sans avoir à la distinguer — et le socle ne la rejoue **jamais** sur
les lignes. Le listing filtre donc à la lecture, sans colonne-pont et sans se
vider.

⚠️ **C'est une promesse faite à la source, pas une garantie du socle.** La
clause ne vaut que si le dépôt la sert : devant un dépôt qui l'ignore, elle ne
filtre **rien**, et l'écran montre alors plus que ce qui a été déclaré — sans
erreur, sans avertissement. Il en va de même sur la voie `ZCrudSource.items`,
où il n'y a pas de source à qui adresser la promesse : la liste fournie est
prise telle quelle, la clause n'y filtre rien. À ne déclarer que sur une clause
dont vous savez votre dépôt capable ; partout ailleurs, une clause ordinaire
(ré-appliquée, donc exacte) ou un `itemFilter` écrit sur l'entité restent les
bonnes voies. Une clause servie par la source n'a pas non plus sa place dans un
`baseFilterGroups` : le socle ne pouvant pas l'évaluer, elle est écartée de la
disjonction.

**La disjonction**, ensuite, parce que c'est le cas le plus courant d'un
workflow : *l'état initial est l'absence d'état*. Un onglet « En attente »
exprimé par la seule égalité se vide des dossiers fraîchement déposés, dont le
champ n'a jamais été écrit — sans un message, sans une erreur.

```dart
ZListTab(
  labelKey: 'enAttente',
  baseFilterGroups: const <ZFilterGroup>[
    ZFilterGroup.any(<ZFilter>[
      ZFilter('etat', ZFilterOp.eq, 'enAttente'),
      ZFilter('etat', ZFilterOp.isNull),
    ]),
  ],
)
```

**Le post-filtre**, ensuite, pour ce qu'aucune clause ne dit : un croisement de
droits, une fenêtre de dates calculée, une catégorie qui n'existe pas en base.

```dart
// Déclaré une fois, HORS du `build` (voir l'avertissement plus bas).
bool _visiblePour(Dossier dossier) => dossier.habilitations.contains(agent);

query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_visiblePour)),
```

Le prédicat reçoit **l'entité**, jamais la ligne rendue : la règle se lit dans
le vocabulaire du domaine, et renommer un champ devient une erreur de
compilation au lieu d'un listing qui se met silencieusement à tout montrer. Il
ne peut que **restreindre** — l'écran montre au plus ce qu'il montrait sans
lui — et il s'applique **avant la pagination**, si bien qu'une page pleine
reste pleine. Un onglet peut en déclarer un à son tour
(`ZListTab.itemFilter`) : les deux s'appliquent, l'onglet retire, il ne rouvre
pas ce que l'écran a écarté.

**Ce que cela coûte, et pourquoi.** Ni une disjonction ni un prédicat Dart ne
sont réputés traduisibles par la source. Le socle refuse de laisser une
déclaration de périmètre être ignorée en silence par la pagination curseur —
un écran qui montrerait plus que ce qu'on lui a déclaré est le pire des cas.
Déclarer l'un ou l'autre **bascule donc le listing sur le chemin mémoire**, et
le jeu entier est lu à chaque requête, pour toute la vie de l'écran (là où la
bascule d'une recherche ne dure que le temps du terme saisi).

**Quand ne PAS en déclarer** : dès que la règle est exprimable en clauses.
`baseFilters` reste servi par la source, garde la pagination curseur et ne lit
que la page affichée. Sur une collection sans borne, c'est la seule voie
tenable : le post-filtre est fait pour ce qui n'est **pas** requêtable, jamais
comme raccourci d'écriture. Un écran qui n'en déclare aucun ne change de rien —
mêmes requêtes, même pagination serveur qu'auparavant.

⚠️ **Déclarez le prédicat hors du `build`.** Deux politiques d'écran sont
comparées par valeur, et changer de politique reconstruit les contrôleurs du
listing. Une fonction nommée reste égale à elle-même d'une image à l'autre ;
une lambda écrite dans `build` est une fonction neuve à chaque fois, et le
listing se rechargerait sans fin.

### Présentation de l'édition

Le formulaire est présenté via `presentEdition` : le mode (`page`/`sheet`/
`dialog`) se dérive du breakpoint par la `ZPresentationPolicy` déclarée
(`policy`, `formWeight`). `editionBuilder` remplace le formulaire dérivé par
un formulaire applicatif complet — la présentation et la voie de sauvegarde
restent assemblées.

### Duplication et titres à trois états

Le geste **« dupliquer »** est une action de ligne câblée d'office : il ouvre
la surface d'édition en mode **duplication**, pré-remplie d'une copie **sans
identité** de l'entité (produite par le canal du registre : `encode` → retrait
des champs `isId` → `decode`) ; la sauvegarde matérialise une **nouvelle**
entité, l'originale reste intacte. Il est gouverné par la même permission que
la création (`ZCrudAction.create`) et par `canCreate` ; `canDuplicate: false`
le retire par déclaration, et il est absent hors de `ZScreenMode.full`, si la
source ne sait pas écrire, ou sans `registry` (le canal de copie est la
dérivation).

Les **titres** de la surface d'édition se déclarent en une fois via
`titles: ZCrudTitles(create: …, copy: …, update: …, read: …)` — quatre états,
la duplication ayant son **propre** intitulé (ex. « Copie de la mutation »),
distinct de la création nue, et la consultation le sien. Chaque titre est une
clé l10n ou un littéral (résolu via `label(context, …)`) ; un titre `null`
retombe sur les clés l10n génériques `create` / `copy` / `edit` / `details`.

### Consultation, fiche de détail, verrouillage

**La fiche de détail est un geste de ligne, pas un mode d'écran.** Un écran qui
crée, met à la corbeille et restaure peut parfaitement ouvrir des fiches : c'est
même le cas le plus courant. Il suffit de le déclarer.

```dart
// On crée, on met à la corbeille, on restaure… et le tap consulte.
ZCrudScreen<Convocation>(
  title: 'Convocations',
  source: ZCrudSource.repository(repo),
  registry: registry,
  detailsEnabled: true,
)
```

`detailsEnabled` ne retire rien : le bouton de création, la bascule corbeille,
la mise à la corbeille et la restauration restent exactement ce qu'ils étaient.
Chaque ligne gagne simplement une action « détails », et le geste **nominal**
d'une carte métier devient la consultation.

Le `mode:`, lui, décrit ce qu'est l'écran **entier** :

| Mode | Créer | Consulter la fiche | Éditer | Corbeille |
|---|---|---|---|---|
| `ZScreenMode.full` (défaut) | oui | selon `detailsEnabled` | oui | oui |
| `ZScreenMode.details` | non | **oui** | oui si `ZCrudAction.update` | non |
| `ZScreenMode.locked` | non | non | non | non |

`ZScreenMode.details` est l'**écran de consultation** : une liste qui ne crée
rien et n'a pas de corbeille. Ne le choisissez pas pour obtenir la fiche sur un
écran par ailleurs complet — vous perdriez la création et la corbeille pour
tout l'écran. C'est `detailsEnabled` qu'il faut.

**La fiche est le formulaire entier, pas un résumé des colonnes.** C'est le
point qui la distingue d'un simple affichage en lecture : une fiche construite
depuis le schéma de **liste** ne montrerait que les quatre ou six colonnes
affichées, là où le formulaire porte **tous** les champs. L'action « détails »
ouvre la surface d'édition habituelle — `formFields` dérivés du registre, ou le
formulaire de l'application (`editionBuilder`) — rendue en lecture seule.

```dart
// Un écran de consultation : la liste montre 5 colonnes, la fiche les 23
// champs du formulaire, et l'utilisateur autorisé repart en édition d'un tap.
ZCrudScreen<Consignee>(
  title: 'Consignataires',
  source: ZCrudSource.repository(repo),
  registry: registry,
  mode: ZScreenMode.details,
)
```

Le retour vers l'édition n'est **pas** un cul-de-sac : l'action « modifier »
reste rendue si et seulement si l'ACL accorde `ZCrudAction.update` — c'est
l'ACL qui tranche, jamais le mode. `ZScreenMode.locked`, lui, est la
consultation **verrouillée** : aucun geste, pas même l'ouverture d'une fiche
(`detailsEnabled` y est sans effet).

#### Ouvrir la fiche depuis une carte

Sur un écran déclaré consultable, deux rappels, deux intentions :

```dart
// Le geste NOMINAL de la ligne : consultation dès que la fiche est offerte.
final ouvrir = zCrudEditionOpener(context, convocation);
// La consultation, demandée explicitement (`ZCrudAction.view`).
final consulter = zCrudDetailsOpener(context, convocation);
// L'édition, demandée explicitement (`ZCrudAction.update`).
final modifier = ZCrudScreenScope.maybeOf(context)?.updateOpener(convocation);
```

Tous trois rendent `null` quand le geste n'est pas possible — hors écran, écran
verrouillé, aucun formulaire, ou permission refusée **sur cette ligne**. `null`
veut dire « ne dessinez pas le bouton », jamais « dessinez-en un mort ».

La **vue corbeille** ne retire que l'écriture : `updateOpener` y rend `null`,
tandis que `zCrudDetailsOpener` — et donc `zCrudEditionOpener`, dont le geste
nominal est la consultation — y reste offert si `ZCrudAction.view` est accordé.

#### Revenir à l'édition **depuis** la fiche

L'action « modifier » existe sur la **ligne**. Dans la fiche, c'est
`ZCrudEditionScope.onEditOf(context)` qui la porte :

```dart
editionBuilder: (context, initial, save) {
  final modifier = ZCrudEditionScope.onEditOf(context);
  return MonFormulaire(
    initial: initial,
    onSave: save,
    readOnly: ZCrudEditionScope.readOnlyOf(context),
    // `null` ⇒ pas de bouton « Modifier ».
    onEdit: modifier,
  );
},
```

**Le geste ne referme rien.** La surface reste ouverte, à sa place, et redevient
éditable : aucune route n'est fermée ni rouverte, les valeurs déjà chargées sont
conservées, et le titre passe de celui de la consultation à celui de la
modification. Le formulaire **dérivé** obtient la même chose sans une ligne de
code.

`onEdit` est `null` — donc le bouton n'a pas lieu d'être — dans tous ces cas :
la surface est déjà en édition, l'ACL refuse `ZCrudAction.update` sur cette
entité, l'écran est verrouillé ou en vue corbeille, la source ne sait pas
écrire, ou le formulaire est monté hors d'un `ZCrudScreen`.

⚠️ **`readOnly: true` est déprécié** au profit de `mode:` (retrait en 1.0).
La correspondance est exacte : `readOnly: true` → `ZScreenMode.locked`,
`readOnly: false` → `ZScreenMode.full`. Le booléen ne savait pas exprimer le
troisième état — le seul dont un écran de consultation a besoin.

#### Un formulaire d'application se rend en lecture seule aussi

Le drapeau est **transporté jusqu'au formulaire**, quel qu'il soit. Le
formulaire dérivé le lit tout seul (`DynamicEdition.readOnly`, respecté par
toutes les familles de champs). Un formulaire fourni par l'application le lit
depuis le `BuildContext` qu'il reçoit :

```dart
editionBuilder: (context, initial, save) => MonFormulaire(
  initial: initial,
  onSave: save,
  readOnly: ZCrudEditionScope.readOnlyOf(context),
),
```

`ZCrudEditionScope` est un scope et non un paramètre de plus, délibérément :
ajouter un paramètre à `ZCrudEditionBuilder` rendrait inassignables **toutes**
les lambdas déjà écrites. Ici, le code existant compile inchangé, et celui qui
veut le drapeau le lit.

🔴 **Un champ « widget libre » ne devient pas lecture seule tout seul.** Un
widget hôte servi par le `ZWidgetRegistry` dessine ses propres contrôles — une
matrice d'autorisations à interrupteurs, par exemple. Le socle lui transmet
l'information (`ctx.field.readOnly` vaut `true` en fiche), mais c'est au widget
de l'honorer : sans cela, la fiche « lecture seule » reste cliquable.

```dart
registry.register('permMatrix', (context, ctx) => Switch(
      value: ctx.value == true,
      onChanged: ctx.field.readOnly ? null : ctx.onChanged,
    ));
```

Deux détails mesurés, qui évitent des surprises :

- le `ZWidgetRegistry` doit être posé **au-dessus du `Navigator`**
  (`MaterialApp.builder`), pas sous `home:` : la surface d'édition est une
  route, elle n'hérite que de ce qui enveloppe le `Navigator` ;
- en lecture, un champ **vide** n'est affiché que s'il déclare
  `showIfNull: true` — règle du socle, antérieure à ce mode.

### Coquille, recherche, confirmation et notification (socle `zcrud_ui_kit`)

La page est un `ZPageScaffold` : c'est **lui** qui construit le `Scaffold` et
l'`AppBar`. Le titre, le `leading` et les actions déclarées (`actions:`,
`List<ZAppBarAction>`) y sont propagés ; les actions **assemblées** (bascule
corbeille, création) s'y ajoutent après. Une action `isOverflow: true` part
dans le menu de débordement du socle — l'écran n'a pas de menu propre.

La **recherche** est celle de l'app-bar (`ZAppBarSearchConfig`) : la loupe
morphe le titre en champ, la query est propagée telle quelle à
`ZListController.setSearch` (voie repository) ou au moteur in-memory
`zApplyListRequest` (voie items), et la **portée corbeille** est respectée
(la recherche interroge alors `ZDeletedScope.deletedOnly`). `searchEnabled:
false` retire la loupe ; en mode `tabs`, elle est offerte quand **tous** les
onglets sont assemblés (elle filtre alors l'onglet actif) et retirée dès qu'un
onglet porte son propre `builder`.

La **mise à la corbeille est confirmée** par `showZConfirmDialog`
(`ZConfirmTone.destructive`). Annuler — bouton, barrière ou `pop` sans valeur
— n'écrit **rien** : ni `repository.softDelete`, ni `source.onSoftDelete`.
`confirmDestructive: false` retire le dialogue pour l'hôte qui possède son
propre flux. La **restauration** n'est jamais confirmée (geste non destructif).

L'**échec d'une action de ligne** (corbeille, restauration) part au toaster :
`ZToasterScope` de l'hôte s'il est monté, sinon le repli pur-Flutter
(`ScaffoldMessenger`), sinon **silence** — jamais de `throw` (AD-10). L'échec
d'une **sauvegarde** reste, lui, affiché **dans** la surface d'édition : les
deux canaux sont distincts, et le formulaire est la seule surface où une
erreur de saisie se corrige.

Les états **vide / chargement / aucun résultat / erreur** du listing restent
rendus par `DynamicList` (zcrud_core), qui les porte déjà avec `Semantics`,
l10n et couleurs de thème : l'écran n'en **double** aucun.

#### La navigation de l'application, portée par l'écran {#navigation}

L'écran **construit** le `Scaffold` : sans relais, une application à modules
n'avait aucun moyen d'attacher son menu à un écran migré — il fallait un second
`Scaffold` imbriqué, un `GlobalKey<ScaffoldState>` et un `leading` qui ment sur
son rôle. `drawer:` et `endDrawer:` sont donc **transmis tels quels** au
`Scaffold` du socle :

```dart
ZCrudScreen<Navire>(
  title: 'ships',
  source: ZCrudSource<Navire>.repository(repo),
  drawer: MonMenuLateral(), // votre menu, votre ACL, votre responsive
);
```

**Le menu appartient à l'application.** Le paquet n'en fournit aucun, n'impose
aucun responsive (tiroir sur mobile, colonne fixe sur desktop : c'est l'hôte
qui tranche) et n'y applique aucune règle de droits.

**Le bouton d'ouverture est inséré par Material, pas par zcrud** : un `Scaffold`
porteur d'un tiroir dote son `AppBar` du bouton « hamburger » **si et seulement
si** la place du `leading` est libre (`automaticallyImplyLeading` — comportement
natif que le socle ne réimplémente pas). Trois conséquences **voulues** :

| Situation | Bouton de menu | Tiroir atteignable ? |
|---|---|---|
| Vue normale, pas de `leading` | inséré par Material | oui (bouton + glissement) |
| `leading:` déclaré par l'hôte | **absent** — le `leading` prime | oui, par **glissement** depuis le bord |
| **Vue corbeille** | **absent** — le bouton de retour occupe la place | oui, par **glissement** depuis le bord |
| **Recherche ouverte** | absent — le bouton de fermeture occupe la place | oui, par glissement |

Le choix de la corbeille est **figé et gardé** : sortir de la corbeille prime
sur changer de module. L'`endDrawer` obéit aux mêmes règles ; son bouton
n'apparaît que si l'`AppBar` n'a aucune action — les actions de l'écran
occupant cette place, on l'ouvre en pratique par glissement ou par un geste
déclaré par l'hôte (`Scaffold.of(context).openEndDrawer()`).

🔴 **L'état « accès refusé » porte lui aussi le tiroir** : c'est l'écran où la
navigation manque le plus — sans elle, un refus d'ACL enferme l'usager sur une
page qui ne lui offre ni contenu ni sortie.

`drawer`/`endDrawer` nuls (défaut) ⇒ **aucun** tiroir, **aucun** bouton, rendu
strictement identique à celui d'avant leur introduction.

### Grille de cartes métier

Une liste ne se rend pas toujours en tableau. Pour une **grille de cartes**, il
suffit de déclarer la géométrie de la grille et la carte — la carte reçoit
**l'entité**, pas un sac de cellules :

```dart
ZCrudScreen<Consignee>(
  title: 'Consignataires',
  source: ZCrudSource<Consignee>.repository(repo),
  registry: registry,
  // Géométrie : largeur maximale d'une carte, hauteur fixe, plafond de
  // colonnes sur très grand écran. Responsive et RTL par construction.
  layout: const ZListGridLayout(
    maxCrossAxisExtent: 360,
    mainAxisExtent: 180,
    maxColumns: 4,
  ),
  // La carte : elle reçoit l'objet métier, avec tous ses champs — y compris
  // ceux qui ne sont pas des colonnes de liste.
  itemBuilder: (context, consignee, columns) => ConsigneeCard(consignee),
)
```

Ce qu'il n'y a **pas** à écrire : l'index `ligne → entité`. L'écran projette
chaque entité en ligne sous la clé publique `ZListRow.keyOf` (l'identité réelle,
ou une clé éphémère stable si l'entité n'est pas encore persistée) et alimente
avec lui le seam `DynamicList.entityFor` — celui-là même qui sert déjà aux
actions de ligne et à l'ACL par entité. La tuile déclarée descend dans **le
layout choisi par l'application**, quel qu'il soit (grille, liste verticale) :
la déclaration reste la seule source de vérité.

Deux règles de priorité, sans surprise :

- un layout construit avec **sa propre** tuile de ligne
  (`ZListGridLayout(itemBuilder: (context, row, columns) => …)`, qui reçoit une
  `ZListRow`) garde la sienne — l'explicite l'emporte sur l'injecté ;
- sans tuile déclarée, ni ici ni sur le layout, le rendu reste la **tuile
  générique** du paquet (titre = première colonne dérivée).

Hors `ZCrudScreen`, les mêmes tuiles typées se déclarent directement sur les
layouts du cœur : `ZListGridLayout.forEntity<T>(…)` et
`ZListBuilderLayout.forEntity<T>(…)`, alimentées par `DynamicList.entityFor`.

### Coloration de ligne

Sur un tableau de dépouillement, **la couleur porte l'information** : c'est ce
qui permet de balayer cent lignes d'un coup d'œil — une convocation relancée, un
rapport non rendu, un dossier clos. `rowColor` déclare cette teinte, et il la
décide sur **l'entité typée** :

```dart
ZCrudScreen<Convocation>(
  title: 'Convocations',
  source: ZCrudSource.repository(repo),
  registry: registry,
  rowColor: (context, convocation) => switch (convocation.statut) {
    Statut.relancee => ZRowTint(
        Theme.of(context).colorScheme.errorContainer,
        semanticLabel: 'Relancée',
      ),
    Statut.repondue => ZRowTint(
        Theme.of(context).colorScheme.secondaryContainer,
        semanticLabel: 'Répondue',
      ),
    // `null` ⇒ aucune teinte : la ligne est rendue telle quelle.
    _ => null,
  },
)
```

Le seam reçoit l'objet métier, jamais une cellule formatée : un renommage de
champ devient une **erreur de compilation**, là où une décision prise sur
`row.cells['statut']` se contenterait de faire disparaître la couleur en
silence.

La teinte est peinte **derrière** la tuile — celle du paquet comme celle de
l'application (`itemBuilder`), dans la liste verticale comme dans la grille de
cartes. Elle ne s'applique pas à un layout qui porte déjà **sa propre** tuile
(`ZListGridLayout(itemBuilder: …)`) — cette tuile appartient à l'application,
qui la colore elle-même — ni à la grille de données (`ZListDataGridLayout`),
dont le backend a sa propre coloration de cellules. Sans `rowColor`, le rendu
est strictement inchangé : pas un widget de plus dans l'arbre.

⚠️ **Doublez la couleur — une information portée par la seule couleur est
perdue.** Elle l'est pour un usager daltonien, sur un écran en plein soleil, à
l'impression, et pour un lecteur d'écran. `ZRowTint.semanticLabel` la rend
**audible** (il est annoncé sur la ligne, et accepte une clé l10n). La rendre
**visible** autrement reste l'affaire de la tuile :

```dart
itemBuilder: (context, convocation, columns) => ListTile(
  // Le même état, dit trois fois : par la teinte, par l'icône, par le mot.
  leading: Icon(convocation.statut.icone),
  title: Text(convocation.objet),
  subtitle: Text(convocation.statut.libelle),
),
```

Aucune couleur n'est codée dans zcrud : la teinte vient entièrement du thème de
l'application, d'où le `BuildContext` passé au seam.

### Une carte qui ouvre l'édition de l'écran

La carte de la section précédente reçoit son entité — il lui manque le geste.
Le lui passer par une fermeture serait un **court-circuit** : le rappel capturé
ne connaîtrait ni la politique de présentation de l'écran, ni son `formWeight`,
ni son `onSave`, ni son mode, ni ses titres. Une carte descendante d'un
`ZCrudScreen` demande donc à l'écran :

```dart
class ConsigneeCard extends StatelessWidget {
  const ConsigneeCard(this.consignee, {super.key});
  final Consignee consignee;

  @override
  Widget build(BuildContext context) {
    // `null` ⇒ le geste n'est pas possible (écran verrouillé, vue corbeille,
    // source en lecture seule, ou permission refusée). On ne dessine alors
    // rien, plutôt qu'un bouton mort.
    final ouvrir = zCrudEditionOpener(context, consignee);
    return Card(
      child: ListTile(
        title: Text(consignee.nom),
        subtitle: Text(consignee.ville),
        onTap: ouvrir,
        trailing: ouvrir == null
            ? null
            : IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier',
                onPressed: ouvrir,
              ),
      ),
    );
  }
}
```

La surface ouverte est **exactement** celle du bouton « + » et de l'action de
ligne : même `ZPresentationPolicy`, même `ZFormWeight`, même formulaire (dérivé
ou `editionBuilder`), même voie de sauvegarde, mêmes titres.

Trois formes, pour trois besoins :

| Forme | Usage |
|---|---|
| `ZCrudScreenScope.maybeOf(context)?.canOpenEdition(entity)` | interroger la capacité **avant de rendre** |
| `…openEdition(entity)` | ouvrir — **inerte** si le geste est refusé |
| `zCrudEditionOpener(context, entity)` | le rappel prêt à poser, ou `null` |

Le même triplet existe pour l'édition **explicite** (`canOpenUpdate` /
`openUpdate` / `updateOpener`) et pour la **création** (`canOpenCreation` /
`openCreation` / `creationOpener` — le geste du bouton « + », si vous préférez
dessiner le vôtre).

**Ce que « nominal » veut dire.** `openEdition` ouvre le geste que la ligne
offrirait d'elle-même : en `ZScreenMode.details`, c'est la **fiche en lecture
seule** (permission `ZCrudAction.view`) ; ailleurs, c'est l'**édition**. Le
retour vers l'édition depuis une fiche passe par `openUpdate`, offert si et
seulement si l'ACL accorde `ZCrudAction.update` — c'est la même règle que
l'action « modifier » de la ligne, pas une seconde logique de mode.

**Refus, jamais d'exception.** Aucun de ces membres ne lève :
`ZCrudScreenScope.maybeOf` rend `null` hors d'un `ZCrudScreen` (votre carte
reste montable seule, en galerie de composants ou en test), une capacité
refusée rend `false`, un rappel refusé rend `null`, et une ouverture demandée
malgré tout ne présente **rien**. La permission interrogée porte l'entité en
cible : le filtrage est **par ligne**, comme celui des actions.

Une entité **éphémère** (sans identité) relève de la création : c'est alors
`ZCrudAction.create` qui gouverne son ouverture, puisque l'enregistrer la crée.

**Deux scopes, deux endroits.** `ZCrudEditionScope` est posé autour de la
**surface présentée** — il dit au formulaire s'il est rendu en consultation.
`ZCrudScreenScope` est posé autour du **corps de l'écran** — il dit aux tuiles
ce que l'écran sait ouvrir. Une carte de la liste n'est jamais descendante de
la surface d'édition : les fondre en un seul scope les rendrait mutuellement
inatteignables.

### Champs « chemin » (modèle imbriqué, édition plate)

Quand des specs (dérivées ou fournies via `formFields`) portent un nom
**pointé** (`'vido.chefEquipePosteId'`), l'écran fait le pont entre le modèle
imbriqué et le formulaire plat : à l'ouverture, les valeurs initiales sont
aplaties (`zFlattenPaths` de `zcrud_core` sur l'entité encodée) ; à la
soumission, les clés pointées sont regroupées (`zRegroupPaths`) avant
`decode` — le sous-objet est reconstruit, les champs imbriqués non édités
sont préservés. La paire est symétrique par construction (testée dans
`zcrud_core`) : aucune paire aplatir/regrouper à réécrire côté hôte. Sans nom
pointé, le chemin d'édition est strictement inchangé.

### Gouvernance par ligne

Une autorisation utile ne s'arrête pas à « cet utilisateur peut-il supprimer
dans cette collection ? ». Elle descend à la ligne : un dossier clôturé ne se
modifie plus, une pièce déjà validée ne se valide pas deux fois, un élément
protégé ne se supprime pas — alors même que les droits de qui regarde n'ont pas
changé.

Tout cela se déclare par **un seul** point d'extension, `rowAcl`. Il reçoit
l'entité de la ligne et rend ses `ZRowPermissions` :

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource<Dossier>.repository(depot),
  registry: registre,
  rowAcl: (dossier) => dossier.cloture
      ? const ZRowPermissions.locked(reasonKey: 'dossierCloture')
      : const ZRowPermissions.unrestricted(),
);
```

Une seule déclaration gouverne **tout** : les actions de la vue vivante et
celles de la corbeille, rendues en boutons dans la ligne comme en menu.

#### 🔒 Un résolveur restreint, il n'élargit jamais

`ZRowPermissions` n'a aucun vocabulaire d'autorisation : on y déclare ce que la
ligne **refuse**, jamais ce qu'elle accorde. La composition avec votre ACL est
une **intersection** — un résolveur, même écrit permissif, ne peut pas rouvrir
un geste que l'ACL de l'écran ou du scope a fermé. C'est ce qui permet de
confier `rowAcl` à du code métier sans en faire une surface de contournement
des droits.

#### Droit refusé ≠ action inapplicable

| Nature | Ce qui la déclare | Ce qui est rendu |
|---|---|---|
| **Droit refusé** | votre ACL, ou `ZRowPermissions` | ce que dit votre `actionAclMode` : `hide` masque (défaut), `disable` montre l'action inerte avec son motif |
| **Action inapplicable** | `ZRowAction.enabledFor` | l'action est **toujours** rendue, inerte, avec son motif — elle existe, elle ne s'applique pas à cette ligne |

La distinction compte : masquer une action inapplicable ferait clignoter les
lignes au gré de leur état, tandis que la présentation des refus de **droit**
reste votre décision. Dans les deux cas, l'action inerte annonce son motif aux
lecteurs d'écran (`Semantics(enabled: false)` et indice), et n'invoque rien.

#### Les quatre besoins courants, un seul concept

| Besoin | Écriture |
|---|---|
| **ACL propre à un élément** | `rowAcl: (e) => e.sensible ? const ZRowPermissions.denying({ZCrudAction.delete, ZCrudAction.update}) : const ZRowPermissions.unrestricted()` |
| **Lecture seule d'un élément** | `rowAcl: (e) => e.cloture ? const ZRowPermissions.locked() : const ZRowPermissions.unrestricted()` — toutes les écritures tombent, consultation et historique restent |
| **Suppression conditionnelle** | `rowAcl: (e) => e.protege ? const ZRowPermissions.denying({ZCrudAction.delete}, reasonKey: 'elementProtege') : const ZRowPermissions.unrestricted()` |
| **Validation conditionnelle** | `rowAcl: (e) => e.valide ? const ZRowPermissions.denying({ZCrudAction.validate}) : const ZRowPermissions.unrestricted()` — ou, si le geste doit rester **visible mais inerte** : `monAction.withEligibility((e) => !e.valide, reasonKey: 'dejaValidee')` |

Sans `rowAcl` déclaré ni `enabledFor` posé, le comportement est strictement
inchangé.

**Coût.** Le résolveur est appelé une fois par ligne rendue : gardez-le pur et
bon marché (aucune lecture de dépôt). Rendre la constante
`ZRowPermissions.unrestricted()` pour les lignes ordinaires ne coûte rien.

### Sélection multiple et actions de masse

Une déclaration suffit : chaque ligne reçoit sa case à cocher, et une **barre
d'actions de masse** apparaît dès le premier élément coché.

```dart
ZCrudScreen<Dossier>(
  title: 'Dossiers',
  source: ZCrudSource.repository(repo),
  registry: registry,
  selection: const ZSelectionPolicy(),
)
```

Les actions offertes sont celles de la **vue courante** : mise à la corbeille
sur les éléments vivants, restauration et suppression définitive en corbeille.
Chacune existe aux mêmes conditions que l'action de ligne homonyme — geste voulu
par `trashPolicy`, servi par la source, autorisé par l'ACL. Rien à recoudre :
sans `selection` déclarée, l'écran est exactement celui d'avant.

#### Le lot obéit aux mêmes droits que la ligne

La résolution est **la même voie** que celle des boutons de ligne : ACL de
l'écran, `rowAcl`, `enabledFor`. Il n'existe pas de seconde logique
d'autorisation pour le lot.

| Situation | Effet |
|---|---|
| Droit refusé pour la collection | Action **absente** de la barre (`actionAclMode: hide`, défaut), ou **inerte** (`disable` : l'action garde sa place, grisée, non actionnable, motif du refus annoncé — et rien ne s'écrit) |
| Ligne restreinte par `rowAcl` | L'élément est **retiré du lot** avant toute écriture, et le compte rendu le dit (« n skipped ») |
| Action inapplicable (`enabledFor`) | Même traitement : exclusion du lot, jamais une écriture silencieuse |

#### Ouvrir la sélection à l'appui long

Par défaut, chaque ligne porte sa case dès qu'une politique de sélection est
déclarée. Le motif tactile usuel — ouvrir la sélection à l'appui long — se
déclare par l'**arbitrage du geste** :

```dart
ZCrudScreen<Piece>(
  selection: const ZSelectionPolicy(),
  longPressOwner: ZRowLongPressOwner.selection,
);
```

Les cases n'apparaissent alors qu'une fois la sélection non vide, et la
sélection se referme d'elle-même quand elle se vide. Le menu contextuel des
actions de ligne ne s'ouvre plus qu'au **clic droit** ; son déclencheur visible
reste rendu, l'action reste donc atteignable sans geste contextuel (AD-13).

L'appui long est réclamé par trois fonctions — menu contextuel, copie de cellule
d'un rendu de grille, ouverture de la sélection — et `longPressOwner` n'en
désigne **qu'une**. C'est délibéré : trois réglages indépendants auraient permis
d'en déclarer deux à la fois, c'est-à-dire de recréer le conflit que ce réglage
existe pour empêcher. À noter : sur le layout `dataGrid`, les gestes de ligne
appartiennent au backend de grille — y déclarer `selection` retirerait l'appui
long au menu contextuel sans rien ouvrir en échange.

#### Le lot rend des comptes

Une action de masse qui échoue **sur une partie** du lot ne dit jamais « fait ».
La notification porte le nombre de succès, le nombre d'échecs, le nombre
d'éléments écartés, et **nomme** les éléments en échec (les trois premiers) :

```
1 succeeded · 2 failed : Bravo, Charlie
```

L'application qui veut sa propre surface — liste exhaustive, journal, réessai —
reçoit le `ZBatchReport` complet, avec les identités réussies et la cause de
chaque échec :

```dart
selection: ZSelectionPolicy(
  onReport: (report) {
    if (report.hasFailures) monJournal.consigner(report.failures);
  },
),
```

#### Confirmation, vidage, portée

- Un geste de masse **destructif** passe par la confirmation de l'écran
  (`confirmDestructive`, `true` par défaut), avec le **nombre d'éléments** dans
  la question — celui du lot réellement soumis, écartés déjà retirés. Annuler
  n'écrit rien. La restauration, non destructive, n'est pas confirmée.
- La sélection est **vidée** après chaque action de masse et à la bascule
  vivants ⇄ corbeille : un lot ne s'exécute jamais sur des éléments qu'on ne
  voit plus.
- « Tout sélectionner » porte sur les éléments **actuellement listés**, jamais
  au-delà de ce que la source a rendu.
- Tant que la barre d'onglets est rendue — vue vivante, et corbeille
  catégorisée — la sélection de l'écran n'est pas servie : chaque onglet
  possède sa vue. Elle s'applique au listing dont l'écran est propriétaire (le
  listing sans onglets, et la corbeille non catégorisée). Une page d'onglet
  qui veut la sienne déclare sa propre `DynamicList(selection:)`.

#### Actions de masse de l'application

`batchActions` ajoute les vôtres après les actions assemblées ; elles reçoivent
les entités sélectionnées et vous appartiennent (l'écran ne les gouverne pas) :

```dart
batchActions: (context, selected) => <ZBatchAction>[
  ZBatchAction(
    kind: ZBatchActionKind.custom,
    label: 'Exporter',
    icon: Icons.download,
    onSelected: () => exporter(selected),
  ),
],
```

#### Libellés

La barre et le compte rendu utilisent les clés `selectedCount`, `selectAll`,
`batchSucceeded`, `batchFailed` et `batchSkipped`, désormais présentes dans les
tables `en`/`fr` du socle. Elles restent surchargeables par le scope, comme
toute clé générique :

```dart
ZcrudScope(
  labels: ZcrudLabels(<String, String>{
    'selectedCount': 'éléments retenus',
  }),
  child: monEcran,
)
```

### Export {#export}

L'écran n'exporte rien par défaut, et n'en sait rien faire : produire un
`.xlsx` ou un `.pdf` demande des bibliothèques lourdes, qu'aucune application
ne doit payer sans les avoir demandées. `zcrud_screen` ne connaît que le port
`ZListExporter` du socle — il **ne dépend d'aucun paquet d'export**.

#### Déclarer un format

```dart
ZCrudScreen<Consignataire>(
  title: 'Consignataires',
  source: ZCrudSource.repository(repo),
  registry: registry,
  export: ZExportPolicy(
    exporters: const <ZListExporter>[
      ZCsvListExporter(),   // zcrud_export      — Dart pur, aucun moteur
      ZXlsxListExporter(),  // zcrud_export      — Excel
      ZPdfListExporter(),   // zcrud_export_pdf  — PDF
    ],
    onExported: (context, fichier) => monPartage(fichier),
  ),
)
```

Un format déclaré = une entrée « Exporter (CSV) » dans le menu de débordement
de l'app-bar, dans l'ordre de déclaration. **Aucun format déclaré = aucune
entrée**, aucun menu, et rien de la mécanique d'export n'est construit. Deux
exporteurs de même `id` désignent le même format : seul le premier est offert.

Les exporteurs vivent dans les paquets d'export — c'est l'**application** qui
en déclare la dépendance, jamais `zcrud_screen`. Un exporteur maison
s'implémente en réalisant `ZListExporter` : rien n'oblige à passer par ces
paquets.

#### Où va le fichier

`onExported` reçoit un `ZExportedBytes` — octets, nom de fichier suggéré, type
MIME — et **conclut le geste** : enregistrer, partager, imprimer, téléverser
sont des décisions de plateforme et de produit, jamais d'écran. Le paramètre est
requis : un export dont les octets n'iraient nulle part serait un geste sans
effet, indiscernable d'une panne.

Le nom du fichier dérive du titre de l'écran, réduit à des caractères sûrs
(`Consignataires` → `Consignataires.csv`) ; `fileBaseName` le remplace.

#### Ce qui est exporté

**Ce que l'utilisateur voit, et rien d'autre** :

| Entre dans le fichier | N'y entre pas |
|---|---|
| Les lignes **réellement listées** — tri, filtres, recherche et vue (vivants ou corbeille) déjà appliqués | Ce que la source contient au-delà de l'écran |
| Les colonnes **dérivées du schéma**, dans l'ordre affiché | Les champs d'identité (`isId`), écartés à la dérivation |
| Les valeurs **formatées**, telles qu'elles sont peintes — devise portée par la ligne, format composé | Les valeurs brutes |
| — | La colonne de **numéro d'ordre** (`#`), qui décrit une position d'écran |
| — | Les **cases à cocher** de sélection et les **boutons d'action** |

**Une sélection en cours restreint l'export** aux seuls éléments cochés, dans
l'ordre de l'écran : c'est la lecture attendue d'un export demandé sélection
faite. Vider la sélection rend l'export à la liste entière.

#### Ce qui ne peut pas arriver

- **Une liste vide** s'annonce (« Rien à exporter ») ; aucun exporteur n'est
  appelé, aucun fichier n'est remis.
- **Un exporteur en échec** — ou qui **lève** — s'annonce avec son motif.
  Aucune exception ne remonte, l'écran reste debout, `onExported` n'est pas
  appelé.

#### Droits

L'export est une **lecture** : il ne montre rien de plus que le listing déjà
affiché, et n'est offert que là où l'écran affiche ce listing
(`ZCrudAction.view`). Aucun droit propre à l'export n'est introduit — une
application qui veut le restreindre plus finement déclare, ou non, sa politique
selon le profil de l'utilisateur.

#### Libellés

Clés employées : `export`, `exportEmpty`, `exportFailed` — présentes dans les
tables `en`/`fr` du socle, surchargeables par `ZcrudScope(labels:)`. Le nom d'un
format (`CSV`, `Excel`, `PDF`) est le `labelKey` de son exporteur : un sigle ne
se traduit pas, et une clé inconnue des tables est rendue telle quelle.

### Lire ce qui est listé {#lecture-du-listing}

L'export intégré couvre le cas courant : les colonnes du schéma, formatées
comme à l'écran. Il ne sait pas produire **votre** document — en-tête maison,
regroupements par agent ou par déclarant, colonnes calculées, moteur de rendu
propre. Pour cela, il ne vous manque qu'une chose : **savoir ce que l'écran
liste**.

Sur la voie `items`, vous le savez déjà — c'est votre variable. Sur la voie
`repository`, c'est l'écran qui lit, filtre, cherche, trie et pagine. Relire la
source en parallèle donnerait **deux lectures, deux instants, deux règles de
filtrage à tenir d'accord** — et un document qui contredit la liste qu'il
prétend imprimer. `ZCrudScreenActions` publie donc la lecture que l'écran fait
déjà pour lui-même :

| Membre | Ce qu'il rend |
|---|---|
| `entitiesInView` | Les entités **actuellement listées**, dans l'ordre peint. |
| `entitiesInViewListenable` | La même lecture, **notifiée** quand elle change réellement. |
| `entitiesSelectedOrInView` | Les entités **cochées** si la sélection porte, celles listées sinon — la règle exacte de l'export intégré. |

#### Un document métier maison

```dart
IconButton(
  icon: const Icon(Icons.picture_as_pdf_outlined),
  tooltip: 'Imprimer la liste',
  onPressed: () async {
    // Depuis n'importe quel widget DESCENDANT de l'écran : une carte, un
    // en-tête (`header:`), un bouton de la barre d'actions.
    final actions = ZCrudScreenScope.maybeOf(context);
    if (actions == null) return;
    final demandes =
        actions.entitiesSelectedOrInView.whereType<DemandeDepotage>().toList();
    if (demandes.isEmpty) return;
    await imprimerListeDesDemandes(demandes); // votre moteur, vos en-têtes
  },
)
```

Un compteur qui suit la liste :

```dart
ValueListenableBuilder<List<ZEntity>>(
  valueListenable: actions.entitiesInViewListenable,
  builder: (context, entites, _) => Text('${entites.length} dossiers'),
)
```

#### Ce que la lecture garantit

- l'**ordre peint** — le tri demandé (`sortBy`) ou celui déclaré, tel qu'il est
  à l'écran ;
- la **portée** — les vivants en vue normale, les **supprimés** en vue
  corbeille, et l'**onglet actif** quand l'écran en assemble ;
- ce que la **recherche** et les **filtres** ont retenu, filtres permanents et
  post-filtre déclaré compris ;
- les **pages chargées** — « ce qui est listé » veut dire ce qui est listé :
  autant d'entités lues que de lignes rendues, jamais plus, jamais moins.
  C'est la même définition que celle de l'export intégré ;
- **écran qui ne montre rien** — chargement, erreur, liste vide, aucun
  résultat : la lecture est **vide**, jamais le rendu précédent. Un document ne
  part pas sur ce que l'utilisateur ne voit plus.

#### Ce qu'elle n'est pas

- **Pas un flux de données** : elle ne va pas chercher ce que l'écran n'a pas
  lu. Une page non chargée n'y est pas.
- **Pas un accès au contrôleur de liste** : c'est une **lecture**, pas une
  prise. Le tri et les filtres se demandent par `sortBy` et `filterBy`.
- **Pas une rétro-lecture du filtrage** : elle dit *ce qui* est retenu, jamais
  *pourquoi*.

`entitiesInViewListenable` n'entraîne pas le corps de l'écran : rien n'est
notifié tant que personne n'écoute, la notification n'est émise que si le
contenu **diffère** du précédent, et seul ce qui écoute se reconstruit
(invariant AD-2). Un écran qui ne lit rien se comporte exactement comme avant.
Le `ValueListenable` appartient à l'écran — ne le libérez pas.

### Formulaire seul et édition en fenêtre {#formulaire-seul}

L'écran assemblé n'est pas toujours la bonne maille. Deux besoins reviennent :
poser le **formulaire nu au milieu d'une page** que l'on compose soi-même, et
éditer des **données sans modèle typé** — un bloc de configuration, un filtre
avancé — dans une fenêtre qui **rend une carte de valeurs**.

#### Le formulaire, intégré dans votre page

`ZFormOnly` rend les champs, et rien d'autre : aucun `Scaffold`, aucune barre
d'application, aucun bouton d'enregistrement. Le pilotage se fait de
l'extérieur, par un `ZFormOnlyController` que votre page détient :

```dart
final _form = ZFormOnlyController(
  fields: motDePasseFields,
  initialValues: const <String, Object?>{'ancien': '', 'nouveau': ''},
);

@override
void dispose() {
  _form.dispose(); // vous l'avez créé, vous le libérez
  super.dispose();
}

@override
Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Bienvenue')),
      body: ZFormOnly(controller: _form),
      bottomNavigationBar: FilledButton(
        onPressed: () async {
          final valeurs = _form.submit();
          // Invalide : les messages sont affichés, rien n'est rendu.
          if (valeurs == null) return;
          await monService.changerMotDePasse(valeurs);
        },
        child: const Text('Valider'),
      ),
    );
```

Le contrôleur expose `validate()` (table `champ → message`, sans rien
afficher), `isValid`, `revealErrors()`, `values` (valeurs normalisées) et
`submit()` (valide puis rend les valeurs, ou `null`). Vous pouvez aussi ne rien
fournir — `ZFormOnly(fields: …)` crée son pilotage et le libère lui-même.

#### La fenêtre qui rend une carte de valeurs

`presentFormEdition` ouvre le même formulaire en **page, feuille ou dialogue**
— selon la même politique de présentation que le reste du socle — et retourne
`Map<String, dynamic>?` : les valeurs si l'utilisateur enregistre, `null` s'il
renonce.

```dart
final reglages = await presentFormEdition(
  context,
  fields: reglagesExportFields,
  initialValues: const <String, Object?>{'format': 'pdf', 'paysage': true},
  title: "Réglages d'export",
);
if (reglages != null) await monService.exporter(reglages);
```

#### Ce que contient la carte rendue

Les valeurs sont **validées puis normalisées**, jamais l'état brut des
contrôleurs de saisie :

- les types sont coercés (`'12,5'` sur un champ nombre ⇒ `12.5`) ;
- les dates sortent en ISO-8601, les heures en `HH:mm`, les plages en
  `{start, end}` ;
- les valeurs d'énumération sortent en camelCase (leur `name`) ;
- les champs **en lecture seule** et ceux qu'une **condition d'affichage
  masque** sont **absents** : ce qui n'était ni modifiable ni visible n'a pas
  été décidé par l'utilisateur ;
- un formulaire **invalide ne rend rien** : les messages s'affichent, la
  fenêtre reste ouverte, et l'appelant ne reçoit aucune donnée partielle.

C'est la **même** normalisation que celle de la sauvegarde de `ZCrudScreen`
(`zNormalizeFormValues`, de `zcrud_core`) : la forme des données ne dépend pas
de l'écran qui les a produites.

#### La même fenêtre, présentée en ÉTAPES

Un formulaire long se présente en assistant : `steps` déclare les étapes,
`fields` reste le **catalogue** complet. Les deux se **complètent** — une étape
ne porte pas de champs à elle, elle nomme ceux du catalogue qu'elle regroupe :

```dart
final escale = await presentFormEdition(
  context,
  fields: escaleFields, // le catalogue COMPLET, toutes étapes confondues
  steps: const <ZEditionStep>[
    ZEditionStep(title: 'Navire', fields: <String>['nom', 'pavillon']),
    ZEditionStep(title: 'Escale', fields: <String>['quai', 'arrivee']),
  ],
  title: 'Escale',
);
```

`stepperConfig` règle la présentation de l'assistant — bande verticale, toutes
les étapes dépliées, accordéon, gate de navigation :

```dart
stepperConfig: const ZStepperConfig(
  stepsDisplay: ZStepsDisplay.allExpanded, // toutes les étapes dépliées
  orientation: ZStepOrientation.vertical,
),
```

##### Quand le nombre d'étapes dépend des données

`steps` est une liste ordinaire, construite à l'appel comme n'importe quelle
autre — rien n'oblige à la connaître à la compilation. Une étape par type de
document présent s'écrit donc directement :

```dart
final documents = await presentFormEdition(
  context,
  fields: <ZFieldSpec>[
    for (final type in typesPresents)
      ZFieldSpec(
        name: 'doc_${type.code}',
        type: EditionFieldType.text,
        label: type.libelle,
      ),
  ],
  steps: <ZEditionStep>[
    for (final type in typesPresents)
      ZEditionStep(title: type.libelle, fields: <String>['doc_${type.code}']),
  ],
  title: 'Pièces du dossier',
);
```

##### Ce que les étapes ne changent PAS

La soumission valide et normalise le **catalogue entier**, pas l'étape
affichée. Concrètement :

- les valeurs de **toutes** les étapes sont rendues, y compris celles d'une
  étape que l'utilisateur n'a jamais ouverte ;
- un champ invalide dans une étape **non visitée** empêche l'enregistrement —
  rien n'est rendu, la fenêtre reste ouverte ;
- le bouton d'enregistrement du chrome reste disponible à tout moment, et le
  bouton final de la dernière étape soumet par la même voie ;
- renoncer rend `null`, étapes ou pas.

⚠️ Un champ du catalogue qu'**aucune** étape ne nomme n'est jamais affiché, mais
reste validé : s'il porte un validateur qui échoue, la fenêtre devient
insoumissible sans message visible. Le cas est signalé en mode développement —
ajoutez le champ à une étape, ou retirez son validateur.

#### Le corps composé par vos soins

Quand la présentation sort de ces deux formes — un corps mêlant formulaire et
contenu applicatif, un assistant maison, un récapitulatif en tête —
`bodyBuilder` rend la main. Vous montez le corps ; le socle garde le conteneur
adaptatif, le garde d'abandon, le chrome et le **contrat de sortie** :

```dart
final valeurs = await presentFormEdition(
  context,
  fields: escaleFields,
  bodyBuilder: (context, controller) => Column(
    children: <Widget>[
      const RappelReglementaire(),
      // Le MÊME contrôleur : c'est lui que la soumission lira.
      Expanded(child: ZFormOnly(controller: controller)),
    ],
  ),
  bodyFit: ZEditionBodyFit.scrollable, // votre corps défile lui-même
);
```

Tout ce que vous montez doit écrire dans **ce** contrôleur — un second
contrôleur ne serait jamais lu au moment d'enregistrer.

`bodyBuilder` et `steps` déclarent deux corps concurrents, et `sections` décrit
la mise en page d'un formulaire à plat (sous des étapes, chaque `ZEditionStep`
porte ses propres sections) : ces combinaisons sont **refusées par une
assertion** en développement. En production la préséance est définie et rien ne
lève — `bodyBuilder`, puis `steps`, puis le formulaire à plat.

#### Le repli des sections qui survit à la fermeture

Une section déclarée `collapsible` se replie. Sans rien de plus, ce repli meurt
avec la fenêtre : un agent qui replie « Finances » sur une fiche qu'il ouvre
trente fois par jour la retrouve dépliée à chaque ouverture.

`collapseStore` est l'endroit où ce repli est **conservé**. Le stockage
appartient à l'application — le socle n'en fournit ni n'en impose aucun : vous
branchez le vôtre derrière `ZSectionCollapseStore`, deux méthodes synchrones
qui ne lèvent jamais. L'unité persistée est le **titre** de la section repliée.

```dart
class ReplisPersistants extends ZSectionCollapseStore {
  @override
  Set<String> loadCollapsed(String? formId) => …; // les titres repliés
  @override
  void saveCollapsed(String? formId, Set<String> collapsed) => …;
}

await presentFormEdition(
  context,
  fields: ficheAgentFields,
  sections: const <ZEditionSection>[
    ZEditionSection(
      title: 'Finances',
      fields: <String>['salaire', 'prime'],
      collapsible: true,
    ),
  ],
  collapseStore: ReplisPersistants(),
  formId: 'fiche-agent',
);
```

`formId` est la **portée**. L'unité persistée étant le titre, deux formulaires
qui nomment tous deux une section « Finances » se marcheraient dessus sous une
portée commune ; un `formId` distinct les isole. `null` (défaut) ⇒ portée
globale, ce qui convient tant qu'un titre ne désigne qu'une seule chose dans
l'application. La valeur est opaque, transmise telle quelle à votre store.

Les deux paramètres existent à l'identique sur `ZFormOnly`, et suivent le corps
réellement monté : le formulaire à plat **et** l'assistant `steps` — chaque
étape recevant alors **sa propre portée**, dérivée de `formId` et du titre de
l'étape (une écriture remplaçant la portée entière, une portée commune ferait
effacer par la dernière étape repliée ce que les autres avaient enregistré). Un
`bodyBuilder`, lui, compose son corps : c'est à lui de les passer au `ZFormOnly`
ou au `DynamicEdition` qu'il monte.

Sans `collapseStore` (le défaut), **rien ne change** : ni lecture, ni écriture,
et le repli reste celui de la vie du widget.

⚠️ La surface d'édition de `ZCrudScreen` ne porte pas ces paramètres, et c'est
délibéré : son formulaire ne déclare aucune section, donc rien n'y est
repliable et un store n'y serait jamais ni lu ni écrit.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZCrudScreen<T>` | Écran CRUD assemblé : liste + recherche + création + édition + sauvegarde + corbeille, depuis une déclaration. |
| `ZCrudSource<T>` | Source déclarative : `.repository(ZRepository<T>)`, `.readOnlyRepository(ZRepository<T>)` (ressource immuable : lecture entière, `canWrite`/`supportsTrash`/`supportsPurge` tous `false`) ou `.items(List<T>, callbacks…)`. |
| `ZScreenMode` | Mode de l'écran : `full` (défaut) / `details` (fiche de détail, retour vers l'édition selon l'ACL) / `locked` (consultation verrouillée). Remplace `readOnly`, déprécié. |
| `ZCrudEditionScope` | Transport du drapeau de lecture jusqu'au formulaire — `ZCrudEditionScope.readOnlyOf(context)` dans un `editionBuilder`. |
| `ZCrudScreenScope` | Contexte posé autour du corps de l'écran — `ZCrudScreenScope.maybeOf(context)` donne ses gestes à n'importe quelle carte descendante (`null` hors écran). |
| `ZCrudScreenActions` | Les gestes de l'écran : `canOpenEdition`/`openEdition`/`editionOpener`, `canOpenUpdate`/`openUpdate`/`updateOpener`, `canOpenCreation`/`openCreation`/`creationOpener`, plus `sortBy` (remplace le tri par défaut) et `filterBy` (s'ajoute aux filtres permanents). Aucun ne lève ; un geste refusé est `false`, `null` ou une ouverture inerte. |
| `entitiesInView` / `entitiesInViewListenable` / `entitiesSelectedOrInView` | La **lecture du listing** (`ZCrudScreenActions`) : ce que l'écran liste, dans l'ordre peint, portée et pages chargées comprises — synchrone, notifiée, ou restreinte par la sélection comme l'export intégré. Écran vidé ⇒ lecture vide. Voir [Lire ce qui est listé](#lecture-du-listing). |
| `zCrudEditionOpener(context, entity)` | Raccourci du cas courant : le rappel d'ouverture, ou `null` si le geste n'est pas possible. |
| `ZCrudOpener` | `Future<void> Function()` — une ouverture déjà liée à son élément. |
| `ZTrashMode` | Activation de la corbeille : `auto` (dès que la source la supporte) / `none`. |
| `ZTrashPolicy` | Gestes offerts par la corbeille : `full` (défaut), `withoutPurge`, `readOnly`, ou combinaison libre ; plus `showCount` (pastille de comptage) et `visibleWhenEmpty` (accès masqué à corbeille vide). |
| `trashCount` (`ValueListenable<int>?`) | Nombre d'éléments en corbeille fourni par l'application : pastille sur le bouton d'accès, et condition de visibilité. Dérivé gratuitement sur la voie `items`. |
| `ZListQueryPolicy` (`query`) | Tri par défaut (`sort`), filtres permanents (`baseFilters`), taille de page (`pageSize`) et sémantique de recherche (`searchScope`, `searchFolding` ; raccourci `ZListQueryPolicy.legacySearch()`) et voie de pagination (`paginationMode`) du listing. `filtersWith` ajoute, `sortFor` remplace ; `ZListQueryPolicy.of(context)` la rend aux vues que l'application pose sous l'écran (page d'onglet). Rien de déclaré ⇒ requêtes strictement inchangées. |
| `ZListTab` (`tabs`) | Onglet de catégorisation : `labelKey`, `builder`, `pageKey`, `canCreate`, `defaultItemBuilder`, plus `acl` (restriction du segment), `titles` (intitulés du formulaire) et `countOf` (pastille de comptage). |
| `ZRestrictedAcl` / `zRestrictAcl` | Composition **conjonctive** de deux `ZAcl` — la cascade onglet > écran > scope. L'élargissement y est inexprimable. |
| `ZPurgeable<T>` | Mixin optionnel du dépôt déclarant la **suppression définitive** (hors du port `ZRepository`). |
| `ZCrudTitles` | Titres à quatre états de la surface d'édition (`create` / `copy` / `update` / `read`), replis l10n génériques quand `null`. |
| `ZCrudSave<T>` | Persistance (upsert) d'une entité — `onSave` de l'écran et de la source. |
| `ZCrudTrashWrite<T>` | Écriture de corbeille déléguée (voie items) : `(BuildContext, T)`. Le contexte est celui de la ligne — confirmation maison, notification ou navigation sans capturer un contexte externe. |
| `ZCrudEditionBuilder<T>` | Fabrique du formulaire applicatif — voie d'échappement de l'édition dérivée. |
| `ZCrudItemBuilder<T>` | Rendu d'une tuile (reçoit l'entité `T`) — voie d'échappement de la tuile générique, **transmise au `layout` déclaré** (grille de cartes comprise). |
| `rowAcl` (`ZRowAclResolver<T>`) | Gouvernance **par ligne** : les droits propres à chaque entité, en intersection avec l'ACL. Gouverne la vue vivante, la corbeille, les boutons et le menu. |
| `selection` (`ZSelectionPolicy?`) | Sélection multiple : `mode`, `showSelectAll`, `onReport`. `null` (défaut) ⇒ aucune sélection, écran inchangé. |
| `batchActions` (`ZCrudBatchActions<T>?`) | Actions de masse supplémentaires de l'application, construites avec les entités sélectionnées. |
| `export` (`ZExportPolicy?`) | Export du listing : `exporters` (les formats offerts, ordre conservé, dédoublonnés par `id`), `onExported` (remise du fichier — requis), `fileBaseName`. `null` (défaut) ⇒ aucune entrée d'export, aucune dépendance tirée. |
| `ZCrudExportDelivery` | `FutureOr<void> Function(BuildContext, ZExportedBytes)` — la remise du fichier produit à l'application. |
| `ZFormOnly` | Le formulaire déclaratif **nu** : les champs, sans coquille ni bouton. `controller` (pilotage de la page) ou `fields` (pilotage possédé et libéré par le widget). `collapseStore` + `formId` conservent le repli des sections d'une ouverture à la suivante ; `null` (défaut) ⇒ aucune lecture, aucune écriture. |
| `ZFormOnlyController` | Pilotage extérieur d'un `ZFormOnly` : `validate()`, `isValid`, `revealErrors()`, `values` (normalisées), `submit()` (valeurs ou `null`), `isDirty`, `form` (le `ZFormController` sous-jacent). |
| `presentFormEdition(...)` | Présente un formulaire en page/feuille/dialogue et rend `Map<String, dynamic>?` — les valeurs validées et normalisées, ou `null` si l'utilisateur renonce. Trois corps possibles : `fields` seuls (formulaire à plat), `fields` + `steps` (assistant multi-étapes, `stepperConfig` pour sa présentation), ou `bodyBuilder` (corps composé par l'appelant). `collapseStore` + `formId` (facultatifs) conservent le repli des sections — voir [Le repli des sections qui survit à la fermeture](#le-repli-des-sections-qui-survit-à-la-fermeture). |
| `ZFormBodyBuilder` | `Widget Function(BuildContext, ZFormOnlyController)` — le corps que vous composez pour `presentFormEdition`, sur le contrôleur que la soumission lira. |
| `ZRowPermissions` | Ce qu'une ligne **retire** : `.unrestricted()`, `.locked()`, `.denying({…})`, avec `reasonKey` facultatif. Aucun vocabulaire d'autorisation — un résolveur ne peut jamais élargir. |

Paramètres notables hérités du socle : `actions` (`List<ZAppBarAction>` de
`zcrud_ui_kit`, débordement compris) et `confirmDestructive` (défaut `true`).
`appBarActions` (widgets déjà construits) est **déprécié** au profit de
`actions` : un widget opaque ne peut être transmis à l'app-bar du socle
qu'emballé, ce qui masque sa sémantique propre et élargit sa boîte
(48 → 64 dp) — le tap, lui, reste fonctionnel (mesuré).

## Cas limites et invariants {#cas-limites}

- **Lecture seule par déclaration** : `mode: ZScreenMode.locked` (consultation
  verrouillée), `mode: ZScreenMode.details` (fiche de détail, édition selon
  l'ACL), `canCreate: false`, `trash: ZTrashMode.none`,
  `ZCrudSource.items(rows)` sans callbacks, ou
  `ZCrudSource.readOnlyRepository(repo)` (ressource immuable **servie par un
  dépôt** : lecture, pagination et recherche entières, aucune écriture, quelle
  que soit l'ACL) — un journal immuable ou un référentiel distant en lecture
  seule s'écrivent sans contournement.
- **ACL partout** (invariant AD-16) : bouton de création (`ZCrudAction.create`),
  actions de ligne (`update`/`delete`/`restore`/`clear` — masquées par défaut,
  grisables via `actionAclMode`), bascule corbeille. `acl` non fourni ⇒ l'ACL
  du `ZcrudScope` ambiant s'applique.
- **Jamais d'exception de persistance** (invariants AD-10/AD-11) : un échec de
  `repository.save` (ou un callback hôte qui lève) est replié en `ZFailure`
  et **affiché dans la surface d'édition** (zone annoncée, `liveRegion`), qui
  reste ouverte. Exception : la voie `editionBuilder` reçoit un `save` qui
  lève un `StateError` sur échec — le formulaire applicatif reste maître de
  son affichage.
- **Déclaration incomplète = erreur actionnable** : sans registre ni
  `listFields`/`cellsOf`, l'écran lève une `ZScopeError` nommant le paramètre
  manquant — jamais un écran vide silencieux.
- **Réactivité granulaire** (invariant AD-2) : contrôleurs possédés par des
  `State` (create/dispose), liste écoutée sur sa seule tranche
  `ValueListenable<ZListViewState>`, formulaire réactif par tranche
  (`ZFormController`), bouton de création re-évalué par `ValueListenable`
  (onglets).
- **Onglets** : `tabs` non-`null` ⇒ le corps est un `ZTabbedList` ; la création
  lit `canCreate`, `defaultItemBuilder`, `acl` et `titles` de l'onglet **actif**
  (`Map` de valeurs ou entité `T`). Un onglet **assemblé** (`builder` absent)
  reçoit la liste de l'écran, ses actions de ligne, la recherche partagée et la
  corbeille catégorisée ; un onglet **à `builder`** reste opaque — l'écran n'y
  accroche rien, et un seul onglet opaque retire la recherche partagée et les
  onglets de corbeille à l'écran entier. L'ACL d'un onglet **restreint** celle
  de l'écran, jamais l'inverse.
- **Corbeille** : l'accès s'ouvre sur `restore` **ou** `clear`, jamais sur
  `delete` seul. `ZTrashPolicy(visibleWhenEmpty: false)` le retire à corbeille
  vide, à condition que le compte soit connu (`trashCount`, ou voie `items`).
- **Purge définitive absente** : `ZRepository` n'expose pas de suppression
  dure ; l'action « vider » se branche via `rowActions` (action custom) le cas
  échéant — elle relève alors de l'hôte, y compris sa confirmation
  (`showZConfirmDialog` reste à sa disposition).
- **Confirmation destructive** : demandée avant toute mise à la corbeille
  (`confirmDestructive: true` par défaut) ; une annulation ne produit
  **aucune** écriture. La restauration n'est pas confirmée.
- **Notification sans dépendance** : un échec d'action de ligne passe par le
  port `ZToaster` ; sans `ZToasterScope` ni `ScaffoldMessenger` atteignable,
  le repli est **silencieux** et documenté, jamais une exception.
- **Actions de masse** : un lot ne dit jamais « fait » quand une partie a
  échoué — le compte rendu porte succès, échecs, éléments écartés et nomme les
  échecs (`ZBatchReport` complet via `ZSelectionPolicy.onReport`). Un élément
  que la gouvernance n'admet pas est **exclu du lot**, jamais écrit en silence.
  La sélection est vidée après l'action et au changement de vue.
- **RTL / a11y** (invariant AD-13) : primitives directionnelles, `Semantics`
  explicites, cibles ≥ 48 dp. Aucune couleur codée en dur (rôles du thème).

## Voir aussi {#voir-aussi}

- Fiche du paquet : `docs/site/paquets/zcrud_screen.md` (dépôt zcrud).
- `zcrud_core` — `DynamicList`, `ZListController`, `ZRowAction`,
  `DynamicEdition`, `ZcrudRegistry` : les briques assemblées ici.
- `zcrud_navigation` — `presentEdition`, `ZPresentationPolicy`, `ZFormWeight`.
- `zcrud_list` — backend de **rendu** Syncfusion du port `ZListRenderer`
  (à injecter si vous utilisez le layout `dataGrid`).

## Licence {#licence}

MIT — voir la racine du dépôt.
