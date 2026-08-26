# Réfutation — IA (IFFD) : « Génération de flashcards par IA (3 onglets + dépôt + scan) »

**Date** : 2026-08-26 · **Verdict : RÉFUTÉE** (couverture partielle présentée comme totale)
**Gain annoncé** : ~1050 lignes d'hôte · **Gain soutenable mesuré** : nettement < la moitié

---

## 1. Ce qui RÉSISTE (vérifié, à porter au crédit de l'affirmation)

Toutes les citations sont **exactes à la ligne**. Rien n'est inventé côté références.

| Citation | Vérif |
|---|---|
| `z_flashcard_generation_sheet.dart:62` `ZGenerationSourceOption` | ✅ classe à :61-84 |
| `…:100` `ZSourceAcquisitionGesture` | ✅ classe à :99-120 |
| `…:216` ctor `ZFlashcardGenerationSheet` | ✅ `const ZFlashcardGenerationSheet({...})` :216-230 |
| `…:403-412` source par référence | ✅ corps réel : `if (resolve == null) return Right(ZResolvedGenerationSource(provenance: option.provenance))` |
| `z_flashcard_generation_port.dart:289` | ✅ `abstract interface class ZFlashcardGenerationPort` |
| `z_flashcard_generation_controller.dart` | ✅ existe (11 211 o) |
| `z_flashcard_generation_defaults.dart` | ✅ existe ; `zClampGenerationCount` + `zEvenTypesDistribution` consommés en :370-372 |
| Hôte : 1 238 l ; `_buildDocumentsTab:280`, `_buildDropZone:328`, `_buildScanZone:443`, `_buildSubjectsTab:671`, `_buildTagChip:835`, `_buildTextTab:889`, `_buildGenerateButton:929` | ✅ **les 8 exactes** |

**Atteignabilité : OK.** Barrel `zcrud_study.dart` :20 (port), :26 (defaults), :126 (controller), :127 (sheet). `zcrud_study` est dépendance déclarée d'IFFD (`pubspec.yaml:391`).

**GREP NÉGATIF hôte — confirmé :**
```
$ grep -rn "ZFlashcardGenerationSheet\|ZFlashcardGenerationPort\|ZGenerationSourceOption\|ZSourceAcquisitionGesture\|ZFlashcardGenerationController" lib/
RC=1   (0 ligne)
```

---

## 2. Ce qui DÉMENT — 9 constats

### 2.1 🔴 La seule preuve « corps lu » avancée valide une ROUTE MORTE

L'affirmation s'appuie sur `:403-412` en disant qu'elle « couvre `…FromWholeDocument` ».
Or dans le fichier hôte, `generateFlashcardsFromWholeDocument` n'apparaît qu'**une fois**, ligne
**1195**, à l'intérieur d'un bloc **entièrement commenté** (1194-1237, 44 l).

La route **VIVE** du parcours document est `generateFlashcardsFromDocumentPagesContents`
(hôte:1141), qui exige `pagesContents: Map<int, String>` produit par
`showFolderDocumentPagesSelectionDialog` (`documents_dialogs.dart:222`, fichier de 323 l).
C'est-à-dire **exactement le chemin `resolveContent` non nul** (`pagesContents`), pas le chemin
par référence.

⇒ La preuve invoquée démontre la couverture d'un besoin que l'hôte **n'exécute pas**, et laisse
non couvert celui qu'il exécute.

### 2.2 🔴 Aucun onglet — le besoin est littéralement « 3 onglets »

```
$ grep -n "TabBar\|TabController\|DefaultTabController\|TabBarView\|Tab(" z_flashcard_generation_sheet.dart
RC=1   (0 ligne)
```
Hôte : `TabController(length: 3, vsync: this)` (:113), `_buildTabBar` (:261-279).
La feuille rend **un formulaire linéaire unique** (:486-530 : sélecteur de source → sources de
contexte → contenu → compteur → types → instructions → modelId).

