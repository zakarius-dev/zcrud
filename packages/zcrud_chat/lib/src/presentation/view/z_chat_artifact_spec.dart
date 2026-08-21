/// La **déclaration** d'un artefact par message : ce que l'hôte doit dire pour
/// que le socle rende la barre d'artefacts, et rien de plus.
///
/// ## Ce que l'hôte déclare, et ce qu'il ne déclare plus
///
/// Une application d'étude décrit **ce qu'elle supporte** :
///
/// ```dart
/// ZChatArtifactSpec(
///   key: kZChatCapabilityMindmap,   // une CLÉ OPAQUE, jamais un type du socle
///   icon: Icons.map_outlined,
///   label: l10n.mindmap,            // déjà localisé par l'hôte
///   presence: (m) => m.mindmap != null,
///   count: (m) => countNodes(m.mindmap),  // null ⇒ pas de pastille
///   busy: (m) => controller.isGenerating(m.id),
///   actions: <ZChatArtifactAction>[
///     ZChatArtifactAction.create(onSelected: …),      // visible SI absent
///     ZChatArtifactAction.open(onSelected: …),        // visible SI présent
///     ZChatArtifactAction.regenerate(onSelected: …),
///     ZChatArtifactAction.delete(onSelected: …, confirmMessage: …),
///   ],
/// )
/// ```
///
/// Le socle rend le reste : le glyphe **teinté quand l'artefact existe**, la
/// pastille de compte, le menu des verbes dont la condition tient, la
/// confirmation d'un verbe destructeur, et l'annonce d'accessibilité.
///
/// ## 🔴 Une CLÉ, jamais une identité
///
/// Le socle **ne connaît ni `mindmap` ni `flashcards`** : il connaît une clé
/// opaque, exactement comme `ZChatCustomAction.verb`. Les identités et le
/// stockage restent à l'hôte — une clé `classroom` peut très bien s'écrire
/// `chat` en base.
/// La clé ne sert qu'à deux choses : retrouver un accent dans la chaîne
/// `ZChatNotebookSkin` (paramètre > jeton > référence), et distinguer deux
/// artefacts dans l'arbre.
///
/// ## 🔴 L'ordre et la teinte restent ceux de l'HÔTE
///
/// Les verbes sont rendus dans l'ordre **déclaré**, et chacun porte sa propre
/// teinte facultative. C'est délibéré : une application rend couramment
/// « Régénérer » en vert pour un artefact et en gris-bleu pour un autre, et
/// l'ordre des entrées diffère d'un artefact à l'autre. Un mécanisme qui
/// imposerait un ordre unique forcerait l'hôte à choisir entre le socle et sa
/// propre présentation.
///
/// ## Trois lectures d'ÉTAT, sur le message BRUT
///
/// [ZChatArtifactSpec.presence], [ZChatArtifactSpec.count] et
/// [ZChatArtifactSpec.busy] lisent le message tel que l'hôte le connaît. Le
/// socle n'en dérive aucun modèle : c'est ce qui permet à un artefact de
/// vivre dans un champ, dans une collection annexe, ou dans une paire de
/// messages, sans que le socle ait à le savoir.
///
/// Chacune de ces lectures est appelée **dans un `try`** par le rendu : une
/// lecture qui lève retombe sur un repli **fermant** — artefact traité comme
/// absent, compte nul, occupation fausse, verbe masqué (invariant AD-10).
/// Jamais l'inverse : un repli ouvrant offrirait un verbe destructeur sur un
/// état qu'on n'a pas pu lire.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import '../render/z_chat_seam_failure.dart';
import 'z_chat_labels.dart';

/// Lecture de **présence** d'un artefact sur un message brut.
typedef ZChatArtifactPresence = bool Function(ZChatMessage message);

/// Lecture du **compte** d'un artefact. `null` signifie « pas de pastille » —
/// distinct de `0`, qui signifie « zéro élément » (et ne montre pas de
/// pastille non plus : une pastille « 0 » est du bruit).
typedef ZChatArtifactCount = int? Function(ZChatMessage message);

/// Lecture de l'**occupation** — une génération en cours POUR CET ARTEFACT.
///
/// La lecture est indexée par artefact **par construction** : une occupation
/// qui animerait tous les glyphes à la fois est inexprimable.
typedef ZChatArtifactBusy = bool Function(ZChatMessage message);

/// Condition de visibilité d'un verbe. [present] est le résultat **déjà
/// résolu** de [ZChatArtifactSpec.presence] : l'hôte n'a pas à réécrire la
/// même lecture deux fois.
typedef ZChatArtifactVisibility =
    bool Function(ZChatMessage message, bool present);

/// Rappel d'un verbe — ce qu'il fait reste **entièrement** à l'hôte (une
/// suppression en cascade, un `runAction`, une navigation).
typedef ZChatArtifactCallback = void Function(ZChatMessage message);

