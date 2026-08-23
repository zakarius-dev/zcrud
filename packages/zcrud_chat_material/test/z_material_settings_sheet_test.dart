/// Gardes de la **feuille de réglages Material** — les huit builders des
/// familles standard et leur assemblage par défaut.
///
/// * **SET-M1** — les NEUF créneaux sont rendus par un widget Material ;
/// * **SET-M2** — le sous-titre d'état vient de l'hôte (absent ⇒ aucun) ;
/// * **SET-M3** — la puce « tous » n'existe que nommée par l'hôte ;
/// * **SET-M4** — une entrée indisponible est RENDUE, grisée, avec sa raison ;
/// * **SET-M5** — le builder de l'hôte GAGNE sur le défaut Material ;
/// * **SET-M6** — AD-2 : changer la verbosité ne reconstruit pas le corpus ;
/// * **SET-M7** — chaque geste écrit par le contrôleur (voie unique) ;
/// * **SET-M8** — sections : titre hiérarchisé teinté `primary`, séparateur
///   ENTRE deux sections ;
/// * **SET-M9** — AD-13 : toute cible ≥ 48 dp sous un hôte hostile ;
/// * **SET-M10** — garde de source : aucun `ZChatTool*` dans les builders
///   standard, aucun `IconTheme.merge` ;
/// * **SET-M11** — le montage n'écrit rien ;
/// * **SET-M12** — un hôte PASSIF obtient la feuille riche ;
/// * **SET-M13** — l'en-tête est gaté sur `onClose` ; « réinitialiser » vide ;
/// * **SET-M14** — une entrée d'hôte d'une section du socle survit (AD-10).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

/// Un kind que personne ne sait rendre.
class _HostControl implements ZChatSettingsControl {
  const _HostControl();
  @override
  String get kind => 'host.mystery';
}

const List<ZChatCorpusOption> _corpus = <ZChatCorpusOption>[
  ZChatCorpusOption(key: 'gatt', label: 'Code du GATT'),
  ZChatCorpusOption(key: 'tec', label: 'TEC CEDEAO', enabled: false),
  ZChatCorpusOption(
    key: 'cdn',
    label: 'Codes des douanes',
    children: <ZChatCorpusOption>[
      ZChatCorpusOption(key: 'cdn.togo', label: 'Togo'),
      ZChatCorpusOption(key: 'cdn.niger', label: 'Niger'),
    ],
  ),
];

const List<ZChatSettingsPreset> _presets = <ZChatSettingsPreset>[
  ZChatSettingsPreset(
    id: 'fast',
    label: 'Rapide',
    settings: ZChatGenerationSettings(
      responseLength: ZChatResponseLength.concise,
    ),
  ),
];

const List<ZChatSettingsHostOption> _capabilities = <ZChatSettingsHostOption>[
  ZChatSettingsHostOption(key: 'ocr', label: 'Lecture de documents'),
  ZChatSettingsHostOption(key: 'voice', label: 'Voix', enabled: false),
];

const ZChatSettingsEntry _unknownEntry = ZChatSettingsEntry(
  id: 'host.x',
  title: ZChatSettingsLabel.text('Mystère'),
  subtitle: ZChatSettingsLabel.text('Sans rendu'),
  control: _HostControl(),
);

String? _reason(String key) => switch (key) {
      'tec' => 'Corpus en cours d\'indexation',
      'voice' => 'Micro indisponible',
      _ => null,
    };

const ZChatMaterialSettingsLabels _fullLabels = ZChatMaterialSettingsLabels(
  all: 'Tous',
  revealThinkingStateOf: _thinkingState,
  capabilityStateOf: _capabilityState,
  reasonOf: _reason,
);

String _thinkingState(bool? v) => 'Niveau : ${v ?? 'auto'}';
String _capabilityState(String key, bool on) => '$key=${on ? 'on' : 'off'}';

