/// Provenance d'une réponse d'assistant — `ZChatSource` (AD-4, AD-10).
///
/// origine: lex_core (module « Assistant ») — `chat_source.dart:17-115`.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_enums.dart';

/// Clé persistée du discriminant de provenance.
const String kZChatSourceTypeKey = 'source_type';

/// Clés de la **forme commune** — tout le reste tombe dans [ZChatSource.payload].
const Set<String> _kCommonKeys = <String>{
  kZChatSourceTypeKey,
  'display_text',
  'relevance_score',
  'verified',
  'verification_status',
  'snippet',
  'breadcrumb',
  'ranker',
  'corpus',
  'usage_status',
};

/// Une source citée/consultée par l'assistant — **une seule classe concrète**.
///
/// ## Pourquoi une classe, là où lex a une `sealed` à 14 sous-types
///
/// lex décline `ChatSource` en 14 variantes **douanières**
/// (`CodeDesDouanesSource`, `TecSource`, `ShSource`, `ValuationToolSource`,
/// `ConventionSource`, `RegulationSource`…). Ce vocabulaire n'a rien de
/// générique : le figer dans un socle éducatif partagé imposerait la douane à
/// IFFD et à DODLP. Ce qui **est** générique, c'est la **forme commune** —
/// exactement les 10 champs que lex déclare sur la base (`chat_source.dart:18-65`).
///
/// ⇒ Les 14 sous-types restent **atteignables**, branchés par l'app via
/// `ZSourceRegistry.register('tec', fromJson: …, toJson: …)` (AD-4 pt.3) :
/// leurs champs propres transitent par [payload], et le codec de l'hôte les
/// reconstruit. **Aucun second registre n'est créé** — `ZSourceRegistry` existe
/// déjà et sert le même axe (la provenance).
///
/// ## Fail-safe (porté à l'identique)
///
/// [isVerified] et [usageStatus] reproduisent les règles de lex, **y compris
/// leur prudence** : en l'absence de signal, on ne présume **jamais** « vérifié ».
class ZChatSource {
  /// Construit une source (immuable, `const`).
  const ZChatSource({
    this.sourceType = '',
    this.displayText = '',
    this.relevanceScore = 0.0,
    this.verified,
    this.verificationStatus,
    this.snippet,
    this.breadcrumb,
    this.ranker,
    this.corpus,
    this.usageStatusRaw,
    this.payload = const <String, dynamic>{},
  });

  /// Discriminant **ouvert** de provenance (`'tec'`, `'article'`, `'web'`…).
  ///
  /// Volontairement une `String` et non un enum : c'est la clé de lookup du
  /// [ZSourceRegistry], et fermer cet ensemble reviendrait à interdire aux
  /// hôtes leurs propres provenances.
  final String sourceType;

  /// Libellé lisible de la source.
  final String displayText;

  /// Score de pertinence (défaut `0.0`).
  final double relevanceScore;

  /// Drapeau brut `verified` du backend — **jamais** l'autorité de vérification
  /// (cf. [isVerified]).
  final bool? verified;

  /// Statut de vérification brut (`'verified'`, `'not_applicable'`,
  /// `'pass-through'`, ou `null`).
  final String? verificationStatus;

  /// Extrait littéral de la source, si exposé.
  final String? snippet;

  /// Chemin hiérarchique lisible (« Partie I > Chapitre 2 > Section 3 »).
  final String? breadcrumb;

  /// Outil/ranker ayant récupéré la source.
  final String? ranker;

  /// Libellé du corpus d'origine.
  final String? corpus;

  /// Statut d'usage **brut** — conservé tel quel pour un round-trip sans perte
  /// même si la valeur est inconnue du cœur (cf. [usageStatus] pour la version
  /// typée).
  final String? usageStatusRaw;

  /// Reste de la map, **verbatim** — ou reconstruit par le codec de
  /// [ZSourceRegistry] quand [sourceType] y est enregistré.
  ///
  /// C'est le canal par lequel les champs propres d'un sous-type d'hôte
  /// (`code_id`, `node_number`, `tec_id`…) survivent au round-trip **sans que
  /// le cœur ait à les connaître**.
  final Map<String, dynamic> payload;

  /// 🔴 **Fail-safe** : `true` **uniquement** si [verificationStatus] vaut
  /// exactement `'verified'`.
  ///
  /// `null` / `'not_applicable'` / `'pass-through'` ⇒ `false`. Le drapeau
  /// [verified] n'est **PAS** consulté : porté de `chat_source.dart:70`, où le
  /// choix est explicite (« ne jamais présumer vérifié en l'absence de
  /// signal »). ⛔ Le remplacer par `verified == true` ferait passer pour
  /// ancrée une source qui ne l'est pas — garde **G9**.
  bool get isVerified => verificationStatus == 'verified';

