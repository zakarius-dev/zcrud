/// `ZFlashcardGenerationSheet` + point d'entrée conditionnel (SU-9/AC1/AC10..AC13
/// — AD-37/AD-2/AD-13).
///
/// ## Composition, pas de logique dupliquée
///
/// - Bornage `count` / répartition par type ⇒ `z_flashcard_generation_defaults`
///   (SOURCE UNIQUE — aucun littéral `1`/`50`, aucune répartition maison ici).
/// - Cycle de vie asynchrone / jeton de fraîcheur / handoff ⇒
///   [ZFlashcardGenerationController] (aucun store).
/// - Aperçu des cartes ⇒ [ZFlashcardPreview] → `ZFlashcardReviewCard` (su-2),
///   **jamais** un rendu de flashcard parallèle (AC10).
/// - Confirmation des tags ⇒ [ZFlashcardTagConfirmSheet] → [ZTagEditor] (AC9).
///
/// ## SM-1 (AC13) : réactivité granulaire
///
/// Les `TextEditingController` (contenu/instructions/modelId) sont créés UNE FOIS
/// en `initState` (jamais dans `build`) et vivent HORS du `ListenableBuilder` du
/// statut ⇒ taper n'y reconstruit pas l'aire d'aperçu et ne perd jamais le focus.
/// Slider et chips sont pilotés par des `ValueNotifier` LOCAUX (tranche ciblée).
///
/// ## `modelId` OPAQUE (AC2)
///
/// Le champ `modelId` est une simple `String` transportée VERBATIM : la feuille ne
/// l'interprète jamais (aucun `enum`, aucun `switch`, aucun catalogue).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, ZSuggestedTag;

import '../domain/z_flashcard_generation_defaults.dart';
import '../domain/z_flashcard_generation_port.dart';
import 'z_flashcard_generation_controller.dart';
import 'z_flashcard_preview.dart';
import 'z_flashcard_tag_confirm_sheet.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Option de source SÉLECTIONNABLE (AC1). L'app la construit depuis
/// `ZSourceRegistry` (document/pages, sujets, texte libre, article, note…) — la
/// feuille reste registre-agnostique et EXTENSIBLE sans toucher zcrud.
@immutable
class ZGenerationSourceOption {
  /// Construit une option. [provenance] `null` ⇒ « texte libre » (aucune source).
  const ZGenerationSourceOption({required this.label, this.provenance});

  /// Libellé INJECTÉ de l'option (i18n).
  final String label;

  /// Provenance à estampiller dans les cartes (AC5) — issue de `ZSourceRegistry`.
  final ZFlashcardSource? provenance;
}

/// Libellés INJECTÉS de la feuille de génération (i18n — AC12).
@immutable
class ZFlashcardGenerationLabels {
  /// Construit les libellés injectés.
  const ZFlashcardGenerationLabels({
    required this.contentLabel,
    required this.contentHint,
    required this.countLabel,
    required this.instructionsLabel,
    required this.instructionsHint,
    required this.modelIdLabel,
    required this.modelIdHint,
    required this.sourceLabel,
    required this.generateLabel,
    required this.generatingLabel,
    required this.proceedToTagsLabel,
    required this.previewTitle,
    required this.typeLabels,
    required this.tagConfirmTitle,
    required this.tagConfirmApply,
    required this.tagConfirmCancel,
    required this.tagInputLabel,
    required this.tagInputHint,
    required this.tagAddSemanticLabel,
  });

  /// Libellé du champ de contenu source.
  final String contentLabel;

  /// Indice du champ de contenu source.
  final String contentHint;

  /// Libellé du réglage « nombre de cartes ».
  final String countLabel;

  /// Libellé du champ d'instructions libres.
  final String instructionsLabel;

  /// Indice du champ d'instructions libres.
  final String instructionsHint;

  /// Libellé du champ `modelId` opaque.
  final String modelIdLabel;

  /// Indice du champ `modelId` opaque.
  final String modelIdHint;

  /// Libellé du sélecteur de source.
  final String sourceLabel;

  /// Libellé du bouton « générer ».
  final String generateLabel;

  /// Libellé affiché pendant la génération.
  final String generatingLabel;

  /// Libellé du bouton « confirmer les tags » (aperçu → confirmation).
  final String proceedToTagsLabel;

  /// Titre de l'aire d'aperçu.
  final String previewTitle;

  /// Libellés par type de carte (repli `type.name` si absent).
  final Map<ZFlashcardType, String> typeLabels;

  /// Titre de la feuille de confirmation de tags.
  final String tagConfirmTitle;

  /// Libellé du bouton de confirmation des tags.
  final String tagConfirmApply;

  /// Libellé du bouton d'annulation des tags.
  final String tagConfirmCancel;

