# zcrud_navigation

Transverse navigation UI infrastructure for zcrud (epic EX-UI). This first P2 piece (EX-UI.5) provides the **missing link** of AD-30 — a **presentation policy derived from the breakpoint** — as **pure** domain types:

- **`ZEditionPresentation`** — the edition mode as an **enum** (`page` / `sheet` / `dialog`). It is the single mode type: it replaces the historical multi-state booleans (`fullscreenDialog`, `dialog`, `isWebOrDesktop`) with a bounded domain (NFR-U7, "enums over booleans").
- **`ZFormWeight`** — a form's weight as an **enum** (`light` / `heavy`), the criterion that splits `expanded → dialog | page`.
- **`ZPresentationPolicy`** — derives, **purely** (no `BuildContext`), a `ZEditionPresentation` from a `ZWindowSizeClass` (provided by `zcrud_responsive`, EX-UI.1). It is **injectable / overridable** (never a frozen constant — AD-30 / AD-6) and **never `sealed`** (AD-4): an app supplies its own rule without editing the package.

This package **depends on `zcrud_core` and `zcrud_responsive`**. It imports **no** state manager (`get` / `flutter_riverpod` / `provider`) and **no** router (`go_router`); the policy itself is **pure Dart** (no `package:flutter` import).

The default policy implements the Material 3 mapping:

| `ZWindowSizeClass` | `ZFormWeight`     | → `ZEditionPresentation` |
|--------------------|-------------------|--------------------------|
| `compact`          | (any)             | `sheet`                  |
| `medium`           | (any)             | `dialog`                 |
| `expanded`         | `light` (default) | `dialog`                 |
| `expanded`         | `heavy`           | `page`                   |

> **Out of scope here (→ EX-UI.6, same package):** the `ZFormPresenter` port and the pure-Flutter `ZAdaptivePresenter` (`Navigator.push` / `showModalBottomSheet` / `showDialog`) that will *execute* the resolved mode, plus the `ZcrudScope` seam wiring.

## Install

```yaml
dependencies:
  zcrud_navigation: ^0.2.0
```

## Minimal example

```dart
import 'package:zcrud_navigation/zcrud_navigation.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

// Pure derivation — no BuildContext needed.
const policy = ZPresentationPolicy();

policy.resolve(ZWindowSizeClass.compact);  // → ZEditionPresentation.sheet
policy.resolve(ZWindowSizeClass.medium);   // → ZEditionPresentation.dialog
policy.resolve(ZWindowSizeClass.expanded); // → ZEditionPresentation.dialog (light default)
policy.resolve(
  ZWindowSizeClass.expanded,
  formWeight: ZFormWeight.heavy,
);                                         // → ZEditionPresentation.page

// Inject a custom rule without subclassing (AD-6).
final custom = ZPresentationPolicy.from(
  (sizeClass, {formWeight = ZFormWeight.light}) => ZEditionPresentation.dialog,
);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
