# Inventaire affichage/édition flashcards — lex_douane (module Étudier)

Périmètre : `lex_core` (domaine), `lex_ui` (présentation), `lex_data` (repos). Hors `apps/lex_douane_admin`.

## Entité canonique `Flashcard` (lex_core/lib/domain/entities/education/flashcard.dart)

Champs : `id?`, `folderId?`, `subFolderId?`, `type` (FlashcardType, defensive unknownEnumValue→openQuestion), `question`, `answer?`, `isTrue?`, `choices?` (List<FlashcardChoice> réutilisé de `lexia_flashcard.dart`), `explanation?`, `hint?`, `tagIds` (List<String>, défaut []), `source?` (FlashcardSource), `isReadOnly` (bool, défaut false), `createdAt?`, `updatedAt?`.
- `isEphemeral` = `id == null` (carte née dans le chat LexIA, non encore persistée dans un dossier — matérialisée par le repo à la sauvegarde).
- `fromChatJson`/`toChatJson` : wire camelCase du chat, distinct du wire persisté snake_case.

**FlashcardType** (6 valeurs, superset zéro-perte) : `multipleChoice`, `trueOrFalse`, `openQuestion`, `exercise`, `fillBlank`, `shortAnswer`. Désérialisation défensive → `openQuestion`.

**FlashcardSource** (union scellée, discriminant `kind`) : `article` (codeId+articleId), `note` (noteId), `conversation` (conversationId+messageId), `document` (documentId+page?), `subject` (texte libre, génération IA « sujet »). `kind` inconnu → `FormatException` (pas de silent fallback).

**FlashcardTag** (`id`, `title`, `colorKey`) — palette verrouillée à 8 couleurs (`blue/green/orange/purple/red/teal/pink/indigo`), remap déterministe par hash SHA-256 du titre si couleur hors palette.

**RepetitionInfo** (état SM-2 **séparé** de la carte, jamais emporté par le partage) : `flashcardId`, `folderId`, `interval`, `repetitions`, `easeFactor`, `nextReviewDate?`, `learnedAt?`, `lastQuality?`.

## Fonctionnalités (L1..L15)

