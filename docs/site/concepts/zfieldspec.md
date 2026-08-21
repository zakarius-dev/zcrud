---
title: "Concept : ZFieldSpec"
description: L'anatomie du schéma déclaratif qui pilote à la fois le formulaire et la liste — familles, configuration, sous-schémas.
sidebar_position: 2
---

# ZFieldSpec

`ZFieldSpec` est le concept central de zcrud : **un** schéma de champs, projeté depuis
votre modèle annoté, pilote à la fois le formulaire d'édition (`DynamicEdition`) et la
colonne de liste (`DynamicList`) — sans duplication. Cette page décrit son anatomie, le
trajet modèle → spec → widget, et les deux façons dont un `ZFieldSpec` porte plus qu'un
type de champ nu : la configuration par famille et les sous-schémas.

## Anatomie d'un `ZFieldSpec` {#anatomie}

`ZFieldSpec` (`zcrud_core`, couche `domain/`) est une classe **pur-données `const`** :
aucune closure, aucun widget, aucune dépendance Flutter — c'est ce qui la rend lisible
statiquement par le générateur et stable en égalité de valeur (`==`/`hashCode`) pour la
mémoïsation runtime. Elle ne fait que **porter la donnée** ; l'interprétation (type →
widget, validateurs → `FormBuilderValidators`, condition → visibilité) appartient à la
couche présentation.

