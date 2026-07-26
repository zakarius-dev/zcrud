/// SUF-4 — gardes des **fermetures d'écart de parité** face aux widgets natifs
/// de `lex_ui` (audit : `docs/parity-session-widgets-2026-07-26.md`).
///
/// Trois fermetures, trois lots de gardes **MORDANTES** (R3). Chaque garde
/// énonce **explicitement** la régression qu'elle attrape ; la morsure a été
/// rejouée sur disque (ré-injection → ROUGE → retrait → VERT), cf. Completion
/// Notes de la story.
///
/// | Paire | Écart fermé | Surface ajoutée |
/// |---|---|---|
/// | 4 — indicateur | aucune barre CONTINUE face au `LinearProgressIndicator(minHeight: 6)` de `_SessionHeader` | `ZSessionProgressStyle.linear` + `linearThickness` |
/// | 1 — boutons SRS | fond plein / zéro bord FIGÉS, contre le fond teinté + bord 1↔2 px de `_SrsButton` | `ZSrsQualityEmphasis` |
/// | 2 — répartition | crans à 0 OMIS, contre les 5 lignes stables de `SessionQualityBreakdown` | `ZQualityBreakdownCoverage` |
///
/// 🔒 **Aucune assertion tautologique** : on mesure la **géométrie/les objets
/// réellement peints** (`minHeight` du `LinearProgressIndicator`, `color`/`shape`
/// du `Material`, segments réellement montés) et l'**arbre sémantique** — jamais
/// un `find.text` dépendant de la langue, jamais un champ que le widget se
/// contenterait de recopier.
@TestOn('vm')
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope, ZcrudTheme;
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

