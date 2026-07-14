@Tags(<String>['reserved-keys'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:reserved_keys_gate/reserved_keys_gate.dart';
import 'package:zcrud_core/zcrud_core.dart';
// H2 — le canal `source` (`ZFlashcardSource`/`ZCustomSource`) n'est observable
// que sur l'entité réelle qui le porte : `ZFlashcard`.
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Entité **volontairement fautive** (AC5 — contre-exemple mensonger PERMANENT).
///
/// Capture TOUT dans `extra` (y compris les clés réservées) et réémet
/// `is_deleted`/`updated_at` : c'est exactement le défaut des 2 findings HIGH
/// d'ES-1.3. Les assertions du harnais DOIVENT la rejeter — sans quoi elles
/// seraient tautologiquement vertes et ne prouveraient rien.
class _LyingEntity with ZExtensible {
  _LyingEntity.fromMap(Map<String, dynamic> map)
      : extra = Map<String, dynamic>.unmodifiable(map); // ⚠️ capture TOUT

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  Map<String, dynamic> toMap() => <String, dynamic>{...extra}; // ⚠️ réémet TOUT
}

/// Entité **sans** slot `extra` (patron `ZChoice`) — sert à prouver que le saut
/// de (a)/(b) n'est toléré que lorsqu'il est **DÉCLARÉ** (L1).
class _NotExtensible {
  const _NotExtensible();
}

/// Contre-exemple **PERMANENT et ISOLÉ** de l'assertion **(e)** (AC4 / R2).
///
/// ⚠️ **Isolée par règle** (R2 — la leçon la plus chère d'ES-1.4 : une fixture
/// qui déclenche 2 règles à la fois ne prouve AUCUNE des deux) : cette entité est
/// **VERTE sur (a), (b), (c) et (d)** —
///   - (a) elle dépouille les clés réservées (`ZSyncMeta.stripReserved`) ;
///   - (b) elle PRÉSERVE la clé inconnue dans `extra` ;
///   - (c)/(d) son `toMap` ne réémet ni `is_deleted` ni `updated_at` —
/// et **SEULE (e)** peut la faire rougir : son `toMap` **omet `...extra`**, donc
/// la clé inconnue **ne survit pas au round-trip**. C'est exactement le mode de
/// destruction de DW-ES14-1 vu depuis la sortie (`decode` correct, `encode`
/// amnésique). Si (e) ne mord pas ici, (e) ne mord nulle part.
class _ExtraDroppingEntity with ZExtensible {
  _ExtraDroppingEntity.fromMap(Map<String, dynamic> map)
      : extra = Map<String, dynamic>.unmodifiable(
          ZSyncMeta.stripReserved(map), // ✅ (a) : clés de sync écartées
        );

  @override
  final Map<String, dynamic> extra; // ✅ (b) : clé inconnue préservée

  @override
  ZExtension? get extension => null;

  /// ⛔ **Omet `...extra`** — la clé inconnue est DÉTRUITE au ré-encodage.
  Map<String, dynamic> toMap() => <String, dynamic>{'id': extra['id']};
}

/// Clé du **canal hors-codegen** de [_ChannelLeakingEntity] — présente dans le
/// corps de sonde (le domaine la CONNAÎT), **absente** de ses clés réservées.
const String kLeakedChannelKey = 'zz_canal_hors_codegen';

/// Contre-exemple **PERMANENT et ISOLÉ** de l'assertion **(f)** (H1, ES-2.1 / R2).
///
/// ⚠️ **Isolée par règle** : cette entité est **VERTE sur (a), (b), (c), (d) et
/// (e)** —
///   - (a) elle dépouille les clés réservées (`ZSyncMeta.stripReserved`) ;
///   - (b) elle PRÉSERVE la clé inconnue dans `extra` ;
///   - (c)/(d) son `toMap` ne réémet ni `is_deleted` ni `updated_at` ;
///   - (e) son `toMap` étale `...extra` ⇒ la clé inconnue SURVIT au round-trip —
/// et **SEULE (f)** peut la faire rougir : elle déclare un **canal hors-codegen**
/// ([kLeakedChannelKey], porté par son corps de sonde — donc **connu du
/// domaine**) mais **OUBLIE de le RÉSERVER** ⇒ le canal atterrit dans `extra`.
///
/// C'est **exactement** le mode de destruction que l'injection `kLearningKey`
/// d'ES-2.1 a mis en évidence — et que le gate laissait passer **EN VERT**.
/// Si (f) ne mord pas ici, (f) ne mord nulle part.
class _ChannelLeakingEntity with ZExtensible {
  _ChannelLeakingEntity.fromMap(Map<String, dynamic> map)
      : channel = map[kLeakedChannelKey],
        extra = Map<String, dynamic>.unmodifiable(<String, dynamic>{
          for (final e in ZSyncMeta.stripReserved(map).entries)
            // ⛔ `_reservedKeys` = {'id'} SEULEMENT : le canal hors-codegen
            //    `kLeakedChannelKey` a été OUBLIÉ ⇒ il tombe dans `extra`.
            if (e.key != 'id') e.key: e.value,
        });

  /// Le canal, décodé « à la main » (patron `ZFlashcard.source`).
  final Object? channel;

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  /// Réémet `...extra` (⇒ (e) VERTE) **et** le canal à la main ⇒ le canal est
  /// écrit **DEUX FOIS** : la perte silencieuse que (f) dénonce.
  Map<String, dynamic> toMap() => <String, dynamic>{
        ...extra,
        'id': 'x',
        kLeakedChannelKey: channel,
      };
}

/// Contre-exemple **PERMANENT et ISOLÉ** de l'assertion **(i.1)** (AC11 / R2).
///
/// ⚠️ **Isolée par règle** : cette entité est **VERTE sur (a)(b)(c)(d)(e)(f)** —
/// son `fromMap` **dépouille** correctement les clés réservées, et son `toMap`
/// **ne réémet** ni `is_deleted` ni `updated_at` **tant qu'on ne l'a pas ÉCRITE**.
/// **SEULE (i.1)** peut la faire rougir : sa **voie d'écriture** (`withExtra`,
/// ici un `copyWith`-like) **NE FILTRE PAS**, et son `toMap` étale `...extra`
/// **nuement** ⇒ le filtre est **ROUVERT**.
///
/// C'est **exactement** le défaut mesuré sur **8 entités sur 9** avant ES-2.2b :
/// la garde n'était posée qu'à la frontière d'**ENTRÉE**. Si (i.1) ne mord pas
/// ici, (i.1) ne mord nulle part.
class _ExtraReopeningEntity with ZExtensible {
  _ExtraReopeningEntity._(this.extra);

  /// ✅ Frontière d'ENTRÉE : correctement filtrée ⇒ (a)/(b) VERTES.
  factory _ExtraReopeningEntity.fromMap(Map<String, dynamic> map) =>
      _ExtraReopeningEntity._(
        Map<String, dynamic>.unmodifiable(ZSyncMeta.stripReserved(map)),
      );

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  /// ⛔ **LA VOIE D'ÉCRITURE NE FILTRE PAS** — le défaut, isolé.
  _ExtraReopeningEntity withExtra(Map<String, dynamic> x) =>
      _ExtraReopeningEntity._(Map<String, dynamic>.unmodifiable(x));

  /// ⛔ Étale `...extra` **nuement** : pas de garde à la SORTIE non plus.
  /// (Étale `...extra` ⇒ (e) VERTE : la clé inconnue survit au round-trip.)
  Map<String, dynamic> toMap() => <String, dynamic>{...extra};
}

/// Contre-exemple **PERMANENT et ISOLÉ** de l'assertion **(i.2)** (AC11 / R2).
///
/// ⚠️ **Isolée par règle** : cette entité est **VERTE sur (a)(b)(c)(d)(e)(f) ET
/// (i.1)** — elle dépouille à l'ENTRÉE **et** à l'ÉCRITURE **et** à la SORTIE.
/// **SEULE (i.2)** peut la faire rougir : son `operator ==` compare `extra` avec
/// un `==` **SUPERFICIEL** (le `_mapEquals` qui était copié dans 3 packages).
///
/// C'est le défaut **DW-ES22-4** : invisible sur un `extra` **scalaire**, fatal
/// dès que `extra` porte du JSON **imbriqué** — c.-à-d. **sa raison d'être**.
class _ShallowExtraEqualityEntity with ZExtensible {
  _ShallowExtraEqualityEntity._(this.extra);

  factory _ShallowExtraEqualityEntity.fromMap(Map<String, dynamic> map) =>
      _ShallowExtraEqualityEntity._(_sanitize(map));

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  /// ✅ La garde partagée, aux TROIS frontières ⇒ (i.1) VERTE.
  static Map<String, dynamic> _sanitize(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, ZSyncMeta.reservedKeys);

  _ShallowExtraEqualityEntity withExtra(Map<String, dynamic> x) =>
      _ShallowExtraEqualityEntity._(_sanitize(x));

  Map<String, dynamic> toMap() => <String, dynamic>{..._sanitize(extra)};

  /// ⛔ **ÉGALITÉ SUPERFICIELLE** sur `extra` — le défaut, isolé.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ShallowExtraEqualityEntity && _shallowMapEquals(extra, other.extra);

  @override
  int get hashCode {
    var h = 0;
    for (final e in extra.entries) {
      h ^= Object.hash(e.key, e.value); // ⛔ hash superficiel, lui aussi.
    }
    return h;
  }
}

/// Jumelle **SAINE** de [_ShallowExtraEqualityEntity] : égalité **PROFONDE**
/// réelle (`zJsonEquals`). Sert **UNIQUEMENT** de fixture à l'anti-inertie du
/// skip d'(i.2).
///
/// ⚠️ **Pourquoi une fixture DÉDIÉE, et non `study_folder`** : le premier jet de
/// ce test empruntait l'entité de PRODUCTION `study_folder`. L'injection de
/// régression n° 3 (rétablir l'`==` superficiel sur `ZStudyFolder`) le faisait
/// alors rougir **AUSSI** — un rouge PARASITE, qui ne dit rien de l'anti-inertie.
/// Une fixture ne doit **jamais** dépendre du comportement d'une entité de
/// production (esprit **R2** : une fixture par règle, et une seule).
class _DeepExtraEqualityEntity with ZExtensible {
  _DeepExtraEqualityEntity.fromMap(Map<String, dynamic> map)
      : extra = zSanitizeExtra(map, ZSyncMeta.reservedKeys);

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _DeepExtraEqualityEntity && zJsonEquals(extra, other.extra);

  @override
  int get hashCode => zJsonHash(extra);
}

/// Voie d'écriture de [_ExtraReopeningEntity] (fixture d'(i.1)).
final ZExtraWriter _reopenWriter = ZExtraWriter(
  voie: 'withExtra',
  eagerlyNormalized: true,
  write: (Object e, Map<String, dynamic> x) =>
      (e as _ExtraReopeningEntity).withExtra(x),
);

/// 🔴 Le patron de PRODUCTION, isolé (remédiation ES-2.2b) : constructeur
/// **`const`** (incapable de filtrer — AD-10 y interdit l'`assert`) + **ACCESSEUR**
/// `extra` qui **NORMALISE** à la lecture (`zNormalizeExtra`).
///
/// C'est la fixture **témoin** : elle doit être **VERTE** sur (i.1) par ses DEUX
/// voies (ctor **et** `copyWith`). Sa jumelle fautive est [_ConstCtorRawEntity].
class _ConstCtorGuardedEntity with ZExtensible {
  const _ConstCtorGuardedEntity({
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  factory _ConstCtorGuardedEntity.fromMap(Map<String, dynamic> map) =>
      _ConstCtorGuardedEntity(extra: _sanitize(map)); // normalisation EAGER

  /// Slot BRUT (le ctor `const` le stocke tel quel).
  final Map<String, dynamic> _extra;

  /// ✅ **LA GARDE** — le seul point que TOUTES les voies traversent.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reserved);

  @override
  ZExtension? get extension => null;

  static const Set<String> _reserved = <String>{'id', ...ZSyncMeta.reservedKeys};

  static Map<String, dynamic> _sanitize(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reserved);

  /// ✅ Normalisation EAGER (le slot stocké reste propre ⇒ lecture zéro-copie).
  _ConstCtorGuardedEntity copyWith({Map<String, dynamic>? extra}) =>
      _ConstCtorGuardedEntity(
        extra: extra == null ? this.extra : _sanitize(extra),
      );

  /// Étale l'**ACCESSEUR** (jamais `_extra`).
  Map<String, dynamic> toMap() => <String, dynamic>{...extra};
}

/// ⛔ Jumelle **FAUTIVE** de [_ConstCtorGuardedEntity] : accesseur **SANS garde**
/// (il rend le slot BRUT). Le défaut **HIGH-2** exact — et, via `toMap()`, le
/// défaut **HIGH-1** (persistance) sur la voie CTOR.
///
/// ⚠️ **Isolée par règle (R2)** : elle est **VERTE sur (a)(b)(c)(d)(e)(f)** — son
/// `fromMap` normalise EAGER, donc une instance DÉCODÉE est propre. **SEULE** une
/// écriture par la **voie CTOR** la fait rougir.
class _ConstCtorRawEntity with ZExtensible {
  const _ConstCtorRawEntity({
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  factory _ConstCtorRawEntity.fromMap(Map<String, dynamic> map) =>
      _ConstCtorRawEntity(
        extra: zSanitizeExtra(map, _ConstCtorGuardedEntity._reserved),
      );

  final Map<String, dynamic> _extra;

  /// ⛔ **AUCUNE GARDE** : le slot brut est exposé tel quel.
  @override
  Map<String, dynamic> get extra => _extra;

  @override
  ZExtension? get extension => null;

  Map<String, dynamic> toMap() => <String, dynamic>{...extra};
}

/// Voie CTOR de [_ConstCtorGuardedEntity] — `x` passé **VERBATIM**.
final ZExtraWriter _constCtorWriter = ZExtraWriter(
  voie: 'ctor',
  eagerlyNormalized: false, // ctor `const` : le slot stocké reste BRUT.
  write: (Object e, Map<String, dynamic> x) =>
      _ConstCtorGuardedEntity(extra: x),
);

/// Voie `copyWith` de [_ConstCtorGuardedEntity] — `x` passé **VERBATIM**.
final ZExtraWriter _constCopyWithWriter = ZExtraWriter(
  voie: 'copyWith',
  eagerlyNormalized: true,
  write: (Object e, Map<String, dynamic> x) =>
      (e as _ConstCtorGuardedEntity).copyWith(extra: x),
);

/// Voie CTOR de [_ConstCtorRawEntity] (accesseur non gardé).
final ZExtraWriter _rawCtorWriter = ZExtraWriter(
  voie: 'ctor',
  eagerlyNormalized: false,
  write: (Object e, Map<String, dynamic> x) => _ConstCtorRawEntity(extra: x),
);

/// L'ancien `_mapEquals` **SUPERFICIEL** — reproduit ici, et NULLE PART AILLEURS
/// dans le repo (les 7 copies sont supprimées).
bool _shallowMapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
  if (a.length != b.length) return false;
  for (final e in a.entries) {
    if (!b.containsKey(e.key) || b[e.key] != e.value) return false;
  }
  return true;
}

void main() {
  final registry = buildRegistry();

  group('AD-19.1.c — volet (A) comportemental : clés de sync réservées', () {
    // ---------------------------------------------------------------------
    // Cohérence du CÂBLAGE (anti-pourrissement, AC2) — un kind enregistré sans
    // corps de sonde produirait un trou silencieux (sonde muette = faux vert).
    // ---------------------------------------------------------------------
    test('chaque kind enregistré a un corps de sonde (dans les deux sens)', () {
      final kinds = registry.kinds.toSet();
      expect(kinds, isNotEmpty, reason: 'kRegistrars est vide : gate muet.');
      expect(
        kinds.difference(kProbeBodies.keys.toSet()),
        isEmpty,
        reason: 'kind(s) enregistré(s) sans corps dans `kProbeBodies` '
            '(registrars.dart) — sonde muette = faux vert.',
      );
      // Sens inverse : entrée MORTE (corps d'un kind disparu).
      expect(
        kProbeBodies.keys.toSet().difference(kinds),
        isEmpty,
        reason: 'corps de sonde ORPHELIN (kind non enregistré) — nettoyer '
            '`kProbeBodies`.',
      );
    });

    // ---------------------------------------------------------------------
    // (a)(b)(c)(d)(e) sur CHAQUE kind enregistré — **VOIE REGISTRE** de bout en
    // bout (`registry.decode` → `registry.encode`), c.-à-d. EXACTEMENT le chemin
    // de `FirebaseZRepositoryImpl.fromRegistry`.
    //
    // ⚠️ ES-2.0 / DW-ES14-1 : avant le correctif du générateur, cette voie était
    // INTENABLE (le registrar câblait `_$ZXxxFromMap`, qui ne peuple pas `extra`
    // ⇒ (a) vacuellement verte, (b)/(e) structurellement rouges). Le harnais
    // devait alors décoder par une table manuelle `kDomainDecoders` — déviation
    // désormais SUPPRIMÉE : `registry.decode` EST la voie de domaine.
    // ---------------------------------------------------------------------
    for (final kind in kProbeBodies.keys) {
      test('$kind : sonde polluée → decode/encode REGISTRE propres (a→e)', () {
        final probe = buildProbe(kProbeBodies[kind]!);
        final entity = registry.decode(kind, probe);
        final encoded = registry.encode(kind, entity);

        assertReservedKeysClean(
          label: kind,
          entity: entity,
          encoded: encoded,
          legacyMirrorAllowed: kLegacyUpdatedAtMirrors.contains(kind),
          // L1 / D3 : le saut de (a)/(b)/(e) est DÉCLARÉ, jamais silencieux.
          expectExtensible: !kNonExtensibleKinds.contains(kind),
          // (f) — H1 (ES-2.1) : AUCUNE clé du CORPS de sonde ne doit atterrir
          // dans `extra`. GÉNÉRIQUE : couvre `source`, `learning` et TOUT canal
          // hors-codegen futur, sans une ligne de code par entité. Ses DENTS
          // viennent de la règle (g) du volet AST (le canal DOIT être sondé).
          probeBody: kProbeBodies[kind]!,
        );
      });

      // AD-10 — désérialisation DÉFENSIVE : la voie registre ne throw JAMAIS,
      // même sur une map vide (le swap vers la factory de domaine ne l'a pas
      // dégradée : elle sanitise en plus — clamps `ZRepetitionInfo`).
      test('$kind : registry.decode({}) ne lève pas (AD-10)', () {
        expect(() => registry.decode(kind, <String, dynamic>{}), returnsNormally);
      });

      // ─────────────────────────────────────────────────────────────────────
      // 🔴 (i.1) — DW-ES22-3 : la VOIE D'ÉCRITURE PUBLIQUE de `extra`.
      //
      // Les 6 assertions (a)…(f) ci-dessus sondent TOUTES `registry.decode` — la
      // frontière d'ENTRÉE. AUCUNE ne regarde une voie d'ÉCRITURE applicative :
      // angle mort STRUCTUREL, sous lequel **8 entités sur 9** étaient cassées.
      // ─────────────────────────────────────────────────────────────────────
      if (!kNonExtensibleKinds.contains(kind)) {
        // 🔴 REMÉDIATION HIGH-1/HIGH-2 : **TOUTES** les voies publiques, pas la
        // plus sûre. La v1 ne câblait que `copyWith` (qui filtre déjà) ⇒ l'entité
        // encodée avait un `extra` DÉJÀ PROPRE ⇒ (i.1a)/(i.1b) n'exigeaient la
        // garde de sortie sur AUCUNE entité (sauf `repetition_info`), et la voie
        // CTOR — polluante — n'était sondée nulle part.
        for (final writer in kExtraWriters[kind]!) {
          test(
              '$kind : (i.1) voie `${writer.voie}` — l\'écriture de `extra` ne '
              'rouvre PAS le filtre', () {
            final entity = registry.decode(kind, buildProbe(kProbeBodies[kind]!));
            assertExtraWriteSanitized(
              label: '$kind#${writer.voie}',
              entity: entity,
              writer: writer,
              encode: (Object e) => registry.encode(kind, e),
              legacyMirrorAllowed: kLegacyUpdatedAtMirrors.contains(kind),
            );
          });
        }

        // ───────────────────────────────────────────────────────────────────
        // 🔴 (i.2) — DW-ES22-4 : égalité/hash PROFONDS d'`extra`.
        // ZÉRO code par entité (ne consomme que `registry.decode` + `==`).
        // ───────────────────────────────────────────────────────────────────
        test('$kind : (i.2) `extra` IMBRIQUÉ ⇒ égalité/hash PROFONDS', () {
          assertExtraDeepEquality(
            label: kind,
            probeBody: kProbeBodies[kind]!,
            decode: (Map<String, dynamic> m) => registry.decode(kind, m),
            // Tous les kinds du REGISTRE ont un `==` de valeur (seules les 2
            // sondes MANUELLES ne l'ont pas — cf. `kNoValueEqualityProbes`).
            expectValueEquality: true,
          );
        });
      }
    }

    // ---------------------------------------------------------------------
    // Entités `ZExtensible` HORS registre (ZMindmap/ZMindmapNode) — MÊMES
    // assertions, SANS allowlist.
    // ---------------------------------------------------------------------
    for (final probe in kManualProbes) {
      test('${probe.className} (sonde manuelle, hors registre) : mêmes assertions',
          () {
        final map = buildProbe(probe.body);
        final entity = probe.decode(map);
        assertReservedKeysClean(
          label: probe.className,
          entity: entity,
          encoded: probe.encode(entity),
          legacyMirrorAllowed: false, // aucune exception hors registre.
          expectExtensible: true, // sondées PARCE QU'elles portent un `extra`.
          probeBody: probe.body, // (f)
        );
      });

      // (i.1) — leur voie d'écriture est le CONSTRUCTEUR NOMINAL (aucun
      // `copyWith` public : « la mutation passe EXCLUSIVEMENT par TreeOps »).
      // MESURÉ CASSÉ : leur `toJson()` réémettait `updated_at` ET `is_deleted`,
      // en contradiction directe avec sa propre dartdoc « INVARIANT AD-16 ».
      for (final writer in probe.writes) {
        test(
            '${probe.className} : (i.1) voie `${writer.voie}` — ne rouvre pas le '
            'filtre', () {
          final entity = probe.decode(buildProbe(probe.body));
          assertExtraWriteSanitized(
            label: '${probe.className}#${writer.voie}',
            entity: entity,
            writer: writer,
            encode: probe.encode,
            legacyMirrorAllowed: false, // aucun miroir hors registre.
          );
        });
      }

      // (i.2) — SKIP DÉCLARÉ ET CONTRÔLÉ (R6) : ces deux entités n'ont AUCUN
      // `operator ==` (dette DW-ES22-5). L'assertion vérifie que l'égalité est
      // bien ABSENTE ⇒ le jour où elle apparaît, l'entrée est MORTE et ROUGIT.
      test('${probe.className} : (i.2) skip DÉCLARÉ (DW-ES22-5) — anti-inertie',
          () {
        assertExtraDeepEquality(
          label: probe.className,
          probeBody: probe.body,
          decode: probe.decode,
          expectValueEquality:
              !kNoValueEqualityProbes.contains(probe.className),
        );
      });
    }
  });

  // =========================================================================
  // 🔴 AC9 — LA MACHINE (R1) : couverture BIDIRECTIONNELLE de `kExtraWriters`.
  //
  // C'est LE livrable de la story ES-2.2b. Corriger les 8 entités à la main NE
  // SUFFIT PAS : les 6 entités restantes d'ES-2 (ES-2.3…2.8) reproduiraient le
  // défaut — les 8 déjà livrées l'ont TOUTES reproduit, c'est mesuré.
  //
  // ⇒ Une entité `ZExtensible` **ne peut pas naître sans son writer**, donc ne
  //   peut pas échapper à (i.1)/(i.2). La parade devient une MACHINE, pas une
  //   discipline.
  // =========================================================================
  group('AC9 — `kExtraWriters` : couverture BIDIRECTIONNELLE (la MACHINE)', () {
    test('tout kind `ZExtensible` enregistré A un writer (trou ⇒ ROUGE)', () {
      final extensibleKinds =
          registry.kinds.toSet().difference(kNonExtensibleKinds);
      expect(extensibleKinds, isNotEmpty, reason: 'gate muet.');
      expect(
        extensibleKinds.difference(kExtraWriters.keys.toSet()),
        isEmpty,
        reason:
            '🔴 TROU DE COUVERTURE : ce/ces kind(s) `ZExtensible` sont enregistrés '
            'SANS voie d\'écriture dans `kExtraWriters` (registrars.dart) — les '
            'assertions (i.1) et (i.2) ne les atteindraient JAMAIS.\n'
            '\n'
            'C\'est le défaut que la story ES-2.2b existe pour rendre IMPOSSIBLE : '
            'les 8 entités livrées avant elle ont TOUTES reproduit le même bug '
            '(`copyWith`/constructeur rouvrant le filtre des clés réservées) '
            'parce que RIEN ne l\'observait.\n'
            '\n'
            'GESTE : ajouter la VOIE D\'ÉCRITURE PUBLIQUE du kind à '
            '`kExtraWriters` — `copyWith(extra:)` si l\'entité en offre un, SINON '
            'le CONSTRUCTEUR NOMINAL (3 entités sur 9 n\'ont AUCUN `copyWith`).',
      );
    });

    test('aucun writer ORPHELIN (entrée morte ⇒ ROUGE — anti-inertie)', () {
      expect(
        kExtraWriters.keys.toSet().difference(registry.kinds.toSet()),
        isEmpty,
        reason: 'writer ORPHELIN dans `kExtraWriters` : le kind n\'est plus '
            'enregistré — retirer l\'entrée (sinon la table se fossilise).',
      );
    });

    // 🔴 REMÉDIATION HIGH-1/HIGH-2 : la voie CTOR (celle que le harnais NE
    // sondait PAS) est OBLIGATOIRE. Sans elle, (i.1a)/(i.1b) n'encodent que des
    // entités à l'`extra` DÉJÀ PROPRE ⇒ la garde de sortie n'est exigée par
    // AUCUNE machine (mesuré : 8 entités sur 9 restaient vertes sans elle).
    //
    // ⚠️ CE TEST NE REMPLACE PAS la règle AST **(j)** (gate) : ici on exige la
    // PRÉSENCE du ctor ; (j), elle, DÉRIVE DU DISQUE **toutes** les voies
    // publiques de l'entité (ctor + `copyWith` + toute méthode à paramètre
    // `extra`) et interdit d'en omettre une. Les deux sont nécessaires : ce test
    // tourne partout (même hors CI), (j) est exhaustive.
    test('CHAQUE kind câble la voie `ctor` (la voie NON filtrante)', () {
      for (final entry in kExtraWriters.entries) {
        final voies = entry.value.map((w) => w.voie).toList();
        expect(
          voies,
          contains('ctor'),
          reason:
              '🔴 [${entry.key}] la voie CONSTRUCTEUR n\'est pas câblée. C\'est LA '
              'voie que le harnais « oubliait » (code-review ES-2.2b/HIGH-1) : elle '
              'seule écrit un `extra` POLLUÉ dans le slot stocké, donc elle seule '
              'EXERCE la garde de l\'accesseur. Sans elle, (i.1a)/(i.1b)/(i.1c) '
              'sont vertes SANS RIEN PROUVER.',
        );
        expect(
          voies.toSet(),
          hasLength(voies.length),
          reason: '[${entry.key}] voie DUPLIQUÉE dans `kExtraWriters` : deux '
              'entrées de même nom masqueraient l\'une des deux dans les rapports.',
        );
      }
    });

    test('aucun writer sur un kind NON-`ZExtensible` (il n\'a pas d\'`extra`)',
        () {
      expect(
        kExtraWriters.keys.toSet().intersection(kNonExtensibleKinds),
        isEmpty,
        reason: '`kExtraWriters` cible un kind déclaré NON-`ZExtensible` — il n\'a '
            'aucun slot `extra` : (i.1) y serait structurellement ROUGE.',
      );
    });

    // 🔴 MAJEUR-1 (code-review ES-2.2b) — `kConstCtorOnlyWriters` **N'EXISTE
    // PLUS**. Ce test en interdit le RETOUR sous une autre forme.
    //
    // Cette liste exemptait d'(i.1c) les kinds « à ctor `const` », et son unique
    // anti-inertie exigeait `leaked isNotEmpty` — c.-à-d. **LA PRÉSENCE DU DÉFAUT
    // LUI-MÊME** : on s'exemptait de (i.1c) EN COMMETTANT ce que (i.1c) attrape.
    // MESURÉ : `copyWith` de `ZStudyDocument` cessant de filtrer + ajout de
    // `'study_document'` à la liste ⇒ **81/81 VERTS**.
    //
    // Le correctif n'est PAS un verrou d'égalité sur l'exemption : c'est sa
    // **SUPPRESSION**. L'accesseur `extra` (`zNormalizeExtra`) normalise à la
    // LECTURE ⇒ **aucune** entité n'a plus besoin d'être exemptée d'(i.1c).
    // ⛔ Toute réintroduction d'une exemption d'(i.1c) est une DÉCISION
    // D'ARCHITECTURE (et un aveu que la garde d'accesseur a été abandonnée).
    test('MAJEUR-1 : (i.1c) n\'a AUCUNE liste d\'exemption (elle est SUPPRIMÉE)',
        () {
      // Le seul « skip » restant du harnais est celui d'(i.2) — et il est, lui,
      // VERROUILLÉ PAR ÉGALITÉ (ci-dessous). Aucun kind du registre n'est
      // exempté de quoi que ce soit.
      for (final kind in kExtraWriters.keys) {
        expect(
          kNoValueEqualityProbes.contains(kind),
          isFalse,
          reason: 'un kind du REGISTRE ne peut PAS figurer dans une liste de skip '
              'réservée aux sondes MANUELLES.',
        );
      }
    });

    test(
        '`kNoValueEqualityProbes` : VERROU D\'ÉGALITÉ FIGÉ + anti-inertie '
        '(MEDIUM-1)', () {
      // 🔴 MEDIUM-1 (code-review ES-2.2b) — patron `kLegacyUpdatedAtMirrors` :
      // sans verrou FIGÉ, une future entité `ZExtensible` écrite à la main
      // pouvait s'EXEMPTER d'(i.2) en s'ajoutant à la liste — l'anti-inertie
      // (« je n'ai pas d'`==` ») étant satisfaite PAR LE DÉFAUT LUI-MÊME.
      // Une exemption ne doit JAMAIS pouvoir s'auto-attribuer.
      expect(
        kNoValueEqualityProbes,
        equals(<String>{'ZMindmap', 'ZMindmapNode'}),
        reason:
            '`kNoValueEqualityProbes` a changé. C\'est une DÉCISION D\'ARCHITECTURE '
            '(dette DW-ES22-5), pas un ajout discret : on ne « passe pas le gate » '
            'en y glissant son entité. RÉDUCTION = la dette se solde ⇒ mettre à '
            'jour architecture.md.',
      );
      final manual = kManualProbes.map((p) => p.className).toSet();
      expect(
        kNoValueEqualityProbes.difference(manual),
        isEmpty,
        reason: 'entrée MORTE dans `kNoValueEqualityProbes` : cette classe n\'est '
            'plus une sonde manuelle — retirer l\'entrée (sinon le skip de (i.2) '
            'se fossilise).',
      );
    });
  });

  group('AD-19.2 — allowlist legacy : VERROU + anti-inertie', () {
    test('VERROU : l\'ensemble est FIGÉ (toute croissance/réduction = ROUGE)',
        () {
      expect(
        kLegacyUpdatedAtMirrors,
        equals(<String>{'study_folder', 'flashcard'}),
        reason:
            'kLegacyUpdatedAtMirrors a changé. Élargir l\'allowlist est une '
            'DÉCISION D\'ARCHITECTURE (AD-19.2) : mettre à jour architecture.md '
            'et justifier en code-review — on ne « passe pas le gate » en y '
            'ajoutant discrètement son kind.',
      );
    });

    test('anti-inertie : chaque entrée correspond à un kind RÉELLEMENT enregistré',
        () {
      for (final kind in kLegacyUpdatedAtMirrors) {
        expect(
          registry.isRegistered(kind),
          isTrue,
          reason: 'entrée MORTE `$kind` dans kLegacyUpdatedAtMirrors : le kind '
              'n\'est plus enregistré — retirer l\'entrée.',
        );
      }
    });
  });

  group('L1 — anti-vacuité : le saut de (a)/(b) est DÉCLARÉ, jamais silencieux',
      () {
    test('`kNonExtensibleKinds` ne contient que des kinds RÉELLEMENT enregistrés',
        () {
      expect(
        kNonExtensibleKinds.difference(registry.kinds.toSet()),
        isEmpty,
        reason: 'entrée MORTE dans `kNonExtensibleKinds` : le kind n\'est plus '
            'enregistré — retirer l\'entrée (sinon la liste se fossilise et '
            'exempterait un jour une VRAIE entité de (a)/(b)).',
      );
    });

    test('MORD : entité NON-ZExtensible là où on en attendait une (vacuité)', () {
      // Simule un registrar recâblé par erreur vers un type sans `extra` :
      // sans la garde, (a)/(b) auraient été SAUTÉES en silence — gate vert, zéro
      // protection.
      expect(
        () => assertExtraClean(
          label: 'kind_extensible_attendu',
          entity: const _NotExtensible(),
          expectExtensible: true,
          probeBody: const <String, dynamic>{},
        ),
        throwsA(isA<TestFailure>()),
        reason: 'un skip NON attendu de (a)/(b) doit être ROUGE, pas silencieux.',
      );
    });

    test('MORD : `kNonExtensibleKinds` PÉRIMÉE (l\'entité est devenue extensible)',
        () {
      final lying = _LyingEntity.fromMap(
        buildProbe(const <String, dynamic>{'id': 'x'}),
      );
      expect(
        () => assertExtraClean(
          label: 'kind_declare_non_extensible',
          entity: lying,
          expectExtensible: false,
          probeBody: const <String, dynamic>{},
        ),
        throwsA(isA<TestFailure>()),
        reason: 'une entité `ZExtensible` déclarée « non extensible » serait '
            'exemptée à tort de (a)/(b).',
      );
    });

    test('TOLÈRE le skip ATTENDU (ZChoice / flashcard_choice)', () {
      // Le seul cas légitime : le kind est DANS `kNonExtensibleKinds`.
      assertExtraClean(
        label: 'flashcard_choice',
        entity: const _NotExtensible(),
        expectExtensible: false,
        probeBody: const <String, dynamic>{},
      ); // ne throw pas
    });
  });

  group('AC5 — contre-exemple mensonger : le gate MORD', () {
    test('_LyingEntity échoue sur (a)/(b)/(c)/(d)', () {
      final lying = _LyingEntity.fromMap(
        buildProbe(const <String, dynamic>{'id': 'x'}),
      );

      expect(
        () => assertReservedKeysClean(
          label: '_LyingEntity',
          entity: lying,
          encoded: lying.toMap(),
          legacyMirrorAllowed: false,
          expectExtensible: true,
          // R2 — ISOLATION : ces fixtures synthétiques n'ont AUCUN schéma (tout
          // atterrit dans `extra`). Un corps de sonde NON VIDE ferait rougir (f)
          // AUSSI, et la fixture ne prouverait plus la règle qu'elle vise. (f) a
          // sa PROPRE fixture isolée : `_ChannelLeakingEntity`.
          probeBody: const <String, dynamic>{},
        ),
        throwsA(isA<TestFailure>()),
        reason: 'les assertions doivent MORDRE sur une entité fautive.',
      );

      // Portée MINIMALE de l'allowlist : même « legacy », (a) et (c) rejettent.
      expect(
        () => assertReservedKeysClean(
          label: '_LyingEntity#legacy',
          entity: lying,
          encoded: lying.toMap(),
          legacyMirrorAllowed: true,
          expectExtensible: true,
          // R2 — ISOLATION : ces fixtures synthétiques n'ont AUCUN schéma (tout
          // atterrit dans `extra`). Un corps de sonde NON VIDE ferait rougir (f)
          // AUSSI, et la fixture ne prouverait plus la règle qu'elle vise. (f) a
          // sa PROPRE fixture isolée : `_ChannelLeakingEntity`.
          probeBody: const <String, dynamic>{},
        ),
        throwsA(isA<TestFailure>()),
        reason: 'l\'allowlist ne couvre QUE (d) : (a)/(b)/(c) restent sans '
            'exception, miroirs legacy compris.',
      );
    });

    test('(a) mord : clé réservée capturée dans extra', () {
      final lying = _LyingEntity.fromMap(
        buildProbe(const <String, dynamic>{'id': 'x'}),
      );
      expect(lying.extra.containsKey(ZSyncMeta.kIsDeleted), isTrue);
      expect(
        () => assertExtraClean(
          label: '_LyingEntity',
          entity: lying,
          expectExtensible: true,
          // R2 — ISOLATION : ces fixtures synthétiques n'ont AUCUN schéma (tout
          // atterrit dans `extra`). Un corps de sonde NON VIDE ferait rougir (f)
          // AUSSI, et la fixture ne prouverait plus la règle qu'elle vise. (f) a
          // sa PROPRE fixture isolée : `_ChannelLeakingEntity`.
          probeBody: const <String, dynamic>{},
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(c) mord SANS exception, même sous allowlist legacy', () {
      expect(
        () => assertEncodedClean(
          label: '_encoded',
          encoded: <String, dynamic>{ZSyncMeta.kIsDeleted: true},
          legacyMirrorAllowed: true,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(d) mord hors allowlist et TOLÈRE sous allowlist', () {
      expect(
        () => assertEncodedClean(
          label: '_encoded',
          encoded: <String, dynamic>{ZSyncMeta.kUpdatedAt: kProbeUpdatedAt},
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
      );
      assertEncodedClean(
        label: '_encoded#legacy',
        encoded: <String, dynamic>{ZSyncMeta.kUpdatedAt: kProbeUpdatedAt},
        legacyMirrorAllowed: true,
      ); // ne throw pas
    });

    test('anti-inertie : une entrée d\'allowlist qui n\'émet plus updated_at mord',
        () {
      expect(
        () => assertEncodedClean(
          label: '_encoded#dead',
          encoded: const <String, dynamic>{'title': 'x'},
          legacyMirrorAllowed: true,
        ),
        throwsA(isA<TestFailure>()),
      );
    });
  });

  // =========================================================================
  // (e) — DW-ES14-1 : le round-trip REGISTRE préserve la clé inconnue.
  // Contre-exemple PERMANENT et ISOLÉ PAR RÈGLE (R2) : `_ExtraDroppingEntity`
  // est VERTE sur (a)(b)(c)(d) — SEULE (e) peut la faire rougir. Sans cette
  // isolation, un rouge ne prouverait pas que (e) mord (erreur exacte qui a
  // masqué H1 d'ES-1.4).
  // =========================================================================
  group('AC4 — assertion (e) : le round-trip AD-4 MORD (contre-exemple isolé)',
      () {
    _ExtraDroppingEntity dropper() => _ExtraDroppingEntity.fromMap(
          buildProbe(const <String, dynamic>{'id': 'x'}),
        );

    test('la fixture est VERTE sur (a)(b)(c)(d) — l\'isolation de (e) est RÉELLE',
        () {
      final e = dropper();
      // (a) : aucune clé de sync capturée. (b) : la clé inconnue survit au decode.
      assertExtraClean(
        label: '_ExtraDropping',
        entity: e,
        expectExtensible: true,
        probeBody: const <String, dynamic>{}, // R2 — cf. ci-dessus.
      );
      expect(e.extra[kProbeUnknownKey], kProbeUnknownValue);
      // (c)/(d) : l'encodage ne réémet ni `is_deleted` ni `updated_at`.
      assertEncodedClean(
        label: '_ExtraDropping',
        encoded: e.toMap(),
        legacyMirrorAllowed: false,
      );
    });

    test('(e) MORD : `toMap` sans `...extra` ⇒ clé inconnue DÉTRUITE au round-trip',
        () {
      final e = dropper();
      expect(
        () => assertUnknownKeyRoundTrip(
          label: '_ExtraDropping',
          entity: e,
          encoded: e.toMap(),
          expectExtensible: true,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'une entité qui perd la clé inconnue au ré-encodage DOIT rougir '
            '— c\'est le mode de destruction exact de DW-ES14-1.',
      );
      // Et la batterie complète rougit aussi (via (e) SEULE).
      expect(
        () => assertReservedKeysClean(
          label: '_ExtraDropping',
          entity: e,
          encoded: e.toMap(),
          legacyMirrorAllowed: false,
          expectExtensible: true,
          probeBody: const <String, dynamic>{}, // R2 — isolation de (e).
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(e) : skip NON DÉCLARÉ ⇒ ROUGE (une entité ZExtensible « exemptée »)',
        () {
      expect(
        () => assertUnknownKeyRoundTrip(
          label: 'kind_declare_non_extensible',
          entity: dropper(),
          encoded: const <String, dynamic>{},
          expectExtensible: false, // ⛔ mensonge : l'entité EST ZExtensible
        ),
        throwsA(isA<TestFailure>()),
        reason: 'exempter de (e) une entité extensible rendrait la destruction '
            'd\'`extra` invisible — le saut doit être DÉCLARÉ et VRAI.',
      );
    });

    test('(e) : skip ATTENDU toléré (ZChoice — non ZExtensible)', () {
      assertUnknownKeyRoundTrip(
        label: 'flashcard_choice',
        entity: const _NotExtensible(),
        encoded: const <String, dynamic>{},
        expectExtensible: false,
      ); // ne throw pas
    });
  });

  // =========================================================================
  // 🔴 (f) — H1 (code-review ES-2.1) : LE CORPS DE SONDE EST ENFIN OBSERVÉ.
  //
  // Avant (f), les 5 assertions du volet (A) ne regardaient QUE
  // `ZSyncMeta.reservedKeys` ((a)/(c)/(d)) et l'UNIQUE `kProbeUnknownKey`
  // ((b)/(e)). **AUCUNE ne regardait une clé du CORPS de sonde.** Le harnais
  // TRANSPORTAIT donc `source` (ES-2.0/H2) et `learning` (ES-2.1/D4) sans que
  // rien ne les OBSERVE : retirer `kLearningKey` de `_reservedKeys` laissait le
  // **gate VERT** (mesuré), et le seul filet qui mordait était un test écrit À LA
  // MAIN, par canal, dans un AUTRE package. R1 violé : rien n'aurait obligé le
  // PROCHAIN canal hors-codegen (ES-2.2 `ZSmartNote.content`, ES-2.5…) à naître
  // avec son observateur.
  //
  // (f) est GÉNÉRIQUE (zéro code par entité) et ses DENTS viennent de la règle
  // (g) du volet AST : un canal déclaré DOIT être porté par la sonde.
  //
  // Contre-exemple PERMANENT et ISOLÉ PAR RÈGLE (R2) : `_ChannelLeakingEntity`
  // est VERTE sur (a)(b)(c)(d)(e) — SEULE (f) peut la faire rougir.
  // =========================================================================
  group('(f) — H1/ES-2.1 : une clé du CORPS DE SONDE dans `extra` ⇒ ROUGE', () {
    const body = <String, dynamic>{
      'id': 'x',
      kLeakedChannelKey: <String, dynamic>{'payload': 'brut'},
    };

    _ChannelLeakingEntity leaker() =>
        _ChannelLeakingEntity.fromMap(buildProbe(body));

    test('la fixture est VERTE sur (a)(b)(c)(d)(e) — l\'isolation de (f) est RÉELLE',
        () {
      final e = leaker();
      // (a) : aucune clé de sync capturée. (b) : la clé inconnue survit au decode.
      assertExtraClean(
        label: '_ChannelLeaking',
        entity: e,
        expectExtensible: true,
        probeBody: const <String, dynamic>{}, // sonde VIDE ⇒ (f) neutralisée ici
      );
      expect(e.extra[kProbeUnknownKey], kProbeUnknownValue);
      // (c)/(d) : l'encodage ne réémet ni `is_deleted` ni `updated_at`.
      assertEncodedClean(
        label: '_ChannelLeaking',
        encoded: e.toMap(),
        legacyMirrorAllowed: false,
      );
      // (e) : la clé inconnue SURVIT au round-trip.
      assertUnknownKeyRoundTrip(
        label: '_ChannelLeaking',
        entity: e,
        encoded: e.toMap(),
        expectExtensible: true,
      );
    });

    test('(f) MORD : le canal hors-codegen NON RÉSERVÉ a fui dans `extra`', () {
      final e = leaker();
      // Le fait, d'abord : le canal EST dans `extra` (il ne devrait JAMAIS y être).
      expect(e.extra.containsKey(kLeakedChannelKey), isTrue);

      expect(
        () => assertProbeBodyNotInExtra(
          label: '_ChannelLeaking',
          extra: e.extra,
          probeBody: body,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'une clé du CORPS DE SONDE trouvée dans `extra` PROUVE un canal '
            'oublié dans `_reservedKeys` — c\'est le mode de destruction exact '
            'que l\'injection `kLearningKey` (ES-2.1) laissait passer EN VERT.',
      );

      // Et la batterie complète rougit aussi (via (f) SEULE).
      expect(
        () => assertReservedKeysClean(
          label: '_ChannelLeaking',
          entity: e,
          encoded: e.toMap(),
          legacyMirrorAllowed: false,
          expectExtensible: true,
          probeBody: body,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(f) : la DOUBLE ÉMISSION est réelle (pourquoi le round-trip casse)', () {
      // Sans réservation, `toMap()` écrit le canal DEUX FOIS : une via `...extra`,
      // une via le câblage manuel. Le dernier gagne — ici la même valeur, mais
      // l'instance mémoire et la même relue du store DIVERGENT (`extra` porte la
      // map BRUTE au 1ᵉʳ tour, la map RÉÉMISE au 2ᵉ) : `==` casse, le round-trip
      // n'est plus idempotent.
      final e = leaker();
      final encoded = e.toMap();
      expect(encoded.containsKey(kLeakedChannelKey), isTrue);
      final relu = _ChannelLeakingEntity.fromMap(encoded);
      expect(
        relu.extra.containsKey(kLeakedChannelKey),
        isTrue,
        reason: 'le canal non réservé se REPROPAGE dans `extra` à chaque cycle — '
            'la fuite est PERSISTANTE, pas ponctuelle.',
      );
    });
  });

  // =========================================================================
  // 🔴 (i.1) — DW-ES22-3 : LA VOIE D'ÉCRITURE EST ENFIN OBSERVÉE.
  //
  // Contre-exemple PERMANENT et ISOLÉ PAR RÈGLE (R2) : `_ExtraReopeningEntity`
  // est VERTE sur (a)(b)(c)(d)(e)(f) — SEULE (i.1) peut la faire rougir.
  // =========================================================================
  group('(i.1) — DW-ES22-3 : la VOIE D\'ÉCRITURE rouvre le filtre ⇒ ROUGE', () {
    _ExtraReopeningEntity reopener() =>
        _ExtraReopeningEntity.fromMap(buildProbe(const <String, dynamic>{'id': 'x'}));

    test('la fixture est VERTE sur (a)(b)(c)(d)(e)(f) — l\'isolation est RÉELLE',
        () {
      final e = reopener();
      // (a)/(b)/(f) : `fromMap` dépouille, préserve la clé inconnue.
      assertExtraClean(
        label: '_ExtraReopening',
        entity: e,
        expectExtensible: true,
        probeBody: const <String, dynamic>{}, // R2 — fixture sans schéma.
      );
      expect(e.extra[kProbeUnknownKey], kProbeUnknownValue);
      // (c)/(d) : tant qu'on n'a pas ÉCRIT, l'encodage est PROPRE.
      assertEncodedClean(
        label: '_ExtraReopening',
        encoded: e.toMap(),
        legacyMirrorAllowed: false,
      );
      // (e) : la clé inconnue survit au round-trip (`toMap` étale `...extra`).
      assertUnknownKeyRoundTrip(
        label: '_ExtraReopening',
        entity: e,
        encoded: e.toMap(),
        expectExtensible: true,
      );
    });

    test('(i.1) MORD : après écriture, `is_deleted`/`updated_at` sont RÉÉMIS', () {
      // Le fait, d'abord : la voie d'écriture ROUVRE réellement le filtre.
      final pollue = reopener().withExtra(<String, dynamic>{
        ZSyncMeta.kIsDeleted: true,
        kExtraWriteWitnessKey: kExtraWriteWitnessValue,
      });
      expect(pollue.toMap().containsKey(ZSyncMeta.kIsDeleted), isTrue);

      expect(
        () => assertExtraWriteSanitized(
          label: '_ExtraReopening',
          entity: reopener(),
          writer: _reopenWriter,
          encode: (Object e) => (e as _ExtraReopeningEntity).toMap(),
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'une voie d\'écriture qui ROUVRE le filtre des clés réservées '
            'DOIT rougir — c\'est le défaut mesuré sur 8 entités sur 9.',
      );
    });

    test('(i.1) MORD AUSSI sous allowlist legacy (la valeur vient de la POLLUTION)',
        () {
      // Portée MINIMALE de l'allowlist : elle tolère un `updated_at` issu du
      // CHAMP MÉTIER, jamais une valeur ARBITRAIRE écrite dans `extra`.
      expect(
        () => assertExtraWriteSanitized(
          label: '_ExtraReopening#legacy',
          entity: reopener(),
          writer: _reopenWriter,
          encode: (Object e) => (e as _ExtraReopeningEntity).toMap(),
          legacyMirrorAllowed: true,
        ),
        throwsA(isA<TestFailure>()),
      );
    });

    test('(i.1) MORD sur un WRITER MENTEUR (anti-vacuité — AC7)', () {
      // Un writer `(e, x) => e` n'écrit RIEN : sans le témoin, (i.1) serait
      // TRIVIALEMENT VERTE sur TOUTES les entités, y compris les cassées.
      expect(
        () => assertExtraWriteSanitized(
          label: '_writerMenteur',
          entity: reopener(),
          writer: ZExtraWriter(
            voie: 'ctor',
            eagerlyNormalized: true,
            write: (Object e, Map<String, dynamic> x) => e, // ⛔ n'écrit rien
          ),
          encode: (Object e) => (e as _ExtraReopeningEntity).toMap(),
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'un writer qui n\'écrit pas rendrait (i.1) vacuellement verte : '
            'le TÉMOIN D\'ÉCRITURE doit le démasquer.',
      );
    });
  });

  // =========================================================================
  // 🔴 (i.1c)/(i.3) — REMÉDIATION HIGH-1 / HIGH-2 / MAJEUR-2 (code-review ES-2.2b).
  //
  // Le motif exact des entités de PRODUCTION, isolé en fixtures PERMANENTES :
  // un constructeur **`const`** (qui ne peut RIEN filtrer — AD-10 y interdit
  // l'`assert`) + un **ACCESSEUR** `extra` qui NORMALISE à la lecture.
  //
  // Trois fixtures, trois règles, une seule à la fois (R2) :
  //   - `_ConstCtorGuardedEntity`  : le patron CORRECT ⇒ VERT (témoin d'isolation) ;
  //   - `_ConstCtorRawEntity`      : MÊME entité, accesseur SANS garde ⇒ (i.1a) ET
  //                                  (i.1c) ROUGES — la garde d'accesseur est
  //                                  PORTEUSE (HIGH-1/HIGH-2) ;
  //   - writer AUTO-SANITISANT sur `_ConstCtorGuardedEntity` ⇒ (i.3) ROUGE
  //                                  (MAJEUR-2 : le « menteur POLI »).
  // =========================================================================
  group('(i.3) — HIGH-1/HIGH-2/MAJEUR-2 : la garde de l\'ACCESSEUR est EXIGÉE', () {
    _ConstCtorGuardedEntity guarded() =>
        _ConstCtorGuardedEntity.fromMap(buildProbe(const <String, dynamic>{'id': 'x'}));

    test('témoin : le patron CORRECT (ctor `const` + accesseur gardé) est VERT',
        () {
      assertExtraWriteSanitized(
        label: '_ConstCtorGuarded#ctor',
        entity: guarded(),
        writer: _constCtorWriter,
        encode: (Object e) => (e as _ConstCtorGuardedEntity).toMap(),
        legacyMirrorAllowed: false,
      ); // ne throw pas
      // …et la voie `copyWith` (qui, elle, normalise EAGER) aussi.
      assertExtraWriteSanitized(
        label: '_ConstCtorGuarded#copyWith',
        entity: guarded(),
        writer: _constCopyWithWriter,
        encode: (Object e) => (e as _ConstCtorGuardedEntity).toMap(),
        legacyMirrorAllowed: false,
      ); // ne throw pas
    });

    test('HIGH-1/HIGH-2 MORD : accesseur SANS garde ⇒ voie CTOR ⇒ (i.1a)+(i.1c)',
        () {
      // Le fait, d'abord : sans garde d'accesseur, le ctor `const` POLLUE la
      // mémoire ET la persistance (son `toMap()` étale `...extra`).
      const raw = _ConstCtorRawEntity(
        extra: <String, dynamic>{ZSyncMeta.kIsDeleted: true},
      );
      expect(raw.extra.containsKey(ZSyncMeta.kIsDeleted), isTrue);
      expect(raw.toMap().containsKey(ZSyncMeta.kIsDeleted), isTrue);

      expect(
        () => assertExtraWriteSanitized(
          label: '_ConstCtorRaw#ctor',
          entity: _ConstCtorRawEntity.fromMap(
            buildProbe(const <String, dynamic>{'id': 'x'}),
          ),
          writer: _rawCtorWriter,
          encode: (Object e) => (e as _ConstCtorRawEntity).toMap(),
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
        reason: '🔴 C\'EST LE CŒUR DE LA REMÉDIATION : la voie CTOR est la SEULE '
            'qui écrive un `extra` POLLUÉ dans le slot stocké. Sans elle (v1 du '
            'harnais), retirer la garde laissait le gate VERT sur 8 entités sur 9.',
      );
    });

    test('MAJEUR-2 MORD : writer AUTO-SANITISANT (le « menteur POLI »)', () {
      // ⚠️ CE WRITER PASSE LE TÉMOIN D'ÉCRITURE : la clé témoin (NON réservée)
      // ressort intacte de l'encodage. C'est précisément pourquoi l'anti-vacuité
      // de la v1 ne le voyait PAS — et c'est la forme que `kExtraWriters` avait
      // DÉJÀ en production (il câblait la voie qui filtre).
      expect(
        () => assertExtraWriteSanitized(
          label: '_writerMenteurPoli',
          entity: guarded(),
          writer: ZExtraWriter(
            voie: 'ctor',
            eagerlyNormalized: false, // il PRÉTEND transmettre verbatim…
            write: (Object e, Map<String, dynamic> x) =>
                // …mais il DÉPOUILLE `x` lui-même avant la voie publique.
                _ConstCtorGuardedEntity(
              extra: <String, dynamic>{
                for (final en in x.entries)
                  if (!ZSyncMeta.reservedKeys.contains(en.key)) en.key: en.value,
              },
            ),
          ),
          encode: (Object e) => (e as _ConstCtorGuardedEntity).toMap(),
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'un writer qui sanitise LUI-MÊME rendrait (i.1a/b/c) trivialement '
            'vertes : elles n\'exerceraient plus AUCUNE garde de l\'entité. (i.3) '
            'l\'observe — le slot stocké serait PROPRE alors que la voie `const` '
            'est incapable de le nettoyer.',
      );
    });

    test('(i.3) MORD : `copyWith` qui ne normalise plus EAGER (garde décorative)',
        () {
      // La garde EAGER de `copyWith` ne porte PAS l'invariant (l'accesseur le
      // porte) — sans (i.3) elle serait donc DÉCORATIVE (R1). (i.3) l'EXIGE.
      expect(
        () => assertExtraWriteSanitized(
          label: '_copyWithNonEager',
          entity: guarded(),
          writer: ZExtraWriter(
            voie: 'copyWith',
            eagerlyNormalized: true, // ce que la production DOIT tenir…
            write: (Object e, Map<String, dynamic> x) =>
                // …mais ce `copyWith` a perdu son `_sanitizeExtra` : le slot
                // stocké reste POLLUÉ (l'accesseur devra copier à chaque lecture).
                _ConstCtorGuardedEntity(extra: x),
          ),
          encode: (Object e) => (e as _ConstCtorGuardedEntity).toMap(),
          legacyMirrorAllowed: false,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'retirer `_sanitizeExtra` du `copyWith` (le défaut DW-ES22-3 exact) '
            'DOIT rougir — sinon la garde EAGER est un vœu.',
      );
    });
  });

  // =========================================================================
  // 🔴 (i.2) — DW-ES22-4 : L'ÉGALITÉ D'`extra` EST ENFIN OBSERVÉE.
  //
  // Contre-exemple PERMANENT et ISOLÉ PAR RÈGLE (R2) :
  // `_ShallowExtraEqualityEntity` est VERTE sur (a)…(f) **ET (i.1)** — SEULE
  // (i.2) peut la faire rougir.
  // =========================================================================
  group('(i.2) — DW-ES22-4 : égalité SUPERFICIELLE sur `extra` ⇒ ROUGE', () {
    _ShallowExtraEqualityEntity shallow(Map<String, dynamic> m) =>
        _ShallowExtraEqualityEntity.fromMap(m);

    test('la fixture est VERTE sur (a)…(f) ET (i.1) — l\'isolation est RÉELLE',
        () {
      final e = shallow(buildProbe(const <String, dynamic>{'id': 'x'}));
      assertExtraClean(
        label: '_ShallowExtraEquality',
        entity: e,
        expectExtensible: true,
        probeBody: const <String, dynamic>{},
      );
      expect(e.extra[kProbeUnknownKey], kProbeUnknownValue);
      assertEncodedClean(
        label: '_ShallowExtraEquality',
        encoded: e.toMap(),
        legacyMirrorAllowed: false,
      );
      assertUnknownKeyRoundTrip(
        label: '_ShallowExtraEquality',
        entity: e,
        encoded: e.toMap(),
        expectExtensible: true,
      );
      // 🔴 (i.1) VERTE : sa garde est posée à l'ENTRÉE, à l'ÉCRITURE et à la SORTIE.
      assertExtraWriteSanitized(
        label: '_ShallowExtraEquality',
        entity: e,
        writer: ZExtraWriter(
          voie: 'withExtra',
          eagerlyNormalized: true,
          write: (Object x, Map<String, dynamic> m) =>
              (x as _ShallowExtraEqualityEntity).withExtra(m),
        ),
        encode: (Object x) => (x as _ShallowExtraEqualityEntity).toMap(),
        legacyMirrorAllowed: false,
      ); // ne throw pas
    });

    test('(i.2) est VERTE sur un `extra` SCALAIRE — le « vert pour une MAUVAISE '
        'raison » que la sonde IMBRIQUÉE démasque', () {
      // MESURÉ : avec un scalaire, l'égalité SUPERFICIELLE a RAISON. C'est
      // pourquoi toutes les sondes du repo étaient vertes tout en ne prouvant
      // RIEN : le filet avait une EXISTENCE, aucun POUVOIR DISCRIMINANT.
      final a = shallow(deepCopyJson(<String, dynamic>{'zz_s': 'x'}));
      final b = shallow(deepCopyJson(<String, dynamic>{'zz_s': 'x'}));
      expect(a, equals(b), reason: 'l\'`==` superficiel suffit sur un scalaire.');
    });

    test('(i.2) MORD sur un `extra` IMBRIQUÉ (Map + List)', () {
      // Le fait, d'abord : deux décodages indépendants ne sont PAS égaux.
      final a = shallow(deepCopyJson(<String, dynamic>{
        kProbeNestedKey: nestedProbeValue(),
      }));
      final b = shallow(deepCopyJson(<String, dynamic>{
        kProbeNestedKey: nestedProbeValue(),
      }));
      expect(a == b, isFalse, reason: 'témoin : l\'`==` de `Map` est une IDENTITÉ.');
      expect(<Object>{a, b}, hasLength(2), reason: 'un `Set` en garde DEUX.');

      expect(
        () => assertExtraDeepEquality(
          label: '_ShallowExtraEquality',
          probeBody: const <String, dynamic>{},
          decode: shallow,
          expectValueEquality: true,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'une égalité SUPERFICIELLE sur `extra` DOIT rougir : porter du '
            'JSON imbriqué est LA RAISON D\'ÊTRE d\'`extra` (AD-4 pt.2).',
      );
    });

    test('(i.2) MORD sur une entité qui JETTE `extra` (anti-vacuité)', () {
      // Deux `extra` VIDES sont trivialement égaux ⇒ (i.2) serait VERTE sur une
      // entité qui DÉTRUIT l'échappatoire AD-4. Le témoin imbriqué l'interdit.
      expect(
        () => assertExtraDeepEquality(
          label: '_ExtraDropping',
          probeBody: const <String, dynamic>{},
          decode: (Map<String, dynamic> m) => _ExtraDroppingEntity.fromMap(
            <String, dynamic>{'id': 'x'}, // ⛔ ignore le payload : `extra` vide
          ),
          expectValueEquality: true,
        ),
        throwsA(isA<TestFailure>()),
        reason: 'le témoin IMBRIQUÉ doit être PRÉSENT dans `extra`, sinon (i.2) '
            'comparerait deux `extra` vides — trivialement égaux.',
      );
    });

    test('(i.2) skip DÉCLARÉ : MORD si l\'entité a GAGNÉ une égalité de valeur',
        () {
      // 🔴 ANTI-INERTIE (R6) — le skip de `kNoValueEqualityProbes` doit être
      // CONTRÔLÉ contre le comportement RÉEL, jamais cru sur parole.
      //
      // ⚠️ La fixture est `_DeepExtraEqualityEntity` — une entité à égalité
      // PROFONDE RÉELLE, DÉDIÉE. Deux erreurs de fixture ont été commises ici, et
      // toutes deux méritent d'être retenues :
      //   1. `_ShallowExtraEqualityEntity` (superficielle) **NE ROUGISSAIT PAS** :
      //      sur un `extra` IMBRIQUÉ, une égalité superficielle rend bel et bien
      //      `a != b` ⇒ la branche « entrée morte » était SATISFAITE, et le test
      //      était VERT en ne prouvant RIEN — le motif exact que ce gate combat,
      //      rencontré DANS le gate lui-même ;
      //   2. `study_folder` (entité de PRODUCTION) rougissait PARASITAIREMENT
      //      quand l'injection de régression n° 3 lui retirait son `==` profond.
      //      Une fixture ne doit JAMAIS dépendre d'une entité de production (R2).
      expect(
        () => assertExtraDeepEquality(
          label: '_faussement_sans_egalite',
          probeBody: const <String, dynamic>{},
          decode: _DeepExtraEqualityEntity.fromMap,
          expectValueEquality: false, // ⛔ mensonge : elle A une égalité profonde
        ),
        throwsA(isA<TestFailure>()),
        reason: 'un skip d\'(i.2) sur une entité qui A une égalité de valeur '
            'serait une ENTRÉE MORTE dans `kNoValueEqualityProbes` — le jour où '
            'DW-ES22-5 est soldée, ce chemin DOIT rougir pour forcer le retrait '
            'de l\'entrée.',
      );
    });
  });

  // =========================================================================
  // VERROU DE DETTE — DW-ES14-2 (AC8).
  // =========================================================================
  group(
      'DW-ES14-2 — VERROU : la voie registre ne TYPE JAMAIS `extension` (et la '
      'DÉTRUIT partout où l\'entité ne la préserve pas)', () {
    /// Payload d'extension **valide en forme** (peu importe le contenu : sur la
    /// voie registre, AUCUN parser n'est injectable ⇒ il n'est jamais lu).
    const extensionPayload = <String, dynamic>{
      'format_version': 1,
      'kind': 'zz_ext_test',
      'body': <String, dynamic>{'k': 'v'},
    };

    for (final kind in kProbeBodies.keys.where(
      (k) => !kNonExtensibleKinds.contains(k),
    )) {
      test('$kind : le slot `extension` n\'est JAMAIS TYPÉ par le registre', () {
        final probe = <String, dynamic>{
          ...buildProbe(kProbeBodies[kind]!),
          'extension': extensionPayload,
        };
        final entity = registry.decode(kind, probe);
        final encoded = registry.encode(kind, entity);

        // ⛔ PERTE CONNUE ET DÉLIBÉRÉMENT NON CORRIGÉE PAR ES-2.0.
        //
        // CAUSE (racine, commune avec le canal `source` — cf. H2) : `ZcrudRegistry`
        // n'offre AUCUN SLOT D'INJECTION. Les entités décodent leur slot
        // `extension` via un `extensionParser` INJECTABLE — le registre appelle
        // `ZXxx.fromMap(map)` SANS parser ⇒ `_decodeExtension(raw, null)` renvoie
        // `null`. Et comme `'extension'` est une clé RÉSERVÉE de chaque entité,
        // elle n'atterrit pas non plus dans `extra` : le payload est purement et
        // simplement PERDU (`toMap()` ne réémet `extension` que si non-`null`).
        //
        // POURQUOI NON CORRIGÉE ICI : le correctif exige d'écrire soit
        // `ZcrudRegistry` (`zcrud_core`), soit la sémantique des entités
        // (`zcrud_study_kernel`) — les DEUX packages qu'ES-2.0 s'interdit d'écrire
        // (condition de sa parallélisation avec ES-2.1/2.2/2.6).
        //
        // CE TEST EST UN VERROU D'HONNÊTETÉ : il rend la dette VISIBLE EN MACHINE
        // (pas seulement en prose) et EMPÊCHE de croire la voie registre « sûre ».
        //
        // QUAND DW-ES14-2 SERA SOLDÉE (slot d'injection dans `ZcrudRegistry`, à
        // faire AVANT ES-3.2/ES-3.5), CE TEST DOIT ÊTRE INVERSÉ : `isTrue` +
        // assertion d'égalité du payload ré-encodé. Le voir rougir sera alors le
        // SIGNAL du succès — ne pas le « réparer » en supprimant l'assertion.

        // 🟢 L2 (code-review ES-2.0) — PRÉCONDITIONS DU VERROU : sans elles, ce
        // verrou pourrait rougir pour une raison qui N'EST PAS la clôture de la
        // dette, en annonçant un FAUX SIGNAL DE SUCCÈS.
        //
        // (i) `extension` doit rester une clé RÉSERVÉE. Si elle cessait de
        //     l'être, elle tomberait dans `extra` et serait réémise via
        //     `...extra` ⇒ `containsKey('extension')` deviendrait `true` et le
        //     verrou ci-dessous crierait « la dette est soldée ! » alors que le
        //     payload ne serait TOUJOURS PAS décodé en `ZExtension` typé.
        expect(
          (entity as ZExtensible).extra.containsKey('extension'),
          isFalse,
          reason: '[$kind] L2 : `extension` n\'est PLUS une clé réservée de '
              'l\'entité — elle a FUITÉ dans `extra`. Le verrou DW-ES14-2 '
              'ci-dessous n\'est plus interprétable (il rougirait en annonçant à '
              'tort la clôture de la dette). Ce n\'est PAS la clôture : c\'est '
              'une régression de `_reservedKeys`.',
        );
        // ─────────────────────────────────────────────────────────────────────
        // 🔴 DEUX RÉGIMES — LA DETTE EST LA MÊME, LE SORT DE LA DONNÉE DIFFÈRE.
        //
        // Ce qui est COMMUN (= LA DETTE, intacte) : le registre n'injecte AUCUN
        // parser ⇒ le slot n'est **JAMAIS TYPÉ**, sur AUCUN kind.
        //
        // Ce qui diffère (mitigation ES-2.2, MAJEUR-1/MAJEUR-2) :
        //   - kind ORDINAIRE          ⇒ payload ⛔ DÉTRUIT   (`extension == null`,
        //                                clé OMISE par `toMap()`) ;
        //   - kind ∈ `kExtensionPayloadPreservers` ⇒ payload ✅ PORTÉ VERBATIM
        //     (`ZOpaqueNoteExtension`) et RÉÉMIS BIT POUR BIT.
        // ─────────────────────────────────────────────────────────────────────
        if (kExtensionPayloadPreservers.contains(kind)) {
          // (ii-bis) Le slot est PORTÉ, mais **NON TYPÉ** — et c'est ce que
          //          `toJson() == payload` PROUVE : un parser typé aurait
          //          NORMALISÉ le payload (`{format_version, kind, body}` n'est le
          //          sous-schéma d'AUCUN type du repo). Le payload ressort
          //          IDENTIQUE ⇒ **rien ne l'a interprété** ⇒ **DW-ES14-2 est
          //          TOUJOURS OUVERTE**.
          expect(
            entity.extension,
            isNotNull,
            reason: '[$kind] RÉGRESSION : ce kind est déclaré PRÉSERVANT '
                '(`kExtensionPayloadPreservers`) mais le payload d\'`extension` '
                'est de nouveau DÉTRUIT (MAJEUR-1/MAJEUR-2 sont REVENUS).',
          );
          expect(
            entity.extension!.toJson(),
            equals(extensionPayload),
            reason: '[$kind] soit le payload n\'est PLUS réémis verbatim (perte '
                'de données), soit un parser TYPÉ l\'a enfin interprété — dans ce '
                'second cas DW-ES14-2 est en voie de CLÔTURE : vérifier que '
                '`ZcrudRegistry` offre un slot d\'injection, puis INVERSER ce '
                'verrou et RETIRER le kind de `kExtensionPayloadPreservers`.',
          );
          expect(
            encoded['extension'],
            equals(extensionPayload),
            reason: '[$kind] ⛔ LE PAYLOAD D\'EXTENSION EST PERDU AU ROUND-TRIP '
                'REGISTRE (le slot serait EFFACÉ DU STORE au premier `put`).',
          );
        } else {
          // (ii) le slot TYPÉ est bien VIDE — c'est CELA que DW-ES14-2 décrit
          //      (aucun parser injectable ⇒ `extension == null`). Quand la dette
          //      sera soldée, cette assertion rougira AUSSI : les deux rouges
          //      ensemble sont la signature du VRAI succès.
          expect(
            entity.extension,
            isNull,
            reason: '[$kind] DW-ES14-2 : le slot `extension` est désormais DÉCODÉ '
                '(non-`null`) — la dette est en voie de clôture. Vérifier que '
                '`ZcrudRegistry` offre bien un slot d\'injection de parser, puis '
                'INVERSER ce verrou. ⚠️ Si l\'entité PRÉSERVE désormais le payload '
                'NON TYPÉ (patron `ZOpaqueNoteExtension`, ES-2.2), ce n\'est PAS '
                'la clôture : l\'inscrire dans `kExtensionPayloadPreservers`.',
          );

          expect(
            encoded.containsKey('extension'),
            isFalse,
            reason: '[$kind] DW-ES14-2 : si `extension` est désormais RÉÉMISE, la '
                'dette est soldée — INVERSER ce verrou (et retirer DW-ES14-2 de '
                'l\'architecture), ne pas le supprimer. ⚠️ Vérifier D\'ABORD les '
                'deux préconditions ci-dessus : une `extension` réémise via `extra` '
                '(clé dé-réservée) ne serait PAS une clôture, mais une fuite.',
          );
        }

        // ⚠️ ANTI-AGGRAVATION SILENCIEUSE : la perte reste CIRCONSCRITE à
        // `extension`. Si `extra` régressait du même coup (retour de DW-ES14-1),
        // ce test rougirait AUSSI — la dette ne peut pas empirer en silence.
        expect(
          encoded[kProbeUnknownKey],
          kProbeUnknownValue,
          reason: '[$kind] la perte s\'est ÉTENDUE à `extra` (DW-ES14-1 est '
              'revenue) — régression majeure, pas une simple dette.',
        );
      });
    }
  });

  // =========================================================================
  // 🟠 H2 (code-review ES-2.0) — CANAL `source` : la vérité MESURÉE, épinglée.
  //
  // La dartdoc de `FirebaseZRepositoryImpl.fromRegistry` — celle qui AUTORISE le
  // câblage d'un store — publiait « `source` ✅ PRÉSERVÉ … intégralement
  // préservé ». **Zéro machine derrière cette ligne** : la sonde `flashcard` ne
  // portait aucune clé `source`. `extra` avait l'assertion (e), `extension` avait
  // 4 verrous, `source` avait UNE PHRASE.
  //
  // Ces tests remplacent la phrase par des OBSERVATIONS. Ils disent ce que la
  // voie registre fait RÉELLEMENT — y compris ce qu'elle CASSE.
  // =========================================================================
  group('H2 — canal `source` sur la voie registre : comportement MESURÉ', () {
    Map<String, dynamic> flashcardProbe() => buildProbe(kProbeBodies['flashcard']!);

    test('✅ le PAYLOAD BRUT survit au round-trip registre → registre', () {
      final probe = flashcardProbe();
      final entity = registry.decode('flashcard', probe);
      final encoded = registry.encode('flashcard', entity);

      // C'est CE point — et lui seul — que la dartdoc pouvait légitimement
      // revendiquer. Il est désormais OBSERVÉ, plus seulement affirmé.
      expect(
        encoded['source'],
        equals(probe['source']),
        reason: 'le round-trip registre → registre doit rendre le `source` '
            'BYTE-POUR-BYTE : `decode` et `encode` sont symétriquement SANS '
            '`ZSourceRegistry`, donc `ZCustomSource` conserve le payload brut.',
      );
    });

    test('⚠️ le `ZSourceRegistry` de l\'app est IGNORÉ (codec JAMAIS appliqué)',
        () {
      // Une app enregistre son codec de provenance (AD-4 pt.3) : il NORMALISE le
      // corps persisté `{zz_payload}` en payload métier `{normalise}`.
      final appRegistry = ZSourceRegistry()
        ..register(
          'zz_source_test',
          fromJson: (json) => <String, dynamic>{'normalise': json['zz_payload']},
          toJson: (value) => <String, dynamic>{
            'zz_payload': (value as Map<String, dynamic>)['normalise'],
          },
        );
      final probe = flashcardProbe();

      // VOIE DOMAINE (le registre est fourni) : le codec EST appliqué. ✅
      final viaDomaine =
          ZFlashcard.fromMap(probe, sourceRegistry: appRegistry).source;
      expect(
        (viaDomaine! as ZCustomSource).payload,
        equals(<String, dynamic>{'normalise': 'brut'}),
        reason: 'témoin : avec le registre, `ZFlashcardSource.fromJson` route '
            'par `registry.tryCodecFor(kind)`.',
      );

      // VOIE REGISTRE : `ZcrudRegistry` n'a AUCUN slot pour passer le
      // `sourceRegistry` ⇒ `ZFlashcardSource.fromJson(raw, registry: null)` ⇒ le
      // codec de l'app est PUREMENT IGNORÉ et l'on obtient le payload BRUT.
      final viaRegistre =
          (registry.decode('flashcard', probe) as ZFlashcard).source;
      expect(
        (viaRegistre! as ZCustomSource).payload,
        equals(<String, dynamic>{'zz_payload': 'brut'}),
        reason: 'DW-ES14-2 (canal `source`) : la voie registre BYPASSE le '
            '`ZSourceRegistry` de l\'app — le contrat d\'AD-4 pt.3 est rompu EN '
            'SILENCE. MÊME CAUSE RACINE que la perte d\'`extension` : '
            '`ZcrudRegistry` n\'offre AUCUN SLOT D\'INJECTION. Si ce test rougit '
            'parce que le codec est désormais APPLIQUÉ, la dette est soldée — '
            'INVERSER ce verrou, ne pas le supprimer.',
      );
    });

    test('⛔ MÉLANGER LES VOIES CORROMPT LES VALEURS (pas une simple asymétrie)',
        () {
      // Scénario EXPLICITEMENT autorisé par l'ancienne dartdoc : elle disait
      // « `source` intégralement préservé » (⇒ `fromRegistry` est sûr) ET
      // recommandait ailleurs le constructeur nominal AVEC le registre. Une app
      // qui LIT par `fromRegistry` et ÉCRIT par la voie nominale tombe ici.
      final appRegistry = ZSourceRegistry()
        ..register(
          'zz_source_test',
          fromJson: (json) => <String, dynamic>{'normalise': json['zz_payload']},
          toJson: (value) => <String, dynamic>{
            'zz_payload': (value as Map<String, dynamic>)['normalise'],
          },
        );

      // LECTURE par le registre : payload jamais décodé (`{zz_payload: brut}`).
      final card = registry.decode('flashcard', flashcardProbe()) as ZFlashcard;
      // ÉCRITURE par la voie nominale : `codec.toJson` est appliqué à un payload
      // qui n'a JAMAIS été décodé — il y cherche `normalise`, ne trouve rien.
      final reecrit = card.toMap(sourceRegistry: appRegistry);

      expect(
        reecrit['source'],
        equals(<String, dynamic>{'zz_payload': null, 'kind': 'zz_source_test'}),
        reason: 'MESURE (spike ES-2.0/H2) : la valeur `brut` est remplacée par '
            '`null`. Ce n\'est PAS une « double transformation » bénigne : c\'est '
            'une PERTE DE DONNÉES RÉELLE, produite par un mélange de voies que la '
            'dartdoc autorisait explicitement. Verrou d\'honnêteté : si ce test '
            'rougit, mesurer le nouveau comportement AVANT de le « réparer ».',
      );
    });
  });
}
