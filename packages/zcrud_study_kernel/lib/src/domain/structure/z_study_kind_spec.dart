/// `ZStudyKindSpec` — déclaration d'un type de structure et de **ce qu'il sait
/// faire**.
///
/// C'est la pièce qui remplace toute énumération fermée. Le noyau ne teste
/// jamais un type concret : il demande à la spécification si le type porte une
/// **capacité** (`zHasCapability`). Un contexte pédagogique inconnu se décrit
/// donc entièrement en données, sans une ligne de code dans le socle.
///
/// **Ensembles vides = aucune restriction.** [allowedParentKinds],
/// [allowedChildKinds] et [allowedVocabularyKeys] vides signifient « tout est
/// permis », jamais « rien n'est permis ». C'est ce qui rend une ontologie
/// partielle utilisable telle quelle.
///
/// [key] et [family] sont des chaînes opaques ; les constantes
/// `kZStudyFamily…` nomment les familles que le noyau range dans des registres
/// distincts, mais une famille inconnue reste valide.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Déclaration immuable d'un type de structure.
class ZStudyKindSpec {
  /// Construit une spécification de type.
  const ZStudyKindSpec({
    required this.key,
    this.family = '',
    this.label,
    this.iconKey,
    this.capabilities = const <String>{},
    this.allowedParentKinds = const <String>{},
    this.allowedChildKinds = const <String>{},
    this.allowedVocabularyKeys = const <String>{},
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyKindSpec.fromMap(Map<String, dynamic> map) => ZStudyKindSpec(
    key: zJsonString(map['key']),
    family: zJsonString(map['family']),
    label: zJsonStringOrNull(map['label']),
    iconKey: zJsonStringOrNull(map['icon_key']),
    capabilities: zStudyDecodeStringSet(map['capabilities']),
    allowedParentKinds: zStudyDecodeStringSet(map['allowed_parent_kinds']),
    allowedChildKinds: zStudyDecodeStringSet(map['allowed_child_kinds']),
    allowedVocabularyKeys: zStudyDecodeStringSet(
      map['allowed_vocabulary_keys'],
    ),
  );

  /// Clé du type — chaîne opaque, défaut `''`.
  final String key;

  /// Famille du type (registre de l'ontologie) — chaîne opaque, défaut `''`.
  final String family;

  /// Libellé affichable, `null` si absent. Destiné à être remplacé par la
  /// localisation de l'application : le noyau ne traduit rien.
  final String? label;

  /// Clé d'icône résolue côté hôte (jamais un widget), `null` si absente.
  final String? iconKey;

  /// Capacités du type, défaut `const {}`. Voir les constantes
  /// `kZStudyCapability…` ; une capacité inconnue est conservée et
  /// interrogeable, simplement jamais lue par une primitive du noyau.
  final Set<String> capabilities;

  /// Types de parent autorisés ; **vide = aucune restriction**.
  final Set<String> allowedParentKinds;

  /// Types d'enfant autorisés ; **vide = aucune restriction**.
  final Set<String> allowedChildKinds;

  /// Vocabulaires que ce type peut porter ; **vide = aucune restriction**.
  final Set<String> allowedVocabularyKeys;

  /// `true` si le type déclare [capability].
  bool hasCapability(String capability) => capabilities.contains(capability);

  /// Sérialise vers la map persistée ; un ensemble vide n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'key': key,
    'family': family,
    if (label != null) 'label': label,
    if (iconKey != null) 'icon_key': iconKey,
    if (capabilities.isNotEmpty)
      'capabilities': capabilities.toList(growable: false),
    if (allowedParentKinds.isNotEmpty)
      'allowed_parent_kinds': allowedParentKinds.toList(growable: false),
    if (allowedChildKinds.isNotEmpty)
      'allowed_child_kinds': allowedChildKinds.toList(growable: false),
    if (allowedVocabularyKeys.isNotEmpty)
      'allowed_vocabulary_keys': allowedVocabularyKeys.toList(growable: false),
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyKindSpec copyWith({
    Object? key = _undefined,
    Object? family = _undefined,
    Object? label = _undefined,
    Object? iconKey = _undefined,
    Object? capabilities = _undefined,
    Object? allowedParentKinds = _undefined,
    Object? allowedChildKinds = _undefined,
    Object? allowedVocabularyKeys = _undefined,
  }) => ZStudyKindSpec(
    key: identical(key, _undefined) ? this.key : key as String,
    family: identical(family, _undefined) ? this.family : family as String,
    label: identical(label, _undefined) ? this.label : label as String?,
    iconKey: identical(iconKey, _undefined)
        ? this.iconKey
        : iconKey as String?,
    capabilities: identical(capabilities, _undefined)
        ? this.capabilities
        : capabilities as Set<String>,
    allowedParentKinds: identical(allowedParentKinds, _undefined)
        ? this.allowedParentKinds
        : allowedParentKinds as Set<String>,
    allowedChildKinds: identical(allowedChildKinds, _undefined)
        ? this.allowedChildKinds
        : allowedChildKinds as Set<String>,
    allowedVocabularyKeys: identical(allowedVocabularyKeys, _undefined)
        ? this.allowedVocabularyKeys
        : allowedVocabularyKeys as Set<String>,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyKindSpec &&
          key == other.key &&
          family == other.family &&
          label == other.label &&
          iconKey == other.iconKey &&
          zStringSetEquals(capabilities, other.capabilities) &&
          zStringSetEquals(allowedParentKinds, other.allowedParentKinds) &&
          zStringSetEquals(allowedChildKinds, other.allowedChildKinds) &&
          zStringSetEquals(
            allowedVocabularyKeys,
            other.allowedVocabularyKeys,
          );

  @override
  int get hashCode => Object.hash(
    key,
    family,
    label,
    iconKey,
    zStringSetHash(capabilities),
    zStringSetHash(allowedParentKinds),
    zStringSetHash(allowedChildKinds),
    zStringSetHash(allowedVocabularyKeys),
  );

  @override
  String toString() => 'ZStudyKindSpec($family/$key)';
}

/// Règle de contenance entre deux types, **de famille quelconque**.
///
/// Là où [ZStudyKindSpec.allowedChildKinds] décrit ce qu'un type accepte dans
/// son propre registre, une règle de contenance relie deux registres — un
/// groupe placé sous une unité d'organisation, par exemple.
///
/// Une chaîne vide vaut **joker** : `parentKind: ''` signifie « sous n'importe
/// quel parent ». Les règles sont des **permissions** : dès qu'une ontologie
/// mentionne un type d'enfant dans au moins une règle, ce type ne peut plus
/// être placé que là où une de ces règles l'autorise.
class ZStudyContainmentRule {
  /// Construit une règle de contenance.
  const ZStudyContainmentRule({
    this.parentKind = '',
    this.childKind = '',
    this.maxDepth,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyContainmentRule.fromMap(Map<String, dynamic> map) =>
      ZStudyContainmentRule(
        parentKind: zJsonString(map['parent_kind']),
        childKind: zJsonString(map['child_kind']),
        maxDepth: zJsonIntOrNull(map['max_depth']),
      );

  /// Type du parent autorisé ; `''` = n'importe lequel.
  final String parentKind;

  /// Type de l'enfant concerné ; `''` = n'importe lequel.
  final String childKind;

  /// Profondeur maximale autorisée pour l'enfant (`0` = racine seulement),
  /// `null` = non bornée.
  final int? maxDepth;

  /// `true` si la règle concerne un enfant de type [kind].
  bool coversChild(String kind) => childKind.isEmpty || childKind == kind;

  /// `true` si la règle autorise un parent de type [kind].
  bool allowsParent(String kind) => parentKind.isEmpty || parentKind == kind;

  /// Sérialise vers la map persistée ; une valeur absente n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'parent_kind': parentKind,
    'child_kind': childKind,
    if (maxDepth != null) 'max_depth': maxDepth,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyContainmentRule &&
          parentKind == other.parentKind &&
          childKind == other.childKind &&
          maxDepth == other.maxDepth;

  @override
  int get hashCode => Object.hash(parentKind, childKind, maxDepth);
}

/// Préférences d'affichage déclarées par l'ontologie.
///
/// Données **pour l'hôte** : le noyau les transporte et ne s'en sert jamais
/// pour décider quoi que ce soit.
class ZStudyDisplayRules {
  /// Construit des préférences d'affichage.
  const ZStudyDisplayRules({
    this.kindOrder = const <String>[],
    this.hiddenKinds = const <String>{},
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyDisplayRules.fromMap(Map<String, dynamic> map) =>
      ZStudyDisplayRules(
        kindOrder: zJsonStringList(map['kind_order']) ?? const <String>[],
        hiddenKinds: zStudyDecodeStringSet(map['hidden_kinds']),
      );

  /// Ordre d'affichage souhaité des types, défaut `const []`.
  final List<String> kindOrder;

  /// Types à masquer par défaut, défaut `const {}`.
  final Set<String> hiddenKinds;

  /// Sérialise vers la map persistée ; une collection vide n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    if (kindOrder.isNotEmpty) 'kind_order': List<String>.of(kindOrder),
    if (hiddenKinds.isNotEmpty)
      'hidden_kinds': hiddenKinds.toList(growable: false),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyDisplayRules &&
          zStringListEquals(kindOrder, other.kindOrder) &&
          zStringSetEquals(hiddenKinds, other.hiddenKinds);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(kindOrder), zStringSetHash(hiddenKinds));
}
