/// `ZItemActionsMenu` — menu d'actions par item PARAMÉTRIQUE (ES-5.3, AD-25).
///
/// 🔴 **CHAT-4b — ce widget est désormais un CONSOMMATEUR de `zcrud_menu`.**
///
/// Il ne construit plus AUCUN `PopupMenuButton`/`PopupMenuItem`/`PopupMenuEntry` :
/// il traduit sa `List<ZItemAction>` en `List<ZMenuEntry>` et délègue à
/// [ZActionMenu]. Le doublon que CR-LEX-78 interdit (deux menus vivant côte à
/// côte dans le socle) est donc SUPPRIMÉ, pas différé — la garde
/// `packages/zcrud_menu/test/z_menu_supersedes_test.dart` le mesure sur disque.
///
/// Ce qui NE change pas pour un appelant qui n'utilise aucune capacité neuve :
/// la surface publique ([ZItemAction], [ZItemActionKind], [ZItemActionsMenu],
/// [ZItemActionsMenuBuilder]) est INCHANGÉE, et le rendu est celui d'avant
/// (même déclencheur `PopupMenuButton` sous le repli [ZDefaultMenuRenderer],
/// même colonne de `PopupMenuItem`, même info-bulle, mêmes `Semantics`).
///
/// Ce que la délégation REND ACCESSIBLE, en ADDITIF :
/// * [ZItemAction.permitted] — le **droit** séparé de l'**effet** (IFFD a dû
///   écrire `IffdMenuAction`/`iffdMenuActions()` faute de cette distinction) ;
/// * [ZItemAction.disabledReason] — entrée **présente, inerte, MOTIVÉE** (lex
///   réécrit 297 lignes de `PopupMenuButton` pour l'obtenir) ;
/// * [ZItemAction.id] / [ZMenuEntryIds] — le vocabulaire d'identités PARTAGÉ ;
/// * [ZMenuEntryTile] — la cellule ≥ 48 dp à `Semantics` NON dupliquées, offerte
///   au [menuBuilder] (le renoncement a11y du slot est levé) ;
/// * [renderer] / [ZMenuScope] — le déclencheur ET la surface substituables.
///
/// ⚠️ **Seule divergence de rendu assumée** : un menu dont AUCUNE action n'est
/// visible et qui n'a pas de [menuBuilder] rend un déclencheur **inerte**
/// (AD-10 : jamais une surface flottante vide). Avant CHAT-4b il s'ouvrait sur
/// une surface vide. Aucun appelant du dépôt n'est dans ce cas.
///
/// Invariants (AD-2/AD-13/AD-15) : AUCUN gestionnaire d'état ; labels/icônes
/// INJECTÉS (jamais codés en dur) ; cibles ≥ 48 dp ; `Semantics` explicites ;
/// directionnel ; thème injecté.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_menu/zcrud_menu.dart';

/// Couture de menu RÉEXPORTÉE : un hôte qui compose un [menuBuilder] a besoin de
/// [ZMenuEntryTile] (cellule a11y) et de [ZMenuEntryIds] (identités partagées)
/// sans avoir à déclarer une dépendance de plus. Ce sont les MÊMES déclarations
/// que celles de `package:zcrud_menu/zcrud_menu.dart` : importer les deux ne
/// crée aucune ambiguïté.
export 'package:zcrud_menu/zcrud_menu.dart'
    show
        ZActionMenu,
        ZDefaultMenuRenderer,
        ZMenuContentBuilder,
        ZMenuEntry,
        ZMenuEntryIds,
        ZMenuEntryTile,
        ZMenuRenderer,
        ZMenuRequest,
        ZMenuScope,
        ZMenuTrigger,
        kZMenuMinTapTarget,
        zResolveMenuRenderer,
        zVisibleMenuEntries;

/// Glyphe « menu » de REPLI du déclencheur (défaut neutre conventionnel
/// documenté, même patron justifié que le repli d'icône d'ajout du layout). Ne
/// s'applique QUE si l'appelant n'injecte pas [ZItemActionsMenu.icon].
const IconData _kMenuFallbackIcon = Icons.more_vert;

