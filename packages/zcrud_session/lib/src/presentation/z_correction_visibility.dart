/// Régime d'apparition de la correction dans `ZFlashcardAnswerInput`.
///
/// ## Ce que cet enum gate, et ce qu'il ne gate pas
///
/// Il porte sur le rendu seul de la correction (icônes de vérité ✓/✗,
/// `statusText` correct/incorrect, section de feedback). Il ne touche
/// jamais au verrouillage d'interaction, qui reste gaté — comme avant — sur
/// « une correction a-t-elle été posée ? » (`_correction.value != null`) :
///
/// - `onTap` des choix (`_ChoiceRow`) reste `null` après soumission ;
/// - `onPressed` des boutons Vrai/Faux reste `null` après soumission ;
/// - le bouton de soumission disparaît toujours après soumission ;
/// - `_submitLocked` (verrou one-shot couvrant la fenêtre `await`) est intact.
///
/// ## Pourquoi cette séparation est non négociable
///
/// La correction gate deux choses distinctes au même endroit : l'affichage
/// et le verrou. Différer naïvement en laissant `_correction.value` à
/// `null` rouvrirait la double soumission : les choix redeviendraient
/// tapables après réponse, et un QCM auto-soumis pourrait ré-émettre
/// `onSubmitted`. La carte pose donc toujours `_correction` et se contente
/// de ne pas le peindre.
///
/// Un enum plutôt qu'un booléen : un `bool deferCorrection` ne dirait pas
/// quand la correction apparaît, ni qui la révèle.
library;

/// Régime d'apparition de la correction d'une carte.
enum ZCorrectionVisibility {
  /// Défaut — révision/apprentissage : la correction apparaît dès la
  /// soumission de la carte.
  immediate,

  /// Examen blanc : la carte ne rend jamais la correction.
  ///
  /// La soumission est bien enregistrée (et la saisie verrouillée, une
  /// réponse par carte), mais rien n'est peint : c'est l'hôte qui révèle la
  /// correction en fin d'examen, depuis les `ZFlashcardSubmission`
  /// mémorisées. Une carte en `deferred` ne redevient jamais `immediate`
  /// d'elle-même.
  deferred,
}

/// Décision de rendu de la correction — source unique des trois gates.
extension ZCorrectionVisibilityX on ZCorrectionVisibility {
  /// La carte peint-elle sa correction (icônes ✓/✗, `statusText`, feedback) ?
  ///
  /// `switch` exhaustif sans `default` : c'est tout l'intérêt de ce getter —
  /// une valeur supplémentaire de l'enum casse la compilation ici, plutôt
  /// que de tomber silencieusement dans un repli.
  ///
  /// Défaut qu'il ferme : trois sites de rendu portaient auparavant la même
  /// règle avec deux polarités opposées — certains en allowlist
  /// (`== immediate`), d'autres en denylist (`== deferred`). Aucun `switch`
  /// ne les protégeait. Ajouter une troisième valeur (un régime « révéler à
  /// la demande », par exemple) aurait compilé sans avertissement, puis :
  /// icônes ✓/✗ et `Semantics.value` muets (`!= immediate`), pendant que la
  /// section de correction tombait au travers et peignait le feedback
  /// (`!= deferred`) — le canal le plus informatif, en `liveRegion`, donc
  /// annoncé au lecteur d'écran. Un défaut où les deux canaux ne suivraient
  /// plus le même gate, rendant une correction invisible à l'œil.
  ///
  /// La promesse tenait par coïncidence (deux valeurs, donc
  /// `!= immediate` équivalait à `== deferred`), jamais par structure. Elle
  /// tient désormais par structure : une troisième valeur casse la
  /// compilation ici, à l'endroit où la décision se prend, et nulle part
  /// ailleurs.
  bool get paintsCorrection => switch (this) {
    ZCorrectionVisibility.immediate => true,
    ZCorrectionVisibility.deferred => false,
  };
}
