# Confrontation — domaine « IA : assistant, chatbot, génération, explication, routeurs » (IFFD × zcrud v3.21.0)

Mesuré le **2026-08-26**. Hôte : `/home/zakarius/DEV/iffd`, branche `feat/migration-zcrud`,
HEAD `65d1af9`, **lecture seule**. Socle : `/home/zakarius/DEV/zcrud`, `v3.21.0`, HEAD `cc276c154`.

Matière : `carte-ia-chat-generation.md` (36 758 o, présent) et les **cinq** catalogues
`capacites-zcrud-*.md`. **Aucun des deux n'a été cru sur parole** : les §« Corrections » ci-dessous
listent **six** affirmations de catalogue démenties par le disque.

---

## 0. Chiffres de cadrage

| Mesure | Valeur | Obtention |
|---|---:|---|
| Périmètre du domaine chez l'hôte | 80 fichiers / 32 583 l | carte, recontrôlée par sondage |
| Paquets zcrud déclarés par l'hôte | **25** | `grep -oE "^  zcrud_[a-z_]+" iffd/pubspec.yaml \| sort -u` |
| Lignes `ref: v3.21.0` | **48** | `grep -c` — l'hôte est **à jour du socle** |
| Dernier commit **fonctionnel** du chat | `fe0d9311d`, **v3.11.0**, 2026-08-23 | `git log -- packages/zcrud_chat*/lib` |
| CR ouvertes visant chat/IA | **0** | 114/115/116 ouvertes, toutes `zcrud_markdown` ; 117-120 « RETIRÉE AVANT ÉMISSION » |
| **Lignes d'hôte supprimables aujourd'hui** | **≈ 4 900** | somme du tableau § 2 |
| Lignes supprimables **sous condition** (modèle de routeur) | ≈ 1 120 | § 2 bis |

🔴 **Le contexte daté du brief est faux pour cette aire.** Les versions 3.13 → 3.21 (24-25 août)
ne touchent **aucun** `lib/` de chat : `git log --oneline v3.12.0..HEAD -- packages/zcrud_chat*`
rend 9 commits qui ne modifient que 6 `pubspec.yaml` (22 insertions / 22 suppressions). La fenêtre
utile est **v3.2.0 → v3.11.0**. Le catalogue IA l'avait déjà établi ; je le confirme.

---

## 1. DÉJÀ MIGRÉ — l'hôte consomme le canal

Le Notebook porté est la surface la plus intégrée du dépôt : **22 fichiers / 5 532 lignes**.

| Canal du socle | Site chez l'hôte |
|---|---|
| `ZChatNotebookController` | `notebook_ports_iffd.dart:208` ; `notebook_page_zcrud.dart:145` |
| `ZChatNotebookView` | `notebook_zcrud.dart:763` |
| `ZChatConversationScreen(transcript:)` | `assistant_chat_zcrud_mount.dart:26` |
| `ZChatTranscriptPort` → écriture réelle | `notebook_transcript_iffd.dart:100` (`repository.create`) |
| `ZChatMaterialComposer` (5 sites) / `ZChatMaterialSettingsSheet` (4) / `ZChatSettingsController` (12) | `notebook_zcrud.dart:792` ; `notebook_settings_iffd.dart:34` |
| `ZChatCorpusOption` + `ZChatCorpusScope` | `notebook_settings_iffd.dart:56-63` ; `notebook_byte_opener_iffd.dart:99` |
| `ZChatArtifactRegistry` (4) / `Declaration` (6) / `Spec` (13) / `zChatArtifactSpecsOf` (4) | `notebook_artifact_registry_iffd.dart` ; `notebook_page_zcrud.dart:358` |
| **`artifactMenuBuilder`** (seam de `ZChatArtifactBar`) | `notebook_zcrud.dart` → `buildIffdArtifactPopupMenu` |
| **`ZChatTileShell`** + `zChatPrecedingRequestTopic` + `topicTrailing` | `notebook_page_zcrud.dart:346-360` |
| **`ZChatMarkdownRenderer(styleSet:)`** | `notebook_page_zcrud.dart:312` ; `assistant_chat_zcrud_mount.dart:141` |
| `ZChatRouteSession` (5) + `ZChatRouteCatalogShape.suffixPairs` + **`taskAliases`** | `notebook_route_catalog_iffd.dart:43-58` |
| **`ZAllowAllChatRouteGate`** | `discovry_page_controller.dart:649` |
| `ZChatConversationList` / `ZChatConversationTile` | `conversation_list_zcrud.dart:103` ; `conversation_item_zcrud.dart` |
| `ZIffdTextStreamPort` (7) / `ZSfAssistShellRenderer` (2) | `notebook_ports_iffd.dart:207` ; `notebook_page_zcrud.dart:307` |
| `ZChatGenerationStyle` (27) / `ZChatCustomAction` (8) / `ZChatRegenerateAction` (2) / `ZChatActionImpact` (2) | `notebook_capabilities_iffd.dart`, `notebook_variants_iffd.dart` |
| `ZChatArtifactGenerationPort` **implémenté** par l'hôte | `notebook_artifact_generation_iffd.dart:48` |
| `ZSubListConfig` + `ZAcl` + `ZSubListSeamRegistry` (formulaire de routeur) | `ai_router_zcrud_edition.dart:238-317`, `:308-317` (une boucle pour 12 groupes) |
| `ZFormOnly` / `ZFormOnlyController` / `presentFormEdition` (10 sites) | `ai_expert_zcrud_edition.dart:68` |
| `ZMultiFlashcardEditor` | `multi_flashcard_editor_zcrud.dart:172` |