/// Nature d'une action d'item — enum EXTENSIBLE (AD-4). [custom] couvre toute
/// action hors nomenclature (l'appelant porte le [ZItemAction.label]/[icon]).
///
/// 🔴 Depuis CHAT-4b, chaque membre a un pendant dans le vocabulaire d'identités
/// PARTAGÉ [ZMenuEntryIds] ([ZItemAction.entryId]) — adoptable par un package
/// qui ne peut pas dépendre de `zcrud_study` (`zcrud_core`, CORE OUT = 0).
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

/// Identité PARTAGÉE ([ZMenuEntryIds]) correspondant à une [ZItemActionKind].
///
/// [ZItemActionKind.custom] n'a pas d'identité canonique : l'appelant fournit la
/// sienne via [ZItemAction.id] (pendant exact du variant `custom`).
String zMenuEntryIdForKind(ZItemActionKind kind) => switch (kind) {
      ZItemActionKind.open => ZMenuEntryIds.open,
      ZItemActionKind.rename => ZMenuEntryIds.rename,
      ZItemActionKind.move => ZMenuEntryIds.move,
      ZItemActionKind.share => ZMenuEntryIds.share,
      ZItemActionKind.duplicate => ZMenuEntryIds.duplicate,
      ZItemActionKind.delete => ZMenuEntryIds.delete,
      ZItemActionKind.custom => 'custom',
    };

/// Une action d'item — data-class de présentation immuable (`const`).
///
/// [label]/[icon] sont INJECTÉS (i18n, jamais codés en dur).
///
/// ## Les TROIS états (CHAT-4b — le troisième était inexprimable)
///
/// | [onSelected] | [disabledReason] | État rendu |
/// |---|---|---|
/// | non-`null` | `null` | **présente et actionnable** |
/// | `null` | `null` | **ABSENTE** — règle AD-4 HISTORIQUE, préservée |
/// | `null` | non-`null` | **présente, INERTE, motif ANNONCÉ** |
///
/// [permitted] `false` force l'absence, quoi qu'il en soit du reste de la ligne.
///
/// Les deux premières lignes reproduisent EXACTEMENT la sémantique d'avant : un
/// appelant qui ne renseigne ni [disabledReason] ni [permitted] obtient le
/// comportement historique, au caractère près.
@immutable
class ZItemAction {
  /// Construit une action d'item.
  ///
  /// [id] : identité OPAQUE et STABLE (jamais affichée). `null` ⇒ dérivée de
  /// [kind] via [zMenuEntryIdForKind]. À renseigner pour une action
  /// [ZItemActionKind.custom] afin qu'elle porte une identité distinctive
  /// (`ZMenuEntryIds.moveUp`…).
  ///
  /// [permitted] : l'utilisateur a-t-il le DROIT de voir cette action ? `false`
  /// ⇒ action ABSENTE, quels que soient [onSelected]/[disabledReason]. Défaut
  /// `true` : un appelant qui ne gère pas de droits n'en voit rien.
  ///
  /// [disabledReason] : motif LOCALISÉ INJECTÉ de désactivation. Non-`null` ⇒
  /// l'action est rendue **présente mais inerte**, motif ANNONCÉ (AD-13).
  /// Incompatible avec un [onSelected] non-`null` (assert) : une action ne peut
  /// pas être à la fois actionnable et désactivée.
  const ZItemAction({
    required this.kind,
    required this.label,
    required this.icon,
    this.onSelected,
    this.id,
    this.permitted = true,
    this.disabledReason,
  }) : assert(
          onSelected == null || disabledReason == null,
          'ZItemAction: une action ACTIONNABLE (onSelected non nul) ne peut pas '
          'porter un disabledReason — les deux états sont exclusifs. Pour une '
          'action désactivée, laisser onSelected nul et fournir le motif ; pour '
          'une action absente, laisser les deux nuls.',
        );

  /// Nature de l'action ([ZItemActionKind]).
  final ZItemActionKind kind;

  /// Libellé LOCALISÉ INJECTÉ (i18n, AD-13/FR-23).
  final String label;

  /// Glyphe INJECTÉ de l'action (jamais codé en dur).
  final IconData icon;

  /// Callback de sélection. `null` (et [disabledReason] `null`) ⇒ action
  /// ABSENTE du menu (AD-4).
  final VoidCallback? onSelected;

  /// Identité opaque PARTAGÉE (`null` ⇒ dérivée de [kind]).
  final String? id;

  /// Droit de l'utilisateur sur cette action. `false` ⇒ ABSENTE.
  final bool permitted;

  /// Motif LOCALISÉ INJECTÉ de désactivation (`null` ⇒ pas de désactivation).
  final String? disabledReason;

