# Étude CR-IFFD-72 — le Notebook, ce qu'il est vraiment et ce qu'il faudrait pour le porter

**Produite le 2026-08-05**, à la demande de CR-IFFD-72 (étude, pas livraison). Trois volets
menés **en lecture seule** sur `/home/zakarius/DEV/iffd`, `/home/zakarius/DEV/lex_douane` et le
socle, plus les vérifications indépendantes de l'orchestrateur.

> Directive du propriétaire de zcrud qui encadre toute la suite :
> *« Pour le mode Chat, lex_douane a un design plus en avance, moderne et riche, qu'on va
> approfondir, adapter, rendre flexible et adaptatif. Mais côté Notebook, on cherche à
> ressembler au pixel près à IFFD legacy. Sauf que les deux doivent pouvoir adopter la même
> zone de texte, édition, sélection de fichier, d'outils… avec un controller socle que les
> deux types d'écrans peuvent étendre. »*

---

## 0. Le résultat qui commande tous les autres

**La mesure donne raison à la directive, et plus fortement qu'elle ne le supposait.**

Sur les douze axes de comparaison de la feuille de réglages, **lex_douane l'emporte 12/12**.
Et le mécanisme que CR-IFFD-72 voulait généraliser depuis IFFD — « restreindre la génération à
un sous-ensemble de corpus » — **n'existe pas chez IFFD** : il existe chez lex.

⇒ La référence du **mode Chat** est bien lex_douane, y compris pour des mécanismes que la CR
croyait tenir d'IFFD. La référence du **Notebook** reste IFFD legacy pour le **rendu**, mais
son **outillage** doit venir de lex.

---

## 1. 🔴 Ce que l'étude INFIRME dans la CR

### 1.1 La famille « corpus » d'IFFD est INERTE
La CR la désigne comme « la plus générique » et propose d'en tirer un mécanisme. Mesuré : les
six drapeaux (`enableCodeGATT`, `enableTecCedeao`, `enableCDCCedeao`, `enableCDNTogo`,
`enableCDNNiger`, `enableCGITogo`), plus `niveauIFFD`, `thinkingEffort`, `scrapeWebResults` et
`maxWeb*`, sont transmis par le contrôleur puis **jetés** par `IffdAiRepositoryImpl` : le
payload `explain` ne porte que `message`, `model`, `enableWebSearch` (grep négatif montré au
volet A).

**Le motif reste juste, la source est fausse.** Le mécanisme fonctionnel est chez lex —
`ToolsContext` + `CatalogEntry(indexed)` — piloté par données, à deux niveaux, et il **atteint
le backend**.

