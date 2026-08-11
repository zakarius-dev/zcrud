# zcrud_chat_kernel

Noyau Dart pur de conversation IA de zcrud — modèle neutre de chat et contrat
d'action de message, borné par l'invariant AD-1 (aucune dépendance lourde,
une seule arête sortante vers `zcrud_core`).

## Aperçu {#apercu}

`zcrud_chat_kernel` est le paquet **kernel** de la capacité chat, au sens du
patron [kernel/satellite](../../docs/site/concepts/architecture-hexagonale.md#le-patron-kernel-satellite) :
il porte les entités et les règles métier, sans aucune dépendance `flutter:`.
Le rendu Flutter et les intégrations riches vivent dans des paquets
**satellites** qui dépendent de ce kernel — `zcrud_chat` (contrôleur
Flutter-natif), `zcrud_chat_markdown` (rendu Markdown/LaTeX),
`zcrud_chat_material` (composeur Material), `zcrud_chat_study` (pont vers les
flashcards) et `zcrud_chat_syncfusion` (coquille Syncfusion AI AssistView).

Ce paquet fournit :

- le modèle neutre — `ZChatConversation`, `ZChatMessage`, la famille ouverte
  `ZContentBlock`, les sources, suggestions, quotas et métadonnées de
  réponse ;
- le contrat d'**action** de message — intentions scellées (`ZChatAction`),
  plan d'impact (`ZChatActionPlan`) et répartiteur unique
  (`ZChatActionDispatcher`) ;
- les **ports** que l'hôte implémente pour brancher un backend réel :
  génération (one-shot et streaming), gestion de conversation, saisie
  assistée (dictée/OCR), diffusion vocale.

**Utilisez ce paquet** si vous devez traiter des conversations IA hors
Flutter (migration de données, traitement serveur, test unitaire), ou si vous
écrivez un nouveau satellite de rendu qui a seulement besoin du modèle et des
contrats. **N'utilisez pas ce paquet directement** pour construire une
interface de chat : passez par `zcrud_chat`, qui assemble ce kernel avec un
contrôleur `ChangeNotifier` réactif (invariant AD-2) et les rendus riches.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  final conversation = ZChatConversation(
    title: 'Discussion tarifaire',
    lastMessageAt: DateTime.now(),
  );

  final message = ZChatMessage(
    conversationId: conversation.id ?? '',
    role: ZChatRole.assistant,
    contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'Bonjour !')],
    createdAt: DateTime.now(),
  );

  // Round-trip sans perte, tel que le fera un store d'hôte.
  final Map<String, dynamic> persisted = message.toMap();
  final ZChatMessage relu = ZChatMessage.fromMap(persisted);
  assert(relu.content == 'Bonjour !');
}
```

## Concepts clés {#concepts-cles}

- **Kernel Dart pur** — ce paquet n'importe ni `flutter:`, ni `dart:ui`, ni
  aucun autre paquet `zcrud_*` que `zcrud_core` (surface pur-Dart
  `package:zcrud_core/domain.dart`). Sa suite tourne sous `dart test`. Voir
  [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md).
- **Modèle ouvert par composition (invariant AD-4)** — `ZContentBlock` et
  `ZChatAction` sont des unions `sealed` **en interne** avec un variant ouvert
  (`ZCustomContentBlock`, `ZChatCustomAction`) : un hôte étend le vocabulaire
  sans forker le kernel, via `ZTypeRegistry`. Aucun héritage inter-paquet.
  Voir [Invariants d'architecture — AD-4](../../docs/site/concepts/invariants.md#ad-4).
- **Un verbe, un seul site d'appel** — `ZChatActionDispatcher` n'expose que
  `prepare`/`execute` ; les membres d'effet de `ZChatActionExecutor` ne sont
  invocables que depuis ce répartiteur. Une action détruisant du contenu
  (`isDestructive`) impose une confirmation avant que l'exécuteur soit touché.
- **Ports plutôt qu'implémentations** — la génération (`ZChatGenerationPort`,
  `ZChatStreamPort`), la gestion de conversation
  (`ZChatConversationSearchPort` et consorts), la capture assistée
  (`ZChatDictationPort`, `ZChatOcrPort`) et la diffusion vocale
  (`ZChatSpeechPort`) sont des `abstract interface class` : le kernel ne
  connaît aucun fournisseur concret, conformément à l'invariant AD-5.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZChatConversation` | Entité conversation — titre, récence (`lastMessageAt`), épinglage, extension versionnée. |