### 🔴 Six corrections aux catalogues

| Affirmation de catalogue | Disque |
|---|---|
| IA § 11 #7 — « `taskAliases` le plus susceptible d'être ignoré » | **consommé**, `notebook_route_catalog_iffd.dart:58` |
| IA § 11 #16 — « `styleSet` : le seul canal… non consommé » | **consommé**, 2 sites (`:312`, `:141`) |
| IA § 11 #17 — « `ZChatTileShell.topicTrailing` non consommé » | **consommé**, `notebook_page_zcrud.dart:346-352` |
| IA § 11 #6 — « `ZChatRouteGate` non branché » | **branché** en `ZAllowAllChatRouteGate` (`:649`) — le piège `ZDenyAllChatRouteGate` est **évité** |
| IA § 9 — « `ZChatArtifactBar` aucun site » | vrai pour le **widget**, faux pour son **seam** `artifactMenuBuilder`, consommé |
| IA § 11 #14 — « `ZChatSpeechChain` : zéro site, la chaîne de repli devient une donnée » | **inapplicable** : `grep -rn "flutter_tts" iffd/lib` → **RC=1**. Le TTS d'IFFD est **serveur** (`TTSProvider` = paramètre de requête, `ai_repository.dart:121`), pas une synthèse locale |

⚠️ `zChatRunArtifactGeneration` à **0 site hôte n'est PAS un manque** : la séquence gardée est
appelée **par le socle** depuis `ZChatNotebookController`. Un catalogue qui la classe « inconsommée »
se trompe de sens de l'appel.

---

## 2. 🔴 MIGRABLE AUJOURD'HUI

Chaque ligne porte l'API exacte, son `fichier:ligne` sous `packages/`, la **preuve que le corps fait
ce qu'on lui prête** (pas seulement sa dartdoc), et le grep négatif côté hôte.

### 2.1 `ZFlashcardGenerationSheet` — la plus grosse économie du domaine

