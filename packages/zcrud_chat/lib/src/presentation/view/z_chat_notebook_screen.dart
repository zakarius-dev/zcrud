/// L'écran **assemblé** du fil de travail — `ZChatNotebookScreen`.
///
/// ## Une couche mince au-dessus des briques publiques
///
/// Un fil de travail complet se compose de pièces qui existent toutes déjà :
/// `ZChatNotebookController` (conversation composée, artefacts par tranche,
/// fil persisté), `ZChatNotebookView` (la surface), le créneau d'artefacts
/// dérivé du registre (`zChatNotebookArtifactsSlot`), le composer assemblé
/// (`ZDefaultChatComposer`), la feuille de réglages (`ZChatSettingsSheet`) et
/// le contrôleur d'outils (`ZChatToolController`). Cet écran les **câble une
/// fois pour toutes** ; il n'ajoute aucune logique qui n'existe pas déjà
/// dans une brique.
///
/// Ce qu'il tient, et que chaque hôte écrivait jusqu'ici à la main :
///
/// | Point | Ici |
/// |---|---|
/// | cycle de vie du contrôleur | créé dans `initState`, libéré dans `dispose`, **jamais** dans `build` |
/// | créneau d'artefacts | dérivé du registre et des résolveurs de l'hôte, par tranche |
/// | confirmation | `confirm` et `confirmArtifactVerb` relayés ; sans eux, un verbe destructeur est **refusé** |
/// | région live | une pour les jalons d'artefact, **en plus** de celle des tours de conversation |
/// | échecs | une tranche par artefact et deux tranches globales, rendues par les créneaux de l'hôte |
/// | composer | monté sur la conversation composée, réglages et feuille d'outils branchés |
/// | hauteur repliée | dérivée de la hauteur d'écran, remplaçable |
///
/// ## Rien n'est inventé, tout est remplaçable
///
/// Le socle ne choisit ni glyphe, ni libellé, ni couleur, ni phrase d'échec :
/// les résolveurs, les libellés live, les créneaux d'échec et le dialogue de
/// confirmation viennent de l'hôte. Chaque pièce montée par défaut a son
/// paramètre de remplacement ([composerBuilder], [toolsSheetBuilder],
/// [collapsedMaxHeight], [skin], [artifactMenuBuilder]…).
///
/// ## L'échappatoire
///
/// Un hôte qui a besoin d'autre chose descend d'un cran sans rien perdre :
/// `ZChatNotebookController` + [ZChatNotebookLiveRegion] +
/// `ZChatNotebookView(actionsBuilder: zChatNotebookArtifactsSlot(...))`
/// rendent **exactement** l'arbre que cet écran rend avec ses défauts.
///
/// ## Invariant AD-2
///
/// L'écran n'écoute **aucune** tranche : chaque sous-arbre s'abonne à la
/// sienne (le fil à `messages`, le composer à `composer`/`canSend`, les
/// barres d'artefact à leurs tranches, les régions live à leur annonce). Un
/// jeton reçu, une génération qui aboutit, un réglage changé ne reconstruisent
/// ni l'écran ni le composer.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import '../notebook/z_chat_notebook_controller.dart';
import '../settings/z_chat_settings_controller.dart';
import '../tools/z_chat_tool_controller.dart';
import '../tools/z_chat_tool_settings_adapter.dart';
import '../z_chat_controller.dart';
import '../z_chat_live_labels.dart';
import 'z_chat_artifact_bar.dart';
import 'z_chat_artifact_binding.dart';
import 'z_chat_composer_band.dart';
import 'z_chat_composer_chrome.dart';
import 'z_chat_composer_keys.dart';
import 'z_chat_composer_model_selector.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart';
import 'z_chat_notebook_skin.dart';
import 'z_chat_notebook_view.dart';
import 'z_chat_settings_sheet.dart';
import 'z_default_chat_composer.dart';

/// Borne haute absolue de la hauteur repliée d'une réponse, en dp.
const double kZChatNotebookCollapsedMaxHeight = 250;

/// Fraction de la hauteur d'écran qui borne la hauteur repliée d'une
/// réponse.
const double kZChatNotebookCollapsedHeightFactor = 0.3;

