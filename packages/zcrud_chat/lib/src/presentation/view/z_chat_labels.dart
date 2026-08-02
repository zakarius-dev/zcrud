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

/// Étiquette sémantique de la LISTE de conversations (CR-IFFD-39).
const String kZChatLabelConversations = '${kZChatLabelPrefix}conversations';

/// 🔴 Annonce de l'état de **CHARGEMENT** de la liste (CR-IFFD-39, AD-13).
///
/// Chez IFFD, `conversation_list_widget.dart:164` passe `initialData: const []`
/// et le `builder` ne teste **ni `connectionState` ni `hasError`** : la première
/// frame tombe dans `EmptyConversationsState` (`:198-205`). L'utilisateur lit
/// « aucune conversation » **avant** que la moindre donnée soit arrivée. Le
/// chargement doit donc avoir sa propre clé, et son propre état.
const String kZChatLabelLoadingConversations =
    '${kZChatLabelPrefix}loadingConversations';

/// 🔴 État d'**ERREUR** de la liste — inexistant chez IFFD (même mesure que
/// ci-dessus : un échec Firestore y est indiscernable d'une liste vide).
const String kZChatLabelConversationsError =
    '${kZChatLabelPrefix}conversationsError';

/// Action « réessayer » après une erreur de liste (CR-IFFD-39).
const String kZChatLabelRetry = '${kZChatLabelPrefix}retry';

/// État vide — variante « **aucun élément** » (CR-IFFD-39).
const String kZChatLabelNoConversations =
    '${kZChatLabelPrefix}noConversations';

/// État vide — variante « **aucun résultat** » (recherche en cours).
///
/// Les deux variantes sont distinctes parce que l'action qui les accompagne
/// l'est : créer une conversation répond à « la liste est vide », **jamais** à
/// « votre recherche ne rend rien ».
const String kZChatLabelNoResults = '${kZChatLabelPrefix}noResults';

/// Action « nouvelle conversation » — **masquée en recherche** (CR-IFFD-39).
const String kZChatLabelNewConversation =
    '${kZChatLabelPrefix}newConversation';

/// Action « charger la suite » — pagination par **curseur** (CR-IFFD-39).
const String kZChatLabelLoadMore = '${kZChatLabelPrefix}loadMore';

/// Compte des conversations sélectionnées — porte [kZChatCountPlaceholder].
const String kZChatLabelSelectedCount = '${kZChatLabelPrefix}selectedCount';

/// Action « quitter la sélection » — la sortie **explicite** du mode.
const String kZChatLabelExitSelection = '${kZChatLabelPrefix}exitSelection';

/// Étiquette sémantique d'une ligne **sélectionnée** (AD-13).
const String kZChatLabelRowSelected = '${kZChatLabelPrefix}rowSelected';

/// Action « épingler » — `ZChatConversationPinPort.setPinned(pinned: true)`.
const String kZChatLabelPin = '${kZChatLabelPrefix}pin';

/// Action « désépingler » — `setPinned(pinned: false)`. **Un port, deux
/// libellés** : c'est le libellé qui varie, pas le verbe (invariant du port).
const String kZChatLabelUnpin = '${kZChatLabelPrefix}unpin';

/// Action « retirer » — `ZChatConversationLifecyclePort.retire` (**soft**).
const String kZChatLabelRetire = '${kZChatLabelPrefix}retire';

/// 🔴 Action « restaurer » — `ZChatConversationLifecyclePort.restore`.
///
/// **Aucun des deux hôtes n'a ce chemin** : lex soft-supprime en base et
/// n'expose ni route ni UI de restauration (grep client négatif sur
/// `restoreConversation|/restore`), IFFD n'a rien. C'est la capacité que le
/// soft-delete rend possible, et c'est ce qui rend l'annulation **triviale**
/// sans qu'on ait à l'imposer.
const String kZChatLabelRestore = '${kZChatLabelPrefix}restore';

/// Action « reprendre à partir d'ici » — `trimAfter` (**soft**, jamais purge).
const String kZChatLabelTrim = '${kZChatLabelPrefix}trim';

