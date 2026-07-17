/// Régime d'apparition de la correction dans `ZFlashcardAnswerInput` (SU-7/D2).
///
/// 🔴 **Ce que cet enum gate, et ce qu'il NE gate PAS.**
///
/// Il porte sur le **RENDU SEUL** de la correction (icônes de vérité ✓/✗,
/// `statusText` correct/incorrect, section de feedback). Il ne touche **JAMAIS**
/// au **verrouillage d'interaction** de su-3, qui reste gaté — comme avant — sur
/// « une correction a-t-elle été posée ? » (`_correction.value != null`) :
///
/// - `onTap` des choix (`_ChoiceRow`) reste `null` après soumission ;
/// - `onPressed` des boutons Vrai/Faux reste `null` après soumission ;
/// - le bouton de soumission **disparaît** toujours après soumission ;
/// - `_submitLocked` (verrou ONE-SHOT couvrant la fenêtre `await`) est intact.
///
/// ⚠️ **Pourquoi cette séparation est NON-NÉGOCIABLE** (sous-piège mesuré,
/// SU-7/G4) : dans su-3, `corrected != null` gate **deux choses distinctes au
/// même endroit** — l'affichage ET le verrou. « Différer » naïvement en laissant
/// `_correction.value` à `null` **rouvrirait la double soumission** : les choix
/// redeviendraient tapables après réponse, et un QCM auto-soumis pourrait
/// **ré-émettre** `onSubmitted`. C'est le défaut majeur D2 que su-3 a fermé. Le
/// report de su-7 pose donc **toujours** `_correction` et se contente de **ne
/// pas le peindre**.
///
/// **enum > booléen** (D9) : un `bool deferCorrection` ne dirait pas *quand* la
/// correction apparaît, ni *qui* la révèle.
library;

/// Régime d'apparition de la correction d'une carte.
enum ZCorrectionVisibility {
  /// **Défaut** — révision/apprentissage : la correction apparaît dès la
  /// soumission de la carte (comportement historique de su-3, inchangé).
  immediate,

  /// Examen blanc (FR-SU13) : la carte **NE REND JAMAIS** la correction.
  ///
  /// La soumission est bien enregistrée (et la saisie **verrouillée**, une
  /// réponse par carte), mais rien n'est peint : c'est l'**hôte** qui révèle la
  /// correction en fin d'examen, depuis les `ZFlashcardSubmission` mémorisées
  /// (SU-7/D4). Une carte en `deferred` ne redevient jamais `immediate` d'elle-même.
  deferred,
}

/// Décision de RENDU de la correction — **source unique** des trois gates.
extension ZCorrectionVisibilityX on ZCorrectionVisibility {
  /// La carte peint-elle sa correction (icônes ✓/✗, `statusText`, feedback) ?
  ///
  /// 🔴 **`switch` EXHAUSTIF SANS `default` — c'est TOUT l'intérêt de ce getter**
  /// (idiome maison, cf. `viewPhaseOf` : « une 4ᵉ phase casserait la compilation
  /// **ici** plutôt que de tomber silencieusement dans un repli »).
  ///
  /// **Défaut MESURÉ qu'il ferme** : les trois sites de rendu portaient la même
  /// règle avec **deux polarités OPPOSÉES** — `_ChoiceRow`/`_tfButton` en
  /// **allowlist** (`== immediate`), `_CorrectionSection` en **denylist**
  /// (`== deferred`). Aucun `switch` ne les protégeait. L'ajout d'une 3ᵉ valeur
  /// — `onDemand` (« révéler à la demande ») est **exactement** le régime qu'un
  /// produit d'étude ajoute ensuite, et cet enum est **public** — aurait compilé
  /// **sans un avertissement**, puis : icônes ✓/✗ et `Semantics.value` **muets**
  /// (`!= immediate`), pendant que `_CorrectionSection` **tombait au travers et
  /// PEIGNAIT** le feedback (`!= deferred`) — le canal **le plus informatif**,
  /// en `liveRegion`, donc **annoncé au lecteur d'écran**. Soit littéralement le
  /// défaut que su-3 promet d'avoir fermé : « les DEUX canaux suivent le MÊME
  /// gate ; les découpler annoncerait une correction invisible à l'œil ».
  ///
  /// La promesse tenait **par coïncidence** (2 valeurs ⇒ `!= immediate` ≡
  /// `== deferred`), jamais **par structure**. Elle tient désormais par
  /// structure : une 3ᵉ valeur **casse la compilation ICI**, à l'endroit où la
  /// décision se prend, et nulle part ailleurs.
  bool get paintsCorrection => switch (this) {
    ZCorrectionVisibility.immediate => true,
    ZCorrectionVisibility.deferred => false,
  };
}
