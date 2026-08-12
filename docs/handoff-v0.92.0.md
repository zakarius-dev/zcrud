# Handoff **v0.92.0** — `zcrud_screen` : l'écran CRUD assemblé, et la déclarativité jusqu'au bout

> **Tag à épingler : `v0.92.0`** — répond à trois CR DODLP du 2026-08-12 :
> `cr-ecran-crud-assemble` (structurant), `cr-tabbed-list-recherche-et-etat`,
> `cr-repository-corbeille-inaccessible`. **40ᵉ paquet : `zcrud_screen`**.
> Release **strictement additive** pour tous les paquets existants.

---

## 1. CR écran assemblé — **`zcrud_screen`, nouveau paquet**

Votre diagnostic est retenu tel quel : la déclarativité s'arrêtait à mi-chemin, et vos
16 copies du bloc `presentEdition` étaient le signal d'un assemblage manquant. Il existe
désormais :

```dart
// Déclaration minimale — 5 lignes, écran complet :
ZCrudScreen<Consignee>(
  title: 'Consignataires',
  source: ZCrudSource.repository(repo),
  registry: registry,
)
```

Création (« + » gouverné par l'ACL, `canCreate` et `defaultItemBuilder` de l'onglet
actif), édition pré-remplie, sauvegarde (`repository.save` ou votre `onSave` de
cohabitation), corbeille complète (bascule vivants/supprimés via `deletedScope`,
`softDelete`/`restore` gouvernés ACL), recherche, onglets, grille — **sans une ligne
d'assemblage côté app**. Votre exemple `Consignee` complet, tout surchargé (schémas,
cellules, ACL, policy, grille) : **17 lignes** — contre ~235 mesurées chez vous, ~30 en
legacy.

