@TestOn('vm')
/// Gardes du contrôleur d'outils et de sa projection vers la feuille de
/// réglages (lot C).
///
/// Ce que ces gardes défendent, et pourquoi :
/// * TC-1 — AD-2 : régler un outil ne réveille QUE sa tranche. C'est la
///   propriété qui rend une feuille de vingt tuiles tenable.
/// * TC-2 — le refus d'une entrée grisée est le cas NOMINAL : il s'absorbe.
/// * TC-3 — le contrôleur ne REFAIT aucune décision du domaine (ordre,
///   comptage, visibilité) : grep négatif outillé sur ses sources.
/// * TC-4/TC-5 — la projection rend une entrée grisée AVEC sa raison, et une
///   nature d'hôte sans jamais lever.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

const String kReasonWeb = 'reason.web';
const String kReasonUnavailable = 'reason.unavailable';

ZChatToolCatalog _fixture() => ZChatToolCatalog(
      sections: <ZChatToolSection>[
        const ZChatToolSection(key: 'gen', label: 'Génération'),
        const ZChatToolSection(key: 'doc', label: 'Documents'),
      ],
      entries: <ZChatToolEntry>[
        ZChatToolEntry(
          key: 'web',
          sectionKey: 'gen',
          label: 'Recherche web',
          state: const ZChatToggleState(),
          stateLabels: const <String, String>{
            'on': 'Activée',
            'off': 'Désactivée',
          },
        ),
        ZChatToolEntry(
          key: 'think',
          sectionKey: 'gen',
          label: 'Réflexion',
          state: const ZChatToggleState(),
        ),
        ZChatToolEntry(
          key: 'think.level',
          sectionKey: 'gen',
          label: 'Niveau de réflexion',
          revealedBy: 'think',
          state: ZChatCycleState(stepCount: 3),
          stateLabels: const <String, String>{
            'step.0': 'Aucun',
            'step.1': 'Court',
            'step.2': 'Long',
          },
        ),
        ZChatToolEntry(
          key: 'summary',
          sectionKey: 'gen',
          label: 'Résumé',
          state: const ZChatToggleState(),
          disabledWhen: <ZChatToolRule>[
            ZChatToolRule(
              condition: ZChatToolCondition(activeKeys: const <String>['web']),
              reasonToken: kReasonWeb,
            ),
          ],
        ),
        ZChatToolEntry(
          key: 'corpus',
          sectionKey: 'doc',
          label: 'Portée',
          state: ZChatCatalogState(
            itemKeys: const <String>['x', 'y'],
            unavailableKeys: const <String>['y'],
            unavailableReasonToken: kReasonUnavailable,
          ),
          stateLabels: const <String, String>{'x': 'Dossier X', 'y': 'Dossier Y'},
        ),
        ZChatToolEntry(
          key: 'host',
          sectionKey: 'doc',
          label: 'Nature d\'hôte',
          state: const ZChatCustomToolState(kind: 'hostThing'),
        ),
      ],
    );

