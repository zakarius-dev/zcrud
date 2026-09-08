/// Registre OUVERT des thèmes nommés.
///
/// Un thème est une **identité**, pas une énumération fermée : un hôte ou un
/// paquet tiers doit pouvoir en ajouter un sans modifier ce fichier. Le
/// registre est donc une table enregistrable ([ZThemeCatalog.register]), et
/// non un `enum` ni une hiérarchie `sealed` — c'est le patron d'extensibilité
/// de la boîte à outils (invariant AD-4, même forme que `ZTypeRegistry`).
///
/// Le catalogue ne porte **aucune valeur de design** : seulement de quoi
/// présenter un choix de thème à l'utilisateur (une identité stable et une clé
/// de libellé). Les valeurs vivent dans les fichiers de référence du thème.
library;

import 'package:flutter/foundation.dart';

/// Identité d'un thème nommé.
@immutable
class ZThemeSpec {
  /// Crée une identité de thème.
  const ZThemeSpec({required this.id, required this.labelKey});

  /// Identifiant stable et non traduit (`'classic'`). C'est lui qu'un hôte
  /// persiste dans les préférences de l'utilisateur : il ne change jamais.
  final String id;

  /// Clé l10n du libellé affiché.
  ///
  /// Une CLÉ, jamais un texte : le nom d'un thème se traduit comme le reste de
  /// l'interface, et ce paquet ne connaît aucune langue.
  final String labelKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZThemeSpec && id == other.id && labelKey == other.labelKey;

  @override
  int get hashCode => Object.hash(id, labelKey);

  @override
  String toString() => 'ZThemeSpec($id)';
}

/// Registre ouvert des thèmes disponibles.
///
/// ```dart
/// for (final spec in ZThemeCatalog.specs) {
///   // spec.id -> à persister ; spec.labelKey -> à traduire.
/// }
/// ```
abstract final class ZThemeCatalog {
  /// Identité du thème Classic.
  static const ZThemeSpec classic = ZThemeSpec(
    id: 'classic',
    labelKey: 'zcrud.theme.classic',
  );

  static final Map<String, ZThemeSpec> _registry = <String, ZThemeSpec>{
    classic.id: classic,
  };

  /// Enregistre [spec], en remplaçant toute entrée de même
  /// [ZThemeSpec.id]. Point d'extension du registre (invariant AD-4).
  static void register(ZThemeSpec spec) => _registry[spec.id] = spec;

  /// Les thèmes enregistrés, dans leur ordre d'enregistrement.
  static List<ZThemeSpec> get specs =>
      List<ZThemeSpec>.unmodifiable(_registry.values);

  /// Le thème d'identifiant [id], ou `null` s'il n'est pas enregistré.
  ///
  /// Total et défensif (invariant AD-10) : un identifiant inconnu — venu par
  /// exemple d'une préférence persistée par une version antérieure — rend
  /// `null`, jamais une exception. L'appelant retombe alors sur son thème par
  /// défaut.
  static ZThemeSpec? byId(String id) => _registry[id];

  /// Retire [id] du registre. Rend `true` si une entrée a été retirée.
  ///
  /// Destiné aux tests et aux hôtes qui composent leur propre catalogue ;
  /// retirer [classic] est permis et sans effet sur les valeurs du thème.
  static bool unregister(String id) => _registry.remove(id) != null;
}
