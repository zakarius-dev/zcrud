// DP-15 (AC1, AC6, AC10) — tests DOMAINE PURS des types-valeur `const` enrichis :
// `ZFieldChoice` (subtitle/disabled additifs, rétro-compat), `ZSelectConfig`
// (nouveau, égalité profonde `filterKeys`), `ZRelationConfig.crudKey` (additif).
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('ZFieldChoice (AC1) — subtitle/disabled additifs', () {
    test('défauts rétro-compat : subtitle null, disabled false', () {
      const c = ZFieldChoice(value: 'a', label: 'Alpha');
      expect(c.subtitle, isNull);
      expect(c.disabled, isFalse);
    });

    test('const + égalité avec subtitle/disabled', () {
      const a = ZFieldChoice(
          value: 'a', label: 'Alpha', subtitle: 'sub', disabled: true);
      const b = ZFieldChoice(
          value: 'a', label: 'Alpha', subtitle: 'sub', disabled: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('subtitle/disabled discriminants de l\'égalité', () {
      const base = ZFieldChoice(value: 'a', label: 'Alpha');
      expect(base,
          isNot(equals(const ZFieldChoice(value: 'a', label: 'Alpha', subtitle: 's'))));
      expect(
          base,
          isNot(equals(const ZFieldChoice(
              value: 'a', label: 'Alpha', disabled: true))));
    });

    test('rétro-compat : {value,label} inchangé égal à défauts explicites', () {
      const legacy = ZFieldChoice(value: 1, label: 'Un');
      const explicit =
          ZFieldChoice(value: 1, label: 'Un', subtitle: null, disabled: false);
      expect(legacy, equals(explicit));
      expect(legacy.hashCode, equals(explicit.hashCode));
    });
  });

  group('ZSelectConfig (AC6)', () {
    test('const + valeurs par défaut', () {
      const cfg = ZSelectConfig();
      expect(cfg.searchable, isFalse);
      expect(cfg.modalThreshold, isNull);
      expect(cfg.choicesFromKey, isNull);
      expect(cfg.choicesSourceKey, isNull);
      expect(cfg.filterKeys, isEmpty);
      expect(cfg, isA<ZFieldConfig>());
    });

    test('égalité de valeur (dont filterKeys profond) + hashCode', () {
      const a = ZSelectConfig(
        searchable: true,
        modalThreshold: 8,
        choicesFromKey: 'cats',
        choicesSourceKey: 'src',
        filterKeys: <String>['p', 'q'],
      );
      const b = ZSelectConfig(
        searchable: true,
        modalThreshold: 8,
        choicesFromKey: 'cats',
        choicesSourceKey: 'src',
        filterKeys: <String>['p', 'q'],
      );
      const diff = ZSelectConfig(
        searchable: true,
        modalThreshold: 8,
        choicesFromKey: 'cats',
        choicesSourceKey: 'src',
        filterKeys: <String>['p'],
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(diff)));
    });

    test('discriminants scalaires', () {
      const base = ZSelectConfig(choicesFromKey: 'cats');
      expect(base, isNot(equals(const ZSelectConfig(choicesFromKey: 'dogs'))));
      expect(base, isNot(equals(const ZSelectConfig())));
      expect(const ZSelectConfig(modalThreshold: 5),
          isNot(equals(const ZSelectConfig(modalThreshold: 6))));
    });
  });

  group('ZRelationConfig.crudKey (AC10) — additif', () {
    test('défaut null (rétro-compat DP-5)', () {
      const cfg = ZRelationConfig(sourceKey: 's');
      expect(cfg.crudKey, isNull);
    });

    test('crudKey discriminant de l\'égalité + hashCode', () {
      const a = ZRelationConfig(sourceKey: 's', crudKey: 'c');
      const b = ZRelationConfig(sourceKey: 's', crudKey: 'c');
      const noCrud = ZRelationConfig(sourceKey: 's');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(noCrud)));
    });
  });
}
