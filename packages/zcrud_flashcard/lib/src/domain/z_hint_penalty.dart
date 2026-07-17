/// Plafond de qualité par **indices consommés** (Story SU-3, AC6 — AD-36).
///
/// 🔒 **PROPRIÉTAIRE UNIQUE de la pénalité d'indices** (AD-36 mot pour mot :
/// « la pénalité a un propriétaire unique : la couche **locale** »). Une seule
/// fonction pure la possède : [zApplyHintCeiling]. Toute autre application de
/// pénalité — dans un widget, dans un port, dans un barème — serait une
/// **seconde source** : les deux se **cumuleraient** (double peine invisible) ou
/// se **contrediraient**.
///
/// 🔒 **APPLIQUÉ EN DERNIER, SUR LA VALEUR RENDUE** — y compris sur la
/// `suggestedQuality` d'un port. C'est la **garde anti-contournement** d'AD-36 :
/// « un port qui rend 10 indices ne contourne pas le plafond ». L'ordre est
/// **imposé par mandat** (AD-36) :
///
/// ```text
/// port  → config.clampQuality(suggestedQuality) → zApplyHintCeiling(...) → qualité
/// local → max/minQuality                        → zApplyHintCeiling(...) → qualité
/// repli → config.passThreshold                  → zApplyHintCeiling(...) → qualité
/// « Je ne sais pas » → config.minQuality        → zApplyHintCeiling(...) → qualité
///                                                 ▲ UNE SEULE VOIE, EN DERNIER
/// ```
///
/// ⚠️ **Ce que cet ordre garantit RÉELLEMENT — dit sans le surestimer.**
/// Cette dartdoc a affirmé que l'ordre était « **non commutatif** » et
/// « **verrouillé par un test dédié** ». **Les deux étaient FAUX**, et le
/// contre-exemple qu'elle construisait démontrait en réalité l'**égalité** des
/// deux ordres. Mesure faite (1144 combinaisons, **0 divergence**), puis prouvée
/// algébriquement :
///
/// ```text
/// clamp(x) = max(minQ, min(maxQ, x))   apply(x) = min(x, c)   c = max(maxQ-used, floor)
/// Ordre imposé   A = min(clamp(x), c)        Ordre inverse  B = clamp(min(x, c))
/// Soit m = min(maxQ, x) :
///   m >= minQ : A = min(m, c) ; B = max(minQ, min(m, c)) = min(m, c)   (car c >= minQ)
///   m <  minQ : A = min(minQ, c) = minQ ; B = max(minQ, min(m, c)) = minQ
/// ⇒ A == B, à la SEULE condition que c >= minQ.
/// ```
///
/// Or `c >= floor >= passThreshold - 1 >= minQuality`, **structurellement
/// garanti** par l'`assert(minQuality < passThreshold)` de `ZSrsConfig` (AD-46) :
/// les configs qui casseraient l'égalité sont **inconstructibles**.
///
/// ⇒ **L'invariant PORTEUR n'est donc pas l'ordre : c'est `ceiling >= minQuality`**
/// — et c'est LUI qui est pinné (`z_hint_penalty_test.dart`, « le plafond ne
/// descend jamais sous `minQuality` » : retirer le plancher dérivé le fait
/// **ROUGIR**). L'ordre reste imposé **par mandat AD-36 et par robustesse** (il
/// cesserait d'être équivalent si un jour AD-46 relâchait ses asserts), **pas**
/// parce qu'un test le verrouille : un tel test **ne pourrait jamais rougir**, et
/// l'écrire aurait été fabriquer une preuve.
///
/// 🔒 **Fonction PURE** : aucun Flutter, aucun port, aucun état.
library;

import 'dart:math' as math;

import 'z_srs_config.dart';

/// Politique de plafonnement par indices (value-object immuable).
///
/// Ne porte que le **plancher** du plafond : le pas de pénalité (**un cran par
/// indice**) est fixé par AD-36 et n'est pas un réglage.
class ZHintPenaltyPolicy {
  /// Construit une politique. [floor] `null` ⇒ plancher **DÉRIVÉ**
  /// (`config.passThreshold - 1`).
  const ZHintPenaltyPolicy({this.floor});

  /// Plancher du **plafond** (jamais de la note), ou `null` ⇒ dérivé.
  ///
  /// 🔒 **Ne descend JAMAIS sous `config.passThreshold - 1`** (= `2` par défaut).
  /// Une valeur plus basse est **REMONTÉE** à cette borne (AD-10 : dégrader,
  /// jamais lever d'exception).
  ///
  /// **Pourquoi ce plancher, et pourquoi DÉRIVÉ** : sous `passThreshold - 1`, un
  /// apprenant qui demande quelques indices basculerait **mécaniquement en
  /// lapse** — l'indice, qui est une aide **pédagogique**, deviendrait une
  /// sanction SRS et la carte reviendrait en boucle. Le PRD parle d'un
  /// « plancher 2 » : c'est la **conséquence** de `passThreshold == 3`, pas une
  /// constante. Le coder en dur ferait diverger silencieusement toute app qui
  /// configure `passThreshold: 4` (son plancher doit alors valoir **3**).
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

/// Plancher **effectif** du plafond : [ZHintPenaltyPolicy.floor] **remonté** à
/// `config.passThreshold - 1` s'il est plus bas (ou `null`).
///
/// Exposé pour que la garde de dérivation soit testable **directement** (une app
/// à `passThreshold: 4` ⇒ plancher `3`, jamais le littéral `2`).
int zHintCeilingFloor({
  required ZSrsConfig config,
  ZHintPenaltyPolicy policy = const ZHintPenaltyPolicy(),
}) {
  // 🔒 DÉRIVÉ, jamais le littéral 2 : `passThreshold - 1` est « le cran
  // immédiatement inférieur au seuil de passage » (AD-36).
  final derived = config.passThreshold - 1;
  final requested = policy.floor;
  if (requested == null || requested < derived) return derived;
  return requested;
}

/// Applique le **plafond d'indices** à [rawQuality] — 🔒 **EN DERNIER**, sur la
/// **valeur rendue** (AD-36).
///
/// Chaque indice **abaisse d'UN CRAN la qualité maximale attribuable** :
/// `ceiling = max(config.maxQuality - hintsUsed, floor)`, puis
/// 🔒 `quality = min(rawQuality, ceiling)`.
///
/// 🔒 **Il PLAFONNE, il ne REMONTE JAMAIS une note basse** (`min`, jamais `max`) :
/// `raw = 1` avec 3 indices vaut **1**, pas `2`. Un plafond qui remonterait une
/// note serait une **récompense** pour avoir demandé de l'aide — l'inverse exact
/// de son objet.
///
/// 🔒 **Défensif (AD-10)** : un [hintsUsed] négatif est traité comme `0` ; le
/// plancher est **remonté** si la politique en demande un trop bas ; aucune
/// exception n'est jamais levée.
///
/// Le résultat reste **dans l'échelle** dès lors que [rawQuality] y est (il n'est
/// que diminué) — le clamp d'échelle reste la charge de `config.clampQuality`,
/// **appelé avant** (AD-46 : une seule voie de clamp).
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
  // 🔒 `min` : plafonne, ne remonte pas.
  return math.min(rawQuality, ceiling);
}
