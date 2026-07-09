/// Contrôleur de formulaire **Flutter-natif** — brique de réactivité granulaire
/// (AD-2, OBJECTIF PRODUIT N°1 / SM-1).
///
/// origine: refonte du bug historique de rafraîchissement GLOBAL du formulaire à
/// chaque frappe (jank, perte de focus, saut de curseur). `ZFormController` pose
/// la mécanique réactive sur laquelle E3 (`DynamicEdition`) bâtira les widgets
/// d'édition.
library;

import 'package:flutter/foundation.dart';

/// Contrôleur d'un formulaire d'édition, réactif **par tranche de champ**.
///
/// Invariants (AD-2 — NON-NÉGOCIABLES) :
/// - **Une tranche = un [ValueNotifier] mémoïsé** : [fieldListenable] renvoie
///   TOUJOURS la même instance pour un `name` donné (créée une fois, jamais
///   recréée). C'est ce qui évite la recréation d'état au rebuild — cause racine
///   du bug historique.
/// - **[setValue] ne provoque JAMAIS de rebuild global** : écrire la valeur d'un
///   champ ne notifie QUE les listeners de la tranche de ce champ. Le
///   [ChangeNotifier] global (`notifyListeners()`) est réservé aux changements
///   **structurels** (ensemble/visibilité de champs — canal [visibleFields]).
/// - **Pas de ré-injection** : le contrôleur DÉTIENT la valeur ; il n'écrit
///   jamais dans un `TextEditingController` (`.text=`). La synchronisation
///   valeur↔`TextField` et la stabilité du `TextEditingController` relèvent de
///   E3-2. Ici la saisie est à sens unique (`onChanged → setValue`).
///
/// Aucun gestionnaire d'état n'est importé (AD-15) : seules les primitives
/// `package:flutter/foundation.dart` (`ChangeNotifier`/`ValueListenable`) sont
/// utilisées. Le branchement injection/cycle de vie passe par `ZcrudScope` / un
/// binding (E2-9), jamais par une référence directe à un manager.
class ZFormController extends ChangeNotifier {
  /// Construit un contrôleur.
  ///
  /// [initialValues] pré-remplit des tranches (identité stable dès la
  /// construction). [visibleFields] fixe l'ensemble structurel initial ; à
  /// défaut il reprend les clés de [initialValues] (ou vide). Les tranches
  /// demandées ultérieurement via [fieldListenable] sont créées paresseusement
  /// et mémoïsées (voir [fieldListenable]).
  ZFormController({
    Map<String, Object?>? initialValues,
    List<String>? visibleFields,
  }) {
    if (initialValues != null) {
      initialValues.forEach((name, value) {
        _slices[name] = ValueNotifier<Object?>(value);
      });
    }
    final initial =
        visibleFields ?? initialValues?.keys.toList(growable: false) ?? const <String>[];
    _visibleFields = ValueNotifier<List<String>>(
      List<String>.unmodifiable(initial),
    );
  }

  /// Registre `name → tranche` (identité stable ; jamais recréé pour un `name`).
  final Map<String, ValueNotifier<Object?>> _slices =
      <String, ValueNotifier<Object?>>{};

  /// Canal **structurel** : ensemble/ordre des champs visibles. C'est le SEUL
  /// signal qui déclenche `notifyListeners()` du contrôleur (voir
  /// [setVisibleFields]). Un [setValue] ne le modifie jamais.
  late final ValueNotifier<List<String>> _visibleFields;

  /// Retourne la **tranche réactive** du champ [name].
  ///
  /// Renvoie TOUJOURS la même instance de [ValueListenable] pour un `name`
  /// donné (tranche stable, AC3). **`name` inconnu** : la tranche est créée
  /// paresseusement (valeur initiale `null`) puis mémoïsée — décision E2-7 (voir
  /// Dev Notes) : le formulaire dynamique (E3) ne connaît pas toujours ses
  /// champs à l'avance ; la création paresseuse évite un couplage d'ordre et un
  /// `throw` fragile. La composition structurelle (visibilité) reste gouvernée
  /// par [visibleFields], pas par la simple existence d'une tranche.
  ValueListenable<Object?> fieldListenable(String name) => _slice(name);

  ValueNotifier<Object?> _slice(String name) =>
      _slices.putIfAbsent(name, () => ValueNotifier<Object?>(null));

  /// Lit la valeur courante de la tranche [name] (`null` si jamais écrite).
  Object? valueOf(String name) => _slices[name]?.value;

  /// Met à jour **exclusivement** la tranche du champ [name].
  ///
  /// Notifie UNIQUEMENT les listeners de `fieldListenable(name)` ; les autres
  /// tranches et le `ChangeNotifier` global ne sont PAS notifiés (aucun
  /// `notifyListeners()` global — invariant SM-1). Poser la même valeur (`==`)
  /// est un no-op natif de [ValueNotifier] (pas de notification superflue).
  void setValue(String name, Object? value) {
    _slice(name).value = value;
  }

  /// Canal **structurel** : liste ordonnée des champs visibles.
  ///
  /// Seul canal qui déclenche `notifyListeners()` du contrôleur (servira E3-4,
  /// champs conditionnels). Un [setValue] ne le modifie jamais.
  ValueListenable<List<String>> get visibleFields => _visibleFields;

  /// Remplace l'ensemble structurel des champs visibles.
  ///
  /// No-op si l'ensemble est inchangé (comparaison de liste). Sinon met à jour
  /// [visibleFields] ET déclenche le `notifyListeners()` global — le SEUL
  /// déclencheur global (invariant AD-2).
  void setVisibleFields(List<String> names) {
    final next = List<String>.unmodifiable(names);
    if (listEquals(_visibleFields.value, next)) return;
    _visibleFields.value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final slice in _slices.values) {
      slice.dispose();
    }
    _slices.clear();
    _visibleFields.dispose();
    super.dispose();
  }
}
