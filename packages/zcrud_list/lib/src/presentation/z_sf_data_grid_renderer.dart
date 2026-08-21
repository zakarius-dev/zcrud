/// Backend `SfDataGrid` du port [ZListRenderer] — **SEULE arête Syncfusion** du
/// graphe zcrud (invariant AD-8).
///
/// `zcrud_core` n'expose que l'abstraction `ZListRenderer` + les modèles
/// neutres Material-free ; le rendu concret Syncfusion vit **exclusivement**
/// ici, dans `zcrud_list`. Un consommateur qui n'importe pas `zcrud_list`
/// (ex. `zcrud_markdown` seul) ne tire donc AUCUNE dépendance Syncfusion.
///
/// **Consomme les colonnes dérivées** du cœur : une `GridColumn` par
/// `ZListColumn` du `ZListRenderRequest`, en-tête résolu au rendu
/// (`label(context, col.header)`), largeur `col.width` (si non nulle),
/// cellule via le **format neutre partagé** `col.format(row.cells[col.name])`.
///
/// **Persistance de scroll et de sélection** : le renderer délègue à un
/// `StatefulWidget` (`_ZSfDataGrid`) qui **mémoïse** la `DataGridSource`
/// (construite une fois, **mise à jour en place** via `didUpdateWidget` —
/// plus jamais recréée par `build`) et détient un `DataGridController`
/// **persistant**. La sélection Syncfusion est liée **bidirectionnellement**
/// à `ZListInteraction` (init/sync depuis `selectedIds`, remontée via
/// `onSelectionChanged`) et keyée par l'`id` STABLE de `ZListRow`. Résultat :
/// scroll & sélection **persistants** au rebuild/scroll/pagination. Les
/// actions de ligne **déjà résolues** (`interaction.actionsFor`) sont rendues
/// dans une colonne dédiée (le renderer ne voit ni `T` ni `ZAcl`).
///
/// **Réglages additifs, opt-in, zéro changement de défaut** (invariant
/// AD-10) :
/// - [ZSfDataGridRenderer.onLoadMore] : auto-`loadMore` au scroll (infinite
///   scrolling natif Syncfusion, `SfDataGrid.loadMoreViewBuilder` — déclenché
///   quand le scroll vertical atteint la fin). `null` (défaut) ⇒ AUCUN
///   `loadMoreViewBuilder` posé, widget-tree strictement identique à avant.
///   Le câblage à `ZListController.loadMore()` (chemin `backendCursor`) est
///   **hôte** : ce package ne connaît pas le contrôleur (`DynamicList` ne le
///   porte pas non plus jusqu'au renderer).
/// - [ZSfDataGridRenderer.headerRowHeight]
///   / [ZSfDataGridRenderer.withOrderNumber] / [ZSfDataGridRenderer.orderColumnHeader]
///   / [ZSfDataGridRenderer.cellColorBuilder] : réglages Syncfusion, exposés
///   comme paramètres nommés **optionnels** à défaut strictement identique au
///   rendu historique (48 dp / pas de colonne d'ordre / pas de
///   couleur de cellule).
/// - [ZSfDataGridRenderer.rowsPerPage] : **pager numéroté** (`SfDataPager`).
///   `null` (défaut) ⇒ AUCUN pager, arbre de widgets strictement identique
///   (le `SfDataGrid` reste la racine, virtualisation intacte).
/// - [ZSfDataGridRenderer.copyCellOnLongPress] : long-press d'une cellule ⇒
///   copie de la valeur **FORMATÉE** (`col.format(...)`, jamais la valeur
///   brute) + toast. `false` (défaut) ⇒ aucun `onCellLongPress` posé.
/// - [ZSfDataGridRenderer.swipeToRevealActions] : swipe start→end d'une ligne
///   ⇒ révèle les **actions de ligne DÉJÀ résolues** (`interaction.actionsFor`,
///   ACL appliquée en amont — aucun second canal d'actions). `false` (défaut)
///   ⇒ `allowSwiping: false`, aucun builder de swipe posé.
///
/// **Colonne de numéro d'ordre** : déclarée par `ZListRenderRequest.ordinal`
/// (donc par le schéma, via `ZColumnPolicy`), ou par le raccourci historique
/// [ZSfDataGridRenderer.withOrderNumber]. Elle numérote ce qui est **affiché**
/// — tri et page appliqués — et non l'ordre d'origine des lignes : le numéro
/// n'est PAS rangé dans la `DataGridRow`, il est calculé au moment de peindre
/// depuis la position de la ligne dans la séquence rendue, avec l'unique règle
/// de numérotation du cœur (`ZListOrdinal.textAt`).
///
/// **Largeur de colonnes RESPONSIVE** (parité legacy DODLP) :
/// [ZSfDataGridRenderer.columnWidthMode]
/// est désormais **nullable**. `null` (défaut) ⇒ le mode est **dérivé** de
/// (plateforme × nombre de colonnes visibles) par
/// [ZSfDataGridRenderer.responsiveColumnWidthMode] ; une valeur explicite
/// **écrase** la dérivation (échappatoire exacte pour l'hôte qui veut figer
/// `fill`).
///
/// Une implémentation legacy de coloration/numérotation opérerait sur des
/// types Syncfusion bruts (`DataGridRow`/`DataGridCell`) ; ici,
/// [cellColorBuilder] est reçu sur les types **neutres**
/// [ZListRow]/[ZListColumn] déjà publics de `zcrud_core` — AUCUN nouveau
/// champ ni AUCUNE nouvelle arête n'est ajoutée à `zcrud_core` (ce package
/// les consomme tels quels).
///
/// **Aucune clé/licence Syncfusion committée** : l'enregistrement de licence
/// (`SyncfusionLicense.registerLicense`) est une **config plateforme de l'app**
/// hôte, jamais du package.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'z_sf_grid_customization.dart';

/// Hauteur de ligne minimale (cible tactile ≥ 48 dp — AD-13).
const double _kMinRowHeight = 48;

/// Hauteur de la barre du pager numéroté (cible tactile ≥ 48 dp — AD-13).
const double _kPagerHeight = 60;

/// Largeur réservée par action révélée au swipe (cible tactile ≥ 48 dp,
/// AD-13 : le legacy réservait 36 dp/action — sous le plancher tactile).
const double _kSwipeActionWidth = 56;

/// Marge de fin ajoutée à l'offset de swipe dérivé (parité legacy : `+12`).
const double _kSwipeOffsetPadding = 12;

/// Offset de swipe **par défaut de Syncfusion**, reposé tel quel quand le
/// swipe est désactivé (valeur alors inerte : aucun swipe n'est possible).
const double _kSyncfusionDefaultSwipeMaxOffset = 200;

/// Clé l10n **par défaut** du message de confirmation de copie. Elle n'est
/// PAS enregistrée dans `zcrud_core` (ce package n'y écrit rien) : sans
/// surcharge de l'hôte, `label()` retombe sur la clé générique `'copy'`
/// (déjà traduite dans `zcrud_core`) — jamais sur un texte codé en dur ici.
const String _kCopiedMessageKey = 'list.valueCopied';

/// Clé l10n de **repli** du message de copie (générique, déjà présente dans
/// `zcrud_core` : `'copy' → « Copier » / « Copy »`).
const String _kCopyFallbackKey = 'copy';

/// Nom interne de la colonne d'actions (jamais un `field.name` réel).
const String _kActionsColumnName = '__zActions';

/// Nom **réservé** de la colonne de numéro d'ordre, emprunté au cœur pour que
/// tout consommateur (export compris) reconnaisse la colonne technique sans la
/// confondre avec un champ du schéma. Jamais un `field.name` réel.
const String _kOrderColumnName = ZListOrdinal.columnName;

