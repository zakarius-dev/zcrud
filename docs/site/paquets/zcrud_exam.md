---
title: zcrud_exam
description: Domaine des examens datés — rappels, calcul de proximité par horloge injectée.
---

# zcrud_exam

## Rôle

`zcrud_exam` fournit l'entité canonique `ZExam` — un examen rattaché à un
dossier, avec une date, des seuils de rappel en jours, une récurrence
hebdomadaire optionnelle et une heure de rappel typée (`ZReminderTime`).
C'est un paquet **pur-Dart** : aucune dépendance Flutter, aucun gestionnaire
d'état, aucun SDK Firebase. Toute sa logique de proximité (`daysUntil`,
`isPast`, `isApproaching`) est pure et déterministe — l'horloge courante est
un paramètre explicite, jamais un `DateTime.now()` implicite.

## Quand l'utiliser

- Pour modéliser une échéance d'examen datée, rattachée à un dossier
  d'étude, avec ses seuils de rappel.
- Pour calculer la proximité d'une échéance (« ce rappel est-il dû
  aujourd'hui ? ») de façon testable, sans dépendre de l'horloge système.
- Pour combiner un modèle de rappel relatif (« N jours avant ») et un modèle
  hebdomadaire (« ces jours de la semaine ») sur la même échéance.

## Quand ne pas l'utiliser

- Pour de la planification générale hors du domaine d'étude : `ZExam` est
  spécifiquement une échéance rattachée à un dossier, pas un événement de
  calendrier générique.
- Pour représenter l'état de répétition espacée d'une flashcard : voir
  [`zcrud_flashcard`](./zcrud_flashcard.md), dont l'état SRS est un domaine
  séparé.

## Types clés

| Type | Rôle |
|---|---|
| `ZExam` | Entité canonique — dossier, intitulé, date, rappels, calcul de proximité. |
| `ZReminderRecurrence` | Récurrence de rappel combinant seuils relatifs et jours de semaine absolus. |
| `ZReminderTime` | Value-object d'heure `'HH:mm'`, défensif et total. |
| `ZExamExtensionParser` | Signature du décodeur d'extension fourni par l'application appelante. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_exam/README.md) — installation,
  démarrage rapide, API complète.
- [`zcrud_flashcard`](./zcrud_flashcard.md) — domaine voisin de répétition
  espacée.
- [Invariants d'architecture](../concepts/invariants.md) — définitions
  canoniques AD-1 à AD-16.
