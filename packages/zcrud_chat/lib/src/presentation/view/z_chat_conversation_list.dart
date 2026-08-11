/// Liste neutre de conversations.
///
/// ## Cinq défauts fréquents qu'une liste de conversations doit éviter
///
/// 1. Une liste construite d'un coup (`ListView(children: [...])`) monte
///    toutes ses lignes, groupes repliés compris. Ici : `.builder`, et les
///    groupes sont aplatis en lignes avant d'être construits — un groupe
///    replié ne coûte pas ses lignes.
/// 2. Un état initial qui ne distingue ni le chargement ni l'erreur affiche
///    « aucune conversation » avant que la moindre donnée soit arrivée, et
///    sur tout échec de chargement. Ici, trois états distincts.
/// 3. L'erreur doit être testée avant le chargement : un flux en échec
///    pendant un rechargement doit rester signalé comme échec, pas comme
///    « en chargement » — sans quoi l'écran resterait bloqué sur le
///    squelette pour toujours.
/// 4. Un tri appliqué à une copie de la liste plutôt qu'à la liste
///    effectivement rendue laisse l'écran non trié. Ici le tri est un
///    paramètre, appliqué à la liste qui est ensuite rendue, une seule fois.
/// 5. Une pagination déclarée côté données mais jamais déclenchée côté
///    interface reste morte. Ici, [ZChatConversationList.onLoadMore] et
///    [ZChatConversationList.hasMore] posent le déclencheur.
///
/// ## Ce qui reste hors de ce widget
///
/// Aucune navigation (des callbacks, jamais une route) ; aucune hiérarchie à
/// champs fixes (la clé de groupe est opaque) ; aucun drapeau de déploiement
/// (ne pas passer le callback est le drapeau) ; aucune canonicalisation
/// d'URL de partage.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../conversation/z_chat_conversation_selection.dart';
import '../conversation/z_chat_group_expansion.dart';
import 'z_chat_conversation_actions.dart';
import 'z_chat_conversation_tile.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

/// État de chargement de la liste — **distinct** de « vide » et de « erreur ».
enum ZChatConversationListStatus {
  /// Les données n'ont pas encore été rendues disponibles.
  loading,

  /// Les données sont à jour.
  ready,
}

/// Prédicat de recherche injectable.
///
/// Un filtre client qui ne cherche que le titre laisse tout résultat obtenu
/// par le contenu des messages sans surlignage. Le socle ne peut pas faire
/// mieux par défaut (il n'a pas les corps de messages sous la main), mais il
/// ne fige pas le défaut : un hôte qui indexe autre chose passe le sien.
typedef ZChatConversationMatcher = bool Function(
  ZChatConversation conversation,
  String term,
);

/// Prédicat par défaut — le titre, insensible à la casse.
bool zChatDefaultConversationMatcher(ZChatConversation c, String term) =>
    c.title.toLowerCase().contains(term.trim().toLowerCase());

/// Enveloppe une ligne — le créneau qui évite la réécriture de la tuile.
///
/// Un hôte qui veut décorer une ligne selon un état qui lui est propre (par
/// exemple une animation tant qu'une génération est en cours) n'a pas à
/// réécrire la tuile entière pour l'entourer.
typedef ZChatConversationItemWrapper = Widget Function(
  BuildContext context,
  ZChatConversation conversation,
  Widget child,
);

/// Construit l'en-tête d'un groupe. `null` ⇒ aucun en-tête (et donc aucun
/// repliement : on ne replie pas ce qu'on ne montre pas).
typedef ZChatGroupHeaderBuilder = Widget? Function(
  BuildContext context,
  Object? groupKey,
  int count,
);

/// Extrait la clé de groupe opaque d'une conversation.
///
/// `Object?`, pas `String` : une hiérarchie de groupement appartient
/// toujours à des spécificités d'hôte, et la modéliser en champs fixes
/// interdirait toute autre hiérarchie (par date, par sujet, par état).
typedef ZChatGroupKey = Object? Function(ZChatConversation conversation);