void main() {
  group('🔴 TC-1 — AD-2 : une écriture ne réveille QUE la tranche concernée',
      () {
    test('basculer `web` ne notifie pas la tranche de `think`', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      int webBuilds = 0;
      int thinkBuilds = 0;
      c.entryOf('web').addListener(() => webBuilds++);
      c.entryOf('think').addListener(() => thinkBuilds++);

      final ZResult<Unit> outcome =
          c.setEntryState('web', const ZChatToggleState(value: true));

      expect(outcome.isRight(), isTrue);
      expect(webBuilds, 1, reason: '🔴 la tranche réglée doit être notifiée');
      expect(thinkBuilds, 0,
          reason: '🔴 AD-2 : régler un outil a reconstruit une tuile qui ne le '
              'regarde pas — c\'est le rafraîchissement global que ce socle '
              'existe pour éviter');
    });

    test('…et la tranche d\'une entrée RÉELLEMENT affectée, elle, est '
        'notifiée', () {
      // Contre-preuve de non-vacuité : si la granularité était obtenue en ne
      // notifiant JAMAIS rien, la garde ci-dessus serait verte pour rien.
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      int summaryBuilds = 0;
      c.entryOf('summary').addListener(() => summaryBuilds++);
      c.setEntryState('web', const ZChatToggleState(value: true));
      expect(summaryBuilds, 1,
          reason: '🔴 `summary` devient GRISÉE quand `web` s\'allume : sa '
              'tranche doit bouger');
      expect(c.entryOf('summary').value?.disabledReasonToken, kReasonWeb);
    });

    test('une entrée non révélée a une tranche NULLE, et revient quand sa '
        'bascule parente s\'allume', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      expect(c.entryOf('think.level').value, isNull);
      c.setEntryState('think', const ZChatToggleState(value: true));
      expect(c.entryOf('think.level').value, isNotNull);
    });
  });

  group('🔴 TC-2 — un `Left` est le cas NOMINAL, jamais une exception', () {
    test('régler une entrée GRISÉE est refusé, sans lever et sans rien '
        'changer', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      final ZChatToolCatalog before = c.catalog;

      final ZResult<Unit> outcome =
          c.setEntryState('summary', const ZChatToggleState(value: true));

      expect(outcome.isLeft(), isTrue);
      expect(identical(c.catalog, before), isTrue,
          reason: '🔴 un refus ne doit RIEN écrire');
      expect(c.entryOf('summary').value?.entry.isActive, isFalse);
    });

    test('`clearEntry` sur une entrée grisée ou inconnue est inerte', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      expect(() => c.clearEntry('summary'), returnsNormally);
      expect(() => c.clearEntry('inconnue'), returnsNormally);
    });

    test('`advance` fait boucler le cycle — le contrôleur ne calcule pas le '
        'cran', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('think', const ZChatToggleState(value: true));
      final List<int> steps = <int>[];
      for (int i = 0; i < 4; i++) {
        c.advance('think.level');
        steps.add(
          (c.entryOf('think.level').value!.entry.state as ZChatCycleState).step,
        );
      }
      expect(steps, <int>[1, 2, 0, 1],
          reason: '🔴 le retour à zéro appartient au domaine : une saturation '
              'signalerait un incrément réimplémenté ici');
    });
  });

  group('🔴 TC-3 — le comptage et l\'ordre viennent du DOMAINE', () {
    test('le comptage publié est exactement celui du catalogue', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      c.setEntryState('think', const ZChatToggleState(value: true));
      expect(c.activeCount.value, c.catalog.resolve().activeCount);
      expect(c.activeKeys.value, c.catalog.resolve().activeKeys);
    });

    test('la recherche filtre le RENDU, jamais le comptage', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      final int before = c.activeCount.value;
      c.setQuery('portée');
      expect(c.activeCount.value, before);
      final List<String> visible = <String>[
        for (final ZChatToolSectionSlice s in c.sheetStructure.value.sections)
          ...s.entryKeys,
      ];
      expect(visible, contains('corpus'));
      expect(visible, isNot(contains('web')));
    });

    test('la structure ne porte AUCUNE section vide', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setQuery('zzz-aucune-correspondance');
      expect(c.sheetStructure.value.sections, isEmpty);
    });

    test('🔴 grep NÉGATIF — aucune seconde implémentation de l\'ordre, du '
        'comptage ni de la visibilité dans `presentation/tools/`', () {
      final List<File> sources = Directory('lib/src/presentation/tools')
          .listSync()
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList();
      expect(sources, hasLength(3),
          reason: '🔴 GARDE VACUELLE : les sources du lot sont introuvables');
      // Motifs d'une décision REPRISE au domaine. `resolve()` les a toutes
      // prises ; les rejouer ici ferait diverger la feuille de la bande.
      final RegExp reimplemented = RegExp(
        r'\.sort\(|\.where\(\s*\(.*isActive|activeKeys\s*\.add\(|'
        r'countsTowardActive|revealedBy\s*==|disabledWhen\s*\.',
      );
      final List<String> hits = <String>[];
      for (final File f in sources) {
        final List<String> lines = f.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String code = lines[i].split('//').first;
          if (reimplemented.hasMatch(code)) {
            hits.add('${f.path}:${i + 1} → ${lines[i].trim()}');
          }
        }
      }
      expect(hits, isEmpty,
          reason: '🔴 une décision déjà prise par `ZChatToolCatalog.resolve` '
              'est rejouée ici :\n${hits.join('\n')}');
    });

    test('🔬 contre-preuve — le motif SAIT rougir sur une réimplémentation', () {
      final RegExp reimplemented = RegExp(
        r'\.sort\(|\.where\(\s*\(.*isActive|activeKeys\s*\.add\(|'
        r'countsTowardActive|revealedBy\s*==|disabledWhen\s*\.',
      );
      for (final String witness in <String>[
        '    entries.sort((a, b) => a.order.compareTo(b.order));',
        '    if (e.countsTowardActive) n++;',
        '    activeKeys.add(e.key);',
      ]) {
        expect(reimplemented.hasMatch(witness), isTrue,
            reason: '🔴 le motif ne voit pas `$witness`');
      }
      expect(reimplemented.hasMatch('    final r = catalog.resolve();'), isFalse,
          reason: '🔴 FAUX POSITIF : consommer le domaine n\'est pas le '
              'refaire');
    });
  });

  group('🔴 TC-4 — la projection rend les entrées GRISÉES, avec leur raison',
      () {
    test('une entrée grisée est projetée, et son sous-titre porte la raison',
        () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));

      final List<ZChatSettingsEntry> entries = zChatToolSettingsEntries(
        c,
        reasonOf: (String token) =>
            token == kReasonWeb ? 'Coupée par la recherche web' : null,
      );

      final Iterable<ZChatSettingsEntry> summary =
          entries.where((ZChatSettingsEntry e) => e.id == 'summary');
      expect(summary, hasLength(1),
          reason: '🔴 une entrée grisée est RENDUE, jamais masquée — c\'est '
              'exactement le défaut legacy que ce lot ferme');
      expect(summary.single.subtitle?.text, 'Coupée par la recherche web');
    });

    test('le sous-titre décrit l\'ÉTAT, pas la fonction', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      final ZChatSettingsEntry web = zChatToolSettingsEntries(c)
          .firstWhere((ZChatSettingsEntry e) => e.id == 'web');
      expect(web.subtitle?.text, 'Activée');
    });

    test('un tap sur la projection d\'une entrée grisée n\'explose pas et '
        'n\'écrit rien', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      final ZChatSettingsEntry summary = zChatToolSettingsEntries(c)
          .firstWhere((ZChatSettingsEntry e) => e.id == 'summary');
      final ZChatToolCatalog before = c.catalog;
      expect(
        () => (summary.control as ZChatToggleControl).onChanged(true),
        returnsNormally,
      );
      expect(identical(c.catalog, before), isTrue);
    });

    test('les sections gardent leur libellé d\'hôte, et rien n\'est inventé',
        () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      final List<ZChatSettingsSection> sections = zChatToolSettingsSections(c);
      expect(
        sections.map((ZChatSettingsSection s) => s.id).toList(),
        <String>['gen', 'doc'],
      );
      expect(sections.first.title?.text, 'Génération');
    });

    test('une entrée SANS libellé d\'hôte n\'est pas projetée (jamais la clé '
        'technique à l\'écran)', () {
      final ZChatToolController c = ZChatToolController(
        catalog: ZChatToolCatalog(
          entries: <ZChatToolEntry>[
            ZChatToolEntry(key: 'muette', state: const ZChatToggleState()),
          ],
        ),
      );
      addTearDown(c.dispose);
      expect(zChatToolSettingsEntries(c), isEmpty);
    });
  });

  group('🔴 TC-5 — une nature d\'hôte ne lève JAMAIS (AD-4/AD-10)', () {
    test('un `kind` inconnu tombe sur le contrôle d\'échappatoire', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      late List<ZChatSettingsEntry> entries;
      expect(() => entries = zChatToolSettingsEntries(c), returnsNormally);
      final ZChatSettingsEntry host =
          entries.firstWhere((ZChatSettingsEntry e) => e.id == 'host');
      expect(host.control, isA<ZChatToolCustomControl>());
      expect(host.kind, 'hostThing',
          reason: '🔴 le kind publié doit rester celui de l\'hôte : c\'est ce '
              'qu\'il cible dans `kindBuilders`');
    });

    test('un catalogue filtrable garde ses entrées INDISPONIBLES, désactivées',
        () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      final ZChatSettingsEntry corpus = zChatToolSettingsEntries(c)
          .firstWhere((ZChatSettingsEntry e) => e.id == 'corpus');
      final List<ZChatSettingsChoice> choices =
          (corpus.control as ZChatSelectControl).choices;
      expect(choices, hasLength(2),
          reason: '🔴 une entrée indisponible reste ÉNUMÉRÉE');
      expect(choices.last.enabled, isFalse);
    });
  });

  group('🔴 TC-6 — `reset` vide réellement le comptage', () {
    test('après `reset`, aucune clé active et les tranches sont republiées',
        () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      expect(c.activeKeys.value, isNotEmpty);
      c.reset();
      expect(c.activeKeys.value, isEmpty);
      expect(c.activeCount.value, 0);
      expect(c.entryOf('web').value?.entry.isActive, isFalse);
    });
  });

  group('🔴 TC-7 — la structure est une VALEUR comparable', () {
    test('deux structures identiques sont égales — sans quoi tout notifierait',
        () {
      const ZChatToolSectionSlice a = ZChatToolSectionSlice(
        sectionKey: 'gen',
        label: 'G',
        entryKeys: <String>['x'],
      );
      const ZChatToolSectionSlice b = ZChatToolSectionSlice(
        sectionKey: 'gen',
        label: 'G',
        entryKeys: <String>['x'],
      );
      expect(
        const ZChatToolSheetStructure(<ZChatToolSectionSlice>[a]),
        const ZChatToolSheetStructure(<ZChatToolSectionSlice>[b]),
      );
    });

    test('la structure ne bouge pas quand seul un ÉTAT change', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      int structureBuilds = 0;
      c.sheetStructure.addListener(() => structureBuilds++);
      c.setEntryState('web', const ZChatToggleState(value: true));
      expect(structureBuilds, 0,
          reason: '🔴 la liste ne doit pas se reconstruire parce qu\'une '
              'bascule a changé — seules les tuiles bougent');
    });

    test('…mais elle bouge quand une entrée est RÉVÉLÉE (non-vacuité)', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      int structureBuilds = 0;
      c.sheetStructure.addListener(() => structureBuilds++);
      c.setEntryState('think', const ZChatToggleState(value: true));
      expect(structureBuilds, 1);
    });
  });

  group('🔴 TC-8 — la bande et la feuille comptent PAREIL', () {
    test('le comptage est identique quelle que soit la surface interrogée', () {
      final ZChatToolController c = ZChatToolController(catalog: _fixture());
      addTearDown(c.dispose);
      c.setEntryState('web', const ZChatToggleState(value: true));
      expect(
        c.activeCount.value,
        c.catalog.resolve(surface: ZChatToolSurface.band).activeCount,
      );
      expect(
        c.activeCount.value,
        c.catalog.resolve(surface: ZChatToolSurface.sheet).activeCount,
      );
    });
  });

  test('🔬 contrôle positif — les tranches sont bien des `ValueListenable`',
      () {
    final ZChatToolController c = ZChatToolController(catalog: _fixture());
    addTearDown(c.dispose);
    expect(c.entryOf('web'), isA<ValueListenable<ZChatToolResolvedEntry?>>());
    expect(c.sheetStructure, isA<ValueListenable<ZChatToolSheetStructure>>());
  });
}
