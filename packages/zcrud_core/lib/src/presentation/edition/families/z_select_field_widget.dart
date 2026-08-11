/// Widget de la **famille select** : `select` / `radio` / `checkbox`.
///
/// Alimenté par des `ZFieldChoice{value,label,subtitle,disabled}` — soit
/// `field.choices` (statique), soit les **choix effectifs** résolus par le
/// dispatcher ([choices], choix dynamiques cross-champ) :
/// - `select` mono → `DropdownButtonFormField` (défaut) **OU** modal de recherche
///   ([searchable] ou seuil [modalThreshold] atteint) ;
/// - `select` multi ([multiple], via `ZFieldSpec.multiple`) → **chips**
///   supprimables + modal multi ;
/// - `radio` → `RadioGroup` + `RadioListTile` (choix unique, cibles ≥ 48 dp) ;
/// - `checkbox` → `CheckboxListTile` **multi-sélection** (valeur = `List`).
///
/// **Sous-titre + disabled par option** : `ZFieldChoice.subtitle` rend
/// une ligne secondaire (radio/checkbox/tuile modal) ; `ZFieldChoice.disabled`
/// désactive l'option (dropdown `enabled: false`, radio/checkbox non cochables,
/// tuile modal grisée). `subtitle == null` + `disabled == false` ⇒ rendu
/// identique (rétro-compat stricte).
///
/// **Rétro-compat** : sans mode modal ([searchable]/[modalThreshold]) ni
/// [multiple], le `select` reste un `DropdownButtonFormField` natif inchangé.
///
/// Aucun `TextEditingController` (invariant AD-2) : lecture de `value`,
/// écriture via `onChanged`. a11y/RTL (invariant AD-13) :
/// `RadioListTile`/`CheckboxListTile`/chips/modal portent rôle + état + cible
/// ≥ 48 dp, directionnels. Aucune couleur/inset non directionnel en dur
/// (invariant FR-26). `Column`/`ListView.builder` (jamais
/// `ListView(children:)`).
library;

import 'package:flutter/material.dart';

import '../../../domain/edition/edition_field_type.dart';
import '../../../domain/edition/z_field_choice.dart';
import '../../../domain/edition/z_field_spec.dart';
import '../../l10n/z_localizations.dart';
import '../../zcrud_scope.dart';
import '../z_field_adornment_view.dart';
import '../z_orphan_choice.dart';
import '../z_select_presenter.dart';

/// Champ d'édition à **choix** (liste déroulante / modal recherche / chips /
/// radios / cases).
class ZSelectFieldWidget extends StatelessWidget {
  /// Construit le contrôle de choix lié à [field], valeur courante [value],
  /// notifiant [onChanged] avec la (les) valeur(s). Params **additifs optionnels**
  /// (défauts rétro-compat) : [choices] (choix effectifs résolus — `null` ⇒
  /// `field.choices`), [searchable]/[modalThreshold] (mode modal du `select`),
  /// [multiple] (variante chips du `select`, via `ZFieldSpec.multiple`).
  const ZSelectFieldWidget({
    required this.field,
    required this.value,
    required this.onChanged,
    this.choices,
    this.searchable = false,
    this.modalThreshold,
    this.multiple = false,
    this.bare = false,
    this.radioAsModal = false,
    this.onCleared,
    this.choiceBuilder,
    this.choiceSecondaryBuilder,
    this.optionsLoader,
    super.key,
  });

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Valeur courante (valeur unique, ou `List` pour `checkbox`/`select` multi).
  final Object? value;

  /// Notifié avec la valeur sélectionnée (unique) ou la `List` (multi).
  final ValueChanged<Object?> onChanged;

  /// Choix **effectifs** à rendre (résolus par le dispatcher : dynamique
  /// cross-champ). `null` (défaut) ⇒ `field.choices` (statique, rétro-compat).
  final List<ZFieldChoice>? choices;

  /// Active le **modal de recherche** du `select`. Défaut `false`.
  final bool searchable;

  /// Seuil de bascule automatique en modal du `select`. `null` ⇒ aucun.
  final int? modalThreshold;

  /// Variante **multi chips** du `select` (via `ZFieldSpec.multiple`). Défaut
  /// `false`. **Distinct** de `checkbox` (multi-liste inline).
  final bool multiple;

