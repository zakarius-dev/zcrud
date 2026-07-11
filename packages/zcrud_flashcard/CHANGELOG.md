# Changelog

All notable changes to `zcrud_flashcard` are documented in this file.

## 0.1.0

Initial release.

- `ZFlashcard`/`ZChoice`/`ZFlashcardType` models (6 card types) with open provenance via `ZSourceRegistry`, SRS state kept off the card.
- Pluggable spaced-repetition scheduling: `ZRepetitionInfo` + `ZSrsScheduler` (SuperMemo-2 default), single write path `reviewCard() → apply`.
- Study folders and sessions: `ZStudyFolder` (2-level hierarchy), `ZStudySession` filters, pure session selector.
- Offline-first `ZFlashcardRepository` built on neutral core ports (no Firebase edge), top-level SRS invariant.
- Additive edition widgets served through `ZWidgetRegistry` (does not replace the host app's study module).
- Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo (14 packages, one declarative CRUD engine).
- Published under the MIT license.
