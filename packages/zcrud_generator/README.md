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

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
