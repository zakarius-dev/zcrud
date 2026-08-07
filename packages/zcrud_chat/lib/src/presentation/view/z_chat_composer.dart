/// Le **composer socle partagé** — `ZChatComposer` (lot α du chantier
/// Notebook/Chat, suite de l'étude CR-IFFD-72).
///
/// ## 🔴 Ce qui manquait, exactement
///
/// L'étude a mesuré, grep négatif à l'appui, que **ni `ZChatConversationView`
/// ni `ZChatNotebookView` ne montent de zone de saisie** : les deux surfaces
/// partagent la fabrique de TUILE (garde CR-71) et rien d'autre. **Aucun widget
/// du socle ne rendait `ZChatController.composer`** — les deux seuls
/// `EditableText` du paquet vivaient dans le champ de *relecture* d'une
/// capture. `ZChatCaptureBar`, elle, n'est pas une saisie : ce sont deux
/// boutons dictée/OCR.
///
/// Le **contrôleur**, lui, existait déjà : `ZChatController.composer` est un
/// `TextEditingController` **public**, listé dans la garde d'ensemble **G-CH1**
/// et écrit par un site unique (G-CH4). Le manque était donc le **WIDGET**.
///
/// ⇒ Ce fichier ne crée **aucun contrôleur d'état de saisie** et n'ajoute
/// **aucun membre** à `ZChatController` : il **lit et lie** la tranche
/// existante. G-CH1 reste verte par construction.
///
/// ## 🔴 Aucun nouveau chemin d'exécution (G-CH1 / G-U1)
///
/// L'envoi passe par [ZChatController.send] — le verbe existant — et par lui
/// seul. Le socle n'expose pas un `onSend` que l'hôte câblerait lui-même : il
/// **fournit** la fermeture [ZChatComposerSlot.submit], si bien que le bouton
/// d'envoi de l'hôte et la touche « valider » du clavier empruntent
/// **littéralement le même site d'appel**. C'est la forme locale de l'invariant
/// « un verbe = un seul site d'appel » qui fonde tout ce paquet : IFFD porte
/// deux barres d'actions parallèles qui ont divergé, et c'est ce qu'aucune
/// surface d'ici ne peut reproduire.
///
/// ## Les quatre créneaux, et pourquoi ce sont des BUILDERS
///
/// ```
/// ZChatComposer
///   ├── capture    ← l'hôte y branche le `ZChatCaptureBar` EXISTANT
///   ├── Row [ leading | champ | trailing ]
///   │        ↑ pièces jointes / `+`        ↑ envoi
///   └── tools      ← accès aux réglages
/// ```
///
/// **AD-4** : un créneau nul — ou un créneau dont le builder rend `null` — est
/// **ABSENT de l'arbre**, jamais un `SizedBox.shrink()` inerte.
///
/// Un **builder** plutôt qu'un `Widget` figé, et un objet
/// [ZChatComposerSlot] plutôt qu'une liste de paramètres positionnels : c'est
/// ce qui rend accueillables, **sans rupture**, les mécanismes que le
/// `ChatInputController` de lex_douane porte et que le socle n'a pas encore
/// (contexte d'outils pré-expert, cycle de raisonnement, mode édition,
/// brouillon à compteur, remise à zéro). Chacun deviendra un **champ de plus
/// sur [ZChatComposerSlot]** — strictement additif — au lieu d'un booléen figé
/// de plus dans la signature.
///
/// ## 🔴 AD-13 — la cible d'envoi ne sera PAS celle du legacy
///
/// Le FAB d'envoi d'IFFD mesure **40 dp**. Ici, [leading] et [trailing] sont
/// posés dans une boîte de [kZChatMinTapTarget] **bornée des deux côtés** : le
/// plancher vient du `ConstrainedBox`, la borne haute de la **disposition** (le
/// champ est le seul enfant flexible de la `Row`). La garde mesure la
/// **géométrie rendue**, jamais les contraintes — cf. le dartdoc de
/// [_ZChatComposerTarget], qui dit précisément ce que les
/// `widthFactor`/`heightFactor` font et **ne font pas** ici, mesure R3 à
/// l'appui.
///
/// ## 🔴 SM-1 — ce que ce fichier ne fait PAS
///
/// * il ne crée **aucun** `TextEditingController` (celui du contrôleur est
///   stable et vit aussi longtemps que lui) ;
/// * il n'abonne **rien** au canal du composer au-dessus du champ : le seul
///   abonnement à la frappe est [_ZChatComposerHint], une feuille qui rend un
///   `Text` — ni la liste des messages, ni les créneaux de l'hôte n'en
///   dépendent ;
/// * il n'appelle **jamais** `setState` (G-CH5 : interdit dans tout `lib/`).
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
/// 🔴 **Un objet, pas une liste d'arguments.** Les mécanismes de lex que le
/// socle n'a pas encore (mode édition, brouillon à compteur, cycle de
/// raisonnement…) s'ajouteront ici en **champs supplémentaires**, sans changer
/// la signature de [ZChatComposerSlotBuilder] — donc sans casser un seul hôte.
@immutable
class ZChatComposerSlot {
  /// Construit le contexte d'un créneau.
  const ZChatComposerSlot({
    required this.controller,
    required this.submit,
    this.settings,
  });

