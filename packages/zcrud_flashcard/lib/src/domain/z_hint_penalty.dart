/// Plafond de qualité par indices consommés.
///
/// Propriétaire unique de la pénalité d'indices : la pénalité a un
/// propriétaire unique, la couche locale. Une seule fonction pure la
/// possède : [zApplyHintCeiling]. Toute autre application de pénalité — dans
/// un widget, dans un port, dans un barème — serait une seconde source : les
/// deux se cumuleraient (double peine invisible) ou se contrediraient.
///
/// ## Appliqué en dernier, sur la valeur rendue
///
/// Y compris sur la qualité suggérée par un port : c'est la garde
/// anti-contournement — un port qui rend une note haute avec plusieurs
/// indices consommés ne contourne pas le plafond. L'ordre imposé est :
///
/// ```text
/// port  → config.clampQuality(suggestedQuality) → zApplyHintCeiling(...) → qualité
/// local → max/minQuality                        → zApplyHintCeiling(...) → qualité
/// repli → config.passThreshold                  → zApplyHintCeiling(...) → qualité
/// « je ne sais pas » → config.minQuality        → zApplyHintCeiling(...) → qualité
///                                                 ▲ une seule voie, en dernier
/// ```
///
/// L'invariant réellement porteur n'est pas cet ordre en lui-même, mais la
/// propriété `ceiling >= minQuality`, structurellement garantie par
/// l'assertion `minQuality < passThreshold` de `ZSrsConfig` : les
/// configurations qui casseraient cette propriété sont inconstructibles.
/// L'ordre reste imposé par mandat et par robustesse (il cesserait d'être
/// équivalent à l'ordre inverse si les assertions de `ZSrsConfig` étaient un
/// jour relâchées).
///
/// Fonction pure : aucun Flutter, aucun port, aucun état.
library;

import 'dart:math' as math;

import 'z_srs_config.dart';

/// Politique de plafonnement par indices (value-object immuable).
///
/// Ne porte que le plancher du plafond : le pas de pénalité (un cran par
/// indice) est fixe et n'est pas un réglage.
class ZHintPenaltyPolicy {
  /// Construit une politique. [floor] `null` ⇒ plancher dérivé
  /// (`config.passThreshold - 1`).
  const ZHintPenaltyPolicy({this.floor});

  /// Plancher du plafond (jamais de la note), ou `null` ⇒ dérivé.
  ///
  /// Ne descend jamais sous `config.passThreshold - 1` (`2` par défaut). Une
  /// valeur plus basse est remontée à cette borne (invariant AD-10 :
  /// dégrader, jamais lever d'exception).
  ///
  /// Pourquoi ce plancher, et pourquoi dérivé : sous `passThreshold - 1`, un
  /// apprenant qui demande quelques indices basculerait mécaniquement en
  /// lapse — l'indice, qui est une aide pédagogique, deviendrait une
  /// sanction SRS et la carte reviendrait en boucle. Un plancher de `2` est
  /// la conséquence de `passThreshold == 3`, pas une constante indépendante.
  /// Le coder en dur ferait diverger silencieusement toute application qui
  /// configure un `passThreshold` différent.
  final int? floor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZHintPenaltyPolicy && floor == other.floor;

  @override
  int get hashCode => floor.hashCode;

  @override
  String toString() => 'ZHintPenaltyPolicy(floor: $floor)';
}

/// Plancher effectif du plafond : [ZHintPenaltyPolicy.floor] remonté à
/// `config.passThreshold - 1` s'il est plus bas (ou `null`).
///
/// Exposé pour que la dérivation soit testable directement (une application
/// à `passThreshold: 4` a un plancher `3`, jamais un littéral figé).
int zHintCeilingFloor({
  required ZSrsConfig config,
  ZHintPenaltyPolicy policy = const ZHintPenaltyPolicy(),
}) {
  // Dérivé, jamais le littéral 2 : `passThreshold - 1` est le cran
  // immédiatement inférieur au seuil de passage.
  final derived = config.passThreshold - 1;
  final requested = policy.floor;
  if (requested == null || requested < derived) return derived;
  return requested;
}

/// Applique le plafond d'indices à [rawQuality] — en dernier, sur la valeur
/// rendue.
///
/// Chaque indice abaisse d'un cran la qualité maximale attribuable :
/// `ceiling = max(config.maxQuality - hintsUsed, floor)`, puis
/// `quality = min(rawQuality, ceiling)`.
///
/// Il plafonne, il ne remonte jamais une note basse (`min`, jamais `max`) :
/// une note brute de 1 avec 3 indices vaut 1, pas 2. Un plafond qui
/// remonterait une note serait une récompense pour avoir demandé de l'aide —
/// l'inverse exact de son objet.
///
/// Défensif (invariant AD-10) : un [hintsUsed] négatif est traité comme `0` ;
/// le plancher est remonté si la politique en demande un trop bas ; aucune
/// exception n'est jamais levée.
///
/// Le résultat reste dans l'échelle dès lors que [rawQuality] y est (il
/// n'est que diminué) — le clamp d'échelle reste la charge de
/// `config.clampQuality`, appelé avant (une seule voie de clamp).
int zApplyHintCeiling({
  required int rawQuality,
  required int hintsUsed,
  required ZSrsConfig config,
  ZHintPenaltyPolicy policy = const ZHintPenaltyPolicy(),
}) {
  final used = hintsUsed < 0 ? 0 : hintsUsed;
  final floor = zHintCeilingFloor(config: config, policy: policy);
  // Un cran de moins par indice, jamais sous le plancher.
  final ceiling = math.max(config.maxQuality - used, floor);
  // `min` : plafonne, ne remonte pas.
  return math.min(rawQuality, ceiling);
}
