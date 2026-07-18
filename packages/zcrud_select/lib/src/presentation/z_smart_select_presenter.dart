/// Présentateur riche `ZSelectPresenter` adossé au fork vendorisé
/// `awesome_select` (`SmartSelect`) — fp-4-1 (AD-48).
///
/// **Rôle** : implémentation CONCRÈTE du seam `ZSelectPresenter` (livré par le
/// cœur, fp-1-1). Injectée via `ZcrudScope(selectPresenter: const
/// ZSmartSelectPresenter())`, elle **supplante** le rendu natif des familles
/// `select` / `radio` / `checkbox` / `multiselect` / `relation` par un
/// **modal S2 responsive + recherche** à parité DODLP.
///
/// **Isolation (AD-40/AD-49)** : `SmartSelect` / `S2*` restent CONFINÉS sous
/// `lib/src/` — AUCUN type `awesome_select` ne fuit au barrel ni dans la
/// signature `present()` (neutre, `zcrud_core`). Les helpers de conversion
/// `ZFieldChoice → S2Choice` sont **privés**.
///
/// **AD-2/SM-1** : le présentateur ne touche JAMAIS le `ZFormController` ; il
/// lit la tranche via `presentation.selected` et **notifie** via
/// `presentation.onChanged` (valeur MÉTIER : scalaire en mono, `List` en multi —
/// jamais un type S2, jamais la concaténation littérale `"S2Choice"` du DODLP).
///
/// **AD-10 (défensif)** : options vides / `selected` hors options / option
/// `disabled` → rendu **dégradé défini** (sélecteur vide accessible / placeholder
/// / option non cochable), jamais une exception.
///
/// **AD-13 / FR-26** : déclencheur avec une **seule** annonce accessible
/// (`Semantics(button:, label:)` + `ExcludeSemantics` sur l'habillage), cible
/// **≥ 48 dp**, couleurs dérivées du `Theme`/`ColorScheme` (aucune constante en
/// dur), insets **directionnels**. Libellés d'options résolus via
/// `label(context, ...)` (jamais la clé brute).
library;

import 'package:awesome_select/awesome_select.dart';
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Présentateur riche `select`/`radio`/`checkbox`/`multiselect`/`relation`
/// (AD-48) au-dessus de `SmartSelect`.
///
/// `const`-constructible et **sans side-effect d'import** (aucun `register*()`
/// top-level) : l'enrôlement est **explicite** via `ZcrudScope.selectPresenter`
/// (AR-4). Immuable ⇒ partageable en `const`.
class ZSmartSelectPresenter extends ZSelectPresenter {
  /// Constructeur `const` (présentateur immuable, injectable en `const`).
  const ZSmartSelectPresenter();

