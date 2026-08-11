/// Carte **OUVERTE** de fin de réponse — `ZChatResponseMetadata`.
///
/// ## Le client reçoit des VERDICTS, il n'en calcule AUCUN
///
/// Un backend de génération calcule côté serveur des signaux de qualité
/// (scores de fidélité et de complétude, statut de vérification des
/// citations, statut de couverture documentaire) puis les joint à
/// l'événement terminal du flux, aux côtés de métriques d'exécution
/// (durée, agents appelés, coût, tokens) et, le cas échéant, d'une liste de
/// fiches de fraîcheur des sources.
///
/// ⇒ Le socle ne **note** rien, ne **vérifie** aucune citation, ne **calcule**
/// aucun score : il **transporte** des verdicts sans les perdre ni les inventer.
/// Toute règle d'agrégation vit déjà dans `ZChatResponseConfidence`,
/// **câblée ici, jamais redéclarée**.
///
/// ## Carte OUVERTE, jamais un enregistrement figé (invariant AD-4)
///
/// Seules les clés d'un contrat serveur connu sont typées. Tout le reste —
/// clés futures, clés d'un autre backend, clé présente dans un état interne
/// du serveur mais non retenue dans l'événement final — traverse
/// **verbatim** par [extra] et ressort intact au `toJson`. Une API publique
/// zcrud est irréversible : figer ici un enregistrement fermé condamnerait
/// le socle à un fork à chaque évolution du serveur.
///
/// ## Absence POSSIBLE de TOUT champ (invariant AD-10)
///
/// Deux causes **indiscernables du point de vue du client**, et c'est voulu :
/// 1. le backend n'a **aucun** contrat de ce type (il n'émet même pas
///    d'événement structuré — cf. l'entête de `z_chat_stream_event.dart`) ;
/// 2. le backend a le code **écrit mais inerte** — une fonctionnalité
///    désactivée par configuration serveur n'écrit simplement pas sa clé.
///
/// Dans les deux cas la clé est **absente**, et la réponse du socle est la
/// même : `null` / liste vide, **jamais une valeur fabriquée**. C'est la leçon
/// déjà payée par `zChatQuotaFromMetadata` : un instantané de quota à zéro se
/// lit « épuisé » et **bloque l'utilisateur** d'un déploiement où le quota est
/// simplement désactivé.
///
/// De la même façon, [confidence] rend `null` — et **pas** un agrégat vide dont
/// `level` vaudrait `toVerify` — quand le serveur n'a émis aucun signal : un
/// « à vérifier » est un **verdict**, et l'afficher sur un backend muet serait
/// exactement l'invention que ce contrat interdit — pas de signal du tout
/// signifie n'afficher aucun indicateur.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_response_confidence.dart';
import '../z_chat_source_freshness.dart';

/// Clés de **confiance** reconnues par un backend de référence —
/// l'ensemble EXACT, ni plus ni moins.
///
/// Rien n'est ajouté « au cas où » : cinq des sept codes d'erreur reconnus
/// ailleurs dans ce paquet n'existent dans **aucun** backend, et c'est
/// précisément le motif à ne pas reproduire. Ce qui n'est pas listé ici n'est
/// pas nié : il traverse par [ZChatResponseMetadata.extra].
const Set<String> kZChatConfidenceMetadataKeys = <String>{
  'faithfulness_score',
  'completeness_score',
  'quality_grade',
  'citation_guard_status',
  'citations_verified',
  'citations_rejected',
  'coverage_status',
};

/// Clés **typées** par [ZChatResponseMetadata] — tout le reste va dans
/// [ZChatResponseMetadata.extra].
const Set<String> kZChatResponseMetadataKnownKeys = <String>{
  'duration_ms',
  'agents_called',
  'cost_total_usd',
  'tokens_total',
  'source_freshness',
  // Comptes de sources : absents du flux serveur (ils se dérivent des
  // drapeaux de vérification des sources côté client), mais présents dans
  // la forme PERSISTÉE de `ZChatResponseConfidence` — donc reconnus ici
  // pour que l'aller-retour `toJson`/`fromJson` soit sans perte.
  'verified_source_count',
  'total_source_count',
  ...kZChatConfidenceMetadataKeys,
};

