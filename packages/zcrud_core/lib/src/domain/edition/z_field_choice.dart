/// Option statique d'un champ à choix (`select`/`radio`/`checkbox`), portée par
/// `@ZcrudField.choices` (authoring) et projetée dans `ZFieldSpec.choices`
/// (runtime, E2-5).
///
/// origine: paire `choiceValueKey`/`choiceLabelKey` DODLP
/// (technical-inventory §3, ligne `select`). Nom **distinct** de `ZChoice`
/// (flashcard) : concept différent — option de champ, pas choix de QCM.
library;

/// Une option `{value, label}` proposée à la sélection.
///
/// Type-valeur `const` pur-données (lisible par `ConstantReader` en E2-5) :
/// - [value] : valeur métier stockée (opaque, `Object?`).
/// - [label] : libellé d'affichage (clé l10n ou littéral ; résolu côté UI, E3).
/// - [subtitle] : **sous-titre** optionnel par option (DP-15/M8, parité
///   `choiceSubTitleBuilder` DODLP ; défaut `null` ⇒ rendu E3-3a inchangé).
/// - [disabled] : option **désactivée** (non sélectionnable mais visible/
///   accessible — DP-15/M8, parité `s2ChoiceDisabled` DODLP ; défaut `false`).
///
/// **Statique seulement** : les options issues d'une source dynamique
/// (`relation` / `choiceItemsRepository`) sont câblées au runtime (E4), pas ici.
class ZFieldChoice {
  /// Construit une option statique `const`. [subtitle]/[disabled] sont
  /// **additifs** (défauts rétro-compat : `null`/`false`).
  const ZFieldChoice({
    required this.value,
    required this.label,
    this.subtitle,
    this.disabled = false,
  });

  /// Valeur métier de l'option (opaque).
  final Object? value;

  /// Libellé d'affichage (clé l10n ou littéral).
  final String label;

  /// Sous-titre d'affichage optionnel (clé l10n ou littéral ; résolu côté UI).
  /// `null` (défaut) ⇒ aucune ligne secondaire (rendu E3-3a strict).
  final String? subtitle;

  /// Option **désactivée** : affichée/accessible mais non sélectionnable
  /// (a11y : porte l'état `disabled`, pas un simple grisage). Défaut `false`.
  final bool disabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFieldChoice &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          label == other.label &&
          subtitle == other.subtitle &&
          disabled == other.disabled;

  @override
  int get hashCode => Object.hash(runtimeType, value, label, subtitle, disabled);

  @override
  String toString() =>
      'ZFieldChoice(value: $value, label: $label, subtitle: $subtitle, '
      'disabled: $disabled)';
}
