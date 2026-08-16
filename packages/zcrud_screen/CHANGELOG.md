# Changelog

Toutes les modifications notables de `zcrud_screen` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 1.6.0 — 2026-08-16

### Ajouté

#### `drawer` / `endDrawer` — l'écran assemblé peut porter la navigation de l'hôte

`ZPageScaffold` acceptait déjà `drawer` et `endDrawer` et les passait à son
`Scaffold` ; `ZCrudScreen` **ne les exposait pas**. Une application dont la
navigation entre modules passe par un menu latéral ne pouvait donc plus
l'atteindre depuis un écran migré — sur un téléphone, ni bouton hamburger, ni
ouverture par glissement.

Les deux paramètres sont désormais relayés **tels quels**, et aux **deux**
surfaces montées par l'écran : la coquille nominale **et** l'écran « accès
refusé ». Ce second site était le plus grave — un refus d'ACL rendait un écran
sans contenu *et* sans navigation.

Défaut `null` ⇒ comportement **strictement inchangé**, aucune rupture.

- Le paquet **ne fournit aucun menu** : la navigation appartient à
  l'application, avec son ACL et son responsive.
- Le bouton d'ouverture est inséré par **Material** (`automaticallyImplyLeading`),
  jamais réimplémenté : un `leading` déclaré par l'hôte continue donc de primer,
  comme partout ailleurs dans Flutter.
- **En vue corbeille**, le bouton de retour occupe le `leading` : Material
  n'insère pas le bouton de menu, et le tiroir reste ouvrable **par glissement
  depuis le bord**. Sortir de la corbeille prime sur changer de module. Le bouton
  de menu **revient** au retour aux vivants. Comportement documenté et gardé.

## 1.3.0 — 2026-08-16

### Ajouté

#### L'écran assemblé dit enfin ce qu'il liste

Sur la voie `items`, l'application détient la liste : ce qu'elle imprime et ce
que l'écran rend sont la même variable, au même instant. Sur la voie
`repository`, ce lien se coupait — l'écran lit, filtre, cherche, trie et
pagine, et rien ne revenait. Une application dont la liste alimente autre chose
que l'écran — un document signé, un compte, un tableau de bord — n'avait qu'un
recours : relire la source en parallèle. Deux lectures, deux instants, deux
règles de filtrage à tenir d'accord ; et un document qui contredit la liste
qu'il prétend imprimer quitte l'écran et circule.

`ZCrudScreenActions` publie désormais la lecture que l'écran faisait déjà pour
son propre export :

```dart
final actions = ZCrudScreenScope.maybeOf(context);
final demandes =
    actions!.entitiesSelectedOrInView.whereType<DemandeDepotage>().toList();
await imprimerListeDesDemandes(demandes); // votre moteur, vos en-têtes
```

| Membre | Ce qu'il rend |
|---|---|
| `entitiesInView` | Les entités **actuellement listées**, dans l'ordre peint. |
| `entitiesInViewListenable` | La même lecture, **notifiée** quand elle change réellement. |
| `entitiesSelectedOrInView` | Les entités **cochées** si la sélection porte, celles listées sinon — la règle exacte de l'export intégré. |

