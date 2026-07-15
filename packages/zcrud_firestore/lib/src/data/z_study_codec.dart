/// Codec/normaliseur **d'adaptateur** de documents d'étude LEGACY (ES-3.5,
/// FR-S16, AD-27/AD-10/AD-3/AD-4).
///
/// origine: app IFFD (`FolderDocument`) — documents Firestore **historiques**
/// écrits en **camelCase**, statuts d'un cycle de vie conversion/embedding à
/// **6 valeurs**, dates en `Timestamp` natif **ou** en `int` (millisSinceEpoch),
/// **aucune** métadonnée de sync `updated_at`/`is_deleted`. Ce codec les
/// réconcilie avec la forme **canonique** zcrud (snake_case, enums camelCase à
/// 4 valeurs, `ZSyncMeta` hors-entité) **sans perte ni exception**.
///
/// **Confinement AD-27 (CRUCIAL)** : le mapping de **casse** et de **valeur**
/// (statut legacy) vit **EXCLUSIVEMENT** ici (`zcrud_firestore`) — jamais dans
/// `zcrud_core`/kernel/entités (aucun `@JsonKey` camelCase, aucun renommage de
/// domaine). Le domaine ignore la casse legacy.
///
/// **Confinement AD-5** : signature publique = `Map<String, dynamic>`
/// **UNIQUEMENT** — aucun type `cloud_firestore` (`Timestamp`/`Query`/
/// `FirebaseException`) n'apparaît. L'interop `Timestamp` **natif** reste la
/// responsabilité de l'adaptateur (`FirebaseZRepositoryImpl._normalizeIsoInPlace`,
/// déjà en place) ; ce codec ne comble QUE le cas `int` millis (D6/DW-ES32-1).
///
/// **DÉFENSIF partout (AD-10)** : [toCanonical]/[toLegacy] ne lèvent **JAMAIS**.
/// Une clé/valeur inattendue est repliée ou passée telle quelle, jamais perdue,
/// jamais propagée en exception.
///
/// **Composition (D2)** — le codec se branche **EN AMONT** du décodage, au
/// point de câblage DI (fabrique de l'app/intégration IFFD), SANS modifier
/// `FirebaseZRepositoryImpl` :
///
/// ```dart
/// const codec = ZStudyLegacyCodec(
///   valueMappers: {'status': ZStudyLegacyCodec.mapDocumentStatus},
///   preserveLegacyUnder: {'status'},
/// );
/// final repo = FirebaseZRepositoryImpl<ZStudyDocument>(
///   firestore: firestore, collectionPath: path, kind: 'study_document',
///   fromMap: (raw) => canonicalFromMap(codec.toCanonical(raw)), // ← EN AMONT
///   toMap:   (v)   => codec.toLegacy(canonicalToMap(v)),        // ← interop
/// );
/// ```
library;

// `prefer_initializing_formals` est un FAUX POSITIF ici : les champs de config
// sont **privés** et exposés en paramètres **nommés** (`valueMappers`/
// `preserveLegacyUnder`). Dart interdit un formal d'initialisation nommé privé
// (`this._x` n'est pas appelable comme paramètre nommé) — l'assignation en liste
// d'initialisation est la SEULE forme possible (même convention que
// `firebase_z_repository_impl.dart`).
// ignore_for_file: prefer_initializing_formals

import 'package:zcrud_core/zcrud_core.dart';

/// Fonction de mapping de **valeur** d'un champ legacy → valeur canonique
/// (`String`). Toujours **totale et défensive** (jamais de throw) — cf.
/// [ZStudyLegacyCodec.mapDocumentStatus].
typedef ZLegacyValueMapper = String Function(Object? legacyValue);

/// Normaliseur PUR de `Map`, bidirectionnel, DÉFENSIF, confiné à l'adaptateur.
///
/// Sans état (`const`-constructible) : opère uniquement sur
/// `Map<String, dynamic>`.
class ZStudyLegacyCodec {
  /// Construit un codec.
  ///
  /// - [valueMappers] : mapping de **valeur** par champ (clé = nom de champ,
  ///   canonique snake_case **ou** legacy camelCase — les deux sont consultés).
  ///   Seul cas non générique (ex. `{'status': mapDocumentStatus}`).
  /// - [preserveLegacyUnder] : noms de champs dont la valeur legacy **exacte**
  ///   (avant remap) est conservée dans le corps canonique sous une clé de
  ///   survie `_legacy_<snake>` (AD-4 : zéro perte de granularité). Décodée, cette
  ///   clé inconnue retombe dans l'échappatoire `extra` de l'entité.
  const ZStudyLegacyCodec({
    Map<String, ZLegacyValueMapper> valueMappers =
        const <String, ZLegacyValueMapper>{},
    Set<String> preserveLegacyUnder = const <String>{},
  })  : _valueMappers = valueMappers,
        _preserveLegacyUnder = preserveLegacyUnder;

