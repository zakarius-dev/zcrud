# Rapport d'exploration — Parité migration Flashcards & Mindmaps (IFFD ∥ lex_douane → zcrud)

> **Date** : 2026-07-16 · **Méthode** : 6 audits en lecture seule (2 par codebase : flashcards + mindmaps) sur
> `/home/zakarius/DEV/iffd`, `/home/zakarius/DEV/lex_douane`, `/home/zakarius/DEV/zcrud`.
> **Question posée (user)** : « Est-ce qu'en l'état, si j'entame la migration dans les deux apps (IFFD et
> Lex Douane), je ne risque pas de rater et de perdre certaines fonctionnalités ? »
> **Usage prévu de ce rapport** : ENTRÉE de la planification BMAD (contexte frais) d'un epic
> d'enrichissement zcrud comblant les écarts identifiés, AVANT toute migration app-side.
> **Annexes** : les 6 inventaires détaillés (fichiers, classes, champs, couplages) sont dans `annexes/`.

---

## 1. Réponse courte

- **Mindmaps : risque de migration FAIBLE.** `zcrud_mindmap` **égale ou dépasse** la source canonique
  lex_douane (même approche auto-layout, outline editor qui corrige un bug historique, tree-ops plus
  riches). Seule absence transverse : la **génération IA** (app+backend, légitimement app-side).
- **Flashcards : risque RÉEL et ciblé.** zcrud a porté le **domaine, l'édition, le SRS et le moteur de
  session** — mais **PAS la couche présentation de révision** : carte flip, pile swipeable, écran de
  fin/célébration, liste+filtres UI, gabarit PDF. Ces pièces **existent dans `lex_ui`** (la source
  canonique) : ce sont donc de **vraies pertes** en cas de migration à l'aveugle, pas des extras IFFD.

**Recommandation** : NE PAS migrer les flashcards avant un epic d'enrichissement zcrud (§6). Les
mindmaps sont migrables dès maintenant (IA à câbler app-side).

---

## 2. Matrice de parité — FLASHCARDS

Légende : ✅ porté (impl fournie) · 🟡 port-seulement / générique (à câbler app-side) · ❌ absent ·
➖ non-canonique (extra propre à une app, à trancher).

