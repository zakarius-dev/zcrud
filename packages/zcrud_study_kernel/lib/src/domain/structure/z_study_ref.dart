/// `ZStudyRef` — référence universelle, et instantané d'affichage, vers
/// n'importe quel élément de structure d'étude.
///
/// Une référence porte l'identité ([type] + [id]) et un **instantané**
/// facultatif de ce qu'il faut pour afficher la cible sans la relire
/// ([label], [code], [kind]). L'instantané peut être périmé : c'est un confort
/// d'affichage, jamais une source de vérité — la vérité est l'enregistrement
/// désigné par [id].
///
/// **[type] et [kind] sont des chaînes opaques.** Les constantes
/// `kZStudyRefType…` couvrent les types que le noyau nomme lui-même ; un type
/// hors de cette liste est parfaitement valide, traverse la (dé)sérialisation
/// intact, et n'est interprété par aucune primitive.
///
/// **`ZStudyScopeRef`** n'est pas une classe distincte : c'est le nom de la
/// restriction d'une `ZStudyRef` dont le [type] appartient à
/// `kZStudyScopableRefTypes`. Un filtre portant une portée d'un autre type
/// n'est jamais rejeté ; il ne bénéficie d'aucune résolution fournie.
///
/// **Égalité** structurelle sur tous les champs, [extra] compris — deux
/// références de même identité mais d'instantanés différents ne sont pas
/// égales. Comparer les identités seules se fait par [sameTarget].
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_constants.dart';
import 'z_study_json.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Référence universelle vers un élément de structure d'étude.
class ZStudyRef {
  /// Construit une référence. Seuls [type] et [id] sont requis.
  const ZStudyRef({
    required this.type,
    required this.id,
    this.label,
    this.code,
    this.kind,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// [type] et [id] absents ou d'un type inattendu retombent sur `''`.
  ///
  /// Les métadonnées d'instantané distinguent **absence** et **vide** : une
  /// clé absente rend `null` (non capturée), une clé présente valant `''` rend
  /// `''` (capturée, et vide). [toMap] et cette fabrique sont donc exactement
  /// inverses l'une de l'autre. Ne lève jamais.
  factory ZStudyRef.fromMap(Map<String, dynamic> map) => ZStudyRef(
    type: zJsonString(map['type']),
    id: zJsonString(map['id']),
    label: _metadataOrNull(map, 'label'),
    code: _metadataOrNull(map, 'code'),
    kind: _metadataOrNull(map, 'kind'),
    extra: _sanitizeExtra(map),
  );

  /// Type de la cible — chaîne opaque (`kZStudyRefType…` pour les types que le
  /// noyau nomme), défaut `''`.
  final String type;

  /// Identifiant opaque de la cible, défaut `''`. Jamais un code métier.
  final String id;

  /// Libellé instantané de la cible, `null` si non capturé.
  final String? label;

  /// Code métier instantané de la cible, `null` si non capturé.
  ///
  /// Un code n'est **jamais** une identité : deux cibles peuvent porter le
  /// même code dans deux organisations, et un code peut changer.
  final String? code;

  /// `kind` instantané de la cible — chaîne opaque, `null` si non capturé.
  final String? kind;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` ; l'accesseur
  /// normalise et ne rend jamais une clé réservée.
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si la référence désigne la **même cible** que [other] — identité
  /// seule ([type] + [id]), instantané ignoré.
  bool sameTarget(ZStudyRef other) => type == other.type && id == other.id;

  /// `true` si le [type] appartient aux types scopables nommés par le noyau.
  ///
  /// Faux ne signifie pas invalide : voir la documentation de bibliothèque.
  bool get isScopable => kZStudyScopableRefTypes.contains(type);

  /// Sérialise vers la map persistée ; aucune métadonnée absente n'est émise.
  Map<String, dynamic> toMap() => <String, dynamic>{
    ...extra,
    'type': type,
    'id': id,
    if (label != null) 'label': label,
    if (code != null) 'code': code,
    if (kind != null) 'kind': kind,
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyRef copyWith({
    Object? type = _undefined,
    Object? id = _undefined,
    Object? label = _undefined,
    Object? code = _undefined,
    Object? kind = _undefined,
    Object? extra = _undefined,
  }) => ZStudyRef(
    type: identical(type, _undefined) ? this.type : type as String,
    id: identical(id, _undefined) ? this.id : id as String,
    label: identical(label, _undefined) ? this.label : label as String?,
    code: identical(code, _undefined) ? this.code : code as String?,
    kind: identical(kind, _undefined) ? this.kind : kind as String?,
    extra: identical(extra, _undefined)
        ? this.extra
        : _sanitizeExtra(extra as Map<String, dynamic>),
  );

  /// Lit une métadonnée d'instantané en distinguant **absence** et **vide**.
  ///
  /// Une clé absente vaut `null` (non capturée) ; une clé présente valant `''`
  /// vaut `''` (capturée, et vide). Confondre les deux ferait qu'une référence
  /// construite sur une cible au libellé vide ne se relirait pas identique à
  /// elle-même — [toMap] et [ZStudyRef.fromMap] cesseraient d'être inverses.
  static String? _metadataOrNull(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) return null;
    final value = map[key];
    return value is String ? value : null;
  }

  static final Set<String> _reservedKeys = <String>{
    'type',
    'id',
    'label',
    'code',
    'kind',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyRef &&
          type == other.type &&
          id == other.id &&
          label == other.label &&
          code == other.code &&
          kind == other.kind &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(type, id, label, code, kind, zJsonHash(extra));

  @override
  String toString() => 'ZStudyRef($type:$id)';
}

/// Décode une liste de références (repli `const []`, éléments illisibles
/// ignorés).
List<ZStudyRef> zStudyDecodeRefs(Object? raw) =>
    zStudyDecodeList<ZStudyRef>(raw, ZStudyRef.fromMap);
