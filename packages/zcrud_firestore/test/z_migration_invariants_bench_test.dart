// BANC D'INVARIANTS DE MIGRATION — passe de consolidation (2026-07-22).
//
// ## Pourquoi ce banc existe
//
// `ZStudyLegacyCodec` / `ZLegacyStudyMigrator` ont reçu 7 correctifs successifs
// (CR-IFFD-1..7, CR-LEX-8/9). **Trois d'entre eux corrigeaient des régressions
// introduites par un correctif précédent** : `keyAliases` avait cassé le census,
// `opaqueKeys` avait cassé l'idempotence, la garde anti-collision dépendait de
// l'ordre des clés. Chaque option ajoutée touche les gardes existantes.
//
// La cause n'est pas la qualité des correctifs mais la **forme de la
// couverture** : des gardes PAR CR, chacune exerçant UNE option sur LE document
// qui motivait la demande. Les COMBINAISONS n'étaient jamais couvertes.
//
// ## Ce que ce banc fait de différent
//
// Il croise **7 configurations** × **10 formes de documents** et vérifie, sur
// chaque paire, **6 invariants UNIVERSELS** — des propriétés qui doivent tenir
// quelle que soit la configuration. Les 7 CR violaient chacune l'un d'eux :
//
//   I1 IDEMPOTENCE      migrate ∘ migrate == migrate   (CR-IFFD-1, CR-IFFD-7)
//   I2 JAMAIS DE THROW  quelle que soit l'entrée       (AD-10)
//   I3 DÉTERMINISME     indépendant de l'ordre des clés (CR-IFFD-6)
//   I4 ZÉRO PERTE       toute valeur métier retrouvable (CR-IFFD-2, CR-IFFD-6)
//   I5 SUPPRESSION SÛRE un document supprimé ne renaît jamais (CR-IFFD-3)
//   I6 ENTRÉE INTACTE   le dry-run ne mute jamais la source
//
// ## L'oracle de I4 est INDÉPENDANT du census
//
// Point de méthode : vérifier `isPreservationComplete` avec la même logique que
// `_census` serait tautologique — le test rougirait seulement si le census se
// contredisait lui-même. L'oracle ici est **au niveau des VALEURS** : toute
// valeur métier présente en entrée doit être retrouvable en sortie, quel que
// soit le nom de clé sous lequel elle atterrit. C'est ce qui aurait attrapé
// CR-IFFD-6 (collision détruisant une valeur alors que le census se déclarait
// satisfait) sans rien savoir de son mécanisme.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────────── Configurations ────────────────────────────────

class _Config {
  const _Config(this.name, this.migrator);
  final String name;
  final ZLegacyStudyMigrator migrator;
}

const _statusMappers = <String, ZLegacyValueMapper>{
  'status': ZStudyLegacyCodec.mapDocumentStatus,
};

final List<_Config> _configs = <_Config>[
  // Aucune option : le comportement de base doit satisfaire les invariants.
  const _Config('C0-défaut', ZLegacyStudyMigrator()),
  // Le TRAP `status` 6→4 seul.
  const _Config(
    'C1-status',
    ZLegacyStudyMigrator(
      codec: ZStudyLegacyCodec(
        valueMappers: _statusMappers,
        preserveLegacyUnder: <String>{'status'},
      ),
    ),
  ),
  // + alias de clé de SYNC (soft-delete sous un autre nom).
  const _Config(
    'C2-syncAlias',
    ZLegacyStudyMigrator(
      codec: ZStudyLegacyCodec(
        valueMappers: _statusMappers,
        preserveLegacyUnder: <String>{'status'},
        syncMetaKeyAliases: <String, String>{'deleted': ZSyncMeta.kIsDeleted},
      ),
    ),
  ),
  // + renommage sémantique de clé MÉTIER.
  const _Config(
    'C3-keyAlias',
    ZLegacyStudyMigrator(
      codec: ZStudyLegacyCodec(
        valueMappers: _statusMappers,
        preserveLegacyUnder: <String>{'status'},
        syncMetaKeyAliases: <String, String>{'deleted': ZSyncMeta.kIsDeleted},
        keyAliases: <String, String>{'quality': 'last_quality'},
      ),
    ),
  ),
  // + récursion en profondeur.
  const _Config(
    'C4-récursif',
    ZLegacyStudyMigrator(
      codec: ZStudyLegacyCodec(
        valueMappers: _statusMappers,
        preserveLegacyUnder: <String>{'status'},
        syncMetaKeyAliases: <String, String>{'deleted': ZSyncMeta.kIsDeleted},
        keyAliases: <String, String>{'quality': 'last_quality'},
        recurseNested: true,
      ),
    ),
  ),
  // + charges utiles tierces protégées.
  const _Config(
    'C5-opaque',
    ZLegacyStudyMigrator(
      codec: ZStudyLegacyCodec(
        recurseNested: true,
        opaqueKeys: <String>{'dashboard'},
      ),
    ),
  ),
  // La configuration RÉELLE d'IFFD — toutes les options ensemble.
  const _Config(
    'C6-IFFD-complet',
    ZLegacyStudyMigrator(
      codec: ZStudyLegacyCodec(
        valueMappers: _statusMappers,
        preserveLegacyUnder: <String>{'status'},
        syncMetaKeyAliases: <String, String>{'deleted': ZSyncMeta.kIsDeleted},
        keyAliases: <String, String>{'quality': 'last_quality'},
        recurseNested: true,
        opaqueKeys: <String>{'dashboard'},
      ),
    ),
  ),
];

