/// Le composer socle partagé.
///
/// ## Ce que ce widget résout
///
/// Ni `ZChatConversationView` ni `ZChatNotebookView` ne montent de zone de
/// saisie par elles-mêmes : les deux surfaces partagent la fabrique de tuile
/// et rien d'autre. Ce fichier fournit le widget manquant qui rend
/// `ZChatController.composer` — le contrôleur, lui, existait déjà :
/// `ZChatController.composer` est un `TextEditingController` public, écrit
/// par un site unique. Ce fichier ne crée aucun contrôleur d'état de saisie
/// et n'ajoute aucun membre à `ZChatController` : il lit et lie la tranche
/// existante.
///
/// ## Aucun nouveau chemin d'exécution
///
/// L'envoi passe par [ZChatController.send] — le verbe existant — et par lui
/// seul. Le socle n'expose pas un `onSend` que l'hôte câblerait lui-même : il
/// fournit la fermeture [ZChatComposerSlot.submit], si bien que le bouton
/// d'envoi de l'hôte et la touche « valider » du clavier empruntent
/// littéralement le même site d'appel. C'est la forme locale de l'invariant
/// « un verbe = un seul site d'appel » qui fonde tout ce paquet.
///
/// ## La touche Entrée
///
/// Un champ multiligne ne déclenche jamais `onSubmitted` : le raccourci
/// clavier est donc porté par une table de `Shortcuts` — Entrée soumet,
/// Maj+Entrée et Ctrl+Entrée insèrent une nouvelle ligne, et rien de tout
/// cela ne s'applique sur une plateforme tactile. La table invoque la MÊME
/// fermeture que le bouton d'envoi. Cf. [ZChatComposer.submitPolicy].
///
/// ## Les créneaux, leur RANG, et pourquoi ce sont des builders
///
/// Tout vit dans une seule `Column`, à un rang fixe. C'est le rang — et non
/// le voisinage — qui tient la promesse de disposition : un créneau qui
/// grandit (une vignette de plus, une bande d'état qui apparaît) **pousse le
/// champ** sans jamais sortir du cadre, parce que le cadre est son parent.
///
/// ```
/// ZChatComposer
///   0 status         annonce   <- hors ligne / quota / erreur
///   1 editingBanner  annonce   <- « vous modifiez ce message »
///   2 progress       annonce   <- progression d'un televersement
///   3 suggestions    proposition
///   4 attachments    proposition  <- apercu des pieces jointes
///   5 capture        proposition  <- le `ZChatCaptureBar` EXISTANT
///   6 Row [ leading | champ + hint | trailing ]   <- l'ANCRE
///   7 tools          accessoire   <- acces aux reglages
///   8 counter        accessoire   <- compteur de caracteres / jetons
/// ```
///
/// L'ordre n'est pas décoratif. Les rangs 0-2 sont des **annonces** : elles
/// doivent rester visibles et ne jamais être poussées hors du cadre. Les
/// rangs 3-5 sont des **propositions** : elles poussent le champ vers le bas
/// quand elles apparaissent. Le rang 6 est l'**ancre** : il ne bouge jamais
/// du bas, clavier monté ou non. Les rangs 7-8 sont des **accessoires** :
/// ils suivent l'ancre.
///
/// Deux paramètres seulement font varier cette disposition, et aucun n'est un
/// second arbre : [sendAlignment] choisit où l'envoi se pose sur la hauteur
/// du champ, [bandPlacement] échange les rangs 6 et 7.
///
/// Contrainte imposée à tout créneau monté ici : hauteur **minimale**, jamais
/// fixe, et débordement scrollable **à l'intérieur du rang** — sans quoi le
/// rang cesse de pousser et se met à déborder.
///
/// Invariant AD-4 : un créneau nul — ou un créneau dont le builder rend
/// `null` — est absent de l'arbre, jamais un `SizedBox.shrink()` inerte. Un
/// hôte qui ne fournit que `capture`, la `Row` et `tools` obtient donc
/// exactement l'arbre à trois enfants d'hier, au widget près.
///
/// Un builder plutôt qu'un `Widget` figé, et un objet [ZChatComposerSlot]
/// plutôt qu'une liste de paramètres positionnels : c'est ce qui rend
/// accueillables, sans rupture, des mécanismes que le socle n'a pas encore
/// (contexte d'outils pré-expert, cycle de raisonnement, mode édition,
/// brouillon à compteur, remise à zéro). Chacun deviendra un champ de plus
/// sur [ZChatComposerSlot] — strictement additif — au lieu d'un booléen figé
/// de plus dans la signature.
///
/// ## Invariant AD-13 — la cible d'envoi
///
/// [leading] et [trailing] sont posés dans une boîte de
/// [kZChatMinTapTarget] bornée des deux côtés : le plancher vient du
/// `ConstrainedBox`, la borne haute de la disposition (le champ est le seul
/// enfant flexible de la `Row`). Cf. le dartdoc de [_ZChatComposerTarget],
/// qui explique précisément ce que les `widthFactor`/`heightFactor` font et
/// ne font pas ici.
///
/// ## Invariant AD-2 — ce que ce fichier ne fait pas
///
/// * il ne crée aucun `TextEditingController` (celui du contrôleur est
///   stable et vit aussi longtemps que lui) ;
/// * il n'abonne rien au canal du composer au-dessus du champ : le seul
///   abonnement à la frappe est [_ZChatComposerHint], une feuille qui rend un
///   `Text` — ni la liste des messages, ni les créneaux de l'hôte n'en
///   dépendent ;
/// * il n'appelle jamais `setState`.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../attachment/z_chat_attachment_controller.dart';
import '../capture/z_chat_capture_controller.dart';
import '../capture/z_chat_voice_session_controller.dart';
import '../settings/z_chat_settings_controller.dart';
import '../tools/z_chat_tool_controller.dart';
import '../z_chat_controller.dart';
import 'z_chat_composer_affordance.dart';
import 'z_chat_composer_history.dart';
import 'z_chat_composer_keys.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;
import 'z_chat_voice_session_banner.dart';

