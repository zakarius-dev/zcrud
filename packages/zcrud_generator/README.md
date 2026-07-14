# zcrud_generator

The `build_runner` code generator for zcrud. Add it as a `dev_dependency`; it reads `@ZcrudModel`-annotated models statically and emits `toMap`/`fromMap`/`copyWith`, the `ZFieldSpec[]` and registry registration. Never uses `reflectable`.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_generator: ^0.1.0
```

## Minimal example

```yaml
# pubspec.yaml
dev_dependencies:
  build_runner: ^2.5.0
  zcrud_generator: ^0.1.0
```

```bash
# Then generate the *.g.dart companions:
dart run build_runner build --delete-conflicting-outputs
```

## ⚠️ Required: a domain `fromMap` on every `@ZcrudModel`

The generated registrar wires **your** decoder — `fromMap: Xxx.fromMap` — not the
generated `_$XxxFromMap`. Declaring it is a **contract**: its absence is a build
failure, never a silent fallback.

```dart
@ZcrudModel(kind: 'article')
class Article {
  // factory OR static method; extra OPTIONAL parameters are allowed.
  factory Article.fromMap(Map<String, dynamic> map) => _$ArticleFromMap(map);
  ...
}
```

**If your class is `ZExtensible`** (it carries an `extra` slot), the delegation
above is **rejected at build time**. `_$XxxFromMap` only knows `@ZcrudField`
fields, so it leaves `extra` **empty** — and a store wired on `registry.decode`
would then erase every business key unknown to the schema on each read → write
cycle, irreversibly. Populate `extra` on the way in, and re-emit it on the way out
(the **generated** `toMap()` does *not* spread `extra`):

```dart
@ZcrudModel(kind: 'flashcard')
class ZFlashcard with ZExtensible {
  factory ZFlashcard.fromMap(Map<String, dynamic> map) {
    final base = _$ZFlashcardFromMap(map);          // schema fields
    return ZFlashcard(/* …copied from `base`… */, extra: _extraFrom(map));
  }

  /// Shadows the generated `toMap()`, which does not spread `extra`.
  Map<String, dynamic> toMap() => {...extra, ...ZFlashcardZcrud(this).toMap()};

  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZFlashcardFieldSpecs) spec.name,
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>
      Map<String, dynamic>.unmodifiable({
        for (final e in map.entries)
          if (!_reservedKeys.contains(e.key)) e.key: e.value,
      });
}
```

The emitted `registerZFlashcard` carries an **executable guard** that decodes a
probe and requires the out-of-schema key to survive the **full round-trip**
(`fromMap` *and* `toMap`), raising a `StateError` at registration otherwise. It is
not behind `assert`: the net holds in release, where the loss is permanent.

See `CHANGELOG.md` for the migration note.

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
