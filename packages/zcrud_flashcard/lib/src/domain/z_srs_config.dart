/// Configuration `ZSrsConfig` — constantes SRS **injectables** (Story E9-2, AC5).
///
/// origine: lex_core (module « Étude ») — variante IFFD canonique (canonique
/// §2.1, l.75) : les constantes de l'algorithme de répétition espacée sont
/// **paramétrées**, jamais codées en dur dans le calcul (`Sm2`). Permet à une
/// app d'ajuster la courbe, et à un scheduler alternatif (FSRS/Leitner —
/// FR-17) de réutiliser/redéfinir ces bornes sans forker les modèles.
///
/// **Pur-Dart, immuable, `const`** (AD-14) : aucun état, aucune I/O. **Pas de
/// codegen** — ce n'est pas une entité persistée mais un paramétrage
/// d'algorithme. Injectée dans [ZSm2Scheduler].
library;

/// Paramètres immuables de l'algorithme de répétition espacée (SuperMemo-2 par
/// défaut). Toutes les constantes de [ZSm2Scheduler] sont lues depuis une
/// instance de cette classe (AC5 : aucune constante SM-2 en dur dans l'algo).
class ZSrsConfig {
  /// Construit une configuration SRS avec les défauts canoniques (variante
  /// IFFD). Tout paramètre peut être surchargé pour ajuster la courbe.
  const ZSrsConfig({
    this.minEaseFactor = 1.3,
    this.maxEaseFactor = 2.5,
    this.defaultEaseFactor = kDefaultEaseFactor,
    this.defaultIntervalModifier = 1.0,
    this.overdueBonusFactor = 0.5,
    this.passThreshold = 3,
  });

  /// Valeur canonique du facteur de facilité par défaut (`2.5`), exposée en
  /// `static const` : sert de défaut d'instance ([defaultEaseFactor]) ET de
  /// **repli de désérialisation** (défaut de persistance) à `ZRepetitionInfo`
  /// — une constante utilisable dans un contexte `const` (annotation codegen).
  static const double kDefaultEaseFactor = 2.5;

  /// Plancher du facteur de facilité (`easeFactor`) — borne basse du clamp SM-2
  /// (défaut `1.3`, minimum historique SuperMemo-2).
  final double minEaseFactor;

  /// Plafond du facteur de facilité — borne haute du clamp (défaut `2.5`,
  /// variante IFFD canonique qui clampe les DEUX bornes, cf. AC4).
  final double maxEaseFactor;

  /// Facteur de facilité initial d'un état neuf (`initial`) — défaut `2.5`.
  final double defaultEaseFactor;

  /// Multiplicateur global appliqué au calcul d'intervalle
  /// (`interval * easeFactor * defaultIntervalModifier`) — défaut `1.0`.
  /// Une app le monte pour espacer davantage, le baisse pour resserrer.
  final double defaultIntervalModifier;

  /// Facteur de bonus pour une carte révisée **en retard** (échéance dépassée).
  /// Point d'extension documenté du calcul d'échéance (défaut `0.5`) : **inerte
  /// au MVP** (E9-2), un scheduler enrichi (E9-4/FSRS) peut l'exploiter.
  final double overdueBonusFactor;

  /// Seuil de **réussite** : `quality >= passThreshold` = révision réussie,
  /// sinon lapse (défaut `3`, échelle SuperMemo-2 `0..5`).
  final int passThreshold;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSrsConfig &&
          minEaseFactor == other.minEaseFactor &&
          maxEaseFactor == other.maxEaseFactor &&
          defaultEaseFactor == other.defaultEaseFactor &&
          defaultIntervalModifier == other.defaultIntervalModifier &&
          overdueBonusFactor == other.overdueBonusFactor &&
          passThreshold == other.passThreshold;

  @override
  int get hashCode => Object.hash(
        minEaseFactor,
        maxEaseFactor,
        defaultEaseFactor,
        defaultIntervalModifier,
        overdueBonusFactor,
        passThreshold,
      );
}
