/// Clés de libellé du rendu neutre.
///
/// Une clé brute affichée à l'écran (`zchat.removeAttachment` sur un bouton
/// de retrait, par exemple) est un discriminant machine, illisible pour
/// l'utilisateur et inaudible pour un lecteur d'écran. Ce fichier fournit
/// donc un repli lisible pour chaque clé — jamais prioritaire sur une
/// traduction fournie par l'hôte, mais toujours préférable à la clé brute.
///
/// La chaîne de résolution est : `ZcrudScope.labels` → delegate
/// `ZcrudLocalizations` → table intégrée → [kZChatLabelFallbacks] (au lieu
/// de la clé brute). Le repli n'écrase donc jamais une traduction : il n'est
/// atteint que lorsqu'il n'y en a aucune.
///
/// Un seul site de résolution : [zChatLabel]. Aucun autre fichier du paquet
/// n'appelle `label(` directement — c'est ce qui rend « aucune clé sans
/// repli » structurel plutôt que promis.
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

/// Étiquette sémantique de la bande de pièces jointes en attente.
const String kZChatLabelAttachments = '${kZChatLabelPrefix}attachments';

/// Action « retirer cette pièce jointe ».
const String kZChatLabelRemoveAttachment =
    '${kZChatLabelPrefix}removeAttachment';

/// Annonce « un téléversement est en cours ».
///
/// Elle dit qu'un transfert **tourne**, jamais où il en est : le socle n'a
/// pas le compteur d'octets. Un hôte qui affiche un pourcentage remplace la
/// pièce entière.
const String kZChatLabelUploading = '${kZChatLabelPrefix}uploading';

/// Action « lire à voix haute ».
const String kZChatLabelSpeak = '${kZChatLabelPrefix}speak';

/// Action « arrêter la lecture ».
const String kZChatLabelStopSpeaking = '${kZChatLabelPrefix}stopSpeaking';

/// Action « partager la conversation ».
const String kZChatLabelShare = '${kZChatLabelPrefix}share';

/// Étiquette sémantique de la barre de diffusion.
const String kZChatLabelDiffusion = '${kZChatLabelPrefix}diffusion';

/// Étiquette sémantique de la barre de saisie assistée — l'état de
/// repos de sa région live.
const String kZChatLabelAssistedInput = '${kZChatLabelPrefix}assistedInput';

/// Action « dicter le message ».
const String kZChatLabelDictate = '${kZChatLabelPrefix}dictate';

/// Action « arrêter la dictée ».
const String kZChatLabelStopDictation = '${kZChatLabelPrefix}stopDictation';

/// Annonce de la région live pendant l'écoute (invariant AD-13).
///
/// Une écoute qui n'est que visible (une icône qui change) laisse un
/// utilisateur non-voyant ignorer que le micro écoute. Cette clé porte
/// l'annonce correspondante.
const String kZChatLabelListening = '${kZChatLabelPrefix}listening';

/// Action « extraire le texte d'une image ».
const String kZChatLabelScanText = '${kZChatLabelPrefix}scanText';

/// Annonce de la région live pendant l'analyse d'une image.
const String kZChatLabelRecognizing = '${kZChatLabelPrefix}recognizing';

/// Étiquette sémantique de la surface de RELECTURE.
const String kZChatLabelReviewCapture = '${kZChatLabelPrefix}reviewCapture';

/// Action « insérer le texte relu dans le message ».
const String kZChatLabelAcceptCapture = '${kZChatLabelPrefix}acceptCapture';

/// Action « abandonner la relecture » — n'efface JAMAIS la saisie.
const String kZChatLabelCancelCapture = '${kZChatLabelPrefix}cancelCapture';

/// Annonce « la saisie affichée vient d'un brouillon enregistré ».
///
/// Sans elle, un texte réapparu à l'ouverture d'une conversation est
/// indiscernable d'un texte qu'on vient de taper.
const String kZChatLabelDraftRestored = '${kZChatLabelPrefix}draftRestored';

/// Action « masquer l'indication de brouillon » — n'efface JAMAIS la saisie.
const String kZChatLabelDismissDraftNotice =
    '${kZChatLabelPrefix}dismissDraftNotice';

/// Étiquette sémantique de la **zone de saisie** partagée.
const String kZChatLabelComposer = '${kZChatLabelPrefix}composer';

