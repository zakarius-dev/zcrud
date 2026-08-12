/// `ZFlashcardTagConfirmSheet` — confirmation des tags suggérés post-génération.
///
/// ## Réutilise l'éditeur existant (jamais un second éditeur)
///
/// Compose [ZTagEditor] — il ne réinvente ni la garde anti-doublon, ni
/// la matérialisation `id == null`, ni les puces. Les tags suggérés
/// (fournis par l'app, suggestion IA = app-side) sont pré-cochés :
/// matérialisés dans l'ensemble confirmé dès l'ouverture, l'utilisateur pouvant
/// décocher (retrait d'une puce) ou ajouter (confirmer une suggestion
/// restante / créer un tag).
///
/// ## Ne persiste rien
///
/// La confirmation remet l'ensemble retenu à l'appelant via [onConfirmed] —
/// aucun repository/store (grep négatif prouvé sur les lignes de code,
/// commentaires exclus ⇒ RC=1 ; la garde `z_widgets_purity_test.dart` le
/// verrouille par mutation). Les tags matérialisés ont
/// `id == null` (matérialisés par le repository app-side). L'annulation
/// ([onCancel]) n'écrit rien.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZFlashcardTag, ZSuggestedTag, normalizeTagTitle, remapColorKey;

import 'z_tag_editor.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Feuille de confirmation des tags d'un lot généré — pré-cochage éditable.
class ZFlashcardTagConfirmSheet extends StatefulWidget {
  /// Construit la feuille. Tous les libellés rendus sont injectés (i18n) —
  /// aucun défaut FR en dur : [title]/[confirmLabel]/[cancelLabel] et les libellés
  /// de l'éditeur ([inputLabel]/[inputHint]/[addSemanticLabel]) sont requis, de
  /// sorte qu'une app anglaise ne peut pas hériter de français par omission.
  const ZFlashcardTagConfirmSheet({
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirmed,
    required this.inputLabel,
    required this.inputHint,
    required this.addSemanticLabel,
    this.onCancel,
    this.suggestedTags = const <ZSuggestedTag>[],
    this.existingTags = const <ZFlashcardTag>[],
    this.palette = const ZColorPalette.defaultStudy(),
    super.key,
  });

  /// Titre injecté de la feuille (i18n).
  final String title;

  /// Libellé injecté du bouton de confirmation (i18n).
  final String confirmLabel;

  /// Libellé injecté du bouton d'annulation (i18n).
  final String cancelLabel;

  /// Émis avec l'ensemble retenu (tags confirmés) — canal de handoff.
  /// Les tags peuvent porter `id == null` (matérialisés par le repository).
  final void Function(List<ZFlashcardTag> confirmedTags) onConfirmed;

  /// Émis à l'annulation (fermeture sans confirmer) — n'écrit rien.
  final VoidCallback? onCancel;

  /// Tags suggérés par l'app (value objects sans `id`) — pré-cochés.
  final List<ZSuggestedTag> suggestedTags;

  /// Tags existants (pour la garde anti-doublon de [ZTagEditor]).
  final List<ZFlashcardTag> existingTags;

  /// Palette injectée bornant la couleur des tags matérialisés.
  final ZColorPalette palette;

  /// Libellé injecté du champ de saisie (transmis à [ZTagEditor]).
  final String inputLabel;

  /// Indice injecté du champ de saisie (transmis à [ZTagEditor]).
  final String inputHint;

  /// Libellé sémantique injecté du bouton d'ajout (transmis à [ZTagEditor]).
  final String addSemanticLabel;

  @override
  State<ZFlashcardTagConfirmSheet> createState() =>
      _ZFlashcardTagConfirmSheetState();
}

class _ZFlashcardTagConfirmSheetState extends State<ZFlashcardTagConfirmSheet> {
  /// Ensemble retenu (source de vérité unique). Pré-coché = les suggestions
  /// matérialisées dès l'ouverture.
  late List<ZFlashcardTag> _confirmed;

  @override
  void initState() {
    super.initState();
    _confirmed = <ZFlashcardTag>[
      for (final s in widget.suggestedTags) _materializeSuggested(s),
    ];
  }

  /// Matérialise une suggestion en tag `id == null`, couleur bornée par
  /// la palette injectée (`remapColorKey`, jamais un clamp maison).
  ZFlashcardTag _materializeSuggested(ZSuggestedTag s) => ZFlashcardTag(
        title: s.title,
        colorKey: remapColorKey(
          palette: widget.palette,
          rawColorKey: s.colorKey,
          seedTitle: s.title,
        ),
      );

  bool _isConfirmed(String title) {
    final normalized = normalizeTagTitle(title);
    for (final t in _confirmed) {
      if (normalizeTagTitle(t.title) == normalized) return true;
    }
    return false;
  }

  /// Coche (ajoute) un tag à l'ensemble retenu, dédupliqué par titre normalisé.
  void _check(ZFlashcardTag tag) {
    if (_isConfirmed(tag.title)) return;
    setState(() => _confirmed = <ZFlashcardTag>[..._confirmed, tag]);
  }

  /// Décoche (retire) un tag de l'ensemble retenu.
  void _uncheck(ZFlashcardTag tag) {
    setState(() => _confirmed = <ZFlashcardTag>[
          for (final t in _confirmed)
            if (normalizeTagTitle(t.title) != normalizeTagTitle(tag.title)) t,
        ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Suggestions restantes = celles pas (encore) cochées : décocher une puce la
    // fait réapparaître ici (état recalculé), cocher une suggestion l'en retire.
    final pending = <ZSuggestedTag>[
      for (final s in widget.suggestedTags)
        if (!_isConfirmed(s.title)) s,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.title, textAlign: TextAlign.start),
        SizedBox(height: theme.gapM),
        ZTagEditor(
          existingTags: _confirmed,
          palette: widget.palette,
          onCreateTag: _check,
          onApplyExisting: _check,
          onSuggestionConfirmed: _check,
          onDeleteTag: _uncheck,
          suggestions: pending,
          inputLabel: widget.inputLabel,
          inputHint: widget.inputHint,
          addSemanticLabel: widget.addSemanticLabel,
        ),
        SizedBox(height: theme.gapL),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              child: TextButton(
                key: const ValueKey<String>('z-tag-confirm-cancel'),
                onPressed: widget.onCancel,
                child: Text(widget.cancelLabel, textAlign: TextAlign.center),
              ),
            ),
            SizedBox(width: theme.gapM),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              child: ElevatedButton(
                key: const ValueKey<String>('z-tag-confirm-apply'),
                onPressed: () => widget.onConfirmed(
                  List<ZFlashcardTag>.unmodifiable(_confirmed),
                ),
                child: Text(widget.confirmLabel, textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