**Ce que la lecture garantit** : l'ordre **peint** (tri demandé ou déclaré) ; la
**portée** (les supprimés en vue corbeille, l'onglet **actif** en mode onglets) ;
ce que la recherche et les filtres ont retenu, filtres permanents et post-filtre
compris ; les **pages chargées** — autant d'entités lues que de lignes rendues,
jamais plus, jamais moins, exactement la définition qu'emploie déjà l'export
intégré. **Écran qui ne montre rien** (chargement, erreur, liste vide, aucun
résultat) ⇒ lecture **vide**, jamais le rendu précédent.

**Ce qu'elle n'est pas** : ni un flux de données (elle ne va pas chercher ce que
l'écran n'a pas lu), ni un accès au contrôleur de liste — c'est une lecture, pas
une prise ; le tri et les filtres se demandent toujours par `sortBy` et
`filterBy`.

`entitiesInViewListenable` n'entraîne pas le corps de l'écran : rien n'est
notifié tant que personne n'écoute, la notification n'est émise que si le
**contenu** diffère du précédent (pas l'identité de la liste), et seul ce qui
écoute se reconstruit (invariant AD-2). Mesuré : un écran abonné construit
**exactement autant** de tuiles qu'un écran qui ne lit rien, au repos comme sur
un changement réel de la liste.

Voir la section **Lire ce qui est listé** du README.

### Impact sur votre code

**Ajout pur.** Aucun écran existant ne change de comportement : un écran qui ne
lit pas ces membres construit le même nombre de widgets qu'avant, n'arme aucune
notification et n'expose rien de plus. L'export intégré (`ZExportPolicy`,
`ZListExporter`) est **inchangé**, la voie `items` aussi.

Si vous **compensiez** ce manque en relisant le dépôt en parallèle de l'écran —
un `StreamProvider`, un cas d'usage « périmètre courant », une requête doublée
pour vos exports — cette compensation est désormais **en trop**, et c'est elle
qui portait le risque de divergence : retirez-la au profit de `entitiesInView`.
Un point d'attention : votre lecture parallèle ignorait probablement la
recherche plein texte et la page courante, que seule la lecture de l'écran
connaît — les chiffres peuvent donc **changer** en migrant, dans le sens de la
justesse.

`ZCrudScreenActions` gagne trois membres. C'est une interface **implémentée par
l'écran**, jamais par une application : si vous en aviez fait une implémentation
maison (un double de test, par exemple), complétez-la.

## 1.1.0 — 2026-08-16

### Ajouté

#### Une fenêtre de formulaire peut enfin être un assistant à étapes

`presentFormEdition` ne savait présenter que des champs **à plat**. L'assistant
multi-étapes existait pourtant dans le socle (`ZStepperEdition`), mais comme
widget à monter soi-même : il n'était pas atteignable depuis la présentation de
formulaire, celle-là même que les migrations d'édition emploient partout. Un
écran à étapes restait donc sur son moteur d'origine — non pas faute de brique,
faute de chemin.

`steps` ouvre ce chemin. Le catalogue reste `fields` ; les étapes n'en nomment
que des sous-ensembles :

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

`steps` et `fields` se **complètent**, ils ne s'excluent pas : une étape est une
mise en page, pas une seconde déclaration de champs. `stepperConfig` règle la
présentation de l'assistant — bande verticale, toutes les étapes dépliées,
accordéon, gate de navigation.

**Le nombre d'étapes peut dépendre des données.** `steps` est une liste
ordinaire, construite à l'appel : une étape par type de document présent
s'écrit sans détour, et rien n'exige de connaître le compte à la compilation.

**Le contrat de sortie ne bouge pas d'un iota.** La soumission valide et
normalise le **catalogue entier**, jamais la seule étape affichée : les valeurs
de toutes les étapes sont rendues, et un champ invalide dans une étape **que
l'utilisateur n'a jamais ouverte** empêche l'enregistrement. Renoncer rend
toujours `null`.

⚠️ Un champ du catalogue qu'**aucune** étape ne nomme n'est jamais affiché mais
reste validé : s'il porte un validateur qui échoue, la fenêtre devient
insoumissible sans message visible. Le cas est signalé en mode développement.

#### Un corps de fenêtre composé par l'appelant

Pour tout ce qui sort de ces deux formes — un corps mêlant formulaire et contenu
applicatif, un assistant maison, un récapitulatif en tête — `bodyBuilder` rend
la main sans faire perdre le reste :

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

Le conteneur adaptatif, le garde d'abandon, le chrome et le contrat de sortie
restent ceux du socle. `bodyFit` déclare comment votre corps veut être placé —
`null` (défaut) le **dérive** : `intrinsic` pour un formulaire à plat et pour un
`bodyBuilder`, `scrollable` pour un assistant.

`bodyBuilder` et `steps` déclarent deux corps concurrents, et `sections` décrit
la mise en page d'un formulaire à plat : ces combinaisons sont **refusées par
une assertion** en développement. En production la préséance est définie et rien
ne lève — `bodyBuilder`, puis `steps`, puis le formulaire à plat.

### Impact sur votre code

**Hôte passif** : rien à faire. Sans `steps` ni `bodyBuilder`, `presentFormEdition`
rend le même arbre qu'avant, avec le même `bodyFit` — un test le vérifie.

**Hôte qui avait contourné le manque** : si vous montiez vous-même un
`ZStepperEdition` dans un `presentEdition` maison pour obtenir un assistant qui
rende une carte de valeurs, `steps` remplace ce montage — et surtout sa
soumission, qui devait re-valider le catalogue entier à la main. Vérifiez que
votre contournement n'ajoute plus sa propre validation par-dessus celle du
socle : les deux ensemble révéleraient les erreurs deux fois.

## 1.0.0 — 2026-08-14

### Ajouté

#### Une ressource qui ne s'écrit pas peut enfin passer par un dépôt

Sur `ZCrudSource.items`, l'absence d'écriture se **déclare** : une source sans
rappel n'offre ni création, ni édition, ni corbeille, et cela se vérifie par un
test. Sur `ZCrudSource.repository`, cette expression disparaissait — brancher un
dépôt, serait-ce uniquement pour lire, paginer et chercher, faisait déclarer à
l'écran qu'il savait écrire **et** servir une corbeille.

Un écran sur ressource immuable — un journal d'opérations horodatées, un
référentiel servi par un tiers — n'avait donc que deux issues : rester sur la
voie `items` en renonçant à la pagination et à la recherche serveur, ou tenir
son invariant d'immuabilité par une **omission** (pas de `registry`, donc pas de
formulaire dérivable). La seconde n'en est pas une : un invariant qui repose sur
ce qui manque saute au premier refactoring, sans bruit.

Une troisième fabrique le dit :

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
création, ni action d'édition, ni duplication, ni bascule corbeille, ni action
de masse d'écriture ; ses gestes programmatiques
(`ZCrudScreenActions.openCreation` / `openEdition` / `openUpdate`) restent
inertes, et le dépôt ne reçoit rien. Le registre peut être fourni et la fiche de
détail offerte : il n'y a toujours **aucune voie d'écriture** à emprunter — la
séparation est structurelle, le dépôt de lecture et le dépôt d'écriture ne sont
plus le même objet.

Lecture, pagination par curseur, tri, recherche serveur et périmètre de requête
sont intacts : c'est la contrepartie qu'on n'a plus à payer pour exprimer
l'immuabilité. La consultation reste entière — `detailsEnabled: true` ouvre le
formulaire complet en lecture, sans retour vers l'édition.

**Ce n'est pas une ACL, et cela ne doit pas en devenir une.** Une ACL gouverne
**qui** a le droit d'agir : elle se paramètre par usager, et un profil
administrateur finit toujours par obtenir le geste qu'elle refusait aux autres.
Cette fabrique parle de **ce que la ressource permet**. Un journal immuable
n'est pas « un CRUD interdit à tout le monde » : c'est une ressource dont
l'écriture n'existe pas. Le geste n'est donc offert à personne — pas même sous
une ACL tout-accordée.

#### Une clause que seule la base sait trancher

Dès qu'un listing est servi en mémoire — parce qu'il déclare un `itemFilter`,
une disjonction, le mode mémoire, ou simplement parce qu'une recherche est en
cours — les filtres de la requête sont **ré-appliqués** aux lignes projetées :
c'est ce qui les rend exacts devant une source qui ne les traduit pas. Mais une
clause qui vise un champ **absent de la ligne** — une valeur calculée, jamais
persistée, ou une colonne que l'écran n'affiche pas — n'y trouve rien, et **vide
le listing dès le premier rendu**. Le seul contournement était d'ajouter une
colonne « pont » au seul bénéfice du filtre.

`ZFilter.servedBySource` déclare l'exception :

```dart
// `etat_depotage` est calculé côté source : aucune colonne ne le porte.
query: const ZListQueryPolicy(
  baseFilters: <ZFilter>[
    ZFilter.servedBySource('etat_depotage', ZFilterOp.isIn, <String>['termine']),
  ],
),
```

La clause part dans la requête comme n'importe quelle autre — un adaptateur la
traduit sans avoir à la distinguer — et le socle ne la rejoue **jamais** sur les
lignes. Le listing filtre à la lecture, sans colonne-pont et sans se vider.

⚠️ **C'est une promesse faite à la source, pas une garantie du socle.** Devant
un dépôt qui ne la sert pas — ou sur la voie `ZCrudSource.items`, où il n'y a
pas de source à qui adresser la promesse — la clause ne filtre **rien**, et
l'écran montre plus que ce qui a été déclaré, sans erreur ni avertissement. À
réserver aux clauses dont votre dépôt est connu capable ; partout ailleurs, une
clause ordinaire — ré-appliquée, donc exacte — ou un `itemFilter` restent les
bonnes voies.

### Impact

**Rien à changer** si vous n'avez rien contourné : `ZCrudSource.repository`
garde exactement son comportement — c'est le cas courant, et il continue
d'ouvrir l'écriture. Seule la nouvelle fabrique retire les gestes.

**Si vous compensiez** ce défaut, la compensation s'ajoute désormais au
correctif et doit être **retirée** :

* un écran laissé sur `ZCrudSource.items` uniquement pour éviter de déclarer une
  écriture interdite peut passer sur `ZCrudSource.readOnlyRepository` et
  récupérer pagination et recherche serveur ;
* un `registry` délibérément **omis** pour empêcher l'ouverture d'un formulaire
  peut être rétabli : la fiche de détail redevient disponible sans rouvrir
  l'écriture ;
* une ACL qui refusait `create`/`update`/`delete` à **tout le monde** dans le
  seul but de fermer une ressource immuable n'a plus lieu d'être : elle mélangeait
  la personne et la ressource, et laissait le geste offert à un administrateur.

### Corrigé

#### Un écran trié sur une date facultative perdait, en silence, ses lignes non datées

Quand le listing d'un écran est servi en mémoire, le jeu est lu **en entier**
puis ordonné par le moteur du socle. Le tri déclaré partait pourtant **aussi** à
la source, où il ne servait plus à rien : l'ordre final était de toute façon
recalculé.

Il n'était pas sans effet pour autant. Sur un backend documentaire, un ordre
serveur **exclut** les documents dépourvus du champ trié : `ZListQueryPolicy`
triée sur une date facultative retranchait donc de l'écran toutes les lignes non
datées — sans message, sans erreur, sans rien qui distingue « il n'y en a pas »
de « elles ont été écartées ». Restait une alternative sans issue : déclarer le
tri et amputer la liste, ou renoncer à l'ordre.

La requête d'une lecture servie en mémoire ne porte plus de tri. L'ordre demandé
est rendu par le moteur du socle, qui **classe** les valeurs absentes au lieu de
les retrancher — dernières en ordre croissant, premières en décroissant. Un
écran affiche donc tout ce qu'il a lu, et aucun index composite n'est exigé pour
un tri qui ne s'applique qu'en mémoire. Un écran à périmètre requêtable, lui,
garde son tri **et** sa pagination **serveur**, à l'identique.

⚠️ **Si vous compensiez** ce défaut, la compensation s'ajoute désormais au
correctif et doit être **retirée** : un écran qui renonçait au tri déclaré pour
ne pas perdre ses lignes peut le déclarer ; un tri ré-appliqué après coup, ou
des lignes non datées réinjectées à la main dans le rendu, feraient maintenant
double emploi. Un écran qui déclarait simplement son tri en attendant qu'il
s'applique n'a rien à faire — il retrouve ses lignes.

## 0.99.0 — 2026-08-14

### Ajouté

#### L'écran dit enfin le dernier mot sur ce qu'il montre

Sur `ZCrudSource.items`, l'application remet une liste **déjà constituée** :
elle peut la calculer comme elle veut, puis la confier à l'écran. Sur
`ZCrudSource.repository`, ce point disparaissait — le périmètre était
entièrement dérivé de la requête, et la voie nominale n'était donc ouverte
qu'aux écrans dont le périmètre s'exprime en clauses. Sur un parc métier, c'est
une minorité : le dernier mot appartient souvent au métier, et il s'écrit en
Dart.

`ZListQueryPolicy` porte désormais deux déclarations de plus :

* **`baseFilterGroups`** — des disjonctions permanentes, pour la règle que la
  conjonction ne sait pas dire : « cet état **ou** ce champ jamais renseigné ».
  C'est le cas le plus courant d'un workflow, *l'état initial étant l'absence
  d'état* : l'onglet d'entrée exprimé par la seule égalité se vidait des
  dossiers fraîchement déposés, silencieusement ;
* **`itemFilter`** — un **post-filtre** écrit sur l'entité typée
  (`ZItemFilter.of(...)`), appliqué aux entités lues avant leur projection en
  lignes.

```dart
// Déclaré une fois, HORS du `build`.
bool _visiblePour(Dossier dossier) => dossier.habilitations.contains(agent);

ZCrudScreen<Dossier>(
  source: ZCrudSource.repository(repo),
  query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_visiblePour)),
  tabs: const <ZListTab>[
    ZListTab(
      labelKey: 'enAttente',
      baseFilterGroups: <ZFilterGroup>[
        ZFilterGroup.any(<ZFilter>[
          ZFilter('etat', ZFilterOp.eq, 'enAttente'),
          ZFilter('etat', ZFilterOp.isNull),
        ]),
      ],
    ),
  ],
);
```

Les deux se déclarent aussi **par onglet** (`ZListTab.baseFilterGroups`,
`ZListTab.itemFilter`) et se composent avec ceux de l'écran comme se composent
les droits : l'onglet **retire**, il ne rouvre jamais ce que l'écran a écarté.
Le post-filtre vaut pour les deux voies de données — la voie `items` l'applique
elle aussi, une déclaration de périmètre valant pour l'écran et non pour une
source.

**Ce que cela coûte, et quand ne pas en déclarer.** Ni une disjonction ni un
prédicat Dart ne sont réputés traduisibles par la source : en déclarer un fait
**basculer le listing sur le chemin mémoire**, où le jeu entier est lu à chaque
requête, pour toute la vie de l'écran. Le socle préfère ce coût à une
déclaration de périmètre silencieusement ignorée par la pagination curseur —
un écran qui montre plus que ce qui a été déclaré. Dès que la règle s'exprime
en clauses, `baseFilters` reste le bon outil : servi par la source, pagination
curseur intacte, seule la page affichée est lue. La section « Ce qui filtre,
sur quelle voie, à quel coût » du README détaille le compromis.

⚠️ **Déclarez le prédicat hors du `build`** : deux politiques sont comparées
par valeur, et une lambda recréée à chaque image rechargerait le listing sans
fin. Une fonction nommée reste égale à elle-même.

**Étiez-vous touché ?** Non : rien de déclaré, rien de changé. Un écran sans
post-filtre ni disjonction émet exactement les mêmes requêtes qu'avant,
pagination serveur comprise.

## 0.98.0 — 2026-08-14

### Corrigé

#### Les données d'un écran partaient dans une collection que rien ne relisait

`ZCrudScreen` transmettait son `collectionId` à `repository.save`. Sur un
adaptateur qui honore ce paramètre — c'est le cas de `FirebaseZRepositoryImpl`,
où il désigne un **chemin de collection** — la valeur déclarée pour gouverner
les droits de l'écran devenait la destination des écritures. Un écran déclarant
`collectionId: 'ships'` sur un dépôt configuré `collectionPath: 'bmd_ships'`
écrivait dans `ships`.

C'était une **perte de données**, et une perte silencieuse : l'enregistrement
réussissait (`Right`, aucune erreur, aucun avertissement) tandis que les
lectures continuaient d'interroger le chemin du dépôt. La liste n'affichait
donc jamais ce qui venait d'être saisi, et l'usager en concluait que sa saisie
n'avait pas été enregistrée. Elle l'était — ailleurs, dans une collection créée
à la volée que ni la liste, ni la corbeille, ni aucun export ne relisent.

`ZCrudScreen.collectionId` gouverne désormais l'**autorisation** et rien
d'autre : il continue d'être soumis à `ZAcl.can` pour toutes les décisions de
l'écran (consultation, création, édition, corbeille, purge), et n'est plus
transmis à aucune écriture. Un dépôt sait déjà où il écrit.

**Étiez-vous touché ?** Uniquement si vos écritures passaient par le socle,
c'est-à-dire si votre écran déclare à la fois un `collectionId` et une
`ZCrudSource.repository(...)` branchée sur un adaptateur qui honore le
paramètre, **et** ne détourne pas la sauvegarde par `onSave`. Le signe
caractéristique, côté backend : une collection portant exactement le nom de
votre clé d'autorisation, contenant les documents absents de votre collection
métier. Les écrans sur `ZCrudSource.items(...)` et ceux qui persistent par
`onSave` n'ont jamais été concernés — leur voie de sauvegarde était déjà la
leur.

**Que faire des documents déjà égarés ?** Ils sont intacts et complets : seul
leur emplacement est faux. Avant toute chose, relevez le contenu de la
collection homonyme de votre clé d'autorisation, elle n'est visible d'aucune de
vos vues. Rapatriez ensuite ces documents dans la collection déclarée par le
`collectionPath` de votre dépôt, en conservant leur identifiant : les corps
écrits par le socle portent déjà leur `id` logique et leurs métadonnées de
synchronisation, ils sont relus tels quels une fois au bon endroit. Traitez les
collisions d'identifiant comme votre politique de fusion l'exige — le socle ne
peut pas arbitrer à votre place. Supprimez enfin la collection fantôme, sans
quoi une prochaine reprise la relira comme une source légitime.

**Si vous aviez contourné le défaut** — par exemple en persistant via `onSave`
pour appeler `repository.save(entity)` sans `collectionId` — votre
contournement reste correct et sans effet de bord : `onSave` demeure prioritaire
sur la voie du dépôt. Vous pouvez le retirer pour revenir à la voie du socle,
qui écrit maintenant au même endroit que lui.

La redirection d'écriture, elle, n'est pas supprimée : `ZRepository.save`
conserve son paramètre `collectionId`, et un appel direct
`repository.save(item, collectionId: …)` localise toujours le conteneur. Ce
qui change, c'est qu'une déclaration d'écran ne la déclenche plus à votre insu.

## 0.97.0 — 2026-08-14

### Ajouté

#### `ZListQueryPolicy.paginationMode` — où la liste est paginée, filtrée et cherchée

La politique de requête portait le tri, les filtres permanents, la taille de
page et la sémantique de recherche, mais pas la **voie** : un écran assemblé ne
pouvait pas demander que son listing soit servi en mémoire, alors que le socle
savait le faire. Déclarer `paginationMode: ZListPaginationMode.inMemory` rend
recherche, filtres et tri exacts sur une source qui n'en sert aucun, sans avoir
à construire un contrôleur à la main.

Le jeu est alors lu en entier à chaque requête : à déclarer sur un listing
borné. Par défaut (`backendCursor`), les requêtes émises sont **strictement**
celles d'avant.

### Corrigé

#### Une barre de recherche qui ne filtrait rien, sur la voie dépôt

Sur `ZCrudSource.repository(...)` avec une source ne servant pas la recherche —
l'adaptateur Firestore, un dépôt offline-first — la barre s'affichait et ne
filtrait rien : un terme sans correspondance rendait la **totalité** des
documents, ce dont l'usager conclut que la liste ne contient pas ce qu'il
cherche.

L'écran interroge désormais la capacité déclarée par le dépôt
(`ZDelegatesSearch`, `zcrud_core`) : quand la source délègue la recherche, le
listing est filtré par le moteur du socle **le temps de la recherche** — vue
corbeille comprise. Un terme sans correspondance rend la liste vide, le pliage
diacritique tient, et la portée reste celle des champs `searchable`.

Rien ne change ailleurs : la voie `items` est inchangée, et une source qui sert
la recherche continue de la servir, paginée. Sans terme saisi, aucune lecture
supplémentaire n'a lieu.

## 0.96.0 — 2026-08-14

### Corrigé

#### La fiche de détail est de nouveau consultable **en corbeille**

La vue corbeille n'offrait plus que deux gestes de ligne — restaurer et
supprimer définitivement. Aucun moyen, donc, de regarder ce qu'on s'apprête à
rendre ou à détruire, alors que la ligne ne montre qu'une poignée de colonnes et
que la suppression définitive est irréversible.

L'action **« détails »** est rétablie en corbeille, à la même place et avec la
même gouvernance qu'en vue vivante : elle apparaît dès que la consultation est
déclarée (`detailsEnabled`, ou `ZScreenMode.details`) et que votre `ZAcl`
accorde `ZCrudAction.view` **sur la ligne**. L'ouverture publique suit :
`zCrudDetailsOpener`, `ZCrudScreenScope.detailsOpener` et `openDetails` ne
rendent plus un geste inerte en corbeille — une action ajoutée par
`trashRowActions` n'y est donc plus condamnée à être un bouton mort. Le geste
nominal d'une carte (`zCrudEditionOpener`) y consulte lui aussi.

L'asymétrie avec l'écriture est **voulue et documentée** : écrire sur un élément
supprimé n'a pas de sens, le lire en a. La fiche ouverte depuis la corbeille
reste donc **strictement en lecture** — aucun bouton « Modifier », **même** pour
un usager muni de `ZCrudAction.update` (`ZCrudEditionScope.onEditOf` y rend
`null`). Les gestes `edit`, `duplicate` et `softDelete`, ainsi que la création,
restent absents de la corbeille ; la vue vivante est inchangée.

**Rien à faire côté application** si vous n'aviez rien contourné. Si vous aviez
compensé ce défaut — coquille hôte réintroduisant un bouton « voir », ou action
`trashRowActions` maison ouvrant votre propre fiche —, **retirez la
compensation** : elle s'ajouterait désormais à l'action assemblée et la ligne de
corbeille porterait deux gestes de consultation.

## 0.95.0 — 2026-08-14

### Ajouté

#### Le formulaire **seul**, et la fenêtre qui rend une carte de valeurs

Le formulaire déclaratif s'utilise désormais **hors** de l'écran assemblé :

- `ZFormOnly` rend les champs et **rien d'autre** — aucun `Scaffold`, aucune
  barre d'application, aucun bouton d'enregistrement — pour être posé au milieu
  d'une page que vous composez. Le pilotage vient de l'extérieur avec
  `ZFormOnlyController` : `validate()`, `isValid`, `revealErrors()`, `values`,
  `submit()`. Un contrôleur que vous créez, vous le libérez ; sinon le
  formulaire crée le sien et le libère.
- `presentFormEdition(...)` présente ce formulaire en **page, feuille ou
  dialogue** (même politique de présentation que partout ailleurs) et retourne
  `Map<String, dynamic>?` — les valeurs si l'utilisateur enregistre, `null`
  s'il renonce. De quoi éditer une configuration ou des données sans modèle
  typé, sans écrire de formulaire à la main.

Les valeurs rendues sont **validées et normalisées** : types coercés, dates en
ISO-8601, heures en `HH:mm`, valeurs d'énumération en camelCase. Les champs en
**lecture seule** et ceux qu'une **condition d'affichage masque** en sont
absents, et un formulaire **invalide ne rend rien**.

```dart
final reglages = await presentFormEdition(
  context,
  fields: reglagesExportFields,
  initialValues: const <String, Object?>{'format': 'pdf'},
  title: "Réglages d'export",
);
if (reglages != null) await monService.exporter(reglages);
```

### Modifié

#### Une seule normalisation des saisies, pour toutes les surfaces

La sauvegarde de `ZCrudScreen` passe désormais par la **même** projection que
le formulaire seul (`zNormalizeFormValues`, de `zcrud_core`). Un écran passif
enregistre comme avant ; ce qui change est que la forme des données ne dépend
plus de la surface qui les a produites — et qu'un champ déclaré en lecture
seule ou masqué par sa condition ne peut plus contribuer à ce qui est écrit.

#### L'onglet **assemblé** : une catégorie déclarée, un écran complet rendu

Un onglet de `ZCrudScreen(tabs: …)` peut désormais **omettre son `builder`**.
Il ne déclare alors que sa **catégorie** (`ZListTab.baseFilters`) et, s'il y a
lieu, sa **restriction de droits** (`ZListTab.acl`) — et l'écran construit sa
vue lui-même, exactement comme il construit la sienne en l'absence d'onglets :

- la **liste** dérivée du schéma, avec les tuiles, le layout et la coloration
  de ligne déclarés sur l'écran ;
- ses **actions de ligne** assemblées — consulter, modifier, dupliquer, mettre
  à la corbeille — gouvernées par `view` / `update` / `create` / `delete` ;
- la **cascade d'autorisations** inchangée : les droits de l'onglet se
  composent en **conjonction** avec ceux de l'écran, puis du scope. Un onglet
  retire un geste, il n'en ajoute jamais un que l'écran refuse.

```dart
ZCrudScreen<Piece>(
  title: 'Pièces',
  source: ZCrudSource<Piece>.repository(repo),
  registry: registry,
  detailsEnabled: true,
  tabs: <ZListTab>[
    ZListTab(labelKey: 'enCours', baseFilters: const <ZFilter>[
      ZFilter('statut', ZFilterOp.eq, 'open'),
    ]),
    ZListTab(labelKey: 'clotures', baseFilters: const <ZFilter>[
      ZFilter('statut', ZFilterOp.eq, 'closed'),
    ], acl: const MesDroitsEnLecture()),
  ],
);
```

Chaque onglet assemblé possède **son propre contrôleur de liste**, né sur la
politique de l'écran élargie de sa catégorie : sa position, sa pagination et sa
recherche lui appartiennent, et changer d'onglet ne les perd pas.

#### Une **barre de recherche unique**, qui filtre l'onglet actif

Quand **tous** les onglets sont assemblés, la loupe de l'app-bar est de nouveau
offerte. La barre est unique et filtre **l'onglet actif, et lui seul** ; changer
d'onglet fait suivre la recherche — l'onglet quitté retrouve sa liste entière.

La restriction est devenue « pas de recherche **si un onglet est opaque** » au
lieu de « pas de recherche **si onglets** » : un onglet qui fournit son
`builder` rend une vue que l'écran ne connaît pas, et où il ne peut donc pas
porter un terme de recherche.

#### La **corbeille garde la catégorisation**

Avec des onglets tous assemblés, la vue corbeille conserve la barre d'onglets :
les mêmes filtres de catégorie s'appliquent à la partition supprimée. Avec un
onglet opaque, la corbeille reste le listing unique de l'écran — inchangé.

#### `tabsScrollable` — la barre d'onglets défilante

`ZCrudScreen(tabsScrollable: true)` rend la barre d'onglets défilante (le
réglage atteint `ZTabbedList.isScrollable`). Défaut `false` : rendu inchangé.