/// Métadonnées de **fin de réponse**, immuables et **ouvertes**.
///
/// Portées par l'événement terminal du flux (`ZChatDoneEvent.responseMetadata`).
/// Chaque champ typé est **absent possible** ; [extra] garantit qu'aucune clé
/// inconnue n'est jetée.
class ZChatResponseMetadata {
  /// Construit une carte (immuable, `const`).
  const ZChatResponseMetadata({
    this.durationMs,
    this.agentsCalled = const <String>[],
    this.costTotalUsd,
    this.tokensTotal,
    this.confidence,
    this.sourceFreshness = const <ZChatSourceFreshness>[],
    this.extra = const <String, dynamic>{},
  });

  /// Carte **vide** : le serveur n'a rien dit. Aucun champ fabriqué.
  static const ZChatResponseMetadata empty = ZChatResponseMetadata();

  /// Durée serveur de la génération, en millisecondes (`duration_ms`).
  ///
  /// `null` = non communiqué ; **jamais** `0`, qui se lirait « instantané ».
  final int? durationMs;

  /// Agents/outils appelés côté serveur (`agents_called`).
  ///
  /// Liste vide = non communiqué **ou** aucun agent : le serveur ne distingue
  /// pas les deux, le socle ne le prétend donc pas non plus.
  final List<String> agentsCalled;

  /// Coût total facturé de la génération, en USD (`cost_total_usd`).
  ///
  /// `null` = non communiqué ; distinct de `0.0` (« gratuit »).
  final double? costTotalUsd;

  /// Jetons totaux consommés (`tokens_total`). `null` = non communiqué.
  final int? tokensTotal;

  /// Agrégat de confiance **CÂBLÉ** sur `ZChatResponseConfidence`.
  ///
  /// `null` quand le serveur n'a émis **aucun** signal exploitable — un palier
  /// de confiance est un verdict, et le socle n'en fabrique pas.
  final ZChatResponseConfidence? confidence;

  /// Fiches de fraîcheur **CÂBLÉES** sur `ZChatSourceFreshness`,
  /// une par dataset cité distinct.
  final List<ZChatSourceFreshness> sourceFreshness;

  /// Toute clé **non typée** de la carte, **verbatim**.
  ///
  /// C'est ce qui rend le modèle survivable à l'évolution du serveur : une note
  /// inconnue est **préservée**, jamais jetée.
  final Map<String, dynamic> extra;

  /// `true` si la carte ne porte **rien** — ni champ typé, ni clé inconnue.
  bool get isEmpty =>
      durationMs == null &&
      agentsCalled.isEmpty &&
      costTotalUsd == null &&
      tokensTotal == null &&
      confidence == null &&
      sourceFreshness.isEmpty &&
      extra.isEmpty;

  /// `true` si la carte porte au moins un élément.
  bool get isNotEmpty => !isEmpty;

