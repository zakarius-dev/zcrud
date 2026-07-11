// DP-9 (AC1, AC2, AC3, AC7) — `ZStepperConfig` + enums + presets ; `ZEditionStep`
// enrichi (icon/subtitle) : construction `const`, égalité/hashCode/copyWith,
// additivité (les descripteurs restent constructibles à l'identique).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZStepperConfig (AC2/AC3)', () {
    test('défauts = comportement E3-5 (top/horizontal/numbered, gate strict)', () {
      const c = ZStepperConfig();
      expect(c.orientation, ZStepOrientation.horizontal);
      expect(c.style, ZStepStyle.numbered);
      expect(c.indicatorPosition, ZStepIndicatorPosition.top);
      expect(c.showLabels, isTrue);
      expect(c.showSubtitles, isFalse);
      expect(c.allowStepTap, isTrue);
      expect(c.validateOnNext, isTrue, reason: 'gate strict par défaut (M12)');
      // Aucun override couleur figé (dérivation ColorScheme — AC6/AC17).
      expect(c.activeColor, isNull);
      expect(c.completedColor, isNull);
      expect(c.inactiveColor, isNull);
      expect(c.errorColor, isNull);
    });

    test('presets de parité DODLP (aucune couleur figée)', () {
      expect(ZStepperConfig.defaultHorizontal, const ZStepperConfig());

      const v = ZStepperConfig.defaultVertical;
      expect(v.orientation, ZStepOrientation.vertical);
      expect(v.indicatorPosition, ZStepIndicatorPosition.start,
          reason: 'left DODLP → start directionnel (AD-13)');

      const d = ZStepperConfig.dotStyle;
      expect(d.style, ZStepStyle.dots);
      expect(d.indicatorPosition, ZStepIndicatorPosition.bottom);
      expect(d.showLabels, isFalse);

      const p = ZStepperConfig.progressBarStyle;
      expect(p.style, ZStepStyle.progressBar);
      expect(p.showLabels, isFalse);

      for (final preset in <ZStepperConfig>[v, d, p]) {
        expect(preset.activeColor, isNull);
        expect(preset.completedColor, isNull);
        expect(preset.inactiveColor, isNull);
        expect(preset.errorColor, isNull);
      }
    });

    test('== / hashCode / copyWith', () {
      const a = ZStepperConfig();
      final b = a.copyWith(style: ZStepStyle.dots, validateOnNext: false);
      expect(b.style, ZStepStyle.dots);
      expect(b.validateOnNext, isFalse);
      expect(b.orientation, a.orientation, reason: 'reste inchangé');
      expect(b == a, isFalse);
      expect(a == const ZStepperConfig(), isTrue);
      expect(a.hashCode, const ZStepperConfig().hashCode);

      const withColor = ZStepperConfig(activeColor: Color(0xFF112233));
      expect(withColor == a, isFalse);
      expect(withColor.copyWith().activeColor, const Color(0xFF112233));
    });

    test('couleurs effectives : override sinon ColorScheme', () {
      const scheme = ColorScheme.light();
      const c = ZStepperConfig();
      expect(c.activeOf(scheme), scheme.primary);
      expect(c.completedOf(scheme), scheme.primary);
      expect(c.inactiveOf(scheme), scheme.onSurfaceVariant);
      expect(c.errorOf(scheme), scheme.error);

      const over = ZStepperConfig(
        activeColor: Color(0xFF010203),
        errorColor: Color(0xFF040506),
      );
      expect(over.activeOf(scheme), const Color(0xFF010203));
      expect(over.errorOf(scheme), const Color(0xFF040506));
      expect(over.inactiveOf(scheme), scheme.onSurfaceVariant,
          reason: 'non surchargé ⇒ dérivé');
    });
  });

  group('ZEditionStep enrichi (AC7)', () {
    test('const + défauts null (rétro-compat : sites existants inchangés)', () {
      const s = ZEditionStep(title: 't', fields: <String>['a', 'b']);
      expect(s.icon, isNull);
      expect(s.subtitle, isNull);
      expect(s.nestedSteps, isNull);
      expect(s.nestedConfig, isNull);
    });

    test('icon/subtitle additifs, ctor const', () {
      const s = ZEditionStep(
        title: 't',
        fields: <String>['a'],
        icon: Icons.person,
        subtitle: 'sous-titre',
      );
      expect(s.icon, Icons.person);
      expect(s.subtitle, 'sous-titre');
    });

    test('== / hashCode reflètent icon/subtitle/nested', () {
      const base = ZEditionStep(title: 't', fields: <String>['a']);
      const same = ZEditionStep(title: 't', fields: <String>['a']);
      const withIcon =
          ZEditionStep(title: 't', fields: <String>['a'], icon: Icons.star);
      const withSub =
          ZEditionStep(title: 't', fields: <String>['a'], subtitle: 's');

      expect(base == same, isTrue);
      expect(base.hashCode, same.hashCode);
      expect(base == withIcon, isFalse);
      expect(base == withSub, isFalse);

      const nested = ZEditionStep(
        title: 't',
        fields: <String>['a'],
        nestedSteps: <ZEditionStep>[ZEditionStep(title: 's0', fields: <String>['b'])],
      );
      expect(base == nested, isFalse);
      expect(nested.nestedSteps!.length, 1);
    });

    test('toString expose icon/subtitle/nb nested', () {
      const s = ZEditionStep(
        title: 't',
        fields: <String>['a'],
        icon: Icons.map,
        subtitle: 'sub',
        nestedSteps: <ZEditionStep>[ZEditionStep(title: 's0', fields: <String>[])],
      );
      expect(s.toString(), contains('subtitle: sub'));
      expect(s.toString(), contains('nested: 1'));
    });
  });
}
