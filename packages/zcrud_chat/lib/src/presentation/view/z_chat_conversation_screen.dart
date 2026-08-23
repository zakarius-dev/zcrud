/// L'écran **assemblé** d'une conversation — `ZChatConversationScreen`.
///
/// ## Une couche mince au-dessus des briques publiques
///
/// Le pendant de `ZChatNotebookScreen` pour le chat : `ZChatController`
/// (créé dans `initState`, libéré dans `dispose`, **jamais** dans `build`),
/// `ZChatConversationView` (la surface, avec sa région live), le composer
/// assemblé (`ZDefaultChatComposer`), la feuille de réglages
/// (`ZChatSettingsSheet`), le contrôleur d'outils (`ZChatToolController`) et
/// la session de routage (`ZChatRouteSession`) — câblés une fois, par
/// l'assemblage **commun** aux deux écrans (`z_chat_route_assembly.dart`).
/// Il n'ajoute aucune logique qui n'existe pas déjà dans une brique.
///
/// ## Rien n'est inventé, tout est remplaçable
///
/// Le socle ne choisit ni glyphe, ni libellé, ni couleur, ni phrase d'échec :
/// les libellés live, le créneau d'échec et le dialogue de confirmation
/// viennent de l'hôte. Chaque pièce montée par défaut a son paramètre de
/// remplacement ([composerBuilder], [toolsSheetBuilder], [shell]…).
///
/// ## L'échappatoire
///
/// Un hôte qui a besoin d'autre chose descend d'un cran sans rien perdre :
/// `ZChatController` + `ZChatConversationView(composer:
/// ZDefaultChatComposer(...))` rendent **exactement** l'arbre que cet écran
/// rend avec ses défauts.
///
/// ## Invariant AD-2
///
/// L'écran n'écoute **aucune** tranche : chaque sous-arbre s'abonne à la
/// sienne (le fil à `messages`, le composer à `composer`/`canSend`, le
/// sélecteur de routeur à `routerId`, la feuille à ses contrôleurs). Un jeton
/// reçu, un réglage changé, un routeur choisi ne reconstruisent ni l'écran ni
/// le composer.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import '../routing/z_chat_route_session.dart';
import '../routing/z_chat_route_settings_adapter.dart';
import '../settings/z_chat_settings_controller.dart';
import '../tools/z_chat_tool_controller.dart';
import '../tools/z_chat_tool_settings_adapter.dart';
import '../z_chat_controller.dart';
import '../z_chat_live_labels.dart';
import 'z_chat_composer_band.dart';
import 'z_chat_composer_chrome.dart';
import 'z_chat_composer_keys.dart';
import 'z_chat_composer_model_selector.dart';
import 'z_chat_conversation_view.dart';
import 'z_chat_message_tile.dart';
import 'z_chat_notebook_screen.dart'
    show ZChatNotebookSheetPresenter, zChatNotebookFailureIsReportable;
import 'z_chat_route_assembly.dart';
import 'z_chat_settings_sheet.dart';
import 'z_chat_tile_shell.dart';
import 'z_default_chat_composer.dart';

/// Remplace la feuille de réglages et d'outils par défaut. [tools] est `null`
/// quand aucun catalogue d'outils n'a été déclaré.
typedef ZChatConversationToolsSheetBuilder =
    Widget Function(
      BuildContext context,
      ZChatSettingsController settings,
      ZChatToolController? tools,
    );

/// Remplace la zone de saisie par défaut. Rendre `null` signifie aucune zone
/// de saisie (invariant AD-4).
typedef ZChatConversationComposerBuilder =
    Widget? Function(
      BuildContext context,
      ZChatController controller,
      ZChatSettingsController settings,
    );

/// Rend un échec de tour. Rendre `null` signifie rien d'affiché pour cet
/// échec.
typedef ZChatConversationFailureBuilder =
    Widget? Function(BuildContext context, ZFailure failure);

/// Un créneau de l'écran qui reçoit le contrôleur de conversation. Rendre
/// `null` signifie absent de l'arbre (invariant AD-4).
typedef ZChatConversationSlotBuilder =
    Widget? Function(BuildContext context, ZChatController controller);

