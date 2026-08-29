/// `ZMindmapGenerationSheet` — feuille de génération de carte mentale par IA,
/// et injection Flutter-native du port qui la rend disponible.
///
/// ## Composition, jamais de moteur dupliqué
///
/// - Cycle de vie asynchrone, jeton de fraîcheur, matérialisation : délégués à
///   [ZMindmapGenerationController] (aucun dépôt, aucun store).
/// - Revue des nœuds générés : déléguée à `ZMindmapOutlineEditor` — la surface
///   d'édition d'outline existante, avec ses gestes (ajout, indentation,
///   suppression) et ses libellés a11y. Aucun éditeur parallèle n'est écrit
///   ici, et **ce sont les nœuds ÉDITÉS dans cette revue** qui sont
///   matérialisés à la validation.
///
/// ## Réactivité granulaire (invariant AD-2)
///
/// Les `TextEditingController` (contenu, instructions) sont créés une seule
/// fois en `initState` (jamais dans `build`) et vivent hors du
/// `ListenableBuilder` du statut : taper n'y reconstruit ni l'aire de revue ni
/// la surface hôte, et ne perd jamais le focus. La sélection de source et
/// l'option de condensation sont pilotées par des `ValueNotifier` locaux, à
/// tranche ciblée.
///
/// ## Rien n'est écrit par cette feuille
///
/// Le seul canal de sortie est le handoff [ZMindmapGeneratedCallback] : c'est
/// l'application qui écrit la carte reçue par la voie de persistance de son
/// choix. Un échec, un résultat vide ou une fermeture ne remettent rien.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

import '../domain/z_mindmap_generation_port.dart';
import 'z_mindmap_generation_controller.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Hauteur de repli du viewport de REVUE. L'éditeur d'outline contient un
/// `ListView` : imbriqué dans une feuille défilante, il exige une contrainte
/// de hauteur bornée. Dimension de LAYOUT admissible (jamais une couleur ni un
/// libellé), surchargeable par l'appelant.
const double _kDefaultReviewHeight = 320.0;

/// Option de source SÉLECTIONNABLE présentée par l'application.
///
/// L'hôte les construit depuis son propre référentiel (document, note,
/// conversation…) : la feuille reste registre-agnostique et extensible sans
/// toucher à ce paquet. [source] `null` ⇒ **texte libre** (seul le contenu
/// saisi part au port).
@immutable
class ZMindmapGenerationSourceOption {
  /// Construit une option de source.
  const ZMindmapGenerationSourceOption({required this.label, this.source});

  /// Libellé INJECTÉ de l'option (i18n).
  final String label;

  /// Référence opaque transmise telle quelle dans la requête, ou `null` pour
  /// une génération à partir du seul contenu saisi.
  final ZMindmapSourceRef? source;
}

/// Libellés INJECTÉS de la feuille de génération (i18n — aucun libellé en dur,
/// FR-26). Tous requis : un défaut dans une langue serait un libellé en dur
/// sans voie de remplacement.
@immutable
class ZMindmapGenerationLabels {
  /// Construit les libellés injectés.
  const ZMindmapGenerationLabels({
    required this.contentLabel,
    required this.contentHint,
    required this.instructionsLabel,
    required this.instructionsHint,
    required this.sourceLabel,
    required this.summarizeLabel,
    required this.generateLabel,
    required this.generatingLabel,
    required this.reviewTitle,
  });

  /// Libellé du champ de contenu source.
  final String contentLabel;

  /// Indice du champ de contenu source.
  final String contentHint;

  /// Libellé du champ d'instructions libres.
  final String instructionsLabel;

  /// Indice du champ d'instructions libres.
  final String instructionsHint;

  /// Libellé du sélecteur de source.
  final String sourceLabel;

  /// Libellé de l'option « résumer » (condenser la source plutôt que la
  /// développer).
  final String summarizeLabel;

  /// Libellé du bouton de génération.
  final String generateLabel;

  /// Libellé affiché pendant la génération.
  final String generatingLabel;

  /// Titre de l'aire de revue des nœuds générés.
  final String reviewTitle;
}

/// Feuille de génération IA d'une carte mentale, revue puis matérialisée.
class ZMindmapGenerationSheet extends StatefulWidget {
  /// Construit la feuille autour d'un [port] faillible.
  ///
  /// La carte validée est matérialisée dans [folderId] et remise à
  /// [onGenerated] — c'est l'appelant qui l'écrit.
  const ZMindmapGenerationSheet({
    required this.port,
    required this.folderId,
    required this.messages,
    required this.labels,
    this.sources = const <ZMindmapGenerationSourceOption>[],
    this.onGenerated,
    this.outlineLabels = const ZMindmapOutlineLabels(),
    this.viewConfig = const ZMindmapViewConfig(),
    this.title = '',
    this.languageTag,
    this.modelId,
    this.routeId,
    this.reviewHeight = _kDefaultReviewHeight,
    super.key,
  });