/// Liste neutre de conversations — `ListView.builder`, trois états, groupes
/// repliables, sélection multiple, pagination par curseur.
class ZChatConversationList extends StatelessWidget {
  /// Construit la liste.
  const ZChatConversationList({
    required this.items,
    this.status = ZChatConversationListStatus.ready,
    this.failure,
    this.onRetry,
    this.sort,
    this.matcher,
    this.searchTerm = '',
    this.header,
    this.itemWrapper,
    this.tileBuilder,
    this.groupKeyOf,
    this.groupHeaderBuilder,
    this.groupExpansion,
    this.selection,
    this.onRetireSelected,
    this.onOpen,
    this.onCreate,
    this.onLoadMore,
    this.hasMore = false,
    this.autoLoadMore = true,
    this.emptyBuilder,
    this.errorBuilder,
    this.loadingBuilder,
    this.skeletonRowCount = 6,
    this.padding,
    this.tileConfig = const ZChatConversationTileConfig(),
    super.key,
  });

  /// Les conversations, telles que l'hôte les fournit.
  final List<ZChatConversation> items;

  /// Chargement ou prêt — **jamais** confondu avec « vide ».
  final ZChatConversationListStatus status;

  /// Échec courant, ou `null`. Testé **AVANT** [status] (cf. §3 de l'en-tête).
  final ZFailure? failure;

  /// Relance après un échec, ou `null` (aucun bouton).
  final VoidCallback? onRetry;

  /// Comparateur de tri **exposé**, appliqué à la liste RENDUE, ou `null`.
  final int Function(ZChatConversation a, ZChatConversation b)? sort;

  /// Prédicat de recherche local, ou `null` (l'hôte a déjà filtré, cas d'un
  /// backend qui répond à `searchConversations`).
  final ZChatConversationMatcher? matcher;

  /// Terme cherché — pilote le surlignage **et** la variante d'état vide.
  final String searchTerm;

  /// Slot d'en-tête de liste (bandeau, filtres, compteur…).
  final Widget? header;

  /// Enveloppe de ligne (cf. [ZChatConversationItemWrapper]).
  final ZChatConversationItemWrapper? itemWrapper;

  /// Remplace la tuile par défaut, ou `null`.
  final Widget? Function(BuildContext context, ZChatConversation conversation)?
  tileBuilder;

  /// Clé de groupe opaque, ou `null` (liste plate).
  final ZChatGroupKey? groupKeyOf;

  /// En-tête de groupe, ou `null`.
  final ZChatGroupHeaderBuilder? groupHeaderBuilder;

  /// Contrôleur de repliement externe. `null` signifie groupes toujours
  /// dépliés. Le socle n'en crée jamais : un contrôleur créé dans `build`
  /// perdrait son état à chaque rebuild, et ses listeners fuiraient.
  final ZChatGroupExpansion? groupExpansion;

  /// Sélection multiple **externe**, ou `null` (aucune sélection multiple).
  final ZChatConversationSelection? selection;

  /// Retrait par **lot** — pendant de `retireAll`. `null` ⇒ action absente.
  final void Function(Set<String> ids)? onRetireSelected;

  /// Ouverture d'une conversation (appui simple hors sélection).
  final void Function(ZChatConversation conversation)? onOpen;

  /// Création — **masquée en recherche** : « créer » ne répond pas à « votre
  /// recherche ne rend rien ».
  final VoidCallback? onCreate;

  /// Chargement de la page suivante. `null` ⇒ aucune pagination.
  final VoidCallback? onLoadMore;

  /// `true` s'il reste une page (le curseur est détenu par l'hôte).
  final bool hasMore;

  /// `true` ⇒ [onLoadMore] est déclenché dès que la ligne de fin est **montée**
  /// (défilement infini) ; `false` ⇒ seulement à l'appui.
  final bool autoLoadMore;

  /// Rendu de l'état vide, ou `null` (défaut du socle). Le second argument dit
  /// si une recherche est en cours.
  final Widget? Function(BuildContext context, bool searching)? emptyBuilder;

  /// Rendu de l'état d'erreur, ou `null` (défaut du socle).
  final Widget? Function(BuildContext context, ZFailure failure)? errorBuilder;

