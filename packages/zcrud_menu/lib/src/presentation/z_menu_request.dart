/// [ZMenuRequest] — requête de rendu NEUTRE d'un menu.
///
/// Patron strict de `ZListRenderRequest` / `ZReorderRenderRequest`
/// (`zcrud_core`) : tout ce dont un renderer a besoin, et RIEN qui trahisse une
/// technologie de menu. Aucun type Material, aucun `PopupMenuEntry`, aucun
/// paquet tiers n'apparaît dans cette signature — c'est ce qui rend les
/// implémentations interchangeables.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_menu_entry.dart';
import '../domain/z_menu_trigger.dart';

/// Présentation INJECTÉE du CONTENU du menu.
///
/// * [context] — contexte de la SURFACE ouverte (pas du déclencheur) ;
/// * `entries` — liste **DÉJÀ FILTRÉE** par la règle d'absence (invariant
///   AD-4) ;
/// * `select` — invoque l'entrée ET ferme la surface, par le **MÊME chemin** que
///   le rendu par défaut. L'hôte n'a ni à fermer, ni à appeler `onSelected` :
///   une présentation alternative ne peut pas diverger du défaut.
///
/// Les entrées DÉSACTIVÉES ([ZMenuEntry.isEnabled] `false`) sont présentes
/// dans `entries` : une présentation injectée doit les rendre inertes et
/// annoncer [ZMenuEntry.disabledReason]. Appeler `select` sur une entrée
/// désactivée est **sans effet** (garanti par [ZMenuRequest.select], pas par la
/// bonne volonté de l'hôte).
typedef ZMenuContentBuilder = Widget Function(
  BuildContext context,
  List<ZMenuEntry> entries,
  void Function(ZMenuEntry entry) select,
);

/// Requête neutre transmise à un [ZMenuRenderer].
@immutable
class ZMenuRequest {
  /// Construit la requête. [entries] DOIT être déjà filtrée
  /// ([zVisibleMenuEntries]) — `ZActionMenu` s'en charge.
  const ZMenuRequest({
    required this.trigger,
    required this.entries,
    required this.select,
    this.contentBuilder,
  });

  /// Description du déclencheur (le renderer décide de sa forme).
  final ZMenuTrigger trigger;

  /// Entrées visibles, ordre PRÉSERVÉ, règle d'absence DÉJÀ appliquée.
  final List<ZMenuEntry> entries;

  /// **UNIQUE** site d'invocation de l'effet d'une entrée.
  ///
  /// Un renderer ne doit JAMAIS appeler `entry.onSelected` lui-même : il
  /// appelle [select]. C'est ce qui empêche un second chemin d'exécution
  /// divergent d'apparaître dans un adaptateur tiers.
  ///
  /// Sans effet sur une entrée désactivée ou absente de [entries].
  final void Function(ZMenuEntry entry) select;

  /// Présentation INJECTÉE du contenu (`null` ⇒ le renderer choisit la sienne).
  final ZMenuContentBuilder? contentBuilder;
}
