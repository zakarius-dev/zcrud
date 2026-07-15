/// Barrel d'API publique de `zcrud_exam` (ES-2.6, **FR-S9**).
///
/// Examen daté rattaché à un dossier avec rappels :
/// - `ZExam` : l'entité (`ZEntity` + `ZExtensible`) — dossier, intitulé, `date`
///   ISO-8601, seuils de rappel `reminderDaysBefore`, et `reminderTime` **TYPÉ**
///   (canal hors-codegen `'HH:mm'`). Ses méthodes de proximité (`daysUntil` /
///   `isPast` / `isApproaching`) prennent l'horloge `now` en **PARAMÈTRE** —
///   pures, totales, déterministes, **jamais** `DateTime.now()` (D5, prouvé par
///   machine : `no_datetime_now_test.dart`) ;
/// - `ZReminderTime` : le value-object d'heure `'HH:mm'` (défensif, TOTAL) — le
///   TYPE dit le format, jamais une `String` ambiguë (AD-28) ;
/// - `kReminderTimeKey` : la clé persistée du canal hors-codegen `reminder_time`.
///
/// **AD-19** : `ZExam` ne déclare **NI `updated_at` NI `is_deleted`** — l'autorité
/// Last-Write-Wins et le soft-delete vivent **hors-entité** (`ZSyncMeta`). La date
/// d'examen (`date`) est une clé MÉTIER DISTINCTE de toute clé de sync.
///
/// Dépend **UNIQUEMENT** de `zcrud_core` (surface **pur-Dart** `domain.dart`) et
/// `zcrud_annotations` (AD-1/AD-17) — **zéro** dép lourde, **zéro** gestionnaire
/// d'état, **zéro** `cloud_firestore`, **zéro** SDK Flutter (NFR-S3/SM-S5/NFR-S10).
/// Tests sous **`dart test`** (et `dart test -p node` — `gate:web` default-ON).
///
/// ## 🔴 Extension générée masquée (`hide`) — règle **(h)**, tenue par machine
///
/// `ZExamZcrud` porte un `copyWith` **GÉNÉRÉ** qui ne connaît que les champs
/// `@ZcrudField` : il IGNORE `extra`, `extension` **et le canal hors-codegen
/// `reminderTime`**, et les remet à leurs **DÉFAUTS** ⇒ destruction silencieuse.
/// ⇒ **Politique UNIFORME : aucune extension générée n'est exportée** (finding H3
/// d'ES-2.1). La (dé)sérialisation et la copie passent par l'API d'instance
/// (`fromMap` / `toMap` / `copyWith` à sentinelle). Tenu par
/// `scripts/ci/gate_reserved_keys.dart` (règle (h)).
///
/// API publique = ce barrel ; implémentation sous `lib/src/domain/`.
library;

export 'src/domain/z_exam.dart' hide ZExamZcrud;
export 'src/domain/z_reminder_time.dart';
