# zcrud_session

Runtime de session d'étude Flutter-natif de zcrud — trois moteurs (SRS en
cycle, linéaire, examen blanc) qui font progresser une file de cartes déjà
sélectionnée, avec une seule voie d'écriture SRS (invariant AD-9).

## Aperçu {#apercu}

`zcrud_session` porte le **runtime** de la capacité étude : une fois qu'un
autre paquet a sélectionné et trié un lot de cartes, ce paquet le fait
progresser jusqu'à la fin de session — cycle de répétition espacée,
parcours linéaire (avec ou sans re-boucle des ratés), ou examen blanc à
scoring différé.

Il dépend de `zcrud_core` (contrat `ZResult`/`Either`), `zcrud_flashcard`
(`ZRepetitionInfo`, `ZSrsConfig`) et `zcrud_study_kernel` (`ZReviewMode`).
Il ne dépend d'aucun gestionnaire d'état : les trois moteurs sont des
`ChangeNotifier` purs Flutter (invariant AD-2), et les widgets de
présentation sont des `StatelessWidget`/`StatefulWidget` sans état global.

**Utilisez ce paquet** pour construire l'écran de session d'un module
d'étude — sélecteur de mode, pile swipeable, saisie notée, boutons de
qualité SRS, écran de fin — sans reconstruire vous-même le cycle de
réinsertion des cartes ratées ni la voie d'écriture SRS.

**N'utilisez pas ce paquet** pour sélectionner ou filtrer un lot de cartes
(cela relève de `zcrud_flashcard`, en amont) ni pour calculer un intervalle
de répétition (cela relève du planificateur SM-2 de `zcrud_flashcard`) :
`zcrud_session` consomme ces décisions, il ne les prend jamais.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Un moteur de session SRS minimal, câblé sur un seam d'écriture fourni
/// par l'hôte — ici, un simple récapitulatif de la réponse.
ZStudySessionEngine buildEngine(List<ZSessionItem> queue) {
  return ZStudySessionEngine(
    queue: queue,
    reviewer: ({
      required String flashcardId,
      required String folderId,
      required int quality,
      DateTime? now,
    }) async {
      // En production : `repo.reviewCard(...)`, l'unique voie d'écriture SRS.
      return Right<ZFailure, ZRepetitionInfo>(
        ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
      );
    },
  );
}

/// La rangée de notation, alimentée par l'échelle dérivée de la config SRS.
Widget buildQualityButtons(ZStudySessionEngine engine, ZSrsConfig config) {
  return ZSrsQualityButtons(
    scale: ZQualityScale.fromConfig(config),
    passThreshold: config.passThreshold,
    onQualitySelected: (quality) => engine.grade(quality),
  );
}
```

## Concepts clés {#concepts-cles}

- **Trois runtimes, un régime d'écriture chacun** — `ZStudySessionEngine`
  (cycle SRS, seul détenteur d'un `ZSessionReviewer`), `ZLinearSessionState`
  (parcours list/cramming, aucun seam SRS par construction) et
  `ZWhiteExamSessionEngine` (machine à états setup/running/submitted, aucun
  seam SRS). `zSessionRuntimeForMode` désigne le runtime légitime pour
  chaque `ZReviewMode`, sans jamais en instancier un nouveau.
- **Voie d'écriture SRS unique (invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9))** —
  seul `ZStudySessionEngine` peut écrire de la répétition espacée, via le
  seam `ZSessionReviewer` injecté (= `reviewCard` en production). Les deux
  autres runtimes ne détiennent structurellement aucun seam d'écriture :
  l'absence d'écriture est une propriété du type, pas un comportement
  observé.
- **Réactivité granulaire (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  la surface de saisie (`ZFlashcardAnswerInput`) isole son `TextEditingController`
  et son minuteur dans des tranches indépendantes : taper une réponse ne
  reconstruit ni la carte, ni le formulaire de notation.
- **Correction advisory, notation par le tap** — la saisie n'écrit jamais
  elle-même : elle émet un `ZFlashcardSubmission` (fait, pas décision) via
  `onSubmitted`, et pré-sélectionne un cran de qualité dans
  `ZSrsQualityButtons` sans jamais le confirmer à sa place. Seul le tap de
  l'utilisateur sur un bouton de qualité vaut notation.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZStudySessionEngine` | Moteur de session SRS en cycle : fait progresser la file par `grade`, réinsère une carte ratée à un offset déterministe (+2/+4), écrit via le seam `ZSessionReviewer` injecté. |