/// Ce que le socle offre à un créneau du composer.
///
/// Un objet, pas une liste d'arguments. Les mécanismes que le socle n'a pas
/// encore (mode édition, brouillon à compteur, cycle de raisonnement…)
/// s'ajouteront ici en champs supplémentaires, sans changer la signature de
/// [ZChatComposerSlotBuilder] — donc sans casser un seul hôte.
@immutable
class ZChatComposerSlot {
  /// Construit le contexte d'un créneau.
  const ZChatComposerSlot({
    required this.controller,
    required this.submit,
    this.settings,
    this.attachments,
    this.tools,
    this.capture,
    this.compact = false,
  });

  /// Le contrôleur de la conversation — l'hôte y lit les tranches réactives
  /// (`canSend`, `attachmentIds`, `activeRequests`…) et y pose ses propres
  /// `ValueListenableBuilder`. Le socle n'en impose aucun : un créneau qui ne
  /// réagit à rien n'est jamais reconstruit (invariant AD-2).
  final ZChatController controller;

  /// Soumet la saisie courante — l'unique chemin d'envoi du composer.
  ///
  /// C'est la même fermeture que celle branchée sur la touche « valider » du
  /// clavier. Un hôte qui appellerait `controller.send()` de son côté
  /// créerait un second site d'appel : le socle le lui évite en le lui
  /// donnant.
  ///
  /// Sans objet quand la saisie est vide et sans pièce jointe : l'appel est
  /// alors sans effet (le refus reste celui de `send()`, jamais un second).
  final VoidCallback submit;

  /// Les réglages de génération du composer, ou `null` si l'hôte n'en a pas
  /// branché.
  ///
  /// C'est le premier des « champs de plus » que ce type a été conçu pour
  /// accueillir. Il est ici pour que la feuille montée dans le créneau
  /// `tools` écrive dans le contrôleur que le composer soumettra — et non
  /// dans un second, qui laisserait des réglages affichés, réglés, puis
  /// jetés avant l'appel.
  final ZChatSettingsController? settings;

  /// Les pièces jointes en attente, ou `null` si l'hôte n'en a branché
  /// aucune.
  ///
  /// Le même motif que [settings], pour la même raison : l'aperçu du rang 4
  /// et le menu `+` du créneau de tête lisent **la même** instance. Deux
  /// contrôleurs donneraient une bande qui montre des pièces que l'envoi
  /// n'emporte pas.
  final ZChatAttachmentController? attachments;

  /// Le catalogue d'outils, ou `null` si l'hôte n'en a branché aucun.
  ///
  /// La bande d'accessoires et la feuille qu'elle ouvre lisent le même
  /// catalogue : un outil activé dans la feuille est celui que la bande
  /// montre actif.
  final ZChatToolController? tools;

  /// La dictée et la reconnaissance de texte, ou `null` si l'hôte n'en a
  /// branché aucune.
  ///
  /// La saisie n'a qu'un écrivain hors du contrôleur de conversation, et
  /// c'est celui-ci : le partager par le créneau évite qu'un second
  /// apparaisse pour un geste posé ailleurs dans le cadre.
  final ZChatCaptureController? capture;

  /// `true` demande à un créneau sa forme resserrée (typiquement mobile).
  ///
  /// Résolu **une fois**, en amont, et distribué à tous les créneaux : chaque
  /// pièce mesurant la largeur de son côté finirait par basculer à un point
  /// différent de sa voisine.
  final bool compact;
}

/// Où l'envoi se pose sur la hauteur du champ de saisie.
///
/// Ce n'est pas un mode et cela ne produit pas un second arbre : c'est
/// l'alignement transversal de la seule `Row` du composer.
enum ZChatComposerSendAlignment {
  /// L'envoi suit le **bas** du champ — il reste sur la dernière ligne quand
  /// la saisie grandit. C'est le défaut.
  bottom,

  /// L'envoi reste **centré** sur la hauteur du champ, quel que soit le
  /// nombre de lignes.
  center,
}

/// De quel côté du champ la bande d'accessoires se pose.
///
/// Les deux valeurs décrivent le même arbre : seuls deux enfants de la
/// `Column` échangent leur rang.
enum ZChatComposerBandPlacement {
  /// La bande suit le champ — elle reste sous l'ancre. C'est le défaut.
  below,

  /// La bande précède le champ — elle passe au-dessus de l'ancre, sans
  /// changer sa position relative aux créneaux qui la précèdent déjà.
  above,
}

/// Construit le contenu d'un créneau du composer.
///
/// Rendre `null` signifie aucun widget inséré (invariant AD-4). C'est ce qui
/// permet à un même builder de ne monter son affordance que dans certaines
/// conditions — sans que le socle ait à porter un booléen par cas.
typedef ZChatComposerSlotBuilder =
    Widget? Function(BuildContext context, ZChatComposerSlot slot);

