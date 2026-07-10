/// `ZTabbedList` — **onglets de catégorisation** de listes du cœur `zcrud_core`
/// (E4-5, étend FR-6 · AD-8/AD-13/AD-2/AD-15/SM-5).
///
/// origine: capacité « **onglets** » du §4.2 du PRD (rattachée à FR-6). Un chrome
/// `TabBar`/`TabBarView` **pur-Flutter Material** où **chaque onglet est une
/// [DynamicList]/`ZListController` indépendante** (typiquement catégorisée par un
/// filtre via `baseFilters`). L'**état de chaque onglet est PRÉSERVÉ** au
/// changement d'onglet (recherche / tri / pagination / **sélection** / scroll) :
/// chaque page est enveloppée dans un `_KeepAliveTabPage`
/// (`AutomaticKeepAliveClientMixin`, `wantKeepAlive => true`) → son sous-arbre
/// (et le `State` portant ses contrôleurs) est monté **une fois** et **conservé**
/// — les contrôleurs ne sont ni recréés ni disposés au switch (équivalent
/// « liste » du principe AD-2 : état stable, pas recréé au rebuild).
///
/// **Sélection INDÉPENDANTE par onglet** : chaque onglet possède sa **propre**
/// `ZListSelectionController` (créée dans son `builder`) — sélectionner dans un
/// onglet n'affecte jamais les autres (AC6/AC8).
///
/// **SM-5** : le chrome des onglets est **pur-Flutter Material** (`TabBar`/
/// `TabBarView`, déjà dans `flutter/material.dart`) ; les listes ne rendent
/// Syncfusion QUE si l'app a injecté `ZSfDataGridRenderer` via `ZcrudScope`
/// (sinon layout `builder`/`custom` neutre). Ce fichier n'importe JAMAIS
/// `zcrud_list`/Syncfusion.
///
/// **Neutre (AD-2/AD-15)** : imports limités à `package:flutter/material.dart` +
/// types `zcrud_core`. AUCUN gestionnaire d'état.
library;

import 'package:flutter/material.dart';

import '../l10n/z_localizations.dart';
import 'z_list_tab.dart';

/// Onglets de catégorisation : `TabBar` (N onglets) + `TabBarView` (une liste
/// indépendante par onglet, état préservé au switch).
class ZTabbedList extends StatefulWidget {
  /// Construit les onglets à partir de [tabs]. [initialIndex] fixe l'onglet actif
  /// initial ; [onTabChanged] est notifié à chaque changement d'onglet ;
  /// [isScrollable] rend la barre défilante (nombreux onglets).
  const ZTabbedList({
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
    this.isScrollable = false,
    super.key,
  });

  /// Descripteurs d'onglets (libellé l10n + icône + builder de vue).
  final List<ZListTab> tabs;

  /// Index de l'onglet actif initial.
  final int initialIndex;

  /// Notifié à chaque changement d'onglet (nouvel index).
  final ValueChanged<int>? onTabChanged;

  /// Barre d'onglets défilante (défaut `false`).
  final bool isScrollable;

  @override
  State<ZTabbedList> createState() => _ZTabbedListState();
}

class _ZTabbedListState extends State<ZTabbedList>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // LOW-2 (code-review E4-5) : les `labelKey` servent de clés de page
    // (`ValueKey('zTab_<labelKey>')`) — un doublon provoquerait une collision de
    // clés dans le `TabBarView`. On l'attrape tôt avec un message actionnable.
    assert(
      widget.tabs.map((t) => t.labelKey).toSet().length == widget.tabs.length,
      'ZTabbedList : les `labelKey` des onglets doivent être uniques '
      '(clés de page dérivées). Doublon détecté dans '
      '${widget.tabs.map((t) => t.labelKey).toList()}.',
    );
    _tabController = _createController();
  }

  TabController _createController() {
    final controller = TabController(
      length: widget.tabs.length,
      initialIndex: widget.initialIndex.clamp(
        0,
        widget.tabs.isEmpty ? 0 : widget.tabs.length - 1,
      ),
      vsync: this,
    );
    controller.addListener(_handleTabChange);
    return controller;
  }

  void _handleTabChange() {
    // Notifie une seule fois par sélection (ignore les frames intermédiaires de
    // l'animation d'indicateur).
    if (_tabController.indexIsChanging) return;
    widget.onTabChanged?.call(_tabController.index);
  }

  @override
  void didUpdateWidget(covariant ZTabbedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le nombre d'onglets change ⇒ recycle le `TabController` (longueur figée).
    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabController
        ..removeListener(_handleTabChange)
        ..dispose();
      _tabController = _createController();
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TabBar(
          controller: _tabController,
          isScrollable: widget.isScrollable,
          tabs: <Widget>[
            for (final tab in widget.tabs)
              Tab(
                // Cible tactile ≥ 48 dp (AD-13).
                height: 48,
                icon: tab.icon == null ? null : Icon(tab.icon),
                child: Text(
                  label(context, tab.labelKey),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              for (final tab in widget.tabs)
                _KeepAliveTabPage(
                  // Clé stable par onglet : préserve le `State` (donc les
                  // contrôleurs) à travers les rebuilds du parent.
                  key: ValueKey<String>('zTab_${tab.labelKey}'),
                  builder: tab.builder,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Page d'onglet **keep-alive** : monte `builder` **une fois** et conserve son
/// sous-arbre (donc les `ZListController`/`ZListSelectionController` créés dans
/// le `builder`) au changement d'onglet (`AutomaticKeepAliveClientMixin`,
/// `wantKeepAlive => true`). Sans quoi `TabBarView` détruirait les pages hors
/// écran (perte de la recherche/tri/pagination/sélection/scroll) — AC5/AC6.
class _KeepAliveTabPage extends StatefulWidget {
  const _KeepAliveTabPage({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<_KeepAliveTabPage> createState() => _KeepAliveTabPageState();
}

class _KeepAliveTabPageState extends State<_KeepAliveTabPage>
    with AutomaticKeepAliveClientMixin<_KeepAliveTabPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // requis par AutomaticKeepAliveClientMixin.
    return widget.builder(context);
  }
}
