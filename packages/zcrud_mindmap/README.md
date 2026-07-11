# zcrud_mindmap

Mind maps for zcrud: an immutable `ZMindmap`/`ZMindmapNode` tree with pure `ZMindmapTreeOps` (add/update/delete/find + move/indent/outdent/reorder), a `graphite` auto-layout view with an accessible list surface, and an outline editor.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_mindmap: ^0.1.0
```

## Minimal example

```dart
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

// Build a forest (mutation goes exclusively through ZMindmapTreeOps).
var forest = <ZMindmapNode>[ZMindmapTreeOps.newRootNode()];
forest = ZMindmapTreeOps.updateNode(forest, forest.first.id, label: 'Root');

// Render: graphite auto-layout + an accessible list surface.
final view = ZMindmapView(roots: forest);
```

The domain layer (`ZMindmap`/`ZMindmapNode`/`ZMindmapTreeOps`) is pure Dart and imports the Flutter-free `package:zcrud_core/domain.dart` entrypoint; the `graphite` map SDK is confined to the view.

## License

MIT © 2026 Zakarius ([zakarius.com](https://zakarius.com)).
