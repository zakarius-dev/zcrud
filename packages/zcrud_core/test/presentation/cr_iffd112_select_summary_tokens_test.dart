/// 🔴 Gardes des quatre jetons `ZcrudTheme.selectSummary*` et de la clé l10n
/// `selectSummaryOverflow` — le résumé d'un déclencheur de sélection MULTIPLE.
///
/// Ce que `zcrud_core` doit tenir **seul** (le rendu, lui, appartient au
/// présentateur et est gardé dans `zcrud_select`) :
///
/// 1. **aucun jeton posé par le repli** — `fallback()` laisse les quatre à
///    `null`, sans quoi la référence du présentateur deviendrait inatteignable ;
/// 2. **`copyWith` propage** réellement les quatre valeurs ;
/// 3. **`lerp` correct par FAMILLE** — discret pour le COMPTE, plancher pour
///    les deux dimensions, insets pour la marge ;
/// 4. **la clé de débordement existe dans les DEUX tables**, avec des valeurs
///    réellement distinctes, et se résout par locale.
///
/// ⚠️ **Anti-vacuité** : chaque garde de `lerp` affirme d'abord que la valeur
/// attendue n'est **pas** celle qu'un helper de la mauvaise famille produirait.
///
/// 🔴 **Anti-tautologie** : les valeurs attendues sont des **littéraux** posés
/// par le test, jamais une constante du code sous test.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const ZcrudLocalizationsDelegate _delegate = ZcrudLocalizationsDelegate();