/// Invite du champ de saisie — elle sert de **placeholder visuel** ET de
/// libellé du champ pour un lecteur d'écran.
const String kZChatLabelComposerHint = '${kZChatLabelPrefix}composerHint';

/// Étiquette sémantique du compteur de saisie.
///
/// Elle nomme la **quantité**, jamais son unité : l'unité vient du port de
/// mesure, et c'est l'hôte qui décide comment la dire.
const String kZChatLabelComposerCounter =
    '${kZChatLabelPrefix}composerCounter';

/// Étiquette sémantique du **mode vocal continu**, au repos.
const String kZChatLabelVoiceSession = '${kZChatLabelPrefix}voiceSession';

/// Phase « la transcription part dans le tour ».
const String kZChatLabelVoiceSubmitting = '${kZChatLabelPrefix}voiceSubmitting';

/// Phase « la réponse est lue à voix haute ».
const String kZChatLabelVoiceSpeaking = '${kZChatLabelPrefix}voiceSpeaking';

/// Action « arrêter le mode vocal continu ».
const String kZChatLabelStopVoiceSession =
    '${kZChatLabelPrefix}stopVoiceSession';

/// Étiquette sémantique de la superposition de candidats (mentions, commandes).
const String kZChatLabelAffordanceCandidates =
    '${kZChatLabelPrefix}affordanceCandidates';

/// Action « fermer la liste de candidats sans rien choisir ».
const String kZChatLabelAffordanceDismiss =
    '${kZChatLabelPrefix}affordanceDismiss';

// ── Feuille de réglages de génération ────────────────────────────────────
//
// Aucune valeur métier ici : les paliers nommés ci-dessous sont ceux des
// enums du kernel (`ZChatResponseLength`, `ZChatLengthBias`), jamais des
// corpus ni des codes d'un hôte. Le catalogue de corpus est une donnée
// d'hôte — ses libellés viennent de `ZChatCorpusOption.label`, pas d'une clé
// du socle.

/// Étiquette sémantique de la feuille de réglages.
const String kZChatLabelSettings = '${kZChatLabelPrefix}settings';

/// Groupe « verbosité de la réponse » — axe `ZChatResponseLength`.
const String kZChatLabelResponseLength = '${kZChatLabelPrefix}responseLength';

/// Palier `ZChatResponseLength.concise`.
const String kZChatLabelLengthConcise = '${kZChatLabelPrefix}lengthConcise';

/// Palier `ZChatResponseLength.standard`.
const String kZChatLabelLengthStandard = '${kZChatLabelPrefix}lengthStandard';

/// Palier `ZChatResponseLength.detailed`.
const String kZChatLabelLengthDetailed = '${kZChatLabelPrefix}lengthDetailed';

/// Groupe « biais de régénération » — axe `ZChatLengthBias`, orthogonal au
/// précédent (le kernel refuse de les fusionner).
const String kZChatLabelLengthBias = '${kZChatLabelPrefix}lengthBias';

/// Palier `ZChatLengthBias.shorter`.
const String kZChatLabelBiasShorter = '${kZChatLabelPrefix}biasShorter';

/// Palier `ZChatLengthBias.asIs`.
const String kZChatLabelBiasAsIs = '${kZChatLabelPrefix}biasAsIs';

/// Palier `ZChatLengthBias.longer`.
const String kZChatLabelBiasLonger = '${kZChatLabelPrefix}biasLonger';

/// Groupe « budget de calcul » — l'axe porté par `ZChatComputeEffort`.
///
/// Le nom de cette constante évite délibérément le mot `Effort` : une garde
/// de nommage n'autorise, pour ce radical, que les deux orthographes exactes
/// `ZChatComputeEffort` et `computeEffort`, avec limites de mot — pour
/// qu'aucune famille d'orthographes voisines ne se glisse à côté de l'axe
/// qu'elle protège. Le concept, lui, est nommé sans ambiguïté par le kernel :
/// « budget de calcul ».
const String kZChatLabelComputeBudget = '${kZChatLabelPrefix}computeBudget';

/// Un palier `1..5` du budget de calcul — porte [kZChatCountPlaceholder].
const String kZChatLabelComputeBudgetLevel =
    '${kZChatLabelPrefix}computeBudgetLevel';

/// Réglage « exposer les étapes de raisonnement »
/// (`ZChatGenerationSettings.revealThinkingSteps`).
const String kZChatLabelRevealThinking =
    '${kZChatLabelPrefix}revealThinking';