/// La hauteur repliée dérivée d'une hauteur d'écran : le minimum entre
/// [kZChatNotebookCollapsedMaxHeight] et [kZChatNotebookCollapsedHeightFactor]
/// fois [screenHeight]. Une explication de plusieurs milliers de caractères
/// reste ainsi parcourable sur tout écran.
double zChatNotebookCollapsedMaxHeightOf(double screenHeight) => math.min(
      kZChatNotebookCollapsedMaxHeight,
      screenHeight * kZChatNotebookCollapsedHeightFactor,
    );

/// `true` si [failure] mérite d'être **montré** à l'utilisateur.
///
/// Deux familles sont tues par règle : `ZUnsupportedOperationFailure` (l'hôte
/// ne sait pas faire — le verbe aurait dû ne pas être déclaré, et le signaler
/// n'apprendrait rien à l'utilisateur) et `ZChatActionNotConfirmedFailure`
/// (l'utilisateur a répondu non — ce n'est pas un échec).
bool zChatNotebookFailureIsReportable(ZFailure failure) =>
    failure is! ZUnsupportedOperationFailure &&
    failure is! ZChatActionNotConfirmedFailure;

/// Présente la feuille de réglages et d'outils — modale, page, panneau :
/// l'hôte décide. [sheet] construit la feuille dans le contexte de
/// présentation que l'hôte lui donne.
typedef ZChatNotebookSheetPresenter = Future<void> Function(
  BuildContext context,
  WidgetBuilder sheet,
);

/// Remplace la feuille de réglages et d'outils par défaut. [tools] est `null`
/// quand aucun catalogue d'outils n'a été déclaré.
typedef ZChatNotebookToolsSheetBuilder = Widget Function(
  BuildContext context,
  ZChatSettingsController settings,
  ZChatToolController? tools,
);

/// Remplace la zone de saisie par défaut. Rendre `null` signifie aucune zone
/// de saisie (invariant AD-4).
typedef ZChatNotebookComposerBuilder = Widget? Function(
  BuildContext context,
  ZChatNotebookController controller,
  ZChatSettingsController settings,
);

/// Rend un échec **global** (écriture du fil, tour de conversation). Rendre
/// `null` signifie rien d'affiché pour cet échec.
typedef ZChatNotebookFailureBuilder = Widget? Function(
  BuildContext context,
  ZFailure failure,
);

/// Rend l'échec d'un **artefact** d'un message. Rendre `null` signifie rien
/// d'affiché pour cet échec.
typedef ZChatNotebookArtifactFailureBuilder = Widget? Function(
  BuildContext context,
  ZChatMessage message,
  String artifactKey,
  ZFailure failure,
);

/// Un créneau de l'écran qui reçoit le contrôleur de fil de travail. Rendre
/// `null` signifie absent de l'arbre (invariant AD-4).
typedef ZChatNotebookSlotBuilder = Widget? Function(
  BuildContext context,
  ZChatNotebookController controller,
);

/// L'écran assemblé d'un fil de travail : une déclaration (ports, registre,
/// résolveurs, confirmation) et un écran fonctionnel.
class ZChatNotebookScreen extends StatefulWidget {
  /// Construit l'écran.
  ///
  /// Les ports et réglages du contrôleur ([streamPort], [transcript],
  /// [conversationId], [registry], [generationPort], [store], [statePort],
  /// [actionExecutor], [confirm], [confirmArtifactVerb], [newRequestId],
  /// [buildRequest], [decorateRequest], [lifecycle], [liveLabels],
  /// [maxResumeAttempts]) sont **lus une fois**, à la création du contrôleur :
  /// pour changer de conversation, donner une `key` différente à l'écran.
  /// [readOnly] et [toolCatalog], eux, sont suivis à chaque mise à jour.
  const ZChatNotebookScreen({
    required this.streamPort,
    required this.transcript,
    required this.conversationId,
    required this.cursorColor,
    this.registry,
    this.generationPort,
    this.store,
    this.statePort,
    this.actionExecutor = const ZChatUnsupportedActionExecutor(),
    this.confirm = zChatConfirmWithoutDialog,
    this.confirmArtifactVerb = zChatConfirmArtifactWithoutDialog,
    this.newRequestId,
    this.buildRequest,
    this.decorateRequest,
    this.lifecycle,
    this.liveLabels = ZChatLiveLabels.none,
    this.maxResumeAttempts = 2,
    this.readOnly = false,
    this.resolvers = ZChatArtifactResolvers.none,
    this.actionsBuilder,
    this.skin,
    this.artifactMenuBuilder,
    this.artifactMenuCrossAxisCount = kZChatArtifactMenuCrossAxisCount,
    this.artifactSpacing,
    this.collapsedMaxHeight,
    this.padding,
    this.reverse = false,
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
    this.artifactFailureBuilder,
    this.headerBuilder,
    super.key,
  });