void main() {
  group('CR-IFFD-112 — jetons `ZcrudTheme.selectSummary*`', () {
    test(
      '🔴 SUM-T1 — les 4 jetons sont ABSENTS de `fallback()` (clair ET sombre) : '
      'la référence du présentateur reste seule maîtresse',
      () {
        for (final ThemeData base in <ThemeData>[
          ThemeData.light(),
          ThemeData.dark(),
        ]) {
          final ZcrudTheme f = ZcrudTheme.fallback(base);
          expect(
            f.selectSummaryMaxChips,
            isNull,
            reason: '🔴 le repli POSE une coupure : un hôte qui n\'a rien '
                'déclaré subirait un palier que personne n\'a choisi, et la '
                'référence du présentateur deviendrait inatteignable.',
          );
          expect(f.selectSummaryChipRadius, isNull);
          expect(f.selectSummaryChipPadding, isNull);
          expect(f.selectSummaryChipFontSize, isNull);
        }
        // Anti-vacuité : le repli pose BIEN d'autres jetons — la garde ne
        // mesure donc pas un `fallback()` vide.
        expect(ZcrudTheme.fallback(ThemeData.light()).fieldPadding, isNotNull);
      },
    );

    test('🔴 SUM-T2 — `copyWith` propage les quatre valeurs', () {
      const ZcrudTheme vide = ZcrudTheme();
      final ZcrudTheme plein = vide.copyWith(
        selectSummaryMaxChips: 5,
        selectSummaryChipRadius: 9,
        selectSummaryChipPadding:
            const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 2),
        selectSummaryChipFontSize: 17,
      );
      // Anti-vacuité : la source ne portait aucune des quatre valeurs.
      expect(vide.selectSummaryMaxChips, isNull);
      expect(plein.selectSummaryMaxChips, 5);
      expect(plein.selectSummaryChipRadius, 9);
      expect(
        plein.selectSummaryChipPadding,
        const EdgeInsetsDirectional.symmetric(horizontal: 7, vertical: 2),
      );
      expect(plein.selectSummaryChipFontSize, 17);
    });

    test(
      '🔴 SUM-T3 — `lerp` du COMPTE est DISCRET : jamais un demi-palier',
      () {
        const ZcrudTheme a = ZcrudTheme(selectSummaryMaxChips: 3);
        const ZcrudTheme b = ZcrudTheme(selectSummaryMaxChips: 9);
        // Anti-vacuité : une interpolation continue rendrait 6 à mi-course —
        // ce que la garde EXCLUT explicitement.
        expect((3 + (9 - 3) * 0.5).round(), 6);
        expect(a.lerp(b, 0.49).selectSummaryMaxChips, 3);
        expect(a.lerp(b, 0.51).selectSummaryMaxChips, 9);
        expect(a.lerp(b, 0.51).selectSummaryMaxChips, isNot(6));
      },
    );

    test(
      '🔴 SUM-T4 — `lerp` des DIMENSIONS est un PLANCHER : un côté `null` ne '
      'traverse jamais par zéro',
      () {
        const ZcrudTheme rien = ZcrudTheme();
        const ZcrudTheme pose =
            ZcrudTheme(selectSummaryChipRadius: 20, selectSummaryChipFontSize: 20);
        final ZcrudTheme mi = rien.lerp(pose, 0.5);
        // Anti-vacuité : `lerpDouble(0, 20, .5)` vaudrait 10 — le rendu d'un
        // rayon presque carré et d'un texte de moitié, que personne n'a choisi.
        expect(10.0, isNot(20.0));
        expect(mi.selectSummaryChipRadius, 20);
        expect(mi.selectSummaryChipFontSize, 20);
        // Les deux côtés posés ⇒ interpolation réelle.
        const ZcrudTheme autre =
            ZcrudTheme(selectSummaryChipRadius: 10, selectSummaryChipFontSize: 10);
        expect(
          autre.lerp(pose, 0.5).selectSummaryChipRadius,
          15,
        );
      },
    );

    test(
      '🔴 SUM-T5 — `lerp` de la MARGE : `null` des deux côtés RESTE `null`',
      () {
        const ZcrudTheme rien = ZcrudTheme();
        expect(
          rien.lerp(const ZcrudTheme(), 0.5).selectSummaryChipPadding,
          isNull,
          reason: '🔴 matérialiser `EdgeInsets.zero` GÈLERAIT la référence du '
              'présentateur à la première transition de thème',
        );
        const ZcrudTheme pose = ZcrudTheme(
          selectSummaryChipPadding: EdgeInsetsDirectional.all(20),
        );
        expect(
          rien.lerp(pose, 0.5).selectSummaryChipPadding,
          const EdgeInsetsDirectional.all(10),
        );
      },
    );
  });

  group('CR-IFFD-112 — clé l10n `selectSummaryOverflow`', () {
    test(
      '🔴 SUM-L1 — la clé vit dans les DEUX tables, et `fr` n\'est pas `en`',
      () async {
        final ZcrudLocalizations fr = await _delegate.load(const Locale('fr'));
        final ZcrudLocalizations en = await _delegate.load(const Locale('en'));
        // 🔴 `maybeResolve` rend `null` sur clé ABSENTE — c'est le seul canal
        // qui distingue « traduit » de « retombé sur la clé brute », que
        // `resolve()` masquerait en rendant la clé elle-même.
        expect(fr.maybeResolve('selectSummaryOverflow'), isNotNull);
        expect(en.maybeResolve('selectSummaryOverflow'), isNotNull);
        expect(fr.resolve('selectSummaryOverflow'), 'autres');
        expect(en.resolve('selectSummaryOverflow'), 'more');
        // Anti-vacuité : une table `fr` recopiée de `en` passerait les deux
        // premiers `expect` — pas celui-ci.
        expect(
          fr.resolve('selectSummaryOverflow'),
          isNot(en.resolve('selectSummaryOverflow')),
        );
      },
    );

    testWidgets(
      '🔴 SUM-L2 — sans delegate monté, `label()` rend le fragment `en`, '
      'JAMAIS la clé brute',
      (tester) async {
        late String texte;
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (ctx) {
            texte = label(ctx, 'selectSummaryOverflow');
            return const SizedBox.shrink();
          }),
        ));
        expect(texte, isNot('selectSummaryOverflow'));
        expect(texte, 'more');
      },
    );

    testWidgets(
      '🔴 SUM-L3 — `ZcrudScope.labels` SURCHARGE le fragment (AD-13)',
      (tester) async {
        late String texte;
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            labels: ZcrudLabels(<String, String>{
              'selectSummaryOverflow': 'de plus',
            }),
            child: Builder(builder: (ctx) {
              texte = label(ctx, 'selectSummaryOverflow');
              return const SizedBox.shrink();
            }),
          ),
        ));
        expect(texte, 'de plus');
      },
    );
  });
}
