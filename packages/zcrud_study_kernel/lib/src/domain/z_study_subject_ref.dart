/// Référence d'affichage légère vers une matière gérée par l'application.
///
/// Le noyau conserve uniquement l'identifiant opaque et des métadonnées
/// d'affichage optionnelles. La résolution de l'identifiant et la définition
/// de la matière restent à la charge de l'application.
library;

/// Valeur immuable représentant une matière sans introduire son entité.
class ZStudySubjectRef {
  /// Construit une référence avec son identifiant opaque obligatoire.
  const ZStudySubjectRef({required this.id, this.label, this.colorKey});

  /// Reconstruit une référence depuis une map potentiellement corrompue.
  ///
  /// Un identifiant absent ou d'un type inattendu devient une chaîne vide ;
  /// les métadonnées d'affichage invalides deviennent `null`.
  factory ZStudySubjectRef.fromMap(Map<String, dynamic> map) =>
      ZStudySubjectRef(
        id: _asString(map['id']) ?? '',
        label: _asString(map['label']),
        colorKey: _asString(map['color_key']),
      );

  /// Identifiant opaque résolu par l'application.
  final String id;

  /// Libellé d'affichage, ou `null` s'il n'est pas disponible.
  final String? label;

  /// Clé de couleur résolue par l'application, ou `null` si elle est absente.
  final String? colorKey;

  /// Sérialise la référence en omettant les métadonnées absentes.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    if (label != null) 'label': label,
    if (colorKey != null) 'color_key': colorKey,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySubjectRef &&
          id == other.id &&
          label == other.label &&
          colorKey == other.colorKey;

  @override
  int get hashCode => Object.hash(id, label, colorKey);
}

String? _asString(Object? value) => value is String ? value : null;