/// L'écran assemblé d'une conversation : une déclaration (port, exécuteur,
/// confirmation, session de routage) et un écran fonctionnel.
class ZChatConversationScreen extends StatefulWidget {
  /// Construit l'écran.
  ///
  /// Les ports et réglages du contrôleur ([streamPort], [actionExecutor],
  /// [confirm], [newRequestId], [buildRequest], [lifecycle], [liveLabels],
  /// [maxResumeAttempts], [conversationId], [initialMessages],
  /// [routeSession]) sont **lus une fois**, à la création du contrôleur :
  /// pour changer de conversation, donner une `key` différente à l'écran.
  /// [readOnly] et [toolCatalog], eux, sont suivis à chaque mise à jour.
  const ZChatConversationScreen({
    required this.streamPort,
    required this.cursorColor,
    this.conversationId = '',
    this.initialMessages = const <ZChatMessage>[],
    this.actionExecutor = const ZChatUnsupportedActionExecutor(),
    this.confirm = zChatConfirmWithoutDialog,
    this.newRequestId,
    this.buildRequest,
    this.lifecycle,
    this.liveLabels = ZChatLiveLabels.none,
    this.maxResumeAttempts = 2,
    this.readOnly = false,
    this.collapsedMaxHeight,
    this.padding,
    this.reverse = false,
    this.identityBuilder,
    this.actionsBuilder,
    this.shell,
    this.settings,
    this.composerBuilder,
    this.composerChrome,
    this.composerBackgroundColor,
    this.composerBorderColor,
    this.composerActiveAccent,
    this.composerFocusNode,
    this.hints = const <String>[],
    this.submitPolicy = ZChatComposerSubmitPolicy.standard,
    this.pickers = const <ZChatComposerPickerAction>[],
    this.modelOptions = const <ZChatModelOption>[],
    this.modelActiveId,
    this.onSelectModel,
    this.modelSelectionMark,
    this.routeSession,
    this.routerOptions = const <ZChatModelOption>[],
    this.modelLabelOf,
    this.taskLabelKeyOf,
    this.routeSectionId,
    this.toolCatalog,
    this.toolReasonOf,
    this.onToolCommand,
    this.corpusCatalog = const <ZChatCorpusOption>[],
    this.presetCatalog = const <ZChatSettingsPreset>[],
    this.capabilityCatalog = const <ZChatSettingsHostOption>[],
    this.presentTools,
    this.onCloseTools,
    this.toolsSheetBuilder,
    this.failureBuilder,
    this.headerBuilder,
    super.key,
  });

  // ── Le contrôleur de conversation ─────────────────────────────────────────

  /// Génération des réponses.
  final ZChatStreamPort streamPort;

  /// Identité de la conversation.
  final String conversationId;

  /// Fil initial.
  final List<ZChatMessage> initialMessages;

  /// Exécuteur des verbes de l'hôte.
  final ZChatActionExecutor actionExecutor;

  /// Confirmation des verbes de conversation. Le défaut **refuse** tout
  /// verbe destructeur : brancher le dialogue de l'application.
  final ZChatConfirm confirm;

  /// Fabrique d'identités de requête. `null` signifie séquentielle.
  final ZChatRequestIdFactory? newRequestId;

  /// Construction de la requête d'un tour. `null` signifie le brouillon
  /// copié, style `converse`.
  final ZChatRequestBuilder? buildRequest;

  /// Cycle de vie de la conversation chez l'hôte.
  final ZChatConversationLifecyclePort? lifecycle;

  /// Libellés des annonces live. Sans libellé, le jalon est muet.
  final ZChatLiveLabels liveLabels;

  /// Tentatives de reprise d'un flux interrompu.
  final int maxResumeAttempts;

  /// Consultation : aucune zone de saisie. Suivi à chaque mise à jour.
  final bool readOnly;

  // ── La surface ────────────────────────────────────────────────────────────

  /// Hauteur repliée des tuiles. `null` signifie aucun repli.
  final double? collapsedMaxHeight;

