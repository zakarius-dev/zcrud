/// `ZEmptyStateSpec` — un état vide **en données**, indexable par nature de
/// contenu.
///
/// Un écran qui affiche des dossiers, un autre des cartes, un troisième des
/// notes : chacun rend le même composant avec un glyphe, deux textes et parfois
/// une action. Décrire cela en **données** plutôt qu'en trois appels de
/// constructeur permet à l'hôte d'en tenir une table
/// (`Map<String, ZEmptyStateSpec>`) et de la traduire, l'auditer ou la servir
/// depuis son backend d'un seul tenant.
///
/// **La table appartient à l'appelant.** Ce paquet est transverse : il ne
/// nomme aucune nature de contenu et n'en fournit donc aucune entrée. Une
/// nature de contenu déclarée ici deviendrait une dépendance métier cachée du
/// kit d'UI.
library;

import 'package:flutter/widgets.dart';

/// Construit l'illustration d'un état vide.
///
/// Un `BuildContext` est fourni parce qu'une illustration réelle lit presque
/// toujours le thème, la locale ou la taille disponible ; la construire à
/// l'avance figerait ces trois lectures.
typedef ZEmptyStateIllustrationBuilder = Widget Function(BuildContext context);

/// Description **immuable** d'un état vide, par clés de libellé.
///
/// Les trois textes sont des **clés**, jamais des libellés : la spec traverse
/// les couches sans se traduire, et la résolution a lieu au rendu, contre le
/// registre effectivement monté.
@immutable
class ZEmptyStateSpec {
  /// Construit une spec. [titleKey] et [messageKey] sont requis — le message
  /// est le canal texte garanti, le titre le nomme.
  const ZEmptyStateSpec({
    required this.titleKey,
    required this.messageKey,
    this.iconData,
    this.actionLabelKey,
    this.illustrationBuilder,
  });

  /// Glyphe illustratif, ou `null` pour n'en afficher aucun. Ignoré quand
  /// [illustrationBuilder] est fourni.
  final IconData? iconData;

  /// Clé du titre.
  final String titleKey;

  /// Clé du message.
  final String messageKey;

  /// Clé du libellé d'action, ou `null` si cette nature de contenu n'offre
  /// aucune action.
  final String? actionLabelKey;

  /// Illustration **remplaçant** le glyphe, ou `null` pour garder [iconData].
  final ZEmptyStateIllustrationBuilder? illustrationBuilder;

  /// Copie modifiée. Un argument omis conserve la valeur courante ; passer
  /// `null` explicitement ne remet donc **pas** un membre à zéro — utiliser le
  /// constructeur pour cela.
  ZEmptyStateSpec copyWith({
    IconData? iconData,
    String? titleKey,
    String? messageKey,
    String? actionLabelKey,
    ZEmptyStateIllustrationBuilder? illustrationBuilder,
  }) => ZEmptyStateSpec(
    iconData: iconData ?? this.iconData,
    titleKey: titleKey ?? this.titleKey,
    messageKey: messageKey ?? this.messageKey,
    actionLabelKey: actionLabelKey ?? this.actionLabelKey,
    illustrationBuilder: illustrationBuilder ?? this.illustrationBuilder,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZEmptyStateSpec &&
          other.iconData == iconData &&
          other.titleKey == titleKey &&
          other.messageKey == messageKey &&
          other.actionLabelKey == actionLabelKey &&
          other.illustrationBuilder == illustrationBuilder;

  @override
  int get hashCode => Object.hash(
    iconData,
    titleKey,
    messageKey,
    actionLabelKey,
    illustrationBuilder,
  );

  @override
  String toString() =>
      'ZEmptyStateSpec(iconData: $iconData, titleKey: $titleKey, '
      'messageKey: $messageKey, actionLabelKey: $actionLabelKey, '
      'illustrationBuilder: ${illustrationBuilder == null ? 'null' : 'fourni'})';
}
