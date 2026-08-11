/// `ZSubfolderNarrowNav` — aiguillage de la navigation de sous-dossiers SOUS le
/// seuil de bascule (< 600 dp).
///
/// Trois chemins, dans cet ordre :
///
/// 1. **coquille de l'hôte** injectée via `ZSubfolderNavRendererScope` (seam de
///    SURFACE, chaîne totale — voir `z_subfolder_nav_renderer.dart`) ;
/// 2. [ZSubfolderNarrowMode.selector] — barre de sélection (**DÉFAUT**) ;
/// 3. [ZSubfolderNarrowMode.compact] — rangée de puces défilante.
///
/// Sans coquille injectée, le rendu est celui du mode demandé — l'existence de
/// ce seam ne change RIEN à un consommateur qui ne l'utilise pas.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

import 'z_subfolder_compact_selector.dart';
import 'z_subfolder_item_content.dart';
import 'z_subfolder_nav_renderer.dart';
import 'z_subfolder_nav_spec.dart';
import 'z_subfolder_selector_bar.dart';

/// Aiguille la navigation étroite vers la coquille de l'hôte ou la surface du
/// socle correspondant à [ZSubfolderNavSpec.narrowMode].
class ZSubfolderNarrowNav extends StatelessWidget {
  /// Construit l'aiguillage.
  const ZSubfolderNarrowNav({
    required this.spec,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  /// Descripteur de navigation (données + libellés, tout injecté).
  final ZSubfolderNavSpec spec;

  /// Tranche réactive de sélection (`null` = item racine).
  final ValueListenable<String?> selected;

  /// Émis quand un item est choisi (`null` pour la racine).
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final Widget? hosted = zResolveSubfolderNav(
      context,
      ZSubfolderNavRenderRequest(
        spec: spec,
        selected: selected,
        onSelect: onSelect,
        // La coquille d'hôte garde `allSubfoldersLabel` pour la racine, et
        // **ne reçoit AUCUNE `ZSubfolderSurface`** (`maybeOf` y rend
        // `null`). Ce n'est pas un oubli : le socle ne sait pas quelle
        // FORME la coquille rend — un déclencheur ? une liste ? les deux ?
        // Lui imposer `rootItemLabel` reviendrait à décider à sa place
        // laquelle des deux questions elle pose. La coquille détient sa
        // forme : elle lit `spec.rootItemLabel` elle-même si elle rend une
        // liste.
        itemContentBuilder: (context, refOrNull, isSelected) =>
            zBuildSubfolderItemContent(
              context,
              spec: spec,
              refOrNull: refOrNull,
              label: refOrNull?.label ?? spec.allSubfoldersLabel,
              selected: isSelected,
            ),
      ),
    );
    if (hosted != null) {
      // Le scope de mode est posé AU-DESSUS de la coquille de l'hôte : la
      // fabrique d'item qu'elle rappelle observe `compact` comme partout
      // ailleurs sous le seuil.
      return ZSubfolderLayoutScope(
        mode: ZSubfolderLayoutMode.compact,
        child: hosted,
      );
    }
    return switch (spec.narrowMode) {
      ZSubfolderNarrowMode.selector => ZSubfolderSelectorBar(
        spec: spec,
        selected: selected,
        onSelect: onSelect,
      ),
      ZSubfolderNarrowMode.compact => ZSubfolderCompactSelector(
        spec: spec,
        selected: selected,
        onSelect: onSelect,
      ),
    };
  }
}
