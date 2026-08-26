# Confrontation — domaine « Tâches et découverte » d'IFFD × socle zcrud v3.21.0

**Mesuré le 2026-08-26.** Socle : `/home/zakarius/DEV/zcrud` à `v3.21.0` (HEAD `cc276c154`).
Hôte : `/home/zakarius/DEV/iffd`, **lecture seule stricte**, épinglé `ref: v3.21.0`
(`pubspec.yaml:308` et suivants). **Aucun test lancé, dans aucun dépôt.**

Tout `fichier:ligne` du socle est relatif à `/home/zakarius/DEV/zcrud/packages/`.
Tout chemin hôte est relatif à `/home/zakarius/DEV/iffd/`.

---

## 0. Périmètre remesuré, et deux corrections à la carte

| Zone | Fichiers | Lignes |
|---|---:|---:|
| `lib/src/presentation/features/tasks/` | 4 | 1 218 |
| `lib/src/features/tasks/` | 3 | 228 |
| `lib/src/presentation/features/discovery/` | 8 | 3 729 |
| `lib/src/features/discovery/` | 3 | 77 |
| `lib/workflow/` | 38 | 17 417 |
| `lib/src/domain/repositories/workflow/` | 3 | 109 |
| **TOTAL DOMAINE** | **59** | **22 778** |

Mesure : `find <6 dossiers> -name '*.dart' | wc -l` et `-exec cat {} + | wc -l`.

🔴 **Deux corrections à `carte-taches-decouverte.md`**, remesurées :
1. La carte annonce **58 fichiers / 22 874 lignes** en comptant « 2 fichiers / 205 lignes »
   pour `lib/src/domain/repositories/workflow/`. La mesure rend **3 fichiers / 109 lignes**.
   Total réel : **59 / 22 778**.
2. La carte décrit `weekdays_widget.dart` comme une « barre de 7 jours ». **C'est faux** :
   le fichier (93 l.) rend un **libellé de date + un bouton « Aujourd'hui » + deux chevrons
   ±1 jour** (`weekdays_widget.dart:34-92`). Aucune cellule de jour. Cette correction change
   le verdict sur `ZDailyTasksView` (§ 3, ligne « bandeau »).

**Couplage zcrud du domaine : 5 sites d'import sur 209 dans `lib/` (2,4 %)**, répartis sur
3 fichiers — `discovry_page_controller.dart:7,9` (`ZChatRouteSession`, `ZAllowAllChatRouteGate`),
`workflow/screens/zcrud/task_list_zcrud_edition.dart:*` (`presentFormEdition`, `zcrud_core`),
`workflow/screens/zcrud/workflow_notes_zcrud_edition.dart:101` (`zcrud_markdown`).
Mesure : `grep -rn "package:zcrud" <6 dossiers>`.

Bruit récurrent du domaine (`grep -rhoF` sur les 6 dossiers) :

| Motif | Domaine | | Motif | Domaine |
|---|---:|---|---|---:|
| `Colors.` | **256** | | `DateFormat(` | 27 |
| `setState(` | **158** | | `showDialog` | 25 |
| `ListTile(` | 69 | | `TextEditingController(` | 23 |
| `notifyListeners()` | 58 | | `showDatePicker(` 13 + `showTimePicker(` 10 | 23 |
| `Navigator.pop(` | 58 | | `PopScope(` | 13 |
| `EdgeInsets.only(left:` | 42 | | `StreamBuilder<` | 12 |
| `Theme.of(context)` | 37 | | `AppBar(` 10 · `Scaffold(` 9 | 19 |
| `Alignment.centerRight` 10 · `centerLeft` 4 · `TextAlign.left` 8 | 22 | | `AlertDialog(` 8 · `PopupMenuButton` 7 · `showModalBottomSheet(` 3 | 18 |
| | | | `zcrudFlagValue(` | **3** |

---

## 1. DÉJÀ MIGRÉ — 3 sites, tous sous drapeau, tous en défaut LEGACY

| Canal du socle | Site chez l'hôte | Preuve | Drapeau |
|---|---|---|---|
| `presentFormEdition` (`zcrud_screen/lib/src/presentation/present_form_edition.dart:234`) | `lib/workflow/screens/zcrud/task_list_zcrud_edition.dart` (117 l.) — formulaire de **liste de tâches** | `tasks_screen.dart:455-466` : `zcrudFlagValue(taskListEditionUseZcrudProvider, …) ? await _presenterListeDeTachesParLeSocle(…) : await showPushedDialog(… DynamicEditionScreen …)` | `taskList` (`z_qa_flags.dart:852`), **défaut legacy** |
| `showZRichTextFullscreenDialog` + `ZHtmlCodec` + `ZRichTextToolbarConfig` (`zcrud_markdown/lib/src/presentation/z_rich_text_fullscreen_dialog.dart:44`) | `lib/workflow/screens/zcrud/workflow_notes_zcrud_edition.dart:205` (214 l.), **un** aiguilleur pour **deux** sites : description d'événement (`event_editon_screen.dart:968-1038`) et notes de tâche (`task_edition_screen.dart:412-474`) | `workflow_notes_zcrud_edition.dart:1-18` + `:101` | `workflowNotes` (`z_qa_flags.dart:883`), **défaut legacy**, classé `changesData: true` |
| `ZChatRouteSession` + `ZAllowAllChatRouteGate` + `iffdRouteCatalog` (forme `ZChatRouteCatalogShape.suffixPairs`) | `discovry_page_controller.dart:636` (champ), `:645-656` (`attachRouteCatalog`), `:769` (`selectRouter`) | lecture du fichier | aucun drapeau |

🔴 **Le troisième est une adoption INERTE, et c'est le constat le plus utile de ce rapport.**
La session de route est **créée** dans le contrôleur de Découverte, mais son unique résolveur
n'est **jamais appelé** :

```
$ grep -n "routeSession?.resolve\|routeSession!.resolve\|session.resolve\|zChatApplyRoute\|ZChatRoutedStreamPort\|ZChatStreamPort\|ZIffdTextStreamPort" \
    lib/src/presentation/features/discovery/controllers/discovry_page_controller.dart ; echo "RC=$?"
RC=1
```

La session ne sert donc qu'à peupler le **sélecteur de routeur** de la barre de composition
(`discovry_search_composer.dart:197-247`). Tous les envois passent encore par
`aiRepository.<méthode>()`, qui code l'endpoint en dur :
`endpoint: aiRouter?.<champ> ?? "<route>"` — **19 sites** dans
`lib/src/data/repositories/iffd_ai_repository_impl.dart` (`grep -c 'endpoint: aiRouter'` → 19).
Le canal `ZChatRouteSession.resolve` existe (`zcrud_chat/lib/src/presentation/routing/z_chat_route_session.dart:294`) ;
il n'est pas branché.

