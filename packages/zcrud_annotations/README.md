# zcrud_annotations

Annotations déclaratives consommées par `zcrud_generator` — le modèle annoté
est la source unique de vérité du schéma (invariant AD-3).

## Aperçu {#apercu}

`zcrud_annotations` ne contient **aucun comportement** : quatre annotations
`const` pur-données (`@ZcrudModel`, `@ZcrudField`, `@ZcrudId`, `@ZcrudIgnore`)
et l'enum `ZPersistAs`. `zcrud_generator` les lit **statiquement** au moment du
`build_runner` (`ConstantReader`, jamais d'exécution ni de réflexion) pour
émettre `toMap`/`fromMap`/`copyWith`, le `ZFieldSpec[]` du champ et
l'enregistrement au `ZcrudRegistry`.

Ce paquet ne dépend que de `zcrud_core` (invariant AD-1 : graphe acyclique,
zéro dépendance lourde) — l'annoter dans un modèle ne tire ni Flutter, ni
Firebase, ni aucun gestionnaire d'état.

**Utilisez ce paquet** pour annoter vos modèles de domaine consommés par le
schéma `zcrud` (édition **et** liste, depuis la même déclaration).
**N'utilisez pas ce paquet** seul : sans `zcrud_generator` dans vos
`dev_dependencies`, les annotations n'ont aucun effet — elles ne sont lues
qu'au moment du codegen.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`. Ajoutez aussi `zcrud_generator` en
`dev_dependency` : sans lui, ces annotations ne produisent rien.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_annotations/zcrud_annotations.dart';

@ZcrudModel(kind: 'note')
class Note {
  const Note({required this.id, required this.title});

  /// Décodeur de domaine exigé par le contrat de [ZcrudModel] — voir
  /// « Cas limites et invariants » plus bas.
  factory Note.fromMap(Map<String, dynamic> map) => _$NoteFromMap(map);

  @ZcrudId()
  final String? id;

  @ZcrudField(label: 'Titre', searchable: true)
  final String title;
}
```

## Concepts clés {#concepts-cles}

- **Le modèle est la source unique de vérité (invariant [AD-3](../../docs/site/concepts/invariants.md#ad-3))** —
  une seule déclaration `@ZcrudModel`/`@ZcrudField` pilote à la fois le
  formulaire d'édition et la colonne de liste ; aucune double définition de
  schéma à maintenir en synchronisation.
- **Lecture statique, jamais de réflexion** — `zcrud_generator` lit ces
  annotations via `ConstantReader` à la compilation. `reflectable` est banni
  du moteur : un modèle mal annoté échoue au **build**, jamais silencieusement
  à l'exécution.
- **`persistAs` et le confinement du backend (invariant [AD-5](../../docs/site/concepts/invariants.md#ad-5))** —
  `ZPersistAs.timestamp` fait collecter par le générateur un artefact neutre
  (`Set<String>` de clés) ; c'est `zcrud_firestore`, seul, qui traduit ce hint
  en `Timestamp` natif. Ce paquet ne référence jamais `cloud_firestore`.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZcrudModel` | Annotation de classe : déclare un modèle sérialisable et enregistrable, porte le contrat `fromMap` obligatoire. |
| `ZcrudField` | Annotation de champ : projette chaque paramètre dans le `ZFieldSpec` correspondant (label, type, validateurs, condition, ornements…). |
| `ZcrudId` | Marqueur du champ identifiant (`id`) d'un modèle. |
| `ZcrudIgnore` | Marqueur d'exclusion : le champ n'est **pas** écrit par le codegen. Requis sur un champ non annoté dont le type n'est pas sérialisable (sinon échec de build) ; la donnée qu'il porte relève alors d'un canal manuel (`fromMap`/`toMap` de domaine, slot `extra`). |
| `ZPersistAs` | Hint de format de persistance d'un champ date (`iso8601` par défaut, ou `timestamp` pour Firestore natif). |
| `ZAnnotationsApi` | Marqueur de version de l'API publique du paquet. |

## Cas limites et invariants {#cas-limites}

- **`fromMap` est obligatoire, sans exception** — toute classe `@ZcrudModel`
  doit déclarer une factory ou méthode statique `fromMap`. Son absence est un
  **échec de build**, jamais un repli silencieux : voir la dartdoc de
  [ZcrudModel] pour le détail des trois filets de vérification.
- **Une classe `ZExtensible` ne peut pas déléguer nuement** — si le modèle
  porte un slot `extra` (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4)),
  son `fromMap` doit peupler `extra` et son `toMap()` d'instance doit le
  réémettre ; déléguer directement au décodeur généré effacerait toute clé
  métier hors schéma à chaque cycle lecture/écriture.
- **`type` non déclaré ⇒ inféré, jamais absent** — un `@ZcrudField` sans
  `type` explicite se voit attribuer un type déduit du type Dart statique du
  champ (`String`→`text`, `bool`→`boolean`, `enum`→`select`…).
- **Un champ non annoté n'est pas sérialisé — et le build refuse le silence
  qui coûterait des données** — un champ non annoté de type sérialisable reste
  ignoré (contrat assumé) ; un champ non annoté dont le type n'est **pas**
  sérialisable est un échec de build, à lever par `@ZcrudField`, `@ZcrudModel`
  sur le type **et** `@ZcrudField` sur le champ, ou `@ZcrudIgnore`. Sont
  exemptés : les champs privés et, sur une classe `ZExtensible`, les slots
  AD-4 (`extension`, `extra`).
- **Rien ici n'accepte de closure** — un builder de widget libre, un
  validateur dépendant de l'état ou une relation dynamique ne s'expriment pas
  dans l'annotation (illisible par `ConstantReader`) : ils se câblent au
  runtime via `ZTypeRegistry` ou `ZFormController`.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_annotations.md`](../../docs/site/paquets/zcrud_annotations.md)
- `zcrud_generator` — le générateur `build_runner` qui lit ces annotations.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
