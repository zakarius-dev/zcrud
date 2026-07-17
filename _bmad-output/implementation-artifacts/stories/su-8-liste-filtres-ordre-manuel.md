---
baseline_commit: 9ed81259f2d386e2596a8b8552231768f95bf110
---

# Story SU-8 : Liste de flashcards, filtres et ordre manuel

Status: review

<!-- Source : epics-zcrud-study-ui-2026-07-16/epics.md § Story 1.8 (Epic 1 E-STUDY-UI) -->

## Story

As an **utilisateur**,
I want **retrouver, trier et organiser mes flashcards**,
so that **je gère mon dossier sans quitter zcrud**.

**Couvre :** FR-SU14, FR-SU21 (duplication) · **Taille :** XL · **Dépend de :** su-7 (livrée)

---

## 🔴 Décisions tranchées AVANT dev (mode non-interactif — option la plus conservatrice)

Ces sept points ont été tranchés sur la **réalité du disque**, pas sur la prose. Chaque
verdict porte sa preuve. **Deux prémisses de la consigne d'entrée se sont révélées FAUSSES** —
elles sont corrigées ici, pas propagées.

### D1 — Le widget vit dans `zcrud_study`, PAS dans `zcrud_flashcard` (sinon CYCLE)

`ZFlashcardListView` a besoin de `zReorderIds` pour l'ordre manuel. Or :

```
$ grep -rln "zReorderIds" packages/ --include='*.dart'
packages/zcrud_study/lib/src/presentation/z_reorder_ids.dart   ← il vit dans zcrud_study
$ grep -q 'zcrud_flashcard' packages/zcrud_study/pubspec.yaml ; echo $?
0                                                              ← zcrud_study → zcrud_flashcard
```

⇒ Héberger la vue dans `zcrud_flashcard` exigerait `zcrud_flashcard → zcrud_study` : **cycle**,
violation AD-1. Et dupliquer `zReorderIds` est interdit (seconde voie).

`zcrud_study` est par ailleurs le **foyer déjà constitué** de tout ce dont la story a besoin —
vérifié sur disque : `z_reorder_ids.dart`, `z_item_actions_menu.dart` (patron AD-44 « action
absente si non fournie »), `z_tag_chips.dart`, `z_sectioned_study_layout.dart` (qui **fait déjà**
drag + `ReorderableListView.builder` + `zReorderIds`), `z_study_tools_section_spec.dart` (qui
**documente déjà** le patron `applyTo` → `zReorderIds` → `copyWith(sectionOrders:)`).

**Corroboration décisive** : la garde `z_section_key_single_composition_test.dart` (su-1) couvre
**déjà** `../zcrud_study/lib` et dit explicitement que ce package est « **le vrai lieu du
risque** » de composition de clés. Les auteurs de su-1 avaient anticipé ce placement.

⇒ **Verdict : `zcrud_study/lib/src/presentation/z_flashcard_list_view.dart`.**

### D2 — Arête NOUVELLE `zcrud_study → zcrud_responsive` (nécessaire, acyclique)

```
$ grep -q 'zcrud_responsive' packages/zcrud_study/pubspec.yaml ; echo $?
1                                            ← ABSENT (preuve d'absence, grep -q sans pipe)
$ grep -rln 'zcrud_responsive' packages/*/pubspec.yaml
packages/zcrud_navigation/pubspec.yaml
packages/zcrud_get/pubspec.yaml              ← aucun package de la chaîne study/session
```

`ZAdaptiveGrid` vit dans `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:39`
et **aucun** package de la chaîne study/session ne l'atteint. L'AC de l'epic l'exige
(« jamais une grille réécrite ») ⇒ l'arête est **nécessaire**, exactement comme su-6 a dû créer
`zcrud_session → zcrud_ui_kit` pour `ZToaster`.

`zcrud_responsive` ne dépend que de `zcrud_core` ⇒ **acyclique, CORE OUT reste 0**.
Graphe : **53 → 54 arêtes**. Mettre à jour toute garde de graphe qui compte les arêtes.

### D3 — 🔴 `ZAdaptiveGrid` prend `children:` (EAGER) : les deux ACs de l'epic sont EN TENSION

**C'est le piège structurant de cette story.** L'epic exige *dans le même AC* :
« responsive via `ZAdaptiveGrid` » **ET** « la liste est **virtualisée** (`.builder`, NFR-SU9) ».
Or, lu sur disque (`z_adaptive_grid.dart:44-52, 88-140`) :

```dart
const ZAdaptiveGrid({ required this.children, ... });   // List<Widget> — EAGER
final List<Widget> children;
// build : GridView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
//                          itemCount: children.length, ...)
```

`ZAdaptiveGrid` est **lazy au rendu** mais **eager à la construction** : l'appelant doit
matérialiser **tous** les `Widget` d'abord. Avec `shrinkWrap: true` +
`NeverScrollableScrollPhysics`, la grille **layoute tout** (aucun culling de viewport). Sur
**des milliers** de cartes ⇒ des milliers de widgets construits **à chaque frappe** de recherche.
Les deux ACs sont donc **conformes mais incompatibles** en l'état.

⇒ **Verdict : ajouter un constructeur `ZAdaptiveGrid.builder` à `zcrud_responsive`**
(`itemCount` + `itemBuilder`, **sans** `shrinkWrap`, scrollable, `GridView.builder` natif),
**réutilisant le MÊME `computeCrossAxisCount`**. C'est additif, non-breaking, et « jamais une
grille réécrite » reste **vrai** (même primitive de colonnes, même widget).
Écrire dans `zcrud_responsive` est **autorisé** : le sprint-status ne réserve à l'epic ME que
`zcrud_core`/`zcrud_list`.