1. **Éditeur de flashcard** (`study_flashcard_editor_screen.dart`, `_FlashcardEditorForm`) — création/édition unitaire : sélecteur de type (6 valeurs), champs question/réponse/explication/indice, éditeur de choix QCM, Vrai/Faux via `SegmentedButton`, tags attachables, validation bloquante (question requise, QCM ≥2 choix non vides + ≥1 correct), garde-fou "dirty" (confirmation d'abandon), lien "voir la source" (article).
2. **Aperçu lecture seule carte curée** (`_ReadOnlyFlashcardPreview`) — cartes `isReadOnly==true` (issues d'un partage) jamais éditables ; bouton "Dupliquer pour modifier".
3. **Éditeur de choix QCM** (`flashcard_choices_editor.dart`, `FlashcardChoicesEditor`) — liste dynamique de brouillons (texte + switch "correct" + suppression), bouton "Ajouter un choix".
4. **Sélecteur de type** (`flashcard_type_selector.dart`, `FlashcardTypeSelector`) — `ChoiceChip` par valeur d'enum (6), labels localisés.
5. **Chips de tags** (`flashcard_tag_chips.dart`, `FlashcardTagChips`) — `FilterChip` multi-sélection colorés, réutilisés pour attribution (éditeur) ET filtrage (liste dossier).
6. **Éditeur de tag** (`flashcard_tag_editor_sheet.dart`, `FlashcardTagEditorDialog`) — nom + palette de 8 couleurs, validation nom vide/doublon.
7. **Feuille de confirmation de tags post-génération** (`flashcard_tag_confirm_sheet.dart`) — pré-cochage éditable des tags suggérés par l'IA avant persistance du lot.
8. **Palette de couleurs de tags** (`flashcard_tag_palette.dart`, `FlashcardTagPalette`).
9. **Carte de révision interactive `SessionFlashcardView`** (`session_flashcard_view.dart`) — voir FOCUS (a).
10. **Pile de cartes `SessionCardSwiper`** (même fichier) — `flutter_card_swiper`, geste de swipe désactivé côté notation (neutralisé, AC9 : seuls les boutons SRS valident), carte de fond = aperçu muet (question seule).
11. **Boutons de qualité SRS** (`srs_quality_buttons.dart`, `SrsQualityButtons`) — 5 niveaux `Sm2QualityLevel`, intervalle prévisionnel affiché par bouton (`Sm2.simulate`), mise en évidence de la suggestion IA (10.2).
12. **Génération IA de flashcards** — voir point 6 du prompt (détail ci-dessous).
13. **Récapitulatif de fin de session `SessionSummaryView`** — voir FOCUS (c).
14. **Liste/filtre dans le détail de dossier** (`study_folder_screen.dart`) — voir FOCUS (d).
15. **Export PDF** (`folder_actions_sheet.dart`, `pdfExportControllerProvider`, `pdf_export_result.dart`) — voir FOCUS (e).
16. **Mode "liste" de session** (`list_session_view.dart`, `ListSessionView`) — parcours linéaire sans SRS (consultation/exam blanc), révélation réponse, prev/next, pas de notation.

## Génération IA (`flashcard_generation_controller.dart` + `flashcard_generation_sheet.dart`)

- Sources : `FlashcardSource` app (article/note/conversation) ou `subject` (texte libre — "sujet connexe"). `document` explicitement hors périmètre (`UnsupportedError`).
- Feuille (`FlashcardGenerationSheet`) : dossier/sous-dossier cible (dropdown), nombre de cartes (slider 1..50), répartition par 4 types générables (`kDefaultGenerableTypes` : multipleChoice/trueOrFalse/openQuestion/fillBlank) via `FilterChip`, répartition équitable (`distributeTypes`).
- Contrôleur Riverpod `@Riverpod(keepAlive:true)` family par dossier cible : anti-double-tap, garde offline, `Either.fold`, persistance carte par carte via `saveFlashcard` (jamais de lot partiel silencieux — bascule `error(server)` si une écriture échoue), quota/rate-limit humanisés.
- Flux avec pré-cochage de tags (`generatePreview` → feuille de confirmation → `commitPreview`) : génère sans persister, résout les tags via `/tags/suggest` (repli déterministe local), applique après confirmation utilisateur.
- Entités : `FlashcardGenerationRequest` (source, count, typesDistribution, language, targetFolderId/targetSubFolderId, noteText) avec `toWireJson`/`toSourcePayload` ; `FlashcardGenerationResult` (flashcards éphémères + suggestedTags + quota).
- Erreurs typées `FlashcardGenerationFailure`/`FlashcardGenerationErrorKind` (quota/rate-limit/invalidSource/serviceUnavailable/offline/network/server).

## Réponses FOCUS

**(a) Carte de révision interactive flip — PRÉSENT.** `SessionFlashcardView` (dans `session_flashcard_view.dart`) : face question (type + énoncé + indice optionnel + bouton "Voir la réponse") → tap n'importe où sur la carte ou bouton → `AnimatedSwitcher` (fade 250ms, `Duration.zero` si Reduce Motion) vers la face réponse, adaptée par type (QCM cliquable avec correction visuelle, Vrai/Faux à 2 boutons, réponse ouverte avec `TextField` + évaluation IA "Évaluer ma réponse" ou "Évaluer sans IA", explication, lien source). Empilée dans `SessionCardSwiper` (`flutter_card_swiper`) : swipe désactivé pour la notation (uniquement les 5 boutons SRS valident, AC9), carte de fond = aperçu muet.

**(b) Éditeur batch/multi-flashcards — ABSENT (édition), PRÉSENT (sélection multiple pour export uniquement).** Aucun éditeur ne permet de modifier le contenu de plusieurs cartes en une opération — l'éditeur (`study_flashcard_editor_screen.dart`) est strictement unitaire (une carte à la fois, création ou édition). Le seul mécanisme multi-cartes est une **sélection multiple** dans `study_folder_screen.dart` (appui long → `_enterSelection`, `_selectedCardIds`, barre `_buildSelectionBar`) exclusivement pour choisir les cartes à **exporter en PDF** (`_exportDeckBySelection`) — pas de suppression groupée, pas de tag groupé, pas d'édition groupée de contenu.

**(c) Page de célébration de fin de session — PRÉSENT.** `SessionSummaryView` (`session_summary_view.dart`, Story 8.2) : titre + icône trophée, compteur de cartes révisées, répartition colorée des 5 qualités (`SessionQualityBreakdown`), confetti (`package:confetti`) joué une seule fois à l'apparition (jamais si Reduce Motion, purement décoratif), analytics `FlashcardSessionCompletedEvent` (0-PII), boutons "Terminer" et "Encore N dues" (relance session si cartes restantes tous dossiers).

**(d) Liste de flashcards avec filtres — PRÉSENT.** Dans `study_folder_screen.dart` : liste/grille des flashcards du dossier (section "Flashcards (n)", triable date/titre/ordre custom réordonnable), filtrable par sous-dossier (chips) et par tags (OU logique, `_TagFilterRow` + `FlashcardTagChips`, Story 12.2 AC8), composable entre les deux filtres. Chaque carte est un tile avec actions (éditer, dupliquer).

**(e) Export PDF de flashcards — PRÉSENT.** Story 17.4 : entrée "Exporter le deck en PDF" dans `folder_actions_sheet.dart` (export dossier entier, désactivée hors ligne) + export d'une **sélection** de cartes via le mode sélection multiple de `study_folder_screen.dart`. Piloté par `pdfExportControllerProvider`, résultat `PdfExportResult` (bytes + nom de fichier suggéré + MIME `application/pdf`) prêt pour la feuille de partage système. Aucun appel réseau en couche presentation (délégué à `education_export_remote_data_source`).

## Couplage

- **Riverpod** partout côté présentation (`ConsumerWidget`/`ConsumerStatefulWidget`, providers `@riverpod`/`@Riverpod(keepAlive:true)` family).
- `go_router` pour la navigation (routes nommées `study_flashcard_edit`, `article`, `study_tags`, `study_session`).
- Domaine (`lex_core`) 100% pur Dart, `Either<Failure,T>` (dartz) pour tous les repos.
- Repos `FlashcardsRepository`/`RepetitionRepository` : offline-first (Hive source de lecture, Firestore sync fire-and-forget), invariant de matérialisation des cartes éphémères, invariant SM-2 write unique via `reviewCard()`/`Sm2.apply`.