/// Backend concret rendant un [ZListRenderRequest] neutre en `SfDataGrid`.
///
/// `const`-constructible : injectable tel quel via
/// `ZcrudScope(listRenderer: const ZSfDataGridRenderer(), child: ...)`.
///
/// Tous les paramètres sont **additifs et opt-in** : omis, le rendu produit
/// est **strictement identique** à la version historique (mêmes valeurs
/// Syncfusion par défaut).
class ZSfDataGridRenderer implements ZListRenderer {
  /// Construit le renderer (sans état ; immuable).
  const ZSfDataGridRenderer({
    this.onLoadMore,
    this.headerRowHeight = _kMinRowHeight,
    this.columnWidthMode,
    this.withOrderNumber = false,
    this.orderColumnHeader = '#',
    this.cellColorBuilder,
    this.rowsPerPage,
    this.copyCellOnLongPress = false,
    this.copiedMessageKey = _kCopiedMessageKey,
    this.swipeToRevealActions = false,
    this.swipeMaxOffset,
    this.stackedHeaders = const <List<ZSfStackedHeader>>[],
    this.columnSizing = const <String, ZSfColumnSizing>{},
    this.allowColumnResizing = false,
    this.adaptiveRowHeight = false,
    this.maxRowHeight,
    this.cellStyleBuilder,
  });

  /// Dérive le mode de largeur de colonnes **PUREMENT** (aucun
  /// `BuildContext`), en reproduisant la RÈGLE legacy DODLP :
  ///
  /// | Cible | Règle |
  /// |---|---|
  /// | Web / desktop | `visibleColumnCount > 3` ⇒ `auto`, sinon `fill` |
  /// | Mobile | `visibleColumnCount > 1` ⇒ `auto`, sinon `fill` |
  ///
  /// Intuition : `fill` répartit la largeur disponible (beau tant que les
  /// colonnes sont peu nombreuses) ; au-delà du seuil, `fill` écrase les
  /// contenus — `auto` dimensionne alors chaque colonne sur son contenu et
  /// laisse le défilement horizontal faire le reste. Le seuil est plus bas
  /// sur mobile (largeur physique moindre).
  ///
  /// [visibleColumnCount] compte les colonnes de **données** (les colonnes
  /// techniques `#`/actions ne comptent pas — comme le `displayedFieldLength`
  /// legacy, qui filtrait `hidden != true`).
  static ColumnWidthMode responsiveColumnWidthMode({
    required int visibleColumnCount,
    required TargetPlatform platform,
    bool isWeb = false,
  }) {
    final isWebOrDesktop = isWeb ||
        platform == TargetPlatform.linux ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows;
    final threshold = isWebOrDesktop ? 3 : 1;
    return visibleColumnCount > threshold
        ? ColumnWidthMode.auto
        : ColumnWidthMode.fill;
  }

  /// Auto-`loadMore` au scroll. `null` (défaut) : AUCUN `loadMoreViewBuilder`
  /// n'est posé sur le `SfDataGrid` — comportement STRICTEMENT identique au
  /// rendu sans pagination automatique.
  ///
  /// Non-`null` : Syncfusion déclenche ce callback quand le scroll vertical
  /// atteint la fin de la grille (infinite scrolling natif, pas de bouton) ; un
  /// indicateur de progression est affiché pendant l'attente. L'hôte le câble
  /// typiquement sur `ZListController.loadMore()`, **seulement** quand
  /// `controller.mode == ZListPaginationMode.backendCursor` (le contrôleur
  /// lui-même est un no-op sûr si aucune page suivante n'existe).
  final Future<void> Function()? onLoadMore;

  /// Hauteur de la ligne d'en-tête. Défaut [_kMinRowHeight] (48 dp, invariant
  /// AD-13) : valeur strictement inchangée par rapport au rendu historique.
  /// L'en-tête n'étant pas une cible tactile dans ce renderer (aucun tri par
  /// tap câblé), l'appelant reste libre d'y descendre sous 48 dp sous sa
  /// propre responsabilité.
  final double headerRowHeight;

  /// Mode de répartition des largeurs de colonnes, ou `null` (défaut) pour
  /// le laisser **dériver** de (plateforme × nombre de colonnes visibles) par
  /// [responsiveColumnWidthMode] — parité legacy.
  ///
  /// ⚠️ **Seul changement de défaut du lot** : un hôte **passif** (qui ne
  /// passait pas ce paramètre) obtenait `fill` en toute circonstance ; il
  /// obtient désormais `fill` **en deçà** du seuil (≤ 3 colonnes en
  /// web/desktop, ≤ 1 en mobile) et `auto` au-delà. Pour figer l'ancien
  /// comportement : passer explicitement `columnWidthMode:
  /// ColumnWidthMode.fill`.
  final ColumnWidthMode? columnWidthMode;

  /// Ajoute une colonne de numéro d'ordre (`#`) en tête de grille, **quand la
  /// requête n'en déclare pas** (`ZListRenderRequest.ordinal`). Défaut
  /// `false` : aucune colonne ajoutée, comportement inchangé.
  ///
  /// C'est le **raccourci historique** de la déclaration portée par le
  /// schéma : `ZColumnPolicy(ordinal: ZListOrdinal(enabled: true))`. Les deux
  /// chemins produisent la même colonne et la même numérotation ; la
  /// déclaration de la requête **prime** quand elle est active, parce qu'elle
  /// porte aussi l'en-tête, la largeur et le décalage de page. Ce raccourci
  /// reste utile à l'hôte qui construit sa requête sans politique de colonnes.
  ///
  /// Dans les deux cas, le numéro décrit la **position à l'écran** : la
  /// première ligne affichée porte `1`, la deuxième `2` — un tri renumérote
  /// donc la colonne au lieu de promener d'anciens numéros.
  final bool withOrderNumber;

  /// En-tête de la colonne de numéro d'ordre quand [withOrderNumber] est le
  /// chemin retenu (cf. ci-dessus). Défaut `'#'` (symbole ordinal universel,
  /// non dépendant de la langue). Personnalisable par l'hôte (sa propre l10n)
  /// sans toucher `zcrud_core`. Sans effet quand la requête déclare son
  /// ordinal : c'est alors `ZListOrdinal.header` qui fait foi.
  final String orderColumnHeader;

  /// Couleur de fond par cellule, résolue depuis les types **neutres** déjà
  /// publics de `zcrud_core` ([ZListRow] complet de la ligne + [ZListColumn]
  /// courante), SANS exposer de type Syncfusion à l'appelant ni ajouter de
  /// champ à `ZListColumn`/`ZListRow` (`zcrud_core` intact). Défaut `null` :
  /// aucune coloration, comportement inchangé. Ne doit jamais lever (invariant
  /// AD-10) ; une exception de l'appelant est **propagée telle quelle** (pas
  /// de `try/catch` silencieux ici — l'appelant reste responsable de son
  /// builder).
  final Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder;

  /// Nombre de lignes par page du **pager numéroté** (`SfDataPager`), ou
  /// `null` (défaut) pour n'en poser AUCUN.
  ///
  /// Non-`null` (et > 0) : la grille ne rend plus que la **tranche** de la
  /// page courante et une barre de pagination numérotée est ajoutée sous la
  /// grille (`Column` → `Expanded(SfDataGrid)` + pager). La virtualisation
  /// Syncfusion est **conservée** (la grille reste une liste virtualisée de
  /// la tranche ; aucun `children: [...]` de lignes n'est construit).
  ///
  /// Ce pager pagine **côté client** l'instantané `request.rows` déjà en
  /// mémoire : il est **orthogonal** à [onLoadMore] (pagination backend par
  /// curseur). Les deux peuvent coexister, mais un hôte qui pagine côté
  /// backend n'a normalement pas besoin de celui-ci.
  final int? rowsPerPage;

  /// Long-press d'une cellule ⇒ copie de sa valeur **FORMATÉE** dans le
  /// presse-papiers + toast de confirmation. Défaut `false` : AUCUN
  /// `onCellLongPress` n'est posé sur le `SfDataGrid`.
  ///
  /// La valeur copiée est **toujours** `col.format(row.cells[col.name])` — le
  /// texte exact affiché à l'écran — jamais la valeur brute (le legacy DODLP
  /// copiait le brut : un `select` partait au presse-papiers sous sa clé
  /// technique au lieu de son libellé). Les colonnes techniques (`#`,
  /// actions) et la ligne d'en-tête ne copient rien. Ne lève jamais
  /// (invariant AD-10) : un échec du presse-papiers est absorbé sans toast.
  final bool copyCellOnLongPress;

