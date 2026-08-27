/// **Le vocabulaire des mentions** — ce qu'un déclencheur reconnaît, ce qu'un
/// candidat porte, et par quel port l'hôte fournit ses candidats.
///
/// Domaine PUR (aucun Flutter, aucun libellé, aucune icône, aucune couleur).
///
/// ## Les trois règles normatives portées par ce fichier
///
/// 1. **Le socle ne résout aucun candidat.** Fichiers, agents, connecteurs,
///    documents : ce sont des données d'hôte. Le socle transporte un
///    [ZChatMentionSource] et n'embarque aucun annuaire, aucun index, aucune
///    heuristique de classement. Sans source déclarée, un déclencheur reconnu
///    ne propose **rien** — et ne lève pas.
/// 2. **Le déclencheur est déclaré, jamais présumé.** Aucun caractère n'est
///    codé en dur : `@`, `/`, `#` ou toute autre amorce est une donnée de
///    l'hôte ([ZChatMentionTrigger.character]). Ce que le socle apporte est la
///    **reconnaissance** — [ZChatMentionTrigger.matchIn], une analyse de texte
///    pure et testable — pas le choix de l'amorce.
/// 3. **Le socle ne nomme rien** (FR-26). [ZChatMentionCandidate.label],
///    [ZChatMentionCandidate.sublabel] et les jetons d'icône, de nature et de
///    raison sont fournis **déjà localisés** par l'hôte. Le socle produit des
///    jetons opaques, l'hôte produit du texte.
library;

import 'package:zcrud_core/domain.dart';

