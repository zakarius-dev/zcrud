# zcrud_chat_syncfusion

Coquille Syncfusion AI AssistView et normalisation d'un fil textuel encodé
selon la convention IFFD, pour le chat zcrud — satellite opt-in, unique
point d'entrée de Syncfusion dans l'écosystème du chat (invariant AD-1).

## Aperçu {#apercu}

Ce paquet porte deux volets indépendants, réunis parce qu'ils sont tous les
deux des frontières d'intégration que le socle ne doit jamais porter :

1. **La coquille Syncfusion.** `ZSfAssistShellRenderer` implémente
   `ZChatShellRenderer` : il rend le cadre `SfAIAssistView` et rappelle la
   fabrique de tuiles du socle — jamais une vue de conversation
   concurrente qui réimplémenterait la région live, le dépli inline ou le
   rendu de message du socle. `syncfusion_flutter_chat` est une arête de
   ce seul paquet du monorepo.
2. **La normalisation d'un fil textuel.** Un backend qui n'expose qu'un
   flux de texte brut — avec un encodage du saut de ligne, des sentinelles
   pseudo-XML dans le corps du message, et des erreurs écrites en clair
   dans le canal de réponse — est décodé ici vers les événements typés du
   kernel (`ZChatStreamEvent`). Une erreur en clair devient un échec typé,
   jamais un message de conversation.

**Utilisez ce paquet** si votre application affiche le chat avec
`SfAIAssistView`, ou si votre backend de génération émet un fil textuel
suivant la convention IFFD (marqueurs de ligne, sentinelles pseudo-XML).

**N'utilisez pas ce paquet** si vous n'avez ni l'un ni l'autre besoin :
monter `zcrud_chat` seul ne tire aucun octet de Syncfusion, et un backend
qui émet déjà des événements typés n'a besoin d'aucune normalisation.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_syncfusion/zcrud_chat_syncfusion.dart';

/// Rend une conversation dans la coquille Syncfusion `SfAIAssistView`,
/// tout en gardant la région live, le dépli inline et le rendu de message
/// du socle.
Widget buildSyncfusionConversation(ZChatController controller) {
  return ZChatShellRendererScope(
    renderer: const ZSfAssistShellRenderer(),
    child: ZChatConversationView(controller: controller),
  );
}
```

## Concepts clés {#concepts-cles}

- **Backend de cadre, jamais une vue parallèle** — `ZSfAssistShellRenderer`
  ne construit aucune tuile lui-même : il rappelle la fabrique du socle
  pour chaque message, ce qui garde la région live d'accessibilité, le
  dépli inline et le port de rendu de bloc hors de sa portée.
- **`AssistMessage.data` n'est ni le corps rendu ni la voie d'annonce** —
  Syncfusion exige un `String` pour ce champ, mais le corps visible vient
  du constructeur de contenu du socle, et l'annonce à l'accessibilité passe
  par le `Semantics` de la tuile de `zcrud_chat`, pas par ce champ.
- **Classement en canal, total** — chaque balise du fil textuel est
  classée en réponse, trace de raisonnement, échec ou charge utile
  structurée ; une balise inconnue retombe sur la trace de raisonnement
  plutôt que d'apparaître dans la réponse affichée.
- **Aucun identifiant de séquence fabriqué** — ce fil ne permet pas de
  reprendre un flux coupé sans rejouer le tour entier : les événements
  sortent avec `sequenceId == null` plutôt que de laisser croire à une
  reprise honorée.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZSfAssistShellRenderer` | Backend Syncfusion du port `ZChatShellRenderer`, à injecter via `ZChatShellRendererScope`. |
| `ZIffdTextStreamPort` / `ZIffdRawStreamOpener` | Port de streaming adossé au fil textuel, et la couture de transport fournie par l'hôte. |
| `ZIffdLexer` / `ZIffdSegment` | Découpage incrémental du fil brut en segments de texte et de balises. |
| `ZIffdStreamNormalizer` | Classement des segments en canaux et production des événements typés du kernel. |
| `ZIffdChannel` / `zIffdChannelOfTag` | Le canal logique d'une balise (réponse, trace, échec, charge utile) et sa dérivation. |
| `zIffdDecodeNonStreamResponse` / `zIffdDecodeNonStreamBody` | Décodage d'une réponse non-streamée du même backend. |

## Cas limites et invariants {#cas-limites}

- **Aucune perte sur un flux tronqué** — `ZIffdLexer.close()` relâche toute
  queue retenue (marqueur ou balise coupés) comme du texte plutôt que de la
  perdre silencieusement (invariant AD-10).
- **Aucune exception ne traverse le port de streaming** — une erreur de
  transport devient un `Left(ZChatStreamInterruptedFailure)`, jamais une
  exception qui remonterait jusqu'à l'UI.
- **Le skin de notebook est strictement additif** — sans
  `ZSfAssistShellRenderer.notebookSkin`, les réglages de bulle Syncfusion
  restent leurs valeurs par défaut, à l'octet près ; un hôte qui ne demande
  rien ne voit rien changer.
- **Aucun client HTTP ni SDK IA ici (invariants [AD-11](../../docs/site/concepts/invariants.md#ad-11), [AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  ce paquet consomme un `Stream<String>` déjà extrait par l'hôte ; le
  transport, les en-têtes et les clés restent côté application.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_chat_syncfusion.md`](../../docs/site/paquets/zcrud_chat_syncfusion.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — le socle Flutter dont ce paquet implémente le port `ZChatShellRenderer`.
- `zcrud_chat_kernel` — la cible des événements de streaming produits par ce paquet.

## Licence {#licence}

MIT — voir la racine du dépôt.
