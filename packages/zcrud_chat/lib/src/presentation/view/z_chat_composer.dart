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
/// ## Les quatre créneaux, et pourquoi ce sont des builders
///
/// ```
/// ZChatComposer
///   ├── capture    <- l'hote y branche le `ZChatCaptureBar` EXISTANT
///   ├── Row [ leading | champ | trailing ]
///   |        pieces jointes / '+'        envoi
///   └── tools      <- acces aux reglages
/// ```
///
/// Invariant AD-4 : un créneau nul — ou un créneau dont le builder rend
/// `null` — est absent de l'arbre, jamais un `SizedBox.shrink()` inerte.
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

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../settings/z_chat_settings_controller.dart';
import '../z_chat_controller.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart' show kZChatMinTapTarget;

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
    this.leading,
    this.trailing,
    this.tools,
    this.capture,
    this.hint,
    this.settings,
    this.focusNode,
    this.padding,
    this.minLines = 1,
    this.maxLines = 5,
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

  /// Créneau de tête — pièces jointes, menu `+`. `null` signifie absent
  /// (invariant AD-4).
  final ZChatComposerSlotBuilder? leading;

  /// Créneau de queue — l'envoi. `null` signifie absent (invariant AD-4) ;
  /// la touche « valider » du clavier reste alors le seul déclencheur.
  final ZChatComposerSlotBuilder? trailing;

  /// Créneau des réglages — la bande sous le champ. `null` signifie absent.
  final ZChatComposerSlotBuilder? tools;

  /// Créneau de capture — la bande au-dessus du champ, où l'hôte branche le
  /// [ZChatCaptureBar] existant (dictée/reconnaissance de texte).
  final ZChatComposerSlotBuilder? capture;

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
    _owned.dispose();
    super.dispose();
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
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final Widget? capture = _slot(context, widget.capture);
    final Widget? leading = _slot(context, widget.leading);
    final Widget? trailing = _slot(context, widget.trailing);
    final Widget? tools = _slot(context, widget.tools);
    // Règle des trois cas du créneau `hint` (cf. son dartdoc) : la distinction
    // « builder absent » / « builder rendant null » se lit ici, jamais dans le
    // champ.
    final Widget? hostHint = _slot(context, widget.hint);
    final bool suppressHint = widget.hint != null && hostHint == null;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: zChatLabel(context, kZChatLabelComposer),
      child: Padding(
        padding: widget.padding ?? theme.formPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ?capture,
            Row(
              // Les affordances suivent le BAS du champ quand il grandit.
              crossAxisAlignment: CrossAxisAlignment.end,
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
                  ),
                ),
                if (trailing != null) _ZChatComposerTarget(child: trailing),
              ],
            ),
            ?tools,
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
    this.hint,
    this.suppressHint = false,
  });

  final ZChatController controller;
  final FocusNode focusNode;
  final Color cursorColor;
  final int minLines;
  final int maxLines;
  final VoidCallback onSubmit;

  /// Invite visuelle d'hôte — `null` signifie le libellé par défaut (sauf
  /// [suppressHint]).
  final Widget? hint;

  /// `true` signifie aucune invite visuelle (le builder d'hôte a rendu
  /// `null`, invariant AD-4).
  final bool suppressHint;

  @override
  Widget build(BuildContext context) {
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
          EditableText(
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
