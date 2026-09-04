/// `ZItemActionsMenu` — menu d'actions par item PARAMÉTRIQUE.
///
/// **Ce widget est un CONSOMMATEUR de `zcrud_menu`.**
///
/// Il ne construit plus AUCUN `PopupMenuButton`/`PopupMenuItem`/`PopupMenuEntry` :
/// il traduit sa `List<ZItemAction>` en `List<ZMenuEntry>` et délègue à
/// [ZActionMenu]. Deux implémentations de menu ne vivent jamais côte à côte
/// dans le socle — une garde dédiée le mesure sur disque.
///
/// Défaut de contenu : [menuBuilder] nul rend une grille à **trois colonnes**.
/// Le déclencheur reste celui du renderer et la colonne unique reste
/// atteignable par `crossAxisCount: 1`.
///
/// Ce que la délégation REND ACCESSIBLE, en ADDITIF :
/// * [ZItemAction.permitted] — le **droit** séparé de l'**effet**, deux
///   notions distinctes qui n'existaient pas comme telles auparavant ;
/// * [ZItemAction.disabledReason] — entrée **présente, inerte, MOTIVÉE** ;
/// * [ZItemAction.id] / [ZMenuEntryIds] — le vocabulaire d'identités PARTAGÉ ;
/// * [ZMenuEntryTile] — la cellule ≥ 48 dp à `Semantics` NON dupliquées, offerte
///   au [menuBuilder] (le renoncement a11y du slot est levé) ;
/// * [renderer] / [ZMenuScope] — le déclencheur ET la surface substituables.
///
/// Deux voies d'ouverture, une seule composition : le widget porte son
/// déclencheur, [showZItemActionsMenu] ouvre la MÊME surface sur un
/// déclencheur que l'appelant garde dans son arbre (ancrage par `GlobalKey`).
///
/// **Seule divergence de rendu assumée** : un menu dont AUCUNE action n'est
/// visible et qui n'a pas de [menuBuilder] rend un déclencheur **inerte**
/// (AD-10 : jamais une surface flottante vide).
///
/// Invariants (AD-2/AD-13/AD-15) : AUCUN gestionnaire d'état ; labels/icônes
/// INJECTÉS (jamais codés en dur) ; cibles ≥ 48 dp ; `Semantics` explicites ;
/// directionnel ; thème injecté.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZForegroundOverride, kZNonTextMinContrast, zReadableTintOn;
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
/// Chaque membre a un pendant dans le vocabulaire d'identités PARTAGÉ
/// [ZMenuEntryIds] ([ZItemAction.entryId]) — adoptable par un package qui ne
/// peut pas dépendre de `zcrud_study` (invariant AD-1 : cœur léger).
enum ZItemActionKind {
  /// Ouvrir/consulter l'item.
  open,

  /// Renommer l'item.
  rename,

  /// Déplacer l'item.
  move,

  /// Partager l'item.
  share,

  /// **Dupliquer** l'item.
  ///
  /// Ajout **ADDITIF, non-breaking** : aucun `switch` sur [ZItemActionKind]
  /// n'existe dans le repo (vérifié par grep négatif — seules des
  /// constructions `kind: ZItemActionKind.x` existent, jamais une analyse de
  /// cas exhaustive qui deviendrait non-exhaustive). Un membre neuf ne casse
  /// donc aucun appelant.
  duplicate,

  /// Supprimer l'item.
  delete,

  /// Action applicative hors nomenclature.
  custom,
}

/// État de l'artefact produit ou ouvert par une [ZItemAction].
///
/// Cet état est distinct de l'état d'interaction de l'entrée
/// (actionnable/désactivée/absente du menu) : une action [absent] peut être
/// actionnable précisément pour créer l'artefact manquant.
enum ZItemActionState {
  /// L'artefact n'existe pas encore.
  absent,

  /// Sa création ou sa mise à jour est en cours.
  inProgress,

