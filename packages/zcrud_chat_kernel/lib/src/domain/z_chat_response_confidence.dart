/// Confiance agrégée d'une réponse d'assistant — `ZChatResponseConfidence`.
///
/// origine: lex_core (module « Assistant ») — `response_confidence.dart:40-293`
/// (`ConfidenceFactor`, `ConfidenceThresholds`, `ResponseConfidence`).
///
/// ## Principe fail-safe — porté **à l'identique**, seuils **nommés**
///
/// La règle [ZChatResponseConfidence.level] est **déterministe et explicable** :
/// elle n'invente aucun signal, elle agrège ceux que le backend a déjà calculés.
/// Sa propriété centrale est la **prudence** : en l'absence de signal, ou sur
/// un signal dégradé, elle descend à [ZChatConfidenceLevel.toVerify].
/// **Jamais `high` par défaut.** Garde **G9**.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_enums.dart';

/// Seuils **nommés** de la règle de confiance (aucun littéral épars).
///
/// origine: `ConfidenceThresholds` (`response_confidence.dart:59-70`).
class ZChatConfidenceThresholds {
  const ZChatConfidenceThresholds._();

  /// Fidélité minimale pour prétendre à [ZChatConfidenceLevel.high].
  static const double faithfulnessHigh = 0.8;

  /// Complétude minimale pour prétendre à [ZChatConfidenceLevel.high].
  static const double completenessOk = 0.7;

  /// Nombre minimal de sources **vérifiées** pour [ZChatConfidenceLevel.high].
  static const int minVerifiedForHigh = 2;
}

/// Un facteur contributif **explicable** de la confiance.
///
/// [code] est un identifiant **stable** que l'hôte résout en libellé localisé —
/// le domaine ne porte aucun texte traduisible (AD-13/FR-26). [humanValue] est
/// une valeur factuelle **déjà formatée** et non traduisible (« 85 % », « 3 / 3 »).
class ZChatConfidenceFactor {
  /// Construit un facteur (immuable, `const`).
  const ZChatConfidenceFactor({
    required this.code,
    required this.humanValue,
    this.sense = ZChatConfidenceFactorSense.neutral,
  });

  /// Identifiant stable du facteur (`'faithfulness'`, `'citationGuard'`…).
  final String code;

  /// Valeur factuelle déjà formatée (non traduisible).
  final String humanValue;

  /// Sens du facteur pour la confiance.
  final ZChatConfidenceFactorSense sense;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZChatConfidenceFactor? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatConfidenceFactor(
      code: zJsonString(map['code']),
      humanValue: zJsonString(map['human_value']),
      sense: ZChatConfidenceFactorSense.fromJson(map['sense']),
    );
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'human_value': humanValue,
        'sense': sense.jsonValue,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatConfidenceFactor &&
          code == other.code &&
          humanValue == other.humanValue &&
          sense == other.sense;

  @override
  int get hashCode => Object.hash(code, humanValue, sense);

  @override
  String toString() => 'ZChatConfidenceFactor(code: $code, sense: $sense)';
}

/// Agrégat des signaux de grounding d'une réponse, immuable.
///
/// Tous les scores sont **nullables** : « non évalué » (`null`) et « évalué à
/// zéro » (`0.0`) sont deux faits distincts, et les confondre fausserait
/// [level].
class ZChatResponseConfidence {
  /// Construit un agrégat (immuable, `const`).
  const ZChatResponseConfidence({
    this.faithfulnessScore,
    this.completenessScore,
    this.qualityGrade,
    this.citationGuardStatus,
    this.citationsVerified,
    this.citationsRejected,
    this.coverageStatus,
    this.verifiedSourceCount = 0,
    this.totalSourceCount = 0,
  });

  /// Score de fidélité (`null` = non évalué).
  final double? faithfulnessScore;

  /// Score de complétude (`null` = non évalué).
  final double? completenessScore;

  /// Grade qualité brut (`'pass'`/`'fail'`/`'skipped'`/`null`).
  ///
  /// Volontairement une `String` **ouverte** : lex ne ferme pas cet ensemble,
  /// et fermer ici un vocabulaire de backend rendrait le socle cassant.
  final String? qualityGrade;

  /// Statut brut du garde-citations
  /// (`'ok'`/`'degraded'`/`'all_rejected'`/`'no_citations'`/`'error'`).
  final String? citationGuardStatus;

  /// Nombre de citations vérifiées, si connu.
  final int? citationsVerified;