Future<void> _pump(
  WidgetTester tester,
  ZChatSettingsController settings, {
  ZChatMaterialSettingsLabels labels = _fullLabels,
  VoidCallback? onClose,
  List<ZChatSettingsSection> sections = const <ZChatSettingsSection>[],
  List<ZChatSettingsEntry> entries = const <ZChatSettingsEntry>[],
  ZChatSettingsTileBuilder? responseLengthBuilder,
  ZChatSettingsTileBuilder? headerBuilder,
  ThemeData? material,
}) =>
    tester.pumpWidget(
      harness(
        SingleChildScrollView(
          child: ZChatMaterialSettingsSheet(
            controller: settings,
            labels: labels,
            onClose: onClose,
            corpusCatalog: _corpus,
            presetCatalog: _presets,
            capabilityCatalog: _capabilities,
            sections: sections,
            entries: entries,
            responseLengthBuilder: responseLengthBuilder,
            headerBuilder: headerBuilder,
          ),
        ),
        material: material,
      ),
    );

ZChatSettingsController _settings() {
  final ZChatSettingsController s = ZChatSettingsController();
  addTearDown(s.dispose);
  return s;
}

/// Un tap qui ATTEINT sa cible : la feuille est plus haute que l'écran du
/// testeur, une cible hors champ serait « tapée » dans le vide.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// `true` si un élément du sous-arbre de [root] est marqué à reconstruire.
bool _anyDirty(Element root) {
  bool dirty = root.dirty;
  root.visitChildren((Element child) {
    if (!dirty && _anyDirty(child)) dirty = true;
  });
  return dirty;
}

Finder _chip(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(FilterChip));

Finder _choice(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip));

Finder _switch(String title) => find.ancestor(
      of: find.text(title),
      matching: find.byType(SwitchListTile),
    );

