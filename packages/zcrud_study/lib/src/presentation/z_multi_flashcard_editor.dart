/// `ZMultiFlashcardEditor` — édition d'un LOT de flashcards en régime BROUILLON
/// avant un enregistrement groupé unique (me-2, FR-SU20 —
/// AD-43/AD-44/AD-39/AD-45/AD-2/AD-15/AD-10/AD-13).
///
/// ## Ce que ce widget COMPOSE (il ne réimplémente RIEN)
///
/// - **Brouillon EN MÉMOIRE** : [ZMultiFlashcardDraftController] (régime
///   [ZEditingMode.draft] DÉCLARÉ) — liste de travail pur-Flutter, **aucun store**
///   (la garde de pureté récursive `z_widgets_purity_test.dart` couvre ce fichier
///   AUTOMATIQUEMENT ; aucune ligne ne matche `Repository`/`LocalStore`/
///   `RemoteStore`/`.save(`/`.persist(`).
/// - **Sortie gardée** : `ZDiscardChangesGuard` **EXISTANT** (zcrud_ui_kit) —
///   jamais une garde réécrite. me-2 alimente son `isDirty`
///   ([ZMultiFlashcardDraftController.isDirty]).
/// - **Sélection + actions de lot** : `ZListSelectionController` + `ZBatchActionBar`
///   + `applyCommonField` (validateurs DÉRIVÉS du `ZFieldSpec`, AD-44) du CŒUR
///   (me-1) — le seam d'écriture est INJECTÉ et écrit la liste EN MÉMOIRE
///   (`writeRootInMemory`), jamais un store. `clearSucceededFromSelection` reste
///   au défaut **`false`** (édition in-place ⇒ sélection conservée) — **consommé,
///   jamais redéclaré**.
/// - **Aperçu** : `ZFlashcardReviewCard` (su-2) — **jamais** un rendu de contenu
///   de carte parallèle (grep -qF négatif dans les tests).
/// - **Génération IA** : `ZFlashcardGenerationSheet`/`ZFlashcardGenerationLauncher`
///   (su-9) — `onGenerated` ajoute les cartes ÉPHÉMÈRES (`id == null`, AD-37) à la
///   liste de travail, **jamais persistées**.
/// - **Split-view** : `ZResponsiveLayout` (zcrud_responsive) — grand écran :
///   liste + formulaire simultanés ; mobile : navigation liste ↔ formulaire. Aucun
///   breakpoint réécrit.
///
/// ## AD-43 (LE point dur) — RIEN persisté avant le commit unique
///
/// La **seule** frontière de persistance est le callback [onCommit] injecté :
/// éditer / ajouter / supprimer / appliquer un champ commun / recevoir un lot
/// généré ne touche QUE la liste de travail. Le commit remet l'**intégralité** de
/// la liste en **une seule** invocation ; un échec de commit préserve le brouillon
/// *dirty* (aucun vidage optimiste, AC9).
library;

import 'package:flutter/material.dart';
// `Unit` est RÉ-EXPORTÉ par `zcrud_core` (via `domain.dart` → dartz) : aucune
// dépendance directe à `dartz` (arête pubspec unique = `zcrud_ui_kit`).
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZBatchAction,
        ZBatchActionKind,
        ZBatchActionBar,
        ZBatchReport,
        ZFieldSpec,
        ZListSelectionController,
        ZListSelectionMode,
        ZResult,
        ZcrudTheme,
        Unit;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZFlashcard, ZFlashcardReviewCard, ZFlashcardType;
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZResponsiveLayout;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZFlashcardTag, ZSuggestedTag;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZDiscardChangesGuard;

import '../domain/z_flashcard_generation_port.dart';
import 'z_flashcard_generation_controller.dart';
import 'z_flashcard_generation_sheet.dart';
import 'z_multi_flashcard_editor_controller.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Signature du **commit unique** (AC4) : remet l'intégralité de la liste de
/// travail à l'appelant. Retourne un `Either<ZFailure, Unit>` — un `Left` laisse
/// le brouillon *dirty* intact (AC9), un `Right` valide le brouillon.
typedef ZFlashcardBatchCommit = Future<ZResult<Unit>> Function(
  List<ZFlashcard> cards,
);

