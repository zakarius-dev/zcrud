/// Réglages de **composition de face** de la carte de révision.
///
/// Ces deux enums ne décrivent ni un style ni un thème : ils disent ce que
/// la carte doit **rendre** une fois posée dans un assemblage. Un jeton de
/// thème serait le mauvais support — il s'appliquerait à toutes les cartes
/// de l'application à la fois, alors que la réponse dépend de la place
/// exacte de CETTE carte (devant ou derrière dans une pile, seule ou
/// accompagnée d'une surface de saisie). D'où deux paramètres d'instance,
/// dont les défauts reproduisent le rendu d'une carte posée seule.
library;

/// Sort des choix d'un QCM **sur la face question**.
///
/// La face **réponse** n'est jamais concernée : ses choix y portent le
/// marquage de la bonne réponse, c'est-à-dire la correction elle-même.
///
/// Enum plutôt que booléen : le sujet du réglage (les choix, sur une face
/// précise) est nommé sur le site d'appel, et une troisième conduite
/// éventuelle n'imposerait pas de rupture d'API.
enum ZFlashcardQuestionFaceChoices {
  /// Les choix sont rendus sous l'énoncé, non interactifs — le rendu d'une
  /// carte consultée seule.
  shown,

  /// La face question se réduit à l'**énoncé seul**.
  ///
  /// C'est ce que demande un assemblage où les mêmes choix sont déjà rendus,
  /// interactifs, par une surface de saisie posée sous la carte : sans ce
  /// réglage, l'utilisateur les verrait deux fois.
  ///
  /// Sans effet hors QCM : les autres types de carte ne rendent aucun choix
  /// sur leur face question.
  hidden,
}

/// Sort du **contenu** de la carte, chrome mis à part.
///
/// Le chrome — fond, rayon, ombre portée, liseré de tête — ne dépend pas de
/// cette valeur : c'est lui qui donne à la carte sa silhouette.
enum ZFlashcardFaceContent {
  /// Contenu rendu : énoncé ou réponse, choix, badge de type, consigne,
  /// actions.
  full,

  /// Carte **muette** : le chrome seul, sans aucun contenu.
  ///
  /// Rien n'est rendu de l'énoncé, des choix, du badge de type, de la
  /// consigne ni des actions. La carte perd du même coup son geste de
  /// révélation et le nœud d'accessibilité qui l'annonce : elle n'est ni
  /// tapable, ni annoncée comme une question.
  ///
  /// C'est ce que demande une carte empilée **derrière** celle qu'on
  /// consulte, dont seule une bande de débord est visible : y laisser du
  /// texte donnerait à lire des fragments de la carte suivante.
  blank,
}
