/// `ZTagEditor` — éditeur de tags de flashcard (Story ES-8.1, AC2/AC3/AC5/AC7).
/// ADAPTATEUR MINCE de PRÉSENTATION : il COMPOSE des primitives de domaine DÉJÀ
/// LIVRÉES (`ZFlashcardTag`/`ZSuggestedTag`, `normalizeTagTitle`/
/// `dedupeByNormalizedTitle`, `remapColorKey`/`ZColorPalette`, `orphanTagIds` —
/// toutes `zcrud_study_kernel`) — il n'en réimplémente AUCUNE.
///
/// Ce que l'éditeur POSSÈDE et PROUVE (lignes de prod PROPRES au widget) :
/// - **Création (AC2)** : la GARDE anti-doublon au point de création — un titre
///   dont la forme normalisée duplique un tag existant N'ÉMET PAS `onCreateTag` ;
///   il applique le tag EXISTANT (`onApplyExisting`).
/// - **Intégrité référentielle STRUCTURELLE (AC3)** : la composition
///   purge-sur-suppression — le modèle de références ÉMIS ne porte JAMAIS une
///   référence orpheline après suppression (`orphanTagIds(refsÉmises,
///   existantsAprès) == {}`). La **purge PERSISTÉE** (retrait des `tagIds` côté
///   store) est HORS PÉRIMÈTRE (repository ES-3, DW-ES81-2) : elle est déléguée à
///   l'app via [onReferencesPurged].
/// - **Réactivité Flutter-native (AC5)** : le `TextEditingController` de saisie
///   POSSÉDÉ est créé en `initState` (jamais dans `build`) et disposé au `dispose`
///   ; un controller INJECTÉ est utilisé tel quel et JAMAIS disposé (patron
///   owned/injected d'`ZStudyMindmapSection` ES-7.1). L'état de saisie vit dans le
///   controller ; l'état de la zone de suggestions dans un `ValueNotifier` LOCAL —
///   aucun `setState` de page, aucun gestionnaire d'état (SM-1).
/// - **Suggestion IA (AC7)** : une `ZSuggestedTag` n'est matérialisée qu'au geste
///   de confirmation explicite (jamais à l'affichage), routée par la MÊME garde de
///   dédup que la création.
///
/// AD-1 : AUCUNE nouvelle arête (symboles de `zcrud_study_kernel`/`zcrud_core`
/// DÉJÀ en dépendance). AD-14 : `onCreateTag` émet un `ZFlashcardTag` d'`id == null`
/// — l'`id` est attribué par le repository (ES-3), jamais par le widget.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show
        ZColorPalette,
        ZFlashcardTag,
        ZSuggestedTag,
        dedupeByNormalizedTitle,
        normalizeTagTitle,
        orphanTagIds,
        remapColorKey;

import 'z_tag_chips.dart';

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Icône de REPLI du bouton d'ajout/création (défaut neutre documenté ; INJECTABLE).
const IconData _kAddFallbackIcon = Icons.add;

/// Icône de REPLI du bouton de confirmation de suggestion (INJECTABLE).
const IconData _kConfirmFallbackIcon = Icons.check;

/// Icône de REPLI du bouton de rejet de suggestion (INJECTABLE).
const IconData _kRejectFallbackIcon = Icons.close;

/// Fournit le **modèle de références** courant : la liste des `tagIds` de chaque
/// carte (clés opaques). Sert au calcul de la purge STRUCTURELLE (AC3).
typedef ZCardTagIdsProvider = List<List<String>> Function();

/// Libellé sémantique INJECTÉ dérivé d'une suggestion (i18n — AC7).
typedef ZSuggestionSemanticLabel = String Function(ZSuggestedTag suggestion);