  @override
  Widget present(BuildContext context, ZSelectPresentation presentation) {
    // Titre du modal + déclencheur : label déjà résolu (l10n) sinon repli sur la
    // spéc du champ. TOUJOURS non-null (assert `SmartSelect`).
    final String title = presentation.label ??
        presentation.field.label ??
        presentation.field.name;

    // AD-10 : projection défensive — options vides restent une `List` non-null
    // (assert `choiceItems != null`), aucune exception.
    //
    // Type-param `dynamic` (valeurs métier opaques) : `SmartSelect<dynamic>` a
    // pour `runtimeType` le littéral `SmartSelect` — indispensable pour la garde
    // de rendu `find.byType(SmartSelect)` (comparaison d'égalité de type).
    final List<S2Choice<dynamic>> choiceItems =
        _toS2Choices(context, presentation.options);

    final bool enabled = !presentation.readOnly;

    // FR-26 : placeholder de l'état vide LOCALISÉ via la l10n injectée (clé
    // `select`, résolue en/fr par `ZcrudLocalizations`) — JAMAIS le littéral
    // anglais `'Select one'` / `'Select one or more'` du fork. Passé à
    // `SmartSelect` (paramètre `placeholder:`) ET employé directement dans le
    // déclencheur, pour que le libellé anglais du fork ne surface nulle part.
    final String placeholder = label(context, 'select');

    if (presentation.multiple) {
      return SmartSelect<dynamic>.multiple(
        title: title,
        placeholder: placeholder,
        // AD-10 : normalise scalaire/`null`/`List` → `List<Object?>` ; une
        // valeur hors options est simplement non représentée (placeholder).
        selectedValue: _asList(presentation.selected),
        choiceItems: choiceItems,
        choiceType: S2ChoiceType.checkboxes,
        modalType: S2ModalType.bottomSheet,
        modalFilter: presentation.searchable,
        // Valeur MÉTIER : une vraie `List<Object?>` (jamais la concat "S2Choice").
        onChange: enabled
            ? (state) => presentation.onChanged(
                  List<Object?>.from(state.value),
                )
            : (_) {},
        tileBuilder: (context, state) => _ZSmartSelectTile(
          label: title,
          // État vide → placeholder LOCALISÉ (jamais `state.selected.toString()`
          // qui retombe sur `'Select one or more'` du fork).
          valueText:
              state.selected.isNotEmpty ? state.selected.toString() : placeholder,
          hasValue: state.selected.isNotEmpty,
          enabled: enabled,
          onTap: state.showModal,
        ),
      );
    }

    // Mono : `select` / `radio` (parité `radioAsModal` DODLP) — choix unique en
    // modal S2, `choiceType: radios`.
    return SmartSelect<dynamic>.single(
      title: title,
      placeholder: placeholder,
      selectedValue: presentation.selected,
      choiceItems: choiceItems,
      choiceType: S2ChoiceType.radios,
      modalType: S2ModalType.bottomSheet,
      modalFilter: presentation.searchable,
      // Valeur MÉTIER scalaire (jamais un type S2).
      onChange:
          enabled ? (state) => presentation.onChanged(state.value) : (_) {},
      tileBuilder: (context, state) => _ZSmartSelectTile(
        label: title,
        // État vide → placeholder LOCALISÉ (jamais `'Select one'` du fork).
        valueText:
            state.selected.isResolved ? state.selected.toString() : placeholder,
        hasValue: state.selected.isResolved,
        enabled: enabled,
        onTap: state.showModal,
      ),
    );
  }

  /// Projette les options **neutres** `ZFieldChoice` en `S2Choice` **privés**
  /// (aucun S2 ne franchit la frontière publique). Résout les libellés d'options
  /// via `label(context, ...)` (clé l10n → texte, repli sur la clé). `disabled`
  /// est propagé (option visible mais non sélectionnable — AD-10/AD-13).
  static List<S2Choice<dynamic>> _toS2Choices(
    BuildContext context,
    List<ZFieldChoice> options,
  ) {
    return <S2Choice<dynamic>>[
      for (final c in options)
        S2Choice<dynamic>(
          value: c.value,
          title: label(context, c.label, fallback: c.label),
          subtitle: c.subtitle == null
              ? null
              : label(context, c.subtitle!, fallback: c.subtitle!),
          disabled: c.disabled,
        ),
    ];
  }

  /// Normalise la sélection multi (défensif AD-10) : scalaire/`null` → `List`.
  static List<Object?> _asList(Object? selected) {
    if (selected is List) return List<Object?>.from(selected);
    if (selected == null) return const <Object?>[];
    return <Object?>[selected];
  }
}

/// Déclencheur accessible du modal S2 (AD-13 / FR-26).
///
/// **Une SEULE annonce accessible** : le nœud `Semantics` porte lui-même le rôle
/// `button`, le `label`, la `value` ET l'action `tap` (`onTap:`), avec
/// `excludeSemantics: true` qui **écarte tous les nœuds descendants** (InkWell /
/// InputDecorator / Text) — pas de double annonce, mais l'activation par lecteur
/// d'écran reste possible (l'action `tap` vit sur ce même nœud). Cible **≥ 48 dp**
/// (`ConstrainedBox(minHeight: 48)`). Couleurs dérivées du `Theme` (aucune
/// constante en dur). Alignement **directionnel** (`TextAlign.start`, RTL).
class _ZSmartSelectTile extends StatelessWidget {
  const _ZSmartSelectTile({
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
      enabled: enabled,
      label: label,
      value: hasValue ? valueText : null,
      // L'action `tap` est portée par CE nœud → activable par lecteur d'écran
      // malgré `excludeSemantics` (qui n'écarte que les descendants).
      onTap: enabled ? onTap : null,
      excludeSemantics: true,
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
