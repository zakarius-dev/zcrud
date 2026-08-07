/// **Porteur de réglages** neutre — `ZChatGenerationSettings` (lot β,
/// AD-4/AD-10).
///
/// ## Le manque mesuré : le porteur, pas le widget
///
/// L'étude CR-IFFD-72 (§ 4.3) a établi que les réglages du chat sont **déjà
/// modélisés** dans ce paquet mais atteignables par **un seul canal étroit** —
/// la capture de closure de l'hôte, `send()` n'ayant aucun paramètre. Et un
/// défaut structurel : `ZChatRegenerateAction` ne portait que `{messageId}`
/// alors que [ZChatLengthBias] est défini comme « biais d'une **régénération** »
/// — donc **inatteignable sur son propre cas d'usage**.
///
/// Ce porteur regroupe les réglages en **une valeur transportable**, la même
/// sur la requête et sur la régénération. C'est ce qui ferme le défaut ③.
///
/// ## 🔴 Aucun enum réinventé — RÉFÉRENCE, jamais redéclaration
///
/// | Réglage | Type porté | Déclaré où |
/// |---|---|---|
/// | Verbosité | `ZChatResponseLength` | `z_chat_enums.dart` (CHAT-0) |
/// | Biais de régénération | `ZChatLengthBias` | `z_chat_enums.dart` (CHAT-0) |
/// | Budget de calcul `1..5` | `ZChatComputeEffort` | `z_chat_compute_effort.dart` (CHAT-1) |
/// | Étapes de raisonnement | `bool?` [revealThinkingSteps] | pendant, côté DEMANDE, de `ZChatThinkingStep` (côté réponse) |
/// | Recherche web | `bool?` [webSearch] | ce fichier (lot K1) — cf. « typé vs clé ouverte » |
/// | Capacités d'hôte | `Map<String, bool>` [capabilities] | ce fichier (lot K1) — canal OUVERT (AD-4) |
///
/// ## Typé vs clé ouverte — le critère est MESURÉ, pas décrété (lot K1)
///
/// [webSearch] est **typé** pour la même raison que `computeEffort` l'a été :
/// c'est la capacité booléenne que les DEUX backends lisent réellement —
/// lex l'envoie en `enable_web_search`
/// (`lex_data/lib/data/datasources/remote/chat_remote_data_source.dart:333`,
/// `:369`, `:429`) et IFFD en `enableWebSearch`
/// (`iffd/lib/src/data/repositories/iffd_ai_repository_impl.dart:701`, `:756`).
/// Une capacité partagée et vivante mérite un nom que le compilateur vérifie.
///
/// Tout le reste — « résumé » (IFFD seul, couplé au flux documents), scraping,
/// génération d'images, interpréteur (code MORT commenté chez IFFD) — passe par
/// [capabilities], le canal **ouvert** : des clés opaques `String`, jamais un
/// enum fermé (AD-4). Une app future ajoute « brouillon long » sans toucher le
/// kernel ; le socle n'en connaît **aucune valeur** (FR-26).
///
/// ## 🔴 Jamais de repli muet — la capacité non honorée est DÉTECTABLE
///
/// Une clé ouverte qu'un port ne comprend pas ne doit pas mourir en silence :
/// [auditCapabilities] confronte l'**écho** des clés honorées par l'exécuteur
/// aux clés exprimées ici, et **nomme** les muettes — le pendant exact de
/// `ZChatCorpusScope.audit` (cf. `z_chat_capability_audit.dart`).
///
/// Le risque n°1 nommé par la revue était « reconstruire la moitié du kernel » :
/// ce fichier ne déclare **aucun** type de réglage, il les compose.
///
/// ## Pourquoi une PROJECTION, et non un second jeu de champs
///
/// `ZChatGenerationRequest` porte **déjà** `responseLength`, `lengthBias` et
/// `computeEffort` en champs de premier niveau — et la garde **G16/CHAT-1b**
/// exige qu'ils y restent, littéralement, pour que les deux axes (verbosité vs
/// calcul) demeurent non confondables sur la requête. Y ajouter un porteur
/// **redondant** aurait créé deux sources de vérité et « deux lectures
/// conformes mais incompatibles » — exactement ce que la lentille adversariale
/// traque.
///
/// ⇒ Sur la requête, le porteur est une **vue** : `request.settings` le
/// projette, `request.withSettings(…)` l'injecte, et le tour est une
/// **bijection** (garde du lot). Sur `ZChatRegenerateAction`, où il n'existait
/// rien, il est **stocké**.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_enums.dart';
import 'z_chat_capability_audit.dart';
import 'z_chat_compute_effort.dart';

