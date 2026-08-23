/// **Une entrée d'outil déclarée** — `ZChatToolEntry`, et les règles qui
/// décident de sa présence, de sa surface et de sa disponibilité.
///
/// Domaine PUR (aucun Flutter, aucun libellé inventé, aucune icône, aucune
/// couleur).
///
/// ## Les trois règles normatives portées par ce fichier
///
/// 1. **Un outil est déclaré UNE fois, rendu par PLUSIEURS surfaces.** La
///    proéminence ([ZChatToolProminence]) dit *où* il est proéminent ; l'état
///    reste unique. Un même réglage visible dans la bande et dans la feuille
///    n'est donc pas un doublon : c'est **un état, deux surfaces, une
///    déclaration**.
/// 2. **Une entrée indisponible est RENDUE, jamais masquée, et porte sa
///    raison.** Masquer une affordance laisse l'utilisateur sans explication ;
///    la désactiver en disant pourquoi lui rend l'information. C'est
///    [ZChatToolEntry.disabledWhen] et son jeton de raison.
/// 3. **Le socle ne nomme rien.** [ZChatToolEntry.label],
///    [ZChatToolEntry.stateLabels] et les jetons de raison sont **fournis par
///    l'hôte** (FR-26). Le socle produit des **jetons**, l'hôte produit du
///    texte.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_tool_state.dart';

/// Où un outil est **proéminent**.
///
/// La déclaration reste unique quelle que soit la valeur : ce n'est pas une
/// duplication d'outil, c'est un choix de surface.
enum ZChatToolProminence {
  /// La proéminence **suit l'état** : l'outil apparaît dans la bande dès qu'il
  /// est actif, et disparaît de la bande quand il retombe à l'inactif. Il reste
  /// toujours présent dans la feuille.
  auto,

  /// Toujours dans la bande **et** dans la feuille, actif ou non.
  band,

  /// Feuille seulement — jamais dans la bande, même actif.
  sheet;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** (repli [ZChatToolProminence.auto]) — ne lève jamais.
  static ZChatToolProminence fromJson(Object? raw) {
    switch (raw) {
      case 'band':
        return ZChatToolProminence.band;
      case 'sheet':
        return ZChatToolProminence.sheet;
      case 'auto':
      default:
        return ZChatToolProminence.auto;
    }
  }
}

/// La surface qui interroge le catalogue.
enum ZChatToolSurface {
  /// La bande compacte du composer — elle ne rend que les proéminents.
  band,

  /// La feuille — elle rend **tout** ce qui est révélé.
  sheet,
}

/// Pourquoi une entrée déclarée n'est pas rendue par la surface interrogée.
///
/// Une entrée absente est toujours **explicable** : la résolution nomme la
/// raison plutôt que de laisser l'entrée s'évaporer.
enum ZChatToolHiddenReason {
  /// Non proéminente pour la surface demandée (cas normal de la bande).
  notOnSurface,

  /// Sa bascule parente est inactive (révélation conditionnelle).
  parentInactive,

  /// Sa bascule parente est introuvable, ou la chaîne de révélation boucle.
  unknownParent,

  /// Écartée par la recherche.
  filteredOut,
}

/// Lecture de l'activité d'une entrée par sa clé.
///
/// `null` signifie **clé inconnue** — distinct de « connue et inactive ». Les
/// conditions s'appuient sur cette distinction pour rester fail-safe.
typedef ZChatToolActivityLookup = bool? Function(String key);

/// Une **condition déclarative** sur l'état du catalogue : une conjonction
/// « ces clés-là actives, ces clés-là inactives ».
///
/// Deux propriétés en font un prédicat sûr :
/// * une condition **vide n'est jamais satisfaite** — sans quoi une règle mal
///   déclarée désactiverait son entrée pour toujours ;
/// * une clé **inconnue** ne satisfait rien — ni le versant actif, ni le
///   versant inactif. En l'absence de signal on ne conclut pas.
class ZChatToolCondition {
  /// Construit une condition. Les clés sont rognées, dédupliquées, vides
  /// écartées.
  ZChatToolCondition({
    Iterable<String> activeKeys = const <String>[],
    Iterable<String> inactiveKeys = const <String>[],
  })  : activeKeys = List<String>.unmodifiable(_keys(activeKeys)),
        inactiveKeys = List<String>.unmodifiable(_keys(inactiveKeys));

