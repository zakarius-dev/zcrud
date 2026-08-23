# Handoff v3.6.0 — le composer, sa feuille d'outils, et les deux contrôleurs

> **Date** : 2026-08-23. **Portée** : `zcrud_chat_kernel`, `zcrud_chat`, `zcrud_chat_material`,
> plus six corrections d'octets de contrôle dans `zcrud_firestore`, `zcrud_study_kernel`,
> `zcrud_study`, et une garde inter-paquets dans `zcrud_core`.
> **Traite** : CR-IFFD-87 (composer et feuille), la demande du propriétaire sur les contrôleurs
> de chat et de Notebook, et la moitié non traitée de CR-IFFD-72 (« le Notebook complet,
> portable ailleurs qu'à IFFD »).

---

## 1. D'où vient cette version — le relevé des quatre références

Le propriétaire a demandé que le composer du socle « rassemble le meilleur » de lex_douane et
d'IFFD legacy. Le relevé a porté sur **quatre** applications, la quatrième étant celle que
CR-IFFD-76 déclarait « non mesurée » :

| Référence | Où vit le composer | Taille |
|---|---|---|
| lex_douane | `lex_ui/…/chat/chat_input.dart` + `tools_sheet.dart` | 1 231 l. + 652 l. |
| IFFD legacy | noyé dans `chatbot_conversation_screen.dart` | 5 180 l. (composer : `:2521-3437`) |
| DODLP | noyé dans `ai_conversation_screen.dart` | 2 103 l. |
| DLCFTI | noyé dans `chat_screen.dart` | 1 658 l. |

**Règle d'arbitrage retenue** (celle de CR-IFFD-76, confirmée par CR-IFFD-87) : *pièce par pièce,
jamais application par application* ; et *ce que deux applications développées séparément font
pareil est un défaut évident*.

### Ce qui a été repris, et de qui

| Pièce | Source | Livrée par |
|---|---|---|
| Entrée = envoyer (bureau/Web), Maj+Entrée et Ctrl+Entrée = nouvelle ligne | **arbitrage socle** — les deux références font l'inverse mais partagent un auteur | lot A |
| Badge agrégé sur « Outils » ; en compact, le badge **remplace** le libellé | les deux + `discovry_search_composer` | lot A |
| Libellés qui s'effacent sous le seuil, badges conservés | les deux | lot A |
| `AnimatedScale` du bouton d'envoi | les deux — **existait déjà**, gardé depuis un lot antérieur | — |
| Sous-titre qui décrit l'**état** (« Niveau : Équilibré »), pas la fonction | lex | lots B/C |
| Révélation conditionnelle (réglage fin visible si la bascule est active) | lex | lots B/C |
| Entrée grisée **avec sa raison**, jamais masquée | lex (catalogue) + principe | lots B/C |
| Exclusions déclaratives (« joindre un document masque Outils ») | IFFD legacy — codé en dur, ici **déclaré** | lot B |
| Cycle de réflexion 0→…→N→0 en un tap, badge numérique | les deux | lots B/C |
| En-tête **« Actifs »** + « Réinitialiser » | **ajout socle** — absent des quatre | lots B/C |
| Recherche dans la feuille au-delà d'un seuil de sections | **ajout socle** — absent des quatre | lots B/C |
| Annulation qui **conserve le partiel** et notifie le port | **déjà le meilleur des cinq** ; garanti et gardé | lot E |
| Édition d'un message envoyé avec aperçu d'impact **calculé par le contrôleur** | lex (calcul dans l'écran : mauvais placement) | lot E |
| Régénération sans enum de variantes (transformation déclarée par l'hôte) | refus de l'enum fermé de lex (14 valeurs) | lot E |
| Annonces d'accessibilité à repli **silencieux** | plus strict que les quatre | lot E |

### Ce qui n'a PAS été repris, et pourquoi

- La **feuille d'outils de lex** comme mécanique : `ListView.builder` à `itemCount: 9` et `switch`
  sur index magiques (`tools_sheet.dart:90-126`). Bonne pour lex, inextensible par un hôte.
  Ses **sections** ont été reprises ; son assemblage a été remplacé par une feuille **déclarée**.
- Le `ref.watch` global de lex (`chat_screen.dart:162`, deux `.select` pour 2 218 lignes) : chaque
  token reçu reconstruit l'écran entier. C'est le bug historique du formulaire, transposé au chat.
- L'annulation de DODLP (supprime le message, laisse tourner l'appel réseau) et celle de lex
  (perd le partiel). Seul DLCFTI coupait la requête (`CancelToken`).
- Les échecs aplatis en `String` (lex), la logique métier douanière, les paliers freemium,
  « Obtenir le prompt » (DLCFTI — original mais métier).

---

## 2. Ce qui change pour un hôte

### 🔴 Hôte ayant COMPENSÉ — à retirer, sinon le correctif s'additionne à la compensation

| Compensation hôte | Effet si elle reste | Remède |
|---|---|---|
| Ses propres `Shortcuts` « Entrée = envoi » (le chemin clavier du socle était **mort** : `onSubmitted` sous `maxLines: 5`) | **double envoi** par frappe | retirer, ou `submitPolicy: ZChatComposerSubmitPolicy.disabled` |
| Un comptage d'outils tenu à côté du déclencheur | **deux badges** | retirer ; `ZDefaultChatComposer(showToolsBadge: false)` si nécessaire |
| Une feuille d'outils bâtie sur un `switch` d'index | doublon de la feuille déclarée | migrer vers `ZChatToolCatalog` |
| Recherche d'un message partiel par `requestId` | ne le trouve plus | la réponse sans identité serveur porte `<requestId>/reply` |
| Calcul d'impact d'édition dans l'écran, balayages du fil à la main | doublon | `previewEditImpact`, `messageById`, `replyToOf`, `contentOf` |
| Notebook IFFD : les trois `Set` d'occupation, le `setState` de page, le reparse des comptes, `iffdConfirmNoDestructiveAction` | double notification, **double question** de confirmation | retirer ; brancher `confirmArtifactVerb` **ou** la confirmation en place, jamais les deux |
| Notebook IFFD : les deux ouvreurs SSE (`notebook_stream_opener_iffd`, `notebook_byte_opener_iffd`, 318 l.) | `data: ` retiré deux fois, annulation doublée | retirer ; `ZChatSseStreamPort(open:, decode:, onClose:)` |

### Hôte PASSIF — changements de défaut visibles

1. Badge de comptage sur le déclencheur d'outils (`showToolsBadge: true`).
2. Sous le seuil compact, « Outils » se réduit au badge dès que le compte est non nul.
3. Entrée envoie sur bureau et Web.
4. 4 dp d'écart avant la cible de retrait d'une pièce jointe (cible portée à 48 dp).
5. L'identifiant du message partiel devient `<requestId>/reply`.
6. Le même texte annoncé deux fois notifie deux fois (dédoublonnage des annonces identiques consécutives).

Tout le reste est additif.

### Tripwire recommandé

Sur chaque défaut amont que vous aviez contourné, gardez un test qui **affirme la perte** : il rougit
quand l'amont corrige et désigne le doublon. Pour cette version : un test qui affirme « Entrée
insère une ligne » (rougit désormais sur bureau), un test qui compte **un** badge d'outils.

---

## 3. Ce que le socle absorbe du Notebook IFFD

Mesuré avant : **4 921 lignes** sous `iffd/lib/ai_assistant/zcrud/` (2 091 de code, 2 505 de
commentaire) + 307 l. d'actions + 250 l. au site d'appel = **5 478**. Ventilation : 43 % de
mécanique pure (A), 31 % d'assemblage paramétré (C), 26 % irréductiblement hôte (B).

- `ZChatNotebookController` (lot F) : ≈ **1 370 l.** rendues inutiles.
- `ZChatSseStreamPort` + `zChatSseLines` (lot G1) : **318 l.** → ~25 l. de branchement.
- `ZChatNotebookScreen` (lot G2) : **~200 l.** d'assemblage retirables (la classe `NotebookZcrudView` disparaît ; le relais de `folder_explanation_page` tombe à ~40 l.) + ~430 l. de commentaires sans objet. Les ~95 l. de rappels restent des verbes d'hôte : un `ZChatActionExecutor` + un `ZChatArtifactVerbConfirm`. **Exemple minimal IFFD : 34 lignes** (§3 bis).

Reste hôte, et doit le rester : le catalogue des neuf artefacts, glyphes, couleurs, libellés,

### 3 bis. L'exemple minimal — ce qu'IFFD écrirait désormais (34 lignes)

```dart
ZChatRendererScope(                                                   // 1
  renderer: ZChatMarkdownRenderer(styleSet: iffdMarkdownStyleSet()),  // 2
  child: ZChatNotebookScreen(                                          // 3
    streamPort: iffdNotebookStreamPort(openPost: aiRepository.openRawByteStream), // 4
    transcript: IffdTranscriptPort(chatbot.messageRepository),         // 5
    conversationId: conversationId,                                    // 6
    cursorColor: Theme.of(context).colorScheme.primary,                // 7
    registry: iffdArtifactRegistry,                                    // 8  (déclaration pure, partagée)
    generationPort: IffdArtifactGenerationPort(aiRepository),          // 9
    store: IffdArtifactStore(chatbot.messageRepository),               // 10
    actionExecutor: IffdNotebookActionExecutor(context),               // 11 (ouvrir, modifier, imprimer, partager)
    confirm: (plan) => buildConfirmDialog(context, message: iffdConfirmText(plan)),       // 12
    confirmArtifactVerb: (v) => buildConfirmDialog(context, message: iffdConfirmText(v)), // 13
    resolvers: ZChatArtifactResolvers(                                 // 14
      icon: IffdNotebookIcons.of, label: iffdL10n.of, accent: iffdAccents.of), // 15
    liveLabels: iffdChatLiveLabels(context),                           // 16
    skin: const ZChatNotebookSkin(showTimestamp: false,                // 17
      tile: ZChatTileShell(topicOf: zChatPrecedingRequestTopic, topicMaxLines: 1)), // 18
    artifactMenuBuilder: buildIffdArtifactPopupMenu,                   // 19
    actionsBuilder: buildIffdSaveAsNote,                               // 20
    composerBorderColor: Theme.of(context).colorScheme.outlineVariant, // 21
    hints: kIffdNotebookHints,                                         // 22
    pickers: iffdPickers(context, folder),                             // 23
    modelOptions: modelOptions, modelActiveId: defaultModelId,         // 24
    onSelectModel: defaultDiscovryPageController.setAiRouterId,        // 25
    presentTools: (ctx, sheet) => showModalBottomSheet<void>(          // 26
      context: ctx, isScrollControlled: true, showDragHandle: true, builder: sheet), // 27
    onCloseTools: () => Navigator.of(context).pop(),                   // 28
    failureBuilder: (ctx, f) => IffdFailureBanner(f),                  // 29
    artifactFailureBuilder: (ctx, m, k, f) => IffdFailureBanner(f),    // 30
    headerBuilder: (ctx, nb) => IffdExportThreadButton(nb),            // 31 (export du fil — à l'hôte)
    readOnly: !droits.peutEcrire,                                      // 32
  ),                                                                   // 33
)                                                                      // 34
```


Contre 984 + 926 lignes dans les deux fichiers `*_zcrud.dart` actuels (870 de code). L'exécuteur, le port de
transcript et le stockage d'artefact sont des adaptateurs de **domaine** qu'IFFD écrit une fois, sans
aucun assemblage d'écran.
prompts, corpus, endpoint et ouverture authentifiée du POST, persistance, drapeau de migration.

---

## 4. Défauts trouvés en chemin (hors CR)

| Défaut | Où | Correction |
|---|---|---|
| Chemin d'envoi clavier mort (`onSubmitted` jamais atteint sous `maxLines > 1`) | `z_chat_composer.dart:389` | lot A |
| Cibles < 48 dp **avouées** dans la référence et non corrigées | `z_chat_composer_reference.dart:149,183` | lot A |
| Question optimiste et réponse partielle partageaient un identifiant | `z_chat_controller.dart` | lot E |
| `zChatTranscriptOrEmpty` propageait `cancel` avec un événement de retard (l'écouteur distant survivait au `dispose`) | kernel, lot D | lot G1 |
| **Six octets NUL bruts** dans des littéraux Dart (dont une dartdoc) : `grep` sans `-a` voit un binaire, `git diff` aussi | `zcrud_chat_kernel` ×3, `zcrud_firestore`, `zcrud_study_kernel`, `zcrud_study` | remplacés par ` ` ; garde inter-paquets dans `zcrud_core` |
| Trois types neufs à `extra` concret (`ZChatArtifactDeclaration`, `ZChatArtifactGenerationRequest`, `ZChatToolEntry`) réémettaient `extra` **sans filtrer** les clés réservées de synchronisation : `updated_at` glissée dans `extra` aurait faussé le merge Last-Write-Wins | `zcrud_chat_kernel`, lots B/D | filtre `zSanitizeExtra`/`zNormalizeExtra` + `_reservedKeys` consommant `ZSyncMeta.reservedKeys` (attrapé par la gate `reserved-keys`, AD-19.1) |
| Un test qui laissait un flux ouvert faisait durer le run de `zcrud_chat` **10 min** (13 s au repos) | lot F | `dispose` du transcript en teardown, `pumpEventQueue` banni sous `testWidgets` |

---

## 5. Vérification

Rejouée par l'orchestrateur, workstreams au repos, depuis le dossier de chaque paquet :

- `melos run generate` : **0 `.g.dart` modifié**.
- `melos run analyze` repo-wide : 4 `info` dans `example/` (non touché), **0 erreur**.
- `melos run verify` : **RC=0**, les douze gates vertes — dont `web` (déterminisme sous Node) et `reserved-keys` (AD-19.1), qui ont chacune attrapé un défaut réel de cette livraison avant publication (§4).
- Balayage des **40 paquets** : 39 verts ; `zcrud_generator` rouge **environnemental** (`Unsupported operation: Isolate.packageConfig` via `build_test`, 25 occurrences, identique aux versions précédentes).
- Après la dernière correction : `zcrud_chat_kernel` **541**, `zcrud_chat` **788** (13 s), `zcrud_chat_material` **72**, `zcrud_core` **2 376**.

Comptes mesurés par l'orchestrateur pendant le chantier : `zcrud_chat_kernel` 411 → 461 → 498 → 535 → 541 ;
`zcrud_chat` 673 → 694 → 719 → 745 → 772 → 788 ; `zcrud_chat_material` 47 → 72.
Campagnes R3 : A 7 · B 14 · C 15 · D 16 · E 11 · F 13 · G1 12 · G2 10 · garde NUL 1 · AD-19.1 5 — **104 injections, 104 rouges par
assertion**, restauration par copie, empreintes identiques.

## 6. Ouvert

- CR-IFFD-72 : ce handoff en est la réponse formelle pour la moitié « contrôleur » ; l'hôte dira
  si l'écran assemblé suffit.
- `ZChatCommandState` sans verbe natif (le rendu exige `onCommand`) — choix assumé.
- La marque « interrompu » d'un message n'est pas persistable sur `ZChatMessage` (vit dans la
  session du contrôleur).
- 🔴 CI GitHub Actions toujours morte (facturation) : la vérification locale est la seule défense.