/// Groupe « portée documentaire » — `ZChatCorpusScope`, exprimée en **clés
/// stables** d'hôte.
const String kZChatLabelCorpusScope = '${kZChatLabelPrefix}corpusScope';

/// Option « aucune restriction » de la portée documentaire.
///
/// Elle est **rendue**, jamais implicite : une portée vide qui n'apparaît pas à
/// l'écran est indiscernable d'une portée oubliée. C'est le pendant, côté UI,
/// du fail-safe de `ZChatCorpusScope.audit` (en l'absence de signal, jamais de
/// présomption).
const String kZChatLabelCorpusAll = '${kZChatLabelPrefix}corpusAll';

/// Option « l'hôte décide » d'un réglage — l'état `null`, rendu **explicitement**.
///
/// Sans elle, un utilisateur ne pourrait jamais REVENIR à « non réglé » : il
/// n'existerait que trois paliers, et le quatrième état — le défaut — serait
/// atteignable une seule fois, avant le premier choix.
const String kZChatLabelSettingAuto = '${kZChatLabelPrefix}settingAuto';

/// État « cette capacité a déjà produit un contenu » — le canal textuel des
/// capacités du notebook.
///
/// Un état qui ne se signale que par la couleur d'une icône est perdu pour
/// un utilisateur daltonien, ou pour un thème qui écrase la teinte. Cette
/// clé est le canal non chromatique que `ZChatNotebookCapabilityStyle` rend
/// obligatoire.
const String kZChatLabelGenerated = '${kZChatLabelPrefix}generated';

// ── Artefacts déclarés par message (CR-IFFD-84, volet A) ─────────────────
//
// Les cinq verbes standard sont nommés ICI, jamais dans le rendu : un hôte
// qui déclare `ZChatArtifactAction.open(...)` obtient un menu localisé sans
// alimenter son registre, et l'hôte qui traduit passe par les mêmes clés que
// partout ailleurs. L'IDENTITÉ d'un artefact, elle, n'entre pas au socle :
// `label` est un texte déjà localisé par l'hôte (patron `ZChatModelOption`).

/// Étiquette sémantique de la rangée d'artefacts d'un message.
const String kZChatLabelArtifacts = '${kZChatLabelPrefix}artifacts';

/// Verbe standard « créer » — visible quand l'artefact est absent.
const String kZChatLabelArtifactCreate = '${kZChatLabelPrefix}artifactCreate';

/// Verbe standard « ouvrir » — visible quand l'artefact est présent.
const String kZChatLabelArtifactOpen = '${kZChatLabelPrefix}artifactOpen';

/// Verbe standard « régénérer ».
const String kZChatLabelArtifactRegenerate =
    '${kZChatLabelPrefix}artifactRegenerate';

/// Verbe standard « modifier ».
const String kZChatLabelArtifactEdit = '${kZChatLabelPrefix}artifactEdit';

/// Verbe standard « supprimer » — destructeur, donc confirmé.
const String kZChatLabelArtifactDelete = '${kZChatLabelPrefix}artifactDelete';

/// État « aucun contenu pour cet artefact » — le pendant explicite de
/// [kZChatLabelGenerated].
///
/// Les deux états sont annoncés, jamais seulement l'un des deux : une absence
/// qui ne se signale que par l'absence d'annonce est indiscernable d'un
/// rendu muet.
const String kZChatLabelArtifactEmpty = '${kZChatLabelPrefix}artifactEmpty';

/// État « génération en cours » pour CET artefact — le canal non chromatique
/// de l'occupation. L'animation, elle, est un autre sujet : l'annonce ne
/// dépend pas d'elle.
const String kZChatLabelArtifactBusy = '${kZChatLabelPrefix}artifactBusy';

/// Compte d'éléments d'un artefact — porte [kZChatCountPlaceholder]. C'est le
/// canal TEXTUEL de la pastille, qui n'est jamais annoncée elle-même.
const String kZChatLabelArtifactCount = '${kZChatLabelPrefix}artifactCount';

/// Question générique de confirmation d'un verbe destructeur, quand l'hôte
/// n'a pas fourni la sienne (`confirmMessage`).
const String kZChatLabelArtifactConfirmPrompt =
    '${kZChatLabelPrefix}artifactConfirmPrompt';

