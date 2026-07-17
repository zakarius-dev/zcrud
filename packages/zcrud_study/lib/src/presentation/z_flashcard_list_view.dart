/// `ZFlashcardListView` — liste de flashcards : recherche, filtres, tris, ordre
/// manuel, duplication (SU-8, FR-SU14/FR-SU21 — AC1/AC3/AC8/AC14-AC18/AC20/AC21).
///
/// ## Pourquoi ce widget vit dans `zcrud_study` (et pas `zcrud_flashcard`)
///
/// Il a besoin de `zReorderFlashcards`/`zReorderIds` (ordre manuel), qui vivent
/// ici. Or `zcrud_study → zcrud_flashcard` : l'héberger dans `zcrud_flashcard`
/// exigerait l'arête inverse ⇒ **CYCLE**, violation AD-1. Et dupliquer
/// `zReorderIds` serait la « seconde voie » qu'AD-38 interdit.
///
/// ## SM-1 (objectif produit n°1) — taper ne reconstruit QUE le champ
///
/// La liste peut porter des **milliers** de cartes. Deux mécanismes, tous deux
/// nécessaires :
/// 1. **Débounce local** ([_kSearchDebounce]) — patron su-3
///    (`z_flashcard_answer_input.dart`, `Timer` local **disposé** au démontage).
///    Aucune primitive de débounce générique n'existe dans le repo
///    (`grep -rn "class ZDebounc\|zDebounce"` ⇒ **RC=1**) : en inventer une
///    abstraction transverse ici serait hors périmètre ;
/// 2. **`ValueListenable` ciblée** — seul le sous-arbre de la liste écoute
///    [_query] ; le `TextField` n'est **jamais** reconstruit par la frappe (il
///    possède son propre `TextEditingController`, **stable**), donc le **focus
///    est conservé** et le curseur ne saute pas.
///
/// Prouvé par **compteur** (`z_flashcard_list_view_sm1_test.dart`), jamais par
/// opinion : 100 caractères ⇒ rebuilds de liste **bornés**, focus intact.
///
/// ## Ce que ce widget ne fait PAS
///
/// - **Aucune sélection multiple** (FR-SU19 = **me-3**) : su-8 est complète sans
///   elle et ne **précâble rien** — aucun `selectionController`, aucun paramètre
///   « en prévision de », aucun champ mort (AC17, prouvé par grep négatif) ;
/// - **Aucun flux de génération IA** (**su-9**) : l'option est **ABSENTE** sans
///   port, par **composition** ([ZFeatureAvailability.gate] fabrique le `null`
///   que `ZItemAction.onSelected` consomme déjà) — jamais un `if (kEnableAi)` ni
///   un booléen local (AC16) ;
/// - **Aucun rendu riche en dur** : le contenu passe par le slot AD-40, dont le
///   défaut est du **texte brut thématisé** (AC3).
///
/// Invariants (AD-2/AD-13/AD-15) : aucun gestionnaire d'état ; aucun `setState`
/// de liste ; controllers **stables** ; labels/icônes **INJECTÉS** ; thème via
/// `ZcrudTheme.of` (repli `Theme.of`) ; cibles ≥ 48 dp ; `Semantics` explicites ;
/// API **directionnelles** uniquement.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZFolderContentsOrder, ZStudySessionSelector;

import 'z_feature_availability.dart';
import 'z_flashcard_reorder.dart';
import 'z_item_actions_menu.dart';

/// Délai de débounce de la recherche (SM-1).
///
/// 300 ms : au-dessus du rythme de frappe soutenu (~150 ms/caractère), donc une
/// rafale de 100 caractères ne déclenche **qu'un** recalcul ; sous le seuil de
/// perception d'attente (~400 ms), donc la liste reste réactive.
const Duration _kSearchDebounce = Duration(milliseconds: 300);

/// Cible tap minimale (AD-13/NFR-S6) — patron `z_item_actions_menu.dart`.
const double _kMinTapTarget = 48.0;

/// Largeur minimale d'une tuile (dp) : pilote le nombre de colonnes.
///
/// Remplace le ternaire `300/350` codé en dur d'IFFD — la décision revient à
/// `computeCrossAxisCount`, sur la largeur **LOCALE**.
const double _kMinTileWidth = 300.0;

/// Hauteur cible d'une tuile en grille (dp).
const double _kTileHeight = 180.0;

/// `featureKey` OPAQUE de la génération IA (AC16).
///
/// L'app décide de sa disponibilité via [ZFeatureAvailability] — su-8 ne livre
/// **aucun** flux de génération (**su-9**). La clé est une `String` opaque
/// (AD-4), jamais un enum fermé.
const String kFlashcardAiGenerationFeature = 'flashcard.ai.generation';

