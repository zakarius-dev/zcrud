/// Migrateur de **CORPUS** de documents d'étude LEGACY IFFD → forme CANONIQUE
/// zcrud (ES-11.2, FR-S34, AD-27/AD-19/AD-10/AD-5).
///
/// origine: app IFFD — collections Firestore **flat top-level** de documents
/// écrits en **camelCase**, dates `int` millis, statuts à **6 valeurs**, champs
/// de contrôle inline (`audioText`/`audioTextHash`), **aucune** métadonnée de
/// sync `updated_at`/`is_deleted`. Ce migrateur transforme un tel corpus vers la
/// forme **canonique** (snake_case, enums camelCase à 4 valeurs, `ZSyncMeta`
/// additif hors-entité) **sans perte de champ métier** (R26), de façon
/// **idempotente** (reprise sûre) et **défensive** (jamais de throw, AD-10).
///
/// ## Composition, PAS réécriture (AD-27)
/// Le mapping **par document** (casse camelCase↔snake, valeur `status` 6→4,
/// interop dates `int`→ISO, préservation `_legacy_…`, ajout additif
/// `is_deleted:false`) est déjà porté par [ZStudyLegacyCodec] (ES-3.5). Ce
/// migrateur **compose** ce codec et n'ajoute QUE la valeur d'un migrateur de
/// **corpus ré-entrant** :
///   1. une **garde d'IDEMPOTENCE** (le codec N'EST PAS idempotent sur `status`,
///      cf. TRAP ci-dessous) ;
///   2. un **census R26** de préservation exacte des clés métier ;
///   3. un **rapport auditable** ([ZLegacyMigrationReport]) ;
///   4. un **DRY-RUN** par construction (calcule sans écrire ni muter l'entrée).
///
/// ## Le TRAP central — idempotence du `status` (vérifié sur le code du codec)
/// [ZStudyLegacyCodec.toCanonical] N'EST PAS idempotent : `mapDocumentStatus` ne
/// connaît QUE les 6 valeurs legacy ; une valeur DÉJÀ canonique (`ready`/
/// `validating`) tombe dans le `default` → **`uploading`**. Donc
/// `toCanonical(toCanonical(doc))` **RÉTROGRADE** `ready`→`uploading` — perte
/// silencieuse à la ré-exécution. Un corpus RÉEL étant **re-migré** (reprise,
/// bascule progressive), le migrateur DOIT être un **point fixe**
/// (`migrate(migrate(x)) == migrate(x)`). La garde retenue (documentée ci-dessous)
/// **détecte les documents déjà canoniques** et les laisse **inchangés** — le
/// codec ES-3.5 reste inchangé (son test reste vert).
///
/// ## Stratégie d'idempotence retenue : détection « déjà canonique »
/// Un document est considéré **déjà canonique** s'il porte la clé de sync
/// [ZSyncMeta.kIsDeleted] **ET** qu'aucune de ses clés n'est en camelCase
/// (aucune majuscule interne). C'est robuste au-delà du seul `status` : toute la
/// forme canonique (clés snake, `is_deleted` additif, `_legacy_…`) est un point
/// fixe. Un document legacy (camelCase, sans `is_deleted`) échoue la détection et
/// est migré ; un document déjà migré la réussit et traverse **à l'identique**.
///
/// ## Confinement AD-5 / R28 (générique par `Map`)
/// Signature publique = `Map<String, dynamic>` **UNIQUEMENT** : AUCUN type
/// `cloud_firestore` (`Timestamp`/`Query`/`WriteBatch`/`FirebaseException`) ni
/// `hive` (`Box`) n'apparaît. Le migrateur est **générique par `Map`** : il ne
/// dépend d'AUCUN package d'entité (`zcrud_document`/`note`/…) — aucune arête de
/// graphe neuve (delta = 0).
///
/// ## DRY-RUN — write-back DÉFÉRÉ (DW-ES112-1)
/// [migrateCorpus] **CALCULE** la forme canonique **sans muter** l'entrée ni
/// écrire nulle part. Le **write-back** Firestore batché (lecture des collections
/// RÉELLES IFFD → `WriteBatch` ≤ 450/lot → `serverTimestamp()` pour `updated_at`
/// → cutover repo-par-repo) est **DÉFÉRÉ** à une **session IFFD dédiée** (dette
/// **DW-ES112-1**) : il n'est PAS implémenté ici (aucune I/O, aucun
/// `FirebaseFirestore` dans ce fichier).
library;