/// Éditeur de tags — création dédupliquée, suppression à intégrité référentielle
/// STRUCTURELLE, confirmation de suggestions IA.
///
/// `StatefulWidget` **uniquement** pour (a) le cycle de vie du
/// [TextEditingController] POSSÉDÉ (créé `initState` ssi non injecté, disposé
/// `dispose` ssi possédé) et (b) le `ValueNotifier` **local** de la zone de
/// suggestions. JAMAIS pour l'état des tags (immuable, passé en entrée).
class ZTagEditor extends StatefulWidget {
  /// Construit l'éditeur. [palette] est INJECTÉE (défaut recommandé documenté).
  /// Les libellés RENDUS ([inputLabel]/[inputHint]/[addSemanticLabel]) sont
  /// REQUIS (aucun défaut FR en dur — AD-13/FR-26/AC12) ; les dérivateurs
  /// sémantiques de puces/suggestions gardent un repli neutre documenté.
  const ZTagEditor({
    required this.existingTags,
    this.palette = const ZColorPalette.defaultStudy(),
    this.onCreateTag,
    this.onApplyExisting,
    this.onDeleteTag,
    this.cardTagIds,
    this.onReferencesPurged,
    this.suggestions = const <ZSuggestedTag>[],
    this.onSuggestionConfirmed,
    this.onSuggestionRejected,
    this.inputController,
    this.showUsageCount = false,
    this.referencingCardsCountOf,
    required this.inputLabel,
    required this.inputHint,
    required this.addSemanticLabel,
    this.deleteTagSemanticLabel = _defaultDeleteSemanticLabel,
    this.confirmSuggestionSemanticLabel = _defaultConfirmSemanticLabel,
    this.rejectSuggestionSemanticLabel = _defaultRejectSemanticLabel,
    this.addIcon,
    this.confirmIcon,
    this.rejectIcon,
    super.key,
  });

  /// Tags existants (immuables). Base de la GARDE anti-doublon (AC2) et du registre
  /// remonté à la suppression (AC3).
  final List<ZFlashcardTag> existingTags;

  /// Palette INJECTÉE bornant la `colorKey` d'un tag créé/matérialisé (AC1/AC2).
  final ZColorPalette palette;

  /// Émis à la création d'un tag INÉDIT — reçoit un `ZFlashcardTag` d'`id == null`
  /// (AD-14 : l'`id` est attribué par le repository). `null` = création ABSENTE.
  final void Function(ZFlashcardTag tag)? onCreateTag;

  /// Émis quand un titre saisi/confirmé DUPLIQUE (titre normalisé) un tag existant
  /// ⇒ on applique l'EXISTANT au lieu de créer un doublon (AC2/AC7). `null` = absent.
  final void Function(ZFlashcardTag tag)? onApplyExisting;

  /// Émis à la suppression d'un tag (AC3). `null` = suppression ABSENTE (AD-4).
  final void Function(ZFlashcardTag tag)? onDeleteTag;

  /// Fournit le modèle de références courant (les `tagIds` de chaque carte) — base
  /// du calcul de purge STRUCTURELLE (AC3). `null` ⇒ aucune référence à purger.
  final ZCardTagIdsProvider? cardTagIds;

  /// Émis avec le modèle de références NETTOYÉ (aucune référence orpheline) après
  /// une suppression (AC3). La **persistance** de cette purge est déléguée à l'app/
  /// au repository (ES-3, DW-ES81-2). `null` = purge non remontée.
  final void Function(List<List<String>> purgedCardTagIds)? onReferencesPurged;

  /// Suggestions IA à présenter (value objects SANS `id`). Vide = zone ABSENTE.
  final List<ZSuggestedTag> suggestions;

  /// Émis (tag matérialisé) à la CONFIRMATION explicite d'une suggestion (AC7).
  /// `null` = zone de suggestions en lecture seule.
  final void Function(ZFlashcardTag tag)? onSuggestionConfirmed;

  /// Émis au REJET d'une suggestion (AC7). `null` = rejet ABSENT (AD-4).
  final void Function(ZSuggestedTag suggestion)? onSuggestionRejected;

  /// Controller de saisie INJECTÉ (optionnel). `null` ⇒ l'éditeur en crée/possède
  /// un (disposé au `dispose`). Non-`null` ⇒ UTILISÉ tel quel, JAMAIS disposé (AC5).
  final TextEditingController? inputController;

  /// Affiche le compteur d'usages DÉRIVÉ des tags existants (AC4 — délégué aux
  /// puces). Requiert [referencingCardsCountOf].
  final bool showUsageCount;