/// Libellés **INJECTÉS** de la liste (i18n — AD-13/FR-23).
///
/// **Aucun défaut codé en dur** : tous les champs sont `required`. Un défaut
/// français masquerait une localisation manquante — le libellé apparaîtrait,
/// simplement dans la mauvaise langue, sans qu'aucun test ne rougisse.
@immutable
class ZFlashcardListLabels {
  /// Construit les libellés de la liste (tous **requis** — jamais de défaut).
  const ZFlashcardListLabels({
    required this.searchHint,
    required this.searchFieldLabel,
    required this.emptyState,
    required this.noResults,
    required this.actionsMenuTooltip,
    required this.openAction,
    required this.editAction,
    required this.deleteAction,
    required this.duplicateAction,
    required this.moveUpAction,
    required this.moveDownAction,
    required this.generateWithAiAction,
    required this.readOnlyBadge,
  });

  /// Indication du champ de recherche.
  final String searchHint;

  /// Label a11y du champ de recherche (lecteur d'écran).
  final String searchFieldLabel;

  /// Message quand le dossier est **vide** (aucune carte).
  final String emptyState;

  /// Message quand la **recherche/les filtres** ne retiennent rien.
  ///
  /// **Distinct** de [emptyState] : « aucune carte » et « aucun résultat » sont
  /// deux situations différentes, avec deux actions différentes pour
  /// l'utilisateur (créer une carte / élargir sa recherche).
  final String noResults;

  /// Tooltip du déclencheur du menu d'actions.
  final String actionsMenuTooltip;

  /// Libellé de l'action « ouvrir ».
  final String openAction;

  /// Libellé de l'action « modifier ».
  final String editAction;

  /// Libellé de l'action « supprimer ».
  final String deleteAction;

  /// Libellé de l'action « dupliquer » (FR-SU21).
  final String duplicateAction;

  /// Libellé de l'action a11y « monter ».
  final String moveUpAction;

  /// Libellé de l'action a11y « descendre ».
  final String moveDownAction;

  /// Libellé de l'action « générer avec l'IA » (**absente** sans port — AC16).
  final String generateWithAiAction;

  /// Badge d'une carte en **lecture seule** (AD-45).
  final String readOnlyBadge;
}

/// Rend le **contenu** d'une carte dans une tuile — slot AD-40 (AC3).
///
/// `null` ⇒ **texte brut thématisé** (le défaut). L'app injecte son moteur riche
/// (Markdown/LaTeX) sans que `zcrud_study` ne connaisse Quill.
typedef ZFlashcardTileContentBuilder = Widget Function(
  BuildContext context,
  String text,
);

/// Liste de flashcards : recherche, filtres, tris, ordre manuel, duplication.
class ZFlashcardListView extends StatefulWidget {
  /// Construit la liste.
  ///
  /// - [cards] : cartes du dossier (**non filtrées**) ;
  /// - [labels] : libellés **INJECTÉS** (i18n) ;
  /// - [selector] : filtres dossier ∧ tags ∧ types — **délégués** au kernel ;
  /// - [filters] : recherche + `kind` de source (su-8 n'ajoute que ça) ;
  /// - [sortMode] : tri — [ZFlashcardSortMode.manual] ⇒ l'ordre personnel de
  ///   [order] s'applique (AD-38) ;
  /// - [order] : ordre personnel du dossier (`null` ⇒ aucun) ;
  /// - [onOrderChanged] : **notification sortante** de l'ordre réordonné. `null`
  ///   ⇒ réordonnancement **ABSENT** (ni drag, ni boutons) — la liste ne persiste
  ///   **jamais** elle-même (AD-2 : elle ne possède pas les données) ;
  /// - [onOpen]/[onEdit]/[onDelete]/[onDuplicate] : actions par item. `null` ⇒
  ///   action **ABSENTE** du menu (AD-44) — jamais grisée ;
  /// - [aiAvailability] : disponibilité de la génération IA. `null` ⇒ lue sur le
  ///   [ZFeatureAvailabilityScope] ambiant (repli **fail-open**). L'option reste
  ///   **ABSENTE** tant qu'[onGenerateWithAi] n'est pas fourni (AC16) ;
  /// - [tagLabels] : résolution `tagId → libellé` (recherche + affichage) ;
  /// - [typeLabels]/[sourceLabels] : résolution `clé → libellé` du **badge de
  ///   type** et de la **source** (mêmes patron/repli que [tagLabels]) ;
  /// - [contentBuilder] : slot AD-40 (`null` ⇒ texte brut thématisé).
  const ZFlashcardListView({
    required this.cards,
    required this.labels,
    this.selector = const ZStudySessionSelector(ZStudySessionConfig()),
    this.filters = const ZFlashcardBrowseFilters(),
    this.sortMode = ZFlashcardSortMode.dateDesc,
    this.order,
    this.subfolderId,
    this.onOrderChanged,
    this.onOpen,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
    this.onGenerateWithAi,
    this.aiAvailability,
    this.tagLabels,
    this.typeLabels,
    this.sourceLabels,
    this.contentBuilder,
    this.searchDebounce = _kSearchDebounce,
    super.key,
  });