| | |
|---|---|
| **API** | `ZFlashcardGenerationSheet` + `ZFlashcardGenerationPort` + `ZGenerationSourceOption` + `ZSourceAcquisitionGesture` + `ZFlashcardGenerationController` |
| **Preuve socle** | `packages/zcrud_study/lib/src/presentation/z_flashcard_generation_sheet.dart:216` (ctor), `:62` (option de source), `:100` (geste d'acquisition), `:403-412` ; port `packages/zcrud_study/lib/src/domain/z_flashcard_generation_port.dart:289` ; contrôleur `z_flashcard_generation_controller.dart:87` |
| **Corps lu** | `:403-412` : « sans `resolveContent` ⇒ source **par référence** — couvre `…FromWholeDocument` » ; `:56-58` le contenu **n'est résolu qu'à la soumission** ; bornes `[1,50]` et répartition déléguées à `z_flashcard_generation_defaults.dart` (aucun littéral dans la feuille) |
| **Ce que ça remplace** | `ai_flashcards_generator_dialog_widget.dart` — **1 238 l**, trois onglets (`_buildDocumentsTab:280`, `_buildSubjectsTab:671`, `_buildTextTab:889`), zone de dépôt `:328`, zone de scan `:443`, chips de tags `:835`, bouton de génération `:929`, et trois appels de dépôt `:1061`, `:1140`, `:1195` |
| **Grep négatif hôte** | `grep -rn "ZFlashcardGenerationSheet\|ZFlashcardGenerationController\|ZFlashcardGenerationRequest\|ZGenerationSourceOption" iffd/lib` → **0 ligne** (seul `ZMultiFlashcardEditor` sort, ailleurs) |
| **Lignes économisées** | ≈ **1 050** (il reste ≈ 190 l : libellés injectés, options de source, implémentation du port) |
| **Frottement** | La feuille est *Material* ; les zones dépôt/scan deviennent deux `ZSourceAcquisitionGesture` (`acquire` rendant `Right(null)` sur annulation, `:112-119`) |

### 2.2 `ZChatNotebookScreen`

| | |
|---|---|
| **API** | `ZChatNotebookScreen` — **58 paramètres nommés** |
| **Preuve socle** | `packages/zcrud_chat/lib/src/presentation/view/z_chat_notebook_screen.dart:154`, ctor `:165-223` |
| **Corps lu** | `:157-165` — 18 paramètres **lus une fois** à la création du contrôleur ; seuls `readOnly` et `toolCatalog` sont suivis. `composerBuilder` est un `ZChatNotebookComposerBuilder(context, controller, settings)` (`:123-127`) : **le contrôleur est atteignable**, donc le picker « joindre un document » de l'hôte (`notebook_page_zcrud.dart:290-299`, qui lit `_nb.chat.attachmentIds`) reste exprimable. `headerBuilder` reçoit aussi le contrôleur (`:147-150`, appel `:552`) |
| **Ce que ça remplace** | `notebook_zcrud.dart:619-926` (`NotebookZcrudView`, **308 l / 129 de code**) + l'`initState`/`dispose`/`_vue` de `notebook_page_zcrud.dart:132-376` + `buildIffdNotebookController` (`notebook_ports_iffd.dart:187-228`, 42 l / 38 de code) |
| **Grep négatif hôte** | `grep -rn "ZChatNotebookScreen" iffd --include='*.dart'` → **0 ligne**. Seule occurrence du dépôt : `docs/plan-notebook-externalisation.md:812` |
| **Lignes économisées** | ≈ **330** (⚠️ le « ~1 900 » que l'hôte s'écrit à lui-même est **surestimé** : `NotebookZcrudView` **délègue déjà** à `ZChatNotebookView` — ce ne sont pas 1 900 lignes de rendu maison) |

### 2.3 `ZCrudScreen` — les deux pages de liste jamais portées

| | |
|---|---|
| **API** | `ZCrudScreen<T extends ZEntity>` — 64 paramètres, `ZCrudSource.repository` / `.items` / `.readOnlyRepository` |
| **Preuve socle** | `packages/zcrud_screen/lib/src/presentation/z_crud_screen.dart:180` (classe, 4 428 l) ; cas déclaratifs `:160-178` |
| **Corps lu** | La contrainte `T extends ZEntity` ne coûte **qu'un getter** : `ZEntity` déclare `String? get id` et **rien d'autre** (`zcrud_core/lib/src/domain/entity/z_entity.dart:17-24`) — `AiExpert`, `IffdAiRouterModel` et `ChatbotConversation` le portent déjà |
| **Ce que ça remplace** | `ai_experts_page.dart` **1 330 l** (`build` de 1 292 l) + `ai_routers_page.dart` **803 l** (`build` `:38→637`, 599 l) |
| **Grep négatif hôte** | `grep -rn "\bZCrudScreen\b\|\bDynamicList\b\|\bZListRenderer\b" iffd/lib` → **0 ligne**. L'hôte ne consomme de `zcrud_screen` que `ZFormOnly` / `ZFormOnlyController` (10 sites) |
| **Lignes économisées** | ≈ **1 700** |

### 2.4 La feuille d'outils déclarative

| | |
|---|---|
| **API** | `ZChatToolCatalog` + `.resolve()` + `ZChatToolEntry` + `ZChatToolState` + `ZChatToolController` + `zChatToolSettingsEntries` + `ZChatMaterialToolsSheet` + `ZChatMaterialToolTile` |
| **Preuve socle** | `zcrud_chat_kernel/lib/src/domain/tools/z_chat_tool_catalog.dart:177`, `resolve` `:217`, `activeCount` `:165` ; `z_chat_tool_entry.dart:215`, règles avec raison `:169` ; `z_chat_tool_state.dart:89` — **six natures dont un cycle 0..N** (`:212`) ; `zcrud_chat/…/tools/z_chat_tool_controller.dart:107` (tranche par entrée) ; `…/tools/z_chat_tool_settings_adapter.dart:66` ; `zcrud_chat_material/…/z_chat_material_tools_sheet.dart:40`, tuile `z_chat_material_tool_tile.dart:52` |
| **Corps lu** | `resolve()` calcule **une fois** visibilité motivée, grisage **avec sa raison**, ordre, comptage agrégé, actifs et recherche — pour les **deux** surfaces (bande + feuille) |
| **Ce que ça remplace** | Legacy `ToolsSheet` + `ToolTile` + `ToolNumberInputTile` + `ToolSelectTile` + `MinMaxFormatter` + `_ValueNotifierBuilder` (`chatbot_conversation_screen.dart:4686-5356`, **670 l**) ; côté contrôleur : six bascules identiques de 4 l (`discovry_page_controller.dart:896-923`), le cycle `toggleThinking` 0→5 (`:947-955`) et le comptage `toolsCount` (`:929-940`) — le socle porte **exactement** ces trois formes |
| **Grep négatif hôte** | `grep -rn "ZChatToolCatalog\|ZChatToolController\|zChatToolSettingsEntries\|ZChatMaterialToolsSheet\|ZChatToolEntry" iffd/lib` → **0 ligne** |
| **Lignes économisées** | ≈ **600** |
| **Frottement** | Les familles **standard** (corpus, longueur, réflexion, capacités) restent sur `ZChatSettingsSheet` — une garde v3.7.0 interdit de les redéclarer en outils d'hôte. À réserver à `scrapeWebResults`, à l'effort de réflexion et au choix d'expert |

### 2.5 `ZChatComputeEffort` — l'effort, sur le bon axe

| | |
|---|---|
| **API** | `ZChatComputeEffort(int level)`, bornes `min=1` / `max=5`, projections `low`/`medium`/`high` |
| **Preuve socle** | `zcrud_chat_kernel/lib/src/domain/ai/z_chat_compute_effort.dart:37`, écrêtage `:44-45`, bornes `:48-52`, projections `:57-62` |
| **Corps lu** | L'écrêtage est **dans le constructeur** (`level < min ? min : (level > max ? max : level)`), pas dans un `assert` : une valeur corrompue est **ramenée**, jamais levée. La dartdoc `:16-18` nomme **`WorkflowEffort`** comme le symbole ambigu à éviter — c'est le nom exact du type d'IFFD |
| **Ce que ça remplace** | `WorkflowEffort` Mini/Plus/Pro (`ai_models.dart:119-137`) et `thinkingEffort` 0-5 (`discovry_page_controller.dart:938-953`) — **le même axe, le même intervalle** |
| **Grep négatif hôte** | `grep -rn "\bZChatComputeEffort\b" iffd/lib` → **0 ligne** |
| **Lignes économisées** | ≈ **40** |
| **⚠️ Frottement réel** | `thinkingEffort == 0` signifie « réflexion désactivée » ; le socle borne à 1. Le 0 se porte en **capacité** (`kZChatCapabilityWebSearch` et voisines, `z_chat_generation_settings.dart:78`), pas en effort. Une transposition naïve `0 → ZChatComputeEffort(0)` rendrait **1** et activerait la réflexion en silence |

### 2.6 États de contenu (`zcrud_ui_kit`) et action de groupe

| | |
|---|---|
| **API** | `ZEmptyState` / `ZLoadingState` / `ZErrorState` / `ZContentStateView` ; `ZChatConversationList.groupActionsBuilder` + `ZChatGroupAction` |
| **Preuve socle** | `zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:31, 75, 127, 180` ; `z_content_state.dart:13` ; `zcrud_chat/…/view/z_chat_conversation_list.dart:131`, `:105` |
| **Ce que ça remplace** | `folder_conversations_widget.dart` (**218 l**) : **aucun** état de chargement, **aucun** état d'erreur, vide → `SizedBox.shrink()` (`:138`), `Column(children: …map())` non virtualisé (`:145-150`), `EdgeInsets.only(left:)` (`:142`, violation RTL). Et `chatbot_document_selector_dialog_widget.dart` (**842 l**, 9 `StreamBuilder` imbriqués à `:72, 96, 175, 182, 368, 425, 468, 643, 707`) |
| **Grep négatif hôte (états)** | `grep -rn "ZEmptyState\|ZLoadingState\|ZErrorState\|ZContentStateView\|ZPageShell" iffd/lib` → **0 ligne** |
| **Grep négatif hôte (sélecteur)** | `grep -n "hasError\|ConnectionState" chatbot_document_selector_dialog_widget.dart` → **RC=1** — zéro état traité en 842 lignes |
| **Lignes économisées** | ≈ **200** (le sélecteur, lui, **gagne** du comportement plutôt qu'il n'en perd des lignes) |

### 2.7 `zChatConversationActions`

| | |
|---|---|
| **API** | `zChatConversationActions` — descripteurs d'action **absents quand leur rappel est nul** |
| **Preuve socle** | `zcrud_chat/lib/src/presentation/view/z_chat_conversation_actions.dart:109`, clés `:198` |
| **Ce que ça remplace** | `conversation_actions_menu.dart` (**157 l**) : renommer `:116`, supprimer `:125`, aiguillage `userInfo` `:136-138` |
| **Grep négatif hôte** | `grep -rn "zChatConversationActions" iffd/lib` → **0 ligne** |
| **Lignes économisées** | ≈ **120** |
| **⚠️ Réserve** | La **suppression** de l'hôte est physique (`:94-96` : `repository.delete` + `deleteConversationMessages`). Voir § 3.3 |

### 2.8 `ZChatExportService`

| | |
|---|---|
| **API** | `ZChatExportService.exportConversation` / `.shareConversation` / `.suggestedFileName` ; `ZChatExportFormat` (markdown, plainText, html, **references**, pdf) ; coutures `ZChatPdfComposer` / `ZChatExportSink` |
| **Preuve socle** | `zcrud_chat/lib/src/presentation/export/z_chat_export_service.dart:129, 149, 220, 260` ; `export/z_chat_export_format.dart:10` ; `export/z_chat_export_ports.dart:37, 70` |
| **Ce que ça remplace** | Les trois copies manuelles du fil : `chatbot_conversation_screen.dart:107` (texte), `:114` (texte sans gras, `replaceAll("**","*")`), `:127` (html). Le socle rend **le même triplet** plus `references` dédupliquées, **à l'échelle de la conversation** |
| **Grep négatif hôte** | `grep -rn "ZChatExportService\|ZChatExportFormat" iffd/lib` → **0 ligne** |
| **Lignes économisées** | ≈ **60**, plus une capacité que l'hôte n'a pas |
| **Frottement** | `convert_markdown_to_pdf` et `convert_flashcards_to_pdf` (`ai_repository.dart:66-68`) sont **serveur** : ils restent, ou se branchent en `ZChatPdfComposer` |

### 2.9 La voie codegen sur les cinq modèles

| | |
|---|---|
| **API** | `@ZcrudModel(kind:, fieldRename:)`, `@ZcrudField` (18 paramètres), `@ZcrudId`, `@ZcrudIgnore`, **`ZPersistAs.timestamp`** |
| **Preuve socle** | `zcrud_annotations/lib/src/domain/annotations/zcrud_model.dart:151` ; `zcrud_field.dart:52` ; `z_persist_as.dart:16` ; générateur `zcrud_generator/lib/src/zcrud_model_generator.dart` — émission de `toMap`/`copyWith` `:978`, du registrar `:1184`, de **`$XxxTimestampFields`** `:1237` |
| **Corps lu** | `$XxxTimestampFields` est la métadonnée que `FirebaseZRepositoryImpl.timestampFields` (`zcrud_firestore/…/firebase_z_repository_impl.dart:167`) applique pour écrire le format natif — **c'est le canal qui retire `Timestamp` du domaine sans changer le format persisté** |
| **Ce que ça remplace** | 677 l de `copyWith`+`toMap`+`fromMap`+`props` (65 % des 1 044 l des 5 modèles) et **16 `Timestamp`** dans le domaine : `chatbot_conversation.dart` 8 (dont l'`import cloud_firestore` `:4`), `chatbot_message.dart` 4, `ai_expert.dart` 4 |
| **Grep négatif hôte** | `grep -rn "@ZcrudModel\|@ZcrudField\|@ZcrudId" iffd/lib/ai_assistant iffd/lib/src/domain/models/ai` → **RC=1** ; `zcrud_generator` **absent** du `pubspec.yaml` |
| **Lignes économisées** | ≈ **677** |
| **⚠️ Frottement** | Contrat cassant en vigueur : toute classe `@ZcrudModel` doit déclarer `Xxx.fromMap(Map<String,dynamic>)` **de domaine**, et une classe `ZExtensible` doit peupler **et** ré-émettre `extra` — garde d'exécution levant un `StateError` **hors `assert`** (`zcrud_generator/CHANGELOG.md:154-166`) |

### 2.10 `zcrud_chat_study` — le pont conversation ↔ SRS

| | |
|---|---|
| **API** | `ZChatFlashcardGenerator`, `zStampChatProvenance`, `zChatMessageGenerationRequest`, `zChatMessageStudyText`, `ZStudyPool` / `zBuildStudyPool`, `zIsChatStudyLaunchMode` |
| **Preuve socle** | `packages/zcrud_chat_study/lib/src/domain/z_chat_flashcard_generator.dart:36`, `:153` ; `z_chat_flashcard_mapper.dart:53, 89, 113, 137` ; `z_chat_study_pool.dart:54, 83, 144, 157` ; `z_chat_study_launch.dart:51`. Paquet à `version: 3.21.0` |
| **Ce que ça apporte** | L'estampillage **défensif** de la provenance conversationnelle, et un **pool de session = cartes du dossier ∪ cartes de la conversation, dédoublonnées** — capacité que l'hôte n'a pas. Aujourd'hui la génération de cartes depuis un message passe par `IffdArtifactGenerationPort` avec une répartition **codée en dur** (`notebook_artifact_generation_iffd.dart:41-45`) |
| **Grep négatif hôte** | `grep -rn "zcrud_chat_study\|ZChatFlashcardGenerator" iffd` → **0 ligne** ; le paquet n'est **ni déclaré ni surchargé** dans `iffd/pubspec.yaml` |
| **Lignes économisées** | ≈ **100**, et **une capacité d'étude débloquée** (réviser depuis une conversation) |

### 2.11 Canaux à coût nul et à gain de qualité

| Canal | `fichier:ligne` socle | Preuve d'absence hôte | Effet |
|---|---|---|---|
| **19 jetons `chat*` de `ZcrudTheme` sur 20** | `zcrud_core/…/theme/z_theme.dart:1852-1976` | boucle `grep -rn "\b<jeton>\b" iffd/lib` sur les 20 noms → seul `chatComposerActiveAccent` sort (**2 sites**) | bulles, capacités, palette d'occupation, chrome complet du composer, accents de longueur, emphase de sélection — **sans remplacer un widget** |
| `ZChatLiveLabels` | `zcrud_chat/…/z_chat_live_labels.dart:30` | `grep -rn "ZChatLiveLabels" iffd/lib` → **0** | l'hôte prend le repli **silencieux** : aucune annonce d'accessibilité pendant le flux. À rapprocher des **0 `Semantics(`** dans 23 303 l de legacy |
| **`ZChatCorpusScope.audit` + `ZChatCapabilityAudit`** | `…/ai/z_chat_corpus_scope.dart:190` ; `…/ai/z_chat_capability_audit.dart:48` | `grep -rn "\.audit(\|auditCapabilities" iffd/lib` → **2 lignes, toutes deux des commentaires** (`notebook_settings_iffd.dart:48`, `notebook_byte_opener_iffd.dart:38`) | ferme la boucle **anti-repli-muet** : l'hôte émet déjà les six drapeaux (`iffdLegacyCorpusFlags`, `:99-107`) mais **ne vérifie jamais** que les sources rendues respectent la portée. Il l'a lui-même écrit comme « la moitié que nous pouvons boucler » — et ne l'a pas bouclée |
| `ZChatContextPort` / `Fragment` / `Request` | `…/ai/z_chat_context_port.dart:181, 40, 133` | `grep -rn "ZChatContextPort" iffd/lib` → **0** | le contexte d'étude injecté dans la requête, au lieu des clés à la main de `iffdNotebookPayload` |
| `ZChatComposerSubmitPolicy` | `zcrud_chat/…/view/z_chat_composer_keys.dart:63`, `resolve` `:96` | **0** | l'hôte **subit** le défaut (Entrée envoie sur bureau/Web, `desktopAndWebOnly = true` `:76`) sans l'avoir choisi |

### 2 bis. Sous condition — la famille « routeur »

`buildChatRouterFirestoreRepository` + `$ZChatRouterFieldSpecs` + `registerZChatRouter` sont
**réels et bidirectionnels**, mais leur adoption **n'est pas un drop-in** et je refuse de la compter
dans les 4 900 lignes.

- **Preuve que le canal fait ce qu'on lui prête** : `packages/zcrud_chat_firestore/lib/src/data/z_chat_router_firestore_repository.dart:76` — `toCanonical` **et** `toLegacy` (`:79-80`) sont tous deux câblés, `toMap: (r) => _encode(router, toLegacy)` (`:99`), `fromMapSafe` applique `zChatRouterShapeIssue` (`:134`) avant décodage. `$ZChatRouterFieldSpecs` (`zcrud_chat_kernel/…/route/z_chat_router.dart:340`) déclare bien `routes` et `fallbacks` en `subItems` ; `registerZChatRouter` (`:385`) câble `fromMap`/`toMap`/`fieldSpecs`.
- **Ce qui bloque** : le schéma canonique porte `is_active`, que **`IffdAiRouterModel` n'a pas** (`grep -n "isActive\|is_active" ai_models.dart` → **RC=1** — l'hôte le documente lui-même, `notebook_route_catalog_iffd.dart:21`). Surtout, `IffdAiRouterModel` est cité **329 fois dans 81 fichiers** : l'adopter est une migration de modèle, pas un branchement.
- **Gain conditionnel** : `ai_router_zcrud_edition.dart` (685 l / 307 de code) + `ai_router_sub_list_seams.dart` (329 l / 198) + `notebook_route_catalog_iffd.dart` (106 l) ≈ **1 120 l**.
- **Ce qui est acquis sans rien migrer** : `zChatRouterShapeIssue` (`:134`) est un **prédicat pur**, applicable tel quel aux fixtures de l'hôte — il écarte le document qui deviendrait « un routeur vide, actif ».

---

## 3. MANQUE AU SOCLE

### 3.1 Profil d'assistant persisté (« expert IA »)

| | |
|---|---|
| **Forme** | Entité `ZChatAssistantProfile` (`ZEntity` + `ZExtensible`) + `$…FieldSpecs` + `register…` — le patron **exact** de `ZChatRouter` (`z_chat_router.dart:52 / :340 / :385`) |
| **Paquet** | `zcrud_chat_kernel` (domaine), rendu par `zcrud_screen` / `zcrud_core` |
| **Preuve d'absence** | `grep -rn "class ZChatAgent\|class ZChatExpert\|class ZChatPersona\|class ZChatSystemInstructions\|class ZChatAssistantProfile" packages/*/lib --include='*.dart'` → **RC=1** ; `grep -rln "knowledgeBase\|vectorStore\|systemInstructions" packages/*/lib --include='*.dart'` → **RC=1** |
| **Pourquoi l'hôte ne peut pas s'en passer** | `AiExpert` (325 l) + `AiExpertKnowledge` (96) + `AiExpertResponsesExample` (89) portent identité, instructions, base de connaissances, exemples de réponses et **six défauts de corpus** ; le formulaire legacy monte **40 `DynamicFormField`** (`ai_experts_dialogs.dart`, 1 200 l), le porté 727 l. Le socle sait router *quel modèle pour quelle tâche* (`ZChatRouter`) et transporter des instructions ponctuelles (`ZChatGenerationRequest.instructions`), mais **rien ne persiste un profil**. |
| **Bloque une capacité d'étude ?** | **Non** — l'étude ne dépend pas de l'expert |
| **Réserve honnête** | La frontière est discutable : c'est le patron « assistant personnalisé », générique dans l'industrie, mais dont l'**ingestion documentaire** (`ingest_ai_expert_documents`) est indissociable du backend de l'hôte |

### 3.2 Sélecteur de corpus documentaire

| | |
|---|---|
| **Forme** | Assemblage `ZDocumentSelectionSheet` sur `ZReadOnlyRepository<T>` : groupement dossier/sous-dossier, multi-sélection, trois états, pagination par curseur — le pendant de `ZChatConversationList` pour des documents |
| **Paquet** | `zcrud_document` (qui porte déjà `ZStudyDocument`, `z_study_document.dart`) ou `zcrud_screen` |
| **Preuve d'absence** | `grep -rln "DocumentSelector\|DocumentPicker\|ZDocumentSelect" packages/*/lib --include='*.dart'` → **RC=1** |
| **Pourquoi l'hôte ne peut pas s'en passer** | `chatbot_document_selector_dialog_widget.dart` — **842 l**, 9 `StreamBuilder` imbriqués jusqu'à 5 niveaux, indentation en colonne **81**, **zéro** état d'erreur ou de chargement, **aucun jumeau porté, aucun drapeau de QA**. C'est la plus grosse surface non portée du domaine. Le socle laisse à raison le *geste* à l'hôte (`ZChatComposerPickerAction`, contrat opaque), mais ne lui donne aucune **liste sélectionnable** |
| **Bloque une capacité d'étude ?** | **Oui, partiellement** — « générer des flashcards / une carte mentale depuis des documents choisis » passe par cette surface. `ZFlashcardGenerationSheet.contextSources` (§ 2.1) en couvre la **moitié** (options déjà résolues par l'hôte), pas le **choix** dans un corpus paginé |
| **Atténuation immédiate** | § 2.6 — les quatre widgets d'état existent et coûtent 0 ligne à adopter |

