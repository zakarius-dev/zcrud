# zcrud_flashcard

Flashcards en répétition espacée pour zcrud — modèle canonique, planificateur
SRS remplaçable et état de répétition **séparé de la carte** (invariant AD-9).

## Aperçu {#apercu}

`zcrud_flashcard` fournit l'entité canonique `ZFlashcard` (six types de carte,
provenance ouverte via `ZFlashcardSource`), le planificateur de répétition
espacée `ZSrsScheduler` (implémentation par défaut `ZSm2Scheduler`,
SuperMemo-2) et un dépôt offline-first `ZFlashcardRepository` qui compose les
ports neutres de `zcrud_core`. L'organisation en dossiers d'étude et la
sélection de session (`ZStudyFolder`, `ZStudySessionConfig`,
`ZStudySessionSelector`) sont portées par `zcrud_study_kernel` et réexportées
telles quelles.

Le paquet ajoute une couche `presentation/` : des widgets d'édition additifs
servis par le registre de widgets du cœur (sélecteur de type, éditeur QCM,
éditeur vrai/faux) et `ZFlashcardReviewCard`, une carte de révision Flutter
qui affiche les six types canoniques et bascule question/réponse par tap.
Aucun de ces widgets n'importe Syncfusion, Firebase ou un gestionnaire d'état
(invariants AD-1/AD-15).

**Utilisez ce paquet** pour modéliser des flashcards, planifier leur révision
et les éditer/afficher dans une application Flutter — sans réimplémenter
l'algorithme SM-2 ni la séparation entre carte et état SRS. **N'utilisez pas
ce paquet** pour orchestrer une session de révision complète (minuteur,
notation, enchaînement de cartes, port d'évaluation) : cette couche vit dans
`zcrud_session`, en aval.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  // Une carte question/réponse simple.
  const card = ZFlashcard(
    question: 'Capitale de la France ?',
    answer: 'Paris',
  );

  // L'état SRS est un objet séparé — jamais un champ de la carte.
  final scheduler = const ZSm2Scheduler();
  final now = DateTime(2026, 8, 11);
  final fresh = scheduler.initial('carte-1');

  // Voie d'écriture unique : reviewCard() délègue à scheduler.apply.
  final advanced = scheduler.apply(fresh, 5, now: now);
  print(advanced.nextReviewDate); // échéance recalculée
}
```

## Concepts clés {#concepts-cles}

- **État SRS séparé de la carte (invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9))** —
  `ZFlashcard` ne porte aucun champ de répétition espacée ; `ZRepetitionInfo`
  vit dans un canal persisté distinct (`ZRepetitionStore`), adressé par
  identifiant de carte. Dupliquer ou partager une carte n'emporte donc jamais
  son historique de révision.
- **Voie d'écriture SRS unique** — `ZSrsScheduler.apply` (état avancé) et
  `ZSrsScheduler.initial` (état neuf) sont les deux seules opérations qui
  produisent un `ZRepetitionInfo`. Côté dépôt, `ZFlashcardRepository.reviewCard`
  et `initRepetition` sont les seuls points d'entrée publics correspondants —
  aucune autre API n'écrit d'état de répétition.
- **Planificateur remplaçable** — `ZSrsScheduler` est une interface : `ZSm2Scheduler`
  (SuperMemo-2, défaut) est pur, sans état, paramétré par un `ZSrsConfig`
  injectable et prend l'horloge courante en paramètre explicite, jamais
  capturée à la construction.
- **Rendu additif, contenu par slot** — `ZFlashcardReviewCard` rend les six
  types de carte et bascule la révélation par tap ; tout contenu textuel
  (question, réponse, choix, explication) passe par un slot injectable
  (`ZFlashcardContentBuilder`), dont le défaut est un texte brut thématisé.
  Un rendu enrichi (Markdown/LaTeX) se branche via `ZFlashcardMarkdownContent`
  sans jamais construire de widget de rendu riche si l'application n'injecte
  rien.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZFlashcard` | Entité canonique — contenu, type, choix, provenance ; jamais l'état SRS. |
| `ZChoice` | Un choix de question à choix multiples (libellé + caractère correct). |
| `ZFlashcardType` | Les six types canoniques de carte. |
| `ZRepetitionInfo` | État de répétition espacée — persisté séparément de la carte. |
| `ZSrsScheduler` / `ZSm2Scheduler` | Contrat de planification SRS et son implémentation SuperMemo-2. |
| `ZSrsConfig` | Constantes SRS injectables (bornes de facteur de facilité, seuil de réussite…). |
| `ZFlashcardRepository` | Dépôt offline-first : compose les ports neutres, expose `reviewCard`/`initRepetition`. |
| `ZRepetitionStore` | Port de persistance de l'état SRS — abstrait, toujours injecté. |
| `ZFlashcardReviewCard` | Carte de révision Flutter : rendu par type + bascule question/réponse. |
| `ZFlashcardContentBuilder` | Slot injectable de rendu de contenu de carte. |
| `ZFlashcardMarkdownContent` | Rendu rich-text opt-in (Markdown/LaTeX) du contenu d'une carte. |

## Cas limites et invariants {#cas-limites}

- **Désérialisation défensive (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  un `ZChoice` corrompu dans la liste `choices` est ignoré individuellement,
  jamais un échec de toute la carte ; un type de carte inconnu retombe sur
  `ZFlashcardType.openQuestion`.
- **`ZFlashcardZcrud`/`ZRepetitionInfoZcrud`, les extensions générées par le
  codegen, ne sont pas exportées** — leur `copyWith` ignore `extra`,
  `extension` et les canaux hors schéma et les remet à leurs défauts.
  Utilisez toujours `ZFlashcard.copyWith`/`ZRepetitionInfo.fromMap`, jamais
  l'extension générée.
- **Une instance de `ZRepetitionStore` = un propriétaire** — le port ne
  sépare le SRS que du corps de la carte, pas entre utilisateurs. Plusieurs
  utilisateurs révisant une même carte partagée doivent être adressés par des
  chemins de persistance distincts côté adaptateur ; sinon leurs progressions
  s'écrasent silencieusement.
- **Actions structurellement absentes, jamais grisées** — `ZFlashcardReviewCard`
  retire une action d'édition/suppression de l'arbre quand `isReadOnly` est
  vrai ou que le callback correspondant est absent. L'action « voir la
  source » suit une règle distincte : elle survit à la lecture seule, car
  consulter une provenance ne mute rien.
- **Reduce Motion prime toujours (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  quel que soit `ZRevealTransition`, la révélation reste instantanée quand
  l'accessibilité « réduire les animations » est active ; seule l'animation
  est dégradée, jamais la fonction.

## Voir aussi {#voir-aussi}

- [Fiche du paquet](../../docs/site/paquets/zcrud_flashcard.md) — rôle, quand
  l'utiliser.
- [`zcrud_exam`](../zcrud_exam/README.md) — domaine voisin d'échéance
  d'étude, même patron de séparation entre entité et état dérivé.
- `zcrud_session` — orchestration de session de révision (minuteur, notation,
  port d'évaluation), en aval de ce paquet.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) —
  définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
