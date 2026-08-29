/// `ZSkeleton` — l'attente **en forme du contenu à venir**, sans dépendance.
///
/// Un `CircularProgressIndicator` dit qu'il se passe quelque chose ; un
/// squelette dit **ce qui arrive** — une ligne, une vignette, une liste de
/// tuiles — et évite le saut de mise en page au moment où la donnée se pose.
/// C'est la seule raison d'être de ce composant.
///
/// ## Aucune couleur inventée (FR-26)
///
/// Les deux teintes du battement sont des **rôles Material 3** lus sur le
/// `ColorScheme` ambiant (`surfaceContainerHighest` et `surfaceContainerHigh`).
/// Ce fichier ne porte aucun littéral de couleur, aucune opacité magique, et
/// ne dépend d'aucun paquet tiers de squelette : la teinte suit le thème de
/// l'hôte, clair comme sombre, sans réglage.
///
/// ## L'animation est bornée
///
/// Le battement est confié à `ZColorCycle` : un seul `AnimationController`,
/// créé **uniquement** quand le squelette est actif, libéré dès qu'il ne l'est
/// plus ou que le widget quitte l'arbre. Sous « Réduire les animations »
/// (`MediaQuery.disableAnimations`), aucun contrôleur n'est créé et la forme
/// reste peinte, fixe : l'attente doit rester visible pour qui a désactivé le
/// mouvement.
///
/// ## Muet pour les lecteurs d'écran
///
/// Un squelette est du bruit visuel : il est enveloppé d'`ExcludeSemantics`.
/// L'annonce de l'attente appartient à l'écran qui l'affiche — canoniquement
/// le `Semantics(liveRegion:)` de `ZLoadingState`. Deux annonces concurrentes
/// vaudraient moins qu'une.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Forme rendue par un [ZSkeleton].
enum _ZSkeletonKind {
  /// Une barre de texte.
  line,

  /// Un rectangle plein (vignette, image, carte).
  box,

  /// Une tuile de liste : un carré en tête, des lignes à côté.
  tile,
}

/// Placeholder animé **en forme du contenu attendu**.
///
/// Trois formes, choisies par constructeur nommé : [ZSkeleton.line],
/// [ZSkeleton.box], [ZSkeleton.tile]. Aucune ne connaît de couleur : elles
/// peignent les rôles `surfaceContainer*` du thème ambiant.
class ZSkeleton extends StatelessWidget {
  const ZSkeleton._(
    this._kind, {
    this.width,
    this.height,
    this.borderRadius,
    this.leadingSize = defaultLeadingSize,
    this.lines = 2,
    this.period = defaultPeriod,
    this.active = true,
    super.key,
  });

  /// Une **barre de texte**. [width] nul occupe la largeur disponible.
  const ZSkeleton.line({
    double? width,
    double height = defaultLineHeight,
    BorderRadius? borderRadius,
    Duration period = defaultPeriod,
    bool active = true,
    Key? key,
  }) : this._(
         _ZSkeletonKind.line,
         width: width,
         height: height,
         borderRadius: borderRadius,
         period: period,
         active: active,
         key: key,
       );

  /// Un **rectangle plein** (vignette, image, carte). Dimensions nulles :
  /// la forme prend la place que lui laisse son parent.
  const ZSkeleton.box({
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Duration period = defaultPeriod,
    bool active = true,
    Key? key,
  }) : this._(
         _ZSkeletonKind.box,
         width: width,
         height: height,
         borderRadius: borderRadius,
         period: period,
         active: active,
         key: key,
       );

  /// Une **tuile de liste** : un carré arrondi en tête, [lines] barres à côté.
  const ZSkeleton.tile({
    double leadingSize = defaultLeadingSize,
    int lines = 2,
    double height = defaultLineHeight,
    BorderRadius? borderRadius,
    Duration period = defaultPeriod,
    bool active = true,
    Key? key,
  }) : this._(
         _ZSkeletonKind.tile,
         height: height,
         borderRadius: borderRadius,
         leadingSize: leadingSize,
         lines: lines,
         period: period,
         active: active,
         key: key,
       );

  /// Hauteur de référence d'une barre de texte, en dp.
  static const double defaultLineHeight = 12;

  /// Côté de référence du carré de tête d'une tuile, en dp.
  static const double defaultLeadingSize = 40;

  /// Rythme de référence entre les éléments d'une tuile, en dp.
  static const double defaultGap = 12;

  /// Arrondi de référence des barres, en dp.
  static const double defaultRadius = 6;

  /// Durée d'un **battement complet**.
  ///
  /// Publique parce que c'est le défaut documenté : un hôte qui veut « le même
  /// rythme, un peu plus lent » a besoin du point de départ. Une durée nulle
  /// ou négative fige la teinte sans rien casser.
  static const Duration defaultPeriod = Duration(milliseconds: 1200);

