/// `ZChoicesFieldWidget` — éditeur **QCM** d'une `List<ZChoice>`, servi via
/// `ZWidgetRegistry` (Story E9-5, AC1/AC2/AC3/AD-2/AD-13/AD-10/FR-26).
///
/// Édite les choix d'un QCM : **ajouter / supprimer / réordonner** un choix,
/// **éditer** son libellé (`content`), **basculer** son caractère correct
/// (`isCorrect`). Émet la `List<ZChoice>` **neutre** via `ctx.onChanged`.
///
/// **AD-2 (SM-1 — OBJECTIF PRODUIT N°1)** : chaque ligne possède SON
/// `TextEditingController`/`FocusNode` **stables** (créés 1× à la construction de
/// la ligne, disposés) — **jamais** recréés ni `.text=` réinjectés pendant la
/// frappe (sync guardée **hors focus** dans `didUpdateWidget`). Le réordonnancement
/// **déplace** les lignes (identité contrôleur/focus préservée). Écriture
/// **exclusivement** via `ctx.onChanged`. **Un seul** point d'écoute par tranche
/// (AI-E10-3) : le widget lit `ctx.value`, n'ouvre aucun ré-abonnement interne au
/// notifier partagé.
///
/// **AC2 (validation révélée, sans `Form` global)** : ≥ 2 choix + ≥ 1 correct ;
/// le message est **révélé** quand le canal `reveal` du `ZFormController`
/// (exposé par [ZFlashcardEditingScope]) s'incrémente à la soumission agrégée —
/// jamais un `Form`/`FormBuilder` global (AD-2). Scope absent → aucune
/// révélation (dégradation propre).
///
/// **AD-13/FR-26** : chaque cible (ajouter/supprimer/monter/descendre/toggle
/// correct/champ éditable) est opérable (action sémantique `tap`) et **≥ 48 dp** ;
/// directionnel ; thème injecté (aucune couleur en dur) ; `ListView.builder`.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_choice.dart';
import '../domain/z_flashcard_type.dart';
import 'z_flashcard_editing_scope.dart';
import 'z_flashcard_edition_validator.dart';
import 'z_flashcard_editor_values.dart';

/// Éditeur QCM d'une liste de [ZChoice] (widget d'édition additif).
class ZChoicesFieldWidget extends StatefulWidget {
  /// Construit l'éditeur QCM pour [ctx]. [messages] surcharge les libellés
  /// d'erreur (défaut FR — AD-4).
  const ZChoicesFieldWidget({
    required this.ctx,
    this.messages = ZFlashcardEditionValidator.defaultMessages,
    this.addChoiceLabel = 'Ajouter un choix',
    this.typeFieldName = 'type',
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = `List<ZChoice>?` courant ; `ctx.onChanged`).
  final ZFieldWidgetContext ctx;

  /// Nom du champ **type** dans le formulaire (défaut `'type'`) : la surface
  /// d'erreur QCM n'est révélée que si le type courant vaut `multipleChoice`
  /// (aligné sur `ZFlashcardEditionValidator.validate`, MEDIUM-1).
  final String typeFieldName;

  /// Messages d'erreur éditeur (paramétrables — AD-4).
  final ZFlashcardEditionMessages messages;

  /// Libellé du bouton d'ajout (paramétrable — AD-4).
  final String addChoiceLabel;

  /// Hook de test : appelé UNE FOIS en `initState` (preuve SM-1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test : appelé à chaque (re)build (compteur ciblé SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  @override
  State<ZChoicesFieldWidget> createState() => _ZChoicesFieldWidgetState();
}

/// Ligne d'édition d'un choix : buffer de frappe **stable** + état `isCorrect`.
class _ChoiceRow {
  _ChoiceRow({required String content, required this.isCorrect})
      : controller = TextEditingController(text: content),
        focusNode = FocusNode();

  final TextEditingController controller;
  final FocusNode focusNode;
  bool isCorrect;