  /// Cartes du dossier — **non filtrées** (la vue applique filtres et tri).
  final List<ZFlashcard> cards;

  /// Libellés **INJECTÉS** (jamais codés en dur).
  final ZFlashcardListLabels labels;

  /// Filtres dossier ∧ tags ∧ types — **DÉLÉGUÉS** à `matches` (jamais
  /// `selectFrom`, dont le plafond `count` tronquerait la liste).
  final ZStudySessionSelector selector;

  /// Recherche + `kind` de source. La **requête texte** de la vue (débouncée)
  /// **prime** sur [ZFlashcardBrowseFilters.query] dès que l'utilisateur tape.
  final ZFlashcardBrowseFilters filters;

  /// Mode de tri (AC8).
  final ZFlashcardSortMode sortMode;

  /// Ordre personnel du dossier (AD-38) — `null` ⇒ aucun ordre manuel.
  final ZFolderContentsOrder? order;

  /// Sous-dossier de la section (`null` ⇒ section racine).
  final String? subfolderId;

  /// Notification sortante de l'ordre réordonné (AD-2 : la vue ne persiste pas).
  ///
  /// `null` ⇒ drag **et** boutons a11y **ABSENTS** (une réorganisation que rien
  /// ne persisterait serait perdue au prochain rebuild — une fonctionnalité
  /// morte, pire qu'absente).
  final ValueChanged<ZFolderContentsOrder>? onOrderChanged;

  /// Ouvrir une carte — `null` ⇒ action absente.
  final ValueChanged<ZFlashcard>? onOpen;

  /// Modifier une carte — `null` ⇒ absente. **Jamais** proposée sur une carte
  /// `isReadOnly` (AD-45).
  final ValueChanged<ZFlashcard>? onEdit;

  /// Supprimer une carte — `null` ⇒ absente. **Jamais** sur `isReadOnly`.
  final ValueChanged<ZFlashcard>? onDelete;

  /// Dupliquer une carte (FR-SU21) — reçoit la **copie éphémère** produite par
  /// `zDuplicateFlashcardForEditing` (`id: null`). `null` ⇒ action absente.
  final ValueChanged<ZFlashcard>? onDuplicate;

  /// Générer avec l'IA — `null` ⇒ **ABSENTE** (AC16). su-8 ne livre aucun flux.
  final VoidCallback? onGenerateWithAi;

  /// Disponibilité de la fonctionnalité IA (`null` ⇒ scope ambiant, fail-open).
  final ZFeatureAvailability? aiAvailability;

  /// Résolution `tagId → libellé` (recherche + affichage).
  final Map<String, String>? tagLabels;

  /// Résolution `type.name → libellé` du badge de type (D2/AC20). `null` ou clé
  /// absente ⇒ **repli sur la clé opaque** (patron [tagLabels]) : la vue ne
  /// traduit **jamais** en dur, mais l'app **peut** injecter un libellé localisé.
  final Map<String, String>? typeLabels;

  /// Résolution `source.kind → libellé` (D2/AC20). Même patron/repli que
  /// [typeLabels] : `null` ⇒ la clé brute (`'pdf'`, `'book'`…) est affichée.
  final Map<String, String>? sourceLabels;

  /// Slot de rendu de contenu **opt-in** (AD-40) — `null` ⇒ texte brut thématisé.
  final ZFlashcardTileContentBuilder? contentBuilder;

  /// Délai de débounce de la recherche (injectable pour les tests).
  final Duration searchDebounce;

  /// Clé du champ de recherche (testabilité).
  static const ValueKey<String> searchFieldKey =
      ValueKey<String>('zFlashcardListView_search');

  /// Clé de la grille (testabilité).
  static const ValueKey<String> gridKey =
      ValueKey<String>('zFlashcardListView_grid');

  /// Clé de la liste réordonnable (mode manuel).
  static const ValueKey<String> reorderableKey =
      ValueKey<String>('zFlashcardListView_reorderable');

  /// Clé de l'état vide / sans résultat.
  static const ValueKey<String> emptyStateKey =
      ValueKey<String>('zFlashcardListView_empty');

  @override
  State<ZFlashcardListView> createState() => _ZFlashcardListViewState();
}

class _ZFlashcardListViewState extends State<ZFlashcardListView> {
  /// Controller du champ de recherche — **STABLE**, créé une fois, disposé.
  ///
  /// 🔴 SM-1 : le recréer à chaque build **perdrait le focus et la sélection** à
  /// chaque frappe. C'est le bug historique n°1 que zcrud corrige par conception.
  late final TextEditingController _searchController;

