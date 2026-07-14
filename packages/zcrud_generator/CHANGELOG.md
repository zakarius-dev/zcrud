# Changelog

All notable changes to `zcrud_generator` are documented in this file.

## Unreleased

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
