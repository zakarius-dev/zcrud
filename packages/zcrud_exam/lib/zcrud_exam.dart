/// Barrel d'API publique de `zcrud_exam`.
///
/// Domaine d'un examen daté rattaché à un dossier, avec rappels :
/// - `ZExam` : l'entité (`ZEntity` + `ZExtensible`) — dossier, intitulé,
///   `date` ISO-8601, seuils de rappel `reminderDaysBefore`, et
///   `reminderTime` **typé** (canal hors schéma `'HH:mm'`). Ses méthodes de
///   proximité (`daysUntil` / `isPast` / `isApproaching`) prennent l'horloge
///   `now` en **paramètre** — pures, totales, déterministes, jamais
///   `DateTime.now()` ;
/// - `ZReminderTime` : le value-object d'heure `'HH:mm'` (défensif, total) —
///   le type porte le format, jamais une `String` ambiguë ;
/// - `kReminderTimeKey` : la clé persistée du canal hors schéma
///   `reminder_time`.
///
/// `ZExam` ne déclare **ni `updated_at` ni `is_deleted`** — l'autorité
/// Last-Write-Wins et la suppression logique vivent hors de l'entité
/// (invariant AD-9). La date d'examen (`date`) est une clé métier distincte
/// de toute clé de synchronisation.
///
/// Dépend uniquement de `zcrud_core` (surface pur-Dart `domain.dart`) et de
/// `zcrud_annotations` (invariant AD-1) — aucune dépendance lourde, aucun
/// gestionnaire d'état, aucun `cloud_firestore`, aucun SDK Flutter. Tests
/// exécutés sous `dart test` (et `dart test -p node`, ce paquet étant
/// pur-Dart).
///
/// ## Extension générée masquée
///
/// `ZExamZcrud` porte un `copyWith` **généré** qui ne connaît que les champs
/// annotés : il ignore `extra`, `extension` **et le canal hors schéma
/// `reminderTime`**, et les remet à leurs **défauts** — perte silencieuse. La
/// politique est donc uniforme : aucune extension générée n'est exportée. La
/// (dé)sérialisation et la copie passent par l'API d'instance (`fromMap` /
/// `toMap` / `copyWith` à sentinelle).
///
/// API publique = ce barrel ; implémentation sous `lib/src/domain/`.
library;

export 'src/domain/z_exam.dart' hide ZExamZcrud;
// Le modèle de récurrence hebdomadaire complète le modèle relatif
// (`reminderDaysBefore`) : les deux modèles ne sont pas inter-convertibles,
// donc coexistent plutôt que de se remplacer — voir `ZReminderRecurrence`.
export 'src/domain/z_reminder_recurrence.dart';
export 'src/domain/z_reminder_time.dart';
