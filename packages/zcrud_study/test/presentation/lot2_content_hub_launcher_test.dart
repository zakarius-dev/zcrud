/// **Lot 2** — gardes du branchement du hub d'ajout.
///
/// Ce que ces gardes MESURENT (et non « constatent ») :
///
/// 1. **sans slot, l'arbre est IDENTIQUE** — comparaison de la SUITE DES TYPES
///    de widgets rendus, avec contre-preuve que la comparaison est
///    discriminante (elle diffère dès qu'on branche le hub) ;
/// 2. le `+` d'app-bar et le `+` d'une section ouvrent **LE MÊME** hub —
///    mesuré sur le CONTENU rendu de la feuille, jamais sur la présence d'un
///    type ;
/// 3. **paramètre de l'hôte > hub** : une commande explicite n'est jamais
///    détournée (le callback de l'hôte part, la feuille ne s'ouvre PAS) ;
/// 4. `addOpensContentHub` **sans scope** ⇒ le `+` est ABSENT (AD-4), avec sa
///    contre-preuve (avec scope ⇒ présent) ;
/// 5. **SM-1** : ouvrir le hub ne reconstruit AUCUNE ligne de section, et un
///    hôte qui recompose son launcher à chaque frame non plus ;
/// 6. les **clés de couleur stables** tiennent leur promesse : insérer une
///    entrée au milieu ne déplace la teinte d'AUCUNE autre — mesuré sur la
///    couleur RÉELLEMENT peinte de la pastille.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZAppBarAction;

import '../support/suf3_harness.dart';

// Libellés INJECTÉS de test (jamais des défauts du socle).
const String kHubEntryLabel = 'HUB_ENTRY';
const String kHubEntryLabel2 = 'HUB_ENTRY_2';
const String kAddSemantic = 'ADD_CONTENT';
const String kSectionAddSemantic = 'SECTION_ADD';

ZContentHubLauncher hub({List<ZContentHubEntry>? entries}) =>
    ZContentHubLauncher(
      entries:
          entries ??
          const <ZContentHubEntry>[
            ZContentHubEntry(
              icon: Icons.auto_awesome,
              label: kHubEntryLabel,
              colorKey: ZContentHubReference.colorKeyFlashcards,
            ),
          ],
    );

/// Suite des types de widgets RÉELLEMENT rendus — la signature d'arbre comparée.
List<String> treeSignature(WidgetTester tester) => tester
    .allWidgets
    .map((Widget w) => w.runtimeType.toString())
    .toList(growable: false);

/// Une section `ZStudyToolsSectionSpec` neutre paramétrable.
ZStudyToolsSectionSpec section({
  VoidCallback? addAction,
  bool addOpensContentHub = false,
  int itemCount = 0,
  Widget Function(BuildContext, int)? itemBuilder,
}) => ZStudyToolsSectionSpec(
  id: 'sec',
  title: 'SECTION_TITLE',
  itemCount: itemCount,
  itemBuilder: itemBuilder ?? (_, _) => const SizedBox.shrink(),
  emptyState: const SizedBox.shrink(),
  addAction: addAction,
  addOpensContentHub: addOpensContentHub,
  addActionIcon: Icons.add,
  addActionSemanticLabel: kSectionAddSemantic,
);

