// CR-IFFD-2 / CR-IFFD-3 — gardes des deux correctifs de migration legacy
// remontés par la session IFFD (2026-07-20), reproduits puis corrigés.
//
// Ces deux défauts partageaient un trait : ils étaient **silencieux**. Le
// migrateur ne levait rien, le census R26 était satisfait, le rapport sortait
// vert — et la donnée était pourtant perdue ou exposée. Aucun garde-fou
// existant ne les voyait passer. D'où ces gardes.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

void main() {
  mainCr5();
  mainCr6();
  // Configuration de l'hôte IFFD : son soft-delete générique s'appelle
  // `deleted` (cf. lib/src/utils/functions/data_functions.dart), ses mindmaps
  // portent des arbres `nodes[].outputs` récursifs à clés camelCase, et son
  // champ `dashboard` est une sérialisation `flutter_flow_chart` intouchable.
  // ⚠️ PIÈGE D'USAGE (rencontré en écrivant ces gardes) : injecter un `codec`
  // REMPLACE intégralement celui par défaut du migrateur — donc perd sa config
  // IFFD (`valueMappers: {'status': mapDocumentStatus}` +
  // `preserveLegacyUnder: {'status'}`). Sans les réinscrire, le TRAP `status`
  // 6→4 n'est plus mappé du tout et `embedded` sort tel quel. Tout hôte qui
  // personnalise le codec DOIT les redéclarer.
  const iffdCodec = ZStudyLegacyCodec(
    valueMappers: <String, ZLegacyValueMapper>{
      'status': ZStudyLegacyCodec.mapDocumentStatus,
    },
    preserveLegacyUnder: <String>{'status'},
    syncMetaKeyAliases: <String, String>{'deleted': ZSyncMeta.kIsDeleted},
    recurseNested: true,
    opaqueKeys: <String>{'dashboard'},
  );
  const migrator = ZLegacyStudyMigrator(codec: iffdCodec);

  group('CR-IFFD-3 — alias de clé de sync (soft-delete sous un autre nom)', () {
    test('🔴 un document supprimé NE RESSUSCITE PAS', () {
      final out = migrator.migrateDocument(
        <String, dynamic>{'name': 'fiche', 'deleted': true},
      ).canonical;

      // Discriminant : sans l'alias, `camelToSnake('deleted')` laisse la clé
      // intacte, le `putIfAbsent` final ajoute `is_deleted:false`, et zcrud —
      // qui filtre la visibilité sur `is_deleted == false` — RÉAFFICHE le
      // document. Sur un dossier partagé, à d'autres utilisateurs.
      expect(out[ZSyncMeta.kIsDeleted], isTrue);
      // La valeur brute reste récupérable (AD-4, zéro perte de granularité).
      expect(out['_legacy_deleted'], isTrue);
      // La clé legacy est CONSOMMÉE, pas dupliquée dans le corps.
      expect(out.containsKey('deleted'), isFalse);
    });

    test('un document vivant reste visible', () {
      final out = migrator.migrateDocument(
        <String, dynamic>{'name': 'x', 'deleted': false},
      ).canonical;
      expect(out[ZSyncMeta.kIsDeleted], isFalse);
    });

    test('absent ⇒ non supprimé (défaut ouvert, comme IFFD `??= false`)', () {
      final out = migrator.migrateDocument(
        <String, dynamic>{'name': 'x', 'deleted': null},
      ).canonical;
      expect(out[ZSyncMeta.kIsDeleted], isFalse);
    });

    test('valeur ininterprétable ⇒ FAIL-CLOSED (masqué, jamais exposé)', () {
      final out = migrator.migrateDocument(
        <String, dynamic>{'name': 'x', 'deleted': 'oui'},
      ).canonical;
      // Choix asymétrique délibéré : masquer à tort est réparable (la valeur
      // brute survit sous `_legacy_`), exposer ne l'est pas.
      expect(out[ZSyncMeta.kIsDeleted], isTrue);
      expect(out['_legacy_deleted'], 'oui');
    });

    test('un corpus PARTIELLEMENT migré n\'est pas sauté', () {
      // `deleted` n'a aucune majuscule interne : avant correctif, ce document
      // passait la détection « déjà canonique » et n'était jamais retraité.
      final doc = <String, dynamic>{
        'name': 'x',
        'deleted': true,
        ZSyncMeta.kIsDeleted: false,
      };
      final outcome = migrator.migrateDocument(doc);
      expect(outcome.alreadyCanonical, isFalse);
      expect(outcome.canonical[ZSyncMeta.kIsDeleted], isTrue);
    });
  });

  group('CR-IFFD-2 — profondeur : détection et conversion récursives', () {
    test('🔴 contenu imbriqué legacy N\'est PLUS déclaré canonique', () {
      // Premier niveau irréprochable (snake_case + is_deleted), contenu
      // imbriqué intégralement legacy. Avant correctif : `alreadyCanonical`,
      // renvoyé INCHANGÉ, compté en succès au census — et la détection étant
      // un POINT FIXE, aucun passage ultérieur ne le rattrapait jamais.
      final outcome = migrator.migrateDocument(<String, dynamic>{
        'name': 'carte',
        ZSyncMeta.kIsDeleted: false,
        'nodes': <dynamic>[
          <String, dynamic>{
            'edgeColor': 42,
            'outputs': <dynamic>[
              <String, dynamic>{'edgeColor': 1},
            ],
          },
        ],
      });

      expect(outcome.alreadyCanonical, isFalse);
      final nodes = outcome.canonical['nodes'] as List<dynamic>;
      final first = nodes.first as Map<String, dynamic>;
      expect(first['edge_color'], 42);
      final outputs = first['outputs'] as List<dynamic>;
      expect((outputs.first as Map<String, dynamic>)['edge_color'], 1);
    });

    test('dates `int` millis normalisées à toute profondeur', () {
      final out = migrator.migrateDocument(<String, dynamic>{
        'deleted': false,
        'meta': <String, dynamic>{'createdAt': 1700000000000},
      }).canonical;
      final meta = out['meta'] as Map<String, dynamic>;
      expect(meta['created_at'], isA<String>());
      expect(meta['created_at'], contains('2023-'));
    });

    test('charge utile TIERCE protégée par opaqueKeys', () {
      // Renommer les champs d'un objet `flutter_flow_chart` le rendrait
      // indésérialisable par la bibliothèque qui l'a produit : « convertir »
      // serait ici pire que « laisser tel quel ».
      final out = migrator.migrateDocument(<String, dynamic>{
        'deleted': false,
        'dashboard': <String, dynamic>{
          'elementId': 'e1',
          'nested': <String, dynamic>{'kindValue': 3},
        },
      }).canonical;

      expect(out['dashboard'], <String, dynamic>{
        'elementId': 'e1',
        'nested': <String, dynamic>{'kindValue': 3},
      });
    });

    test('récursion DÉSACTIVÉE par défaut (rétro-compatibilité)', () {
      const plain = ZLegacyStudyMigrator();
      final out = plain.migrateDocument(<String, dynamic>{
        'nodes': <dynamic>[
          <String, dynamic>{'edgeColor': 5},
        ],
      }).canonical;
      final nodes = out['nodes'] as List<dynamic>;
      expect((nodes.first as Map<String, dynamic>)['edgeColor'], 5);
    });
  });

  group('Invariants préservés', () {
    test('idempotence : migrate ∘ migrate == migrate, suppression conservée',
        () {
      final once = migrator.migrateDocument(<String, dynamic>{
        'name': 'c',
        'status': 'embedded',
        'deleted': true,
        'nodes': <dynamic>[
          <String, dynamic>{'edgeColor': 7},
        ],
      }).canonical;

      final twice = migrator.migrateDocument(once);
      expect(twice.alreadyCanonical, isTrue);
      expect(twice.canonical, once, reason: 'point fixe strict');
      expect(twice.canonical[ZSyncMeta.kIsDeleted], isTrue,
          reason: 'une reprise ne doit jamais ressusciter');
      expect(twice.canonical['status'], 'ready',
          reason: 'TRAP status : jamais rétrogradé');
    });

    test('AD-10 — ne throw jamais, même sur entrée hostile', () {
      final hostiles = <Map<String, dynamic>>[
        <String, dynamic>{},
        <String, dynamic>{'deleted': <int>[1, 2]},
        <String, dynamic>{
          'nodes': <dynamic>[null, 3, 'x'],
        },
        <String, dynamic>{
          'a': <dynamic, dynamic>{1: 'cléNonString'},
        },
      ];
      for (final h in hostiles) {
        expect(() => migrator.migrateDocument(h), returnsNormally);
      }
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CR-IFFD-5 — renommage SÉMANTIQUE de clé métier (`quality` → `last_quality`).
// ─────────────────────────────────────────────────────────────────────────────
void mainCr5() {
  const codec = ZStudyLegacyCodec(
    keyAliases: <String, String>{'quality': 'last_quality'},
    syncMetaKeyAliases: <String, String>{'deleted': ZSyncMeta.kIsDeleted},
  );
  const migrator = ZLegacyStudyMigrator(codec: codec);

  group('CR-IFFD-5 — keyAliases', () {
    test('la clé est renommée vers sa cible sémantique', () {
      final out = migrator
          .migrateDocument(<String, dynamic>{'quality': 4}).canonical;
      expect(out['last_quality'], 4);
      expect(out.containsKey('quality'), isFalse);
    });

    test('🔴 le census CRÉDITE la clé aliasée (sinon rapport rouge à tort)', () {
      // Sans le volet census, `quality` serait cherchée sous `quality` ou
      // `_legacy_quality` — introuvables — donc déclarée PERDUE sur CHAQUE
      // document, rendant le dry-run inexploitable.
      final o = migrator.migrateDocument(<String, dynamic>{'quality': 4});
      expect(o.isPreservationComplete, isTrue);
      expect(o.lostBusinessKeys, isEmpty);
    });

    test('🔴 une clé source résiduelle n\'est PAS déclarée canonique', () {
      // `quality` n'a aucune majuscule interne : la seule détection de camelCase
      // l'aurait laissée passer et le document n'aurait jamais été renommé.
      final o = migrator.migrateDocument(
        <String, dynamic>{'quality': 4, ZSyncMeta.kIsDeleted: false},
      );
      expect(o.alreadyCanonical, isFalse);
      expect(o.canonical['last_quality'], 4);
    });

    test('collision : aucune valeur écrasée en silence', () {
      final out = migrator.migrateDocument(<String, dynamic>{
        'lastQuality': 1,
        'quality': 9,
      }).canonical;
      // L'une occupe la cible, l'autre survit sous `_legacy_` — rien n'est perdu.
      expect(out['last_quality'], anyOf(1, 9));
      expect(out.values.contains(9), isTrue);
      expect(out.values.contains(1), isTrue);
    });

    test('idempotence : le document renommé est un point fixe', () {
      final once =
          migrator.migrateDocument(<String, dynamic>{'quality': 4}).canonical;
      final twice = migrator.migrateDocument(once);
      expect(twice.alreadyCanonical, isTrue);
      expect(twice.canonical, once);
    });

    test('sans keyAliases, comportement v0.3.3 inchangé', () {
      const plain = ZLegacyStudyMigrator();
      final out =
          plain.migrateDocument(<String, dynamic>{'quality': 4}).canonical;
      expect(out['quality'], 4);
      expect(out.containsKey('last_quality'), isFalse);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// CR-IFFD-6 — collision d'alias : INDÉPENDANCE À L'ORDRE des clés.
//
// Défaut trouvé par la session IFFD en éprouvant par exécution une affirmation
// du handoff v0.3.4 qui était FAUSSE : la préservation ne tenait que dans un
// ordre sur deux, et le census se déclarait satisfait dans les deux.
// ─────────────────────────────────────────────────────────────────────────────
void mainCr6() {
  const migrator = ZLegacyStudyMigrator(
    codec: ZStudyLegacyCodec(
      keyAliases: <String, String>{'quality': 'last_quality'},
    ),
  );

  group('CR-IFFD-6 — collision indépendante de l\'ordre', () {
    test('🔴 les deux ordres produisent un résultat IDENTIQUE', () {
      // Firestore ne garantit pas l'ordre des clés d'un document : un résultat
      // qui en dépend est non déterministe du point de vue de l'appelant.
      final a = migrator
          .migrateDocument(<String, dynamic>{'quality': 1, 'lastQuality': 5})
          .canonical;
      final b = migrator
          .migrateDocument(<String, dynamic>{'lastQuality': 5, 'quality': 1})
          .canonical;
      expect(a, b, reason: 'la sortie ne doit dépendre que du CONTENU');
    });

    test('🔴 aucune valeur perdue, quel que soit l\'ordre', () {
      for (final doc in <Map<String, dynamic>>[
        <String, dynamic>{'quality': 1, 'lastQuality': 5},
        <String, dynamic>{'lastQuality': 5, 'quality': 1},
      ]) {
        final out = migrator.migrateDocument(doc).canonical;
        expect(out.values.contains(5), isTrue, reason: 'gagnant présent');
        expect(out['_legacy_quality'], 1, reason: 'perdant PRÉSERVÉ');
      }
    });

    test('la collision est JOURNALISÉE (jamais silencieuse)', () {
      final out = migrator
          .migrateDocument(<String, dynamic>{'quality': 1, 'lastQuality': 5})
          .canonical;
      expect(
        out[ZStudyLegacyCodec.kAliasCollisionsKey],
        <String>['last_quality'],
      );
    });

    test('la forme DÉJÀ CANONIQUE prime — une reprise ne rétrograde pas', () {
      // Reprise réelle : le document porte le résultat d'une migration
      // antérieure (`last_quality`) ET la clé legacy résiduelle (`quality`).
      final out = migrator
          .migrateDocument(<String, dynamic>{'quality': 1, 'last_quality': 9})
          .canonical;
      expect(out['last_quality'], 9, reason: 'le migré prime sur le legacy');
      expect(out['_legacy_quality'], 1, reason: 'le legacy survit quand même');
    });

    test('sans collision, aucune clé de journal parasite', () {
      final out =
          migrator.migrateDocument(<String, dynamic>{'quality': 3}).canonical;
      expect(out['last_quality'], 3);
      expect(out.containsKey(ZStudyLegacyCodec.kAliasCollisionsKey), isFalse);
    });
  });
}