Les trois onglets sont des **modes mutuellement exclusifs**, chacun avec sa propre garde de
soumission : `if (_selectedDocument == null) return` (:987), `if (_selectedTags.isEmpty) return`
(:1003), `if (textContent.isEmpty) return` (:1057). Non exprimable avec un submit unique.

### 2.3 🔴 Ni zone de dépôt ni zone de scan

```
$ grep -n "DragTarget\|Draggable\|onDragDone\|DropTarget\|onAcceptWithDetails" z_flashcard_generation_sheet.dart
RC=1   (0 ligne)
```
Le socle rend les gestes en **`OutlinedButton` / `OutlinedButton.icon`** (:680, :684).
L'hôte a `_buildDropZone` (328-442, **115 l**) : `DragTarget<Object>` + état de survol
`_isDragging` + bordure réactive ; et `_buildScanZone` (443-518, **76 l**) : carte bordée avec
bascule responsive `isMobile` (`constraints.maxWidth < 350`).

Deux boutons ne sont pas deux zones. C'est une **régression UX**, pas une migration iso.

> ⚖️ *Nuance à la décharge* : `onAcceptWithDetails` de l'hôte a pour corps `// Handle dropped file`
> — le dépôt réel est un **no-op**. Seul le `onTap → FilePicker` (:955-971) fonctionne. Le
> « dépôt » du besoin n'est donc pas implémenté côté hôte non plus.

### 2.4 🔴 Port à MÉTHODE UNIQUE contre hôte à 4 ROUTES

`ZFlashcardGenerationPort` (:289-294) expose **exactement une** méthode :
`Future<ZResult<List<ZFlashcard>>> generateFlashcards(ZFlashcardGenerationRequest)`.

L'hôte pilote **quatre** routes distinctes :

| Route hôte | Site | Charge propre |
|---|---|---|
| `generateSubjectTags` | :147 | tags IA à l'ouverture |
| `generateSubjectFlashcards` | :1017 | `tags:` + `subject:` + `parentSubject:` |
| `generateFlashcardsFromNotes` | :1060 | `notes:` |
| `generateFlashcardsFromDocumentPagesContents` | :1141 | `documentId:` + `pagesContents:` |

C'est précisément l'hôte « **transport PAR ROUTE** » de la décision owner du 2026-08-23. Multiplexer
4 routes dans 1 méthode est de l'**adaptateur à écrire**, pas du code qui disparaît.

### 2.5 🔴 Aucun canal de génération IA de tags

```
$ grep -rn "generateTags\|generateSubjectTags\|suggestTags\|ZTagGenerationPort\|tagSuggestionPort" zcrud_study/lib/
RC=1   (0 ligne)
```
`_loadInitialTags` (hôte:128-155, 28 l) appelle `generateSubjectTags` **à l'ouverture**, avec son
spinner `_isLoadingTags`, pour peupler `_generatedTags`.
Côté socle, `suggestedTags` est une `List<ZSuggestedTag>` **statique** passée au constructeur
(`ZSuggestedTag` : `zcrud_study_kernel/lib/src/domain/z_suggested_tag.dart:35`). Ni chargement
asynchrone, ni état de chargement. **Capacité entièrement absente.**

### 2.6 🔴 Champ de contenu en texte BRUT contre éditeur riche

```
$ grep -n "Markdown\|Quill\|Delta\|maxLength" z_flashcard_generation_sheet.dart
RC=1   (0 ligne)
```
Hôte : `MarkdownEditionField` (:900) sur delta Quill
(`DeltaToMarkdownHelper.normalizedMarkdown`) + compteur `${normalizedText.length}/$_maxTextLength`
avec `_maxTextLength = 30000` (:98).
Socle : `TextField` nu, `minLines: 2, maxLines: 5` (:497-507). Perte de l'éditeur riche **et** du
compteur.

### 2.7 🟠 Contrat progressif contre contrat one-shot