  // ── Le contrôleur de fil de travail ───────────────────────────────────────

  /// Génération des réponses.
  final ZChatStreamPort streamPort;

  /// Lecture et écriture du fil.
  final ZChatTranscriptPort transcript;

  /// Identité de la conversation.
  final String conversationId;

  /// Les artefacts déclarés. `null` signifie aucun artefact.
  final ZChatArtifactRegistry? registry;

  /// Génération des artefacts. `null` : « créer » et « régénérer » sont
  /// refusés par `ZUnsupportedOperationFailure`.
  final ZChatArtifactGenerationPort? generationPort;

  /// Stockage des artefacts. `null` signifie en mémoire.
  final ZChatArtifactStorePort? store;

  /// Existence des artefacts. `null` : lue dans [store].
  final ZChatArtifactStatePort? statePort;

  /// Exécuteur des verbes de l'hôte.
  final ZChatActionExecutor actionExecutor;

  /// Confirmation des verbes de conversation. Le défaut **refuse** tout
  /// verbe destructeur : brancher le dialogue de l'application.
  final ZChatConfirm confirm;

  /// Confirmation des verbes d'artefact destructeurs. Le défaut **refuse** :
  /// brancher le dialogue de l'application, dont le message se choisit par
  /// `ZChatArtifactVerbAction.confirmToken`.
  final ZChatArtifactVerbConfirm confirmArtifactVerb;

  /// Fabrique d'identités de requête. `null` signifie séquentielle.
  final ZChatRequestIdFactory? newRequestId;

  /// Construction de la requête d'un tour. `null` signifie le brouillon
  /// copié, style `converse`.
  final ZChatRequestBuilder? buildRequest;

  /// Ajustement de la requête de génération d'un artefact.
  final ZChatArtifactRequestDecorator? decorateRequest;

  /// Cycle de vie de la conversation chez l'hôte.
  final ZChatConversationLifecyclePort? lifecycle;

  /// Libellés des annonces live — tours **et** artefacts. Sans libellé, le
  /// jalon est muet.
  final ZChatLiveLabels liveLabels;

  /// Tentatives de reprise d'un flux interrompu.
  final int maxResumeAttempts;

  /// Consultation : aucune zone de saisie, et le contrôleur retire les verbes
  /// d'écriture des artefacts. Suivi à chaque mise à jour.
  final bool readOnly;

  // ── La surface ────────────────────────────────────────────────────────────

  /// Résolveurs d'icône, de libellé et d'accent des artefacts déclarés.
  final ZChatArtifactResolvers resolvers;

  /// Créneau d'actions propre à l'hôte, rendu au-dessus de la barre
  /// d'artefacts de chaque message.
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// Réglage de rendu du notebook — relayé à la vue et à la barre.
  final ZChatNotebookSkin? skin;

  /// Présentation injectée des menus d'artefact.
  final ZChatArtifactMenuBuilder? artifactMenuBuilder;

  /// Colonnes de la grille de menu par défaut.
  final int artifactMenuCrossAxisCount;

  /// Écart entre deux artefacts de la barre.
  final double? artifactSpacing;

  /// Hauteur repliée des tuiles. `null` signifie
  /// [zChatNotebookCollapsedMaxHeightOf] sur la hauteur d'écran.
  final double? collapsedMaxHeight;

  /// Marge directionnelle de la liste.
  final EdgeInsetsDirectional? padding;

  /// Liste inversée.
  final bool reverse;

  // ── La zone de saisie ─────────────────────────────────────────────────────

  /// Couleur du curseur — fournie par l'hôte, même arbitrage que
  /// `ZChatComposer.cursorColor`.
  final Color cursorColor;

  /// Contrôleur de réglages **de l'hôte** (persisté chez lui). `null` : l'écran
  /// en possède un, créé et libéré avec lui.
  final ZChatSettingsController? settings;

  /// Remplace la zone de saisie par défaut ([ZDefaultChatComposer] sur la
  /// conversation composée). Ignoré en lecture seule.
  final ZChatNotebookComposerBuilder? composerBuilder;

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

