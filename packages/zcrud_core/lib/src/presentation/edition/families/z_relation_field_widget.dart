/// Widget de la **famille relation** : `relation`.
///
/// **Abstraction** du sélecteur d'entité liée : un contrôle de sélection
/// lisant/écrivant la tranche, qui câble la **source dynamique** : le champ
/// peut s'alimenter d'un flux live d'options fourni par un [ZRelationSource]
/// **neutre injecté** (résolu au runtime via
/// `ZcrudScope.relationSourceRegistry` + `ZRelationConfig.sourceKey` dans le
/// dispatcher), appliquer un **filtre cross-champ** ([filterContext]
/// snapshot des `filterKeys`), proposer la **multi-sélection** (chips) et un
/// **modal de recherche** ([searchable]).
///
/// **Repli statique strict (rétro-compat)** : si [source] `== null`
/// (registre non injecté, clé absente/non enregistrée, ou pas de
/// `ZRelationConfig`), le rendu est **identique** au chemin sans source — un
/// `DropdownButtonFormField` sur [options] (défaut vide → désactivé mais
/// accessible), jamais un crash.
///
/// **Défensif (invariant AD-10)** : avant la 1ʳᵉ émission → état chargement
/// (désactivé, libellé `'loading'`) ; émission vide → contrôle sans option ;
/// **flux en erreur** → capturée, aucune exception propagée, conservation de
/// la dernière liste connue. Un seul `StreamSubscription`, possédé par le
/// `State` (create `initState`, `cancel` `dispose`, ré-abonnement contrôlé
/// `didUpdateWidget` si [source]/[filterContext] changent — invariant AD-2,
/// jamais recréé dans `build`).
///
/// a11y/RTL (invariant AD-13) : `DropdownButtonFormField`/chips/modal
/// directionnels (`EdgeInsetsDirectional`, `TextAlign.start`), cibles ≥ 48 dp,
/// `ListView.builder`, `Semantics`, recherche `liveRegion`. Aucune
/// couleur/inset non directionnel en dur (invariant FR-26 → `Theme.of`).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/edition/z_condition_evaluator.dart' show ZValueOf;
import '../../../domain/edition/z_field_choice.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../../domain/ports/z_relation_crud.dart';
import '../../../domain/ports/z_relation_source.dart';
import '../../l10n/z_localizations.dart';
import '../../zcrud_scope.dart';
import '../z_field_adornment_view.dart';
import '../z_field_label.dart';
import '../z_orphan_choice.dart';
import '../z_select_presenter.dart';

/// Champ d'édition **relation** (sélecteur d'entité liée, source dynamique
/// injectable + filtre cross-champ + multi + modal recherche).
class ZRelationFieldWidget extends StatefulWidget {
  /// Construit le sélecteur lié à [field]. [value] est la valeur courante
  /// (scalaire en mono ; `List<Object?>` en [multiple]), [onChanged] écrit la
  /// sélection. Params **additifs optionnels** (défauts rétro-compat) :
  /// [options] (repli statique), [source] (flux dynamique), [filterContext]
  /// (snapshot des `filterKeys`), [multiple], [searchable].
  const ZRelationFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    this.options = const <ZFieldChoice>[],
    this.source,
    this.filterContext = const <String, Object?>{},
    this.multiple = false,
    this.searchable = false,
    this.crudHandler,
    this.choiceBuilder,
    this.choiceSecondaryBuilder,
    this.optionsLoader,
    this.valueOf,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante de la tranche (id opaque en mono ; `List<Object?>` en multi).
  final Object? value;

  /// Notifié avec la valeur sélectionnée (scalaire en mono, `List<Object?>` en
  /// multi).
  final ValueChanged<Object?> onChanged;

  /// Source **statique** de repli (défaut vide) — rendue quand [source] `== null`.
  final List<ZFieldChoice> options;

  /// Source **dynamique** neutre injectée (défaut `null` → repli statique).
  final ZRelationSource? source;

  /// Snapshot des valeurs des champs `filterKeys` passé à
  /// `source.options(filterContext)` (filtre cross-champ). Défaut vide.
  final Map<String, Object?> filterContext;

