---
title: Démarrage rapide
description: De la dépendance git à un premier écran CRUD complet — modèle annoté, formulaire et liste.
sidebar_position: 2
---

# Démarrage rapide

Ce guide construit un premier écran CRUD complet : un modèle `Article` annoté, sa
génération de code, son enregistrement, un formulaire d'édition (`DynamicEdition`) et
une liste (`DynamicList`). Chaque étape s'appuie sur une API réellement exportée par les
barrels publics — vous pouvez copier chaque bloc tel quel.

## Ajouter la dépendance git {#ajouter-la-dependance}

zcrud n'est pas publié sur pub.dev : il se consomme en **dépendance git**, épinglée sur
un tag de release. La recette complète — y compris le piège des dépendances
inter-`zcrud_*` qui exige un `dependency_overrides` pour **chaque** paquet transitif —
est décrite dans la [recette de consommation](../private-git-consumption.md). Pour ce
guide, votre `pubspec.yaml` a besoin au minimum de `zcrud_core` et `zcrud_annotations`
en dépendance, et de `zcrud_generator` + `build_runner` en dev-dépendance :

```yaml
dependencies:
  zcrud_core:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.80.0, path: packages/zcrud_core }
  zcrud_annotations:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.80.0, path: packages/zcrud_annotations }

dev_dependencies:
  zcrud_generator:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.80.0, path: packages/zcrud_generator }
  build_runner: ^2.4.0

# OBLIGATOIRE dès qu'un paquet zcrud_* supplémentaire entre dans le graphe
# (ex. zcrud_list plus bas dans ce guide) : voir la recette de consommation.
dependency_overrides:
  zcrud_core:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.80.0, path: packages/zcrud_core }
  zcrud_annotations:
    git: { url: git@github.com:zakarius-dev/zcrud.git, ref: v0.80.0, path: packages/zcrud_annotations }
```

## Annoter un modèle {#annoter-un-modele}