| `ZLinearSessionState` | Runtime linéaire (`list`/`cramming`) : parcours strict ou avec re-boucle des ratés, zéro écriture SRS par construction. |
| `ZWhiteExamSessionEngine` / `ZWhiteExamSessionController` | Machine à états d'examen blanc (`setup`/`running`/`submitted`) à scoring différé ; le contrôleur en est l'adaptateur de présentation. |
| `ZSessionState` / `ZSessionItem` | État immuable de la file de session (compteurs `reviewed`/`lapses`/`remaining`) et identité neutre d'une carte. |
| `ZSessionReviewer` | Seam d'écriture SRS injecté au moteur — signature identique à `ZFlashcardRepository.reviewCard`. |
| `ZFlashcardAnswerInput` | Surface de saisie notée (QCM, Vrai/Faux, rédigée) — évaluation locale ou via un port advisory, indices plafonnés, minuteur, sans tap-to-reveal. |
| `ZSrsQualityButtons` / `ZQualityScale` | Rangée de boutons de notation SM-2, échelle dérivée de `ZSrsConfig`. |
| `ZSessionCardSwiper` | Pile de session swipeable — navigation seule, aucun paramètre de notation. |
| `ZListSessionView` | UI d'examen blanc en liste, pilotée en données par la `phase` et les `cards` de l'hôte. |
| `ZSessionModeSelector` | Sélecteur de session (apprendre, réviser, tester, bachotage) — produit une file, ne démarre aucun runtime. |
| `ZSessionSummaryView` | Écran de fin de session — assemble `ZSessionQualityBreakdown` et `ZStudyProgressRings`, célébration opt-in. |
| `ZSessionProgressIndicator` / `ZSessionQualityBreakdown` / `ZStudyProgressRings` | Indicateurs de progression et de répartition des qualités, présentation pure. |
| `ZStreakBadge` / `zShowStreakToast` | Badge et confirmation de la série d'assiduité, via le port `ZToaster`. |
| `ZTestFiltersDialog` | Dialog de composition des filtres d'un test (nombre de questions, seaux de maîtrise, sources). |
| `ZCorrectionVisibility` / `ZCardAdvanceBehavior` / `ZTimerDisplay` | Enums de comportement de rendu : apparition de la correction, avance automatique, affichage du minuteur. |

## Cas limites et invariants {#cas-limites}

- **Une file vide ne plante jamais** — chaque widget de ce paquet rend un
  repli l10n localisé sur une file vide plutôt que de construire un sous-arbre
  invalide (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10)).
- **Une commande hors bornes est ramenée dans les bornes, pas ignorée** —
  un index de carte négatif ou au-delà de la file, une clé de soumission
  périmée, un seuil de qualité négatif : tous sont clampés ou filtrés
  défensivement, jamais laissés provoquer une exception.
- **Le swipe ne note jamais** — `ZSessionCardSwiper` n'a structurellement
  aucun paramètre de qualité ; les deux directions de swipe font toutes deux
  avancer la pile, jamais l'une « réussite » et l'autre « lapse ».
  L'examen blanc en liste (`ZListSessionView`) est lui aussi structurellement
  incapable d'écrire du SRS : son constructeur n'accepte aucun `reviewer`.
- **Une réponse répondue est verrouillée, définitivement** — aucun des
  trois runtimes ne sait réviser une réponse déjà donnée ; sauter une
  question la laisse sans réponse, mais rien ne permet de revenir dessus.
- **Reduce Motion dégrade l'animation, jamais la fonction** — les
  indicateurs de swipe et la célébration de fin de session basculent en
  apparition binaire sans interpolation, mais restent fonctionnellement
  complets.
- **RTL et thème injectés** — variantes directionnelles uniquement
  (`EdgeInsetsDirectional`, `AlignmentDirectional`), couleurs résolues par
  clé via `ZColorKeyResolver`, jamais de `Colors.*` en dur (invariant
  [AD-13](../../docs/site/concepts/invariants.md#ad-13)).

## Voir aussi {#voir-aussi}

- [`zcrud_flashcard`](../zcrud_flashcard/README.md) — modèle de carte,
  planificateur SM-2, sélection et filtrage en amont de ce runtime.
- [`zcrud_study_kernel`](../zcrud_study_kernel/README.md) — `ZReviewMode` et
  les types canoniques partagés par les paquets d'étude.
- Fiche [`docs/site/paquets/zcrud_session.md`](../../docs/site/paquets/zcrud_session.md).
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Offline-first](../../docs/site/concepts/offline-first.md) — AD-9 en pratique.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
