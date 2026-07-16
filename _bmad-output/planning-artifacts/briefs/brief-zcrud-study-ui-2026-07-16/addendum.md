---
title: "Addendum — Brief E-STUDY-UI / E-MULTI-EDIT"
status: final
created: 2026-07-16
updated: 2026-07-16
---

# Addendum — détail à destination du PRD et de l'architecture

## A. « Tout le meilleur d'IFFD » — détail des 8 pièces (réf. annexe `iffd_flashcards.md`)

| # | Pièce (réf. annexe) | Détail à porter |
|---|---|---|
| 1 | Saisie interactive notée (F13) | QCM cases à cocher, mode simple/multiple selon nb de bonnes réponses, correction visuelle après soumission ; V/F 2 boutons avec auto-soumission ; ouverte/exercice = éditeur de rédaction ; éval locale QCM/VF (comparaison exacte), éval IA pour ouverte (score 1-5, **repli qualité neutre 3 si échec IA**) ; minuteur `Stopwatch` ; « Je ne sais pas » = soumission qualité 1 ; auto-passage carte suivante (~200 ms) |
| 2 | Indices (F13) | Bouton « Indice » : montre l'indice stocké (`hint`) puis génère de nouveaux indices via port IA quand épuisés ; tracking du nb d'indices utilisés → module la qualité |
| 3 | Feedback pédagogique (F14) | Banques de messages par qualité (4-5 encouragement / 3 neutre / 1-2 motivation), modulées par temps de réponse (<10 s sans indice = « exceptionnel ») et nb d'indices |
| 4 | Modes de session (F15) | `nFlashcardsLearningCycle`, `allFlashcardsLearningCycle`, `listOnly`, `test`, `whiteExam`, `cramming` ; points colorés par qualité de dernière révision (cycle N), barre segmentée (mode complet) ; émojis satisfait/insatisfait pendant le drag |
| 5 | Célébration + stats (F16) | Trophée animé (scale élastique + glow), titre dégradé, stats totalCards/masteredCards/sessionDuration, confettis, cercles de fond animés |
| 6 | Sélecteur de session (F17) | « Apprendre +N » (jamais apprises, lot 30 max, anneau de progression), « À réviser » (dues triées par urgence, visible si >0), « Test » (avec dialog filtres F18) ; catégorisation par lookup sets O(1) |
| 7 | Streak (F15.8/F17) | Mise à jour du streak quotidien après une répétition (hors listOnly) ; badge flamme dans le sélecteur ; snackbar de confirmation |
| 8 | Filtres test/examen (F18) | Fonction pure : questionCount (défaut 10, tirage aléatoire si excédent), questionTypes multi-sélection, masteryLevels (mauvais=q1-2/jamais, bon=q3, maîtrise=q4-5), tags, sources ; mélange des choix QCM avant session |

## B. Sources best-of-breed (LECTURE SEULE — jamais modifiées depuis ce repo)

- lex_ui : `packages/lex_ui/lib/presentation/widgets/study/session_flashcard_view.dart`,
  `session_card_swiper.dart`, `session_summary_view.dart`, `screens/study_folder_screen.dart`,
  `flashcard_generation_sheet.dart` + `flashcard_tag_confirm_sheet.dart` +
  `controllers/flashcard_generation_controller.dart`, contrôleur `pdfExportControllerProvider`.
- IFFD : `lib/src/presentation/features/flashcards/` — notamment
  `interactive_flashcard_repetition_card.dart` (~1050 l.), `learning_mode_question_card.dart`,
  `folder_flashcards_repetitions_page.dart` (~1200 l.), `flashcards_learning_celebration_page.dart`,
  `multi_flashcard_editor_page.dart` (~1240 l.), `folder_flashcards_list_page.dart` (~1080 l.),
  `utils/flashcard_filters.dart`, `flashcard_widgets.dart` (`FlashcardsLearningModeScreen`).
- Chemins complets et inventaires : `docs/parity-study-ui-2026-07-16/` (rapport + 6 annexes).

## C. Dépendances tierces décidées (versions relevées sur lex_ui)

- `flutter_card_swiper: ^7.2.0` — zcrud_session uniquement.
- `confetti: ^0.8.0` — zcrud_session uniquement (opt-in, 1 tir, jamais si Reduce Motion).
- Flip 3D : **maison** (`Transform.rotateY` animé) — la dep `flip_card` d'IFFD n'est PAS reprise.

## D. Alternatives écartées (rationale)

- **Flip seul ou fade seul** : écarté — enum `ZRevealTransition { flip3d, fade }` pour que chaque
  app conserve son identité visuelle à la migration (convention enums > booléens).
- **Streak app-side** : écarté — promu canonique (zcrud_study_kernel) pour profiter aussi à lex.
- **Exclusion du cramming** : écartée par décision user — inclus, mapping moteur à vérifier en archi
  (candidat : session sans écriture SRS ≈ `ZWhiteExamSessionEngine`).
- **Multi-édition limitée aux flashcards** : écartée — deux étages (moteur générique
  zcrud_core/zcrud_list + `ZMultiFlashcardEditor`), en **epic dédié E-MULTI-EDIT**.
- **Goldens sur les écrans clés** : écartés (maintenance) — preuve = matrice verte à tests porteurs
  + parcours assemblé dans l'app example.
- **Reprise du batch editor / markdown de nœud tels quels (spécifiques IFFD)** : écartée — versions
  génériques canoniques ; le mode flowchart et couleur/taille de nœud restent app-side (slots AD-4).

## E. Faits levés sur le code pendant le brief (2026-07-16)

- Aucune UI d'examen blanc dans zcrud (`grep` packages/*/lib) : seul le moteur
  `ZWhiteExamSessionEngine` existe → `ZListSessionView` confirmé au périmètre.
- lex_ui dépend de `flutter_card_swiper ^7.2.0` et `confetti ^0.8.0` (pubspec lex_ui) ; le
  confetti n'est utilisé que dans `session_summary_view.dart`.
