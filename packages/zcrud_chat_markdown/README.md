# zcrud_chat_markdown

Backend de rendu riche Markdown/LaTeX pour le chat zcrud — satellite opt-in
qui ne coûte rien à qui ne le monte pas (invariant AD-1).

## Aperçu {#apercu}

Le rendu neutre de `zcrud_chat` affiche volontairement le Markdown, le LaTeX
et les diagrammes Mermaid comme du texte source : c'est un choix délibéré,
pas un défaut, pour que le socle du chat reste sans dépendance riche. Ce
paquet fournit l'implémentation branchée au bout du port `ZChatRenderer` —
le point d'extension que `zcrud_chat` expose précisément pour ce cas —
adossée à `zcrud_markdown` (Quill en interne, isolé derrière son propre
codec neutre).

**Utilisez ce paquet** si votre conversation affiche des réponses de modèle
formatées (gras, listes, tableaux, formules LaTeX) et que vous voulez les
rendre plutôt que les afficher en texte source.

**N'utilisez pas ce paquet** si vos messages sont du texte brut sans mise en
forme, ou si vous préférez composer votre propre `ZChatRenderer` : rien dans
`zcrud_chat` n'impose ce satellite, et son absence ne change strictement
rien au comportement du socle.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_markdown/zcrud_chat_markdown.dart';

/// Branche le rendu riche sur une conversation existante : les blocs de
/// texte de rôle assistant/system passent désormais par le Markdown, le
/// reste (pièces jointes, réglages…) est inchangé.
Widget buildRichConversation(ZChatController controller) {
  return ZChatRendererScope(
    renderer: const ZChatMarkdownRenderer(),
    child: ZChatConversationView(controller: controller),
  );
}
```

## Concepts clés {#concepts-cles}

- **Rendu au bout d'un port ([AD-8](../../docs/site/concepts/invariants.md#ad-8))** —
  `ZChatMarkdownRenderer` implémente `ZChatRenderer`, exactement comme
  `ZSfDataGridRenderer` implémente `ZListRenderer` pour les listes : le
  cœur du chat n'a jamais besoin de connaître Markdown ou LaTeX pour définir
  le port.
- **Streaming : neutre pendant, riche à la complétion** — un Markdown reçu
  fragment par fragment est incomplet à chaque étape (un `**` peut ne pas
  être encore fermé). Reconstruire le rendu riche à chaque jeton reçu
  provoquerait un clignotement visuel et un coût croissant avec la longueur
  du message ; `ZChatMarkdownRenderer` décline donc par défaut pendant le
  flux et laisse le rendu neutre — déjà granulaire — afficher le texte en
  cours, avant de rendre le résultat riche une seule fois à la fin. Voir
  `ZChatMarkdownStreamingMode` pour le mode alternatif.
- **Périmètre limité aux blocs de texte** — seul `ZTextBlock` est rendu en
  Markdown ; les autres variantes de bloc (tableau, diagramme, sources…)
  portent une donnée déjà structurée qu'un passage Markdown pourrait
  corrompre. Le renderer décline sur tout ce qui n'est pas du texte, et le
  rendu neutre du socle prend le relais.
- **Confinement de la dépendance riche ([AD-1](../../docs/site/concepts/invariants.md#ad-1))** —
  ce paquet n'atteint Quill qu'à travers l'API neutre de `zcrud_markdown`
  (`ZMarkdownReader`/`ZCodec`) ; aucun type de l'éditeur riche ne fuit dans
  ce paquet ni dans son barrel.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZChatMarkdownRenderer` | Le backend de rendu, à injecter via `ZChatRendererScope`. Paramètres : politique de streaming, LaTeX, rôles couverts, style de texte. |
| `ZChatMarkdownStreamingMode` | Politique de rendu pendant un flux en cours (`neutralWhileStreaming` par défaut, `richWhileStreaming`). |
| `kZChatMarkdownDefaultRoles` | Les rôles dont le texte est interprété comme du Markdown par défaut — tout sauf `user`. |

## Cas limites et invariants {#cas-limites}

- **Aucun `throw`, quel que soit le fragment reçu (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  un Markdown tronqué à un endroit délicat (`**` non fermé, tableau à une
  ligne, bloc de code non refermé, lien coupé, `$$` ouvert) est toujours
  rendu comme du texte littéral plutôt que de lever une exception.
- **Le texte de l'utilisateur reste littéral par défaut** — `roles` exclut
  `user` de `kZChatMarkdownDefaultRoles` : ce que l'utilisateur a tapé
  (astérisques compris) doit rester visible tel quel, pas interprété comme
  de la mise en forme.
- **LaTeX est une décision d'affichage, jamais d'écriture** — ce paquet ne
  fait que décoder du texte déjà persisté ; activer ou désactiver le pont
  LaTeX (`latex: true/false`) ne modifie ni ne risque aucune donnée stockée.
- **Un bloc vide ne rend rien** — aucun texte de repli n'est inventé pour un
  contenu vide ; le renderer décline et laisse le rendu neutre décider.
- **`const ZChatMarkdownRenderer()` est comparé par identité** — le garder
  `const`, ou le mémoïser hors de `build`, évite de reconstruire toute la
  conversation à chaque frame.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_chat_markdown.md`](../../docs/site/paquets/zcrud_chat_markdown.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — le socle Flutter dont ce paquet implémente le port de rendu (`ZChatRenderer`).
- `zcrud_chat_kernel` — le domaine pur de conversation, dont dépend `zcrud_chat`.
- `zcrud_markdown` — l'éditeur/lecteur Markdown neutre sur lequel ce paquet s'appuie.

## Licence {#licence}

MIT — voir la racine du dépôt.
