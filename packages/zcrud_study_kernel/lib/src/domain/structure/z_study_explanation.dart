/// Entité `ZStudyExplanation` — un texte explicatif attaché à un dossier.
///
/// Une explication est **du contenu produit à côté** du dossier, pas une
/// propriété du dossier. La séparer permet d'en avoir plusieurs, de styles ou
/// de longueurs différents, sans jamais réécrire le dossier ni faire grossir sa
/// map — et de n'en charger aucune quand on ne fait que lister des dossiers.
///
/// [style] et [operation] sont des chaînes **opaques** : la première dit sous
/// quelle forme le texte est rendu, la seconde par quel traitement il a été
/// obtenu. Le noyau n'en interprète aucune ; ce sont des étiquettes que l'hôte
/// pose et relit.
///
/// [relatedTopics] porte des identifiants de thèmes **opaques**, non résolus :
/// le noyau ne vérifie pas qu'ils existent, et une explication dont les thèmes
/// ont disparu reste lisible.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';

part 'z_study_explanation.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyExplanationExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Explication immuable.
@ZcrudModel(kind: 'study_explanation', fieldRename: ZFieldRename.snake)
class ZStudyExplanation extends ZEntity with ZExtensible {
  /// Construit une explication.
  const ZStudyExplanation({
    this.id,
    this.folderId = '',
    this.content = '',
    this.style,
    this.operation,
    this.relatedTopics = const <String>[],
    this.createdAt,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// `content` absent ⇒ `''` ; `related_topics` non-liste ⇒ `const []` ; date
  /// illisible ⇒ `null`. Ne lève jamais.
  factory ZStudyExplanation.fromMap(
    Map<String, dynamic> map, {
    ZStudyExplanationExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyExplanationFromMap(map);
    return ZStudyExplanation(
      id: base.id,
      folderId: base.folderId,
      content: base.content,
      style: base.style,
      operation: base.operation,
      relatedTopics: base.relatedTopics,
      createdAt: base.createdAt,
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Dossier auquel l'explication est attachée, défaut `''`.
  @ZcrudField()
  final String folderId;

  /// Texte de l'explication, défaut `''`.
  @ZcrudField()
  final String content;

  /// Forme de rendu — chaîne opaque, `null` si non qualifiée.
  @ZcrudField()
  final String? style;

  /// Traitement dont l'explication est issue — chaîne opaque, `null` si non
  /// qualifié.
  @ZcrudField()
  final String? operation;

  /// Thèmes couverts (identifiants opaques non résolus), défaut `const []`.
  @ZcrudField()
  final List<String> relatedTopics;

  /// Date de création (ISO-8601), `null` si éphémère.
  @ZcrudField()
  final DateTime? createdAt;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyExplanationZcrud(this).toMap()),
    };
    if (extension != null) map['extension'] = extension!.toJson();
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyExplanation copyWith({
    Object? id = _$undefined,
    Object? folderId = _$undefined,
    Object? content = _$undefined,
    Object? style = _$undefined,
    Object? operation = _$undefined,
    Object? relatedTopics = _$undefined,
    Object? createdAt = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyExplanation(
    id: identical(id, _$undefined) ? this.id : id as String?,
    folderId: identical(folderId, _$undefined)
        ? this.folderId
        : folderId as String,
    content: identical(content, _$undefined) ? this.content : content as String,
    style: identical(style, _$undefined) ? this.style : style as String?,
    operation: identical(operation, _$undefined)
        ? this.operation
        : operation as String?,
    relatedTopics: identical(relatedTopics, _$undefined)
        ? this.relatedTopics
        : relatedTopics as List<String>,
    createdAt: identical(createdAt, _$undefined)
        ? this.createdAt
        : createdAt as DateTime?,
    extension: identical(extension, _$undefined)
        ? this.extension
        : extension as ZExtension?,
    extra: identical(extra, _$undefined)
        ? this.extra
        : _sanitizeExtra(extra as Map<String, dynamic>),
  );

  /// Clés persistées réservées (schéma généré + canal `extension` +
  /// `ZSyncMeta`).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyExplanationFieldSpecs) spec.name,
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyExplanation &&
          id == other.id &&
          folderId == other.folderId &&
          content == other.content &&
          style == other.style &&
          operation == other.operation &&
          zStringListEquals(relatedTopics, other.relatedTopics) &&
          createdAt == other.createdAt &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    folderId,
    content,
    style,
    operation,
    Object.hashAll(relatedTopics),
    createdAt,
    extension,
    zJsonHash(extra),
  ]);
}