/// Rend la zone de saisie d'un [ZChatController] — zéro dépendance tierce.
///
/// Le widget est monté par les deux surfaces (`ZChatConversationView` et
/// `ZChatNotebookView`) par une fabrique unique, exactement comme la tuile
/// de message : une régression ici affecte les deux.
class ZChatComposer extends StatefulWidget {
  /// Construit le composer.
  const ZChatComposer({
    required this.controller,
    required this.cursorColor,
    this.status,
    this.editingBanner,
    this.progress,
    this.suggestions,
    this.attachments,
    this.leading,
    this.trailing,
    this.tools,
    this.capture,
    this.counter,
    this.hint,
    this.settings,
    this.attachmentController,
    this.toolController,
    this.captureController,
    this.compact = false,
    this.sendAlignment = ZChatComposerSendAlignment.bottom,
    this.bandPlacement = ZChatComposerBandPlacement.below,
    this.focusNode,
    this.padding,
    this.minLines = 1,
    this.maxLines = 5,
    this.submitPolicy = ZChatComposerSubmitPolicy.standard,
    this.history,
    this.affordance,
    this.voice,
    super.key,
  });

  /// Le contrôleur dont la saisie est rendue. Il n'est ni créé ni disposé
  /// ici : son cycle de vie appartient à l'hôte (invariant AD-2).
  final ZChatController controller;

  /// Couleur du curseur — fournie par l'hôte.
  ///
  /// `EditableText` exige une couleur non nulle et ce paquet n'a le droit
  /// d'en inventer aucune. Entre inventer une couleur et la demander, ce
  /// paquet demande — c'est le même arbitrage, déjà tranché, que
  /// `ZChatCaptureReviewField.cursorColor`.
  final Color cursorColor;

  /// Créneau d'annonce — rang 0, tout en haut du cadre.
  ///
  /// C'est la place d'un état qui concerne la conversation entière et qui ne
  /// doit jamais quitter l'écran : hors ligne, quota atteint, dernier envoi
  /// refusé. Il est au-dessus de tout le reste précisément pour qu'aucune
  /// proposition n'ait le pouvoir de le pousser dehors.
  ///
  /// `null` signifie absent (invariant AD-4).
  final ZChatComposerSlotBuilder? status;

  /// Créneau du bandeau d'édition — rang 1.
  ///
  /// « Vous modifiez ce message », et l'abandon qui va avec. Il a son propre
  /// rang, distinct de [capture] : le bandeau et la dictée sont deux
  /// mécanismes sans rapport, et un hôte qui affiche les deux ne doit pas
  /// choisir lequel montrer.
  ///
  /// `null` signifie absent (invariant AD-4).
  final ZChatComposerSlotBuilder? editingBanner;

  /// Créneau de progression — rang 2.
  ///
  /// La progression d'un téléversement en cours, indéterminée ou chiffrée.
  /// Elle est une annonce, pas une proposition : elle reste visible tant que
  /// le transfert dure.
  ///
  /// `null` signifie absent (invariant AD-4).
  final ZChatComposerSlotBuilder? progress;

  /// Créneau des suggestions — rang 3.
  ///
  /// Amorces de conversation et relances proposées après une réponse. C'est
  /// la première des propositions : elle pousse le champ vers le bas quand
  /// elle apparaît, et le laisse remonter quand elle disparaît.
  ///
  /// `null` signifie absent (invariant AD-4).
  final ZChatComposerSlotBuilder? suggestions;

  /// Créneau d'aperçu des pièces jointes — rang 4.
  ///
  /// Les vignettes des pièces en attente, **dans** le cadre : c'est ce rang
  /// qui fait qu'une pièce ajoutée pousse le champ au lieu de déborder de la
  /// boîte. Le contenu monté ici et le menu `+` de [leading] doivent lire le
  /// même [ZChatComposerSlot.attachments].
  ///
  /// `null` signifie absent (invariant AD-4).
  final ZChatComposerSlotBuilder? attachments;

  /// Créneau de tête — pièces jointes, menu `+`. `null` signifie absent
  /// (invariant AD-4).
  final ZChatComposerSlotBuilder? leading;

  /// Créneau de queue — l'envoi. `null` signifie absent (invariant AD-4) ;
  /// la touche « valider » du clavier reste alors le seul déclencheur.
  final ZChatComposerSlotBuilder? trailing;

  /// Créneau des réglages — la bande d'accessoires, rang 7. `null` signifie
  /// absent.
  ///
  /// Elle suit l'ancre par défaut ; [bandPlacement] la fait passer devant.
  final ZChatComposerSlotBuilder? tools;

  /// Créneau de capture — rang 5, juste au-dessus du champ, où l'hôte branche
  /// le [ZChatCaptureBar] existant (dictée/reconnaissance de texte).
  ///
  /// Un hôte qui y empilait aussi son bandeau d'édition a désormais
  /// [editingBanner] pour cela ; ce créneau-ci n'a pas changé de
  /// comportement.
  final ZChatComposerSlotBuilder? capture;

  /// Créneau du compteur — rang 8, tout en bas du cadre.
  ///
  /// Caractères restants, jetons estimés, indication de brouillon
  /// enregistré : ce qui commente la saisie sans la commander. Dernier rang
  /// parce qu'il suit l'ancre, et non l'inverse.
  ///
  /// `null` signifie absent (invariant AD-4).
  final ZChatComposerSlotBuilder? counter;

