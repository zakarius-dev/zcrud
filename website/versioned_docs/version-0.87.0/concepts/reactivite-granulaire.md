---
title: "Concept : réactivité granulaire"
description: Pourquoi le formulaire ne se reconstruit jamais en entier, et comment ZFormController le garantit.
sidebar_position: 3
---

# Réactivité granulaire

C'est l'objectif produit n°1 de zcrud, formalisé par l'invariant
[AD-2](invariants.md#ad-2) : taper 100 caractères dans un champ ne reconstruit **que**
ce champ — jamais le formulaire entier.

## Le problème historique {#le-probleme-historique}

Avant l'extraction en monorepo, le moteur déclaratif dupliqué dans les trois
applications d'origine rafraîchissait le formulaire **entier** à chaque frappe : un
seul `setState` (ou son équivalent côté gestionnaire d'état) à l'échelle du widget
racine, déclenché par chaque `onChanged`. Sur un formulaire à plusieurs dizaines de
champs, chaque caractère saisi reconstruisait donc tous les autres champs — jank
visible, perte de focus, parfois un saut de curseur dans le champ en cours de saisie.
Le problème n'était pas un bug ponctuel mais une **conséquence directe** de
l'architecture : il n'existait aucune frontière de rebuild plus fine que le
formulaire lui-même.

## La solution : `ZFormController` {#la-solution-zformcontroller}

`ZFormController` (`zcrud_core`) est un `ChangeNotifier` **Flutter-natif** — aucun
gestionnaire d'état tiers importé — qui expose une tranche réactive **par champ** :

```dart
import 'package:zcrud_core/zcrud_core.dart';

final controller = ZFormController(
  initialValues: <String, Object?>{'nom': 'Ada'},
);

// Tranche réactive du champ « nom » : TOUJOURS la même instance pour ce nom.
ValueListenable<Object?> tranche = controller.fieldListenable('nom');

// N'écrit QUE la tranche « nom » : aucune autre tranche, aucun rebuild global.
controller.setValue('nom', 'Ada Lovelace');
```

Deux garanties portent toute la granularité :

- **`fieldListenable(name)` renvoie toujours la même instance** pour un `name`
  donné — créée paresseusement au premier accès, puis mémoïsée. C'est ce qui évite
  la recréation d'état à chaque rebuild, cause racine du bug historique.
- **`setValue` ne notifie que la tranche du champ modifié.** Le `ChangeNotifier`
  global du contrôleur (`notifyListeners()`) est réservé à un seul canal :
  `visibleFields`, qui porte l'ensemble ou l'ordre des champs **visibles**
  (utile aux champs conditionnels). Une saisie ne touche jamais ce canal.

Le contrôleur porte aussi des canaux dédiés qui n'élargissent jamais leur portée :
`isDirty` (un champ s'écarte-t-il de sa valeur d'origine), `reveal` (révélation des
erreurs de validation à la soumission) et `reseedRevision` (re-amorçage des widgets à
buffer interne après `reset`/`reseed`, toujours **hors focus**). Chacun est un
`ValueListenable` séparé : un widget « bannière dirty » n'observe que `isDirty`, sans
jamais écouter les tranches de champs.

## Le widget de frontière : `ZFieldListenableBuilder` {#le-widget-de-frontiere}

`ZFieldListenableBuilder` est un fin wrapper de `ValueListenableBuilder` scellé sur
`controller.fieldListenable(name)` : c'est lui qui matérialise la frontière de
rebuild.

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget champNom(ZFormController controller) => ZFieldListenableBuilder(
      controller: controller,
      name: 'nom',
      builder: (context, valeur, _) => Text('$valeur'),
    );
```

Seul le sous-arbre retourné par `builder` reconstruit quand la tranche `nom` change ;
un champ voisin, abonné à une autre tranche, ne bouge pas. `DynamicEdition` et
`ZEditionField` (le champ hôte du moteur d'édition) bâtissent tous les widgets de
champ sur ce même helper — jamais réimplémenté ailleurs dans le cœur.

## Ce que ça change pour l'hôte {#ce-que-ca-change-pour-lhote}

- L'hôte crée **un seul** `ZFormController` par formulaire (généralement dans
  `initState`, disposé dans `dispose`) — pas un `TextEditingController` par champ
  géré à la main, pas de `setState` du widget parent à chaque saisie.
- Lire l'état courant se fait par `controller.values` (snapshot immuable) au moment
  de la soumission, jamais en observant le formulaire entier.
- Recharger des valeurs externes (chargement asynchrone d'un enregistrement) passe
  par `controller.reseed(values)` : la baseline est redéfinie sur ces valeurs, et les
  widgets à buffer interne se ré-amorcent — mais uniquement **hors focus**, jamais en
  écrasant une saisie en cours.

## Les interdits {#les-interdits}

Ces règles sont vérifiées par les tests de garde du cœur, pas seulement documentées :

- **Jamais de `setState` à l'échelle du formulaire.** Une saisie ne doit provoquer
  aucun rebuild au-dessus de la frontière `ZFieldListenableBuilder` du champ modifié.
- **Jamais de `TextEditingController` recréé au rebuild.** Sa stabilité (une
  instance par champ, sur toute la durée de vie du widget) est ce qui préserve le
  curseur et la sélection pendant la saisie.
- **Jamais de ré-injection de valeur qui écrase la sélection.** Le contrôleur
  **détient** la valeur ; il n'écrit jamais dans `TextEditingController.text` en
  retour d'un `setValue` — la saisie est à **sens unique**
  (`onChanged → setValue`). Le seul chemin qui réécrit un buffer de texte est un
  `reset`/`reseed` explicite, et seulement hors focus.

## Rendre la granularité visible : la démo {#rendre-la-granularite-visible}

L'application d'exemple prouve la granularité à l'écran plutôt que de l'affirmer :
`RebuildLog`/`RebuildBadge` (`example/lib/support/rebuild_indicator.dart`) posent un
compteur de reconstructions **par champ**, lui-même construit à l'intérieur d'un
`ZFieldListenableBuilder` scellé sur ce champ — l'indicateur est donc granulaire au
même titre que ce qu'il mesure. Taper dans un champ n'incrémente que son propre
badge ; les compteurs voisins restent immobiles à l'écran, preuve visuelle directe de
l'invariant AD-2.

```dart
import 'package:zcrud_core/zcrud_core.dart';

class RebuildLog {
  final Map<String, int> _counts = <String, int>{};

  int bump(String name) {
    final next = (_counts[name] ?? 0) + 1;
    _counts[name] = next;
    return next;
  }

  int countOf(String name) => _counts[name] ?? 0;
}
```

## `ZcrudScope` et les bindings {#zcrudscope-et-les-bindings}

`ZFormController` ne dit rien de **qui** le crée ni de **comment** il est injecté
dans l'arbre de widgets — c'est le rôle de `ZcrudScope` (invariant
[AD-6](invariants.md#ad-6)) : un `InheritedWidget` **zéro-dépendance** qui porte un
bundle immuable de seams (résolveur de dépendances applicatives, `ZAcl`, libellés,
thème, registres de widgets…) et les expose via `ZcrudScope.of(context)` /
`ZcrudScope.maybeOf(context)`. Un `ZcrudScope` par défaut fonctionne **sans aucun
gestionnaire d'état** : le cycle de vie du contrôleur reste alors possédé par
l'`State` Flutter qui le crée, exactement comme dans les extraits ci-dessus.

L'invariant [AD-15](invariants.md#ad-15) va plus loin : puisque le cœur ne repose que
sur `Listenable`/`ValueListenable`, un même `ZFormController` fonctionne à l'identique
sous n'importe quel gestionnaire d'état. Chaque idiome a son paquet de binding
optionnel, qui enveloppe `ZcrudScope` d'un scope enrichi :

| Binding | Paquet | Ce qu'il ajoute |
|---|---|---|
| Riverpod | `zcrud_riverpod` | `ZRiverpodResolver` (résolution via `ProviderContainer`), `ZcrudRiverpodScope`, `zFormControllerProvider` (provider auto-dispose) |
| GetX | `zcrud_get` | `ZGetResolver` (résolution via `get_it`/GetX), `ZcrudGetScope` (création/scoping/dispose du contrôleur) |
| provider | `zcrud_provider` | `ZProviderResolver` (résolution via `context.read`), `ZcrudProviderScope` (`ChangeNotifierProvider<ZFormController>`) |

Ajouter un nouveau gestionnaire d'état signifie ajouter un nouveau paquet de
binding — jamais modifier le cœur. Le code spécifique à un manager (`WidgetRef`,
`Get.find`, `Provider.of`) reste **confiné** à son paquet de binding et n'entre
jamais dans `zcrud_core`.

## Voir aussi

- [Invariants d'architecture](invariants.md) — définition canonique d'AD-2, AD-6 et
  AD-15.
- [Architecture hexagonale](architecture-hexagonale.md) — où `ZFormController` se
  situe dans la couche `presentation/` du cœur.