  /// Marge directionnelle de la liste.
  final EdgeInsetsDirectional? padding;

  /// Liste inversée.
  final bool reverse;

  /// Créneau d'identité par message.
  final ZChatMessageSlotBuilder? identityBuilder;

  /// Créneau d'actions par message.
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// Coquille de tuile déclarée. `null` laisse l'arbre inchangé.
  final ZChatTileShell? shell;

  // ── La zone de saisie ─────────────────────────────────────────────────────

  /// Couleur du curseur — fournie par l'hôte.
  final Color cursorColor;

  /// Contrôleur de réglages **de l'hôte**. `null` : l'écran en possède un,
  /// créé et libéré avec lui.
  final ZChatSettingsController? settings;

  /// Remplace la zone de saisie par défaut. Ignoré en lecture seule.
  final ZChatConversationComposerBuilder? composerBuilder;

  /// Chrome du composer par défaut.
  final ZChatComposerChrome? composerChrome;

  /// Fond du composer par défaut.
  final Color? composerBackgroundColor;

  /// Filet du composer par défaut.
  final Color? composerBorderColor;

  /// Teinte d'état actif des bascules du composer par défaut.
  final Color? composerActiveAccent;

  /// Nœud de focus du composer par défaut.
  final FocusNode? composerFocusNode;

  /// Suggestions du placeholder, déjà localisées.
  final List<String> hints;

  /// Ce que la touche Entrée fait.
  final ZChatComposerSubmitPolicy submitPolicy;

  /// Catalogue du menu `+`. Vide signifie absent.
  final List<ZChatComposerPickerAction> pickers;

  /// Catalogue du sélecteur de modèle de l'hôte. Vide signifie absent.
  /// Remplacé par le sélecteur de routeur quand [routeSession] est déclarée.
  final List<ZChatModelOption> modelOptions;

  /// Modèle actif.
  final String? modelActiveId;

  /// Sélection d'un modèle.
  final ValueChanged<String>? onSelectModel;

  /// Glyphe d'hôte posé devant l'option active du sélecteur.
  final Widget? modelSelectionMark;

  // ── Routage ───────────────────────────────────────────────────────────────

  /// Session de routage **de l'hôte** (possédée par lui, partagée entre ses
  /// écrans). Déclarée, elle route chaque tour avant l'envoi, monte le
  /// sélecteur de routeur dans le composer et le choix de repli par tâche
  /// dans la feuille. `null` ⇒ l'écran est **strictement inchangé**.
  final ZChatRouteSession? routeSession;

  /// Catalogue du sélecteur de routeur (un id = un routeur du catalogue).
  /// Vide signifie sélecteur absent.
  final List<ZChatModelOption> routerOptions;

  /// Libellé d'un modèle candidat, déjà localisé. `null` ⇒ candidat absent.
  /// Sans résolveur, aucune entrée de repli n'est projetée.
  final ZChatModelLabelResolver? modelLabelOf;

  /// Clé de libellé d'une tâche routée. `null` ⇒ tâche absente de la
  /// feuille. Sans résolveur, aucune entrée de repli n'est projetée.
  final ZChatTaskLabelKeyResolver? taskLabelKeyOf;

  /// Section de la feuille qui reçoit les entrées de repli. `null` signifie
  /// la section de génération du socle.
  final String? routeSectionId;

  // ── Réglages et outils ────────────────────────────────────────────────────

  /// Catalogue d'outils de l'hôte. Renseigné, l'écran possède un
  /// `ZChatToolController`, projette ses entrées dans la feuille et porte
  /// son compte actif sur le déclencheur d'outils.
  final ZChatToolCatalog? toolCatalog;

  /// Résolution des jetons de raison de grisage des outils.
  final ZChatToolTokenResolver? toolReasonOf;

  /// Geste d'une action ponctuelle d'outil.
  final void Function(String key)? onToolCommand;

  /// Catalogue de corpus de la feuille. Vide signifie tuile absente.
  final List<ZChatCorpusOption> corpusCatalog;