  /// Créneau du placeholder visuel. Règle des trois cas, la même que les
  /// tuiles de `ZChatSettingsSheet` :
  ///
  /// | Builder | Effet |
  /// |---|---|
  /// | absent (`null`) | l'invite par défaut du socle (le libellé résolu) |
  /// | fourni, rend un widget | ce widget remplace l'invite |
  /// | fourni, rend `null` | aucune invite visuelle (invariant AD-4) |
  ///
  /// Quel que soit le cas, le rendu reste `ExcludeSemantics` +
  /// `IgnorePointer` et sa visibilité reste pilotée par la vacuité de la
  /// saisie : le libellé du champ pour un lecteur d'écran ne change pas, et
  /// le seul abonnement à la frappe reste celui de l'invite (invariant
  /// AD-2).
  final ZChatComposerSlotBuilder? hint;

  /// Réglages de génération soumis avec la saisie. `null` signifie le
  /// comportement par défaut : `send()` est appelé sans argument, donc le
  /// port reçoit l'objet même que le builder de l'hôte a construit.
  ///
  /// Le créneau `tools` et ce champ vont ensemble. Un hôte qui monte une
  /// feuille de réglages dans `tools` sans passer ici le même
  /// [ZChatSettingsController] afficherait des réglages qui n'atteindraient
  /// jamais la requête. Le socle donne le contrôleur au créneau
  /// ([ZChatComposerSlot.settings]) précisément pour que l'hôte n'ait jamais
  /// à en fabriquer un second.
  ///
  /// Renseigné, il gouverne les quatre réglages : un porteur vide les remet
  /// à « l'hôte décide », y compris ceux qu'aurait posés le
  /// `ZChatRequestBuilder`. C'est la règle de remplacement du kernel, et
  /// c'est ce qui rend un réglage retirable depuis la feuille.
  final ZChatSettingsController? settings;

  /// Les pièces jointes en attente, offertes à **tous** les créneaux par
  /// [ZChatComposerSlot.attachments]. `null` signifie qu'aucune n'est
  /// branchée.
  ///
  /// Le composer ne s'y abonne pas et n'en rend rien : il le distribue, pour
  /// que l'aperçu et le menu `+` ne puissent pas lire deux instances.
  final ZChatAttachmentController? attachmentController;

  /// Le catalogue d'outils, offert à tous les créneaux par
  /// [ZChatComposerSlot.tools]. `null` signifie qu'aucun n'est branché.
  final ZChatToolController? toolController;

  /// La dictée et la reconnaissance de texte, offertes à tous les créneaux
  /// par [ZChatComposerSlot.capture]. `null` signifie qu'aucune n'est
  /// branchée.
  final ZChatCaptureController? captureController;

  /// Forme resserrée demandée aux créneaux (typiquement mobile).
  ///
  /// Résolue par l'hôte — le composer ne mesure aucune largeur — et
  /// distribuée telle quelle par [ZChatComposerSlot.compact], pour que
  /// toutes les pièces basculent au même point.
  final bool compact;

  /// Où l'envoi se pose sur la hauteur du champ. Défaut :
  /// [ZChatComposerSendAlignment.bottom], l'alignement d'origine.
  final ZChatComposerSendAlignment sendAlignment;

  /// De quel côté du champ la bande [tools] se pose. Défaut :
  /// [ZChatComposerBandPlacement.below], le placement d'origine.
  final ZChatComposerBandPlacement bandPlacement;

  /// Nœud de focus de l'hôte. `null` signifie que le composer en possède un,
  /// créé une fois et disposé avec lui (jamais dans un `build` — interdit
  /// par l'invariant AD-2).
  final FocusNode? focusNode;

  /// Marge directionnelle (invariant AD-13). `null` signifie
  /// `ZcrudTheme.formPadding`.
  final EdgeInsetsDirectional? padding;

  /// Hauteur minimale du champ, en lignes.
  final int minLines;

  /// Hauteur maximale du champ, en lignes.
  final int maxLines;

  /// Ce que la touche Entrée fait dans le champ.
  ///
  /// Par défaut, et sur bureau et Web seulement : **Entrée soumet**,
  /// **Maj+Entrée** et **Ctrl+Entrée** insèrent une nouvelle ligne. Sur une
  /// plateforme tactile, Entrée insère une nouvelle ligne — un clavier
  /// virtuel n'a pas de modificateur. Cf. [ZChatComposerSubmitPolicy] pour la
  /// convention inverse et pour le retrait du raccourci.
  ///
  /// Le raccourci n'ouvre aucun second chemin d'envoi : il emprunte le site
  /// de soumission unique du composer, celui de [ZChatComposerSlot.submit].
  final ZChatComposerSubmitPolicy submitPolicy;

  /// Le rappel d'historique sur **flèche haut**.
  ///
  /// `null` — le défaut — signifie qu'aucun rappel n'est monté : la flèche
  /// haut garde intégralement son sens de navigation, et l'arbre du champ est
  /// celui d'un composer sans ce geste.
  ///
  /// Branché, il n'agit **que sur un champ vide** : dès qu'un caractère est
  /// saisi, la touche redevient une navigation (cf.
  /// [ZChatComposerHistoryPort]).
  final ZChatComposerHistoryPort? history;