  /// Le contrôleur de la conversation — l'hôte y lit les tranches réactives
  /// (`canSend`, `attachmentIds`, `activeRequests`…) et y pose **ses propres**
  /// `ValueListenableBuilder`. Le socle n'en impose aucun : un créneau qui ne
  /// réagit à rien n'est jamais reconstruit (SM-1).
  final ZChatController controller;

  /// Soumet la saisie courante — **l'unique** chemin d'envoi du composer.
  ///
  /// C'est la MÊME fermeture que celle branchée sur la touche « valider » du
  /// clavier. Un hôte qui appellerait `controller.send()` de son côté créerait
  /// un second site d'appel : le socle le lui évite en le lui donnant.
  ///
  /// Sans objet quand la saisie est vide **et** sans pièce jointe : l'appel est
  /// alors sans effet (le refus reste celui de `send()`, jamais un second).
  final VoidCallback submit;

  /// Les **réglages de génération** du composer, ou `null` si l'hôte n'en a pas
  /// branché — lot γ0.
  ///
  /// 🔴 C'est le premier des « champs de plus » que ce type a été conçu pour
  /// accueillir. Il est ici pour que la feuille montée dans le créneau `tools`
  /// écrive dans **le contrôleur que le composer soumettra** — et non dans un
  /// second, qui serait la forme exacte du défaut mesuré chez IFFD : des
  /// réglages affichés, réglés, puis **jetés** avant l'appel.
  final ZChatSettingsController? settings;
}

/// Construit le contenu d'un créneau du composer.
///
/// Rendre `null` ⇒ **aucun widget inséré** (AD-4). C'est ce qui permet à un
/// même builder de ne monter son affordance que dans certaines conditions —
/// sans que le socle ait à porter un booléen par cas.
typedef ZChatComposerSlotBuilder =
    Widget? Function(BuildContext context, ZChatComposerSlot slot);

