---
title: zcrud_chat
description: Contrôleur de conversation IA Flutter-natif — état réactif granulaire et rendu par défaut d'un chat.
---

# zcrud_chat

## Rôle

`zcrud_chat` est le paquet **satellite Flutter** de la capacité chat : il
porte l'**état réactif** — `ZChatController`, un `ChangeNotifier` pur
Flutter exposant des tranches `ValueListenable` granulaires (composer,
messages, texte en cours par requête, progression, échec typé) — sur le
domaine pur exposé par `zcrud_chat_kernel` (modèle, contrat d'action, ports
IA). Il fournit aussi le rendu par défaut d'une conversation, une feuille de
réglages composable, la gestion des pièces jointes, l'export agrégé et une
liste de conversations, sans aucune dépendance tierce (ni Markdown, ni
Syncfusion, ni gestionnaire d'état).

## Quand l'utiliser

- Pour construire un **écran de conversation** Flutter — envoi, streaming,
  annulation, régénération, édition — sans reconstruire la logique de
  contrôleur ni risquer le rafraîchissement global du formulaire à chaque
  frappe (invariant [AD-2](../concepts/invariants.md#ad-2)).
- Pour assembler un **composer**, une **liste de conversations** ou une
  **feuille de réglages** à partir de pièces remplaçables individuellement,
  sans repartir d'un widget monolithique.
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
| `ZChatController` | Le contrôleur de conversation — tranches réactives granulaires, jeton par requête, point d'entrée unique des verbes (`runAction`). |
| `ZChatRenderer` / `ZChatRendererScope` | Port de rendu neutre et sa chaîne de résolution, sur le patron de `ZListRenderer` (invariant [AD-8](../concepts/invariants.md#ad-8)). |
| `ZChatSettingsSheet` / `ZChatSettingsController` | Feuille de réglages composable et l'état de génération qu'elle rend, sans réinventer d'enum. |
| `ZChatAttachmentController` / `ZChatExportService` | Cycle de vie d'une pièce jointe en attente ; export agrégé d'une conversation en cinq formats (`markdown`, `plainText`, `html`, `references`, `pdf` — ce dernier mis en page par la couture `ZChatPdfComposer`). |
| `ZChatArtifactSpec` / `ZChatArtifactAction` / `ZChatArtifactBar` | Artefacts déclarés par message : clé opaque, lectures d'état, verbes ordonnés avec conditions, et leur rendu. |
| `ZChatTileShell` / `ZChatTileToggleStyle` | Coquille **déclarée** d'une tuile (carte, filet, coiffe du sujet du tour, bouton de dépli, horodatage). Rien n'est peint tant qu'elle n'est pas déclarée. |
| `ZChatShellRenderer` / `ZChatShellRendererScope` | Port de rendu du **cadre défilant** d'une conversation — `null` garde la liste neutre ; la région live et la tuile restent hors de portée d'une coquille tierce. |
| `ZChatCaptureController` | Dictée et reconnaissance de texte : l'insertion **concatène**, jamais ne remplace, et la transcription est un `ZUnreviewedText` — l'envoi sans relecture est inexprimable. |
| `ZChatDiffusionService` | Sortir la conversation de l'application : export, partage, lecture à voix haute. N'ajoute aucun format et ne redéfinit ni le rendu ni le partage de `ZChatExportService`. |
| `ZChatConversationList.groupActionsBuilder` | Actions déclarées dans l'en-tête d'un groupe, sur la **clé opaque** et le compte ; un builder qui lève replie ce seul groupe. |
| `ZDefaultChatComposer` / `ZChatConversationList` | Assemblages par défaut, opt-in et remplaçables pièce par pièce. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat/README.md) — installation, démarrage rapide, API complète.
- [Artefacts de message déclarés](../concepts/artefacts-de-message.md) — le contrat de `ZChatArtifactSpec`, de la coquille de tuile et des actions de groupe.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