### Modifié

- **Sélection multiple** : tant que la barre d'onglets est rendue — vue vivante
  **et** corbeille catégorisée — la sélection de l'écran n'est pas servie
  (chaque onglet possède sa vue). Sans changement pour un écran dont les
  onglets sont opaques : sa corbeille reste le listing unique, avec sa
  sélection.

### Impact sur votre code

- **Hôte passif** (aucun onglet, ou onglets tous à `builder`) : **rien à
  faire**. Un onglet qui fournit son `builder` rend exactement ce qu'il
  rendait, et l'écran ne lui accroche rien de nouveau.
- **Hôte qui COMPENSAIT l'absence d'assemblage** — c'est-à-dire qui
  re-déclarait dans son écran la liste de chaque onglet, sa partition, ses
  actions de ligne, son `entityFor` ou sa barre de recherche posée en
  `header` — **retirez ces compensations** en passant l'onglet en forme
  assemblée (supprimez son `builder`) : autrement la liste re-déclarée et la
  liste assemblée coexisteraient, et la recherche posée en `header`
  doublerait celle de l'app-bar.

## 0.94.0 — 2026-08-13

### Ajouté

#### La fiche de détail devient un **geste de ligne** — `detailsEnabled`

`ZCrudScreen(detailsEnabled: true)` ouvre la fiche de chaque ligne **sans que
l'écran perde quoi que ce soit** : le bouton de création, la bascule corbeille,
la mise à la corbeille et la restauration restent offerts, à l'identique.