  /// Identité effective de l'action ([id], à défaut dérivée de [kind]).
  String get entryId => id ?? zMenuEntryIdForKind(kind);

  /// Projection vers l'entrée NEUTRE de `zcrud_menu`.
  ///
  /// Publique à dessein : une présentation injectée ([ZItemActionsMenuBuilder])
  /// peut ainsi rendre chaque action avec [ZMenuEntryTile] — cible ≥ 48 dp,
  /// `Semantics` NON dupliquées, directionnalité — au lieu de les réécrire.
  ///
  /// [ZMenuEntry.isDestructive] est dérivé de [kind] : c'est une **donnée**, pas
  /// un style (FR-26 — le socle ne lui associe aucune couleur).
  ZMenuEntry toMenuEntry() => ZMenuEntry(
        id: entryId,
        label: label,
        icon: icon,
        onSelected: onSelected,
        disabledReason: disabledReason,
        permitted: permitted,
        isDestructive: kind == ZItemActionKind.delete,
      );
}

/// Présentation INJECTÉE du contenu du menu (CR-IFFD-32).
///
/// Reçoit :
/// * [context] — le contexte de la **surface flottante** (celui du menu ouvert,
///   pas celui du déclencheur) ;
/// * `actions` — la liste **DÉJÀ FILTRÉE** par la règle d'absence (AD-4) :
///   toute action ni actionnable ni motivée, ou non [ZItemAction.permitted], en
///   est ABSENTE. L'hôte n'a donc **jamais** à refaire ce filtrage, et ne peut
///   pas le contourner par inadvertance ;
/// * `select` — invoque l'action ET ferme la surface, par le **MÊME chemin** que
///   le rendu par défaut. L'hôte n'a ni à fermer à la main, ni à appeler
///   `action.onSelected` : une présentation alternative ne peut pas diverger du
///   comportement de la colonne par défaut. Sans effet sur une action
///   DÉSACTIVÉE (garanti par `ZMenuRequest.select`, pas par la bonne volonté de
///   l'hôte).
///
/// Le socle **n'impose rien** sur la forme rendue (grille bornée, colonnes
/// multiples, sections…) : c'est précisément l'objet du slot.
typedef ZItemActionsMenuBuilder = Widget Function(
  BuildContext context,
  List<ZItemAction> actions,
  void Function(ZItemAction action) select,
);

/// Menu d'actions par item paramétrique — façade sur [ZActionMenu].
class ZItemActionsMenu extends StatelessWidget {
  /// Construit le menu à partir des actions (ordre préservé).
  ///
  /// [icon] : glyphe INJECTÉ du déclencheur (`null` ⇒ repli neutre documenté).
  /// [tooltip] : label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  /// [menuBuilder] : présentation INJECTÉE du contenu (`null` ⇒ **colonne
  /// unique**, rendu strictement inchangé).
  /// [renderer] : surcharge PONCTUELLE du [ZMenuRenderer] (prioritaire sur
  /// [ZMenuScope]). `null` ⇒ scope de l'hôte, puis repli `ZDefaultMenuRenderer`.
  const ZItemActionsMenu({
    required this.actions,
    this.icon,
    this.tooltip,
    this.menuBuilder,
    this.renderer,
    super.key,
  });

  /// Actions candidates. Celles qui ne sont ni actionnables ni motivées, et
  /// celles non [ZItemAction.permitted], sont FILTRÉES (absentes, AD-4).
  final List<ZItemAction> actions;

  /// Glyphe INJECTÉ du déclencheur (`null` ⇒ [_kMenuFallbackIcon]).
  final IconData? icon;

  /// Label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  ///
  /// `null` ⇒ repli LOCALISÉ du SDK (`MaterialLocalizations.showMenuTooltip`) —
  /// exactement la chaîne que `PopupMenuButton` utilisait déjà de lui-même.
  /// Elle est désormais résolue ICI parce que `ZMenuTrigger.semanticLabel` est
  /// REQUIS : un déclencheur muet sous un renderer injecté (hors Material) est
  /// proscrit (AD-13, récidive `su-9`).
  final String? tooltip;