  /// Port de génération (injecté par l'application hôte).
  final ZMindmapGenerationPort port;

  /// Dossier dans lequel la carte validée est matérialisée (clé opaque).
  final String folderId;

  /// Messages d'échec injectés (transmis au contrôleur).
  final ZMindmapGenerationMessages messages;

  /// Libellés injectés de la feuille.
  final ZMindmapGenerationLabels labels;

  /// Options de source présentées. Vide ⇒ aucun sélecteur rendu.
  final List<ZMindmapGenerationSourceOption> sources;

  /// Handoff de la carte matérialisée. `null` ⇒ non remise.
  final ZMindmapGeneratedCallback? onGenerated;

  /// Libellés a11y de l'éditeur d'outline utilisé pour la revue (transmis).
  final ZMindmapOutlineLabels outlineLabels;

  /// Configuration de layout transmise à l'éditeur de revue.
  final ZMindmapViewConfig viewConfig;

  /// Titre de la carte matérialisée (vide ⇒ défaut d'affichage).
  final String title;

  /// Étiquette de langue BCP-47 transmise telle quelle à la requête.
  final String? languageTag;

  /// Identifiant de modèle OPAQUE transporté verbatim (jamais interprété).
  final String? modelId;

  /// Route de génération transportée verbatim (jamais interprétée, jamais une
  /// URL — invariant AD-12).
  final String? routeId;

  /// Hauteur bornée de l'aire de revue (contrainte requise ; surchargeable).
  final double reviewHeight;

  @override
  State<ZMindmapGenerationSheet> createState() =>
      _ZMindmapGenerationSheetState();
}

class _ZMindmapGenerationSheetState extends State<ZMindmapGenerationSheet> {
  // Controllers STABLES (créés UNE fois, jamais dans build() — AD-2).
  late final TextEditingController _contentController;
  late final TextEditingController _instructionsController;

  // Tranches LOCALES pilotées granulairement (SM-1).
  late final ValueNotifier<int> _sourceIndex;
  late final ValueNotifier<bool> _summarize;

  late final ZMindmapGenerationController _generation;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _instructionsController = TextEditingController();
    _sourceIndex = ValueNotifier<int>(0);
    _summarize = ValueNotifier<bool>(false);
    _generation = ZMindmapGenerationController(
      port: widget.port,
      folderId: widget.folderId,
      messages: widget.messages,
      onGenerated: widget.onGenerated,
      title: widget.title,
      routeId: widget.routeId,
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _instructionsController.dispose();
    _sourceIndex.dispose();
    _summarize.dispose();
    _generation.dispose();
    super.dispose();
  }

  /// Construit la requête soumise au port. `modelId` et `routeId` voyagent
  /// VERBATIM ; la feuille ne les lit ni ne les dérive.
  ZMindmapGenerationRequest _buildRequest() {
    final index = _sourceIndex.value;
    final source = index >= 0 && index < widget.sources.length
        ? widget.sources[index].source
        : null;
    final instructions = _instructionsController.text.trim();
    return ZMindmapGenerationRequest(
      content: _contentController.text,
      source: source,
      languageTag: widget.languageTag,
      instructions: instructions.isEmpty ? null : instructions,
      modelId: widget.modelId,
      summarize: _summarize.value,
      routeId: widget.routeId,
    );
  }