Jusqu'ici, la consultation n'existait qu'en `ZScreenMode.details` — un mode qui
retire la création et la corbeille de **tout** l'écran. Consulter et administrer
ne sont pourtant pas exclusifs : le cas le plus courant est l'écran complet dont
le tap sur une ligne ouvre la fiche. Il fallait choisir ; il n'y a plus à
choisir.

- `ZScreenMode.details` est **inchangé** : il reste l'écran de consultation (ni
  création, ni corbeille), et reste le bon choix quand c'est l'écran **entier**
  qui est un écran de consultation ;
- `detailsEnabled` est ignoré en `ZScreenMode.locked` — un écran verrouillé
  n'ouvre rien ;
- la ligne porte l'action « détails » (`ZCrudAction.view`) **avant** l'action
  « modifier » (`ZCrudAction.update`), toutes deux filtrées par ligne.

#### `ZCrudScreenActions` expose la consultation — `zCrudDetailsOpener`

Trois membres nouveaux, symétriques de ceux de l'édition : `canOpenDetails`,
`openDetails`, `detailsOpener`, plus le raccourci
`zCrudDetailsOpener(context, entity)`. Même contrat que `zCrudEditionOpener` :
`null` quand le geste n'est pas possible, pour qu'une carte ne dessine pas un
bouton mort.

Sur un écran déclaré consultable, le geste **nominal** d'une ligne devient la
consultation : `zCrudEditionOpener` ouvre alors la fiche, `updateOpener` reste
l'édition.

#### Retour vers l'édition **depuis** la fiche — `ZCrudEditionScope.onEdit`

`ZCrudEditionScope` portait le seul drapeau `readOnly` : une fois la fiche
ouverte, le formulaire de l'application n'avait aucun moyen d'offrir
« Modifier » — l'action existait sur la **ligne**, pas **dans** la fiche.

`ZCrudEditionScope.onEditOf(context)` rend ce geste, ou `null` quand il n'est
pas permis (`ZCrudAction.update` refusé sur cette entité, surface déjà en
édition, écran verrouillé, vue corbeille, source en lecture seule, formulaire
monté hors écran assemblé).

**Il bascule la surface courante sans la refermer** : aucune route n'est fermée
ni rouverte, l'état du formulaire de l'application survit, les valeurs déjà
chargées sont conservées, et le titre passe de celui de la consultation à celui
de la modification. Le formulaire **dérivé** en bénéficie sans rien déclarer.

#### Coloration de ligne — `rowColor` et `ZRowTint`

`ZCrudScreen(rowColor: (context, entity) => ZRowTint(…))` teinte les lignes
selon un état métier. La décision se prend sur **l'entité typée**, jamais sur
une cellule formatée : un renommage de champ devient une erreur de compilation
au lieu d'une couleur qui disparaît en silence.

- la teinte est peinte **derrière** la tuile — celle du paquet comme celle de
  l'application (`itemBuilder`), en liste verticale comme en grille de cartes ;
- elle ne s'applique pas à un layout portant **sa propre** tuile, ni à la grille
  de données (`ZListDataGridLayout`), dont le backend a sa propre coloration de
  cellules ;
- sans `rowColor` — ou pour une ligne dont le seam rend `null` — le rendu est
  **strictement inchangé** : pas un widget de plus dans l'arbre ;
