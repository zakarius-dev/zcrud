---
title: zcrud_chat
description: Contrôleur de conversation IA Flutter-natif — état réactif granulaire, composer par défaut, Notebook et conversation persistée, routage par tâche côté écran.
---

# zcrud_chat

## Rôle

`zcrud_chat` est le paquet **satellite Flutter** de la capacité chat : il
porte l'**état réactif** — `ZChatController`, un `ChangeNotifier` pur
Flutter exposant des tranches `ValueListenable` granulaires (composer,
messages, texte en cours par requête, progression, échec typé) — sur le
domaine pur exposé par `zcrud_chat_kernel` (modèle, contrat d'action, ports
IA). Il fournit aussi le rendu par défaut d'une conversation, un composer
complet, une feuille de réglages et une feuille d'outils composables, deux
écrans assemblés (conversation et Notebook), la gestion des pièces jointes,
l'export agrégé et une liste de conversations, sans aucune dépendance
tierce (ni Markdown, ni Syncfusion, ni gestionnaire d'état).

## Quand l'utiliser

- Pour construire un **écran de conversation** Flutter — envoi, streaming,
  annulation, régénération, édition — sans reconstruire la logique de
  contrôleur ni risquer le rafraîchissement global du formulaire à chaque
  frappe (invariant [AD-2](../concepts/invariants.md#ad-2)).
- Pour monter un **Notebook** — un fil dont les réponses portent des
  artefacts générés (carte mentale, flashcards, résumé…) — à partir d'un
  écran assemblé, en ne fournissant que des adaptateurs de domaine.
- Pour assembler un **composer**, une **liste de conversations**, une
  **feuille de réglages** ou une **feuille d'outils** à partir de pièces
  remplaçables individuellement, sans repartir d'un widget monolithique.
- Pour brancher un **rendu riche** (Markdown/LaTeX, grille de données) sur
  une portion de la conversation, via le port `ZChatRenderer`, sans que
  votre build tire une dépendance dont vous n'avez pas besoin.

## Quand ne pas l'utiliser

- Pour traiter des conversations IA **hors Flutter** (migration de données,
  traitement serveur, script) : passez directement par `zcrud_chat_kernel`,
  qui n'importe aucune dépendance Flutter.
- Pour du rendu Markdown/LaTeX ou une coquille Syncfusion AI AssistView : ce
  sont les rôles des satellites dédiés qui dépendent, eux, de ce paquet et
  du kernel.

## Le composer par défaut {#composer}

`ZDefaultChatComposer` assemble le champ de saisie, les pièces jointes, le
déclencheur d'outils et le bouton d'envoi. Trois comportements à connaître :

- **Entrée envoie sur bureau et sur le Web** ; Maj+Entrée et Ctrl+Entrée
  insèrent une nouvelle ligne ; sur une plateforme **tactile**, Entrée
  insère toujours une nouvelle ligne — un clavier virtuel n'a pas de
  modificateur. La convention est **déclarable** :
  `ZChatComposerSubmitPolicy` inverse le sens (`modifierSubmits`), retire
  tout raccourci (`ZChatComposerSubmitPolicy.disabled`) ou étend le
  raccourci au tactile (`desktopAndWebOnly: false`). Le raccourci invoque le
  même site que le bouton d'envoi — jamais un second chemin d'envoi.
- **Un badge agrège les outils actifs** sur le déclencheur « Outils »
  (`showToolsBadge`, actif par défaut) ; sous le seuil compact, le badge
  **remplace** le libellé dès que le compte est non nul — les libellés
  s'effacent, les badges restent.
- **Les pièces jointes en attente** sont rendues en rangée, chaque cible de
  retrait à 48 dp ([AD-13](../concepts/invariants.md#ad-13)).

## La feuille d'outils déclarative {#feuille-outils}

Les outils propres à une application (bascules, cycles, choix) se déclarent
en **données** dans un `ZChatToolCatalog` (porté par le kernel) et se pilotent
par un `ZChatToolController` : **un seul état pour deux surfaces** — le badge
du composer et la feuille lisent le même contrôleur, un réglage ne peut donc
jamais diverger entre les deux. La feuille rend :

- un en-tête **« Actifs »** : les outils enclenchés en puces désactivables
  d'un geste, avec un bouton **Réinitialiser** ;
- les sections déclarées, chaque entrée grisée **avec sa raison** quand une
  exclusion déclarative la ferme (joindre un document peut masquer un outil,
  par déclaration — jamais en dur) ;
- une **recherche** recommandée par le catalogue au-delà d'un seuil de
  sections (`searchRecommended`), plutôt qu'un long défilement.

L'habillage Material de cette feuille vit dans
[zcrud_chat_material](zcrud_chat_material.md) ; les réglages **standard**
(longueur, budget, corpus…) restent portés par `ZChatSettingsController` et
sa feuille — un outil d'hôte ne redéclare jamais un réglage standard, sous
peine de deux états pour une même donnée.

## Le contrôleur de conversation {#controleur}

`ZChatController` est le point d'entrée unique des verbes (`runAction`) et
tient une tranche réactive par facette. Son contrat le plus important est
celui de l'**annulation** : interrompre une génération **conserve le texte
partiel** déjà reçu (la réponse passe en phase `cancelled`, jamais
supprimée) et **notifie le port** — la requête réseau est réellement coupée,
pas abandonnée en arrière-plan. Un arrêt voulu n'est pas une panne : l'échec
d'interruption porte `cancelledByUser`.

Une réponse encore sans identité serveur est identifiable par convention :
son identifiant est `<requestId>/reply` — inutile de la chercher par
`requestId`.

L'édition d'un message envoyé et la régénération passent par `runAction` :
`previewEditImpact` calcule **dans le contrôleur** le nombre de tours que
l'édition invaliderait (l'écran n'a rien à balayer), et la régénération ne
propose aucun enum de variantes — la transformation de la requête est
déclarée par l'hôte. Les lectures `messageById`, `replyToOf` et `contentOf`
évitent tout parcours manuel du fil.

## Notebook : contrôleur et écran assemblé {#notebook}

`ZChatNotebookController` orchestre un fil dont les réponses portent des
artefacts : abonnement au transcript, génération en flux, occupation par
artefact, confirmation des verbes destructeurs, persistance de chaque tour
réglé. Il compose les ports du kernel (transcript, registre d'artefacts,
génération, stockage) sans en connaître les identités métier.

`ZChatNotebookScreen` est l'**assemblage complet** : l'hôte ne fournit que
des adaptateurs de domaine (port de flux, transcript, registre, exécuteur
d'actions, confirmations, résolveurs de glyphes et libellés) et des
paramètres de peau — l'écran câble tout le reste. Descendre d'un cran vers
le contrôleur et les vues reste possible sans rien perdre.

## Conversation persistée : le transcript partagé {#conversation}

La mécanique « flux → messages, envoi → persistance » est écrite **une
fois** — `ZChatTranscriptBinding` : abonnement unique au
`ZChatTranscriptPort`, attachement au premier instantané, `append`/`update`
à chaque tour réglé, échecs (y compris une exception **synchrone** du port)
publiés en `Left` sur `lastFailure`. Le Notebook et la conversation simple
la composent tous deux : les deux surfaces ne peuvent pas diverger.

`ZChatConversationController` est un `ZChatController` doté de ce binding, et
`ZChatConversationScreen(transcript:)` l'écran assemblé correspondant :

```dart
ZChatConversationScreen(
  streamPort: monStreamPort,
  transcript: monTranscriptPort,        // le même port que le Notebook
  conversationId: conversation.id,
  cursorColor: theme.colorScheme.primary,
  failureBuilder: (_, f) => Text(l10n.of(f)), // tours ET écritures du fil
  key: ValueKey(conversation.id),       // changer de conversation = nouvelle clé
)
```

Sans `transcript`, `initialMessages` reste la source et l'arbre est
strictement celui d'avant — l'ajout est additif. Avec lui, le fil vient du
dépôt et chaque tour s'y persiste ; `initialMessages` n'est plus lu.

## Routage par tâche, côté écran {#routage}

Le [routage par tâche](../concepts/routage-par-tache.md) — quel fournisseur
et quel modèle pour quelle tâche — se déclare au kernel ; ce paquet en porte
la moitié écran :

- **`ZChatRouteSession`**, possédée par l'hôte : tranches granulaires
  (`routerId`, `router`, `routeOf(taskKey)` — seule la route qui change
  notifie), gestes `selectRouter`/`refresh`/`setModelOverride`. **Aucun
  membre n'envoie** : la session résout, elle ne transporte pas.
- **Les ports routés** (`ZChatRoutedStreamPort`, port d'artefact routé) :
  répartition `handlerId → providerId → routeName → fallback` vers les ports
  concrets déclarés (`ZChatRouteHandlers`). Ils ne résolvent ni ne gatent.
- **Le câblage vit dans le cycle d'envoi** : `ZChatController(routeResolver:)`
  résout la route **avant** l'état, le message optimiste et tout appel de
  port ; un refus du gate publie `lastFailure` (`upgradeRequired`) et laisse
  la saisie intacte. `ZChatNotebookScreen` et `ZChatConversationScreen`
  partagent le même assembleur (`routeSession:`, `routerOptions:`,
  `modelLabelOf:`, `taskLabelKeyOf:`) : sélecteur de routeur au composer,
  choix du repli par tâche dans la feuille de réglages.

Sans session ni résolveur déclarés, la requête reçue par le port est
identique à celle du builder — rien ne change pour un hôte passif.

## Artefacts déclarés par message

Dans un usage notebook, une réponse a produit — ou peut produire — une carte
mentale, des flashcards, un résumé, une note. `ZChatArtifactSpec` déclare ces
**artefacts** par message : une clé **opaque**, un glyphe, un libellé déjà
localisé, trois lectures d'état sur le message brut, et des verbes ordonnés.
Le socle rend le glyphe **teinté si le contenu existe**, la pastille de compte,
le menu des verbes dont la condition tient, la confirmation d'un verbe
destructeur, l'animation d'occupation **par artefact** et l'annonce
d'accessibilité — sans jamais connaître le vocabulaire métier de l'hôte.

Avec `artifacts` vide — le défaut — le rendu est strictement celui d'avant :
aucun widget, aucun contrôleur, aucun changement d'arbre.

Le contrat complet est décrit dans
[Artefacts de message déclarés](../concepts/artefacts-de-message.md) : chaîne de
résolution de l'accent, replis fermants, comportement sous « Réduire les
animations », coquille de tuile (`ZChatTileShell`) et actions par groupe de la
liste de conversations.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatController` | Le contrôleur de conversation — tranches réactives granulaires, jeton par requête, point d'entrée unique des verbes (`runAction`), lectures `messageById`/`replyToOf`/`contentOf`/`previewEditImpact`, résolution de route optionnelle. |
| `ZChatConversationController` / `ZChatConversationScreen` | Conversation **persistée** : le contrôleur doté du transcript, et l'écran assemblé (`transcript:`). Sans transcript, arbre et sources inchangés. |
| `ZChatNotebookController` / `ZChatNotebookScreen` | Le Notebook : orchestration des artefacts par message et l'écran assemblé complet, branchés sur les ports du kernel. |
| `ZChatTranscriptBinding` | La mécanique « flux → messages, envoi → persistance », écrite une fois et composée par les deux contrôleurs. |
| `ZDefaultChatComposer` / `ZChatComposerSubmitPolicy` | Le composer assemblé et sa politique de raccourci clavier déclarable (Entrée envoie sur bureau/Web par défaut). |
| `ZChatToolController` | L'état **unique** des outils d'hôte, partagé par le badge du composer et la feuille d'outils. |
| `ZChatRouteSession` | Session de routage possédée par l'hôte : tranches granulaires par tâche, sélection et repli — aucun membre n'envoie. |
| `ZChatRoutedStreamPort` | Port de flux routé : répartition `handlerId → providerId → routeName → fallback`, sans résolution ni gouvernance. |
| `ZChatRenderer` / `ZChatRendererScope` | Port de rendu neutre et sa chaîne de résolution, sur le patron de `ZListRenderer` (invariant [AD-8](../concepts/invariants.md#ad-8)). |
| `ZChatSettingsSheet` / `ZChatSettingsController` | Feuille de réglages composable et l'état de génération qu'elle rend, sans réinventer d'enum. |
| `ZChatAttachmentController` / `ZChatExportService` | Cycle de vie d'une pièce jointe en attente ; export agrégé d'une conversation en cinq formats (`markdown`, `plainText`, `html`, `references`, `pdf` — ce dernier mis en page par la couture `ZChatPdfComposer`). |
| `ZChatArtifactSpec` / `ZChatArtifactAction` / `ZChatArtifactBar` | Artefacts déclarés par message : clé opaque, lectures d'état, verbes ordonnés avec conditions, et leur rendu. |
| `ZChatTileShell` / `ZChatTileToggleStyle` | Coquille **déclarée** d'une tuile (carte, filet, coiffe du sujet du tour, bouton de dépli, horodatage). Rien n'est peint tant qu'elle n'est pas déclarée. |
| `ZChatShellRenderer` / `ZChatShellRendererScope` | Port de rendu du **cadre défilant** d'une conversation — `null` garde la liste neutre ; la région live et la tuile restent hors de portée d'une coquille tierce. |
| `ZChatCaptureController` | Dictée et reconnaissance de texte : l'insertion **concatène**, jamais ne remplace, et la transcription est un `ZUnreviewedText` — l'envoi sans relecture est inexprimable. |
| `ZChatDiffusionService` | Sortir la conversation de l'application : export, partage, lecture à voix haute. N'ajoute aucun format et ne redéfinit ni le rendu ni le partage de `ZChatExportService`. |
| `ZChatConversationList.groupActionsBuilder` | Actions déclarées dans l'en-tête d'un groupe, sur la **clé opaque** et le compte ; un builder qui lève replie ce seul groupe. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat/README.md) — installation, démarrage rapide, API complète.
- [Routage par tâche](../concepts/routage-par-tache.md) — l'entité routeur, sa résolution et sa gouvernance, dont ce paquet porte la moitié écran.
- [Artefacts de message déclarés](../concepts/artefacts-de-message.md) — le contrat de `ZChatArtifactSpec`, de la coquille de tuile et des actions de groupe.
- [zcrud_chat_kernel](zcrud_chat_kernel.md) — le domaine pur : modèle, ports, outils, routeurs.
- [zcrud_chat_material](zcrud_chat_material.md) — l'habillage Material du composer, des réglages et de la feuille d'outils.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