/// Un **champ commun** applicable à la sélection (AC7) — DÉCLARÉ en données.
///
/// [spec] porte les validateurs (dérivés par `applyCommonField` via
/// `ZValidatorCompiler.compile`, AD-44 : mêmes validateurs que le formulaire
/// unitaire) ; [label] est le libellé LOCALISÉ INJECTÉ (i18n) ; [apply] mappe la
/// valeur candidate sur la carte (édition IN MEMORY par `copyWith`, jamais un
/// store).
@immutable
class ZMultiFlashcardCommonField {
  /// Construit un champ commun applicable à la sélection.
  const ZMultiFlashcardCommonField({
    required this.spec,
    required this.label,
    required this.apply,
  });

  /// Spec du champ (source UNIQUE des validateurs, AD-44).
  final ZFieldSpec spec;

  /// Libellé LOCALISÉ INJECTÉ du champ (i18n).
  final String label;

  /// Mappe la valeur candidate sur la carte (in-memory `copyWith`).
  final ZFlashcard Function(ZFlashcard card, String? value) apply;
}

/// Configuration OPTIONNELLE du flux de génération IA (su-9) intégré au
/// multi-éditeur (AC5). Absente ⇒ l'option « Générer » est **ABSENTE de l'arbre**
/// (jamais grisée — patron `ZFlashcardGenerationLauncher`).
@immutable
class ZMultiFlashcardGeneration {
  /// Construit la configuration de génération.
  const ZMultiFlashcardGeneration({
    required this.port,
    required this.messages,
    required this.labels,
    required this.sources,
    required this.launcherLabel,
    this.suggestedTags = const <ZSuggestedTag>[],
    this.existingTags = const <ZFlashcardTag>[],
    this.languageTag,
    this.initialModelId,
  });

  /// Port advisory/faillible (injecté par l'app, AD-35).
  final ZFlashcardGenerationPort port;

  /// Messages d'échec injectés (transmis à la feuille).
  final ZFlashcardGenerationMessages messages;

  /// Libellés injectés de la feuille de génération.
  final ZFlashcardGenerationLabels labels;

  /// Options de source (construites depuis `ZSourceRegistry`).
  final List<ZGenerationSourceOption> sources;

  /// Libellé LOCALISÉ du point d'entrée « Générer avec l'IA ».
  final String launcherLabel;

  /// Tags suggérés (pré-cochés à la confirmation).
  final List<ZSuggestedTag> suggestedTags;

  /// Tags existants (garde anti-doublon de l'éditeur de tags).
  final List<ZFlashcardTag> existingTags;

  /// Langue souhaitée (BCP-47), transmise verbatim.
  final String? languageTag;

  /// `modelId` OPAQUE pré-rempli.
  final String? initialModelId;
}

/// Libellés LOCALISÉS INJECTÉS du multi-éditeur (i18n — AD-13/FR-26 : **aucun**
/// libellé en dur, invisible à la garde de scan sinon).
@immutable
class ZMultiFlashcardEditorLabels {
  /// Construit les libellés injectés.
  const ZMultiFlashcardEditorLabels({
    required this.addCardLabel,
    required this.deleteSelectedLabel,
    required this.commitLabel,
    required this.applyCommonLabel,
    required this.selectAllLabel,
    required this.emptyState,
    required this.detailPlaceholder,
    required this.backToListLabel,
    required this.questionLabel,
    required this.answerLabel,
    required this.explanationLabel,
    required this.hintLabel,
    required this.typeLabel,
    required this.commonFieldPickerLabel,
    required this.commonValueLabel,
    required this.previewTitle,
    required this.commitSucceeded,
    required this.commitFailed,
    required this.selectCardSemanticLabel,
    required this.countLabelBuilder,
    required this.applyReportBuilder,
    this.typeLabels = const <ZFlashcardType, String>{},
  });

  /// Bouton « ajouter une carte vierge ».
  final String addCardLabel;

  /// Bouton « supprimer la sélection ».
  final String deleteSelectedLabel;

  /// Bouton « enregistrer le lot » (commit unique).
  final String commitLabel;

