# Contrat du composer de chat avancé — zcrud

> **Statut** : contrat de conception, 2026-08-27. Aucun code écrit par ce document.
> **Mandat propriétaire** : « prévoir et offrir toutes les fonctionnalités possibles d'un composer
> de Chat avancé, même si cela implique de prévoir les fonctionnalités des contrôleurs de notebook
> et chat. » Ce mandat **dépasse** CR-IFFD-125, qui se borne à ce dont ses hôtes ont l'usage.
> **Critère d'acceptation mesurable** : `lex_douane/packages/lex_ui/lib/presentation/widgets/chat/chat_input.dart`
> (1 231 lignes) supprimable au profit d'un montage du composer du socle, sans perte.

---

## 0. Avertissement — la CR mesure UN FICHIER, pas le paquet

CR-IFFD-125 conclut que « le composer ignore tout ce que le contrôleur sait ». Ce constat est
**exact sur `z_chat_composer.dart`** (540 l) — et **faux sur le paquet**. Le socle a livré en
**v3.6.0** (`ce3a47a62`, 2026-08-23) l'assemblage complet, que la CR ne cite jamais :

| Brique livrée | Fichier:ligne | Ce qu'elle couvre |
|---|---|---|
| `ZDefaultChatComposer` | `zcrud_chat/…/view/z_default_chat_composer.dart` (600 l) | l'assemblage complet : ~50 paramètres, un builder par pièce |
| `ZChatComposerSurface` | `…/view/z_chat_composer_band.dart:186` | **le cadre** : fond, filet, rayon, `clipBehavior` |
| `ZChatComposerEditingBanner` | `…/z_chat_composer_band.dart:1264` | bandeau d'édition, branché sur `controller.editing` (`:1289`) |
| `ZChatComposerStopTarget` | `…/z_chat_composer_band.dart:1193` | la bascule STOP pendant le flux |
| `ZChatComposerPickerTrigger` / `…ThinkingToggle` / `…WebSearchToggle` / `…ToolsTrigger` / `…CountBadge` / `…EffortSelector` / `…DictationTrigger` | `…/z_chat_composer_band.dart:297, 598, 705, 793, 892, 920, 1371` | menu `+`, bascules, badge de compte, paliers d'effort, dictée |
| `ZChatComposerSendTarget` / `…AnimatedHint` | `…/view/z_chat_composer_chrome.dart:290, 379` | envoi 48 dp + `AnimatedScale` ; invite tournante |
| `ZChatComposerChrome` / `…Style` / `ZChatComposerReference` | `…/z_chat_composer_chrome.dart:55, 132, 212` ; `…/view/z_chat_composer_reference.dart` | 13 réglages, résolution **paramètre > jeton > référence** ; fichier de référence audité (exception FR-26) |

Tous exportés : `zcrud_chat/lib/zcrud_chat.dart:163,172-176,225`.

**Conséquence de méthode** : la règle du dépôt « un plan ancien se MESURE avant de s'exécuter »
s'applique à la CR elle-même. Le crible A1→L1 de CR-IFFD-125 a été **rejoué sur disque** pour ce
document ; **cinq de ses lignes sont périmées** et une sixième est fausse (§1.7).

---

## 1. La surface complète, capacité par capacité

**Nature du manque** — la colonne qui décide de tout le reste :

| Code | Nature | Où le manque se répare |
|---|---|---|
| **J** | **jeton** de thème | `zcrud_core/…/z_theme.dart` + résolution dans le chrome |
| **C** | **créneau** (slot) | signature d'un widget de `zcrud_chat` |
| **B** | **branchement** sur une tranche déjà portée par un contrôleur | `zcrud_chat` (présentation) |
| **T** | **type de domaine** | `zcrud_chat_kernel` |
| **G** | **geste** de saisie (clavier, souris, presse-papier, glisser) | `zcrud_chat` (présentation) |
| **O** | **orchestration** (contrôleur : machine à états, non un widget) | `zcrud_chat` (présentation) |

### 1.1 A — Saisie

| # | Capacité | État réel du socle (`fichier:ligne`) | Manque | Nature |
|---|---|---|---|---|
| A1 | champ multiligne min/max | ✅ `z_chat_composer.dart:227-230`, défauts `ZChatComposerReference.fieldMinLines/fieldMaxLines` | — | — |
| A2 | politique de soumission | ✅ `ZChatComposerSubmitPolicy`, table `Shortcuts` `z_chat_composer.dart:428-446` | — | — |
| A3 | invite tournante | ✅ `ZChatComposerAnimatedHint` `z_chat_composer_chrome.dart:379` | — | — |
| A4 | **coller une image** | ❌ `grep -rn "paste\|Clipboard" zcrud_chat/lib zcrud_chat_kernel/lib` ⇒ **0** | un `ZChatComposerPastePort` + interception au champ | **G + T** |
| A5 | **glisser-déposer** | ❌ `grep -rn "DropTarget\|onDrop"` ⇒ **0** | zone de dépôt **optionnelle**, aucune dépendance nouvelle | **G + C** |
| A6 | rappel du dernier message | ❌ aucun symbole | flèche haut sur champ vide ⇒ recharge la dernière saisie | **G + B** |
| A7 | compteur de caractères / jetons | ❌ `grep -rn "characterCount\|charCount"` ⇒ **0** ; `tokenCount` n'existe que sur `ZChatAiFailure` (`zcrud_chat_kernel/…/ai/z_chat_ai_failure.dart:103`) | créneau `counter` + **port** de comptage | **C + T** |