### 3.3 Suppression définitive d'une conversation

| | |
|---|---|
| **Forme** | Un mixin `ZPurgeable`-like **sur le port de conversation** — le socle a déjà ce patron pour les dépôts (`zcrud_core/…/ports/z_purgeable.dart`) |
| **Paquet** | `zcrud_chat_kernel` |
| **Preuve d'absence** | `z_chat_conversation_ports.dart:443-452` : « retrait et élagage, **jamais** purge (invariant AD-9) » ; barrel `zcrud_chat_kernel.dart:82-84` : « la suppression définitive en lot est **refusée** » |
| **Pourquoi l'hôte ne peut pas s'en passer** | `conversation_actions_menu.dart:94-96` supprime **physiquement** : `repository.delete(conversation.id)` puis `deleteConversationMessages(...)`. Adopter `ZChatConversationLifecyclePort` **changerait le comportement observable** |
| **Bloque une capacité d'étude ?** | **Non** |
| **⚠️ C'est un refus assumé, pas un oubli** : le socle argumente que le hard-delete casse le merge LWW (`:447-451`). L'hôte doit **changer de sémantique** ou garder son chemin — mais il ne doit pas croire le canal manquant par distraction |

### 3.4 Fournisseur de voix comme paramètre de génération — **faux manque, à ne pas demander**