/// Clé **canonique** de la recherche web dans le vocabulaire des capacités.
///
/// C'est sous cette clé que le champ typé [ZChatGenerationSettings.webSearch]
/// apparaît en persistance, dans [ZChatGenerationSettings.expressedCapabilityKeys]
/// et dans l'écho attendu par [ZChatGenerationSettings.auditCapabilities] : un
/// hôte qui l'écrit dans le canal ouvert et un hôte qui remplit le champ typé
/// expriment la **même** demande (le décodage la re-canonicalise vers le champ
/// typé — une seule lecture possible).
const String kZChatCapabilityWebSearch = 'web_search';

/// Réglages de génération transportables — immuable, `==`/`hashCode` par
/// valeur.
///
/// **Tout est nullable, et `null` signifie « l'hôte décide »** — jamais un
/// défaut inventé par le socle. Un porteur entièrement nul ([isEmpty]) laisse
/// le comportement strictement inchangé.
class ZChatGenerationSettings {
  /// Construit un porteur de réglages (immuable, `const`).
  ///
  /// ⚠️ Constructeur `const` ⇒ [capabilities] est stockée **verbatim** (aucune
  /// normalisation possible ici). L'écriture **canonique** de la recherche web
  /// est le champ typé [webSearch] ; une entrée [kZChatCapabilityWebSearch]
  /// dans le canal ouvert reste néanmoins comprise partout ([capability],
  /// [expressedCapabilityKeys], `==`, [toJson], [auditCapabilities]) avec une
  /// priorité UNIQUE et documentée : **champ typé d'abord** — jamais deux
  /// lectures possibles.
  const ZChatGenerationSettings({
    this.responseLength,
    this.lengthBias,
    this.computeEffort,
    this.revealThinkingSteps,
    this.webSearch,
    this.capabilities = const <String, bool>{},
  });

  /// Longueur attendue — enum **EXISTANT** `ZChatResponseLength`.
  final ZChatResponseLength? responseLength;

  /// Biais de longueur d'une régénération — enum **EXISTANT**
  /// `ZChatLengthBias`.
  final ZChatLengthBias? lengthBias;

  /// Budget de calcul `1..5` — type **EXISTANT** `ZChatComputeEffort`. Axe
  /// ORTHOGONAL à [responseLength] : les deux ne se substituent jamais.
  final ZChatComputeEffort? computeEffort;

  /// Demande d'**exposer les étapes de raisonnement** (`ZChatThinkingStep`) au
  /// fil de la réponse. `null` ⇒ l'hôte décide ; c'est le pendant, côté
  /// demande, d'un type qui n'existait jusqu'ici que côté réponse.
  final bool? revealThinkingSteps;

  /// Demande d'activer (`true`) ou de **couper** (`false`) la recherche web,
  /// ou `null` (l'hôte décide) — lot K1.
  ///
  /// Champ **typé** parce que mesuré vivant chez les DEUX hôtes (cf. l'entête,
  /// « typé vs clé ouverte ») ; clé canonique [kZChatCapabilityWebSearch] en
  /// persistance et dans l'audit.
  final bool? webSearch;

  /// Canal **OUVERT** de capacités booléennes d'hôte (AD-4) — lot K1.
  ///
  /// Clés opaques `String`, choisies par l'hôte (« résumé », « brouillon
  /// long »…), **jamais** un enum fermé : une app future étend sans toucher le
  /// kernel. `true` demande la capacité, `false` demande son **absence**
  /// (les deux exigent d'être honorées), clé absente ⇒ l'hôte décide.
  ///
  /// 🔴 Une clé exprimée ici n'est **pas** une garantie : c'est
  /// [auditCapabilities] qui rend son honneur vérifiable — sans ce bouclage le
  /// canal ne serait qu'un vœu (même règle que la portée de corpus).
  final Map<String, bool> capabilities;

