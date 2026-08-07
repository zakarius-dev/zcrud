/// **CR-IFFD-75** — l'en-tête de `ZChatSettingsSheet` collait ses deux actions
/// (« RéinitialiserFermer », mesuré sur appareil, TECNO KN4, 2026-08-07).
///
/// ## Ce que ces gardes mesurent — et pourquoi elles ne sont pas vacantes
///
/// Le plancher 48 dp est une borne **basse** : un libellé plus large fait
/// grandir la boîte, et deux boîtes voisines finissent bord à bord. Les gardes
/// existantes mesuraient des cibles (≥ 48 dp) et des nœuds sémantiques — deux
/// propriétés que le rendu défaillant satisfaisait. Ici on mesure **la
/// distance horizontale entre les deux rectangles de LIBELLÉ rendus**, dans le
/// régime exact du défaut : des libellés **plus larges que 48 dp** (asserté —
/// l'attendu diffère de l'ambiant anglais, où Reset/Close restent sous le
/// plancher et ne se touchent jamais).
///
/// Les « non mesuré » de la CR sont mesurés : RTL (l'ordre s'inverse, l'écart
/// tient), petit écran (l'`Expanded` du titre comprimé — aucun débordement,
/// l'écart tient), et l'absence d'autre surface montant la primitive est
/// prouvée par grep négatif (volet SOURCE).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

/// Libellés LONGS injectés — le régime du défaut (chacun > 48 dp rendu).
const Map<String, String> _long = <String, String>{
  kZChatLabelSettingsReset: 'Réinitialisation complète des réglages',
  kZChatLabelSettingsClose: 'Fermeture de la feuille',
};

Widget _sheet({
  TextDirection direction = TextDirection.ltr,
  double? actionSpacing,
  Map<String, String> labels = _long,
}) {
  final ZChatSettingsController c = ZChatSettingsController();
  return harness(
    SingleChildScrollView(
      child: ZChatSettingsSheet(
        controller: c,
        onClose: () {},
        actionSpacing: actionSpacing,
      ),
    ),
    direction: direction,
    labels: labels,
  );
}

/// Les rects RENDUS des deux libellés d'action de l'en-tête.
({Rect reset, Rect close}) _labelRects(
  WidgetTester tester,
  Map<String, String> labels,
) {
  final Rect reset = tester.getRect(
    find.text(labels[kZChatLabelSettingsReset]!),
  );
  final Rect close = tester.getRect(
    find.text(labels[kZChatLabelSettingsClose]!),
  );
  return (reset: reset, close: close);
}

/// Distance horizontale entre deux rects DISJOINTS sur l'axe X — négative ou
/// nulle si les libellés se touchent ou se chevauchent (le collage mesuré).
double _horizontalGap(Rect a, Rect b) {
  final Rect first = a.left <= b.left ? a : b;
  final Rect second = identical(first, a) ? b : a;
  return second.left - first.right;
}