// `prefer_initializing_formals` est un FAUX POSITIF ici : le champ `_codec` est
// PRIVÉ mais exposé en paramètre NOMMÉ public (`codec`). Dart interdit un formal
// d'initialisation nommé privé (`this._codec` n'est pas appelable comme paramètre
// nommé) — l'assignation en liste d'initialisation est la SEULE forme possible
// (même convention que `z_study_codec.dart`).
// ignore_for_file: prefer_initializing_formals

import 'package:zcrud_core/zcrud_core.dart';

import 'z_study_codec.dart';

/// Issue de migration d'**un** document legacy → canonique (immuable).
///
/// Porte le [canonical] produit, le drapeau d'[alreadyCanonical] (idempotence),
/// la liste des champs ayant reçu un **défaut défensif** ([defaultsApplied],
/// AD-10, jamais avalés en silence), et le **census R26** de préservation
/// ([businessKeysIn] → [coveredBusinessKeys]).
class ZDocumentMigrationOutcome {
  /// Construit une issue immuable.
  const ZDocumentMigrationOutcome({
    required this.canonical,
    required this.alreadyCanonical,
    required this.defaultsApplied,
    required this.businessKeysIn,
    required this.coveredBusinessKeys,
  });

  /// Forme canonique produite (snake_case, `is_deleted` additif hors-entité).
  final Map<String, dynamic> canonical;

  /// `true` si le document était **déjà canonique** et a traversé **inchangé**
  /// (garde d'idempotence — reprise d'une migration interrompue).
  final bool alreadyCanonical;

  /// Noms des champs (canoniques snake_case) ayant reçu un **défaut défensif**
  /// (ex. `status` illisible → `uploading` ; `*_at` implausible laissé intact).
  /// Vide si aucune dégradation. Tracé au rapport (AD-10 : jamais silencieux).
  final List<String> defaultsApplied;

  /// Clés **métier** (hors sync/`_legacy_`) présentes dans l'entrée legacy.
  final Set<String> businessKeysIn;

  /// Sous-ensemble de [businessKeysIn] **retrouvé** dans le canonique (renommé
  /// snake_case OU préservé sous `_legacy_<snake>`). Le census R26 est complet
  /// ssi `coveredBusinessKeys.length == businessKeysIn.length`.
  final Set<String> coveredBusinessKeys;

  /// `true` ssi **aucune** clé métier legacy n'a été silencieusement perdue
  /// (census R26 — préservation EXACTE, pas simple existence).
  bool get isPreservationComplete =>
      coveredBusinessKeys.length == businessKeysIn.length;

  /// Clés métier legacy **perdues** (jamais retrouvées dans le canonique).
  /// Vide quand [isPreservationComplete].
  Set<String> get lostBusinessKeys =>
      businessKeysIn.difference(coveredBusinessKeys);
}

/// Rapport **auditable** et immuable d'une migration de corpus ([migrateCorpus]).
///
/// Permet un **audit sans perte AVANT toute écriture** (DRY-RUN) : compteurs
/// cohérents (invariant [migrated] + [alreadyCanonical] == [total]), documents
/// canoniques calculés, census agrégé de préservation métier.
class ZLegacyMigrationReport {
  /// Construit un rapport immuable.
  const ZLegacyMigrationReport({
    required this.total,
    required this.migrated,
    required this.alreadyCanonical,
    required this.defaultsApplied,
    required this.canonicalDocuments,
    required this.preservedAllBusinessKeys,
    required this.lostBusinessKeys,
  });

  /// Nombre total de documents traités.
  final int total;

  /// Documents effectivement **migrés** (legacy → canonique).
  final int migrated;

  /// Documents déjà canoniques ayant traversé **inchangés** (idempotence).
  final int alreadyCanonical;

  /// Nombre **total** de défauts défensifs appliqués sur l'ensemble du corpus.
  final int defaultsApplied;

  /// Formes canoniques produites (une par document, ordre du corpus). Le
  /// write-back de ces documents est DÉFÉRÉ (DW-ES112-1).
  final List<Map<String, dynamic>> canonicalDocuments;

  /// `true` ssi **aucune** clé métier n'a été perdue sur **tout** le corpus (R26).
  final bool preservedAllBusinessKeys;

  /// Union des clés métier perdues sur l'ensemble du corpus (vide si sans perte).
  final Set<String> lostBusinessKeys;

  /// Invariant de cohérence du rapport : chaque document est **soit** migré
  /// **soit** déjà canonique — jamais perdu (aucune catégorie d'erreur : le
  /// migrateur ne throw jamais, AD-10).
  bool get isConsistent => migrated + alreadyCanonical == total;
}

