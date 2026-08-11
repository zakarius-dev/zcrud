/// Pièce jointe d'un message — `ZChatAttachment`.
///
/// **Modèle seul** : le téléversement, la prévisualisation et le cycle de vie
/// des pièces jointes sont du ressort de la couche de présentation d'un
/// satellite, pas de ce noyau de données.
library;

import 'package:zcrud_core/domain.dart';

/// Une pièce jointe (identité + URL + type MIME + nom de fichier), immuable.
class ZChatAttachment {
  /// Construit une pièce jointe (immuable, `const`).
  const ZChatAttachment({
    this.id = '',
    this.url = '',
    this.mimeType = '',
    this.fileName = '',
  });

  /// Identifiant opaque de la pièce jointe.
  final String id;

  /// URL de récupération.
  final String url;

  /// Type MIME déclaré (clé persistée `mime_type`).
  final String mimeType;

  /// Nom de fichier lisible (clé persistée `file_name`).
  final String fileName;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  static ZChatAttachment? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatAttachment(
      id: zJsonString(map['id']),
      url: zJsonString(map['url']),
      mimeType: zJsonString(map['mime_type']),
      fileName: zJsonString(map['file_name']),
    );
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'url': url,
        'mime_type': mimeType,
        'file_name': fileName,
      };

  /// Copie modifiée (champs omis conservés).
  ZChatAttachment copyWith({
    String? id,
    String? url,
    String? mimeType,
    String? fileName,
  }) =>
      ZChatAttachment(
        id: id ?? this.id,
        url: url ?? this.url,
        mimeType: mimeType ?? this.mimeType,
        fileName: fileName ?? this.fileName,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatAttachment &&
          id == other.id &&
          url == other.url &&
          mimeType == other.mimeType &&
          fileName == other.fileName;

  @override
  int get hashCode => Object.hash(id, url, mimeType, fileName);

  @override
  String toString() => 'ZChatAttachment(id: $id, fileName: $fileName)';
}
