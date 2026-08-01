/// Clés de libellé du rendu neutre — CHAT-3 (FR-26/FR-23).
///
/// 🔴 **CORRECTION DE FIN D'EPIC — HIGH-1.** Ce fichier documentait auparavant
/// l'inverse : « aucune chaîne d'interface, pas même en repli », au motif
/// qu'une clé brute affichée serait « bruyante et donc corrigée ». C'était une
/// lecture **conforme mais incompatible** avec le reste du dépôt :
/// `zcrud_session` et `zcrud_study` écrivent partout
/// `label(context, 'cancel', fallback: 'Annuler')`. Mesuré avant correction :
/// un hôte qui n'alimente pas son registre voyait littéralement
/// `zchat.removeAttachment` sur le bouton de retrait, `zchat.showMore` sur le
/// dépli — et un lecteur d'écran s'entendait annoncer `zchat.liveRegion`. Un
/// libellé de secours dans la mauvaise langue est **lisible** ; un
/// discriminant machine ne l'est pas, et il est annoncé à l'aveugle.
///
/// La chaîne de résolution reste **inchangée et prioritaire pour l'hôte** :
/// `ZcrudScope.labels` → delegate `ZcrudLocalizations` → table `en` intégrée →
/// **[kZChatLabelFallbacks]** (au lieu de la clé brute). Le repli n'écrase donc
/// jamais une traduction : il n'est atteint que lorsqu'il n'y en a aucune.
///
/// 🔴 **Un seul site de résolution : [zChatLabel].** Aucun autre fichier du
/// package n'appelle `label(` directement — c'est ce qui rend « aucune clé sans
/// repli » **structurel** plutôt que promis, et c'est ce que vérifie
/// `test/z_chat_label_fallback_guard_test.dart` (volets carte, source et rendu).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Préfixe commun — permet à un hôte de repérer d'un coup toutes les clés du
/// chat dans son registre.
const String kZChatLabelPrefix = 'zchat.';

/// Action « déplier le message » (dépli **inline**, jamais une navigation).
const String kZChatLabelShowMore = '${kZChatLabelPrefix}showMore';

/// Action « replier le message ».
const String kZChatLabelShowLess = '${kZChatLabelPrefix}showLess';

/// En-tête du bloc de provenance (`ZSourcesBlock`).
const String kZChatLabelSources = '${kZChatLabelPrefix}sources';

/// En-tête du bloc de relances (`ZSuggestionsBlock`).
const String kZChatLabelSuggestions = '${kZChatLabelPrefix}suggestions';

/// En-tête d'un diagramme non interprété (`ZMermaidDiagramBlock`).
const String kZChatLabelDiagram = '${kZChatLabelPrefix}diagram';

/// Étiquette sémantique d'un contenu que le socle ne sait pas typer
/// ([ZCustomContentBlock]) — le payload est préservé, pas rendu.
const String kZChatLabelUnsupportedBlock = '${kZChatLabelPrefix}unsupportedBlock';

/// Étiquette sémantique de la région live d'annonce (a11y, AD-13).
const String kZChatLabelLiveRegion = '${kZChatLabelPrefix}liveRegion';

/// Étiquette sémantique de la réponse en cours de rédaction.
const String kZChatLabelStreaming = '${kZChatLabelPrefix}streaming';

/// Étiquette sémantique de la bande de pièces jointes en attente (CHAT-5).
const String kZChatLabelAttachments = '${kZChatLabelPrefix}attachments';

/// Action « retirer cette pièce jointe » (CHAT-5).
const String kZChatLabelRemoveAttachment =
    '${kZChatLabelPrefix}removeAttachment';

/// Action « lire à voix haute » (CHAT-9, diffusion vocale).
const String kZChatLabelSpeak = '${kZChatLabelPrefix}speak';

/// Action « arrêter la lecture » (CHAT-9).
const String kZChatLabelStopSpeaking = '${kZChatLabelPrefix}stopSpeaking';

/// Action « partager la conversation » (CHAT-9).
const String kZChatLabelShare = '${kZChatLabelPrefix}share';

/// Étiquette sémantique de la barre de diffusion (CHAT-9).
const String kZChatLabelDiffusion = '${kZChatLabelPrefix}diffusion';

/// Étiquette sémantique de la barre de saisie assistée (CHAT-10) — l'état de
/// repos de sa région live.
const String kZChatLabelAssistedInput = '${kZChatLabelPrefix}assistedInput';

/// Action « dicter le message » (CHAT-10, saisie assistée).
const String kZChatLabelDictate = '${kZChatLabelPrefix}dictate';

/// Action « arrêter la dictée » (CHAT-10).
const String kZChatLabelStopDictation = '${kZChatLabelPrefix}stopDictation';

/// 🔴 Annonce de la région live pendant l'écoute (CHAT-10, AD-13).
///
/// Chez lex, l'écoute est VISIBLE (une icône change) mais jamais ANNONCÉE : un
/// utilisateur non-voyant ne sait pas que le micro écoute. Cette clé existe pour
/// que ce ne soit plus le cas.
const String kZChatLabelListening = '${kZChatLabelPrefix}listening';

