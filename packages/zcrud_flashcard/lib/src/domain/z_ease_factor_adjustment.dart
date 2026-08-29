/// Stratégie d'ajustement du facteur de facilité (`easeFactor`).
///
/// Pur-Dart, immuable, `const` : aucun état, aucune E/S, aucune horloge. La
/// stratégie ne décide QUE de la variation du facteur de facilité ; le
/// bornage aux deux bornes de la configuration (`minEaseFactor`,
/// `maxEaseFactor`) reste la responsabilité du planificateur, jamais de la
/// stratégie — un clamp appliqué deux fois masquerait une stratégie qui
/// déborde.
library;

import 'z_srs_config.dart';

/// Clé de discrimination de la forme sérialisée.
const String _kindKey = 'kind';

/// Valeur de [_kindKey] pour la stratégie canonique.
const String _canonicalKind = 'canonical';

/// Valeur de [_kindKey] pour la stratégie tabulée.
const String _tableKind = 'table';

/// Clé de la table de deltas (clés de qualité en chaînes).
const String _deltaByQualityKey = 'delta_by_quality';

/// Clé du drapeau de pénalisation des échecs.
const String _penalizeLapseKey = 'penalize_lapse';

/// Comment le facteur de facilité varie à chaque révision.
///
/// Deux stratégies sont fournies :
/// - [ZEaseFactorAdjustment.canonical] — la formule SuperMemo-2 historique,
///   qui est le **défaut** de [ZSrsConfig] : une application qui ne déclare
///   rien obtient exactement la courbe d'avant l'existence de ce point
///   d'extension ;
/// - [ZEaseFactorAdjustment.table] — un **delta additif par qualité**, déclaré
///   par l'application.
///
/// ## Contrat de [apply]
///
/// [apply] rend le facteur de facilité **brut** (non borné) correspondant à
/// [current] après une révision notée [quality]. L'appelant borne ensuite le
/// résultat à `[ZSrsConfig.minEaseFactor, ZSrsConfig.maxEaseFactor]` —
/// le planificateur SuperMemo-2 par défaut (`ZSm2Scheduler`) le fait
/// systématiquement.
///
/// [quality] est ramenée sur l'échelle déclarée par [config]
/// (`ZSrsConfig.clampQuality`) avant tout calcul : une note aberrante venue
/// d'un port d'évaluation est dégradée, jamais rejetée par une exception.
///
/// ## Implémenter sa propre stratégie
///
/// Ce type n'est pas scellé : une application peut l'implémenter. Elle doit
/// alors rendre [toMap] sérialisable et accepter que [fromMap] — qui ne
/// connaît que les deux formes livrées ici — replie sa forme inconnue sur la
/// stratégie canonique. Une application qui persiste une stratégie maison
/// fournit donc sa propre relecture.
abstract class ZEaseFactorAdjustment {
  /// Constructeur `const` pour les implémentations.
  const ZEaseFactorAdjustment();

  /// Formule SuperMemo-2 canonique :
  /// `EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))`.
  ///
  /// C'est le défaut de [ZSrsConfig]. Le sommet `5` de la formule est
  /// intrinsèque à SuperMemo-2, pas un réglage : [ZSrsConfig] épingle
  /// `maxQuality == 5` par assertion, la configuration ne peut donc pas
  /// diverger de la formule.
  const factory ZEaseFactorAdjustment.canonical() =
      ZCanonicalEaseFactorAdjustment;

  /// Delta **additif** par qualité, déclaré par l'application.
  ///
  /// Voir [ZTableEaseFactorAdjustment] pour le contrat détaillé (qualité
  /// absente de la table, `penalizeLapse`).
  const factory ZEaseFactorAdjustment.table({
    required Map<int, double> deltaByQuality,
    bool penalizeLapse,
  }) = ZTableEaseFactorAdjustment;

  /// Relit une stratégie persistée — **tolérante** (invariant AD-10).
  ///
  /// Replie sur [ZEaseFactorAdjustment.canonical] dès que la forme n'est pas
  /// reconnue : [map] nul, discriminant absent, discriminant inconnu, table
  /// absente ou illisible. Une stratégie corrompue en base fait donc réviser
  /// l'apprenant avec la courbe canonique — jamais planter une session.
  ///
  /// Forme attendue : `{'kind': 'canonical'}` ou
  /// `{'kind': 'table', 'delta_by_quality': {'0': -0.2, …},
  /// 'penalize_lapse': true}` — les clés de la table sont des **chaînes**
  /// (contrainte JSON), relues par `int.tryParse` ; une entrée illisible est
  /// ignorée, jamais fatale.
  static ZEaseFactorAdjustment fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ZEaseFactorAdjustment.canonical();
    final kind = map[_kindKey];
    if (kind is! String || kind != _tableKind) {
      // Inconnu, absent ou explicitement canonique : même repli.
      return const ZEaseFactorAdjustment.canonical();
    }
    final raw = map[_deltaByQualityKey];
    if (raw is! Map) return const ZEaseFactorAdjustment.canonical();