  void _submit() => _generation.generate(_buildRequest());

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final labels = widget.labels;
    return ListenableBuilder(
      listenable: _generation,
      builder: (context, _) {
        if (_generation.status == ZMindmapGenerationStatus.reviewing) {
          return _buildReview(theme, labels);
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSourceSelector(theme, labels),
              // Champ de contenu — controller STABLE, hors des tranches
              // réactives : taper ne reconstruit rien d'autre que lui-même.
              TextField(
                key: const ValueKey<String>('z-mindmap-generation-content'),
                controller: _contentController,
                textAlign: TextAlign.start,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: labels.contentLabel,
                  hintText: labels.contentHint,
                ),
              ),
              SizedBox(height: theme.gapM),
              TextField(
                key: const ValueKey<String>('z-mindmap-generation-instructions'),
                controller: _instructionsController,
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: labels.instructionsLabel,
                  hintText: labels.instructionsHint,
                ),
              ),
              SizedBox(height: theme.gapM),
              _buildSummarizeSwitch(labels),
              SizedBox(height: theme.gapL),
              _buildActionArea(labels),
              _buildResultArea(theme),
            ],
          ),
        );
      },
    );
  }

  /// Sélecteur de source. Aucune option ⇒ **rien** n'est rendu (jamais un
  /// sélecteur vide, jamais un gap orphelin : le gap vit à l'intérieur).
  Widget _buildSourceSelector(
    ZcrudTheme theme,
    ZMindmapGenerationLabels labels,
  ) {
    if (widget.sources.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(labels.sourceLabel, textAlign: TextAlign.start),
        SizedBox(height: theme.gapS),
        ValueListenableBuilder<int>(
          valueListenable: _sourceIndex,
          builder: (context, selected, _) => Wrap(
            spacing: theme.gapM,
            runSpacing: theme.gapS,
            children: <Widget>[
              for (var i = 0; i < widget.sources.length; i++)
                ChoiceChip(
                  key: ValueKey<String>('z-mindmap-generation-source-$i'),
                  label:
                      Text(widget.sources[i].label, textAlign: TextAlign.start),
                  selected: selected == i,
                  onSelected: (_) => _sourceIndex.value = i,
                ),
            ],
          ),
        ),
        SizedBox(height: theme.gapM),
      ],
    );
  }

  Widget _buildSummarizeSwitch(ZMindmapGenerationLabels labels) {
    return ValueListenableBuilder<bool>(
      valueListenable: _summarize,
      builder: (context, on, _) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: SwitchListTile(
          key: const ValueKey<String>('z-mindmap-generation-summarize'),
          contentPadding: EdgeInsets.zero,
          value: on,
          onChanged: (next) => _summarize.value = next,
          title: Text(labels.summarizeLabel, textAlign: TextAlign.start),
        ),
      ),
    );
  }

  Widget _buildActionArea(ZMindmapGenerationLabels labels) {
    final generating =
        _generation.status == ZMindmapGenerationStatus.generating;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: ElevatedButton(
        key: const ValueKey<String>('z-mindmap-generation-submit'),
        // Anti-double-soumission : le contrôleur ignore toute soumission
        // pendant `generating` — le bouton reflète l'état.
        onPressed: generating ? null : _submit,
        child: Text(
          generating ? labels.generatingLabel : labels.generateLabel,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Aire de résultat NON bloquante : échec et résultat vide sont annoncés
  /// (`liveRegion`) sans quitter la feuille — la saisie reste intacte.
  Widget _buildResultArea(ZcrudTheme theme) {
    switch (_generation.status) {
      case ZMindmapGenerationStatus.failed:
      case ZMindmapGenerationStatus.empty:
        final message = _generation.errorMessage ?? '';
        final key = _generation.status == ZMindmapGenerationStatus.failed
            ? const ValueKey<String>('z-mindmap-generation-error')
            : const ValueKey<String>('z-mindmap-generation-empty');
        return Padding(
          padding: EdgeInsetsDirectional.only(top: theme.gapM),
          child: Semantics(
            liveRegion: true,
            child: Text(message, key: key, textAlign: TextAlign.start),
          ),
        );
      case ZMindmapGenerationStatus.idle:
      case ZMindmapGenerationStatus.generating:
      case ZMindmapGenerationStatus.reviewing:
        return const SizedBox.shrink();
    }
  }

  /// Aire de REVUE : l'éditeur d'outline existant, seedé sur la forêt générée.
  ///
  /// La validation passe par le bouton d'enregistrement de l'éditeur, qui émet
  /// **la forêt mutée** — donc les nœuds tels qu'édités, jamais ceux d'origine.
  Widget _buildReview(ZcrudTheme theme, ZMindmapGenerationLabels labels) {
    return Column(
      key: const ValueKey<String>('z-mindmap-generation-review'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(labels.reviewTitle, textAlign: TextAlign.start),
        SizedBox(height: theme.gapS),
        SizedBox(
          height: widget.reviewHeight,
          child: ZMindmapOutlineEditor(
            roots: _generation.nodes,
            labels: widget.outlineLabels,
            config: widget.viewConfig,
            onSave: _generation.confirm,
          ),
        ),
      ],
    );
  }
}

/// Injection Flutter-native d'un [ZMindmapGenerationPort] OPTIONNEL
/// (AD-2/AD-15).
///
/// `InheritedWidget` PUR (aucun état mutable). Les surfaces qui offrent la
/// génération y lisent le port : **absent** ⇒ l'action est ABSENTE de l'arbre,
/// jamais grisée.
class ZMindmapGenerationScope extends InheritedWidget {
  /// Injecte [port] (éventuellement `null`) dans le sous-arbre [child].
  const ZMindmapGenerationScope({
    required this.port,
    required super.child,
    super.key,
  });

  /// Port injecté (ou `null` = génération indisponible).
  final ZMindmapGenerationPort? port;

  /// Port du plus proche ancêtre, ou `null` si aucun.
  static ZMindmapGenerationPort? maybePortOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZMindmapGenerationScope>()
      ?.port;

  @override
  bool updateShouldNotify(ZMindmapGenerationScope oldWidget) =>
      !identical(port, oldWidget.port);
}
