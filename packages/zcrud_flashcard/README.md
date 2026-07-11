# zcrud_flashcard

Spaced-repetition flashcards for zcrud: `ZFlashcard`/`ZChoice` models (6 card types), a pluggable `ZSrsScheduler` (SuperMemo-2 by default) with SRS state kept off the card, study folders/sessions, and an offline-first `ZFlashcardRepository` built on neutral core ports.

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_flashcard: ^0.1.0
```

## Minimal example

```dart
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

// A card (SRS state lives in a separate ZRepetitionInfo, never on the card).
const card = ZFlashcard(
  question: 'Capital of France?',
  answer: 'Paris',
);

// Advance the SRS state — the only write path is reviewCard() → scheduler.apply.
final scheduler = const ZSm2Scheduler();
final next = scheduler.apply(scheduler.initial(card.id ?? ''), 5);
```

The offline-first repository composes neutral `zcrud_core` ports (a `ZSyncableRepository<ZFlashcard>` + a flashcard-local `ZRepetitionStore`), so this package never depends on a backend SDK (Firebase/Hive live in `zcrud_firestore`).

## License

MIT © 2026 Zakarius ([zakarius.com](https://zakarius.com)).