  /// L'artefact existe déjà.
  present,
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
/// ## Les TROIS états
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
    this.state,
    this.stateSemanticLabel,
    this.count,
  }) : assert(
         onSelected == null || disabledReason == null,
         'ZItemAction: une action ACTIONNABLE (onSelected non nul) ne peut pas '
         'porter un disabledReason — les deux états sont exclusifs. Pour une '
         'action désactivée, laisser onSelected nul et fournir le motif ; pour '
         'une action absente, laisser les deux nuls.',
       ),
       assert(
         (state == null && stateSemanticLabel == null) ||
             (state != null &&
                 stateSemanticLabel != null &&
                 stateSemanticLabel != ''),
         'ZItemAction: state et stateSemanticLabel vont ensemble. Le libellé '
         "d'état doit être localisé et non vide afin que l'état ne soit "
         'jamais porté par la seule couleur.',
       ),
       assert(
         count == null || count >= 0,
         'ZItemAction: count doit être positif ou nul.',
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

  /// État optionnel de l'artefact associé à l'action.
  ///
  /// `null` préserve strictement le rendu historique de l'action : aucune
  /// teinte, aucun nœud sémantique et aucun badge ne sont ajoutés.
  final ZItemActionState? state;

  /// Libellé LOCALISÉ annoncé pour [state].
  ///
  /// Requis et non vide quand [state] est renseigné ; interdit sans état. Le
  /// socle ne fabrique ainsi aucune chaîne d'interface (FR-26/AD-13).
  final String? stateSemanticLabel;

  /// Compte absolu optionnel associé à l'artefact.
  ///
  /// Une valeur strictement positive rend un badge ; `null` ou `0` n'ajoute
  /// aucun nœud. Les valeurs négatives sont rejetées en debug.
  final int? count;

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

/// Présentation INJECTÉE du contenu du menu.
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
///   comportement du rendu par défaut. Sans effet sur une action
///   DÉSACTIVÉE (garanti par `ZMenuRequest.select`, pas par la bonne volonté de
///   l'hôte).
///
/// Le socle **n'impose rien** sur la forme rendue (grille bornée, colonnes
/// multiples, sections…) : c'est précisément l'objet du slot.
typedef ZItemActionsMenuBuilder =
    Widget Function(
      BuildContext context,
      List<ZItemAction> actions,
      void Function(ZItemAction action) select,
    );

/// Composition PARTAGÉE d'un menu d'actions d'item.
///
/// Regroupe ce dont les DEUX voies d'ouverture ont besoin — le déclencheur
/// porté par [ZItemActionsMenu] et l'ouverture impérative
/// [showZItemActionsMenu] : les entrées neutres, la même liste une fois filtrée
/// et la présentation du contenu.
@immutable
class _ZItemActionsComposition {
  const _ZItemActionsComposition({
    required this.entries,
    required this.visible,
    required this.contentBuilder,
  });

  /// Entrées traduites, ordre PRÉSERVÉ, règle d'absence NON appliquée.
  final List<ZMenuEntry> entries;

  /// Les mêmes entrées, filtrées par la règle d'absence.
  final List<ZMenuEntry> visible;

  /// Présentation du contenu (`null` ⇒ rien à montrer).
  final ZMenuContentBuilder? contentBuilder;
}

/// SITE UNIQUE de composition d'un menu d'actions d'item.
///
/// Recopier cette composition ailleurs recréerait deux rendus du même menu, qui
/// divergeraient au premier changement — une garde de source l'interdit.
_ZItemActionsComposition _composeItemActions({
  required List<ZItemAction> actions,
  required ZItemActionsMenuBuilder? menuBuilder,
  required int crossAxisCount,
}) {
  // Traduction 1:1, ordre PRÉSERVÉ.
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
  // Le filtrage AD-4 a un site UNIQUE (`zVisibleMenuEntries`) et n'est appelé
  // qu'ICI : la voie du déclencheur laisse `ZActionMenu` le rejouer sur la
  // liste complète (rendu inchangé), la voie impérative consomme `visible`.
  final visible = zVisibleMenuEntries(entries);
  // Un builder par défaut ne doit pas rendre actionnable un déclencheur dont
  // toutes les entrées seront filtrées.
  final hasVisibleAction = visible.isNotEmpty;
  return _ZItemActionsComposition(
    entries: entries,
    visible: visible,
    contentBuilder: hote == null && !hasVisibleAction
        ? null
        : (surfaceContext, visibles, select) {
            if (hote != null) {
              return hote(
                surfaceContext,
                <ZItemAction>[for (final entry in visibles) versAction[entry]!],
                // MÊME chemin de sortie que le défaut : l'hôte ne peut ni
                // oublier de fermer, ni invoquer deux fois, ni diverger.
                (action) {
                  final entry = versEntree[action];
                  if (entry != null) select(entry);
                },
              );
            }
            return _ZDefaultItemActionGrid(
              actions: <ZItemAction>[
                for (final entry in visibles) versAction[entry]!,
              ],
              entries: visibles,
              crossAxisCount: crossAxisCount,
              onSelected: select,
            );
          },
  );
}

/// Point d'ancrage GLOBAL du menu, dérivé de la boîte de rendu de [anchorKey].
///
/// Retourne `null` — jamais une levée — dès qu'aucune géométrie fiable n'existe
/// (ancre non montée, objet de rendu absent, non attaché ou non mesuré).
Offset? _zItemActionsAnchorPoint(BuildContext context, GlobalKey anchorKey) {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) return null;
  final renderObject = anchorContext.findRenderObject();
  if (renderObject is! RenderBox) return null;
  if (!renderObject.attached || !renderObject.hasSize) return null;
  final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
  final direction =
      Directionality.maybeOf(anchorContext) ??
      Directionality.maybeOf(context) ??
      TextDirection.ltr;
  // Un COIN du bord haut de l'ancre, jamais son centre ni son rectangle : la
  // surface s'ouvre en s'alignant sur ce point et grandit dans la direction
  // qui lui laisse le plus de place. Le coin retenu est donc celui du côté
  // vers lequel elle va grandir — le bord de DÉPART tant que l'ancre est du
  // côté départ de l'écran, le bord de FIN au-delà, la directionnalité
  // départageant l'ancre exactement centrée.
  //
  // Ce choix n'est pas décoratif : il fait coïncider AU PIXEL le rendu de
  // l'ouverture impérative avec celui du déclencheur porté, qui transmet, lui,
  // le rectangle complet de son bouton (garde de géométrie sur les quatre
  // configurations ancre × directionnalité). Aucun `left:`/`right:` n'est
  // écrit : le côté est dérivé, jamais codé (AD-13).
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  if (overlay is! RenderBox || !overlay.hasSize) {
    return direction == TextDirection.rtl ? rect.topRight : rect.topLeft;
  }
  final milieu = overlay.size.width / 2;
  final centre = rect.center.dx;
  final versLaFin =
      centre > milieu || (centre == milieu && direction == TextDirection.rtl);
  return versLaFin ? rect.topRight : rect.topLeft;
}