  /// Requête **débouncée** — `ValueListenable` : SEUL le sous-arbre de la liste
  /// l'écoute. Le `TextField` n'en dépend pas ⇒ taper ne le reconstruit pas.
  late final ValueNotifier<String> _query;

  /// Timer de débounce — **local** (patron su-3), `cancel()` au dispose.
  ///
  /// Sans ce `cancel()`, un timer survivant appellerait `_query.value` sur un
  /// arbre démonté (fuite réelle, pas théorique).
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.filters.query);
    _query = ValueNotifier<String>(widget.filters.query);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant ZFlashcardListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🔴 D5 — `filters.query` est une prop VIVANTE, au même titre que
    // `searchFields`/`sources` (déjà relus à chaque build via _effectiveFilters).
    // Un parent qui pousse une nouvelle requête (deep-link, filtre restauré,
    // puce de tag) doit la voir appliquée — sans quoi le champ afficherait un
    // filtre à moitié appliqué, en silence.
    //
    // On ne resynchronise QUE sur changement RÉEL de la prop (jamais à chaque
    // build), et seulement si le champ ne la reflète pas déjà : c'est ce qui
    // empêche d'écraser la saisie EN COURS de l'utilisateur (AD-2 interdit la
    // ré-injection qui casse focus/sélection).
    if (widget.filters.query != oldWidget.filters.query &&
        widget.filters.query != _searchController.text) {
      _searchController.text = widget.filters.query;
      _query.value = widget.filters.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _query.dispose();
    super.dispose();
  }

  /// Débounce la frappe (SM-1) : la liste ne se recalcule qu'au repos.
  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDebounce, () {
      if (!mounted) return;
      // Ne notifie QUE si la valeur change réellement : deux frappes qui
      // s'annulent (« a » puis retour arrière) ne doivent pas reconstruire.
      _query.value = _searchController.text;
    });
  }

  /// Filtres effectifs = ceux de l'appelant + la requête **débouncée** de la vue.
  ZFlashcardBrowseFilters _effectiveFilters(String query) =>
      ZFlashcardBrowseFilters(
        query: query,
        searchFields: widget.filters.searchFields,
        sources: widget.filters.sources,
      );

  /// Cartes **visibles** : filtres (délégués) → tri → ordre manuel (AD-38).
  ///
  /// L'ordre des trois étapes est **significatif** : filtrer d'abord (moins de
  /// cartes à trier), puis trier, puis appliquer l'ordre personnel — qui, en
  /// mode manuel, **prime** sur le tri (c'est sa définition).
  List<ZFlashcard> _visibleCards(String query) {
    final filtered = zApplyBrowseFilters(
      widget.cards,
      selector: widget.selector,
      filters: _effectiveFilters(query),
      tagLabels: widget.tagLabels,
    );

    final sorted = zSortFlashcards(filtered, widget.sortMode);

    // AD-38 : l'ordre manuel vient EXCLUSIVEMENT de ZFolderContentsOrder +
    // applyOrder (kernel) — jamais d'un champ `position` inline.
    final order = widget.order;
    if (widget.sortMode != ZFlashcardSortMode.manual || order == null) {
      return sorted;
    }
    return order.applyTo<ZFlashcard>(
      zFlashcardsSectionKey(subfolderId: widget.subfolderId),
      sorted,
      idOf: (card) => card.id ?? '',
    );
  }

  /// `true` si le réordonnancement est possible **en principe** (AC11).
  ///
  /// Exige le mode **manuel** ET un `onOrderChanged` : réordonner sans persister
  /// serait une fonctionnalité morte (l'ordre sauterait au prochain rebuild).
  ///
  /// ⚠️ Condition **nécessaire mais non suffisante** : sous un filtre de contenu
  /// actif, le réordonnancement est en plus **désactivé** (cf.
  /// [_contentFilterActive] / décision D1). L'état runtime réel est calculé dans
  /// [_buildList].
  bool get _canReorder =>
      widget.sortMode == ZFlashcardSortMode.manual &&
      widget.onOrderChanged != null;

  /// `true` si un filtre **DE CONTENU** masque potentiellement des cartes de la
  /// **même** section (🔴 D1 — HIGH, RISQUE DE DONNÉES).
  ///
  /// `zReorderFlashcards` **REMPLACE** l'entrée de section par les seuls
  /// `visibleIds` : sous un tel filtre, l'ordre persisté des cartes masquées
  /// serait **effacé en silence** (`applyOrder` est TOTAL ⇒ aucune exception,
  /// aucun test rouge). On INTERDIT donc le drag ET les boutons dans ce cas
  /// (absents, jamais grisés — AD-44), la voie la plus conservatrice : une vue
  /// partielle n'a de toute façon pas de sémantique de réordonnancement claire.
  ///
  /// Sont des filtres de contenu : la **recherche** (débouncée), le **`kind` de
  /// source**, les **tags** et les **types** du sélecteur. Le **sous-dossier**
  /// n'en est **pas** un : il **scope la clé de section** (`flashcards/<sub>`),
  /// donc réordonner un sous-dossier n'écrase jamais l'ordre d'un autre — c'est
  /// sûr **par construction**, et reste autorisé.
  bool _contentFilterActive(String query) =>
      query.trim().isNotEmpty ||
      widget.filters.sources.isNotEmpty ||
      (widget.selector.config.tagIds?.isNotEmpty ?? false) ||
      (widget.selector.config.types?.isNotEmpty ?? false);

  /// **UNIQUE** point d'appel du réordonnancement de la vue (AC11).
  ///
  /// Drag **ET** boutons a11y passent par ici, puis par `zReorderFlashcards` —
  /// jamais deux voies.
  void _reorder(List<ZFlashcard> visible, int oldIndex, int newIndex) {
    final notify = widget.onOrderChanged;
    if (notify == null) return;

    final next = zReorderFlashcards(
      widget.order ?? const ZFolderContentsOrder(),
      visibleIds: <String>[
        for (final card in visible)
          if (card.id != null) card.id!,
      ],
      oldIndex: oldIndex,
      newIndex: newIndex,
      subfolderId: widget.subfolderId,
    );
    notify(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SearchField(
          controller: _searchController,
          labels: widget.labels,
        ),
        SizedBox(height: theme.gapM),
        // 🔴 SM-1 : SEUL ce sous-arbre écoute la requête. Le champ ci-dessus est
        // HORS du builder ⇒ taper ne le reconstruit pas, le focus est conservé.
        Expanded(
          child: ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) => _buildList(context, query),
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, String query) {
    final visible = _visibleCards(query);

    if (visible.isEmpty) {
      // Deux messages DISTINCTS : « aucune carte » ≠ « aucun résultat ».
      // Un dossier NON vide dont rien n'est visible ⇒ « aucun résultat » ;
      // un dossier réellement vide ⇒ « aucune carte ».
      return _EmptyState(
        key: ZFlashcardListView.emptyStateKey,
        message: widget.cards.isNotEmpty
            ? widget.labels.noResults
            : widget.labels.emptyState,
      );
    }

    // 🔴 D1 (HIGH) — le réordonnancement n'est proposé que si AUCUN filtre de
    // contenu ne masque de carte de la même section (sinon `zReorderFlashcards`
    // écraserait l'ordre persisté des cartes masquées). Le sous-dossier scope la
    // clé ⇒ il ne compte PAS comme filtre de contenu (cf. [_contentFilterActive]).
    //
    // 🔴 R3 — une carte ÉPHÉMÈRE (`id == null`, ex. une duplication non encore
    // persistée) fait DIVERGER l'espace d'indices de la liste affichée (`visible`,
    // qui la contient) de celui des `visibleIds` persistables (`_reorder`/
    // `zReorderFlashcards` écartent les cartes sans id) : un drag déplacerait
    // SILENCIEUSEMENT la MAUVAISE carte (mesuré : drag de l'éphémère ⇒ une autre
    // carte bouge). On DÉSACTIVE donc le réordonnancement (drag ET boutons) dès
    // qu'une telle carte est visible — ABSENT, jamais cassé (patron D1/AD-44).
    // En su-8 la duplication sort par `onDuplicate` et n'entre jamais dans
    // `cards` (persistance = me-2) : ce garde est un filet défensif (AD-10/AD-2).
    final reorderable = _canReorder &&
        !_contentFilterActive(query) &&
        !visible.any((card) => card.id == null);

    if (reorderable) {
      return _ReorderableList(
        visible: visible,
        onReorder: (oldIndex, newIndex) =>
            _reorder(visible, oldIndex, newIndex),
        tileBuilder: (context, card, index) =>
            _buildTile(context, card, visible, index,
                grid: false, reorderable: true),
      );
    }

    // 🔴 AC1/NFR-SU9 — grille responsive VIRTUALISÉE : `ZAdaptiveGrid.builder`
    // (jamais `children:`, qui matérialiserait des MILLIERS de widgets à chaque
    // frappe ; jamais une grille réécrite).
    return ZAdaptiveGrid.builder(
      key: ZFlashcardListView.gridKey,
      itemCount: visible.length,
      minItemWidth: _kMinTileWidth,
      itemHeight: _kTileHeight,
      itemBuilder: (context, i) =>
          _buildTile(context, visible[i], visible, i,
              grid: true, reorderable: false),
    );
  }

  Widget _buildTile(
    BuildContext context,
    ZFlashcard card,
    List<ZFlashcard> visible,
    int index, {
    required bool grid,
    required bool reorderable,
  }) {
    return _FlashcardTile(
      // ValueKey stable par carte (AD-2) : l'identité d'une tuile suit sa carte,
      // jamais sa position — sinon un réordonnancement recyclerait les états.
      key: ValueKey<String>('tile-${card.id ?? 'ephemeral-$index'}'),
      card: card,
      labels: widget.labels,
      tagLabels: widget.tagLabels,
      typeLabels: widget.typeLabels,
      sourceLabels: widget.sourceLabels,
      contentBuilder: widget.contentBuilder,
      showAnswerPreview: grid,
      actions: _actionsFor(card, visible, reorderable: reorderable),
    );
  }

  /// Actions d'un item — **déclarées** (AD-44) : `onSelected == null ⇒ ABSENTE`.
  List<ZItemAction> _actionsFor(
    ZFlashcard card,
    List<ZFlashcard> visible, {
    required bool reorderable,
  }) {
    final labels = widget.labels;
    final availability = widget.aiAvailability ??
        ZFeatureAvailabilityScope.of(context);

    final onOpen = widget.onOpen;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;
    final onDuplicate = widget.onDuplicate;

    // 🔴 AD-45 — une carte en lecture seule n'est NI éditable NI supprimable.
    // L'absence est obtenue par `null` (le mécanisme existant), jamais par un
    // item grisé : `ZItemActionsMenu` FILTRE déjà les `onSelected == null`.
    final editable = !card.isReadOnly;

    return <ZItemAction>[
      ZItemAction(
        kind: ZItemActionKind.open,
        label: labels.openAction,
        icon: Icons.open_in_new,
        onSelected: onOpen == null ? null : () => onOpen(card),
      ),
      ZItemAction(
        kind: ZItemActionKind.rename,
        label: labels.editAction,
        icon: Icons.edit,
        onSelected:
            (!editable || onEdit == null) ? null : () => onEdit(card),
      ),
      // FR-SU21 — « dupliquer pour modifier » : disponible MÊME (et surtout) sur
      // une carte en lecture seule. C'est sa raison d'être.
      ZItemAction(
        kind: ZItemActionKind.duplicate,
        label: labels.duplicateAction,
        icon: Icons.copy,
        onSelected: onDuplicate == null
            ? null
            : () => onDuplicate(zDuplicateFlashcardForEditing(card)),
      ),
      // 🔴 AC11 — boutons a11y : MÊME voie que le drag (`_reorder`).
      // `null` ⇒ ABSENT : le 1er ne remonte pas, le dernier ne descend pas.
      ZItemAction(
        kind: ZItemActionKind.custom,
        label: labels.moveUpAction,
        icon: Icons.arrow_upward,
        onSelected: _moveCallback(card, visible, reorderable: reorderable, up: true),
      ),
      ZItemAction(
        kind: ZItemActionKind.custom,
        label: labels.moveDownAction,
        icon: Icons.arrow_downward,
        onSelected:
            _moveCallback(card, visible, reorderable: reorderable, up: false),
      ),
      // 🔴 AC16 — « Générer avec l'IA » : ABSENTE sans port, par COMPOSITION.
      // `gate` fabrique le `null` que `onSelected` consomme DÉJÀ — jamais un
      // `if (kEnableAi)`, jamais un booléen local.
      ZItemAction(
        kind: ZItemActionKind.custom,
        label: labels.generateWithAiAction,
        icon: Icons.auto_awesome,
        onSelected: availability.gate(
          kFlashcardAiGenerationFeature,
          widget.onGenerateWithAi,
        ),
      ),
      ZItemAction(
        kind: ZItemActionKind.delete,
        label: labels.deleteAction,
        icon: Icons.delete,
        onSelected:
            (!editable || onDelete == null) ? null : () => onDelete(card),
      ),
    ];
  }

  /// Callback d'un bouton Monter/Descendre, ou `null` si **impossible** (AC11).
  ///
  /// `reorderable == false` (mode non manuel, pas de `onOrderChanged`, **ou
  /// filtre de contenu actif — D1**) ⇒ `null` : bouton ABSENT, jamais grisé.
  VoidCallback? _moveCallback(
    ZFlashcard card,
    List<ZFlashcard> visible, {
    required bool reorderable,
    required bool up,
  }) {
    if (!reorderable) return null;
    final id = card.id;
    if (id == null) return null;

    final ids = <String>[
      for (final c in visible)
        if (c.id != null) c.id!,
    ];
    final indices =
        up ? zMoveUpIndices(ids, id) : zMoveDownIndices(ids, id);
    if (indices == null) return null;

    // MÊME voie que le drag : `_reorder` → `zReorderFlashcards`.
    return () => _reorder(visible, indices.oldIndex, indices.newIndex);
  }
}

