// MIN-2 — gaps MINEURS de parité DODLP (config pur-données + helpers purs) :
// slider défauts 0..100, FileFieldConfig par catégorie + fallback image,
// ZTimeCodec Map↔'HH:mm', ZSelectConfig.radioAsModal, cohérence des clés `layout`,
// espacement type-dépendant, store de repli mémoire.
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('MIN-2 · slider défauts 0..100 (paramétrable)', () {
    test('ZSliderConfig sans bornes ⇒ 0..100 (aligné DODLP)', () {
      const cfg = ZSliderConfig();
      expect(cfg.min, 0);
      expect(cfg.max, 100);
      expect(cfg.divisions, isNull);
    });

    test('bornes explicites toujours respectées (rétro-compat authored)', () {
      const cfg = ZSliderConfig(min: 0, max: 1);
      expect(cfg.max, 1);
      const strict = ZSliderConfig(min: -5, max: 5, divisions: 10);
      expect(strict.min, -5);
      expect(strict.max, 5);
      expect(strict.divisions, 10);
    });
  });

  group('MIN-2 · FileFieldConfig catégories + fallback image', () {
    test('effectiveExtensions == acceptedExtensions sans catégories (rétro-compat)',
        () {
      const cfg = FileFieldConfig(acceptedExtensions: <String>['pdf', 'png']);
      expect(cfg.effectiveExtensions, <String>['pdf', 'png']);
      expect(cfg.allowedDocumentTypes, isEmpty);
      expect(cfg.imageFallback, isFalse);
    });

    test('effectiveExtensions = union plate ∪ catégories (dédupliquée, ordre stable)',
        () {
      const cfg = FileFieldConfig(
        acceptedExtensions: <String>['pdf'],
        allowedDocumentTypes: <String, List<String>>{
          'images': <String>['png', 'jpg'],
          'docs': <String>['pdf', 'docx'], // 'pdf' dédupliqué
        },
      );
      expect(cfg.effectiveExtensions, <String>['pdf', 'png', 'jpg', 'docx']);
    });

    test('== / hashCode incluent catégories + imageFallback', () {
      const a = FileFieldConfig(
        imageFallback: true,
        allowedDocumentTypes: <String, List<String>>{
          'x': <String>['a', 'b'],
        },
      );
      const b = FileFieldConfig(
        imageFallback: true,
        allowedDocumentTypes: <String, List<String>>{
          'x': <String>['a', 'b'],
        },
      );
      const c = FileFieldConfig(
        allowedDocumentTypes: <String, List<String>>{
          'x': <String>['a', 'b'],
        },
      ); // imageFallback différent
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('MIN-2 · ZTimeCodec Map{hour,minute} ↔ HH:mm', () {
    test('mapToHhmm zéro-padde et valide les bornes', () {
      expect(ZTimeCodec.mapToHhmm(<String, int>{'hour': 9, 'minute': 5}), '09:05');
      expect(ZTimeCodec.mapToHhmm(<String, int>{'hour': 23, 'minute': 59}), '23:59');
    });

    test('mapToHhmm défensif : null / hors-bornes / mal typé ⇒ null (AD-10)', () {
      expect(ZTimeCodec.mapToHhmm(null), isNull);
      expect(ZTimeCodec.mapToHhmm(<String, int>{'hour': 24, 'minute': 0}), isNull);
      expect(ZTimeCodec.mapToHhmm(<String, int>{'hour': 1}), isNull);
      // Valeurs String numériques tolérées (désérialisation défensive).
      expect(ZTimeCodec.mapToHhmm(<String, dynamic>{'hour': '7', 'minute': '3'}),
          '07:03');
    });

    test('hhmmToMap parse et ignore les secondes', () {
      expect(ZTimeCodec.hhmmToMap('08:30'),
          <String, int>{'hour': 8, 'minute': 30});
      expect(ZTimeCodec.hhmmToMap('08:30:59'),
          <String, int>{'hour': 8, 'minute': 30});
      expect(ZTimeCodec.hhmmToMap('bad'), isNull);
      expect(ZTimeCodec.hhmmToMap(null), isNull);
      expect(ZTimeCodec.hhmmToMap('25:00'), isNull);
    });

    test('round-trip Map → HH:mm → Map', () {
      const map = <String, int>{'hour': 14, 'minute': 7};
      final hhmm = ZTimeCodec.mapToHhmm(map);
      expect(ZTimeCodec.hhmmToMap(hhmm), map);
    });

    test('hhmmToMinutesOfDay', () {
      expect(ZTimeCodec.hhmmToMinutesOfDay('01:30'), 90);
      expect(ZTimeCodec.hhmmToMinutesOfDay('nope'), isNull);
    });
  });

  group('MIN-2 · ZSelectConfig.radioAsModal', () {
    test('défaut false ; == / hashCode le prennent en compte', () {
      const off = ZSelectConfig();
      expect(off.radioAsModal, isFalse);
      const a = ZSelectConfig(radioAsModal: true);
      const b = ZSelectConfig(radioAsModal: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(off));
    });
  });
}
