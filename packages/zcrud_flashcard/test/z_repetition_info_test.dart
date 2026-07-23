/// Tests de `ZRepetitionInfo` (Story E9-2) : round-trip zéro-perte SANS
/// recalcul (AC8), désérialisation défensive de bout en bout (AC9), slots
/// d'extension AD-4 (AC2), état SRS séparé de la carte (AC1).
///
/// Gate E2-10 (rétro-compat sérialisation) : couverture sur maps **corrompues**,
/// pas seulement happy-path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  const scheduler = ZSm2Scheduler();

  group('Round-trip zéro-perte, jamais recalculé (AC8)', () {
    test('fromMap(toMap(x)) == x sur un état non trivial', () {
      final source = ZRepetitionInfo(
        flashcardId: 'card-42',
        folderId: 'folder-7',
        interval: 41,
        repetitions: 7,
        easeFactor: 1.87,
        nextReviewDate: DateTime.utc(2026, 3, 15, 10, 30),
        learnedAt: DateTime.utc(2026, 1, 2, 8),
        lastQuality: 4,
      );
      final round = ZRepetitionInfo.fromMap(source.toMap());
      expect(round, source);
    });

    test('fromMap NE recalcule PAS : valeurs « impossibles » conservées', () {
      // easeFactor=9.9 (hors clamp [1.3;2.5]) et interval=999 : un apply les
      // aurait normalisés. fromMap reconstruit l'état TEL QUEL (aucun scheduler).
      final map = <String, dynamic>{
        'flashcard_id': 'c',
        'folder_id': 'f',
        'interval': 999,
        'repetitions': 50,
        'ease_factor': 9.9,
        'last_quality': 5,
      };
      final info = ZRepetitionInfo.fromMap(map);
      expect(info.easeFactor, 9.9); // NON clampé à 2.5.
      expect(info.interval, 999);
      expect(info.repetitions, 50);
    });

    test('snake_case persistant (AC1)', () {
      final info = scheduler
          .apply(scheduler.initial(flashcardId: 'c', folderId: 'f'), 5,
              now: DateTime.utc(2026, 1, 1));
      final map = info.toMap();
      expect(map.keys, containsAll(<String>[
        'flashcard_id',
        'folder_id',
        'interval',
        'repetitions',
        'ease_factor',
        'next_review_date',
        'learned_at',
        'last_quality',
      ]));
    });
  });

  group('Désérialisation défensive (AC9, gate E2-10)', () {
    test('map vide → défauts sûrs, aucun throw', () {
      final info = ZRepetitionInfo.fromMap(const <String, dynamic>{});
      expect(info.flashcardId, '');
      expect(info.folderId, '');
      expect(info.interval, 0);
      expect(info.repetitions, 0);
      expect(info.easeFactor, ZSrsConfig.kDefaultEaseFactor);
      expect(info.nextReviewDate, isNull);
      expect(info.learnedAt, isNull);
      expect(info.lastQuality, isNull);
    });

    test('ease_factor non-numérique → defaultEaseFactor', () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{
        'flashcard_id': 'c',
        'ease_factor': 'pas-un-nombre',
      });
      expect(info.easeFactor, ZSrsConfig.kDefaultEaseFactor);
    });

    test('interval négatif → 0 (sanitisé) ; interval non-int → 0', () {
      final neg = ZRepetitionInfo.fromMap(<String, dynamic>{'interval': -5});
      expect(neg.interval, 0);
      final bad = ZRepetitionInfo.fromMap(<String, dynamic>{'interval': 'xx'});
      expect(bad.interval, 0);
    });

    test('repetitions négatif → 0 (sanitisé)', () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{'repetitions': -3});
      expect(info.repetitions, 0);
    });

    test('dates illisibles → null', () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{
        'next_review_date': 'not-a-date',
        'learned_at': 12345, // ni String ISO ni DateTime.
      });
      expect(info.nextReviewDate, isNull);
      expect(info.learnedAt, isNull);
    });

    test('last_quality hors 0..5 → conservé tel quel (clamp au seul apply)', () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{'last_quality': 99});
      expect(info.lastQuality, 99); // choix documenté : pas de perte à la sync.
    });

    test('map réellement corrompue (types mixtes) ne throw jamais', () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{
        'flashcard_id': 123, // pas une String.
        'folder_id': true,
        'interval': <int>[1, 2],
        'ease_factor': <String, int>{'x': 1},
        'extension': 'corrompue',
      });
      expect(info.flashcardId, ''); // repli sûr.
      expect(info.folderId, '');
      expect(info.interval, 0);
      expect(info.easeFactor, ZSrsConfig.kDefaultEaseFactor);
    });
  });

  group('Slots d\'extension AD-4 (AC2)', () {
    test('extra : clés inconnues préservées au round-trip', () {
      final map = <String, dynamic>{
        'flashcard_id': 'c',
        'folder_id': 'f',
        'interval': 3,
        'un_champ_futur': 'valeur',
        'autre': 42,
      };
      final info = ZRepetitionInfo.fromMap(map);
      expect(info.extra['un_champ_futur'], 'valeur');
      expect(info.extra['autre'], 42);
      // Round-trip : les clés inconnues repassent dans la map.
      final back = info.toMap();
      expect(back['un_champ_futur'], 'valeur');
      expect(back['autre'], 42);
    });

    test('extra est non-modifiable et jamais null', () {
      final info = ZRepetitionInfo.fromMap(const <String, dynamic>{});
      expect(info.extra, isEmpty);
      expect(() => info.extra['x'] = 1, throwsUnsupportedError);
    });

    test('extension de formatVersion non gérée → null, parent survit', () {
      final info = ZRepetitionInfo.fromMap(
        <String, dynamic>{
          'flashcard_id': 'c',
          'extension': <String, dynamic>{'format_version': 999, 'v': 'x'},
        },
        extensionParser: _TestExt.fromJsonSafe,
      );
      // ⚠️ CHANGEMENT DE CONTRAT (CR-LEX-33) : ce test assertait `isNull`.
      // Ne pas savoir TYPER un payload n'autorise pas à l'EFFACER — `extension`
      // étant une clé CONNUE (exclue d'`extra`), le `null` valait DESTRUCTION
      // silencieuse du slot d'un autre hôte. Il est désormais porté verbatim.
      expect(info.extension, isA<ZOpaqueExtension>()); // version non gérée → null.
      expect(info.flashcardId, 'c'); // parent intact.
    });

    test('extension valide parsée puis round-trip', () {
      final source = ZRepetitionInfo.fromMap(
        <String, dynamic>{
          'flashcard_id': 'c',
          'folder_id': 'f',
          'extension': <String, dynamic>{'format_version': 1, 'value': 'hello'},
        },
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(source.extension, isA<_TestExt>());
      expect((source.extension! as _TestExt).value, 'hello');
      // toMap réémet l'extension ; refromMap la reconstruit à l'identique.
      final round = ZRepetitionInfo.fromMap(
        source.toMap(),
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(round, source);
    });

    test('extension corrompue (non-map) → null via guard, parent survit', () {
      final info = ZRepetitionInfo.fromMap(
        <String, dynamic>{'flashcard_id': 'c', 'extension': 'corrompue'},
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(info.extension, isNull);
      expect(info.flashcardId, 'c');
    });
  });

  group('État SRS séparé de la carte (AC1)', () {
    test('ZRepetitionInfo n\'est pas une ZFlashcard (entité distincte)', () {
      final info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      expect(info, isA<ZExtensible>());
      expect(info, isNot(isA<ZFlashcard>()));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // AD-19 (ES-1.3, finding H1 du code-review) — NON-RÉGRESSION.
  //
  // ⚠️ SI CE GROUPE TOMBE : `_reservedKeys` a perdu `...ZSyncMeta.reservedKeys`.
  // `ZRepetitionInfo` est l'EXEMPLAIRE DE RÉFÉRENCE d'AD-19.1 (zéro `updatedAt`
  // interne) ET un document persisté top-level (`study_repetitions/{cardId}`)
  // dont le store écrit la méta DANS LE CORPS avant de passer la map COMPLÈTE à
  // `fromMap`. Ne déclarant AUCUN champ `updatedAt`/`isDeleted`, elle capturerait
  // les DEUX clés réservées dans `extra` (AD-4) et les RÉÉMETTRAIT via `toMap()`
  // (AD-16), cassant `==` entre un état SRS en mémoire et le même relu du store.
  // ───────────────────────────────────────────────────────────────────────────
  group('ZRepetitionInfo — AD-19 : clés de sync hors-entité (ES-1.3)', () {
    test('fromMap d\'une map de STORE : ni is_deleted ni updated_at dans extra',
        () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{
        'flashcard_id': 'c1',
        'folder_id': 'f1',
        'interval': 3,
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
        'un_champ_inconnu': 'gardé',
      });

      expect(info.extra.containsKey('is_deleted'), isFalse);
      expect(info.extra.containsKey('updated_at'), isFalse);
      // Round-trip AD-4 des clés VRAIMENT inconnues : non régressé.
      expect(info.extra['un_champ_inconnu'], 'gardé');
      expect(info.interval, 3);
    });

    test('toMap() ne RÉÉMET aucune clé de sync (AD-16, soft-delete hors-entité)',
        () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{
        'flashcard_id': 'c1',
        'folder_id': 'f1',
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': true,
      });

      final map = info.toMap();
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('isDeleted'), isFalse);
    });

    test('convergence : fromMap(toMap(i)) == i (l\'== n\'est plus cassée entre '
        'un état SRS en mémoire et le même relu du store)', () {
      final fromStore = ZRepetitionInfo.fromMap(<String, dynamic>{
        'flashcard_id': 'c1',
        'folder_id': 'f1',
        'interval': 6,
        'repetitions': 2,
        'ease_factor': 2.36,
        'updated_at': DateTime.utc(2026, 5, 5).toIso8601String(),
        'is_deleted': false,
      });
      final reread = ZRepetitionInfo.fromMap(fromStore.toMap());

      expect(reread.extra, equals(fromStore.extra));
      expect(reread, equals(fromStore));
      expect(fromStore.extra, isEmpty);

      // L'état SRS construit en mémoire par l'algorithme est ÉGAL au même état
      // relu du store (c'était FAUX avant la correction : `extra` divergeait).
      final inMemory = ZRepetitionInfo(
        flashcardId: 'c1',
        folderId: 'f1',
        interval: 6,
        repetitions: 2,
        easeFactor: 2.36,
      );
      expect(fromStore, equals(inMemory));
    });

    test('map de sync corrompue (is_deleted: "oui", updated_at: 42) ⇒ aucun '
        'throw, aucune pollution (AD-10)', () {
      final info = ZRepetitionInfo.fromMap(<String, dynamic>{
        'flashcard_id': 'c1',
        'folder_id': 'f1',
        'updated_at': 42,
        'is_deleted': 'oui',
      });

      expect(info.flashcardId, 'c1');
      expect(info.extra, isEmpty);
      expect(info.toMap().containsKey('is_deleted'), isFalse);
    });

    test('AD-19.1 — exemplaire de référence : AUCUN champ updatedAt/isDeleted '
        'déclaré (la clé LWW est EXCLUSIVEMENT hors-entité)', () {
      final specNames =
          $ZRepetitionInfoFieldSpecs.map((s) => s.name).toSet();
      expect(
        specNames.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
        reason: 'ZRepetitionInfo ne doit déclarer NI updated_at NI is_deleted : '
            'ces clés appartiennent au store (ZSyncMeta), pas au domaine.',
      );
    });
  });
}

/// Extension de TEST (`ZExtension`) — vérifie le slot type additif versionné
/// (AD-4/AC2) : ne gère que `formatVersion == 1`.
class _TestExt extends ZExtension {
  const _TestExt(this.value);

  static const int _version = 1;

  final String value;

  /// Convention `fromJsonSafe` : `null` si version non gérée ou corrompu.
  static ZExtension? fromJsonSafe(Map<String, dynamic> json) =>
      ZExtension.guard<ZExtension?>(() {
        if (json['format_version'] != _version) return null;
        final v = json['value'];
        return _TestExt(v is String ? v : '');
      });

  @override
  int get formatVersion => _version;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'format_version': _version,
        'value': value,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TestExt && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
