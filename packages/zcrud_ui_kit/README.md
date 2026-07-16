# zcrud_ui_kit

Transverse UI kit for zcrud (epic EX-UI). It factors out the generic content-state and confirmation patterns that the apps (dodlp, iffd, …) used to reimplement by hand:

- **`ZContentState`** — the state of an async content as an **enum** (`idle` / `loading` / `empty` / `error` / `success`). It replaces the `isLoading` / `hasError` / `isEmpty` boolean combinations: a sealed enum makes the state space explicit and exhaustive (an exhaustive `switch` without `default` catches any missing tier at compile time).
- **`ZEmptyState` / `ZLoadingState` / `ZErrorState`** — `const` state widgets. Colors are **derived** from the current `ColorScheme` (never a hard-coded hex); texts are supplied by the caller (injected l10n); each carries explicit `Semantics`, touch targets ≥ 48 dp and a directional (RTL-safe) layout. The icon/color is never the only information channel (text is always present).
- **`ZContentStateView`** — a router that maps a `ZContentState` to the right widget via an exhaustive `switch`, with safe fallbacks (`ZLoadingState` for `loading`, `SizedBox.shrink()` for the other empty slots — never throws).
- **`ZConfirmTone`** — the confirmation tone as an **enum** (`neutral` / `destructive`), replacing a `bool isDestructive`.
- **`ZConfirmDialog` + `showZConfirmDialog(...)`** — a dark-mode-aware confirmation dialog (colors derived from the current `ColorScheme`, default labels from `MaterialLocalizations`) returning a `Future<bool>`, built with **no** state manager (`showDialog` + `Navigator.pop` only).

This package **depends on `zcrud_core`** and **consumes** its seams (`ZcrudScope`, `ZcrudTheme`, `ZcrudLocalizations`) in read-only mode, always falling back to `Theme.of(context)` / `MaterialLocalizations.of(context)` when no scope is mounted. It re-declares none of them and imports **no** state manager, router or third-party UI library.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_ui_kit: ^0.2.0
```

## Minimal example

```dart
import 'package:flutter/material.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

// Route a content state to the right widget (exhaustive, safe fallbacks).
Widget build(BuildContext context) {
  return ZContentStateView(
    state: myState, // ZContentState
    loading: const ZLoadingState(),
    empty: ZEmptyState(
      icon: Icons.inbox_outlined,
      message: 'No items yet', // your l10n string
    ),
    error: ZErrorState(
      message: 'Something went wrong', // your l10n string
      retryLabel: 'Retry',
      onRetry: reload,
    ),
    successBuilder: (context) => MyList(items),
  );
}

// Ask for confirmation (dark-mode-aware, no state manager). Returns true/false.
Future<void> onDelete(BuildContext context) async {
  final ok = await showZConfirmDialog(
    context,
    title: 'Delete item?',
    message: 'This action cannot be undone.',
    tone: ZConfirmTone.destructive, // confirm button tinted ColorScheme.error
  );
  if (ok) doDelete();
}
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
