# Réfutation — Cartes mentales (mindmap) / IFFD
## Affirmation attaquée
« Le socle sait déjà le faire, par `ZMindmapGenerationPort.generateMindmap(ZMindmapGenerationRequest) -> Future<ZResult<List<ZMindmapNode>>>` + `ZMindmapSourceRef` » — gain annoncé **~116 lignes d'hôte supprimées**.

**VERDICT : DÉMENTIE** — non pas sur l'existence du canal (elle est confirmée), mais sur trois points vérifiables : une **preuve d'appel fausse**, une **arithmétique gonflée**, et une **couverture partielle présentée comme totale** (le routage par intention de l'hôte n'a aucun logement typé).

---

## 1. Ce qui RÉSISTE (vérifié, à conserver)

| Point | Vérification | Résultat |
|---|---|---|
| Port au chemin/lignes cités | `z_mindmap_generation_port.dart` = 195 l. | ✅ `:189` port, `:81` requête, `:49` `ZMindmapSourceRef` — **exact** |
| Signature | `Future<ZResult<List<ZMindmapNode>>> generateMindmap(ZMindmapGenerationRequest)` `:192-194` | ✅ exacte |
| Corps réel (pas la dartdoc) | lecture intégrale | ✅ `abstract interface class` pur, **aucune** impl de référence |
| `extra` assaini | `:148` `zSanitizeExtra(_extra, _reservedKeys)`, `:151` `{...ZSyncMeta.reservedKeys}` | ✅ conforme gate reserved-keys |
| Forêt éphémère | `:11-16` + absence de `id`/`folderId` dans la requête | ✅ aucune identité fabriquée |
| **Exporté** | `packages/zcrud_study/lib/zcrud_study.dart:31` | ✅ `export 'src/domain/z_mindmap_generation_port.dart';` |
| **Atteignable au tag épinglé** | `git show v3.21.0:…` | ✅ port **et** export présents à **v3.21.0** (lignes identiques) |
| Dépendances hôte | `iffd/pubspec.yaml` | ✅ `zcrud_study` **et** `zcrud_mindmap` déclarés, `ref: v3.21.0` (48 entrées uniformes) |
| Grep négatif hôte | `grep -rn 'ZMindmapGenerationPort\|ZMindmapGenerationRequest\|ZMindmapSourceRef' lib test` | ✅ **0 / 0 / 0** ; symbole présent seulement dans `docs/` (4 fichiers) |

Le canal est donc **réel, exporté, et consommable en l'état**. Ce n'est pas un jeton sans consommateur.

---

## 2. RÉFUTATION 1 — la « FORME VÉRIFIÉE AU SITE D'APPEL » est FAUSSE

L'affirmation avance : *« les 7 copies n'agissent que sur `if (completed && !hasError)` (popup_menu_helpers.dart:350-352) »*.

**a) Il y a 8 sites d'appel dans `lib/`, pas 7** :

| # | Fichier:ligne | Méthode |
|---|---|---|
| 1 | `folder_documents_actions_dialog_widget.dart:331` | PagesContents |
| 2 | `folder_documents_actions_dialog_widget.dart:344` | WholeDocument |
| 3 | `explain_ai_page.dart:496` | FromNotes |
| 4 | `smartnote_actions_dialog_widget.dart:185` | FromNotes |
| 5 | `valuation_tool_model_actions_dialog_widget.dart:159` | FromNotes |
| 6 | `popup_menu_helpers.dart:346` | FromNotes |
| 7 | `popup_menu_helpers.dart:776` | PagesContents |
| 8 | `notebook_capabilities_iffd.dart:488` | FromNotes |

**b) Cinq sites agissent HORS de ce garde** — grep montré :
```
valuation_tool_model_actions_dialog_widget.dart:212:  if (completed) mindmapCallback?.call(false);
popup_menu_helpers.dart:393:                         if (completed) mindmapCallback?.call(false);
popup_menu_helpers.dart:830:                         if (completed) mindmapCallback?.call(false);
notebook_capabilities_iffd.dart:340:                  marquer?.call(messageId, isGenerating: false);
notebook_capabilities_iffd.dart:348:                  marquer?.call(messageId, isGenerating: false);
```
L'extinction de l'indicateur se fait **quel que soit `hasError`**. La preuve citée (`:350-352`) est une lecture de **3 lignes** extrapolée à un rappel qui va jusqu'à `:393`.