/// Ouvre le menu d'actions d'item **sans déclencheur fourni par le socle**,
/// ancré sur un widget que l'appelant garde dans son propre arbre.
///
/// C'est la voie de l'application qui possède DÉJÀ son bouton (barre d'outils,
/// en-tête, cellule de liste) et ne veut pas le remplacer par celui de
/// [ZItemActionsMenu] : elle branche cette fonction sur son `onPressed` et
/// conserve son bouton, sa position et son style.
///
/// ```dart
/// final GlobalKey _boutonKey = GlobalKey();
/// // …
/// IconButton(
///   key: _boutonKey,
///   icon: Icon(monGlyphe),
///   tooltip: l10n.moreOptions,
///   onPressed: () => showZItemActionsMenu(
///     context,
///     actions: mesActions,
///     anchorKey: _boutonKey,
///   ),
/// )
/// ```
///
/// Tout ce que rend [ZItemActionsMenu] est rendu ici À L'IDENTIQUE : mêmes
/// entrées, même règle d'absence (AD-4), même grille par défaut gouvernée par
/// [crossAxisCount], même [menuBuilder] injectable, même renderer résolu par la
/// chaîne `paramètre → ZMenuScope → repli`, et **même voie unique de
/// sélection** — l'appelant n'a ni à fermer la surface, ni à invoquer
/// `onSelected` lui-même.
///
/// [anchorKey] : clé du widget d'ancrage, déjà monté. La surface se pose sur sa
/// boîte exactement comme elle se poserait sur le déclencheur du widget : elle
/// s'aligne sur le bord de **départ** de l'ancre et grandit dans le sens de la
/// lecture, et bascule sur son bord de **fin** quand l'ancre est plus proche du
/// bord de fin de l'écran.
///
/// [semanticLabel] : nom accessible LOCALISÉ INJECTÉ de la surface ouverte.
/// `null` ⇒ repli localisé du SDK (`MaterialLocalizations.showMenuTooltip`).
///
/// **Ce qui ne produit AUCUNE surface** (jamais une exception, invariant
/// AD-10) : aucune action à montrer et aucun [menuBuilder] ; ancre non montée,
/// détachée ou non mesurée ; contexte démonté ; aucun nom accessible
/// disponible. Le dernier cas — déterministe, jamais une course — est en outre
/// signalé par un `assert` en debug.
///
/// Retourne quand la surface est refermée.
Future<void> showZItemActionsMenu(
  BuildContext context, {
  required List<ZItemAction> actions,
  required GlobalKey anchorKey,
  ZItemActionsMenuBuilder? menuBuilder,
  int crossAxisCount = 3,
  ZMenuRenderer? renderer,
  String? semanticLabel,
}) {
  assert(
    crossAxisCount > 0,
    'showZItemActionsMenu: crossAxisCount doit être strictement positif.',
  );
  if (!context.mounted) return Future<void>.value();
  // Aucun `assert` ici, délibérément : une ancre démontée est une COURSE
  // normale (l'utilisateur tape, l'écran se démonte), pas une erreur de
  // programmation. La faire lever en debug serait la levée que l'invariant
  // AD-10 proscrit. Le cas du nom accessible manquant, lui, est déterministe
  // et reste asserté ci-dessous.
  final anchor = _zItemActionsAnchorPoint(context, anchorKey);
  if (anchor == null) return Future<void>.value();
  // Lecture NON levante des localisations : `MaterialLocalizations.of` jette
  // hors Material, ce qu'une fonction asynchrone ne doit pas faire.
  final label =
      semanticLabel ??
      Localizations.of<MaterialLocalizations>(
        context,
        MaterialLocalizations,
      )?.showMenuTooltip;
  assert(
    label != null && label.isNotEmpty,
    'showZItemActionsMenu: aucun nom accessible disponible — ni semanticLabel '
    'injecté, ni MaterialLocalizations dans le contexte. Une surface muette '
    'pour un lecteur d\'écran est proscrite (AD-13) : rien ne sera ouvert.',
  );
  if (label == null || label.isEmpty) return Future<void>.value();
  final composition = _composeItemActions(
    actions: actions,
    menuBuilder: menuBuilder,
    crossAxisCount: crossAxisCount,
  );
  final contentBuilder = composition.contentBuilder;
  // Rien à montrer ⇒ AUCUNE surface (invariant AD-10).
  if (composition.visible.isEmpty && contentBuilder == null) {
    return Future<void>.value();
  }
  return zResolveMenuRenderer(context, override: renderer).openAt(
    context,
    ZMenuRequest(
      // Aucun déclencheur n'est rendu par cette voie : la description ne sert
      // qu'à NOMMER la surface ouverte.
      trigger: ZMenuTrigger(icon: _kMenuFallbackIcon, semanticLabel: label),
      entries: composition.visible,
      contentBuilder: contentBuilder,
      // MÊME voie de sélection que le déclencheur porté.
      select: zMenuSelectFor(composition.visible),
    ),
    anchor,
  );
}

