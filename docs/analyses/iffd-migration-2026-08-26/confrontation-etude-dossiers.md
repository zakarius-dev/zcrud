# Confrontation — domaine « Étude — dossiers d'étude » (IFFD) × socle zcrud v3.21.0

**Relevé du 2026-08-26.**
Hôte : `/home/zakarius/DEV/iffd`, branche `feat/migration-zcrud`, HEAD `65d1af9` — **lecture seule stricte**, aucun fichier hôte écrit, aucun test lancé (dans aucun dépôt).
Socle : `/home/zakarius/DEV/zcrud`, HEAD `cc276c154`, tag `v3.21.0`, 41 paquets.

Matière d'entrée : `carte-etude-dossiers.md` (47 961 o, présente) et les cinq
`capacites-zcrud-*.md`. **Aucun des deux n'a été cru sur parole** : tout constat repris ici a
été remesuré sur disque. Les corrections apportées à la carte et aux catalogues sont en § 1.

> **Règle appliquée dans tout ce document** : une capacité placée en 🔴 MIGRABLE porte
> (a) le nom exact de l'API, (b) son `fichier:ligne` dans `packages/`, (c) la **lecture de son
> corps** — pas de sa seule dartdoc, (d) le chiffrage des lignes d'hôte supprimées. Quand la
> lecture du corps a **infirmé** la promesse, la ligne est descendue en MANQUE AU SOCLE et le
> dit (§ 1.3 : deux capacités promises par les catalogues n'ont pas survécu à cette lecture).

---

## 1. Corrections mesurées avant toute confrontation

### 1.1 Corrections à la carte du domaine

| Affirmation de la carte | Commande | Mesuré | Verdict |
|---|---|---|---|
| « Vingt-six verbes CRUD, dont six étendus IA » (§ 7.5) | `awk '/^enum Crud \{/,/^  ;/' crud.dart \| grep -cE '^\s+[a-zA-Z]+\("'` | **17** (11 classiques + 6 IA) | 🔴 **faux** — 17, pas 26 |
| « 5 226 lignes de portage écrites » (§ 2.4) | `wc -l folders/zcrud/*.dart` = **4 940** (13 f.) ; + 3 formulaires = **1 230** | **6 170** | 🔴 arithmétique fausse (4 940 + 1 230 = 6 170) |
| Sécurité = 5 fichiers, 1 194 l (§ 0) | `wc -l lib/src/domain/security/*.dart` | **8 fichiers, 1 582 l** | 🟡 sous-compté |
| D12 « 12 `buildConfirmDialog` dans le domaine » | `grep -rn -F buildConfirmDialog folders documents \| wc -l` | **7** | 🟡 sur-compté (38 repo-wide : ✅) |
| `folders/**` 36 f. / 18 333 l ; `documents/**` 12 f. / 6 420 l | `find … \| wc -l` / `-exec cat {} + \| wc -l` | **36 / 18 333** et **12 / 6 420** | ✅ |
| `features/documents/documents_module.dart` vide | `ls -la` + `find … -type f \| wc -l` | **0 octet**, **1 seul fichier** dans l'arbre | ✅ |
| D4 = 5 menus / 831 l | bornes `:186, :269, :492, :612, :667`, fin `:1016` ⇒ 83+223+120+55+350 | **831** | ✅ |
| D5 = 35 blocs IA | `grep -rn "onComplete: (result, completed" lib \| wc -l` | **35**, dont **5 seulement** dans le domaine dossier (`popup_menu_helpers.dart`) | ✅ + précision décisive |
| D9 = 63 `StreamBuilder`, D11 = 108 `showPushedDialog` | `grep -rn -F … \| wc -l` | **63 / 108** | ✅ |
| Aucune bascule du domaine active | `sed -n '201,210p' lib/main.dart` | 8 identifiants, **aucun** des 12 du domaine | ✅ |
| `folder_actions_menu_zcrud.dart` = code mort | 4 greps (§ 2.2) | ✅ confirmé, greps montrés | ✅ |

### 1.2 Corrections aux catalogues de capacités

| Affirmation du catalogue | Mesuré | Verdict |
|---|---|---|
| `capacites-…-etude-revision.md` § 3 : `ZColorPalette` **jamais cité par IFFD** | `grep -rn -w ZColorPalette /home/zakarius/DEV/iffd/lib` → **4 lignes**, dont `folder_card_default_zcrud.dart:121` (`final ZColorPalette palette;`) et `folder_tags_zcrud.dart:66` (`final ZColorPalette kIffdTagPalette = …`) | 🔴 **faux** — il est consommé, dans **ce** domaine |
| `capacites-…-etude-revision.md` § 9.1 : `ZItemActionState` « inconnu de l'hôte » | `grep -rn -w ZItemActionState lib` → `lib/ai_assistant/zcrud/notebook_zcrud.dart:46` (import réel) | 🟡 vrai pour le domaine dossier, **faux** repo-wide |
| `capacites-…-listes-ecrans.md` : le blocage Syncfusion `^32` a disparu | `grep -n syncfusion pubspec.yaml` → **`^34.1.31`** sur les 9 entrées (`:141-149`) ; le commentaire `:292` dit encore « IFFD est en ^32 » | ✅ le catalogue a raison, le commentaire de l'hôte est périmé |
| `capacites-…-listes-ecrans.md` : `ZAdaptiveGrid.builder` est public | `z_adaptive_grid.dart:89` `const ZAdaptiveGrid.builder({…})`, barrel `zcrud_responsive.dart:61` | ✅ — et `study_tools_zcrud_adapter.dart:69` écrit toujours « n'est pas exposé » |

### 1.3 🔴 Deux capacités promises par les catalogues qui ne survivent PAS à la lecture du corps

Les cinq catalogues alignent `zcrud_document` (`ZAnnotationToolbar`, `ZColorPalette`,
`ZAnnotationPanel`…) face aux **3 349 l** de visionneuse maison. La lecture du code
**infirme** l'équivalence :

1. **`ZDocumentAnnotationKind` ne porte que DEUX valeurs.**
   `packages/zcrud_document/lib/src/domain/z_document_annotation_kind.dart:23-30` — l'enum
   complet est `{ highlight, stickyNote }`. L'hôte en emploie **cinq** :
   ```
   $ grep -rhno "PdfAnnotationMode\.[a-zA-Z]*" lib | sed 's/.*PdfAnnotationMode\.//' | sort -u
   highlight  none  squiggly  stickyNote  strikethrough  underline  values
   ```
   Adopter `ZAnnotationToolbar` aujourd'hui **perdrait** `underline`, `strikethrough`,
   `squiggly`. Ce n'est pas une migration, c'est une régression fonctionnelle.
2. **Aucun canal d'OPACITÉ d'annotation.** `ZDocumentAnnotation`
   (`z_document_annotation.dart:139-194`) porte `id, docId, page, kind, colorKey, bounds,
   rects, text, createdAt` + `extension`/`extra` — **pas d'opacité**. Le
   `ColorPalette` de l'hôte (`document_viewer/color_palette.dart:33-42`) porte
   `selectedOpacity`, `onOpacityChanged`, `onOpcatiySliderViewChanged` et un
   `SfRangeSlider`.

⇒ Le bloc `annotation_toolbar.dart` (837 l) + `color_palette.dart` (483 l) = **1 320 l**
que le catalogue rangeait implicitement en migrable **passe en MANQUE AU SOCLE** (§ 5).
C'est la correction la plus coûteuse de ce document : elle retire 1 320 lignes de la
promesse.

---

## 2. DÉJÀ MIGRÉ — le canal est consommé par du code de l'hôte

⚠️ **Distinction imposée par la mesure.** Douze jumeaux portés consomment réellement des
canaux du socle (imports, symboles, compilation) — mais **aucune de leurs bascules n'est
active à l'exécution** : `lib/main.dart:201-210` active
`{notebook, aiRouterEdition, exam, valuationTool, subject, flashcardEdition, anneeAccademique,
aiExpert}`, dont **zéro** appartient au domaine dossier. « Déjà migré » signifie donc ici
**« porté, compilé, jamais allumé »** — sauf mention contraire.

| # | Canal du socle | Site chez l'hôte | l. jumeau | Legacy qu'il remplace | Actif ? |
|---|---|---|---:|---|---|
| A1 | `ZStudyFolderDetail`, `ZPageScaffold`, `ZAppBarAction`, `ZAppBarSearchConfig`, `ZResponsiveLayout`, `ZSectionedStudyLayout`, `ZGradientSpec` | `folders/zcrud/folder_detail_zcrud.dart` | 545 | ossature de `folder_details_page.dart` (2 037) | ❌ éteint |
| A2 | `ZStudyToolsPage`, `ZStudyToolsSectionSpec`, `ZStudyToolsItemCard`, `ZDefaultDocumentCard`/`FlashcardCard`/`NoteCard`, `ZReorderableAdaptiveGrid`, `ZDefaultReorderRenderer`, `ZStudyReorderHandleMode`, `ZAdaptiveGrid`, `ZTags`, `ZColorPair` | `folders/zcrud/study_tools_zcrud_adapter.dart` (+ `_view` 39, `_flag` 44) | 962 | `folder_study_tools_page.dart:857-2251` (**1 395**) | ❌ éteint |
| A3 | `ZFolderCard`, `ZDefaultFolderCard`, `ZFolderCardFooterPlacement`, `ZFolderCardGradientAccent`, `ZStudyNoteCard`, **`ZColorPalette`**, `ZFolderCardCount` | `folders/zcrud/folder_card_zcrud.dart` (618) + `folder_card_default_zcrud.dart` (263) | 881 | `folders_page.dart:763-1449` (**687**) | ❌ éteint |
| A4 | `ZSubfolderSidebar`, `ZSubfolderNavSpec`, `ZSubfolderRef`, `ZSubfolderCompactSelector`, `ZSubfolderCountPill`, `ZSubfolderLayoutMode`, `ZSubfolderAddPlacement` | `folders/zcrud/subfolder_nav_zcrud.dart` | 671 | `folder_details_page.dart:1760-2037` (278) + `:1571-1759` (189) | ❌ éteint |
| A5 | `ZContentHubSheet`, `ZContentHubSection`, `ZContentHubEntry`, `ZExamEditor`, `ZSmartNoteEditor`, `ZMindmapOutlineEditor` | `folders/zcrud/content_hub_zcrud.dart` | 458 | `folder_content_add_dialog_widget.dart` (**550**) — 6 entrées en **79 l** contre **263** | ❌ éteint |
| A6 | `ZTagEditor`, `ZTagChips`, `ZFlashcardTag`, `ZColorPalette` | `folders/zcrud/folder_tags_zcrud.dart` | 209 | `folder_tags_management_dialog.dart` (**538**) | ❌ éteint |
| A7 | `ZFieldSpec` (6), `presentFormEdition`, `ZFormOnly` | `dialogs/folder_zcrud_edition.dart` | 556 | branche legacy de `showFolderEditonDialog` | ❌ éteint |
| A8 | `ZFieldSpec` (3), `ZFormOnly`, `presentFormEdition` | `dialogs/folders_filter_zcrud_edition.dart` | 462 | `showFoldersFilterDialog` | ❌ éteint |
| A9 | `ZFieldSpec` (1) | `documents/dialogs/folder_document_zcrud_edition.dart` | 212 | `showFolderDocumentEditonDialog` | ❌ éteint |
| A10 | `ZRichTextFullscreenDialog`, `ZRichTextToolbarConfig` | `folders/zcrud/notebook_artifact_actions_iffd.dart` | 488 | `data_crud/rich_text_editor_screen.dart` | ❌ éteint |
| A11 | `ZChatConversationScreen`, `ZChatController`, `ZChatMaterialComposer`, `ZChatMarkdownRenderer`, `ZChatTranscriptBinding`, `ZChatModelOption` | `folders/zcrud/assistant_chat_zcrud_mount.dart` (230) + `notebook_zcrud_mount.dart` (172) | 402 | onglet Notebook | 🟢 **`notebook` ACTIF** |
| A12 | `registerZMarkdownFields(codec:, styleSet:, chrome:)`, `registerZFlashcardEditors`, `ZPhoneFieldWidget`, `ZcrudScope`, `ZcrudTheme` (≈18 jetons d'étude) | `shared/zcrud/z_iffd_field_registry.dart:101,171,188,199,295` | — | registre par montage | 🟢 monté |
| A13 | `ZStudyLegacyCodec` (15 sites), `ZLegacyStudyMigrator` (8), `ZSyncMeta` (84) | `data/repositories/z_backed_*.dart` | — | — | 🟢 |
| A14 | `zReadableTintOn`, `kZNonTextMinContrast` | `ai_assistant/zcrud/notebook_zcrud.dart:46,612` (usage réel) ; cité en commentaire dans `folder_card_default_zcrud.dart:39,143,205,230` | — | — | 🟢 hors domaine |

**Chiffrage.** Le portage écrit pèse **6 170 l** (`wc -l folders/zcrud/*.dart` = 4 940 sur
13 fichiers ; + 1 230 l de formulaires portés). Le legacy qu'il remplacerait, si les bascules
étaient allumées, pèse **≈ 3 640 l** (687 + 1 395 + 278 + 189 + 550 + 538). **Ce gisement
n'est PAS compté dans les « lignes supprimables » de ce document** : la migration y est déjà
faite en code — il manque une décision d'allumage, pas un canal.

---

## 3. 🔴 MIGRABLE AUJOURD'HUI — le socle sait faire, l'hôte l'ignore

Chaque ligne a été vérifiée par lecture du **corps** du canal, pas de sa dartdoc.

### M1 — Les 5 menus contextuels d'item → `ZItemActionsMenu` + `ZItemAction`

| | |
|---|---|
| **API** | `ZItemActionsMenu({required List<ZItemAction> actions, IconData? icon, String? tooltip, ZMenuContentBuilder? menuBuilder, int crossAxisCount = 3, ZMenuRenderer? renderer})` |
| **Preuve** | `packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart:283` (ctor `:292`) ; `ZItemAction` `:147` (ctor `:166`) ; `ZItemActionKind` `:95` ; `ZItemActionState` `:104` |
| **Corps lu** | `:166-176` — `permitted` (défaut `true`) ⇒ action **ABSENTE** si `false` ; `onSelected == null && disabledReason == null` ⇒ **ABSENTE** ; `disabledReason != null` ⇒ **présente, inerte, motif annoncé** ; `assert(onSelected == null \|\| disabledReason == null)` `:176`. `crossAxisCount` défaut **3** `:297`, `assert(crossAxisCount > 0)` `:302`. `zMenuEntryIdForKind` `:119` mappe sur `ZMenuEntryIds` partagés. |
| **Ce que ça remplace** | Les 5 `PopupMenu buildXxxPopupMenu(…)` de `lib/src/presentation/core/widgets/popup_menu_helpers.dart` : `:186` folder (83 l), `:269` note (223), `:492` mindmap (120), `:612` flashcard (55), `:667` document (350) — **831 l**. Même squelette : `MenuConfig(grid, maxColumn: 2)` + `switch (item.menuUserInfo)` + garde de droit + action. |
| **Le jumeau existe déjà — et il est MORT** | `folders/zcrud/folder_actions_menu_zcrud.dart` (241 l) fait le 1ᵉʳ des 5 en **57 l** (`iffdFolderActions` `:98-154`) contre 83. Greps négatifs montrés : `grep -n "folderActionsMenu" z_qa_flags.dart` → **RC=1** (absent des 52 bascules) ; `grep -rn -w iffdFolderActions lib` → **1 ligne**, sa déclaration `:98` ; `grep -rn -w FolderActionsMenuZcrudView lib` → **3 lignes, toutes dans son propre fichier** (`:155,:157,:232`) ; `grep -rn "folderActionsMenuUseZcrud\|kFolderActionsMenuUseZcrudDefault" lib` → **1 ligne**, `:56`, une `const bool` sans provider. Ses seuls consommateurs sont `test/w8k/` et `test/w8p/`. |
| **Lignes supprimées** | Ratio **mesuré dans le dépôt** sur la seule paire existante : 83 → 57 (−31 %). Appliqué aux 831 l ⇒ **≈ 545 l**. ⚠️ extrapolation assumée : une seule paire mesurée. |
| **Préalable** | `zcrud_menu` est **déjà déclaré** (`pubspec.yaml:340`), `zcrud_study` aussi (`:391`). Aucun ajout de dépendance. |
| **Piège à connaître** | `crossAxisCount` est passé de 1 à **3** en v3.0.0 (rupture assumée). L'hôte pose `maxColumn: 2` en legacy ⇒ il devra passer `crossAxisCount: 2` explicitement, sinon la grille change de forme. |

### M2 — L'ordre personnel de contenu → `ZFolderContentsOrder` + `zSectionKey` + `applyOrder<T>`

| | |
|---|---|
| **API** | `ZFolderContentsOrder({String folderId, Map<String,List<String>> sectionOrders, …})` · `String zSectionKey({required String contentType, String? subfolderId})` · `List<T> applyOrder<T>(Iterable<T> items, List<String> order, {required String Function(T) idOf, ZUnorderedPlacement unordered = end})` |
| **Preuve** | `packages/zcrud_study_kernel/lib/src/domain/z_folder_contents_order.dart:115` (`@ZcrudModel(kind:'folder_contents_order')` `:114`, `kSectionOrdersKey = 'section_orders'` `:110`) ; `…/z_section_key.dart:52` ; `…/apply_order.dart:16` (enum `ZUnorderedPlacement` `:16`, fonction `:41`) |
| **Corps lu** | `zSectionKey` : `subfolderId` nul/vide ⇒ `contentType` **verbatim** (rétro-compat du persisté), sinon `'<type>/<sub>'` ; la dartdoc explique que composer la clé à la main **orphelinerait silencieusement** l'ordre en base. `applyOrder` : partition en un passage, tri **stable par construction** (clé secondaire = index d'entrée, indépendant de la stabilité non garantie de `List.sort`), `order` vide ⇒ ordre d'entrée préservé, id inconnu ignoré, doublon ⇒ 1ʳᵉ occurrence, **ne lève jamais**. |
| **Ce que ça remplace** | `getSortedIterms<T>` (`folder_study_tools_page.dart:227-310`, **84 l**) + la partie tri de `onFolderContentReorder<T>` (`:311-357`, **47 l**) + les **4 listes racine + 4 maps par sous-dossier** de `FolderContentsOrders` (`folder_model.dart:332-…`) réduites à **une** map `sectionKey → [ids]`. |
| **Défaut réel que ça corrige** | `getSortedIterms` porte un **bug de shadowing** : `List<String> contentOrder = contentsMaps[T] ?? [];` (`:255`) **redéclare** la variable de `:233` dans la portée du `if` ; l'externe reste vide et le bloc final (`:305-307`) l'écrase par `sortedItems.map(...)`. Le mode `custom` ne trie donc jamais depuis l'ordre persisté sur ce chemin. Il porte aussi un `catch (_) {}` muet (`:298`) qui avale toute exception de transtypage du tri par titre. |
| **Lignes supprimées** | 84 + 47 = **131 l**, plus la simplification du modèle (8 champs → 1). |
| **Réserve honnête** | `ZFolderContentsOrder` est clé par `folderId` seul ; l'hôte utilise `"${userId}_$folderId"` (`folder_details_page.dart:140`). L'entité étant `ZExtensible` (`extra`), l'`userId` se porte dans l'id du document ou dans `extra` — c'est un choix de câblage, pas un blocage. |

### M3 — La confirmation → `showZConfirmDialog` / `ZConfirmDialog`

| | |
|---|---|
| **API** | `Future<bool> showZConfirmDialog(BuildContext, {String? title, required String message, String? confirmLabel, String? cancelLabel, ZConfirmTone tone = ZConfirmTone.neutral})` |
| **Preuve** | `packages/zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129` (widget `:36`) ; `ZConfirmTone` `…/domain/z_confirm_tone.dart:12` |
| **Corps lu** | `:129-148` — `showDialog<bool>` puis `return result ?? false` : **jamais `null`**, jamais de throw. `title` **optionnel** (v2.4.0) : `null` ⇒ titre **retiré de l'arbre**, aucun titre inventé. Libellés via `MaterialLocalizations`. Aucun gestionnaire d'état. |
| **Ce que ça remplace** | `buildConfirmDialog(BuildContext, {String? message, Function? onConfirm})` — `lib/src/utils/functions/forms_utils.dart:480-654`, soit **175 l** (seule fonction de premier niveau dans cet intervalle : `awk 'NR>=478&&NR<=660&&/^[A-Za-z].*\(/'` ne rend qu'elle). **38 appels** repo-wide, **7** dans le domaine dossier. |
| **Grep négatif** | `grep -rn -w showZConfirmDialog lib` → **0** ; `grep -rn -w ZConfirmDialog lib` → **0**. `AlertDialog(` : 25 repo-wide, **2** dans le domaine. |
| **Lignes supprimées** | **175 l** (le corps), les 38 sites restant des appels. |
| **Préalable** | `zcrud_ui_kit` **déjà déclaré** (`pubspec.yaml:440`). |

### M4 — États de contenu et états vides → `ZContentStateView` / `ZLoadingState` / `ZEmptyState` / `ZErrorState`

| | |
|---|---|
| **API** | `ZContentStateView({required ZContentState state, required WidgetBuilder successBuilder, Widget? idle, loading, empty, error})` ; `ZEmptyState`, `ZLoadingState`, `ZErrorState` (`const`) |
| **Preuve** | `packages/zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:180` (`ZContentStateView`), `:31` / `:75` / `:127` ; `ZContentState` `…/domain/z_content_state.dart:13` |
| **Corps lu** | `:214-…` — `switch (state)` **exhaustif sans `default`** (un membre neuf casse la compilation) ; `success` ⇒ `successBuilder` (requis), `loading` ⇒ tranche fournie sinon `const ZLoadingState()`, `idle`/`empty`/`error` ⇒ tranche fournie sinon `SizedBox.shrink()` — replis sûrs, jamais de throw (AD-10). Couleurs **dérivées du `ColorScheme`**, textes injectés, `Semantics`, ≥ 48 dp. |
| **Ce que ça remplace** | `core/widgets/loading_indicators.dart` (**100 l** : `WrapInProgressIndication` `:4`, `FlashcardGenerationIndicator` `:44`) + `folders/widgets/empty_folder_content.dart` (**183 l**). Dans le domaine : **15** `CircularProgressIndicator`. |
| **Grep négatif** | `grep -rn -w -e ZContentStateView -e ZEmptyState -e ZLoadingState -e ZErrorState lib` → **0 pour les quatre**. |
| **Lignes supprimées** | **283 l**. |
| **Réserve** | `EmtyFolderContent` (183 l) porte de l'illustration et de l'onboarding IFFD ; le socle en remplace la structure et l'a11y, pas l'illustration. Chiffrage à considérer comme un plafond. |

### M5 — Les préférences et l'état de lecture d'un document → `ZDocumentViewerPrefs` / `ZDocumentReadingState` / `ZDocumentLearningInfo`

| | |
|---|---|
| **API** | `ZDocumentViewerPrefs` (+ `ZDocumentScrollDirection`, `ZDocumentPageLayout`, `kDefaultZoomLevel`) · `ZDocumentReadingState` · `ZDocumentLearningInfo` (+ `ZDocPageQuality`) |
| **Preuve** | `packages/zcrud_document/lib/src/domain/z_document_viewer_prefs.dart:26` / `:36` / `:47` ; `…/z_document_reading_state.dart:63` (champs `:122-149`) ; `…/z_document_learning_info.dart:32` ; barrel `zcrud_document.dart:70,71,74` |
| **Corps lu** | La dartdoc de tête (`:1-8`) **nomme le défaut de l'hôte** : « un modèle de domaine ne persiste **jamais** un enum d'une lib UI concrète (**ex. un enum Syncfusion**) ». Les deux enums portent un **ordre normatif** (`vertical`, `continuous` = replis défensifs, première constante). `zoomLevel` est **sanitisé** (`kDefaultZoomLevel = 1.0`, plancher `0.25` justifié en commentaire) : « un invariant de valeur naît avec sa garde ». |
| **Ce que ça remplace** | `domain/models/folder_document_reading.dart` (**105 l**) qui déclare `PdfPageLayoutMode? pdfPageLayout` (`:13`) et `PdfScrollDirection? pdfScrollDirection` (`:14`) — **des enums Syncfusion dans le modèle de domaine** — et `folder_document_learning_info.dart` (**82 l**). |
| **Grep négatif** | `grep -rn -w -e ZDocumentViewerPrefs -e ZDocumentReadingState -e ZDocumentLearningInfo -e ZDocumentAnnotation lib` → **0 pour les quatre**, alors que `zcrud_document` est **déclaré en dépendance** (`pubspec.yaml:376`). |
| **Lignes supprimées** | **≈ 150 l** (les deux modèles deviennent des adaptateurs minces). |

### M6 — La (dé)sérialisation à la main des 6 modèles de dossier → codegen `@ZcrudModel`

| | |
|---|---|
| **API** | `@ZcrudModel(kind:, fieldRename:)` `zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:151` · `@ZcrudField(… persistAs:)` `…/zcrud_field.dart:52` · `@ZcrudId` `:16` · `@ZcrudIgnore` `:62` · `ZPersistAs` `…/z_persist_as.dart:16` |
| **Émis** | `_$XxxFromMap` (défensif), `extension XxxZcrud on Xxx { toMap(); copyWith(); }` (`copyWith` **à sentinelle** : reset-`null` distinct de « non fourni »), `$XxxFieldSpecs` (formulaire **et** liste dérivés), `registerXxx(ZcrudRegistry)`, `$XxxTimestampFields`. Source : `zcrud_generator/lib/src/zcrud_model_generator.dart:7-17`, émissions `:978`, `:1184`, `:1208`, `:1237`. |
| **Ce que ça remplace** | **35** triplets `toMap`/`fromMap`/`copyWith`/`props` dans `lib/src/domain/models/` (mesuré : `grep -c "Map<String, dynamic> toMap()"` = **35** sur **17** fichiers), dont **6** dans le domaine dossier : `folder_model.dart` (489 l dont ~273 de sérialisation), `folder_document.dart` (246/96), `folder_document_annotation.dart` (259/112), `folder_invitation.dart` (129/77), `folder_document_reading.dart` (105/42), `folder_document_learning_info.dart` (82/39) = **639 l**. |
| **Grep négatif** | `grep -rn "@ZcrudModel" lib` → **RC=1** ; `grep -rn "ZcrudRegistry" lib` → **RC=1** ; `grep -n zcrud_generator pubspec.yaml` → **RC=1**. Les 10 occurrences de `@ZcrudField` dans `lib` sont **toutes des commentaires** des 5 adaptateurs `z_backed_*`. |
| **Lignes supprimées** | **639 l** pour le seul domaine dossier. |
| **Le canal exact pour le piège `Timestamp`** | `ZPersistAs.timestamp` existe **pour ce cas précis** (`z_persist_as.dart:16-26`). Mais son corps le dit sans détour (`zcrud_field.dart:125-140`) : *« Ce hint **ne change pas** ce que `toMap()` produit… C'est le **repository** qui applique le format natif, en relisant `$XxxTimestampFields` »*. L'hôte écrit `Timestamp.fromDate` **dans le modèle** (`folder_model.dart:126-129`) via son propre `FirebaseCrudRepositoryImpl` : adopter le codegen **sans** faire transiter les écritures par `FirebaseZRepositoryImpl` (ou sans appliquer `$FolderModelTimestampFields` soi-même) écrirait des **String ISO** là où le parc attend des `Timestamp`. Le socle documente le contournement ; il ne l'automatise pas. |
| **Préalables mesurés** | ① `zcrud_annotations` n'est qu'en `dependency_overrides` (`pubspec.yaml:577`), `zcrud_generator` **absent** — deux entrées à ajouter ; `build_runner: ^2.15.1` est **déjà là** (`:539`). ② `folder_model.dart` importe `package:flutter/material.dart` **et** `package:cloud_firestore/cloud_firestore.dart` (`:4-5`) et porte `Color? color` : le générateur **échoue explicitement** sur un champ non annoté de type non sérialisable (`zcrud_model_generator.dart:722-724`). Neutraliser `Color` (→ `colorKey`) est un préalable **hôte**, pas une absence du socle. |

### M7 — La cascade de suppression → `ZCascadeRegistry` + `ZFirestoreCascadeBatcher`

| | |
|---|---|
| **API** | `ZCascadeEdge({parentKind, childKind, childParentRef, owner})` · `ZCascadeRegistry(List<ZCascadeEdge>)` · `ZFirestoreCascadeBatcher(...).deleteCascade({rootKind, rootId, userId}) → Future<ZResult<ZCascadeReport>>` |
| **Preuve** | `zcrud_study_kernel/lib/src/domain/z_cascade_registry.dart:40` (edge) / `:88` (registre) ; `zcrud_firestore/lib/src/data/z_firestore_cascade_batcher.dart:107` (ctor `:110`), `deleteCascade` `:139`, `ZCascadeReport` `:77` |
| **Corps lu** | Registre : garde **anti « deux propriétaires »** — deux arêtes `(parentKind, childKind)` d'`owner` différents ⇒ `ArgumentError` explicite (`:113-121`) ; doublon strict dédupliqué. Batcher : **énumération complète d'abord** (snapshot avant soft-delete), puis flush borné à `FirebaseZRepositoryImpl.kMaxBatchWrites` = **450** (`:127`, jamais un second littéral) ; `Right(ZCascadeReport)` ou `Left(ZFailure)` — **jamais un succès partiel masqué**. |
| **Ce que ça remplace** | `FoldersRepository.deleteFolder` (`folders_repository.dart:135-143`, **9 l**) + `deletedSubFolders` (`:346-363`, **18 l**) + `deleteFolderFlashcards` (`flashcard_repository.dart:73`) + `deleteFolderFlashcardTags` (`flashcard_tags_repository.dart:55`). |
| **🔴 Défaut réel que ça met au jour** | Grep négatif **montré** : `grep -rn -iE "deleteFolder(Documents\|Notes\|Mindmaps\|Contents)" lib` → **RC=1, aucune ligne**. **Supprimer un dossier n'efface ni ses documents, ni ses notes, ni ses cartes mentales** — ils sont orphelinés. `deleteFolder` lance en outre ses trois cascades **sans `await`** (`:138-141`) et `delete(item.id)` part avant leur fin. Un `ZCascadeRegistry` déclaratif rend l'oubli **visible par construction** (la liste d'arêtes est le contrat), et `deleteCascade` rend un rapport au lieu d'un `Future<void>` non attendu. |
| **Lignes supprimées** | **≈ 30 l** — mais la valeur est la **correction**, pas le volume. |
| **Préalable** | `zcrud_study_kernel` (`pubspec.yaml:421`) et `zcrud_firestore` (`:310`) sont **déjà déclarés**. |

### M8 — Le sélecteur de sous-dossiers → `ZSubfolderSelectorBar` + `ZSubfolderNavSpec`

| | |
|---|---|
| **API** | `ZSubfolderSelectorBar({required ZSubfolderNavSpec spec, required ValueListenable<String?> selected, required ValueChanged<String?> onSelect})` |
| **Preuve** | `zcrud_study/lib/src/presentation/z_subfolder_selector_bar.dart:90` (1 066 l) ; `ZSubfolderNavSpec` `…/z_subfolder_nav_spec.dart:402` (**28 paramètres**) |
| **Corps lu** | Structure codée dans le socle et **énumérée dans la dartdoc de tête** (`:24-33`) : déploiement en **feuille modale** bornée à 80 % de la hauteur (`_kSheetMaxHeightFraction = 0.8` `:75`), sous-dossiers **indentés de 24 dp** derrière un filet (`_kHierarchyIndent` `:79`), **la racine est un ITEM sélectionnable** (pas un en-tête), **slot d'action par item** (`ZSubfolderNavSpec.itemActionBuilder`), **pied d'ajout**. Sélection détenue par le parent (`ValueListenable` injectée) ; seul l'ouverture est un état local. |
| **Ce que ça remplace** | `folders/widgets/folder_subfolder_selection_dialog_widget.dart` (**228 l**), qui prend `folder` + `subfolders` et rend exactement cette forme : racine en gras + enfants en `ListTile`, quatre gardes de droit (`canCreate/canUpdate/canDelete/canMove`, `:48-52`), menu par item. |
| **Grep négatif ciblé** | `ZSubfolderSelectorBar` : **0** site hôte (`grep -rn -w`). L'hôte consomme `ZSubfolderSidebar` et `ZSubfolderCompactSelector` dans `subfolder_nav_zcrud.dart`, **pas** la barre à feuille modale. |
| **Lignes supprimées** | **≈ 170 l** (le reste étant les gardes de droit IFFD, à reporter dans `itemActionBuilder`). |
| **🔴 Ne couvre PAS les deux autres sélecteurs** | `folder_selection_dialog_widget.dart` (155 l) et `public_folder_selection_dialog_widget.dart` (239 l) choisissent **parmi des dossiers** (arbre inter-dossiers, `StreamBuilder<List<FolderModel>>` + `ExpandablePanel` par parent). `ZSubfolderNavSpec` est **scopé à UN dossier** : ce n'est pas le même objet. Cf. § 5, MQ-4. |

### M9 — Le partage et la publication → `ZStudySharingPort` + `ZShareLink` + `ZStudyMembership` + `ZPublicStudyFolder` + `ZStudySharingAcl`

| | |
|---|---|
| **API** | `ZStudySharingPort` (6 verbes : `createShareLink`, `revokeShareLink`, `grantMembership`, `watchMemberships`, `publishToGallery`, `unpublish`) · `ZShareLink` · `ZStudyMembership`/`ZMembershipRole` · `ZPublicStudyFolder` · `ZStudyFolderReport`/`ZReportStatus` · `ZStudyModerationPort` · `ZStudySharingAcl` · `ZStudySharingExtension` |
| **Preuve** | `zcrud_study/lib/src/domain/z_study_sharing_port.dart:37` ; `z_share_link.dart:23` ; `z_study_membership.dart:51` / `:22` ; `z_public_study_folder.dart:16` ; `z_study_folder_report.dart:43` / `:15` ; `z_study_moderation_port.dart:28` ; `z_study_sharing_acl.dart:43` ; `z_study_sharing_extension.dart:39` |
| **Corps lu** | Toute mutation rend `Future<ZResult<T>>`, les flux sont des `Stream<List<T>>` **nus** (`watchMemberships` `:51`). `revokeShareLink` rend `ZResult<Unit>` — **jamais un `ZShareLink` nu** : la révocation est **monotone**. Chaque mutation de champ de contrôle **doit consommer `ZStudySharingAcl.canMutateControl`** ; une mutation par un non-propriétaire remonte `Left`, jamais un `Right` silencieux. Aucun nom de collection, aucun endpoint, aucune primitive de chiffrement (AD-12). `ZShareLink.fromJson` : `revoked` non-`bool` ⇒ `false`, `revoked_at` mal formé ⇒ `null`, clés inconnues ⇒ `extra` ; **un lien révoqué reste révoqué** au round-trip. |
| **Ce que ça remplace** | `domain/models/folder_invitation.dart` (**129 l**) et le vocabulaire épars de `FolderModel` (`isPublic` `:26`, `sharedWith` `:28`, `canBeJoinedWithLink` `:29`, `coWorkersCanInviteOthers` `:30`) ; l'ossature de `folders/widgets/folder_coworkers_dialog_widget.dart` (449 l). |
| **Grep négatif** | `grep -rn -w -e ZStudySharingPort -e ZShareLink lib` → **0 pour les deux**. |
| **Lignes supprimées** | **≈ 100 l** (le modèle d'invitation ; l'implémentation Firestore reste hôte — c'est un **port**). |
| **Réserve honnête** | Le socle est **plus riche** que l'hôte : lien **révocable à jeton** (l'hôte n'a qu'un booléen `canBeJoinedWithLink`), **rôles** d'adhésion (l'hôte n'a qu'une `List<String> sharedWith`), signalement/modération (absents chez l'hôte). Adopter n'est donc pas un portage neutre : c'est un gain de fonctionnalité à décider, pas à subir. |

### M10 — `ZcrudScope.derive` : ne plus masquer ses propres seams

| | |
|---|---|
| **API** | `static ZcrudScope derive(BuildContext context, {required Widget child, Key? key, ZDependencyResolver? resolver, ZAcl? acl, Object? labels = _zScopeUndefined, … 25 seams})` |
| **Preuve** | `zcrud_core/lib/src/presentation/zcrud_scope.dart:478` ; sentinelle `_zScopeUndefined` `:46` |
| **Corps lu** | Chaque seam a pour défaut la sentinelle : un paramètre **omis hérite** du scope ambiant, un `null` **explicite** remet le seam à son repli. C'est la différence entre compléter et remplacer. |
| **Mesure hôte** | `grep -rn "ZcrudScope(" lib \| wc -l` → **28** ; `grep -rn "ZcrudScope.derive" lib \| wc -l` → **0**. Chacun des 28 `ZcrudScope(` imbriqués **masque** le registre, le thème et les 23 autres seams de son parent. |
| **Lignes supprimées** | **0** — c'est une correction de comportement, pas de volume. C'est précisément pour ce défaut que les trois bindings sont passés à `derive` en 3.1.0 (`zcrud_riverpod/lib/src/presentation/zcrud_riverpod_scope.dart:98`). |

### M11 — L'affordance qui disparaît au lieu d'être grisée → `ZFeatureAvailability`

| | |
|---|---|
| **API** | `ZFeatureAvailability.isAvailable(String featureKey)` + `enabledFor` + **`VoidCallback? gate(String, VoidCallback?)`** ; impls `ZAllFeaturesAvailable`, `ZMapFeatureAvailability({flags, availableWhenUnspecified})` ; scope `ZFeatureAvailabilityScope` |
| **Preuve** | `zcrud_study/lib/src/presentation/z_feature_availability.dart:41` / `:64` / `:77` / `:94` / `:149` |
| **Corps lu** | `gate` rend `action` si disponible, **`null` sinon** — et ce `null` rend la surface non actionnable **par le mécanisme existant** (`ZContentHubEntry.onTap` nul, `ZItemAction.onSelected` nulle ⇒ filtrée, `ZStudyToolsSectionSpec.addAction` nulle) : jamais un no-op silencieux. Défaut du paquet **fail-open** (`ZAllFeaturesAvailable`) : le socle ne masque jamais une capacité que l'app a câblée. `featureKey` est une `String` **opaque** — pas d'enum fermé. |
| **Ce que ça sert** | Les **72** `ListTile(` du domaine (`grep -rn -F "ListTile(" folders documents \| wc -l`) portent chacun leur garde `userPermissions?.can(Crud.x, cleAcces)` avant l'action — patron répété (ex. `folder_actions_dialog_widget.dart:57,99,118,135,159,167` : 6 en 130 l). |
| **Grep négatif** | `grep -rn -w ZFeatureAvailability lib` → **0**. |
| **Lignes supprimées** | **non chiffré** — le gain est l'uniformité (« absente, jamais grisée ») et la suppression des `if (can) … else SizedBox.shrink()`, pas un volume net. |

### M12 — Les 5 dépôts orphelins → `ZStudyRepository<T>` + `buildFolderScopedStudyRepository` / `buildUserScopedStudyRepository`

| | |
|---|---|
| **API** | `ZStudyRepository<T> buildFolderScopedStudyRepository<T extends ZEntity>({firestore, local, kind, collection, parentCollection, decode, encode, folderId, userId, userScoped = true, isConnected, logger, autoListen = true})` et son jumeau **racine** `buildUserScopedStudyRepository` |
| **Preuve** | `zcrud_firestore/lib/src/data/z_folder_scoped_study_repository.dart:114` et `:187` ; `ZStudyRepository<T>` `zcrud_study_kernel/…/z_study_repository.dart:52` ; `ZOfflineFirstBoxRepository` `zcrud_firestore/…/z_offline_first_box_repository.dart:103` |
| **Corps lu** | Assemble `ZOfflineFirstBoxRepository` + `ZFirestorePathResolver` ; **type de retour = port neutre** (aucun type `cloud_firestore` en signature hors le paramètre d'injection). `folderId` vide ⇒ `Left(ZDomainFailure)` du resolver à **toute** opération (AD-10, jamais avalé). Sur la variante racine, `userScoped` est **requis sans défaut**, et la dartdoc dit pourquoi : *« un défaut se trompant de sens écrirait hors du scope utilisateur… une fuite de données silencieuse »* — et que le contournement manuel **« a fini par entrer en production chez un consommateur »**. |
| **Ce que ça sert** | Les **5** dépôts du domaine sans jumeau zcrud : `FolderInvitaionsRepository`, `FolderContentsOrdersRepository`, `FolderDocumentReadingRepository`, `FolderDocumentLearningRepository`, `FolderDocumentAnnotationRepository` (`folder_providers.dart:96-115`). |
| **Grep négatif** | `grep -rn -w -e buildFolderScopedStudyRepository -e buildUserScopedStudyRepository -e ZOfflineFirstRepository -e ZFirestorePathRule lib` → **0**. Les deux seules mentions de `ZOfflineFirstBoxRepository`/`ZFirestorePathResolver` sont des **commentaires** (`z_backed_folder_document_repository.dart:308,309`). |
| **Lignes supprimées** | **non chiffré** (ces 5 dépôts n'ont pas d'implémentation zcrud à comparer ; le gain est de ne pas écrire un 6ᵉ `z_backed_*` de ~700 l pour chacun). |

### M13 — Deux constats d'absence de l'hôte que la mesure contredit

| Constat écrit par l'hôte | Où | Mesure |
|---|---|---|
| « `ZAdaptiveGrid.builder` (virtualisé) **n'est pas exposé** » | `folders/zcrud/study_tools_zcrud_adapter.dart:69` | 🔴 **faux** : `const ZAdaptiveGrid.builder({required int itemCount, required IndexedWidgetBuilder itemBuilder, …})` `zcrud_responsive/lib/src/presentation/z_adaptive_grid.dart:89`, classe exportée par le barrel `:61`. Exclusivité avec `children:` **par construction** (deux constructeurs), pas par `assert`. ⚠️ La **décision** de l'hôte reste valable (corpus ≤ 21 items, virtualisation exclusive du réordonnancement) — seul le constat d'absence ne l'est plus. **0 ligne** gagnée. |
| « `zcrud_list` / `zcrud_export` : exigent Syncfusion ^34, **IFFD est en ^32** » | `pubspec.yaml:292` | 🔴 **périmé** : `grep -n syncfusion pubspec.yaml` → les **9** entrées sont en **`^34.1.31`** (`:141-149`), `syncfusion_flutter_pdfviewer` compris. Le blocage n'existe plus ; déclarer `zcrud_list` (donc `ZSfDataGridRenderer`, `ZListQueryPolicy`, `ZCrudScreen`) redevient un **choix**. |

---

## 4. Les 5 blocs « générer avec l'IA » du domaine — migrable en partie seulement

`grep -rn "onComplete: (result, completed" lib \| wc -l` = **35** repo-wide ; **5** sont dans
le domaine dossier (`core/widgets/popup_menu_helpers.dart`) et sont **déjà comptés en M1**.

| Verbe IA de l'hôte | Port neutre du socle | `fichier:ligne` | Chaîne UI assemblée ? |
|---|---|---|---|
| `generateFlashcardsFrom{WholeDocument, DocumentPagesContents, Notes}`, `generateSubjectFlashcards` | **`ZFlashcardGenerationPort`** + `ZFlashcardGenerationRequest` + `ZResolvedGenerationSource` + `ZGenerationSourceResolver` | `zcrud_study/…/z_flashcard_generation_port.dart:289` / `:113` / `:43` / `:98` | ✅ **oui, complète** — `ZFlashcardGenerationSheet` `…/z_flashcard_generation_sheet.dart:214` (12 params : `port`, `messages`, `labels`, `sources`, `onGenerated`, `suggestedTags`, `existingTags`, `palette`, `languageTag`, `initialModelId`, `contextSources`, `acquisitionGestures`), `…Controller` `…_controller.dart:84`, `…Launcher` `:868`, `…Scope` `:841` |
| `generateSubjectExplanation`, `elaborateExplanation`, `summarizeExplanation`, `explainSubjectWithStyle` | `ZAiExplanationPort` + `ZAiExplanationRequest` | `…/z_ai_explanation_port.dart:67` / `:17` | ❌ **port seul** |
| `generateMindmapFrom{WholeDocument, DocumentPagesContents, Notes}` | `ZMindmapGenerationPort` | `…/z_mindmap_generation_port.dart:189` | ❌ port seul (rend une **forêt éphémère** de `ZMindmapNode`, jamais un `ZMindmap` persisté) |
| `generateSummaryFrom{WholeDocument, DocumentPagesContents}` | `ZNoteSummaryPort` | `…/z_note_summary_port.dart:68` | ❌ port seul |
| `generateSpeechFromTextWithAi` | `ZPodcastGenerationPort` (+ `ZStudyPodcast`, `sourceHash` **fourni par l'appelant**) | `…/z_podcast_generation_port.dart:131` | ❌ port seul |
| `convertDocumentToPdf` (7 sites) | — | — | 🔴 **aucun canal** (cf. § 5, MQ-6) |
| `generateRelatedTopics` | — | — | 🔴 aucun canal |

**Corps lu, `ZFlashcardGenerationLauncher`** (`:900-903`) : sans port ni
`ZFlashcardGenerationScope`, il rend `const SizedBox.shrink()` — **absent de l'arbre**, jamais
grisé. Un hôte qui cherche « pourquoi le bouton ne s'affiche pas » cherche un booléen qui
n'existe pas.

**Greps négatifs montrés** : `grep -rn -w -e ZFlashcardGenerationPort -e ZAiExplanationPort
-e ZMindmapGenerationPort -e ZNoteSummaryPort -e ZPodcastGenerationPort
-e ZFlashcardGenerationSheet lib` → **0 pour les six**.

⇒ **Verdict** : un seul des sept verbes a une chaîne UI prête. Les cinq autres ports
n'économisent **aucune ligne d'UI** — ils normalisent la signature (`Either<ZFailure,T>`,
zéro prompt/endpoint en surface) sans remplacer le bloc répété. Classer les cinq en
« migrable » serait une promesse à tort ; ils sont **des ports disponibles**, pas des
assemblages.

---

## 5. MANQUE AU SOCLE

| # | Ce qui manque | Forme du canal | Paquet | Pourquoi l'hôte ne peut pas s'en passer | Bloque une capacité d'étude/révision ? |
|---|---|---|---|---|---|
| **MQ-1** | **Trois natures d'annotation** : `underline`, `strikethrough`, `squiggly` | **Valeurs d'enum additives** sur `ZDocumentAnnotationKind` (ordre normatif : ajouter **en fin**, `highlight` reste le repli) | `zcrud_document` | Preuve : l'enum complet est `{highlight, stickyNote}` (`z_document_annotation_kind.dart:23-30`, fichier lu **en entier**) ; l'hôte en emploie 5 (`grep -rhno "PdfAnnotationMode\.[a-zA-Z]*"` → `highlight, none, squiggly, stickyNote, strikethrough, underline`). Adopter aujourd'hui = **perdre 3 outils de surlignage**. | 🔴 **oui** — bloque la migration de la lecture annotée d'un document |
| **MQ-2** | **L'opacité d'une annotation** | Champ `double? opacity` (borné, garde de valeur) sur `ZDocumentAnnotation` + un slot dans `ZAnnotationToolbar` | `zcrud_document` | Preuve : les champs de `ZDocumentAnnotation` sont `id, docId, page, kind, colorKey, bounds, rects, text, createdAt` + `extension`/`extra` (`z_document_annotation.dart:139-194`) — **aucune opacité** ; l'hôte pilote `selectedOpacity` / `onOpacityChanged` / `onOpcatiySliderViewChanged` (`document_viewer/color_palette.dart:33-42`). | 🟡 dégrade, ne bloque pas |
| **MQ-3** | **Le glyphe d'une note ancrée** et les **lignes de texte** couvertes | Slot typé (`String iconKey`) + `List<ZAnnotationBounds>` déjà présent (`rects`) mais sans convention de correspondance | `zcrud_document` | `FolderDocumentAnnotation` porte `PdfStickyNoteIcon? icon` (`:21`) et `List<PdfTextLine> textLines` (`:24`) — deux types **Syncfusion** dont le socle n'a d'homologue que partiel (`rects`). | 🟡 |
| **MQ-4** | **Un sélecteur d'arbre INTER-dossiers** (choisir un dossier, puis son sous-dossier, parmi tous) | **Assemblage** — un `ZFolderTreePicker` prenant une liste de `(dossier, sous-dossiers)` et rendant `(folderId, subFolderId)` | `zcrud_study` | `ZSubfolderNavSpec`/`ZSubfolderSelectorBar`/`ZSubfolderCompactSelector` sont **scopés à UN dossier** (lu : `spec` + `selected: ValueListenable<String?>` + `onSelect`, `z_subfolder_selector_bar.dart:90-97`). Les deux sélecteurs restants de l'hôte (`folder_selection_dialog_widget.dart` 155 l, `public_folder_selection_dialog_widget.dart` 239 l) choisissent **parmi des dossiers** — et le déplacement d'un contenu (`popup_menu_helpers.dart:413,536,921`) en dépend. | 🟡 bloque D6 (2 des 3 sites, **394 l**) |
| **MQ-5** | **Un horodatage MÉTIER de dernière modification**, distinct de l'horloge de sync | Champ typé (`modifiedAt`) sur `ZStudyFolder`, **hors** `ZSyncMeta.reservedKeys` | `zcrud_study_kernel` | Mesuré : `ZStudyFolder.updatedAt` (`z_study_folder.dart:186`) est **`@Deprecated`** et documenté « miroir de compatibilité — le store réécrit la clé `updated_at` à chaque écriture » ; `ZSyncMeta.reservedKeys = {updated_at, is_deleted}` (`z_sync_meta.dart:44`). L'hôte doit donc **doubler** son `updatedAt` métier dans `extra['iffd_updated_at']` (`z_backed_folder_repository.dart:44-48` et la table de correspondance `:130`). Le socle prescrit le contournement au lieu d'offrir le canal. | 🟡 |
| **MQ-6** | **Aucun rattachement typé d'un dossier à une MATIÈRE** | Champ `subjectId` (ou `ZStudySubjectRef`, sur le modèle de `ZStudyDocumentRef`/`ZStudyNoteRef`) | `zcrud_study_kernel` | 🔴 **Grep négatif montré** : `grep -rn -i "subjectid\|subject_id" zcrud_study_kernel/lib zcrud_study/lib` → **RC=1** ; `grep -rnE "class ZStudySubject\|class ZSubject" zcrud_study_kernel/lib zcrud_study/lib zcrud_exam/lib` → **RC=1**. L'hôte range `subjectId` dans `extra['iffd_subject_id']` — sa propre table de correspondance le dit : `z_backed_folder_repository.dart:134` « aucun homologue de schéma ». Sans ce lien : pas de `groupBySubject` (`folders_page.dart:189`), pas de filtre par matière (`:209-238`), pas de `SubjectStudyToolsPage` (`folder_study_tools_page.dart:2252`), pas de « flashcards par défaut de la matière » (`:869-873`). | 🔴 **oui** — bloque le groupement et le filtrage d'étude par matière |
| **MQ-7** | **Le droit de « déplacer » et les 6 droits IA ne sont pas exprimables** | Valeurs additives sur `ZCrudAction`, **ou** une clé d'action ouverte (`String`) en second canal | `zcrud_core` | Mesuré : `ZCrudAction` est **fermé à 11 valeurs** (`z_acl.dart:28-61` : `view, create, update, delete, restore, copy, archive, publish, clear, validate, history`). Le `RessourceACL` de l'hôte porte **exactement les 11 mêmes** (`ressource_acl.dart:2-12`) — correspondance parfaite. Mais son enum `Crud` en compte **17** (`awk … \| grep -c` = 17) : `move` **plus** `aiGenerate, aiSummary, aiMindMap, aiFlashCard, aiExplain, aiChat`, marqués `extended: true` (`crud.dart:20-25`). Chez IFFD **le droit de générer avec l'IA est un droit CRUD comme un autre** (`document_access_service.dart:164-194`). | 🔴 **oui** — un `ZAcl` du socle ne peut pas gouverner la génération IA ni le déplacement |
| **MQ-8** | **Aucun canal de conversion de document** (non-PDF → PDF) | **Port** `ZDocumentConversionPort` | `zcrud_document` | `convertDocumentToPdf` est appelé **7 fois** chez l'hôte. Le socle porte `ZPdfCreationService.buildImagesPdf` (`zcrud_export_pdf/…/z_pdf_creation_service.dart:19`) — **images → PDF uniquement**, pas Word/Excel/PowerPoint. | 🟡 |
| **MQ-9** | **Aucune primitive de composition de flux** pour les pyramides de `StreamBuilder` | — | — | **63** `StreamBuilder` dans le domaine, pyramides de **5** niveaux (`folders_page.dart:916-…`, un par nature de contenu) et de **4** (`folder_details_page.dart:138-160`). ⚠️ **C'est un non-manque assumé** : AD-2/AD-15 interdisent au cœur tout gestionnaire d'état ; la composition de flux appartient au binding (`zcrud_riverpod`). Consigné pour que personne ne le redemande. | ❌ non |

---

## 6. RESTE À L'HÔTE — règle métier IFFD, le socle ne porte pas de règle métier

| # | Ce qui reste | Preuve | Pourquoi |
|---|---|---|---|
| R1 | **L'année académique comme suffixe de clé d'ACL** — `"FolderModel$accademicYear"` | `folder_actions_dialog_widget.dart:41-45` ; `folder_subfolder_selection_dialog_widget.dart:47-52` ; `folder_details_page.dart:191-195` | Un même utilisateur a des droits **différents sur le même type** selon l'année. Aucune ontologie de socle ne porte ça. La clé est **relue à chaque appel, jamais capturée** — le commentaire `:191-192` explique qu’elle change sans reconstruire le bloc, et `cleAcces` la recompose à chaque appel (`:194-195`). |
| R2 | **`FiliereEtCycleIFFD`** — produit cartésien fermé de 12 valeurs (6 filières × 2 cycles), vues `cyclesMoyens`/`cyclesSuperieurs`, `title` dérivé par découpe de chaîne | `domain/models/iffd_models.dart:30` | Nomenclature d'un établissement. |
| R3 | **La promotion d'un auditeur est CALCULÉE**, et elle **change la forme de la requête** | `folders_page.dart:178-182` (`anneeEnCours?.promotionAuditeur(userId)`), `:209-238` (sans promotion ⇒ `whereIn`/`itemFilter` ; avec ⇒ `arrayContains`) | Règle d'accès métier. |
| R4 | **Le filtre est une ACL déguisée** : en mode « mes dossiers », « Filières et cycles » et « Auditeurs » disparaissent et leurs valeurs sont neutralisées, puis retrouvées intactes au retour | `folders_page.dart:194-208` ; comportement listé prioritaire en QA (`z_qa_flags.dart:205-220`) | — |
| R5 | **Deux orthographes fautives contractuelles** : `accademicYear`, `folderExplaination` | `folder_model.dart:19,32` ; préservées jusque dans l'adaptateur (`z_backed_folder_repository.dart:59-62`) | Le parc documentaire en dépend. |
| R6 | **La hiérarchie bicéphale** : un sous-dossier est un dossier dont `isSubFolder` est vrai ; `getFolderIds()` rend `(folderId, subFolderId)` ; les badges d'une carte de sous-dossier comptent **le parent** | `folder_model.dart:99` ; `folders_page.dart:842-843` | Le socle n'a que `parentId` + `validatePlacement` — le doublon `isSubFolder` est une convention IFFD. |
| R7 | **La couleur d'un document est décidée par son extension**, en dur | `folder_document.dart:37-55` (pdf rouge, doc/docx bleu, xls/xlsx vert, ppt/pptx orange, images bleu-gris, txt/md gris) | Convention IFFD. Le socle offre `zDefaultDocumentFormatIcons` (`z_default_document_card.dart:92`) pour les **icônes**, jamais pour les couleurs. |
| R8 | **Le rail de flashcards non réordonnable** et borné à `take(10)` alors que le badge affiche le total | `study_tools_zcrud_adapter.dart:610-616` — le portage **refuse** de l'ajouter (« ce serait un ajout de fonctionnalité déguisé en portage ») | Décision de parité, exemplaire. |
| R9 | **Les flashcards par défaut de la matière**, concaténées **seulement à la racine** | `folder_study_tools_page.dart:869-873` | Règle métier. |
| R10 | **Les 10 dégradés de carte de dossier** (5 clair + 5 sombre, hex en dur) | `folders_page.dart:55-74` (`folderGradientsLight`, `folderGradientsDark`, `getFolderGradients`) | FR-26 : valeurs de marque. **Le mécanisme** est migrable (`ZcrudScope.gradientResolver` + `ZGradientSpec`, `zcrud_core/…/z_gradient_resolver.dart:40,63`, déjà consommé par le jumeau `folder_card_zcrud.dart` via `ZFolderCardGradientAccent`) — **les valeurs**, non. |
| R11 | **Le gabarit de bascule** (D8) : 55 constantes `const bool kXxxDefault` + 52 providers + `z_qa_flags.dart` (985 l) | `z_flag_gateway.dart:1-34` documente le défaut mesuré le 2026-07-30 : **sur 17 providers, un seul était lu**, les 16 autres aiguillaient sur la `const` résolue à la compilation | **Échafaudage de strangler fig**, à démonter avec la migration — pas un assemblage manquant. |
| R12 | **Les 6 adaptateurs `z_backed_*`** (D2, **4 648 l** mesurées : 912+797+698+772+806+663) | En-têtes auto-descriptifs : « RÉPLICATION EXACTE du patron des cutovers PRÉCÉDENTS » (`z_backed_folder_repository.dart:4-11`) | Ce sont des **mappeurs** `FolderModel ↔ ZStudyFolder`, prix du double modèle pendant la transition. Ils disparaissent quand l'hôte adopte l'entité du socle (ou M6). Le socle offre déjà `ZStudyLegacyCodec` (15 sites) et `ZLegacyStudyMigrator` (8 sites) pour ce chemin. |
| R13 | **Les 4 fabriques `FolderResourceAccessContext.forDocument/forNote/forMindmap/forFlashcard`** (D10, 96 l) | `folder_resource_access_service.dart:50,74,98,122` | Composition de droits IFFD. |

---

## 7. Bilan chiffré

| Catégorie | Volume |
|---|---|
| Domaine exploré (mesuré ce jour) | `folders/**` **36 f. / 18 333 l** + `documents/**` **12 f. / 6 420 l** + 6 modèles **1 310 l** + sécurité **8 f. / 1 582 l** + `z_backed_*` **4 648 l** |
| **Déjà migré** (porté, compilé) | **6 170 l** de jumeaux (13 f. `folders/zcrud/` = 4 940 l ; 3 formulaires = 1 230 l) |
| …dont **actif à l'exécution** | **1 seul** — `notebook` (`main.dart:201-210`) ; les **12** identifiants du domaine dossier sont éteints |
| Legacy que l'allumage des bascules retirerait | **≈ 3 640 l** (687 + 1 395 + 278 + 189 + 550 + 538) — **non compté** ci-dessous |
| 🔴 **Migrable aujourd'hui** | **≈ 2 220 l** — M1 545 · M2 131 · M3 175 · M4 283 · M5 150 · M6 639 · M7 30 · M8 170 · M9 100 ; M10-M13 à gain nul en volume |
| **Manque au socle** | 9 items, dont **3 bloquants** (MQ-1 annotations, MQ-6 matière, MQ-7 droits IA/déplacement) |
| **Reste à l'hôte** | 13 items |
| Retiré de la promesse après lecture du corps | **1 320 l** (`annotation_toolbar.dart` 837 + `color_palette.dart` 483) — § 1.3 |

**Ordre de rendement décroissant** : M6 (codegen, 639 l) · M1 (menus, 545 l) · M4 (états,
283 l) · M3 (confirmation, 175 l) · M8 (sélecteur de sous-dossiers, 170 l) · M2 (ordre
personnel, 131 l + un bug de shadowing corrigé) · M5 (150 l + les enums Syncfusion sortis du
domaine) · M9 (100 l) · M7 (30 l + **une cascade incomplète mise au jour**) · M10-M13
(correction sans volume).

**Le geste le moins coûteux et le plus rentable n'est dans aucune de ces lignes** : allumer
les 12 bascules du domaine dans `main.dart`. Le code est écrit, compilé, testé
(21 fichiers de test nommément liés au domaine sur 224). C'est une décision, pas un chantier.

---

## 8. Ce que cette confrontation N'A PAS établi

- **Aucun test lancé**, dans aucun dépôt (consigne). Rien ici n'atteste qu'un canal
  *fonctionne* — seulement qu'il *existe*, à telle ligne, avec tel corps et tels défauts.
- **Le ratio d'économie de M1** est extrapolé d'**une seule** paire mesurée (83 → 57). Les
  quatre autres menus (223, 120, 55, 350 l) n'ont pas de jumeau à comparer.
- **La fermeture transitive** d'une adoption de `zcrud_list` / `zcrud_export` /
  `zcrud_annotations` + `zcrud_generator` n'a pas été résolue (`pub get` non lancé). Le
  précédent `zcrud_menu` (« TROISIÈME OCCURRENCE », `pubspec.yaml:334-339`) impose la
  prudence.
- **Le comportement du générateur face à `Color?`** n'a pas été exercé : j'ai lu qu'il lève
  `InvalidGenerationSourceError` sur « champ non annoté de type non sérialisable »
  (`zcrud_model_generator.dart:722-724`), je n'ai pas prouvé que `Color` tombe dans cette
  branche.
- **Les CR ouvertes CR-IFFD-114/115/116** (`docs/zcrud-change-requests.md:7589,7675,7734`)
  portent sur le lecteur riche et l'éditeur plein écran — **hors** de ce domaine ; les
  CR-117 à 120 sont « RETIRÉE AVANT ÉMISSION » (`:7787,7825,7859,7879`), quatre sur sept
  parce que **le canal existait déjà**. Je ne les ai pas confrontées.
- **Aucun secret n'a été lu.** Aucun fichier de configuration de plateforme n'a été ouvert.