/// Action « extraire le texte d'une image » (CHAT-10, OCR).
const String kZChatLabelScanText = '${kZChatLabelPrefix}scanText';

/// Annonce de la région live pendant l'analyse d'une image (CHAT-10).
const String kZChatLabelRecognizing = '${kZChatLabelPrefix}recognizing';

/// Étiquette sémantique de la surface de RELECTURE (CHAT-10).
const String kZChatLabelReviewCapture = '${kZChatLabelPrefix}reviewCapture';

/// Action « insérer le texte relu dans le message » (CHAT-10).
const String kZChatLabelAcceptCapture = '${kZChatLabelPrefix}acceptCapture';

/// Action « abandonner la relecture » — n'efface JAMAIS la saisie (CHAT-10).
const String kZChatLabelCancelCapture = '${kZChatLabelPrefix}cancelCapture';

/// Toutes les clés du rendu neutre — surface exhaustive pour un hôte qui
/// alimente son registre, et cible de la garde « aucune chaîne en dur ».
const List<String> kZChatLabelKeys = <String>[
  kZChatLabelShowMore,
  kZChatLabelShowLess,
  kZChatLabelSources,
  kZChatLabelSuggestions,
  kZChatLabelDiagram,
  kZChatLabelUnsupportedBlock,
  kZChatLabelLiveRegion,
  kZChatLabelStreaming,
  kZChatLabelAttachments,
  kZChatLabelRemoveAttachment,
  kZChatLabelSpeak,
  kZChatLabelStopSpeaking,
  kZChatLabelShare,
  kZChatLabelDiffusion,
  kZChatLabelAssistedInput,
  kZChatLabelDictate,
  kZChatLabelStopDictation,
  kZChatLabelListening,
  kZChatLabelScanText,
  kZChatLabelRecognizing,
  kZChatLabelReviewCapture,
  kZChatLabelAcceptCapture,
  kZChatLabelCancelCapture,
];

/// Repli **lisible** de chaque clé — jamais prioritaire sur l'hôte (HIGH-1).
///
/// 🔴 La langue est le **français**, comme `ZDefaultReorderRenderer`
/// (`'Déplacer avant'`) et `zcrud_session` (`'Annuler'`, `'Valider'`) : le
/// dépôt a tranché, et deux conventions de repli dans un même socle
/// multi-consommateurs coûteraient plus qu'une langue de secours unique.
/// L'hôte qui traduit passe `ZcrudScope(labels:)` — le repli n'est **jamais**
/// atteint dans ce cas (`label()` ne le consulte qu'en dernier ressort).
///
/// Une clé absente de cette carte ferait rougir
/// `test/z_chat_label_fallback_guard_test.dart` (volet **carte**) : la carte et
/// [kZChatLabelKeys] sont assertées **égales en ensemble**, jamais « incluses ».
const Map<String, String> kZChatLabelFallbacks = <String, String>{
  kZChatLabelShowMore: 'Afficher plus',
  kZChatLabelShowLess: 'Afficher moins',
  kZChatLabelSources: 'Sources',
  kZChatLabelSuggestions: 'Suggestions',
  kZChatLabelDiagram: 'Diagramme',
  kZChatLabelUnsupportedBlock: 'Contenu non pris en charge',
  kZChatLabelLiveRegion: 'Conversation',
  kZChatLabelStreaming: 'Réponse en cours',
  kZChatLabelAttachments: 'Pièces jointes',
  kZChatLabelRemoveAttachment: 'Retirer',
  kZChatLabelSpeak: 'Lire à voix haute',
  kZChatLabelStopSpeaking: 'Arrêter la lecture',
  kZChatLabelShare: 'Partager',
  kZChatLabelDiffusion: 'Diffusion',
  kZChatLabelAssistedInput: 'Saisie assistée',
  kZChatLabelDictate: 'Dicter',
  kZChatLabelStopDictation: 'Arrêter la dictée',
  kZChatLabelListening: 'Micro à l\'écoute',
  kZChatLabelScanText: 'Extraire le texte d\'une image',
  kZChatLabelRecognizing: 'Extraction du texte en cours',
  kZChatLabelReviewCapture: 'Relire avant envoi',
  kZChatLabelAcceptCapture: 'Insérer dans le message',
  kZChatLabelCancelCapture: 'Abandonner',
};

/// Résout une clé du chat — **l'UNIQUE** site d'appel de `label()` du package.
///
/// 🔴 Passer par cette fonction plutôt que par `label(context, clé)` n'est pas
/// une préférence de style : c'est ce qui rend impossible d'ajouter une clé
/// **sans repli**. La garde source asserte qu'aucun autre fichier de `lib/`
/// n'écrit `label(` — un nouvel appel direct rougit, même si son auteur avait
/// « pensé » au repli.
String zChatLabel(BuildContext context, String key) =>
    label(context, key, fallback: kZChatLabelFallbacks[key]);
