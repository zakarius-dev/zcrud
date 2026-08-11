# zcrud_chat_study

Pont entre une conversation zcrud et le domaine d'étude par répétition
espacée — satellite opt-in, sans dépendance Flutter côté domaine
(invariant AD-1).

## Aperçu {#apercu}

Ce paquet ne redéclare aucun symbole existant. L'entité de carte,
l'ordonnanceur de répétition espacée, le moteur de session et le port de
génération IA vivent déjà dans `zcrud_flashcard`, `zcrud_session`,
`zcrud_study` et `zcrud_study_kernel`. `zcrud_chat_study` fournit
uniquement ce qui manquait pour relier une conversation à ces contrats
existants : un mapper (conversation → requête de génération), un pool de
session (cartes du dossier union cartes de la conversation, dédoublonnées)
et la sélection des modes offerts par un parcours « commencer à
apprendre ».

`zcrud_chat`/`zcrud_chat_kernel` ne dépendent jamais de `zcrud_flashcard` :
un consommateur qui utilise le chat sans le domaine d'étude n'en porte pas
le poids. Symétriquement, `zcrud_flashcard` ne connaît pas le chat. Le pont
vit donc dans ce satellite dédié, qui dépend des deux domaines et dont rien
ne dépend.

**Utilisez ce paquet** si votre application propose de transformer une
conversation IA en session de révision par flashcards.

**N'utilisez pas ce paquet** si votre chat n'a aucun usage d'étude : montez
seulement `zcrud_chat`/`zcrud_chat_kernel`, sans jamais tirer le domaine
flashcards.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_study/zcrud_chat_study.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Génère des flashcards depuis un message d'assistant, en s'appuyant sur
/// le port de génération que l'application a déjà implémenté ailleurs.
Future<void> generateFromMessage(
  ZFlashcardGenerationPort port,
  ZChatMessage message,
) async {
  final ZChatFlashcardGenerator generator = ZChatFlashcardGenerator(port);
  final result = await generator.generateFromMessage(message);
  result.fold(
    (failure) => throw StateError('génération échouée : $failure'),
    (cards) => cards, // à persister par l'application
  );
}
```

## Concepts clés {#concepts-cles}

- **Câblage, jamais redéclaration** — ce paquet consomme
  `ZFlashcardGenerationPort`, `ZConversationSource`, `ZStudySessionSelector`
  et `ZReviewMode` tels quels ; il n'en existe qu'une déclaration dans tout
  le monorepo.
- **Estampillage défensif ([AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  une carte générée reçoit sa provenance conversationnelle et son dossier
  d'accueil seulement s'ils sont absents : une provenance déjà posée par
  l'implémentation du port n'est jamais écrasée.
- **Pool dédoublonné entre deux origines** — `zBuildStudyPool` unit les
  cartes déjà rangées dans un dossier et les cartes éphémères produites par
  la conversation, sans exiger que ces dernières soient d'abord rangées
  pour devenir révisables. En cas de doublon (l'assistant régénère une
  carte déjà rangée), la carte persistée est retenue pour ne pas perdre son
  historique de répétition espacée.
- **Soft-delete uniquement ([AD-9](../../docs/site/concepts/invariants.md#ad-9))** —
  ce module ne détient aucun repository et n'efface rien ; une carte
  soft-supprimée est exclue du pool par lecture filtrée.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZChatFlashcardGenerator` | Câble un `ZFlashcardGenerationPort` existant sur un message ou une conversation, avec estampillage défensif de la provenance. |
| `zChatMessageGenerationRequest` / `zChatConversationGenerationRequest` | Construisent la requête de génération depuis un message ou une conversation. |
| `zChatMessageProvenance` / `zChatConversationProvenance` | Construisent la provenance `ZConversationSource` d'un message ou d'une conversation. |
| `ZStudyPoolRequest` / `ZStudyPool` / `zBuildStudyPool` | Requête, résultat et fonction pure de constitution du pool de session dédoublonné. |
| `kZChatStudyLaunchModes` / `zIsChatStudyLaunchMode` | Les modes offerts par un parcours « commencer à apprendre » depuis une conversation. |

## Cas limites et invariants {#cas-limites}

- **Aucun prompt ni instruction système ici ([AD-12](../../docs/site/concepts/invariants.md#ad-12))** —
  le contenu transmis au port de génération est du texte de conversation
  neutre ; le fil de prompt reste du ressort de l'application.
- **Ne lève jamais** — `zBuildStudyPool` dégrade en pool vide sur des
  entrées vides ou un plafond nul ou négatif ; une implémentation d'hôte du
  port de génération qui lève est convertie en `Left(ZDomainFailure)`
  plutôt que de laisser une exception traverser ce module.
- **Aucun libellé ni couleur ici** — les modes offerts sont exposés comme
  des valeurs d'enum, jamais comme des chaînes traduites ; la l10n reste du
  ressort de l'hôte.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_chat_study.md`](../../docs/site/paquets/zcrud_chat_study.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat_kernel` — le domaine pur de conversation, source du mapper.
- `zcrud_study` / `zcrud_study_kernel` / `zcrud_flashcard` — le domaine d'étude que ce paquet relie au chat.

## Licence {#licence}

MIT — voir la racine du dépôt.
