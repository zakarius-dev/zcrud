# Rétrospective — Epic E-STUDY-UI (parité UI d'étude)

- **Skill** : `bmad-retrospective` (mode non-interactif, options conservatrices, choix consignés).
- **Date** : 2026-07-17 · **Facilitation** : Amelia (Developer). Participants simulés : Alice (PO), Charlie (Senior Dev), Dana (QA), Elena (Junior Dev), Zakarius (Project Lead).
- **Périmètre** : su-1 → su-12, **12/12 stories `done`**, vertes, revues adversarialement.
- **Clé sprint-status** : `epic-su-retrospective` (à passer `optional → done` par l'orchestrateur).
- **Épic suivant** : **E-MULTI-EDIT (ME)** — `me-1..me-3`, seul epic autorisé à écrire `zcrud_core`/`zcrud_list`, **séquentiel strict**.

---

## 1. Ce que l'epic a livré

L'epic a comblé l'écart *« le cerveau de l'étude sans son visage »* : le domaine d'étude (ES-1..ES-11) existait, mais sans surface de révision. Livré :

| Story | Livrable | Package(s) |
|---|---|---|
| su-1 | Socle : bornes d'échelle 0..5 possédées par `ZSrsConfig`, garde de mode symétrique, `sectionKey` canonique, slots de rendu ouverts (AD-46/34/38/40) | types partagés |
| su-2 | Carte de révision adaptative 6 types + `ZRevealTransition{flip3d,fade}` maison + Reduce Motion | zcrud_flashcard |
| su-3 | Saisie notée QCM/VF locale, indices (port advisory), minuteur, avance par mode — **jamais** d'écriture SRS par le port | zcrud_flashcard |
| su-4 | Pile swipeable (`flutter_card_swiper` confiné) + 6 modes sur les 3 runtimes **existants** | zcrud_session |
| su-5 | Écran de fin + feedback + confetti opt-in 1 tir (jamais si Reduce Motion) | zcrud_session |
| su-6 | Sélecteur de mode O(1) + streak canonique (kernel) + filtres purs | zcrud_study_kernel |
| su-7 | UI examen blanc, correction en fin, **zéro écriture SRS garanti par le type** | zcrud_session |
| su-8 | Liste + recherche accent-insensible + ordre manuel (drag ET boutons = même voie) | zcrud_flashcard |
| su-9 | Flux de génération IA, résultat **éphémère jamais persisté** | zcrud_study |
| su-10 | **Critère de succès n°2** : parcours assemblé sélecteur→swiper→carte→célébration dans `example/` | example |
| su-11 | Gabarit PDF (bytes in/out) + port rasterisation LaTeX + **paquet neuf `zcrud_export_ui`** (`printing ^5.15.0` confiné) | zcrud_export(+_ui) |
| su-12 | Édition mindmap riche + `ZMindmapGenerationPort` aligné | zcrud_mindmap |

**Vérité de clôture (rejouée par l'orchestrateur)** : `melos run analyze` RC=0 · `melos run verify` RC=0 (10 gates). Bump Syncfusion 32→34 + `printing 5.15` (**CVE-2024-4367 corrigé**), **zéro rupture d'API**. Graphe : 55 arêtes (paquet neuf), **ACYCLIQUE**, **CORE OUT=0**.

---

## 2. Métriques de qualité (findings du code-review adversarial)

Chaque défaut ci-dessous a **échappé à une suite verte** et n'a été démasqué que par la revue multi-agent à lentilles.

| Story | HIGH | MAJEUR | MEDIUM | Signature dominante |
|---|---|---|---|---|
| su-1 | 2 | 2 | 3 | gardes ne couvrant qu'un package/aveugles au multi-lignes ; 2ᵉ source de vérité `clamp` en dur |
| su-2 | 2 | 3 | 9 | **révélation MORTE** sur chemin documenté ; canal a11y non-coloré désignant le **mauvais choix** ; 5 gardes infalsifiables (328/328 verts) |
| su-3 | — | 4+1R3 | 8+2R3 | carte changée en vol ; soumission ré-entrante 2 chemins/3 ; `didUpdateWidget` absent (minuteur figé) |
| su-4 | 2 | 4 | 2 | **crash `RangeError`** chemin nominal ; **bouton « précédent » qui AVANCE** (récidive du HIGH su-2) |
| su-5 | — | 2 | 5 | motif `Terminer\nTerminer` sur 3 tuiles ; garde falsifiable **par un commentaire** |
| su-6 | — | 3 | 4 | **deux gardes rendant des verdicts OPPOSÉS** ; dialog 240 lignes sans test (MAJEUR su-5 rétabli) |
| su-7 | 1 | 4 | 5 | **« -2 questions » affiché** ; `ExcludeSemantics` rendant 3 boutons inactivables pour lecteur d'écran |
| su-8 | 1 | 2 | 5 | **perte de données HIGH** : réordonner sous filtre effaçait l'ordre des cartes non visibles |
| su-9 | — | 2 | 3 | témoin comportemental infalsifiable ; fuite L10n FR en dur |
| su-10 | — | 1 | 4 | **perte SRS silencieuse** (moteur cyclique ↔ swiper linéaire) |

Tous les HIGH/MAJEUR corrigés ; MEDIUM corrigés par défaut (rares reports justifiés) ; 1 MAJEUR contraste (su-6 ÉCART-2) + 1 point AC9 (su-7 D2) laissés en **décision owner**.

---

## 3. Les 5 leçons clés (avec action concrète pour ME et au-delà)

### L1 — « La prose ment » : toute affirmation de dartdoc est un défaut jusqu'à preuve par grep (7+ récidives)
Vu partout : `clampQuality` « unique propriétaire » sans appelant ; « non commutatif » alors qu'il l'est (su-7) ; « ne tire pas Quill » sur une arête runtime dure (su-2 D10) ; test cité **inexistant** ; dartdoc auto-réfutante (su-3 D12). La prose **clôt l'enquête** du reviewer suivant — c'est son danger réel.
- **Action ME** : dans chaque code-review ME, une lentille dédiée **« réalité du code »** doit prouver par **grep négatif** chaque « unique/jamais/garanti par/testé par ». Aucune affirmation de garantie n'est acceptée sans son appelant/test nommé sur disque.

### L2 — Une garde/un test qui ne peut pas rougir ne protège rien (falsifiabilité R3 obligatoire)
Espion jamais branché (`expect(spy.calls, isEmpty)`), corpus rendant l'assertion vraie quel que soit le code (NFD su-8), branche jamais exercée, `takeException() isNull` seul, assertion comparée à une **constante du code**, coïncidence numérique `bodyMedium.color == onSurface` (su-1 D7). Aggravant su-5/su-6 : gardes **désarmées par un commentaire**, ou aveugles à `dart format`, ou dé-commentateur Dart (`//`) appliqué à du **YAML** (`#`).
- **Action ME** : tout test/garde porteur livré avec sa **contre-preuve mutante** (injecter la faute → obtenir le rouge), rejouée par l'orchestrateur. Motif de garde **ancré** (`^`, hors lignes de commentaire) + dé-commentateur du **bon langage**.

### L3 — Présence ≠ association (le canal a11y/le nombre doit être prouvé SUR le bon nœud)
Bouton « précédent » qui avance (su-4, vert car jamais tapé), marqueur a11y sur le mauvais choix (su-2 D2), nombre annoncé mais affiché nulle part (su-7 D1 « -2 »), verdict bégayé `label="correct\nBIEN"` (su-5/su-7). La leçon HIGH de su-2 s'est **propagée comme discipline** : `Semantics(value:)` prouvant l'action réelle, pas la présence du widget.
- **Action ME** : pour toute action de lot ME (Déplacer/Supprimer/sélectionner), le test asserte le **comportement observé** (élément réellement déplacé/supprimé) ET l'**annonce a11y sur le nœud qui porte le rôle** — jamais « le bouton existe ».

### L4 — Perte de données par voie non anticipée = catégorie HIGH systématique quand deux modèles divergent
su-8 (réordonner sous filtre efface l'ordre des cartes hors vue) et su-10 (note SRS sautée quand moteur cyclique et swiper linéaire divergent) sont la **même faille** : deux vues/curseurs sur une donnée, l'un écrase ce que l'autre ne voit pas.
- **Action ME critique** : ME écrit `zcrud_core`/`zcrud_list` avec sélection à **propriétaire unique** (AD-44) et cascade de suppression **awaited** (AD-21). Exiger un test explicite « l'état non-visible/non-sélectionné survit à l'opération de lot » et « la cascade n'orpheline rien ». C'est le risque n°1 de me-1/me-3.

### L5 — Ce qui a marché doit devenir procédure, pas exception
La revue **multi-agent à lentilles** est le **seul filet** qui a attrapé, sur des suites 100% vertes : un HIGH de perte de données, des fonctionnalités **mortes**, des tests infalsifiables. Ont aussi payé : la **vérification systématique sur disque** (jamais sur la foi d'un rapport d'agent), l'**extension des gardes existantes** plutôt que la duplication (su-6 D6, su-9 D5), et la **parallélisation des dev-story à packages disjoints** (A: flashcard/session ∥ B: export ∥ C: mindmap) avec **sérialisation des phases de test**.
- **Action ME** : ME étant **séquentiel** (écrit le cœur), reporter l'effort de parallélisation gagné vers **plus de lentilles** par story. Conserver le gate NON-NÉGOCIABLE `melos analyze` + `verify` **repo-wide** à chaque commit d'epic (rappel : `ZExportApi` supprimé en E11a resté RED plusieurs commits).

---

## 4. Action items → follow-up (dette consignée)

| # | Item | Origine | Priorité | Disposition |
|---|---|---|---|---|
| AI-SU-1 | `_sanitize` non-WinAnsi (caractères hors WinAnsi mal encodés dans le gabarit PDF) | su-11 | MEDIUM | **DW ouverte** — à traiter avant usage export non-latin |
| AI-SU-2 | Seau slot-label **write-only** (label riche posé mais jamais relu par un consommateur) | su-1/su-12 | LOW | consigné — solder quand un consommateur lit le slot |
| AI-SU-3 | Couplage `zcrud_study → zcrud_mindmap` limitant l'`example` | su-12 | MEDIUM | consigné — réévaluer au branchement `example` complet |
| AI-SU-4 | 2 tests `example` pré-cassés hérités de l'epic EX (`markdown_demo`, `offline_demo` — API évoluées) | EX (héritée) | MEDIUM | **dette portée** — hors périmètre SU, à solder dans un lot `example` dédié |
| AI-SU-5 | su-6 ÉCART-2 : contraste 1,23:1 | su-6 | MAJEUR | **décision owner ouverte** (hors dispositions auto) |
| AI-SU-6 | su-7 D2 : AC9 canal moteur (commutativité documentée+gardée) | su-7 | MAJEUR | **décision owner ouverte** (voie (c) appliquée) |

L'orchestrateur sérialise l'ajout de ces entrées dans `action_items` du sprint-status (statut `open`), ce document n'y touche pas.

---

## 5. Ce qui distingue cet epic

1. **Parallélisation réelle à 3 workstreams à packages disjoints** (flashcard/session ∥ export ∥ mindmap) — première application à grande échelle de la règle « 3 stories max, fichiers disjoints, seul point de contact `zcrud_core` », avec vérifs vertes **par package ciblé** pendant le dev actif et vérif globale au repos.
2. **La revue adversariale a payé de façon décisive** : sur 12 suites vertes, elle a extrait des HIGH de perte de données et de crash nominal, des fonctionnalités mortes, et une **famille entière** de tests infalsifiables — la couverture venant du **nombre de lentilles** (jusqu'à 7), pas de la finesse du découpage. Les leçons se sont **propagées** de story en story (HIGH su-2 → discipline « association » su-3/su-4/su-7).
3. **Bump transverse sans rupture** : Syncfusion 32→34 + `printing 5.15` corrigeant **CVE-2024-4367**, absorbé avec zéro rupture d'API et un **paquet neuf** (`zcrud_export_ui`) qui garde le graphe **acyclique / CORE OUT=0** — la discipline d'isolation des deps lourdes (AD-8/AD-42) a tenu sous ajout de 3 dépendances tierces (`flutter_card_swiper`, `confetti`, `printing`+`flutter_math_fork`).

---

## 6. Préparation de l'epic suivant (E-MULTI-EDIT)

**Découverte structurante — PAS de blocage, mais garde-fou majeur** : ME est le **seul epic qui écrit `zcrud_core`/`zcrud_list`**, en **séquentiel strict** (aucune parallélisation). Les leçons L3 (association) et surtout **L4 (perte de données)** sont directement en jeu : me-1 (sélection propriétaire-unique AD-44, cascade AD-21 awaited), me-2 (régime brouillon AD-43 : rien persisté avant commit unique), me-3 (suppression par lot, purge SRS, liste fonctionnelle sans sélection = zéro régression de su-8).

- Prérequis confirmés : su-2 (aperçu), su-8 (liste), su-9 (génération) sont `done` et stables → dépendances de me-1/me-2/me-3 satisfaites.
- Recommandation : porter l'effort de revue vers **plus de lentilles** (séquentiel = pas de parallélisme à exploiter), avec une lentille **perte-de-données** obligatoire sur chaque story ME, et rejouer `melos analyze`+`verify` **repo-wide** au commit d'epic.
- **Aucune mise à jour d'epic requise** : les découvertes SU renforcent le plan ME sans le contredire.