/// Champ de recherche — **hors** du `ValueListenableBuilder` de la liste (SM-1).
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.labels});

  final TextEditingController controller;
  final ZFlashcardListLabels labels;

  @override
  Widget build(BuildContext context) {
    // 🔴 D3 — le libellé a11y est porté par `InputDecoration(labelText:)` : le
    // SDK l'attache alors au **nœud sémantique DU champ** (focusable, actionnable).
    // Un `Semantics(label:)` PARENT ne fusionnerait PAS dans le `TextField` (qui
    // est sa propre frontière sémantique) : il créerait un nœud `isTextField`
    // FANTÔME (non focusable, sans action) et le vrai champ n'annoncerait que le
    // hint. `labelText` est aussi la seule voie qui NE détruit pas les actions du
    // champ (contrairement à `excludeSemantics: true`, juste pour un menu mais
    // fatal ici).
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: TextField(
        key: ZFlashcardListView.searchFieldKey,
        controller: controller,
        textAlign: TextAlign.start,
        decoration: InputDecoration(
          labelText: labels.searchFieldLabel,
          hintText: labels.searchHint,
          prefixIcon: const Icon(Icons.search),
        ),
      ),
    );
  }
}

/// État vide / sans résultat.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final color = theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(theme.gapL),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: color),
        ),
      ),
    );
  }
}