  /// Rendu de l'état de chargement, ou `null` (squelette du socle).
  final Widget? Function(BuildContext context)? loadingBuilder;

  /// Nombre de lignes du squelette.
  final int skeletonRowCount;

  /// Marge **directionnelle** de la liste (AD-13).
  final EdgeInsetsDirectional? padding;

  /// Configuration passée à chaque tuile par défaut.
  final ZChatConversationTileConfig tileConfig;

  /// La liste réellement rendue : filtrée, puis triée.
  ///
  /// Exposée publiquement pour qu'un test puisse comparer l'ordre rendu à
  /// l'ordre attendu sans avoir à recopier la logique.
  List<ZChatConversation> get renderedItems {
    final String term = searchTerm.trim();
    final ZChatConversationMatcher? m = matcher;
    final List<ZChatConversation> out = <ZChatConversation>[
      for (final ZChatConversation c in items)
        if (term.isEmpty || m == null || m(c, term)) c,
    ];
    final int Function(ZChatConversation, ZChatConversation)? comparator = sort;
    if (comparator != null) out.sort(comparator);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final EdgeInsetsDirectional pad = padding ?? theme.formPadding;
    // Les deux contrôleurs externes changent les lignes rendues (le
    // repliement retire des lignes, la sélection change l'état de chacune) :
    // ils sont donc écoutés au-dessus de l'aplatissement, jamais dedans. Un
    // abonnement pris sous `_flatten` verrait l'ancienne liste.
    final List<Listenable> sources = <Listenable>[
      ?selection,
      ?groupExpansion,
    ];
    final Widget content = sources.isEmpty
        ? _content(context, theme, pad)
        : ListenableBuilder(
            listenable: Listenable.merge(sources),
            builder: (BuildContext context, Widget? child) =>
                _withSelectionBar(context, _content(context, theme, pad)),
          );
    return Semantics(
      container: true,
      label: zChatLabel(context, kZChatLabelConversations),
      child: header == null
          ? content
          : Column(
              children: <Widget>[header!, Expanded(child: content)],
            ),
    );
  }

  /// Coiffe le corps de la barre de sélection **quand le mode est engagé**.
  Widget _withSelectionBar(BuildContext context, Widget body) {
    final ZChatConversationSelection? sel = selection;
    if (sel == null || !sel.active) return body;
    return Column(
      children: <Widget>[
        _ZSelectionBar(selection: sel, onRetireSelected: onRetireSelected),
        Expanded(child: body),
      ],
    );
  }

  Widget _content(
    BuildContext context,
    ZcrudTheme theme,
    EdgeInsetsDirectional pad,
  ) {
    // Ordre non négociable : l'échec d'abord. Un flux qui échoue pendant un
    // rechargement resterait « en chargement » et bloquerait l'écran sur le
    // squelette pour toujours.
    final ZFailure? f = failure;
    if (f != null) {
      return errorBuilder?.call(context, f) ?? _ZErrorState(onRetry: onRetry);
    }
    if (status == ZChatConversationListStatus.loading) {
      return loadingBuilder?.call(context) ??
          _ZSkeleton(rowCount: skeletonRowCount, padding: pad);
    }
    final List<ZChatConversation> rendered = renderedItems;
    if (rendered.isEmpty) {
      final bool searching = searchTerm.trim().isNotEmpty;
      return emptyBuilder?.call(context, searching) ??
          _ZEmptyState(
            searching: searching,
            // L'action de création est masquée en recherche.
            onCreate: searching ? null : onCreate,
          );
    }
    return _ZRows(
      list: this,
      rows: _flatten(rendered),
      padding: pad,
    );
  }