  /// Compteur d'usages DÉRIVÉ (nb de cartes référençantes, recalculé — AC4/AD-19).
  final ZTagUsageCount? referencingCardsCountOf;

  /// Libellé INJECTÉ du champ de saisie (i18n).
  final String inputLabel;

  /// Indice INJECTÉ (`hint`) du champ de saisie (i18n).
  final String inputHint;

  /// Libellé sémantique INJECTÉ du bouton d'ajout (= tooltip).
  final String addSemanticLabel;

  /// Libellé sémantique INJECTÉ du bouton de suppression d'un tag (défaut documenté).
  final ZTagSemanticLabel deleteTagSemanticLabel;

  /// Libellé sémantique INJECTÉ du bouton de confirmation d'une suggestion.
  final ZSuggestionSemanticLabel confirmSuggestionSemanticLabel;

  /// Libellé sémantique INJECTÉ du bouton de rejet d'une suggestion.
  final ZSuggestionSemanticLabel rejectSuggestionSemanticLabel;

  /// Icône INJECTÉE du bouton d'ajout (repli neutre documenté).
  final IconData? addIcon;

  /// Icône INJECTÉE du bouton de confirmation (repli neutre documenté).
  final IconData? confirmIcon;

  /// Icône INJECTÉE du bouton de rejet (repli neutre documenté).
  final IconData? rejectIcon;

  static String _defaultDeleteSemanticLabel(ZFlashcardTag tag) =>
      'Supprimer le tag ${tag.title}';

  static String _defaultConfirmSemanticLabel(ZSuggestedTag suggestion) =>
      'Confirmer le tag suggéré ${suggestion.title}';

  static String _defaultRejectSemanticLabel(ZSuggestedTag suggestion) =>
      'Rejeter le tag suggéré ${suggestion.title}';

  @override
  State<ZTagEditor> createState() => _ZTagEditorState();
}

class _ZTagEditorState extends State<ZTagEditor> {
  /// Controller de saisie POSSÉDÉ (créé ici) — `null` si l'appelant en a injecté
  /// un. Miroir du patron owned/injected d'`ZStudyMindmapSection`.
  TextEditingController? _owned;

  /// Controller effectif : injecté prioritaire, sinon le controller possédé.
  TextEditingController get _controller => widget.inputController ?? _owned!;

  /// Zone de suggestions VISIBLES, pilotée LOCALEMENT (AD-2/AD-15). Un rejet/une
  /// confirmation retire la suggestion ; SEUL le `ValueListenableBuilder` de la
  /// zone se reconstruit — aucune propagation à la page (SM-1/AC5).
  late final ValueNotifier<List<ZSuggestedTag>> _suggestions;

  @override
  void initState() {
    super.initState();
    // Controller STABLE créé UNE fois (jamais dans build()) — AD-2/AC5.
    if (widget.inputController == null) {
      _owned = TextEditingController();
    }
    _suggestions =
        ValueNotifier<List<ZSuggestedTag>>(List<ZSuggestedTag>.of(widget.suggestions));
  }

