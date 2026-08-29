/// Configuration `ZSrsConfig` — constantes SRS injectables.
///
/// Les constantes de l'algorithme de répétition espacée sont paramétrées,
/// jamais codées en dur dans le calcul. Cela permet à une application
/// d'ajuster la courbe, et à un scheduler alternatif de réutiliser ou
/// redéfinir ces bornes sans forker les modèles.
///
/// Pur-Dart, immuable, `const` : aucun état, aucune E/S. Ce n'est pas une
/// entité persistée mais un paramétrage d'algorithme, donc pas de codegen.
/// Injectée dans [ZSm2Scheduler].
library;

import 'z_ease_factor_adjustment.dart';

/// Paramètres immuables de l'algorithme de répétition espacée (SuperMemo-2
/// par défaut). Toutes les constantes de [ZSm2Scheduler] sont lues depuis une
/// instance de cette classe — aucune constante SM-2 n'est codée en dur dans
/// l'algorithme.
class ZSrsConfig {
  /// Construit une configuration SRS avec les défauts canoniques. Tout
  /// paramètre peut être surchargé pour ajuster la courbe.
  const ZSrsConfig({
    this.minEaseFactor = 1.3,
    this.maxEaseFactor = 2.5,
    this.defaultEaseFactor = kDefaultEaseFactor,
    this.defaultIntervalModifier = 1.0,
    this.overdueBonusFactor = 0.0,
    this.passThreshold = 3,
    this.minQuality = 0,
    this.maxQuality = 5,
    int? neutralQuality,
    this.easeFactorAdjustment = const ZEaseFactorAdjustment.canonical(),
  })  :
        // Bornage DÉFENSIF, jamais une levée (invariant AD-10) : une qualité
        // neutre hors échelle est ramenée sur l'échelle déclarée. Écrit en
        // ternaire plutôt qu'avec `clamp` parce que le constructeur est
        // `const` — `clamp` n'est pas évaluable à la compilation.
        neutralQuality = neutralQuality == null
            ? null
            : (neutralQuality < minQuality
                ? minQuality
                : (neutralQuality > maxQuality ? maxQuality : neutralQuality)),
        assert(
          minQuality < maxQuality,
          'minQuality doit être STRICTEMENT inférieur à maxQuality : une échelle '
          'vide ou inversée ne peut porter aucun cran de notation. Reçu : '
          'minQuality=$minQuality, maxQuality=$maxQuality.',
        ),
        assert(
          minQuality < passThreshold && passThreshold <= maxQuality,
          'passThreshold doit vérifier minQuality < passThreshold <= maxQuality : '
          'un seuil hors de cet intervalle rendrait la réussite soit systématique '
          '(seuil <= min), soit inatteignable (seuil > max). Reçu : '
          'minQuality=$minQuality, passThreshold=$passThreshold, '
          'maxQuality=$maxQuality.',
        ),
        assert(
          maxQuality == 5,
          'maxQuality DOIT valoir 5 : SM-2 est intrinsèquement un algorithme '
          '0..5 (AD-46, « échelle canonique : 0..5 — SM-2 complet »). Sa '
          'formule de facteur de facilité est bâtie sur le sommet 5 — '
          '`EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))` — et elle est GELÉE '
          'par le contrat `z_sm2_contract_test.dart`. Un sommet tronqué ne '
          'généralise donc PAS l\'algorithme : il fabrique une config que le '
          'moteur ne sait pas servir. Ex. maxQuality=4 ⇒ deltaEF(4) = 0.0000 au '
          'MEILLEUR score possible, et strictement négatif partout ailleurs : '
          'l\'easeFactor ne croîtrait JAMAIS, silencieusement (aucune '
          'exception, aucun test rouge) — les intervalles cesseraient de '
          's\'espacer pour un apprenant sans faute. Pour tronquer l\'échelle, '
          'n\'utilisez que minQuality (1 = « sans blackout »), qui est sûr. '
          'Reçu : maxQuality=$maxQuality.',
        ),
        assert(
          minQuality == 0 || minQuality == 1,
          'minQuality DOIT valoir 0 ou 1 : ce sont les deux seules bornes '
          'basses que SM-2 sait honorer (0 = échelle complète avec blackout '
          'total, 1 = échelle « sans blackout »). Toute autre borne basse '
          'décalerait l\'échelle sous la formule gelée `(5 - q)` et fausserait '
          'la courbe sans le signaler (AD-46). Reçu : minQuality=$minQuality.',
        );

