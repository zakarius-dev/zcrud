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

/// Présentation INJECTÉE du contenu du menu (CR-IFFD-32).
///
/// Reçoit :
/// * [context] — le contexte de la **surface flottante** (celui du menu ouvert,
///   pas celui du déclencheur) ;
/// * `actions` — la liste **DÉJÀ FILTRÉE** par la règle d'absence (AD-4) :
///   toute action à [ZItemAction.onSelected] `null` en est ABSENTE. L'hôte n'a
///   donc **jamais** à refaire ce filtrage, et ne peut pas le contourner par
///   inadvertance en rendant une entrée grisée ;
/// * `select` — invoque l'action ET ferme la surface, par le **MÊME chemin** que
///   le rendu par défaut (`Navigator.pop(context, action)` ⇒ `onSelected` du
///   `PopupMenuButton`). L'hôte n'a ni à fermer à la main, ni à appeler
///   `action.onSelected` : une présentation alternative ne peut pas diverger du
///   comportement de la colonne par défaut.
///
/// Le socle **n'impose rien** sur la forme rendue (grille bornée, colonnes
/// multiples, sections…) : c'est précisément l'objet du slot.
typedef ZItemActionsMenuBuilder = Widget Function(
  BuildContext context,
  List<ZItemAction> actions,
  void Function(ZItemAction action) select,
);

/// Menu d'actions par item paramétrique (déclencheur `PopupMenuButton`).
class ZItemActionsMenu extends StatelessWidget {
  /// Construit le menu à partir des actions (ordre préservé).
  ///
  /// [icon] : glyphe INJECTÉ du déclencheur (`null` ⇒ repli neutre documenté).
  /// [tooltip] : label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  /// [menuBuilder] : présentation INJECTÉE du contenu (`null` ⇒ **colonne
  /// unique**, rendu strictement inchangé).
  const ZItemActionsMenu({
    required this.actions,
    this.icon,
    this.tooltip,
    this.menuBuilder,
    super.key,
  });

  /// Actions candidates. Celles à [ZItemAction.onSelected] `null` sont FILTRÉES
  /// (absentes du menu, AD-4).
  final List<ZItemAction> actions;

  /// Glyphe INJECTÉ du déclencheur (`null` ⇒ [_kMenuFallbackIcon]).
  final IconData? icon;

  /// Label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  final String? tooltip;

  /// Présentation INJECTÉE du contenu du menu (CR-IFFD-32).
  ///
  /// `null` (défaut) ⇒ **colonne unique** de `PopupMenuItem` — rendu
  /// **strictement inchangé** pour tout hôte qui ne renseigne pas ce slot.
  ///
  /// Non-null ⇒ la surface flottante ne contient plus qu'UNE entrée, dont le
  /// contenu est celui rendu par l'hôte. Ce qui reste **la propriété du socle**,
  /// et qui ne peut donc pas régresser : la liste transmise est déjà filtrée par
  /// la règle « `onSelected == null` ⇒ action ABSENTE » (AD-4), et la sélection
  /// passe par le même `Navigator.pop(context, action)` que le rendu par défaut.
  ///
  /// **Pourquoi un SLOT et pas une option de grille** (arbitrage CR-IFFD-32) :
  /// au-delà de six ou sept entrées, une colonne unique impose un balayage
  /// vertical long sur une surface flottante — le plafond de lisibilité est
  /// réel. Mais y répondre par un `crossAxisMaxColumns` figerait dans le socle
  /// *une* ergonomie de menu flottant (largeur de panneau, ordre de lecture,
  /// parcours clavier, position du séparateur destructif) alors que ces
  /// décisions dépendent de l'hôte — ce serait exactement le défaut que
  /// CR-LEX-61/73 et CR-IFFD-35 reprochent au socle : figer sur un widget une
  /// décision qui ne lui appartient pas. Le slot n'engage RIEN sur le rendu tout
  /// en préservant l'abstraction jugée juste (`List<ZItemAction>` + règle
  /// d'absence). Une option de disposition reste ajoutable par-dessus, plus
  /// tard, sans rupture.
  ///
  /// ⚠️ **A11y (AD-13) — ce que le socle ne peut plus garantir** : les cibles
  /// ≥ 48 dp, les `Semantics` et la directionnalité du contenu rendu par l'hôte
  /// sont à SA charge (le socle ne les impose que sur sa colonne par défaut).
  final ZItemActionsMenuBuilder? menuBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // AD-4 — action sans callback ⇒ ABSENTE (jamais rendue grisée/no-op).
    // 🔴 Filtrage AMONT, PARTAGÉ par les deux présentations : le slot reçoit la
    // MÊME liste que la colonne par défaut. La règle d'absence n'est donc pas
    // « re-demandée » à l'hôte — elle lui est INOPPOSABLE.
    final visible =
        actions.where((a) => a.onSelected != null).toList(growable: false);
    final builder = menuBuilder;
    return PopupMenuButton<ZItemAction>(
      icon: Icon(icon ?? _kMenuFallbackIcon),
      tooltip: tooltip,
      onSelected: (action) => action.onSelected?.call(),
      itemBuilder: (context) => <PopupMenuEntry<ZItemAction>>[
        if (builder != null)
          _ZActionsPanelEntry(
            builder: builder,
            actions: visible,
          )
        else
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

/// Entrée UNIQUE portant la présentation INJECTÉE (CR-IFFD-32).
///
/// C'est un `PopupMenuEntry` **nu** — délibérément PAS un `PopupMenuItem` :
/// * un `PopupMenuItem` impose sa hauteur minimale, son `padding` et son
///   `TextStyle` (couleur « désactivée » comprise si `enabled: false`) au
///   sous-arbre de l'hôte : la présentation injectée serait re-décorée par le
///   socle, ce que le slot promet justement de ne pas faire ;
/// * il pose surtout un `InkWell` qui **ferme le menu au moindre tap** tombé
///   entre deux cellules (`Navigator.pop(context, null)`), un comportement
///   invisible en revue et déroutant sur un panneau à plusieurs colonnes.
///
/// [height] ne sert qu'à l'**estimation de défilement** du `PopupMenu` (le
/// contenu se dimensionne lui-même) ; [represents] est `false` : cette entrée ne
/// représente AUCUNE valeur, donc aucune mise en surbrillance d'« item courant ».
class _ZActionsPanelEntry extends PopupMenuEntry<ZItemAction> {
  const _ZActionsPanelEntry({required this.builder, required this.actions});

  /// Présentation INJECTÉE par l'hôte.
  final ZItemActionsMenuBuilder builder;

  /// Actions DÉJÀ filtrées par la règle d'absence (AD-4).
  final List<ZItemAction> actions;

  @override
  double get height => _kMinTapTarget;

  @override
  bool represents(ZItemAction? value) => false;

  @override
  State<_ZActionsPanelEntry> createState() => _ZActionsPanelEntryState();
}

class _ZActionsPanelEntryState extends State<_ZActionsPanelEntry> {
  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        widget.actions,
        // MÊME chemin de sortie que la colonne par défaut : la valeur poppée est
        // récupérée par `onSelected` du `PopupMenuButton`, qui invoque
        // `action.onSelected`. Une présentation injectée ne peut donc ni oublier
        // de fermer, ni invoquer deux fois, ni diverger du défaut.
        (action) => Navigator.of(context).pop(action),
      );
}
