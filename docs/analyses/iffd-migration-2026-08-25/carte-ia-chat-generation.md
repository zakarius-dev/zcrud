# Carte du domaine « IA — assistant, chatbot, génération, explication, routeurs » — IFFD

> Relevé du **2026-08-25**, dépôt `/home/zakarius/DEV/iffd` en **lecture seule**,
> `HEAD = e36c490` (« feat(zcrud): v3.20.0 + v3.21.0 adoptées — CR-112 livrée… »).
> Toutes les références sont en `fichier:ligne`. Aucun test n'a été lancé ; aucune
> valeur n'est devinée — ce qui n'est pas lisible dans le code est signalé comme tel.

---

## 0. Périmètre retenu et chiffres d'ensemble

Le point de départ fourni par l'orchestrateur (6 chemins) a été **suivi par les
dépendances réelles**. Ce qui a été **ajouté au-delà** :

| Ajouté | Pourquoi |
|---|---|
| `lib/src/domain/models/ai/` | `IffdAiRouterModel`, `AiResponse`, `ExplainStyle`, `SummaryType`, `TTSProvider`, `WorkflowEffort` — le modèle du domaine entier |
| `lib/src/domain/repositories/ai_repository.dart` | le **port** : 25 endpoints + 28 méthodes |
| `lib/src/domain/repositories/chatbot/*` | les 4 contrats CRUD (conversation, message, expert, exemples) |
| `lib/src/data/repositories/{iffd,openai,cloud_functions}_ai_repository_impl.dart` + `iffd_ai_transport.dart` | les 3 implémentations du port + le transport pur |
| `lib/src/domain/services/ai/ai_prompt_generator.dart` | l'assemblage des prompts (mixin de l'impl. vivante) |
| `lib/src/presentation/features/discovery/` | `DiscovryPageController` (2 412 l.) est **le** contrôleur du chat ; `DiscovryAiPage`, `AssistantPage`, `DiscovrySearchComposer` |
| `lib/src/presentation/features/administration/{pages,dialogs,zcrud}/ai_expert*` | les Assistants IA Experts (modèle `AiExpert` vit dans `lib/ai_assistant/models/`) |
| `lib/src/presentation/features/folders/pages/folder_explanation_page.dart` + `folders/zcrud/{assistant_chat_zcrud_mount, notebook_zcrud_mount, notebook_artifact_actions_iffd}.dart` | les **points de montage** du Notebook et de l'Assistant |
| `lib/src/features/corpus/providers/corpus_providers.dart`, `lib/src/features/discovery/providers/` | les providers du routeur IA et du chat |

### Volumétrie