  /// Valeur canonique du facteur de facilité par défaut (`2.5`), exposée en
  /// `static const` : sert de défaut d'instance ([defaultEaseFactor]) et de
  /// repli de désérialisation à `ZRepetitionInfo` — une constante utilisable
  /// dans un contexte `const` (annotation de champ).
  static const double kDefaultEaseFactor = 2.5;

  /// Plancher du facteur de facilité (`easeFactor`) — borne basse du clamp
  /// SM-2 (défaut `1.3`, minimum historique SuperMemo-2).
  final double minEaseFactor;

  /// Plafond du facteur de facilité — borne haute du clamp (défaut `2.5`,
  /// variante qui clampe les deux bornes).
  final double maxEaseFactor;

  /// Facteur de facilité initial d'un état neuf (`initial`) — défaut `2.5`.
  final double defaultEaseFactor;

  /// Multiplicateur global appliqué au calcul d'intervalle
  /// (`interval * easeFactor * defaultIntervalModifier`) — défaut `1.0`.
  /// Une application le monte pour espacer davantage, le baisse pour
  /// resserrer.
  final double defaultIntervalModifier;

  /// Facteur de bonus pour une carte révisée en retard (échéance dépassée) —
  /// défaut `0.0`, c'est-à-dire aucun bonus.
  ///
  /// Une carte révisée en retard a été mémorisée plus longtemps que son
  /// intervalle ne le prévoyait : le retard est une information de
  /// rétention, que `ZSm2Scheduler` peut créditer au prochain intervalle —
  /// `min(round(joursDeRetard * ce facteur), intervalleDeBase)`, le bornage
  /// étant anti-explosion (au pire, le retard double l'intervalle).
  ///
  /// Le défaut `0.0` correspond au comportement historique de ce paquet
  /// (aucun bonus). `0.5` est la valeur de parité avec des moteurs SM-2 qui
  /// créditent le retard par ailleurs. Une application qui veut ce
  /// comportement le déclare explicitement.
  final double overdueBonusFactor;

  /// Seuil de réussite : `quality >= passThreshold` signifie révision
  /// réussie, sinon lapse (défaut `3`, échelle SuperMemo-2 `0..5`).
  final int passThreshold;

  /// Borne basse de l'échelle de qualité (défaut `0` — SuperMemo-2 complet,
  /// « blackout total »). Une application peut tronquer l'échelle par le
  /// bas : `1` signifie « sans blackout ». Seules `0` et `1` sont admises
  /// (`assert`) — les deux seules bornes basses que la formule SM-2 gelée
  /// sait honorer.
  ///
  /// Source unique de vérité de l'échelle : toute dérivation d'échelle doit
  /// lire ces bornes plutôt que les redéclarer — une seconde source
  /// divergerait silencieusement.
  final int minQuality;

  /// Borne haute de l'échelle de qualité — épinglée à `5` (`assert`).
  ///
  /// Champ de lecture, pas de réglage : SM-2 étant intrinsèquement un
  /// algorithme `0..5` (formule `(5 - q)`, gelée par contrat), un sommet
  /// tronqué produirait une config que le moteur ne sait pas servir
  /// (`maxQuality: 4` ⇒ `deltaEF(4) = 0.0` ⇒ le facteur de facilité ne
  /// croît jamais, en silence). Il existe pour que [clampQuality] et les
  /// dérivations d'échelle lisent le sommet au lieu de le recopier en dur —
  /// la garde est ici, une fois, plutôt que dispersée chez chaque
  /// consommateur.
  ///
  /// Voir [minQuality] : ces bornes sont possédées par le domaine. Pour
  /// tronquer l'échelle, n'utilisez que [minQuality].
  final int maxQuality;

