/// `ZFlashcardMarkdownContent` — seam rich-text **opt-in** du contenu d'une carte
/// (SU-2, AC6 — AD-40 / AD-7 / AD-10 / AD-1).
///
/// ⚠️ **ADAPTATEUR MINCE** (patron `ZMindmapMarkdownContent`) : il **compose**
/// `ZMarkdownReader` + `const ZMarkdownCodec()` de `zcrud_markdown` **TELS
/// QUELS**. **AUCUN** nouveau codec, **AUCUNE** heuristique de format, **AUCUN**
/// `QuillController`/`Delta` construit à la main.
///
/// ⚠️ **Il vit chez le CONSOMMATEUR** (`zcrud_flashcard`), **JAMAIS** dans
/// `zcrud_markdown` : l'arête autorisée est `zcrud_flashcard → zcrud_markdown`
/// (elle **préexiste** — `z_flashcard_api.dart` la rattache déjà). L'inverse
/// créerait un **cycle** (AD-1/AD-40). Cet adaptateur ne coûte donc **aucune
/// nouvelle arête** de graphe.
///
/// **Différence assumée avec le patron mindmap** : `ZMindmapMarkdownContent` lit
/// un payload Delta dans le slot AD-4 `extra[slotKey]` avec un codec **identité**,
/// parce que `ZMindmapNode.content` est **imposé texte brut** (OQ-S5/AD-28). Ici
/// **le texte de la carte EST la source markdown** (FR-SU1 : « contenus
/// question/réponse/choix rendus en texte riche ») ⇒ `ZMarkdownCodec.decode`
/// transforme la source markdown en ops Delta. **Aucune clé persistée nouvelle**,
/// aucun élargissement du typedef de slot.
///
/// **OPT-IN** (AD-40) : le défaut de `ZFlashcardReviewCard` reste le **texte brut
/// thématisé** de su-1. Une app qui n'injecte pas ce builder ne **construit aucun
/// widget Quill** : aucun `QuillEditor`, aucun `Document`, aucun décodage Delta
/// n'est monté sur le chemin par défaut.
///
/// ⚠️ **Ce que l'opt-in n'est PAS** : il ne ferme **pas** le graphe de
/// dépendances. `zcrud_flashcard → zcrud_markdown → flutter_quill` est une arête
/// **runtime dure** du pubspec (vérifiable : `dart pub deps`), présente que ce
/// builder soit injecté ou non. L'opt-in d'AD-40 porte sur le **rendu** (le coût
/// payé à l'exécution), jamais sur la fermeture de dépendances. Le défaut, lui,
/// n'importe réellement rien de riche — c'est ce que garde
/// `z_flashcard_rich_type_leak_test.dart`.
///
/// Le LaTeX est rendu sans recâblage : `ZMarkdownReader` monte déjà
/// `kZEmbedBuilders` (embeds LaTeX/tableaux).
///
/// **AD-10** : une source markdown mal formée **ne casse jamais** le rendu
/// (`ZMarkdownCodec.decode` retombe sur `[]`, jamais de throw).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'z_flashcard_content_slot.dart' show ZFlashcardContentBuilder;

/// Clé l10n du placeholder d'un contenu de carte **vide**.
const String _kEmptyContentKey = 'zcrud.flashcard.emptyContent';

/// Rendu rich-text **opt-in** (markdown/LaTeX) d'un contenu de carte.
///
/// À passer en `contentBuilder` de `ZFlashcardReviewCard` via [builder] :
///
/// ```dart
/// ZFlashcardReviewCard(
///   card: card,
///   contentBuilder: ZFlashcardMarkdownContent.builder(),
/// )
/// ```
class ZFlashcardMarkdownContent extends StatelessWidget {
  /// Construit le rendu rich-text de [content] (source markdown/LaTeX).
  const ZFlashcardMarkdownContent({
    required this.content,
    this.placeholder,
    super.key,
  });

  /// **Source markdown/LaTeX** — le texte de la carte lui-même (FR-SU1), décodé
  /// en ops Delta par `ZMarkdownCodec` (défensif : mal formé ⇒ rendu vide).
  final String content;

  /// Texte affiché quand [content] est vide (repli l10n si `null`).
  final String? placeholder;

  /// Fabrique un [ZFlashcardContentBuilder] opt-in — **voie d'usage app**.
  ///
  /// Le défaut de `ZFlashcardReviewCard` reste le texte brut si ce builder n'est
  /// pas passé (AD-40).
  static ZFlashcardContentBuilder builder({String? placeholder}) =>
      (BuildContext context, String content) => ZFlashcardMarkdownContent(
            content: content,
            placeholder: placeholder,
          );

  @override
  Widget build(BuildContext context) => ZMarkdownReader(
        // Source markdown normalisée par le codec — le lecteur accepte une
        // valeur au format persisté du codec (`value: Object?`).
        value: content,
        codec: const ZMarkdownCodec(),
        placeholder: placeholder ??
            label(context, _kEmptyContentKey, fallback: 'Aucun contenu'),
      );
}
