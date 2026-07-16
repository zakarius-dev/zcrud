/// Extension de partage concrète `ZStudySharingExtension` (Story ES-9.4, AC1/AC3/AC5).
///
/// origine: le slot **opt-in** `ZStudyFolder.extension` (`ZExtension?`, kernel).
/// Cette sous-classe **CONCRÈTE** porte les champs de **contrôle PARTAGEABLES**
/// d'un dossier — `isPublic`, `joinableWithLink`, `coOwnersCanInvite`,
/// `shareLinkId` — **jamais** d'état personnel (SRS / ordre / lecture, AC3).
///
/// ## `implements ZExtension` — JAMAIS `extends`, JAMAIS `sealed` (AD-4)
///
/// Calque le précédent `ZNoteAudio` (premier `ZExtension` concret du repo) :
/// `formatVersion` propre, `toJson` incluant `format_version`, `fromJsonSafe`
/// bâti sur [ZExtension.guard] (version non gérée / corrompu ⇒ `null`, **jamais**
/// de throw, AD-10). L'app injecte
/// `ZStudyFolder.fromMap(map, extensionParser: ZStudySharingExtension.fromJsonSafe)`.
///
/// ## Optionalité (AC2, AD-26)
///
/// Le partage est **activé** UNIQUEMENT si l'app injecte ce parser. Une app qui ne
/// l'active pas décode le dossier normalement (`extension == null`) : ni entités,
/// ni backend de partage tirés. Le slot kernel est **RÉUTILISÉ** (R21), jamais
/// re-déclaré.
///
/// ## 🔴 Dette sécu lex — séparation structurelle (AC5 pt.1)
///
/// Les champs de contrôle **effectifs** (propriété, rôle, révocation, listing)
/// vivent dans les **entités owner-contrôlées** ([ZShareLink]/[ZStudyMembership]/
/// [ZPublicStudyFolder]), protégées par [ZStudySharingAcl]. Cette extension ne
/// porte que les **préférences de partage** du dossier ; le bloc V2c **inerte** de
/// `ZStudyFolder` n'est **PAS** réactivé et ne route **aucune** décision d'autorité.
library;

import 'package:zcrud_core/domain.dart';

/// Version du sous-schéma de [ZStudySharingExtension] (indépendante du parent,
/// AD-4 pt.1). Une version **non gérée** fait rendre `null` à [fromJsonSafe].
const int kZStudySharingFormatVersion = 1;

/// Clé de la version dans la map `extension`.
const String kZStudySharingFormatVersionKey = 'format_version';

/// Extension typée de **partage** d'un dossier — **opt-in, versionnée** (AD-4).
class ZStudySharingExtension implements ZExtension {
  /// Construit une extension de partage (tous les champs ont un défaut sûr).
  const ZStudySharingExtension({
    this.isPublic = false,
    this.joinableWithLink = false,
    this.coOwnersCanInvite = false,
    this.shareLinkId,
  });

  /// Dossier listé en galerie publique (préférence partageable).
  final bool isPublic;

  /// Rejoignable via un lien de partage.
  final bool joinableWithLink;

  /// Les co-owners peuvent inviter d'autres membres.
  final bool coOwnersCanInvite;

  /// Référence opaque vers le [ZShareLink] actif, ou `null`.
  final String? shareLinkId;

  @override
  int get formatVersion => kZStudySharingFormatVersion;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        kZStudySharingFormatVersionKey: formatVersion,
        'is_public': isPublic,
        'joinable_with_link': joinableWithLink,
        'co_owners_can_invite': coOwnersCanInvite,
        'share_link_id': shareLinkId,
      };

  /// Reconstruit **défensivement** depuis sa map JSON, ou `null` (AD-4/AD-10) —
  /// **ne throw JAMAIS**.
  ///
  /// Rend `null` si [json] est `null`, non-map, de `format_version` **absente**
  /// ou **non gérée**. Un champ non-`bool` retombe sur `false`. Bâtie sur
  /// [ZExtension.guard] : toute exception imprévue retombe sur `null`, le parent
  /// (dossier) survivant toujours.
  static ZStudySharingExtension? fromJsonSafe(Object? json) =>
      ZExtension.guard<ZStudySharingExtension?>(() {
        final map = _asStringMap(json);
        if (map == null) return null;
        if (map[kZStudySharingFormatVersionKey] !=
            kZStudySharingFormatVersion) {
          return null;
        }
        return ZStudySharingExtension(
          isPublic: map['is_public'] is bool ? map['is_public'] as bool : false,
          joinableWithLink: map['joinable_with_link'] is bool
              ? map['joinable_with_link'] as bool
              : false,
          coOwnersCanInvite: map['co_owners_can_invite'] is bool
              ? map['co_owners_can_invite'] as bool
              : false,
          shareLinkId:
              map['share_link_id'] is String ? map['share_link_id'] as String : null,
        );
      });

  static Map<String, dynamic>? _asStringMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) {
      return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
    }
    return null;
  }

  /// Copie modifiée (champ à champ).
  ZStudySharingExtension copyWith({
    bool? isPublic,
    bool? joinableWithLink,
    bool? coOwnersCanInvite,
    Object? shareLinkId = _unset,
  }) =>
      ZStudySharingExtension(
        isPublic: isPublic ?? this.isPublic,
        joinableWithLink: joinableWithLink ?? this.joinableWithLink,
        coOwnersCanInvite: coOwnersCanInvite ?? this.coOwnersCanInvite,
        shareLinkId: identical(shareLinkId, _unset)
            ? this.shareLinkId
            : shareLinkId as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySharingExtension &&
          isPublic == other.isPublic &&
          joinableWithLink == other.joinableWithLink &&
          coOwnersCanInvite == other.coOwnersCanInvite &&
          shareLinkId == other.shareLinkId;

  @override
  int get hashCode =>
      Object.hash(isPublic, joinableWithLink, coOwnersCanInvite, shareLinkId);

  @override
  String toString() => 'ZStudySharingExtension(isPublic: $isPublic, '
      'joinableWithLink: $joinableWithLink, '
      'coOwnersCanInvite: $coOwnersCanInvite, shareLinkId: $shareLinkId)';
}

/// Sentinelle interne de [ZStudySharingExtension.copyWith].
const Object _unset = Object();
