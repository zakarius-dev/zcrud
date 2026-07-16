# zcrud_responsive

Transverse responsive UI infrastructure for zcrud (epic EX-UI). It provides two **pure** measurement primitives that the rest of the responsive layer (layout, adaptive grid, presentation policy) builds on:

- **`ZWindowSizeClass`** — a Material 3 window size class as an **enum** (`compact` / `medium` / `expanded`, thresholds **600 / 840**). It is the single screen-class type: there is no `bool isMobile/isTablet/isDesktop`. Resolution is pure (`fromWidth`, testable without a `BuildContext`) with a safe default (`compact`, never throws), plus a context helper `of(context)` reading the width via `MediaQuery.sizeOf` (never `Get.width`).
- **`ZBreakpointValue<T>`** — a generic breakpoint-scoped value with mobile-first cascade, built **on** the `ZBreakpoint` enum (5 Bootstrap breakpoints) that **`zcrud_core` already owns**. `resolve(width)` delegates to `zcrud_core`'s `ZResponsiveBreakpoints.of`, so no threshold is duplicated.

This package **depends on `zcrud_core`** and **reuses** its responsive primitives (`ZBreakpoint`, `ZResponsiveBreakpoints`, `ZResponsiveSpan`) — it never redeclares them (they are re-exported here for convenience only). It imports **no** state manager, router or third-party responsive library.

The two scales coexist on purpose: the Material 3 window class (600/840, 3 tiers) classifies the window for a presentation choice; the Bootstrap breakpoints (576/768/992/1200, 5 tiers) carry a per-tier authoring value. Neither replaces the other.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_responsive: ^0.2.0
```

## Minimal example

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';

// Pure resolution — no BuildContext needed.
final cls = ZWindowSizeClass.fromWidth(700); // → ZWindowSizeClass.medium

// Context helper (reads MediaQuery.sizeOf).
Widget build(BuildContext context) {
  final windowClass = ZWindowSizeClass.of(context);
  return Text('$windowClass');
}

// A per-breakpoint value with mobile-first cascade (ZBreakpoint from zcrud_core).
const padding = ZBreakpointValue<double>(xs: 8, md: 16, xl: 24);
final p = padding.resolve(1000); // width → ZBreakpoint.lg → inherits md → 16.0
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