/// Migrateur de corpus **PUR, DÉFENSIF, IDEMPOTENT**, confiné à l'adaptateur
/// (`zcrud_firestore`, AD-27). Sans état (`const`-constructible) : opère
/// uniquement sur `Map<String, dynamic>`.
///
/// Compose [ZStudyLegacyCodec] (config IFFD par défaut : mapping de valeur
/// `status` 6→4 + préservation `_legacy_status`) — il ne réimplémente NI
/// `camelToSnake` NI le mapping de statut (AD-27).
class ZLegacyStudyMigrator {
  /// Construit un migrateur.
  ///
  /// [codec] : brique par-document injectable (défaut : config IFFD
  /// `valueMappers: {'status': mapDocumentStatus}`, `preserveLegacyUnder:
  /// {'status'}`). Injectable pour les tests / d'autres topologies legacy.
  const ZLegacyStudyMigrator({ZStudyLegacyCodec codec = _iffdCodec})
      : _codec = codec;

  final ZStudyLegacyCodec _codec;

  /// Configuration IFFD par défaut (identique à ES-3.5) — mapping de valeur
  /// `status` 6→4 + préservation de la granularité legacy sous `_legacy_status`.
  static const ZStudyLegacyCodec _iffdCodec = ZStudyLegacyCodec(
    valueMappers: <String, ZLegacyValueMapper>{
      'status': ZStudyLegacyCodec.mapDocumentStatus,
    },
    preserveLegacyUnder: <String>{'status'},
  );

  /// Les 6 valeurs de statut LEGACY connues (IFFD `FolderDocumentStatus`). Toute
  /// autre valeur de `status` déclenche le défaut défensif `uploading` (AD-10).
  static const Set<String> _knownLegacyStatuses = <String>{
    'uploading',
    'converting',
    'embedding',
    'uploaded',
    'converted',
    'embedded',
  };

  /// Migre **un** document legacy → canonique. **Ne throw JAMAIS** (AD-10,
  /// défensif par construction). **Ne mute PAS** l'entrée (copie défensive).
  ///
  /// - Détecte les documents **déjà canoniques** ([_isAlreadyCanonical]) et les
  ///   renvoie **inchangés** (`alreadyCanonical: true`) — garde d'idempotence
  ///   qui franchit le TRAP `status` (point fixe).
  /// - Sinon **compose** [ZStudyLegacyCodec.toCanonical] et calcule le census R26
  ///   + la trace des défauts défensifs.
  ZDocumentMigrationOutcome migrateDocument(Map<String, dynamic> legacy) {
    // Census calculé sur l'entrée ORIGINALE (jamais mutée) : toute perte dans le
    // pipeline (drop de clé) reste détectable (R26 discriminant).
    final businessIn = _businessKeys(legacy);

    // Copie défensive : DRY-RUN, l'entrée n'est jamais mutée (AD-27/AC6).
    final input = Map<String, dynamic>.of(legacy);

    if (_isAlreadyCanonical(input)) {
      // Point fixe : traverse inchangé (aucun remap, aucune rétrogradation).
      return ZDocumentMigrationOutcome(
        canonical: input,
        alreadyCanonical: true,
        defaultsApplied: const <String>[],
        businessKeysIn: businessIn,
        coveredBusinessKeys: businessIn,
      );
    }

    final canonical = _codec.toCanonical(input);
    return ZDocumentMigrationOutcome(
      canonical: canonical,
      alreadyCanonical: false,
      defaultsApplied: _detectDefaults(legacy),
      businessKeysIn: businessIn,
      coveredBusinessKeys: _census(businessIn, canonical),
    );
  }

  /// Migre un **corpus** ré-entrant → [ZLegacyMigrationReport] auditable.
  /// **DRY-RUN** : aucune I/O, aucune mutation d'entrée, aucun write-back (DÉFÉRÉ
  /// DW-ES112-1). **Ne throw JAMAIS** (AD-10).
  ZLegacyMigrationReport migrateCorpus(Iterable<Map<String, dynamic>> corpus) {
    var total = 0;
    var migrated = 0;
    var already = 0;
    var defaults = 0;
    final canonicalDocs = <Map<String, dynamic>>[];
    final lost = <String>{};
    var preservedAll = true;

    for (final doc in corpus) {
      total++;
      final outcome = migrateDocument(doc);
      if (outcome.alreadyCanonical) {
        already++;
      } else {
        migrated++;
      }
      defaults += outcome.defaultsApplied.length;
      canonicalDocs.add(outcome.canonical);
      if (!outcome.isPreservationComplete) {
        preservedAll = false;
        lost.addAll(outcome.lostBusinessKeys);
      }
    }

    return ZLegacyMigrationReport(
      total: total,
      migrated: migrated,
      alreadyCanonical: already,
      defaultsApplied: defaults,
      canonicalDocuments: List<Map<String, dynamic>>.unmodifiable(canonicalDocs),
      preservedAllBusinessKeys: preservedAll,
      lostBusinessKeys: Set<String>.unmodifiable(lost),
    );
  }

