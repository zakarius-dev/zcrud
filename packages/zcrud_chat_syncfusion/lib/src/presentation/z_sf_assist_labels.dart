/// Clés de libellé de la coquille Syncfusion.
///
/// Chaque clé porte un repli lisible ([kZSfAssistLabelFallbacks]), atteint
/// uniquement quand ni les libellés injectés par l'hôte (`ZcrudScope.labels`),
/// ni le delegate de localisation, ni la table par défaut ne répondent : sans
/// ce repli, un texte affiché à l'utilisateur pourrait valoir littéralement
/// sa clé technique chez un hôte dont le registre de libellés n'est pas
/// encore alimenté.
///
/// [zSfAssistLabel] est l'unique site de résolution de ces clés dans ce
/// paquet.
///
/// Ne figurent ici que les libellés qu'aucun autre paquet ne peut fournir :
/// les noms d'auteur qu'impose le modèle de message de Syncfusion. La
/// région live et la tuile de streaming appartiennent au rendu neutre du
/// socle, avec leurs propres clés — cette coquille ne les redéclare pas.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Préfixe commun — repère toutes les clés de la coquille Syncfusion.
const String kZSfAssistLabelPrefix = 'zchat.sf.';

/// Nom d'auteur des messages de l'utilisateur.
const String kZSfAssistLabelUserAuthor = '${kZSfAssistLabelPrefix}userAuthor';

/// Nom d'auteur des messages de l'assistant.
const String kZSfAssistLabelAssistantAuthor =
    '${kZSfAssistLabelPrefix}assistantAuthor';

/// Toutes les clés de la coquille — surface exhaustive pour l'hôte.
const List<String> kZSfAssistLabelKeys = <String>[
  kZSfAssistLabelUserAuthor,
  kZSfAssistLabelAssistantAuthor,
];

/// Repli lisible de chaque clé — jamais prioritaire sur les libellés de
/// l'hôte, atteint seulement en leur absence.
const Map<String, String> kZSfAssistLabelFallbacks = <String, String>{
  kZSfAssistLabelUserAuthor: 'Vous',
  kZSfAssistLabelAssistantAuthor: 'Assistant',
};

/// Résout une clé de la coquille — l'unique site d'appel de résolution de
/// libellé de ce paquet.
String zSfAssistLabel(BuildContext context, String key) =>
    label(context, key, fallback: kZSfAssistLabelFallbacks[key]);
