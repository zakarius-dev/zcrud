---
title: "Concept : architecture hexagonale"
description: Couches domain/data/presentation, ports neutres, adaptateurs et carte des 40 paquets.
sidebar_position: 4
---

# Architecture hexagonale

zcrud suit un patron **ports & adapters** : le domaine ne connaît que des contrats
abstraits, et chaque technologie concrète (Firestore, Hive, Syncfusion, Quill…) entre
par un paquet satellite qui implémente ces contrats. Cette page décrit les couches, les
ports du cœur, le patron kernel/satellite et la carte complète des paquets.

## Les trois couches {#les-trois-couches}

Chaque paquet organise son code sous `lib/src/` en (au plus) trois couches :

| Couche | Contenu | Contrainte |
|---|---|---|
| `domain/` | Entités, ports abstraits, échecs (`ZFailure`), value objects | Dart **pur** — jamais `flutter:`, jamais un SDK backend |
| `data/` | Adaptateurs concrets d'un port (Firestore, Hive, HTTP…) | Vit dans le paquet satellite, jamais dans le cœur |
| `presentation/` | Widgets, contrôleurs Flutter (`ChangeNotifier`), rendu | Flutter autorisé, aucun gestionnaire d'état tiers |

Cette séparation est l'invariant [AD-14](invariants.md#ad-14) : la pureté du `domain/`
est vérifiable mécaniquement (aucun import `flutter`/`cloud_firestore`/`hive` dans ces
fichiers), alors que le paquet `zcrud_core` dans son ensemble **autorise** Flutter — le
moteur d'édition (`presentation/`) en a besoin.

## Les ports du domaine {#les-ports-du-domaine}

`zcrud_core` (couche `domain/`) déclare des **ports** — des `abstract class` sans
aucune dépendance backend — que les satellites implémentent. Les plus structurants :