- ⛔ **Rejeté** : réécrire une grille dans `zcrud_study` (viole l'AC).
- ⛔ **Rejeté** : garder `children:` (viole NFR-SU9 — le défaut exact d'IFFD, cf. D7).
- ✅ `ZAdaptiveGrid` existant **inchangé** (aucune régression sur ses consommateurs).

### D4 — su-6 : les filtres NE SONT PAS câblés, et su-8 n'en est PAS le consommateur légitime

Prémisse d'entrée à corriger : `zApplyTestFilters` **est** référencé dans `zcrud_session`, mais
uniquement en **dartdoc** expliquant pourquoi il n'est **pas** câblé
(`z_list_session_view.dart:152-157`, `z_test_filters_dialog.dart:4-8`). Non câblé : **confirmé**.

Mais su-8 n'en est pas pour autant le consommateur. Lu sur disque
(`z_flashcard_filters.dart:120-224`), `zApplyTestFilters` est une fonction de **tirage de
session** :

| Ce que porte `zApplyTestFilters` | Effet sur une liste de gestion |
|---|---|
| `questionCount` **défaut 10** + tirage aléatoire | un dossier de 2 000 cartes n'en afficherait **10** |
| `required Random random` | une liste de gestion **non déterministe** |
| `required Map<String, ZRepetitionInfo> srsById` | impose le SRS à une surface de consultation |
| `masteryLevels` | **hors** FR-SU14 |

⇒ **Verdict : su-8 NE câble PAS `zApplyTestFilters`.** Le câbler transformerait la liste en
tirage — un défaut fonctionnel majeur. Son consommateur légitime reste la construction de
session/examen (su-6 produit déjà le value object ; l'app le passe au sélecteur).

**MAIS — « un filtre, une source » est NON-NÉGOCIABLE** (règle posée par `z_flashcard_filters.dart:1-21`
lui-même). Vérifié sur disque, `ZStudySessionSelector.matches` (`z_study_session_selector.dart:46-88`)
implémente **exactement** ce dont FR-SU14 a besoin :

```dart
bool matches(c) => _matchesFolder(c) && _matchesTags(c) && _matchesTypes(c);
// _matchesFolder : candidate.folderId == folderId || candidate.subFolderId == folderId  → sous-dossier ✓
// _matchesTags   : for (tag in candidate.tagIds) if (tagIds.contains(tag)) return true;  → OU composable ✓
```

⇒ su-8 **DÉLÈGUE** sous-dossier ∧ tags(OU) ∧ types à `selector.matches` — **jamais réécrits** —
exactement comme `zApplyTestFilters`. `matches` (prédicat) et **jamais** `selectFrom` (qui
appliquerait son plafond `config.count`). su-8 n'ajoute **que** ce que le kernel ignore :
**recherche texte normalisée** + **`kind` de source**.

### D5 — 🔴 `zFoldDiacritics` EXISTE : su-8 le CONSOMME, ne le réinvente pas

```
$ grep -rn "zFoldDiacritics" packages/zcrud_core/lib/src/domain/data/z_search_text.dart
78:String zFoldDiacritics(String input)      ← la table de repli EXISTE déjà
```

Le « nid à bugs » de la normalisation est **déjà largement traité** dans `zcrud_core`
(`z_search_text.dart`) : casse, `é/è/ê/ë`, `ç`, **`œ→oe`**, **`æ→ae`**, **`ß→ss`**, **`ı→i`**
(turc), chaîne vide, idempotence. `zcrud_flashcard → zcrud_core` existe ⇒ **atteignable**.
Réimplémenter une seconde table serait le péché de la « 2e entité », en version texte.

**Deux manques réels, documentés par le fichier lui-même :**
1. **L-2 (NFD)** : `zFoldDiacritics` ne replie **que** le précomposé (NFC). `e`+U+0301
   (combinant) **subsiste**. Le fichier propose lui-même le remède « sans dépendance » :
   stripper U+0300–U+036F avant consultation de la table.
2. **Les espaces** : l'AC exige « normalise accents **et espaces** » — `zFoldDiacritics` ne
   normalise **aucun** espace.

⇒ **Verdict** : su-8 livre `zFlashcardSearchText(String)` dans `zcrud_flashcard`, qui
(1) **strippe les marques combinantes U+0300–U+036F**, (2) **DÉLÈGUE** à `zFoldDiacritics`
(jamais de seconde table), (3) **replie les espaces** (trim + runs d'espaces → un seul).
La table reste **unique** dans `zcrud_core` — non modifié (réservé à l'epic ME).
Une garde interdit toute seconde table de repli dans `zcrud_flashcard`.

### D6 — Ce que la duplication copie EXACTEMENT (AD-45)

`ZFlashcard` (`z_flashcard.dart:66-215`) — champ par champ, sans trou :

| Copié | Champ | Pourquoi |
|---|---|---|
| ✅ | `question`, `answer`, `isTrue`, `choices`, `explanation`, `hint`, `type` | **le contenu** — c'est l'objet de la duplication |
| ✅ | `tagIds` | classement **du contenu**, pas un état perso (`ZFlashcardTag` est une entité partagée) |
| ✅ | `folderId`, `subFolderId` | la copie naît **là où on l'a dupliquée** |
| ✅ | `source` | **provenance factuelle du contenu copié** — pas un état personnel (AD-45 ne bannit que SRS + ordre). L'origine reste vraie. |
| ✅ | `extension`, `extra` | slots AD-4 : les perdre serait une perte muette |
| 🚫 | **`id` → `null`** | **éphémère** (AD-45/AD-43) : sans id, ne franchit la frontière que par le commit de l'appelant |
| 🚫 | **`isReadOnly` → `false`** | AD-45 : « remis à faux » — sinon la copie serait aussi ineditable, la fonction serait morte |
| 🚫 | **`createdAt`/`updatedAt` → `null`** | ce sont les dates de l'**original** : les copier **mentirait** sur la provenance. Le commit les assignera. |
| 🚫 | **état SRS (`ZRepetitionInfo`)** | AD-45. **Par construction** : le SRS n'est **pas** dans `ZFlashcard` (entité séparée, clé `flashcardId`) — et une copie sans id **ne peut pas** être jointe. À **prouver**, pas à supposer. |
| 🚫 | **ordre (`ZFolderContentsOrder`)** | AD-45. Idem : l'ordre est une entité séparée indexant des **ids** ; `id == null` ⇒ inatteignable. |

⇒ `zDuplicateFlashcardForEditing(ZFlashcard) → ZFlashcard` : fonction **PURE**, dans
`zcrud_flashcard/lib/src/domain/`. **L'original n'est JAMAIS muté** (AD-45).

### D7 — Sans sélection multiple, et ce qu'IFFD faisait de travers

FR-SU19 (sélection multiple) appartient à **me-3**. su-8 est **complète sans elle** et
**ne précâble RIEN** : aucun `selectionController`, aucun paramètre « en prévision de », aucun
champ mort. me-3 **branchera** le contrôleur de me-1 sans régression.

Best-of-breed IFFD (`folder_flashcards_list_page.dart` ~1080 l., **LECTURE SEULE**) — ce qu'on
reprend et ce qu'on **corrige** :

| IFFD | su-8 |
|---|---|
| `GridView.count` responsive (≥300-350 px) | ✅ `ZAdaptiveGrid.builder` — **virtualisé** (D3) |
| Recherche **sur la question seule** | ✅ question **+ réponse/choix + tags** (AC epic) |
| Normalisation accents/espaces | ✅ `zFlashcardSearchText` (D5) |
| Filtres tags / sources | ✅ délégués `selector.matches` + `kind` registre (D4) |
| Ordre manuel | ❌ **absent d'IFFD** — apporté par AD-38 |
| `FlashcardCard` compacte | ✅ question tronquée, badge type, tags, source, aperçu réponse en grille |

---

## Acceptance Criteria

**AC1 — Grille responsive virtualisée (FR-SU14, NFR-SU9, D3).** `ZFlashcardListView` dispose ses
cartes via **`ZAdaptiveGrid.builder`** (`zcrud_responsive`) — jamais une grille réécrite, jamais
`children:`/`GridView.count`. Le nombre de colonnes vient de `computeCrossAxisCount` (mesure
**locale**, `LayoutBuilder`). **Aucune** carte hors viewport n'est construite.

**AC2 — `ZAdaptiveGrid.builder` (zcrud_responsive, additif).** Nouveau constructeur nommé :
`itemCount` + `itemBuilder`, **sans** `shrinkWrap`, scrollable, réutilisant `computeCrossAxisCount`
**et** la garde vide (`itemCount == 0 → SizedBox.shrink()`) et les replis défensifs AD-10 du
`ZAdaptiveGrid` existant. Le constructeur `children:` existant est **inchangé** (zéro régression).

**AC3 — Carte compacte (FR-SU14).** Chaque tuile montre : **question tronquée**, **badge de type**,
**tags**, **source**, et — **en grille** — un **aperçu de la réponse**. Contenu rendu via le slot
injectable (AD-40) dont le **défaut est du texte brut thématisé** ; aucun rendu riche en dur.

**AC4 — Recherche normalisée (FR-SU14, D5).** `zFlashcardSearchText` : strippe U+0300–U+036F,
**délègue** à `zFoldDiacritics` (`zcrud_core`), replie les espaces. **Fonction PURE**, testable
hors widget. Chercher « **eleve** » trouve « **élève** » — en NFC **et en NFD**.

**AC5 — Champs cherchés, configurables (FR-SU14).** La recherche porte sur **question + réponse
(ou contenu des `choices`) + tags**, **champs configurables** par un **enum** de champs
(`Set<ZFlashcardSearchField>` — jamais des booléens). Défaut : les trois.

**AC6 — Filtres délégués, jamais réécrits (FR-SU14, AD-4, D4).** Sous-dossier ∧ tags (**OU**
composables) ∧ types ⇒ **`ZStudySessionSelector.matches`** (jamais `selectFrom` : son plafond
`config.count` tronquerait la liste). su-8 n'ajoute que **recherche** + **`kind` de source**, dont
les types viennent du **registre** ouvert (AD-4) — jamais une enum fermée. Le prédicat de source
est **factorisé** et **partagé** avec `zApplyTestFilters` (une seule implémentation).

**AC7 — Aucun tirage, aucun aléa (D4).** `zApplyBrowseFilters` est **pure et déterministe** :
ni `Random`, ni `questionCount`, ni troncature. Combinés, les filtres donnent un résultat
**cohérent** ; aucun filtre ne retenant rien ⇒ **liste vide**, jamais de throw (AD-10).

**AC8 — Tris date / titre / ordre manuel (FR-SU14).** Le mode de tri est un **enum**
(`ZFlashcardSortMode { dateDesc, dateAsc, title, manual }`). Tri **stable** et **total** (AD-10) :
`createdAt` null → position déterministe, jamais de throw.

**AC9 — 🔴 Ordre manuel : entités EXISTANTES, aucune 2e entité (AD-38).** L'ordre manuel provient
**exclusivement** de `ZFolderContentsOrder` + `applyOrder<T>` (`zcrud_study_kernel`, **existants**).
**Aucune nouvelle entité, aucun nouveau `kind` persisté, aucun champ `position` inline.**

**AC10 — 🔴 `sectionKey` : constructeur canonique, clé nue VERBATIM (AD-38, RISQUE DE DONNÉES).**
La clé passe **toujours** par `zSectionKey(contentType: 'flashcards', subfolderId: …)` — en
**lecture COMME en écriture**, jamais composée à la main. La clé nue reste **VERBATIM
`'flashcards'`** (jamais `'flashcards/'`, jamais `'section:flashcards'`). `applyOrder` étant
**TOTAL**, toute dérive **orphelinerait l'ordre persisté en silence, sans erreur ni test rouge**.

**AC11 — 🔴 Drag ET boutons = MÊME voie d'écriture (AD-38).** Le drag et les boutons
Monter/Descendre (a11y) aboutissent à **une seule** fonction de réordonnancement, qui délègue à
**`zReorderIds`** puis persiste via **`ZFolderContentsOrder.copyWith(sectionOrders:)`**. **Aucune
seconde voie.** Les boutons sont de **vrais** contrôles a11y (≥ 48 dp, `Semantics`), pas un décor.

**AC12 — Ordre stable, nouveaux appendés, orphelins ignorés (AD-38).** Nouveaux éléments
**appendés de façon stable** (`ZUnorderedPlacement.end`) ; ids d'ordre sans carte **ignorés**.
Un ordre **périmé** (cartes supprimées **et** ajoutées) reste **cohérent et sans throw**.

**AC13 — Duplication (FR-SU21, AD-45, D6).** « Dupliquer pour modifier » →
`zDuplicateFlashcardForEditing` : copie **éphémère** (`id: null`, `isReadOnly: false`,
`createdAt`/`updatedAt` `null`, **aucun état personnel** — ni SRS ni ordre). **L'original n'est
jamais muté.**

**AC14 — Aperçu en lecture seule via `ZFlashcardReviewCard` (AD-45).** Une carte `isReadOnly`
s'ouvre en **aperçu** rendu par **`ZFlashcardReviewCard`** (su-2) — **jamais un rendu parallèle** —
avec `onEdit: null` **et** `onDelete: null` ⇒ actions **ABSENTES**, **jamais grisées**.

**AC15 — Actions par item déclarées (AD-44).** Les actions passent par **`ZItemActionsMenu`**
(existant) : `onSelected == null ⇒ action ABSENTE`. `ZItemActionKind` gagne **`duplicate`**
(additif — **aucun `switch` sur cet enum n'existe dans le repo**, grep négatif ⇒ non-breaking).

**AC16 — « Générer avec l'IA » absente si aucun port (FR-SU14).** Sans port de génération injecté,
l'option est **ABSENTE** (jamais grisée) ; la **saisie manuelle reste disponible**. su-8 ne livre
**aucun** flux de génération (**su-9**).
⚠️ **Ne PAS réinventer un drapeau de fonctionnalité** : `ZFeatureAvailability` **EXISTE**
(`zcrud_study/.../z_feature_availability.dart`, ES-5.4/AD-25) et est **exactement** ce mécanisme —
interface **injectable**, `featureKey` **`String` opaque**, injectée par `ZFeatureAvailabilityScope`
(`InheritedWidget` pur) **ou par paramètre**. Elle **n'introduit aucun chemin de rendu** : ses
`gate`/`enabledFor` **fabriquent le `null`** que `ZItemAction.onSelected` consomme **déjà**.
⇒ l'absence de l'option IA est obtenue **par composition** (`onSelected: null`), jamais par un
`if (kEnableAi)` ni un booléen local.

**AC17 — Fonctionne SANS sélection multiple (D7).** Consultation, recherche, tris, filtres,
actions par item : **tout marche sans FR-SU19**. **Aucun** précâblage de sélection, **aucun**
champ mort. Prouvé par grep négatif.

**AC18 — SM-1 : taper ne reconstruit QUE le champ (objectif produit n°1).** Taper **100
caractères** dans la recherche : **zéro perte de focus**, et la **sonde de comptage** prouve que
la liste **ne se reconstruit pas** à chaque frappe (débounce + `ValueListenable` ciblée). Preuve
par **compteur**, jamais par opinion.
**Aucune primitive de débounce générique n'existe** (`grep -rn "class ZDebounc\|zDebounce"` ⇒
**RC=1**, aucun résultat ; les seuls porteurs de débounce sont les `ZSyncOrchestrator`, hors
sujet). ⇒ le débounce est **local à la vue**, sur le patron **déjà établi par su-3**
(`zcrud_session/.../z_flashcard_answer_input.dart`, `Timer` local) : **l'imiter**, ne pas inventer
une abstraction transverse, et **disposer le `Timer`** au démontage.

**AC19 — Robustesse, jamais de throw (AD-10).** Dossier **vide** · **1 seule** carte · **des
milliers** · recherche ne retenant **rien** · ordre **périmé** · **clé de section inconnue** ·
tags **vides/dupliqués** · `byQuality` **corrompu** · qualité **hors échelle** ⇒ tous rendus sans
exception.

**AC20 — A11y / RTL / l10n / thème (AD-13).** `Semantics` explicites, cibles **≥ 48 dp**,
variantes **directionnelles** uniquement, **Reduce Motion** respecté. **Aucun libellé ni couleur
codé en dur** : labels **injectés** (patron `ZItemActionsMenu`), thème via `ZcrudTheme.of` (repli
`Theme.of`). Contraste **≥ 4,5:1** (WCAG AA) mesuré en clair **et** sombre.

**AC21 — Échelle de qualité : jamais redéclarée (AD-46).** Si un badge de maîtrise est affiché, il
**dérive** de `ZSrsConfig` (`config.clampQuality` **unique voie**, `masteredThreshold` **getter
dérivé**). **Aucune** redéclaration de l'échelle ni du seuil.

**AC22 — Isolation des dépendances (AD-1).** Arête **nouvelle et unique** :
`zcrud_study → zcrud_responsive`. Graphe **ACYCLIQUE**, **CORE OUT = 0**, **54 arêtes**. Aucune
dépendance tierce nouvelle.

---

## Tasks / Subtasks

- [x] **T1 — `ZAdaptiveGrid.builder` (AC1, AC2)** · `zcrud_responsive`
  - [x] Constructeur nommé `.builder({required itemCount, required itemBuilder, ...})` ; champs
        `children`/`itemCount` mutuellement exclusifs, **`computeCrossAxisCount` réutilisé**.
  - [x] Garde vide + replis AD-10 (`itemWidth`/`ratio` non finis) **partagés**, jamais dupliqués.
  - [x] Tests : lazy prouvée (**une sonde compte les `itemBuilder` appelés** ≪ `itemCount` sur
        1 000 items) ; colonnes identiques aux deux ctors ; ctor `children:` **non régressé**.

- [x] **T2 — Normalisation de recherche (AC4, D5)** · `zcrud_flashcard/lib/src/domain/`
  - [x] `zFlashcardSearchText` : strip U+0300–U+036F → **délègue `zFoldDiacritics`** → replie les
        espaces. Pure, totale, **idempotente**.
  - [x] Tests aux bornes : `élève`/`eleve` **NFC et NFD** · `ç` · `œ` · `æ` · `ß` · turc `İ`/`ı` ·
        **chaîne vide** · espaces multiples/insécables · **emoji** (préservé, jamais de crash) ·
        idempotence.
  - [x] **Garde** : aucune seconde table de repli dans `zcrud_flashcard` (grep de source).

- [x] **T3 — Filtres de consultation (AC5, AC6, AC7)** · `z_flashcard_filters.dart` (étendu)
  - [x] `enum ZFlashcardSearchField { question, answer, tags }` ; `ZFlashcardBrowseFilters`
        (immuable, `==`/`hashCode`) ; `zApplyBrowseFilters(...)` **pure**, prenant `selector`.
  - [x] **Extraire** le prédicat de `kind` de source et le **partager** avec `zApplyTestFilters`
        (une seule implémentation — sinon deux sources du même filtre).
  - [x] Tests : OU sur tags · sous-dossier · types · sources · combinaisons · résultat vide ·
        **aucun `Random`/`questionCount`** dans la signature (garde de source).

- [x] **T4 — Duplication (AC13, D6)** · `zcrud_flashcard/lib/src/domain/`
  - [x] `zDuplicateFlashcardForEditing` — pure.
  - [x] Tests **champ par champ** (le tableau D6 en entier — un défaut est un **MOTIF**, pas une
        anomalie isolée) : copiés ✓ ; `id`/`createdAt`/`updatedAt` **null** ; `isReadOnly` **false** ;
        **original inchangé** (`==` avant/après) ; **SRS non copié prouvé** (un `ZRepetitionInfo`
        de l'original n'est **pas** joignable à la copie) ; **ordre non copié prouvé**
        (`orderFor(zSectionKey(...))` ne contient pas la copie).

- [x] **T5 — Ordre manuel : la MÊME voie (AC9-AC12)** · `zcrud_study`
  - [x] **Une seule** fonction de réordonnancement → `zReorderIds` → `copyWith(sectionOrders:)`.
        Drag (`ReorderableListView.builder`, patron `z_sectioned_study_layout.dart`) **et** boutons
        Monter/Descendre **l'appellent tous deux**.
  - [x] Clé **uniquement** via `zSectionKey(contentType: 'flashcards', subfolderId: …)`.
  - [x] **Rétro-compat bout-en-bout** — **imiter** `z_section_key_test.dart:42-72`, ne pas le
        dupliquer : `fromMap({'section_orders': {'flashcards': ['c2','c1']}})` →
        `orderFor(zSectionKey(contentType:'flashcards'))` → `applyOrder` **réellement appliqué**
        (assérer **l'ordre rendu**, pas seulement la clé).
  - [x] **Garde « une seule voie »** : rougit si une **seconde** voie apparaît — aucun
        `sectionOrders:` / `zReorderIds` hors de la fonction unique (scan de source, hors dartdoc).
  - [x] Boutons **ACTIONNÉS** dans le test (su-4 : un « précédent » qui **avançait**, vert car
        jamais tapé) : Monter **remonte** — et **Descendre descend** ; le **1er** ne remonte pas,
        le **dernier** ne descend pas ; drag et boutons ⇒ **ordre persisté identique**.

- [x] **T6 — `ZFlashcardListView` (AC1, AC3, AC8, AC14-AC17, AC20, AC21)** · `zcrud_study`
  - [x] `pubspec.yaml` : `zcrud_responsive: ^0.2.1` (**seule** arête nouvelle) ; barrel mis à jour.
  - [x] Tuile compacte (AC3) ; slot de rendu AD-40 (défaut **texte brut thématisé**).
  - [x] `enum ZFlashcardSortMode` ; aperçu `isReadOnly` via **`ZFlashcardReviewCard`**
        (`onEdit: null`, `onDelete: null`) ; `ZItemActionKind.duplicate` ; IA **absente** sans port
        **via `ZFeatureAvailability` existant** (`onSelected: null`) — jamais un booléen local.
  - [x] Débounce **local** de la recherche sur le patron su-3 (`z_flashcard_answer_input.dart`) ;
        `Timer` **disposé** au démontage.
  - [x] **Aucun** `setState` de liste ; controllers **stables** ; `ValueKey(card.id)`.

- [x] **T7 — SM-1 (AC18)** · imiter `z_list_session_view_sm1_test.dart` / `z_study_tools_rebuild_test.dart`
  - [x] **Sonde de comptage** de rebuilds de la liste + du champ ; taper **100 caractères** ⇒
        rebuilds de liste **bornés** (débounce), rebuilds du champ **seuls** ; **focus conservé**.
  - [x] **Injection R3** : supprimer le débounce/la granularité ⇒ le test **ROUGIT par le
        COMPORTEMENT** (compteur), pas par une erreur de compilation.

- [x] **T8 — Gardes de package (AC20, AC22)** · `zcrud_study/test/`
  - [x] ⚠️ **Prémisse d'entrée CORRIGÉE** : les gardes `z_widgets_purity_test.dart` /
        `z_widgets_hardcode_scan_test.dart` **n'existent QUE dans `zcrud_session`**
        (`find packages -name … | sort` ⇒ 2 fichiers, tous deux `zcrud_session`), et scannent
        `Directory('lib/src/presentation')` **de leur propre package**. Elles **ne peuvent pas**
        couvrir `zcrud_study`. Les **créer** ici est une **extension de couverture à un package
        non gardé**, pas une duplication.
  - [x] **Contraste WCAG** : la garde de su-6 vit dans
        `zcrud_session/test/presentation/z_session_mode_selector_test.dart:1502-1650` et énumère
        les **ÉCRANS**. `zcrud_session` **ne dépend pas** de `zcrud_study` ⇒ su-8 **ne peut pas
        s'y ajouter**. Créer la garde équivalente dans `zcrud_study`, **helper de mesure
        identique**, et y énumérer **TOUS** les écrans de su-8 (liste, aperçu, dialog de filtres,
        menu d'actions) × `Brightness.values` — **un écran non listé n'est JAMAIS mesuré**.
  - [x] **A11y** : énumérer **toutes** les tuiles/contrôles de su-8 (≥ 48 dp + `Semantics`) —
        su-6 avait **omis un dialog entier** ⇒ 4 tuiles non gardées, **4/4 défectueuses**.
        **Balayer tout le diff**, pas un échantillon.
  - [x] **Graphe** : mettre à jour le compte d'arêtes **53 → 54** ; ACYCLIQUE, CORE OUT = 0.
  - [x] `z_third_party_confinement_test.dart` : **sans objet** — aucune dep tierce nouvelle
        (`zcrud_responsive` est un package **zcrud**). Ne pas y toucher.

---

## Dev Notes

### Contrats réels vérifiés sur disque (ne pas re-supposer)

| Symbole | Fichier | Contrat **réel** |
|---|---|---|
| `zSectionKey` | `zcrud_study_kernel/.../z_section_key.dart:53` | `({required String contentType, String? subfolderId})`. `null` **ou vide** ⇒ `contentType` **VERBATIM**. Sinon `'<type>/<sub>'`. |
| `applyOrder<T>` | `.../apply_order.dart:41` | `(Iterable<T>, List<String>, {required String Function(T) idOf, ZUnorderedPlacement unordered = end})`. **Pure, totale, stable.** Ordre vide ⇒ entrée préservée ; id sans item **ignoré** ; doublon ⇒ **1re occurrence**. |
| `ZFolderContentsOrder` | `.../z_folder_contents_order.dart:129` | `{folderId, sectionOrders}` + `orderFor(key)`, `applyTo(key, items, idOf:)` (**délègue** `applyOrder`), `copyWith(sectionOrders:)`. `@ZcrudModel(kind: 'folder_contents_order')`. `sectionOrders` **profondément non modifiable**. |
| `zReorderIds` | `zcrud_study/.../z_reorder_ids.dart:28` | `(List<String>, int old, int new)`. Pure, **totale** (indices **clampés**). Convention : `removeAt` **puis** `insert` (ajustement `ReorderableListView` déjà fait en amont). |
| `ZAdaptiveGrid` | `zcrud_responsive/.../z_adaptive_grid.dart:39` | ⚠️ **`children: List<Widget>` EAGER**, `shrinkWrap: true`, `NeverScrollableScrollPhysics` — cf. **D3**. |
| `ZFlashcardReviewCard` | `zcrud_flashcard/.../z_flashcard_review_card.dart:82` | `{required card, revealTransition, contentBuilder, transitionDuration, onRevealChanged, onEdit, onDelete}` — `onEdit`/`onDelete` **null ⇒ absents**. |
| `ZItemActionsMenu` | `zcrud_study/.../z_item_actions_menu.dart` | `List<ZItemAction>`, labels/icônes **INJECTÉS**, `onSelected == null ⇒ ABSENTE`. |
| `ZFeatureAvailability` | `zcrud_study/.../z_feature_availability.dart` | Disponibilité **injectable** (`featureKey` opaque) ; `gate`/`enabledFor` **fabriquent le `null`** consommé par `onSelected`. **Aucun** chemin de rendu neuf ⇒ **AC16 par composition**. |
| `ZStudySessionSelector.matches` | `zcrud_study_kernel/.../z_study_session_selector.dart:46` | folder **∨ subFolder** ∧ tags (**OU**) ∧ types. **Prédicat pur, sans plafond** (`selectFrom` **le porte** — ne pas l'utiliser). |
| `zFoldDiacritics` | `zcrud_core/.../z_search_text.dart:78` | Casse + table Latin + `œ/æ/ß/ĳ` + `ı`. **Limite L-2 : NFD non replié.** Pas d'espaces. |
| `ZFlashcard` | `zcrud_flashcard/.../z_flashcard.dart:66` | `implements ZSessionCandidate` ⇒ **directement** consommable par `selector.matches`. |

### Discipline de preuve (R3) — non-négociable

- Chaque AC : **fichier réel** + **test porteur** + **injection R3** qui rougit **par le
  COMPORTEMENT**. Une injection qui casse la **compilation** rougit tout et ne prouve **RIEN**.
- **Toute ABSENCE se prouve par un grep négatif** (commande + RC dans le rapport).
  ⚠️ `grep … | head; echo $?` rend le RC de **`head`** ⇒ **`grep -q` sans pipe**.
  ⚠️ `$` est un métacaractère BRE ⇒ **`grep -qF`** pour tout symbole `$`/codegen.
  ⚠️ **zsh** : `--include=*.dart` **non quoté** est globbé et le grep échoue en silence
  (rencontré sur cette story) ⇒ **`--include='*.dart'`** ; un glob sans match **abandonne toute
  la commande** (`nomatch`) ⇒ préférer **`find`**.
- **`flutter test` depuis le PACKAGE** (gardes en `Directory('lib')` **relatif** ⇒ depuis la
  racine = **26 faux échecs**). 🚫 **Jamais `melos run test`** (parallélise, se bloque).
- 🚫 **Jamais `git checkout`** (su-1..su-7 **non committés** — un checkout les détruit).
  🚫 **Jamais `dart format`**.
- 🚫 **On ne modifie JAMAIS un test pour taire un défaut réel** (su-2 : débordement `RenderFlex`
  masqué ainsi).

### Défauts démasqués sur su-1..su-7 — à ne PAS reproduire

- **présence ≠ association** : un contrôle doit être **ACTIONNÉ** (su-4 : bouton « précédent »
  qui **avançait**, vert car jamais tapé) ⇒ **T5**.
- **un défaut est un MOTIF** : su-5 a corrigé 1 tuile sur 4 ; su-6 a **omis un dialog entier**.
  **Balayer tout le diff** ⇒ **T4, T8**.
- **un test ne doit pas observer qu'UN canal** (su-6 : un nombre visible **nulle part**, annoncé
  au lecteur d'écran, test **vert**) ⇒ assérer le **rendu** ET la **sémantique**.
- **`takeException() isNull` ne vérifie PAS la justesse** (su-7 : « **-2 questions sans
  réponse** » s'affichait, garde verte) ⇒ **AC19** assère le **contenu rendu**, pas l'absence de
  crash.
- **la prose ment** (5 récidives) : toute affirmation de dartdoc (« unique », « jamais »,
  « garanti par », un test cité) doit être **vraie sur disque**.
- **deux gardes ne doivent pas se contredire** (su-6 : l'une interdisait ce que l'autre
  bénissait) ⇒ la garde « une seule voie » (T5) doit tolérer les mentions en **dartdoc**
  (patron `z_section_key_single_composition_test.dart`).

### Frontières

su-8 = **liste + filtres + ordre manuel + duplication**. **PAS** de génération IA (**su-9**),
**PAS** de parcours example (**su-10**), **PAS** de sélection multiple ni de multi-édition
(**epic ME** : me-1/me-2/me-3). `zcrud_core`/`zcrud_list` : **INTERDITS EN ÉCRITURE** (réservés
à l'epic ME) — d'où **D5** (la limite NFD est contournée **chez le consommateur**, pas dans
`zcrud_core`).

`/home/zakarius/DEV/iffd` et `lex_ui` = **LECTURE SEULE**.

### Vérif verte (à rejouer réellement, depuis chaque package)

```
melos run generate      # ZItemActionKind.duplicate ⇒ regénérer ; committer les *.g.dart
cd packages/zcrud_responsive && flutter test      # + ZAdaptiveGrid.builder
cd packages/zcrud_flashcard  && flutter test      # baseline 464
cd packages/zcrud_study      && flutter test      # baseline 201 (mesurée : « +201 All tests passed! »)
cd packages/zcrud_study_kernel && flutter test    # baseline 361 (garde composition unique)
melos run analyze && melos run verify             # REPO-WIDE au gate de commit d'epic
```

Référence repo : **23/23, 4313 tests** — `zcrud_session` **521**, `zcrud_flashcard` **464**,
`zcrud_study_kernel` **361**, **`zcrud_study` 201** (mesuré sur disque pour cette story).

### Project Structure Notes

| Fichier | Statut |
|---|---|
| `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart` | **UPDATE** — ctor `.builder` additif |
| `packages/zcrud_flashcard/lib/src/domain/z_flashcard_search_text.dart` | **NEW** |
| `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart` | **UPDATE** — browse filters + prédicat de source factorisé |
| `packages/zcrud_flashcard/lib/src/domain/z_flashcard_duplicate.dart` | **NEW** |
| `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` | **UPDATE** — barrel |
| `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart` | **NEW** |
| `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart` | **UPDATE** — `duplicate` |
| `packages/zcrud_study/lib/zcrud_study.dart` | **UPDATE** — barrel |
| `packages/zcrud_study/pubspec.yaml` | **UPDATE** — `zcrud_responsive` (**seule** arête nouvelle) |
| `packages/zcrud_study/test/**` | **NEW** — purity, hardcode scan, contraste, a11y, SM-1, ordre |

**Variance assumée (déclarée, pas subie)** : la story **écrit dans `zcrud_responsive`** (D3) — hors
du package d'accueil. Justifié : l'AC exige `ZAdaptiveGrid` **et** la virtualisation, inconciliables
sans le ctor `.builder` ; l'alternative (réécrire une grille) **viole** l'AC. `zcrud_responsive`
n'est réservé à aucun epic.

### References

- [Source: epics-zcrud-study-ui-2026-07-16/epics.md#Story 1.8] — spécification source
- [Source: ARCHITECTURE-SPINE.md#AD-38] — ordre manuel, `sectionKey`, **`applyOrder` TOTAL**
- [Source: ARCHITECTURE-SPINE.md#AD-45] — lecture seule, duplication, état perso jamais copié
- [Source: ARCHITECTURE-SPINE.md#AD-44] — actions déclarées, sélection possédée par la liste
- [Source: ARCHITECTURE-SPINE.md#AD-46] — échelle de qualité possédée par `ZSrsConfig`
- [Source: ARCHITECTURE-SPINE.md#AD-40] — slot de rendu injectable, défaut texte brut
- [Source: ARCHITECTURE-SPINE.md#AD-33] — sélection amont (pourquoi su-8 ne câble pas su-6)
- [Source: ARCHITECTURE-SPINE.md#AD-43] — frontière brouillon/persistance (liste = **directe**)
- [Source: architecture-zcrud-2026-07-09/architecture.md] — AD-1..32 hérités
- [Source: prd-zcrud-study-ui-2026-07-16/prd.md#FR-SU14, #FR-SU21, #NFR-SU9]
- [Source: docs/parity-study-ui-2026-07-16/annexes/iffd_flashcards.md#F9, #F10, #F5, #F6]
- [Source: CLAUDE.md] — invariants, gates, cycle BMAD

---

## Dev Agent Record

### Agent Model Used

`claude-opus-4-8[1m]` — skill `bmad-dev-story` (mode non-interactif).

### Debug Log References

**Vérif verte rejouée RÉELLEMENT sur disque** (jamais sur la foi d'un rapport) :

| Commande | RC | Résultat |
|---|---|---|
| `dart run melos run generate` | **0** | SUCCESS (aucun `.g.dart` neuf : su-8 n'ajoute aucun `@ZcrudModel`) |
| `dart run melos run analyze` (REPO-WIDE) | **0** | **0 error, 0 warning** |
| `dart run melos run verify` | **0** | 10 gates verts — **`total arêtes = 54`**, **`ACYCLIQUE OK`**, **`CORE OUT=0 OK`** |

**Tests par package, lancés DEPUIS le package** (jamais `melos run test`, qui se bloque ; jamais
depuis la racine — les gardes en `Directory('lib')` **relatif** y produisent des faux échecs) :

| Package | Avant | Après | Δ |
|---|---|---|---|
| `zcrud_responsive` | 99 | **107** | +8 |
| `zcrud_flashcard` | 464 | **536** | +72 |
| `zcrud_study` | 201 | **334** | +133 |
| `zcrud_study_kernel` | 361 | **361** | 0 (non touché) |
| `zcrud_session` | 521 | **521** | 0 (non régressé) |

#### Injections R3 jouées RÉELLEMENT (cassé → rouge **par le COMPORTEMENT** → restauré `cp` + SHA-256 vérifié)

Chaque rouge a été contrôlé **sans aucune ligne `Error:`/`Failed to load`** — une injection qui
casse la compilation rougit tout et ne prouve rien.

| # | Injection | Rouge causé par | Vérif |
|---|---|---|---|
| 1 | `.builder` matérialise en eager | compteur : **« 1000/1000 items construits »** | SHA OK |
| 2 | `shrinkWrap: !virtualized` → `true` | test structurel (contrat scrollable) | SHA OK |
| 3 | strip NFD supprimé | **3 tests** NFD (limite L-2 restaurée) | SHA OK |
| 4 | `matches` → `selectFrom` | **« tronqué à `config.count` = 10 »** | SHA OK |
| 5 | duplication : `id: card.id` | id + **preuve SRS** + **preuve ordre** (3 rouges) | SHA OK |
| 6 | duplication : `isReadOnly: card.isReadOnly` | 2 rouges | SHA OK |
| 7 | duplication : `createdAt: card.createdAt` | 2 rouges | SHA OK |
| 8 | `contentType` → `'section:flashcards'` | **rétro-compat AD-38** (6 rouges) | SHA OK |
| 9 | clé + `'/'` final (**dérive invisible à l'œil**) | rétro-compat **lecture ET écriture** | SHA OK |
| 10 | **débounce supprimé** | compteur : **« 1000 rebuilds PENDANT la frappe »** | SHA OK |
| 11 | controller recréé au build | **4 rouges** (dont saisie tronquée) | SHA OK |
| 12 | premier plan = couleur de FOND | **8 rouges** à **« 1,00:1 »** | SHA OK |
| 13 | `Semantics(label:)` dupliqué sur la tuile | **« Actual: <2> »** | SHA OK |
| 14 | `Semantics` du badge lecture seule retirée | test « deux canaux » | SHA OK |
| 15 | `excludeSemantics` retiré du menu | duplication d'annonce | SHA OK |
| 16 | `label:` retiré du menu | **mutité** d'annonce | SHA OK |

#### Défauts RÉELS trouvés et corrigés en cours de route (jamais un test modifié pour taire un défaut)

1. **🔴 `ZItemActionsMenu` (préexistant, ES-5.3) — chaque action annoncée DEUX FOIS.** Découvert
   en dumpant l'arbre sémantique : `label was "Ouvrir\nOuvrir"`. `PopupMenuItem` **fusionne** son
   sous-arbre ⇒ le `label:` du `Semantics` **et** le `Text(action.label)` s'additionnent. Corrigé
   par `excludeSemantics: true`. ⚠️ Retirer le `label:` **ne marche pas** (mesuré : le nœud
   devient **muet**) — le couple `label:` + `excludeSemantics:` est la **seule** combinaison juste.
   *Un défaut est un MOTIF* : le même défaut existait sur ma tuile (`_FlashcardTile`), corrigé aussi.
2. **🔴 Mon test SM-1 phare était infalsifiable.** Les 100 caractères aléatoires ne matchaient
   **aucune** carte ⇒ état vide ⇒ compteur à 0 **quel que soit** le débounce : l'injection #10 le
   laissait **vert**. Corrigé — les cartes contiennent désormais le texte tapé, et une assertion
   « le recalcul a BIEN eu lieu au repos » interdit qu'un « 0 rebuild » soit vrai d'une liste morte.
3. **🔴 Ma dartdoc mentait** (`_ZGridMetrics.resolve`, symbole **inexistant** — `grep -q 'class
   _ZGridMetrics'` ⇒ RC=1). Réécrite pour décrire le mécanisme réel.
4. **Ma garde de signature se contredisait** : elle scannait les commentaires du corps, qui
   expliquent légitimement pourquoi `selectFrom` est refusé. Commentaires exclus (patron
   `z_section_key_single_composition_test.dart`).
5. **Trou de test comblé** : le test « 2 000 cartes » ne pouvait **pas** attraper le passage à
   `selectFrom` (avec `count: null`, `selectFrom` rend tout). Ajout d'un test à `count: 10` —
   le seul qui rende les deux voies distinguables.
6. Ma garde d'aperçu bannissait `'Card('`… qui matche `ZFlashcardReviewCard(` : elle rougissait
   sur ce qu'elle exige. Ancrée sur `\b`.
7. Constante `_typed` : deux écritures « à peu près 100 » rejetées par la sonde `length == 100`.

### Completion Notes List

- **AC1-AC22 : tous couverts**, chacun par un fichier réel + un test porteur + (pour les ACs
  structurants) une injection R3 rougissant **par le comportement**.
- **AC2 — `ZAdaptiveGrid.builder` strictement ADDITIF** : le ctor `children:` est **inchangé**
  (garde de non-régression explicite : `shrinkWrap: true` + `NeverScrollableScrollPhysics`
  préservés). Les deux ctors partagent `computeCrossAxisCount`, la garde vide et les replis AD-10 :
  `build` est un **corps unique** paramétré par `virtualized` — jamais deux formules.
- **AC10 — clé `'flashcards'` VERBATIM** : verrouillée **dans les deux sens** (un ordre écrit
  avant su-8 est relu ET **réellement appliqué** ; ce que su-8 écrit est relisible par la clé
  historique **littérale** — jamais par notre propre constructeur, ce qui serait une tautologie).
- **AC14 — écart comblé en cours de route** : l'aperçu n'existait pas dans ma première passe.
  `ZFlashcardPreview` livré : il **compose** `ZFlashcardReviewCard` et ne rend **rien** lui-même
  (garde de source : aucun `Text(`/`Column(`/`Card(` ancré dans le fichier).
- **AC16 — par COMPOSITION** : `ZFeatureAvailability.gate` **existant** fabrique le `null` que
  `ZItemAction.onSelected` consomme déjà. Aucun booléen local, aucun `if (kEnableAi)`.
- **AC17 — prouvé par grep négatif** (commentaires exclus) : `grep -qE
  'selectionController|selectedIds|isSelected|onSelectionChanged|multiSelect|Checkbox'` ⇒ **RC=1**.
- **AC22 — 54ᵉ arête** : `zcrud_study → zcrud_responsive`, documentée dans le pubspec.
  `zcrud_responsive → [zcrud_core]` seulement ⇒ acyclique, **zéro dépendance tierce**.
- **`zcrud_core` / `zcrud_list` NON touchés** (réservés à l'epic ME) : `git status --porcelain` ⇒
  **vide**. D'où D5 : la limite NFD est contournée **chez le consommateur**.
- **`sprint-status.yaml` NON touché** (interdit) — mtime `12:21`, antérieur à toutes mes écritures.
- **Aucun commit** (interdit ; commit en fin d'epic).

#### Ce que je n'ai PAS fait — et pourquoi

- **Aucun `dart format`** (repo *short*, non format-gated — interdit par la consigne).
- **Aucun flux de génération IA** (**su-9**), **aucun parcours example** (**su-10**), **aucune
  sélection multiple** (**epic ME** / me-3) — hors frontières.
- **`z_third_party_confinement_test.dart` non touché** : sans objet (`zcrud_responsive` est un
  package **zcrud**, aucune dépendance tierce nouvelle).
- **Le repli `theme.labelColor ?? scheme.onSurfaceVariant` n'est pas couvert par un test** :
  `ZcrudTheme.fallback` définit **toujours** `labelColor`, donc la branche n'est atteinte que si
  une app injecte via `ZcrudScope` un `ZcrudTheme` partiel (`labelColor: null`). Repli défensif
  AD-10 **légitime et atteignable en production**, mais non exercé ici — **consigné, non prétendu**.
- **La garde de contraste ne mesure que les `RichText` peints** (helper identique à su-6) : une
  icône colorée n'est pas mesurée. Limite **héritée et déclarée**, non élargie par su-8.

### File List

**`zcrud_responsive`** (variance assumée, cf. D3 — écriture hors package d'accueil) :
- `packages/zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart` — **UPDATE** (ctor
  `.builder` additif ; ctor `children:` **inchangé**)
- `packages/zcrud_responsive/test/z_adaptive_grid_test.dart` — **UPDATE** (+8 tests)

**`zcrud_flashcard`** :
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_search_text.dart` — **NEW**
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_duplicate.dart` — **NEW**
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_sort.dart` — **NEW**
- `packages/zcrud_flashcard/lib/src/domain/z_flashcard_filters.dart` — **UPDATE** (browse filters
  + `zMatchesSourceKind` factorisé, **consommé** par `zApplyTestFilters`)
- `packages/zcrud_flashcard/lib/zcrud_flashcard.dart` — **UPDATE** (barrel)
- `packages/zcrud_flashcard/test/z_flashcard_search_text_test.dart` — **NEW**
- `packages/zcrud_flashcard/test/z_flashcard_search_single_fold_table_test.dart` — **NEW**
- `packages/zcrud_flashcard/test/z_flashcard_duplicate_test.dart` — **NEW**
- `packages/zcrud_flashcard/test/z_flashcard_browse_filters_test.dart` — **NEW**

**`zcrud_study`** :
- `packages/zcrud_study/lib/src/presentation/z_flashcard_list_view.dart` — **NEW**
- `packages/zcrud_study/lib/src/presentation/z_flashcard_preview.dart` — **NEW**
- `packages/zcrud_study/lib/src/presentation/z_flashcard_reorder.dart` — **NEW**
- `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart` — **UPDATE**
  (`ZItemActionKind.duplicate` + **correction a11y** `excludeSemantics`)
- `packages/zcrud_study/lib/zcrud_study.dart` — **UPDATE** (barrel)
- `packages/zcrud_study/pubspec.yaml` — **UPDATE** (`zcrud_responsive` — **seule** arête nouvelle)
- `packages/zcrud_study/test/presentation/z_flashcard_list_view_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_flashcard_list_view_sm1_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_flashcard_reorder_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_flashcard_reorder_single_path_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_flashcard_preview_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_flashcard_contrast_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_flashcard_a11y_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_widgets_purity_test.dart` — **NEW**
- `packages/zcrud_study/test/presentation/z_widgets_hardcode_scan_test.dart` — **NEW**

**Story** : `_bmad-output/implementation-artifacts/stories/su-8-liste-filtres-ordre-manuel.md`
(frontmatter `baseline_commit`, cases, Dev Agent Record, File List, Change Log, Status).

### Change Log

| Date | Étape | Détail |
|---|---|---|
| 2026-07-17 | `dev-story` | SU-8 implémentée : 8/8 tâches, 22/22 ACs. +213 tests (99→107, 464→536, 201→334). Graphe 53→54 arêtes (ACYCLIQUE, CORE OUT=0). 16 injections R3 jouées et restaurées (SHA-256 vérifiés). **3 défauts réels corrigés** : annonce a11y dupliquée de `ZItemActionsMenu` (préexistant ES-5.3) et de la tuile ; test SM-1 infalsifiable ; dartdoc mensongère. Statut → `review`. |