**Ce qui est dérivé et jamais redemandé** (c'est le cœur du geste) : pour un `T`
enregistré au registre, les colonnes de liste et les champs de formulaire viennent des
`ZFieldSpec` générés, les cellules d'`encode`, la reconstruction d'entité de `decode`
(identité et champs non édités **conservés**), le kind de `kindOf<T>`. L'ACL vient du
`ZcrudScope` ambiant, le mode de présentation du breakpoint. Vous ne déclarez que ce qui
vous est propre.

**Vos trois points d'attention, adressés** :
1. *Composabilité* : assemblage mince — chaque câblage passe par les briques publiques
   (`DynamicList`, `ZTabbedList`, `ZRowAction`, `presentEdition`), tout est surchargeable
   (`listFields`/`formFields`, `cellsOf`, `editionBuilder`, `rowActions`, `layout`,
   `itemBuilder`, `tabs`, `header`…), et descendre d'un cran vers `DynamicList` reste le
   chemin normal pour vos `customView`.
2. *Ce qui ne doit pas y monter* : le journal immuable et le référentiel en lecture seule
   se **déclarent** — `readOnly: true`, `trash: ZTrashMode.none`, `canCreate: false`, ou
   simplement `ZCrudSource.items(...)` sans callbacks (lecture seule effective, prouvée
   par garde).
3. *Packaging* : ni `zcrud_core` (l'assemblage a besoin de `presentEdition`, qui vit dans
   `zcrud_navigation` — le faire monter violerait l'invariant AD-1, le cœur ne dépend
   d'aucun satellite), ni `zcrud_list` (c'est le satellite de **rendu** Syncfusion — y
   mettre l'écran vous imposerait Syncfusion). Donc un satellite dédié, puits du graphe
   de dépendances, arêtes sortantes `zcrud_core` + `zcrud_navigation` uniquement. Votre
   remarque sur le nom de `zcrud_list` est fondée ; la fiche du site de `zcrud_screen`
   fait le renvoi.

Votre brouillon `DodlpZListScreen`/`DodlpZTabbedListScreen` devient **la dette à
retirer** — écran par écran, chaque migration remplaçant votre coquille par la
déclaration. Limites assumées, documentées au README : pas de purge dure (le port
`ZRepository` n'en a pas — `rowActions` custom), pas de dialogue de confirmation intégré,
pas de badge de compte sur la bascule corbeille.

## 2. CR corbeille — **le constat central était dépassé ; la doc du port est corrigée**

Correction amicale, mesure à l'appui : `ZDataRequest.deletedScope`
(`aliveOnly`/`deletedOnly`/`includeDeleted`) existe **depuis la v0.86.0** — c'est mot
pour mot votre option 1 — et il est honoré par `watch(request)`/`getAll`/`count` de
`FirebaseZRepositoryImpl`, y compris votre note d'implémentation fine : en
`absentMeansAlive`, un document legacy `deleted: true` sans `is_deleted` **appartient à
la corbeille** dans les trois portées.

Votre Phase D n'était donc pas bloquée — mais votre erreur avait une cause racine chez
nous : la dartdoc du port `ZRepository` affirmait « les lectures excluent les
soft-deleted » sans jamais mentionner `deletedScope`. **C'est corrigé** (votre option 3) :
chaque chemin de lecture dit sa portée, et l'onglet Corbeille s'écrit
`watch(request.copyWith(deletedScope: ZDeletedScope.deletedOnly))`.

Deux gardes de bout en bout figent le parcours exact de votre CR : *l'id se retrouve via
`getAll(deletedOnly)` et `restore(id)` rend l'élément aux vivants* — flag canonique et
flag legacy. À noter : `getById` d'un supprimé rend un `ZNotFoundFailure` explicite
(« Entité soft-deleted ») — l'id d'un élément en corbeille se lit par la voie
`deletedOnly`, jamais par `getById`.

## 3. CR tabbed-list — **les cinq points, additifs**

- `ZTabbedList.header` — widget partagé au-dessus de la barre d'onglets. Dit
  honnêtement en dartdoc : le header seul ne supprime pas le coût du re-filtrage
  multi-onglets — ne redistribuez qu'à l'onglet actif, via le point suivant.
- `ZTabbedList.activeIndexNotifier` — `ValueNotifier<int>` possédé par l'hôte, tenu
  synchronisé par le widget (montage, tap, swipe — avant `onTabChanged`). **Sens
  unique** : y écrire côté hôte ne pilote pas l'onglet. Votre `_activeIndex` dupliqué
  disparaît. (Notifier `onTabChanged` à l'initialisation a été refusé : changer le timing
  d'un callback existant surprendrait les consommateurs actuels.)
- `ZListTab.pageKey` — identité découplée du libellé (repli sur `labelKey`) : renommer
  un onglet ne casse plus l'écran, deux homonymes sont valides.
- `ZListTab.canCreate` — le pendant de `defaultItemBuilder` ; lu par le geste de
  création de l'onglet actif (et câblé d'office dans `ZCrudScreen`).
- `ZListGridLayout.maxColumns` — plafond de colonnes (`clamp` du motif legacy) ; sans
  plafond, comportement strictement inchangé.

**Hôte ayant compensé (votre cas, nommément)** : la recherche posée au-dessus de
`ZTabbedList`, le `_activeIndex` maintenu à la main, `DodlpZListTabSpec.canCreate` et la
grille responsive maison sont des compensations **à retirer** en migrant sur ces seams.
La diffusion générique d'un `ZDataRequest` aux onglets (votre « plus puissant ») n'a pas
été retenue : les builders + `baseFilters` permettent déjà de threader la requête, et un
canal de diffusion serait un couplage nouveau — à re-proposer si un cas concret le
justifie.

## 4. État des vérifications

`melos run analyze` RC=0 et `melos run verify` RC=0 (14 gates, **40 paquets** — graphe
acyclique vérifié, `CORE OUT=0`), tests rejoués depuis le dossier de chaque paquet
touché, workstreams au repos : core **1803**, firestore **805**, screen **13**. Sur les
trois lots : **16 injections R3** au total, toutes rouges **par assertion**,
restaurations par copie vérifiées par sha256, résidus prouvés absents par grep négatif.
(Dont une injection restaurée par l'orchestrateur lui-même après le crash d'un agent en
pleine campagne — le processus a fonctionné.)

⚠️ La CI GitHub du dépôt reste **hors service** (facturation) : la vérification locale
ci-dessus constitue la ligne de défense de cette release.
