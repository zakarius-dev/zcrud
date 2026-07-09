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
///
/// **Statique seulement** : les options issues d'une source dynamique
/// (`relation` / `choiceItemsRepository`) sont câblées au runtime (E4), pas ici.
class ZFieldChoice {
  /// Construit une option statique `const`.
  const ZFieldChoice({required this.value, required this.label});

  /// Valeur métier de l'option (opaque).
  final Object? value;

  /// Libellé d'affichage (clé l10n ou littéral).
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFieldChoice &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          label == other.label;

  @override
  int get hashCode => Object.hash(runtimeType, value, label);

  @override
  String toString() => 'ZFieldChoice(value: $value, label: $label)';
}