  final Map<String, ZLegacyValueMapper> _valueMappers;
  final Set<String> _preserveLegacyUnder;

  /// Préfixe des clés de survie (granularité legacy préservée, AD-4).
  static const String kLegacyPrefix = '_legacy_';

  /// Legacy (camelCase) → canonique (snake_case). **DÉFENSIF** (jamais throw).
  ///
  /// Pour chaque entrée :
  /// - les clés **réservées** `ZSyncMeta.reservedKeys` (`updated_at`/`is_deleted`)
  ///   sont passées **telles quelles** (déjà snake, gérées par l'adaptateur —
  ///   jamais remappées de casse ni de valeur, D3) ;
  /// - les clés de survie (`_legacy_…`) sont passées telles quelles ;
  /// - sinon la clé est transformée en snake_case ([camelToSnake]), la valeur
  ///   legacy exacte est éventuellement préservée (`preserveLegacyUnder`), puis
  ///   la valeur est remappée par [valueMappers] si applicable, sinon normalisée
  ///   (interop dates `int` millis → ISO-8601, D6).
  ///
  /// Enfin, `is_deleted:false` est **ajouté** de façon **ADDITIVE** (D3) si
  /// absent — condition de visibilité de l'adaptateur (sans quoi le document
  /// legacy est exclu de TOUTES les lectures). `updated_at` est **laissé absent**
  /// (→ `ZSyncMeta.updatedAt: null`, défaut LWW « jamais synchronisé »).
  Map<String, dynamic> toCanonical(Map<String, dynamic> legacy) {
    final out = <String, dynamic>{};
    for (final entry in legacy.entries) {
      final key = entry.key;
      final value = entry.value;

      // Clés réservées / de survie : passées telles quelles (D3/AD-4).
      if (ZSyncMeta.reservedKeys.contains(key) || key.startsWith(kLegacyPrefix)) {
        out[key] = value;
        continue;
      }

      final snakeKey = camelToSnake(key);

      // Préservation de la granularité legacy exacte AVANT tout remap (AD-4).
      if (_preserveLegacyUnder.contains(snakeKey) ||
          _preserveLegacyUnder.contains(key)) {
        out['$kLegacyPrefix$snakeKey'] = value;
      }

      final mapper = _valueMappers[snakeKey] ?? _valueMappers[key];
      if (mapper != null) {
        out[snakeKey] = mapper(value);
      } else {
        out[snakeKey] = _normalizeValue(snakeKey, value);
      }
    }

    // Ajout ADDITIF rétro-compatible (D3) : jamais d'écrasement d'une clé
    // déjà présente (putIfAbsent).
    out.putIfAbsent(ZSyncMeta.kIsDeleted, () => false);
    return out;
  }

  /// Canonique (snake_case) → legacy (camelCase). Round-trip de migration/interop.
  /// **DÉFENSIF** (jamais throw). Les clés réservées `ZSyncMeta.reservedKeys` et
  /// de survie (`_legacy_…`) restent **intactes** (elles n'ont pas de forme
  /// camelCase legacy — concern de store / survie codec).
  Map<String, dynamic> toLegacy(Map<String, dynamic> canonical) {
    final out = <String, dynamic>{};
    for (final entry in canonical.entries) {
      final key = entry.key;
      if (ZSyncMeta.reservedKeys.contains(key) || key.startsWith(kLegacyPrefix)) {
        out[key] = entry.value;
        continue;
      }
      out[snakeToCamel(key)] = entry.value;
    }
    return out;
  }

