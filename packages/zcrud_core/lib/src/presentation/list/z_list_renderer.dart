/// Port de **rendu de liste** du cœur `zcrud_core` (abstraction pure — AD-8).
///
/// origine: E4-1. `zcrud_core` n'expose QUE cette abstraction ; le rendu concret
/// (`SfDataGrid` par défaut) vit **exclusivement** dans `zcrud_list`
/// (`ZSfDataGridRenderer`). Un consommateur qui n'importe pas `zcrud_list` (ex.
/// `zcrud_markdown` seul) ne tire donc AUCUNE dépendance Syncfusion (SM-5). Un
/// backend Material `DataTable` — ou tout autre — reste implémentable sur ce même
/// port sans toucher le cœur.
///
/// Imports limités à `package:flutter/widgets.dart` + types `zcrud_core` :
/// AUCUN `package:syncfusion`, AUCUNE dépendance lourde, AUCUN gestionnaire
/// d'état (garde `presentation_purity_test.dart`).
library;

import 'package:flutter/widgets.dart';

import 'z_list_interaction.dart';
import 'z_list_render_request.dart';

/// Abstraction de rendu d'une liste tabulaire à partir d'un [ZListRenderRequest]
/// **neutre**.
///
/// Le backend concret (injecté via `ZcrudScope.listRenderer` ou passé à
/// `DynamicList`) traduit les `columns`/`rows` neutres en widget de grille
/// (`SfDataGrid`, `DataTable`, …). Le cœur ne connaît QUE ce contrat.
abstract class ZListRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZListRenderer();

  /// Construit le widget de liste pour la [request] neutre fournie.
  ///
  /// Le paramètre nommé optionnel [interaction] (E4-4) porte la sélection et les
  /// actions de ligne **déjà résolues** (neutres). Il est **rétro-compatible** :
  /// un renderer antérieur peut l'ignorer (sélection/actions simplement inactives).
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  });
}