Les routes hôtes prennent `onComplete(result, completed, {hasError = false})`, rappelé
**progressivement**. Le port rend un `Future` unique. Pontable par `Completer`, mais le rendu
progressif est perdu.

### 2.8 🟠 Effet de bord sans créneau

`_generateFromTags` (:1002) exécute un `batchSet` de `FlashcardTagModel` vers
`flashcardTagsRepositoryProvider` **en parallèle de la génération** (`Future.wait`, :1024-1026).
Le socle ne confirme les tags qu'**après** génération (`ZFlashcardGenerationStatus.confirmingTags`
→ `onGenerated`). Aucun créneau de persistance pré-génération.

### 2.9 🔴 Le gain de lignes est gonflé

Découpage mesuré des 1 238 lignes :

| Bloc | Lignes | Devenir réel |
|---|---|---|
| En-tête, champs, état, `initState`, `build` | 1-238 (**238 l**) | partiellement reconstruit (libellés, gestes, sources injectés) |
| `_loadInitialTags` (dans le bloc ci-dessus) | 128-155 (28 l) | **RESTE** — aucun équivalent socle (§2.5) |
| UI des 3 onglets (`_buildHeader`→`_scanDocument`) | 239-985 (**747 l**) | seule zone réellement remplaçable, et partiellement (§2.2, §2.3, §2.6) |
| Dispatch de routes + 2ᵉ dialogue | 986-1238 (**253 l**) | **RÉÉCRIT** en implémentation de port, pas supprimé |

De plus, la génération document réelle vit dans `showFolderDocumentPagesSelectionDialog`
(`documents_dialogs.dart:222`, fichier de 323 l), que le socle ne remplace pas et qui est
**partagée par 8 autres sites d'appel** : `popup_menu_helpers.dart:697,765,841` ;
`folder_documents_actions_dialog_widget.dart:167,311,408` ;
`discovry_page_controller.dart:2097` ; `ai_flashcards_generator_dialog_widget.dart:1131`.
Elle n'est donc **pas supprimable** par cette migration.

⇒ **~1050 lignes n'est pas soutenable.** Plafond théorique 747 l (l'UI), dont il faut retrancher
la ré-injection des libellés/gestes/sources de contexte, et auxquelles s'ajoutent 253 l à réécrire
en adaptateur.

---

## 3. Correction

Le socle **ne sait pas déjà le faire**. Ce qu'il fait réellement :

- ✅ **Couvre bien 1 onglet sur 3** — « texte libre », en texte brut : contenu + nombre (bornes
  `[1,50]` via `zClampGenerationCount`) + types + répartition + instructions + `modelId`.
- ✅ **Offre de vrais créneaux** : `contextSources` (multi-sélection, résolution **à la demande** à
  la soumission — bon pour l'objectif produit n°1) et `acquisitionGestures` (acquisition sur place
  sans perdre le paramétrage saisi, :431-460).
- ❌ **Ne fournit pas** : la structure à 3 onglets ; les zones dépôt/scan (boutons seulement) ;
  la pré-génération IA des tags ; l'éditeur riche + compteur 30 000 ; le flux de sélection de pages
  qu'exige la route document **vive** ; un port multi-routes.

**Reformulation tenable** : « le socle fournit les **briques** (feuille mono-formulaire, port
mono-route, sources de contexte résolues à la demande, gestes d'acquisition) sur lesquelles l'hôte
peut reconstruire l'onglet *texte libre* et, moyennant un adaptateur de routes et un
`resolveContent` branché sur la sélection de pages existante, l'onglet *documents*. L'onglet
*sujets* exige un canal de génération IA de tags **qui n'existe pas**. »

**Manques à combler côté socle** pour rendre l'affirmation vraie : (a) un port de suggestion de
tags asynchrone ; (b) un mode multi-onglets ou l'aveu que l'hôte compose N feuilles ; (c) un slot
de rendu personnalisable pour les gestes d'acquisition (zone, pas bouton) ; (d) un champ de contenu
pluggable (ZCodec/markdown) avec `maxLength`.