  /// Bouton « appliquer à la sélection » (champ commun).
  final String applyCommonLabel;

  /// Libellé a11y du bouton « tout sélectionner ».
  final String selectAllLabel;

  /// Message d'état vide (aucune carte).
  final String emptyState;

  /// Message du volet détail quand aucune carte n'est sélectionnée.
  final String detailPlaceholder;

  /// Libellé a11y du retour à la liste (navigation mobile).
  final String backToListLabel;

  /// Libellé du champ « question ».
  final String questionLabel;

  /// Libellé du champ « réponse ».
  final String answerLabel;

  /// Libellé du champ « explication ».
  final String explanationLabel;

  /// Libellé du champ « indice ».
  final String hintLabel;

  /// Libellé du sélecteur de type.
  final String typeLabel;

  /// Libellé du sélecteur de champ commun.
  final String commonFieldPickerLabel;

  /// Libellé du champ de valeur commune.
  final String commonValueLabel;

  /// Titre de l'aire d'aperçu.
  final String previewTitle;

  /// Message de succès du commit.
  final String commitSucceeded;

  /// Message d'échec du commit (préfixe ; la cause `ZFailure` peut le compléter).
  final String commitFailed;

  /// Libellé a11y de la case de sélection d'une carte (indexée à partir de 1).
  final String Function(int oneBasedIndex) selectCardSemanticLabel;

  /// Libellé LOCALISÉ du badge compteur de sélection.
  final String Function(int selectedCount) countLabelBuilder;

  /// Message LOCALISÉ résumant un `ZBatchReport` d'application de champ commun.
  final String Function(ZBatchReport report) applyReportBuilder;

  /// Libellés par type de carte (repli `type.name` si absent).
  final Map<ZFlashcardType, String> typeLabels;
}

/// Éditeur d'un LOT de flashcards en régime brouillon (me-2).
class ZMultiFlashcardEditor extends StatefulWidget {
  /// Construit le multi-éditeur.
  ///
  /// - [initialCards] : lot initial (souvent vide, ou un lot rentré pour édition) ;
  /// - [onCommit] : **seul** franchissement de la frontière de persistance (AC4) ;
  /// - [labels] : libellés LOCALISÉS injectés (i18n) ;
  /// - [commonFields] : champs communs applicables à la sélection (AC7) ;
  /// - [generation] : configuration OPTIONNELLE du flux de génération (AC5) ;
  /// - [newCardBuilder] : fabrique de carte vierge (défaut : question vide,
  ///   `id == null` ⇒ éphémère, AD-37) ;
  /// - [selection] : contrôleur de sélection INJECTÉ (sinon créé et possédé —
  ///   propriétaire UNIQUE AD-44) ;
  /// - [rowContentBuilder] : slot de rendu du RÉSUMÉ de ligne (défaut : la
  ///   question thématisée) — hissé pour la garde SM-1 (compteur de builds).
  const ZMultiFlashcardEditor({
    required this.onCommit,
    required this.labels,
    this.initialCards = const <ZFlashcard>[],
    this.commonFields = const <ZMultiFlashcardCommonField>[],
    this.generation,
    this.newCardBuilder,
    this.selection,
    this.rowContentBuilder,
    super.key,
  });

  /// Lot initial (snapshot de référence du *dirty*).
  final List<ZFlashcard> initialCards;

  /// Commit unique injecté (AC4).
  final ZFlashcardBatchCommit onCommit;

  /// Libellés LOCALISÉS injectés.
  final ZMultiFlashcardEditorLabels labels;

  /// Champs communs applicables à la sélection (AC7).
  final List<ZMultiFlashcardCommonField> commonFields;

  /// Configuration OPTIONNELLE de génération IA (AC5).
  final ZMultiFlashcardGeneration? generation;

  /// Fabrique de carte vierge éphémère (défaut : question vide).
  final ZFlashcard Function()? newCardBuilder;

  /// Contrôleur de sélection INJECTÉ (sinon créé/possédé). Propriétaire UNIQUE.
  final ZListSelectionController? selection;

  /// Slot de rendu du résumé de ligne (défaut : question thématisée).
  final Widget Function(BuildContext context, ZFlashcard card)? rowContentBuilder;

