---
title: zcrud_core
description: Domaine pur et moteur d'édition/liste Flutter-natif — le pivot de l'écosystème zcrud.
---

# zcrud_core

## Rôle

`zcrud_core` est le **puits du graphe de dépendances** de l'écosystème zcrud
(invariant [AD-1](../concepts/invariants.md#ad-1)) : il porte le schéma
déclaratif `ZFieldSpec`, le moteur d'édition `DynamicEdition`, le moteur de
liste `DynamicList`, les ports de domaine (`ZRepository`, `ZLocalStore`,
`ZAcl`…) et la réactivité Flutter-native (`ZFormController`,
`ChangeNotifier`/`ValueListenable`). Il n'importe aucun autre paquet
`zcrud_*`, aucun gestionnaire d'état, aucun backend lourd — tous les autres
paquets du dépôt en dépendent.

Sa couche `domain/` est pur-Dart et exposée seule par
`package:zcrud_core/domain.dart`, pour les satellites dont seuls les modèles
ont besoin de rester transitivement pur-Dart.

## Quand l'utiliser

- Pour tout **formulaire d'édition** ou **tableau de liste** de l'écosystème
  zcrud : `ZFieldSpec` pilote les deux depuis une seule déclaration.
- Pour un état de formulaire qui ne reconstruit **jamais** l'écran entier à la
  frappe (invariant [AD-2](../concepts/invariants.md#ad-2)) — l'objectif
  produit historique de l'extraction du moteur.
- Pour un **contrat repository backend-agnostique** (`ZRepository<T>`) que
  n'importe quel adaptateur (`zcrud_firestore` ou un autre) peut implémenter.

## Quand ne pas l'utiliser

- Pour du rendu Markdown/LaTeX riche : c'est `zcrud_markdown`, qui dépend de
  `zcrud_core` et se branche via `ZWidgetRegistry`.
- Pour une grille de données `SfDataGrid` : c'est `zcrud_list`, qui implémente
  le port neutre `ZListRenderer` exposé ici.
- Pour la persistance Firestore/Hive concrète : ce sont les adaptateurs de
  `zcrud_firestore`, qui implémentent les ports neutres `ZRepository`/
  `ZLocalStore`/`ZRemoteStore`.
- Pour brancher un gestionnaire d'état particulier (Riverpod/GetX/provider) :
  ce sont les paquets de binding (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`),
  qui injectent le cycle de vie sans que le cœur en dépende.

## Types clés

| Type | Rôle |
|---|---|
| `ZFieldSpec` / `EditionFieldType` | Schéma déclaratif `const` d'un champ, source unique pour l'édition et la liste. |
| `ZFormController` | Contrôleur `ChangeNotifier` du formulaire — une `ValueListenable` par champ (invariant [AD-2](../concepts/invariants.md#ad-2)). |
| `DynamicEdition` / `DynamicList` | Formulaire et liste de référence, dispatchés par type de champ / mise en page. |
| `ZRepository<T>` / `ZFailure` | Contrat repository backend-agnostique et hiérarchie d'erreurs maison (invariant [AD-5](../concepts/invariants.md#ad-5)/[AD-11](../concepts/invariants.md#ad-11)). |
| `ZcrudScope` / `ZcrudTheme` | Injection zéro-dépendance (resolver, l10n, thème) et jetons visuels thémés. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_core/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — couches et ports.
- [Offline-first](../concepts/offline-first.md) — AD-9 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