  /// Multi-sélection (chips) — s'appuie sur `ZFieldSpec.multiple` (source unique).
  final bool multiple;

  /// Active le modal de recherche (filtrage client sur les libellés).
  final bool searchable;

  /// **CRUD inline** neutre injecté (défaut `null` → aucun bouton
  /// créer/modifier/copier, modal identique). Résolu au runtime par le
  /// dispatcher (`ZRelationCrudRegistry` + `ZRelationConfig.crudKey`). L'impl
  /// concrète (form + repository) vit hors du cœur (binding/app).
  final ZRelationCrudHandler? crudHandler;

  /// Rendu **complet** d'une option, fourni par l'hôte. Transmis **tel quel**
  /// au présentateur riche injecté au scope ; **sans effet** sur le rendu
  /// natif. `null` (défaut) ⇒ comportement antérieur strict. Fermeture ⇒
  /// paramètre de widget, jamais un champ de `ZFieldSpec` (invariants
  /// AD-3/AD-14).
  final ZSelectChoiceBuilder? choiceBuilder;

  /// **Affordance de fin de ligne** d'une option. Mêmes règles que
  /// [choiceBuilder] : transmis au présentateur riche, sans effet sur le
  /// rendu natif, `null` par défaut.
  final ZSelectChoiceSecondaryBuilder? choiceSecondaryBuilder;

  /// Chargeur **asynchrone paginé** d'options. Mêmes règles que [choiceBuilder].
  ///
  /// **Distinct de [source]** : [source] est un `Stream` **poussé** de la
  /// liste ENTIÈRE ; [optionsLoader] est une requête **tirée**, paginée
  /// et filtrée par le texte de recherche. Les deux peuvent coexister — le
  /// présentateur riche préfère alors le chargeur pour la liste du modal, et
  /// [source] continue d'alimenter la résolution du libellé sélectionné.
  final ZSelectOptionsLoader? optionsLoader;

  /// Lecteur **nommé** du formulaire hôte, transmis aux ornements `.widget`
  /// (valeur du champ orné + lecture d'un champ voisin). `null` ⇒ ornement
  /// rendu sans valeur (comportement d'une composition hors formulaire).
  final ZValueOf? valueOf;

  @override
  State<ZRelationFieldWidget> createState() => _ZRelationFieldWidgetState();
}

class _ZRelationFieldWidgetState extends State<ZRelationFieldWidget> {
  /// **Unique** abonnement au flux dynamique, possédé par le `State`
  /// (invariant AD-2).
  StreamSubscription<List<ZFieldChoice>>? _sub;

  /// Dernière liste connue émise par la source ; `null` avant la 1ʳᵉ émission
  /// (état chargement). Conservée telle quelle sur erreur (invariant AD-10).
  List<ZFieldChoice>? _liveChoices;

  @override
  void initState() {
    super.initState();
    if (widget.source != null) _subscribe();
  }