void main() {
  group('🔴 CR75 — deux actions adjacentes restent DISTINCTES', () {
    testWidgets(
        'CR75-G1 — libellés LONGS (> 48 dp chacun) : l\'écart rendu entre les '
        'deux libellés est ≥ la référence', (WidgetTester tester) async {
      await tester.pumpWidget(_sheet());
      final ({Rect close, Rect reset}) r = _labelRects(tester, _long);
      // 🔴 Non-vacuité du RÉGIME : les deux libellés débordent le plancher —
      // c'est le cas que la borne basse de 48 dp ne protège pas, et celui où
      // l'ambiant anglais (Reset/Close < 48 dp) ne mesurerait rien.
      expect(r.reset.width, greaterThan(kZChatMinTapTarget),
          reason: '🔴 régime hors-défaut : le libellé « réinitialiser » tient '
              'sous le plancher, la garde ne mesure pas le cas de la CR.');
      expect(r.close.width, greaterThan(kZChatMinTapTarget),
          reason: '🔴 régime hors-défaut : le libellé « fermer » tient sous '
              'le plancher.');
      expect(
        _horizontalGap(r.reset, r.close),
        greaterThanOrEqualTo(kZChatSettingsReferenceActionGap),
        reason: '🔴 CR-IFFD-75 réinjectée : les deux libellés se touchent — '
            '« RéinitialiserFermer ».',
      );
    });

    testWidgets(
        'CR75-G2 — le COLLAGE EXACT de l\'appareil (replis français '
        'Réinitialiser/Fermer) est écarté', (WidgetTester tester) async {
      // Aucun registre : les replis français du socle — la capture de la CR.
      final ZChatSettingsController c = ZChatSettingsController();
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: ZChatSettingsSheet(controller: c, onClose: () {}),
          ),
        ),
      );
      final Rect reset = tester.getRect(find.text('Réinitialiser'));
      final Rect close = tester.getRect(find.text('Fermer'));
      expect(reset.width, greaterThan(kZChatMinTapTarget),
          reason: '🔴 « Réinitialiser » ne déborde plus le plancher : le '
              'collage mesuré n\'est plus reproduit par ce montage.');
      expect(
        _horizontalGap(reset, close),
        greaterThanOrEqualTo(kZChatSettingsReferenceActionGap),
        reason: '🔴 le collage mesuré sur appareil (v0.56.0) est de retour.',
      );
    });

    testWidgets('CR75-G3 — RTL : l\'ordre s\'INVERSE et l\'écart TIENT',
        (WidgetTester tester) async {
      await tester.pumpWidget(_sheet(direction: TextDirection.rtl));
      final ({Rect close, Rect reset}) r = _labelRects(tester, _long);
      // L'ordre s'inverse réellement (sinon le volet RTL mesure le même
      // montage que G1 — garde vacante).
      expect(r.reset.left, greaterThan(r.close.left),
          reason: '🔴 en RTL, « réinitialiser » doit passer À DROITE de '
              '« fermer » — l\'ordre ne s\'est pas inversé, le volet RTL est '
              'vacant.');
      expect(
        _horizontalGap(r.reset, r.close),
        greaterThanOrEqualTo(kZChatSettingsReferenceActionGap),
        reason: '🔴 l\'écart CR-75 ne survit pas au RTL.',
      );
    });

    testWidgets(
        'CR75-G4 — PETIT ÉCRAN (280 dp) : aucun débordement, écart tenu',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(280, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_sheet());
      final List<Object> errors = <Object>[];
      for (Object? e = tester.takeException();
          e != null;
          e = tester.takeException()) {
        errors.add(e);
      }
      expect(
        errors.where((Object e) => '$e'.contains('overflowed')),
        isEmpty,
        reason: '🔴 CR-75, « non mesuré » petit écran : la Row de l\'en-tête '
            'déborde quand l\'Expanded du titre se comprime.',
      );
      final ({Rect close, Rect reset}) r = _labelRects(tester, _long);
      expect(
        _horizontalGap(r.reset, r.close),
        greaterThanOrEqualTo(kZChatSettingsReferenceActionGap),
        reason: '🔴 sous compression, les libellés se recollent.',
      );
    });

    testWidgets(
        'CR75-G5 — l\'écart est RÉGLABLE (paramètre `actionSpacing`, '
        'attendu ≠ référence)', (WidgetTester tester) async {
      const double demande = 40;
      await tester.pumpWidget(_sheet(actionSpacing: demande));
      final ({Rect close, Rect reset}) r = _labelRects(tester, _long);
      expect(
        _horizontalGap(r.reset, r.close),
        greaterThanOrEqualTo(demande),
        reason: '🔴 `actionSpacing` n\'est pas honoré : le canal « réglable » '
            'demandé par la CR est décoratif.',
      );
    });

    test(
        'CR75-S1 — grep NÉGATIF : la primitive `_ZChatSettingsAction` n\'est '
        'montée par AUCUNE autre surface de `lib/`', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<String> hosts = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in lib.entries) {
        scanned++;
        if (e.key.endsWith('z_chat_settings_sheet.dart')) continue;
        if (e.value.any((String l) => l.contains('_ZChatSettingsAction'))) {
          hosts.add(e.key);
        }
      }
      // Contre-preuve de non-vacuité : le scan a bien parcouru les sources, et
      // le fichier porteur, lui, contient le motif.
      expect(scanned, greaterThan(10),
          reason: '🔴 garde vacante : le scan n\'a rien lu.');
      expect(
        lib.entries
            .where((MapEntry<String, List<String>> e) =>
                e.key.endsWith('z_chat_settings_sheet.dart'))
            .single
            .value
            .any((String l) => l.contains('_ZChatSettingsAction')),
        isTrue,
        reason: '🔴 le motif ne voit plus la primitive là où elle vit.',
      );
      expect(hosts, isEmpty,
          reason: '🔴 la primitive est montée ailleurs : vérifier que la '
              'surface hôte hérite bien du dégagement CR-75 (elle l\'hérite '
              'par défaut — ce volet force la relecture).');
    });

    test('CR75-S2 — le dégagement de la primitive est DIRECTIONNEL (AD-13)',
        () {
      final File f = File(
        'lib/src/presentation/view/z_chat_settings_sheet.dart',
      );
      final String src = f.readAsStringSync();
      expect(
        src.contains(
          'EdgeInsetsDirectional.symmetric(horizontal: inset)',
        ),
        isTrue,
        reason: '🔴 le dégagement CR-75 n\'est plus posé en '
            '`EdgeInsetsDirectional` symétrique dans la primitive.',
      );
    });
  });
}
