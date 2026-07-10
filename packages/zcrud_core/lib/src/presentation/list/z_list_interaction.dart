/// Pont d'**interaction** neutre entre `DynamicList` et un `ZListRenderer`
/// (E4-4, AD-8/SM-5).
///
/// origine: E4-4. Porte la **sélection** (mode + `id` sélectionnés + callback de
/// changement) et le **résolveur d'actions par ligne** (`actionsFor`) — déjà
/// filtrées/résolues par l'ACL dans `DynamicList` (le renderer ne voit ni `T` ni
/// `ZAcl`). Passé en **paramètre nommé optionnel** de `ZListRenderer.build`.
///
/// **Pourquoi SÉPARÉ de `ZListRenderRequest`** : ce dernier a une **égalité de
/// valeur profonde** (E4-1/E4-2) exploitée par les tests et la mémoïsation ; y
/// injecter des **callbacks** (`onSelectionChanged`, `actionsFor`) la casserait
/// (les fonctions ne sont pas comparables). Ce pont vit donc à côté, hors du
/// value object — additif et **rétro-compatible** (les renderers E4-1 ignorent
/// le paramètre).
///
/// **Neutre** : imports limités à `package:flutter/foundation.dart` (`@immutable`)
/// + types `zcrud_core`. AUCUN `package:syncfusion`, AUCUN gestionnaire d'état.
library;

import 'package:flutter/foundation.dart';

import 'z_list_render_request.dart';
import 'z_list_selection.dart';
import 'z_row_action.dart';

/// Bundle d'interaction **neutre** consommé par un `ZListRenderer` (E4-4).
///
/// - [mode] : mode de sélection (`none`/`single`/`multiple`) → pilote le
///   `selectionMode` du backend ;
/// - [selectedIds] : instantané des `id` sélectionnés (le renderer initialise sa
///   sélection interne dessus, à chaque rebuild) ;
/// - [onSelectionChanged] : remontée de la sélection utilisateur (le backend
///   appelle avec le nouvel ensemble d'`id`) ; `null` si sélection désactivée ;
/// - [actionsFor] : résout les actions **déjà filtrées/liées** d'une ligne
///   (`ZResolvedRowAction`, sans `T`) ; `null` si aucune action.
@immutable
class ZListInteraction {
  /// Construit le pont d'interaction neutre.
  const ZListInteraction({
    this.mode = ZListSelectionMode.none,
    this.selectedIds = const <String>{},
    this.onSelectionChanged,
    this.actionsFor,
  });

  /// Mode de sélection demandé par l'hôte.
  final ZListSelectionMode mode;

  /// Instantané des `id` sélectionnés (source de vérité = `DynamicList`).
  final Set<String> selectedIds;

  /// Remontée de la sélection utilisateur (nouvel ensemble d'`id`), ou `null`.
  final void Function(Set<String> selectedIds)? onSelectionChanged;

  /// Résolveur d'actions **résolues** (neutres) par ligne, ou `null`.
  final List<ZResolvedRowAction> Function(ZListRow row)? actionsFor;
}