  /// Présentation INJECTÉE du contenu du menu (CR-IFFD-32).
  ///
  /// `null` (défaut) ⇒ **colonne unique** de `PopupMenuItem` — rendu
  /// **strictement inchangé** pour tout hôte qui ne renseigne pas ce slot.
  ///
  /// Non-null ⇒ la surface flottante ne contient plus qu'UNE entrée, dont le
  /// contenu est celui rendu par l'hôte. Ce qui reste **la propriété du socle**,
  /// et qui ne peut donc pas régresser : la liste transmise est déjà filtrée par
  /// la règle d'absence (AD-4), et la sélection passe par le même chemin que le
  /// rendu par défaut.
  ///
  /// **Pourquoi un SLOT et pas une option de grille** (arbitrage CR-IFFD-32) :
  /// au-delà de six ou sept entrées, une colonne unique impose un balayage
  /// vertical long sur une surface flottante — le plafond de lisibilité est
  /// réel. Mais y répondre par un `crossAxisMaxColumns` figerait dans le socle
  /// *une* ergonomie de menu flottant (largeur de panneau, ordre de lecture,
  /// parcours clavier, position du séparateur destructif) alors que ces
  /// décisions dépendent de l'hôte.
  ///
  /// 🟢 **A11y (AD-13) — le renoncement est LEVÉ depuis CHAT-4b.** La cellule
  /// [ZMenuEntryTile] est offerte à l'hôte : `ZMenuEntryTile(entry:
  /// action.toMenuEntry(), onSelected: () => select(action))` lui donne la cible
  /// ≥ 48 dp, les `Semantics` NON dupliquées et la directionnalité sans les
  /// réécrire. La DISPOSITION reste sa liberté ; la CELLULE reste la propriété
  /// du socle. S'il rend autre chose, l'a11y de ce qu'il rend est à sa charge.
  final ZItemActionsMenuBuilder? menuBuilder;

  /// Surcharge ponctuelle du renderer de menu (prioritaire sur [ZMenuScope]).
  final ZMenuRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    // 🔴 Traduction 1:1, ordre PRÉSERVÉ. Le filtrage AD-4 n'est PAS refait ici :
    // il a un site UNIQUE, `ZActionMenu` (`zVisibleMenuEntries`). Le refaire
    // serait la seconde source que ce lot supprime.
    final entries = <ZMenuEntry>[];
    // Correspondance par IDENTITÉ : deux actions distinctes peuvent être ÉGALES
    // au sens de `==` (mêmes kind/label/icône/callback). Une `Map` ordinaire les
    // confondrait ; `Map.identity()` non.
    final versAction = Map<ZMenuEntry, ZItemAction>.identity();
    final versEntree = Map<ZItemAction, ZMenuEntry>.identity();
    for (final action in actions) {
      final entry = action.toMenuEntry();
      entries.add(entry);
      versAction[entry] = action;
      versEntree[action] = entry;
    }

    final hote = menuBuilder;
    return ZActionMenu(
      entries: entries,
      renderer: renderer,
      trigger: ZMenuTrigger(
        icon: icon ?? _kMenuFallbackIcon,
        // Nom accessible : à défaut d'injection, le repli LOCALISÉ du SDK — la
        // chaîne même que `PopupMenuButton` posait auparavant (aucune chaîne
        // codée en dur, FR-26/FR-23).
        semanticLabel: tooltip ?? _defaultTooltip(context),
        // `null` ⇒ le renderer retombe sur `semanticLabel`, donc sur la même
        // info-bulle qu'avant : rendu INCHANGÉ pour un appelant sans tooltip.
        tooltip: tooltip,
      ),
      contentBuilder: hote == null
          ? null
          : (surfaceContext, visibles, select) => hote(
                surfaceContext,
                <ZItemAction>[
                  for (final entry in visibles) versAction[entry]!,
                ],
                // MÊME chemin de sortie que la colonne par défaut : l'hôte ne
                // peut ni oublier de fermer, ni invoquer deux fois, ni diverger.
                (action) {
                  final entry = versEntree[action];
                  if (entry != null) select(entry);
                },
              ),
    );
  }

  /// Repli LOCALISÉ de l'info-bulle du déclencheur.
  ///
  /// `MaterialLocalizations.of` LÈVE en l'absence de localisations Material —
  /// exactement comme le faisait `PopupMenuButton` lui-même quand `tooltip`
  /// était nul. Le contrat d'échec est donc inchangé, pas relâché.
  String _defaultTooltip(BuildContext context) =>
      MaterialLocalizations.of(context).showMenuTooltip;
}