/// Menu d'actions par item paramétrique — façade sur [ZActionMenu].
class ZItemActionsMenu extends StatelessWidget {
  /// Construit le menu à partir des actions (ordre préservé).
  ///
  /// [icon] : glyphe INJECTÉ du déclencheur (`null` ⇒ repli neutre documenté).
  /// [tooltip] : label a11y LOCALISÉ INJECTÉ du déclencheur (optionnel).
  /// [menuBuilder] : présentation INJECTÉE du contenu (`null` ⇒ grille dont
  /// [crossAxisCount] vaut 3 par défaut).
  /// [renderer] : surcharge PONCTUELLE du [ZMenuRenderer] (prioritaire sur
  /// [ZMenuScope]). `null` ⇒ scope de l'hôte, puis repli `ZDefaultMenuRenderer`.
  const ZItemActionsMenu({
    required this.actions,
    this.icon,
    this.tooltip,
    this.menuBuilder,
    this.crossAxisCount = 3,
    this.renderer,
    super.key,
  }) : assert(
         crossAxisCount > 0,
         'ZItemActionsMenu: crossAxisCount doit être strictement positif.',
       );

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
  /// proscrit (invariant AD-13).
  final String? tooltip;

  /// Présentation INJECTÉE du contenu du menu.
  ///
  /// `null` (défaut) ⇒ grille de [ZMenuEntryTile] gouvernée par
  /// [crossAxisCount].
  ///
  /// Non-null ⇒ la surface flottante ne contient plus qu'UNE entrée, dont le
  /// contenu est celui rendu par l'hôte. Ce qui reste **la propriété du socle**,
  /// et qui ne peut donc pas régresser : la liste transmise est déjà filtrée par
  /// la règle d'absence (AD-4), et la sélection passe par le même chemin que le
  /// rendu par défaut.
  ///
  /// Le slot reste l'échappatoire complète pour les sections, séparateurs ou
  /// dispositions adaptatives propres à l'hôte ; [crossAxisCount] ne gouverne
  /// que le défaut du socle.
  ///
  /// **A11y (AD-13) — le renoncement est LEVÉ.** La cellule
  /// [ZMenuEntryTile] est offerte à l'hôte : `ZMenuEntryTile(entry:
  /// action.toMenuEntry(), onSelected: () => select(action))` lui donne la cible
  /// ≥ 48 dp, les `Semantics` NON dupliquées et la directionnalité sans les
  /// réécrire. La DISPOSITION reste sa liberté ; la CELLULE reste la propriété
  /// du socle. S'il rend autre chose, l'a11y de ce qu'il rend est à sa charge.
  final ZItemActionsMenuBuilder? menuBuilder;