| Champ | Rôle |
|---|---|
| `name` | Clé persistée du champ (snake_case par défaut, invariant [AD-3](invariants.md#ad-3)). |
| `type` | `EditionFieldType` — fourni par `@ZcrudField.type` ou **inféré** du type Dart statique. |
| `label` | Libellé d'affichage (clé l10n ou littéral, résolu côté UI). |
| `validators` | `List<ZValidatorSpec>` déclaratifs, composés en validateurs exécutables. |
| `config` | Configuration spécialisée par type (`ZFieldConfig` — voir plus bas). |
| `choices` | `List<ZFieldChoice>` — options statiques pour `select`/`radio`/`checkbox`. |
| `condition` | `ZCondition?` — visibilité conditionnelle **déclarative**, jamais une closure. |
| `searchable` | Participation du champ à la recherche/filtre de la liste. |
| `defaultValue` | Valeur appliquée par `fromMap` si la clé est absente. |
| `readOnly` / `showIfNull` | Champ non éditable / visible même vide en mode lecture global. |
| `multiple` | Multi-valeur (`List<…>` ou `@ZcrudField(multiple: true)`). |
| `isId` | `true` si le champ porte `@ZcrudId`. |
| `leading` / `prefix` / `suffix` | Ornements (`ZFieldAdornment`) — texte, icône ou widget nommé. |
| `hintText` / `helperText` | Texte indicatif / texte d'aide sous le champ. |
| `derivedFrom` | Seule surcharge **runtime** (porte des closures) — posée par l'hôte via `copyWith`, jamais émise par le générateur. |

`isRequired` (accesseur calculé) est vrai dès que `validators` contient un
`ZValidatorKind.required` — c'est lui qui alimente l'astérisque « requis » du libellé,
sans dépendance Flutter dans le domaine.

## Une condition, en données {#condition-en-donnees}

`ZCondition` illustre la discipline générale : là où un moteur legacy accepterait une
closure `(item, state, crud) → bool`, `ZFieldSpec.condition` reste une **structure**
comparable et composable — `equals`/`notEquals`/`truthy`/`isEmpty`/`and`/`or`/`not`,
etc. :

```dart
import 'package:zcrud_core/edition.dart';

const condition = ZCondition.equals('status', 'published');
```

L'**évaluation** contre l'état du formulaire vit dans `DynamicEdition`, abonnée
uniquement aux champs référencés par la condition — jamais un canal global. C'est la
même discipline « donnée, pas closure » qui rend `ZFieldSpec` entier lisible par
`ConstantReader` (invariant [AD-3](invariants.md#ad-3)).

## Du modèle au widget : le trajet complet {#du-modele-au-widget}

```
@ZcrudModel / @ZcrudField     (authoring, zcrud_annotations)
        │  générateur zcrud_generator (ConstantReader, jamais reflectable)
        ▼
$XxxFieldSpecs : List<ZFieldSpec>   (runtime, pur-données)
        │
        ├─► DynamicEdition(fields: $XxxFieldSpecs)   → familyOf(type) → widget de champ
        └─► DynamicList(fields: $XxxFieldSpecs)      → deriveColumns  → colonne de liste
```

`@ZcrudField.type` est optionnel : quand il est omis, le générateur **infère**
`EditionFieldType` depuis le type Dart statique du champ :

| Type Dart | `EditionFieldType` inféré |
|---|---|
| `String` | `text` |
| `int` | `integer` |
| `double` | `float` |
| `num` | `number` |
| `bool` | `boolean` |
| `DateTime` | `dateTime` |
| `ZDateRange` | `dateRange` |
| `enum` | `select` |
| classe annotée `@ZcrudModel` | schéma imbriqué (voir [Sous-schémas](#sous-schemas)) |

Un type Dart non couvert par cette table (ni scalaire, ni enum, ni `@ZcrudModel`) fait
échouer la génération **explicitement**, jamais par un cast silencieux — cohérent avec
la désérialisation défensive de l'invariant [AD-10](invariants.md#ad-10), qui protège le
runtime, pas la génération.

## Familles de champs {#familles-de-champs}

`EditionFieldType` est le catalogue **canonique** — plus de trente valeurs, de `text` à
`mediaVideo`. Pour piloter le rendu, `familyOf(EditionFieldType) → EditionFamily` les
classe en un nombre réduit de familles de rendu, via un `switch` exhaustif **sans
clause `default`** : ajouter un `EditionFieldType` sans le classer casse la compilation
plutôt que de retomber silencieusement dans un repli.

| `EditionFamily` | Types couverts | Rôle |
|---|---|---|
| `text` | `text`, `multiline`, `password` | Champ texte, `TextEditingController` stable. |
| `number` | `number`, `integer`, `float` | Champ numérique typé, contrôleur stable. |
| `date` | `dateTime`, `time` | Déclencheur de picker, valeur ISO-8601. |
| `dateRange` | `dateRange` | Déclencheur de picker de **plage**, valeur `ZDateRange`. |
| `boolean` | `boolean` | Interrupteur (`Switch`) avec état sémantique. |
| `select` | `select`, `radio`, `checkbox` | Options depuis `ZFieldSpec.choices`. |
| `relation` | `relation` | Sélecteur d'entité liée, source injectable au runtime. |
| `tags` | `tags` | Saisie multi-valeur à puces (`List<String>`). |
| `rowChips` | `rowChips` | Rangée de puces mono-choix depuis `choices`. |
| `rating` | `rating` | Note en étoiles/segments. |
| `slider` | `slider` | Curseur borné. |
| `color` | `color` | Sélecteur de couleur (`int` ARGB, ou `List<int>` en `multiple`). |
| `subList` | `subItems` | Mini-CRUD imbriqué — voir [Sous-schémas](#sous-schemas). |
| `dynamicItem` | `dynamicItem` | Sous-formulaire dynamique à cardinalité ≤ 1. |
| `signature` | `signature` | Capture gestuelle, valeur en tranche. |
| `freeWidget` | `widget` | Widget libre fourni par l'hôte via un registre injecté. |
| `registryOrFallback` | `markdown`, `richText`, `location`, `geoArea`, `phoneNumber`, `country`, `pin`, `custom`, … | Type **nommé** au cœur ; widget servi par un satellite (`zcrud_markdown`, `zcrud_geo`, `zcrud_intl`…) via un registre injecté — repli contrôlé si non enregistré. |
| `file` | `file`, `image`, `document` | Champ fichier, seams picker/stockage injectés. |
| `hidden` | `hidden` | Valeur conservée, aucun rendu. |
| `unsupported` | `stepper` | Repli contrôlé (`ZUnsupportedFieldWidget`) — jamais une exception. |

Cette classification explique pourquoi zcrud reste modulaire par construction :
`registryOrFallback` **nomme** un type au cœur (`markdown`, `phoneNumber`, `geoArea`…)
sans jamais y importer le paquet qui le rend — invariant
[AD-1](invariants.md#ad-1). Tant que l'hôte n'importe pas `zcrud_markdown`, un champ
`markdown` dégrade proprement en repli plutôt que de tirer Quill.

## Configuration par famille {#configuration-par-famille}

`ZFieldSpec.config` accueille une sous-classe de `ZFieldConfig` — base `abstract`
`const`, point d'extension de l'invariant [AD-4](invariants.md#ad-4) : jamais `sealed`,
pour qu'un satellite ou une app hôte ajoute sa propre config sans forker le cœur. Les
configurations triviales, pur-cœur, vivent directement dans `zcrud_core` :

| Config | Champ ciblé | Porte |
|---|---|---|
| `ZTextConfig` | `text`/`multiline` | Lignes min/max, indice de clavier neutre, capitalisation, transformation de saisie injectable. |
| `ZNumberConfig` | `number`/`integer`/`float` | Bornes (littérales ou clé d'un autre champ), formatage monnaie/pourcentage. |
| `ZColorConfig` | `color` | Canal alpha, palette, couleurs récentes, variante `.multiple`. |
| `ZSliderConfig` | `slider` | Bornes `min`/`max` (défaut `0..100`), `divisions`. |
| `ZBooleanConfig` | `boolean` | Variante d'affichage (interrupteur/encart). |
| `ZSelectConfig` | `select`/`radio`/`checkbox` | Recherche modale, seuil de bascule en modal, choix calculés cross-champ. |
| `ZRelationConfig` | `relation` | Clé de source dynamique résolue au runtime (`ZRelationSourceRegistry`), filtres cross-champ. |
| `ZSubListConfig` | `subItems`/`dynamicItem` | Le **sous-schéma** de l'item — voir ci-dessous. |

Une config est `const` pur-données au même titre que `ZFieldSpec` : les configurations
**lourdes** (géolocalisation, fichiers riches, barre d'outils rich-text, assistant
multi-étapes) appartiennent à leurs paquets satellites respectifs et n'entrent jamais
dans `zcrud_core`.

```dart
import 'package:zcrud_core/edition.dart';

const config = ZTextConfig(maxLines: 4, capitalization: ZTextCapitalization.sentences);
```

## Sous-schémas : champs imbriqués {#sous-schemas}

Un champ `subItems` (mini-CRUD imbriqué : ajouter/retirer/réordonner une liste
d'éléments) ou `dynamicItem` (le même mécanisme à cardinalité ≤ 1) ne porte pas un type
scalaire mais un **sous-schéma** complet : `ZSubListConfig.itemFields`, un
`List<ZFieldSpec>` `const` au même titre que le schéma racine.

`ZSubListConfig` vit sous `src/domain/edition/z_sub_list_config.dart` et s'importe via
la surface domaine complète (`domain.dart`), pas via le point d'entrée `edition.dart`
plus restreint :

```dart
import 'package:zcrud_core/domain.dart';

const coauthorField = ZFieldSpec(
  name: 'coauthors',
  type: EditionFieldType.subItems,
  label: 'Co-auteurs',
  config: ZSubListConfig(
    itemFields: <ZFieldSpec>[
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
      ZFieldSpec(name: 'email', type: EditionFieldType.text, label: 'E-mail'),
    ],
    reorderable: true,
  ),
);
```

Côté widget, `ZSubListConfig.displayMode` décide de la présentation, et son défaut est
`ZSubListDisplayMode.compact` : une **table de résumé** (une ligne par item, une colonne
par valeur de `summaryFields`) doublée d'un **formulaire d'édition par item**, chaque
geste filtré par l'`ZAcl`. Deux autres modes se déclarent en une ligne :
`ZSubListDisplayMode.inline` déballe tous les sous-champs de chaque item en
sous-formulaires imbriqués, `ZSubListDisplayMode.tags` rend une rangée de puces.
`ZSubItemFormPresentation` choisit l'enveloppe du formulaire d'item — `dialog`
(défaut), `sheet` ou `page`.

Quel que soit le mode, chaque item est édité par un `ZFormController` **propre à
l'item**, qui réutilise le même dispatcher de champ que le formulaire racine. La
granularité de rebuild reste imbriquée : taper dans le champ d'un
item ne reconstruit que ce champ, jamais le conteneur ni les items voisins (même
discipline que l'invariant [AD-2](invariants.md#ad-2) au niveau racine). Un modèle
`@ZcrudModel` imbriqué (`List<Author> coauthors`, `Author? author`) obtient
automatiquement ce sous-schéma par inférence — le générateur projette le
`@ZcrudModel` cible en `ZFieldSpec` imbriqués sans configuration manuelle.

## Voir aussi

- [Invariants d'architecture](invariants.md) — la définition canonique d'AD-1 à AD-16.
- [Réactivité granulaire](reactivite-granulaire.md) — comment `ZFormController`
  consomme un `ZFieldSpec` pour n'exposer qu'une tranche réactive par champ.
- [Architecture hexagonale](architecture-hexagonale.md) — où `ZFieldSpec` se situe
  dans la couche `domain/` du cœur, et comment les satellites étendent son point
  d'extension `ZFieldConfig`.
- [Démarrage rapide](../demarrage-rapide.md) — le trajet complet, d'un modèle annoté
  à un écran CRUD.