/// Condition « visible seulement si l'artefact est ABSENT » — celle de
/// [ZChatArtifactAction.create].
bool zChatArtifactWhenAbsent(ZChatMessage message, bool present) => !present;

/// Condition « visible seulement si l'artefact est PRÉSENT » — celle de
/// [ZChatArtifactAction.open], `.regenerate`, `.edit` et `.delete`.
bool zChatArtifactWhenPresent(ZChatMessage message, bool present) => present;

/// Un **verbe** offert sur un artefact : sa condition de visibilité, sa
/// teinte facultative, et son rappel.
///
/// Le libellé vient soit d'un texte **déjà localisé** par l'hôte ([label]),
/// soit d'une **clé** du socle ([labelKey]) résolue par `zChatLabel` — même
/// contrat que `ZChatModelOption`. Les cinq constructeurs nommés posent la
/// clé du socle correspondante : un hôte obtient un menu localisé sans
/// alimenter quoi que ce soit.
@immutable
class ZChatArtifactAction {
  /// Verbe entièrement décrit par l'hôte. Au moins l'un de [label] et
  /// [labelKey] doit être fourni — sans quoi le menu rendrait une ligne
  /// muette.
  const ZChatArtifactAction({
    required this.onSelected,
    this.label,
    this.labelKey,
    this.icon,
    this.accent,
    this.visible,
    this.destructive = false,
    this.confirmMessage,
  }) : assert(label != null || labelKey != null);

  /// « Créer » — visible **si l'artefact est absent**.
  const ZChatArtifactAction.create({
    required this.onSelected,
    this.label,
    this.icon,
    this.accent,
  }) : labelKey = kZChatLabelArtifactCreate,
       visible = zChatArtifactWhenAbsent,
       destructive = false,
       confirmMessage = null;

  /// « Ouvrir » — visible **si l'artefact est présent**.
  ///
  /// C'est ce verbe qui garantit que toucher le glyphe ouvre un MENU, et ne
  /// régénère jamais en silence.
  const ZChatArtifactAction.open({
    required this.onSelected,
    this.label,
    this.icon,
    this.accent,
  }) : labelKey = kZChatLabelArtifactOpen,
       visible = zChatArtifactWhenPresent,
       destructive = false,
       confirmMessage = null;

  /// « Régénérer » — visible si l'artefact est présent.
  const ZChatArtifactAction.regenerate({
    required this.onSelected,
    this.label,
    this.icon,
    this.accent,
  }) : labelKey = kZChatLabelArtifactRegenerate,
       visible = zChatArtifactWhenPresent,
       destructive = false,
       confirmMessage = null;

  /// « Modifier » — visible si l'artefact est présent.
  const ZChatArtifactAction.edit({
    required this.onSelected,
    this.label,
    this.icon,
    this.accent,
  }) : labelKey = kZChatLabelArtifactEdit,
       visible = zChatArtifactWhenPresent,
       destructive = false,
       confirmMessage = null;

  /// « Supprimer » — visible si l'artefact est présent, et **destructeur** :
  /// le socle demande confirmation avant d'appeler [onSelected].
  const ZChatArtifactAction.delete({
    required this.onSelected,
    this.label,
    this.icon,
    this.accent,
    this.confirmMessage,
  }) : labelKey = kZChatLabelArtifactDelete,
       visible = zChatArtifactWhenPresent,
       destructive = true;

  /// Libellé **déjà localisé** par l'hôte. Prioritaire sur [labelKey].
  final String? label;

  /// Clé de libellé, résolue par le registre de l'hôte puis le repli du
  /// socle. Consultée seulement si [label] est nul.
  final String? labelKey;

  /// Glyphe du verbe. `null` signifie aucun glyphe (invariant AD-4 : un
  /// créneau nul est absent de l'arbre, jamais un espace réservé).
  final IconData? icon;

  /// Teinte **propre à ce verbe**, portée au plancher de contraste avant
  /// d'être peinte. `null` signifie la couleur ambiante.
  ///
  /// C'est ce champ qui laisse l'hôte garder sa palette de verbes sans que le
  /// socle ait à en inventer une.
  final Color? accent;

  /// Condition de visibilité. `null` signifie **toujours visible**.
  final ZChatArtifactVisibility? visible;

  /// `true` ⇒ le socle demande une **confirmation** avant [onSelected].
  final bool destructive;

  /// Message de confirmation, **déjà localisé** par l'hôte. `null` avec
  /// [destructive] laisse le socle poser sa question générique.
  final String? confirmMessage;

  /// Le rappel de l'hôte. Le socle ne fait rien d'autre que l'appeler — et,
  /// pour un verbe destructeur, seulement après confirmation.
  final ZChatArtifactCallback onSelected;