  @override
  void didUpdateWidget(covariant ZRelationFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ré-abonnement CONTRÔLÉ (jamais dans la voie de build) : uniquement si la
    // source change OU si le filtre cross-champ (contenu) change.
    final sourceChanged = !identical(widget.source, oldWidget.source);
    final filterChanged =
        !_mapEquals(widget.filterContext, oldWidget.filterContext);
    if (sourceChanged || filterChanged) {
      _sub?.cancel();
      _sub = null;
      if (widget.source != null) _subscribe();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    // Copie défensive du contexte (le flux le capture au moment de l'abonnement).
    final ctx = Map<String, Object?>.from(widget.filterContext);
    _sub = widget.source!.options(ctx).listen(
      (choices) {
        if (!mounted) return;
        setState(() => _liveChoices = List<ZFieldChoice>.from(choices));
      },
      // Invariant AD-10 : erreur capturée, aucune exception propagée au
      // build ; conservation de la dernière liste connue (ou reste `null` =
      // chargement).
      onError: (Object error, StackTrace stack) {},
      cancelOnError: false,
    );
  }

  /// Options effectivement affichées : le flux dynamique remplace [options]
  /// comme source d'affichage dès qu'une source est branchée.
  List<ZFieldChoice> get _choices =>
      widget.source != null ? (_liveChoices ?? const <ZFieldChoice>[]) : widget.options;

  /// `true` tant que la source dynamique n'a pas émis (état chargement,
  /// invariant AD-10).
  bool get _isLoading => widget.source != null && _liveChoices == null;

  /// `true` si un handler CRUD est résolu **et** offre encore au moins un
  /// geste (`offersAnyGesture`, lecture défensive AD-10).
  ///
  /// Un handler dont les trois droits sont refusés n'a **rien** à montrer : il
  /// ne doit donc plus imposer la surface qui portait ses boutons (le modal
  /// mono). Aucun handler existant n'est concerné — les trois droits valent
  /// `true` par défaut.
  bool get _hasCrudAffordance {
    final crud = widget.crudHandler;
    return crud != null && crud.offersAnyGesture;
  }

  @override
  Widget build(BuildContext context) {
    // Présentateur riche injecté au scope → DÉLÉGATION via DTO NEUTRE
    // (jamais le controller — invariant AD-2). Les options présentées sont
    // les choix effectifs (`_choices` : flux dynamique si branché, sinon
    // repli statique). Défaut `null` ⇒ rendu natif ci-dessous strictement
    // conservé.
    final presenter = ZcrudScope.maybeOf(context)?.selectPresenter;
    if (presenter != null) {
      return presenter.present(
        context,
        ZSelectPresentation(
          field: widget.field,
          options: _choices,
          selected: widget.value,
          onChanged: widget.onChanged,
          multiple: widget.multiple,
          searchable: widget.searchable,
          readOnly: widget.field.readOnly,
          label: _resolvedLabel,
          // Cet état (`_isLoading`) existe et le rendu natif s'en sert déjà
          // (`hintText: 'loading'`, déclencheur inerte) : le transmettre est
          // nécessaire pour qu'un présentateur riche distingue « pas encore
          // chargé » de « aucune option ».
          isLoading: _isLoading,
          choiceBuilder: widget.choiceBuilder,
          choiceSecondaryBuilder: widget.choiceSecondaryBuilder,
          // Le rendu natif expose Créer/Modifier/Copier : ne pas le
          // transmettre ferait PERDRE une capacité en enrôlant le
          // présentateur riche. Alimenté de bout en bout (registre +
          // `crudKey`).
          crudHandler: widget.crudHandler,
          optionsLoader: widget.optionsLoader,
        ),
      );
    }
    // Repli statique STRICT : aucune source → dropdown sur `options`.
    if (widget.source == null) {
      return _buildDropdown(context, widget.options, loading: false);
    }
    final choices = _choices;
    if (widget.multiple) return _buildMulti(context, choices);
    // Un handler CRUD inline impose le chemin MODAL (mono searchable), seul
    // endroit exposant les boutons Créer/Modifier/Copier. Sans handler ni
    // `searchable`, le dropdown reste inchangé — de même si le handler
    // n'offre plus AUCUN geste (rien à montrer ⇒ rien à imposer).
    if (widget.searchable || _hasCrudAffordance) {
      return _buildSearchableMono(context, choices);
    }
    return _buildDropdown(context, choices, loading: _isLoading);
  }

  String get _resolvedLabel => label(context, widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name);

  /// Dropdown mono (repli statique OU source non-searchable). [loading] désactive
  /// et affiche l'indice de chargement (invariant AD-10) sans jamais crasher.
  Widget _buildDropdown(
    BuildContext context,
    List<ZFieldChoice> rawChoices, {
    required bool loading,
  }) {
    // Garde propre à la relation : PENDANT le chargement la liste est vide,
    // donc TOUTE valeur y paraîtrait orpheline. « Pas encore chargé » n'est
    // pas « plus proposé » — on n'annote donc rien tant que `loading`, et
    // l'indice `'loading'` existant reste seul à parler.
    final choices = loading
        ? rawChoices
        : zWithOrphanChoices(rawChoices, <Object?>[widget.value]);
    final values = choices.map((c) => c.value).toList(growable: false);
    final current = values.contains(widget.value) ? widget.value : null;
    // `enabled` reste calculé sur les options RÉELLES : une option synthétique
    // n'est pas une option offerte, elle ne doit pas rendre un champ vide actif.
    final enabled = !loading && rawChoices.isNotEmpty && !widget.field.readOnly;
    return DropdownButtonFormField<Object?>(
      // Clé sur la valeur COURANTE → reflète un changement EXTERNE
      // (un `FormField` ne relit `initialValue` qu'à l'`initState`).
      key: ValueKey<Object?>(current),
      // Sans `isExpanded`, le bouton se dimensionne sur l'option la plus
      // large et déborde (même piège que `z_select_field_widget`). Les
      // libellés de RELATION (raisons sociales, intitulés d'entités) sont
      // typiquement longs — le champ est donc au moins aussi exposé que le
      // `select`.
      isExpanded: true,
      initialValue: current,
      // Label enrichi (astérisque requis) + helper + leading.
      decoration: InputDecoration(
        label: ZFieldLabel(field: widget.field),
        icon: resolveAdornment(context, widget.field.leading,
            field: widget.field, valueOf: widget.valueOf),
        hintText: label(context, loading ? 'loading' : 'select'),
        helperText: widget.field.helperText == null
            ? null
            : label(context, widget.field.helperText!,
                fallback: widget.field.helperText!),
      ),
      items: <DropdownMenuItem<Object?>>[
        for (final option in choices)
          DropdownMenuItem<Object?>(
            value: option.value,
            // L'option synthétique d'un orphelin est `disabled` — visible
            // mais non re-sélectionnable, ce qui EST son statut. La famille
            // `select` honore le même `ZFieldChoice.disabled` ; `relation`
            // suit la même règle, sans effet sur une option qui ne se
            // déclare pas désactivée.
            enabled: !option.disabled,
            child: _dropdownItemChild(context, option),
          ),
      ],
      onChanged: enabled ? widget.onChanged : null,
    );
  }

  /// Sélecteur mono **searchable** : un déclencheur ouvrant le modal de recherche.
  Widget _buildSearchableMono(BuildContext context, List<ZFieldChoice> rawChoices) {
    // Sans cette annotation, le placeholder « Sélectionner » masquerait une
    // valeur portée mais orpheline. Chargement exclu.
    final choices = _isLoading
        ? rawChoices
        : zWithOrphanChoices(rawChoices, <Object?>[widget.value]);
    final selectedLabel = _labelForValue(choices, widget.value);
    return _SelectionTrigger(
      label: _resolvedLabel,
      valueText: selectedLabel ?? label(context, _isLoading ? 'loading' : 'select'),
      hasValue: selectedLabel != null,
      enabled: !widget.field.readOnly && !_isLoading,
      onTap: () => _openModal(context, choices, multiple: false),
    );
  }

  /// Multi-sélection : chips supprimables + déclencheur d'ajout (modal multi).
  Widget _buildMulti(BuildContext context, List<ZFieldChoice> rawChoices) {
    final selected = _selectedList;
    // Sans cette résolution, une chip afficherait la clé brute pendant le
    // chargement (la liste live est vide, donc rien ne résout). Les deux
    // états sont donc textuels et traduits — « Chargement… » tant que la
    // source n'a pas émis, « Option indisponible » une fois qu'elle a émis
    // sans la valeur.
    final choices = _isLoading
        ? rawChoices
        : zWithOrphanChoices(rawChoices, selected);
    String chipLabel(Object? v) =>
        _labelForValue(choices, v) ??
        label(context, _isLoading ? 'loading' : zOrphanChoiceLabelKey);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 4),
          child: Text(_resolvedLabel,
              textAlign: TextAlign.start, style: theme.textTheme.labelLarge),
        ),
        if (selected.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 4),
            child: Text(
              label(context, _isLoading ? 'loading' : 'select'),
              textAlign: TextAlign.start,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final v in selected)
                Semantics(
                  label: chipLabel(v),
                  child: InputChip(
                    label: Text(chipLabel(v), textAlign: TextAlign.start),
                    onDeleted: widget.field.readOnly
                        ? null
                        : () => _removeValue(v),
                    deleteButtonTooltipMessage: label(context, 'remove'),
                    // Cible ≥ 48 dp (AD-13).
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                  ),
                ),
            ],
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: TextButton.icon(
              onPressed: (widget.field.readOnly || _isLoading)
                  ? null
                  : () => _openModal(context, choices, multiple: true),
              icon: const Icon(Icons.add),
              label: Text(label(context, 'add')),
            ),
          ),
        ),
      ],
    );
  }

  /// Valeurs sélectionnées en multi (défensif : normalise scalaire/`null`→liste).
  List<Object?> get _selectedList {
    final v = widget.value;
    if (v is List) return List<Object?>.from(v);
    if (v == null) return const <Object?>[];
    return <Object?>[v];
  }

  void _removeValue(Object? v) {
    final next = _selectedList.where((e) => e != v).toList(growable: false);
    widget.onChanged(next);
  }

  /// Libellé d'affichage d'une [value] (résolu depuis [choices] ; `null` si
  /// absente des options live — valeur non représentée).
  /// Item de menu déroulant — titre, plus une ligne secondaire quand l'option
  /// porte un `subtitle` (parité avec `select`).
  Widget _dropdownItemChild(BuildContext context, ZFieldChoice option) {
    final String title = label(context, option.label, fallback: option.label);
    final String? sub = option.subtitle == null
        ? null
        : label(context, option.subtitle!, fallback: option.subtitle!);
    if (sub == null || sub.isEmpty) {
      return Text(title, textAlign: TextAlign.start);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, textAlign: TextAlign.start),
        Text(
          sub,
          textAlign: TextAlign.start,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String? _labelForValue(List<ZFieldChoice> choices, Object? value) {
    for (final c in choices) {
      if (c.value == value) {
        return label(context, c.label, fallback: c.label);
      }
    }
    return null;
  }

  Future<void> _openModal(
    BuildContext context,
    List<ZFieldChoice> choices, {
    required bool multiple,
  }) async {
    final initial = multiple ? _selectedList.toSet() : <Object?>{widget.value};
    final result = await showModalBottomSheet<List<Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RelationSelectSheet(
        title: _resolvedLabel,
        choices: choices,
        multiple: multiple,
        // Un handler CRUD force la recherche (modal riche), même si la
        // config `searchable` est absente — sauf s'il n'offre plus aucun
        // geste (voir `_hasCrudAffordance`).
        searchable: widget.searchable || _hasCrudAffordance,
        initialSelection: initial,
        labelOf: (c) => label(sheetContext, c.label, fallback: c.label),
        subtitleOf: (c) => c.subtitle == null
            ? null
            : label(sheetContext, c.subtitle!, fallback: c.subtitle!),
        // CRUD inline neutre (create/edit/copy) + snapshot du filtre
        // cross-champ pour pré-remplir la création. `null` ⇒ aucun bouton.
        crudHandler: widget.crudHandler,
        crudContext: widget.filterContext,
      ),
    );
    if (result == null) return; // annulé/fermé → aucune écriture.
    if (multiple) {
      widget.onChanged(result);
    } else {
      widget.onChanged(result.isEmpty ? null : result.first);
    }
  }

  /// Égalité de contenu de deux maps (pur-Dart — évite `package:collection`).
  static bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// Déclencheur accessible d'un sélecteur modal (mono searchable) : `InputDecorator`
/// tap-able affichant la sélection courante, cible ≥ 48 dp (AD-13).
class _SelectionTrigger extends StatelessWidget {
  const _SelectionTrigger({
    required this.label,
    required this.valueText,
    required this.hasValue,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final bool hasValue;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: label,
      value: hasValue ? valueText : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.arrow_drop_down),
              enabled: enabled,
            ),
            child: Text(
              valueText,
              textAlign: TextAlign.start,
              style: hasValue
                  ? theme.textTheme.bodyLarge
                  : theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.hintColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille de sélection (modal) : recherche client sur les libellés + sélection
/// mono/multi, boutons Confirmer/Fermer l10n. Pop avec `List<Object?>` (vide si
/// « aucune sélection ») ; `null` si fermé sans confirmer. a11y/RTL (AD-13).
class _RelationSelectSheet extends StatefulWidget {
  const _RelationSelectSheet({
    required this.title,
    required this.choices,
    required this.multiple,
    required this.searchable,
    required this.initialSelection,
    required this.labelOf,
    this.subtitleOf,
    this.crudHandler,
    this.crudContext = const <String, Object?>{},
  });

  final String title;
  final List<ZFieldChoice> choices;
  final bool multiple;
  final bool searchable;
  final Set<Object?> initialSelection;
  final String Function(ZFieldChoice) labelOf;

  /// Sous-titre d'une option, ou `null`.
  ///
  /// `relation` rend `ZFieldChoice.subtitle` comme `select` et `row_chips` —
  /// c'est la famille qui en a le plus besoin : elle liste des ENTITÉS, dont
  /// le seul libellé est souvent ambigu (deux homonymes deviennent
  /// indistinguables).
  final String? Function(ZFieldChoice)? subtitleOf;

  /// CRUD inline neutre : `null` ⇒ aucun bouton créer/modifier/copier.
  final ZRelationCrudHandler? crudHandler;

  /// Snapshot du filtre cross-champ transmis à `crudHandler.create(...)`.
  final Map<String, Object?> crudContext;

  @override
  State<_RelationSelectSheet> createState() => _RelationSelectSheetState();
}

class _RelationSelectSheetState extends State<_RelationSelectSheet> {
  late final Set<Object?> _selection = <Object?>{...widget.initialSelection}
    ..removeWhere((e) => e == null);
  String _query = '';

  /// Copie **mutable** des options : une entité créée/éditée/copiée via le CRUD
  /// inline y est insérée pour apparaître immédiatement (avant que le flux live
  /// ne la reflète).
  late final List<ZFieldChoice> _choices =
      List<ZFieldChoice>.from(widget.choices);

  List<ZFieldChoice> get _filtered {
    if (_query.isEmpty) return _choices;
    final q = _query.toLowerCase();
    return _choices
        .where((c) =>
            widget.labelOf(c).toLowerCase().contains(q) ||
            // Le sous-titre porte souvent le discriminant (un `@pseudo`) : le
            // rendre visible sans le rendre cherchable serait à moitié utile.
            (widget.subtitleOf?.call(c)?.toLowerCase().contains(q) ?? false))
        .toList(growable: false);
  }

  void _toggle(Object? value) {
    setState(() {
      if (widget.multiple) {
        if (_selection.contains(value)) {
          _selection.remove(value);
        } else {
          _selection.add(value);
        }
      } else {
        _selection
          ..clear()
          ..add(value);
      }
    });
    if (!widget.multiple) {
      // Mono : sélection immédiate → confirme et ferme.
      Navigator.of(context).pop(_selection.toList());
    }
  }

  /// Insère/actualise [choice] dans la liste locale (par valeur), puis
  /// l'auto-sélectionne (mono → remplace + ferme ; multi → `addIfNotIn`).
  /// [replaced] (édition) est retirée si sa valeur change.
  void _selectResult(ZFieldChoice choice, {Object? replaced}) {
    if (!mounted) return;
    setState(() {
      if (replaced != null && replaced != choice.value) {
        _choices.removeWhere((c) => c.value == replaced);
        _selection.remove(replaced);
      }
      final idx = _choices.indexWhere((c) => c.value == choice.value);
      if (idx >= 0) {
        _choices[idx] = choice;
      } else {
        _choices.add(choice);
      }
      if (widget.multiple) {
        _selection.add(choice.value); // addIfNotIn (Set).
      } else {
        _selection
          ..clear()
          ..add(choice.value);
      }
    });
    if (!widget.multiple) {
      Navigator.of(context).pop(_selection.toList());
    }
  }

  /// Exécute une opération CRUD **défensivement** (AD-10) : `Future` en
  /// erreur/`null` ⇒ aucune écriture, aucun crash (équivalent `try/catch (_) {}`).
  Future<void> _runCrud(
    Future<ZFieldChoice?> Function() op, {
    Object? replaced,
  }) async {
    ZFieldChoice? result;
    try {
      result = await op();
    } catch (_) {
      return; // AD-10 : échec silencieux, aucune écriture.
    }
    if (result == null) return; // annulé/échec → no-op.
    _selectResult(result, replaced: replaced);
  }

  /// Sous-titre d'une option, ou `null` s'il n'y en a pas.
  Widget? _subtitleWidget(BuildContext context, ZFieldChoice choice) {
    final String? sub = widget.subtitleOf?.call(choice);
    if (sub == null || sub.isEmpty) return null;
    return Text(
      sub,
      textAlign: TextAlign.start,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final crud = widget.crudHandler;
    // Droits lus **une fois par construction** (jamais dans l'`itemBuilder` :
    // le code d'ACL de l'hôte ne doit pas s'exécuter à chaque frame de
    // défilement — invariant AD-2/SM-1). Lecture défensive AD-10 : un getter
    // hôte qui lève **ferme** le geste.
    final bool crudEdit = crud != null && crud.offersEdit;
    final bool crudCopy = crud != null && crud.offersCopy;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(widget.title,
                        textAlign: TextAlign.start,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  // Action **Créer** — rendue seulement si le handler
                  // l'offre (`offersCreate`, lecture défensive AD-10 de la
                  // déclaration hôte). Refusé ⇒ **absent**, jamais inerte.
                  if (crud != null && crud.offersCreate)
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minHeight: 48, minWidth: 48),
                      child: TextButton.icon(
                        onPressed: () => _runCrud(
                            () => crud.create(widget.crudContext)),
                        icon: const Icon(Icons.add),
                        label: Text(label(context, 'create')),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.searchable)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  textAlign: TextAlign.start,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: label(context, 'search'),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            Flexible(
              child: Semantics(
                liveRegion: true,
                container: true,
                child: filtered.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                        child: Text(label(context, 'empty'),
                            textAlign: TextAlign.start),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final choice = filtered[i];
                          final selected = _selection.contains(choice.value);
                          return CheckboxListTile(
                            value: selected,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            title: Text(widget.labelOf(choice),
                                textAlign: TextAlign.start),
                            subtitle: _subtitleWidget(context, choice),
                            // Affordances Modifier/Copier par option, chacune
                            // gouvernée par SON droit : un geste refusé n'a
                            // aucune icône, l'autre garde la sienne. Les deux
                            // refusés ⇒ aucune colonne d'actions du tout.
                            secondary: crud == null || !(crudEdit || crudCopy)
                                ? null
                                : _CrudRowActions(
                                    onEdit: !crudEdit
                                        ? null
                                        : () => _runCrud(
                                              () => crud.edit(choice.value),
                                              replaced: choice.value,
                                            ),
                                    onCopy: !crudCopy
                                        ? null
                                        : () => _runCrud(
                                            () => crud.copy(choice.value)),
                                  ),
                            // Une option `disabled` (dont l'option
                            // synthétique d'un orphelin) est visible et lue,
                            // mais non cochable — parité avec la feuille du
                            // `select`, qui applique la même règle.
                            onChanged: choice.disabled
                                ? null
                                : (_) => _toggle(choice.value),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(label(context, 'close')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selection.toList()),
                    child: Text(label(context, 'confirm')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Affordances **Modifier/Copier** par option : icônes accessibles,
/// cibles ≥ 48 dp, `Tooltip`/`Semantics`, l10n. Directionnel (invariant
/// AD-13).
///
/// Un callback `null` ⇒ l'icône correspondante n'est **pas construite** —
/// absente, donc ni cliquable, ni tabulable, ni annoncée. Jamais un
/// `IconButton(onPressed: null)` : un bouton grisé et muet est précisément ce
/// que le port refuse (cf. `ZRelationCrudHandler.canCreate`). L'icône restante
/// garde sa cible ≥ 48 dp et son annotation.
class _CrudRowActions extends StatelessWidget {
  const _CrudRowActions({this.onEdit, this.onCopy});

  final VoidCallback? onEdit;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? edit = onEdit;
    final VoidCallback? copy = onCopy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (edit != null)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: label(context, 'edit'),
            onPressed: edit,
          ),
        if (copy != null)
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: label(context, 'copy'),
            onPressed: copy,
          ),
      ],
    );
  }
}
