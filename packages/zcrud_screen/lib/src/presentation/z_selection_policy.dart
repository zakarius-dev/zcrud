/// Sélection multiple et **actions de masse** d'un `ZCrudScreen`.
///
/// Le socle sait déjà tout faire : `ZListSelectionController` tient la
/// sélection (keyée par identité, immunisée contre le défilement et la
/// pagination), `ZBatchActionBar` rend la barre d'actions, `ZBatchReport`
/// rapporte le résultat **au grain de l'élément**. Ce qui manquait, c'est la
/// déclaration : de quoi dire « cet écran se sélectionne » sans recoudre à la
/// main le contrôleur, la barre, la gouvernance et le compte-rendu.
///
/// Déclarer [ZSelectionPolicy] suffit — l'écran câble le reste.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZBatchAction, ZBatchReport, ZEntity, ZListSelectionMode;

/// Politique de **sélection multiple** d'un écran CRUD.
///
/// `null` sur `ZCrudScreen.selection` (le défaut) = aucune sélection : ni case
/// à cocher, ni barre d'actions de masse — l'écran est exactement celui d'un
/// écran sans sélection.
///
/// ```dart
/// ZCrudScreen<Consignee>(
///   title: 'Consignataires',
///   source: ZCrudSource.repository(repo),
///   registry: registry,
///   selection: const ZSelectionPolicy(),
/// )
/// ```
///
/// La barre d'actions apparaît **dès le premier élément coché** et disparaît
/// quand la sélection se vide. Les actions offertes sont celles de la vue
/// courante — mise à la corbeille sur les éléments vivants, restauration et
/// suppression définitive en corbeille —, gouvernées **exactement** comme les
/// actions de ligne correspondantes.
@immutable
class ZSelectionPolicy {
  /// Déclare la sélection.
  ///
  /// [mode] : `multiple` (défaut) coche plusieurs éléments, `single` n'en
  /// retient qu'un, `none` désactive toute mutation de la sélection (les cases
  /// ne sont alors pas rendues).
  ///
  /// [showSelectAll] : offre le bouton « tout sélectionner » de la barre, qui
  /// porte sur les éléments **actuellement listés** (page courante de la vue
  /// courante), jamais sur ce que la source contient au-delà.
  ///
  /// [onReport] : reçoit le [ZBatchReport] de chaque action de masse — le
  /// point d'accroche d'une application qui veut sa **propre** surface de
  /// compte rendu (liste complète des échecs, journal, réessai). L'écran
  /// notifie de son côté, toujours.
  const ZSelectionPolicy({
    this.mode = ZListSelectionMode.multiple,
    this.showSelectAll = true,
    this.onReport,
  });

  /// Mode de sélection (défaut : `multiple`).
  final ZListSelectionMode mode;

  /// Offre le bouton « tout sélectionner » de la barre (défaut `true`).
  final bool showSelectAll;

  /// Rappel du compte rendu d'une action de masse, si l'application veut en
  /// faire davantage que la notification de l'écran. `null` = rien de plus.
  final void Function(ZBatchReport report)? onReport;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSelectionPolicy &&
          other.mode == mode &&
          other.showSelectAll == showSelectAll &&
          other.onReport == onReport;

  @override
  int get hashCode => Object.hash(mode, showSelectAll, onReport);
}

/// Actions de masse **supplémentaires** de l'application, construites avec les
/// entités actuellement sélectionnées.
///
/// Voie d'échappement : les actions assemblées (corbeille, restauration,
/// suppression définitive) sont fournies par l'écran ; celles-ci s'y ajoutent,
/// avec leur libellé, leur glyphe et leur effet. L'écran ne les gouverne pas —
/// elles appartiennent à l'application, comme les `rowActions` qu'elle déclare.
typedef ZCrudBatchActions<T extends ZEntity> = List<ZBatchAction> Function(
  BuildContext context,
  List<T> selected,
);
