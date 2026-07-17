// Contraste ≥ 4,5:1 (WCAG AA) sur TOUT ce que su-8 peint (SU-8/AC20 — AD-13).
//
// ## Pourquoi CRÉÉE ici (extension de couverture, pas duplication)
//
// La garde de contraste de su-6 vit dans
// `zcrud_session/test/presentation/z_session_mode_selector_test.dart:1502+` et
// **énumère les ÉCRANS de zcrud_session**. `zcrud_session` **ne dépend PAS** de
// `zcrud_study` ⇒ su-8 ne peut **structurellement pas** s'y ajouter. Le helper de
// mesure est **identique** (même formule WCAG 2.x, même remontée du fond
// réellement peint) ; seuls les écrans énumérés changent.
//
// 🔴 « **Un écran non listé n'est JAMAIS mesuré** » — su-6 avait omis un dialog
// entier : 4 tuiles non gardées, **4/4 défectueuses**. La liste ci-dessous est
// donc exhaustive sur le diff de su-8, et chaque écran est monté sous
// **`Brightness.values`** (clair ET sombre — un contraste juste en clair peut
// être catastrophique en sombre).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Champ de recherche',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',  readOnlyBadge: 'Lecture seule',
);

ZFlashcard _card(String id, {bool isReadOnly = false}) => ZFlashcard(
      id: id,
      question: 'Question $id',
      answer: 'Réponse $id',
      isReadOnly: isReadOnly,
      tagIds: const <String>['tag'],
      source: ZCustomSource('pdf', const <String, dynamic>{}),
    );