/// Monte un `ZSectionedStudyLayout` (éventuellement) sous un `ZContentHubScope`.
Future<void> pumpSection(
  WidgetTester tester, {
  required ZStudyToolsSectionSpec spec,
  ZContentHubLauncher? launcher,
}) async {
  final Widget layout = ZSectionedStudyLayout(
    sections: <ZStudyToolsSectionSpec>[spec],
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: launcher == null
            ? layout
            : ZContentHubScope(launcher: launcher, child: layout),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('① sans slot, l\'arbre est STRICTEMENT identique', () {
    testWidgets('aucun ZContentHubScope, signature d\'arbre inchangée', (
      WidgetTester tester,
    ) async {
      await setScreen(tester, 800, 900);

      await pumpDetail(tester);
      final List<String> withoutSlot = treeSignature(tester);
      expect(
        find.byType(ZContentHubScope),
        findsNothing,
        reason: '🔴 le socle a inséré un nœud sans qu\'on le lui demande',
      );

      // Second montage IDENTIQUE : la signature doit être reproductible, sans
      // quoi la comparaison ci-dessous ne prouverait rien (bruit de montage).
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpDetail(tester);
      expect(
        treeSignature(tester),
        withoutSlot,
        reason: '🔴 sonde INSTABLE : deux montages identiques rendent deux '
            'arbres différents ⇒ la comparaison est sans valeur.',
      );

      // 🔴 CONTRE-PREUVE de NON-VACUITÉ : la même signature DOIT différer dès
      // qu'on branche le hub. Sans elle, l'égalité ci-dessus serait compatible
      // avec une sonde qui ne mesure rien.
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpDetail(tester, contentHubLauncher: hub());
      final List<String> withSlot = treeSignature(tester);
      expect(
        withSlot,
        isNot(withoutSlot),
        reason: '🔴 sonde AVEUGLE : brancher le hub ne change pas la '
            'signature ⇒ elle ne mesure pas l\'arbre.',
      );
      expect(withSlot, contains('ZContentHubScope'));
      // …et la SEULE différence est ce nœud (le reste est intact).
      expect(
        withSlot.where((String t) => t != 'ZContentHubScope').toList(),
        withoutSlot,
        reason: '🔴 brancher le hub a changé autre chose que l\'ajout du '
            'scope — le slot n\'est plus purement additif.',
      );
    });

    testWidgets(
      'une section sans addAction ni addOpensContentHub n\'a AUCUN `+`, '
      'même sous un scope',
      (WidgetTester tester) async {
        await pumpSection(tester, spec: section(), launcher: hub());
        expect(
          find.byTooltip(kSectionAddSemantic),
          findsNothing,
          reason: '🔴 un scope en portée a fait POUSSER un `+` non demandé — '
              'l\'hôte qui branche le hub pour son app-bar verrait tous ses '
              'en-têtes changer.',
        );
        // Contre-preuve : le même `+` EXISTE dès qu'il est demandé.
        await pumpSection(
          tester,
          spec: section(addOpensContentHub: true),
          launcher: hub(),
        );
        expect(find.byTooltip(kSectionAddSemantic), findsOneWidget);
      },
    );
  });

  group('② le `+` d\'app-bar ouvre le hub CONFIGURÉ', () {
    testWidgets('onPressed nul + launcher ⇒ la feuille s\'ouvre et rend '
        'l\'entrée INJECTÉE', (WidgetTester tester) async {
      await setScreen(tester, 800, 900);
      await pumpDetail(
        tester,
        addAction: const ZAppBarAction(
          icon: Icons.add,
          semanticLabel: kAddSemantic,
          // `ZPageShell` ne pose de `Tooltip` QUE si l'hôte en fournit un
          // (`tooltip: action.tooltip`) — c'est notre poignée de test.
          tooltip: kAddSemantic,
        ),
        contentHubLauncher: hub(),
      );
      expect(find.text(kHubEntryLabel), findsNothing);

      await tester.tap(find.byTooltip(kAddSemantic));
      await tester.pumpAndSettle();

      // 🔴 On mesure le CONTENU rendu, pas la présence du type : une feuille
      // vide « trouvée » ne prouverait pas que la configuration est arrivée.
      expect(find.byType(ZContentHubSheet), findsOneWidget);
      expect(find.text(kHubEntryLabel), findsOneWidget);
    });

    testWidgets('SANS launcher, le même `+` reste DÉSACTIVÉ (aucune feuille)', (
      WidgetTester tester,
    ) async {
      await setScreen(tester, 800, 900);
      await pumpDetail(
        tester,
        addAction: const ZAppBarAction(
          icon: Icons.add,
          semanticLabel: kAddSemantic,
          // `ZPageShell` ne pose de `Tooltip` QUE si l'hôte en fournit un
          // (`tooltip: action.tooltip`) — c'est notre poignée de test.
          tooltip: kAddSemantic,
        ),
      );
      await tester.tap(find.byTooltip(kAddSemantic), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        find.byType(ZContentHubSheet),
        findsNothing,
        reason: '🔴 une feuille s\'ouvre sans qu\'aucun hub soit branché',
      );
    });

    testWidgets('🔴 paramètre de l\'hôte > hub : une commande explicite n\'est '
        'JAMAIS détournée', (WidgetTester tester) async {
      await setScreen(tester, 800, 900);
      int hostCalls = 0;
      await pumpDetail(
        tester,
        addAction: ZAppBarAction(
          icon: Icons.add,
          semanticLabel: kAddSemantic,
          // `ZPageShell` ne pose de `Tooltip` QUE si l'hôte en fournit un
          // (`tooltip: action.tooltip`) — c'est notre poignée de test.
          tooltip: kAddSemantic,
          onPressed: () => hostCalls++,
        ),
        contentHubLauncher: hub(),
      );
      await tester.tap(find.byTooltip(kAddSemantic));
      await tester.pumpAndSettle();

      expect(hostCalls, 1, reason: '🔴 la commande de l\'hôte n\'est pas partie');
      expect(
        find.byType(ZContentHubSheet),
        findsNothing,
        reason: '🔴 le hub a DÉTOURNÉ une commande explicite de l\'hôte — le '
            'pire mode d\'échec (silencieux).',
      );
    });
  });

  group('③ le `+` d\'une section ouvre LE MÊME hub', () {
    testWidgets('addOpensContentHub + scope ⇒ feuille rendue avec l\'entrée '
        'INJECTÉE', (WidgetTester tester) async {
      await pumpSection(
        tester,
        spec: section(addOpensContentHub: true),
        launcher: hub(),
      );
      await tester.tap(find.byTooltip(kSectionAddSemantic));
      await tester.pumpAndSettle();
      expect(find.text(kHubEntryLabel), findsOneWidget);
    });

    testWidgets('🔴 AD-4 — addOpensContentHub SANS scope ⇒ le `+` est ABSENT '
        '(jamais grisé, jamais un no-op)', (WidgetTester tester) async {
      await pumpSection(tester, spec: section(addOpensContentHub: true));
      expect(
        find.byTooltip(kSectionAddSemantic),
        findsNothing,
        reason: '🔴 un `+` déclaré « ouvre le hub » est rendu alors qu\'aucun '
            'hub n\'est branché : il ne peut RIEN faire.',
      );
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('🔴 paramètre de la section > hub', (
      WidgetTester tester,
    ) async {
      int sectionCalls = 0;
      await pumpSection(
        tester,
        spec: section(
          addAction: () => sectionCalls++,
          addOpensContentHub: true,
        ),
        launcher: hub(),
      );
      await tester.tap(find.byTooltip(kSectionAddSemantic));
      await tester.pumpAndSettle();
      expect(sectionCalls, 1);
      expect(find.byType(ZContentHubSheet), findsNothing);
    });

    testWidgets('les DEUX `+` ouvrent la MÊME configuration', (
      WidgetTester tester,
    ) async {
      await setScreen(tester, 800, 900);
      final ZContentHubLauncher shared = hub();
      await pumpDetail(
        tester,
        addAction: const ZAppBarAction(
          icon: Icons.add,
          semanticLabel: kAddSemantic,
          // `ZPageShell` ne pose de `Tooltip` QUE si l'hôte en fournit un
          // (`tooltip: action.tooltip`) — c'est notre poignée de test.
          tooltip: kAddSemantic,
        ),
        contentHubLauncher: shared,
        materialSectionsBuilder: (_) => <ZStudyToolsSectionSpec>[
          section(addOpensContentHub: true),
        ],
      );

      // Voie app-bar.
      await tester.tap(find.byTooltip(kAddSemantic));
      await tester.pumpAndSettle();
      expect(find.text(kHubEntryLabel), findsOneWidget);
      Navigator.of(tester.element(find.byType(ZContentHubSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.text(kHubEntryLabel), findsNothing);

      // Voie section — MÊME contenu, sans que rien n'ait été reconfiguré.
      await tester.tap(find.byTooltip(kSectionAddSemantic));
      await tester.pumpAndSettle();
      expect(find.text(kHubEntryLabel), findsOneWidget);
    });
  });

  group('④ SM-1 — ouvrir le hub ne reconstruit PAS la liste', () {
    testWidgets('aucun item de section reconstruit au tap du `+`', (
      WidgetTester tester,
    ) async {
      int itemBuilds = 0;
      await pumpSection(
        tester,
        spec: section(
          addOpensContentHub: true,
          itemCount: 3,
          itemBuilder: (_, int i) {
            itemBuilds++;
            return SizedBox(height: 40, key: ValueKey<String>('it$i'));
          },
        ),
        launcher: hub(),
      );
      final int before = itemBuilds;
      expect(before, greaterThan(0), reason: 'sonde morte : rien n\'a été bâti');

      await tester.tap(find.byTooltip(kSectionAddSemantic));
      await tester.pumpAndSettle();
      expect(find.text(kHubEntryLabel), findsOneWidget);

      expect(
        itemBuilds,
        before,
        reason: '🔴 SM-1 : ouvrir le hub a reconstruit ${itemBuilds - before} '
            'item(s) de section.',
      );
    });

    testWidgets('🔴 un launcher RECOMPOSÉ à chaque frame ne reconstruit '
        'AUCUNE section (lecture non dépendante)', (WidgetTester tester) async {
      int itemBuilds = 0;
      late StateSetter setOuter;
      int frame = 0;

      // 🔴 L'enfant est construit UNE SEULE FOIS et repassé par IDENTITÉ à
      // chaque frame. Flutter court-circuite alors la reconstruction du
      // sous-arbre — SAUF si une dépendance d'`InheritedWidget` la force. C'est
      // ce qui rend la mesure DISCRIMINANTE : sans cette hoisting, le rebuild
      // observé viendrait du parent, pas du scope, et la garde serait vacante
      // (elle l'a été : première rédaction, 3 → 6 rebuilds imputés à tort).
      final Widget stableChild = ZSectionedStudyLayout(
        sections: <ZStudyToolsSectionSpec>[
          section(
            addOpensContentHub: true,
            itemCount: 3,
            itemBuilder: (_, int i) {
              itemBuilds++;
              return SizedBox(height: 40, key: ValueKey<String>('it$i'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                setOuter = setState;
                frame++;
                return ZContentHubScope(
                  // Instance NEUVE et NON ÉGALE à chaque frame : `entries` porte
                  // une closure fraîche, donc `listEquals` est faux.
                  launcher: ZContentHubLauncher(
                    entries: <ZContentHubEntry>[
                      ZContentHubEntry(
                        icon: Icons.auto_awesome,
                        label: kHubEntryLabel,
                        onTap: () {},
                      ),
                    ],
                  ),
                  child: stableChild,
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final int before = itemBuilds;
      expect(before, greaterThan(0));

      // La CAUSE mesurée : le launcher change réellement d'identité ET
      // d'égalité entre deux frames.
      final ZContentHubScope first = tester.widget<ZContentHubScope>(
        find.byType(ZContentHubScope),
      );
      setOuter(() {});
      await tester.pump();
      final ZContentHubScope second = tester.widget<ZContentHubScope>(
        find.byType(ZContentHubScope),
      );
      expect(frame, greaterThan(1), reason: 'sonde morte : aucune reframe');
      expect(
        second.launcher == first.launcher,
        isFalse,
        reason: '🔴 sonde MOLLE : les deux launchers sont égaux, la garde ne '
            'mesure donc pas le cas qu\'elle prétend mesurer.',
      );
      expect(
        second.updateShouldNotify(first),
        isTrue,
        reason: '🔴 sonde MOLLE : le scope ne notifierait de toute façon pas — '
            'l\'absence de rebuild ne prouverait rien.',
      );

      expect(
        itemBuilds,
        before,
        reason: '🔴 SM-1 : un launcher recomposé a reconstruit '
            '${itemBuilds - before} item(s). La lecture du scope est devenue '
            'DÉPENDANTE (`dependOnInheritedWidgetOfExactType`).',
      );
    });
  });

  group('⑤ clés de couleur STABLES — le seul vocabulaire ajouté', () {
    test('les six clés sont recensées, distinctes, et non vides', () {
      expect(ZContentHubReference.colorKeys, hasLength(6));
      expect(
        ZContentHubReference.colorKeys.toSet(),
        hasLength(6),
        reason: '🔴 deux clés identiques ⇒ deux familles partageraient une '
            'teinte sans que personne l\'ait décidé.',
      );
      expect(
        ZContentHubReference.colorKeys.every((String k) => k.isNotEmpty),
        isTrue,
      );
    });

    test('🔴 ce ne sont PAS des libellés : aucune n\'est traduite ni rendue', () {
      // Preuve sur pièces : aucune de ces constantes n'apparaît dans un puits
      // de rendu (`Text(`, `label:`) du package.
      final Directory dir = Directory('lib/src/presentation');
      expect(dir.existsSync(), isTrue, reason: 'lancer depuis le package');
      final List<String> hits = <String>[];
      for (final FileSystemEntity f in dir.listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final List<String> lines = f.readAsLinesSync();
        for (int i = 0; i < lines.length; i++) {
          final String raw = lines[i];
          final String t = raw.trimLeft();
          if (t.startsWith('//')) continue;
          for (final String key in ZContentHubReference.colorKeys) {
            if (RegExp("(Text\\(|label:)\\s*'$key'").hasMatch(raw)) {
              hits.add('${f.path}:${i + 1}');
            }
          }
        }
      }
      expect(
        hits,
        isEmpty,
        reason: '🔴 une clé de couleur est RENDUE comme un libellé : $hits',
      );
    });

    testWidgets('🔴 insérer une entrée au MILIEU ne déplace la teinte '
        'd\'AUCUNE autre (mesuré sur la couleur peinte)', (
      WidgetTester tester,
    ) async {
      const ZContentHubEntry a = ZContentHubEntry(
        icon: Icons.note,
        label: kHubEntryLabel,
        colorKey: ZContentHubReference.colorKeyNote,
      );
      const ZContentHubEntry b = ZContentHubEntry(
        icon: Icons.description,
        label: kHubEntryLabel2,
        colorKey: ZContentHubReference.colorKeyDocument,
      );
      const ZContentHubEntry inserted = ZContentHubEntry(
        icon: Icons.mic,
        label: 'HUB_ENTRY_INSERTED',
        colorKey: ZContentHubReference.colorKeyPodcast,
      );

      Future<List<Color>> avatarColors(List<ZContentHubEntry> entries) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZContentHubSheet(entries: entries),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byKey(ZContentHubSheet.avatarKey),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((DecoratedBox d) => (d.decoration as BoxDecoration).color!)
            .toList();
      }

      final List<Color> before = await avatarColors(
        const <ZContentHubEntry>[a, b],
      );
      expect(before, hasLength(2));
      expect(
        before.first,
        isNot(before.last),
        reason: 'sonde MOLLE : les deux teintes sont déjà identiques.',
      );

      final List<Color> after = await avatarColors(
        const <ZContentHubEntry>[a, inserted, b],
      );
      expect(after, hasLength(3));
      expect(
        <Color>[after.first, after.last],
        <Color>[before.first, before.last],
        reason: '🔴 insérer un type au milieu a DÉPLACÉ la teinte de ses '
            'voisins — la clé n\'est donc pas ce qui gouverne le créneau.',
      );
    });
  });

  group('⑥ le socle n\'ajoute AUCUN libellé', () {
    test('ZContentHubLauncher ne déclare aucun champ String', () {
      final File f = File(
        'lib/src/presentation/z_content_hub_launcher.dart',
      );
      expect(f.existsSync(), isTrue, reason: 'sonde cassée');
      final List<String> offenders = <String>[];
      for (final String raw in f.readAsLinesSync()) {
        final String t = raw.trimLeft();
        if (t.startsWith('//')) continue;
        if (RegExp(r'^\s*final\s+String\??\s+\w+;').hasMatch(raw)) {
          offenders.add(raw.trim());
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 le launcher porte un texte : $offenders. Tout libellé vient '
            'des entrées/sections INJECTÉES par l\'hôte (FR-26).',
      );
      // Contre-preuve : le détecteur n'est pas aveugle.
      expect(
        RegExp(r'^\s*final\s+String\??\s+\w+;')
            .hasMatch('  final String? badgeLabel;'),
        isTrue,
      );
    });
  });
}