  ZChoice toChoice() =>
      ZChoice(content: controller.text, isCorrect: isCorrect);

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _ZChoicesFieldWidgetState extends State<ZChoicesFieldWidget> {
  final List<_ChoiceRow> _rows = <_ChoiceRow>[];

  @override
  void initState() {
    super.initState();
    _rebuildRows(coerceChoices(widget.ctx.value));
    widget.onInit?.call();
  }

  @override
  void didUpdateWidget(covariant ZChoicesFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SYNC GUARDÉE (AD-2) : reflet d'une valeur EXTERNE (reseed) **hors focus**
    // uniquement — jamais pendant une frappe (priorité absolue à la saisie).
    if (_hasFocus) return;
    final incoming = coerceChoices(widget.ctx.value);
    if (_listEquals(incoming, _currentChoices)) return;
    setState(() => _rebuildRows(incoming));
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  bool get _hasFocus => _rows.any((r) => r.focusNode.hasFocus);

  List<ZChoice> get _currentChoices =>
      <ZChoice>[for (final r in _rows) r.toChoice()];

  /// Reconstruit les lignes depuis [choices] (dispose les anciennes) — appelé au
  /// montage et au reseed hors focus (jamais dans la voie de frappe).
  void _rebuildRows(List<ZChoice> choices) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(<_ChoiceRow>[
        for (final c in choices)
          _ChoiceRow(content: c.content, isCorrect: c.isCorrect),
      ]);
  }

  /// Voie d'écriture UNIQUE (AD-2) : émet la liste courante via `ctx.onChanged`.
  void _emit() => widget.ctx.onChanged(_currentChoices);

  void _addChoice() {
    setState(() => _rows.add(_ChoiceRow(content: '', isCorrect: false)));
    _emit();
  }

  void _removeChoice(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
    _emit();
  }

  void _toggleCorrect(int index) {
    setState(() => _rows[index].isCorrect = !_rows[index].isCorrect);
    _emit();
  }

  /// Déplace la ligne [index] de [delta] (±1) en **préservant** l'identité du
  /// contrôleur/focus (réordonnancement, non recréation — AD-2).
  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _rows.length) return;
    setState(() {
      final row = _rows.removeAt(index);
      _rows.insert(target, row);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final theme = ZcrudTheme.of(context);
    final field = widget.ctx.field;
    final resolvedLabel = field.label ?? field.name;
    final readOnly = field.readOnly;
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Padding(
        padding: theme.fieldPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(resolvedLabel, style: TextStyle(color: theme.labelColor)),
            SizedBox(height: theme.gapS),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _rows.length,
              itemBuilder: (context, index) => _buildRow(theme, index, readOnly),
            ),
            SizedBox(height: theme.gapS),
            if (!readOnly) _buildAddButton(theme),
            _buildErrorSurface(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(ZcrudTheme theme, int index, bool readOnly) {
    final row = _rows[index];
    return Padding(
      key: ValueKey<String>('z-flashcard-choice-row-$index'),
      padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
      child: Row(
        children: <Widget>[
          _correctToggle(theme, index, row.isCorrect, readOnly),
          SizedBox(width: theme.gapS),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: TextField(
                key: ValueKey<String>('z-flashcard-choice-content-$index'),
                controller: row.controller,
                focusNode: row.focusNode,
                readOnly: readOnly,
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: 'Choix ${index + 1}',
                ),
                onChanged: readOnly ? null : (_) => _emit(),
              ),
            ),
          ),
          if (!readOnly) ...<Widget>[
            _iconButton(
              key: 'z-flashcard-choice-up-$index',
              icon: Icons.arrow_upward,
              tooltip: 'Monter',
              color: theme.labelColor,
              onPressed: index > 0 ? () => _move(index, -1) : null,
            ),
            _iconButton(
              key: 'z-flashcard-choice-down-$index',
              icon: Icons.arrow_downward,
              tooltip: 'Descendre',
              color: theme.labelColor,
              onPressed:
                  index < _rows.length - 1 ? () => _move(index, 1) : null,
            ),
            _iconButton(
              key: 'z-flashcard-choice-remove-$index',
              icon: Icons.delete_outline,
              tooltip: 'Supprimer',
              color: theme.errorColor,
              onPressed: () => _removeChoice(index),
            ),
          ],
        ],
      ),
    );
  }

