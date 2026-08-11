/// Slot de rendu de contenu de carte — contrat et défaut sûr.
///
/// Ce que ce fichier livre : le contrat d'injection
/// ([ZFlashcardContentBuilder]) et son défaut texte brut thématisé
/// ([ZFlashcardDefaultContent]) — rien de plus. L'adaptateur markdown/LaTeX
/// prêt à injecter n'est pas ici : c'est un ajout séparé (voir
/// `z_flashcard_markdown_content.dart`), qui vit dans `zcrud_flashcard`
/// (jamais dans `zcrud_markdown` — ce serait un cycle, invariant AD-1).
///
/// Pourquoi le défaut est du texte brut (invariant AD-4) : le chemin
/// par défaut ne doit atteindre aucun rendu riche. Le rendu riche est une
/// injection de l'application hôte ; un consommateur qui ne l'injecte pas
/// ne construit aucun widget Quill (il n'en paie donc pas le coût
/// d'exécution). Cela ne ferme pas le graphe de dépendances :
/// `zcrud_flashcard → zcrud_markdown → flutter_quill` reste une arête
/// runtime dure du pubspec — l'opt-in porte sur le rendu, pas sur la
/// fermeture de dépendances. Aucun type `Quill`/`flutter_math_fork`
/// n'apparaît dans une signature publique (invariant AD-7).
///
/// Patron repris à l'identique du slot de contenu équivalent de
/// `zcrud_mindmap` : même forme de typedef, même défaut thématisé, même
/// tear-off statique stable (pas de closure réallouée à chaque build).
///
/// Le slot est défini par paquet consommateur ; `zcrud_mindmap` a déjà le
/// sien et n'est pas retouché ici.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Constructeur injectable du contenu d'une carte (question/réponse).
///
/// Reçoit le texte de contenu et retourne le widget de rendu. Défaut sûr
/// fourni quand l'application n'injecte rien ([ZFlashcardDefaultContent],
/// texte brut thématisé) — le défaut ne dépend pas de `zcrud_markdown` : le
/// rendu riche est une injection de l'application hôte (invariant AD-4).
///
/// Au juste besoin : le slot reçoit le texte, pas la carte entière. Si un
/// besoin de la carte complète se démontre un jour, l'enrichissement lui
/// appartiendra (extension additive).
typedef ZFlashcardContentBuilder = Widget Function(
  BuildContext context,
  String content,
);

/// Défaut sûr : rendu texte brut thématisé d'un contenu de carte.
///
/// Couleur issue de `ZcrudTheme` (repli `Theme.of`) : aucune couleur ni
/// libellé en dur. `TextAlign.start` (RTL-safe, invariant AD-13). Ne rend
/// jamais de markdown/LaTeX : un contenu riche s'affiche tel quel, en texte.
class ZFlashcardDefaultContent extends StatelessWidget {
  /// Construit le rendu par défaut de [content].
  const ZFlashcardDefaultContent({required this.content, super.key});

  /// Texte de contenu rendu verbatim (jamais interprété).
  final String content;

  /// Tear-off statique stable conforme à [ZFlashcardContentBuilder] — à
  /// utiliser comme défaut d'un widget (`builder ?? ZFlashcardDefaultContent.builder`).
  ///
  /// Statique par nécessité de performance (invariant AD-2) : une closure
  /// serait réallouée à chaque build, changerait d'identité et casserait la
  /// stabilité des rebuilds — même patron que le slot de contenu
  /// équivalent de `zcrud_mindmap`.
  static Widget builder(BuildContext context, String content) =>
      ZFlashcardDefaultContent(content: content);

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final baseColor = theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      content,
      textAlign: TextAlign.start,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: baseColor) ??
          TextStyle(color: baseColor),
    );
  }
}