  /// Rendu **bare** (borderless, sans label) du dropdown pour le mode `large` :
  /// le décor est porté par la Card. Défaut `false`.
  final bool bare;

  /// Rend un champ `radio` comme un **déclencheur modal** de choix unique au
  /// lieu des `RadioListTile` inline. Sans effet hors `radio`. Défaut `false`
  /// (rendu inline inchangé).
  final bool radioAsModal;

  /// Callback de **remise à `null`** de la sélection (mono seulement). Le
  /// dispatcher ne le fournit que pour un `select`/`radio` **mono non requis**
  /// et éditable ; un bouton reset accessible n'est rendu que si [onCleared]
  /// est non `null` ET qu'une valeur est sélectionnée. `null` (défaut) ⇒ aucun
  /// bouton reset (rendu antérieur inchangé).
  final VoidCallback? onCleared;

  /// Rendu **complet** d'une option, fourni par l'hôte. Transmis **tel quel**
  /// au présentateur riche injecté au scope ; **sans effet** sur le rendu
  /// natif ci-dessous, qui rend ses propres tuiles. `null` (défaut) ⇒
  /// comportement antérieur strict.
  ///
  /// Paramètre de **widget** et non champ de `ZFieldSpec` : c'est une
  /// fermeture, et les invariants AD-3/AD-14 interdisent d'en loger une dans
  /// la spec `const` sérialisable. Le dispatcher déclaratif ne l'alimente
  /// donc pas.
  final ZSelectChoiceBuilder? choiceBuilder;

  /// **Affordance de fin de ligne** d'une option. Mêmes règles que
  /// [choiceBuilder] : transmis au présentateur riche, sans effet sur le
  /// rendu natif, `null` par défaut.
  final ZSelectChoiceSecondaryBuilder? choiceSecondaryBuilder;

  /// Chargeur **asynchrone paginé** d'options. Mêmes règles que
  /// [choiceBuilder] : transmis au présentateur riche, sans effet sur le
  /// rendu natif, `null` par défaut.
  final ZSelectOptionsLoader? optionsLoader;

  /// Choix effectifs (dynamique cross-champ) ou repli statique `field.choices`.
  List<ZFieldChoice> get _choices => choices ?? field.choices;

  String _label(BuildContext context, String key) =>
      label(context, key, fallback: key);

  String? _subtitle(BuildContext context, String? key) =>
      key == null ? null : label(context, key, fallback: key);

  /// `true` si le `select` mono doit passer en modal (searchable OU seuil).
  bool get _modalMode =>
      searchable ||
      (modalThreshold != null && _choices.length >= modalThreshold!);

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = label(context, field.label ?? field.name,
        fallback: field.label ?? field.name);

    // Si un présentateur riche est injecté au scope, on lui DÉLÈGUE la
    // présentation via un DTO NEUTRE (jamais le controller — invariant AD-2).
    // Défaut `null` ⇒ rendu natif ci-dessous strictement conservé.
    final presenter = ZcrudScope.maybeOf(context)?.selectPresenter;
    if (presenter != null) {
      return presenter.present(
        context,
        ZSelectPresentation(
          field: field,
          options: _choices,
          selected: value,
          onChanged: onChanged,
          multiple: multiple || field.type == EditionFieldType.checkbox,
          searchable: searchable,
          readOnly: field.readOnly,
          label: resolvedLabel,
          // `isLoading` n'est PAS transmis : cette famille n'a aucune notion
          // de chargement — ses choix sont résolus SYNCHRONEMENT par le
          // dispatcher (`_resolveSelectChoices`). Poser autre chose que le
          // défaut `false` serait une donnée inventée.
          choiceBuilder: choiceBuilder,
          choiceSecondaryBuilder: choiceSecondaryBuilder,
          optionsLoader: optionsLoader,
        ),
      );
    }

