# Changelog

All notable changes to `zcrud_generator` are documented in this file.

## 0.88.0 — 2026-08-12

### Corrigé

- **`@ZcrudModel(fieldRename:)` était ignoré** : quelle que soit la stratégie
  déclarée (`none`, `kebab`, `pascal`), les clés persistées étaient renommées en
  `snake_case`. La lecture de l'énumération d'annotation comparait un accesseur
  **qualifié** (`ZFieldRename.none`) à un nom nu, et retombait donc toujours sur
  la branche par défaut. Adopter le codegen sur un parc documentaire existant
  renommait ainsi **toutes** les clés : documents déjà écrits devenus illisibles
  par le décodeur généré, et documents neufs illisibles par le chemin hérité.
  Les quatre stratégies sont désormais exercées de bout en bout sur la sortie
  émise.
- La même lecture d'énumération sert `@ZcrudField(persistAs:)` et toute valeur
  d'énumération re-émise dans un `ZFieldSpec`. Elle lit désormais le **dernier
  segment de l'accesseur qualifié** que l'analyse rend pour toute constante
  d'enum, ce qui la rend **insensible aux alias `const`**, aux préfixes d'import
  et à la forme d'écriture (mesuré sur les quatre stratégies et `persistAs`,
  écrits littéralement et derrière un alias).

### Modifié — durcissement cassant