  /// Clés qui doivent être **actives**.
  final List<String> activeKeys;

  /// Clés qui doivent être **inactives**.
  final List<String> inactiveKeys;

  /// `true` si la condition n'exprime rien — elle n'est alors jamais satisfaite.
  bool get isEmpty => activeKeys.isEmpty && inactiveKeys.isEmpty;

  /// Évalue la condition contre l'activité courante.
  bool isSatisfiedBy(ZChatToolActivityLookup lookup) {
    if (isEmpty) return false;
    for (final String k in activeKeys) {
      if (lookup(k) != true) return false;
    }
    for (final String k in inactiveKeys) {
      if (lookup(k) != false) return false;
    }
    return true;
  }

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais.
  static ZChatToolCondition? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatToolCondition(
      activeKeys: zJsonStringList(map['active_keys']) ?? const <String>[],
      inactiveKeys: zJsonStringList(map['inactive_keys']) ?? const <String>[],
    );
  }

  /// Sérialise en clés `snake_case` ; les champs vides sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (activeKeys.isNotEmpty) 'active_keys': activeKeys,
        if (inactiveKeys.isNotEmpty) 'inactive_keys': inactiveKeys,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatToolCondition &&
          zListEquals(activeKeys, other.activeKeys) &&
          zListEquals(inactiveKeys, other.inactiveKeys);

  @override
  int get hashCode => Object.hash(zListHash(activeKeys), zListHash(inactiveKeys));

  @override
  String toString() =>
      'ZChatToolCondition(active: $activeKeys, inactive: $inactiveKeys)';
}

/// Une **règle de désactivation** : une condition, et le jeton de la raison à
/// montrer quand elle mord.
///
/// Le jeton est opaque — c'est l'hôte qui le traduit. Une règle sans jeton
/// serait une désactivation muette, exactement ce que ce type existe pour
/// empêcher.
class ZChatToolRule {
  /// Construit une règle.
  ZChatToolRule({required this.condition, required this.reasonToken});

  /// La condition qui déclenche la désactivation.
  final ZChatToolCondition condition;

  /// Jeton opaque de la raison, résolu par l'hôte.
  final String reasonToken;

  /// Décode **défensivement** (invariant AD-10) — une règle sans condition
  /// lisible ou sans jeton de raison est **écartée**, jamais partiellement
  /// reconstruite : une règle dont on ne saurait pas dire pourquoi elle mord
  /// vaut moins que pas de règle.
  static ZChatToolRule? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final ZChatToolCondition? condition =
        ZChatToolCondition.fromJson(map['condition']);
    final String? reason = zJsonStringOrNull(map['reason_token']);
    if (condition == null || condition.isEmpty || reason == null) return null;
    return ZChatToolRule(condition: condition, reasonToken: reason);
  }

  /// Sérialise en clés `snake_case`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'condition': condition.toJson(),
        'reason_token': reasonToken,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatToolRule &&
          condition == other.condition &&
          reasonToken == other.reasonToken;

  @override
  int get hashCode => Object.hash(condition, reasonToken);

  @override
  String toString() => 'ZChatToolRule($condition -> $reasonToken)';
}

/// Une entrée d'outil déclarée : une identité, une nature, un état, et les
/// règles qui décident de sa présence.
class ZChatToolEntry {
  /// Construit une entrée.
  ZChatToolEntry({
    required this.key,
    required this.state,
    this.label,
    this.iconKey,
    this.sectionKey,
    this.prominence = ZChatToolProminence.auto,
    this.revealedBy,
    List<ZChatToolRule> disabledWhen = const <ZChatToolRule>[],
    Iterable<String> deactivates = const <String>[],
    Map<String, String> stateLabels = const <String, String>{},
    Map<String, String> itemLabels = const <String, String>{},
    Iterable<String> searchTerms = const <String>[],
    this.countsTowardActive = true,
    this.order = 0,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  })  : disabledWhen = List<ZChatToolRule>.unmodifiable(disabledWhen),
        deactivates = List<String>.unmodifiable(_keys(deactivates)),
        stateLabels = Map<String, String>.unmodifiable(stateLabels),
        itemLabels = Map<String, String>.unmodifiable(itemLabels),
        searchTerms = List<String>.unmodifiable(_keys(searchTerms)),
        _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Identité **stable et opaque**. C'est la cible des règles, de la
  /// révélation, de l'exclusion et des builders de rendu.
  final String key;