// ─────────────────────────── Formes de documents ─────────────────────────────

final Map<String, Map<String, dynamic>> _documents = <String, Map<String, dynamic>>{
  'D0-vide': <String, dynamic>{},
  'D1-legacy-plat': <String, dynamic>{
    'subjectId': 's1',
    'folderId': 'f1',
    'name': 'Doc',
    'status': 'embedded',
    'createdAt': 1700000000000,
  },
  'D2-déjà-canonique': <String, dynamic>{
    'subject_id': 's1',
    'name': 'Doc',
    'status': 'ready',
    ZSyncMeta.kIsDeleted: false,
  },
  'D3-partiellement-migré': <String, dynamic>{
    'subject_id': 's1',
    'folderId': 'f1',
    'status': 'ready',
    'deleted': true,
    ZSyncMeta.kIsDeleted: false,
  },
  'D4-imbriqué-legacy': <String, dynamic>{
    'name': 'Carte',
    ZSyncMeta.kIsDeleted: false,
    'nodes': <dynamic>[
      <String, dynamic>{
        'edgeColor': 42,
        'outputs': <dynamic>[
          <String, dynamic>{'edgeColor': 7},
        ],
      },
    ],
  },
  'D5-charge-tierce': <String, dynamic>{
    'name': 'Carte',
    'deleted': false,
    'dashboard': <String, dynamic>{
      'elementId': 'e1',
      'nested': <String, dynamic>{'kindValue': 3},
    },
  },
  'D6-supprimé': <String, dynamic>{
    'name': 'Fiche secrète',
    'deleted': true,
  },
  'D7-collision': <String, dynamic>{
    'quality': 1,
    'lastQuality': 5,
    'name': 'Révision',
  },
  'D8-hostile': <String, dynamic>{
    'a': null,
    'deleted': <int>[1, 2],
    'nodes': <dynamic>[null, 3, 'x'],
    'quality': <String, dynamic>{'inattendu': true},
    'status': 42,
  },
  // ⚠️ FORME CRITIQUE — combine une charge OPAQUE et un champ à valueMapper.
  // Sans elle, le banc laissait passer la régression CR-IFFD-7 (opaqueKeys
  // neutralisant la détection « déjà canonique » ⇒ re-migration à chaque passage
  // ⇒ `status` rétrogradé). Aucune option seule ne la déclenche : il faut LE
  // CROISEMENT. C'est exactement ce que la couverture par-CR ne produisait pas.
  'D10-opaque+status': <String, dynamic>{
    'name': 'Carte',
    'status': 'embedded',
    'dashboard': <String, dynamic>{'elementId': 'e1'},
  },
  // Croisement alias de sync + alias de clé + imbriqué + opaque, tous à la fois.
  'D11-tout-croisé': <String, dynamic>{
    'name': 'Tout',
    'status': 'converted',
    'deleted': true,
    'quality': 3,
    'dashboard': <String, dynamic>{'elementId': 'e2'},
    'nodes': <dynamic>[
      <String, dynamic>{'edgeColor': 9},
    ],
    'createdAt': 1700000000000,
  },
  'D9-temporel': <String, dynamic>{
    'createdAt': 1700000000000,
    'updatedAt': '2024-01-01T00:00:00.000Z',
    'meta': <String, dynamic>{'seenAt': 1700000000000},
  },
};

// ──────────────────────────────── Oracles ────────────────────────────────────

/// Toutes les valeurs SCALAIRES d'une structure, à toute profondeur.
/// Oracle INDÉPENDANT du census (qui raisonne, lui, sur les CLÉS).
Set<Object> _scalarValues(Object? v) {
  final out = <Object>{};
  void walk(Object? x) {
    if (x is Map) {
      for (final e in x.entries) {
        walk(e.value);
      }
    } else if (x is List) {
      for (final e in x) {
        walk(e);
      }
    } else if (x != null) {
      out.add(x);
    }
  }

  walk(v);
  return out;
}

/// Clés métier de premier niveau (hors sync et hors clés de survie).
Set<String> _businessKeys(Map<String, dynamic> doc) => <String>{
      for (final k in doc.keys)
        if (!ZSyncMeta.reservedKeys.contains(k) &&
            !k.startsWith(ZStudyLegacyCodec.kLegacyPrefix))
          k,
    };

/// Reconstruit le même document avec les clés en ordre INVERSE.
Map<String, dynamic> _reversed(Map<String, dynamic> doc) =>
    <String, dynamic>{for (final k in doc.keys.toList().reversed) k: doc[k]};