Le modèle est la **source unique de vérité** (invariant
[AD-3](concepts/invariants.md#ad-3)) : `@ZcrudModel` sur la classe, `@ZcrudField` sur
chaque champ, `@ZcrudId` sur l'identifiant. Le fichier importe la surface pure
`zcrud_core/edition.dart` (pas le barrel principal, qui tire Flutter) — ce modèle reste
donc utilisable côté serveur ou dans un test `dart test` sans dépendance Flutter.

```dart
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'article.g.dart';

@ZcrudModel(kind: 'article')
class Article {
  const Article({
    this.id,
    required this.title,
    this.published = false,
  });

  /// Reconstruit depuis une map persistée (délègue au décodeur généré défensif).
  factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);

  /// Identité opaque, nullable pour un article pas encore enregistré.
  @ZcrudId()
  final String? id;

  @ZcrudField(
    label: 'Titre',
    validators: <ZValidatorSpec>[
      ZValidatorSpec.required(),
      ZValidatorSpec.minLength(3),
    ],
  )
  final String title;

  @ZcrudField(searchable: true)
  final bool published;
}
```

Toute classe `@ZcrudModel` **doit** déclarer un `fromMap` de domaine (factory ou méthode
statique) : le générateur câble le registrar dessus, et son absence est un échec de
build explicite plutôt qu'un repli silencieux. `toMap()`/`copyWith()` n'ont, eux, rien à
déclarer : ils arrivent avec l'extension générée (`ArticleZcrud`), directement
utilisables sur toute instance (`article.toMap()`).

## Générer le code {#generer-le-code}

```bash
dart run build_runner build --delete-conflicting-outputs
```

Cette commande produit `article.g.dart` (le `part` déclaré ci-dessus) à partir de
`zcrud_generator`, qui lit `@ZcrudModel`/`@ZcrudField` **statiquement**
(`ConstantReader`, jamais de réflexion — `reflectable` est banni du moteur) et émet,
dans l'ordre :

1. `_$ArticleFromMap` — reconstruction défensive (un champ absent ou corrompu retombe
   sur une valeur sûre, jamais un échec du parent — invariant
   [AD-10](concepts/invariants.md#ad-10)) ;
2. l'extension `ArticleZcrud` — `toMap()`, `copyWith()` à sentinelle (un argument omis
   préserve la valeur, `null` explicite la remet à `null`) ;
3. `$ArticleFieldSpecs` — le `List<ZFieldSpec>` projeté 1:1 depuis vos `@ZcrudField`,
   consommé aussi bien par le formulaire que par la liste (détail dans
   [Concept : ZFieldSpec](concepts/zfieldspec.md)) ;
4. `registerArticle(ZcrudRegistry registry)` — le câblage `kind → (fromMap, toMap,
   fieldSpecs)`.

Si le monorepo lui-même est votre point de départ (contribution plutôt que
consommation), l'équivalent multi-paquets est `dart run melos run generate`.

## Enregistrer le modèle {#enregistrer-le-modele}

`ZcrudRegistry` est **instanciable** — pas un singleton statique — pour rester testable
et isolée par app. Un seul appel au bootstrap suffit :

```dart
import 'package:zcrud_core/domain.dart';

import 'article.dart';

final ZcrudRegistry registry = ZcrudRegistry();

void bootstrap() {
  registerArticle(registry);
}
```

Un `kind` non enregistré échoue **explicitement** à la première utilisation
(`registry.decode`/`registry.fieldSpecsFor`) plutôt que de retourner un résultat
dégradé — c'est le contrat de l'invariant [AD-3](concepts/invariants.md#ad-3).

## Construire le formulaire d'édition {#construire-le-formulaire}

`ZFormController` porte l'état du formulaire, `DynamicEdition` l'assemble à partir du
schéma généré. Le contrôleur est **créé et détenu par l'hôte** (jamais recréé au
rebuild) :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'article.dart';

class ArticleFormScreen extends StatefulWidget {
  const ArticleFormScreen({super.key});

  @override
  State<ArticleFormScreen> createState() => _ArticleFormScreenState();
}

class _ArticleFormScreenState extends State<ArticleFormScreen> {
  late final ZFormController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ZFormController(
      initialValues: <String, Object?>{'title': '', 'published': false},
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel article')),
      body: DynamicEdition(
        controller: _controller,
        fields: $ArticleFieldSpecs,
      ),
    );
  }
}
```

Taper dans le champ « Titre » ne reconstruit **que** ce champ — c'est l'objectif produit
n°1 de zcrud, garanti par l'invariant [AD-2](concepts/invariants.md#ad-2) et détaillé
dans [Réactivité granulaire](concepts/reactivite-granulaire.md). À la soumission, lisez
un instantané immuable via `_controller.values`, puis reconstruisez le modèle :

```dart
final article = Article.fromMap(_controller.values);
```

`DynamicEdition` fonctionne sans aucun gestionnaire d'état injecté (défaut
`ZcrudScope`, invariant [AD-6](concepts/invariants.md#ad-6)) ; sous Riverpod, GetX ou
provider, le même contrôleur se branche via `zcrud_riverpod`/`zcrud_get`/
`zcrud_provider` sans changer le code du formulaire ci-dessus (invariant
[AD-15](concepts/invariants.md#ad-15)).

## Afficher la liste {#afficher-la-liste}

`DynamicList` dérive ses colonnes du **même** `$ArticleFieldSpecs` — aucun schéma de
liste séparé à maintenir. La variante `ZListBuilderLayout` se rend entièrement dans
`zcrud_core` (`ListView.builder` Material-free) et ne tire **aucune** dépendance
Syncfusion (invariant [AD-8](concepts/invariants.md#ad-8)) :

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'article.dart';

class ArticleListScreen extends StatelessWidget {
  const ArticleListScreen({required this.articles, super.key});

  final List<Article> articles;

  @override
  Widget build(BuildContext context) {
    final rows = <ZListRow>[
      for (final article in articles)
        ZListRow(id: article.id ?? '', cells: article.toMap()),
    ];
    return DynamicList.rows(
      $ArticleFieldSpecs,
      rows,
      layout: ZListBuilderLayout(
        itemBuilder: (context, row, columns) => ListTile(
          title: Text('${row.cells['title']}'),
          trailing: row.cells['published'] == true
              ? const Icon(Icons.check_circle)
              : null,
        ),
      ),
    );
  }
}
```

Le layout par défaut (omis ci-dessus, `ZListDataGridLayout`) délègue à un
`ZListRenderer` injecté — c'est le backend `SfDataGrid` du paquet
[`zcrud_list`](paquets/) qui l'implémente. Ajoutez cette dépendance (et sa propre
entrée `dependency_overrides`) uniquement si vous voulez le rendu grille complet
(tri/redimensionnement de colonnes) ; le layout `builder` ci-dessus reste une option
Syncfusion-free à part entière, pas un simple repli de démonstration.

## Aller plus loin {#aller-plus-loin}

- [Concept : ZFieldSpec](concepts/zfieldspec.md) — l'anatomie complète du schéma qui
  vient d'être généré, ses familles de champs et sa configuration par type.
- [Réactivité granulaire](concepts/reactivite-granulaire.md) — `isDirty`,
  `reseed`, et les interdits qui garantissent qu'un rebuild reste local à un champ.
- [Architecture hexagonale](concepts/architecture-hexagonale.md) — où brancher un
  vrai dépôt (`ZRepository<T>`) derrière ce formulaire et cette liste, offline-first
  compris.
- [Recette de consommation](../private-git-consumption.md) — la liste complète des
  paquets `zcrud_*` à surcharger dès que votre graphe de dépendances grandit.