| Port | Rôle |
|---|---|
| `ZRepository<T>` | Contrat complet de persistance d'un agrégat : `watchAll`/`watch`, `getAll`/`getById`, `save`, `softDelete`/`restore`, `count`. Étend `ZReadOnlyRepository<T>`, qui expose la même surface de lecture sans écriture. |
| `ZLocalStore<T>` | Store **local**, source de vérité offline-first : `put`/`putMerged`, `softDelete`/`restore`, et la voie de synchronisation `syncEntries`/`applyMerged`. |
| `ZRemoteStore<T>` | Store **distant**, best-effort : `push`, `remoteDelete`, `pull`, et les mêmes primitives de synchronisation que `ZLocalStore`. |
| `ZAcl` | Autorisation synchrone : `can(ZCrudAction action, {target, collectionId})`. **Sans implémentation déclarée, le repli est `ZDenyAllAcl` — il refuse tout** (voir [AD-16](invariants.md#ad-16)). |
| `ZDataRequest` | Value object neutre de requête : `filters` (`ZFilter`), `sorts` (`ZSort`), `search`, pagination curseur (`limit`/`startAfter`). |

Aucune de ces signatures n'expose un type backend (`Timestamp`, `Filter`,
`FirebaseException`…) — c'est l'invariant [AD-5](invariants.md#ad-5). Toutes les
opérations qui peuvent échouer retournent `ZResult<T>`, l'alias de
`Either<ZFailure, T>` (invariant [AD-11](invariants.md#ad-11)) ; les flux temps réel
sont des `Stream<List<T>>` **nus**, jamais enveloppés.

```dart
import 'package:flutter/foundation.dart';
import 'package:zcrud_core/zcrud_core.dart';

Future<void> chargerUneEntite<T extends ZEntity>(
  ZRepository<T> depot,
  String id,
) async {
  final resultat = await depot.getById(id);
  resultat.fold(
    (echec) => debugPrint('Échec : ${echec.message}'),
    (entite) => debugPrint('Chargé : ${entite.id}'),
  );
}
```

`ZReadOnlyRepository<T>` sert à typer une dépendance qui ne doit **jamais** écrire
(un flux de migration, un écran de consultation) : passer un `ZReadOnlyRepository`
rend l'écriture inexprimable à la compilation, sans décorateur à écrire ni à tester.

## Les adaptateurs {#les-adaptateurs}

`zcrud_firestore` fournit les implémentations concrètes des ports data : un
`ZLocalStore` adossé à Hive (stockage JSON) et un `ZRemoteStore` adossé à Cloud
Firestore. C'est le **seul** endroit du monorepo où `cloud_firestore` et `hive`
apparaissent en dépendance directe d'un port du domaine. La traduction d'un
`ZDataRequest` en requête Firestore concrète (curseur `startAfter`, opérateurs de
filtre) est un détail d'implémentation de cet adaptateur — le contrat neutre ne la
décrit pas.

Un consommateur qui n'importe pas `zcrud_firestore` n'a donc **aucune** dépendance
Firebase transitive : `zcrud_core` seul suffit pour écrire ses propres adaptateurs
(un backend REST, Isar, Drift…) contre les mêmes ports.

## Le patron kernel/satellite {#le-patron-kernel-satellite}

Certaines capacités riches (étude/flashcards, chat) suivent un découpage en deux
temps :

- un paquet **kernel**, Dart pur, qui porte les entités et la logique métier — sans
  aucune dépendance `flutter:` ;
- un ou plusieurs paquets **satellites** qui apportent le rendu Flutter et les
  intégrations tierces, en dépendant du kernel.

`zcrud_study_kernel` (dépend uniquement de `zcrud_core` et `zcrud_annotations`, plus
`meta` pour un point d'extension `@protected`) porte le modèle d'étude ; `zcrud_study`
(Flutter) l'assemble avec `zcrud_mindmap`, `zcrud_flashcard`, `zcrud_exam`,
`zcrud_session` et `zcrud_responsive` pour livrer l'écran complet. De même,
`zcrud_chat_kernel` (Dart pur, dépendant uniquement de `zcrud_core`) porte le modèle
de conversation ; `zcrud_chat` (Flutter) l'assemble avec les rendus riches
(`zcrud_chat_markdown`, `zcrud_chat_material`, `zcrud_chat_study`,
`zcrud_chat_syncfusion`).

Ce découpage a un effet concret : un consommateur qui n'a besoin que du modèle
(migration de données, traitement serveur, test unitaire hors Flutter) importe le
kernel seul et fait tourner sa suite sous `dart test`, sans jamais tirer Flutter.

## `Either<ZFailure, T>` {#either-zfailure-t}

Tout contrat de dépôt retourne `ZResult<T>` — l'alias `Either<ZFailure, T>` de
`package:dartz`. `ZFailure` est une hiérarchie maison, **volontairement non
`sealed`** : `sealed` interdirait à un satellite d'ajouter son propre type d'échec
sans forker le cœur ([AD-4](invariants.md#ad-4)). Les sous-types déjà fournis par le
cœur :

| Type | Cas d'usage |
|---|---|
| `ZDomainFailure` | Règle métier violée, opération invalide |
| `ZCacheFailure` | Échec du store local (lecture/écriture offline) |
| `ZNotFoundFailure` | Entité introuvable (porte `id`/`entity` optionnels) |
| `ZServerFailure` | Échec du store distant |

Le traitement se fait par `fold`/`is`/`message`, jamais par un `switch` exhaustif sur
`ZFailure` — l'exhaustivité compilateur est explicitement sacrifiée pour permettre
l'extension inter-paquet.

## La carte des 40 paquets {#la-carte-des-paquets}

| Capacité | Paquets |
|---|---|
| **Cœur** | `zcrud_core` (schéma, moteur d'édition, ports, thème, l10n) · `zcrud_annotations` · `zcrud_generator` |
| **Bindings d'état** | `zcrud_riverpod` · `zcrud_get` · `zcrud_provider` |
| **Liste & données** | `zcrud_list` (Syncfusion) · `zcrud_firestore` (offline-first) · `zcrud_select` |
| **Rich-text** | `zcrud_markdown` (Quill, LaTeX, tables) · `zcrud_html` |
| **Étude** | `zcrud_study` · `zcrud_study_kernel` · `zcrud_session` · `zcrud_flashcard` · `zcrud_exam` · `zcrud_mindmap` · `zcrud_note` · `zcrud_document` |
| **Chat** | `zcrud_chat` · `zcrud_chat_kernel` · `zcrud_chat_markdown` · `zcrud_chat_material` · `zcrud_chat_study` · `zcrud_chat_syncfusion` |
| **Champs spécialisés** | `zcrud_geo` · `zcrud_geo_location` · `zcrud_intl` (téléphone/pays/devise) · `zcrud_media` · `zcrud_field_extras` |
| **Export** | `zcrud_export` · `zcrud_export_pdf` · `zcrud_export_ui` |
| **UI & navigation** | `zcrud_ui_kit` · `zcrud_responsive` · `zcrud_menu` · `zcrud_navigation` · `zcrud_screen` (écran CRUD assemblé) · `zcrud_dnd` · `zcrud_reorder` |

Chaque paquet expose son API par un barrel unique (`lib/<pkg>.dart`) ; le code sous
`lib/src/` n'est pas un contrat et peut changer sans préavis.

## Le graphe acyclique vérifié par gate {#le-graphe-acyclique-verifie-par-gate}

L'invariant [AD-1](invariants.md#ad-1) — `zcrud_core` en puits du graphe, aucune
dépendance circulaire — n'est pas qu'une convention : un gate de CI construit le
graphe d'adjacence à partir de tous les `pubspec.yaml` (dépendances directes,
dev-dépendances et `dependency_overrides`), prouve son acyclicité par un tri
topologique et vérifie que le degré sortant de `zcrud_core` vers un autre paquet
`zcrud_*` est nul. Toute arête qui romprait l'acyclicité — y compris une dépendance
de développement ou un override temporaire — fait échouer le gate avant merge.

## Voir aussi

- [Invariants d'architecture](invariants.md) — la définition canonique des 16 règles
  AD référencées ici.
- [Réactivité granulaire](reactivite-granulaire.md) — comment la couche
  `presentation/` reste Flutter-native sans gestionnaire d'état imposé.
- [Catalogue des paquets](../paquets/index.md) — une fiche détaillée par paquet.
