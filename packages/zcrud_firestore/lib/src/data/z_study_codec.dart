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
  /// - [syncMetaKeyAliases] (**CR-IFFD-3**) : clé legacy → clé RÉSERVÉE
  ///   ([ZSyncMeta.reservedKeys]) qu'elle désigne réellement. Sans cela, un hôte
  ///   dont le soft-delete s'appelle autrement (IFFD : `deleted`) voit sa clé
  ///   traverser telle quelle — `camelToSnake('deleted')` == `'deleted'`, aucune
  ///   majuscule interne — puis `is_deleted:false` ajouté par le `putIfAbsent`
  ///   final : **tout document supprimé redevient visible**. La perte est
  ///   silencieuse (le census R26 est satisfait, la clé étant préservée).
  ///   Ex. `{'deleted': ZSyncMeta.kIsDeleted}`.
  /// - [recurseNested] (**CR-IFFD-2**) : descend dans les `Map`/`List`
  ///   imbriquées pour y renommer les clés et normaliser les dates. `false` par
  ///   défaut — la conversion en profondeur d'une charge utile TIERCE la
  ///   casserait (cf. [opaqueKeys]).
  /// - [opaqueKeys] : clés (canoniques snake_case) dont la valeur est une charge
  ///   utile **tierce** à ne JAMAIS convertir, même sous [recurseNested] — ex.
  ///   `dashboard` (sérialisation `flutter_flow_chart`), dont les noms de champs
  ///   sont imposés par la bibliothèque : les renommer rendrait l'objet
  ///   indésérialisable.
  /// - [keyAliases] (**CR-IFFD-5**) : clé legacy → clé **canonique métier**
  ///   lorsqu'il s'agit d'un **renommage sémantique** que la conversion de casse
  ///   ne peut pas deviner. Ex. IFFD `quality` → `last_quality` :
  ///   `camelToSnake('quality')` rend `quality`, donc sans alias le champ
  ///   traverse sous son nom legacy et `last_quality` reste **absent** — la
  ///   qualité de la dernière révision est silencieusement perdue.
  ///   ⚠️ À ne pas confondre avec [syncMetaKeyAliases], qui vise les clés
  ///   **réservées** hors-entité ; ici la cible est une clé **métier** ordinaire.
  /// - [preserveAbsenceUnder] (**CR-IFFD-12**) : champs (nom canonique
  ///   snake_case **ou** legacy) dont l'**ABSENCE** doit survivre à la migration
  ///   vers un domaine qui ne sait pas la représenter. Cf. [kAbsentFieldsKey].
  const ZStudyLegacyCodec({
    Map<String, ZLegacyValueMapper> valueMappers =
        const <String, ZLegacyValueMapper>{},
    Set<String> preserveLegacyUnder = const <String>{},
    Map<String, String> syncMetaKeyAliases = const <String, String>{},
    Map<String, String> keyAliases = const <String, String>{},
    bool recurseNested = false,
    Set<String> opaqueKeys = const <String>{},
    Set<String> preserveAbsenceUnder = const <String>{},
  })  : _valueMappers = valueMappers,
        _preserveAbsenceUnder = preserveAbsenceUnder,
        _preserveLegacyUnder = preserveLegacyUnder,
        _syncMetaKeyAliases = syncMetaKeyAliases,
        _keyAliases = keyAliases,
        _recurseNested = recurseNested,
        _opaqueKeys = opaqueKeys;

  final Map<String, ZLegacyValueMapper> _valueMappers;
  final Set<String> _preserveLegacyUnder;
  final Map<String, String> _syncMetaKeyAliases;
  final Map<String, String> _keyAliases;
  final bool _recurseNested;
  final Set<String> _opaqueKeys;
  final Set<String> _preserveAbsenceUnder;

  /// Table de renommage sémantique de clés MÉTIER (CR-IFFD-5), exposée pour que
  /// [ZLegacyStudyMigrator] puisse (a) créditer le census R26 sur la clé CIBLE —
  /// sans quoi tout champ aliasé serait faussement déclaré **perdu** — et
  /// (b) refuser de considérer comme « déjà canonique » un document portant
  /// encore une clé source non renommée.
  Map<String, String> get keyAliases => _keyAliases;

  /// Clés dont la valeur est une charge utile TIERCE, jamais convertie
  /// (CR-IFFD-2), exposée pour que la **détection** de canonicité du migrateur
  /// puisse les enjamber exactement comme la conversion le fait (CR-IFFD-7).
  ///
  /// Sans cela, un sous-arbre opaque — qui conserve **par conception** ses clés
  /// camelCase — ferait échouer la détection à jamais : le document serait
  /// re-migré à chaque passage et ses `valueMappers` réappliqués, rétrogradant
  /// les valeurs déjà canoniques. **La détection doit refléter la conversion :
  /// ce qui n'est pas converti ne peut pas être exigé canonique.**
  Set<String> get opaqueKeys => _opaqueKeys;

  /// `true` si la conversion descend dans les `Map`/`List` imbriquées.
  ///
  /// Exposé pour que la **détection** de canonicité du migrateur reflète la
  /// conversion : n'exiger la canonicité en profondeur que si la conversion y
  /// descend. Sans cette symétrie, un contenu imbriqué camelCase — que le codec
  /// ne convertit PAS quand `recurseNested` est `false` — rendait le document
  /// éternellement « non canonique », donc re-migré à chaque passage, avec
  /// rétrogradation des valeurs déjà remappées.
  bool get recurseNested => _recurseNested;

  /// Clés legacy déclarées comme alias d'une clé de sync réservée (CR-IFFD-3).
  ///
  /// Exposé pour que [ZLegacyStudyMigrator] puisse refuser de considérer comme
  /// « déjà canonique » un document qui en porte encore une — sans quoi une
  /// reprise de migration sauterait définitivement ces documents.
  Set<String> get syncMetaAliasKeys => _syncMetaKeyAliases.keys.toSet();

  /// Préfixe des clés de survie (granularité legacy préservée, AD-4).
  static const String kLegacyPrefix = '_legacy_';

  /// Clé de survie journalisant les **cibles disputées** par plusieurs clés
  /// sources (CR-IFFD-6). Présente **uniquement** en cas de collision : sa seule
  /// existence signale qu'un arbitrage a eu lieu et qu'un `_legacy_<source>`
  /// porte la ou les valeurs écartées. Une collision n'est ainsi jamais
  /// silencieuse — le silence était le pire des comportements possibles.
  static const String kAliasCollisionsKey = '${kLegacyPrefix}alias_collisions';

  /// Clé de survie listant les champs qui étaient **ABSENTS** (ou `null`) dans
  /// le document legacy (**CR-IFFD-12**).
  ///
  /// **Le motif générique** : toute migration d'un schéma legacy *permissif*
  /// vers un domaine *strict* perd une distinction que la cible ne porte pas.
  /// Ici : les entités `zcrud_*` rendent non-nullables des champs que les hôtes
  /// portent en nullable (`folderId`, `title`, `question`…), avec `''` pour
  /// défaut — « jamais renseigné » et « vidé volontairement » deviennent
  /// **indiscernables**. Cinq cutovers ont posé cinq fois le même contournement.
  ///
  /// La réponse retenue est celle de [kLegacyPrefix] : **ne pas assouplir le
  /// domaine** (il est strict à dessein), mais préserver l'information écartée
  /// dans une clé de survie. Décodée, cette clé inconnue retombe dans
  /// l'échappatoire `extra` de l'entité — l'hôte y lit la distinction et
  /// [toLegacy] la restitue en `null`.
  ///
  /// **Une liste, pas N clés** : un marqueur par champ multiplierait les clés
  /// sur un corpus large ; la liste est vide-donc-absente dans le cas nominal.
  ///
  /// ⚠️ **Cumulative entre passages.** Au 2ᵉ passage le champ vaut `''` et non
  /// plus `null` : recalculer la liste l'effacerait, et l'absence — que cette
  /// clé existe pour retenir — serait perdue au moment même où on la relit.
  /// [toCanonical] fusionne donc avec la liste déjà présente. C'est la même
  /// classe de défaut que CR-IFFD-7 (la détection doit refléter la conversion).
  static const String kAbsentFieldsKey = '${kLegacyPrefix}absent_fields';

  /// Priorité d'une clé source sur sa cible canonique (CR-IFFD-6). **0 gagne.**
  ///
  /// Déterministe et **indépendante de l'ordre d'itération** — Firestore ne
  /// garantit pas l'ordre des clés d'un document, donc arbitrer au fil de la
  /// boucle rendait le résultat non reproductible.
  ///
  /// Ordre retenu : la forme **déjà canonique** prime (elle est le produit d'une
  /// migration antérieure), puis la conversion de casse, puis l'alias. Cela rend
  /// une reprise **stable** : un document déjà migré n'est pas rétrogradé par
  /// une clé legacy résiduelle.
  int _priorityOf(String key) {
    if (_keyAliases.containsKey(key)) return 2;
    if (camelToSnake(key) == key) return 0;
    return 1;
  }

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
    // Résultats des alias de clés de sync — appliqués APRÈS la boucle pour
    // primer sur un passthrough de clé réservée (CR-IFFD-3, corpus partiel).
    final aliased = <String, Object?>{};
    // CR-IFFD-6 — revendications de cible, résolues APRÈS la boucle pour être
    // indépendantes de l'ordre des clés (non garanti par Firestore).
    final claims = <String, _Claim>{};
    final collisions = <String>{};
    for (final entry in legacy.entries) {
      final key = entry.key;
      final value = entry.value;

      // Clés réservées / de survie : passées telles quelles (D3/AD-4).
      if (ZSyncMeta.reservedKeys.contains(key) || key.startsWith(kLegacyPrefix)) {
        out[key] = value;
        continue;
      }

      // CR-IFFD-3 — alias de clé de SYNC : la clé legacy DÉSIGNE une clé
      // réservée. Elle est CONSOMMÉE (renommée), jamais dupliquée, et la valeur
      // brute est préservée sous `_legacy_<snake>` (AD-4, zéro perte).
      // ⚠️ Résolu APRÈS la boucle (cf. `aliased`) : sur un corpus PARTIELLEMENT
      // migré, le document porte à la fois `deleted:true` (la vérité legacy) et
      // un `is_deleted:false` ajouté à tort par un passage antérieur. Appliquer
      // l'alias dans la boucle le laisserait écraser par le passthrough de la
      // clé réservée — la corruption l'emporterait sur l'intention réelle.
      final aliasTarget = _syncMetaKeyAliases[key];
      if (aliasTarget != null && ZSyncMeta.reservedKeys.contains(aliasTarget)) {
        out['$kLegacyPrefix${camelToSnake(key)}'] = value;
        aliased[aliasTarget] = _coerceSyncMetaValue(aliasTarget, value);
        continue;
      }

      // CR-IFFD-5 — renommage SÉMANTIQUE : l'alias remplace la conversion de
      // casse, qui ne peut pas le deviner (`quality` → `last_quality`).
      final snakeKey = _keyAliases[key] ?? camelToSnake(key);

      // CR-IFFD-6 — plusieurs sources peuvent viser la MÊME cible (ex. `quality`
      // aliasée ET `lastQuality` qui snake vers `last_quality`). La résolution
      // est DIFFÉRÉE après la boucle : arbitrer au fil de l'itération rendait le
      // résultat dépendant de l'ORDRE DES CLÉS du document — or Firestore ne le
      // garantit pas. Selon l'ordre, une valeur disparaissait sans trace.
      final claim = _Claim(source: key, value: value, priority: _priorityOf(key));
      final existing = claims[snakeKey];
      if (existing == null || claim.priority < existing.priority) {
        if (existing != null) {
          // Le perdant est préservé — INCONDITIONNELLEMENT, quel que soit
          // l'ordre d'arrivée (AD-4, zéro perte).
          out['$kLegacyPrefix${camelToSnake(existing.source)}'] = existing.value;
          collisions.add(snakeKey);
        }
        claims[snakeKey] = claim;
      } else {
        out['$kLegacyPrefix${camelToSnake(key)}'] = value;
        collisions.add(snakeKey);
      }
    }

    // Résolution des revendications : un gagnant déterministe par cible.
    for (final e in claims.entries) {
      final snakeKey = e.key;
      final key = e.value.source;
      final value = e.value.value;

      // Préservation de la granularité legacy exacte AVANT tout remap (AD-4).
      // CR-IFFD-7 (2ᵉ effet) — `putIfAbsent` et NON affectation : sur un
      // document déjà porteur d'un `_legacy_<clé>`, réécrire l'écraserait par la
      // valeur DÉJÀ REMAPPÉE du passage précédent (`embedded` → `ready`), et la
      // granularité d'origine — seule raison d'être de cette clé — serait perdue
      // sans retour. La première valeur observée est la bonne.
      if (_preserveLegacyUnder.contains(snakeKey) ||
          _preserveLegacyUnder.contains(key)) {
        out.putIfAbsent('$kLegacyPrefix$snakeKey', () => value);
      }

      final mapper = _valueMappers[snakeKey] ?? _valueMappers[key];
      if (mapper != null) {
        out[snakeKey] = mapper(value);
      } else {
        out[snakeKey] = _normalizeValue(snakeKey, value);
      }
    }

    // CR-IFFD-3 — les alias PRIMENT : la clé legacy porte l'intention réelle de
    // l'utilisateur, une clé réservée déjà présente peut être le résultat d'un
    // passage antérieur défectueux.
    out.addAll(aliased);

    // Ajout ADDITIF rétro-compatible (D3) : jamais d'écrasement d'une clé
    // déjà présente (putIfAbsent).
    out.putIfAbsent(ZSyncMeta.kIsDeleted, () => false);

    // CR-IFFD-12 — préservation de l'ABSENCE. Un champ déclaré est « absent »
    // s'il manque du document legacy OU s'il y vaut `null` : le domaine cible
    // le rendra `''` dans les deux cas, et la distinction serait perdue là.
    if (_preserveAbsenceUnder.isNotEmpty) {
      final absent = <String>{};
      // CUMULATIF (cf. [kAbsentFieldsKey]) : au 2ᵉ passage la valeur vaut déjà
      // `''` — recalculer seul EFFACERAIT le marqueur du 1ᵉʳ passage.
      final prior = legacy[kAbsentFieldsKey];
      if (prior is List) {
        for (final e in prior) {
          if (e is String) absent.add(e);
        }
      }
      for (final field in _preserveAbsenceUnder) {
        final canonical = _keyAliases[field] ?? camelToSnake(field);
        // La forme legacy ET la forme canonique sont consultées : l'hôte
        // déclare l'une ou l'autre, comme pour `preserveLegacyUnder`.
        final present = legacy.containsKey(field) && legacy[field] != null ||
            legacy.containsKey(canonical) && legacy[canonical] != null;
        if (!present) absent.add(canonical);
      }
      if (absent.isNotEmpty) {
        out[kAbsentFieldsKey] = absent.toList()..sort();
      }
    }

    // CR-IFFD-6 — une collision d'alias n'est JAMAIS silencieuse : les cibles
    // disputées sont journalisées sous une clé de survie dédiée, inspectable et
    // relevée par le rapport de migration.
    if (collisions.isNotEmpty) {
      out[kAliasCollisionsKey] = collisions.toList()..sort();
    }
    return out;
  }

  /// Canonique (snake_case) → legacy (camelCase). Round-trip de migration/interop.
  /// **DÉFENSIF** (jamais throw). Les clés réservées `ZSyncMeta.reservedKeys` et
  /// de survie (`_legacy_…`) restent **intactes** (elles n'ont pas de forme
  /// camelCase legacy — concern de store / survie codec).
  Map<String, dynamic> toLegacy(Map<String, dynamic> canonical) {
    // CR-IFFD-12 — restitution de l'ABSENCE : les champs listés retrouvent
    // `null`, la valeur que le domaine strict avait dû rendre `''`.
    final absent = <String>{};
    final marker = canonical[kAbsentFieldsKey];
    if (marker is List) {
      for (final e in marker) {
        if (e is String) absent.add(e);
      }
    }
    final out = <String, dynamic>{};
    for (final entry in canonical.entries) {
      final key = entry.key;
      if (ZSyncMeta.reservedKeys.contains(key) || key.startsWith(kLegacyPrefix)) {
        out[key] = entry.value;
        continue;
      }
      // Restitution CONSERVATRICE : seule une valeur devenue `''` est rendue à
      // `null`. Si l'hôte a depuis renseigné le champ, la saisie l'emporte sur
      // un marqueur d'absence devenu périmé — sinon la migration écraserait une
      // donnée réelle par `null`.
      final restore = absent.contains(key) && entry.value == '';
      out[snakeToCamel(key)] = restore ? null : entry.value;
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
    // CR-IFFD-2 — descente RÉCURSIVE optionnelle. `opaqueKeys` protège les
    // charges utiles tierces (renommer leurs champs les rendrait illisibles
    // par la bibliothèque qui les a produites).
    if (_recurseNested && !_opaqueKeys.contains(snakeKey)) {
      return _normalizeDeep(value);
    }
    return value;
  }

  /// Descente récursive : renomme les clés en snake_case et normalise les dates
  /// `int` millis→ISO à **toute profondeur**. Les `valueMappers` et
  /// `preserveLegacyUnder` restent **de premier niveau** — ils désignent des
  /// champs de document (ex. `status`), pas des feuilles arbitraires.
  /// **DÉFENSIF** : jamais de throw ; toute valeur non-`Map`/`List` est rendue
  /// telle quelle.
  Object? _normalizeDeep(Object? value) {
    if (value is Map) {
      final out = <String, dynamic>{};
      for (final e in value.entries) {
        final k = e.key;
        if (k is! String) {
          // Clé non-String : intraduisible, préservée à l'identique.
          out['${e.key}'] = _normalizeDeep(e.value);
          continue;
        }
        if (ZSyncMeta.reservedKeys.contains(k) || k.startsWith(kLegacyPrefix)) {
          out[k] = e.value;
          continue;
        }
        final sk = camelToSnake(k);
        final v = e.value;
        out[sk] = (v is int && sk.endsWith('_at'))
            ? (_millisToIsoOrNull(v) ?? v)
            : _normalizeDeep(v);
      }
      return out;
    }
    if (value is List) {
      return value.map<Object?>(_normalizeDeep).toList();
    }
    return value;
  }

  /// Coercition DÉFENSIVE d'une valeur legacy vers le type attendu par une clé
  /// de sync réservée (CR-IFFD-3). **Ne throw jamais.**
  ///
  /// Pour [ZSyncMeta.kIsDeleted], le défaut est **FERMÉ** : une valeur
  /// ininterprétable (ni `bool`, ni `null`) est traitée comme **supprimée**.
  /// Ce choix est asymétrique et délibéré — masquer à tort un document est
  /// réparable (la donnée est intacte, la valeur brute reste sous
  /// `_legacy_<snake>`), tandis que **ressusciter** un document supprimé expose
  /// un contenu que l'utilisateur avait explicitement retiré, potentiellement à
  /// d'autres membres d'un dossier partagé.
  static Object? _coerceSyncMetaValue(String target, Object? value) {
    if (target == ZSyncMeta.kIsDeleted) {
      if (value is bool) return value;
      if (value == null) return false; // absent ⇒ non supprimé
      return true; // ininterprétable ⇒ fail-closed
    }
    if (target == ZSyncMeta.kUpdatedAt) {
      if (value is String) return value;
      if (value is int) return _millisToIsoOrNull(value);
      return null;
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

/// Revendication d'une clé canonique par une clé source (CR-IFFD-6).
///
/// [priority] arbitre de façon **déterministe** quand plusieurs sources visent
/// la même cible — 0 gagne. L'ordre d'itération du document n'intervient jamais.
class _Claim {
  const _Claim({
    required this.source,
    required this.value,
    required this.priority,
  });

  final String source;
  final Object? value;
  final int priority;
}