  /// Clé de test du volet liste.
  static const ValueKey<String> listPaneKey =
      ValueKey<String>('z-multi-editor-list');

  /// Clé de test du volet détail.
  static const ValueKey<String> detailPaneKey =
      ValueKey<String>('z-multi-editor-detail');

  /// Clé de test du bouton de commit.
  static const ValueKey<String> commitButtonKey =
      ValueKey<String>('z-multi-editor-commit');

  /// Clé de test du bouton « ajouter une carte ».
  static const ValueKey<String> addButtonKey =
      ValueKey<String>('z-multi-editor-add');

  @override
  State<ZMultiFlashcardEditor> createState() => _ZMultiFlashcardEditorState();
}

class _ZMultiFlashcardEditorState extends State<ZMultiFlashcardEditor> {
  late final ZMultiFlashcardDraftController _draft;
  late final ZListSelectionController _selection;
  bool _ownsSelection = false;

  /// Clé de travail de la carte affichée dans le volet détail (`null` = aucune).
  late final ValueNotifier<String?> _focusedKey;

  /// Jeton de rafraîchissement de l'aperçu (bump à la fin d'édition d'un champ) —
  /// l'aperçu ne se reconstruit PAS à chaque frappe (SM-1).
  late final ValueNotifier<int> _previewTick;

  /// Message transitoire (commit / application de champ commun) — région live a11y.
  late final ValueNotifier<String?> _statusMessage;

  /// Index du champ commun sélectionné dans le panneau « appliquer ».
  late final ValueNotifier<int> _commonFieldIndex;

  /// Controller STABLE de la valeur commune (créé une fois — AD-2).
  late final TextEditingController _commonValueController;

