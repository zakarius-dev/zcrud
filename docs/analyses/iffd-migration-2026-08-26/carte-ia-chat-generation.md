# Carte du domaine « IA — assistant, chatbot, génération, explication, routeurs » (IFFD)

Relevé du **2026-08-26**, mesuré sur `/home/zakarius/DEV/iffd`, branche `feat/migration-zcrud`,
HEAD `65d1af9`. Socle de référence : `zcrud` v3.21.0 (41 paquets).

> Le relevé `docs/analyses/iffd-migration-2026-08-25/` n'a servi que de piste. **Aucun de ses
> constats n'est repris sans remesure** ; tout `fichier:ligne` ci-dessous a été relu sur disque.

---

## 0. Périmètre réellement retenu

Les six chemins du brief comptent **57 fichiers / 18 949 lignes**. En suivant les dépendances
réelles (modèles, dépôts, générateur de prompts, montages, formulaires d'expert), le domaine
pèse **80 fichiers / 32 583 lignes**.

| Ajouté au-delà du brief | Fichiers | Lignes | Pourquoi |
|---|---:|---:|---|
| `lib/src/domain/models/ai/ai_models.dart` | 1 | 581 | `IffdAiRouterModel`, `AiResponse`, 6 enums |
| `lib/src/domain/repositories/ai_repository.dart` + `chatbot/` | 5 | 591 | le port : 29 méthodes, 26 endpoints |
| `lib/src/data/repositories/{iffd,openai,cloud_functions}_ai_repository_impl.dart` | 3 | 2 548 | **trois** implémentations du même port |
| `lib/src/domain/services/ai/ai_prompt_generator.dart` | 1 | 597 | 24 constructeurs de prompt |
| `lib/src/presentation/features/administration/{dialogs,pages,zcrud}/ai_expert*` | 4 | 3 257 | l'agent expert : legacy + porté |
| `lib/src/presentation/features/discovery/controllers/discovry_page_controller.dart` | 1 | 2 412 | le contrôleur IA de « Découverte » |
| `lib/src/presentation/features/flashcards/{widgets,controllers}/ai_*` | 2 | 1 522 | générateur de cartes IA, URL du service |
| `lib/src/presentation/features/documents/widgets/chatbot_document_selector_dialog_widget.dart` | 1 | 842 | sélecteur de corpus documentaire |
| `lib/src/presentation/features/folders/zcrud/notebook_*`, `assistant_chat_zcrud_mount.dart` | 3 | 890 | montages du Notebook porté |
| `lib/src/utils/constants/ai_systems_messages.dart` | 1 | 389 | messages système |

**Partage legacy / porté du périmètre :**

| | Fichiers | Lignes | Part |
|---|---:|---:|---:|
| **Porté zcrud** (`*/zcrud/*`, `*_zcrud*`) | 36 | 9 280 | 28 % |
| **Legacy** | 44 | 23 303 | 72 % |
| **Tests du domaine** (hors des 80) | 40 | 8 660 | — |

---

## 1. Ce que le domaine SAIT FAIRE

En termes d'utilisateur, et non de technique.

### 1.1 Converser

- **Tenir une conversation avec un assistant IA**, adossée à un dossier d'étude, un
  sous-dossier ou un document (`ChatbotConversationType`, `chatbot_conversation.dart:8-12`).
- **Ranger ses conversations** : créer, renommer, archiver, supprimer, rechercher, regrouper
  par dossier d'étude (`conversation_list_widget.dart`, `conversation_actions_menu.dart`).
- **Choisir la portée documentaire** d'une question parmi **six corpus douaniers
  ouest-africains** — Code du GATT, TEC CEDEAO, Code des douanes CEDEAO, Codes des douanes
  du Togo et du Niger, Code général des impôts du Togo
  (`notebook_settings_iffd.dart:56-63`).
- **Activer la recherche web**, le *scraping* des résultats, et une **réflexion à effort
  gradué** de 0 à 5 (`discovry_page_controller.dart:938-953`).
- **Parler à un « expert »** — un agent au domaine, aux instructions, à la base de
  connaissances et aux exemples de réponses déclarés (`ai_expert.dart`).

### 1.2 Générer

**29 intentions de génération** déclarées au port (`ai_repository.dart:74-476`), servies par
**26 endpoints nommés** (`:22-72`). Regroupées :

| Famille | Ce que l'utilisateur obtient |
|---|---|
| Expliquer | l'explication d'un sujet, un développement, un résumé, des sujets connexes |
| Reformuler | **sept variantes** d'une même réponse (résumé, développement, exemples, poème, histoire, humour, séance de cours) |
| Étudier | flashcards depuis un sujet / des notes / un document entier / des pages choisies ; indice ; évaluation d'une réponse |
| Cartographier | carte mentale depuis des notes / un document entier / des pages |
| Écouter | podcast et lecture audio d'un message (5 fournisseurs TTS, `ai_models.dart:107-117`) |
| Étiqueter | étiquettes d'un sujet |
| Exporter | markdown → PDF, flashcards → PDF |
| Administrer | instructions d'un expert, ingestion de ses documents |

- **Quatre types de résumé** : par défaut, chronologique, hiérarchique, détaillé — chacun
  portant son instruction rédigée (`ai_models.dart:65-105`).
- **Dix styles d'explication** (`ExplainStyle`, `ai_models.dart:9-52`).

### 1.3 Router

- **Déclarer un « routeur IA »** : quel modèle sert quelle tâche, avec ses modèles de repli,
  et un **effort d'exécution** en trois paliers — Mini / Plus / Pro
  (`WorkflowEffort`, `ai_models.dart:119-150`).
- **Treize tâches routables**, chacune avec modèle + liste de repli (§4.2).
- **Régler l'URL du service IA** (schéma, hôte, port, version) depuis l'application
  (`ai_base_url_zcrud_edition.dart`).

### 1.4 Agir sur une réponse

- **Modifier, régénérer, supprimer** un message (`notebook_capabilities_iffd.dart:389-391`).
- **Enregistrer dans les notes**, **exporter en PDF**, **copier** (avec variante « sans
  gras », `chatbot_conversation_screen.dart:90-135`).
- **Ouvrir une carte mentale** ou **une série de flashcards** produite depuis un message, et
  la réviser (`notebook_artifact_specs_iffd.dart:95-125`).

---

## 2. Écrans et dialogues

### 2.1 Legacy

| Fichier | Lignes | Rôle | Porte |
|---|---:|---|---|
| `lib/ai_assistant/screens/chatbot_conversation_screen.dart` | **5 356** | le fil de conversation, la barre d'artefacts, la feuille d'outils, l'aperçu PDF | rendu riche + navigation + 32 menus |
| `lib/src/presentation/features/discovery/controllers/discovry_page_controller.dart` | 2 412 | contrôleur « Découverte » (état IA global) | état |
| `lib/src/presentation/features/administration/pages/ai_experts_page.dart` | 1 330 | liste des agents experts | liste |
| `lib/src/presentation/features/flashcards/widgets/ai_flashcards_generator_dialog_widget.dart` | 1 238 | générer des cartes depuis un document | formulaire + liste |
| `lib/src/presentation/features/administration/dialogs/ai_experts_dialogs.dart` | 1 200 | éditer un agent expert (**40** `DynamicFormField`) | formulaire |
| `lib/src/presentation/features/documents/widgets/chatbot_document_selector_dialog_widget.dart` | 842 | choisir les documents du contexte | liste (9 `StreamBuilder`) |
| `lib/src/presentation/features/explain_ai/pages/explain_ai_page.dart` | 812 | lire une explication IA | rendu riche |
| `lib/src/presentation/features/ai_routers/pages/ai_routers_page.dart` | 803 | liste des routeurs IA | liste |
| `lib/ai_assistant/screens/chatbot_screen.dart` | 799 | coquille responsive de l'assistant | navigation |
| `lib/src/presentation/features/ai_routers/dialogs/ai_routers_dialogs.dart` | 716 | éditer un routeur IA | formulaire + sous-listes |
| `lib/ai_assistant/widgets/*` (6 fichiers) | 1 208 | liste, tuile, menu, recherche, état vide, groupe par dossier | liste |

**Un `build()` unique de 4 272 lignes.** `chatbot_conversation_screen.dart:426` ouvre
`_SfExplainScreenState.build`, qui ne se referme qu'à `:4697` — la méthode suivante est
`SfChatBotScreen` (`:4675`, classe) puis `ToolsSheet.build` (`:4698`). L'**indentation
maximale atteint la colonne 81** (ligne 1868), soit ~40 niveaux d'imbrication.

Trois autres écrans suivent le même motif : `explain_ai_page.dart:122→812` (690 l),
`ai_routers_page.dart:38→637` (599 l), `ai_routers_dialogs.dart:126→716` (590 l).

### 2.2 Jumeaux portés et leur drapeau

**Douze** drapeaux de bascule du domaine IA, tous inscrits au registre
`lib/src/presentation/shared/zcrud/z_qa_flags.dart` (52 drapeaux au total → **23 %** du
registre est du domaine IA). Aucun n'est coché dans
`docs/qa-plan-comparaison-legacy-zcrud.md` (☐ pour les douze, `:592-639`).

| Drapeau | Famille | Jumeau porté | Lignes | Legacy remplacé |
|---|---|---|---:|---|
| `chatMessageTile` | rendu | `chatbot_message_adapter.dart` | 115 | bulle de message |
| `chatConversationList` | rendu | `conversation_list_zcrud.dart` | 144 | `conversation_list_widget.dart` (362) |
| `chatConversationTile` | rendu | `conversation_item_zcrud.dart` | 238 | `conversation_item_widget.dart` (241) |
| `chatConversationEdition` | comportement | `chatbot_conversation_zcrud_edition.dart` | 273 | dialogue de renommage |
| `notebook` | comportement | `notebook_zcrud.dart` + 21 fichiers | **4 862** | le fil entier |
| `pdfPreviewRichReader` | rendu | `pdf_preview_rich_reader_zcrud_flag.dart` | 63 | `RichTextReaderScreen` |
| `aiExplanationRichReader` | rendu | `ai_explanation_zcrud_reader.dart` | 162 | 4 montages du lecteur legacy |
| `aiRouterEdition` | comportement | `ai_router_zcrud_edition.dart` + seams | 1 014 | `ai_routers_dialogs.dart` (716) |
| `aiBaseUrl` | comportement | `ai_base_url_zcrud_edition.dart` | 284 | formulaire d'URL |
| `aiExpert` | **données** | `ai_expert_zcrud_edition.dart` + champ | 727 | `ai_experts_dialogs.dart` (1 200) |
| `smartNoteAiInstructions` | comportement | `smartnote_ai_instructions_zcrud_edition.dart` | 311 | instructions de note |
| `richTextEditor` | **données** | `notebook_artifact_actions_iffd.dart` | 488 | éditeur riche plein écran |

**Deux jumeaux neufs** au commit `a3d10b7` : `chatbot_conversation_zcrud_edition.dart` (273) et
`smartnote_ai_instructions_zcrud_edition.dart` (311).

---

## 3. Modèles et persistance

### 3.1 Entités

| Modèle | Fichier | Lignes | Champs notables |
|---|---|---:|---|
| `ChatbotMessage` | `ai_assistant/models/chatbot_message.dart` | 390 | ~30 champs, dont **7 champs de variante** (`summary`, `elaboration`, `examples`, `poem`, `story`, `humor`, `chat`, `:150-156`) |
| `ChatbotConversation` | `ai_assistant/models/chatbot_conversation.dart` | 144 | 12 champs |
| `AiExpert` | `ai_assistant/models/ai_expert.dart` | 325 | identité, instructions, RAG, **6 défauts de corpus** |
| `AiExpertKnowledge` | `ai_assistant/models/ai_expert_knowledge.dart` | 96 | base de connaissances |
| `AiExpertResponsesExample` | `ai_assistant/models/ai_expert_responses_example.dart` | 89 | exemples de réponses |
| `IffdAiRouterModel` | `src/domain/models/ai/ai_models.dart:190-581` | 391 | **13 paires** modèle/replis |
| `AiResponse` | `src/domain/models/ai/ai_models.dart:152-189` | 38 | enveloppe de réponse |

### 3.2 Sérialisation — entièrement manuelle

**Aucun modèle du domaine n'est annoté.** Grep négatif :

```
$ grep -n "@ZcrudModel\|@ZcrudField" <les 80 fichiers>
RC=123   (aucune occurrence)
```

Volume de code écrit à la main que le codegen zcrud produirait :

| Modèle | Total | `copyWith`+`toMap`+`fromMap`+`props` | Part |
|---|---:|---:|---:|
| `ai_expert.dart` | 325 | 237 (`:88-325`) | 73 % |
| `chatbot_message.dart` | 390 | 200 (`:190-390`) | 51 % |
| `chatbot_conversation.dart` | 144 | 100 (`:44-144`) | 69 % |
| `ai_expert_knowledge.dart` | 96 | 72 (`:24-96`) | 75 % |
| `ai_expert_responses_example.dart` | 89 | 68 (`:21-89`) | 76 % |
| **Total** | **1 044** | **677** | **65 %** |

### 3.3 Le backend fuit dans le domaine

`cloud_firestore.Timestamp` est manipulé **directement dans les modèles** — violation de
l'invariant « aucun type `cloud_firestore` dans le domaine » :

| Fichier | Occurrences de `Timestamp` |
|---|---:|
| `chatbot_conversation.dart` | 8 (dont `import 'package:cloud_firestore/cloud_firestore.dart'` `:4`) |
| `chatbot_message.dart` | 4 |
| `ai_expert.dart` | 4 |

### 3.4 Erreurs

Le domaine n'utilise **pas** `Either<ZFailure, T>`. Le port entier retourne `Future<void>` et
remonte le résultat par **callback** :

```dart
void Function(AiResponse result, bool completed, {bool hasError})? onComplete
```

Cette signature exacte est écrite **119 fois** :

| Fichier | Sites |
|---|---:|
| `ai_repository.dart` (port) | 28 |
| `iffd_ai_repository_impl.dart` | 28 |
| `openai_ai_repository_impl.dart` | 28 |
| `cloud_functions_ai_repository_impl.dart` | 28 |
| `discovry_page_controller.dart` | 5 |
| `notebook_capabilities_iffd.dart` | 2 |

Seul le chemin **porté** rend des `ZResult` (`notebook_transcript_iffd.dart:74`, `:121`).

---

## 4. LE CODE RÉPÉTÉ

### 4.1 Les six corpus documentaires — **201 sites, 11 fichiers**

Une liste de six éléments, réécrite à la main partout.

| Fichier | Sites |
|---|---:|
| `discovry_page_controller.dart` | 60 |
| `ai_assistant/models/ai_expert.dart` | 46 |
| `chatbot_conversation_screen.dart` | 18 |
| `ai_assistant/zcrud/notebook_settings_iffd.dart` *(porté)* | 15 |
| `ai_repository.dart` | 12 |
| `iffd_ai_repository_impl.dart` | 12 |
| `openai_ai_repository_impl.dart` | 12 |
| `cloud_functions_ai_repository_impl.dart` | 12 |
| `ai_expert_zcrud_edition.dart` *(porté)* | 6 |
| `ai_experts_dialogs.dart` | 6 |
| `notebook_byte_opener_iffd.dart` *(porté)* | 2 |

Dont **six bascules identiques de 4 lignes** (`discovry_page_controller.dart:896-923`) :

```dart
void toggleCDNTogo()  { enableCDNTogo  = !enableCDNTogo;  notifyListeners(); }
void toggleCDNNiger() { enableCDNNiger = !enableCDNNiger; notifyListeners(); }
// … quatre fois de plus
```

Le porté les remplace par **six lignes de données** (`notebook_settings_iffd.dart:56-63`,
`ZChatCorpusOption(key:, label:)`).

> 🔴 **Et ces 36 déclarations legacy ne servent à RIEN.** Les six drapeaux sont déclarés en
> paramètre des trois implémentations et **ne sont posés dans aucun corps de requête**.
>
> ```
> $ grep -n '"enableCDNTogo"\|"enableCodeGATT"\|"enableTecCedeao"\|"corpus"' \
>       lib/src/data/repositories/iffd_ai_repository_impl.dart
> RC=1                          # jamais transmis
> $ # idem openai_ai_repository_impl.dart : RC=1
> $ # idem cloud_functions_ai_repository_impl.dart : RC=1
> ```
>
> Déclarations : `iffd_ai_repository_impl.dart:680-685` et `:727-732`, 12 par implémentation,
> **36 au total, 0 transmission**. Cocher « Code du GATT » côté legacy ne restreint rien.

### 4.2 Les treize tâches routables

| Où | Forme | Lignes |
|---|---|---:|
| `ai_models.dart:194-236` | 13 paires de champs écrites à la main | 43 |
| `ai_routers_dialogs.dart:540-604` | 13 blocs `buildFallbackModelsField(fieldName:, label:)` | 65 |
| `ai_router_zcrud_edition.dart:308-317` | **une boucle** `for (final String g in kAiRouterFallbackGroups)` | **10** |
| `notebook_route_catalog_iffd.dart:43-58` | **une forme** `ZChatRouteCatalogShape.suffixPairs` — découvre les 13 par suffixe | **16** |

Le pont de catalogue est le meilleur exemple d'assemblage réussi : il ne tient **aucune
liste**, et son commentaire le dit — « le décodeur les découvre toutes par suffixe […] c'est
ce qui rend le pont robuste à la quatorzième » (`:27-30`).

### 4.3 Trois implémentations du même port — **2 548 lignes**

| Implémentation | Lignes | Méthodes |
|---|---:|---:|
| `iffd_ai_repository_impl.dart` | 1 377 | 28 |
| `openai_ai_repository_impl.dart` | 672 | 28 |
| `cloud_functions_ai_repository_impl.dart` | 499 | 28 |

Chaque méthode a la **même forme** : construire un prompt, appeler `callApi`. Exemple
(`iffd_ai_repository_impl.dart:740-760`) :

```dart
final prompt = subjectExplainationPrompt(subject: subject, /* … */);
return callApi(
  endpoint: aiRouter?.explanationModel ?? "explain",
  data: {"message": prompt, "model": aiRouter?.aiModel, "enableWebSearch": enableWebSearch},
  onComplete: onComplete,
);
```

**28 intentions × 4 déclarations (port + 3 impls) = 112 signatures** pour 28 comportements.

### 4.4 États chargement / erreur / vide

| Fichier | `StreamBuilder` | `hasError` | `ConnectionState` |
|---|---:|---:|---:|
| `chatbot_document_selector_dialog_widget.dart` | **9** | **0** | **0** |
| `chatbot_screen.dart` | 3 | — | — |
| `chatbot_conversation_screen.dart` | 3 | 6 | — |
| 8 autres fichiers | 1 chacun | — | — |

Le sélecteur de documents empile **neuf `StreamBuilder` imbriqués jusqu'à 5 niveaux**
(`:72`, `:96`, `:175`, `:182`, `:368`, `:425`, `:468`, `:643`, `:707`) et ne traite **aucun**
état d'erreur ni de chargement :

```
$ grep -n "hasError\|ConnectionState\|connectionState" \
      lib/src/presentation/features/documents/widgets/chatbot_document_selector_dialog_widget.dart
RC=1
```

Son indentation maximale atteint la **colonne 81** (ligne 546).

**Deux listes de conversations, deux qualités différentes** :

| | `conversation_list_widget.dart` | `folder_conversations_widget.dart` |
|---|---|---|
| Chargement | `:227` (`ConnectionState.waiting`) | **absent** |
| Erreur | `:225`, `:231` | **absent** |
| Vide | `:250`, `:284` (`EmptyConversationsState`) | `:138` → `SizedBox.shrink()` |
| Virtualisation | `ListView(` **non-builder**, `:292` | `Column(children: …map())`, `:145-150` |
| RTL | — | `EdgeInsets.only(left:)`, `:142` |

Le porté (`conversation_list_zcrud.dart`) rend les **trois états** en 144 lignes et documente
les quatre défauts qu'il ferme (`:1-31`).

### 4.5 Feuille d'outils

| | Lignes | Forme |
|---|---:|---|
| Legacy `ToolsSheet` + `ToolTile` + `ToolNumberInputTile` + `ToolSelectTile` + `MinMaxFormatter` + `_ValueNotifierBuilder` (`chatbot_conversation_screen.dart:4686-5356`) | **670** | widgets maison |
| Porté `notebook_settings_iffd.dart` | **168** | déclaration sur `ZChatMaterialSettingsSheet` |

### 4.6 Menus et barres d'action

`chatbot_conversation_screen.dart` porte **32 `MenuItem(`/`PopupMenuItem(`** (`:503`, `:742-778`,
`:1065-1110`, `:1295-1331`, `:2619-2628`, `:2805-2844`, `:3179`, `:4142`) et **13 montages de
`FlashcardGenerationIndicator`**, dont trois blocs quasi identiques
`Tooltip → ValueListenableBuilder → FlashcardGenerationIndicator → Stack → IconButton → Positioned`
(`:1822`, `:1909`, `:1989`).

La barre de variantes rend **neuf boutons** côte à côte (`:1292-1356`), chacun avec son glyphe,
sa couleur et son état — remplacée côté porté par **une table**
(`notebook_variants_iffd.dart`, 345 l).

### 4.7 Code mort

| Fichier | Lignes commentées ressemblant à du code |
|---|---:|
| `chatbot_conversation_screen.dart` | **526** (≈ 10 % du fichier) |
| `discovry_page_controller.dart` | 103 |
| `ai_flashcards_generator_dialog_widget.dart` | 22 |
| `iffd_ai_repository_impl.dart` | 21 |
| 5 autres | 55 |
| **Total legacy** | **747** |

### 4.8 Synthèse chiffrée des répétitions

| Bloc répété | Sites | Lignes en jeu |
|---|---:|---:|
| Les six corpus documentaires | 201 | ~400 |
| Signature de callback `AiResponse/completed/hasError` | 119 | ~360 |
| Les 13 tâches routables | 4 formes | 134 |
| Sérialisation manuelle des 5 modèles | 5 | 677 |
| Trois implémentations du même port | 3 | 2 548 |
| Code mort commenté | — | 747 |
| Feuille d'outils maison | 1 | 670 |
| Menus / items de barre | 32 | ~450 |

---

## 5. Ce qui est DÉJÀ branché sur zcrud

**25 paquets zcrud déclarés** dans `pubspec.yaml`, **48 entrées** (dépendances +
`dependency_overrides`), toutes épinglées sur **`ref: v3.21.0`** — l'hôte est **à jour du
socle**.

Dans le périmètre IA, **14 paquets** sont importés, pour **78 symboles distincts** :

| Paquet | Imports |
|---|---:|
| `zcrud_chat_kernel` | 18 |
| `zcrud_core` | 17 |
| `zcrud_chat` | 14 |
| `zcrud_study` | 13 |
| `zcrud_study_kernel`, `zcrud_markdown`, `zcrud_chat_syncfusion`, `zcrud_chat_material` | 3 chacun |
| `zcrud_screen`, `zcrud_chat_markdown` | 2 chacun |
| `zcrud_ui_kit`, `zcrud_navigation`, `zcrud_menu`, `zcrud_flashcard` | 1 chacun |

**Le Notebook est la surface la plus intégrée** : 22 fichiers, **4 862 lignes** d'adaptation
IFFD au-dessus de `ZChatNotebookController` et de ses ports.

### Ce qui est enregistré au registre

Aucun `ZcrudRegistry` / `ZTypeRegistry` / `ZSourceRegistry` n'est alimenté par ce domaine
(grep négatif : 0 site). **Trois registres** seulement sont montés :

| Registre | Sites | Où |
|---|---:|---|
| `ZChatArtifactRegistry` | 4 | `notebook_artifact_registry_iffd.dart` — carte mentale, flashcards, variantes |
| `ZSubListSeamRegistry` | 4 | `ai_router_sub_list_seams.dart` — les groupes de modèles |
| `ZRelationSourceRegistry` | 5 | formulaires d'expert et de conversation |

Et deux portées de rendu : `ZChatRendererScope` (4), `ZChatShellRendererScope` (2).

### Le catalogue de routes — l'assemblage qui a fonctionné

`notebook_route_catalog_iffd.dart` (106 l) branche `IffdAiRouterModel` sur
`ZChatRouteCatalogShape.suffixPairs` **sans qu'aucune clé IFFD ne vive dans le socle**. Il
documente aussi pourquoi la source « repository » du socle ne convient pas : elle filtre sur
`isActive`, champ que `IffdAiRouterModel` **n'a pas** — elle rendrait « ZÉRO routeur, sans
erreur » (`:12-18`). C'est le mode **transport par route** décrit par la décision d'owner du
2026-08-23, en production chez l'hôte.

---

## 6. Widgets maison qui refont ce que le socle fait

| Widget maison | Lignes | Équivalent socle | Lignes socle |
|---|---:|---|---:|
| `conversation_list_widget.dart` | 362 | `ZChatConversationList` | 941 |
| `conversation_item_widget.dart` | 241 | `ZChatConversationTile` | 455 |
| `folder_conversations_widget.dart` | 218 | `ZChatConversationList` (groupé) | — |
| `conversation_actions_menu.dart` | 157 | `ZChatConversationActions` | 205 |
| `conversation_search_bar.dart` | 123 | *(recherche intégrée à la liste)* | — |
| `empty_conversations_state.dart` | 107 | `emptyBuilder` de la liste | — |
| **Sous-total `lib/ai_assistant/widgets/`** | **1 208** | | |
| `ToolsSheet` + 5 classes (`chatbot_conversation_screen.dart:4686-5356`) | 670 | `ZChatMaterialSettingsSheet` | 2 046 |
| `SfExplainScreen` (le fil) | ~4 300 | `ZChatConversationScreen` / `ZChatNotebookView` | 544 / 189 |
| `chatbot_document_selector_dialog_widget.dart` | 842 | *(aucun équivalent direct)* | — |

Le socle offre **37 962 lignes** de surface chat (`zcrud_chat` 22 860 + `zcrud_chat_kernel`
15 102), plus `zcrud_chat_material` 2 807, `zcrud_chat_syncfusion` 1 022,
`zcrud_chat_markdown` 301.

### Qualité comparée legacy / porté

| Marqueur | Porté (9 280 l) | Legacy (23 303 l) |
|---|---:|---:|
| `EdgeInsetsDirectional` | 11 | **1** |
| `Semantics(` | 4 | **0** |

```
$ grep -n "Semantics(" <les 44 fichiers legacy>
RC=123      # zéro Semantics dans 23 303 lignes de legacy
```

**Mélange de gestionnaires d'état** : 7 fichiers (10 935 lignes) importent **à la fois**
`package:get/get.dart` et `flutter_riverpod` — `chatbot_conversation_screen.dart`,
`conversation_actions_menu.dart`, `ai_experts_dialogs.dart`, `ai_experts_page.dart`,
`chatbot_document_selector_dialog_widget.dart`, `explain_ai_page.dart`,
`ai_flashcards_generator_dialog_widget.dart`. `Get.back` compte **39 sites**, `Get.dialog` 3,
`Get.put` 3, `Get.find` 2 ; `showDialog` **0** (grep négatif RC=123).

---

## 7. Ce que le domaine fait de PARTICULIER

Ce qui résisterait à toute généralisation.

### 7.1 Une variante n'est pas un message : c'est un CHAMP du message

C'est la règle la plus structurante du domaine, et elle est documentée par l'hôte
(`notebook_variants_iffd.dart:18-27`). Le legacy écrit le résultat d'une reformulation
**dans le message existant** (`mapUpdate({"id": message.id, dataKey: data})`,
`chatbot_conversation_screen.dart:1013-1020`), d'où **sept colonnes** sur `ChatbotMessage`
(`:150-156`). Une variante **ne produit pas de tour de conversation** — elle remplace un
contenu à côté. Le fil du socle, qui raisonne en tours, ne peut pas la porter nativement.

**Trois pièges qui vont avec** (`notebook_variants_iffd.dart:31-47`) :

1. `classroom` **s'écrit `chat` en base** — trois noms pour une même chose (transformer
   `ChatbotMessageTransformer.classroom`, kind zcrud `'classroom'`, clé persistée `"chat"`).
