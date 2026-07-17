/// Sélection PURE du **feedback pédagogique** d'une soumission (SU-5, AC4 —
/// FR-SU9).
///
/// La règle de seau vit **ICI et nulle part ailleurs**, en **pur-Dart** : aucune
/// `BuildContext`, aucun widget, aucune l10n — la fonction rend une **clé**
/// ([zFeedbackKeyFor]), jamais un texte. C'est ce qui la rend testable **hors
/// widget** (exigence explicite de FR-SU9) : `test`, pas `testWidgets`.
///
/// ## AD-46 — aucune note n'est hors seau, et l'échelle n'est PAS redéclarée
///
/// La qualité entrante est **CLAMPÉE par `config.clampQuality`** — **voie
/// UNIQUE** du repo (AD-46/AD-10) : une note aberrante venue d'un port
/// d'évaluation (`-3`, `9`) est ramenée dans l'échelle, **jamais** rejetée par
/// une exception. Les bornes ne sont **jamais** réécrites ici : `min`/`max`
/// appartiennent à `ZSrsConfig`, et `masteredThreshold` est **injecté** (son
/// défaut est **CONSOMMÉ** depuis son propriétaire AD-46 —
/// `ZSrsConfig.masteredThreshold` — côté widget, jamais le littéral `4` et jamais
/// redérivé ; su-6/D2. `z_quality_scale_single_source_test.dart` rougit sur un
/// littéral de borne ou un `masteredThreshold ?? <littéral>` dans ce fichier).
///
/// ## 🔴 Le seau « mauvais » est **q0-2**, jamais « 1-2 »
///
/// Écart PRD **tranché** (cf. story, § « Écart PRD tranché ») : §FR-SU9 porte un
/// **résidu** de l'échelle 1-5, déjà **explicitement amendée** par le spine
/// (AD-46, échelle canonique **0..5**). Le glossaire PRD, les ACs des epics et
/// l'AD-46 (« **aucune note n'est hors seau** ») imposent **0-2**. Une note `q0`
/// (blackout total) ne doit tomber dans **aucun trou** : c'est l'apprenant le
/// plus en difficulté qui, sinon, ne recevrait **aucun** encouragement.
///
/// Pur-Dart, Flutter-free : `test/z_purity_test.dart` bannit
/// `flutter/material|widgets|cupertino` dans `lib/src/domain/`.
library;

// AD-46 : les bornes ET le clamp sont possédés par le domaine `ZSrsConfig`
// (`zcrud_flashcard`). Arête PRÉEXISTANTE (`zcrud_session → zcrud_flashcard`,
// déjà importée par les 3 runtimes) : aucune arête nouvelle.
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;

/// Seau de feedback — dérivé de la qualité **CLAMPÉE** (AD-46 : aucune note
/// hors seau).
enum ZFeedbackTier {
  /// Note **mauvaise** (`q0-2` en échelle canonique) — message de motivation.
  motivation,

  /// Note **bonne sans être maîtrisée** (`q3`) — message neutre.
  neutral,

  /// Note **maîtrisée** (`q4-5`) — message d'encouragement.
  encouragement,

  /// Maîtrisée **vite et sans indice** — palier « exceptionnel ».
  exceptional,
}

/// Seuils du palier « **exceptionnel** » — **configurables** (FR-SU9 : « palier
/// `< 10 s` sans indice »), jamais un `10` en dur dans un `build()`.
class ZFeedbackThresholds {
  /// Construit les seuils du palier exceptionnel.
  ///
  /// - [exceptionalUnder] : temps de réponse **STRICTEMENT** inférieur exigé
  ///   (défaut `10 s` — FR-SU9) ;
  /// - [exceptionalMaxHints] : nombre d'indices **maximal** toléré (défaut `0` :
  ///   *l'indice tue le palier*).
  const ZFeedbackThresholds({
    this.exceptionalUnder = const Duration(seconds: 10),
    this.exceptionalMaxHints = 0,
  });

  /// Temps de réponse sous lequel le palier exceptionnel est atteignable
  /// (comparaison **stricte** : `timeTaken < exceptionalUnder`).
  final Duration exceptionalUnder;

  /// Nombre d'indices maximal toléré pour le palier exceptionnel.
  final int exceptionalMaxHints;
}