  /// Les déclencheurs de contexte (`@`, `/`) et leur panneau de candidats.
  ///
  /// `null` — le défaut — signifie qu'aucun déclencheur n'est monté : la
  /// saisie ne reconnaît rien, aucune touche ne change de sens, et l'arbre du
  /// champ est celui d'un composer sans cette mécanique.
  ///
  /// Branché, il ajoute quatre gestes **au clavier seulement quand un panneau
  /// est ouvert** : flèches haut/bas pour parcourir, Entrée pour retenir,
  /// Échap pour fermer. Panneau fermé, ces touches retrouvent leur sens — y
  /// compris Entrée, qui redevient le raccourci d'envoi.
  final ZChatComposerAffordanceController? affordance;

  /// La session vocale continue, ou `null`.
  ///
  /// `null` — le défaut — signifie qu'aucune session n'est montée : rien n'est
  /// ajouté à l'arbre, aucune touche ne change de sens, et le composer est
  /// **à l'octet** celui d'hier.
  ///
  /// Branchée, elle ajoute deux choses, et rien d'autre :
  ///
  /// * le bandeau d'annonce de la phase, au rang 5 (à côté de la capture, dont
  ///   la session est le mode continu) ;
  /// * une couche de clavier qui **arrête la session à la première frappe** —
  ///   elle ne consomme aucune touche : l'événement poursuit sa route intact
  ///   vers les gestes, le raccourci d'envoi et la saisie.
  ///
  /// La destruction de ce widget arrête la session : une boucle vocale dont la
  /// zone de saisie a disparu n'a plus de destination pour sa transcription, et
  /// laisser le micro ouvert derrière un écran fermé est le défaut que cette
  /// mécanique doit rendre impossible.
  final ZChatVoiceSessionController? voice;

  @override
  State<ZChatComposer> createState() => _ZChatComposerState();
}

class _ZChatComposerState extends State<ZChatComposer> {
  /// Créé une fois — jamais au rebuild (invariant AD-2). Utilisé seulement
  /// si l'hôte n'a pas fourni le sien ; disposé dans tous les cas puisqu'il
  /// nous appartient.
  final FocusNode _owned = FocusNode();

  @override
  void dispose() {
    // La session est arrêtée parce que ce widget disparaît : c'est le seul
    // moment où il sait encore qu'elle existe. `stop()` est best-effort et ne
    // lève jamais (invariant AD-10).
    //
    // DIFFÉRÉ d'une microtâche, et ce n'est pas une précaution de style :
    // `dispose` s'exécute pendant que l'arbre est VERROUILLÉ, et l'arrêt fait
    // retomber une tranche que le bandeau écoute encore. Arrêter ici même fait
    // lever « markNeedsBuild called when widget tree was locked » — sur le
    // chemin le plus nominal qui soit : fermer l'écran pendant que le micro
    // écoute. La microtâche s'exécute une fois l'arbre déverrouillé, quand le
    // bandeau s'est déjà désabonné.
    final ZChatVoiceSessionController? session = widget.voice;
    if (session != null) scheduleMicrotask(() => unawaited(session.stop()));
    _owned.dispose();
    super.dispose();
  }

