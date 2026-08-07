/// Lot K2 (chantier composer-lex) — **comportement** de la feuille complète
/// (T1) et des préréglages à mémoire (T2) sur `ZChatSettingsController`
/// (SET-F6 étendue par arbitrage owner du 2026-08-07).
///
/// Ce que ce fichier MESURE :
/// * **PR** — préréglages : appliquer puis retirer rend l'état EXACT d'avant —
///   et l'état d'avant DIFFÈRE de celui du préréglage (snapshot NON VACANT,
///   asserté avant la mesure) ; passer d'un préréglage à l'autre conserve la
///   sauvegarde du PREMIER ; `reset` révoque tout ;
/// * **CT** — le compteur F12 (`activeCount`) : axes + clés de portée, tranche
///   qui SIGNALE ;
/// * **UI** — l'en-tête (hôte passif inchangé sans `onClose`), la tuile de
///   préréglages, les filtres à DEUX niveaux, l'entrée désactivée (deux canaux
///   non chromatiques), l'échelle labellisée du budget, les tuiles génériques.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_render_harness.dart';

/// Clés et libellés FICTIFS — aucune valeur métier n'entre au socle.
const String _kAlpha = 'corpus-alpha';
const String _kA1 = 'corpus-alpha-un';
const String _kA2 = 'corpus-alpha-deux';

const List<ZChatCorpusOption> _catalogue2N = <ZChatCorpusOption>[
  ZChatCorpusOption(
    key: _kAlpha,
    label: 'Alpha',
    children: <ZChatCorpusOption>[
      ZChatCorpusOption(key: _kA1, label: 'Alpha-Un'),
      ZChatCorpusOption(key: _kA2, label: 'Alpha-Deux', enabled: false),
    ],
  ),
];

const ZChatSettingsPreset _expert = ZChatSettingsPreset(
  id: 'p1',
  label: 'Préréglage Un',
  settings: ZChatGenerationSettings(
    responseLength: ZChatResponseLength.detailed,
  ),
  corpusScope: null,
);

String fb(String key) => kZChatLabelFallbacks[key]!;