  /// Libellé INJECTÉ du champ de saisie de tag (transmis au [ZTagEditor] de la
  /// feuille de confirmation — ferme la voie d'un défaut FR en dur, AC12/L10n).
  final String tagInputLabel;

  /// Indice INJECTÉ du champ de saisie de tag (transmis au [ZTagEditor]).
  final String tagInputHint;

  /// Libellé sémantique INJECTÉ du bouton d'ajout de tag (transmis au [ZTagEditor]).
  final String tagAddSemanticLabel;
}

/// Feuille de génération IA d'un lot de flashcards.
class ZFlashcardGenerationSheet extends StatefulWidget {
  /// Construit la feuille autour d'un [port] advisory/faillible (AD-35).
  const ZFlashcardGenerationSheet({
    required this.port,
    required this.messages,
    required this.labels,
    required this.sources,
    this.onGenerated,
    this.suggestedTags = const <ZSuggestedTag>[],
    this.existingTags = const <ZFlashcardTag>[],
    this.palette = const ZColorPalette.defaultStudy(),
    this.languageTag,
    this.initialModelId,
    super.key,
  });

  /// Port de génération (injecté par l'app hôte).
  final ZFlashcardGenerationPort port;

  /// Messages d'échec injectés (transmis au contrôleur).
  final ZFlashcardGenerationMessages messages;

  /// Libellés injectés de la feuille.
  final ZFlashcardGenerationLabels labels;

  /// Options de source (construites par l'app depuis `ZSourceRegistry`, AC1).
  final List<ZGenerationSourceOption> sources;

  /// Handoff du lot éphémère + tags confirmés (AC5). `null` ⇒ non remis.
  final ZFlashcardGeneratedCallback? onGenerated;

  /// Tags suggérés par l'app (pré-cochés à la confirmation, AC9).
  final List<ZSuggestedTag> suggestedTags;

  /// Tags existants (garde anti-doublon de l'éditeur, AC9).
  final List<ZFlashcardTag> existingTags;

  /// Palette injectée (couleur des tags).
  final ZColorPalette palette;

  /// Langue souhaitée (BCP-47), transmise telle quelle à la requête.
  final String? languageTag;

  /// `modelId` OPAQUE pré-rempli (AC2) — l'app peut proposer un défaut éditable.
  final String? initialModelId;

  @override
  State<ZFlashcardGenerationSheet> createState() =>
      _ZFlashcardGenerationSheetState();
}

class _ZFlashcardGenerationSheetState extends State<ZFlashcardGenerationSheet> {
  // Controllers STABLES (créés UNE fois — AD-2/AC13, jamais dans build()).
  late final TextEditingController _contentController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _modelIdController;

  // Tranches LOCALES pilotées granulairement (SM-1).
  late final ValueNotifier<double> _count;
  late final ValueNotifier<Set<ZFlashcardType>> _selectedTypes;
  late final ValueNotifier<int> _sourceIndex;

  late final ZFlashcardGenerationController _generation;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController();
    _instructionsController = TextEditingController();
    _modelIdController = TextEditingController(text: widget.initialModelId ?? '');
    _count = ValueNotifier<double>(zDefaultGenerationCount.toDouble());
    _selectedTypes = ValueNotifier<Set<ZFlashcardType>>(
      <ZFlashcardType>{...ZFlashcardType.values},
    );
    _sourceIndex = ValueNotifier<int>(0);
    _generation = ZFlashcardGenerationController(
      port: widget.port,
      messages: widget.messages,
      onGenerated: widget.onGenerated,
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _instructionsController.dispose();
    _modelIdController.dispose();
    _count.dispose();
    _selectedTypes.dispose();
    _sourceIndex.dispose();
    _generation.dispose();
    super.dispose();
  }

