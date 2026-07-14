/// Tests de [ZSmartNote] (ES-2.2) — AC3, AC6, AC7, AC8, AC9, AC11.
///
/// Le groupe « **AD-19 — clés de sync hors-entité** » est **calqué** sur celui de
/// `z_document_reading_state_test.dart` / `z_repetition_info_test.dart` : il est
/// **reproduit, pas réinventé** (R-A/R-C — l'oubli s'est produit **2 fois sur 4**
/// en ES-1.3, **sous 1193 tests verts**).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_note/zcrud_note.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // AC6 / R-C — AD-19 dès la NAISSANCE : zéro clé de sync dans l'entité.
  //
  // 🔴 lex porte `final DateTime updatedAt;` INLINE (smart_note.dart l. 42) ET
  // son repository AVOUE en maintenir une copie hors-entité « à la main »
  // (smart_notes_repository.dart l. 12-16). Le porter aurait logé la CLÉ
  // D'AUTORITÉ DU MERGE dans le corps métier — que le store ÉCRASE à chaque `put`.
  // ═══════════════════════════════════════════════════════════════════════════
  group('ZSmartNote — AD-19 : clés de sync hors-entité (AC6/AC7)', () {
    test(r'(R-C) `$ZSmartNoteFieldSpecs` ∩ ZSyncMeta.reservedKeys == {}', () {
      final specNames = $ZSmartNoteFieldSpecs.map((s) => s.name).toSet();
      expect(
        specNames.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
        reason: 'ES-2.1 avait OUBLIÉ cette assertion sur sa 3ᵉ entité '
            '(finding M1) — ne pas rejouer.',
      );
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
      expect(specNames, isNot(contains('updatedAt')));
      expect(specNames, isNot(contains('isDeleted')));
    });

    test('`created_at` est bien au schéma (clé DISTINCTE, jamais réservée)', () {
      final specNames = $ZSmartNoteFieldSpecs.map((s) => s.name).toSet();
      expect(specNames, contains('created_at'));
      expect(ZSyncMeta.reservedKeys, isNot(contains('created_at')));
    });

    test('(AD-19.1.b) aucun `persistAs: timestamp` sur une clé réservée', () {
      expect(
        $ZSmartNoteTimestampFields.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
      expect($ZSmartNoteTimestampFields, isEmpty);
    });

    test('(R-A) fromMap d\'une SONDE DE STORE : clés de sync hors de `extra`',
        () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'id': 'n1',
        'folder_id': 'f1',
        'title': 't',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'corps\n'},
        ],
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      });

      // (a) — aucune clé réservée capturée.
      expect(n.extra.containsKey('updated_at'), isFalse);
      expect(n.extra.containsKey('is_deleted'), isFalse);
      expect(n.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys), isEmpty);

      // ANTI-VACUITÉ : on ne « passe » pas (a) en VIDANT `extra`.
      expect(n.extra['zz_cle_inconnue'], 'gardee');

      // (f) — le CANAL `content` n'est PAS dans `extra` (il est RÉSERVÉ).
      expect(
        n.extra.containsKey('content'),
        isFalse,
        reason: 'une clé du CORPS DE SONDE dans `extra` PROUVE un canal oublié '
            'dans `_reservedKeys` (règle (f) / (g1)).',
      );
      expect(n.content.single['insert'], 'corps\n');
    });

    test('(R-A) toMap() ne RÉÉMET aucune clé de sync (AD-16)', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'id': 'n1',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
      });
      final m = n.toMap();
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('is_deleted'), isFalse);
      expect(m.containsKey('updatedAt'), isFalse);
      expect(m.containsKey('isDeleted'), isFalse);
    });

    test('toMap() n\'émet `content` QU\'UNE FOIS (pas de doublon extra/canal)',
        () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ],
        'zz_cle_inconnue': 'gardee',
      });
      final m = n.toMap();
      // Une Map ne peut pas porter deux fois la clé : la preuve du non-doublon
      // est que la valeur émise est la LISTE NATIVE (canal), pas la valeur brute
      // ré-étalée par `...extra`.
      expect(m['content'], same(n.content));
      expect(m['zz_cle_inconnue'], 'gardee');
    });

    test('convergence : une note en mémoire == la même relue du store', () {
      final fromStore = ZSmartNote.fromMap(<String, dynamic>{
        'id': 'n1',
        'folder_id': 'f1',
        'title': 't',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ],
        'updated_at': '2026-05-05T00:00:00.000Z',
        'is_deleted': false,
      });
      final inMemory = ZSmartNote(
        id: 'n1',
        folderId: 'f1',
        title: 't',
        content: <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a\n'},
        ],
      );
      expect(fromStore.extra, isEmpty);
      expect(fromStore, inMemory);
      expect(fromStore.hashCode, inMemory.hashCode);
    });

    test('`kLegacyUpdatedAtMirrors` : `ZSmartNote` n\'est PAS un miroir legacy',
        () {
      // L'entité est NEUVE : elle ne peut légitimement porter aucun miroir.
      final n = ZSmartNote.fromMap(const <String, dynamic>{});
      expect(n.toMap().containsKey('updated_at'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC3 / D11 — `content` est un CANAL, pas un CHAMP.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC3 / D11 — `content` : canal hors-codegen, aucun ZFieldSpec', () {
    test(r"`content` n'est PAS dans `$ZSmartNoteFieldSpecs`", () {
      final names = $ZSmartNoteFieldSpecs.map((s) => s.name).toSet();
      expect(
        names,
        isNot(contains('content')),
        reason: 'canal HORS-CODEGEN (le générateur ne supporte AUCUN type '
            '`Map`) ⇒ aucun `ZFieldSpec` ⇒ absent d\'un formulaire GÉNÉRÉ. '
            'CE N\'EST PAS UN OUBLI (D11) : l\'éditeur d\'ES-6.1 ajoutera son '
            '`ZMarkdownField` EXPLICITEMENT.',
      );
      expect(names, <String>{
        'id',
        'folder_id',
        'sub_folder_id',
        'title',
        'created_at',
      });
    });

    test('le canal est néanmoins DÉCODÉ et RÉÉMIS (il vit hors du schéma)', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'x\n'},
        ],
      });
      expect(n.content.single['insert'], 'x\n');
      expect(n.toMap()['content'], n.content);
    });

    test('toMap() émet TOUJOURS `content`, même VIDE (round-trip idempotent)',
        () {
      const n = ZSmartNote();
      final m = n.toMap();
      expect(m.containsKey('content'), isTrue);
      expect(m['content'], isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC5 — AUDIO HORS-SCHÉMA : les DEUX voies (extra ET ZNoteAudio).
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC5 — audio hors-schéma (FR-S5 / D6)', () {
    test('aucun champ audio au schéma (assertion MACHINE)', () {
      final names = $ZSmartNoteFieldSpecs.map((s) => s.name).toSet();
      expect(names, isNot(contains('audio_url')));
      expect(names, isNot(contains('audio_path')));
      expect(names, isNot(contains('audio_text_hash')));
    });

    test('VOIE `extra` : audio top-level legacy ⇒ `extra` + ROUND-TRIP', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'id': 'n1',
        'title': 't',
        'audio_url': 'https://x/a.mp3',
        'audio_path': '/local/a.mp3',
        'audio_text_hash': 12345, // int (IFFD)
        'audio_text': 'texte source', // IFFD, sans équivalent lex
      });
      expect(n.extra['audio_url'], 'https://x/a.mp3');
      expect(n.extra['audio_path'], '/local/a.mp3');
      expect(n.extra['audio_text_hash'], 12345);
      expect(n.extra['audio_text'], 'texte source');

      final m = n.toMap();
      expect(m['audio_url'], 'https://x/a.mp3');
      expect(m['audio_path'], '/local/a.mp3');
      expect(m['audio_text_hash'], 12345);
      expect(m['audio_text'], 'texte source');
    });

    test('VOIE TYPÉE : `ZNoteAudio` round-trippe via `extension`', () {
      const audio = ZNoteAudio(
        url: 'https://x/a.mp3',
        path: '/local/a.mp3',
        textHash: 'abc',
      );
      final source = ZSmartNote(id: 'n1', extension: audio).toMap();

      final relu = ZSmartNote.fromMap(
        source,
        extensionParser: ZNoteAudio.fromJsonSafe,
      );
      expect(relu.extension, isA<ZNoteAudio>());
      expect(relu.extension, audio);
      expect((relu.extension! as ZNoteAudio).textHash, 'abc');
    });

    test('note SANS audio ⇒ `extension == null`, `extra` sans clé audio', () {
      final n = ZSmartNote.fromMap(
        <String, dynamic>{'id': 'n1', 'title': 't'},
        extensionParser: ZNoteAudio.fromJsonSafe,
      );
      expect(n.extension, isNull);
      expect(n.extra, isEmpty);
      expect(n.toMap().containsKey('extension'), isFalse);
    });

    test('`extension` NON-`Map` ⇒ `null` (rien à préserver), JAMAIS de throw', () {
      for (final raw in <Object?>[42, 'texte', <Object?>[], true]) {
        late final ZSmartNote n;
        expect(
          () => n = ZSmartNote.fromMap(
            <String, dynamic>{'id': 'n1', 'extension': raw},
            extensionParser: ZNoteAudio.fromJsonSafe,
          ),
          returnsNormally,
          reason: 'extension: $raw',
        );
        expect(n.extension, isNull, reason: 'extension: $raw');
        expect(n.id, 'n1', reason: 'le PARENT survit toujours (AD-10)');
        expect(n.toMap().containsKey('extension'), isFalse);
      }
    });

    test('`extension` NON TYPABLE mais `Map` ⇒ OPAQUE (payload PRÉSERVÉ), '
        'jamais `null`', () {
      // Une `Map` que le parser ne sait pas typer (version inconnue, sous-schéma
      // étranger) : elle n'est PLUS jetée — elle est PORTÉE VERBATIM.
      for (final raw in <Map<String, dynamic>>[
        <String, dynamic>{'format_version': 99},
        <String, dynamic>{},
        <String, dynamic>{'kind': 'un_autre_schema', 'x': 1},
      ]) {
        final n = ZSmartNote.fromMap(
          <String, dynamic>{'id': 'n1', 'extension': raw},
          extensionParser: ZNoteAudio.fromJsonSafe,
        );
        expect(n.extension, isA<ZOpaqueNoteExtension>(), reason: '$raw');
        expect(n.extension, isNot(isA<ZNoteAudio>()), reason: '$raw');
        expect(n.toMap()['extension'], equals(raw), reason: '$raw');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🟠 MAJEUR-2 (code-review ES-2.2) — `format_version` FUTURE : le payload
  // SURVIT. AD-4 pt.1 (« évolution additive ») cesse d'être de la PROSE.
  //
  // v1 MESURÉE : `extension: {format_version: 2, …}` ⇒ `extension == null` ⇒
  // `toMap()` N'ÉMETTAIT PAS la clé ⇒ une app v1 qui RELIT puis RÉÉCRIT une note
  // écrite par v2 EFFAÇAIT le slot v2 du store. DÉFINITIVEMENT.
  // Le test de la v1 (`z_note_audio_test.dart:56`) n'observait que `isNull` — il
  // ne demandait JAMAIS ce qu'il advenait du PAYLOAD.
  // ═══════════════════════════════════════════════════════════════════════════
  group('MAJEUR-2 — une version FUTURE ne DÉTRUIT plus le payload', () {
    const payloadV2 = <String, dynamic>{
      'format_version': 2,
      'url': 'u',
      'nouveau_champ': 'x',
      'imbrique': <String, dynamic>{'a': 1},
    };

    test('🔴 le payload v2 SURVIT au cycle lecture → réécriture d\'une app v1',
        () {
      final v1Lit = ZSmartNote.fromMap(
        <String, dynamic>{'id': 'n1', 'title': 't', 'extension': payloadV2},
        extensionParser: ZNoteAudio.fromJsonSafe, // app v1 : ne connaît que v1
      );

      // Le slot n'est pas TYPÉ (la v1 ne sait pas lire v2) — c'est correct.
      expect(v1Lit.extension, isNot(isA<ZNoteAudio>()));
      // …mais le PAYLOAD est PORTÉ.
      expect(v1Lit.extension, isA<ZOpaqueNoteExtension>());
      expect((v1Lit.extension! as ZOpaqueNoteExtension).payload, payloadV2);

      // L'app v1 édite le TITRE et RÉÉCRIT : le slot v2 est TOUJOURS là.
      final reecrit = v1Lit.copyWith(title: 'nouveau titre').toMap();
      expect(
        reecrit['extension'],
        equals(payloadV2),
        reason: '⛔ v1 : le slot v2 était EFFACÉ du store — la version SUIVANTE '
            'ne le retrouvait JAMAIS. `formatVersion` avait une EXISTENCE, aucun '
            'POUVOIR de préservation.',
      );

      // Et une app v2 (qui, elle, sait lire) le retrouve INTACT.
      expect(ZSmartNote.fromMap(reecrit).toMap()['extension'], payloadV2);
    });

    test('la version est RAPPORTÉE, jamais interprétée', () {
      final n = ZSmartNote.fromMap(
        <String, dynamic>{'extension': payloadV2},
        extensionParser: ZNoteAudio.fromJsonSafe,
      );
      expect(n.extension!.formatVersion, 2);
      expect(ZNoteAudio.fromJsonSafe(payloadV2), isNull,
          reason: 'le contrat de `ZNoteAudio` est INCHANGÉ : version non gérée '
              '⇒ `null`. C\'est l\'ENTITÉ qui refuse désormais de détruire.');
    });

    test('round-trip OPAQUE idempotent + `==` PROFONDE (payload imbriqué)', () {
      final a = ZSmartNote.fromMap(<String, dynamic>{'extension': payloadV2});
      final b = ZSmartNote.fromMap(a.toMap());
      expect(b, a);
      expect(b.hashCode, a.hashCode);
      expect(b.toMap(), a.toMap());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🟠 MAJEUR-1 / DW-ES14-2 — VERROU D'HONNÊTETÉ LOCAL.
  //
  // `ZNoteAudio` est la PREMIÈRE `ZExtension` concrète du repo ⇒ elle FALSIFIE la
  // clause d'échappement n°1 de DW-ES14-2 (« si et seulement si l'entité n'utilise
  // pas le slot `extension` »). `registerZSmartNote` câble `fromMap:
  // ZSmartNote.fromMap` SANS `extensionParser` (le registre n'offre AUCUN slot
  // d'injection).
  //
  // ⇒ AC5 (« VOIE TYPÉE : ZNoteAudio round-trippe ») était VERT sur une voie
  //   qu'AUCUN câblage de production n'emprunte.
  //
  // ⚠️ CE GROUPE DOIT ÊTRE INVERSÉ quand DW-ES14-2 sera soldée (slot d'injection
  //    dans `ZcrudRegistry`) : `extension` deviendra un `ZNoteAudio` et les deux
  //    `isNot`/`isA` ci-dessous rougiront — ce sera le SIGNAL DU SUCCÈS. Ne pas
  //    « réparer » en supprimant les assertions.
  // ═══════════════════════════════════════════════════════════════════════════
  group('DW-ES14-2 — VERROU : la voie REGISTRE ne TYPE PAS le slot `extension`',
      () {
    const audioPayload = <String, dynamic>{
      'format_version': 1,
      'url': 'https://x/a.mp3',
      'path': '/local/a.mp3',
      'text_hash': 'abc',
    };

    test('⛔ TYPE PERDU : `registry.decode` ne rend JAMAIS un `ZNoteAudio`', () {
      final registry = ZcrudRegistry();
      registerZSmartNote(registry);

      final entity = registry.decode('smart_note', <String, dynamic>{
        'id': 'n1',
        'title': 't',
        'extension': audioPayload,
      }) as ZSmartNote;

      expect(
        entity.extension,
        isNot(isA<ZNoteAudio>()),
        reason: 'DW-ES14-2 SOLDÉE ? Le registre TYPE désormais le slot — '
            'INVERSER ce verrou (et retirer la clause n°1 de la dette), ne pas '
            'le supprimer.',
      );
      expect(
        entity.extension,
        isA<ZOpaqueNoteExtension>(),
        reason: 'le payload est PORTÉ (mitigation MAJEUR-1), mais NON TYPÉ : '
            'l\'app ne peut PAS lire l\'audio par cette voie.',
      );
    });

    test('✅ DONNÉE PRÉSERVÉE : le payload SURVIT au round-trip registre', () {
      final registry = ZcrudRegistry();
      registerZSmartNote(registry);

      final entity = registry.decode('smart_note', <String, dynamic>{
        'id': 'n1',
        'title': 't',
        'extension': audioPayload,
      });
      final encoded = registry.encode('smart_note', entity);

      expect(
        encoded['extension'],
        equals(audioPayload),
        reason: '⛔ AVANT la remédiation MAJEUR-1 : `extension` était ABSENTE du '
            'ré-encodage (`extension == null` ⇒ clé omise) et, `extension` étant '
            'une clé RÉSERVÉE, elle ne tombait pas non plus dans `extra` : le '
            'slot audio était EFFACÉ DU STORE au premier `put`. IRRÉVERSIBLE.',
      );
      expect((entity as ZExtensible).extra.containsKey('extension'), isFalse,
          reason: '`extension` reste une clé RÉSERVÉE : le payload est réémis '
              'par le CANAL, jamais par une FUITE dans `extra`.');
    });

    test('CONTOURNEMENT documenté : le constructeur nominal, lui, TYPE le slot',
        () {
      final n = ZSmartNote.fromMap(
        <String, dynamic>{'id': 'n1', 'extension': audioPayload},
        extensionParser: ZNoteAudio.fromJsonSafe,
      );
      expect(n.extension, isA<ZNoteAudio>());
      expect((n.extension! as ZNoteAudio).url, 'https://x/a.mp3');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🟠 MAJEUR-3 — la garde de `extra` est PARTAGÉE par fromMap / copyWith / toMap.
  //
  // La v1 avait appliqué la leçon H2 à `content`… et OUBLIÉ l'AUTRE garde du même
  // `fromMap` : le filtre des clés RÉSERVÉES (`_extraFrom`). MESURÉ :
  //   note.copyWith(extra: {'updated_at': …, 'is_deleted': true}).toMap()
  //     ⇒ toMap PORTAIT updated_at ET is_deleted — la dartdoc de `toMap()`
  //       promettait pourtant l'inverse SANS CONDITION.
  // ═══════════════════════════════════════════════════════════════════════════
  group('MAJEUR-3 / H2 — `copyWith(extra:)` ne ROUVRE PAS le filtre réservé', () {
    test('🔴 `copyWith(extra: {clés de sync})` ⇒ DÉPOUILLÉES (extra ET toMap)',
        () {
      final n = ZSmartNote.fromMap(<String, dynamic>{'id': 'n1', 'title': 't'});
      final pollue = n.copyWith(extra: <String, dynamic>{
        'updated_at': '1999-01-01T00:00:00.000Z',
        'is_deleted': true,
        'zz_metier': 'gardee',
      });

      expect(pollue.extra.containsKey('updated_at'), isFalse);
      expect(pollue.extra.containsKey('is_deleted'), isFalse);
      final m = pollue.toMap();
      expect(
        m.containsKey('updated_at'),
        isFalse,
        reason: 'le store réécrit `ZSyncMeta` APRÈS le corps (AD-19) : une clé '
            'de sync MÉTIER dans le corps corrompt l\'autorité LWW. C\'est le '
            'piège R-C que la story déclare fermer.',
      );
      expect(m.containsKey('is_deleted'), isFalse);

      // ANTI-VACUITÉ : on ne « passe » pas en VIDANT `extra`.
      expect(pollue.extra['zz_metier'], 'gardee');
      expect(m['zz_metier'], 'gardee');
    });

    test('`copyWith(extra:)` dépouille AUSSI les clés de CANAL / de SCHÉMA', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{'id': 'n1'});
      final copie = n.copyWith(extra: <String, dynamic>{
        'content': 'sosie du canal',
        'title': 'sosie du schéma',
        'extension': <String, dynamic>{'faux': true},
        'zz_metier': 'gardee',
      });
      expect(copie.extra.keys, <String>['zz_metier']);
      // Le canal reste émis UNE FOIS, par le CANAL (pas par `...extra`).
      expect(copie.toMap()['content'], same(copie.content));
      expect(copie.toMap()['title'], '');
      expect(copie.toMap().containsKey('extension'), isFalse);
    });

    test('🔴 la promesse de `toMap()` est INCONDITIONNELLE (même hors fromMap)',
        () {
      // Le constructeur `const` ne peut RIEN filtrer (AD-10 interdit l'`assert`)
      // ⇒ c'est `toMap()`, FRONTIÈRE DE SORTIE, qui rejoue la garde.
      const n = ZSmartNote(
        id: 'n1',
        extra: <String, dynamic>{
          'updated_at': '1999-01-01T00:00:00.000Z',
          'is_deleted': true,
          'zz_metier': 'gardee',
        },
      );
      final m = n.toMap();
      expect(m.containsKey('updated_at'), isFalse);
      expect(m.containsKey('is_deleted'), isFalse);
      expect(m['zz_metier'], 'gardee');
    });

    test('`extra` reste NON MODIFIABLE après `copyWith`', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{'id': 'n1'})
          .copyWith(extra: <String, dynamic>{'a': 1});
      expect(() => n.extra['b'] = 2, throwsUnsupportedError);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 🟡 MEDIUM-1 — `==`/`hashCode` : égalité PROFONDE sur `extra` AUSSI.
  //
  // L'argument écrit pour `noteContentEquals` (« sinon l'`==` entre une note en
  // mémoire et la même relue du store casserait ») s'applique MOT POUR MOT à
  // `extra`, dont la raison d'être (AD-4 pt.2) est de porter du JSON IMBRIQUÉ.
  // Les sondes de la v1 n'utilisaient QUE des scalaires ⇒ vertes pour une
  // MAUVAISE raison.
  // ═══════════════════════════════════════════════════════════════════════════
  group('MEDIUM-1 — `extra` IMBRIQUÉ : `fromMap(m) == fromMap(m)`', () {
    Map<String, dynamic> doc() => <String, dynamic>{
          'id': 'n1',
          'title': 't',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'a\n'},
          ],
          'legacy_meta': <String, dynamic>{
            'a': 1,
            'b': <Object?>[1, 2],
          },
          'tags': <Object?>['x', 'y'],
        };

    test('🔴 deux décodages SÉPARÉS du même document sont ÉGAUX', () {
      final a = ZSmartNote.fromMap(doc());
      final b = ZSmartNote.fromMap(doc());
      expect(a, b, reason: 'MESURÉ en v1 : `false` — `_mapEquals` était '
          'SUPERFICIEL ⇒ toute déduplication (`Set`), tout cache mémoïsé, tout '
          '`expect(relu, original)` était CASSÉ dès qu\'une clé legacy portait '
          'une `Map`/`List`.');
      expect(a.hashCode, b.hashCode);
      expect(<ZSmartNote>{a, b}, hasLength(1));
    });

    test('POUVOIR DISCRIMINANT : une valeur imbriquée DIFFÉRENTE casse l\'`==`',
        () {
      final a = ZSmartNote.fromMap(doc());
      final modifie = doc()
        ..['legacy_meta'] = <String, dynamic>{
          'a': 2, // ← une seule feuille change
          'b': <Object?>[1, 2],
        };
      expect(a, isNot(ZSmartNote.fromMap(modifie)));

      final listeModifiee = doc()..['tags'] = <Object?>['x', 'z'];
      expect(a, isNot(ZSmartNote.fromMap(listeModifiee)));
    });

    test('round-trip complet avec `extra` IMBRIQUÉ (mémoire == store)', () {
      final a = ZSmartNote.fromMap(doc());
      expect(ZSmartNote.fromMap(a.toMap()), a);
      expect(ZSmartNote.fromMap(a.toMap()).hashCode, a.hashCode);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC11 / R-H — chaque invariant : sa GARDE **et** son cas CORROMPU.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC11 — invariants de valeur : garde + désérialisation corrompue', () {
    test('`ZSmartNote.fromMap(const {})` NE THROW PAS (map vide)', () {
      late final ZSmartNote n;
      expect(() => n = ZSmartNote.fromMap(const <String, dynamic>{}),
          returnsNormally);
      expect(n.id, isNull);
      expect(n.isEphemeral, isTrue);
      expect(n.folderId, '');
      expect(n.subFolderId, isNull);
      expect(n.title, '');
      expect(n.content, isEmpty);
      expect(n.createdAt, isNull);
      expect(n.extension, isNull);
      expect(n.extra, isEmpty);
    });

    test('`title` / `folderId` : garde + corrompu ⇒ `\'\'`', () {
      final ok = ZSmartNote.fromMap(<String, dynamic>{
        'title': 'T',
        'folder_id': 'F',
      });
      expect(ok.title, 'T');
      expect(ok.folderId, 'F');

      final ko = ZSmartNote.fromMap(<String, dynamic>{
        'title': 42,
        'folder_id': <Object?>[],
      });
      expect(ko.title, '');
      expect(ko.folderId, '');
    });

    test('`subFolderId` : garde + corrompu ⇒ `null`', () {
      expect(
        ZSmartNote.fromMap(<String, dynamic>{'sub_folder_id': 'S'}).subFolderId,
        'S',
      );
      expect(
        ZSmartNote.fromMap(<String, dynamic>{'sub_folder_id': 42}).subFolderId,
        isNull,
      );
      expect(
        ZSmartNote.fromMap(const <String, dynamic>{}).subFolderId,
        isNull,
      );
    });

    test('`createdAt` ISO-8601 : garde + corrompu ⇒ `null`', () {
      expect(
        ZSmartNote.fromMap(<String, dynamic>{
          'created_at': '2026-07-13T10:00:00.000Z',
        }).createdAt,
        DateTime.utc(2026, 7, 13, 10),
      );
      expect(
        ZSmartNote.fromMap(<String, dynamic>{'created_at': 'pas-une-date'})
            .createdAt,
        isNull,
      );
      expect(
        ZSmartNote.fromMap(<String, dynamic>{'created_at': 42}).createdAt,
        isNull,
      );
      expect(
        ZSmartNote.fromMap(const <String, dynamic>{}).createdAt,
        isNull,
      );
    });

    test('🔴 `content` : le TEXTE LEGACY N\'EST JAMAIS DÉTRUIT (le cas D5)', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'title': 'Note lex',
        'content': '# T', // `String` MARKDOWN (lex)
      });
      expect(n.content, isNotEmpty, reason: '🔴 le corps de la note SURVIT.');
      expect(n.content.single['insert'], '# T\n');

      // Le cycle store complet : ce qu'on RÉÉCRIT porte encore le texte.
      expect(n.toMap()['content'], n.content);
      final relu = ZSmartNote.fromMap(n.toMap());
      expect(relu.content.single['insert'], '# T\n');
      expect(relu, n, reason: 'round-trip STABLE au second passage.');
    });

    test('AUCUNE map ne fait throw (corpus de corruption)', () {
      final maps = <Map<String, dynamic>>[
        const <String, dynamic>{},
        <String, dynamic>{'id': 42},
        <String, dynamic>{'content': 42},
        <String, dynamic>{'content': <Object?>[1, 2]},
        <String, dynamic>{
          'content': <Object?>[
            <String, dynamic>{'retain': 1},
          ],
        },
        <String, dynamic>{'content': ''},
        <String, dynamic>{'content': '# md'},
        <String, dynamic>{'created_at': <Object?>[]},
        <String, dynamic>{'extension': 'corrompue'},
        <String, dynamic>{'title': true, 'folder_id': 3.14},
      ];
      for (final m in maps) {
        expect(() => ZSmartNote.fromMap(m), returnsNormally, reason: '$m');
        expect(() => ZSmartNote.fromMap(m).toMap(), returnsNormally,
            reason: '$m');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC9 / H2 (ES-2.1) — la GARDE est PARTAGÉE par `fromMap` ET `copyWith`.
  //
  // `ZStudyDocument.copyWith` ROUVRAIT l'invariant `sizeBytes >= 0` que `fromMap`
  // fermait, alors que la dartdoc promettait « jamais négative » : une promesse en
  // PROSE qu'aucune machine ne tenait.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC9 / H2 — `copyWith` ne ROUVRE PAS la garde du contenu', () {
    test('🔴 `copyWith(content: [{retain: 1}])` ⇒ ops NORMALISÉES (`[]`)', () {
      const n = ZSmartNote(id: 'n1');
      final copie = n.copyWith(content: <Map<String, dynamic>>[
        <String, dynamic>{'retain': 1}, // op INVALIDE (diff, pas document)
      ]);
      expect(
        copie.content,
        isEmpty,
        reason: 'la mutation applicative est une FRONTIÈRE au même titre que la '
            'désérialisation : ne fermer que `fromMap` laisserait la garde '
            'ROUVRABLE (H2, ES-2.1).',
      );
      // Et donc : rien d'invalide n'est PERSISTÉ.
      expect(copie.toMap()['content'], isEmpty);
    });

    test('`copyWith(content: <String markdown>)` ⇒ MÊME coercition qu\'en fromMap',
        () {
      const n = ZSmartNote(id: 'n1');
      final copie = n.copyWith(content: '# T');
      expect(copie.content.single['insert'], '# T\n');
      expect(copie.content, ZSmartNote.fromMap(<String, dynamic>{'content': '# T'}).content);
    });

    test('round-trip IDEMPOTENT après `copyWith` (ops valides préservées)', () {
      const n = ZSmartNote(id: 'n1');
      final copie = n.copyWith(content: <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'a\n'},
      ]);
      expect(ZSmartNote.fromMap(copie.toMap()), copie);
    });

    test('`copyWith` à sentinelle : couvre TOUS les champs (dont extra/extension)',
        () {
      const audio = ZNoteAudio(url: 'u');
      final n = ZSmartNote.fromMap(
        <String, dynamic>{
          'id': 'n1',
          'folder_id': 'f',
          'sub_folder_id': 's',
          'title': 't',
          'content': <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'a\n'},
          ],
          'created_at': '2026-07-13T10:00:00.000Z',
          'zz_cle_inconnue': 'gardee',
          'extension': <String, dynamic>{'format_version': 1, 'url': 'u'},
        },
        extensionParser: ZNoteAudio.fromJsonSafe,
      );
      expect(n.extension, audio);

      // Un `copyWith` d'un SEUL champ ne détruit AUCUN des autres (le `copyWith`
      // GÉNÉRÉ, lui, remettrait `content`/`extra`/`extension` aux défauts — d'où
      // le `hide ZSmartNoteZcrud` du barrel, règle (h)).
      final copie = n.copyWith(title: 'nouveau');
      expect(copie.title, 'nouveau');
      expect(copie.id, 'n1');
      expect(copie.folderId, 'f');
      expect(copie.subFolderId, 's');
      expect(copie.content, n.content);
      expect(copie.createdAt, n.createdAt);
      expect(copie.extra['zz_cle_inconnue'], 'gardee');
      expect(copie.extension, audio);
    });

    test('sentinelle : `null` EXPLICITE remet bien à `null`', () {
      const n = ZSmartNote(id: 'n1', subFolderId: 's');
      expect(n.copyWith(subFolderId: null).subFolderId, isNull);
      expect(n.copyWith(id: null).id, isNull);
      expect(n.copyWith().subFolderId, 's');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // AC8 — conformité au patron ES-2.0, OBSERVÉE par le REGISTRE.
  // ═══════════════════════════════════════════════════════════════════════════
  group('AC8 — round-trip par le REGISTRE (voie du store)', () {
    late ZcrudRegistry registry;

    setUp(() {
      // Le garde runtime `_$zRequireExtraPreserved` s'exécute ICI : si `fromMap`
      // ne peuplait pas `extra`, ou si `toMap()` ne le réémettait pas, cet appel
      // LÈVERAIT (y compris en release — il n'est PAS sous `assert`).
      registry = ZcrudRegistry();
      registerZSmartNote(registry);
    });

    test('l\'enregistrement PASSE (garde runtime DW-ES14-1 observé)', () {
      expect(registry.kinds, contains('smart_note'));
    });

    test('(e) la clé inconnue ET le `content` survivent au round-trip registre',
        () {
      final sonde = <String, dynamic>{
        'id': 'p',
        'folder_id': 'f',
        'title': 't',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'sonde\n'},
        ],
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      };
      final entity = registry.decode('smart_note', sonde);
      final encoded = registry.encode('smart_note', entity);

      expect(encoded['zz_cle_inconnue'], 'gardee');
      expect(
        (encoded['content'] as List).single,
        <String, dynamic>{'insert': 'sonde\n'},
      );
      expect(encoded.containsKey('updated_at'), isFalse);
      expect(encoded.containsKey('is_deleted'), isFalse);
      expect((entity as ZExtensible).extra.containsKey('content'), isFalse);
    });

    test('round-trip COMPLET : fromMap(toMap(x)) == x', () {
      final n = ZSmartNote.fromMap(<String, dynamic>{
        'id': 'n1',
        'folder_id': 'f',
        'sub_folder_id': 's',
        'title': 't',
        'content': <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'a', 'attributes': <String, dynamic>{'bold': true}},
          <String, dynamic>{
            'insert': <String, dynamic>{'formula': 'x^2'},
          },
          <String, dynamic>{'insert': '\n'},
        ],
        'created_at': '2026-07-13T10:00:00.000Z',
        'zz_cle_inconnue': 'gardee',
      });
      expect(ZSmartNote.fromMap(n.toMap()), n);
      expect(ZSmartNote.fromMap(n.toMap()).hashCode, n.hashCode);
    });
  });
}