void main() {
  group('🔴 AC20 — contraste ≥ 4,5:1 (WCAG AA) sur TOUT ce qui est peint', () {
    /// Luminance relative WCAG 2.x d'une couleur **opaque**.
    double luminance(Color c) {
      double channel(double v) => v <= 0.03928
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    /// Ratio de contraste WCAG entre deux couleurs opaques (1:1 … 21:1).
    double contrast(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    /// Fond **réellement peint** derrière [e] : le premier ancêtre opaque.
    /// `null` si rien n'est peint (le test échoue alors bruyamment plutôt que
    /// de sauter la mesure — un puits « sauté » est un puits non gardé).
    Color? paintedBackgroundOf(Element e) {
      Color? found;
      e.visitAncestorElements((ancestor) {
        final w = ancestor.widget;
        if (w is DecoratedBox) {
          final d = w.decoration;
          if (d is BoxDecoration && d.color != null && d.color!.a == 1.0) {
            found = d.color;
            return false;
          }
        } else if (w is ColoredBox && w.color.a == 1.0) {
          found = w.color;
          return false;
        } else if (w is Material && w.color != null && w.color!.a == 1.0) {
          found = w.color;
          return false;
        }
        return true;
      });
      return found;
    }

    /// Mesure CHAQUE `RichText` peint et exige ≥ 4,5:1.
    void assertAllContrasts(WidgetTester tester, String screen) {
      final targets = find.byType(RichText).evaluate();
      expect(targets, isNotEmpty,
          reason: '🔴 $screen : aucun RichText peint — la garde ne mesurerait '
              'RIEN et resterait verte. Sonde cassée.');

      for (final element in targets) {
        final paragraph = element.renderObject! as RenderParagraph;
        final text = paragraph.text.toPlainText();
        final foreground = paragraph.text.style?.color;
        expect(foreground, isNotNull,
            reason: '🔴 $screen : « $text » n\'a AUCUNE couleur de premier plan '
                'fusionnée — impossible de mesurer un contraste.');

        final background = paintedBackgroundOf(element);
        expect(background, isNotNull,
            reason: '🔴 $screen : « $text » n\'a AUCUN fond opaque derrière lui '
                '— impossible de garantir sa lisibilité.');

        final ratio = contrast(foreground!, background!);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '🔴 $screen : « $text » est peint à '
              '${ratio.toStringAsFixed(2)}:1 — WCAG AA exige 4,5:1.\n'
              '  premier plan : $foreground\n'
              '  fond         : $background\n'
              'Cause quasi certaine : un rôle de FOND (`surfaceContainerHighest`) '
              'utilisé en PREMIER PLAN. Le rôle apparié est `onSurfaceVariant` '
              '(patron `z_flashcard_list_view.dart` › `_FlashcardTile.build`).',
        );
      }
    }

    /// 🔴 **TOUS** les écrans de su-8 — ÉNUMÉRÉS. Ajouter un écran ici est le
    /// seul geste nécessaire pour l'y soumettre ; un écran ABSENT de cette table
    /// n'est **JAMAIS** mesuré (su-6 : un dialog oublié = 4 tuiles défectueuses).
    final screens = <String, Widget>{
      'ZFlashcardListView (grille + tuiles)': ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2')],
        labels: _labels,
        onOpen: (_) {},
        onEdit: (_) {},
        onDelete: (_) {},
        onDuplicate: (_) {},
      ),
      'ZFlashcardListView (carte en LECTURE SEULE)': ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1', isReadOnly: true)],
        labels: _labels,
        onDuplicate: (_) {},
      ),
      'ZFlashcardListView (état VIDE)': const ZFlashcardListView(
        cards: <ZFlashcard>[],
        labels: _labels,
      ),
      'ZFlashcardListView (aucun RÉSULTAT)': ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1')],
        labels: _labels,
        filters: const ZFlashcardBrowseFilters(query: 'introuvable-zzz'),
      ),
      'ZFlashcardListView (mode MANUEL, réordonnable)': ZFlashcardListView(
        cards: <ZFlashcard>[_card('c1'), _card('c2')],
        labels: _labels,
        sortMode: ZFlashcardSortMode.manual,
        order: const ZFolderContentsOrder(folderId: 'f'),
        onOrderChanged: (_) {},
      ),
      'ZFlashcardPreview (aperçu lecture seule)': ZFlashcardPreview(
        card: _card('c1', isReadOnly: true),
      ),
      'ZFlashcardPreview (aperçu éditable)': ZFlashcardPreview(
        card: _card('c1'),
        onEdit: () {},
        onDelete: () {},
      ),
    };

    for (final entry in screens.entries) {
      // 🔴 Clair ET sombre : un contraste juste en clair peut être illisible en
      // sombre (le fond change, le premier plan pas toujours).
      for (final brightness in Brightness.values) {
        testWidgets('${entry.key} — ${brightness.name}', (tester) async {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SizedBox(width: 1000, height: 700, child: entry.value),
            ),
          ));
          await tester.pump();

          assertAllContrasts(tester, '${entry.key} [${brightness.name}]');
        });
      }
    }

    // 🔴 Le menu est un OVERLAY : il n'existe qu'une fois OUVERT. Les écrans
    // ci-dessus ne le couvrent donc PAS — c'est exactement le trou de su-6 (un
    // dialog entier oublié ⇒ 4 tuiles non gardées, 4/4 défectueuses).
    //
    // ⚠️ UN test PAR luminosité (jamais une boucle dans un seul `testWidgets`) :
    // l'overlay de la 1ʳᵉ itération reste monté et MASQUE le déclencheur de la
    // seconde — le `tap` échouerait sur un widget obscurci, et la 2ᵉ luminosité
    // ne serait jamais mesurée. (Constaté en l'écrivant : le test rougissait
    // pour cette raison, pas pour un défaut de contraste.)
    for (final brightness in Brightness.values) {
      testWidgets(
          '🔴 le MENU d\'actions ouvert est mesuré — ${brightness.name} '
          '(su-6 : dialog oublié)', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              height: 700,
              child: ZFlashcardListView(
                cards: <ZFlashcard>[_card('c1')],
                labels: _labels,
                onOpen: (_) {},
                onEdit: (_) {},
                onDelete: (_) {},
                onDuplicate: (_) {},
              ),
            ),
          ),
        ));
        await tester.pump();

        await tester.tap(find.byType(ZItemActionsMenu).first);
        await tester.pumpAndSettle();

        expect(find.text('Dupliquer'), findsOneWidget,
            reason: 'sonde : le menu doit être RÉELLEMENT ouvert, sinon la '
                'mesure porterait sur la liste et non sur le menu');
        assertAllContrasts(
            tester, 'ZItemActionsMenu ouvert [${brightness.name}]');
      });
    }
  });
}