  /// Construit la requête d'union (AC1) — source unique de bornage/répartition.
  ZFlashcardGenerationRequest _buildRequest() {
    final selected = <ZFlashcardType>[
      for (final t in ZFlashcardType.values)
        if (_selectedTypes.value.contains(t)) t,
    ];
    final count = zClampGenerationCount(_count.value.round());
    final types = selected.isEmpty ? _generation.generableTypes : selected;
    final distribution = zEvenTypesDistribution(count, types);
    final modelId = _modelIdController.text.trim();
    final instructions = _instructionsController.text.trim();
    final sourceIndex = _sourceIndex.value;
    final provenance = sourceIndex >= 0 && sourceIndex < widget.sources.length
        ? widget.sources[sourceIndex].provenance
        : null;
    return ZFlashcardGenerationRequest(
      content: _contentController.text,
      count: count,
      languageTag: widget.languageTag,
      provenance: provenance,
      typesDistribution: distribution,
      instructions: instructions.isEmpty ? null : instructions,
      modelId: modelId.isEmpty ? null : modelId, // transporté VERBATIM (AC2).
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
        if (_generation.status == ZFlashcardGenerationStatus.confirmingTags) {
          // AC9 — confirmation de tags (réutilise l'éditeur existant).
          return ZFlashcardTagConfirmSheet(
            title: labels.tagConfirmTitle,
            confirmLabel: labels.tagConfirmApply,
            cancelLabel: labels.tagConfirmCancel,
            suggestedTags: widget.suggestedTags,
            existingTags: widget.existingTags,
            palette: widget.palette,
            inputLabel: labels.tagInputLabel,
            inputHint: labels.tagInputHint,
            addSemanticLabel: labels.tagAddSemanticLabel,
            onConfirmed: _generation.confirmTags,
            onCancel: _generation.backToPreview,
          );
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildSourceSelector(theme, labels),
              SizedBox(height: theme.gapM),
              // Champ de contenu — controller STABLE (AC13), hors des tranches
              // réactives : taper ne reconstruit pas l'aperçu ni ne perd le focus.
              TextField(
                key: const ValueKey<String>('z-generation-content'),
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
              _buildCountSlider(theme, labels),
              SizedBox(height: theme.gapM),
              _buildTypeChips(theme, labels),
              SizedBox(height: theme.gapM),
              TextField(
                key: const ValueKey<String>('z-generation-instructions'),
                controller: _instructionsController,
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: labels.instructionsLabel,
                  hintText: labels.instructionsHint,
                ),
              ),
              SizedBox(height: theme.gapM),
              TextField(
                key: const ValueKey<String>('z-generation-model-id'),
                controller: _modelIdController,
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: labels.modelIdLabel,
                  hintText: labels.modelIdHint,
                ),
              ),
              SizedBox(height: theme.gapL),
              _buildActionArea(theme, labels),
              _buildResultArea(theme, labels),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceSelector(ZcrudTheme theme, ZFlashcardGenerationLabels labels) {
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
                  label: Text(widget.sources[i].label, textAlign: TextAlign.start),
                  selected: selected == i,
                  onSelected: (_) => _sourceIndex.value = i,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountSlider(ZcrudTheme theme, ZFlashcardGenerationLabels labels) {
    const min = zGenerationCountBounds;
    return ValueListenableBuilder<double>(
      valueListenable: _count,
      builder: (context, value, _) {
        final current = value.round();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${labels.countLabel} : $current', textAlign: TextAlign.start),
            // D4 — l'ancien `Semantics(slider: true, label:, value:)` ENVELOPPANT
            // créait un SECOND nœud « slider » NON actionnable (portant le libellé
            // et une valeur `10` distincte), en DOUBLE du vrai `Slider` actionnable
            // (valeur `18%`, increase/decrease) : un lecteur d'écran rencontrait
            // DEUX sliders et le contrôle réel était muet (récidive su-8 D3). Le
            // `Slider` étant une frontière sémantique dure (il impose son propre
            // nœud actionnable et n'hérite pas d'un libellé de parent sans perdre
            // ses actions), le patron accessible correct est un CONTENEUR libellé
            // UNIQUE : un seul nœud slider actionnable, le libellé porté par le
            // conteneur (et doublé par le `Text` visible ci-dessus).
            Semantics(
              container: true,
              label: labels.countLabel,
              child: Slider(
                min: min.min.toDouble(),
                max: min.max.toDouble(),
                divisions: min.max - min.min,
                value: value.clamp(min.min.toDouble(), min.max.toDouble()),
                onChanged: (v) => _count.value = v,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeChips(ZcrudTheme theme, ZFlashcardGenerationLabels labels) {
    return ValueListenableBuilder<Set<ZFlashcardType>>(
      valueListenable: _selectedTypes,
      builder: (context, selected, _) => Wrap(
        spacing: theme.gapM,
        runSpacing: theme.gapS,
        children: <Widget>[
          for (final type in ZFlashcardType.values)
            FilterChip(
              label: Text(
                labels.typeLabels[type] ?? type.name,
                textAlign: TextAlign.start,
              ),
              selected: selected.contains(type),
              onSelected: (on) {
                final next = <ZFlashcardType>{...selected};
                if (on) {
                  next.add(type);
                } else {
                  next.remove(type);
                }
                _selectedTypes.value = next;
              },
            ),
        ],
      ),
    );
  }

  Widget _buildActionArea(ZcrudTheme theme, ZFlashcardGenerationLabels labels) {
    final generating =
        _generation.status == ZFlashcardGenerationStatus.generating;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: ElevatedButton(
        key: const ValueKey<String>('z-generation-submit'),
        // Anti-double-tap : le contrôleur ignore toute soumission pendant
        // `generating` (AC8) — le bouton reflète l'état.
        onPressed: generating ? null : _submit,
        child: Text(
          generating ? labels.generatingLabel : labels.generateLabel,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildResultArea(ZcrudTheme theme, ZFlashcardGenerationLabels labels) {
    switch (_generation.status) {
      case ZFlashcardGenerationStatus.failed:
        final message = _generation.errorMessage ?? '';
        return Padding(
          padding: EdgeInsetsDirectional.only(top: theme.gapM),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message,
              key: const ValueKey<String>('z-generation-error'),
              textAlign: TextAlign.start,
            ),
          ),
        );
      case ZFlashcardGenerationStatus.preview:
        return _buildPreview(theme, labels);
      case ZFlashcardGenerationStatus.idle:
      case ZFlashcardGenerationStatus.generating:
      case ZFlashcardGenerationStatus.confirmingTags:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPreview(ZcrudTheme theme, ZFlashcardGenerationLabels labels) {
    final cards = _generation.cards;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.gapM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(labels.previewTitle, textAlign: TextAlign.start),
          SizedBox(height: theme.gapS),
          // Aperçu via ZFlashcardPreview → ZFlashcardReviewCard (su-2), jamais un
          // rendu parallèle (AC10). ListView.builder (jamais children:[…]).
          ListView.builder(
            key: const ValueKey<String>('z-generation-preview-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsetsDirectional.only(bottom: theme.gapM),
              child: ZFlashcardPreview(card: cards[i]),
            ),
          ),
          SizedBox(height: theme.gapM),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kMinTapTarget),
            child: ElevatedButton(
              key: const ValueKey<String>('z-generation-proceed'),
              onPressed: _generation.proceedToTagConfirmation,
              child: Text(labels.proceedToTagsLabel, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

/// Injection Flutter-native d'un [ZFlashcardGenerationPort] OPTIONNEL (AD-2/AD-15).
///
/// `InheritedWidget` PUR (aucun état mutable). Le point d'entrée
/// [ZFlashcardGenerationLauncher] lit le port ici : **absent** ⇒ l'option de
/// génération est ABSENTE (jamais grisée, AC11).
class ZFlashcardGenerationScope extends InheritedWidget {
  /// Injecte [port] (éventuellement `null`) dans le sous-arbre [child].
  const ZFlashcardGenerationScope({
    required this.port,
    required super.child,
    super.key,
  });

  /// Port injecté (ou `null` = génération indisponible).
  final ZFlashcardGenerationPort? port;

  /// Port du plus proche ancêtre, ou `null` si aucun.
  static ZFlashcardGenerationPort? maybePortOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZFlashcardGenerationScope>()
      ?.port;

  @override
  bool updateShouldNotify(ZFlashcardGenerationScope oldWidget) =>
      !identical(port, oldWidget.port);
}

/// Point d'entrée CONDITIONNEL « Générer avec l'IA » (AC11).
///
/// Sans port injecté (paramètre [port] `null` ET aucun [ZFlashcardGenerationScope]
/// ancêtre), l'option est **ABSENTE de l'arbre** — jamais grisée/désactivée.
/// Avec un port, le bouton est présent et déclenche [onPressed] (l'app ouvre la
/// feuille avec le port résolu).
class ZFlashcardGenerationLauncher extends StatelessWidget {
  /// Construit le point d'entrée.
  const ZFlashcardGenerationLauncher({
    required this.label,
    required this.onPressed,
    this.port,
    this.icon,
    super.key,
  });

  /// Libellé INJECTÉ de l'action (i18n).
  final String label;

  /// Déclenché au tap (le port résolu NON `null` est passé à l'app).
  final void Function(ZFlashcardGenerationPort port) onPressed;

  /// Port explicite (prioritaire sur le scope). `null` ⇒ résolu via le scope.
  final ZFlashcardGenerationPort? port;

  /// Icône INJECTÉE optionnelle.
  final IconData? icon;

  /// Port effectif (paramètre prioritaire, sinon scope). Exposé pour falsifier
  /// la règle « absent ⇒ ABSENTE ».
  @visibleForTesting
  ZFlashcardGenerationPort? resolvedPort(BuildContext context) =>
      port ?? ZFlashcardGenerationScope.maybePortOf(context);

  @override
  Widget build(BuildContext context) {
    final resolved = resolvedPort(context);
    if (resolved == null) {
      // AC11 : option ABSENTE (jamais grisée) sans port.
      return const SizedBox.shrink();
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _kMinTapTarget,
        minHeight: _kMinTapTarget,
      ),
      child: ElevatedButton.icon(
        key: const ValueKey<String>('z-generation-launch'),
        onPressed: () => onPressed(resolved),
        // D3 — pas de `semanticLabel` sur l'icône : `ElevatedButton.icon` fusionne
        // son sous-arbre ; le `Text(label)` porte DÉJÀ le libellé. Un `semanticLabel`
        // ici le dupliquerait (« Générer avec IA, Générer avec IA », récidive su-8).
        icon: Icon(icon ?? Icons.auto_awesome),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