**Aucune bascule de QA ne couvre la Découverte comme écran** — les 53 `ZQaFlag(`
(`grep -c 'ZQaFlag(' z_qa_flags.dart` → 53) n'en portent que **3** pour ce domaine :
`taskList` (`:852`), `workflowNotes` (`:883`), et `aiExplanationRichReader` (`:822`), qui porte
le **rendu du texte** d'une explication, partagé avec « Explain AI ».
**Grep négatif montré :**
```
$ find lib/src/presentation/features/tasks lib/src/presentation/features/discovery -name '*zcrud*' ; echo "RC=$?"
RC=1
```

---

## 2. 🔴 MIGRABLE AUJOURD'HUI — 8 canaux, preuves et chiffres

> Chaque ligne nomme l'API exacte, son `fichier:ligne` dans `packages/`, ce que son **corps**
> fait réellement (lu, pas seulement sa dartdoc), et les lignes d'hôte que l'adoption supprime.

### M1 — La feuille d'outils déclarative remplace 136 lignes de bascules à la main

**API :** `ZChatToolCatalog` (`zcrud_chat_kernel/lib/src/domain/tools/z_chat_tool_catalog.dart:177`),
`ZChatToolCatalog.resolve()` (`:217`), `activeCount` (`:165` sur `ZChatToolResolution`, `:279` sur le catalogue),
`ZChatToolEntry` (`z_chat_tool_entry.dart:215`) avec **`revealedBy`** (`:268`) et
**`deactivates`** (`:276`), `ZChatCycleState` (`z_chat_tool_state.dart:212`),
`ZChatCatalogState` (`:432`), `ZChatToolController` (`zcrud_chat/lib/src/presentation/tools/z_chat_tool_controller.dart:107`),
`zChatToolSettingsEntries` (`.../tools/z_chat_tool_settings_adapter.dart:66`),
`ZChatMaterialToolsSheet` (`zcrud_chat_material/lib/src/presentation/z_chat_material_tools_sheet.dart:40`).

**Corps vérifié — les quatre correspondances sont exactes, pas approchées :**

| Ce que fait l'hôte | Ligne hôte | Ce que le socle fait, **corps lu** |
|---|---|---|
| `toggleThinking()` : cycle 0→5 puis retour à 0 ; `enableThinking = thinkingEffort > 0` | `discovry_page_controller.dart:939-949` | `ZChatCycleState.next()` (`z_chat_tool_state.dart:228`) : `step + 1 >= stepCount ? 0 : step + 1` (`:229`) ; `isActive => step > 0` (`:239`). **Identique**, `stepCount: 6`. |
| 6 bascules de corpus + « aucune sélection = tous les corpus » | `:896-925` | `ZChatCatalogState` (`z_chat_tool_state.dart:432`) : `isActive => selectedKeys.isNotEmpty` (`:477`), `stateToken` = `kZChatToolTokenAll` si vide (`:480-481`). **Identique.** |
| `toggleWebSearch()` met `enableSummary = false` ; `toggleSummary()` met `enableWebSearch = false` | `:858-867`, `:956-966` | `ZChatToolEntry.deactivates` — « Clés que l'**activation** de cette entrée rend inactives (exclusion mutuelle). L'effet est appliqué par le catalogue, **à un seul endroit** » (`z_chat_tool_entry.dart:273-276`), appliqué dans `setState`, **site unique** (`z_chat_tool_catalog.dart:322`). |
| `scrapeWebResults` remis à `false` quand `enableWebSearch` retombe | `:862-864` | `ZChatToolEntry.revealedBy` — « l'entrée n'est révélée que si cette entrée-là est présente et active » (`z_chat_tool_entry.dart:263-268`), appliqué par `resolve()` étape 1 (`z_chat_tool_catalog.dart:228-231`, `_revealReason` `:418`). |
| `int get toolsCount => [10 booléens].where((e) => e).length` | `:926-937` | `ZChatToolResolution.activeCount` (`z_chat_tool_catalog.dart:165`), calculé **une fois** pour les deux surfaces, étape 3 de `resolve()` (`:243-250`), avec `countsTowardActive` par entrée. |

**Lignes d'hôte supprimées : 136.**
`discovry_page_controller.dart:590-607` (18 lignes de champs de réglage : `enableCDNTogo`…
`summuarzationCustomInstruction`) + `:858-975` (118 lignes de mutateurs).

⚠️ **Le catalogue de corpus est DÉJÀ écrit chez l'hôte** — `kIffdCorpusCatalog`
(`lib/ai_assistant/zcrud/notebook_settings_iffd.dart:55-62`, six `ZChatCorpusOption`) — et la
Découverte l'ignore. **Grep négatif montré :**
```
$ grep -rn "kIffdCorpusCatalog\|buildIffdNotebookSettingsSheet\|ZChatCorpusOption\|ZChatSettings\|ZChatToolEntry\|notebook_settings_iffd" \
    lib/src/presentation/features/discovery lib/src/presentation/features/tasks lib/src/features lib/workflow ; echo "RC=$?"
RC=1
```
Effet de bord chiffré : les six noms de drapeau legacy apparaissent **168 fois** dans
`lib/` (28 occurrences de `enableCDNTogo` × 6 corpus, 8 fichiers) ; un `Set<String>` de clés de
corpus les supprime toutes.

### M2 — Le composer assemblé remplace 293 lignes de la barre de composition

**API :** `ZChatComposer` (`zcrud_chat/lib/src/presentation/view/z_chat_composer.dart:139`),
`ZDefaultChatComposer` (`.../z_default_chat_composer.dart:63`),
`ZChatComposerModelSelector` (`.../z_chat_composer_model_selector.dart:119`),
`ZChatComposerThinkingToggle` (`.../z_chat_composer_band.dart:598`),
`ZChatComposerWebSearchToggle` (`:705`), `ZChatComposerToolsTrigger` (`:793`),
`ZChatComposerCountBadge` (`:892`), `ZChatComposerStopTarget` (`:1193`),
`ZChatComposerSendTarget` (`.../z_chat_composer_chrome.dart:290`),
`zChatMaterialSendFab` (`zcrud_chat_material/.../z_chat_material_send_fab.dart:32`),
`ZChatMaterialSettingsSheet` (`.../z_chat_material_settings_sheet.dart:78`, 9 familles `:89-97`).

**Correspondance mesurée**, `discovry_search_composer.dart` (483 l.) :

| Bloc hôte | Lignes | Canal socle |
|---|---:|---|
| Sélecteur de routeur (`PopupMenuButton<IffdAiRouterModel>` `:197`) | `:191-247` (57) | `ZChatComposerModelSelector` + `ZChatModelOption` (contrat opaque, menu par défaut) |
| Bascule « Raisonnement » (`AnimatedContainer` + `Icons.psychology` + badge de cran) | `:248-325` (78) | `ZChatComposerThinkingToggle` **ou** l'entrée `ZChatCycleState` du catalogue M1, rendue par `ZChatMaterialToolTile` (« cycle à badge de cran », `z_chat_material_tool_tile.dart:52`) |
| Bouton « Outils » + pastille de compte | `:326-424` (99) | `ZChatComposerToolsTrigger` + `ZChatComposerCountBadge`, badge alimenté par `activeCount` |
| Bouton d'envoi | `:425-483` (59) | `ZChatComposerSendTarget` / `zChatMaterialSendFab` — l'envoi passe par `ZChatComposerSlot.submit`, **site unique** |