  /// Catalogue du sélecteur de modèle. Vide signifie absent.
  final List<ZChatModelOption> modelOptions;

  /// Modèle actif.
  final String? modelActiveId;

  /// Sélection d'un modèle.
  final ValueChanged<String>? onSelectModel;

  // ── Réglages et outils ────────────────────────────────────────────────────

  /// Catalogue d'outils de l'hôte. Renseigné, l'écran possède un
  /// `ZChatToolController` (créé et libéré avec lui), projette ses entrées
  /// dans la feuille et porte son compte actif sur le déclencheur d'outils.
  /// Une nouvelle valeur remplace le catalogue en place.
  final ZChatToolCatalog? toolCatalog;

  /// Résolution des jetons de raison de grisage des outils.
  final ZChatToolTokenResolver? toolReasonOf;

  /// Geste d'une action ponctuelle d'outil. Sans lui, une action n'est pas
  /// projetée.
  final void Function(String key)? onToolCommand;

  /// Catalogue de corpus de la feuille. Vide signifie tuile absente.
  final List<ZChatCorpusOption> corpusCatalog;

  /// Préréglages de la feuille. Vide signifie tuile absente.
  final List<ZChatSettingsPreset> presetCatalog;

  /// Capacités de l'hôte dans la feuille. Vide signifie tuile absente.
  final List<ZChatSettingsHostOption> capabilityCatalog;

  /// Présente la feuille de réglages et d'outils. `null` signifie le bouton
  /// « outils » **absent** du composer (invariant AD-4) : le socle ne sait
  /// pas comment l'hôte présente une feuille.
  final ZChatNotebookSheetPresenter? presentTools;

  /// Geste de fermeture de la feuille par défaut — c'est l'hôte qui possède
  /// le conteneur. `null` signifie aucun en-tête de fermeture.
  final VoidCallback? onCloseTools;

  /// Remplace la feuille par défaut ([ZChatSettingsSheet] avec les entrées
  /// projetées du catalogue d'outils).
  final ZChatNotebookToolsSheetBuilder? toolsSheetBuilder;

  // ── Échecs et action globale ──────────────────────────────────────────────

  /// Rend les échecs **globaux** — écriture du fil (`lastFailure` du fil de
  /// travail) et tour de conversation (`lastFailure` de la conversation) —
  /// au-dessus du fil. `null` signifie rien de rendu. Les échecs tus par
  /// [zChatNotebookFailureIsReportable] ne lui sont jamais présentés.
  final ZChatNotebookFailureBuilder? failureBuilder;

  /// Rend l'échec d'un **artefact**, sous les actions du message porteur,
  /// depuis la tranche `failureOf` du couple. `null` signifie rien de rendu.
  /// Les échecs tus par [zChatNotebookFailureIsReportable] ne lui sont jamais
  /// présentés.
  final ZChatNotebookArtifactFailureBuilder? artifactFailureBuilder;

  /// Créneau d'**action globale** rendu au-dessus du fil — exporter le fil
  /// entier, l'imprimer, le partager. Le socle n'implémente aucune de ces
  /// actions : il offre la place et le contrôleur. `null` signifie absent.
  final ZChatNotebookSlotBuilder? headerBuilder;

  @override
  State<ZChatNotebookScreen> createState() => _ZChatNotebookScreenState();
}

class _ZChatNotebookScreenState extends State<ZChatNotebookScreen> {
  late final ZChatNotebookController _nb;
  ZChatSettingsController? _ownedSettings;
  ZChatToolController? _tools;

  @override
  void initState() {
    super.initState();
    // UNE création, ici et nulle part ailleurs : un contrôleur créé dans
    // `build` serait recréé à chaque frame, perdant requêtes en vol,
    // abonnement au fil et tranches d'artefact.
    _nb = ZChatNotebookController(
      streamPort: widget.streamPort,
      transcript: widget.transcript,
      conversationId: widget.conversationId,
      registry: widget.registry,
      generationPort: widget.generationPort,
      store: widget.store,
      statePort: widget.statePort,
      actionExecutor: widget.actionExecutor,
      confirm: widget.confirm,
      confirmArtifactVerb: widget.confirmArtifactVerb,
      newRequestId: widget.newRequestId,
      buildRequest: widget.buildRequest,
      decorateRequest: widget.decorateRequest,
      lifecycle: widget.lifecycle,
      liveLabels: widget.liveLabels,
      maxResumeAttempts: widget.maxResumeAttempts,
      readOnly: widget.readOnly,
    );
    if (widget.settings == null) _ownedSettings = ZChatSettingsController();
    final ZChatToolCatalog? catalog = widget.toolCatalog;
    if (catalog != null) _tools = ZChatToolController(catalog: catalog);
  }