  /// Ce verbe est-il visible sur [message], sachant [present] ?
  ///
  /// Chaîne **totale** (invariant AD-10) : une condition qui lève masque le
  /// verbe (repli **fermant**), jamais l'inverse.
  bool isVisible(ZChatMessage message, {required bool present}) {
    final ZChatArtifactVisibility? test = visible;
    if (test == null) return true;
    try {
      return test(message, present);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return false;
    }
  }
}

/// La déclaration d'un artefact : une clé opaque, un glyphe, un libellé,
/// trois lectures d'état, et des verbes.
@immutable
class ZChatArtifactSpec {
  /// Déclare un artefact. Seuls [key], [icon], [label] et [presence] sont
  /// requis : un artefact sans verbe est un **indicateur d'état**, ce qui est
  /// une déclaration légitime.
  const ZChatArtifactSpec({
    required this.key,
    required this.icon,
    required this.label,
    required this.presence,
    this.count,
    this.busy,
    this.accent,
    this.actions = const <ZChatArtifactAction>[],
  });

  /// Clé **opaque** de l'artefact. Le socle ne l'interprète pas : il s'en
  /// sert pour retrouver un accent dans `ZChatNotebookSkin` et pour
  /// distinguer deux entrées.
  final String key;

  /// Le glyphe de l'artefact. Le socle le **teinte** selon l'état — c'est la
  /// seule chose qu'il en fait.
  final IconData icon;

  /// Libellé **déjà localisé** par l'hôte — annoncé et affiché dans le menu.
  final String label;

  /// Lecture de présence : l'artefact existe-t-il sur ce message ?
  final ZChatArtifactPresence presence;

  /// Lecture du compte. `null` (ou une lecture absente) signifie aucune
  /// pastille.
  final ZChatArtifactCount? count;

  /// Lecture d'occupation. `null` signifie « jamais occupé ».
  final ZChatArtifactBusy? busy;

  /// Teinte de l'artefact **en paramètre** — le niveau le plus prioritaire de
  /// la chaîne. `null` délègue à `ZChatNotebookSkin.capabilityAccents`, puis
  /// au jeton `ZcrudTheme.chatCapabilityAccents`, puis à la référence
  /// `ZChatNotebookReference.capabilities`.
  final Color? accent;

  /// Les verbes, **dans l'ordre voulu par l'hôte**.
  final List<ZChatArtifactAction> actions;

  /// L'artefact est-il présent sur [message] ? Repli **fermant** (invariant
  /// AD-10) : une lecture qui lève rend `false`.
  bool isPresent(ZChatMessage message) {
    try {
      return presence(message);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return false;
    }
  }

  /// Compte de l'artefact sur [message], ou `null` si aucune pastille n'est
  /// due. Un compte `<= 0` est traité comme absent — une pastille « 0 » ne
  /// porte aucune information.
  int? countOf(ZChatMessage message) {
    final ZChatArtifactCount? read = count;
    if (read == null) return null;
    try {
      final int? value = read(message);
      if (value == null || value <= 0) return null;
      return value;
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return null;
    }
  }

  /// L'artefact est-il en cours de génération sur [message] ? Repli
  /// **fermant** (invariant AD-10).
  bool isBusy(ZChatMessage message) {
    final ZChatArtifactBusy? read = busy;
    if (read == null) return false;
    try {
      return read(message);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamArtifactSpec,
      );
      return false;
    }
  }

  /// Les verbes dont la condition tient, **dans l'ordre déclaré**.
  List<ZChatArtifactAction> visibleActions(
    ZChatMessage message, {
    required bool present,
  }) => <ZChatArtifactAction>[
    for (final ZChatArtifactAction action in actions)
      if (action.isVisible(message, present: present)) action,
  ];
}

/// Ce qu'un hôte reçoit quand le socle lui demande de confirmer un verbe
/// destructeur.
@immutable
class ZChatArtifactConfirmRequest {
  /// Construit une demande de confirmation.
  const ZChatArtifactConfirmRequest({
    required this.message,
    required this.artifact,
    required this.action,
  });

  /// Le message porteur de l'artefact.
  final ZChatMessage message;

  /// L'artefact concerné.
  final ZChatArtifactSpec artifact;

  /// Le verbe destructeur en attente de confirmation.
  final ZChatArtifactAction action;
}

/// Couture de confirmation d'un verbe destructeur — `true` exécute le verbe.
///
/// `null` (défaut) fait rendre au socle sa **confirmation en place**, dans le
/// menu lui-même : le socle ne dépend d'aucune surface stylée, il ne peut
/// donc pas pousser un dialogue Material. Un hôte qui veut le sien le passe
/// ici.
typedef ZChatArtifactConfirm =
    Future<bool> Function(
      BuildContext context,
      ZChatArtifactConfirmRequest request,
    );