  /// Nature et état courant.
  final ZChatToolState state;

  /// Libellé **déjà localisé par l'hôte**. `null` signifie absent — le socle
  /// n'en fabrique aucun (FR-26).
  final String? label;

  /// Clé d'icône **opaque**, résolue par l'hôte au rendu — pendant visuel
  /// du jeton de raison : le socle transporte la clé, ne dessine rien.
  /// `null` ⇒ aucune icône déclarée.
  final String? iconKey;

  /// Section d'appartenance. `null` ⇒ section non assignée.
  final String? sectionKey;

  /// Surface(s) où l'outil est proéminent.
  final ZChatToolProminence prominence;

  /// Clé de la **bascule parente** : l'entrée n'est révélée que si cette
  /// entrée-là est présente et active. `null` ⇒ toujours révélée.
  ///
  /// C'est le réglage fin qui ne se déplie qu'une fois sa bascule allumée : la
  /// feuille reste courte au repos.
  final String? revealedBy;

  /// Règles de désactivation, évaluées **dans l'ordre** : la première
  /// satisfaite fournit la raison.
  final List<ZChatToolRule> disabledWhen;

  /// Clés que l'**activation** de cette entrée rend inactives (exclusion
  /// mutuelle). L'effet est appliqué par le catalogue, à un seul endroit.
  final List<String> deactivates;

  /// Association `jeton d'état → texte d'hôte`, source du sous-titre qui décrit
  /// **l'état** et non la fonction. Un jeton absent ⇒ pas de sous-titre.
  final Map<String, String> stateLabels;

  /// Association `clé d'item → texte d'hôte` pour les **items** d'un
  /// catalogue ou les **options** d'un choix — le canal déclaré des libellés
  /// d'items, distinct de [stateLabels] (qui nomme des **états**).
  ///
  /// Lecture par [describeItem], qui retombe sur `stateLabels[itemKey]` :
  /// une entrée qui nommait déjà ses items dans [stateLabels] reste valide.
  final Map<String, String> itemLabels;

  /// Termes supplémentaires interrogés par la recherche, en plus de [label].
  final List<String> searchTerms;

  /// `false` pour un outil qui ne doit **pas** peupler le comptage agrégé.
  final bool countsTowardActive;

  /// Rang au sein de sa section (croissant) ; à égalité, l'ordre de
  /// déclaration décide.
  final int order;

  /// Slot d'extension typé versionné (invariant AD-4).
  final ZExtension? extension;

  /// Données d'hôte libres (invariant AD-4), immuables.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) et les
  /// clés propres de l'entrée (`key`, `state`, `icon_key`…) en sont
  /// **retirées**, quelle que soit la voie d'écriture : elles ne sont ni
  /// conservées ni réémises par [toJson].
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  // Slot brut, lu uniquement par l'accesseur `extra`.
  final Map<String, dynamic> _extra;

