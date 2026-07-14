# Changelog

All notable changes to `zcrud_annotations` are documented in this file.

## Unreleased

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
