/// Jetons de FORME de la surface de saisie notée — maillon JETON de la chaîne
/// `paramètre > jeton > référence`.
///
/// Avant ce lot, la surface n'avait AUCUN seam de forme (mesuré :
/// `grep -c "choiceLayout\|actionsLayout\|submitWidth\|gradingVisibility"` sur
/// `z_flashcard_answer_input.dart` → 0), et la seule voie pour changer la forme
/// de trois boutons était de réimplémenter la surface entière.
///
/// Cette suite vérifie ce que la garde structurelle des « 4 sites »
/// (`z_theme_four_sites_guard_test.dart`) ne PEUT PAS voir : elle lit la
/// SOURCE (le jeton est-il cité aux quatre endroits ?), jamais le
/// COMPORTEMENT. Un `copyWith` qui citerait le jeton en écrivant
/// `x: this.x` la laisserait verte.
///
/// Quatre propriétés sont donc assertées :
/// * **défaut `null`** — sinon « posé au défaut » et « non posé » deviennent
///   indistinguables et la chaîne à trois maillons est INEXPRIMABLE ;
/// * **transport** — `copyWith` porte l'argument reçu ET ne perd pas
///   l'existant quand aucun argument n'est donné ;
/// * **nature DISCRÈTE** — une disposition, une largeur et un régime de gestes
///   ne s'interpolent pas : `lerp` les fait BASCULER (aucune valeur
///   intermédiaire, qu'aucun des deux thèmes ne décrit) ;
/// * **null-préservation** — `null` ↔ `null` reste `null`, sans quoi la
///   première transition de thème GÈLERAIT la valeur de référence de la
///   surface, qui cesserait d'être une référence.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Thème PLEIN : les quatre jetons posés à leur valeur NON-référence.
const ZcrudTheme _plein = ZcrudTheme(
  answerInputChoiceLayout: ZAnswerChoiceLayout.tile,
  answerInputActionsLayout: ZAnswerActionsLayout.sideBySide,
  answerInputSubmitWidth: ZAnswerSubmitWidth.full,
  answerInputGradingVisibility: ZAnswerGradingVisibility.always,
);

void main() {
  group('les quatre jetons `answerInput*` — défauts', () {
    test('ils sont `null` par défaut', () {
      const ZcrudTheme t = ZcrudTheme();
      expect(t.answerInputChoiceLayout, isNull);
      expect(t.answerInputActionsLayout, isNull);
      expect(t.answerInputSubmitWidth, isNull);
      expect(t.answerInputGradingVisibility, isNull);
    });

    test('le repli dérivé (`fallback`) ne les matérialise pas', () {
      // Un défaut matérialisé ici PRIMERAIT sur la référence de la surface
      // sans que personne ne l'ait demandé — et rendrait le maillon « jeton »
      // toujours gagnant, donc la référence inatteignable.
      final ZcrudTheme t = ZcrudTheme.fallback(ThemeData());
      expect(t.answerInputChoiceLayout, isNull);
      expect(t.answerInputActionsLayout, isNull);
      expect(t.answerInputSubmitWidth, isNull);
      expect(t.answerInputGradingVisibility, isNull);
    });
  });

  group('`copyWith` — transport ET préservation', () {
    test('chaque argument reçu est PORTÉ', () {
      const ZcrudTheme vide = ZcrudTheme();
      expect(
        vide
            .copyWith(answerInputChoiceLayout: ZAnswerChoiceLayout.tile)
            .answerInputChoiceLayout,
        ZAnswerChoiceLayout.tile,
      );
      expect(
        vide
            .copyWith(answerInputActionsLayout: ZAnswerActionsLayout.sideBySide)
            .answerInputActionsLayout,
        ZAnswerActionsLayout.sideBySide,
      );
      expect(
        vide
            .copyWith(answerInputSubmitWidth: ZAnswerSubmitWidth.full)
            .answerInputSubmitWidth,
        ZAnswerSubmitWidth.full,
      );
      expect(
        vide
            .copyWith(
              answerInputGradingVisibility: ZAnswerGradingVisibility.always,
            )
            .answerInputGradingVisibility,
        ZAnswerGradingVisibility.always,
      );
    });

    test('un `copyWith` SANS argument ne perd rien', () {
      final ZcrudTheme t = _plein.copyWith();
      expect(t.answerInputChoiceLayout, ZAnswerChoiceLayout.tile);
      expect(t.answerInputActionsLayout, ZAnswerActionsLayout.sideBySide);
      expect(t.answerInputSubmitWidth, ZAnswerSubmitWidth.full);
      expect(t.answerInputGradingVisibility, ZAnswerGradingVisibility.always);
    });
  });

  group('`lerp` — DISCRET et null-préservant', () {
    test('la bascule est nette : aucune valeur intermédiaire', () {
      const ZcrudTheme vide = ZcrudTheme();
      final ZcrudTheme avant = vide.lerp(_plein, 0.49);
      final ZcrudTheme apres = vide.lerp(_plein, 0.51);

      expect(avant.answerInputChoiceLayout, isNull);
      expect(avant.answerInputActionsLayout, isNull);
      expect(avant.answerInputSubmitWidth, isNull);
      expect(avant.answerInputGradingVisibility, isNull);

      expect(apres.answerInputChoiceLayout, ZAnswerChoiceLayout.tile);
      expect(apres.answerInputActionsLayout, ZAnswerActionsLayout.sideBySide);
      expect(apres.answerInputSubmitWidth, ZAnswerSubmitWidth.full);
      expect(
        apres.answerInputGradingVisibility,
        ZAnswerGradingVisibility.always,
      );
    });

    test('`null` ↔ `null` reste `null` à toute étape', () {
      const ZcrudTheme vide = ZcrudTheme();
      for (final double t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        final ZcrudTheme r = vide.lerp(const ZcrudTheme(), t);
        expect(r.answerInputChoiceLayout, isNull, reason: 't=$t');
        expect(r.answerInputActionsLayout, isNull, reason: 't=$t');
        expect(r.answerInputSubmitWidth, isNull, reason: 't=$t');
        expect(r.answerInputGradingVisibility, isNull, reason: 't=$t');
      }
    });
  });

  group('les énumérations de forme', () {
    test('la PREMIÈRE valeur de chacune est le rendu de RÉFÉRENCE', () {
      // La surface applique la référence quand paramètre ET jeton sont nuls.
      // Si la référence cessait d'être la première valeur, une relecture
      // rapide de l'énumération enseignerait le mauvais défaut.
      expect(ZAnswerChoiceLayout.values.first, ZAnswerChoiceLayout.compact);
      expect(ZAnswerActionsLayout.values.first, ZAnswerActionsLayout.stacked);
      expect(ZAnswerSubmitWidth.values.first, ZAnswerSubmitWidth.content);
      expect(
        ZAnswerGradingVisibility.values.first,
        ZAnswerGradingVisibility.afterSubmit,
      );
    });

    test('chacune est BINAIRE — deux valeurs, pas trois', () {
      expect(ZAnswerChoiceLayout.values, hasLength(2));
      expect(ZAnswerActionsLayout.values, hasLength(2));
      expect(ZAnswerSubmitWidth.values, hasLength(2));
      expect(ZAnswerGradingVisibility.values, hasLength(2));
    });
  });
}