/// Rend la zone de saisie d'un [ZChatController] — **zéro dépendance tierce**.
///
/// Le widget est **monté par les deux surfaces** (`ZChatConversationView` et
/// `ZChatNotebookView`) par une **fabrique unique**, exactement comme la tuile
/// de message l'est depuis CR-71 : une régression ici rougit les deux.
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

  /// Le contrôleur dont la saisie est rendue. Il n'est **ni créé ni disposé**
  /// ici : son cycle de vie appartient à l'hôte (AD-2).
  final ZChatController controller;

  /// Couleur du curseur — fournie par l'hôte.
  ///
  /// 🔴 `EditableText` exige une couleur non nulle et ce paquet n'a le droit
  /// d'en inventer **aucune** (FR-26 ; `material.dart` y est banni). Entre
  /// « inventer un noir » et « demander », on demande — c'est le même
  /// arbitrage, déjà tranché, que `ZChatCaptureReviewField.cursorColor`.
  final Color cursorColor;

  /// Créneau de tête — pièces jointes, menu `+`. `null` ⇒ absent (AD-4).
  final ZChatComposerSlotBuilder? leading;

  /// Créneau de queue — **l'envoi**. `null` ⇒ absent (AD-4) ; la touche
  /// « valider » du clavier reste alors le seul déclencheur.
  final ZChatComposerSlotBuilder? trailing;

  /// Créneau des **réglages** — la bande sous le champ. `null` ⇒ absent.
  final ZChatComposerSlotBuilder? tools;

  /// Créneau de **capture** — la bande au-dessus du champ, où l'hôte branche le
  /// [ZChatCaptureBar] **existant** (dictée/OCR).
  ///
  /// 🔴 Il n'est pas réécrit ici : l'étude établit que la capture du socle est
  /// **déjà meilleure** que celle de lex (l'écoute y est annoncée, pas
  /// seulement affichée).
  final ZChatComposerSlotBuilder? capture;

  /// Créneau du **placeholder visuel** — lot K2 (chantier composer-lex). Règle
  /// des trois cas, la même que les tuiles de `ZChatSettingsSheet` :
  ///
  /// | Builder | Effet |
  /// |---|---|
  /// | absent (`null`) | l'invite par défaut du socle (le libellé résolu) |
  /// | fourni, rend un widget | ce widget remplace l'invite — c'est ici que se branche `ZChatComposerAnimatedHint` (le placeholder animé de lex) |
  /// | fourni, rend `null` | aucune invite visuelle (AD-4) |
  ///
  /// 🔴 Quel que soit le cas, le rendu reste **ExcludeSemantics +
  /// IgnorePointer** et sa visibilité reste pilotée par la vacuité de la
  /// saisie : le libellé du champ pour un lecteur d'écran ne change pas
  /// (CMP-R1), et le seul abonnement à la frappe reste celui de l'invite
  /// (SM-1).
  final ZChatComposerSlotBuilder? hint;

  /// Réglages de génération **soumis avec la saisie** — lot γ0. `null` ⇒ le
  /// comportement est **strictement** celui d'avant ce lot : `send()` est appelé
  /// sans argument, donc le port reçoit l'objet même que le builder de l'hôte a
  /// construit (`withSettings(null)` rend `identical`). Mesuré : `SET-A1`.
  ///
  /// 🔴 **Le créneau `tools` et ce champ vont ensemble.** Un hôte qui monte une
  /// feuille de réglages dans `tools` sans passer ici le **même**
  /// [ZChatSettingsController] afficherait des réglages qui n'atteindraient
  /// jamais la requête : c'est, à la lettre, le défaut que l'étude a mesuré chez
  /// IFFD (six drapeaux de corpus transmis par le contrôleur puis jetés par le
  /// repository). Le socle donne le contrôleur au créneau
  /// ([ZChatComposerSlot.settings]) précisément pour que l'hôte n'ait jamais à
  /// en fabriquer un second.
  ///
  /// ⚠️ Renseigné, il **gouverne** les quatre réglages : un porteur vide les
  /// remet à « l'hôte décide », y compris ceux qu'aurait posés le
  /// `ZChatRequestBuilder`. C'est la règle de remplacement du kernel, et c'est
  /// ce qui rend un réglage **retirable** depuis la feuille.
  final ZChatSettingsController? settings;

  /// Nœud de focus de l'hôte. `null` ⇒ le composer en possède un, créé **une
  /// fois** et disposé avec lui (jamais dans un `build` — interdit AD-2).
  final FocusNode? focusNode;

  /// Marge **directionnelle** (AD-13). `null` ⇒ `ZcrudTheme.formPadding`.
  final EdgeInsetsDirectional? padding;

  /// Hauteur minimale du champ, en lignes.
  final int minLines;

  /// Hauteur maximale du champ, en lignes.
  final int maxLines;

  @override
  State<ZChatComposer> createState() => _ZChatComposerState();
}

class _ZChatComposerState extends State<ZChatComposer> {
  /// Créé UNE fois — jamais au rebuild (AD-2). Utilisé seulement si l'hôte n'a
  /// pas fourni le sien ; disposé dans tous les cas puisqu'il nous appartient.
  final FocusNode _owned = FocusNode();

  @override
  void dispose() {
    _owned.dispose();
    super.dispose();
  }

  /// 🔴 **L'UNIQUE site de soumission du composer.**
  ///
  /// Il ne fabrique aucune requête, ne compose aucun prompt et n'invente aucun
  /// verbe : il appelle le `send()` **existant** du contrôleur. Le garde-fou
  /// `canSend` n'est pas un second refus — c'est la même condition que celle de
  /// `send()`, lue en amont pour ne pas salir `lastFailure` sur un geste vide.
  void _submit() {
    if (!widget.controller.canSend.value) return;
    // 🔴 Les réglages sont lus AU MOMENT DE L'ENVOI, jamais capturés au
    // montage : la feuille a pu être ouverte, réglée et refermée entre-temps.
    // `settings == null` ⇒ appel SANS argument — le défaut, à l'octet près.
    final ZChatSettingsController? tools = widget.settings;
    unawaited(
      widget.controller.send(
        settings: tools?.settings.value,
        corpusScope: tools?.corpusScope.value,
      ),
    );
  }