  /// Clé l10n du message de confirmation de copie. Défaut
  /// `'list.valueCopied'`, **non enregistrée** dans `zcrud_core` : sans
  /// surcharge de l'hôte (`ZcrudScope.labels`), le toast affiche le libellé
  /// de la clé générique `'copy'` (« Copier »/« Copy »), déjà traduite dans
  /// le cœur. Aucun texte codé en dur, aucune clé ajoutée au cœur.
  final String copiedMessageKey;

  /// Swipe start→end d'une ligne ⇒ révèle ses actions **déjà résolues**
  /// (`interaction.actionsFor`, filtrées/liées par l'ACL en amont). Défaut
  /// `false` : `allowSwiping: false`, aucun builder de swipe posé.
  ///
  /// N'ouvre **aucun second canal d'actions** : ce sont exactement les
  /// `ZResolvedRowAction` de la colonne d'actions (mêmes libellés, même
  /// `enabled` ACL, mêmes callbacks). Sans `actionsFor`, le swipe reste
  /// désactivé même à `true` (rien à révéler).
  final bool swipeToRevealActions;

  /// Offset maximal de swipe (px logiques), ou `null` (défaut) pour le
  /// **dériver** du nombre maximal d'actions d'une ligne
  /// (`n × 56 + 12` — parité legacy `n × 36 + 12`, relevé au plancher
  /// tactile de 48 dp, AD-13). Sans effet si [swipeToRevealActions] est
  /// `false`.
  final double? swipeMaxOffset;

  /// **En-têtes multi-lignes** : lignes d'en-tête EMPILÉES au-dessus de la
  /// ligne d'en-tête normale, de haut en bas (chaque élément = une ligne,
  /// composée de groupes [ZSfStackedHeader] couvrant chacun plusieurs
  /// colonnes). Défaut : liste vide ⇒ `stackedHeaderRows` vide, en-tête
  /// simple, rendu strictement inchangé.
  ///
  /// Les libellés sont des **clés l10n** résolues au rendu et le fond dérive
  /// du `ColorScheme` du thème (FR-26 : aucun hex ici).
  final List<List<ZSfStackedHeader>> stackedHeaders;

  /// **Dimensionnement par colonne**, indexé par `ZListColumn.name`
  /// (largeur fixe, min/max, mode de largeur spécifique, marge d'auto-fit —
  /// cf. [ZSfColumnSizing]). Défaut : map vide ⇒ chaque `GridColumn` garde
  /// exactement ses valeurs d'origine (largeur dérivée du schéma, défauts
  /// Syncfusion pour le reste).
  ///
  /// Priorité de largeur : [ZSfColumnSizing.width] > `ZListColumn.width`
  /// (dérivée du type de champ) > mode de largeur (colonne, puis grille).
  final Map<String, ZSfColumnSizing> columnSizing;

  /// Autorise le **redimensionnement de colonne par l'utilisateur** (glisser
  /// la bordure d'en-tête). Défaut `false` (rendu inchangé).
  ///
  /// Les largeurs redimensionnées sont **conservées** dans un
  /// `ValueNotifier` local au widget de grille : elles survivent aux rebuilds
  /// SANS `setState` à l'échelle de la liste (AD-2) — seule la sous-arborescence
  /// de la grille est reconstruite, la `DataGridSource` mémoïsée et le
  /// `DataGridController` (donc scroll et sélection) sont préservés.
  final bool allowColumnResizing;

  /// **Hauteur de ligne adaptative au contenu** : chaque ligne prend la
  /// hauteur INTRINSÈQUE de sa donnée (texte long rendu sur plusieurs
  /// lignes), plancher [_kMinRowHeight] (48 dp, AD-13), plafond
  /// [maxRowHeight] s'il est fourni. Défaut `false` : hauteur fixe de 48 dp
  /// et cellules tronquées à l'ellipse — rendu strictement inchangé.
  ///
  /// À `true`, les cellules de données **passent à la ligne** (`softWrap`,
  /// plus d'ellipse) et s'alignent en haut : sans cela la hauteur
  /// intrinsèque resterait celle d'une ligne unique et le réglage serait
  /// inerte.
  final bool adaptiveRowHeight;

  /// Plafond de hauteur de ligne quand [adaptiveRowHeight] est actif, ou
  /// `null` (défaut) pour ne pas plafonner. Sans effet sinon.
  final double? maxRowHeight;

  /// **Style CONDITIONNEL par cellule** : résolu à chaque rendu de ligne
  /// depuis les types **neutres** déjà publics de `zcrud_core` ([ZListRow]
  /// complet + [ZListColumn] courante), et renvoyant un [ZSfCellStyle] (fond,
  /// style de texte, alignement, marge, `maxLines`) ou `null` pour laisser la
  /// cellule au rendu par défaut. Défaut `null` : aucun style conditionnel,
  /// rendu strictement inchangé.
  ///
  /// C'est la généralisation de [cellColorBuilder] (conservé, rétro-compatible)
  /// : si les DEUX sont fournis, le fond de [cellStyleBuilder] est
  /// **prioritaire**, et il retombe sur celui de [cellColorBuilder] quand il
  /// ne déclare pas de fond.
  ///
  /// Aucun type Syncfusion n'est exposé à l'appelant et AUCUN champ n'est
  /// ajouté à `zcrud_core`. Ne doit jamais lever (AD-10) ; une exception de
  /// l'appelant est **propagée telle quelle** (l'appelant reste responsable de
  /// son builder).
  final ZSfCellStyle? Function(ZListRow row, ZListColumn column)?
      cellStyleBuilder;

  @override
  Widget build(
    BuildContext context,
    ZListRenderRequest request, {
    ZListInteraction? interaction,
  }) {
    return _ZSfDataGrid(
      request: request,
      interaction: interaction,
      onLoadMore: onLoadMore,
      headerRowHeight: headerRowHeight,
      columnWidthMode: columnWidthMode,
      withOrderNumber: withOrderNumber,
      orderColumnHeader: orderColumnHeader,
      cellColorBuilder: cellColorBuilder,
      rowsPerPage: rowsPerPage,
      copyCellOnLongPress: copyCellOnLongPress,
      copiedMessageKey: copiedMessageKey,
      swipeToRevealActions: swipeToRevealActions,
      swipeMaxOffset: swipeMaxOffset,
      stackedHeaders: stackedHeaders,
      columnSizing: columnSizing,
      allowColumnResizing: allowColumnResizing,
      adaptiveRowHeight: adaptiveRowHeight,
      maxRowHeight: maxRowHeight,
      cellStyleBuilder: cellStyleBuilder,
    );
  }
}

/// Widget stateful portant la source **mémoïsée** + le `DataGridController`
/// **persistant**. C'est lui qui immunise scroll/sélection contre les
/// rebuilds.
class _ZSfDataGrid extends StatefulWidget {
  const _ZSfDataGrid({
    required this.request,
    this.interaction,
    this.onLoadMore,
    this.headerRowHeight = _kMinRowHeight,
    this.columnWidthMode,
    this.withOrderNumber = false,
    this.orderColumnHeader = '#',
    this.cellColorBuilder,
    this.rowsPerPage,
    this.copyCellOnLongPress = false,
    this.copiedMessageKey = _kCopiedMessageKey,
    this.swipeToRevealActions = false,
    this.swipeMaxOffset,
    this.stackedHeaders = const <List<ZSfStackedHeader>>[],
    this.columnSizing = const <String, ZSfColumnSizing>{},
    this.allowColumnResizing = false,
    this.adaptiveRowHeight = false,
    this.maxRowHeight,
    this.cellStyleBuilder,
  });

  final ZListRenderRequest request;
  final ZListInteraction? interaction;
  final Future<void> Function()? onLoadMore;
  final double headerRowHeight;
  final ColumnWidthMode? columnWidthMode;
  final bool withOrderNumber;
  final String orderColumnHeader;
  final Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder;
  final int? rowsPerPage;
  final bool copyCellOnLongPress;
  final String copiedMessageKey;
  final bool swipeToRevealActions;
  final double? swipeMaxOffset;
  final List<List<ZSfStackedHeader>> stackedHeaders;
  final Map<String, ZSfColumnSizing> columnSizing;
  final bool allowColumnResizing;
  final bool adaptiveRowHeight;
  final double? maxRowHeight;
  final ZSfCellStyle? Function(ZListRow row, ZListColumn column)?
      cellStyleBuilder;

