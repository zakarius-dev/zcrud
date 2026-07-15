/// Tests de `ZFlashcardTag` (`ZExtensible`, patron ES-2.2b) et `ZSuggestedTag`
/// (value object NON-`ZExtensible`) — ES-2.3, FR-S6, AC1/AC2/AC4/AC6/AC7/AC8/AC11.
///
/// ⚠️ **Aucun `dart:io`** (AC14) : le kernel est pur-Dart, ses tests tournent
/// sous `dart test` (y compris JS). Le garde de pureté SM-S5 lit les sources via
/// `dart:io` mais vit dans `z_kernel_purity_test.dart` (`@TestOn('vm')`).
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Extension type de test (AD-4 pt.1) — round-trip d'un slot `extension` typé.
class _TestExt extends ZExtension {
  const _TestExt(this.note);

  final String note;

  @override
  int get formatVersion => 1;

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': formatVersion, 'note': note};

  static ZExtension? fromJsonSafe(Map<String, dynamic> json) {
    if (json['format_version'] != 1) return null;
    return ZExtension.guard<ZExtension?>(() => _TestExt(json['note'] as String));
  }

  @override
  bool operator ==(Object other) =>
      other is _TestExt && note == other.note && formatVersion == 1;

  @override
  int get hashCode => Object.hash(note, formatVersion);
}

