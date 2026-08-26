# Confrontation — domaine « Notes intelligentes » (SmartNotes) IFFD ⇄ socle zcrud v3.21.0

> Relevé du **2026-08-26**. IFFD en **lecture seule stricte**, HEAD `65d1af9`
> (« feat(zcrud): les étiquettes de résumé d'un select reprennent la teinte du legacy »).
> Socle : `/home/zakarius/DEV/zcrud/packages`, **41 paquets**, v3.21.0.
> Matière d'entrée : `carte-notes-smartnotes.md` (présente, 24 686 o) + les **cinq**
> catalogues `capacites-zcrud-*.md`. **Aucun constat repris sans remesure sur disque.**
> Le relevé `iffd-migration-2026-08-25/` n'a pas été utilisé comme preuve.

---

## 0. Ce que la remesure a corrigé dans la matière d'entrée

Quatre constats de la carte et des catalogues sont **faux ou imprécis**. Ils sont corrigés ici
parce qu'ils portaient chacun sur une catégorie « migrable ».

| Constat de la matière | Remesure | Verdict |
|---|---|---|
| Carte §1.1/§3.3 : « `zcrud_chat_study` couvre les 8 sites / ~440 l. de *flashcards depuis une note* » | `zChatMessageGenerationRequest` prend un **`ZChatMessage`** (`z_chat_flashcard_mapper.dart:113-114`), `zChatConversationGenerationRequest` une **`ZChatConversation`** (`:137-139`). Aucune des deux ne prend une note. Le paquet câble **conversation → SRS**, jamais note → SRS | 🔴 **FAUX** — le bon canal est `ZFlashcardGenerationPort` (`zcrud_study`), pas `zcrud_chat_study` |
| Carte §1.1 : « `popup_menu_helpers.dart:707-760` et `:791-820` = blocs *depuis une note* » | `:706` appelle `generateFlashcardsFromDocumentPagesContents`, `:784` la variante document. Ce sont les blocs **document**, pas note | ⚠️ **Mal attribué** (le bloc de post-traitement est bien identique, la source ne l'est pas) |
| Carte §4 : « `smartNoteAiInstructionsForcedMode` — manque au socle : `showPushedDialog` dérive le mode mais ne l'expose pas » | `presentFormEdition` porte **`ZEditionPresentation? forcedMode`** (`present_form_edition.dart:246`). Le canal du socle **existe** ; les 9 lignes de l'hôte traduisent ses **deux booléens legacy**, ce qui est une règle d'hôte | ⚠️ **Reclassé** en RESTE À L'HÔTE |
| Catalogue étude §2.1 : les 3 ports IA « rendent la chaîne UI possible » | `ZFlashcardGenerationPort` a **5 consommateurs** dans le socle ; `ZMindmapGenerationPort` et `ZNoteSummaryPort` en ont **ZÉRO** (grep §3, ligne M-5/M-6) | ⚠️ **Asymétrie non dite** — décisive pour deux capacités du domaine |

**Périmètre revérifié** (toutes les valeurs de la carte §0 tiennent) : `presentation/features/smartnotes/**`
= **6 fichiers / 1 718 l.** (311+434+342+2+212+417) ; `smartnotes_module.dart` = **0 octet** ;
domaine+données = 3 fichiers / **823 l.** ; IFFD importe **22 paquets zcrud sur 41**.

---

## 1. DÉJÀ MIGRÉ — l'hôte consomme le canal

| # | Capacité / bloc | Canal du socle | Site chez l'hôte |
|---|---|---|---|
| D-1 | **Corps de note en Delta neutre** (`List<Map>` d'ops), coercition totale d'une `String` markdown | `ZSmartNote` (`zcrud_note/…/z_smart_note.dart:78`, `extends ZEntity with ZExtensible`), `normalizeNoteContentOps`, `kContentKey` | `z_backed_smart_note_repository.dart:52-53` (`show ZSmartNote, kContentKey, normalizeNoteContentOps`) |
| D-2 | **Formulaire de note déclaratif** — titre `multiline` 1-3 l. + corps `inlineMarkdown` 7-15 l. | `ZFieldSpec` / `ZFormController` / `DynamicEdition` / `ZTextConfig.textTransform` | `smartnote_zcrud_edition.dart:138-160` (2 `ZFieldSpec`) |
| D-3 | **Champ compact riche par registre** | `registerZMarkdownFields(kind inlineMarkdown → mode inline)` (`z_markdown_registration.dart:56`) | `z_iffd_field_registry.dart:101-103` |
| D-4 | 🔴 **Chrome + barre d'outils par défaut du champ compact (livré 3.21.0, il y a 1 jour)** — piège P-04 du catalogue édition | défauts posés par `registerZMarkdownFields` (dartdoc `:51-55` : « Omis ne veut pas dire nu ») + préréglage `ZRichTextToolbarConfig.inline` | **Déjà absorbé** : `z_iffd_field_registry.dart:105-140` documente le retrait de 18 lignes (`chrome` et `toolbarConfig` supprimés) le lendemain de leur écriture. `themedBarBackground: true` retiré parce que **mort** |
| D-5 | **Instructions IA en un composant paramétré** (2 dialogues legacy → 1) | `presentFormEdition` (`zcrud_screen`) + `ZEditionPresentation` (`zcrud_navigation`) + `ZCondition` | `smartnote_ai_instructions_zcrud_edition.dart:108-110`, 5 `ZFieldSpec` `:185-255` |
| D-6 | **Carte de note dans le hub d'étude** | `ZDefaultNoteCard` (`z_default_note_card.dart:73`, 23 params) | `study_tools_zcrud_adapter.dart:759-766` |
| D-7 | **Section « Notes » repliable, grille, état vide, bouton d'ajout** | `zStudyToolsSection` / `ZStudyToolsSectionSpec` (`z_study_tools_section_spec.dart:96`, 36 params) | `study_tools_zcrud_adapter.dart:750-778` |
| D-8 | **Réordonnancement persisté des notes** | `ZStudyToolsSectionSpec.onReorder` (`:937`) + `itemIds` (`:923`) + `reorderHandleMode` (`:985`) | `study_tools_zcrud_adapter.dart:774-777` |
| D-9 | **Codec de texte riche pluggable** (Markdown ⇄ Delta) | `ZCodec` / `ZDeltaCodec` / `ZMarkdownCodec` (`zcrud_markdown`) | `z_iffd_rich_text_codec.dart` (193 l.), posé `z_iffd_field_registry.dart:103` |
| D-10 | **Soft-delete et LWW hors-entité** | `ZSyncMeta` (`zcrud_core/…/sync/z_sync_meta.dart:20`, clés `is_deleted`/`updated_at`) | `z_backed_smart_note_repository.dart` (`FirestoreZNoteDataPath._isDeleted`, `:294`) |
| D-11 | **Catalogue de routes IA depuis le modèle d'hôte** | `ZChatRouteCatalogShape.suffixPairs` (`:43`), `ZChatRouteCatalogDecoder` (`:88`), `ZChatRouteCatalogPort` (`:105`) | `notebook_route_catalog_iffd.dart:42-105` — **mais seulement pour le Notebook** ; les 81 fichiers qui portent `IffdAiRouterModel` passent encore par le dépôt IA legacy |
| D-12 | **Menu d'actions d'item sur le vocabulaire du socle** (précédent, sur les **dossiers**) | `ZItemActionsMenu` + `ZItemAction` + `ZItemActionKind` + `ZMenuEntryTile.gridDelegate` | `folder_actions_menu_zcrud.dart:36-38`, 241 l., **testé** (`test/w8k/`, `test/w8p/`) — pas encore branché en production (grep : `FolderActionsMenuZcrudView` n'apparaît qu'en tests) |

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — le socle sait déjà le faire, l'hôte l'ignore

> Chaque ligne porte : l'**API exacte**, son `fichier:ligne` dans `packages/`, la **vérification
> du corps** (pas de la seule dartdoc), et le chiffrage des lignes d'hôte supprimées.

### M-1 🔴 Générer des flashcards depuis une note — toute la chaîne existe, y compris la preuve écrite par l'hôte

**API exacte.**

| Canal | `fichier:ligne` | Corps vérifié |
|---|---|---|
| `ZFlashcardGenerationPort.generateFlashcards` | `zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:289-295` | `abstract interface class`, rend `Future<ZResult<List<ZFlashcard>>>` |
| `ZFlashcardGenerationRequest` | `…/z_flashcard_generation_port.dart:113-125` | 9 champs : `content`, `count`, `languageTag`, `provenance`, `typesDistribution`, `instructions`, `modelId`, `resolvedSources`, `extra` (filtré par `zSanitizeExtra`, `:209`) |
| `ZNoteSource` | `zcrud_flashcard/lib/src/domain/z_flashcard_source.dart:93` | membre `sealed` de `ZFlashcardSource` ; `fromJson` décode `kind == 'note'` → `ZNoteSource(noteId:)` (`:66-67`) |
| `ZFlashcardGenerationController` | `zcrud_study/lib/src/presentation/z_flashcard_generation_controller.dart:84` | **lu ligne à ligne** : anti-double-tap (`:149-151`), jeton de péremption `_generation` (`:152`, `:197`), résolveurs de source appelés **à la soumission** (`:157-184`), `catch` sur port qui lève (`:189-195`), `Right([])` traité comme échec (`:202-205`), cartes rendues **éphémères** `id: null` (`:263-264`), commit délégué par `onGenerated` — **aucune écriture base** (`:243`) |
| `ZFlashcardGenerationSheet` | `zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:214` | 12 params ; `contextSources` (`:265`) documenté « documents du dossier, **notes**… » ; `acquisitionGestures` (`:270`) ; controllers créés **une** fois en `initState` (`:300-320`) |
| `ZGenerationSourceOption` | `…/z_flashcard_generation_sheet.dart:62-85` | `{label, provenance, resolveContent}` — `resolveContent` est un `ZGenerationSourceResolver` appelé **à la demande** |
| `ZResolvedGenerationSource` | `…/z_flashcard_generation_port.dart:43-46` | trois formes : `text`, `pagesContents` (**paginée partielle**), `provenance` |
| `ZFlashcardGenerationLauncher` | `…/z_flashcard_generation_sheet.dart:868` | l'affordance **disparaît** sans port (`resolvedPort`, `:893`) |
| Défauts purs | `z_flashcard_generation_defaults.dart:30/39/55/97` | `zDefaultGenerationCount = 10`, `zClampGenerationCount` bornes `[1,50]` |

**🔴 La preuve la plus forte est écrite par l'hôte lui-même.**
`iffd/test/qa-w2/ai_generation_parity_test.dart` (231 l.) est un tripwire écrit le 2026-08-05 qui
recense **4 capacités** du générateur legacy (`depuis-notes`, `depuis-document`, `charger-fichier`,
`scanner`) avec un drapeau `couvertParLeSocle`. **Grep négatif montré** :

```
$ grep -n "couvertParLeSocle: false" test/qa-w2/ai_generation_parity_test.dart ; echo "RC=$?"
RC=1
```

⇒ **aucune capacité n'est plus non couverte** depuis CR-IFFD-70 (v0.51.0). Le fichier le dit
lui-même (`:57-66`) : *« LE BRANCHEMENT RESTE À FAIRE […] Confondre "le socle offre" et "nous
consommons" est précisément le motif offert-non-passé, compté vingt-et-une fois. »*

**Et le site porté n'existe pas** :
```
$ ls lib/src/presentation/features/flashcards/zcrud/ai_generation_zcrud.dart
ls: … Aucun fichier ou répertoire de ce type
```
(le tripwire le nomme `kPorte`, `:88-89` — il attend ce fichier).

**Grep négatif montré — aucun canal de génération n'est consommé** :
```
$ grep -rn "ZFlashcardGenerationPort\|ZFlashcardGenerationSheet\|ZFlashcardGenerationController\
|ZFlashcardGenerationLauncher\|ZGenerationSourceOption\|ZResolvedGenerationSource\|ZNoteSource" \
  lib test --include='*.dart'
→ 4 lignes, TOUTES dans test/qa-w2/ai_generation_parity_test.dart (:5, :15, :53, :113),
  toutes en COMMENTAIRE. Zéro ligne dans lib/.
```

**Lignes d'hôte supprimées.** Le bloc dupliqué est : appel IA → `normalizedJsonString(result.data)`
→ `json.decode` → `fromMapList<FlashcardModel>` → remap → `saveFolderFlashcards` → `callback(false)`.

| Site vivant (source = note) | Étendue mesurée | Lignes |
|---|---|---:|
| `popup_menu_helpers.dart` | `:292-341` | **50** |
| `explain_ai_page.dart` | `:661-730` | **70** |
| `chatbot_conversation_screen.dart` | `:807-…` | ~55 |
| `ai_flashcards_generator_dialog_widget.dart` | `:1061-…` (+ `:1032/:1074/:1154`) | ~50 |
| *(mort, à supprimer de toute façon)* `smartnote_actions_dialog_widget.dart` | `:100-164` | *(65)* |

⇒ **≈ 225 lignes vivantes** dans le domaine notes. Le décodage défensif reste chez l'hôte, mais
**une seule fois**, dans son implémentation du port, au lieu de 4. Compteurs de contexte remesurés :
`normalizedJsonString(` = **22 sites / 10 fichiers** ; `fromMapList<FlashcardModel>(` = **13 sites /
9 fichiers** ; `saveFolderFlashcards(` = **14 sites**.

⚠️ **Ce que le port ne fait PAS** : il ne décode aucun JSON. `ZFlashcardGenerationPort` reçoit une
requête neutre et rend des `ZFlashcard`. Le `json.decode` + `fromMapList` reste du code d'hôte —
il devient **le corps unique** de l'implémentation du port, jamais un bloc en ligne.

### M-2 🔴 Le menu d'actions d'une note — le précédent est déjà écrit et testé dans le même dépôt

**API exacte.** `ZItemActionsMenu` (`zcrud_study/lib/src/presentation/z_item_actions_menu.dart:283`,
6 params, **grille 3 colonnes par défaut**, `menuBuilder` livré par CR-IFFD-32) ;
`ZItemAction` (`:147-193`, 10 params) ; `ZItemAction.toMenuEntry()` (`:246-254`) ;
`ZMenuEntryTile` (`zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:31`) et son
`gridDelegate` (`:81-96`, plancher `kZMenuMinTapTarget = 48` **non négociable**, `math.max` et non
un `assert`, `:92`) ; `ZActionMenu` (`zcrud_menu/…/z_action_menu.dart:18`, filtrage amont **site
unique**, `:58`).

**Corps vérifié.** `ZMenuEntry.isVisible => permitted && (onSelected != null || disabledReason != null)`
(`z_menu_entry.dart:103-104`) — `permitted: false` force l'**ABSENCE**, pas le grisage.
`ZMenuEntryTile` pose `Semantics(button, enabled, label, hint: disabledReason, excludeSemantics)`
(`:111-122`) et n'installe l'`InkWell` que si `onSelected != null && entry.isEnabled` (`:104`, `:132-134`).

**Le précédent, mesuré.** `iffd/lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart`
(**241 l.**) porte déjà le menu de **dossier** sur ces trois canaux (`:36-38`), avec ses gardes
(`test/w8k/folder_actions_menu_zcrud_test.dart`, `test/w8p/folder_actions_menu_a11y_test.dart`).
Son en-tête (`:60-76`) documente la mesure faite avant retrait de la couche de traduction :
*« `z_menu_entry.dart:118` : `isVisible => permitted && (…)` ⇒ `permitted: false` force donc l'ABSENCE ».*
**Il n'y a plus rien à mesurer : la même transposition s'applique aux 5 actions d'une note.**

**Lignes d'hôte supprimées.** `buildSmartNotePopupMenu` (`popup_menu_helpers.dart:269-491`, **223 l.**,
2 sites d'appel : `folder_study_tools_page.dart:781` et `:1780`) → ~90 l. de `List<ZItemAction>`.
⇒ **≈ 133 lignes**, plus le retrait définitif de `SmartnoteActionsDialogWidget` (417 l., mort).

⚠️ **Écart de comportement à annoncer à la QA** (le même que le portage dossier a signalé) :
`permitted: false` **retire** l'entrée. Le legacy des notes l'affiche à **0,7 d'opacité** et
l'ignore au clic. Ce n'est pas cosmétique.

### M-3 🔴 La règle d'absence par permission — 15 tuiles à 0,7 d'opacité

**API exacte.** `ZItemAction.permitted` (`z_item_actions_menu.dart:212`) ;
`ZFeatureAvailability.gate(featureKey, action)` (`zcrud_study/…/z_feature_availability.dart:63-64`,
corps : `isAvailable(k) ? action : null`) ; `ZMapFeatureAvailability` (`:94-109`) ;
`ZFeatureAvailabilityScope` (`:149`).

**Lignes d'hôte supprimées.** Motif `Opacity(opacity: <perm> ? 1 : 0.7, …, enabled: <perm>,
onTap: <perm> ? … : null)` — **15 sites** remesurés (`grep -rn "? 1 : 0.7\|? 1.0 : 0.7" lib | wc -l`
→ **15**), dont **5** dans `smartnote_actions_dialog_widget.dart` et 3 dans `mindmap_dialog_widgets.dart`.
⇒ **≈ 40 lignes** dans le seul périmètre notes, ≈ 180 l. si le motif est traité partout.

⚠️ Le socle **n'a aucun jeton d'opacité de menu**. Grep négatif montré :
```
$ grep -rn "Opacity\|opacity" zcrud_menu/lib ; echo "RC=$?"
RC=1
```
⇒ adopter le canal **change le rendu**. `disabledReason` remplace le grisage par une seconde ligne.

### M-4 🔴 Le dépôt Firestore générique — 137 lignes réécrites à la main

**API exacte.** `FirebaseZRepositoryImpl<T extends ZEntity>`
(`zcrud_firestore/lib/src/data/firebase_z_repository_impl.dart:156`, **1 174 l.**) et sa fabrique
`\.fromRegistry` (`:261`).

**Corps vérifié.** `_guard<R>` enveloppe tout en `ZResult` (`:805`) ; `watchAll`/`watch(ZDataRequest)`
rendent des `Stream<List<T>>` **nus** (`:823`, `:827`) ; `getAll`/`getById`/`count`/`save`/`softDelete`/
`restore` rendent `Future<ZResult<…>>` (`:913`, `:923`, `:960`, `:1009`, `:1036`, `:1040`) ;
`timestampFields` encode `Timestamp` avec une garde **exécutoire** qui soustrait `ZSyncMeta.reservedKeys`
même en release (`:203-206`) ; `ZDeletionSemantics.absentMeansAlive` + `legacyDeletedKey` couvrent
un corpus legacy sans `is_deleted` (`:57-81`).

**Le borne générique est satisfaite** : `class ZSmartNote extends ZEntity with ZExtensible`
(`zcrud_note/lib/src/domain/z_smart_note.dart:78`).

**Lignes d'hôte supprimées.** `FirestoreZNoteDataPath` (`z_backed_smart_note_repository.dart:272-408`,
**137 l.**) réimplémente `streamAll`/`streamOne`/`streamByIds`/`asyncCount`/`put`/`softDelete`/
`restore`/`hardDelete`. Sept des huit ont leur équivalent. S'y ajoute l'abandon de
`FirestoreDataState<T>` et de la fabrication d'échecs en `FirebaseException` (`_err`, `:465`),
contraire à AD-5. ⇒ **≈ 137 lignes**, plus la voie d'erreur remise sur `Either<ZFailure, T>`.

⚠️ **Une méthode sur huit n'a pas d'équivalent** : `hardDelete`. Grep négatif montré :
```
$ grep -rn "hardDelete" packages/*/lib --include='*.dart'
zcrud_chat_kernel/…/z_chat_action_executor.dart:56:  /// `hardDelete`, ni `purge`, ni `deleteForever`.
```
⇒ **une seule occurrence dans les 41 paquets, et c'est une dartdoc qui déclare l'absence
délibérée**. La suppression définitive reste à écrire chez l'hôte (cf. §3, M-11).

### M-5 Slot d'extrait sur la carte de note (capacité, pas lignes)

`ZDefaultNoteCard.excerpt` + `excerptMaxLines = 2` (`z_default_note_card.dart:78-79`, assert `≥ 1`
`:105-109`). IFFD ne passe que `title`/`subtitle`/`trailing`/`progress`/`onTap`
(`study_tools_zcrud_adapter.dart:759-766`) — l'extrait n'est jamais rendu. **0 ligne économisée**
(le socle « ne parse aucun rich-text ici », dartdoc `:120-122` : le texte brut est fourni par l'hôte),
mais une capacité rendue disponible sans code. Cf. §3 M-12 pour l'extraction manquante.

### M-6 Générer des flashcards depuis une **conversation** (adjacent, mal attribué par la carte)

`ZChatFlashcardGenerator.generateFromConversation` (`zcrud_chat_study/lib/src/domain/z_chat_flashcard_generator.dart:81-112`)
et `.generateFromMessage` (`:51-78`) ; `zStampChatProvenance` (`:153`) ; `zChatMessagesStudyText`
(`z_chat_flashcard_mapper.dart:69`). **Corps vérifié** : `_generate` (`:115-141`) capte une
implémentation d'hôte qui lève et la convertit en `Left(ZDomainFailure)` (`:123-129`).
Couvre `chatbot_conversation_screen.dart:807`. **Le paquet n'est ni importé ni déclaré** :
```
$ grep -rn "zcrud_chat_study" lib --include='*.dart' ; echo "RC=$?"   → RC=1
$ grep -n  "zcrud_chat_study" pubspec.yaml           ; echo "RC=$?"   → RC=1
$ grep -rn "zcrud_chat_study" test --include='*.dart'
test/qa-w2/notebook_parity_test.dart:148:  '(`zcrud_chat_study`, `zChatMessageGenerationRequest`).',   ← chaîne de message, pas un import
```

**Total M-1 → M-4 : ≈ 530 lignes d'hôte vivantes supprimables** (220 + 133 + 40 + 137).

---

## 3. MANQUE AU SOCLE — preuve d'absence par grep négatif montré

| # | Ce qui manque | Forme du canal | Paquet | Pourquoi l'hôte ne peut pas s'en passer | Bloque étude/révision ? |
|---|---|---|---|---|---|
| **M-7** | **Retour à la ligne souple non déclarable** (CR-IFFD-115) | **option de décodage** : `ZMarkdownCodec({ZSoftBreak softBreak})` — `space` (défaut, inchangé) / `lineBreak` | `zcrud_markdown` | Le corps d'une note IFFD n'est **pas** écrit par un auteur markdown : c'est du texte saisi à la touche Entrée. `_ZSoftLineBreakSyntax` (`z_markdown_codec.dart:283`) fait `parser.addNode(md.Text(' '))` (`:292`) et est enregistrée **inconditionnellement** (`:509`) ⇒ **tout retour à la ligne d'une note devient une espace**, à la lecture comme à la relecture | 🔴 **OUI** — un corpus de production de 127 valeurs `content` est lu de travers |
| **M-8** | **Pas de sous-titre au dialogue plein écran** (CR-IFFD-116) | paramètre `subtitle: String?` sur `showZRichTextFullscreenDialog` **et** `ZRichTextFullscreenDialog`, rendu sous le titre dans les deux présentations | `zcrud_markdown` | Le mode `inline` du champ de note ouvre ce dialogue ; plein cadre, il **remplace** l'écran d'origine et doit porter *sur quoi* + *quel champ*. Contournement écrit chez l'hôte : `'$titre — $sousTitre'` (`workflow_notes_zcrud_edition.dart:152-166`) — l'information survit, la hiérarchie non. **Quatrième surface du même motif** (après `ZFolderCard`/CR-28 et `ZSearchableAppBar`/CR-34) | non |
| **M-9** | **Géométrie du tableau markdown = décision fermée** (CR-IFFD-114) | échappatoire déclarative, sur le modèle de celle reçue par l'embed LaTeX | `zcrud_markdown` | Un tableau est un contenu de note courant ; sans échappatoire l'hôte ne peut ni approcher son rendu legacy ni s'en écarter | non |
| **M-10** | 🔴 **Déplacer un contenu vers un dossier / sous-dossier — RIEN au socle** | **assemblage** : sélecteur de destination (`ZDestinationPicker`) + application (`onMove(ref)`), avec le pli sous-dossier porté par `ZSubfolderRef` | `zcrud_study` (assemblage), primitives dans `zcrud_ui_kit` | **7 sites / ~320 l.** chez l'hôte, dont `smartnote_actions_dialog_widget.dart:319-378` (60 l.) ; `showFolderSelectionModelDialog(` = **10 appels / 8 fichiers** (remesuré). Le seul voisin du socle est `ZFlashcardListBatchMove` (`z_flashcard_list_view.dart:224`), **spécifique aux flashcards** et dont la destination vient d'un `resolveDestination` **fourni par l'hôte** (`:247`) | non, mais coûte 320 l. |
| **M-11** | **Aucune suppression définitive** | verbe `hardDelete` (ou décision explicite de ne pas en avoir, à documenter côté hôte) | `zcrud_core` (`ZRepository`) | `ZNoteDataPath.hardDelete` existe chez l'hôte (`z_backed_smart_note_repository.dart:262`) ; `ZRepository` s'arrête à `softDelete`/`restore` (`z_repository.dart:185`, `:189`). **Grep négatif** : `grep -rn "hardDelete" packages/*/lib` ⇒ **1 ligne, une dartdoc qui déclare l'absence** | non — c'est un refus assumé du socle |
| **M-12** | **Extraction de texte brut d'un corps riche** | fonction pure `zPlainTextOf(ops) → String` (ou `ZCodec.toPlainText`) | `zcrud_markdown` | Sans elle, `ZDefaultNoteCard.excerpt` (M-5) est inatteignable et l'hôte garde `_getContentPreview` (strip markdown, 50 car.). **Grep négatif** : `grep -n "^export" zcrud_markdown/lib/zcrud_markdown.dart` — aucun export d'extraction ; `ZMarkdownApi` (`z_markdown_api.dart:7-15`) n'expose que `version`/`coreApiVersion`. `toPlainText()` n'est appelé qu'**en interne** (7 sites, tous dans `z_markdown_reader.dart` / `z_markdown_field.dart`) | non |
| **M-13** | 🔴 **`ZMindmapGenerationPort` n'a AUCUN consommateur dans le socle** | **assemblage** : contrôleur + feuille + aperçu, sur le patron `ZFlashcardGenerationController`/`Sheet` | `zcrud_study` | La carte mentale depuis une note est **8 sites / ~250 l. vivantes** chez l'hôte (`popup_menu_helpers.dart:346-394` 49 l., `explain_ai_page.dart:496-556` 61 l., `chatbot_conversation_screen.dart:607-700` 94 l., `valuation_tool_model_actions_dialog_widget.dart:159-200` 42 l.). **Grep montré** : `grep -rn "ZMindmapGenerationPort" packages/*/lib` ⇒ **2 lignes** — sa déclaration (`z_mindmap_generation_port.dart:189`) et **une dartdoc** de `zcrud_chat_kernel/…/z_chat_generation_port.dart:21`. Aucun contrôleur, aucune feuille, aucun lanceur | 🔴 **OUI** — capacité #5 du domaine, non migrable malgré le port |
| **M-14** | 🔴 **`ZNoteSummaryPort` n'a AUCUN consommateur dans le socle** | idem M-13 : contrôleur + surface | `zcrud_study` | Capacité #6 (« Résumer avec instructions »). **Grep montré** : `grep -rn "ZNoteSummaryPort" packages/*/lib` ⇒ **2 lignes** — sa déclaration (`z_note_summary_port.dart:68`) et une dartdoc de `z_chat_generation_port.dart:20`. La requête ne porte d'ailleurs que `content`/`maxLength`/`languageTag`/`extra` (`:18-23`) : ni `summaryType`, ni `modelId` | 🔴 **OUI** |
| **M-15** | **Horodatage de soumission** (`createdAt`/`updatedAt` **d'entité**) | seam sur `presentFormEdition`/`ZEditionSubmitController` : `stampTimestamps` + horloge injectable | `zcrud_core` ou `zcrud_screen` | L'hôte repose la règle à la main : `adaptSmartNoteZcrudOutput` (`smartnote_zcrud_edition.dart:192-211`, 20 l.), parité `edition_screen.dart:402-403`. **Grep négatif** : `grep -rn "createdAt\|submittedAt\|onSubmitTimestamp\|zStampTimestamps\|touchUpdatedAt" zcrud_core/lib` ⇒ **0**. `ZSyncMeta` existe mais est **hors-entité** (`z_sync_meta.dart:24-25`), donc sans effet sur un champ métier | non |
| **M-16** | **Pas de fusion « carte de départ ⊕ saisie »** | option `includeInactive` / `mergeInitialValues` sur `presentFormEdition` | `zcrud_core` + `zcrud_screen` | `zNormalizeFormValues` **saute** tout champ `readOnly` et tout champ dont la condition est fausse (`z_form_values.dart:262-270`) ⇒ `aResumer` est **absent** de la carte quand « tout le document » est coché. L'hôte referme l'écart à la main : `_presenterInstructionsParLeSocle` (`smartnotes_dialogs.dart:412-434`, 23 l.). **Grep négatif** : `grep -rn "includeInactive\|mergeInitial\|keepHidden\|includeHidden\|withInitialValues" zcrud_core/lib zcrud_screen/lib zcrud_navigation/lib ; RC=1` | non |
| **M-17** | **Le codegen ne collecte pas les champs hérités** | branche « champs de la superclasse » dans `zcrud_generator`, ou décision explicite de refuser l'héritage | `zcrud_generator` | `SmartNoteModel extends FolderContentModel extends SubjectContentModel extends DynamicModel` : les 6 champs de base (`id`, `subjectId`, `folderId`, `subFolderId`, `creatorId`, `createdAt`) vivent dans la base. Le générateur le dit lui-même (`zcrud_model_generator.dart:646-648`) : *« Un champ déclaré dans une classe de base n'est **pas collecté** par le générateur »* — il ne fait que **signaler** la perte (`_collectInheritedSilentlyLost`, `:652`). ⇒ annoter `SmartNoteModel` **perdrait 6 champs sur 12**. C'est pourquoi je **ne classe pas** la sérialisation manuelle (109 l.) en migrable | non |
| **M-18** | **`ZConfirmDialog` sans ornement** | slot `icon`/`leading` (`IconData?` ou `Widget?`) sur `ZConfirmDialog` et `showZConfirmDialog` | `zcrud_ui_kit` | Le canal existe (`z_confirm_dialog.dart:36`, `showZConfirmDialog` `:129`, `ZConfirmTone.destructive` `:71-73`, cibles 48 dp `:84`, `:91`, `Semantics(scopesRoute, namesRoute)` `:108-114`) et **couvre la sémantique**. Mais le corps est un `AlertDialog` **nu** : ni titre stylé, ni icône. Le `buildConfirmDialog` de l'hôte (`forms_utils.dart:480`) rend une pastille à dégradé 64×64 + `Icons.help_outline_rounded` + titre « Confirmation ». **36 sites / 20 fichiers** (remesuré) attendent cette forme. **Grep négatif** : `grep -rn "ZConfirmDialog\|showZConfirmDialog\|ZConfirmTone" iffd/lib test` ⇒ **1 ligne, un commentaire de test** | non |
| **M-19** | **Aucune recherche sur une section d'outils d'étude** | `searchQuery` / `matches` sur `ZStudyToolsSectionSpec`, ou seam de filtre sur `ZStudyToolsPage` | `zcrud_study` | Capacité #9 du domaine (chercher une note par titre ou contenu, `folder_study_tools_page.dart:441-452`, `:909-915`). **Grep négatif** : `grep -in "search" zcrud_study/lib/src/presentation/z_study_tools_section_spec.dart ; RC=1` — aucune des 36 propriétés | non |
| **M-20** | **`ZNoteAudio` ne porte pas le texte de la transcription** | *(déjà tranché par le socle)* — 4ᵉ champ à loger en `extra` | `zcrud_note` | IFFD persiste **4** champs (`audioText`, `audioUrl`, `audioPath`, `audioTextHash`) ; `ZNoteAudio` en porte **3** (`z_note_audio.dart:85-98`). La dartdoc du canal le déclare : *« un consommateur legacy porte en plus `audioText: String?`, sans équivalent lex : il tombe dans [extra] »* (`:26`). ⇒ **ce n'est pas un manque non résolu**, c'est un contrat explicite — signalé pour qu'on ne le redécouvre pas | non (UI IFFD commentée, 27 l.) |

---

## 4. RESTE À L'HÔTE — règle métier IFFD, le socle ne porte pas de règle métier

| # | Ce qui reste | Preuve / mesure | Pourquoi ce n'est pas au socle |
|---|---|---|---|
| **H-1** | **Double format de `content`** — Markdown **ou** Delta JSON selon l'historique d'édition, avec `iffd_content` faisant foi | corpus de prod : **127 valeurs, 0 Delta** ; `ZBackedSmartNoteMapper` (`z_backed_smart_note_repository.dart:108-238`, 131 l.), 3 marqueurs de fidélité `iffd_folder_id`/`iffd_title`/`iffd_content` | Dette de schéma IFFD. Le socle a déjà fait sa part : `normalizeNoteContentOps` **préserve verbatim** une `String` markdown, et `ZNoteContentFaithChannel` (`z_note_faith_channel.dart:84`) écrit les deux canaux dans la **même** remontée — canal offert, jamais consommé (grep : `ZNoteContentFaithChannel` = **0 site** chez IFFD) |
| **H-2** | **Double appartenance dossier OU matière** — `folderId`/`subFolderId` **ou** `subjectId`, jamais les deux ; booléen `subjectToolPage` propagé dans toutes les signatures | purge de clés `smartnotes_dialogs.dart:105-111` ; `subjectId` logé en `extra['iffd_subject_id']` | Le socle ne connaît que `folderId`/`subFolderId`. L'exclusivité est un **invariant produit** IFFD, pas une préférence de rendu |
| **H-3** | **`isSubFolder ? parentId : id`** — la dérivation du couple `(folderId, subFolderId)` | réécrite à chaque site de déplacement (7×) et à la création de mindmap (`smartnote_actions_dialog_widget.dart:212-219`) | La **règle** est propre au modèle de dossier IFFD. En revanche le **geste** (choisir une destination, écrire) est un assemblage manquant — cf. M-10 |
| **H-4** | **`ucFirstLegacy` partout** — le moteur legacy capitalise tout champ texte et tout libellé d'option de `select` sauf `country` | `edition_screen.dart:1015-1020`, `:1745` ; reposé champ par champ via `ZTextConfig.textTransform` | Contrainte de **parité de migration**, pas un besoin durable. Le canal (`textTransform`) est déjà consommé |
| **H-5** | **Mode de présentation dérivé des deux booléens legacy** (`dialog` / `fullscreenDialog`) | `smartNoteAiInstructionsForcedMode` (`smartnote_ai_instructions_zcrud_edition.dart:269-277`, 9 l.) | 🔴 **Reclassé depuis « manque au socle »** : `presentFormEdition` **expose** `forcedMode: ZEditionPresentation?` (`present_form_edition.dart:246`). Les 9 lignes traduisent deux booléens **d'IFFD** vers cet enum. C'est exactement le bon endroit |
| **H-6** | **`SummaryType` + composition d'instructions en français codées en dur** | `smartnotes_dialogs.dart:277-285`, `:381-387` | Prompt métier non localisé |
| **H-7** | **ACL par ressource de dossier** croisant créateur, propriétaire, **année académique** et `AppUserPermissions` | `folder_resource_access_service.dart` (364 l.), contexte `…Context.forNote(…)` lisant `accademicYear` | Modèle d'autorisation maison. Seule sa **projection** sur les affordances est migrable (M-3) |
| **H-8** | **Décodage défensif de la réponse IA** (`normalizedJsonString` + `json.decode` + `fromMapList`) | 22 sites / 10 fichiers | Le format de réponse dépend du backend IA d'IFFD. Migrer M-1 ne le supprime pas : il **descend** dans l'implémentation unique de `ZFlashcardGenerationPort` |
| **H-9** | **~888 lignes de code mort** (41 % du périmètre présentation+dialogues) | `SmartnoteActionsDialogWidget` 417 l. · `showSmartNoteActionsDialog` 39 l. · `showSummaryCustomInstructionsDialig` 120 l. · `showMindmapCustomInstructionsDialig` 100 l. · `NoteSelectorDropdown`+`NoteSelectorState` 212 l. · `smartnotes_module.dart` 0 o. Confirmé par le plan QA de l'hôte : le drapeau `smartNoteAiInstructions` est **🔕 INOBSERVABLE** (`qa-plan-comparaison-legacy-zcrud.md:340-344`) | Ménage d'hôte. À faire **avant** M-2, sinon on porte un menu mort |

---

## 5. Bilan chiffré

| Catégorie | Nombre | Lignes d'hôte concernées |
|---|---:|---:|
| DÉJÀ MIGRÉ | **12** | — |
| 🔴 MIGRABLE AUJOURD'HUI | **6** (dont 4 chiffrées) | **≈ 535 vivantes** (225 + 133 + 40 + 137) |
| MANQUE AU SOCLE | **14** (dont **3 bloquent une capacité d'étude/révision** : M-7, M-13, M-14) | ≈ 570 non résorbables aujourd'hui (250 mindmap + 320 déplacement) |
| RESTE À L'HÔTE | **9** | ≈ 888 de code mort à supprimer, + les règles métier |

**Ordre de traitement recommandé** — par rendement mesuré, et parce que chaque étape est
indépendante des autres :

1. **H-9** (supprimer les 888 l. mortes) — sinon M-2 porterait un menu inatteignable.
2. **M-1** (flashcards depuis une note) — le tripwire de l'hôte dit déjà que tout est couvert,
   le site porté n'existe pas, ≈ 225 l. ⇒ **le meilleur rapport preuve/gain du domaine**.
3. **M-2 + M-3** (menu de note + règle d'absence) — le précédent dossier est écrit et testé, ≈ 173 l.
4. **M-4** (dépôt Firestore générique) — ≈ 137 l., et remet la voie d'erreur sur `Either<ZFailure, T>`.
5. **CR à émettre** : **M-7** (`softBreak`) d'abord — c'est le seul manque qui **fausse la lecture
   d'un corpus de production** ; puis **M-13/M-14** (assemblages de génération carte mentale et
   résumé), qui sont la moitié restante de la duplication du domaine.