  /// `true` si aucun réglage n'est exprimé — le porteur est alors **sans
  /// effet** et une requête qui le reçoit est identique à une requête sans.
  bool get isEmpty =>
      responseLength == null &&
      lengthBias == null &&
      computeEffort == null &&
      revealThinkingSteps == null &&
      webSearch == null &&
      capabilities.isEmpty;

  /// Valeur exprimée pour la capacité [key], ou `null` (non exprimée).
  ///
  /// Lecture **unique** quel que soit le canal d'écriture : pour
  /// [kZChatCapabilityWebSearch], le champ typé [webSearch] prime, puis le
  /// canal ouvert. La clé interrogée est rognée ([key] blanche ⇒ `null`).
  bool? capability(String key) {
    final String? normalized = _normalizeCapabilityKey(key);
    if (normalized == null) return null;
    if (normalized == kZChatCapabilityWebSearch) {
      return webSearch ?? _lookup(capabilities, normalized);
    }
    return _lookup(capabilities, normalized);
  }

  /// Clés de **toutes** les capacités exprimées, canoniques (rognées,
  /// dédupliquées, ordonnées) — [webSearch] y figure sous
  /// [kZChatCapabilityWebSearch]. C'est l'ensemble que [auditCapabilities]
  /// confronte à l'écho.
  List<String> get expressedCapabilityKeys => List<String>.unmodifiable(
        _canonicalCapabilities(this).keys,
      );

  /// 🔴 **Le bouclage anti-repli-muet** : confronte l'écho des clés
  /// [honored] — celles que l'exécuteur déclare avoir comprises et
  /// appliquées — aux capacités exprimées par CE porteur, et **nomme** les
  /// muettes ([ZChatCapabilityAudit.unhonored]).
  ///
  /// Fail-safe : une clé exprimée absente de l'écho est **non honorée** —
  /// en l'absence de signal on ne présume jamais « honoré » (pendant exact de
  /// `ZChatCorpusScope.audit`, cf. `z_chat_capability_audit.dart` pour la
  /// provenance de l'écho). Ne filtre rien, ne lève rien (AD-10).
  ZChatCapabilityAudit auditCapabilities(Iterable<String> honored) {
    final List<String> requested = expressedCapabilityKeys;
    final Set<String> echo = <String>{
      for (final String key in honored)
        if (_normalizeCapabilityKey(key) != null) _normalizeCapabilityKey(key)!,
    };
    final List<String> honoredKeys = <String>[
      for (final String key in requested)
        if (echo.contains(key)) key,
    ];
    final List<String> unhonored = <String>[
      for (final String key in requested)
        if (!echo.contains(key)) key,
    ];
    final List<String> unrequested = (echo.toList()..sort())
        .where((String key) => !requested.contains(key))
        .toList();
    return ZChatCapabilityAudit(
      requested: requested,
      honored: honoredKeys,
      unhonored: unhonored,
      unrequested: unrequested,
    );
  }

  /// `true` si au moins un réglage est exprimé.
  bool get isNotEmpty => !isEmpty;

  /// Copie modifiée — les paramètres omis sont **conservés** (même forme que
  /// `ZChatThinkingStep.copyWith`).
  ///
  /// ⚠️ **Ce membre ne peut pas RETIRER un réglage** : passer `null` est
  /// indistinguable d'un paramètre omis. Pour revenir à « l'hôte décide », on
  /// **construit** la valeur — les quatre champs sont optionnels, donc
  /// `ZChatGenerationSettings(responseLength: s.responseLength)` suffit.
  ///
  /// 🔴 Les drapeaux `clear*` de lex (`ToolsContext.copyWith`) ne sont pas
  /// portés : `clearComputeEffort` heurterait la garde **G16**, qui n'autorise
  /// pour `Effort` que les deux orthographes exactes `ZChatComputeEffort` et
  /// `computeEffort` — précisément pour qu'aucune famille d'orthographes
  /// voisines ne se glisse à côté de l'axe qu'elle protège. Le contournement
  /// aurait été de la renommer ; on préfère un membre plus étroit.
  ZChatGenerationSettings copyWith({
    ZChatResponseLength? responseLength,
    ZChatLengthBias? lengthBias,
    ZChatComputeEffort? computeEffort,
    bool? revealThinkingSteps,
    bool? webSearch,
    Map<String, bool>? capabilities,
  }) =>
      ZChatGenerationSettings(
        responseLength: responseLength ?? this.responseLength,
        lengthBias: lengthBias ?? this.lengthBias,
        computeEffort: computeEffort ?? this.computeEffort,
        revealThinkingSteps: revealThinkingSteps ?? this.revealThinkingSteps,
        webSearch: webSearch ?? this.webSearch,
        capabilities: capabilities ?? this.capabilities,
      );