  /// Préréglages de la feuille. Vide signifie tuile absente.
  final List<ZChatSettingsPreset> presetCatalog;

  /// Capacités de l'hôte dans la feuille. Vide signifie tuile absente.
  final List<ZChatSettingsHostOption> capabilityCatalog;

  /// Présente la feuille de réglages et d'outils. `null` signifie le bouton
  /// « outils » **absent** du composer (invariant AD-4).
  final ZChatNotebookSheetPresenter? presentTools;

  /// Geste de fermeture de la feuille par défaut. `null` signifie aucun
  /// en-tête de fermeture.
  final VoidCallback? onCloseTools;

  /// Remplace la feuille par défaut.
  final ZChatConversationToolsSheetBuilder? toolsSheetBuilder;

  // ── Échecs et action globale ──────────────────────────────────────────────

  /// Rend les échecs de tour (`lastFailure` de la conversation) au-dessus du
  /// fil. `null` signifie rien de rendu. Les échecs tus par
  /// [zChatNotebookFailureIsReportable] ne lui sont jamais présentés.
  final ZChatConversationFailureBuilder? failureBuilder;

  /// Créneau d'**action globale** rendu au-dessus du fil. `null` signifie
  /// absent.
  final ZChatConversationSlotBuilder? headerBuilder;

  @override
  State<ZChatConversationScreen> createState() =>
      _ZChatConversationScreenState();
}

class _ZChatConversationScreenState extends State<ZChatConversationScreen> {
  late final ZChatController _chat;
  ZChatSettingsController? _ownedSettings;
  ZChatToolController? _tools;

  @override
  void initState() {
    super.initState();
    // UNE création, ici et nulle part ailleurs : un contrôleur créé dans
    // `build` serait recréé à chaque frame, perdant requêtes en vol et
    // saisie.
    final String conversationId = widget.conversationId;
    _chat = ZChatController(
      streamPort: widget.streamPort,
      actionExecutor: widget.actionExecutor,
      confirm: widget.confirm,
      newRequestId:
          widget.newRequestId ?? ZChatSequentialRequestIds(conversationId).call,
      buildRequest:
          widget.buildRequest ??
          ZChatDraftRequestBuilder(
            style: ZChatGenerationStyle.converse,
            conversationId: conversationId,
          ).call,
      lifecycle: widget.lifecycle,
      // La session résout, le contrôleur décide : le résolveur est la
      // fonction PURE de la session, jamais un port.
      routeResolver: widget.routeSession?.resolve,
      liveLabels: widget.liveLabels,
      maxResumeAttempts: widget.maxResumeAttempts,
      conversationId: conversationId,
      initialMessages: widget.initialMessages,
    );
    if (widget.settings == null) _ownedSettings = ZChatSettingsController();
    final ZChatToolCatalog? catalog = widget.toolCatalog;
    if (catalog != null) _tools = ZChatToolController(catalog: catalog);
  }

  @override
  void didUpdateWidget(ZChatConversationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ZChatToolCatalog? catalog = widget.toolCatalog;
    final ZChatToolController? tools = _tools;
    if (catalog != null &&
        tools != null &&
        !identical(catalog, oldWidget.toolCatalog)) {
      tools.replaceCatalog(catalog);
    }
    if (widget.settings == null && _ownedSettings == null) {
      _ownedSettings = ZChatSettingsController();
    }
  }

  @override
  void dispose() {
    _tools?.dispose();
    _ownedSettings?.dispose();
    _chat.dispose();
    super.dispose();
  }

  ZChatSettingsController get _settings => widget.settings ?? _ownedSettings!;