  /// Nombre de colonnes de la grille rendue quand [menuBuilder] est `null`.
  ///
  /// Le défaut est **3**. Un hôte qui veut retrouver une colonne la déclare en
  /// une ligne avec `crossAxisCount: 1`. Ignoré quand [menuBuilder] est
  /// fourni.
  final int crossAxisCount;

  /// Surcharge ponctuelle du renderer de menu (prioritaire sur [ZMenuScope]).
  final ZMenuRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    // Composition par le site UNIQUE, partagé avec [showZItemActionsMenu] :
    // aucune seconde traduction actions → entrées n'existe dans ce paquet, donc
    // aucune divergence de rendu entre le déclencheur porté et l'ouverture
    // impérative ne peut apparaître. Garde de source dédiée.
    final composition = _composeItemActions(
      actions: actions,
      menuBuilder: menuBuilder,
      crossAxisCount: crossAxisCount,
    );
    return ZActionMenu(
      // Liste NON filtrée : `ZActionMenu` applique lui-même la règle d'absence
      // (site unique du filtrage). Le rendu du déclencheur est inchangé.
      entries: composition.entries,
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
      contentBuilder: composition.contentBuilder,
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

/// Grille par défaut : la DISPOSITION et la CELLULE réutilisent les deux
/// mécanismes structurels de `zcrud_menu`; ce paquet n'en redéclare aucun.
class _ZDefaultItemActionGrid extends StatelessWidget {
  const _ZDefaultItemActionGrid({
    required this.actions,
    required this.entries,
    required this.crossAxisCount,
    required this.onSelected,
  });

  final List<ZItemAction> actions;
  final List<ZMenuEntry> entries;
  final int crossAxisCount;
  final void Function(ZMenuEntry entry) onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
    // `PopupMenuRoute` mesure son contenu avec `IntrinsicWidth`. Une largeur
    // serrée empêche ce calcul de descendre dans le viewport (qui, à raison,
    // refuse les dimensions intrinsèques) et donne à chaque colonne deux fois
    // le plancher tactile avant la borne de largeur appliquée par Material.
    width: crossAxisCount * kZMenuMinTapTarget * 2,
    child: GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: ZMenuEntryTile.gridDelegate(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: kZMenuMinTapTarget * 2,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) => _ZItemActionGridTile(
        action: actions[index],
        entry: entries[index],
        onSelected: () => onSelected(entries[index]),
      ),
    ),
  );
}

