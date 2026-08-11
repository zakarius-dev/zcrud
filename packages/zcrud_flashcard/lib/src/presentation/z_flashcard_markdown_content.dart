/// `ZFlashcardMarkdownContent` — seam rich-text opt-in du contenu d'une
/// carte.
///
/// Adaptateur mince : il compose `ZMarkdownReader` et `const ZMarkdownCodec()`
/// de `zcrud_markdown` tels quels. Aucun nouveau codec, aucune heuristique
/// de format, aucun `QuillController`/`Delta` construit à la main.
///
/// Il vit chez le consommateur (`zcrud_flashcard`), jamais dans
/// `zcrud_markdown` : l'arête autorisée est `zcrud_flashcard →
/// zcrud_markdown` (elle préexiste). L'inverse créerait un cycle (invariant
/// AD-1). Cet adaptateur ne coûte donc aucune nouvelle arête de graphe.
///
/// Le texte de la carte est lui-même la source markdown : `ZMarkdownCodec.decode`
/// transforme la source markdown en ops Delta. Aucune clé persistée
/// nouvelle, aucun élargissement du typedef de slot.
///
/// Opt-in : le défaut de `ZFlashcardReviewCard` reste le
/// texte brut thématisé du slot de contenu par défaut. Une application qui
/// n'injecte pas ce builder ne construit aucun widget Quill : aucun
/// `QuillEditor`, aucun `Document`, aucun décodage Delta n'est monté sur le
/// chemin par défaut.
///
/// Ce que l'opt-in n'est pas : il ne ferme pas le graphe de dépendances.
/// `zcrud_flashcard → zcrud_markdown → flutter_quill` est une arête runtime
/// dure du pubspec, présente que ce builder soit injecté ou non. L'opt-in
/// porte sur le rendu (le coût payé à l'exécution), jamais sur la fermeture
/// de dépendances. Le défaut, lui, n'importe réellement rien de riche.
///
/// Le LaTeX est rendu sans recâblage : `ZMarkdownReader` monte déjà les
/// builders d'embeds (LaTeX/tableaux).
///
/// Invariant AD-10 : une source markdown mal formée ne casse jamais le
/// rendu (`ZMarkdownCodec.decode` retombe sur une liste vide, jamais une
/// exception).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'z_flashcard_content_slot.dart' show ZFlashcardContentBuilder;

/// Clé l10n du placeholder d'un contenu de carte vide.
const String _kEmptyContentKey = 'zcrud.flashcard.emptyContent';

/// Rendu rich-text opt-in (markdown/LaTeX) d'un contenu de carte.
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

  /// Source markdown/LaTeX — le texte de la carte lui-même, décodé en ops
  /// Delta par `ZMarkdownCodec` (défensif : mal formé ⇒ rendu vide).
  final String content;

  /// Texte affiché quand [content] est vide (repli l10n si `null`).
  final String? placeholder;

  /// Fabrique un [ZFlashcardContentBuilder] opt-in — voie d'usage
  /// applicatif.
  ///
  /// Le défaut de `ZFlashcardReviewCard` reste le texte brut si ce builder
  /// n'est pas passé.
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