  @override
  State<_ZSfDataGrid> createState() => _ZSfDataGridState();
}

class _ZSfDataGridState extends State<_ZSfDataGrid> {
  late _ZListDataGridSource _source;
  final DataGridController _controller = DataGridController();
  // Contrôleur du pager numéroté — créé UNE FOIS et conservé (jamais recréé
  // par `build`, comme `_controller`) pour que la page courante survive aux
  // rebuilds. Instancié même quand le pager n'est pas monté (objet inerte et
  // sans coût : aucune allocation Syncfusion lourde).
  final DataPagerController _pagerController = DataPagerController();
  // Largeurs redimensionnées par l'utilisateur, par `columnName`. Notifier
  // LOCAL (jamais un `setState` à l'échelle de la liste, AD-2) ; consommé par
  // un `ValueListenableBuilder` posé UNIQUEMENT quand le redimensionnement
  // est autorisé.
  final ValueNotifier<Map<String, double>> _resizedWidths =
      ValueNotifier<Map<String, double>>(const <String, double>{});
  bool _syncingSelection = false;

  bool get _hasActions => widget.interaction?.actionsFor != null;

  /// Déclaration EFFECTIVE de la colonne de numéro d'ordre.
  ///
  /// La déclaration portée par la requête (donc par le schéma, via
  /// `ZColumnPolicy`) fait foi dès qu'elle est active : elle porte en-tête,
  /// largeur et décalage de page. À défaut, le raccourci historique
  /// `withOrderNumber` est traduit dans le MÊME vocabulaire — de sorte que la
  /// numérotation n'a jamais deux règles, quel que soit le chemin déclaratif
  /// emprunté.
  static ZListOrdinal _ordinalOf(_ZSfDataGrid widget) {
    final declared = widget.request.ordinal;
    if (declared.enabled) return declared;
    if (!widget.withOrderNumber) return const ZListOrdinal();
    return ZListOrdinal(enabled: true, header: widget.orderColumnHeader);
  }

  ZListOrdinal get _ordinal => _ordinalOf(widget);

  /// Pager monté ssi un [_ZSfDataGrid.rowsPerPage] strictement positif est
  /// fourni (défaut `null` ⇒ jamais).
  bool get _hasPager => (widget.rowsPerPage ?? 0) > 0;

  /// Swipe actif ssi demandé ET qu'il y a des actions à révéler (sans
  /// `actionsFor`, un swipe ne révélerait rien : autant le désactiver).
  bool get _swipeEnabled => widget.swipeToRevealActions && _hasActions;

  @override
  void initState() {
    super.initState();
    _source = _ZListDataGridSource(
      widget.request.columns,
      widget.request.rows,
      actionsFor: widget.interaction?.actionsFor,
      ordinal: _ordinal,
      cellColorBuilder: widget.cellColorBuilder,
      onLoadMore: widget.onLoadMore,
      rowsPerPage: widget.rowsPerPage,
      wrapCellText: widget.adaptiveRowHeight,
      cellStyleBuilder: widget.cellStyleBuilder,
    );
    _syncControllerFromInteraction();
  }

  @override
  void didUpdateWidget(_ZSfDataGrid old) {
    super.didUpdateWidget(old);
    final newActionsFor = widget.interaction?.actionsFor;
    final oldActionsFor = old.interaction?.actionsFor;
    // La PRÉSENCE d'actions (null ↔ non-null) modifie le nombre de cellules par
    // ligne (colonne d'actions) → reconstruction nécessaire.
    final actionsPresenceChanged =
        (newActionsFor != null) != (oldActionsFor != null);
    // La colonne d'ordre modifie elle aussi le nombre de cellules par ligne.
    final newOrdinal = _ordinal;
    final oldOrdinal = _ordinalOf(old);
    final orderNumberChanged = newOrdinal != oldOrdinal;

    // La taille de page change la TRANCHE visible : la source doit la
    // recalculer (mise à jour en place, jamais de recréation).
    if (widget.rowsPerPage != old.rowsPerPage) {
      _source.refreshRowsPerPage(widget.rowsPerPage);
    }
    // Le passage à la ligne des cellules suit la hauteur adaptative.
    if (widget.adaptiveRowHeight != old.adaptiveRowHeight) {
      _source.refreshWrapCellText(widget.adaptiveRowHeight);
    }

    if (widget.request != old.request ||
        actionsPresenceChanged ||
        orderNumberChanged) {
      // MISE À JOUR EN PLACE de la source mémoïsée (jamais recréée) quand les
      // DONNÉES (lignes/colonnes) — ou la présence d'actions/colonne d'ordre —
      // changent : reconstruit les `DataGridRow` puis notifie la grille.
      _source.update(
        widget.request.columns,
        widget.request.rows,
        newActionsFor,
        ordinal: newOrdinal,
      );
    } else if (!identical(newActionsFor, oldActionsFor)) {
      // Performance : SEULE la closure `actionsFor` a changé d'identité
      // (recréée à chaque `build` de `DynamicList._buildInteraction`, ex. à
      // chaque changement de sélection) alors que les DONNÉES sont inchangées.
      // On RAFRAÎCHIT uniquement la référence de résolution SANS effacer /
      // reconstruire les `DataGridRow` (l'actions-cell est résolue
      // paresseusement dans `buildRow`) : cocher une case ne reconstruit plus
      // toute la source de grille (mémoïsation préservée).
      _source.refreshActions(newActionsFor);
    }
    // `cellColorBuilder`/`onLoadMore` ne touchent ni le nombre ni l'identité des
    // `DataGridRow` : rafraîchi paresseusement, comme `actionsFor`.
    if (!identical(widget.cellColorBuilder, old.cellColorBuilder)) {
      _source.refreshCellColorBuilder(widget.cellColorBuilder);
    }
    if (!identical(widget.cellStyleBuilder, old.cellStyleBuilder)) {
      _source.refreshCellStyleBuilder(widget.cellStyleBuilder);
    }
    if (!identical(widget.onLoadMore, old.onLoadMore)) {
      _source.refreshOnLoadMore(widget.onLoadMore);
    }
    // Re-synchronise la sélection Syncfusion depuis l'état neutre (source de
    // vérité = `ZListInteraction.selectedIds`, keyé par `id`).
    _syncControllerFromInteraction();
  }

  SelectionMode get _selectionMode {
    switch (widget.interaction?.mode ?? ZListSelectionMode.none) {
      case ZListSelectionMode.none:
        return SelectionMode.none;
      case ZListSelectionMode.single:
        return SelectionMode.single;
      case ZListSelectionMode.multiple:
        return SelectionMode.multiple;
    }
  }

  /// Aligne `controller.selectedRows` sur `interaction.selectedIds` (keyé par
  /// `id`). Marqué `_syncingSelection` pour ne pas re-remonter ce changement
  /// programmatique comme une sélection utilisateur.
  void _syncControllerFromInteraction() {
    final interaction = widget.interaction;
    if (interaction == null || interaction.mode == ZListSelectionMode.none) {
      return;
    }
    final wanted = interaction.selectedIds;
    final rows = <DataGridRow>[
      for (final entry in _source.indexedRows)
        if (wanted.contains(entry.value.id)) entry.key,
    ];
    _syncingSelection = true;
    _controller.selectedRows = rows;
    _syncingSelection = false;
  }

  /// Remonte la sélection utilisateur (mappée `DataGridRow → id` stable) vers
  /// l'état neutre via `interaction.onSelectionChanged`.
  void _handleSelectionChanged(
    List<DataGridRow> addedRows,
    List<DataGridRow> removedRows,
  ) {
    if (_syncingSelection) return;
    final onChanged = widget.interaction?.onSelectionChanged;
    if (onChanged == null) return;
    final ids = <String>{
      for (final row in _controller.selectedRows)
        if (_source.idOf(row) case final String id) id,
    };
    onChanged(ids);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pagerController.dispose();
    _resizedWidths.dispose();
    _source.visibleSliceRevision.dispose();
    super.dispose();
  }

