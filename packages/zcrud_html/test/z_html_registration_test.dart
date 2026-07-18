/// 🎯 fp-4-3 (AC2, AC6) — enrôlement `registerZHtmlFields` : EXACTEMENT
/// `{html, inlineHtml}`, et **exclusivité md/html** prouvée CONTRE le contrat
/// cœur `ZWidgetRegistry.register` (throw), SANS dépendre de `zcrud_markdown`
/// (arête interdite AD-1).
@TestOn('vm')
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_html/zcrud_html.dart';

void main() {
  group('🎯 AC2 — kinds enregistrés = EXACTEMENT {html, inlineHtml}', () {
    test('🔴 registry.kinds == {html, inlineHtml} après enrôlement', () {
      final registry = ZWidgetRegistry();
      registerZHtmlFields(registry);
      // 🔴 R3 : assertion d'ÉGALITÉ d'ensemble — un mutant qui n'enregistrerait
      // qu'UN seul `kind` (ou un `kind` de trop) fait rougir ce test.
      expect(registry.kinds.toSet(), <String>{'html', 'inlineHtml'});
      expect(registry.isRegistered('html'), isTrue);
      expect(registry.isRegistered('inlineHtml'), isTrue);
    });
  });

  group('🎯 AC6 — exclusivité md/html via le CONTRAT CŒUR (throw)', () {
    test('🔴 propriétaire concurrent PRÉ-enregistré sur `html` ⇒ throw', () {
      final registry = ZWidgetRegistry();
      // Proxy de la voie markdown (ou de tout autre propriétaire du kind) —
      // AUCUN import de `zcrud_markdown` (AD-1).
      registry.register('html', (context, ctx) => const SizedBox.shrink());
      expect(
        () => registerZHtmlFields(registry),
        throwsA(isA<ZDuplicateRegistrationError>()),
        reason: '🔴 la 2ᵉ voie sur `html` DOIT throw (mutuellement exclusif)',
      );
    });

    test('🔴 propriétaire concurrent PRÉ-enregistré sur `inlineHtml` ⇒ throw',
        () {
      final registry = ZWidgetRegistry();
      registry.register(
          'inlineHtml', (context, ctx) => const SizedBox.shrink());
      expect(
        () => registerZHtmlFields(registry),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('🔴 double appel de registerZHtmlFields ⇒ throw à la 2ᵉ', () {
      final registry = ZWidgetRegistry();
      registerZHtmlFields(registry);
      expect(
        () => registerZHtmlFields(registry),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });

    test('un registre NEUF accepte l\'enrôlement (contrôle négatif)', () {
      final registry = ZWidgetRegistry();
      expect(() => registerZHtmlFields(registry), returnsNormally);
    });
  });
}