### 1.2 B — Envoi

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| B1 | envoi animé | ✅ `ZChatComposerSendTarget` `z_chat_composer_chrome.dart:290` | — | — |
| B2 | cible ≥ 48 dp | ✅ `_ZChatComposerTarget` `z_chat_composer.dart:515-540` ; écrêtage au plancher `z_chat_composer_chrome.dart:243` | — | — |
| B3 | **bascule STOP** | ✅ **livré** — `ZChatComposerStopTarget` `z_chat_composer_band.dart:1193`, monté par défaut `z_default_chat_composer.dart:404-410` ; annulation par `runAction(ZChatCancelAction(requestId:))` (`z_chat_controller.dart:1216`) | *(la CR le classe ⚙️ : périmé)* | — |
| B4 | **3ᵉ état : envoi occupé** | ❌ le socle n'a que STOP / ENVOI ; Lex a un spinner d'upload (`chat_input.dart:633-643`) et un glyphe `check_circle` en mode édition (`:670-682`) | glyphes **par état**, jamais un glyphe unique | **C** |

### 1.3 C — Pièces jointes

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| C1 | sources multiples | ✅ `ZChatAttachmentPicker` (`attachment/z_chat_attachment_ports.dart`) | — | — |
| C2 | vignettes, plafonds | ✅ `ZChatAttachmentController` (366 l), `ZChatAttachmentStrip` (232 l) | — | — |
| C3 | téléversement | ✅ `ZChatAttachmentUploader` | — | — |
| C4 | motifs de rejet | ⚠️ 6 codes (`z_chat_attachment_failure.dart:32-49`) ; `pickFailed` fusionne 3 causes | `fileInaccessible`, `cameraError`, `galleryError` en **queue** d'enum | **T** |
| C5 | OCR / dictée | ✅ `ZChatDictationPort` (Stream, `zcrud_chat_kernel/…/capture/z_chat_capture_port.dart:264`) + `ZChatOcrPort` (`:324`), texte opaque `ZUnreviewedText` (`:174`). ⚠️ **`ZChatCapturePort` n'existe pas** — la CR le nomme à tort (`grep -rn "class ZChatCapturePort" packages/` ⇒ 0) | — | — |
| C6 | **aperçu monté par le composer** | ❌ `grep -rn "ZChatAttachmentStrip" z_default_chat_composer.dart` ⇒ **0** | un **rang** dédié dans la boîte | **C** |
| C7 | **progression du téléversement** | ❌ `grep -rn "progress\|percent\|Stream" …/presentation/attachment/` ⇒ **0** ; `ZChatAttachmentUploader.upload` est un `Future` tout-ou-rien (`z_chat_attachment_ports.dart:82`) | tranche de progression sur le contrôleur **+** rang dans la boîte. Le **contrat du port** peut rester `Future` : un `ValueListenable<bool> uploading` suffit à Lex (`chat_input.dart:508` = `LinearProgressIndicator()` indéterminé) | **B + C** |
| C8 | sources cloud | ✅ extensible par port | — | — |
| — | `sizeBytes` | ✅ **existe** : `z_pending_attachment.dart:61` (`int get sizeBytes => bytes.length`) — **la CR ❺① est périmée** | — | — |

### 1.4 D — Outils et modes

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| D1 | bascules | ✅ 3 pièces livrées + créneau `tools` libre | — | — |
| D2 | **niveaux sur une bascule** (0→5) | ⚠️ le domaine **et** le contrôleur l'ont : `ZChatCycleState` (`step`/`stepCount`, `zcrud_chat_kernel/…/tools/z_chat_tool_state.dart:212`), `ZChatScaleState` (`:328`), et le verbe `ZChatToolController.advance(key)` (`zcrud_chat/…/tools/z_chat_tool_controller.dart:183`). **Aucune pièce de présentation** ne les rend | une puce à cycle | **C seul** |
| D3 | pastille de compte | ✅ `ZChatComposerCountBadge` `z_chat_composer_band.dart:892` | — | — |
| D4 | teinte d'état actif | ✅ jeton `chatComposerActiveAccent` `z_theme.dart:1952` | — | — |
| D5 | **catalogue d'outils déclaratif** | ✅ `ZChatToolCatalog` (519 l), `ZChatToolEntry` (474 l, `prominence`, `disabledWhen`, `deactivates`, `countsTowardActive`) | — | — |
| D6 | **puce d'outil générique** | ❌ chaque pièce est écrite à la main ; rien ne rend un `ZChatToolEntry` en puce | `ZChatComposerToolChip` piloté par le catalogue | **C** |

### 1.5 E — Modèle

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| E1 | sélecteur de modèle | ✅ `ZChatComposerModelSelector` (439 l) + `modelOptions`/`modelActiveId`/`onSelectModel` (`z_default_chat_composer.dart:198-204`) | — | — |
| E2 | description / coût par modèle | à vérifier au lot M (cf. §6) sur `ZChatModelOption` | champ additif si absent | **T** |

### 1.6 F — Voix

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| F1 | dictée ponctuelle | ✅ `ZChatComposerDictationTrigger` `z_chat_composer_band.dart:1371` | — | — |
| F2 | **mode vocal continu** | ⚠️ les **deux ports existent** : `ZChatDictationPort.listen()` est un `Stream` (`…/capture/z_chat_capture_port.dart:276`) et `ZChatSpeechPort.speak()` (`…/diffusion/z_chat_speech_port.dart:158`). Ce qui manque est la **boucle** écouter → soumettre → énoncer → réécouter | un contrôleur de session vocale | **O** |