/// Un **candidat de mention** : une identité stable, de quoi la rendre, et la
/// charge utile que l'hôte se remettra à lui-même.
///
/// Le socle ne fabrique jamais de candidat et n'en filtre aucun : il en
/// transporte la liste telle que le [ZChatMentionSource] l'a rendue.
class ZChatMentionCandidate {
  /// Construit un candidat.
  ZChatMentionCandidate({
    required this.key,
    this.label,
    this.sublabel,
    this.iconKey,
    this.kindKey,
    this.insertText,
    this.disabledReasonToken,
    this.order = 0,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = zSanitizeExtra(extra, _reservedKeys);

  /// Identité **stable et opaque** du candidat, telle que l'hôte la connaît.
  /// C'est la seule donnée que le socle rendra à l'hôte pour qu'il agisse.
  final String key;

  /// Libellé **déjà localisé par l'hôte**. `null` signifie absent — le socle
  /// n'en fabrique aucun, et n'affiche jamais [key] à la place.
  final String? label;

  /// Second libellé d'hôte (chemin, rôle, provenance…). `null` ⇒ absent.
  final String? sublabel;

  /// Clé d'icône **opaque**, résolue par l'hôte au rendu. `null` ⇒ aucune
  /// icône déclarée ; le socle ne dessine rien de son propre chef.
  final String? iconKey;

  /// Jeton **opaque** de nature (fichier, agent, connecteur…). Ce n'est pas un
  /// enum : la liste des natures appartient à l'hôte et lui seul.
  final String? kindKey;

  /// Texte à insérer dans la saisie quand le candidat est retenu. `null`
  /// signifie **non déclaré** : le socle n'invente aucune forme de jeton
  /// (ni `@key`, ni `[label](key)`), c'est l'hôte qui décide de l'insertion.
  final String? insertText;

  /// Jeton **opaque** de raison d'indisponibilité. `null` ⇒ candidat
  /// sélectionnable. Un candidat indisponible est **rendu avec sa raison**,
  /// jamais masqué : une absence sans explication ne renseigne personne.
  final String? disabledReasonToken;

  /// `true` si le candidat est sélectionnable.
  bool get isEnabled => disabledReasonToken == null;

  /// Rang souhaité (croissant) ; à égalité, l'ordre rendu par la source
  /// décide. Le socle ne réordonne jamais de lui-même.
  final int order;

  /// Slot d'extension typé versionné (invariant AD-4).
  final ZExtension? extension;

  /// **Charge utile d'hôte**, libre et immuable (invariant AD-4) : ce que
  /// l'hôte veut retrouver intact quand le candidat lui revient.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) et les
  /// clés propres du candidat (`key`, `label`, `icon_key`…) en sont
  /// **retirées**, quelle que soit la voie d'écriture : elles ne sont ni
  /// conservées ni réémises par [toJson].
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  // Slot brut, lu uniquement par l'accesseur `extra`.
  final Map<String, dynamic> _extra;

  // Clés propres émises par `toJson` ∪ clés de sync hors-entité (AD-9).
  static const Set<String> _reservedKeys = <String>{
    'key',
    'label',
    'sublabel',
    'icon_key',
    'kind_key',
    'insert_text',
    'disabled_reason_token',
    'order',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais. Un candidat
  /// sans clé lisible est écarté (`null`) : sans identité stable, l'hôte ne
  /// saurait pas à quoi la sélection se rapporte.
  static ZChatMentionCandidate? fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String? key = zJsonStringOrNull(map['key']);
    if (key == null) return null;
    return ZChatMentionCandidate(
      key: key,
      label: zJsonStringOrNull(map['label']),
      sublabel: zJsonStringOrNull(map['sublabel']),
      iconKey: zJsonStringOrNull(map['icon_key']),
      kindKey: zJsonStringOrNull(map['kind_key']),
      insertText: zJsonStringOrNull(map['insert_text']),
      disabledReasonToken: zJsonStringOrNull(map['disabled_reason_token']),
      order: zJsonInt(map['order'], 0),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    if (label != null) 'label': label,
    if (sublabel != null) 'sublabel': sublabel,
    if (iconKey != null) 'icon_key': iconKey,
    if (kindKey != null) 'kind_key': kindKey,
    if (insertText != null) 'insert_text': insertText,
    if (disabledReasonToken != null)
      'disabled_reason_token': disabledReasonToken,
    if (order != 0) 'order': order,
    if (extension != null) 'extension': extension!.toJson(),
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  String toString() => 'ZChatMentionCandidate($key, kind: $kindKey)';
}

/// Un **déclencheur de mention** déclaré : l'amorce qui ouvre un panneau, et
/// les conditions qui font qu'elle est reconnue.
///
/// Un déclencheur ne connaît **pas** ses candidats : il nomme la source qui
/// les rendra ([sourceKey]) et s'arrête là.
class ZChatMentionTrigger {
  /// Construit un déclencheur.
  ///
  /// [character] est l'amorce **déclarée par l'hôte** ; une amorce vide ou
  /// entièrement blanche rend le déclencheur [isDeclared] `false`, et
  /// [matchIn] ne reconnaît alors plus rien — plutôt que de lever, ou de
  /// retomber sur une amorce inventée par le socle.
  ZChatMentionTrigger({
    required String character,
    this.sourceKey,
    int minQueryLength = 0,
    this.maxCandidates,
    this.allowsWhitespace = false,
    this.requiresLeadingBoundary = true,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : character = character.trim(),
       minQueryLength = minQueryLength < 0 ? 0 : minQueryLength,
       _extra = zSanitizeExtra(extra, _reservedKeys);

  /// L'amorce, rognée. Aucune valeur par défaut : `@` et `/` sont des choix
  /// d'hôte, pas des constantes du socle (FR-26).
  final String character;

  /// Clé **opaque** de la source interrogée. `null` ⇒ l'hôte décide au montage
  /// quelle source répond.
  final String? sourceKey;

  /// Longueur minimale de la requête avant que le panneau soit jugé prêt
  /// ([ZChatMentionMatch.isReady]). Une valeur négative est ramenée à `0`.
  final int minQueryLength;

  /// Plafond souhaité de candidats rendus. `null` ⇒ aucun plafond déclaré ;
  /// le socle ne tronque jamais de lui-même une liste rendue par la source.
  final int? maxCandidates;

  /// `true` si la requête peut contenir des blancs (cas d'une commande suivie
  /// de ses arguments). `false` ⇒ la requête s'arrête au premier blanc.
  final bool allowsWhitespace;

  /// `true` si l'amorce n'est reconnue qu'en **début de mot** (début du texte
  /// ou blanc juste avant). C'est ce qui empêche une adresse de courriel
  /// d'ouvrir un panneau de mentions.
  final bool requiresLeadingBoundary;

  /// `true` si l'hôte a effectivement déclaré une amorce exploitable.
  bool get isDeclared => character.isNotEmpty;

  /// Slot d'extension typé versionné (invariant AD-4).
  final ZExtension? extension;

  /// Données d'hôte libres (invariant AD-4), immuables.
  ///
  /// Les clés réservées de synchronisation (`ZSyncMeta.reservedKeys`) et les
  /// clés propres du déclencheur en sont **retirées**, quelle que soit la voie
  /// d'écriture.
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  final Map<String, dynamic> _extra;

  static const Set<String> _reservedKeys = <String>{
    'character',
    'source_key',
    'min_query_length',
    'max_candidates',
    'allows_whitespace',
    'requires_leading_boundary',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Reconnaît l'amorce dans [text] à la position du curseur [caretOffset].
  ///
  /// Analyse **pure** : elle lit le texte, elle ne consulte aucune source et
  /// ne propose aucun candidat. Rend `null` — sans jamais lever — quand :
  /// * le déclencheur n'est pas [isDeclared] ;
  /// * [caretOffset] tombe hors de `[0, text.length]` ;
  /// * aucune amorce n'ouvre le mot courant ;
  /// * l'amorce est reconnue mais [requiresLeadingBoundary] n'est pas honorée ;
  /// * la requête contient un blanc alors que [allowsWhitespace] est `false`.
  ZChatMentionMatch? matchIn(String text, int caretOffset) {
    if (!isDeclared) return null;
    if (caretOffset < 0 || caretOffset > text.length) return null;
    final String head = text.substring(0, caretOffset);
    final int start = head.lastIndexOf(character);
    if (start < 0) return null;
    if (requiresLeadingBoundary && start > 0) {
      final String before = head.substring(start - 1, start);
      if (before.trim().isNotEmpty) return null;
    }
    final String query = head.substring(start + character.length);
    if (!allowsWhitespace && query.contains(RegExp(r'\s'))) return null;
    return ZChatMentionMatch(
      trigger: this,
      query: query,
      start: start,
      end: caretOffset,
    );
  }

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais. Un
  /// déclencheur sans amorce lisible est écarté (`null`).
  static ZChatMentionTrigger? fromJson(
    Object? raw, {
    ZExtension? Function(Map<String, dynamic> json)? extensionParser,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String character = zJsonString(map['character']).trim();
    if (character.isEmpty) return null;
    return ZChatMentionTrigger(
      character: character,
      sourceKey: zJsonStringOrNull(map['source_key']),
      minQueryLength: zJsonInt(map['min_query_length'], 0),
      maxCandidates: zJsonIntOrNull(map['max_candidates']),
      allowsWhitespace: zJsonBool(map['allows_whitespace'], false),
      requiresLeadingBoundary: zJsonBool(map['requires_leading_boundary'], true),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: zJsonMap(map['extra']) ?? const <String, dynamic>{},
    );
  }

  /// Sérialise en clés `snake_case` ; les champs par défaut sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'character': character,
    if (sourceKey != null) 'source_key': sourceKey,
    if (minQueryLength != 0) 'min_query_length': minQueryLength,
    if (maxCandidates != null) 'max_candidates': maxCandidates,
    if (allowsWhitespace) 'allows_whitespace': true,
    if (!requiresLeadingBoundary) 'requires_leading_boundary': false,
    if (extension != null) 'extension': extension!.toJson(),
    if (extra.isNotEmpty) 'extra': extra,
  };

  @override
  String toString() => 'ZChatMentionTrigger($character -> $sourceKey)';
}

/// Ce que la reconnaissance d'un déclencheur a établi sur le texte : rien de
/// plus, rien de moins.
///
/// C'est une **lecture**, pas une décision : elle ne dit ni quoi proposer, ni
/// quoi insérer, ni s'il faut ouvrir un panneau.
class ZChatMentionMatch {
  /// Construit un résultat de reconnaissance.
  const ZChatMentionMatch({
    required this.trigger,
    required this.query,
    required this.start,
    required this.end,
  });

  /// Le déclencheur reconnu.
  final ZChatMentionTrigger trigger;

  /// Le texte saisi **après** l'amorce, jusqu'au curseur. Peut être vide.
  final String query;

  /// Décalage de l'amorce dans le texte (inclus).
  final int start;

  /// Décalage du curseur (exclu) — borne haute du segment à remplacer.
  final int end;

  /// `true` si la requête atteint [ZChatMentionTrigger.minQueryLength].
  ///
  /// C'est un **constat de longueur**, pas un ordre d'affichage : l'hôte reste
  /// libre d'ouvrir son panneau quand il l'entend.
  bool get isReady => query.length >= trigger.minQueryLength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatMentionMatch &&
          identical(trigger, other.trigger) &&
          query == other.query &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(identityHashCode(trigger), query, start, end);

  @override
  String toString() => 'ZChatMentionMatch("$query", $start..$end)';
}

/// Le port par lequel l'hôte **fournit** ses candidats.
///
/// Le socle n'en implémente aucun de fond : il n'a ni index de fichiers, ni
/// annuaire d'agents, ni catalogue de connecteurs, et n'en aura pas.
abstract interface class ZChatMentionSource {
  /// Rend les candidats correspondant à [match].
  ///
  /// `Right` d'une liste vide signifie « rien à proposer » — un cas normal,
  /// distinct d'un `Left`, qui signale une panne de la source.
  Future<ZResult<List<ZChatMentionCandidate>>> candidates(
    ZChatMentionMatch match,
  );
}

/// Source **inerte** : elle ne propose jamais rien et n'échoue jamais.
///
/// C'est le défaut d'un déclencheur dont l'hôte n'a branché aucune source :
/// le panneau reste vide, la saisie continue, rien ne lève.
class ZChatEmptyMentionSource implements ZChatMentionSource {
  /// Construit la source inerte.
  const ZChatEmptyMentionSource();

  @override
  Future<ZResult<List<ZChatMentionCandidate>>> candidates(
    ZChatMentionMatch match,
  ) async =>
      const Right<ZFailure, List<ZChatMentionCandidate>>(
        <ZChatMentionCandidate>[],
      );
}

/// Annuaire **de transport** des sources déclarées par l'hôte, indexées par la
/// clé que porte un déclencheur.
///
/// Il ne résout aucun candidat : il rend la source, ou l'inerte. Une clé
/// inconnue — ou absente — n'est jamais une erreur, parce qu'un hôte a le
/// droit de déclarer un déclencheur avant d'avoir branché sa source.
class ZChatMentionSources {
  /// Construit l'annuaire. Les entrées sont copiées et rendues immuables.
  ZChatMentionSources([
    Map<String, ZChatMentionSource> sources =
        const <String, ZChatMentionSource>{},
  ]) : _sources = Map<String, ZChatMentionSource>.unmodifiable(sources);

  final Map<String, ZChatMentionSource> _sources;

  /// Les clés déclarées.
  Iterable<String> get keys => _sources.keys;

  /// La source de [key], ou [ZChatEmptyMentionSource] si elle est inconnue.
  /// [key] `null` (déclencheur sans source nommée) rend aussi l'inerte.
  ZChatMentionSource sourceFor(String? key) =>
      _sources[key] ?? const ZChatEmptyMentionSource();

  /// La source du déclencheur [trigger], ou l'inerte.
  ZChatMentionSource sourceForTrigger(ZChatMentionTrigger trigger) =>
      sourceFor(trigger.sourceKey);
}
