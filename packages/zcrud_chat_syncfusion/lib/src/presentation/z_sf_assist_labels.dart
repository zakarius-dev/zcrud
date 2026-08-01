/// Clés de libellé de la coquille Syncfusion — CHAT-6, réduites par CHAT-3b
/// (FR-26).
///
/// 🔴 **CORRECTION DE FIN D'EPIC — HIGH-1.** Ce fichier reprenait l'arbitrage
/// « aucune chaîne en dur, pas même en repli » de `z_chat_labels.dart` — lequel
/// divergeait de la convention du dépôt (`zcrud_session`, `zcrud_study` :
/// `label(context, 'cancel', fallback: 'Annuler')`). Sans repli,
/// `AssistMessageAuthor.name` — un texte **affiché** — valait littéralement
/// `zchat.sf.userAuthor` chez un hôte au registre non alimenté. Les deux clés
/// portent donc désormais un repli lisible ([kZSfAssistLabelFallbacks]),
/// atteint **uniquement** quand ni `ZcrudScope.labels`, ni le delegate, ni la
/// table `en` ne répondent.
///
/// 🔴 **Un seul site de résolution : [zSfAssistLabel]** — même discipline
/// structurelle que `zChatLabel`, gardée par
/// `test/z_sf_label_fallback_guard_test.dart`.
///
/// 🔴 **CHAT-3b — deux clés SUPPRIMÉES, parce qu'elles doublonnaient.** La
/// coquille déclarait `…conversation` (région live) et `…streaming` (réponse en
/// cours) : deux libellés que l'hôte devait alimenter **en plus** de
/// `kZChatLabelLiveRegion` et `kZChatLabelStreaming`, pour annoncer exactement
/// les mêmes nœuds. Le doublon venait de la vue parallèle, qui portait sa propre
/// région live et sa propre tuile de streaming. Devenue backend du port, la
/// coquille ne rend plus ni l'une ni l'autre : elles appartiennent au socle, et
/// leurs clés aussi. Un hôte qui alimentait les deux jeux n'en tient plus qu'un —
/// et ne risque plus de les traduire différemment.
///
/// Ne restent donc que les deux libellés qu'**aucun** autre paquet ne peut
/// fournir : les noms d'auteur qu'impose le modèle de message de Syncfusion.
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

/// Toutes les clés de la coquille — surface exhaustive pour l'hôte, et cible de
/// la garde « aucune chaîne en dur » **et** de la garde « aucune clé morte ».
const List<String> kZSfAssistLabelKeys = <String>[
  kZSfAssistLabelUserAuthor,
  kZSfAssistLabelAssistantAuthor,
];

/// Repli **lisible** de chaque clé — jamais prioritaire sur l'hôte (HIGH-1).
///
/// Assertée **égale en ensemble** à [kZSfAssistLabelKeys] par la garde : une
/// clé ajoutée sans repli rougit.
const Map<String, String> kZSfAssistLabelFallbacks = <String, String>{
  kZSfAssistLabelUserAuthor: 'Vous',
  kZSfAssistLabelAssistantAuthor: 'Assistant',
};

/// Résout une clé de la coquille — **l'UNIQUE** site d'appel de `label()` du
/// paquet (garde source : aucun autre fichier de `lib/` n'écrit `label(`).
String zSfAssistLabel(BuildContext context, String key) =>
    label(context, key, fallback: kZSfAssistLabelFallbacks[key]);