- **Un champ non annoté de type non sérialisable est désormais un échec de
  build.** Seuls les champs annotés sont sérialisés ; un tel champ disparaissait
  du document persisté sans aucun signal. Le build le refuse, nomme **tous** les
  champs fautifs du modèle en une passe (champs déclarés **et** champs concrets
  hérités d'une super-classe ou d'un mixin hors SDK) et cite les trois remèdes :
  donner au champ un type sérialisable et l'annoter `@ZcrudField` ; annoter le
  type `@ZcrudModel` **et** le champ `@ZcrudField` ; ou déclarer l'exclusion
  avec `@ZcrudIgnore`.

  **Qui est concerné.** Tout modèle `@ZcrudModel` portant un champ **public**
  non annoté dont le type n'est ni scalaire supporté, ni `enum`, ni classe
  `@ZcrudModel` — typiquement un canal sérialisé à la main (`source`,
  `learning`…) ou un sous-objet métier oublié. **Ne sont PAS concernés** (exemptés
  d'office) : les champs **privés** (`_xxx`), les slots AD-4 d'une classe
  `ZExtensible` (`extension`, `extra`) — déjà couverts par le contrat de factory
  de domaine et le garde d'extensibilité —, les champs statiques, et tout champ
  non annoté de type **sérialisable** (contrat inchangé : ignoré en silence).
  Mesure sur le monorepo après exemptions : 4 champs sur 21 modèles ont réclamé
  `@ZcrudIgnore`, tous des canaux hors-codegen déjà documentés comme tels.
- **`@ZcrudIgnore` combiné à `@ZcrudField` ou `@ZcrudId` sur le même champ est
  un échec de build** : les deux déclarations se contredisent, aucune résolution
  silencieuse n'est appliquée.

### Ajouté

- **Prise en charge de `@ZcrudIgnore`** (nouvelle annotation de
  `zcrud_annotations`) : lève l'échec ci-dessus sans rien ajouter au code émis.
  `@ZcrudIgnore` signifie « cette donnée n'est **pas** écrite par le codegen » —
  un canal manuel (`fromMap`/`toMap` de domaine, slot `extra`) reste à la charge
  de l'auteur si la donnée doit vivre dans le document.
- Une valeur de `fieldRename` non reconnue — ou illisible sous résolution
  dégradée — est un **échec de build explicite**, jamais un repli muet sur
  `snake`.

### Documentation

- La dartdoc du générateur explique désormais, au point d'usage, pourquoi les
  clés de synchronisation `updated_at` / `is_deleted` sont **omises quand elles
  sont nulles** alors qu'une clé métier comme `created_at` est toujours émise —
  l'asymétrie tient au statut de la clé, pas au type du champ.
- Avertissement explicite : le `toMap()` généré émet **toute** date en `String`
  ISO-8601 ; le format natif du backend est appliqué par le **repository** via
  `$XxxTimestampFields`. Un moteur de persistance qui appelle `toMap()`
  directement écrira des `String` là où le parc attend le type natif.

#### Migration

Un modèle qui déclarait `fieldRename` autrement que `snake` voit ses clés
persistées **changer** à la prochaine génération — c'est la correction attendue,
mais elle doit être rapprochée du format réellement présent sur disque avant
d'être déployée. Un modèle portant des champs **publics** non annotés de type
non sérialisable (hors exemptions ci-dessus) devra les qualifier
(`@ZcrudField`, `@ZcrudModel` sur le type **et** `@ZcrudField` sur le champ, ou
`@ZcrudIgnore`) : le build les nomme tous en une passe. Un champ qui portait
`@ZcrudIgnore` **et** `@ZcrudField`/`@ZcrudId` doit perdre l'une des deux
annotations.

### ⚠️ BREAKING — every `@ZcrudModel` class must now declare a domain `fromMap`

**What changed.** The generated registrar now wires the **domain** decoder
(`fromMap: Xxx.fromMap`) instead of the **codegen** one (`fromMap: _$XxxFromMap`).

**Why.** `_$XxxFromMap` only knows `@ZcrudField`-annotated fields. It never
populates the *out-of-codegen* channels — `extra` (the AD-4 escape hatch),
`extension`, `source`. Any store wired on `registry.decode`
(`FirebaseZRepositoryImpl.fromRegistry`) therefore **destroyed every business key
unknown to the schema, silently and irreversibly, on each read → write cycle**
(debt `DW-ES14-1`).

**Migration.** Declare `Xxx.fromMap(Map<String, dynamic> map)` — a **factory**
*or* a **static method**; extra **optional** parameters are allowed
(`extensionParser`, `sourceRegistry`…).

- Class **without** an `extra` slot (plain value object): a bare delegation is
  correct and remains legal.

  ```dart
  factory ZChoice.fromMap(Map<String, dynamic> map) => _$ZChoiceFromMap(map);
  ```

- Class **`ZExtensible`** (it has an `extra` slot): a bare delegation is
  **REJECTED AT BUILD TIME** — it *is* the defect above. Populate `extra` on the
  way in, and re-emit it on the way out (the **generated** `toMap()` does *not*
  spread `extra`):

  ```dart
  factory ZFlashcard.fromMap(Map<String, dynamic> map) {
    final base = _$ZFlashcardFromMap(map);            // schema fields
    return ZFlashcard(/* …copied from `base`… */, extra: _extraFrom(map));
  }

  Map<String, dynamic> toMap() =>
      {...extra, ...ZFlashcardZcrud(this).toMap()};   // instance toMap
  ```

### Enforcement — three machine nets (no net relies on prose)

1. **Build** — missing decoder, or a signature no `Map<String, dynamic>` can be
   assigned to ⇒ `InvalidGenerationSourceError`.
2. **Build** — a `ZExtensible` class whose `fromMap` **bare-delegates** to
   `_$XxxFromMap` ⇒ `InvalidGenerationSourceError`. Detected on the constructor
   **body AST** (`package:analyzer`), never by regex.
3. **Runtime** — the emitted `registerXxx` of a `ZExtensible` class carries an
   **executable guard**: it decodes a probe carrying an out-of-schema key and
   requires it to **survive the full round-trip** (`fromMap` *and* `toMap`),
   raising an explicit `StateError` at registration. It is deliberately **not**
   behind `assert` — the net must hold in release, where the data loss is
   permanent.

### Fixed

- Signature validation compared the **display string**
  (`getDisplayString() == 'Map<String, dynamic>'`), so it wrongly **rejected**
  legal, assignable decoders: `Map<String, Object?>`, a `typedef` alias, an
  import-prefixed form. It now compares **types** via the analyzer `TypeSystem`.
- A `fromMap` declared as a **static method** (a perfectly valid tear-off) was
  rejected with a message claiming no `fromMap` existed at all. Static decoders
  are now accepted.

## 0.1.0

Initial public release.

- The `build_runner` code generator for zcrud.
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