  /// Aplatit la liste rendue en **lignes** : en-têtes de groupe, éléments des
  /// groupes dépliés, et — s'il y a lieu — la ligne de pagination.
  List<_ZRow> _flatten(List<ZChatConversation> rendered) {
    final List<_ZRow> rows = <_ZRow>[];
    final ZChatGroupKey? keyOf = groupKeyOf;
    if (keyOf == null || groupHeaderBuilder == null) {
      rows.addAll(rendered.map(_ZRow.item));
    } else {
      // Groupes dans l'ordre de PREMIÈRE APPARITION après tri : le tri reste
      // l'unique source de l'ordre (cf. dette n°4).
      final List<Object?> order = <Object?>[];
      final Map<Object?, List<ZChatConversation>> buckets =
          <Object?, List<ZChatConversation>>{};
      for (final ZChatConversation c in rendered) {
        final Object? k = keyOf(c);
        final List<ZChatConversation> bucket = buckets.putIfAbsent(k, () {
          order.add(k);
          return <ZChatConversation>[];
        });
        bucket.add(c);
      }
      for (final Object? k in order) {
        final List<ZChatConversation> bucket = buckets[k]!;
        rows.add(_ZRow.header(k, bucket.length));
        if (groupExpansion?.isExpanded(k) ?? true) {
          rows.addAll(bucket.map(_ZRow.item));
        }
      }
    }
    if (hasMore && onLoadMore != null) rows.add(const _ZRow.loadMore());
    return rows;
  }
}

/// Réglages passés aux tuiles par défaut — un seul objet plutôt que quinze
/// paramètres recopiés sur la liste.
@immutable
class ZChatConversationTileConfig {
  /// Construit une configuration.
  const ZChatConversationTileConfig({
    this.titleMaxLines = 1,
    this.isStrongTitle,
    this.timestampOf = zChatLastMessageTimestamp,
    this.timeFormatter = zChatDefaultRelativeTime,
    this.now,
    this.iconColorKey = '',
    this.iconSlotIndex = 0,
    this.iconBuilder,
    this.leadingBuilder,
    this.subtitleBuilder,
    this.trailingBuilder,
    this.badges = const <ZChatConversationBadge>[],
    this.actions = const <ZChatConversationAction>[],
    this.minHeight = kZChatMinTapTarget,
  });

  /// Cf. `ZChatConversationTile.titleMaxLines`.
  final int titleMaxLines;

  /// Cf. `ZChatConversationTile.isStrongTitle`.
  final bool Function(ZChatConversation conversation)? isStrongTitle;

  /// Cf. `ZChatConversationTile.timestampOf`.
  final ZChatConversationTimestamp timestampOf;

  /// Cf. `ZChatConversationTile.timeFormatter`.
  final ZChatRelativeTimeFormatter timeFormatter;

  /// Cf. `ZChatConversationTile.now`.
  final DateTime? now;

  /// Cf. `ZChatConversationTile.iconColorKey`.
  final String iconColorKey;

  /// Cf. `ZChatConversationTile.iconSlotIndex`.
  final int iconSlotIndex;

  /// Cf. `ZChatConversationTile.iconBuilder`.
  final ZChatActionIconBuilder? iconBuilder;

  /// Cf. `ZChatConversationTile.leadingBuilder`.
  final ZChatConversationLeadingBuilder? leadingBuilder;

  /// Cf. `ZChatConversationTile.subtitleBuilder`.
  final ZChatConversationSubtitleBuilder? subtitleBuilder;

  /// Construit le `trailing` d'une ligne, ou `null`.
  final Widget? Function(BuildContext context, ZChatConversation conversation)?
  trailingBuilder;

  /// Cf. `ZChatConversationTile.badges`.
  final List<ZChatConversationBadge> badges;

  /// Cf. `ZChatConversationTile.actions`.
  final List<ZChatConversationAction> actions;

  /// Cf. `ZChatConversationTile.minHeight`.
  final double minHeight;
}

/// Une ligne aplatie : en-tête de groupe, élément, ou pagination.
@immutable
class _ZRow {
  const _ZRow.header(this.groupKey, this.count)
    : conversation = null,
      isLoadMore = false;

  _ZRow.item(this.conversation) : groupKey = null, count = 0, isLoadMore = false;

  const _ZRow.loadMore()
    : conversation = null,
      groupKey = null,
      count = 0,
      isLoadMore = true;

  final ZChatConversation? conversation;
  final Object? groupKey;
  final int count;
  final bool isLoadMore;

  bool get isHeader => conversation == null && !isLoadMore;
}