void main() {
  testWidgets('🔴 SET-M1 — les NEUF créneaux sont rendus en Material', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController s = _settings();
    await _pump(tester, s, onClose: () {}, entries: <ZChatSettingsEntry>[
      _unknownEntry,
    ]);
    expect(tester.takeException(), isNull);
    for (final Type type in <Type>[
      ZChatMaterialSettingsHeader,
      ZChatMaterialPresetChips,
      ZChatMaterialResponseLengthChips,
      ZChatMaterialLengthBiasChips,
      ZChatMaterialBudgetSlider,
      ZChatMaterialRevealThinkingTile,
      ZChatMaterialCapabilityTiles,
      ZChatMaterialCorpusChips,
      ZChatMaterialUnknownEntryTile,
    ]) {
      expect(find.byType(type), findsOneWidget,
          reason: '🔴 la famille $type n\'est pas rendue par son builder');
    }
    // Le repli d'entrée inconnue rend le titre ET le sous-titre, inertes.
    expect(find.text('Mystère'), findsOneWidget);
    expect(find.text('Sans rendu'), findsOneWidget);
  });

  group('🔴 SET-M2 — le sous-titre d\'état vient de l\'hôte', () {
    testWidgets('fourni ⇒ rendu, et il SUIT l\'état', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      expect(find.text('Niveau : auto'), findsOneWidget);
      expect(find.text('web_search=off'), findsOneWidget);
      s.setRevealThinkingSteps(true);
      await tester.pump();
      expect(find.text('Niveau : true'), findsOneWidget);
    });

    testWidgets('absent ⇒ AUCUN sous-titre (jamais un texte du socle)', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s, labels: const ZChatMaterialSettingsLabels());
      for (final Element e in find.byType(SwitchListTile).evaluate()) {
        expect((e.widget as SwitchListTile).subtitle, isNull,
            reason: '🔴 un sous-titre est rendu sans canal d\'hôte');
      }
      expect(find.byType(SwitchListTile), findsNWidgets(4));
    });
  });

  group('🔴 SET-M3 — la puce « tous »', () {
    testWidgets('nommée ⇒ rendue, et son tap remet la portée à null', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      s.toggleCorpusKey('gatt');
      await _pump(tester, s);
      expect(_chip('Tous'), findsOneWidget);
      await _tap(tester, _chip('Tous'));
      expect(s.corpusScope.value, isNull,
          reason: '🔴 « tous » n\'a pas remis la portée à null');
    });

    testWidgets('non nommée ⇒ ABSENTE', (WidgetTester tester) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s, labels: const ZChatMaterialSettingsLabels());
      expect(find.byType(ZChatMaterialCorpusChips), findsOneWidget);
      expect(_chip('Tous'), findsNothing,
          reason: '🔴 une puce « tous » rendue sans libellé d\'hôte');
      expect(find.byType(FilterChip), findsNWidgets(_corpus.length));
    });
  });

  group('🔴 SET-M4 — une entrée indisponible est RENDUE, grisée, avec sa '
      'raison', () {
    testWidgets('corpus : puce présente, inerte, raison en tooltip', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      final FilterChip chip = tester.widget<FilterChip>(_chip('TEC CEDEAO'));
      expect(chip.onSelected, isNull, reason: '🔴 puce indisponible active');
      expect(
        find.ancestor(
          of: _chip('TEC CEDEAO'),
          matching: find.byWidgetPredicate(
            (Widget w) =>
                w is Tooltip && w.message == 'Corpus en cours d\'indexation',
          ),
        ),
        findsOneWidget,
        reason: '🔴 la raison de l\'hôte n\'est pas portée',
      );
      await tester.ensureVisible(_chip('TEC CEDEAO'));
      await tester.pump();
      await tester.tap(_chip('TEC CEDEAO'), warnIfMissed: false);
      await tester.pump();
      expect(s.corpusScope.value, isNull);
    });

    testWidgets('capacité : bascule présente, inerte, raison en sous-titre', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      final SwitchListTile tile = tester.widget<SwitchListTile>(_switch('Voix'));
      expect(tile.onChanged, isNull);
      expect(find.text('Micro indisponible'), findsOneWidget);
    });
  });

  group('🔴 SET-M5 — le builder de l\'hôte GAGNE sur le défaut Material', () {
    testWidgets('une famille', (WidgetTester tester) async {
      final ZChatSettingsController s = _settings();
      await _pump(
        tester,
        s,
        responseLengthBuilder: (BuildContext _, ZChatSettingsSlot _) =>
            const Text('HOST-LENGTH'),
      );
      expect(find.text('HOST-LENGTH'), findsOneWidget);
      expect(find.byType(ZChatMaterialResponseLengthChips), findsNothing,
          reason: '🔴 le défaut Material est rendu malgré le builder d\'hôte');
      // Les autres familles gardent leur défaut Material.
      expect(find.byType(ZChatMaterialLengthBiasChips), findsOneWidget);
    });

    testWidgets('l\'en-tête', (WidgetTester tester) async {
      final ZChatSettingsController s = _settings();
      await _pump(
        tester,
        s,
        onClose: () {},
        headerBuilder: (BuildContext _, ZChatSettingsSlot _) =>
            const Text('HOST-HEADER'),
      );
      expect(find.text('HOST-HEADER'), findsOneWidget);
      expect(find.byType(ZChatMaterialSettingsHeader), findsNothing);
    });
  });

  testWidgets('🔴 SET-M6 — AD-2 : changer la verbosité ne reconstruit pas le '
      'corpus', (WidgetTester tester) async {
    final ZChatSettingsController s = _settings();
    await tester.pumpWidget(
      harness(
        Column(
          children: <Widget>[
            ZChatMaterialResponseLengthChips(controller: s),
            ZChatMaterialCorpusChips(controller: s, catalog: _corpus),
          ],
        ),
      ),
    );
    s.setResponseLength(ZChatResponseLength.concise);
    // SANS pump : on lit ce qui a été MARQUÉ à reconstruire — dans TOUT le
    // sous-arbre de chaque tuile, pas seulement à sa racine.
    final Element length =
        tester.element(find.byType(ZChatMaterialResponseLengthChips));
    final Element corpus = tester.element(find.byType(ZChatMaterialCorpusChips));
    expect(_anyDirty(length), isTrue, reason: '🔴 contrôle positif');
    expect(_anyDirty(corpus), isFalse,
        reason: '🔴 le corpus écoute la tranche des réglages');
    await tester.pump();
  });

  group('🔴 SET-M7 — chaque geste écrit par le contrôleur', () {
    testWidgets('verbosité et biais', (WidgetTester tester) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      await _tap(tester, _choice('Concise'));
      expect(s.settings.value.responseLength, ZChatResponseLength.concise);
      await _tap(tester, _choice('Plus long'));
      expect(s.settings.value.lengthBias, ZChatLengthBias.longer);
      // Le chip choisi porte le rôle `primaryContainer`.
      final ChoiceChip chosen = tester.widget<ChoiceChip>(_choice('Concise'));
      expect(chosen.selected, isTrue);
      expect(
        chosen.selectedColor,
        Theme.of(tester.element(_choice('Concise'))).colorScheme.primaryContainer,
      );
    });

    testWidgets('raisonnement : ouvrir ⇒ true, fermer ⇒ null', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      final Finder tile = _switch('Afficher le raisonnement');
      await _tap(tester, tile);
      expect(s.settings.value.revealThinkingSteps, isTrue);
      await _tap(tester, tile);
      expect(s.settings.value.revealThinkingSteps, isNull,
          reason: '🔴 fermer doit rendre la main à l\'hôte, pas refuser');
    });

    testWidgets('capacités : web par le champ typé, hôte par le canal ouvert',
        (WidgetTester tester) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      await _tap(tester, _switch('Recherche web'));
      expect(s.settings.value.webSearch, isTrue);
      await _tap(tester, _switch('Lecture de documents'));
      expect(s.settings.value.capability('ocr'), isTrue);
    });

    testWidgets('préréglage : appliquer puis « aucun »', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      await _tap(tester, _choice('Rapide'));
      expect(s.activePresetId.value, 'fast');
      expect(s.settings.value.responseLength, ZChatResponseLength.concise);
      await _tap(tester, _choice('Aucun'));
      expect(s.activePresetId.value, isNull);
    });

    testWidgets('corpus : parent, enfants, et désélection en cascade', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      expect(_chip('Togo'), findsNothing,
          reason: 'les enfants n\'apparaissent qu\'une fois le parent choisi');
      await _tap(tester, _chip('Codes des douanes'));
      expect(_chip('Togo'), findsOneWidget);
      await _tap(tester, _chip('Togo'));
      expect(s.corpusScope.value?.corpusKeys, containsAll(<String>['cdn', 'cdn.togo']));
      await _tap(tester, _chip('Codes des douanes'));
      expect(s.corpusScope.value, isNull,
          reason: '🔴 clé d\'enfant orpheline après désélection du parent');
    });
  });

  group('🔴 SET-M8 — sections', () {
    testWidgets('titre hiérarchisé teinté `primary`, séparateur ENTRE', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s, sections: const <ZChatSettingsSection>[
        ZChatSettingsSection(
          id: kZChatSettingsSectionGeneration,
          title: ZChatSettingsLabel.text('Génération'),
        ),
        ZChatSettingsSection(
          id: kZChatSettingsSectionCorpus,
          title: ZChatSettingsLabel.text('Sources documentaires'),
        ),
      ]);
      expect(find.byType(ZChatMaterialSettingsSectionHeader), findsNWidgets(2));
      expect(find.byType(Divider), findsOneWidget,
          reason: '🔴 un séparateur par frontière, pas un par section');
      final Element ctx = tester.element(find.text('Génération'));
      final ThemeData theme = Theme.of(ctx);
      final Text title = ctx.widget as Text;
      expect(title.style?.color, theme.colorScheme.primary);
      expect(title.style?.fontSize, theme.textTheme.titleSmall?.fontSize);
      // Le séparateur précède le titre de la SECONDE section.
      expect(
        tester.getTopLeft(find.byType(Divider)).dy,
        lessThan(tester.getTopLeft(find.text('Sources documentaires')).dy),
      );
      expect(
        tester.getTopLeft(find.byType(Divider)).dy,
        greaterThan(tester.getTopLeft(find.text('Génération')).dy),
      );
    });

    testWidgets('sans titre déclaré : aucun en-tête, le séparateur reste', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      expect(find.byType(ZChatMaterialSettingsSectionHeader), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  testWidgets('🔴 SET-M9 — AD-13 : toute cible ≥ 48 dp sous un hôte hostile', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController s = _settings();
    await _pump(tester, s, onClose: () {}, material: hostileTapTargets());
    int measured = 0;
    for (final Type type in <Type>[
      ChoiceChip,
      FilterChip,
      SwitchListTile,
      TextButton,
      IconButton,
    ]) {
      for (final Element e in find.byType(type).evaluate()) {
        final Size size = tester.getSize(find.byElementPredicate(
          (Element candidate) => identical(candidate, e),
        ));
        measured++;
        expect(size.height, greaterThanOrEqualTo(kZChatMinTapTarget),
            reason: '🔴 cible de $type haute de ${size.height} dp');
      }
    }
    expect(measured, greaterThan(12),
        reason: '🔴 GARDE VACUELLE : $measured cible(s) mesurée(s)');
  });

  test('🔴 SET-M10 — garde de source : aucun catalogue d\'outils dans les '
      'builders standard, aucun IconTheme.merge', () {
    final List<File> files = Directory('lib/src/presentation')
        .listSync()
        .whereType<File>()
        .where((File f) =>
            f.path.contains('_settings_') || f.path.contains('_corpus_'))
        .toList();
    expect(files.length, greaterThanOrEqualTo(6),
        reason: '🔴 GARDE VACUELLE : ${files.length} fichier(s)');
    final RegExp tools =
        RegExp(r'ZChatTool(Catalog|Controller|Entry|State|ResolvedEntry)');
    final String all = files.map((File f) => f.readAsStringSync()).join('\n');
    expect(all, contains('ZChatSettingsController'),
        reason: 'contrôle positif : les builders lisent le contrôleur');
    for (final File f in files) {
      final List<String> lines = f.readAsLinesSync();
      for (int n = 0; n < lines.length; n++) {
        // Le CODE seul : une dartdoc a le droit de nommer ce qu'elle interdit.
        if (lines[n].trimLeft().startsWith('//')) continue;
        expect(tools.hasMatch(lines[n]), isFalse,
            reason: '🔴 ${f.path}:${n + 1} — un réglage standard passe par '
                'le catalogue d\'outils : deux états pour un même réglage');
        expect(lines[n].contains('IconTheme.merge('), isFalse,
            reason: '🔴 ${f.path}:${n + 1} — la teinte d\'un glyphe passe '
                'par ZForegroundOverride');
      }
    }
    expect(all, contains('ZForegroundOverride('));
  });

  testWidgets('🔴 SET-M11 — le montage n\'écrit RIEN', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController s = _settings();
    await _pump(tester, s, onClose: () {});
    await tester.pump();
    expect(s.settings.value, const ZChatGenerationSettings());
    expect(s.corpusScope.value, isNull);
    expect(s.activePresetId.value, isNull);
    expect(s.activeCount.value, 0);
  });

  testWidgets('🔴 SET-M12 — un hôte PASSIF obtient la feuille riche', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController s = _settings();
    await tester.pumpWidget(harness(
      SingleChildScrollView(
        child: ZChatMaterialSettingsSheet(controller: s, onClose: () {}),
      ),
    ));
    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
    expect(find.byType(ZChatMaterialSettingsHeader), findsOneWidget);
    // Sans catalogue : ni préréglages ni portée (AD-4), et rien ne lève.
    expect(find.byType(ZChatMaterialPresetChips), findsNothing);
    expect(find.byType(ZChatMaterialCorpusChips), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('🔴 SET-M13 — l\'en-tête', () {
    testWidgets('n\'existe que si l\'hôte fournit la fermeture', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      await _pump(tester, s);
      expect(find.byType(ZChatMaterialSettingsHeader), findsNothing);
    });

    testWidgets('« réinitialiser » remet tout, « fermer » appelle l\'hôte', (
      WidgetTester tester,
    ) async {
      final ZChatSettingsController s = _settings();
      int closed = 0;
      s.setResponseLength(ZChatResponseLength.detailed);
      s.toggleCorpusKey('gatt');
      await _pump(tester, s, onClose: () => closed++);
      await _tap(tester, find.byType(TextButton));
      expect(s.settings.value.responseLength, isNull);
      expect(s.corpusScope.value, isNull);
      await _tap(tester, find.byIcon(Icons.close));
      expect(closed, 1);
    });
  });

  testWidgets('🔴 SET-M14 — une entrée d\'hôte d\'une section du socle survit '
      '(AD-10)', (WidgetTester tester) async {
    final ZChatSettingsController s = _settings();
    await _pump(tester, s, entries: <ZChatSettingsEntry>[
      ZChatSettingsEntry(
        id: 'host.toggle',
        sectionId: kZChatSettingsSectionGeneration,
        title: const ZChatSettingsLabel.text('Réglage d\'hôte'),
        control: ZChatToggleControl(value: false, onChanged: (bool _) {}),
      ),
    ]);
    expect(find.text('Réglage d\'hôte'), findsOneWidget,
        reason: '🔴 l\'entrée d\'hôte a été perdue par l\'assemblage');
  });
}