**c) Le code de l'hôte affirme le CONTRAIRE de la prémisse.** `notebook_capabilities_iffd.dart:326-329` :
> `// ⚠️ SEUL 'completed' termine : 'onComplete' est appelé plusieurs fois pendant un flux.`

**La conclusion survit néanmoins, mais pour une AUTRE raison que celle avancée** : `callApi` déclare `bool stream = false` (`iffd_ai_repository_impl.dart:76`) et **aucune** des trois impls mindmap ne passe `stream:` — elles appellent `callApi(endpoint:…, data:…, onComplete:…)` (`:634-638`, `:1290-1294`, `:1317-1321`). Le rappel est donc invoqué **une seule fois**. Le `Future<ZResult<…>>` convient — par non-streaming, pas par la forme du garde.

---

## 3. RÉFUTATION 2 — l'arithmétique est gonflée (~116 annoncé, **108** réel au mieux)

Mesure par appariement d'accolades (le matcher naïf trébuche sur `{bool hasError}` dans le type du rappel) :

| Nature | Fichier | Span | Lignes |
|---|---|---|---|
| MORT | `openai…:598-612` / `614-627` / `650-659` | | 15 + 14 + 10 = **39** |
| MORT | `cloud_functions…:425-439` / `441-454` / `477-486` | | 15 + 14 + 10 = **39** |
| **Total 6 corps morts** | | | **78** (annoncé : 84) |
| ABSTRAIT | `ai_repository.dart:109-115` / `408-419` / `421-431` | | 7 + 12 + 11 = **30** (annoncé : ~32) |
| **Supprimable net** | | | **108** (annoncé : ~116) |
| RÉEL — **NON supprimé** | `iffd_ai_repository_impl.dart:623-640` / `1266-1295` / `1297-1322` | | 18 + 30 + 26 = **74** |

Trois défauts :
1. **La mesure citée est erronée** : `openai:599-627` couvre **deux** méthodes (599-612 et 614-627), pas une de 14 l. Les corps ne sont pas uniformes (10 / 14 / 15).
2. **Les 74 l. d'impl réelle ne disparaissent pas** — elles *deviennent* l'implémentation hôte du port.
3. **Les 78 l. mortes ne sont pas imputables au socle.** Elles n'existent que parce que `OpenAiAiRepositoryImpl` et `CloudFunctionsAiRepositoryImpl` implémentent l'interface large `AiRepository`. **Scinder cette interface côté hôte** les supprime — sans une ligne de zcrud. Le gain principal annoncé est atteignable **sans le port**.

---

## 4. RÉFUTATION 3 — couverture partielle : le ROUTAGE n'a aucun logement typé

C'est le point de fond. L'impl réelle résout **trois** dimensions distinctes :

```dart
// iffd_ai_repository_impl.dart:634-638
return callApi(
  endpoint: aiRouter?.mindmapModel ?? "generate_mindmap",   // ← une ROUTE par intention
  data: {"message": prompt, "model": aiRouter?.aiModel, "jsonMode": true},  // ← un MODÈLE
  onComplete: onComplete,
);
```
`ai_models.dart:205-206` confirme la paire : `final String? mindmapModel;` **et** `final List<String> mindmapFallbackModels;` — plus `final String aiModel;` (`:194`).

Or `ZMindmapGenerationRequest` n'offre **qu'un seul** `String? modelId` opaque (`:138`). **Ni route, ni liste de repli.** L'hôte devrait les faire voyager dans `extra` non typé.

C'est frontalement la **décision d'owner du 2026-08-23 (« transport PAR ROUTE »)**, qui exige que le mode par route soit *« pleinement prévu et supporté par le socle, au même rang que l'autre »*, IFFD étant l'exemple nommé. Le port ne le prévoit pas.