  // ─────────────────────────── Détection & census ──────────────────────────

  /// Un document est **déjà canonique** s'il porte [ZSyncMeta.kIsDeleted] ET
  /// qu'AUCUNE clé n'est en camelCase. Garde d'idempotence (franchit le TRAP
  /// `status`). Robuste au-delà du seul statut. **Ne throw jamais.**
  /// **CR-IFFD-2 / CR-IFFD-3** — la détection est RÉCURSIVE et tient compte des
  /// alias de clés de sync.
  ///
  /// Deux faux positifs corrigés, tous deux à perte SILENCIEUSE :
  /// 1. n'inspecter que `doc.keys` déclarait canonique un document au premier
  ///    niveau propre mais au **contenu imbriqué encore legacy** (ex. les
  ///    `nodes[].edgeColor` récursifs d'un mindmap). Il traversait inchangé, et
  ///    la détection étant un **point fixe**, aucun passage ultérieur ne le
  ///    rattrapait jamais ;
  /// 2. une clé d'alias encore présente (ex. `deleted`, sans majuscule interne)
  ///    ne déclenchait rien : un corpus partiellement migré était sauté.
  ///
  /// Un faux négatif coûte un retraitement (le migrateur est idempotent) ; un
  /// faux positif perd la donnée. La détection est donc volontairement STRICTE.
  bool _isAlreadyCanonical(Map<String, dynamic> doc) {
    if (!doc.containsKey(ZSyncMeta.kIsDeleted)) return false;
    final syncAliases = _codec.syncMetaAliasKeys;
    // CR-IFFD-5 — même piège que `deleted` : une clé source de renommage
    // sémantique (`quality`) ne porte AUCUNE majuscule interne, donc la seule
    // détection de camelCase la laisserait passer pour canonique et le document
    // ne serait jamais renommé.
    final keyAliasSources = _codec.keyAliases.keys;
    for (final key in doc.keys) {
      if (syncAliases.contains(key)) return false;
      if (keyAliasSources.contains(key)) return false;
    }

    // CR-IFFD-7 — la DÉTECTION doit refléter la CONVERSION : un sous-arbre
    // déclaré opaque n'est jamais converti, il ne peut donc pas être exigé
    // canonique. Sans cette symétrie, tout document portant une charge utile
    // tierce (qui conserve PAR CONCEPTION ses clés camelCase) était classé
    // « non canonique » À JAMAIS, donc re-migré à chaque passage — et ses
    // `valueMappers` réappliqués, rétrogradant `status` de `ready` à
    // `uploading` : exactement le TRAP que la garde d'idempotence devait
    // franchir. `opaqueKeys` la neutralisait.
    final opaque = _codec.opaqueKeys;
    // ⚠️ ÉLARGISSEMENT (banc d'invariants, 2026-07-22) — le principe de
    // CR-IFFD-7 (« la détection doit refléter la conversion ») ne valait
    // qu'à moitié : `opaqueKeys` était enjambé, mais la détection descendait
    // TOUJOURS dans les sous-structures, y compris quand `recurseNested` est
    // FALSE — c'est-à-dire quand la conversion, elle, ne descend PAS.
    //
    // Conséquence, trouvée par croisement (config `valueMappers` + document à
    // contenu imbriqué camelCase, SANS aucun `opaqueKeys`) : le document était
    // déclaré non canonique à jamais, re-migré à chaque passage, et son `status`
    // rétrogradé `ready` → `uploading`. Exactement le TRAP de CR-IFFD-1, par une
    // porte que les 7 CR n'avaient pas ouverte.
    //
    // Règle complète : on n'exige la canonicité EN PROFONDEUR que si la
    // conversion descend effectivement (`recurseNested`). Sinon seul le premier
    // niveau — le seul que le codec transforme — répond de sa casse.
    final deep = _codec.recurseNested;
    for (final e in doc.entries) {
      // Le NOM de la clé de premier niveau reste toujours soumis à la règle,
      // même quand sa VALEUR est opaque : c'est notre clé, pas celle du tiers.
      if (_hasInternalUppercase(e.key)) return false;
      if (!deep || opaque.contains(e.key)) continue;
      if (!_isDeepCanonical(e.value)) return false;
    }
    return true;
  }