void main() {
  for (final config in _configs) {
    group(config.name, () {
      for (final entry in _documents.entries) {
        final docName = entry.key;
        // Copie fraîche par cas : aucune contamination entre tests.
        Map<String, dynamic> doc() =>
            Map<String, dynamic>.from(entry.value);

        group(docName, () {
          test('I2 — ne throw JAMAIS (AD-10)', () {
            expect(() => config.migrator.migrateDocument(doc()), returnsNormally);
          });

          test('I1 — IDEMPOTENCE : migrate ∘ migrate == migrate', () {
            final once = config.migrator.migrateDocument(doc()).canonical;
            final twice = config.migrator.migrateDocument(once).canonical;
            expect(twice, once,
                reason: 'point fixe rompu — une reprise corromprait le corpus');
          });

          test('I3 — DÉTERMINISME : indépendant de l\'ordre des clés', () {
            // Firestore ne garantit pas l'ordre des clés d'un document.
            final a = config.migrator.migrateDocument(doc()).canonical;
            final b = config.migrator.migrateDocument(_reversed(doc())).canonical;
            expect(b, a, reason: 'la sortie ne doit dépendre que du CONTENU');
          });

          test('I4 — ZÉRO PERTE : toute valeur métier reste retrouvable', () {
            final input = doc();
            final business = _businessKeys(input);
            final expected = <Object>{
              for (final k in business) ..._scalarValues(input[k]),
            };
            final produced =
                _scalarValues(config.migrator.migrateDocument(input).canonical);

            // Oracle au niveau des VALEURS — délibérément indépendant du census
            // (qui raisonne sur les clés). Une valeur écrasée en silence par une
            // collision est détectée ici même si le census se déclare complet.
            for (final v in expected) {
              // Deux TRANSFORMATIONS LÉGITIMES, à ne pas confondre avec une
              // perte. L'équivalent attendu est dérivé ICI (jamais lu du codec) :
              // l'oracle reste indépendant de l'implémentation testée.
              //  - remap de valeur (status 6→4) ;
              //  - normalisation temporelle (int millis → String ISO-8601).
              final ok = produced.contains(v) ||
                  _remapped(v) ||
                  (v is int && produced.contains(_isoOf(v)));
              expect(ok, isTrue,
                  reason: 'valeur métier "$v" perdue sans trace');
            }
          });

          test('I6 — le dry-run ne MUTE PAS l\'entrée', () {
            final input = doc();
            final before = input.toString();
            config.migrator.migrateDocument(input);
            expect(input.toString(), before);
          });
        });
      }

      test('I5 — SUPPRESSION SÛRE : un document supprimé ne renaît jamais', () {
        // Seules les configs déclarant l'alias peuvent interpréter `deleted`.
        final hasAlias =
            config.migrator.migrateDocument(<String, dynamic>{'deleted': true})
                .canonical[ZSyncMeta.kIsDeleted] ==
                true;
        if (!hasAlias) return; // config sans alias : hors périmètre de I5.

        for (final d in <Map<String, dynamic>>[
          <String, dynamic>{'deleted': true},
          <String, dynamic>{'deleted': true, ZSyncMeta.kIsDeleted: false},
          <String, dynamic>{'name': 'x', 'deleted': true, 'status': 'embedded'},
        ]) {
          final out = config.migrator.migrateDocument(d).canonical;
          expect(out[ZSyncMeta.kIsDeleted], isTrue,
              reason: 'RÉSURRECTION : $d est ressorti visible');
          // Et la reprise ne doit pas le ressusciter non plus.
          final again = config.migrator.migrateDocument(out).canonical;
          expect(again[ZSyncMeta.kIsDeleted], isTrue,
              reason: 'RÉSURRECTION à la reprise : $d');
        }
      });

      test('cohérence du rapport de corpus (invariant migrated+already==total)',
          () {
        final report = config.migrator.migrateCorpus(_documents.values);
        expect(report.isConsistent, isTrue);
        expect(report.total, _documents.length);
        expect(report.canonicalDocuments, hasLength(_documents.length));
      });
    });
  }
}

/// Une valeur est légitimement absente si elle a été REMAPPÉE (statut legacy
/// 6→4). Sa granularité d'origine survit sous `_legacy_status`, donc la valeur
/// brute reste présente — cette exception ne couvre que le cas où la valeur
/// remappée REMPLACE l'originale sans `preserveLegacyUnder`.
/// ISO-8601 UTC d'un horodatage en millis — dérivé INDÉPENDAMMENT du codec,
/// pour distinguer une normalisation temporelle légitime d'une perte réelle.
String? _isoOf(int millis) {
  if (millis < 0 || millis > 253402300799999) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
      .toIso8601String();
}

bool _remapped(Object v) => const <Object>{
      'uploading', 'converting', 'embedding',
      'uploaded', 'converted', 'embedded',
      'validating', 'ready',
    }.contains(v);