**S'y ajoutent trois paramètres structurels sans logement typé** : `subject` et `parentSubject` sont porteurs dans **les trois** prompts (`ai_prompt_generator.dart:420` : « pour le sujet **$subject** (THEME GENERALE: …) »), et `customInstructions` n'a qu'un `instructions` générique. `subject`/`parentSubject` iraient en `extra`.

**Et trois modes deviennent une seule méthode** : `FromNotes` / `FromDocumentPagesContents` / `FromWholeDocument` ont trois constructeurs de prompt distincts. Leur discrimination via le port devient **implicite** (présence de `source`, vacuité de `content`) — fragile et non contractuelle.

*Nuance en faveur du port* : `pagesContents: Map<int,String>` n'est **pas** bloquant — le prompt l'aplatit déjà en `"Page ${e.key}: ${e.value}"` (`ai_prompt_generator.dart:416-418`), donc l'hôte peut aplatir dans `content`. Et `zSanitizeExtra` (`z_extensible.dart:73-80`) est un simple filtre de clés, `zJsonHash` (`z_json_equality.dart:78`) retombe sur `v.hashCode` : un objet non-JSON dans `extra` ne casse rien. Ces deux craintes-là ne tiennent pas.

---

## 5. Conditions cachées non signalées

1. **Une garde de parité s'ancre sur le symbole** : `test/qa-w2/notebook_parity_test.dart:131` déclare `ancrage: 'generateMindmapFromNotes'`, avec la note explicite qu'un ancrage mal choisi *« serait resté VERT sur un portage qui n'engendre aucune carte »*. Migrer sans réancrer la rend **muette**.
2. **Paramètres morts dans l'impl réelle** : `iffd_ai_repository_impl.dart:1277-1278` déclare `String? content` et `List<int> emptyPages` — **absents de l'abstrait** (`:408-419`) et **jamais transmis** au constructeur de prompt (`:1281-1289`). Les signatures ne sont donc pas « triplées à l'identique ».
3. **Le volume réel de l'hôte n'est pas dans la génération mais dans l'après** : chaque site enchaîne `normalizedJsonString` → `json.decode` → `MindmapNode.fromMap`/`fromMapList` → `MindmapModel(...)` → `showFolderMindmapViewer(...)` (~45 l./site × 8). Le port n'en couvre rien — l'affirmation l'admet, mais le gain de 108 l. doit se lire face à ~360 l. inchangées.

---

## 6. Correction proposée

> Le canal existe, est exporté (`zcrud_study.dart:31`) et est atteignable au tag épinglé **v3.21.0** — cela résiste. Mais : les sites d'appel sont **8** et non 7 ; l'assertion « n'agissent que sur `if (completed && !hasError)` » est **fausse** (5 sites agissent hors du garde, `popup_menu_helpers.dart:393`/`:830`, `valuation_tool…:212`, `notebook_capabilities…:340`/`:348`) — la forme `Future` convient tout de même, parce que `callApi` a `stream = false` par défaut (`:76`) et qu'aucune impl mindmap ne l'active. Le gain réel est **108 lignes** (78 mortes + 30 abstraites), non ~116, et les **74 l.** d'impl réelle survivent comme impl hôte du port. Surtout, les 78 l. mortes se suppriment par une **scission d'interface purement hôte**, sans zcrud. Enfin le port **ne couvre pas le routage** : l'hôte résout une **route par intention** (`aiRouter.mindmapModel` → `endpoint:`), un **modèle** (`aiModel`) et une **liste de repli** (`mindmapFallbackModels`), là où la requête n'offre qu'un `modelId` opaque — contraire à la décision d'owner « transport PAR ROUTE » du 2026-08-23. `subject`/`parentSubject`, porteurs dans les trois prompts, n'ont pas non plus de logement typé.
>
> **Pour que l'affirmation tienne**, il manque au port : (1) un champ de **route** (+ repli) de premier rang ; (2) un logement typé pour `subject`/`parentSubject` ; (3) une discrimination explicite des trois modes de génération.