    if (field.type == EditionFieldType.checkbox) {
      return _buildCheckboxes(context, resolvedLabel);
    }
    if (field.type == EditionFieldType.radio) {
      // `radio` en modal (option) — sinon `RadioListTile` inline.
      if (radioAsModal) return _buildModalMono(context, resolvedLabel);
      return _buildRadios(context, resolvedLabel);
    }
    // Famille `select`.
    if (multiple) return _buildMultiChips(context, resolvedLabel);
    if (_modalMode) return _buildModalMono(context, resolvedLabel);
    return _buildDropdown(context);
  }

  /// Enveloppe un contrôle **mono** dans une `Row` ajoutant un bouton
  /// **reset** (→ `null`) accessible quand [onCleared] est fourni et qu'une valeur
  /// est présente. Sinon retourne [child] tel quel (rétro-compat pixel stricte).
  Widget _withReset(BuildContext context, Widget child, {required bool hasValue}) {
    if (onCleared == null || !hasValue || field.readOnly) return child;
    return Row(
      children: <Widget>[
        Expanded(child: child),
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: label(context, 'reset'),
          onPressed: onCleared,
        ),
      ],
    );
  }

  Widget _buildDropdown(BuildContext context) {
    // `DropdownButtonFormField` EXIGE que `value` figure dans `items`
    // (assertion Flutter) : un `values.contains(value) ? value : null` naïf
    // effacerait donc la valeur de l'écran alors qu'elle reste dans la
    // tranche et serait SOUMISE. On lève la contrainte au lieu de la subir,
    // en ajoutant l'option synthétique d'affichage — la donnée n'est pas
    // touchée.
    final choices = zWithOrphanChoices(_choices, <Object?>[value]);
    final values = choices.map((c) => c.value).toList(growable: false);
    final current = values.contains(value) ? value : null;
    return _withReset(
      context,
      _buildDropdownField(context, choices, current),
      hasValue: current != null,
    );
  }

  Widget _buildDropdownField(
      BuildContext context, List<ZFieldChoice> choices, Object? current) {
    return DropdownButtonFormField<Object?>(
      // Un `FormField` ne relit `initialValue` qu'à l'`initState`. Clé sur
      // la valeur COURANTE de la tranche pour que le contrôle recrée son état et
      // reflète un changement EXTERNE/programmatique. Reste DANS la tranche du
      // champ (invariant AD-2 : le rebuild est borné par
      // `ZFieldListenableBuilder`).
      key: ValueKey<Object?>(current),
      // Sans `isExpanded`, `DropdownButton` se dimensionne sur l'option la
      // PLUS LARGE et déborde (`RenderFlex overflowed`) dès qu'un libellé
      // long + les ornements de l'`InputDecoration` dépassent la largeur
      // disponible. `true` contraint le bouton à la largeur du champ ; le
      // libellé s'ellipse au lieu de déborder — c'est déjà le comportement
      // attendu d'un champ de formulaire.
      isExpanded: true,
      initialValue: current,
      // Label enrichi + hint/helper + ornements leading/prefix/suffix.
      decoration: zFieldDecoration(context, field, bare: bare),
      items: <DropdownMenuItem<Object?>>[
        for (final choice in choices)
          DropdownMenuItem<Object?>(
            value: choice.value,
            // `disabled` désactive l'option (visible mais non
            // sélectionnable) ; `subtitle` ajoute une ligne secondaire.
            enabled: !choice.disabled,
            child: _dropdownItemChild(context, choice),
          ),
      ],
      onChanged: field.readOnly ? null : onChanged,
    );
  }

  Widget _dropdownItemChild(BuildContext context, ZFieldChoice choice) {
    final sub = _subtitle(context, choice.subtitle);
    final title = Text(_label(context, choice.label), textAlign: TextAlign.start);
    if (sub == null) return title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        title,
        Text(sub,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildRadios(BuildContext context, String resolvedLabel) {
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: RadioGroup<Object?>(
        groupValue: value,
        onChanged: onChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
              child: Text(resolvedLabel,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            // Sans option synthétique, `RadioGroup` ne trouverait AUCUNE
            // tuile portant `groupValue` : le champ paraîtrait « rien de
            // coché » alors qu'une valeur est portée et serait soumise. La
            // tuile synthétique est `enabled: false` (non re-sélectionnable)
            // mais bien cochée — l'état réel, visible.
            for (final choice in zWithOrphanChoices(_choices, <Object?>[value]))
              RadioListTile<Object?>(
                value: choice.value,
                // `enabled: false` DÉSACTIVE réellement chaque radio (état
                // `disabled` correct a11y/UX) — combine `readOnly` global
                // ET `choice.disabled` (désactivation par option).
                enabled: !field.readOnly && !choice.disabled,
                title: Text(_label(context, choice.label)),
                subtitle: _subtitleWidget(context, choice),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxes(BuildContext context, String resolvedLabel) {
    final selected = value is Iterable
        ? List<Object?>.from(value! as Iterable)
        : <Object?>[];
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 0),
            child: Text(resolvedLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          // Une valeur cochée absente des options ne rendrait AUCUNE tuile
          // sans l'option synthétique. Elle la montre cochée et désactivée
          // (`choice.disabled` ⇒ `onChanged: null`), donc non décochable :
          // ce widget ne rend que ce que son propre geste écrit.
          for (final choice in zWithOrphanChoices(_choices, selected))
            CheckboxListTile(
              value: selected.contains(choice.value),
              // `disabled` par option → `onChanged: null` (non cochable).
              onChanged: (field.readOnly || choice.disabled)
                  ? null
                  : (checked) => _toggle(selected, choice, checked),
              title: Text(_label(context, choice.label)),
              subtitle: _subtitleWidget(context, choice),
            ),
        ],
      ),
    );
  }

  Widget? _subtitleWidget(BuildContext context, ZFieldChoice choice) {
    final sub = _subtitle(context, choice.subtitle);
    if (sub == null) return null;
    return Text(sub, textAlign: TextAlign.start);
  }

  /// `select` mono en **modal de recherche** : un déclencheur
  /// accessible ouvrant le modal (recherche client + sous-titre + disabled).
  Widget _buildModalMono(BuildContext context, String resolvedLabel) {
    // Sans l'option synthétique, `_labelForValue` rendrait `null` et le
    // déclencheur afficherait le PLACEHOLDER « Sélectionner » : le champ
    // paraîtrait vide alors qu'il porte une valeur (et le bouton reset,
    // piloté par `hasValue`, disparaîtrait — l'utilisateur n'aurait alors
    // aucun moyen de retirer ce qu'il ne voit pas).
    final choices = zWithOrphanChoices(_choices, <Object?>[value]);
    final selectedLabel = _labelForValue(context, choices, value);
    return _withReset(
      context,
      _ChoiceSelectionTrigger(
        label: resolvedLabel,
        valueText: selectedLabel ?? label(context, 'select'),
        hasValue: selectedLabel != null,
        enabled: !field.readOnly,
        onTap: () =>
            _openModal(context, resolvedLabel, choices, multiple: false),
      ),
      hasValue: selectedLabel != null,
    );
  }

  /// `select` **multi chips** (via `ZFieldSpec.multiple`) : chips
  /// supprimables + déclencheur d'ajout (modal multi).
  Widget _buildMultiChips(BuildContext context, String resolvedLabel) {
    final selected = _selectedList;
    // Sans les options synthétiques, l'IDENTIFIANT BRUT s'afficherait
    // (`_labelForValue(...) ?? '$v'`). Elles donnent un libellé à chaque
    // orphelin ; le `??` ci-dessous devient donc inatteignable et reste
    // garni d'un libellé (jamais d'une clé) par défense en profondeur.
    final choices = zWithOrphanChoices(_choices, selected);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: resolvedLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 4),
            child: Text(resolvedLabel,
                textAlign: TextAlign.start, style: theme.textTheme.labelLarge),
          ),
          if (selected.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 4),
              child: Text(
                label(context, 'select'),
                textAlign: TextAlign.start,
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final v in selected)
                  Semantics(
                    label: _labelForValue(context, choices, v) ??
                        zOrphanChoiceLabel(context),
                    child: InputChip(
                      label: Text(
                          _labelForValue(context, choices, v) ??
                              zOrphanChoiceLabel(context),
                          textAlign: TextAlign.start),
                      onDeleted: field.readOnly ? null : () => _removeValue(v),
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
                onPressed: field.readOnly
                    ? null
                    : () => _openModal(context, resolvedLabel, choices,
                        multiple: true),
                icon: const Icon(Icons.add),
                label: Text(label(context, 'add')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Valeurs sélectionnées en multi (défensif : normalise scalaire/`null`→liste).
  List<Object?> get _selectedList {
    final v = value;
    if (v is List) return List<Object?>.from(v);
    if (v == null) return const <Object?>[];
    return <Object?>[v];
  }

  void _removeValue(Object? v) {
    final next = _selectedList.where((e) => e != v).toList(growable: false);
    onChanged(next);
  }

  /// Libellé d'affichage d'une [value] (résolu depuis [choices] ; `null` si
  /// absente des options — valeur affichée brute, jamais un crash).
  String? _labelForValue(
      BuildContext context, List<ZFieldChoice> choices, Object? value) {
    for (final c in choices) {
      if (c.value == value) return label(context, c.label, fallback: c.label);
    }
    return null;
  }

  void _toggle(List<Object?> selected, ZFieldChoice choice, bool? checked) {
    final next = List<Object?>.from(selected);
    if (checked == true) {
      if (!next.contains(choice.value)) next.add(choice.value);
    } else {
      next.remove(choice.value);
    }
    onChanged(next);
  }

  Future<void> _openModal(
    BuildContext context,
    String title,
    List<ZFieldChoice> choices, {
    required bool multiple,
  }) async {
    final initial = multiple ? _selectedList.toSet() : <Object?>{value};
    final result = await showModalBottomSheet<List<Object?>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ZChoiceSelectSheet(
        title: title,
        choices: choices,
        multiple: multiple,
        searchable: true,
        initialSelection: initial,
        labelOf: (c) => label(sheetContext, c.label, fallback: c.label),
        subtitleOf: (c) => _subtitle(sheetContext, c.subtitle),
      ),
    );
    if (result == null) return; // annulé/fermé → aucune écriture.
    if (multiple) {
      onChanged(result);
    } else {
      onChanged(result.isEmpty ? null : result.first);
    }
  }
}

/// Déclencheur accessible d'un sélecteur modal (mono) : `InputDecorator` tap-able
/// affichant la sélection courante, cible ≥ 48 dp (AD-13).
class _ChoiceSelectionTrigger extends StatelessWidget {
  const _ChoiceSelectionTrigger({
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
                  : theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Feuille de sélection (modal) du `select` : recherche client sur les
/// libellés + sélection mono/multi, **sous-titre + option désactivée** par tuile,
/// boutons Confirmer/Fermer l10n. Pop avec `List<Object?>` (vide si « aucune
/// sélection ») ; `null` si fermé sans confirmer. a11y/RTL (invariant AD-13).
///
/// Gabarit **dupliqué** de `_RelationSelectSheet` (duplication assumée dans
/// ce fichier) enrichi de `subtitleOf`/`disabled`.
class _ZChoiceSelectSheet extends StatefulWidget {
  const _ZChoiceSelectSheet({
    required this.title,
    required this.choices,
    required this.multiple,
    required this.searchable,
    required this.initialSelection,
    required this.labelOf,
    required this.subtitleOf,
  });

  final String title;
  final List<ZFieldChoice> choices;
  final bool multiple;
  final bool searchable;
  final Set<Object?> initialSelection;
  final String Function(ZFieldChoice) labelOf;
  final String? Function(ZFieldChoice) subtitleOf;

  @override
  State<_ZChoiceSelectSheet> createState() => _ZChoiceSelectSheetState();
}

class _ZChoiceSelectSheetState extends State<_ZChoiceSelectSheet> {
  late final Set<Object?> _selection = <Object?>{...widget.initialSelection}
    ..removeWhere((e) => e == null);
  String _query = '';

  List<ZFieldChoice> get _filtered {
    if (_query.isEmpty) return widget.choices;
    final q = _query.toLowerCase();
    return widget.choices
        .where((c) => widget.labelOf(c).toLowerCase().contains(q))
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
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
              child: Text(widget.title,
                  textAlign: TextAlign.start,
                  style: Theme.of(context).textTheme.titleMedium),
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
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16, 16, 16, 16),
                        child: Text(label(context, 'empty'),
                            textAlign: TextAlign.start),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final choice = filtered[i];
                          final selected = _selection.contains(choice.value);
                          final sub = widget.subtitleOf(choice);
                          return CheckboxListTile(
                            value: selected,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(widget.labelOf(choice),
                                textAlign: TextAlign.start),
                            subtitle: sub == null
                                ? null
                                : Text(sub, textAlign: TextAlign.start),
                            // Option désactivée non cochable (a11y).
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