### 1.7 G — Contexte

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| G1 | **@-mentions** | ❌ `grep -rn "mention" zcrud_chat/lib zcrud_chat_kernel/lib` ⇒ **0** | déclencheur, source de candidats, jeton inséré | **T + O + C** |
| G2 | **commandes slash** | ❌ `grep -rn "slash"` ⇒ **0** | idem, plus l'**exécution** de la commande | **T + O + C** |

C'est le seul manque de **mécanique** du tableau, et le seul qui exige un type de domaine neuf
non trivial. Il est aussi le seul dont aucun hôte connu n'a l'usage aujourd'hui.

### 1.8 H — Suggestions

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| H1 | amorces au démarrage | ⚙️ `ZChatSuggestion` (`zcrud_chat_kernel/…/z_chat_suggestion.dart:101`) arrive par `ZChatSuggestionsEvent` et atterrit dans `ZChatStreamProgress.suggestions` (`zcrud_chat/…/z_chat_stream_progress.dart:75`), lisible via `controller.progress(requestId)` (`z_chat_controller.dart:460`) | la tranche est **par requête** ; un composer a besoin d'une vue **par conversation** | **B + C** (+ **O** pour la vue agrégée) |
| H2 | suggestions proactives après réponse | ⚙️ même tranche (`ProactiveSuggestionsBar` chez Lex, `proactive_suggestions_bar.dart`, 102 l, montée au rang 3 `chat_input.dart:513`) | idem | **B + C + O** |

### 1.9 I / J — Édition et brouillon

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| I1 | bandeau d'édition | ✅ **livré** (`z_chat_composer_band.dart:1264`) — *la CR le classe ⚙️ : périmé* | — | — |
| J1 | brouillon | ⚙️ `ZChatDraft` (`zcrud_chat_kernel/…/action/z_chat_action.dart:84`) + `currentDraft` (`z_chat_controller.dart:441`), `seedDraft` (`:581`), `draftSeeds` (`:438`), sauvegarde/restitution autour de `startEditing`/`cancelEditing` (`:550`, `:568`). **Aucune restitution visuelle**, **aucun port de persistance** | indicateur + restauration explicite ; persistance = **port**, jamais une implémentation | **B + C** (+ **T** pour le port) |

### 1.10 K — États

| # | Capacité | État réel | Manque | Nature |
|---|---|---|---|---|
| K1a | **quota** | ⚠️ le domaine l'a (`ZChatQuotaSnapshot`, `zcrud_chat_kernel/…/z_chat_quota_snapshot.dart:11` : `limit`, `remaining`, `resetEpoch`, `prepaidBalance`) **et** la tranche aussi (`ZChatStreamProgress.quota`). Aucune bande d'état ne les rend | une bande d'état **neutre** | **C** |
| K1b | **erreur** | ⚙️ `controller.lastFailure` (`z_chat_controller.dart:409`) — jamais rendue par le composer | même bande | **B + C** |
| K1c | **hors ligne** | ❌ `grep -rni "offline"` ⇒ 1 hit, un commentaire de merge (`…/action/z_chat_action.dart:279`) | **ne rien inventer** : c'est un `ValueListenable<bool>` d'hôte passé en paramètre (§5) | **C seul** |

### 1.11 L — Accessibilité

✅ `Semantics(container:, explicitChildNodes:, label:)` `z_chat_composer.dart:306-309` ; plancher
tactile `kZChatMinTapTarget` ; `TextAlign.start` partout. Rien à ajouter — **à re-vérifier par lot**.

### 1.12 Six écarts que le crible de la CR ne relève pas