  /// Décode **défensivement** (AD-10) — ne lève jamais ; `raw` non-`Map` ⇒
  /// `null`, valeur illisible ⇒ réglage absent (« l'hôte décide »), **jamais**
  /// un palier inventé.
  ///
  /// ⚠️ [responseLength] et [lengthBias] ont des `fromJson` **totaux** (repli
  /// `standard` / `asIs`) : appliquer ce repli à une clé **absente**
  /// transformerait « non réglé » en « réglé au défaut ». La clé est donc
  /// testée avant d'être décodée.
  /// Valeur portée pour la recherche web par un canal ouvert **brut** (clé
  /// [kZChatCapabilityWebSearch], clés tolérées non rognées), ou `null`.
  ///
  /// Utilisé par `ZChatGenerationRequest` pour **canonicaliser à l'entrée** —
  /// le constructeur de la requête n'étant pas `const`, il peut faire ce que
  /// celui-ci ne peut pas.
  static bool? hoistedWebSearch(Map<String, bool> capabilities) =>
      _lookup(capabilities, kZChatCapabilityWebSearch);

  /// Forme **canonique** d'un canal ouvert brut : clés rognées, vides
  /// écartées, dédupliquées, triées, et **sans** la clé réservée
  /// [kZChatCapabilityWebSearch] (elle vit dans le champ typé).
  static Map<String, bool> sanitizeCapabilities(
    Map<String, bool> capabilities,
  ) {
    final Map<String, bool> canonical = _canonicalCapabilities(
      ZChatGenerationSettings(capabilities: capabilities),
    )..remove(kZChatCapabilityWebSearch);
    return canonical;
  }

  static ZChatGenerationSettings? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    // Canal ouvert : seules les valeurs strictement booléennes sont retenues ;
    // une entrée illisible est SAUTÉE (AD-10 : capacité absente, jamais un
    // `false` inventé — `false` est une DEMANDE, pas une absence). La clé
    // réservée est re-canonicalisée vers le champ typé (une seule lecture).
    final Map<String, bool> decoded = _decodeCapabilities(map['capabilities']);
    final bool? hoisted = decoded.remove(kZChatCapabilityWebSearch);
    return ZChatGenerationSettings(
      responseLength: map.containsKey('response_length')
          ? ZChatResponseLength.fromJson(map['response_length'])
          : null,
      lengthBias: map.containsKey('length_bias')
          ? ZChatLengthBias.fromJson(map['length_bias'])
          : null,
      computeEffort: ZChatComputeEffort.fromJson(map['compute_effort']),
      revealThinkingSteps: zJsonBoolOrNull(map['reveal_thinking_steps']),
      webSearch: zJsonBoolOrNull(map[kZChatCapabilityWebSearch]) ?? hoisted,
      capabilities: Map<String, bool>.unmodifiable(decoded),
    );
  }

  /// Sérialise en clés snake_case ; un réglage non exprimé est **omis** (et
  /// non écrit `null`), pour qu'un round-trip conserve « l'hôte décide ».
  ///
  /// La forme émise est **canonique** : la recherche web sort toujours en clé
  /// [kZChatCapabilityWebSearch] de premier niveau (quel que soit le canal
  /// d'écriture), et `capabilities` ne la contient jamais — deux écritures de
  /// la même demande produisent le **même** document.
  Map<String, dynamic> toJson() {
    final Map<String, bool> canonical = _canonicalCapabilities(this);
    final bool? web = canonical.remove(kZChatCapabilityWebSearch);
    return <String, dynamic>{
      if (responseLength != null) 'response_length': responseLength!.jsonValue,
      if (lengthBias != null) 'length_bias': lengthBias!.jsonValue,
      if (computeEffort != null) 'compute_effort': computeEffort!.toJson(),
      if (revealThinkingSteps != null)
        'reveal_thinking_steps': revealThinkingSteps,
      kZChatCapabilityWebSearch: ?web,
      if (canonical.isNotEmpty) 'capabilities': canonical,
    };
  }

  /// `==` par valeur, sur la forme **canonique** des capacités : deux porteurs
  /// qui expriment la même demande sont égaux quel que soit le canal
  /// d'écriture de la recherche web et l'ordre des clés du canal ouvert. Un
  /// porteur ancien (sans les champs du lot K1) compare **à l'identique**.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatGenerationSettings &&
          responseLength == other.responseLength &&
          lengthBias == other.lengthBias &&
          computeEffort == other.computeEffort &&
          revealThinkingSteps == other.revealThinkingSteps &&
          zJsonEquals(_canonicalCapabilities(this),
              _canonicalCapabilities(other));

  @override
  int get hashCode => Object.hash(
        responseLength,
        lengthBias,
        computeEffort,
        revealThinkingSteps,
        zJsonHash(_canonicalCapabilities(this)),
      );

  @override
  String toString() => 'ZChatGenerationSettings(responseLength: '
      '$responseLength, lengthBias: $lengthBias, '
      'computeEffort: $computeEffort, '
      'revealThinkingSteps: $revealThinkingSteps, '
      'webSearch: $webSearch, capabilities: ${capabilities.length})';
}