  /// Vrai ssi AUCUNE clé camelCase ne subsiste à quelque profondeur que ce soit.
  /// **Ne throw jamais** (AD-10) ; les clés non-`String` sont ignorées.
  static bool _isDeepCanonical(Object? value) {
    if (value is Map) {
      for (final e in value.entries) {
        final k = e.key;
        if (k is String && _hasInternalUppercase(k)) return false;
        if (!_isDeepCanonical(e.value)) return false;
      }
      return true;
    }
    if (value is List) {
      for (final v in value) {
        if (!_isDeepCanonical(v)) return false;
      }
      return true;
    }
    return true;
  }

  /// `true` si [key] contient une lettre majuscule (indice de camelCase legacy).
  /// **Défensif** : chiffres / `_` ne comptent pas.
  static bool _hasInternalUppercase(String key) {
    for (var i = 0; i < key.length; i++) {
      final ch = key[i];
      if (ch != ch.toLowerCase() && ch == ch.toUpperCase()) return true;
    }
    return false;
  }

  /// Clés **métier** de [doc] : hors clés de sync réservées ([ZSyncMeta
  /// .reservedKeys]) et hors clés de survie (`_legacy_…`) — celles-ci ne sont
  /// pas des clés métier d'entrée (AC2 : le census EXCLUT le hors-corps).
  static Set<String> _businessKeys(Map<String, dynamic> doc) => <String>{
        for (final key in doc.keys)
          if (!ZSyncMeta.reservedKeys.contains(key) &&
              !key.startsWith(ZStudyLegacyCodec.kLegacyPrefix))
            key,
      };

  /// Census R26 : pour chaque clé métier [businessIn], vérifie qu'elle est
  /// **retrouvable** dans [canonical] — soit renommée snake_case, soit préservée
  /// sous `_legacy_<snake>`. Retourne le sous-ensemble **couvert**.
  ///
  /// **CR-IFFD-5** — une clé **aliasée** (renommage sémantique, ex. `quality` →
  /// `last_quality`) est créditée sur sa clé CIBLE. Sans cela, le census
  /// chercherait `quality`/`_legacy_quality`, ne trouverait ni l'un ni l'autre,
  /// et déclarerait **perdu** un champ pourtant correctement migré — rendant le
  /// rapport de dry-run rouge à tort, donc inexploitable.
  Set<String> _census(
    Set<String> businessIn,
    Map<String, dynamic> canonical,
  ) {
    final aliases = _codec.keyAliases;
    final covered = <String>{};
    for (final key in businessIn) {
      final snake = ZStudyLegacyCodec.camelToSnake(key);
      final aliasTarget = aliases[key];
      if (canonical.containsKey(snake) ||
          canonical.containsKey('${ZStudyLegacyCodec.kLegacyPrefix}$snake') ||
          (aliasTarget != null && canonical.containsKey(aliasTarget))) {
        covered.add(key);
      }
    }
    return covered;
  }

  /// Détecte les champs ayant reçu (ou nécessité) un **défaut défensif** lors de
  /// la migration de [legacy] — tracés au rapport (AD-10, jamais silencieux).
  /// **Ne throw jamais.**
  ///
  /// - `status` absent / non-`String` / hors des 6 valeurs legacy connues → le
  ///   codec applique le défaut `uploading` ⇒ champ `status` tracé.
  /// - une clé de **date** (`*_at`) portant un `int` implausible (année ∉
  ///   [1970, 9999]) ou une String non-ISO ⇒ valeur **laissée intacte** (jamais
  ///   de date fabriquée) ⇒ champ tracé.
  static List<String> _detectDefaults(Map<String, dynamic> legacy) {
    final defaults = <String>[];

    if (legacy.containsKey('status')) {
      final status = legacy['status'];
      if (status is! String || !_knownLegacyStatuses.contains(status)) {
        defaults.add('status');
      }
    }

    for (final entry in legacy.entries) {
      final snake = ZStudyLegacyCodec.camelToSnake(entry.key);
      if (!snake.endsWith('_at')) continue;
      final value = entry.value;
      if (value is int) {
        if (value < 0 || value > _maxPlausibleMillis) defaults.add(snake);
      } else if (value is String) {
        if (DateTime.tryParse(value) == null) defaults.add(snake);
      }
    }

    return defaults;
  }

  /// Borne haute de plausibilité d'un horodatage millis (`9999-12-31T23:59:59Z`).
  static const int _maxPlausibleMillis = 253402300799999;
}