- la couleur n'entre **pas** dans la requête de rendu : deux écrans qui ne
  diffèrent que par leur `rowColor` produisent la même `ZListRenderRequest`, et
  la mémoïsation du rendu est préservée ;
- **aucune couleur n'est codée dans zcrud** : la teinte vient entièrement du
  thème de l'application, d'où le `BuildContext` passé au seam.

⚠️ **Accessibilité** : une information portée par la seule couleur est perdue
pour un usager daltonien, en plein soleil, à l'impression et pour un lecteur
d'écran. `ZRowTint.semanticLabel` la rend **audible** (annoncé sur la ligne,
accepte une clé l10n) ; la rendre **visible** autrement — icône, pastille, mot
d'état — reste l'affaire de la tuile.

### Impact sur votre code

- **Hôte passif** (qui n'implémente pas `ZCrudScreenActions` lui-même) : rien à
  faire, tout est additif ; les écrans existants sont rendus à l'identique.
- **Hôte qui COMPENSAIT l'absence de fiche sur un écran complet** — en
  dupliquant l'écran en deux versions, en basculant `mode` selon le rôle de
  l'utilisateur, ou en câblant sa propre feuille de consultation : la
  compensation **s'ajoute** désormais au comportement natif. Remplacez-la par
  `detailsEnabled: true`, et retirez le `mode: ZScreenMode.details` posé pour
  obtenir la consultation — il continuerait à retirer création et corbeille.
- **Hôte qui portait son propre « Modifier » dans la fiche** (rappel capturé par
  fermeture, scope maison type `DodlpZReadOnlyScope`) : `onEditOf` le remplace,
  et bascule sans refermer. Les deux cohabitent sans conflit, mais l'hôte
  dessinerait alors **deux** boutons.
- **Hôte qui colorait ses lignes lui-même** (décorateur autour de sa tuile) :
  `rowColor` fait la même chose en amont. Les deux se superposeraient — la
  couleur de l'hôte étant peinte **par-dessus** celle de l'écran, le résultat
  visible reste le sien, mais la teinte du socle est alors inutile.
- **Hôte qui IMPLÉMENTE `ZCrudScreenActions`** (interface, non destinée à
  l'implémentation) : trois membres s'y ajoutent (`canOpenDetails`,
  `openDetails`, `detailsOpener`) — une implémentation maison doit être
  complétée.

## 0.93.0 — 2026-08-13

### Modifié — rupture

#### `ZCrudScreen` refuse par défaut, et `view` gouverne l'écran

- **Refus par défaut.** Sans ACL déclarée — ni `ZCrudScreen(acl:)`, ni
  `ZcrudScope(acl:)` — l'écran n'offre **aucun** geste. Le repli était
  `ZAllowAllAcl` : une application qui oubliait de brancher son ACL voyait tous
  les gestes au lieu d'aucun, sans le moindre signal.
- **`ZCrudAction.view` devient bloquant pour l'écran entier.** Refusé, l'écran
  rend un **état « accès refusé »** (brique `ZErrorState` de `zcrud_ui_kit`,
  clé `zCrudAccessDenied`, libellés `accessDenied`/`accessDeniedMessage`), sans
  bouton ni recherche.
- **Aucune lecture n'est déclenchée sur la source** quand `view` est refusé :
  le contrôleur de listing est désormais construit **paresseusement**, au
  premier rendu autorisé, au lieu de l'être au montage de l'écran. Un écran
  refusé n'interroge pas le dépôt.
- **Échappatoire explicite** : `ZCrudScreen(acl: const ZAllowAllAcl())` ou
  `ZcrudScope(acl: const ZAllowAllAcl())` rétablissent l'ouverture totale — en
  la **déclarant**. Le paramètre de l'écran l'emporte sur le scope.
- Conséquence à connaître : une **erreur de configuration** (par exemple un
  écran sans registre ni `listFields`, qui lève un `ZScopeError` actionnable)
  n'est atteinte qu'une fois la consultation autorisée ; sans ACL, c'est l'état
  d'accès refusé qui s'affiche d'abord.

#### `ZCrudTrashWrite<T>` reçoit un `BuildContext`

`FutureOr<void> Function(T)` devient `FutureOr<void> Function(BuildContext, T)`
— même geste que `ZCrudEditionBuilder`, et pour la même raison : sans contexte,
une application ne peut ni demander sa propre confirmation, ni notifier, ni
naviguer avant une écriture destructive, sinon en capturant un contexte
extérieur à la ligne.

Le contexte transmis est celui de la **ligne** au moment du geste.

**Geste de migration** — ajoutez le paramètre en tête de chaque rappel de
corbeille (`onSoftDelete`, `onRestore`), et ignorez-le si vous n'en avez pas
l'usage :

```dart
// avant
onSoftDelete: (item) => monService.supprimer(item.id!),
// après
onSoftDelete: (context, item) => monService.supprimer(item.id!),
```

La rupture est **détectée à la compilation** : aucun appel ne peut passer
silencieusement.

### Modifié

- **`ZCrudScreen` est porté sur `zcrud_ui_kit`** (CR owner, 2026-08-13) : le
  paquet livré en 0.92.0 rendait un `Scaffold` + `AppBar` **bruts** et une
  barre de recherche `TextField` **maison** — exactement le défaut que zcrud
  reproche à ses hôtes. La coquille est désormais celle du socle
  (`ZPageScaffold`/`ZSearchableAppBar`) : titre, `leading` et actions y sont
  propagés, la **recherche** devient celle de l'app-bar
  (`ZAppBarSearchConfig` : la loupe morphe le titre en champ, `Échap`
  referme, la frappe ne reconstruit que la tranche app-bar), avec le
  **câblage inchangé** (`ZListController.setSearch` en voie repository,
  `zApplyListRequest` en voie items) et la **portée corbeille** préservée.
  Les boutons assemblés (bascule corbeille, création) deviennent des
  `ZAppBarAction` — donc éligibles au **menu de débordement** du socle. Les
  clés de test historiques (`zCrudCreate`, `zCrudTrashToggle`,
  `zCrudTrashBack`) sont **conservées** ; la clé `zCrudSearch` disparaît avec
  le champ maison (la recherche s'ouvre par la loupe de l'app-bar).
- **Échec d'une action de LIGNE notifié** : la corbeille et la restauration
  n'avaient **aucune** surface où afficher une `ZFailure` — leur échec passe
  désormais par le port `ZToaster` (`ZToasterScope` de l'hôte, repli
  `ScaffoldMessenger`, sinon **silence** documenté — jamais de `throw`,
  AD-10). L'échec de **sauvegarde** reste, lui, affiché dans la surface
  d'édition (`zCrudFormError`) : les deux canaux restent distincts.

### Ajouté

#### La requête d'un onglet est composée par l'écran

Un onglet qui déclare son socle de filtres (`ZListTab.baseFilters`, renseigné
par `ZListTab.category`) le voit désormais **composé par l'écran** avec les
filtres permanents de `query` : sa page lit
`ZListQueryPolicy.of(context).baseFilters` et le tout y est déjà. Les deux
socles sont ANDés en tête de chaque requête — chercher ou filtrer dans un onglet
ne peut pas en faire sortir.

#### `ZRowLongPressOwner.selection`

Troisième propriétaire possible de l'appui long : il **ouvre la sélection
multiple** (coche la ligne pressée, fait apparaître les cases), le menu
contextuel ne s'ouvrant plus qu'au clic droit. Ce geste étant déjà réclamé par
le menu contextuel et par la copie de cellule d'un rendu de grille, l'arbitrage
reste **un choix unique et déclaré** plutôt que trois réglages indépendants qui
auraient permis de désigner deux propriétaires à la fois.

#### Export du listing (`export`)

- **`ZCrudScreen(export: ZExportPolicy(...))`** offre l'export de la liste :
  un format déclaré = une entrée « Exporter (CSV) » dans le menu de
  débordement de l'app-bar, dans l'ordre de déclaration.
- **Aucun format par défaut.** Sans politique déclarée — le défaut — il n'y a
  ni entrée, ni menu, ni dépendance supplémentaire : `zcrud_screen` ne connaît
  que le port `ZListExporter` du cœur et ne dépend d'**aucun** paquet d'export.
  Une politique déclarée sans format n'ouvre rien non plus.
- **Ce qui est exporté, c'est ce qui est affiché** : les lignes réellement
  listées — tri, filtres, recherche et vue (vivants ou corbeille) déjà
  appliqués —, avec les colonnes dérivées du schéma et leurs valeurs
  **formatées**, telles qu'elles sont peintes (devise portée par la ligne,
  format composé). Les ornements d'écran — numéro d'ordre, cases à cocher,
  boutons d'action — n'entrent jamais dans le fichier.
- **Une sélection en cours restreint l'export** aux seuls éléments cochés,
  dans l'ordre de l'écran : c'est la lecture attendue d'un export demandé
  sélection faite.
- **Le fichier va où l'application décide** : `ZExportPolicy.onExported`
  reçoit le `ZExportedBytes` (octets, nom suggéré, type MIME) — enregistrer,
  partager, imprimer, téléverser sont des décisions de plateforme.
  `fileBaseName` remplace le titre de l'écran dans le nom du fichier.
- **Rien ne peut emporter l'écran** : une liste vide s'annonce
  (« Rien à exporter »), un exporteur en échec — ou qui lève — s'annonce aussi,
  avec son motif, et aucun fichier n'est remis.

L'export est une **lecture** : il est offert là où le listing l'est
(`ZCrudAction.view`), et aucun droit propre n'est introduit. Une application
qui veut le restreindre plus finement déclare, ou non, sa politique.

#### Sélection multiple et actions de masse (`selection`)

- **`ZCrudScreen(selection: const ZSelectionPolicy())`** câble la sélection
  multiple : case à cocher par ligne, et **barre d'actions de masse** qui
  apparaît dès le premier élément coché puis disparaît quand la sélection se
  vide. `null` (défaut) ⇒ écran strictement inchangé.
- **Actions de masse assemblées, par vue** : mise à la corbeille sur les
  éléments vivants ; restauration et suppression définitive en corbeille.
  Chacune existe aux mêmes conditions que l'action de ligne homonyme (geste
  voulu par `trashPolicy`, servi par la source, autorisé par l'ACL).
- **Gouvernées par la voie des actions de ligne** (`zResolveRowActions`) :
  aucune seconde logique d'autorisation. Un droit refusé rend l'action
  **absente** (`actionAclMode: hide`, défaut) ou **inerte** (`disable` :
  l'invoquer annonce le refus et n'écrit rien). Une entité que `rowAcl` ou
  `enabledFor` n'admet pas est **exclue du lot avant toute écriture**, et le
  compte rendu la compte comme écartée — jamais un traitement silencieux.
- **Un lot partiellement en échec le dit.** La notification porte le nombre de
  succès, le nombre d'échecs, le nombre d'éléments écartés, et **nomme** les
  éléments en échec. Le `ZBatchReport` complet (identités réussies, cause de
  chaque échec) est remis à l'application par `ZSelectionPolicy.onReport`,
  pour qui veut sa propre surface. C'est un gain, pas une parité : les moteurs
  de liste historiques appliquaient le lot sans jamais lire ses résultats.
- **Confirmation avec le compte** : un geste de masse destructif passe par la
  confirmation déjà en place (`confirmDestructive`), dont la question porte le
  **nombre d'éléments** du lot réellement soumis. Annuler n'écrit rien. La
  restauration, non destructive, n'est pas confirmée.
- **La sélection ne traîne pas** : vidée après chaque action de masse et à la
  bascule vivants ⇄ corbeille. « Tout sélectionner » porte sur les éléments
  actuellement listés, jamais au-delà.
- **`batchActions`** ajoute les actions de masse de l'application après les
  actions assemblées, avec les entités sélectionnées.
- Nouveaux libellés utilisés : `selectedCount`, `selectAll`, `batchSucceeded`,
  `batchFailed`, `batchSkipped`. Absents des tables du socle, ils se résolvent
  sur leur repli anglais et se localisent dès aujourd'hui par
  `ZcrudScope(labels: ZcrudLabels({…}))`.

- **Domaine et normalisation de la recherche déclarés** : la même politique
  porte désormais `searchScope` (les colonnes que la recherche interroge) et
  `searchFolding` (ce qu'elle ignore en comparant), plus le raccourci
  `ZListQueryPolicy.legacySearch()` qui pose les deux d'un coup.

  ```dart
  ZCrudScreen<Dossier>(
    query: const ZListQueryPolicy(
      searchScope: ZSearchScope.allColumns,              // toutes les colonnes
      searchFolding: ZSearchFolding.diacriticsAndSpaces, // blancs ignorés
    ),
    // …
  );
  ```

  Pourquoi : les moteurs de liste déclaratifs antérieurs cherchaient dans
  **toutes** les colonnes déclarées et ignoraient les espaces. Une migration
  qui gardait le défaut rétrécissait donc la recherche **sans aucun signal** —
  la liste s'affiche, elle est simplement vide. `ZSearchScope.allColumns` rend
  le domaine historique ; `ZSearchFolding.diacriticsAndSpaces` fait à nouveau
  correspondre « SOCIETE X SARL U » et « sarlu ».

  **Non cassant** : sans déclaration, la recherche interroge les seuls champs
  `searchable` et les blancs comptent — les requêtes émises sont **exactement**
  celles d'avant (garde de contre-témoin dédiée).

  Composition : élargir le domaine ne fait pas déborder la recherche hors de ce
  que la requête a déjà réduit — les filtres permanents restent opposables, la
  vue corbeille garde sa portée, un onglet garde son filtre de catégorie et
  hérite de la sémantique par `ZListQueryPolicy.of(context)`. Coût mesuré :
  aucune requête ni reconstruction supplémentaire.

- **Tri, filtres de base et pagination déclarés** : `ZCrudScreen(query:
  ZListQueryPolicy(…))` porte le **tri par défaut** (`sort`), les **filtres
  permanents** (`baseFilters`) et la **taille de page** (`pageSize`) du
  listing. Ces trois réglages existaient dans le socle (`ZListController`)
  sans qu'un écran assemblé les expose : ouvrir une liste triée, ne jamais
  montrer les archives ou changer la pagination obligeait à construire son
  propre contrôleur — c'est-à-dire à quitter la déclaration.

  ```dart
  ZCrudScreen<Dossier>(
    query: const ZListQueryPolicy(
      sort: <ZSort>[ZSort('updated_at', ZSortDirection.desc)],
      baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
      pageSize: 50,
    ),
    // …
  );
  ```

  **Non cassant** : sans `query`, les requêtes émises sont **exactement**
  celles d'avant — aucun filtre, aucun tri, aucune limite de page (garde de
  contre-témoin dédiée).

  Composition : la **corbeille** garde sa portée de suppression et reçoit le
  tri, les filtres permanents et la taille de page **en plus** ; la
  **recherche** ne les efface pas ; en mode **onglets**, la politique est
  offerte aux pages via `ZListQueryPolicy.of(context)` et se compose avec le
  filtre de catégorie par `filtersWith` (permanents d'abord, catégorie
  ensuite — jamais l'un à la place de l'autre).

  Le tri par défaut est posé **sur la requête** : la première requête part
  déjà triée, au lieu d'en émettre une non triée puis de la remplacer.

- **Trier et filtrer sans descendre au contrôleur** : `ZCrudScreenActions`
  gagne `sortBy(List<ZSort>)` et `filterBy(List<ZFilter>)`, atteignables
  depuis n'importe quelle vue posée sous l'écran
  (`ZCrudScreenScope.maybeOf(context)`). Un tri demandé **remplace** le tri
  par défaut ; des filtres demandés **s'ajoutent** aux filtres permanents,
  qu'aucun appel ne peut lever.

- **Onglets gouvernés** : un onglet (`ZListTab`) peut porter ses **droits**
  (`acl`), ses **intitulés de formulaire** (`titles`) et son **compteur**
  (`countOf`). L'écran les applique à l'onglet **actif** : la création se ferme
  sur un segment sans se fermer sur les autres, et chaque onglet ouvre son
  formulaire sous son propre intitulé.

  ```dart
  ZCrudScreen<Piece>(
    tabs: <ZListTab>[
      ZListTab(
        labelKey: 'closed',
        acl: const MesDroitsEnLecture(),          // retire, n'accorde pas
        titles: const ZCrudTitles(create: 'Nouveau dossier'),
        countOf: compteurDeDossiers,              // pastille auto-rafraîchie
        builder: (_) => maListe,
      ),
    ],
    // …
  );
  ```

  🔒 La cascade **onglet > écran > scope** est une intersection : un onglet ne
  peut pas rouvrir un geste refusé plus haut.

- **Compteur de corbeille** : `ZCrudScreen.trashCount` (`ValueListenable<int>?`)
  affiche le nombre d'éléments en corbeille sur le bouton d'accès (pastille
  `ZCountBadge`), et conditionne sa visibilité quand la déclaration l'exige.
  Sur la voie `items`, le compte est **dérivé gratuitement** de la liste déjà
  en mémoire : rien à déclarer. L'écran n'interroge **jamais** le dépôt pour
  afficher un nombre — une lecture par image coûterait plus que le nombre ne
  vaut. La pastille se rafraîchit **sans reconstruire la liste**.

- `ZTrashPolicy(visibleWhenEmpty: false)` : plus de bouton qui mène à une
  corbeille vide. Sans compte connu, l'accès reste offert (non compté ≠ vide).


- **Gouvernance par ligne, déclarée une fois pour tout l'écran** :
  `ZCrudScreen.rowAcl` reçoit l'entité d'une ligne et rend ses droits
  effectifs.

  ```dart
  ZCrudScreen<Dossier>(
    rowAcl: (dossier) => dossier.cloture
        ? const ZRowPermissions.locked(reasonKey: 'dossierCloture')
        : const ZRowPermissions.unrestricted(),
    // …
  );
  ```

  Une seule déclaration gouverne les actions de la vue vivante **et** de la
  corbeille, rendues en boutons dans la ligne **comme** en menu. Un dossier
  clôturé, une pièce déjà validée, un élément protégé cessent ainsi de réclamer
  du filtrage maison en amont de l'écran.

  🔒 **Le résolveur restreint, il n'élargit jamais** : la composition avec
  l'ACL de l'écran (ou du scope) est une **intersection**. Il ne peut pas
  rouvrir un geste que l'ACL refuse.

  La présentation d'une action fermée suit la nature du refus : un **droit
  refusé** obéit au `actionAclMode` déclaré (`hide` masque, `disable` montre
  inerte avec son motif), tandis qu'une action simplement **inapplicable** à la
  ligne (`ZRowAction.enabledFor`) reste toujours rendue, inerte et motivée —
  une entrée de menu inerte n'ouvre rien, un bouton inerte n'invoque rien.

- **Une carte peut ouvrir le cycle d'édition DE L'ÉCRAN.** Il n'existait aucun
  point d'accès public : une tuile métier déclarée par `itemBuilder` ne pouvait
  ouvrir un formulaire qu'avec un rappel capturé par fermeture — un
  court-circuit qui ne bénéficiait ni de la `policy` de l'écran, ni de son
  `formWeight`, ni de son `onSave`, ni de son mode, ni de ses titres.

  `ZCrudScreenScope` est désormais posé autour du corps de l'écran, et
  `ZCrudScreenActions` porte ses gestes :

  ```dart
  // Dans une carte descendante d'un ZCrudScreen :
  final ouvrir = zCrudEditionOpener(context, consignee);
  // `null` ⇒ le geste n'est pas possible : on ne dessine pas le bouton.
  return Card(child: ListTile(title: Text(consignee.nom), onTap: ouvrir));
  ```

  - **Trois formes par geste** : `canOpenX(entity)` pour interroger la capacité
    **avant de rendre**, `openX(entity)` pour ouvrir, `xOpener(entity)` pour
    obtenir le rappel — ou `null`. Trois gestes : l'ouverture **nominale**
    (`openEdition`), l'édition **explicite** (`openUpdate`, le retour vers
    l'édition depuis une fiche) et la **création** (`openCreation`, le geste du
    bouton « + »).
  - **La surface est celle de l'écran, à l'identique** : même politique de
    présentation, même poids de formulaire, même formulaire, même voie de
    sauvegarde, mêmes titres (garde qui compare les trois chemins — carte,
    action de ligne, bouton « + » — sur la politique consultée, le poids
    enregistré et le titre rendu).
  - **Refus fail-closed, jamais d'exception** (AD-10) : `maybeOf` rend `null`
    hors d'un `ZCrudScreen`, une capacité refusée rend `false`, un rappel
    refusé rend `null`, une ouverture demandée malgré tout ne présente
    **rien** — écran `ZScreenMode.locked`, vue corbeille, source sans écriture,
    permission refusée, ou entité d'un autre type. La permission est
    interrogée **avec l'entité en cible** : le filtrage est par ligne, comme
    celui des actions.
  - **Cohérent avec le mode « Détails »** : `openEdition` ouvre en
    `ZScreenMode.details` la **fiche en lecture seule** (`ZCrudAction.view`), et
    le retour vers l'édition (`openUpdate`) n'est offert que si l'ACL accorde
    `ZCrudAction.update`. Aucune seconde logique de mode.
  - **Entité éphémère** (sans identité) : son ouverture relève de
    `ZCrudAction.create`, puisque l'enregistrer la crée.
  - **Deux scopes, deux endroits** : `ZCrudEditionScope` reste posé autour de
    la **surface présentée** (il dit au formulaire s'il est en consultation),
    `ZCrudScreenScope` autour du **corps** (il dit aux tuiles ce que l'écran
    sait ouvrir). Une carte de la liste n'est jamais descendante de la surface
    d'édition : un scope unique les rendrait mutuellement inatteignables.

  **Si vous compensiez** en passant votre propre rappel d'édition à vos cartes,
  retirez-le : il court-circuite la configuration de l'écran, et les deux
  chemins divergeront (politique, poids, titres, et surtout `onSave`).
- **Le mode « Détails » descend jusqu'au formulaire.** `ZScreenMode`
  (`full` / `details` / `locked`) remplace le booléen `readOnly`, qui ne
  savait pas exprimer l'état dont un écran de consultation a besoin : la
  lecture seule **avec** retour vers l'édition.
  - `ZScreenMode.details` — la liste ne crée rien et n'a pas de corbeille,
    mais chaque ligne porte une action « détails » qui ouvre **le formulaire
    entier** en lecture seule. Ce n'est pas une fiche dérivée des colonnes :
    les colonnes montrent ce qu'un tableau peut montrer, la fiche montre
    **tous** les champs du formulaire (`formFields` dérivés du registre, ou
    le formulaire de l'application).
  - L'action « modifier » y reste rendue **si et seulement si** l'ACL accorde
    `ZCrudAction.update` — la consultation n'est pas un cul-de-sac pour qui a
    le droit de modifier.
  - `ZScreenMode.locked` — consultation verrouillée, **strictement**
    équivalente à l'ancien `readOnly: true` (mêmes gestes retirés, même
    rendu ; verrouillé par une garde de non-régression qui compare les deux
    écrans affordance par affordance).
- **`ZCrudEditionScope`** : le transport du drapeau jusqu'au formulaire de
  l'**application**. Un `editionBuilder` lit
  `ZCrudEditionScope.readOnlyOf(context)` depuis le contexte qu'il reçoit et
  rend son propre formulaire en lecture seule. Un scope, et non un paramètre
  de plus sur `ZCrudEditionBuilder` : ajouter un paramètre — positionnel ou
  nommé — rendrait inassignables **toutes** les lambdas déjà écrites, donc
  casserait chaque application à la compilation. Ici, le code existant
  compile inchangé.
- **`ZCrudTitles.read`** : le titre du mode consultation, quatrième état du
  porte-titres. `null` retombe sur la clé l10n `details` (ajoutée aux tables
  `en` **et** `fr` de `zcrud_core`).
- ⚠️ **Le champ « widget libre » n'est pas dispensé.** Un widget hôte servi
  par le `ZWidgetRegistry` dessine ses propres contrôles ; le socle lui
  transmet bien l'information (`ctx.field.readOnly` vaut `true` en fiche —
  garde dédiée), mais c'est au widget de l'honorer (`onChanged: null`), sinon
  la fiche « lecture seule » reste cliquable. Deux détails mesurés et
  documentés au README : le `ZWidgetRegistry` doit être posé **au-dessus du
  `Navigator`** (`MaterialApp.builder`) pour servir une surface présentée en
  route, et un champ **vide** n'apparaît en lecture que s'il déclare
  `showIfNull: true`.