  @override
  Widget build(BuildContext context) {
    final Widget body = ZChatConversationView(
      controller: _chat,
      collapsedMaxHeight: widget.collapsedMaxHeight,
      padding: widget.padding,
      reverse: widget.reverse,
      identityBuilder: widget.identityBuilder,
      actionsBuilder: widget.actionsBuilder,
      shell: widget.shell,
      composer: widget.readOnly ? null : _composer(context),
    );
    final List<Widget> above = <Widget>[
      if (widget.headerBuilder != null)
        _ZChatOptionalSlot(
          builder: (BuildContext context) =>
              widget.headerBuilder!(context, _chat),
        ),
      if (widget.failureBuilder != null)
        _ZChatFailureSlice(
          failure: _chat.lastFailure,
          builder: widget.failureBuilder!,
        ),
    ];
    // Sans créneau déclaré, l'arbre est EXACTEMENT celui de l'échappatoire :
    // la vue, et rien autour (invariant AD-4).
    if (above.isEmpty) return body;
    return Column(
      children: <Widget>[
        ...above,
        Expanded(child: body),
      ],
    );
  }

  Widget? _composer(BuildContext context) {
    final ZChatConversationComposerBuilder? custom = widget.composerBuilder;
    if (custom != null) return custom(context, _chat, _settings);
    final ZChatNotebookSheetPresenter? present = widget.presentTools;
    final ZChatToolController? tools = _tools;
    final ZChatRouteSession? session = widget.routeSession;
    return ZDefaultChatComposer(
      controller: _chat,
      settings: _settings,
      cursorColor: widget.cursorColor,
      chrome: widget.composerChrome,
      backgroundColor: widget.composerBackgroundColor,
      borderColor: widget.composerBorderColor,
      activeAccent: widget.composerActiveAccent,
      focusNode: widget.composerFocusNode,
      hints: widget.hints,
      submitPolicy: widget.submitPolicy,
      pickers: widget.pickers,
      onOpenTools: present == null ? null : () => present(context, _sheet),
      toolsBadge: tools == null
          ? null
          : ValueListenableBuilder<int>(
              valueListenable: tools.activeCount,
              builder: (BuildContext context, int count, Widget? _) =>
                  ZChatComposerCountBadge(count: count),
            ),
      showToolsBadge: tools == null,
      modelOptions: widget.modelOptions,
      modelActiveId: widget.modelActiveId,
      onSelectModel: widget.onSelectModel,
      modelSelectionMark: widget.modelSelectionMark,
      // Le sélecteur de ROUTEUR remplace le sélecteur de modèle de l'hôte
      // (règle des trois cas) — seulement si une session est déclarée.
      modelBuilder: session == null
          ? null
          : zChatRouteModelSlot(
              session: session,
              options: widget.routerOptions,
              selectionMark: widget.modelSelectionMark,
            ),
    );
  }

  Widget _sheet(BuildContext context) {
    final ZChatConversationToolsSheetBuilder? custom = widget.toolsSheetBuilder;
    if (custom != null) return custom(context, _settings, _tools);
    return zChatSettingsSheetOf(
      context,
      controller: _settings,
      tools: _tools,
      toolReasonOf: widget.toolReasonOf,
      onToolCommand: widget.onToolCommand,
      session: widget.routeSession,
      modelLabelOf: widget.modelLabelOf,
      taskLabelKeyOf: widget.taskLabelKeyOf,
      routeSectionId: widget.routeSectionId,
      corpusCatalog: widget.corpusCatalog,
      presetCatalog: widget.presetCatalog,
      capabilityCatalog: widget.capabilityCatalog,
      onClose: widget.onCloseTools,
    );
  }
}

/// Un créneau d'hôte dont le `null` est absent de l'arbre.
class _ZChatOptionalSlot extends StatelessWidget {
  const _ZChatOptionalSlot({required this.builder});

  final Widget? Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) =>
      builder(context) ?? const SizedBox.shrink();
}

/// La tranche d'échec de tour : n'écoute que sa tranche, ne rend que les
/// échecs à montrer.
class _ZChatFailureSlice extends StatelessWidget {
  const _ZChatFailureSlice({required this.failure, required this.builder});

  final ValueListenable<ZFailure?> failure;
  final ZChatConversationFailureBuilder builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZFailure?>(
      valueListenable: failure,
      builder: (BuildContext context, ZFailure? f, Widget? _) {
        if (f == null || !zChatNotebookFailureIsReportable(f)) {
          return const SizedBox.shrink();
        }
        return builder(context, f) ?? const SizedBox.shrink();
      },
    );
  }
}