/// Action de **lot** « retirer la sélection » — `retireAll`.
const String kZChatLabelRetireSelected =
    '${kZChatLabelPrefix}retireSelected';

/// Horodatage relatif — moins d'une minute.
const String kZChatLabelTimeNow = '${kZChatLabelPrefix}timeNow';

/// Horodatage relatif — minutes. Porte [kZChatCountPlaceholder].
const String kZChatLabelTimeMinutes = '${kZChatLabelPrefix}timeMinutes';

/// Horodatage relatif — heures. Porte [kZChatCountPlaceholder].
const String kZChatLabelTimeHours = '${kZChatLabelPrefix}timeHours';

/// Horodatage relatif — jours. Porte [kZChatCountPlaceholder].
const String kZChatLabelTimeDays = '${kZChatLabelPrefix}timeDays';

/// Horodatage relatif — semaines. Porte [kZChatCountPlaceholder].
const String kZChatLabelTimeWeeks = '${kZChatLabelPrefix}timeWeeks';

/// Horodatage relatif — mois. Porte [kZChatCountPlaceholder].
const String kZChatLabelTimeMonths = '${kZChatLabelPrefix}timeMonths';

/// Horodatage relatif — années. Porte [kZChatCountPlaceholder].
const String kZChatLabelTimeYears = '${kZChatLabelPrefix}timeYears';

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
  kZChatLabelConversations,
  kZChatLabelLoadingConversations,
  kZChatLabelConversationsError,
  kZChatLabelRetry,
  kZChatLabelNoConversations,
  kZChatLabelNoResults,
  kZChatLabelNewConversation,
  kZChatLabelLoadMore,
  kZChatLabelSelectedCount,
  kZChatLabelExitSelection,
  kZChatLabelRowSelected,
  kZChatLabelPin,
  kZChatLabelUnpin,
  kZChatLabelRetire,
  kZChatLabelRestore,
  kZChatLabelTrim,
  kZChatLabelRetireSelected,
  kZChatLabelTimeNow,
  kZChatLabelTimeMinutes,
  kZChatLabelTimeHours,
  kZChatLabelTimeDays,
  kZChatLabelTimeWeeks,
  kZChatLabelTimeMonths,
  kZChatLabelTimeYears,
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
  kZChatLabelConversations: 'Conversations',
  kZChatLabelLoadingConversations: 'Chargement des conversations',
  kZChatLabelConversationsError: 'Les conversations n\'ont pas pu être chargées',
  kZChatLabelRetry: 'Réessayer',
  kZChatLabelNoConversations: 'Aucune conversation',
  kZChatLabelNoResults: 'Aucun résultat',
  kZChatLabelNewConversation: 'Nouvelle conversation',
  kZChatLabelLoadMore: 'Charger la suite',
  kZChatLabelSelectedCount: '$kZChatCountPlaceholder sélectionnée(s)',
  kZChatLabelExitSelection: 'Quitter la sélection',
  kZChatLabelRowSelected: 'Sélectionnée',
  kZChatLabelPin: 'Épingler',
  kZChatLabelUnpin: 'Désépingler',
  kZChatLabelRetire: 'Retirer la conversation',
  kZChatLabelRestore: 'Restaurer',
  kZChatLabelTrim: 'Reprendre à partir d\'ici',
  kZChatLabelRetireSelected: 'Retirer la sélection',
  kZChatLabelTimeNow: 'à l\'instant',
  kZChatLabelTimeMinutes: 'il y a $kZChatCountPlaceholder min',
  kZChatLabelTimeHours: 'il y a $kZChatCountPlaceholder h',
  kZChatLabelTimeDays: 'il y a $kZChatCountPlaceholder j',
  kZChatLabelTimeWeeks: 'il y a $kZChatCountPlaceholder sem.',
  kZChatLabelTimeMonths: 'il y a $kZChatCountPlaceholder mois',
  kZChatLabelTimeYears: 'il y a $kZChatCountPlaceholder an(s)',
};