  /// Forme rendue.
  final _ZSkeletonKind _kind;

  /// Largeur imposée, ou `null` pour occuper la place disponible.
  final double? width;

  /// Hauteur imposée, ou `null` pour occuper la place disponible.
  final double? height;

  /// Arrondi, ou `null` pour l'arrondi de référence ([defaultRadius]).
  final BorderRadius? borderRadius;

  /// Côté du carré de tête d'une tuile.
  final double leadingSize;

  /// Nombre de barres d'une tuile.
  final int lines;

  /// Durée d'un battement complet.
  final Duration period;

  /// Le squelette bat-il ? `false` peint la forme, fixe, **sans** créer le
  /// moindre contrôleur d'animation.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    // Deux rôles M3 voisins : le battement reste lisible sans jamais devenir
    // un clignotement, et suit le thème clair comme sombre.
    final Color base = scheme.surfaceContainerHighest;
    final Color highlight = scheme.surfaceContainerHigh;
    return ExcludeSemantics(
      child: ZColorCycle(
        palette: <Color>[base, highlight],
        period: period,
        active: active,
        idle: base,
        builder: (BuildContext context, Color? color, Widget? child) =>
            _paint(color ?? base),
      ),
    );
  }

  Widget _paint(Color color) {
    final BorderRadius radius =
        borderRadius ?? BorderRadius.circular(defaultRadius);
    switch (_kind) {
      case _ZSkeletonKind.line:
      case _ZSkeletonKind.box:
        return _bar(color, radius, width: width, height: height);
      case _ZSkeletonKind.tile:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _bar(
              color,
              BorderRadius.circular(leadingSize / 2),
              width: leadingSize,
              height: leadingSize,
            ),
            const SizedBox(width: defaultGap),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < lines; i++) ...<Widget>[
                    if (i > 0) SizedBox(height: (height ?? defaultLineHeight)),
                    // La dernière barre est plus courte : une liste de barres
                    // toutes égales lit comme une grille, pas comme du texte.
                    FractionallySizedBox(
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: i == lines - 1 && lines > 1 ? 0.6 : 1.0,
                      child: _bar(
                        color,
                        radius,
                        height: height ?? defaultLineHeight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
    }
  }

  Widget _bar(
    Color color,
    BorderRadius radius, {
    double? width,
    double? height,
  }) => SizedBox(
    width: width,
    height: height,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius),
    ),
  );
}

/// Liste de squelettes — l'attente d'une liste, en forme de liste.
///
/// Virtualisée (`ListView.builder`, jamais `ListView(children:)`) : une attente
/// n'a aucune raison de coûter plus cher que le contenu qu'elle annonce.
/// L'ensemble est muet pour les lecteurs d'écran, comme chaque [ZSkeleton].
class ZSkeletonList extends StatelessWidget {
  /// Construit une liste de [count] squelettes.
  ///
  /// [itemBuilder] permet de substituer la forme d'une ligne ; à défaut,
  /// chaque ligne est une [ZSkeleton.tile].
  const ZSkeletonList({
    required this.count,
    this.itemBuilder,
    this.padding,
    this.itemSpacing = ZSkeleton.defaultGap,
    this.period = ZSkeleton.defaultPeriod,
    this.active = true,
    this.shrinkWrap = false,
    this.physics,
    super.key,
  });

  /// Nombre de lignes rendues. Une valeur nulle ou négative rend une liste
  /// vide plutôt qu'une erreur (repli sûr, invariant AD-10).
  final int count;

  /// Constructeur de ligne, ou `null` pour une [ZSkeleton.tile].
  final IndexedWidgetBuilder? itemBuilder;

  /// Retrait de la liste.
  final EdgeInsetsGeometry? padding;

  /// Écart vertical entre deux lignes, en dp.
  final double itemSpacing;

  /// Durée d'un battement complet, transmise aux lignes par défaut.
  final Duration period;

  /// Les lignes battent-elles ?
  final bool active;

  /// La liste se dimensionne-t-elle sur son contenu ?
  final bool shrinkWrap;

  /// Physique de défilement, ou `null` pour celle de la plateforme.
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final int safeCount = count > 0 ? count : 0;
    return ExcludeSemantics(
      child: ListView.builder(
        padding: padding,
        shrinkWrap: shrinkWrap,
        physics: physics,
        itemCount: safeCount,
        itemBuilder: (BuildContext context, int index) => Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: index == safeCount - 1 ? 0 : itemSpacing,
          ),
          child:
              itemBuilder?.call(context, index) ??
              ZSkeleton.tile(period: period, active: active),
        ),
      ),
    );
  }
}
