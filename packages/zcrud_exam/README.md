# zcrud_exam

Domaine d'un examen daté rattaché à un dossier, avec rappels — pur-Dart, sans
horloge implicite (invariant AD-9 sur la synchronisation, AD-10 sur la
désérialisation défensive).

## Aperçu {#apercu}

`zcrud_exam` fournit l'entité canonique `ZExam` — un examen avec une date, des
seuils de rappel en jours, une récurrence hebdomadaire optionnelle et une
heure de rappel typée — et le value-object `ZReminderTime`. C'est un paquet
**pur-Dart** : aucune dépendance Flutter, aucun gestionnaire d'état, aucun
SDK Firebase. Il ne dépend que de `zcrud_core` (surface pur-Dart
`domain.dart`) et de `zcrud_annotations`.

Toute la logique de proximité d'un examen (`daysUntil`, `isPast`,
`isApproaching`) est **pure et déterministe** : l'horloge courante est un
paramètre explicite, jamais un `DateTime.now()` implicite — deux appels avec
la même horloge rendent toujours le même résultat.

**Utilisez ce paquet** pour représenter un examen daté avec ses rappels dans
un domaine d'étude — modèle, persistance, calcul de proximité — sans
réimplémenter la logique de seuils ou de récurrence. **N'utilisez pas ce
paquet** pour de la planification générale hors du domaine d'étude : `ZExam`
est spécifiquement une échéance rattachée à un dossier, pas un événement de
calendrier générique.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_exam/zcrud_exam.dart';

void main() {
  // Un examen dans 5 jours, avec un rappel à J-7 et J-1.
  final exam = ZExam(
    folderId: 'droit-douanier',
    title: 'Partiel de droit douanier',
    date: DateTime(2026, 8, 18),
    reminderEnabled: true,
    reminderDaysBefore: const [7, 1],
    reminderTime: const ZReminderTime(hour: 8, minute: 30),
  );

  // L'horloge est un paramètre : le calcul est déterministe et testable.
  final now = DateTime(2026, 8, 12);
  print(exam.daysUntil(now)); // 6
  print(exam.isApproaching(now)); // true (dans la fenêtre du seuil 7)

  // Round-trip sans perte vers la forme persistée.
  final map = exam.toMap();
  final reloaded = ZExam.fromMap(map);
  assert(reloaded == exam);
}
```

## Concepts clés {#concepts-cles}

- **Horloge injectée** — `daysUntil`, `isPast` et `isApproaching` prennent
  toutes `now` en paramètre. Aucune méthode de ce paquet n'appelle
  `DateTime.now()` en interne : un appelant contrôle entièrement le temps de
  référence, ce qui rend ces calculs reproductibles en test.
- **Deux modèles de récurrence, jamais fusionnés** — `ZReminderRecurrence`
  exprime soit des seuils relatifs (« N jours avant »), soit des jours de
  semaine absolus, soit les deux combinés en logique **ou**. Quand
  `reminderRecurrence` est renseigné, il fait seul autorité sur
  `reminderDaysBefore` dans le calcul de proximité — les deux sources ne
  s'additionnent jamais.
- **`reminderTime` est typé** — `ZReminderTime` porte le format `'HH:mm'`
  dans son type plutôt que de laisser circuler une chaîne ambiguë ; son
  analyse (`ZReminderTime.parse`) ne lève jamais, une entrée invalide rend
  `null`.
- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  `ZExam.fromMap` ne lève jamais, y compris sur une map vide ou une date
  illisible ; chaque champ retombe sur un défaut sûr.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZExam` | Entité canonique — dossier, intitulé, date, rappels, calcul de proximité. |
| `ZReminderRecurrence` | Récurrence de rappel combinant seuils relatifs et jours de semaine absolus. |
| `ZReminderTime` | Value-object d'heure `'HH:mm'`, défensif et total. |
| `ZExamExtensionParser` | Signature du décodeur d'extension fourni par l'application appelante. |
| `kReminderTimeKey` | Clé persistée du canal hors schéma `reminder_time`. |

## Cas limites et invariants {#cas-limites}

- **Aucun horodatage de synchronisation inline** — `ZExam` ne déclare ni
  `updatedAt` ni `isDeleted` : l'autorité Last-Write-Wins et la suppression
  logique vivent hors de l'entité, conformément à l'invariant
  [AD-9](../../docs/site/concepts/invariants.md#ad-9). La date d'examen
  (`date`) est une clé métier, distincte de toute clé de synchronisation.
- **Récurrence corrompue ⇒ emplacement absent, jamais une exception** — une
  valeur de récurrence illisible dans la map persistée rend `null` plutôt que
  de faire échouer tout l'examen ; les valeurs valides d'une même map
  survivent à côté des valeurs corrompues.
- **`isApproaching` sans échéance** — la famille hebdomadaire d'une
  récurrence reste évaluable même quand `date` est `null` ; la famille
  relative, elle, reste inévaluable sans échéance.
- **`ZExamZcrud`, l'extension générée par le codegen, n'est pas exportée** —
  son `copyWith` ignore `extra`, `extension` et le canal `reminderTime` et
  les remet à leurs défauts. Utilisez toujours `ZExam.copyWith`, jamais
  l'extension générée.

## Voir aussi {#voir-aussi}

- [Fiche du paquet](../../docs/site/paquets/zcrud_exam.md) — rôle, quand
  l'utiliser.
- [`zcrud_flashcard`](../zcrud_flashcard/README.md) — domaine voisin de
  répétition espacée, même patron de séparation entre entité et état dérivé.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