void main() {
  group('ZFlashcardTag — modèle & round-trip (AC1)', () {
    test('valeurs par défaut : id null, title/colorKey vides, extra vide', () {
      const tag = ZFlashcardTag();
      expect(tag.id, isNull);
      expect(tag.title, '');
      expect(tag.colorKey, '');
      expect(tag.extension, isNull);
      expect(tag.extra, isEmpty);
      expect(tag.isEphemeral, isTrue); // id == null (ZEntity, AD-14)
    });

    test('round-trip PLEIN : fromMap(toMap(x)) == x', () {
      const tag = ZFlashcardTag(id: 'a', title: 'Droit', colorKey: 'blue');
      final rt = ZFlashcardTag.fromMap(tag.toMap());
      expect(rt, equals(tag));
      expect(rt.hashCode, equals(tag.hashCode));
    });

    test('round-trip MINIMAL : map vide', () {
      final tag = ZFlashcardTag.fromMap(const <String, dynamic>{});
      expect(tag.id, isNull);
      expect(tag.title, '');
      expect(tag.colorKey, '');
      expect(ZFlashcardTag.fromMap(tag.toMap()), equals(tag));
    });

    test('idempotence : fromMap(toMap(fromMap(m))) stable', () {
      final m = <String, dynamic>{
        'id': 'x',
        'title': 't',
        'color_key': 'red',
        'zz_libre': 'gardé',
      };
      final a = ZFlashcardTag.fromMap(m);
      final b = ZFlashcardTag.fromMap(a.toMap());
      expect(b, equals(a));
    });

    test('clés persistées snake_case (id/title/color_key)', () {
      const tag = ZFlashcardTag(id: 'a', title: 't', colorKey: 'blue');
      final map = tag.toMap();
      expect(map['id'], 'a');
      expect(map['title'], 't');
      expect(map['color_key'], 'blue');
    });

    test('slot extension typé round-trippé', () {
      const tag = ZFlashcardTag(title: 't', extension: _TestExt('hello'));
      final map = tag.toMap();
      expect((map['extension'] as Map)['note'], 'hello');
      final rt = ZFlashcardTag.fromMap(
        map,
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(rt.extension, const _TestExt('hello'));
    });
  });

  group('ZFlashcardTag — désérialisation défensive (AC11, AD-10)', () {
    test('title/color_key non-String ⇒ défaut vide, jamais de throw', () {
      final tag = ZFlashcardTag.fromMap(<String, dynamic>{
        'title': 42,
        'color_key': <String>['x'],
      });
      expect(tag.title, '');
      expect(tag.colorKey, '');
    });

    test('extension corrompue ⇒ null (parent survit)', () {
      final tag = ZFlashcardTag.fromMap(
        <String, dynamic>{'title': 't', 'extension': 'pas-une-map'},
        extensionParser: _TestExt.fromJsonSafe,
      );
      expect(tag.extension, isNull);
      expect(tag.title, 't');
    });

    test('fromMap(const {}) ne throw pas', () {
      expect(() => ZFlashcardTag.fromMap(const <String, dynamic>{}),
          returnsNormally);
    });
  });

  group('ZFlashcardTag — colorKey BRUT, aucun clamp entité (AC4, D4)', () {
    // 🔴 Précédent EXACT : `ZStudyFolder.colorKey` (@ZcrudField String libre,
    // « résolue côté UI »). `colorKey` n'a AUCUN invariant de VALEUR au niveau
    // entité — il est stocké VERBATIM. Le bornage se fait À L'AFFICHAGE via
    // `remapColorKey(palette, rawColorKey: tag.colorKey, seedTitle: tag.title)`
    // chez le consommateur (ES-8.1), JAMAIS ici (la borne est palette-dépendante,
    // la palette est injectée). Ce n'est PAS un oubli (contraste `ZSmartNote`).
    test('constructeur : colorKey inconnue conservée telle quelle', () {
      const tag = ZFlashcardTag(colorKey: 'zzz_inconnue');
      expect(tag.colorKey, 'zzz_inconnue');
    });

    test('fromMap : color_key conservée VERBATIM', () {
      final tag = ZFlashcardTag.fromMap(<String, dynamic>{'color_key': 'zzz'});
      expect(tag.colorKey, 'zzz');
    });

    test('copyWith : colorKey conservée VERBATIM', () {
      const tag = ZFlashcardTag(colorKey: 'blue');
      expect(tag.copyWith(colorKey: 'zzz').colorKey, 'zzz');
    });

    test('DOC — le bornage AFFICHABLE se fait via remapColorKey chez le conso',
        () {
      // Démontre que la borne est portée par `remapColorKey` + palette injectée,
      // et NON par l'entité : la valeur stockée reste brute, la valeur AFFICHÉE
      // est ∈ palette.keys.
      const tag = ZFlashcardTag(title: 'Droit', colorKey: 'zzz_inconnue');
      final palette = const ZColorPalette.defaultStudy();
      final display = remapColorKey(
        palette: palette,
        rawColorKey: tag.colorKey,
        seedTitle: tag.title,
      );
      expect(tag.colorKey, 'zzz_inconnue'); // stockée brute
      expect(palette.keys, contains(display)); // affichée ∈ keys
    });
  });

  group('ZFlashcardTag — extra & AD-19 (AC6/AC7/AC8)', () {
    test('clé inconnue round-trippée (anti-vacuité)', () {
      final tag = ZFlashcardTag.fromMap(<String, dynamic>{
        'title': 't',
        'zz_cle_inconnue': 'gardee',
      });
      expect(tag.extra['zz_cle_inconnue'], 'gardee');
      expect(tag.toMap()['zz_cle_inconnue'], 'gardee');
    });

    test('sonde de STORE : is_deleted/updated_at hors extra + non réémis', () {
      final tag = ZFlashcardTag.fromMap(<String, dynamic>{
        'id': 'p',
        'title': 't',
        'color_key': 'blue',
        'updated_at': '2026-01-01T00:00:00.000Z',
        'is_deleted': true,
        'zz_cle_inconnue': 'gardee',
      });
      expect(
        tag.extra.keys.toSet().intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
      expect(tag.extra['zz_cle_inconnue'], 'gardee'); // anti-vacuité
      final map = tag.toMap();
      expect(map.containsKey('updated_at'), isFalse);
      expect(map.containsKey('is_deleted'), isFalse);
      expect(map['zz_cle_inconnue'], 'gardee');
    });

    test('map de sync corrompue ⇒ aucun throw, aucune pollution', () {
      final tag = ZFlashcardTag.fromMap(<String, dynamic>{
        'title': 't',
        'updated_at': 42,
        'is_deleted': 'oui',
      });
      expect(tag.extra, isEmpty);
      expect(tag.toMap().containsKey('is_deleted'), isFalse);
    });

    test('pollution ctor NEUTRALISÉE (accesseur normalisant, HIGH-2)', () {
      // Le constructeur `const` ne filtre RIEN — c'est l'accesseur qui garde.
      const tag = ZFlashcardTag(
        title: 't',
        extra: <String, dynamic>{'is_deleted': true, 'ok': 1},
      );
      expect(tag.extra.containsKey('is_deleted'), isFalse);
      expect(tag.extra['ok'], 1);
      // Convergence : une entité polluée en mémoire == la même relue du store.
      expect(ZFlashcardTag.fromMap(tag.toMap()), equals(tag));
    });

    test('copyWith(extra:) ne rouvre PAS le filtre (garde partagée H2)', () {
      const tag = ZFlashcardTag(title: 't');
      final copied =
          tag.copyWith(extra: <String, dynamic>{'is_deleted': true, 'k': 'v'});
      expect(copied.extra.containsKey('is_deleted'), isFalse);
      expect(copied.extra['k'], 'v');
    });

    test('extra porte du JSON imbriqué : égalité PROFONDE (DW-ES22-4)', () {
      const a = ZFlashcardTag(
        title: 't',
        extra: <String, dynamic>{
          'meta': <String, dynamic>{'a': 1, 'b': <int>[1, 2]},
        },
      );
      const b = ZFlashcardTag(
        title: 't',
        extra: <String, dynamic>{
          'meta': <String, dynamic>{'a': 1, 'b': <int>[1, 2]},
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('ZFlashcardTag — AD-19 : \$FieldSpecs ∩ ZSyncMeta.reservedKeys == {} '
      '(R-C, AC6)', () {
    test('aucun champ de schéma ne collisionne avec une clé de sync', () {
      final specNames =
          $ZFlashcardTagFieldSpecs.map((s) => s.name).toSet();
      expect(specNames.intersection(ZSyncMeta.reservedKeys), isEmpty);
    });

    test('aucun champ persistAs:timestamp réservé (AD-19.1.b)', () {
      // Le kernel ne connaît pas `Timestamp` : la liste des timestamp fields
      // générée ne doit contenir aucune clé réservée.
      expect(
        $ZFlashcardTagTimestampFields.intersection(ZSyncMeta.reservedKeys),
        isEmpty,
      );
    });

    test('aucun champ nommé updated_at/is_deleted', () {
      final specNames =
          $ZFlashcardTagFieldSpecs.map((s) => s.name).toSet();
      expect(specNames, isNot(contains('updated_at')));
      expect(specNames, isNot(contains('is_deleted')));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  group('ZSuggestedTag — value object NON-ZExtensible (AC2/AC11)', () {
    test('valeurs par défaut vides', () {
      const t = ZSuggestedTag();
      expect(t.title, '');
      expect(t.colorKey, '');
    });

    test('round-trip défensif : fromMap/toMap', () {
      const t = ZSuggestedTag(title: 'IA', colorKey: 'teal');
      final rt = ZSuggestedTag.fromMap(t.toMap());
      expect(rt, equals(t));
      expect(t.toMap()['color_key'], 'teal');
    });

    test('title/color_key absents ⇒ vides ; fromMap(const {}) ne throw pas', () {
      expect(() => ZSuggestedTag.fromMap(const <String, dynamic>{}),
          returnsNormally);
      final t = ZSuggestedTag.fromMap(const <String, dynamic>{});
      expect(t.title, '');
      expect(t.colorKey, '');
    });

    test('title non-String ⇒ défaut vide (défensif)', () {
      final t = ZSuggestedTag.fromMap(<String, dynamic>{'title': 99});
      expect(t.title, '');
    });

    test('colorKey BRUT conservée VERBATIM (D4)', () {
      const t = ZSuggestedTag(colorKey: 'zzz_inconnue');
      expect(t.colorKey, 'zzz_inconnue');
      expect(ZSuggestedTag.fromMap(<String, dynamic>{'color_key': 'zzz'}).colorKey,
          'zzz');
    });

    test('== / hashCode scalaires (patron ZChoice)', () {
      expect(const ZSuggestedTag(title: 'a', colorKey: 'b'),
          equals(const ZSuggestedTag(title: 'a', colorKey: 'b')));
      expect(const ZSuggestedTag(title: 'a'),
          isNot(equals(const ZSuggestedTag(title: 'b'))));
    });

    test('\$FieldSpecs ∩ ZSyncMeta.reservedKeys == {} (R-C)', () {
      final specNames = $ZSuggestedTagFieldSpecs.map((s) => s.name).toSet();
      expect(specNames.intersection(ZSyncMeta.reservedKeys), isEmpty);
    });
  });
}
