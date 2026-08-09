/// 🔴 Gardes du **maillon jeton** du chrome d'édition (CR-TOKENS, 2026-08-09).
///
/// Le lot précédent avait livré `zEditionChromeMetricsOf` avec la chaîne
/// **paramètre > jeton `ZcrudTheme` > référence** — mais le maillon 2 était
/// **vide** (aucun jeton n'existait dans `zcrud_core`). Il existe maintenant,
/// pour **quatre** des six métriques. Ces gardes affirment :
///
/// 1. que le maillon jeton **mord réellement** (pas seulement qu'il compile) ;
/// 2. que le **paramètre reprime** dessus, dans les deux sens ;
/// 3. qu'**aucun hôte passif ne bouge** : sans jeton, la référence est rendue
///    au caractère près ;
/// 4. que les deux métriques **volontairement non tokenisées** le restent, avec
///    leur motif.
///
/// 🔴 **Anti-vacuité systématique** : chaque valeur de jeton employée ici est
/// asserté **différente** de la valeur de référence correspondante. Sans cela,
/// une garde passerait aussi bien avec le jeton totalement ignoré.
///
/// Accès `dart:io` ⇒ chemins RELATIFS : lancer `flutter test` **depuis**
/// `packages/zcrud_navigation`.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Résout les métriques sous un `ZcrudTheme` donné (ou aucun), en passant
/// éventuellement des surcharges **par paramètre**.
Future<ZEditionChromeMetrics> resolve(
  WidgetTester tester, {
  ZcrudTheme? token,
  double? minTouchTarget,
  EdgeInsetsGeometry? headerPadding,
  EdgeInsetsGeometry? actionBarPadding,
  double? pageHeaderExpandedHeight,
}) async {
  late ZEditionChromeMetrics out;
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[?token],
      ),
      home: Builder(
        builder: (BuildContext context) {
          out = zEditionChromeMetricsOf(
            context,
            minTouchTarget: minTouchTarget,
            headerPadding: headerPadding,
            actionBarPadding: actionBarPadding,
            pageHeaderExpandedHeight: pageHeaderExpandedHeight,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return out;
}

/// Valeurs de jeton, toutes **distinctes** de la référence (cf. CT-0).
const double kTokenMinTarget = 64;
const EdgeInsetsDirectional kTokenHeaderPadding =
    EdgeInsetsDirectional.fromSTEB(24, 12, 12, 12);
const EdgeInsetsDirectional kTokenActionBarPadding =
    EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20);
const double kTokenPageHeader = 200;

const ZcrudTheme kAllTokens = ZcrudTheme(
  editionChromeMinTouchTarget: kTokenMinTarget,
  editionChromeHeaderPadding: kTokenHeaderPadding,
  editionChromeActionBarPadding: kTokenActionBarPadding,
  editionChromePageHeaderExpandedHeight: kTokenPageHeader,
);

void main() {
  test(
    'CT-0 — ANTI-VACUITÉ : chaque valeur de jeton DIFFÈRE de sa référence',
    () {
      expect(kTokenMinTarget, isNot(ZEditionChromeReference.minTouchTarget));
      expect(kTokenHeaderPadding, isNot(ZEditionChromeReference.headerPadding));
      expect(
        kTokenActionBarPadding,
        isNot(ZEditionChromeReference.actionBarPadding),
      );
      expect(
        kTokenPageHeader,
        isNot(ZEditionChromeReference.pageHeaderExpandedHeight),
      );
    },
  );

  testWidgets(
    'CT-1 — HÔTE PASSIF : sans jeton, la RÉFÉRENCE est rendue au caractère '
    'près',
    (WidgetTester tester) async {
      final ZEditionChromeMetrics m = await resolve(tester);
      expect(m.minTouchTarget, ZEditionChromeReference.minTouchTarget);
      expect(m.headerPadding, ZEditionChromeReference.headerPadding);
      expect(m.actionBarPadding, ZEditionChromeReference.actionBarPadding);
      expect(m.actionPadding, ZEditionChromeReference.actionPadding);
      expect(
        m.pageHeaderExpandedHeight,
        ZEditionChromeReference.pageHeaderExpandedHeight,
      );
    },
  );

  testWidgets(
    'CT-2 — JETON : les 4 métriques tokenisées sont réellement pilotées par '
    '`ZcrudTheme`',
    (WidgetTester tester) async {
      final ZEditionChromeMetrics m = await resolve(tester, token: kAllTokens);
      expect(m.minTouchTarget, kTokenMinTarget,
          reason: '🔴 le maillon JETON de `minTouchTarget` est inerte : la '
              'référence a gagné.');
      expect(m.headerPadding, kTokenHeaderPadding,
          reason: '🔴 le maillon JETON de `headerPadding` est inerte.');
      expect(m.actionBarPadding, kTokenActionBarPadding,
          reason: '🔴 le maillon JETON de `actionBarPadding` est inerte.');
      expect(m.pageHeaderExpandedHeight, kTokenPageHeader,
          reason: '🔴 le maillon JETON de `pageHeaderExpandedHeight` est '
              'inerte.');
    },
  );

  testWidgets(
    'CT-3 — PRIORITÉ (sens 1) : le PARAMÈTRE reprime sur un jeton posé',
    (WidgetTester tester) async {
      final ZEditionChromeMetrics m = await resolve(
        tester,
        token: kAllTokens,
        minTouchTarget: 72,
        headerPadding: const EdgeInsetsDirectional.fromSTEB(1, 1, 1, 1),
        actionBarPadding: const EdgeInsetsDirectional.fromSTEB(2, 2, 2, 2),
        pageHeaderExpandedHeight: 300,
      );
      // Anti-vacuité : les valeurs de paramètre diffèrent AUSSI des jetons.
      expect(72.0, isNot(kTokenMinTarget));
      expect(300.0, isNot(kTokenPageHeader));
      expect(m.minTouchTarget, 72,
          reason: '🔴 le jeton a battu le paramètre : la chaîne est inversée.');
      expect(
        m.headerPadding,
        const EdgeInsetsDirectional.fromSTEB(1, 1, 1, 1),
      );
      expect(
        m.actionBarPadding,
        const EdgeInsetsDirectional.fromSTEB(2, 2, 2, 2),
      );
      expect(m.pageHeaderExpandedHeight, 300);
    },
  );

  testWidgets(
    'CT-4 — PRIORITÉ (sens 2) : sans paramètre, le jeton bat la référence — et '
    'un paramètre PARTIEL ne fait pas tomber les autres jetons',
    (WidgetTester tester) async {
      final ZEditionChromeMetrics m = await resolve(
        tester,
        token: kAllTokens,
        minTouchTarget: 72, // un SEUL paramètre
      );
      expect(m.minTouchTarget, 72);
      // Les trois autres restent sur le JETON, pas sur la référence.
      expect(m.headerPadding, kTokenHeaderPadding,
          reason: '🔴 fournir UN paramètre a fait retomber les autres '
              'métriques sur la référence.');
      expect(m.actionBarPadding, kTokenActionBarPadding);
      expect(m.pageHeaderExpandedHeight, kTokenPageHeader);
    },
  );

  testWidgets(
    'CT-5 — `gap` reste sur le jeton GÉNÉRIQUE `gapM` : aucun second canal',
    (WidgetTester tester) async {
      // 🔴 Décision CR-TOKENS : pas de `editionChromeGap`. `gap` lit `gapM`,
      // jeton générique EXISTANT — un jeton dédié serait une « vue parallèle »
      // (CR-LEX-78) pour la même propriété.
      const double gapM = 33;
      expect(gapM, isNot(const ZcrudTheme().gapM),
          reason: 'anti-vacuité : la valeur de test doit différer du défaut.');
      final ZEditionChromeMetrics m =
          await resolve(tester, token: const ZcrudTheme(gapM: gapM));
      expect(m.gap, gapM,
          reason: '🔴 `gap` ne lit plus `ZcrudTheme.gapM` : soit le canal est '
              'mort, soit un second canal a été introduit.');
    },
  );

  testWidgets(
    'CT-6 — `actionPadding` n\'est PAS tokenisé, et reste surchargeable par '
    'paramètre',
    (WidgetTester tester) async {
      // Décision CR-TOKENS : micro-détail d'un seul widget, pas une décision de
      // design à l'échelle d'une app. L'échappatoire par paramètre existe donc
      // la métrique n'est jamais hors d'atteinte.
      final ZEditionChromeMetrics avecJetons =
          await resolve(tester, token: kAllTokens);
      expect(avecJetons.actionPadding, ZEditionChromeReference.actionPadding,
          reason: '🔴 `actionPadding` a gagné un jeton sans que la décision '
              'documentée soit revue.');
      late ZEditionChromeMetrics m;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              m = zEditionChromeMetricsOf(
                context,
                actionPadding: const EdgeInsetsDirectional.fromSTEB(9, 9, 9, 9),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(
        m.actionPadding,
        const EdgeInsetsDirectional.fromSTEB(9, 9, 9, 9),
      );
    },
  );

  testWidgets(
    'CT-7 — AU RENDU : le jeton de plancher tactile pilote réellement le '
    'chrome monté (AD-13)',
    (WidgetTester tester) async {
      // Le maillon ne doit pas seulement exister dans la fonction de
      // résolution : il doit atteindre l'arbre. On mesure une CIBLE.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              ZcrudTheme(editionChromeMinTouchTarget: kTokenMinTarget),
            ],
          ),
          home: ZEditionScaffold(
            mode: ZEditionPresentation.dialog,
            chrome: ZEditionChrome(title: 'Titre', onSubmit: () {}),
            body: const SizedBox(width: double.infinity, height: 100),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Iterable<Element> cibles = find
          .descendant(
            of: find.byType(ZEditionScaffold),
            matching: find.byType(GestureDetector),
          )
          .evaluate();
      expect(cibles, isNotEmpty,
          reason: '🔴 aucune cible trouvée : la garde serait VACANTE.');
      bool auMoinsUneAuJeton = false;
      for (final Element e in cibles) {
        final Size s = e.size ?? Size.zero;
        if (s.isEmpty) {
          continue;
        }
        expect(
          s.height,
          greaterThanOrEqualTo(kTokenMinTarget),
          reason: '🔴 une cible fait ${s.height} dp alors que le jeton exige '
              '$kTokenMinTarget : le plancher tokenisé n\'atteint pas l\'arbre.',
        );
        if (s.height == kTokenMinTarget) {
          auMoinsUneAuJeton = true;
        }
      }
      expect(auMoinsUneAuJeton, isTrue,
          reason: '🔴 aucune cible ne vaut EXACTEMENT le plancher du jeton : '
              'la garde passerait avec n\'importe quel plancher plus grand, '
              'donc elle ne prouve pas que le jeton mord.');
    },
  );
}