### 1.2 Trois erreurs factuelles de relevé
* `aiProvider` **n'existe pas** — vérifié par l'orchestrateur : **0 occurrence non commentée**.
  Le champ réel est `aiRouterId` (le seul réglage persisté, d'ailleurs).
* `elaborateExplanation` est une **méthode**, pas un drapeau.
* `enableSummary` n'est pas un mode de raisonnement.

### 1.3 Le compte d'usages de l'indicateur
`FlashcardGenerationIndicator` : **9 usages actifs**, pas 12.

### 1.4 « Synthèse vocale » — mort dans le monolithe, VIVANT ailleurs
⚠️ **Nuance de l'orchestrateur contre son propre volet A.** Le volet concluait à un TTS
entièrement mort. Vérifié : `playAudio` porte **3 appels vivants** (`:528`, `:537`, `:545`)
dans `DiscovryPageController`, et `ChatbotMessage.audioUrl` est bien sérialisé. La chaîne est
morte **côté monolithe Notebook**, vivante côté `discovery` — ce qui est cohérent avec le § 3.

---

## 2. Ce que l'étude AJOUTE

### 2.1 L'inventaire réel : 47 fonctionnalités, 9 familles
cycle de vie 5 · habilitation 6 · projection des messages 8 · capacités par message 12 ·
capacités sur la requête 2 · rendu 7 · composer 11 · vue globale 6 · réglages 10.
La CR annonçait son relevé comme partiel ; il l'était. **Dix réglages omis**, dont
`selectedDocumentsIds`, `summaryType`, `aiExpertRagModel`, `ttsProvider` — et six couplages
implicites, dont un `setAiExpert` qui **écrase les treize réglages** d'un coup.

### 2.2 Environ 1 120 lignes mortes — 22 % du fichier
`ConversationSearchBar` (123, déjà connue) · **`ToolNumberInputTile` (80)** — que la CR cite
pourtant comme widget à porter · `MinMaxFormatter` (29, corps commenté) · le bloc TTS/podcast
du monolithe (~480) · copier/partager/imprimer/pouces (167) · blocs de `ToolsSheet` (170).
🔴 Et un `_ValueNotifierBuilder` **inerte par construction** : son notifier ne peut jamais
valoir `true`, si bien que le bouton « Afficher plus » est en réalité « Exporter en PDF ».

### 2.3 Dix-huit comportements structurants, tous à ne PAS porter
Appariement **O(n²) par contenu** recalculé à chaque token · double représentation des
variantes · le **protocole RAG fuit dans le texte** et est récupéré au regex · `isThinking`
déduit par `contains("RAG_THINKING")` · heuristique de parité `% 2` · trois effets de bord
dans `build` · FAB d'envoi à **40 dp** · **zéro l10n, zéro `Semantics`**.

### 2.4 `discovery` / `explain_ai` : le classement « hors périmètre » est intenable
Dépendance **structurelle**, 7 points de contact. `DiscovryPageController` (2 359 l.) **est**
l'état de la vue ; « Régénérer » pousse `ExplainAiPage` (751 l.). Environ **3 110 lignes sur
4 613** sont sur le chemin d'exécution du Notebook.

### 2.5 La persistance : des ports, pas un modèle
Collections plates `ChatbotConversation` / `ChatbotMessage`. 🔴 Vérifié par l'orchestrateur :
le champ `isChatSession` existe (défaut `false`) mais **n'est renseigné à aucun des sites de
construction** (`:955`, `:965` — absent des deux). Le discriminant réel est un **préfixe
d'identifiant déterministe**, `folderExplationConversation…` — faute de frappe comprise, en
production. Aucun quota dans le legacy.
⇒ Le socle doit porter des **ports**, jamais ce modèle.

---

## 3. Ce que le socle a DÉJÀ — le garde-fou anti-réinvention

Vérification du tableau § ③ de la CR : **8 confirmées, 0 infirmée, 4 nuancées.**

Les quatre nuancées existent **en donnée mais sans aucune surface** : `ZChatThinkingStep`,
`ZChatComputeEffort`, `ZChatResponseLength`/`ZChatLengthBias`, quotas.

🔴 **Un piège de réinvention évité** : la CR cite `ZChatQuotaMetadata`. **Ce type n'existe
pas** (grep → 0). Les vrais noms sont `ZChatQuotaKeys` + `zChatQuotaFromMetadata`. Un lot qui
aurait grepé le nom de la CR aurait conclu à un manque et réécrit le lecteur de quota.

### Le rendu « pixel près » ne se joue pas dans un fichier de constantes
La bulle de message du legacy **n'est pas du rendu maison** : elle délègue à `SfAIAssistView`
(`chatbot_conversation_screen.dart:3422`). Le legacy ne fige autour que `widthFactor: 0.95` en
Notebook, un rayon 12 sur la bulle de requête, et le masquage avatar/nom.

⇒ Le socle **a déjà la bonne couture** : `ZSfAssistShellRenderer` (`zcrud_chat_syncfusion`),
backend du port `ZChatShellRenderer`, qui rend le **cadre** Syncfusion et rappelle la fabrique
de tuiles du socle. Son dartdoc documente précisément l'erreur à ne pas refaire — une
`ZSfAssistConversationView` parallèle avait été livrée puis **supprimée**, motif CR-LEX-78.
`zcrud_chat` reste **pur** (aucune arête Syncfusion, garde `z_chat_purity_test`).

---

## 4. Ce qui MANQUE réellement

### 4.1 🔴 La couche de saisie — le manque le plus net, et il vise la directive
Vérifié par l'orchestrateur, grep négatif à l'appui : **ni `ZChatConversationView` ni
`ZChatNotebookView` ne montent de barre de capture**. Elles partagent la **fabrique de tuile**
(garde CR-71), **pas la saisie**.

* **Aucun widget du socle ne rend `ZChatController.composer`** — les deux seuls `EditableText`
  du paquet sont dans le champ de *relecture* d'une capture vocale.
* **`ZChatCaptureBar` n'est pas une barre de saisie** : ce sont deux boutons dictée/OCR.

⇒ L'exigence « les deux surfaces adoptent la même zone de texte, édition, sélection de
fichier, d'outils, avec un controller socle extensible » désigne un **chantier**, pas un
acquis. C'est le premier lot à faire.

### 4.2 La restriction de corpus : NON, et le vrai sujet est ailleurs
Chemin mesuré de bout en bout : closure hôte `ZChatRequestBuilder` → `send():388` →
`_drain:503` → `_streamPort.stream`. `ZChatGenerationRequest` (14 champs) n'a **aucun** champ
de portée documentaire ; les 8 occurrences de `corpus` sont toutes **en lecture**.
`ZChatCustomAction` n'est pas une voie de contournement : il route vers `executeCustom` et ne
touche **jamais** le port de génération.

🔴 **Ce que ni la CR ni lex n'ont formulé** : `ZChatSource.corpus` est un **libellé**, pas une
clé. Même en ajoutant un champ de restriction, aucune restriction ne serait **vérifiable** —
on ne pourrait pas confronter les sources retournées à la portée demandée. Le vrai sujet est
le **bouclage lecture/écriture** sur une clé de corpus stable.

### 4.3 La feuille de réglages : le porteur manque, pas le widget
Aucune surface (énumération exhaustive des 15 widgets publics). Les enums sont atteignables,
mais par **un seul canal étroit** : la capture de closure. `send()` n'a aucun paramètre.
🔴 Et un défaut structurel : **`ZChatRegenerateAction` ne porte que `{messageId}`** (vérifié,
`z_chat_action.dart:205-210`), alors que `ZChatLengthBias` est défini comme « biais d'une
régénération » — il est donc **structurellement inatteignable sur son propre cas d'usage**.

### 4.4 Ce que lex apporte et que le socle n'a pas
`ChatInputController` porte **8 mécanismes absents** : `preExpertToolsContext`,
`cycleThinking`, mode édition, brouillon à compteur, `resetToDefaults`…
À l'inverse — et c'est à dire aux deux hôtes — **la capture (dictée/OCR) du socle est déjà
meilleure que celle de lex**, comme le sont pièces jointes, quotas, export et diffusion.

---

## 5. Plan de travail proposé (ordre d'exécution)

| # | Lot | Pourquoi d'abord |
|---|---|---|
| 1 | **Composer socle partagé** + controller extensible, monté par les deux surfaces, avec garde d'anti-divergence (même fabrique, comme CR-71 pour la tuile) | c'est la directive, et c'est le manque le plus net |
| 2 | **Porteur de réglages** neutre sur la requête **et sur la régénération** (ferme le défaut `ZChatLengthBias`) | débloque tous les réglages déjà modélisés |
| 3 | **Clé de corpus + portée vérifiable** (bouclage lecture/écriture), motif porté de lex | le seul vrai manque fonctionnel, et il est générique |
| 4 | **`ZChatNotebookReference`** + skin par défaut via `ZSfAssistShellRenderer` | le « pixel près », une fois l'ossature en place |
| 5 | Feuille de réglages **par défaut** composable (widgets personnalisables, rendu de référence) | dépend de 2 et 3 |

**Ne pas porter** : les 22 % de code mort, les 18 comportements structurants du § 2.3, et le
modèle de persistance du § 2.5.

---

## 6. Réserves de cette étude

* Le volet A a parcouru le monolithe par tranches : exhaustif sur les familles, pas garanti
  sur chaque ligne des 5 180.
* Les valeurs de rendu du volet B sont relevées **à la source**, jamais mesurées à l'écran :
  un rendu de référence exigera une mesure de pixels, comme pour les cartes d'étude.
* La comparaison avec lex porte sur `ToolsSheet` et `ChatInputController` ; le reste de son
  volet chat n'a pas été dépouillé.
* Aucune de ces conclusions n'a été éprouvée par une implémentation : c'est une étude.
