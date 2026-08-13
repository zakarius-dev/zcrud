/// `ZRowTint` — la **teinte d'une ligne**, décidée sur l'entité typée.
///
/// Sur un tableau de dépouillement, la couleur d'une ligne **porte
/// l'information** : c'est elle qui permet de balayer cent lignes d'un coup
/// d'œil pour repérer les convocations relancées, les rapports non rendus, les
/// dossiers clos. Une teinte n'est donc pas une décoration — c'est une donnée
/// affichée, et elle se déclare comme telle.
///
/// **La décision se prend sur l'entité, jamais sur une cellule formatée.** Le
/// seam `ZCrudScreen.rowColor` reçoit l'objet métier (`Convocation`,
/// `Rapport`…) : un renommage de champ devient une **erreur de compilation**,
/// là où une décision prise sur `row.cells['statut']` se contenterait de faire
/// disparaître la couleur en silence.
///
/// **La couleur seule n'est pas une information accessible** (invariant
/// AD-13) : un usager daltonien, un écran en plein soleil ou un lecteur
/// d'écran ne la reçoivent pas. C'est pourquoi la teinte transporte, dans le
/// même objet, le **libellé** qui la double ([semanticLabel]).
library;

import 'package:flutter/widgets.dart';

/// Teinte d'une ligne de liste, et le libellé qui la **double**.
///
/// ```dart
/// ZCrudScreen<Convocation>(
///   title: 'Convocations',
///   source: ZCrudSource.repository(repo),
///   registry: registry,
///   rowColor: (context, convocation) => switch (convocation.statut) {
///     Statut.relancee => ZRowTint(
///         Theme.of(context).colorScheme.errorContainer,
///         semanticLabel: 'convocation.relancee',
///       ),
///     Statut.repondue => ZRowTint(
///         Theme.of(context).colorScheme.secondaryContainer,
///         semanticLabel: 'convocation.repondue',
///       ),
///     _ => null, // aucune teinte : la ligne reste rendue telle quelle
///   },
/// )
/// ```
///
/// **Aucune couleur n'est codée dans zcrud** (invariant FR-26) : la teinte est
/// **entièrement** fournie par l'application, qui la dérive de son thème
/// (`Theme.of(context).colorScheme`, `ZcrudTheme`, `ThemeExtension`). Le
/// [BuildContext] passé au seam est là pour ça.
@immutable
class ZRowTint {
  /// Déclare la teinte [color] d'une ligne, doublée par [semanticLabel].
  const ZRowTint(this.color, {this.semanticLabel});

  /// Couleur peinte **derrière** la tuile de la ligne.
  ///
  /// Elle est posée en fond : la tuile — celle du paquet comme celle de
  /// l'application (`ZCrudScreen.itemBuilder`) — est rendue par-dessus,
  /// inchangée. Préférer un ton de **conteneur** du schéma de couleurs
  /// (`colorScheme.errorContainer`, `secondaryContainer`…) : le texte de la
  /// tuile garde alors son contraste, ce qu'une couleur vive ne garantit pas.
  final Color color;

  /// Le **doublage** de la couleur : ce que la teinte veut dire, en toutes
  /// lettres — clé l10n ou littéral (résolu via `label(context, …)`, repli sur
  /// le littéral).
  ///
  /// Renseigné, il est annoncé par les lecteurs d'écran sur la ligne teintée
  /// (`Semantics`), de sorte que l'information portée par la couleur reste
  /// accessible à qui ne la voit pas.
  ///
  /// 🔴 **Une information portée par la seule couleur est perdue** pour un
  /// usager daltonien, sur un écran en plein soleil, à l'impression et pour un
  /// lecteur d'écran. Renseigner ce libellé rend la teinte audible ; il reste à
  /// la rendre **visible** autrement, ce que seule la tuile peut faire — une
  /// icône, une pastille, un mot d'état dans `ZCrudScreen.itemBuilder` :
  ///
  /// ```dart
  /// itemBuilder: (context, convocation, columns) => ListTile(
  ///   // Le même état, dit trois fois : par la teinte, par l'icône, par le mot.
  ///   leading: Icon(convocation.statut.icone),
  ///   title: Text(convocation.objet),
  ///   subtitle: Text(convocation.statut.libelle),
  /// ),
  /// ```
  final String? semanticLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRowTint &&
          runtimeType == other.runtimeType &&
          color == other.color &&
          semanticLabel == other.semanticLabel;

  @override
  int get hashCode => Object.hash(runtimeType, color, semanticLabel);

  @override
  String toString() =>
      'ZRowTint($color, semanticLabel: ${semanticLabel ?? '<aucun>'})';
}

/// Décide la [ZRowTint] d'une ligne à partir de l'**entité typée** [entity].
///
/// Rend `null` quand la ligne n'a **aucune** teinte : elle est alors rendue
/// strictement telle qu'elle le serait sans ce seam. Le [BuildContext] permet
/// de dériver la couleur du thème ambiant (invariant FR-26 : aucune couleur
/// codée en dur, ni dans zcrud, ni dans l'application).
typedef ZRowTintBuilder<T> = ZRowTint? Function(
  BuildContext context,
  T entity,
);
