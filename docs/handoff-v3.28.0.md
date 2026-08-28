# Handoff v3.28.0 — Vague 0 : les six manques qui bloquaient la réactivation des chaînes d'étude

> **Date** : 2026-08-28. **Portée** : `zcrud_flashcard`, `zcrud_session`, `zcrud_study_kernel`,
> `zcrud_study`, `zcrud_core`, `zcrud_screen`, `zcrud_document`. **Plan** : Partie III (réactiver
> toutes les chaînes d'étude du legacy IFFD, apparence alignée par défaut), Vague 0 + trois lots
> transverses de la Vague 2 avancés parce que sans dépendance.

## 1. Pourquoi cette vague

Le relevé du 26 août listait 21 « bloquants » ; la remesure du 28 en a retenu **six réels** (cinq
étaient livrés, trois faux, un à demi). Sans eux, une chaîne du legacy ne se réactive pas du tout :
un hôte ne pouvait ni restreindre une session aux cartes issues **d'un document précis** (B3), ni
rendre des choix de QCM en markdown/LaTeX ou observer la saisie (B4), ni éditer un rappel
**hebdomadaire** pourtant porté par l'entité (B5), ni typer le lien dossier → matière (B6). Les
deux autres — génération de carte mentale (B1) et résumé de note (B2), ports sans consommateur —
sont des assemblages dans `zcrud_study` et suivent en Vague 1 (le paquet n'admet qu'un rédacteur).

## 2. Ce que le socle livre

| Lot | Paquet | Livré |
|---|---|---|
| **P0-A** | `zcrud_flashcard` | `ZFlashcardTestFilters.sourceIds` et `ZFlashcardBrowseFilters.sourceIds` (défaut vide = aucun filtre), prédicat public **unique** `zMatchesSourceId` (switch exhaustif sur les sources scellées ; une `ZCustomSource` ne correspond jamais), composé en **ET** avec le filtre de `kind` dans les deux appliqueurs ; `ZStudySubjectRef` masqué de la ré-export du kernel |
| **P0-B** | `zcrud_session` | `ZFlashcardAnswerInput` gagne cinq contrats optionnels : `choiceContentBuilder`, `writtenAnswerFieldBuilder`, `initialAnswer` (appliquée une fois au montage), `onAnswerChanged` (`ZFlashcardAnswerDraft`), `isSubmitted` (état imposé). Défaut réel corrigé au passage : l'observation d'un champ nu émettait une saisie vide fantôme à la prise de focus |
| **P0-C** | `zcrud_study_kernel` | `ZStudyFolder.subjectId` (clé `subject_id`, émise seulement si non nulle, réservée, spec de champ « Matière »), valeur `ZStudySubjectRef {id, label?, colorKey?}` — la **matière reste une entité de l'hôte**, le socle porte le lien et une référence d'affichage |
| **P0-D** | `zcrud_study` | `ZExamEditor.showWeeklyReminders` (défaut `false`) : section des jours (ordre de la locale, puces ≥ 48 dp, sémantique ISO) + heure via le seam `onPickTime` existant ; la récurrence hebdomadaire initiale est **préservée** même section masquée ; `ZExamWeekdayLabeler`, `weekdayLabeler`, `weeklyRemindersLabel` |
| **P2-C** | `zcrud_screen` | `presentFormEdition(maxWidth:, maxHeight:, sheetFrame:, floatingActionButton:)` (bornes relayées au présentateur ; cadre de feuille = ancêtre direct du formulaire ; FAB porté par un `Scaffold` en voie page) ; `ZCrudScreen.emptyStateBuilder`, rendu sous l'ACL dérivée — « accès refusé » prime |
| **P2-A** | `zcrud_core` | dix jetons nullables (`confirmDialog{Shape,TitleStyle,ContentStyle,ActionsPadding,DestructiveColor}`, `emptyState{IconSize,IconColor,TitleStyle,MessageStyle,Spacing}`) aux quatre sites + `lerp`, absents de `fallback` ; lecteurs `ZConfirmDialogStyle` / `ZEmptyStateStyle.resolve(context)` ; **`ZAudioPlaybackPort`** pur Dart (`ZAudioSource`, `ZAudioPlaybackState` à six états, `ZInertAudioPlaybackPort` const rendant `Left(ZUnsupportedOperationFailure)`) — le socle ne monte un lecteur que si `isAvailable` |
| **P2-F** | `zcrud_document` | `ZDocumentTextExtractionPort` / `ZDocumentOcrPort` (`isAvailable`, `ZResult<ZDocumentText>`), valeurs `ZDocumentTextRequest` / `ZDocumentPageText` / `ZDocumentText` immuables et tolérantes, ports inertes const ; geste « reconnaître le texte » sur `ZDocumentViewerChrome`, monté seulement si `ocrPort` fourni **et** disponible, résultat à `onTextRecognized`, échec à `onTextRecognitionFailed` (à défaut `FlutterError.reportError`), libellé `kZDocumentRecognizeTextLabelKey` via `ZcrudScope.labels` |

Deux points d'honnêteté sur ces lots : la boucle « jeton → pixel » de P2-A n'est **pas fermée** —
`showZConfirmDialog` et `ZEmptyState` (dans `zcrud_ui_kit`) ne lisent pas encore ces styles, c'est
le lot P2-B ; et `ZDocumentTextExtractionPort` est déclaré mais **câblé à aucun geste** (le geste
livré n'appelle que l'OCR, sur le document entier, sans `pages`).

## 3. Ce qui change pour un hôte

**Hôte passif : rien** — prouvé, pas affirmé, par des gardes d'**inertie absolue** écrites avant
toute modification (arbres figés en égalité stricte : QCM 198 nœuds, V/F 125, rédaction 143 ;
`toMap()` de dossier égal clé pour clé ; identité d'instance index par index sur 60 cartes ; quatre
étalons de `presentFormEdition`/`ZCrudScreen`).

**Une exception, voulue, à lire deux fois** : `subjectId` porte une spec de champ. Tout hôte qui
construit son édition de dossier depuis `$ZStudyFolderFieldSpecs` ou `registry.fieldSpecs(…)`
affiche **un champ « Matière » de plus sans une ligne de code**. Une garde d'exhaustivité côté
hôte rougira : c'est un tripwire, pas une régression.

**Hôte ayant compensé — retirer la compensation, sinon elle s'additionne** :
- filtrait par identifiant de source **en aval** de `zApplyTestFilters`/`zApplyBrowseFilters` →
  retirer le `where` et passer `sourceIds:` ;
- avait **cloné** `ZFlashcardAnswerInput` pour rendre ses choix en markdown ou remplacer son champ
  de rédaction → supprimer le clone ; enveloppait la surface dans un `IgnorePointer` pour la geler
  → le retirer au profit de `isSubmitted: true` (l'enveloppe neutralisait aussi la rangée SRS et la
  correction, que `isSubmitted` laisse vivantes) ;
- rangeait la matière dans `extra['subject_id']` → la clé est désormais **réservée** : la lecture
  rend `null`, `copyWith(extra:)` la filtre ; migrer vers `folder.subjectId` (la valeur persistée
  survit au round-trip) ;
- posait sa propre section hebdomadaire autour de `ZExamEditor` → deux jeux de cases et deux
  écritures de `reminderRecurrence`, la sienne gagnant après `onSubmit` ;
- bornait le dialogue d'édition par un `ConstrainedBox` maison ou un présentateur maison, ou
  superposait un bouton flottant par `Stack` → borne la plus petite, deux cadres, deux boutons.

**Limites mesurées** : (1) `narrowWeekdays` Material rend `S M T W T F S` en `en_US` — cinq
libellés pour sept jours ; la garde mesure l'appariement index → jour ISO et `weekdayLabeler` est
l'échappatoire. (2) Aucun repli `showTimePicker` : ajouter un sélecteur aurait rendu actif un bouton
aujourd'hui désactivé quand `onPickTime == null` (rupture d'inertie, AD-26). (3) Les cartes de
lex_douane projetées sur `ZCustomSource` (`z_flashcard_lex_codec.dart:185,197`) sont hors
d'atteinte de `sourceIds` — un extracteur d'identifiant par `kind` serait une décision
d'architecture, non prise ici.

