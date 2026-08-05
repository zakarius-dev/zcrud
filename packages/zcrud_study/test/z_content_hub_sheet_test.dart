// Tests DISCRIMINANTS ES-5.3 — `ZContentHubSheet` (AC3, AC6).
//
// AC3 : entrée active ⇒ tap invoque onTap 1× + icône/label/hint INJECTÉS
//   rendus ; entrée désactivée (`enabled:false` OU `onTap:null`) ⇒ NON
//   actionnable (tap sans effet) + Semantics désactivée. Pouvoir discriminant
//   R3-I3 : entrée désactivée actionnable ⇒ ROUGE.
//
// 🔴 **CR-IFFD-65 — réécriture du MOTIF, pas d'un seuil.** Le troisième cas
// lisait `tester.widget<ListTile>(find.byType(ListTile))` : il liait l'assertion
// « non actionnable » à un DÉTAIL DE STRUCTURE (l'entrée est un `ListTile` nu).
// Le rendu par défaut étant devenu le rendu de référence (carte + pastille +
// chevron), ce motif cassait **structurellement** — sans qu'aucune propriété
// mesurée n'ait changé. Le motif est donc reporté sur ce qui EST la propriété :
// **le puits d'activation réellement câblé** (`InkWell.onTap`) et le signal
// a11y (`Semantics(enabled:)`), tous deux indépendants de la forme rendue.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study/zcrud_study.dart';

const IconData kActiveIcon = Icons.star;
const IconData kDisabledIcon = Icons.block;
const String kActiveLabel = 'AJOUTER-DOC-XYZ';
const String kActiveHint = 'INDICE-DOC-XYZ';
const String kDisabledLabel = 'AJOUTER-NOTE-DESACTIVEE';

Widget _wrap(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(child: Scaffold(body: child)),
    ),
  );
}

void main() {
  testWidgets(
    'AC3 : entrée active ⇒ tap invoque onTap 1× + icône/label/hint INJECTÉS',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          ZContentHubSheet(
            entries: [
              ZContentHubEntry(
                icon: kActiveIcon,
                label: kActiveLabel,
                hint: kActiveHint,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );

      // Contenus INJECTÉS rendus (jamais un label/icône codé en dur).
      expect(find.byIcon(kActiveIcon), findsOneWidget);
      expect(find.text(kActiveLabel), findsOneWidget);
      expect(find.text(kActiveHint), findsOneWidget);

      await tester.tap(find.text(kActiveLabel));
      await tester.pump();
      expect(taps, 1);
    },
  );

  testWidgets('AC3 : entrée enabled:false ⇒ NON actionnable (tap sans effet)', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(
        ZContentHubSheet(
          entries: [
            ZContentHubEntry(
              icon: kDisabledIcon,
              label: kDisabledLabel,
              enabled: false,
              onTap: () => taps++,
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text(kDisabledLabel));
    await tester.pump();
    expect(taps, 0, reason: 'entrée désactivée : le tap n\'a AUCUN effet (AD-4)');
  });

  testWidgets('AC3 : entrée onTap:null ⇒ NON actionnable (AD-4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ZContentHubSheet(
          entries: [ZContentHubEntry(icon: kDisabledIcon, label: kDisabledLabel)],
        ),
      ),
    );

    // 🔴 Motif INDÉPENDANT DE LA FORME (cf. tête de fichier) : le puits
    // d'activation réellement câblé. Une entrée non actionnable n'a AUCUN
    // `onTap` branché — pas un callback qui ne fait rien (AD-4).
    final InkWell ink = tester.widget<InkWell>(find.byType(InkWell));
    expect(ink.onTap, isNull);

    // …et l'état est SIGNALÉ à l'a11y, pas seulement au pointeur.
    final Semantics tile = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == kDisabledLabel);
    expect(tile.properties.enabled, isFalse);
  });

  testWidgets('AC3/AC6 : entrée désactivée signalée Semantics(enabled:false)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ZContentHubSheet(
          entries: [
            ZContentHubEntry(
              icon: kActiveIcon,
              label: kActiveLabel,
              onTap: () {},
            ),
            const ZContentHubEntry(icon: kDisabledIcon, label: kDisabledLabel),
          ],
        ),
      ),
    );

    // L'état actionnable/désactivé est PORTÉ par le Semantics de la tuile
    // (signal a11y déterministe, indépendant de la forme rendue).
    Semantics semanticsFor(String label) => tester
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == label);

    expect(semanticsFor(kActiveLabel).properties.enabled, isTrue);
    expect(semanticsFor(kActiveLabel).properties.button, isTrue);
    expect(
      semanticsFor(kDisabledLabel).properties.enabled,
      isFalse,
      reason: 'entrée désactivée signalée Semantics(enabled:false) — AD-4',
    );
  });

  test('ZContentHubEntry.isActionable : enabled ET onTap non-null', () {
    expect(
      ZContentHubEntry(icon: kActiveIcon, label: 'x', onTap: () {}).isActionable,
      isTrue,
    );
    expect(
      const ZContentHubEntry(icon: kActiveIcon, label: 'x').isActionable,
      isFalse,
    );
    expect(
      ZContentHubEntry(
        icon: kActiveIcon,
        label: 'x',
        enabled: false,
        onTap: () {},
      ).isActionable,
      isFalse,
    );
  });
}