  /// Statut d'usage typé — défaut [ZChatSourceUsageStatus.cited] quand
  /// [usageStatusRaw] est absent ou illisible (porté de `chat_source.dart:76-89`).
  ///
  /// ⚠️ La règle douanière de lex (`sourceType == lexiaKnowledge` ⇒
  /// `generalKnowledge`) n'est **pas** portée : elle repose sur une valeur de
  /// `SourceType` propre à ce domaine. Un hôte l'obtient en persistant
  /// explicitement `usage_status: 'generalKnowledge'`.
  ZChatSourceUsageStatus get usageStatus =>
      ZChatSourceUsageStatus.fromJson(usageStatusRaw) ??
      ZChatSourceUsageStatus.cited;

  /// Décode **défensivement** une source (AD-10) — ne lève jamais.
  ///
  /// - [raw] non-`Map` ⇒ `null` ;
  /// - champs absents/mal typés ⇒ défauts sûrs ;
  /// - [sourceType] **enregistré** dans [registry] ⇒ [payload] reconstruit par
  ///   le codec de l'app (un codec qui lève est absorbé : repli sur le reste de
  ///   la map, **verbatim**) ;
  /// - [sourceType] inconnu ⇒ [payload] = reste de la map, **verbatim**.
  static ZChatSource? fromJson(Object? raw, {ZSourceRegistry? registry}) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String sourceType = zJsonString(map[kZChatSourceTypeKey]);
    final Map<String, dynamic> rest = <String, dynamic>{
      for (final MapEntry<String, dynamic> e in map.entries)
        if (!_kCommonKeys.contains(e.key)) e.key: e.value,
    };
    // 🔴 `tryCodecFor`, jamais `codecFor` (qui lève sur un kind non enregistré).
    final ZValueCodec? codec =
        sourceType.isEmpty ? null : registry?.tryCodecFor(sourceType);
    final Map<String, dynamic> payload = codec == null
        ? rest
        : (zJsonMap(zJsonGuard(() => codec.fromJson(map))) ?? rest);
    return ZChatSource(
      sourceType: sourceType,
      displayText: zJsonString(map['display_text']),
      relevanceScore: zJsonDouble(map['relevance_score'], 0.0),
      verified: zJsonBoolOrNull(map['verified']),
      verificationStatus: zJsonStringOrNull(map['verification_status']),
      snippet: zJsonStringOrNull(map['snippet']),
      breadcrumb: zJsonStringOrNull(map['breadcrumb']),
      ranker: zJsonStringOrNull(map['ranker']),
      corpus: zJsonStringOrNull(map['corpus']),
      usageStatusRaw: zJsonStringOrNull(map['usage_status']),
      payload: Map<String, dynamic>.unmodifiable(payload),
    );
  }

  /// Sérialise en clés **snake_case**, [payload] étalé en premier (les champs
  /// de la forme commune font autorité en cas de collision).
  Map<String, dynamic> toJson({ZSourceRegistry? registry}) {
    final ZValueCodec? codec =
        sourceType.isEmpty ? null : registry?.tryCodecFor(sourceType);
    final Map<String, dynamic> body = codec == null
        ? payload
        : (zJsonGuard(() => codec.toJson(payload)) ?? payload);
    return <String, dynamic>{
      ...body,
      kZChatSourceTypeKey: sourceType,
      'display_text': displayText,
      'relevance_score': relevanceScore,
      if (verified != null) 'verified': verified,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (snippet != null) 'snippet': snippet,
      if (breadcrumb != null) 'breadcrumb': breadcrumb,
      if (ranker != null) 'ranker': ranker,
      if (corpus != null) 'corpus': corpus,
      if (usageStatusRaw != null) 'usage_status': usageStatusRaw,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSource &&
          sourceType == other.sourceType &&
          displayText == other.displayText &&
          relevanceScore == other.relevanceScore &&
          verified == other.verified &&
          verificationStatus == other.verificationStatus &&
          snippet == other.snippet &&
          breadcrumb == other.breadcrumb &&
          ranker == other.ranker &&
          corpus == other.corpus &&
          usageStatusRaw == other.usageStatusRaw &&
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(
        sourceType,
        displayText,
        relevanceScore,
        verified,
        verificationStatus,
        snippet,
        breadcrumb,
        ranker,
        corpus,
        usageStatusRaw,
        zJsonHash(payload),
      );

  @override
  String toString() =>
      'ZChatSource(sourceType: $sourceType, displayText: $displayText)';
}