**Lignes d'hôte supprimées : 293** (`discovry_search_composer.dart:191-483`).

⚠️ **Piège à connaître avant d'adopter :** `ZChatComposerSubmitPolicy`
(`.../z_chat_composer_keys.dart:63`) a `enterSubmits` **et** `desktopAndWebOnly = true` par
défaut (`:76`) : sur bureau/Web, **Entrée envoie**. Zéro site chez IFFD — l'hôte prendrait ce
défaut sans l'avoir choisi. Et `ZChatMaterial*Labels` : **libellé absent ⇒ affordance absente**,
jamais un libellé par défaut.

### M3 — Le lexer de fil corrige B-59 dans la Découverte et supprime ~200 lignes

**API :** `ZIffdTextStreamPort` (`zcrud_chat_syncfusion/lib/src/data/z_iffd_stream_port.dart:40`),
`ZIffdLexer` (`.../z_iffd_lexer.dart:98`), `ZIffdStreamNormalizer` (`.../z_iffd_stream_normalizer.dart:53`),
`zIffdChannelOfTag` (`.../z_iffd_wire.dart:53`), `ZIffdFailureCodes` (`:100`).

**Corps vérifié :** la forme reconnue est une **expression régulière de FORME**, pas une table :
`final RegExp _tagPattern = RegExp(r'<(/?)([A-Z][A-Z0-9_]*)(?: +([0-9]+))?>');`
(`z_iffd_lexer.dart:87`). Le classement est **total** : « toute autre balise, connue ou non ⇒
`ZIffdChannel.thinking` » (`z_iffd_wire.dart:60-63`), et une erreur écrite **en clair** dans le
canal de réponse (`kZIffdPlainErrorPrefix = '⚠️ Erreur'`, `:35`) devient un
`Left(ZChatProviderFailure)`, jamais un message.

**Le défaut vit dans mon domaine, mesuré :** la Découverte porte une **table fermée de quatre
noms**, recopiée à deux endroits :
`discovry_ai_page.dart:112` et `:128` —
`r'</?(?:RAG_THINKING|RAG_ITERATION_\d+|AI_MODEL_REASONING_\d+|RAG_REQUESTS_\d+)[^>]*>'` ;
`discovry_page_controller.dart:1137` (`endsWith("</RAG_THINKING>")`) ;
`iffd_ai_repository_impl.dart:140,142,156,267,268,281` (`###LINE###`, `<RAG_THINKING>`).
Une cinquième balise s'**affiche dans la réponse**.

⚠️ **Le port est DÉJÀ adopté par l'hôte, ailleurs** : `ZIffdTextStreamPort` est cité par
`lib/ai_assistant/zcrud/notebook_stream_opener_iffd.dart` (140 l., ouvreur générique et
route-agnostique), `notebook_ports_iffd.dart` et
`lib/src/presentation/features/folders/zcrud/assistant_chat_zcrud_mount.dart`. La Découverte ne
le nomme pas.

