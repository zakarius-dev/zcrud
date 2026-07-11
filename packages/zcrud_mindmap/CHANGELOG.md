# Changelog

All notable changes to `zcrud_mindmap` are documented in this file.

## 0.1.0

Initial release.

- Immutable `ZMindmap`/`ZMindmapNode` tree model (nesting + denormalized `level`) with pure `ZMindmapTreeOps` (add/update/delete/find + move/indent/outdent/reorder with level recomputation, anti-cycle, structural sharing).
- `ZMindmapView`: `graphite` auto-layout (bounded zoom/pan) plus an accessible indented list surface, with an injectable node content builder.
- Outline editor whose save actually applies edits (Flutter-native reactivity, targeted rebuilds).
- Sync metadata kept off the entity (`ZSyncMeta`); defensive deserialization (AD-10).
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