  @override
  void didUpdateWidget(ZChatNotebookScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readOnly != widget.readOnly) {
      _nb.setReadOnly(widget.readOnly);
    }
    final ZChatToolCatalog? catalog = widget.toolCatalog;
    final ZChatToolController? tools = _tools;
    if (catalog != null &&
        tools != null &&
        !identical(catalog, oldWidget.toolCatalog)) {
      tools.replaceCatalog(catalog);
    }
    // Un hôte qui cesse de fournir ses réglages après coup obtiendrait un
    // composer sans contrôleur : l'écran en crée un à ce moment-là plutôt
    // que de lever.
    if (widget.settings == null && _ownedSettings == null) {
      _ownedSettings = ZChatSettingsController();
    }
  }

  @override
  void dispose() {
    _tools?.dispose();
    _ownedSettings?.dispose();
    _nb.dispose();
    super.dispose();
  }

  ZChatSettingsController get _settings => widget.settings ?? _ownedSettings!;

  @override
  Widget build(BuildContext context) {
    final Widget body = ZChatNotebookLiveRegion(
      announcement: _nb.liveAnnouncement,
      child: ZChatNotebookView(
        controller: _nb.chat,
        actionsBuilder: zChatNotebookArtifactsSlot(
          controller: _nb,
          resolvers: widget.resolvers,
          host: _hostSlot(),
          skin: widget.skin,
          spacing: widget.artifactSpacing,
          menuBuilder: widget.artifactMenuBuilder,
          menuCrossAxisCount: widget.artifactMenuCrossAxisCount,
        ),
        skin: widget.skin,
        collapsedMaxHeight: widget.collapsedMaxHeight ??
            zChatNotebookCollapsedMaxHeightOf(
              MediaQuery.sizeOf(context).height,
            ),
        padding: widget.padding,
        reverse: widget.reverse,
        composer: widget.readOnly ? null : _composer(context),
      ),
    );
    final List<Widget> above = <Widget>[
      if (widget.headerBuilder != null)
        _ZChatOptionalSlot(
          builder: (BuildContext context) =>
              widget.headerBuilder!(context, _nb),
        ),
      if (widget.failureBuilder != null) ...<Widget>[
        _ZChatFailureSlice(
          failure: _nb.lastFailure,
          builder: widget.failureBuilder!,
        ),
        _ZChatFailureSlice(
          failure: _nb.chat.lastFailure,
          builder: widget.failureBuilder!,
        ),
      ],
    ];
    // Sans créneau déclaré, l'arbre est EXACTEMENT celui de l'échappatoire :
    // région live, vue — rien autour (invariant AD-4).
    if (above.isEmpty) return body;
    return Column(
      children: <Widget>[...above, Expanded(child: body)],
    );
  }

  /// Le créneau de l'hôte, enrichi — seulement si l'hôte l'a demandé — de
  /// la tranche d'échec des artefacts du message. Sans rendu d'échec, c'est
  /// le créneau de l'hôte **à l'identique** (même référence).
  ZChatMessageSlotBuilder? _hostSlot() {
    final ZChatNotebookArtifactFailureBuilder? onFailure =
        widget.artifactFailureBuilder;
    final ZChatMessageSlotBuilder? own = widget.actionsBuilder;
    if (onFailure == null) return own;
    final List<String> keys = <String>[
      for (final ZChatArtifactDeclaration d in _nb.registry.declarations) d.key,
    ];
    if (keys.isEmpty) return own;
    return (BuildContext context, ZChatMessage message) {
      final Widget? host = own?.call(context, message);
      final String? id = message.id;
      if (id == null) return host;
      final Widget slice = _ZChatArtifactFailureSlice(
        controller: _nb,
        message: message,
        keys: keys,
        builder: onFailure,
      );
      if (host == null) return slice;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[host, slice],
      );
    };
  }

  Widget? _composer(BuildContext context) {
    final ZChatNotebookComposerBuilder? custom = widget.composerBuilder;
    if (custom != null) return custom(context, _nb, _settings);
    final ZChatNotebookSheetPresenter? present = widget.presentTools;
    final ZChatToolController? tools = _tools;
    return ZDefaultChatComposer(
      controller: _nb.chat,
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
      onOpenTools: present == null
          ? null
          : () => present(context, _sheet),
      // Le compte des OUTILS remplace celui des réglages sur le déclencheur
      // quand un catalogue est déclaré : un seul nombre, celui de la feuille
      // que le bouton ouvre.
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
    );
  }

  Widget _sheet(BuildContext context) {
    final ZChatNotebookToolsSheetBuilder? custom = widget.toolsSheetBuilder;
    if (custom != null) return custom(context, _settings, _tools);
    final ZChatToolController? tools = _tools;
    if (tools == null) {
      return ZChatSettingsSheet(
        controller: _settings,
        corpusCatalog: widget.corpusCatalog,
        presetCatalog: widget.presetCatalog,
        capabilityCatalog: widget.capabilityCatalog,
        onClose: widget.onCloseTools,
      );
    }
    // La feuille suit le contrôleur d'outils : une projection se refait
    // quand le catalogue change, jamais sur un jeton du fil.
    return ListenableBuilder(
      listenable: tools,
      builder: (BuildContext context, Widget? _) => ZChatSettingsSheet(
        controller: _settings,
        corpusCatalog: widget.corpusCatalog,
        presetCatalog: widget.presetCatalog,
        capabilityCatalog: widget.capabilityCatalog,
        onClose: widget.onCloseTools,
        sections: zChatToolSettingsSections(tools),
        entries: zChatToolSettingsEntries(
          tools,
          query: tools.query.value,
          reasonOf: widget.toolReasonOf,
          onCommand: widget.onToolCommand,
        ),
      ),
    );
  }
}