2. **Deux sources de couleur divergentes** : `ChatbotMessageTransformer` peint `summary` en
   **bleu** (`chatbot_message.dart:17-80`), la table d'écran en **blueGrey**
   (`chatbot_conversation_screen.dart:1297`). C'est l'écran qui décide de ce que l'utilisateur voit.
3. `ExplainStyle.exampes` **porte une faute de frappe qui se persiste**
   (`ai_models.dart:10`). La corriger serait une migration de données ; le pont la reproduit
   telle quelle.

### 7.2 Le métier douanier ouest-africain

Les six corpus (Code du GATT, TEC CEDEAO, Code des douanes CEDEAO, Codes des douanes Togo et
Niger, CGI Togo) sont du métier IFFD pur. **Le mécanisme, lui, ne l'est pas** : le socle l'a
généralisé en `ZChatCorpusOption` (clé opaque + libellé traduisible), en réponse à CR-IFFD-72.
L'hôte le note explicitement (`notebook_settings_iffd.dart:25-29`).

S'y ajoutent `NiveauIFFD` (niveau académique de l'auditeur), `FiliereEtCycleIFFD`, et une
année académique dont dépend la visibilité d'un champ du formulaire de conversation
(`z_qa_flags.dart:483-486` : sans année sélectionnée, le champ « Dossier d'étude »
n'apparaît pas).

### 7.3 Une ACL qui refuse la suppression du dernier élément

`delete: items.length > 1` (`ai_routers_dialogs.dart:104`) — un routeur IA ne doit jamais se
retrouver sans modèle de repli, état où il ne pourrait plus rien router. Portée telle quelle
en `ZAcl` de sous-liste (`ai_router_zcrud_edition.dart:221-226`).

### 7.4 Des quirks legacy reproduits volontairement

- L'hôte du service IA subit un `ucFirst` : saisir `localhost` enregistre `Localhost`
  (`ai_base_url_zcrud_edition.dart:17-18`, porté « clé pour clé et type pour type »).
- Le `port` est persisté en **`String`**, pas en `int` (`:19-20`).
- Sur « Instructions personnalisées », **annuler efface le réglage** — seul des sept sites à
  ne pas garder la nullité (`qa-plan:577`).
- Le champ « module » d'export s'ouvre **toujours vide** et enregistrer sans rien taper
  **efface** le module (`z_qa_flags.dart:728-731`).

### 7.5 Un port de flux nommé d'après l'hôte, dans le socle

`zcrud_chat_syncfusion` porte **705 lignes** et **13 symboles `ZIffd*`**
(`z_iffd_lexer.dart` 180, `z_iffd_stream_normalizer.dart` 250, `z_iffd_stream_port.dart` 165,
`z_iffd_wire.dart` 110) — la convention de fil textuel d'IFFD, montée dans un paquet
réutilisable.

```
$ grep -rloE "ZLex[A-Z]|ZDodlp[A-Z]|ZDlcfti[A-Z]" packages --include='*.dart'
RC=1        # IFFD est le SEUL hôte dont le nom vit dans le socle
```

---

## 8. Défauts mesurés pendant ce relevé

### 8.1 🔴 La mise en garde QA « ce fil n'enregistre rien » est FAUSSE — et dangereuse

Le registre de bascules et le plan QA disent tous deux, mot pour mot :

> « ⚠️ CE FIL N'ENREGISTRE RIEN (B-60) : l'historique est lu à l'ouverture, et une conversation
> tenue ici est perdue en quittant l'écran. **Ne jamais l'utiliser sur un compte réel pour du
> travail à conserver.** »
>
> — `z_qa_flags.dart:509-511` et `docs/qa-plan-comparaison-legacy-zcrud.md:324`

**Le fil porté écrit chaque tour en base.** Chaîne mesurée :

1. `notebook_page_zcrud.dart:169` passe `_transcript` à `buildIffdNotebookController`.
2. `notebook_ports_iffd.dart:208` le passe à `ZChatNotebookController(transcript: …)`.
3. Le socle construit un `ZChatTranscriptBinding`
   (`z_chat_notebook_controller.dart:301`), commenté : « La persistance du fil […]
   **chaque tour écrit** » (`:300-303`).
4. Le binding appelle `_transcript.append(m)` pour tout message inconnu
   (`z_chat_transcript_binding.dart:150`).
5. `IffdTranscriptPort.append` appelle **`repository.create(...)`**
   (`notebook_transcript_iffd.dart:100`) — un vrai document Firestore, **sous un id choisi
   pour que « le legacy le lit comme les siens »** (`:85-86`).

**Chronologie de la dérive :**

| Date | Commit | Fait |
|---|---|---|
| 2026-08-06 | `f21d94d` | la mise en garde B-60 est écrite (le fil ne persistait alors pas) |
| 2026-08-23 | `15f0cbe` | `IffdTranscriptPort` + `repository.create` : le fil **se met à persister** |
| 2026-08-23 | `f722ac9` | correctif « la réponse IA arrivait **incomplète en base** » — preuve d'écritures |
| 2026-08-25 | `3c59184` | la mise en garde périmée est **recopiée telle quelle** dans le plan QA neuf |

Un testeur qui suit cette consigne croit être dans un bac à sable alors qu'il écrit dans la
collection de messages réelle. **La consigne est inversée par rapport à la réalité.**

### 8.2 🔴 Le groupe `thinking` est perdu par le formulaire de routeur porté

- Le legacy monte **treize** groupes, `thinking` / « Réflexion » compris, **vivant et non
  commenté** (`ai_routers_dialogs.dart:600-604`).
- Le porté n'en déclare que **douze** (`ai_router_zcrud_edition.dart:206-219`).
- Sa dartdoc affirme : « le legacy en monte douze (`thinking` n'a pas de groupe dans son
  formulaire) » (`:202`) — **c'est faux**.

```
$ grep -n "thinking" lib/src/presentation/features/ai_routers/zcrud/ai_router_sub_list_seams.dart
RC=1        # aucun seam pour thinking
```

Le modèle porte bien `thinkingModel` / `thinkingFallbackModels` (`ai_models.dart:233-234`), et
le catalogue de routes les découvre par suffixe (`notebook_route_catalog_iffd.dart:25-30`,
qui compte correctement **treize**). Seul le **formulaire** les rend inéditables.

### 8.3 Divergence de libellé sur `chatStyle`

| | Libellé |
|---|---|
| Legacy `ai_routers_dialogs.dart:597` | « **Chat** » |
| Porté `ai_router_zcrud_edition.dart:331` | « **Style de conversation** » |

La dartdoc du porté annonce pourtant des libellés « tels que le legacy les affiche » (`:319`).
Elle cite aussi `ai_routers_dialogs.dart:524-578` comme source, alors que le bloc réel est
`:540-604`.

### 8.4 Les six corpus legacy sont inertes

Voir §4.1 : **36 déclarations, 0 transmission**, dans les trois implémentations. Confirme le
constat B-58 du registre.

---

## 9. CR ouvertes — correction au contexte de départ

Le brief annonce « sept CR ouvertes (CR-IFFD-114 → 120) ». **Quatre ont été retirées avant
émission** — l'hôte les a écrites, mesurées, puis annulées lui-même :

| CR | Ligne | Statut | Objet | Paquet visé |
|---|---:|---|---|---|
| CR-IFFD-114 | 7589 | **ouverte** | géométrie du tableau markdown figée, sans échappatoire | `zcrud_markdown` |
| CR-IFFD-115 | 7675 | **ouverte** | retour à la ligne souple recollé en espace, non déclarable | `zcrud_markdown` |
| CR-IFFD-116 | 7734 | **ouverte** | pas de sous-titre au dialogue d'édition plein écran | `zcrud_markdown` |
| CR-IFFD-117 | 7787 | **retirée** | encodage en sortie — « le canal existait » | — |
| CR-IFFD-118 | 7825 | **retirée** | `onTapLink` — « seule l'INTERCEPTION manque » | — |
| CR-IFFD-119 | 7859 | **retirée** | `padding` du lecteur — « équivalence exacte » | — |
| CR-IFFD-120 | 7879 | **retirée** | plein cadre — « le paramètre est public » | — |

**Trois CR vivantes, toutes sur `zcrud_markdown`, aucune sur le cœur chat/IA.** Registre :
`docs/zcrud-change-requests.md`, 7 899 lignes / 440 270 octets.

⚠️ **Point de vigilance pour le prochain handoff.** `zcrud_markdown` v3.21.0 déclare
« **Le rendu d'un hôte passif change** — c'est l'objet de cette version »
(`packages/zcrud_markdown/CHANGELOG.md:22`). IFFD est épinglé sur v3.21.0 **et** consomme
`ZMarkdownReader` sur deux chemins (`chatbot_conversation_screen.dart:46-48`,
`ai_explanation_zcrud_reader.dart`). Le risque de localisation signalé par la même version est
**couvert** : `ZcrudLocalizationsDelegate()` est monté (`main.dart:312`).

Entre 3.13 et 3.21, **aucun paquet chat n'a bougé** — `zcrud_chat` s'arrête à 3.11.0
(2026-08-23). Les versions récentes touchent `zcrud_core`, `zcrud_markdown`, `zcrud_reorder`,
`zcrud_responsive`, `zcrud_screen`, `zcrud_select`.

---

## 10. Tests

**40 fichiers, 8 660 lignes** dédiés au domaine IA. L'hôte a adopté la **discipline du
tripwire** recommandée par les handoffs : **17 fichiers** portent un tripwire, dont
`notebook_markdown_tripwire_test.dart` (152 l), qui monte l'arbre et vérifie que le renderer
markdown n'est pas tombé sur le repli neutre — un défaut « qui ne lève AUCUNE erreur » (`:9-12`).

Quatre familles : caractérisation du legacy (`test/characterization/`, `test/chat/`), parité
legacy/porté (`test/qa-w2/`, 9 fichiers, 2 191 l), montages du Notebook (`test/m0/`, 15
fichiers), portages par vague (`test/w7e/`…`test/w9q/`).

---

## 11. Ce que ce relevé recommande de regarder ensuite

1. **Corriger la consigne QA B-60** (§8.1) avant toute séance de test — c'est une consigne
   qui fait écrire en production en croyant l'inverse.
2. **Rétablir le groupe `thinking`** au formulaire porté (§8.2) : la donnée existe, le
   catalogue la route, seul le formulaire la perd.
3. **Le sélecteur de documents** (842 l, 9 `StreamBuilder`, 0 état d'erreur) est la plus
   grosse surface du domaine **sans jumeau porté ni drapeau**.
4. **Les trois implémentations du port IA** (2 548 l) sont le gisement le plus dense : un
   assemblage « intention → route → requête » côté socle en supprimerait la majeure partie,
   et le catalogue de routes (§5) prouve que la forme est déjà connue du socle.
5. **Les 677 lignes de sérialisation manuelle** (§3.2) et les **16 `Timestamp`** dans les
   modèles (§3.3) sont le prix payé pour ne pas annoter : aucun modèle du domaine n'est passé
   au codegen.

---

## 12. Contrôle de remesure (2026-08-26, second passage)

Ce relevé a été écrit par un premier agent puis **recontrôlé par sondage** sur disque
(`/home/zakarius/DEV/iffd`, HEAD `65d1af9`, branche `feat/migration-zcrud` — identique).
Neuf affirmations chiffrées ont été rejouées :

| § | Affirmation contrôlée | Verdict |
|---|---|---|
| 2.1 | tailles `chatbot_conversation_screen` 5 356 / `discovry_page_controller` 2 412 / sélecteur 842 / impls 1 377+672+499 / `ai_models` 581 | ✅ exactes à la ligne |
| 3.4 | 28 signatures de callback par fichier × 4 (port + 3 impls) | ✅ `grep -c "AiResponse result"` = 28, 28, 28, 28 |
| 4.1 | les six corpus, 11 fichiers | ✅ mêmes 11 fichiers (+ `lib/gen/assets.gen.dart`, hors domaine) |
| 4.1 | **36 déclarations, 0 transmission** | ✅ grep négatif rejoué : `0` sur les trois impls ; params à `:680-685` et `:727-732` |
| 4.2 | 13 blocs `buildFallbackModelsField` à `:540-604` | ✅ 13 appels (`:540`→`:601`) + 1 déclaration (`:129`) |
| 2.2 | 52 drapeaux au registre, dont 12 du domaine IA | ✅ 52 `id:` ; les 12 ids annoncés sont tous présents |
| 8.1 | mise en garde B-60 **contredite par le code** | ✅ `z_qa_flags.dart:509` + `qa-plan:324` vs `notebook_transcript_iffd.dart:100` (`repository.create`) |
| 8.2 | groupe `thinking` perdu par le porté | ✅ legacy `ai_routers_dialogs.dart:600-603` (`fieldName: "thinking"`, label « Réflexion », vivant) ; `kAiRouterFallbackGroups` = **12** entrées ; dartdoc `:202` fausse ; grep négatif `thinking` sur `ai_router_sub_list_seams.dart` = RC 1 |
| 9 | 3 CR ouvertes / 4 retirées | ✅ titres lus : `114/115/116` ouvertes, `117/118/119/120` « RETIRÉE AVANT ÉMISSION » ; registre 7 899 lignes |
| 6 | surface chat du socle 22 860 + 15 102 + 2 807 + 1 022 + 301 | ✅ recomptée à la ligne |
| 7.5 | 13 symboles `ZIffd*` dans le socle, aucun `ZLex*`/`ZDodlp*`/`ZDlcfti*` | ✅ 13 symboles, 4 fichiers `lib/` + 2 tests ; grep négatif = 0 fichier |

**Deux précisions apportées au second passage :**

1. **§9 — versions des paquets chat.** Le *pubspec* des cinq paquets chat affiche bien
   `version: 3.21.0` (l'alignement de release est en pas groupé). Ce qui s'arrête plus tôt,
   c'est leur **dernière entrée substantielle de CHANGELOG** : `zcrud_chat` 3.11.0,
   `zcrud_chat_kernel` 3.10.0, `zcrud_chat_material` 3.7.0, `zcrud_chat_markdown` 3.4.0
   (toutes ≤ 2026-08-23), `zcrud_chat_syncfusion` 3.0.0 (2026-08-18). La conclusion tient —
   **aucun changement de comportement chat entre 3.13 et 3.21** — mais la formulation
   « s'arrête à 3.11.0 » ne doit pas se lire comme une version épinglable.

2. **§5 — nombre de paquets zcrud importés.** Sur les six chemins **stricts** du brief :
   **9 paquets** (`zcrud_chat_kernel` 18 imports, `zcrud_chat` 12, `zcrud_core` 10,
   `zcrud_study` 3, `zcrud_markdown` 2, `zcrud_chat_syncfusion` 2, `zcrud_chat_material` 2,
   `zcrud_screen` 1, `zcrud_chat_markdown` 1). Sur le périmètre **étendu** (+ `administration/`,
   `folders/zcrud/`, `domain/models/ai`, `domain/repositories`) : **15 paquets distincts**.
   Le « 14 » du premier passage portait sur un découpage de chemins légèrement différent.

Le `pubspec.yaml` compte **201 lignes mentionnant `zcrud`** et **48 lignes `ref: v3.21.0`** :
l'hôte est intégralement épinglé sur le tag courant du socle.
