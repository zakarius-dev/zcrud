---
title: 'CR Lex 102 et 103 — apprentissage et ensemble visible'
type: feature
created: '2026-09-19'
status: done
baseline_commit: 2b7c34e4a
review_loop_iteration: 0
context: []
---

<frozen-after-approval reason="Périmètre demandé par l’utilisateur : traiter les CR, écrire le handoff et publier le nouveau tag">

## Intent

**Problem:** Lex réimplémente le cycle d’apprentissage faute de retour typé, de confirmation portant le palier et de file cyclique configurable. Sa recherche interne de flashcards ne communique pas les cartes visibles à l’hôte, ce qui désynchronise compteur et session.

**Approach:** Livrer les deux CR dans v3.55.0, par API additive. Réutiliser les points de progression et aperçus SRS existants. Fournir les tests, la revue et un handoff avec montage hôte et limites vérifiées.

## Boundaries & Constraints

**Always:** Architecture hexagonale, écriture SRS unique par reviewer, libellés et thème injectables, réactivité granulaire, compatibilité des montages existants. Préserver les deux lockfiles préexistants. Publication Git autorisée explicitement par l’utilisateur.

**Ask First:** Changement métier hors CR ou rupture d’API incontournable.

**Never:** Réécrire les applications hôtes, publier sur pub.dev, inclure des changements étrangers ou déclarer verts des contrôles non exécutés.

## I/O & Edge-Case Matrix

| Scénario | Entrée | Comportement attendu | Erreur |
|---|---|---|---|
| File historique | Politique absente | Retrait au seuil SRS et offsets historiques conservés | Comportement actuel |
| Apprentissage | q1/q2/q3/q4/q5 | Réinsertion +3/+5, rotation des q3/q4, retrait q5 | Qualité valide selon contrat actuel |
| Confirmation | Retour avec qualité puis clic suivant | Palier transmis une seule fois, aucune avance automatique | Double clic neutralisé |
| Recherche | Frappe puis debounce | Snapshot de la même liste ordonnée que le rendu | Résultat vide publié |
| Cycle widget | Nouveau parent, callback ou démontage | Pas de boucle de rebuild ni notification obsolète | Callback absent : inertie |

</frozen-after-approval>

## Code Map

- `packages/zcrud_session/lib/src/domain/z_study_session_engine.dart` : moteur et reducer de file.
- `packages/zcrud_session/lib/src/presentation/z_flashcard_answer_input.dart` : soumission, feedback et avance.
- `packages/zcrud_session/lib/src/presentation/z_srs_quality_buttons.dart` : boutons et aperçus.
- `packages/zcrud_study/lib/src/presentation/z_study_session_host.dart` : orchestration réelle de la session.
- `packages/zcrud_study/lib/src/presentation/z_study_session_scaffold.dart` : API de page.
- `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart` : calcul exact des cartes visibles.

## Tasks & Acceptance

**Execution:**
- [x] `packages/zcrud_session/lib/` : ajouter retour typé, confirmation avec palier et politique injectable ; conserver les anciens défauts.
- [x] `packages/zcrud_study/lib/src/presentation/z_study_session_host.dart` et scaffold : câbler les capacités d’apprentissage, réutiliser progression et aperçu, compléter les surfaces manquantes.
- [x] `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart` : snapshot immuable requête/tri/cartes, callback additif publié hors build et dédupliqué.
- [x] `packages/zcrud_session/test/` et `packages/zcrud_study/test/` : prouver scénarios métier, inertie, cycle de vie et câblage.
- [x] `docs/handoff-v3.55.0.md`, recette et versions : documenter migration, contrôles et publication après revue.

**Acceptance Criteria:**
- Given une session historique, when aucun nouveau paramètre n’est fourni, then les tests existants et le comportement restent valides.
- Given une session d’apprentissage montée depuis le scaffold, when une réponse est confirmée, then le palier visible atteint le reviewer une fois et la politique pilote la file.
- Given un retour typé, when il est affiché, then titre, message et explication sont accessibles et personnalisables par l’hôte.
- Given une liste filtrée et triée, when son résultat change, then l’hôte reçoit exactement les cartes rendues après debounce, sans second prédicat.
- Given un callback qui reconstruit son parent, when un snapshot est publié, then la notification ne provoque ni erreur pendant build ni boucle infinie.

## Spec Change Log

- Revue : préciser l’activation apprentissage uniquement SRS, la politique modifiable sans reset, la correction différée compatible avec confirmation, et les gardes de cycle asynchrone. Préserver les anciens défauts et la voie unique du reviewer. Corrections vérifiées par tests ciblés, sans changement de l’intention figée.
- Audit documentaire : distinguer réactivation d’un callback (null → callback) et recréation d’une closure non nulle ; conserver la déduplication anti-boucle.
- Garde globale : le contrat préexistant de `ZStudySessionWiring` exige de nommer tout nouveau seam. `learning` devient donc requis dans ce seul constructeur strict, relayé à l’audit `ZStudySeam`. L’adaptation `learning: null` est annoncée dans le handoff et le changelog ; les constructeurs usuels gardent leur compatibilité. Les gardes exhaustives et leurs sondes d’effet sont conservées.

## Design Notes

Conserver `onAdvance: VoidCallback` et ajouter une voie typée évite une rupture. Une politique de file ne change pas le calcul SM-2 : le reviewer garde la responsabilité de la persistance. Le snapshot est une copie non modifiable et sa publication suit le rendu effectif. Passer de null à un callback republie le dernier état ; remplacer une closure non nulle ne déclenche pas de notification à résultat identique, pour éviter une boucle lorsque le parent reconstruit. Le dernier snapshot peut être transmis directement à un nouveau destinataire.

## Verification

- Analyse et suites complètes des packages session/study.
- `dart run melos run generate`, `dart run melos run analyze`, `dart run melos run test`, `dart run melos run verify` : consigner codes retour et éventuels blocages avec preuves.
- `git diff --check`, examen du diff et revue indépendante avant commit/tag/push.

## Suggested Review Order

- Entrée d’apprentissage et options additives.
  [z_learning_session_options.dart:8](../../packages/zcrud_study/lib/src/presentation/z_learning_session_options.dart#L8)
- Confirmation et écriture unique du palier choisi.
  [z_study_session_host.dart:1462](../../packages/zcrud_study/lib/src/presentation/z_study_session_host.dart#L1462)
- Politique de file distincte du seuil de réussite SRS.
  [z_study_session_engine.dart:140](../../packages/zcrud_session/lib/src/domain/z_study_session_engine.dart#L140)
- Notification du résultat rendu, après frame et dédupliquée.
  [z_flashcard_list_view.dart:668](../../packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart#L668)
- Parcours réel par gestes jusqu’à la fin de session.
  [cr_102_learning_gestures_test.dart:10](../../packages/zcrud_study/test/presentation/cr_102_learning_gestures_test.dart#L10)
- Adoption, compatibilité et preuves de publication.
  [handoff-v3.55.0.md:1](../../docs/handoff-v3.55.0.md#L1)