  /// Mode de largeur EFFECTIF : la valeur explicite de l'hôte si elle existe,
  /// sinon la dérivation responsive (plateforme × colonnes de DONNÉES).
  ColumnWidthMode _resolveColumnWidthMode(BuildContext context) {
    final explicit = widget.columnWidthMode;
    if (explicit != null) return explicit;
    return ZSfDataGridRenderer.responsiveColumnWidthMode(
      visibleColumnCount: widget.request.columns.length,
      platform: Theme.of(context).platform,
      isWeb: kIsWeb,
    );
  }

  /// Offset de swipe EFFECTIF (cf. [_ZSfDataGrid.swipeMaxOffset]).
  double get _resolvedSwipeMaxOffset {
    final explicit = widget.swipeMaxOffset;
    if (explicit != null) return explicit;
    final count = _source.maxActionCount();
    if (count <= 0) return _kMinRowHeight;
    return count * _kSwipeActionWidth + _kSwipeOffsetPadding;
  }

  /// Long-press d'une cellule : copie la valeur **FORMATÉE**.
  ///
  /// `rowIndex == 0` est la ligne d'EN-TÊTE Syncfusion (aucune donnée) ; les
  /// lignes de données commencent à 1. Une colonne technique (`#`, actions)
  /// ou un index hors tranche rend `null` ⇒ no-op silencieux (AD-10).
  void _handleCellLongPress(DataGridCellLongPressDetails details) {
    final rowIndex = details.rowColumnIndex.rowIndex;
    if (rowIndex <= 0) return;
    final text = _source.formattedCellAt(
      rowIndex - 1,
      details.column.columnName,
    );
    if (text == null || text.isEmpty) return;
    unawaited(_copyToClipboard(context, text));
  }

  /// Copie [text] puis notifie via le **toaster injecté** de `zcrud_ui_kit`
  /// (`zToast` → `ZToasterScope`, repli `ScaffoldMessenger`). **Ne lève
  /// jamais** (AD-10) : un échec de la plateforme est absorbé, sans toast de
  /// succès mensonger.
  Future<void> _copyToClipboard(BuildContext context, String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on Object {
      return;
    }
    if (!context.mounted) return;
    zToast(
      context,
      label(
        context,
        widget.copiedMessageKey,
        fallback: label(context, _kCopyFallbackKey),
      ),
      severity: ZToastSeverity.success,
    );
  }

  /// `SfDataGrid.onSwipeStart` : n'autorise que le sens **start→end**
  /// (parité legacy) — le sens inverse est refusé.
  bool _handleSwipeStart(DataGridSwipeStartDetails details) =>
      details.swipeDirection == DataGridRowSwipeDirection.startToEnd;

