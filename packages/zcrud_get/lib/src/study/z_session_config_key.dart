/// `ZSessionConfigKey` — clé de cache d'instance GetX à ÉGALITÉ PROFONDE possédée
/// par le binding — miroir GetX d'une clé de `family` Riverpod équivalente.
///
/// ## Pourquoi ici et pas au kernel
///
/// `ZStudySessionConfig` (`zcrud_study_kernel`) porte DÉJÀ un `operator ==`/
/// `hashCode` par valeur profonde — **forme persistable unique**, round-trip
/// défensif (invariant AD-10). Rien à changer côté kernel. Le contrat de
/// *caching* du gestionnaire d'état (la clé qui décide si l'instance GetX est
/// réutilisée ou recréée) doit néanmoins **vivre dans le BINDING**, jamais
/// dans le kernel/cœur :
/// - (a) sinon le kernel deviendrait garant d'un contrat GetX (couplage inverse
///   interdit — le domaine ne connaît pas GetX, invariant AD-15) ;
/// - (b) la garantie « pas de recréation d'instance si la valeur profonde est
///   inchangée » doit être **prouvée localement** dans `zcrud_get`,
///   indépendamment de ce que le kernel décide de son propre `==`.
///
/// ## Pourquoi un `tag` (idiome GetX) et pas une `family` (idiome Riverpod)
///
/// Riverpod dédup via `==`/`hashCode` d'une clé de `family`. **GetX N'A PAS de
/// family** : son mécanisme natif de réutilisation d'instance est l'indexation
/// **`Type` + `tag` (String)** du gestionnaire d'instances (`Get.put`/`Get.find`/
/// `Get.isRegistered(tag:)`). Le miroir GetX de la clé de family est donc un
/// **`tag` DÉTERMINISTE** dérivé de l'égalité profonde, tel que
/// **`a == b ⟺ a.tag == b.tag`** : deux configs structurellement égales ⇒ **même
/// `tag`** ⇒ GetX réutilise la **même** instance.
///
/// [ZSessionConfigKey] **enveloppe** une [ZStudySessionConfig] et **réimplémente
/// sa propre égalité profonde par VALEUR sur les 7 champs** (`mode`, `folderId`,
/// `tagIds` profond, `types` profond, `count`, `extension`, `extra` via
/// [zJsonEquals]). Il **réutilise** les primitives de comparaison du cœur
/// ([zJsonEquals]/[zJsonHash]) — il ne duplique pas la *normalisation* de `extra`
/// (portée par l'accesseur `ZStudySessionConfig.extra`), seulement la
/// *responsabilité de clé*.
///
/// > **Note de test** : l'égalité ET le `tag` DOIVENT être prouvés en variant
/// > **CHAQUE champ un à un** (7 cas mono-champ), jamais « tous à la fois ».
/// > Neutraliser la comparaison d'un seul champ dans `==` **ou** l'exclure de
/// > la dérivation du `tag` DOIT faire rougir le cas mono-champ correspondant.
library;

import 'dart:convert';

import 'package:zcrud_core/zcrud_core.dart' show zJsonEquals, zJsonHash;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Clé de cache d'instance GetX à égalité profonde par valeur, enveloppant une
/// [ZStudySessionConfig] (l'égalité de clé, et son `tag` GetX, vivent au
/// binding).
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
    // Égalité PROFONDE par VALEUR sur les 7 champs (varier chaque champ un à un
    // dans le test). `tagIds`/`types` : listes profondes ; `extra` : JSON
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

  /// `tag` GetX DÉTERMINISTE dérivé des **7 champs** — miroir de la clé de
  /// family Riverpod. Garantit **`a == b ⟺ a.tag == b.tag`** : c'est le `tag`
  /// passé à `Get.put`/`Get.find`/`Get.isRegistered` pour indexer l'instance de
  /// sélecteur par `Type` + `tag`.
  ///
  /// Dérivé d'une **canonicalisation stable** des 7 composantes (JSON à clés
  /// récursivement triées) — **jamais** de `hashCode` seul (collisions possibles)
  /// ni d'une composante d'IDENTITÉ (`identityHashCode`, qui casserait la
  /// déduplication). Chaque champ contribue explicitement : exclure un champ
  /// de cette dérivation romprait `a == b ⟺ a.tag == b.tag` et rougirait le
  /// cas mono-champ correspondant.
  String get tag {
    final canonical = <String, Object?>{
      'mode': config.mode.name,
      'folderId': config.folderId,
      'tagIds': config.tagIds,
      'types': config.types,
      'count': config.count,
      // `extension` : forme JSON stable (l'extension canonicalise via toJson) ou
      // `null`. Sérialisée via _canonicalize pour un ordre de clés déterministe.
      'extension': config.extension?.toJson(),
      'extra': config.extra,
    };
    return 'ZSessionConfigKey:${jsonEncode(_canonicalize(canonical))}';
  }

  /// Canonicalise récursivement une valeur JSON pour un `tag` STABLE : les `Map`
  /// voient leurs clés **triées** (ordre d'insertion non significatif pour
  /// l'égalité de valeur), les `List` préservent leur ordre (significatif).
  static Object? _canonicalize(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((Object? k) => k.toString()).toList()..sort();
      return <String, Object?>{
        for (final k in keys) k: _canonicalize(value[k]),
      };
    }
    if (value is List) {
      return <Object?>[for (final e in value) _canonicalize(e)];
    }
    return value;
  }
}