  /// Décode **défensivement** (AD-10) — **ne lève jamais**.
  ///
  /// - [raw] non-`Map` (ou absent) ⇒ [empty] ;
  /// - un champ au **mauvais type** est traité comme absent : il n'emporte
  ///   jamais le parent (un `duration_ms: "beaucoup"` laisse le reste de la
  ///   carte intact) ;
  /// - une **note inconnue** est conservée dans [extra].
  ///
  /// [verifiedSourceCount]/[totalSourceCount] sont fournis par l'appelant, qui
  /// seul connaît les sources du message (le serveur ne les émet pas dans
  /// l'événement terminal : ils se dérivent des drapeaux de vérification
  /// côté client). Laissés à `null`, ils sont relus de la carte (forme
  /// persistée), ce qui rend l'aller-retour sans perte.
  static ZChatResponseMetadata fromJson(
    Object? raw, {
    int? verifiedSourceCount,
    int? totalSourceCount,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return empty;

    final int verified =
        verifiedSourceCount ?? zJsonInt(map['verified_source_count'], 0);
    final int total = totalSourceCount ?? zJsonInt(map['total_source_count'], 0);

    // CÂBLAGE, pas redéclaration : `ZChatResponseConfidence.fromJson` lit
    // déjà EXACTEMENT les clés snake_case attendues de l'événement terminal.
    // On lui passe la carte telle quelle, augmentée des seuls comptes de
    // sources.
    final ZChatResponseConfidence? candidate = ZChatResponseConfidence.fromJson(
      <String, dynamic>{
        ...map,
        'verified_source_count': verified,
        'total_source_count': total,
      },
    );
    // Aucun signal ⇒ AUCUN agrégat : `level` vaudrait `toVerify`, qui est un
    // verdict, et le socle n'en invente pas.
    final ZChatResponseConfidence? confidence =
        (candidate == null || candidate.hasNoSignal) ? null : candidate;

    return ZChatResponseMetadata(
      durationMs: zJsonIntOrNull(map['duration_ms']),
      agentsCalled:
          zJsonStringList(map['agents_called']) ?? const <String>[],
      costTotalUsd: zJsonDoubleOrNull(map['cost_total_usd']),
      tokensTotal: zJsonIntOrNull(map['tokens_total']),
      confidence: confidence,
      sourceFreshness:
          zJsonDecodeList<ZChatSourceFreshness>(
            map['source_freshness'],
            ZChatSourceFreshness.fromJson,
          ) ??
          const <ZChatSourceFreshness>[],
      // NORMALISATION **EAGER** à l'ENTRÉE (invariant AD-9) : `extra` ne porte
      // jamais les clés de sync réservées — elles relèvent du store, pas de
      // l'entité. Même patron que `ZChatConversation.fromJson`.
      extra: zSanitizeExtra(map, _reservedKeys),
    );
  }

  /// Clés **jamais** reversées dans [extra] : les clés typées de cette carte,
  /// **plus** `ZSyncMeta.reservedKeys` (invariant AD-9 — `updated_at`,
  /// `is_deleted`).
  static final Set<String> _reservedKeys = <String>{
    ...kZChatResponseMetadataKnownKeys,
    ...ZSyncMeta.reservedKeys,
  };

  /// Sérialise **à plat**, en clés snake_case — la forme attendue d'un
  /// événement terminal de flux.
  ///
  /// [extra] est écrit **en premier** : une clé typée reste la source de
  /// vérité si un appelant a construit une instance incohérente à la main.
  /// Aucun champ absent n'est émis (pas de `0` ni de `false` de complaisance).
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...extra,
    if (durationMs != null) 'duration_ms': durationMs,
    if (agentsCalled.isNotEmpty) 'agents_called': List<String>.of(agentsCalled),
    if (costTotalUsd != null) 'cost_total_usd': costTotalUsd,
    if (tokensTotal != null) 'tokens_total': tokensTotal,
    if (confidence != null) ...confidence!.toJson(),
    if (sourceFreshness.isNotEmpty)
      'source_freshness': <Map<String, dynamic>>[
        for (final ZChatSourceFreshness f in sourceFreshness) f.toJson(),
      ],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatResponseMetadata &&
          durationMs == other.durationMs &&
          zListEquals(agentsCalled, other.agentsCalled) &&
          costTotalUsd == other.costTotalUsd &&
          tokensTotal == other.tokensTotal &&
          confidence == other.confidence &&
          zListEquals(sourceFreshness, other.sourceFreshness) &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    durationMs,
    zListHash(agentsCalled),
    costTotalUsd,
    tokensTotal,
    confidence,
    zListHash(sourceFreshness),
    zJsonHash(extra),
  );

  @override
  String toString() =>
      'ZChatResponseMetadata(durationMs: $durationMs, agents: '
      '${agentsCalled.length}, confidence: ${confidence?.level}, '
      'freshness: ${sourceFreshness.length}, extra: ${extra.length})';
}
