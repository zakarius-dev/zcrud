---
title: "Réconciliation — PRD E-STUDY-UI/E-MULTI-EDIT vs rapport de parité 2026-07-16"
status: final
created: 2026-07-16
---

# Réconciliation PRD ↔ rapport de parité

> Sources comparées :
> - PRD : `_bmad-output/planning-artifacts/prds/prd-zcrud-study-ui-2026-07-16/prd.md`
> - Rapport : `docs/parity-study-ui-2026-07-16/rapport.md` (+ annexe `annexes/iffd_flashcards.md`)
> - Brief + addendum : `_bmad-output/planning-artifacts/briefs/brief-zcrud-study-ui-2026-07-16/`
>
> Question : chaque ligne ❌ / ⚠️ / 🟡-portable des matrices §2 (flashcards) et §3 (mindmaps)
> est-elle couverte par au moins un FR du PRD ? Hors périmètre déclaré (brief §Hors périmètre) :
> impls IA concrètes, mode flowchart, voie PDF serveur, extras visuels de nœud (couleur/taille).

## 1. Matrice §2 — Flashcards : correspondance ligne → FR

| Ligne du rapport (§2) | Statut rapport | FR couvrant | Verdict |
|---|---|---|---|
| Moteur examen blanc — « UI liste non vérifiée » (`ListSessionView`) | ⚠️ UI à confirmer | **FR-SU13** (`ZListSessionView`, absence confirmée) + FR-SU2 (saisie par question) | ✅ couvert |
| Carte de révision FLIP interactive (`SessionFlashcardView` / `FlashcardRepetitionCard`) | ❌ PERTE | **FR-SU1** (carte adaptative, `ZRevealTransition`, Reduce Motion) + **FR-SU2** (saisie notée) + **FR-SU3** (indices) + **FR-SU4** (minuteur) + **FR-SU5** (avance) | ✅ couvert |
| Pile swipeable de session (`SessionCardSwiper`, 6 modes + gamification) | ❌ PERTE | **FR-SU6** (swiper, notation aux boutons SRS, indicateurs) + **FR-SU7** (6 modes) + **FR-SU11** (streak) | ✅ couvert |
| Écran de fin / célébration (`SessionSummaryView`) | ⚠️ PERTE partielle | **FR-SU8** (trophée, stats, breakdown+rings, confetti 1×/Reduce Motion, « Terminer / Encore N dues ») | ✅ couvert |
| Liste/grille de flashcards + filtres UI (`study_folder_screen`) | ❌ PERTE (UI) | **FR-SU14** (liste/grille, recherche normalisée, tris dont ordre manuel, filtres sous-dossier+tags OU, actions item, sélection multiple) | ✅ couvert (réserve R-3 ci-dessous) |
| Génération IA — « flux UI (sheet) portable » | 🟡 portable | **FR-SU15** (sheet + confirmation de tags, remise à l'appelant) ; impl du port = hors périmètre déclaré | ✅ couvert (réserve R-2) |
| Export PDF — « gabarit à fournir » | 🟡 portable | **FR-SU16** (`ZFlashcardPdfTemplate`, badges, ✓/✗, avec/sans réponses, markdown+LaTeX, dossier/sélection) ; voie serveur = hors périmètre déclaré | ✅ couvert |
| Éditeur batch/multi-flashcards (extra IFFD « à trancher ») | ➖ (zcrud ❌) | **Tranché : promu canonique** → **FR-SU19** (capacité moteur) + **FR-SU20** (`ZMultiFlashcardEditor`) | ✅ couvert |
| Aperçu lecture-seule carte curée + « dupliquer pour modifier » (lex, L2) | ⚠️ mineur, à trancher | **AUCUN FR** — non tranché ni déclaré hors périmètre | ❌ **NON COUVERT** (écart E-1) |
| Champs de liaison app (source/extra) | ✅ logeable | n/a (déjà couvert par AD-4, pas une perte) | — |

Lignes ✅ de la matrice §2 (modèle, éditeurs, tags, SM-2, moteur session, boutons qualité,
breakdown/rings) : déjà portées, hors sujet de la réconciliation.

## 2. Matrice §3 — Mindmaps : correspondance ligne → FR

| Ligne du rapport (§3) | Statut rapport | FR couvrant | Verdict |
|---|---|---|---|
| Édition markdown/LaTeX du contenu de nœud (extra IFFD) | ➖ (zcrud ❌) | **Tranché : promu canonique** → **FR-SU17** (slot d'éditeur injectable, impl dans zcrud_markdown, repli texte brut ; rendu du label riche dans le graphe → OA-2) | ✅ couvert |
| Génération IA de mindmap | 🟡 port dédié à créer | **FR-SU18** (`ZMindmapGenerationPort`, contrat aligné sur `ZFlashcardGenerationPort`) ; impl = hors périmètre déclaré | ✅ couvert |
| Mode flowchart formes libres + drag | ➖ | Hors périmètre **explicite** (brief) — non-port intentionnel | ✅ conforme |
| Export/import mindmap (PDF/OPML/image) | ➖ non-canonique | Aucun FR — mais classé ➖ par le rapport lui-même (jamais canonique, JSON flowchart orphelin IFFD) ; abandon cohérent, quoique non listé mot à mot dans le hors-périmètre du brief | ✅ acceptable (note N-1) |
| Extras visuels de nœud (edgeColor/size/resizable) | ➖ (dans ligne « Structure du nœud » ✅) | Hors périmètre **explicite** (brief : logeables via `extension`/`extra` AD-4) | ✅ conforme |
| Rendu graphe / outline editor / tree ops / node card / drag libre | ✅ | Déjà à parité ou supérieurs | — |

## 3. Écarts détectés

### E-1 (seul trou de matrice) — Aperçu lecture-seule d'une carte curée + « dupliquer pour modifier »
- Ligne §2 marquée **⚠️ mineur, à trancher** (fonctionnalité lex_douane : flashcards `isReadOnly`
  consultables avec action « dupliquer pour modifier »).
- Aucun FR ne la couvre : FR-SU20 offre un « aperçu lecture via `ZFlashcardReviewCard` » mais dans
  le contexte du multi-éditeur, pas le flux « carte curée en lecture seule → dupliquer ». Ni le PRD
  ni le brief ne la déclarent hors périmètre ; le critère de succès n°1 (« chaque ligne ❌/⚠️ passe
  à ✅ ») l'inclut pourtant formellement.
- **Reco** : soit ajouter une FR (ou une clause dans FR-SU14 : action item « Dupliquer » +
  verrouillage édition/suppression si `isReadOnly`), soit la déclarer explicitement hors périmètre.
  À noter : `ZFlashcard.isReadOnly` existe déjà dans le domaine zcrud (§2 entité canonique).

### E-2 — Configuration avancée de génération IA d'IFFD (F7) absente de FR-SU15
- FR-SU15 porte le flux **lex** (sheet + confirmation de tags). L'annexe IFFD F7 décrit en plus :
  **3 sources de génération** (document + sélection de pages/scan, sujets auto-suggérés, texte
  libre ≤ 30 000 car.) et une **config avancée** (répartition du nb de questions par
  `QuestionType`, instructions complémentaires, choix du modèle IA).
- Les impls IA sont hors périmètre, mais ces éléments sont de l'**UI/du contrat de requête**
  (champs du `ZFlashcardGenerationRequest`), pas de l'impl. Le brief ne les écarte pas
  explicitement ; l'addendum §A (8 pièces IFFD) ne liste pas F7, ce qui suggère un choix implicite
  du flux lex — jamais acté noir sur blanc.
- **Reco** : trancher — au minimum garantir que le contrat du port (OA-5) accepte
  types×quantités + instructions, pour que la sheet IFFD reste implémentable app-side sans casser
  le port.

### E-3 — Filtres de liste par sources (F9) absents de FR-SU14
- IFFD filtre la **liste** aussi par documents source, notes source, sections/chapitres SH
  (F9.5). FR-SU14 ne prévoit que sous-dossier + tags (la recherche a des « champs cherchés
  configurables », mais pas les filtres). FR-SU12 inclut bien « sources » — mais uniquement pour
  les filtres de test/examen.
- Les sources étant registre-pluggables (AD-4, ligne « champs de liaison » ✅ logeable), un slot de
  filtre par `source.kind` dans FR-SU14 suffirait ; sinon perte du filtrage par source en liste
  pour IFFD. **Reco** : étendre FR-SU14 d'un filtre par source (ou déclarer app-side).

### Mineurs (M)
- **M-1 (F15.8)** — Snackbar de confirmation de streak (« 🔥 Flamme mise à jour ») : exigé par
  l'addendum §A pièce 7, absent de FR-SU11 (qui ne mentionne que le badge flamme). Trivial
  (toast `zcrud_ui_kit`), mais incohérence brief/PRD à lisser au create-story.
- **M-2 (F6)** — Point d'entrée combiné « Créer manuellement / Générer avec l'IA » (dialog de
  création rapide) : aucun FR ne décrit ce chooser ; assemblable app-side à partir des briques
  existantes (éditeur + FR-SU15), à confirmer comme tel.
- **M-3 (F11.6)** — Prévisualisation/impression/partage du PDF (`PdfPreview` du package
  `printing`) : FR-SU16 produit le gabarit, pas la surface de préviz. Cohérent avec
  `ZExporter`/`PdfExportResult` (bytes+filename+MIME → l'app affiche), mais non dit explicitement.
- **M-4 (F1.5/F12.6)** — Détails IFFD assumables : `shuffledChoices()` n'est couvert que via
  FR-SU12 (mélange avant session de test — suffisant si les autres modes n'affichent les choix
  qu'en aperçu) ; rafraîchissement temps réel de la carte (`streamOne`) = branchement data
  app-side, hors parité UI.

### Notes (aucune action requise)
- **N-1** — Export/import mindmap (PDF/OPML/image) : classé ➖ non-canonique par le rapport
  lui-même ; l'abandon est cohérent, mais le brief ne le nomme pas dans son hors-périmètre —
  une ligne au PRD/brief clorait le sujet proprement.
- **N-2** — Toutes les autres pièces « meilleur d'IFFD » (F13, F14, F15, F16, F17, F18) sont
  fidèlement reprises : saisie notée+repli 3+« Je ne sais pas » (FR-SU2), indices+malus qualité
  (FR-SU3), minuteur (FR-SU4), auto-avance (FR-SU5), 6 modes+indicateurs (FR-SU6/7), célébration+
  stats (FR-SU8), feedback qualité/temps/indices (FR-SU9), sélecteur +N/à réviser/test+O(1)
  (FR-SU10), streak (FR-SU11), filtres purs+mélange QCM (FR-SU12), batch editor (FR-SU19/20).
- **N-3** — Suppression avec purge en cascade des répétitions SRS (F5.3/F9.6) : couverte par les
  « hooks de cascade app-side » de FR-SU19 — conforme à l'architecture (cascade côté app).

## 4. Conclusion

**Couverture matrices : 12/13 lignes ❌/⚠️/🟡-portables couvertes** (9 flashcards + 3 mindmaps),
plus 2 lignes ➖ volontairement promues canoniques (batch editor, markdown de nœud) et 3 lignes ➖
conformes au hors-périmètre déclaré. **Un seul vrai trou** : E-1 (aperçu carte curée + dupliquer,
⚠️ mineur non tranché). Côté IFFD, deux écarts fonctionnels notables (E-2 config de génération,
E-3 filtres de liste par source) et quatre points mineurs, tous résolubles par une retouche de FR
ou une déclaration explicite hors périmètre — rien qui remette en cause la structure du PRD.