  /// Arrête la session à la première frappe, sans rien consommer.
  ///
  /// `KeyEventResult.ignored` est structurel : cette couche observe le
  /// clavier, elle ne l'intercepte pas. Une frappe traverse donc les gestes,
  /// le raccourci d'envoi et la saisie exactement comme sans session.
  KeyEventResult _onComposerKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      unawaited(widget.voice?.stop() ?? Future<void>.value());
    }
    return KeyEventResult.ignored;
  }

  /// L'unique site de soumission du composer.
  ///
  /// Il ne fabrique aucune requête, ne compose aucun prompt et n'invente
  /// aucun verbe : il appelle le `send()` existant du contrôleur. Le
  /// garde-fou `canSend` n'est pas un second refus — c'est la même condition
  /// que celle de `send()`, lue en amont pour ne pas salir `lastFailure` sur
  /// un geste vide.
  void _submit() {
    if (!widget.controller.canSend.value) return;
    // Les réglages sont lus au moment de l'envoi, jamais capturés au
    // montage : la feuille a pu être ouverte, réglée et refermée entre-temps.
    // `settings == null` donne un appel sans argument — le défaut, à
    // l'octet près.
    final ZChatSettingsController? tools = widget.settings;
    unawaited(
      widget.controller.send(
        settings: tools?.settings.value,
        corpusScope: tools?.corpusScope.value,
      ),
    );
  }

  /// Résout un créneau. `null` (builder absent ou builder rendant `null`)
  /// signifie que le créneau est absent de l'arbre (invariant AD-4).
  Widget? _slot(BuildContext context, ZChatComposerSlotBuilder? builder) =>
      builder?.call(
        context,
        ZChatComposerSlot(
          controller: widget.controller,
          submit: _submit,
          settings: widget.settings,
          attachments: widget.attachmentController,
          tools: widget.toolController,
          capture: widget.captureController,
          compact: widget.compact,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    // Résolus dans l'ORDRE DES RANGS — c'est la seule liste où l'ordre du
    // cadre est écrit, et elle se lit de haut en bas comme le rendu.
    final Widget? status = _slot(context, widget.status);
    final Widget? editingBanner = _slot(context, widget.editingBanner);
    final Widget? progress = _slot(context, widget.progress);
    final Widget? suggestions = _slot(context, widget.suggestions);
    final Widget? attachments = _slot(context, widget.attachments);
    final Widget? capture = _slot(context, widget.capture);
    final Widget? leading = _slot(context, widget.leading);
    final Widget? trailing = _slot(context, widget.trailing);
    final Widget? tools = _slot(context, widget.tools);
    final Widget? counter = _slot(context, widget.counter);
    // Règle des trois cas du créneau `hint` (cf. son dartdoc) : la distinction
    // « builder absent » / « builder rendant null » se lit ici, jamais dans le
    // champ.
    final Widget? hostHint = _slot(context, widget.hint);
    final bool suppressHint = widget.hint != null && hostHint == null;

    // Le rang 6 — l'ancre. Extrait pour que [bandPlacement] puisse échanger
    // sa place avec celle de la bande sans dupliquer la disposition : il n'y
    // a qu'UNE `Row` dans ce fichier, quel que soit le placement.
    final Widget anchor = Row(
      crossAxisAlignment: switch (widget.sendAlignment) {
        // Les affordances suivent le BAS du champ quand il grandit.
        ZChatComposerSendAlignment.bottom => CrossAxisAlignment.end,
        ZChatComposerSendAlignment.center => CrossAxisAlignment.center,
      },
      children: <Widget>[
        if (leading != null) _ZChatComposerTarget(child: leading),
        Expanded(
          child: _ZChatComposerField(
            controller: widget.controller,
            focusNode: widget.focusNode ?? _owned,
            cursorColor: widget.cursorColor,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            hint: hostHint,
            suppressHint: suppressHint,
            // Le MÊME site de soumission que celui du créneau d'envoi.
            onSubmit: _submit,
            submitPolicy: widget.submitPolicy,
            history: widget.history,
            affordance: widget.affordance,
          ),
        ),
        if (trailing != null) _ZChatComposerTarget(child: trailing),
      ],
    );
    final ZChatVoiceSessionController? voice = widget.voice;
    // La couche de clavier de la session : ancêtre du champ dans l'arbre de
    // focus, donc elle VOIT chaque frappe qui atteint la saisie — et elle la
    // laisse passer (`KeyEventResult.ignored`). Sans session, `anchor` est
    // rendue telle quelle.
    final Widget anchorRow = voice == null
        ? anchor
        : Focus(
            // Elle observe, elle ne prend jamais le focus : sans ces deux
            // réglages, une couche invisible s'insérerait dans le parcours au
            // clavier et volerait une tabulation au champ.
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onComposerKey,
            child: anchor,
          );
    final bool bandAbove =
        widget.bandPlacement == ZChatComposerBandPlacement.above;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, kZChatLabelComposer),
      child: Padding(
        padding: widget.padding ?? theme.formPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          // LES NEUF RANGS. Un créneau absent n'occupe RIEN — pas même un
          // enfant de taille nulle (invariant AD-4) : l'hôte qui n'en fournit
          // aucun retrouve l'arbre à trois enfants d'hier.
          children: <Widget>[
            ?status, // 0 — annonce
            ?editingBanner, // 1 — annonce
            ?progress, // 2 — annonce
            ?suggestions, // 3 — proposition
            ?attachments, // 4 — proposition
            // 5 — proposition : la session vocale annonce sa phase à côté de
            // la capture, dont elle est le mode continu.
            if (voice != null) ZChatVoiceSessionBanner(controller: voice),
            ?capture, // 5 — proposition
            if (bandAbove && tools != null) tools, // 7, remonté devant l'ancre
            anchorRow, // 6 — l'ancre
            if (!bandAbove && tools != null) tools, // 7 — accessoire
            ?counter, // 8 — accessoire
          ],
        ),
      ),
    );
  }
}

/// Le champ lui-même — il lie `controller.composer`, il ne le remplace pas.
///
/// Aucune écriture de la saisie ici (`composer.text = …` n'apparaît nulle
/// part) : le seul écrivain hors du contrôleur reste
/// `ZChatCaptureController.acceptInto`.
class _ZChatComposerField extends StatelessWidget {
  const _ZChatComposerField({
    required this.controller,
    required this.focusNode,
    required this.cursorColor,
    required this.minLines,
    required this.maxLines,
    required this.onSubmit,
    required this.submitPolicy,
    this.hint,
    this.suppressHint = false,
    this.history,
    this.affordance,
  });

  final ZChatController controller;
  final FocusNode focusNode;
  final Color cursorColor;
  final int minLines;
  final int maxLines;
  final VoidCallback onSubmit;

  /// La politique de raccourci clavier — résolue au rendu contre la
  /// plateforme réelle.
  final ZChatComposerSubmitPolicy submitPolicy;

  /// Invite visuelle d'hôte — `null` signifie le libellé par défaut (sauf
  /// [suppressHint]).
  final Widget? hint;

  /// `true` signifie aucune invite visuelle (le builder d'hôte a rendu
  /// `null`, invariant AD-4).
  final bool suppressHint;

  /// Le rappel d'historique, ou `null` — le geste n'est alors pas monté.
  final ZChatComposerHistoryPort? history;

  /// Les déclencheurs de contexte, ou `null` — les gestes ne sont pas montés.
  final ZChatComposerAffordanceController? affordance;