- **La corbeille a ses trois gestes.** `ZCrudAction.clear` existait dans le
  cœur sans être câblé nulle part : la corbeille de l'écran savait y mettre et
  en sortir, jamais détruire. La **suppression définitive** est désormais
  assemblée, gouvernée par `ZCrudAction.clear` et par la capacité **déclarée**
  de la source :
  - voie repository : le geste apparaît si le dépôt applique le mixin
    `ZPurgeable` de `zcrud_core` ;
  - voie `items` : nouveau rappel `ZCrudSource.items(onPurge:)` ;
  - sans l'un ni l'autre : **aucun bouton, aucune erreur, aucun crash** — la
    corbeille garde ses deux autres gestes.
- **`trashPolicy`** (`ZTrashPolicy`) déclare *quels* gestes la corbeille offre,
  là où `trash` (`ZTrashMode`) décide seulement si elle *existe*. Défaut
  `ZTrashPolicy.full` : comportement inchangé. `ZTrashPolicy.withoutPurge`
  donne une corbeille dont rien ne disparaît, même si le dépôt sait purger.
- **`trashRowActions`** : canal d'actions de ligne propre à la vue corbeille.
- **La confirmation couvre la purge**, avec son propre texte. La mise à la
  corbeille se défait, la suppression définitive non : elle porte les libellés
  `deleteForever`/`confirmDeleteForeverItem`, qui annoncent l'irréversibilité.
  Annuler — bouton, barrière ou retour arrière — n'appelle **aucune** écriture.