  /// Qualité neutre posée quand **aucune évaluation n'est disponible** —
  /// `null` (le défaut) signifie « utiliser [passThreshold] ».
  ///
  /// Une soumission peut arriver sans note : le type de carte n'est pas
  /// évalué localement et le port d'évaluation est absent, indisponible ou
  /// rend `null`. La révision a pourtant eu lieu, et l'état de répétition
  /// espacée doit avancer. C'est cette qualité-là que le consommateur pose
  /// alors — ni la meilleure note (qui offrirait une réussite gratuite), ni
  /// la pire (qui punirait une panne d'infrastructure).
  ///
  /// `null` ⇒ [passThreshold], c'est-à-dire la plus petite note qui compte
  /// comme réussite : la carte progresse au minimum, sans cadeau. Une
  /// application qui veut faire retomber ces révisions sous le seuil
  /// (« aucune preuve d'apprentissage ») déclare la valeur explicitement.
  ///
  /// La valeur est **bornée** à `[minQuality, maxQuality]` à la construction
  /// (jamais une exception : une configuration hors échelle est corrigée, pas
  /// rejetée).
  ///
  /// Ce paquet ne consomme pas ce réglage : il ne décrit pas une variante de
  /// l'algorithme, mais la politique du **flux de session** qui appelle le
  /// planificateur. Il est déclaré ici parce que l'échelle de qualité est
  /// possédée ici — une seconde source de bornes divergerait.
  final int? neutralQuality;

  /// Stratégie d'ajustement du facteur de facilité — défaut
  /// `ZEaseFactorAdjustment.canonical()`, la formule SuperMemo-2 historique.
  ///
  /// Le défaut rend **exactement** les mêmes facteurs de facilité que la
  /// formule codée en dur dans le planificateur avant l'existence de ce
  /// point d'extension : une application qui ne déclare rien ne voit aucune
  /// différence de planification.
  ///
  /// Le bornage à [minEaseFactor]/[maxEaseFactor] n'appartient PAS à la
  /// stratégie : le planificateur borne systématiquement le résultat qu'elle
  /// rend.
  final ZEaseFactorAdjustment easeFactorAdjustment;

  /// Seuil de maîtrise — dérivé de la borne haute possédée par cette config.
  /// `maxQuality - 1` correspond à q4-5 en échelle canonique — jamais le
  /// littéral `4`.
  ///
  /// Source unique : ce seuil est dérivé une seule fois, ici, dans le type
  /// qui possède l'échelle. Tout consommateur qui a besoin du seuil de
  /// maîtrise le lit sur cette configuration plutôt que de le redériver —
  /// une seconde dérivation divergerait silencieusement si l'échelle change.
  ///
  /// Ceci est un accesseur dérivé : aucun champ, aucun paramètre de
  /// constructeur, aucun impact sur la sérialisation ou le round-trip
  /// (`ZSrsConfig` n'est pas un modèle du codegen).
  int get masteredThreshold => maxQuality - 1;

  /// Qualité effectivement posée quand aucune évaluation n'est disponible :
  /// [neutralQuality] s'il est déclaré, sinon [passThreshold].
  ///
  /// Source unique de la résolution du défaut : un consommateur lit cet
  /// accesseur plutôt que d'écrire `neutralQuality ?? passThreshold` chez
  /// lui — une seconde écriture de la règle divergerait en silence si le
  /// défaut changeait.
  ///
  /// Accesseur dérivé : aucun champ, aucun paramètre de constructeur, aucun
  /// effet sur l'égalité.
  int get effectiveNeutralQuality => neutralQuality ?? passThreshold;

  /// Ramène [quality] dans l'échelle `[minQuality, maxQuality]`.
  ///
  /// Propriétaire unique du clamp : aucun consommateur ne doit réécrire des
  /// bornes en dur — tous passent par ici. Défensif (invariant AD-10) : une
  /// valeur hors bornes est clampée, jamais rejetée par une exception (une
  /// note aberrante venue d'un port d'évaluation ne doit pas casser une
  /// session).
  int clampQuality(int quality) => quality.clamp(minQuality, maxQuality);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSrsConfig &&
          minEaseFactor == other.minEaseFactor &&
          maxEaseFactor == other.maxEaseFactor &&
          defaultEaseFactor == other.defaultEaseFactor &&
          defaultIntervalModifier == other.defaultIntervalModifier &&
          overdueBonusFactor == other.overdueBonusFactor &&
          passThreshold == other.passThreshold &&
          minQuality == other.minQuality &&
          maxQuality == other.maxQuality &&
          neutralQuality == other.neutralQuality &&
          easeFactorAdjustment == other.easeFactorAdjustment;

  @override
  int get hashCode => Object.hash(
        minEaseFactor,
        maxEaseFactor,
        defaultEaseFactor,
        defaultIntervalModifier,
        overdueBonusFactor,
        passThreshold,
        minQuality,
        maxQuality,
        neutralQuality,
        easeFactorAdjustment,
      );
}
