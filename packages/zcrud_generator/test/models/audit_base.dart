/// Base de PREUVE (test-only — PAS un package produit) reproduisant la forme
/// d'une entité de domaine qui porte des **canaux hors schéma**.
///
/// Ce que la base impose, et que le mixin doit respecter pour compiler :
///   - `toMap()` prend un paramètre nommé ([AuditRegistry]) que le schéma
///     n'exprime pas ;
///   - `copyWith()` couvre trois canaux — `label`, `extra`, `source` — dont
///     aucun n'est annoté, donc aucun n'est vu par le codegen ;
///   - la sentinelle de `copyWith()` est **privée à cette bibliothèque** : une
///     sous-classe ne peut pas la nommer, et lui en passer une autre ferait
///     prendre chaque argument omis pour une valeur explicite.
library;

/// Collaborateur injectable factice — tient le rôle d'un registre de provenance.
class AuditRegistry {
  /// Construit le registre.
  const AuditRegistry(this.prefix);

  /// Préfixe appliqué à la provenance encodée.
  final String prefix;
}

/// Sentinelle PRIVÉE — inaccessible depuis toute autre bibliothèque.
const Object _undefined = Object();

/// Racine à canaux hors schéma.
class AuditBase {
  /// Construit la racine.
  const AuditBase({
    this.label,
    Map<String, dynamic>? extra,
    this.source,
  }) : _extraOrNull = extra;

  /// Libellé libre, hors schéma (non annoté).
  final String? label;

  final Map<String, dynamic>? _extraOrNull;

  /// Clés inconnues préservées, hors schéma — normalisées par l'accesseur, dont
  /// le type diffère de celui du paramètre de construction.
  Map<String, dynamic> get extra => _extraOrNull ?? const <String, dynamic>{};

  /// Provenance, hors schéma.
  final String? source;

  /// Map de la base : canaux hors schéma compris.
  Map<String, dynamic> toMap({AuditRegistry? registry}) => <String, dynamic>{
        ...extra,
        'label': label,
        if (source != null) 'source': '${registry?.prefix ?? ''}$source',
      };

  /// Copie à sentinelle couvrant les trois canaux hors schéma.
  AuditBase copyWith({
    Object? label = _undefined,
    Object? extra = _undefined,
    Object? source = _undefined,
  }) =>
      AuditBase(
        label: identical(label, _undefined) ? this.label : label as String?,
        extra: identical(extra, _undefined)
            ? this.extra
            : extra as Map<String, dynamic>,
        source: identical(source, _undefined) ? this.source : source as String?,
      );
}