/// Région live des jalons d'**artefact** (génération lancée, aboutie,
/// échouée ; suppression), à monter **en plus** de celle des tours de
/// conversation que la vue porte déjà. Le libellé suit [announcement] ;
/// sans annonce en cours, le nœud porte le libellé neutre de la région.
///
/// Le sous-arbre est passé en `child` : une annonce ne reconstruit pas la
/// vue.
class ZChatNotebookLiveRegion extends StatelessWidget {
  /// Construit la région.
  const ZChatNotebookLiveRegion({
    required this.announcement,
    required this.child,
    super.key,
  });

  /// La tranche d'annonce — `ZChatNotebookController.liveAnnouncement`.
  final ValueListenable<String> announcement;

  /// Le sous-arbre porteur du nœud.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: announcement,
      builder: (BuildContext context, String text, Widget? child) {
        return Semantics(
          container: true,
          liveRegion: true,
          label: text.isEmpty
              ? zChatLabel(context, kZChatLabelLiveRegion)
              : text,
          child: child,
        );
      },
      child: child,
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

/// Une tranche d'échec global : n'écoute que sa tranche, ne rend que les
/// échecs à montrer.
class _ZChatFailureSlice extends StatelessWidget {
  const _ZChatFailureSlice({required this.failure, required this.builder});

  final ValueListenable<ZFailure?> failure;
  final ZChatNotebookFailureBuilder builder;

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

/// La tranche d'échec des artefacts d'UN message : écoute les tranches
/// `failureOf` de ce message seulement, rend le premier échec à montrer,
/// dans l'ordre du registre.
class _ZChatArtifactFailureSlice extends StatelessWidget {
  const _ZChatArtifactFailureSlice({
    required this.controller,
    required this.message,
    required this.keys,
    required this.builder,
  });

  final ZChatNotebookController controller;
  final ZChatMessage message;
  final List<String> keys;
  final ZChatNotebookArtifactFailureBuilder builder;

  @override
  Widget build(BuildContext context) {
    final String id = message.id!;
    final List<ValueListenable<ZFailure?>> slices =
        <ValueListenable<ZFailure?>>[
      for (final String k in keys) controller.failureOf(id, k),
    ];
    return ListenableBuilder(
      listenable: Listenable.merge(slices),
      builder: (BuildContext context, Widget? _) {
        for (int i = 0; i < keys.length; i++) {
          final ZFailure? f = slices[i].value;
          if (f == null || !zChatNotebookFailureIsReportable(f)) continue;
          return builder(context, message, keys[i], f) ??
              const SizedBox.shrink();
        }
        return const SizedBox.shrink();
      },
    );
  }
}