void main() {
  group('🔴 PR — préréglages À MÉMOIRE (le `preExpertToolsContext` de lex, '
      'généralisé)', () {
    test('PR-1 — appliquer puis retirer rend l\'état EXACT d\'avant (snapshot '
        'NON VACANT)', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.setResponseLength(ZChatResponseLength.concise);
      c.toggleCorpusKey(_kAlpha);
      final ZChatGenerationSettings before = c.settings.value;
      final ZChatCorpusScope? scopeBefore = c.corpusScope.value;
      // 🔴 NON-VACUITÉ du snapshot : l'état d'avant DIFFÈRE du préréglage —
      // sinon « restauré » et « resté sur le préréglage » seraient
      // indiscernables et la garde serait verte sur un `clearPreset` inerte.
      expect(before, isNot(_expert.settings));
      expect(scopeBefore, isNotNull);

      c.applyPreset(_expert.id, _expert.settings, _expert.corpusScope);
      expect(c.activePresetId.value, 'p1');
      expect(c.settings.value, _expert.settings);
      expect(c.corpusScope.value, isNull);

      c.clearPreset();
      expect(c.activePresetId.value, isNull);
      expect(c.settings.value, before,
          reason: '🔴 la restauration n\'est pas EXACTE — le contre-modèle '
              'IFFD (des « défauts » réinventés) est de retour');
      expect(c.corpusScope.value?.corpusKeys, scopeBefore?.corpusKeys);
    });

    test('PR-2 — passer d\'un préréglage à un autre CONSERVE la sauvegarde du '
        'premier', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.setLengthBias(ZChatLengthBias.shorter);
      final ZChatGenerationSettings before = c.settings.value;

      c.applyPreset('p1', _expert.settings, null);
      c.applyPreset(
        'p2',
        const ZChatGenerationSettings(
          responseLength: ZChatResponseLength.concise,
        ),
        null,
      );
      expect(c.activePresetId.value, 'p2');
      c.clearPreset();
      expect(c.settings.value, before,
          reason: '🔴 la sauvegarde a été ÉCRASÉE par le second préréglage : '
              'restaurer doit rendre l\'état d\'AVANT LE PREMIER (lex '
              '`chat_input_controller.dart:333-341`, `copyWith` non destructif)');
    });

    test('PR-3 — `reset` révoque le préréglage ; `clearPreset` sans préréglage '
        'est un no-op', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.applyPreset('p1', _expert.settings, null);
      c.reset();
      expect(c.activePresetId.value, isNull,
          reason: '🔴 un préréglage encore affiché après reset MENT');
      expect(c.settings.value, const ZChatGenerationSettings());

      c.setResponseLength(ZChatResponseLength.concise);
      c.clearPreset(); // aucun préréglage actif
      expect(c.settings.value.responseLength, ZChatResponseLength.concise,
          reason: '🔴 `clearPreset` sans préréglage a touché l\'état');
    });
  });

  group('🔴 CT — le compteur F12 (`activeCount`)', () {
    test('axes non-défaut + clés de portée, et la tranche SIGNALE', () {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      expect(c.activeCount.value, 0);
      int signals = 0;
      c.activeCount.addListener(() => signals++);

      c.setResponseLength(ZChatResponseLength.concise);
      expect(c.activeCount.value, 1);
      c.setComputeEffort(ZChatComputeEffort(3));
      expect(c.activeCount.value, 2);
      c.toggleCorpusKey(_kAlpha);
      c.toggleCorpusKey(_kA1);
      expect(c.activeCount.value, 4,
          reason: '🔴 les clés de portée ne comptent pas — le badge lex/IFFD '
              'ne saurait pas se rendre');
      expect(signals, greaterThanOrEqualTo(3),
          reason: '🔴 la tranche ne signale pas : le badge resterait figé');

      c.reset();
      expect(c.activeCount.value, 0);
    });
  });

  group('🔴 UI — la feuille complète (T1)', () {
    testWidgets('UI-H1 — SANS `onClose` ni builder : AUCUN en-tête (hôte '
        'passif inchangé)', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(ZChatSettingsSheet(controller: c)));
      expect(find.text(fb(kZChatLabelSettingsReset)), findsNothing,
          reason: '🔴 un en-tête est apparu chez un hôte PASSIF : son rendu '
              'd\'avant le lot a changé sans geste de sa part (CR-LEX-78 / '
              'règle des handoffs)');
      expect(find.text(fb(kZChatLabelSettingsClose)), findsNothing);
    });

    testWidgets('UI-H2 — avec `onClose` : titre + réinitialiser + fermer, et '
        'les deux gestes AGISSENT', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      c.setResponseLength(ZChatResponseLength.concise);
      int closed = 0;
      await tester.pumpWidget(
        harness(
          ZChatSettingsSheet(controller: c, onClose: () => closed++),
        ),
      );
      expect(find.text(fb(kZChatLabelSettings)), findsWidgets);

      await tester.tap(find.text(fb(kZChatLabelSettingsReset)));
      expect(c.settings.value, const ZChatGenerationSettings(),
          reason: '🔴 « Réinitialiser » n\'appelle pas `reset()`');

      await tester.tap(find.text(fb(kZChatLabelSettingsClose)));
      expect(closed, 1, reason: '🔴 « Fermer » n\'appelle pas `onClose`');

      // Cibles ≥ 48 dp en géométrie RENDUE.
      final Size reset = tester.getSize(
        find.ancestor(
          of: find.text(fb(kZChatLabelSettingsReset)),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(reset.height, greaterThanOrEqualTo(48));
    });

    testWidgets('UI-P1 — la tuile de préréglages : absente sans catalogue, '
        'appliquer/retirer par tap', (WidgetTester tester) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(harness(ZChatSettingsSheet(controller: c)));
      expect(find.text(fb(kZChatLabelPresets)), findsNothing,
          reason: '🔴 une tuile de préréglages SANS catalogue laisse croire '
              'que le socle en propose (AD-4)');

      c.setLengthBias(ZChatLengthBias.shorter);
      final ZChatGenerationSettings before = c.settings.value;
      await tester.pumpWidget(
        harness(
          ZChatSettingsSheet(
            controller: c,
            presetCatalog: const <ZChatSettingsPreset>[_expert],
          ),
        ),
      );
      await tester.tap(find.text('Préréglage Un'));
      await tester.pump();
      expect(c.activePresetId.value, 'p1');
      expect(c.settings.value, _expert.settings);

      await tester.tap(find.text(fb(kZChatLabelPresetNone)));
      await tester.pump();
      expect(c.activePresetId.value, isNull);
      expect(c.settings.value, before,
          reason: '🔴 « Aucun » ne restitue pas l\'état d\'avant');
    });

    testWidgets('UI-C1 — filtres à DEUX niveaux : les enfants n\'apparaissent '
        'que parent SÉLECTIONNÉ ; le retrait du parent emporte ses clés', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: ZChatSettingsSheet(controller: c, corpusCatalog: _catalogue2N),
          ),
        ),
      );
      expect(find.text('Alpha-Un'), findsNothing,
          reason: '🔴 le second niveau est visible AVANT la sélection du '
              'parent — lex ne montre ses filtres que switch actif');

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(find.text('Alpha-Un'), findsOneWidget);

      await tester.tap(find.text('Alpha-Un'));
      await tester.pump();
      expect(c.selectsCorpusKey(_kA1), isTrue);

      // Désélectionner le parent retire AUSSI la clé d'enfant.
      await tester.tap(find.text('Alpha'));
      await tester.pump();
      expect(c.corpusScope.value, isNull,
          reason: '🔴 une clé d\'enfant ORPHELINE reste dans la portée après '
              'le retrait de sa famille');
    });

    testWidgets('UI-C2 — une entrée `enabled: false` : PAS de geste, sémantique '
        'désactivée, canal visible NON chromatique', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: ZChatSettingsSheet(controller: c, corpusCatalog: _catalogue2N),
          ),
        ),
      );
      await tester.tap(find.text('Alpha'));
      await tester.pump();

      await tester.tap(find.text('Alpha-Deux'), warnIfMissed: false);
      await tester.pump();
      expect(c.selectsCorpusKey(_kA2), isFalse,
          reason: '🔴 une entrée non indexée a été SÉLECTIONNÉE');
      final Text disabled = tester.widget<Text>(find.text('Alpha-Deux'));
      expect(disabled.style?.fontStyle, FontStyle.italic,
          reason: '🔴 l\'indisponibilité n\'a AUCUN canal visible — chez lex '
              'c\'est un alpha 0.38, une information portée par la seule '
              'couleur (le défaut CR-74)');
    });

    testWidgets('UI-B1 — l\'échelle du budget est LABELLISÉE (Rapide / '
        'Équilibré / Profond), hors arbre sémantique', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController c = ZChatSettingsController();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(child: ZChatSettingsSheet(controller: c)),
        ),
      );
      for (final String key in <String>[
        kZChatLabelComputeBudgetFast,
        kZChatLabelComputeBudgetBalanced,
        kZChatLabelComputeBudgetDeep,
      ]) {
        expect(find.text(fb(key)), findsOneWidget,
            reason: '🔴 repère absent : $key — le « slider labellisé » de lex '
                '(`tools_sheet.dart:322-392`) n\'est pas porté');
      }
    });

    testWidgets('UI-G1 — tuiles GÉNÉRIQUES : échelle discrète et capacités '
        'booléennes, avec l\'emphase CR-74', (WidgetTester tester) async {
      String? level;
      final Set<String> caps = <String>{'web'};
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              ZChatSettingsScaleTile(
                label: 'Niveau',
                options: const <ZChatSettingsHostOption>[
                  ZChatSettingsHostOption(key: 'l1', label: 'Novice'),
                  ZChatSettingsHostOption(key: 'l2', label: 'Expert'),
                ],
                selectedKey: 'l1',
                onSelect: (String k) => level = k,
              ),
              ZChatSettingsCapabilityTile(
                label: 'Capacités',
                options: const <ZChatSettingsHostOption>[
                  ZChatSettingsHostOption(key: 'web', label: 'Recherche web'),
                ],
                selectedKeys: caps,
                onToggle: caps.contains,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('Expert'));
      expect(level, 'l2', reason: '🔴 le choix ne remonte pas à l\'hôte');

      // 🔴 CR-74 : l'état choisi a ses DEUX canaux visibles sur la tuile
      // générique aussi — même primitive, même correctif.
      final Text chosen = tester.widget<Text>(find.text('Novice'));
      expect(chosen.style?.fontWeight, FontWeight.w700);
      expect(
        chosen.style?.decoration.toString(),
        contains('underline'),
      );
      final Text webChip = tester.widget<Text>(find.text('Recherche web'));
      expect(webChip.style?.fontWeight, FontWeight.w700,
          reason: '🔴 une capacité ACTIVE n\'est pas emphasée : l\'état ne '
              'serait porté par rien de visible');
    });
  });
}