/// Rogne une clé de capacité ; blanche ⇒ `null` (une chaîne vide n'est pas une
/// clé) — même règle que la normalisation des clés de corpus.
String? _normalizeCapabilityKey(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Lecture d'une entrée du canal ouvert, tolérante aux clés non rognées
/// (le constructeur `const` ne peut pas normaliser à l'entrée).
bool? _lookup(Map<String, bool> capabilities, String normalizedKey) {
  for (final MapEntry<String, bool> entry in capabilities.entries) {
    if (_normalizeCapabilityKey(entry.key) == normalizedKey) return entry.value;
  }
  return null;
}

/// Projection **canonique** des capacités d'un porteur : clés rognées,
/// vides écartées, ordre trié, et la recherche web sous
/// [kZChatCapabilityWebSearch] — champ typé prioritaire sur le canal ouvert.
/// C'est la forme sur laquelle `==`, `hashCode`, [ZChatGenerationSettings.toJson]
/// et l'audit s'accordent : une seule lecture possible.
Map<String, bool> _canonicalCapabilities(ZChatGenerationSettings settings) {
  final Map<String, bool> out = <String, bool>{};
  for (final MapEntry<String, bool> entry in settings.capabilities.entries) {
    final String? key = _normalizeCapabilityKey(entry.key);
    if (key == null) continue;
    out.putIfAbsent(key, () => entry.value);
  }
  if (settings.webSearch != null) {
    out[kZChatCapabilityWebSearch] = settings.webSearch!;
  }
  final List<String> keys = out.keys.toList()..sort();
  return <String, bool>{for (final String key in keys) key: out[key]!};
}

/// Décode le canal ouvert **défensivement** (AD-10) : non-`Map` ⇒ vide ; une
/// valeur non booléenne est sautée (jamais convertie) ; clés rognées,
/// dédupliquées (première occurrence gagne), triées.
Map<String, bool> _decodeCapabilities(Object? raw) {
  final Map<String, dynamic>? map = zJsonMap(raw);
  if (map == null) return <String, bool>{};
  final Map<String, bool> out = <String, bool>{};
  for (final MapEntry<String, dynamic> entry in map.entries) {
    final String? key = _normalizeCapabilityKey(entry.key);
    final Object? value = entry.value;
    if (key == null || value is! bool) continue;
    out.putIfAbsent(key, () => value);
  }
  final List<String> keys = out.keys.toList()..sort();
  return <String, bool>{for (final String key in keys) key: out[key]!};
}