/// Question générique posée avant d'exécuter le verbe unique d'un artefact
/// en mode d'activation `confirm`, quand l'hôte n'a pas fourni la sienne
/// (`ZChatArtifactSpec.activationPrompt`).
const String kZChatLabelArtifactActivatePrompt =
    '${kZChatLabelPrefix}artifactActivatePrompt';

/// Action « confirmer » de la confirmation en place.
const String kZChatLabelArtifactConfirm = '${kZChatLabelPrefix}artifactConfirm';

/// Action « annuler » de la confirmation en place — elle n'exécute rien.
const String kZChatLabelArtifactCancel = '${kZChatLabelPrefix}artifactCancel';

// ── Réglages du composer ──────────────────────────────────────────────────

/// Action « envoyer le message » — libellé du créneau d'envoi par défaut
/// (`ZChatComposerSendTarget`). La clé traverse le registre de l'hôte comme
/// toutes les autres.
const String kZChatLabelSend = '${kZChatLabelPrefix}send';

/// Annonce de l'affordance d'envoi pendant une **préparation d'hôte** (un
/// téléversement, typiquement) : l'envoi n'est pas encore possible.
const String kZChatLabelSendBusy = '${kZChatLabelPrefix}sendBusy';

/// Annonce de l'affordance d'envoi en mode **modification** : le geste valide
/// la modification d'un message existant, il n'en poste pas un nouveau.
const String kZChatLabelSendEdit = '${kZChatLabelPrefix}sendEdit';

/// Étiquette sémantique de la BANDE D'ÉTAT du composer (rang 0) — la région
/// live qui porte l'annonce que l'hôte lui donne.
const String kZChatLabelComposerStatus = '${kZChatLabelPrefix}composerStatus';

/// Action « réinitialiser les réglages » — l'en-tête par défaut de la feuille.
const String kZChatLabelSettingsReset = '${kZChatLabelPrefix}settingsReset';

/// Action « fermer la feuille de réglages » — l'en-tête par défaut. Rendue
/// seulement si l'hôte a fourni un `onClose` (invariant AD-4 : pas
/// d'affordance inerte).
const String kZChatLabelSettingsClose = '${kZChatLabelPrefix}settingsClose';

/// Borne basse de l'échelle du budget de calcul.
const String kZChatLabelComputeBudgetFast =
    '${kZChatLabelPrefix}computeBudgetFast';

/// Point médian de l'échelle.
const String kZChatLabelComputeBudgetBalanced =
    '${kZChatLabelPrefix}computeBudgetBalanced';

/// Borne haute de l'échelle.
const String kZChatLabelComputeBudgetDeep =
    '${kZChatLabelPrefix}computeBudgetDeep';

/// Groupe « préréglages ». Les préréglages eux-mêmes (id, libellé, valeurs)
/// viennent de l'hôte.
const String kZChatLabelPresets = '${kZChatLabelPrefix}presets';

/// Groupe « capacités » — la famille par défaut câblée sur
/// `ZChatGenerationSettings.capabilities`.
const String kZChatLabelCapabilities = '${kZChatLabelPrefix}capabilities';

/// L'unique capacité que le socle nomme : la recherche web
/// (`kZChatCapabilityWebSearch`), champ typé du kernel parce que mesuré
/// fréquent chez plusieurs hôtes. Toute autre capacité vient du catalogue
/// de l'hôte — clé opaque, libellé déjà localisé par lui : le socle n'en
/// connaît aucune valeur.
const String kZChatLabelCapabilityWebSearch =
    '${kZChatLabelPrefix}capabilityWebSearch';

/// Option « aucun préréglage » — restaure l'état d'avant le préréglage.
const String kZChatLabelPresetNone = '${kZChatLabelPrefix}presetNone';

/// État visible « interrupteur actif » du kind `toggle` — le canal textuel
/// non chromatique (une information ne repose jamais sur la seule couleur).
const String kZChatLabelToggleOn = '${kZChatLabelPrefix}toggleOn';

/// État visible « interrupteur inactif » du kind `toggle`.
const String kZChatLabelToggleOff = '${kZChatLabelPrefix}toggleOff';

/// Action « diminuer » du kind `numberBounded`.
const String kZChatLabelDecrease = '${kZChatLabelPrefix}decrease';

/// Action « augmenter » du kind `numberBounded`.
const String kZChatLabelIncrease = '${kZChatLabelPrefix}increase';