  /// Monte les gestes additifs autour du champ.
  ///
  /// Rend [field] **inchangé** quand rien n'est déclaré : l'inertie est
  /// structurelle, pas promise.
  Widget _withGestures(Widget field) {
    Widget monte = field;
    // ORDRE DES COUCHES — la plus INTERNE est consultée la première.
    //
    // Le panneau de candidats vient donc en premier : tant qu'il est ouvert,
    // les flèches le parcourent et Entrée y retient un candidat. Fermé, ses
    // actions sont DÉSACTIVÉES, la frappe poursuit sa route, et la couche
    // suivante la reçoit intacte — le rappel d'historique, puis le raccourci
    // d'envoi, puis les raccourcis d'édition de Flutter.
    monte = _withAffordance(monte);
    monte = _withHistory(monte);
    return monte;
  }

  Widget _withAffordance(Widget field) {
    final ZChatComposerAffordanceController? panneau = affordance;
    if (panneau == null) return field;
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp):
            ZChatComposerAffordancePreviousIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown):
            ZChatComposerAffordanceNextIntent(),
        SingleActivator(LogicalKeyboardKey.enter):
            ZChatComposerAffordanceCommitIntent(),
        SingleActivator(LogicalKeyboardKey.escape):
            ZChatComposerAffordanceDismissIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ZChatComposerAffordancePreviousIntent: _ZChatAffordanceMoveAction<
            ZChatComposerAffordancePreviousIntent
          >(panel: panneau, delta: -1),
          ZChatComposerAffordanceNextIntent: _ZChatAffordanceMoveAction<
            ZChatComposerAffordanceNextIntent
          >(panel: panneau, delta: 1),
          ZChatComposerAffordanceCommitIntent: _ZChatAffordanceCommitAction(
            panel: panneau,
          ),
          ZChatComposerAffordanceDismissIntent: _ZChatAffordanceDismissAction(
            panel: panneau,
          ),
        },
        child: field,
      ),
    );
  }

  Widget _withHistory(Widget field) {
    final ZChatComposerHistoryPort? recall = history;
    if (recall == null) return field;
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.arrowUp):
            ZChatComposerHistoryIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ZChatComposerHistoryIntent: ZChatComposerHistoryAction(
            // La MÊME tranche que celle du champ : le rappel écrit là où la
            // saisie se lit, jamais dans une copie.
            composer: controller.composer,
            history: recall,
          ),
        },
        child: field,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Un champ MULTILIGNE ne déclenche jamais `onSubmitted` : sans cette
    // table, un composer à `maxLines > 1` n'a aucun chemin d'envoi au
    // clavier. `onSubmitted` reste câblé — il redevient le chemin dès qu'un
    // hôte règle `maxLines: 1`, ou quand la politique est retirée.
    final ZChatComposerSubmitKey resolved = submitPolicy.resolve();
    final Widget field = EditableText(
      // La tranche du contrôleur, telle quelle. Instance stable : elle
      // n'est ni créée ni recréée ici, donc le curseur et la sélection
      // survivent à tout rebuild du composer (invariant AD-2).
      controller: controller.composer,
      focusNode: focusNode,
      // Invariant AD-13 : jamais `TextAlign.left`.
      textAlign: TextAlign.start,
      minLines: minLines,
      maxLines: maxLines,
      style: DefaultTextStyle.of(context).style,
      cursorColor: cursorColor,
      backgroundCursorColor: cursorColor,
      // Le MÊME site de soumission que celui du créneau d'envoi.
      onSubmitted: (String _) => onSubmit(),
    );
    // Gestes additifs montés SEULEMENT quand l'hôte les a déclarés : sans
    // déclaration, `core` EST le champ, et non un `Shortcuts` inerte de plus
    // dans l'arbre. C'est la couche la plus INTERNE — plus interne que le
    // raccourci d'envoi — pour que ses actions désactivées laissent la frappe
    // poursuivre sa route vers les raccourcis d'édition de Flutter.
    final Widget core = _withGestures(field);
    return Semantics(
      container: true,
      textField: true,
      // L'invite est le libellé du champ pour un lecteur d'écran : le
      // placeholder visuel, lui, est retiré de l'arbre sémantique pour ne pas
      // être énoncé DEUX fois (leçon MAJEUR-doublon de la bande de pièces
      // jointes).
      label: zChatLabel(context, kZChatLabelComposerHint),
      child: Stack(
        // Invariant AD-13 : alignement directionnel, et en haut — un
        // placeholder centré verticalement se décalerait dès que le champ
        // passe à deux lignes.
        alignment: AlignmentDirectional.topStart,
        children: <Widget>[
          if (!suppressHint) _ZChatComposerHint(controller: controller, hint: hint),
          if (resolved == ZChatComposerSubmitKey.none)
            core
          else
            Shortcuts(
              // Posée SOUS `DefaultTextEditingShortcuts` (inséré par
              // `WidgetsApp`), donc consultée avant lui : c'est ce qui permet
              // à Entrée de soumettre au lieu d'atteindre la saisie de texte.
              shortcuts: zChatComposerSubmitShortcuts(resolved),
              child: Actions(
                actions: <Type, Action<Intent>>{
                  ZChatComposerSubmitIntent:
                      CallbackAction<ZChatComposerSubmitIntent>(
                        // Le MÊME site que le créneau d'envoi — jamais un
                        // second appel à `send()`.
                        onInvoke: (ZChatComposerSubmitIntent _) {
                          onSubmit();
                          return null;
                        },
                      ),
                },
                child: core,
              ),
            ),
        ],
      ),
    );
  }
}