## 4. Vérification

Rejouée par l'orchestrateur, tous les lots au repos (aucun fichier de paquet modifié depuis > 5 min,
aucun marqueur d'injection dans le dépôt), chaque paquet **depuis son dossier**.

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_study_kernel` (`dart test`) | 398 | **407** (analyze 3 infos préexistantes) |
| `zcrud_flashcard` | 586 | **594** (analyze 16 infos préexistantes) |
| `zcrud_session` | 581 | **595** (analyze 43 infos préexistantes) |
| `zcrud_study` | 1555 | **1563** (analyze 70 infos préexistantes) |
| `zcrud_screen` | 370 | **390** (analyze 0) |
| `zcrud_core` | 2 586 | **2 607** (analyze 13 infos préexistantes, 71 s) |
| `zcrud_document` | 268 | **292** (analyze 11 infos préexistantes) |

| Contrôle | Résultat |
|---|---|
| `melos run generate` | SUCCESS — seul `z_study_folder.g.dart` régénéré (attendu : nouveau champ, codegen idempotent prouvé au second passage) |
| `melos run analyze` repo-wide | **RC=0** (4 `info` préexistants) |
| `melos run verify` (12 gates, dont `web` et `reserved-keys` : 17 registrars / 17 sondes) | **RC=0** |
| Balayage des 41 paquets, chacun depuis son dossier | **40 verts** ; `zcrud_generator` rouge **environnemental** de signature inchangée (`Isolate.packageConfig` via `build_test`, 41 échecs, aucun rouge de code) |
| `melos run verify` après le bump (41 pubspecs, contraintes `^3.28.0`, `tool/*`, recette à 47 `ref: v3.28.0`) | **RC=0** |
| Résidus d'injection R3 | **0** — aucun marqueur `ZR3-P*` dans `lib/` ni `test/` |

## 5. Suite

Vague 0 bis (structure d'étude universelle : unités, périodes, matières, curriculums, offerings,
adhésions, rattachements — validée par le propriétaire le 2026-08-28) et Vague 1 (chaînes complètes :
niveaux et repli de qualité, swipe noté et seaux, seuil d'examen blanc, explication progressive,
adaptateurs par route, podcast, partage). Le tripwire recommandé aux hôtes reste inchangé : sur chaque
défaut contourné, un test qui **affirme la perte** — il rougira à la livraison qui la corrige.

Discipline R3 : chaque garde neuve injectée, rouge **par assertion**, restaurée **par copie** (sha256
identiques), grep négatif du marqueur montré. Incident de vague : le quota Codex s'est épuisé deux
fois (18:17, 18:42) ; un lot est mort **en pleine injection** (`z_flashcard_filters.dart:208`) et a
été restauré par l'orchestrateur depuis la sauvegarde privée de l'agent (sha `8e00ffc5…`) ; les
sept lots ont été repris sur des agents Claude Opus, chacun ayant remesuré l'inactivité du paquet
à 90 s d'intervalle avant d'écrire.