/// Étiquette sémantique du sélecteur de modèle d'IA du composer. Générique :
/// aucun nom de modèle n'entre au socle — les options (`ZChatModelOption`)
/// viennent de l'hôte, id opaque + libellé déjà localisé.
const String kZChatLabelModelSelector = '${kZChatLabelPrefix}modelSelector';

/// Étiquette du bandeau de mode édition du composer (`editing` /
/// `startEditing` / `cancelEditing` existent sur le contrôleur — le bandeau
/// les rend).
const String kZChatLabelEditing = '${kZChatLabelPrefix}editing';

/// Action « sortir du mode édition sans soumettre » — le verbe existant
/// `cancelEditing` (jamais un second chemin).
const String kZChatLabelEditingCancel = '${kZChatLabelPrefix}editingCancel';

/// Action « arrêter la génération en cours » — câblée sur le verbe existant
/// `runAction(ZChatCancelAction(requestId:))`.
const String kZChatLabelStopGeneration =
    '${kZChatLabelPrefix}stopGeneration';

/// Déclencheur `+` des pickers de pièces jointes — le socle rend le
/// créneau ; galerie/photo/fichier restent des actions d'hôte (libellés,
/// icônes et gestes injectés).
const String kZChatLabelAttachmentPickers =
    '${kZChatLabelPrefix}attachmentPickers';

/// Déclencheur « outils » de la bande d'accessoires — il ouvre la feuille de
/// réglages (le créneau `tools` est une bande, jamais une page montée
/// inline).
const String kZChatLabelTools = '${kZChatLabelPrefix}tools';

/// Étiquette sémantique de la liste de conversations.
const String kZChatLabelConversations = '${kZChatLabelPrefix}conversations';

/// Annonce de l'état de chargement de la liste (invariant AD-13).
///
/// Sans un état de chargement distinct, un lecteur d'écran ou un
/// utilisateur peut lire « aucune conversation » avant que la moindre
/// donnée soit arrivée. Le chargement doit donc avoir sa propre clé, et son
/// propre état.
const String kZChatLabelLoadingConversations =
    '${kZChatLabelPrefix}loadingConversations';

/// État d'erreur de la liste — distinct de l'état vide : un échec de
/// chargement est indiscernable d'une liste réellement vide sans lui.
const String kZChatLabelConversationsError =
    '${kZChatLabelPrefix}conversationsError';

/// Action « réessayer » après une erreur de liste.
const String kZChatLabelRetry = '${kZChatLabelPrefix}retry';

/// État vide — variante « **aucun élément** ».
const String kZChatLabelNoConversations =
    '${kZChatLabelPrefix}noConversations';

/// État vide — variante « **aucun résultat** » (recherche en cours).
///
/// Les deux variantes sont distinctes parce que l'action qui les accompagne
/// l'est : créer une conversation répond à « la liste est vide », **jamais** à
/// « votre recherche ne rend rien ».
const String kZChatLabelNoResults = '${kZChatLabelPrefix}noResults';

/// Action « nouvelle conversation » — **masquée en recherche**.
const String kZChatLabelNewConversation =
    '${kZChatLabelPrefix}newConversation';

/// Action « charger la suite » — pagination par **curseur**.
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