  /// Nombre de citations rejetées, si connu.
  final int? citationsRejected;

  /// Statut brut de couverture
  /// (`'available'`/`'partial'`/`'unavailable'`/`'error'`).
  final String? coverageStatus;

  /// Nombre de sources vérifiées (défaut `0`).
  final int verifiedSourceCount;

  /// Nombre total de sources (défaut `0`).
  final int totalSourceCount;

  /// `true` si **aucun** signal exploitable n'est présent.
  bool get hasNoSignal =>
      faithfulnessScore == null &&
      completenessScore == null &&
      (qualityGrade == null || qualityGrade == 'skipped') &&
      citationGuardStatus == null &&
      coverageStatus == null &&
      totalSourceCount == 0;

  /// `true` si au moins une source n'est pas vérifiée.
  bool get hasUnverifiedSources =>
      totalSourceCount > 0 && verifiedSourceCount < totalSourceCount;

  /// 🔴 Palier de confiance **dérivé** — règle déterministe **fail-safe**
  /// (portée de `response_confidence.dart:148-190`).
  ///
  /// **Dégradations dures ⇒ [ZChatConfidenceLevel.toVerify]** :
  /// 1. garde-citations `degraded` / `all_rejected` / `error` ;
  /// 2. couverture `unavailable` / `partial` / `error` ;
  /// 3. des sources étaient attendues (`totalSourceCount > 0`) mais **aucune**
  ///    n'est vérifiée ;
  /// 4. les deux scores sont `null` **et** aucune source vérifiée ;
  /// 5. aucun signal du tout ([hasNoSignal]).
  ///
  /// **[ZChatConfidenceLevel.high] UNIQUEMENT si** garde `ok` **et**
  /// `verifiedSourceCount >= `[ZChatConfidenceThresholds.minVerifiedForHigh]
  /// **et** fidélité ≥ [ZChatConfidenceThresholds.faithfulnessHigh] **et**
  /// complétude ≥ [ZChatConfidenceThresholds.completenessOk].
  ///
  /// **[ZChatConfidenceLevel.moderate] sinon.** ⛔ Retirer l'une des
  /// dégradations dures ferait passer une réponse non ancrée pour fiable :
  /// c'est la régression exacte que la garde **G9** ré-injecte.
  ZChatConfidenceLevel get level {
    final String? guard = citationGuardStatus;
    final String? coverage = coverageStatus;

    if (guard == 'degraded' || guard == 'all_rejected' || guard == 'error') {
      return ZChatConfidenceLevel.toVerify;
    }
    if (coverage == 'unavailable' ||
        coverage == 'partial' ||
        coverage == 'error') {
      return ZChatConfidenceLevel.toVerify;
    }
    if (totalSourceCount > 0 && verifiedSourceCount == 0) {
      return ZChatConfidenceLevel.toVerify;
    }

    final double? f = faithfulnessScore;
    final double? c = completenessScore;

    final bool guardOk = guard == 'ok';
    final bool enoughVerified =
        verifiedSourceCount >= ZChatConfidenceThresholds.minVerifiedForHigh;
    final bool scoresHigh = f != null &&
        c != null &&
        f >= ZChatConfidenceThresholds.faithfulnessHigh &&
        c >= ZChatConfidenceThresholds.completenessOk;
    if (guardOk && enoughVerified && scoresHigh) {
      return ZChatConfidenceLevel.high;
    }

    if (f == null && c == null && verifiedSourceCount < 1) {
      return ZChatConfidenceLevel.toVerify;
    }
    if (hasNoSignal) return ZChatConfidenceLevel.toVerify;

    return ZChatConfidenceLevel.moderate;
  }