**Lignes d'hôte supprimées : ≈ 200** — `discovry_ai_page.dart:100-135` (36, les 6 `RegExp`) +
`iffd_ai_repository_impl.dart:130-300` (≈ 170, le traitement de sentinelles, **partagé** avec le
reste de l'application).

### M4 — Le transport PAR ROUTE : 29 emballages réduits à leur prompt

**API :** `zChatTaskKeyOf` (`zcrud_chat/lib/src/presentation/routing/z_chat_route_session.dart:53`
— *« la clé de tâche est `request.style.kind` »*, corps lu : `String zChatTaskKeyOf(req) => req.style.kind;`),
`ZChatRouteSession.resolve` (`:294`), `zChatApplyRoute` (`:65`),
`ZChatRouteResolution.from` (`zcrud_chat_kernel/lib/src/domain/route/z_chat_route_resolution.dart:43`),
`.routeName` (`:80`), `ZChatRoutedStreamPort` (`zcrud_chat/lib/src/presentation/routing/z_chat_routed_stream_port.dart:31`),
`ZChatGenerationRequest` (`zcrud_chat_kernel/lib/src/domain/ai/z_chat_generation_port.dart:61`),
`ZChatGenerationStyle` (`.../z_chat_generation_style.dart:50`),
`ZChatStreamEvent` + 8 cas (`.../z_chat_stream_event.dart:49…`).

**Corps vérifié :** `ZChatRouteResolution.from(router, taskKey)` (`:43-63`) résout
`route.routeName` / `route.model` avec repli sur la racine, et `toRequest(base, settings:)`
**n'emporte jamais** sur un modèle déjà nommé par l'appelant (`:118-124`).
`routeName` **est** l'endpoint — le champ que les 29 emballages codent en dur.

**Le défaut mesuré, hôte :** trois emballages consécutifs sont identiques **mot pour mot** hors le
nom de la méthode et un enum —
`discovry_page_controller.dart:2231-2379` (`summarizeExplanation`, `elaborateExplanation`,
`explainSubjectWithStyle`), lus intégralement. Le motif `onComplete: (result, completed,
{hasError = false}) { _onAiCompletion(…, onError: …, onAnswer: …) }` compte **7 sites**
(`:1264`, `:1320`, `:2061`, `:2131`, `:2253`, `:2303`, `:2356`), ≈ 28 lignes chacun.
Côté couche IA : `iffd_ai_repository_impl.dart` (1 377 l.) porte **29** `return callApi(`
(`grep -c` → 29) et **19** littéraux de route ; `ai_repository.dart` (494 l.) recopie **27** fois
la signature `void Function(AiResponse, bool, {bool hasError})? onComplete`.

⚠️ **Le pont de décodage est DÉJÀ écrit chez l'hôte** : `iffdRouteCatalog`
(`lib/ai_assistant/zcrud/notebook_route_catalog_iffd.dart`, 106 l.) décode `IffdAiRouterModel`
par `ZChatRouteCatalogShape.suffixPairs`, **treize paires découvertes par suffixe**, et
`attachRouteCatalog` le pose déjà dans la Découverte.

**Lignes d'hôte supprimées : ≈ 600** — 196 dans le domaine (7 blocs `_onAiCompletion`),
≈ 350 dans `iffd_ai_repository_impl.dart` (l'échafaudage des 29 emballages ; **les prompts
restent à l'hôte**, § 4), ≈ 110 dans `ai_repository.dart` (54 signatures `onComplete` recopiées
+ paramètres répétés `aiRouter` ×22, `userData` ×18, `cycle` ×13).

🔴 **Piège bloquant s'il est ignoré :** `ZChatRouteSession({gate = ZDenyAllChatRouteGate()})`
(`z_chat_route_session.dart:202`) — sans gate explicite, **tout est refusé**, silencieusement
(`lastFailure`, pas d'exception). L'hôte pose déjà `ZAllowAllChatRouteGate`
(`discovry_page_controller.dart:649`), avec sa justification mesurée en commentaire.

### M5 — `ZEmptyState` remplace `EmptyTasksWidget` (77 lignes)

**API :** `ZEmptyState` (`zcrud_ui_kit/lib/src/presentation/z_state_widgets.dart:31`),
`ZLoadingState` (`:75`), `ZErrorState` (`:127`), `ZContentStateView` (`:180`),
`ZContentState` (`zcrud_ui_kit/lib/src/domain/z_content_state.dart:13`).

**Corps vérifié :** `ZEmptyState({required message, icon, title, actionLabel, onAction})` —
icône **optionnelle**, message **toujours présent** (« l'icône n'est jamais le seul canal »,
`:26-27`), couleurs dérivées de `Theme.of(context).colorScheme.onSurfaceVariant` (`:61`),
`Semantics` composé `'$title. $message'` (`:63`), cible ≥ 48 dp (`_kA11yButtonStyle`, `:20`, posé `:301`).

**Hôte :** `EmptyTasksWidget` (`daily_tasks_page.dart:560-636`, **77 lignes**) porte exactement
`title` / `subtitle` / CTA `onCreateExam` (`:563-566`).

**Lignes d'hôte supprimées : 77.**
⚠️ **Le rendu change** : l'hôte peint un `Container` à `borderRadius: 24` et
`surface.withValues(alpha: 0.5)` (`:571-576`) ; `ZEmptyState` rend un état neutre. C'est un
changement visuel assumé, pas une parité au pixel.

**Contexte chiffré :** `CircularProgressIndicator` n'apparaît que **2 fois** dans les 59 fichiers,
et `daily_tasks_page.dart` n'a **aucun** état d'erreur ni de chargement sur ses 5 `StreamBuilder`.
**Grep négatif montré :**
```
$ grep -cF hasError lib/src/presentation/features/tasks/pages/daily_tasks_page.dart          # 0
$ grep -cF ConnectionState lib/src/presentation/features/tasks/pages/daily_tasks_page.dart   # 0
$ grep -cF CircularProgressIndicator lib/src/presentation/features/tasks/pages/daily_tasks_page.dart  # 0
```
`ZContentStateView` (aiguilleur `switch` exhaustif `idle/loading/empty/error/success`) est le
canal qui rend ce trou **structurellement impossible**.

### M6 — `ZContentHubSheet` + `ZFeatureAvailability.gate` : 202 lignes, et 3 affordances mortes qui disparaissent

**API :** `ZContentHubSheet` (`zcrud_study/lib/src/presentation/z_content_hub_sheet.dart:188`,
constructeur `:194`, 18 paramètres), `ZContentHubEntry` (même paquet), `gridBreakpoint` / `gridCrossAxisCount`
(`:203-204`), `ZContentHubDensity` (`:229`), `ZFeatureAvailability` (`.../z_feature_availability.dart:41`),
`.gate(featureKey, action)` (`:63`), `ZMapFeatureAvailability` (`:94`),
`ZFeatureAvailabilityScope` (`:149`).

**Corps vérifié :** `ZContentHubSheet` est un **`StatelessWidget` nu** — sa dartdoc dit
« Testable en isolation (widget nu) **ou** présentée en modale via `show` » (`:168`) : il
s'embarque en ligne dans une page. Son exemple de dartdoc utilise littéralement
`onTap: fa.gate('flashcards.ai', _generate)` (`:181`). `ZFeatureAvailability.gate` « Retourne
`action` SSI la feature est disponible, sinon `null`. Le `null` rend la surface NON
actionnable / **ABSENTE** par le mécanisme EXISTANT » (`:59-62`).

**Le défaut hôte, mesuré :** `_QuickActionsWidget` (`daily_tasks_page.dart:900-983`) déclare
**4 raccourcis dont 3 sont INERTES** — `enabled: false, onTap: () {}` aux lignes `:916-918`,
`:925-927`, `:933-935`. Une affordance grisée qui ne fait rien est exactement ce qu'AD-4
interdit ; `gate` la fait **disparaître**.

**Lignes d'hôte supprimées : 202** — `_QuickActionsWidget` (`:900-983`, 84) +
`_QuickActionCard` (`:985-1101`, 117), remplacés par ≈ 25 lignes de déclaration
`ZContentHubEntry`.
⚠️ L'hôte a déjà un adaptateur de hub — `lib/src/presentation/features/folders/zcrud/content_hub_zcrud.dart`
(458 l.) — mais il est **spécifique aux dossiers** : la Découverte/les tâches déclareraient
leurs propres entrées, pas ne réutiliseraient ce fichier.

### M7 — `ZActionMenu` / `ZContextMenuRegion` : la règle d'absence appliquée en amont

**API :** `ZActionMenu` (`zcrud_menu/lib/src/presentation/z_action_menu.dart:18`),
`ZContextMenuRegion` (`.../z_context_menu_region.dart:30`),
`ZMenuEntry` (`zcrud_menu/lib/src/domain/z_menu_entry.dart:36`),
`zVisibleMenuEntries` (`:194`), `ZMenuTrigger` (`.../z_menu_trigger.dart:20`),
`ZGridMenuRenderer` (`.../z_grid_menu_renderer.dart:59`),
`ZMenuScope` (`.../z_menu_scope.dart:34`).

**Corps vérifié :** `ZActionMenu.build` applique `zVisibleMenuEntries(entries)` **avant** le
renderer — « la liste transmise au renderer est déjà filtrée ; la règle lui est INOPPOSABLE, il
ne peut ni la contourner ni la ré-implémenter de travers » (`z_action_menu.dart:54-56`).
`ZMenuEntry.semanticLabel` du déclencheur est **requis** (`z_menu_trigger.dart:57`), cible
≥ `kZMenuMinTapTarget = 48.0` (`z_menu_entry_tile.dart:27`).

**Hôte :** 7 `PopupMenuButton` + 3 `showModalBottomSheet(` + 8 `AlertDialog(` dans le domaine
(mesures § 0), dont les deux menus latéraux de `tasks_screen.dart:529` et `:578`.
**Grep négatif montré :** `grep -rlnw ZActionMenu lib` → **0 fichier** ; idem
`ZContextMenuRegion`, `ZMenuEntry`.

**Lignes d'hôte supprimées : ≈ 60** (estimation prudente sur les 7 `PopupMenuButton` : la
construction d'items reste, l'échafaudage disparaît).

### M8 — `showZConfirmDialog` : 175 lignes de dialogue maison, hors périmètre mais déclenché par lui

**API :** `showZConfirmDialog` (`zcrud_ui_kit/lib/src/presentation/z_confirm_dialog.dart:129`),
`ZConfirmDialog` (`:36`), `ZConfirmTone` (`zcrud_ui_kit/lib/src/domain/z_confirm_tone.dart:12`).

**Corps vérifié :** rend `Future<bool>` avec `?? false` (`:172`, jamais de throw), libellés par
`MaterialLocalizations` (`:69-72`), couleur du bouton dérivée du `ColorScheme` selon la tonalité
(`:73-76`), cibles 48 dp (`:87`, `:95`), `Semantics(scopesRoute:, namesRoute:)` quand il n'y a
pas de titre (`:110-116`).

**Hôte :** `buildConfirmDialog` (`lib/src/utils/functions/forms_utils.dart:480-654`,
**175 lignes**) — **38 sites, 20 fichiers**, dont **4 dans mon domaine**
(`tasks_screen.dart` ×2, `task_edition_screen.dart` ×2). Le helper code en dur
`Color(0xFF1A1F2E)`, `Color(0xFF8B3A62)`, `Color(0xFF5C2A53)`, `Color(0xFFF093FB)`,
`Color(0xFFF5576C)` (`:491-509`) — violation FR-26 franche.

**Lignes supprimées : 0 dans le domaine** (les 4 sites changent de nom, pas de longueur) ;
**175 à l'échelle de l'application**, une fois les 38 sites bascculés. ⚠️ **Le rendu change** :
le dégradé et l'icône maison disparaissent au profit d'un `AlertDialog` neutre.

### M9 — `ZDiscardChangesGuard` : 12 `PopScope` inertes, et une capacité qui manque

**API :** `ZDiscardChangesGuard` (`zcrud_ui_kit/lib/src/presentation/z_discard_changes_guard.dart:50`).

**Corps vérifié :** `PopScope(canPop: !dirty, …)` sous un `ValueListenableBuilder` dont le
`child` est passé **par paramètre**, donc **non reconstruit** au flip *dirty* (`:99-108`, `canPop: !dirty` `:104`, commentaire `:101`). Confirmation par `showZConfirmDialog` en ton destructif.

**Le défaut hôte, mesuré :** les **12** `PopScope(` du domaine portent **tous** `canPop: true` —
ce sont des enveloppes **inertes** :
```
$ grep -rhn -A1 "PopScope(" lib/workflow/screens/appointment_editor.dart lib/workflow/screens/event_editon_screen.dart | grep canPop | sort | uniq -c
```
rend 12 lignes, toutes `canPop: true` (`appointment_editor.dart:488,523,591,635,1527,4886,5000,5695,5895,5948` ;
`event_editon_screen.dart:1114,1151`). **Il n'y a donc AUCUNE garde anti-perte de saisie** dans
les trois éditeurs de rendez-vous ni dans l'éditeur d'événement.

**Lignes d'hôte supprimées : 36** (12 enveloppes × 3 lignes) — et l'adoption **ajoute** une
capacité absente, ce qui est le vrai gain.

---

## 3. MANQUE AU SOCLE — 6 canaux, chacun avec son grep négatif

### N1 — 🔴 La règle de récurrence (RRULE) : le plus gros manque du domaine

**Preuve d'absence, montrée :**
```
$ cd /home/zakarius/DEV/zcrud
$ grep -rlni "rrule\|recurrenceRule\|RecurrenceProperties" packages/*/lib/ ; echo "RC=$?"
RC=1
$ grep -rln "ZRecurrence" packages/*/lib/ ; echo "RC=$?"
RC=1
$ grep -rlni "recurrence" packages/*/lib/
packages/zcrud_exam/lib/src/domain/z_reminder_recurrence.dart
packages/zcrud_exam/lib/zcrud_exam.dart
packages/zcrud_exam/lib/src/domain/z_exam.dart
```
Les trois seuls fichiers portent `ZReminderRecurrence` (`z_reminder_recurrence.dart:42`), qui est
`{daysBefore: List<int>, weekdays: Set<int>}` — **un rappel**, pas une règle de récurrence
d'occurrences.

**Forme du canal manquant :** une **entité** `ZRecurrenceRule` pur-Dart (fréquence, intervalle,
`byDay`/`byMonthDay`/`bySetPos`, fin par date ou par compte, dates d'exception) + un
**assemblage** d'édition `ZRecurrenceEditor` déclaratif, + un `expand(from, to)` **pur et total**.
**Paquet :** `zcrud_core` pour l'entité (pur-Dart, `domain/`), un satellite `zcrud_calendar` pour
l'éditeur.

**Pourquoi l'hôte ne peut pas s'en passer :** il l'écrit **deux fois** —
`lib/workflow/components/recurrence_picker.dart` (**1 721 l.**) et
`SelectRuleDialogState` + `_CustomRule` dans `appointment_editor.dart:6210-6425` + `:6874-7858`
(**≈ 1 200 l.**). **≈ 2 900 lignes pour « répéter »**, dans un seul domaine. Et le champ
`Task.recurrenceRule` est persisté (`workflow/models/task.dart:280`).

**Bloque une capacité d'étude ou de révision ?** **Non.** Le SRS n'en dépend pas ; c'est un
manque d'**agenda**.

### N2 — 🔴 L'agenda : calendrier, fuseau horaire, participants, série d'occurrences

**Preuve d'absence, montrée :**
```
$ grep -rlni "SfCalendar\|CalendarView\|timeZone\|timezone" packages/*/lib/ ; echo "RC=$?"
RC=1
$ grep -rlniw "attendee\|attendees\|participant" packages/*/lib/ ; echo "RC=$?"
RC=1
```

**Forme du canal manquant :** un **satellite** `zcrud_calendar` — entité `ZCalendarEvent`
(tout-le-jour, début/fin, fuseau **de début et de fin**, participants, couleur, récurrence,
`recurrenceExceptionDates`), un `ZCalendarRenderer` sur le patron de `ZListRenderer` (AD-8, la
frontière Syncfusion reste dans le satellite), et le **dialogue de portée** « cette occurrence /
toute la série », qui est une décision d'assemblage, pas un widget.

**Pourquoi l'hôte ne peut pas s'en passer :** `agenda_screen.dart` (737 l.),
`event_editon_screen.dart` (1 308 l.) et surtout `appointment_editor.dart` (**7 858 l.,
21 classes**), qui écrit **trois fois le même formulaire** — `PopUpAppointmentEditorState`
(658 l.), `AppointmentEditorWebState` (3 508 l.), `AppointmentEditorState` (928 l.) — plus
`_DeleteDialog` / `_EditDialog` (430 l.). Aucune l10n : ~40 `Text('…')` en anglais en dur.

**Bloque l'étude ou la révision ?** **Non.**

### N3 — 🔴 L'entité « tâche » et sa sous-tâche

**Preuve d'absence, montrée :**
```
$ grep -rlniw "ZTask\|ZTodo\|ZTaskList\|subTasks" packages/*/lib/ ; echo "RC=$?"
RC=1
$ grep -rln "reminderDate\|ZReminderAt\|remindAt" packages/*/lib/ ; echo "RC=$?"
RC=1
```

**Forme du canal manquant :** l'entité `ZTask` (titre, notes riches, échéance, **rappel à date
absolue**, priorité, `parent`, `position`, `completed`) + `ZTaskList` (verrouillage, membres),
sous `@ZcrudModel` pour que le formulaire, la liste **et** les cellules se dérivent du registre.
**Paquet :** un satellite `zcrud_task` (le cœur ne porte pas d'entité métier), ou `zcrud_core`
si l'on juge la tâche aussi transverse que `ZExam`.

**Pourquoi l'hôte ne peut pas s'en passer :** `tasks_screen.dart` (816 l.) +
`task_edition_screen.dart` (589 l.) + `models/task.dart` (584 l., `Task.toMap` = **27 clés à la
main**, `:254-285`) + les trois composants (`task_due_date_picker.dart` 192,
`task_reminder_picker.dart` 170, `is_read_only.dart` 92).

⚠️ **Nuance mesurée sur le rappel** : `ZReminderRecurrence` (`zcrud_exam/.../z_reminder_recurrence.dart:42`)
est un modèle **relatif** (« N jours avant ») + **hebdomadaire**. `TaskReminderPicker`
(`task_reminder_picker.dart:45-90`) produit une **date-heure absolue** par préréglages
(`duringDay` / `tomorrow` / `nextWeek` / date libre). Les deux ne sont pas inter-convertibles —
c'est exactement l'argument que la dartdoc de `ZReminderRecurrence` avance elle-même (`:8-14`),
appliqué au troisième modèle qu'elle ne porte pas.

**Bloque l'étude ou la révision ?** **Non** — mais c'est le seul manque du domaine dont
l'absence rend `ZCrudScreen` inatteignable (§ 4, R2).

### N4 — Lecture audio : position, `seek`, arrière-plan, téléchargement

**Ce qui EXISTE au socle** (à ne pas confondre avec ce qui manque) :
`ZStudyPodcast` (`zcrud_study_kernel/lib/src/domain/z_study_podcast.dart:72`,
`@ZcrudModel(kind: 'study_podcast')`), `ZPodcastGenerationPort`
(`zcrud_study/lib/src/domain/z_podcast_generation_port.dart:130`), `podcastFreshness`
(`zcrud_study_kernel/.../z_podcast_freshness.dart:46`, invalidation *content-addressed* pure),
`ZPodcastStatus` / `ZPodcastMode`, et `ZChatSpeechPort` / `ZChatSpeechChain`
(`zcrud_chat_kernel/.../z_chat_speech_port.dart:144`, `:174`), `ZChatDiffusionService`
(`zcrud_chat/.../diffusion/z_chat_diffusion_service.dart:51`).

**Preuve d'absence de la LECTURE, montrée :**
```
$ grep -rn "seek\|Duration position\|pause()\|isPlaying\|downloadUrl\|MediaItem" packages/zcrud_chat*/lib/
packages/zcrud_chat_kernel/lib/src/data/sse/z_chat_sse_stream_port.dart:252:      onPause: () => lines?.pause(),
packages/zcrud_chat_kernel/lib/src/data/sse/z_chat_sse_line.dart:275:    onPause: () => subscription?.pause(),
packages/zcrud_chat_kernel/lib/src/domain/notebook/z_chat_transcript_port.dart:85:    onPause: () => subscription?.pause(),
```
— trois `pause()` de **`StreamSubscription`**, aucun contrôle de lecture audio.
`ZChatDiffusionService` n'expose que `narrateConversation` (`:78`), `narrateMessage` (`:119`),
`stopNarration` (`:134`) et un `ValueNotifier<bool> _speaking` (`:73`).

**Deux manques distincts :**
1. **La lecture** : aucun `ZAudioPlaybackController` (position, durée, `seek`, `pause`/`resume`,
   session média d'arrière-plan, file d'attente). L'hôte l'écrit avec `just_audio` +
   `just_audio_background` : `discovry_page_controller.dart:219` (`AudioPlayer`), `:309-425`
   (`playPodcast`, deux `MediaItem` `:330` et `:389`), `:491-525` (`readPodcast`),
   `:526-557` (`readAudio`) — **≈ 300 lignes**.
2. **L'adressage** : `ZChatSpeechRequest` ne porte que `{text, languageTag, rate}`
   (`z_chat_speech_port.dart:52-56`). IFFD lit un **MP3 déjà synthétisé côté serveur**, adressé
   par `chaMessage.audioUrl` / `audioPath` (`:530-537`). Un maillon `ZChatSpeechPort` ne peut
   donc pas le retrouver : le canal n'a pas de créneau d'adresse.
3. **La source d'un podcast est un enum FERMÉ** : `enum ZPodcastSourceKind { note, folder,
   document }` (`z_podcast_source_kind.dart:15-24`) — pas de `conversation`/`message`. Et
   `ZStudyPodcast.folderId` est **non-nullable** (`z_study_podcast.dart:156`). Le podcast de la
   Découverte est engendré depuis un **message de conversation**, souvent hors dossier
   (`generateChatbotMessagePodcast`, `discovry_page_controller.dart:426`).

**Forme des canaux manquants :** (a) `ZAudioPlaybackPort` + `ZAudioPlaybackController`
(tranches `ValueListenable` de position/durée/état, AD-2) dans un satellite `zcrud_audio` ;
(b) un créneau d'**adresse** sur `ZChatSpeechRequest` (`assetRef: String?`) ou un
`ZChatSpeechSource` ouvert ; (c) `ZPodcastSourceKind` élargi ou rendu **ouvert** (`String kind`,
patron AD-4 déjà employé par `ZContentBlock`), et `folderId` nullable.

**Bloque l'étude ou la révision ?** **Oui, partiellement** : (c) empêche un podcast engendré
depuis une conversation d'entrer dans le domaine d'étude du socle — c'est le pont
`zcrud_chat_study` qui reste borgne sur cet axe.

### N5 — Le sous-titre du dialogue d'édition plein écran (CR-IFFD-116, **ouverte**)

**Preuve d'absence, montrée :**
```
$ grep -rn "subtitle" packages/zcrud_markdown/lib/src/presentation/z_rich_text_fullscreen_dialog.dart ; echo "RC=$?"
RC=1
```
Signature complète : `showZRichTextFullscreenDialog(context, {initialValue, title, codec,
placeholder, styleSet, textScaleFactor, formulaSpec, toolbarConfig})`
(`z_rich_text_fullscreen_dialog.dart:44-54`) — **pas de `subtitle`**.

**Forme du canal manquant :** `subtitle: String?` sur la fonction **et** sur
`ZRichTextFullscreenDialog`, rendu **sous** le titre dans les deux présentations (`AppBar` plein
écran et en-tête du dialogue dimensionné), tronqué à une ligne. `null` ⇒ rendu inchangé au pixel.
**Paquet :** `zcrud_markdown`.

**Pourquoi l'hôte ne peut pas s'en passer :** les **deux seuls sites du dépôt** qui passent un
sous-titre sont **dans mon domaine** — description d'un événement (`title: item.subject`,
`subtitle: "Description"`) et notes d'une tâche (`title: task.title`, `subtitle: "Notes"`). Le
contournement est écrit et commenté : `_titreAffiche` compose `'$titre — $sousTitre'`
(`workflow_notes_zcrud_edition.dart:154-172`), « préserve l'information et perd la hiérarchie ».
La CR de l'hôte est ouverte, `docs/zcrud-change-requests.md:7734`, et recense **quatre
surfaces, trois manques, un seul motif** (`ZFolderCard` ⇒ CR-28 ; `ZSearchableAppBar`/
`ZPageScaffold` ⇒ CR-34 ; ici ⇒ CR-116).

**Bloque l'étude ou la révision ?** **Non** — mais c'est le seul écart QA **attendu** du drapeau
`workflowNotes` (`docs/qa-plan-comparaison-legacy-zcrud.md:562`, point ③).

### N6 — Un composeur de champs hors du binding GetX

**Preuve d'absence, montrée :**
```
$ grep -rn "registerZ.*Fields\|FormFieldsComposer" packages/zcrud_riverpod/lib packages/zcrud_provider/lib ; echo "RC=$?"
RC=1
```
Le seul point de composition du dépôt — `registerZcrudFormFields`
(`zcrud_get/lib/src/presentation/z_form_fields_composer.dart:76`) — vit dans le binding **GetX**,
alors que son corps n'utilise que `ZWidgetRegistry` + markdown/intl/geo.

**Forme du canal manquant :** remonter ce composeur dans un paquet neutre (ou le dupliquer
côté `zcrud_riverpod`), pour qu'un hôte Riverpod n'ait pas à dépendre de `get ^4.7.2`,
`get_it ^9.0.0` et `reflectable ^5.2.3`.
**Pourquoi l'hôte ne peut pas s'en passer :** IFFD est Riverpod et réécrit son registre —
`lib/src/presentation/shared/zcrud/z_iffd_field_registry.dart` (461 l., **2** `.register(`).
**Bloque l'étude ou la révision ?** **Non.**

---

## 4. RESTE À L'HÔTE — règle métier, jamais du socle

| # | Ce qui reste | Preuve / mesure | Pourquoi c'est un invariant |
|---|---|---|---|
| R1 | **Les 29 prompts pédagogiques** (`AiPromptGenerator`) : `explanationSummarizerPrompt`, `explanationElaboratorPrompt`, `subjectExplanationPrompt`… | `iffd_ai_repository_impl.dart:23` (mixin), corps des 29 emballages | Le socle transporte une **requête**, pas une **intention pédagogique**. § M4 ne retire que l'échafaudage. |
| R2 | **Les 6 corpus juridiques** (Code du GATT, TEC CEDEAO, Codes des douanes CEDEAO/Togo/Niger, CGI Togo) | `notebook_settings_iffd.dart:55-62` | C'est le métier de l'institut. `ZChatCorpusOption` les accueille déjà **comme déclaration d'hôte** — clé opaque + libellé traduisible. |
| R3 | **`NiveauIFFD` / `CycleIFFD` / `FiliereEtCycleIFFD` / `AuditeurIffd`**, injectés dans chaque prompt avec accord de genre | `discovry_ai_page.dart:74-75` ; `cycle` recopié 13× dans `ai_repository.dart` | Contexte pédagogique propre à l'institut. |
| R4 | **Les droits par chaîne composée** `canCreateOrUpdate("ExamModel$accademicYear")` | `daily_tasks_page.dart:53-58` | La convention de nommage `<Type><année>` est une décision d'ACL d'IFFD ; `ZAcl.can(action, {target, collectionId})` la porte sans la connaître. |
| R5 | **`Task extends google_api.Task`, `Event extends google_api.Event`** — le schéma Google Calendar/Tasks (`etag`, `EventAttendee`, `TaskLinks`) | `workflow/models/task.dart:124`, `event.dart:5` ; `lib/src/core/services/google/google_api.dart` = 2 lignes d'`export` de `package:googleapis` | C'est une **frontière d'intégration**, pas une dette. ⚠️ Et elle **bloque le codegen** : le générateur parcourt les supertypes non-`dart:` (`zcrud_generator/lib/src/zcrud_model_generator.dart:667-684`) et **refuse le build** sur un champ hérité non annoté de type non sérialisable (`:684`). Une adoption de `@ZcrudModel` sur `Task`/`Event` devrait d'abord rompre l'héritage. `TaskList` (`task.dart:14`, sans héritage) n'a pas ce blocage. |
| R6 | **Le groupement des révisions par dossier puis par date** (`FolderRepetitionFlashcardsWidget`) | `daily_tasks_page.dart:821-898` (78 l.) | ⚠️ **C'est ce qui disqualifie `ZDailyTasksView` en remplacement direct** — voir ci-dessous. |
| R7 | **La cascade année → filière/cycle → matière → dossier → sous-dossier → documents** | `discovry_page_controller.dart:39-155` (`ChatBotDocumentsSelectionController`, 117 l.) | La *cascade* est généralisable ; ses **six niveaux** sont l'arborescence IFFD. |
| R8 | **La discipline de thème et de l10n** : 256 `Colors.` contre 37 `Theme.of(context)` (ratio 1:7) ; 71 sites non directionnels ; `WorkflowLocalizations` déclare 41 libellés et une seule traduction réelle (`fr.dart`, 413 l.), les 8 autres locales faisant 4 lignes et déclarant `class En extends Fr` | mesures § 0 | Le socle n'a pas de canal pour « l'anglais est du français ». C'est une dette d'hôte. `ZcrudLabels` (`zcrud_core/lib/src/presentation/l10n/z_labels.dart:20`) ne couvre que les 123 clés du socle — **grep négatif** : `grep -rn "ZcrudLabels" lib` → RC=1. |

### 🔴 Le cas `ZDailyTasksView` — pourquoi je ne le classe PAS en migrable

`ZDailyTasksView` (`zcrud_study/lib/src/presentation/z_daily_tasks_view.dart:212`, 21 paramètres)
ressemble à `daily_tasks_page.dart`. **Corps lu, il ne peut pas le remplacer** :

1. **Il agrège lui-même**, et son agrégat est fermé. `build` appelle
   `aggregateDailyStudyTasks(dueCount: dueCount, exams: exams, now: now)` (`:368-372`), et cette
   fonction émet **au plus UNE** ligne « cartes dues » (`if (dueCount > 0) ZDueCardsTask(dueCount)`,
   `zcrud_study_kernel/lib/src/domain/aggregate_daily_study_tasks.dart:77`) plus N `ZExamTask`.
   IFFD rend **une carte par couple (dossier, date)** — `Map<DateTime, Map<FolderModel, List<…>>>`
   construit à `daily_tasks_page.dart:465-...`, rendu par `FolderRepetitionFlashcardsWidget`
   (`:821-898`). `unknownTaskBuilder` n'y change rien : la vue ne reçoit pas la liste de tâches,
   elle la fabrique.
2. **Le bandeau n'est pas le même geste.** `_ZDayBand` rend **7 cellules de jour sélectionnables**
   (`:434-470`) ; `WeekdaysWidget` rend **un libellé + « Aujourd'hui » + deux chevrons ±1 jour**
   (`weekdays_widget.dart:34-92`). Adopter la vue changerait l'interaction, pas seulement le style.

**Ce qui, dans cette page, EST migrable** est isolé en M5 (`ZEmptyState`) et M6
(`ZContentHubSheet`). Le reste demanderait au socle un `dueCount` **groupé** — ce n'est pas
demandé ici, l'agrégat par dossier étant une décision de produit IFFD.

### Autres non-candidats, dits explicitement

| Canal | Pourquoi je ne le promets pas |
|---|---|
| `ZCrudScreen` (`zcrud_screen/lib/src/presentation/z_crud_screen.dart:180`, 54 paramètres) | Il exige `source: ZCrudSource` et un `ZcrudRegistry` sur un `T extends ZEntity`. `Task`/`TaskList` n'implémentent pas `ZEntity` (`task.dart:14`, `:124` — `implements DynamicModel`), et le codegen est bloqué par R5. **`ZCrudScreen` devient atteignable APRÈS N3**, pas avant. `grep -rlnw ZCrudScreen lib` → 0. |
| `ZReorderableAdaptiveGrid` / `ZDefaultReorderRenderer` | `tasks_screen.dart:307-323` utilise `ReorderableListView` du SDK avec une `position` persistée. Le canal socle est une **grille** (`z_default_reorder_renderer.dart:53-80` délègue à `ZReorderableAdaptiveGrid`) : la forcer à une colonne pour remplacer une liste native est un décalage de forme, pas un gain. |
| `ZChatSpeechChain` | Voir N4 : `ZChatSpeechRequest` ne porte pas d'adresse de fichier audio. Le promettre serait faux. |
| `ZChatExportService` (4 formats) | Le domaine n'exporte pas de conversation. `grep -rlnw ZChatExportService lib` → 0, mais aucun besoin mesuré ici. |
| `ZDelegatesSearch`, `ZSyncOrchestrator`, `ZClock`, `ZFirestoreCascadeBatcher`, `ZDeletionSemantics` | 0 site hôte, mais le domaine passe par `FirebaseCrudRepositoryImpl<T extends DynamicModel>` (499 l.) et `DataState<T, Exception>` maison — ils ne deviennent atteignables qu'après N3 (entité `ZEntity`). |

---

## 5. Récapitulatif chiffré

| Catégorie | Nombre | Lignes d'hôte concernées |
|---|---:|---:|
| **Déjà migré** | 3 sites (2 sous drapeau legacy, 1 **inerte**) | 331 (jumeaux `*_zcrud_*`) |
| 🔴 **Migrable aujourd'hui** | 9 canaux | **≈ 1 400** |
| **Manque au socle** | 6 canaux, dont 1 CR ouverte | ≈ 3 200 (récurrence 2 900 + audio 300) |
| **Reste à l'hôte** | 8 familles | — |

**Détail des 1 400 lignes supprimables**, séparé pour ne pas être compté deux fois par un autre
agent :

| Lot | Fichier(s) | Lignes | Périmètre |
|---|---|---:|---|
| M1 feuille d'outils | `discovry_page_controller.dart:590-607`, `:858-975` | 136 | domaine |
| M2 composer | `discovry_search_composer.dart:191-483` | 293 | domaine |
| M3 lexer (part domaine) | `discovry_ai_page.dart:100-135` | 36 | domaine |
| M4 requête neutre (part domaine) | `discovry_page_controller.dart` ×7 blocs `_onAiCompletion` | 196 | domaine |
| M5 état vide | `daily_tasks_page.dart:560-636` | 77 | domaine |
| M6 hub de contenu | `daily_tasks_page.dart:900-1101` | 202 | domaine |
| M7 menus | 7 `PopupMenuButton` du domaine | ≈ 60 | domaine |
| M9 garde d'abandon | 12 `PopScope(canPop: true)` | 36 | domaine |
| **Sous-total domaine** | | **1 036** | **59 fichiers** |
| M3 lexer (part adjacente) | `iffd_ai_repository_impl.dart:130-300` | ≈ 170 | couche IA partagée |
| M4 route + port (part adjacente) | `iffd_ai_repository_impl.dart` (29 emballages), `ai_repository.dart` | ≈ 460 | couche IA partagée |
| **Sous-total adjacent** | | **≈ 630** | partagé avec le Notebook et le chatbot |
| **TOTAL** | | **≈ 1 666** | |

⚠️ Je retiens **1 400** comme chiffre annoncé : les 630 lignes de la couche IA sont **partagées**
avec les domaines « IA / chat / génération » et « notes » — les compter en entier ici les
double-compterait.

---

## 6. Ordre d'attaque proposé (par rapport gain/risque mesuré)

1. **M3** (lexer de fil) — corrige un défaut **vivant** (B-59 dans la Découverte), le port est
   déjà adopté ailleurs chez l'hôte, aucun changement visuel.
2. **M1 + M2** (outils déclaratifs + composer) — 429 lignes, catalogue de corpus déjà écrit,
   changement visuel maîtrisé par les builders Material.
3. **M4** (transport par route) — le plus gros gain, le plus gros risque ; la session est déjà
   créée, le pont de décodage déjà écrit, mais il faut démêler auth + App Check du `dio`
   (l'hôte le dit lui-même : `notebook_stream_opener_iffd.dart:36-46`).
4. **M5, M6, M7, M9** — petits lots indépendants, sans dépendance croisée.
5. **N5** (sous-titre) — CR ouverte, une ligne de signature au socle, deux sites d'hôte à
   simplifier.
6. **N3** puis **N1/N2** — l'entité `ZTask` d'abord (elle débloque `ZCrudScreen`), la récurrence
   et l'agenda ensuite (≈ 2 900 + ≈ 10 000 lignes d'hôte en jeu, mais rien n'en dépend en aval).

---

## 7. Limites de ce relevé

1. **Aucun test lancé**, dans aucun dépôt. Aucune affirmation ne repose sur une exécution.
2. Je n'ai **pas lu** `docs/zcrud-change-requests.md` en entier (440 270 octets) : j'en ai isolé
   les CR 114→120 par `git log` puis lecture ciblée. CR-114/115/116 sont ouvertes, 117→120
   portent « RETIRÉE AVANT ÉMISSION ». Seule **CR-116** touche mon domaine.
3. Les estimations de lignes marquées « ≈ » (M3 part adjacente, M4, M7) sont des **bornes
   prudentes** dérivées de comptes d'occurrences mesurés, pas de diffs joués.
4. Je n'ai pas mesuré le **comportement à l'exécution** de `ZChatToolCatalog`,
   `ZChatComposer` ni `ZContentHubSheet` : leurs propriétés viennent de la lecture de leur
   **corps** (indiquée à chaque ligne), pas d'un rendu observé.
5. `carte-taches-decouverte.md` était **présente et complète** (27 504 octets) ; deux de ses
   constats sont corrigés au § 0, les autres sont remesurés et confirmés.