| Fonctionnalité | IFFD | lex_douane (source canonique) | zcrud | Statut migration |
|---|---|---|---|---|
| Modèle + types de carte | 4 types | 6 types | **6 types** (`multipleChoice, trueOrFalse, openQuestion, exercise, fillBlank, shortAnswer`) + slots `source`/`extra`/`extension` | ✅ zcrud ≥ source |
| Éditeur de champs (type, QCM, vrai/faux, validation) | oui | `study_flashcard_editor_screen` | `registerZFlashcardEditors` + `ZFlashcardEditionValidator` (question requise, QCM ≥2 choix + 1 correct) | ✅ porté |
| Tags (chips + éditeur + palette) | oui | oui (palette 8 couleurs verrouillée) | `ZTagChips` + `ZTagEditor` | ✅ porté |
| Scheduler SM-2 + config + store SRS séparé | oui | oui (`RepetitionInfo` hors carte) | `ZSm2Scheduler`/`ZSrsConfig`/`ZRepetitionStore` (SRS hors-entité) | ✅ porté |
| Moteur de session + reviewer (cycle, lapses) | oui | oui | `ZStudySessionEngine`/`ZSessionReviewer`/`ZSessionState` | ✅ porté |
| Moteur examen blanc (sans SRS) | oui | `ListSessionView` | `ZWhiteExamSessionEngine` (**moteur oui, UI liste non vérifiée**) | ⚠️ UI à confirmer |
| Boutons qualité SRS (5 niveaux + intervalle prévisionnel) | oui | `SrsQualityButtons` | `ZSrsQualityButtons` | ✅ porté |
| Répartition qualité / anneaux de progression | oui | (dans summary) | `ZSessionQualityBreakdown` / `ZStudyProgressRings` | ✅ porté (primitives) |
| **Carte de révision FLIP interactive** | `FlashcardRepetitionCard` (flip+swipe) | **`SessionFlashcardView`** — `AnimatedSwitcher` fade 250 ms question→réponse, **adaptée par type** (QCM cliquable avec correction, VF, réponse ouverte + évaluation IA) | ❌ **ABSENT** | ❌ **PERTE** |
| **Pile swipeable de session** | oui (6 modes + gamification streak) | **`SessionCardSwiper`** (`flutter_card_swiper`, swipe neutralisé pour la notation — seuls les boutons SRS valident) | ❌ **ABSENT** | ❌ **PERTE** |
| **Écran de fin / célébration** | page animée | **`SessionSummaryView`** — trophée, compteur, répartition qualités, confetti (1×, jamais si Reduce Motion), boutons « Terminer / Encore N dues » | ⚠️ partiel (primitives breakdown+rings existent, **l'écran assemblé n'existe pas**) | ⚠️ **PERTE partielle** |
| **Liste/grille de flashcards + filtres UI** | oui (recherche + multi-filtres + sélection/lots) | **`study_folder_screen`** — tri date/titre/custom, filtre sous-dossier + tags (OU, composables) | ❌ widget **ABSENT** (seul `ZStudySessionSelector` = filtrage pur domaine ; `zcrud_list` reste générique) | ❌ **PERTE (UI)** |
| **Génération IA** (docs / texte / sujets) | `ai_flashcards_generator` 3 onglets | **`flashcard_generation_controller` + `flashcard_generation_sheet`** (impl complète, entités request/result, feuille de confirmation tags post-génération) | 🟡 `ZFlashcardGenerationPort` (**port seul**, aucune impl) | 🟡 impl app-side (AD-15) légitime — **flux UI (sheet) portable** |
| **Export PDF de flashcards** | local Syncfusion + serveur, gabarit typé | `pdfExportControllerProvider` → `PdfExportResult` (bytes+filename+MIME), dossier entier ou sélection | 🟡 `ZExporter`/`ZPdfCreationService` **génériques** (aucun gabarit flashcard) | 🟡 **gabarit à fournir** |
| Éditeur **batch/multi-flashcards** | `multi_flashcard_editor` (sélection multiple, suppression groupée, preview) | ➖ ABSENT (la sélection multiple ne sert qu'à l'export PDF) | ❌ ABSENT | ➖ extra IFFD non-canonique — à trancher |
| Aperçu lecture-seule carte curée + « dupliquer pour modifier » | — | oui (L2) | ❌ non identifié | ⚠️ mineur, à trancher |
| Champs de liaison app (documentId/pageNumber, noteId, hsSection/hsChapter, chatConversationId) | champs typés | union `source` (article\|note\|conversation\|document\|subject) | slots `source` **registre-pluggable** + `extra` (AD-4) | ✅ logeable (l'app enregistre ses types de source) |

**Entité canonique `Flashcard` (lex_core)** : `id?/folderId?/subFolderId?/type(6)/question/answer?/isTrue?/
choices?/explanation?/hint?/tagIds/source?/isReadOnly/createdAt?/updatedAt?` — **identique au `ZFlashcard`
zcrud** (avec `extension`/`extra` en plus). `RepetitionInfo` SM-2 séparé de la carte des deux côtés.

---

## 3. Matrice de parité — MINDMAPS

| Fonctionnalité | IFFD | lex_douane (source) | zcrud | Statut |
|---|---|---|---|---|
| Rendu graphe auto-layout | `graphite` (+ mode flowchart legacy) | `graphview` ^1.5.1 / BuchheimWalker (top-bottom), zoom/pan `InteractiveViewer` | **`graphite` ^1.2.1** direct — `ZMindmapView` instancie `DirectGraph` (zoom/compact/plein-écran/super-racine) | ✅ porté (réimpl propre) |
| Outline editor arborescent (édition de référence) | oui (liste réordonnable indentée) | oui (liste indentée — l'édition ne passe PAS par le canvas) | `ZMindmapOutlineEditor` + `ZMindmapOutlineController` (**corrige le bug de sauvegarde historique lex/IFFD**) | ✅ zcrud ≥ source |
| Tree ops | add/del/rename | add-child/delete/rename **seulement** (ni move/reparent, ni reorder, ni indent/outdent) | `ZMindmapTreeOps` : add/delete/update/**move/indent/outdent/reorder** (structural sharing) | ✅ **zcrud > source** |
| Node card / liste a11y / contrôles de vue | oui | `MindmapView` (interactive/compact) | `ZMindmapNodeCard` / `ZMindmapListView` (surface a11y de référence) / `ZMindmapViewControls` | ✅ porté |
| Structure du nœud | id/title(**markdown/LaTeX**)/content(**markdown/LaTeX**)/children/level/**edgeColor/size/resizable** | id/label/content(**texte brut**)/children/level — PAS de couleur/taille/position | id/label/content(**texte brut**)/children/level + `extension`/`extra` (AD-4) | ✅ = source (couleur/taille/markdown = extras IFFD ➖) |
| Édition markdown/LaTeX du contenu de nœud | oui (dialog) | ➖ ABSENT (`TextField` brut) | ❌ édition riche absente ; **lecture** markdown opt-in via `ZMindmapMarkdownContent` (slot AD-4) | ➖ extra IFFD non-canonique |
| Édition contenu de nœud (dialog/sheet basique) | oui | `MindmapNodeEditSheet` (label+content) | via outline editor | ✅ porté |
| **Génération IA de mindmap** | oui (3 variantes : notes/pages/document) | **PRÉSENT** — prompt backend `mindmap_generator.py`, déclenchée via chat Lexia, bloc inline + « Attacher au dossier » | ❌ ABSENT (aucun `ZMindmapGenerationPort` — seuls `ZAiExplanationPort`/`ZNoteSummaryPort` génériques dans `zcrud_study`) | 🟡 impl app+backend-side ; **port dédié à créer** pour homogénéité |
| Mode flowchart formes libres + drag (`flutter_flow_chart`) | M5-M9 (import/export JSON débranché) | ➖ ABSENT | ❌ ABSENT | ➖ legacy/orphelin IFFD — non-port probablement intentionnel |
| Export/import (PDF/OPML/image) | (JSON flowchart orphelin) | ➖ ABSENT | ❌ ABSENT (JSON canonique interne seul) | ➖ non-canonique |
| Drag libre de nœud | seulement en mode flowchart | ❌ (auto-layout only) | ❌ (auto-layout only) | ✅ parité (jamais canonique) |

---

## 4. Verdict de migration par app

- **lex_douane (Riverpod)** — mindmaps ✅ prêts. Flashcards : domaine/édition/SRS ✅, mais la **couche
  révision de `lex_ui` n'a jamais été portée dans zcrud** (`SessionFlashcardView`, `SessionCardSwiper`,
  `SessionSummaryView`, liste+filtres de `study_folder_screen`, export PDF). Migrer maintenant =
  **régression de l'écran de révision**. IA + PDF à recâbler.
- **IFFD (GetX/Riverpod)** — mêmes pertes flashcard + extras non-canoniques à trancher (batch editor,
  markdown de nœud, mode flowchart) : soit abandon assumé, soit conservation app-side. **Risque le plus élevé.**
  Rappel : la migration de données IFFD flat→canonique est DÉJÀ outillée côté zcrud (`ZLegacyStudyMigrator`,
  ES-11.2) — le présent rapport ne concerne que les fonctionnalités UI.

---

## 5. Sources best-of-breed à porter (chemins exacts pour le create-story)

Toutes dans `/home/zakarius/DEV/lex_douane/packages/lex_ui/lib/presentation/` (LECTURE SEULE) :

| Pièce à porter | Fichier source lex_ui |
|---|---|
| Carte flip adaptative par type | `widgets/study/session_flashcard_view.dart` |
| Pile swipeable (notation par boutons, swipe neutralisé) | `widgets/study/session_card_swiper.dart` (via `session_flashcard_view`/écran session) |
| Écran résumé/célébration (confetti + Reduce Motion) | `widgets/study/session_summary_view.dart` (repéré comme `SessionSummaryView`) |
| Liste + filtres (tri, sous-dossier, tags OU-composables) | `screens/study_folder_screen.dart` |
| Mode liste examen blanc | `widgets/study/` (`ListSessionView`) |
| Flux UI de génération IA (sheet + confirmation tags) | `widgets/study/flashcard_generation_sheet.dart` + `controllers/flashcard_generation_controller.dart` + `widgets/study/flashcard_tag_confirm_sheet.dart` |
| Export PDF (contrôleur → `PdfExportResult`) | contrôleur `pdfExportControllerProvider` (lex_ui) |
| Complément IFFD (comparaison) | `/home/zakarius/DEV/iffd/lib/src/presentation/features/flashcards/` |

Existant zcrud à RÉUTILISER (jamais redéclarer) : `ZFlashcard`/`ZFlashcardType`/`ZChoice` (zcrud_flashcard
domain) ; `ZStudySessionEngine`/`ZWhiteExamSessionEngine`/`ZSessionReviewer`/`ZSessionState` +
`ZSrsQualityButtons`/`ZSessionQualityBreakdown`/`ZStudyProgressRings` (zcrud_session) ;
`ZStudySessionSelector` (zcrud_study_kernel) ; `ZTagChips`/`ZTagEditor` ; `ZExporter`/`ZPdfCreationService`
(zcrud_export) ; `ZFlashcardGenerationPort` (zcrud_study) ; et les nouveaux packages EX-UI
(`zcrud_responsive` pour l'adaptativité, `zcrud_ui_kit` pour états/toasts/confirm, `zcrud_navigation`
pour la présentation adaptative des éditeurs).

## 6. Périmètre proposé pour l'epic d'enrichissement (« E-STUDY-UI », à planifier en session fraîche)

Objectif : combler les écarts CANONIQUES avant toute migration app-side. Pur-Flutter (AD-2/AD-15),
aucun gestionnaire d'état, thème/l10n injectés (AD-13), enums > booléens (convention EX-UI).

1. **`ZFlashcardReviewCard`** (zcrud_flashcard/presentation) — carte flip adaptative par type
   (QCM cliquable + correction, vrai/faux, question ouverte + slot d'évaluation injectable), reveal via
   `ZFlashcardEditingScope`/canal existant, animations avec égard Reduce Motion.
2. **`ZSessionCardSwiper`** (zcrud_session/presentation) — pile swipeable au-dessus du moteur de session
   existant ; la notation reste aux `ZSrsQualityButtons` (swipe de navigation neutralisé pour la note).
   Décision d'archi : dépendance `flutter_card_swiper` (à évaluer) vs implémentation maison.
3. **`ZSessionSummaryView`** (zcrud_session/presentation) — écran de fin assemblant
   `ZSessionQualityBreakdown` + `ZStudyProgressRings` + trophée/confetti (opt-in, jamais si Reduce
   Motion), boutons « Terminer / Encore N dues » (callbacks injectés).
4. **`ZFlashcardListView` + filtres UI** (zcrud_flashcard/presentation) — liste/grille (peut réutiliser
   `ZAdaptiveGrid` d'EX-UI) + barre de filtres (tri, sous-dossier, tags OU) branchée sur
   `ZStudySessionSelector` ; actions par item via `ZItemActionsMenu` existant.
5. **Gabarit PDF flashcard** (zcrud_export) — `ZFlashcardPdfTemplate` sur `ZPdfCreationService`
   (mise en page typée question/réponse/choix/explication ; dossier entier ou sélection).
6. **UI d'examen blanc** (`ZListSessionView`) si l'audit d'implémentation confirme son absence —
   au-dessus de `ZWhiteExamSessionEngine`.
7. **(mindmap, optionnel)** port `ZMindmapGenerationPort` dans zcrud_study pour homogénéiser l'IA
   (impl toujours app-side).
8. **Hors périmètre / app-side** : impls concrètes IA (backend lex/IFFD), extras IFFD non-canoniques
   (mode flowchart, batch editor, markdown de nœud — à trancher explicitement avec le user au brief).

## 7. Questions ouvertes pour la planification

- OQ-1 : `flutter_card_swiper` en dépendance de `zcrud_session` (package UI léger) ou réimplémentation ?
- OQ-2 : le confetti (`SessionSummaryView`) → quelle lib (lex utilise laquelle ?) ou peinture maison ;
  gate `uses-material-design`/poids à vérifier.
- OQ-3 : l'« évaluation IA d'une réponse ouverte » en session (lex `SessionFlashcardView`) : slot/port
  injectable dans `ZFlashcardReviewCard` (recommandé) ou hors périmètre v1 ?
- OQ-4 : extras IFFD (batch editor, markdown de nœud) : abandon, app-side, ou v1.x zcrud ?
- OQ-5 : `ZListSessionView` — vérifier sur code si une UI liste d'examen blanc existe déjà côté zcrud_exam.

---
*Annexes (inventaires détaillés par source) : `annexes/iffd_flashcards.md`, `annexes/lex_flashcards.md`,
`annexes/zcrud_flashcards.md`, `annexes/iffd_mindmaps.md`, `annexes/lex_mindmaps.md`,
`annexes/zcrud_mindmaps.md`.*