/// Liste réordonnable (mode manuel) — patron `z_sectioned_study_layout.dart`.
class _ReorderableList extends StatelessWidget {
  const _ReorderableList({
    required this.visible,
    required this.onReorder,
    required this.tileBuilder,
  });

  final List<ZFlashcard> visible;
  final void Function(int oldIndex, int newIndex) onReorder;
  final Widget Function(BuildContext, ZFlashcard, int) tileBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // `ReorderableListView.builder` : VIRTUALISÉ (jamais `children:`).
    return ReorderableListView.builder(
      key: ZFlashcardListView.reorderableKey,
      itemCount: visible.length,
      // `EdgeInsets.all` (symétrique) : le paramètre du SDK est typé
      // `EdgeInsets?`, pas `EdgeInsetsGeometry?`. Une marge SYMÉTRIQUE est
      // RTL-neutre par construction — aucun `left:`/`right:` n'est écrit, la
      // règle AD-13 est donc tenue (ce n'est pas une exception, c'est un cas où
      // la question ne se pose pas).
      padding: EdgeInsets.all(theme.gapS),
      // 🔴 `onReorderItem` (SDK ≥ v3.41 — `onReorder` est DÉPRÉCIÉ) : il fournit
      // un `newIndex` DÉJÀ ajusté pour le retrait de l'item à `oldIndex`, ce qui
      // correspond EXACTEMENT à la convention `removeAt` puis `insert` de
      // `zReorderIds` (aucun `-1` manuel à appliquer). Patron
      // `z_sectioned_study_layout.dart`.
      onReorderItem: onReorder,
      itemBuilder: (context, i) {
        final card = visible[i];
        return KeyedSubtree(
          // La clé DOIT être portée par l'enfant direct (exigence du SDK).
          key: ValueKey<String>('reorderable-${card.id ?? 'ephemeral-$i'}'),
          child: tileBuilder(context, card, i),
        );
      },
    );
  }
}