  /// Facteurs contributifs **explicables**, dans un ordre stable.
  ///
  /// Les libellés humains sont résolus par l'hôte depuis
  /// [ZChatConfidenceFactor.code] : le domaine ne traduit rien.
  List<ZChatConfidenceFactor> get factors {
    String pct(double v) => '${(v * 100).round()} %';

    final List<ZChatConfidenceFactor> list = <ZChatConfidenceFactor>[];

    final double? f = faithfulnessScore;
    list.add(ZChatConfidenceFactor(
      code: 'faithfulness',
      humanValue: f != null ? pct(f) : '—',
      sense: f == null
          ? ZChatConfidenceFactorSense.neutral
          : (f >= ZChatConfidenceThresholds.faithfulnessHigh
              ? ZChatConfidenceFactorSense.positive
              : ZChatConfidenceFactorSense.negative),
    ));

    final double? c = completenessScore;
    list.add(ZChatConfidenceFactor(
      code: 'completeness',
      humanValue: c != null ? pct(c) : '—',
      sense: c == null
          ? ZChatConfidenceFactorSense.neutral
          : (c >= ZChatConfidenceThresholds.completenessOk
              ? ZChatConfidenceFactorSense.positive
              : ZChatConfidenceFactorSense.negative),
    ));

    final String? guard = citationGuardStatus;
    list.add(ZChatConfidenceFactor(
      code: 'citationGuard',
      humanValue: guard ?? '—',
      sense: guard == 'ok'
          ? ZChatConfidenceFactorSense.positive
          : (guard == null
              ? ZChatConfidenceFactorSense.neutral
              : ZChatConfidenceFactorSense.negative),
    ));

    if (totalSourceCount > 0) {
      list.add(ZChatConfidenceFactor(
        code: 'verifiedSources',
        humanValue: '$verifiedSourceCount / $totalSourceCount',
        sense: verifiedSourceCount >=
                ZChatConfidenceThresholds.minVerifiedForHigh
            ? ZChatConfidenceFactorSense.positive
            : (verifiedSourceCount == 0
                ? ZChatConfidenceFactorSense.negative
                : ZChatConfidenceFactorSense.neutral),
      ));
    }

    final String? coverage = coverageStatus;
    if (coverage != null) {
      list.add(ZChatConfidenceFactor(
        code: 'coverage',
        humanValue: coverage,
        sense: coverage == 'available'
            ? ZChatConfidenceFactorSense.positive
            : ZChatConfidenceFactorSense.negative,
      ));
    }

    return List<ZChatConfidenceFactor>.unmodifiable(list);
  }

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZChatResponseConfidence? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatResponseConfidence(
      faithfulnessScore: zJsonDoubleOrNull(map['faithfulness_score']),
      completenessScore: zJsonDoubleOrNull(map['completeness_score']),
      qualityGrade: zJsonStringOrNull(map['quality_grade']),
      citationGuardStatus: zJsonStringOrNull(map['citation_guard_status']),
      citationsVerified: zJsonIntOrNull(map['citations_verified']),
      citationsRejected: zJsonIntOrNull(map['citations_rejected']),
      coverageStatus: zJsonStringOrNull(map['coverage_status']),
      verifiedSourceCount: zJsonInt(map['verified_source_count'], 0),
      totalSourceCount: zJsonInt(map['total_source_count'], 0),
    );
  }

  /// Sérialise en clés snake_case.
  ///
  /// ⚠️ Ni [level] ni [factors] ne sont persistés : ce sont des **dérivés** de
  /// la règle ci-dessus. Les figer permettrait à un document de contredire la
  /// règle — et donc d'afficher « confiance élevée » sur des signaux dégradés.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (faithfulnessScore != null) 'faithfulness_score': faithfulnessScore,
        if (completenessScore != null) 'completeness_score': completenessScore,
        if (qualityGrade != null) 'quality_grade': qualityGrade,
        if (citationGuardStatus != null)
          'citation_guard_status': citationGuardStatus,
        if (citationsVerified != null) 'citations_verified': citationsVerified,
        if (citationsRejected != null) 'citations_rejected': citationsRejected,
        if (coverageStatus != null) 'coverage_status': coverageStatus,
        'verified_source_count': verifiedSourceCount,
        'total_source_count': totalSourceCount,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatResponseConfidence &&
          faithfulnessScore == other.faithfulnessScore &&
          completenessScore == other.completenessScore &&
          qualityGrade == other.qualityGrade &&
          citationGuardStatus == other.citationGuardStatus &&
          citationsVerified == other.citationsVerified &&
          citationsRejected == other.citationsRejected &&
          coverageStatus == other.coverageStatus &&
          verifiedSourceCount == other.verifiedSourceCount &&
          totalSourceCount == other.totalSourceCount;

  @override
  int get hashCode => Object.hash(
        faithfulnessScore,
        completenessScore,
        qualityGrade,
        citationGuardStatus,
        citationsVerified,
        citationsRejected,
        coverageStatus,
        verifiedSourceCount,
        totalSourceCount,
      );

  @override
  String toString() => 'ZChatResponseConfidence(level: $level, '
      'verified: $verifiedSourceCount/$totalSourceCount)';
}
