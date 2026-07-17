/// `ZItemActionsMenu` — menu d'actions par item PARAMÉTRIQUE (ES-5.3, AD-25).
///
/// Comble l'absence IFFD (menu d'item **diffus**, aucun `PopupMenuButton`
/// centralisé) par une abstraction propre : le menu est paramétré par une
/// `List<ZItemAction>`, chacune portant une **nature** ([ZItemActionKind]) +
/// [label]/[icon] INJECTÉS + un callback. **`onSelected == null` ⇒ action ABSENTE
/// du menu** (AD-4 — jamais un item grisé silencieux ni un no-op).
///
/// Invariants (AD-2/AD-13/AD-15) : AUCUN gestionnaire d'état ; labels/icônes
/// INJECTÉS (jamais codés en dur) ; cibles ≥ 48 dp ; `Semantics` explicites ;
/// directionnel ; thème injecté (`ZcrudTheme.of`, repli `Theme.of`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Glyphe « menu » de REPLI du déclencheur (défaut neutre conventionnel
/// documenté, même patron justifié que le repli d'icône d'ajout du layout). Ne
/// s'applique QUE si l'appelant n'injecte pas [ZItemActionsMenu.icon].
const IconData _kMenuFallbackIcon = Icons.more_vert;

/// Nature d'une action d'item — enum EXTENSIBLE (AD-4). [custom] couvre toute
/// action hors nomenclature (l'appelant porte le [ZItemAction.label]/[icon]).
enum ZItemActionKind {
  /// Ouvrir/consulter l'item.
  open,

  /// Renommer l'item.
  rename,

  /// Déplacer l'item.
  move,

  /// Partager l'item.
  share,

  /// **Dupliquer** l'item (SU-8/AC15, FR-SU21).
  ///
  /// Ajout **ADDITIF, non-breaking** : aucun `switch` sur [ZItemActionKind]
  /// n'existe dans le repo (grep négatif vérifié — `grep -rn 'ZItemActionKind'`
  /// ne rend que des constructions `kind: ZItemActionKind.x`, jamais une
  /// analyse de cas exhaustive qui deviendrait non-exhaustive). Un membre neuf
  /// ne casse donc aucun appelant.
  duplicate,

  /// Supprimer l'item.
  delete,

  /// Action applicative hors nomenclature.
  custom,
}

/// Une action d'item — data-class de présentation immuable (`const`).
///
/// [label]/[icon] sont INJECTÉS (i18n, jamais codés en dur). [onSelected] `null`
/// ⇒ action ABSENTE du menu (AD-4).
@immutable
class ZItemAction {
  /// Construit une action d'item.
  const ZItemAction({
    required this.kind,
    required this.label,
    required this.icon,
    this.onSelected,
  });

  /// Nature de l'action ([ZItemActionKind]).
  final ZItemActionKind kind;

  /// Libellé LOCALISÉ INJECTÉ (i18n, AD-13/FR-23).
  final String label;

  /// Glyphe INJECTÉ de l'action (jamais codé en dur).
  final IconData icon;

  /// Callback de sélection. `null` ⇒ action ABSENTE du menu (AD-4).
  final VoidCallback? onSelected;
}

/// Menu d'actions par item paramétrique (déclencheur `PopupMenuButton`).
class ZItemActionsMenu extends StatelessWidget {
  /// Construit le menu à partir des actions (ordre préservé).
  ///
  /// [icon] : glyphe INJECTÉ du déclencheur (`null` ⇒ repli neutre documenté).
  /// [tooltip] : label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  const ZItemActionsMenu({
    required this.actions,
    this.icon,
    this.tooltip,
    super.key,
  });

  /// Actions candidates. Celles à [ZItemAction.onSelected] `null` sont FILTRÉES
  /// (absentes du menu, AD-4).
  final List<ZItemAction> actions;

  /// Glyphe INJECTÉ du déclencheur (`null` ⇒ [_kMenuFallbackIcon]).
  final IconData? icon;

  /// Label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // AD-4 — action sans callback ⇒ ABSENTE (jamais rendue grisée/no-op).
    final visible =
        actions.where((a) => a.onSelected != null).toList(growable: false);
    return PopupMenuButton<ZItemAction>(
      icon: Icon(icon ?? _kMenuFallbackIcon),
      tooltip: tooltip,
      onSelected: (action) => action.onSelected?.call(),
      itemBuilder: (context) => <PopupMenuEntry<ZItemAction>>[
        for (final action in visible)
          PopupMenuItem<ZItemAction>(
            value: action,
            // PopupMenuItem impose déjà kMinInteractiveDimension (48) ; on le
            // rend explicite (AD-13/NFR-S6).
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              child: Semantics(
                button: true,
                label: action.label,
                // 🔴 `excludeSemantics: true` (SU-8/AC20 — DÉFAUT RÉEL CORRIGÉ).
                //
                // `PopupMenuItem` **fusionne** son sous-arbre (`MergeSemantics`).
                // Sans cette exclusion, le label de ce nœud **ET** celui du
                // `Text(action.label)` enfant fusionnent tous deux : le lecteur
                // d'écran annonce l'action **DEUX FOIS** — mesuré sur l'arbre
                // sémantique réel : `label was "Ouvrir\nOuvrir"`.
                //
                // ⚠️ Retirer le `label:` d'ici **ne marche PAS** (essayé,
                // mesuré) : le nœud devient **MUET** (`label: ""`) — l'action
                // disparaîtrait purement et simplement pour un lecteur d'écran.
                // Le couple `label:` + `excludeSemantics:` est la **seule**
                // combinaison qui annonce l'action **exactement une fois**.
                excludeSemantics: true,
                child: Row(
                  children: [
                    Icon(action.icon),
                    SizedBox(width: theme.gapM),
                    Expanded(
                      child: Text(action.label, textAlign: TextAlign.start),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
