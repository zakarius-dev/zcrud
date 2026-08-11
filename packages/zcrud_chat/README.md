# zcrud_chat

Contrôleur de conversation IA Flutter-natif de zcrud — état réactif granulaire
(invariant AD-2) sur le domaine pur exposé par `zcrud_chat_kernel`.

## Aperçu {#apercu}

`zcrud_chat` est le paquet **satellite Flutter** de la capacité chat, au sens
du patron [kernel/satellite](../../docs/site/concepts/architecture-hexagonale.md#le-patron-kernel-satellite) :
`zcrud_chat_kernel` porte le domaine pur (modèle, contrat d'action, ports
IA), ce paquet porte l'**état réactif** — `ZChatController`, un
`ChangeNotifier` pur Flutter qui expose des tranches `ValueListenable`
granulaires (composer, messages, texte en cours par requête, progression par
requête, échec typé, annonce d'accessibilité) — et le **rendu par défaut**
d'une conversation, sans aucune dépendance tierce.

Ce paquet fournit :

- le **contrôleur de conversation** — un jeton `ZChatRequestToken` par
  requête, la reprise d'un flux interrompu sous la même identité, et un
  unique point d'entrée pour tous les verbes (`runAction`) ;
- le **rendu neutre** — `ZChatConversationView`, `ZChatMessageTile`,
  `ZChatBlockView` : `ListView.builder`, région live d'accessibilité, dépli
  inline, libellés résolus, jetons de thème. Un rendu riche (Markdown/LaTeX,
  grille de données) se branche par le port `ZChatRenderer` sans que ce
  paquet ne dépende de Quill ni de Syncfusion (invariant AD-8) ;
- les **pièces jointes et l'export** — `ZChatAttachmentController` en
  `ChangeNotifier` à tranches, `ZChatExportService` pour l'export agrégé
  d'une conversation en quatre formats textuels ;
- la **feuille de réglages** — `ZChatSettingsSheet`, entièrement composable,
  qui rend les réglages du kernel sans en réinventer aucun ;
- la **bande du composer**, la **liste de conversations** et la **vue
  notebook** — des assemblages par défaut, chacun opt-in et remplaçable
  pièce par pièce.

**Utilisez ce paquet** pour construire une interface de chat Flutter — écran
de conversation, composer, liste de conversations, feuille de réglages —
sans jamais reconstruire vous-même la logique d'envoi, de flux ou
d'annulation. **N'utilisez pas ce paquet** si vous traitez des conversations
hors Flutter (migration, script, traitement serveur) : passez directement
par `zcrud_chat_kernel`, qui n'a aucune dépendance Flutter.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Un contrôleur minimal : l'hôte fournit le transport, l'exécuteur de
/// verbes, la confirmation et la fabrique d'identité de requête.
ZChatController buildController({
  required ZChatStreamPort streamPort,
  required ZChatActionExecutor actionExecutor,
}) {
  return ZChatController(
    streamPort: streamPort,
    actionExecutor: actionExecutor,
    confirm: (ZChatActionPlan plan) async => true,
    newRequestId: () => DateTime.now().microsecondsSinceEpoch.toString(),
    buildRequest: (ZChatDraft draft) =>
        ZChatGenerationRequest(prompt: draft.text),
  );
}

/// Le rendu par défaut d'une conversation, abonné aux tranches du
/// contrôleur — aucune reconstruction du formulaire à chaque jeton reçu.
Widget buildConversation(ZChatController controller) {
  return ZChatConversationView(controller: controller);
}
```

## Concepts clés {#concepts-cles}

- **Réactivité granulaire (invariant [AD-2](../../docs/site/concepts/invariants.md#ad-2))** —
  chaque tranche du contrôleur signale à sa fréquence propre : le composer à
  chaque frappe, le texte en cours de streaming à chaque jeton, la liste de
  messages seulement à l'ajout d'un tour. Taper 100 caractères ne reconstruit
  que le champ de saisie, jamais la liste de messages ni le formulaire de
  réglages.
- **Un jeton par requête, un point d'entrée par verbe** — `send` fabrique un
  `ZChatRequestToken` par appel (deux flux concurrents s'annulent
  indépendamment) ; `runAction` est le seul site du paquet qui invoque
  `ZChatActionDispatcher`, pour que supprimer, régénérer, éditer ou annuler
  passent tous par le même protocole d'impact chiffré et de confirmation.
- **Rendu neutre + port de rendu (invariant [AD-8](../../docs/site/concepts/invariants.md#ad-8))** —
  sur le patron de `ZListRenderer`, `ZChatRenderer` laisse un hôte substituer
  un rendu riche à une portion de la conversation sans que ce paquet importe
  la dépendance correspondante ; `null` signifie « garder le rendu neutre ».
- **Composabilité par créneaux nullables (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  la feuille de réglages, la bande du composer et la vue notebook exposent
  chacune un builder par pièce : absent, la pièce est rendue par défaut ;
  fourni et rendant `null`, la pièce est retirée de l'arbre.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| **Contrôleur** | |
| `ZChatController` | Le contrôleur de conversation : tranches réactives granulaires, jeton par requête, point d'entrée unique des verbes. |
| `ZChatConfirm` / `ZChatRequestIdFactory` / `ZChatRequestBuilder` | Seams fournis par l'hôte (confirmation, identité de requête, construction de la requête). |
| `ZChatPhase` / `ZChatStreamProgress` | Progression grossière d'un flux, séparée du texte à haute fréquence. |
| `ZChatEditingSession` | Session d'édition en cours d'un message déjà envoyé. |
| **Rendu neutre** | |
| `ZChatConversationView` / `ZChatMessageTile` / `ZChatBlockView` | Rendu par défaut d'une conversation, d'un message, d'un bloc de contenu. |
| `ZChatRenderer` / `ZChatRendererScope` / `zResolveChatBlock` | Port de rendu, son injection et sa chaîne de résolution (jamais levée). |
| `ZChatAccessibleTextScope` | Résolution du texte annoncé à l'accessibilité pour un bloc ouvert. |
| **Pièces jointes** | |
| `ZChatAttachmentController` / `ZPendingAttachment` | Cycle de vie d'une pièce jointe en attente, à tranches `ValueListenable`. |
| `ZChatAttachmentPicker` / `ZChatAttachmentUploader` | Coutures d'hôte pour la sélection de fichier et le transport. |
| `ZChatAttachmentStrip` | Rendu par défaut des pièces en attente, cibles tactiles conformes. |
| **Export et diffusion** | |
| `ZChatExportService` / `ZChatExportFormat` / `ZChatExportResult` | Export agrégé d'une conversation en quatre formats textuels. |
| `ZChatPdfComposer` / `ZChatExportSink` | Coutures d'hôte pour le PDF et la destination système. |
| `ZChatDiffusionService` / `ZChatDiffusionBar` | Diffusion vocale d'une réponse, avec chaîne de repli. |
| **Réglages** | |
| `ZChatSettingsController` | État des réglages de génération, hors du contrôleur de conversation. |
| `ZChatSettingsSheet` | Feuille de réglages par défaut, entièrement composable par créneaux. |
| `ZChatSettingsEntry` / `ZChatCorpusOption` | Entrée déclarative de réglage et catalogue de corpus fourni par l'hôte. |
| **Composer** | |
| `ZChatComposer` | Zone de saisie partagée, abonnée à `ZChatController.composer`. |
| `ZDefaultChatComposer` | Assemblage par défaut opt-in de la bande, des sélecteurs et du bandeau d'édition. |
| `ZChatComposerBand` (et pièces associées) | Bande d'accessoires du composer — pickers, bascules, sélecteur d'effort, bouton d'arrêt. |
| **Liste et sélection** | |
| `ZChatConversationList` / `ZChatConversationTile` | Liste de conversations avec états, tri, pagination curseur, sélection multiple. |
| `ZChatConversationSelection` / `ZChatGroupExpansion` | Contrôleurs de sélection et de repli fournis par l'hôte. |
| `zChatConversationActions` | Descripteurs d'action de conversation, absents quand leur callback est nul. |
| **Saisie assistée et notebook** | |
| `ZChatCaptureController` / `ZChatCaptureBar` | Dictée et OCR avec relecture structurelle avant envoi. |
| `ZChatNotebookView` | Vue notebook — identité de message masquée, actions par message exposées. |
| `ZChatHighlightedText` / `zChatHighlightRanges` | Surlignage de texte partagé par les surfaces de recherche. |

## Cas limites et invariants {#cas-limites}

- **Un échec n'est jamais un message** — `ZChatController.lastFailure` vit
  dans sa propre tranche, hors de `messages` : un texte d'erreur brut n'est
  jamais poussé dans le corps d'une bulle et affiché comme si c'était la
  réponse de l'assistant.
- **Annuler ne coûte jamais la saisie** — l'arrêt volontaire d'un flux ne
  touche jamais le champ de saisie ; une panne sans contenu produit restitue
  le brouillon et retire le message optimiste (invariant AD-10).
- **La rétention des tranches par requête est bornée** — les tranches d'une
  requête terminée restent vivantes le temps d'une transition d'UI, dans une
  fenêtre glissante de taille fixe : une conversation longue ne fait pas
  grossir la mémoire sans limite.
- **Accessibilité (invariant [AD-13](../../docs/site/concepts/invariants.md#ad-13))** —
  toute cible tactile fait ≥ 48 dp en géométrie rendue, tout est
  directionnel (`EdgeInsetsDirectional`, `TextAlign.start`), et un état ne
  repose jamais sur la seule couleur : un canal sémantique et un canal
  visuel non chromatique coexistent toujours.
- **Aucun secret, aucun prompt composé ici (invariant [AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  le transport, les clés d'API et la construction du prompt restent côté
  application, derrière `ZChatStreamPort` et `ZChatRequestBuilder`.
- **Zéro dépendance tierce** — ce paquet n'importe ni gestionnaire d'état
  (invariants [AD-2](../../docs/site/concepts/invariants.md#ad-2)/[AD-15](../../docs/site/concepts/invariants.md#ad-15)),
  ni Markdown, ni Syncfusion : un rendu riche se branche par
  `ZChatRenderer` sans jamais entrer dans ce paquet.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_chat.md`](../../docs/site/paquets/zcrud_chat.md)
- [Réactivité granulaire](../../docs/site/concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md) — couches, ports et patron kernel/satellite.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat_kernel` — le domaine pur de conversation dont ce paquet porte l'état réactif.
- `zcrud_core` — `ZResult`/`ZFailure`, `ZcrudTheme`, résolution de libellés.

## Licence {#licence}

MIT — voir la racine du dépôt.