  /// Résout un créneau. `null` (builder absent **ou** builder rendant `null`)
  /// ⇒ le créneau est **absent de l'arbre** (AD-4).
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

/// Le champ lui-même — il **lie** `controller.composer`, il ne le remplace pas.
///
/// 🔴 Aucune écriture de la saisie ici (`composer.text = …` n'apparaît nulle
/// part) : la garde G10-P2 balaie tout `lib/` et exige que le seul écrivain
/// hors du contrôleur reste `ZChatCaptureController.acceptInto`.
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

  /// Invite visuelle d'HÔTE — `null` ⇒ le libellé par défaut (sauf
  /// [suppressHint]).
  final Widget? hint;

  /// `true` ⇒ aucune invite visuelle (le builder d'hôte a rendu `null`, AD-4).
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
        // AD-13 : alignement DIRECTIONNEL, et en HAUT — un placeholder centré
        // verticalement se décalerait dès que le champ passe à deux lignes.
        alignment: AlignmentDirectional.topStart,
        children: <Widget>[
          if (!suppressHint) _ZChatComposerHint(controller: controller, hint: hint),
          EditableText(
            // 🔴 LA tranche du contrôleur, telle quelle. Instance STABLE : elle
            // n'est ni créée ni recréée ici, donc le curseur et la sélection
            // survivent à tout rebuild du composer (interdit AD-2).
            controller: controller.composer,
            focusNode: focusNode,
            // AD-13 : jamais `TextAlign.left`.
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
/// 🔴 C'est le **seul** abonnement du composer au canal à haute fréquence, et
/// c'est une **feuille** : une frappe reconstruit un `Text`, jamais le champ,
/// jamais les créneaux de l'hôte, jamais la liste des messages (SM-1, mesuré).
class _ZChatComposerHint extends StatelessWidget {
  const _ZChatComposerHint({required this.controller, this.hint});

  final ZChatController controller;

  /// Invite d'HÔTE (créneau `hint`, lot K2). `null` ⇒ le libellé par défaut.
  ///
  /// 🔴 Quel que soit le porteur, il reste sous **ExcludeSemantics +
  /// IgnorePointer**, et sa visibilité reste pilotée ici : un hôte ne peut pas
  /// faire d'une invite un widget interactif ni un doublon sémantique.
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
                // AD-13 : jamais `TextAlign.left`.
                textAlign: TextAlign.start,
              ),
        ),
      ),
    );
  }
}

/// Cible tactile d'un créneau — **≥ 48 dp et BORNÉE PAR LE HAUT** (AD-13).
///
/// Le legacy IFFD envoie depuis un bouton de **40 dp** : c'est ce que le
/// plancher [kZChatMinTapTarget] rend inexprimable ici, et la garde CMP-G1 le
/// mesure en **géométrie rendue** (l'injection R3 « minHeight: 40 » la fait
/// rougir).
///
/// ## 🔴 Ce que les `widthFactor`/`heightFactor` font — et ce qu'ils ne font
/// PAS ici, MESURÉ
///
/// Le précédent de `z_chat_diffusion_bar.dart` est réel : sans facteurs,
/// `Align` occupe **toute** la contrainte et une garde de plancher passe pour
/// la mauvaise raison. Il serait donc tentant d'écrire que ce sont eux qui
/// bornent la cible ici. **C'est faux, et l'injection R3 l'a démontré** : les
/// retirer laisse la boîte à 48×48 et **aucune garde ne rougit**.
///
/// Raison : le parent est une `Row`, et une `Flex` dispose ses enfants **non
/// flexibles sous contraintes non bornées** — la boîte y épouse déjà son
/// enfant, facteurs ou non. La borne haute réelle vient donc de la
/// **disposition** (le champ est le seul `Expanded`), pas des facteurs. Ce
/// qu'assertent CMP-G1 (`< 200 dp`) et son injection jumelle : rendre ce
/// créneau flexible ferait immédiatement rougir.
///
/// Les facteurs sont **conservés** — défense si cette boîte est un jour posée
/// sous des contraintes bornées — mais ils ne sont **pas** ce qui tient la
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
        // AD-13 : alignement DIRECTIONNEL.
        alignment: AlignmentDirectional.center,
        // Défense (cf. le dartdoc) : inertes sous la `Row`, utiles si cette
        // boîte est un jour posée sous des contraintes BORNÉES.
        widthFactor: 1,
        heightFactor: 1,
        child: child,
      ),
    );
  }
}