/// Tuile compacte d'une carte (AC3).
class _FlashcardTile extends StatelessWidget {
  const _FlashcardTile({
    required this.card,
    required this.labels,
    required this.actions,
    required this.showAnswerPreview,
    this.tagLabels,
    this.typeLabels,
    this.sourceLabels,
    this.contentBuilder,
    super.key,
  });

  final ZFlashcard card;
  final ZFlashcardListLabels labels;
  final List<ZItemAction> actions;
  final bool showAnswerPreview;
  final Map<String, String>? tagLabels;
  final Map<String, String>? typeLabels;
  final Map<String, String>? sourceLabels;
  final ZFlashcardTileContentBuilder? contentBuilder;

  /// Aperçu de la réponse : `answer`, ou le **choix correct** d'un QCM.
  ///
  /// Une carte QCM n'a pas d'`answer` : n'afficher que ce champ laisserait la
  /// moitié des types sans aperçu (le défaut « affiché nulle part »).
  String? get _answerPreview {
    final answer = card.answer;
    if (answer != null && answer.isNotEmpty) return answer;
    final choices = card.choices;
    if (choices == null || choices.isEmpty) return null;
    for (final choice in choices) {
      if (choice.isCorrect) return choice.content;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final surface = theme.surfaceColor ?? scheme.surfaceContainerHighest;
    // 🔴 Contraste : le premier plan est LISIBLE SUR le fond réellement peint
    // (`onSurfaceVariant` est le rôle apparié à `surfaceContainerHighest` —
    // jamais une couleur de FOND utilisée en premier plan, défaut su-6).
    final foreground = theme.labelColor ?? scheme.onSurfaceVariant;

    final preview = _answerPreview;

    return Semantics(
      // Un seul nœud sémantique par tuile : le lecteur d'écran annonce la carte
      // d'un bloc, pas ses fragments un à un.
      //
      // 🔴 **AUCUN `label:` explicite ici** — délibérément. `container: true`
      // **FUSIONNE déjà** les labels des descendants (question, badge de type,
      // badge lecture seule…) dans ce nœud. Ajouter `label: card.question`
      // ferait annoncer la question **DEUX FOIS** (« Annoncée, openQuestion,
      // Lecture seule, **Annoncée** ») — vérifié en dumpant l'arbre sémantique
      // réel, pas supposé. Le contenu vient des enfants, qui sont sa **seule**
      // source ; ce nœud ne fait que les grouper.
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.all(theme.radiusM),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.gapM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _TypeBadge(
                      type: card.type,
                      typeLabels: typeLabels,
                      foreground: foreground,
                    ),
                  ),
                  if (card.isReadOnly)
                    Padding(
                      padding: EdgeInsetsDirectional.only(start: theme.gapS),
                      child: Semantics(
                        label: labels.readOnlyBadge,
                        child: Icon(Icons.lock_outline,
                            size: 16, color: foreground),
                      ),
                    ),
                  ZItemActionsMenu(
                    actions: actions,
                    tooltip: labels.actionsMenuTooltip,
                  ),
                ],
              ),
              SizedBox(height: theme.gapS),
              // Question TRONQUÉE (AC3) — slot AD-40, défaut texte brut thématisé.
              Flexible(
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: _content(context, card.question, maxLines: 2),
                ),
              ),
              if (showAnswerPreview && preview != null) ...<Widget>[
                SizedBox(height: theme.gapS),
                Flexible(
                  child: DefaultTextStyle.merge(
                    style: TextStyle(color: foreground),
                    child: _content(context, preview, maxLines: 1),
                  ),
                ),
              ],
              if (card.tagIds.isNotEmpty) ...<Widget>[
                SizedBox(height: theme.gapS),
                _Tags(
                  tagIds: card.tagIds,
                  tagLabels: tagLabels,
                  foreground: foreground,
                ),
              ],
              if (card.source != null) ...<Widget>[
                SizedBox(height: theme.gapS),
                Text(
                  // 🔴 D2/AC20 — libellé INJECTÉ (repli sur la clé opaque),
                  // jamais le `kind` brut codé en dur (patron `tagLabels`).
                  sourceLabels?[card.source!.kind] ?? card.source!.kind,
                  textAlign: TextAlign.start,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // 🔴 R2 — taille via le thème (`labelSmall`), jamais un
                  // `fontSize:` littéral : un nombre en dur ignore la mise à
                  // l'échelle du texte (a11y) et casse le thème (FR-26/AD-13).
                  // `foreground` reste apposé (repli `const TextStyle()`).
                  style:
                      (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                          .copyWith(color: foreground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Contenu via le slot AD-40, ou **texte brut thématisé** par défaut.
  Widget _content(BuildContext context, String text, {required int maxLines}) {
    final builder = contentBuilder;
    if (builder != null) return builder(context, text);
    return Text(
      text,
      textAlign: TextAlign.start,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Badge de type de carte (AC3/D2).
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.type,
    required this.foreground,
    this.typeLabels,
  });

  final ZFlashcardType type;
  final Map<String, String>? typeLabels;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    // 🔴 D2/AC20 — la clé de type (`type.name`) est OPAQUE mais NE DOIT PAS être
    // servie telle quelle à l'utilisateur (« openQuestion » est un identifiant
    // Dart, écrit pour un dev). Le libellé est INJECTÉ via `typeLabels`, avec
    // repli sur la clé (patron `tagLabels`) — jamais une traduction en dur.
    return Text(
      typeLabels?[type.name] ?? type.name,
      textAlign: TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // 🔴 R2 — taille via le thème (`labelSmall`), jamais un `fontSize:`
      // littéral (a11y / thème — FR-26/AD-13). `foreground` reste apposé.
      style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
          .copyWith(color: foreground),
    );
  }
}

/// Étiquettes de la carte (AC3).
class _Tags extends StatelessWidget {
  const _Tags({
    required this.tagIds,
    required this.foreground,
    this.tagLabels,
  });

  final List<String> tagIds;
  final Map<String, String>? tagLabels;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Wrap(
      spacing: theme.gapS,
      children: <Widget>[
        for (final id in tagIds)
          Text(
            tagLabels?[id] ?? id,
            textAlign: TextAlign.start,
            // 🔴 R2 — taille via le thème (`labelSmall`), jamais un `fontSize:`
            // littéral (a11y / thème — FR-26/AD-13). `foreground` reste apposé.
            style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                .copyWith(color: foreground),
          ),
      ],
    );
  }
}
