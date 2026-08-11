/// `ZSessionConfigKey` — clé de family Riverpod à ÉGALITÉ PROFONDE possédée
/// par le binding (invariant AD-24).
///
/// ## Pourquoi ici et pas au kernel
///
/// `ZStudySessionConfig` (`zcrud_study_kernel`) porte DÉJÀ un `operator ==`/
/// `hashCode` par valeur profonde — forme persistable unique, round-trip
/// invariant AD-10. Rien à changer côté kernel. L'invariant AD-24 exige
/// néanmoins que le contrat d'égalité utilisé comme clé de family Riverpod
/// (contrat de *caching*) vive dans le BINDING, jamais dans le kernel/cœur :
/// - (a) sinon le kernel deviendrait garant d'un contrat Riverpod (couplage
///   inverse interdit — le domaine ne connaît pas Riverpod, invariant AD-15) ;
/// - (b) la garantie « pas de rebuild si la valeur profonde est inchangée »
///   (objectif produit n°1) doit être **prouvée localement** dans
///   `zcrud_riverpod`, indépendamment de ce que le kernel décide de son propre
///   `==`.
///
/// [ZSessionConfigKey] **enveloppe** une [ZStudySessionConfig] et **réimplémente
/// sa propre égalité profonde par VALEUR sur TOUS les champs** de la config
/// (`mode`, `folderId`, `tagIds` profond, `types` profond, `count`, `extension`,
/// `extra` via [zJsonEquals]). Les family(ies) study sont clées par
/// [ZSessionConfigKey], **jamais** par `ZStudySessionConfig` nu — ainsi le
/// dedup/no-rebuild vit et se prouve dans le binding.
///
/// Il **réutilise** les primitives de comparaison du cœur ([zJsonEquals]/
/// [zJsonHash]) — il ne duplique pas la *normalisation* de `extra` (portée par
/// l'accesseur `ZStudySessionConfig.extra`), seulement la *responsabilité de
/// clé*.
///
/// > **Note de test** : l'égalité DOIT être prouvée en variant **CHAQUE
/// > champ un à un**, jamais « tous à la fois » (qui ne teste que la
/// > présence de `==`, pas la contribution de chaque champ).
library;

import 'package:zcrud_core/zcrud_core.dart' show zJsonEquals, zJsonHash;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Clé de family Riverpod à égalité profonde par valeur, enveloppant une
/// [ZStudySessionConfig] (AD-24 — l'égalité de clé vit au binding).
class ZSessionConfigKey {
  /// Construit la clé autour d'une [config].
  const ZSessionConfigKey(this.config);

  /// Config source enveloppée (forme persistable unique du kernel, inchangée).
  final ZStudySessionConfig config;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ZSessionConfigKey) return false;
    final a = config;
    final b = other.config;
    // Égalité PROFONDE par VALEUR sur les 7 champs (varier chaque champ un à
    // un dans le test). `tagIds`/`types` : listes profondes ; `extra` : JSON
    // imbriqué → [zJsonEquals] (jamais l'égalité d'identité d'une Map/List).
    return a.mode == b.mode &&
        a.folderId == b.folderId &&
        zJsonEquals(a.tagIds, b.tagIds) &&
        zJsonEquals(a.types, b.types) &&
        a.count == b.count &&
        a.extension == b.extension &&
        zJsonEquals(a.extra, b.extra);
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        config.mode,
        config.folderId,
        zJsonHash(config.tagIds),
        zJsonHash(config.types),
        config.count,
        config.extension,
        zJsonHash(config.extra),
      ]);
}
