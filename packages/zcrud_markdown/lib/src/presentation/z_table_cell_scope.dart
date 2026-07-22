/// Interprétation du contenu d'une cellule de tableau — opt-in (AD-57).
///
/// La charge d'un embed tableau est `List<List<String>>` : des chaînes. Ce scope
/// ne change **ni la charge, ni le format persisté** — il change seulement la
/// façon dont une cellule est LUE au rendu. Rien à migrer, et la bascule est
/// réversible dans les deux sens.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_codec.dart';

/// Comment le contenu d'une cellule de tableau doit être interprété.
enum ZTableCellContent {
  /// Texte brut — le comportement HISTORIQUE, et le défaut.
  ///
  /// Une cellule contenant `- a` affiche littéralement `- a`.
  plainText,

  /// **Document Markdown complet**, décodé pour son propre compte.
  ///
  /// Une cellule est un document à part entière, pas de l'inline inséré dans le
  /// document extérieur : elle porte donc des **blocs** — listes (imbriquées
  /// comprises), cases à cocher, blocs de code, citations, titres, paragraphes
  /// multiples — et les embeds que les ponts déclarés savent produire, formules
  /// LaTeX inline **et bloc** comprises.
  ///
  /// ⚠️ **C'est un pont : le sens d'un texte ordinaire change.** Une cellule
  /// contenant `- a` devient une puce, `*x*` devient de l'italique. Sur un
  /// corpus écrit à l'époque du texte brut, l'apparence peut donc bouger. C'est
  /// pour cela que ce mode se déclare et ne s'active jamais tout seul.
  markdown,
}

/// Diffuse le mode d'interprétation des cellules au sous-arbre.
///
/// **Absent ⇒ [ZTableCellContent.plainText]** : un hôte qui ne fait rien garde
/// exactement le rendu d'avant.
///
/// ```dart
/// ZTableCellScope(
///   content: ZTableCellContent.markdown,
///   codec: ZMarkdownCodec(bridges: ZMarkdownBridges.latex),
///   child: monEditeur,
/// )
/// ```
class ZTableCellScope extends InheritedWidget {
  const ZTableCellScope({
    required this.content,
    required super.child,
    this.codec,
    super.key,
  });

  /// Interprétation appliquée aux cellules descendantes.
  final ZTableCellContent content;

  /// Codec de décodage d'une cellule. `null` ⇒ repli sur le
  /// `ZMarkdownCodecScope` hérité, puis sur `ZMarkdownCodec()`.
  ///
  /// C'est ce codec qui porte les **ponts** : les déclarer ici suffit à ce
  /// qu'une formule écrite dans une cellule soit rendue comme telle.
  final ZCodec? codec;

  /// Scope hérité le plus proche, ou `null`.
  static ZTableCellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZTableCellScope>();

  /// Mode hérité, `plainText` par défaut (AD-10 : jamais de throw sur absence).
  static ZTableCellContent contentOf(BuildContext context) =>
      maybeOf(context)?.content ?? ZTableCellContent.plainText;

  @override
  bool updateShouldNotify(ZTableCellScope oldWidget) =>
      content != oldWidget.content || codec != oldWidget.codec;
}