| Ensemble | Fichiers | Lignes |
|---|---:|---:|
| **Périmètre total** (dont 2 `.g.dart`) | **83** | **30 609** |
| — hors code généré | 81 | 30 302 |
| — **déjà porté sur zcrud** (`**/zcrud/**`) | **31** | **8 260** |
| — legacy restant | 52 | 22 349 |
| Point de départ seul (6 chemins de l'orchestrateur) | 52 | 18 096 |

Dix fichiers pèsent **14 500 lignes**, soit 47 % du domaine :

| Fichier | Lignes |
|---|---:|
| `lib/ai_assistant/screens/chatbot_conversation_screen.dart` | 5 180 |
| `lib/src/presentation/features/discovery/controllers/discovry_page_controller.dart` | 2 412 |
| `lib/src/data/repositories/iffd_ai_repository_impl.dart` | 1 377 |
| `lib/src/presentation/features/administration/pages/ai_experts_page.dart` | 1 330 |
| `lib/src/presentation/features/administration/dialogs/ai_experts_dialogs.dart` | 1 200 |
| `lib/ai_assistant/zcrud/notebook_zcrud.dart` | 926 |
| `lib/src/presentation/features/ai_routers/pages/ai_routers_page.dart` | 803 |
| `lib/src/presentation/features/explain_ai/pages/explain_ai_page.dart` | 751 |
| `lib/ai_assistant/screens/chatbot_screen.dart` | 738 |
| `lib/src/presentation/features/ai_routers/dialogs/ai_routers_dialogs.dart` | 716 |

🔴 **`chatbot_conversation_screen.dart` porte un `build()` de 4 211 lignes** —
`_SfExplainScreenState.build` s'ouvre à `:288` et la classe se ferme à `:4498`
(`SfChatBotScreen` commence à `:4499`). Une fonction locale `_buildComposer` est
**déclarée à l'intérieur** de ce `build`, à `:2521`.

---

## 1. Ce que le domaine SAIT FAIRE (capacités visibles par l'utilisateur)

Établi à partir des 25 endpoints déclarés (`ai_repository.dart:22-69`), des 28
méthodes du port, des menus d'artefacts et des tables de variantes.

### Conversation

1. **Tenir une conversation avec un assistant IA** (« Polaris AI ») en **flux
   token par token** — `chatWithAssistant` → `chat_with_assistant_v2`
   (`ai_repository.dart:57`, `:125-146`).
2. **Organiser ses conversations** : créer, renommer, archiver, supprimer,
   rechercher, **regrouper par dossier** (`ChatbotConversation.folderId` /
   `subFolderId` / `documentId`, `chatbot_conversation.dart:18-27`).
3. **Choisir un « expert IA »** (persona à instructions + base de connaissances +
   exemples de Q/R + documents indexés) — `AiExpert` (`ai_expert.dart:12-48`).
4. **Choisir un « routeur IA »** (agrégateur de modèles) parmi ceux auxquels
   l'utilisateur a droit, trié par effort (`chatbot_conversation_screen.dart:346-372`).
5. **Régler l'effort d'exécution** — Mini / Plus / Pro (`WorkflowEffort`,
   `ai_models.dart:127-146`).

### Génération d'explication (le « Notebook »)

6. **Faire expliquer un sujet** à partir d'un dossier / sous-dossier / matière —
   `generateSubjectExplanation` → `generate_subject_explanation`
   (`ai_repository.dart:34`, `:148-176`).
7. **Régénérer** une explication (`discovry_page_controller.dart:1720`).
8. **Décliner une réponse en 7 variantes** : résumé, élaboration, exemples, poème,
   histoire fantastique, humour, séance de cours
   (`chatbot_conversation_screen.dart:1293-1357` ; table portée dans
   `notebook_variants_iffd.dart`).
9. **Obtenir des sujets connexes** — depuis un sujet (`generate_related_topics`) ou
   **depuis l'historique de la conversation** (`ai_repository.dart:178-200`).
10. **Résumer la conversation en continu** (`generateConversationSummary`,
    `ai_repository.dart:202-209` ; champ persisté `conversationSummary`).

### Génération d'artefacts d'étude

11. **Créer une carte mentale** depuis des notes ou depuis un document entier
    (`generateMindmapFromNotes`, `generateMindmapFromWholeDocument`,
    `generate_mindmap_with_ai` / `generate_mindmap_from_whole_document`).
12. **Créer des flashcards** — depuis un sujet, depuis des notes, depuis les pages
    d'un document, depuis un document entier, depuis un outil d'évaluation douanière
    (5 chemins distincts, `ai_repository.dart:23-32`, `:99-105`, `:315-405`).
13. **Résumer un document** — pages choisies ou document entier, avec **4 styles de
    résumé** (`SummaryType` : par défaut, chronologique, hiérarchique, détaillé —
    `ai_models.dart:64-105`).
14. **Générer des étiquettes (tags) de matière** (`generate_subject_tags`).
15. **Générer une explication de flashcard** après réponse, **évaluer une réponse
    libre**, **donner un indice** (`generateFlashcardExplanation`,
    `evaluateFlashcardAnswer`, `generateFlashcardHint`, `ai_repository.dart:286-361`).
16. **Générer les instructions d'un expert IA** à partir d'un but et de ressources
    (`generate_ai_expert_instructions`) et **indexer ses documents**
    (`ingest_ai_expert_documents`).

### Restitution

17. **Écouter la réponse** — synthèse vocale et **podcast**, avec 5 fournisseurs de
    voix (`TTSProvider` : Gemini, OpenAI, OpenAI HD, ElevenLabs, ElevenLabs Studio —
    `ai_models.dart:107-117` ; `generate_podcast_from_content`).
18. **Exporter en PDF** — markdown (`convert_markdown_to_pdf`) et flashcards
    (`convert_flashcards_to_pdf`).
19. **Lire un rendu riche** (markdown + LaTeX + tableaux) via `GptMarkdown` /
    `ZChatMarkdownRenderer`.
20. **Éditer à la main** le contenu généré (retour vers l'éditeur riche Quill,
    `rich_text_editor_screen.dart`).

### Outillage de la requête

21. **Joindre des documents** du dossier à la requête (`documentsIds`), avec
    sélecteur (`notebook_document_picker_iffd.dart`, `ChatBotDocumentsSelectionController`
    `discovry_page_controller.dart:39-155`).
22. **Activer la recherche web**, avec ou sans *scraping*, et plafonner le nombre de
    résultats (`enableWebSearch`, `scrapeWebResults`, `maxWebSearchResults`).
23. **Activer le raisonnement** et régler son effort et son plafond de jetons
    (`enableThinking`, `thinkingEffort`, `maxWebThinkingTokens`).
24. **Brancher six corpus douaniers** : CDN Togo, CDN Niger, CDC CEDEAO, CGI Togo,
    TEC CEDEAO, Code GATT (`enableCDNTogo`… `enableCodeGATT`).
25. **Cadrer le niveau IFFD** de la réponse (`NiveauIFFD`, filière + cycle de
    l'auditeur injectés dans la charge utile, `iffd_ai_transport.dart:87-92`).

### Administration

26. **Administrer les routeurs IA** — créer / modifier / consulter un agrégateur qui
    fixe, **par tâche**, le modèle principal et sa liste de modèles de repli
    (13 paires, cf. §3), plus la répartition des types de questions.
27. **Administrer les experts IA** — CRUD complet, base de connaissances, exemples de
    réponses, filières et cycles cibles, outils activés par défaut.
28. **Changer l'URL du service IA à chaud** (écran de QA, `smart_learn_controller.dart:138`,
    `:547`).

---

## 2. Les écrans

Tous les écrans du domaine. « L » = legacy, « Z » = porté sur zcrud.

| # | Écran / vue | Chemin | Lignes | Rôle | Formulaire | Liste | Nav | Rendu riche |
|---|---|---|---:|---|:--:|:--:|:--:|:--:|
| 1 | `SfExplainScreen` / `SfChatBotScreen` (L) | `lib/ai_assistant/screens/chatbot_conversation_screen.dart:232` / `:4499` | **5 180** (dont `build()` 4 211 l.) | Le fil de conversation complet : Notebook (explication d'un sujet) **et** chat assistant. Porte les 9 boutons d'artefact, les 7 variantes, l'export, le podcast, l'édition | ✔ (composer + `ToolsSheet`) | ✔ (fil `AssistView`) | ✔ | ✔ |
| 2 | `ToolsSheet` + `ToolTile` / `ToolNumberInputTile` / `ToolSelectTile` (L) | même fichier `:4510-5180` | 671 | Feuille de réglages : corpus, web, raisonnement, documents, voix, expert | ✔ | — | — | — |
| 3 | `ChatbotScreen` (L) | `lib/ai_assistant/screens/chatbot_screen.dart:42` | 738 | Coquille « Polaris IA » : panneau de conversations + conversation active, responsive | — | ✔ | ✔ | — |
| 4 | `NotebookZcrudPage` (Z) | `lib/ai_assistant/zcrud/notebook_page_zcrud.dart:69` | 376 | Le Notebook porté sur `ZChatNotebookView` | ✔ | ✔ | ✔ | ✔ |
| 5 | `NotebookZcrudView` (Z) | `lib/ai_assistant/zcrud/notebook_zcrud.dart:624` | 926 (fichier) | Surface + 5 créneaux + glyphes/couleurs legacy | ✔ | ✔ | — | ✔ |
| 6 | `mountIffdAssistantChat` → `ZChatConversationScreen` (Z) | `lib/src/presentation/features/folders/zcrud/assistant_chat_zcrud_mount.dart` | 230 | L'onglet Assistant porté, même `IffdTranscriptPort` que le Notebook | ✔ | ✔ | — | ✔ |
| 7 | `ExplainAiPage` (L) | `lib/src/presentation/features/explain_ai/pages/explain_ai_page.dart:31` | 751 | Explication autonome d'un sujet, avec pagination des explications générées (`IntroductionScreen`) | — | ✔ | ✔ | ✔ |
| 8 | `AiRoutersPage` (L) | `lib/src/presentation/features/ai_routers/pages/ai_routers_page.dart:19` | 803 | Liste des routeurs IA (grille manuelle) + état vide illustré + FAB | — | ✔ | ✔ | — |
| 9 | `AiRouterEditionScreen` (L) | `lib/src/presentation/features/ai_routers/dialogs/ai_routers_dialogs.dart:110` | 716 (fichier) | Formulaire legacy du routeur : 3 champs + **13 groupes** `buildFallbackModelsField` | ✔ | ✔ (sous-listes) | — | — |
| 10 | `AiRouterZcrudEditionScreen` (Z, **actif**) | `lib/src/presentation/features/ai_routers/zcrud/ai_router_zcrud_edition.dart:444` | 704 (fichier) | Le même formulaire en `ZFieldSpec` + `ZStepperEdition` + `ZSubListConfig` + `ZAcl` | ✔ | ✔ | — | — |
| 11 | `AiExpertsPage` (L) | `lib/src/presentation/features/administration/pages/ai_experts_page.dart:31` | 1 330 | Liste des experts IA, onglets par filière/cycle, recherche, grille manuelle, état vide illustré | — | ✔ | ✔ | — |
| 12 | `AiExpertdEditionScreen` (L) | `lib/src/presentation/features/administration/dialogs/ai_experts_dialogs.dart:42` | 1 200 (fichier) | Formulaire de l'expert : 40 `DynamicFormField`, sous-listes imbriquées à 3 niveaux | ✔ | ✔ | — | ✔ (markdown en ligne) |
| 13 | `presentAiExpertEdition` (Z) | `lib/src/presentation/features/administration/zcrud/ai_expert_zcrud_edition.dart:466` | 534 (fichier) | Le même formulaire en schéma déclaratif | ✔ | ✔ | — | ✔ |
| 14 | `DiscovryAiPage` (L) | `lib/src/presentation/features/discovery/pages/discovry_ai_page.dart:22` | 425 | Recherche/découverte assistée par IA (`AssistView` Syncfusion) | ✔ | ✔ | ✔ | ✔ |
| 15 | `AssistantPage` (L) | `lib/src/presentation/features/discovery/pages/assistant_page.dart:12` | 26 | Coquille de route vers l'assistant | — | — | ✔ | — |
| 16 | `FolderExplanationPage` + `SubjectExplanationPage` + `FolderChatbotPage` + `SubjectChatbotPage` (L) | `lib/src/presentation/features/folders/pages/folder_explanation_page.dart:27,276,292,311` | 325 | Quatre points d'entrée routés vers le fil ; c'est **ici** que le drapeau zcrud arbitre (`:159-163`) | — | — | ✔ | — |
| 17 | `DiscovrySearchComposer` (L) | `lib/src/presentation/features/discovery/widgets/discovry_search_composer.dart:24` | 483 | Le composer de la découverte IA | ✔ | ✔ | — | — |
| 18 | `ConversationListWidget` (L) | `lib/ai_assistant/widgets/conversation_list_widget.dart:27` | 362 | Panneau de conversations : recherche, groupement par dossier, états | ✔ (recherche) | ✔ | — | — |
| 19 | `FolderConversationsWidget` (L) | `lib/ai_assistant/widgets/folder_conversations_widget.dart:18` | 218 | Conversations d'un dossier | — | ✔ | — | — |
| 20 | `ConversationItemWidget` (L) | `lib/ai_assistant/widgets/conversation_item_widget.dart:15` | 241 | Tuile de conversation (pulsation de génération) | — | — | — | — |
| 21 | `ConversationListZcrudView` (Z) | `lib/src/presentation/features/chatbot/zcrud/conversation_list_zcrud.dart:43` | 144 | La liste portée : états chargement/erreur/vide **décidés par le socle** | — | ✔ | — | — |
| 22 | `ConversationItemZcrudView` (Z) | `lib/src/presentation/features/chatbot/zcrud/conversation_item_zcrud.dart:87` | 238 | La tuile portée | — | — | — | — |
| 23 | `ConversationActionsMenu` (L) | `lib/ai_assistant/widgets/conversation_actions_menu.dart` | 157 | Menu contextuel d'une conversation | — | — | — | — |
| 24 | `ConversationSearchBar` (L) | `lib/ai_assistant/widgets/conversation_search_bar.dart` | 123 | Barre de recherche | ✔ | — | — | — |
| 25 | `EmptyConversationsState` (L) | `lib/ai_assistant/widgets/empty_conversations_state.dart` | 107 | État vide des conversations | — | — | — | — |
| 26 | Sélecteur de documents (Z) | `lib/ai_assistant/zcrud/notebook_document_picker_iffd.dart` | 103 | Pièces jointes du Notebook | — | ✔ | — | — |
| 27 | Feuille de réglages portée (Z) | `lib/ai_assistant/zcrud/notebook_settings_iffd.dart` | 168 | `ZChatMaterialSettingsSheet` + sections corpus/génération | ✔ | — | — | — |

**Routes déclarées** (`app_router.gr.dart`) : `AiExpertsPageRoute:126`,
`AiRoutersPageRoute:142`, `DiscovryPageRoute:567`, `ExplainAiPageRoute:668`,
`FolderChatbotPageRoute:827`, `FolderExplanationPageRoute:1085`,
`SubjectChatbotPageRoute:2002`, `SubjectExplanationPageRoute:2236` — **8 routes**.

---

## 3. Modèles de domaine et persistance

### 3.1 Les entités

| Entité | Fichier | Lignes | Champs | Sérialisation |
|---|---|---:|---:|---|
| `ChatbotMessage` | `lib/ai_assistant/models/chatbot_message.dart:122` | 390 | 27 | manuelle |
| `ChatbotConversation` | `lib/ai_assistant/models/chatbot_conversation.dart:14` | 144 | 12 | manuelle |
| `AiExpert` | `lib/ai_assistant/models/ai_expert.dart:12` | 325 | 34 | manuelle |
| `AiExpertKnowledge` | `lib/ai_assistant/models/ai_expert_knowledge.dart` | 96 | — | manuelle |
| `AiExpertResponsesExample` | `lib/ai_assistant/models/ai_expert_responses_example.dart` | 89 | — | manuelle |
| `IffdAiRouterModel` | `lib/src/domain/models/ai/ai_models.dart:178` | ~365 | 31 | manuelle |
| `AiResponse` (DTO de transport) | `lib/src/domain/models/ai/ai_models.dart:161` | ~40 | 4 | manuelle |

Toutes implémentent `DynamicModel` (`toMap` / `fromMap` / `copyWith` / `props` /
`toJson`), **entièrement à la main**.

🔴 **Aucun codegen dans tout `lib/`** — grep négatif montré :

```
$ grep -rn "@ZcrudModel"          --include='*.dart' lib   → rc=1 (0 ligne)
$ grep -rn "ZcrudRegistry"        --include='*.dart' lib   → rc=1 (0 ligne)
$ grep -rn "package:zcrud_annotations" --include='*.dart' lib → rc=1 (0 ligne)
$ grep -rn "@JsonSerializable"    --include='*.dart' lib   → 0
```

Les 16 `*.g.dart` de `lib/` sont **exclusivement** des providers Riverpod
(`riverpod_annotation`) et le routeur `auto_route` — aucune sérialisation générée.

### 3.2 Les enums

`ChatbotMessageType` (7 valeurs), `ChatbotMessageSender` (3),
`ChatbotMessageTransformer` (**15**, avec titre + message de chargement + couleur,
`chatbot_message.dart:15-120`), `ChatbotConversationType` (3), `ExplainStyle` (10),
`AiModelsProvider` (7), `SummaryType` (4), `TTSProvider` (5), `WorkflowEffort` (3).

⚠️ **`ExplainStyle.exampes` porte une faute de frappe et elle est PERSISTÉE**
(`ai_models.dart:10`) — relevé et reproduit tel quel par
`notebook_variants_iffd.dart:44-47`.

⚠️ **Trois noms pour une même chose** : le transformer `classroom`, le style zcrud
`'classroom'`, et la **clé persistée `"chat"`** (`notebook_variants_iffd.dart:32-35`).

### 3.3 Les dépôts

Contrat unique `CrudRepository<T>` (`lib/src/domain/repositories/datacrud_repository.dart:21-63`,
93 l.) : `create`, `mapCreate`, `streamByIds`, `streamAll`, `streamOne`, `all`,
`count`, `asyncCount`, `batchDelete`, `find`, `batchSet`, `batchUpdate`, `update`,
`mapUpdate`, `softDelete`, `delete`, `restore` + ACL (`objectType`, `crudableObjects`).

Les 4 dépôts du domaine sont des **coquilles vides** au-dessus de
`FirebaseCrudRepositoryImpl<T>` :

```
firebase_models_repositories_impls.dart:225  FirebaseChatbotConversationRepositoryImpl
                                       :230  FirebaseChatbotMessageRepositoryImpl
                                       :240  FirebaseAiExpertRepositoryImpl
                                       :245  FirebaseAiExpertResponsesExampleRepositoryImpl
```

Les requêtes métier vivent en **extensions** sur les contrats
(`chatbot_conversation_repository.dart:9-31`, `chatbot_message_repository.dart:9-56`).

### 3.4 Source de données, cache, synchronisation

- **Firestore en flux direct**, sans couche locale.
- 🔴 **Aucun cache local, aucune synchronisation offline** — grep négatif montré :
  ```
  $ grep -nE "Persistence|Hive|GetOptions|Source\.cache" \
        lib/src/data/repositories/firebase_crud_repository_impl.dart  → rc=1
  $ grep -rn "package:hive" --include='*.dart' lib                    → 0
  ```
  Le port de transcript porté le documente explicitement : « le dépôt est l'unique
  source — pas de seconde lecture, pas de cache divergent »
  (`notebook_transcript_iffd.dart:12`).
- **Dates** : `Timestamp` Firestore, avec repli sur `int` millisecondes en lecture
  (`chatbot_message.dart:283-288`, `chatbot_conversation.dart:90-100`). Les
  `Timestamp` **fuient dans le modèle de domaine** (`chatbot_message.dart:3`).
- **Pas de soft-delete de sync** : `isArchived` est un booléen métier, pas un
  `is_deleted` d'orchestrateur.

### 3.5 Traitement des erreurs — **deux régimes incompatibles**

| Régime | Où | Forme |
|---|---|---|
| **CRUD** | `CrudRepository` | `DataState<String, Exception>` — **121 occurrences** dans `lib/` |
| **IA** | `AiRepository` | **callback** `void Function(AiResponse result, bool completed, {bool hasError})` — jamais de valeur de retour, jamais d'exception typée |
| **porté** | `**/zcrud/**` | `ZResult` / `ZFailure` (dartz) — 57 occurrences dans le périmètre, 4 imports `package:dartz` |

L'erreur IA se transporte donc dans un **champ de chaîne** (`AiResponse.error`,
`ai_models.dart:162`), jamais dans un type. Le dépôt vivant compte **8 `catch (`**
(`iffd_ai_repository_impl.dart`), tous convertis en
`onComplete?.call(AiResponse(error: …), true, hasError: true)` — **41 sites de
`onComplete?.call(`** dans `lib/`.

### 3.6 Transport

- Base : `EnvConfig.aiBaseUrl` (`lib/src/config/env_config.dart:19-24`), surchargée
  à l'exécution par `SmartLearnController.aiBaseUrl`
  (`smart_learn_controller.dart:138-139`, persistée en `SharedPreferences`).
- En-têtes et charge utile factorisés dans `iffd_ai_transport.dart` (102 l.,
  **fonctions pures**) : `iffdAiAuthHeaders` (`:61`) et `iffdAiPayload` (`:87`).
  Ce fichier existe précisément parce que le dépôt les construisait **4 fois**
  (2 branches `dio` + 2 branches `http` web) — son en-tête le documente (`:1-32`).
- ⚠️ `stream` part **en chaîne** (`"true"`/`"false"`), pas en booléen (`:96`).

### 3.7 Secrets — **où ils vivent** (aucune valeur citée)

| Quoi | Où |
|---|---|
| Jeton de debug App Check, clé de site reCAPTCHA, URL du service IA — **valeurs de repli littérales** | `lib/src/config/env_config.dart:5-24` (repli de `dotenv` / `String.fromEnvironment`) |
| Une **clé d'API littérale** nommée `defaultApiKey` | `lib/src/utils/constants/strings.dart:6` — déclarée, et **référencée nulle part ailleurs** dans `lib/` (grep : une seule ligne de résultat, celle de la déclaration) |
| Un **identifiant d'assistant OpenAI codé en dur** | `lib/src/data/repositories/openai_ai_repository_impl.dart:32` (dans une implémentation morte, cf. §4.1) |
| Jetons d'authentification de requête (App Check, ID token Firebase) | construits à l'exécution, `iffd_ai_transport.dart:61-71` — jamais littéraux |

---

## 4. LE CODE RÉPÉTÉ — le point décisif

### 4.1 🔴 Deux implémentations MORTES du port IA — 1 171 lignes

`AiRepository` a **3 implémentations**. Deux ne sont **référencées nulle part** —
grep négatif montré :

```
$ grep -rn "OpenaiAiRepositoryImpl" --include='*.dart' lib test \
      | grep -v "^lib/src/data/repositories/openai_ai_repository_impl.dart"
  → rc=1 (0 ligne)
$ grep -rn "CloudFunctionsAiRepositoryImpl" --include='*.dart' lib test \
      | grep -v "^lib/src/data/repositories/cloud_functions_ai_repository_impl.dart"
  → rc=1 (0 ligne)
```

Chacune contient **27 `UnimplementedError`**. Seule
`IffdAiRepositoryImpl` est branchée (`main.dart:112`,
`ai_generation_providers.dart:11`, `discovery_providers.dart:16`).

| Site | Lignes | Vivant ? |
|---|---:|---|
| `openai_ai_repository_impl.dart` | 672 | **non** |
| `cloud_functions_ai_repository_impl.dart` | 499 | **non** |
| `iffd_ai_repository_impl.dart` | 1 377 | oui |

⇒ **2 sites, 1 171 lignes de code mort** qui obligent à répercuter toute évolution
du port sur trois fichiers.

### 4.2 🔴 La signature de callback IA — 113 sites

```
void Function(AiResponse result, bool completed, {bool hasError})? onComplete
```

| Fichier | Occurrences |
|---|---:|
| `lib/src/domain/repositories/ai_repository.dart` | 28 |
| `lib/src/data/repositories/iffd_ai_repository_impl.dart` | 28 |
| `lib/src/data/repositories/openai_ai_repository_impl.dart` | 28 |
| `lib/src/data/repositories/cloud_functions_ai_repository_impl.dart` | 28 |
| `lib/ai_assistant/zcrud/notebook_capabilities_iffd.dart` | 1 |
| **Total** | **113** |

Écrite sur 2 lignes à chaque fois → **~226 lignes**. Un `typedef` existe déjà pour
une variante de cette signature (`OnAiExplanationComplete`, `ai_models.dart:154-158`)
— il n'est utilisé qu'aux endroits où `auto_route_generator` l'imposait.

### 4.3 🔴 Les 28 méthodes du port, écrites 4 fois

28 signatures × 4 fichiers = **112 déclarations**, chacune portant entre 6 et 25
paramètres nommés. `chatWithAssistant` seule compte **22 paramètres**
(`ai_repository.dart:125-146`) ; `generateSubjectExplanation` en compte **24**
(`:148-176`). Ces listes sont recopiées à l'identique dans les 3 implémentations.

### 4.4 🔴 Les six corpus douaniers — 125 occurrences, 8 fichiers

`enableCDNTogo`, `enableCDNNiger`, `enableCDCCedeao`, `enableCGITogo`,
`enableTecCedeao`, `enableCodeGATT` :

| Drapeau | Occurrences dans `lib/` |
|---|---:|
| `enableCDNTogo` | 22 |
| `enableCDNNiger` | 22 |
| `enableCDCCedeao` | 22 |
| `enableCGITogo` | 22 |
| `enableTecCedeao` | 22 |
| `enableCodeGATT` | 23 |
| **Total** | **125** |

Fichiers touchés (8) : `chatbot_conversation_screen.dart`,
`notebook_byte_opener_iffd.dart`, `notebook_settings_iffd.dart`,
`cloud_functions_ai_repository_impl.dart`, `iffd_ai_repository_impl.dart`,
`openai_ai_repository_impl.dart`, `ai_repository.dart`,
`discovry_page_controller.dart`.
Chaque corpus a en outre **son propre `toggleXxx()`** dans le contrôleur
(`discovry_page_controller.dart:896-921`, 6 méthodes de 5 lignes) et **son propre
champ `default*`** sur `AiExpert` (`ai_expert.dart:41-46`).
Un septième corpus coûterait aujourd'hui ~21 éditions.

### 4.5 🔴 Les sept variantes — le motif le plus cher

| Site répété | Où | Sites | Lignes |
|---|---|---:|---:|
| Champ de variante sur le modèle (`final` + ctor + `copyWith` param + `copyWith` corps + `toMap` + `fromMap` + `props`) | `chatbot_message.dart:148-156, 179-186, 208-215, 240-247, 271-277, 341-347, 365-371` | 7 champs × 7 emplacements = **49** | ~49 |
| Paire de paramètres `<x>RequestId` / `<x>Response` dans `toChatUiMessage` | `chatbot_conversation_screen.dart:386-399` | **14** | 14 |
| Résolution `<x> = (message.<x> ?? <x>Response?.content)?.nullifyIfEmpty()` | `:411-430` | **7** | 20 |
| Bloc de recherche `firstWhereOrNull` requête + réponse (19 l. chacun) | `:2264-2398` | **7** | **133** |
| Idem pour carte mentale + flashcards (22 l. chacun) | `:2210-2256` | **2** | 47 |
| Appel `variantPopupmenuBuilder(...)` | `:1201-1255` | **7** | 55 |
| `GlobalKey(debugLabel: "<x>BtnKey${message.id}")` | `:1258-1292` | **9** | 27 |
| Entrée de la table `variantes` (`content`/`btnKey`/`color`/`menu`/`tooltip`/`transformer`/`icon`) | `:1293-1357` | **7** | **65** |
| **Total mesuré pour le seul motif « variante »** | | **~102** | **~410** |

Le portage zcrud remplace tout cela par **une table de 7 lignes** dans
`notebook_variants_iffd.dart` (345 l. dont ~180 de commentaire de relevé) plus
`notebook_artifact_registry_iffd.dart` (199 l.), qui **dérive** les
`ZChatArtifactSpec` au lieu de les assembler à la main
(`notebook_artifact_registry_iffd.dart:4-10`).

### 4.6 🔴 Les treize groupes de modèles de repli du routeur IA

`IffdAiRouterModel` porte **13 paires** `<tâche>Model` / `<tâche>FallbackModels`
(ai, explanation, chat, mindmap, flashcards, summary, elaboration, examples, poem,
history, humor, chatStyle, thinking).

| Site | Mesure |
|---|---|
| `"FallbackModels"` dans `ai_models.dart` | **111 occurrences** (déclaration, ctor, `copyWith` ×2, `toMap`, `fromMap`, `props`, `toString`) |
| `"Model:"` dans `ai_models.dart` | **30 occurrences** |
| Appels `buildFallbackModelsField(...)` dans le formulaire **legacy** | **13 sites**, `ai_routers_dialogs.dart:540-601` ; le helper lui-même fait 46 l. (`:129-175`) |
| Le même formulaire **porté** | **1 boucle** `for (final String g in kAiRouterFallbackGroups)`, répétée 5 fois pour 5 usages distincts (`ai_router_zcrud_edition.dart:296, 400, 530, 620, 675`) |

Le modèle fait **365 lignes pour 31 champs** ; ~290 de ces lignes sont de la
recopie mécanique des 13 paires.

### 4.7 🔴 L'état vide illustré — 2 sites, 304 lignes

Le **même** état vide (cercle 180 dp → 160 → 120, `ShaderMask` sur `LinearGradient`,
titre, sous-titre, bouton d'action) est écrit deux fois, mot pour mot sauf le
libellé et le glyphe :

| Site | Lignes | Étendue |
|---|---:|---|
| `ai_routers_page.dart` | 145 | `:141-285` |
| `ai_experts_page.dart` | 159 | `:129-287` |

Le commentaire `// … empty state illustration` apparaît exactement à ces 2 endroits.

### 4.8 🔴 La grille responsive calculée à la main — 15 sites repo-wide, 2 dans le périmètre

```dart
const itemMinWidth = 350;
final screenWidth = constraints.maxWidth;
final crossAxisCount = screenWidth ~/ itemMinWidth;
final itemWidth = (screenWidth / crossAxisCount);
```

**15 sites** de `crossAxisCount = screenWidth ~/ itemMinWidth` dans `lib/`, dont
`ai_experts_page.dart:291-295` et `ai_routers_page.dart:290-294`. Le seuil varie
sans raison visible (350 fixe ici, `Get.width >= 840 ? 350 : 300` ailleurs).

### 4.9 🔴 Le formulaire d'expert IA — 40 `DynamicFormField` dans un fichier

| Fichier | `DynamicFormField(` |
|---|---:|
| `ai_experts_dialogs.dart` | **40** |
| `ai_routers_dialogs.dart` | **12** |
| `chatbot_screen.dart` | 2 |
| **Total périmètre** | **54** |

Avec sous-listes imbriquées **à trois niveaux** (`ai_experts_dialogs.dart:175-330`),
chacune redéclarant son `listViewBuilder`, son `customItemBuilder`, son
`onCrud`, sa couleur de libellé en dur (`const labelColor = Colors.teal`, `:358`).

### 4.10 🔴 La feuille de réglages faite main — 671 lignes contre 168

`ToolsSheet` + `ToolTile` + `MinMaxFormatter` + `ToolNumberInputTile` +
`ToolSelectTile<T>` + `_ValueNotifierBuilder` occupent
`chatbot_conversation_screen.dart:4510-5180` = **671 lignes**, pour ce que
`notebook_settings_iffd.dart` (**168 l.**) exprime en déclarant des
`ZChatSettingsSection` / `ZChatSettingsLabel` / `ZChatCorpusOption` servis par
`ZChatMaterialSettingsSheet`.

### 4.11 Couleurs codées en dur — 61 sites dans le périmètre

| Fichier | `Color(0x…)` |
|---|---:|
| `ai_experts_page.dart` | 23 |
| `ai_routers_page.dart` | 12 |
| `ai_router_sub_list_seams.dart` | 5 |
| `empty_conversations_state.dart` | 4 |
| `conversation_actions_menu.dart` | 4 |
| `conversation_item_widget.dart` | 3 |
| `chatbot_conversation_screen.dart` | 3 |
| `conversation_item_zcrud.dart` | 2 |
| `notebook_artifact_menu_iffd.dart` | 2 |
| `folder_conversations_widget.dart` | 2 |
| `ai_routers_dialogs.dart` | 1 |
| **Total** | **61** |

S'y ajoutent les `Colors.*` littéraux des tables de variantes et de menus, relevés
comme **délibérés** par le portage (« ce sont les repères que l'utilisateur a
appris », `notebook_artifact_menu_iffd.dart:35-37`).

### 4.12 Ce qui n'est **pas** dupliqué (dit pour ne pas surestimer)

- `buildConfirmDialog` est **factorisé** (`lib/src/utils/functions/forms_utils.dart:480`),
  36 appels dans `lib/`, 8 dans le périmètre. Pas de duplication.
- `iffdAiAuthHeaders` / `iffdAiPayload` **ont déjà été extraits** (§3.6).
- L'état chargement/erreur/vide n'est **pas** dupliqué 12 fois : 14 `StreamBuilder`
  dans le périmètre, mais seuls 5 fichiers testent explicitement
  `ConnectionState.waiting` / `snapshot.hasError`. Le motif coûteux est ailleurs :
  chaque `StreamBuilder` refait **son propre filtrage + tri + recherche** en ligne
  (`ai_experts_page.dart:88-118`, `ai_routers_page.dart:133-139`,
  `conversation_list_widget.dart:172-201`).

---

## 5. Ce qui est DÉJÀ branché sur zcrud

### 5.1 Volumétrie

**31 fichiers, 8 260 lignes** sous `**/zcrud/**` dans le périmètre, répartis en :

| Dossier | Fichiers | Lignes |
|---|---:|---:|
| `lib/ai_assistant/zcrud/` | 20 | 5 196 |
| `lib/src/presentation/features/chatbot/zcrud/` | 4 | 605 |
| `lib/src/presentation/features/ai_routers/zcrud/` | 2 | 1 023 |
| `lib/src/presentation/features/administration/zcrud/` (ai_expert) | 2 | 727 |
| `lib/src/presentation/features/folders/zcrud/` (3 fichiers IA) | 3 | 709 |

### 5.2 Paquets consommés (dans le périmètre IA)

`zcrud_chat`, `zcrud_chat_kernel`, `zcrud_chat_material`, `zcrud_chat_markdown`,
`zcrud_chat_syncfusion`, `zcrud_core`, `zcrud_study`.

Repo-wide, IFFD importe **22 paquets zcrud** (55 fichiers importent `zcrud_core`,
19 `zcrud_chat_kernel`, 17 `zcrud_study`, 15 `zcrud_chat`, 11 `zcrud_flashcard`…)
et en déclare ~30 en `dependency_overrides` (`pubspec.yaml:305-729`).

### 5.3 Symboles zcrud consommés — 80 distincts

`ZAcl`, `ZAllowAllChatRouteGate`, `ZChatArtifactAction`, `ZChatArtifactResolvers`,
`ZChatArtifactSpec`, `zChatArtifactSpecsOf`, `ZChatArtifactVerbAction`,
`ZChatComposerPickerAction`, `ZChatController`, `ZChatConversationScreen`,
`ZChatCorpusOption`, `ZChatCorpusScope`, `ZChatCustomAction`,
`ZChatGenerationRequest`, `ZChatGenerationStyle`, `ZChatMarkdownRenderer`,
`ZChatMaterialComposer`, `ZChatMaterialSettingsSheet`, `ZChatMessage`,
`ZChatMessageTile`, `ZChatModelOption`, `ZChatNotebookController`,
`ZChatNotebookSkin`, `ZChatNotebookView`, `zChatPrecedingRequestTopic`,
`ZChatRendererScope`, `ZChatRequestToken`, `ZChatRole`, `ZChatRouteResolver`,
`ZChatRouteSession`, `ZChatSettingsController`, `ZChatSettingsLabel`,
`ZChatSettingsSection`, `ZChatShellRendererScope`, `ZChatTileShell`, `ZCrudAction`,
`ZcrudTheme`, `ZDomainFailure`, `ZEditionBodyFit`, `ZEditionPresentation`,
`ZEditionStep`, `ZEditionSubmitController`, `ZEntity`, `ZFailure`,
`ZFieldAdornment`, `ZFieldChoice`, `ZFieldSpec`, `ZFieldWidgetBuilder`,
`ZFieldWidgetContext`, `ZFormController`, `ZFormOnly`, `ZFormOnlyController`,
`ZIffdTextStreamPort`, `ZItemActionState`, `zReadableTintOn`, `ZResult`,
`ZServerFailure`, `ZSfAssistShellRenderer`, `ZStepperEdition`, `ZSubListConfig`,
`ZSubListHeaderView`, `ZSubListItemTemplate`, `ZSubListItemView`,
`ZSubListSeamRegistry`, `ZSubListSeams`, `ZTextCapitalization`, `ZTextConfig`,
`ZUnsupportedOperationFailure`, `ZValidatorSpec`, plus les constantes
`kZChatArtifactVerb{Edit,Open,Print}`, `kZChatCapability{Classroom,Flashcards,Humour,Mindmap,Story}`,
`kZChatSettingsSection{Corpus,Generation}`, `kZNonTextMinContrast`.

### 5.4 Registre de widgets

`buildIffdWidgetRegistry()` — `lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart:78-201`
(445 l. au total, un registre **par montage**, jamais un singleton).

| Enregistrement | Ligne | Ce qui est servi |
|---|---:|---|
| `registerZMarkdownFields(registry, codec: IffdRichTextCodec(), styleSet: iffdMarkdownStyleSet(), chrome: …)` | `:101` | tous les champs markdown/rich-text |
| `registerZFlashcardEditors(registry, trueLabel:'Vrai', falseLabel:'Faux', addChoiceLabel:…)` | `:171` | sélecteur de type, éditeur de QCM, vrai/faux (kind `custom`) |
| `registry.register('phoneNumber', ZPhoneFieldWidget.builder())` | `:188` | champ téléphone (`zcrud_intl`) |
| `registry.register(kIffdBooleanKind, iffdBooleanBuilder())` | `:199` | **tous** les booléens de l'application (`FlutterSwitch`) |

⚠️ Aucun de ces enregistrements n'est spécifique au domaine IA — ils servent le
formulaire de routeur et celui d'expert par ricochet.

### 5.5 État réel des drapeaux — **le chemin zcrud du chat est DORMANT**

| Drapeau | Fichier:ligne | Défaut | Ce qu'il commande |
|---|---|:--:|---|
| `kNotebookUseZcrudDefault` | `notebook_zcrud_flag.dart:41` | **`false`** | le Notebook **et** l'onglet Assistant (`chatbot_screen.dart:679-686`, `folder_explanation_page.dart:159-163`, `dashbord_page.dart:383`) |
| `kChatbotMessageUseZcrudDefault` | `chatbot_message_adapter.dart:40` | **`false`** | le rendu d'un message (`chatbot_conversation_screen.dart:4295`) |
| `kChatbotConversationListUseZcrudDefault` | `chatbot_conversation_adapter.dart:46` | **`false`** | la liste de conversations (`conversation_list_widget.dart:213`) |
| `kConversationItemUseZcrudDefault` | `conversation_item_zcrud.dart:221` | **`false`** | la tuile de conversation |
| `kAiExpertEditionUseZcrudDefault` | `ai_expert_zcrud_edition.dart:87` | **`false`** | le formulaire d'expert IA |
| `kAiBaseUrlEditionUseZcrudDefault` | `ai_base_url_zcrud_edition.dart:58` | **`false`** | le formulaire d'URL du service IA |
| **`kAiRouterEditionUseZcrudDefault`** | `ai_router_zcrud_edition.dart:91` | **`true`** ✅ | **le formulaire de routeur IA — seul chemin zcrud actif du domaine** |

⇒ **8 260 lignes portées, dont une seule surface est servie par défaut** : le
formulaire de routeur IA (`ai_routers_dialogs.dart:53-58`). Tout le reste est
joignable uniquement par le registre de QA (`z_qa_flags.dart`, 467 l., entrées
`chatMessageTile:277`, `chatConversationList:286`, `chatConversationTile:296`,
`notebook:305`, `aiBaseUrl:269`).

### 5.6 ⚠️ Contradiction documentaire à trancher — B-60

| Fichier | Dit | Dernier commit |
|---|---|---|
| `notebook_zcrud_flag.dart:20-31` | « **LE FIL PORTÉ N'ÉCRIT RIEN** […] une conversation tenue derrière ce drapeau est perdue en quittant l'écran » | `f21d94d`, **2026-08-06** |
| `z_qa_flags.dart:318` | « ⚠️ CE FIL N'ENREGISTRE RIEN (B-60) » | — |
| `main.dart:183` | « ⚠️ Ce fil n'ENREGISTRE RIEN (B-60) » | — |
| `notebook_transcript_iffd.dart:4` | « 🔴 **FIN DU B-60** » — et le fichier **implémente** `append` (`:74`) et `update` (`:121`) vers `ChatbotMessageRepository` | `f722ac9`, **2026-08-23** |
| `assistant_chat_zcrud_mount.dart:1-10` | « CR-IFFD-90, LIVRÉE EN v3.11.0 […] le B-60 ne peut plus revenir par cette porte » | — |

Le code le plus récent contredit trois avertissements toujours en place. **Non
tranché ici** : je n'ai pas exécuté le fil, je constate seulement que `append` et
`update` existent et écrivent (`notebook_transcript_iffd.dart:74-143`).

Réserve **encore vraie et gardée** : l'adaptateur de message est *unidirectionnel*
par construction — `chatbot_message_adapter.dart:1-31`, avec une garde structurelle
(`test/w9a/chatbot_message_adapter_test.dart`) qui échoue si `toMap()` est appelé sur
un `ZChatMessage` où que ce soit dans `lib/`. `flashcards` et `mindmap` **ne
deviennent pas des blocs** (`:26-31`).

### 5.7 Ce que le catalogue de routes exploite déjà

`notebook_route_catalog_iffd.dart` (106 l.) décode `IffdAiRouterModel` par la forme
**`suffixPairs`** du socle — « une paire de clés par tâche », `<tâche>Model` /
`<tâche>FallbackModels` — sans qu'aucune clé IFFD ne vive côté zcrud
(`:1-8`). Il note **13 paires, pas 12** (`:26-31`), et documente pourquoi la source
`ZChatRepositoryRouteCatalogSource` n'est **pas** utilisée : elle filtre sur
`isActive`, champ que `IffdAiRouterModel` **n'a pas** — elle rendrait zéro routeur
sans erreur (`:11-23`). C'est un manque **côté modèle IFFD**, pas côté socle.

---

## 6. Les widgets maison qui refont ce que zcrud fait probablement

| Widget maison | Chemin:ligne | Lignes | Ce que le socle offre déjà (mesuré par l'usage porté) |
|---|---|---:|---|
| `SfExplainScreen` / `SfChatBotScreen` | `chatbot_conversation_screen.dart:232`, `:4499` | **5 180** | `ZChatNotebookView` (via `NotebookZcrudView`, 926 l.) et `ZChatConversationScreen` (via `mountIffdAssistantChat`, 230 l.) |
| `ToolsSheet` + `ToolTile` + `ToolNumberInputTile` + `ToolSelectTile` + `MinMaxFormatter` + `_ValueNotifierBuilder` | `chatbot_conversation_screen.dart:4510-5180` | **671** | `ZChatMaterialSettingsSheet` + `ZChatSettingsController` + `ZChatSettingsSection` / `ZChatSettingsLabel` / `ZChatCorpusOption` — 168 l. dans `notebook_settings_iffd.dart` |
| `ConversationListWidget` | `conversation_list_widget.dart:27` | 362 | `ConversationListZcrudView` (144 l.) : états chargement/erreur/vide, groupement, recherche, `onRetry` — décidés par le socle (`:203-260`) |
| `ConversationItemWidget` | `conversation_item_widget.dart:15` | 241 | `ConversationItemZcrudView` (238 l., dont le `_Pastille` maison qui reste hôte) |
| `FolderConversationsWidget` | `folder_conversations_widget.dart:18` | 218 | même famille que ci-dessus (groupement par dossier) |
| `EmptyConversationsState` | `empty_conversations_state.dart` | 107 | `emptyBuilder` du socle — IFFD l'injecte déjà (`conversation_list_widget.dart:248-254`) |
| `ConversationSearchBar` | `conversation_search_bar.dart` | 123 | `searchTerm` du socle (`conversation_list_widget.dart:236`) |
| `ConversationActionsMenu` | `conversation_actions_menu.dart` | 157 | `ZChatArtifactAction` / `ZChatCustomAction` / `ZChatArtifactVerbAction` |
| `AiRouterEditionScreen` (legacy) | `ai_routers_dialogs.dart:110-716` | ~606 | `ZStepperEdition` + `ZFieldSpec` + `ZSubListConfig` + `ZAcl` — **déjà porté et actif** |
| `AiExpertdEditionScreen` (legacy) | `ai_experts_dialogs.dart:42` | 1 200 | `ai_expert_zcrud_edition.dart` (534 l.) — porté, **drapeau à `false`** |
| État vide illustré ×2 | `ai_routers_page.dart:141-285`, `ai_experts_page.dart:129-287` | 304 | l'état vide du socle |
| Grille responsive manuelle ×2 | `ai_experts_page.dart:291-295`, `ai_routers_page.dart:290-294` | ~10 | déjà encapsulée côté zcrud pour les flashcards (`flashcard_list_zcrud.dart:94`) |
| `IffdVariantMenuSpec` / `IffdArtifactMenus` (maison, mais **du côté porté**) | `notebook_artifact_menu_iffd.dart` | 379 | complète `ZChatArtifactSpec` ; c'est une **table de relevé**, pas un doublon |
| `AiPromptGenerator` (mixin) | `lib/src/domain/services/ai/ai_prompt_generator.dart` | 597 | assemble les prompts côté client ; **pas d'équivalent socle relevé** — à conserver ou à déplacer côté backend |

**Total des surfaces maison directement recouvertes par le socle :
~9 070 lignes** (fil 5 180 + réglages 671 + listes/tuiles/états 1 208 + formulaires
legacy 1 806 + états vides 304).

---

## 7. Ce qui bloquera la migration — constats à trancher

1. **`AiRepository` n'a pas de paramètre de style de génération.** Le socle porte un
   discriminant ouvert (`ZChatGenerationStyle`, dont les constantes citent
   nommément `summarize_explanation` et `elaborate_explanation` d'IFFD), mais le
   port IFFD n'a aucun créneau pour le transporter jusqu'au fournisseur — le manque
   est **chez IFFD** (`notebook_ports_iffd.dart:28-31`).
2. **`IffdAiRouterModel` n'a pas de champ `isActive`** — la source de catalogue
   « repository » du socle rendrait zéro routeur sans erreur
   (`notebook_route_catalog_iffd.dart:11-23`).
3. **Une variante n'est pas un message, c'est un champ du message** : elle ne produit
   pas de tour de conversation. Le legacy écrit `mapUpdate({"id": …, dataKey: data})`
   ET conserve une **paire de messages annexes** requête/réponse ; supprimer le champ
   sans supprimer la paire fait **réapparaître** la variante au rechargement
   (`notebook_artifact_menu_iffd.dart:46-56`, `notebook_variants_iffd.dart:18-27`).
4. **Deux sources de couleur divergentes** pour les variantes : l'enum
   `ChatbotMessageTransformer` (bleu pour `summary`) et la table d'écran (blueGrey) —
   c'est la **table d'écran** qui décide de ce que l'utilisateur voit
   (`notebook_variants_iffd.dart:36-42`).
5. **`Timestamp` de `cloud_firestore` fuit dans les modèles de domaine**
   (`chatbot_message.dart:3`, `chatbot_conversation.dart:4`, `ai_expert.dart:3`) —
   incompatible avec AD-11 tel quel.
6. **Deux régimes d'erreur** (`DataState` vs callback `AiResponse`) à unifier vers
   `ZResult`/`ZFailure`.
7. **`IffdAiRepositoryImpl` est un singleton statique mutable**
   (`iffd_ai_repository_impl.dart:32-39`) et lit son URL de base par un **mixin de
   présentation** (`smartLearnInstance.aiBaseUrl`, `:47`) — un `TODO(migration)`
   l'admet au `:43-46`.

---

## 8. Couverture de test existante

**37 fichiers de test** sur 208 touchent le domaine (18 %), dont :
`test/m0/` (13 fichiers notebook/variantes/artefacts), `test/qa-w2/` (8 fichiers
transport/parité/corpus), `test/w9a`, `test/w9b`, `test/w9d`, `test/w8l`,
`test/w8m`, `test/w7e`, `test/w7h`, `test/chat/`, `test/characterization/`.

---

*Fin du relevé. Aucun fichier d'IFFD n'a été modifié ; aucun test n'a été lancé.*
