/// Provenance d'une réponse d'assistant — `ZChatSource` (invariants AD-4,
/// AD-10).
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
  'corpus_key',
  'usage_status',
};

/// Une source citée/consultée par l'assistant — **une seule classe concrète**.
///
/// ## Pourquoi une classe, là où un domaine métier voudrait des sous-types
///
/// Un domaine spécialisé (juridique, douanier, médical…) décline volontiers
/// sa provenance en une famille fermée de variantes propres à son métier.
/// Ce vocabulaire n'a rien de générique : le figer dans un socle partagé
/// imposerait ce métier à tous les hôtes. Ce qui **est** générique, c'est la
/// **forme commune** — les quelques champs stables qu'une source cite quel
/// que soit le domaine.
///
/// ⇒ Les variantes propres à un métier restent **atteignables**, branchées
/// par l'app via `ZSourceRegistry.register('tec', fromJson: …, toJson: …)`
/// (invariant AD-4, mécanisme 3) : leurs champs propres transitent par
/// [payload], et le codec de l'hôte les reconstruit. **Aucun second registre
/// n'est créé** — `ZSourceRegistry` existe déjà et sert le même axe (la
/// provenance).
///
/// ## Fail-safe
///
/// [isVerified] et [usageStatus] adoptent la posture la plus prudente : en
/// l'absence de signal, on ne présume **jamais** « vérifié ».
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
    this.corpusKey,
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

  /// **Libellé** du corpus d'origine — texte d'affichage, traduisible.
  ///
  /// **Jamais une clé.** Confronter ce champ à une portée demandée
  /// (`ZChatCorpusScope`) reviendrait à comparer un libellé à un identifiant :
  /// la comparaison passerait quand les deux se ressemblent et échouerait dès
  /// qu'un hôte traduit son interface. Utiliser [corpusKey].
  final String? corpus;

  /// **Clé stable** du corpus d'origine — l'autre moitié du
  /// bouclage lecture/écriture.
  ///
  /// Une requête de génération sans portée documentaire **et** une source
  /// qui ne porte qu'un libellé partagent le même défaut : même en ajoutant
  /// un champ de restriction, aucune restriction n'aurait été **vérifiable**,
  /// faute de pouvoir confronter les sources rendues à la portée demandée.
  /// Ce champ est ce qui rend `ZChatCorpusScope.audit` possible.
  ///
  /// Opaque et **ouvert** : le socle ne connaît aucune valeur (les codes
  /// documentaires appartiennent aux hôtes). `null` ⇒ source non attribuée —
  /// ce qui, sous une portée restrictive, compte fail-safe comme une
  /// **violation** et non comme une conformité présumée.
  final String? corpusKey;

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

  /// **Fail-safe** : `true` **uniquement** si [verificationStatus] vaut
  /// exactement `'verified'`.
  ///
  /// `null` / `'not_applicable'` / `'pass-through'` ⇒ `false`. Le drapeau
  /// [verified] n'est **pas** consulté : le choix est délibéré (« ne jamais
  /// présumer vérifié en l'absence de signal »). Le remplacer par
  /// `verified == true` ferait passer pour ancrée une source qui ne l'est pas.
  bool get isVerified => verificationStatus == 'verified';

  /// Statut d'usage typé — défaut [ZChatSourceUsageStatus.cited] quand
  /// [usageStatusRaw] est absent ou illisible.
  ///
  /// Une règle métier qui déduirait automatiquement « connaissance générale »
  /// d'une valeur de [sourceType] propre à un domaine n'est **pas** portée :
  /// elle reposerait sur un vocabulaire que le socle ne connaît pas. Un hôte
  /// l'obtient en persistant explicitement `usage_status: 'generalKnowledge'`.
  ZChatSourceUsageStatus get usageStatus =>
      ZChatSourceUsageStatus.fromJson(usageStatusRaw) ??
      ZChatSourceUsageStatus.cited;

  /// Décode **défensivement** une source (invariant AD-10) — ne lève jamais.
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
    // `tryCodecFor`, jamais `codecFor` (qui lève sur un kind non enregistré).
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
      corpusKey: zJsonStringOrNull(map['corpus_key']),
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
      if (corpusKey != null) 'corpus_key': corpusKey,
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
          corpusKey == other.corpusKey &&
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
        corpusKey,
        usageStatusRaw,
        zJsonHash(payload),
      );

  @override
  String toString() =>
      'ZChatSource(sourceType: $sourceType, displayText: $displayText)';
}