`ZPodcastGenerationRequest` (`zcrud_study/…/z_podcast_generation_port.dart:36`) porte
`content`, `sourceKind`, `sourceId`, `folderId`, `mode`, `sourceHash`, `languageTag` et **`extra`**
(`:79`, filtré par `_reservedKeys` `:89`). Les cinq `TTSProvider` d'IFFD (`ai_models.dart:107-117`)
voyagent donc **par `extra`**, qui est la réponse conçue du socle (AD-4). Une CR réclamant un
`voiceProviderId` de premier rang serait à retirer avant émission.

---

## 4. RESTE À L'HÔTE

| Élément | Où | Pourquoi le socle ne le portera pas |
|---|---|---|
| Les **six corpus douaniers** ouest-africains (Code du GATT, TEC CEDEAO, Code des douanes CEDEAO, Codes Togo/Niger, CGI Togo) | `notebook_settings_iffd.dart:56-63` | Valeurs métier. **Le mécanisme, lui, est déjà généralisé** en `ZChatCorpusOption` (clé opaque + libellé) — l'hôte le note `:25-29` |
| `NiveauIFFD`, `FiliereEtCycleIFFD`, l'année académique dont dépend la visibilité du champ « Dossier d'étude » | `z_qa_flags.dart:483-486` | Règle métier de visibilité conditionnelle |
| L'ACL « on ne supprime pas le **dernier** modèle de repli » | `ai_routers_dialogs.dart:104` → `IffdMinimumOneAcl` (`ai_router_zcrud_edition.dart:238-251`) | Règle métier. Le socle fournit **le port** (`ZAcl.can`, `zcrud_core/…/ports/z_acl.dart:101`) — et l'hôte l'a déjà porté correctement |
| Les 24 constructeurs de prompt (`ai_prompt_generator.dart`, 597 l) et les messages système (`ai_systems_messages.dart`, 389 l) | — | Le prompt est du métier. AD-12 interdit qu'un prompt vive dans le socle |
| Le rendu du menu d'artefact en `popup_menu` | `notebook_artifact_menu_iffd.dart` (379) + `_render` (103) | Bibliothèque de menus choisie par l'app, branchée par le **seam prévu** (`artifactMenuBuilder`) — ce **n'est pas** un doublon |
| Les quirks legacy reproduits volontairement : `ucFirst` sur l'hôte du service (`localhost` → `Localhost`), `port` persisté en `String` | `ai_base_url_zcrud_edition.dart:17-20` | Parité de données avec le parc existant |
| `classroom` persisté sous la clé `"chat"`, `ExplainStyle.exampes` (faute de frappe persistée) | `notebook_variants_iffd.dart:31-47` ; `ai_models.dart:10` | Corriger serait une migration de données |
| Le transport réel (Dio, App Check, authentification, `CancelToken`) | `iffd_ai_repository_impl.dart` | Le socle est HTTP-agnostique par conception (`ZChatSseOpener`, `ZIffdRawStreamOpener`) |
| Les **sept variantes** écrites *dans* le message | `chatbot_message.dart:150-156` ; `IffdArtifactStore` | **Déjà servi** : les neuf clés de capacité (`mindmap`, `flashcards`, `story`, `humour`, `classroom`, `summary`, `elaboration`, `examples`, `poem`) sont **publiques dans le socle** (`z_chat_notebook_reference.dart:157-181`) et le stockage passe par `ZChatArtifactStorePort`. Ce n'est **pas** un manque |

