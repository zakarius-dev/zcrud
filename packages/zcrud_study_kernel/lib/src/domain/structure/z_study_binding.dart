/// `ZStudyBinding` — rattachement daté d'une source à une cible de structure.
///
/// C'est le **protocole de liaison unique** du noyau : un dossier rattaché à
/// un cours, une ressource rattachée à un groupe, un artefact rattaché à une
/// période s'écrivent tous de la même façon. Généraliser la liaison — pas les
/// concepts — est ce qui permet à des entités aux responsabilités distinctes
/// de partager une seule mécanique de portée.
///
/// **[propagation] décide de l'étendue** : `exact` (défaut) ne vaut que pour
/// la cible désignée ; `descendants` / `ancestors` suivent l'arbre de la
/// cible ; `members` suit les participants ; `offerings` suit les offres ;
/// `none` désactive le rattachement sans le supprimer. Une valeur inconnue est
/// **conservée** et traitée comme n'ouvrant aucune propagation — jamais
/// rejetée, jamais réécrite (registre ouvert, invariant AD-4).
///
/// **[validFrom] / [validTo] sont facultatives et non contraintes** : le noyau
/// ne vérifie pas que l'une précède l'autre et n'en dérive aucun calendrier.
/// [isActiveAt] les lit comme un intervalle semi-ouvert `[validFrom, validTo)`
/// — une borne absente signifie « non bornée de ce côté ».
///
/// **[snapshot]** est l'instantané d'affichage de la cible, potentiellement
/// périmé (voir `ZStudyRef`) ; [targetRef] reste la vérité.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_constants.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Rattachement daté d'une source à une cible.
class ZStudyBinding {
  /// Construit un rattachement. [snapshot] vaut [targetRef] si omis.
  const ZStudyBinding({
    required this.sourceRef,
    required this.targetRef,
    this.role,
    this.propagation = kZStudyPropagationExact,
    this.validFrom,
    this.validTo,
    // Les slots bruts restent privés : ce sont les accesseurs qui portent la
    // garde (normalisation d'`extra`, repli de l'instantané sur la cible).
    ZStudyRef? snapshot,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _snapshot = snapshot,
       // ignore: prefer_initializing_formals
       _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Références absentes ⇒ référence vide (`type: ''`, `id: ''`) ;
  /// [propagation] absente ou illisible ⇒ `exact` ; dates illisibles ⇒ `null`.
  /// Ne lève jamais.
  factory ZStudyBinding.fromMap(Map<String, dynamic> map) {
    final target = _refOf(map['target_ref']);
    return ZStudyBinding(
      sourceRef: _refOf(map['source_ref']),
      targetRef: target,
      role: zJsonStringOrNull(map['role']),
      propagation: zJsonString(map['propagation'], kZStudyPropagationExact),
      validFrom: zJsonDate(map['valid_from']),
      validTo: zJsonDate(map['valid_to']),
      snapshot: _refOrNull(map['snapshot']),
      extra: _sanitizeExtra(map),
    );
  }

  /// Élément rattaché (le dossier, la ressource, l'artefact…).
  final ZStudyRef sourceRef;

  /// Élément de structure auquel la source est rattachée.
  final ZStudyRef targetRef;

  /// Rôle du rattachement — chaîne opaque, `null` si non qualifié.
  final String? role;

  /// Étendue du rattachement — chaîne opaque, défaut `exact`.
  ///
  /// Voir les constantes `kZStudyPropagation…`. Une valeur inconnue n'ouvre
  /// aucune propagation et n'est jamais rejetée.
  final String propagation;

  /// Début de validité inclus, `null` si non borné.
  final DateTime? validFrom;

  /// Fin de validité exclue, `null` si non bornée.
  final DateTime? validTo;

  final ZStudyRef? _snapshot;

  final Map<String, dynamic> _extra;

  /// Instantané d'affichage de la cible ; vaut [targetRef] si aucun n'a été
  /// capturé. Peut être périmé — [targetRef] reste la vérité.
  ZStudyRef get snapshot => _snapshot ?? targetRef;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si [propagation] est un mode que le noyau interprète.
  bool get hasKnownPropagation => kZStudyPropagations.contains(propagation);

  /// `true` si le rattachement est valide à [instant], sur l'intervalle
  /// semi-ouvert `[validFrom, validTo)`.
  ///
  /// Une borne absente ne restreint rien de ce côté. `propagation == 'none'`
  /// **ne** rend pas le rattachement inactif : la propagation décrit l'étendue,
  /// la validité décrit le temps — deux axes indépendants.
  bool isActiveAt(DateTime instant) {
    if (validFrom != null && instant.isBefore(validFrom!)) return false;
    if (validTo != null && !instant.isBefore(validTo!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée ; aucune valeur absente n'écrit de clé.
  ///
  /// L'instantané n'est émis que s'il a été explicitement capturé — un
  /// rattachement construit sans instantané reste, au round-trip, un
  /// rattachement sans instantané.
  Map<String, dynamic> toMap() => <String, dynamic>{
    ...extra,
    'source_ref': sourceRef.toMap(),
    'target_ref': targetRef.toMap(),
    if (role != null) 'role': role,
    'propagation': propagation,
    if (validFrom != null) 'valid_from': validFrom!.toIso8601String(),
    if (validTo != null) 'valid_to': validTo!.toIso8601String(),
    if (_snapshot != null) 'snapshot': _snapshot.toMap(),
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null` — y compris pour l'instantané, qui redevient [targetRef]).
  ZStudyBinding copyWith({
    Object? sourceRef = _undefined,
    Object? targetRef = _undefined,
    Object? role = _undefined,
    Object? propagation = _undefined,
    Object? validFrom = _undefined,
    Object? validTo = _undefined,
    Object? snapshot = _undefined,
    Object? extra = _undefined,
  }) => ZStudyBinding(
    sourceRef: identical(sourceRef, _undefined)
        ? this.sourceRef
        : sourceRef as ZStudyRef,
    targetRef: identical(targetRef, _undefined)
        ? this.targetRef
        : targetRef as ZStudyRef,
    role: identical(role, _undefined) ? this.role : role as String?,
    propagation: identical(propagation, _undefined)
        ? this.propagation
        : propagation as String,
    validFrom: identical(validFrom, _undefined)
        ? this.validFrom
        : validFrom as DateTime?,
    validTo: identical(validTo, _undefined)
        ? this.validTo
        : validTo as DateTime?,
    snapshot: identical(snapshot, _undefined)
        ? _snapshot
        : snapshot as ZStudyRef?,
    extra: identical(extra, _undefined)
        ? this.extra
        : _sanitizeExtra(extra as Map<String, dynamic>),
  );

  static ZStudyRef _refOf(Object? raw) =>
      _refOrNull(raw) ?? const ZStudyRef(type: '', id: '');

  static ZStudyRef? _refOrNull(Object? raw) {
    final map = zStudyAsJsonMap(raw);
    return map == null ? null : ZStudyRef.fromMap(map);
  }

  static final Set<String> _reservedKeys = <String>{
    'source_ref',
    'target_ref',
    'role',
    'propagation',
    'valid_from',
    'valid_to',
    'snapshot',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyBinding &&
          sourceRef == other.sourceRef &&
          targetRef == other.targetRef &&
          role == other.role &&
          propagation == other.propagation &&
          validFrom == other.validFrom &&
          validTo == other.validTo &&
          _snapshot == other._snapshot &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    sourceRef,
    targetRef,
    role,
    propagation,
    validFrom,
    validTo,
    _snapshot,
    zJsonHash(extra),
  );
}

/// Décode une liste de rattachements (repli `const []`, éléments illisibles
/// ignorés).
List<ZStudyBinding> zStudyDecodeBindings(Object? raw) =>
    zStudyDecodeList<ZStudyBinding>(raw, ZStudyBinding.fromMap);