  // Clés propres émises par `toJson` ∪ clés de sync hors-entité (AD-9).
  static const Set<String> _reservedKeys = <String>{
    'key',
    'state',
    'label',
    'icon_key',
    'section_key',
    'prominence',
    'revealed_by',
    'disabled_when',
    'deactivates',
    'state_labels',
    'item_labels',
    'search_terms',
    'counts_toward_active',
    'order',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// État par défaut appliqué par la remise à zéro.
  ///
  /// Il est dérivé de la nature courante ([ZChatToolState.cleared]) : une
  /// remise à zéro ne change jamais la **nature** d'un outil, seulement sa
  /// position.
  ZChatToolState get defaultState => state.cleared;

  /// `true` si l'état courant compte comme « activé ».
  bool get isActive => state.isActive;

  /// Le sous-titre d'état, ou `null` si l'hôte n'a pas nommé ce jeton.
  String? describeState() => stateLabels[state.stateToken];

  /// Le libellé d'hôte de l'item [itemKey] — [itemLabels] d'abord, puis
  /// [stateLabels] (convention de repli) — ou `null` si l'hôte ne l'a pas
  /// nommé. Un item non nommé n'est jamais remplacé par un texte du socle.
  String? describeItem(String itemKey) =>
      itemLabels[itemKey] ?? stateLabels[itemKey];

  /// `true` si [query] (rognée, insensible à la casse) apparaît dans [label]
  /// ou dans un [searchTerms]. Une requête vide accepte **tout**.
  bool matches(String query) {
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if ((label ?? '').toLowerCase().contains(q)) return true;
    for (final String t in searchTerms) {
      if (t.toLowerCase().contains(q)) return true;
    }
    return false;
  }

  /// Même entrée, état remplacé.
  ZChatToolEntry withState(ZChatToolState next) => _copy(next);

  /// Même entrée, ramenée à son état inactif.
  ZChatToolEntry cleared() => _copy(state.cleared);

  /// Même entrée, ramenée à [defaultState].
  ZChatToolEntry reset() => _copy(defaultState);

  ZChatToolEntry _copy(ZChatToolState next) => ZChatToolEntry(
        key: key,
        state: next,
        label: label,
        iconKey: iconKey,
        sectionKey: sectionKey,
        prominence: prominence,
        revealedBy: revealedBy,
        disabledWhen: disabledWhen,
        deactivates: deactivates,
        stateLabels: stateLabels,
        itemLabels: itemLabels,
        searchTerms: searchTerms,
        countsTowardActive: countsTowardActive,
        order: order,
        extension: extension,
        extra: extra,
      );

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais. Une entrée
  /// sans clé ou sans état lisible est écartée (`null`) : elle n'aurait pas
  /// d'identité stable à laquelle rattacher une règle.
  static ZChatToolEntry? fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String? key = zJsonStringOrNull(map['key']);
    final ZChatToolState? state = ZChatToolState.fromJson(map['state']);
    if (key == null || state == null) return null;
    return ZChatToolEntry(
      key: key,
      state: state,
      label: zJsonStringOrNull(map['label']),
      iconKey: zJsonStringOrNull(map['icon_key']),
      sectionKey: zJsonStringOrNull(map['section_key']),
      prominence: ZChatToolProminence.fromJson(map['prominence']),
      revealedBy: zJsonStringOrNull(map['revealed_by']),
      disabledWhen: zJsonDecodeList<ZChatToolRule>(
            map['disabled_when'],
            ZChatToolRule.fromJson,
          ) ??
          const <ZChatToolRule>[],
      deactivates: zJsonStringList(map['deactivates']) ?? const <String>[],
      stateLabels: _readLabels(map['state_labels']),
      itemLabels: _readLabels(map['item_labels']),
      searchTerms: zJsonStringList(map['search_terms']) ?? const <String>[],
      countsTowardActive: zJsonBool(map['counts_toward_active'], true),
      order: zJsonInt(map['order'], 0),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'state': state.toJson(),
        if (label != null) 'label': label,
        if (iconKey != null) 'icon_key': iconKey,
        if (sectionKey != null) 'section_key': sectionKey,
        if (prominence != ZChatToolProminence.auto)
          'prominence': prominence.jsonValue,
        if (revealedBy != null) 'revealed_by': revealedBy,
        if (disabledWhen.isNotEmpty)
          'disabled_when': <Map<String, dynamic>>[
            for (final ZChatToolRule r in disabledWhen) r.toJson(),
          ],
        if (deactivates.isNotEmpty) 'deactivates': deactivates,
        if (stateLabels.isNotEmpty) 'state_labels': stateLabels,
        if (itemLabels.isNotEmpty) 'item_labels': itemLabels,
        if (searchTerms.isNotEmpty) 'search_terms': searchTerms,
        if (!countsTowardActive) 'counts_toward_active': false,
        if (order != 0) 'order': order,
        if (extension != null) 'extension': extension!.toJson(),
        if (extra.isNotEmpty) 'extra': extra,
      };

  @override
  String toString() => 'ZChatToolEntry($key, $state, $prominence)';
}

Map<String, String> _readLabels(Object? raw) {
  final Map<String, dynamic>? map = zJsonMap(raw);
  if (map == null) return const <String, String>{};
  return <String, String>{
    for (final MapEntry<String, dynamic> e in map.entries)
      if (e.value is String) e.key: e.value as String,
  };
}

List<String> _keys(Iterable<String> raw) {
  final List<String> out = <String>[];
  for (final String k in raw) {
    final String t = k.trim();
    if (t.isEmpty || out.contains(t)) continue;
    out.add(t);
  }
  return out;
}