- **La tuile déclarée descend dans le layout déclaré** — une **grille de cartes
  métier** se déclare enfin sans code d'index. `itemBuilder` (qui reçoit
  l'entité `T`) n'était consulté que sur la voie de repli : dès qu'un `layout`
  était fourni, il était **ignoré**, la tuile ne recevait qu'une `ZListRow`, et
  l'application devait reconstruire à la main l'index `ligne → entité` en
  répliquant une convention de clé privée. Désormais :

  ```dart
  ZCrudScreen<Consignee>(
    title: 'Consignataires',
    source: ZCrudSource<Consignee>.repository(repo),
    registry: registry,
    layout: const ZListGridLayout(maxCrossAxisExtent: 360, mainAxisExtent: 180),
    itemBuilder: (context, consignee, columns) => ConsigneeCard(consignee),
  )
  ```

  L'écran alimente lui-même le seam `DynamicList.entityFor` avec l'index qu'il
  tient déjà pour les actions de ligne (clé publique `ZListRow.keyOf` :
  identité réelle, ou clé éphémère stable pour une entité non persistée).
  Priorités inchangées et explicites : un layout portant **sa propre** tuile de
  ligne la garde ; sans `itemBuilder`, la **tuile générique** du paquet est
  rendue à l'identique.
- **Confirmation des gestes destructifs** (limite assumée en 0.92.0, levée
  ici) : la mise à la corbeille passe par `showZConfirmDialog`
  (`ZConfirmTone.destructive`, libellés l10n, cibles ≥ 48 dp). Annuler —
  bouton, barrière ou `pop` sans valeur — n'écrit **rien** (ni
  `repository.softDelete`, ni `source.onSoftDelete`). Désactivable par
  déclaration : `confirmDestructive: false`, pour l'hôte qui possède son
  propre flux. La **restauration** n'est jamais confirmée (non destructive).
