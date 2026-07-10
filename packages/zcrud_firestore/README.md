# zcrud_firestore

Firestore and Hive adapters for zcrud repositories. Offline-first: a Hive `ZLocalStore` is the source of truth and a Firestore `ZRemoteStore` syncs fire-and-forget. No `cloud_firestore` or `hive` type leaks into the public API — signatures stay neutral (`ZResult<…>` / `Stream<List<T>>`).

Part of the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo — a set of reusable, rich CRUD Flutter packages built on a single declarative `ZFieldSpec` schema.

## Install

```yaml
dependencies:
  zcrud_firestore: ^0.1.0
```

## Minimal example

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// `Note` is your app model: it extends `ZEntity` (from zcrud_core) and provides
// `fromMap`/`toMap`. Inject a FirebaseFirestore instance; the repository exposes
// neutral ports (`ZResult<…>` / `Stream<List<T>>`) — no cloud_firestore type leaks.
final repo = FirebaseZRepositoryImpl<Note>(
  firestore: FirebaseFirestore.instance,
  collectionPath: 'notes',
  kind: 'note', // registry kind for (de)serialization
  fromMap: Note.fromMap,
  toMap: (n) => n.toMap(),
);
```

## Monorepo

This package is developed in the [zcrud](https://github.com/zakarius-dev/zcrud) monorepo. See the repository for the architecture, the other packages and contribution guidelines.

## License

MIT © 2026 Zakarius (zakarius.com). See the [LICENSE](LICENSE) file.