  /// Bascule accessible du caractère « correct » d'un choix (≥ 48 dp, action
  /// sémantique `tap` opérable, thème injecté).
  Widget _correctToggle(
    ZcrudTheme theme,
    int index,
    bool isCorrect,
    bool readOnly,
  ) {
    final handler = readOnly ? null : () => _toggleCorrect(index);
    return Semantics(
      key: ValueKey<String>('z-flashcard-choice-correct-$index'),
      button: true,
      enabled: !readOnly,
      checked: isCorrect,
      label: 'Choix correct',
      onTap: handler,
      child: GestureDetector(
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onTap: handler,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Icon(
            isCorrect ? Icons.check_box : Icons.check_box_outline_blank,
            color: isCorrect ? theme.labelColor : theme.fieldBorderColor,
          ),
        ),
      ),
    );
  }

  Widget _iconButton({
    required String key,
    required IconData icon,
    required String tooltip,
    required Color? color,
    required VoidCallback? onPressed,
  }) =>
      IconButton(
        key: ValueKey<String>(key),
        icon: Icon(icon),
        color: color,
        tooltip: tooltip,
        // Cible tactile ≥ 48 dp garantie (AD-13).
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        onPressed: onPressed,
      );

  Widget _buildAddButton(ZcrudTheme theme) => Semantics(
        key: const Key('z-flashcard-choice-add'),
        button: true,
        label: widget.addChoiceLabel,
        onTap: _addChoice,
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTap: _addChoice,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: <Widget>[
                Icon(Icons.add, color: theme.labelColor),
                SizedBox(width: theme.gapS),
                Text(
                  widget.addChoiceLabel,
                  textAlign: TextAlign.start,
                  style: TextStyle(color: theme.labelColor),
                ),
              ],
            ),
          ),
        ),
      );

  /// Surface d'erreur **accessible** révélée par le canal `reveal` (AC2), sans
  /// `Form` global. Écoute UNIQUEMENT `controller.reveal` (tranche dédiée) — via
  /// [ZFlashcardEditingScope] ; absent → aucune révélation.
  Widget _buildErrorSurface(ZcrudTheme theme) {
    final controller = ZFlashcardEditingScope.maybeOf(context)?.controller;
    if (controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<int>(
      valueListenable: controller.reveal,
      builder: (context, revealEpoch, _) {
        if (revealEpoch <= 0) return const SizedBox.shrink();
        // MEDIUM-1 : ne révéler l'erreur QCM que si le type courant est bien
        // `multipleChoice` — sinon une carte non-QCM (dont le champ `choices`
        // est monté par `ZFlashcardEditionFields.all()`) afficherait un message
        // parasite lors d'un reveal déclenché par une AUTRE erreur (énoncé).
        final isMultipleChoice =
            coerceFlashcardType(controller.values[widget.typeFieldName]) ==
                ZFlashcardType.multipleChoice;
        if (!isMultipleChoice) return const SizedBox.shrink();
        final error = ZFlashcardEditionValidator.validateChoices(
          _currentChoices,
          messages: widget.messages,
        );
        if (error == null) return const SizedBox.shrink();
        return Semantics(
          liveRegion: true,
          container: true,
          child: Padding(
            padding: EdgeInsetsDirectional.only(top: theme.gapS),
            child: Text(
              error,
              key: const Key('z-flashcard-choices-error'),
              textAlign: TextAlign.start,
              style: TextStyle(color: theme.errorColor),
            ),
          ),
        );
      },
    );
  }
}

bool _listEquals(List<ZChoice> a, List<ZChoice> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
