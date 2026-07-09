/// `ZcrudLabels` — registre de libellés IMMUABLE et injectable (FR-23, AD-13).
///
/// origine : instance immuable passée à `ZcrudScope(labels:)`. **Aucun singleton
/// statique mutable, aucun setter global** : le registre est une valeur portée
/// par le scope, pas un état global. Il sert (a) à **surcharger** un libellé
/// générique fourni par `ZcrudLocalizations`, (b) à fournir des **libellés
/// métier par clé** côté app/feature — que le cœur ne connaît pas.
library;

import 'package:flutter/foundation.dart';

/// Registre de libellés immuable, injecté via `ZcrudScope(labels:)`.
///
/// La map interne est **non modifiable** ([Map.unmodifiable]) : toute tentative
/// de mutation lève `UnsupportedError`. Aucun champ `static` mutable — deux
/// instances distinctes résolvent indépendamment (preuve d'absence d'état
/// global). Égalité **par contenu** ([mapEquals]) pour que
/// `ZcrudScope.updateShouldNotify` compare des valeurs cohérentes.
@immutable
class ZcrudLabels {
  /// Construit un registre à partir de [labels] (copié en map non modifiable).
  ZcrudLabels(Map<String, String> labels)
      : _labels = Map<String, String>.unmodifiable(labels);

  const ZcrudLabels._const(this._labels);

  /// Registre vide `const` (chemin zéro-config : aucune surcharge).
  static const ZcrudLabels empty = ZcrudLabels._const(<String, String>{});

  final Map<String, String> _labels;

  /// Vue **non modifiable** des libellés (mutation ⇒ `UnsupportedError`).
  Map<String, String> get labels => _labels;

  /// Retourne le libellé de [key], ou `null` si absent (composition tolérante).
  String? maybeResolve(String key) => _labels[key];

  /// Retourne le libellé de [key] ; à défaut [fallback], à défaut [key].
  String resolve(String key, {String? fallback}) =>
      _labels[key] ?? fallback ?? key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZcrudLabels && mapEquals(_labels, other._labels));

  @override
  int get hashCode => Object.hashAllUnordered(
        _labels.entries.map((e) => Object.hash(e.key, e.value)),
      );
}