  /// Garde de commit EN VOL (BUG-3/AC4) : un second tap pendant qu'un commit est
  /// en cours est ignoré ⇒ **exactement une salve** par intention utilisateur.
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _draft = ZMultiFlashcardDraftController(initialCards: widget.initialCards);
    final injected = widget.selection;
    if (injected != null) {
      _selection = injected;
    } else {
      _selection =
          ZListSelectionController(mode: ZListSelectionMode.multiple);
      _ownsSelection = true;
    }
    _focusedKey = ValueNotifier<String?>(null);
    _previewTick = ValueNotifier<int>(0);
    _statusMessage = ValueNotifier<String?>(null);
    _commonFieldIndex = ValueNotifier<int>(0);
    _commonValueController = TextEditingController();
    _draft.orderKeys.addListener(_reconcileFocus);
  }

  /// Si la carte focalisée a disparu (suppression), retombe sur « aucune » (AD-10).
  void _reconcileFocus() {
    final key = _focusedKey.value;
    if (key != null && _draft.cardOf(key) == null) {
      _focusedKey.value = null;
    }
  }

  @override
  void dispose() {
    _draft.orderKeys.removeListener(_reconcileFocus);
    _draft.dispose();
    if (_ownsSelection) _selection.dispose();
    _focusedKey.dispose();
    _previewTick.dispose();
    _statusMessage.dispose();
    _commonFieldIndex.dispose();
    _commonValueController.dispose();
    super.dispose();
  }

  ZFlashcard _blankCard() =>
      widget.newCardBuilder?.call() ?? const ZFlashcard(question: '');

  void _addCard() {
    final key = _draft.addBlank(_blankCard());
    _focusedKey.value = key; // navigue vers le formulaire (mobile) / focalise.
  }

  void _deleteSelected() {
    final selected = _selection.selectedIds.value;
    if (selected.isEmpty) return;
    _draft.removeKeys(selected);
    _selection.clearSelection();
  }

  Future<void> _commit() async {
    // BUG-3 : garde de ré-entrance — un double-tap ne déclenche QU'UNE salve.
    if (_isCommitting) return;
    _isCommitting = true;
    try {
      final result = await _draft.commit(widget.onCommit);
      if (!mounted) return;
      // LOW #10 : message d'échec LOCALISÉ seul — on n'accole PAS la
      // `ZFailure.message` brute (non localisée, pouvant porter une trace
      // technique, cf. BUG-2). Le contrôleur préserve la liste ⇒ aucune perte.
      _statusMessage.value = result.fold(
        (failure) => widget.labels.commitFailed,
        (_) => widget.labels.commitSucceeded,
      );
    } finally {
      _isCommitting = false;
    }
  }

  Future<void> _applyCommonField() async {
    final fields = widget.commonFields;
    if (fields.isEmpty) return;
    final index = _commonFieldIndex.value.clamp(0, fields.length - 1);
    final field = fields[index];
    final value = _commonValueController.text;
    // AD-44 : validateurs DÉRIVÉS du `ZFieldSpec` (source unique). Le seam
    // `writeRoot` écrit la liste EN MÉMOIRE (jamais un store). Le défaut
    // `clearSucceededFromSelection: false` est CONSOMMÉ (non redéclaré) : édition
    // in-place ⇒ la sélection est conservée pour enchaîner un 2ᵉ champ.
    final report = await _selection.applyCommonField(
      field: field.spec,
      value: value,
      writeRoot: (key, _, candidate) =>
          _draft.writeRootInMemory(key, (card) => field.apply(card, candidate)),
    );
    if (!mounted) return;
    _statusMessage.value = widget.labels.applyReportBuilder(report);
  }

  void _openGeneration() {
    final generation = widget.generation;
    if (generation == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: ZFlashcardGenerationSheet(
          port: generation.port,
          messages: generation.messages,
          labels: generation.labels,
          sources: generation.sources,
          suggestedTags: generation.suggestedTags,
          existingTags: generation.existingTags,
          languageTag: generation.languageTag,
          initialModelId: generation.initialModelId,
          // AC5 : le lot éphémère est AJOUTÉ à la liste de travail — jamais
          // persisté. Un lot vide (échec / Right([])) est un no-op (AC9).
          onGenerated: (cards, _) {
            _draft.addGenerated(cards);
            Navigator.of(sheetContext).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AC3 : sortie gardée par `ZDiscardChangesGuard` EXISTANT (jamais réécrit).
    return ZDiscardChangesGuard(
      isDirty: _draft.isDirty,
      onDiscard: _draft.discardToSnapshot,
      // AC1 : split-view responsive via `ZResponsiveLayout` (aucun breakpoint
      // réécrit). Compact (< 600) : navigation liste ↔ formulaire ; medium/
      // expanded (≥ 600) : les deux volets simultanés.
      child: ZResponsiveLayout(
        compact: _buildMobile,
        medium: _buildSplit,
        expanded: _buildSplit,
      ),
    );
  }

  Widget _buildSplit(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: _buildListPane(context)),
        SizedBox(width: theme.gapM),
        Expanded(child: _buildDetailPane(context, showBack: false)),
      ],
    );
  }

  Widget _buildMobile(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _focusedKey,
      builder: (context, focused, _) => focused == null
          ? _buildListPane(context)
          : _buildDetailPane(context, showBack: true),
    );
  }

  // ---------------------------------------------------------------------------
  // Volet LISTE (sélection + actions de lot + champ commun).
  // ---------------------------------------------------------------------------

  Widget _buildListPane(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final labels = widget.labels;
    return Column(
      key: ZMultiFlashcardEditor.listPaneKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildActionRow(theme, labels),
        SizedBox(height: theme.gapS),
        ZBatchActionBar(
          controller: _selection,
          countLabelBuilder: labels.countLabelBuilder,
          selectAllLabel: labels.selectAllLabel,
          onSelectAll: () => _selection.selectAll(_draft.keys),
          actions: <ZBatchAction>[
            ZBatchAction(
              kind: ZBatchActionKind.delete,
              label: labels.deleteSelectedLabel,
              icon: Icons.delete,
              onSelected: _deleteSelected,
            ),
          ],
        ),
        if (widget.commonFields.isNotEmpty) _buildCommonFieldPanel(theme, labels),
        _buildStatusMessage(theme),
        SizedBox(height: theme.gapS),
        Expanded(child: _buildList(theme, labels)),
      ],
    );
  }

  Widget _buildActionRow(ZcrudTheme theme, ZMultiFlashcardEditorLabels labels) {
    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapS,
      children: <Widget>[
        _minTarget(
          ElevatedButton.icon(
            key: ZMultiFlashcardEditor.addButtonKey,
            onPressed: _addCard,
            icon: const Icon(Icons.add),
            label: Text(labels.addCardLabel, textAlign: TextAlign.center),
          ),
        ),
        _minTarget(
          ElevatedButton.icon(
            key: ZMultiFlashcardEditor.commitButtonKey,
            onPressed: _commit,
            icon: const Icon(Icons.save_alt),
            label: Text(labels.commitLabel, textAlign: TextAlign.center),
          ),
        ),
        if (widget.generation != null)
          // FIX-7/AD-13 : cible ≥ 48 dp comme les autres actions de la barre.
          _minTarget(
            ZFlashcardGenerationLauncher(
              label: widget.generation!.launcherLabel,
              port: widget.generation!.port,
              onPressed: (_) => _openGeneration(),
            ),
          ),
      ],
    );
  }

  Widget _buildCommonFieldPanel(
      ZcrudTheme theme, ZMultiFlashcardEditorLabels labels) {
    final fields = widget.commonFields;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.gapS),
      child: Row(
        children: <Widget>[
          ValueListenableBuilder<int>(
            valueListenable: _commonFieldIndex,
            builder: (context, index, _) => DropdownButton<int>(
              key: const ValueKey<String>('z-multi-editor-common-picker'),
              value: index.clamp(0, fields.length - 1),
              onChanged: (v) {
                if (v != null) _commonFieldIndex.value = v;
              },
              items: <DropdownMenuItem<int>>[
                for (var i = 0; i < fields.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Text(fields[i].label, textAlign: TextAlign.start),
                  ),
              ],
            ),
          ),
          SizedBox(width: theme.gapM),
          Expanded(
            child: TextField(
              key: const ValueKey<String>('z-multi-editor-common-value'),
              controller: _commonValueController,
              textAlign: TextAlign.start,
              decoration: InputDecoration(labelText: labels.commonValueLabel),
            ),
          ),
          SizedBox(width: theme.gapM),
          _minTarget(
            ElevatedButton(
              key: const ValueKey<String>('z-multi-editor-apply-common'),
              onPressed: _applyCommonField,
              child: Text(labels.applyCommonLabel, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(ZcrudTheme theme) {
    return ValueListenableBuilder<String?>(
      valueListenable: _statusMessage,
      builder: (context, message, _) {
        if (message == null || message.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsetsDirectional.only(top: theme.gapS),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message,
              key: const ValueKey<String>('z-multi-editor-status'),
              textAlign: TextAlign.start,
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(ZcrudTheme theme, ZMultiFlashcardEditorLabels labels) {
    // 🔴 SM-1 : la liste n'écoute QUE la tranche STRUCTURELLE `orderKeys` — éditer
    // un champ (`updateCard`) ne l'émet PAS ⇒ la liste ne se reconstruit pas à la
    // frappe. Ajout/suppression/champ commun/lot généré l'émettent (recalcul).
    return ValueListenableBuilder<List<String>>(
      valueListenable: _draft.orderKeys,
      builder: (context, keys, _) {
        if (keys.isEmpty) {
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: Text(
              labels.emptyState,
              key: const ValueKey<String>('z-multi-editor-empty'),
              textAlign: TextAlign.start,
            ),
          );
        }
        return ListView.builder(
          itemCount: keys.length,
          itemBuilder: (context, i) => _buildRow(theme, labels, keys[i], i),
        );
      },
    );
  }

  Widget _buildRow(
    ZcrudTheme theme,
    ZMultiFlashcardEditorLabels labels,
    String key,
    int index,
  ) {
    final card = _draft.cardOf(key);
    if (card == null) return const SizedBox.shrink();
    final content = widget.rowContentBuilder?.call(context, card) ??
        Text(card.question, textAlign: TextAlign.start);
    // 🔴 FIX-8/AD-13 : la ligne porte DEUX actionnables INDÉPENDANTS — la bascule
    // de sélection (Checkbox) ET l'ouverture du volet détail (InkWell). On NE les
    // FUSIONNE PAS (pas de `MergeSemantics`) : la fusion écrasait l'une des deux
    // actions de tap au lecteur d'écran (une seule survivait). Chaque nœud reste
    // annoncé et actionnable séparément. Le libellé de la case reste explicite.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: Row(
        children: <Widget>[
          ValueListenableBuilder<Set<String>>(
            valueListenable: _selection.selectedIds,
            builder: (context, selected, _) => Semantics(
              label: labels.selectCardSemanticLabel(index + 1),
              child: Checkbox(
                value: selected.contains(key),
                onChanged: (_) => _selection.toggle(key),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _focusedKey.value = key,
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(
                  vertical: theme.gapS,
                  horizontal: theme.gapS,
                ),
                child: content,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Volet DÉTAIL (formulaire de carte + aperçu su-2).
  // ---------------------------------------------------------------------------

  Widget _buildDetailPane(BuildContext context, {required bool showBack}) {
    final theme = ZcrudTheme.of(context);
    final labels = widget.labels;
    return ValueListenableBuilder<String?>(
      valueListenable: _focusedKey,
      builder: (context, key, _) {
        final card = key == null ? null : _draft.cardOf(key);
        if (key == null || card == null) {
          return Align(
            key: ZMultiFlashcardEditor.detailPaneKey,
            alignment: AlignmentDirectional.topStart,
            child: Text(labels.detailPlaceholder, textAlign: TextAlign.start),
          );
        }
        return SingleChildScrollView(
          key: ZMultiFlashcardEditor.detailPaneKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showBack)
                _minTarget(
                  TextButton.icon(
                    onPressed: () => _focusedKey.value = null,
                    icon: const Icon(Icons.arrow_back),
                    label: Text(labels.backToListLabel,
                        textAlign: TextAlign.center),
                  ),
                ),
              _ZCardForm(
                // Clé de travail ⇒ changer de carte RECRÉE l'état (controllers
                // re-seedés) ; taper DANS une carte garde les controllers stables.
                key: ValueKey<String>('z-card-form-$key'),
                initialCard: card,
                // 🔴 BUG-1 : base VIVANTE relue à chaque `_rebuild` (jamais le
                // snapshot figé `initialCard`). Un champ commun appliqué HORS
                // formulaire (folderId/tags/type) mute `_draft.cardOf(key)` sans
                // reconstruire ce volet ; sans cette relecture, la frappe suivante
                // repartirait de la base périmée et écraserait la valeur appliquée.
                baseCardOf: () => _draft.cardOf(key) ?? card,
                labels: labels,
                onChanged: (updated) => _draft.updateCard(key, updated),
                onEditingComplete: () => _previewTick.value++,
              ),
              SizedBox(height: theme.gapM),
              _buildPreview(theme, labels, key),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreview(
    ZcrudTheme theme,
    ZMultiFlashcardEditorLabels labels,
    String key,
  ) {
    // AC6 : l'aperçu réutilise `ZFlashcardReviewCard` (su-2) — JAMAIS un rendu
    // parallèle du contenu de carte. Rafraîchi au jeton (fin d'édition), pas à
    // chaque frappe (SM-1).
    return ValueListenableBuilder<int>(
      valueListenable: _previewTick,
      builder: (context, _, __) {
        final card = _draft.cardOf(key);
        if (card == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(labels.previewTitle, textAlign: TextAlign.start),
            SizedBox(height: theme.gapS),
            ZFlashcardReviewCard(
              key: const ValueKey<String>('z-multi-editor-preview'),
              card: card,
            ),
          ],
        );
      },
    );
  }

  Widget _minTarget(Widget child) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _kMinTapTarget,
          minHeight: _kMinTapTarget,
        ),
        child: child,
      );
}

/// Formulaire d'ÉDITION d'une carte (volet détail) — controllers STABLES (AD-2).
///
/// 🔴 SM-1 : chaque `TextField` porte un `TextEditingController` créé UNE fois en
/// `initState` (jamais recréé au rebuild) ⇒ taper ne perd jamais le focus. Le type
/// est une tranche `ValueListenable` isolée (enum, pas un booléen). Aucune frappe
/// ne reconstruit la liste (l'édition passe par `updateCard`, hors tranche
/// structurelle).
class _ZCardForm extends StatefulWidget {
  const _ZCardForm({
    required this.initialCard,
    required this.baseCardOf,
    required this.labels,
    required this.onChanged,
    required this.onEditingComplete,
    super.key,
  });

  /// Carte de SEED des controllers (une seule fois, en `initState` — AD-2).
  final ZFlashcard initialCard;

  /// Lit la carte VIVANTE (base à jour) au moment de reconstruire l'édit. Sert de
  /// base au `copyWith` de `_rebuild` : préserve tout champ muté hors formulaire
  /// (champ commun appliqué à la sélection — BUG-1). Ne re-seed JAMAIS les
  /// controllers (stabilité AD-2 : le focus et la sélection ne sautent pas).
  final ZFlashcard Function() baseCardOf;

  final ZMultiFlashcardEditorLabels labels;
  final ValueChanged<ZFlashcard> onChanged;
  final VoidCallback onEditingComplete;

  @override
  State<_ZCardForm> createState() => _ZCardFormState();
}

class _ZCardFormState extends State<_ZCardForm> {
  late final TextEditingController _question;
  late final TextEditingController _answer;
  late final TextEditingController _explanation;
  late final TextEditingController _hint;
  late final ValueNotifier<ZFlashcardType> _type;

  @override
  void initState() {
    super.initState();
    final card = widget.initialCard;
    _question = TextEditingController(text: card.question);
    _answer = TextEditingController(text: card.answer ?? '');
    _explanation = TextEditingController(text: card.explanation ?? '');
    _hint = TextEditingController(text: card.hint ?? '');
    _type = ValueNotifier<ZFlashcardType>(card.type);
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _explanation.dispose();
    _hint.dispose();
    _type.dispose();
    super.dispose();
  }

  /// Reconstruit la carte depuis les controllers (édition IN MEMORY, `id`
  /// PRÉSERVÉ — une carte éphémère reste éphémère, une persistée garde son `id`).
  ///
  /// 🔴 BUG-1 : la base est la carte VIVANTE ([ZMultiFlashcardEditor] la relit via
  /// `baseCardOf`), pas le snapshot figé — sinon un champ commun appliqué hors
  /// formulaire serait écrasé à la frappe suivante.
  ZFlashcard _rebuild() => widget.baseCardOf().copyWith(
        question: _question.text,
        answer: _answer.text.isEmpty ? null : _answer.text,
        explanation: _explanation.text.isEmpty ? null : _explanation.text,
        hint: _hint.text.isEmpty ? null : _hint.text,
        type: _type.value,
      );

  void _notify() => widget.onChanged(_rebuild());

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final labels = widget.labels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _field('z-card-question', _question, labels.questionLabel),
        SizedBox(height: theme.gapS),
        _field('z-card-answer', _answer, labels.answerLabel),
        SizedBox(height: theme.gapS),
        _field('z-card-explanation', _explanation, labels.explanationLabel),
        SizedBox(height: theme.gapS),
        _field('z-card-hint', _hint, labels.hintLabel),
        SizedBox(height: theme.gapS),
        ValueListenableBuilder<ZFlashcardType>(
          valueListenable: _type,
          builder: (context, type, _) => Row(
            children: <Widget>[
              Text(labels.typeLabel, textAlign: TextAlign.start),
              SizedBox(width: theme.gapM),
              DropdownButton<ZFlashcardType>(
                key: const ValueKey<String>('z-card-type'),
                value: type,
                onChanged: (v) {
                  if (v == null) return;
                  _type.value = v;
                  _notify();
                  widget.onEditingComplete();
                },
                items: <DropdownMenuItem<ZFlashcardType>>[
                  for (final t in ZFlashcardType.values)
                    DropdownMenuItem<ZFlashcardType>(
                      value: t,
                      child: Text(labels.typeLabels[t] ?? t.name,
                          textAlign: TextAlign.start),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String keyId, TextEditingController controller, String label) {
    return TextField(
      key: ValueKey<String>(keyId),
      controller: controller,
      textAlign: TextAlign.start,
      onChanged: (_) => _notify(),
      onEditingComplete: () {
        _notify();
        widget.onEditingComplete();
      },
      decoration: InputDecoration(labelText: label),
    );
  }
}