Mesurés sur `chat_input.dart`, tous absents du socle : le **badge OCR sur une vignette** (relancer
l'OCR depuis l'aperçu, `:1050-1101`) ; le **3ᵉ état du bouton d'envoi** (spinner pendant l'upload,
`:633-643`) ; le **glyphe `check_circle`** en mode édition (`:670-682`) ; le **micro conditionné par
la disponibilité du moteur** (`:877-893` — `isAvailable()` du port n'est consulté par aucune pièce) ;
le **brouillon de suggestion injecté dans le champ** (`:439-454`) ; le **cycle 0→5 sur une seule
puce** (`:748-812`). Les rangs manquants (upload `:508`, suggestions `:513`, pièces `:522`) sont
traités au §2.3.

---

## 2. Le contrat de disposition

### 2.1 Le fait qui tranche : le socle n'a pas d'`InputDecorator`

Le champ du socle est un **`EditableText` nu** (`z_chat_composer.dart:390`), pas un `TextField`.
`suffixIcon`, `helper`, `prefix` — les trois slots dont Lex se sert (`chat_input.dart:598`, `:599`)
— **n'existent pas** dans cet arbre. Les offrir imposerait de remplacer `EditableText` par
`TextField`, ce qui :

1. redonnerait à `InputDecorator` la maîtrise de la ligne de base, du `contentPadding` et de la
   hauteur — soit exactement les trois choses que `ZChatComposerChromeStyle` gouverne aujourd'hui ;
2. doublerait tout l'arbre, donc toute garde ;
3. changerait l'arbre d'un hôte passif — **interdit** (AD-4).

### 2.2 Verdict : NI un mode, NI deux widgets — une composition de créneaux + deux réglages

La différence mesurée entre le socle et Lex se réduit à **trois écarts**, dont deux déjà comblés :

| Écart | Lex | Socle | Reste à faire |
|---|---|---|---|
| la boîte unique (fond, filet, rayon, clip) | `Container` `chat_input.dart:456-468` | ✅ `ZChatComposerSurface` `z_chat_composer_band.dart:186`, montée par `z_default_chat_composer.dart:336` | **rien** (sauf les jetons, §1) |
| les outils DANS la boîte, sous le champ | `helper:` `chat_input.dart:599` | ✅ créneau `tools`, dans la même `Column`, sous la même bordure (`z_chat_composer.dart:339`) | **rien** |
| l'alignement vertical de l'envoi | `suffixIcon` ⇒ **centré** sur le champ | `Row(crossAxisAlignment: end)` ⇒ **en bas** (`z_chat_composer.dart:317`) | **un enum** |

⇒ **Un `ZChatComposerLayout.adjacent/inline` serait un faux jumeau** : il nommerait « mode » ce qui
est un alignement, et ferait croire à deux arbres là où il n'y en a qu'un. **Rejeté.**
On livre à la place :

* `ZChatComposerSendAlignment { bottom, center }` — défaut `bottom` (l'actuel), mappé sur
  `Row.crossAxisAlignment` (`end` / `center`). C'est tout ce que `suffixIcon` apportait.
* `ZChatComposerBandPlacement { below, above }` — défaut `below` (l'actuel). Certains produits
  (Gemini) posent la bande **au-dessus** du champ ; c'est un échange de deux enfants de la `Column`,
  pas un mode.

### 2.3 Le RANG canonique — le vrai contrat

Tout vit **dans** `ZChatComposerSurface`. C'est ce qui fait qu'une vignette ajoutée **pousse le
champ** sans sortir du cadre : le cadre est le parent, pas le voisin.

```
ZChatComposerSurface            <- fond + filet + rayon + clip (le CADRE)
└── Column (mainAxisSize.min, crossAxisAlignment.stretch)
    0  status        bande d'état      hors ligne / quota / erreur        [NEUF]
    1  editing       bandeau d'édition                                    [LIVRÉ]
    2  progress      progression du téléversement                         [NEUF]
    3  suggestions   bande de suggestions (amorces + proactives)          [NEUF]
    4  attachments   aperçu des pièces jointes                            [NEUF, widget existant]
    5  capture       dictée / relecture                                   [LIVRÉ]
    6  Row [ leading | (champ + hint) | trailing ]                        [LIVRÉ]
    7  tools         bande d'accessoires                                  [LIVRÉ]
    8  counter       compteur de caractères / jetons                      [NEUF]
```

Correspondance **mesurée** avec Lex (`chat_input.dart`) : rang 1 = `:472-505`, rang 2 = `:508`,
rang 3 = `:513-519`, rang 4 = `:522-523`, rang 6 = `:532-566` (envoi en `suffixIcon` `:598`),
rang 7 = `helper` `:599`. Lex n'a ni rang 0, ni rang 5, ni rang 8.

**Pourquoi cet ordre, et pas un autre** : rangs 0-2 sont des **annonces** (elles doivent rester
visibles et ne jamais être poussées hors du cadre) ; rangs 3-5 sont des **propositions** (elles
poussent le champ vers le bas quand elles apparaissent) ; rang 6 est l'**ancre** (elle ne bouge
jamais du bas, clavier monté ou non) ; rangs 7-8 sont des **accessoires** (ils suivent l'ancre).

**Règle AD-4, rang par rang** : un créneau `null` — ou un builder rendant `null` — est **absent de
l'arbre**, jamais un `SizedBox.shrink()`. Un hôte passif d'aujourd'hui obtient donc exactement
`[capture, Row, tools]` : l'arbre inchangé, au widget près.

### 2.4 Ce que le clavier fait

Le rang 6 est l'ancre ; l'insets du clavier reste géré par l'hôte (`ZChatNotebookScreen` le fait
déjà). Contrainte imposée à **tout rang neuf** : hauteur `min`, jamais fixe, et débordement
scrollable **à l'intérieur du rang** (rang 4 en horizontal — `ZChatAttachmentStrip` l'est déjà).

---

## 3. Le contrat de créneaux

### 3.1 Sur `ZChatComposer` — cinq créneaux existants, cinq ajoutés

| Créneau | Rang | État | Ce qu'il reçoit |
|---|---|---|---|
| `status` | 0 | **neuf** | `ZChatComposerSlot` |
| `editingBanner` | 1 | **neuf** *(la pièce existe ; aujourd'hui elle est empilée dans `capture` par `ZDefaultChatComposer:_captureSlot` `z_default_chat_composer.dart:374-395` — un rang emprunté)* | `ZChatComposerSlot` |
| `progress` | 2 | **neuf** | `ZChatComposerSlot` |
| `suggestions` | 3 | **neuf** | `ZChatComposerSlot` |
| `attachments` | 4 | **neuf** | `ZChatComposerSlot` |
| `capture` | 5 | ✅ `z_chat_composer.dart:182` | `ZChatComposerSlot` |
| `leading` | 6 | ✅ `:170` | `ZChatComposerSlot` |
| `hint` | 6 | ✅ `:199` | `ZChatComposerSlot` |
| `trailing` | 6 | ✅ `:175` | `ZChatComposerSlot` |
| `tools` | 7 | ✅ `:179` | `ZChatComposerSlot` |
| `counter` | 8 | **neuf** | `ZChatComposerSlot` |

**Séparer `editingBanner` de `capture` est une correction, pas un ajout** : aujourd'hui deux
mécanismes sans rapport (le bandeau d'édition et la dictée) partagent un rang. Migration additive :
`capture` conserve son comportement ; `editingBanner`, quand il est fourni, prend le rang 1 et
`ZDefaultChatComposer` cesse d'empiler.

### 3.2 `ZChatComposerSlot` — additif, comme son dartdoc le promet

Le type porte aujourd'hui `controller`, `submit`, `settings` (`z_chat_composer.dart:91-124`) et son
dartdoc annonce explicitement l'ajout de champs (`:82-89`). On y ajoute, **sans changer la signature
de `ZChatComposerSlotBuilder`** :

| Champ | Type | Pourquoi |
|---|---|---|
| `attachments` | `ZChatAttachmentController?` | le rang 4 et le menu `+` lisent la même instance — jamais deux |
| `tools` | `ZChatToolController?` | la bande et la feuille lisent le même catalogue (`z_chat_tool_controller.dart:107`) |
| `capture` | `ZChatCaptureController?` | dictée/OCR : un seul écrivain de la saisie |
| `compact` | `bool` | résolu **une fois** contre `ZChatComposerChromeStyle.mobileBreakpoint` — aujourd'hui chaque pièce refait un `LayoutBuilder` |
| `sendState` | `ZChatComposerSendState` | `idle` / `busy` / `streaming` / `editing` — décide du glyphe (B4) |

### 3.3 Le relais par les surfaces notebook — la CR se trompe de cible

Mesuré : **`ZChatNotebookView` ne câble rien** — c'est un relais pur de `Widget? composer`
(`z_chat_notebook_view.dart:149`, passé `:170`). Les paramètres que la CR dit perdus
(`pickers`, `settingsController`, `modelOptions`, `activeModelId`, `onModelSelected`) vivent sur
**`ZChatNotebookScreen`** (`z_chat_notebook_screen.dart:610-640`).

⇒ Deux conséquences, et elles réduisent le travail :

1. Un hôte de `ZChatNotebookView` **ne perd rien** : il passe `composer: ZDefaultChatComposer(...)`
   et dispose de la cinquantaine de paramètres de l'assemblé. Rien à changer sur la vue.
   *(Grep : `grep -n "pickers\|modelOptions\|settingsController" z_chat_notebook_view.dart` ⇒ **0**.)*
2. Le vrai manque est sur **`ZChatNotebookScreen`** : `composerBuilder` est **tout-ou-rien**
   (`:330`, appelé `:605-606`). Un hôte qui veut styliser une seule pièce doit tout reconstruire —
   et reperd le câblage `toolsBadge`/routeur que l'écran fait pour lui (`:626-640`).

**Contrat** : un unique porteur `ZChatComposerSlots` (objet à champs nullables, un par créneau et
par builder de pièce), passé **tel quel** de l'écran à `ZDefaultChatComposer`. `null` ⇒ défauts de
l'écran, à l'octet près. `composerBuilder` reste l'échappatoire totale et **prime** ; en debug, une
assertion refuse `composerBuilder != null && composerSlots != null` (deux intentions
contradictoires, silencieusement gagnées par l'une d'elles).

---

## 4. Le vocabulaire neuf — nom, forme, paquet

| Nom | Forme | Paquet | Pourquoi ce paquet |
|---|---|---|---|
| `chatComposerFill`, `chatComposerBorderColor`, `chatComposerBorderWidth`, `chatComposerRadius` | 4 jetons `Color?`/`double?`/`Radius?` sur `ZcrudTheme` | **`zcrud_core`** | un jeton de thème est un rôle, pas un widget ; `ZChatComposerSurface:222` réserve déjà l'emplacement en commentaire |
| `ZChatComposerSendAlignment` | `enum { bottom, center }` | **`zcrud_chat`** | pure disposition |
| `ZChatComposerBandPlacement` | `enum { below, above }` | **`zcrud_chat`** | pure disposition |
| `ZChatComposerSendState` | `enum { idle, busy, streaming, editing }` | **`zcrud_chat`** | état de **rendu**, dérivé de tranches existantes ; rien à persister |
| `ZChatComposerToolChip` | widget : glyphe + libellé escamotable + badge + accent actif | **`zcrud_chat`** | la puce commune à Lex/ChatGPT/Claude ; piloté par un `ZChatToolEntry` du catalogue |
| `ZChatComposerCycleChip` | widget : puce dont le tap **avance** un `ZChatCycleState` (0→n) | **`zcrud_chat`** | D2. Le domaine (`ZChatCycleState` `…/tools/z_chat_tool_state.dart:212`) et le verbe (`ZChatToolController.advance` `…/tools/z_chat_tool_controller.dart:183`) existent **déjà** : il ne manque que la pièce |
| `ZChatComposerStatusBand` | widget + `ZChatComposerStatus` (`@immutable` : `severity`, `messageKey`, `action?`) | **`zcrud_chat`** | rendu ; la **donnée** (quota, échec) vient de tranches déjà portées |
| `ZChatComposerSuggestionsBand` | widget rendant `List<ZChatSuggestion>` | **`zcrud_chat`** | `ZChatSuggestion` est déjà dans le noyau (`…/z_chat_suggestion.dart:101`) |
| `ZChatSuggestionsView` | `ValueListenable<List<ZChatSuggestion>>` **agrégée par conversation** sur `ZChatController` | **`zcrud_chat`** | aujourd'hui la tranche est **par requête** (`progress(requestId).suggestions`) : un composer n'a pas le `requestId` |
| `ZChatComposerCounter` + `ZChatTextMeasurePort` | widget + **port** `int measure(String)` | **`zcrud_chat`** (widget) / **`zcrud_chat_kernel`** (port) | A7. Le socle **ne compte pas les jetons** : il affiche ce qu'un port lui rend (§5) |
| `ZChatMentionTrigger`, `ZChatMentionCandidate`, `ZChatMentionSource` | types + **port** de candidats | **`zcrud_chat_kernel`** | G1. C'est un contrat de données (id, libellé, type, charge utile), pas un widget |
| `ZChatSlashCommand`, `ZChatSlashCatalog` | types déclaratifs | **`zcrud_chat_kernel`** | G2. Même raison ; le catalogue doit être sérialisable (servi par le backend, cf. décision « transport PAR ROUTE ») |
| `ZChatComposerAffordanceOverlay` | widget : le panneau de candidats (mentions **et** slash — un seul) | **`zcrud_chat`** | deux panneaux jumeaux divergeraient |
| `ZChatComposerPastePort` | **port** `Future<ZResult<ZPendingAttachment?>> readImage()` | **`zcrud_chat`** (à côté des ports de pièces jointes) | A4. `Clipboard` d'image n'est pas dans `flutter/services` sans plugin ⇒ **jamais** de dépendance dans le socle |
| `ZChatComposerDropZone` | widget enveloppant, `onFiles` | **`zcrud_chat`** | A5. Le socle expose la **zone** et le callback ; le plugin de glisser-déposer reste chez l'hôte |
| `ZChatVoiceSessionController` | `ChangeNotifier` : écouter → transcrire → soumettre → énoncer → réécouter | **`zcrud_chat`** | F2. Les deux ports existent (`ZChatDictationPort.listen` `…/capture/z_chat_capture_port.dart:276`, `ZChatSpeechPort.speak` `…/diffusion/z_chat_speech_port.dart:158`) ; **la boucle** manque |
| `ZChatAttachmentRejection.{fileInaccessible, cameraError, galleryError}` | 3 valeurs **en queue** d'enum | **`zcrud_chat`** (`…/attachment/z_chat_attachment_failure.dart:30`) | C4 ; `pickFailed` reste le repli |
| `ZChatModelOption.{descriptionKey, description, badge}` | 3 champs additifs | **`zcrud_chat`** (`…/view/z_chat_composer_model_selector.dart:55`) | E2 |
| `ZChatDraftStore` | **port** `read(conversationId)` / `write(conversationId, ZChatDraft)` | **`zcrud_chat_kernel`** | J1 ; la persistance est une décision d'hôte |

---

## 5. Ce qui NE doit PAS être fait

| # | Interdit | Pourquoi |
|---|---|---|
| 1 | **Compter les jetons dans le socle** | le comptage dépend du tokenizer du modèle, donc du fournisseur. Un compteur maison serait **faux** et le resterait silencieusement. ⇒ `ZChatTextMeasurePort`, et un compteur qui **n'affiche rien** sans port (AD-4). |
| 2 | **Décider d'une politique de quota** | bloquer l'envoi à `remaining == 0`, proposer un achat, dégrader le modèle : ce sont des décisions commerciales. Le socle **rend** un `ZChatQuotaSnapshot` et expose un `action` opaque ; il ne refuse jamais un envoi de son propre chef. |
| 3 | **Demander une permission micro/caméra** | `ZChatDictationPort.isAvailable()` (`…/capture/z_chat_capture_port.dart:266`) est le seul contrat. Le socle **consulte**, il ne demande pas, et il n'ajoute aucun plugin de permission. |
| 4 | **Détecter le hors-ligne** | aucune sonde réseau dans le socle (`zcrud_core` ne dépend de rien de lourd, AD-1). Le hors-ligne entre comme `ValueListenable<bool>` fourni par l'hôte. |
| 5 | **Implémenter le presse-papier d'images ou le glisser-déposer** | les deux exigent un plugin (`super_clipboard`, `desktop_drop`). ⇒ **ports + créneau**, l'implémentation vit chez l'hôte ou dans un satellite futur. Aucune dépendance nouvelle dans `zcrud_chat`, aucune dans `zcrud_core`. |
| 6 | **Remplacer `EditableText` par `TextField`** | §2.1. Cela rendrait la boîte, le padding et la ligne de base à `InputDecorator`, et changerait l'arbre d'un hôte passif. |
| 7 | **Introduire `ZChatComposerLayout.adjacent/inline`** | §2.2 : ce serait nommer « mode » un alignement, et doubler l'arbre et les gardes pour un enum de deux valeurs. |
| 8 | **Changer un défaut** — glyphe, couleur, rang, `clipBehavior`, `Clip.antiAlias` | tout rang neuf naît `null`. `ZChatComposerSurface.clipBehavior` reste `Clip.none` (`z_chat_composer_band.dart:193`) même si Lex utilise `Clip.antiAlias` : c'est **l'hôte** qui le demande. |
| 9 | **Exécuter une commande slash dans le socle** | le socle **reconnaît** le déclencheur et **rend** le panneau ; l'exécution est un `ZChatSlashCommand` remis à l'hôte. Sinon le socle devient un interpréteur. |
| 10 | **Résoudre les candidats de mention dans le socle** | fichiers, agents, connecteurs : ce sont des données d'hôte. Port `ZChatMentionSource`, jamais un annuaire. |
| 11 | **Faire du `ZChatComposerToolChip` un `ChoiceChip` Material** | `zcrud_chat` ne peut pas imposer un design system. La puce est un widget **nu** stylé par jetons + créneaux (le socle ne peint ni icône ni couleur — cf. `ZChatComposerSendTarget`, `z_chat_composer_chrome.dart:276-281`). |
| 12 | **Persister un brouillon** | port `ZChatDraftStore`, jamais Hive ni `shared_preferences` dans `zcrud_chat`. |
| 13 | **Recopier `ProactiveSuggestionsBar` telle quelle** | Lex la monte **hors** du champ mais **dans** la boîte (`chat_input.dart:513`). Le socle doit offrir le **rang**, pas le style de Lex. |

---

## 6. La décomposition en lots

**Règle du dépôt** : un seul rédacteur par paquet, scratchpads distincts, `.dart_tool/package_config`
partagé ⇒ aucune mesure d'un paquet pendant qu'un agent y écrit. `zcrud_chat` est le goulot : il est
découpé en **six lots séquentiels** de taille tenable (aucun ne dépasse ~2 fichiers de rédaction
lourde + leurs gardes).

### 6.1 Vague 1 — parallèle (paquets disjoints)

| Lot | Paquet | Livre | Dépend de |
|---|---|---|---|
| **L1** | `zcrud_core` | les 4 jetons de cadre (`chatComposerFill`, `chatComposerBorderColor`, `chatComposerBorderWidth`, `chatComposerRadius`) : champs, `copyWith`, `lerp` (`_lerpNullableFloor`/`Color.lerp`, patron `z_theme.dart:4022-4062`), dartdoc consommateur, garde de `lerp` et garde de non-régression du défaut `null` | — |
| **L2** | `zcrud_chat_kernel` | `ZChatMentionCandidate` / `ZChatMentionTrigger` / `ZChatMentionSource` ; `ZChatSlashCommand` / `ZChatSlashCatalog` (sérialisables, `fromJsonSafe`, AD-10) ; `ZChatTextMeasurePort` ; `ZChatDraftStore`. **Tous à `extra` concret ⇒ `zSanitizeExtra` + `_reservedKeys` consommant `ZSyncMeta.reservedKeys`** (gate `reserved-keys`, AD-19.1). Gardes de source lisant le disque ⇒ **`@TestOn('vm')`** (gate `web`) | — |

⚠️ L1 et L2 sont disjoints. **Ne pas** lancer un lot `zcrud_chat` en même temps : `zcrud_chat`
dépend des deux et une mesure y serait fausse.

### 6.2 Vague 2 — `zcrud_chat`, six lots STRICTEMENT séquentiels

| Lot | Livre | Fichiers principaux | Dépend de |
|---|---|---|---|
| **L3 — les rangs** | les 5 créneaux neufs (`status`, `editingBanner`, `progress`, `suggestions`, `attachments`, `counter`) sur `ZChatComposer` ; `ZChatComposerSendAlignment` ; `ZChatComposerBandPlacement` ; champs additifs sur `ZChatComposerSlot`. **Aucun rendu neuf** — que des créneaux et l'ordre | `z_chat_composer.dart` | L1 |
| **L4 — le cadre + les pièces d'état** | branchement des 4 jetons dans `zChatComposerChromeOf` et `ZChatComposerSurface` ; `ZChatComposerStatusBand` ; `ZChatComposerSendState` + glyphes par état (B4) | `z_chat_composer_chrome.dart`, `z_chat_composer_band.dart` | L1, L3 |
| **L5 — pièces jointes de bout en bout** | 3 codes de rejet en queue (C4) ; `ValueListenable<bool> uploading` sur `ZChatAttachmentController` (C7) ; montage de `ZChatAttachmentStrip` au rang 4 et de la progression au rang 2 par `ZDefaultChatComposer` (C6) ; geste OCR sur une vignette | `attachment/*`, `z_chat_attachment_strip.dart`, `z_default_chat_composer.dart` | L3, L4 |
| **L6 — suggestions & brouillon** | `ZChatSuggestionsView` (agrégat par conversation sur `ZChatController`) ; `ZChatComposerSuggestionsBand` au rang 3 ; indicateur et restauration de brouillon, câblé sur `ZChatDraftStore` | `z_chat_controller.dart`, `z_chat_composer_band.dart` | L2, L3 |
| **L7 — vocabulaire d'outils** | `ZChatComposerToolChip` (piloté par `ZChatToolEntry`) ; `ZChatComposerCycleChip` (D2, sur `advance`) ; `ZChatModelOption.description*`/`badge` (E2) ; migration **facultative** des 3 bascules existantes vers la puce commune, **sans changer leur rendu** | `z_chat_composer_band.dart`, `z_chat_composer_model_selector.dart` | L3, L4 |
| **L8 — gestes & contexte** | `ZChatComposerPastePort` (A4) ; `ZChatComposerDropZone` (A5) ; rappel d'historique sur flèche haut (A6) ; `ZChatComposerCounter` (A7) ; `ZChatComposerAffordanceOverlay` + reconnaissance des déclencheurs `@` et `/` (G1, G2) | `z_chat_composer.dart`, fichiers neufs | L2, L3 |
| **L9 — mode vocal continu** | `ZChatVoiceSessionController` (boucle dictée ↔ énoncé), état exposé au composer, arrêt sur toute frappe | `capture/`, `diffusion/` | L3, L8 |
| **L10 — relais notebook** | `ZChatComposerSlots` ; passage écran → `ZDefaultChatComposer` ; assertion `composerBuilder` ⊕ `composerSlots` | `z_chat_notebook_screen.dart`, `z_chat_conversation_screen.dart` | L3…L7 |

### 6.3 Ce qui peut tourner en parallèle, et ce qui ne peut pas

* **Parallèle** : L1 ∥ L2 (paquets disjoints). C'est la seule parallélisation sûre.
* **Séquentiel obligatoire** : L3 → L4 → {L5, L6, L7} → L8 → L9 → L10. L5/L6/L7 touchent tous
  `z_chat_composer_band.dart` ou `z_default_chat_composer.dart` : **un seul rédacteur à la fois**
  dans `zcrud_chat`, sans exception.
* **Ordre de valeur** : L3+L4+L5 suffisent déjà à rendre `chat_input.dart` de Lex supprimable pour
  l'essentiel ; L6/L7 comblent le reste du critère d'acceptation ; L8/L9 servent le mandat au-delà
  de la CR (aucun hôte connu ne les emploie aujourd'hui).

### 6.4 Le critère d'acceptation, lot par lot

| Ce que Lex a | Couvert par |
|---|---|
| Container 12 dp + filet | L1 + L4 |
| bandeau d'édition (rang 1) | ✅ livré + L3 (rang propre) |
| progression d'upload (rang 2) | L5 |
| suggestions proactives (rang 3) | L6 |
| aperçu des pièces (rang 4) | L5 |
| envoi/STOP/spinner en `suffixIcon` | ✅ livré + L3 (`SendAlignment.center`) + L4 (B4) |
| toolbar en `helper` | ✅ livré (créneau `tools`) |
| chip Réfléchir 0→5 | L7 |
| chip Internet, bouton Outils + badge | ✅ livré |
| micro conditionné par `isAvailable` | L5 |
| `EffortChips` | ✅ livré (`ZChatComposerEffortSelector`) |
| placeholder animé | ✅ livré |
| raccourcis Entrée / Ctrl+Entrée | ✅ livré |
| badge OCR sur vignette | L5 |

---

## 7. Les invariants, rappelés par lot

À recopier **dans chaque brief de sous-agent**, sans exception :

1. **Additif — `null` ⇒ arbre inchangé** (AD-4). Un créneau nul, ou un builder rendant `null`, est
   **absent de l'arbre**, jamais un `SizedBox.shrink()`. Une garde par rang neuf doit **rougir par
   assertion** si le rang apparaît sans être demandé (discipline R3 : rouge par assertion,
   restauration par copie, sha avant/après, résidus par grep négatif montré).
2. **Aucun défaut changé sans décision explicite** : ni glyphe, ni couleur, ni rang, ni
   `clipBehavior`. La comparaison de référence est l'arbre d'un hôte passif **au widget près**.
3. **Rebuilds granulaires** (AD-2) : une pièce n'écoute que **sa** tranche. Interdits : `setState`
   à l'échelle du composer, controller recréé dans un `build`, abonnement d'un rang au canal de
   frappe. Le seul abonnement à `composer` reste `_ZChatComposerHint` (`z_chat_composer.dart:474`).
4. **AD-13** : cibles ≥ `kZChatMinTapTarget`, `Semantics` explicite par pièce, variantes
   **directionnelles** partout (`EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`),
   région live pour tout état annoncé (statut, dictée, quota).
5. **FR-26** : aucune couleur ni aucun libellé codé en dur. Les valeurs de référence entrent
   **uniquement** par `ZChatComposerReference` (`…/view/z_chat_composer_reference.dart`), exempté
   nominativement par la garde anti-couleurs. Résolution **paramètre > jeton > référence**
   (`z_chat_composer_chrome.dart:212`). Les libellés passent par `zChatLabel`.
6. **AD-1** : aucune dépendance nouvelle dans `zcrud_core` **ni** dans `zcrud_chat`. Presse-papier
   d'images, glisser-déposer, permissions, comptage de jetons, persistance : **ports**, jamais
   d'implémentations.
7. **AD-10** : aucun chemin d'exception. Un port absent ⇒ la pièce est absente, jamais une levée.
   Un paramètre absurde est écrêté (patron `borderWidth.clamp(0, ∞)`, `z_chat_composer_chrome.dart:240`).
8. **Gates** : `reserved-keys` (AD-19.1) — tout type neuf du noyau à `extra` concret filtre par
   `zSanitizeExtra`/`zNormalizeExtra` avec un `_reservedKeys` **consommant** `ZSyncMeta.reservedKeys` ;
   `web` — toute garde lisant le disque (`dart:io`) porte **`@TestOn('vm')`** en tête de fichier
   (`zcrud_chat_kernel` compile vers Node).
9. **Gardes jumelles** : tout contrat changé se cherche dans les **autres** paquets
   (`grep -rn "<TypeChangé>" packages/*/test`).
10. **Dartdoc = documentation publiée** : aucun numéro de CR, aucune version, aucun récit de lot dans
    un `///`. La justification va en `//` dans le corps, dans les tests, ou au CHANGELOG.
11. **Vérif** : `melos run generate` → `analyze` → `flutter test` **depuis le dossier du paquet**,
    rejouée par l'orchestrateur ; **tous** les paquets balayés avant tag (gardes inter-paquets).