/// Le corps virtualisé.
class _ZRows extends StatelessWidget {
  const _ZRows({
    required this.list,
    required this.rows,
    required this.padding,
  });

  final ZChatConversationList list;
  final List<_ZRow> rows;
  final EdgeInsetsDirectional padding;

  @override
  Widget build(BuildContext context) => ListView.builder(
    // `.builder` — jamais `ListView(children: [...])`. Les lignes sont déjà
    // aplaties : un groupe replié ne coûte pas ses éléments.
    padding: padding,
    itemCount: rows.length,
    itemBuilder: _row,
  );

  Widget _row(BuildContext context, int index) {
    // Invariant AD-10 : un index hors-bornes ne fait pas tomber la liste.
    if (index < 0 || index >= rows.length) return const SizedBox.shrink();
    final _ZRow row = rows[index];
    if (row.isLoadMore) {
      return _ZLoadMoreRow(
        onLoadMore: list.onLoadMore,
        auto: list.autoLoadMore,
      );
    }
    if (row.isHeader) {
      return _ZGroupHeader(list: list, groupKey: row.groupKey, count: row.count);
    }
    final ZChatConversation c = row.conversation!;
    final Widget tile =
        list.tileBuilder?.call(context, c) ?? _defaultTile(context, c);
    final Widget keyed = KeyedSubtree(
      key: ValueKey<String>('zchat.conv#${c.id ?? index}'),
      child: tile,
    );
    return list.itemWrapper?.call(context, c, keyed) ?? keyed;
  }

  Widget _defaultTile(BuildContext context, ZChatConversation c) {
    final ZChatConversationTileConfig cfg = list.tileConfig;
    final ZChatConversationSelection? sel = list.selection;
    return ZChatConversationTile(
      conversation: c,
      titleMaxLines: cfg.titleMaxLines,
      isStrongTitle: cfg.isStrongTitle,
      timestampOf: cfg.timestampOf,
      timeFormatter: cfg.timeFormatter,
      now: cfg.now,
      iconColorKey: cfg.iconColorKey,
      iconSlotIndex: cfg.iconSlotIndex,
      iconBuilder: cfg.iconBuilder,
      leadingBuilder: cfg.leadingBuilder,
      subtitleBuilder: cfg.subtitleBuilder,
      trailing: cfg.trailingBuilder?.call(context, c),
      badges: cfg.badges,
      actions: cfg.actions,
      minHeight: cfg.minHeight,
      searchTerm: list.searchTerm,
      isSelected: sel?.isSelected(c.id) ?? false,
      // En mode sélection, l'appui simple COCHE ; hors mode, il OUVRE.
      onTap: (sel != null && sel.active)
          ? (ZChatConversation x) => sel.toggle(x.id)
          : list.onOpen,
      // L'appui long ENTRE en sélection — jamais un second geste caché.
      onLongPress: sel == null
          ? null
          : (ZChatConversation x) => sel.begin(x.id),
    );
  }
}

/// L'en-tête d'un groupe — repliable **si** un contrôleur externe est fourni.
class _ZGroupHeader extends StatelessWidget {
  const _ZGroupHeader({
    required this.list,
    required this.groupKey,
    required this.count,
  });

  final ZChatConversationList list;
  final Object? groupKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final Widget? built = list.groupHeaderBuilder?.call(
      context,
      groupKey,
      count,
    );
    if (built == null) return const SizedBox.shrink();
    final ZChatGroupExpansion? expansion = list.groupExpansion;
    if (expansion == null) return built;
    return Semantics(
      button: true,
      expanded: expansion.isExpanded(groupKey),
      onTap: () => expansion.toggle(groupKey),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => expansion.toggle(groupKey),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: built,
          ),
        ),
      ),
    );
  }
}

/// La barre de sélection multiple : compte, sortie explicite, retrait par lot.
class _ZSelectionBar extends StatelessWidget {
  const _ZSelectionBar({required this.selection, required this.onRetireSelected});