/// Action « restaurer » — `ZChatConversationLifecyclePort.restore`.
///
/// C'est la capacité que le soft-delete rend possible, et c'est ce qui rend
/// l'annulation triviale à implémenter sans qu'on ait à l'imposer à l'hôte.
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
  kZChatLabelUploading,
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
  kZChatLabelDraftRestored,
  kZChatLabelDismissDraftNotice,
  kZChatLabelComposer,
  kZChatLabelComposerHint,
  kZChatLabelComposerCounter,
  kZChatLabelVoiceSession,
  kZChatLabelVoiceSubmitting,
  kZChatLabelVoiceSpeaking,
  kZChatLabelStopVoiceSession,
  kZChatLabelAffordanceCandidates,
  kZChatLabelAffordanceDismiss,
  kZChatLabelSettings,
  kZChatLabelResponseLength,
  kZChatLabelLengthConcise,
  kZChatLabelLengthStandard,
  kZChatLabelLengthDetailed,
  kZChatLabelLengthBias,
  kZChatLabelBiasShorter,
  kZChatLabelBiasAsIs,
  kZChatLabelBiasLonger,
  kZChatLabelComputeBudget,
  kZChatLabelComputeBudgetLevel,
  kZChatLabelRevealThinking,
  kZChatLabelCorpusScope,
  kZChatLabelCorpusAll,
  kZChatLabelSettingAuto,
  kZChatLabelGenerated,
  kZChatLabelArtifacts,
  kZChatLabelArtifactCreate,
  kZChatLabelArtifactOpen,
  kZChatLabelArtifactRegenerate,
  kZChatLabelArtifactEdit,
  kZChatLabelArtifactDelete,
  kZChatLabelArtifactEmpty,
  kZChatLabelArtifactBusy,
  kZChatLabelArtifactCount,
  kZChatLabelArtifactConfirmPrompt,
  kZChatLabelArtifactActivatePrompt,
  kZChatLabelArtifactConfirm,
  kZChatLabelArtifactCancel,
  kZChatLabelSend,
  kZChatLabelSendBusy,
  kZChatLabelSendEdit,
  kZChatLabelComposerStatus,
  kZChatLabelSettingsReset,
  kZChatLabelSettingsClose,
  kZChatLabelComputeBudgetFast,
  kZChatLabelComputeBudgetBalanced,
  kZChatLabelComputeBudgetDeep,
  kZChatLabelPresets,
  kZChatLabelPresetNone,
  kZChatLabelCapabilities,
  kZChatLabelCapabilityWebSearch,
  kZChatLabelToggleOn,
  kZChatLabelToggleOff,
  kZChatLabelDecrease,
  kZChatLabelIncrease,
  kZChatLabelModelSelector,
  kZChatLabelEditing,
  kZChatLabelEditingCancel,
  kZChatLabelStopGeneration,
  kZChatLabelAttachmentPickers,
  kZChatLabelTools,
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

/// Repli lisible de chaque clé — jamais prioritaire sur l'hôte.
///
/// La langue est le français, comme le reste des replis du dépôt : deux
/// conventions de repli dans un même socle multi-consommateurs coûteraient
/// plus qu'une langue de secours unique. L'hôte qui traduit passe
/// `ZcrudScope(labels:)` — le repli n'est jamais atteint dans ce cas
/// (`label()` ne le consulte qu'en dernier ressort).
///
/// Cette table couvre exactement l'ensemble de [kZChatLabelKeys] — jamais
/// une inclusion partielle.
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
  kZChatLabelUploading: 'Téléversement en cours',
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
  kZChatLabelDraftRestored: 'Brouillon restauré',
  kZChatLabelDismissDraftNotice: 'Masquer l\'indication',
  kZChatLabelComposer: 'Zone de saisie',
  kZChatLabelComposerCounter: 'Longueur de la saisie',
  kZChatLabelVoiceSession: 'Mode vocal',
  kZChatLabelVoiceSubmitting: 'Envoi du message dicté',
  kZChatLabelVoiceSpeaking: 'Lecture de la réponse',
  kZChatLabelStopVoiceSession: 'Arrêter le mode vocal',
  kZChatLabelAffordanceCandidates: 'Candidats',
  kZChatLabelAffordanceDismiss: 'Fermer la liste',
  kZChatLabelComposerHint: 'Écrivez votre message',
  kZChatLabelSettings: 'Réglages de génération',
  kZChatLabelResponseLength: 'Longueur de réponse',
  kZChatLabelLengthConcise: 'Concise',
  kZChatLabelLengthStandard: 'Standard',
  kZChatLabelLengthDetailed: 'Détaillée',
  kZChatLabelLengthBias: 'Régénération',
  kZChatLabelBiasShorter: 'Plus court',
  kZChatLabelBiasAsIs: 'Tel quel',
  kZChatLabelBiasLonger: 'Plus long',
  kZChatLabelComputeBudget: 'Budget de calcul',
  kZChatLabelComputeBudgetLevel: 'Niveau $kZChatCountPlaceholder',
  kZChatLabelRevealThinking: 'Afficher le raisonnement',
  kZChatLabelCorpusScope: 'Portée documentaire',
  kZChatLabelCorpusAll: 'Tous les corpus',
  kZChatLabelSettingAuto: 'Automatique',
  kZChatLabelGenerated: 'Déjà généré',
  kZChatLabelArtifacts: 'Artefacts',
  kZChatLabelArtifactCreate: 'Créer',
  kZChatLabelArtifactOpen: 'Ouvrir',
  kZChatLabelArtifactRegenerate: 'Régénérer',
  kZChatLabelArtifactEdit: 'Modifier',
  kZChatLabelArtifactDelete: 'Supprimer',
  kZChatLabelArtifactEmpty: 'Aucun contenu',
  kZChatLabelArtifactBusy: 'Génération en cours',
  kZChatLabelArtifactCount: '$kZChatCountPlaceholder élément(s)',
  kZChatLabelArtifactConfirmPrompt: 'Confirmer cette action ?',
  kZChatLabelArtifactActivatePrompt: 'Lancer cette action ?',
  kZChatLabelArtifactConfirm: 'Confirmer',
  kZChatLabelArtifactCancel: 'Annuler',
  kZChatLabelSend: 'Envoyer',
  kZChatLabelSendBusy: 'Envoi en préparation',
  kZChatLabelSendEdit: 'Valider la modification',
  kZChatLabelComposerStatus: 'État',
  kZChatLabelSettingsReset: 'Réinitialiser',
  kZChatLabelSettingsClose: 'Fermer',
  kZChatLabelComputeBudgetFast: 'Rapide',
  kZChatLabelComputeBudgetBalanced: 'Équilibré',
  kZChatLabelComputeBudgetDeep: 'Profond',
  kZChatLabelPresets: 'Préréglages',
  kZChatLabelPresetNone: 'Aucun',
  kZChatLabelCapabilities: 'Capacités',
  kZChatLabelCapabilityWebSearch: 'Recherche web',
  kZChatLabelToggleOn: 'Activé',
  kZChatLabelToggleOff: 'Désactivé',
  kZChatLabelDecrease: 'Diminuer',
  kZChatLabelIncrease: 'Augmenter',
  kZChatLabelModelSelector: 'Modèle',
  kZChatLabelEditing: 'Modification en cours',
  kZChatLabelEditingCancel: 'Annuler la modification',
  kZChatLabelStopGeneration: 'Arrêter la génération',
  kZChatLabelAttachmentPickers: 'Ajouter',
  kZChatLabelTools: 'Outils',
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