/// Traduction VISUELLE et SÉMANTIQUE de l'état optionnel d'une action.
class _ZItemActionGridTile extends StatelessWidget {
  const _ZItemActionGridTile({
    required this.action,
    required this.entry,
    required this.onSelected,
  });

  final ZItemAction action;
  final ZMenuEntry entry;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    Widget tile = ZMenuEntryTile(
      entry: entry,
      direction: Axis.vertical,
      onSelected: onSelected,
    );
    // Une grille borne la hauteur de sa cellule : les libellés et motifs longs
    // restent sur une ligne visuelle (le nœud sémantique conserve les chaînes
    // complètes), sans jamais déborder dans la ligne suivante.
    tile = DefaultTextStyle.merge(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: tile,
    );

    // En release les asserts du modèle disparaissent : une donnée invalide
    // échoue donc FERMÉE. Sans libellé réellement annonçable, aucune teinte
    // d'état n'est appliquée et l'information ne peut pas devenir visuelle
    // seulement.
    final String? declaredStateLabel = action.stateSemanticLabel;
    final String? stateLabel =
        declaredStateLabel != null && declaredStateLabel.trim().isNotEmpty
        ? declaredStateLabel
        : null;
    final ZItemActionState? state = stateLabel == null ? null : action.state;
    final Color? tint = switch (state) {
      ZItemActionState.inProgress => _readableStateTint(
        context,
        Theme.of(context).colorScheme.secondary,
      ),
      ZItemActionState.present => _readableStateTint(
        context,
        Theme.of(context).colorScheme.primary,
      ),
      ZItemActionState.absent || null => null,
    };
    if (tint != null) {
      // `ZForegroundOverride`, jamais `IconTheme.merge` : ce dernier n'atteint
      // QUE le contenu qui HÉRITE. Un slot d'hôte stylé depuis
      // `Theme.of(context).textTheme.*` (rôles `inherit: false`) garderait la
      // couleur ambiante et resterait illisible — le défaut même que la teinte
      // d'état prétend corriger. La primitive réécrit AUSSI
      // `ThemeData.textTheme`/`iconTheme`, donc elle atteint le slot libre.
      // Garde inter-paquets : `z_foreground_merge_source_guard_test` (CR-IFFD-43).
      tile = ZForegroundOverride(color: tint, child: tile);
    }

