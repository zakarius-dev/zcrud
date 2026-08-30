/// `ZSubfolderNav` — la BASCULE responsive de navigation de sous-dossiers,
/// utilisable seule.
///
/// Les deux surfaces existent déjà (`ZSubfolderNarrowNav` sous le seuil,
/// `ZSubfolderSidebar` au-dessus). Ce widget porte la seule chose qui manquait
/// pour s'en servir hors d'une ossature complète : **la règle qui choisit entre
/// elles**, mesurée sur la largeur LOCALE (`LayoutBuilder`) et non sur la
/// fenêtre — la bonne disposition en split-view, master-detail ou dans une
/// colonne de `Row`.
///
/// ## Ce que ce widget DÉCIDE
///
/// - **Quelle variante est montée**, selon [sidebarBreakpoint] (défaut :
///   `ZWindowSizeThresholds.mediumMinWidth`).
/// - **L'exclusivité** : au plus une variante est instanciée, jamais les deux.
///   Les builders sont paresseux, la variante écartée n'est donc pas construite
///   — la sélection n'a jamais deux surfaces concurrentes.
/// - **L'assemblage**, quand [bodyBuilder] est fourni : `Column` (surface
///   étroite au-dessus du corps) ou `Row` (barre latérale au côté start du
///   corps), le corps prenant la place restante.
///
/// ## Ce que ce widget NE DÉCIDE PAS
///
/// - **La taille de la barre latérale**, ni son repli, ni ses bornes de
///   redimensionnement : [sidebarBuilder] est fourni par l'appelant, qui pose
///   lui-même la contrainte de largeur (cf. `ZSubfolderSidebar.width`, qui
///   annonce et fait glisser la poignée mais ne contraint aucun layout). Ce
///   widget n'ajoute aucune contrainte autour de ce que le builder rend.
/// - **L'état de sélection** : il n'est ni détenu ni recopié ici — [selected]
///   est une tranche réactive lue par les surfaces, [onSelect] la remonte
///   (AD-2).
/// - **La surface étroite**, si [narrowBuilder] est fourni ; à défaut, le socle
///   rend `ZSubfolderNarrowNav`, qui aiguille lui-même vers la coquille de
///   l'hôte ou la surface correspondant à `ZSubfolderNavSpec.narrowMode`.
///
/// ## Sans corps
///
/// [bodyBuilder] absent ⇒ ce widget rend **la variante seule**, sans `Row` ni
/// `Column` : un appelant qui tient déjà sa propre coquille place la surface
/// où il veut et ne récupère que la règle et l'exclusivité.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZWindowSizeThresholds;

import 'z_subfolder_narrow_nav.dart';
import 'z_subfolder_nav_spec.dart';

/// Largeur locale à partir de laquelle la barre latérale remplace la surface
/// étroite, en dp.
///
/// C'est le plancher du palier « medium » des classes de taille de fenêtre :
/// la bascule des sous-dossiers ne définit pas un seuil qui lui serait propre.
const double kZSubfolderSidebarBreakpoint =
    ZWindowSizeThresholds.mediumMinWidth;

/// **Unique** source de la règle de bascule : `true` ⇒ barre latérale,
/// `false` ⇒ surface étroite.
///
/// La mesure porte sur [availableWidth] — la largeur allouée au conteneur —, et
/// sur rien d'autre. [breakpoint] `null` ⇒ [kZSubfolderSidebarBreakpoint]. La
/// comparaison est **inclusive** : à largeur exactement égale au seuil, la barre
/// latérale l'emporte.
///
/// Grandeur directionnellement neutre : la réponse est identique en LTR et en
/// RTL à largeur égale (AD-13).
bool zSubfolderNavPrefersSidebar(double availableWidth, {double? breakpoint}) =>
    availableWidth >= (breakpoint ?? kZSubfolderSidebarBreakpoint);

/// Bascule responsive entre surface étroite et barre latérale de sous-dossiers.
class ZSubfolderNav extends StatelessWidget {
  /// Construit la bascule.
  ///
  /// [sidebarBuilder] est REQUIS : la barre latérale — et donc sa largeur, son
  /// repli et ses bornes — appartient à l'appelant.
  const ZSubfolderNav({
    required this.spec,
    required this.selected,
    required this.onSelect,
    required this.sidebarBuilder,
    this.narrowBuilder,
    this.bodyBuilder,
    this.sidebarBreakpoint,
    super.key,
  });

  /// Descripteur de navigation (données + libellés, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Tranche réactive de sélection (`null` = item racine « tous »).
  final ValueListenable<String?> selected;

  /// Émis quand un item est choisi (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  /// Construit la barre latérale, contrainte de largeur COMPRISE.
  ///
  /// Invoqué **uniquement** au-dessus du seuil, et à ce moment-là seulement.
  final WidgetBuilder sidebarBuilder;

  /// Construit la surface étroite. `null` ⇒ `ZSubfolderNarrowNav` construit
  /// depuis [spec]/[selected]/[onSelect].
  ///
  /// Invoqué **uniquement** sous le seuil.
  final WidgetBuilder? narrowBuilder;

  /// Construit le corps que la navigation accompagne.
  ///
  /// `null` ⇒ aucune enveloppe : ce widget rend la variante seule.
  final WidgetBuilder? bodyBuilder;

  /// Seuil de bascule en dp. `null` ⇒ [kZSubfolderSidebarBreakpoint].
  final double? sidebarBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Une seule branche est parcourue : la variante écartée n'est jamais
        // instanciée, ce qui rend l'exclusivité structurelle plutôt que
        // conditionnelle à l'affichage.
        if (zSubfolderNavPrefersSidebar(
          constraints.maxWidth,
          breakpoint: sidebarBreakpoint,
        )) {
          final Widget sidebar = sidebarBuilder(context);
          final Widget? body = bodyBuilder?.call(context);
          if (body == null) return sidebar;
          return Row(
            children: <Widget>[sidebar, Expanded(child: body)],
          );
        }
        final Widget narrow =
            narrowBuilder?.call(context) ??
            ZSubfolderNarrowNav(
              spec: spec,
              selected: selected,
              onSelect: onSelect,
            );
        final Widget? body = bodyBuilder?.call(context);
        if (body == null) return narrow;
        return Column(
          children: <Widget>[narrow, Expanded(child: body)],
        );
      },
    );
  }
}