---

## 5. Défauts de l'hôte relevés au passage — hors migration

1. 🔴 **La consigne QA B-60 est inversée.** `z_qa_flags.dart:509-511` et
   `docs/qa-plan-comparaison-legacy-zcrud.md:324` affirment « CE FIL N'ENREGISTRE RIEN […] ne jamais
   l'utiliser sur un compte réel ». Or `IffdTranscriptPort.append` appelle
   `repository.create(...)` (`notebook_transcript_iffd.dart:100`), au bout de la chaîne
   `notebook_page_zcrud.dart:169` → `notebook_ports_iffd.dart:208` →
   `ZChatTranscriptBinding` (`z_chat_transcript_binding.dart:150`). **Un testeur qui suit la
   consigne écrit en production en croyant l'inverse.** À corriger avant toute séance de QA.
2. 🔴 **Le groupe `thinking` est perdu par le formulaire porté.** Legacy : 13 groupes, `thinking`
   vivant (`ai_routers_dialogs.dart:600-604`). Porté : **12** (`kAiRouterFallbackGroups`,
   `ai_router_zcrud_edition.dart:206-219`), et sa dartdoc `:202` affirme à tort que le legacy n'en
   monte que douze. Grep négatif : `grep -n "thinking" ai_router_sub_list_seams.dart` → **RC=1**.
   La donnée existe (`ai_models.dart:233-234`) et le catalogue de routes la découvre par suffixe.
