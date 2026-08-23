/// État d'un artefact — `ZChatArtifactPhase`, `ZChatArtifactExistence`,
/// `ZChatArtifactStatus` — et le port de lecture `ZChatArtifactStatePort`.
///
/// ## Trois états, jamais deux
///
/// Un artefact est **absent**, **en cours**, ou **présent** (avec, le cas
/// échéant, un compte). Un booléen « existe / n'existe pas » écraserait le
/// temps du milieu — celui pendant lequel l'utilisateur attend et a le plus
/// besoin d'un signal.
///
/// ## L'occupation l'emporte sur l'existence
///
/// L'**occupation** (une génération en vol) est connue du seul contrôleur ;
/// l'**existence** (présent ? combien ?) est lue chez l'hôte via
/// [ZChatArtifactStatePort]. La règle de composition est une fonction pure,
/// [ZChatArtifactStatus.resolve] : tant qu'une génération est en vol,
/// l'état rendu est **en cours**, quoi que dise le stockage — sinon une
/// régénération afficherait « présent » pendant tout le temps où l'ancien
/// contenu est en train d'être remplacé.
library;

import 'package:zcrud_core/domain.dart';

/// Phase d'un artefact.
enum ZChatArtifactPhase {
  /// Aucun contenu, aucune génération en vol.
  absent,

  /// Une génération est en vol.
  inProgress,

  /// Un contenu existe.
  present;

  /// Valeur persistée (camelCase).
  String get jsonValue => name;

  /// Parse **total** (repli [absent]) — ne lève jamais.
  static ZChatArtifactPhase fromJson(Object? raw) {
    switch (raw) {
      case 'inProgress':
        return ZChatArtifactPhase.inProgress;
      case 'present':
        return ZChatArtifactPhase.present;
      default:
        return ZChatArtifactPhase.absent;
    }
  }
}

/// Ce que le stockage **sait** d'un artefact : présent ? combien ?
///
/// Ne connaît pas l'occupation — c'est voulu. Un compte négatif est ramené à
/// zéro.
class ZChatArtifactExistence {
  /// Construit un relevé d'existence.
  const ZChatArtifactExistence({required this.present, int count = 0})
      : count = count < 0 ? 0 : count;

  /// Absent.
  static const ZChatArtifactExistence absent =
      ZChatArtifactExistence(present: false);

  /// Présent, avec un compte optionnel.
  const ZChatArtifactExistence.found({int count = 0})
      : this(present: true, count: count);

  /// Présent si [count] est strictement positif, absent sinon — la lecture
  /// d'un artefact **compté** (nœuds d'une carte, cartes d'un paquet).
  factory ZChatArtifactExistence.counted(int count) =>
      ZChatArtifactExistence(present: count > 0, count: count);

  /// `true` si un contenu existe.
  final bool present;

  /// Compte porté (`0` si sans objet).
  final int count;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactExistence &&
          present == other.present &&
          count == other.count;

  @override
  int get hashCode => Object.hash(present, count);

  @override
  String toString() => 'ZChatArtifactExistence(present: $present, '
      'count: $count)';
}

/// L'état **dérivé** d'un artefact, tel que le rendu le consomme.
///
/// Value object immuable. Le [count] n'a de sens qu'en phase
/// [ZChatArtifactPhase.present] ; il est `0` dans les deux autres.
class ZChatArtifactStatus {
  const ZChatArtifactStatus._(this.phase, this.count);

  /// Absent.
  static const ZChatArtifactStatus absent =
      ZChatArtifactStatus._(ZChatArtifactPhase.absent, 0);

  /// En cours.
  static const ZChatArtifactStatus inProgress =
      ZChatArtifactStatus._(ZChatArtifactPhase.inProgress, 0);

  /// Présent, avec un compte (`0` si sans objet ; un négatif vaut `0`).
  const ZChatArtifactStatus.present({int count = 0})
      : this._(ZChatArtifactPhase.present, count < 0 ? 0 : count);

  /// **La règle** : l'occupation l'emporte sur l'existence.
  ///
  /// * [busy] ⇒ [inProgress], quel que soit [existence] ;
  /// * sinon [existence] `null` (lecture impossible) ⇒ [absent] — une lecture
  ///   qui échoue ne bloque jamais le rendu (invariant AD-10) ;
  /// * sinon présent ⇒ [present] avec le compte, absent ⇒ [absent].
  static ZChatArtifactStatus resolve({
    required bool busy,
    required ZChatArtifactExistence? existence,
  }) {
    if (busy) return inProgress;
    if (existence == null || !existence.present) return absent;
    return ZChatArtifactStatus.present(count: existence.count);
  }

  /// Même règle que [resolve], sur le résultat d'un port : un `Left` est
  /// traité comme une lecture impossible (⇒ absent, sauf occupation).
  static ZChatArtifactStatus fromResult({
    required bool busy,
    required ZResult<ZChatArtifactExistence> result,
  }) =>
      resolve(
        busy: busy,
        existence: result.fold(
          (ZFailure _) => null,
          (ZChatArtifactExistence e) => e,
        ),
      );

  /// Phase.
  final ZChatArtifactPhase phase;

  /// Compte (`0` hors phase présente).
  final int count;

  /// `true` en phase présente.
  bool get isPresent => phase == ZChatArtifactPhase.present;

  /// `true` en phase en cours.
  bool get isBusy => phase == ZChatArtifactPhase.inProgress;

  /// Le compte à afficher en pastille : `null` si absent, en cours, ou nul —
  /// une pastille « 0 » n'informe de rien.
  int? get badgeCount => isPresent && count > 0 ? count : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactStatus &&
          phase == other.phase &&
          count == other.count;

  @override
  int get hashCode => Object.hash(phase, count);

  @override
  String toString() => 'ZChatArtifactStatus(${phase.name}'
      '${isPresent ? ', count: $count' : ''})';
}

/// Port de lecture de l'**existence** d'un artefact — implémenté par l'hôte.
///
/// Répond, pour un couple `(messageId, artifactKey)` : présent ? combien ?
/// **Rien d'autre** : l'occupation n'est pas de son ressort, et le port ne
/// connaît ni verbe, ni rendu. Chaque clé d'artefact lit **son propre**
/// compte — croiser les comptes donnerait un nombre plausible sur le mauvais
/// bouton, la forme d'erreur que personne ne remarque.
///
/// Invariants AD-5/AD-10 : `Either<ZFailure, ·>`, aucune exception. Un
/// `Left` est rendu **absent** par [ZChatArtifactStatus.fromResult].
abstract interface class ZChatArtifactStatePort {
  /// L'existence de l'artefact [artifactKey] sur le message [messageId].
  Future<ZResult<ZChatArtifactExistence>> existenceOf({
    required String messageId,
    required String artifactKey,
  });
}
