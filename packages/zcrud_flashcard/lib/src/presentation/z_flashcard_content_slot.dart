/// Slot de rendu de CONTENU de carte — contrat + défaut sûr (SU-1, AC4 — AD-40).
///
/// **Ce que ce fichier livre** : le **contrat** d'injection
/// ([ZFlashcardContentBuilder]) et son **défaut texte brut thématisé**
/// ([ZFlashcardDefaultContent]) — rien de plus. L'**adaptateur markdown/LaTeX
/// prêt à injecter n'est PAS ici** : il relève de su-2, et il vivra dans
/// `zcrud_flashcard` (jamais dans `zcrud_markdown` — ce serait un **cycle**,
/// AD-1).
///
/// **Pourquoi le défaut est du texte brut** (AD-40/AD-4) : le chemin par défaut
/// ne doit atteindre **aucun** rendu riche. Le rendu riche est une **injection**
/// de l'app hôte ; un consommateur qui ne l'injecte pas ne **construit** aucun
/// widget Quill (il n'en paie donc pas le coût d'exécution). ⚠️ Cela ne ferme pas
/// le **graphe** : `zcrud_flashcard → zcrud_markdown → flutter_quill` reste une
/// arête runtime dure du pubspec — l'opt-in porte sur le **rendu**, pas sur la
/// fermeture de dépendances.
/// Aucun type `Quill`/`flutter_math_fork` n'apparaît dans une signature publique
/// (AD-7/AD-40) — la garde de source `z_flashcard_rich_type_leak_test.dart`
/// ROUGIT sinon.
///
/// **Patron repris à l'identique de `ZMindmapNodeContentBuilder`**
/// (`z_mindmap_view_config.dart`) : même forme de typedef, même défaut
/// thématisé, même tear-off statique stable (pas de closure réallouée à chaque
/// build). Les deux slots AD-40 du repo restent ainsi symétriques.
///
/// ⚠️ **Foyer du slot** : il n'existe **aucun ancêtre commun** à
/// `zcrud_flashcard` et `zcrud_mindmap` hors `zcrud_core` — interdit d'écriture
/// à toute story SU. Le slot est donc défini **par package consommateur** ;
/// `zcrud_mindmap` a déjà le sien et n'est pas retouché ici.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Constructeur injectable du **contenu** d'une carte (question/réponse).
///
/// Reçoit le **texte de contenu** et retourne le widget de rendu. Défaut sûr
/// fourni quand l'app n'injecte rien ([ZFlashcardDefaultContent], texte brut
/// thématisé) — le défaut **ne dépend pas** de `zcrud_markdown` : le rendu riche
/// est une injection de l'app hôte (AD-4/AD-40).
///
/// **Au juste besoin** : le slot reçoit le **texte**, pas la carte entière.
/// `ZFlashcardContent` n'existe pas ; si su-2 démontre le besoin de la carte
/// complète, l'enrichissement lui appartient (extension **additive**).
typedef ZFlashcardContentBuilder = Widget Function(
  BuildContext context,
  String content,
);

/// Défaut sûr : rendu **texte brut THÉMATISÉ** d'un contenu de carte (AD-40).
///
/// Couleur issue de `ZcrudTheme` (repli `Theme.of` — FR-26/NFR-SU4) : **aucune**
/// couleur ni libellé en dur. `TextAlign.start` (RTL-safe, AD-13). Ne rend
/// **jamais** de markdown/LaTeX : un contenu riche s'affiche tel quel, en texte.
class ZFlashcardDefaultContent extends StatelessWidget {
  /// Construit le rendu par défaut de [content].
  const ZFlashcardDefaultContent({required this.content, super.key});

  /// Texte de contenu rendu **verbatim** (jamais interprété).
  final String content;

  /// Tear-off **statique stable** conforme à [ZFlashcardContentBuilder] — à
  /// utiliser comme défaut d'un widget (`builder ?? ZFlashcardDefaultContent.builder`).
  ///
  /// Statique **par nécessité de perf** (AD-2/SM-1) : une closure `(c, s) =>
  /// ZFlashcardDefaultContent(content: s)` serait **réallouée à chaque build**,
  /// changerait d'identité et casserait la stabilité des rebuilds — patron
  /// `_defaultContent` de `z_mindmap_view.dart`.
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