  final ZChatConversationSelection selection;
  final void Function(Set<String> ids)? onRetireSelected;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return Semantics(
      container: true,
      label: zChatCountLabel(
        context,
        kZChatLabelSelectedCount,
        selection.count,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    zChatCountLabel(
                      context,
                      kZChatLabelSelectedCount,
                      selection.count,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
              if (onRetireSelected != null)
                _ZBarButton(
                  labelKey: kZChatLabelRetireSelected,
                  onTap: () => onRetireSelected!(selection.selectedIds),
                ),
              _ZBarButton(
                labelKey: kZChatLabelExitSelection,
                onTap: selection.clear,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un bouton de barre — cible ≥ 48 dp, libellé résolu.
class _ZBarButton extends StatelessWidget {
  const _ZBarButton({required this.labelKey, required this.onTap});

  final String labelKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kZChatMinTapTarget,
            minWidth: kZChatMinTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            child: Text(zChatLabel(context, labelKey), textAlign: TextAlign.start),
          ),
        ),
      ),
    );
  }
}

/// La ligne de pagination — pendant du curseur détenu par l'hôte.
class _ZLoadMoreRow extends StatefulWidget {
  const _ZLoadMoreRow({required this.onLoadMore, required this.auto});

  final VoidCallback? onLoadMore;
  final bool auto;

  @override
  State<_ZLoadMoreRow> createState() => _ZLoadMoreRowState();
}

class _ZLoadMoreRowState extends State<_ZLoadMoreRow> {
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    if (!widget.auto || widget.onLoadMore == null) return;
    // Différé : déclencher pendant la construction relancerait un build dans
    // la même frame. Et une seule fois par montage — sans quoi un hôte dont
    // `hasMore` reste `true` boucle à l'infini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_fired || !mounted) return;
      _fired = true;
      widget.onLoadMore?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? load = widget.onLoadMore;
    if (load == null) return const SizedBox.shrink();
    return Semantics(
      button: true,
      onTap: load,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: load,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
          child: Align(
            alignment: AlignmentDirectional.center,
            child: Text(
              zChatLabel(context, kZChatLabelLoadMore),
              textAlign: TextAlign.start,
            ),
          ),
        ),
      ),
    );
  }
}

/// Le squelette de chargement — structuré et annoncé.
class _ZSkeleton extends StatelessWidget {
  const _ZSkeleton({required this.rowCount, required this.padding});

  final int rowCount;
  final EdgeInsetsDirectional padding;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: zChatLabel(context, kZChatLabelLoadingConversations),
      child: ExcludeSemantics(
        child: ListView.builder(
          padding: padding,
          itemCount: rowCount < 0 ? 0 : rowCount,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: EdgeInsetsDirectional.only(bottom: theme.gapM),
            child: SizedBox(
              height: kZChatMinTapTarget,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  // La teinte du squelette est dérivée du `ColorScheme`
                  // (slot neutre), jamais un gris littéral.
                  color: zResolveColorKeyOrSlot(
                    context,
                    '',
                    slotIndex: ZColorSlot.neutral.index,
                  ).color,
                  borderRadius: BorderRadius.all(theme.radiusM),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'état d'erreur — distinct de l'état vide.
class _ZErrorState extends StatelessWidget {
  const _ZErrorState({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: zChatLabel(context, kZChatLabelConversationsError),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
              child: Text(
                zChatLabel(context, kZChatLabelConversationsError),
                textAlign: TextAlign.start,
              ),
            ),
          ),
          if (onRetry != null)
            _ZBarButton(labelKey: kZChatLabelRetry, onTap: onRetry!),
        ],
      ),
    );
  }
}

/// L'état vide, **à deux variantes**.
class _ZEmptyState extends StatelessWidget {
  const _ZEmptyState({required this.searching, required this.onCreate});

  final bool searching;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final String key = searching
        ? kZChatLabelNoResults
        : kZChatLabelNoConversations;
    return Semantics(
      container: true,
      label: zChatLabel(context, key),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ExcludeSemantics(
            child: Padding(
              padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
              child: Text(zChatLabel(context, key), textAlign: TextAlign.start),
            ),
          ),
          if (onCreate != null)
            _ZBarButton(
              labelKey: kZChatLabelNewConversation,
              onTap: onCreate!,
            ),
        ],
      ),
    );
  }
}