    final int? count = action.count;
    final bool hasCount = count != null && count > 0;
    if (hasCount) {
      // CR-IFFD-83 — la pastille est une INFORMATION, jamais une CIBLE.
      //
      // `Badge.count(child: tile)` empile son décor par-dessus l'enfant DANS LE
      // MÊME `Stack`, et ce décor est HIT-TESTABLE : `RenderDecoratedBox`
      // renvoie `hitTestSelf == true` dès que la forme (`StadiumBorder`)
      // contient le point. Le `Stack` s'arrête au premier enfant touché : le
      // tap qui tombe sur la pastille n'atteint JAMAIS la tuile, et il n'émet
      // rien — ni erreur, ni retour visuel. Mesuré : tap au coin haut-fin
      // (à 6 dp) ⇒ 0 déclenchement ; tap au centre ⇒ 1.
      //
      // 🔴 Neutraliser le seul `label` NE SUFFIT PAS — mesuré aussi :
      // `Badge(label: IgnorePointer(child: Text('12')))` laisse le tap perdu,
      // l'absorbeur devenant le `RenderDecoratedBox` du stade. C'est la
      // pastille ASSEMBLÉE qui doit sortir du hit-test.
      //
      // Le montage ci-dessous reproduit la géométrie de `Badge` À L'IDENTIQUE
      // — `Badge` place lui-même son décor dans un `Positioned.fill` au-dessus
      // de son enfant, et le calcule à partir de la taille du `Stack`, pas de
      // celle de la tuile. Mêmes pixels (tuile, pastille et nombre aux mêmes
      // rectangles), seul le hit-test diffère. Le nombre reste dans l'arbre,
      // donc toujours ANNONCÉ par le `MergeSemantics` ci-dessous :
      // `IgnorePointer` ne retire pas le nœud sémantique.
      tile = Stack(
        clipBehavior: Clip.none,
        // `StackFit.passthrough`, jamais le défaut `StackFit.loose` : ce
        // dernier donne à ses enfants NON positionnés une contrainte LÂCHE.
        // La tuile se repliait alors sur sa taille intrinsèque au lieu de
        // remplir la cellule réservée par la grille — mesuré `93,3 × 48` avec
        // compte contre `93,3 × 96` sans, soit la MOITIÉ BASSE de la cellule
        // rendue morte au tap ; avec un libellé court, le repli était aussi
        // horizontal (`48 × 48`) et la pastille — ancrée sur la CELLULE — se
        // posait entièrement HORS de la tuile, à cheval sur la voisine.
        //
        // `passthrough` retransmet la contrainte SERRÉE reçue de la grille :
        // la tuile réoccupe sa cellule entière. Le décor, lui, est en
        // `Positioned.fill` et se dimensionne déjà sur le `Stack` : la
        // pastille et son nombre restent AU PIXEL PRÈS aux mêmes rectangles
        // (garde de non-régression dédiée).
        //
        // Effet ASSUMÉ et gardé : le glyphe redescend de 24 dp, car il est
        // désormais centré dans la cellule entière — exactement comme celui
        // d'une action SANS compte. C'est la correction d'une INCOHÉRENCE
        // (deux glyphes désalignés dans la même rangée), pas une régression.
        fit: StackFit.passthrough,
        children: <Widget>[
          tile,
          Positioned.fill(
            child: IgnorePointer(
              child: Badge.count(
                count: count,
                maxCount: count,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      );
    }

    if (stateLabel == null && !hasCount) return tile;

    // L'état et/ou le compte rejoignent le MÊME nœud que le bouton. Le libellé
    // d'action reste porté une seule fois par ZMenuEntryTile.
    return MergeSemantics(
      child: stateLabel == null
          ? tile
          : Semantics(value: stateLabel, child: tile),
    );
  }

  Color _readableStateTint(BuildContext context, Color base) {
    final ThemeData material = Theme.of(context);
    final Color surface =
        PopupMenuTheme.of(context).color ??
        material.colorScheme.surfaceContainer;
    return zReadableTintOn(
      base,
      surface: surface,
      minContrast: kZNonTextMinContrast,
    );
  }
}