/// Monte [child] sous un `ZcrudScope` dont on maîtrise les **tokens de thème**
/// (c'est ce qui rend la garde d'épaisseur discriminante : deux `gapS`
/// différents doivent produire deux épaisseurs différentes).
Future<void> _pumpScoped(
  WidgetTester tester,
  Widget child, {
  ZcrudTheme? theme,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(theme: theme, child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Le `LinearProgressIndicator` **du nœud de barre** (jamais un trouvé au
/// hasard de l'arbre).
LinearProgressIndicator _linearOf(WidgetTester tester) =>
    tester.widget<LinearProgressIndicator>(
      find.byKey(ZSessionProgressIndicator.linearKey),
    );

/// Le `Material` du bouton de cran [quality].
Material _qualityMaterialOf(WidgetTester tester, int quality) =>
    tester.widget<Material>(
      find.descendant(
        of: find.byKey(
          ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$quality'),
        ),
        matching: find.byType(Material),
      ),
    );

/// Côté de bordure **réellement peint** par le `Material` d'un cran.
BorderSide _sideOf(Material material) {
  final shape = material.shape;
  if (shape is RoundedRectangleBorder) return shape.side;
  fail('le Material du cran ne porte pas de RoundedRectangleBorder');
}

void main() {
  // ══════════════════════════════════════════════════════════════════════════
  // PAIRE 4 — `ZSessionProgressStyle.linear`
  // ══════════════════════════════════════════════════════════════════════════
  group('SUF-4 / paire 4 — barre CONTINUE (parité `_SessionHeader` de lex)', () {
    testWidgets(
      '`linear` rend UNE barre continue et AUCUN élément par carte',
      (tester) async {
        await _pumpScoped(
          tester,
          const ZSessionProgressIndicator(
            total: 4,
            currentIndex: 1,
            passThreshold: 3,
            style: ZSessionProgressStyle.linear,
          ),
        );

        expect(
          find.byKey(ZSessionProgressIndicator.linearKey),
          findsOneWidget,
        );
        // 🔴 MORDANT : si `linear` retombait sur `dots`/`segmentedBar` (branche
        // oubliée dans le `switch`, ou valeur d'enum câblée sur un style
        // existant), ces deux attentes RIPOSTERAIENT — c'est exactement la
        // fermeture qui serait annulée.
        expect(
          find.byKey(const ValueKey<String>('zProgressDot_0')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey<String>('zProgressSegment_0')),
          findsNothing,
        );
      },
    );

    testWidgets(
      '🔴 la fraction PEINTE est EXACTEMENT celle qu\'annonce le lecteur '
      'd\'écran (source unique `position`)',
      (tester) async {
        // 🔴 Corpus ASYMÉTRIQUE — mesuré : mon premier jet utilisait
        // `total: 4, currentIndex: 1` ⇒ fraction **0,5**. La ré-injection R3
        // « fraction inversée » (`1 - value`) laissait le test **VERT** :
        // `1 - 0.5 == 0.5`. Un cas symétrique rend la garde structurellement
        // incapable de rougir. `2/5 = 0,4` (inversé : 0,6 ; décalé : 0,2).
        await _pumpScoped(
          tester,
          const ZSessionProgressIndicator(
            total: 5,
            currentIndex: 1,
            passThreshold: 3,
            style: ZSessionProgressStyle.linear,
          ),
        );

        // Ce que le nœud de progression ANNONCE.
        final semantics = tester.getSemantics(
          find.byKey(ZSessionProgressIndicator.progressKey),
        );
        expect(semantics.value, '2/5');

        // Ce que la barre PEINT. 🔴 MORDANT : une fraction inversée
        // (`1 - value` = 0,6), décalée (`currentIndex / total` = 0,2) ou
        // recodée en dur ferait diverger ces deux canaux — le défaut « la
        // barre dit autre chose que le lecteur d'écran » que ce dépôt traque.
        expect(_linearOf(tester).value, closeTo(2 / 5, 1e-9));
      },
    );

    testWidgets(
      '🔴 l\'épaisseur par DÉFAUT vient du THÈME (deux `gapS` ⇒ deux '
      'épaisseurs) — un `6` en dur ferait converger',
      (tester) async {
        const indicator = ZSessionProgressIndicator(
          total: 3,
          currentIndex: 0,
          passThreshold: 3,
          style: ZSessionProgressStyle.linear,
        );

        await _pumpScoped(tester, indicator,
            theme: const ZcrudTheme(gapS: 4));
        final thin = _linearOf(tester).minHeight;

        await _pumpScoped(tester, indicator,
            theme: const ZcrudTheme(gapS: 11));
        final thick = _linearOf(tester).minHeight;

        // Ancrage sur la VALEUR du token, pas seulement sur la différence :
        // « deux valeurs différentes » resterait vrai d'un `gapS * 2` fantaisiste.
        expect(thin, 4);
        expect(thick, 11);
        // 🔴 MORDANT : `minHeight: 6` (le littéral de lex) rendrait ces deux
        // mesures ÉGALES et fausses.
        expect(thin, isNot(equals(thick)));
      },
    );

    testWidgets(
      '`linearThickness` INJECTÉE gagne sur le thème ; une valeur aberrante '
      'retombe sur le thème (AD-10)',
      (tester) async {
        // Injection légitime : l\'app atteint le 6 dp de son design SANS que le
        // widget le connaisse.
        await _pumpScoped(
          tester,
          const ZSessionProgressIndicator(
            total: 3,
            currentIndex: 0,
            passThreshold: 3,
            style: ZSessionProgressStyle.linear,
            linearThickness: 6,
          ),
          theme: const ZcrudTheme(gapS: 4),
        );
        // 🔴 MORDANT : ignorer le paramètre (le déclarer sans le consommer,
        // défaut classique) rendrait 4 ici.
        expect(_linearOf(tester).minHeight, 6);

        for (final aberrant in <double>[0, -3, double.nan, double.infinity]) {
          await _pumpScoped(
            tester,
            ZSessionProgressIndicator(
              total: 3,
              currentIndex: 0,
              passThreshold: 3,
              style: ZSessionProgressStyle.linear,
              linearThickness: aberrant,
            ),
            theme: const ZcrudTheme(gapS: 4),
          );
          // 🔴 MORDANT : propager la valeur telle quelle donnerait une barre
          // invisible (0), une assertion de framework (négatif) ou un NaN.
          expect(
            _linearOf(tester).minHeight,
            4,
            reason: 'épaisseur aberrante $aberrant ⇒ repli THÈME, jamais un throw',
          );
        }
      },
    );

    testWidgets(
      '🔴 file VIDE : aucune exception, barre à 0, annonce « 0/0 » (AD-10)',
      (tester) async {
        await _pumpScoped(
          tester,
          const ZSessionProgressIndicator(
            total: 0,
            currentIndex: 0,
            passThreshold: 3,
            style: ZSessionProgressStyle.linear,
          ),
        );

        expect(tester.takeException(), isNull);
        // 🔴 MORDANT : une division `position / total` non gardée lèverait ou
        // rendrait NaN — `LinearProgressIndicator` asserte sur `0..1`.
        expect(_linearOf(tester).value, 0);
        expect(
          tester
              .getSemantics(
                find.byKey(ZSessionProgressIndicator.progressKey),
              )
              .value,
          '0/0',
        );
      },
    );

    testWidgets(
      '🔴 la progression n\'est annoncée QU\'UNE FOIS (le nœud Material natif '
      'ne double pas l\'annonce)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpScoped(
          tester,
          const ZSessionProgressIndicator(
            total: 4,
            currentIndex: 1,
            passThreshold: 3,
            style: ZSessionProgressStyle.linear,
          ),
        );

        // Énumération de TOUS les nœuds du SOUS-ARBRE de la progression —
        // jamais une sonde sur un seul nœud (leçon su-5 : un défaut a11y est
        // un MOTIF). 🔴 MORDANT — DÉFAUT RÉELLEMENT ATTRAPÉ ICI : mon premier
        // jet passait `semanticsValue: null` au `LinearProgressIndicator` en
        // croyant le taire ; le framework CALCULE alors un pourcentage. Ce
        // test a rougi sur `['2/4', '50']` — deux annonces, deux unités.
        // Retirer l'`ExcludeSemantics` du widget le fait rougir à nouveau.
        final announcing = <String>[];
        void visit(SemanticsNode node) {
          if (node.value.isNotEmpty) announcing.add(node.value);
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(
          tester.getSemantics(
            find.byKey(ZSessionProgressIndicator.progressKey),
          ),
        );
        expect(announcing, <String>['2/4']);
        handle.dispose();
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PAIRE 1 — `ZSrsQualityEmphasis`
  // ══════════════════════════════════════════════════════════════════════════
  group('SUF-4 / paire 1 — affordance d\'emphase INJECTÉE (parité `_SrsButton`)',
      () {
    ZSrsQualityButtons buttons({
      ZSrsQualityEmphasis emphasis = ZSrsQualityEmphasis.none,
      int? selectedQuality,
    }) =>
        ZSrsQualityButtons(
          scale: ZQualityScale.fromConfig(
            const ZSrsConfig(minQuality: 1, maxQuality: 5),
          ),
          passThreshold: 3,
          onQualitySelected: (_) {},
          emphasis: emphasis,
          selectedQuality: selectedQuality,
        );

    testWidgets(
      '🔒 DÉFAUT = rendu HISTORIQUE : fond OPAQUE, AUCUN bord (zéro régression)',
      (tester) async {
        await _pumpScoped(tester, buttons(selectedQuality: 4));

        for (var quality = 1; quality <= 5; quality++) {
          final material = _qualityMaterialOf(tester, quality);
          // 🔴 MORDANT : appliquer un `withValues(alpha:)` « par défaut »
          // (même à 1.0) ou peindre un bord d'office ferait rougir CHAQUE cran
          // — c'est la régression silencieuse que craignent les appelants
          // existants (runtimes ES-4, démo su-10, bridges lex).
          expect(material.color!.a, 1.0, reason: 'cran $quality opaque');
          expect(_sideOf(material), BorderSide.none, reason: 'cran $quality');
        }
      },
    );

    testWidgets(
      '🔴 emphase INJECTÉE : le cran SÉLECTIONNÉ est plus soutenu ET plus '
      'bordé que les autres (les deux dimensions, pas une seule)',
      (tester) async {
        await _pumpScoped(
          tester,
          buttons(
            selectedQuality: 4,
            emphasis: const ZSrsQualityEmphasis(
              fillOpacity: 0.12,
              selectedFillOpacity: 0.24,
              borderWidth: 1,
              selectedBorderWidth: 2,
            ),
          ),
        );

        final selected = _qualityMaterialOf(tester, 4);
        final plain = _qualityMaterialOf(tester, 2);

        // 🔴 MORDANT : ignorer `selected` dans `opacityFor`/`borderWidthFor`
        // (le bug le plus probable : lire toujours la variante ordinaire)
        // ferait CONVERGER ces paires.
        expect(selected.color!.a, closeTo(0.24, 1e-3));
        expect(plain.color!.a, closeTo(0.12, 1e-3));
        expect(_sideOf(selected).width, 2);
        expect(_sideOf(plain).width, 1);

        // La couleur du bord reste celle RÉSOLUE par les seams — jamais une
        // teinte inventée par l'affordance (qui ne porte AUCUNE couleur).
        expect(_sideOf(plain).color, plain.color!.withValues(alpha: 1));
      },
    );

    testWidgets(
      '🔴 défensif (AD-10) : opacité hors [0,1] BORNÉE, épaisseur négative ⇒ '
      'aucun bord, NaN ignoré',
      (tester) async {
        await _pumpScoped(
          tester,
          buttons(
            selectedQuality: 4,
            emphasis: const ZSrsQualityEmphasis(
              fillOpacity: 5,
              selectedFillOpacity: -2,
              borderWidth: -1,
              selectedBorderWidth: double.nan,
            ),
          ),
        );

        // 🔴 MORDANT : propager telles quelles ⇒ `Color.withValues` asserte
        // (`0..1`) et `BorderSide(width: -1)` asserte : l'écran entier tombe.
        expect(tester.takeException(), isNull);
        expect(_qualityMaterialOf(tester, 2).color!.a, 1.0);
        expect(_qualityMaterialOf(tester, 4).color!.a, 0.0);
        expect(_sideOf(_qualityMaterialOf(tester, 2)), BorderSide.none);
        expect(_sideOf(_qualityMaterialOf(tester, 4)), BorderSide.none);
      },
    );

    testWidgets(
      '🔴 le canal NON-COLORÉ survit à l\'emphase (AD-13 : la couleur n\'est '
      'jamais le seul canal)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpScoped(
          tester,
          buttons(
            selectedQuality: 4,
            emphasis: const ZSrsQualityEmphasis(
              fillOpacity: 0.12,
              selectedFillOpacity: 0.24,
              borderWidth: 1,
              selectedBorderWidth: 2,
            ),
          ),
        );

        // 🔴 MORDANT : « fermer » l'écart en REMPLAÇANT la coche + le flag
        // a11y par une simple intensité de fond (ce que fait lex) rendrait le
        // cran suggéré indistinguable en niveaux de gris — régression AD-13.
        expect(
          find.descendant(
            of: find.byKey(
              ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}4'),
            ),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(
                find.byKey(
                  ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}4'),
                ),
              )
              .flagsCollection
              .isSelected,
          Tristate.isTrue,
        );
        handle.dispose();
      },
    );
  });

  // ══════════════════════════════════════════════════════════════════════════
  // PAIRE 2 — `ZQualityBreakdownCoverage`
  // ══════════════════════════════════════════════════════════════════════════
  group('SUF-4 / paire 2 — couverture de la répartition (parité lex)', () {
    final scale = ZQualityScale.fromConfig(
      const ZSrsConfig(minQuality: 1, maxQuality: 5),
    );
    // Cran 3 ABSENT (personne n'a répondu « Difficile ») + une clé HORS échelle.
    const byQuality = <String, int>{'1': 2, '2': 1, '4': 3, '5': 1, '9': 7};

    Finder segment(int quality) => find.byKey(
          ValueKey<String>(
            '${ZSessionQualityBreakdown.segmentKeyPrefix}$quality',
          ),
        );

    testWidgets(
      '🔒 DÉFAUT `presentKeysOnly` : le cran ABSENT n\'a PAS de pilule '
      '(comportement historique préservé)',
      (tester) async {
        await _pumpScoped(
          tester,
          ZSessionQualityBreakdown(
            byQuality: byQuality,
            scale: scale,
            passThreshold: 3,
          ),
        );
        expect(segment(1), findsOneWidget);
        // 🔴 MORDANT : basculer le défaut sur `wholeScale` ferait apparaître
        // cette pilule — régression pour tout appelant existant.
        expect(segment(3), findsNothing);
      },
    );

    testWidgets(
      '🔴 `wholeScale` : TOUS les crans de l\'échelle ont une pilule, l\'absent '
      'affichant 0 — longueur STABLE comme le natif lex',
      (tester) async {
        await _pumpScoped(
          tester,
          ZSessionQualityBreakdown(
            byQuality: byQuality,
            scale: scale,
            passThreshold: 3,
            coverage: ZQualityBreakdownCoverage.wholeScale,
          ),
        );

        for (final quality in scale.qualities) {
          // 🔴 MORDANT : laisser le filtre `containsKey` en place (le
          // paramètre déclaré mais non consommé) ferait rougir sur le cran 3.
          expect(segment(quality), findsOneWidget, reason: 'cran $quality');
        }
        // La VALEUR du cran absent est 0 — jamais un compte inventé, jamais
        // une clé fabriquée dans `byQuality`.
        expect(
          tester.getSemantics(segment(3)).value,
          '0',
        );
        expect(byQuality.containsKey('3'), isFalse,
            reason: 'la map d\'entrée n\'a pas été mutée');
      },
    );

    testWidgets(
      '🔴 `wholeScale` ne fusionne ni n\'invente : la clé HORS échelle reste '
      'rendue À PART (R6)',
      (tester) async {
        await _pumpScoped(
          tester,
          ZSessionQualityBreakdown(
            byQuality: byQuality,
            scale: scale,
            passThreshold: 3,
            coverage: ZQualityBreakdownCoverage.wholeScale,
          ),
        );
        // 🔴 MORDANT : une fermeture qui parcourrait `byQuality.keys` au lieu
        // de l'échelle aspirerait « 9 » dans la section in-scale.
        expect(
          find.byKey(
            const ValueKey<String>(
              '${ZSessionQualityBreakdown.unknownKeyPrefix}9',
            ),
          ),
          findsOneWidget,
        );
        expect(segment(9), findsNothing);
      },
    );

    testWidgets(
      '🔴 `ZSessionSummaryView` PROPAGE la couverture (sans quoi l\'écart '
      'resterait inatteignable depuis l\'écran de fin)',
      (tester) async {
        Widget summary(ZQualityBreakdownCoverage coverage) =>
            ZSessionSummaryView(
              result: const ZStudySessionResult(
                total: 7,
                correct: 4,
                byQuality: <String, int>{'1': 2, '2': 1, '4': 3, '5': 1},
              ),
              duration: const Duration(minutes: 2),
              config: const ZSrsConfig(minQuality: 1, maxQuality: 5),
              onFinish: () {},
              breakdownCoverage: coverage,
            );

        await _pumpScoped(
          tester,
          summary(ZQualityBreakdownCoverage.presentKeysOnly),
        );
        expect(segment(3), findsNothing);

        await _pumpScoped(
          tester,
          summary(ZQualityBreakdownCoverage.wholeScale),
        );
        // 🔴 MORDANT : oublier `coverage: widget.breakdownCoverage` dans le
        // `build` (paramètre déclaré, jamais transmis) laisserait ce cran
        // absent — le pass-through serait décoratif.
        expect(segment(3), findsOneWidget);
      },
    );
  });
}