/// Le placeholder — visible tant que la saisie est vide.
///
/// C'est le seul abonnement du composer au canal à haute fréquence, et
/// c'est une feuille : une frappe reconstruit un `Text`, jamais le champ,
/// jamais les créneaux de l'hôte, jamais la liste des messages (invariant
/// AD-2).
class _ZChatComposerHint extends StatelessWidget {
  const _ZChatComposerHint({required this.controller, this.hint});

  final ZChatController controller;

  /// Invite d'hôte (créneau `hint`). `null` signifie le libellé par défaut.
  ///
  /// Quel que soit le porteur, il reste sous `ExcludeSemantics` +
  /// `IgnorePointer`, et sa visibilité reste pilotée ici : un hôte ne peut
  /// pas faire d'une invite un widget interactif ni un doublon sémantique.
  final Widget? hint;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller.composer,
          builder:
              (BuildContext context, TextEditingValue value, Widget? child) =>
                  value.text.isEmpty ? child! : const SizedBox.shrink(),
          // Construit UNE fois et passé en `child` : la frappe ne le
          // reconstruit pas, elle ne fait que le montrer ou le cacher.
          child:
              hint ??
              Text(
                zChatLabel(context, kZChatLabelComposerHint),
                // Invariant AD-13 : jamais `TextAlign.left`.
                textAlign: TextAlign.start,
              ),
        ),
      ),
    );
  }
}

/// Cible tactile d'un créneau — ≥ 48 dp et bornée par le haut (invariant
/// AD-13).
///
/// Le plancher [kZChatMinTapTarget] fixe une cible tactile conforme quelle
/// que soit la taille demandée par l'hôte.
///
/// ## Ce que les `widthFactor`/`heightFactor` font — et ne font pas ici
///
/// Sans facteurs, un `Align` peut occuper toute la contrainte disponible et
/// une vérification de plancher passerait alors pour la mauvaise raison
/// (cf. `z_chat_diffusion_bar.dart`). Il serait donc tentant d'écrire que ce
/// sont eux qui bornent la cible ici. Ce n'est pas le cas : les retirer
/// laisse la boîte à 48×48.
///
/// Raison : le parent est une `Row`, et une `Flex` dispose ses enfants non
/// flexibles sous contraintes non bornées — la boîte y épouse déjà son
/// enfant, facteurs ou non. La borne haute réelle vient donc de la
/// disposition (le champ est le seul `Expanded`), pas des facteurs.
///
/// Les facteurs sont conservés — défense si cette boîte est un jour posée
/// sous des contraintes bornées — mais ils ne sont pas ce qui tient la
/// promesse aujourd'hui, et ce dartdoc ne le prétend pas.
class _ZChatComposerTarget extends StatelessWidget {
  const _ZChatComposerTarget({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: kZChatMinTapTarget,
        minWidth: kZChatMinTapTarget,
      ),
      child: Align(
        // Invariant AD-13 : alignement directionnel.
        alignment: AlignmentDirectional.center,
        // Défense (cf. le dartdoc) : inertes sous la `Row`, utiles si cette
        // boîte est un jour posée sous des contraintes bornées.
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    );
  }
}

/// Déplace la mise en avant — **désactivée** quand aucun panneau n'est ouvert,
/// pour que la flèche poursuive sa route vers la couche suivante.
class _ZChatAffordanceMoveAction<T extends Intent> extends Action<T> {
  _ZChatAffordanceMoveAction({required this.panel, required this.delta});

  // Nommé `panel`, jamais `controller` : le fichier du composer ne doit
  // toucher du `ZChatController` que `composer`, `canSend` et `send`, et la
  // garde qui l'exige lit le motif `controller.<membre>` sur tout le fichier.
  final ZChatComposerAffordanceController panel;
  final int delta;

  @override
  bool isEnabled(T intent) {
    final ZChatComposerAffordanceState s = panel.state.value;
    return s.isOpen && s.entries.isNotEmpty;
  }

  @override
  Object? invoke(T intent) {
    panel.moveSelection(delta);
    return null;
  }
}

/// Retient le candidat mis en avant — **désactivée** panneau fermé, ce qui
/// rend Entrée au raccourci d'envoi.
class _ZChatAffordanceCommitAction
    extends Action<ZChatComposerAffordanceCommitIntent> {
  _ZChatAffordanceCommitAction({required this.panel});

  final ZChatComposerAffordanceController panel;

  @override
  bool isEnabled(ZChatComposerAffordanceCommitIntent intent) =>
      panel.state.value.selected != null;

  @override
  Object? invoke(ZChatComposerAffordanceCommitIntent intent) {
    panel.commit();
    return null;
  }
}

/// Ferme sans rien retenir — **désactivée** panneau fermé.
class _ZChatAffordanceDismissAction
    extends Action<ZChatComposerAffordanceDismissIntent> {
  _ZChatAffordanceDismissAction({required this.panel});

  final ZChatComposerAffordanceController panel;

  @override
  bool isEnabled(ZChatComposerAffordanceDismissIntent intent) =>
      panel.state.value.isOpen;

  @override
  Object? invoke(ZChatComposerAffordanceDismissIntent intent) {
    panel.dismiss();
    return null;
  }
}