  @override
  void didUpdateWidget(covariant ZTagEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Transition possédé ↔ injecté (défensif ; jamais recréé pour un rebuild
    // ordinaire — seule une bascule de propriété reconstruit le controller).
    if (widget.inputController != null && _owned != null) {
      _owned!.dispose();
      _owned = null;
    } else if (widget.inputController == null && _owned == null) {
      _owned = TextEditingController();
    }
    // Rafraîchir la zone de suggestions si l'appelant fournit un nouveau lot.
    if (!identical(oldWidget.suggestions, widget.suggestions)) {
      _suggestions.value = List<ZSuggestedTag>.of(widget.suggestions);
    }
  }

  @override
  void dispose() {
    // Ne disposer QUE le controller POSSÉDÉ (jamais un controller injecté — AC5).
    _owned?.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  // ── Garde de dédup PARTAGÉE (AC2 & AC7) ──────────────────────────────────────

  /// Recherche un tag existant dont le titre NORMALISÉ égale [normalized] (garde
  /// anti-doublon PROPRE à l'éditeur). Réutilise `dedupeByNormalizedTitle`/
  /// `normalizeTagTitle` du kernel — AUCUNE réimplémentation.
  ZFlashcardTag? _existingByNormalizedTitle(String normalized) {
    final deduped = dedupeByNormalizedTitle<ZFlashcardTag>(
      widget.existingTags,
      titleOf: (ZFlashcardTag t) => t.title,
    );
    for (final tag in deduped) {
      if (normalizeTagTitle(tag.title) == normalized) return tag;
    }
    return null;
  }

  /// Matérialise un titre saisi/suggéré : route via la MÊME garde (AC2/AC7).
  ///
  /// Titre normalisé DUPLIQUANT un existant ⇒ `onApplyExisting` (jamais un
  /// doublon). Titre INÉDIT ⇒ `onCreateTag` d'un `ZFlashcardTag` d'`id == null`
  /// (AD-14), `colorKey` remappée contre la palette INJECTÉE.
  void _materialize(
    String rawTitle,
    String rawColorKey, {
    required void Function(ZFlashcardTag tag)? onNew,
  }) {
    final normalized = normalizeTagTitle(rawTitle);
    if (normalized.isEmpty) return; // rien à matérialiser (AD-10).
    final existing = _existingByNormalizedTitle(normalized);
    if (existing != null) {
      widget.onApplyExisting?.call(existing);
      return;
    }
    final colorKey = remapColorKey(
      palette: widget.palette,
      rawColorKey: rawColorKey,
      seedTitle: rawTitle,
    );
    // AD-14 : `id` OMIS (null) — matérialisé par le repository (ES-3).
    final created = ZFlashcardTag(title: rawTitle.trim(), colorKey: colorKey);
    (onNew ?? widget.onCreateTag)?.call(created);
  }

  /// Soumission de la saisie (AC2) : la GARDE anti-doublon décide create vs apply.
  void _submitInput() {
    final text = _controller.text;
    if (normalizeTagTitle(text).isEmpty) return;
    _materialize(text, '', onNew: widget.onCreateTag);
    _controller.clear();
  }

  // ── Suppression / purge STRUCTURELLE (AC3) ───────────────────────────────────

  /// Supprime [tag] SANS émettre de référence orpheline (AC3).
  ///
  /// Ligne de prod PROPRE au widget : la composition purge-sur-émission. On calcule
  /// via `orphanTagIds` (kernel) les références devenues orphelines (dont l'`id` du
  /// tag supprimé) puis on ÉMET un modèle de références où ces `id` sont RETIRÉS de
  /// chaque `tagIds` ⇒ `orphanTagIds(refsÉmises, existantsAprès) == {}`. La
  /// persistance est déléguée (DW-ES81-2).
  void _deleteTag(ZFlashcardTag tag) {
    final removedId = tag.id;
    final cards = widget.cardTagIds?.call() ?? const <List<String>>[];

    if (removedId != null && widget.onReferencesPurged != null) {
      // Ids existants APRÈS retrait du tag supprimé.
      final existingAfter = <String>[
        for (final t in widget.existingTags)
          if (t.id != null && t.id != removedId) t.id!,
      ];
      // Références orphelines détectées par la primitive kernel (inclut removedId).
      final orphans = orphanTagIds(
        referencedTagIds: cards.expand((List<String> l) => l),
        existingTagIds: existingAfter,
      );
      // Purge STRUCTURELLE : retirer les orphelins de CHAQUE liste émise. Neutraliser
      // ce filtre (émettre `l` inchangée) laisserait `removedId` orphelin ⇒ RC=1.
      final purged = <List<String>>[
        for (final l in cards)
          <String>[
            for (final id in l)
              if (!orphans.contains(id)) id,
          ],
      ];
      widget.onReferencesPurged!(purged);
    }

    widget.onDeleteTag?.call(tag);
  }

  // ── Suggestions IA (AC7) ─────────────────────────────────────────────────────

  /// Confirme [suggestion] (geste EXPLICITE — jamais à l'affichage) : route par la
  /// MÊME garde de dédup que la création (AC7), puis retire la suggestion.
  void _confirmSuggestion(ZSuggestedTag suggestion) {
    _materialize(
      suggestion.title,
      suggestion.colorKey,
      onNew: widget.onSuggestionConfirmed ?? widget.onCreateTag,
    );
    _removeSuggestion(suggestion);
  }

  /// Rejette [suggestion] : n'émet AUCUN tag, la retire de la zone (AC7).
  void _rejectSuggestion(ZSuggestedTag suggestion) {
    widget.onSuggestionRejected?.call(suggestion);
    _removeSuggestion(suggestion);
  }

  void _removeSuggestion(ZSuggestedTag suggestion) {
    _suggestions.value = <ZSuggestedTag>[
      for (final s in _suggestions.value)
        if (!identical(s, suggestion) && s != suggestion) s,
    ];
  }

  // ── Rendu ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildInputRow(theme),
        SizedBox(height: theme.gapM),
        // Tags existants (puces) — délègue l'affichage/compteur DÉRIVÉ à ZTagChips.
        ZTagChips(
          tags: widget.existingTags,
          palette: widget.palette,
          showUsageCount: widget.showUsageCount,
          referencingCardsCountOf:
              widget.referencingCardsCountOf ?? _zeroCount,
          onTagRemoved: widget.onDeleteTag != null ? _deleteTag : null,
          removeTagSemanticLabel: widget.deleteTagSemanticLabel,
        ),
        // Zone de suggestions — pilotée par le notifier LOCAL (SM-1/AC5).
        ValueListenableBuilder<List<ZSuggestedTag>>(
          valueListenable: _suggestions,
          builder: (context, suggestions, _) {
            if (suggestions.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: EdgeInsetsDirectional.only(top: theme.gapM),
              child: Wrap(
                spacing: theme.gapM,
                runSpacing: theme.gapS,
                children: <Widget>[
                  for (final s in suggestions)
                    _buildSuggestionChip(theme, s),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static int _zeroCount(ZFlashcardTag tag) => 0;

  Widget _buildInputRow(ZcrudTheme theme) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: widget.inputLabel,
              hintText: widget.inputHint,
            ),
            onSubmitted: (_) => _submitInput(),
          ),
        ),
        SizedBox(width: theme.gapS),
        ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTapTarget,
            minHeight: _kMinTapTarget,
          ),
          child: IconButton(
            onPressed: _submitInput,
            tooltip: widget.addSemanticLabel,
            icon: Icon(
              widget.addIcon ?? _kAddFallbackIcon,
              semanticLabel: widget.addSemanticLabel,
            ),
          ),
        ),
      ],
    );
  }

  /// Puce de suggestion : titre TOUJOURS visible (couleur jamais seul canal, AC6),
  /// confirmation/rejet ≥ 48 dp aux libellés sémantiques INJECTÉS. La suggestion
  /// n'est JAMAIS matérialisée au rendu (AC7) — seulement au tap de confirmation.
  Widget _buildSuggestionChip(ZcrudTheme theme, ZSuggestedTag suggestion) {
    final confirmLabel = widget.confirmSuggestionSemanticLabel(suggestion);
    final rejectLabel = widget.rejectSuggestionSemanticLabel(suggestion);
    return DecoratedBox(
      key: ValueKey<String>('z-suggested-tag:${suggestion.title}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(theme.radiusM),
        border: Border.all(color: theme.fieldBorderColor ?? theme.labelColor ??
            Theme.of(context).colorScheme.outline),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: theme.gapM),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(suggestion.title, textAlign: TextAlign.start),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: IconButton(
                onPressed: () => _confirmSuggestion(suggestion),
                tooltip: confirmLabel,
                icon: Icon(
                  widget.confirmIcon ?? _kConfirmFallbackIcon,
                  semanticLabel: confirmLabel,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: _kMinTapTarget,
                minHeight: _kMinTapTarget,
              ),
              child: IconButton(
                onPressed: () => _rejectSuggestion(suggestion),
                tooltip: rejectLabel,
                icon: Icon(
                  widget.rejectIcon ?? _kRejectFallbackIcon,
                  semanticLabel: rejectLabel,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