/// 🔴 Marqueur de substitution du **compte**, dans un repli comme dans une
/// traduction d'hôte.
///
/// Il est déclaré ici, à côté des replis qui le portent, et **consommé par un
/// seul site** ([zChatCountLabel]). Un hôte qui traduit `zchat.timeMinutes`
/// garde le marqueur dans sa chaîne ; s'il l'omet, le compte n'apparaît
/// simplement pas — aucune exception, aucun texte cassé (AD-10).
const String kZChatCountPlaceholder = '{n}';

/// Résout [key] et y substitue [count] à [kZChatCountPlaceholder].
String zChatCountLabel(BuildContext context, String key, int count) =>
    zChatLabel(context, key).replaceAll(kZChatCountPlaceholder, '$count');

/// Formate un horodatage **relatif** — couture d'hôte (CR-IFFD-39).
///
/// [now] est passé explicitement : un formateur qui lit l'horloge lui-même
/// n'est pas testable, et deux lignes d'une même liste peuvent alors se référer
/// à deux instants différents.
typedef ZChatRelativeTimeFormatter =
    String Function(BuildContext context, DateTime value, DateTime now);

/// Formateur **par défaut** — buckets grossiers, entièrement résolus par clés.
///
/// 🔴 **Aucune locale, aucun mot en dur.** Le défaut mesuré chez IFFD
/// (`conversation_item_widget.dart:49-63`) écrit `'Hier'` en toutes lettres
/// (`:57`) et fige `DateFormat.MMMd('fr_FR')` (`:61`) — la ligne reste en
/// français quelle que soit la langue de l'application. Chez lex, la même faute
/// existe à un endroit et pas à l'autre : `search_result_tile.dart:55` passe
/// `locale: 'fr'` en dur alors que `conversations_screen.dart:249` passe bien
/// `Localizations.localeOf(context).languageCode`. **La même conversation change
/// donc de langue selon qu'on la regarde en recherche ou non.**
///
/// Ici, chaque bucket est une **clé** : un hôte qui alimente son registre
/// obtient sa langue, et un hôte qui veut `timeago`/`intl` passe son propre
/// [ZChatRelativeTimeFormatter]. Le socle, lui, ne dépend d'aucun paquet de
/// dates (AD-57).
String zChatDefaultRelativeTime(
  BuildContext context,
  DateTime value,
  DateTime now,
) {
  final Duration d = now.difference(value);
  // Une date FUTURE (horloge décalée, écriture serveur en avance) ne devient
  // jamais « il y a -3 min » : elle se lit « à l'instant » (AD-10).
  if (d.isNegative || d.inMinutes < 1) {
    return zChatLabel(context, kZChatLabelTimeNow);
  }
  if (d.inHours < 1) {
    return zChatCountLabel(context, kZChatLabelTimeMinutes, d.inMinutes);
  }
  if (d.inDays < 1) {
    return zChatCountLabel(context, kZChatLabelTimeHours, d.inHours);
  }
  if (d.inDays < 7) {
    return zChatCountLabel(context, kZChatLabelTimeDays, d.inDays);
  }
  if (d.inDays < 30) {
    return zChatCountLabel(context, kZChatLabelTimeWeeks, d.inDays ~/ 7);
  }
  if (d.inDays < 365) {
    return zChatCountLabel(context, kZChatLabelTimeMonths, d.inDays ~/ 30);
  }
  return zChatCountLabel(context, kZChatLabelTimeYears, d.inDays ~/ 365);
}

/// Résout une clé du chat — **l'UNIQUE** site d'appel de `label()` du package.
///
/// 🔴 Passer par cette fonction plutôt que par `label(context, clé)` n'est pas
/// une préférence de style : c'est ce qui rend impossible d'ajouter une clé
/// **sans repli**. La garde source asserte qu'aucun autre fichier de `lib/`
/// n'écrit `label(` — un nouvel appel direct rougit, même si son auteur avait
/// « pensé » au repli.
String zChatLabel(BuildContext context, String key) =>
    label(context, key, fallback: kZChatLabelFallbacks[key]);
