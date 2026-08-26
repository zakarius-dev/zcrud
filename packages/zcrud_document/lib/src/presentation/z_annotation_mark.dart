/// `ZAnnotationMark` — rendu d'un passage marqué, une apparence par nature
/// d'annotation.
///
/// Le socle ne dessine pas la page du document (c'est la visionneuse de
/// l'hôte qui la peint) : il rend le **passage** et fixe, pour chaque
/// `ZDocumentAnnotationKind`, l'apparence canonique du marquage —
/// surlignage plein, soulignage, barrage, soulignage ondulé — de sorte que
/// deux hôtes ne réinventent pas deux conventions divergentes.
///
/// ## Une apparence observable par nature
///
/// | Nature | Fond | Décoration | Style de trait |
/// |---|---|---|---|
/// | `highlight` | rempli | aucune | — |
/// | `stickyNote` | aucun | aucune | — |
/// | `underline` | aucun | `underline` | `solid` |
/// | `strikethrough` | aucun | `lineThrough` | `solid` |
/// | `squiggly` | aucun | `underline` | `wavy` |
///
/// Les cinq triplets sont deux à deux distincts : la nature se lit sur le
/// rendu, pas seulement dans la donnée.
///
/// ## Couleur et épaisseur injectées (FR-26)
///
/// La teinte vient de `ZcrudScope.colorKeyResolver`
/// (`zResolveColorKeyOrSlot`, repli total sur le `ColorScheme` courant,
/// invariant AD-10) — jamais un hex en dur. L'épaisseur du trait est
/// facultative : `null` ⇒ l'épaisseur propre de la police du style
/// résolu, donc celle du thème de l'hôte ; aucune valeur numérique n'est
/// figée par le socle.
///
/// ## Accessibilité (invariant AD-13)
///
/// La nature du marquage est **annoncée** : voir [announceKind].
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_document_annotation_kind.dart';

/// Préfixe de [ValueKey] du `Text` rendu par [ZAnnotationMark]
/// (`zAnnotationMark_<name>`) — permet de lire le `TextStyle` réellement
/// appliqué (décoration, style de trait, fond) plutôt que la seule présence
/// du widget.
const String kAnnotationMarkKeyPrefix = 'zAnnotationMark_';

/// Passage de texte rendu selon sa nature d'annotation (présentation).
class ZAnnotationMark extends StatelessWidget {
  /// Construit le rendu d'un passage marqué.
  ///
  /// - [text] : le passage tel qu'il doit être lu ;
  /// - [kind] : la nature du marquage (défaut
  ///   [ZDocumentAnnotationKind.highlight], repli défensif du domaine) ;
  /// - [colorKey] : clé de couleur symbolique brute, résolue à l'affichage
  ///   (`''` ⇒ repli sur le slot [slotIndex] du `ColorScheme`) ;
  /// - [slotIndex] : index de repli quand la clé est inconnue de l'hôte ;
  /// - [thickness] : multiplicateur d'épaisseur du trait (`null` ⇒
  ///   l'épaisseur propre de la police) ;
  /// - [style] : style de base (`null` ⇒ `bodyMedium` du thème) ;
  /// - [announceKind] : voir la propriété.
  const ZAnnotationMark({
    required this.text,
    this.kind = ZDocumentAnnotationKind.highlight,
    this.colorKey = '',
    this.slotIndex = 0,
    this.thickness,
    this.style,
    this.maxLines,
    this.announceKind = true,
    super.key,
  });

  /// Passage marqué.
  final String text;

  /// Nature du marquage.
  final ZDocumentAnnotationKind kind;

  /// Clé de couleur symbolique brute (invariant AD-4 : jamais une couleur).
  final String colorKey;

  /// Index de slot de repli quand [colorKey] est inconnue de l'hôte.
  final int slotIndex;

  /// Multiplicateur d'épaisseur du trait (`null` ⇒ épaisseur de la police).
  final double? thickness;

  /// Style de base du passage (`null` ⇒ `bodyMedium` du thème).
  final TextStyle? style;

  /// Nombre maximal de lignes rendues (`null` ⇒ non borné).
  final int? maxLines;

