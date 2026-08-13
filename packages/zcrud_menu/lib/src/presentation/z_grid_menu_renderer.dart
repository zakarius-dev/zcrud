/// [ZGridMenuRenderer] — le menu rendu en **grille de tuiles** plutôt qu'en
/// colonne, sans aucune dépendance tierce.
///
/// ## Pourquoi une grille est un renderer, et pas l'affaire de l'appelant
///
/// Un menu de dix ou onze actions rendu en colonne unique impose un long
/// défilement là où deux ou trois colonnes tiennent d'un coup d'œil. Cette
/// présentation-là se retrouve à l'identique dans plusieurs applications ; tant
/// qu'elle appartient à chaque hôte, chacun refait la même grille — et refait
/// avec elle les deux mêmes défauts d'accessibilité, mesurés sur un rendu réel :
///
/// * une cellule posée dans un `InkWell` sans plancher de taille, dont la
///   hauteur dérivait d'un `childAspectRatio`, tombait à **28,6 dp** — 60 % de
///   la cible minimale. Un enfant ne peut pas se rendre plus grand que la place
///   reçue : le plancher doit être tenu par la **DISPOSITION**, d'où
///   [ZMenuEntryTile.gridDelegate], et non par la cellule seule ;
/// * un `Semantics(label:)` dont le sous-arbre n'était pas exclu faisait
///   annoncer le libellé **deux fois** par le lecteur d'écran. Retirer le
///   `label:` ne corrige pas : le nœud devient muet. [ZMenuEntryTile] porte la
///   forme correcte (`label` + `excludeSemantics`).
///
/// Un troisième piège est propre à la grille : **aucun `InkWell` ne doit être
/// superposé** au détecteur de la cellule. Deux détecteurs empilés produisent
/// **DEUX invocations** de l'action pour un seul tap. La cellule porte son
/// geste, la grille ne pose rien.
///
/// ## Usage
///
/// ```dart
/// ZMenuScope(
///   renderer: const ZGridMenuRenderer(),        // 3 colonnes par défaut
///   child: monEcran,
/// )
/// ```
///
/// Tout est déclaratif : `ZGridMenuRenderer(columns: 2)` pour deux colonnes,
/// `tileExtent`/`width`/`spacing` pour la métrique. Une présentation injectée
/// par l'appelant (`ZActionMenu.contentBuilder`) reste prioritaire : ce
/// renderer ne fournit sa grille que là où rien n'est déclaré.
library;

import 'package:flutter/material.dart';

import '../domain/z_menu_entry.dart';
import 'z_default_menu_renderer.dart';
import 'z_menu_entry_tile.dart';
import 'z_menu_renderer.dart';
import 'z_menu_request.dart';
import 'z_menu_scope.dart';
import 'z_menu_surface.dart';

/// Nombre de colonnes par défaut de la grille de menu.
const int kZGridMenuColumns = 3;

/// Renderer de menu à contenu en **grille**, zéro dépendance tierce.
///
/// Même déclencheur, même surface et même voie de sélection que
/// [ZDefaultMenuRenderer] — seule la présentation du contenu change.
class ZGridMenuRenderer extends ZMenuRenderer {
  /// Construit le renderer en grille (`const` — identité stable pour les
  /// scopes, cf. [ZMenuScope]).
  ///
  /// [columns] : nombre de colonnes (défaut [kZGridMenuColumns]) ; borné par le
  /// bas à 1, une grille sans colonne n'ayant pas de sens.
  ///
  /// [tileExtent] : hauteur d'une cellule. Bornée par le bas à la cible tactile
  /// minimale par [ZMenuEntryTile.gridDelegate] — aucun appelant ne peut
  /// demander une cellule plus courte.
  ///
  /// [width] : largeur de la surface de contenu (la grille se dimensionne en
  /// hauteur sur son contenu).
  ///
  /// [spacing] : espacement entre cellules, dans les deux axes.
  ///
  /// [padding] : marge intérieure de la grille (directionnelle).
  const ZGridMenuRenderer({
    this.columns = kZGridMenuColumns,
    this.tileExtent = 72,
    this.width = 280,
    this.spacing = 0,
    this.padding = const EdgeInsetsDirectional.all(8),
  });

  /// Nombre de colonnes demandé.
  final int columns;

  /// Hauteur d'une cellule (plancher de cible tactile appliqué).
  final double tileExtent;

  /// Largeur de la surface de contenu.
  final double width;

  /// Espacement entre cellules.
  final double spacing;

  /// Marge intérieure (directionnelle — invariant AD-13).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, ZMenuRequest request) =>
      const ZDefaultMenuRenderer().build(context, _withGrid(request));

  @override
  Future<void> openAt(
    BuildContext context,
    ZMenuRequest request,
    Offset globalPosition,
  ) =>
      zShowZMenuAt(
        context,
        request,
        globalPosition,
        contentBuilder: request.contentBuilder ?? _grid,
      );

  /// Requête dont le CONTENU est la grille — sauf si l'appelant a déclaré sa
  /// propre présentation, qui reste prioritaire. Le déclencheur, les entrées et
  /// la voie de sélection sont transmis intacts.
  ZMenuRequest _withGrid(ZMenuRequest request) => request.contentBuilder != null
      ? request
      : ZMenuRequest(
          trigger: request.trigger,
          entries: request.entries,
          select: request.select,
          contentBuilder: _grid,
        );

  /// Grille de cellules — présentation du CONTENU, jamais du déclencheur.
  ///
  /// `entries` est déjà filtrée par la règle d'absence (invariant AD-4) ;
  /// `select` est la voie de sortie UNIQUE (elle ferme la surface et invoque
  /// l'effet déclaré par l'appelant). Aucun détecteur n'est posé ici : la
  /// cellule porte le sien.
  Widget _grid(
    BuildContext context,
    List<ZMenuEntry> entries,
    void Function(ZMenuEntry entry) select,
  ) =>
      SizedBox(
        width: width,
        child: GridView(
          shrinkWrap: true,
          padding: padding,
          // Le plancher de 48 dp est tenu par la DISPOSITION : `mainAxisExtent`
          // est borné par le bas, et `childAspectRatio` — qui dérive la hauteur
          // de la largeur et peut tomber à n'importe quelle valeur — n'est
          // jamais consulté.
          gridDelegate: ZMenuEntryTile.gridDelegate(
            crossAxisCount: columns < 1 ? 1 : columns,
            mainAxisExtent: tileExtent,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
          ),
          children: <Widget>[
            for (final entry in entries)
              ZMenuEntryTile(
                key: ValueKey<String>('zGridMenuEntry_${entry.id}'),
                entry: entry,
                // UN SEUL détecteur : celui de la cellule. Aucun `InkWell`
                // n'est superposé ici — deux détecteurs empilés produiraient
                // DEUX invocations pour un seul tap.
                onSelected: () => select(entry),
                direction: Axis.vertical,
              ),
          ],
        ),
      );
}
