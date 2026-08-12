# Changelog

All notable changes to `zcrud_annotations` are documented in this file.

## 0.88.0 — 2026-08-12

### Ajouté

- **`@ZcrudIgnore`** — marqueur excluant explicitement un champ d'instance de la
  (dé)sérialisation générée. Il lève l'échec de build que `zcrud_generator` émet
  désormais sur un champ **non annoté dont le type n'est pas sérialisable**, sans
  rien ajouter au code émis : le champ reste absent de `toMap()`, du décodeur, du
  `ZFieldSpec[]` et de l'inventaire des clés persistées. C'est la façon d'assumer,
  au point de déclaration, un canal sérialisé à la main, un collaborateur
  d'exécution, un cache ou une valeur dérivée — la donnée n'est alors **pas**
  écrite par le codegen. Inutile sur les champs privés et, pour une classe
  `ZExtensible`, sur les slots AD-4 (`extension`, `extra`) : le générateur les
  exempte d'office. Combiné à `@ZcrudField` ou `@ZcrudId` sur le même champ,
  c'est une contradiction refusée au build. Exporté par le barrel.

### Documentation

- La dartdoc de `@ZcrudModel` dit maintenant **quels champs sont sérialisés**
  (seuls les champs annotés) et dans quel cas l'omission devient un échec de
  build.
- Elle explique aussi pourquoi les clés de synchronisation `updated_at` /
  `is_deleted` sont **omises lorsqu'elles sont nulles**, là où une clé métier
  comme `created_at` est toujours émise : ces clés appartiennent à la couche de
  synchronisation, hors-entité.
- `@ZcrudField.persistAs` porte un avertissement explicite : le `toMap()` généré
  émet **toute** date en `String` ISO-8601 ; le format natif est appliqué par le
  **repository**. Un moteur de persistance qui appelle `toMap()` directement,
  sans passer par lui, écrira des `String` là où le parc attend le type natif.

### ⚠️ BREAKING (contract, enforced by `zcrud_generator`)

Every `@ZcrudModel` class must now declare a **domain** decoder
`Xxx.fromMap(Map<String, dynamic> map)` (factory *or* static method). A
`ZExtensible` class must additionally **populate `extra`** in it and **re-emit
`extra`** from an instance `toMap()`.

No code changed in this package — but `@ZcrudModel`'s dartdoc now carries the
contract, because that is where a consumer reads it *before* hitting the build
error. Full rationale and migration steps: `zcrud_generator/CHANGELOG.md`.

## 0.1.0

Initial public release.

- Declarative annotations consumed by the zcrud code generator.
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