    final deltas = <int, double>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final q = key is int ? key : int.tryParse('$key');
      if (q == null) continue; // Clé illisible : ignorée, jamais fatale.
      final value = entry.value;
      if (value is num) deltas[q] = value.toDouble();
    }
    if (deltas.isEmpty) return const ZEaseFactorAdjustment.canonical();

    final penalize = map[_penalizeLapseKey];
    return ZEaseFactorAdjustment.table(
      deltaByQuality: deltas,
      // Toute valeur non booléenne (absente, chaîne, nombre) retombe sur le
      // défaut `true` — la stratégie pénalise, comme la canonique.
      penalizeLapse: penalize is bool ? penalize : true,
    );
  }

  /// Facteur de facilité **brut** (non borné) après une révision notée
  /// [quality] depuis [current]. Voir le contrat en tête de classe.
  double apply(double current, int quality, ZSrsConfig config);

  /// Forme sérialisable, relisible par [fromMap].
  Map<String, dynamic> toMap();
}

/// Formule SuperMemo-2 canonique — voir [ZEaseFactorAdjustment.canonical].
class ZCanonicalEaseFactorAdjustment extends ZEaseFactorAdjustment {
  /// Construit la stratégie canonique (sans paramètre : la formule n'en a
  /// aucun).
  const ZCanonicalEaseFactorAdjustment();

  @override
  double apply(double current, int quality, ZSrsConfig config) {
    final q = config.clampQuality(quality);
    // Formule SuperMemo-2, écrite ICI et nulle part ailleurs : le
    // planificateur la lit sur la stratégie. L'ordre des opérations est
    // celui d'origine — toute réécriture « équivalente » décalerait les
    // derniers bits du résultat.
    return current + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{_kindKey: _canonicalKind};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ZCanonicalEaseFactorAdjustment;

  @override
  int get hashCode => _canonicalKind.hashCode;
}

/// Delta **additif** par qualité — voir [ZEaseFactorAdjustment.table].
///
/// ## Contrat
///
/// - une qualité **absente** de [deltaByQuality] laisse le facteur de
///   facilité **inchangé** (delta `0.0`) : la table n'a pas à être totale ;
/// - [penalizeLapse] `false` ⇒ **aucune** variation du facteur de facilité
///   quand `quality < ZSrsConfig.passThreshold`, quelle que soit la table.
///   C'est la différence de fond avec la formule canonique, qui recalcule le
///   facteur de facilité même sur un échec ;
/// - aucune valeur de delta n'est fournie par ce paquet : la table est une
///   **donnée de l'application**, pas un défaut du socle. Une application qui
///   ne veut pas la déclarer garde la stratégie canonique.
///
/// Exemple d'échelle 0..5 (valeurs illustratives, à décider par
/// l'application) : `{0: -0.3, 1: -0.3, 2: -0.15, 3: 0.0, 4: 0.05, 5: 0.1}`.
///
/// [deltaByQuality] est traitée comme **immuable** : la muter après
/// construction rendrait la stratégie non déterministe. Passer une `const`
/// map, ou une copie.
class ZTableEaseFactorAdjustment extends ZEaseFactorAdjustment {
  /// Construit une stratégie tabulée à partir de [deltaByQuality].
  const ZTableEaseFactorAdjustment({
    required this.deltaByQuality,
    this.penalizeLapse = true,
  });

  /// Variation additive du facteur de facilité, par qualité. Une qualité
  /// absente vaut `0.0` (aucune variation).
  final Map<int, double> deltaByQuality;

  /// Si `false`, une révision sous `ZSrsConfig.passThreshold` laisse le
  /// facteur de facilité strictement inchangé (défaut `true` : la table
  /// s'applique à toutes les qualités).
  final bool penalizeLapse;

  @override
  double apply(double current, int quality, ZSrsConfig config) {
    final q = config.clampQuality(quality);
    // Le drapeau prime sur la table : `penalizeLapse: false` neutralise même
    // un delta déclaré sous le seuil, sinon les deux réglages se
    // contrediraient en silence.
    if (!penalizeLapse && q < config.passThreshold) return current;
    return current + (deltaByQuality[q] ?? 0.0);
  }

  @override
  Map<String, dynamic> toMap() => <String, dynamic>{
        _kindKey: _tableKind,
        // Clés en chaînes : une clé entière n'est pas représentable en JSON.
        _deltaByQualityKey: <String, dynamic>{
          for (final entry in deltaByQuality.entries)
            '${entry.key}': entry.value,
        },
        _penalizeLapseKey: penalizeLapse,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTableEaseFactorAdjustment &&
          penalizeLapse == other.penalizeLapse &&
          _sameDeltas(deltaByQuality, other.deltaByQuality);

  @override
  int get hashCode => Object.hash(
        penalizeLapse,
        Object.hashAllUnordered(<Object>[
          for (final entry in deltaByQuality.entries)
            Object.hash(entry.key, entry.value),
        ]),
      );
}

/// Égalité de deux tables de deltas (comparaison par contenu, jamais par
/// identité de `Map`).
bool _sameDeltas(Map<int, double> a, Map<int, double> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