3. **Commentaire périmé** : `z_iffd_markdown_style.dart:44-46` écrit « le FIL DE CHAT ne peut pas
   encore la recevoir : `ZChatMarkdownRenderer` n'expose que `textStyle` ». Faux depuis v3.4.0 —
   et l'hôte le consomme déjà à deux sites. À retirer, sous peine d'induire le prochain lot.
4. **Les 36 déclarations de corpus legacy sont inertes** — 12 par implémentation, **0 transmission**
   (`grep '"enableCDNTogo"\|"corpus"' *_ai_repository_impl.dart` → RC=1 sur les trois). Le chemin
   **porté** les transmet (`iffdLegacyCorpusFlags`, `notebook_byte_opener_iffd.dart:99-107`) :
   la bascule QA change donc un comportement **réel**, pas seulement un rendu.

---

## 6. Limites de ce relevé

1. **Aucun test lancé**, dans aucun dépôt (consigne). Rien ici ne repose sur une exécution.
2. Les économies de lignes sont des **estimations bornées** : je donne le brut mesuré
   (`wc -l`) et le net après retrait des lignes de déclaration qui subsistent. Les fichiers
   d'IFFD sont très commentés — j'ai donné les **lignes de code** (`grep -vcE '^\s*(//|$)'`)
   là où l'écart comptait (§ 2.2).
3. Je n'ai **pas** relu les 440 270 octets du registre de CR : j'ai vérifié les sept titres
   `CR-IFFD-114→120` par `sed -n` aux lignes 7589, 7675, 7734, 7787, 7825, 7859, 7879.
4. Le relevé `iffd-migration-2026-08-25/` n'a servi à rien : je ne m'en suis pas servi.
5. **Non mesuré** : l'atteignabilité à l'exécution des deux chemins Notebook coexistants
   (`notebook_zcrud.dart` monte `ZChatController` nu via `NotebookZcrudView`,
   `notebook_page_zcrud.dart` monte `ZChatNotebookController`). Si les deux sont vivants, le
   `routeResolver` ne s'applique qu'à l'un. Le soupçon B du catalogue IA **reste ouvert**.