/// Marqueur de substitution du compte, dans un repli comme dans une
/// traduction d'hôte.
///
/// Il est déclaré ici, à côté des replis qui le portent, et consommé par un
/// seul site ([zChatCountLabel]). Un hôte qui traduit `zchat.timeMinutes`
/// garde le marqueur dans sa chaîne ; s'il l'omet, le compte n'apparaît
/// simplement pas — aucune exception, aucun texte cassé (invariant AD-10).
const String kZChatCountPlaceholder = '{n}';

/// Résout [key] et y substitue [count] à [kZChatCountPlaceholder].
String zChatCountLabel(BuildContext context, String key, int count) =>
    zChatLabel(context, key).replaceAll(kZChatCountPlaceholder, '$count');

/// Formate un horodatage **relatif** — couture d'hôte.
///
/// [now] est passé explicitement : un formateur qui lit l'horloge lui-même
/// n'est pas testable, et deux lignes d'une même liste peuvent alors se référer
/// à deux instants différents.
typedef ZChatRelativeTimeFormatter =
    String Function(BuildContext context, DateTime value, DateTime now);

/// Formateur par défaut — buckets grossiers, entièrement résolus par clés.
///
/// Aucune locale, aucun mot en dur : un mot écrit en toutes lettres dans une
/// langue fixe resterait dans cette langue quelle que soit celle de
/// l'application — et deux points d'un même écran qui appliquent des
/// conventions différentes feraient changer la langue d'un même contenu
/// selon l'endroit où on le regarde.
///
/// Ici, chaque bucket est une clé : un hôte qui alimente son registre
/// obtient sa langue, et un hôte qui veut un paquet de formatage de dates
/// dédié passe son propre [ZChatRelativeTimeFormatter]. Le socle, lui, ne
/// dépend d'aucun paquet de dates.
String zChatDefaultRelativeTime(
  BuildContext context,
  DateTime value,
  DateTime now,
) {
  final Duration d = now.difference(value);
  // Une date future (horloge décalée, écriture serveur en avance) ne devient
  // jamais « il y a -3 min » : elle se lit « à l'instant » (invariant AD-10).
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

/// Résout une clé du chat — l'unique site d'appel de `label()` du paquet.
///
/// Passer par cette fonction plutôt que par `label(context, clé)` n'est pas
/// une préférence de style : c'est ce qui rend impossible d'ajouter une clé
/// sans repli.
String zChatLabel(BuildContext context, String key) =>
    label(context, key, fallback: kZChatLabelFallbacks[key]);