  /// `SfDataGrid.startSwipeActionsBuilder` : révèle les actions **déjà
  /// résolues** de la ligne (aucun second canal d'actions).
  Widget _buildSwipeActions(BuildContext context, DataGridRow row, int index) {
    final source = _source.sourceRowOf(row);
    final actions = source == null
        ? const <ZResolvedRowAction>[]
        : (widget.interaction?.actionsFor?.call(source) ??
            const <ZResolvedRowAction>[]);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final action in actions) _ZSfRowActionButton(action: action),
        ],
      ),
    );
  }

  /// Applique le dimensionnement demandé pour [name] à une `GridColumn` —
  /// **champ par champ** : un réglage absent laisse la valeur d'origine
  /// ([fallbackWidth] pour la largeur, défaut Syncfusion pour le reste).
  GridColumn _sizedColumn({
    required String name,
    required Widget label,
    required double fallbackWidth,
    bool allowSorting = true,
  }) {
    final sizing = widget.columnSizing[name];
    // Largeur redimensionnée par l'utilisateur : prioritaire (c'est son geste
    // le plus récent), sinon la largeur déclarée, sinon la largeur dérivée.
    final resized = _resizedWidths.value[name];
    return GridColumn(
      columnName: name,
      label: label,
      allowSorting: allowSorting,
      width: resized ?? sizing?.width ?? fallbackWidth,
      minimumWidth: sizing?.minimumWidth ?? double.nan,
      maximumWidth: sizing?.maximumWidth ?? double.nan,
      columnWidthMode: sizing?.widthMode ?? ColumnWidthMode.none,
      autoFitPadding: sizing?.autoFitPadding == null
          ? const EdgeInsets.all(16)
          : EdgeInsets.all(sizing!.autoFitPadding!),
    );
  }

  /// Lignes d'en-tête EMPILÉES (multi-lignes), ou liste vide (défaut).
  /// Libellés = clés l10n résolues au rendu ; fond dérivé du `ColorScheme`
  /// (FR-26 : aucune couleur codée en dur).
  List<StackedHeaderRow> _buildStackedHeaderRows(BuildContext context) {
    if (widget.stackedHeaders.isEmpty) return const <StackedHeaderRow>[];
    final scheme = Theme.of(context).colorScheme;
    return <StackedHeaderRow>[
      for (final row in widget.stackedHeaders)
        StackedHeaderRow(
          cells: <StackedHeaderCell>[
            for (final group in row)
              StackedHeaderCell(
                columnNames: group.columnNames,
                child: Semantics(
                  header: true,
                  container: true,
                  child: Container(
                    alignment: AlignmentDirectional.center,
                    padding:
                        const EdgeInsetsDirectional.symmetric(horizontal: 12),
                    color: scheme.surfaceContainerHighest,
                    child: Text(
                      label(context, group.labelKey),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    ];
  }

  /// `SfDataGrid.onQueryRowHeight` (posé UNIQUEMENT si
  /// [_ZSfDataGrid.adaptiveRowHeight]) : hauteur INTRINSÈQUE du contenu,
  /// bornée par le plancher tactile 48 dp (AD-13) et le plafond optionnel.
  double _queryRowHeight(RowHeightDetails details) {
    final intrinsic = details.getIntrinsicRowHeight(details.rowIndex);
    final max = widget.maxRowHeight;
    if (intrinsic < _kMinRowHeight) return _kMinRowHeight;
    if (max != null && intrinsic > max) return max;
    return intrinsic;
  }

  /// Persiste la largeur redimensionnée par l'utilisateur SANS `setState` à
  /// l'échelle de la liste (AD-2) : la notification ne reconstruit que la
  /// sous-arborescence du `ValueListenableBuilder` posé autour de la grille
  /// (source mémoïsée et `DataGridController` préservés ⇒ scroll et sélection
  /// intacts).
  bool _handleColumnResizeUpdate(ColumnResizeUpdateDetails details) {
    _resizedWidths.value = <String, double>{
      ..._resizedWidths.value,
      details.column.columnName: details.width,
    };
    return true;
  }

  /// L'offset de swipe **dérivé** dépend des lignes réellement rendues : avec
  /// un pager, la tranche change sans que ce widget soit reconstruit. Ce
  /// rafraîchissement n'est donc nécessaire que si les trois conditions sont
  /// réunies — pager monté, swipe actif, offset non imposé par l'appelant.
  bool get _followsVisibleSlice =>
      _hasPager && _swipeEnabled && widget.swipeMaxOffset == null;

  @override
  Widget build(BuildContext context) {
    // Le redimensionnement interactif est le SEUL cas où la grille doit se
    // reconstruire sur un état local : on n'interpose le builder QUE là
    // (défaut ⇒ arbre de widgets strictement identique au rendu historique).
    if (!widget.allowColumnResizing) return _buildSliceAwareGrid(context);
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: _resizedWidths,
      builder: (context, _, _) => _buildSliceAwareGrid(context),
    );
  }

  /// Reconstruit la grille quand la TRANCHE visible change, et seulement si
  /// une dimension en dépend ([_followsVisibleSlice]) : ni le rendu par
  /// défaut, ni un offset de swipe imposé n'ajoutent de builder — et ce
  /// rebuild reste confiné à la sous-arborescence de la grille (source
  /// mémoïsée et contrôleur préservés : scroll et sélection intacts, AD-2).
  Widget _buildSliceAwareGrid(BuildContext context) {
    if (!_followsVisibleSlice) return _buildGrid(context);
    return ValueListenableBuilder<int>(
      valueListenable: _source.visibleSliceRevision,
      builder: (context, _, _) => _buildGrid(context),
    );
  }

  Widget _buildGrid(BuildContext context) {
    final ordinal = _ordinal;
    final columns = <GridColumn>[
      if (ordinal.enabled)
        _sizedColumn(
          name: _kOrderColumnName,
          // La colonne d'ordre n'est PAS triable : elle décrit la position à
          // l'écran, la trier n'aurait rien à réordonner.
          allowSorting: false,
          fallbackWidth: ordinal.width,
          label: Container(
            alignment: Alignment.center,
            child: Text(
              ordinal.header,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      for (final col in widget.request.columns)
        _sizedColumn(
          name: col.name,
          fallbackWidth: col.width ?? double.nan,
          label: Container(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label(context, col.header),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      if (_hasActions)
        _sizedColumn(
          name: _kActionsColumnName,
          fallbackWidth: double.nan,
          label: const SizedBox.shrink(),
        ),
    ];

    final grid = SfDataGrid(
      source: _source,
      controller: _controller,
      columns: columns,
      stackedHeaderRows: _buildStackedHeaderRows(context),
      rowHeight: _kMinRowHeight,
      headerRowHeight: widget.headerRowHeight,
      columnWidthMode: _resolveColumnWidthMode(context),
      gridLinesVisibility: GridLinesVisibility.horizontal,
      headerGridLinesVisibility: GridLinesVisibility.horizontal,
      selectionMode: _selectionMode,
      navigationMode: GridNavigationMode.row,
      onSelectionChanged: _handleSelectionChanged,
      onCellLongPress: widget.copyCellOnLongPress ? _handleCellLongPress : null,
      allowSwiping: _swipeEnabled,
      swipeMaxOffset: _swipeEnabled
          ? _resolvedSwipeMaxOffset
          : _kSyncfusionDefaultSwipeMaxOffset,
      onSwipeStart: _swipeEnabled ? _handleSwipeStart : null,
      startSwipeActionsBuilder: _swipeEnabled ? _buildSwipeActions : null,
      allowColumnsResizing: widget.allowColumnResizing,
      onColumnResizeUpdate:
          widget.allowColumnResizing ? _handleColumnResizeUpdate : null,
      onQueryRowHeight: widget.adaptiveRowHeight ? _queryRowHeight : null,
      loadMoreViewBuilder:
          widget.onLoadMore == null ? null : _buildLoadMoreView,
    );

    // Défaut (`rowsPerPage == null`) : la grille est la RACINE — arbre de
    // widgets strictement identique au rendu historique (pas de `Column`
    // interposée, aucun pager).
    if (!_hasPager) return grid;

    return Column(
      children: <Widget>[
        // La grille garde tout l'espace restant ET sa virtualisation (elle ne
        // rend que la tranche de la page courante, ligne par ligne).
        Expanded(child: grid),
        SizedBox(
          height: _kPagerHeight,
          child: SfDataPager(
            delegate: _source,
            controller: _pagerController,
            pageCount: _source.pageCount.toDouble(),
            direction: Axis.horizontal,
          ),
        ),
      ],
    );
  }

  /// `SfDataGrid.loadMoreViewBuilder` : rendu quand le scroll vertical
  /// atteint la fin ET que [ZSfDataGridRenderer.onLoadMore] est fourni. Posé
  /// sur `SfDataGrid` QUE dans ce cas (`build`, ci-dessus) — un renderer par
  /// défaut (`onLoadMore == null`) ne voit jamais ce builder appelé.
  Widget? _buildLoadMoreView(BuildContext context, LoadMoreRows loadMoreRows) {
    return _ZAutoLoadMoreView(loadMoreRows: loadMoreRows);
  }
}

/// Vue "infinite scrolling" : déclenche IMMÉDIATEMENT [loadMoreRows] (pas de
/// bouton — auto-`loadMore` dès que le scroll vertical atteint la fin de
/// l'extent, seuil natif Syncfusion) et affiche un indicateur de progression
/// accessible pendant l'attente ; se réduit à une hauteur nulle une fois la
/// page intégrée. Réutilise la clé l10n `list.loading` déjà enregistrée dans
/// `zcrud_core` (AUCUNE nouvelle clé, ce package n'écrit pas dans
/// `zcrud_core`).
class _ZAutoLoadMoreView extends StatefulWidget {
  const _ZAutoLoadMoreView({required this.loadMoreRows});

  final LoadMoreRows loadMoreRows;

  @override
  State<_ZAutoLoadMoreView> createState() => _ZAutoLoadMoreViewState();
}

class _ZAutoLoadMoreViewState extends State<_ZAutoLoadMoreView> {
  // Capturé UNE FOIS à la création de l'état : Syncfusion recrée ce widget à
  // chaque déclenchement de fin de scroll (`_isLoadMoreViewLoaded` remis à
  // `false` par la source amont), jamais pendant l'attente d'un même appel.
  late final Future<void> _future = widget.loadMoreRows();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Semantics(
            liveRegion: true,
            container: true,
            label: label(context, 'list.loading'),
            child: const SizedBox(
              height: _kMinRowHeight,
              width: double.infinity,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Source de données `SfDataGrid` **mémoïsée** mappant chaque [ZListRow] vers
/// une `DataGridRow` de cellules texte via le **format neutre partagé**
/// `col.format(row.cells[col.name])`. Une cellule d'actions (widgets déjà
/// résolus) est ajoutée si [_actionsFor] est fourni. Mise à jour **en place**
/// via [update] (jamais recréée par `build`).
class _ZListDataGridSource extends DataGridSource {
  _ZListDataGridSource(
    List<ZListColumn> columns,
    List<ZListRow> rows, {
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor,
    ZListOrdinal ordinal = const ZListOrdinal(),
    Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder,
    Future<void> Function()? onLoadMore,
    int? rowsPerPage,
    bool wrapCellText = false,
    ZSfCellStyle? Function(ZListRow row, ZListColumn column)? cellStyleBuilder,
  }) {
    _cellColorBuilder = cellColorBuilder;
    _cellStyleBuilder = cellStyleBuilder;
    _onLoadMore = onLoadMore;
    _rowsPerPage = rowsPerPage;
    _wrapCellText = wrapCellText;
    update(columns, rows, actionsFor, ordinal: ordinal);
  }

  List<ZListColumn> _columns = const <ZListColumn>[];
  List<ZResolvedRowAction> Function(ZListRow row)? _actionsFor;
  ZListOrdinal _ordinal = const ZListOrdinal();
  Color? Function(ZListRow row, ZListColumn column)? _cellColorBuilder;
  ZSfCellStyle? Function(ZListRow row, ZListColumn column)? _cellStyleBuilder;
  Future<void> Function()? _onLoadMore;
  int? _rowsPerPage;
  bool _wrapCellText = false;
  int _pageIndex = 0;
  int? _maxActionCountCache;

  /// Révision de la **tranche visible** : incrémentée à chaque recalcul
  /// (changement de page, de taille de page, ou mise à jour des données).
  ///
  /// Elle permet aux dimensions dérivées du contenu réellement rendu de rester
  /// justes après une navigation de page — le pager ne rafraîchit que la
  /// grille, pas le widget qui porte ces dimensions.
  final ValueNotifier<int> visibleSliceRevision = ValueNotifier<int>(0);

  final List<DataGridRow> _dataRows = <DataGridRow>[];
  // Tranche VISIBLE (= [_dataRows] entier quand aucune pagination n'est
  // active : le défaut ne dévie donc jamais du rendu historique).
  List<DataGridRow> _visibleRows = const <DataGridRow>[];
  // Association DataGridRow → ZListRow (identité) pour retrouver l'`id` stable et
  // l'entité d'origine sans encoder l'`id` dans une cellule visible.
  final Map<DataGridRow, ZListRow> _rowByData = <DataGridRow, ZListRow>{};

  bool get _hasActions => _actionsFor != null;

  @override
  List<DataGridRow> get rows => _visibleRows;

  /// Paires (DataGridRow, ZListRow) **de la tranche visible**, dans l'ordre,
  /// pour la synchronisation de sélection keyée par `id`. Sans pagination, la
  /// tranche est la totalité des lignes (comportement inchangé) ; avec
  /// pagination, on ne resélectionne jamais une ligne absente de la grille.
  Iterable<MapEntry<DataGridRow, ZListRow>> get indexedRows sync* {
    for (final data in _visibleRows) {
      final source = _rowByData[data];
      if (source != null) yield MapEntry(data, source);
    }
  }

  /// Retrouve l'`id` stable d'une [row] Syncfusion (ou `null` si inconnue).
  String? idOf(DataGridRow row) => _rowByData[row]?.id;

  /// Retrouve la [ZListRow] NEUTRE d'origine d'une [row] Syncfusion.
  ZListRow? sourceRowOf(DataGridRow row) => _rowByData[row];

  /// Nombre de pages du pager (≥ 1 : `SfDataPager` asserte `pageCount > 0`).
  int get pageCount {
    final perPage = _rowsPerPage;
    if (perPage == null || perPage <= 0) return 1;
    if (_dataRows.isEmpty) return 1;
    return (_dataRows.length / perPage).ceil();
  }

  /// Nombre MAXIMAL d'actions résolues sur une ligne de la tranche visible
  /// (mémoïsé ; invalidé par [update]/[refreshActions]/[refreshRowsPerPage]).
  /// Sert à dimensionner l'offset de swipe. Renvoie `0` sans `actionsFor`.
  int maxActionCount() {
    final cached = _maxActionCountCache;
    if (cached != null) return cached;
    final resolve = _actionsFor;
    var max = 0;
    if (resolve != null) {
      for (final data in _visibleRows) {
        final source = _rowByData[data];
        if (source == null) continue;
        final n = resolve(source).length;
        if (n > max) max = n;
      }
    }
    _maxActionCountCache = max;
    return max;
  }

  /// Valeur **FORMATÉE** (`col.format(...)` — le texte exact affiché) de la
  /// cellule ([visibleRowIndex], [columnName]) de la tranche visible, ou
  /// `null` si l'index est hors tranche ou si la colonne est **technique**
  /// (numéro d'ordre / actions : rien à copier).
  ///
  /// ⚠️ **Jamais la valeur brute** : `row.cells[name]` est opaque (une clé
  /// technique de `select`, un `DateTime`, un `bool`…). Copier le brut
  /// mettrait au presse-papiers autre chose que ce que l'utilisateur voit.
  String? formattedCellAt(int visibleRowIndex, String columnName) {
    if (visibleRowIndex < 0 || visibleRowIndex >= _visibleRows.length) {
      return null;
    }
    final source = _rowByData[_visibleRows[visibleRowIndex]];
    if (source == null) return null;
    for (final col in _columns) {
      if (col.name == columnName) return col.format(source.cells[col.name]);
    }
    return null;
  }

  /// Recalcule la tranche visible depuis [_rowsPerPage] / [_pageIndex]
  /// (clampés). Sans pagination : la tranche EST [_dataRows].
  ///
  /// Publie ensuite la nouvelle [visibleSliceRevision] : changer de page
  /// remplace le CONTENU rendu sans reconstruire le widget parent
  /// (`notifyDataSourceListeners` ne s'adresse qu'à la grille), or les
  /// dimensions dérivées de ce contenu — l'offset de swipe — doivent suivre.
  void _recomputeVisibleRows() {
    _assignVisibleRows();
    visibleSliceRevision.value++;
  }

  void _assignVisibleRows() {
    _maxActionCountCache = null;
    final perPage = _rowsPerPage;
    if (perPage == null || perPage <= 0) {
      _pageIndex = 0;
      _visibleRows = _dataRows;
      return;
    }
    final pages = pageCount;
    if (_pageIndex >= pages) _pageIndex = pages - 1;
    if (_pageIndex < 0) _pageIndex = 0;
    final start = _pageIndex * perPage;
    if (start >= _dataRows.length) {
      _visibleRows = const <DataGridRow>[];
      return;
    }
    final end = (start + perPage).clamp(0, _dataRows.length);
    _visibleRows = _dataRows.sublist(start, end);
  }

  /// Hook `DataPagerDelegate` : navigation vers [newPageIndex] (0-based).
  /// Recalcule la tranche et notifie la grille. **Ne lève jamais** (AD-10) :
  /// un index hors bornes est clampé par [_recomputeVisibleRows].
  @override
  Future<bool> handlePageChange(int oldPageIndex, int newPageIndex) async {
    _pageIndex = newPageIndex;
    _recomputeVisibleRows();
    // `notifyDataSourceListeners` (et NON `notifyListeners`) : c'est le hook
    // documenté par Syncfusion pour une **collection de lignes remplacée**
    // par la pagination — `notifyListeners` seul laisse la grille afficher
    // la page précédente (mesuré).
    notifyDataSourceListeners();
    return true;
  }

  /// Bascule le **passage à la ligne** des cellules de données (hauteur
  /// adaptative). Les cellules étant construites paresseusement par
  /// [buildRow], une simple notification suffit (aucune reconstruction des
  /// `DataGridRow`, identités préservées).
  void refreshWrapCellText(bool wrapCellText) {
    _wrapCellText = wrapCellText;
    notifyListeners();
  }

  /// Change la taille de page (mise à jour EN PLACE, source jamais recréée) et
  /// revient à la première page (la page courante n'a plus de sens à un autre
  /// découpage).
  void refreshRowsPerPage(int? rowsPerPage) {
    _rowsPerPage = rowsPerPage;
    _pageIndex = 0;
    _recomputeVisibleRows();
    notifyListeners();
  }

  /// **Met à jour en place** la source (jamais recréée) : reconstruit les
  /// `DataGridRow` puis notifie la grille. Préserve l'instance.
  ///
  /// [withOrderNumber] `null` conserve la valeur courante (appel interne depuis
  /// le constructeur) ; non-`null` la remplace (colonne d'ordre).
  void update(
    List<ZListColumn> columns,
    List<ZListRow> rows,
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor, {
    ZListOrdinal? ordinal,
  }) {
    _columns = columns;
    _actionsFor = actionsFor;
    if (ordinal != null) _ordinal = ordinal;
    _dataRows.clear();
    _rowByData.clear();
    _displayIndexByRow = <DataGridRow, int>{};
    for (final row in rows) {
      final data = DataGridRow(
        cells: <DataGridCell>[
          if (_ordinal.enabled)
            // Cellule TECHNIQUE, volontairement VIDE : le numéro d'ordre
            // n'est pas une donnée de la ligne. Le ranger ici le figerait à
            // l'ordre de construction, et un tri le ferait voyager avec sa
            // ligne. Il est calculé au moment de peindre, depuis la position
            // d'affichage (cf. [buildRow]).
            const DataGridCell<String>(
              columnName: _kOrderColumnName,
              value: '',
            ),
          for (final col in columns)
            DataGridCell<String>(
              columnName: col.name,
              value: col.format(row.cells[col.name]),
            ),
          if (_hasActions)
            const DataGridCell<String>(
              columnName: _kActionsColumnName,
              value: '',
            ),
        ],
      );
      _dataRows.add(data);
      _rowByData[data] = row;
    }
    _recomputeVisibleRows();
    notifyListeners();
  }

  /// Performance : met à jour SEULEMENT la closure de résolution d'actions,
  /// SANS reconstruire les `DataGridRow` ni notifier la grille. L'actions-cell
  /// est résolue paresseusement dans [buildRow] via [_actionsFor] : rafraîchir
  /// la référence suffit à ce que le prochain rendu naturel de ligne utilise la
  /// closure courante (contexte/ACL frais), sans effacer/reconstruire la source
  /// (préserve l'identité des lignes → aucun rebuild lourd sur un simple
  /// changement de sélection). PRÉCONDITION : la PRÉSENCE d'actions est
  /// inchangée (null ↔ non-null gérée par [update], car elle modifie le nombre
  /// de cellules par ligne).
  void refreshActions(
    List<ZResolvedRowAction> Function(ZListRow row)? actionsFor,
  ) {
    _actionsFor = actionsFor;
    // Le nombre d'actions par ligne peut avoir changé (ACL rafraîchie) :
    // l'offset de swipe dérivé doit être recalculé au prochain build.
    _maxActionCountCache = null;
  }

  /// Rafraîchit SEULEMENT la référence du résolveur de couleur de cellule
  /// (même discipline que [refreshActions]) : la couleur est résolue
  /// paresseusement dans [buildRow], aucune reconstruction requise (elle
  /// n'affecte ni le nombre ni l'identité des `DataGridRow`).
  void refreshCellColorBuilder(
    Color? Function(ZListRow row, ZListColumn column)? cellColorBuilder,
  ) {
    _cellColorBuilder = cellColorBuilder;
  }

  /// Rafraîchit SEULEMENT la référence du résolveur de STYLE conditionnel
  /// (même discipline que [refreshCellColorBuilder] : le style est résolu
  /// paresseusement dans [buildRow]).
  void refreshCellStyleBuilder(
    ZSfCellStyle? Function(ZListRow row, ZListColumn column)? cellStyleBuilder,
  ) {
    _cellStyleBuilder = cellStyleBuilder;
  }

  /// Rafraîchit SEULEMENT la référence du callback `loadMore` : appelé
  /// paresseusement par [handleLoadMoreRows], aucune reconstruction requise.
  void refreshOnLoadMore(Future<void> Function()? onLoadMore) {
    _onLoadMore = onLoadMore;
  }

  /// Override du hook Syncfusion invoqué par `LoadMoreRows` (le callback passé
  /// à `loadMoreViewBuilder`) : délègue à [_onLoadMore] s'il est fourni ; no-op
  /// sinon (défaut `DataGridSource.handleLoadMoreRows`, invariant AD-10 — hôte
  /// passif strictement immobile).
  @override
  Future<void> handleLoadMoreRows() async {
    await _onLoadMore?.call();
  }

  /// Séquence **réellement peinte**, dans l'ordre de l'écran.
  ///
  /// `DataGridSource.effectiveRows` est la collection que Syncfusion indexe
  /// pour peindre : c'est elle qu'il réordonne (en place) quand un tri est
  /// appliqué. La collection [rows] que cette source expose, elle, reste dans
  /// l'ordre d'origine (à la tranche de page près) — s'y fier ferait afficher
  /// des numéros mélangés dès le premier tri. Repli sur la tranche visible
  /// tant que la grille n'a pas encore pris connaissance de la source.
  List<DataGridRow> get _displayedRows =>
      effectiveRows.isEmpty ? _visibleRows : effectiveRows;

  // Position d'affichage mémoïsée par ligne. Un tri réordonne la collection
  // SANS prévenir la source : la validité de l'entrée est donc revérifiée à
  // chaque lecture (comparaison d'identité en O(1)), et la table entière n'est
  // reconstruite que lorsque l'ordre a effectivement bougé.
  Map<DataGridRow, int> _displayIndexByRow = <DataGridRow, int>{};

  /// Position **0-based à l'écran** de [row] (tri et page appliqués), ou `null`
  /// si la ligne n'est pas peinte.
  int? _displayPositionOf(DataGridRow row) {
    final displayed = _displayedRows;
    final cached = _displayIndexByRow[row];
    if (cached != null &&
        cached < displayed.length &&
        identical(displayed[cached], row)) {
      return cached;
    }
    _displayIndexByRow = <DataGridRow, int>{
      for (var i = 0; i < displayed.length; i++) displayed[i]: i,
    };
    return _displayIndexByRow[row];
  }

  /// Numéro d'ordre de [row] : la **règle du cœur** appliquée à la position
  /// d'affichage (`ZListOrdinal.textAt`), jamais une numérotation refaite ici.
  ///
  /// La page courante est **transmise** au cœur (`pageIndex`/`pageSize`), qui
  /// seul décide s'il l'utilise (`ZListOrdinal.continuousAcrossPages`). C'est
  /// ce que le pager interne rendait auparavant inatteignable : l'index de page
  /// vit ici, en privé, et l'hôte n'avait aucun moyen de le connaître pour
  /// déclarer lui-même un décalage. Sans pager (`_rowsPerPage == null`), la
  /// taille de page transmise est `0` — le décalage est nul quelle que soit la
  /// déclaration.
  String _ordinalTextOf(DataGridRow row) {
    final position = _displayPositionOf(row);
    if (position == null) return '';
    return _ordinal.textAt(
      position,
      pageIndex: _pageIndex,
      pageSize: _rowsPerPage ?? 0,
    );
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final source = _rowByData[row];
    final cells = <Widget>[
      if (_ordinal.enabled)
        Container(
          alignment: Alignment.center,
          child: Text(_ordinalTextOf(row)),
        ),
      for (final col in _columns) _dataCell(row, source, col),
      if (_hasActions) _actionsCell(row),
    ];
    return DataGridRowAdapter(cells: cells);
  }

  /// Cellule de DONNÉES : texte formaté + style **conditionnel** éventuel.
  ///
  /// Priorité, champ par champ : [_cellStyleBuilder] > [_cellColorBuilder]
  /// (fond uniquement, rétro-compat) > rendu par défaut. Un style `null` (ou
  /// un champ non déclaré) laisse EXACTEMENT le rendu historique.
  Widget _dataCell(DataGridRow row, ZListRow? source, ZListColumn col) {
    final style =
        source == null ? null : _cellStyleBuilder?.call(source, col);
    final legacyColor =
        source == null ? null : _cellColorBuilder?.call(source, col);
    final defaultPadding = _wrapCellText
        ? const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsetsDirectional.symmetric(horizontal: 12);
    final text = Text(
      _cellString(row, col.name),
      // Défaut : une seule ligne tronquée à l'ellipse (rendu historique).
      // Hauteur adaptative : le texte PASSE À LA LIGNE — sans quoi la hauteur
      // intrinsèque resterait celle d'une ligne.
      overflow: _wrapCellText ? TextOverflow.clip : TextOverflow.ellipsis,
      softWrap: _wrapCellText,
      textAlign: style?.textAlign ?? TextAlign.start,
      maxLines: style?.maxLines,
    );
    return Container(
      padding: style?.padding ?? defaultPadding,
      // Hauteur adaptative : le texte part du HAUT de la cellule (sinon une
      // ligne haute centrerait un paragraphe multi-lignes).
      alignment: style?.alignment ??
          (_wrapCellText
              ? AlignmentDirectional.topStart
              : AlignmentDirectional.centerStart),
      color: style?.backgroundColor ?? legacyColor,
      // `merge` (et non `style:` sur le Text) : un style partiel de
      // l'appelant (ex. `fontWeight` seul) CONSERVE la police et la couleur
      // héritées du thème (FR-26).
      child: style?.textStyle == null
          ? text
          : DefaultTextStyle.merge(style: style!.textStyle, child: text),
    );
  }

  Widget _actionsCell(DataGridRow row) {
    final source = _rowByData[row];
    final actions = source == null
        ? const <ZResolvedRowAction>[]
        : (_actionsFor?.call(source) ?? const <ZResolvedRowAction>[]);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        for (final action in actions) _ZSfRowActionButton(action: action),
      ],
    );
  }

  String _cellString(DataGridRow row, String columnName) {
    for (final cell in row.getCells()) {
      if (cell.columnName == columnName) return cell.value?.toString() ?? '';
    }
    return '';
  }
}

/// Bouton d'action accessible rendu dans la colonne d'actions de la grille.
class _ZSfRowActionButton extends StatelessWidget {
  const _ZSfRowActionButton({required this.action});

  final ZResolvedRowAction action;

  @override
  Widget build(BuildContext context) {
    final text = label(context, action.labelKey);
    final onPressed = action.enabled ? action.onInvoke : null;
    final Widget control = action.icon != null
        ? SizedBox(
            width: 48,
            height: 48,
            child: IconButton(
              icon: Icon(action.icon),
              tooltip: text,
              onPressed: onPressed,
            ),
          )
        : ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: TextButton(
              onPressed: onPressed,
              child: Text(text, textAlign: TextAlign.center),
            ),
          );
    return Semantics(
      button: true,
      enabled: action.enabled,
      label: text,
      container: true,
      child: control,
    );
  }
}