  /// Normalise une **valeur** générique lors du passage legacy → canonique.
  ///
  /// Seule interop appliquée (D6/DW-ES32-1) : une clé de **date** (convention
  /// canonique : snake_case terminant par `_at`) portant un `int`
  /// (millisecondsSinceEpoch, forme IFFD `createdAt: int`) est convertie en
  /// String ISO-8601 UTC — cas **NON** couvert par `_normalizeIsoInPlace` de
  /// l'adaptateur (qui gère `Timestamp`/`DateTime`/`{_seconds}` mais pas `int`).
  ///
  /// **DÉFENSIF** : un `int` hors bornes plausibles (année ∉ [1970, 9999]) ou une
  /// valeur non-`int` est **laissée intacte** — jamais de throw. Une String déjà
  /// ISO (document déjà normalisé) traverse inchangée.
  Object? _normalizeValue(String snakeKey, Object? value) {
    if (value is int && snakeKey.endsWith('_at')) {
      return _millisToIsoOrNull(value) ?? value;
    }
    return value;
  }

  /// Convertit des millisecondes epoch en ISO-8601 UTC, ou `null` si implausible
  /// (jamais de throw — bornes [1970-01-01, 9999-12-31]).
  static String? _millisToIsoOrNull(int millis) {
    // Bornes de plausibilité : [epoch 0 (1970), fin d'année 9999].
    const int maxPlausibleMillis = 253402300799999; // 9999-12-31T23:59:59.999Z
    if (millis < 0 || millis > maxPlausibleMillis) return null;
    try {
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
          .toIso8601String();
    } on Object {
      return null;
    }
  }

  /// Mapping DÉTERMINISTE **6 → 4** du statut legacy IFFD `FolderDocumentStatus`
  /// vers le nom d'enum canonique `ZDocumentStatus` (DW-ES21-1 — SOLDÉE).
  ///
  /// Table (dérivée des getters sémantiques IFFD `isProcessing`/`ready`) :
  ///
  /// | Legacy IFFD (6)              | Canonique (nom d'enum) |
  /// |------------------------------|------------------------|
  /// | `uploading`                  | `uploading`            |
  /// | `converting`                 | `validating`           |
  /// | `embedding`                  | `validating`           |
  /// | `uploaded`                   | `ready`                |
  /// | `converted`                  | `ready`                |
  /// | `embedded`                   | `ready`                |
  /// | absent/`null`/inconnu/non-`String` | `uploading` (défaut sûr) |
  ///
  /// `uploading` est le **défaut défensif** = 1ʳᵉ constante `ZDocumentStatus`
  /// (`T.values.first`, AD-10) : ne ment ni ne détruit rien. `rejected` n'est
  /// **jamais** produit (état transitoire jamais persisté côté IFFD). La
  /// granularité exacte (`embedded`/`converted`…) est préservée par le codec dans
  /// `extra` (`preserveLegacyUnder`), zéro perte (AD-4).
  static String mapDocumentStatus(Object? legacy) {
    if (legacy is! String) return 'uploading';
    switch (legacy) {
      case 'uploading':
        return 'uploading';
      case 'converting':
      case 'embedding':
        return 'validating';
      case 'uploaded':
      case 'converted':
      case 'embedded':
        return 'ready';
      default:
        return 'uploading';
    }
  }

  /// Transforme une clé camelCase en snake_case (`subjectId` → `subject_id`,
  /// `createdAt` → `created_at`, `assistantFileId` → `assistant_file_id`).
  /// Aligné sur `fieldRename: snake` du générateur (AD-3). **Idempotent** sur les
  /// mots simples / déjà-snake (`id` → `id`, `status` → `status`,
  /// `is_deleted` → `is_deleted`). **DÉFENSIF** : jamais de throw ; une clé sans
  /// majuscule est renvoyée inchangée.
  static String camelToSnake(String key) {
    final buf = StringBuffer();
    for (var i = 0; i < key.length; i++) {
      final ch = key[i];
      final lower = ch.toLowerCase();
      // Majuscule interne → insère un séparateur (jamais en tête).
      if (ch != lower && i > 0) buf.write('_');
      buf.write(lower);
    }
    return buf.toString();
  }

  /// Transforme une clé snake_case en camelCase (`subject_id` → `subjectId`).
  /// **Idempotent** sur les mots simples (`id` → `id`, `status` → `status`).
  /// **DÉFENSIF** : jamais de throw ; segment vide préservé comme `_`.
  static String snakeToCamel(String key) {
    if (!key.contains('_')) return key;
    final parts = key.split('_');
    final buf = StringBuffer(parts.first);
    for (var i = 1; i < parts.length; i++) {
      final part = parts[i];
      if (part.isEmpty) {
        buf.write('_'); // segment vide (double underscore) préservé.
        continue;
      }
      buf.write(part[0].toUpperCase());
      buf.write(part.substring(1));
    }
    return buf.toString();
  }
}