| `ZChatMessage` | Entité message — rôle, blocs de contenu, sources, feedback, confiance, extension versionnée. |
| `ZContentBlock` | Famille ouverte de blocs (`ZTextBlock`, `ZSuggestionsBlock`, `ZCustomContentBlock`…). |
| `ZChatSource` / `ZChatSourceFreshness` | Source citée et fiche de fraîcheur d'un dataset cité. |
| `ZChatResponseConfidence` | Palier de confiance dérivé, fail-safe, jamais fabriqué sans signal. |
| `ZChatAction` / `ZChatActionPlan` / `ZChatActionDispatcher` | Intentions scellées, plan d'impact chiffré, répartiteur unique. |
| `ZChatGenerationPort` / `ZChatStreamPort` | Ports de génération one-shot et de streaming, paramétrés par `ZChatGenerationStyle`. |
| `ZChatStreamEvent` | Union scellée des événements de flux (`token`, `thinking`, `done`…), variant ouvert `ZChatCustomStreamEvent`. |
| `ZChatConversationSearchPort`, etc. | Ports de gestion de conversation — recherche, épinglage, partage, retrait soft. |
| `ZChatCaptureRejection` / `ZUnreviewedText` | Saisie assistée avec relecture obligatoire rendue structurelle. |
| `ZChatSpeechPort` / `ZChatSpeechChain` | Diffusion vocale avec chaîne de repli explicite. |
| `ZChatQuotaSnapshot` / `ZChatQuotaMetadata` | Instantané de quota observationnel et métadonnées associées. |

## Cas limites et invariants {#cas-limites}

- **Désérialisation totale, jamais levée** (invariant AD-10) — chaque
  `fromJson`/`fromMap` de ce paquet rend un résultat même sur une entrée
  vide, corrompue ou de mauvais type : un rôle inconnu retombe sur
  `ZChatRole.unknown`, un bloc de type inconnu devient
  `ZCustomContentBlock`, une date illisible devient `null`. Un champ
  corrompu ne fait jamais échouer le parent.
- **`updated_at` / `is_deleted` n'existent pas sur les entités** (invariant
  AD-9) — ces clés appartiennent à `ZSyncMeta`, hors-entité. `ZChatConversation`
  expose `lastMessageAt` (persisté `last_message_at`) comme champ métier
  distinct, précisément pour ne pas entrer en collision avec l'autorité de
  synchronisation du store.
- **Aucune valeur fabriquée sans signal** — `ZChatResponseConfidence` rend
  `null` plutôt qu'un palier « à vérifier » quand le serveur n'a rien émis ;
  un instantané de quota absent n'est jamais interprété comme « épuisé ».
  C'est le même principe qui gouverne `ZChatCapabilityAudit` : une capacité
  demandée sans écho de l'exécuteur est **non honorée**, jamais présumée
  honorée.
- **Retrait de message = soft-delete uniquement** (invariant AD-9) —
  `ZChatDeleteAction` ne modélise aucune suppression matérielle ; c'est
  `ZSyncMeta` qui porte l'état de suppression, pour que le merge
  offline-first propage le retrait entre appareils.
- **Aucun secret, aucun format de prompt** (invariant AD-12) — les ports de
  génération ne portent ni endpoint, ni clé API, ni instruction système
  assemblée. `instructions` est une consigne neutre transmise verbatim.
- **Zéro présentation dans le domaine** (invariant AD-13) — aucun libellé,
  icône ou couleur n'est déclaré ici ; les enums exposent des discriminants
  techniques (`jsonValue`), jamais des chaînes traduisibles.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_chat_kernel.md`](../../docs/site/paquets/zcrud_chat_kernel.md)
- [Architecture hexagonale](../../docs/site/concepts/architecture-hexagonale.md) — couches, ports et patron kernel/satellite.
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — contrôleur Flutter-natif qui assemble ce kernel avec une réactivité granulaire (invariant AD-2).
- `zcrud_core` — seule dépendance `zcrud_*` de ce paquet (surface pur-Dart).

## Licence {#licence}

MIT — voir la racine du dépôt.