  /// Annonce la nature du marquage aux technologies d'assistance.
  ///
  /// Vrai par défaut : la nature d'un marquage est une **donnée saisie par
  /// le lecteur**, pas une décoration. Un passage barré et un passage
  /// souligné ne disent pas la même chose du texte qu'ils portent, et cette
  /// différence ne circule que par le trait — un lecteur d'écran qui ne
  /// l'annonce pas restitue les deux passages à l'identique.
  ///
  /// Mettre à `false` quand le marquage est déjà annoncé par le conteneur
  /// (une liste d'annotations qui énonce la nature de chaque entrée) : la
  /// répéter à l'intérieur ne ferait qu'allonger la lecture.
  final bool announceKind;

  @override
  Widget build(BuildContext context) {
    // Teinte injectée : seam hôte → repli ColorScheme (invariant AD-10),
    // jamais un hex en dur (FR-26).
    final ZColorPair pair =
        zResolveColorKeyOrSlot(context, colorKey, slotIndex: slotIndex);
    final TextStyle base =
        style ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final _ZMarkAppearance appearance = _appearanceOf(kind);
    final TextStyle marked = base.copyWith(
      // Le fond n'est peint que pour le surlignage : les trois natures de
      // trait laissent le texte sur le fond de la page.
      backgroundColor: appearance.filled ? pair.color : base.backgroundColor,
      // Sur un fond rempli, le `on-` compagnon de la paire garantit le
      // contraste ; sinon la couleur du texte reste celle du thème.
      color: appearance.filled ? pair.onColor : base.color,
      decoration: appearance.decoration,
      decorationStyle: appearance.decorationStyle,
      decorationColor:
          appearance.decoration == TextDecoration.none ? null : pair.color,
      // `null` ⇒ épaisseur propre de la police (aucun nombre figé ici).
      decorationThickness: thickness,
    );

    final Widget rendered = Text(
      text,
      key: ValueKey<String>('$kAnnotationMarkKeyPrefix${kind.name}'),
      style: marked,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      textAlign: TextAlign.start,
    );

    if (!announceKind) return rendered;

    // Canal non-visuel de la nature : libellé injecté (`ZcrudScope.labels`),
    // repli sur le nom de la constante — jamais un libellé en dur.
    final String kindText = label(
      context,
      'zcrud.annotation.kind.${kind.name}',
      fallback: kind.name,
    );
    return Semantics(
      label: kindText,
      value: text,
      // Le `Text` porte déjà son propre nœud sémantique : sans exclusion, le
      // passage serait énoncé deux fois.
      child: ExcludeSemantics(child: rendered),
    );
  }
}

/// Apparence canonique d'une nature de marquage (fond + décoration).
class _ZMarkAppearance {
  const _ZMarkAppearance({
    required this.filled,
    required this.decoration,
    required this.decorationStyle,
  });

  final bool filled;
  final TextDecoration decoration;
  final TextDecorationStyle decorationStyle;
}

/// Apparence d'une nature. `switch` exhaustif : ajouter une nature sans lui
/// donner d'apparence ne compile pas.
_ZMarkAppearance _appearanceOf(ZDocumentAnnotationKind kind) {
  switch (kind) {
    case ZDocumentAnnotationKind.highlight:
      return const _ZMarkAppearance(
        filled: true,
        decoration: TextDecoration.none,
        decorationStyle: TextDecorationStyle.solid,
      );
    case ZDocumentAnnotationKind.stickyNote:
      // Une note ancrée ne marque pas le texte : son marqueur est un point
      // sur la page, dessiné par la visionneuse.
      return const _ZMarkAppearance(
        filled: false,
        decoration: TextDecoration.none,
        decorationStyle: TextDecorationStyle.solid,
      );
    case ZDocumentAnnotationKind.underline:
      return const _ZMarkAppearance(
        filled: false,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.solid,
      );
    case ZDocumentAnnotationKind.strikethrough:
      return const _ZMarkAppearance(
        filled: false,
        decoration: TextDecoration.lineThrough,
        decorationStyle: TextDecorationStyle.solid,
      );
    case ZDocumentAnnotationKind.squiggly:
      return const _ZMarkAppearance(
        filled: false,
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.wavy,
      );
  }
}