/// Sélectionne le seau de feedback d'une soumission — **fonction PURE** (AC4).
///
/// - [quality] est **CLAMPÉE** par `config.clampQuality` (voie UNIQUE, AD-46/
///   AD-10) ⇒ `-3` → `min`, `9` → `max`, **jamais** d'exception ;
/// - [timeTaken] et [hintsUsed] **aberrants (négatifs)** sont ramenés à **zéro
///   puis REFUSENT le palier** (AD-10 — code-review su-5, D7) : voir plus bas ;
/// - `q >= masteredThreshold` → [ZFeedbackTier.encouragement], **promu** en
///   [ZFeedbackTier.exceptional] si `timeTaken < thresholds.exceptionalUnder`
///   **ET** `hintsUsed <= thresholds.exceptionalMaxHints` ;
/// - `q >= config.passThreshold` (mais non maîtrisée) → [ZFeedbackTier.neutral] ;
/// - **sinon** → [ZFeedbackTier.motivation] (**q0-2** : aucune note hors seau).
///
/// 🔴 **Écart consigné, assumé** — la spec de la story écrivait
/// `== passThreshold → neutral`. Le `>=` retenu ici est **identique** sur toute
/// config par défaut (`passThreshold=3`, `masteredThreshold=4` ⇒ `3` est la
/// SEULE note entre les deux seuils), mais il reste **total et correct** sur une
/// échelle tronquée : avec `passThreshold=1`, un `q2` est une **réussite** et
/// doit recevoir « bon », pas « mauvais ». Le `==` l'aurait envoyé en
/// `motivation` — silencieusement. Le `>=` colle en outre au **glossaire**
/// (« bon » = *réussi mais non maîtrisé*), qui est la définition normative des
/// seaux (AD-46).
///
/// ## 🔴 AD-10 — une mesure ABERRANTE ne peut pas MÉRITER le palier (D7)
///
/// [timeTaken] et [hintsUsed] sont **fournis par l'hôte** (D1 : la clé est
/// calculée par l'appelant, et su-5 force déjà l'hôte à mesurer le temps au mur
/// — le patron naturel étant `end.difference(start)`). Sur une correction NTP ou
/// un changement d'heure système entre les deux relevés, `timeTaken` est
/// **NÉGATIF** — et un apprenant qui a peiné 5 minutes recevrait « Exceptionnel
/// — juste, sans indice et **en un éclair** ! ».
///
/// 🔒 **On ne les clampe PAS à zéro** — ce serait exactement le bug : `0`
/// signifie *« instantané »*, soit la valeur la plus **flatteuse** de l'échelle.
/// Une entrée aberrante refuse donc le **palier** (repli sur
/// [ZFeedbackTier.encouragement] — la carte EST maîtrisée, le message reste
/// juste et positif), **jamais** une exception, **jamais** une perte de
/// fonction. C'est la symétrie qui manquait : la fonction clampait déjà
/// [quality] et le fichier frère gardait déjà la durée négative côté
/// présentation (`_formatDuration` ⇒ `00:00`) — les deux **autres** entrées
/// aberrantes de cette même signature ne recevaient aucun traitement.
ZFeedbackTier zFeedbackTierFor({
  required int quality,
  required Duration timeTaken,
  required int hintsUsed,
  required ZSrsConfig config,
  required int masteredThreshold,
  ZFeedbackThresholds thresholds = const ZFeedbackThresholds(),
}) {
  // AD-46/AD-10 — VOIE UNIQUE de clamp : jamais de bornes réécrites ici, jamais
  // d'exception sur une note aberrante.
  final q = config.clampQuality(quality);

  if (q >= masteredThreshold) {
    // AD-10 (D7) — une mesure ABERRANTE refuse le palier : la ramener à zéro la
    // rendrait au contraire MAXIMALEMENT flatteuse (`0 s` = « en un éclair »,
    // `-1` indice = « sans aide »).
    final fastEnough =
        !timeTaken.isNegative && timeTaken < thresholds.exceptionalUnder;
    final unaided = hintsUsed >= 0 && hintsUsed <= thresholds.exceptionalMaxHints;
    // 🔒 Les DEUX conditions sont exigées : un indice tue le palier, même sur
    // une réponse fulgurante (FR-SU9 : « < 10 s **sans indice** »).
    if (fastEnough && unaided) return ZFeedbackTier.exceptional;
    return ZFeedbackTier.encouragement;
  }
  if (q >= config.passThreshold) return ZFeedbackTier.neutral;
  return ZFeedbackTier.motivation;
}

/// Clé l10n du message d'un seau (`zcrud.session.feedback.<tier>`).
///
/// Espace de clés **libre** : `grep "zcrud\.session\." packages/zcrud_core/lib`
/// → **RC=1** (aucune collision avec les tables du cœur, qui sont fermées et
/// hors périmètre de cette story — cf. D5).
String zFeedbackKeyFor(ZFeedbackTier tier) =>
    'zcrud.session.feedback.${tier.name}';