- **`actions`** (`List<ZAppBarAction>`) : actions d'app-bar **déclarées en
  données**, rendues avant les actions assemblées, avec `semanticLabel`
  obligatoire (a11y AD-13) et débordement (`isOverflow`) du socle.

### Corrigé

- **Le mode d'ACL « désactiver » rend l'action de masse INERTE.** Il ne
  s'exprimait que par l'effet : l'action restait pleinement actionnable, et
  l'invoquer annonçait le refus sans rien écrire. Elle est désormais grisée,
  non actionnable et annoncée désactivée avec son motif — l'apparence dit ce que
  l'effet faisait déjà. Le mode `hide` est inchangé (l'action est absente).
- **La restauration en lot porte sa nature** (`ZBatchActionKind.restore` au lieu
  de `custom`).
- **Le tri déclaré ne passe plus par un décorateur de dépôt** : il devient le
  tri de naissance du contrôleur (`ZListController.initialSorts`). Aucun
  changement observable — la première requête partait déjà triée, elle l'est
  toujours, par un chemin plus court.

### Corrigé

#### L'accès à la corbeille suivait le mauvais droit

Le bouton d'accès à la corbeille apparaissait dès que `delete` **ou** `restore`
était accordé. Or *mettre* à la corbeille n'est pas *y entrer* : un usager
autorisé à supprimer, mais ni à restaurer ni à purger, se voyait offrir une vue
où aucun geste ne lui était possible. Le critère est désormais
**`restore` ou `clear`**.

**Hôtes ayant compensé** : une application qui masquait elle-même ce bouton
pour les rôles « suppression seule » peut retirer sa compensation. Une
application **passive** verra le bouton disparaître pour ces rôles — c'est la
correction, pas une régression.


- **Les `rowActions` de l'application fuyaient dans la vue corbeille.** Elles
  étaient ajoutées **en dehors** du test de vue : toute action déclarée pour
  les éléments vivants apparaissait aussi sur les éléments en corbeille, et
  réciproquement il n'existait aucun moyen d'en déclarer une pour la corbeille
  seule. Conséquence concrète signalée par un pilote : une action « supprimer
  définitivement » passée en contournement se serait affichée **au milieu des
  éléments vivants**.

  `rowActions` ne s'applique désormais qu'à la vue vivante, `trashRowActions` à
  la corbeille. **Si vous compensiez ce défaut** — par exemple en filtrant
  vous-même vos actions selon la vue, ou en renonçant à en déclarer —, retirez
  votre compensation : la séparation est maintenant faite par l'écran.

### Déprécié

- **`readOnly`** (`bool`) au profit de `mode` (`ZScreenMode`). Correspondance
  exacte, à appliquer telle quelle :

  | Ancien | Nouveau |
  |---|---|
  | `readOnly: false` (défaut) | `mode: ZScreenMode.full` (défaut) |
  | `readOnly: true` | `mode: ZScreenMode.locked` |
  | *(inexprimable)* | `mode: ZScreenMode.details` |

  Le booléen **continue de fonctionner à l'identique** tant qu'il est là
  (retrait en 1.0) ; quand les deux sont déclarés, `mode` l'emporte. Un écran
  qui offrait de la consultation pure n'a rien à changer — mais un écran qui
  voulait une **fiche de détail** et se rabattait sur `readOnly: true` faute
  de mieux doit passer à `ZScreenMode.details` pour la gagner.

- **`appBarActions`** (`List<Widget>`) au profit de `actions`. L'app-bar du
  socle attend des **données**, pas des widgets : un widget déjà construit
  n'y entre qu'emballé, ce qui masque sa sémantique propre et porte sa boîte
  de 48 à 64 dp. Le **tap reste fonctionnel** (mesuré) ; le paramètre sera
  retiré en 1.0.

- **Geste « dupliquer »** (CR DODLP « choix dérivés et champs chemin »,
  point 4) : action de ligne câblée d'office, gouvernée par la **même
  permission que la création** (`ZCrudAction.create`) et par `canCreate`.
  Elle ouvre la surface d'édition en mode **duplication** — une copie **sans
  identité** de l'entité, produite par le canal du registre (`encode` →
  retrait des champs `isId` → `decode`) — et la sauvegarde matérialise une
  **nouvelle** entité, l'originale restant intacte. Désactivable par
  déclaration (`canDuplicate: false`) ; absente si `readOnly`, si la source
  ne sait pas écrire, ou sans `registry`.
- **`ZCrudTitles`** : porte-titres à **trois états** (`create` / `copy` /
  `update`) de la surface d'édition, passé via le paramètre `titles:`.
  Chaque titre est une clé l10n ou un littéral (résolu via `label(context,
  …)`) ; `null` retombe sur les clés l10n génériques (`create` / `copy` /
  `edit`). La surface d'édition dérivée affiche le titre du mode courant —
  la **duplication a son propre intitulé**, distinct de la création nue.
- **Champs « chemin » câblés** : des specs à nom **pointé**
  (`'vido.chefEquipePosteId'`) font le pont entre le modèle imbriqué et le
  formulaire plat — valeurs initiales aplaties à l'ouverture
  (`zFlattenPaths`, zcrud_core), clés pointées regroupées avant `decode` à la
  soumission (`zRegroupPaths`) ; sous-objet reconstruit, champs imbriqués non
  édités préservés. Sans nom pointé, le chemin d'édition est strictement
  inchangé.

## 0.92.0 — 2026-08-12

### Ajouté

- Création du paquet (réponse au CR DODLP « écran CRUD assemblé »,
  2026-08-12) : `ZCrudScreen<T>`, écran CRUD **assemblé et déclaratif** —
  liste + recherche + création + édition + sauvegarde + corbeille à partir
  d'une déclaration (`title` + `source`), câblée sur les briques publiques
  existantes (`DynamicList`/`ZTabbedList`, `ZRowAction`, `presentEdition`/
  `ZPresentationPolicy`, `DynamicEdition`/`ZFormController`, `ZRepository`/
  `ZDataRequest.deletedScope`).
- `ZCrudSource<T>` : source déclarative — `.repository(ZRepository<T>)`
  (voie nominale) ou `.items(List<T>, onSave/onSoftDelete/onRestore/isDeleted)`
  (cohabitation ; sans callbacks = lecture seule effective).
- Dérivation depuis le `ZcrudRegistry` : champs de liste et de formulaire
  (`kindOf<T>` → `fieldSpecsFor`, champs `isId` exclus du formulaire),
  projection en cellules (`encode`), reconstruction d'entité (`decode` sur
  valeurs fusionnées — identité conservée). Chaque dérivation surchargeable
  (`listFields`, `formFields`, `cellsOf`, `editionBuilder`).
- Cas exprimables par déclaration : `canCreate: false`,
  `trash: ZTrashMode.none`, `readOnly: true`, ACL refusante (masquage par
  défaut, `actionAclMode` grisable).
- Corbeille voie repository via `ZDeletedScope.deletedOnly` (décorateur de
  requête interne — recherche et pagination inchangées en vue corbeille) ;
  voie items via partition `isDeleted` + fabriques `softDeleteWith`/
  `restoreWith`.
- Mode onglets (`tabs`) : corps `ZTabbedList`, création héritant du contexte
  (`defaultItemBuilder`) et de l'autorisation (`canCreate`) de l'onglet actif.
- `public_member_api_docs` activé (exhaustivité dartdoc vérifiée par
  l'analyse) ; README au gabarit de la charte documentaire ; fiche
  `docs/site/paquets/zcrud_screen.md`.
